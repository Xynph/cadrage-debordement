extends SceneTree
## Conférence de presse rapide dans le vrai jeu (Godot réel + worker réel, carrière Monde au 13 juillet 2026).
## 1. Grand moment (arrivée) : 4 questions, tons et effets visibles, adjoint refusé ; un clic par question (la
##    suivante s'affiche d'elle-même), « Publier », bilan des trois conséquences, « Continuer ».
## 2. Conférence ordinaire suivante (atteinte par « Continuer ») : 3 questions au plus, réglage « Envoyer l'adjoint »,
##    puis « Envoyer mon adjoint » : deux clics en tout (adjoint, Continuer).
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
	# 1. Arrivée : grand moment.
	var conference: Dictionary = press().get("conference", {})
	check(conference.get("available", false) and conference.get("moment") is Dictionary, "Conférence d'arrivée : grand moment")
	var questions: Array = conference.get("questions", [])
	check(questions.size() == 4, "Grand moment : 4 questions (%d)" % questions.size())
	if not await open_room(): return finish()
	var moment := node("PressMoment")
	check(moment != null and moment.find_children("*", "Label", true, false).any(func(l: Label): return l.text.begins_with("GRAND MOMENT")), "Bandeau « Grand moment » visible")
	var delegate := node("PressDelegate") as Button
	check(delegate != null and delegate.disabled, "Grand moment : l'adjoint n'est pas proposé")
	check(node("PressDelegateReason") != null and str(node("PressDelegateReason").text).contains("en personne"), "Raison affichée : présence attendue")
	check(node("PressMicrophone") != null, "Micro aux couleurs du média")
	var first: Dictionary = questions[0]
	for answer: Dictionary in first.answers:
		var card := node("PressAnswer_%s_%s" % [first.id, answer.id]) as Button
		check(card != null and card.text == str(answer.text), "Texte exact de la réponse " + str(answer.id))
		if card == null: continue
		var tone := card.find_child("PressTone", true, false)
		var effects := card.find_child("PressEffects", true, false) as RichTextLabel
		check(tone != null and effects != null and effects.get_parsed_text().contains("Moral") and effects.get_parsed_text().contains("Relation"), "Ton et effets visibles sur la carte " + str(answer.id))
	await capture("presse-apres-grand-moment")
	var clicks := 0
	for index in questions.size():
		var shown: Dictionary = questions[view().question_index]
		check(view().question_index == index, "Question %d affichée d'elle-même" % (index + 1))
		if await click("PressAnswer_%s_%s" % [shown.id, "r1"]): clicks += 1
	check(view().choices.size() == questions.size(), "Toutes les réponses en un clic chacune")
	if await click("PressPublish"): clicks += 1
	await settle(8)
	check(node("PressOutcomeHeadline") != null, "Bilan : moral, relation presse, confiance")
	await capture("presse-apres-bilan")
	if await click("PressReturn"): clicks += 1
	check(clicks == questions.size() + 2, "Parcours complet en %d clics (questions + publier + continuer)" % clicks)
	print("CD_PRESSE grand moment : ", clicks, " clics pour ", questions.size(), " questions")
	# 2. Conférence ordinaire suivante, atteinte avec « Continuer ».
	var reached := false
	for attempt in 12:
		await Flow.settle_club_meetings(app, self, check, "press")
		if press().get("conference", {}).get("available", false): reached = true; break
		if not await command("advance_until_event", {"fromDate": str(app.model.get("meta", {}).get("calendarToday", ""))}): break
		var cadence: Dictionary = app.model.get("meta", {}).get("calendarCadence", {})
		if cadence.get("matchReady", false): break
	check(reached, "Une conférence ordinaire s'ouvre (" + str(app.model.get("meta", {}).get("calendarToday", "")) + ")")
	if not reached: return finish()
	conference = press().conference
	questions = conference.get("questions", [])
	check(not conference.get("moment") is Dictionary and questions.size() >= 2 and questions.size() <= 3, "Ordinaire : 3 questions au plus (%d)" % questions.size())
	if not await open_room(): return finish()
	check(node("PressDelegate") != null and not (node("PressDelegate") as Button).disabled, "« Envoyer mon adjoint » proposé")
	await capture("presse-apres-ordinaire")
	# Dilemmes : les cinq tons n'affichent pas les mêmes effets, et aucun n'est meilleur sur tous les axes.
	var shown_q: Dictionary = questions[view().question_index]
	var rows := {}
	for answer: Dictionary in shown_q.get("answers", []):
		var effects := (node("PressAnswer_%s_%s" % [shown_q.id, answer.id]) as Button).find_child("PressEffects", true, false) as RichTextLabel
		rows[str(answer.tone)] = effects.get_parsed_text() if effects != null else ""
	check(rows.size() == 5 and rows.values().size() == 5 and rows.values().duplicate().size() == 5 and _distinct(rows.values()), "Cinq tons, cinq profils d'effets différents")
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
	# Réglage de carrière depuis la salle.
	if await click("PressPolicy_adjoint"):
		check(press().get("policy", {}).get("ordinary") == "adjoint", "Réglage « envoyer l'adjoint » enregistré")
		await settle(4)
		check(node("PressPolicy_adjoint") != null and (node("PressPolicy_adjoint") as Button).disabled, "Réglage actif affiché")
	clicks = 0
	if await click("PressDelegate"): clicks += 1
	await settle(8)
	var outcome: Dictionary = press().get("lastOutcome", {})
	check(outcome.get("delegated", false), "Conférence tenue par Gabi")
	check(view() != null and view().find_children("*", "Label", true, false).any(func(l: Label): return l.text == "Gabi a tenu la conférence"), "Bilan : Gabi a répondu, coût annoncé")
	await capture("presse-apres-adjoint")
	if await click("PressReturn"): clicks += 1
	check(clicks == 2, "Adjoint : deux clics (%d)" % clicks)
	check(view() == null, "Salle refermée")
	finish()

func _distinct(values: Array) -> bool:
	var seen := {}
	for value in values: seen[str(value)] = true
	return seen.size() == values.size()

func finish() -> void:
	if failures.is_empty(): print("Presse rapide Godot · %d contrôles réussis" % checks)
	else: printerr("Presse rapide Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
