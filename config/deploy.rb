# Capistranoのバージョン
lock "~> 3.20.1"

# アプリ名
set :application, "aws_deploy_task"

# GitHubのリポジトリ
set :repo_url, "https://github.com/arduino0420/aws_deploy_task.git"

# デプロイするブランチ
set :branch, "master"

# EC2のどこにアプリを配置するか
set :deploy_to, "/home/ec2-user/apps/aws_deploy_task"

# EC2で使うRuby
set :rbenv_type, :user
set :rbenv_ruby, "4.0.5"

# 本番ではdevelopment/test用Gemを入れない
set :bundle_without, %w[development test].join(" ")

# CapistranoがEC2でコマンドを実行するときに渡す環境変数
set :default_env, {
  "NODE_OPTIONS" => "--openssl-legacy-provider",
  "POSTGRES_HOST" => ENV.fetch("POSTGRES_HOST"),
  "POSTGRES_USER" => ENV.fetch("POSTGRES_USER"),
  "BLOG_APP_DATABASE_PASSWORD" => ENV.fetch("BLOG_APP_DATABASE_PASSWORD"),
  "SECRET_KEY_BASE" => ENV.fetch("SECRET_KEY_BASE")
}

set :puma_service_unit_env_vars, [
  "POSTGRES_HOST=#{ENV.fetch("POSTGRES_HOST")}",
  "POSTGRES_USER=#{ENV.fetch("POSTGRES_USER")}",
  "BLOG_APP_DATABASE_PASSWORD=#{ENV.fetch("BLOG_APP_DATABASE_PASSWORD")}",
  "SECRET_KEY_BASE=#{ENV.fetch("SECRET_KEY_BASE")}"
]

# デプロイ履歴を3世代残す
set :keep_releases, 3

# デプロイをまたいで残しておくディレクトリ
append :linked_dirs,
       "log",
       "tmp/pids",
       "tmp/cache",
       "tmp/sockets",
       "storage"