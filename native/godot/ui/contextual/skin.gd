extends RefCounted
# Contextual views only render career projections. They never compute outcomes.
const G = preload("res://ui/carnet_skin.gd")
const RoomFactory = preload("res://ui/contextual/rooms/room_factory.gd")
const TEXT = Color("f1f0df")
const MUTED = Color("c0c9b5")
const GOLD = Color("d8c183")
const PANEL = Color(0.055, 0.115, 0.10, 0.94)

static func label(text: Variant, size: int = 16, color: Color = TEXT) -> Label:
	return G.label(text, size, color)

static func wrap(text: Variant, size: int = 15, color: Color = MUTED) -> Label:
	return G.wrap(text, size, color)

static func button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var result := G.button(text, callback, primary)
	result.custom_minimum_size.y = 38
	result.set_meta("contextual_enabled", enabled)
	result.disabled = not enabled
	for state in ["normal", "hover", "pressed"]:
		result.add_theme_stylebox_override(state, G.T.box(Color("bca36a") if primary else PANEL, 4, Color("66745e")))
		result.add_theme_color_override("font_color", Color("152a22") if primary else TEXT)
		result.add_theme_color_override("font_hover_color", Color("152a22") if primary else GOLD)
		result.add_theme_color_override("font_pressed_color", Color("152a22") if primary else GOLD)
	result.add_theme_stylebox_override("disabled", G.T.box(Color("172a23"), 4, Color("53604e")))
	result.add_theme_color_override("font_disabled_color", MUTED)
	return result

static func selected(control: Button, accent: Color = GOLD) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := G.T.box(Color("283e2d"), 4, accent)
		style.border_width_left = 4
		control.add_theme_stylebox_override(state, style)
	control.add_theme_color_override("font_color", GOLD)

static func panel(parent: Node, padding: int = 14) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", G.T.box(PANEL, 5, Color("53624d")))
	parent.add_child(shell)
	var margin := G.margin(padding)
	shell.add_child(margin)
	var column := G.v(8)
	margin.add_child(column)
	return column

static func full(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func frame(parent: Control, padding: int = 20) -> VBoxContainer:
	var margin := G.margin(padding)
	full(margin)
	parent.add_child(margin)
	var column := G.v(10)
	margin.add_child(column)
	return column

static func room(parent: Control, kind: String, club: Dictionary) -> Node3D:
	var container := SubViewportContainer.new()
	container.name = "ContextualRoomViewport"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(container)
	parent.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var world := RoomFactory.build(kind, club)
	if world != null: viewport.add_child(world)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.035, 0.025, 0.21)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(shade)
	parent.add_child(shade)
	return world

static func person(model: Dictionary, id: Variant) -> Dictionary:
	for player: Dictionary in model.get("squad", []):
		if str(player.get("id", "")) == str(id): return player
	var staff: Variant = model.get("staff", [])
	if staff is Dictionary:
		var members: Array = []
		for team: Dictionary in staff.get("teams", []):
			if str(team.get("id", "")) == str(model.get("club", {}).get("id", "")):
				members.append_array(team.get("members", []))
		staff = members
	if staff is Array:
		for member: Dictionary in staff:
			if str(member.get("id", "")) == str(id) or str(member.get("sourceId", member.get("sourceStaffId", ""))) == str(id): return member
	return {}

static func reactions(decision: Dictionary, id: Variant) -> String:
	var rows: Variant = decision.get("reactions", [])
	if rows is Array:
		for reaction: Variant in rows:
			if reaction is Dictionary and str(reaction.get("id", reaction.get("playerId", ""))) == str(id):
				return str(reaction.get("label", reaction.get("text", reaction.get("reaction", ""))))
	return ""

static func heading(parent: Node, club: Dictionary, title: String, subtitle: String) -> void:
	var row := G.h(14)
	parent.add_child(row)
	row.add_child(G.crest(club, 42))
	var words := G.v(2)
	G.fill(words)
	row.add_child(words)
	words.add_child(label(title, 25, GOLD))
	words.add_child(label(subtitle, 13))

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
