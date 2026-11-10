extends SceneTree
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_CALENDAR_AGENDA_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 10: await process_frame
func projected_dates() -> void:
	check(Agenda.valid_date("2028-02-29") and not Agenda.valid_date("2027-02-29") and not Agenda.valid_date("2026-02-31"),"Dates validées sans normalisation silencieuse")
	check(Agenda.week("2027-01-01") == ["2026-12-28","2026-12-29","2026-12-30","2026-12-31","2027-01-01","2027-01-02","2027-01-03"],"Sept jours uniques à la jonction des années")
	check(Agenda.shift("2026-12-31",1) == "2027-01-01","Navigation quotidienne au changement d’année")
	var fixtures := [{"id":"a","date":"2026-12-31"},{"id":"a","date":"2026-12-31"},{"id":"a","date":"2027-12-31"}]
	check(Agenda.unique_fixtures(fixtures).size() == 2,"Doublon id+date écarté, édition d’une autre année conservée")
	var player := {"id":"p1","name":"Joueur de recette","from":"2026-11-10","through":"2026-11-12","returnDate":"2026-11-13","nationName":"France"}
	var model := {"international":{"availability":{"clubManaged":true,"players":[player],"returned":[player]}}}
	var before := JSON.stringify(model)
	check(Agenda.absence_events(model,"2026-11-09").is_empty(),"Aucune absence avant la convocation")
	check(Agenda.absence_events(model,"2026-11-12").size() == 1 and Agenda.absence_events(model,"2026-11-12")[0].kind == "absence","Dernier jour d’absence inclus, joueur non dupliqué")
	check(Agenda.absence_events(model,"2026-11-13").size() == 1 and Agenda.absence_events(model,"2026-11-13")[0].kind == "return","Retour sur la date publiée seulement")
	check(Agenda.absence_events(model,"2026-11-14").is_empty(),"Pas de prolongation de l’absence inventée")
	check(JSON.stringify(model) == before,"Les données de convocation ne sont pas modifiées")
	var later := player.duplicate(true)
	later.from = "2026-11-20"; later.through = "2026-11-22"; later.returnDate = "2026-11-23"
	model.international.availability.players = [later]
	check(Agenda.absence_events(model,"2026-11-13").size() == 1,"Une nouvelle convocation ne masque pas le retour publié précédent")
	model.international.availability.clubManaged = false
	check(Agenda.absence_events(model,"2026-11-12").is_empty(),"Pas d’absence de club sans mandat de club")
func view() -> Control:
	return app.find_child("CarnetCalendar",true,false)
func button(id: String) -> Button:
	return app.find_child(id,true,false) as Button
func press(id: String) -> void:
	var action := button(id)
	check(action != null and not action.disabled,"Action disponible : "+id)
	if action == null: return
	action.pressed.emit()
	await settle()
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func wait_engine() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vraie réponse du moteur : "+app.last_error)
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(2560,1440),"Capture1440 native")
	check(image.save_png(output.path_join(name+".png")) == OK,"Capture "+name)
