extends SceneTree
## Film de contrôle de l'entracte 2D (outil manuel, lancé par tests/godot-match-entracte-2d-capture.cjs).
## La vraie interface et le vrai moteur, à vitesse réelle : coup d'envoi en 3D, puis les
## entractes demandés (terrain 2D et tableau de bord), et le début du temps fort suivant.
## À lancer avec --write-movie et --fixed-fps 30 : chaque image du film vaut 1/30 s de jeu.
## Variables : CD_ENTRACTE_2D_SAVE (match exporté), CD_ENTRACTE_2D_PNG (capture PNG à 5 s du
## dernier entracte filmé), CD_ENTRACTE_2D_NOMBRE (entractes à filmer, 2 par défaut),
## CD_ENTRACTE_2D_VUES (mises en page à enchaîner, ex. « staff,mix,tele » : une toutes les
## 4 s d'entracte ; « %s » dans CD_ENTRACTE_2D_PNG donne une capture par mise en page).

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
	# Le projet s'ouvre en plein écran 1440×900 : fenêtre 1280×720 imposée, sinon le film
	# (--write-movie, taille de la fenêtre) est rogné.
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	for i in 6: await process_frame
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
	var capture_faite := 0
	# Images du film : la vue racine elle-même (1280×720 exactes), une par image de jeu.
	var images_dossier := OS.get_environment("CD_ENTRACTE_2D_IMAGES")
	var vues: PackedStringArray = OS.get_environment("CD_ENTRACTE_2D_VUES").split(",", false)
	var temps_vues := 0.0
	var vue_depuis := 0.0
	var captures_vues := {}
	if not vues.is_empty(): regie.between.choisir_disposition(vues[0])
	while image < 30 * 600:
		await process_frame
		image += 1
		if not images_dossier.is_empty(): root.get_texture().get_image().save_jpg(images_dossier.path_join("%05d.jpg" % image), 0.92)
		var live: Dictionary = app.model.get("live", {}) if app.model.get("live") is Dictionary else {}
		# Le match importé est en pause : on le relance une fois le coup d'envoi joué.
		if regie.etat != regie.JEU and live.get("paused", false) and not app.waiting and not live.get("finished", false) and regie.arret.is_empty():
			app._command("pause", {"paused": false})
		if not regie.arret.is_empty() and not app.waiting: regie.between.reprise_demandee.emit()
		if regie.etat == regie.INTER and precedent != regie.INTER: entractes += 1
		precedent = regie.etat
		if regie.etat == regie.INTER and entractes >= 1:
			dans_entracte += 1.0 / 30.0
			# Capture à 5 s de chaque entracte (la dernière l'emporte) : le terrain joue, le tableau
			# est rempli de plus de minutes de jeu.
			if not vues.is_empty():
				temps_vues += 1.0 / 30.0
				vue_depuis += 1.0 / 30.0
				var vue := vues[int(temps_vues / 4.0) % vues.size()]
				if vue != regie.between.disposition:
					regie.between.choisir_disposition(vue)
					vue_depuis = 0.0
				# Une capture par mise en page, dans le dernier entracte filmé (la dernière l'emporte).
				if "%s" in png and entractes >= maxi(1, voulu - 3) and vue_depuis >= 2.5 and captures_vues.get(vue, 0) != entractes and regie.between.terrain.places.size() >= 28:
					captures_vues[vue] = entractes
					root.get_texture().get_image().save_png(png % vue)
					print("CAPTURE ", png % vue, " ", view.clock.text)
			if not "%s" in png and capture_faite != entractes and not png.is_empty() and dans_entracte >= 5.0 and regie.between.terrain.places.size() >= 28:
				capture_faite = entractes
				var shot := root.get_texture().get_image()
				shot.save_png(png)
				print("CAPTURE ", png, " ", view.clock.text)
		else: dans_entracte = 0.0
		if entractes > voulu or (entractes == voulu and regie.etat == regie.JEU): apres += 1.0 / 30.0
		if apres >= 4.0 or live.get("finished", false): break
	print("FILM ", JSON.stringify({"images": image, "entractes": entractes, "faits": regie.between.terrain.suivi.filter(func(e: Dictionary): return e.evenement == "fait").size()}))
	fin(0)
