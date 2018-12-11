# Class: nginx
#
# This module manages nginx
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
#
class nginx inherits docker {

  $docker_shared = $docker_::docker_shared
  $docker_dir = $docker_::docker_dir

  package { ["nginx","fcgiwrap","nginx-common"]:
    ensure  => latest,
    notify  => Service["nginx"],
  }

  service { ["nginx","fcgiwrap"]:
    ensure => running,
  }
  Service["fcgiwrap"] -> Service["nginx"]

  file { "/var/www":
    ensure => directory,
  }
  File["/var/www"] -> Mount["/var/www"]

  mount { "/var/www":
      ensure  => mounted,
      atboot  => True,
      device  => "/usr/share/nginx/html",
      fstype  => "none",
      options => "rw,bind",
  }

  file { "/var/www/ssl":
    ensure  => directory,
    require => Mount["/var/www"],
  }
  file { "/var/www/ssl/input":
    source => "/etc/puppet/files/ssl.input",
  }

  exec { "gen_nginx_ssl_keys":
    command  => "cat input | openssl req -new -x509 -sha256 -days 365 -nodes -out /var/www/ssl/nginx.pem -keyout /var/www/ssl/nginx.key",
    provider => shell,
    cwd      => "/var/www/ssl",
    user     => root,
    onlyif   => "/usr/bin/test ! -f /var/www/ssl/nginx.pem -o ! -f /var/www/ssl/nginx.key",
    notify   => Service["nginx"],
  }
  File["/var/www/ssl/input"] -> Exec["gen_nginx_ssl_keys"]

  exec { "register_nginx_ssl_keys":
    command  => "echo -n | openssl s_client -showcerts -connect localhost:443 2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >/etc/ssl/certs/ca-nginx.crt && cat /etc/ssl/certs/ca-nginx.crt >>/etc/ssl/certs/ca-certificates.crt",
    provider => shell,
    cwd      => "/etc/ssl/certs",
    user     => root,
    onlyif   => "/usr/bin/test ! -f /etc/ssl/certs/ca-nginx.crt",
    notify   => Service["nginx"],
  }
  Exec["gen_nginx_ssl_keys"] -> Exec["register_nginx_ssl_keys"]


  file { "/etc/nginx/sites-available/default":
    source  => "/etc/puppet/files/nginx.sites.default",
    require => Package["nginx"],
    notify  => Service["nginx"],
  }

}
