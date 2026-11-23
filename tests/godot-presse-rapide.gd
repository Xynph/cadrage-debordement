extends SceneTree
## Conférence de presse rapide dans le vrai jeu (Godot réel + worker réel, carrière Monde au 13 juillet 2026).
## Calendrier de presse façon FM (18/11/2026) : aucune conférence à la création de la carrière.
## 1. Grand moment (la rentrée, ouverte le lundi de la semaine du 1er match, atteinte par « Continuer ») : 4 questions,
##    chacune sur un vrai joueur de l'effectif ; tons visibles mais AUCUN effet avant de répondre (choix de Léo du
##    23/11/2026) ; petites fenêtres du joueur et du journaliste ; adjoint refusé ; un clic par question dit la réponse
##    (la suivante s'affiche, la réaction se découvre en flèches), la dernière publie ; bilan en flèches, « Continuer ».
## 2. Conférence ordinaire : l'après-match du 1er match (3 questions au plus, salle de presse ouverte par le jeu dès le
##    résultat), cinq tons aux conséquences différentes, réglage « Envoyer l'adjoint », « Envoyer mon adjoint » d'un
##    clic, bilan, « Continuer » qui ramène en Réception.
## CD_PRESSE_CAPTURES=<dossier> : captures 1920×1080 (rendu fenêtré requis).
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var captures := OS.get_environment("CD_PRESSE_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames := 5) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 300000) -> bool:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
	return not app.waiting

func command(id: String, payload: Dictionary = {}) -> bool:
	if not app._command(id, payload):
		check(false, "Commande acceptée · " + id)
		return false
	await wait_idle()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func press() -> Dictionary:
	return app.model.get("clubLife", {}).get("press", {})

func view() -> Control:
	var director: Node = app.contextual_director
	return director.view if director.active() and director.kind == "press" else null

func node(id: String) -> Node:
	var room := view()
	return room.find_child(id, true, false) if room != null else null

func click(id: String) -> bool:
	var target := node(id) as BaseButton
	check(target != null and target.is_visible_in_tree() and not target.disabled, "Bouton actif : " + id)
	if target == null or target.disabled: return false
	target.pressed.emit()
	await settle()
	if app.waiting: await wait_idle()
	return true

func capture(name_: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(captures)
	await settle(30)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.save_png(captures.path_join(name_ + ".png")) == OK, "Capture " + name_)

## Ouvre la salle comme le fait l'action du courrier de presse en Réception.
func open_room() -> bool:
	var invitation := str(press().get("conference", {}).get("invitationId", ""))
	check(not invitation.is_empty(), "Invitation de presse en attente")
	app.set_meta("press_mail_origin", invitation)
	app.contextual_director.sync()
	await settle(8)
	check(view() != null, "Salle de presse ouverte")
	return view() != null

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	if is_instance_valid(app.coach): app.coach.close()
	# 1. Arrivée : grand moment, ouverte en avançant jusqu'à la semaine du 1er match (rien à la création de la carrière).
	check(not press().get("conference", {}).get("available", false), "Aucune conférence à la création de la carrière")
	var arrived: bool = await Flow.reach_press_conference(app, self, check)
	check(arrived, "La conférence d'arrivée s'ouvre en avançant (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
	if not arrived: return finish()
	var conference: Dictionary = press().get("conference", {})
	check(conference.get("available", false) and conference.get("moment") is Dictionary, "Conférence d'arrivée : grand moment")
	var questions: Array = conference.get("questions", [])
	check(questions.size() == 4, "Grand moment : 4 questions (%d)" % questions.size())
	if not await open_room(): return finish()
	check(node("PressMoment") != null, "Pastille « grand moment » visible")
	check(node("PressDelegate") == null, "Grand moment : l'adjoint n'est pas proposé")
	check(node("PressDelegateReason") != null, "Pastille « En personne » affichée")
	check(questions.all(func(q: Dictionary): return q.get("player") is Dictionary and not str(q.player.get("name", "")).is_empty()), "Chaque question vise un vrai joueur de l'effectif")
	var ids := {}
	for q: Dictionary in questions: ids[str(q.get("player", {}).get("id", ""))] = true
	check(ids.size() == questions.size(), "Un joueur différent par question")
	var first: Dictionary = questions[0]
	check(node("PressPlayerName") != null and str(node("PressPlayerName").text) == str(first.player.name), "Carte du joueur concerné")
	check(str((node("PressQuestion") as Label).text) == str(first.question), "Question du moteur dans la bulle")
	for answer: Dictionary in first.answers:
		var card := node("PressAnswerCard_%s" % answer.id)
		check(node("PressAnswer_%s_%s" % [first.id, answer.id]) is Button, "Réponse cliquable " + str(answer.id))
		check(card != null and card.find_children("*", "Label", true, false).any(func(l: Label): return l.text == str(answer.text)), "Texte exact de la réponse " + str(answer.id))
		check(card != null and card.find_child("PressAnswerTone_" + str(answer.id), true, false) != null, "Pastille de ton " + str(answer.id))
		check(card != null and _fleches(card) == 0, "Aucun effet montré avant de répondre " + str(answer.id))
	check(_fleches(view()) == 0, "Aucune flèche avant la première réponse")
	# Petites fenêtres : joueur puis journaliste (✕ et Échap ferment).
	await click("PressPlayerOpen")
	check(node("PressPlayerWindow") != null and node("PressPlayerWindowForm") != null and node("PressPlayerWindowMorale") != null and node("PressPlayerWindowTrust") != null, "Fenêtre du joueur : forme, moral, confiance")
	await capture("presse-fenetre-joueur")
	await click("PressPlayerWindowFermer")
	await settle(3)
	check(node("PressPlayerWindow") == null or node("PressPlayerWindow").is_queued_for_deletion(), "✕ ferme la fenêtre du joueur")
	await click("PressJournalistOpen")
	check(node("PressJournalistWindow") != null and node("PressJournalistWindowRelation") != null, "Fenêtre du journaliste : relation")
	check(load("res://ui/petite_fenetre.gd").fermer_derniere(self), "Échap ferme la fenêtre du journaliste")
	await settle(3)
	await capture("presse-apres-grand-moment")
	var clicks := 0
	for index in questions.size():
		var shown: Dictionary = questions[view().question_index]
		check(view().question_index == index, "Question %d affichée d'elle-même" % (index + 1))
		if await click("PressAnswer_%s_%s" % [shown.id, "r1"]): clicks += 1
		if index == 0:
			check(node("PressReaction") != null and node("PressReaction").find_children("PressReaction_*", "", true, false).size() == 5, "Réaction de la 1re réponse : cinq flèches")
			check(node("PressAnswer_%s_r0" % shown.id) == null, "Une réponse dite ne se reprend pas")
			await capture("presse-reaction")
	check(press().get("lastOutcome", {}).get("players", []).size() >= 1, "La dernière réponse publie ; moral des joueurs visés touché")
	await settle(8)
	check(node("PressOutcomeHeadline") != null and _fleches(node("PressOutcomeHeadline")) >= 4, "Bilan en flèches")
	await capture("presse-apres-bilan")
	if await click("PressReturn"): clicks += 1
	check(clicks == questions.size() + 1, "Parcours complet en %d clics (questions + continuer)" % clicks)
	print("CD_PRESSE grand moment : ", clicks, " clics pour ", questions.size(), " questions")
	# 2. Conférence ordinaire : l'après-match du 1er match, ouvert dès la validation du résultat.
	var played: bool = await Flow.play_to_result(app, self, check)
	check(played, "Le 1er match est joué jusqu'au résultat (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
	if not played: return finish()
	conference = press().get("conference", {})
	check(conference.get("available", false) and str(press().get("context", {}).get("slot", "")) == "apres", "Une conférence d'après-match s'ouvre (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
	if not conference.get("available", false): return finish()
	questions = conference.get("questions", [])
	check(not conference.get("moment") is Dictionary and questions.size() >= 2 and questions.size() <= 3, "Ordinaire : 3 questions au plus (%d)" % questions.size())
	# L'après-match s'ouvre de lui-même dans la salle de presse dès la validation du résultat (18/11/2026), sans
	# passer par la Réception ni par un arrêt de « Continuer ».
	await settle(8)
	await wait_idle()
	check(view() != null, "Après-match : la salle de presse s'ouvre d'elle-même")
	if view() == null: return finish()
	await capture("presse-apres-ordinaire")
	# Dilemmes : les cinq tons n'ont pas les mêmes conséquences, et aucun n'est meilleur sur tous les axes.
	var shown_q: Dictionary = questions[view().question_index]
	var rows := {}
	for answer: Dictionary in shown_q.get("answers", []):
		check(node("PressAnswer_%s_%s" % [shown_q.id, answer.id]) != null, "Réponse affichée dans la salle : " + str(answer.id))
		rows[str(answer.tone)] = JSON.stringify(answer.get("effects", {}))
	check(rows.size() == 5 and _distinct(rows.values()), "Cinq tons, cinq profils d'effets différents")
	var best := 0
	for answer: Dictionary in shown_q.get("answers", []):
		var fx: Dictionary = answer.get("effects", {})
		var better_than_all := true
		for other: Dictionary in shown_q.get("answers", []):
			if other == answer: continue
			var o: Dictionary = other.get("effects", {})
			if not (fx.morale >= o.morale and fx.media >= o.media and -fx.pressure >= -o.pressure and fx.relation >= o.relation): better_than_all = false
		if better_than_all: best += 1
	check(best == 0, "Aucun ton n'est meilleur ou égal sur tous les axes")
	await capture("presse-dilemmes")
	# Réglage de carrière depuis la salle : il vaut pour les prochains après-matchs.
	var toggle := node("PressPolicy_adjoint") as Button
	check(toggle != null and toggle.is_visible_in_tree(), "Réglage « Envoyer l'adjoint » proposé dans la salle")
	if toggle != null:
		toggle.pressed.emit()
		await settle(3)
		await wait_idle()
		check(press().get("policy", {}).get("ordinary") == "adjoint", "Réglage « envoyer l'adjoint » enregistré")
	check(press().get("conference", {}).get("available", false), "La conférence en cours reste à traiter après le réglage")
	# Après-match ordinaire : « Envoyer mon adjoint » d'un clic, puis « Continuer » referme la salle.
	var send := node("PressDelegate") as Button
	check(send != null and not send.disabled, "Après-match : l'adjoint est proposé")
	await click("PressDelegate")
	await settle(8)
	var outcome: Dictionary = press().get("lastOutcome", {})
	check(outcome.get("delegated", false), "Conférence tenue par Gabi")
	check(str(outcome.get("context", {}).get("slot", "")) == "apres", "Après-match tenu par Gabi")
	check(view() != null and node("PressReturn") != null, "Bilan affiché, « Continuer » proposé")
	await capture("presse-apres-adjoint")
	await click("PressReturn")
	await settle(8)
	check(app.route == "Réception", "Retour en Réception après l'après-match")
	check(view() == null, "Aucune salle de presse restée ouverte")
	finish()

## Flèches de réaction (conference_presse.gd, classe Fleche) sous un nœud.
func _fleches(n: Node) -> int:
	if n == null: return 0
	return n.find_children("*", "Control", true, false).filter(func(c: Node): return "sens" in c and "couleur" in c).size()

func _distinct(values: Array) -> bool:
	var seen := {}
	for value in values: seen[str(value)] = true
	return seen.size() == values.size()

func finish() -> void:
	if failures.is_empty(): print("Presse rapide Godot · %d contrôles réussis" % checks)
	else: printerr("Presse rapide Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
