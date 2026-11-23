extends SceneTree
const Rooms = preload("res://qa_runner.gd")
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
## Programme du mois (Entraînement › Mois) : il remplace la grille du Calendrier depuis le 22/11/2026.
func view() -> Control:
	return app.find_child("TrainingMonthGrid",true,false)
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
	app._command("new_career",{"mode":"world-champ","club":29})
	await wait_engine(); app.timer.stop()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var original: Dictionary = app.model.duplicate(true)
	var file := str(original.meta.dataDir).path_join("donnees.json")
	var hash := FileAccess.get_sha256(file)
	var commands: int = app.bridge._next_id
	var sessions := JSON.stringify(original.get("calendarPlanning",{}).get("sessions",[]))
	var Mois = load("res://ui/immersive08/training_mois.gd")
	Mois.ouvrir(app); await settle()
	check(view() != null,"Mois disponible dans le vrai entraînement")
	var today := str(original.get("calendarPlanning",{}).get("today",""))
	check(app.find_child("TrainingMonthDay_"+today,true,false) != null,"Le jour courant est dans la grille")
	await capture("calendrier-mois-1440")
	await press("TrainingMonthNext")
	var etat: Dictionary = app.management_ui.immersive_training
	check(str(etat.get("mois","")) > today.substr(0,7),"Suivant avance d’un mois")
	await press("TrainingMonthPrev")
	check(str(etat.get("mois","")) == today.substr(0,7),"Précédent revient au mois du jour")
	# Absence publiée : pastille sur ses jours, détail (absent puis retour) dans la petite fenêtre du jour.
	var controlled := original.duplicate(true)
	var person: Dictionary = original.squad[0]
	controlled.international = {"role":"club","teams":[],"availability":{"clubManaged":true,"absentCount":1,"nextReturn":Agenda.shift(today,3),"players":[{"id":person.id,"name":person.name,"pos":person.pos,"nationName":"France","from":today,"through":Agenda.shift(today,2),"returnDate":Agenda.shift(today,3)}],"returned":[]}}
	app.model = controlled
	Mois.ouvrir(app); await settle()
	var marques := 0
	for k in 3: if app.find_child("TrainingMonthAbsence_"+Agenda.shift(today,k),true,false) != null: marques += 1
	check(marques == 3 or today.substr(0,7) != Agenda.shift(today,2).substr(0,7),"Absence confirmée affichée sur ses jours (%d)" % marques)
	await capture("calendrier-absences-1440")
	await press("TrainingMonthDayOpen_"+today)
	check(app.find_child("TrainingMonthDayAbsence0",true,false) != null,"Absence dans la petite fenêtre du jour")
	Mois.ouvrir(app, Agenda.shift(today,3), true); await settle()
	var fenetre: Control = app.find_child("TrainingMonthDayWindow",true,false)
	var text := ""
	if fenetre != null:
		for label: Label in fenetre.find_children("*","Label",true,false): text += label.text+" "
	check(text.contains("Retour"),"Retour au club affiché à sa date publiée")
	await capture("calendrier-retours-1440")
	app.model = original.duplicate(true)
	Mois.ouvrir(app); await settle()
	check(JSON.stringify(app.model.calendarPlanning.sessions) == sessions,"Séances enregistrées inchangées")
	check(app.bridge._next_id == commands and FileAccess.get_sha256(file) == hash,"Navigation sans commande ni écriture sportive")
	var report := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"profile_unchanged":FileAccess.get_sha256(file)==hash},"  ")); report.close()
	print("CALENDRIER AGENDA : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
