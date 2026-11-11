extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var nav: Node
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var speech_requests := 0
var speech_starts := 0
var output := OS.get_environment("CD_NIGHT_NAV_OUTPUT")
var group := OS.get_environment("CD_NIGHT_NAV_CASE")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func named(id: String) -> Node: return app.find_child(id, true, false)
func command(id: String, payload: Dictionary = {}) -> bool:
	var accepted: bool = app._command(id, payload)
	check(accepted, "Commande de préparation autorisée : " + id)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	var ok: bool = not app.waiting and app.bridge.last_response_ok
	check(ok, "Réponse du vrai worker : " + id + " · " + app.last_error)
	await settle()
	return accepted and ok
func key(code: Key, alt: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down; event.alt_pressed = alt
		Input.parse_input_event(event); await process_frame
	await settle()
func activate(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Lien rendu présent et visible")
	if control == null: return
	check(control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled), "Lien accessible au clavier : " + str(control.name))
	control.grab_focus(); await settle()
	check(control.has_focus(), "Focus visible prêt : " + str(control.name))
	await key(KEY_ENTER)
func open_entity(kind: String, id: Variant, section: String = "") -> bool:
	var target := {"kind":kind, "id":id}
	if not section.is_empty(): target.section = section
	var accepted: bool = nav.open_entity(target)
	await settle()
	return accepted
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == root.size, "Pixels natifs de la fenêtre : " + id)
	var filename := output.path_join(id + ".png")
	check(image.save_png(filename) == OK, "Capture réelle : " + id)
	captures.append({"file":filename, "width":image.get_width(), "height":image.get_height(), "route":app.route, "sha256":FileAccess.get_sha256(filename)})
func snapshot() -> Dictionary:
	await command("export")
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	return {"file":file, "sha256":FileAccess.get_sha256(file), "state":JSON.parse_string(app.model.meta.exportText).state, "commands":app.bridge._next_id, "model":app.model.duplicate(true)}
func unchanged(before: Dictionary, context: String) -> void:
	check(app.bridge._next_id == before.commands, context + " : aucune commande métier ou lecture worker déclenchée par les liens")
	check(FileAccess.get_sha256(before.file) == before.sha256, context + " : mêmes octets de sauvegarde, seed et horloge persistés")
	await command("export")
	check(JSON.parse_string(app.model.meta.exportText).state == before.state, context + " : état sportif du vrai worker identique")
	check(FileAccess.get_sha256(before.file) == before.sha256, context + " : export de contrôle sans écriture")
func text(node: Node) -> String:
	if node == null: return ""
	var value := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	for child in node.get_children(): value += text(child)
	return value
func back() -> void:
	app.get_viewport().gui_release_focus()
	await key(KEY_LEFT, true)
func entity_control(kind: String, id: Variant) -> Control:
	for control: Control in app.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and str(control.get_meta("entity_kind", "")) == kind and str(control.get_meta("entity_id", "")) == str(id): return control
	return null
func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
	root.push_input(event, true); await process_frame
func motion(point: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	var event := InputEventMouseMotion.new(); event.position = point; event.global_position = point; event.relative = relative
	if held: event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true); await process_frame
func cancel_real_drag() -> void:
	app._navigate("Composition"); await settle()
	var source := named("LineupSlot11") as Control
	var destination := named("LineupSlot14") as Control
	check(source != null and destination != null, "Surfaces de glisser-déposer existantes rendues")
	if source == null or destination == null: return
	var before_commands: int = app.bridge._next_id
	var player_before: String = app.selected_player
	var full_before: bool = app.get_meta("immersive08_full_player", false)
	var start := source.get_global_rect().get_center()
	var target := destination.get_global_rect().get_center()
	await motion(start); await mouse(start, true)
	await motion(start + Vector2(30, 0), Vector2(30, 0), true); await settle()
	check(root.gui_is_dragging(), "Vrai glisser démarré sans ouverture de fiche")
	await motion(target, target - start - Vector2(30, 0), true); await settle()
	await key(KEY_ESCAPE)
	await mouse(target, false); await settle()
	check(not root.gui_is_dragging() and app.route == "Composition" and app.selected_player == player_before and app.get_meta("immersive08_full_player", false) == full_before, "Annulation du glisser distincte d’un clic de consultation")
	check(app.bridge._next_id == before_commands, "Glisser annulé : aucune commande de composition ou consultation")
func setup_career() -> bool:
	var payload := {"mode":"world-champ", "nationalRole":"nation", "nation":"ENG"} if group == "nation" else {"mode":"world-champ", "club":29} if group == "reading" else {"mode":"common", "club":0}
	if not await command("new_career", payload): return false
	if group != "guards" and group != "nation":
		if not await Flow.settle_club_meetings(app, self, check): return false
	return true
