extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
var watched_id := ""
var advice_fixture: Control
class AdviceHost extends Control:
	var model: Dictionary = {}
	var accent := Color("234e53")
	var waiting := false
	var management_ui: Dictionary = {}
	var sent: Array = []
	func _command(id: String, payload: Dictionary) -> bool:
		sent.append({"id":id,"payload":payload.duplicate(true)})
		return true
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 6: await process_frame
func wait_model() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Réponse réelle du worker : " + app.last_error)
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_model()
func state() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state
func load_fixture(id: String) -> void:
	await command("import", {"text":FileAccess.get_file_as_string(OS.get_environment("CD_PLAYBOOK_WATCH_ARTIFACTS").path_join(id + ".json"))})
func keyboard(button: BaseButton) -> void:
	check(button != null and not button.disabled, "Bouton activable au clavier")
	if button == null or button.disabled: return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus clavier obtenu")
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await wait_model()
func advice_buttons() -> Array:
	return advice_fixture.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("ADAPTER « "))
func advice_page() -> Control:
	return advice_fixture.find_child("PlaybookTabs", true, false).get_child(2)
func labels(node: Node) -> String:
	var text: String = node.text + "\n" if node is Label else ""
	for child in node.get_children(): text += labels(child)
	return text
func watch_button() -> Button:
	for b: Button in app.body.find_children("Follow*", "Button", true, false):
		if b.is_visible_in_tree() and str(b.get_meta("follow_id", "")) == watched_id: return b
	return null
