define nodeapp::instance (
  $entry_point,
  $log_dir = undef,
  $npm_install_dir = undef,
  $app_name = $name,
  $node_path = undef,
  $watch_config_file = undef,
  $time_zone = undef,
  $user = undef,
  $group = undef,
  $redirect_logs = true,
  $npm_install_args = '--unsafe-perm'
) {
  include upstart
  include nodeapp

  $node_path_cmd = $node_path ? {
    undef => '',
    default => "export NODE_PATH=${node_path} && "
  }

  $time_zone_cmd = $time_zone ? {
    undef => '',
    default => "export TZ=${time_zone} && "
  }

  if $log_dir != undef {
    $log_file = "${log_dir}/${app_name}.log"
    file { $log_file:
      ensure => file,
      mode => 0644,
      require => File[$log_dir],
      before => Upstart::Job[$app_name]
    }
  }

  if $npm_install_dir != undef {
    exec { "${app_name}-node-modules":
      command => "npm install ${npm_install_dir} ${npm_install_args}",
      cwd => $npm_install_dir,
      before => Upstart::Job[$app_name],
      notify => Service[$app_name]
    }
  }

  if $user != undef and $group != undef {
    group { $group:
      ensure => present,
      system => true,
    }

    user { $user:
      ensure => present,
      gid => $group,
      system => true,
      shell => '/bin/false',
      require => Group[$group],
      before => Upstart::Job[$app_name]
    }
  }

  if $redirect_logs == true and $log_dir != undef {
    $log_redirects = ">> ${log_file} 2>> ${log_file}"
  } else {
    $log_redirects = ""
  }

  upstart::job { $app_name:
    description => "Node app for ${app_name}",
    respawn => true,
    respawn_limit => '10 5',
    user => $user,
    group => $group,
    script => "${node_path_cmd}${time_zone_cmd}node ${entry_point} ${log_redirects}\n"
  }

  if $watch_config_file != undef {
    $watch_service = "${app_name}_watcher"
    $app_watcher_dir = "${nodeapp::watcher_dir}/${app_name}"
    $watch_script = "${app_watcher_dir}/${watch_service}.js"
    $package_json = "${app_watcher_dir}/package.json"

    # copy the watcher file to a unique place
    file { $app_watcher_dir:
      ensure => directory,
    }

    file { $watch_script:
      ensure => present,
      source => 'puppet:///modules/nodeapp/watcher.js',
      require => File[$app_watcher_dir],
    }

    file { $package_json:
      ensure => present,
      content => template('nodeapp/package.json.erb'),
      require => File[$app_watcher_dir],
    }

    nodeapp::instance { $watch_service:
      entry_point => "${watch_script} ${watch_config_file}",
      log_dir => $log_dir,
      npm_install_dir => $app_watcher_dir,
      require => [ File[$watch_script], File[$package_json] ],
    }
  }
}