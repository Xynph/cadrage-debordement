extends VBoxContainer
# Reading state belongs to the application UI, never the career or its RNG.
const G = preload("res://ui/carnet_skin.gd")
const Decisions = preload("res://ui/decision_views.gd")
const MatchContext = preload("res://ui/preparation_match_context.gd")
const Reprise = preload("res://ui/reprise_view.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Briefing = preload("res://ui/preparation_briefing.gd")
const TABS = ["Dossier", "Consignes", "Entrainement"]
const TAB_CAPTIONS = ["Dossier adverse et repères du staff", "Consignes avec et sans le ballon", "Entraînement · le travail de la semaine"]
## Les trois charges de la séance collective : [mode, titre, effet, niveau de charge, image].
const LOADS = [
	["repos", "Récupération", "Condition et fraîcheur remontent. Pas de progression cette semaine.", 1, "medical-recovery"],
	["normal", "Charge normale", "Progression régulière, fatigue maîtrisée.", 2, "training-session"],
	["intense", "Intensive", "Plus de progrès, plus de fatigue : à doser avant un gros match.", 3, "academy-training"],
]
## Raccourcis du chapitre, regroupés dans l'unique barre d'onglets de la page.
const CHAPTER_LINKS = [["Composition", "Composition"], ["Plan de jeu", "Plan de jeu"], ["Match", "Jour de match"]]
var app: Control
var banner_caption: Label
var tab_bar: HBoxContainer
var state: Dictionary
var sections: Array[Control] = []
var tabs: Array[Button] = []
var tab_style: StyleBox
var tab_pressed_style: StyleBox
var restoring := true
var match_context := MatchContext.new()

static func build(application: Control) -> Control:
	var page := new()
	page.app = application
	page.name = "CarnetPreparation"
	G.fill(page, true)
	page.add_theme_constant_override("separation", 14)
	if not application.management_ui.get("preparation") is Dictionary:
		application.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	page.state = application.management_ui.preparation
	page._build()
	return page

func _build() -> void:
	# En-tête unique : bannière photo pleine largeur qui porte la seule barre d'onglets de la page.
	var bar := G.h(8)
	bar.name = "PreparationTabs"
	_banner().add_child(bar)
	tab_bar = bar
	for i in TABS.size():
		var button := G.button(["DOSSIER", "CONSIGNES", "ENTRAÎNEMENT"][i], func(): _choose(i))
		button.name = "PreparationTab" + TABS[i]
		button.toggle_mode = true
		button.tooltip_text = ["Adversaire et dossier du staff", "Avec et sans le ballon", "Charge, préparation spécifique et accès au match"][i]
		G.fill(button)
		bar.add_child(button)
		tabs.append(button)
		if tab_style == null:
			tab_style = button.get_theme_stylebox("normal")
			tab_pressed_style = button.get_theme_stylebox("pressed")
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				var next := posmod(i + (1 if event.keycode == KEY_RIGHT else -1), TABS.size())
				_choose(next)
				tabs[next].grab_focus()
				button.accept_event())
	_chapter_links(bar)
	for id in TABS:
		var section := G.v(14)
		section.name = "Preparation" + id
		G.fill(section, true)
		add_child(section)
		sections.append(section)
	if Reprise.relevant(app.model): Reprise.build(app, sections[0])
	Decisions.dossier_summary(app, sections[0])
	# Le bas de l'onglet Dossier porte des repères utiles ; la photo du club se réduit à une bannière.
	_week_board(sections[0])
	sections[0].add_child(_strip("city"))
	_consigne(sections[1])
	_training(sections[2])
	add_child(match_context)
	match_context.bind(app)
	_observe(self)
	# The shell owns the outer viewport; each section remembers its own position.
	app.body_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
		if not restoring: state.outer[int(state.tab)] = int(value))
	_show_tab()
	_restore.call_deferred()

