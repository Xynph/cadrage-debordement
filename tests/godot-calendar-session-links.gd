extends SceneTree
# Catches wrong-session routing, silent malformed-ID acceptance, lost reading
# context and hidden consultation commands against the actual shipped scene.
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var requests := 0
var starts := 0
var output := OS.get_environment("CD_SESSION_LINKS_OUTPUT")
var captures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Projection réelle reçue : " + app.last_error)
	await settle()
func calendar() -> Control: return app.find_child("CarnetCalendar", true, false)
func press(name: String) -> void:
	var b := app.find_child(name, true, false) as Button
	check(b != null and not b.disabled, "Action réelle disponible : " + name)
	if b != null: b.pressed.emit()
	await settle()
func links(parent: Node, id: String) -> Array[Button]:
	var found: Array[Button] = []
	if parent == null: return found
	for b: Button in parent.find_children("*", "Button", true, false):
		if b.get_meta("entity_kind", "") == "session" and str(b.get_meta("entity_id", "")) == id: found.append(b)
	return found
func key(code: Key, alt: bool = false) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.alt_pressed = alt; e.pressed = down
		Input.parse_input_event(e); await process_frame
	await settle()
func mouse(b: Button) -> void:
	var scroller := app.find_child("CalendarProgramScroll", true, false) as ScrollContainer
	if scroller != null: scroller.ensure_control_visible(b)
	await settle()
	var point := b.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new(); e.position = point; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = down
		Input.parse_input_event(e); await process_frame
	await settle()
func snapshot() -> Dictionary:
	var state: Dictionary = app.management_ui.get("calendar_reading", {}).duplicate(true)
	state["month_observed"] = calendar().month
	state["scrolls_observed"] = {}
	for s: ScrollContainer in calendar().find_children("*", "ScrollContainer", true, false): state.scrolls_observed[str(s.name)] = [s.scroll_horizontal, s.scroll_vertical]
	var focus := root.gui_get_focus_owner()
	state["focus_observed"] = str(focus.name) if focus != null else ""
	return state
func target_ok(id: String, date: String, label: String) -> void:
	check(app.route == "Calendrier" and calendar() != null, "La séance ouvre le Calendrier")
	if calendar() == null: return
	check(calendar().selected == date and calendar().month == date.left(7) and calendar().filter == "all", "Date exacte publiée et filtre all, indépendants du jour courant")
	var detail := app.find_child("MonthDayDetail", true, false)
	var targets := links(detail, id)
	check(targets.size() == 1, "Une seule cible de détail pour l’identifiant projeté")
	if targets.size() == 1:
		check(targets[0].has_focus() and targets[0].is_visible_in_tree(), "Focus clavier sur la séance du programme du jour")
		check(targets[0].text.contains(label), "Libellé publié affiché sur le lien ciblé")
		check(str(targets[0].name) == "CalendarSessionDetail_" + id.sha256_text(), "Nom du détail unique par hash de l’ID brut")
func reject(target: Dictionary, message: String) -> void:
	var route: String = app.route
	var reading: Dictionary = app.management_ui.duplicate(true)
	var history: Array = app.navigation_controller.history.duplicate(true)
	var cursor: int = app.navigation_controller.cursor
	check(not app.navigation_controller.open_entity(target), message)
	check(app.route == route and app.management_ui == reading and app.navigation_controller.history == history and app.navigation_controller.cursor == cursor, "Refus atomique sans navigation : " + message)
func finish() -> void:
	var speech_id := int(app.coach.speech._id) if is_instance_valid(app.coach) else -1
	check(requests == 0 and starts == 0 and speech_id == 0, "Mute précoce : requested=0, started=0, _id=0")
	var f := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"speech":{"requested":requests,"started":starts,"id":speech_id},"captures":captures,"display":DisplayServer.get_name(),"test_sha":OS.get_environment("CD_SESSION_LINKS_TEST_SHA"),"product_sha":OS.get_environment("CD_SESSION_LINKS_PRODUCT_SHA")}, "  ")); f.close()
	print("SESSION LINKS : %d contrôles ; %d échecs" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)
