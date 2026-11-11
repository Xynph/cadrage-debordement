extends SceneTree
## Réception visuelle du match : captures jour/soirée × TV/tactique/action × trois
## niveaux de qualité, avec mesures. Outil manuel, non lancé par la CI.
##
##   godot --path native/godot --script ../../tests/godot-match-render-capture.gd
##   CD_MATCH_RENDER_PROOF : dossier absolu des captures et de report.json (requis)
##   CD_MATCH_RENDER_SIZE  : "1920x1080" par défaut
##   CD_MATCH_RENDER_QUALITY : un seul niveau ("economy", "balanced" ou "detail") pour un calibrage rapide
##
## Le script n'utilise que l'API publique de match_view.gd et fonctionne donc sur
## main (avant) comme sur la branche de rendu (après).

const Stadium = preload("res://match_stadium_evening.gd")
const View = preload("res://match_view.gd")

var view: NativeMatchView
var kit: Stadium


func _initialize() -> void:
	call_deferred("run")


## Phase de jeu lisible : ruck à 30 m, ligne d'attaque en profondeur, défense à plat.
func fixture() -> Dictionary:
	var players: Array[Dictionary] = []
	for side in 2:
		for slot in 15:
			var forward := slot < 8
			var x := 0.0
			var y := 0.0
			if forward:
				x = 46.0 + side * 4.0 + (slot % 4) * (1.4 if side == 0 else -1.4)
				y = 30.0 + (slot / 4) * 3.0 + (slot % 2) * 1.5
			else:
				x = (41.0 - (slot - 8) * 2.2) if side == 0 else (53.0 + (slot - 8) * 0.6)
				y = 36.0 + (slot - 8) * 4.6
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"featured": side == 0 and slot == 9, "x": x, "y": y})
	return {
		"paused": true,
		"scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 41.5, "y": 41.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}],
	}


func run() -> void:
	var proof := OS.get_environment("CD_MATCH_RENDER_PROOF")
	if proof.is_empty() or not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("CD_MATCH_RENDER_PROOF doit désigner un dossier absolu accessible.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles en --headless : lancer avec un affichage (Windows, X11 ou Xvfb).")
		quit(2)
		return
	var size_text := OS.get_environment("CD_MATCH_RENDER_SIZE")
	var parts := (size_text if not size_text.is_empty() else "1920x1080").split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var started := Time.get_ticks_msec()
	root.title = "Réception du rendu de match"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	kit = Stadium.new()
	kit.attach(view)
	var has_quality := view.has_method("set_quality")
	var report := {
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"size": [size.x, size.y], "captures": [],
	}
	var levels := ["economy", "balanced", "detail"] if has_quality else ["balanced"]
	var only := OS.get_environment("CD_MATCH_RENDER_QUALITY")
	if only in levels:
		levels = [only]
	for quality in levels:
		if has_quality:
			view.set_quality(quality)
		for evening in [false, true]:
			kit.set_evening(evening)
			if has_quality and kit.has_method("apply_quality"):
				kit.apply_quality(quality)
			for camera in ["tv", "tactical", "action"]:
				view.set_camera(camera)
				view._process(1.0 / 60.0)
				for settle in 6:
					await RenderingServer.frame_post_draw
				var before := Time.get_ticks_usec()
				for sample in 4:
					view._process(1.0 / 60.0)
					await RenderingServer.frame_post_draw
				var frame_ms := (Time.get_ticks_usec() - before) / 4000.0
				var image := root.get_texture().get_image()
				var name := "%s-%s-%s.png" % ["soiree" if evening else "jour", camera, quality]
				if image.save_png(proof.path_join(name)) != OK:
					push_error("Écriture impossible : " + name)
					quit(1)
					return
				# Luminance moyenne et part de pixels écrêtés : repères de calibrage.
				image.resize(160, 90, Image.INTERPOLATE_BILINEAR)
				var total := 0.0
				var clipped := 0
				var crushed := 0
				for y in 90:
					for x in 160:
						var luma := image.get_pixel(x, y).get_luminance()
						total += luma
						if luma > 0.97: clipped += 1
						if luma < 0.03: crushed += 1
				report.captures.append({"file": name, "frame_ms": snappedf(frame_ms, 0.1),
					"mean_luma": snappedf(total / 14400.0, 0.001),
					"clipped_pct": snappedf(clipped / 144.0, 0.1), "crushed_pct": snappedf(crushed / 144.0, 0.1)})
				print("CAPTURE ", name, " ", frame_ms, " ms")
	report["total_ms"] = Time.get_ticks_msec() - started
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATCH_RENDER_CAPTURE ", JSON.stringify({"captures": report.captures.size(), "driver": report.driver, "method": report.method}))
	quit(0)
