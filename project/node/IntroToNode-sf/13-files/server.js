var fs = require("fs");
var express = require("express");
var port = process.env["app_port"];

var app = express.createServer();
app.get("/", function(request, response){
	var content = fs.readFileSync(__dirname + "/template.html");
	response.setHeader("Content-Type", "text/html");
	response.send(content);
});
app.listen(port);
var io = require('socket.io').listen(app);



var https = require("https");
var options = {
	host: 'stream.twitter.com',
	path: '/1/statuses/filter.json?track=bieber',
	method: 'GET',
	headers: {
		"Authorization": "Basic " + new Buffer("IntroToNode:introduction").toString("base64") 
	}
};
var request = https.request(options, function(response){
	var body = '';
	response.on("data", function(chunk) {
		var tweet = JSON.parse(chunk);
		io.sockets.emit("tweet", tweet);
	});
	response.on("end", function(){
		console.log("Disconnected");
	});
});
request.end();

