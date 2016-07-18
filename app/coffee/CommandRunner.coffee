spawn = require("child_process").spawn
logger = require "logger-sharelatex"

logger.info "using standard command runner"

module.exports = CommandRunner =
	run: (project_id, command, directory, image, timeout, callback = (error) ->) ->
		command = "timeout #{60 * 5}s #{command}"
		command = (arg.replace('$COMPILE_DIR', directory) for arg in command)
		logger.log project_id: project_id, command: command, directory: directory, "running command"
		logger.warn "timeouts and sandboxing are not enabled with CommandRunner"

		proc = spawn command[0], command.slice(1), stdio: "inherit", cwd: directory
		proc.on "error", (err)->
			logger.err err:err, project_id:project_id, command: command, directory: directory, "error running command"
			callback(err)
		proc.on "close", () ->
			callback()
