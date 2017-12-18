

serverVideo = (root, option) ->
  opts = option || {}

  fallthrough = opts.fallthrough isnt false
  redirect = opts.redirect isnt false
  setHeaders = opts.setHeaders
  parseUrl = require('parseurl')

  unless root
    throw new TypeError('root path required')
  
  (req, res, next) ->
    console.log parseUrl.original(req)
    next()

module.exports = serverVideo