func _consigne(parent: Control) -> void:
	match_context.consignes = parent
	match_context.focus_fallback = tabs[1]
	var info := G.panel(parent)
	match_context.status_row = info.get_parent()
	var live_line := G.h(12)
	info.add_child(live_line)
	match_context.live_context_row = live_line
	match_context.live_context = G.label("", 44, G.INK, true)
	match_context.live_context.name = "PreparationLiveContext"
	G.fill(match_context.live_context)
	live_line.add_child(match_context.live_context)
	match_context.return_button = G.button("", match_context.open_match, true)
	match_context.return_button.name = "PreparationConsignesReturn"
	live_line.add_child(match_context.return_button)
	var status_line := G.h(12)
	info.add_child(status_line)
	match_context.status = G.label("", 14)
	match_context.status.name = "PreparationMatchState"
	G.fill(match_context.status)
	status_line.add_child(match_context.status)
	match_context.pause_button = G.button("Mettre le match en pause", match_context.pause_match, true)
	match_context.pause_button.name = "PreparationPauseMatch"
	status_line.add_child(match_context.pause_button)
	var tactics: Dictionary = app.model.get("tactics", {})
	var row := G.h(14)
	G.fill(row, true)
	parent.add_child(row)
	for pair in [["attack","attacks","03","Avec le ballon","Attack"],["defense","defenses","04","Sans le ballon","Defense"]]:
		var card := G.panel(row)
		G.fill(card.get_parent(), true)
		G.chapter(card, pair[2], pair[3], "Ton intention de jeu pour la rencontre", app.accent)
		var list := G.scroll(card)
		var scroll: ScrollContainer = list.get_parent()
		scroll.name = "Preparation" + pair[4] + "Scroll"
		scroll.custom_minimum_size.y = 190
		scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if not restoring: state[pair[0]] = int(value))
		for option in tactics.get(pair[1], []):
			var button := G.button(str(option.label).to_upper(), func():
				if not match_context.can_edit_tactics(): return
				var current: Dictionary = app.model.get("tactics", {})
				var data: Dictionary = {"attack":current.get("attack","equilibre"),"defense":current.get("defense","equilibre")}
				data[pair[0]] = option.id
				app._command("set_tactics", data))
			button.name = "Preparation" + pair[4] + "_" + str(option.id)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.set_meta("tactic_id", str(option.id))
			if tactics.get(pair[0]) == option.id: G.selected(button, app.accent)
			match_context.tactics.append(button)
			list.add_child(button)
			list.add_child(G.wrap(option.get("description", ""), 14))
			list.add_child(G.separator())

func _training(parent: Control) -> void:
	var training := G.panel(parent)
	# The panel takes the whole section height: the club photo fills what the form leaves.
	G.fill(training.get_parent(), true)
	# Keep the whole training form and match access above the fold at 720p 1:1.
	training.add_theme_constant_override("separation", 9)
	# L'accès au match vit dans la barre d'onglets : toujours visible, sans ligne de plus ici.
	if MatchContext.match_available(app.model):
		match_context.match_button = G.button("", match_context.open_match, true)
		match_context.match_button.name = "PreparationMatch"
		tab_bar.add_child(match_context.match_button)
	var choices := G.h(12)
	choices.name = "PreparationLoads"
	training.add_child(choices)
	var meta: Dictionary = app.model.meta
	var season_closed: bool = meta.get("phase") == "ended"
	var trained: bool = meta.get("trained", false)
	var locked: bool = season_closed or trained or not app._live().is_empty()
	for entry: Array in LOADS:
		choices.add_child(_load_card(entry, locked, trained and str(meta.get("training", "")) == entry[0]))
	if season_closed: training.add_child(G.wrap("Séance indisponible après la clôture de la saison.", 14, G.MUTED))
	elif trained: training.add_child(G.label("Séance déjà effectuée cette semaine.", 14, G.GOOD))
	Decisions.training(app, training, not season_closed)
	training.add_child(_filler("stadium"))

