var keyword = process.argv[2];
var username = process.argv[3];
var password = process.argv[4];

var tweetCount = 0;
setInterval(function(){
	process.send(tweetCount + " tweets");
}, 2000);

var https = require("https");
var options = {
	host: 'stream.twitter.com',
	path: '/1/statuses/filter.json?track=' + keyword,
	method: 'GET',
	headers: {
		"Authorization": "Basic " + new Buffer(username + ":" + password).toString("base64") 
	}
};

var mongo = require("mongodb");
var host = "127.0.0.1";
var port = mongo.Connection.DEFAULT_PORT;
var db = new mongo.Db("nodejs-introduction", new mongo.Server(host, port, {}));
var tweetCollection;
db.open(function(error){
	db.collection("tweet", function(error, collection){
		tweetCollection = collection;
	});

});
var request = https.request(options, function(response){
	var body = '';
	response.on("data", function(chunk) {
		var tweet = JSON.parse(chunk);
		tweet.keyword = keyword;
		tweetCount++;
		tweetCollection.insert(tweet, function(error) {
			if (error) {
				console.log("Error: ", error.message);
			}
		});
	});
	response.on("end", function(){
		console.log("Disconnected");
	});
});
request.end();
