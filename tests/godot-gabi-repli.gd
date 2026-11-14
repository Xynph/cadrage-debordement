extends SceneTree
## Repli du visage de Gabi (disque du bandeau du haut, 14/11/2026) : sans fichier Mixamo privé (Gabi d'origine,
## buste 3D) et sans GLB du guide (portrait 2D zoomé en disque, avec un souffle léger), sans asset nouveau.
## Le disque n'affiche que la texture du portrait : le portrait reste au guide (jamais déplacé ni libéré), ce
## qui permet de reconstruire le bandeau à chaque écran sans recréer Gabi.
const Medaillon = preload("res://guide/gabi_medaillon.gd")
const Portrait3D = preload("res://guide/coach_portrait_3d.gd")
const Portrait2D = preload("res://guide/coach_portrait.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	# Jeu de base : aucune donnée privée -> le Gabi d'origine du dépôt, pas de modèle nul.
	var model := Portrait3D.load_model("/chemin/inexistant")
	_check(model != null, "Sans fichier privé, le Gabi d'origine est chargé")
	_check(model != null and model.resource_path == "res://guide/assets/gabi.glb", "Le modèle de repli est le GLB du dépôt public")
	var original := Portrait3D.new()
	original.model = model
	var medaillon: Control = Medaillon.new()
	medaillon.size = Vector2(120, 120)
	root.add_child(medaillon)
	root.add_child(original)
	medaillon.afficher(original)
	for i in 3: await process_frame
	_check(medaillon.portrait == original and medaillon._image.material is ShaderMaterial and medaillon._image.material.shader.resource_path.ends_with("gabi_medaillon_masque.gdshader"), "Buste 3D : masque rond conservé")
	_check(medaillon._image.texture == original.texture and original.texture is ViewportTexture, "Buste 3D : le disque affiche la texture du portrait")
	_check(original.get_parent() == root, "Buste 3D : le portrait reste au guide")
	_check(medaillon._disque == null, "Buste 3D : pas de repli 2D")
	# Cadrages hors mode grand : visage (bandeau) et en pied (Bureau), rendu à la taille demandée.
	original.set_framing("visage")
	original.set_render_size(Vector2i(120, 120))
	_check(original._viewport.size == Vector2i(120, 120), "Visage : rendu à la taille du disque")
	original.set_framing("pied")
	original.set_render_size(Vector2i(300, 520))
	_check(original._viewport.size == Vector2i(300, 520) and is_equal_approx(original._camera.size, original.CADRAGES.pied.size), "En pied : Gabi en entier, rendu à la taille de sa zone")
	original.set_framing("portrait")
	_check(original._viewport.size == original.RENDER_SIZE, "Mode grand : rendu du portrait")
	original.set_process(false)
	medaillon.liberer()
	_check(medaillon.portrait == null and original.get_parent() == root, "Disque vidé, portrait intact")
	original.free()
	medaillon.free()

	# Sans GLB : portrait 2D de Gabi, zoomé en disque et vivant.
	medaillon = Medaillon.new()
	medaillon.size = Vector2(120, 120)
	root.add_child(medaillon)
	var flat: TextureRect = Portrait2D.new()
	root.add_child(flat)
	medaillon.afficher(flat)
	for i in 3: await process_frame
	var disque: Control = medaillon._disque
	var souffle: Control = medaillon._souffle
	var image: TextureRect = medaillon._image
	_check(disque != null and souffle != null, "Repli 2D : disque et souffle créés")
	_check(disque.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "Repli 2D : le portrait est découpé en disque")
	_check(image.get_parent() == souffle and souffle.get_parent() == disque, "Repli 2D : portrait dans le disque")
	_check(image.texture == flat.texture and flat.get_parent() == root, "Repli 2D : texture du portrait partagée, portrait resté au guide")
	_check(image.material is ShaderMaterial and image.material.shader.resource_path.ends_with("coach_matte.gdshader"), "Repli 2D : détourage du fond conservé")
	var inner := disque.size
	_check(souffle.size.x > inner.x * 1.3, "Repli 2D : zoom sur la tête et les épaules")
	var head := souffle.position + Vector2(0.52, 0.30) * souffle.size
	_check(Rect2(Vector2.ZERO, inner).has_point(head), "Repli 2D : la tête reste dans le disque (%s)" % head)
	var hands := souffle.position + Vector2(0.5, 0.88) * souffle.size
	_check(not Rect2(Vector2.ZERO, inner).has_point(hands), "Repli 2D : mains et carnet hors du disque")
	var seen := {}
	for i in 140:
		medaillon._process(1.0 / 30.0)
		seen[snappedf(souffle.scale.y, 0.0005)] = true
		_check(souffle.scale.y >= 1.0 and souffle.scale.y <= 1.0 + medaillon.BREATH_DEPTH + 0.0001, "Souffle borné (%f)" % souffle.scale.y)
	_check(seen.size() > 10, "Repli 2D : le portrait respire (%d valeurs)" % seen.size())
	_check(is_equal_approx(souffle.scale.x, 1.0), "Souffle : largeur inchangée")
	medaillon.reduced_motion = true
	medaillon._process(0.1)
	_check(souffle.scale == Vector2.ONE, "Mouvement réduit : portrait immobile")
	medaillon.liberer()
	_check(flat.get_parent() == root and is_instance_valid(flat), "Disque vidé : le portrait du guide est intact")
	_check(medaillon.portrait == null and medaillon._disque == null, "Disque vidé")
	flat.free()
	medaillon.free()
	print("GABI_REPLI %d controles, %d echec%s" % [checks, failures, "s" if failures > 1 else ""])
	quit(1 if failures > 0 else 0)
