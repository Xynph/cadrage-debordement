extends SceneTree
const G = preload("res://ui/carnet_skin.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
var proof := OS.get_environment("CD_READABILITY06_ARTIFACTS")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.12).timeout
	for i in 6: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty(), "Vrai worker disponible")
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload); await worker()
	check(app.bridge.last_response_ok, "Commande réelle " + id + " : " + app.last_error)
func named(id: String) -> Control: return app.find_child(id, true, false)
func resize_to(resolution: Vector2i) -> void:
	root.size = resolution
	DisplayServer.window_set_size(resolution)
	await settle()
	check(root.size == resolution and app.size == Vector2(resolution), "Viewport natif à la taille physique " + str(resolution))
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var requested := OS.get_environment("CD_READABILITY06_CAPTURE")
	if not requested.is_empty() and label != requested: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(proof.path_join(label + ".png")) == OK, "Capture " + label)
func contrast(a: Color, b: Color) -> float:
	var x := a.srgb_to_linear().get_luminance()
	var y := b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+.05)/(minf(x,y)+.05)
func finish() -> void:
	var report := {"checks":checks,"failures":failures,"measurements":measurements,
		"display_server":DisplayServer.get_name(),"real_dpi_tested":false}
	if DisplayServer.get_name() != "headless":
		report["reported_screen_dpi"] = DisplayServer.screen_get_dpi()
		report["reported_screen_scale"] = DisplayServer.screen_get_scale()
	var file := FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	if app != null: app.closing = true; app.bridge.stop()
	print("Lisibilité06 : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	# main removes a retired root before queue_free; resize/deferred calls must
	# never touch its viewport or move its retired controls afterwards.
	var retired:=preload("res://ui/office_view.gd").OfficeColumns.new()
	retired.size=Vector2(1000,400)
	root.add_child(retired)
	root.remove_child(retired)
	await process_frame
	check(not retired.compact,"Bureau retiré : adaptation différée ignorée sans viewport")
	retired._adapt()
	check(not retired.compact,"Bureau retiré : signal tardif ignoré sans viewport")
	retired.free()
	if OS.get_environment("CD_READABILITY06_TEARDOWN_ONLY")=="1":finish();return
	var heading := G.section("Un titre à sa juste place", "Une explication lisible")
	check(heading.get_child(0).get_theme_font_size("font_size") <= 22,"Titre du carnet réduit à22px maximum")
	heading.free()
	# A selected row remains identifiable under pointer, keyboard and pressed states.
	var selected := G.button("Échéance de l’équipe — sélection", func(): pass)
	check(selected.custom_minimum_size.y <= 36,"Commande générale limitée à36px")
	G.selected(selected,Color("ffe032"))
	for state in ["normal","hover","pressed"]:
		var style: StyleBoxFlat = selected.get_theme_stylebox(state)
		check(style.border_width_left >= 4, "Repère géométrique sélection conservé : " + state)
		check(contrast(selected.get_theme_color("font_color"),style.bg_color) >= 4.5, "Contraste sélection : " + state)
	selected.free()
	var cleared := G.button("Ancienne sélection",func(): pass)
	G.selected(cleared,Color("b94850"))
	G.clear_selection(cleared)
	for state in ["normal","hover","pressed"]:
		check(cleared.get_theme_stylebox(state).border_width_left < 4,"Ancien repère retiré : " + state)
	cleared.free()
	var metric := G.metric("123 456 789 €", "Engagement hebdomadaire connu")
	var value: Label = metric.get_child(0)
	check(value.autowrap_mode != TextServer.AUTOWRAP_OFF, "Valeur longue autorisée sur plusieurs lignes")
	check(value.get_theme_font_size("font_size") > metric.get_child(1).get_theme_font_size("font_size"), "Valeur hiérarchisée devant explication")
	check(value.get_theme_font_size("font_size") <= 24,"Métrique réduite à24px maximum")
	var metric_tile := PanelContainer.new()
	root.add_child(metric_tile)
	metric_tile.size = Vector2(150,100)
	metric_tile.add_child(metric)
	await settle()
	check(metric_tile.size.x <= 150 and value.get_global_rect().end.x <= metric_tile.get_global_rect().end.x,"Grand montant réellement contenu dans une tuile de150px")
	metric_tile.free()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("new_career", {"club":0,"mode":"common"})
	var annotated := _reference_player()
	var annotated_id := str(annotated.id)
	var annotation := "Repère de recette du dossier — uniquement pour ce joueur."
	await command("coach_note_save",{"context":app.model.clubLife.coachNotebook.context,"target":annotated_id,"text":annotation})
	await command("export")
	var before: String = app.model.meta.exportText
	var disk := str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	check(not bytes.is_empty(), "Profil réel pour la comparaison disque")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		await resize_to(resolution)
		await office_reading(resolution)
		await roster_reading(resolution, annotated, annotation)
		await route_reading(resolution)
		await navigate("Création")
		for id in ["CreationStart", "CreationClubsScroll"]:
			check(inside(named(id)), "Création : contrôle directement visible %s %s" % [id,resolution])
		await capture("creation-dense-" + str(resolution.x))
	await resize_to(Vector2i(1280,720))
	await navigate("Effectif")
	await visit_all_players("compact 720p")
	await responsive_reading(annotated, annotation)
	await resize_to(Vector2i(2560,1440))
	app.selected_player = annotated_id
	await navigate("Effectif")
	await visit_all_players("1440p")
	await immersive_drafts(annotated, annotation)
	check(FileAccess.get_file_as_bytes(disk) == bytes, "Consultation, clavier et resize : octets du profil inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation et resize : état complet et RNG identiques")
	finish()

func _reference_player() -> Dictionary:
	for player: Dictionary in app.model.squad:
		var peers: Array = app.model.squad.filter(func(member: Dictionary): return member.id != player.id and member.pos == player.pos)
		if not peers.is_empty() and player.renewal.available and player.get("rosterProfile") is Dictionary: return player
	check(false, "La fixture doit contenir un joueur prolongeable avec un pair et des sources")
	return app.model.squad[0]

func navigate(route: String) -> void:
	app._navigate(route)
	await settle()
	app.coach.close()
	await settle()

func rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)

