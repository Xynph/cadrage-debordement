extends "res://ui/match_screen.gd"
## Présentation du direct. La scène 3D, les commandes et le journal restent ceux du match.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const Present = preload("res://ui/immersive08/projection.gd")
const ACTION_FONT_PIXELS = 12
const ACTION_HEIGHT_PIXELS = 28
const JOURNAL_CATEGORY_PIXELS = 104

var opening: Control
var opening_title: Label
var opening_context: Label
var opening_position: Label
var opening_status: Label
var result_strip: PanelContainer
var result_title: Label
var result_context: Label
var broadcast: PanelContainer
var broadcast_text: Label
var stage_viewport: SubViewport
var delegation: Button
var badges: Array[Control] = []
var team_key := ""
var _action_defaults: Dictionary = {}

func _ready() -> void:
	super._ready()
	Legacy.apply(self,app.accent)
	add_theme_constant_override("separation",C.px(13))
	_score_sheet.add_theme_stylebox_override("panel",_band(C.RAISED))
	_bottom_sheet.add_theme_stylebox_override("panel",_band(C.PANEL))
	_notebook.add_theme_stylebox_override("panel",C.box(C.PANEL,C.LINE,7,12))
	clock.add_theme_font_override("font",C.BOLD)
	clock.add_theme_color_override("font_color",C.GOLD)
	score.add_theme_font_override("font",C.EXTRA_BOLD)
	_caption.text = "DIFFUSION DE LA RENCONTRE  ·  CAMÉRAS TV, TACTIQUE ET AU CONTACT  ·  ENCEINTE 3D GÉNÉRIQUE"
	_caption.add_theme_color_override("font_color",C.MUTED)
	_add_badges()
	_add_pitch_overlays()
	for button in _bottom_controls.get_children():
		if button is Button and button.text=="ADJOINT": delegation=button; break
	for control in _tab_controls + _bottom_controls.get_children() + [journal.category,journal.search]:
		if not (control is BaseButton or control is LineEdit): continue
		_action_defaults[control] = {
			"minimum":control.custom_minimum_size,
			"font_size":control.get_theme_font_size("font_size")
		}
	_layout_short_height()
	set_meta("immersive_match",true)

func _layout_short_height() -> void:
	super._layout_short_height()
	_notebook.custom_minimum_size.x=C.px(525)
	score.add_theme_font_size_override("font_size",C.px(56))
	clock.add_theme_font_size_override("font_size",C.px(31))
	for label in [home,away]: label.add_theme_font_size_override("font_size",C.px(29))
	if not _action_defaults.is_empty(): _fit_action_sizes.call_deferred()

func _fit_action_sizes() -> void:
	var scale := maxf(.1,get_global_transform().get_scale().y)
	var font_size := ceili(ACTION_FONT_PIXELS / scale)
	var hit_height := ceili(ACTION_HEIGHT_PIXELS / scale)
	for control: Control in _action_defaults:
		var original: Dictionary = _action_defaults[control]
		var minimum: Vector2 = original.minimum
		minimum.y = maxf(minimum.y,hit_height)
		if control == journal.category:
			minimum.x = maxf(minimum.x,ceili(JOURNAL_CATEGORY_PIXELS / scale))
		control.custom_minimum_size = minimum
		control.add_theme_font_size_override("font_size",maxi(original.font_size,font_size))

func _band(color: Color) -> StyleBoxFlat:
	var frame := C.box(color,C.LINE,7,11)
	frame.border_width_bottom = 2
	frame.border_color = Color(Present.safe_accent(app.accent),.72)
	return frame

func _add_badges() -> void:
	var row: HBoxContainer = home.get_parent()
	for index in 2:
		var mount := Control.new()
		mount.mouse_filter=Control.MOUSE_FILTER_IGNORE
		mount.custom_minimum_size=Vector2(C.px(63),C.px(63))
		mount.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		row.add_child(mount)
		row.move_child(mount,home.get_index()+1 if index==0 else score.get_index()+1)
		badges.append(mount)

