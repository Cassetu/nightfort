extends RefCounted

const SINGLE := ["Marcus", "Livia", "Titus", "Cornelia", "Gaius", "Aurelia", "Lucius", "Flavia", "Quintus", "Octavia", "Servius", "Valeria", "Decimus", "Julia", "Aulus", "Claudia", "Publius", "Sabina", "Sextus", "Portia", "Tiberius", "Lucilla", "Cassius", "Marcia"]
const FIRST := ["Marcus", "Lucius", "Gaius", "Quintus", "Titus", "Servius", "Aulus", "Decimus", "Publius", "Gnaeus", "Sextus", "Manius", "Tiberius", "Cassius", "Octavius", "Flavius"]
const FAMILY := ["Varro", "Cato", "Fabius", "Crassus", "Naso", "Severus", "Rufus", "Lepidus", "Gracchus", "Priscus", "Falco", "Brutus", "Metellus", "Nerva", "Pollio", "Scaevola"]


static func person(rng: RandomNumberGenerator) -> String:
	return FIRST[rng.randi() % FIRST.size()] + " " + FAMILY[rng.randi() % FAMILY.size()]
