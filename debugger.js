/**
 * Created by eamole on 31/08/2015.
 */

//var net = require('net');
//
//var server = net.createServer(function (socket) {
//    socket.write('Echo server\r\n');
//    socket.pipe(socket);
//});
//
//server.listen(5858, '127.0.0.1');

var http = require('http');
http.createServer(function (req, res) {
    console.log(req);
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('Hello World\n');

}).listen(5858, '127.0.0.1');
console.log('Server running at http://127.0.0.1:5858/');