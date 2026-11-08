extends Control
const G = preload("res://ui/carnet_skin.gd")
var app: Control
var tiles: Array[Control] = []
var portraits: Array[Control] = []
# Six rugby lines: front row, locks, back row, halves, three-quarters, fullback.
# The row index spans the whole available height; columns include card width.
const POSITIONS = [Vector2(0,5),Vector2(.5,5),Vector2(1,5),Vector2(.3,4),Vector2(.7,4),Vector2(0,3),Vector2(1,3),Vector2(.5,3),Vector2(.3,2),Vector2(.7,2),Vector2(0,1),Vector2(1.0/3,1),Vector2(2.0/3,1),Vector2(1,1),Vector2(.5,0)]

func _ready() -> void:
	custom_minimum_size = Vector2(434,420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for slot in 15:
		var player: Dictionary = {}
		for p in app.model.get("squad", []):
			if p.get("shirtNumber") != null and int(p.shirtNumber) == slot + 1: player = p
		var name := str(player.get("name", "À pourvoir"))
		var b := G.button("", func(): app.selected_slot=slot; app._render())
		b.name = "LineupSlot%02d" % (slot+1)
		b.custom_minimum_size = Vector2(100,62)
		b.add_theme_font_size_override("font_size",11)
		b.tooltip_text = name + " · poste %02d"%(slot+1)
		if slot == app.selected_slot: G.selected(b,app.accent)
		add_child(b)
		var inset:=G.margin(3)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var face:=G.v(1)
		face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		inset.add_child(face)
		var portrait: Control
		if not player.is_empty():
			portrait=G.portrait(int(player.get("portraitIndex",0)),36,player)
			portrait.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
			face.add_child(portrait)
		portraits.append(portrait)
		var parts:=name.split(" ")
		var surname:=" ".join(parts.slice(1)) if parts.size()>1 else name
		var caption:=G.label("%02d %s"%[slot+1,surname],12)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		face.add_child(caption)
		tiles.append(b)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var height := minf(74, floorf((size.y-40)/6.0))
	var portrait_size := minf(36,height-25)
	for i in tiles.size():
		var point: Vector2 = POSITIONS[i]
		tiles[i].position = Vector2(point.x*(size.x-110)+5,point.y*(size.y-height-10)/5.0+5)
		tiles[i].size = Vector2(100,height)
		if portraits[i] != null:
			portraits[i].custom_minimum_size = Vector2(portrait_size,portrait_size)
	queue_redraw()

func _draw() -> void:
	draw_style_box(G.T.box(Color("1e3a32"),3),Rect2(Vector2.ZERO,size))
	for stripe in 10:
		if stripe % 2 == 0: draw_rect(Rect2(8, 12 + (size.y - 24) * stripe / 10.0, size.x - 16, (size.y - 24) / 10.0), Color("244437"))
	var field := Rect2(Vector2(8,12),size-Vector2(16,24))
	draw_rect(field,Color("517366"),false,1.5)
	for ratio in [.13,.32,.50,.68,.87]:
		var y: float = field.position.y+field.size.y*ratio
		draw_line(Vector2(8,y),Vector2(size.x-8,y),Color("517366"),1.0)
	draw_line(Vector2(size.x/2,12),Vector2(size.x/2,size.y-12),Color("365849"),1.0)
	for x in [.22,.78]:
		draw_dashed_line(Vector2(size.x * x,12),Vector2(size.x * x,size.y-12),Color("6a8978"),1.0,7.0)
