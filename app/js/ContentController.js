const Path = require('path')
const send = require('send')
const Settings = require('settings-sharelatex')
const OutputCacheManager = require('./OutputCacheManager')

const ONE_DAY_S = 24 * 60 * 60
const ONE_DAY_MS = ONE_DAY_S * 1000

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
    res.setHeader('cache-control', `public, max-age=${ONE_DAY_S}`)
    res.setHeader('expires', new Date(Date.now() + ONE_DAY_MS).toUTCString())
    send(req, path).pipe(res)
  })
}

module.exports = { getPdfRange }
