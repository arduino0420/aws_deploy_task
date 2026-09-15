namespace :yarn do
  desc "Install JavaScript dependencies"
  task :install do
    on roles(:app) do
      within release_path do
        execute :yarn, "install", "--frozen-lockfile"
      end
    end
  end
end

before "deploy:assets:precompile", "yarn:install"