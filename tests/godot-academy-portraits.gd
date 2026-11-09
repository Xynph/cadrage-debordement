extends SceneTree
const Regen = preload("res://ui/regen_portrait.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Commande " + id)
	await settle()
func portrait_probe(helper: Control, person: Dictionary, large: bool, packed: bool) -> void:
	var panel := Control.new(); root.add_child(panel)
	helper._portrait(panel, person, Rect2(0,0,180,220), large)
	var photos := panel.find_children("*", "TextureRect", true, false)
	check(not photos.is_empty(), "Portrait créé")
	if not photos.is_empty():
		var photo: TextureRect = photos[0]
		check(photo.texture != null and (photo.material == null if packed else photo.material != null), "Priorité pack / composition locale " + str(large))
		if not packed: check(photo.texture == Regen.texture(person), "Même visage déterministe en vignette et dossier")
	check((panel.find_child("AcademyPortraitIllustration",true,false) != null) == (large and not packed), "Badge fictif seulement sur grand portrait composé")
	panel.queue_free(); await settle()
func run() -> void:
	root.size = Vector2i(1280,800)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await command("snapshot")
	await command("new_career", {"mode":"common","club":0})
	var people: Array = app.model.decisions.development.academy
	check(not people.is_empty(), "Vrais académiciens projetés par le worker")
	if people.is_empty(): finish(); return
	var source: Dictionary = people[0].duplicate(true)
	var profile: Dictionary = Regen.describe(source)
	await command("export")
	var before: String = app.model.meta.exportText
	var save: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(save)
	for resolution in [Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size = resolution; await settle(); app._navigate("Formation"); await settle()
		var found := false
		for photo: TextureRect in app.body.find_children("*","TextureRect",true,false):
			if photo.texture == Regen.texture(source) and photo.material != null: found = true
		check(found, "Visage du vrai académicien dans Formation " + str(resolution.x))
		check((app.body.find_child("ImmersiveAcademy",true,false) != null) == (resolution.x == 1920), "Branches compact/immersif réellement exercées")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("CD_ACADEMY_CAPTURES").path_join("academy-%d.png" % resolution.x)) == OK, "Capture académie")
	var helper := Academy.new(); helper.app = app
	for large in [false,true]:
		await portrait_probe(helper, source, large, false)
		var packed := source.duplicate(true)
		packed.identity = {"portraitPath":ProjectSettings.globalize_path("res://art/regen-staff-atlas.png"),"portraitStatus":"official"}
		await portrait_probe(helper, packed, large, true)
		var missing := source.duplicate(true); missing.portraitPath = "/missing/academy-pack.png"
		await portrait_probe(helper, missing, large, false)
	var anonymous := Control.new(); root.add_child(anonymous)
	helper._portrait(anonymous, {}, Rect2(0,0,180,220), true)
	var illustration := anonymous.find_children("*","TextureRect",true,false)
	check(not illustration.is_empty() and illustration[0].material == null, "Sans identité : illustration générique, sans visage attribué")
	check(anonymous.find_child("AcademyPortraitIllustration",true,false) != null, "Sans identité : illustration explicitement signalée")
	anonymous.queue_free(); await settle()
	helper.free()
	await command("export")
	check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(save) == bytes, "Affichage sans mutation sauvegarde/RNG/disque")
	await command("promote_academy", {"playerId":source.id,"confirmed":true})
	var promoted: Dictionary = {}
	for person: Dictionary in app.model.squad:
		if str(person.id) == str(source.id): promoted = person
	check(not promoted.is_empty(), "Promotion réelle conserve ID de l’académicien")
	if not promoted.is_empty(): check(Regen.describe(promoted) == profile, "Promotion réelle conserve exactement le profil de visage")
	var changed := source.duplicate(true); changed.name = "Autre nom"; changed.clubId = 29
	check(Regen.describe(changed) == profile, "Nom et club ne modifient pas le visage")
	var staff := {"id":"staff-conversion-probe","sourcePlayerId":source.id,"portraitRole":"staff","appearanceAge":source.age,"age":49}
	var future: Dictionary = Regen.describe(staff)
	for key in profile:
		if key not in ["maturity","referenceAge","ageBasis"]: check(future[key] == profile[key], "Contrat reconversion préserve " + str(key))
	finish()
func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
