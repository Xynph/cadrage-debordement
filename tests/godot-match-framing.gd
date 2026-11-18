extends SceneTree

var failures: Array[String] = []
var metrics: Array = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func fixture(x: float = 50, y: float = 35) -> Dictionary:
	var players: Array = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"x": x if slot == 0 and side == 0 else 30 + side * 20 + slot % 3 * 2,
				"y": y if slot == 0 and side == 0 else 8 + slot * 4, "featured": slot == 0 and side == 0})
	return {"scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": x, "y": y}},
		"teams": [{"color": "#a12f41"}, {"color": "#a73043"}]}

func garment(view, id: String, name_: String) -> Color:
	var parameters := {"Shirt": "jersey_color", "Shirt2": "trim_color", "Pants": "shorts_color", "Socks": "socks_color"}
	for mesh in view._actors[id].model.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as ShaderMaterial
		if material and parameters.has(name_):
			return material.get_shader_parameter(parameters[name_]) as Color
	check(false, "Paramètre de tenue présent : " + name_)
	return Color.MAGENTA

func comfort(view, message: String) -> void:
	var point: Vector2 = view._camera.unproject_position(view._ball.global_position)
	var normalized: Vector2 = point / view.get_viewport().get_visible_rect().size
	check(normalized.x > 0.15 and normalized.x < 0.85 and normalized.y > 0.15 and normalized.y < 0.85, message + str(normalized))

## Part de l'image (grille de 32 x 18 rayons) qui montre le terrain et ses abords immédiats (3 m).
func pitch_share(view) -> float:
	var camera: Camera3D = view._camera
	var size: Vector2 = view.get_viewport().get_visible_rect().size
	var on := 0
	for i in 32:
		for j in 18:
			var pixel := Vector2((i + 0.5) / 32.0 * size.x, (j + 0.5) / 18.0 * size.y)
			var origin := camera.project_ray_origin(pixel)
			var normal := camera.project_ray_normal(pixel)
			if normal.y < -0.001:
				var hit := origin + normal * (-origin.y / normal.y)
				if absf(hit.x) <= 58.0 and absf(hit.z) <= 38.0:
					on += 1
	return on / 576.0

func on_screen(view, point: Vector3, margin: float = 0.0) -> bool:
	var camera: Camera3D = view._camera
	if camera.is_position_behind(point):
		return false
	var p: Vector2 = camera.unproject_position(point) / view.get_viewport().get_visible_rect().size
	return p.x >= margin and p.x <= 1.0 - margin and p.y >= margin and p.y <= 1.0 - margin

func settle(view, frame: Dictionary, seconds: float = 2.0) -> void:
	view.apply_frame(frame)
	for i in int(seconds * 60.0):
		view._process(1.0 / 60.0)

