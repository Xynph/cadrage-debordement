extends RefCounted
## Bloc « Banc » de la Composition (maquette 10-composition-1) : les huit remplaçants (n°, joueur, postes couverts,
## marque « 1re ligne », condition), triables par en-tête, puis les doublures de métier présentes sur la feuille pour
## chaque poste (joueurs dont c'est le poste principal ou secondaire, données projetées par le moteur).
## Exemple : `Banc.build(app, page, Rect2(1062, 200, 600, 696), choisir, clavier, avis, bleus, premiere_ligne)`.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const TableOrder = preload("res://ui/player_table_order.gd")
const PersonName = preload("res://ui/person_name.gd")
const LIGNE := 33.0
## Colonnes (x dans le bloc) : n°, joueur, couvre, marque 1re ligne, condition (barre puis valeur alignée à droite).
const X_NUMERO := 22.0
const X_JOUEUR := 76.0
const X_COUVRE := 300.0
const X_MARQUE := 404.0
const X_CONDITION := 484.0

static func build(app: Control, page: Control, zone: Rect2, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, premiere: Dictionary) -> Panel:
	var bloc := D.rect(page, zone, Charte.PANNEAU, 0)
	bloc.name = "TacticsBench"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var remplis := 0
	for slot in range(15, 23):
		if not Selection.occupant(app.model, slot).is_empty(): remplis += 1
	Kit.titre(bloc, 22, 34, "Banc %d/8" % remplis, 24, 300)
	Kit.etiquette(bloc, zone.size.x - 22, 32, "1re ligne %d/%d" % [mini(int(premiere.formes), int(premiere.cible)), int(premiere.cible)], 300, true)
	D.line(bloc, Vector2(22, 46), Vector2(zone.size.x - 22, 46), Charte.FILET)
	var lecture: Dictionary = app.management_ui.get("bench_reading", {"key":"slot", "descending":false})
	app.management_ui.bench_reading = lecture
	for colonne: Array in [["N°", X_NUMERO, 50, "slot"], ["Joueur", X_JOUEUR, 210, "name"], ["Couvre", X_COUVRE, 100, "pos"], ["Cond.", X_CONDITION, 94, "condition"]]:
		var cle: String = colonne[3]
		var titre: String = str(colonne[0]).to_upper() + ((" ▼" if lecture.descending else " ▲") if lecture.key == cle else "")
		var tri := Kit.lien(bloc, Rect2(float(colonne[1]) - 4, 50, float(colonne[2]), 32), titre, func():
			lecture.descending = not lecture.descending if lecture.key == cle else false
			lecture.key = cle
			app._render()
			var cible: Control = app.root_content.find_child("BenchSort_" + cle, true, false)
			if cible != null: FocusLater.grab(cible), "BenchSort_" + cle, 16)
		tri.add_theme_font_override("font", C.DISPLAY)
		tri.add_theme_color_override("font_color", Charte.IVOIRE if lecture.key == cle else Charte.IVOIRE_2)
		tri.tooltip_text = "Trier par " + str(colonne[0]).to_lower()
	D.line(bloc, Vector2(22, 84), Vector2(zone.size.x - 22, 84), Charte.FILET)
	var entrees: Array = []
	for slot in range(15, 23):
		var person := Selection.occupant(app.model, slot)
		entrees.append({"id":str(person.get("id", "vacant")) + "/" + str(slot), "slot":slot, "person":person})
	entrees = TableOrder.ordered(entrees, lecture.key, lecture.descending, func(entree: Dictionary, cle: String):
		if cle == "slot": return entree.slot
		if cle == "pos": return Selection.positions(entree.person) if not entree.person.is_empty() else null
		return entree.person.get(cle))
	var lignes := Control.new()
	lignes.name = "BenchPlayerRows"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(lignes)
	D.place(lignes, Rect2(0, 86, zone.size.x, LIGNE * 8))
	var pris: Dictionary = Selection.state(app).get("pris", {}) if Selection.state(app).get("pris") is Dictionary else {}
	for i in entrees.size():
		_ligne(app, lignes, i, entrees[i].slot, entrees[i].person, zone.size.x, choisir, clavier, avis, bleus, pris)
	var y := 86.0 + LIGNE * 8 + 30
	Kit.texte(bloc, 22, y, "Les n° 16 à 18 sont généralement la première ligne ;", Charte.IVOIRE_2, zone.size.x - 44, 16).name = "BenchFrontRowNote"
	Kit.texte(bloc, 22, y + 22, "la règle compte les formés sur la feuille." if C.dense() else "la règle compte les premières lignes formées sur toute la feuille.", Charte.IVOIRE_2, zone.size.x - 44, 16)
	_doublures(app, bloc, y + 68, zone.size.x, choisir)
	return bloc

