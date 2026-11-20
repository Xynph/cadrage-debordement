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
##     [--cadence 2] [--cadence-moments 0.5] [--duree-max 600] [--minutes 0] [--niveau dynamique] [--taille 1280x720] \
##     [--attente libre|figee] [--sans-planche]
##   (ajouter --fixed-fps 30 --disable-vsync avant --script pour calculer le film au plus vite)
##
## Film calculé au plus vite (19/11/2026) : l'horloge du film est le temps de jeu simulé (somme des
## deltas de process), pas l'horloge murale. Lancé avec `--fixed-fps 30 --disable-vsync`, Godot avance
## chaque image de 1/30 s de jeu quelle que soit sa durée réelle : le rendu est le même image par
## image, l'outil lève alors la limite d'images par seconde (Engine.max_fps = 0) et le film se
## calcule aussi vite que le PC le permet. Sans --fixed-fps, 30 images/s en temps réel comme avant.
## Cadence, attentes des causeries et des arrêts, fin, --duree-max et les « secondes » du rapport
## sont en temps simulé ; les horodatages muraux de la régie (légendes, ralentis) sont convertis par
## les échantillons (mur, simulé) relevés à chaque image. Pendant que le moteur Node calcule une
## réponse, --attente reelle (défaut) fait durer l'attente en temps de jeu ce qu'elle dure vraiment,
## comme en jeu (Engine.time_scale = durée murale de l'image / pas) ; figee la gèle (time_scale = 0) ;
## libre n'y touche pas (à pas fixe, l'attente dure alors plus longtemps qu'en jeu).
## Les attentes de préparation avant le direct (120 s, 180 s) restent en temps réel (garde-fous).
##
## Grands moments (18/11/2026) : autour d'un essai (plan d'essai, bandeau « ESSAI », ralenti) et
## pendant la sortie des joueurs de la mi-temps et de la fin de match (plan large, marche vers le
## tunnel), une image toutes les --cadence-moments secondes ; la mi-temps n'est passée qu'une fois la
## causerie ouverte, la fin attend la fin de la sortie. report.json liste ces moments (« moments »,
## avec la première image de chacun) et marque chaque image (« moment »).
##
## CD_GODOT_DATA_DIR est obligatoire (profil jetable) : l'outil refuse de tourner sur le profil réel.
## Le jeu normal n'est pas touché : ce script n'est chargé qu'avec --script.

const CAMERAS := ["tv", "tactical", "action"]
const NIVEAUX := ["aucun", "resume", "cles", "etendus", "dynamique", "integral"]
## Luminance moyenne sous laquelle une image est comptée comme noire.
const SEUIL_NOIR := 0.03
const TAILLE_MIN := Vector2i(1280, 720)
const ATTENTES := ["reelle", "figee", "libre"]

var app: Control

func _initialize() -> void:
	call_deferred("run")

static func defauts() -> Dictionary:
	return {"sortie": "", "export": "", "camera": "tv", "cadence": 2.0, "cadence_moments": 0.5, "duree_max": 600.0, "minutes": 0,
		"niveau": "dynamique", "taille": Vector2i(1280, 720), "planche": true, "attente": "reelle"}

## Vitesse du temps de jeu (Engine.time_scale) pour l'image suivante. Hors attente du moteur : 1.
## Pendant l'attente : « figee » 0 ; « reelle » la durée murale de la dernière image rapportée au pas
## fixe (l'attente dure en jeu ce qu'elle dure vraiment, bornée à 1) ; « libre » ou sans pas fixe : 1.
static func echelle_attente(mode: String, attend: bool, image_ms: float, pas: int) -> float:
	if not attend or mode == "libre": return 1.0
	if mode == "figee": return 0.0
	if pas <= 0: return 1.0
	return clampf(image_ms / 1000.0 * pas, 0.0, 1.0)

