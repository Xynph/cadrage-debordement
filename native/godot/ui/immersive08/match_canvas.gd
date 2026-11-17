extends "res://ui/match_screen.gd"
## Présentation du direct. La scène 3D, les commandes et le journal restent ceux du match.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const Present = preload("res://ui/immersive08/projection.gd")
const DelegationDialog = preload("res://ui/delegation_dialog.gd")
const MatchAvant = preload("res://ui/immersive08/match_avant.gd")
const ACTION_FONT_PIXELS = 12
const ACTION_HEIGHT_PIXELS = 28
const JOURNAL_CATEGORY_PIXELS = 104

## Avant le coup d'envoi : tableau de bord en tuiles (maquette « Retenue », match_avant.gd) à la place du direct.
var opening: MatchAvant
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
	opening=MatchAvant.new()
	opening.setup(app,_act,func():DelegationDialog.ouvrir(app))
	add_child(opening)
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
		row.move_child(mount,_kit_swatches[0].get_index()+1 if index==0 else score.get_index()+1)
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
	result_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	result_strip.offset_left=C.px(20)
	result_strip.offset_right=-C.px(20)
	result_strip.offset_top=C.px(20)
	result_strip.offset_bottom=C.px(150)
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
	# Avant le coup d'envoi, le tableau de bord prend toute la page ; le direct (tableau d'affichage, terrain, carnet,
	# commandes) revient au coup d'envoi.
	for part: Control in [_score_sheet,_notebook.get_parent(),_bottom_sheet,_caption]: part.visible=active
	if not active:
		var ready: bool = value.get("selection",{}).get("valid",false)
		var reduced := Present.reduced_bench_number(value) != 0
		var espoir := not Espoir.offer(value).is_empty()
		opening.status.text="" if fixture.is_empty() else "FEUILLE VALIDÉE" if ready else "COMPOSITION À VÉRIFIER"
		if reduced and not fixture.is_empty(): opening.status.text="FEUILLE À 22 DISPONIBLE"
		if espoir and not fixture.is_empty(): opening.status.text="FEUILLE INCOMPLÈTE · UN ESPOIR PEUT ÊTRE APPELÉ"
		if fixture.is_empty(): opening.status.text="SAISON TERMINÉE" if value.meta.get("canAdvanceSeason",false) else "EN ATTENTE DE RENCONTRE"
		opening.status.add_theme_color_override("font_color",C.MINT if ready else C.AMBER)
		opening.refresh(value,play)
		# Déléguer le match : mêmes conditions que le coup d'envoi (jour de match, presse réglée). Feuille à 22 :
		# la délégation reste possible, la fenêtre demande la confirmation du match à 22.
		opening.delegate.tooltip_text=play.tooltip_text if play.disabled else "Feuille incomplète : la fenêtre te propose d’appeler un espoir du centre ou, quand la règle le permet, de jouer à 22." if espoir else "L’adjoint joue le match à 22 joueurs (%s) : la fenêtre te demande de le confirmer." % Present.reduced_bench_vacancy(Present.reduced_bench_number(value)).trim_suffix(".").to_lower() if reduced else "L’adjoint joue le match ; tu peux lui confier aussi la composition."
		return
	if finished:
		play.text="Terminé"
		result_title.text=_decision_label(live.get("decision"),teams)
		result_context.text="%s   %s   %s  ·  Consulte le journal ou valide la journée." % [GameSkin.club_abbr(teams[0]),score.text,GameSkin.club_abbr(teams[1])]
	else:
		var state := "MI-TEMPS" if live.get("atBreak",false) else "EN PAUSE" if live.get("paused",false) else "EN DIRECT"
		broadcast_text.text="%s   ·   %s′" % [state,GameSkin.n(live.get("minute",0))]

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
	# Avant le coup d'envoi, le carnet est masqué : le tableau de bord (match_avant.gd) montre tout.
	if not model.get("live") is Dictionary: return
	var tab_changed := _styled_tab!=tab
	super._side()
	if tab_changed:
		for button: Button in _tab_controls:
			var selected: bool = button.get_meta("match_tab")==tab
			var style := C.box(app.accent.darkened(.48) if selected else C.PANEL,Present.safe_accent(app.accent) if selected else C.LINE,5,8)
			if selected: style.border_width_bottom=3
			button.add_theme_stylebox_override("normal",style)
