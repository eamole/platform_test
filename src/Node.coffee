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
