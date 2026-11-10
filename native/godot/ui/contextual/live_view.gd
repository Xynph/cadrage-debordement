extends Control
const S = preload("res://ui/contextual/skin.gd")
var director: Node
var app: Control
var stage: Node3D
var model: Dictionary = {}
var clock: Label
var score: Label
var home: Label
var away: Label
var play: Button
var finish: Button
var events: Label
var drawer: PanelContainer
var drawer_body: VBoxContainer
var drawer_tab := ""
var selected_slot := -1
var _drawer_key := ""
var _camera_controls: Array[Button] = []
var _applied_camera := ""
var _applied_quality := ""

func _ready() -> void:
	name = "ContextualLiveMatch"
	app = director.app
	var container := SubViewportContainer.new()
	container.name = "LiveMatchViewport"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(container)
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	stage = load("res://match_view.gd").new()
	if stage.has_method("set_club_identity"): stage.set_club_identity(app.model.get("club", {}))
	viewport.add_child(stage)
	var frame := S.frame(self, 18)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scoreboard := S.panel(frame, 10)
	var banner := S.G.h(12)
	scoreboard.add_child(banner)
	clock = S.label("", 24, S.GOLD)
	clock.custom_minimum_size.x = 125
	banner.add_child(clock)
	home = S.label("", 22)
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	S.G.fill(home)
	banner.add_child(home)
	score = S.label("", 32, S.GOLD)
	score.custom_minimum_size.x = 145
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(score)
	away = S.label("", 22)
	S.G.fill(away)
	banner.add_child(away)
	play = S.button("PAUSE", _pause)
	banner.add_child(play)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(space, true)
	frame.add_child(space)
	var event_row := S.G.h(10)
	frame.add_child(event_row)
	var event_panel := S.panel(event_row, 10)
	event_panel.get_parent().custom_minimum_size.x = 480
	event_panel.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	events = S.wrap("", 14, S.TEXT)
	event_panel.add_child(events)
	event_row.add_child(S.G.spacer())
	var controls := S.panel(frame, 8)
	var bar := S.G.h(7)
	controls.add_child(bar)
	for title in ["Tactique", "Banc", "Stats"]:
		bar.add_child(S.button(title.to_upper(), func(): _toggle_drawer(title)))
	for pair in [["tv", "TV"], ["tactical", "TACTIQUE"], ["action", "CONTACT"]]:
		var button := S.button(pair[1], func(): _choose_camera(pair[0]))
		_camera_controls.append(button)
		bar.add_child(button)
	var cadence := OptionButton.new()
	cadence.custom_minimum_size.y = 38
	for text in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: cadence.add_item(text)
	cadence.select(maxi(0, [1, 4, 12].find(app.tick_steps)))
	cadence.item_selected.connect(func(index: int): app.tick_steps = [1, 4, 12][index]; stage.set_live_cadence(app.tick_steps))
	cadence.set_meta("contextual_enabled", true)
	bar.add_child(cadence)
	bar.add_child(S.G.spacer())
	bar.add_child(S.button("CONFIER LA FIN À L’ADJOINT", func(): app.confirm("Confier la fin du match", "L’adjoint prend en charge la fin de cette rencontre. Confirmer la délégation ?", func(): director.command("delegate"))))
	finish = S.button("VALIDER LA JOURNÉE  →", func(): director.command("finish_round"), false, true)
	bar.add_child(finish)
	drawer = PanelContainer.new()
	drawer.name = "MatchDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	drawer.offset_left = -450
	drawer.offset_right = -18
	drawer.offset_top = 100
	drawer.anchor_bottom = 1
	drawer.offset_bottom = -90
	drawer.add_theme_stylebox_override("panel", S.G.T.box(S.PANEL, 5, Color("68785a")))
	add_child(drawer)
	var drawer_margin := S.G.margin(14)
	drawer.add_child(drawer_margin)
	var drawer_column := S.G.v(8)
	drawer_margin.add_child(drawer_column)
	drawer_column.add_child(S.button("FERMER  ×", func(): drawer_tab = ""; drawer.hide()))
	drawer_body = S.G.scroll(drawer_column)
	S.G.fill(drawer_body.get_parent(), true)
	drawer.hide()
	app.match_view = stage
	app.pause_button = play
	app.match_finish = finish
	app.match_clock = clock
	apply_preferences()

func update_frame(value: Dictionary) -> void:
	model = value
	if not is_node_ready(): return
	var live := _live()
	var teams: Array = live.get("teams", [{}, {}])
	if teams.size() >= 2:
		home.text = S.G.club_name(teams[0])
		away.text = S.G.club_name(teams[1])
	var scores: Array = live.get("score", [0, 0])
	score.text = "%s — %s" % [str(scores[0]), str(scores[1])]
	clock.text = "%s min" % str(live.get("minute", 0))
	if live.get("finished", false): clock.text = "TERMINÉ"
	elif live.get("atBreak", false): clock.text = "MI-TEMPS"
	play.text = "REPRENDRE" if live.get("paused", false) else "PAUSE"
	play.set_meta("contextual_enabled", not live.get("finished", false))
	finish.visible = live.get("finished", false)
	finish.set_meta("contextual_enabled", live.get("finished", false))
	stage.set_live_cadence(app.tick_steps)
	if stage.has_method("set_club_identity"): stage.set_club_identity(model.get("club", {}))
	stage.apply_frame(live)
	var lines := PackedStringArray()
	var rows: Array = live.get("events", [])
	for event: Variant in rows.slice(maxi(0, rows.size() - 2)):
		if event is Dictionary: lines.append("%s'  %s" % [str(event.get("min", "")), str(event.get("text", ""))])
		else: lines.append(str(event))
	events.text = "\n".join(lines)
	events.get_parent().get_parent().visible = not lines.is_empty()
	_update_drawer()
	apply_preferences()
	director._refresh_controls()

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func _pause() -> void:
	var live := _live()
	director.command("pause", {"paused":not live.get("paused", false)})

