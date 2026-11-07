extends Control

const Art = preload("res://theme.gd")
const Widget = preload("res://visual_widgets.gd")
var model: Dictionary = {}
var catalogue: Array = []
var route := "Bureau"
var selected_player := ""
var selected_club := 0
var accent := Color("d43e47")
var bridge: Node
var body: VBoxContainer
var heading: Label
var subtitle: Label
var sidebar_club: Label
var sidebar_crest: Control
var status: Label
var nav_buttons: Dictionary = {}
var waiting := false
var match_view: Node3D
var match_page: VBoxContainer
var match_score: Label
var match_clock: Label
var match_events: Label
var match_stats: Label
var pause_button: Button
var match_finish: Button
var timer: Timer
var tick_steps := 1
var viewport: SubViewport
var file_dialog: FileDialog
var import_mode := false
var export_path := ""
var roster_scroll: ScrollContainer
var roster_offset := 0
var closing := false
var initial_model_received := false

func _ready() -> void:
	if OS.get_environment("CD_GODOT_SELF_TEST") == "1" and OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Le test automatique exige un profil temporaire explicite.")
		get_tree().quit(2)
		return
	theme = Art.make()
	RenderingServer.set_default_clear_color(Art.BG)
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://assets/clubs.json"))
	_build_shell()
	bridge = load("res://engine_bridge.gd").new()
	add_child(bridge)
	bridge.model_changed.connect(_receive_model)
	bridge.command_failed.connect(_failed)
	bridge.start(_profile_path())
	timer = Timer.new()
	timer.wait_time = 0.4
	timer.timeout.connect(_live_tick)
	add_child(timer)
	timer.start()
	get_tree().root.close_requested.connect(_close)
	get_tree().auto_accept_quit = false
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; Carrière Cadrage Débordement"])
	file_dialog.file_selected.connect(_file_selected)
	add_child(file_dialog)
	_show_loading()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-route="): route = arg.get_slice("=", 1)
	if OS.get_environment("CD_GODOT_SELF_TEST") == "1":
		var qa: Node = load("res://qa_runner.gd").new()
		qa.app = self
		add_child(qa)

