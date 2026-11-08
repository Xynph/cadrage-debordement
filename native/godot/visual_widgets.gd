extends Control

var mode := "crest"
var accent := Color("d43e47")
var initials := "XV"
var values: Array = []
var grid_color := Color("40515a")
var data_color := Color.TRANSPARENT
const DISPLAY = preload("res://fonts/BarlowCondensed-SemiBold.ttf")

func _draw() -> void:
	if mode == "trend":
		if values.size() < 2: return
		var low := float(values.min())
		var high := float(values.max())
		var span := maxf(1, high - low)
		var points := PackedVector2Array()
		for fraction in [0.0, 0.5, 1.0]:
			var y: float = 8 + (size.y - 24) * fraction
			draw_line(Vector2(8, y), Vector2(size.x - 8, y), grid_color, 1)
		for i in values.size():
			points.append(Vector2(10 + (size.x - 20) * i / (values.size() - 1), 8 + (size.y - 24) * (1 - (float(values[i]) - low) / span)))
		draw_polyline(points, accent, 2.5, true)
		for point in points: draw_circle(point, 3.5, accent)
		draw_string(DISPLAY, Vector2(10, size.y - 1), str(values[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
		draw_string(DISPLAY, Vector2(size.x - 40, size.y - 1), str(values[-1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
	elif mode == "crest":
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.43
		var p := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r * 0.88, r * 0.48), c + Vector2(0, r), c + Vector2(-r * 0.88, r * 0.48)])
		draw_colored_polygon(p, Color("f1eee5"))
		var q := PackedVector2Array()
		for v in p: q.append(c + (v - c) * 0.87)
		draw_colored_polygon(q, accent.darkened(0.2))
		draw_line(c + Vector2(-r * 0.65, -r * 0.27), c + Vector2(r * 0.65, -r * 0.27), Color("f1eee5"), 2)
		var fs := int(r * 0.6)
		var text_size := DISPLAY.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(DISPLAY, c + Vector2(-text_size.x * 0.5, fs * 0.42), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f1eee5"))
	else:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.38
		for ring in [0.25, 0.5, 0.75, 1.0]:
			var poly := PackedVector2Array()
			for i in range(6): poly.append(c + Vector2.from_angle(-PI / 2 + TAU * i / 6) * r * ring)
			poly.append(poly[0])
			draw_polyline(poly, grid_color, 1, true)
		var data := PackedVector2Array()
		for i in range(mini(6, values.size())):
			var axis := Vector2.from_angle(-PI / 2 + TAU * i / 6)
			draw_line(c, c + axis * r, grid_color, 1)
			data.append(c + axis * r * clampf(float(values[i]) / 100.0, 0.0, 1.0))
		if data.size() == 6:
			draw_colored_polygon(data, Color(accent, 0.3))
			data.append(data[0])
			draw_polyline(data, data_color if data_color.a > 0 else accent.lightened(0.35), 2.5, true)
