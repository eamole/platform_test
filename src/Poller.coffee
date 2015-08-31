#{Base} = require "./Base.js"
class Poller extends Base
  constructor : (cfg)->

    @maxCount=0 # infinite

    @cb = cfg.handler?
    @freq = cfg.freq?
    @maxCount = cfg.maxCount?

    @count = 0

    setTimeout @tick , @freq

  tick : =>
    @count++
    @stop "maxCount exceeded" if @count>@maxCount
    ok = @cb()
    if ok?
      setTimeout @tick, @freq
    else
      @stop "callback returned null"

  stop : (reason) =>
    @trace "finishing polling because #{reason}"


#exports.Poller=Poller  # for node