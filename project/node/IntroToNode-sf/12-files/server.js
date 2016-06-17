var fs = require("fs");
var express = require("express");
var config = JSON.parse(fs.readFileSync("config.json"));
var host = config.host;
var port = config.port;

var app = express.createServer();
app.get("/", function(request, response){
	var content = fs.readFileSync("template.html");
	
	getTweets(function(tweets){
		var ul = '';
		tweets.forEach(function(tweet) {
			ul += "<li><strong>" + tweet.user.screen_name + ": </strong>" + tweet.text + "</li>";
		});
		content = content.toString("utf8").replace("{{INITIAL_TWEETS}}", ul);
		response.setHeader("Content-Type", "text/html");
		response.send(content);
	});
});
app.listen(port, host);
var io = require('socket.io').listen(app);

var mongo = require("mongodb");
var host = "127.0.0.1";
var port = mongo.Connection.DEFAULT_PORT;
var db = new mongo.Db("nodejs-introduction", new mongo.Server(host, port, {}));
var tweetCollection;
db.open(function(error){
	console.log("We are connected! " + host + ":" + port);
	
	db.collection("tweet", function(error, collection){
		tweetCollection = collection;
	});

});

function getTweets(callback) {
	tweetCollection.find({}, {"limit":10, "sort": {"_id": -1}}, function(error, cursor) {
		cursor.toArray(function(error, tweets) {
			callback(tweets);
		});
	});
}


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
		tweetCollection.insert(tweet, function(error) {
			if (error) {
				console.log("Error: ", error.message);
			} else {
				console.log("Inserted into database");
			}
		});
	});
	response.on("end", function(){
		console.log("Disconnected");
	});
});
request.end();

