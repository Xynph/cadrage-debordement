extends Node3D

const IDLE := &"Repos"
const APPROVAL := &"Approbation"
const SPEECH := &"Parole"
const ACCENT := Color("#d9e696")
const INK := Color("#eaf1e7")
const MUTED := Color("#a9b9b6")
const REPLIQUE := "« Continue à construire. »"
const JAW_ACCENTS: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.31, 0.0), Vector2(0.36, 0.22), Vector2(0.42, 0.58),
	Vector2(0.47, 0.53), Vector2(0.51, 0.10), Vector2(0.55, 0.28), Vector2(0.59, 0.37),
	Vector2(0.64, 0.54), Vector2(0.69, 0.66), Vector2(0.74, 0.40), Vector2(0.79, 0.35),
	Vector2(0.83, 0.53), Vector2(0.90, 0.12), Vector2(0.94, 0.0), Vector2(0.98, 0.26),
	Vector2(1.05, 0.43), Vector2(1.12, 0.21), Vector2(1.19, 0.10), Vector2(1.27, 0.0),
	Vector2(1.31, 0.25), Vector2(1.35, 0.36), Vector2(1.45, 0.18), Vector2(1.55, 0.02),
	Vector2(1.65, 0.0), Vector2(1.875, 0.0),
]
const BLINK: Array[Vector2] = [
	Vector2(-0.112, 0.0), Vector2(-0.068, 0.14), Vector2(-0.037, 0.52),
	Vector2(-0.014, 0.88), Vector2(0.0, 1.0), Vector2(0.034, 0.74),
	Vector2(0.066, 0.40), Vector2(0.106, 0.11), Vector2(0.14, 0.0),
]
const BLINK_MID := 0.54

@onready var animations := $Gabi.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var voice: AudioStreamPlayer = $Voice
@onready var camera: Camera3D = $ReviewCamera
@onready var hud: CanvasLayer = $HUD

var current_clip := IDLE
var azimuth := -14.0
var portrait := false
var dragging := false
var caption: Label
var feedback: Label
var clip_buttons: Dictionary = {}
var view_buttons: Dictionary = {}
var face_mesh: MeshInstance3D
var jaw_channel := -1
var blink_targets: Array[Dictionary] = []
var face_ready := false


func _ready() -> void:
	_build_hud()
	set_view(-14.0, false)
	if not _clips_available():
		feedback.text = "Les trois animations sont requises dans le GLB."
		for button: Button in clip_buttons.values():
			button.disabled = true
		return
	face_ready = _configure_face()
	animations.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	animations.animation_finished.connect(_on_animation_finished)
	play_clip(IDLE)


func _clips_available() -> bool:
	return animations != null and animations.has_animation(IDLE) \
		and animations.has_animation(APPROVAL) and animations.has_animation(SPEECH)


func play_clip(clip: StringName) -> void:
	if not _clips_available() or clip not in [IDLE, APPROVAL, SPEECH]:
		return
	voice.stop()
	if face_ready:
		_apply_face(0.0, 0.0)
	current_clip = clip
	animations.stop(true)
	animations.play(clip, 0.12)
	animations.advance(0.0)
	for key: StringName in clip_buttons:
		clip_buttons[key].set_pressed_no_signal(key == clip)
	caption.text = REPLIQUE if clip == SPEECH else ""
	match clip:
		IDLE:
			feedback.text = "Repos · boucle continue"
		APPROVAL:
			feedback.text = "Approbation · hochement et geste de la main"
		SPEECH:
			feedback.text = "Mâchoire calée sur une réplique · sans visèmes" if face_ready \
				else "Voix existante · gestuelle sans synchronisation labiale"
			voice.play()


func _configure_face() -> bool:
	face_mesh = $Gabi.find_child("SK_Gabi", true, false) as MeshInstance3D
	if face_mesh == null:
		return false
	jaw_channel = face_mesh.find_blend_shape_by_name(&"Machoire")
	if jaw_channel < 0:
		return false
	for name: String in ["SK_Gabi", "Globe_L", "Globe_R"]:
		var mesh := $Gabi.find_child(name, true, false) as MeshInstance3D
		if mesh == null:
			return false
		var mid := mesh.find_blend_shape_by_name(&"Paupiere_Mi")
		var closed := mesh.find_blend_shape_by_name(&"Paupiere_Fermee")
		if mid < 0 or closed < 0:
			return false
		blink_targets.append({"mesh": mesh, "mid": mid, "closed": closed})
	return true


func _process(_delta: float) -> void:
	if not face_ready:
		return
	var time := animations.current_animation_position
	var jaw := 0.0
	var blink := 0.0
	if current_clip == SPEECH and voice.playing:
		jaw = _sample(JAW_ACCENTS, time)
		blink = _sample(BLINK, time - 0.69)
	elif current_clip == IDLE:
		blink = _sample(BLINK, time - 1.15)
	_apply_face(jaw, blink)


