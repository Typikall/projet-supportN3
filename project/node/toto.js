var person = {
	prenom : "paul",
	nom : "rakoto",
	mail : "prakot@edf.fr",
	full : function(){
	return person.prenom  + " " + person.nom
	}
}
console.log(person.full());