func run() -> void:
	root.size = Vector2i(2560, 1440)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	# Connect before the first worker wait, including initial career setup.
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech), "Service vocal réel disponible avant attente")
	if is_instance_valid(app.coach):
		app.coach.speech.set_muted(true)
		app.coach.speech.requested.connect(func(_line: String): requests += 1)
		app.coach.speech.started.connect(func(_id: int): starts += 1)
	await wait_worker()
	check(app._command("new_career", {"club":0,"mode":"common"}), "Création publique Common 0")
	await wait_worker()
	var sessions: Array = app.model.get("calendarPlanning", {}).get("sessions", [])
	var chosen: Dictionary = {}
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	for row: Dictionary in sessions:
		if not str(row.get("id", "")).is_empty() and str(row.get("date", "")) != today:
			chosen = row.duplicate(true); break
	check(not chosen.is_empty(), "Vraie séance publiée datée hors aujourd’hui")
	if chosen.is_empty(): await finish(); return
	var id := str(chosen.id); var date := str(chosen.date)
	var scene: Variant = app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene")
	check(scene is Dictionary and not scene.get("completed", false), "Garde testée pendant le vrai rendez-vous obligatoire")
	reject({"kind":"session","id":id}, "Rendez-vous obligatoire refuse la séance réelle")
	if not await Flow.settle_club_meetings(app, self, check): await finish(); return
	# All business preparation is complete. No export or command after baseline.
	var baseline := JSON.stringify(app.model)
	var profile := str(app.model.meta.dataDir).path_join("donnees.json")
	var saved := FileAccess.get_file_as_bytes(profile)
	var bridge_id: int = app.bridge._next_id
	var command: String = app.last_command
	app._navigate("Calendrier"); await settle()
	reject({"kind":"session","id":""}, "Identifiant vide refusé")
	reject({"kind":"session","id":"__synthetic_unknown_session__"}, "Identifiant inconnu refusé")
	reject({"kind":"session"}, "Identifiant absent refusé")
	# Explicit isolated synthetic malformed projections. Never saved or captured.
	var original: Dictionary = app.model
	for invalid in ["missing", "invalid", "duplicate"]:
		var clone: Dictionary = original.duplicate(true)
		for row: Dictionary in clone.calendarPlanning.sessions:
			if str(row.get("id", "")) == id:
				if invalid == "missing": row.erase("date")
				elif invalid == "invalid": row.date = "2026-02-31"
		if invalid == "duplicate": clone.calendarPlanning.sessions.append(chosen.duplicate(true))
		app.model = clone
		reject({"kind":"session","id":id}, "Projection synthétique isolée refusée : " + invalid)
	app.model = original
	var nav: Node = app.navigation_controller
	check(nav.open_entity({"kind":"session","id":id}), "Adaptateur session accepte l’ID réel après préparation")
	await settle()
	if calendar() == null or calendar().selected != date:
		check(false, "Adaptateur session manquant : le vrai ID doit sélectionner " + date)
	else:
		target_ok(id, date, str(chosen.get("label", "Entraînement")))
		# Guards also apply when the target is already selected.
		var modal := AcceptDialog.new(); modal.name = "SessionExistingTargetGuard"
		app.add_child(modal); modal.popup_centered(Vector2i(400,200)); await settle()
		reject({"kind":"session","id":id}, "Cible déjà ouverte : garde modale toujours appliquée")
		check(modal.visible, "La garde existante reste visible")
		modal.hide(); modal.queue_free(); await settle()
		# Two real slots on a shared date must not collapse to a date-only target.
		var same_day: Dictionary = {}
		for row: Dictionary in sessions:
			if str(row.get("date", "")) == date and str(row.get("id", "")) != id:
				same_day = row; break
		# Optional real extra slot; mandatory same-day coverage uses the isolated clone below.
		if same_day.is_empty(): print("SESSION REAL FIXTURE: second same-day slot absent; isolated synthetic case follows")
		if not same_day.is_empty():
			check(nav.open_entity({"kind":"session","id":str(same_day.id)}), "Autre ID réel du même jour ouvert")
			await settle(); target_ok(str(same_day.id),date,str(same_day.get("label","Entraînement")))
			check(nav.open_entity({"kind":"session","id":id}), "Retour au premier créneau réel du même jour")
			await settle(); target_ok(id,date,str(chosen.get("label","Entraînement")))
		# Selecting another real published date invalidates the old ID destination.
		var other_date := today
		if other_date == date:
			for row: Dictionary in sessions:
				if str(row.get("date", "")) != date: other_date = str(row.date); break
		calendar()._select(other_date); await settle()
		check(str(app.management_ui.get("navigation_target", {}).get("id", "")) != id, "Sélection manuelle d’un autre jour invalide la cible active")
		check(nav.open_entity({"kind":"session","id":id}), "Même ID réouvre sa date après sélection manuelle")
		await settle(); target_ok(id,date,str(chosen.get("label","Entraînement")))
		# A real table origin must build the program and be restored by Back.
		app._navigate("Bureau"); await settle()
		app.set_meta("calendar_table", true)
		app._navigate("Calendrier"); await settle()
		check(calendar() == null and app.get_meta("calendar_table",false), "Origine : vraie vue tableau du Calendrier")
		check(nav.open_entity({"kind":"session","id":id}), "Tableau vers séance publiée")
		await settle()
		check(not app.get_meta("calendar_table",true) and calendar() != null, "Ouverture construit le programme hors tableau")
		target_ok(id,date,str(chosen.get("label","Entraînement")))
		await key(KEY_LEFT,true)
		check(app.get_meta("calendar_table",false) and calendar() == null, "Back restaure la vraie vue tableau")
		check(nav.open_entity({"kind":"session","id":id}), "Réouverture de la séance depuis le tableau restauré")
		await settle()
		for size: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1440)]:
			root.size = size
			if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
			await settle()
			var detail_links := links(app.find_child("MonthDayDetail",true,false),id)
			check(detail_links.size() == 1 and detail_links[0].get_global_rect().size.x > 0 and detail_links[0].get_global_rect().end.x <= size.x + 1, "Lien séance contenu dans le viewport " + str(size))
		if OS.get_environment("CD_SESSION_LINKS_CAPTURE") == "1":
			check(DisplayServer.get_name() != "headless", "Capture exige un vrai moteur graphique")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(image.get_size() == Vector2i(2560,1440), "Capture réelle 2560×1440")
				check(image.save_png(output.path_join("session-1440.png")) == OK, "Capture séance publiée")
				captures.append("session-1440.png")
		await press("CalendarView_week")
		await press("MonthFilter_matches")
		check(links(app.find_child("CalendarWeekGrid",true,false),id).is_empty(), "Filtre matchs masque les séances de la grille")
		var weekly := links(app.find_child("CalendarWeekSessionDetails",true,false),id)
		check(weekly.size() == 1, "Lien hebdomadaire réel reste disponible sous le filtre matchs")
		if weekly.size() == 1:
			var source := weekly[0]
			source.grab_focus(); await settle()
			var before := snapshot()
			await key(KEY_ENTER)
			target_ok(id,date,str(chosen.get("label","Entraînement")))
			var history_count: int = nav.history.size()
			check(nav.open_entity({"kind":"session","id":id}), "Répétition de la même destination acceptée")
			await settle()
			check(nav.history.size() == history_count and app.find_children("*","AcceptDialog",true,false).filter(func(d): return d.visible).is_empty(), "Répétition sans nouvelle entrée ni dialogue")
			await key(KEY_LEFT,true)
			check(snapshot() == before, "Back clavier restitue date, mois, vue, filtre, scrolls et focus exacts")
			weekly = links(app.find_child("CalendarWeekSessionDetails",true,false),id)
			if weekly.size() == 1:
				await mouse(weekly[0]); target_ok(id,date,str(chosen.get("label","Entraînement")))
				await key(KEY_LEFT,true)
				check(snapshot() == before, "Back après clic restitue le contexte hebdomadaire")
	# Explicit SYNTHETIC projection: collision, same-day slots and past date.
	# This section is never captured, sent to the worker, or persisted.
	if calendar() != null and calendar().selected == date:
		var real_ui: Dictionary = app.management_ui.duplicate(true)
		var real_history: Array[Dictionary] = nav.history.duplicate(true)
		var real_cursor: int = nav.cursor
		var synthetic: Dictionary = original.duplicate(true)
		var a: Dictionary = chosen.duplicate(true)
		var b: Dictionary = chosen.duplicate(true)
		a.id = "synthetic/session"; b.id = "synthetic:session"
		a.date = "2000-01-01"; b.date = "2000-01-01"
		a.label = "Créneau synthétique A"; b.label = "Créneau synthétique B"
		synthetic.calendarPlanning.sessions = [a,b]
		check(str(a.id).validate_node_name() == str(b.id).validate_node_name(), "Fixture explicitement synthétique : collision des noms assainis")
		app.model = synthetic
		var synthetic_before := JSON.stringify(synthetic)
		for row: Dictionary in [a,b]:
			check(nav.open_entity({"kind":"session","id":str(row.id)}), "Projection synthétique isolée : ID exact accepté")
			await settle(); target_ok(str(row.id),"2000-01-01",str(row.label))
			var detail := app.find_child("MonthDayDetail",true,false)
			var text := ""
			for node: Control in detail.find_children("*","Control",true,false):
				if node is Label or node is Button: text += str(node.text) + " "
			check(text.contains(str(a.label)) and text.contains(str(b.label)), "Deux créneaux synthétiques du même jour restent publiés séparément")
			check(text.contains("Créneau passé") and not text.to_lower().contains("séance effectuée"), "Créneau passé décrit sans prétendre une exécution sportive")
			for field: String in ["forwards","backs"]:
				if not str(row.get(field, "")).is_empty(): check(text.contains(str(row[field])), "Programme passé limité au champ publié : " + field)
		check(JSON.stringify(app.model) == synthetic_before and app.bridge._next_id == bridge_id, "Projection synthétique passée sans mutation ni application entraînement")
		app.model = original
		app.management_ui = real_ui
		app._navigate("Calendrier"); await settle()
		nav.history = real_history; nav.cursor = real_cursor
	check(JSON.stringify(app.model) == baseline, "Modèle intégral, RNG projeté et horloge inchangés")
	check(saved == FileAccess.get_file_as_bytes(profile), "Profil sportif inchangé octet pour octet")
	check(app.bridge._next_id == bridge_id and app.last_command == command and not app.waiting and app.timer.is_stopped(), "Consultation sans commande, bridge ni horloge active")
	await finish()
