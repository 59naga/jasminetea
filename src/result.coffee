# Dependencies
fs= require 'fs'
path= require 'path'

# Private
process.on 'uncaughtException',(error)->
  console.error error?.stack or error?.message

  code= module.exports.code?(1)
  code?= 1
  process.exit code

# Public
class Result
  constructor: (@logPath)->
    @logPath?= path.resolve __dirname,'..','jasminetea.json'

  get: ->
    try
      log= JSON.parse fs.readFileSync @logPath
    log?= {}

  # Get the exitCode if --cover. via @logPath
  set: (exitCode)->
    log= @get()
    log[process.env.JASMINETEA]?= 0
    log[process.env.JASMINETEA]= 1 if exitCode isnt 0
    logData= JSON.stringify log

    fs.writeFileSync @logPath,logData

    log[process.env.JASMINETEA]

  clear: ->
    fs.writeFileSync @logPath,'{}'

  latest: ->
    latest= null
    latest= exitCode for time,exitCode of @get()
    latest

module.exports= new Result
module.exports.Result= Result