## Pas fixe de Godot lu dans ses arguments (`--fixed-fps N`, OS.get_cmdline_args) : N images par
## seconde de jeu, 0 si absent ou invalide (le jeu suit alors l'horloge murale).
static func pas_fixe(args: PackedStringArray) -> int:
	var i := args.find("--fixed-fps")
	if i < 0 or i + 1 >= args.size(): return 0
	var valeur := args[i + 1]
	return int(valeur) if valeur.is_valid_int() and int(valeur) > 0 else 0

## Instant mural (Time.get_ticks_msec) converti en secondes de jeu simulées. `echantillons` vaut
## [PackedInt64Array des ms murales croissantes, PackedFloat64Array des secondes simulées] : un couple
## par image du direct. Interpolation linéaire entre les deux échantillons qui encadrent `ms`
## (recherche dichotomique), saturée au premier et au dernier ; 0.0 sans échantillon.
static func vers_simule(echantillons: Array, ms: int) -> float:
	if echantillons.size() < 2 or not echantillons[0] is PackedInt64Array or not echantillons[1] is PackedFloat64Array: return 0.0
	var murs: PackedInt64Array = echantillons[0]
	var simules: PackedFloat64Array = echantillons[1]
	var n := mini(murs.size(), simules.size())
	if n == 0: return 0.0
	if ms <= murs[0]: return simules[0]
	if ms >= murs[n - 1]: return simules[n - 1]
	var bas := 0
	var haut := n - 1
	while haut - bas > 1:
		var milieu := (bas + haut) / 2
		if murs[milieu] <= ms: bas = milieu
		else: haut = milieu
	var ecart := murs[haut] - murs[bas]
	if ecart <= 0: return simules[haut]
	return simules[bas] + (simules[haut] - simules[bas]) * float(ms - murs[bas]) / float(ecart)

## États de la régie des temps forts, dans l'ordre de son enum (match_temps_forts.gd).
const ETATS := ["intermediaire", "temps_fort", "attente", "sortie"]

## Grand moment montré par la régie à cet instant : « essai » (plan d'essai en cours ou bandeau
## « ESSAI »), « mi-temps » ou « fin » (sortie des joueurs), sinon vide.
static func moment_de(regie: Node) -> String:
	if regie == null: return ""
	if regie.has_method("sortie_en_cours") and regie.sortie_en_cours():
		return "fin" if bool(regie.get("_live").get("finished", false)) else "mi-temps"
	if regie.has_method("bandeau_affiche"):
		var bandeau: Dictionary = regie.bandeau_affiche()
		if bandeau.get("visible", false) and str(bandeau.get("titre", "")) == "ESSAI": return "essai"
	var tf: Dictionary = regie.get("tf") if regie.get("tf") is Dictionary else {}
	var index: int = int(regie.get("index"))
	if int(regie.get("etat")) == 1 and index >= 0 and index < (tf.get("plans", []) as Array).size() and str(tf.plans[index].get("kind", "")) == "try": return "essai"
	return ""

## Ralenti de l'essai à l'image (19/11/2026) : {"ralenti": la vue rejoue l'essai au ralenti sous la
## caméra basse, "mention": la mention « RALENTI » est affichée}. Les deux vont ensemble.
static func ralenti_de(regie: Node) -> Dictionary:
	if regie == null: return {"ralenti": false, "mention": false}
	return {"ralenti": regie.has_method("rejeu_en_cours") and bool(regie.rejeu_en_cours()),
		"mention": regie.has_method("mention_affichee") and bool(regie.mention_affichee())}

