extends SceneTree
## Gabi rigué par Mixamo (coach_portrait_3d.gd), vérifié en --headless.
## 1. Sans fichier (ni variable, ni dossier animations/) : le Gabi d'origine, inchangé.
## 2. Variable vers un fichier absent ou sans clip « repos » : Gabi d'origine, simple avertissement.
## 3. Avec une scène fabriquée ici (noms de clips du Gabi Mixamo, clips vides, bouche à quatre
##    formes, yeux, paupières et formes du regard chaleureux) : chargement par la variable ou par le
##    dossier fixe, puis gestes cohérents avec le moment (gabi_moments.gd), parole, attente selon le
##    ton, regard, clignements, sourire, mouvement réduit.
## Aucun contenu Mixamo n'est nécessaire ni présent dans le dépôt.

const Portrait3D = preload("res://guide/coach_portrait_3d.gd")
const PrivateFiles = preload("res://donnees_privees.gd")
const Animations = preload("res://match_animations.gd")
const Moments = preload("res://guide/gabi_moments.gd")
const Content = preload("res://guide/guide_content.gd")
## Les 41 clips du Gabi Mixamo (noms seulement ; clips vides fabriqués par le test).
const MIXAMO_CLIPS := [&"repos", &"repos_respire", &"appui", &"parle", &"parle_2", &"parle_3", &"parle_4",
	&"parle_5", &"parle_7", &"parle_8", &"explique", &"insiste", &"argumente", &"reflechit", &"approuve",
	&"approuve_fort", &"refuse", &"hausse", &"sceptique", &"montre", &"salut", &"remercie", &"decu", &"rit",
	&"surpris", &"content", &"tablette", &"regarde_bas", &"baille", &"applaudit", &"marche", &"tourne_g",
	&"tourne_d", &"assis_debout", &"debout_assis", &"assis_parle", &"assis_pouce", &"pouce", &"telephone",
	&"telephone_marche", &"bras_croises"]
const TALKS := ["parle", "parle_2", "parle_3", "parle_4", "parle_5", "parle_7", "parle_8"]
const WAITS := ["repos_respire", "appui", "regarde_bas", "reflechit"]
const RARE := ["tablette"]
const NEVER := ["bras_croises", "assis_debout", "debout_assis", "assis_parle", "assis_pouce", "marche",
	"tourne_g", "tourne_d", "telephone", "telephone_marche", "rit", "decu", "baille", "applaudit"]

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


