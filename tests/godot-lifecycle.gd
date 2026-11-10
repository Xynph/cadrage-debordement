extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
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
	await response(id)
func response(id: String) -> void:
	var until := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Commande " + id)
	await settle()
func button(id: String) -> Button:
	for item: Button in app.find_children(id, "Button", true, false):
		if item.is_visible_in_tree() and not item.disabled: return item
	return null
func own_staff() -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.id) == int(app.model.club.id): return team.members
	return []
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_LIFECYCLE_CAPTURES").path_join(id + ".png")) == OK, "Capture " + id)
func sign_contract() -> void:
	var dialog := app.find_child("StaffContract", true, false) as AcceptDialog
	check(dialog != null and dialog.visible, "Contrat de staff réellement ouvert")
	var confirm := button("StaffContractConfirm")
	check(confirm != null, "Confirmation du contrat disponible")
	if confirm != null: confirm.pressed.emit(); await response("contrat staff")
func confirmation(accept: bool) -> void:
	var dialogs := app.find_children("*", "ConfirmationDialog", true, false).filter(func(d): return d.visible)
	check(not dialogs.is_empty(), "Confirmation explicite d’activation")
	if dialogs.is_empty(): return
	if accept: dialogs[0].confirmed.emit(); await response("activation")
	else: dialogs[0].canceled.emit(); await settle()
