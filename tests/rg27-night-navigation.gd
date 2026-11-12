extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
const GameSkin = preload("res://ui/game_skin.gd")
var app: Control
var nav: Node
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var visits: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var speech_requests := 0
var speech_starts := 0
var output := OS.get_environment("CD_NIGHT_NAV_OUTPUT")
var group := OS.get_environment("CD_NIGHT_NAV_CASE")
var progress_started: int = Time.get_ticks_msec()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	progress("initialize")
	call_deferred("run")
func progress(stage: String, extra: Dictionary = {}) -> void:
	var entry: Dictionary = {"stage":stage,"elapsed_ms":Time.get_ticks_msec()-progress_started,"case":group,"checks":checks}
	if is_instance_valid(app):
		entry.route = app.route
		entry.waiting = app.waiting
		entry.command = app.last_command
		entry.error = app.last_error
	entry.merge(extra,true)
	var file: String = output.path_join("progress.jsonl")
	var access: FileAccess = FileAccess.open(file,FileAccess.READ_WRITE if FileAccess.file_exists(file) else FileAccess.WRITE)
	if access != null:
		access.seek_end()
		access.store_line(JSON.stringify(entry))
		access.close()
	print("NIGHT_PROGRESS ",JSON.stringify(entry))
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func named(id: String) -> Node: return app.find_child(id, true, false)
func command(id: String, payload: Dictionary = {}) -> bool:
	var request_started: int = Time.get_ticks_msec()
	progress("command_begin",{"request":id,"payload_keys":payload.keys()})
	var accepted: bool = app._command(id, payload)
	check(accepted, "Commande de préparation autorisée : " + id)
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	var ok: bool = not app.waiting and app.bridge.last_response_ok
	check(ok, "Réponse du vrai worker : " + id + " · " + app.last_error)
	await settle()
	progress("command_end",{"request":id,"accepted":accepted,"ok":ok,"request_ms":Time.get_ticks_msec()-request_started})
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
	visits.append({"control":str(control.name), "kind":control.get_meta("entity_kind", ""), "id":control.get_meta("entity_id", ""), "activation":"Enter", "route_before":app.route})
	await key(KEY_ENTER)
func open_entity(kind: String, id: Variant, section: String = "") -> bool:
	var target := {"kind":kind, "id":id}
	if not section.is_empty(): target.section = section
	var accepted: bool = nav.open_entity(target)
	await settle()
	visits.append({"target":target, "accepted":accepted, "route_after":app.route, "selected_player":app.selected_player})
	return accepted
func capture(id: String) -> void:
	progress("capture_begin",{"capture":id})
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == root.size, "Pixels natifs de la fenêtre : " + id)
	var filename := output.path_join(id + ".png")
	check(image.save_png(filename) == OK, "Capture réelle : " + id)
	captures.append({"file":filename, "width":image.get_width(), "height":image.get_height(), "route":app.route, "sha256":FileAccess.get_sha256(filename)})
	progress("capture_end",{"capture":id})
func snapshot() -> Dictionary:
	await command("export")
	var file := str(app.model.meta.dataDir).path_join("donnees.json")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	return {"file":file, "sha256":FileAccess.get_sha256(file), "state":JSON.parse_string(app.model.meta.exportText).state, "commands":app.bridge._next_id, "model":app.model.duplicate(true), "seed":profile.get("seed"), "clock":profile.get("clock")}
func unchanged(before: Dictionary, context: String) -> void:
	var requests: int = app.bridge._next_id - int(before.commands)
	check(app.bridge._next_id == before.commands, context + " : aucune commande métier ou lecture worker déclenchée par les liens")
	check(FileAccess.get_sha256(before.file) == before.sha256, context + " : mêmes octets de sauvegarde, seed et horloge persistés")
	await command("export")
	var after_state: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	check(after_state == before.state, context + " : état sportif du vrai worker identique")
	check(FileAccess.get_sha256(before.file) == before.sha256, context + " : export de contrôle sans écriture")
	var after_profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(before.file))
	receipts.append({"context":context,"link_commands":requests,"profile_sha256_before":before.sha256,"profile_sha256_after":FileAccess.get_sha256(before.file),"state_unchanged":after_state == before.state,"saved_seed_before":before.seed,"saved_seed_after":after_profile.get("seed"),"saved_clock_before":before.clock,"saved_clock_after":after_profile.get("clock")})
