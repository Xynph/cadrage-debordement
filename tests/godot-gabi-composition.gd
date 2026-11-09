extends SceneTree

const Portrait = preload("res://guide/coach_portrait.gd")

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

	print("Réception du portrait de composition : %d contrôles, %d échecs" % [checks, failures])
	quit(1 if failures else 0)
