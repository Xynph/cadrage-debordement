extends SceneTree
## Gabi rigué par Mixamo (coach_portrait_3d.gd), vérifié en --headless.
## 1. Sans fichier (ni variable, ni dossier animations/) : le Gabi d'origine, inchangé.
## 2. Variable vers un fichier absent ou sans clip « repos » : Gabi d'origine, simple avertissement.
## 3. Avec une scène fabriquée ici (noms de clips du Gabi Mixamo, clips vides, bouche à quatre
##    formes) : chargement par la variable ou par le dossier fixe, puis choix des clips (salut,
##    explications variées, parole tirée au hasard, microgestes, approbation, mouvement réduit).
## Aucun contenu Mixamo n'est nécessaire ni présent dans le dépôt.

const Portrait3D = preload("res://guide/coach_portrait_3d.gd")
const PrivateFiles = preload("res://donnees_privees.gd")
const Animations = preload("res://match_animations.gd")
const MIXAMO_CLIPS := [&"repos", &"repos_respire", &"appui", &"parle", &"parle_2", &"parle_3", &"parle_4",
	&"explique", &"insiste", &"argumente", &"reflechit", &"approuve", &"approuve_fort", &"refuse", &"hausse",
	&"sceptique", &"montre", &"salut", &"remercie", &"decu", &"rit", &"surpris", &"content", &"tablette",
	&"regarde_bas", &"baille", &"applaudit"]
const TALKS := ["parle", "parle_2", "parle_3", "parle_4"]
const EXPLANATIONS := ["explique", "montre", "insiste"]
const MICROGESTURES := ["regarde_bas", "appui", "reflechit", "repos_respire", "baille"]

var failures: Array[String] = []
var checks := 0
var folder := ""


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_warning("ÉCHEC : " + label)


func _scene(clip_names: Array, with_mouth: bool) -> PackedScene:
	var scene := Node3D.new()
	scene.name = "GabiEssai"
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	scene.add_child(player)
	player.owner = scene
	var library := AnimationLibrary.new()
	for clip_name: StringName in clip_names:
		var clip := Animation.new()
		clip.length = 1.0
		library.add_animation(clip_name, clip)
	player.add_animation_library(&"", library)
	if with_mouth:
		var mesh := ArrayMesh.new()
		for shape: StringName in Portrait3D.MOUTH_SHAPES:
			mesh.add_blend_shape(shape)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		var shapes := []
		for shape in Portrait3D.MOUTH_SHAPES:
			var moved := []
			moved.resize(Mesh.ARRAY_MAX)
			moved[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP * 1.2])
			shapes.append(moved)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
		var face := MeshInstance3D.new()
		face.name = "Visage"
		face.mesh = mesh
		scene.add_child(face)
		face.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	return packed


func _save(packed: PackedScene, path: String) -> String:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(ResourceSaver.save(packed, path) == OK, "Scène d'essai enregistrée : " + path)
	return path


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0] if not args.is_empty() else OS.get_cache_dir().path_join("cd-gabi-mixamo-essai")
	DirAccess.make_dir_recursive_absolute(folder)
	OS.unset_environment(Portrait3D.MIXAMO_VARIABLE)
	OS.unset_environment("CD_MATCH_ANIMATIONS")
	var origin: PackedScene = load(Portrait3D.MODEL_PATH) if ResourceLoader.exists(Portrait3D.MODEL_PATH, "PackedScene") else null

	# 1. Aucun fichier : rien ne change.
	var empty_game := folder.path_join("jeu-vide")
	DirAccess.make_dir_recursive_absolute(empty_game)
	check(PrivateFiles.chemin(Portrait3D.MIXAMO_VARIABLE, Portrait3D.MIXAMO_FILE, empty_game) == "", "Sans variable ni fichier : aucun chemin")
	check(Portrait3D.load_model(empty_game) == origin, "Sans fichier : Gabi d'origine")
	check(Portrait3D.load_model() == origin, "Sans fichier à côté de l'exécutable : Gabi d'origine")
	check(Animations.chemin() == "" and not Animations.demande(), "Match : aucune bibliothèque sans variable ni fichier")

	# 2. Variable vers un fichier absent, puis vers une scène sans les clips du Gabi Mixamo.
	OS.set_environment(Portrait3D.MIXAMO_VARIABLE, folder.path_join("absent.scn"))
	check(Portrait3D.load_model(empty_game) == origin, "Fichier absent : Gabi d'origine")
	var wrong := _save(_scene([&"Repos", &"Approbation"], true), folder.path_join("sans-repos.scn"))
	OS.set_environment(Portrait3D.MIXAMO_VARIABLE, wrong)
	check(Portrait3D.load_model(empty_game) == origin, "Scène sans clip « repos » : Gabi d'origine")

	# 3a. Variable vers une scène valable.
	var valid := _save(_scene(MIXAMO_CLIPS, true), folder.path_join("gabi-mixamo-essai.scn"))
	OS.set_environment(Portrait3D.MIXAMO_VARIABLE, valid)
	var by_variable := Portrait3D.load_model(empty_game)
	check(by_variable != null and by_variable != origin and by_variable.resource_path == valid, "La variable charge la scène du Gabi Mixamo")

	# 3b. Dossier fixe à côté de l'exécutable, sans variable.
	OS.unset_environment(Portrait3D.MIXAMO_VARIABLE)
	var game := folder.path_join("jeu")
	var fixed := _save(_scene(MIXAMO_CLIPS, true), game.path_join("animations").path_join(Portrait3D.MIXAMO_FILE))
	check(PrivateFiles.chemin(Portrait3D.MIXAMO_VARIABLE, Portrait3D.MIXAMO_FILE, game) == fixed, "Dossier fixe : chemin trouvé")
	var by_folder := Portrait3D.load_model(game)
	check(by_folder != null and by_folder.resource_path == fixed, "Dossier fixe : scène chargée sans variable")
	var match_file := game.path_join("animations").path_join(Animations.FICHIER)
	FileAccess.open(match_file, FileAccess.WRITE).store_string("essai")
	check(PrivateFiles.chemin("CD_MATCH_ANIMATIONS", Animations.FICHIER, game) == match_file, "Dossier fixe : bibliothèque du match trouvée")
	OS.set_environment("CD_MATCH_ANIMATIONS", "/ailleurs/mixamo-match.res")
	check(PrivateFiles.chemin("CD_MATCH_ANIMATIONS", Animations.FICHIER, game) == "/ailleurs/mixamo-match.res", "La variable prime sur le dossier fixe")
	OS.unset_environment("CD_MATCH_ANIMATIONS")

	_check_origin_profile()
	_check_mixamo_profile(by_variable)
	print("GABI_MIXAMO_CHECKS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(1 if failures else 0)


func _check_origin_profile() -> void:
	var portrait := Portrait3D.new()
	portrait.model = _scene([&"Repos", &"Approbation", &"Salut", &"Explication", &"Ecoute", &"RegardCarnet"], false)
	root.add_child(portrait)
	var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player.current_animation == "Repos" and portrait._talks.is_empty(), "Gabi d'origine : repos, aucun geste de parole")
	check(portrait._microgesture_wait >= 7.0 and portrait._microgesture_wait <= 13.0, "Gabi d'origine : délai des microgestes inchangé")
	portrait.set_speaking(true)
	check(player.current_animation == "Repos", "Gabi d'origine : la parole ne change pas le geste")
	portrait.set_speaking(false)
	portrait.free()


