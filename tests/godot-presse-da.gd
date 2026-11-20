extends SceneTree
# Presse (variante 3 « Synthèse à gauche », décision de Léo du 19/11/2026), carrière Monde réelle :
# verdict de pression à trois paliers (mot + symbole), tout ce qui ressemble à un lien en est un, aucune fenêtre ouverte
# par un clic, un seul ivoire plein, aucun or hors Continuer, clubs et journalistes cliquables.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle(frames := 6) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func finish() -> void:
	print("PRESSE DA : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found

func page() -> Control:
	return app.find_child("CarnetPresse", true, false) as Control

func visible_buttons() -> Array:
	var found: Array = []
	for button: Button in page().find_children("*", "Button", true, false):
		if button.is_visible_in_tree(): found.append(button)
	return found

func fill_of(button: Button, state: String) -> Color:
	var style := button.get_theme_stylebox(state) as StyleBoxFlat
	return style.bg_color if style != null else Color(0, 0, 0, 0)

## Aucun or (Continuer seul), un ivoire plein au plus, aucun bouton visible sans effet.
func check_buttons(label: String) -> void:
	var plein := 0
	var morts: Array[String] = []
	for button: Button in visible_buttons():
		for state in ["normal", "hover", "pressed"]:
			var fond := fill_of(button, state)
			check(not fond.is_equal_approx(Charte.OR) and not fond.is_equal_approx(Charte.OR_VIF), label + " : pas d'or sur " + button.name)
		if fill_of(button, "normal").is_equal_approx(Charte.IVOIRE): plein += 1
		if not button.disabled and button.get_signal_connection_list("pressed").is_empty(): morts.append(str(button.name))
	check(plein <= 1, label + " : un seul bouton ivoire plein (" + str(plein) + ")")
	check(morts.is_empty(), label + " : aucun bouton sans effet " + str(morts))

func click(button: Button) -> void:
	var nom := str(button.name)
	button.pressed.emit()
	await settle(8)
	check(windows(app).is_empty(), "Aucune fenêtre après le clic sur " + nom)

func conference_ouverte() -> void:
	# Conférence ouverte (arrivée au club) : réponses en place, Publier expliqué, Gabi demande confirmation en ligne.
	var conference: Dictionary = app.model.clubLife.press.conference
	# Carrière neuve : pas toujours de conférence ouverte (l'invitation vient plus tard) ; le parcours est alors vu en capture.
	if not conference.get("available", false): print("PRESSE DA : aucune conférence ouverte au départ, parcours des réponses non exercé")
	if conference.get("available", false):
		app.set_meta("press_mail_origin", conference.invitationId)
		app.management_ui.press_tab = 1
		app._navigate("Presse")
		await settle(10)
		var submit := page().find_child("PressSubmit", true, false) as Button
		var missing := page().find_child("PressSubmitMissing", true, false) as Label
		check(submit != null and submit.disabled and missing != null and missing.text.contains("sans réponse"), "Publier désactivé, avec la raison écrite")
		check_buttons("Conférence ouverte")
		for question: Dictionary in conference.questions:
			var reponse := page().find_child("PressAnswer_" + str(question.id) + "_" + str(question.answers[0].id), true, false) as Button
			check(reponse != null, "Réponse cliquable " + str(question.id))
			if reponse != null: await click(reponse)
		check(submit != null and not submit.disabled and missing.text.is_empty(), "Toutes les réponses choisies : Publier actif, raison effacée")
		var ask := page().find_child("PressDelegateAsk", true, false) as Button
		var confirm := page().find_child("PressDelegate", true, false) as Button
		if ask != null:
			check(confirm != null and not confirm.visible, "Gabi : rien ne part au premier clic")
			await click(ask)
			check(confirm.visible and page().find_child("PressDelegateCancel", true, false).visible, "Gabi : confirmation en ligne")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await wait_idle()
	await conference_ouverte()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app.set_meta("press_mail_origin", "qa-presse-da")
	app.management_ui.press_tab = 0
	app._navigate("Presse")
	await settle(10)
	check(page() != null, "La page Presse est affichée")
	if page() == null: return finish()

	# Verdict de pression : un mot parmi trois, jamais la couleur seule (symbole et chiffre à côté).
	var verdict := page().find_child("PressPressureVerdict", true, false) as Label
	check(verdict != null and verdict.text in ["CALME", "SOUS TENSION", "TEMPÊTE"], "Pression : verdict à trois paliers en toutes lettres")
	check(page().find_child("PressMetricMedia", true, false) != null and page().find_child("PressMetricFans", true, false) != null, "Médias et supporters affichés")
	check(page().find_child("PressDivision", true, false) != null, "Sélecteur de division du journal")
	check_buttons("Journal")

	# Journal : un score choisit la coupure ; un club ouvre sa fiche.
	var scores := page().find_children("PressResult_*", "Button", true, false)
	if scores.size() >= 2:
		await click(scores[scores.size() - 1])
		var apres := page().find_child("PressHeadline", true, false) as Label
		check(apres != null, "La coupure reste affichée après le choix d'un score")
	var clubs: Array = []
	for bouton: Button in visible_buttons():
		if str(bouton.get_meta("entity_kind", "")) == "club": clubs.append(bouton)
	# Début de carrière : aucun résultat encore, donc aucun nom de club à lier.
	check(not clubs.is_empty() or scores.is_empty(), "Les noms de clubs du journal sont des liens")
	if not clubs.is_empty():
		await click(clubs[0])
		check(app.route != "Presse", "Clic sur un club : on change d'écran (" + str(app.route) + ")")
		app.set_meta("press_mail_origin", "qa-presse-da")
		app._navigate("Presse")
		await settle(10)

	# Onglets.
	for index in [1, 2, 3, 0]:
		var onglet := page().find_child("PressCanvasTab" + str(index), true, false) as Button
		check(onglet != null, "Onglet " + str(index))
		if onglet == null: continue
		await click(onglet)
		var tabs := page().find_child("PressTabs", true, false) as TabContainer
		check(tabs.current_tab == index, "Onglet " + str(index) + " ouvert")
		check_buttons("Onglet " + str(index))
	# Portraits : un autre journaliste change le détail.
	await click(page().find_child("PressCanvasTab3", true, false))
	var gens := page().find_children("PressPerson_*", "Button", true, false)
	check(gens.size() > 1, "Portraits : plusieurs journalistes cliquables")
	if gens.size() > 1:
		await click(gens[1])
		check(page().find_child("PressCanvasTab3", true, false) != null and (page().find_child("PressTabs", true, false) as TabContainer).current_tab == 3, "Portraits : le choix reste sur l'onglet")
	# Liens de la colonne de gauche.
	await click(page().find_child("OpenPressHistory", true, false))
	check((page().find_child("PressTabs", true, false) as TabContainer).current_tab == 2, "« Historique » ouvre l'onglet Historique")
	await click(page().find_child("OpenPressPeople", true, false))
	check((page().find_child("PressTabs", true, false) as TabContainer).current_tab == 3, "« Portraits » ouvre l'onglet Portraits")
	# Plus d'ancienne vue : 1280 × 720 affiche la page de la direction artistique.
	root.size = Vector2i(1280, 720)
	await settle(10)
	app._navigate("Presse")
	await settle(10)
	check(page() != null and page().find_child("PressCanvasTab0", true, false) != null and page().find_child("PressImage", true, false) != null, "1280x720 : la page Presse de la DA (onglets, Ton image)")
	root.size = Vector2i(1920, 1080)
	await settle(10)
	finish()