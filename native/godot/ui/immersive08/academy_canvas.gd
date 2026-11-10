extends Control
## Données des Espoirs, décisions disponibles et historique reçu du moteur.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const TABS = ["Effectif U21", "Effectif U18", "Progression", "Passerelles", "Encadrement"]
const PAGE_SIZE = 12
const GREEN = Color("63ef96")
const GOLD = Color("ffcf67")
const RED = Color("f69a91")
const PATHS = {"equilibre":"Équilibre", "minutes":"Temps de jeu", "progression":"Développer le potentiel", "professionnel":"Passage professionnel"}

class Trend extends Control:
	var levels: Array[float] = []
	var minimum := 0.0
	var maximum := 100.0

	func _draw() -> void:
		for i in 4:
			var y := size.y * i / 3.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(C.LINE, .66), maxf(1.0, C.density))
		draw_line(Vector2.ZERO, Vector2(0, size.y), C.LINE, maxf(1.0, C.density))
		var points := PackedVector2Array()
		for i in levels.size():
			var fraction := float(i) / (levels.size() - 1) if levels.size() > 1 else 1.0
			var x := lerpf(size.x * .06, size.x * .94, fraction)
			var y := size.y * (1.0 - inverse_lerp(minimum, maximum, levels[i]))
			points.append(Vector2(x, y))
		if points.size() > 1:
			var area := points.duplicate()
			area.append(Vector2(points[-1].x, size.y))
			area.append(Vector2(points[0].x, size.y))
			draw_colored_polygon(area, Color(GREEN, .12))
			draw_polyline(points, Color("216547"), C.px(7), true)
			draw_polyline(points, GREEN, C.px(2.5), true)
		for point in points:
			draw_circle(point, C.px(8), Color("10221a"), true, -1, true)
			draw_circle(point, C.px(5), GREEN, true, -1, true)

var app: Control
var state: Dictionary
var development: Dictionary
var pathway: Dictionary
var roster: Array
var professionals: Array
var academy_by_id: Dictionary = {}
var selected: Dictionary
var active_tab := 0
var staff: Array
var rows: Control
var dossier: Panel
var integration: Button

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.app = application
	page.name = "ImmersiveAcademy"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

func _build() -> void:
	development = app.model.get("decisions", {}).get("development", {})
	pathway = app.model.get("clubLife", {}).get("academyPathways", {})
	roster = development.get("academy", [])
	professionals = development.get("professionals", []).filter(func(p: Dictionary): return int(p.get("age", 99)) <= 23)
	for person: Dictionary in pathway.get("players", []): academy_by_id[person.id] = person
	staff = _academy_staff()
	if not app.management_ui.get("immersive_academy") is Dictionary:
		app.management_ui.immersive_academy = {}
	state = app.management_ui.immersive_academy
	var club_id: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club_id:
		state.clear()
		state.club = club_id
	active_tab = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	var default_group: String = ["u21", "u18", "academy", "academy", "academy"][active_tab]
	var group := str(state.get("group", default_group))
	var visible := _filtered(group)
	_select_visible(visible)
	_heading()
	match active_tab:
		0, 1, 2: _table(group, visible)
		3: _pathways()
		4: _staff_page()
	_dossier()
	_lower_pathways()
	_staff_card()
	_junior()

func _heading() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 279), "", "", "", "AcademyHero")
	hero.clip_contents = true
	D.photo(hero, "club-forest", Rect2(1450, 1, 796, 276))
	D.fade_photo_edges(D.photo(hero, "academy-training", Rect2(1056, 1, 780, 276)))
	D.text(hero, 29, 36, "LA RELÈVE SE CONSTRUIT", 28, GOLD, 700, 615)
	app.heading = D.text(hero, 26, 102, "Le futur porte nos couleurs.", 69, C.IVORY, 800, 1010)
	D.text(hero, 30, 140, "Académie · " + G.club_name(app.model.club) + "  ·  U18 / U21", 26, C.IVORY, 500, 1000)
	var high := roster.filter(func(p: Dictionary): return float(p.get("potential", 0)) >= 85).size()
	var pro: Array = pathway.get("players", []).filter(func(p: Dictionary): return p.get("path") == "professionnel")
	var coaches := G.n(pathway.get("coaches", "—"))
	var metrics := [
		[191, "people", G.n(roster.size()), "espoirs", GREEN],
		[234, "star", G.n(high), "potentiels estimés ≥ 85", GOLD],
		[246, "arrow", G.n(pro.size()) if pathway.get("active", false) else "—", "parcours professionnels", GREEN],
		[240, "people", coaches + " / 3" if coaches != "—" else coaches, "niveau des éducateurs", C.IVORY],
	]
	var x := 30.0
	for entry: Array in metrics:
		var width: float = entry[0]
		var card := D.panel(hero, Rect2(x, 153, width, 78))
		_icon(card, entry[1], Rect2(14, 23, 36, 36), entry[4])
		D.text(card, 66, 37, entry[2], 34, entry[4], 700, width - 73)
		D.text(card, 66, 62, entry[3], 19, C.IVORY, 500, width - 73)
		x += width + 17.0
	D.scenario_photo(hero, "chair", Rect2(2070, 9, 158, 142))
	integration = _action(hero, Rect2(1709, 160, 519, 65), "Préparer une intégration", _integration_dialog, true, "arrow", "AcademyPrepareIntegration")
	integration.add_theme_font_size_override("font_size", C.px(35))
	_update_integration()
	D.text(hero,1100,151,"Objectifs et gains réellement observés",23,C.IVORY,600,580)
	D.button(hero,Rect2(1100,170,580,55),"Suivre la progression des jeunes →",func(): preload("res://ui/youth_development_view.gd").open(app),false,"arrow",false,app.accent,"OpenYouthDevelopment")
	for i in TABS.size():
		var tab := U.tab(self, Rect2(3 + i * 282, 247, 271, 56), TABS[i], i == active_tab, func(): _open_tab(i), "AcademyImmersiveTab" + str(i))
		tab.toggle_mode = true
		tab.set_pressed_no_signal(i == active_tab)
		tab.add_theme_stylebox_override("pressed", tab.get_theme_stylebox("normal"))
		if i < 2: tab.tooltip_text = "Espoirs de 19 à 21 ans" if i == 0 else "Espoirs jusqu’à 18 ans"
	D.line(self, Vector2(1, 304), Vector2(2248, 304), Color(C.LINE, .90))

