extends SceneTree
## Réception : courrier du président (prêt de l'actionnaire, deux réponses) et du nouvel actionnaire ; Finances >
## Classement avec le nouveau propriétaire (profil préparé par tests/godot-argent-proprietaire.cjs, vrai moteur).
var app: Control
var sortie := OS.get_environment("CD_PROPRIO_OUTPUT")
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

func mail(type: String) -> Dictionary:
	for m: Dictionary in app.model.get("clubLife", {}).get("clubMail", {}).get("mails", []):
		if str(m.get("type", "")) == type: return m
	return {}

func ouvrir(type: String) -> Dictionary:
	var m := mail(type)
	verifier(not m.is_empty(), "courrier " + type + " dans le modèle")
	if m.is_empty(): return m
	app._reset_reception(str(m.id))
	app._navigate("Réception", false)
	await poser(24)
	verifier(app.root_content.find_child("InboxClubMail_" + str(m.id).replace("-", "_"), true, false) != null, "courrier rangé dans la Réception : " + str(m.sujet))
	return m

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var pret := await ouvrir("pret_actionnaire")
	if not pret.is_empty():
		verifier(str(pret.corps).contains("prêt") and str(pret.corps).contains("acheteur"), "corps du courrier : prêt et vente proposée")
		for id in ["accepter", "vendre"]:
			var b := app.root_content.find_child("InboxClubMailReply_" + id, true, false) as Button
			verifier(b != null and not b.disabled, "réponse « %s » possible" % id)
	await capturer("pret-courrier.png")
	var arrivee := await ouvrir("proprietaire_arrivee")
	if not arrivee.is_empty(): verifier(str(arrivee.expediteur) == "Le nouvel actionnaire", "expéditeur du nouvel actionnaire")
	await capturer("proprietaire-courrier.png")
	app.management_ui["immersive08_finance_tab"] = "clubs"
	app._navigate("Finances"); await poser(20)
	var health: Dictionary = app.model.get("finance", {}).get("health", {})
	verifier(str(health.get("proprietaire", {}).get("type", "")) == "mecene", "le club joué appartient à un mécène : " + str(health))
	await capturer("proprietaire-classement.png")
	print("PROPRIO ", JSON.stringify({"controles": controles, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
