#{Template} = require "./Template.js"
#{Poller} = require "./Poller.js"


class View extends Template
  views : {}

  @show : (name,data) =>
    # @trace "calling require" # @ here refers to a static function!!
    console.log "view name : #{name} "
    # {View} = require "./#{name}.js"
    # view = new View
    view = new window[name] # global func

    @views[name]=view
    view.init data
    html = view.render()
    $("main-container").html html

  constructor : (@name) ->

    @events = {
      click : {
      }
      change : {
      }
    }

    # these are latched elements
    # i think a poller might be useful
    # to push props to dom
    # the dom tracks change
    @domBindings = {
      props : {

      }
      els : {

      }

    }
    @propChangePollerRequired = false

    # domReady
    $ -> @onDomReady

  init : (data) =>
    # import the data
    for k,v of data
      @[k]=v


  # bind a prop to an el - timer
  pbind : (prop,id) =>
    @domBindings.props[prop] = id

  #bind an el to a prop - onChange
  ebind : (id,prop) =>
    @domBindings.els[id] = prop

# solve the $/CS problem of losing this
  # by wrapping the passed handler and passing the el and the event
  # @ will stay the original bound object
  onDomReady : =>
    self = @

    for id,prop in @domBindings.els
      el = @$ id
      @events.change[id] = ->
        self[prop]=@.val  # should possibly be a method to fire an event

    for id,prop in @domBindings.props
      el = @$ id  # simple test
      @error "invalid watched property #{prop}" if not @[prop]?
      @domBindings.vals[prop] = @[prop] if @[prop]?
      @propChangePollerRequired = true

    # establish click handlers
    for sel,handler of @events.click
      el = @$ sel
      el.click (evt) ->
        handler @,evt

    # establish change handlers
    for sel,handler of @events.change
      el = @$ sel
      el.change (evt) ->
        handler @,evt

    @poller = new Poller { cb : checkProps }

  ###
    we want some dom handling
  ###
  $ : (sel,val) =>
    els = $(sel)
    if els.length is 0 then @error "invalid selector #{sel}"
    # val only on form els
    els.val val if val? and els.val?
    els.html val if val? and els.html?
    @warn "value specified but no suitable update method #{sel} " if (
      val? and not (els.html? or els.val)
    )
    # return the els
    $(els)  #make the object a jquery object - might already be one

  # still need to handle the problems with click handlers

  render : (data) =>
    super data
    """

    """

#exports.View=View