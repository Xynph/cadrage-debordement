extends Control
const S = preload("res://ui/contextual/skin.gd")
const TempsForts = preload("res://ui/contextual/match_temps_forts.gd")
var director: Node
## Régie du match en temps forts (mode de base ; absente avec CD_MATCH_TEMPS_FORTS=0).
var regie: Node
var _cadence: OptionButton
var _niveau: OptionButton
var _niveaux: Array = []
var _reglages_temps_forts := false
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
var journal: VBoxContainer
var _journal_shell: PanelContainer
var _bench_feedback: VBoxContainer
var _bench_context: Label
var _bench_status: Label
var drawer_tab := ""
var selected_slot := -1
var _drawer_key := ""
var _bench_focus_key := ""
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
	for title in ["Tactique", "Banc", "Stats", "Journal"]:
		bar.add_child(S.button(title.to_upper(), func(): _toggle_drawer(title)))
	for pair in [["tv", "TV"], ["tactical", "VUE DE DESSUS"], ["action", "CONTACT"]]:
		var button := S.button(pair[1], func(): _choose_camera(pair[0]))
		_camera_controls.append(button)
		bar.add_child(button)
	_cadence = OptionButton.new()
	_cadence.custom_minimum_size.y = 38
	for text in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: _cadence.add_item(text)
	_cadence.select(maxi(0, [1, 4, 12].find(app.tick_steps)))
	_cadence.item_selected.connect(_choisir_cadence)
	_cadence.set_meta("contextual_enabled", true)
	bar.add_child(_cadence)
	# Ce que le match montre, des temps forts choisis au match complet : visible en temps forts.
	_niveau = OptionButton.new()
	_niveau.name = "MatchLevel"
	_niveau.custom_minimum_size.y = 38
	_niveau.tooltip_text = "Ce que le match montre : des temps forts choisis au match complet. Conservé pour les prochains matchs."
	_niveau.set_meta("contextual_enabled", true)
	_niveau.item_selected.connect(func(index: int): if regie != null and index >= 0 and index < _niveaux.size(): regie.choisir_niveau(str(_niveaux[index].get("id", ""))))
	_niveau.hide()
	bar.add_child(_niveau)
	if TempsForts.enabled():
		regie = TempsForts.new()
		add_child(regie)
		regie.setup(self, container, viewport, space)
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
	drawer_column.add_child(S.button("FERMER  ×", _fermer_tiroir))
	_bench_feedback = S.G.v(2)
	_bench_context = S.wrap("", 14, S.TEXT)
	_bench_context.name = "MatchBenchContext"
	_bench_status = S.wrap("", 13, S.GOLD)
	_bench_status.name = "MatchBenchStatus"
	_bench_feedback.add_child(_bench_context)
	_bench_feedback.add_child(_bench_status)
	_bench_feedback.hide()
	drawer_column.add_child(_bench_feedback)
	drawer_body = S.G.scroll(drawer_column)
	S.G.fill(drawer_body.get_parent(), true)
	_journal_shell = PanelContainer.new()
	_journal_shell.add_theme_stylebox_override("panel", S.G.T.box(Color("e8dfce"), 3, S.G.LINE))
	S.G.fill(_journal_shell, true)
	drawer_column.add_child(_journal_shell)
	var journal_margin := S.G.margin(8)
	_journal_shell.add_child(journal_margin)
	journal = preload("res://ui/match_journal.gd").new()
	journal.setup(app)
	journal_margin.add_child(journal)
	_journal_shell.hide()
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
	score.text = "%d — %d" % [int(scores[0]), int(scores[1])]
	clock.text = "%d min" % int(live.get("minute", 0))
	if live.get("finished", false): clock.text = "TERMINÉ"
	elif live.get("atBreak", false): clock.text = "MI-TEMPS"
	play.text = "REPRENDRE" if live.get("paused", false) else "PAUSE"
	# Une causerie retenue par un temps fort : la reprise passera par elle.
	play.set_meta("contextual_enabled", not live.get("finished", false) and director._talk().is_empty())
	finish.visible = live.get("finished", false)
	finish.set_meta("contextual_enabled", live.get("finished", false))
	if stage.has_method("set_club_identity"): stage.set_club_identity(model.get("club", {}))
	if regie == null:
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
	var lines := PackedStringArray()
	var rows: Array = live.get("events", [])
	for event: Variant in rows.slice(maxi(0, rows.size() - 2)):
		if event is Dictionary: lines.append("%s'  %s" % [str(event.get("min", "")), str(event.get("text", ""))])
		else: lines.append(str(event))
	events.text = "\n".join(lines)
	events.get_parent().get_parent().visible = not lines.is_empty()
	if regie != null:
		regie.receive(model, live)
		if live.get("direct") is Dictionary: montrer_reglages_temps_forts(live.direct, regie)
	_update_drawer()
	apply_preferences()
	director._refresh_controls()

