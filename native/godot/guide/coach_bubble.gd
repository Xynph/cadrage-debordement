extends MarginContainer
## A speech balloon, with its tail kept outside the text/scrolling area.
const PAPER := Color("f4eedf")
const EDGE := Color("a99572")
var speaker: Control
var _paper := StyleBoxFlat.new()

func _ready() -> void:
	name = "GuideSpeechBalloon"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("margin_left", 15)
	add_theme_constant_override("margin_right", 30)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_bottom", 12)
	_paper.bg_color = PAPER
	_paper.border_color = EDGE
	_paper.set_border_width_all(2)
	_paper.set_corner_radius_all(16)
	_paper.shadow_color = Color(0, 0, 0, 0.18)
	_paper.shadow_size = 3
	_paper.shadow_offset = Vector2(0, 3)
	resized.connect(queue_redraw)
	if is_instance_valid(speaker): speaker.item_rect_changed.connect(queue_redraw)

func get_tail_points() -> PackedVector2Array:
	var mouth_y := size.y * 0.45
	if is_instance_valid(speaker):
		mouth_y = speaker.get_global_rect().position.y + speaker.size.y * 0.42 - global_position.y
	var y := clampf(mouth_y, 25.0, maxf(25.0, size.y - 25.0))
	return PackedVector2Array([Vector2(size.x - 20, y - 9), Vector2(size.x - 1, y + 6), Vector2(size.x - 20, y + 9)])

func _draw() -> void:
	if size.x <= 20 or size.y <= 0: return
	_paper.draw(get_canvas_item(), Rect2(Vector2.ZERO, Vector2(size.x - 20, size.y)))
	var points := get_tail_points()
	draw_colored_polygon(points, PAPER)
	draw_polyline(points, EDGE, 2.0, true)
	# Cover the join so the bubble and tail read as one continuous shape.
	draw_line(points[0] + Vector2(0, 1), points[2] - Vector2(0, 1), PAPER, 3.0, true)
