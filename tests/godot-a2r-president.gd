extends SceneTree
## Courriers de l'A2R et du président en Réception (profil préparé par tests/godot-a2r-president.cjs, vrai moteur) :
## décision « apport exigé » avec ses réponses, réponse « Demander l'apport au propriétaire » et verdict, puis courrier
## du président qui désigne les joueurs à vendre. Captures 1920×1080 en affichage graphique.
const ClubMail = preload("res://ui/club_mail.gd")
var app: Control
var sortie := OS.get_environment("CD_A2R_OUTPUT")
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
	if noeud == null: return t
	for n in noeud.find_children("*", "Label", true, false): t += (n as Label).text + "\n"
	for n in noeud.find_children("*", "RichTextLabel", true, false): t += (n as RichTextLabel).get_parsed_text() + "\n"
	return t

func mail_de(type: String) -> Dictionary:
	for m: Dictionary in ClubMail.mails(app.model):
		if str(m.get("type", "")) == type: return m
	return {}

func ouvrir(mail: Dictionary) -> void:
	app._reset_reception(str(mail.id))
	app._navigate("Réception", false)
	await poser(20)

func bouton(nom: String) -> Button:
	return app.root_content.find_child(nom, true, false) as Button if is_instance_valid(app.root_content) else null

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var a2r := mail_de("a2r_apport")
	verifier(not a2r.is_empty(), "courrier de l’A2R dans la Réception")
	var lu_a2r := ""
	if not a2r.is_empty():
		await ouvrir(a2r)
		lu_a2r = textes(app.root_content.find_child("InboxDetail", true, false))
		verifier(lu_a2r.contains("A2R") and lu_a2r.contains("30 juin"), "texte de la décision : « %s »" % lu_a2r.left(400))
		for id in ["apport", "appel", "acte"]: verifier(bouton("InboxClubMailReply_" + id) != null, "réponse « %s » proposée" % id)
		await capturer("a2r-courrier.png")
		var apport := bouton("InboxClubMailReply_apport")
		if apport != null:
			apport.pressed.emit()
			await attendre_moteur()
			var envoi := bouton("InboxClubMailSend")
			verifier(envoi != null and not envoi.disabled, "un clic choisit la réponse, « Envoyer la réponse » la confirme")
			if envoi != null: envoi.pressed.emit()
			await attendre_moteur()
			var recu: Variant = app.model.get("meta", {}).get("clubMailReply")
			verifier(recu is Dictionary and recu.get("choice") == "apport", "réponse confirmée par le moteur")
			await ouvrir(mail_de("a2r_apport"))
			var verdict := textes(app.root_content.find_child("InboxDetail", true, false))
			verifier(verdict.contains("propriétaire"), "verdict du propriétaire affiché : « %s »" % verdict.left(500))
			await capturer("a2r-reponse.png")
	var pres := mail_de("reprise_president")
	verifier(not pres.is_empty(), "courrier du président dans la Réception")
	var lu_pres := ""
	if not pres.is_empty():
		await ouvrir(pres)
		lu_pres = textes(app.root_content.find_child("InboxDetail", true, false))
		verifier(lu_pres.contains("réserve"), "texte du président : « %s »" % lu_pres.left(400))
		for id in ["lister", "confier", "delai"]: verifier(bouton("InboxClubMailReply_" + id) != null, "réponse « %s » proposée" % id)
		await capturer("president-courrier.png")
	print("A2R ", JSON.stringify({"controles": controles, "failures": echecs, "a2r": lu_a2r.left(300), "president": lu_pres.left(300)}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
