extends SceneTree
const Briefing = preload("res://ui/preparation_briefing.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_PREPARATION_BRIEFING_OUTPUT")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func base() -> Dictionary:
	return {"meta":{"phase":"league","calendarCadence":{"matchReady":true}},"next":{"id":"fixture"},"clubLife":{"press":{"conference":{"required":true}}},"selection":{"valid":false,"errors":["Pilier gauche manquant"]},"squad":[{"injury":1}],"international":{"availability":{"clubManaged":true,"absentCount":2,"nextReturn":"2027-02-08"}}}
func projections() -> void:
	var model := base()
	var before := JSON.stringify(model)
	var report := Briefing.project(model)
	check(report.checks.map(func(row: Dictionary): return row.id).slice(0,3) == ["press","selection","day"], "La presse et la feuille précèdent le match du jour, puis les alertes d’effectif")
	check(report.checks[1].detail == "Pilier gauche manquant", "Motif exact de la feuille projetée")
	check(not report.reportAvailable and report.domains == 0 and report.recent == 0, "Données adverses absentes explicitement inconnues")
	check(JSON.stringify(model) == before, "Projection sans mutation")
	model.meta.calendarCadence.matchReady = false
	check(not Briefing.project(model).checks.any(func(row: Dictionary): return row.id == "day"), "Aucune autorisation de match déduite sans le signal du moteur")
	model.meta.phase = "ended"
	model.meta.canAdvanceSeason = false
	check(Briefing.project(model).checks.map(func(row: Dictionary): return row.id) == ["ended"], "Intersaison : clôture reconnue malgré le calendrier international")
	model.live = {"finished":false}
	check(Briefing.project(model).checks[0].action == "match", "Direct prioritaire sur une préparation future")
	model.live.finished = true
	check(Briefing.project(model).checks[0].title.contains("Résultat"), "Résultat terminé explicitement consultable")
	model = {"meta":{},"selection":{"valid":false}}
	check(Briefing.project(model).checks.map(func(row: Dictionary): return row.id) == ["tactics"], "Sans rencontre : aucune urgence de feuille inventée")

func wait_worker() -> bool:
	var until := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and app.last_error.is_empty() and Time.get_ticks_msec() < until: await process_frame
	await settle()
	return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok
func enter(button: Button) -> void:
	check(button != null and button.is_visible_in_tree(), "Action de briefing réellement affichée")
	if button == null: return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus du briefing")
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER; event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()
func render(model: Dictionary) -> void:
	app.model = model.duplicate(true)
	app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	app._navigate("Préparation")
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(2560,1440), "Capture native 1440p")
	check(image.save_png(output.path_join(name + ".png")) == OK, "Capture " + name)
func run() -> void:
	projections()
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	check(await wait_worker(), "Démarrage du vrai moteur")
	app.timer.stop()
	app._command("new_career", {"mode":"common","club":29})
	check(await wait_worker(), "Carrière réelle créée")
	if app.model.is_empty() or not app.bridge.last_response_ok:
		await app._close(1)
		return
	if DisplayServer.get_name() != "headless":
		if root.size_changed.is_connected(app._keep_filled_display): root.size_changed.disconnect(app._keep_filled_display)
		if root.focus_entered.is_connected(app._keep_filled_display): root.focus_entered.disconnect(app._keep_filled_display)
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(2560,1440)
		await settle()
	var original: Dictionary = app.model.duplicate(true)
	var profile: String = app.model.meta.dataDir.path_join("donnees.json")
	var disk := FileAccess.get_sha256(profile)
	var commands: int = app.bridge._next_id
	await render(original)
	check(app.find_child("PreparationBriefingAll",true,false) != null, "Briefing raccordé au dossier actuel")
	check(app.find_child("PreparationAdoptPlan",true,false) != null and app.find_child("OpenOppositionDossier",true,false) != null, "Accès directs au dossier et au plan du staff conservés")
	check(app.find_children("PreparationXIPlayer_*","Button",true,false).size() == 15, "Schéma XV raccordé aux quinze cases publiées")
	await capture("preparation-briefing-reel-1440")
	var first := app.find_child("PreparationXIPlayer_1",true,false) as Button
	if first != null and not first.disabled:
		var expected: Variant = first.get_meta("player_id")
		await enter(first)
		check(app.route == "Effectif" and app.selected_player == expected, "Entrée sur le XV ouvre la vraie fiche du titulaire")
	var controlled := original.duplicate(true)
	controlled.clubLife.press.conference.required = true
	controlled.selection = {"valid":false,"errors":["Poste à compléter · recette UI"]}
	controlled.meta.calendarCadence = {"matchReady":true}
	controlled.international = {"availability":{"clubManaged":true,"absentCount":2,"nextReturn":"2027-02-08"}}
	await render(controlled)
	await enter(app.find_child("PreparationBriefing_press",true,false) as Button)
	check(app.route == "Réception", "Entrée sur la presse ouvre la vraie invitation, sans lancer le match")
	await render(controlled)
	await enter(app.find_child("PreparationBriefing_selection",true,false) as Button)
	check(app.route == "Composition", "La feuille mène à la composition")
	await render(controlled)
	await enter(app.find_child("PreparationBriefingAll",true,false) as Button)
	var dialog := app.find_child("PreparationAllChecks",true,false) as AcceptDialog
	check(dialog != null and dialog.visible, "Tous les repères consultables sans commande")
	await enter(dialog.find_child("PreparationBriefingAll_international",true,false) as Button if dialog != null else null)
	check(app.route == "Sélections" and app.management_ui.international_section == "availability", "Le briefing ouvre le suivi des absents")
	var unknown := original.duplicate(true)
	unknown.decisions.preparation = {}
	await render(unknown)
	check(app.find_child("PreparationKnownOpponent",true,false) != null, "L’adversaire connu reste affiché sans statistiques publiées")
	check(app.find_child("PreparationUnknownOpponent",true,false) != null, "L’absence de dossier est lisible")
	await capture("preparation-adversaire-sans-dossier-1440")
	check(app.bridge._next_id == commands, "Aucune commande sportive à la lecture ou à la navigation")
	check(FileAccess.get_sha256(profile) == disk, "Profil sportif inchangé")
	print("BRIEFING PRÉPARATION : %d contrôles ; %d échecs" % [checks, failures.size()])
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"fixtures":"real career then explicit UI projections"},"  "))
	file.close()
	await app._close(0 if failures.is_empty() else 1)
