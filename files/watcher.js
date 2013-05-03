require('colors');
var	exec = require('child_process').exec,
	gargoyle = require('gargoyle'),
	async = require('async'),
	config = require(process.argv[2]);

var restarting = false;

config.locations.forEach(function(location) {
	gargoyle.monitor(location.dir, location.options, function(err, monitor) {
		if (err) {
			console.error('failed to configure gargoyle', err);
			throw err;
		}

		var fileColor = 'grey';
		monitor.on('create', function(filename) {
			console.log('[' + 'create'.green + '] ' + filename[fileColor]);
			restart();
		});
		monitor.on('modify', function(filename) {
			console.log('[' + 'modify'.blue + '] ' + filename[fileColor]);
			restart();
		});
		monitor.on('delete', function(filename) {
			console.log('[' + 'delete'.red + '] ' + filename[fileColor]);
			restart();
		});
	});
});

function restart() {
	if (restarting) {
		console.log('Skipping...');
		return;
	}

	restarting = true;

	async.forEachSeries(config.services, function(service, next) {
		doServiceAction(service, 'status', function(err, stdout, stderr) {
			if (err) {
				console.error(('Unable to get status for service: ' + service).red);
				next(err);
				return;
			}

			// Is the service stopped?
			if (stdout.toString().indexOf(service + ' stop/waiting') === 0) {
				doServiceAction(service, 'start', next);
			} else if (stdout.toString().indexOf(service + ' start/running') === 0) {
				doServiceAction(service, 'restart', next);
			}
		});
	}, function(err) {
		if (err) {
			console.error('Unknown state, exiting!');
			throw err;
		}

		restarting = false;
	});

	function doServiceAction(service, action, callback) {
		exec(action + ' ' + service, function(err, stdout, stderr) {
			if (err) {
				console.error(('Unable to execute service action: ' + service + ' ' + action).red);
			} else {
				console.log('Service ' + service + ' ' + action + 'ed...');
			}

			callback(err, stdout, stderr);
		});
	}
}

restart();
