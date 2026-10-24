threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

# Exit cleanly (code 0) on SIGTERM, e.g. when Vercel scales the container down.
raise_exception_on_sigterm false