func text(node: Node) -> String:
	if node == null: return ""
	var value := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	if node is Window: value += node.title + "\n"
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
func click_link(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Lien de souris réellement rendu")
	if control == null: return
	var point := control.get_global_rect().get_center()
	visits.append({"control":str(control.name),"kind":control.get_meta("entity_kind", ""),"id":control.get_meta("entity_id", ""),"activation":"mouse","route_before":app.route})
	await motion(point); await mouse(point, true); await mouse(point, false); await settle()
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
func fatigue_chart_return() -> void:
	app.Immersive.open_training(app); await settle()
	await activate(named("TrainingTab4"))
	var bins := [0, 0, 0, 0, 0]
	var players: Array = app.model.get("squad", [])
	for person: Dictionary in players:
		if person.get("physicalLoad") is float or person.get("physicalLoad") is int:
			bins[clampi(int(floorf(float(person.physicalLoad) / 20.0)), 0, 4)] += 1
	var bucket: int = bins.find(bins.max())
	await activate(named("FatigueLoadBucket" + str(bucket)))
	check(int(app.management_ui.immersive_training.get("fatigue_load_bin", -1)) == bucket, "Barre du graphique : filtre de charge exact")
	var rows: Array = app.find_children("FatigueRow_*", "Control", true, false)
	check(rows.size() == bins[bucket], "Graphique et liste : mêmes joueurs projetés dans la tranche")
	var scroll := named("FatigueScroll") as ScrollContainer
	check(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Liste filtrée réellement assez longue pour défiler")
	if scroll == null or rows.is_empty(): return
	scroll.scroll_vertical = mini(120, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)); await settle()
	var offset: int = scroll.scroll_vertical
	check(offset > 0, "Défilement non nul réellement atteint avant consultation")
	var visible: Array = rows.filter(func(row: Control): return scroll.get_global_rect().encloses(row.get_global_rect()))
	check(not visible.is_empty(), "Au moins un nom de joueur entièrement visible dans la liste défilée")
	if visible.is_empty(): return
	var selected_id := str(visible[0].get_meta("player_id", ""))
	await click_link(named("FatigueOpenPlayer_" + selected_id.replace(":", "_")))
	check(app.route == "Effectif" and app.selected_player == selected_id, "Vrai clic sur le nom du graphique : bonne fiche, distinct de Régler")
	await back()
	check(int(app.management_ui.immersive_training.get("fatigue_load_bin", -1)) == bucket, "Retour du joueur : tranche du graphique conservée")
	check(named("FatigueScroll") != null and named("FatigueScroll").scroll_vertical == offset, "Retour du joueur : défilement non nul exact conservé")
	await capture("fatigue-tranche-retour-2560")
	await activate(named("FatigueFilter4"))
	check(not app.management_ui.immersive_training.has("fatigue_load_bin"), "Tout l’effectif retire le filtre graphique")
	await activate(named("TrainingTab2"))
	var individual_rows: Array = app.find_children("TrainingIndividual_*", "Button", true, false)
	check(not individual_rows.is_empty(), "Lignes du travail individuel réellement rendues")
	if individual_rows.is_empty(): return
	var player_id := str(individual_rows[0].get_meta("player_id", ""))
	var individual_scroll := named("TrainingIndividualsScroll") as ScrollContainer
	var profile_link := named("TrainingOpenPlayer_" + player_id.replace(":", "_")) as Control
	if individual_scroll != null and profile_link != null: individual_scroll.ensure_control_visible(profile_link); await settle()
	await click_link(profile_link)
	check(app.route == "Effectif" and app.selected_player == player_id and named("TrainingIndividualDialog") == null, "Nom du travail individuel ouvre la fiche sans ouvrir le réglage")
	await back()
	var row := named("TrainingIndividual_" + player_id.replace(":", "_")) as Control
	await activate(row)
	check(named("TrainingIndividualDialog") != null, "Activation de la ligne métier garde son dialogue de réglage distinct")
	app._clear_dialogs(); await settle()
func setup_career() -> bool:
	if group == "report":
		var reports: Array = app.model.get("decisions", {}).get("recruitment", {}).get("reports", [])
		check(not reports.is_empty() and app.model.get("live") == null, "Checkpoint réel préparé : rapports présents et aucun match en cours")
		visits.append({"preparation":"checkpoint de vraie mission chargé sans nouvelle carrière", "report_ids":reports.map(func(report: Dictionary): return str(report.get("id", ""))), "week":app.model.meta.get("week")})
		return not reports.is_empty()
	var payload := {"mode":"world-champ", "nationalRole":"nation", "nation":"ENG"} if group == "nation" else {"mode":"world-champ", "club":29} if group == "reading" else {"mode":"common", "club":0}
	if not await command("new_career", payload): return false
	if group != "guards" and group != "nation":
		if not await Flow.settle_club_meetings(app, self, check): return false
	if group in ["prospects", "quote"]:
		var regen: Array = app.model.get("clubLife", {}).get("regenScouting", {}).get("candidates", [])
		var available: Array = app.model.get("clubLife", {}).get("interclubMarket", {}).get("candidates", []).filter(func(person: Dictionary): return person.get("available", false))
		visits.append({"preparation":"catalogues réels de common0", "regen_candidates":regen.size(), "available_interclub":available.size()})
		if regen.is_empty() or available.is_empty():
			# Public career creation is test setup. No projected availability,
			# roster, cash, quote or hidden player data is rewritten here.
			if not await command("new_career", {"mode":"fiction", "club":13}): return false
			if not await Flow.settle_club_meetings(app, self, check): return false
			visits.append({"preparation":"carrière publique fiction13 pour catalogue et place disponibles", "club_id":app.model.club.id})
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
	await activate(named("RosterMoreFilters"))
	var reset := named("RosterReset") as Button
	check(reset != null, "Réinitialiser est présent dans le vrai dialogue de filtres")
	await activate(reset)
	await activate(named("RosterMoreFilters"))
	var sort := named("RosterSort") as OptionButton
	check(sort != null, "Tri disponible dans le vrai dialogue de filtres")
	if sort != null and sort.item_count > 1:
		var selected_before: String = app.selected_player
		var changed_sort := (sort.selected + 1) % sort.item_count
		sort.grab_focus(); sort.select(changed_sort); sort.item_selected.emit(changed_sort); await settle()
		check(app.route == "Effectif" and app.selected_player == selected_before and not app.get_meta("immersive08_full_player", false), "Tri de colonne/liste distinct d’une ouverture d’entité")
	var advanced := named("RosterAdvancedFilters") as AcceptDialog
	if advanced != null: await activate(advanced.get_ok_button())
	var scroll := named("SquadScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = mini(150, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
		await settle()
		var offset: int = scroll.scroll_vertical
		check(await open_entity("player", id), "Deuxième consultation depuis une liste défilée")
		await back()
		check(named("SquadScroll") != null and named("SquadScroll").scroll_vertical == offset, "Retour : défilement exact de la liste conservé")
	var player_link := named("SquadOpenPlayer_" + id.validate_node_name()) as Control
	check(player_link != null, "Nom/portrait du joueur lié dans la vraie ligne d’effectif")
	if player_link != null:
		var roster_scroll := named("SquadScroll") as ScrollContainer
		if roster_scroll != null: roster_scroll.ensure_control_visible(player_link); await settle()
		await click_link(player_link)
		check(app.selected_player == id and app.get_meta("immersive08_full_player", false), "Vrai clic distinct du tri : bonne fiche complète ouverte")
		await back()
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
		var limited: Array = market.filter(func(person: Dictionary): return not person.get("knowledge", {}).get("owned", false) and person.get("knowledge", {}).get("stage") == "unobserved")
		check(not limited.is_empty(), "Vraie cible hors club non observée disponible pour la recette")
		var outsider: Dictionary = limited[0] if not limited.is_empty() else market[0]
		var outsider_before := JSON.stringify(outsider)
		check(await open_entity("market", str(outsider.id)), "Cible hors club : dossier de recrutement par ID")
		check(app.route == "Recrutement" and str(app.management_ui.market.get("navigation_id", "")) == str(outsider.id), "Bonne piste ouverte sans homonyme")
		var after: Array = app.model.market.filter(func(person: Dictionary): return str(person.id) == str(outsider.id))
		check(after.size() == 1 and JSON.stringify(after[0]) == outsider_before, "Aucune information supplémentaire injectée dans la projection hors club")
		if not limited.is_empty():
			check(outsider.get("rating") == null and outsider.get("potential") == null and outsider.get("ratingRange") == null and outsider.get("potentialRange") == null, "Cible non observée : aucun niveau ou potentiel exact ni intervalle révélé")
			check(text(named("RecruitmentProfilePanel")).contains("—"), "Dossier hors club non observé : les valeurs inconnues restent absentes à l’écran")
		await capture("recrutement-cible-2560")
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	if not teams.is_empty() and not teams[0].get("members", []).is_empty():
		var person: Dictionary = teams[0].members[0]
		check(await open_entity("staff", str(person.id)), "Membre du staff ouvert par son identifiant")
		check(named("StaffProfile") != null and text(named("StaffProfileName")) == str(person.name) + "\n", "Profil du membre de staff exact")
		var title := named("StaffProfileName") as Label
		check(title != null and title.size.x >= 180 and title.get_line_count() <= 3, "Nom du staff lisible sur une vraie largeur, sans colonne d’une lettre")
		await capture("staff-profil-2560")
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		for fixture: Dictionary in app.model.get("calendar", []):
			if fixture.get("home") is Dictionary and fixture.get("away") is Dictionary and (str(fixture.home.get("id")) == str(app.model.club.id) or str(fixture.away.get("id")) == str(app.model.club.id)):
				next = fixture; break
	check(not next.is_empty(), "Une rencontre du club est réellement projetée pour consulter son adversaire")
	if not next.is_empty():
		var opponent: Dictionary = next.away if int(next.home.id) == int(app.model.club.id) else next.home
		check(await open_entity("club", opponent.id), "Club adverse ouvert dans son détail existant")
		var club_detail := named("CompetitionClubDetails")
		check(club_detail != null and str(club_detail.get_meta("entity_id", "")) == str(opponent.id), "Détail du bon ID de club adverse effectivement rendu")
		check(club_detail != null and club_detail.title == GameSkin.club_name(opponent), "Nom publié du bon club adverse effectivement rendu dans le titre")
		await capture("club-adverse-2560")
		app._clear_dialogs(); await settle()
	await cancel_real_drag()
	await fatigue_chart_return()
	for resolution in [Vector2i(1280,720), Vector2i(1440,900), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		check(await open_entity("player", id), "Même fiche par ID à " + str(resolution))
		await settle()
		check(app.selected_player == id and root.size == resolution, "Bonne destination et dimensions exactes à " + str(resolution))
		await capture("fiche-%d-%d" % [resolution.x, resolution.y])
	await unchanged(before, "Parcours joueurs staff clubs")
func guard_refusal(context: String) -> void:
	progress("guard_begin",{"context":context})
	var before := await snapshot()
	var route_before: String = app.route
	var scene_before: String = app.contextual_director.kind
	var ui_before: Dictionary = app.management_ui.duplicate(true)
	var id := str(app.model.squad[0].id)
	check(not await open_entity("player", id), context + " : lien refusé proprement")
	check(app.route == route_before and app.contextual_director.kind == scene_before and app.management_ui == ui_before, context + " : scène et état de lecture préservés")
	await unchanged(before, context)
	progress("guard_end",{"context":context})
func inspect_and_return(owner: Window, link: Control, target: Dictionary, context: String) -> void:
	check(link != null and owner.visible, context + " : catalogue et lien réels")
	if link == null: return
	var owner_id: int = owner.get_instance_id()
	link.grab_focus(); await settle()
	await activate(link)
	var detail := owner.find_child("ProspectProfile", true, false) as AcceptDialog
	check(detail != null and detail.visible and str(detail.get_meta("entity_id", "")) == str(target.id) and detail.get_meta("entity_source") == target.source, context + " : dossier du bon ID/source dans la fenêtre appelante")
	check(not nav.inspect_entity(target, owner), context + " : deuxième dossier refusé pendant le premier")
	if detail != null:
		await capture("prospect-" + str(target.source) + "-2560")
		await activate(detail.get_ok_button())
	check(is_instance_valid(owner) and owner.get_instance_id() == owner_id and owner.visible, context + " : même fenêtre appelante conservée")
	check(link.has_focus(), context + " : focus restitué au nom exact")
func prospects_cases() -> void:
	var before := await snapshot()
	app._navigate("Recrutement"); await settle()
	await activate(named("OpenRegenScouting"))
	var scout := named("RegenScouting") as Window
	check(scout != null and scout.visible, "Vrai catalogue de relève ouvert")
	var candidates: Array = app.model.get("clubLife", {}).get("regenScouting", {}).get("candidates", [])
	check(not candidates.is_empty(), "Candidats de relève réellement projetés")
	if scout != null and not candidates.is_empty():
		var candidate: Dictionary = candidates[0]
		var candidate_id := str(candidate.get("playerId", candidate.id))
		var search := scout.find_child("RegenScoutSearch", true, false) as LineEdit
		search.text = str(candidate.name); search.text_changed.emit(search.text); await settle()
		var link := scout.find_child("RegenScoutProfile_" + candidate_id.validate_node_name(), true, false) as Control
		if link != null: scout.scroll.ensure_control_visible(link); await settle()
		var state_before: Dictionary = scout.state.duplicate(true)
		var scroll_before: int = scout.scroll.scroll_vertical
		await inspect_and_return(scout, link, {"kind":"prospect", "source":"regen-candidates", "id":candidate_id}, "Relève")
		check(scout.state == state_before and scout.scroll.scroll_vertical == scroll_before and search.text == str(candidate.name), "Retour de la relève : recherche, filtres, page et défilement conservés")
	app._clear_dialogs(); await settle()
	await activate(named("OpenInterclubMarket"))
	var market := named("InterclubMarket") as Window
	check(market != null and market.visible, "Vrai catalogue entre clubs ouvert")
	var contracted: Array = app.model.get("clubLife", {}).get("interclubMarket", {}).get("candidates", []).filter(func(person: Dictionary): return person.get("available", false))
	check(not contracted.is_empty(), "Vrai joueur sous contrat disponible pour préparer un brouillon")
	if market != null and not contracted.is_empty():
		var candidate: Dictionary = contracted[0]
		var interclub_search := market.find_child("InterclubSearch", true, false) as LineEdit
		interclub_search.text = str(candidate.name); interclub_search.text_changed.emit(interclub_search.text); await settle()
		var offer: Control
		for button: Button in market.find_children("InterclubOffer", "Button", true, false):
			if str(button.get_meta("player_id", "")) == str(candidate.id): offer = button; break
		check(offer != null, "Action de préparation du brouillon pour le vrai candidat")
		if offer != null:
			await activate(offer)
			var fee := market.find_child("InterclubFee", true, false) as SpinBox
			var salary := market.find_child("InterclubSalary", true, false) as SpinBox
			check(fee != null and salary != null, "Champs réels du brouillon de négociation")
			if fee != null and salary != null:
				fee.value = minf(fee.max_value, fee.value + fee.step * 2)
				salary.value = minf(salary.max_value, salary.value + salary.step)
				await settle()
				var draft := {"fee":market.offer_fee,"salary":market.offer_salary,"person":market.selected_person.duplicate(true),"negotiation":market.negotiation.duplicate(true),"query":market.query,"page":market.page,"fee_input":fee.value,"salary_input":salary.value}
				var link := market.find_child("InterclubProfile_" + str(candidate.id).validate_node_name(), true, false) as Control
				await inspect_and_return(market, link, {"kind":"prospect", "source":"interclub", "id":str(candidate.id)}, "Marché entre clubs")
				check(market.offer_fee == draft.fee and market.offer_salary == draft.salary and market.selected_person == draft.person and market.negotiation == draft.negotiation, "Retour interclubs : indemnité, salaire, joueur sélectionné et devis strictement conservés")
				check(market.query == draft.query and market.page == draft.page and fee.value == draft.fee_input and salary.value == draft.salary_input, "Retour interclubs : recherche, page et champs exacts du brouillon conservés")
				# Isolated UI guard: a real ConfirmationDialog component, with no
				# command or transaction attached. app.confirm intentionally closes
				# the parent catalogue and therefore is not this guard fixture.
				var confirmation := ConfirmationDialog.new()
				confirmation.name = "ProspectInspectionGuardConfirmation"
				confirmation.title = "Confirmation de recette"
				app._prepare_dialog(confirmation, 650)
				market.add_child(confirmation); confirmation.popup_centered(Vector2i(650, 180))
				await settle()
				check(not nav.inspect_entity({"kind":"prospect","source":"interclub","id":str(candidate.id)}, market) and market.find_child("ProspectProfile", true, false) == null, "Confirmation de test visible : inspection refusée sans superposition")
				confirmation.queue_free(); await settle()
	app._clear_dialogs(); await settle()
	await unchanged(before, "Consultation des prospects depuis leurs catalogues")
func staff_cases() -> void:
	var before := await snapshot()
	var teams: Array = app.model.get("staff", {}).get("teams", [])
	var members: Array = []
	for team: Dictionary in teams:
		if str(team.get("id")) == str(app.model.club.id): members = team.get("members", []); break
	check(not members.is_empty(), "Staff réel du club disponible pour sa recette ciblée")
	if members.is_empty(): return
	var person: Dictionary = members[0]
	var id := str(person.id)
	for resolution in [Vector2i(2560,1440), Vector2i(1920,1080), Vector2i(1280,720)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		check(await open_entity("staff", id), "Profil du staff exact à " + str(resolution))
		await settle()
		var title := named("StaffProfileName") as Label
		check(title != null and title.text == str(person.name), "Identité du staff conservée à " + str(resolution))
		check(title != null and title.size.x >= 180 and title.get_line_count() <= 3, "Nom du staff lisible, sans colonne d’une lettre, à " + str(resolution))
		await capture("staff-fiche-%d-%d" % [resolution.x,resolution.y])
	root.size = Vector2i(2560,1440)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	check(await open_entity("staff", id), "Même profil du staff avant retour à l’annuaire")
	await activate(named("StaffProfileDirectory"))
	var search := named("StaffSearch") as LineEdit
	check(search != null, "Vraie recherche d’annuaire disponible au retour du profil")
	if search != null:
		search.text = str(person.name); search.text_changed.emit(search.text); await settle()
		search.grab_focus(); search.caret_column = mini(4, search.text.length()); search.select(1, mini(3, search.text.length()))
		var caret := search.caret_column
		var selection_from := search.get_selection_from_column()
		var selection_to := search.get_selection_to_column()
		check(await open_entity("staff", id), "Consultation depuis l’annuaire filtré et la saisie focalisée")
		await back()
		search = named("StaffSearch") as LineEdit
		check(search != null and search.text == str(person.name) and search.has_focus(), "Retour staff : recherche exacte et focus de saisie conservés")
		check(search != null and search.caret_column == caret and search.get_selection_from_column() == selection_from and search.get_selection_to_column() == selection_to, "Retour staff : curseur et sélection de texte conservés")
		var link := named("StaffOpenName_" + id.validate_node_name()) as Control
		var scroll := named("StaffList") as ScrollContainer
		if link != null and scroll != null: scroll.ensure_control_visible(link); await settle()
		await activate(link)
		check(named("StaffProfile") != null and str(named("StaffProfile").get_meta("staff_id", "")) == id, "Entrée sur le vrai nom du staff : même profil par ID")
		await back()
		search = named("StaffSearch") as LineEdit
		check(search != null and search.text == str(person.name), "Retour du vrai lien du staff : annuaire toujours filtré")
	await unchanged(before, "Profil et annuaire du staff")
func quote_cases() -> void:
	app._navigate("Recrutement"); await settle()
	await activate(named("OpenInterclubMarket"))
	var market := named("InterclubMarket") as Window
	var candidates: Array = app.model.get("clubLife", {}).get("interclubMarket", {}).get("candidates", []).filter(func(person: Dictionary): return person.get("available", false))
	check(market != null and not candidates.is_empty(), "Catalogue réel avec candidat interclubs disponible pour un devis")
	if market == null or candidates.is_empty(): return
	var person: Dictionary = candidates[0]
	var search := market.find_child("InterclubSearch", true, false) as LineEdit
	search.text = str(person.name); search.text_changed.emit(search.text); await settle()
	var offer: Control
	for button: Button in market.find_children("InterclubOffer", "Button", true, false):
		if str(button.get_meta("player_id", "")) == str(person.id): offer = button; break
	await activate(offer)
	var fee := market.find_child("InterclubFee", true, false) as SpinBox
	var salary := market.find_child("InterclubSalary", true, false) as SpinBox
	check(fee != null and salary != null, "Vrais champs du devis avant soumission")
	if fee == null or salary == null: return
	fee.value = minf(fee.max_value, fee.value + fee.step * 2)
	salary.value = minf(salary.max_value, salary.value + salary.step)
	await settle()
	var request: Dictionary = market._payload().duplicate(true)
	var before_quote := await snapshot()
	var command_before: int = app.bridge._next_id
	await activate(market.find_child("InterclubNegotiate", true, false))
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or market.pending) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop(); await settle()
	check(not app.waiting and not market.pending and app.bridge.last_response_ok and app.last_command == "interclub_negotiate", "Devis reçu de la vraie commande publique interclub_negotiate")
	check(app.bridge._next_id == command_before + 1, "Une seule commande réelle de préparation du devis")
	check(not market.negotiation.is_empty() and str(market.negotiation.get("playerId", "")) == str(person.id), "Devis non vide correspondant au joueur proposé")
	var message := market.find_child("InterclubNegotiationMessage", true, false) as Label
	check(message != null and not message.text.is_empty() and message.text != "Réponses des clubs et du joueur…", "Réponse et conditions du devis réellement rendues")
	var quote: Dictionary = market.negotiation.duplicate(true)
	visits.append({"preparation":"interclub_negotiate reçu avant baseline de consultation","payload":request,"request_number":command_before,"quote_sha256":JSON.stringify(quote).sha256_text(),"offer_count":quote.get("offers", []).size()})
	var scrolls: Array = market.find_children("*", "ScrollContainer", true, false)
	var scroll := scrolls[0] as ScrollContainer if not scrolls.is_empty() else null
	if scroll != null and message != null: scroll.ensure_control_visible(message); await settle()
	await capture("devis-interclub-recu-2560")
	var before := await snapshot()
	check(before.state == before_quote.state and before.sha256 == before_quote.sha256, "Préparation du devis réel : état sportif et profil inchangés")
	check(before.seed == before_quote.seed and before.clock == before_quote.clock, "Préparation du devis réel : seed et horloge persistés inchangés")
	visits.append({"preparation":"contrôle avant/après devis réel", "profile_sha256_before":before_quote.sha256,"profile_sha256_after":before.sha256,"saved_seed_before":before_quote.seed,"saved_seed_after":before.seed,"saved_clock_before":before_quote.clock,"saved_clock_after":before.clock,"state_unchanged":before.state == before_quote.state})
	check(market.negotiation == quote, "L’export de baseline conserve le vrai devis préparé")
	var link := market.find_child("InterclubProfile_" + str(person.id).validate_node_name(), true, false) as Control
	if scroll != null and link != null:
		scroll.ensure_control_visible(link); await settle()
		var content_top := link.get_global_rect().position.y - scroll.get_global_rect().position.y + scroll.scroll_vertical
		scroll.scroll_vertical = clampi(int(content_top) - 20, 0, int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)); await settle()
	if link != null: link.grab_focus(); await settle()
	var offset: int = scroll.scroll_vertical if scroll != null else 0
	var draft := {"fee":market.offer_fee,"salary":market.offer_salary,"person":market.selected_person.duplicate(true),"query":market.query,"page":market.page,"fee_input":fee.value,"salary_input":salary.value,"can_close":not market.close_button.disabled,"message":message.text if message != null else ""}
	await inspect_and_return(market, link, {"kind":"prospect","source":"interclub","id":str(person.id)}, "Devis non vide")
	check(market.negotiation == quote and not market.negotiation.is_empty(), "Retour du dossier : devis moteur non vide strictement identique")
	check(market.offer_fee == draft.fee and market.offer_salary == draft.salary and market.selected_person == draft.person and fee.value == draft.fee_input and salary.value == draft.salary_input, "Retour du devis : indemnité, salaire, joueur et champs conservés")
	check(market.query == draft.query and market.page == draft.page and (scroll == null or scroll.scroll_vertical == offset), "Retour du devis : recherche, page et défilement exacts conservés")
	check((not market.close_button.disabled) == draft.can_close and message.text == draft.message, "Retour du devis : réponse et état de validation inchangés sans clôturer")
	if scroll != null and message != null: scroll.ensure_control_visible(message); await settle()
	await capture("devis-interclub-retour-2560")
	app._clear_dialogs(); await settle()
	await unchanged(before, "Inspection d’un vrai devis interclubs non vide")
func report_cases() -> void:
	var reports: Array = app.model.get("decisions", {}).get("recruitment", {}).get("reports", [])
	check(not reports.is_empty(), "Mission réelle : rapport disponible dans la projection du worker")
	if reports.is_empty(): return
	var report: Dictionary = reports[0]
	var before := await snapshot()
	app._navigate("Recrutement"); await settle()
	await activate(named("MarketTab3"))
	check(int(app.management_ui.market.get("immersive_tab", -1)) == 3, "Vrai onglet des rapports conservés ouvert")
	check(not await open_entity("report", "__rapport_absent__"), "Rapport inexistant refusé sans ouvrir une autre archive")
	var report_link := named("MarketEntity_" + str(report.id).validate_node_name()) as Control
	check(report_link != null and str(report_link.get_meta("entity_id", "")) == str(report.id), "Vrai nom d’archive lié au rapport produit par la mission")
	await activate(report_link)
	var detail := named("RecruitmentReport") as Window
	check(detail != null and str(detail.get_meta("entity_id", "")) == str(report.id), "Fenêtre du vrai rapport reçu de la mission")
	check(named("ScoutReport_" + str(report.id)) != null, "Dossier d’archive daté rendu, pas une fiche actuelle substituée")
	var source := named("ScoutSource") as Label
	check(source != null and source.text == str(report.get("assessment", {}).get("source", "Date du rapport non conservée")), "Date et source du rapport conservées exactement")
	check(not await open_entity("report", str(report.id)), "Deuxième fenêtre du même rapport refusée")
	await capture("rapport-observation-reel-2560")
	var tabs := named("ScoutEvidenceTabs") as TabContainer
	check(tabs != null and tabs.get_tab_count() == 3, "Faits, appréciations et limites du rapport réel disponibles")
	if tabs != null:
		var sections := [["ScoutObserved", "observed"], ["ScoutEstimates", "estimates"], ["ScoutLimits", "limits"]]
		for index in sections.size():
			tabs.current_tab = index; await settle()
			var block := named(str(sections[index][0])) as Control
			check(block != null and block.is_visible_in_tree(), "Section du rapport réellement consultable : " + str(sections[index][1]))
			if block != null:
				var expected: Array = report.get("assessment", {}).get(sections[index][1], [])
				if expected.is_empty(): expected = ["Information non conservée."]
				var rendered: Array = block.find_children("*", "Label", true, false).map(func(label: Label): return label.text)
				check(rendered == expected, "Texte archivé rendu mot pour mot et dans son ordre : " + str(sections[index][1]))
		await capture("rapport-observation-limites-2560")
	var projected: Array = app.model.get("decisions", {}).get("recruitment", {}).get("reports", []).filter(func(item: Dictionary): return str(item.id) == str(report.id))
	check(projected.size() == 1 and projected[0] == report, "Consultation du rapport : même projection, aucune information supplémentaire injectée")
	var current := named("ReportCurrentPlayer") as Control
	if current != null:
		var original_window: int = detail.get_instance_id()
		await activate(current)
		check(app.route == "Recrutement" and str(app.management_ui.market.get("navigation_id", "")) == str(report.get("playerId", "")), "Lien depuis le vrai rapport vers la seule piste actuellement projetée")
		check(not detail.visible, "Le rapport source est suspendu sans fenêtre visible dupliquée au changement de dossier")
		await back()
		var restored := named("RecruitmentReport") as Window
		check(restored != null and restored.visible and restored.get_instance_id() == original_window and str(restored.get_meta("entity_id", "")) == str(report.id), "Retour de la piste : même fenêtre et même archive datée restituées")
		check(tabs != null and tabs.current_tab == 2, "Retour de la piste : onglet des limites du rapport conservé")
	else:
		check(detail != null and detail.visible, "Archive seule conservée si le joueur n’est plus dans le marché projeté")
	app._clear_dialogs(); await settle()
	check(int(app.management_ui.market.get("immersive_tab", -1)) == 3, "Fermeture du rapport : retour à l’onglet d’archives d’origine")
	await unchanged(before, "Lecture du vrai rapport d’observation")
func guard_cases() -> void:
	progress("guard_cases_begin")
	# A press appointment is intentionally absent until its exact persisted mail
	# is opened. Exercise that entrypoint instead of manufacturing scene metadata.
	var invitation := str(app.model.get("clubLife", {}).get("press", {}).get("conference", {}).get("invitationId", ""))
	if not app.contextual_director.active_meeting() and not invitation.is_empty():
		app._show_press_inbox(); await settle()
		var mail: Control
		for button: Button in app.find_children("*", "Button", true, false):
			if str(button.get_meta("message_id", "")) == invitation: mail = button; break
		check(mail != null, "Courrier de la vraie invitation de presse présent")
		if mail != null:
			await activate(mail)
			await activate(named("InboxOpenPressInvitation"))
			check(app.get_meta("press_mail_origin", "") == invitation, "Presse ouverte uniquement par son courrier et son invitation exacts")
	check(app.contextual_director.active_meeting(), "Rendez-vous réel initial présent")
	if app.contextual_director.active_meeting(): await guard_refusal("Rendez-vous obligatoire")
	progress("flow_begin",{"flow":"settle_club_meetings","boundary":"before_match"})
	var initial_meetings_ok: bool = await Flow.settle_club_meetings(app, self, check)
	progress("flow_end",{"flow":"settle_club_meetings","boundary":"before_match","ok":initial_meetings_ok})
	if not initial_meetings_ok: return
	progress("flow_begin",{"flow":"prepare_match_day"})
	var match_day_ok: bool = await Flow.prepare_match_day(app, self, check)
	progress("flow_end",{"flow":"prepare_match_day","ok":match_day_ok})
	if not match_day_ok: return
	await command("auto_lineup")
	await command("begin_match")
	check(app.contextual_director.kind == "locker", "Vraie causerie avant-match")
	await guard_refusal("Causerie obligatoire")
	progress("flow_begin",{"flow":"skip_talk","phase":"pre"})
	await Flow.skip_talk(app, self, "pre", check)
	progress("flow_end",{"flow":"skip_talk","phase":"pre"})
	app.timer.stop()
	await command("pause", {"paused":true})
	check(app.contextual_director.kind == "live", "Vrai match immersif en pause")
	await guard_refusal("Match immersif")
	await capture("navigation-refusee-match-2560")
	await command("delegate")
	if app.model.get("clubLife", {}).get("matchTalks", {}).get("scene") is Dictionary:
		progress("flow_begin",{"flow":"skip_talk","phase":"post"})
		await Flow.skip_talk(app, self, "post", check)
		progress("flow_end",{"flow":"skip_talk","phase":"post"})
	elif app.model.get("live") is Dictionary:
		await command("finish_round")
	progress("flow_begin",{"flow":"settle_club_meetings","boundary":"after_result"})
	var final_meetings_ok: bool = await Flow.settle_club_meetings(app, self, check)
	progress("flow_end",{"flow":"settle_club_meetings","boundary":"after_result","ok":final_meetings_ok})
	if not final_meetings_ok: return
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
	var speech_id := int(app.coach.speech._id) if is_instance_valid(app.coach) else 0
	progress("finish",{"failures":failures})
	if is_instance_valid(app.coach):
		check(app.coach.speech.muted and not app.coach.speech.speaking and app.coach.speech.player == null, "Gabi silencieux, aucun lecteur audio")
	check(speech_requests == 0 and speech_starts == 0 and speech_id == 0, "Compteurs de parole : zéro demande, zéro début et identifiant zéro")
	var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"case":group,"display":DisplayServer.get_name(),"engine":Engine.get_version_info(),"captures":captures,"visits":visits,"receipts":receipts,"speech_requests":speech_requests,"speech_starts":speech_starts,"speech_id":speech_id}, "  ")); report.close()
	print("NAVIGATION NOCTURNE ", group, " : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	await app._close(0 if failures.is_empty() else 1)
func run() -> void:
	progress("run")
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	if is_instance_valid(app.coach):
		app.coach.speech.set_muted(true)
		app.coach.speech.requested.connect(func(_line: String): speech_requests += 1)
		app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Projection initiale du vrai worker reçue")
	app.timer.stop()
	nav = app.navigation_controller
	check(nav.has_method("open_entity"), "API commune d’entité raccordée au vrai main")
	if not nav.has_method("open_entity") or not await setup_career(): await finish(); return
	match group:
		"nation": await nation_cases()
		"guards": await guard_cases()
		"prospects": await prospects_cases()
		"staff": await staff_cases()
		"quote": await quote_cases()
		"report": await report_cases()
		_: await reading_cases()
	await finish()
