const Path = require('path')

module.exports = {
  // Options are passed to Sequelize.
  // See http://sequelizejs.com/documentation#usage-options for details
  mysql: {
    clsi: {
      database: 'clsi',
      username: 'clsi',
      dialect: 'sqlite',
      storage:
        process.env.SQLITE_PATH || Path.resolve(__dirname, '../db/db.sqlite'),
      pool: {
        max: 1,
        min: 1,
      },
      retry: {
        max: 10,
      },
    },
  },

  compileSizeLimit: process.env.COMPILE_SIZE_LIMIT || '7mb',

  processLifespanLimitMs:
    parseInt(process.env.PROCESS_LIFE_SPAN_LIMIT_MS) || 60 * 60 * 24 * 1000 * 2,

  catchErrors: process.env.CATCH_ERRORS === 'true',

  path: {
    compilesDir: Path.resolve(__dirname, '../compiles'),
    outputDir: Path.resolve(__dirname, '../output'),
    clsiCacheDir: Path.resolve(__dirname, '../cache'),
    synctexBaseDir(projectId) {
      // HACK: The files are referenced as `/COMPILES_DIR/PROJECT_ID/./main.tex` in synctex.
      return Path.join(this.compilesDir, projectId) + '/.'
    },
  },

  internal: {
    clsi: {
      port: 3013,
      host: process.env.LISTEN_ADDRESS || 'localhost',
    },

    load_balancer_agent: {
      report_load: true,
      load_port: 3048,
      local_port: 3049,
    },
  },
  apis: {
    clsi: {
      url: `http://${process.env.CLSI_HOST || 'localhost'}:3013`,
    },
    clsiPerf: {
      host: `${process.env.CLSI_PERF_HOST || 'localhost'}:${
        process.env.CLSI_PERF_PORT || '3043'
      }`,
    },
  },

  smokeTest: process.env.SMOKE_TEST || false,
  project_cache_length_ms: 1000 * 60 * 60 * 24,
  parallelFileDownloads: process.env.FILESTORE_PARALLEL_FILE_DOWNLOADS || 1,
  parallelSqlQueryLimit: process.env.FILESTORE_PARALLEL_SQL_QUERY_LIMIT || 1,
  filestoreDomainOveride: process.env.FILESTORE_DOMAIN_OVERRIDE,
  texliveImageNameOveride: process.env.TEX_LIVE_IMAGE_NAME_OVERRIDE,
  texliveOpenoutAny: process.env.TEXLIVE_OPENOUT_ANY,
  sentry: {
    dsn: process.env.SENTRY_DSN,
  },

  enablePdfCaching: process.env.ENABLE_PDF_CACHING === 'true',
  enablePdfCachingDark: process.env.ENABLE_PDF_CACHING_DARK === 'true',
  pdfCachingMinChunkSize:
    parseInt(process.env.PDF_CACHING_MIN_CHUNK_SIZE, 10) || 1024,
  pdfCachingMaxProcessingTime:
    parseInt(process.env.PDF_CACHING_MAX_PROCESSING_TIME, 10) || 10 * 1000,
}

if (process.env.ALLOWED_COMPILE_GROUPS) {
  try {
    module.exports.allowedCompileGroups =
      process.env.ALLOWED_COMPILE_GROUPS.split(' ')
  } catch (error) {
    console.error(error, 'could not apply allowed compile group setting')
    process.exit(1)
  }
}

if (process.env.DOCKER_RUNNER) {
  let seccompProfilePath
  module.exports.clsi = {
    dockerRunner: process.env.DOCKER_RUNNER === 'true',
    docker: {
      runtime: process.env.DOCKER_RUNTIME,
      image:
        process.env.TEXLIVE_IMAGE || 'quay.io/sharelatex/texlive-full:2017.1',
      env: {
        HOME: '/tmp',
      },
      socketPath: '/var/run/docker.sock',
      user: process.env.TEXLIVE_IMAGE_USER || 'tex',
    },
    optimiseInDocker: true,
    expireProjectAfterIdleMs: 24 * 60 * 60 * 1000,
    checkProjectsIntervalMs: 10 * 60 * 1000,
  }

  try {
    // Override individual docker settings using path-based keys, e.g.:
    // compileGroupDockerConfigs = {
    //    priority: { 'HostConfig.CpuShares': 100 }
    //    beta: { 'dotted.path.here', 'value'}
    // }
    const compileGroupConfig = JSON.parse(
      process.env.COMPILE_GROUP_DOCKER_CONFIGS || '{}'
    )
    // Automatically clean up wordcount and synctex containers
    const defaultCompileGroupConfig = {
      wordcount: { 'HostConfig.AutoRemove': true },
      synctex: { 'HostConfig.AutoRemove': true },
    }
    module.exports.clsi.docker.compileGroupConfig = Object.assign(
      defaultCompileGroupConfig,
      compileGroupConfig
    )
  } catch (error) {
    console.error(error, 'could not apply compile group docker configs')
    process.exit(1)
  }

  try {
    seccompProfilePath = Path.resolve(__dirname, '../seccomp/clsi-profile.json')
    module.exports.clsi.docker.seccomp_profile = JSON.stringify(
      JSON.parse(require('fs').readFileSync(seccompProfilePath))
    )
  } catch (error) {
    console.error(
      error,
      `could not load seccomp profile from ${seccompProfilePath}`
    )
    process.exit(1)
  }

  if (process.env.APPARMOR_PROFILE) {
    try {
      module.exports.clsi.docker.apparmor_profile = process.env.APPARMOR_PROFILE
    } catch (error) {
      console.error(error, 'could not apply apparmor profile setting')
      process.exit(1)
    }
  }

  if (process.env.ALLOWED_IMAGES) {
    try {
      module.exports.clsi.docker.allowedImages =
        process.env.ALLOWED_IMAGES.split(' ')
    } catch (error) {
      console.error(error, 'could not apply allowed images setting')
      process.exit(1)
    }
  }

  module.exports.path.synctexBaseDir = () => '/compile'

  module.exports.path.sandboxedCompilesHostDir = process.env.COMPILES_HOST_DIR

  module.exports.path.synctexBinHostPath = process.env.SYNCTEX_BIN_HOST_PATH
}
