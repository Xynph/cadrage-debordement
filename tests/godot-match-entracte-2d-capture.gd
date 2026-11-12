extends SceneTree
## Film de contrôle de l'entracte 2D (outil manuel, lancé par tests/godot-match-entracte-2d-capture.cjs).
## La vraie interface et le vrai moteur, à vitesse réelle : coup d'envoi en 3D, puis les
## entractes demandés (terrain 2D et tableau de bord), et le début du temps fort suivant.
## À lancer avec --write-movie et --fixed-fps 30 : chaque image du film vaut 1/30 s de jeu.
## Variables : CD_ENTRACTE_2D_SAVE (match exporté), CD_ENTRACTE_2D_PNG (capture PNG au milieu du
## premier entracte complet), CD_ENTRACTE_2D_NOMBRE (entractes à filmer, 2 par défaut).

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
	root.size = size
	if not app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_ENTRACTE_2D_SAVE"))}):
		push_error("Import refusé")
		fin(2)
		return
	while app.waiting: await process_frame
	for i in 8: await process_frame
	var view := surface()
	if view == null or view.regie == null:
		push_error("Direct en temps forts absent : " + str(app.last_error))
		fin(2)
		return
	var regie: Node = view.regie
	var voulu := maxi(1, int(OS.get_environment("CD_ENTRACTE_2D_NOMBRE")) if OS.get_environment("CD_ENTRACTE_2D_NOMBRE").is_valid_int() else 2)
	var png := OS.get_environment("CD_ENTRACTE_2D_PNG")
	var entractes := 0
	var precedent: int = regie.etat
	var dans_entracte := 0.0
	var apres := 0.0
	var image := 0
	var capture_faite := false
	while image < 30 * 600:
		await process_frame
		image += 1
		var live: Dictionary = app.model.get("live", {}) if app.model.get("live") is Dictionary else {}
		# Le match importé est en pause : on le relance une fois le coup d'envoi joué.
		if regie.etat != regie.JEU and live.get("paused", false) and not app.waiting and not live.get("finished", false) and regie.arret.is_empty():
			app._command("pause", {"paused": false})
		if not regie.arret.is_empty() and not app.waiting: regie.between.reprise_demandee.emit()
		if regie.etat == regie.INTER and precedent != regie.INTER: entractes += 1
		precedent = regie.etat
		if regie.etat == regie.INTER and entractes >= 1:
			dans_entracte += 1.0 / 30.0
			# Capture au milieu du premier entracte : le terrain joue, le tableau est rempli.
			if not capture_faite and not png.is_empty() and dans_entracte >= 5.0 and regie.between.terrain.places.size() >= 28:
				capture_faite = true
				var shot := root.get_texture().get_image()
				shot.save_png(png)
				print("CAPTURE ", png, " ", view.clock.text)
		else: dans_entracte = 0.0
		if entractes > voulu or (entractes == voulu and regie.etat == regie.JEU): apres += 1.0 / 30.0
		if apres >= 4.0 or live.get("finished", false): break
	print("FILM ", JSON.stringify({"images": image, "entractes": entractes, "faits": regie.between.terrain.suivi.filter(func(e: Dictionary): return e.evenement == "fait").size()}))
	fin(0)
