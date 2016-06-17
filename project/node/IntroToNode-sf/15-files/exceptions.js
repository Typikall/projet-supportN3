//Normal event listener
var doSomething = function(){
	console.log("Something happened");
};
someObject.addListener("something", doSomething);
someObject.removeListener("something", doSomething);
someObject.removeAllListeners();