func inside(control: Control, viewport: Control = null) -> bool:
	if control == null or not control.is_visible_in_tree(): return false
	var bounds := rect(control)
	if bounds.size.x <= 0 or bounds.size.y <= 0: return false
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	return screen.grow(1).encloses(bounds) and (viewport == null or rect(viewport).grow(1).encloses(bounds))

func keyboard(button: BaseButton, description: String) -> void:
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Commande clavier disponible · " + description)
	if button == null or button.disabled or not button.is_visible_in_tree(): return
	button.grab_focus()
	await settle()
	check(button.has_focus(), "Focus clavier · " + description)
	await key(KEY_ENTER)

func office_reading(resolution: Vector2i) -> void:
	await navigate("Bureau")
	var tiles := ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]
	for id: String in tiles:
		var tile := named(id)
		if id == "OfficeTimeline" and resolution.x == 1280 and tile != null:
			app.body_scroll.ensure_control_visible(tile)
			await settle()
		check(inside(tile, app.body_scroll), "Tuile entière dans le Bureau %s %s" % [id,resolution])
		if id == "OfficeTimeline" and resolution.x == 1280:
			app.body_scroll.scroll_vertical = 0
			await settle()
	var decisions := named("OfficeDecisions")
	check(decisions != null and rect(decisions).size.x >= 280, "Espace utile pour les décisions " + str(resolution))
	for id in ["OfficePreparationAction", "OfficeSelectionAction", "OfficeSquadAction", "OfficeStandingsAction", "OfficeCalendarAction"]:
		check(inside(named(id), app.body_scroll), "Accès métier visible depuis le Bureau %s %s" % [id,resolution])
	await capture("bureau-" + str(resolution.x))

func roster_rows(roster: Control) -> Array[Node]:
	if roster == null: return []
	return roster.find_children("*","Button",true,false).filter(func(row: Node): return row.has_meta("player_id"))

