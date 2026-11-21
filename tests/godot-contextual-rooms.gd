extends SceneTree

const Factory = preload("res://ui/contextual/rooms/room_factory.gd")
const Identity = preload("res://ui/contextual/rooms/room_identity.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func run() -> void:
	var image := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	image.fill(Color("ef3c6b"))
	var crest_path := OS.get_user_data_dir().path_join("oval-contextual-room-test-crest.png")
	check(image.save_png(crest_path) == OK, "create temporary pack crest")
	# Root identity conflicts deliberately: enriched presentation must win.
	var club := {"name":"Root identity", "color":"#ff0000", "presentation":{
		"name":"Club actif", "color":"#176ca4", "abbr":"CA", "logoPath":crest_path}}
	for kind in ["office", "locker", "training"]:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.size = Vector2i(640, 400)
		root.add_child(viewport)
		var room := Factory.build(kind, club)
		check(room != null, kind + " builds")
		check(room.get_meta("primary_color") == Color("176ca4"), kind + " presentation color wins")
		check(room.get_meta("identity").name == "Club actif", kind + " active name")
		var crest: Texture2D = room.get_meta("crest_texture")
		check(crest != null and crest.get_width() == 16 and crest.get_height() == 20, kind + " pack crest")
		viewport.add_child(room)
		await process_frame
		var cameras: Array[Camera3D] = []
		var locker_count := 0
		var textured_surfaces := 0
		for node in descendants(room):
			check(not node is Control and not node is CanvasLayer, kind + " contains background geometry only")
			if node is Camera3D: cameras.append(node)
			if node.name.begins_with("Locker") and node.get_class() == "Node3D": locker_count += 1
			if node is MeshInstance3D and node.material_override is StandardMaterial3D:
				if node.material_override.albedo_texture == crest: textured_surfaces += 1
		check(cameras.size() == 1 and cameras[0].current, kind + " has one current camera")
		check(textured_surfaces > 0, kind + " places actual crest on geometry")
		if kind == "locker":
			check(locker_count == 23, "23 match group lockers")
			check(cameras[0].projection == Camera3D.PROJECTION_PERSPECTIVE, "locker perspective")
			check(cameras[0].position.y > 1.6 and cameras[0].position.y < 2.1, "human-height locker view")
			check(room.kit_material.albedo_color == Color("176ca4"), "all locker jerseys share active kit")
		room.free()
		viewport.free()
	# Each new opening resolves identity independently, with no fictitious default.
	var neutral := Factory.build("locker", {})
	var neutral_crest: Texture2D = neutral.crest_texture
	check(neutral_crest != null and club_crest_matches(neutral_crest, {}), "missing crest shows the club's recoloured crest, never a grey generic shield")
	check(neutral.get_meta("primary_color") == Identity.NEUTRAL_PRIMARY, "missing color stays neutral")
	neutral.free()
	var changed := Factory.build("office", {"name":"Autre club", "color":"#e8ddcc"})
	check(changed.get_meta("primary_color") == Color("e8ddcc"), "club change color is fresh")
	check(changed.get_meta("contrast_color") == Color("252b2e"), "light kit derives dark neutral contrast")
	var changed_club := {"name":"Autre club", "color":"#e8ddcc"}
	check(changed.crest_texture != null and changed.crest_texture != neutral_crest and club_crest_matches(changed.crest_texture, changed_club), "club change renders its own recoloured crest with its colour")
	changed.free()
	DirAccess.remove_absolute(crest_path)
	print("CONTEXTUAL_ROOMS_CHECKS failures=", failures)
	quit(0 if failures == 0 else 1)

## Blason attendu sur une surface 3D : celui du pack ou l'écusson officiel s'il existe, sinon l'écusson recoloré du
## club rendu depuis le contrôle de l'interface (ses initiales, sa couleur), jamais le bouclier gris de la banque.
func club_crest_matches(texture: Texture2D, club: Dictionary) -> bool:
	var Skin = load("res://ui/game_skin.gd")
	var real: Texture2D = Skin.crest_texture(club)
	if real != null: return texture == real
	var shown: Control = Skin.crest_render_control(texture)
	if shown == null or shown.name != "ClubCrestRecolored" or not shown.material is ShaderMaterial: return false
	var identity: Dictionary = club.get("presentation", club) if club.get("presentation") is Dictionary else club
	var initials := false
	for label in shown.find_children("*", "Label", true, false):
		if label.text == str(identity.get("abbr", "XV")): initials = true
	var primary: Color = load("res://ui/contextual/rooms/room_identity.gd").primary(identity)
	var material := shown.material as ShaderMaterial
	var tinted: bool = (material.get_shader_parameter("couleur_base") as Color).is_equal_approx(primary) or (material.get_shader_parameter("couleur_motif") as Color).is_equal_approx(primary)
	return initials and tinted
