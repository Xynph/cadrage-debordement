extends SceneTree
const PersonName = preload("res://ui/person_name.gd")
var failures: Array[String] = []

func check(full_name: String, surname: String, short: String) -> void:
	var a: String = PersonName.surname(full_name)
	var b: String = PersonName.initial_and_surname(full_name)
	if a != surname or b != short:
		failures.append("%s -> « %s » / « %s »" % [full_name, a, b])

func _initialize() -> void:
	# Noms de la table de base : patronymes composés, à particule, à apostrophe ; prénoms composés ; noms japonais, polynésiens, géorgiens.
	check("Julien LE GAC", "LE GAC", "J. LE GAC")
	check("Rik VAN DIJK", "VAN DIJK", "R. VAN DIJK")
	check("Dewald DU TOIT", "DU TOIT", "D. DU TOIT")
	check("Xavier DOS SANTOS", "DOS SANTOS", "X. DOS SANTOS")
	check("Padraig O'BRIEN", "O'BRIEN", "P. O'BRIEN")
	check("Pierre-Alexandre LE BORGNE", "LE BORGNE", "P. LE BORGNE")
	check("Jean-Baptiste SOLER", "SOLER", "J. SOLER")
	check("Kenta HASHIMOTO", "HASHIMOTO", "K. HASHIMOTO")
	check("Sione KAUFUSI", "KAUFUSI", "S. KAUFUSI")
	check("Demetre DATUNASHVILI", "DATUNASHVILI", "D. DATUNASHVILI")
	check("Émile ÉCHARD", "ÉCHARD", "É. ÉCHARD")
	# Noms d'un pack ou du staff, sans capitales : tout ce qui suit le premier mot.
	check("Joueur Test 1", "Test 1", "J. Test 1")
	check("Paul de La Vigne", "de La Vigne", "P. de La Vigne")
	check("Mohamed Amine GARREAU", "GARREAU", "M. GARREAU")
	check("JEAN GARREAU", "GARREAU", "J. GARREAU")
	check("Seul", "Seul", "Seul")
	for failure in failures:
		printerr("FAIL: ", failure)
	print("Noms affichés : 16 cas, %d échec(s)" % failures.size())
	quit(1 if not failures.is_empty() else 0)
