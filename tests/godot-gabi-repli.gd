extends SceneTree
## Repli du médaillon de Gabi : sans fichier Mixamo privé (Gabi d'origine, buste 3D) et sans GLB du guide
## (portrait 2D zoomé en disque, avec un souffle léger), sans asset nouveau.
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
	medaillon.adopt(original)
	for i in 3: await process_frame
	_check(medaillon.portrait == original and original.material is ShaderMaterial, "Buste 3D : masque rond conservé")
	_check(medaillon._disque == null, "Buste 3D : pas de repli 2D")
	original.set_process(false)
	medaillon.release()
	original.free()
	medaillon.free()

	# Sans GLB : portrait 2D de Gabi, zoomé en disque et vivant.
	medaillon = Medaillon.new()
	medaillon.size = Vector2(120, 120)
	root.add_child(medaillon)
	var flat: TextureRect = Portrait2D.new()
	root.add_child(flat)
	medaillon.adopt(flat)
	for i in 3: await process_frame
	var disque: Control = medaillon._disque
	var souffle: Control = medaillon._souffle
	_check(disque != null and souffle != null, "Repli 2D : disque et souffle créés")
	_check(disque.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "Repli 2D : le portrait est découpé en disque")
	_check(flat.get_parent() == souffle and souffle.get_parent() == disque, "Repli 2D : portrait dans le disque")
	_check(flat.material is ShaderMaterial and flat.material.shader.resource_path.ends_with("coach_matte.gdshader"), "Repli 2D : détourage du fond conservé")
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
	var rendered: TextureRect = medaillon.release()
	_check(rendered == flat and flat.get_parent() == null, "Retour au mode grand : portrait rendu")
	_check(medaillon.portrait == null and medaillon._disque == null, "Retour au mode grand : médaillon vidé")
	flat.free()
	medaillon.free()
	print("GABI_REPLI %d controles, %d echec%s" % [checks, failures, "s" if failures > 1 else ""])
	quit(1 if failures > 0 else 0)
