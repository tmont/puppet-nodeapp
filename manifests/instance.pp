define nodeapp::instance (
  $entry_point,
  $log_dir,
  $npm_install_dir = undef,
  $app_name = $name,
  $node_path = undef,
  $watch_config_file = undef,
  $time_zone = undef
) {
  include upstart
  include nodeapp

  $log_file = "${log_dir}/${app_name}.log"
  $node_path_cmd = $node_path ? {
    undef => '',
    default => "export NODE_PATH=${node_path} && "
  }

  $time_zone_cmd = $time_zone ? {
    undef => '',
    default => "export TZ=${time_zone} && "
  }

  file { $log_file:
    ensure => file,
    mode => 0644,
    require => File[$log_dir],
  }

  if $npm_install_dir != undef {
    exec { "${app_name}-node-modules":
      command => "npm install ${npm_install_dir} --unsafe-perm --production",
      cwd => $npm_install_dir,
      before => Upstart::Job[$app_name],
    }
  }

  upstart::job { $app_name:
    description => "Node app for ${app_name}",
    respawn => true,
    respawn_limit => '10 5',
    script => "${node_path_cmd}${time_zone_cmd}node ${entry_point} >> ${log_file} 2>> ${log_file}\n"
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