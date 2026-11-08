extends Control
## Original compact chapter signs. Pure drawing: no state, commands or resources.
var kind := "Bureau"
var ink := Color("bdc8c9")

static func glyph(chapter: String, color: Color, edge: int = 18) -> Control:
	var mark:Control = load("res://ui/art_widgets.gd").new()
	mark.kind = chapter
	mark.ink = color
	mark.custom_minimum_size = Vector2(edge,edge)
	mark.size = Vector2(edge,edge)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark

func stroke(points: Array) -> void:
	var path := PackedVector2Array()
	for point: Vector2 in points: path.append(point*size/24.0)
	draw_polyline(path,ink,1.35,true)
func ring(center: Vector2, radius: float) -> void:
	draw_arc(center*size/24.0,radius*size.x/24.0,0,TAU,24,ink,1.35,true)
func _draw() -> void:
	match kind:
		"Bureau":
			stroke([Vector2(4,4),Vector2(20,4),Vector2(20,20),Vector2(4,20),Vector2(4,4)])
			stroke([Vector2(8,9),Vector2(16,9)])
			stroke([Vector2(8,13),Vector2(16,13)])
			stroke([Vector2(8,17),Vector2(13,17)])
		"Équipe":
			ring(Vector2(12,7),3)
			ring(Vector2(4,10),2)
			ring(Vector2(20,10),2)
			stroke([Vector2(7,21),Vector2(7,17),Vector2(9,13),Vector2(15,13),Vector2(17,17),Vector2(17,21)])
			stroke([Vector2(1,20),Vector2(1,16),Vector2(4,14)])
			stroke([Vector2(23,20),Vector2(23,16),Vector2(20,14)])
		"Développement":
			stroke([Vector2(3,21),Vector2(3,15),Vector2(7,15),Vector2(7,21)])
			stroke([Vector2(10,21),Vector2(10,11),Vector2(14,11),Vector2(14,21)])
			stroke([Vector2(17,21),Vector2(17,7),Vector2(21,7),Vector2(21,21)])
			stroke([Vector2(3,10),Vector2(12,3),Vector2(20,3)])
		"Club":
			stroke([Vector2(4,3),Vector2(20,3),Vector2(19,15),Vector2(12,22),Vector2(5,15),Vector2(4,3)])
			stroke([Vector2(8,8),Vector2(16,8)])
			stroke([Vector2(12,8),Vector2(12,16)])
		"Compétitions":
			stroke([Vector2(7,3),Vector2(17,3),Vector2(17,10),Vector2(15,14),Vector2(9,14),Vector2(7,10),Vector2(7,3)])
			stroke([Vector2(7,5),Vector2(3,5),Vector2(3,10),Vector2(7,12)])
			stroke([Vector2(17,5),Vector2(21,5),Vector2(21,10),Vector2(17,12)])
			stroke([Vector2(12,14),Vector2(12,20)])
			stroke([Vector2(7,21),Vector2(17,21)])
		"Carrière":
			ring(Vector2(5,19),2.5)
			ring(Vector2(19,5),2.5)
			stroke([Vector2(8,19),Vector2(17,19),Vector2(17,12),Vector2(7,12),Vector2(7,5),Vector2(16,5)])
