var http = require('http');
//var fs = require(fs);
var port = 8888
var fs = require("fs");
console.log("Starting");
var text = fs.readFile("sample.txt", function(error, data) 
/*        if(error)
	    console.log("Imposible de lire le fichier")
        else
	    console.log("Contents of file: " + data);
							});
*/
console.log("Carry on executing");
console.log(text);

//text = "Coucou"
var server = http.createServer(function (request, response) {
  response.writeHead(200, {'Content-Type': 'text/plain'});
  response.end("text");
})
server.listen(port);
console.log('Server running at http://127.0.0.1:' + port);
