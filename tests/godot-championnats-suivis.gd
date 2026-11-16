extends SceneTree
## Championnats suivis dans le vrai jeu (profil préparé par tests/godot-championnats-suivis.cjs) :
## fenêtre de choix avec indicateur de fluidité aux couleurs d'état du carnet, puis classement
## d'un championnat suivi de loin (bandeau « SUIVI DE LOIN »). Captures 1920×1080.
const LeagueDetail = preload("res://ui/league_detail_view.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
var app: Control
var sortie := OS.get_environment("CD_SUIVIS_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var mesures: Dictionary = {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func capture(nom: String) -> void:
	await poser(14)
	if DisplayServer.get_name() == "headless" or sortie.is_empty(): return
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

func jauge(dialogue: Node, cas: String) -> void:
	var verdict := dialogue.find_child("LeagueDetailVerdict", true, false) as Label
	verifier(verdict != null, cas + " : verdict de la jauge")
	if verdict == null: return
	verifier(verdict.text in ["Fluide", "Correct", "Lent"], cas + " : cran « %s »" % verdict.text)
	# Couleurs d'état du carnet, transposées par l'habillage sombre des fenêtres (immersive08).
	var teinte: Color = verdict.get_theme_color("font_color")
	verifier(teinte in [G.GOOD, G.GOLD, G.ALERT, C.MINT, C.GOLD, C.ALERT], cas + " : couleur d'état du thème (%s)" % teinte.to_html())
	var temps := dialogue.find_child("LeagueDetailTiming", true, false) as Label
	verifier(temps != null and temps.text.contains("par semaine"), cas + " : temps par semaine")
	mesures[cas] = {"verdict": verdict.text, "temps": temps.text if temps else ""}

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var suivi: Dictionary = app.model.get("clubLife", {}).get("leagueDetail", {})
	verifier(bool(suivi.get("configured", false)), "réglage des championnats suivis présent")
	verifier(str(suivi.get("own", "")) == "elite", "championnat du club : élite")
	# Mesure de la machine (mise en cache dans le profil par le moteur).
	LeagueDetail.request_benchmark(app, true); await poser(4); await attendre_moteur()
	verifier(not LeagueDetail.benchmark(app).is_empty(), "banc d'essai reçu")
	LeagueDetail.open_career(app); await poser(20)
	var dialogue := app.get_node_or_null("LeagueDetailDialog")
	verifier(dialogue != null, "fenêtre des championnats suivis")
	if dialogue == null:
		print("SUIVIS ", JSON.stringify({"controles": controles, "failures": echecs, "mesures": mesures}))
		quit(1)
		return
	var cases := dialogue.find_children("LeagueDetail_*", "CheckBox", true, false)
	verifier(cases.size() >= 9, "une case par championnat (%d)" % cases.size())
	var mien := dialogue.find_child("LeagueDetail_elite", true, false) as CheckBox
	verifier(mien != null and mien.disabled and mien.button_pressed, "championnat du club coché et verrouillé")
	var loin := 0
	for l: Node in dialogue.find_children("*", "Label", true, false):
		if (l as Label).text == "SUIVI DE LOIN": loin += 1
	verifier(loin >= 8, "championnats suivis de loin signalés (%d)" % loin)
	jauge(dialogue, "defaut")
	await capture("championnats-suivis-defaut")
	for b: Node in dialogue.find_children("*", "Button", true, false):
		if (b as Button).text == "Tout suivre en détail": (b as Button).pressed.emit()
	await poser(10)
	jauge(dialogue, "tout")
	await capture("championnats-suivis-tout")
	(dialogue as Window).hide(); dialogue.queue_free(); await poser(6)
	# Classement d'un championnat suivi de loin : bandeau et légende des statistiques.
	app._navigate("Classements"); await poser(30)
	var onglet := app.find_child("StandingsDivision_prem", true, false) as Button
	verifier(onglet != null, "onglet de la PREM dans les classements")
	if onglet: onglet.pressed.emit()
	await poser(30)
	var bandeau := app.find_child("CompetitionFollowedFromAfar", true, false)
	verifier(bandeau != null, "bandeau « suivi de loin » sur le classement de la PREM")
	await capture("championnats-suivis-classement-prem")
	var retour := app.find_child("StandingsDivision_elite", true, false) as Button
	if retour: retour.pressed.emit()
	await poser(30)
	verifier(app.find_child("CompetitionFollowedFromAfar", true, false) == null, "pas de bandeau sur le championnat du club")
	print("SUIVIS ", JSON.stringify({"affichage": DisplayServer.get_name(), "controles": controles, "failures": echecs, "mesures": mesures}))
	quit(0 if echecs.is_empty() else 1)
