extends SceneTree
const Rooms = preload("res://qa_runner.gd")
const Priorities = preload("res://ui/immersive08/office_priorities.gd")
const Office = preload("res://ui/immersive08/office.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_OFFICE_PRIORITIES_OUTPUT")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func ids(model: Dictionary) -> Array:
	return Priorities.select(model).map(func(item: Dictionary): return item.id)
func base() -> Dictionary:
	return {"club":{"id":1},"meta":{"season":3,"trained":false,"calendarToday":"2026-11-10"},"selection":{"valid":true},"finance":{"cash":1000},"squad":[],"market":[]}
func projections() -> void:
	check(Priorities.select({}).is_empty(),"Sans carrière : aucune priorité inventée")
	var model := base()
	check(ids(model) == ["OfficeTrainingAction","OfficeRecruitmentAction","OfficeSquadPriorityAction"],"Trois accès utiles sans alerte")
	model.next = {"date":"2026-11-12"}
	model.selection = {"valid":false,"errors":["Pilier gauche manquant"]}
	model.clubLife = {"press":{"conference":{"required":true}}}
	model.finance.cash = -10
	check(ids(model) == ["OfficePressPriorityAction","OfficeSelectionPriorityAction","OfficeFinancePriorityAction"],"Ordre des blocages : presse, feuille, trésorerie")
	var before := JSON.stringify(model)
	var selected := Priorities.select(model)
	check(selected[1].detail == "Pilier gauche manquant","Motif réglementaire repris du moteur sans réinterprétation")
	check(JSON.stringify(model) == before and ids(model) == ids(model),"Projection déterministe sans mutation")
	model.live = {"finished":false}
	check(ids(model)[0] == "OfficeLivePriorityAction","Un direct déjà lancé garde la priorité")
	model.live.finished = true
	check(Priorities.select(model)[0].title == "Consulter le résultat","Fin du match : action de consultation explicite")
	model = base()
	model.squad = [{"id":"b","name":"Second","contractEnd":4},{"id":"z","name":"Dernier","contractEnd":3},{"id":"a","name":"Premier","contractEnd":3,"contractLabel":"Fin saison 3 · À prolonger"}]
	selected = Priorities.select(model)
	check(selected[0].id == "OfficeContractsAction" and selected[0].player == "a","Échéance la plus proche puis ID stable")
	check(selected[0].deadline == "Fin de cette saison","Pas de confusion entre échéance actuelle et saison suivante")
	check(selected[0].detail.contains("Fin de contrat 2029") and not selected[0].detail.contains("Fin saison"),"Échéance affichée en année, sans ancien libellé de saison")
	model.squad = [{"id":"a","name":"Joueur","contractEnd":4}]
	check(Priorities.select(model)[0].deadline == "Fin 2030","Contrat suivant daté en année de fin")
	model.squad = []
	model.meta.canAdvanceSeason = true
	check(ids(model)[0] == "OfficeFinalStandingsAction" and "OfficeTrainingAction" not in ids(model),"Clôture : bilan, sans entraînement ouvert")
	model = base()
	model.international = {"availability":{"clubManaged":true,"absentCount":2,"nextReturn":"2026-11-15"}}
	selected = Priorities.select(model)
	check(selected[0].action == "international" and selected[0].deadline.contains("15/11/2026"),"Absences confirmées et date de retour publiées")
	model.international.availability.clubManaged = false
	check("OfficeInternationalPriorityAction" not in ids(model),"Aucune alerte du club pour un mandat sans club")
	model = base()
	model.squad = [{"injury":2}]
	check(ids(model)[0] == "OfficeMedicalPriorityAction","Blessures reliées à l’effectif")
	model.next = {"date":"2026-11-10"}
	model.international = {"availability":{"clubManaged":true,"absentCount":2,"nextReturn":"2026-11-15"}}
	model.squad = [{"id":"a","name":"Joueur","contractEnd":4,"injury":2}]
	check(ids(model) == ["OfficeMatchPriorityAction","OfficeInternationalPriorityAction","OfficeMedicalPriorityAction"],"Match du jour prioritaire sur absences, blessures et contrat de la saison suivante")
	model.meta.canAdvanceSeason = false
	model.meta.phase = "ended"
	model.selection.valid = false
	var closing := ids(model)
	check(closing[0] == "OfficeFinalStandingsAction" and "OfficeTrainingAction" not in closing and "OfficeSelectionPriorityAction" not in closing,"Clôture sportive conservée pendant intersaison internationale")

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : " + app.last_error)
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Capture " + name)
func render(model: Dictionary) -> void:
	app.model = model.duplicate(true)
	app._navigate("Bureau")
	await settle()