static func _ligne(app: Control, parent: Control, rang: int, slot: int, person: Dictionary, largeur: float, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, pris: Dictionary) -> void:
	var id := str(person.get("id", ""))
	var choisi: bool = app.selected_slot == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "LineupSlot%02d" % (slot + 1)
	Kit.styler_ligne(bouton, Charte.PANNEAU_2 if rang % 2 == 1 else Charte.PANNEAU, choisi)
	parent.add_child(bouton)
	D.place(bouton, Rect2(14, rang * LIGNE, largeur - 28, LIGNE))
	Selection.wire(bouton, app, id, slot, slot, str(person.get("name", "Poste vacant")))
	if choisi: Kit.marqueur(bouton, Rect2(2, 5, 4, LIGNE - 10))
	Kit.ovale(bouton, Rect2(X_NUMERO - 10, 4, 40, 25), str(slot + 1), app.accent)
	var accessible := "Remplaçant n° %d · " % (slot + 1)
	if person.is_empty():
		Kit.texte(bouton, X_JOUEUR - 14, 23, "Place vide", Charte.IVOIRE_2, 200)
		accessible += "place vide"
	else:
		var court := Kit.casse(str(person.get("name", "")), true)
		Kit.nom(app, bouton, Rect2(X_JOUEUR - 14, 3, 200, 27), court, id, "BenchName%02d" % (slot + 1))
		Kit.texte(bouton, X_COUVRE - 14, 23, Selection.positions(person), Charte.IVOIRE_2, 100, 16)
		if Selection.premiere_ligne_formee(app.model, person):
			var marque := D.rect(bouton, Rect2(X_MARQUE - 14, 7, 70, 20), Charte.PANNEAU_3, 0)
			marque.name = "BenchFrontRow%02d" % (slot + 1)
			D.text(marque, 35, 15, "1re" if C.dense() else "1re ligne", 16, Charte.IVOIRE, 600, 66, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.condition(bouton, X_CONDITION - 14, 23, person.get("condition"), 34)
		accessible += "%s · couvre %s" % [str(person.get("name", "")), Selection.positions(person)]
	if avis.has(slot):
		Kit.puce(bouton, Rect2(X_MARQUE + 56 - 14, 6, 18, 20), "!", Charte.IVOIRE_2, Charte.NUIT, "TacticsStaffAdviceMark%02d" % (slot + 1))
		accessible += " · " + str(avis[slot])
	if bleus.has(slot): Kit.puce(bouton, Rect2(X_MARQUE - 44, 6, 28, 20), "33", Charte.D, Charte.NUIT, "TacticsBleusMark%02d" % (slot + 1))
	if not pris.is_empty() and str(pris.get("player_id", "")) != id and Selection.can_drop(app, Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))), slot):
		D.rect(bouton, Rect2(0, LIGNE - 3, largeur - 28, 3), Charte.IVOIRE_2, 0).name = "TacticsCible%02d" % (slot + 1)
	bouton.accessibility_name = accessible
	bouton.pressed.connect(func(): choisir.call(slot))
	bouton.gui_input.connect(func(event: InputEvent): clavier.call(event, slot, bouton))

## Doublures de métier : pour chaque poste, combien de joueurs de la feuille l'ont pour poste principal ou secondaire.
## Une case cliquable sélectionne le poste (ses candidats s'affichent dessous).
static func _doublures(app: Control, bloc: Control, y: float, largeur: float, choisir: Callable) -> void:
	Kit.titre(bloc, 22, y, "Doublures sur la feuille", 22, 360)
	Kit.etiquette(bloc, largeur - 22, y - 2, "n° du poste · joueurs du métier", 300, true)
	D.line(bloc, Vector2(22, y + 12), Vector2(largeur - 22, y + 12), Charte.FILET)
	var comptes := {}
	for poste in range(1, 16): comptes[poste] = 0
	for slot in 23:
		var person := Selection.occupant(app.model, slot)
		if person.is_empty(): continue
		for poste in _postes(person):
			if comptes.has(poste): comptes[poste] += 1
	var case_l := (largeur - 44 - 7 * 6) / 8.0
	var seuls: Array[int] = []
	for poste in range(1, 16):
		var rang := poste - 1
		var zone := Rect2(22 + (rang % 8) * (case_l + 6), y + 24 + int(rang / 8) * 62, case_l, 56)
		var compte: int = comptes[poste]
		var case_ := Button.new()
		case_.name = "TacticsDepth%02d" % poste
		Kit.styler_ligne(case_, Charte.PANNEAU_2, app.selected_slot == poste - 1)
		bloc.add_child(case_)
		D.place(case_, zone)
		D.text(case_, case_l / 2.0, 25, str(poste), 21, Charte.IVOIRE, 700, case_l - 4, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_GRAS)
		D.text(case_, case_l / 2.0, 47, "×%d" % compte, 16, Charte.IVOIRE_2 if compte > 1 else Charte.D, 600, case_l - 4, HORIZONTAL_ALIGNMENT_CENTER, true)
		case_.accessibility_name = "Poste n° %d · %d joueur%s du métier sur la feuille" % [poste, compte, "s" if compte > 1 else ""]
		case_.tooltip_text = case_.accessibility_name
		case_.pressed.connect(func(): choisir.call(poste - 1))
		if compte <= 1: seuls.append(poste)
	var bas := y + 24 + 2 * 62 + 22
	if seuls.is_empty():
		Kit.texte(bloc, 22, bas, "Chaque poste a au moins une doublure de métier sur la feuille.", Charte.IVOIRE_2, largeur - 44, 16).name = "TacticsDepthSummary"
		return
	var debut := "Sans doublure de métier : "
	Kit.texte(bloc, 22, bas, debut, Charte.IVOIRE_2, Kit.largeur(debut, 16) + 4, 16).name = "TacticsDepthSummary"
	var x := 22.0 + Kit.largeur(debut, 16)
	for poste: int in seuls:
		var lien := Kit.lien(bloc, Rect2(x - 2, bas - 22, 0, 30), "n° %d" % poste, func(): choisir.call(poste - 1), "TacticsDepthAlone%02d" % poste, 16)
		x += lien.size.x / C.density + 2
static func _postes(person: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var principal: Variant = person.get("primaryPosition")
	if principal is int or principal is float: result.append(int(principal))
	for autre: Variant in person.get("secondaryPositions", []):
		if (autre is int or autre is float) and int(autre) not in result: result.append(int(autre))
	return result
