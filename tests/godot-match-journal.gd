extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
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
func match_surface() -> Control:
	if app.contextual_director.active() and app.contextual_director.kind == "live":
		return app.contextual_director.view
	return app.match_screen if is_instance_valid(app.match_screen) else null
func button_text(text: String) -> Button:
	var surface := match_surface()
	if surface == null: return null
	for b: Button in surface.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree(): return b
	return null
func journal_selected() -> bool:
	var surface := match_surface()
	if surface == null: return false
	if surface.has_method("_toggle_drawer"):
		return surface.drawer_tab == "Journal" and surface.drawer.is_visible_in_tree()
	return surface.tab == "Journal"
func bind_journal() -> bool:
	var surface := match_surface()
	journal = surface.find_child("MatchJournal", true, false) if surface != null else null
	var visible := journal != null and journal.is_visible_in_tree()
	check(visible, "Le journal appartient à la vraie surface de match visible")
	return visible
func open_journal() -> bool:
	# The contextual button toggles its drawer; selecting an already-open journal
	# must keep it open rather than operate on the hidden management screen.
	if not journal_selected(): await keyboard(button_text("JOURNAL"))
	await settle()
	return bind_journal()
func tactics_button() -> Button:
	return button_text("TACTIQUE" if match_surface().has_method("_toggle_drawer") else "CONSIGNES")
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
	check(control != null and control.is_visible_in_tree() and not control.disabled, "Action clavier visible et autorisée par le directeur")
	if control == null or not control.is_visible_in_tree() or control.disabled: return
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
func resolutions() -> Array[Vector2i]:
	var requested := OS.get_environment("QA_RESOLUTION")
	if not requested.is_empty():
		var dimensions := requested.to_lower().replace("×", "x").split("x")
		if dimensions.size() == 2 and dimensions[0].is_valid_int() and dimensions[1].is_valid_int() and int(dimensions[0]) > 0 and int(dimensions[1]) > 0:
			return [Vector2i(int(dimensions[0]), int(dimensions[1]))]
		check(false, "QA_RESOLUTION doit indiquer largeurxhauteur")
	return [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]
