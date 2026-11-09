extends SceneTree

const MatchView = preload("res://match_view.gd")
const Cut = preload("res://match_cut.gd")
const Motion = preload("res://match_motion.gd")
const Presentation = preload("res://match_presentation.gd")

var failures: Array[String] = []
var measurements: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func prepare(before: Dictionary) -> NativeMatchView:
	var view := MatchView.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame(before)
	step(view, 38)
	return view


func step(view: NativeMatchView, frames: int) -> void:
	for _frame in frames:
		view._process(1.0 / 120.0)


func run() -> void:
	var fixture := OS.get_environment("CD_ANIMATION_LIVE_CUT_FIXTURE")
	var samples: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	if not samples is Array or samples.size() != 2:
		printerr("Deux portages du moteur sont requis.")
		quit(1)
		return
	for sample: Dictionary in samples:
		var after: Dictionary = sample.after
		var plan: Dictionary = after.scene.cut
		var view := prepare(sample.before)
		view.apply_frame(after)
		var carrier: Dictionary = view._actors.get(plan.carrier, {})
		if carrier.is_empty():
			check(false, "Porteur réel présent dans la vue")
			view.queue_free()
			await process_frame
			continue
		check(view._actors.size() == 30, "Présence des trente joueurs")
		check(view._carrier_id == plan.carrier and view._ball_attached, "Ballon attaché au porteur déclaré")
		check(carrier.cut_direction == int(plan.side), "Sens déclaré appliqué au porteur")
		var actor: Node3D = carrier.node
		var rig: Skeleton3D = carrier.rig
		var foot := rig.find_bone("Foot.R" if int(plan.side) > 0 else "Foot.L")
		var planted_frames := 0
		var max_slip := 0.0
		var max_height := 0.0
		for _frame in 23:
			step(view, 1)
			if carrier.cut_beat < 0.096 or carrier.cut_beat > 0.168:
				continue
			if carrier.cut_pose.has(foot) and carrier.cut_plant.has("world"):
				var position := rig.to_global(rig.get_bone_global_pose(foot).origin)
				planted_frames += 1
				max_slip = maxf(max_slip, position.distance_to(carrier.cut_plant.world))
				max_height = maxf(max_height, position.y)
		check(planted_frames >= 8 and max_slip < 0.04 and max_height < 0.075,
			"Appui extérieur stable au sol pendant au moins huit images à 120 Hz")
		var torso := rig.find_bone("Torso")
		var lean := 0.0
		var lateral := 0.0
		if carrier.cut_pose.has(torso):
			var base: Quaternion = carrier.cut_pose[torso][1]
			lean = base.angle_to(rig.get_bone_pose_rotation(torso))
			var parent_basis := rig.get_bone_global_pose(rig.get_bone_parent(torso)).basis
			var baseline := (parent_basis * Basis(base)).y.normalized()
			var posed := rig.get_bone_global_pose(torso).basis.y.normalized()
			var right := (rig.global_basis.inverse() * actor.global_basis.x).normalized()
			lateral = (posed - baseline).dot(right)
		check(lean > 0.10 and lateral * int(plan.side) > 0.06, "Inclinaison du buste dans le sens déclaré")
		var expected := Motion.position_at(carrier.from, carrier.target, carrier.tangent,
			Cut.live_travel(float(carrier.elapsed) / MatchView.BLEND_SECONDS))
		check(actor.position.is_equal_approx(expected), "L’appui reste sur le trajet de la phase")
		var anchor := Presentation.ball_anchor(actor, rig)
		var gap := anchor.distance_to(view._ball.global_position)
		check(gap < 0.001, "Le ballon suit la poitrine sans trajet séparé")
		for id: String in view._actors:
			if id != plan.carrier:
				check(view._actors[id].cut_pose.is_empty(), "Aucun autre joueur ne prend la pose")

		var beat: float = carrier.cut_beat
		view.apply_frame(after)
		check(is_equal_approx(carrier.cut_beat, beat), "Même clé sans redémarrage de l’appui")

		if int(plan.side) < 0:
			var paused := after.duplicate(true)
			paused.paused = true
			view.apply_frame(paused)
			step(view, 1)
			check(carrier.cut_direction == 0 and carrier.cut_pose.is_empty(), "La pause retire la pose")
			view.apply_frame(after)
			step(view, 1)
			check(carrier.cut_direction == 0 and carrier.cut_pose.is_empty(), "La reprise de la même action ne rejoue pas l’appui")
		else:
			step(view, 15)
			check(carrier.cut_pose.is_empty(), "Retour à la pose source avant le prochain tick moteur")
			view.apply_frame(after)
			step(view, 1)
			check(carrier.cut_pose.is_empty(), "Un rafraîchissement tardif ne rejoue pas l’appui")
			step(view, 28)
			check(actor.position.is_equal_approx(carrier.target), "Le porteur rejoint le point d’arrivée dans le délai habituel")

		measurements.append({"minute": sample.event.min, "side": plan.side, "torso_angle_rad": lean,
			"lateral_lean": lateral, "ball_gap_m": gap, "planted_frames_120hz": planted_frames,
			"max_slip_m": max_slip, "max_height_m": max_height})
		view.queue_free()
		await process_frame

	var reduced := prepare(samples[0].before)
	reduced.set_action_motion(false)
	reduced.apply_frame(samples[0].after)
	step(reduced, 15)
	var reduced_carrier: Dictionary = reduced._actors[samples[0].after.scene.cut.carrier]
	check(reduced_carrier.cut_direction == 0 and reduced_carrier.cut_pose.is_empty(), "Les mouvements réduits désactivent l’appui")
	reduced.set_action_motion(true)
	reduced.apply_frame(samples[0].after)
	step(reduced, 15)
	check(reduced_carrier.cut_pose.is_empty(), "Réactiver le mouvement ne rejoue pas la même action")
	reduced.queue_free()
	await process_frame
	print("LIVE_CUT_GODOT ", JSON.stringify({"failures": failures, "measurements": measurements}))
	quit(0 if failures.is_empty() else 1)
