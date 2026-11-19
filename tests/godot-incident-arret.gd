extends SceneTree
## Arrêt-incident dans l'écran intermédiaire du match (match_between.gd), sans moteur : la projection
## `live.direct.arret` d'un remplacement forcé (native/engine/incidents-match.cjs, match-direct.cjs) avec
## le choix du manager. Vérifie : titre selon le motif, une ligne par joueur possible (nom, poste,
## énergie), focus sur le choix du staff, la commande `match_incident_choice` {cle, id} envoyée à
## l'application trouvée en remontant les parents, choix figé ensuite ; un carton garde son titre.
const Between = preload("res://ui/contextual/match_between.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

## Application factice : retient les commandes reçues.
func fausse_app() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar envois: Array = []\nfunc _command(command: String, payload: Dictionary = {}, _route: String = \"\") -> bool:\n\tenvois.append([command, payload])\n\treturn true\n"
	script.reload()
	var app := Node.new()
	app.set_script(script)
	return app

## Vue du match factice : porte l'application comme la vraie (match_view → `app`).
func fausse_vue(app: Node) -> Control:
	var script := GDScript.new()
	script.source_code = "extends Control\nvar app: Node\n"
	script.reload()
	var vue := Control.new()
	vue.set_script(script)
	vue.set("app", app)
	vue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return vue

func blessure() -> Dictionary:
	return {"cle": "incident-m42-118", "raison": "blessure", "rouge": false, "pourNous": false, "horloge": "34′",
		"texte": "VOT · Blessure : Hugo Marchal doit quitter le terrain, Jules Dupont le remplace.",
		"choix": {"type": "entrant", "options": [
			{"id": "p17", "nom": "Jules Dupont", "poste": "talonneur", "energie": 82, "actuel": true},
			{"id": "p18", "nom": "Bastien Rey", "poste": "Pilier gauche", "energie": 91, "actuel": false},
			{"id": "p21", "nom": "Noa Ferrand", "poste": "Troisième ligne", "energie": 76, "actuel": false}]}}

func options(ecran: Control) -> Array:
	var boite := ecran.find_child("MatchBetweenStopOptions", true, false) as Container
	if boite == null: return []
	return boite.get_children().filter(func(n): return n is Button and not n.is_queued_for_deletion())

func dedans(ecran: Control, taille: Vector2i) -> bool:
	var panneau := ecran.find_child("MatchBetweenStop", true, false) as Control
	return panneau != null and Rect2(Vector2.ZERO, Vector2(taille)).encloses(panneau.get_global_rect())

func run() -> void:
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = taille
		var app := fausse_app()
		root.add_child(app)
		var vue := fausse_vue(app)
		root.add_child(vue)
		var ecran: Control = Between.new()
		ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vue.add_child(ecran)
		for i in 4: await process_frame
		var equipes := [{"id": 7, "name": "Meadowbridge Rovers", "abbr": "MBR", "color": "#2a5bd7"}, {"id": 102, "name": "Votre club", "abbr": "VOT", "color": "#d43e47"}]
		var live := {"teams": equipes, "events": [], "finished": false, "paused": true, "lineup": [], "incidentChoix": {"cle": "incident-m42-118"}}
		ecran.update_frame({}, live, {"camp": 1, "score": [3, 7], "borne": 0, "fil": []}, func(_c): pass)
		for i in 3: await process_frame
		var arret := blessure()
		ecran.montrer_arret(arret)
		for i in 4: await process_frame
		var cadre := "%dx%d" % [taille.x, taille.y]
		check(ecran.arret_titre.text.begins_with("BLESSURE"), cadre + " : titre BLESSURE (" + ecran.arret_titre.text + ")")
		check(ecran.arret_texte.text.contains("Le staff propose J. Dupont. Choisis qui entre :"), cadre + " : phrase du manager (" + ecran.arret_texte.text + ")")
		var boutons := options(ecran)
		check(boutons.size() == 3, cadre + " : trois joueurs proposés (%d)" % boutons.size())
		if boutons.size() == 3:
			check(boutons[0].text == "J. Dupont · Talonneur · 82 %", cadre + " : nom, poste, énergie (" + boutons[0].text + ")")
			check(boutons[0].has_meta("retenue") and not boutons[1].has_meta("retenue"), cadre + " : choix du staff mis en avant")
			check(root.gui_get_focus_owner() == boutons[0], cadre + " : focus clavier/manette sur le choix du staff (%s)" % root.gui_get_focus_owner())
			check(boutons.all(func(b): return b.focus_mode == Control.FOCUS_ALL and not b.disabled), cadre + " : options atteignables au clavier")
			check(ecran.find_child("MatchBetweenStopTeam", true, false) != null and ecran.find_child("MatchBetweenStopResume", true, false) != null, cadre + " : Équipe et Reprendre gardés")
			check(dedans(ecran, taille), cadre + " : le panneau tient dans l'écran")
			boutons[1].pressed.emit()
			for i in 3: await process_frame
			var envois: Array = app.get("envois")
			check(envois.size() == 1 and envois[0][0] == "match_incident_choice" and envois[0][1] == {"cle": "incident-m42-118", "id": "p18"}, cadre + " : commande envoyée (%s)" % [envois])
			boutons = options(ecran)
			check(boutons.size() == 3 and boutons.all(func(b): return b.disabled), cadre + " : options figées après le choix")
			check(boutons.size() == 3 and boutons[1].has_meta("retenue") and not boutons[0].has_meta("retenue"), cadre + " : le joueur choisi est mis en avant")
			check(ecran.arret_texte.text.contains("Choix enregistré : B. Rey entre."), cadre + " : choix confirmé (" + ecran.arret_texte.text + ")")
			check(root.gui_get_focus_owner() == ecran.find_child("MatchBetweenStopResume", true, false), cadre + " : focus sur Reprendre après le choix")
			# Un second clic n'envoie rien ; la réponse du moteur (choix vidé) ne change plus l'écran.
			boutons[2].pressed.emit()
			live.incidentChoix = null
			ecran.update_frame({}, live, {"camp": 1, "score": [3, 7], "borne": 0, "fil": []}, func(_c): pass)
			for i in 2: await process_frame
			check((app.get("envois") as Array).size() == 1, cadre + " : un seul envoi")
			check(ecran.arret_texte.text.contains("Choix enregistré"), cadre + " : confirmation gardée après la réponse")
		# Carton : titre d'origine, aucune option.
		ecran.montrer_arret({"cle": "carton-12", "raison": "carton", "rouge": true, "pourNous": false, "texte": "VOT · Carton rouge pour Hugo Marchal.", "horloge": "51′"})
		for i in 3: await process_frame
		check(ecran.arret_titre.text.begins_with("CARTON ROUGE"), cadre + " : carton rouge (" + ecran.arret_titre.text + ")")
		check(options(ecran).is_empty() and not ecran.arret_options.visible, cadre + " : pas d'option sur un carton")
		check(ecran.arret_texte.text.contains("Le match est en pause"), cadre + " : phrase d'arrêt habituelle")
		# Choc à la tête sans alternative : titre propre, pas de choix.
		ecran.montrer_arret({"cle": "incident-m42-140", "raison": "hia", "texte": "VOT · HIA.", "horloge": "60′"})
		check(ecran.arret_titre.text.begins_with("CHOC À LA TÊTE"), cadre + " : HIA (" + ecran.arret_titre.text + ")")
		# Choix devenu impossible côté moteur : options figées, le staff garde sa décision.
		var perime := blessure()
		perime.cle = "incident-m42-150"
		ecran.montrer_arret(perime)
		live.incidentChoix = null
		live.paused = false
		ecran.update_frame({}, live, {"camp": 1, "score": [3, 7], "borne": 0, "fil": []}, func(_c): pass)
		for i in 2: await process_frame
		check(options(ecran).all(func(b): return b.disabled) and ecran.arret_texte.text.contains("Le staff garde sa décision"), cadre + " : choix périmé figé")
		vue.queue_free()
		app.queue_free()
		for i in 2: await process_frame
	print("INCIDENT_ARRET_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
