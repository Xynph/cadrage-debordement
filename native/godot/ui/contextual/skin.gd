extends RefCounted
# Contextual views only render career projections. They never compute outcomes.
const G = preload("res://ui/carnet_skin.gd")
const RoomFactory = preload("res://ui/contextual/rooms/room_factory.gd")
const Base = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
# Jetons de la charte (design/art/art-bible.md) : crème, gris-vert et doré sur panneaux noirs.
const TEXT = Charte.CREME
const MUTED = Charte.GRIS_VERT
const GOLD = Charte.DORE
const PRIMARY_FILL = Charte.DORE
const PANEL = Charte.PANNEAU

static func label(text: Variant, size: int = 16, color: Color = TEXT) -> Label:
	return G.label(text, size, color)

static func wrap(text: Variant, size: int = 15, color: Color = MUTED) -> Label:
	return G.wrap(text, size, color)

## Bouton pilule : à contour (secondaire) ou doré (l'unique bouton principal).
static func button(text: String, callback: Callable, enabled: bool = true, primary: bool = false) -> Button:
	var result := G.button(text, callback, primary)
	result.custom_minimum_size.y = 38
	result.set_meta("contextual_enabled", enabled)
	result.disabled = not enabled
	var fonds := {"normal": PRIMARY_FILL if primary else Color.TRANSPARENT, "hover": Charte.OR_VIF if primary else Charte.PANNEAU_2,
		"pressed": Charte.OR_VIF if primary else Charte.PANNEAU_3}
	var cles := {"normal": "font_color", "hover": "font_hover_color", "pressed": "font_pressed_color"}
	for state in fonds:
		result.add_theme_stylebox_override(state, Charte.style_pilule(fonds[state], PRIMARY_FILL if primary else Charte.FILET, 16, 6))
		result.add_theme_color_override(cles[state], Charte.ENCRE if primary else (TEXT if state == "normal" else GOLD))
	result.add_theme_stylebox_override("disabled", Charte.style_pilule(Color.TRANSPARENT, Charte.FILET, 16, 6))
	result.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	result.add_theme_font_override("font", Charte.TEXTE)
	return result

## Choix retenu : pilule à voile doré, contour et texte dorés (le contour dit l'état, pas seulement la couleur).
static func selected(control: Button, _accent: Color = GOLD) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := Charte.style_pilule(Charte.VOILE_DORE, GOLD, 16, 6)
		style.set_border_width_all(2)
		control.add_theme_stylebox_override(state, style)
	control.add_theme_color_override("font_color", GOLD)

static func panel(parent: Node, padding: int = 14) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", Charte.style_panneau(PANEL, Charte.RAYON_PANNEAU, 0))
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
	shade.color = Color(Charte.NUIT, 0.21)
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
