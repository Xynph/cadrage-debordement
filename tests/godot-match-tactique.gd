extends SceneTree

var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func fixture() -> Dictionary:
	var players: Array = []
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"x": 30 + side * 20 + slot % 3 * 2, "y": 8 + slot * 4, "featured": slot == 8 and side == 0})
	return {"scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 30 + 16, "y": 8 + 8 * 4}},
		"teams": [{"color": "#d43e47"}, {"color": "#6f9ac9"}]}

## Hauteur (px) occupée à l'écran par un repère de joueur (disque).
func disc_pixels(view, id: String) -> float:
	var disc: MeshInstance3D = view._actors[id].node.get_node("TacticalMarker/Disque")
	var centre: Vector3 = disc.global_position
	var a: Vector2 = view._camera.unproject_position(centre + Vector3(-1.5, 0, 0))
	var b: Vector2 = view._camera.unproject_position(centre + Vector3(1.5, 0, 0))
	return a.distance_to(b)

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	# Vue TV : aucun repère ni balise visible.
	for mode in ["tv", "action"]:
		view.set_camera(mode)
		view._process(1.0 / 60.0)
		var any_marker := false
		for entry in view._actors.values():
			any_marker = any_marker or (entry.node.get_node("TacticalMarker") as Node3D).is_visible_in_tree()
		check(not any_marker, "Aucun repère de joueur en vue " + mode)
		check(not view._ball_beacon.is_visible_in_tree(), "Aucune balise du ballon en vue " + mode)
		check(not view._ball_marker.is_visible_in_tree(), "Pas d'anneau au sol en vue " + mode)
	# Vue tactique : repères, numéros, balise.
	view.set_camera("tactical")
	view._process(1.0 / 60.0)
	check(view._actors.size() == 30, "Trente joueurs")
	var porteur: String = view._carrier_id
	check(porteur == "0-8", "Porteur du ballon désigné : " + porteur)
	for id in view._actors:
		var node: Node3D = view._actors[id].node
		var marker := node.get_node_or_null("TacticalMarker") as Node3D
		check(marker != null and marker.is_visible_in_tree(), "Repère visible en vue tactique : " + id)
		var label := node.get_node("TacticalMarker/Numero") as Label3D
		var slot := int(id.split("-")[1])
		check(label.text == str(slot + 1), "Numéro de maillot %s = %s" % [id, label.text])
		check(disc_pixels(view, id) >= 18.0, "Disque d'au moins 18 px : %s (%.1f)" % [id, disc_pixels(view, id)])
	var colour_home: Color = ((view._actors["0-0"].node.get_node("TacticalMarker/Disque") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	var colour_away: Color = ((view._actors["1-0"].node.get_node("TacticalMarker/Disque") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	check(colour_home == Color("d43e47") and colour_away != colour_home, "Disques aux couleurs des équipes")
	var number_colour: Color = (view._actors["0-0"].node.get_node("TacticalMarker/Numero") as Label3D).modulate
	check(Vector3(number_colour.r, number_colour.g, number_colour.b).distance_to(Vector3(colour_home.r, colour_home.g, colour_home.b)) > 0.5, "Numéro contrasté sur son disque")
	var carrier_marker := view._actors[porteur].node.get_node("TacticalMarker") as Node3D
	var other_marker := view._actors["0-0"].node.get_node("TacticalMarker") as Node3D
	check(carrier_marker.scale.x > other_marker.scale.x, "Le porteur a un repère agrandi")
	# Ballon marqué : balise jaune vif, plus grande que le ballon, au-dessus de tout.
	check(view._ball.visible and view._ball_beacon.is_visible_in_tree(), "Balise du ballon visible en vue tactique")
	var ring: MeshInstance3D = view._ball_beacon.get_child(1)
	var material := ring.material_override as StandardMaterial3D
	check(material.albedo_color.r > 0.9 and material.albedo_color.g > 0.8 and material.albedo_color.b < 0.2, "Balise jaune vif")
	check(material.no_depth_test and material.render_priority >= 20, "Balise toujours dessus")
	var ball_centre: Vector2 = view._camera.unproject_position(view._ball.global_position)
	var ball_edge: Vector2 = view._camera.unproject_position(view._ball.global_position + Vector3(2.7, 0, 0))
	check(ball_centre.distance_to(ball_edge) >= 15.0, "Balise d'au moins 15 px de rayon")
	# Retour en TV : tout disparaît de nouveau.
	view.set_camera("tv")
	view._process(1.0 / 60.0)
	check(not carrier_marker.is_visible_in_tree() and not view._ball_beacon.is_visible_in_tree(), "Retour en TV : repères masqués")
	print("MATCH_TACTIQUE_CHECKS ", JSON.stringify({"failures": failures}))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
