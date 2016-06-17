var mongo = require("mongodb");
var host = "127.0.0.1";
var port = mongo.Connection.DEFAULT_PORT;
var db = new mongo.Db("nodejs-introduction", new mongo.Server(host, port, {}));
db.open(function(error){
	console.log("We are connected! " + host + ":" + port);

	db.collection("user", function(error, collection){
		console.log("We have the collection");
		
		collection.insert({
			id: "1",
			name: "Ollie Parsley",
			twitter: "ollieparsley",
			email: "ollie@ollieparsley.com"
		}, function(){
			console.log("Successfully inserted ollieparsley");
		});

		collection.insert({
			id: "2",
			name: "Joe Blogs",
			twitter: "joeblogs",
			email: "joeblogs@ollieparsley.com"
		}, function() {
			console.log("Successfully inserted joeblogs");
		});
	});

});
