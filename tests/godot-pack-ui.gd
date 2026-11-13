extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")

var app: Control
var failures: Array[String] = []
var checks := 0
var capture_index := 0

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
	# AcceptDialog owns native internal buttons; they are real user controls too.
	for child in node.get_children(true):
		var found := button(child, label)
		if found != null: return found
	return null

func wait_response(expected_ok: bool = true) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting, "Commande terminée dans le délai borné")
	check(app.bridge.last_response_ok == expected_ok, "Réponse native attendue : " + app.last_command + " / " + app.last_error)

func press(label: String) -> void:
	var control := button(app, label)
	check(control != null and control.visible and not control.disabled, "Commande utilisable : " + label)
	if control != null and not control.disabled: control.pressed.emit()

func press_entry(id: String) -> void:
	var control := app.find_child(id, true, false) as Button
	var usable := control != null and control.is_visible_in_tree() and not control.disabled
	check(usable, "Commande d’accueil utilisable : " + id)
	if usable: control.pressed.emit()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var folder := OS.get_environment("CD_GODOT_PACK_QA_CAPTURES")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(folder.path_join(label+".png")) == OK, "Capture graphique : " + label)
	capture_index += 1

func configure_resolution() -> void:
	var requested := OS.get_environment("QA_RESOLUTION")
	if requested.is_empty(): return
	var dimensions := requested.to_lower().replace("×", "x").split("x")
	var valid := dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int() and int(dimensions[0]) > 0 and int(dimensions[1]) > 0
	check(valid, "QA_RESOLUTION indique largeurxhauteur")
	if not valid: return
	var target := Vector2i(int(dimensions[0]), int(dimensions[1]))
	# Keep the requested client area through each real application restart.
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	root.size = target
	await process_frame
	check(root.size == target and app.size == Vector2(target), "Packs : vraie fenêtre et interface à " + str(target))
	print("PACK_NATIVE_GEOMETRY ", JSON.stringify({"window":str(root.size), "canvas":str(app.size)}))

func sports(state: Dictionary) -> String:
	var copy := state.duplicate(true)
	copy.erase("identityPack")
	return JSON.stringify(copy)

func import_archive(path: String, expected_ok: bool = true) -> void:
	press("Importer une autre réalité")
	await process_frame
	check(app.pack_manager.picker.visible, "Vrai sélecteur de fichiers ZIP ouvert")
	check("*.zip" in str(app.pack_manager.picker.filters), "Sélecteur limité aux archives ZIP")
	app.pack_manager.picker.file_selected.emit(path)
	app.pack_manager.picker.hide()
	await wait_response(expected_ok)