func _choose_camera(mode: String) -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_camera(mode); return
	if not preferences.set_value("camera", mode): app.notice("Réglage non enregistré", preferences.last_error)
	apply_preferences()

func apply_preferences() -> void:
	if not is_instance_valid(stage): return
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: return
	var camera: String = preferences.effective_camera()
	var quality: String = str(preferences.data.quality)
	stage.set_stadium_evening(preferences.data.stadium == "evening")
	stage.set_action_motion(not bool(preferences.data.reduced_motion))
	if camera != _applied_camera:
		_applied_camera = camera
		stage.set_camera(camera)
	if quality != _applied_quality:
		_applied_quality = quality
		stage.set_quality(quality)
	for button: Button in _camera_controls:
		button.set_meta("contextual_enabled", not bool(preferences.data.reduced_motion))
		button.tooltip_text = "Mode calme : caméra tactique fixe." if preferences.data.reduced_motion else "Caméra conservée pour les prochains matchs."

func _toggle_drawer(title: String) -> void:
	if title == drawer_tab and drawer.visible:
		drawer_tab = ""
		drawer.hide()
		return
	drawer_tab = title
	drawer.show()
	_drawer_key = ""
	_update_drawer()

func _update_drawer() -> void:
	if drawer_tab.is_empty(): return
	var live := _live()
	var key := JSON.stringify([drawer_tab, selected_slot, live.get("paused"), live.get("finished"), live.get("lineup"), live.get("reserves"), live.get("substitutions"), live.get("statsRows") if drawer_tab == "Stats" else model.get("tactics", {})])
	if key == _drawer_key: return
	_drawer_key = key
	S.clear(drawer_body)
	drawer_body.add_child(S.label(drawer_tab, 23, S.GOLD))
	match drawer_tab:
		"Banc": _bench(live)
		"Stats":
			for stat: Dictionary in live.get("statsRows", []):
				drawer_body.add_child(S.label(str(stat.get("label", "")), 13))
				drawer_body.add_child(S.label("%s    —    %s" % [str(stat.get("home", "")), str(stat.get("away", ""))], 23, S.GOLD))
			if live.get("statsRows", []).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique disponible pour cette rencontre.", 14))
		"Tactique": _tactics(live)
	director._refresh_controls()

func _tactics(live: Dictionary) -> void:
	var allowed: bool = live.get("paused", false) and not live.get("finished", false)
	if not allowed: drawer_body.add_child(S.wrap("Mettez le match en pause pour modifier vos consignes.", 14, S.GOLD))
	var tactics: Dictionary = model.get("tactics", {})
	for pair in [["attack", "attacks", "Avec le ballon"], ["defense", "defenses", "Sans le ballon"]]:
		drawer_body.add_child(S.label(pair[2], 18, S.GOLD))
		for option: Dictionary in tactics.get(pair[1], []):
			var button := S.button(str(option.get("label", "")), func():
				var current: Dictionary = app.model.get("tactics", {})
				var payload := {"attack":current.get("attack", "equilibre"), "defense":current.get("defense", "equilibre")}
				payload[pair[0]] = option.get("id")
				director.command("set_tactics", payload), allowed)
			if tactics.get(pair[0]) == option.get("id"): S.selected(button, S.GOLD)
			drawer_body.add_child(button)
			drawer_body.add_child(S.wrap(str(option.get("description", "")), 13))

func _bench(live: Dictionary) -> void:
	if not live.get("paused", false): drawer_body.add_child(S.wrap("Mettez le match en pause pour effectuer un changement.", 14, S.GOLD))
	var players: Array = live.get("lineup", [])
	for slot in players.size():
		var player: Variant = players[slot]
		var title := str(player.get("name", "Joueur")) if player is Dictionary else "Poste vacant"
		var button := S.button("%d · %s" % [slot + 1, title], func(): selected_slot = slot; _drawer_key = ""; _update_drawer())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if selected_slot == slot: S.selected(button, S.GOLD)
		drawer_body.add_child(button)
	if selected_slot < 0 or selected_slot >= players.size(): return
	var allowed: Array = []
	for option: Dictionary in live.get("substitutions", []):
		if option.get("slot") == selected_slot: allowed = option.get("inIds", [])
	var out: Variant = players[selected_slot]
	var out_id: Variant = out.get("id") if out is Dictionary else null
	drawer_body.add_child(S.label("Faire entrer", 18, S.GOLD))
	for player: Dictionary in live.get("reserves", []):
		var button := S.button(str(player.get("name", "Joueur")), func(): director.command("substitute", {"slot":selected_slot, "outId":out_id, "inId":player.get("id")}), player.get("id") in allowed and live.get("paused", false) and not live.get("finished", false))
		drawer_body.add_child(button)
