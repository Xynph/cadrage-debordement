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
		var left := 38.0 if size.x >= 220 else 10.0
		var right := size.x-12
		var bottom := size.y-22
		var points := PackedVector2Array()
		for fraction in [0.0, 0.5, 1.0]:
			var y: float = 9 + (bottom-9) * fraction
			draw_line(Vector2(left, y), Vector2(right, y), Color(grid_color,.55), 1)
		if low<0 and high>0:
			var zero_y:=9+(bottom-9)*(1-low*-1/span)
			draw_line(Vector2(left,zero_y),Vector2(right,zero_y),grid_color,1)
		for i in values.size():
			points.append(Vector2(left+(right-left)*i/(values.size()-1),9+(bottom-9)*(1-(float(values[i])-low)/span)))
		var area:=PackedVector2Array([Vector2(left,bottom)])
		area.append_array(points);area.append(Vector2(right,bottom))
		draw_colored_polygon(area,Color(accent,.10))
		draw_polyline(points,accent,2,true)
		for point in points:draw_circle(point,2.5,accent)
		draw_circle(points[-1],4.5,Color(accent,.22))
		draw_circle(points[-1],2.5,accent)
		if size.x>=220:
			draw_string(DISPLAY,Vector2(3,13),str(high),HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
			draw_string(DISPLAY,Vector2(3,bottom+3),str(low),HORIZONTAL_ALIGNMENT_LEFT,-1,10,accent)
		draw_string(DISPLAY,Vector2(left,size.y-2),str(values[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
		var last_text:=str(values[-1])
		var last_width:=DISPLAY.get_string_size(last_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(DISPLAY,Vector2(right-last_width,size.y-2),last_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
	elif mode == "crest":
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.43
		var p := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r * 0.88, r * 0.48), c + Vector2(0, r), c + Vector2(-r * 0.88, r * 0.48)])
		draw_colored_polygon(p, Color("f1eee5"))
		var q := PackedVector2Array()
		for v in p: q.append(c + (v - c) * 0.87)
		draw_colored_polygon(q, accent.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([q[0],q[1],c+Vector2(-r*.1,-r*.27),c+Vector2(-r*.78,-r*.27)]),accent)
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
			draw_polyline(poly, Color(grid_color,.65), 1, true)
		var data := PackedVector2Array()
		for i in range(mini(6, values.size())):
			var axis := Vector2.from_angle(-PI / 2 + TAU * i / 6)
			draw_line(c,c+axis*r,Color(grid_color,.7),1)
			draw_circle(c+axis*r,1.5,grid_color)
			data.append(c + axis * r * clampf(float(values[i]) / 100.0, 0.0, 1.0))
		if data.size() == 6:
			draw_colored_polygon(data, Color(accent, 0.17))
			data.append(data[0])
			var outline:=data_color if data_color.a>0 else accent
			draw_polyline(data,outline,2,true)
			for point in data.slice(0,6):draw_circle(point,2.5,outline)
