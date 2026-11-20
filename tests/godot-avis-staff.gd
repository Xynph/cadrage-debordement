extends SceneTree
## Composition (profil préparé par tests/godot-avis-staff.cjs) : bandeau « Avis du staff » avec au moins une
## ligne, repère « ! » sur le poste contesté. Capture 1920×1080 en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_AVIS_OUTPUT")
var poste := int(OS.get_environment("CD_AVIS_POSTE"))
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
	app._navigate("Composition"); await poser(20)
	var bandeau := app.find_child("TacticsStaffAdvice", true, false)
	verifier(bandeau != null, "bandeau de l'avis du staff")
	var lignes: Array = []
	if bandeau != null:
		for i in 4:
			# Bulle de Gabi (Composition du 19/11) : chaque conseil est un bloc dont les noms ouvrent la fiche.
			var l := bandeau.find_child("TacticsStaffAdvice%d" % i, true, false) as Control
			if l == null: break
			verifier(l.tooltip_text.begins_with("Ton "), "texte complet au tutoiement : « %s »" % l.tooltip_text)
			verifier(not l.find_children("*Nom*", "Button", true, false).is_empty(), "noms du conseil cliquables")
			lignes.append(str(l.get_meta("court", "")))
	verifier(not lignes.is_empty(), "au moins un conseil affiché")
	verifier(app.find_child("TacticsStaffAdviceMark%02d" % (poste + 1), true, false) != null, "repère sur le poste contesté")
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("composition-avis-staff.png")) == OK, "capture")
	print("AVIS ", JSON.stringify({"controles": controles, "failures": echecs, "lignes": lignes}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