## Foule à l'image (le film tourne sans son) : intensité d'ambiance (0 à 1), part du public debout
## (%), sons décidés depuis l'image précédente (audio/soundscape.gd, etat_foule). {} sans gestionnaire.
static func foule_de(jeu: Node) -> Dictionary:
	var sons: Variant = jeu.get("soundscape") if jeu != null else null
	if not is_instance_valid(sons) or not sons.has_method("etat_foule"): return {}
	var etat: Dictionary = sons.etat_foule()
	return {"intensite": etat.get("intensite", 0.0), "debout": etat.get("debout", 0.0), "sons": etat.get("sons", [])}

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
		# Pas fixe r�p�t� apr�s � -- � (Godot ne le laisse pas dans ses propres arguments) : lu par pas_fixe.
		if arg == "--fixed-fps":
			i += 1
			continue
		if arg == "--sans-planche":
			o.planche = false
			continue
		if not arg in ["--sortie", "--export", "--camera", "--cadence", "--cadence-moments", "--duree-max", "--minutes", "--niveau", "--taille", "--attente"]:
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
			"--attente":
				if valeur in ATTENTES: o.attente = valeur
				else: erreurs.append("--attente inconnue : " + valeur + " (reelle, figee ou libre).")
			"--cadence":
				if valeur.is_valid_float() and float(valeur) >= 0.2: o.cadence = float(valeur)
				else: erreurs.append("--cadence : nombre de secondes, 0.2 au moins.")
			"--cadence-moments":
				if valeur.is_valid_float() and float(valeur) >= 0.2: o.cadence_moments = float(valeur)
				else: erreurs.append("--cadence-moments : nombre de secondes, 0.2 au moins.")
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
	Engine.time_scale = 1.0
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
	# À pas fixe, chaque image vaut 1/N s de jeu quelle que soit sa durée réelle : aucune limite.
	var pas: int = maxi(pas_fixe(OS.get_cmdline_args()), pas_fixe(OS.get_cmdline_user_args()))
	Engine.max_fps = 0 if pas > 0 else 30
	print("MATCH_FILME pas_fixe=", pas, " attente=", o.attente)
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
	var report := {"options": {"camera": o.camera, "cadence": o.cadence, "cadence_moments": o.cadence_moments, "duree_max": o.duree_max, "minutes": o.minutes, "niveau": o.niveau, "taille": [o.taille.x, o.taille.y], "attente": o.attente},
		"pilote": RenderingServer.get_current_rendering_driver_name(), "carte": RenderingServer.get_video_adapter_name(), "audio": AudioServer.get_driver_name(),
		"fenetre": {"taille": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y], "mode": DisplayServer.window_get_mode()},
		"images": [], "noires": 0, "moments": []}
	var cadence_moments: float = minf(o.cadence_moments, o.cadence)
	var moment_vu := ""
	var regie_vue: Node = null
	var debut := Time.get_ticks_msec()
	# Horloge du film : secondes de jeu simulées depuis l'ouverture du direct (somme des deltas de process).
	var temps := 0.0
	var images_rendues := 0
	# Échantillons (ms murale, secondes simulées), un par image : conversion des horodatages de la régie.
	var murs := PackedInt64Array([debut])
	var simules := PackedFloat64Array([0.0])
	var cadence: float = o.cadence
	var duree_max: float = o.duree_max
	var minutes: int = o.minutes
	var depuis_capture := cadence
	var attente := 0.0
	var fin := 0.0
	var dernier: Dictionary = {}
	var minute_vue := -1
	# Texte / image : chaque légende du temps fort, affichée à t= ; sa phase rendue à t= (suivi de la régie).
	var legendes: Array = []
	# Ralentis d'essai rejoués (suivi de la régie) : un par essai, sauf animations réduites.
	var ralentis: Array = []
	var regie_id := 0
	var suivi_lu := 0
	# Écran 13 (20/11/2026) : vues du HUD à capturer en plus du film, à un instant de jeu simulé (secondes) :
	# CD_MATCH_FILME_MENU_ECHAP (menu du match ouvert par Échap) et CD_MATCH_FILME_FICHE_CLUB (fiche du club
	# visiteur ouverte depuis sa plaque). Image « menu-echap.png » / « fiche-club.png », puis retour au direct.
	var vues_hud: Array = []
	for paire: Array in [["menu-echap", "CD_MATCH_FILME_MENU_ECHAP"], ["fiche-club", "CD_MATCH_FILME_FICHE_CLUB"]]:
		var a := OS.get_environment(str(paire[1]))
		if a.is_valid_float(): vues_hud.append({"nom": paire[0], "a": float(a), "etape": 0, "depuis": 0.0})
	while true:
		await process_frame
		var maintenant := Time.get_ticks_msec()
		# Delta de l'image qui vient d'être traitée (pas fixe et Engine.time_scale compris).
		var delta: float = root.get_process_delta_time()
		temps += delta
		images_rendues += 1
		murs.append(maintenant)
		simules.append(temps)
		# Attente du moteur Node : en temps de jeu, sa durée réelle (reelle), rien (figee) ou un pas entier par image (libre).
		Engine.time_scale = echelle_attente(o.attente, app.waiting, float(maintenant - murs[murs.size() - 2]), pas)
		var live: Dictionary = app.model.live if app.model.get("live") is Dictionary else {}
		var vue := surface()
		var regie: Node = vue.get("regie") if vue != null else null
		if regie != null and regie.get("suivi") is Array:
			if regie.get_instance_id() != regie_id:
				regie_id = regie.get_instance_id()
				suivi_lu = 0
			var suivi: Array = regie.suivi
			while suivi_lu < suivi.size():
				var e: Dictionary = suivi[suivi_lu]
				suivi_lu += 1
				# Ralenti de l'essai : l'entrée du suivi est complétée à sa fin (durée, abrégé, état remis).
				if str(e.get("evenement", "")) in ["rejeu", "rejeu_refuse"]:
					ralentis.append(e)
					continue
				if str(e.get("evenement", "")) != "legende": continue
				# Horodatages muraux de la régie : convertis en temps simulé à la fin du direct.
				legendes.append(e)
		if not live.is_empty():
			dernier = {"score": live.get("score", [0, 0]).duplicate(), "minute": int(live.get("minute", 0)), "termine": bool(live.get("finished", false))}
			if dernier.minute != minute_vue:
				minute_vue = dernier.minute
				print("MATCH_FILME minute=", minute_vue, " score=", dernier.score)
		# Vues du HUD demandées (menu Échap, fiche club) : ouverture, une seconde de jeu, image, retour au direct.
		var vue_hud_en_cours := false
		for v: Dictionary in vues_hud:
			if int(v.etape) >= 2 or vue == null or live.is_empty() or bool(live.get("finished", false)): continue
			if int(v.etape) == 0 and temps >= float(v.a) and not app.waiting and (regie == null or regie.etat != 3):
				if v.nom == "menu-echap": vue.ouvrir_menu()
				else: vue.ouvrir_fiche_club(1)
				v.etape = 1
				v.depuis = temps
			if int(v.etape) == 1:
				vue_hud_en_cours = true
				if temps - float(v.depuis) >= (1.0 if v.nom == "menu-echap" else 3.0) and not app.waiting:
					await RenderingServer.frame_post_draw
					var vue_image := root.get_texture().get_image()
					if vue_image != null: vue_image.save_png(str(o.sortie).path_join(str(v.nom) + ".png"))
					report[str(v.nom)] = {"secondes": snappedf(temps, 0.1), "minute": int(live.get("minute", 0))}
					print("MATCH_FILME vue ", v.nom, " minute=", int(live.get("minute", 0)))
					if v.nom == "menu-echap": vue.fermer_menu(true)
					else: vue.fermer_page()
					v.etape = 2
		# Ce qu'un joueur ferait : passer la causerie de la mi-temps, relancer après un arrêt.
		var causerie: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if vue_hud_en_cours or app.waiting or not str(app.last_error).is_empty(): attente = 0.0
		elif causerie is Dictionary:
			attente = attente + delta if app.contextual_director.kind == "locker" else 0.0
			if attente >= 2.0:
				attente = 0.0
				app._command("match_talk_continue", {"key": causerie.key, "phase": causerie.phase, "skip": true})
		elif live.get("paused", false) and not live.get("finished", false) and (regie == null or regie.etat != regie.JEU):
			attente += delta
			# Arrêt sur incident (blessure, saignement, choc, première ligne) : comme un joueur, choisir un
			# autre joueur que celui proposé par le staff, une fois, avant de reprendre.
			if attente >= 1.5 and regie != null:
				var options: Node = regie.between.find_child("MatchBetweenStopOptions", true, false) if regie.get("between") != null else null
				if options != null and options.is_visible_in_tree() and options.get_child_count() >= 2:
					var bouton: Variant = options.get_child(1)
					if bouton is Button and not bouton.disabled and not report.has("choix_incident"):
						report["choix_incident"] = {"minute": int(live.get("minute", 0)), "option": bouton.text, "image": report.images.size() + 1}
						print("MATCH_FILME choix_incident=", bouton.text)
						bouton.pressed.emit()
			if attente >= 3.0:
				attente = 0.0
				app._command("pause", {"paused": false})
		else: attente = 0.0
		# Grand moment en cours (essai, sortie des joueurs) : images rapprochées, notées dans le rapport.
		if regie != regie_vue:
			regie_vue = regie
			moment_vu = ""
		var moment := moment_de(regie)
		if moment != moment_vu:
			if not moment.is_empty():
				var detail: Dictionary = regie.bandeau_affiche() if regie.has_method("bandeau_affiche") else {}
				report.moments.append({"moment": moment, "secondes": snappedf(temps, 0.1), "minute": int(live.get("minute", dernier.get("minute", 0))),
					"premiere_image": "image-%04d.png" % (report.images.size() + 1), "bandeau": detail})
				print("MATCH_FILME moment=", moment, " minute=", int(live.get("minute", 0)), " image=", report.images.size() + 1)
				# Première image du moment prise tout de suite.
				depuis_capture = cadence
			moment_vu = moment
		var en_sortie: bool = regie != null and regie.has_method("sortie_en_cours") and regie.sortie_en_cours()
		var termine: bool = live.is_empty() or bool(live.get("finished", false)) or (minutes > 0 and int(live.get("minute", 0)) >= minutes)
		# La fin de match se filme jusqu'au bout de la sortie des joueurs.
		if termine and (regie == null or (regie.etat != regie.JEU and not en_sortie)): fin += delta
		if fin >= 3.0 or temps > duree_max: break
		depuis_capture += delta
		if depuis_capture < (cadence_moments if not moment.is_empty() else cadence): continue
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
		if regie != null: etat = ETATS[regie.etat] if regie.etat >= 0 and regie.etat < ETATS.size() else str(regie.etat)
		# La causerie n'est à l'écran qu'une fois ouverte (pendant la sortie, elle attend).
		if causerie is Dictionary and app.contextual_director.kind == "locker": etat = "causerie"
		# Ralenti de l'essai à l'image (vue au ralenti, caméra basse) et mention « RALENTI » affichée :
		# les deux doivent aller ensemble.
		var ralenti_vu: Dictionary = ralenti_de(regie)
		report.images.append({"fichier": nom, "secondes": snappedf(temps, 0.1), "minute": int(live.get("minute", dernier.get("minute", 0))),
			"score": live.get("score", dernier.get("score", [0, 0])), "etat": etat, "moment": moment, "ralenti": ralenti_vu.ralenti, "mention_ralenti": ralenti_vu.mention,
			"luminance": lum, "foule": foule_de(app)})
	Engine.time_scale = 1.0
	var duree_murale := (Time.get_ticks_msec() - debut) / 1000.0
	# duree_s : temps de jeu simulé ; duree_reelle_s : horloge murale du direct.
	report["duree_s"] = snappedf(temps, 0.1)
	report["duree_reelle_s"] = snappedf(duree_murale, 0.1)
	report["pas_fixe"] = pas
	report["attente"] = o.attente
	report["images_rendues"] = images_rendues
	report["images_par_seconde_reelles"] = snappedf(images_rendues / maxf(duree_murale, 0.001), 0.1)
	report["score"] = dernier.get("score", [0, 0])
	report["minute"] = dernier.get("minute", 0)
	report["termine"] = dernier.get("termine", false)
	var echantillons: Array = [murs, simules]
	report["legendes"] = legendes.map(func(e: Dictionary) -> Dictionary:
		var texte_s := vers_simule(echantillons, int(e.texte_ms))
		var image_s := vers_simule(echantillons, int(e.image_ms))
		return {"texte": e.texte, "kind": e.kind, "phase": e.phase, "horloge": e.horloge,
			"texte_s": snappedf(texte_s, 0.01), "image_s": snappedf(image_s, 0.01),
			"ecart_ms": int(round((image_s - texte_s) * 1000.0)), "meme_fait": int(e.journal) == int(e.image_journal)})
	# Ralentis : début et durée murale de la régie convertis en temps simulé (-1 si la durée manque).
	report["ralentis"] = ralentis.map(func(e: Dictionary) -> Dictionary:
		var debut_ms := int(e.get("debut_ms", debut))
		var debut_s := vers_simule(echantillons, debut_ms)
		var duree_mur := float(e.get("duree_reelle", -1.0))
		var duree_sim: float = vers_simule(echantillons, debut_ms + int(round(duree_mur * 1000.0))) - debut_s if duree_mur >= 0.0 else -1.0
		return {"evenement": e.get("evenement"), "secondes": snappedf(debut_s, 0.1),
			"plan": e.get("plan", -1), "duree_source": e.get("duree_source", 0.0), "duree_prevue": e.get("duree_prevue", 0.0), "duree_reelle": duree_sim,
			"passe": e.get("passe", false), "hauteur_camera": e.get("hauteur_camera", 0.0), "gene_angle": e.get("gene_angle", -1.0), "retrait": e.get("retrait", -1.0),"ecart_restitution": e.get("ecart_restitution", -1.0)})
	report["images_ralenti"] = report.images.filter(func(i: Dictionary) -> bool: return bool(i.get("ralenti", false))).size()
	if o.planche and not report.images.is_empty():
		var choisies: Array = []
		for k in repartir(report.images.size(), 24): choisies.append(Image.load_from_file(str(o.sortie).path_join(report.images[k].fichier)))
		var feuille := planche(choisies, 4, 400)
		if feuille != null and feuille.save_png(str(o.sortie).path_join("planche.png")) == OK: report["planche"] = "planche.png"
		# Planche des grands moments seuls (essais, mi-temps, fin), dans l'ordre du match.
		var des_moments: Array = report.images.filter(func(i: Dictionary) -> bool: return not str(i.get("moment", "")).is_empty())
		if not des_moments.is_empty():
			var vues: Array = []
			for k in repartir(des_moments.size(), 24): vues.append(Image.load_from_file(str(o.sortie).path_join(des_moments[k].fichier)))
			var feuille_moments := planche(vues, 4, 400)
			if feuille_moments != null and feuille_moments.save_png(str(o.sortie).path_join("planche-moments.png")) == OK: report["planche_moments"] = "planche-moments.png"
	var fichier := FileAccess.open(str(o.sortie).path_join("report.json"), FileAccess.WRITE)
	fichier.store_string(JSON.stringify(report, "  "))
	fichier.close()
	print("MATCH_FILME_FIN ", JSON.stringify({"images": report.images.size(), "noires": report.noires, "moments": report.moments.map(func(m: Dictionary) -> String: return "%s %d′ %s" % [m.moment, int(m.minute), m.premiere_image]), "score": report.score, "minute": report.minute, "termine": report.termine, "secondes": report.duree_s, "duree_reelle_s": report.duree_reelle_s, "images_par_seconde_reelles": report.images_par_seconde_reelles, "pilote": report.pilote, "audio": report.audio}))
	app.closing = true
	app.bridge.stop()
	for k in 10: await process_frame
	quit(0 if not report.images.is_empty() and report.noires < report.images.size() else 3)
