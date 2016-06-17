var childProcess = require("child_process");

var children = [];

var keywords = [
	["bieber", "IntroToNode", "introduction"],
	["euro2012", "IntroToNode2", "introduction"]
];

keywords.forEach(function(keywordData){
	var child = childProcess.fork(__dirname + "/twitter.js", keywordData);
	child.on("exit", function(){
		console.log(keywordData[0] + ": died :(");
	});
	child.on("message", function(text) {
		console.log(keywordData[0] + ": " + text);
	});
	children.push(child);
});

process.on("exit", function() {
	children.forEach(function(child){
		child.kill();
	});
});

