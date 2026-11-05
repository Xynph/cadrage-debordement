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


func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animation_player(child)
		if found != null:
			return found
	return null


func start_idle_animation(scene: Node) -> Dictionary:
	var player := find_animation_player(scene)
	if player == null:
		return {"status": "NO_ANIMATION_PLAYER"}
	var names: Array = Array(player.get_animation_list())
	var selected := ""
	for name in names:
		var low := str(name).to_lower()
		if "idle" in low or "stand" in low:
			selected = str(name)
			break
	if selected.is_empty():
		return {"status": "NO_IDLE_CLIP", "availableClips": names}
	var clip: Animation = player.get_animation(selected)
	# Only on an ephemeral test copy; never mutate/source-control originals.
	if clip != null:
		clip.loop_mode = Animation.LOOP_LINEAR
	player.play(selected)
	player.seek(0.0, true)
	return {"status": "PLAYING", "selected": selected, "availableClips": names}


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


func capture_pair(camera: Camera3D, output_dir: String, lod: int, mode: String, phase: String) -> Array:
	var saved := []
	# Freeze the physics world while rendering both angles on the same frame.
	paused = true
	for view in ["front", "side"]:
		camera.position = Vector3(0.0, 1.45, 3.45) if view == "front" else Vector3(3.45, 1.45, 0.0)
		camera.look_at(Vector3(0.0, 0.67, 0.0), Vector3.UP)
		await RenderingServer.frame_post_draw
		var image: Image = get_root().get_texture().get_image()
		if image.is_empty() or image.get_width() < 320 or image.get_height() < 180:
			saved.append({"view": view, "error": "EMPTY_RENDERED_VIEWPORT"})
			continue
		var path := output_dir.path_join("lod%d_%s_%s_%s.jpg" % [lod, mode, phase, view])
		var error := image.save_jpg(path, 0.88)
		saved.append({"view": view, "file": path.get_file(), "errorCode": error,
			"bytes": FileAccess.get_file_as_bytes(path).size() if error == OK else 0,
			"width": image.get_width(), "height": image.get_height()})
	paused = false
	return saved


func prepare_visual_stage() -> Camera3D:
	get_root().size = Vector2i(800, 450)
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.78, 0.83, 0.90)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.83, 0.85, 0.90)
	sky.ambient_light_energy = 1.3
	env.environment = sky
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 37.0, -8.0)
	sun.light_energy = 1.7
	get_root().add_child(sun)
	var visual_pitch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(25.0, 25.0)
	visual_pitch.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.40, 0.29)
	material.roughness = 0.95
	visual_pitch.material_override = material
	get_root().add_child(visual_pitch)
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.current = true
	get_root().add_child(camera)
	return camera


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
	if args.size() != 4 and args.size() != 5:
		printerr("Expected output, 3 exact dequantized GLB paths and optional visual flag")
		quit(2)
		return
	var render_requested: bool = args.size() == 5 and args[4] == "visual"
	var visual_dir: String = str(args[0]).get_base_dir().path_join("paired-images")
	var camera: Camera3D = null
	if render_requested:
		DirAccess.make_dir_recursive_absolute(visual_dir)
		camera = prepare_visual_stage()
		result["visualEvidence"] = "GODOT_RENDERED_VIEWPORT_SOFTWARE_OPENGL_FACE_SIDE"
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
				var animation := start_idle_animation(scene)
				scenario["animationPlayer%d" % actor_index] = animation
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
					if render_requested:
						scenario["images"] = await capture_pair(camera, visual_dir, lod, mode, "approach_start")
					var towards: Vector3 = (b["Chest"].global_position - a["Chest"].global_position).normalized()
					a["Chest"].apply_central_impulse(towards * 0.9)
					for frame in 12:
						await physics_frame
					scenario["samples"].append(snap(12, "approach_end", a, b))
					var start_height: float = scenario["samples"][0]["chestA"][1]
					var approach_height: float = scenario["samples"][-1]["chestA"][1]
					scenario["preImpactChestDropM"] = maxf(0.0, start_height - approach_height)
					scenario["stableBeforeImpact"] = scenario["preImpactChestDropM"] <= 0.35
					if render_requested:
						scenario["images"].append_array(await capture_pair(camera, visual_dir, lod, mode, "approach_end"))
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
							if render_requested:
								scenario["images"].append_array(await capture_pair(camera, visual_dir, lod, mode, "impact"))
						if frame == 35:
							scenario["samples"].append(snap(48, "fall", a, b))
							if render_requested:
								scenario["images"].append_array(await capture_pair(camera, visual_dir, lod, mode, "fall"))
					# Release the experimental hand attachment at recovery.
					for link in hand_links:
						link.queue_free()
					for frame in 48:
						await physics_frame
					scenario["samples"].append(snap(108, "recovery", a, b))
					if render_requested:
						scenario["images"].append_array(await capture_pair(camera, visual_dir, lod, mode, "recovery"))
					# A nominal "two-handed grip" is not a valid two-hand
					# contact experiment when only one PinJoint attaches.
					if not scenario["stableBeforeImpact"]:
						scenario["error"] = "Existing canonical rig physically collapses before tackle impact"
						scenario["status"] = "FAIL"
						all_pass = false
					elif render_requested and (not scenario.has("images") or scenario["images"].size() != 10 or 							scenario["images"].any(func(q): return q.get("errorCode", FAILED) != OK or q.get("bytes", 0) < 2000)):
						scenario["error"] = "Real Godot viewport face/side image missing or invalid"
						scenario["status"] = "FAIL"
						all_pass = false
					elif mode == "impact_with_hand_pins" and scenario["gripPhysicsLinks"] != 2:
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
