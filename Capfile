# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# Git
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

# rbenv
require "capistrano/rbenv"

# Bundler
require "capistrano/bundler"

# Rails
require "capistrano/rails/assets"
require "capistrano/rails/migrations"

# Puma
require "capistrano/puma"
install_plugin Capistrano::Puma
install_plugin Capistrano::Puma::Systemd

# Load custom tasks
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }