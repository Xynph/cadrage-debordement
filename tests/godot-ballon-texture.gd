extends SceneTree
## Texture du ballon : intégrée au glb (pas de PNG extrait, donc pas d'UID de texture à désynchroniser).
## Lancé depuis le projet natif : --script ../../tests/godot-ballon-texture.gd (après l'import du projet).
const BALL := "res://art/office_props/ballon.glb"
const IMPORT := "res://art/office_props/ballon.glb.import"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, detail: String) -> bool:
	checks += 1
	if not condition:
		failures.append(detail)
	return condition

func finish() -> void:
	print(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	check(FileAccess.file_exists(IMPORT), "Réglage d'import du ballon versionné")
	var reglage := FileAccess.get_file_as_string(IMPORT)
	check(reglage.contains("gltf/embedded_image_handling=3"), "Texture du ballon embarquée dans le glb")
	var scene := load(BALL) as PackedScene
	if not check(scene != null, "ballon.glb importé"):
		finish()
		return
	var ball := scene.instantiate()
	var meshes := ball.find_children("*", "MeshInstance3D", true, false)
	if ball is MeshInstance3D:
		meshes.push_front(ball)
	if not check(meshes.size() == 1, "Un maillage de ballon"):
		finish()
		return
	var mesh := meshes[0] as MeshInstance3D
	var material := mesh.get_active_material(0) as StandardMaterial3D
	if check(material != null, "Matériau standard du ballon"):
		var texture := material.albedo_texture
		if check(texture != null, "Texture de cuir présente"):
			var path := texture.resource_path
			check(not path.begins_with("res://") or path.contains("::") or path.contains(".godot/imported/ballon.glb"), "Texture portée par le glb, sans fichier d'image externe : " + path)
			check(texture.get_width() >= 256, "Texture lisible : %d px" % texture.get_width())
	ball.free()
	finish()