func reveal_watch_button() -> Button:
	for direction in ["Previous", "Next"]:
		for _page in range(app.model.market.size() + 1):
			var track := watch_button()
			if track != null: return track
			for row: Button in app.body.find_children("MarketPlayer_*", "Button", true, false):
				if row.is_visible_in_tree() and str(row.get_meta("player_id", "")) == watched_id:
					await keyboard(row)
					return watch_button()
			var step := app.body.find_child("MarketPagination" + direction, true, false) as Button
			if step == null or not step.is_visible_in_tree() or step.disabled: break
			await keyboard(step)
	return null
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_model()
	app.timer.stop()
	await playbook_case()
	await watch_case()
	app.closing = true
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 4500
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Le moteur ferme le profil avant la reprise")
	var report := FileAccess.open(OS.get_environment("CD_PLAYBOOK_WATCH_ARTIFACTS").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"watchedId":watched_id}, "  "))
	report.close()
	print("UI C04/C08 : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
func playbook_case() -> void:
	await load_fixture("live")
	app.timer.stop()
	var data: Dictionary = app.model.clubLife.playbook
	check(data.general.attack == "conquete" and data.general.defence == "prudente" and data.staffAdvice.suggestions.is_empty() and data.staffAdvice.zoneSuggestions.size() == 1, "Fixture réelle : général correct et seul conflit local")
	var surface: Control = app.match_screen
	for route in ["Plan de jeu", "Recrutement"]:
		app._navigate(route); await settle()
		check(app.route == "Match" and app.contextual_director.kind == "live" and app.match_screen == surface, "Direct réel : navigation verrouillée vers " + route)
	check(not app.root_content.is_visible_in_tree(), "Le carnet de gestion reste masqué pendant le direct")
	# Receive the retained classic advice renderer as an explicit isolated UI
	# projection. It is no longer a navigable screen during the live match.
	var host := AdviceHost.new(); root.add_child(host); host.model=app.model.duplicate(true)
	host.z_index=110; host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	advice_fixture=preload("res://ui/playbook_view.gd").build(host);host.add_child(advice_fixture)
	advice_fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tabs:=advice_fixture.find_child("PlaybookTabs",true,false) as TabContainer
	tabs.current_tab=2;await settle()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		check(advice_buttons().size()==1,"Projection du renderer conservé : conseil local visible " + str(resolution))
		check(not labels(advice_page()).contains("Aucune consigne supplémentaire"),"Projection : aucune fausse absence de conseil")
	var before: Dictionary=await state()
	await keyboard(advice_buttons()[0])
	check(host.sent.size()==1 and host.sent[0].id=="playbook_staff_zone","Le contrôle conservé construit la commande exacte")
	if host.sent.size()==1:
		await command(host.sent[0].id,host.sent[0].payload)
		var after: Dictionary=await state()
		check(after.live.playbooks[0].zones.sortie.attack=="conquete" and after.manager.playbook.zones.sortie.attack=="conquete","La commande publique réelle corrige la seule zone contradictoire")
		after.live.playbooks[0].zones.sortie.attack="large";after.manager.playbook.zones.sortie.attack="large"
		check(after.tactic==before.tactic and after.defence==before.defence and after.live.tactics==before.live.tactics and after.live.defences==before.live.defences,"Plans généraux inchangés")
		check(after.live.playbooks==before.live.playbooks and after.manager.playbook==before.manager.playbook,"Aucune autre zone ni phase arrêtée modifiée")
	# Independent projected rows keep the duplicate and availability contracts.
	host.model.clubLife.playbook=data.duplicate(true)
	host.model.clubLife.playbook.staffAdvice.suggestions=data.staffAdvice.zoneSuggestions.duplicate(true)
	advice_fixture.queue_free();await settle()
	advice_fixture=preload("res://ui/playbook_view.gd").build(host);host.add_child(advice_fixture)
	advice_fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(advice_fixture.find_child("PlaybookTabs",true,false) as TabContainer).current_tab=2;await settle()
	check(advice_buttons().size()==1,"Projection : conseils généraux et locaux dédoublonnés")
	host.model.clubLife.playbook.available=false
	advice_fixture.queue_free();await settle()
	advice_fixture=preload("res://ui/playbook_view.gd").build(host);host.add_child(advice_fixture)
	advice_fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(advice_fixture.find_child("PlaybookTabs",true,false) as TabContainer).current_tab=2;await settle()
	check(advice_buttons().size()==1 and advice_buttons().all(func(b):return b.disabled),"Projection : conseil visible mais indisponible quand le carnet est fermé")
	host.queue_free();await settle();advice_fixture=null
func watch_case() -> void:
	await load_fixture("full")
	app._navigate("Recrutement")
	await settle()
	watched_id = str(app.model.market[0].id)
	check(app.model.clubLife.managerCareer.places == 0 and not app.model.clubLife.managerCareer.recruitmentAvailable, "Fixture réelle : effectif plein et embauche indisponible")
	var followed := app.body.find_child("MarketFollowed", true, false) as Button
	check(followed != null and followed.text == "Joueurs suivis", "Le filtre décrit le suivi persistant")
	var before: Dictionary = await state()
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		app._navigate("Recrutement")
		await settle()
		var control := await reveal_watch_button()
		check(control != null and not control.disabled, "Suivre reste activable à effectif plein " + str(resolution))
	var track := watch_button()
	if track == null or track.disabled: return
	await keyboard(track)
	check(app.last_command == "manager_recruitment_watch", "Commande exacte de suivi depuis Entrée")
	var after: Dictionary = await state()
	check(after.manager.watch == [watched_id], "Le suivi est enregistré par le vrai moteur")
	check(after.clubs[after.club].players == before.clubs[before.club].players and after.clubs[after.club].cash == before.clubs[before.club].cash, "Suivre ne recrute personne et ne coûte rien")
	track = await reveal_watch_button()
	check(track != null and track.text.to_lower() == "retirer du suivi" and not track.disabled, "Retrait activable à effectif plein")
	if track == null or track.disabled: return
	await keyboard(track)
	check(app.last_command == "manager_recruitment_watch" and app.model.clubLife.managerCareer.watch.is_empty(), "Retrait réel sans recrutement")
	await keyboard(await reveal_watch_button())
	await command("export")
	var saved: String = app.model.meta.exportText
	await command("new_career", {"club":1,"mode":"fiction"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("import", {"text":saved})
	check(app.management_ui.shortlist == [watched_id] and app.model.clubLife.managerCareer.places == 0, "Import : suivi persistant et effectif toujours plein")
	app._navigate("Recrutement")
	await settle()
	await keyboard(app.body.find_child("MarketFollowed", true, false))
	track = await reveal_watch_button()
	check(app.management_ui.market.followed and track != null and track.text.to_lower() == "retirer du suivi" and not track.disabled, "Après import, le filtre Joueurs suivis rend le retrait accessible")
	var desktop := root.size
	root.size = Vector2i(1280,720)
	await settle()
	track = watch_button()
	check(track != null and not track.disabled, "Le suivi reste accessible après réduction de la fenêtre ouverte")
	root.size = desktop
	await settle()
	var original: Dictionary = app.model.duplicate(true)
	# Explicit UI projections for guards, no state or fixture mutation in the worker.
	for phase in ["barrage", "semi", "final", "ended"]:
		app.model.meta.phase = phase
		app.model.meta.canAdvanceSeason = false
		app._render()
		await settle()
		track = watch_button()
		check(track != null and track.disabled == (phase == "ended"), "Projection UI : garde de phase " + phase)
	app.model = original.duplicate(true)
	app.waiting = true
	app._render()
	await settle()
	track = watch_button()
	check(track != null and track.disabled, "Projection UI : commande en attente bloque le suivi")
	app.waiting = false
	await load_fixture("live")
	app._navigate("Recrutement")
	await settle()
	check(not app._live().is_empty() and app.route == "Match" and app.contextual_director.kind == "live", "Vrai match en pause : recrutement inaccessible par la garde contextuelle")
	check(not app.root_content.is_visible_in_tree(), "Le suivi ne peut pas être actionné dans une page de gestion masquée")
	# Restore the save produced by the keyboard action for process restart.
	await command("import", {"text":saved})