func first_roster_page() -> void:
	var search := named("RosterSearch")
	var previous := named("RosterPaginationPrevious") as Button
	check(previous != null and search != null, "Pagination et recherche de l’effectif présentes")
	if previous == null or search == null: return
	var selected: String = app.selected_player
	for i in 60:
		if previous.disabled: break
		await keyboard(previous, "page précédente")
		check(named("RosterSearch") == search, "Recul de page conserve la recherche")
	check(previous.disabled, "Première page atteinte au clavier")
	check(app.selected_player == selected, "Recul de page conserve le dossier choisi")

func visit_all_players(format: String) -> void:
	await first_roster_page()
	var search := named("RosterSearch")
	var seen: Array[String] = []
	var next := named("RosterPaginationNext") as Button
	check(next != null, "Pagination suivante disponible · " + format)
	if next == null: return
	for i in 60:
		for row: Node in roster_rows(named("SquadScroll")): seen.append(str(row.get_meta("player_id")))
		if next.disabled: break
		await keyboard(next, "page suivante " + format)
		check(named("RosterSearch") == search, "Pagination conserve la recherche · " + format)
	var expected: Array[String] = []
	for player: Dictionary in app.model.squad: expected.append(str(player.id))
	expected.sort()
	seen.sort()
	check(next.disabled and seen == expected, "Exactement tous les identifiants, sans doublon, par pagination clavier · " + format)

func roster_reading(resolution: Vector2i, player: Dictionary, annotation: String) -> void:
	app.selected_player = str(player.id)
	await navigate("Effectif")
	await first_roster_page()
	var roster := named("SquadScroll")
	var rows := roster_rows(roster)
	var complete := rows.filter(func(row: Control): return inside(row, roster))
	var immersive := named("ImmersiveRosterTable") != null
	check(immersive == (resolution.x >= 1600), "Gabarit attendu de l’Effectif " + str(resolution))
	check(roster != null and not rows.is_empty(), "Table d’effectif natif renseignée " + str(resolution))
	if immersive:
		check(rows.size() == 24 and complete.size() == 24, "24 lignes entières de l’Effectif immersif %s · reçu %d/%d" % [resolution,complete.size(),rows.size()])
		for id in ["RosterColumnSalary", "RosterColumn_CONTRAT", "RosterColumnFatigue", "RosterColumnPotential", "RosterPaginationInfo", "OpenComparison", "OpenPlayerFull"]:
			check(inside(named(id), app.body_scroll), "Colonne ou commande visible %s %s" % [id,resolution])
		var header := named("RosterHeader")
		var minute := false
		if header != null:
			for label: Label in header.find_children("*", "Label", true, false):
				if label.text == "MIN.": minute = inside(label, app.body_scroll)
		check(minute, "Colonne Minutes visible " + str(resolution))
	else:
		check(complete.size() >= 9, "Effectif compact : au moins neuf lignes entières, reçu " + str(complete.size()))
		check(inside(named("RosterPagination"), app.body_scroll), "Pagination de l’effectif compact visible")
		var toolbar := named("RosterTools")
		check(toolbar != null, "Barre de lecture dédiée compacte")
		if toolbar != null:
			for button: Button in toolbar.find_children("*","Button",true,false):
				check(button.size.y <= 42, "Commande compacte lisible " + str(button.name))
	for row: Control in rows:
		check(rect(row).size.y <= (34 if immersive else 29), "Ligne dense et entière " + str(row.name))
	measurements.append({"window":str(resolution),"canvas":str(app.size),"roster_rows":complete.size(),
		"roster_height":rect(roster).size.y if roster != null else 0,"row_height":rect(rows[0]).size.y if not rows.is_empty() else 0,
		"office_tiles":7,"roster_variant":"immersive" if immersive else "compact"})
	await capture("effectif-" + str(resolution.x))
	if immersive:
		await keyboard(named("OpenPlayerFull"), "ouvrir la fiche joueur complète")
		await immersive_profile(player, resolution)
		await keyboard(named("PlayerBackToSquad"), "retour à l’effectif")
		check(named("ImmersiveRosterTable") != null and app.selected_player == str(player.id), "Retour au tableau sans perdre le joueur")
	else:
		await compact_profile(player, annotation, resolution)

