var https = require("https");
var options = {
	host: 'stream.twitter.com',
	path: '/1/statuses/filter.json?track=bieber',
	method: 'GET',
	headers: {
		"Authorization": "Basic " + new Buffer("IntroToNode:introduction").toString("base64") 
	}
};

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
var request = https.request(options, function(response){
	var body = '';
	response.on("data", function(chunk) {
		var tweet = JSON.parse(chunk);
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
