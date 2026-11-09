extends SceneTree

var app: Control
var failures: Array[String] = []
var checks := 0
var visible_pool_rows := {}

func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		quit(2)
		return
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAIL: ", description)

func settle() -> void:
	for i in range(3): await process_frame

func response(expected := true) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok == expected, "Réponse de " + app.last_command + " · " + app.last_error)
	await settle()

func text_present(node: Node, part: String) -> bool:
	if node is Label and node.is_visible_in_tree() and part in node.text: return true
	return node.get_children().any(func(child: Node): return text_present(child, part))

func press(control: BaseButton) -> void:
	check(control != null and control.is_visible_in_tree() and not control.disabled, "Bouton accessible · " + str(control.name if control != null else "absent"))
	if control != null and not control.disabled: control.pressed.emit()
	await settle()

func click_action(control: BaseButton) -> bool:
	var available := control != null and control.is_visible_in_tree() and not control.disabled
	check(available,"Action de création visible et active")
	if not available: return false
	var point := control.get_global_transform_with_canvas() * (control.size / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	var hit := hovered != null and (hovered == control or control.is_ancestor_of(hovered))
	check(hit,"Gabi laisse le centre de l’action de création accessible")
	if not hit: return false
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await settle()
	return true

func named(id: String) -> Node:
	return app.find_child(id, true, false)

func button(label: String) -> Button:
	for control in app.find_children("*", "Button", true, false):
		if control.text == label and control.is_visible_in_tree(): return control
	return null

func pager_next(id: String) -> Button:
	return named(id).get_child(2)

func scroll_fits(id: String) -> bool:
	var scroll: ScrollContainer = named(id)
	var bar := scroll.get_v_scroll_bar()
	return bar.max_value <= bar.page + 1

func enumerate_clubs() -> void:
	var seen := {}
	for league in [["elite",14,"FR"],["accession",16,"FR"],["prem",10,"GB"],["urc",16,"international"]]:
		await press(named("CreationCountry_" + league[2]))
		await press(named("CreationDivision_" + league[0]))
		var members := {}
		for page_index in range(2):
			for control in app.find_children("CreationClub*", "Button", true, false):
				members[int(str(control.name).trim_prefix("CreationClub"))] = true
			check(scroll_fits("CreationClubsScroll"), "Grille visible sans défilement vertical · " + league[0])
			if not pager_next("CreationPagination").disabled: await press(pager_next("CreationPagination"))
		check(members.size() == league[1], "Tous les clubs de " + league[0] + " sont accessibles")
		seen.merge(members)
	check(seen.size() == 56 and not seen.has(56) and not seen.has(57), "56 clubs jouables et deux invités exclus du sélecteur")

func creation_grid_fits(expected: int, context: String) -> void:
	var list := named("CreationClubsScroll") as ScrollContainer
	var grid := named("CreationClubGrid") as GridContainer
	if list == null or grid == null:
		check(false, "Grille présente · " + context)
		return
	var bounds := list.get_global_rect().grow(1).intersection(root.get_visible_rect().grow(1))
	var cards_fit := grid.get_children().all(func(card: Control): return bounds.encloses(card.get_global_rect()))
	check(grid.columns == 3 and grid.get_child_count() == expected and scroll_fits("CreationClubsScroll") and cards_fit,
		"Grille complète sans défilement · %s · %s dans %s" % [context, grid.size, list.size])

func creation_dossier_fits(expected: int, context: String) -> void:
	var dossier := named("CreationDossier") as Control
	var honours := named("CreationHonours") as Control
	var action := named("CreationStart") as Control
	if dossier == null or honours == null or action == null:
		check(false, "Dossier, palmarès et action présents · " + context)
		return
	var viewport := root.get_visible_rect().grow(1)
	var bounds := dossier.get_global_rect().grow(1)
	var content_fits := viewport.encloses(bounds.grow(-1)) and bounds.encloses(honours.get_global_rect()) and bounds.encloses(action.get_global_rect())
	check(content_fits and honours.get_child_count() == expected and honours.get_global_rect().end.y <= action.get_global_rect().position.y and dossier.find_children("*", "ScrollContainer", true, false).is_empty() and scroll_fits("EntryWorkspace"),
		"Dossier complet sans défilement · %s · dossier %s, palmarès %s, action %s, fenêtre %s" % [context, dossier.get_global_rect(), honours.get_global_rect(), action.get_global_rect(), viewport])

func check_creation_geometry() -> void:
	var groups := {"FR":["elite", "accession", "nationale"], "GB":["prem", "champ"], "JP":["jlo-d1", "jlo-d2"], "international":["urc", "srp"]}
	var catalogue: Array = app.pack_manager.creation_catalogue()
	var witness: Dictionary = catalogue[0]
	var original: Dictionary = witness.history
	witness.history = original.duplicate(true)
	witness.history.results.append_array([
		{"competition":"urc", "rank":2, "year":2024},
		{"competition":"challenge", "finish":"final", "year":2023},
		{"competition":"accession", "titles":2, "year":2010},
		{"competition":"champ", "finish":"semi", "year":2014},
		{"competition":"nationale", "rank":3, "year":2009},
	])
	for resolution in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		root.size = resolution
		await create_timer(0.15).timeout
		var dossiers := 0
		for country: String in groups:
			await press(named("CreationCountry_" + country))
			for division: String in groups[country]:
				await press(named("CreationDivision_" + division))
				var clubs := catalogue.filter(func(club: Dictionary): return club.playable and club.division == division)
				creation_grid_fits(clubs.size(), "%s · %s" % [division, resolution])
				if division == "prem":
					await press(named("CreationClub30"))
					var city := named("CreationCity") as Control
					if resolution.y == 1440:
						check(city != null and city.visible and root.get_visible_rect().encloses(city.get_global_rect()), "La ville utilise l’espace libre du dossier en 1440p")
					else:
						check(city == null, "La ville ne réduit pas l’espace du dossier en 720p")
				for club: Dictionary in clubs:
					var results: Array = club.get("history", {}).get("results", [])
					if results.size() < 5: continue
					await press(named("CreationClub%d" % int(club.id)))
					creation_dossier_fits(results.size(), "club %d · %s" % [int(club.id), resolution])
					creation_grid_fits(clubs.size(), "club %d · %s" % [int(club.id), resolution])
					dossiers += 1
		check(dossiers > 0, "Dossiers à cinq résultats ou plus · %s" % resolution)
	witness.history = original
	root.size = Vector2i(1280, 720)
	await create_timer(0.15).timeout
	await press(named("CreationCountry_FR"))
	await press(named("CreationDivision_elite"))

func import_pack(path: String, expected := true) -> void:
	await press(button("Importer une autre réalité"))
	check(app.pack_manager.picker.visible, "Sélecteur ZIP natif ouvert")
	app.pack_manager.picker.file_selected.emit(path)
	app.pack_manager.picker.hide()
	await response(expected)

func install_and_select(path: String) -> void:
	await import_pack(path)
	await activate_inspected_pack()

func activate_inspected_pack() -> void:
	await press(button("INSTALLER CE PACK"))
	await response()
	await press(button("UTILISER CE PACK  →"))
	await response()

func check_competitions() -> void:
	var urc: String = app.pack_manager.competition("urc", "career").name
	var champions: String = app.pack_manager.competition("champions", "career").name
	var challenge: String = app.pack_manager.competition("challenge", "career").name
	var prem: String = app.pack_manager.competition("prem", "career").name
	app._navigate("Calendrier")
	await settle()
	var table := named("CalendarShowTable") as Button
	check(table != null, "Tableau détaillé accessible depuis le mois")
	if table != null: await press(table)
	check(named("CalendarFixtureDate") != null and "/" in named("CalendarFixtureDate").text, "Date du calendrier mise en forme")
	check(text_present(app, str(app.model.calendar[0].venue)), "Lieu de la rencontre issu du moteur")
	for page_index in range(12):
		if text_present(app, champions) or pager_next("CalendarPagination").disabled: break
		await press(pager_next("CalendarPagination"))
	check(text_present(app, champions) and text_present(app, "Poules"), "Calendrier du club mêlant championnat et journées de coupe")
	app._navigate("Classements")
	await settle()
	check(app.find_children("StandingsDivision_*", "Button", true, false).size() == 6, "Six onglets de compétition")
	for competition in [["champions",4],["challenge",3]]:
		await press(named("StandingsDivision_" + competition[0]))
		var option: OptionButton = named("StandingsPoolChoice")
		check(option != null and option.item_count == competition[1], "Poules distinctes · " + competition[0])
		if option == null: continue
		var index := (option.selected + 1) % option.item_count
		option.select(index)
		option.item_selected.emit(index)
		for i in range(4): await settle()
		var league: Dictionary = app.model.leagues.filter(func(item: Dictionary): return item.id == competition[0])[0]
		var ids: Array = league.pools[index].rows.map(func(item: Dictionary): return item.id)
		var rows := app.find_children("StandingsRow_*", "PanelContainer", true, false)
		visible_pool_rows[competition[0]] = rows.size()
		check(not rows.is_empty() and rows.all(func(row: Node): return row.get_meta("club_id") in ids), "Le classement n’affiche que la poule choisie")
		var standings_scroll: ScrollContainer = named("StandingsScroll")
		var bar := standings_scroll.get_v_scroll_bar()
		check(scroll_fits("StandingsScroll"), "Classement paginé sans défilement vertical · %s · hauteur %.0f · contenu %.0f · page %.0f · lignes %d" % [competition[0], standings_scroll.size.y, bar.max_value, bar.page, rows.size()])
	# Projection de palmarès. La simulation complète et l’archivage réels sont
	# vérifiés séparément dans world-worker-season.cjs.
	app.model.archives.seasons = [{"season":1,"champions":[{"leagueId":"urc","clubId":40}],"europe":{"champions":{"champion":30},"challenge":{"champion":31}}}]
	await press(named("OpenArchives"))
	var archive := named("SeasonArchives")
	check(archive != null and text_present(archive, "Champion " + urc) and text_present(archive, "Champion " + champions) and text_present(archive, "Champion " + challenge), "Le palmarès sépare les titres des trois compétitions témoins")
	app._clear_dialogs()
	app.model.clubLife.clubWorld.archives = [{"season":1,"champions":{"prem":30.0},"europe":{"challenge":{"champion":31.0}}}]
	app._navigate("Rivalités")
	await settle()
	await press(named("RivalryTab2"))
	var rivalry_archives := named("RivalryArchives")
	check(rivalry_archives != null and text_present(rivalry_archives, "SAISON 1") and text_present(rivalry_archives, prem + " · Bath témoin") and text_present(rivalry_archives, challenge + " ·") and not text_present(rivalry_archives, "Club 31"), "Le palmarès des rivalités distingue les titres et les identités des champions")
	app._navigate("Centre")
	await settle()
	check(text_present(app, "Les compétitions Espoirs ne sont pas encore disponibles") and button("ACTIVER LES PARCOURS") == null, "Centre mondial · raison visible et activation absente")

func finish() -> void:
	app.bridge.stop()
	var deadline := Time.get_ticks_msec() + 4000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
	check(app.bridge.child_pid <= 0, "Moteur de test arrêté")
	root.remove_child(app)
	app.queue_free()
	await settle()
	print("WORLD_NATIVE_UI_CHECKS ", JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"visible_pool_rows":visible_pool_rows}))
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 20000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if app.model.is_empty():
		printerr("Moteur Godot indisponible · ", app.last_error)
		quit(1)
		return
	app.timer.stop()
	await press(named("EntryNewCareer"))
	var start := named("CreationStart") as Button
	check(named("CreationCompetitionSummary") != null and named("CreationClubTitle") == null and start != null and start.disabled, "La création présente le championnat avant le choix d’un club")
	check(named("CreationPagination") == null and app.find_children("CreationClub*", "Button", true, false).size() == 14, "Toute l’Élite est présente dans une seule liste")
	check(text_present(app, "26 matchs par club") and text_present(app, "Le 13e dispute un barrage"), "Le résumé décrit le format et le barrage simulés")
	var grid := named("CreationClubGrid") as GridContainer
	check(grid != null and grid.columns == 3 and scroll_fits("CreationClubsScroll"), "La liste compacte affiche toute la grille en trois colonnes")
	await press(named("CreationClub0"))
	check(named("CreationClubTitle") != null and named("CreationCompetitionSummary") == null and not (named("CreationStart") as Button).disabled, "Choisir un club révèle sa fiche et active la prise de poste")
	check(named("CreationStadium") != null and text_present(app, "Trésorerie de départ") and not text_present(app, "Trésorerie de départ simulée"), "La fiche présente le stade et la trésorerie de départ")
	check(text_present(app, "Stade Ernest Wallon") and text_present(app, "jeu de mouvement") and named("CreationClubPresentation") != null, "La présentation raconte l’histoire du club choisi et indique son stade")
	check(named("CreationClubFounded") != null and text_present(app, "Fondé en 1907") and text_present(app, "25 titres") and text_present(app, "6 titres"), "La fiche affiche la fondation et les titres du club anonymisé")
	creation_dossier_fits(app.pack_manager.creation_catalogue()[0].history.results.size(), "club 0 · 1280 × 720")
	var roster_summary := named("CreationRosterSummary")
	check(roster_summary != null and text_present(roster_summary, "Note moyenne") and not text_present(roster_summary, "Avants") and not text_present(roster_summary, "Trois-quarts"), "La note moyenne reste dans la fiche sans les compteurs par ligne")
	check(text_present(app, "Atout actuel") and text_present(app, "Point à renforcer") and text_present(app, "Meilleure note") and text_present(app, "Adversaires du même poste") and text_present(app, "ce niveau"), "La fiche détaille les postes et compare leur niveau aux autres clubs de la division")
	check("Note moyenne" in named("CreationClub0").tooltip_text, "La grille permet de comparer les notes moyennes avant de choisir un club")
	check(app.pack_manager.mode("creation") == "world-champ" and app.model.meta.champCatalogue.size() == 116, "La création ouvre directement le Monde complet")
	check(named("CreationEditionRow") == null and named("CreationMode_common") == null, "Les éditions intermédiaires sont absentes du parcours normal")
	check(app.model.meta.champDatabase.playerCount == 5878 and app.model.meta.champCatalogue.filter(func(c: Dictionary): return c.playable).size() == 114, "5 878 joueurs et 114 clubs jouables")
	await check_creation_geometry()
	for code in ["FR", "GB", "JP"]:
		var country := named("CreationCountry_" + code) as Button
		check(country != null and country.icon != null, "Drapeau visible · " + code)
	check(named("CreationDivision_nationale") != null and named("CreationDivision_prem") == null and named("CreationDivision_urc") == null, "France ne montre que ses divisions")
	check(text_present(app, "Championnats de France"), "Le groupe des divisions nomme le pays actif")
	var french_connector := named("CreationCountryConnector") as Control
	check(french_connector != null and french_connector.get_parent().get_parent() == named("CreationCountry_FR").get_parent(), "Le repère graphique part de l’onglet France")
	await press(named("CreationCountry_GB"))
	check(named("CreationDivision_prem") != null and named("CreationDivision_champ") != null and named("CreationDivision_urc") == null, "Angleterre montre PREM et Champ")
	check(text_present(app, "Championnats d’Angleterre") and not text_present(app, "Championnats de France"), "Le titre des divisions suit l’Angleterre")
	var english_connector := named("CreationCountryConnector") as Control
	check(english_connector != null and english_connector.get_parent().get_parent() == named("CreationCountry_GB").get_parent(), "Le repère graphique suit l’onglet Angleterre")
	await press(named("CreationCountry_JP"))
	check(named("CreationDivision_jlo-d1") != null and named("CreationDivision_jlo-d2") != null and named("CreationDivision_champ") == null, "Japon montre ses deux divisions")
	check(text_present(app, "Championnats du Japon"), "Le titre des divisions suit le Japon")
	await press(named("CreationCountry_international"))
	check(named("CreationDivision_srp") != null and named("CreationDivision_urc") != null and named("CreationDivision_prem") == null, "URC et Pacifique sont sous International")
	check(text_present(app, "Championnats internationaux"), "Les compétitions internationales forment leur propre groupe")
	check(text_present(app, "114 clubs jouables"), "Le total mondial reste visible après filtrage")
	await press(named("CreationCountry_FR"))
	check(named("CreationCompetitionSummary") != null and (named("CreationStart") as Button).disabled, "Changer de championnat demande un nouveau choix explicite")
	await press(named("CreationClub0"))
	var base := named("CreationBaseIdentity") as Button
	var importer := named("CreationImportReality") as Button
	check(base != null and base.text == "Jeu de base" and base.disabled, "Le jeu de base est la présentation initiale")
	check(importer != null and importer.text == "Importer une autre réalité" and named("CreationPackChoice") == null, "Le mod se choisit depuis un fichier ZIP")
	await press(importer)
	check(app.route == "Création" and app.pack_manager.picker.visible, "Importer ouvre directement le sélecteur de fichiers")
	app.pack_manager.picker.get_cancel_button().pressed.emit()
	await settle()
	check(app.route == "Création" and not app.pack_manager.picker.visible, "Annuler conserve l’écran de création")
	await press(importer)
	app.pack_manager.picker.file_selected.emit(OS.get_environment("CD_WORLD_UI_CHAMP_PACK"))
	app.pack_manager.picker.hide()
	await response()
	check(app.route == "Packs" and not app.pack_manager.preview().is_empty(), "Le ZIP sélectionné est analysé pour le Monde complet")
	await activate_inspected_pack()
	await press(button("← Retour"))
	check(named("CreationClubTitle").text == "Club Monde complet témoin", "Le pack activé apparaît dans le catalogue commun")
	app.pack_manager.creation_mode = "world"
	app._render()
	await settle()
	check(app.pack_manager.mode("creation") == "world", "Le scénario historique charge son propre catalogue")
	await enumerate_clubs()
	await press(named("CreationCountry_GB"))
	await press(named("CreationDivision_prem"))
	await press(button("PACKS ET IDENTITÉS"))
	check(text_present(app, "NOUVELLE CARRIÈRE") and app.pack_manager.mode() == "world", "Édition active indiquée dans les packs")
	await import_pack(OS.get_environment("CD_WORLD_UI_FRANCE_PACK"), false)
	check(button("INSTALLER CE PACK") == null, "Une archive France ne peut pas être installée comme pack Monde")
	app._clear_dialogs()
	await install_and_select(OS.get_environment("CD_WORLD_UI_WORLD_PACK"))
	check(app.model.meta.worldPackCreation != "base" and app.model.meta.legacyPackCreation == "base", "Préférence Monde isolée")
	await press(button("← Retour"))
	check(named("CreationClubTitle").text == "Bath témoin", "Identité Monde appliquée avant création")
	check(is_instance_valid(app.coach),"Guide présent dans le formulaire")
	if is_instance_valid(app.coach):
		app.coach.open_help()
		await settle()
		check(app.coach.expanded,"Aide de création ouverte pendant le test au clic")
	if not await click_action(named("CreationStart")):
		await finish()
		return
	await response()
	check(app.model.meta.mode == "world" and int(app.model.club.id) == 30 and app.model.club.name == "Bath témoin", "Vraie carrière mondiale PREM créée avec son pack")
	await check_competitions()
	app.pack_manager.open("career")
	await settle()
	check(text_present(app, "CARRIÈRE EN COURS") and app.pack_manager.mode() == "world", "Packs de la carrière ouverte filtrés pour le Monde")
	await press(button("Choisir le jeu de base"))
	await response()
	check(app.model.packs.career == "base" and app.model.meta.worldPackCreation != "base", "Changer le pack de la carrière conserve la préférence de création")
	await press(button("UTILISER CE PACK  →"))
	await response()
	check(app.model.club.name == "Bath témoin", "L’identité de carrière mondiale peut être réappliquée")
	app.pack_manager.creation_mode = "common"
	app._navigate("Création")
	await settle()
	await press(button("PACKS ET IDENTITÉS"))
	check(not text_present(app, "Identités Monde test"), "Packs Monde filtrés côté France malgré la carrière Monde ouverte")
	await install_and_select(OS.get_environment("CD_WORLD_UI_FRANCE_PACK"))
	check(app.model.meta.legacyPackCreation != "base" and app.model.meta.worldPackCreation == app.model.packs.career, "Préférence France isolée de la carrière Monde")
	await press(button("← Retour"))
	check(named("CreationClubTitle").text == "Toulouse témoin" and named("CreationDivision_prem") == null, "France 30 retrouve son catalogue et son pack")
	await press(named("CreationStart"))
	await press(button("ANNULER"))
	check(app.model.meta.mode == "world", "Annuler conserve la carrière ouverte")
	await press(named("CreationStart"))
	await press(button("CONFIRMER"))
	await response()
	check(app.model.meta.mode == "common" and int(app.model.club.id) == 0 and app.model.club.name == "Toulouse témoin", "France 30 créée après confirmation et liaison de son pack")
	await finish()
