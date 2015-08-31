# Base class
class Base
  constructor : (@class_name) ->

  #  these can be amended to make use of the UI
  # for more immediate feedback
  error : (msg) =>
    console.log "error [#{@class_name}]: #{msg}"
  warn : (msg) =>
    console.log "warning [#{@class_name}]: #{msg}"
  trace : (msg) =>
    console.log "trace [#{@class_name}]: #{msg}"

#exports.Base=Base  # for node