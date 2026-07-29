require "test_helper"

class DeploymentConfigurationTest < ActiveSupport::TestCase
  setup do
    @nginx = Rails.root.join("deploy/nginx/blog_app.conf").read
    @puma = Rails.root.join("config/puma.rb").read
    @systemd = Rails.root.join("deploy/systemd/puma.service").read
  end

  test "Nginx and systemd use the same Puma socket" do
    puma_socket = @systemd.match(
      /^Environment="PUMA_BIND=unix:\/\/(?<path>[^?"]+)/
    )&.[](:path)
    nginx_socket = @nginx.match(
      /^\s*server unix:(?<path>[^ ;]+)/
    )&.[](:path)

    assert puma_socket, "PUMA_BIND must define a Unix socket"
    assert nginx_socket, "Nginx upstream must define a Unix socket"
    assert_equal puma_socket, nginx_socket
  end

  test "Puma environment and systemd use the same PID file" do
    environment_pid = @systemd.match(
      /^Environment=PIDFILE=(?<path>\S+)/
    )&.[](:path)
    systemd_pid = @systemd.match(/^PIDFile=(?<path>\S+)/)&.[](:path)

    assert environment_pid, "PIDFILE environment must be configured"
    assert systemd_pid, "systemd PIDFile must be configured"
    assert_equal environment_pid, systemd_pid
  end

  test "Nginx and systemd use the same current release directory" do
    working_directory = @systemd.match(
      /^WorkingDirectory=(?<path>\S+)/
    )&.[](:path)
    public_root = @nginx.match(/^\s*root (?<path>[^;]+);/)&.[](:path)

    assert working_directory, "WorkingDirectory must be configured"
    assert public_root, "Nginx public root must be configured"
    assert_equal "#{working_directory}/public", public_root
  end

  test "Puma is not exposed on every network interface by default" do
    assert_includes @puma, "tcp://127.0.0.1:"
    assert_not_includes @puma, "0.0.0.0"
  end

  test "systemd runs Puma as a non-root user with restart safeguards" do
    assert_match(/^User=(?!root$)\S+/, @systemd)
    assert_match(/^Group=(?!root$)\S+/, @systemd)
    assert_includes @systemd, "ExecStart=/usr/bin/bash -lc \"exec bundle exec puma -C config/puma.rb\""
    assert_includes @systemd, "Restart=on-failure"
    assert_includes @systemd, "NoNewPrivileges=true"
  end

  test "database pool defaults to the Puma maximum thread count" do
    expected_pool = Integer(ENV.fetch("DB_POOL") { ENV.fetch("RAILS_MAX_THREADS", 3) })
    database_config = ActiveRecord::Base.configurations.configs_for(
      env_name: Rails.env,
      name: "primary"
    ).configuration_hash

    assert_equal expected_pool, database_config.fetch(:max_connections)
  end
end
