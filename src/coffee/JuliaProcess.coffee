Bacon = require 'baconjs'
_ = require 'lodash'

{spawn} = require 'child_process'
{EventEmitter} = require 'events'
path = require 'path'

getArgs = ()-> arguments

# Separator for different chunks of code.
# Unicode \\u0017 &#x2417; "End of Transmission Block"
#
# TODO: switch back to ETB; only using newline for testing
BLOCK_SEPARATOR = "\n"#String.fromCharCode(17)

module.exports =
# # JuliaProcess
# Best of both worlds: Bacon.js and EventEmitter.
# Use whatever you're most comfortable with.
class JuliaProcess extends Bacon.Bus
  constructor: (opt) ->
    super()
    startImmediately = opt?.startImmediately ? yes
    @juliaPath = opt?.juliaPath ? '/usr/bin/julia'
    @emitter = new EventEmitter()
    _.keys(EventEmitter::).forEach (method) =>
      @[method] = @emitter[method].bind @emitter
    ['ready','killed'].forEach (method) =>
      @[method] = Bacon.fromEventTarget @emitter, method
        .map => @
    if startImmediately
      process.nextTick => @createProcess()
  createProcess: ->
    @process = spawn @juliaPath, [
      '--no-startup'
      path.resolve __dirname, '../julia/JavaScriptBridge.jl'
    ],
      cwd: process.cwd()

    @_detach = @plug (
      Bacon.fromEventTarget @process.stdout, 'data'
        .map (chunk) -> chunk.toString()
        .filter (x) -> x?
        .scan {code:[],wip:''}, (last, chunk) ->
          newCode = last.wip + chunk
          if newCode.indexOf(BLOCK_SEPARATOR) is -1
            return {
              code: []
              wip: newCode
            }
          split = newCode.split BLOCK_SEPARATOR
          {
            code: _.first split, split.length - 1
            wip: _.last split
          }
        .log 'scanned'
        .flatMap (codes) -> Bacon.fromArray codes.code
        .map (json) ->
          try
            JSON.parse(json)
          catch err
            Bacon.error json
    )
    @emitter.emit('ready')
  kill: (signal) ->
    if @process?
      @detachProcess()
      @process.kill signal
      delete @process
      delete @_detach
      @emit 'killed'
  start: ->
    @createProcess()
  stop: ->
    @kill()
  restart: ->
    @stop()
    @start()
  detachProcess: ->
    @_detach()
  evaluate: (code) ->
    @emit 'output', code
  send: (code) ->
    console.log "#{code}\u2417"
    @process.stdin.write(code+BLOCK_SEPARATOR)