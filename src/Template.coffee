#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode