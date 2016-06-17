var fs = require("fs");
console.log("Starting");
fs.readFile("sample.txt", function(error, data) {
	if(error)
		console.log("Imposible de lire le fichier")
	else
		console.log("Contents of file: " + data);
});
console.log("Carry on executing");
