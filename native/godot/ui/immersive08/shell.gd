extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Office = preload("res://ui/immersive08/office.gd")
const G = preload("res://ui/game_skin.gd")

const GROUPS = [
	["Bureau", "Bureau", ["Bureau"]],
	["Effectif", "Effectif", ["Effectif", "Vestiaire"]],
	["Tactique", "Composition", ["Composition", "Préparation", "Plan de jeu", "Match"]],
	["Recrutement", "Recrutement", ["Recrutement"]],
	["Club", "Club", ["Club", "Staff", "Travail du club", "Stratégie"]],
	["Finances", "Finances", ["Finances"]],
	["Compétitions", "Classements", ["Classements", "Calendrier", "Presse", "Rivalités"]],
	["Formation", "Formation", ["Formation", "Centre"]],
	["Carrière", "Carrière", ["Carrière"]]
]
const TITLES = {"Bureau":"Votre semaine commence ici.", "Effectif":"Les hommes du projet.", "Composition":"Le XV de départ.", "Préparation":"La semaine se gagne ici.", "Plan de jeu":"Votre identité de jeu.", "Vestiaire":"Un groupe, une ambition.", "Recrutement":"Le prochain renfort.", "Club":"Un club. Un territoire.", "Finances":"Garder une longueur d’avance.", "Classements":"Chaque point compte.", "Calendrier":"Le fil de votre saison.", "Formation":"Le futur porte nos couleurs.", "Centre":"Les chemins de la progression.", "Staff":"Le collectif derrière le collectif.", "Travail du club":"Des décisions qui engagent.", "Stratégie":"Construire dans la durée.", "Presse":"La voix du club.", "Rivalités":"Votre place dans le rugby.", "Carrière":"Une carrière à écrire.", "Match":"Le jour de match."}

