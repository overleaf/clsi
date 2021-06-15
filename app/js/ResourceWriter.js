/* eslint-disable
    camelcase,
    handle-callback-err,
    no-return-assign,
    no-unused-vars,
    no-useless-escape,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
let ResourceWriter
const UrlCache = require('./UrlCache')
const Path = require('path')
const fs = require('fs')
const async = require('async')
const OutputFileFinder = require('./OutputFileFinder')
const ResourceStateManager = require('./ResourceStateManager')
const Metrics = require('./Metrics')
const logger = require('logger-sharelatex')
const settings = require('settings-sharelatex')

const parallelFileDownloads = settings.parallelFileDownloads || 1

module.exports = ResourceWriter = {
  syncResourcesToDisk(request, basePath, callback) {
    if (callback == null) {
      callback = function (error, resourceList) {}
    }
    if (request.syncType === 'incremental') {
      logger.log(
        { project_id: request.project_id, user_id: request.user_id },
        'incremental sync'
      )
      return ResourceStateManager.checkProjectStateMatches(
        request.syncState,
        basePath,
        function (error, resourceList) {
          if (error != null) {
            return callback(error)
          }
          return ResourceWriter._removeExtraneousFiles(
            resourceList,
            basePath,
            function (error, outputFiles, allFiles) {
              if (error != null) {
                return callback(error)
              }
              return ResourceStateManager.checkResourceFiles(
                resourceList,
                allFiles,
                basePath,
                function (error) {
                  if (error != null) {
                    return callback(error)
                  }
                  return ResourceWriter.saveIncrementalResourcesToDisk(
                    request.project_id,
                    request.resources,
                    basePath,
                    function (error) {
                      if (error != null) {
                        return callback(error)
                      }
                      return callback(null, resourceList)
                    }
                  )
                }
              )
            }
          )
        }
      )
    }
    logger.log(
      { project_id: request.project_id, user_id: request.user_id },
      'full sync'
    )
    UrlCache.createProjectDir(request.project_id, (error) => {
      if (error != null) {
        return callback(error)
      }
      this.saveAllResourcesToDisk(
        request.project_id,
        request.resources,
        basePath,
        function (error) {
          if (error != null) {
            return callback(error)
          }
          return ResourceStateManager.saveProjectState(
            request.syncState,
            request.resources,
            basePath,
            function (error) {
              if (error != null) {
                return callback(error)
              }
              return callback(null, request.resources)
            }
          )
        }
      )
    })
  },

  saveIncrementalResourcesToDisk(project_id, resources, basePath, callback) {
    if (callback == null) {
      callback = function (error) {}
    }
    return this._createDirectory(basePath, (error) => {
      if (error != null) {
        return callback(error)
      }
      const jobs = Array.from(resources).map((resource) =>
        ((resource) => {
          return (callback) =>
            this._writeResourceToDisk(project_id, resource, basePath, callback)
        })(resource)
      )
      return async.parallelLimit(jobs, parallelFileDownloads, callback)
    })
  },

  saveAllResourcesToDisk(project_id, resources, basePath, callback) {
    if (callback == null) {
      callback = function (error) {}
    }
    return this._createDirectory(basePath, (error) => {
      if (error != null) {
        return callback(error)
      }
      return this._removeExtraneousFiles(resources, basePath, (error) => {
        if (error != null) {
          return callback(error)
        }
        const jobs = Array.from(resources).map((resource) =>
          ((resource) => {
            return (callback) =>
              this._writeResourceToDisk(
                project_id,
                resource,
                basePath,
                callback
              )
          })(resource)
        )
        return async.parallelLimit(jobs, parallelFileDownloads, callback)
      })
    })
  },

  _createDirectory(basePath, callback) {
    if (callback == null) {
      callback = function (error) {}
    }
    return fs.mkdir(basePath, function (err) {
      if (err != null) {
        if (err.code === 'EEXIST') {
          return callback()
        } else {
          logger.log({ err, dir: basePath }, 'error creating directory')
          return callback(err)
        }
      } else {
        return callback()
      }
    })
  },

  _removeExtraneousFiles(resources, basePath, _callback) {
    if (_callback == null) {
      _callback = function (error, outputFiles, allFiles) {}
    }
    const timer = new Metrics.Timer('unlink-output-files')
    const callback = function (error, ...result) {
      timer.done()
      return _callback(error, ...Array.from(result))
    }

    return OutputFileFinder.findOutputFiles(resources, basePath, function (
      error,
      outputFiles,
      allFiles
    ) {
      if (error != null) {
        return callback(error)
      }

      const jobs = []
      for (const file of Array.from(outputFiles || [])) {
        ;(function (file) {
          const { path } = file
          let should_delete = true
          if (
            path.match(/^output\./) ||
            path.match(/\.aux$/) ||
            path.match(/^cache\//)
          ) {
            // knitr cache
            should_delete = false
          }
          if (path.match(/^output-.*/)) {
            // Tikz cached figures (default case)
            should_delete = false
          }
          if (path.match(/\.(pdf|dpth|md5)$/)) {
            // Tikz cached figures (by extension)
            should_delete = false
          }
          if (
            path.match(/\.(pygtex|pygstyle)$/) ||
            path.match(/(^|\/)_minted-[^\/]+\//)
          ) {
            // minted files/directory
            should_delete = false
          }
          if (
            path.match(/\.md\.tex$/) ||
            path.match(/(^|\/)_markdown_[^\/]+\//)
          ) {
            // markdown files/directory
            should_delete = false
          }
          if (path.match(/-eps-converted-to\.pdf$/)) {
            // Epstopdf generated files
            should_delete = false
          }
          if (
            path === 'output.pdf' ||
            path === 'output.dvi' ||
            path === 'output.log' ||
            path === 'output.xdv' ||
            path === 'output.stdout' ||
            path === 'output.stderr'
          ) {
            should_delete = true
          }
          if (path === 'output.tex') {
            // created by TikzManager if present in output files
            should_delete = true
          }
          if (should_delete) {
            return jobs.push((callback) =>
              ResourceWriter._deleteFileIfNotDirectory(
                Path.join(basePath, path),
                callback
              )
            )
          }
        })(file)
      }

      return async.series(jobs, function (error) {
        if (error != null) {
          return callback(error)
        }
        return callback(null, outputFiles, allFiles)
      })
    })
  },

  _deleteFileIfNotDirectory(path, callback) {
    if (callback == null) {
      callback = function (error) {}
    }
    return fs.stat(path, function (error, stat) {
      if (error != null && error.code === 'ENOENT') {
        return callback()
      } else if (error != null) {
        logger.err(
          { err: error, path },
          'error stating file in deleteFileIfNotDirectory'
        )
        return callback(error)
      } else if (stat.isFile()) {
        return fs.unlink(path, function (error) {
          if (error != null) {
            logger.err(
              { err: error, path },
              'error removing file in deleteFileIfNotDirectory'
            )
            return callback(error)
          } else {
            return callback()
          }
        })
      } else {
        return callback()
      }
    })
  },

  _writeResourceToDisk(project_id, resource, basePath, callback) {
    if (callback == null) {
      callback = function (error) {}
    }
    return ResourceWriter.checkPath(basePath, resource.path, function (
      error,
      path
    ) {
      if (error != null) {
        return callback(error)
      }
      return fs.mkdir(Path.dirname(path), { recursive: true }, function (
        error
      ) {
        if (error != null) {
          return callback(error)
        }
        // TODO: Don't overwrite file if it hasn't been modified
        if (resource.url != null) {
          return UrlCache.downloadUrlToFile(
            project_id,
            resource.url,
            path,
            resource.modified,
            function (err) {
              if (err != null) {
                logger.err(
                  {
                    err,
                    project_id,
                    path,
                    resource_url: resource.url,
                    modified: resource.modified
                  },
                  'error downloading file for resources'
                )
                Metrics.inc('download-failed')
              }
              return callback()
            }
          ) // try and continue compiling even if http resource can not be downloaded at this time
        } else {
          fs.writeFile(path, resource.content, callback)
        }
      })
    })
  },

  checkPath(basePath, resourcePath, callback) {
    const path = Path.normalize(Path.join(basePath, resourcePath))
    if (path.slice(0, basePath.length + 1) !== basePath + '/') {
      return callback(new Error('resource path is outside root directory'))
    } else {
      return callback(null, path)
    }
  }
}