func _apply_face(jaw: float, blink: float) -> void:
	face_mesh.set_blend_shape_value(jaw_channel, jaw)
	var mid := blink / BLINK_MID if blink <= BLINK_MID else (1.0 - blink) / (1.0 - BLINK_MID)
	var closed := 0.0 if blink <= BLINK_MID else (blink - BLINK_MID) / (1.0 - BLINK_MID)
	for target: Dictionary in blink_targets:
		var mesh: MeshInstance3D = target.mesh
		mesh.set_blend_shape_value(target.mid, mid)
		mesh.set_blend_shape_value(target.closed, closed)


func _sample(curve: Array[Vector2], time: float) -> float:
	if time <= curve[0].x or time >= curve[-1].x:
		return 0.0
	for index: int in range(1, curve.size()):
		var target := curve[index]
		if time <= target.x:
			var previous := curve[index - 1]
			var progress := inverse_lerp(previous.x, target.x, time)
			return lerpf(previous.y, target.y, smoothstep(0.0, 1.0, progress))
	return 0.0


func _on_animation_finished(clip: StringName) -> void:
	if clip != IDLE and clip == current_clip:
		play_clip(IDLE)


func set_view(angle: float, close_up: bool) -> void:
	azimuth = angle
	portrait = close_up
	_update_camera()
	var active_view := &"profil" if portrait and is_equal_approx(absf(azimuth), 90.0) else (&"portrait" if portrait else &"ensemble")
	for key: StringName in view_buttons:
		view_buttons[key].set_pressed_no_signal(key == active_view)


func _update_camera() -> void:
	var radians := deg_to_rad(azimuth)
	var target := Vector3(0.0, 1.54 if portrait else 0.90, 0.0)
	var vertical_offset := 0.025 if portrait else 0.28
	camera.position = target + Vector3(sin(radians) * 3.5, vertical_offset, cos(radians) * 3.5)
	camera.look_at(target, Vector3.UP)
	camera.size = 0.66 if portrait else 2.12
	camera.h_offset = 0.145 if portrait else 0.47
	camera.v_offset = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		azimuth = wrapf(azimuth - event.relative.x * 0.38, -180.0, 180.0)
		_update_camera()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: play_clip(IDLE)
		KEY_2: play_clip(APPROVAL)
		KEY_3: play_clip(SPEECH)
		KEY_F: set_view(-10.0, true)
		KEY_P: set_view(-90.0, true)
		KEY_R: set_view(-14.0, false)
		KEY_LEFT: set_view(azimuth - 10.0, portrait)
		KEY_RIGHT: set_view(azimuth + 10.0, portrait)
		_: return
	get_viewport().set_input_as_handled()


func _build_hud() -> void:
	var ui := Control.new()
	hud.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mark := _label("OVAL LEGACY   /   ATELIER PERSONNAGES", 17, ACCENT)
	mark.position = Vector2(48, 34)
	ui.add_child(mark)

	var footnote := _label("Glisser pour tourner   ·   ← / →   ·   R pour recentrer", 16, MUTED)
	ui.add_child(footnote)
	footnote.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footnote.position += Vector2(48, -31)

	caption = _label("", 25, INK)
	ui.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.position += Vector2(48, -81)

	var card := PanelContainer.new()
	ui.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	card.offset_left = -444
	card.offset_right = -48
	card.offset_top = -312
	card.offset_bottom = 312
	card.add_theme_stylebox_override("panel", _style(Color("#122427"), Color("#294347"), 12, 25))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	content.add_child(_label("PROTOTYPE 3D · VISAGE V6", 15, ACCENT))
	content.add_child(_label("Gabi", 58, INK))
	content.add_child(_label("Gaston Darroux · ancien pilier", 18, MUTED))
	_rule(content)
	content.add_child(_label("ANIMATIONS", 15, ACCENT))
	for item: Array in [[IDLE, "1   Repos"], [APPROVAL, "2   Approbation"], [SPEECH, "3   Parole"]]:
		var button := _button(item[1])
		content.add_child(button)
		button.pressed.connect(play_clip.bind(item[0]))
		clip_buttons[item[0]] = button
	feedback = _label("", 16, MUTED)
	feedback.custom_minimum_size.y = 50
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(feedback)
	_rule(content)
	content.add_child(_label("CADRAGE", 15, ACCENT))
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 8)
	content.add_child(views)
	for item: Array in [[&"ensemble", "En pied", -14.0, false], [&"portrait", "Visage", -10.0, true], [&"profil", "Profil", -90.0, true]]:
		var button := _button(item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		views.add_child(button)
		button.pressed.connect(set_view.bind(item[2], item[3]))
		view_buttons[item[0]] = button
	var disclaimer := _label("Échelle 1,80 m · clignement et mâchoire", 14, MUTED)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(disclaimer)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size.y = 46
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", ACCENT)
	button.add_theme_stylebox_override("normal", _style(Color("#1b3235"), Color("#395356"), 6, 11))
	button.add_theme_stylebox_override("hover", _style(Color("#254348"), Color("#63877f"), 6, 11))
	button.add_theme_stylebox_override("pressed", _style(Color("#2e4230"), Color("#a9bd75"), 6, 11))
	var focus := _style(Color.TRANSPARENT, ACCENT, 6, 0)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	return button


func _style(fill: Color, border: Color, radius: int, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	return box


func _rule(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = Color("#395356")
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
