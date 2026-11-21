extends Control
## Vue de la semaine. Les repères organisent les décisions d’une seule séance simulée.
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Fatigue = preload("res://ui/immersive08/fatigue_overview.gd")
const Plans = preload("res://ui/immersive08/training_group_plans.gd")
const Anneau = preload("res://ui/anneau_repartition.gd")
const Groupe = preload("res://ui/immersive08/training_group_panel.gd")
const Watch = preload("res://ui/management_state.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const TABS = ["Semaine", "Groupes", "Individuel", "Staff", "Fatigue"]
const MODES = {"repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}
const INDIVIDUAL = {"collective":"Suivre le collectif", "repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}
const TOPICS = ["COLLECTIF", "GROUPES", "INDIVIDUEL", "VIGILANCE", "CONSIGNES", "MATCH", "ENCADREMENT"]
const FAMILIES = [["PIL.", [0]], ["TAL.", [1]], ["2e L.", [2]], ["3e L.", [3]], ["CHAR.", [4, 5]], ["CEN.", [7]], ["3/4", [6, 8]]]
const GREEN = Color("b6d6b6")
const PALE_GOLD = Color("d7aa5a")
const SLOTS = [
	["train", "Séance collective", "Choisir la charge", "Une séance collective agit sur la récupération et le développement.", "Modifier la séance"],
	["flag", "Travail spécifique", "Préparation ciblée", "Choisis le travail spécifique avant d’effectuer la séance.", "Modifier le travail"],
	["people", "Plan des groupes", "Répartir les charges", "Le plan affecte des charges individuelles et conserve la séance disponible.", "Voir les plans"],
	["people", "Avants et arrières", "Condition et charge", "Compare les groupes de poste et les charges effectives de l’effectif.", "Voir les groupes"],
	["star", "Axes individuels", "Développement", "Les spécialisations disponibles dépendent du profil et de la semaine.", "Suivre les joueurs"],
	["train", "Charge individuelle", "Exceptions au collectif", "Ajuste les charges avant la séance. Les joueurs blessés récupèrent.", "Ajuster les charges"],
	["heart", "Récupération", "Vigilance physique", "L’effectif met en évidence la charge cumulée et la condition actuelle.", "Voir les joueurs"],
	["heart", "Suivi médical", "Disponibilité et reprise", "Les protocoles médicaux seront appliqués à la séance suivante.", "Ouvrir le suivi"],
	["tactic", "Plan de jeu", "Consignes collectives", "Ouvre tes choix de jeu et les consignes de préparation du match.", "Ouvrir le plan de jeu"],
	["shield", "Niveau adverse", "Entraîneurs adverses", "Le niveau détermine les exigences des entraîneurs adverses.", "Ajuster le niveau"],
	["people", "Feuille de match", "XV et banc", "Contrôle la qualification et la disponibilité des joueurs de la feuille.", "Ouvrir la composition"],
	["ball", "Jour de match", "Prochaine rencontre", "Retrouve les informations de la prochaine rencontre.", "Aller au jour de match"],
	["info", "Conseil du staff", "État du groupe", "Consulte le diagnostic actuel et les responsabilités de l’encadrement.", "Voir les conseils"],
	["people", "Délégation", "Charge et sélection", "Confie la sélection ou la charge collective au staff.", "Voir la délégation"],
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
	watched = squad.filter(func(p: Dictionary):
		return not Watch.watch_reason(p).is_empty())
	watched.sort_custom(func(a: Dictionary, b: Dictionary): return _risk(a) > _risk(b))
	staff = _staff_members()
	trained = meta.get("trained", false)
	locked = not app._live().is_empty() or meta.get("phase") == "ended"
	if not app.management_ui.get("immersive_training") is Dictionary:
		app.management_ui.immersive_training = {}
	state = app.management_ui.immersive_training
	var week_key := str([app.model.get("club", {}).get("id"), meta.get("season"), meta.get("week")])
	var training_mode := str(meta.get("training", "normal"))
	if state.get("week") != week_key or state.get("stored_mode") != training_mode or trained:
		state.week = week_key
		state.stored_mode = training_mode
		state.erase("mode")
	active_tab = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	app.heading = D.text(self, 27, 103, "PLAN D’ENTRAÎNEMENT", 72, C.IVORY, 800, 780)
	app.heading.add_theme_font_override("font", C.Charte.TITRE_FICHE)
	var opponent: Dictionary = P.next_fixture(app.model)
	var fixture := "Aucune rencontre annoncée"
	if not opponent.is_empty():
		var home: Dictionary = opponent.get("home", {})
		var is_home: bool = home.get("id") == app.model.get("club", {}).get("id")
		var location := "Terrain neutre" if opponent.get("neutral", false) else ("Réception" if is_home else "Déplacement")
		fixture = location + " · " + G.club_name(opponent.get("away", {}) if is_home else home)
	D.text(self, 30, 142, "Semaine %s  ·  %s" % [G.n(int(meta.get("week", 0)) + 1), fixture], 27, C.IVORY, 500, 785)
	_metrics(meta)
	for i in TABS.size():
		var tab := ClubUI.tab(self, Rect2(4 + i * 199, 169, 188, 58), TABS[i], i == active_tab, func(): _open_tab(i), "TrainingTab" + str(i))
		tab.add_theme_font_size_override("font_size", C.font_px(30))
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
	var validate := _action(self, Rect2(1316, 166, 424, 58), "Séance effectuée" if trained else "Effectuer la séance", _validate, false, "arrow", "TrainingValidateWeek")
	validate.tooltip_text = "Séance déjà effectuée cette semaine." if trained else "Séance indisponible pendant le match ou après la saison." if locked else "Une séance collective par semaine. Tu pourras choisir sa charge."
	validate.disabled = trained or locked
	validate.add_theme_font_size_override("font_size", C.font_px(33))
	D.line(self, Vector2(2, 234), Vector2(1741, 234))
	match active_tab:
		0: _week(opponent)
		1: _groups()
		2: _individuals()
		3: _staff_tab()
		4: Fatigue.build(app, self, state)

func _risk(p: Dictionary) -> float:
	return maxf(float(p.get("physicalLoad", 0)), 100.0 - float(p.get("condition", 100)))

func _mode() -> String:
	return str(MODES.get(state.get("mode", state.get("stored_mode")), MODES.normal))

func _staff_members() -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("id") != app.model.get("club", {}).get("id"): continue
		var members: Array = team.get("members", [])
		return members.filter(func(p: Dictionary):
			var role := str(p.get("role", "")).to_lower()
			return role.contains("prépar") or role.contains("entraîn") or role.contains("coach"))
	return []

## Tuiles du haut : le moral mène au Vestiaire, les autres à l'onglet Fatigue.
func _open_metric(index: int) -> void:
	if index == 1: app._navigate("Vestiaire")
	else: _open_tab(4)

func _metrics(meta: Dictionary) -> void:
	var group := P.group(app.model)
	var total_load := 0.0
	for p: Dictionary in squad: total_load += float(p.get("physicalLoad", 0))
	var metrics := D.panel(self, Rect2(815, 24, 928, 106), "", "", "", "TrainingMetrics")
	var values := [
		["heart", "Condition", G.n(group.condition) + " %", GREEN],
		["people", "Moral", G.n(meta.get("morale", "—")), C.IVORY],
		["train", "Charge moyenne", "%d / 100" % roundi(total_load / maxi(1, squad.size())), C.IVORY],
		["warning", "À surveiller", str(watched.size()), C.ALERT if not watched.is_empty() else C.MUTED],
	]
	for i in values.size():
		var value: Array = values[i]
		var x := i * 232
		if i > 0: D.line(metrics, Vector2(x, 8), Vector2(x, 98), Color(C.LINE, .8))
		if i == 3 and not watched.is_empty(): D.rect(metrics, Rect2(x+1, 1, 230, 104), C.SELECTED, 8)
		_icon(metrics, value[0], Rect2(x + 20, 36, 48, 48), value[3])
		D.text(metrics, x + 81, 40, value[1], 24, C.IVORY, 500, 144)
		D.text(metrics, x + 81, 85, value[2], 38, value[3], 700, 144)
		var destination: String = ["Condition de l'effectif : ouvrir la fatigue", "Moral : ouvrir le vestiaire", "Charge moyenne : ouvrir la fatigue", "Joueurs à surveiller : ouvrir la fatigue"][i]
		var zone := _zone(metrics, Rect2(x + 4, 4, 224, 98), "TrainingMetric" + str(i), destination, func(): _open_metric(i))
		# Mini-courbe au survol de la condition et du moral (relevé hebdomadaire du moteur).
		if i < 2: preload("res://ui/mini_courbe_survol.gd").lier(app, zone, ["condition", "morale"][i], ["Condition du groupe", "Moral du vestiaire"][i])

func _week(fixture: Dictionary) -> void:
	var focus: Dictionary = training.get("collective", {})
	var focus_label := _label(focus, "Sans préparation spécifique")
	var state_caption := "Séance effectuée" if trained else "Séance indisponible" if locked else ""
	var plans: Array = support.get("training", {}).get("plans", [])
	var captions := [
		state_caption, focus_label, P.plural(plans.size(), "plan", "plans") if not plans.is_empty() else "", "%d joueurs" % squad.size(),
		"%d ciblés" % _axis_people()[1], "%d exceptions" % _load_exceptions().size(), "%d à suivre" % watched.size(),
		"%d suivis" % support.get("medical", {}).get("players", []).size(), "",
		"",
		"Feuille valide" if app.model.get("selection", {}).get("valid", false) else "Feuille à compléter",
		str(fixture.get("label", "Aucune rencontre")), "", "",
	]
	var selected := clampi(int(state.get("slot", 0)), 0, SLOTS.size() - 1)
	_programme()
	for i in TOPICS.size():
		var column := D.panel(self, Rect2(4 + i * 250, 270, 239, 545), "", "", "", "TrainingWeekColumn" + str(i))
		var match_column := i == 5 and not fixture.is_empty()
		var tone := PALE_GOLD if match_column else C.MINT if i == 0 else C.MUTED
		D.rect(column, Rect2(1, 1, 237, 82), C.SELECTED if match_column or i == 0 else C.RAISED, 8)
		D.text(column, 119, 51, TOPICS[i], 29, tone, 700, 224, HORIZONTAL_ALIGNMENT_CENTER)
		for band in 2:
			var index := i * 2 + band
			var slot: Array = SLOTS[index]
			var y := 99 + band * 220
			D.rect(column, Rect2(11, y, 217, 31), C.SELECTED, 5)
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
			_card_visual(hit, index, fixture)
		if i == 0: D.line(column, Vector2(13, 310), Vector2(226, 310))
	_chart()
	_vigilance()
	week_panel = D.panel(self, Rect2(1760, 509, 488, 306), "Séance sélectionnée", "train", "", "TrainingSelectedSession")
	_selection(selected)
	var art := D.panel(self, Rect2(4, 840, 1020, 377), "", "", "", "TrainingPhoto")
	art.clip_contents = true
	D.photo(art, photo_centre(app.model), Rect2(2, 2, 1016, 373))
	_axes(D.panel(self, Rect2(1039, 840, 560, 341), "Axes individuels", "star", "", "TrainingAxes"))
	_staff_cards(D.panel(self, Rect2(1614, 840, 634, 341), "Encadrement", "people", "", "TrainingStaff"))

## Programme de la semaine jour par jour (moteur : clubLife.weekProgram) : sept cases du lundi au dimanche, couleur et
## icône par jour (séance à sa charge, veille, match, récupération, repos), aujourd'hui cerclé, jour passé estompé.
## Clic : la carte de la semaine correspondante (séance, jour de match, récupération).
func _programme() -> void:
	var Panneaux = load("res://ui/immersive08/panneaux_effectif.gd")
	var jours: Array = Panneaux._jours_programme(app)
	if jours.is_empty(): return
	for i in jours.size():
		var j: Dictionary = jours[i]
		var kind := str(j.get("kind", "repos"))
		var r := Rect2(6 + i * 104, 239, 96, 28)
		var case_ := D.rect(self, r, Panneaux._couleur_jour(j), 14, C.IVORY if bool(j.get("today", false)) else Color.TRANSPARENT)
		case_.name = "TrainingDay_%d" % i
		if bool(j.get("past", false)): case_.modulate = Color(1, 1, 1, .55)
		var encre: Color = C.Charte.NUIT if kind != "repos" else C.IVORY
		D.text(case_, 14, 21, str(j.get("lettre", "")), 18, encre, 800, 20)
		var icone: String = Panneaux.JOURS.get(kind, ["", ""])[0]
		if bool(j.get("done", false)) or (kind == "match" and bool(j.get("played", false))): icone = "check"
		if not icone.is_empty(): _icon(case_, icone, Rect2(56, 4, 20, 20), encre)
		var aide := "%s · %s" % [str(j.get("date", "")), Panneaux.JOURS.get(kind, ["", kind])[1]]
		if kind == "seance": aide += " · " + str(Panneaux.CHARGES.get(str(j.get("charge", "normal")), ""))
		var cible: int = {"seance": 0, "match": 11, "veille": 11, "recuperation": 6}.get(kind, -1)
		if cible >= 0: _zone(self, C.reach_rect(r), "TrainingDayOpen_%d" % i, aide, func(): _select(cible))
		else: case_.tooltip_text = aide

## Bande visuelle du bas de chaque carte de la semaine (y 120-160 de la carte) : uniquement des données du moteur,
## en cases, portraits et blasons ; chaque pièce qui a une destination est cliquable (écran, onglet ou petite fenêtre).
func _card_visual(hit: Button, index: int, fixture: Dictionary) -> void:
	var y := 120.0
	match index:
		0:
			var mode := str(state.get("mode", state.get("stored_mode", "normal")))
			var free := not (trained or locked)
			var cells := [["repos", "Repos", C.Charte.REPOS], ["normal", "Normal", C.Charte.NORMAL], ["intense", "Intensif", C.Charte.INTENSIF]]
			for k in cells.size():
				var id: String = cells[k][0]
				var pick := func():
					state.mode = id
					app._render()
				_notch(hit, k, cells.size(), y, cells[k][1], cells[k][2], id == mode, "TrainingWeekMode_" + id, pick if free else Callable(), "heart" if id == "repos" else "train")
		1:
			var collective: Dictionary = training.get("collective", {})
			var options: Array = collective.get("options", [])
			var available: bool = collective.get("available", false)
			var chosen: Variant = collective.get("selected")
			var step := minf(38.0, 191.0 / maxi(1, options.size()))
			for k in options.size():
				var option: Dictionary = options[k]
				var active: bool = option.get("id") == chosen
				var rect := Rect2(13 + k * step, y + 4, step - 6, 32)
				var dot := D.rect(hit, rect, C.Charte.PANNEAU_2.lerp(C.MINT, .45) if active else C.Charte.PANNEAU_3, 6, C.MINT if active else Color.TRANSPARENT)
				dot.name = "TrainingWeekFocus_" + str(option.get("id", k))
				if active: _icon(dot, "check", Rect2((rect.size.x - 20) / 2.0, 6, 20, 20), C.IVORY)
				var tip := "%s · %s · %s" % [option.get("label", ""), option.get("cost", ""), option.get("effect", "")]
				var option_id: Variant = option.get("id")
				var choose := func(): app._command("set_collective_focus", {"focus":option_id})
				var open := func(): _choices_dialog(false)
				if not C.dense(): _zone(hit, C.reach_rect(rect), "TrainingWeekFocusLink_" + str(option.get("id", k)), tip, choose if available and not active else open)
			# Petite fenêtre : points trop étroits pour un clic chacun, la rangée entière ouvre le choix.
			if C.dense() and not options.is_empty(): _zone(hit, C.reach_rect(Rect2(9, y, 199, 40)), "TrainingWeekFocusRow", _label(collective, "Préparation spécifique"), func(): _choices_dialog(false))
		2:
			var plans: Array = support.get("training", {}).get("plans", [])
			var tips := PackedStringArray()
			for k in mini(3, plans.size()):
				var plan: Dictionary = plans[k]
				var counts: Dictionary = plan.get("effectiveCounts", plan.get("counts", {}))
				var parts := [[int(counts.get("repos", 0)), C.Charte.REPOS], [int(counts.get("normal", 0)), C.Charte.NORMAL], [int(counts.get("intense", 0)), C.Charte.INTENSIF]]
				var total := 0
				for part: Array in parts: total += int(part[0])
				var row_y := y - 4 + k * 15
				var x := 13.0
				for part: Array in parts:
					if int(part[0]) <= 0 or total <= 0: continue
					var w := 191.0 * float(part[0]) / total
					D.rect(hit, Rect2(x, row_y, maxf(2.0, w - 2), 12), part[1], 3)
					x += w
				tips.append("%s · %d repos · %d normal · %d intensif" % [plan.get("label", ""), parts[0][0], parts[1][0], parts[2][0]])
			if not plans.is_empty(): _zone(hit, C.reach_rect(Rect2(9, y - 7, 199, 46)), "TrainingWeekPlans", " / ".join(tips), func(): _open_tab(1))
		3:
			var forwards := squad.filter(func(p: Dictionary): return int(p.get("fam", -1)) in [0, 1, 2, 3])
			var backs := squad.filter(func(p: Dictionary): return int(p.get("fam", -1)) >= 4)
			for k in 2:
				var players: Array = [forwards, backs][k]
				var value := 0.0
				for p: Dictionary in players: value += float(p.get("condition", 0))
				value /= maxi(1, players.size())
				var x := 13.0 + k * 103
				D.text(hit, x, y + 16, ["AV", "AR"][k], 16, C.IVORY, 700, 30)
				D.text(hit, x + 88, y + 17, "%d %%" % roundi(value), 18, C.Charte.GAIN, 700, 60, HORIZONTAL_ALIGNMENT_RIGHT)
				D.rect(hit, Rect2(x, y + 25, 88, 12), C.Charte.PANNEAU_3, 4)
				D.rect(hit, Rect2(x, y + 25, 88 * clampf(value, 0, 100) / 100.0, 12), C.Charte.GAIN, 4)
				var title: String = ["Avants", "Arrières"][k]
				if not players.is_empty():
					_zone(hit, C.reach_rect(Rect2(x - 3, y - 2, 94, 44)), "TrainingWeekLine" + str(k), "%s · condition %d %% · %s" % [title, roundi(value), P.plural(players.size(), "joueur", "joueurs")], func(): Groupe.ouvrir(self, title, C.Charte.GAIN, players))
		4:
			var people: Array = (_axis_people()[0] as Array).map(func(p: Dictionary): return P.player(app.model, str(p.get("id", ""))))
			_portraits(hit, people.filter(func(p: Dictionary): return not p.is_empty()), y, "TrainingWeekAxis", "Axes individuels", C.MINT)
		5:
			var exceptions := _load_exceptions()
			var cells := [["repos", "repos", C.Charte.REPOS], ["normal", "normal", C.Charte.NORMAL], ["intense", "intensif", C.Charte.INTENSIF]]
			for k in cells.size():
				var mode: String = cells[k][0]
				var players := exceptions.filter(func(p: Dictionary): return str(p.get("loadPlan", "")) == mode)
				var title := "Charge individuelle · " + str(cells[k][1])
				var colour: Color = cells[k][2]
				var show := func(): Groupe.ouvrir(self, title, colour, players)
				_cell(hit, Rect2(13 + k * 65, y, 61, 40), cells[k][1], str(players.size()), colour, not players.is_empty(), "TrainingWeekLoad_" + mode, show if not players.is_empty() else Callable())
		6:
			_portraits(hit, watched, y, "TrainingWeekWatch", "À surveiller", C.Charte.INTENSIF)
		7:
			var records: Array = support.get("medical", {}).get("players", [])
			var people: Array = []
			var weeks: Array = []
			for record: Dictionary in records:
				var person := P.player(app.model, str(record.get("id", "")))
				if person.is_empty(): continue
				people.append(person)
				weeks.append(int(record.get("injury", 0)))
			_portraits(hit, people, y, "TrainingWeekMedical", "Suivi médical", C.Charte.PERTE)
			for k in mini(3, people.size()):
				if int(weeks[k]) <= 0: continue
				var badge := D.rect(hit, Rect2(13 + k * 46 + 24, y - 6, 22, 22), C.Charte.PERTE, 11)
				badge.name = "TrainingWeekMedicalWeeks" + str(k)
				badge.tooltip_text = P.plural(int(weeks[k]), "semaine d’indisponibilité", "semaines d’indisponibilité")
				D.text(badge, 11, 17, str(weeks[k]), 15, C.Charte.ENCRE, 800, 22, HORIZONTAL_ALIGNMENT_CENTER)
		9:
			var difficulty: Dictionary = app.model.get("decisions", {}).get("difficulty", {})
			var options: Array = difficulty.get("options", [])
			for k in options.size():
				var option: Dictionary = options[k]
				var level: Variant = option.get("id")
				var active: bool = level == difficulty.get("selected")
				var choose := func(): app._command("set_opponent_level", {"level":level})
				var open := func(): _choices_dialog(true)
				_notch(hit, k, options.size(), y, str(option.get("label", "")), C.MINT, active, "TrainingWeekLevel_" + str(level), choose if difficulty.get("available", false) and not active else open, "shield")
		10:
			var starters := 0
			var bench := 0
			for slot: Dictionary in app.model.get("selection", {}).get("slots", []):
				if str(slot.get("playerId", "")).is_empty(): continue
				if int(slot.get("slot", -1)) < 15: starters += 1
				else: bench += 1
			var condition := P.lineup_condition(app.model).split(" ")[0]
			var cells := [["XV", str(starters), C.IVORY], ["banc", str(bench), C.IVORY], ["cond. %", condition, C.Charte.GAIN]]
			for k in cells.size():
				_cell(hit, Rect2(13 + k * 65, y, 61, 40), cells[k][0], cells[k][1], cells[k][2], true, "TrainingWeekSheet" + str(k), func(): app._navigate("Composition"))
		11:
			if fixture.is_empty(): return
			for k in 2:
				var club: Dictionary = fixture.get(["home", "away"][k], {})
				var crest := G.crest(club, C.px(40))
				crest.name = "TrainingWeekCrest" + str(k)
				hit.add_child(crest)
				D.place(crest, Rect2(13 + k * 74, y - 2, 40, 40))
			D.text(hit, 70, y + 26, "–", 22, C.IVORY, 700, 24, HORIZONTAL_ALIGNMENT_CENTER)
			var date := str(fixture.get("date", "")).split("-")
			if date.size() == 3: D.text(hit, 204, y + 26, "%s/%s" % [date[2], date[1]], 19, PALE_GOLD, 700, 70, HORIZONTAL_ALIGNMENT_RIGHT)
			_zone(hit, C.reach_rect(Rect2(9, y - 4, 199, 44)), "TrainingWeekFixture", P.next_fixture_caption(app.model, "Prochaine rencontre"), func(): app._navigate("Match"))
		12:
			var advice: Dictionary = training.get("adviceState", {})
			var kind := str(advice.get("kind", ""))
			if kind.is_empty(): return
			var count := int(advice.get("count", 0))
			var look: Array = [C.Charte.GAIN, "check", "Prêt"] if kind == "pret" else [C.Charte.INTENSIF, "warning", "%d chargés" % count] if kind == "charge" else [C.Charte.PERTE, "heart", "XV fatigué"]
			var width := Pieces.pastille(hit, 13, y + 3, look[2], look[1], "TrainingWeekAdvice", "", look[0])
			_zone(hit, C.reach_rect(Rect2(11, y + 1, maxf(width + 4, 64.0), 38)), "TrainingWeekAdviceLink", look[2], func(): _open_tab(3))
		13:
			var delegation: Dictionary = app.model.get("decisions", {}).get("delegation", {})
			var keys := [["training", "Charge"], ["lineup", "Les 23"]]
			for k in keys.size():
				var delegated: bool = delegation.get(keys[k][0], false)
				_cell(hit, Rect2(13 + k * 97, y, 93, 40), keys[k][1], "", C.Charte.GAIN if delegated else C.IVORY, delegated, "TrainingWeekDelegation_" + str(keys[k][0]), func(): _open_tab(3), "check" if delegated else "people")

## Cran d'une jauge à crans (charge collective, niveau adverse) : un segment par choix, le retenu plein et nommé dessous.
func _notch(hit: Control, k: int, count: int, y: float, word: String, colour: Color, active: bool, id: String, action: Callable, icon: String) -> void:
	var step := 195.0 / maxi(1, count)
	var rect := Rect2(13 + k * step, y - 12, step - 4, 14)
	var segment := D.rect(hit, rect, colour if active else C.Charte.PANNEAU_3.lerp(colour, .25), 4)
	segment.name = id
	if active:
		_icon(hit, icon, Rect2(13, y + 11, 22, 22), colour)
		var label := D.text(hit, 42, y + 30, word, Groupe._taille(word, 21, 700, 160), colour, 700, 162)
		label.name = id + "Word"
	if action.is_valid(): _zone(hit, C.reach_rect(Rect2(rect.position.x - 1, y - 16, rect.size.x + 2, 22)), id + "Link", word, action)

## Case de la bande : un mot (et un chiffre au-dessus s'il y en a un), teintée quand elle est retenue.
func _cell(parent: Control, rect: Rect2, word: String, value: String, colour: Color, active: bool, id: String, action: Callable, icon: String = "") -> Panel:
	var cell := D.rect(parent, rect, C.Charte.PANNEAU_2.lerp(colour, .30) if active else C.Charte.PANNEAU_3, 6, colour if active and value.is_empty() else Color.TRANSPARENT)
	cell.name = id
	var tone := colour if active else C.MUTED
	var left := 0.0
	if not icon.is_empty():
		_icon(cell, icon, Rect2(8, (rect.size.y - 20) / 2.0, 20, 20), tone)
		left = 24.0
	if value.is_empty():
		D.text(cell, left + (rect.size.x - left) / 2.0, rect.size.y / 2.0 + 7, word, Groupe._taille(word, 17, 700, rect.size.x - left - 6), tone, 700, rect.size.x - left - 4, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		D.text(cell, rect.size.x / 2.0, 21, value, 22, tone, 800, rect.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER)
		if Groupe._taille(word, 14, 600, rect.size.x - 4) >= 14:
			D.text(cell, rect.size.x / 2.0, 36, word, 14, C.Charte.IVOIRE_2, 600, rect.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER)
		else: cell.tooltip_text = word
	for label in cell.find_children("*", "Control", true, false): (label as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action.is_valid(): _zone(parent, C.reach_rect(rect), id + "Link", (value + " " + word).strip_edges(), action)
	return cell

## Rangée de trois portraits au plus, puis « +N » qui ouvre tout le groupe en petite fenêtre.
func _portraits(hit: Control, people: Array, y: float, id: String, title: String, colour: Color) -> void:
	for k in mini(3, people.size()):
		var p: Dictionary = people[k]
		_portrait(hit, p, Rect2(13 + k * 46, y - 2, 40, 42))
		var condition := clampf(float(p.get("condition", 0)), 0.0, 100.0)
		D.rect(hit, Rect2(13 + k * 46, y + 42, 40 * condition / 100.0, 4), C.Charte.couleur_attribut(condition), 2)
		if not C.dense(): _zone(hit, C.reach_rect(Rect2(11 + k * 46, y - 4, 44, 50)), id + str(k), "%s · %s · condition %d %%" % [p.get("name", ""), p.get("pos", ""), roundi(condition)], func(): _player_dialog(p))
	# Petite fenêtre : portraits trop étroits pour un clic chacun, la rangée ouvre tout le groupe.
	if C.dense() and not people.is_empty(): _zone(hit, C.reach_rect(Rect2(9, y - 4, 145 if people.size() > 3 else 199, 52)), id + "Row", "%s · %s" % [title, P.plural(people.size(), "joueur", "joueurs")], func(): Groupe.ouvrir(self, title, colour, people))
	if people.size() > 3:
		var more := D.rect(hit, Rect2(151, y + 4, 53, 32), C.Charte.PANNEAU_3.lerp(colour, .18), 16)
		more.name = id + "More"
		D.text(more, 26, 23, "+%d" % (people.size() - 3), 18, colour, 800, 50, HORIZONTAL_ALIGNMENT_CENTER)
		_zone(hit, C.reach_rect(Rect2(149, y + 2, 57, 36)), id + "MoreLink", "%s · %s" % [title, P.plural(people.size(), "joueur", "joueurs")], func(): Groupe.ouvrir(self, title, colour, people))

## Joueurs suivis pour un axe individuel (ciblés d'abord) et nombre de ciblés.
func _axis_people() -> Array:
	var people: Array = app.model.get("decisions", {}).get("development", {}).get("professionals", [])
	var prioritized := people.filter(func(p: Dictionary): return p.get("development", {}).get("focus", "equilibre") != "equilibre")
	return [prioritized + people.filter(func(p: Dictionary): return p not in prioritized), prioritized.size()]

## Joueurs dont la charge individuelle s'écarte du collectif.
func _load_exceptions() -> Array:
	return squad.filter(func(p: Dictionary): return str(p.get("loadPlan", "collective")) in ["repos", "normal", "intense"])

func _slot_style(hit: Button, selected: bool, match_slot: bool) -> void:
	var fill := Color("20382d") if selected else Color("32291d") if match_slot else Color("10191a")
	var border := C.MINT if selected else PALE_GOLD if match_slot else Color("3d4946")
	for state in ["normal", "hover", "pressed"]:
		var style := C.box(fill.lightened(.06) if state == "hover" else fill, border, 6, 0)
		style.set_border_width_all(2 if selected else 1)
		hit.add_theme_stylebox_override(state, style)

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
	var regle := Pastilles.info(str(slot[3]), "i", "TrainingSelectedInfo")
	Pastilles.poser_a_droite(holder, regle, 474, 16)
	if index == 0:
		var mode := str(state.get("mode", state.get("stored_mode", "normal")))
		var teinte: Color = C.Charte.REPOS if mode == "repos" else C.Charte.INTENSIF if mode == "intense" else C.Charte.NORMAL
		var icone := "heart" if mode == "repos" else "train"
		Pastilles.poser(holder, Pastilles.pastille(("Effectuée · " if trained else "") + _mode(), teinte, icone, "Charge retenue : " + _mode(), 22, "TrainingSelectedMode"), 150, 70)
	elif index == 12 and not str(training.get("advice", "")).is_empty():
		var lines := D.words(str(training.advice), 38, 4)
		for i in lines.size(): D.text(holder, 150, 72 + i * 24, lines[i], 21, C.IVORY, 500, 322)
	D.line(holder, Vector2(14, 166), Vector2(471, 166))
	D.text(holder, 14, 154, "Préparation du groupe", 20, C.MUTED, 500, 445)
	var unavailable := index == 0 and (trained or locked)
	var action_label: String = slot[4]
	if unavailable: action_label = "Séance effectuée" if trained else "Séance indisponible"
	var action := _action(holder, Rect2(17, 181, 453, 52), action_label, func(): _open_slot(index), false, "" if unavailable else "arrow", "TrainingEditSelected")
	action.disabled = unavailable

func _chart() -> void:
	var tile := D.panel(self, Rect2(1760, 11, 488, 296), "Charge & récupération", "heart", "", "TrainingLoadChart")
	var top := 90.0
	var bottom := 228.0
	var left := 73.0
	var right := 468.0
	for i in 6:
		var y := bottom - (bottom - top) * i / 5.0
		D.line(tile, Vector2(left, y), Vector2(right, y), Color(C.LINE, .64))
		D.text(tile, 60, y + 5, str(i * 20), 16, C.MUTED, 500, 39, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in FAMILIES.size():
		var family: Array = FAMILIES[i]
		var players := squad.filter(func(p: Dictionary): return int(p.get("fam", -1)) in family[1])
		var load_total := 0.0
		var condition_total := 0.0
		for player: Dictionary in players:
			load_total += float(player.get("physicalLoad", 0))
			condition_total += float(player.get("condition", 0))
		var count := maxi(1, players.size())
		var load_value := load_total / count
		var condition_value := condition_total / count
		var x := left + 12 + 56 * i
		D.text(tile, x + 24, 253, family[0], 16, C.IVORY, 600, 56, HORIZONTAL_ALIGNMENT_CENTER)
		if players.is_empty(): continue
		var tip := "%s · charge moyenne %.0f / 100 · condition moyenne %.0f %% · %s" % [family[0], load_value, condition_value, P.plural(players.size(), "joueur", "joueurs")]
		var series := [[load_value, C.Charte.INTENSIF if load_value >= 55.0 else C.Charte.NORMAL, x], [condition_value, C.Charte.REPOS, x + 25]]
		for serie: Array in series:
			var h := maxf(2.0, (bottom - top) * float(serie[0]) / 100.0)
			var bar := D.rect(tile, Rect2(float(serie[2]), bottom - h, 22, h), serie[1], 3)
			bar.mouse_filter = Control.MOUSE_FILTER_PASS
			bar.tooltip_text = tip
			D.text(tile, float(serie[2]) + 11, bottom - h - 4, "%.0f" % float(serie[0]), 15, C.IVORY, 700, 30, HORIZONTAL_ALIGNMENT_CENTER)
	for i in FAMILIES.size():
		var famille: Array = FAMILIES[i]
		var membres := squad.filter(func(p: Dictionary): return int(p.get("fam", -1)) in famille[1])
		if membres.is_empty(): continue
		membres.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("physicalLoad", 0)) > float(b.get("physicalLoad", 0)))
		_zone(tile, Rect2(left + 6 + 56 * i, top - 14, 54, bottom - top + 52), "TrainingChartFamily" + str(i), "%s · voir %s" % [famille[0], P.plural(membres.size(), "joueur", "joueurs")], func(): Groupe.ouvrir(self, "Poste · " + str(famille[0]), C.Charte.NORMAL, membres))
	# Seuil de vigilance : trait horizontal à 55.
	var seuil := bottom - (bottom - top) * 0.55
	D.line(tile, Vector2(left, seuil), Vector2(right, seuil), C.Charte.INTENSIF, 2)
	D.rect(tile, Rect2(21, 270, 16, 16), C.Charte.NORMAL, 3)
	D.text(tile, 43, 284, "Charge", 17, C.MUTED, 500, 80)
	D.rect(tile, Rect2(130, 270, 16, 16), C.Charte.REPOS, 3)
	D.text(tile, 152, 284, "Condition", 17, C.MUTED, 500, 95)
	D.rect(tile, Rect2(268, 277, 22, 3), C.Charte.INTENSIF, 1)
	D.text(tile, 298, 284, "Vigilance dès 55", 17, C.MUTED, 500, 160)

func _vigilance() -> void:
	var tile := D.panel(self, Rect2(1760, 318, 488, 178), "", "", "", "TrainingRisk")
	_icon(tile, "warning", Rect2(18, 13, 25, 25), C.Charte.INTENSIF)
	D.text(tile, 54, 35, "VIGILANCE PHYSIQUE  (%d)" % watched.size(), 25, C.IVORY, 700, 410)
	D.line(tile, Vector2(17, 47), Vector2(469, 47))
	if watched.is_empty():
		D.text(tile, 22, 92, "Aucune alerte physique", 24, GREEN, 600, 420)
		D.text(tile, 22, 127, "Mêmes repères que l’Effectif", 24, C.MUTED, 500, 420)
		return
	# Petite fenêtre : deux lignes plus hautes (cible minimale, deux lignes de texte lisibles) au lieu de trois ;
	# le total reste dans le titre et la liste entière dans l'onglet Fatigue.
	var dense := C.dense()
	var row_height := C.reach(38)
	var gap := 22.0 if dense else 17.0
	for i in mini(2 if dense else 3, watched.size()):
		var p: Dictionary = watched[i]
		var y := 51 + i * (row_height + 2)
		var button := _action(tile, Rect2(12, y, 464, row_height), "", func(): _player_dialog(p), false, "", "TrainingRisk_" + str(i))
		var reasons := Watch.watch_reason(p).split(" · ")
		var description := "%s · %s · %s" % [p.name, p.pos, " · ".join(reasons)]
		button.accessibility_name = description
		button.tooltip_text = description
		button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		_icon(button, "people", Rect2(19, 9.0 + (row_height - 38.0) / 2.0, 23, 23), C.IVORY)
		# Jauge verticale de condition (barème des attributs) ; le chiffre reste écrit à droite.
		var condition := clampf(float(p.get("condition", 0)), 0.0, 100.0)
		D.rect(button, Rect2(6, 6, 7, row_height - 12), C.Charte.PANNEAU_3, 3)
		D.rect(button, Rect2(6, 6 + (row_height - 12) * (1.0 - condition / 100.0), 7, (row_height - 12) * condition / 100.0), C.Charte.couleur_attribut(condition), 3)
		var top := 17.0 + (5.0 if dense else 0.0)
		D.text(button, 53, top, str(p.name), 22, C.IVORY, 700, 205)
		D.text(button, 53, top + gap, str(p.pos), 16, C.MUTED, 500, 205)
		for line in reasons.size():
			var baseline := row_height / 2.0 + 7.0 if reasons.size() == 1 else top + line * gap
			var reason := D.text(button, 452, baseline, reasons[line], 19, C.IVORY, 700, 183, HORIZONTAL_ALIGNMENT_RIGHT)
			reason.name = "TrainingRiskReason%d" % line
		_person_link(button,Rect2(47,0,214,row_height),"player",p,"TrainingRiskPlayer_"+str(p.get("id","")).validate_node_name())

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
		var player_key := str(p.get("id","")).validate_node_name()
		_person_link(hit,Rect2(3,3,81,73),"player",p,"TrainingAxisPlayerPortrait_"+player_key)
		_person_link(hit,Rect2(103,0,375,C.reach(42)),"player",p,"TrainingAxisPlayerName_"+player_key)

# Identity zones are reading actions. The remainder of each training card
# keeps its existing adjustment callback, including the current session guard.
func _person_link(parent: Control, rectangle: Rect2, kind: String, person: Dictionary, id: String) -> Button:
	if person.is_empty(): return null
	var person_id := str(person.get("id", ""))
	var target := {"kind":kind,"id":person_id}
	if person_id.is_empty() or not app.navigation_controller.entity_available(target): return null
	return Fatigue.entity_profile_link(app,parent,rectangle,target,id,str(person.get("name","")))

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
			D.chip(tile, Rect2(width - 177, y + 7, 155, 36), "Délégué" if delegated else "À ta main", GREEN if delegated else C.IVORY)
		D.line(tile, Vector2(17, y + 82), Vector2(width - 20, y + 82), Color(C.LINE, .65))
		var person_key := str(tile.name)+"_"+str(person.get("id","")).validate_node_name()
		_person_link(tile,Rect2(17,y+2,82,73),"staff",person,"TrainingStaffPortrait_"+person_key)
		_person_link(tile,Rect2(121,y+3,width-306 if i < 2 else width-141,C.reach(38)),"staff",person,"TrainingStaffName_"+person_key)

func _groups() -> void:
	var section := D.panel(self, Rect2(4, 260, 1740, 950), "Plans de travail", "people", "", "TrainingGroupPlans")
	var data: Dictionary = support.get("training", {})
	var plans: Array = data.get("plans", [])
	if plans.is_empty():
		D.text(section, 25, 97, "Aucun plan proposé pour cette carrière.", 23, C.MUTED, 500, 1620)
	else:
		section.size.y = C.px(Plans.hauteur_section())
		Plans.build(self, section, plans, data.get("available", false), _plans_reason())
	_chart()
	_vigilance()

## Pourquoi « Appliquer le plan » est grisé (mêmes conditions que le moteur : ni match en cours, ni séance déjà faite).
func _plans_reason() -> String:
	if trained: return "Séance déjà effectuée cette semaine."
	if not app._live().is_empty(): return "Match en cours."
	return "Les plans ne sont disponibles qu'en période de championnat."

func _individuals() -> void:
	var tile := D.panel(self, Rect2(4, 260, 1740, 950), "Le travail individuel", "train", "", "TrainingIndividuals")
	var scroll := ScrollContainer.new()
	scroll.name = "TrainingIndividualsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tile.add_child(scroll)
	# Petite fenêtre : en-têtes de tri et lignes à la cible minimale (la liste défile un peu plus).
	var header_height := C.reach(31)
	var row_height := C.reach(32)
	var lift := (row_height - 32.0) / 2.0
	D.place(scroll, Rect2(17, 103 + maxf(0.0, header_height - 31 - 4), 1704, 821 - maxf(0.0, header_height - 31 - 4)))
	var list := C.v(3)
	C.fill(list)
	scroll.add_child(list)
	for column in [["JOUEUR", 60, 366, "name"], ["POSTE", 440, 330, "pos"], ["CONDITION", 800, 180, "condition"], ["CHARGE", 993, 170, "physicalLoad"], ["PLAN INDIVIDUEL", 1174, 420, "loadPlan"]]:
		Fatigue.sort_header(app, tile, Rect2(column[1], 62 - minf(4.0, header_height - 31), column[2], header_height), column[0], column[3], state, "individual", "TrainingIndividualSort_" + str(column[3]))
	var ordered := Fatigue.sorted_players(squad, str(state.get("individual_sort", "priority")), state.get("individual_descending", false))
	for p: Dictionary in ordered:
		var row := C.button("", func(): _player_dialog(p))
		row.name = "TrainingIndividual_" + str(p.id).replace(":", "_")
		row.accessibility_name = str(p.name) + " · plan individuel"
		row.set_meta("player_id", p.id)
		row.custom_minimum_size.y = C.px(row_height)
		Fatigue.compact_button(row, 18)
		list.add_child(row)
		var link := Fatigue.profile_link(app, row, Rect2(0, 0, 429, row_height), p, "TrainingOpenPlayer_" + str(p.id).replace(":", "_"))
		_portrait(link, p, Rect2(7, 2 + lift, 26, 28))
		D.text(link, 63, 24 + lift, str(p.name), 20, C.IVORY, 700, 366)
		D.text(row, 442, 24 + lift, str(p.pos), 18, C.MUTED, 500, 330)
		D.text(row, 802, 24 + lift, Fatigue._number(p, "condition", " %"), 19, GREEN, 600, 160)
		D.text(row, 993, 24 + lift, Fatigue._number(p, "physicalLoad", " / 100"), 19, PALE_GOLD if p in watched else C.IVORY, 600, 150)
		D.text(row, 1174, 24 + lift, INDIVIDUAL.get(p.get("loadPlan", ""), "—"), 18, C.IVORY, 500, 420)
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
	D.photo(self, photo_centre(app.model), Rect2(4, 805, 1740, 381))
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
		4, 5: _open_tab(2)
		6: _open_tab(4)
		7: app._navigate("Travail du club")
		8: app._navigate("Plan de jeu")
		9: _choices_dialog(true)
		10: app._navigate("Composition")
		11: app._navigate("Match")
		12, 13: _open_tab(3)

func _validate() -> void:
	if locked or trained: return
	var mode := str(state.get("mode", ""))
	if not MODES.has(mode):
		_mode_dialog(true)
		return
	app.confirm("Effectuer la séance", "Charge retenue · %s\nLa séance sera effectuée et ses effets enregistrés." % MODES[mode],
		func(): app._command("train", {"mode":mode}), true)

func _mode_dialog(validate: bool) -> void:
	var window := _dialog("TrainingSessionDialog", "Effectuer la séance" if validate else "Modifier la séance")
	var body: VBoxContainer = window[1]
	var dialog: AcceptDialog = window[0]
	body.add_child(C.wrap("Une séance collective peut être effectuée chaque semaine. Ajuste d’abord la préparation spécifique et les charges individuelles.", 22, C.IVORY, true))
	if trained or locked:
		body.add_child(C.wrap("Séance effectuée cette semaine." if trained else "Séance indisponible pendant le match ou après la saison.", 22, C.MUTED, true))
	else:
		var selected: String = state.get("mode", state.get("stored_mode"))
		for id: String in MODES:
			var button := C.button(str(MODES[id]), func():
				dialog.hide()
				dialog.queue_free()
				if validate: app._command("train", {"mode":id})
				else:
					state.mode = id
					app._render(), selected == id, app.accent)
			button.name = "PreparationTrain_" + id if validate else "TrainingMode_" + id
			button.accessibility_name = ("Effectuer la séance · " if validate else "Sélectionner · ") + str(MODES[id])
			body.add_child(button)
		if validate: body.add_child(C.wrap("Choisir une charge ici effectue la séance et enregistre ses effets.", 19, C.MUTED, true))
	Dialogs.show_centered(dialog, Vector2i(C.px(760), C.px(320)))

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
	control.add_theme_font_size_override("font_size", C.font_px(23))
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
	if not str(p.get("id", "")).is_empty():
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

## Zone cliquable transparente (survol voilé, focus visible) posée sur un élément visuel qui a une destination.
func _zone(parent: Node, rectangle: Rect2, id: String, tip: String, callback: Callable) -> Button:
	var zone := D.button(parent, rectangle, "", callback, false, "", false, Color.WHITE, id)
	zone.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 10, 0))
	for etat in ["hover", "pressed", "hover_pressed"]: zone.add_theme_stylebox_override(etat, C.box(Color(1, 1, 1, .07), Color.TRANSPARENT, 10, 0))
	zone.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.IVORY, 10, 0))
	zone.tooltip_text = tip
	zone.accessibility_name = tip
	return zone

func _action(parent: Node, rectangle: Rect2, caption: String, callback: Callable, primary: bool, icon: String, id: String) -> Button:
	return D.button(parent, rectangle, caption, callback, primary, icon, false, Color("09673e"), id)


## Centre d'entraînement du club à son niveau (banque d'images, d'après les installations), sinon la séance habituelle.
static func photo_centre(model: Dictionary) -> String:
	var finance: Variant = preload("res://ui/immersive08/club_ui.gd").strategy(model).get("finance", {})
	var facility: Variant = finance.get("facility") if finance is Dictionary else null
	var niveau := BanqueImages.niveau_centre(facility.get("level") if facility is Dictionary else null)
	var id := "club-centre-entrainement-niveau-%d" % niveau
	return id if niveau > 0 and BanqueImages.existe(id) else "training-session"
