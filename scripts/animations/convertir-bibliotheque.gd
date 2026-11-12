extends SceneTree
## Convertit la bibliothèque .glb produite par adapter-animations.py en ressource
## Godot (AnimationLibrary .res), forme que le jeu charge sans reconstruire de scène.
## Usage : godot --headless --path native/godot --script ../../scripts/animations/convertir-bibliotheque.gd -- <entree.glb> <sortie.res>
## Ni l'entrée ni la sortie ne vont dans le dépôt (animations Mixamo, licence).

const Animations = preload("res://match_animations.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[1].ends_with(".res"):
		printerr("Usage : -- <entree.glb> <sortie.res>")
		quit(2)
		return
	var source := Animations.lire_gltf(args[0])
	if source.is_empty():
		printerr("Aucune animation lisible dans ", args[0])
		quit(1)
		return
	var bibliotheque := AnimationLibrary.new()
	var noms := source.keys()
	noms.sort()
	for nom: String in noms:
		bibliotheque.add_animation(nom, source[nom])
	var code := ResourceSaver.save(bibliotheque, args[1], ResourceSaver.FLAG_COMPRESS)
	print("BIBLIOTHEQUE ", JSON.stringify({"animations": noms.size(), "sortie": args[1], "code": code}))
	quit(0 if code == OK else 1)