func _check_mixamo_profile(packed: PackedScene) -> void:
	var portrait := Portrait3D.new()
	portrait.model = packed
	root.add_child(portrait)
	var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player != null and player.current_animation == "repos", "Gabi Mixamo : repos au démarrage")
	if player == null: return
	check(player.get_animation("repos").loop_mode == Animation.LOOP_LINEAR and player.get_animation("parle").loop_mode == Animation.LOOP_NONE,
		"Repos en boucle, gestes joués une fois")
	check(portrait._microgesture_wait >= 3.0 and portrait._microgesture_wait <= 6.0 and portrait.is_processing(),
		"Microgeste suivant dans trois à six secondes")

	portrait.request_gesture(true)
	check(player.current_animation == "salut", "Première ouverture : salut")
	portrait.set_speaking(true)
	check(player.current_animation == "salut", "La parole laisse finir le salut")
	player.advance(1.2)
	var first_talk := player.current_animation
	check(first_talk in TALKS and not portrait.is_processing(), "Après le salut, Gabi parle avec un geste de parole")
	player.advance(1.2)
	check(player.current_animation in TALKS and player.current_animation != first_talk, "Les gestes de parole s'enchaînent sans se répéter")
	portrait.set_articulation(1.0, 0.5)
	var face := portrait.find_child("Visage", true, false) as MeshInstance3D
	check(face != null and is_equal_approx(face.get_blend_shape_value(0), 1.0) and is_equal_approx(face.get_blend_shape_value(1), 0.5),
		"La bouche suit toujours l'articulation")
	portrait.set_speaking(false)
	check(player.current_animation == "repos" and portrait.is_processing(), "Fin de parole : retour au repos et au minuteur")
	check(face != null and is_zero_approx(face.get_blend_shape_value(0)), "Fin de parole : bouche fermée")

	var sequence: Array[String] = []
	for i in 8:
		portrait._process(6.1)
		sequence.append(player.current_animation)
		player.advance(1.2)
	check(sequence.all(func(clip: String) -> bool: return clip in MICROGESTURES), "Le minuteur ne joue que des petits gestes de repos")
	check(sequence.count("baille") == 1, "Un seul bâillement sur huit microgestes")
	for clip in MICROGESTURES:
		check(clip in sequence, "Microgeste joué : " + clip)
	check(player.current_animation == "repos", "Chaque microgeste revient au repos")

	portrait._process(6.1)
	check(player.current_animation in MICROGESTURES, "Microgeste en cours")
	portrait.set_speaking(true)
	check(player.current_animation in TALKS, "La parole interrompt un microgeste")
	portrait.set_speaking(false)

	portrait.request_gesture(false)
	var first_explanation := player.current_animation
	check(first_explanation in EXPLANATIONS, "Explication tirée parmi explique, montre, insiste")
	player.advance(1.2)
	portrait.request_gesture(true)
	check(player.current_animation in EXPLANATIONS and player.current_animation != first_explanation,
		"Réouverture : une autre explication, pas de second salut")
	player.advance(1.2)

	portrait.set_context("composition")
	check(player.current_animation in ["approuve", "approuve_fort"], "Composition : approbation")
	portrait.request_gesture(false)
	check(player.current_animation in ["approuve", "approuve_fort"], "Une demande rapprochée respecte l'approbation")
	player.advance(1.2)
	check(player.current_animation == "repos", "Retour au repos après l'approbation")

	portrait.set_reduced_motion(true)
	portrait.set_speaking(true)
	check(not player.is_playing() and not portrait.is_processing(), "Mouvement réduit : ni geste de parole ni minuteur")
	portrait.set_reduced_motion(false)
	check(player.current_animation in TALKS, "Reprise du mouvement pendant la parole : geste de parole")
	portrait.set_speaking(false)
	portrait.hide()
	check(not player.is_playing() and not portrait.is_processing(), "Guide masqué : tout est suspendu")
	portrait.show()
	check(player.current_animation == "repos", "Réouverture au repos")
	portrait.free()
