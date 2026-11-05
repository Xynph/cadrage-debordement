extends SceneTree
## Physical R&D smoke: TWO real canonical humanoids per LOD, Kickback's actual
## Jolt rigid-body builder/springs, deterministic impact, never exports GLBs.
## No fake mesh, no claim of rugby grasp or collision-free contact.

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null


func _initialize() -> void:
	call_deferred("test_physics")


func test_physics() -> void:
	var args := OS.get_cmdline_user_args()
	var report := {"status": "FAIL", "engine": Engine.get_version_info().get("string", ""),
		"realPhysics": true, "tackleApproved": false, "lods": []}
	if args.size() != 4:
		printerr("Expected report path and three decoded canonical GLBs")
		quit(2)
		return
	var passed := true
	# Terrain is an actual static collision object, not a cosmetic height clamp.
	var ground := StaticBody3D.new()
	ground.name = "ExperimentGround"
	ground.position.y = -0.5
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	floor_shape.shape = box
	ground.add_child(floor_shape)
	get_root().add_child(ground)

	for lod in 3:
		var item := {"lod": lod, "status": "FAIL", "rigs": []}
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var result := doc.append_from_file(args[lod + 1], state)
		item["gltf_error"] = result
		if result != OK:
			report["lods"].append(item)
			passed = false
			continue
		var roots: Array = []
		var controllers: Array = []
		var builders: Array = []
		for index in 2:
			var scene := doc.generate_scene(state)
			var root := Node3D.new()
			root.name = "RealCanonicalLOD%dPlayer%d" % [lod, index]
			root.position = Vector3(-0.32 if index == 0 else 0.32, 0.0, 0.0)
			get_root().add_child(root)
			root.add_child(scene)
			var skeleton := find_skeleton(scene)
			if skeleton == null:
				item["error"] = "GLB skeleton unavailable"
				break
			var mapping := SkeletonDetector.detect_humanoid_bones(skeleton)
			var profile := SkeletonDetector.create_profile_from_skeleton(skeleton, mapping)
			var tuning := RagdollTuning.create_default()
			var nodes := KickbackSetup.add_active_rig(root, skeleton, profile, tuning)
			roots.append(root)
			builders.append(nodes[0])
			controllers.append(nodes[3])
			item["rigs"].append({"bones": skeleton.get_bone_count(), "detected": mapping.size()})
		if roots.size() != 2:
			passed = false
			for r in roots:
				r.queue_free()
			await process_frame
			report["lods"].append(item)
			continue
		for tick in 12:
			await physics_frame
		var first: Dictionary = builders[0].get_bodies()
		var second: Dictionary = builders[1].get_bodies()
		item["bodyCount"] = [first.size(), second.size()]
		if first.size() != 16 or second.size() != 16:
			item["error"] = "Kickback could not assemble 16 actual rigid bodies per GLB"
			passed = false
		else:
			var chest0: RigidBody3D = first["Chest"]
			var chest1: RigidBody3D = second["Chest"]
			var initial := chest0.global_position
			var separation_before := chest0.global_position.distance_to(chest1.global_position)
			var impact := ImpactProfile.new()
			impact.base_impulse = 6.0
			impact.impulse_transfer_ratio = 0.5
			impact.ragdoll_probability = 0.0
			impact.strength_reduction = 0.65
			var toward := (chest1.global_position - chest0.global_position).normalized()
			controllers[0].apply_hit(chest0, toward, chest0.global_position, impact)
			for tick in 40:
				await physics_frame
			var after := chest0.global_position
			var separation_after := chest0.global_position.distance_to(chest1.global_position)
			var travelled := initial.distance_to(after)
			item["physics"] = {
				"chestTravelM": travelled,
				"initialChestSeparationM": separation_before,
				"postImpactChestSeparationM": separation_after,
				"firstChestY": after.y,
				"secondChestY": chest1.global_position.y,
				"firstControllerState": str(controllers[0].get_state())
			}
			item["status"] = "PASS" if travelled > 0.005 and travelled < 4.0 and abs(after.y) < 10 else "FAIL"
			if item["status"] != "PASS":
				passed = false
		for r in roots:
			r.queue_free()
		for tick in 3:
			await physics_frame
		report["lods"].append(item)

	ground.queue_free()
	report["status"] = "PASS" if passed else "FAIL"
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("CD_KICKBACK_REAL_RIGID_BODY_TEST=", JSON.stringify(report))
	quit(0 if passed else 2)
