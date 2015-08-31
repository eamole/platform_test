#fs = require "fs"
#util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



#module.exports.Node = Node
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

#exports.Base=Base  # for node#{Base} = require "./Base.js"
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for nodefs = require "fs"
util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for nodefs = require "fs"
util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for nodefs = require "fs"
util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for nodefs = require "fs"
util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



module.exports.Node = Node
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


#exports.Poller=Poller  # for node#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for nodefs = require "fs"
util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for node#fs = require "fs"
#util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



#module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{Template} = require "./Template.js"
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

#exports.View=View#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for node#fs = require "fs"
#util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



#module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher# Base class
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

#exports.Base=Base  # for node#fs = require "fs"
#util = require "util"

###
	bollix
	fstat causes a break : it returns the stats for the object - but we do not know in advance if the object is a file or folder!!
	need to create a generic node and cast it - by changing the prototype!!
###
class Node

# could use path to find parent
  constructor : (@parent , @path) ->
    console.log "parent : #{@parent} path : #{@path}"

    # cannot set on the class
    @lupdate = 0		# time of last update
    @type = "unkown"
    @nodes = {}

    fs.stat @path , @onInitialGetStats

# check existing nodes
  check : =>
    fs.stat @path , @onUpdateGetStats
    for node,path in @nodes
      node.check()

  remove : (key , node) =>
    delete @nodes[key]

# I need an initial getStats to create the object
  onInitialGetStats : (err , stats) =>
    console.log "Stats"
    console.log stats

    if ! err
      @lupdate = stats.ctime.getTime()	// could use mtime
      if stats.isFile()
        @type="file"
      else if stats.isDirectory()
        @type="folder"
        fs.readdir @path , @onInitialGetDir
      else
# should probably remove the node
        @signal "ignore unwatched type #{@path}"
        @parent.remove @path,@

      @signal "add" , @lupdate

  onUpdateGetStats : (err , stats) =>
    if ! err
      time = stats.ctime.getTime()	# could use mtime

      if stats.isFile()
        if @lupdate is 0
          @signal "add" , time
        else if time > @lupdate
          @signal "update" , time
        @lupdate = time
      else if stats.isDirectory()
        @signal "add" , time

  onInitialGetDir : (err , files) =>
    if ! err
      for file in files
        @nodes[file] = new Node @ , file

  onUpdateGetDir : (err , files) =>
# check if all the files in files exist
    for file in files
      if @nodes[file]
        @nodes[file].check()
      else
        @nodes[file] = new Node @ , file

    # now look for deleted nodes
    for node,key in @nodes
      if not key in files
        delete @nodes[key]
        node.signal "deleted"

  signal : (evt , time) =>
    @parent?.signal @ , evt , time?
    console.log @path + "event #{evt} time #{time?} path #{@path}"



#module.exports.Node = Node
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


#exports.Poller=Poller  # for node{Watcher} = require("./watcher.js")

console.log "Watcher : " +  Watcher
console.log Watcher

#console.log typeof Watcher

watcher = new Watcher( {
  ignores : [
    ".git"
    "node_modules"
  ]
  folders : [
    "."
  ]
})#{View} = require "./View.js"
console.log "are we starting?"
View.show "TestView"#{Base} = require "./Base.js"

class Template extends Base
  constructor : (name) ->
    super "Template " + name

  render : (data) =>
    for prop,val of data
      @prop=val
    """

    """


#exports.Template=Template  # for mode#{View}=require "./View.js"

class TestView extends View
  constructor : ->
    super "TestView"  # not too sure what good this does

  init : (data) =>
    super data

  render : (data) =>
    super data
    """

      Hello World from #{@name}

    """

# hugely important - when loading these view - I can refer to them as new View without knowing their actual name
#exports.View=TestView  # only for node#{Template} = require "./Template.js"
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
{Node} = require "./node.js"

class Watcher
	constructor : (args) ->
		# cannot set on the class
		@ignores = []
		@nodes = {}

		@ignores = args.ignores?

		for folder in args.folders
			@nodes[folder] = new Node @ , folder if not @ignore folder


	# will expand to handle wildcards and regex		
	ignore : (folder) =>
		folder in @ignores

module.exports.Watcher = Watcher