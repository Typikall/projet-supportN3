var github = require("./github.js");

github.getRepos("OllieParsley", function(repos) {
	console.log("Ollies repos", repos);
});
