extends SceneTree
## « Pourquoi » d'après-match dans l'écran « Match terminé » (match_between.gd), sans moteur : la projection de
## fin de match `live.direct.pourquoi` (native/engine/match-pourquoi.cjs) est celle du match réel du 19/09/2026
## (carrière Monde, club 102, victoire 29-17). Vérifie : titre selon l'issue, une ligne par raison avec son levier,
## une action par écran concerné, l'action ouvre la route du levier, rien avant le coup de sifflet final.
## CD_POURQUOI_PNG=<fichier.png> : capture de l'écran (rendu fenêtré requis, xvfb-run sous Linux).
const Between = preload("res://ui/contextual/match_between.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func pourquoi() -> Dictionary:
	return {"issue": "victoire", "raisons": [
		{"rang": 1, "levier": "preparation", "levierLabel": "Préparation", "sens": "positif", "texte": "Touche : 7 sur 8 pour nous, 7 sur 11 pour eux. La conquête a fait la différence.", "action": "Préparer la semaine", "route": "Préparation", "poids": -3.3},
		{"rang": 2, "levier": "condition", "levierLabel": "Condition", "sens": "negatif", "texte": "À surveiller : notre XV a fini à 66 % d’énergie contre 79 % en face : on a manqué de jus en fin de match.", "action": "Voir la condition", "route": "Effectif", "poids": 3.9},
		{"rang": 3, "levier": "discipline", "levierLabel": "Discipline", "sens": "positif", "texte": "Discipline propre : 6 pénalités concédées contre 11 en face.", "action": "Travailler la discipline", "route": "Composition", "poids": -6.0}]}

func direct(fini: bool) -> Dictionary:
	var d := {"camp": 1, "score": [17, 29], "borne": 10, "fil": [], "tableau": [
		{"cle": "possession", "label": "Possession", "valeurs": [44, 56], "unite": "%"},
		{"cle": "occupation", "label": "Occupation", "valeurs": [57, 43], "unite": "%"},
		{"cle": "touches", "label": "Touches gagnées", "valeurs": [7, 7], "sur": [11, 8]},
		{"cle": "penalites", "label": "Pénalités concédées", "valeurs": [11, 6], "inverse": true}],
		"hommeDuMatch": {"joueur": "p9", "camp": 1, "nom": "T. Harlow", "note": 8.1, "essais": 1, "plaquages": 9, "metres": 64}}
	if fini: d["pourquoi"] = pourquoi()
	return d

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var fond := ColorRect.new()
	fond.color = Color("0b1012")
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var ecran: Control = Between.new()
	root.add_child(ecran)
	for i in 4: await process_frame
	var equipes := [{"id": 7, "name": "Meadowbridge Rovers", "abbr": "MBR", "color": "#2a5bd7"}, {"id": 102, "name": "Votre club", "abbr": "VOT", "color": "#d43e47"}]
	var live := {"teams": equipes, "events": [], "finished": false, "paused": false, "lineup": []}
	# Pendant le match : aucune raison affichée, même si une projection en portait.
	ecran.update_frame({}, live, direct(false), func(_c): pass)
	for i in 3: await process_frame
	check(ecran.find_child("MatchWhyTitle", true, false) == null, "Rien avant le coup de sifflet final")
	live.finished = true
	ecran.update_frame({}, live, direct(true), func(_c): pass)
	for i in 6: await process_frame
	var titre := ecran.find_child("MatchWhyTitle", true, false) as Label
	check(titre != null and titre.text == "Pourquoi on a gagné", "Titre selon l’issue (" + (titre.text if titre != null else "absent") + ")")
	for rang in [1, 2, 3]: check(ecran.find_child("MatchWhy%d" % rang, true, false) != null, "Raison n° %d affichée" % rang)
	var routes: Array[String] = []
	ecran.levier_choisi.connect(func(route: String): routes.append(route))
	var actions := {"preparation": "Préparation", "condition": "Effectif", "discipline": "Composition"}
	for levier: String in actions:
		var bouton := ecran.find_child("MatchWhyAction_" + levier, true, false) as Button
		check(bouton != null and not bouton.disabled, "Action du levier " + levier)
		if bouton != null: bouton.pressed.emit()
	check(routes == ["Préparation", "Effectif", "Composition"], "Chaque action ouvre l’écran de son levier : " + str(routes))
	var capture := OS.get_environment("CD_POURQUOI_PNG")
	if not capture.is_empty():
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image != null and image.save_png(capture) == OK, "Capture : " + capture)
	if failures.is_empty(): print("Pourquoi d’après-match Godot · %d contrôles réussis" % checks)
	else: printerr("Pourquoi d’après-match Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
