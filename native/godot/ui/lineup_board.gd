extends Control
const G = preload("res://ui/game_skin.gd")
var app: Control
var tiles: Array[Control] = []
const POSITIONS = [Vector2(.23,.80),Vector2(.50,.80),Vector2(.77,.80),Vector2(.36,.65),Vector2(.64,.65),Vector2(.20,.50),Vector2(.80,.50),Vector2(.50,.48),Vector2(.35,.34),Vector2(.58,.28),Vector2(.12,.17),Vector2(.43,.16),Vector2(.67,.13),Vector2(.88,.17),Vector2(.50,.03)]

func _ready() -> void:
	custom_minimum_size = Vector2(360,420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for slot in 15:
		var player: Dictionary = {}
		for p in app.model.get("squad", []):
			if p.get("shirtNumber") != null and int(p.shirtNumber) == slot + 1: player = p
		var name := str(player.get("name", "À pourvoir"))
		var b := G.button("", func(): app.selected_slot=slot; app._render())
		b.custom_minimum_size = Vector2(100,74)
		b.add_theme_font_size_override("font_size",11)
		b.tooltip_text = name + " · portrait fictif généré par IA"
		if slot == app.selected_slot: b.add_theme_stylebox_override("normal",G.T.box(Color("3b4d3d"),4,G.GOLD))
		add_child(b)
		var inset:=G.margin(3)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var face:=G.v(1)
		face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(face)
		if not player.is_empty():
			var portrait:=G.portrait(int(player.get("portraitIndex",0)),40)
			portrait.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
			face.add_child(portrait)
		var parts:=name.split(" ")
		var surname:=" ".join(parts.slice(1)) if parts.size()>1 else name
		var caption:=G.label("%02d %s"%[slot+1,surname],10)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		face.add_child(caption)
		tiles.append(b)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	for i in tiles.size():
		var point: Vector2 = POSITIONS[i]
		tiles[i].position = Vector2(point.x*(size.x-110)+5,point.y*(size.y-86)+5)
		tiles[i].size = Vector2(100,74)
	queue_redraw()

func _draw() -> void:
	draw_style_box(G.T.box(Color("1e3a32"),6),Rect2(Vector2.ZERO,size))
	var field := Rect2(Vector2(8,12),size-Vector2(16,24))
	draw_rect(field,Color("517366"),false,1.5)
	for ratio in [.13,.32,.50,.68,.87]:
		var y: float = field.position.y+field.size.y*ratio
		draw_line(Vector2(8,y),Vector2(size.x-8,y),Color("517366"),1.0)
	draw_line(Vector2(size.x/2,12),Vector2(size.x/2,size.y-12),Color("365849"),1.0)
