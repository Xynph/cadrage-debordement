extends SceneTree
## Bureau (profil préparé par tests/godot-objectif-bureau.cjs) : pastille de l'objectif du conseil en tête
## de la carte du classement, sans chevaucher le titre ni sortir de la carte. Capture 1920×1080 en graphique.
var app: Control
var sortie := OS.get_environment("CD_OBJECTIF_OUTPUT")
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
	app._navigate("Bureau"); await poser(20)
	var carte := app.find_child("OfficeStandings", true, false) as Control
	verifier(carte != null, "carte du classement")
	var texte := ""
	if carte != null:
		var chip := carte.find_child("OfficeBoardObjective", true, false) as Control
		verifier(chip != null, "pastille de l'objectif")
		if chip != null:
			for l: Node in chip.find_children("*", "Label", true, false): texte += (l as Label).text
			var zone := chip.get_global_rect()
			verifier(carte.get_global_rect().encloses(zone), "pastille dans la carte")
			for l: Node in carte.get_children():
				if l is Label and (l as Label).text.begins_with("CLASSEMENT"):
					# Largeur réelle du texte (le titre est tronqué par une ellipse : sa taille minimale ne dit rien).
					var titre := l as Label
					var echelle := titre.get_global_transform().get_scale().x
					var largeur := titre.get_theme_font("font").get_string_size(titre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, titre.get_theme_font_size("font_size")).x * echelle
					verifier(titre.global_position.x + largeur <= zone.position.x and titre.global_position.x + titre.size.x * echelle <= zone.position.x, "titre non chevauché (%s)" % titre.text)
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("bureau-objectif.png")) == OK, "capture")
	print("OBJECTIF ", JSON.stringify({"controles": controles, "failures": echecs, "texte": texte}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
