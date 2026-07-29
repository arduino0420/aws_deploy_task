# Blog App

Ruby on RailsのBlog教材アプリです。

## 対象バージョン

- Ruby 4.0.5
- Bundler 4.0.17
- Rails 8.1.3
- Puma 7.2系
- PostgreSQL
- Node.js 24、Yarn 1.22.22（既存Webpackerアセット用）

Rubyの選択にはリポジトリの `.ruby-version` を使用します。EC2でもローカルでも、次の結果が対象バージョンと一致することを先に確認してください。

```bash
ruby -v
bundle -v
bundle exec rails --version
bundle exec puma --version
```

## ローカルセットアップと検証

PostgreSQLを起動してから実行します。接続先を明示する場合は `POSTGRES_HOST`、`POSTGRES_PORT`、`POSTGRES_USER`、`POSTGRES_PASSWORD` をローカル環境だけに設定してください。

```bash
bundle install
yarn install --frozen-lockfile
bundle exec rails db:prepare
bundle exec rails zeitwerk:check
bundle exec rails test
```

開発サーバーは外部公開せず、既定で `127.0.0.1:3000` にbindします。

```bash
bundle exec puma -C config/puma.rb
```

別ポートで確認する場合は `PORT=3001` のように指定します。停止は `Ctrl-C` です。

## 配備構成

このリポジトリの変更前には、Nginx、systemd、init.d、Capistrano、EC2用スクリプト、UnicornのGemまたは設定はありませんでした。アプリサーバーは既にPuma 4でしたが、開発用TCPポート設定だけでした。

本教材では次のEC2構成を採用します。

```text
client
  -> ALBまたはNginxでTLS終端
  -> Nginx :80
  -> unix:/var/www/blog_app/shared/tmp/sockets/puma.sock
  -> Puma 7.2
  -> Rails 8.1.3
  -> PostgreSQL（RDSまたは別途管理するPostgreSQL）
```

配備ファイルの前提は次のとおりです。

- 実行ユーザー/グループ: `deploy:deploy`
- アプリ: `/var/www/blog_app/current`
- 永続領域: `/var/www/blog_app/shared`
- socket: `/var/www/blog_app/shared/tmp/sockets/puma.sock`
- PID: `/var/www/blog_app/shared/tmp/pids/puma.pid`
- Puma service: `puma.service`
- Rails environment: `production`
- Puma/Rails log: systemd journal
- Nginx log: `/var/log/nginx/blog_app.access.log`、`/var/log/nginx/blog_app.error.log`

AMIや既存運用でユーザーまたはパスが異なる場合は、`deploy/systemd/puma.service`、`deploy/nginx/blog_app.conf`、この手順の3か所を同じ値へ変更してください。存在しないRubyパスはunitへ固定していません。unitは `deploy` ユーザーのlogin shellを通して、そのユーザーが設定したrbenvのRubyを選択します。

Capistranoは導入していません。既存のデプロイツールがなかったため、不要な方式変更を避けています。

## EC2の初期準備

### 1. ユーザーとディレクトリ

以下は上記の標準前提を使う例です。既存の `deploy` ユーザーがある場合は新規作成しません。

```bash
sudo useradd --create-home --shell /bin/bash deploy
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app/current
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app/shared
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app/shared/tmp/pids
sudo install -d -o deploy -g deploy -m 0770 /var/www/blog_app/shared/tmp/sockets
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app/shared/log
sudo install -d -o deploy -g deploy -m 0750 /var/www/blog_app/shared/storage
```

リポジトリでは `tmp/pids/.keep` と `log/.keep` がローカル用の空ディレクトリを維持します。本番のPID/socketはリリース外の `shared/tmp` に置き、systemdの `ExecStartPre` でも存在を確認・作成します。Rails/Pumaはjournaldへ出力するため、`shared/log` は将来ファイル出力へ切り替える場合の予約領域であり、現行unitでは使用しません。

Nginxプロセスがsocketへ接続できるよう、Nginx実行ユーザーを `deploy` グループへ加えます。Amazon Linuxの一般的なユーザー名は `nginx`、Ubuntuでは通常 `www-data` です。実機の `nginx.conf` で確認してから一方だけを実行してください。

```bash
sudo usermod -aG deploy nginx
```

グループ変更後はNginxを再起動します。

### 2. RubyとBundler

`deploy` ユーザーでrbenvをセットアップし、login shellからRubyが選択できる状態にします。OSごとのRubyビルド依存パッケージは使用するAMIに合わせて導入してください。

