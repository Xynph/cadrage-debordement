extends PanelContainer
## Place outside root_content. Parent reserves the emitted height after every render.
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
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 208; offset_right = -14; offset_bottom = -10
	z_index = 10
	current_id = profile.data.step
	visible = profile.data.enabled
	_status(); _layout(); refresh()

func _button(parent: Node, text: String, id: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id; button.text = text
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 12)
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242329"); style.border_color = GOLD
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 10; style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 7); add_child(stack)
	_compact = HBoxContainer.new(); _compact.add_theme_constant_override("separation", 8); stack.add_child(_compact)
	_invitation = _label(_compact, "LE COACH · Un coup de main ?", 13)
	_invitation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invitation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button(_compact, "Visite guidée", "GuideTour", open_tour)
	_button(_compact, "Aide de l'écran", "GuideHelp", open_help)
	_expanded = VBoxContainer.new(); _expanded.add_theme_constant_override("separation", 7); stack.add_child(_expanded)
	var top := HBoxContainer.new(); _expanded.add_child(top)
	_title = _label(top, "Le carnet du coach", 18); _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_voice_state = _label(top, "", 10)
	_progress = _label(top, "", 12)
	_button(top, "Réduire", "GuideClose", close)
	var middle := HBoxContainer.new(); middle.size_flags_vertical = Control.SIZE_EXPAND_FILL; _expanded.add_child(middle)
	var portrait_host := Control.new(); portrait_host.custom_minimum_size = Vector2(144, 128); middle.add_child(portrait_host)
	portrait = Portrait.new(); portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); portrait_host.add_child(portrait)
	var balloon := Balloon.new()
	balloon.speaker = portrait
	balloon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balloon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(balloon)
	var scroll := ScrollContainer.new(); scroll.name = "GuideTextScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	balloon.add_child(scroll)
	bubble = _label(scroll, "", 16); bubble.name = "GuideBubble"
	bubble.add_theme_color_override("font_color", Color("29272b"))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 6); _expanded.add_child(actions)
	_previous = _button(actions, "Précédent", "GuidePrevious", func(): _step(-1))
	_next = _button(actions, "Suivant", "GuideNext", func(): _step(1))
	_navigate = _button(actions, "Ouvrir", "GuideNavigate", _go)
	_button(actions, "Réécouter", "GuideReplay", replay)
	_button(actions, "Arrêter", "GuideStop", func(): speech.stop())
	_button(actions, "Options", "GuideOptions", func():
		_settings_open = not _settings_open; _layout()
	)
	_options = VBoxContainer.new(); _options.add_theme_constant_override("separation", 4); _expanded.add_child(_options)
	var options := HBoxContainer.new(); options.add_theme_constant_override("separation", 8); _options.add_child(options)
	_voice = OptionButton.new(); _voice.name = "GuideVoice"; _voice.custom_minimum_size.x = 230
	_voice.add_theme_font_size_override("font_size", 12)
	_voice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for voice in speech.voices:
		_voice.add_item(str(voice.name))
		if str(voice.id) == speech.voice_id: _voice.select(_voice.item_count - 1)
	if speech.voices.is_empty(): _voice.add_item("Aucune voix française"); _voice.disabled = true
	_voice.item_selected.connect(func(index: int):
		speech.configure(str(speech.voices[index].id), speech.rate)
		profile.data.voice = speech.voice_id; _save()
	)
	options.add_child(_voice)
	_speed = OptionButton.new(); _speed.name = "GuideSpeed"; _speed.add_theme_font_size_override("font_size", 12)
	for speed in [0.75, 1.0, 1.25, 1.5]: _speed.add_item("Débit ×" + str(speed))
	_speed.select([0.75, 1.0, 1.25, 1.5].find(float(profile.data.rate)) if float(profile.data.rate) in [0.75, 1.0, 1.25, 1.5] else 1)
	_speed.item_selected.connect(func(index: int):
		speech.configure(speech.voice_id, [0.75, 1.0, 1.25, 1.5][index])
		profile.data.rate = speech.rate; _save()
	)
	options.add_child(_speed)
	_mute = _button(options, "Muet", "GuideMute", _toggle_mute)
	_button(options, "Passer l'étape", "GuideSkip", func(): _step(1))
	_button(options, "Désactiver", "GuideDisable", disable)
	_notice = _label(_options, "", 11); _notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.name = "GuideStatus"
	_error = _label(stack, "", 12); _error.name = "GuideError"
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", Color("ffbaa5"))

func _status() -> void:
	if not is_instance_valid(_notice): return
	_notice.text = speech.status_text
	_notice.add_theme_color_override("font_color", GOLD)
	_error.visible = not profile.last_error.is_empty()
	_error.text = profile.last_error
	if _error.visible:
		_error.text += "\nLes choix du guide restent actifs pour cette session, mais ne sont pas enregistrés." if profile.data.enabled else "\nCoach désactivé pour cette session. Ce choix n'est pas enregistré : il pourra revenir au prochain démarrage."
	_mute.text = "Activer la voix" if speech.muted else "Muet"
	_voice_state.text = "Mode texte" if speech.voices.is_empty() else ("Voix muette" if speech.muted else "Voix système")
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

func _process(_delta: float) -> void:
	# Also guards the interval before the parent receives a new model.
	if is_instance_valid(app) and _blocked() == _safe: refresh()

func _layout() -> void:
	_compact.visible = not expanded
	_expanded.visible = expanded
	_options.visible = expanded and _settings_open
	custom_minimum_size.y = ((340 if _settings_open else 260) if expanded else 60) + (64 if _error.visible else 0)
	offset_top = -custom_minimum_size.y - 10
	reserved_height_changed.emit(custom_minimum_size.y + 20 if visible else 0.0)

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
	_open()

func open_help() -> void:
	mode = "screen"
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
	var page: Array = Content.PAGES[id]
	var key := mode + ":" + id + ":" + str(app.route)
	current_id = id
	_title.text = "LE COACH · " + page[1]
	_progress.text = "%d / %d" % [Content.TOUR.find(id) + 1, Content.TOUR.size()] if mode == "tour" else "Aide de l'écran"
	bubble.text = page[2]
	_previous.visible = mode == "tour"; _next.visible = mode == "tour"
	_primary(_next, true); _primary(_navigate, mode == "screen")
	var skip: Button = find_child("GuideSkip", true, false); skip.visible = mode == "tour"
	_previous.disabled = Content.TOUR.find(id) <= 0
	_next.text = "Terminer" if id == Content.TOUR.back() else "Suivant"
	_navigate.text = "Ouvrir " + page[0]
	_navigate.disabled = str(page[0]) == str(app.route) or (page[0] not in ["Accueil", "Création", "Packs"] and not app._has_career())
	if force or key != _last_key:
		_last_key = key
		var scroll: ScrollContainer = find_child("GuideTextScroll", true, false); scroll.scroll_vertical = 0
		speech.speak(bubble.text)

func _step(direction: int) -> void:
	if _blocked(): return
	var index: int = Content.TOUR.find(profile.data.step)
	if direction > 0 and profile.data.step not in profile.data.completed: profile.data.completed.append(profile.data.step)
	if index == Content.TOUR.size() - 1 and direction > 0: _save(); close(); return
	profile.data.step = Content.TOUR[clampi(index + direction, 0, Content.TOUR.size() - 1)]
	_save(); _show_page(true)

func _go() -> void:
	if _blocked() or _navigate.disabled: return
	speech.stop()
	app._navigate(str(Content.PAGES[current_id][0]))
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