func labels(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node == null: return result
	for label: Label in node.find_children("*", "Label", true, false): result.append(label.text)
	return result

func fact(id: String, value: Variant) -> void:
	var label := named(id) as Label
	check(label != null and label.text == str(value), "Fait projeté exactement · %s = %s" % [id,value])

func compact_profile(player: Dictionary, annotation: String, resolution: Vector2i) -> void:
	var tabs := named("ProfileTabs") as TabContainer
	var scroll := named("ProfileScroll")
	var overview := named("ProfileOverview") as ScrollContainer
	check(tabs != null and tabs.get_tab_count() == 4 and scroll != null and overview != null, "Quatre vrais onglets du dossier compact " + str(resolution))
	if tabs == null or scroll == null or overview == null: return
	check(absf(rect(scroll).end.y - rect(tabs).end.y) <= 16, "Les onglets utilisent la hauteur du dossier compact")
	check(tabs.get_tab_title(2) == "Contrat", "Contrat reste le troisième onglet compact")
	tabs.current_tab = 2
	await settle()
	for id in ["OfferRenewal", "PlayerLoad"]:
		check(inside(named(id), scroll) and inside(named(id), named("ProfileContract")), "Action accessible dans Contrat compact " + id)
	tabs.current_tab = 0
	await settle()
	for id in ["OpenPlayerCoachNote", "CompareSelected"]:
		check(inside(named(id), overview) and inside(named(id), scroll), "Action entière dans l’Aperçu compact " + id)
	check(overview.get_v_scroll_bar().max_value <= overview.get_v_scroll_bar().page+1, "Aperçu compact sans défilement local")
	var tiles := app.find_children("ProfileTile*", "PanelContainer", true, false)
	check(tiles.size() == 6, "Six tuiles de données dans l’Aperçu compact")
	for tile: Control in tiles:
		check(inside(tile, overview), "Tuile compacte visible " + str(tile.name))
		var contents: Control = tile.get_child(0)
		var last_fact: Control = contents.get_child(contents.get_child_count() - 1)
		check(rect(tile).end.y - rect(last_fact).end.y <= 8, "Tuile compacte sans vide interne " + str(tile.name))
	var overview_tiles := named("ProfileOverviewTiles")
	check(overview_tiles != null and overview_tiles.get_child_count() == 2, "Six tuiles en deux colonnes indépendantes")
	var overview_actions := named("ProfileOverviewActions")
	check(overview_actions != null and rect(overview).end.y - rect(overview_actions).end.y <= 32, "Aperçu compact sans grande surface vide sous les faits")
	for pair in [["ProfileConditionValue", G.n(player.condition)+"%"], ["ProfileRatingValue", G.n(player.rating)], ["ProfilePotentialValue", G.potential_text(player)],
		["ProfileMinutesValue", G.n(player.minutes)], ["ProfileAppearancesValue", G.n(player.appearances)],
		["ProfileContractValue", player.contractLabel], ["ProfileSalaryValue", G.euros(player.salary)], ["ProfileNotePreview", annotation],
		["ProfileRenewalValue", "Disponible" if player.renewal.available else "Indisponible"]]:
		fact(pair[0], pair[1])
	check(named("ProfilePlanValue") != null and named("ProfileQualificationsValue") != null, "Plan et qualifications exposés dans le dossier compact")
	check(app.find_children("ProfileAttribute_*", "Label", true, false).is_empty(), "Aperçu sans projection des onze compétences")
	await keyboard(named("OpenCompactDetailedAttributes"), "attributs détaillés dans le dossier compact")
	check(tabs.current_tab == 1, "Le lien de l’Aperçu ouvre le bon onglet")
	var attributes := named("ProfileAttributes") as ScrollContainer
	check(attributes != null and attributes.find_children("PlayerDetailedAttribute_*", "Label", true, false).size() == 36, "Les 36 attributs sont présents dans l’onglet compact")
	for attribute: String in player.attributesV2:
		fact("PlayerDetailedAttribute_" + attribute, PlayerAttributes.caption(player.attributesV2[attribute]))

func immersive_profile(player: Dictionary, resolution: Vector2i) -> void:
	var profile := named("ImmersivePlayerFull")
	check(profile != null, "Dossier immersif ouvert depuis l’effectif " + str(resolution))
	if profile == null: return
	fact("ProfilePlayerName", str(player.name).to_upper())
	var hero := labels(named("FullPlayerHero"))
	for value in [G.rating_text(player,true), G.potential_text(player), str(player.pos).to_upper()]:
		check(value in hero, "Identité et niveau du vrai dossier " + value)
	for i in 6: check(inside(named("FullPlayerTab"+str(i)), app.body_scroll), "Onglet immersif visible " + str(i))
	check(inside(named("OpenPlayerCoachNote"), app.body_scroll) and inside(named("FullPlayerCompare"), app.body_scroll), "Carnet et comparaison visibles sur la fiche")
	await keyboard(named("FullPlayerTab1"), "attributs du joueur")
	var detailed := named("PlayerDetailedAttributes")
	check(detailed != null and detailed.find_children("PlayerDetailedAttribute_*", "Label", true, false).size() == 36, "Les 36 attributs sont présents dans la fiche immersive")
	for attribute: String in player.attributesV2:
		var label := named("PlayerDetailedAttribute_" + attribute) as Label
		check(inside(label, app.body_scroll) and label.text == PlayerAttributes.caption(player.attributesV2[attribute]), "Attribut visible issu du moteur " + attribute)
	check(app.find_children("PlayerAttribute_*", "Label", true, false).is_empty(), "Fiche immersive sans projection des onze compétences")
	await keyboard(named("FullPlayerTab2"), "performances du joueur")
	var performances := labels(named("ImmersivePlayerFull"))
	for value in [G.n(player.appearances), G.n(player.minutes)]:
		check(value in performances, "Performances fidèles " + value)
	check("NOTE AU POSTE" not in performances,"La note au poste reste réservée à la tactique")
	await keyboard(named("FullPlayerTab3"), "contrat du joueur")
	var contract := labels(named("ImmersivePlayerFull"))
	check(G.euros(player.salary) + " / semaine" in contract and str(player.contractLabel) in contract, "Salaire et échéance exacts dans Contrat")
	check(G.n(player.condition) + " %" in contract and G.n(player.physicalLoad) in contract, "Condition et charge exactes dans Contrat")
	var renewal := named("OfferRenewal") as Button
	check(inside(renewal, app.body_scroll) and renewal.disabled == not bool(player.renewal.available), "Offre de prolongation visible et disponibilité exacte")
	check(inside(named("PlayerLoad"), app.body_scroll), "Charge individuelle visible dans Contrat")
	await keyboard(named("FullPlayerTab4"), "développement du joueur")
	check(inside(named("PlayerDevelopmentAction"), app.body_scroll), "Lien réel vers le suivi du développement")
	await keyboard(named("FullPlayerTab5"), "repères du joueur")
	var sources := labels(named("ImmersivePlayerFull"))
	var position: Dictionary = player.rosterProfile.position
	check("Poste d’origine : " + str(position.primary) in sources and
		"Qualifications de départ : " + ", ".join(position.qualifications) in sources, "Poste d’origine et qualifications exacts dans Repères")
	await keyboard(named("FullPlayerTab0"), "revenir à l’aperçu")
	await capture("fiche-joueur-" + str(resolution.x))

func route_reading(resolution: Vector2i) -> void:
	for route in ["Effectif","Composition","Préparation","Recrutement","Calendrier","Classements","Finances","Club"]:
		await navigate(route)
		check(inside(app.body_scroll), "Espace de travail visible %s %s" % [route,resolution])
		if resolution.x == 2560:
			var outer: VScrollBar = app.body_scroll.get_v_scroll_bar()
			check(outer.max_value <= outer.page + 1, "Aucun défilement global nécessaire en 1440p · " + route)
		if route == "Composition":
			for id in ["LineupSlot01", "LineupAutomatic"]:
				check(inside(named(id), app.body_scroll), "Commande de composition directement visible %s %s" % [id,resolution])
		if route == "Préparation":
			await keyboard(named("Nav_Entraînement"), "ouvrir Entraînement depuis le rail")
			var native := named("ImmersiveTraining") != null
			var controls := ["TrainingValidateWeek", "TrainingEditSelected", "TrainingBackToPreparation"] if native else ["PreparationTrain_repos", "PreparationTrain_normal", "PreparationTrain_intense", "CollectiveFocus", "OpponentLevel", "PreparationMatch"]
			for id: String in controls:
				check(inside(named(id), app.body_scroll), "Action d’entraînement directement visible %s %s" % [id,resolution])
		if route == "Recrutement":
			var tab := named("MarketTab1") as Button
			var immersive_market := tab != null
			if immersive_market: await keyboard(tab, "ouvrir les joueurs du marché")
			var market := named("ImmersiveMarketRows" if immersive_market else "MarketScroll")
			check(market != null and inside(market, app.body_scroll), "Joueurs du marché dans un vrai viewport " + str(resolution))
			if market != null:
				var offers := market.find_children("*", "Button", true, false)
				check(not offers.is_empty(), "Marché : des actions ou lignes sont présentes")
				for button: Button in offers:
					check(inside(button, market), "Offre, ligne ou suivi visible " + str(button.name))
			if immersive_market:
				check(inside(named("OfferRecruitment"), app.body_scroll), "Offre du joueur sélectionné accessible dans le marché immersif")
				var follow := app.body.find_child("Follow*", true, false) as Button
				check(inside(follow, app.body_scroll), "Suivi du joueur sélectionné accessible dans le marché immersif")
		for list_id in ["CalendarScroll","StandingsScroll","FinanceScroll"]:
			var list := named(list_id) as ScrollContainer
			if list == null: continue
			check(inside(list, app.body_scroll), "Viewport visible " + list_id)
			check(list.get_v_scroll_bar().max_value <= list.get_v_scroll_bar().page + 1, "Page paginée sans défilement local " + list_id)
		for pager_id in ["RosterPagination","MarketPagination","CalendarPagination","StandingsPagination","FinancePagination"]:
			var pager := named(pager_id)
			if pager != null and pager.is_visible_in_tree():
				check(inside(pager, app.body_scroll), "Pagination directement accessible %s %s" % [pager_id,resolution])
		if route == "Finances": await capture("finances-"+str(resolution.x))
		await capture(route.to_lower()+"-dense-"+str(resolution.x))

func responsive_reading(player: Dictionary, annotation: String) -> void:
	await navigate("Bureau")
	var office := named("ImmersiveOffice")
	var standings := named("OfficeStandings")
	var standings_action := named("OfficeStandingsAction") as Button
	check(office != null and standings != null and standings_action != null, "Le Bureau compact et le cap sportif sont montés")
	if standings_action != null:
		standings_action.grab_focus()
		await settle()
		for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(1280,720)]:
			await resize_to(resolution)
			check(named("ImmersiveOffice") == office and named("OfficeStandings") == standings and named("OfficeStandingsAction") == standings_action, "Bureau adapté sur les mêmes instances " + str(resolution))
			check(standings_action.has_focus() and inside(standings_action, app.body_scroll), "Cap sportif garde le focus et sa visibilité " + str(resolution))
	app.selected_player = str(player.id)
	await navigate("Effectif")
	var search := named("RosterSearch") as LineEdit
	check(search != null, "Champ de recherche du repli compact")
	if search == null: return
	search.text = "Équipe œuvrée — éléphant"
	search.caret_column = 10
	search.select(2, 10)
	search.grab_focus()
	var compact_tabs := named("ProfileTabs") as TabContainer
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(2560,1440), Vector2i(1920,1080)]:
		await resize_to(resolution)
		check(named("RosterSearch") == search and search.text == "Équipe œuvrée — éléphant" and search.caret_column == 10 and search.has_selection(), "Saisie Unicode, caret et sélection conservés " + str(resolution))
		check(search.has_focus() and named("ProfileTabs") == compact_tabs, "Focus et dossier conservés au redimensionnement " + str(resolution))
		var cohort := named("ProfileContextCohort")
		check(cohort != null and cohort.is_visible_in_tree() == (resolution.y >= 1000), "Contexte du dossier compact adapté à la hauteur " + str(resolution))
		if resolution.y == 1440:
			var peers := named("ProfileContextPeers")
			var same: Array = app.model.squad.filter(func(member: Dictionary): return member.id != player.id and member.pos == player.pos)
			check(peers != null and peers.find_children("ProfilePeerCompare*", "Button", true, false).filter(func(action: Control): return action.is_visible_in_tree()).size() == mini(5, same.size()), "Jusqu’à cinq coéquipiers du même poste à 1440p")
	await compact_context(player)
	search.text = ""
	search.text_changed.emit("")
	await settle()
	await first_roster_page()
	var second: Button
	for row: Button in roster_rows(named("SquadScroll")):
		if str(row.get_meta("player_id")) != str(player.id): second = row; break
	check(second != null, "Autre joueur accessible au clavier")
	if second == null: return
	var second_id := str(second.get_meta("player_id"))
	await keyboard(second, "ouvrir un autre dossier par ID")
	check(app.selected_player == second_id and second.has_focus(), "Le nouveau dossier garde le focus sur la ligne choisie")
	check(named("ProfileNotePreview") == null, "Aucune note inventée pour l’autre identifiant")
	await keyboard(named("OpenPlayerCoachNote"), "ouvrir le carnet de l’autre joueur")
	var notebook := app.get_node_or_null("CoachNotebook") as AcceptDialog
	var editor := named("CoachNoteText") as TextEdit
	check(notebook != null and editor != null and editor.text.is_empty() and editor.text != annotation, "L’autre dossier ouvre son propre carnet vide")
	if notebook != null:
		notebook.hide()
		notebook.queue_free()
		await settle()
	var second_tabs := named("ProfileTabs")
	for resolution in [Vector2i(1600,900), Vector2i(1280,720)]:
		await resize_to(resolution)
		check(named("ProfileTabs") == second_tabs and app.selected_player == second_id, "Dossier remplacé puis redimensionné sur les mêmes nœuds")
	await capture("effectif-focus-" + str(root.size.x))

