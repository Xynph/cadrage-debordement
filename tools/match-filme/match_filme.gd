extends SceneTree
## Match filmé : regarder un match 3D du vrai jeu sans écran ni clic.
##
## Charge le vrai jeu (main.tscn) avec un profil temporaire, importe une carrière Monde arrêtée au
## coup d'envoi (tools/match-filme/preparer-carriere.cjs), passe les causeries comme le ferait un
## joueur, puis enregistre une image PNG toutes les N secondes jusqu'à la fin du match ou la durée
## maximale. Écrit report.json (luminance de chaque image pour repérer les images noires) et une
## planche-contact. Point d'entrée habituel : scripts/match-filme.ps1, qui lance Godot sur un
## bureau Windows séparé (invisible, sans prise du premier plan) avec le pilote audio muet.
##
##   godot --path native/godot --audio-driver Dummy --script tools/match-filme/match_filme.gd -- \
##     --match-filme --sortie <dossier> --export <carriere.json> [--camera tv|tactical|action] \
##     [--cadence 2] [--duree-max 600] [--minutes 0] [--niveau dynamique] [--taille 1280x720] [--sans-planche]
##
## CD_GODOT_DATA_DIR est obligatoire (profil jetable) : l'outil refuse de tourner sur le profil réel.
## Le jeu normal n'est pas touché : ce script n'est chargé qu'avec --script.

const CAMERAS := ["tv", "tactical", "action"]
const NIVEAUX := ["aucun", "resume", "cles", "etendus", "dynamique", "integral"]
## Luminance moyenne sous laquelle une image est comptée comme noire.
const SEUIL_NOIR := 0.03
const TAILLE_MIN := Vector2i(1280, 720)

var app: Control

func _initialize() -> void:
	call_deferred("run")

static func defauts() -> Dictionary:
	return {"sortie": "", "export": "", "camera": "tv", "cadence": 2.0, "duree_max": 600.0, "minutes": 0,
		"niveau": "dynamique", "taille": Vector2i(1280, 720), "planche": true}

## Lit les arguments placés après « -- ». Renvoie {"options": {...}, "erreurs": [...]}.
static func lire_options(args: PackedStringArray) -> Dictionary:
	var o := defauts()
	var erreurs: Array[String] = []
	var i := 0
	while i < args.size():
		var arg := args[i]
		var valeur := args[i + 1] if i + 1 < args.size() else ""
		i += 1
		if arg == "--match-filme": continue
		if arg == "--sans-planche":
			o.planche = false
			continue
		if not arg in ["--sortie", "--export", "--camera", "--cadence", "--duree-max", "--minutes", "--niveau", "--taille"]:
			erreurs.append("Argument inconnu : " + arg)
			continue
		i += 1
		if valeur.is_empty() or valeur.begins_with("--"):
			erreurs.append(arg + " attend une valeur.")
			i -= 1
			continue
		match arg:
			"--sortie": o.sortie = valeur
			"--export": o.export = valeur
			"--camera":
				if valeur in CAMERAS: o.camera = valeur
				else: erreurs.append("Caméra inconnue : " + valeur + " (tv, tactical ou action).")
			"--niveau":
				if valeur in NIVEAUX: o.niveau = valeur
				else: erreurs.append("Niveau de temps forts inconnu : " + valeur + ".")
			"--cadence":
				if valeur.is_valid_float() and float(valeur) >= 0.2: o.cadence = float(valeur)
				else: erreurs.append("--cadence : nombre de secondes, 0.2 au moins.")
			"--duree-max":
				if valeur.is_valid_float() and float(valeur) >= 10.0: o.duree_max = float(valeur)
				else: erreurs.append("--duree-max : nombre de secondes, 10 au moins.")
			"--minutes":
				if valeur.is_valid_int() and int(valeur) >= 0: o.minutes = int(valeur)
				else: erreurs.append("--minutes : minute de match entière (0 : match entier).")
			"--taille":
				var parts := valeur.to_lower().split("x")
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int() and int(parts[0]) >= TAILLE_MIN.x and int(parts[1]) >= TAILLE_MIN.y:
					o.taille = Vector2i(int(parts[0]), int(parts[1]))
				else: erreurs.append("--taille : LxH, %dx%d au moins." % [TAILLE_MIN.x, TAILLE_MIN.y])
	if not str(o.sortie).is_absolute_path(): erreurs.append("--sortie : dossier absolu requis.")
	if not str(o.export).is_absolute_path(): erreurs.append("--export : fichier absolu requis (carrière préparée).")
	return {"options": o, "erreurs": erreurs}

