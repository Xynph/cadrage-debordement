extends SceneTree

const View = preload("res://match_view.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func run() -> void:
	var path := OS.get_user_data_dir().path_join("oval-match-club-crest.png")
	var image := Image.create(30, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color("c52d57"))
	check(image.save_png(path) == OK, "temporary active pack crest")
	var club := {"logoPath":OS.get_user_data_dir().path_join("missing-root-crest.png"), "presentation":{
		"name":"Club actif", "logoPath":path, "color":"#116699"}}
	var before := club.duplicate(true)
	var view := View.new()
	view.set_club_identity(club)
	root.add_child(view)
	await process_frame
	view.set_process(false)
	var batch := view.get_node("ManagedClubCrests") as MultiMeshInstance3D
	check(batch != null and batch.visible, "actual club crest batch visible at ready")
	check(batch.multimesh.instance_count == 1, "stadium fascia receives the managed club crest")
	var material := batch.material_override as StandardMaterial3D
	check(material.albedo_texture != null and material.albedo_texture.get_width() == 30,
		"active presentation pack crest wins over root identity")
	check(material.albedo_texture.get_height() == 40, "texture retains source shape")
	var adverts := view.find_children("*", "Label3D", true, false)
	check(adverts.size() == 16, "sixteen perimeter advertising boards")
	for advert in adverts:
		check(advert.text == "RUGBY LEGACY 27", "advertising boards retain Rugby Legacy 27")
	# Dummy/headless rendering does not retain GPU MultiMesh transforms. Physical
	# placement/aspect are verified in the real rendered contextual captures.
	var batch_id := batch.get_instance_id()
	var mesh_id := batch.multimesh.get_instance_id()
	var children_count := view.get_child_count()
	for tick in 100:
		view.set_club_identity(club)
	check(batch.get_instance_id() == batch_id and batch.multimesh.get_instance_id() == mesh_id,
		"repeated frames retain static branding batch")
	check(view.get_child_count() == children_count, "no scene rebuild or extra nodes per identity refresh")
	check(club == before, "club presentation data is not mutated")
	var without_crest := {"name":"Sans blason", "abbr":"SB", "color":"#aa4455"}
	view.set_club_identity(without_crest)
	check(batch.visible and club_crest_matches(material.albedo_texture, without_crest), "missing crest shows the club's recoloured crest with its initials, never a grey shield")
	view.set_club_identity(club)
	check(batch.visible and material.albedo_texture != null, "club pack restored without rebuilding stadium")
	view.free()
	DirAccess.remove_absolute(path)
	print("MATCH_CLUB_BRANDING_CHECKS ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

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