func _choisir_cadence(index: int) -> void:
	if _reglages_temps_forts:
		regie.choisir_horloge(["lente", "normale", "rapide", "eclair"][index])
		return
	app.tick_steps = [1, 4, 12][index]
	stage.set_live_cadence(app.tick_steps)

## Appelée par la régie quand le moteur projette les temps forts : l'horloge de l'écran
## intermédiaire remplace la cadence du direct, et le niveau se choisit dans la barre.
func montrer_reglages_temps_forts(direct: Dictionary, source: Node) -> void:
	if not _reglages_temps_forts:
		_reglages_temps_forts = true
		_cadence.clear()
		for text in ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"]: _cadence.add_item(text)
		_cadence.select(maxi(0, ["lente", "normale", "rapide", "eclair"].find(source.horloge)))
		_cadence.tooltip_text = "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle."
	var niveaux: Array = direct.get("niveaux", [])
	if JSON.stringify(niveaux) != JSON.stringify(_niveaux):
		_niveaux = niveaux.duplicate(true)
		_niveau.clear()
		for item: Dictionary in _niveaux: _niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == source.niveau and _niveau.selected != index: _niveau.select(index)
	_niveau.visible = not _niveaux.is_empty()

## Vrai tant qu'un temps fort reste à montrer : la causerie attend la fin de l'action.
func retient_la_causerie(live: Dictionary) -> bool:
	return regie != null and regie.retient(live)

## Vrai quand la régie des temps forts cadence elle-même le match.
func temps_forts_actifs() -> bool:
	return regie != null and _live().get("direct") is Dictionary

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
		# Preferences can change without a worker/waiting transition.
		button.disabled = bool(app.waiting) or bool(preferences.data.reduced_motion)
		button.tooltip_text = "Mode calme : caméra tactique fixe." if preferences.data.reduced_motion else "Caméra conservée pour les prochains matchs."

func _toggle_drawer(title: String) -> void:
	if drawer_tab == "Banc":
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and drawer_body.is_ancestor_of(focused):
			_bench_focus_key = str(focused.get_meta("match_bench_focus", ""))
	if title == drawer_tab and drawer.visible:
		_fermer_tiroir()
		return
	drawer_tab = title
	drawer.show()
	_drawer_key = ""
	_update_drawer()
	# Entre deux temps forts : la tactique ou le banc ouverts mettent le match en pause (les
	# changements ne se font qu'en pause) ; le prochain temps fort attend leur fermeture.
	if regie != null:
		if title in ["Tactique", "Banc"]: regie.tiroir_ouvert()
		else: regie.tiroir_ferme()

func _fermer_tiroir() -> void:
	drawer_tab = ""
	drawer.hide()
	if regie != null: regie.tiroir_ferme()

func _update_drawer() -> void:
	_bench_feedback.visible = drawer_tab == "Banc" and drawer.visible
	_journal_shell.visible = drawer_tab == "Journal"
	drawer_body.get_parent().visible = drawer_tab != "Journal"
	if drawer_tab.is_empty(): return
	var live := _live()
	if drawer_tab == "Journal":
		journal.update_frame(regie.montre(live) if regie != null else live)
		return
	var presence: Array = [drawer_tab, selected_slot, live.get("paused"), live.get("finished")]
	match drawer_tab:
		"Banc": presence.append(_bench_presence(live))
		"Stats": presence.append(live.get("statsRows", []))
		"Tactique":
			presence.append(model.get("tactics", {}))
			presence.append(model.get("decisions", {}).get("liveAdvice"))
			presence.append(model.get("decisions", {}).get("report"))
	var key := JSON.stringify(presence)
	if key == _drawer_key: return
	_drawer_key = key
	var bench_focus := _bench_focus_key
	if drawer_tab == "Banc":
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and drawer_body.is_ancestor_of(focused):
			bench_focus = str(focused.get_meta("match_bench_focus", ""))
			_bench_focus_key = bench_focus
	S.clear(drawer_body)
	drawer_body.add_child(S.label(drawer_tab, 23, S.GOLD))
	match drawer_tab:
		"Banc":
			_bench(live)
			if not bench_focus.is_empty(): _restore_bench_focus(bench_focus)
		"Stats":
			for stat: Dictionary in live.get("statsRows", []):
				drawer_body.add_child(S.label(str(stat.get("label", "")), 13))
				drawer_body.add_child(S.label("%s    —    %s" % [str(stat.get("home", "")), str(stat.get("away", ""))], 23, S.GOLD))
			if live.get("statsRows", []).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique disponible pour cette rencontre.", 14))
		"Tactique": _tactics(live)
	director._refresh_controls()

