child_process = require 'child_process'
path = require 'path'
readline = require 'readline'
base32Encode = require('base32-encode')
base32Decode = require('base32-decode')

ffmpegExecPath = '/usr/local/bin'

timeDuration = 3

execPath = (file) -> path.join ffmpegExecPath, file

mpegurl = (req, res) ->
  streaming = child_process.execFile execPath('ffprobe'), [
    '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1'
    req.staticPath
  ], (err, stdout, stderr) ->
    if err
      throw err
    res.type("audio/mpegurl")
    res.write """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-MEDIA-SEQUENCE:0
    #EXT-X-TARGETDURATION:#{(timeDuration * 1.5) | 0}

    """
    duration = Number stdout
    id = 0
    while duration > 0
      res.write("#EXTINF: #{if duration > timeDuration then timeDuration else duration},\n")
      res.write("video#{id}.ts\n")
      id += 1
      duration -= timeDuration
    res.write("#EXT-X-ENDLIST\n")
    res.end()

mpegurlstream = (req, res) ->
  probe = child_process.spawn execPath('ffprobe'), [
    '-v', 'error'
    '-select_streams', 'v'
    '-show_entries', 'packet=dts,flags'
    '-of', 'default=noprint_wrappers=1:nokey=1'
    req.staticPath
  ]

  write_header = () ->
    res.type("audio/mpegurl")
    res.write """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-MEDIA-SEQUENCE:0
    #EXT-X-TARGETDURATION:#{(timeDuration * 1.5) | 0}

    """
    write_header = undefined

  stdout = readline.createInterface { input: probe.stdout }
  flags = false
  dts = 0
  last = 0
  newsegment = () ->
    buf = Buffer.alloc(8)
    buf.writeUInt32LE(last, 0)
    buf.writeUInt32LE(dts,  4)
    res.write("#EXTINF: #{(dts - last) / 1000},\n")
    res.write("videox#{base32Encode(buf, 'Crockford')}.ts\n")
  stdout.on 'line', (line) ->
    write_header() if write_header
    if not flags
      dts = if line == 'N/A'
        0
      else Number(line)
    else
      if line[0] == 'K'
        # console.log "#{dts} #{line}"
        if dts - last > timeDuration * 0.9 * 1000
          newsegment()
          last = dts
    flags = !flags
  
  probe.stderr.on 'data', (data) =>
    console.error("#{data}")

  probe.on 'close', (code) =>
    # console.log("child process exited with code #{code}");
    if code == 0
      newsegment()
      res.write("#EXT-X-ENDLIST\n")
      last = dts
      res.end()
    else
      res.end(404)

transportStream = (req, res) ->
  id = req.videoStreamOption and req.videoStreamOption.dur
  if not id?
    throw "transportStream error"
  {fdts, tdts} = req.videoStreamOption.dur
  console.log fdts, tdts
  args = [
    '-loglevel', 'error'
    '-ss', fdts / 1000
    '-i', req.staticPath
    '-to', tdts / 1000
    # '-async', '1'
    '-vcodec', 'copy', '-acodec', 'copy'
    # '-vbsf', 'h264_mp4toannexb'
    # '-c', 'copy'
    '-avoid_negative_ts', 1
    # '-copyts'
    '-f', 'mpegts'
    '-'
  ]
  console.log('ffmpeg', args.join(' '))
  streaming = child_process.spawn execPath('ffmpeg'), args

  res.set('Content-Type', 'video/mp2t');

  streaming.stdout.on 'data', (data) -> 
    res.write(data)
  streaming.stderr.on 'data', (data) ->
    # console.log(data.toString('utf-8'))
  streaming.on 'close', (code) ->
    res.end()

videoStream = (req, res) ->
  # console.log Object.keys(req)
  # console.log req.method
  # console.log req.staticPath
  # console.log req.path
  # console.log req.params
  # console.log req.query
  if req.path == '/video.m3u8'
    console.log('m3u8')
    mpegurlstream(req, res)
  else if match = req.path.match(/^\/?videox(\w+)\.ts$/)
    dur = Buffer.from(base32Decode(match[1], 'Crockford'))
    [fdts, tdts] = [dur.readUInt32LE(0), dur.readUInt32LE(4)]
    console.log fdts, tdts
    req.videoStreamOption ||= {}
    req.videoStreamOption.dur = {fdts, tdts}
    transportStream(req, res)
  else
    res.send(404)

module.exports = videoStream