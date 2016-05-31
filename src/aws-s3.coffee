# Description:
#   Manage S3 with Hubot.
#
# Dependencies:
#   "moment": "^2.13.0"
#   "aws-sdk": "^2.3.16"
#   "easy-table": "^1.0.0"
#
# Configuration:
#   None
#
# Commands:
#   hubot s3 help - commands to manage s3
#
# Author:
#   gsfjohnson

Table = require 'easy-table'
moment = require 'moment'
aws = require 'aws-sdk'

aws.config.accessKeyId = process.env.HUBOT_AWS_S3_ACCESS
aws.config.secretAccessKey = process.env.HUBOT_AWS_S3_SECRET
aws.config.region = process.env.HUBOT_AWS_S3_REGION
aws.config.logger = process.stdout

modname = authrole = "s3"

maxkeys = 15

s3 = new aws.S3({apiVersion: '2006-03-01'})

previousDir = currentDir = "/"

isAuthorized = (robot, msg) ->
  if robot.auth.isAdmin(msg.envelope.user) or robot.auth.hasRole(msg.envelope.user,authrole)
    return true
  msg.send {room: msg.message.user.name}, "Not authorized.  Missing `#{authrole}` role."
  return false

listBuckets = (msg) ->
  s3.listBuckets (err, res) ->
    return msg.send "Error: #{err}" if err

    t = new Table
    for bucket in res.Buckets
      t.cell('bucket', bucket.Name )
      t.cell('time', moment(bucket.CreationDate).format('YYYY-MM-DD HH:mm:ssZ') )
      t.newRow()

    msg.send {room: msg.message?.user?.name}, "```\n#{t.toString()}\n```"

listObjects = (msg,loObj) ->
  unless loObj? and loObj['MaxKeys'] > 4 and loObj['MaxKeys'] < maxkeys
    loObj['MaxKeys'] = maxkeys

  s3.listObjects loObj, (err, res) ->
    return msg.send "Error: #{err}" if err

    t = new Table
    for p in res.CommonPrefixes
      path = p.Prefix.split "/"
      path.pop()
      fn = path.pop()

      t.cell('Name', fn )
      t.cell('Type', 'dir' )
      t.newRow()

    for content in res.Contents
      path = content.Key.split "/"
      if path[path.length-1].length == 0
        path.pop()
      fn = path.pop()

      t.cell('Name', fn )
      t.cell('Size', content.Size )
      t.cell('Type', 'file' )
      t.cell('Storage', content.StorageClass)
      t.cell('LastModified', moment(content.LastModified).format('YYYY-MM-DD HH:mm:ssZ'))
      t.newRow()

    out = t.toString()
    msg.send {room: msg.message?.user?.name}, "```\n#{out}\n```"


module.exports = (robot) ->

  robot.respond /s3 help$/, (msg) ->
    cmds = []
    arr = [
      "#{modname} ls - list directory"
      "#{modname} pwd - show current directory"
      "#{modname} cd <path> - change directory"
    ]

    for str in arr
      cmd = str.split " - "
      cmds.push "`#{cmd[0]}` - #{cmd[1]}"

    if msg.message?.user?.name?
      msg.send {room: msg.message?.user?.name}, cmds.join "\n"
    else
      msg.reply cmds.join "\n"

  robot.respond /s3 ls$/i, (msg) ->
    return unless isAuthorized robot, msg

    if currentDir == '/'
      return listBuckets msg

    dirStack = currentDir.split "/"
    dirStack.shift()
    bucket = dirStack.shift()
    prefix = dirStack.join "/"

    return listObjects msg, { Bucket: bucket, Prefix: prefix, Delimiter: '/' }

  robot.respond /s3 pwd$/i, (msg) ->
    return unless isAuthorized robot, msg
    return msg.send "```\n#{currentDir}\n```"

  robot.respond /s3 cd (.+)$/i, (msg) ->
    return unless isAuthorized robot, msg
    newDir = msg.match[1]
    if newDir == '-'
      newDir = previousDir
      previousDir = currentDir
      currentDir = newDir
    else if newDir == '/'
      previousDir = currentDir
      currentDir = newDir
    else if newDir == '..'
      unless currentDir == '/'
        previousDir = currentDir
        path = currentDir.split "/"
        val = path.pop()
        unless val.length > 0
          path.pop()
          path.push ""
        currentDir = path.join('/')
    else if newDir.match /^[^\/]+$/
      previousDir = currentDir
      path = currentDir.split "/"
      if path[path.length-1].length == 0
        path[path.length-1] = newDir
        path.push ""
      else
        path.push newDir
      currentDir = path.join('/')
    else
      previousDir = currentDir
      currentDir = newDir

    return msg.send "```\n#{currentDir}\n```"
