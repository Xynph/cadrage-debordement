extends SceneTree
## Real Godot 4.7 glTF import on the three canonical Rugby V24 GLBs.
## Uses Kickback's OWN SkeletonDetector, no fake 53-bone test rig.
## Logs mismatches; does not mutate or export any model.

func walk(node: Node, skeletons: Array, meshes: Array) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		walk(child, skeletons, meshes)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := {"schema": 1, "engine": Engine.get_version_info().get("string", ""), "rigs": [], "artisticApproval": false, "status": "FAIL"}
	if args.size() != 4:
		printerr("Expected: output.json and three canonical LOD GLB paths")
		quit(2)
		return
	var success := true
	for lod in 3:
		var path: String = args[lod + 1]
		var record := {"lod": lod, "path": path, "status": "FAIL"}
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var err := document.append_from_file(path, state)
		record["gltf_error"] = err
		if err != OK:
			success = false
			result["rigs"].append(record)
			continue
		var scene: Node = document.generate_scene(state)
		if scene == null:
			record["error"] = "GLTFDocument did not generate a scene"
			success = false
			result["rigs"].append(record)
			continue
		var skeletons: Array = []
		var meshes: Array = []
		walk(scene, skeletons, meshes)
		record["skeleton_count"] = skeletons.size()
		record["skinned_mesh_count"] = meshes.size()
		if skeletons.size() == 1:
			var skeleton: Skeleton3D = skeletons[0]
			record["bone_count"] = skeleton.get_bone_count()
			var names := PackedStringArray()
			for bone_index in skeleton.get_bone_count():
				names.append(skeleton.get_bone_name(bone_index))
			record["bones_sha256"] = names.join("|").sha256_text()
			record["important_bones"] = {
				"upperarm_l": names.has("upperarm_l"), "upperarm_r": names.has("upperarm_r"),
				"lowerarm_l": names.has("lowerarm_l"), "lowerarm_r": names.has("lowerarm_r"),
				"hand_l": names.has("hand_l"), "hand_r": names.has("hand_r"),
				"spine_03": names.has("spine_03")
			}
			var detected: Dictionary = SkeletonDetector.detect_humanoid_bones(skeleton)
			record["kickback_detected_slots"] = detected
			record["kickback_detected_count"] = detected.size()
			var required := ["Hips", "Head", "UpperArm_L", "UpperArm_R", "LowerArm_L", "LowerArm_R"]
			var missing := []
			for slot in required:
				if not detected.has(slot):
					missing.append(slot)
			record["missing_key_slots"] = missing
			record["status"] = "PASS" if skeleton.get_bone_count() == 53 and missing.is_empty() else "INCOMPATIBLE"
		else:
			record["error"] = "Expected exactly one imported Skeleton3D"
		if record["status"] != "PASS":
			success = false
		scene.free()
		result["rigs"].append(record)
	result["status"] = "PASS" if success else "INCOMPATIBLE"
	var handle := FileAccess.open(args[0], FileAccess.WRITE)
	if handle == null:
		printerr("Cannot write reproducible import report: ", args[0])
		quit(2)
		return
	handle.store_string(JSON.stringify(result, "\t"))
	handle.close()
	print("CD_KICKBACK_CANONICAL_IMPORT=", JSON.stringify(result))
	quit(0 if success else 2)
