extends SceneTree
const Reading = preload("res://ui/immersive08/reception_reading.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_RECEPTION_DECISIONS_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)

func settle() -> void:
	for frame in 12: await process_frame

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = pressed
		Input.parse_input_event(event); await process_frame
	await settle()

func activate(id: String) -> void:
	var button := app.find_child(id,true,false) as Button
	check(button != null and not button.disabled, "Contrôle réel disponible : " + id)
	if button == null: return
	button.grab_focus()
	await key(KEY_ENTER)

func wait_worker() -> void:
	var deadline := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and app.last_error.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Vrai moteur disponible : " + str(app.last_error))

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(2560,1440), "Capture réelle en 1440p")
	check(image.save_png(output.path_join(name+".png")) == OK, "Capture " + name)

func logic() -> void:
	var info := {"id":"information","text":"URGENT ! Contrat et blessure.","category":"Direction"}
	check(Reading.status(info,{}).key == "info", "Un texte alarmant ne crée pas une décision inventée")
	var press := {"id":"press-1","press_invitation":{"id":"press-1","status":"pending","context":{"club":2,"season":1,"week":3}}}
	var model := {"clubLife":{"press":{"conference":{"invitationId":"press-1","available":true,"required":true}}}}
	check(Reading.status(press,model).key == "todo" and Reading.status(press,model).urgent, "Conférence réellement requise classée urgente")
	model.clubLife.press.conference.available = false
	model.clubLife.press.conference.reason = "La conférence ouvrira au prochain rendez-vous."
	check(Reading.status(press,model).key == "waiting", "Indisponibilité explicite : en attente avec son motif")
	check(Reading.status(press,{}).key == "info", "Une invitation sans disponibilité vérifiable reste informative")
	var notice := {"id":"notice","calendar_notice":{"fixtureId":"match-42","status":"pending"}}
	check(Reading.status(notice,{}).key == "todo", "Avis calendrier en attente : choix à faire")
	notice.calendar_notice.status = "kept"
	check(Reading.status(notice,{}).key == "info", "Choix traité : information")
	var host := {"id":"international:host/cup-2031","international_event":{"id":"host/cup-2031","kind":"international_host"}}
	var guide := {"id":"international:host-guide/cup-2031","international_event":{"id":"host-guide/cup-2031","kind":"international_host"}}
	var another := {"id":"international:host/cup-2035","international_event":{"id":"host/cup-2035","kind":"international_host"}}
	check(Reading.groups([host,guide,another]).size() == 2, "Annonce et guide d'une même édition regroupés, années séparées")
	check(Reading.groups([info,{"id":"other","text":info.text}]).size() == 2, "Textes identiques sans lien explicite jamais fusionnés")
	var counts := Reading.counts([info,press,notice],model)
	check(counts.all == 3 and counts.waiting == 1 and counts.info == 2 and counts.todo == 0, "Compteurs issus seulement des courriers fournis")

func run() -> void:
	logic()
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await wait_worker(); app.timer.stop()
	app._command("new_career",{"mode":"common","club":0})
	await wait_worker()
	app._navigate("Réception"); await settle()
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(file)
	var sequence: int = app.bridge._next_id
	await capture("01-reception-tous")
	await activate("InboxActivity_todo")
	var state: Dictionary = app.Immersive.Reception._state(app)
	check(state.activity_filter == "todo", "Filtre À faire activé au clavier")
	await activate("InboxPressInvitation")
	var selected := str(state.selected)
	check(not selected.is_empty(), "Invitation sélectionnée explicitement")
	await capture("02-decision-presse")
	await activate("InboxOpenPressInvitation")
	check(app.route == "Presse", "La décision ouvre la conférence existante")
	await activate("PressBackToInvitation")
	check(app.route == "Réception" and state.selected == selected and state.activity_filter == "todo", "Retour à la même invitation et au même filtre")
	var focus := root.gui_get_focus_owner()
	check(focus != null and focus.get_meta("message_id", "") == selected, "Focus restitué au courrier d'origine")
	await activate("InboxActivity_info")
	var rows := app.find_child("InboxMessageRows",true,false)
	var buttons: Array = rows.get_children().filter(func(node): return node is Button and node.has_meta("message_id"))
	check(not buttons.is_empty(), "Informations réelles présentes")
	if buttons.size()>1:
		var next_id := str(buttons[1].get_meta("message_id"))
		buttons[0].grab_focus(); await key(KEY_DOWN)
		check(state.selected == next_id, "Flèche bas sélectionne le courrier suivant sans commande")
	await capture("03-informations")
	await activate("InboxActivity_waiting")
	check(app.find_child("InboxOpenPressInvitation",true,false) == null, "Aucune conférence disponible inventée dans En attente")
	await activate("InboxActivity_all")
	var expiry: Array = app.Immersive.Reception._messages(app).filter(func(message: Dictionary): return message.get("season_expiry",false))
	check(not expiry.is_empty(), "Courrier réel d'échéance disponible dans la carrière témoin")
	if not expiry.is_empty():
		state.selected = expiry[0].id
		app._render(); await settle()
		var person := app.find_child("InboxExpiryPlayer_0",true,false) as Button
		check(person != null and person.find_children("*","TextureRect",true,false).any(func(image): return image.texture != null), "Portrait chargé pour un joueur de l’effectif lié aux échéances actuelles")
		await capture("04-echeances-portraits")
		if person != null:
			var player_id := str(person.get_meta("player_id"))
			await activate("InboxExpiryPlayer_0")
			check(app.route == "Effectif" and app.selected_player == player_id, "Le portrait ouvre la bonne fiche par identifiant")
			app._navigate("Réception"); await settle()
			check(state.selected == expiry[0].id, "Retour de la fiche au même courrier d'échéance")
	# Controlled UI fixture only: the product still reads the engine projection.
	var original: Dictionary = app.model.duplicate(true)
	var notices: Array = app.model.get("calendarMail", []).duplicate(true)
	for index in 2:
		notices.append({"id":"qa-linked-"+str(index),"fixtureId":"qa-fixture","fromDate":"2026-09-12","toDate":"2026-09-13","opponent":"Adversaire de recette","status":"kept"})
	app.model.calendarMail = notices
	state.selected = "qa-linked-0"
	app._render(); await settle()
	var thread_id := "InboxThread_" + "fixture/qa-fixture".sha256_text().left(12)
	check(app.find_child(thread_id,true,false) != null, "Deux avis de même rencontre possèdent un groupe unique")
	await activate(thread_id)
	var hidden := app.find_children("*","Button",true,false).filter(func(button): return button.get_meta("message_id","") == "qa-linked-0")
	check(hidden.is_empty(), "Entrée replie les messages liés sans effacer leur détail")
	await activate(thread_id)
	check(app.find_children("*","Button",true,false).any(func(button): return button.get_meta("message_id","") == "qa-linked-0"), "Entrée rouvre le groupe et restitue ses messages")
	app.model = original
	app._render(); await settle()
	check(FileAccess.get_sha256(file) == before, "Lecture, filtres, ouverture et retour : profil sportif inchangé")
	check(app.bridge._next_id == sequence, "Parcours de lecture sans commande moteur supplémentaire")
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"resolution":[root.size.x,root.size.y]},"  ")); report.close()
	print("RÉCEPTION DÉCISIONS : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
