extends SceneTree
## Finances > Classement et fiche d'un club (profil préparé par tests/godot-sante-financiere.cjs, vrai moteur) :
## étiquette, propriétaire et mini-courbe des trois dernières saisons. Captures 1920×1080 en affichage graphique.
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
var app: Control
var sortie := OS.get_environment("CD_SANTE_OUTPUT")
var echecs: Array[String] = []
var controles := 0

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

func capturer(nom: String) -> void:
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom)) == OK, "capture " + nom)

func textes(noeud: Node) -> String:
	var t := ""
	for n in noeud.find_children("*", "", true, false):
		if n is Label: t += (n as Label).text + "\n"
		elif n is Button: t += (n as Button).text + "\n"
	return t

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var clubs: Array = app.model.get("finance", {}).get("clubs", [])
	verifier(clubs.size() == 16, "classement financier de la Pro D2 dans le modèle : %d clubs" % clubs.size())
	app.management_ui["immersive08_finance_tab"] = "clubs"
	app._navigate("Finances"); await poser(20)
	var panneau := app.find_child("FinanceClubsHealth", true, false)
	verifier(panneau != null, "panneau « Santé financière des clubs »")
	var lu := textes(panneau) if panneau != null else ""
	for mot in ["Propriétaire", "Trois dernières saisons", "ton club"]: verifier(lu.contains(mot), "« %s » dans le classement : %s" % [mot, lu.left(400)])
	verifier(lu.contains("Association") or lu.contains("Groupe actionnaire") or lu.contains("Mécène"), "types de propriétaires")
	for i in clubs.size():
		verifier(app.find_child("FinanceClubHealth%d" % i, true, false) != null and app.find_child("FinanceClubCurve%d" % i, true, false) != null, "ligne %d : étiquette et courbe" % i)
	verifier(not lu.contains("€"), "aucun montant dans le classement financier")
	await capturer("sante-classement.png")
	# Fiche d'un autre club : le premier du classement qui n'est pas le club du manager.
	var autre := -1
	for c: Dictionary in clubs:
		if not bool(c.get("own", false)): autre = int(c.id); break
	verifier(ClubSheet.open(app, autre), "ouverture de la fiche du club %d" % autre)
	await poser(4); await attendre_moteur(); await poser(10)
	var etiquette := app.find_child("ClubSheetHealth", true, false)
	verifier(etiquette != null, "étiquette de santé sur la fiche")
	verifier(app.find_child("ClubSheetOwner", true, false) != null and app.find_child("ClubSheetHealthCurve", true, false) != null, "propriétaire et courbe sur la fiche")
	await capturer("sante-fiche-club.png")
	print("SANTE ", JSON.stringify({"controles": controles, "failures": echecs, "clubs": clubs.size()}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
