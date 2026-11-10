extends VBoxContainer
const G = preload("res://ui/carnet_skin.gd")
var app: Control
var stage: Node3D
var clock: Label
var score: Label
var home: Label
var away: Label
var play: Button
var finish: Button
var events: Label
var stats: Label
var journal: VBoxContainer
var side: VBoxContainer
var _bench_feedback: VBoxContainer
var _bench_context: Label
var _bench_status: Label
var tab := "Direct"
var selected_slot := -1
var presence_key := ""
var model: Dictionary = {}
var _quality_control: OptionButton
var _camera_controls: Array[Button] = []
var _applied_camera := ""
var _applied_quality := ""
var _score_sheet: PanelContainer
var _notebook: PanelContainer
var _bottom_sheet: PanelContainer
var _bottom_controls: HBoxContainer
var _caption: Label
var _tab_controls: Array[Button] = []
var _styled_tab := ""

func _ready() -> void:
	name="CarnetMatch"
	tab = str(app.management_ui.get("match_journal_tab", "Direct"))
	theme=G.T.paper()
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var score_sheet:=G.panel(self)
	_score_sheet = score_sheet.get_parent()
	var scoreboard_style := G.T.box(Color("222a29"), 3, Color("586354"))
	scoreboard_style.border_width_bottom = 3
	scoreboard_style.border_color = app.accent
	score_sheet.get_parent().add_theme_stylebox_override("panel", scoreboard_style)
	var banner:=G.h(16)
	score_sheet.add_child(banner)
	clock=G.label("AVANT-MATCH",24,Color("ddbd80"),true)
	clock.custom_minimum_size.x=120
	banner.add_child(clock)
	home=G.label("",22,G.WHITE,true)
	home.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	home.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	G.fill(home)
	banner.add_child(home)
	score=G.label("— / —",42,G.WHITE,true)
	score.custom_minimum_size.x=130
	score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(score)
	away=G.label("",22,G.WHITE,true)
	away.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	G.fill(away)
	banner.add_child(away)
	play=G.button("COUP D'ENVOI",_act,true)
	banner.add_child(play)
	var center:=G.h(13)
	G.fill(center,true)
	add_child(center)
	var container:=SubViewportContainer.new()
	container.stretch=true
	container.custom_minimum_size=Vector2(500,280)
	G.fill(container,true)
	center.add_child(container)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1000,620)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	container.add_child(viewport)
	stage=load("res://match_view.gd").new()
	viewport.add_child(stage)
	var panel:=G.panel(center)
	_notebook = panel.get_parent()
	panel.get_parent().name="MatchNotebook"
	panel.get_parent().custom_minimum_size.x=310
	panel.get_parent().size_flags_horizontal=Control.SIZE_FILL
	var tabs:=G.h(3)
	panel.add_child(tabs)
	for name in ["Direct","Journal","Banc","Stats"]:
		var b:=G.button(name.to_upper(),func():_select_tab(name))
		b.add_theme_font_size_override("font_size",13)
		b.set_meta("match_tab", name)
		_tab_controls.append(b)
		G.fill(b)
		tabs.add_child(b)
	_bench_feedback = G.v(2)
	_bench_context = G.wrap("", 14, G.INK)
	_bench_context.name = "MatchBenchContext"
	_bench_status = G.wrap("", 12, G.INK)
	_bench_status.name = "MatchBenchStatus"
	_bench_feedback.add_child(_bench_context)
	_bench_feedback.add_child(_bench_status)
	_bench_feedback.hide()
	panel.add_child(_bench_feedback)
	side=G.scroll(panel)
	journal=preload("res://ui/match_journal.gd").new()
	journal.setup(app)
	panel.add_child(journal)
	journal.hide()
	var control_sheet:=G.panel(self)
	_bottom_sheet = control_sheet.get_parent()
	var bottom:=G.h(8)
	_bottom_controls = bottom
	control_sheet.add_child(bottom)
	var tv:=G.button("CAMÉRA TV",func():_choose_camera("tv"))
	bottom.add_child(tv)
	var tactical := G.button("VUE TACTIQUE",func():_choose_camera("tactical"))
	bottom.add_child(tactical)
	var action := G.button("AU CONTACT",func():_choose_camera("action"))
	bottom.add_child(action)
	_camera_controls = [tv, tactical, action]
	var quality := OptionButton.new()
	_quality_control = quality
	quality.name = "MatchQuality"
	quality.tooltip_text = "Qualité visuelle du match · Économie réduit ombres et détails"
	for text in ["Économie", "Équilibré", "Détail"]: quality.add_item(text)
	quality.select(1)
	quality.item_selected.connect(_choose_quality)
	bottom.add_child(quality)
	var speed:=OptionButton.new()
	for text in ["Cadence ×1","Cadence ×4","Cadence ×12"]:speed.add_item(text)
	speed.select([1,4,12].find(app.tick_steps))
	speed.item_selected.connect(func(index:int):app.tick_steps=[1,4,12][index])
	bottom.add_child(speed)
	bottom.add_child(G.button("CONSIGNES",func():app.Immersive.open_preparation(app,1)))
	bottom.add_child(G.button("ADJOINT",func():app.confirm("Confier la fin du match", "L’adjoint prend en charge la fin de cette rencontre. Confirmer la délégation ?",func():app._command("delegate"))))
	var spacer:=Control.new()
	G.fill(spacer)
	bottom.add_child(spacer)
	finish=G.button("VALIDER LA JOURNÉE  →",func():app._command("finish_round"))
	bottom.add_child(finish)
	for control in bottom.get_children():
		if control is Button:
			control.add_theme_font_size_override("font_size",12)
			for state in ["normal","hover","pressed","disabled"]:
				var style:StyleBoxFlat=control.get_theme_stylebox(state).duplicate()
				style.content_margin_left=10
				style.content_margin_right=10
				control.add_theme_stylebox_override(state,style)
	app.match_view=stage
	app.pause_button=play
	app.match_finish=finish
	app.match_clock=clock
	_caption = G.label("Simulation de carrière · enceinte générique · caméras TV, tactique et au contact",12,G.WHITE)
	add_child(_caption)
	get_viewport().size_changed.connect(_layout_short_height)
	_layout_short_height()
	apply_preferences()

