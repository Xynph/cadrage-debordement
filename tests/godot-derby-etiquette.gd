extends SceneTree
## Étiquette « Derby » (profil préparé par tests/godot-derby-etiquette.cjs : prochain match = derby) : pastille dorée
## « DERBY » au Bureau, sur l'écran Composition et en Préparation. Capture 1920×1080 en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_DERBY_OUTPUT")
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

func texte_de(noeud: Node) -> String:
	var texte := ""
	for l: Node in noeud.find_children("*", "Label", true, false): texte += (l as Label).text
	return texte

func controler(page: String, fichier: String) -> void:
	app._navigate(page); await poser(20)
	var tag := app.find_child("DerbyTag", true, false)
	verifier(tag != null, page + " : pastille DerbyTag")
	if tag != null:
		verifier(texte_de(tag) == "DERBY", page + " : texte « %s »" % texte_de(tag))
		verifier((tag as Control).is_visible_in_tree(), page + " : pastille visible")
	await poser(10)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(fichier)) == OK, "capture " + fichier)

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var derby: Variant = app.model.get("next", {}).get("derby") if app.model.get("next") is Dictionary else null
	verifier(derby is Dictionary and int(derby.get("tension", 0)) >= 60, "next.derby projeté par le moteur : " + str(derby))
	await controler("Bureau", "derby-bureau.png")
	await controler("Composition", "derby-composition.png")
	await controler("Préparation", "derby-preparation.png")
	print("DERBY ", JSON.stringify({"controles": controles, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
