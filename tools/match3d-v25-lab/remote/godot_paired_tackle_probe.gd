extends SceneTree
## Three *real* 53-bone GLB LODs. Paired scenarios:
## 1. approach only; 2. same approach + impulse; 3. impulse + two
##    temporary physics constraints on actual Hand_L/Hand_R rigid bodies.
## This is NOT proof of hands on SKIN, plausible rugby grip, or final visuals.
## Every simulation uses Kickback's 16-body Jolt ragdolls with physical ground.

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var hit := find_skeleton(child)
		if hit != null:
			return hit
	return null


func snap(frame: int, phase: String, a: Dictionary, b: Dictionary) -> Dictionary:
	var left: RigidBody3D = a["Hand_L"]
	var right: RigidBody3D = a["Hand_R"]
	var chest_a: RigidBody3D = a["Chest"]
	var chest_b: RigidBody3D = b["Chest"]
	var hips_a: RigidBody3D = a["Hips"]
	var hips_b: RigidBody3D = b["Hips"]
	var min_rigid_y := INF
	for body in [a["Foot_L"], a["Foot_R"], b["Foot_L"], b["Foot_R"]]:
		min_rigid_y = minf(min_rigid_y, body.global_position.y)
	return {
		"frame": frame, "phase": phase,
		"chestA": [chest_a.global_position.x, chest_a.global_position.y, chest_a.global_position.z],
		"chestB": [chest_b.global_position.x, chest_b.global_position.y, chest_b.global_position.z],
		"chestSeparationM": chest_a.global_position.distance_to(chest_b.global_position),
		"leftHandToCarrierChestM": left.global_position.distance_to(chest_b.global_position),
		"rightHandToCarrierChestM": right.global_position.distance_to(chest_b.global_position),
		"leftHandToCarrierHipsM": left.global_position.distance_to(hips_b.global_position),
		"rightHandToCarrierHipsM": right.global_position.distance_to(hips_b.global_position),
		"tacklerHipY": hips_a.global_position.y, "carrierHipY": hips_b.global_position.y,
		"minFootRigidBodyCenterY": min_rigid_y
	}


func _initialize() -> void:
	call_deferred("run_pair")


