extends SceneTree
## Convertit le .glb du Gabi rigué (exporter-gabi-mixamo.py) en scène Godot (.scn), forme que le jeu
## charge par ResourceLoader, sans reconstruire de scène glTF pendant l'exécution (plantage constaté
## sous Forward+ sur Windows avec GLTFDocument).
## Usage : godot --headless --path native/godot --script ../../scripts/animations/convertir-gabi.gd -- <entree.glb> <sortie.scn>
## Ni l'entrée ni la sortie ne vont dans le dépôt public (animations Mixamo, licence).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[1].ends_with(".scn"):
		printerr("Usage : -- <entree.glb> <sortie.scn>")
		quit(2)
		return
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(args[0], etat) != OK:
		printerr("Lecture glTF impossible : ", args[0])
		quit(1)
		return
	var scene := document.generate_scene(etat) as Node3D
	if scene == null:
		printerr("Aucune scène dans ", args[0])
		quit(1)
		return
	scene.name = "GabiMixamo"
	var textures := {}
	for noeud: Node in scene.find_children("*", "", true, false):
		noeud.owner = scene
		var maillage := noeud as MeshInstance3D
		if maillage == null or maillage.mesh == null:
			continue
		for surface in maillage.mesh.get_surface_count():
			var materiau := maillage.mesh.surface_get_material(surface) as BaseMaterial3D
			if materiau == null:
				continue
			for propriete in ["albedo_texture", "roughness_texture", "metallic_texture", "normal_texture", "emission_texture"]:
				var texture := materiau.get(propriete) as ImageTexture
				if texture == null or textures.has(texture):
					continue
				textures[texture] = true
				# Le portrait est petit (152 à 320 px) : sans mipmaps, la barbe et les yeux scintillent.
				var image := texture.get_image()
				if image != null and not image.has_mipmaps():
					image.generate_mipmaps()
					texture.set_image(image)
	var lecteur := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips: PackedStringArray = lecteur.get_animation_list() if lecteur else PackedStringArray()
	var formes := 0
	for noeud: Node in scene.find_children("*", "MeshInstance3D", true, false):
		if (noeud as MeshInstance3D).find_blend_shape_by_name(&"MouthOpen") >= 0:
			formes += 1
	var paquet := PackedScene.new()
	var code := paquet.pack(scene)
	if code == OK:
		code = ResourceSaver.save(paquet, args[1], ResourceSaver.FLAG_COMPRESS)
	print("GABI ", JSON.stringify({"animations": clips.size(), "textures": textures.size(), "bouche": formes, "sortie": args[1], "code": code}))
	scene.free()
	quit(0 if code == OK and clips.size() > 0 and formes > 0 else 1)
