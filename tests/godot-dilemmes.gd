extends SceneTree
## Captures 1280×720 du lot « dilemmes » (carrière Monde, club de Top 14) :
##  1. écran entre deux temps forts à la 70e minute : tuile Bonus et dilemme à deux consignes cliquables ;
##  2. feuille de match (Composition) : ligne du quota JIFF et joueurs de la liste des 33 des Bleus ;
##  3. Travail du club > Médical : un titulaire sous protocole commotion (HIA).
## Sauvegarde préparée par le vrai moteur (tests/godot-dilemmes.cjs) : CD_DILEMMES_SAUVEGARDE.
## Dossier des PNG : CD_DILEMMES_CAPTURE (sans lui, contrôles seuls).
const Between = preload("res://ui/contextual/match_between.gd")
const Rooms = preload("res://qa_runner.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_DILEMMES_CAPTURE")
var taille := Vector2i(1280, 720)

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames: int = 12) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.4).timeout
	for i in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle(16)
	if DisplayServer.get_name() == "headless" or dossier.is_empty(): return
	var image := root.get_texture().get_image()
	check(image.get_width() == taille.x and image.get_height() == taille.y, "Capture %s en %dx%d (%dx%d)" % [name, taille.x, taille.y, image.get_width(), image.get_height()])
	check(image.save_png(dossier.path_join(name + ".png")) == OK, "Capture " + name)

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Vraie réponse du moteur : " + str(app.last_error))
	await settle()

func rang(cle: String, valeurs: Array, unite: String = "") -> Dictionary:
	return {"cle": cle, "label": cle, "valeurs": valeurs, "unite": unite, "vide": false, "court": false}

## Projection `direct` à la 70e minute (forme de native/engine/match-direct.cjs), vue du camp 1 : +6, deux essais d'écart.
func direct_70() -> Dictionary:
	return {"version": 1, "camp": 1, "score": [14, 20], "possession": 1, "zone": {"x": 62.0},
		"echantillon": {"minutes": 70, "suffisant": true, "seuil": 10},
		"tableau": [rang("possession", [46, 54], "%"), rang("occupation", [41, 59], "%"), rang("metres", [212, 305]), rang("plaquages", [104, 88])],
		"fil": [{"i": 0, "horloge": "70′", "texte": "Essai de Toulouse Capitole.", "kind": "try", "equipe": 1}],
		"domination": {"minutes": [10, 20], "miTemps": null}, "reperes": [], "deroule": [], "borne": 1, "notes": {}, "cartons": [],
		"horloge": "70′",
		"bonus": {"version": 1, "regle": "3 essais d’écart · défaite de 5 pts ou moins",
			"offensif": {"acquis": false, "manque": 1, "horsDePortee": false, "texte": "Bonus offensif à 1 essai"},
			"defensif": {"statut": "sans-objet", "manque": null, "texte": ""},
			"situation": {"cle": "offensif", "texte": "+6 à la 70e, 2 essais d’écart : viser le bonus offensif ou sécuriser la victoire ?",
				"consignes": [{"id": "viser", "label": "Viser le bonus", "attack": "large", "defense": "equilibre", "penalty": "touch", "aide": "Jeu au large, pénaltouche : plus d’essais, mais plus de ballons perdus et de contres."},
					{"id": "securiser", "label": "Sécuriser", "attack": "conquete", "defense": "prudente", "penalty": "points", "aide": "Jeu au près, défense prudente, on prend les points : moins de ballons perdus et d’essais encaissés, moins d’essais marqués."}]}}}

