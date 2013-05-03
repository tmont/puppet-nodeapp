# puppet-nodeapp
This is a puppet module for configuring a NodeJS application. It does the following:

* Creates a service for the node application
* Creates a service that watches for changes and restarts the app as necessary
* Configures logging (from `stdout` and `stderr`)

Only supports Ubuntu, and whatever else uses upstart for its service configuration.

## Dependencies
This module depends on the [Upstart module](https://github.com/bison/puppet-upstart). You'll need
to download it manually since it's not on the Puppet Forge.

## Usage
```puppet
nodeapp::instance { 'my-sweet-node-app':
	# required: the script to run to start your application
	entry_point => '/path/to/app.js',

	# required: the directory to store the logs
	# note that you are responsible for making sure this directory exists
	log_dir => '/path/to/logs',

	# optional: if set, this will run "npm install ${npm_install_dir} --unsafe-perm"
	npm_install_dir => '/path/to/app',

	# optional: defaults to $name
	app_name => 'my-sweet-node-app',

	# optional: sets the NODE_PATH environment variable
	node_path => '/path/to/node/stuff:/another/one',

	# optional: if given, will set up a watch service that detects changes
	# to the app and restarts the service automatically
	watch_config_file => '/path/to/watcher-config.js'
}
```

When this runs, it will create the following services:

* `my-sweet-node-app`
* `my-sweet-node-app_watcher`

These can be statused/restarted/stopped using the service commands, e.g.
`sudo restart my-sweet-node-app`.

The logs for the watch service will be in `$log_dir/my-sweet-node-app_watcher.log`.

### Setting up the watch service
The watcher app uses [Gargoyle](https://github.com/tmont/gargoyle) to handle
file and directory monitoring. See the documentation over there for possible
values for the `options` object.

The watch service requires a configuration file. It should look something like this:

```javascript
var path = require('path');

module.exports = {
	locations: [
		{
			dir: '/path/to/code/to/watch',

			// see Gargoyle documentation for more info on these options
			options: {
				type: 'watch',
				exclude: function(filename, stat) {
					var basename = path.basename(filename);
					if (basename.charAt(0) === '.') {
						return true;
					}

					return false;
				}
			}
		},

		//etc.
	],

	services: [
		'my-sweet-node-app'
	]
};
```

