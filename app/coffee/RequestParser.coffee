module.exports = RequestParser =
	VALID_COMPILERS: ["pdflatex", "latex", "xelatex", "lualatex", "python", "r", "command"]
	MAX_TIMEOUT:    300  # Seconds
	MAX_MEMORY:     4096 # Mb
	MAX_CPU_SHARES: 4096 # Relative (1024 default)
	MAX_PROCESSES:  1024

	parse: (body, callback = (error, data) ->) ->
		response = {}

		if !body.compile?
			return callback "top level object should have a compile attribute"

		compile = body.compile
		compile.options ||= {}
		
		try
			response.session_id = @_parseAttribute "session_id",
				compile.session_id,
				default: ""
				type: "string"

			response.compiler = @_parseAttribute "compiler",
				compile.options.compiler,
				validValues: @VALID_COMPILERS
				default: "pdflatex"
				type: "string"
			
			response.command = @_parseAttribute "command", 
				compile.options.command
				default: []
				type: "object"
			
			response.env = @_parseAttribute "env", 
				compile.options.env
				default: {}
				type: "object"
				
			response.timeout = @_parseAttribute "timeout",
				compile.options.timeout
				default: RequestParser.MAX_TIMEOUT
				type: "number"
			if response.timeout > RequestParser.MAX_TIMEOUT
				response.timeout = RequestParser.MAX_TIMEOUT
			response.timeout = response.timeout * 1000 # milliseconds
			
			response.memory = @_parseAttribute "memory",
				compile.options.memory
				default: RequestParser.MAX_MEMORY
				type: "number"
			if response.memory > RequestParser.MAX_MEMORY
				response.memory = RequestParser.MAX_MEMORY
				
			response.processes = @_parseAttribute "processes",
				compile.options.processes
				default: RequestParser.MAX_PROCESSES
				type: "number"
			if response.processes > RequestParser.MAX_PROCESSES
				response.processes = RequestParser.MAX_PROCESSES
				
			response.cpu_shares = @_parseAttribute "cpu_shares",
				compile.options.cpu_shares
				default: RequestParser.MAX_CPU_SHARES
				type: "number"
			if response.cpu_shares > RequestParser.MAX_CPU_SHARES
				response.cpu_shares = RequestParser.MAX_CPU_SHARES

			response.resources = (@_parseResource(resource) for resource in (compile.resources or []))
			response.rootResourcePath = @_parseAttribute "rootResourcePath",
				compile.rootResourcePath
				default: "main.tex"
				type: "string"
		catch error
			return callback error

		callback null, response

	_parseResource: (resource) ->
		if !resource.path? or typeof resource.path != "string"
			throw "all resources should have a path attribute"

		if resource.modified?
			modified = new Date(resource.modified)
			if isNaN(modified.getTime())
				throw "resource modified date could not be understood: #{resource.modified}"

		if !resource.url? and !resource.content?
		   	throw "all resources should have either a url or content attribute"
		if resource.content? and typeof resource.content != "string"
			throw "content attribute should be a string"
		if resource.url? and typeof resource.url != "string"
			throw "url attribute should be a string"

		return {
			path: resource.path
			modified: modified
			url: resource.url
			content: resource.content
		}

	_parseAttribute: (name, attribute, options) ->
		if attribute?
			if options.validValues?
				if options.validValues.indexOf(attribute) == -1
					throw "#{name} attribute should be one of: #{options.validValues.join(", ")}"
			if options.type?
				if typeof attribute != options.type
					throw "#{name} attribute should be a #{options.type}"
		else
			return options.default if options.default?
			throw "Default not implemented"
		return attribute

