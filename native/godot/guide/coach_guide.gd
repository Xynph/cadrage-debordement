extends Control
## Floating guide. Only the balloon and its explicit controls receive mouse input.
signal reserved_height_changed(height: float)
const Content = preload("res://guide/guide_content.gd")
const Profile = preload("res://guide/guide_profile.gd")
const Speech = preload("res://guide/guide_speech.gd")
const Portrait = preload("res://guide/coach_portrait.gd")
const Balloon = preload("res://guide/coach_bubble.gd")
const INK := Color("e9dec8")
const GOLD := Color("d0b178")
var app: Control
var profile = Profile.new()
var speech: Node
var portrait: TextureRect
var bubble: Label
var expanded := false
var mode := "screen"
var current_id := "bienvenue"
var fragment_index := 0
var fragment_id := ""
var _body: Control
var _balloon: Control
var _settings_panel: PanelContainer
var _error_panel: PanelContainer
var _corner_left := false
var _avoid_elapsed := 0.0
var _last_key := ""
var _compact: HBoxContainer
var _expanded: VBoxContainer
var _title: Label
var _notice: Label
var _error: Label
var _invitation: Label
var _voice_state: Label
var _progress: Label
var _voice: OptionButton
var _speed: OptionButton
var _navigate: Button
var _previous: Button
var _next: Button
var _mute: Button
var _safe := true
var _options: VBoxContainer
var _settings_open := false

func setup(application: Control) -> void:
	app = application
	name = "CoachGuide"
	var directory: String = str(app.model.get("meta", {}).get("dataDir", app._profile_path()))
	# Same explicit normalization as native/engine/worker.cjs, even before its first snapshot.
	if directory.replace("\\", "/").trim_suffix("/").get_file() != "PrototypeGodot": directory = directory.path_join("PrototypeGodot")
	profile.load_profile(directory)
	speech = Speech.new(); add_child(speech)
	speech.setup(profile.data.voice, profile.data.rate, profile.data.muted)
	_build()
	speech.speaking_changed.connect(portrait.set_speaking)
	speech.status_changed.connect(_status)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): queue_redraw())
	z_index = 10
	current_id = profile.data.step
	visible = profile.data.enabled
	_status(); _layout(); refresh()

func _button(parent: Node, text: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id; button.text = text
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var skin := StyleBoxFlat.new(); skin.bg_color = Color("302e34") if state == "normal" else Color("49434a")
		skin.set_corner_radius_all(5); skin.content_margin_left = 7; skin.content_margin_right = 7
		skin.content_margin_top = 3; skin.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, skin)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, size: int = 13) -> Label:
	var label := Label.new(); label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	return label