func nation_cases() -> void:
	check(app.model.get("international", {}).get("nation") == "ENG", "Carrière réelle : nation gérée anglaise")
	var before := await snapshot()
	check(await open_entity("nation", "FRA"), "France ouverte par son identifiant depuis une autre nation gérée")
	var detail := named("InternationalNationDetails")
	check(detail != null and text(detail).contains("France"), "La destination consultée affiche réellement France")
	check(app.management_ui.get("international", {}).get("navigation_id") == "FRA", "Cible de consultation française distincte du mandat")
	check(app.model.international.nation == "ENG" and app.model.international.role == before.model.international.role, "Aucune candidature ni prise de poste française")
	await capture("nation-france-depuis-angleterre-2560")
	var route_before: String = app.route
	var ui_before: Dictionary = app.management_ui.duplicate(true)
	check(not await open_entity("nation", "__absente__"), "Nation inconnue refusée sans destination de repli")
	check(app.route == route_before and app.management_ui == ui_before, "Refus nation inconnue : consultation existante préservée")
	await unchanged(before, "Consultation de la France")
func reading_cases() -> void:
	var before := await snapshot()
	var id := str(app.model.squad[0].id)
	app._navigate("Effectif"); await settle()
	var search := named("RosterSearch") as LineEdit
	check(search != null, "Recherche de l’effectif réellement rendue")
	if search == null: return
	search.text = "___aucun___"; search.text_changed.emit(search.text)
	search.grab_focus(); search.caret_column = 4; search.select(2, 6)
	await settle()
	var reading: Dictionary = app.management_ui.roster.duplicate(true)
	check(await open_entity("player", id), "Joueur du club ouvert par identifiant stable")
	check(app.selected_player == id and app.get_meta("immersive08_full_player", false), "Bonne fiche complète du joueur")
	await capture("joueur-fiche-2560")
	await back()
	search = named("RosterSearch") as LineEdit
	check(search != null and search.text == "___aucun___" and app.management_ui.roster.search == reading.search, "Retour : recherche et filtre exclusif conservés")
	check(search != null and search.has_focus() and search.caret_column == 4 and search.get_selection_from_column() == 2 and search.get_selection_to_column() == 6, "Retour : focus, curseur et sélection de saisie conservés")
	var reset := named("RosterReset") as Button
	if reset != null: reset.pressed.emit(); await settle()
	var sort := named("RosterSort") as OptionButton
	if sort != null and sort.item_count > 1:
		var selected_before: String = app.selected_player
		sort.grab_focus(); sort.select(1); sort.item_selected.emit(1); await settle()
		check(app.route == "Effectif" and app.selected_player == selected_before and not app.get_meta("immersive08_full_player", false), "Tri de colonne/liste distinct d’une ouverture d’entité")
	var scroll := named("SquadScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = mini(150, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
		await settle()
		var offset: int = scroll.scroll_vertical
		check(await open_entity("player", id), "Deuxième consultation depuis une liste défilée")
		await back()
		check(named("SquadScroll") != null and named("SquadScroll").scroll_vertical == offset, "Retour : défilement exact de la liste conservé")
	check(await open_entity("player", id), "Fiche source des drapeaux réellement ouverte")
	var flag: Control = named("PlayerOriginNationLink")
	if flag == null: flag = named("PlayerCapsNationLink")
	check(flag != null, "Drapeau de la vraie fiche rendu comme lien")
	if flag != null:
		var nation_id := str(flag.get_meta("entity_id", ""))
		await activate(flag)
		check(app.route == "Sélections" and app.management_ui.get("international", {}).get("navigation_id") == nation_id, "Entrée sur le vrai drapeau ouvre exactement sa nation")
		await back()
		check(app.route == "Effectif" and app.selected_player == id, "Retour du drapeau vers la même fiche joueur")
	var market: Array = app.model.get("market", [])
	check(not market.is_empty(), "Cible hors club réellement projetée")
	if not market.is_empty():
		var outsider: Dictionary = market[0]
		var outsider_before := JSON.stringify(outsider)
		check(await open_entity("market", str(outsider.id)), "Cible hors club : dossier de recrutement par ID")
		check(app.route == "Recrutement" and str(app.management_ui.market.get("navigation_id", "")) == str(outsider.id), "Bonne piste ouverte sans homonyme")
		check(JSON.stringify(app.model.market[0]) == outsider_before, "Aucune information supplémentaire injectée dans la projection hors club")
		await capture("recrutement-cible-2560")
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	if not teams.is_empty() and not teams[0].get("members", []).is_empty():
		var person: Dictionary = teams[0].members[0]
		check(await open_entity("staff", str(person.id)), "Membre du staff ouvert par son identifiant")
		check(named("StaffProfile") != null and text(named("StaffProfileName")) == str(person.name) + "\n", "Profil du membre de staff exact")
		await capture("staff-profil-2560")
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if not next.is_empty():
		var opponent: Dictionary = next.away if int(next.home.id) == int(app.model.club.id) else next.home
		check(await open_entity("club", opponent.id), "Club adverse ouvert dans son détail existant")
		var club_detail := named("CompetitionClubDetails")
		check(club_detail != null and str(club_detail.get_meta("entity_id", "")) == str(opponent.id), "Détail du bon ID de club adverse effectivement rendu")
		check(text(club_detail).contains(str(opponent.name)), "Nom du bon club adverse effectivement rendu")
		await capture("club-adverse-2560")
		app._clear_dialogs(); await settle()
	await cancel_real_drag()
	for resolution in [Vector2i(1280,720), Vector2i(1440,900), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		check(await open_entity("player", id), "Même fiche par ID à " + str(resolution))
		await settle()
		check(app.selected_player == id and root.size == resolution, "Bonne destination et dimensions exactes à " + str(resolution))
		await capture("fiche-%d-%d" % [resolution.x, resolution.y])
	await unchanged(before, "Parcours joueurs staff clubs")
func guard_refusal(context: String) -> void:
	var before := await snapshot()
	var route_before: String = app.route
	var scene_before: String = app.contextual_director.kind
	var ui_before: Dictionary = app.management_ui.duplicate(true)
	var id := str(app.model.squad[0].id)
	check(not await open_entity("player", id), context + " : lien refusé proprement")
	check(app.route == route_before and app.contextual_director.kind == scene_before and app.management_ui == ui_before, context + " : scène et état de lecture préservés")
	await unchanged(before, context)
func guard_cases() -> void:
	check(app.contextual_director.active_meeting(), "Rendez-vous réel initial présent")
	if app.contextual_director.active_meeting(): await guard_refusal("Rendez-vous obligatoire")
	if not await Flow.settle_club_meetings(app, self, check): return
	if not await Flow.prepare_match_day(app, self, check): return
	await command("auto_lineup")
	await command("begin_match")
	check(app.contextual_director.kind == "locker", "Vraie causerie avant-match")
	await guard_refusal("Causerie obligatoire")
	await Flow.skip_talk(app, self, "pre", check)
	app.timer.stop()
	await command("pause", {"paused":true})
	check(app.contextual_director.kind == "live", "Vrai match immersif en pause")
	await guard_refusal("Match immersif")
	await capture("navigation-refusee-match-2560")
	await command("delegate")
	if app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") is Dictionary:
		await Flow.skip_talk(app, self, "post", check)
	elif app.model.get("live") is Dictionary:
		await command("finish_round")
	if not await Flow.settle_club_meetings(app, self, check): return
	var historical: Dictionary = {}
	for fixture: Dictionary in app.model.get("calendar", []):
		if fixture.get("played", false) and fixture.get("score") is Array:
			historical = fixture; break
	check(not historical.is_empty(), "Rencontre historique réellement produite par le moteur")
	if not historical.is_empty():
		var before := await snapshot()
		check(await open_entity("fixture", historical.id), "Score historique : détail du vrai identifiant de rencontre")
		var detail := named("CompetitionFixtureDetails")
		check(detail != null and str(detail.get_meta("entity_id", "")) == str(historical.id), "Fenêtre historique du même identifiant, sans rencontre substituée")
		await capture("rencontre-historique-2560")
		await unchanged(before, "Consultation du résultat historique")
func finish() -> void:
	if is_instance_valid(app.coach):
		check(app.coach.speech.muted and not app.coach.speech.speaking and app.coach.speech.player == null, "Gabi silencieux, aucun lecteur audio")
	check(speech_requests == 0 and speech_starts == 0, "Compteurs de parole : zéro demande et zéro début")
	var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"case":group,"display":DisplayServer.get_name(),"engine":Engine.get_version_info(),"captures":captures,"speech_requests":speech_requests,"speech_starts":speech_starts}, "  ")); report.close()
	print("NAVIGATION NOCTURNE ", group, " : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	await app._close(0 if failures.is_empty() else 1)
func run() -> void:
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale du vrai worker reçue")
	app.timer.stop()
	if is_instance_valid(app.coach):
		app.coach.speech.set_muted(true)
		app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
		app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	nav = app.navigation_controller
	check(nav.has_method("open_entity"), "API commune d’entité raccordée au vrai main")
	if not nav.has_method("open_entity") or not await setup_career(): await finish(); return
	match group:
		"nation": await nation_cases()
		"guards": await guard_cases()
		_: await reading_cases()
	await finish()
