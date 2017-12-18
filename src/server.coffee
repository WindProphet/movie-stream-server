express = require 'express'
serveIndex = require('serve-index')
serveVideo = require('./serve-video')

app = express()
app.get '/', (req,res) ->
  res.send ""

app.use('/movies',serveIndex(process.env.HOME + '/Movies',{
  icons:true
  filter: (filename, index, files, dir) ->
    !( filename.match(/\.(rmvb)|(mkv)|(txt)|(com)$/) || filename.match(/Icon/i))
}))
app.use('/movies',express.static(process.env.HOME + '/Movies'))

app.listen(3200)

module.exports = app
