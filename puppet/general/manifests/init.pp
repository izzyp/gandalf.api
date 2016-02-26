class sethostname(
  $host_name = undef
) {
  file { "/etc/hostname":
    ensure => present,
    owner => root,
    group => root,
    mode => 644,
    content => "$host_name\n",
    notify => Exec["set-hostname"],
  }
  exec { "set-hostname":
    command => "/bin/hostname -F /etc/hostname",
    unless => "/usr/bin/test `hostname` = `/bin/cat /etc/hostname`",
  }
}

node default {
  $host_name = "gandalf.dev"
  $nginx_configuration_file = 'local'
  $dhparam = undef
  $ssh_port = 'Port 22'

  include stdlib
  include apt
  include composer

  class { 'sethostname' :
    host_name => $host_name
  }

  package {'install uuid-runtime':
    name    => 'uuid-runtime',
    ensure  => installed,
  }
  class {'php56':} -> class{ 'mongo_3': }

  package { "openssh-server": ensure => "installed" }

  service { "ssh":
    ensure => "running",
    enable => "true",
    require => Package["openssh-server"]
  }

  file_line { 'change_ssh_port':
    path  => '/etc/ssh/sshd_config',
    line  => $ssh_port,
    match => '^Port *',
    notify => Service["ssh"]
  }

  class { 'nginx':
    daemon_user => 'www-data',
    worker_processes => 4,
    pid => '/run/nginx.pid',
    worker_connections => 1024,
    multi_accept => 'on',
    events_use => 'epoll',
    sendfile => 'on',
    http_tcp_nopush => 'on',
    http_tcp_nodelay => 'on',
    keepalive_timeout => '65',
    types_hash_max_size => '2048',
    server_tokens => 'off',
    ssl_dhparam => $dhparam
  }

  file { "gandalf_config":
    path => "/etc/nginx/sites-enabled/gandalf.api.conf",
    content => "
    server {
    listen 80;
    server_name gandalf.dev;
    root /www/gandalf.api/public;
    include /www/gandalf.api/config/nginx/nginx.conf;
}
    ",
    notify => Service["nginx"]
  }
}