func _layout_short_height() -> void:
	var compact := get_viewport_rect().size.y < 820
	add_theme_constant_override("separation", 6 if compact else 10)
	_notebook.custom_minimum_size.x = 380 if compact else 310
	_caption.visible = not compact
	score.add_theme_font_size_override("font_size", 32 if compact else 42)
	clock.add_theme_font_size_override("font_size", 20 if compact else 24)
	for label in [home, away]: label.add_theme_font_size_override("font_size", 18 if compact else 22)
	for panel in [_score_sheet, _bottom_sheet]:
		var style: StyleBox = panel.get_theme_stylebox("panel").duplicate()
		style.content_margin_top = 6 if compact else 12
		style.content_margin_bottom = 6 if compact else 12
		panel.add_theme_stylebox_override("panel", style)
	for control in _bottom_controls.get_children() + [play]:
		if not control is BaseButton: continue
		control.custom_minimum_size.y = 32 if compact else 44
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = control.get_theme_stylebox(state).duplicate()
			style.content_margin_top = 5 if compact else 12
			style.content_margin_bottom = 5 if compact else 12
			control.add_theme_stylebox_override(state, style)

func _choose_camera(mode: String) -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_camera(mode); return
	if not preferences.set_value("camera", mode):
		apply_preferences()
		app.notice("Réglage non enregistré", preferences.last_error)

func _choose_quality(index: int) -> void:
	if index < 0 or index > 2: return
	var quality: String = ["economy", "balanced", "detail"][index]
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_quality(quality); return
	if not preferences.set_value("quality", quality):
		apply_preferences()
		app.notice("Réglage non enregistré", preferences.last_error)

func apply_preferences() -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null or not is_instance_valid(stage): return
	var quality: String = str(preferences.data.quality)
	var camera: String = preferences.effective_camera()
	stage.set_stadium_evening(preferences.data.stadium == "evening")
	stage.set_action_motion(not bool(preferences.data.reduced_motion))
	if quality != _applied_quality:
		_applied_quality = quality
		stage.set_quality(quality)
	if camera != _applied_camera:
		_applied_camera = camera
		stage.set_camera(camera)
	if is_instance_valid(_quality_control): _quality_control.select(["economy", "balanced", "detail"].find(quality))
	for button: Button in _camera_controls:
		button.disabled = bool(preferences.data.reduced_motion)
		button.tooltip_text = "Mode calme : caméra tactique fixe. Vous pouvez modifier ce réglage dans Paramètres." if button.disabled else "Choix conservé pour les prochains matchs."

