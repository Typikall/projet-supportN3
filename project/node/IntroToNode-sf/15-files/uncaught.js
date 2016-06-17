proccess.on("uncaughtException", function(error) {
	console.log("Error: ", error.stack);
});
