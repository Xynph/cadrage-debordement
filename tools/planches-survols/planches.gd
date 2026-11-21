extends SceneTree
## Planches A/B des survols (idées de Léo du 21/11/2026) : écusson → mini-carte club, chiffre → mini-courbe,
## compte à rebours du prochain match. Une variante par lancement (CD_VARIANTE_VISUELLE) ; le survol est simulé
## (vrai mouvement de souris poussé dans la fenêtre, puis attente du délai de la bulle).
## Variables : CD_PLANCHE_SORTIE (dossier des PNG), CD_PLANCHE_EXPORT (carrière exportée), CD_GODOT_DATA_DIR (profil
## jetable). Lancé par tools/planches-survols/planches.ps1 sous godot-slot.ps1 (bureau caché, son coupé).
const Bulle = preload("res://ui/bulle_survol.gd")
var app: Control
var sortie := OS.get_environment("CD_PLANCHE_SORTIE")
var variante := OS.get_environment("CD_VARIANTE_VISUELLE").to_upper()
var echecs: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PLANCHE ", "OK " if ok else "ECHEC ", message)
	if not ok: echecs.append(message)

func stabiliser() -> void:
	await create_timer(0.2).timeout
	for k in 8: await process_frame
	var limite := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < limite: await process_frame

func fermer_aide() -> void:
	var coach: Variant = app.get("coach")
	if not is_instance_valid(coach): return
	if coach.has_method("fermer_bulle"): coach.fermer_bulle()
	if coach.get("expanded") == true and coach.has_method("close"): coach.close()

func taille(t: Vector2i) -> void:
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = t
	DisplayServer.window_set_size(t)
	await create_timer(0.4).timeout
	await stabiliser()

func souris(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	root.push_input(m)

## Zone à agrandir sur la planche (ancre + bulle, avec une marge), écrite à côté de la capture.
var zone := Rect2()

func capture(nom: String) -> void:
	for k in 3: await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie.path_join(nom + ".png"))
	if zone.has_area():
		var z := zone.grow(40.0).intersection(Rect2(Vector2.ZERO, root.get_texture().get_size()))
		var f := FileAccess.open(sortie.path_join(nom + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"zone": [z.position.x, z.position.y, z.size.x, z.size.y]}))
		f.close()
	print("PLANCHE capture ", nom)

func survoler(cible: Control) -> Control:
	souris(Vector2(2, 2))
	await create_timer(0.1).timeout
	var debut := Time.get_ticks_msec()
	souris(cible.get_global_rect().get_center())
	var limite := debut + 4000
	while Bulle.actuelle(cible) == null and Time.get_ticks_msec() < limite:
		await process_frame
		souris(cible.get_global_rect().get_center())
	var ecoule := Time.get_ticks_msec() - debut
	var bulle := Bulle.actuelle(cible)
	check(bulle != null, "bulle apparue au survol (%d ms)" % ecoule)
	if bulle != null:
		check(ecoule >= int(Bulle.DELAI * 1000) - 20, "délai de %.2f s respecté" % Bulle.DELAI)
		check(app.get_viewport_rect().encloses(bulle.get_global_rect()), "bulle entière dans l'écran")
	zone = cible.get_global_rect().merge(bulle.get_global_rect()) if bulle != null else cible.get_global_rect()
	await create_timer(0.2).timeout
	return bulle

func lie(cle_debut: String, prefere: String = "") -> Control:
	var choisi: Control = null
	for n: Node in app.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.has_meta("bulle_survol") or not c.is_visible_in_tree(): continue
		var cle := str(c.get_meta("bulle_survol"))
		if not cle.begins_with(cle_debut): continue
		if not prefere.is_empty() and cle == prefere: return c
		if choisi == null: choisi = c
	return choisi