## Caméras de retransmission (18 novembre 2026) : terrain dans le cadre près des touches, coup de
## pied avec son point de chute, mêlée cadrée serrée, plan large en fin de match.
func broadcast_checks(view) -> Dictionary:
	var result := {}
	var Cadrage = load("res://match_cadrage.gd")
	var cadrage = Cadrage.new(view)
	view.set_cadrage(cadrage)
	view.set_camera("tv")
	check(view._camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "TV camera is a perspective broadcast camera")
	# Porteur collé à la touche lointaine puis à la touche proche : le terrain remplit l'image.
	for touch in [Vector2(50, 1), Vector2(30, 69), Vector2(97, 2)]:
		cadrage.regler(true, "carry")
		cadrage.couper()
		settle(view, fixture(touch.x, touch.y))
		var share := pitch_share(view)
		result["tv_pitch_share_%d_%d" % [int(touch.x), int(touch.y)]] = snappedf(share, 0.01)
		check(share >= 0.7, "TV near the touchline %s: the pitch fills at least 70%% of the picture (%.2f)" % [touch, share])
		comfort(view, "TV near the touchline: ball stays comfortable ")
		result["tv_size_%d_%d" % [int(touch.x), int(touch.y)]] = snappedf(view._camera.size, 0.1)
		check(view._camera.size <= Cadrage.HAUTEUR.tv[1] + 0.01, "TV zoom follows the useful players, not the whole pitch: " + str(view._camera.size))
	# Coût du cadrage (recentrage borné, toit de la tribune) : négligeable à 144 images par seconde.
	var started := Time.get_ticks_usec()
	for i in 300:
		view._fit_camera(1.0 / 60.0)
	var cost_ms := (Time.get_ticks_usec() - started) / 300.0 / 1000.0
	result["fit_camera_ms"] = snappedf(cost_ms, 0.001)
	check(cost_ms < 0.5, "Camera framing stays cheap: %.3f ms per frame" % cost_ms)
	# Coup de pied en caméra action : le ballon et son point de chute restent dans le cadre, le
	# cadrage s'élargit, la caméra glisse sans téléportation.
	view.set_camera("action")
	cadrage.regler(true, "carry")
	cadrage.couper()
	settle(view, fixture(30, 35), 1.0)
	cadrage.regler(true, "kick")
	var kick := fixture(74, 18)
	kick.scene.kind = "kick"
	view.apply_frame(kick)
	var landing: Vector3 = view._ball_target
	var widest := 0.0
	var ball_seen := true
	var landing_seen := true
	var max_step := 0.0
	for frame in 90:
		var previous: Vector3 = view._camera.position
		view._process(1.0 / 60.0)
		max_step = maxf(max_step, previous.distance_to(view._camera.position))
		if previous.distance_to(view._camera.position) > 3.0 or not on_screen(view, view._ball.global_position):
			printerr("KICK frame %d cam %s size %.1f look %s ball %s focus %s" % [frame, view._camera.position, view._camera.size, view._camera_look, view._ball.global_position, view._camera_focus])
		widest = maxf(widest, view._camera.size)
		ball_seen = ball_seen and on_screen(view, view._ball.global_position)
		if frame >= 45:
			landing_seen = landing_seen and on_screen(view, landing, 0.03)
	result["action_kick_widest"] = snappedf(widest, 0.1)
	result["action_kick_max_step"] = snappedf(max_step, 0.01)
	check(ball_seen, "Action kick: the ball never leaves the picture")
	check(landing_seen, "Action kick: the landing point is in the picture")
	check(widest > Cadrage.HAUTEUR.action[1] + 2.0, "Action kick widens beyond the contact framing: " + str(widest))
	check(max_step < 3.0, "Action kick: no camera teleport (largest step %.2f m)" % max_step)
	# Ballon qui réapparaît près du point visé : la caméra glisse.
	var hidden := fixture(56, 30)
	hidden.scene.ball = {}
	view.apply_frame(hidden)
	view._process(1.0 / 60.0)
	var before: Vector3 = view._camera.position
	view.apply_frame(fixture(58, 32))
	view._process(1.0 / 60.0)
	check(before.distance_to(view._camera.position) < 2.0, "Ball reappearing nearby: the camera glides, no jump")
	# Mêlée en caméra action : cadrage serré sur le paquet et les demis.
	var scrum := fixture(60, 30)
	scrum.scene.kind = "scrum"
	scrum.scene.key = "melee-1"
	cadrage.regler(true, "scrum")
	cadrage.couper()
	settle(view, scrum, 5.0)
	result["action_scrum_size"] = snappedf(view._camera.size, 0.1)
	result["scrum_group"] = view.regroupement().size()
	check(view.regroupement().size() >= 16, "Scrum group holds both packs: " + str(view.regroupement().size()))
	check(view._camera.size <= Cadrage.SERRE.action[1] + 0.01, "Action scrum framing is tight on the pack: " + str(view._camera.size))
	# Mi-temps et fin de match : plan large de tout le terrain.
	view.set_camera("tv")
	cadrage.regler(false)
	var final := fixture(80, 2)
	final.finished = true
	settle(view, final, 0.5)
	var corners := true
	for corner in [Vector3(-55, 0, -35), Vector3(55, 0, -35), Vector3(-55, 0, 35), Vector3(55, 0, 35)]:
		corners = corners and on_screen(view, corner)
	check(corners, "Full time: wide shot of the whole pitch")
	result["final_pitch_share"] = snappedf(pitch_share(view), 0.01)
	check(pitch_share(view) >= 0.4, "Full time: the pitch fills the wide shot (%.2f)" % pitch_share(view))
	final.finished = false
	settle(view, final, 0.5)
	check(not view._plan_large, "Play resumes after the wide shot")
	view.set_cadrage(null)
	return result

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	var live := fixture()
	var before := live.duplicate(true)
	view.apply_frame(live)
	view._process(1.0)
	check(live == before, "Source data is unchanged by framing and kit selection")
	check(view._actors.size() == 30, "Thirty actors stay present")
	# A valid featured identity is not enough to invent an invisible held ball.
	var carrier: Dictionary = view._actors["0-0"]
	check(carrier.holding and float(carrier.grip) == 1.0 and view._ball.visible, "Positive carry starts with a visible held ball")
	for absent_ball in [{}, {"x": 73}]:
		var missing := fixture(73, 49)
		missing.scene.ball = absent_ball
		var missing_before := missing.duplicate(true)
		var held_focus: Vector3 = view._camera_focus
		view.apply_frame(missing)
		check(view._carrier_id.is_empty() and not carrier.holding, "Valid carrier identity with absent ball cannot hold anything")
		view._process(0.25)
		check(float(carrier.grip) == 0.0, "Absent ball releases the old grip through its normal transition")
		check(not view._ball.visible and not view._ball_marker.is_visible_in_tree(), "Absent ball also hides its presentation ring")
		# 18 novembre 2026 : plus de saut au centre du terrain quand le ballon disparaît.
		check(view._camera_focus.is_equal_approx(held_focus), "Absent ball keeps the camera where it was (no jump to the centre)")
		check(missing == missing_before, "Missing-ball presentation preserves every input field")
		var returned := fixture(73, 49)
		var returned_before := returned.duplicate(true)
		view.apply_frame(returned)
		view._process(1.0 / 60.0)
		check(view._camera_focus.distance_to(view._ball.global_position) < 1.5, "Ball return: camera on the ball (cut when far, glide when near) %s %s" % [view._camera_focus, view._ball.global_position])
		comfort(view, "Returned ball is immediately comfortable: ")
		for frame in 30: view._process(1.0 / 60.0)
		check(view._carrier_id == "0-0" and carrier.holding and float(carrier.grip) == 1.0, "Valid carry and grip restore when ball returns")
		# Plus de cercle au sol en vue de retransmission (12 novembre 2026) ; il reste en vue de dessus.
		check(view._ball.visible and not view._ball_marker.is_visible_in_tree(), "Returned ball is visible, without a ground ring in the broadcast view")
		view.set_camera("tactical")
		view._process(1.0 / 60.0)
		var ring_position := Vector3(view._ball.global_position.x, 0.028, view._ball.global_position.z)
		check(view._ball_marker.is_visible_in_tree() and view._ball_marker.global_position.is_equal_approx(ring_position), "Top view keeps the ball ring on the ground")
		view.set_camera("tv")
		view._process(1.0 / 60.0)
		var rig: Skeleton3D = carrier.rig
		for hand in ["Palm.L", "Palm.R"]:
			var palm := rig.find_bone(hand)
			check(rig.to_global(rig.get_bone_global_pose(palm).origin).distance_to(view._ball.global_position) < 0.28, "Returned carrying pose restores hand contact: " + hand)
		check(returned == returned_before, "Returning-ball presentation preserves every input field")
	view.apply_frame(live)
	view._process(1.0)
	var home := garment(view, "0-0", "Shirt")
	var away := garment(view, "1-0", "Shirt")
	check(home == Color("a12f41"), "Home club source colour retained")
	check(Vector3(home.r, home.g, home.b).distance_to(Vector3(away.r, away.g, away.b)) > 0.65, "Similar source shirts receive a visibly contrasting away kit")
	check(garment(view, "1-0", "Shirt2") == Color("a73043"), "Away detail retains club source colour")
	# Aucun anneau d'équipe aux pieds des joueurs (retours de Léo, 12 novembre 2026) : les maillots distinguent les équipes.
	check(view._actors.values().all(func(entry: Dictionary): return entry.node.get_node_or_null("TeamMarker") == null), "No team ring at the players' feet")
	check(garment(view, "0-0", "Pants") == Color("202b35"), "Home shorts retain their original anthracite palette")
	check(garment(view, "1-0", "Pants") == Color("e5dfd1"), "Away shorts retain their original ivory palette")
	check(garment(view, "0-0", "Socks") == home and garment(view, "1-0", "Socks") == away, "High socks follow contrasting team colours")
	# A home-only pack change must also restore the away primary and refresh every material.
	live.teams[0].color = "#153763"
	view.apply_frame(live)
	check(garment(view, "1-0", "Shirt") == Color("a73043"), "Home pack change recomputes and restores away shirt")
	live.teams[1].presentation = {"color": "#193d69"}
	view.apply_frame(live)
	check(garment(view, "1-0", "Shirt") != Color("193d69"), "Presentation pack colours trigger away contrast")
	live.teams[0].color = "#f8f1dd"
	live.teams[1].presentation.color = "#f3ecd8"
	view.apply_frame(live)
	check(garment(view, "1-0", "Shirt").srgb_to_linear().get_luminance() < 0.05, "Pale pair uses an anthracite away shirt")
	var close_tone := fixture()
	close_tone.teams = [{"color": "#359a66"}, {"color": "#5a8ec4"}]
	view.apply_frame(close_tone)
	check(garment(view, "0-0", "Shirt") == Color("359a66"), "Pau keeps its home shirt")
	check(garment(view, "1-0", "Shirt") == Color("f0ecdf"), "Pau–Montpellier uses the turf-visible ivory for almost equal brightness")
	check(garment(view, "1-0", "Shirt2") == Color("5a8ec4"), "Montpellier keeps its club colour as trim")
	close_tone.teams = [{"color": "#d4b340"}, {"color": "#d4b340"}]
	view.apply_frame(close_tone)
	check(garment(view, "1-0", "Shirt") == Color("202b35"), "Identical golden shirts keep the darker fallback")
	close_tone.teams = [{"color": "#d43e47"}, {"color": "#6f9ac9"}]
	view.apply_frame(close_tone)
	check(garment(view, "1-0", "Shirt") == Color("6f9ac9"), "Toulouse–Vannes keeps its contrasting source kits")
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		print("VIEWPORT ", root.size, " ", root.get_visible_rect())
		var heights := {}
		for mode in ["tactical", "tv", "action"]:
			view.set_camera(mode)
			view.apply_frame(fixture())
			view._process(1.0)
			var camera: Camera3D = view._camera
			# Caméras en perspective (18 novembre 2026) : silhouette mesurée au point visé, au centre de l'image.
			var centre: Vector3 = Vector3(view._camera_look.x, 0.0, view._camera_look.z)
			var outline := Rect2(camera.unproject_position(centre), Vector2.ZERO)
			for x in [-0.45, 0.45]:
				for y in [0.0, 1.9]:
					for z in [-0.25, 0.25]:
						outline = outline.expand(camera.unproject_position(centre + Vector3(x, y, z)))
			heights[mode] = outline.size.y
			var basis := camera.global_basis
			var max_step := 0.0
			for point in [Vector2(-5, 0), Vector2(105, 70), Vector2(105, 0), Vector2(-5, 70)]:
				view.apply_frame(fixture(point.x, point.y))
				for frame in 40:
					var previous := camera.position
					view._process(1.0 / 60.0)
					max_step = maxf(max_step, camera.position.distance_to(previous))
					if mode != "tactical": comfort(view, "%s %s ball remains in comfort: " % [size, mode])
					# Caméra-grue (18 novembre 2026) : l'angle suit la profondeur du jeu, sans à-coup ni roulis.
					check(absf(camera.global_basis.x.y) < 0.001 and camera.global_basis.z.angle_to(basis.z) < 0.05, "Follow camera has no aim snap or roll")
					basis = camera.global_basis
			check(max_step < 5.5, "No unrequested cut during the long corner-to-corner pass")
			if mode == "tactical":
				for corner in [Vector3(-55, 0, -35), Vector3(55, 0, -35), Vector3(-55, 0, 35), Vector3(55, 0, 35)]:
					var projected := camera.unproject_position(corner)
					check(Rect2(Vector2.ZERO, Vector2(size)).has_point(projected), "Tactical contains all pitch corners")
			else:
				var position_ := camera.position
				view.set_camera(mode)
				check(camera.position == position_, "Reapplying same preference does not reset framing")
				view.set_quality("economy")
				check(camera.position == position_, "Changing quality does not reset camera preference")
				var paused := fixture(54, 32)
				paused.paused = true
				view.apply_frame(paused)
				view._process(1.0)
				for frame in 180:
					if frame % 12 == 0: view.apply_frame(paused)
					view._process(1.0 / 60.0)
				var settled := camera.position
				view.apply_frame(paused)
				view._process(1.0 / 60.0)
				check(camera.position.distance_to(settled) < 0.001, "Repeated paused snapshots stay settled without catch-up")
				view.set_camera("tactical")
				view.set_camera(mode)
				comfort(view, "Explicit mode change cuts cleanly to the current ball: ")
				var refused := fixture()
				refused.scene.players[0].id = ""
				refused.scene.ball = {}
				var aim: Vector3 = view._camera_focus
				view.apply_frame(refused)
				view._process(1.0 / 60.0)
				check(view._camera_focus.is_equal_approx(aim) and view._carrier_id.is_empty(), "Missing ball and refused ID hold the camera without a false carrier")
				view.apply_frame({"scene": {}})
				view._process(1.0)
				check(not view._ball.visible and view._carrier_id.is_empty(), "Empty scene leaves no false ball or carrier")
				view.apply_frame(fixture(-5, 0))
				view._process(1.0 / 60.0)
				comfort(view, "First frame after absence cuts to ball: ")
				var flight := fixture(105, 70)
				flight.scene.kind = "kick"
				view.apply_frame(flight)
				for frame in 40:
					view._process(1.0 / 60.0)
					comfort(view, "Long released flight stays comfortable including visual arc (%s, frame %d): " % [mode, frame])
				check(view._carrier_id.is_empty(), "Released flight never invents a carrier")
		check(heights.tv > heights.tactical * 1.6, "TV makes bodies appreciably larger than tactical")
		check(heights.action > heights.tv * 1.7, "Action makes bodies appreciably larger than TV")
		metrics.append({"viewport": str(size), "body_height_px": heights})
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await process_frame
	metrics.append(await broadcast_checks(view))
	print("MATCH_FRAMING_CHECKS ", JSON.stringify({"failures": failures, "projections": metrics}))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)



