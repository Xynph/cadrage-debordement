extends SceneTree

var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view = load("res://match_view.gd").new()
	view.set_quality("economy")
	root.add_child(view)
	await process_frame
	check(not view._sun.shadow_enabled, "Economy quality can be selected before scene is ready")
	for profile in ["detail", "balanced", "unknown", "economy"]:
		view.set_quality(profile)
		check(view._sun.shadow_enabled == (profile != "economy"), "Shadow budget follows quality profile")
	var players: Array = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"x": 50 if side == 0 and slot == 0 else 20 + side * 40 + slot % 3 * 3,
				"y": 35 if side == 0 and slot == 0 else 7 + slot * 4,
				"featured": side == 0 and slot == 0})
	var live := {"scene": {"key": "carry-1", "kind": "carry", "possession": 0,
		"players": players, "ball": {"x": 50, "y": 35}, "origin": {"x": 45, "y": 35}}}
	view.apply_frame(live)
	for i in 50: await process_frame
	check(view._actors.size() == 30, "Thirty sporting actors remain present")
	check(view._ball.position.y > 0.8 and view._ball.position.y < 1.6, "Identified carrier holds ball above ground, near torso")
	var entry: Dictionary = view._actors["0-0"]
	var rigs: Array[Node] = entry.model.find_children("*", "Skeleton3D", true, false)
	check(rigs.size() == 1, "Licensed athlete has one usable skeleton")
	if not rigs.is_empty():
		var rig: Skeleton3D = rigs[0]
		for hand in ["Palm.L", "Palm.R"]:
			var index := rig.find_bone(hand)
			var hand_world := rig.to_global(rig.get_bone_global_pose(index).origin)
			check(hand_world.distance_to(view._ball.global_position) < 0.28, "Hand contacts held ball: " + hand)
		# The test deliberately traverses continuous turns and locomotion. Removing
		# the post-animation pose update or attaching the ball to a fixed world point
		# breaks these bounds while a static screenshot would still look correct.
		view.set_process(false)
		var original: Dictionary = live.duplicate(true)
		var largest_gap := 0.0
		var largest_stretch := 0.0
		for frame in 180:
			if frame % 12 == 0:
				live.scene.players[0].x = 50.0 + frame * 0.025
				live.scene.players[0].y = 35.0 + sin(frame * 0.02) * 1.5
				live.scene.ball = {"x": live.scene.players[0].x, "y": live.scene.players[0].y}
				var before: Dictionary = live.duplicate(true)
				view.apply_frame(live)
				check(live == before, "Presentation does not mutate source frame")
			view._process(1.0 / 60.0)
			for side in ["L", "R"]:
				var palm := rig.find_bone("Palm." + side)
				var upper := rig.find_bone("UpperArm." + side)
				var lower := rig.find_bone("LowerArm." + side)
				var gap := rig.to_global(rig.get_bone_global_pose(palm).origin).distance_to(view._ball.global_position)
				largest_gap = maxf(largest_gap, gap)
				var length := rig.get_bone_global_pose(upper).origin.distance_to(rig.get_bone_global_pose(lower).origin)
				var rest := rig.get_bone_global_rest(upper).origin.distance_to(rig.get_bone_global_rest(lower).origin)
				largest_stretch = maxf(largest_stretch, absf(length / rest - 1.0))
		check(largest_gap < 0.25, "Both wrists stay at ball surface throughout 180 moving frames")
		check(largest_stretch < 0.002, "No arm stretching across motion")
		print("CONTACT_METRICS ", JSON.stringify({"frames": 180, "max_wrist_ball_m": largest_gap, "max_relative_arm_stretch": largest_stretch}))
		original.scene.possession = 1
		view.apply_frame(original)
		view._process(1.0)
		check(view._carrier_id.is_empty(), "Featured opponent cannot acquire possession visually")
		original.scene.kind = "kick"
		original.scene.possession = 0
		view.apply_frame(original)
		view._process(1.0)
		check(view._carrier_id.is_empty(), "Kick releases the held ball")
		original.scene.players = []
		original.scene.ball = {}
		view.apply_frame(original)
		view._process(1.0)
		check(view._actors.is_empty() and not view._ball.visible, "No phantom carrier or ball after removal")
	print("MATCH_PRESENTATION_CHECKS ", JSON.stringify({"failures": failures, "ball": str(view._ball.position)}))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