static func render(app: Control) -> bool:
	if not app.model.get("club") is Dictionary or app.route in ["Accueil", "Création", "Packs"]: return false
	var window := app.get_window()
	var physical := window.size
	# Les composants gèrent leur densité. Le canvas natif doit garder les pixels
	# disponibles, indépendamment de la référence 1600p de l'ancien carnet.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if physical.x >= 1280 and physical.y >= 720:
		window.content_scale_size = Vector2i(mini(physical.x, 2560), mini(physical.y, 1440))
	C.configure(minf(physical.y, 1440))
	if is_instance_valid(app.root_content):
		app.remove_child(app.root_content)
		app.root_content.queue_free()
	app.match_screen = null
	app.match_page = null
	app.match_view = null
	app.entry_scroll = null
	app.root_content = Control.new()
	app.root_content.name = "ImmersiveShell"
	app.root_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(app.root_content)
	app.move_child(app.root_content, 0)
	var background := ColorRect.new()
	background.color = C.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.root_content.add_child(background)
	var shell := C.h(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.root_content.add_child(shell)
	_sidebar(shell, app)
	var workspace := C.v(0)
	C.fill(workspace, true)
	shell.add_child(workspace)
	_topbar(workspace, app)
	var inset := C.margin(32)
	app.workspace_inset = inset
	inset.add_theme_constant_override("margin_top", C.px(28))
	inset.item_rect_changed.connect(app._layout_coach)
	C.fill(inset, true)
	workspace.add_child(inset)
	var content := C.v(16)
	content.name = "CareerContent"
	inset.add_child(content)
	_heading(content, app)
	_subnavigation(content, app)
	app.body_scroll = ScrollContainer.new()
	app.body_scroll.name = "CareerWorkspace"
	app.body_scroll.follow_focus = true
	app.body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(app.body_scroll, true)
	content.add_child(app.body_scroll)
	app.body = C.v(16)
	C.fill(app.body, true)
	app.body_scroll.add_child(app.body)
	if app.route == "Bureau": app.body.add_child(Office.build(app))
	else: _existing_page(app)
	_footer(content, app)
	app._update_live_bar()
	app.call_deferred("_refresh_coach")
	app.call_deferred("_observe_navigation")
	return true

static func _sidebar(parent: Node, app: Control) -> void:
	var rail := PanelContainer.new()
	rail.name = "ImmersiveSidebar"
	rail.custom_minimum_size.x = C.px(248)
	rail.add_theme_stylebox_override("panel", C.box(Color("0a1915"), Color("30443a"), 0, 18))
	parent.add_child(rail)
	var column := C.v(12)
	rail.add_child(column)
	var logo := C.button("", app.pause_menu)
	logo.name = "ImmersiveMainMenu"
	logo.custom_minimum_size.y = C.px(102)
	logo.tooltip_text = "Menu, sauvegardes et paramètres"
	logo.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	column.add_child(logo)
	var bitmap := C.photo("brand")
	bitmap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bitmap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.add_child(bitmap)
	column.add_child(C.rule())
	var crest := G.crest(app.model.club, C.px(132))
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(crest)
	var club := C.wrap(G.club_name(app.model.club).to_upper(), 25, C.IVORY, true)
	club.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(club)
	var season := C.label("SAISON " + G.n(app.model.meta.get("season", 1)), 18, C.GOLD)
	season.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(season)
	column.add_child(C.rule())
	var names: Array = [["home", "Bureau", "Bureau"], ["mail", "Réception", "Bureau"], ["people", "Effectif", "Effectif"], ["tactic", "Tactique", "Composition"], ["train", "Entraînement", "Préparation"], ["search", "Recrutement", "Recrutement"], ["shield", "Club", "Club"], ["money", "Finances", "Finances"], ["trophy", "Compétitions", "Classements"], ["school", "Formation", "Formation"]]
	for entry: Array in names:
		var destination: String = entry[2]
		var selected: bool = app.route == destination and entry[1] != "Réception"
		if entry[1] == "Tactique": selected = app.route in ["Composition", "Plan de jeu"]
		if entry[1] == "Club": selected = app.route in ["Club", "Staff", "Travail du club", "Stratégie"]
		if entry[1] == "Compétitions": selected = app.route in ["Classements", "Calendrier", "Presse", "Rivalités"]
		if entry[1] == "Formation": selected = app.route in ["Formation", "Centre"]
		var action := C.button(entry[1], func(): app._navigate(destination), selected, app.accent)
		action.icon = C.icon_texture(entry[0], C.IVORY)
		action.expand_icon = true
		action.add_theme_constant_override("icon_max_width", C.px(25))
		action.add_theme_constant_override("h_separation", C.px(17))
		action.add_theme_font_override("font", C.DISPLAY)
		action.add_theme_font_size_override("font_size", C.px(26))
		action.name = "Nav_" + entry[1]
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.custom_minimum_size.y = C.px(49)
		if not selected: action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 4, 6))
		column.add_child(action)
	var spacer := Control.new()
	C.fill(spacer, true)
	column.add_child(spacer)
	column.add_child(C.rule())
	for entry in [["Carrière  →", "Carrière"], ["Réglages", "settings"], ["Sauvegarder", "save"]]:
		var action := C.button(entry[0], func():
			if entry[1] == "settings": app.settings()
			elif entry[1] == "save": app._command("save")
			else: app._navigate(entry[1]))
		action.custom_minimum_size.y = C.px(36)
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		column.add_child(action)

