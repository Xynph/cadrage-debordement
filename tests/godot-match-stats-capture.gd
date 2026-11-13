extends SceneTree
## Captures de l'écran entre les temps forts avec la feuille de statistiques (outil manuel, lancé par
## tests/godot-match-stats-capture.cjs) : un entracte en cours de match, puis l'écran « Match terminé ».
## La vraie interface et le vrai moteur. Variables : CD_STATS_SAVE (match exporté), CD_STATS_PNG_ENTRACTE,
## CD_STATS_PNG_FIN (captures PNG 1280×720), CD_STATS_ENTRACTE (numéro de l'entracte capturé, 3 par défaut).

var app: Control

func _initialize() -> void:
	call_deferred("run")

func surface() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "live" else null

func fin(code: int) -> void:
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(code)

func run() -> void:
	var size := Vector2i(1280, 720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	while app.waiting or app.model.is_empty(): await process_frame
	app.timer.stop()
	for forced: Signal in [root.size_changed, root.focus_entered]:
		if forced.is_connected(app._keep_filled_display): forced.disconnect(app._keep_filled_display)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	for i in 6: await process_frame
	if not app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_STATS_SAVE"))}):
		push_error("Import refusé")
		fin(2)
		return
	while app.waiting: await process_frame
	for i in 8: await process_frame
	var view := surface()
	var voulu := int(OS.get_environment("CD_STATS_ENTRACTE")) if OS.get_environment("CD_STATS_ENTRACTE").is_valid_int() else 3
	var png_entracte := OS.get_environment("CD_STATS_PNG_ENTRACTE")
	var png_fin := OS.get_environment("CD_STATS_PNG_FIN")
	var entractes := 0
	var precedent := -1
	var dans_entracte := 0.0
	var apres_fin := 0.0
	var image := 0
	var hold := 0.0
	var entracte_fait := false
	var fin_faite := false
	var limite := int(OS.get_environment("CD_STATS_IMAGES")) if OS.get_environment("CD_STATS_IMAGES").is_valid_int() else 30 * 3000
	while image < limite:
		await process_frame
		image += 1
		var delta := 1.0 / 30.0
		var live: Dictionary = app.model.get("live", {}) if app.model.get("live") is Dictionary else {}
		view = surface()
		var regie: Node = view.regie if view != null else null
		var talk: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		# Ce qu'un joueur ferait : passer les causeries, relancer après la mi-temps ou un arrêt.
		if app.waiting or not str(app.last_error).is_empty(): hold = 0.0
		elif talk is Dictionary:
			if app.contextual_director.kind != "locker": hold = 0.0
			else: hold += delta
			if hold >= 2.0:
				hold = 0.0
				app._command("match_talk_continue", {"key": talk.key, "phase": talk.phase, "skip": true})
		elif regie != null and live.get("paused", false) and not live.get("finished", false) and regie.etat != regie.JEU:
			hold += delta
			if hold >= 3.0:
				hold = 0.0
				app._command("pause", {"paused": false})
		else: hold = 0.0
		if regie == null: continue
		if not regie.arret.is_empty() and not app.waiting: regie.between.reprise_demandee.emit()
		if regie.etat == regie.INTER and precedent != regie.INTER: entractes += 1
		precedent = regie.etat
		if live.get("finished", false):
			apres_fin += delta
			if apres_fin >= 4.0 and not fin_faite:
				fin_faite = true
				if not png_fin.is_empty(): root.get_texture().get_image().save_png(png_fin)
				print("CAPTURE fin ", png_fin, " ", view.clock.text)
				break
		elif regie.etat == regie.INTER and entractes == voulu and not entracte_fait:
			dans_entracte += delta
			if dans_entracte >= 5.0 and regie.between.terrain.places.size() >= 28:
				entracte_fait = true
				if not png_entracte.is_empty(): root.get_texture().get_image().save_png(png_entracte)
				print("CAPTURE entracte ", png_entracte, " ", view.clock.text)
		else: dans_entracte = 0.0
	print("FIN ", JSON.stringify({"images": image, "entractes": entractes, "entracte_fait": entracte_fait, "fin_faite": fin_faite}))
	fin(0 if fin_faite and entracte_fait else 3)