func update_frame(value:Dictionary) -> void:
	model=value
	if not is_node_ready():return
	var live:Dictionary=value.live if value.get("live") is Dictionary else {}
	if live.is_empty():
		stage.apply_frame({})
		var next:Dictionary=value.next if value.get("next") is Dictionary else {}
		home.text=G.club_name(next.get("home",{}))
		away.text=G.club_name(next.get("away",{}))
		score.text="— / —"
		clock.text="AVANT-MATCH"
		play.text="COUP D'ENVOI"
		play.disabled=next.is_empty()
		var season_done:bool=value.meta.get("canAdvanceSeason",false) or (value.meta.get("mode") not in ["france30","common"] and value.meta.get("phase")=="ended")
		finish.disabled=not next.is_empty() or season_done
		if next.is_empty():
			clock.text="SAISON TERMINÉE" if season_done else "SANS RENCONTRE"
			finish.text="AVANCER LA SEMAINE  →"
	else:
		var teams:Array=live.get("teams",[{},{}])
		home.text=G.club_abbr(teams[0])
		away.text=G.club_abbr(teams[1])
		var scores:Array=live.get("score",[0,0])
		score.text="%s — %s"%[G.n(scores[0]),G.n(scores[1])]
		clock.text="%s min"%G.n(live.get("minute",0))
		if live.get("finished",false):clock.text="TERMINÉ"
		elif live.get("atBreak",false):clock.text="MI-TEMPS"
		play.text="REPRENDRE" if live.get("paused",false) else "PAUSE"
		play.disabled=live.get("finished",false)
		finish.text="VALIDER LA JOURNÉE  →"
		finish.disabled=not live.get("finished",false)
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
	_side()

func _select_tab(value: String) -> void:
	tab = value
	app.management_ui["match_journal_tab"] = value
	presence_key = ""
	_side()

func _side() -> void:
	if _styled_tab != tab:
		_styled_tab = tab
		for control in _tab_controls:
			if control.get_meta("match_tab") == tab: G.selected(control, app.accent)
			else: control.add_theme_stylebox_override("normal", G.T.box(Color("e8dfce"), 3, G.LINE))
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	side.get_parent().visible = tab != "Journal"
	journal.visible = tab == "Journal"
	if tab != "Banc" or live.is_empty(): _bench_feedback.hide()
	if tab == "Journal":
		journal.update_frame(live)
		return
	var bench_focus := ""
	if tab=="Banc":
		# Fatigue/clock changes do not affect these controls. Keep focus across ticks,
		# but rebuild when player identity or a replacement permission changes.
		var identities:Array=[]
		for group in [live.get("lineup",[]),live.get("reserves",[])]:
			var players:Array=[]
			for player in group:
				if player is Dictionary:players.append([player.get("id"),player.get("name")])
				else:players.append(null)
			identities.append(players)
		var key:=JSON.stringify([identities,selected_slot,live.get("paused",false),live.get("finished",false),live.get("substitutions",[])])
		if key==presence_key:return
		presence_key=key
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and side.is_ancestor_of(focused):
			bench_focus = str(focused.get_meta("match_bench_focus", ""))
	for child in side.get_children():
		side.remove_child(child)
		child.queue_free()
	if live.is_empty():
		side.add_child(G.section("L'AVANT-MATCH"))
		side.add_child(G.wrap("Vérifiez votre feuille à 23 et vos consignes avant le coup d’envoi.",14))
		side.add_child(G.button("VÉRIFIER LA FEUILLE",func():app._navigate("Composition")))
		preload("res://ui/decision_views.gd").match_notes(app,side,model)
		return
	match tab:
		"Stats":
			side.add_child(G.section("LE MATCH EN CHIFFRES"))
			for stat in live.get("statsRows",[]):
				side.add_child(G.label(stat.label,12,G.MUTED))
				var row:=G.h()
				row.add_child(G.label(G.n(stat.home),25,G.GOLD,true))
				row.add_child(G.label("/",20,G.MUTED,true))
				row.add_child(G.label(G.n(stat.away),25,G.INK,true))
				side.add_child(row)
				var percentage := str(stat.home).trim_suffix("%")
				if str(stat.home).ends_with("%") and percentage.is_valid_float():
					G.gauge(side, "Domicile (%)", float(percentage), 100, G.GOLD)
				side.add_child(G.separator())
		"Banc":
			_bench(live)
			if not bench_focus.is_empty(): _restore_bench_focus(bench_focus)
		_:
			side.add_child(G.section("AU BORD DU TERRAIN"))
			if live.get("finished",false) and live.get("decision") is Dictionary:
				side.add_child(G.wrap(str(live.decision.get("label","Rencontre terminée")),15,G.GOLD))
			var tries:Array=live.get("tries",[0,0])
			side.add_child(G.label("ESSAIS   %s — %s"%[G.n(tries[0]),G.n(tries[1])],14,G.GOLD))
			if live.get("paused",false):side.add_child(G.wrap("Le jeu est en pause. Vos changements et vos consignes restent accessibles.",12,G.GOOD))
			var events:Array=live.get("events",[])
			for event in events.slice(maxi(0,events.size()-5)):
				var text:=str(event.get("text","")) if event is Dictionary else str(event)
				if event is Dictionary:side.add_child(G.label(G.n(event.get("min",0))+"'",20,G.GOLD,true))
				side.add_child(G.wrap(text,13,G.INK))
				side.add_child(G.separator())
			preload("res://ui/decision_views.gd").match_notes(app,side,model)

