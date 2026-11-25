extends SceneTree
## Matières du match 3D (pelouse, tissu des tenues), vérifiées en --headless :
## couleurs des clubs transmises telles quelles au shader des tenues, textures
## importées (res://, avec mipmaps) branchées sur la pelouse et les maillots.

const View = preload("res://match_view.gd")
const Matieres = preload("res://match_matieres.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func fixture() -> Dictionary:
	var players: Array[Dictionary] = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "featured": false,
				"x": 34.0 + side * 21.0 + (slot % 3) * 2.5, "y": 7.0 + slot * 4.0})
	return {"paused": true, "scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 51.0, "y": 35.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}


func run() -> void:
	for texture: Texture2D in [Matieres.PELOUSE_HAUTEUR, Matieres.PELOUSE_NORMAL, Matieres.TISSU_MAILLE]:
		check(texture != null and texture.resource_path.begins_with("res://art/matieres/"), "texture importée : " + str(texture))
		var image := texture.get_image() if texture else null
		check(image != null and image.has_mipmaps(), "mipmaps : " + (texture.resource_path if texture else "?"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var view: NativeMatchView = View.new()
	viewport.add_child(view)
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	var grass: ShaderMaterial = view._grass
	check(grass.shader.resource_path == "res://shaders/stadium_surface.gdshader", "pelouse : shader d'origine")
	check(grass.get_shader_parameter("brins") == Matieres.PELOUSE_HAUTEUR, "pelouse : touffes")
	check(grass.get_shader_parameter("brins_normal") == Matieres.PELOUSE_NORMAL, "pelouse : relief")
	check(grass.get_shader_parameter("taches") is Texture2D, "pelouse : taches")
	var kits: Array = view._kits
	var dressed := 0
	for entry: Dictionary in view._actors.values():
		for mesh: MeshInstance3D in (entry.node as Node).find_children("*", "MeshInstance3D", true, false):
			var material := mesh.material_override as ShaderMaterial
			if material == null or material.shader == null or not material.shader.resource_path.ends_with("athlete_kit.gdshader"):
				continue
			dressed += 1
			var shirt: Color = material.get_shader_parameter("jersey_color")
			var kit: Dictionary = {}
			for candidate: Dictionary in kits:
				if candidate.shirt == shirt:
					kit = candidate
			check(not kit.is_empty(), "maillot : couleur du club %s" % shirt.to_html())
			if kit.is_empty():
				continue
			check(material.get_shader_parameter("panel_color") == (kit.shirt as Color).darkened(0.16), "maillot : panneaux")
			check(material.get_shader_parameter("trim_color") == kit.detail, "maillot : liserés")
			check(material.get_shader_parameter("shorts_color") == kit.get("shorts", Color("202b35")), "maillot : short")
			check(material.get_shader_parameter("socks_color") == kit.shirt, "maillot : chaussettes")
			check(material.get_shader_parameter("maille") == Matieres.TISSU_MAILLE, "maillot : maille")
			check(material.get_shader_parameter("plis") is Texture2D, "maillot : plis")
	check(dressed >= 30, "30 joueurs habillés (%d maillages)" % dressed)
	print("MATCH_MATIERES_CHECKS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
