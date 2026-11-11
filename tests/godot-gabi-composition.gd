extends SceneTree

const Portrait = preload("res://guide/coach_portrait.gd")
const Portrait3D = preload("res://guide/coach_portrait_3d.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var portrait := Portrait.new()
	root.add_child(portrait)
	portrait.set_process(false)
	portrait.size = Vector2(104, 104)
	var atlas: Texture2D = portrait.frame_texture.atlas
	var layout := Rect2(portrait.position, portrait.size)

	portrait.set_context("composition")
	portrait._process(0.20)
	_check(portrait.pose_index == 8 and portrait.scale == Vector2.ONE, "La composition commence sur sa pose fermée")
	portrait._process(0.28)
	_check(portrait.pose_index == 8 and portrait.scale.y < 0.99 and portrait.scale.y > 0.93, "Gabi fait un signe de tête discret sans changer de pose")
	var top: Vector2 = portrait.get_transform() * Vector2.ZERO
	var bottom: Vector2 = portrait.get_transform() * portrait.size
	_check(atlas != null and portrait.frame_texture.atlas == atlas and Rect2(portrait.position, portrait.size) == layout, "Même atlas HD et même rectangle de mise en page")
	_check(top.y >= layout.position.y and bottom.y <= layout.end.y, "Le portrait animé reste dans sa place à 104 pixels")
	portrait.set_context("composition")
	portrait._process(0.07)
	_check(portrait.scale.y < 1.0, "Rafraîchir la même page ne relance pas le signe")
	portrait._process(0.30)
	_check(portrait.scale == Vector2.ONE and portrait.pose_index == 8, "Retour complet à la pose fermée")
	portrait.set_context("composition")
	portrait._process(0.48)
	_check(portrait.scale == Vector2.ONE, "Un contexte inchangé ne rejoue pas la réaction")

	portrait.set_context("premier-match")
	portrait._process(0.48)
	_check(portrait.pose_index == 8 and portrait.scale == Vector2.ONE, "Le premier match garde sa présentation habituelle")
	portrait.set_context("composition")
	portrait._process(0.10)
	portrait.set_articulation(0.0)
	portrait.set_speaking(true)
	portrait._process(1.0)
	_check(portrait.pose_index == 8 and portrait.scale == Vector2.ONE, "Le silence dans un clip ferme la bouche sans signe de tête")
	portrait.set_articulation(1.0)
	_check(portrait.pose_index == 9, "Le signal audio ouvre encore la bouche du portrait de composition")
	portrait.set_speaking(false)
	portrait._process(0.48)
	_check(portrait.pose_index == 8 and portrait.scale.y < 0.99, "Une réaction en attente se joue après la fin de la parole")
	portrait.set_speaking(true)
	_check(portrait.pose_index == 9 and portrait.scale == Vector2.ONE, "La reprise de parole interrompt la réaction")
	portrait.set_speaking(false)
	portrait._process(0.48)
	_check(portrait.scale == Vector2.ONE, "Une réaction interrompue ne se rejoue pas")

	portrait.set_context("finances")
	portrait.set_context("composition")
	portrait._process(0.48)
	portrait.set_reduced_motion(true)
	portrait._process(1.0)
	_check(portrait.pose_index == 8 and portrait.scale == Vector2.ONE, "Le mouvement réduit remet et garde la pose fixe")
	portrait.set_context("finances")
	portrait.set_context("composition")
	portrait.set_reduced_motion(false)
	portrait._process(0.48)
	_check(portrait.scale == Vector2.ONE, "Réactiver le mouvement ne lance pas une ancienne réaction")
	portrait.set_context("finances")
	portrait.set_context("composition")
	portrait._process(0.48)
	portrait.hide()
	portrait.show()
	portrait._process(0.01)
	_check(portrait.scale == Vector2.ONE, "Un portrait masqué ne reprend pas à mi-geste")

	_check_gestures()
	print("Réception du portrait de composition : %d contrôles, %d échecs" % [checks, failures])
	quit(1 if failures else 0)

func _test_model(clip_names: Array[StringName]) -> PackedScene:
	var scene := Node3D.new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	scene.add_child(player)
	player.owner = scene
	var library := AnimationLibrary.new()
	for clip_name in clip_names:
		var clip := Animation.new()
		clip.length = 1.0
		library.add_animation(clip_name, clip)
	player.add_animation_library(&"", library)
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	return packed

func _check_gestures() -> void:
	var portrait := Portrait3D.new()
	portrait.model = _test_model([&"Repos", &"Approbation", &"Salut", &"Explication", &"Ecoute", &"RegardCarnet"])
	root.add_child(portrait)
	var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(player.current_animation == "Repos" and player.get_animation("Repos").loop_mode == Animation.LOOP_LINEAR,
		"Le portrait 3D se repose en boucle")
	portrait.request_gesture(true)
	_check(player.current_animation == "Salut", "La première ouverture explicite salue")
	portrait.request_gesture(false)
	_check(player.current_animation == "Salut", "Une demande rapprochée respecte le salut en cours")
	player.advance(1.2)
	_check(player.current_animation == "Repos" and portrait.is_processing(), "Le salut rend la main au repos et au minuteur")
	var delay := portrait._microgesture_wait
	_check(delay >= 7.0 and delay <= 13.0, "Le premier microgeste attend entre sept et treize secondes")
	portrait._process(delay - 0.01)
	_check(player.current_animation == "Repos", "Le repos se poursuit jusqu’au délai tiré")
	portrait._process(0.02)
	var first := player.current_animation
	_check(first in ["Ecoute", "RegardCarnet"] and not portrait.is_processing(), "Le minuteur déclenche un seul microgeste")
	player.advance(1.2)
	_check(player.current_animation == "Repos" and portrait._microgesture_wait >= 7.0,
		"Un microgeste revient au repos avant le délai suivant")
	portrait._process(13.1)
	_check(player.current_animation in ["Ecoute", "RegardCarnet"] and player.current_animation != first,
		"Les deux microgestes alternent")
	portrait.hide()
	portrait.request_gesture(true)
	_check(not player.is_playing() and not portrait.is_processing(), "Guide masqué : geste et minuteur suspendus")
	portrait.show()
	_check(player.current_animation == "Repos", "Réouverture au repos sans reprendre le geste interrompu")
	portrait.request_gesture(true)
	_check(player.current_animation == "Explication", "La réouverture explique sans répéter le salut")
	portrait.set_context("composition")
	portrait.request_gesture(false)
	_check(player.current_animation == "Approbation", "La composition donne priorité à l’approbation")
	portrait.set_reduced_motion(true)
	portrait.set_context("resultat")
	portrait.request_gesture(true)
	_check(not player.is_playing() and not portrait.is_processing(), "Le réglage réduit bloque animation et minuteur")
	portrait.set_reduced_motion(false)
	_check(player.current_animation == "Repos", "La reprise du mouvement ne joue pas un geste passé")
	portrait.free()

	var fallback := Portrait3D.new()
	fallback.model = _test_model([&"Repos", &"Approbation"])
	root.add_child(fallback)
	var fallback_player := fallback.find_child("AnimationPlayer", true, false) as AnimationPlayer
	fallback.request_gesture(true)
	_check(fallback_player.current_animation == "Repos" and not fallback.is_processing(),
		"Un ancien modèle sans clips optionnels garde le repos")
	fallback.free()