func _add_pitch_overlays() -> void:
	var row: HBoxContainer = _notebook.get_parent()
	var original: SubViewportContainer = row.get_child(0)
	stage_viewport=original.get_child(0)
	var stack := Control.new()
	stack.name="ImmersiveMatchPitch"
	stack.clip_contents=true
	stack.custom_minimum_size=original.custom_minimum_size
	stack.set_meta("immersive_style_applied",true)
	C.fill(stack,true)
	row.add_child(stack)
	row.move_child(stack,0)
	original.reparent(stack,false)
	original.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening=Control.new()
	opening.name="MatchOpening"
	opening.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack.add_child(opening)
	opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var photo := C.photo("match-tunnel")
	opening.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	C.veil(opening)
	var inset := C.margin(53)
	inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
	opening.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := C.v(9)
	lines.alignment=BoxContainer.ALIGNMENT_END
	lines.mouse_filter=Control.MOUSE_FILTER_IGNORE
	inset.add_child(lines)
	lines.add_child(C.label("LE JOUR DE MATCH",24,C.GOLD,true,700))
	opening_title=C.wrap("Avant le coup d’envoi",64,C.IVORY,true,800)
	lines.add_child(opening_title)
	opening_context=C.wrap("",25,C.IVORY)
	opening_context.name="MatchFixtureVenue"
	lines.add_child(opening_context)
	opening_position=C.label("",21,C.GOLD,true,700)
	opening_position.name="MatchFixturePosition"
	lines.add_child(opening_position)
	opening_status=C.wrap("",23,C.MINT,true,700)
	lines.add_child(opening_status)
	var actions := C.h(12)
	actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lines.add_child(actions)
	var sheet := C.button("Vérifier la feuille à 23",func():app._navigate("Composition"),false,app.accent)
	sheet.name="MatchOpenSheet"
	actions.add_child(sheet)
	var prep := C.button("Dossier adverse",func():
		if app.management_ui.get("preparation") is Dictionary:app.management_ui.preparation.tab=0
		app._navigate("Préparation"),false,app.accent)
	prep.name="MatchOpenPreparation"
	actions.add_child(prep)
	broadcast=C.card("")
	broadcast.name="ImmersiveMatchBroadcast"
	broadcast.add_theme_stylebox_override("panel",C.box(Color(C.BG,.87),Color(C.GOLD,.7),6,9))
	broadcast.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack.add_child(broadcast)
	broadcast.position=Vector2(C.px(18),C.px(18))
	broadcast_text=C.label("",21,C.IVORY,true,700)
	C.content(broadcast).mouse_filter=Control.MOUSE_FILTER_IGNORE
	C.content(broadcast).add_child(broadcast_text)
	result_strip=C.card("")
	result_strip.name="ImmersiveMatchResult"
	result_strip.add_theme_stylebox_override("panel",C.box(Color(C.BG,.91),Color(C.GOLD,.8),8,18))
	result_strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack.add_child(result_strip)
	result_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	result_strip.offset_left=C.px(20)
	result_strip.offset_right=-C.px(20)
	result_strip.offset_top=-C.px(150)
	result_strip.offset_bottom=-C.px(20)
	var content := C.content(result_strip)
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_child(C.label("LE SCORE FINAL",19,C.GOLD,true,700))
	result_title=C.wrap("",34,C.IVORY,true,800)
	result_context=C.wrap("",19,C.MUTED)
	content.add_child(result_title)
	content.add_child(result_context)

func update_frame(value: Dictionary) -> void:
	super.update_frame(value)
	if not is_instance_valid(opening): return
	var live: Dictionary = value.live if value.get("live") is Dictionary else {}
	var fixture: Dictionary = value.next if value.get("next") is Dictionary else {}
	var active := not live.is_empty()
	var finished: bool = live.get("finished",false)
	var teams: Array = live.get("teams",[{},{}]) if active else [fixture.get("home",{}),fixture.get("away",{})]
	_update_badges(teams)
	opening.visible=not active
	stage_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	broadcast.visible=active and not finished
	result_strip.visible=finished
	if is_instance_valid(delegation): delegation.disabled=not active or finished
	if not active:
		var next_title := "Avant le coup d’envoi"
		if fixture.is_empty(): next_title="Saison terminée" if value.meta.get("canAdvanceSeason",false) else "En attente de rencontre"
		opening_title.text=next_title
		var venue := Present.fixture_venue(fixture,false) if not fixture.is_empty() else ""
		opening_context.text="  ·  ".join([str(fixture.get("label","Calendrier du club")),venue].filter(func(item:String):return not item.is_empty()))
		opening_position.visible=not fixture.is_empty()
		if opening_position.visible: opening_position.text=Present.fixture_position(fixture,value.get("club",{}).get("id"))
		var ready: bool = value.get("selection",{}).get("valid",false)
		opening_status.text="FEUILLE VALIDÉE" if ready else "COMPOSITION À VÉRIFIER"
		opening_status.visible=not fixture.is_empty()
		opening_status.add_theme_color_override("font_color",C.MINT if ready else C.AMBER)
		return
	if finished:
		play.text="Terminé"
		result_title.text=_verdict(live.get("decision"),teams)
		result_context.text="%s   %s   %s  ·  Consultez le journal ou validez la journée." % [GameSkin.club_abbr(teams[0]),score.text,GameSkin.club_abbr(teams[1])]
	else:
		var state := "MI-TEMPS" if live.get("atBreak",false) else "EN PAUSE" if live.get("paused",false) else "EN DIRECT"
		broadcast_text.text="%s   ·   %s′" % [state,GameSkin.n(live.get("minute",0))]