```bash
sudo -iu deploy
rbenv install 4.0.5
rbenv global 4.0.5
gem install bundler -v 4.0.17
ruby -v
bundle -v
exit
```

すでにrbenv管理のRuby 4.0.5がある場合、再インストールは不要です。system Ruby、RVM、miseを使う環境ではunitの `ExecStart` を実機で確認できる起動方法へ変更してください。

### 3. コードと永続データ

対象リビジョンを `/var/www/blog_app/current` に配置します。Active Storageのローカル保存を継続する場合、リリース内の `storage` を退避してから共有領域へlinkします。最初の空ディレクトリでも退避しておくと戻せます。

```bash
sudo -u deploy mv /var/www/blog_app/current/storage /var/www/blog_app/current/storage.release
sudo -u deploy ln -s /var/www/blog_app/shared/storage /var/www/blog_app/current/storage
```

アプリをリリース単位で配置する運用では、`current` を対象リリースへのsymlinkにして構いません。Nginxとsystemdはどちらも同じ `current` を参照します。

### 4. 環境変数と秘密情報

exampleをコピーし、実ファイルはEC2だけに置きます。

```bash
sudo install -d -o root -g root -m 0755 /etc/blog_app
sudo install -o root -g root -m 0600 deploy/environment.example /etc/blog_app/environment
sudoedit /etc/blog_app/environment
```

`/etc/blog_app/environment` へ本番環境に応じて `DATABASE_URL` またはPostgreSQL接続変数、および必要なら `RAILS_MASTER_KEY` を設定します。値をGit、README、AMI作成ログへ記録しないでください。AWS access keyやSSH秘密鍵もこのリポジトリへ追加しません。

主な調整値は次のとおりです。

| 変数 | 既定値 | 用途 |
| --- | --- | --- |
| `RAILS_ENV` | development（unitはproduction） | Rails environment |
| `WEB_CONCURRENCY` | 1 | Puma worker数 |
| `RAILS_MAX_THREADS` | 3 | workerごとの最大thread数 |
| `RAILS_MIN_THREADS` | 最大thread数と同値 | workerごとの最小thread数 |
| `DB_POOL` | `RAILS_MAX_THREADS` と同値 | workerごとのDB connection上限 |
| `PORT` | 3000 | TCP bind時のloopback port |
| `PUMA_BIND` | `tcp://127.0.0.1:${PORT}` | TCPまたはUnix socket |
| `PIDFILE` | `tmp/pids/server.pid` | Puma PID |
| `PUMA_STATE_PATH` | `tmp/pids/puma.state` | Puma state |
| `PUMA_PRELOAD_APP` | false | 複数worker時のpreload |
| `RAILS_ASSUME_SSL` | false | upstreamでTLS終端する場合 |
| `RAILS_FORCE_SSL` | false | RailsでHTTPS redirectする場合 |

1 workerが同時に使用できるDB接続数は既定でthread数と同じ3です。インスタンス全体のWeb用接続数は概ね `WEB_CONCURRENCY × DB_POOL` になるため、RDSの上限とEC2メモリの両方を確認して増やしてください。

preloadは既定で無効です。複数workerで `PUMA_PRELOAD_APP=true` にした場合、Puma設定はfork前のActive Record接続を破棄し、worker boot後に再接続します。

### 5. Gem、アセット、DB

`deploy` ユーザーのlogin shellで実行します。Webpacker 5がNode.jsのOpenSSL互換設定を必要とするため、アセット作成時だけ `NODE_OPTIONS` を指定します。

```bash
sudo -iu deploy
cd /var/www/blog_app/current
bundle config set --local deployment true
bundle config set --local without "development test"
bundle install
yarn install --frozen-lockfile
NODE_OPTIONS=--openssl-legacy-provider RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile
RAILS_ENV=production bundle exec rails db:prepare
exit
```

`db:prepare` は実DBを変更するため、DB snapshot、migration内容、接続先を確認してから実行します。アセット作成の `SECRET_KEY_BASE_DUMMY=1` は一時的なビルド用であり、本番リクエスト処理には使用しません。

## systemd

unitを配置し、構文と実行ユーザーのRubyを確認します。

```bash
sudo install -o root -g root -m 0644 deploy/systemd/puma.service /etc/systemd/system/puma.service
sudo systemd-analyze verify /etc/systemd/system/puma.service
sudo -u deploy -H /usr/bin/bash -lc "cd /var/www/blog_app/current && ruby -v && bundle -v && bundle exec puma --version"
sudo systemctl daemon-reload
sudo systemctl enable puma
sudo systemctl start puma
sudo systemctl status puma
```