## Luminance moyenne (0 à 1) sur une grille de points : assez pour distinguer une image noire.
static func luminance(image: Image) -> float:
	if image == null or image.is_empty(): return 0.0
	var total := 0.0
	var n := 0
	var pas := Vector2i(maxi(1, image.get_width() / 48), maxi(1, image.get_height() / 27))
	for y in range(pas.y / 2, image.get_height(), pas.y):
		for x in range(pas.x / 2, image.get_width(), pas.x):
			total += image.get_pixel(x, y).get_luminance()
			n += 1
	return total / maxi(1, n)

## Indices répartis régulièrement pour garder au plus `maximum` images sur `total`.
static func repartir(total: int, maximum: int) -> Array[int]:
	var indices: Array[int] = []
	if total <= 0 or maximum <= 0: return indices
	if total <= maximum:
		for k in total: indices.append(k)
		return indices
	for k in maximum: indices.append(int(round(float(k) * (total - 1) / (maximum - 1))) if maximum > 1 else 0)
	return indices

## Planche-contact : vignettes en grille, de gauche à droite puis de haut en bas.
static func planche(images: Array, colonnes: int, largeur: int) -> Image:
	if images.is_empty(): return null
	var premiere: Image = images[0]
	var hauteur := int(round(float(largeur) * premiere.get_height() / maxi(1, premiere.get_width())))
	var marge := 6
	var lignes := int(ceil(float(images.size()) / colonnes))
	var colonnes_utiles := mini(colonnes, images.size())
	var feuille := Image.create_empty(marge + colonnes_utiles * (largeur + marge), marge + lignes * (hauteur + marge), false, Image.FORMAT_RGB8)
	feuille.fill(Color(0.08, 0.09, 0.1))
	for k in images.size():
		var vignette: Image = (images[k] as Image).duplicate()
		vignette.convert(Image.FORMAT_RGB8)
		vignette.resize(largeur, hauteur, Image.INTERPOLATE_BILINEAR)
		feuille.blit_rect(vignette, Rect2i(Vector2i.ZERO, vignette.get_size()), Vector2i(marge + (k % colonnes) * (largeur + marge), marge + (k / colonnes) * (hauteur + marge)))
	return feuille

func echouer(message: String, code := 2) -> void:
	printerr("MATCH_FILME erreur : " + message)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(code)

func surface() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "live" else null

func profil() -> String:
	var dossier := OS.get_environment("CD_GODOT_DATA_DIR")
	# Même normalisation que native/engine/worker.cjs.
	if dossier.replace("\\", "/").trim_suffix("/").get_file() != "PrototypeGodot": dossier = dossier.path_join("PrototypeGodot")
	return dossier

func couper_le_son() -> void:
	for bus in AudioServer.bus_count: AudioServer.set_bus_mute(bus, true)

