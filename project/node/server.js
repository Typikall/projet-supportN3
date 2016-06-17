var http = require('http');
//var fs = require(fs);
var port = 8888
var server = http.createServer(function (request, response) {
  response.writeHead(200, {'Content-Type': 'text/plain'});
  response.end("hello world");
})
server.listen(port);
console.log('Server running at http://127.0.0.1:' + port);