func compact_context(player: Dictionary) -> void:
	var cohort := named("ProfileContextCohort")
	var peers := named("ProfileContextPeers")
	check(cohort != null and peers != null and cohort.is_visible_in_tree() and peers.is_visible_in_tree(), "Deux contextes desktop distincts des six faits")
	if cohort == null or peers == null: return
	check(app.find_children("ProfileContext*", "PanelContainer", true, false).size() == 4, "Quatre panneaux de contexte dans le dossier compact agrandi")
	for field in ["rating", "condition", "age", "salary"]:
		var total := 0.0
		for member: Dictionary in app.model.squad: total += float(member[field])
		var average := named("ProfileMean_" + field) as Label
		check(average != null and average.text.contains(" / "), "Moyenne comparative présente " + field)
		if average == null or not average.text.contains(" / "): continue
		var observed := average.text.split(" / ")[1].replace(" €","").replace("%","").replace(" ans","").replace(" ","").replace(",",".").to_float()
		check(absf(observed - total / app.model.squad.size()) <= (.51 if field == "salary" else .051), "Moyenne publique exacte " + field)
	var same: Array = app.model.squad.filter(func(member: Dictionary): return str(member.id) != str(player.id) and member.pos == player.pos)
	var actions := peers.find_children("ProfilePeerCompare*", "Button", true, false).filter(func(action: Control): return action.is_visible_in_tree())
	check(actions.size() == mini(3, same.size()), "Jusqu’à trois coéquipiers du même poste à 1080p")
	for action: Button in actions:
		check(same.any(func(member: Dictionary): return str(member.id) == str(action.get_meta("peer_id"))), "Cible du même poste par identifiant")
	var professional: Array = app.model.decisions.development.professionals.filter(func(record: Dictionary): return record.id == player.id)
	var delta := named("ProfileDevelopmentDelta") as Label
	check(not professional.is_empty() and delta != null and delta.text.to_int() == int(professional[0].rating-professional[0].development.seasonStart), "Développement comparé au début de saison")
	if actions.is_empty(): return
	var peer := actions[0] as Button
	var requested := [str(player.id), str(peer.get_meta("peer_id"))]
	await keyboard(peer, "comparer un pair du même poste")
	var comparison := app.get_node_or_null("PlayerComparison") as AcceptDialog
	check(comparison != null, "Vrai comparateur ouvert")
	if comparison == null: return
	for slot in 2:
		var choice := comparison.find_child("ComparisonPlayer"+str(slot), true, false) as OptionButton
		check(choice != null and str(choice.get_item_metadata(choice.selected)) == requested[slot], "Comparateur ouvre le dossier exact " + str(slot))
	# Fermer sans reconstruire le dossier compact, afin de continuer le scénario de resize.
	comparison.hide()
	comparison.queue_free()
	await settle()

