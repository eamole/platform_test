{Watcher} = require("./watcher.js")

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
})