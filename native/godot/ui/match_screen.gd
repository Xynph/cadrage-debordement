extends VBoxContainer
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const MatchProjection = preload("res://ui/immersive08/projection.gd")
var app: Control
var stage: Node3D
var clock: Label
var score: Label
var home: Label
var away: Label
var play: Button
var _nomination_notice: Label
var finish: Button
var events: Label
var stats: Label
var journal: VBoxContainer
var side: VBoxContainer
var tab := "Direct"
var selected_slot := -1
var presence_key := ""
var model: Dictionary = {}
var _quality_control: OptionButton
var _camera_controls: Array[Button] = []
var _kit_swatches: Array[Panel] = []
var _kit_swatch_colors: Array[Color] = []
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
	for side in 2:
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_theme_stylebox_override("panel", G.T.box(Color.WHITE, 3, Color("aeafa7")))
		swatch.hide()
		banner.add_child(swatch)
		banner.move_child(swatch, home.get_index() + 1 if side == 0 else score.get_index() + 1)
		_kit_swatches.append(swatch)
	_nomination_notice=G.wrap("",15,Color("ddbd80"))
	_nomination_notice.name="MatchNominationNotice"
	_nomination_notice.hide()
	score_sheet.add_child(_nomination_notice)
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
	var kit_colors: Array[Color] = []
	var vacant := MatchProjection.reduced_bench_number(value)
	_nomination_notice.text = ""
	if vacant != 0: _nomination_notice.text = MatchProjection.reduced_bench_vacancy(vacant)
	elif MatchProjection.is_nomination_at_22(live.get("nominationSize")): _nomination_notice.text = "Feuille à 22 joueurs"
	_nomination_notice.visible = not _nomination_notice.text.is_empty()
	if live.is_empty():
		stage.apply_frame({})
		var next:Dictionary=value.next if value.get("next") is Dictionary else {}
		home.text=G.club_name(next.get("home",{}))
		away.text=G.club_name(next.get("away",{}))
		score.text="— / —"
		clock.text="AVANT-MATCH"
		play.text="Jouer à 22" if vacant != 0 else "COUP D'ENVOI"
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
		kit_colors = stage.alternative_kit_colors()
	if kit_colors != _kit_swatch_colors:
		_kit_swatch_colors = kit_colors
		for side in _kit_swatches.size():
			var swatch := _kit_swatches[side]
			swatch.visible = not kit_colors.is_empty()
			if swatch.visible:
				(swatch.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = kit_colors[side]
	_side()

func _select_tab(value: String) -> void:
	tab = value
	app.management_ui["match_journal_tab"] = value
	presence_key = ""
	_side()

static func _decision_label(decision: Variant, teams: Array, fallback := "Rencontre terminée.") -> String:
	if not decision is Dictionary:
		return fallback
	var label := str(decision.get("label", fallback))
	var winner: Variant = decision.get("winner")
	if winner == null:
		return label
	# Match the exact model wording so only the winner's name changes.
	var suffix: String = {
		"tries": " au nombre d’essais.",
		"penalties": " au nombre de pénalités réussies.",
		"drops": " au nombre de drops.",
		"redCards": " au nombre d’exclusions.",
		"shootout": " aux tirs au but.",
	}.get(decision.get("kind"), "")
	var prefix := "Qualification de " if not suffix.is_empty() else "Victoire de "
	if suffix.is_empty():
		suffix = "."
	for team: Dictionary in teams:
		if team.get("id") == winner:
			var internal_name := str(team.get("name", ""))
			if not internal_name.is_empty() and label == prefix + internal_name + suffix:
				return prefix + G.club_name(team) + suffix
			break
	return label


func _side() -> void:
	if _styled_tab != tab:
		_styled_tab = tab
		for control in _tab_controls:
			if control.get_meta("match_tab") == tab: G.selected(control, app.accent)
			else: control.add_theme_stylebox_override("normal", G.T.box(Color("e8dfce"), 3, G.LINE))
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	side.get_parent().visible = tab != "Journal"
	journal.visible = tab == "Journal"
	if tab == "Journal":
		journal.update_frame(live)
		return
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
	for child in side.get_children():
		side.remove_child(child)
		child.queue_free()
	if live.is_empty():
		side.add_child(G.section("L'AVANT-MATCH"))
		var guidance := "Vérifiez votre feuille et vos consignes avant le coup d’envoi." if MatchProjection.reduced_bench_number(model) != 0 else "Vérifiez votre feuille à 23 et vos consignes avant le coup d’envoi."
		side.add_child(G.wrap(guidance,14))
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
		"Banc":_bench(live)
		_:
			side.add_child(G.section("AU BORD DU TERRAIN"))
			if live.get("finished",false) and live.get("decision") is Dictionary:
				side.add_child(G.wrap(_decision_label(live.decision,live.get("teams",[]),"Rencontre terminée"),15,G.GOLD))
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

func _bench(live:Dictionary) -> void:
	side.add_child(G.section("LES CHANGEMENTS"))
	if not live.get("paused",false):side.add_child(G.wrap("Mettez la rencontre en pause pour préparer le changement.",12,G.GOLD))
	var players:Array=live.get("lineup",[])
	var reserves:Array=live.get("reserves",[])
	for slot in players.size():
		var p:Variant=players[slot]
		var b:=G.button(str(p.get("name","Joueur")) if p is Dictionary else "%d · Poste vacant"%(slot+1),func():selected_slot=slot;presence_key="";_side())
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text=b.text
		for option in live.get("substitutions",[]):
			if option.get("slot")==slot:b.tooltip_text="%s\n%d · %s"%[b.text,slot+1,option.get("label","")]
		if slot==selected_slot:b.add_theme_stylebox_override("normal",G.T.box(Color("ddd1bc"),3,G.GOLD))
		side.add_child(b)
	if selected_slot<0 or selected_slot>=players.size():return
	var allowed:Array=[]
	for option in live.get("substitutions",[]):
		if option.get("slot")==selected_slot:allowed=option.get("inIds",[])
	var out:Variant=players[selected_slot]
	var out_id:Variant=out.get("id") if out is Dictionary else null
	side.add_child(G.separator())
	side.add_child(G.label("FAIRE ENTRER",12,G.GOLD))
	for p in reserves:
		if not p is Dictionary:continue
		var b:=G.button(str(p.get("name","Joueur")),func():app._command("substitute",{"slot":selected_slot,"outId":out_id,"inId":p.id}))
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text=str(p.get("name","Joueur"))
		b.disabled=p.get("id") not in allowed or not live.get("paused",false) or live.get("finished",false)
		side.add_child(b)

func _confirm_reduced_bench(vacant: int) -> void:
	if app.waiting: return
	var fixture: Dictionary = model.next.duplicate(true)
	app._clear_dialogs()
	var dialog := ConfirmationDialog.new()
	dialog.name = "MatchConfirmReducedBench"
	dialog.title = "Coup d’envoi à 22"
	dialog.dialog_text = "%s Vous commencez avec 15 titulaires et 7 remplaçants." % MatchProjection.reduced_bench_vacancy(vacant)
	dialog.dialog_text += "\n\nSi la première ligne ne peut plus être complétée, les mêlées deviennent non disputées."
	app._prepare_dialog(dialog, 520)
	dialog.get_ok_button().text = "Jouer à 22"
	dialog.get_cancel_button().text = "Annuler"
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			if is_instance_valid(play) and play.is_visible_in_tree(): play.grab_focus.call_deferred()
			dialog.queue_free())
	dialog.confirmed.connect(func():
		if app.route == "Match" and not app.waiting and MatchProjection.reduced_bench_number(app.model) == vacant and app.model.next == fixture:
			app._command("begin_match",{"reducedBench":true}))
	Dialogs.show_centered(dialog,Vector2i(520,188))
	dialog.get_cancel_button().grab_focus.call_deferred()

func _act() -> void:
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	if live.is_empty():
		var vacant := MatchProjection.reduced_bench_number(model)
		if vacant != 0: _confirm_reduced_bench(vacant)
		else: app._command("begin_match")
	else:
		app._command("pause",{"paused":not live.get("paused",false)})
		app.timer.start()
