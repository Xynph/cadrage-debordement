extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
var journal: Control
var proof := OS.get_environment("CD_MATCH_JOURNAL_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
	await settle()
func button_text(text: String) -> Button:
	for b: Button in app.body.find_children("*", "Button", true, false):
		if b.text == text: return b
	return null
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
func type_text(value: String) -> void:
	journal.search.grab_focus()
	await settle()
	for character in value:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = character.to_upper().unicode_at(0)
			event.unicode = character.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await settle()
	check(journal.search.text == value and journal.search.caret_column == value.length(), "Saisie clavier réelle de la recherche")
func keyboard(control: Control) -> void:
	control.grab_focus()
	await settle()
	check(control.has_focus(), "Focus clavier : " + str(control.name))
	await key(KEY_ENTER)
func labels(node: Node) -> String:
	var text: String = node.text + "\n" if node is Label else ""
	for child in node.get_children(): text += labels(child)
	return text
func choose(index: int) -> void:
	journal.category.grab_focus()
	await settle()
	# Native OptionButton popup, driven by real keyboard events.
	await key(KEY_SPACE)
	for i in journal.category.selected: await key(KEY_UP)
	for i in index: await key(KEY_DOWN)
	await key(KEY_ENTER)
	await settle()
	check(journal.category.selected == index, "Catégorie choisie au clavier " + str(index))
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app.timer.stop()
	app._navigate("Match")
	await settle()
	var tab := button_text("JOURNAL")
	check(tab != null, "Le match expose un onglet Journal complet")
	if tab != null:
		await keyboard(tab)
		journal = app.body.find_child("MatchJournal", true, false)
		check(journal != null and journal.visible, "Le journal est raccordé au vrai écran")
		if journal != null:
			await cases()
			await round_one()
	var report := FileAccess.open(proof.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	report.close()
	app.closing = true
	app.bridge.stop()
	print("Journal : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
func cases() -> void:
	var live: Dictionary = app.model.live.duplicate(true)
	check(live.events.size() > 20, "Vrai match : journal supérieur aux cinq derniers faits")
	check(journal.visible_events.size() == live.events.size(), "Tous les faits du vrai match sont consultables")
	for event in live.events:
		check(labels(journal.rows).contains(event.text), "Texte moteur exact : " + event.text)
	await command("export")
	var before: String = app.model.meta.exportText
	var disk_path: String = OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var disk_before := FileAccess.get_file_as_bytes(disk_path)
	check(not disk_before.is_empty(), "Profil réel présent pour comparer octets et RNG")
	var source_before := JSON.stringify(app.model.live)
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		for color_key in ["font_placeholder_color", "font_color"]:
			var ink: Color = journal.search.get_theme_color(color_key)
			check((Color("faf6ed").srgb_to_linear().get_luminance() + 0.05) / (ink.srgb_to_linear().get_luminance() + 0.05) >= 4.5, "Recherche : contraste du texte supérieur à 4,5:1")
		check(journal.search.get_global_rect().end.x <= app.size.x and journal.search.get_global_rect().position.x >= 0 and journal.scroll.size.y > 80 and journal.scroll.get_global_rect().end.y <= app.size.y, "Journal et recherche visibles à " + str(resolution))
		check(button_text("PAUSE") != null or button_text("REPRENDRE") != null, "Pause toujours accessible")
		check(button_text("CONSIGNES") != null and button_text("BANC") != null, "Consignes et banc accessibles")
		await choose(1)
		check(journal.visible_events.all(func(e): return e is Dictionary and e.get("scene",{}).get("kind","") in ["try","goal"]), "Scores issus des métadonnées")
		await choose(0)
		if OS.get_environment("CD_MATCH_JOURNAL_GRAPHICS") == "1":
			await process_frame
			await RenderingServer.frame_post_draw
			print("JOURNAL_GEOMETRY ", JSON.stringify({"window":root.size,"canvas":app.size,"scroll":journal.scroll.get_global_rect(),"search":journal.search.get_global_rect()}))
			root.get_texture().get_image().save_png(proof.path_join("journal-%dx%d.png" % [resolution.x,resolution.y]))
	# Explicit UI projection, never imported as a save: typed, legacy, missing data.
	var projected := live.duplicate(true)
	projected.events = [{"min":12,"text":"Pénalité réussie · Émile","scene":{"kind":"goal","team":0,"period":1,"score":[3,0]}},{"min":13,"text":"Discipline réelle","scene":{"kind":"card","team":1}},{"min":14,"text":"Entrée réelle","scene":{"kind":"sub"}},{"min":15,"text":"Touche réelle","scene":{"kind":"lineout"}},"Essai ancien non typé",{"text":"Essai sans kind","type":"try"},{"min":16,"text":"Futur typé","scene":{"kind":"future-kind"}}]
	journal.update_frame(projected)
	await settle()
	check(journal.visible_events.size() == 7, "Tous inclut chaînes historiques et faits non typés")
	check(labels(journal.rows).contains("Minute non renseignée") and labels(journal.rows).contains("Type non renseigné") and labels(journal.rows).contains("Type inconnu"), "Absences et type inconnu explicites")
	await choose(1)
	check(journal.visible_events.size() == 1 and journal.visible_events[0].min == 12, "Les faux essais en texte ne sont pas classés Scores")
	await type_text("emile")
	await settle()
	check(journal.visible_events.size() == 1, "Recherche sans accent combinée aux scores")
	journal.search.text = "introuvable"
	journal.search.text_changed.emit(journal.search.text)
	await settle()
	check(journal.visible_events.is_empty() and journal.empty.visible, "État vide lisible après filtres combinés")
	journal.search.text = ""
	journal.search.text_changed.emit("")
	for item in [[2,13],[3,14],[4,15]]:
		await choose(item[0])
		check(journal.visible_events.size() == 1 and journal.visible_events[0].min == item[1], "Discipline/changements/conquête exacts")
	await choose(0)
	journal.update_frame(live)
	await settle()
	journal.scroll.scroll_vertical = 120
	await settle()
	journal.search.grab_focus()
	journal.search.caret_column = 0
	var old_scroll: int = journal.scroll.scroll_vertical
	var search_id: int = journal.search.get_instance_id()
	var next := live.duplicate(true)
	next.events.append({"min":66,"text":"Ajout UI typé explicite","scene":{"kind":"card"}})
	journal.update_frame(next)
	await settle()
	check(journal.search.get_instance_id() == search_id and journal.search.has_focus() and journal.search.caret_column == 0, "Tick : recherche, focus et caret conservés")
	check(journal.scroll.scroll_vertical == old_scroll, "Tick : la relecture conserve son défilement")
	check(journal.new_events.visible and journal.new_events.text.contains("1"), "Un nouveau fait signalé sans arracher la lecture")
	await keyboard(journal.latest)
	check(journal.scroll.scroll_vertical >= journal.scroll.get_v_scroll_bar().max_value - journal.scroll.get_v_scroll_bar().page - 2, "Dernier événement rejoint explicitement le bas")
	next.events.append({"min":67,"text":"Suivi demandé","scene":{"kind":"card"}})
	journal.update_frame(next)
	await settle()
	check(journal.scroll.scroll_vertical >= journal.scroll.get_v_scroll_bar().max_value - journal.scroll.get_v_scroll_bar().page - 2, "Au bas : nouveaux faits suivis")
	journal.search.text = "emile"
	journal.search.text_changed.emit("emile")
	await choose(2)
	await keyboard(button_text("BANC"))
	await keyboard(button_text("JOURNAL"))
	check(journal.category.selected == 2 and journal.search.text == "emile", "Aller-retour Banc conserve les filtres")
	app._navigate("Préparation")
	await settle()
	app._navigate("Match")
	await settle()
	check(app.match_screen.tab == "Journal", "Retour au match conserve l’onglet Journal")
	journal = app.body.find_child("MatchJournal",true,false)
	check(journal.category.selected == 2 and journal.search.text == "emile", "Recréation écran restaure l’état local")
	check(JSON.stringify(app.model.live) == source_before, "Consultation et projections ne mutent pas le modèle moteur")
	check(FileAccess.get_file_as_bytes(disk_path) == disk_before, "Consultation : octets profil/RNG inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation : export de sauvegarde identique")

	# Actual worker ticks are allowed only after the read-only invariant checks.
	await keyboard(button_text("JOURNAL"))
	await choose(0)
	journal.search.text = "SDB"
	journal.search.text_changed.emit("SDB")
	await settle()
	journal.scroll.scroll_vertical = 100
	await settle()
	journal.search.grab_focus()
	journal.search.caret_column = 1
	var actual_scroll: int = journal.scroll.scroll_vertical
	var actual_id: int = journal.search.get_instance_id()
	var initial_count: int = app.model.live.events.size()
	await command("pause", {"paused":false})
	app.timer.stop()
	for i in 8:
		if app.model.live.events.size() > initial_count: break
		await command("tick", {"steps":1})
		app.timer.stop()
	check(app.model.live.events.size() > initial_count, "Le worker réel ajoute un événement en direct")
	check(journal.search.get_instance_id() == actual_id and journal.search.has_focus() and journal.search.caret_column == 1 and journal.search.text == "SDB", "Vrai tick worker : recherche, identité, focus et caret préservés")
	check(journal.scroll.scroll_vertical == actual_scroll, "Vrai tick worker : défilement inspecté préservé")
	check(journal.new_events.visible, "Vrai tick worker : indicateur de nouveaux faits")

func round_one() -> void:
	await command("pause", {"paused":true})
	journal.search.text = ""
	journal.search.text_changed.emit("")
	await choose(0)
	var projection: Dictionary = app.model.live.duplicate(true)
	projection.events = [{"min":1,"text":"E" + String.chr(0x0301) + "mile marque","scene":{"kind":"goal"}}]
	journal.update_frame(projection)
	journal.search.text = "emile"
	journal.search.text_changed.emit("emile")
	await settle()
	check(journal.visible_events.size() == 1, "Texte Unicode décomposé trouvé par requête sans accent")
	projection.events = [{"min":1,"text":"Émile marque","scene":{"kind":"goal"}}]
	journal.update_frame(projection)
	journal.search.text = "E" + String.chr(0x0301) + "mile"
	journal.search.text_changed.emit(journal.search.text)
	await settle()
	check(journal.visible_events.size() == 1, "Requête Unicode décomposée trouve le texte précomposé")
	# Import from Match with a longer history sharing the exact same prefix.
	for fixture in ["short", "live", "other", "live"]:
		journal.search.text = "ancien filtre"
		journal.search.text_changed.emit(journal.search.text)
		await choose(2)
		await command("import", {"text":FileAccess.get_file_as_string(proof.path_join(fixture + ".json"))})
		check(app.route == "Match", "Import depuis Match conserve la route")
		journal = app.body.find_child("MatchJournal", true, false)
		check(not journal.new_events.visible and journal._unread == 0, "Import " + fixture + " : aucun faux événement live")
		check(journal.search.text.is_empty() and journal.category.selected == 0, "Import " + fixture + " : anciens filtres réinitialisés")
		check(journal.visible_events.size() == app.model.live.events.size(), "Import " + fixture + " : seul le nouvel historique est lu")
	# A reset while leaving Match must not be undone by the old journal exit hook.
	for club in [0, 1]:
		journal.search.text = "filtre abandonné"
		journal.search.text_changed.emit(journal.search.text)
		await choose(2)
		await command("new_career", {"club":club,"mode":"fiction"})
		app.timer.stop()
		app._navigate("Bureau")
		await settle()
		check(not app.management_ui.has("match_journal_search") or str(app.management_ui.match_journal_search).is_empty(), "Nouvelle carrière club " + str(club) + " : sortie ancienne UI ne repollue pas les filtres")
		app._navigate("Match")
		await settle()
		await keyboard(button_text("JOURNAL"))
		journal = app.body.find_child("MatchJournal", true, false)
		check(journal.search.text.is_empty() and journal.category.selected == 0 and not journal.new_events.visible, "Nouveau contexte sans filtres ni compteur hérités")
	# Route-changing import exercises the same exit hook with a saved live history.
	journal.search.text = "autre ancien filtre"
	journal.search.text_changed.emit(journal.search.text)
	app._command("import", {"text":FileAccess.get_file_as_string(proof.path_join("live.json"))}, "Bureau")
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.route == "Bureau" and app.bridge.last_response_ok, "Import réel avec changement de route")
	check(not app.management_ui.has("match_journal_search") or str(app.management_ui.match_journal_search).is_empty(), "Import avec changement de route : ancien store ignoré")
	app._navigate("Match")
	await settle()
	await keyboard(button_text("JOURNAL"))
	journal = app.body.find_child("MatchJournal", true, false)
	# Normal navigation remains local and preserves the exact reading position.
	journal.scroll.scroll_vertical = 120
	await settle()
	var position: int = journal.scroll.scroll_vertical
	journal.search.grab_focus()
	journal.search.caret_column = 0
	app._navigate("Bureau")
	await settle()
	app._navigate("Match")
	await settle()
	journal = app.body.find_child("MatchJournal", true, false)
	check(app.match_screen.tab == "Journal" and journal.scroll.scroll_vertical == position, "Navigation ordinaire : onglet et position de relecture conservés")
	# Private runtime layout variant; never changes production project settings.
	var preferences_before: Dictionary = app.user_preferences.data.duplicate(true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		journal.scroll.scroll_vertical = 0
		await settle()
		var complete := 0
		for entry in journal.rows.get_children():
			if str(entry.name).begins_with("JournalEvent") and journal.scroll.get_global_rect().encloses(entry.get_global_rect()): complete += 1
		check(complete >= 3, "Journal 1:1 " + str(resolution) + " : au moins trois faits complets réellement visibles, obtenu " + str(complete))
		check(journal.scroll.size.y >= 200, "Journal 1:1 : vraie hauteur de lecture >=200, obtenu " + str(journal.scroll.size.y))
		for text in ["REPRENDRE", "CONSIGNES", "BANC", "CAMÉRA TV", "VUE TACTIQUE", "AU CONTACT"]:
			var control := button_text(text)
			check(control != null and Rect2(Vector2.ZERO, app.size).encloses(control.get_global_rect()), "Commande dans le canvas 1:1 : " + text)
		if OS.get_environment("CD_MATCH_JOURNAL_GRAPHICS") == "1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(proof.path_join("journal-native-%dx%d.png" % [resolution.x,resolution.y]))
		check(app.user_preferences.data == preferences_before and app.match_screen.stage._camera_mode == app.user_preferences.effective_camera() and app.match_screen.stage._quality == app.user_preferences.data.quality, "Redimensionnement : préférences caméra/qualité et effets conservés")
		print("JOURNAL_NATIVE_GEOMETRY ", JSON.stringify({"window":root.size,"canvas":app.size,"reading":journal.scroll.size,"completeEvents":complete}))

	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	check(app.user_preferences.set_value("reduced_motion", true), "Mode calme enregistré dans le profil temporaire")
	await settle()
	check(app.match_screen.stage._camera_mode == "tactical" and app.match_screen.stage._quality == preferences_before.quality, "Géométrie courte : mode calme tactique et qualité conservés")
	check(app.match_screen._camera_controls.all(func(b): return b.disabled), "Géométrie courte : contrôles caméra désactivés conformément au calme")
	check(app.user_preferences.set_value("reduced_motion", preferences_before.reduced_motion), "Préférence calme initiale restaurée")
	await settle()
	check(app.user_preferences.data == preferences_before and app.match_screen.stage._camera_mode == app.user_preferences.effective_camera(), "Géométrie courte : caméra préférée restaurée après calme")