func immersive_drafts(player: Dictionary, annotation: String) -> void:
	await keyboard(named("OpenPlayerFull"), "ouvrir le dossier du joueur annoté")
	await keyboard(named("FullPlayerTab3"), "ouvrir son Contrat")
	await keyboard(named("PlayerLoad"), "ouvrir le réglage de charge")
	var load_dialog := app.get_node_or_null("IndividualInstructions") as AcceptDialog
	check(load_dialog != null, "Le bouton Charge ouvre les vrais choix")
	if load_dialog != null:
		for mode in ["collective","repos","normal","intense"]:
			check(load_dialog.find_child("IndividualLoad_"+mode,true,false) != null, "Mode de charge réel " + mode)
		load_dialog.hide()
		load_dialog.queue_free()
		await settle()
	await keyboard(named("OfferRenewal"), "ouvrir la vraie offre sans la confirmer")
	var offer := app.get_node_or_null("ContractOffer") as ConfirmationDialog
	var salary_box := named("OfferSalary") as SpinBox
	check(offer != null and salary_box != null, "Dialogue natif d’offre de contrat")
	if offer != null and salary_box != null:
		var salary := salary_box.get_line_edit()
		salary.grab_focus()
		await settle()
		salary.text = "12345"
		salary.caret_column = 3
		for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
			await resize_to(resolution)
			check(is_instance_valid(offer) and offer.visible and salary.text == "12345" and salary.caret_column == 3, "Brouillon du même dialogue préservé " + str(resolution))
			await capture("contrat-" + str(resolution.x))
		offer.hide()
		offer.queue_free()
		await settle()
	await keyboard(named("OpenPlayerCoachNote"), "ouvrir la vraie note du joueur")
	var notebook := app.get_node_or_null("CoachNotebook") as AcceptDialog
	var editor := named("CoachNoteText") as TextEdit
	var picker := named("CoachNoteTarget") as OptionButton
	check(notebook != null and editor != null and editor.text == annotation, "La fiche immersive ouvre la seule note persistée")
	check(picker != null and str(picker.get_item_metadata(picker.selected)) == str(player.id), "Le carnet vise l’identifiant exact de la fiche")
	if notebook == null or editor == null: return
	editor.text = "Repère PC : garder ce brouillon 😀"
	editor.text_changed.emit()
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		await resize_to(resolution)
		check(app.get_node_or_null("CoachNotebook") == notebook and editor.text == "Repère PC : garder ce brouillon 😀", "Même carnet et brouillon Unicode après resize " + str(resolution))
	notebook.hide()
	notebook.queue_free()
	await settle()
	await keyboard(named("FullPlayerCompare"), "comparer depuis la fiche immersive")
	var comparison := app.get_node_or_null("PlayerComparison") as AcceptDialog
	check(comparison != null, "La fiche immersive ouvre le comparateur réel")
	if comparison == null: return
	var first := comparison.find_child("ComparisonPlayer0", true, false) as OptionButton
	var other := comparison.find_child("ComparisonPlayer1", true, false) as OptionButton
	check(first != null and str(first.get_item_metadata(first.selected)) == str(player.id), "Le comparateur conserve l’identifiant de la fiche ouverte")
	check(other != null and other.item_count == app.model.squad.size() + 1, "Le second comparateur expose tous les joueurs réels")
	comparison.hide()
	comparison.queue_free()
	await settle()