func run_pair() -> void:
	var args := OS.get_cmdline_user_args()
	var result := {"schema": 1, "status": "FAIL", "engine": Engine.get_version_info().get("string", ""),
		"lods": [], "approvedRugbyTackle": false, "confirmedSkinGrip": false,
		"skinnedTriangleIntersectionCheck": "NOT_EXECUTED",
		"groundSkinnedVertexCheck": "NOT_EXECUTED",
		"visualEvidence": "NOT_RENDERED",
		"contactMeaning": "Hand rigid-body centers to opposing chest/hips centers; not skinned contact"}
	if args.size() != 4:
		printerr("Expected output and 3 exact dequantized GLB paths")
		quit(2)
		return
	var ground := StaticBody3D.new()
	ground.name = "PhysicalPitch"
	ground.position.y = -0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	ground.add_child(shape)
	get_root().add_child(ground)
	var all_pass := true
	for lod in 3:
		var lod_report := {"lod": lod, "scenarioResults": []}
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(args[lod + 1], state)
		lod_report["gltfError"] = err
		if err != OK:
			all_pass = false
			result["lods"].append(lod_report)
			continue
		for mode in ["control", "impact", "impact_with_hand_pins"]:
			var scenario := {"name": mode, "status": "FAIL", "samples": [], "gripPhysicsLinks": 0}
			var actors: Array = []
			var builders: Array = []
			var controllers: Array = []
			for actor_index in 2:
				var scene: Node = doc.generate_scene(state)
				var root := Node3D.new()
				root.name = "CanonicalLOD%d_%s_Player%d" % [lod, mode, actor_index]
				# Face-to-face paired interaction instead of side-by-side rigs.
				# The canonical GLB's positive Z is its forward direction.
				root.position = Vector3(0.0, 0.0, -0.42 if actor_index == 0 else 0.42)
				root.rotation.y = 0.0 if actor_index == 0 else PI
				get_root().add_child(root)
				root.add_child(scene)
				var skel := find_skeleton(scene)
				if skel == null:
					scenario["error"] = "Actual 53-bone skeleton not found"
					break
				var mapping := SkeletonDetector.detect_humanoid_bones(skel)
				var profile := SkeletonDetector.create_profile_from_skeleton(skel, mapping)
				var nodes := KickbackSetup.add_active_rig(root, skel, profile, RagdollTuning.create_default())
				actors.append(root)
				builders.append(nodes[0])
				controllers.append(nodes[3])
			if actors.size() != 2:
				all_pass = false
			else:
				var a: Dictionary = {}
				var b: Dictionary = {}
				var ready_frames := 0
				for frame in 120:
					await physics_frame
					ready_frames = frame + 1
					a = builders[0].get_bodies()
					b = builders[1].get_bodies()
					if a.size() == 16 and b.size() == 16:
						break
				scenario["readyFrames"] = ready_frames
				scenario["bodyCount"] = [a.size(), b.size()]
				if a.size() != 16 or b.size() != 16:
					scenario["error"] = "Kickback body build incomplete"
					all_pass = false
				else:
					# Exactly the same pre-impact approach physics in all modes.
					# No root teleports: a real, bounded impulse on the body.
					var initial := snap(0, "approach_start", a, b)
					scenario["samples"].append(initial)
					var towards: Vector3 = (b["Chest"].global_position - a["Chest"].global_position).normalized()
					a["Chest"].apply_central_impulse(towards * 0.9)
					for frame in 12:
						await physics_frame
					scenario["samples"].append(snap(12, "approach_end", a, b))
					if mode != "control":
						var hit := ImpactProfile.new()
						hit.base_impulse = 6.0
						hit.impulse_transfer_ratio = 0.5
						hit.ragdoll_probability = 0.0
						hit.strength_reduction = 0.65
						controllers[0].apply_hit(a["Chest"], towards, a["Chest"].global_position, hit)
					var hand_links: Array = []
					if mode == "impact_with_hand_pins":
						# Explicit experimental physical attachment, NOT
						# a verified anatomical grasp at true skinned surface.
						for pair in [["Hand_L", "Chest"], ["Hand_R", "Hips"]]:
							var hand: RigidBody3D = a[pair[0]]
							var target: RigidBody3D = b[pair[1]]
							var initial_gap := hand.global_position.distance_to(target.global_position)
							if initial_gap > 0.95:
								continue
							# Godot 4.7 has PinJoint3D, NOT DampedSpringJoint3D.
							# A genuine physics link between real Kickback bodies.
							var link := PinJoint3D.new()
							link.position = (hand.global_position + target.global_position) / 2.0
							get_root().add_child(link)
							link.node_a = link.get_path_to(hand)
							link.node_b = link.get_path_to(target)
							hand_links.append(link)
						scenario["gripPhysicsLinks"] = hand_links.size()
					for frame in 48:
						await physics_frame
						if frame == 11:
							scenario["samples"].append(snap(24, "impact", a, b))
						if frame == 35:
							scenario["samples"].append(snap(48, "fall", a, b))
					# Release the experimental hand attachment at recovery.
					for link in hand_links:
						link.queue_free()
					for frame in 48:
						await physics_frame
					scenario["samples"].append(snap(108, "recovery", a, b))
					# A nominal "two-handed grip" is not a valid two-hand
					# contact experiment when only one PinJoint attaches.
					if mode == "impact_with_hand_pins" and scenario["gripPhysicsLinks"] != 2:
						scenario["error"] = "Two simultaneous real hand-body joints were not created"
						scenario["status"] = "FAIL"
						all_pass = false
					else:
						scenario["status"] = "PASS"
			for actor in actors:
				actor.queue_free()
			for frame in 4:
				await physics_frame
			lod_report["scenarioResults"].append(scenario)
		lod_report["status"] = "PASS" if lod_report["scenarioResults"].size() == 3 and \
			lod_report["scenarioResults"].all(func(item): return item["status"] == "PASS") else "FAIL"
		all_pass = all_pass and lod_report["status"] == "PASS"
		result["lods"].append(lod_report)
	ground.queue_free()
	result["status"] = "PASS" if all_pass else "FAIL"
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
		out.close()
	print("CD_PAIRED_RUGBY_PHYSICS=", JSON.stringify(result))
	quit(0 if all_pass else 2)
