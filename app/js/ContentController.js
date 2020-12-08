const Path = require('path')
const send = require('send')
const Settings = require('settings-sharelatex')
const OutputCacheManager = require('./OutputCacheManager')

function getPdfRange(req, res, next) {
  const { project_id: projectId, user_id: userId, hash } = req.params
  const compileDir = Path.join(
    Settings.path.compilesDir,
    `${projectId}-${userId}`
  )
  const cacheRoot = Path.join(compileDir, OutputCacheManager.CONTENT_SUBDIR)
  OutputCacheManager.ensureContentDir(cacheRoot, (err, contentDir) => {
    if (err) {
      return next(err)
    }
    const path = Path.join(contentDir, hash)
    console.log({ path })
    send(req, path).pipe(res)
  })
}

module.exports = { getPdfRange }