func _primary(button: Button, active: bool) -> void:
	for state in ["normal", "hover", "pressed"]:
		if not active: button.remove_theme_stylebox_override(state); continue
		var style := button.get_theme_stylebox(state, "Button").duplicate() as StyleBoxFlat
		if style != null:
			style.bg_color = INK.darkened(0.12) if state == "pressed" else INK
			button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		if active: button.add_theme_color_override(state, Color("242329"))
		else: button.remove_theme_color_override(state)

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact = HBoxContainer.new(); _compact.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_compact)
	_invitation = _label(_compact, "", 12); _invitation.hide()
	_button(_compact, "Gabi · ?", "GuideHelp", open_help).tooltip_text = "Gaston Darroux · Aide de cet écran"
	_button(_compact, "Visite", "GuideTour", open_tour).tooltip_text = "Visite guidée du club"
	_expanded = VBoxContainer.new(); _expanded.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_expanded)
	_expanded.add_theme_constant_override("separation", 3)
	var top := HBoxContainer.new(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE; _expanded.add_child(top)
	_title = _label(top, "GABI", 12); _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var caption := StyleBoxFlat.new(); caption.bg_color = Color("242329"); caption.set_corner_radius_all(4)
	caption.content_margin_left = 6; caption.content_margin_right = 6
	_title.add_theme_stylebox_override("normal", caption)
	_progress = _label(top, "", 11)
	_button(top, "↔", "GuideMove", func(): _corner_left = not _corner_left; _layout()).tooltip_text = "Changer de coin"
	_button(top, "×", "GuideClose", close).tooltip_text = "Réduire Gabi"
	_body = Control.new(); _body.custom_minimum_size = Vector2(492, 150); _body.mouse_filter = Control.MOUSE_FILTER_IGNORE; _expanded.add_child(_body)
	portrait = Portrait.new(); portrait.position = Vector2(356, 16); portrait.size = Vector2(136,136); _body.add_child(portrait)
	_balloon = Balloon.new(); _balloon.speaker = portrait; _balloon.size = Vector2(354,132); _body.add_child(_balloon)
	var scroll := ScrollContainer.new(); scroll.name = "GuideTextScroll"
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_balloon.add_child(scroll)
	bubble = _label(scroll, "", 15); bubble.name = "GuideBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_theme_color_override("font_color", Color("29272b"))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new(); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE; actions.add_theme_constant_override("separation", 4); _expanded.add_child(actions)
	_previous = _button(actions, "‹", "GuidePrevious", func(): _step(-1)); _previous.tooltip_text = "Bulle précédente"
	_next = _button(actions, "Suite ›", "GuideNext", func(): _step(1))
	_navigate = _button(actions, "Ouvrir", "GuideNavigate", _go)
	_button(actions, "↻", "GuideReplay", replay).tooltip_text = "Réécouter cette bulle"
	_button(actions, "■", "GuideStop", func(): speech.stop()).tooltip_text = "Arrêter la voix"
	_button(actions, "···", "GuideOptions", func(): _settings_open = not _settings_open; _layout()).tooltip_text = "Voix et options"
	_settings_panel = PanelContainer.new(); _settings_panel.name = "GuideSettingsPanel"; add_child(_settings_panel)
	_options = VBoxContainer.new(); _options.add_theme_constant_override("separation", 5); _settings_panel.add_child(_options)
	_voice_state = _label(_options, "", 11)
	var options := HBoxContainer.new(); _options.add_child(options)
	_voice = OptionButton.new(); _voice.name = "GuideVoice"; _voice.custom_minimum_size.x = 240
	_voice.add_theme_font_size_override("font_size", 12); _voice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for voice in speech.voices:
		_voice.add_item(str(voice.name))
		if str(voice.id) == speech.voice_id: _voice.select(_voice.item_count - 1)
	if speech.voices.is_empty(): _voice.add_item("Aucune voix système française"); _voice.disabled = true
	_voice.item_selected.connect(func(index: int):
		speech.configure(str(speech.voices[index].id), speech.rate)
		profile.data.voice = speech.voice_id; _save()
	)
	options.add_child(_voice)
	_speed = OptionButton.new(); _speed.name = "GuideSpeed"; _speed.add_theme_font_size_override("font_size", 12)
	for speed in [0.75, 1.0, 1.25, 1.5]: _speed.add_item("Débit ×" + str(speed))
	_speed.select([0.75, 1.0, 1.25, 1.5].find(float(profile.data.rate)) if float(profile.data.rate) in [0.75, 1.0, 1.25, 1.5] else 1)
	_speed.item_selected.connect(func(index: int):
		speech.configure(speech.voice_id, [0.75, 1.0, 1.25, 1.5][index]); profile.data.rate = speech.rate; _save()
	)
	options.add_child(_speed)
	var controls := HBoxContainer.new(); _options.add_child(controls)
	_mute = _button(controls, "Muet", "GuideMute", _toggle_mute)
	_button(controls, "Passer l'étape", "GuideSkip", func(): _step(1, true))
	_button(controls, "Désactiver", "GuideDisable", disable)
	_notice = _label(_options, "", 11); _notice.name = "GuideStatus"; _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_panel = PanelContainer.new(); add_child(_error_panel)
	_error = _label(_error_panel, "", 12); _error.name = "GuideError"
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", Color("ffbaa5"))

func _status() -> void:
	if not is_instance_valid(_notice): return
	_notice.text = speech.status_text
	_notice.add_theme_color_override("font_color", GOLD)
	_error.visible = not profile.last_error.is_empty()
	_error_panel.visible = _error.visible
	_error.text = profile.last_error
	if _error.visible:
		_error.text += "\nLes choix du guide restent actifs pour cette session, mais ne sont pas enregistrés." if profile.data.enabled else "\nCoach désactivé pour cette session. Ce choix n'est pas enregistré : il pourra revenir au prochain démarrage."
	_mute.text = "Activer la voix" if speech.muted else "Muet"
	_voice_state.text = "Voix muette" if speech.muted else ("Voix de Gabi" if not speech.clips.is_empty() else ("Mode texte" if speech.voices.is_empty() else "Voix système"))
	_invitation.text = "LE COACH · Désactivé pour cette session" if not profile.data.enabled else "LE COACH · Un coup de main ?"
	_invitation.tooltip_text = profile.last_error

func _save() -> bool:
	var saved: bool = profile.save_profile(profile.data)
	_status()
	_layout()
	return saved

func _blocked() -> bool:
	if not is_instance_valid(app) or app.closing or app.waiting: return true
	var live: Dictionary = app._live()
	if not live.is_empty() and not live.get("paused", false) and not live.get("finished", false): return true
	return _has_dialog(app)

func _has_dialog(node: Node) -> bool:
	for child in node.get_children():
		if child == self: continue # Our voice/speed menus belong to the guide itself.
		if child is Window and child.visible: return true
		if _has_dialog(child): return true
	return false

func _process(delta: float) -> void:
	_avoid_elapsed += delta
	if _avoid_elapsed >= 0.25:
		_avoid_elapsed = 0.0; _avoid_primary_controls()
	# Also guards the interval before the parent receives a new model.
	if is_instance_valid(app) and _blocked() == _safe: refresh()

func _layout() -> void:
	if not is_instance_valid(_compact): return
	_compact.visible = not expanded
	_expanded.visible = expanded
	_settings_panel.visible = expanded and _settings_open
	var extra := 162.0 if _settings_panel.visible else 0.0
	var error_height := maxf(96.0, _error.get_minimum_size().y + 16.0) if _error.visible else 0.0
	var width := 492.0 if expanded or _error.visible else 140.0
	var height := (220.0 if expanded else 34.0) + extra + error_height
	custom_minimum_size = Vector2.ZERO
	size = Vector2(width, height)
	anchor_left = 0.0 if _corner_left else 1.0; anchor_right = anchor_left
	offset_left = (app.workspace_inset.get_global_rect().position.x + 12 if is_instance_valid(app.workspace_inset) else 208.0) if _corner_left else -width - 18.0
	offset_right = offset_left + width
	offset_top = -height - 18; offset_bottom = -18
	_compact.position = Vector2(0, extra); _compact.size = Vector2(width,34)
	_expanded.position = Vector2(0,extra); _expanded.size = Vector2(width,220)
	_settings_panel.position = Vector2.ZERO; _settings_panel.size = Vector2(width,154)
	_error_panel.position = Vector2(0,height - error_height); _error_panel.size = Vector2(width,error_height)
	reserved_height_changed.emit(0.0)
	call_deferred("_avoid_primary_controls")

func _priority_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not is_instance_valid(app) or not is_instance_valid(app.root_content): return result
	for button in app.root_content.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or button.disabled: continue
		# Text-labelled commands include ordinary offers, filters and decisions.
		# Empty buttons are large illustrated item selectors, not action bars;
		# the descriptive balloon lets their clicks pass through.
		if button.text.is_empty(): continue
		var rect: Rect2 = button.get_global_rect().intersection(Rect2(Vector2.ZERO, app.size))
		var ancestor: Node = button.get_parent()
		while ancestor is Control:
			if ancestor.clip_contents: rect = rect.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if rect.has_area(): result.append(rect.grow(5))
	return result

func _painted_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if expanded:
		controls.append_array([_balloon, portrait, _title])
	if _settings_panel.visible: controls.append(_settings_panel)
	if _error_panel.visible: controls.append(_error_panel)
	for button in find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree(): controls.append(button)
	return controls

func _covers_priority(rects: Array[Rect2]) -> bool:
	for control in _painted_controls():
		for rect in rects:
			if control.get_global_rect().intersects(rect): return true
	return false

func _avoid_primary_controls() -> void:
	if not visible or not is_instance_valid(app): return
	# Voice settings are an explicitly opened popover. Keep it stable while
	# interacting with its menus; persistent write errors must remain readable.
	if _settings_open or _error_panel.visible: return
	var rects := _priority_rects()
	if rects.is_empty() or not _covers_priority(rects): return
	var left: float = app.workspace_inset.get_global_rect().position.x + 12 if is_instance_valid(app.workspace_inset) else 208.0
	var right := app.size.x - size.x - 18
	var bottom := app.size.y - size.y - 18
	# Prefer the opposite corner, then rise above the controls. No reserved strip.
	for rise in range(0, int(maxf(bottom - 90, 0)) + 1, 48):
		for x in ([right, left] if _corner_left else [left, right]):
			global_position = Vector2(x, bottom - rise)
			if not _covers_priority(rects): return
	# Crowded or very small windows: keep the explicit compact invitation usable.
	if expanded: close()

func refresh() -> void:
	if not is_instance_valid(app): return
	_safe = not _blocked()
	for id in ["GuideTour", "GuideHelp"]:
		var button: Button = find_child(id, true, false)
		button.disabled = not _safe
	if not _safe:
		if expanded: close()
		return
	if expanded: _show_page(false)
	# Parent render can replace root_content: re-emit even if size did not change.
	_layout()

func open_tour() -> void:
	mode = "tour"
	fragment_index = 0
	_open()

func open_help() -> void:
	mode = "screen"
	fragment_index = 0
	_open()

func _open() -> void:
	if _blocked(): return
	profile.data.enabled = true; visible = true; expanded = true
	_show_page(true); _layout(); _save()

func toggle() -> void:
	if expanded: close()
	else: open_help()

func close() -> void:
	speech.stop(); expanded = false; _last_key = ""
	_layout()

func disable() -> void:
	close(); profile.data.enabled = false
	# If persistence fails, keep only the compact explanation visible. No modal spam.
	visible = not _save()
	_layout()

func _show_page(force: bool) -> void:
	var id: String = profile.data.step if mode == "tour" else Content.for_route(app.route, app.model)
	var page: Array = Content.page(id)
	if id != current_id: fragment_index = 0
	var fragments: Array = Content.fragments(id)
	fragment_index = clampi(fragment_index, 0, fragments.size() - 1)
	fragment_id = str(fragments[fragment_index].id)
	var key := mode + ":" + id + ":" + str(fragment_index) + ":" + str(app.route)
	current_id = id
	_title.text = "GABI · " + page[1]
	portrait.set_context(id)
	_progress.text = "%d/%d" % [fragment_index + 1, fragments.size()]
	bubble.text = str(fragments[fragment_index].text)
	_previous.visible = true; _next.visible = true
	_primary(_next, true); _primary(_navigate, mode == "screen")
	var skip: Button = find_child("GuideSkip", true, false); skip.visible = mode == "tour"
	_previous.disabled = fragment_index == 0 and (mode != "tour" or Content.TOUR.find(id) <= 0)
	_next.text = "Suite ›" if fragment_index < fragments.size() - 1 else ("Terminer" if mode != "tour" or id == Content.TOUR.back() else "Étape ›")
	_navigate.text = "↗ Écran"
	_navigate.tooltip_text = "Ouvrir " + page[0]
	_navigate.disabled = str(page[0]) == str(app.route) or (page[0] not in ["Accueil", "Création", "Packs"] and not app._has_career())
	if force or key != _last_key:
		_last_key = key
		var scroll: ScrollContainer = find_child("GuideTextScroll", true, false); scroll.scroll_vertical = 0
		speech.speak(bubble.text)

func _step(direction: int, skip_page: bool = false) -> void:
	if _blocked(): return
	var fragments: Array = Content.fragments(current_id)
	if not skip_page and fragment_index + direction >= 0 and fragment_index + direction < fragments.size():
		fragment_index += direction; _show_page(true); return
	if mode != "tour": close(); return
	var index: int = Content.TOUR.find(profile.data.step)
	if direction > 0 and profile.data.step not in profile.data.completed: profile.data.completed.append(profile.data.step)
	if index == Content.TOUR.size() - 1 and direction > 0: _save(); close(); return
	profile.data.step = Content.TOUR[clampi(index + direction, 0, Content.TOUR.size() - 1)]
	fragment_index = Content.fragments(profile.data.step).size() - 1 if direction < 0 else 0
	current_id = profile.data.step
	_save(); _show_page(true)

func _go() -> void:
	if _blocked() or _navigate.disabled: return
	speech.stop()
	app._navigate(str(Content.page(current_id)[0]))
	refresh()

func replay() -> void:
	if expanded and not _blocked(): speech.speak(bubble.text)

func _toggle_mute() -> void:
	speech.set_muted(not speech.muted)
	profile.data.muted = speech.muted; _save()

func destroy() -> void:
	speech.stop(); expanded = false; visible = false
	reserved_height_changed.emit(0.0)
	queue_free()