func run() -> void:
	projected_dates()
	root.size = Vector2i(2560,1440)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await wait_engine()
	app._command("new_career",{"mode":"common","club":29})
	await wait_engine(); app.timer.stop()
	var original: Dictionary = app.model.duplicate(true)
	var file := str(original.meta.dataDir).path_join("donnees.json")
	var hash := FileAccess.get_sha256(file)
	var commands: int = app.bridge._next_id
	var sessions := JSON.stringify(original.get("calendarPlanning",{}).get("sessions",[]))
	app._navigate("Calendrier"); await settle()
	check(view() != null and view().view_mode == "month","Mois disponible dans le vrai calendrier")
	await capture("calendrier-mois-1440")
	await press("CalendarView_week")
	check(app.find_child("CalendarWeekGrid",true,false) != null,"Vue semaine raccordée")
	var dates := Agenda.week(view().selected)
	var grid: Control = app.find_child("CalendarWeekGrid",true,false)
	check(grid.get_child_count() == 7,"La semaine ne duplique aucun jour")
	check(app.find_child("CalendarUpcomingContext",true,false) != null,"Contexte des prochains rendez-vous visible")
	check(app.find_child("CalendarSessionChart",true,false) != null,"Histogramme des séances publiées visible")
	var session_table: Control = app.find_child("CalendarWeekSessionDetails",true,false)
	check(session_table != null,"Détail collectif publié disponible sous la semaine")
	var source_week: Array = view().sessions.filter(func(session: Dictionary): return session.date in dates)
	check(session_table.find_children("CalendarWeekSession_*","HBoxContainer",true,false).size() == source_week.size(),"Table de préparation fidèle aux séances de la semaine")
	for date: String in dates:
		var bar := app.find_child("CalendarSessionCount_"+date,true,false) as ProgressBar
		check(bar != null and int(bar.value) == view().sessions_by_day.get(date,[]).size(),"Histogramme fidèle au nombre de créneaux : "+date)
	await press("MonthFilter_training")
	check(app.find_child("CalendarWeekGrid",true,false).find_children("MonthMatch_*","PanelContainer",true,false).is_empty(),"Filtre entraînement masque les matchs de la semaine")
	var selected: String = view().selected
	var day := button("MonthDay_"+selected)
	day.grab_focus(); await process_frame
	await key(KEY_RIGHT)
	check(view().selected == Agenda.shift(selected,1),"Flèche droite sélectionne le jour suivant")
	check(root.gui_get_focus_owner() == button("MonthDay_"+view().selected),"Focus conservé sur le jour sélectionné")
	await press("MonthToday")
	await press("MonthFilter_all")
	await press("CalendarOpenTraining")
	check(app.route == "Préparation" or app.route == "Entraînement","Le calendrier ouvre le vrai entraînement")
	app._navigate("Calendrier"); await settle()
	check(view().view_mode == "week" and view().filter == "all" and view().selected == view().today,"Vue, filtre et sélection restaurés au retour")
	check(root.gui_get_focus_owner() == button("CalendarOpenTraining"),"Focus restauré sur l’action de retour")
	await press("MonthNext")
	check(view().selected == Agenda.shift(selected,7),"Suivant en semaine avance exactement de sept jours")
	await press("MonthPrevious")
	await press("MonthToday")
	await capture("calendrier-semaine-1440")
	var controlled := original.duplicate(true)
	var date: String = view().today
	var person: Dictionary = original.squad[0]
	controlled.international = {"role":"club","teams":[],"availability":{"clubManaged":true,"absentCount":1,"nextReturn":Agenda.shift(date,3),"players":[{"id":person.id,"name":person.name,"pos":person.pos,"nationName":"France","from":date,"through":Agenda.shift(date,2),"returnDate":Agenda.shift(date,3)}],"returned":[]}}
	app.model = controlled
	app._navigate("Calendrier"); await settle()
	await press("MonthFilter_absences")
	check(app.find_children("CalendarAbsence_*","PanelContainer",true,false).size() > 0,"Absence confirmée affichée sur ses jours")
	check(app.find_child("CalendarOpenAbsences",true,false) != null,"Action vers les disponibilités dans le programme du jour")
	await capture("calendrier-absences-1440")
	view()._select(Agenda.shift(date,3)); await settle()
	var detail: Control = app.find_child("MonthDayDetail",true,false)
	var text := ""
	for label: Label in detail.find_children("*","Label",true,false): text += label.text+" "
	check(text.contains("retour au club"),"Retour au club affiché à sa date publiée")
	await capture("calendrier-retours-1440")
	app.model = original.duplicate(true)
	app._navigate("Calendrier"); await settle()
	await press("MonthFilter_travel")
	var weeks: Control = app.find_child("CalendarWeekGrid",true,false)
	for tile: Control in weeks.find_children("MonthMatch_*","PanelContainer",true,false):
		check(tile.accessibility_name.contains("Extérieur"),"Le filtre déplacement contient seulement des matchs à l’extérieur")
	await capture("calendrier-exterieur-1440")
	check(JSON.stringify(app.model.calendarPlanning.sessions) == sessions,"Séances enregistrées inchangées")
	check(app.bridge._next_id == commands and FileAccess.get_sha256(file) == hash,"Navigation et filtres sans commande ni écriture sportive")
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"profile_unchanged":FileAccess.get_sha256(file)==hash},"  ")); report.close()
	print("CALENDRIER AGENDA : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