func run() -> void:
	var donnees := OS.get_environment("CD_GODOT_DATA_DIR")
	if donnees.is_empty() or sortie.is_empty():
		printerr("CD_GODOT_DATA_DIR et CD_PLANCHE_SORTIE obligatoires")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(sortie)
	var profil := donnees if donnees.replace("\\", "/").get_file() == "PrototypeGodot" else donnees.path_join("PrototypeGodot")
	DirAccess.make_dir_recursive_absolute(profil)
	var reglages := FileAccess.open(profil.path_join("interface.json"), FileAccess.WRITE)
	reglages.store_string(JSON.stringify({"version": 1, "volume": 0, "reduced_motion": false, "quality": "balanced", "camera": "tv"}))
	reglages.close()
	for bus in AudioServer.bus_count: AudioServer.set_bus_mute(bus, true)
	Engine.max_fps = 30
	app = load("res://main.tscn").instantiate()
	app.closing = true
	root.add_child(app)
	for s: Signal in [root.size_changed, root.focus_entered]:
		if s.is_connected(app._keep_filled_display): s.disconnect(app._keep_filled_display)
	await process_frame
	app.closing = false
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_PLANCHE_EXPORT"))})
	limite = Time.get_ticks_msec() + 180000
	while app.waiting and Time.get_ticks_msec() < limite: await process_frame
	if app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene") is Dictionary:
		await load("res://qa_runner.gd").settle_club_meetings(app, self, func(_ok: bool, _m: String): pass)
	app.timer.stop()
	var lettre := variante.right(1)
	var adversaire := str(load("res://ui/rebours_match.gd").prochain(app.model).get("adversaire", {}).get("id", ""))
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		await taille(t)
		var suffixe := "%s-%d" % [lettre, t.x]
		if variante.begins_with("ECUSSON"):
			app.management_ui.erase("competition_page")
			app._navigate("Classements")
			await stabiliser()
			fermer_aide()
			var e := lie("club:", "club:" + adversaire)
			check(e != null, "écusson lié dans le classement")
			if e != null:
				var bulle := await survoler(e)
				if bulle != null:
					check(bulle.find_child("CarteClubForme_0", true, false) != null, "forme en pastilles")
					check(bulle.find_child("CarteClubRang", true, false) != null or bulle.find_child("CarteClubTuile_0", true, false) != null, "rang affiché")
				await capture(suffixe)
				# Le clic garde son effet : fiche du club.
				var route: String = app.route
				souris(e.get_global_rect().get_center())
				var clic := InputEventMouseButton.new()
				clic.button_index = MOUSE_BUTTON_LEFT
				clic.position = e.get_global_rect().get_center()
				clic.global_position = clic.position
				clic.pressed = true
				root.push_input(clic)
				var lache: InputEventMouseButton = clic.duplicate()
				lache.pressed = false
				root.push_input(lache)
				await stabiliser()
				check(Bulle.actuelle(app) == null, "le clic range la bulle")
				check(app.route != route, "le clic ouvre la fiche du club (%s)" % app.route)
		elif variante.begins_with("COURBE"):
			app._navigate("Club")
			await stabiliser()
			fermer_aide()
			var e := lie("courbe:cash")
			check(e != null, "trésorerie liée sur l'écran Club")
			if e != null:
				await survoler(e)
				await capture(suffixe)
				var ev := InputEventKey.new()
				ev.keycode = KEY_ESCAPE
				ev.pressed = true
				root.push_input(ev)
				await stabiliser()
				check(Bulle.actuelle(app) == null, "Échap ferme la bulle")
		elif variante.begins_with("REBOURS"):
			app._navigate("Bureau")
			await stabiliser()
			fermer_aide()
			var b := app.find_child("ImmersiveMatchCountdown", true, false) as Button
			check(b != null, "compte à rebours dans la barre")
			if b != null:
				souris(b.get_global_rect().get_center())
				var date := app.find_child("ImmersiveCalendarDate", true, false) as Control
				zone = b.get_global_rect().merge(date.get_global_rect()) if date != null else b.get_global_rect()
				await stabiliser()
				await capture(suffixe)
				if t.x == 1920:
					b.pressed.emit()
					await stabiliser()
					check(app.route == "Match", "clic → avant-match (%s)" % app.route)
					await capture(suffixe + "-clic")
	print("PLANCHE_FIN ", variante, " echecs=", echecs.size())
	app.closing = true
	app.bridge.stop()
	for k in 10: await process_frame
	quit(0 if echecs.is_empty() else 3)