func ecran_entracte() -> void:
	var between: Control = Between.new()
	between.position = Vector2(0, 100)
	between.size = Vector2(taille.x, taille.y - 100)
	root.add_child(between)
	for i in 3: await process_frame
	var live := {"teams": [{"name": "Bordeaux Estuaire", "abbr": "BOR"}, {"name": "Toulouse Capitole", "abbr": "TOU"}], "events": [{}], "lineup": [], "minute": 70}
	between.update_frame({"tactics": {"attack": "conquete", "defense": "prudente", "penalty": "points"}}, live, direct_70(), func(_c: Variant): pass)
	for i in 4: await process_frame
	check(between.bonus_tuile.visible, "Entracte 70e : tuile Bonus visible")
	check(between.bonus_situation.visible and between.bonus_situation.text.begins_with("+6 à la 70e"), "Entracte 70e : dilemme affiché")
	var viser := between.find_child("MatchBetweenBonusChoice_viser", true, false) as Button
	var securiser := between.find_child("MatchBetweenBonusChoice_securiser", true, false) as Button
	check(viser != null and securiser != null, "Entracte 70e : deux consignes cliquables")
	for b: Button in [viser, securiser]:
		if b == null: continue
		var cadre := b.get_global_rect()
		check(cadre.size.y >= 36.0 and cadre.end.x <= taille.x + 1.0 and cadre.end.y <= taille.y + 1.0, "Bouton « %s » assez grand et dans l'écran (%s)" % [b.text, str(cadre)])
	await capture("1-entracte-2d-bonus-70e")
	between.queue_free()
	await process_frame

## Gabi parle d'office à l'arrivée sur un écran : sa bulle masquerait la page, on la referme avant la capture.
func fermer_gabi() -> void:
	var coach = app.coach
	if coach == null: return
	coach.close()
	coach._attente.clear()
	await settle(8)

func page_visible(noeud_nom: String) -> Control:
	var n := app.find_child(noeud_nom, true, false) as Control
	return n if n != null and n.is_visible_in_tree() else null

func run() -> void:
	create_timer(900.0).timeout.connect(func():
		failures.append("délai dépassé (900 s)")
		fin())
	root.size = taille
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(taille)
		root.content_scale_size = taille
	await ecran_entracte()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	for forced: Signal in [root.size_changed, root.focus_entered]:
		if forced.is_connected(app._keep_filled_display): forced.disconnect(app._keep_filled_display)
	root.size = taille
	app._command("new_career", {"mode": "world-champ", "club": 0})
	await wait_engine()
	app.timer.stop()
	if not await Rooms.settle_club_meetings(app, self, check):
		fin()
		return
	app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_DILEMMES_SAUVEGARDE"))})
	await wait_engine()
	app.timer.stop()
	check(str(app.model.get("meta", {}).get("mode")) == "world", "Carrière Monde importée")
	# 2. Feuille de match : quota JIFF et liste des 33.
	check(bool(app.model.get("clubLife", {}).get("jiff", {}).get("applies", false)), "Le championnat impose un quota JIFF")
	app._navigate("Composition")
	await settle(30)
	var quota := page_visible("LineupJiffNotice")
	check(quota != null, "Feuille de match : la ligne du quota est visible")
	var liste := 0
	for p: Dictionary in app.model.get("squad", []):
		if p.get("playerFacts", {}).get("listeElite", false): liste += 1
	check(liste > 0, "Des joueurs de la liste des 33 dans l'effectif (%d)" % liste)
	await fermer_gabi()
	await capture("2-feuille-match-quota-liste-bleus")
	# 3. Infirmerie : onglet Médical de « Travail du club ».
	app.management_ui["immersive08_support_tab"] = 1
	app._navigate("Travail du club")
	await settle(30)
	var tabs := app.find_child("SupportTabs", true, false) as TabContainer
	if tabs != null: tabs.current_tab = 1
	await settle(10)
	var carte := app.find_children("Concussion_*", "", true, false)
	check(not carte.is_empty(), "Médical : un joueur sous protocole commotion")
	await fermer_gabi()
	await capture("3-infirmerie-commotion-hia")
	fin()

func fin() -> void:
	print("DILEMMES %d controles, %d echec%s" % [checks, failures.size(), "s" if failures.size() > 1 else ""])
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	quit(1 if failures.size() > 0 else 0)
