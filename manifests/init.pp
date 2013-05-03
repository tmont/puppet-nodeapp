class nodeapp ($watcher_dir = '/opt/node-watcher') {
  file { $watcher_dir:
    ensure => directory
  }
}