## Une charge = une carte : image, titre, niveau de charge et effet sur le groupe. Toute la carte est le bouton.
func _load_card(entry: Array, locked: bool, chosen: bool) -> Button:
	var mode: String = entry[0]
	var card := Button.new()
	card.name = "PreparationTrain_" + mode
	card.custom_minimum_size = Vector2(0, 60)
	card.tooltip_text = "%s · %s" % [entry[1], entry[2]]
	card.accessibility_name = "Séance %s · %s" % [str(entry[1]).to_lower(), entry[2]]
	G.fill(card)
	var styles := {"normal": Color("fcfcf8"), "hover": Color("e3ebe8"), "pressed": Color("d1dfd9"), "disabled": Color("eceee9")}
	for look: String in styles:
		var style := G.Base.box(styles[look], "control", G.LINE)
		style.content_margin_left = 0
		style.content_margin_right = 0
		card.add_theme_stylebox_override(look, style)
	var focus := G.Base.box(Color.TRANSPARENT, "control", Color("345c57"))
	focus.set_border_width_all(2)
	card.add_theme_stylebox_override("focus", focus)
	if chosen:
		G.selected(card, app.accent)
		card.add_theme_stylebox_override("disabled", card.get_theme_stylebox("normal"))
	card.disabled = locked
	card.pressed.connect(func(): app._command("train", {"mode":mode}))
	var row := G.h(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5; row.offset_top = 5; row.offset_right = -8; row.offset_bottom = -5
	card.add_child(row)
	var picture := C.photo(str(entry[4]))
	picture.custom_minimum_size = Vector2(72, 0)
	picture.tooltip_text = ""
	row.add_child(picture)
	var words := G.v(2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.fill(words)
	row.add_child(words)
	var heading := G.h(8)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(heading)
	var name_label := G.label(entry[1], 18, G.INK, true)
	G.fill(name_label)
	heading.add_child(name_label)
	heading.add_child(_load_gauge(int(entry[3])))
	var effect := G.wrap(entry[2], 13, G.MUTED)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(effect)
	# Une carte indisponible s'efface, sauf la séance retenue cette semaine.
	if locked and not chosen: card.modulate = Color(1, 1, 1, .62)
	return card

## Trois crans : un pour la récupération, trois pour la séance intensive.
func _load_gauge(level: int) -> HBoxContainer:
	var gauge := G.h(3)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.tooltip_text = ""
	for step in 3:
		var notch := Panel.new()
		notch.custom_minimum_size = Vector2(12, 6)
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notch.add_theme_stylebox_override("panel", G.Base.box(G.accent_ink(app.accent) if step < level else G.LINE, "chip"))
		gauge.add_child(notch)
	return gauge

## Photo du club qui occupe la place laissée libre en bas de la section : pas de grand vide.
func _filler(kind: String) -> Control:
	# Voile sombre : la photo reste une ambiance de fond, pas un contenu qui écrase la page (1280×720).
	var picture := G.club_picture(app.model.club, kind, true)
	picture.name = "PreparationFiller_" + kind
	picture.custom_minimum_size = Vector2.ZERO
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.fill(picture, true)
	return picture

## Bannière photo basse (hauteur fixe) : l'ambiance du club sans écraser les repères de la semaine.
func _strip(kind: String) -> Control:
	var picture := G.club_picture(app.model.club, kind, true)
	picture.name = "PreparationStrip_" + kind
	picture.custom_minimum_size = Vector2(0, 56)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.fill(picture)
	return picture

## Repères de la semaine : ce que le staff a relevé avant le coup d'envoi, l'état du XV et la forme adverse.
## Lecture seule : chaque repère ouvre l'écran concerné, aucune commande sportive n'est envoyée.
func _week_board(parent: Control) -> void:
	var board := G.panel(parent)
	board.get_parent().name = "PreparationWeekBoard"
	G.fill(board.get_parent(), true)
	var columns := G.h(22)
	G.fill(columns, true)
	board.add_child(columns)
	# Colonne gauche : les repères du staff (trois au plus, la liste complète reste à un clic).
	var staff := G.v(6)
	staff.name = "PreparationStaffNotes"
	G.fill(staff, false, 1.5)
	columns.add_child(staff)
	staff.add_child(G.section("Avant le coup d’envoi", "Les repères du staff pour cette semaine"))
	var checks: Array = Briefing.project(app.model).checks
	for index in mini(3, checks.size()):
		var check: Dictionary = checks[index]
		var row := G.h(10)
		row.name = "PreparationStaffNote_" + str(check.id)
		staff.add_child(row)
		var mark := ColorRect.new()
		mark.color = _level_color(str(check.get("level", "info")))
		mark.custom_minimum_size = Vector2(4, 24)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var open := G.button(str(check.title) + "  →", Briefing.open_action.bind(app, str(check.action), func(): _choose(1)))
		open.name = "PreparationStaffOpen_" + str(check.id)
		open.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open.custom_minimum_size.x = 230
		open.tooltip_text = str(check.caption)
		open.accessibility_name = str(check.title) + " · " + str(check.detail)
		row.add_child(open)
		var detail := G.wrap(check.detail, 12)
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		G.fill(detail)
		row.add_child(detail)
	if checks.is_empty(): staff.add_child(G.wrap("Rien à signaler : le staff n’a relevé aucun point avant la rencontre.", 13))
	if checks.size() > 3:
		var all := G.reading_button(G.button("Tous les repères (%d)  →" % checks.size(), Briefing.open_all.bind(app, func(): _choose(1))), 160)
		all.name = "PreparationStaffAll"
		all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		staff.add_child(all)
	# Colonne droite : le XV du club et l'adversaire en chiffres.
	var squad := G.v(8)
	squad.name = "PreparationSquadPulse"
	G.fill(squad)
	columns.add_child(squad)
	squad.add_child(G.section("Ton XV cette semaine", "Feuille, fraîcheur et intentions de jeu"))
	var metrics := G.h(14)
	squad.add_child(metrics)
	var valid: bool = app.model.get("selection", {}).get("valid", false)
	metrics.add_child(G.metric("Valide" if valid else "À revoir", "feuille de match", G.GOOD if valid else G.ALERT))
	metrics.add_child(G.metric(P.lineup_condition(app.model), "condition du XV", G.GOOD))
	var squad_list: Array = app.model.get("squad", [])
	var injured: int = squad_list.filter(func(player: Dictionary): return float(player.get("injury", 0)) > 0).size()
	metrics.add_child(G.metric(G.n(injured), "blessé" + ("s" if injured > 1 else ""), G.ALERT if injured > 0 else G.GOOD))
	var tactics: Dictionary = app.model.get("tactics", {})
	squad.add_child(G.wrap("Avec le ballon · %s     Sans le ballon · %s" % [_tactic_label(tactics.get("attacks", []), tactics.get("attack")), _tactic_label(tactics.get("defenses", []), tactics.get("defense"))], 13, G.INK))
	squad.add_child(_opponent_form())

## Forme de l'adversaire : cinq derniers résultats publiés dans le dossier du staff.
func _opponent_form() -> Control:
	var row := G.h(6)
	row.name = "PreparationOpponentForm"
	var report: Variant = app.model.get("decisions", {}).get("preparation")
	var recent: Array = report.get("recent", []) if report is Dictionary else []
	var caption := G.label("FORME ADVERSE", 11, G.MUTED)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var shown := 0
	for result: Dictionary in recent.slice(0, 5):
		var score: Array = result.get("score", [])
		if score.size() != 2: continue
		var side := int(result.get("side", 0))
		var us := int(score[side])
		var them := int(score[1 - side])
		var letter := "V" if us > them else "D" if us < them else "N"
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(26, 24)
		chip.add_theme_stylebox_override("panel", G.Base.box(G.ALERT if letter == "D" else G.GOLD if letter == "N" else G.GOOD, "chip"))
		var mark := G.label(letter, 13, G.WHITE, true)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(mark)
		row.add_child(chip)
		shown += 1
	if shown == 0:
		# Texte à la ligne dans une rangée : sans largeur propre, il s'écrasait lettre par lettre.
		var empty := G.wrap("Aucun résultat adverse publié pour l’instant." if recent.is_empty() else "Résultats adverses sans score publié.", 12)
		empty.name = "PreparationOpponentFormEmpty"
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		G.fill(empty)
		row.add_child(empty)
	return row

func _level_color(level: String) -> Color:
	return G.ALERT if level == "urgent" else G.GOLD if level == "important" else G.GOOD

func _tactic_label(options: Array, id: Variant) -> String:
	for entry: Variant in options:
		if entry is Dictionary and entry.get("id") == id: return str(entry.get("label", "—"))
	return "—"

## Bannière photo sur toute la largeur : chapitre, onglet ouvert, puis la barre d'onglets (rendue au retour).
func _banner() -> VBoxContainer:
	var picture := G.club_picture(app.model.club, "stadium")
	picture.name = "PreparationBanner"
	picture.custom_minimum_size = Vector2(0, 68)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.fill(picture)
	add_child(picture)
	var content: VBoxContainer = picture.get_meta("content")
	content.add_theme_constant_override("separation", 4)
	for edge in ["top", "bottom"]: content.get_parent().add_theme_constant_override("margin_" + edge, 6)
	var titles := G.h(10)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(titles)
	var overline := G.Base.label("PRÉPARATION", 12, G.Base.GOLD)
	overline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(overline)
	banner_caption = G.Base.label(TAB_CAPTIONS[clampi(int(state.tab), 0, TAB_CAPTIONS.size() - 1)], 23, G.WHITE, true)
	banner_caption.name = "PreparationBannerCaption"
	banner_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	G.fill(banner_caption)
	titles.add_child(banner_caption)
	return content

## Une seule barre d'onglets : les raccourcis du chapitre (composition, plan de jeu, match) la rejoignent
## et la rangée du décor qui les portait se retire pour cette page.
func _chapter_links(bar: HBoxContainer) -> void:
	var root: Node = app.get("root_content")
	if app.get("route") != "Préparation" or not is_instance_valid(root): return
	var rows := root.find_children("ChapterSubnavigation", "", true, false)
	if rows.is_empty(): return
	for row: Control in rows: row.visible = false
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	for link: Array in CHAPTER_LINKS:
		var destination: String = link[0]
		# Le jour de match ouvert, le bouton d'accès au match de cette même barre prend le relais.
		if destination == "Match" and MatchContext.match_available(app.model): continue
		var button := G.reading_button(G.button(str(link[1]) + "  →", func(): app._navigate(destination)), 96)
		button.name = "PreparationLink_" + destination.replace(" ", "")
		button.tooltip_text = "Ouvrir : " + str(link[1])
		bar.add_child(button)

func _observe(node: Node) -> void:
	if node is BaseButton and node.focus_mode != Control.FOCUS_NONE and node != match_context.pause_button:
		node.focus_entered.connect(func():
			if not restoring:
				var index := tabs.find(node) if node in tabs else int(state.tab)
				state.focus[index] = str(node.name))
	for child in node.get_children(): _observe(child)

func _choose(index: int) -> void:
	if int(state.tab) == index:
		tabs[index].set_pressed_no_signal(true)
		return
	state.outer[int(state.tab)] = app.body_scroll.scroll_vertical
	state.tab = index
	restoring = true
	_show_tab()
	app._observe_navigation()
	# Tab selection keeps focus on the tab; Tab then enters its visible content.
	_restore.call_deferred(false)

func _show_tab() -> void:
	if banner_caption != null: banner_caption.text = TAB_CAPTIONS[clampi(int(state.tab), 0, TAB_CAPTIONS.size() - 1)]
	_sync_breadcrumb()
	for i in TABS.size():
		sections[i].visible = i == int(state.tab)
		tabs[i].set_pressed_no_signal(i == int(state.tab))
		if i == int(state.tab):
			G.selected(tabs[i], app.accent)
			tabs[i].add_theme_stylebox_override("pressed", tabs[i].get_theme_stylebox("normal"))
		elif tabs[i].has_meta("carnet_selection_skin"):
			G.clear_selection(tabs[i])
		else:
			tabs[i].add_theme_stylebox_override("normal", tab_style)
			tabs[i].add_theme_stylebox_override("pressed", tab_pressed_style)

## Le fil d'Ariane reprend le titre de la page (« Préparation ») quel que soit l'onglet ;
## l'onglet ouvert se lit dans la bannière. Le libellé du décor a été mesuré pour un mot au moins aussi long.
func _sync_breadcrumb() -> void:
	var root: Node = app.get("root_content")
	if app.get("route") != "Préparation" or not is_instance_valid(root): return
	for crumb: Node in root.find_children("ImmersiveRouteCaption", "Label", true, false):
		(crumb as Label).text = "Préparation"
		(crumb as Label).tooltip_text = "Préparation"

func _restore(restore_focus: bool = true) -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	if tree == null: return
	await tree.process_frame
	await tree.process_frame
	if not is_inside_tree(): return
	var index := int(state.tab)
	for pair in [["PreparationAttackScroll","attack"],["PreparationDefenseScroll","defense"]]:
		var scroll: ScrollContainer = find_child(pair[0], true, false)
		scroll.scroll_vertical = int(state[pair[1]])
	app.body_scroll.scroll_vertical = int(state.outer[index])
	if restore_focus and not str(state.focus[index]).is_empty():
		var control: Control = find_child(str(state.focus[index]), true, false)
		if control != null and control.is_visible_in_tree():
			if control is BaseButton and control.disabled:
				tabs[index].grab_focus()
				state.focus[index] = str(tabs[index].name)
			else: control.grab_focus()
	restoring = false
