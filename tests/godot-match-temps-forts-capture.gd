extends SceneTree
## Capture d'un match en temps forts (CD_MATCH_TEMPS_FORTS=1) : la vraie interface, le
## vrai moteur, du coup d'envoi au coup de sifflet final. Outil manuel, lancé par
## tests/godot-match-temps-forts-capture.cjs (variables décrites dans ce fichier).
## Le script passe les causeries, relance le match à la mi-temps et après un arrêt sur
## carton, enregistre une image JPEG toutes les N images affichées et écrit report.json.

var app: Control
var proof := OS.get_environment("CD_MATCH_TEMPS_FORTS_PROOF")

func _initialize() -> void:
	call_deferred("run")

func number(name: String, fallback: int) -> int:
	var value := OS.get_environment(name)
	return int(value) if value.is_valid_int() and int(value) >= 0 else fallback

func surface() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "live" else null

func fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(2)

## Le jeu se remet de lui-même en fenêtre maximisée ; l'outil coupe ce retour, puis
## impose la taille demandée et attend qu'elle soit réellement appliquée.
func resize(size: Vector2i) -> Vector2i:
	for forced: Signal in [root.size_changed, root.focus_entered]:
		if forced.is_connected(app._keep_filled_display): forced.disconnect(app._keep_filled_display)
	for attempt in 4:
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var deadline := Time.get_ticks_msec() + 2500
		while DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED and Time.get_ticks_msec() < deadline: await process_frame
		root.size = size
		DisplayServer.window_set_size(size)
		deadline = Time.get_ticks_msec() + 2500
		while (root.size != size or root.content_scale_size != size) and Time.get_ticks_msec() < deadline: await process_frame
		for i in 12: await process_frame
		if root.size == size and DisplayServer.window_get_size() == size: break
	return DisplayServer.window_get_size()

