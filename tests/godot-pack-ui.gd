extends SceneTree

var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		quit(2)
		return
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := button(child, label)
		if found != null: return found
	return null

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 15000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Moteur natif connecté")
	app._navigate("Création")
	await process_frame
	var import_button := button(app, "PACKS ET IDENTITÉS")
	check(import_button != null, "Création : commande visible des packs personnalisés")
	if import_button != null:
		import_button.pressed.emit()
		await process_frame
		check(app.route == "Packs", "Création : vraie commande ouvre les packs")
		check(button(app, "IMPORTER UN PACK ZIP") != null, "Packs : sélecteur ZIP disponible")
		check(button(app, "UTILISER LA BASE ANONYMISÉE") != null, "Packs : retour explicite à la base")
	var skin = load("res://ui/game_skin.gd")
	var badge: Control = skin.crest({"abbr":"QA","logoPath":OS.get_environment("CD_GODOT_PACK_TEST_IMAGE")}, 56)
	check(badge is TextureRect and badge.texture != null, "Blason : image du pack chargée depuis le profil")
	badge.free()
	var path := OS.get_environment("CD_GODOT_PACK_TEST_IMAGE")
	var official: TextureRect = skin.portrait(0, 90, {"portraitPath":path,"portraitStatus":"official"})
	var synthetic: TextureRect = skin.portrait(1, 90, {"portraitPath":path,"portraitStatus":"synthetic"})
	check(official.texture is ImageTexture and official.texture.get_size().x <= 512, "Portrait du pack décodé et texture bornée")
	check(official.tooltip_text.begins_with("Photo officielle"), "Photo officielle identifiée")
	check(synthetic.tooltip_text.begins_with("Illustration IA"), "Illustration IA identifiée séparément")
	check(official.texture == synthetic.texture, "Texture partagée entre vues, sans duplication")
	var absent: TextureRect = skin.portrait(3, 90, {"portraitPath":path+".missing","portraitStatus":"official"})
	check(absent.tooltip_text.begins_with("Image du pack indisponible"), "Image absente : repli fictif explicitement signalé")
	official.free()
	synthetic.free()
	absent.free()
	app.bridge.stop()
	deadline = Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Moteur fermé proprement")
	print(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
