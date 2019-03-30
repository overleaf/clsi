spawn = require("child_process").spawn
logger = require "logger-sharelatex"

logger.info "using standard command runner"

module.exports = CommandRunner =
	run: (project_id, command, directory, image, timeout, environment, callback = (error, output) ->) ->
		logger.log project_id: project_id, command: command, directory: directory, "running command"
		command = ((if arg.replace? then arg.replace('$COMPILE_DIR', directory) else arg) for arg in command)
		logger.warn "timeouts and sandboxing are not enabled with CommandRunner"

		# merge environment settings
		env = {}
		env[key] = value for key, value of process.env
		env[key] = value for key, value of environment

		output = { stdout: "", stderr: "" }

		# run command as detached process so it has its own process group (which can be killed if needed)
		proc = spawn command[0], command.slice(1), stdio: ["inherit", "pipe", "pipe"], cwd: directory, detached: true, env: env

		# places for the output pipes to connect to
		proc.stdout.setEncoding 'utf8'
		proc.stdout.on 'data', (data) ->
			console.log data
			output.stdout = output.stdout.concat data

		proc.stderr.setEncoding 'utf8'
		proc.stderr.on 'data', (data) ->
			console.error data
			output.stderr = output.stderr.concat data

		proc.on "error", (err)->
			logger.err err:err, project_id:project_id, command: command, directory: directory, "error running command"
			callback(err)

		proc.on "close", (code, signal) ->
			logger.info code:code, signal:signal, project_id:project_id, "command exited"
			if signal is 'SIGTERM' # signal from kill method below
				err = new Error("terminated")
				err.terminated = true
				return callback(err, output)
			else if code is 1 # exit status from chktex
				err = new Error("exited")
				err.code = code
				return callback(err, output)
			else
				callback(null, output)

		return proc.pid # return process id to allow job to be killed if necessary

	kill: (pid, callback = (error) ->) ->
		try
			process.kill -pid # kill all processes in group
		catch err
			return callback(err)
		callback()
