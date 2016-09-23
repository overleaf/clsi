Path = require "path"

module.exports =
	# Options are passed to Sequelize.
	# See http://sequelizejs.com/documentation#usage-options for details
	mysql:
		clsi:
			database: process.env.CLSI_DB_DATABASE || "clsi"
			username: process.env.CLSI_DB_USER ||"clsi"
			password: process.env.CLSI_DB_PASSWORD || null
			dialect: "sqlite"
			storage: process.env.CLSI_DB_STORAGE || Path.resolve(__dirname + "/../db.sqlite")

	path:
		compilesDir:  process.env.CLSI_PATH_COMPILES_DIR || Path.resolve(__dirname + "/../compiles")
		clsiCacheDir: process.env.CLSI_PATH_CLSI_CACHE_DIR || Path.resolve(__dirname + "/../cache")
		synctexBaseDir: process.env.CLSI_PATH_SYNCTEX_BASE_DIR || (project_id) -> Path.join(@compilesDir, project_id)

	# clsi:
	# 	strace: true
	# 	archive_logs: true
	# 	commandRunner: "docker-runner-sharelatex"
	# 	docker:
	# 		image: "quay.io/sharelatex/texlive-full"
	# 		env:
	# 			PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/texlive/2013/bin/x86_64-linux/"
	# 			HOME: "/tmp"
	# 		modem:
	# 			socketPath: false
	# 		user: "tex"
	# 		latexmkCommandPrefix: []
	# 		# latexmkCommandPrefix: ["/usr/bin/time", "-v"]         # on Linux
	# 		# latexmkCommandPrefix: ["/usr/local/bin/gtime", "-v"]  # on Mac OSX, installed with `brew install gnu-time`

	internal:
		clsi:
			port: process.env.CLSI_INTERNAL_PORT || 3013
			load_port: process.env.CLSI_INTERNAL_LOAD_PORT || 3044
			host: process.env.CLSI_INTERNAL_HOST || "localhost"

	
	apis:
		clsi:
			url: process.env.CLSI_APIS_URL || "http://localhost:3013"
			
	smokeTest: process.env.CLSI_SMOKE_TEST == "true"
	project_cache_length_ms: process.env.CLSI_CACHE_LENGHT_MS || 1000 * 60 * 60 * 24
	parallelFileDownloads: process.env.CLSI_CACHE_LENGHT_MS || 1
