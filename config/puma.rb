# Puma serves each worker with a thread pool. The default of three is modest
# for small EC2 instances and can be changed without editing this file.
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 3))
min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", max_threads))
workers_count = Integer(ENV.fetch("WEB_CONCURRENCY", 1))

raise "RAILS_MIN_THREADS must not exceed RAILS_MAX_THREADS" if min_threads > max_threads
raise "WEB_CONCURRENCY must be at least 1" if workers_count < 1

threads min_threads, max_threads
workers workers_count if workers_count > 1

environment ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development"))

# Local development defaults to loopback TCP. The systemd unit overrides this
# with the Unix socket shared with Nginx. PORT remains available for local use.
bind ENV.fetch("PUMA_BIND", "tcp://127.0.0.1:#{ENV.fetch('PORT', 3000)}")

pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")
state_path ENV.fetch("PUMA_STATE_PATH", "tmp/pids/puma.state")

# Preloading is opt-in because EC2 memory sizes vary. When enabled for multiple
# workers, discard inherited database connections and reconnect after forking.
if workers_count > 1 && ENV["PUMA_PRELOAD_APP"] == "true"
  preload_app!

  before_fork do
    ActiveRecord::Base.connection_handler.clear_all_connections! if defined?(ActiveRecord::Base)
  end

  before_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
  end
end

# Allow Puma to be restarted by `bin/rails restart`.
plugin :tmp_restart
