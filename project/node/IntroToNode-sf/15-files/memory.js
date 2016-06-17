//A random object
var object = {
	foo: "bar",
	joe: "blogs",
	ollie: {
		twitter: "@ollieparsley",
		url: "http://ollieparsley.com"
	}
};

//Remove ollie
object.ollie = null;
delete object.ollie;


