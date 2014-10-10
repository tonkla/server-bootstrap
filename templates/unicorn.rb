worker_processes 4
working_directory "/var/www/DOMAIN/htdocs"

timeout 30

listen "/tmp/unicorn.DOMAIN.sock"

pid "/tmp/unicorn.DOMAIN.pid"

stderr_path "/var/www/DOMAIN/logs/unicorn.stderr.log"
stdout_path "/var/www/DOMAIN/logs/unicorn.stdout.log"
