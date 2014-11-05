spawn = require("child_process").spawn
logger = require "logger-sharelatex"

module.exports = CommandRunner =
	run: (project_id, command, directory, limits = {}, callback = (error, output) ->) ->
		command = (arg.replace('$COMPILE_DIR', directory) for arg in command)
		logger.log project_id: project_id, command: command, directory: directory, "running command"
		logger.warn "timeouts and sandboxing are not enabled with CommandRunner"

		proc = spawn command[0], command.slice(1), cwd: directory
		
		stdout = ""
		stderr = ""
		proc.stdout.on "data", (chunk) -> stdout += chunk.toString()
		proc.stderr.on "data", (chunk) -> stderr += chunk.toString()
		
		proc.on "close", () ->
			callback(null, {stdout, stderr})