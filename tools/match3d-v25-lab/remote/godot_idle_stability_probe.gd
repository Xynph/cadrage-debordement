extends SceneTree
## Isolated diagnosis. One REAL GLB per LOD, NO approach, NO impact, NO hand pins.
## Test target pose and physics tracking separately; no cosmetic stabilization.
## Render the actual skinned GLB at idle start and end for each variant.

func skeleton_find(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for child in n.get_children():
		var x := skeleton_find(child)
		if x != null:
			return x
	return null

func animation_find(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for child in n.get_children():
		var x := animation_find(child)
		if x != null:
			return x
	return null

func terrain() -> void:
	var body := StaticBody3D.new()
	body.name = "RealRigidPitch"
	body.position.y = -0.5
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(15, 1, 15)
	c.shape = b
	body.add_child(c)
	get_root().add_child(body)

func camera_setup() -> Camera3D:
	get_root().size = Vector2i(800, 450)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.75, 0.84, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.9)
	e.ambient_light_energy = 1.2
	world.environment = e
	get_root().add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.6
	get_root().add_child(light)
	var field := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(15, 15)
	field.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.26, 0.42, 0.31)
	field.material_override = material
	get_root().add_child(field)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.current = true
	get_root().add_child(cam)
	return cam

func render_phase(cam: Camera3D, folder: String, lod: int, mode: String, phase: String) -> Array:
	var shots := []
	paused = true
	for view in ["front", "side"]:
		cam.position = Vector3(0, 1.5, 3.2) if view == "front" else Vector3(3.2, 1.5, 0)
		cam.look_at(Vector3(0, 0.82, 0), Vector3.UP)
		await RenderingServer.frame_post_draw
		var im := get_root().get_texture().get_image()
		var p := folder.path_join("lod%d_%s_%s_%s.jpg" % [lod,mode,phase,view])
		var code := im.save_jpg(p, 0.90)
		shots.append({"file":p.get_file(),"error":code,"bytes":FileAccess.get_file_as_bytes(p).size() if code==OK else 0})
	paused = false
	return shots

func measures(frame: int, sk: Skeleton3D, builder: PhysicsRigBuilder, spring: SpringResolver, kc: KickbackCharacter) -> Dictionary:
	var bodies := builder.get_bodies()
	var data := {"frame":frame,"setupComplete":kc.is_setup_complete(),
		"springActive":spring.is_active(),"targetOffsets":{},
		"bones":{},"normalState":kc.get_active_state_name()}
	var lowest := INF
	for role in ["Hips","Chest","Foot_L","Foot_R","Hand_L","Hand_R"]:
		if not bodies.has(role):
			continue
		var rb: RigidBody3D = bodies[role]
		var idx := spring.get_bone_idx(role)
		if idx < 0:
			continue
		var wanted: Transform3D = sk.global_transform * spring.get_animation_bone_global(idx)
		var physical: Vector3 = rb.global_position
		var aim: Vector3 = wanted.origin
		data["bones"][role] = {"physicsY":physical.y,"targetY":aim.y,
			"targetErrorM":physical.distance_to(aim),
			"velocityMps":rb.linear_velocity.length(),
			"strength":spring.get_bone_strength(role),
			"gravityScale":rb.gravity_scale}
		if role.begins_with("Foot"):
			lowest = minf(lowest, physical.y)
	data["minFootRigidCenterY"]=lowest
	return data

func _initialize() -> void:
	call_deferred("run_stability")

