fs = require "fs"
glob = require "glob"
{exec} = require "child_process"

src = "src/"
target = "dist/"
app = "app"
enc = "utf8"
concatCode = "" # needs to be global
triggers = {}   # an array of key, trigger = {count,

triggerCreate = (key , count , next ) ->
  trace "triggerCreate(key = #{key} , count = #{count})"
  triggers[key] = {count:count,next:next}

trigger = (key) ->
  trace "trigger(#{key})"
  _trigger=triggers[key]
  error "invalid trigger key #{key}" if not _trigger?
  trace "trigger count : #{_trigger.count}"
  if --_trigger.count is 0
    trace "eliminating trigger #{key}"
    delete triggers[key]
    trace "calling trigger.next()"
    _trigger.next()


trace = (msg) ->
  console.log msg

error = (err)->
  console.log "Error : #{err} " if err
  throw err if err

compileAll = ->
  trace "conpileAll()"
  exec "coffee --compile --map --output #{target} #{src}" , (err,stdout,stderr) ->
  error err
  console.log stdout + stderr

compile = (file,next) ->
  trace "compile(#{file}) -> #{target} "
  exec "coffee --compile --map --output #{target} #{file}" , (err,stdout,stderr) ->
    error err
    console.log stdout + stderr
    next() if next? and not err

concatAll = (mask , next )->
  trace "concatAll(#{mask})"
  glob mask , (err,matches) ->
    error err
    trace "%1 files found for concat",matches.length
    triggerCreate "files" , matches.length , ->
      trace "trigger fired"
      next concatCode if next? and not err  # writeFile needs to wait until all reads done

    for file in matches
      trace "adding #{file}"
      readFile file , (content) ->
        concatFile content  # no next
        trigger "files"

    #trace "needs to block here till reads done!"
    # need to signal when all this shit is finished
    # pass on the concat code - should be writeFile

concatFile = (content , next) ->
  trace "concatFile(<content>)"
  concatCode += content
  next content if next?

readFile = (file , next ) ->
  trace "readFile(#{file})"
  fs.readFile file , enc , (err,content) ->
    error err
    next content if next? and not err

writeFile = (file , content, next ) ->
  trace "writeFile(#{file},<content>)"
  fs.writeFile file, content , enc , (err) ->
    error err
    next file if next? and not err

task "build" , "build the app" , ->
  trace "task build"
  concatAll "#{src}*.coffee" , (content) ->
    file = "#{src}#{app}.coffee"
    writeFile file, content , (file) ->
      compile file

task "concat" , "concats the source files" , ->
  concatAll "#{src}*.coffee" , (content) ->
    write "#{src}#{app}.coffee" , content , (file) ->
      compile file

task "compile" , "compile the app" , ->
  compileAll()

task "say:hello","description", ->
  console.log "Ola "

