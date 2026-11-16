extends SceneTree
## Courrier du club (native/engine/club-mail.cjs, ui/club_mail.gd), Godot réel + worker réel, carrière Monde
## (world-champ) partie de la veille de la saison :
## - un jour de calendrier plus tard, des mails du club sont en Réception ; l'un appelle une réponse ;
## - le clic sur une réponse l'affiche tout de suite (décision optimiste), le moteur la confirme (meta.clubMailReply)
##   et le mail n'offre plus de réponse ; le bouton « Ouvrir » mène à l'écran concerné ;
## - arrêts informatifs de « Continuer » : veille -> Composition, rapport médical -> Effectif filtré sur les
##   blessés, courrier -> le mail sélectionné en Réception.
## Imprime une ligne COURRIER {checks, failures}.
const Flow = preload("helpers/contextual_flow.gd")
const ClubMail = preload("res://ui/club_mail.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 4) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

func button(name: String) -> Button:
	return app.root_content.find_child(name, true, false) as Button if is_instance_valid(app.root_content) else null

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	check(app.model.get("club") is Dictionary, "Carrière Monde créée")
	await reply_and_open()
	await info_stops()
	print("COURRIER ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Un jour plus tard : un mail qui appelle une réponse, réponse au clic, puis écran concerné.
func reply_and_open() -> void:
	var mail: Dictionary = {}
	for day in 4:
		for item: Dictionary in ClubMail.mails(app.model):
			if ClubMail.awaiting(app.model, item) and (item.reponses as Array).any(func(r: Dictionary) -> bool: return r.disponible):
				mail = item
		if not mail.is_empty(): break
		await command("advance_day", {"fromDate": app.model.meta.calendarToday})
		await Flow.settle_club_meetings(app, self, check)
	check(not mail.is_empty(), "Un mail du club attend une réponse")
	if mail.is_empty(): return
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await settle()
	var row := app.root_content.find_child("InboxClubMail_" + str(mail.id).replace("-", "_"), true, false)
	check(row != null, "Mail rangé dans la Réception · " + str(mail.sujet))
	var option: Dictionary = (mail.reponses as Array).filter(func(r: Dictionary) -> bool: return r.disponible)[0]
	var reply := button("InboxClubMailReply_" + str(option.id))
	check(reply != null and not reply.disabled, "Bouton de réponse « " + str(option.libelle) + " »")
	if reply == null: return
	check(not str(reply.tooltip_text).is_empty(), "Conséquences annoncées en info-bulle")
	reply.pressed.emit()
	await process_frame
	check(str(app.model.get("clubLife", {}).get("clubMail", {}).get("reponses", {}).get(str(mail.id), "")) == str(option.id), "Réponse affichée dès le clic")
	await wait_engine()
	var receipt: Variant = app.model.get("meta", {}).get("clubMailReply")
	check(receipt is Dictionary and receipt.get("choice") == option.id, "Réponse confirmée par le moteur")
	if app.route != "Réception":
		app._navigate("Réception", false)
		await settle()
	check(button("InboxClubMailReply_" + str(option.id)) == null, "Plus de réponse proposée une fois répondu")
	var open := button("InboxClubMailOpen")
	check(open != null and str(open.text).begins_with("Ouvrir"), "Bouton vers l’écran concerné")
	if open == null: return
	var expected := ClubMail.route_of(str(mail.ecran))
	open.pressed.emit()
	await settle()
	if str(mail.ecran) != "fiche": check(app.route == expected, "Écran concerné ouvert : " + expected + " (actuel : " + app.route + ")")

## Arrêts informatifs : écran utile préparé pour la réponse de « Continuer ».
func info_stops() -> void:
	check(ClubMail.stop_route(app, {"kind":"info", "type":"veille", "ecran":"Composition"}) == "Composition", "Veille de match : composition")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"medical", "ecran":"infirmerie"}) == "Effectif", "Rapport médical : effectif")
	check(str(app.management_ui.get("roster", {}).get("available", "")) == "Blessés", "Rapport médical : filtre des blessés")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"mi_saison", "ecran":"Classements"}) == "Classements", "Mi-saison : classement")
	check(ClubMail.stop_route(app, {"kind":"info", "type":"mercato", "ecran":"Recrutement"}) == "Recrutement", "Marché : recrutement")
	var mails := ClubMail.mails(app.model)
	if not mails.is_empty():
		check(ClubMail.stop_route(app, {"kind":"info", "type":"courrier", "ecran":"Réception", "mail":str(mails[0].id)}) == "Réception", "Courrier : Réception")
		check(str(app.management_ui.reception.selected) == str(mails[0].id), "Courrier : le mail est sélectionné")
