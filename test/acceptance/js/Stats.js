const request = require('request')
const Settings = require('settings-sharelatex')
after(function (done) {
  request(
    {
      url: `${Settings.apis.clsi.url}/metrics`
    },
    (err, response, body) => {
      if (err) return done(err)
      console.error('-- metrics --')
      console.error(body)
      console.error('-- metrics --')
      done()
    }
  )
})