func _mesh(shape_names: Array, center := Vector3.ZERO) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for shape: StringName in shape_names:
		mesh.add_blend_shape(shape)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([center + Vector3(-0.01, 0, 0.01), center + Vector3(0.01, 0, 0.01), center + Vector3(0, 0.01, 0.012)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var shapes := []
	for shape in shape_names:
		var moved := []
		moved.resize(Mesh.ARRAY_MAX)
		moved[Mesh.ARRAY_VERTEX] = PackedVector3Array([center, center + Vector3.RIGHT * 0.01, center + Vector3.UP * 0.012])
		moved[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		shapes.append(moved)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	return mesh


func _add_mesh(scene: Node3D, node_name: String, mesh: ArrayMesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	scene.add_child(instance)
	instance.owner = scene


func _scene(clip_names: Array, with_mouth: bool, with_face := false, with_smile := false) -> PackedScene:
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
		var mouth_shapes: Array = Portrait3D.MOUTH_SHAPES + ([&"Sourire"] if with_smile else [])
		for shape: StringName in mouth_shapes:
			mesh.add_blend_shape(shape)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
		var shapes := []
		for shape in mouth_shapes:
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
	if with_face:
		# Yeux sans formes (le portrait construit celles du regard), paupières et formes chaleureuses.
		_add_mesh(scene, "Gabi_Oeil_D", _mesh([], Vector3(-0.03, 1.58, 0.09)))
		_add_mesh(scene, "Gabi_Oeil_G", _mesh([], Vector3(0.03, 1.58, 0.09)))
		_add_mesh(scene, "Gabi_Paupieres_D", _mesh([&"Clignement"]))
		_add_mesh(scene, "Sourire", _mesh([&"SourireYeux", &"SourcilsDoux"]))
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
	var valid := _save(_scene(MIXAMO_CLIPS, true, true), folder.path_join("gabi-mixamo-essai.scn"))
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

	_check_table()
	_check_origin_profile()
	_check_head_texture(origin)
	_check_mixamo_profile(by_variable)
	_check_mouth(load(_save(_scene(MIXAMO_CLIPS, true, true, true), folder.path_join("gabi-bouche-essai.scn"))))
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
	portrait.set_moment(Moments.moment("finances", "decision-tresorerie"))
	check(player.current_animation == "RegardCarnet", "Gabi d'origine : mauvaise nouvelle, regard vers le carnet")
	portrait.set_moment(Moments.moment("recrutement", "decision-contrat"))
	check(player.current_animation == "Approbation", "Gabi d'origine : signature, approbation")
	portrait.set_moment(Moments.moment("tactique", "tactique-01"))
	check(player.current_animation == "Explication", "Gabi d'origine : consigne tactique, explication")
	check(portrait.visage != null and not portrait.visage.has_shape(&"Clignement"), "Gabi d'origine sans formes du visage : rien ne casse")
	portrait.free()


## Netteté de la tête (scripts/animations/nettete-tete-gabi.py) : visage, barbe, sourcils et cheveux ont leur propre
## matériau (Gabi_Tete) avec une couleur et une carte de normales 2K, sur Mesh_0, avec les mêmes formes d'expression.
func _check_head_texture(origin: PackedScene) -> void:
	if origin == null:
		return
	var scene := origin.instantiate()
	var head: StandardMaterial3D = null
	var body: MeshInstance3D = null
	for mesh_instance: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if material != null and material.resource_name == "Gabi_Tete":
				head = material
				body = mesh_instance
	check(head != null, "Tête : matériau Gabi_Tete présent")
	if head != null:
		check(head.albedo_texture != null and head.albedo_texture.get_width() >= 2048, "Tête : couleur 2K dédiée")
		check(head.normal_enabled and head.normal_texture != null and head.normal_texture.get_width() >= 2048, "Tête : carte de normales 2K")
		check(body.find_blend_shape_by_name(&"Clignement") >= 0 and body.find_blend_shape_by_name(&"MouthOpen") >= 0, "Tête : formes d'expression conservées")
	scene.free()

func _check_table() -> void:
	# Toutes les bulles du jeu ont une catégorie ; chaque catégorie n'appelle que des clips existants.
	var content = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	var missing: Array[String] = []
	for page in content.pages:
		for fragment in page.fragments:
			if not Moments.BULLES.has(fragment.id): missing.append(fragment.id)
	check(missing.is_empty(), "Chaque bulle de dialogues.json a son moment : " + str(missing))
	for category in Moments.CATEGORIES:
		for clip in Moments.gestures(category, "mixamo"):
			check(clip in MIXAMO_CLIPS and str(clip) not in NEVER, "Geste de « %s » connu et autorisé : %s" % [category, clip])
		check(not Moments.gestures(category, "origine").is_empty(), "Geste d'origine pour « %s »" % category)
	for clip in Moments.ATTENTE.mixamo + Moments.ATTENTE.mixamo_rares + Moments.ATTENTE.mixamo_negatif:
		check(str(clip) not in NEVER, "Attente autorisée : " + str(clip))
	check(not Moments.ATTENTE.mixamo_negatif.has(&"tablette") and not Moments.ATTENTE.mixamo_negatif.has(&"baille"),
		"Mauvaise nouvelle : ni tablette ni bâillement dans l'attente")
	var won := {"club": {"id": 7}, "live": {"finished": true, "pair": [7, 3], "score": [24, 10]}}
	var lost := {"club": {"id": 7}, "live": {"finished": true, "pair": [3, 7], "score": [24, 10]}}
	var drawn := {"club": {"id": 7}, "live": {"finished": true, "pair": [3, 7], "score": [12, 12]}}
	check(Moments.moment("resultat", "resultat-caractere", won).categorie == "bonne_nouvelle", "Victoire : bonne nouvelle")
	var defeat := Moments.moment("resultat", "resultat-caractere", lost)
	check(defeat.categorie == "mauvaise_nouvelle" and defeat.ton == Moments.NEGATIF, "Défaite : mauvaise nouvelle, ton négatif")
	check(Moments.moment("resultat", "resultat-01", lost).ton == Moments.NEGATIF, "Défaite : la suite de la page garde un ton grave")
	check(Moments.moment("resultat", "resultat-caractere", drawn).categorie == "souvenir", "Nul : Gabi réfléchit")
	check(Moments.moment("resultat", "resultat-caractere", {}).categorie == "consigne", "Résultat inconnu : simple consigne")
	check(Moments.moment("recrutement", "decision-contrat").categorie == "bonne_nouvelle", "Signature : bonne nouvelle")
	check(Moments.moment("finances", "decision-tresorerie").ton == Moments.NEGATIF, "Caisse dans le rouge : ton négatif")
	check(Moments.moment("bienvenue", "bienvenue-caractere").categorie == "accueil", "Première bulle : accueil")
	check(Moments.moment("recrutement", "recrutement-01").categorie == "question", "Une piste te plaît ? : question")
	check(Moments.moment("composition", "").categorie == "approbation", "Composition sans bulle : approbation (comme avant)")


func _in(player: AnimationPlayer, clips: Array) -> bool:
	return player.current_animation in clips.map(func(clip) -> String: return str(clip))


func _check_mixamo_profile(packed: PackedScene) -> void:
	var portrait := Portrait3D.new()
	portrait.model = packed
	root.add_child(portrait)
	var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(player != null and player.current_animation == "repos", "Gabi Mixamo : repos au démarrage")
	if player == null: return
	var visage = portrait.visage
	var face := portrait.find_child("Visage", true, false) as MeshInstance3D
	check(player.get_animation("repos").loop_mode == Animation.LOOP_LINEAR and player.get_animation("parle").loop_mode == Animation.LOOP_NONE,
		"Repos en boucle, gestes joués une fois")
	check(portrait._microgesture_wait >= 3.0 and portrait._microgesture_wait <= 6.0 and portrait.is_processing(),
		"Petit geste suivant dans trois à six secondes")

	# Visage : formes construites ou trouvées par leur nom.
	for shape in [&"RegardGauche", &"RegardDroite", &"RegardHaut", &"RegardBas", &"Clignement", &"SourireYeux", &"SourcilsDoux"]:
		check(visage.has_shape(shape), "Forme pilotée : " + str(shape))
	check(is_equal_approx(visage.shape_value(&"SourireYeux"), visage.EYE_SMILE_REST) and is_equal_approx(visage.shape_value(&"SourcilsDoux"), visage.SOFT_BROWS_REST),
		"Regard chaleureux au repos")

	portrait.set_moment(Moments.moment("bienvenue", "bienvenue-caractere"))
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
	check(face != null and is_equal_approx(face.get_blend_shape_value(0), 1.0) and is_equal_approx(face.get_blend_shape_value(1), 0.5),
		"La bouche suit toujours l'articulation")
	visage.smile_now(1.0)
	visage._process(1.0)
	check(is_equal_approx(face.get_blend_shape_value(1), 0.5) and is_zero_approx(visage.smile), "Pendant la parole, pas de sourire : la synchronisation labiale garde la bouche")
	portrait.set_speaking(false)
	check(player.current_animation == "repos" and portrait.is_processing(), "Fin de parole : retour au repos et au minuteur")
	check(face != null and is_zero_approx(face.get_blend_shape_value(0)) and is_zero_approx(face.get_blend_shape_value(3)), "Fin de parole : bouche fermée")

	# Chaque moment joue un geste de sa catégorie.
	var checks_by_moment := [
		["tactique", "tactique-01", Moments.CATEGORIES.consigne.mixamo],
		["recrutement", "decision-contrat", Moments.CATEGORIES.bonne_nouvelle.mixamo],
		["finances", "decision-tresorerie", Moments.CATEGORIES.mauvaise_nouvelle.mixamo],
		["recrutement", "recrutement-01", Moments.CATEGORIES.question.mixamo],
		["presse", "presse-01", Moments.CATEGORIES.mise_en_garde.mixamo],
		["formation", "formation-01", Moments.CATEGORIES.regret.mixamo],
		["composition", "composition-caractere", Moments.CATEGORIES.approbation.mixamo],
	]
	for entry in checks_by_moment:
		portrait.set_moment(Moments.moment(entry[0], entry[1]))
		check(_in(player, entry[2]), "Moment %s : geste %s parmi %s" % [entry[1], player.current_animation, entry[2]])
		portrait.request_gesture(false)
		check(_in(player, entry[2]), "Une demande rapprochée respecte le geste du moment : " + entry[1])
		player.advance(1.2)
	check(player.current_animation == "repos", "Retour au repos après le geste du moment")

	# Même bulle rafraîchie : pas de nouveau geste ; bulle demandée de nouveau : geste de la catégorie.
	portrait.set_moment(Moments.moment("composition", "composition-caractere"))
	check(player.current_animation == "repos", "Rafraîchir la même bulle ne rejoue pas de geste")
	portrait.request_gesture(true)
	check(_in(player, Moments.CATEGORIES.approbation.mixamo), "Réouverture : geste du moment, pas de second salut")
	player.advance(1.2)

	# Variété sans répétition immédiate entre gestes équivalents.
	var played: Array[String] = []
	for i in 12:
		portrait.set_moment({"id": "essai-%d" % i, "categorie": "consigne", "ton": Moments.NEUTRE})
		played.append(player.current_animation)
		player.advance(1.2)
	var repeated := false
	for i in range(1, played.size()): repeated = repeated or played[i] == played[i - 1]
	check(not repeated and played.all(func(clip: String) -> bool: return clip in ["explique", "montre", "insiste", "argumente"]),
		"Consignes variées, jamais deux fois de suite le même geste : " + str(played))

	# Attente, ton neutre : petits gestes, rares au plus un sur six, aucun geste interdit.
	portrait.set_moment(Moments.moment("bureau", "bureau-01"))
	player.advance(1.2)
	var waits: Array[String] = []
	for i in 36:
		portrait._process(6.1)
		waits.append(player.current_animation)
		player.advance(1.2)
	check(waits.all(func(clip: String) -> bool: return clip in WAITS + RARE), "Attente : seulement des petits gestes cohérents")
	check(waits.filter(func(clip: String) -> bool: return clip in RARE).size() <= 36 / 6, "Tablette et bâillement restent rares")
	check(NEVER.all(func(clip: String) -> bool: return clip not in waits), "Bras croisés et gestes hors cadre jamais joués")
	var waits_repeat := false
	for i in range(1, waits.size()): waits_repeat = waits_repeat or waits[i] == waits[i - 1]
	check(not waits_repeat, "Attente sans répéter deux fois de suite le même geste")

	# Mauvaise nouvelle : jamais tablette ni bâillement, ni sourire.
	portrait.set_moment(Moments.moment("finances", "decision-tresorerie"))
	player.advance(1.2)
	var sad_waits: Array[String] = []
	for i in 24:
		portrait._process(6.1)
		sad_waits.append(player.current_animation)
		player.advance(1.2)
	check(sad_waits.all(func(clip: String) -> bool: return clip in Moments.ATTENTE.mixamo_negatif.map(func(c): return str(c))),
		"Mauvaise nouvelle : attente sobre, sans tablette ni bâillement")
	visage.smile_now(1.0)
	for i in 40: visage._process(0.1)
	check(is_zero_approx(visage.smile) and is_zero_approx(face.get_blend_shape_value(3)) and is_zero_approx(visage.shape_value(&"SourireYeux")),
		"Mauvaise nouvelle : ni sourire ni sourire des yeux")

	# Ton positif : sourire franc, sans toucher à la bouche pendant la parole.
	portrait.set_moment(Moments.moment("recrutement", "decision-contrat"))
	for i in 10: visage._process(0.1)
	check(visage.smile > 0.5 and face.get_blend_shape_value(3) > 0.3 and visage.shape_value(&"SourireYeux") > visage.EYE_SMILE_REST,
		"Bonne nouvelle : sourire (MouthWide %.2f, SourireYeux %.2f)" % [face.get_blend_shape_value(3), visage.shape_value(&"SourireYeux")])
	player.advance(1.2)

	# Ton neutre : un léger sourire revient de lui-même, de temps en temps.
	portrait.set_moment(Moments.moment("bureau", "bureau-02"))
	var smiled := false
	for i in 300:
		visage._process(0.1)
		smiled = smiled or visage.smile > 0.2
	check(smiled, "Ton neutre : un petit sourire de temps en temps")

	# Clignements : la forme se ferme puis se rouvre, au moins une fois en six secondes.
	var closed := false
	var reopened := false
	for i in 130:
		visage._process(0.05)
		if visage.shape_value(&"Clignement") > 0.95: closed = true
		elif closed and visage.shape_value(&"Clignement") < 0.05: reopened = true
	check(closed and reopened, "Clignement complet en moins de 6,5 s")

	# Regard : saccades autour du joueur, carnet consulté, puis retour.
	player.advance(1.2)
	check(player.current_animation == "repos", "Repos avant le contrôle du regard")
	# Les saccades sont tirées au hasard (attente 0,7 à 2,6 s, 30 % pile dans les yeux, sinon petit décalage) :
	# une fenêtre fixe de 3 s pouvait ne contenir aucun décalage mesurable. On observe jusqu'à 12 s, sans rien
	# relâcher sur le contrat : un décalage > 0,05 apparaît, et le regard reste petit (< 0,5) vers le joueur.
	var moved := false
	for i in 240:
		visage._process(0.05)
		moved = moved or visage.gaze.length() > 0.05
		if moved: break
	check(moved and visage.gaze.length() < 0.5 and visage.look == "joueur", "Petites saccades autour du joueur")
	portrait._play_gesture(&"regarde_bas")
	for i in 20: visage._process(0.05)
	check(visage.look == "carnet" and visage.shape_value(&"RegardBas") > 0.6, "Regard vers le carnet quand il le consulte")
	check(visage.shape_value(&"Clignement") >= visage.LID_FOLLOW * visage.shape_value(&"RegardBas") - 0.01,
		"La paupière supérieure suit le regard vers le bas")
	player.advance(1.2)
	for i in 20: visage._process(0.05)
	check(visage.look == "joueur" and visage.shape_value(&"RegardBas") < 0.5, "Le regard revient vers le joueur")

	portrait.set_reduced_motion(true)
	portrait.set_speaking(true)
	check(not player.is_playing() and not portrait.is_processing() and not visage.is_processing(), "Mouvement réduit : ni geste, ni minuteur, ni regard animé")
	check(is_zero_approx(visage.shape_value(&"Clignement")) and visage.gaze == Vector2.ZERO, "Mouvement réduit : yeux ouverts, regard droit")
	portrait.set_reduced_motion(false)
	check(player.current_animation in TALKS and visage.is_processing(), "Reprise du mouvement pendant la parole : geste de parole")
	portrait.set_speaking(false)
	portrait.hide()
	check(not player.is_playing() and not portrait.is_processing() and not visage.is_processing(), "Guide masqué : tout est suspendu")
	portrait.show()
	check(player.current_animation == "repos", "Réouverture au repos")
	portrait.free()


## Bouche (12 novembre) : forme « Sourire », lèvres entrouvertes au repos, lèvres qui bougent sans voix.
func _check_mouth(packed: PackedScene) -> void:
	var portrait := Portrait3D.new()
	portrait.model = packed
	root.add_child(portrait)
	var visage = portrait.visage
	var face := portrait.find_child("Visage", true, false) as MeshInstance3D
	var smile_index := face.find_blend_shape_by_name(&"Sourire")
	check(visage.has_shape(&"Sourire") and smile_index >= 0, "Forme « Sourire » de la bouche pilotée")
	visage._smile_wait = 99.0
	var opens: Array[float] = []
	for i in 50:
		visage._process(0.1)
		opens.append(face.get_blend_shape_value(0))
	check(is_equal_approx(face.get_blend_shape_value(smile_index), visage.MOUTH_SMILE_REST), "Repos : commissures à peine relevées")
	check(opens.min() >= 0.02 and opens.max() <= 0.1 and opens.max() - opens.min() > 0.03, "Repos : lèvres entrouvertes qui bougent avec la respiration (%.2f à %.2f)" % [opens.min(), opens.max()])
	visage.smile_now(1.0)
	for i in 8: visage._process(0.1)
	check(face.get_blend_shape_value(smile_index) > 0.8 and face.get_blend_shape_value(3) <= visage.MOUTH_SMILE_WIDE + 0.001 and is_zero_approx(face.get_blend_shape_value(2)),
		"Sourire franc par la forme « Sourire », MouthWide léger, sans MouthPress")
	visage.set_tone("negatif")
	visage._process(0.1)
	check(is_zero_approx(face.get_blend_shape_value(smile_index)), "Ton négatif : pas de sourire de la bouche")
	visage.set_tone("neutre")
	# Bulle sans voix : la bouche s'ouvre légèrement au rythme de syllabes, puis se referme.
	portrait.mime("Un banc, ce n'est pas une salle d'attente.")
	check(portrait.is_miming() and portrait._speaking, "Bulle sans voix : Gabi remue les lèvres")
	var widest := 0.0
	for i in 20:
		portrait._mime_time += 0.05
		portrait._mime_step()
		widest = maxf(widest, face.get_blend_shape_value(0))
	check(widest > 0.1 and widest <= portrait.MIME_OPEN.y + 0.001, "Ouverture légère (%.2f)" % widest)
	portrait._mime_left = 0.0
	portrait._mime_step()
	check(not portrait.is_miming() and not portrait._speaking, "Fin de la bulle : bouche au repos")
	portrait.set_speaking(true)
	portrait.mime("Texte pendant une vraie voix.")
	check(not portrait.is_miming(), "Une vraie voix n'est pas doublée par le mouvement sans voix")
	portrait.set_speaking(false)
	portrait.set_reduced_motion(true)
	portrait.mime("Texte en mouvement réduit.")
	check(not portrait.is_miming() and not portrait._speaking, "Mouvement réduit : pas de mouvement de lèvres")
	portrait.free()