func _open_tab(index: int) -> void:
	state.tab = index
	state.erase("group")
	state.page = 0
	app._render()

func _filtered(group: String) -> Array:
	var people := professionals if group == "professional" else roster
	return people.filter(func(p: Dictionary):
		var age := int(p.get("age", 0))
		if group == "u18" and age > 18: return false
		if group == "u21" and (age <= 18 or age > 21): return false
		if not str(state.get("position", "")).is_empty() and p.get("pos") != state.position: return false
		if int(state.get("potential", 0)) > 0 and float(p.get("potential", 0)) < int(state.potential): return false
		var preparation := str(state.get("preparation", ""))
		if preparation == "fit" and float(p.get("injury", 0)) > 0: return false
		if preparation == "planned" and _path(p).get("path") != "professionnel": return false
		if preparation == "watched" and float(p.get("condition", 100)) >= 70: return false
		return true)

func _select_visible(people: Array) -> void:
	selected = {}
	if people.is_empty(): return
	var maximum := maxi(0, ceili(float(people.size()) / PAGE_SIZE) - 1)
	var index := clampi(int(state.get("page", 0)), 0, maximum)
	state.page = index
	var shown := people.slice(index * PAGE_SIZE, (index + 1) * PAGE_SIZE)
	for person: Dictionary in shown:
		if person.id == state.get("player"):
			selected = person
			return
	selected = shown[0]
	for person: Dictionary in shown:
		if float(person.get("potential", 0)) > float(selected.get("potential", 0)): selected = person
	state.player = selected.id