func _restore_bench_focus(previous_focus: String) -> void:
	var target: Button
	var fallback: Button
	var selected_key := "sortant:%d" % selected_slot
	for child in side.get_children():
		if not child is Button or child.disabled: continue
		var key := str(child.get_meta("match_bench_focus", ""))
		if key == previous_focus:
			target = child
			break
		if key == selected_key: fallback = child
	if target == null: target = fallback
	if target == null: return
	# The rebuilt list and the fixed feedback must be laid out before scrolling.
	await get_tree().process_frame
	if not is_instance_valid(target) or not target.is_visible_in_tree(): return
	target.grab_focus()
	(side.get_parent() as ScrollContainer).ensure_control_visible(target)

func _update_bench_feedback(live: Dictionary, selected: bool, out: Variant, choice: Dictionary, options: Array) -> void:
	_bench_context.visible = selected
	if selected:
		var position := str(choice.get("label", ""))
		var player_name := str(out.get("name", "Joueur")) if out is Dictionary else "Poste vacant"
		var context := "%d · %s" % [selected_slot + 1, player_name]
		if not position.is_empty(): context = "%d · %s · %s" % [selected_slot + 1, position, player_name]
		_bench_context.text = context
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
	_bench_feedback.show()

func _bench(live:Dictionary) -> void:
	side.add_child(G.section("LES CHANGEMENTS"))
	var players: Array = live.get("lineup", [])
	var reserves: Array = live.get("reserves", [])
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
		var p:Variant=players[slot]
		var b:=G.button(str(p.get("name","Joueur")) if p is Dictionary else "%d · Poste vacant"%(slot+1),func():selected_slot=slot;presence_key="";_side())
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text=b.text
		b.set_meta("match_bench_focus", "sortant:%d" % slot)
		for option: Dictionary in options:
			if option.get("slot")==slot:b.tooltip_text="%s\n%d · %s"%[b.text,slot+1,option.get("label","")]
		if slot==selected_slot:b.add_theme_stylebox_override("normal",G.T.box(Color("ddd1bc"),3,G.GOLD))
		side.add_child(b)
	if not selected: return
	var allowed: Array = choice.get("inIds", [])
	side.add_child(G.separator())
	side.add_child(G.label("FAIRE ENTRER",12,G.GOLD))
	for p in reserves:
		if not p is Dictionary:continue
		var b:=G.button(str(p.get("name","Joueur")),func():app._command("substitute",{"slot":slot_to_replace,"outId":out_id,"inId":p.id}))
		b.set_meta("match_bench_focus", "entrant:%s" % str(p.get("id")))
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text=str(p.get("name","Joueur"))
		b.disabled=p.get("id") not in allowed or not live.get("paused",false) or live.get("finished",false)
		side.add_child(b)

func _act() -> void:
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	if live.is_empty():app._command("begin_match")
	else:
		app._command("pause",{"paused":not live.get("paused",false)})
		app.timer.start()