func run() -> void:
	root.size = Vector2i(1280, 800)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await command("snapshot")
	await command("new_career", {"mode":"common", "club":1})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("export")
	var before: String = app.model.meta.exportText
	var profile: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(profile)
	for size in [Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = size; await settle()
		app._navigate("Staff"); await settle()
		check(app.body.find_child("StaffCareerOverview", true, false) != null, "Carrières du staff visibles dans le jeu")
		check(app.body.find_children("*", "TextureRect", true, false).size() > 0, "Visages présents dans le staff")
		check(app.body.find_child("StaffClub", true, false) != null, "Annuaire des clubs disponible")
		await capture("staff-" + str(size.x))
		app._navigate("Recrutement"); await settle()
		var market_tabs := app.body.find_child("MarketTabs", true, false) as TabContainer
		if market_tabs != null:
			for i in market_tabs.get_tab_count():
				if str(market_tabs.get_tab_control(i).name) == "RecruitmentStaff": market_tabs.current_tab = i
			await settle()
		var needs := button("OpenRecruitmentNeeds")
		if needs == null: needs = button("OpenScoutMission")
		if needs == null: needs = button("OpenEmptyRecruitmentNeeds")
		check(needs != null, "Besoins du club accessibles")
		if needs != null: needs.pressed.emit(); await settle()
		var scout_tabs := app.find_child("ScoutTabs", true, false) as TabContainer
		if scout_tabs != null: scout_tabs.current_tab = 0; await settle()
		var population := app.find_child("PopulationOverview", true, false) as Control
		check(population != null and population.is_visible_in_tree(), "Vivier persistant présenté au recrutement")
		app._clear_dialogs(); await settle()
	await command("export")
	check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(profile) == bytes, "Navigation et portraits sans mutation état/RNG/disque")
	var skin = load("res://ui/game_skin.gd")
	var original: TextureRect = skin.portrait(0, 60, {"id":"staff-fixture","identity":{"portraitPath":ProjectSettings.globalize_path("res://art/regen-staff-atlas.png"),"portraitStatus":"official"}})
	check(original.texture != null and original.material == null and original.tooltip_text.contains("officielle"), "Portrait officiel imbriqué prioritaire sur le générateur")
	original.free()
	var fallback: TextureRect = skin.portrait(0, 60, {"id":"regen-fixture","age":23,"portraitPath":"/missing/portrait.png"})
	check(fallback.texture != null and fallback.material != null, "Image absente remplacée par un portrait composé")
	fallback.free()
	app._navigate("Staff"); await settle()
	var renew := button("StaffRenew")
	check(renew != null, "Prolongation disponible dans le vrai staff")
	if renew != null:
		var id := str(renew.get_meta("staff_id"))
		var old_end := -1
		for p: Dictionary in own_staff():
			if str(p.id) == id: old_end = int(p.contractEnd)
		renew.pressed.emit(); await settle(); await sign_contract()
		check(own_staff().any(func(p: Dictionary): return str(p.id) == id and int(p.contractEnd) > old_end), "Prolongation réellement enregistrée")
	var release := button("StaffRelease")
	check(release != null, "Libération disponible")
	if release != null:
		var id := str(release.get_meta("staff_id"))
		release.pressed.emit(); await settle()
		var confirms := app.find_children("*", "ConfirmationDialog", true, false).filter(func(d): return d.visible)
		check(not confirms.is_empty(), "Départ soumis à confirmation dans le jeu")
		if not confirms.is_empty(): confirms[0].confirmed.emit(); await response("staff_release")
		check(not own_staff().any(func(p: Dictionary): return str(p.id) == id), "Membre libéré sorti de l’équipe")
	var tab := app.body.find_child("StaffCareerTab", true, false) as OptionButton
	if tab != null: tab.select(1); tab.item_selected.emit(1); await settle()
	var hire := button("StaffHire")
	check(hire != null, "Candidats réellement recrutables")
	if hire != null:
		var id := str(hire.get_meta("staff_id"))
		hire.pressed.emit(); await settle(); await sign_contract()
		check(own_staff().any(func(p: Dictionary): return str(p.id) == id), "Candidat engagé dans le vrai état de carrière")
	# Build/import a real v1 career through its historical initializer; no v2
	# players or provenance fields are removed to fake a legacy document.
	var legacy := FileAccess.get_file_as_string(OS.get_environment("CD_LIFECYCLE_LEGACY"))
	await command("import", {"text":legacy})
	check(not app.model.meta.population.active and not app.model.clubLife.staffCareer.active, "Import ancien sans activation silencieuse")
	await command("export")
	var old_export: String = app.model.meta.exportText
	var old_clubs: String = JSON.stringify(JSON.parse_string(old_export).state.clubs)
	var old_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile))
	root.size = Vector2i(1280, 800)
	app._navigate("Staff"); await settle()
	var enable_staff := button("EnableStaffCareer")
	check(enable_staff != null, "Ancienne carrière propose le staff sans l’imposer")
	if enable_staff != null: enable_staff.pressed.emit(); await settle(); await confirmation(false)
	await command("export")
	check(app.model.meta.exportText == old_export, "Annuler l’activation conserve exactement l’ancienne carrière")
	enable_staff = button("EnableStaffCareer")
	if enable_staff != null: enable_staff.pressed.emit(); await settle(); await confirmation(true)
	check(app.model.clubLife.staffCareer.active and not app.model.meta.population.active, "Activation staff indépendante depuis le vrai bouton")
	app._navigate("Recrutement"); await settle()
	var old_tabs := app.body.find_child("MarketTabs", true, false) as TabContainer
	if old_tabs != null:
		for i in old_tabs.get_tab_count():
			if str(old_tabs.get_tab_control(i).name) == "RecruitmentStaff": old_tabs.current_tab = i
		await settle()
	var open_needs := button("OpenRecruitmentNeeds")
	if open_needs == null: open_needs = button("OpenScoutMission")
	check(open_needs != null, "Accès au renouvellement de l’ancienne population")
	if open_needs != null: open_needs.pressed.emit(); await settle()
	var old_scout_tabs := app.find_child("ScoutTabs", true, false) as TabContainer
	if old_scout_tabs != null: old_scout_tabs.current_tab = 0; await settle()
	var enable_population := button("EnablePopulation")
	check(enable_population != null, "Bouton d’activation du renouvellement disponible")
	if enable_population != null: enable_population.pressed.emit(); await settle(); await confirmation(true)
	check(app.model.meta.population.active and app.model.clubLife.staffCareer.active, "Vivier activé en conservant le staff déjà actif")
	await command("export")
	check(JSON.stringify(JSON.parse_string(app.model.meta.exportText).state.clubs) == old_clubs, "Activations sans changer joueurs, clubs et trésoreries")
	var final_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile))
	check(final_profile.seed == old_profile.seed, "Activations sans consommer le RNG sportif")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