func run() -> void:
	if not OS.get_environment("QA_RESOLUTION").is_empty():
		root.size = resolutions()[0]
		DisplayServer.window_set_size(root.size)
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
		if await open_journal():
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
	await keyboard(journal.review)
	var review := journal.find_child("MatchActionReview", true, false) as AcceptDialog
	check(review != null and review.visible, "La relecture des actions s’ouvre au clavier depuis le vrai Journal")
	if review != null:
		check(review.events == live.events, "La relecture conserve l’instantané exact des faits filtrés")
		await keyboard(review.get_ok_button())
		await settle()
		check(not is_instance_valid(review), "La relecture se ferme au clavier sans quitter le match")
	for resolution in resolutions():
		root.size = resolution
		DisplayServer.window_set_size(resolution)
		await settle()
		for color_key in ["font_placeholder_color", "font_color"]:
			var ink: Color = journal.search.get_theme_color(color_key)
			check((Color("faf6ed").srgb_to_linear().get_luminance() + 0.05) / (ink.srgb_to_linear().get_luminance() + 0.05) >= 4.5, "Recherche : contraste du texte supérieur à 4,5:1")
		check(journal.search.get_global_rect().end.x <= app.size.x and journal.search.get_global_rect().position.x >= 0 and journal.scroll.size.y > 80 and journal.scroll.get_global_rect().end.y <= app.size.y, "Journal et recherche visibles à " + str(resolution))
		check(button_text("PAUSE") != null or button_text("REPRENDRE") != null, "Pause toujours accessible")
		check(tactics_button() != null and button_text("BANC") != null, "Consignes et banc accessibles")
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
	await open_journal()
	check(journal.category.selected == 2 and journal.search.text == "emile", "Aller-retour Banc conserve les filtres")
	var journal_id := journal.get_instance_id()
	app._navigate("Préparation")
	await settle()
	check(app.route == "Match" and app.contextual_director.kind == "live", "Le directeur garde le match visible pendant une tentative de sortie")
	app._navigate("Match")
	await settle()
	check(journal_selected(), "La navigation verrouillée conserve le Journal ouvert")
	bind_journal()
	check(journal.get_instance_id() == journal_id and journal.category.selected == 2 and journal.search.text == "emile", "Le verrou du match conserve le widget, les filtres et la recherche")
	check(JSON.stringify(app.model.live) == source_before, "Consultation et projections ne mutent pas le modèle moteur")
	check(FileAccess.get_file_as_bytes(disk_path) == disk_before, "Consultation : octets profil/RNG inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation : export de sauvegarde identique")

	# Actual worker ticks are allowed only after the read-only invariant checks.
	await open_journal()
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
		await open_journal()
		check(not journal.new_events.visible and journal._unread == 0, "Import " + fixture + " : aucun faux événement live")
		check(journal.search.text.is_empty() and journal.category.selected == 0, "Import " + fixture + " : anciens filtres réinitialisés")
		check(journal.visible_events.size() == app.model.live.events.size(), "Import " + fixture + " : seul le nouvel historique est lu")
	# A reset while leaving Match must not be undone by the old journal exit hook.
	for club in [0, 1]:
		journal.search.text = "filtre abandonné"
		journal.search.text_changed.emit(journal.search.text)
		await choose(2)
		await command("new_career", {"club":club,"mode":"fiction"})
		await ContextualFlow.settle_club_meetings(app, self, check)
		app.timer.stop()
		app._navigate("Bureau")
		await settle()
		check(not app.management_ui.has("match_journal_search") or str(app.management_ui.match_journal_search).is_empty(), "Nouvelle carrière club " + str(club) + " : sortie ancienne UI ne repollue pas les filtres")
		app._navigate("Match")
		await settle()
		await open_journal()
		bind_journal()
		check(journal.search.text.is_empty() and journal.category.selected == 0 and not journal.new_events.visible, "Nouveau contexte sans filtres ni compteur hérités")
	# A live import resets the old reading store while the director owns its route.
	journal.search.text = "autre ancien filtre"
	journal.search.text_changed.emit(journal.search.text)
	app._command("import", {"text":FileAccess.get_file_as_string(proof.path_join("live.json"))}, "Bureau")
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.route == "Match" and app.contextual_director.kind == "live" and app.bridge.last_response_ok, "L’import live ouvre le vrai direct malgré la cible Bureau")
	check(not app.management_ui.has("match_journal_search") or str(app.management_ui.match_journal_search).is_empty(), "Import avec changement de route : ancien store ignoré")
	app._navigate("Match")
	await settle()
	await open_journal()
	bind_journal()
	# Live navigation stays locked; local journal reading must survive the attempt.
	journal.scroll.scroll_vertical = 120
	await settle()
	var position: int = journal.scroll.scroll_vertical
	journal.search.grab_focus()
	journal.search.caret_column = 0
	app._navigate("Bureau")
	await settle()
	app._navigate("Match")
	await settle()
	bind_journal()
	check(app.route == "Match" and app.contextual_director.kind == "live" and journal_selected() and journal.scroll.scroll_vertical == position, "Navigation verrouillée : Journal et position de relecture conservés")
	# Private runtime layout variant; never changes production project settings.
	var preferences_before: Dictionary = app.user_preferences.data.duplicate(true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for resolution in resolutions():
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
		var controls: Array = [button_text("REPRENDRE"), tactics_button(), button_text("BANC")]
		controls.append_array(match_surface()._camera_controls)
		check(match_surface()._camera_controls.size() == 3, "Les trois caméras du vrai direct restent accessibles")
		for control: Button in controls:
			check(control != null and control.is_visible_in_tree() and Rect2(Vector2.ZERO, app.size).encloses(control.get_global_rect()), "Commande dans le canvas 1:1 : " + (control.text if control != null else "absente"))
		if OS.get_environment("CD_MATCH_JOURNAL_GRAPHICS") == "1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(proof.path_join("journal-native-%dx%d.png" % [resolution.x,resolution.y]))
		check(app.user_preferences.data == preferences_before and match_surface().stage._camera_mode == app.user_preferences.effective_camera() and match_surface().stage._quality == app.user_preferences.data.quality, "Redimensionnement : préférences caméra/qualité et effets conservés")
		print("JOURNAL_NATIVE_GEOMETRY ", JSON.stringify({"window":root.size,"canvas":app.size,"reading":journal.scroll.size,"completeEvents":complete}))

	root.size = resolutions()[0]
	DisplayServer.window_set_size(root.size)
	check(app.user_preferences.set_value("reduced_motion", true), "Mode calme enregistré dans le profil temporaire")
	await settle()
	check(match_surface().stage._camera_mode == "tactical" and match_surface().stage._quality == preferences_before.quality, "Géométrie reçue : mode calme tactique et qualité conservés")
	check(match_surface()._camera_controls.all(func(b): return b.disabled), "Géométrie reçue : contrôles caméra désactivés conformément au calme")
	check(app.user_preferences.set_value("reduced_motion", preferences_before.reduced_motion), "Préférence calme initiale restaurée")
	await settle()
	check(app.user_preferences.data == preferences_before and match_surface().stage._camera_mode == app.user_preferences.effective_camera(), "Géométrie reçue : caméra préférée restaurée après calme")
	check(match_surface()._camera_controls.all(func(b): return b.disabled == (app.waiting or bool(preferences_before.reduced_motion))), "Caméras réactivées après restauration du calme, sous réserve du verrou de commande")