static func _topbar(parent: Node, app: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ImmersiveTopbar"
	panel.custom_minimum_size.y = C.px(78)
	panel.add_theme_stylebox_override("panel", C.box(Color("0e1618"), C.LINE, 0, 20))
	parent.add_child(panel)
	var row := C.h(24)
	panel.add_child(row)
	var breadcrumb := C.label("⌂  ›  " + (G.club_name(app.model.club) + "  ›  " if app.get_window().size.x >= 1900 else "") + app.route, 24)
	breadcrumb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	C.fill(breadcrumb)
	row.add_child(breadcrumb)
	var search := C.button("⌕   Rechercher un joueur, un club…     Ctrl K", func(): app.navigation_controller.open_palette())
	search.name = "ImmersiveSearch"
	search.clip_text = true
	search.custom_minimum_size.x = C.px(430 if app.get_window().size.x >= 1900 else 290)
	search.alignment = HORIZONTAL_ALIGNMENT_LEFT
	search.add_theme_color_override("font_color", C.MUTED)
	row.add_child(search)
	app.header_date = C.label("", 24)
	app._update_header_date()
	row.add_child(app.header_date)
	app.primary_button = C.button(app.primary_text(), app.primary_action, true, app.accent)
	app.primary_button.name = "ImmersiveContinue"
	row.add_child(app.primary_button)

static func _heading(parent: Node, app: Control) -> void:
	var row := C.h(24)
	parent.add_child(row)
	var titles := C.v(3)
	C.fill(titles)
	row.add_child(titles)
	titles.add_child(C.label(app.route.to_upper(), 19, C.GOLD))
	app.heading = C.label(TITLES.get(app.route, app.route), 53, C.IVORY, true, 700)
	titles.add_child(app.heading)
	var values := P.group(app.model)
	var metrics := C.h(12)
	row.add_child(metrics)
	var rank := G.n(app.model.club.get("rank", "—"))
	for pair in [[rank + ("er" if rank == "1" else "e") + " · " + G.n(app.model.club.get("points", 0)) + " pts", C.GOLD], [str(values.available) + " disponibles", C.MINT], [str(values.injured) + " blessés", C.ALERT]]:
		var chip := C.chip(pair[0], pair[1])
		chip.custom_minimum_size = Vector2(C.px(212), C.px(58))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		metrics.add_child(chip)
	metrics.visible = app.get_window().size.x >= 1600
	app.minibar = C.label("", 17, C.GOLD)
	app.minibar.visible = false
	parent.add_child(app.minibar)

static func _subnavigation(parent: Node, app: Control) -> void:
	for group: Array in GROUPS:
		if app.route not in group[2] or group[2].size() < 2: continue
		var row := C.h(8)
		row.name = "ChapterSubnavigation"
		parent.add_child(row)
		for destination: String in group[2]:
			var action := C.button(destination.to_upper(), func(): app._navigate(destination), app.route == destination, app.accent)
			action.name = "Section_" + destination
			action.custom_minimum_size.y = C.px(38)
			C.fill(action)
			row.add_child(action)
		return

static func _footer(parent: Node, app: Control) -> void:
	parent.add_child(C.rule())
	var row := C.h(16)
	parent.add_child(row)
	app.status = C.label(app._settled_status_text(), 17, C.ALERT if app._status_has_error() else C.MUTED)
	app.status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	C.fill(app.status)
	row.add_child(app.status)
	var shortcuts := C.label("Ctrl S  Sauvegarder   ·   Ctrl K  Rechercher   ·   F1  Aide", 17, C.MUTED)
	shortcuts.visible = app.get_window().size.x >= 1900
	row.add_child(shortcuts)
	if app.decision_feedback != null: row.add_child(app.decision_feedback.control())
	var dock := Control.new()
	dock.name = "CoachCompactDock"
	dock.custom_minimum_size = Vector2(C.px(144), C.px(34))
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.visible = is_instance_valid(app.coach)
	row.add_child(dock)

static func _existing_page(app: Control) -> void:
	match app.route:
		"Club": app.body.add_child(app.ClubViews.club(app))
		"Calendrier": app.body.add_child(app.ClubViews.calendar(app))
		"Classements": app.body.add_child(app.ClubViews.tables(app))
		"Finances": app.body.add_child(app.ClubViews.finance(app))
		"Effectif": app.body.add_child(app.SquadViews.squad(app))
		"Composition": app.body.add_child(app.SquadViews.lineup(app))
		"Préparation": app.body.add_child(app.SquadViews.preparation(app))
		"Plan de jeu": app.body.add_child(app.PlaybookViews.build(app))
		"Recrutement": app.body.add_child(app.SquadViews.market(app))
		"Staff": app.body.add_child(app.StaffViews.build(app))
		"Formation": app.body.add_child(app.DevelopmentViews.build(app))
		"Presse": app.body.add_child(app.PressViews.build(app))
		"Vestiaire": app.body.add_child(app.RelationshipsViews.build(app))
		"Rivalités": app.body.add_child(app.WorldViews.build(app))
		"Stratégie": app.body.add_child(app.StrategyViews.build(app))
		"Centre": app.body.add_child(app.AcademyViews.build(app))
		"Travail du club": app.body.add_child(app.SupportViews.build(app))
		"Carrière": app.body.add_child(app.ManagerCareerViews.build(app))
		"Match":
			app.match_screen = app.MatchUI.new()
			app.match_screen.app = app
			app.body.add_child(app.match_screen)
			app.match_page = app.match_screen
			app.match_screen.update_frame(app.model)
