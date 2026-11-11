extends SceneTree
## Run from the native project with --script ../../tests/godot-office-props.gd.
## Use the graphical runner to save before/after captures to CD_OFFICE_PROP_CAPTURES.
const PROP_SCENE := "res://art/office_props/office_props.tscn"
const SIZE := Vector2(260, 78)
const SCREEN_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

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
	var report := {
		"passed": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"native_display": DisplayServer.get_name(),
	}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for frame in 8:
		await process_frame

func wait_for_engine(app: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	if is_instance_valid(app.timer): app.timer.stop()
	return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.has_environment("CD_OFFICE_PROP_CAPTURES"):
		return
	await RenderingServer.frame_post_draw
	var file := OS.get_environment("CD_OFFICE_PROP_CAPTURES").path_join(label + ".png")
	check(root.get_texture().get_image().save_png(file) == OK, "Capture " + label)

func verify_scale(studio: SubViewport) -> void:
	var ball := studio.get_node_or_null("Ballon")
	var cup := studio.get_node_or_null("Coupe")
	if not check(ball != null and cup != null, "Deux modèles importés"):
		return
	for prop: Node in [ball, cup]:
		var meshes := prop.find_children("*", "MeshInstance3D", true, false)
		if prop is MeshInstance3D:
			meshes.push_front(prop)
		if not check(meshes.size() == 1, "Un maillage par accessoire : " + prop.name):
			continue
		var mesh := meshes[0] as MeshInstance3D
		var size_m := mesh.get_aabb().size
		var measured := size_m.x if prop == ball else size_m.y
		var expected := 0.29 if prop == ball else 0.38
		check(absf(measured - expected) <= 0.001, "Dimensions à 1 mm près : " + prop.name)


func check_ball_material(studio_image: Image) -> void:
	var ivory := 0
	var green := 0
	for y in range(84, 135):
		for x in range(143, 218):
			var color := studio_image.get_pixel(x, y)
			if color.a < 0.75:
				continue
			if color.r > 0.46 and color.g > 0.46 and color.b > 0.36:
				ivory += 1
			elif color.g > color.r * 1.12 and color.g > 0.12:
				green += 1
	check(ivory > 450 and green > 80, "Matière ivoire et marquages verts visibles sur le ballon")


func run() -> void:
	if not check(ResourceLoader.exists(PROP_SCENE), "La vitrine 3D est importable"):
		finish()
		return
	var profile := OS.get_environment("CD_GODOT_DATA_DIR")
	var directory := DirAccess.open(profile)
	if not check(profile.is_absolute_path() and directory != null, "Profil de recette absolu et existant"):
		finish()
		return
	directory.include_hidden = true
	if not check(directory.get_files().is_empty() and directory.get_directories().is_empty(), "Profil de recette vierge"):
		finish()
		return
	var showroom := load(PROP_SCENE) as PackedScene
	var app := load("res://main.tscn").instantiate() as Control
	root.mode = Window.MODE_WINDOWED
	root.add_child(app)
	if not check(await wait_for_engine(app), "Connexion au moteur réel"):
		finish()
		return
	app._command("new_career", {"club": 0, "mode": "fiction"})
	if not check(await wait_for_engine(app), "Création de la carrière témoin"):
		finish()
		return
	if is_instance_valid(app.coach):
		app.coach.close()
	for screen_size: Vector2i in SCREEN_SIZES:
		root.size = screen_size
		app._navigate("Bureau")
		await settle()
		var match_status := app.find_child("ImmersiveOfficeMatchStatus", true, false) as Label
		if not check(match_status != null, "Le vrai Bureau est visible en %s" % screen_size):
			continue
		if is_instance_valid(app.coach):
			app.coach.close()
		await settle()
		await capture("bureau-%s-avant" % screen_size.y)
		var title_row := match_status.get_parent() as Control
		if screen_size.x < 1600 or match_status.visible:
			check(title_row.get_node_or_null("OfficeProps") == null, "Dégagement de l’en-tête compact ou du statut de match")
			await capture("bureau-%s-apres" % screen_size.y)
			continue
		var preview := showroom.instantiate() as TextureRect
		check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE and preview.focus_mode == Control.FOCUS_NONE, "Vitrine décorative sans capture de l’entrée")
		var viewport := preview.get_node("Studio") as SubViewport
		check(viewport.own_world_3d and viewport.transparent_bg, "Rendu indépendant et transparent")
		verify_scale(viewport)
		title_row.add_child(preview)
		# Position provisoire, appliquée au véritable en-tête du Bureau.
		preview.position = Vector2(965, 7) * app.Immersive.C.density
		preview.size = SIZE * app.Immersive.C.density
		await settle()
		var physical := preview.get_global_transform_with_canvas()
		check(is_equal_approx(physical.x.length() / physical.y.length(), 1.0), "Proportions conservées")
		await capture("bureau-%s-apres" % screen_size.y)
		if DisplayServer.get_name() != "headless":
			var studio_image := viewport.get_texture().get_image()
			if check(studio_image != null and studio_image.get_used_rect().size.y > viewport.size.y / 2, "Rendu 3D effectivement dessiné"):
				check_ball_material(studio_image)
				var camera := viewport.get_camera_3d()
				camera.position.x += 0.1
				await RenderingServer.frame_post_draw
				check(viewport.get_texture().get_image().get_data() == studio_image.get_data(), "L’image reste fixe même après déplacement de la caméra")
				if OS.has_environment("CD_OFFICE_PROP_CAPTURES"):
					check(studio_image.save_png(OS.get_environment("CD_OFFICE_PROP_CAPTURES").path_join("insert.png")) == OK, "Capture de l’insert")
		preview.queue_free()
	finish()