func run_stability() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 and args.size() != 5:
		printerr("Expected report.json, three GLB copies, optional visual flag")
		quit(2)
		return
	var visual := args.size()==5 and args[4]=="visual"
	var outfolder := str(args[0]).get_base_dir().path_join("idle-stability-images")
	if visual:
		DirAccess.make_dir_recursive_absolute(outfolder)
	var cam: Camera3D = camera_setup() if visual else null
	terrain()
	var result := {"schema":1,"status":"FAIL","test":"REAL_CANONICAL_IDLE_NO_IMPULSE_NO_PIN",
		"qualifiesRugbyTackle":false,"skinVertexFloorTest":"NOT_EXECUTED",
		"modes":[],"visualRequested":visual}
	var all_valid := true
	for lod in 3:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(args[lod+1],state)
		if err != OK:
			all_valid = false
			result["modes"].append({"lod":lod,"error":"GLB import rejected","code":err})
			continue
		for mode in ["animated_only","kickback_default","no_foot_ik","no_root_strip","no_foot_ik_no_root_strip"]:
			var item := {"lod":lod,"mode":mode,"status":"FAIL","samples":[]}
			var actor := Node3D.new()
			actor.name = "CanonicalIdleLOD%d%s" % [lod,mode]
			get_root().add_child(actor)
			var model := doc.generate_scene(state)
			actor.add_child(model)
			var sk := skeleton_find(model)
			var animation := animation_find(model)
			if sk==null or animation==null or animation.get_animation("idle")==null:
				item["error"]="Missing real animation or skeleton"
				all_valid = false
				actor.queue_free()
				result["modes"].append(item)
				continue
			animation.play("idle")
			animation.seek(0.0,true)
			if mode=="animated_only":
				for frame in 12:
					await physics_frame
				var index := sk.find_bone("spine_03")
				item["targetAt12"]=sk.global_transform * sk.get_bone_global_pose(index)
				item["targetAt12"]=item["targetAt12"].origin.y
				if visual:item["images"]=await render_phase(cam,outfolder,lod,mode,"idle")
				item["status"]="PASS_REFERENCE_ONLY"
			else:
				var profile := SkeletonDetector.create_profile_from_skeleton(sk,
					SkeletonDetector.detect_humanoid_bones(sk))
				var tuning := RagdollTuning.create_default()
				if mode=="no_foot_ik" or mode=="no_foot_ik_no_root_strip":
					tuning.foot_ik_enabled = false
				if mode=="no_root_strip" or mode=="no_foot_ik_no_root_strip":
					tuning.strip_root_motion = false
				var nodes := KickbackSetup.add_active_rig(actor,sk,profile,tuning)
				var builder: PhysicsRigBuilder = nodes[0]
				var spring: SpringResolver = nodes[2]
				var kc: KickbackCharacter = nodes[4]
				var complete := false
				for frame in 120:
					await physics_frame
					if kc.is_setup_complete() and spring.get_all_bone_names().size()==16:
						complete=true
						break
				item["setupComplete"]=complete
				item["boneCount"]=builder.get_bodies().size()
				if not complete:
					item["error"]="Spring target / rig initialization incomplete"
					all_valid=false
				else:
					item["samples"].append(measures(0,sk,builder,spring,kc))
					if visual:item["images"]=await render_phase(cam,outfolder,lod,mode,"begin")
					for frame in 60:
						await physics_frame
						if frame in [11,29,59]:
							item["samples"].append(measures(frame+1,sk,builder,spring,kc))
					if visual:item["images"].append_array(await render_phase(cam,outfolder,lod,mode,"end"))
					var first: Dictionary = item["samples"][0]["bones"]["Chest"]
					var last: Dictionary = item["samples"][-1]["bones"]["Chest"]
					item["physicalChestDropM"]=first["physicsY"]-last["physicsY"]
					item["targetChestDropM"]=first["targetY"]-last["targetY"]
					item["endChestTargetErrorM"]=last["targetErrorM"]
					item["stabilityPass"]=absf(item["physicalChestDropM"])<=0.15 and item["endChestTargetErrorM"]<=0.15
					item["status"]="PASS_STABLE" if item["stabilityPass"] else "FAIL_UNSTABLE"
			for frame in 2:
				await physics_frame
			actor.queue_free()
			await process_frame
			result["modes"].append(item)
	result["status"]="DIAGNOSTIC_COMPLETE" if all_valid else "FAIL"
	var f := FileAccess.open(args[0],FileAccess.WRITE)
	if f!=null:
		f.store_string(JSON.stringify(result,"\t"))
		f.close()
	print("CD_KICKBACK_IDLE_STABILITY=",JSON.stringify(result))
	# Diagnostic comparisons should complete even when existing defaults fail;
	# explicit per-mode stability verdicts are never silently promoted.
	quit(0 if all_valid else 2)