func integration() -> void:
	var archive := OS.get_environment("CD_GODOT_PACK_ARCHIVE")
	if archive.is_empty(): return
	await import_archive(archive)
	var preview: Dictionary = app.model.get("packs", {}).get("preview", {})
	check(not preview.is_empty(), "Analyse réelle du ZIP fourni")
	if preview.is_empty(): return
	check(int(preview.get("counts", {}).get("players", 0)) == 1592, "Aperçu des1592identités")
	check(int(preview.get("counts", {}).get("synthetic", 0)) == 43, "Aperçu distingue les43illustrations IA")
	check(not app._has_career(), "Analyse : aucune création implicite de carrière")
	await capture("pack-analyse")
	press("INSTALLER CE PACK")
	await wait_response()
	check(app.model.packs.installed.size() == 1, "Pack installé et listé")
	if app.model.packs.installed.size() != 1: return
	var pack_id: String = str(app.model.packs.installed[0].id)
	press("UTILISER CE PACK  →")
	await wait_response()
	check(app.model.packs.creation == pack_id, "Choix du pack pour nouvelle carrière")
	app.selected_club = 23
	app.club_division = "accession"
	press("← Retour")
	await process_frame
	check(app.route == "Création", "Retour à la sélection de club")
	check(str(app.catalogue[23].name) == "SU Agen", "Noms réels visibles avant création")
	await capture("creation-rugby-reel")
	press("PRENDRE LES RÊNES DE " + str(app.catalogue[23].abbr) + "  →")
	await wait_response()
	check(app.model.meta.database.active and int(app.model.club.id) == 23, "Vraie carrière commune créée depuis le bouton")
	if not app._has_career(): return
	if not await ContextualFlow.settle_club_meetings(app, self, check): return
	check("30 CLUBS" in app.minibar.text and not "14 CLUBS" in app.minibar.text, "En-tête de carrière : trente clubs annoncés")
	check(app.model.packs.career == pack_id, "Carrière hérite du pack choisi")
	app._navigate("Effectif")
	app.selected_player = "lnr:14090"
	app._render()
	await capture("effectif-illustration-ia")
	var synthetic: Dictionary = {}
	for player: Dictionary in app.model.squad:
		if str(player.id) == "lnr:14090": synthetic = player
	check(synthetic.get("portraitStatus", "") == "synthetic", "Portrait IA réellement lié au bon joueur par ID")
	check(str(synthetic.get("name", "")) == "Camille GERMAIN", "Identité réelle du joueur illustré")
	app.selected_player = "lnr:12453"
	app._render()
	await capture("effectif-photo-officielle")
	app._command("export")
	await wait_response()
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText)
	app.settings()
	press("Packs et identités")
	await process_frame
	check(app.route == "Packs" and app.pack_manager.scope == "career", "Paramètres : deuxième entrée fonctionnelle des packs")
	press("Choisir le jeu de base")
	await wait_response()
	check(app.model.packs.career == "base" and app.model.packs.creation == pack_id, "Choix carrière indépendant du choix de création")
	app._command("export")
	await wait_response()
	var after: Dictionary = JSON.parse_string(app.model.meta.exportText)
	check(sports(before.state) == sports(after.state), "Bascule : joueurs/attributs/contrats/résultats intégralement identiques")
	press("UTILISER CE PACK  →")
	await wait_response()
	check(app.model.packs.career == pack_id, "Réactivation du pack en carrière")
	await capture("pack-actif-carriere")
	var custom_path := OS.get_environment("CD_GODOT_CUSTOM_PACK")
	if not custom_path.is_empty():
		await import_archive(custom_path)
		var custom: Dictionary = app.model.packs.get("preview", {})
		check(custom.get("name", "") == "Mon univers", "Paramètres : analyse du pack personnalisé")
		if not custom.is_empty():
			press("INSTALLER CE PACK")
			await wait_response()
			check(app.model.packs.installed.size() == 2, "Deuxième import installé depuis les paramètres")
			check(app.model.packs.career == pack_id, "Installer un pack ne remplace pas la carrière ni son choix")
			press("UTILISER CE PACK  →")
			await wait_response()
			check(app.model.packs.career == custom.id and app.model.club.name == "Agen des Rives", "Pack personnalisé appliqué par le vrai bouton")
			app._command("export")
			await wait_response()
			var personalized: Dictionary = JSON.parse_string(app.model.meta.exportText)
			check(sports(before.state) == sports(personalized.state), "Personnalisation : progression et statistiques conservées")
			await capture("pack-personnalise")
			press("UTILISER CE PACK  →")
			await wait_response()
			check(app.model.packs.career == pack_id, "Retour réel après le pack personnalisé")
	app.pack_manager.back()
	await process_frame
	await capture("effectif-reel-retour")

func text_visible(node: Node, part: String) -> bool:
	if node is Label and part.to_lower() in node.text.to_lower() and node.is_visible_in_tree(): return true
	for child in node.get_children():
		if text_visible(child, part): return true
	return false

func stop_app() -> void:
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Profil de test fermé proprement")
	root.remove_child(app)
	app.queue_free()
	await process_frame

func start_app(profile: String) -> void:
	OS.set_environment("CD_GODOT_DATA_DIR", profile)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await configure_resolution()
	app.pack_manager.creation_mode = "common"
	var deadline := Time.get_ticks_msec() + 15000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Profil de test connecté")
	app.timer.stop()

