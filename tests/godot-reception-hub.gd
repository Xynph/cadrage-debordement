extends SceneTree

var app: Control
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	printerr("FAIL: ", message)

func settle() -> void:
	for frame in 6: await process_frame

func wait_worker() -> void:
	var deadline := Time.get_ticks_msec() + 25000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok, "Réponse du moteur : " + app.last_command)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_worker()
	app._command("new_career", {"mode":"world-champ", "club":102}, "Bureau")
	await wait_worker()
	check(app.route == "Réception", "Une nouvelle carrière arrive en Réception")
	check(app.find_child("InboxOpenPressInvitation", true, false) == null, "La conférence reste derrière l’ouverture du courrier")
	check(app.find_child("Nav_Sélections", true, false) == null, "Les sélections sont masquées sans projection")
	app._navigate("Bureau")
	await settle()
	check(app.route == "Bureau", "Le Bureau reste consultable")
	app._navigate("Calendrier")
	var next: Dictionary = app.model.duplicate(true)
	next.clubLife.press.invitations = []
	next.clubLife.press.conference.required = false
	next.international = {"mail":[]}
	app.last_command = "advance_day"
	app._receive_model(next)
	await settle()
	check(app.route == "Calendrier", "Un jour ordinaire laisse le joueur sur sa page")
	var mail := {"id":"callup:2026-08-19:FRA", "kind":"callup", "title":"Convocation française",
		"body":"Un joueur est appelé.", "date":"2026-08-19", "action":"international", "nation":"FRA"}
	next = next.duplicate(true)
	next.international.mail = [mail, mail.duplicate(true)]
	app._receive_model(next)
	await settle()
	check(app.route == "Réception", "Une nouvelle convocation ramène à la Réception")
	var rows: Array = app.Immersive.Reception._messages(app).filter(func(message: Dictionary):
		return message.get("international_event", {}).get("id") == mail.id)
	check(rows.size() == 1, "La convocation apparaît une seule fois")
	check(app.find_child("InboxOpenInternational", true, false) != null, "Le courrier de convocation propose son lien")
	check(app.primary_button.text == "Jour suivant" and not app.primary_button.disabled, "La convocation laisse l’avance disponible")
	var action := app.find_child("InboxOpenInternational", true, false) as Button
	if action != null: action.pressed.emit()
	await settle()
	check(app.route == "Sélections" and app.find_child("InternationalSelections", true, false) != null, "Le courrier ouvre l’écran des sélections")
	app._navigate("Calendrier")
	app._receive_model(next)
	await settle()
	check(app.route == "Calendrier", "Un courrier déjà reçu ne rouvre pas la Réception")
	var job := {"id":"job:FRA", "kind":"national_job", "title":"Poste disponible",
		"body":"La sélection recherche un entraîneur.", "date":"2026-08-20", "action":"national_job", "nation":"FRA"}
	next = next.duplicate(true)
	next.international.jobs = [{"nation":"FRA", "name":"France"}]
	next.international.mail.append(job)
	app._receive_model(next)
	await settle()
	action = app.find_child("InboxOpenInternational", true, false) as Button
	if action != null: action.pressed.emit()
	await settle()
	var tabs := app.find_child("InternationalTabs", true, false) as TabContainer
	check(tabs != null and tabs.current_tab == 2 and tabs.get_tab_title(2) == "Offres", "Le courrier d’offre ouvre les offres")
	check(app.find_child("NationalJobDual_FRA", true, false) != null, "L’offre expose la prise de poste mixte")
	print("Réception centrale : ", failures, " échec(s)")
	await app._close(0 if failures == 0 else 1)
