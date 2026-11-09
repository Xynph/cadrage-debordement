extends Control
## Vue de la semaine. Les repères organisent les décisions d’une seule séance simulée.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const TABS = ["Semaine", "Groupes", "Individuel", "Staff"]
const MODES = {"repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}
const INDIVIDUAL = {"collective":"Suivre le collectif", "repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}
const TOPICS = ["COLLECTIF", "GROUPES", "INDIVIDUEL", "VIGILANCE", "CONSIGNES", "MATCH", "ENCADREMENT"]
const FAMILIES = [["PIL.", [0]], ["TAL.", [1]], ["2e L.", [2]], ["3e L.", [3]], ["CHAR.", [4, 5]], ["CEN.", [7]], ["3/4", [6, 8]]]
const GREEN = Color("59eb89")
const PALE_GOLD = Color("f7ce72")
const SLOTS = [
	["train", "Séance collective", "Choisir la charge", "Une séance collective agit sur la récupération et le développement.", "Modifier la séance"],
	["flag", "Travail spécifique", "Préparation ciblée", "Choisissez le travail spécifique avant d’effectuer la séance.", "Modifier le travail"],
	["people", "Plan des groupes", "Répartir les charges", "Le plan affecte des charges individuelles et conserve la séance disponible.", "Voir les plans"],
	["people", "Avants et arrières", "Condition et charge", "Comparez les groupes de poste et les charges effectives de l’effectif.", "Voir les groupes"],
	["star", "Axes individuels", "Développement", "Les spécialisations disponibles dépendent du profil et de la semaine.", "Suivre les joueurs"],
	["train", "Charge individuelle", "Exceptions au collectif", "Ajustez les charges avant la séance. Les joueurs blessés récupèrent.", "Ajuster les charges"],
	["heart", "Récupération", "Vigilance physique", "L’effectif met en évidence la charge cumulée et la condition actuelle.", "Voir les joueurs"],
	["heart", "Suivi médical", "Disponibilité et reprise", "Le suivi médical du club applique les protocoles de simulation à la séance suivante.", "Ouvrir le suivi"],
	["tactic", "Plan de jeu", "Consignes collectives", "Ouvrez vos choix de jeu et les consignes de préparation du match.", "Ouvrir le plan de jeu"],
	["shield", "Niveau adverse", "Entraîneurs adverses", "Le niveau règle les choix des entraîneurs adverses dans la simulation.", "Ajuster le niveau"],
	["people", "Feuille de match", "XV et banc", "Contrôlez la qualification et la disponibilité des joueurs de la feuille.", "Ouvrir la composition"],
	["ball", "Jour de match", "Prochaine rencontre", "Retrouvez les informations de la prochaine rencontre.", "Aller au jour de match"],
	["info", "Conseil du staff", "État du groupe", "Consultez le diagnostic actuel et les responsabilités de l’encadrement.", "Voir les conseils"],
	["people", "Délégation", "Charge et sélection", "Confiez la sélection ou la charge collective au staff.", "Voir la délégation"],
]

var app: Control
var state: Dictionary
var squad: Array
var watched: Array
var staff: Array
var training: Dictionary
var support: Dictionary
var locked := false
var trained := false
var active_tab := 0
var week_panel: Panel
var selection_buttons: Array[Button] = []

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.app = application
	page.name = "ImmersiveTraining"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

func _build() -> void:
	var meta: Dictionary = app.model.get("meta", {})
	var decisions: Dictionary = app.model.get("decisions", {})
	training = decisions.get("training", {})
	support = app.model.get("clubLife", {}).get("clubSupport", {})
	squad = app.model.get("squad", [])
	watched = squad.filter(func(p: Dictionary): return float(p.get("physicalLoad", 0)) >= 55 or float(p.get("condition", 100)) < 70)
	watched.sort_custom(func(a: Dictionary, b: Dictionary): return _risk(a) > _risk(b))
	staff = _staff_members()
	trained = meta.get("trained", false)
	locked = not app._live().is_empty() or meta.get("phase") == "ended"
	if not app.management_ui.get("immersive_training") is Dictionary:
		app.management_ui.immersive_training = {}
	state = app.management_ui.immersive_training
	var week_key := str([app.model.get("club", {}).get("id"), meta.get("season"), meta.get("week")])
	if state.get("week") != week_key or state.get("stored_mode") != meta.get("training"):
		state.week = week_key
		state.stored_mode = meta.get("training")
		state.mode = str(meta.get("training", "normal"))
	active_tab = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	D.text(self, 29, 34, "PRÉPARATION DU GROUPE", 28, PALE_GOLD, 700, 320)
	D.line(self, Vector2(335, 24), Vector2(486, 24), Color(PALE_GOLD, .72), 2)
	app.heading = D.text(self, 27, 103, "La semaine se gagne ici.", 72, C.IVORY, 800, 800)
	var opponent: Dictionary = app.model.get("next") if app.model.get("next") is Dictionary else {}
	var fixture := "Aucune rencontre annoncée"
	if not opponent.is_empty():
		var home: Dictionary = opponent.get("home", {})
		var is_home: bool = home.get("id") == app.model.get("club", {}).get("id")
		fixture = ("Réception · " if is_home else "Déplacement · ") + G.club_name(opponent.get("away", {}) if is_home else home)
	D.text(self, 30, 142, "Semaine %s  ·  %s" % [G.n(int(meta.get("week", 0)) + 1), fixture], 27, C.IVORY, 500, 785)
	_metrics(meta)
	for i in TABS.size():
		var tab := ClubUI.tab(self, Rect2(4 + i * 249, 169, 238, 58), TABS[i], i == active_tab, func(): _open_tab(i), "TrainingTab" + str(i))
		tab.add_theme_font_size_override("font_size", C.px(30))
		var shape := tab.get_theme_stylebox("normal")
		tab.add_theme_stylebox_override("pressed", shape)
		var hover := shape.duplicate() as StyleBoxTexture
		if hover != null:
			hover.modulate_color = Color(1.08, 1.08, 1.08)
			for key in ["hover", "hover_pressed"]: tab.add_theme_stylebox_override(key, hover)
		tab.toggle_mode = true
		tab.set_pressed_no_signal(i == active_tab)
	var dossier := _action(self, Rect2(1002, 169, 294, 58), "Dossier & consignes", func():
		if app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation.tab = 0
		app._navigate("Préparation"), false, "", "TrainingBackToPreparation")
	dossier.tooltip_text = "Revenir au dossier de préparation et aux consignes de jeu"
	var validate := _action(self, Rect2(1316, 166, 424, 58), "Séance effectuée" if trained else "Valider la semaine", _validate, true, "arrow", "TrainingValidateWeek")
	validate.disabled = trained or locked
	validate.add_theme_font_size_override("font_size", C.px(33))
	D.line(self, Vector2(2, 234), Vector2(1741, 234))
	match active_tab:
		0: _week(opponent)
		1: _groups()
		2: _individuals()
		3: _staff_tab()

func _risk(p: Dictionary) -> float:
	return maxf(float(p.get("physicalLoad", 0)), 100.0 - float(p.get("condition", 100)))

func _mode() -> String:
	return str(MODES.get(state.get("mode", "normal"), MODES.normal))

func _staff_members() -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("id") != app.model.get("club", {}).get("id"): continue
		var members: Array = team.get("members", [])
		return members.filter(func(p: Dictionary):
			var role := str(p.get("role", "")).to_lower()
			return role.contains("prépar") or role.contains("entraîn") or role.contains("coach"))
	return []

func _metrics(meta: Dictionary) -> void:
	var group := P.group(app.model)
	var total_load := 0.0
	for p: Dictionary in squad: total_load += float(p.get("physicalLoad", 0))
	var metrics := D.panel(self, Rect2(815, 24, 928, 106), "", "", "", "TrainingMetrics")
	var values := [
		["heart", "Condition", G.n(group.condition) + " %", GREEN],
		["people", "Moral", G.n(meta.get("morale", "—")), GREEN],
		["train", "Charge moyenne", "%d / 100" % roundi(total_load / maxi(1, squad.size())), GREEN],
		["warning", "À surveiller", "%d joueur(s)" % watched.size(), C.ALERT if not watched.is_empty() else GREEN],
	]
	for i in values.size():
		var value: Array = values[i]
		var x := i * 232
		if i > 0: D.line(metrics, Vector2(x, 8), Vector2(x, 98), Color(C.LINE, .8))
		if i == 3 and not watched.is_empty(): D.rect(metrics, Rect2(x+1, 1, 230, 104), Color("2d1b19"), 8)
		_icon(metrics, value[0], Rect2(x + 20, 36, 48, 48), value[3])
		D.text(metrics, x + 81, 40, value[1], 24, C.IVORY, 500, 144)
		D.text(metrics, x + 81, 85, value[2], 38 if i < 3 else 31, value[3], 700, 144)

func _week(fixture: Dictionary) -> void:
	var focus: Dictionary = training.get("collective", {})
	var focus_label := _label(focus, "Sans préparation spécifique")
	var state_caption := "Séance effectuée" if trained else _mode()
	var captions := [
		state_caption, focus_label, "Plans du staff", "%d professionnels" % squad.size(),
		"Spécialisations", "Ajuster les charges", "%d joueur(s) à suivre" % watched.size(),
		"%d joueur(s) suivis" % support.get("medical", {}).get("players", []).size(), "Intentions de jeu",
		_label(app.model.get("decisions", {}).get("difficulty", {}), "Niveau adverse"),
		"Feuille valide" if app.model.get("selection", {}).get("valid", false) else "Feuille à compléter",
		str(fixture.get("label", "Aucune rencontre")), "Diagnostic actuel", "Répartir les décisions",
	]
	var selected := clampi(int(state.get("slot", 0)), 0, SLOTS.size() - 1)
	D.text(self, 6, 256, "PLAN DE SEMAINE  /  1 SÉANCE COLLECTIVE SIMULÉE", 17, C.MUTED, 600, 800)
	for i in TOPICS.size():
		var column := D.panel(self, Rect2(4 + i * 250, 270, 239, 545), "", "", "", "TrainingWeekColumn" + str(i))
		var tone := PALE_GOLD if i == 5 and not fixture.is_empty() else GREEN
		D.rect(column, Rect2(1, 1, 237, 82), Color("433510") if i == 5 and not fixture.is_empty() else Color("074a2e") if i == 0 else Color("15211e"), 8, Color(tone, .55) if i in [0, 5] else Color.TRANSPARENT)
		D.text(column, 119, 29, "%02d  /  %s" % [i + 1, TOPICS[i]], 25, C.IVORY, 700, 224, HORIZONTAL_ALIGNMENT_CENTER)
		D.chip(column, Rect2(37, 42, 165, 29), "SEMAINE EN COURS" if i == 0 else "REPÈRE DU PLAN", tone)
		for band in 2:
			var index := i * 2 + band
			var slot: Array = SLOTS[index]
			var y := 99 + band * 220
			D.rect(column, Rect2(11, y, 217, 31), Color("202a2b"), 5)
			D.text(column, 23, y + 23, "PRÉPARER" if band == 0 else "SUIVRE", 23, C.IVORY, 700, 200)
			var hit := _action(column, Rect2(11, y + 39, 217, 168), "", func(): _select(index), false, "", "TrainingStep" + str(index))
			hit.tooltip_text = slot[3]
			hit.accessibility_name = str(slot[1])
			selection_buttons.append(hit)
			_slot_style(hit, index == selected, index == 11 and not fixture.is_empty())
			_icon(hit, slot[0], Rect2(12, 16, 39, 39), tone if i in [0, 1, 5] else C.IVORY)
			var lines := D.words(str(slot[1]), 14, 2)
			for j in lines.size(): D.text(hit, 60, 33 + j * 24, lines[j], 24, C.IVORY, 700, 146)
			var details := D.words(captions[index], 18, 2)
			for j in details.size(): D.text(hit, 13, 88 + j * 24, details[j], 24, C.IVORY, 500, 192)
			D.text(hit, 13, 157, slot[2], 20, C.MUTED, 500, 191)
			for j in 3:
				D.rect(hit, Rect2(14 + j * 23, 122, 15, 15), tone if j <= (1 if index == selected else 0) else Color("394241"), 9)
		if i == 0: D.line(column, Vector2(13, 310), Vector2(226, 310))
	_chart()
	_vigilance()
	week_panel = D.panel(self, Rect2(1760, 509, 488, 306), "Séance sélectionnée", "train", "", "TrainingSelectedSession")
	_selection(selected)
	var art := D.panel(self, Rect2(4, 840, 1020, 377), "", "", "", "TrainingPhoto")
	art.clip_contents = true
	D.photo(art, "training-session", Rect2(2, 2, 1016, 373))
	_axes(D.panel(self, Rect2(1039, 840, 560, 341), "Axes individuels", "star", "", "TrainingAxes"))
	_staff_cards(D.panel(self, Rect2(1614, 840, 634, 341), "Encadrement", "people", "", "TrainingStaff"))
	D.text(self, 2244, 1217, "Charges et condition issues de votre carrière", 17, C.MUTED, 500, 622, HORIZONTAL_ALIGNMENT_RIGHT)

func _slot_style(hit: Button, selected: bool, match_slot: bool) -> void:
	var style := C.box(Color("17352a") if selected else Color("473509") if match_slot else Color("10191a"), GREEN if selected else PALE_GOLD if match_slot else Color("263130"), 6, 0)
	style.set_border_width_all(3 if selected else 1)
	hit.add_theme_stylebox_override("normal", style)

func _select(index: int) -> void:
	state.slot = index
	for i in selection_buttons.size(): _slot_style(selection_buttons[i], i == index, i == 11 and app.model.get("next") is Dictionary)
	_selection(index)

func _selection(index: int) -> void:
	var existing := week_panel.get_node_or_null("TrainingSelectionContent")
	if existing != null:
		week_panel.remove_child(existing)
		existing.queue_free()
	var holder := Control.new()
	holder.name = "TrainingSelectionContent"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	week_panel.add_child(holder)
	D.place(holder, Rect2(0, 57, 488, 249))
	var slot: Array = SLOTS[index]
	D.photo(holder, "training-coach", Rect2(14, 7, 117, 118))
	_icon(holder, slot[0], Rect2(150, 16, 30, 30), GREEN)
	D.text(holder, 192, 38, slot[1], 29, C.IVORY, 700, 285)
	var detail := str(slot[3])
	if index == 0: detail = ("Séance effectuée · " if trained else "Charge retenue · ") + _mode() + ". " + detail
	if index == 12 and not str(training.get("advice", "")).is_empty(): detail = str(training.advice)
	var lines := D.words(detail, 38, 4)
	for i in lines.size(): D.text(holder, 150, 72 + i * 24, lines[i], 21, C.IVORY, 500, 322)
	D.text(holder, 14, 154, "Préparation du groupe", 20, C.MUTED, 500, 445)
	D.line(holder, Vector2(14, 166), Vector2(471, 166))
	_action(holder, Rect2(17, 181, 453, 52), slot[4], func(): _open_slot(index), true, "arrow", "TrainingEditSelected")

func _chart() -> void:
	var tile := D.panel(self, Rect2(1760, 11, 488, 296), "Charge & récupération", "heart", "", "TrainingLoadChart")
	var top := 79.0
	var bottom := 228.0
	var left := 73.0
	var right := 468.0
	D.rect(tile, Rect2(left, bottom - (bottom - top) * .55, right - left, (bottom - top) * .55), Color("163827"))
	for i in 6:
		var y := bottom - (bottom - top) * i / 5.0
		D.line(tile, Vector2(left, y), Vector2(right, y), Color(C.LINE, .64))
		D.text(tile, 60, y + 5, str(i * 20), 16, C.IVORY, 500, 39, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in FAMILIES.size():
		var family: Array = FAMILIES[i]
		var players := squad.filter(func(p: Dictionary): return p.get("fam", -1) in family[1])
		var total := 0.0
		for player: Dictionary in players: total += float(player.get("physicalLoad", 0))
		var value := total / maxi(1, players.size())
		var x := left + 20 + 56 * i
		var h := maxf(2, (bottom - top) * value / 100.0)
		var color := PALE_GOLD if value >= 55.0 else GREEN
		var bar := D.rect(tile, Rect2(x, bottom - h, 29, h), color.darkened(.22), 2, color)
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		bar.tooltip_text = "%s · charge moyenne %.0f / 100 · %d joueur(s)" % [family[0], value, players.size()] if not players.is_empty() else "%s · aucun joueur" % family[0]
		D.text(tile, x + 15, 253, family[0], 16, C.IVORY, 600, 56, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(tile, Rect2(21, 270, 16, 16), GREEN, 2)
	D.text(tile, 44, 284, "Charge moyenne par poste", 17, C.MUTED, 500, 233)
	D.rect(tile, Rect2(296, 270, 16, 16), PALE_GOLD, 2)
	D.text(tile, 322, 284, "Vigilance dès 55", 17, C.MUTED, 500, 149)

func _vigilance() -> void:
	var tile := D.panel(self, Rect2(1760, 318, 488, 178), "", "", "", "TrainingRisk")
	_icon(tile, "warning", Rect2(18, 13, 25, 25), PALE_GOLD)
	D.text(tile, 54, 35, "RISQUE DE FATIGUE  (%d)" % watched.size(), 25, C.IVORY, 700, 410)
	D.line(tile, Vector2(17, 47), Vector2(469, 47))
	if watched.is_empty():
		D.text(tile, 22, 92, "Aucune alerte physique", 24, GREEN, 600, 420)
		D.text(tile, 22, 127, "Charge ≥ 55 ou condition < 70 %", 20, C.MUTED, 500, 420)
		return
	for i in mini(3, watched.size()):
		var p: Dictionary = watched[i]
		var y := 51 + i * 40
		var button := _action(tile, Rect2(12, y, 464, 38), "", func(): _player_dialog(p), false, "", "TrainingRisk_" + str(i))
		button.accessibility_name = str(p.name)
		button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_icon(button, "people", Rect2(13, 9, 23, 23), C.IVORY)
		D.text(button, 53, 27, str(p.name), 22, C.IVORY, 700, 231)
		D.text(button, 298, 26, str(p.pos), 18, C.MUTED, 500, 93)
		D.text(button, 452, 28, G.n(p.get("physicalLoad", 0)) + " / 100", 21, PALE_GOLD, 700, 67, HORIZONTAL_ALIGNMENT_RIGHT)

func _axes(tile: Panel) -> void:
	var people: Array = app.model.get("decisions", {}).get("development", {}).get("professionals", [])
	var prioritized := people.filter(func(p: Dictionary): return p.get("development", {}).get("focus", "equilibre") != "equilibre")
	var examples := prioritized + people.filter(func(p: Dictionary): return p not in prioritized)
	if examples.is_empty(): D.text(tile, 22, 105, "Aucun suivi individuel disponible", 23, C.MUTED, 500, 510)
	for i in mini(3, examples.size()):
		var p: Dictionary = examples[i]
		var y := 68 + i * 87
		var hit := _action(tile, Rect2(14, y, 532, 81), "", func(): _player_dialog(P.player(app.model, str(p.id))), false, "", "TrainingAxis" + str(i))
		hit.accessibility_name = str(p.name) + " · axe individuel"
		hit.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_portrait(hit, p, Rect2(3, 3, 81, 73))
		D.text(hit, 108, 34, str(p.name), 28, C.IVORY, 700, 390)
		D.text(hit, 108, 65, _focus_name(p.get("development", {})), 23, C.MUTED, 500, 340)
		_icon(hit, "check" if p.get("development", {}).get("available", false) else "clock", Rect2(485, 25, 28, 28), GREEN if p.get("development", {}).get("available", false) else PALE_GOLD)
		D.line(hit, Vector2(1, 82), Vector2(530, 82), Color(C.LINE, .65))

func _staff_cards(tile: Panel) -> void:
	var labels := [["Préparateur", "Charge collective"], ["Adjoint", "Sélection des 23"], ["Cellule médicale", "Disponibilité du groupe"]]
	var width := tile.size.x / C.density
	for i in 3:
		var person: Dictionary = staff[i] if i < staff.size() else {}
		var y := 68 + i * 87
		if person.is_empty():
			D.photo(tile, ["training-coach", "mail-trainer", "mail-medical"][i], Rect2(17, y + 2, 82, 73))
		else: _portrait(tile, person, Rect2(17, y + 2, 82, 73), "training-coach")
		D.text(tile, 125, y + 33, person.get("name", labels[i][0]), 28, C.IVORY, 700, width - 306 if i < 2 else width - 141)
		D.text(tile, 125, y + 65, person.get("role", labels[i][1]), 22, C.MUTED, 500, width - 141)
		if i < 2:
			var key := "training" if i == 0 else "lineup"
			var delegated: bool = app.model.get("decisions", {}).get("delegation", {}).get(key, false)
			D.chip(tile, Rect2(width - 177, y + 7, 155, 36), "Délégué" if delegated else "À votre main", GREEN if delegated else C.IVORY)
		D.line(tile, Vector2(17, y + 82), Vector2(width - 20, y + 82), Color(C.LINE, .65))

func _groups() -> void:
	var section := D.panel(self, Rect2(4, 260, 1740, 950), "Plans de travail", "people", "", "TrainingGroupPlans")
	var data: Dictionary = support.get("training", {})
	D.text(section, 25, 97, "Appliquer un plan répartit les charges individuelles. Vous lancez ensuite la séance collective.", 27, C.IVORY, 500, 1630)
	if data.get("plans", []).is_empty(): D.text(section, 25, 154, "Aucun plan proposé pour cette carrière.", 23, C.MUTED, 500, 1620)
	var plans: Array = data.get("plans", [])
	for i in plans.size():
		var plan: Dictionary = plans[i]
		var tile := D.panel(section, Rect2(23, 129 + i * 204, 1692, 183), str(plan.label), "train")
		D.text(tile, 25, 96, plan.get("detail", ""), 26, C.IVORY, 500, 1598)
		var counts: Dictionary = plan.get("counts", {})
		D.text(tile, 25, 141, "%s récupération  ·  %s normal ou collectif  ·  %s intensif" % [G.n(counts.get("repos", 0)), G.n(int(counts.get("normal", 0)) + int(counts.get("collective", 0))), G.n(counts.get("intense", 0))], 24, GREEN, 600, 1090)
		var apply := _action(tile, Rect2(1230, 110, 438, 50), "Appliquer le plan", func(): app._command("training_plan", {"context":support.context, "plan":plan.key}), true, "arrow", "SupportTraining_" + str(plan.key))
		apply.disabled = not data.get("available", false)
	D.photo(section, "training-session", Rect2(24, 747, 1689, 178))
	_chart()
	_vigilance()

func _individuals() -> void:
	var tile := D.panel(self, Rect2(4, 260, 1740, 950), "Le travail individuel", "train", "", "TrainingIndividuals")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tile.add_child(scroll)
	D.place(scroll, Rect2(17, 103, 1704, 821))
	var list := C.v(3)
	C.fill(list)
	scroll.add_child(list)
	for column in [["JOUEUR", 66], ["POSTE", 457], ["CONDITION", 815], ["CHARGE", 1010], ["PLAN INDIVIDUEL", 1192]]:
		D.text(tile, column[1], 87, column[0], 21, C.MUTED, 700, 280)
	for p: Dictionary in squad:
		var row := C.button("", func(): _player_dialog(p))
		row.name = "TrainingIndividual_" + str(p.id).replace(":", "_")
		row.accessibility_name = str(p.name) + " · plan individuel"
		row.set_meta("player_id", p.id)
		row.custom_minimum_size.y = C.px(55)
		list.add_child(row)
		_portrait(row, p, Rect2(7, 4, 44, 46))
		D.text(row, 63, 37, str(p.name), 26, C.IVORY, 700, 366)
		D.text(row, 442, 37, str(p.pos), 24, C.MUTED, 500, 330)
		D.text(row, 802, 37, G.n(p.get("condition", 0)) + " %", 24, GREEN, 600, 160)
		D.text(row, 993, 37, G.n(p.get("physicalLoad", 0)) + " / 100", 24, PALE_GOLD if p in watched else C.IVORY, 600, 150)
		D.text(row, 1174, 37, INDIVIDUAL.get(p.get("loadPlan", ""), "—"), 24, C.IVORY, 500, 420)
	if squad.is_empty(): list.add_child(C.label("Aucun joueur dans l’effectif.", 24, C.MUTED))
	_chart()
	_vigilance()

func _staff_tab() -> void:
	var tile := D.panel(self, Rect2(4, 260, 1740, 525), "Préparer avec le staff", "people", "", "TrainingDelegation")
	var decisions: Dictionary = app.model.get("decisions", {})
	var delegated: Dictionary = decisions.get("delegation", {})
	var advice := D.words(str(training.get("advice", "")), 115, 3)
	for i in advice.size(): D.text(tile, 23, 105 + i * 30, advice[i], 25, C.IVORY, 500, 1673)
	for i in 2:
		var key: String = ["training", "lineup"][i]
		var enabled: bool = delegated.get(key, false)
		var action := _action(tile, Rect2(24, 208 + i * 83, 1688, 68), ("Reprendre · " if enabled else "Déléguer · ") + ["charge collective", "sélection des 23"][i], func(): app._command("set_delegation", {"key":key, "enabled":not enabled}), enabled, "people", "Delegate" + key.capitalize())
		action.disabled = locked or not decisions.has("delegation")
	_action(tile, Rect2(24, 382, 822, 58), "Réunions, briefing et suivi médical", func(): app._navigate("Travail du club"), false, "arrow", "TrainingOpenSupport")
	_action(tile, Rect2(864, 382, 848, 58), "Ouvrir l’annuaire du staff", func(): app._navigate("Staff"), false, "arrow", "TrainingOpenStaff")
	D.photo(self, "training-session", Rect2(4, 805, 1740, 381))
	_staff_cards(D.panel(self, Rect2(1760, 260, 488, 341), "Encadrement", "people", "", "TrainingStaffCompact"))

func _open_tab(index: int) -> void:
	state.tab = index
	var owner := app
	owner._render()
	ClubUI.focus(owner, "TrainingTab" + str(index))

func _open_slot(index: int) -> void:
	match index:
		0: _mode_dialog(false)
		1: _choices_dialog(false)
		2, 3: _open_tab(1)
		4, 5, 6: _open_tab(2)
		7: app._navigate("Travail du club")
		8: app._navigate("Plan de jeu")
		9: _choices_dialog(true)
		10: app._navigate("Composition")
		11: app._navigate("Match")
		12, 13: _open_tab(3)

func _validate() -> void:
	if locked or trained: return
	_mode_dialog(true)

func _mode_dialog(validate: bool) -> void:
	var window := _dialog("TrainingSessionDialog", "Valider la semaine" if validate else "Modifier la séance")
	var body: VBoxContainer = window[1]
	var dialog: AcceptDialog = window[0]
	body.add_child(C.wrap("Le moteur applique une séance collective par semaine. Ajustez d’abord la préparation spécifique et les charges individuelles.", 22, C.IVORY, true))
	if trained or locked:
		body.add_child(C.wrap("Séance effectuée cette semaine." if trained else "Séance indisponible pendant le match ou après la saison.", 22, C.MUTED, true))
	else:
		for id: String in MODES:
			var button := C.button(str(MODES[id]), func():
				dialog.hide()
				dialog.queue_free()
				if validate: app._command("train", {"mode":id})
				else:
					state.mode = id
					app._render(), state.get("mode") == id, app.accent)
			button.name = "PreparationTrain_" + id if validate else "TrainingMode_" + id
			button.accessibility_name = ("Effectuer la séance · " if validate else "Sélectionner · ") + str(MODES[id])
			body.add_child(button)
		if validate: body.add_child(C.wrap("Choisir une charge ici effectue la séance et enregistre ses effets.", 19, C.MUTED, true))
	_popup(dialog, 760, 320)

func _choices_dialog(opponent: bool) -> void:
	var decisions: Dictionary = app.model.get("decisions", {})
	var data: Dictionary = decisions.get("difficulty", {}) if opponent else training.get("collective", {})
	var window := _dialog("TrainingChoices", "Comportement des entraîneurs adverses" if opponent else "Préparation spécifique")
	var body: VBoxContainer = window[1]
	var dialog: AcceptDialog = window[0]
	for entry: Dictionary in data.get("options", []):
		var button := C.button(str(entry.label), func():
			dialog.hide()
			dialog.queue_free()
			if opponent: app._command("set_opponent_level", {"level":entry.id})
			else: app._command("set_collective_focus", {"focus":entry.id}), data.get("selected") == entry.id, app.accent)
		button.name = ("OpponentLevel_" if opponent else "CollectiveFocus_") + str(entry.id)
		button.disabled = not data.get("available", false)
		body.add_child(button)
		var description := str(entry.get("description", ""))
		if not opponent: description += " · %s · %s" % [entry.get("cost", ""), entry.get("effect", "")]
		body.add_child(C.wrap(description, 20, C.MUTED, true))
	if data.get("options", []).is_empty(): body.add_child(C.wrap("Aucune option disponible.", 22, C.MUTED, true))
	_popup(dialog, 820, 610 if not opponent else 500)

func _player_dialog(p: Dictionary) -> void:
	if p.is_empty(): return
	var window := _dialog("TrainingIndividualDialog", str(p.name))
	var body: VBoxContainer = window[1]
	var dialog: AcceptDialog = window[0]
	body.add_child(C.wrap("%s · Condition %s %% · Charge %s / 100" % [p.pos, G.n(p.condition), G.n(p.get("physicalLoad", 0))], 25, C.IVORY, true))
	var choice := _choice(body, "Charge individuelle", INDIVIDUAL, p.get("loadPlan", "collective"))
	choice.name = "TrainingLoad_" + str(p.id).replace(":", "_")
	choice.disabled = locked or trained
	choice.item_selected.connect(func(index: int):
		dialog.hide()
		dialog.queue_free()
		app._command("set_player_load", {"playerId":p.id, "mode":choice.get_item_metadata(index)}))
	var people: Array = app.model.get("decisions", {}).get("development", {}).get("professionals", [])
	for person: Dictionary in people:
		if person.id != p.id: continue
		var development: Dictionary = person.get("development", {})
		var options := {}
		for option: Dictionary in development.get("options", []): options[option.id] = option.label
		if options.is_empty(): break
		var focus := _choice(body, "Axe de développement", options, development.get("focus"))
		focus.name = "Focus" + str(p.id).replace(":", "_")
		focus.disabled = not development.get("available", false)
		focus.item_selected.connect(func(index: int):
			dialog.hide()
			dialog.queue_free()
			app._command("set_development_focus", {"playerId":p.id, "focus":focus.get_item_metadata(index)}))
		body.add_child(C.wrap(str(development.get("reason", "")) if focus.disabled else "Changer la spécialisation remet à zéro son expérience partielle. Les qualités gagnées sont conservées.", 19, C.MUTED, true))
		break
	_popup(dialog, 760, 310)

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

func _choice(body: Node, caption: String, options: Dictionary, selected: Variant) -> OptionButton:
	body.add_child(C.label(caption, 22, C.MUTED))
	var control := OptionButton.new()
	control.custom_minimum_size.y = C.px(46)
	control.add_theme_font_override("font", C.DISPLAY)
	control.add_theme_font_size_override("font_size", C.px(23))
	for key: Variant in options:
		control.add_item(str(options[key]))
		control.set_item_metadata(control.item_count - 1, key)
		if key == selected: control.select(control.item_count - 1)
	body.add_child(control)
	return control

func _label(source: Dictionary, fallback: String) -> String:
	for option: Dictionary in source.get("options", []):
		if option.get("id") == source.get("selected"): return str(option.get("label", fallback))
	return fallback

func _focus_name(source: Dictionary) -> String:
	for option: Dictionary in source.get("options", []):
		if option.get("id") == source.get("focus"): return str(option.get("label", "Équilibré"))
	return "Équilibré"

func _icon(parent: Node, icon: String, rectangle: Rect2, color: Color) -> void:
	var graphic := C.icon(icon, int(rectangle.size.x), color)
	parent.add_child(graphic)
	D.place(graphic, rectangle)

func _portrait(parent: Node, p: Dictionary, rectangle: Rect2, fallback: String = "") -> void:
	if not str(p.get("portraitPath", "")).is_empty() and G._pack_texture(str(p.portraitPath)) != null:
		var portrait := G.portrait(int(p.get("portraitIndex", 0)), 0, p)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(portrait)
		D.place(portrait, rectangle)
	elif not fallback.is_empty():
		D.photo(parent, fallback, rectangle)
	else:
		var id := str(p.get("id", ""))
		var from_squad := P.player(app.model, id)
		var index := int(from_squad.get("portraitIndex", p.get("portraitIndex", id.hash())))
		D.photo(parent, "player-%02d" % posmod(index, 16), rectangle)

func _action(parent: Node, rectangle: Rect2, caption: String, callback: Callable, primary: bool, icon: String, id: String) -> Button:
	return D.button(parent, rectangle, caption, callback, primary, icon, false, Color("09673e"), id)