func pack_edge_cases() -> void:
	var profile := OS.get_environment("CD_GODOT_DATA_DIR").path_join("edgecases/PrototypeGodot")
	var valid := OS.get_environment("CD_GODOT_PACK_EDGE_VALID")
	await stop_app()
	await start_app(profile)
	app._navigate("Création")
	press("PACKS ET IDENTITÉS")
	await import_archive(valid)
	var preview: Dictionary = app.model.packs.preview
	check(button(app, "INSTALLER CE PACK") != null, "ZIP A valide : aperçu installable")
	check(button(app, "Nouvelle carrière") == null, "L’aperçu seul ne permet pas de continuer avec le pack")
	await import_archive(OS.get_environment("CD_GODOT_PACK_EDGE_INVALID"), false)
	check(app.model.packs.preview == null, "ZIP B refusé : ancien aperçu effacé")
	check(button(app, "INSTALLER CE PACK") == null and not text_visible(app, "PRÊT À INSTALLER"), "ZIP B refusé : aucun ancien contrôle installable")
	app._clear_dialogs()
	await process_frame
	await import_archive(valid)
	check(app.model.packs.preview.digest == preview.digest, "Nouvelle analyse A : empreinte correcte restaurée")
	press("INSTALLER CE PACK")
	await wait_response()
	check(app.model.packs.creation == "base", "Installer conserve le choix de création")
	await capture("pack-installe-creation")
	press("Nouvelle carrière")
	await wait_response()
	check(app.route == "Création" and app.model.packs.creation == preview.id and not app._has_career(), "Le bouton sélectionne le pack installé puis ouvre le choix du club")
	if app.route != "Création": return
	press("PACKS ET IDENTITÉS")
	await capture("pack-actif-creation")
	press("Nouvelle carrière")
	check(app.route == "Création" and not app.waiting, "Le pack déjà actif ouvre directement la création")
	press("PRENDRE LES RÊNES DE REC  →")
	await wait_response()
	# Finish the actual mandatory opening appointments before freezing S/RNG.
	# Reopening/importing this fixture must test pack fallback, with no pending
	# club appointment legitimately locking navigation or pack selection.
	if not await ContextualFlow.settle_club_meetings(app, self, check): return
	app._command("export")
	await wait_response()
	var exported: String = app.model.meta.exportText
	var before: Dictionary = JSON.parse_string(exported)
	var pack_id: String = app.model.packs.career
	var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("donnees.json"))).seed
	await stop_app()
	check(DirAccess.rename_absolute(profile.path_join("packs"), profile.path_join("packs-held")) == OK, "Pack retiré après fermeture du profil")
	await start_app(profile)
	check(app.route == "Accueil" and text_visible(app, "pack de carrière absent"), "Redémarrage : repli annoncé dès l’accueil")
	await capture("pack-manquant-accueil")
	press_entry("EntryPacks")
	check(app.route == "Packs" and app.pack_manager.scope == "career", "Avertissement accueil : accès au pack de carrière")
	check(button(app, "Nouvelle carrière") == null, "L’atelier de la carrière ouverte conserve ses propres actions")
	press("← Retour")
	press_entry("EntryResume")
	check(app.route == "Réception", "Reprise : la vraie réception s’ouvre depuis l’accueil")
	check(text_visible(app, "pack de carrière absent"), "Reprise : repli annoncé dans la réception")
	check(app.model.packs.career == pack_id and app.model.packs.creation == pack_id, "Reprise : liaison et préférence absentes conservées")
	for attempt in range(2):
		app._command("snapshot")
		await wait_response()
	var visible_dialogs := 0
	for child in app.get_children():
		if child is AcceptDialog and child.visible: visible_dialogs += 1
	check(visible_dialogs == 0, "Pack absent : snapshots répétés sans dialogue intrusif")
	await capture("pack-manquant-bureau")
	app._command("export")
	await wait_response()
	check(JSON.parse_string(app.model.meta.exportText).state == before.state, "Reprise sans pack : S intégralement conservé")
	check(JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("donnees.json"))).seed == seed, "Reprise sans pack : RNG conservé")
	app._navigate("Création")
	check(text_visible(app, "PACK INDISPONIBLE"), "Création : préférence absente explicitement affichée")
	check(text_visible(app, "pack de création absent"), "Création : repli et choix nécessaire annoncés")
	await capture("pack-manquant-creation")
	check(button(app, "PRENDRE LES RÊNES DE " + str(app.catalogue[0].abbr) + "  →").disabled, "Création : démarrage bloqué jusqu’au choix effectif")
	press("Jeu de base")
	await wait_response()
	check(app.model.packs.creation == "base" and app.model.packs.career == pack_id, "Choix Base explicite : seule la préférence de création change")
	app._command("export")
	await wait_response()
	check(JSON.parse_string(app.model.meta.exportText).state == before.state, "Choix Base création : S et liaison carrière conservés")
	check(JSON.parse_string(FileAccess.get_file_as_string(profile.path_join("donnees.json"))).seed == seed, "Choix Base création : RNG conservé")
	var save_path := profile.path_join("career.json")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(exported)
	file.close()
	await stop_app()
	await start_app(profile.path_join("import-profile"))
	press_entry("EntryImportCareer")
	check(app.file_dialog.visible, "Import sans pack : vrai sélecteur ouvert")
	app.file_dialog.hide()
	app.file_dialog.file_selected.emit(save_path)
	press("CONFIRMER")
	await wait_response()
	check(app.route == "Réception", "Import sans pack : la vraie réception s’ouvre après confirmation")
	check(text_visible(app, "pack de carrière absent"), "Import sans pack : repli annoncé dans la réception")
	check(app.model.packs.career == pack_id, "Import sans pack : liaison conservée")
	await capture("pack-manquant-import")
	app._command("export")
	await wait_response()
	check(JSON.parse_string(app.model.meta.exportText).state == before.state, "Import sans pack : S conservé")
	press("GÉRER LES PACKS")
	check(app.route == "Packs" and app.pack_manager.scope == "career", "Avertissement import : accès aux packs")

	await stop_app()
	check(DirAccess.rename_absolute(profile.path_join("packs-held"), profile.path_join("packs")) == OK, "Pack remis en place avant de préparer le profil")
	await start_app(profile)
	app._command("pack_select", {"id":"base", "scope":"career"})
	await wait_response()
	app._command("pack_select", {"id":pack_id, "scope":"creation"})
	await wait_response()
	await stop_app()
	check(DirAccess.rename_absolute(profile.path_join("packs"), profile.path_join("packs-held")) == OK, "Pack de création retiré après fermeture")
	await start_app(profile)
	check(app._has_career() and app.model.packs.career == "base" and text_visible(app, "pack de création absent"), "Accueil : seule l’identité de création est indisponible")
	press_entry("EntryPacks")
	check(app.route == "Packs" and app.pack_manager.scope == "creation", "Avertissement création : accès aux packs de création depuis l’accueil")

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		var width := int(OS.get_environment("CD_GODOT_PACK_QA_WIDTH"))
		root.size = Vector2i(1920, 1080) if width == 1920 else Vector2i(1440, 900)
	root.add_child(app)
	await configure_resolution()
	app.pack_manager.creation_mode = "common"
	var deadline := Time.get_ticks_msec() + 15000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Moteur natif connecté")
	app.timer.stop()
	await capture("accueil-rugby-legacy")
	app._navigate("Création")
	await process_frame
	var import_button := button(app, "PACKS ET IDENTITÉS")
	check(import_button != null, "Création : commande visible des packs personnalisés")
	if import_button != null:
		import_button.pressed.emit()
		await process_frame
		check(app.route == "Packs", "Création : vraie commande ouvre les packs")
		check(button(app, "Importer une autre réalité") != null, "Packs : sélecteur ZIP disponible")
		check(button(app, "Choisir le jeu de base") != null, "Packs : retour explicite à la base")
	var skin = load("res://ui/game_skin.gd")
	var badge: Control = skin.crest({"abbr":"QA","logoPath":OS.get_environment("CD_GODOT_PACK_TEST_IMAGE")}, 56)
	check(badge is TextureRect and badge.texture != null, "Blason : image du pack chargée depuis le profil")
	badge.free()
	var path := OS.get_environment("CD_GODOT_PACK_TEST_IMAGE")
	var official: TextureRect = skin.portrait(0, 90, {"portraitPath":path,"portraitStatus":"official"})
	var synthetic: TextureRect = skin.portrait(1, 90, {"portraitPath":path,"portraitStatus":"synthetic"})
	check(official.texture is ImageTexture and official.texture.get_size().x <= 512, "Portrait du pack décodé et texture bornée")
	check(official.tooltip_text == "Portrait", "Portrait du pack présenté normalement")
	check(synthetic.tooltip_text == "Portrait", "Même présentation du portrait sans badge d’origine")
	check(official.texture == synthetic.texture, "Texture partagée entre vues, sans duplication")
	var absent: TextureRect = skin.portrait(3, 90, {"portraitPath":path+".missing","portraitStatus":"official"})
	check(absent.tooltip_text.begins_with("Image du pack indisponible"), "Image absente : indisponibilité du pack toujours signalée")
	official.free()
	synthetic.free()
	absent.free()
	await capture("packs-creation")
	if failures.is_empty(): await integration()
	if failures.is_empty(): await pack_edge_cases()
	app.bridge.stop()
	deadline = Time.get_ticks_msec() + 2500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Moteur fermé proprement")
	print(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
