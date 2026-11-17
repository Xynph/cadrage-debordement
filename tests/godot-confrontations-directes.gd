extends SceneTree
## Préparation du match (profil préparé par tests/godot-confrontations.cjs) : pastilles V/N/D de la forme
## adverse dans « Les faits récents », une par rencontre listée. Capture 1920×1080 en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_CONFR_OUTPUT")
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

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	app._navigate("Préparation"); await poser(20)
	var panneau := app.find_child("PreparationRecent", true, false)
	verifier(panneau != null, "panneau des faits récents")
	var pastilles: Array = []
	if panneau != null:
		for i in 5:
			var chip := panneau.find_child("PreparationHeadToHead%d" % i, true, false)
			if chip == null: break
			var texte := ""
			for l: Node in chip.find_children("*", "Label", true, false): texte += (l as Label).text
			verifier(texte in ["V", "N", "D"], "pastille %d : « %s »" % [i, texte])
			pastilles.append(texte)
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("preparation-confrontations.png")) == OK, "capture")
	print("CONFR ", JSON.stringify({"controles": controles, "failures": echecs, "pastilles": pastilles}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
