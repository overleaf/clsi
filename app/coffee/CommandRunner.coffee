child_process = require("child_process")
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
Path = require "path"

if settings.clsi?.commandRunner?
	CommandRunner = require settings.clsi?.commandRunner
else
	CommandRunner =
		run: (project_id, command, limits = {}, callback = (error, output) ->) ->
			directory = Path.join(settings.path.compilesDir, project_id)

			command = (arg.replace('$COMPILE_DIR', directory) for arg in command)
			logger.log project_id: project_id, command: command, directory: directory, "running command"
			logger.warn "timeouts and sandboxing are not enabled with CommandRunner"

			proc = child_process.spawn command[0], command.slice(1), cwd: directory
			
			stdout = ""
			stderr = ""
			proc.stdout.on "data", (chunk) -> stdout += chunk.toString()
			proc.stderr.on "data", (chunk) -> stderr += chunk.toString()
			
			proc.on "close", () ->
				callback(null, {stdout, stderr})
				
		clearProject: (project_id, callback = (error) ->) ->
			callback()

module.exports = CommandRunner