func _bench_presence(live: Dictionary) -> Array:
	# Condition and spatial presentation change on every tick. Rebuild controls
	# only when their identities, availability or substitution permissions change.
	var presence: Array = []
	for group in [live.get("lineup", []), live.get("reserves", [])]:
		var players: Array = []
		for player: Variant in group:
			players.append([player.get("id"), player.get("name"), player.get("pos"), player.get("injury", 0)] if player is Dictionary else null)
		presence.append(players)
	var permissions: Array = []
	for option: Dictionary in live.get("substitutions", []):
		permissions.append([option.get("slot"), option.get("outId"), option.get("label", ""), option.get("inIds", [])])
	presence.append(permissions)
	return presence

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
	var notes := S.G.panel(drawer_body)
	preload("res://ui/decision_views.gd").match_notes(app, notes, model)

func _restore_bench_focus(previous_focus: String) -> void:
	var target: Button
	var fallback: Button
	var selected_key := "sortant:%d" % selected_slot
	for child in drawer_body.get_children():
		if not child is Button or child.disabled: continue
		var key := str(child.get_meta("match_bench_focus", ""))
		if key == previous_focus:
			target = child
			break
		if key == selected_key: fallback = child
	if target == null: target = fallback
	if target == null: return
	await get_tree().process_frame
	if not is_instance_valid(target) or not target.is_visible_in_tree(): return
	target.grab_focus()
	_bench_focus_key = str(target.get_meta("match_bench_focus", ""))
	(drawer_body.get_parent() as ScrollContainer).ensure_control_visible(target)

func _update_bench_feedback(live: Dictionary, selected: bool, out: Variant, choice: Dictionary, options: Array) -> void:
	_bench_context.visible = selected
	if selected:
		var position := str(choice.get("label", ""))
		var player_name := str(out.get("name", "Joueur")) if out is Dictionary else "Poste vacant"
		_bench_context.text = "%d · %s" % [selected_slot + 1, player_name]
		if not position.is_empty(): _bench_context.text = "%d · %s · %s" % [selected_slot + 1, position, player_name]
	if live.get("finished", false):
		_bench_status.text = "Match terminé. Les remplacements sont fermés."
	elif not live.get("paused", false):
		_bench_status.text = "Mettez le match en pause pour effectuer un remplacement."
	elif not selected:
		_bench_status.text = "Sélectionnez le joueur à remplacer."
	elif choice.get("inIds", []).is_empty():
		var other_choice := options.any(func(option: Dictionary): return option.get("slot") != selected_slot and not option.get("inIds", []).is_empty())
		_bench_status.text = "Aucun remplaçant autorisé pour ce poste. " + ("Sélectionnez un autre joueur." if other_choice else "Reprenez le match pour continuer.")
	else:
		_bench_status.text = "Choisissez un remplaçant dans « Faire entrer » sous le XV."
	_bench_feedback.visible = drawer_tab == "Banc" and drawer.visible

func _bench(live: Dictionary) -> void:
	var players: Array = live.get("lineup", [])
	var options: Array = live.get("substitutions", [])
	var slot_to_replace := selected_slot
	var selected := slot_to_replace >= 0 and slot_to_replace < players.size()
	var out: Variant = players[slot_to_replace] if selected else null
	var out_id: Variant = out.get("id") if out is Dictionary else null
	var choice: Dictionary = {}
	for option: Dictionary in options:
		if option.get("slot") == slot_to_replace and option.get("outId") == out_id:
			choice = option
			break
	_update_bench_feedback(live, selected, out, choice, options)
	for slot in players.size():
		var player: Variant = players[slot]
		var title := str(player.get("name", "Joueur")) if player is Dictionary else "Poste vacant"
		var button := S.button("%d · %s" % [slot + 1, title], func(): selected_slot = slot; _drawer_key = ""; _update_drawer())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = button.text
		button.set_meta("match_bench_focus", "sortant:%d" % slot)
		for option: Dictionary in options:
			if option.get("slot") == slot: button.tooltip_text = "%s\n%d · %s" % [title, slot + 1, option.get("label", "")]
		if selected_slot == slot: S.selected(button, S.GOLD)
		drawer_body.add_child(button)
	if not selected: return
	var allowed: Array = choice.get("inIds", [])
	drawer_body.add_child(S.label("Faire entrer", 18, S.GOLD))
	for player: Dictionary in live.get("reserves", []):
		var button := S.button(str(player.get("name", "Joueur")), func(): director.command("substitute", {"slot":slot_to_replace, "outId":out_id, "inId":player.get("id")}), player.get("id") in allowed and live.get("paused", false) and not live.get("finished", false))
		button.set_meta("match_bench_focus", "entrant:%s" % str(player.get("id")))
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = str(player.get("name", "Joueur"))
		drawer_body.add_child(button)