func _verdict(decision: Variant, teams: Array) -> String:
	if not decision is Dictionary: return "Rencontre terminée."
	if decision.get("kind")=="draw": return "Match nul."
	for team: Dictionary in teams:
		if team.get("id")!=decision.get("winner"): continue
		var reasons := {"tries":"au nombre d’essais", "penalties":"au nombre de pénalités", "drops":"au nombre de drops", "redCards":"au nombre d’exclusions", "shootout":"aux tirs au but"}
		var reason: String = reasons.get(decision.get("kind"),"")
		if reason.is_empty(): return "Victoire de %s." % GameSkin.club_name(team)
		return "Qualification de %s %s." % [GameSkin.club_name(team),reason]
	return str(decision.get("label","Rencontre terminée."))

func _update_badges(teams: Array) -> void:
	var ids := str(teams.map(func(team:Dictionary):return team.get("id")))
	if ids==team_key: return
	team_key=ids
	for index in badges.size():
		var mount := badges[index]
		for child in mount.get_children():
			mount.remove_child(child)
			child.queue_free()
		var team: Dictionary = teams[index]
		if team.is_empty(): continue
		var crest := GameSkin.crest(team,C.px(55))
		crest.mouse_filter=Control.MOUSE_FILTER_IGNORE
		mount.add_child(crest)
		crest.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _side() -> void:
	var tab_changed := _styled_tab!=tab
	super._side()
	if model.get("live")==null and tab=="Direct": _prematch_notes()
	if tab_changed:
		for button: Button in _tab_controls:
			var selected: bool = button.get_meta("match_tab")==tab
			var style := C.box(app.accent.darkened(.48) if selected else C.PANEL,Present.safe_accent(app.accent) if selected else C.LINE,5,8)
			if selected: style.border_width_bottom=3
			button.add_theme_stylebox_override("normal",style)

func _prematch_notes() -> void:
	var selection: Dictionary = model.get("selection",{})
	var slots: Array = selection.get("slots",[])
	var filled := slots.filter(func(slot:Dictionary):return slot.get("playerId")!=null).size()
	var band := C.card("LES 23 RETENUS")
	band.set_meta("immersive_style_applied",true)
	side.add_child(band)
	var content := C.content(band)
	content.add_child(C.label("%d / %d" % [filled,slots.size()],37,C.MINT if selection.get("valid",false) else C.AMBER,true,700))
	var group := Present.group(model)
	content.add_child(C.wrap("%d disponibles  ·  %d blessés" % [group.available,group.injured],20,C.MUTED))
	var tactics: Dictionary = model.get("tactics",{})
	var playbook := C.card("LE PLAN DE JEU")
	playbook.set_meta("immersive_style_applied",true)
	side.add_child(playbook)
	var plan := C.content(playbook)
	for item in [["Attaque","attacks","attack"],["Défense","defenses","defense"]]:
		var options: Array = tactics.get(item[1],[])
		for choice: Dictionary in options:
			if choice.get("id")==tactics.get(item[2]): plan.add_child(C.wrap(item[0]+" · "+str(choice.label),22,C.IVORY,true,600));break
	plan.add_child(C.button("Ouvrir le plan de jeu",func():app._navigate("Plan de jeu"),false,app.accent))
