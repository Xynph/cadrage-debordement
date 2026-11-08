extends SceneTree
const G = preload("res://ui/carnet_skin.gd")
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
	check(root.content_scale_size == Vector2i(mini(resolution.x,1920),mini(resolution.y,1080)), "Référence native conservée " + str(resolution))
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
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await worker()
	await command("new_career", {"club":0,"mode":"common"})
	app.coach.close(); await settle()
	await command("export")
	var before: String = app.model.meta.exportText
	var disk := str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await resize_to(resolution)
		app._navigate("Bureau"); await settle(); app.coach.close()
		var summary := named("OfficeSummary")
		check(summary.size.y <= 90, "Repères contenus en hauteur " + str(resolution))
		var tiles := summary.find_children("OfficeSummaryTile*","PanelContainer",true,false)
		check(tiles.size() == 5, "Cinq repères distincts au Bureau " + str(resolution))
		for tile: Control in tiles: check(summary.get_global_rect().encloses(tile.get_global_rect()), "Tuile contenue " + str(tile.name))
		var decisions: Control = named("OfficeDecisions")
		check(decisions.size.x >= 280,"Feuillet décisions assez large " + str(resolution))
		var columns: Control = named("OfficeColumns")
		check(columns != null and columns.get_child(2).visible == (resolution.x > 1280),"Deux colonnes compactes / trois larges " + str(resolution))
		var office_width := decisions.size.x
		var summary_height := summary.size.y
		await capture("bureau-" + str(resolution.x))
		app._navigate("Effectif"); await settle(); app.coach.close()
		var roster: ScrollContainer = named("SquadScroll")
		check(named("RosterPagination") != null,"Effectif paginé sans liste infinie")
		var dossier_tabs := named("ProfileTabs")
		check(dossier_tabs is TabContainer and dossier_tabs.get_tab_count() == 4,"Dossier réparti en quatre tuiles de lecture")
		if dossier_tabs is TabContainer:
			check(dossier_tabs.get_tab_title(2)=="Contrat","Contrat conserve le troisième onglet du dossier")
			dossier_tabs.current_tab=2; await settle()
			for id in ["OfferRenewal","PlayerLoad"]:
				check(named(id).is_visible_in_tree() and named("ProfileScroll").get_global_rect().encloses(named(id).get_global_rect()),"Action du dossier visible directement "+id+" "+str(resolution))
				check(named("ProfileContract").get_global_rect().encloses(named(id).get_global_rect()),"Action contrat contenue dans son vrai onglet "+id+" "+str(resolution))
			dossier_tabs.current_tab=0; await settle()
		var profile_scroll: ScrollContainer = named("ProfileScroll")
		var overview: ScrollContainer = named("ProfileOverview")
		var empty_below: float = profile_scroll.get_global_rect().end.y-dossier_tabs.get_global_rect().end.y
		check(absf(empty_below)<=16,"Dossier : les onglets utilisent le bas du feuillet, vide="+str(empty_below)+" "+str(resolution))
		for id in ["OpenPlayerCoachNote","CompareSelected"]:
			check(named(id).is_visible_in_tree() and overview.get_global_rect().encloses(named(id).get_global_rect()) and profile_scroll.get_global_rect().encloses(named(id).get_global_rect()),"Action Aperçu entièrement visible dans son vrai viewport "+id+" "+str(resolution))
		check(overview.get_v_scroll_bar().max_value<=overview.get_v_scroll_bar().page+1,"Aperçu : note, radar et comparaison tiennent sans défilement "+str(resolution))
		print("PROFILE_GEOMETRY ",resolution," dossier=",profile_scroll.size.y," tabs=",dossier_tabs.size.y," overview=",overview.size.y," blank=",empty_below)
		var rows := 0
		for row: Button in roster.find_children("*","Button",true,false):
			if roster.get_global_rect().encloses(row.get_global_rect()): rows += 1
		check(rows >= 3, "Au moins trois joueurs entiers " + str(resolution))
		var toolbar := named("RosterTools")
		check(toolbar != null, "Barre de lecture dédiée")
		if toolbar != null:
			for button: Button in toolbar.find_children("*","Button",true,false):
				check(button.size.y <= 42, "Commande compacte lisible " + str(button.name))
		measurements.append({"window":str(resolution),"canvas":str(app.size),"roster_rows":rows,"roster_height":roster.size.y,"office_decisions_width":office_width,"office_summary_height":summary_height,"office_columns":2 if resolution.x == 1280 else 3,"profile_height":profile_scroll.size.y,"profile_tabs_height":dossier_tabs.size.y,"profile_overview_height":overview.size.y,"profile_blank_below":empty_below})
		await capture("effectif-" + str(resolution.x))
		app._navigate("Finances"); await settle(); app.coach.close()
		await capture("finances-" + str(resolution.x))
		for route in ["Effectif","Composition","Préparation","Recrutement","Calendrier","Classements","Finances","Club"]:
			app._navigate(route); await settle(); app.coach.close()
			var bar:VScrollBar=app.body_scroll.get_v_scroll_bar()
			check(bar.max_value<=bar.page+1,"Aucun défilement global nécessaire "+route+" "+str(resolution))
			if route=="Préparation":
				named("CarnetPreparation")._choose(2);await settle()
				for button:Button in named("PreparationEntrainement").find_children("*","Button",true,false):
					check(app.body_scroll.get_global_rect().encloses(button.get_global_rect()),"Action entraînement directement visible "+str(button.name)+" "+str(resolution))
			if route=="Recrutement":
				for button:Button in named("MarketScroll").find_children("*","Button",true,false):
					check(named("MarketScroll").get_global_rect().encloses(button.get_global_rect()),"Offre/suivi directement visible "+str(button.text)+" "+str(resolution))
			for list_id in ["CalendarScroll","StandingsScroll","FinanceScroll"]:
				var list:ScrollContainer=named(list_id)
				if list!=null:
					check(list.get_v_scroll_bar().max_value<=list.get_v_scroll_bar().page+1,"Toute la page tient sans défilement local "+list_id+" "+str(resolution))
			for pager_id in ["RosterPagination","MarketPagination","CalendarPagination","StandingsPagination","FinancePagination"]:
				var pager:=named(pager_id)
				if pager!=null:check(app.body_scroll.get_global_rect().encloses(pager.get_global_rect()),"Pagination accessible directement "+pager_id+" "+str(resolution))
			await capture(route.to_lower()+"-dense-"+str(resolution.x))
		app._navigate("Création");await settle()
		check(app.get_global_rect().encloses(named("CreationStart").get_global_rect()),"Création : validation directement visible "+str(resolution))
		check(app.get_global_rect().encloses(named("CreationPagination").get_global_rect()),"Création : huit tuiles et pagination visibles "+str(resolution))
		await capture("creation-dense-"+str(resolution.x))
	await resize_to(Vector2i(1280,720))
	app._navigate("Effectif");await settle();app.coach.close()
	var stable_search:=named("RosterSearch")
	var seen:Array[String]=[]
	for i in 60:
		for row:Button in named("SquadScroll").find_children("*","Button",true,false):
			var id:=str(row.get_meta("player_id",""))
			if id not in seen:seen.append(id)
		var next:Button=named("RosterPaginationNext")
		if next.disabled:break
		next.grab_focus();await key(KEY_ENTER)
		check(named("RosterSearch")==stable_search,"Pagination ne reconstruit pas la recherche")
	check(seen.size()==app.model.squad.size(),"Tous les joueurs atteignables par pagination clavier")
	app._navigate("Bureau"); await settle(); app.coach.close()
	var office_columns := named("OfficeColumns")
	var standings_action := named("OfficeStandingsAction")
	var standings_scroll := named("OfficeStandings").get_parent()
	standings_action.grab_focus(); await settle()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(1280,720)]:
		await resize_to(resolution)
		check(named("OfficeColumns") == office_columns and named("OfficeStandingsAction") == standings_action,"Bureau adapté sur les mêmes instances " + str(resolution))
		check(named("OfficeStandings").get_parent() == standings_scroll,"Défilement cap sportif conservé " + str(resolution))
		check(standings_action.has_focus(),"Focus du cap sportif conservé " + str(resolution))
		var ancestor := standings_action.get_parent()
		while ancestor != null and ancestor != app:
			if ancestor is ScrollContainer: check(ancestor.get_global_rect().encloses(standings_action.get_global_rect()),"Focus du cap visible dans son feuillet " + str(resolution))
			ancestor = ancestor.get_parent()
	app._navigate("Effectif"); await settle(); app.coach.close()
	var search: LineEdit = named("RosterSearch")
	search.text = "Équipe œuvrée — éléphant"; search.caret_column = 10; search.select(2,10); search.grab_focus()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]: await resize_to(resolution)
	check(named("RosterSearch") == search and search.text == "Équipe œuvrée — éléphant" and search.caret_column == 10 and search.has_selection(), "Saisie Unicode, caret et sélection conservés sur la même instance")
	check(search.has_focus(), "Focus conservé après redimensionnement")
	search.text = ""; search.text_changed.emit(""); await settle()
	var first: Button = named("SquadScroll").find_children("*","Button",true,false)[0]
	first.grab_focus(); await key(KEY_ENTER)
	check(first.has_focus() and not app.selected_player.is_empty(), "Activation clavier du vrai dossier conserve le focus")
	await capture("effectif-focus-" + str(root.size.x))
	# A popup and its unsaved amount survive resize without committing anything.
	preload("res://ui/squad_views.gd").contract(app,app.model.squad[0],false); await settle()
	var offer: Window = app.find_child("ContractOffer",true,false)
	var salary: LineEdit = offer.find_child("OfferSalary",true,false).get_line_edit()
	salary.grab_focus(); await settle()
	salary.text = "12345"; salary.caret_column = 3
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		await resize_to(resolution)
		check(is_instance_valid(offer) and offer.visible and salary.text == "12345" and salary.caret_column == 3,"Brouillon du même dialogue préservé " + str(resolution))
		await capture("contrat-" + str(resolution.x))
	offer.hide(); offer.queue_free(); await settle()
	check(FileAccess.get_file_as_bytes(disk) == bytes,"Consultation et resize : octets du profil inchangés")
	await command("export")
	check(app.model.meta.exportText == before,"Consultation et resize : état complet et RNG identiques")
	finish()
