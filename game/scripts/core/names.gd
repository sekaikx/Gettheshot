class_name Names
extends RefCounted
## Name tables for people, families and shops. Everything takes an RNG so the host and every
## client generate the same names from the same seed.

const ITALIAN_FIRST := ["Sal", "Frankie", "Tommy", "Vito", "Carmine", "Nicky", "Paulie", "Joey",
	"Vinnie", "Lou", "Aldo", "Benny", "Carlo", "Dom", "Enzo", "Gino", "Johnny", "Mario", "Rocco",
	"Sonny", "Tony", "Angelo", "Mikey", "Ralphie", "Sammy"]
const ITALIAN_LAST := ["Esposito", "Bruno", "Greco", "Neri", "Castagna", "Russo", "Moretti",
	"Ferrante", "Lombardi", "Marino", "Rizzo", "Costa", "Gallo", "Conti", "Romano", "Caruso",
	"DeLuca", "Mancini", "Vitale", "Barone", "Santoro", "Serra", "Messina", "Palumbo"]
const IRISH_FIRST := ["Owen", "Liam", "Declan", "Seamus", "Patrick", "Mickey", "Danny", "Frank",
	"Jimmy", "Kevin", "Brendan", "Conor", "Eddie", "Tom"]
const IRISH_LAST := ["O'Hara", "Doyle", "Kearney", "Flanagan", "Murphy", "Callahan", "Byrne",
	"Quinn", "Madden", "Rourke", "Walsh", "Keane", "Duffy", "Brennan"]
const JEWISH_FIRST := ["Meyer", "Abe", "Sol", "Moe", "Izzy", "Benny", "Harry", "Lou", "Sam",
	"Morris", "Jake", "Nat", "Irving", "Max"]
const JEWISH_LAST := ["Weinberg", "Rosen", "Kaplan", "Siegel", "Adler", "Goldstein", "Levine",
	"Shapiro", "Feld", "Brody", "Katz", "Horowitz", "Stein", "Lansky"]
const WOMEN_FIRST := ["Rosa", "Maria", "Anna", "Lucia", "Nora", "Bridget", "Ruth", "Sadie",
	"Esther", "Carmela", "Mae", "Ida", "Grace", "Helen"]
const NICKNAMES := ["Two Times", "The Ear", "Sticks", "Big", "Little", "The Horse", "Books",
	"Cheeks", "The Nose", "Fingers", "Sunshine", "Knuckles", "The Priest", "Blue Eyes"]

const FAMILY_NAMES := ["Vitale", "Russo", "O'Hara", "Moretti", "Kaplan", "Lombardi", "Doyle",
	"Castellano"]
const FAMILY_COLORS := ["#c42828", "#3c6ec8", "#3ca05a", "#d4a532", "#9a4fc4", "#d46a28",
	"#2aa6a6", "#c8c8c8"]

const SHOP_WORDS := {
	"bakery": ["Bakery", "Bread & Pastry", "Pasticceria"],
	"butcher": ["Meats", "Butcher", "Prime Cuts"],
	"grocer": ["Grocery", "Provisions", "Market"],
	"tailor": ["Tailoring", "Clothiers", "Fine Suits"],
	"barber": ["Barber Shop", "Shaves & Cuts"],
	"cobbler": ["Shoe Repair", "Bootmaker"],
	"pawnshop": ["Pawn & Loan", "Pawnbrokers"],
	"laundry": ["Laundry", "Steam Laundry", "Wash House"],
	"restaurant": ["Restaurant", "Trattoria", "Chop House", "Clam House"],
	"cafe": ["Coffee House", "Caffè", "Luncheonette"],
	"candy": ["Candy Store", "Sweets & Soda"],
	"hardware": ["Hardware", "Tools & Paint"],
	"drugstore": ["Drug Store", "Pharmacy"],
	"cigar": ["Cigar Store", "Tobacconist"],
	"fish": ["Fish Market", "Oysters & Fish"],
	"garage": ["Garage", "Motor Repair"],
	"warehouse": ["Warehouse", "Storage Co."],
	"poolhall": ["Billiards", "Pool Room"],
	"club": ["Social Club", "Athletic Club"],
}


static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func person(rng: RandomNumberGenerator, ethnicity: String = "") -> String:
	var e := ethnicity
	if e == "":
		e = pick(rng, ["it", "it", "ir", "je"])
	match e:
		"ir": return "%s %s" % [pick(rng, IRISH_FIRST), pick(rng, IRISH_LAST)]
		"je": return "%s %s" % [pick(rng, JEWISH_FIRST), pick(rng, JEWISH_LAST)]
		"w": return "%s %s" % [pick(rng, WOMEN_FIRST), pick(rng, ITALIAN_LAST + IRISH_LAST + JEWISH_LAST)]
	return "%s %s" % [pick(rng, ITALIAN_FIRST), pick(rng, ITALIAN_LAST)]


static func hood(rng: RandomNumberGenerator, ethnicity: String = "it") -> String:
	var n := person(rng, ethnicity)
	if rng.randf() < 0.45:
		var parts := n.split(" ")
		return "%s \"%s\" %s" % [parts[0], pick(rng, NICKNAMES), parts[1]]
	return n


static func shop(rng: RandomNumberGenerator, kind: String, owner: String) -> String:
	var last := owner.split(" ")[-1]
	var word: String = pick(rng, SHOP_WORDS.get(kind, ["Shop"]))
	if rng.randf() < 0.7:
		return "%s's %s" % [last, word]
	return "%s %s" % [pick(rng, ["Mulberry", "Elm St.", "Bowery", "Grand", "Canal", "Hester",
		"Orchard", "Delancey", "Mott", "Houston", "Ninth Ave.", "West St."]), word]