func _profile_path() -> String:
	var explicit := OS.get_environment("CD_GODOT_DATA_DIR")
	if not explicit.is_empty(): return explicit
	return OS.get_user_data_dir()

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Art.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var all := HBoxContainer.new()
	all.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	all.add_theme_constant_override("separation", 0)
	add_child(all)
	var rail := _panel(Color("121b20"), 22)
	rail.custom_minimum_size.x = 214
	all.add_child(rail)
	var left := _v(18)
	rail.get_child(0).add_child(left)
	left.add_child(_label("CD", 54, Art.INK, true))
	left.add_child(_label("CADRAGE\nDÉBORDEMENT", 18, Art.INK, true))
	left.add_child(_rule())
	sidebar_crest = _crest("XV", accent, 62)
	left.add_child(sidebar_crest)
	sidebar_club = _label("VOTRE CLUB", 16, Art.INK, true)
	sidebar_club.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(sidebar_club)
	left.add_child(_label("DIRECTION SPORTIVE", 11, Art.MUTED))
	left.add_child(_rule())
	for name in ["Bureau", "Club", "Effectif", "Match"]:
		var b := _button(name.to_upper(), func(): _navigate(name))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 46
		nav_buttons[name] = b
		left.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(_label("PROTOTYPE NATIF", 12, Color("d9ba75")))
	left.add_child(_label("Windows · Godot\nCarrière historique à 14 clubs\n30 territoires à découvrir", 11, Art.MUTED))
	var credits := _button("CRÉDITS & LICENCES", _credits)
	credits.add_theme_font_size_override("font_size", 10)
	left.add_child(credits)
	var main_margin := MarginContainer.new()
	main_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right"]: main_margin.add_theme_constant_override("margin_" + edge, 30)
	for edge in ["top", "bottom"]: main_margin.add_theme_constant_override("margin_" + edge, 20)
	all.add_child(main_margin)
	var main := _v(16)
	main_margin.add_child(main)
	var top := _h(12)
	main.add_child(top)
	var titles := _v(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	subtitle = _label("LA SAISON VOUS APPARTIENT", 11, Art.MUTED)
	titles.add_child(subtitle)
	heading = _label("LE BUREAU", 40, Art.INK, true)
	titles.add_child(heading)
	top.add_child(_button("SAUVEGARDER", func(): _command("save")))
	top.add_child(_button("⋯", _save_menu))
	body = _v(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	status = _label("Connexion à la simulation…", 11, Art.MUTED)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.add_child(status)

func _receive_model(value: Dictionary) -> void:
	var first_model := not initial_model_received
	initial_model_received = true
	model = value
	waiting = false
	if model.get("club") == null:
		_render()
		if first_model and bridge.last_response_ok:
			_command("new_career", {"club": 0})
		return
	if not export_path.is_empty():
		var exported: String = str(model.get("meta", {}).get("exportText", ""))
		var destination := export_path
		export_path = ""
		if exported.is_empty():
			_failed("L'export du moteur est vide ; aucun fichier écrit.")
			return
		var temporary := destination + ".tmp-" + str(OS.get_process_id())
		var file := FileAccess.open(temporary, FileAccess.WRITE)
		if file == null:
			_failed("Impossible d'écrire cet export : " + error_string(FileAccess.get_open_error()))
			return
		file.store_string(exported)
		file.flush()
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			DirAccess.remove_absolute(temporary)
			_failed("Écriture de l'export refusée : " + error_string(write_error))
			return
		var rename_error := DirAccess.rename_absolute(temporary, destination)
		if rename_error != OK:
			DirAccess.remove_absolute(temporary)
			_failed("Remplacement de l'export refusé : " + error_string(rename_error))
			return
	var club: Dictionary = model.get("club", {})
	var identity: Dictionary = club.get("presentation", {})
	accent = Color(identity.get("color", "#d43e47"))
	sidebar_crest.initials = str(identity.get("abbr", "XV"))
	sidebar_crest.accent = accent
	sidebar_crest.queue_redraw()
	sidebar_club.text = str(identity.get("name", club.get("name", "Votre club")))
	var meta: Dictionary = model.get("meta", {})
	subtitle.text = "SAISON %s  /  JOURNÉE %s  /  CARRIÈRE FICTIVE" % [_number(meta.get("season", "—")), str(int(meta.get("round", 0)) + 1)]
	status.text = "Simulation locale · Sauvegarde automatique · Profil prototype indépendant"
	status.modulate = Color.WHITE
	if route == "Match" and is_instance_valid(match_page):
		_update_match()
	else:
		_render()

func _command(command: String, payload: Dictionary = {}) -> void:
	if waiting: return
	waiting = true
	status.text = "En cours…"
	bridge.send(command, payload)

func _failed(message: String) -> void:
	waiting = false
	status.text = "ERREUR · " + message
	status.modulate = Color("ffb5aa")
	var dialog := AcceptDialog.new()
	dialog.title = "Action non effectuée"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered(Vector2i(540, 150))
	dialog.confirmed.connect(dialog.queue_free)

func _navigate(name: String) -> void:
	route = name
	_render()

func _clear_body() -> void:
	if is_instance_valid(roster_scroll): roster_offset = roster_scroll.scroll_vertical
	roster_scroll = null
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	match_view = null
	match_page = null

func _render() -> void:
	_clear_body()
	for key in nav_buttons:
		nav_buttons[key].add_theme_stylebox_override("normal", Art.box(accent.darkened(0.5) if key == route else Color("19262d"), 5, accent if key == route else Color.TRANSPARENT))
	heading.text = {"Bureau": "LE BUREAU", "Club": "UN CLUB. UN TERRITOIRE.", "Effectif": "LES HOMMES DU PROJET", "Match": "LE JOUR DE MATCH"}.get(route, route)
	if model.is_empty():
		_show_loading()
		return
	if model.get("club") == null:
		body.add_child(_label("CARRIÈRE NON CRÉÉE", 32, Art.INK, true))
		body.add_child(_label("Vérifiez l'accès au dossier du profil, puis réessayez explicitement.", 16, Art.MUTED))
		body.add_child(_button("RÉESSAYER LA CRÉATION", func(): _command("new_career", {"club": 0}), true))
		return
	match route:
		"Club": _club_page()
		"Effectif": _squad_page()
		"Match": _match_page()
		_: _office_page()

func _show_loading() -> void:
	body.add_child(_label("PRÉPARATION DE VOTRE CARRIÈRE", 32, Art.INK, true))
	body.add_child(_label("Chargement du moteur local et du profil prototype…", 16, Art.MUTED))

func _office_page() -> void:
	var club: Dictionary = model.get("club", {})
	var next: Dictionary = model.get("next", {}) if model.get("next") != null else {}
	var top := _h(16)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	var hero := _photo_card(_identity(next.get("home", club)).get("slug", "toulouse"), "stadium")
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_stretch_ratio = 2.2
	top.add_child(hero)
	var overlay: VBoxContainer = hero.get_meta("content")
	overlay.add_child(_label("PROCHAIN RENDEZ-VOUS", 12, Color("e6c488")))
	overlay.add_child(_label(str(next.get("label", "La suite de votre saison")), 14, Art.INK))
	var free := Control.new()
	free.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.add_child(free)
	var teams := _h(18)
	for field in ["home", "away"]:
		var c: Dictionary = next.get(field, club)
		var id := _identity(c)
		var team := _v(8)
		team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team.add_child(_crest(str(id.get("abbr", "XV")), Color(id.get("color", "#d43e47")), 64))
		var name := _label(str(id.get("name", c.get("name", "—"))), 29, Art.INK, true)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		team.add_child(name)
		teams.add_child(team)
		if field == "home": teams.add_child(_label("/", 45, Art.MUTED, true))
	overlay.add_child(teams)
	overlay.add_child(_label(str(_identity(next.get("home", club)).get("stadium", club.get("stadium", ""))), 12, Art.INK))
	overlay.add_child(_button("PRÉPARER LE MATCH  →", func(): _navigate("Match"), true))
	var side := _card_column(top, 1.0)
	side.add_child(_label("CAP SUR LA SAISON", 20, Art.INK, true))
	side.add_child(_metric(_number(club.get("rank", "—")) + "e", "AU CLASSEMENT", accent.lightened(0.4)))
	side.add_child(_rule())
	side.add_child(_metric(_number(club.get("points", 0)), "POINTS"))
	side.add_child(_rule())
	side.add_child(_label(str(club.get("goal", "Votre projet sportif")), 22, Art.INK, true))
	side.add_child(_label("Objectif de votre carrière fictive", 11, Art.MUTED))
	var lower := _h(16)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.size_flags_stretch_ratio = 0.85
	body.add_child(lower)
	var group := _card_column(lower, 1.35)
	group.add_child(_section("LE GROUPE", "Des décisions qui comptent"))
	var squad: Array = model.get("squad", [])
	var avg := 0.0
	var unavailable := 0
	for p in squad:
		avg += float(p.get("condition", 0))
		if float(p.get("injury", 0)) > 0: unavailable += 1
	var metrics := _h(20)
	metrics.add_child(_metric(str(squad.size()), "JOUEURS"))
	metrics.add_child(_metric("%d%%" % (avg / maxf(1, squad.size())), "CONDITION MOYENNE"))
	metrics.add_child(_metric(str(unavailable), "INDISPONIBLES"))
	group.add_child(metrics)
	var acts := _h(8)
	acts.add_child(_button("ENTRAÎNER", _training))
	acts.add_child(_button("COMPOSER LE XV", func(): _command("auto_lineup")))
	group.add_child(acts)
	group.add_child(_label("L'entraînement et la sélection agissent sur votre vraie carrière.", 11, Art.MUTED))
	group.add_child(_button("VOIR L'EFFECTIF  →", func(): _navigate("Effectif")))
	var table := _card_column(lower, 1.0)
	table.add_child(_section("LA CONCURRENCE", "Championnat historique · 14 clubs"))
	for row in model.get("league", []).slice(0, 5):
		var line := _h(10)
		line.add_child(_label(_number(row.get("rank", "—")).pad_zeros(2), 14, Art.MUTED))
		var name := _label(str(_identity(row).get("name", row.get("name", ""))), 14)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name)
		line.add_child(_label(_number(row.get("points", 0)), 18, Art.INK, true))
		table.add_child(line)

func _club_page() -> void:
	var selector := OptionButton.new()
	selector.custom_minimum_size.y = 42
	for c in catalogue: selector.add_item(str(c.name), int(c.id))
	selector.select(selected_club)
	selector.item_selected.connect(func(index: int): selected_club = index; _render())
	body.add_child(selector)
	var c: Dictionary = catalogue[selected_club]
	var images := _h(16)
	images.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(images)
	for kind in ["city", "stadium"]:
		var picture := _photo_card(c.slug, kind)
		picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picture.size_flags_stretch_ratio = 1.5 if kind == "city" else 1.0
		images.add_child(picture)
		var overlay: VBoxContainer = picture.get_meta("content")
		overlay.add_child(_label("LE TERRITOIRE" if kind == "city" else "LE STADE", 12, Color("e6c488")))
		var space := Control.new()
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		overlay.add_child(space)
		var caption := _label(c.city if kind == "city" else c.stadium, 34, Art.INK, true)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		overlay.add_child(caption)
		overlay.add_child(_label("Photographie réelle d'archive · crédits accessibles", 11, Art.INK))
	var info := _panel()
	body.add_child(info)
	var row := _h(24)
	info.get_child(0).add_child(row)
	row.add_child(_crest(c.abbr, Color(c.color), 88))
	var description := _v(5)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	description.add_child(_label(c.name, 35, Art.INK, true))
	description.add_child(_label("ÉLITE · 14 TERRITOIRES" if c.division == "elite" else "ACCESSION · 16 TERRITOIRES", 12, Color(c.color).lightened(0.4)))
	description.add_child(_label("Identité de jeu originale. Ville et stade réels ; données sportives fictives.", 12, Art.MUTED))
	var actions := _v(8)
	row.add_child(actions)
	if selected_club < 14:
		actions.add_child(_button("ESSAYER CE CLUB", func(): _confirm_career(selected_club), true))
	else:
		actions.add_child(_label("CATALOGUE DU FUTUR MODE", 12, Color("e6c488")))
		actions.add_child(_label("La carrière à 30 clubs est en chantier.", 12, Art.MUTED))
	actions.add_child(_button("CRÉDITS DE CES PHOTOS", _credits))
	body.add_child(_label("30 territoires consultables. Ce prototype réutilise le championnat fictif historique à 14 clubs pour éprouver l'interface native.", 12, Art.MUTED))

func _squad_page() -> void:
	var squad: Array = model.get("squad", [])
	if squad.is_empty(): return
	var selected: Dictionary = squad[0]
	for p in squad:
		if str(p.id) == selected_player: selected = p
	selected_player = str(selected.id)
	var row := _h(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var table := _card_column(row, 1.65)
	table.add_child(_section("L'EFFECTIF PROFESSIONNEL", "%d joueurs · sélectionnez une fiche" % squad.size()))
	var head := _h(12)
	for pair in [["JOUEUR", 210], ["POSTE", 100], ["ÂGE", 38], ["NIV.", 40], ["COND.", 60]]:
		var l := _label(pair[0], 10, Art.MUTED)
		l.custom_minimum_size.x = pair[1]
		if pair[0] == "JOUEUR": l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(l)
	table.add_child(head)
	var scroll := ScrollContainer.new()
	roster_scroll = scroll
	scroll.set_deferred("scroll_vertical", roster_offset)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table.add_child(scroll)
	var list := _v(3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for p in squad:
		var b := _button("", func(): selected_player = str(p.id); _render())
		b.custom_minimum_size.y = 43
		if str(p.id) == selected_player: b.add_theme_stylebox_override("normal", Art.box(accent.darkened(0.65), 4, accent))
		var line := _h(12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := MarginContainer.new()
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(m)
		m.add_child(line)
		var name := _label(str(p.name), 13)
		name.custom_minimum_size.x = 210
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name)
		for pair in [[str(p.get("pos", "")), 100], [_number(p.get("age", "")), 38], [_number(p.get("rating", "")), 40], ["%d%%" % float(p.get("condition", 0)), 60]]:
			var l := _label(pair[0], 13, Art.MUTED)
			l.custom_minimum_size.x = pair[1]
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(l)
		list.add_child(b)
	var profile := _card_column(row, 1.0)
	var face_row := _h(16)
	face_row.add_child(_portrait(int(selected.get("portraitIndex", 0)), 104))
	var identity := _v(3)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := _label(str(selected.name), 29, Art.INK, true)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(n)
	identity.add_child(_label("%s · %s ans" % [str(selected.get("pos", "")), _number(selected.get("age", ""))], 12, Art.MUTED))
	identity.add_child(_label(str(selected.get("status", "")), 12, accent.lightened(0.4)))
	face_row.add_child(identity)
	profile.add_child(face_row)
	profile.add_child(_rule())
	var metrics := _h(18)
	metrics.add_child(_metric(_number(selected.get("rating", "—")), "NIVEAU"))
	metrics.add_child(_metric(_number(selected.get("potential", "—")), "POTENTIEL"))
	metrics.add_child(_metric("%d%%" % float(selected.get("condition", 0)), "CONDITION", Art.GREEN))
	profile.add_child(metrics)
	var attrs: Dictionary = selected.get("attributes", {})
	var radar := Widget.new()
	radar.mode = "radar"
	radar.accent = accent
	radar.values = [attrs.get("power", 0), attrs.get("speed", 0), attrs.get("pass", 0), attrs.get("tackle", 0), attrs.get("stamina", 0), attrs.get("mental", 0)]
	radar.custom_minimum_size = Vector2(170, 170)
	profile.add_child(radar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	profile.add_child(grid)
	for pair in [["power", "Puissance"], ["speed", "Vitesse"], ["pass", "Passe"], ["tackle", "Plaquage"], ["stamina", "Endurance"], ["mental", "Mental"]]:
		grid.add_child(_label("%s   %s" % [pair[1], _number(attrs.get(pair[0], "—"))], 12, Art.MUTED))
	profile.add_child(_rule())
	profile.add_child(_label(str(selected.get("contractLabel", "Contrat")), 14))
	profile.add_child(_label("%s minutes · %s apparitions" % [_number(selected.get("minutes", 0)), _number(selected.get("appearances", 0))], 12, Art.MUTED))
	profile.add_child(_label("Portrait décoratif fictif généré par IA", 10, Art.MUTED))
	profile.add_child(_button("11 COMPÉTENCES & CONTRAT", func(): _player_details(selected)))
	profile.add_child(_button("COMPOSITION AUTOMATIQUE DU XV", func(): _command("auto_lineup")))

func _match_page() -> void:
	match_page = _v(12)
	match_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(match_page)
	var banner := _panel()
	match_page.add_child(banner)
	var score_row := _h(18)
	banner.get_child(0).add_child(score_row)
	match_clock = _label("AVANT-MATCH", 22, Color("e6c488"), true)
	score_row.add_child(match_clock)
	match_score = _label("Votre prochain rendez-vous", 28, Art.INK, true)
	match_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_row.add_child(match_score)
	pause_button = _button("COUP D'ENVOI", _match_action, true)
	score_row.add_child(pause_button)
	var center := _h(12)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_page.add_child(center)
	var field := _v(8)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(field)
	var vp_container := SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.custom_minimum_size = Vector2(600, 340)
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_child(vp_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1000, 620)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	vp_container.add_child(viewport)
	match_view = load("res://match_view.gd").new()
	viewport.add_child(match_view)
	var controls := _h(8)
	field.add_child(controls)
	controls.add_child(_button("CAMÉRA TV", func(): match_view.set_camera("tv")))
	controls.add_child(_button("VUE TACTIQUE", func(): match_view.set_camera("tactical")))
	var speed := OptionButton.new()
	for s in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: speed.add_item(s)
	speed.select(maxi(0, [1, 4, 12].find(tick_steps)))
	speed.item_selected.connect(func(i: int): tick_steps = [1, 4, 12][i])
	controls.add_child(speed)
	var info := _panel()
	info.custom_minimum_size.x = 230
	center.add_child(info)
	var details := _v(14)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.get_child(0).add_child(detail_scroll)
	details.custom_minimum_size.x = 190
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(details)
	details.add_child(_label("LE DIRECT", 22, Art.INK, true))
	match_stats = _label("", 13, Art.MUTED)
	details.add_child(match_stats)
	details.add_child(_rule())
	match_events = _label("", 13)
	match_events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match_events.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(match_events)
	match_finish = _button("VALIDER LA JOURNÉE  →", func(): _command("finish_round"))
	match_page.add_child(match_finish)
	match_page.add_child(_label("Simulation réelle · scène et animations de prototype · enceinte générique", 11, Art.MUTED))
	_update_match()

func _update_match() -> void:
	var live: Dictionary = model.get("live", {}) if model.get("live") != null else {}
	if live.is_empty():
		if is_instance_valid(match_view): match_view.apply_frame({})
		match_clock.text = "AVANT-MATCH"
		var next: Dictionary = model.get("next", {}) if model.get("next") != null else {}
		var ended: bool = model.get("meta", {}).get("phase") == "ended"
		match_score.text = "%s  /  %s" % [_abbr(next.get("home", {})), _abbr(next.get("away", {}))]
		pause_button.text = "COUP D'ENVOI"
		pause_button.disabled = ended or next.is_empty()
		match_events.text = "Votre XV et votre adversaire sont prêts.\n\nLe coup d'envoi lance le moteur de match existant."
		match_stats.text = "LES DEUX CAMÉRAS SONT DISPONIBLES PENDANT LE MATCH."
		match_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match_finish.disabled = ended or not next.is_empty()
		if ended:
			match_clock.text = "SAISON TERMINÉE"
			match_score.text = "Fin de la carrière de prototype"
			match_events.text = "La saison suivante n'est pas disponible dans cette étape du prototype."
		elif next.is_empty():
			match_clock.text = "SANS RENCONTRE"
			match_score.text = "Aucune affiche pour votre club à ce tour"
			match_events.text = "Validez la journée pour poursuivre le calendrier."
		return
	var score: Array = live.get("score", [0, 0])
	var teams: Array = live.get("teams", [{}, {}])
	match_clock.text = "%s min" % _number(live.get("minute", 0))
	if live.get("finished", false): match_clock.text = "TERMINÉ"
	elif live.get("halftime", false): match_clock.text = "MI-TEMPS"
	match_score.text = "%s    %s — %s    %s" % [_abbr(teams[0]), _number(score[0]), _number(score[1]), _abbr(teams[1])]
	pause_button.text = "TERMINÉ" if live.get("finished", false) else ("REPRENDRE" if live.get("paused", false) else "PAUSE")
	pause_button.disabled = live.get("finished", false)
	match_finish.disabled = not live.get("finished", false)
	var tries: Array = live.get("tries", [0, 0])
	var stat_lines: Array[String] = ["ESSAIS  %s — %s" % [_number(tries[0]), _number(tries[1])]]
	for stat in live.get("statsRows", []).slice(0, 6):
		stat_lines.append("%s\n%s — %s" % [str(stat.get("label", "")), _number(stat.get("home", "—")), _number(stat.get("away", "—"))])
	match_stats.text = "\n\n".join(stat_lines)
	var events: Array = live.get("events", [])
	var lines: Array[String] = []
	for e in events.slice(maxi(0, events.size() - 2)):
		if e is Dictionary: lines.append("%s' · %s" % [_number(e.get("min", "")), _present_text(str(e.get("text", e.get("message", ""))))])
		else: lines.append(str(e))
	match_events.text = "\n\n".join(lines)
	if is_instance_valid(match_view): match_view.apply_frame(live)

func _match_action() -> void:
	var live: Dictionary = model.get("live", {}) if model.get("live") != null else {}
	if live.is_empty():
		if model.get("next") != null and model.get("meta", {}).get("phase") != "ended": _command("begin_match")
	else: _command("pause", {"paused": not live.get("paused", false)})

func _live_tick() -> void:
	if waiting or model.is_empty(): return
	var live: Dictionary = model.get("live", {}) if model.get("live") != null else {}
	if not live.is_empty() and not live.get("paused", false) and not live.get("finished", false):
		_command("tick", {"steps": tick_steps})

func _training() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "La séance du groupe"
	dialog.dialog_text = "Choisissez une charge réelle pour cette semaine."
	dialog.get_ok_button().text = "FERMER"
	for pair in [["Repos", "repos"], ["Normal", "normal"], ["Intense", "intense"]]:
		var b := dialog.add_button(pair[0], false, pair[1])
		b.disabled = bool(model.get("meta", {}).get("trained", false))
	dialog.custom_action.connect(func(action: String): dialog.hide(); dialog.queue_free(); _command("train", {"mode": action}))
	add_child(dialog)
	dialog.popup_centered(Vector2i(540, 160))

func _player_details(player: Dictionary) -> void:
	var lines: Array[String] = []
	var attrs: Dictionary = player.get("attributes", {})
	for pair in [["scrum", "Mêlée"], ["lineout", "Touche"], ["tackle", "Plaquage"], ["speed", "Vitesse"], ["pass", "Passe"], ["kick", "Jeu au pied"], ["goal", "But"], ["mental", "Mental"], ["discipline", "Discipline"], ["stamina", "Endurance"], ["power", "Puissance"]]:
		lines.append("%s : %s / 100" % [pair[1], _number(attrs.get(pair[0], "—"))])
	lines.append("\n%s · Salaire : %s €" % [str(player.get("contractLabel", "")), str(player.get("salary", "—"))])
	lines.append("Charge physique : %s / 100 · Blessure : %s semaine(s)" % [str(player.get("physicalLoad", 0)), str(player.get("injury", 0))])
	var d := AcceptDialog.new()
	d.title = str(player.get("name", "Fiche joueur"))
	d.dialog_text = "\n".join(lines)
	add_child(d)
	d.popup_centered(Vector2i(570, 420))

func _confirm_career(id: int) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Nouvelle carrière de prototype"
	d.dialog_text = "Remplacer uniquement la carrière de ce prototype par %s ?\nVos autres carrières restent dans leur profil habituel." % catalogue[id].name
	d.get_ok_button().text = "COMMENCER"
	d.confirmed.connect(func(): route = "Bureau"; _command("new_career", {"club": id}); d.queue_free())
	add_child(d)
	d.popup_centered(Vector2i(580, 160))

func _save_menu() -> void:
	var d := AcceptDialog.new()
	d.title = "Votre carrière de prototype"
	d.dialog_text = "Le profil de ce prototype est indépendant de vos autres carrières.\nDossier : " + _profile_path()
	d.add_button("Exporter JSON", false, "export")
	d.add_button("Importer JSON", false, "import")
	d.custom_action.connect(func(action: String):
		d.hide()
		d.queue_free()
		import_mode = action == "import"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if import_mode else FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.current_file = "Cadrage-Prototype.json" if not import_mode else ""
		file_dialog.popup_centered_ratio(0.7))
	add_child(d)
	d.popup_centered(Vector2i(560, 160))

func _file_selected(path: String) -> void:
	if waiting:
		_failed("Une action est en cours. Réessayez après sa réponse.")
		return
	if import_mode:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_failed("Impossible de lire cette carrière : " + error_string(FileAccess.get_open_error()))
			return
		if file.get_length() > NativeEngineBridge.IMPORT_LIMIT_BYTES:
			file.close()
			_failed("Fichier trop volumineux (5 Mio UTF-8 maximum).")
			return
		var text := file.get_as_text()
		file.close()
		_command("import", {"text": text})
	else:
		export_path = path
		_command("export")

func _credits() -> void:
	var d := AcceptDialog.new()
	d.title = "Crédits & licences"
	d.dialog_text = "Photos : Wikimedia Commons (CC0, CC BY, CC BY-SA) et IGN (Licence Ouverte2).\nAuteurs, liens, licences et modifications : dossier Licences de la distribution.\n\nModèle : Quaternius, CC0. Portraits décoratifs fictifs générés par IA.\nDM Sans et Barlow Condensed : SIL Open Font License.\nGodot : licence MIT. Runtime Node : licences incluses.\n\nLes noms de clubs sont des identités de jeu originales. Les photos sont des archives."
	add_child(d)
	d.popup_centered(Vector2i(760, 300))

func _close() -> void:
	if closing: return
	closing = true
	timer.stop()
	status.text = "Fermeture de la simulation…"
	if is_instance_valid(bridge):
		bridge.stop()
		var deadline := Time.get_ticks_msec() + 2300
		while bridge.child_pid > 0 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
	get_tree().quit()

func _identity(club: Dictionary) -> Dictionary:
	return club.get("presentation", club)

func _number(value: Variant) -> String:
	if value is float or value is int: return str(int(value))
	return str(value)

func _present_text(value: String) -> String:
	for club in model.get("league", []):
		var presentation: Dictionary = _identity(club)
		value = value.replace(str(club.get("name", "")), str(presentation.get("name", club.get("name", ""))))
		var native_abbr := str(club.get("abbr", ""))
		if not native_abbr.is_empty():
			var pattern := RegEx.new()
			if pattern.compile("\\b" + native_abbr + "\\b") == OK:
				value = pattern.sub(value, str(presentation.get("abbr", native_abbr)), true)
	return value

func _abbr(club: Dictionary) -> String:
	return str(_identity(club).get("abbr", club.get("abbr", "XV")))

func _label(text: String, font_size: int = 14, color: Color = Art.INK, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if display: l.add_theme_font_override("font", Art.DISPLAY)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", 12)
	if primary:
		b.add_theme_stylebox_override("normal", Art.box(Art.INK, 4))
		for key in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(key, Art.BG)
		b.add_theme_stylebox_override("hover", Art.box(Color("d3dace"), 4))
		b.add_theme_stylebox_override("pressed", Art.box(Color("b9c7b9"), 4))
	b.pressed.connect(callback)
	return b

func _v(gap: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v

func _h(gap: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h

func _panel(color: Color = Art.PANEL, padding: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.box(color, 6, Art.LINE))
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, padding - 12)
	p.add_child(margin)
	return p

func _card_column(parent: Control, ratio: float) -> VBoxContainer:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	parent.add_child(p)
	var v := _v(12)
	p.get_child(0).add_child(v)
	return v

func _section(title: String, caption: String) -> VBoxContainer:
	var v := _v(2)
	v.add_child(_label(title, 22, Art.INK, true))
	v.add_child(_label(caption, 11, Art.MUTED))
	return v

func _metric(value: String, caption: String, color: Color = Art.INK) -> VBoxContainer:
	var v := _v(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_label(value, 40, color, true))
	v.add_child(_label(caption, 10, Art.MUTED))
	return v

func _rule() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = Art.LINE
	return s

func _crest(initials: String, color: Color, width: int) -> Control:
	var w := Widget.new()
	w.initials = initials
	w.accent = color
	w.custom_minimum_size = Vector2(width, width)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

func _portrait(index: int, width: int) -> TextureRect:
	var r := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/editorial/portraits-%d.webp" % (index / 16))
	var size := atlas.atlas.get_size() / 4.0
	atlas.region = Rect2(Vector2(index % 4, (index % 16) / 4) * size, size)
	r.texture = atlas
	r.custom_minimum_size = Vector2(width, width)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.tooltip_text = "Portrait décoratif fictif généré par IA"
	return r

func _photo_card(slug: String, kind: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", Art.box(Art.PANEL, 6))
	var base := Control.new()
	base.custom_minimum_size.y = 250
	panel.add_child(base)
	var image := TextureRect.new()
	image.texture = load("res://assets/club-atlas/%s-%s.webp" % [slug, kind])
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(image)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.05, 0.72))
	gradient.set_color(1, Color(0.02, 0.04, 0.05, 0.96))
	gradient.add_point(0.18, Color(0.02, 0.04, 0.05, 0.60))
	gradient.add_point(0.42, Color(0.02, 0.04, 0.05, 0.13))
	gradient.add_point(0.68, Color(0.02, 0.04, 0.05, 0.40))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	base.add_child(margin)
	var content := _v(10)
	margin.add_child(content)
	panel.set_meta("content", content)
	return panel