func run() -> void:
	var lu := lire_options(OS.get_cmdline_user_args())
	if not lu.erreurs.is_empty():
		echouer("\n".join(lu.erreurs))
		return
	var o: Dictionary = lu.options
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty() or not OS.get_environment("CD_GODOT_DATA_DIR").is_absolute_path():
		echouer("CD_GODOT_DATA_DIR (profil jetable, chemin absolu) est obligatoire : aucune vraie carrière n'est utilisée.")
		return
	if DisplayServer.get_name() == "headless":
		echouer("--headless ne rend aucune image : lancer avec un affichage (scripts/match-filme.ps1 le fait sur un bureau séparé).")
		return
	if not FileAccess.file_exists(o.export):
		echouer("Carrière introuvable : " + str(o.export))
		return
	if DirAccess.make_dir_recursive_absolute(o.sortie) != OK:
		echouer("Dossier de sortie inaccessible : " + str(o.sortie))
		return
	couper_le_son()
	# Réglages du profil jetable : son à zéro, caméra et niveau de temps forts demandés.
	DirAccess.make_dir_recursive_absolute(profil())
	var reglages := FileAccess.open(profil().path_join("interface.json"), FileAccess.WRITE)
	reglages.store_string(JSON.stringify({"version": 1, "volume": 0, "reduced_motion": false, "quality": "balanced", "camera": o.camera, "match_highlights": o.niveau}, "  "))
	reglages.close()
	Engine.max_fps = 30
	app = load("res://main.tscn").instantiate()
	# Le jeu remet sa fenêtre en plein écran maximisé au démarrage : ici la fenêtre garde la taille
	# demandée (le retour différé lit `closing` et ne fait rien pendant la première image).
	app.closing = true
	root.add_child(app)
	for signal_fenetre: Signal in [root.size_changed, root.focus_entered]:
		if signal_fenetre.is_connected(app._keep_filled_display): signal_fenetre.disconnect(app._keep_filled_display)
	await process_frame
	app.closing = false
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = o.taille
	DisplayServer.window_set_size(o.taille)
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	couper_le_son()
	print("MATCH_FILME import")
	if not app._command("import", {"text": FileAccess.get_file_as_string(o.export)}):
		echouer("Import de la carrière refusé : " + str(app.last_error))
		return
	limite = Time.get_ticks_msec() + 180000
	while app.waiting and Time.get_ticks_msec() < limite: await process_frame
	# La carrière importée reprend avant le match (décision du 16/11/2026) : coup d'envoi comme le
	# bouton du jeu, puis la causerie est passée, comme le ferait un joueur, jusqu'à l'ouverture du direct.
	limite = Time.get_ticks_msec() + 180000
	var envois := 0
	var trace := 0
	while Time.get_ticks_msec() < limite and surface() == null:
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		var pret: bool = app.model.get("meta", {}).get("calendarCadence", {}).get("matchReady", false)
		if not app.waiting and causerie is Dictionary and app.contextual_director.kind == "locker":
			app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif not app.waiting and causerie == null and not app.model.get("live") is Dictionary and app.model.get("next") != null and pret and envois < 3:
			envois += 1
			print("MATCH_FILME coup d'envoi")
			app._command("begin_match", {})
		if Time.get_ticks_msec() > trace:
			trace = Time.get_ticks_msec() + 10000
			print("MATCH_FILME attente direct : route=", app.route, " ecran=", app.contextual_director.kind, " live=", app.model.get("live") is Dictionary, " causerie=", causerie is Dictionary, " erreur=", app.last_error)
		for k in 10: await process_frame
	if surface() == null:
		echouer("Le direct ne s'est pas ouvert : " + str(app.last_error))
		return
	couper_le_son()
	print("MATCH_FILME direct ouvert")
	var report := {"options": {"camera": o.camera, "cadence": o.cadence, "duree_max": o.duree_max, "minutes": o.minutes, "niveau": o.niveau, "taille": [o.taille.x, o.taille.y]},
		"pilote": RenderingServer.get_current_rendering_driver_name(), "carte": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(),
		"fenetre": {"taille": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y], "mode": DisplayServer.window_get_mode()},
		"images": [], "noires": 0}
	var debut := Time.get_ticks_msec()
	var precedent := debut
	var cadence: float = o.cadence
	var duree_max: float = o.duree_max
	var minutes: int = o.minutes
	var depuis_capture := cadence
	var attente := 0.0
	var fin := 0.0
	var dernier: Dictionary = {}
	var minute_vue := -1
	while true:
		await process_frame
		var maintenant := Time.get_ticks_msec()
		var delta := (maintenant - precedent) / 1000.0
		precedent = maintenant
		var live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
		var vue := surface()
		var regie: Node = vue.get("regie") if vue != null else null
		if not live.is_empty():
			dernier = {"score": live.get("score", [0, 0]).duplicate(), "minute": int(live.get("minute", 0)), "termine": bool(live.get("finished", false))}
			if dernier.minute != minute_vue:
				minute_vue = dernier.minute
				print("MATCH_FILME minute=", minute_vue, " score=", dernier.score)
		# Ce qu'un joueur ferait : passer la causerie de la mi-temps, relancer après un arrêt.
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if app.waiting or not str(app.last_error).is_empty(): attente = 0.0
		elif causerie is Dictionary:
			attente = attente + delta if app.contextual_director.kind == "locker" else 0.0
			if attente >= 2.0:
				attente = 0.0
				app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif live.get("paused", false) and not live.get("finished", false) and (regie == null or regie.etat != regie.JEU):
			attente += delta
			if attente >= 3.0:
				attente = 0.0
				app._command("pause", {"paused": false})
		else: attente = 0.0
		var termine: bool = live.is_empty() or bool(live.get("finished", false)) or (minutes > 0 and int(live.get("minute", 0)) >= minutes)
		if termine and (regie == null or regie.etat != regie.JEU): fin += delta
		if fin >= 3.0 or maintenant - debut > duree_max * 1000.0: break
		depuis_capture += delta
		if depuis_capture < cadence: continue
		depuis_capture = 0.0
		var image := root.get_texture().get_image()
		if image == null: continue
		var nom := "image-%04d.png" % (report.images.size() + 1)
		if image.save_png(str(o.sortie).path_join(nom)) != OK:
			echouer("Écriture impossible : " + nom)
			return
		var lum := snappedf(luminance(image), 0.001)
		if lum < SEUIL_NOIR: report.noires += 1
		var etat := "direct"
		if regie != null: etat = ["intermediaire", "temps_fort", "attente"][regie.etat] if regie.etat in [0, 1, 2] else str(regie.etat)
		if causerie is Dictionary: etat = "causerie"
		report.images.append({"fichier": nom, "secondes": snappedf((maintenant - debut) / 1000.0, 0.1), "minute": int(live.get("minute", dernier.get("minute", 0))),
			"score": live.get("score", dernier.get("score", [0, 0])), "etat": etat, "luminance": lum})
	report["duree_s"] = snappedf((Time.get_ticks_msec() - debut) / 1000.0, 0.1)
	report["score"] = dernier.get("score", [0, 0])
	report["minute"] = dernier.get("minute", 0)
	report["termine"] = dernier.get("termine", false)
	if o.planche and not report.images.is_empty():
		var choisies: Array = []
		for k in repartir(report.images.size(), 24): choisies.append(Image.load_from_file(str(o.sortie).path_join(report.images[k].fichier)))
		var feuille := planche(choisies, 4, 400)
		if feuille != null and feuille.save_png(str(o.sortie).path_join("planche.png")) == OK: report["planche"] = "planche.png"
	var fichier := FileAccess.open(str(o.sortie).path_join("report.json"), FileAccess.WRITE)
	fichier.store_string(JSON.stringify(report, "  "))
	fichier.close()
	print("MATCH_FILME_FIN ", JSON.stringify({"images": report.images.size(), "noires": report.noires, "score": report.score, "minute": report.minute, "termine": report.termine, "secondes": report.duree_s, "pilote": report.pilote, "audio": report.audio}))
	app.closing = true
	app.bridge.stop()
	for k in 10: await process_frame
	quit(0 if not report.images.is_empty() and report.noires < report.images.size() else 3)
