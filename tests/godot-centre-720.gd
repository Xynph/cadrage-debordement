extends SceneTree
## Centre de formation en 1280 × 720 (profil Monde préparé par tests/godot-centre-720.cjs) : les pastilles
## « AU CALENDRIER DES ESPOIRS » tiennent sans points de suspension et le bloc « SAISON JUNIOR » suit
## directement les tuiles du tableau du centre (pas de bande vide). Captures en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_CENTRE_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var mesures := {}

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

func tient(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.5

func controler(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(4)
	app._navigate("Centre"); await poser(20)
	var page := app.find_child("ImmersiveCentre", true, false) as Control
	var cle := "%dx%d" % [taille.x, taille.y]
	verifier(page != null and page.is_visible_in_tree(), cle + " : page riche du Centre")
	if page == null: return
	var pastilles := 0
	for noeud: Node in page.find_children("*", "Label", true, false):
		var label := noeud as Label
		if label.text != "AU CALENDRIER DES ESPOIRS": continue
		pastilles += 1
		verifier(tient(label), cle + " : pastille « %s » tronquée (%s px pour %s px)" % [label.text, label.size.x, label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x])
		var carte := label.get_parent().get_parent() as Control
		if carte != null: verifier(carte.get_global_rect().encloses(label.get_parent().get_global_rect()), cle + " : pastille dans sa carte")
	var statut := page.find_child("CentreStatus", true, false) as Control
	verifier(statut != null, cle + " : tableau du centre")
	if statut != null:
		var saison: Label = null
		var bas_tuiles := -1.0
		for noeud: Node in statut.find_children("*", "Label", true, false):
			if (noeud as Label).text == "SAISON JUNIOR": saison = noeud
		for enfant: Node in statut.get_children():
			if enfant is Panel and (enfant as Control).get_global_rect().position.y < statut.get_global_rect().position.y + statut.size.y * .45:
				bas_tuiles = maxf(bas_tuiles, (enfant as Control).get_global_rect().end.y)
		verifier(saison != null, cle + " : titre SAISON JUNIOR")
		if saison != null and bas_tuiles > 0:
			var ecart := saison.get_global_rect().position.y - bas_tuiles
			mesures[cle] = {"pastilles": pastilles, "ecart_saison_px": snappedf(ecart, .1), "hauteur": taille.y}
			# Ligne et titre sous les tuiles : ≈ 75 unités du gabarit ; une bande vide d'une rangée en ajouterait 108.
			verifier(ecart <= 110.0 * C_density(), cle + " : vide de %s px au-dessus de SAISON JUNIOR" % snappedf(ecart, .1))
	await poser(10)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("centre-%s.png" % cle)) == OK, "capture " + cle)

func C_density() -> float:
	return float(load("res://ui/immersive08/components.gd").get("density"))

func executer() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	await controler(Vector2i(1280, 720))
	await controler(Vector2i(1920, 1080))
	print("CENTRE ", JSON.stringify({"controles": controles, "mesures": mesures, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
