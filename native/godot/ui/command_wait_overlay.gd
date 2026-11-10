extends Control
## Indication d’attente. Le contrôleur appelant reste propriétaire de la commande.

const FRAME_SIZE := Vector2(660, 386)
const CYCLE := 2.9
const SCRIM := Color(0.025, 0.04, 0.045, 0.76)
const PANEL := Color("#111a1c")
const FIELD := Color("#142523")
const OUTLINE := Color("#53625e")
const GOLD := Color("#d7ad59")
const IVORY := Color("#f2ecdc")
const MINT := Color("#82e3a3")
const MUTED := Color("#aab7af")

var _frame := Control.new()
var _status := Label.new()
var _kicker := Label.new()
var _reveal := Timer.new()
var _frame_style := StyleBoxFlat.new()
var _field_style := StyleBoxFlat.new()
var _scale := 1.0
var _elapsed := 0.0
var _motion := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_NONE
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_frame.name = "CommandWaitFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_kicker.text = "TRANSFORMATION"
	_configure_label(_kicker, GOLD)
	_status.name = "CommandWaitStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	_configure_label(_status, IVORY)

	_frame_style.bg_color = PANEL
	_frame_style.border_color = OUTLINE
	_frame_style.set_border_width_all(1)
	_frame_style.set_corner_radius_all(16)
	_frame_style.shadow_color = Color(0, 0, 0, 0.44)
	_frame_style.shadow_size = 16
	_frame_style.shadow_offset = Vector2(0, 7)
	_field_style.bg_color = FIELD
	_field_style.border_color = Color("#354a43")
	_field_style.set_border_width_all(1)
	_field_style.set_corner_radius_all(10)

	_reveal.one_shot = true
	add_child(_reveal)
	_reveal.timeout.connect(_show_frame)
	resized.connect(_layout)
	_layout()
	dismiss()


## L’interface absorbe les clics dès l’appel. Le cadre peut apparaître plus tard.
func present(message: String, animate: bool = true, delay_seconds: float = 0.0) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		text = "Un instant…"
	_status.text = text
	_status.accessibility_name = text
	_motion = animate
	if visible:
		if _frame.visible:
			set_process(_motion)
			queue_redraw()
		return

	show()
	queue_redraw()
	_elapsed = 0.0
	if delay_seconds > 0.0:
		_reveal.start(delay_seconds)
	else:
		_show_frame()


func dismiss() -> void:
	_reveal.stop()
	_frame.hide()
	hide()
	set_process(false)


func _show_frame() -> void:
	_frame.show()
	set_process(_motion)
	queue_redraw()


func _configure_label(label: Label, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	_frame.add_child(label)


func _layout() -> void:
	_scale = clampf(minf(size.x / 1280.0, size.y / 720.0), 0.42, 1.38)
	_frame.size = FRAME_SIZE * _scale
	_frame.position = (size - _frame.size) * 0.5
	_kicker.position = Vector2(48, 18) * _scale
	_kicker.size = Vector2(564, 39) * _scale
	_kicker.add_theme_font_size_override("font_size", roundi(17 * _scale))
	_status.position = Vector2(44, 301) * _scale
	_status.size = Vector2(572, 66) * _scale
	_status.add_theme_font_size_override("font_size", roundi(28 * _scale))
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, CYCLE)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SCRIM if _frame.visible else Color(SCRIM, 0.12))
	if not _frame.visible:
		return
	draw_set_transform(_frame.position, 0, Vector2.ONE * _scale)
	draw_style_box(_frame_style, Rect2(Vector2.ZERO, FRAME_SIZE))
	draw_line(Vector2(40, 37), Vector2(199, 37), OUTLINE, 1.0, true)
	draw_line(Vector2(461, 37), Vector2(620, 37), OUTLINE, 1.0, true)
	draw_style_box(_field_style, Rect2(32, 64, 596, 222))
	_draw_pitch()
	var time := _elapsed if _motion else 1.82
	_draw_player(time)
	_draw_ball(time)


func _draw_pitch() -> void:
	draw_line(Vector2(58, 253), Vector2(602, 253), Color("#4a695a"), 1.2, true)
	for x in range(65, 595, 33):
		draw_line(Vector2(x, 266), Vector2(x + 12, 266), Color("#355248"), 1.0, true)
	for x in [368.0, 492.0]:
		draw_line(Vector2(x, 81), Vector2(x, 253), MUTED, 3.0, true)
		draw_line(Vector2(x, 232), Vector2(x, 252), GOLD, 7.0, true)
	draw_line(Vector2(368, 149), Vector2(492, 149), MUTED, 3.0, true)
	draw_line(Vector2(172, 250), Vector2(189, 250), GOLD, 2.5, true)
	for point in range(1, 20):
		draw_circle(_flight(point / 20.0), 1.7, Color(0.84, 0.68, 0.35, 0.48), true, -1.0, true)


func _draw_player(time: float) -> void:
	var strike := smoothstep(0.24, 0.52, time) * (1.0 - smoothstep(0.76, 1.15, time))
	var lean := Vector2(8 * strike, 0)
	var head := Vector2(125, 151) + lean
	var shoulder := Vector2(124, 179) + lean
	var hip := Vector2(130, 205)
	var support_knee := Vector2(122, 227)
	var support_foot := Vector2(113, 248)
	var swing_knee := Vector2(143, 224).lerp(Vector2(153, 208), strike)
	var swing_foot := Vector2(137, 246).lerp(Vector2(176, 226), strike)
	draw_line(hip, support_knee, MUTED, 9.0, true)
	draw_line(support_knee, support_foot, MUTED, 7.0, true)
	draw_line(support_foot, support_foot + Vector2(12, 0), IVORY, 4.0, true)
	draw_line(hip, swing_knee, IVORY, 9.0, true)
	draw_line(swing_knee, swing_foot, IVORY, 7.0, true)
	draw_line(swing_foot, swing_foot + Vector2(9, -1), GOLD, 4.0, true)
	draw_line(shoulder, hip, MINT, 19.0, true)
	draw_line(shoulder, Vector2(106, 191) + lean, MINT, 6.0, true)
	draw_line(shoulder, Vector2(146, 183).lerp(Vector2(154, 176), strike) + lean, MINT, 6.0, true)
	draw_circle(head, 11.0, IVORY, true, -1.0, true)


func _flight(progress: float) -> Vector2:
	return Vector2(180.0 + 274.0 * progress, 235.0 - 123.0 * progress - 104.0 * sin(PI * progress))


func _draw_ball(time: float) -> void:
	var flight := clampf((time - 0.47) / 1.31, 0.0, 1.0)
	var position_on_arc := _flight(flight)
	var spin := flight * TAU * 1.5 - 0.8
	var opacity := 1.0 - smoothstep(2.03, 2.42, time)
	var radius := lerpf(9.0, 6.0, flight)
	var points := PackedVector2Array()
	for segment in range(20):
		var angle := TAU * segment / 20.0
		var oval := Vector2(cos(angle), sin(angle) * 0.61) * radius
		points.append(position_on_arc + oval.rotated(spin))
	draw_colored_polygon(points, Color(GOLD, opacity))
	draw_line(position_on_arc - Vector2(radius * 0.44, 0).rotated(spin), position_on_arc + Vector2(radius * 0.44, 0).rotated(spin), Color(IVORY, opacity), 1.3, true)