func _table(group: String, people: Array) -> void:
	var table := D.panel(self, Rect2(1, 317, 1393, 581), "", "", "", "AcademyImmersiveTable")
	_icon(table, "search", Rect2(22, 20, 25, 25), C.IVORY)
	D.text(table, 59, 42, "Filtres", 26, C.IVORY, 700, 115)
	_picker(table, Rect2(144, 12, 227, 43), "AcademyImmersiveGroup", "Groupe", {"u21":"U21", "u18":"U18", "academy":"Tous les Espoirs", "professional":"Jeunes professionnels"}, group, func(value): _set_filter("group", value))
	var positions := {"":"Tous"}
	var source := professionals if group == "professional" else roster
	for p: Dictionary in source:
		var position := str(p.get("pos", ""))
		if not position.is_empty(): positions[position] = position
	_picker(table, Rect2(391, 12, 252, 43), "AcademyImmersivePosition", "Poste", positions, state.get("position", ""), func(value): _set_filter("position", value))
	_picker(table, Rect2(663, 12, 255, 43), "AcademyImmersivePotential", "Potentiel", {0:"Tous", 80:"80 et +", 85:"85 et +", 90:"90 et +"}, state.get("potential", 0), func(value): _set_filter("potential", value))
	_picker(table, Rect2(938, 12, 308, 43), "AcademyImmersivePreparation", "Préparation", {"":"Tous", "fit":"Disponibles", "watched":"Condition < 70 %", "planned":"Parcours pro"}, state.get("preparation", ""), func(value): _set_filter("preparation", value))
	var header := D.rect(table, Rect2(13, 69, 1367, 36), Color("1b2828"), 5)
	for column: Array in [["#", 22, 40], ["JOUEUR", 127, 247], ["ÂGE", 365, 70], ["POSTE", 462, 194], ["NIVEAU", 657, 90], ["POTENTIEL", 745, 105], ["PROGRESSION", 850, 144], ["TEMPS DE JEU", 997, 143], ["STATUT", 1148, 197]]:
		D.text(header, column[1], 25, column[0], 18, C.MUTED, 700, column[2])
	rows = Control.new()
	rows.name = "AcademyImmersiveRows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(rows)
	D.place(rows, Rect2(13, 106, 1367, 434))
	_draw_rows(people)
	var previous_page := _action(table, Rect2(973, 546, 104, 27), "Préc.", func(): _change_page(-1), false, "", "AcademyImmersivePrevious")
	previous_page.add_theme_font_size_override("font_size", C.px(18))
	var next_page := _action(table, Rect2(1260, 546, 115, 27), "Suiv.", func(): _change_page(1), false, "", "AcademyImmersiveNext")
	next_page.add_theme_font_size_override("font_size", C.px(18))
	previous_page.disabled = int(state.get("page", 0)) <= 0
	next_page.disabled = (int(state.get("page", 0)) + 1) * PAGE_SIZE >= people.size()
	D.text(table, 1170, 568, "%s / %s" % [int(state.get("page", 0)) + 1, maxi(1, ceili(float(people.size()) / PAGE_SIZE))], 19, C.MUTED, 500, 172, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(table, 20, 568, "%d joueur(s) · minutes juniors si parcours actifs" % people.size(), 19, C.MUTED, 500, 874)

func _set_filter(key: String, value: Variant) -> void:
	state[key] = value
	if key == "group":
		state.erase("position")
		state.erase("preparation")
	state.page = 0
	app._render()

func _change_page(offset: int) -> void:
	state.page = maxi(0, int(state.get("page", 0)) + offset)
	app._render()

func _draw_rows(people: Array) -> void:
	var start := int(state.get("page", 0)) * PAGE_SIZE
	var shown := people.slice(start, start + PAGE_SIZE)
	if shown.is_empty():
		D.text(rows, 24, 65, "Aucun joueur dans cette sélection.", 29, C.IVORY, 600, 1301)
		D.text(rows, 24, 109, "Changez le groupe d’âge ou les filtres pour retrouver les Espoirs de votre carrière.", 23, C.MUTED, 500, 1301)
	for i in shown.size():
		var p: Dictionary = shown[i]
		var status := _status(p)
		var hit := _action(rows, Rect2(1, i * 36, 1365, 35), "", func(): _select(p), false, "", "AcademyRow_" + str(p.id).replace(":", "_"))
		hit.set_meta("development_id", p.id)
		hit.accessibility_name = str(p.name) + " · " + str(status[0])
		hit.tooltip_text = "%s · %s" % [p.name, p.pos]
		_row_style(hit, p.id == selected.get("id"), i)
		D.text(hit, 33, 27, G.n(start + i + 1), 25, C.IVORY, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
		_portrait(hit, p, Rect2(78, 0, 44, 35))
		D.text(hit, 130, 27, str(p.name), 26, C.IVORY, 700, 222)
		D.text(hit, 365, 26, G.n(p.age) + " ans", 21, C.IVORY, 500, 87)
		D.text(hit, 462, 26, str(p.pos), 22, C.IVORY, 500, 190)
		D.text(hit, 700, 27, G.n(p.get("note", "—")), 26, C.IVORY, 700, 82, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(hit, 796, 27, G.n(p.get("potential", "—")), 26, GOLD, 700, 88, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(hit, 907, 27, _change(p), 24, GREEN, 700, 117, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(hit, 1054, 26, G.n(_minutes(p)) + " min", 22, C.IVORY, 500, 123, HORIZONTAL_ALIGNMENT_CENTER)
		if status[1] == C.IVORY:
			D.text(hit, 1148, 26, status[0], 21, C.IVORY, 500, 204)
		else:
			D.chip(hit, Rect2(1138, 4, 211, 27), status[0], status[1])
		D.line(hit, Vector2(11, 35), Vector2(1354, 35), Color(C.LINE, .54))

func _row_style(hit: Button, active: bool, row: int) -> void:
	var style := C.box(Color("075331") if active else Color("111b1b") if row % 2 else Color("0e1719"), Color("43a86d") if active else Color.TRANSPARENT, 5, 0)
	hit.add_theme_stylebox_override("normal", style)

func _select(p: Dictionary) -> void:
	state.player = p.id
	selected = p
	for i in rows.get_child_count():
		var child := rows.get_child(i)
		if child is Button: _row_style(child, child.get_meta("development_id", "") == p.id, i)
	_update_integration()
	_dossier()

func _update_integration() -> void:
	integration.disabled = selected.is_empty() or _professional(selected) or not development.get("promotionAvailable", false)
	integration.tooltip_text = "Consulter les conditions du premier contrat professionnel" if not integration.disabled else "Sélectionnez un Espoir et vérifiez les places disponibles."

func _dossier() -> void:
	if is_instance_valid(dossier):
		remove_child(dossier)
		dossier.queue_free()
	dossier = D.panel(self, Rect2(1410, 317, 838, 581), "", "", "", "AcademyImmersiveDossier")
	dossier.clip_contents = true
	if selected.is_empty():
		D.photo(dossier, "academy-training", Rect2(2, 2, 293, 336))
		D.text(dossier, 308, 63, "Aucun dossier sélectionné", 38, C.IVORY, 700, 510)
		D.text(dossier, 310, 105, "Choisissez un joueur dans le tableau.", 25, C.MUTED, 500, 510)
		return
	_portrait(dossier, selected, Rect2(2, 2, 293, 336), true)
	var p := selected
	var progress: Dictionary = p.get("development", {})
	var info := _path(p)
	var shirt: Array = pathway.get("lineup", [])
	var slot := shirt.find(p.id)
	var badge := D.rect(dossier, Rect2(291, 12, 76, 59), Color("12221c"), 8, Color(GREEN, .84))
	D.text(badge, 38, 44, G.n(slot + 1) if slot >= 0 else "—", 40, C.IVORY, 800, 65, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(dossier, 387, 46, str(p.name).to_upper(), 45, C.IVORY, 800, 426)
	D.text(dossier, 388, 74, "%s  ·  %s ANS" % [str(p.pos).to_upper(), G.n(p.age)], 23, C.IVORY, 600, 424)
	_number_card(dossier, Rect2(337, 91, 210, 89), G.n(p.get("note", "—")), "Niveau au poste", GREEN)
	_number_card(dossier, Rect2(571, 91, 245, 89), G.n(p.get("potential", "—")), "Potentiel estimé", GOLD)
	D.line(dossier, Vector2(307, 194), Vector2(817, 194))
	_icon(dossier, "star", Rect2(309, 207, 26, 26), GREEN)
	D.text(dossier, 345, 230, "Suivi de formation", 25, GREEN, 700, 244)
	_icon(dossier, "warning", Rect2(580, 207, 25, 25), RED)
	D.text(dossier, 616, 230, "Vigilance", 25, RED, 700, 202)
	D.line(dossier, Vector2(564, 209), Vector2(564, 324), Color(C.LINE, .75))
	var focus := _focus_name(progress)
	var left := [focus, "%s minutes de jeu" % G.n(_minutes(p)), PATHS.get(info.get("path", ""), "Suivi individuel")]
	var right := ["Condition · %s %%" % G.n(p.get("condition", "—")), "Indisponible · %s sem." % G.n(p.get("injury", 0)) if float(p.get("injury", 0)) > 0 else "Disponible"]
	for i in left.size(): D.text(dossier, 313, 261 + i * 26, left[i], 21, C.IVORY, 500, 241)
	for i in right.size(): D.text(dossier, 584, 261 + i * 26, right[i], 21, C.IVORY, 500, 231)
	D.line(dossier, Vector2(18, 339), Vector2(820, 339))
	_trend(dossier, p)
	var action := _action(dossier, Rect2(20, 518, 796, 48), "Ouvrir le suivi individuel  ·  " + str(_status(p)[0]), func(): _focus_dialog(p), true, "arrow", "AcademyIndividualProgress")
	action.add_theme_font_size_override("font_size", C.px(23))

func _trend(parent: Node, p: Dictionary) -> void:
	var history: Array = p.get("development", {}).get("history", [])
	var chart := Trend.new()
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for year: Dictionary in history:
		var value: Variant = year.get("end")
		if value is float or value is int: chart.levels.append(float(value))
	if p.get("rating") is float or p.get("rating") is int: chart.levels.append(float(p.rating))
	if not chart.levels.is_empty():
		chart.minimum = maxf(0, floorf((float(chart.levels.min()) - 2) / 5.0) * 5.0)
		chart.maximum = minf(100, ceilf((float(chart.levels.max()) + 2) / 5.0) * 5.0)
	D.text(parent, 26, 371, "Progression", 28, C.IVORY, 700, 147)
	D.text(parent, 174, 371, "Niveau général · %s aujourd’hui" % G.n(p.get("rating","—")), 21, C.MUTED, 500, 510).name = "AcademyGeneralRating"
	parent.add_child(chart)
	D.place(chart, Rect2(76, 389, 610, 101))
	for i in 4:
		var amount := lerpf(chart.maximum, chart.minimum, float(i) / 3.0)
		D.text(parent, 62, 397 + i * 32, G.n(amount), 17, C.IVORY, 500, 35, HORIZONTAL_ALIGNMENT_RIGHT)
	if not history.is_empty(): D.text(parent, 77, 507, "SAISON " + G.n(history[0].get("season","—")), 16, C.MUTED, 500, 190)
	D.text(parent, 686, 507, "CETTE SAISON", 16, C.MUTED, 500, 180, HORIZONTAL_ALIGNMENT_RIGHT)
	_number_card(parent, Rect2(704, 382, 114, 119), _change(p), "Cette saison", GREEN)

func _pathways() -> void:
	var panel := D.panel(self, Rect2(1, 317, 1393, 581), "Du centre au rugby professionnel", "school", "", "AcademyPathwayPane")
	D.text(panel, 25, 107, Copy.notice("academy", pathway.get("description", "Choisissez un Espoir pour suivre sa progression.")), 25, C.IVORY, 500, 1347)
	var people := _prospects()
	D.text(panel, 25, 150, "LES MEILLEURS POTENTIELS ESTIMÉS", 24, GOLD, 700, 1250)
	for i in mini(6, people.size()):
		var p: Dictionary = people[i]
		var entry := _action(panel, Rect2(23 + (i % 2) * 681, 173 + floori(i / 2.0) * 85, 665, 75), "", func():
			state.player = p.id
			selected = p
			_update_integration()
			_dossier(), false, "", "AcademyPathway_" + str(p.id).replace(":", "_"))
		entry.accessibility_name = str(p.name)
		_portrait(entry, p, Rect2(10, 5, 75, 63))
		D.text(entry, 106, 32, str(p.name), 28, C.IVORY, 700, 464)
		D.text(entry, 106, 59, "%s  ·  %s ans" % [p.pos, G.n(p.age)], 22, C.MUTED, 500, 466)
		D.text(entry, 646, 51, G.n(p.potential), 42, GOLD, 700, 75, HORIZONTAL_ALIGNMENT_RIGHT)
	_action(panel, Rect2(22, 461, 1349, 66), "Ouvrir les parcours du centre  ·  mentorats, prêts et détection", func(): app._navigate("Centre"), true, "arrow", "AcademyOpenCentre")

func _prospects() -> Array:
	var prospects := roster.duplicate()
	prospects.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("potential", 0)) > float(b.get("potential", 0)))
	return prospects

func _staff_page() -> void:
	var panel := D.panel(self, Rect2(1, 317, 1393, 581), "Le centre de formation", "people", "", "AcademyStaffPane")
	D.text(panel, 25, 106, Copy.notice("academy", pathway.get("description", "Aucune donnée d’encadrement disponible.")), 25, C.IVORY, 500, 1345)
	var labels := [["Éducateurs", G.n(pathway.get("coaches", "—")), "people"], ["Installations", G.n(pathway.get("facilities", "—")), "home"], ["Cohésion", G.n(pathway.get("cohesion", "—")), "heart"]]
	for i in labels.size():
		var item: Array = labels[i]
		var tile := D.panel(panel, Rect2(23 + i * 454, 136, 435, 178), item[0], item[2])
		D.text(tile, 25, 140, item[1], 65, GREEN, 700, 380)
	D.text(panel, 25, 376, "Les décisions du centre restent accessibles depuis son carnet.", 25, C.MUTED, 500, 1348)
	_action(panel, Rect2(23, 428, 660, 63), "Gérer le centre", func(): app._navigate("Centre"), true, "arrow", "AcademyManageCentre")
	_action(panel, Rect2(707, 428, 661, 63), "Ouvrir le staff", func(): app._navigate("Staff"), false, "arrow", "AcademyOpenStaff")

func _inactive_pathway_status() -> String:
	return "Parcours à activer" if pathway.get("available", false) else "Parcours indisponibles"

func _lower_pathways() -> void:
	var tile := D.panel(self, Rect2(1, 916, 1272, 303), "Parcours de formation · les prochaines étapes", "school", "", "AcademyLowerPathways")
	var loans: Array = pathway.get("loans", [])
	var promoted: Array = pathway.get("promotions", [])
	var active: bool = pathway.get("active", false)
	var entries := [
		["ACADÉMIE", "%d Espoirs" % roster.size(), GREEN, "school", _prospects()],
		["PASSERELLES", "%d prêt(s) en cours" % loans.size() if active else _inactive_pathway_status(), C.MINT, "arrow", loans],
		["ÉQUIPE PREMIÈRE", "%d promotion(s)" % promoted.size() if active else "Premiers contrats", GOLD, "trophy", promoted],
	]
	for i in entries.size():
		var entry: Array = entries[i]
		var x := 23 + i * 416
		var click := _action(tile, Rect2(x, 70, 385, 97), "", func():
			if i == 1: app._navigate("Centre")
			elif i == 2: app._navigate("Effectif")
			else: _open_tab(2), i != 1, "", "AcademyStage" + str(i))
		click.accessibility_name = str(entry[0])
		var tone: Color = entry[2]
		var bg := Color("43330c") if i == 2 else Color("0e2d2b") if i == 1 else Color("06482c")
		click.add_theme_stylebox_override("normal", D.surface(385, 97, bg.lightened(.12), bg.darkened(.16), tone))
		_icon(click, entry[3], Rect2(25, 23, 39, 39), tone)
		D.text(click, 81, 43, entry[0], 31, C.IVORY, 700, 294)
		D.text(click, 81, 76, str(entry[1]), 24, C.IVORY, 500, 293)
		if i < 2: _icon(tile, "arrow", Rect2(x + 387, 101, 23, 23), C.IVORY)
		D.text(tile, x, 200, ["Potentiels estimés", "Joueurs en prêt", "Joueurs promus"][i], 22, C.IVORY, 600, 386)
		var people: Array = entry[4]
		if people.is_empty():
			var caption := "Aucun dossier"
			if not active and i > 0:
				caption = "Disponible dans le centre" if pathway.get("available", false) else "—"
			D.text(tile, x, 244, caption, 21, C.MUTED, 500, 385)
		for j in mini(2, people.size()):
			var p: Dictionary = people[j]
			var card := D.rect(tile, Rect2(x + j * 195, 213, 184, 65), Color("132024"), 6, C.LINE)
			_portrait(card, p, Rect2(4, 5, 54, 55))
			D.text(card, 65, 28, p.get("name", "Joueur"), 19, C.IVORY, 700, 113)
			D.text(card, 65, 52, p.get("pos", "Carrière"), 17, C.MUTED, 500, 113)

func _staff_card() -> void:
	var tile := D.panel(self, Rect2(1291, 916, 508, 303), "Encadrement de l’académie", "people", "", "AcademyStaffCard")
	var labels := [["Éducateurs", "Niveau " + G.n(pathway.get("coaches", "—"))], ["Installations", "Niveau " + G.n(pathway.get("facilities", "—"))], ["Cohésion du centre", G.n(pathway.get("cohesion", "—")) + " / 100"]]
	for i in 3:
		var y := 66 + i * 76
		var p: Dictionary = staff[i] if i < staff.size() else {}
		_portrait(tile, p, Rect2(13, y, 70, 63), false, ["training-coach", "mail-trainer", "mail-medical"][i])
		D.text(tile, 100, y + 27, p.get("name", labels[i][0]), 26, C.IVORY, 700, 390)
		D.text(tile, 100, y + 55, p.get("role", labels[i][1]), 22, C.MUTED, 500, 390)
		D.line(tile, Vector2(13, y + 68), Vector2(494, y + 68), Color(C.LINE, .70))

func _academy_staff() -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("id") != app.model.get("club", {}).get("id"): continue
		var members: Array = team.get("members", [])
		return members.filter(func(p: Dictionary):
			var role := str(p.get("role", "")).to_lower()
			return role.contains("espoir") or role.contains("formation") or role.contains("académie") or role.contains("junior"))
	return []

func _junior() -> void:
	var tile := D.panel(self, Rect2(1817, 916, 431, 303), "Compétition junior", "calendar", "", "AcademyJuniorCompetition")
	var results: Array = pathway.get("results", [])
	var context := _inactive_pathway_status()
	var subline := "Calendrier indépendant du championnat pro" if pathway.get("available", false) else "Suivi des Espoirs dans Formation"
	if pathway.get("active", false):
		var round := int(pathway.get("juniorRound", 0))
		var total := int(pathway.get("totalRounds", 0))
		context = "PÉRIODE %d / %d" % [mini(round + 1, total), total] if round < total else "PÉRIODES TERMINÉES"
	var ours: Dictionary = app.model.club
	var crest := G.crest(ours, C.px(83))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(crest)
	D.place(crest, Rect2(38, 110, 83, 99))
	D.text(tile, 80, 229, G.club_abbr(ours), 21, GOLD, 700, 102, HORIZONTAL_ALIGNMENT_CENTER)
	if not results.is_empty():
		var match_result: Dictionary = results[-1]
		var home: bool = match_result.get("home") == ours.get("id")
		var opponent_id: Variant = match_result.get("away") if home else match_result.get("home")
		var opponent := _club(opponent_id)
		var opponent_crest := G.crest(opponent, C.px(82))
		opponent_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(opponent_crest)
		D.place(opponent_crest, Rect2(310, 110, 82, 99))
		D.text(tile, 351, 229, G.club_abbr(opponent), 21, GOLD, 700, 111, HORIZONTAL_ALIGNMENT_CENTER)
		var score: Array = match_result.get("score", [])
		if score.size() == 2:
			D.text(tile, 217, 179, "%s – %s" % [G.n(score[0 if home else 1]), G.n(score[1 if home else 0])], 40, C.IVORY, 700, 177, HORIZONTAL_ALIGNMENT_CENTER)
		subline = "Dernier résultat connu · période %s" % G.n(int(match_result.get("round", 0)) + 1)
	else:
		_icon(tile, "school", Rect2(304, 130, 73, 73), C.MUTED)
		D.text(tile, 217, 175, "—", 46, C.IVORY, 700, 92, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tile, 343, 229, "ESPOIRS", 21, GOLD, 700, 118, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(tile, 215, 91, context, 30, GOLD, 700, 409, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(tile, Vector2(13, 243), Vector2(417, 243), Color(C.LINE, .72))
	D.text(tile, 215, 278, subline, 20, C.IVORY, 500, 405, HORIZONTAL_ALIGNMENT_CENTER)

func _club(club_id: Variant) -> Dictionary:
	for entry: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if entry.get("id") == club_id: return entry
	return {"name":"Centre", "abbr":"Centre", "color":"#436859"}

func _integration_dialog() -> void:
	if selected.is_empty() or _professional(selected): return
	var p := selected
	var info := _path(p)
	var dialog_parts := _dialog("AcademyIntegrationDialog", "Préparer l’intégration · " + str(p.name))
	var dialog: AcceptDialog = dialog_parts[0]
	var body: VBoxContainer = dialog_parts[1]
	body.add_child(C.wrap("%s · %s ans · niveau %s · potentiel estimé %s" % [p.pos, G.n(p.age), G.n(p.note), G.n(p.potential)], 26, C.IVORY, true))
	body.add_child(C.wrap("Le joueur rejoint l’effectif professionnel si l’offre est confirmée et autorisée par la carrière.", 22, C.MUTED, true))
	var standard := C.button("Premier contrat pro  ·  %s / semaine" % G.euros(p.salary), func():
		var end_season := int(app.model.meta.get("season", 0)) + (2 if app.model.meta.get("phase") == "ended" else 1)
		app.confirm("Promouvoir " + str(p.name), "%s rejoindra l’effectif professionnel et ajoutera %s de salaire par semaine. Fin de contrat à la fin de la saison %s. Confirmer ?" % [p.name, G.euros(p.salary), G.n(end_season)], func(): app._command("promote_academy", {"playerId":p.id, "confirmed":true})), true, app.accent)
	standard.name = "AcademyPromoteSelected"
	standard.set_meta("promote_id", p.id)
	standard.disabled = not development.get("promotionAvailable", false)
	body.add_child(standard)
	if pathway.get("active", false) and not info.is_empty():
		body.add_child(C.label("Offres des parcours du centre", 23, GOLD))
		var salaries: Array = info.get("promotionSalary", [])
		for i in salaries.size():
			var years := i + 1
			var wage := G.euros(salaries[i])
			var offer := C.button("%d saison(s)  ·  %s / semaine" % [years, wage], func():
				var args: Dictionary = pathway.context.duplicate()
				args.merge({"playerId":p.id, "years":years, "confirmed":true})
				app.confirm("Premier contrat professionnel", "%s quittera le centre et ajoutera %s par semaine à la masse salariale pour %d saison(s). Confirmer ?" % [p.name, wage, years], func(): app._command("academy_promote", args)))
			offer.name = "AcademyOfferYears" + str(years)
			offer.disabled = pathway.get("locked", false) or not pathway.get("promotionAvailable", false)
			body.add_child(offer)
	_popup(dialog, 770, 420)

func _focus_dialog(p: Dictionary) -> void:
	var dialog_parts := _dialog("AcademyFocusDialog", "Progression · " + str(p.name))
	var dialog: AcceptDialog = dialog_parts[0]
	var body: VBoxContainer = dialog_parts[1]
	var detail: Dictionary = p.get("development", {})
	body.add_child(C.wrap("%s minutes · %s apparition(s) · %s de progression cette saison" % [G.n(_minutes(p)), G.n(p.get("appearances", 0)), _change(p)], 24, C.IVORY, true))
	for year: Dictionary in detail.get("history", []):
		body.add_child(C.label("S%s · %s → %s · %s min" % [G.n(year.get("season", "—")), G.n(year.get("start", "—")), G.n(year.get("end", "—")), G.n(year.get("minutes", 0))], 21))
	if detail.get("history", []).is_empty(): body.add_child(C.wrap("Historique annuel disponible après l’intersaison.", 19, C.MUTED, true))
	var options := {}
	for option: Dictionary in detail.get("options", []): options[option.id] = option.label
	if not options.is_empty():
		var control := _option("Focus" + str(p.id).replace(":", "_"), "Spécialisation", options, detail.get("focus"), func(value):
			dialog.hide()
			dialog.queue_free()
			app._command("set_development_focus", {"playerId":p.id, "focus":value}))
		control.disabled = not detail.get("available", false)
		body.add_child(control)
		body.add_child(C.wrap(str(detail.get("reason", "")) if control.disabled else "Changer d’axe remet à zéro l’expérience partielle non dépensée. Les qualités déjà acquises sont conservées.", 19, C.MUTED, true))
	if _professional(p):
		body.add_child(C.button("Ouvrir la fiche du joueur", func():
			dialog.hide()
			dialog.queue_free()
			app.selected_player = str(p.id)
			app._navigate("Effectif")))
	else:
		body.add_child(C.button("Ouvrir les parcours du centre", func():
			dialog.hide()
			dialog.queue_free()
			app._navigate("Centre")))
	_popup(dialog, 790, 450)

func _option(id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> OptionButton:
	var control := OptionButton.new()
	control.name = id
	control.accessibility_name = caption
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.add_theme_font_override("font", C.DISPLAY)
	control.add_theme_font_size_override("font_size", C.px(22))
	control.add_theme_color_override("font_color", C.IVORY)
	control.add_theme_color_override("font_hover_color", C.IVORY)
	control.add_theme_stylebox_override("normal", C.box(Color("101819"), C.LINE, 5, 11))
	control.add_theme_stylebox_override("hover", C.box(Color("19322a"), C.MINT, 5, 11))
	control.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, GOLD, 5, 0))
	var menu := control.get_popup()
	menu.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 5, 10))
	menu.add_theme_font_override("font", C.DISPLAY)
	menu.add_theme_font_size_override("font_size", C.px(22))
	menu.add_theme_color_override("font_color", C.IVORY)
	menu.add_theme_color_override("font_hover_color", C.IVORY)
	for key: Variant in choices:
		control.add_item(caption + " · " + str(choices[key]))
		control.set_item_metadata(control.item_count - 1, key)
		if key == chosen: control.select(control.item_count - 1)
	control.item_selected.connect(func(index: int): callback.call(control.get_item_metadata(index)))
	return control

func _picker(parent: Node, rectangle: Rect2, id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> void:
	var control := _option(id, caption, choices, chosen, callback)
	parent.add_child(control)
	D.place(control, rectangle)

func _dialog(id: String, title: String) -> Array:
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = id
	app._prepare_dialog(dialog, C.px(640))
	dialog.title = title
	dialog.get_ok_button().text = "Fermer"
	var body := C.v(13)
	dialog.add_child(body)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	return [dialog, body]

func _popup(dialog: AcceptDialog, width: int, height: int) -> void:
	dialog.popup_centered(Vector2i(C.px(width), C.px(height)))

func _change(p: Dictionary) -> String:
	var baseline: Variant = p.get("development", {}).get("seasonStart")
	if not (baseline is int or baseline is float) or not (p.get("rating") is int or p.get("rating") is float): return "—"
	var delta := roundi(float(p.rating) - float(baseline))
	return "+%s" % G.n(delta) if delta > 0 else G.n(delta)

func _minutes(p: Dictionary) -> Variant:
	if pathway.get("active", false) and not _professional(p): return _path(p).get("minutes", p.get("minutes", 0))
	return p.get("minutes", 0)

func _path(p: Dictionary) -> Dictionary:
	return academy_by_id.get(p.get("id", ""), {})

func _professional(p: Dictionary) -> bool:
	return p in professionals

func _status(p: Dictionary) -> Array:
	var info := _path(p)
	if float(p.get("injury", 0)) > 0: return ["Indisponible", RED]
	if float(p.get("condition", 100)) < 70: return ["Condition à surveiller", C.AMBER]
	if _professional(p): return ["Jeune professionnel", C.IVORY]
	if info.get("path") == "professionnel": return ["Parcours professionnel", GREEN]
	if float(info.get("target", 0)) > 0 and float(info.get("minutes", 0)) >= float(info.target): return ["Objectif atteint", GREEN]
	return ["En formation", C.IVORY]

func _focus_name(source: Dictionary) -> String:
	for option: Dictionary in source.get("options", []):
		if option.get("id") == source.get("focus"): return str(option.get("label", "Équilibré"))
	return "Équilibré"

func _number_card(parent: Node, rectangle: Rect2, value: String, caption: String, tone: Color) -> void:
	var background := Color("413010") if tone == GOLD else Color("09432b")
	var tile := D.rect(parent, rectangle, background, 9, tone)
	D.text(tile, rectangle.size.x * .5, rectangle.size.y * .59, value, 50 if rectangle.size.x > 140 else 37, tone if tone == GOLD else C.IVORY, 800, rectangle.size.x - 15, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(tile, rectangle.size.x * .5, rectangle.size.y - 13, caption, 22 if rectangle.size.x > 140 else 17, C.IVORY, 500, rectangle.size.x - 11, HORIZONTAL_ALIGNMENT_CENTER)

func _veil(parent: Node, rectangle: Rect2, colors: Array[Color], stops: Array[float]) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(stops)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	var overlay := TextureRect.new()
	overlay.texture = texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	D.place(overlay, rectangle)

func _icon(parent: Node, icon: String, rectangle: Rect2, color: Color) -> void:
	var graphic := C.icon(icon, int(rectangle.size.x), color)
	parent.add_child(graphic)
	D.place(graphic, rectangle)

func _portrait(parent: Node, p: Dictionary, rectangle: Rect2, large: bool = false, fallback: String = "") -> void:
	if not str(p.get("id", "")).is_empty():
		var portrait := G.portrait(int(p.get("portraitIndex", 0)), 0, p)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		parent.add_child(portrait)
		D.place(portrait, rectangle)
		if large and portrait.material != null:
			_veil(parent, Rect2(rectangle.end.x - 34, rectangle.position.y, 34, rectangle.size.y), [Color("11191a", .0), Color("11191a")], [0.0, 1.0])
	elif large:
		D.photo(parent, "academy-player", rectangle)
		_veil(parent, Rect2(rectangle.end.x - 34, rectangle.position.y, 34, rectangle.size.y), [Color("11191a", .0), Color("11191a")], [0.0, 1.0])
	elif not fallback.is_empty():
		D.photo(parent, fallback, rectangle)
	else:
		var id := str(p.get("id", ""))
		var from_squad := P.player(app.model, id)
		var index := int(from_squad.get("portraitIndex", p.get("portraitIndex", id.hash())))
		D.photo(parent, "player-%02d" % posmod(index, 16), rectangle)

func _action(parent: Node, rectangle: Rect2, caption: String, callback: Callable, primary: bool, icon: String, id: String) -> Button:
	return D.button(parent, rectangle, caption, callback, primary, icon, false, Color("09673e"), id)