func run() -> void:
	if proof.is_empty() or not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("CD_MATCH_TEMPS_FORTS_PROOF doit désigner un dossier absolu accessible.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles en --headless : lancer avec un affichage (Windows, X11 ou Xvfb).")
		quit(2)
		return
	var parts := OS.get_environment("CD_MATCH_TEMPS_FORTS_SIZE").split("x")
	var size := Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 and int(parts[0]) >= 640 and int(parts[1]) >= 360 else Vector2i(1280, 720)
	var every := maxi(1, number("CD_MATCH_TEMPS_FORTS_EVERY", 5))
	var maximum := maxi(1, number("CD_MATCH_TEMPS_FORTS_MAX", 2400))
	var last_minute := number("CD_MATCH_TEMPS_FORTS_MINUTES", 0)
	var quality := clampf(float(number("CD_MATCH_TEMPS_FORTS_QUALITE", 72)) / 100.0, 0.3, 0.95)
	Engine.max_fps = 30
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	var window_size := await resize(size)
	if not app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_MATCH_TEMPS_FORTS_SAVE"))}):
		fail("Import du match refusé.")
		return
	deadline = Time.get_ticks_msec() + 120000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	for i in 8: await process_frame
	var view := surface()
	if view == null or view.regie == null or not view.temps_forts_actifs():
		fail("Le direct en temps forts ne s'est pas ouvert : " + str(app.last_error))
		return
	var report := {"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"size": [size.x, size.y], "window": [window_size.x, window_size.y], "jpeg_quality": quality, "resized": false, "niveau": view.regie.niveau, "horloge": view.regie.horloge, "vitesse": view.regie.vitesse, "every": every,
		"gestes": view.stage.get("_gestes") != null, "images": [], "suivi": [], "tronque": false}
	var regies: Array = []
	var started := Time.get_ticks_msec()
	var frame := 0
	var hold := 0.0
	var ending := 0.0
	var previous := started
	var limit_ms := number("CD_MATCH_TEMPS_FORTS_LIMITE", 2400) * 1000
	var render_usec := 0
	var bytes := 0
	var largest := 0
	var image_size := Vector2i.ZERO
	var watched := ""
	var moved := started
	var stall_ms := maxi(30, number("CD_MATCH_TEMPS_FORTS_GEL", 120)) * 1000
	# Types de pistes voulus (chorégraphe) : seul le premier temps fort de chaque type est enregistré.
	var types_voulus := OS.get_environment("CD_MATCH_TEMPS_FORTS_TYPES").split(",", false)
	var types_vus := {}
	var cle_gardee := ""
	var type_garde := ""
	var queue := 0.0
	report["sequences"] = []
	while true:
		await process_frame
		frame += 1
		var now := Time.get_ticks_msec()
		var delta := (now - previous) / 1000.0
		previous = now
		var live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
		view = surface()
		var regie: Node = view.regie if view != null else null
		if regie != null and not regies.has(regie): regies.append(regie)
		var talk: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		var state := "causerie"
		if regie != null: state = ["intermediaire", "temps_fort", "attente"][regie.etat]
		if regie != null and not regie.arret.is_empty(): state = "arret"
		if live.is_empty(): state = "fin"
		# Ce qu'un joueur ferait : passer la causerie, relancer après la mi-temps ou un carton.
		if app.waiting or not str(app.last_error).is_empty(): hold = 0.0
		elif talk is Dictionary:
			# La causerie n'est passée qu'une fois ouverte : un temps fort en cours la retient.
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
		# Garde-fou : si plus rien n'avance, le rapport dit où le direct s'est figé au lieu d'attendre sans fin.
		var signature := "%s|%s|%d|%d|%s" % [state, str(live.get("minute", "")), regie.index if regie != null else -1, int(live.get("events", []).size()), str(live.get("paused", false))]
		if signature != watched:
			watched = signature
			moved = now
		elif now - moved > stall_ms and not live.get("finished", false):
			var gestes: Variant = view.stage.get("_gestes") if view != null else null
			report["fige"] = {"etat": state, "minute": live.get("minute", 0), "plan": regie.index if regie != null else -1, "phase": regie.phase if regie != null else "",
				"moteur_en_attente": bool(app.waiting), "derniere_commande": str(app.last_command), "erreur": str(app.last_error), "pause": live.get("paused", false),
				"demande": regie.get("_demande") if regie != null else null, "arret": not regie.arret.is_empty() if regie != null else false,
				"geste": str(gestes.phase) if gestes != null else "", "geste_tient": view.stage.is_presenting_extended_pass() if view != null else false,
				"geste_temps": float(gestes.time) if gestes != null else 0.0, "secondes_sans_progres": (now - moved) / 1000.0}
			push_error("Direct figé : " + JSON.stringify(report.fige))
			break
		var garder := true
		if not types_voulus.is_empty():
			garder = false
			if regie != null and regie.etat == regie.JEU and regie.tf.get("choregraphie") is Dictionary:
				var genre := str(regie.tf.choregraphie.get("type", ""))
				var cle := str(regie.tf.get("cle", ""))
				if cle == cle_gardee or (genre in types_voulus and not types_vus.has(genre)):
					if cle != cle_gardee:
						cle_gardee = cle
						type_garde = genre
						types_vus[genre] = true
						report.sequences.append({"type": genre, "horloge": str(regie.tf.get("horlogeDebut", "")), "premiere": report.images.size() + 1})
					garder = true
					queue = 1.0
			if not garder and queue > 0.0:
				# Une seconde de plus après le temps fort gardé (score, journal).
				queue -= 1.0 / 30.0
				garder = true
			if garder and not report.sequences.is_empty(): report.sequences[-1]["derniere"] = report.images.size()
			if regie != null: regie.vitesse = 1.0 if garder else 6.0
		var over: bool = live.is_empty() or live.get("finished", false) or (last_minute > 0 and int(live.get("minute", 0)) >= last_minute)
		if not types_voulus.is_empty() and types_vus.size() >= types_voulus.size() and queue <= 0.0: over = true
		if over and (regie == null or regie.etat != regie.JEU): ending += delta
		if ending >= 3.0 or now - started > limit_ms: break
		if frame % every != 0 or not garder: continue
		if report.images.size() >= maximum:
			report.tronque = true
			continue
		var before := Time.get_ticks_usec()
		# Dernière image affichée : aucune attente du rendu, qui ne doit jamais bloquer la boucle.
		var image := root.get_texture().get_image()
		var name := "tf-%05d.jpg" % (report.images.size() + 1)
		if image != null and image.get_size() != size:
			# La fenêtre n'a pas pu prendre la taille demandée : l'image est ramenée à cette taille.
			report.resized = true
			image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		if image == null or image.save_jpg(proof.path_join(name), quality) != OK:
			fail("Écriture impossible : " + name)
			return
		image_size = image.get_size()
		var written := FileAccess.get_file_as_bytes(proof.path_join(name)).size()
		bytes += written
		largest = maxi(largest, written)
		render_usec += Time.get_ticks_usec() - before
		report.images.append({"file": name, "ms": now - started, "etat": state, "horloge": view.clock.text if view != null else "", "score": view.score.text if view != null else "", "type": type_garde})
	for played: Node in regies:
		if is_instance_valid(played): report.suivi.append_array(played.suivi)
	var final_live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
	report["score"] = final_live.get("score", [0, 0])
	report["termine"] = final_live.get("finished", false)
	report["minute"] = final_live.get("minute", 0)
	report["temps_forts"] = report.suivi.filter(func(entry: Dictionary): return entry.evenement == "temps_fort" and not entry.get("suite", false)).size()
	report["secondes_en_temps_fort"] = snappedf(report.suivi.reduce(func(total: float, entry: Dictionary): return total + float(entry.get("duree_reelle", 0.0)), 0.0), 0.1)
	report["duree_s"] = snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1)
	report["images_par_seconde"] = snappedf(report.images.size() / maxf(0.001, report.duree_s), 0.01)
	report["rendu_ms_par_image"] = snappedf(render_usec / 1000.0 / maxi(1, report.images.size()), 0.1)
	report["image_size"] = [image_size.x, image_size.y]
	report["octets_par_image"] = bytes / maxi(1, report.images.size())
	report["octets_image_la_plus_lourde"] = largest
	report["echeances"] = report.suivi.filter(func(entry: Dictionary): return entry.evenement == "echeance").size()
	var file := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("MATCH_TEMPS_FORTS_CAPTURE ", JSON.stringify({"images": report.images.size(), "taille": report.image_size, "octets_par_image": report.octets_par_image, "secondes": report.duree_s, "temps_forts": report.temps_forts, "driver": report.driver, "fige": report.has("fige")}))
	app.closing = true
	app.bridge.stop()
	quit(3 if report.has("fige") else 0)