操作とログ確認は次のとおりです。

```bash
sudo systemctl stop puma
sudo systemctl start puma
sudo systemctl restart puma
sudo systemctl reload puma
sudo systemctl status puma
sudo journalctl -u puma
sudo journalctl -u puma -f
```

`reload` はPumaへ `USR2` を送りhot restartします。設定変更やRuby/Gem更新後は、確実に新しい環境を読む `restart` を使用してください。

## Nginx

Amazon Linux系の例では次のように配置します。Ubuntuの `sites-available` / `sites-enabled` 構成では、その配布方式に合わせてlinkしてください。

```bash
sudo install -o root -g root -m 0644 deploy/nginx/blog_app.conf /etc/nginx/conf.d/blog_app.conf
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl status nginx
```

設定は静的ファイルとエラーページをNginxから返し、それ以外を同一EC2上のPuma Unix socketへproxyします。Pumaを `0.0.0.0` へ公開しません。

提示設定はHTTP listenerです。ALBでTLS終端する場合はSecurity GroupでEC2のHTTPをALBからだけ許可し、`RAILS_ASSUME_SSL=true` を設定します。Nginx自身でTLS終端する場合は証明書、`listen 443 ssl`、HTTPからHTTPSへのredirectを運用ドメインに合わせて追加し、`RAILS_FORCE_SSL=true` を検討してください。証明書や秘密鍵はGitへ追加しません。

## デプロイ後の確認

新しいコードと依存を配置した後、次を実行します。

```bash
sudo systemctl restart puma
sudo systemctl status puma
sudo nginx -t
sudo systemctl reload nginx
curl --fail --show-error http://127.0.0.1/up
sudo journalctl -u puma -n 100 --no-pager
sudo tail -n 100 /var/log/nginx/blog_app.error.log
```

さらにALBまたは公開URL経由で、一覧、作成、更新、削除、画像upload、静的asset、HTTPS、WebSocketを手動確認します。AWS Security Group、IAM、RDS、ALB、DNS、証明書はこのリポジトリの外部設定であり、別途確認が必要です。

## トラブルシューティング

### Nginxが502を返す

```bash
sudo systemctl status puma
sudo journalctl -u puma -n 100 --no-pager
sudo ls -ld /var/www/blog_app/shared/tmp/sockets
sudo ls -l /var/www/blog_app/shared/tmp/sockets/puma.sock
id nginx
```

systemdの `PUMA_BIND` とNginx upstreamが同じsocketを示すこと、Nginxユーザーが `deploy` groupに所属することを確認します。

### PIDまたはsocketが残って起動できない

まずPumaプロセスの有無を `systemctl status puma` で確認します。実プロセスがないと確認できた場合だけ、残存する `puma.pid` または `puma.sock` を退避して再起動します。稼働中プロセスのファイルを削除しないでください。

### DB接続が枯渇する

`WEB_CONCURRENCY × DB_POOL` とRDS側の最大接続数を比較します。`DB_POOL` は `RAILS_MAX_THREADS` 未満にしないでください。worker数を増やす前にEC2メモリも確認します。

### RubyまたはBundlerが見つからない

```bash
sudo -u deploy -H /usr/bin/bash -lc "ruby -v && bundle -v"
```

失敗する場合は `deploy` ユーザーのlogin shellでrbenv初期化を修正するか、実機で確認できたRuby管理方式に合わせてunitの `ExecStart` を変更します。

## ロールバック

`current` symlinkを使用する場合は、直前のreleaseへ戻した後にPumaをrestartし、NginxのrootとPumaのWorkingDirectoryが同じreleaseを指すことを確認します。DB migrationはコードの切り戻しだけでは戻らないため、互換性のあるmigration設計、事前snapshot、必要に応じた個別rollback手順を用意してください。

このリポジトリには変更前からUnicornが存在しないため、Unicorn serviceへの切り戻し手順はありません。Puma unitを導入する前のEC2固有設定が別管理されている場合は、その実物を退避してから切り替えてください。

## AWS検証について

このリポジトリだけではAWSアカウント、EC2、RDS、ALB、DNS、証明書へ接続できません。したがって、EC2上の `systemd-analyze verify`、`nginx -t`、socket権限、実RDS migration、ALB/HTTPS、公開URLの疎通は、対象AWS環境で必ず手動検証してください。