func run() -> void:
	projections()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app._command("new_career",{"mode":"common","club":29})
	await wait_engine()
	app.timer.stop()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var original: Dictionary = app.model.duplicate(true)
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(file)
	var commands: int = app.bridge._next_id
	var dimensions_to_check := [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]
	if OS.get_environment("QA_RESOLUTION")=="2560x1440":dimensions_to_check=[Vector2i(2560,1440)]
	for dimensions in dimensions_to_check:
		root.size = dimensions
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dimensions)
		await render(original)
		var tasks := Office.priorities(app.model)
		check(tasks.size() == 3,"Trois priorités raccordées à " + str(dimensions))
		for index in tasks.size():
			var action := app.find_child(tasks[index].id,true,false) as Button
			check(action != null and action.is_visible_in_tree(),"Action visible " + str(tasks[index].id))
			if action == null: continue
			check(action.tooltip_text.contains(tasks[index].deadline) and action.accessibility_name.contains(tasks[index].detail),"Motif et échéance accessibles")
			action.grab_focus(); await process_frame
			check(action.has_focus(),"Focus clavier " + str(tasks[index].id))
			var due := app.find_child("OfficePriorityDeadline"+str(index+1),true,false) as Label
			check(due != null and due.text == tasks[index].deadline,"Échéance affichée")
		check(app.find_child("OpenCoachNotebook",true,false) != null,"Carnet conservé")
		check(app.find_child("OfficeTrainingAction",true,false) != null,"Entraînement reste accessible hors top trois")
		await capture("bureau-priorites-"+str(dimensions.x))
		var press := app.find_child("OfficePressPriorityAction",true,false) as Button
		if press != null:
			press.grab_focus(); await process_frame
			for down: bool in [true,false]:
				var event := InputEventKey.new()
				event.keycode = KEY_ENTER; event.pressed = down
				Input.parse_input_event(event); await process_frame
			await settle()
			check(app.route == "Réception","Entrée sur la priorité presse ouvre la vraie Réception")
		var scenario := original.duplicate(true)
		scenario.clubLife.press.conference.required = false
		scenario.live = null
		scenario.selection.valid = true
		scenario.finance.cash = -1234
		await render(scenario)
		var finances := app.find_child("OfficeFinancePriorityAction",true,false) as Button
		check(finances != null,"Alerte trésorerie négative raccordée")
		if finances != null: finances.pressed.emit(); await settle()
		check(app.route == "Finances","L’alerte ouvre les vrais comptes")
		scenario = original.duplicate(true)
		scenario.clubLife.press.conference.required = false
		scenario.live = null
		scenario.selection.valid = true
		for player: Dictionary in scenario.squad:
			player.contractEnd = 999
			player.injury = 0
		var long_name := "Jean-Baptiste de la Vallée du Grand Pré Saint-Martin des Hautes Terres"
		scenario.squad[0].name = long_name
		scenario.squad[0].contractEnd = int(scenario.meta.season)
		await render(scenario)
		var contract := app.find_child("OfficeContractsAction",true,false) as Button
		check(contract != null and contract.accessibility_name.contains(long_name),"Nom long intégral disponible à la lecture accessible")
		if contract != null:
			check(contract.size.x <= app.find_child("OfficeDecisions",true,false).size.x,"Nom long : action contenue dans la carte")
		scenario = original.duplicate(true)
		scenario.clubLife.press.conference.required = false
		# A paused projection tests the real navigation guard without scheduling
		# a tick against the untouched worker. An active match owns the screen.
		scenario.live = {"finished":false,"paused":true,"minute":35,"score":[7,3],"teams":[original.next.home,original.next.away],"pair":[original.next.home.id,original.next.away.id]}
		var live_priority: Dictionary = Office.priorities(scenario)[0]
		check(live_priority.id == "OfficeLivePriorityAction" and live_priority.action == "match","La projection pure conserve la carte et sa destination direct")
		await render(scenario)
		var director: Node = app.contextual_director
		check(app.route == "Match" and director.active() and director.kind == "live" and not app.root_content.is_visible_in_tree(),"Un direct impose sa vraie surface immersive au lieu d’un Bureau inaccessible")
		var live_view: Control = director.view
		app.model.live.finished = true
		check(Office.priorities(app.model)[0].title == "Consulter le résultat","La projection pure actualise le titre au résultat")
		director.sync()
		check(director.view == live_view and live_view.clock.text == "TERMINÉ" and live_view.finish.visible,"Le résultat actualise les contrôles du direct sans reconstruction")
		app._navigate("Bureau"); await settle()
		check(app.route == "Match" and director.view == live_view,"La consultation du résultat respecte le verrou du directeur sans commande de validation")
		scenario = original.duplicate(true)
		scenario.clubLife.press.conference.required = false
		scenario.meta.phase = "ended"
		scenario.meta.canAdvanceSeason = false
		scenario.live = null
		await render(scenario)
		check(app.find_child("OfficeFinalStandingsAction",true,false) != null and app.find_child("OfficeTrainingAction",true,false) == null,"Intersaison internationale : bilan accessible et entraînement absent")
		await capture("bureau-cloture-"+str(dimensions.x))
	await render(original)
	check(app.bridge._next_id == commands,"Toutes les ouvertures sont sans commande au moteur")
	check(FileAccess.get_sha256(file) == before,"Profil sportif inchangé après consultation et tailles")
	var report := {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"profile_unchanged":FileAccess.get_sha256(file)==before}
	var report_file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"  ")); report_file.close()
	print("BUREAU PRIORITÉS : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
