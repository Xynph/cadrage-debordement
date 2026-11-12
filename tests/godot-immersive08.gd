extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")

var checks := 0
var failures: Array[String] = []
var app: Control

func settle() -> void:
	for i in 8: await process_frame

func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse du vrai moteur")
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Commande native : " + id + " " + app.last_error)

func capture(id: String, close_coach: bool = true) -> void:
	if DisplayServer.get_name() == "headless": return
	if close_coach and is_instance_valid(app.coach): app.coach.close()
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join(id + ".png")) == OK, "Capture native : " + id)

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr("FAIL: " + message)

func caption_fits(button: Button) -> bool:
	if button == null: return false
	var font := button.get_theme_font("font")
	var size := button.get_theme_font_size("font_size")
	var width := font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var style := button.get_theme_stylebox("disabled" if button.disabled else "normal")
	return width + style.get_minimum_size().x <= button.size.x + 1

func reference_rects(expected: Dictionary) -> void:
	for id: String in expected:
		var node := app.find_child(id,true,false) as Control
		var actual := node.get_global_transform()*Rect2(Vector2.ZERO,node.size) if node!=null else Rect2()
		var source: Rect2 = expected[id]
		check(node!=null and actual.position.distance_to(source.position)<=1.5 and actual.size.distance_to(source.size)<=1.5,
			"Rectangle du gabarit approuvé · %s · %s / %s" % [id,str(actual),str(source)])

func click(control: Control, fraction: Vector2 = Vector2(.5,.5)) -> void:
	var point := control.get_global_transform()*(control.size*fraction)
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed=down
		root.push_input(event,true)
	await process_frame

func key(code: Key, ctrl: bool = false, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.ctrl_pressed=ctrl
	event.alt_pressed=alt
	event.pressed=true
	root.push_input(event,true)
	await settle()

func entry() -> void:
	check(app.find_child("ImmersiveWelcome",true,false)!=null,"L’accueil natif utilise la composition immersive")
	var art: TextureRect = app.find_child("Art_entry_ground",true,false)
	check(art!=null and art.texture!=null,"Le nouveau stade IA est chargé dans l’accueil")
	check(app.find_child("EntryResume",true,false)==null,"Aucune reprise proposée sans carrière")
	var world: Array = app.pack_manager.creation_catalogue()
	if not world.is_empty():
		var world_chip: Panel = app.find_child("EntryWorldCount",true,false)
		var playable := world.filter(func(club: Dictionary): return club.get("playable",true)).size()
		check(world_chip!=null and world_chip.get_child(0).text=="Monde · %d clubs jouables" % playable,"Accueil distingue les clubs jouables des clubs invités")
	await capture("00-accueil-2560x1440")
	var new_career: Button = app.find_child("EntryNewCareer",true,false)
	if new_career==null: return
	await click(new_career)
	await settle()
	check(app.find_child("CreationEditionRow",true,false)==null,"La création montre un seul catalogue")
	check(app.route=="Création" and app.find_child("CreationStart",true,false)!=null,"Nouvelle carrière ouvre le vrai catalogue et l’action de création")
	var summary := app.find_child("CreationCompetitionSummary",true,false) as Control
	var choices := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
	check(app.find_child("CreationPagination",true,false)==null and summary!=null and choices!=null and choices.size.y>=240,"Le championnat précède une grille unique de clubs")
	if choices!=null:
		var first: Button = choices.find_children("CreationClub*","Button",true,false)[0]
		var second: Button = choices.find_children("CreationClub*","Button",true,false)[1]
		var first_id := first.name
		var expected := int(str(second.name).trim_prefix("CreationClub"))
		await click(second)
		await settle()
		var title := app.find_child("CreationClubTitle",true,false) as Label
		check(int(app.selected_club)==expected and title!=null and app.find_child("CreationRosterSummary",true,false)!=null,"Le dossier illustré suit le vrai club choisi")
		await click(app.find_child(first_id,true,false))
		await settle()
	await capture("07-creation-2560x1440")
	app._navigate("Accueil")
	await settle()
	var packs: Button = app.find_child("EntryPacks",true,false)
	await click(packs)
	await settle()
	check(app.route=="Packs" and app.pack_manager.scope=="creation" and app.find_child("CarnetPacks",true,false)!=null,"L’atelier des identités conserve le gestionnaire de packs de création")
	var base_art := app.find_child("Art_maquette_reality_base",true,false) as TextureRect
	var import_art := app.find_child("Art_match_tunnel",true,false) as TextureRect
	check(base_art!=null and base_art.texture!=null and import_art!=null and import_art.texture!=null and app.find_child("PackNewCareer",true,false)==null,"L’atelier vide montre le jeu de base et le parcours d’import")
	await capture("08-packs-2560x1440")
	app.pack_manager.back()
	await settle()
	check(app.route=="Accueil","Retour depuis l’atelier conserve le parcours d’entrée")

func pacific() -> void:
	app.pack_manager.creation_mode = "world-pacific"
	app._render()
	await settle()
	check(app.pack_manager.mode("creation")=="world-pacific","Le nouveau catalogue par défaut est celui du Pacifique")
	var catalogue: Array = app.model.meta.get("pacificCatalogue", [])
	var count := catalogue.filter(func(club: Dictionary): return club.get("playable",true)).size()
	var badge := app.find_child("EntryWorldCount",true,false) as Panel
	check(badge!=null and badge.get_child(0).text=="Monde · %d clubs jouables" % count,"Accueil indique le vrai nombre de clubs jouables au Pacifique")
	await click(app.find_child("EntryNewCareer",true,false))
	await settle()
	if not await edition_action("CreationCountry_international"): return
	var division := app.find_child("CreationDivision_srp",true,false) as Button
	check(division!=null,"Le vrai choix de division Pacifique est présent")
	if division==null: return
	await click(division)
	await settle()
	var choices := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
	var last := app.find_child("CreationClub67",true,false) as Button
	check(choices!=null and last!=null and choices.get_global_rect().encloses(last.get_global_rect()),"Les dix clubs du Pacifique restent visibles dans Création en 1440p")
	var ground := app.find_child("Art_pacific_ground",true,false) as TextureRect
	check(ground!=null and ground.texture!=null,"Le terrain côtier original est importé dans la création Pacifique")
	await capture("43-pacifique-creation-2560x1440")
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	app._render()
	await settle()
	choices=app.find_child("CreationClubsScroll",true,false)
	last=app.find_child("CreationClub67",true,false)
	check(choices!=null and last!=null and choices.get_global_rect().grow(1).encloses(last.get_global_rect()),"Les dix clubs du Pacifique restent visibles dans Création en 720p")
	await capture("49-pacifique-creation-1280x720")
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	app._render()
	await settle()
	await click(app.find_child("CreationClub58",true,false))
	await settle()
	await click(app.find_child("CreationStart",true,false))
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.bridge.last_response_ok and app.model.meta.get("edition")=="world-pacific" and app.model.club.id==58,"Le vrai club Pacifique est créé par son bouton")
	if not app.bridge.last_response_ok: return
	var preparation: Dictionary = app.model.meta.get("pacificPreparation",{})
	check(not preparation.is_empty() and app.model.next==null,"Le moteur fournit l’attente du premier match")
	app._navigate("Composition")
	await settle()
	check(app.find_child("TacticsNoReport",true,false)!=null and app.find_child("TacticsVigilance",true,false)!=null,"Tactique reste complète sans rapport sur le prochain adversaire")
	app._navigate("Presse")
	await settle()
	var press_division := app.find_child("PressDivision",true,false) as OptionButton
	check(press_division!=null and press_division.selected>=0 and press_division.get_item_text(press_division.selected)=="Super Rugby Pacific","Presse 1440p reprend le vrai nom de la compétition depuis le classement")
	app._navigate("Bureau")
	await settle()
	var office := app.find_child("OfficePreparationAction",true,false) as Button
	check(office!=null and office.text.contains("PRÉPARATION"),"Le Bureau expose la préparation avant le premier match")
	await capture("44-pacifique-bureau-2560x1440")
	app._navigate("Calendrier")
	await settle()
	var calendar := app.find_child("CompetitionPacificLink",true,false) as Button
	check(calendar!=null,"Le calendrier signale la préparation Pacifique")
	await capture("45-pacifique-calendrier-2560x1440")
	if calendar!=null: await click(calendar)
	else: app._navigate("Rivalités")
	await settle()
	check(app.route=="Rivalités","Le calendrier ouvre le dossier de préparation")
	var advance := app.find_child("PacificPreparationAdvance",true,false) as Button
	check(advance!=null,"La commande officielle est accessible dans Rivalités en 1440p")
	await capture("46-pacifique-preparation-2560x1440")
	if advance==null or preparation.is_empty(): return
	var start := int(app.model.meta.week)
	await click(advance)
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.bridge.last_response_ok and int(app.model.meta.week)==start+mini(4,int(preparation.weeksUntil)),"Le clic effectue au plus quatre semaines réelles")
	app._navigate("Bureau")
	await settle()
	office=app.find_child("OfficePreparationAction",true,false)
	start=int(app.model.meta.week)
	await click(office)
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.bridge.last_response_ok and int(app.model.meta.week)>start,"Le Bureau fait avancer la même préparation")
	app._navigate("Rivalités")
	await settle()
	for i in 6:
		if app.model.next is Dictionary: break
		advance=app.find_child("PacificPreparationAdvance",true,false)
		if advance==null: break
		await click(advance)
		await worker()
		await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.model.next is Dictionary and app.model.next.get("date")=="2027-02-13" and app.model.next.get("competitionId")=="srp","La préparation s’arrête sur le vrai premier match Pacifique")
	app._navigate("Bureau")
	await settle()
	var date := app.find_child("OfficeFixtureDate",true,false) as Label
	var venue := app.find_child("OfficeFixtureVenue",true,false) as Label
	check(date!=null and date.text.begins_with("13/02/2027"),"Bureau 1440p : date réelle du prochain match")
	check(venue!=null and venue.text=="Terrain désigné","Bureau 1440p : terrain encore à désigner")
	await capture("47-pacifique-premier-match-2560x1440")
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	app._navigate("Calendrier")
	app._navigate("Bureau")
	await settle()
	date=app.find_child("OfficeFixtureDate",true,false) as Label
	venue=app.find_child("OfficeFixtureVenue",true,false) as Label
	check(date!=null and date.text.begins_with("13/02/2027") and venue!=null and venue.text=="Terrain désigné","Bureau 720p : date et terrain sont préservés")
	await capture("48-pacifique-premier-match-1280x720")
	app._navigate("Presse")
	await settle()
	press_division=app.find_child("PressDivision",true,false) as OptionButton
	check(press_division!=null and press_division.selected>=0 and press_division.get_item_text(press_division.selected)=="Super Rugby Pacific","Le vrai nom du Pacifique est conservé dans le journal compact")

func edition_action(id: String) -> bool:
	var button := app.find_child(id,true,false) as Button
	var available := button!=null and button.is_visible_in_tree() and not button.disabled
	check(available,"Commande utilisable · " + id)
	if not available: return false
	var parent := button.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent=parent.get_parent()
	await settle()
	await click(button)
	await settle()
	return true

func japan(compact: bool) -> void:
	app.pack_manager.creation_mode = "world-japan"
	app._render()
	await settle()
	var division := "jlo-d2" if compact else "jlo-d1"
	var dimensions := "1280x720" if compact else "2560x1440"
	if compact:
		root.size=Vector2i(1280,720)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await settle()
		app._render()
		await settle()
	var catalogue: Array = app.model.meta.get("japanCatalogue",[])
	var playable := catalogue.filter(func(club: Dictionary): return club.get("playable",true)).size()
	var badge := app.find_child("EntryWorldCount",true,false) as Panel
	check(badge!=null and badge.get_child(0).text=="Monde · %d clubs jouables" % playable,"Accueil compte les vrais clubs jouables du catalogue Japon")
	if not await edition_action("EntryNewCareer"): return
	if not await edition_action("CreationCountry_JP"): return
	if not await edition_action("CreationDivision_"+division): return
	var first := 80 if compact else 68
	var last := 88 if compact else 80
	var scroll := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
	for club_id in range(first,last):
		var club := app.find_child("CreationClub%d" % club_id,true,false) as Button
		check(scroll!=null and club!=null and scroll.get_global_rect().grow(1).encloses(club.get_global_rect()),"Club Japon %d dans le sélecteur à %s" % [club_id,dimensions])
	var ground := app.find_child("Art_japan_ground",true,false) as TextureRect
	var texture: Texture2D = ground.texture if ground!=null else null
	if texture is AtlasTexture: texture=texture.atlas
	check(texture!=null and texture.resource_path.ends_with("japan-ground.png"),"Le PNG original est décodé et cadré dans le jeu")
	await capture(("54" if compact else "53")+"-japon-creation-"+dimensions)
	var club_id := 80 if compact else 72
	if not await edition_action("CreationClub%d" % club_id): return
	if not await edition_action("CreationStart"): return
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	var meta: Dictionary = app.model.meta
	check(app.bridge.last_response_ok and meta.get("edition")=="world-japan" and meta.get("mode")=="world" and meta.get("leagueId")==division and app.model.get("club",{}).get("id")==club_id,"Création de la vraie carrière dans la division sélectionnée")
	if not app.bridge.last_response_ok: return
	check(app.model.next==null and meta.get("japanPreparation",{}).get("nextDate")=="2026-12-13","Premier match annoncé par le moteur pendant l’attente")
	await capture(("58" if compact else "55")+"-japon-bureau-"+dimensions)
	var actions := ["OfficePreparationAction","JapanPreparationAdvance","JapanPreparationDossierAdvance","ImmersiveContinue"]
	for i in actions.size():
		match i:
			1:
				app._navigate("Rivalités")
				await settle()
				await capture(("59" if compact else "56")+"-japon-rivalites-"+dimensions)
			2:
				if compact: app._navigate("Préparation")
				else:
					app._navigate("Calendrier")
					await settle()
					if not await edition_action("CompetitionJapanLink"): return
				check(app.route=="Préparation","Le calendrier ouvre la préparation japonaise")
			3: app._navigate("Bureau")
		await settle()
		var week := int(app.model.meta.week)
		var limit := int(app.model.meta.get("japanPreparation",{}).get("weeksUntil",0))
		if not await edition_action(actions[i]): return
		await worker()
		await ContextualFlow.settle_club_meetings(app, self, check)
		check(app.bridge.last_response_ok and int(app.model.meta.week)==week+mini(4,limit),"Avance réelle jusqu’à la semaine du match · " + str(actions[i]))
	var next: Variant = app.model.next
	check(next is Dictionary and next.get("competitionId")==division and next.get("date")=="2026-12-13","L’avance s’arrête au vrai premier match de la division")
	if not next is Dictionary: return
	var date := app.find_child("OfficeFixtureDate",true,false) as Label
	var venue := app.find_child("OfficeFixtureVenue",true,false) as Label
	var projection := preload("res://ui/immersive08/projection.gd")
	check(date!=null and date.text.begins_with("13/12/2026") and venue!=null and venue.text==projection.fixture_venue(next),"Le Bureau montre la date et le lieu réels à " + dimensions)
	await capture(("60" if compact else "57")+"-japon-premier-match-"+dimensions)
	if not await edition_action("OfficePreparationAction"): return
	check(app.route=="Préparation" and app.find_child("JapanPreparationDossierAdvance",true,false)==null,"Le vrai dossier de match a remplacé l’avance")
	app._navigate("Match")
	await settle()
	check(app.model.get("selection",{}).get("valid",false),"La feuille de match réelle est valide")
	if app.pause_button==null: return
	await click(app.pause_button)
	await worker()
	check(app.bridge.last_response_ok and app.model.live is Dictionary and app.model.live.get("pair")==next.get("pair"),"Coup d’envoi des deux vraies équipes japonaises")

func nationale(compact: bool) -> void:
	app.pack_manager.creation_mode = "world-nationale"
	app._render()
	await settle()
	var dimensions := "1280x720" if compact else "2560x1440"
	if compact:
		root.size=Vector2i(1280,720)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await settle()
		app._render()
		await settle()
	var catalogue: Array = app.model.meta.get("nationaleCatalogue",[])
	var playable := catalogue.filter(func(club: Dictionary): return club.get("playable",true)).size()
	var badge := app.find_child("EntryWorldCount",true,false) as Panel
	check(badge!=null and badge.get_child(0).text=="Monde · %d clubs jouables" % playable,"Accueil compte les vrais clubs jouables de l’édition Nationale")
	if not await edition_action("EntryNewCareer"): return
	if not await edition_action("CreationCountry_FR"): return
	if not await edition_action("CreationDivision_nationale"): return
	var scroll := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
	for club_id in range(88,102):
		var club := app.find_child("CreationClub%d" % club_id,true,false) as Button
		check(scroll!=null and club!=null and scroll.get_global_rect().grow(1).encloses(club.get_global_rect()),"Club de Nationale %d visible à %s" % [club_id,dimensions])
		if club!=null:
			for label: Label in club.find_children("*","Label",true,false):
				check(club.get_global_rect().grow(1).encloses(label.get_global_rect()),"Le libellé %s tient dans la carte de club" % label.text)
	var picture := app.find_child("Art_nationale_ground",true,false) as TextureRect
	var texture: Texture2D = picture.texture if picture!=null else null
	if texture is AtlasTexture: texture=texture.atlas
	check(texture!=null and texture.resource_path.ends_with("nationale-ground.png"),"Illustration originale Nationale décodée dans Création")
	var preview := app.find_child("Art_entry_preview",true,false) as TextureRect
	var preview_credit := app.find_child("EntryPreviewCredit",true,false) as Label
	check(preview!=null and preview.get_meta("immersive_art", "")=="entry-preview" and preview_credit!=null and preview_credit.is_visible_in_tree(),"L’aperçu du club sans photo utilise l’illustration de tunnel identifiée")
	if not compact:
		var selected: int = app.selected_club
		(app.find_child("CreationClub88",true,false) as Button).grab_focus()
		for size in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
			root.size = size
			if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(size)
			await create_timer(.2).timeout
			await settle()
			var creation_list := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
			var start := app.find_child("CreationStart",true,false) as Button
			var last_club := app.find_child("CreationClub101",true,false) as Button
			check(creation_list!=null and last_club!=null and creation_list.get_global_rect().grow(1).encloses(last_club.get_global_rect()),"La dernière carte de Nationale reste visible après redimensionnement à %s" % size)
			check(start!=null and root.get_visible_rect().grow(1).encloses(start.get_global_rect()),"L’action de création reste visible après redimensionnement à %s" % size)
			var focus := root.gui_get_focus_owner()
			check(focus!=null and focus.name=="CreationClub88" and app.selected_club==selected,"Le focus et la sélection survivent au redimensionnement à %s" % size)
	await capture(("63" if compact else "62")+"-nationale-creation-"+dimensions)
	var club_id := 101 if compact else 100
	if not await edition_action("CreationClub%d" % club_id): return
	if not await edition_action("CreationStart"): return
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	var meta: Dictionary = app.model.meta
	check(app.bridge.last_response_ok and meta.get("edition")=="world-nationale" and meta.get("leagueId")=="nationale" and app.model.get("club",{}).get("id")==club_id,"La carrière et le club sélectionnés sont confirmés par le moteur")
	var fixture: Variant = app.model.get("next")
	check(fixture is Dictionary and fixture.get("date")=="2026-08-21" and fixture.get("kickoffLocal")=="19:30","Le moteur annonce la date et l’heure locales de la première journée")
	if not fixture is Dictionary: return
	var date := app.find_child("OfficeFixtureDate",true,false) as Label
	var venue := app.find_child("OfficeFixtureVenue",true,false) as Label
	var projection := preload("res://ui/immersive08/projection.gd")
	check(date!=null and date.text.contains("21/08/2026 · 19:30") and venue!=null and venue.text==projection.fixture_venue(fixture),"Le Bureau affiche l’heure et le terrain projetés à " + dimensions)
	await capture(("65" if compact else "64")+"-nationale-bureau-"+dimensions)
	app._navigate("Calendrier")
	await settle()
	var next_date := app.find_child("CompetitionNextDate",true,false) as Label
	var next_venue := app.find_child("CompetitionNextVenue",true,false) as Label
	check(next_date!=null and next_date.text==projection.fixture_date(fixture) and next_venue!=null and next_venue.text==projection.fixture_venue(fixture),"La tuile Calendrier garde la date et le terrain réels")
	if next_date!=null and next_venue!=null:
		check(next_date.get_global_rect().end.x < next_venue.get_global_rect().position.x,"La date reste dans la partie gauche sombre du prochain rendez-vous")
	await capture(("67" if compact else "66")+"-nationale-calendrier-"+dimensions)
	var fixture_id := ""
	for listed: Dictionary in app.model.calendar:
		if listed.date==fixture.date and listed.competitionId==fixture.competitionId and [listed.home.id,listed.away.id]==fixture.pair:
			fixture_id = str(listed.id)
			break
	var rows := app.find_children("CalendarFixture_*","Button",true,false)
	var first := rows.find_custom(func(row: Node): return row.get_meta("fixture_id", "")==fixture_id)
	check(first>=0,"Le premier match s’ouvre depuis sa vraie ligne de calendrier")
	if first>=0:
		await click(rows[first])
		await settle()
		var detail := app.get_node_or_null("CompetitionFixtureDetails") as AcceptDialog
		check(detail!=null and detail.visible,"Le détail de la rencontre est visible")
		if detail!=null:
			var texts := detail.find_children("*","Label",true,false).map(func(label: Label): return label.text)
			check("Date publiée" in texts and "Heure locale · Europe/Paris" in texts,"Le détail distingue la date publiée et le fuseau du match")
			await key(KEY_ESCAPE)
	if not await edition_action("CompetitionPrepareMatch"): return
	check(app.route=="Préparation" and app.model.next is Dictionary and app.model.next.pair==fixture.pair and app.model.next.date==fixture.date,"Le calendrier ouvre le vrai dossier du match")
	app._navigate("Composition")
	await settle()
	check(app.find_child("NationaleLicenceNotice",true,false)!=null,"La feuille de match affiche l’avis de qualification projeté")
	await capture(("69" if compact else "68")+"-nationale-tactique-"+dimensions)
	app._navigate("Match")
	await settle()
	check(app.pause_button!=null and app.model.get("selection",{}).get("valid",false),"Le coup d’envoi est disponible sur la feuille de match réelle")
	if app.pause_button==null: return
	await click(app.pause_button)
	await worker()
	check(app.bridge.last_response_ok and app.model.live is Dictionary and app.model.live.get("pair")==fixture.get("pair"),"Le match de Nationale démarre avec les deux vrais clubs")

func champ(compact: bool) -> void:
	var dimensions := "1280x720" if compact else "2560x1440"
	if compact:
		root.size=Vector2i(1280,720)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await settle()
		app._render()
		await settle()
	var catalogue: Array = app.model.meta.get("champCatalogue", [])
	var count := catalogue.filter(func(club: Dictionary): return club.get("playable",true)).size()
	var badge := app.find_child("EntryWorldCount",true,false) as Panel
	check(badge!=null and badge.get_child(0).text=="Monde · %d clubs jouables" % count,"Accueil compte les clubs jouables de Champ Rugby")
	if not await edition_action("EntryNewCareer"): return
	if not await edition_action("CreationCountry_GB"): return
	if not await edition_action("CreationDivision_champ"): return
	var scroll := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
	for id in range(102,116):
		var club := app.find_child("CreationClub%d" % id,true,false) as Button
		check(scroll!=null and club!=null and scroll.is_ancestor_of(club),"Club de Champ Rugby %d dans la liste unique à %s" % [id,dimensions])
	check(app.find_child("CreationCompetitionSummary",true,false)!=null,"Le championnat est présenté avant la sélection")
	var club_id := 115 if compact else 102
	if not await edition_action("CreationClub%d" % club_id): return
	check(app.find_child("CreationStadium",true,false)!=null,"Le dossier du club affiche son stade")
	await capture(("71" if compact else "70")+"-champ-creation-"+dimensions)
	if not await edition_action("CreationStart"): return
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.bridge.last_response_ok and app.model.meta.get("edition")=="world-champ" and app.model.meta.get("leagueId")=="champ" and app.model.club.get("id")==club_id and app.model.calendar.size()==26,"La carrière Champ est créée avec les 26 vraies rencontres")
	if app.model.calendar.is_empty(): return
	var first: Dictionary = app.model.calendar.front()
	check(app.model.get("next")==null and first.date=="2026-09-19" and first.timezone=="Europe/London" and str(first.scheduleSource).begins_with("rfu-published"),"La préparation précède le vrai premier match publié")
	var timeline := app.find_child("OfficeTimeline", true, false)
	var dates := timeline.find_children("OfficeTimelineDate*","Label",true,false) if timeline!=null else []
	check(dates.size()==7 and dates[0].text.contains("19/09/2026") and dates[0].text.contains(first.kickoffLocal),"Le fil du Bureau affiche les sept échéances et l’heure du premier match")
	await capture(("73" if compact else "72")+"-champ-bureau-"+dimensions)
	app._navigate("Rivalités" if compact else "Calendrier")
	await settle()
	if not await edition_action("ChampPreparationAdvance" if compact else "CompetitionChampAdvance"): return
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	var upcoming: Variant = app.model.get("next")
	check(app.bridge.last_response_ok and app.model.meta.week==first.week and upcoming is Dictionary and upcoming.date==first.date and upcoming.venue==first.venue,"La vraie commande s’arrête au prochain match, avec sa date et son terrain")
	if not upcoming is Dictionary: return
	app._navigate("Calendrier")
	await settle()
	var calendar_date := app.find_child("CompetitionNextDate",true,false) as Label
	var calendar_venue := app.find_child("CompetitionNextVenue",true,false) as Label
	check(calendar_date!=null and first.kickoffLocal in calendar_date.text and calendar_venue!=null and calendar_venue.text==first.venue,"Le calendrier présente l’heure locale et le lieu du premier match")
	await capture(("75" if compact else "74")+"-champ-calendrier-"+dimensions)
	var rows := app.find_children("CalendarFixture_*","Button",true,false)
	var found := rows.find_custom(func(row: Node): return row.get_meta("fixture_id", "")==str(first.id))
	check(found>=0,"La première journée du Champ est accessible au clic")
	if found>=0:
		await click(rows[found])
		await settle()
		var detail := app.get_node_or_null("CompetitionFixtureDetails") as AcceptDialog
		check(detail!=null and detail.visible,"Le vrai détail du match Champ est visible")
		if detail!=null:
			var notes := detail.find_children("*","Label",true,false).map(func(label: Label): return label.text)
			check("Date publiée par la RFU" in notes and "Heure locale · Europe/London" in notes and notes.any(func(note: String): return note.begins_with("Horaire publié")),"La fiche sépare la source de la date, l’horaire publié et le fuseau")
			await key(KEY_ESCAPE)
	if not await edition_action("CompetitionPrepareMatch"): return
	check(app.route=="Préparation" and app.model.next==upcoming,"Le calendrier ouvre le vrai dossier de préparation du match")

func reception() -> void:
	app._navigate("Bureau")
	await settle()
	var nav: Button = app.find_child("Nav_Réception", true, false)
	check(nav != null, "Réception accessible depuis le rail")
	if nav == null: return
	await click(nav)
	await settle()
	var list: VBoxContainer = app.find_child("InboxMessageRows", true, false)
	check(app.route == "Réception" and list != null, "La Réception ouvre un écran propre")
	if list == null: return
	check(list.get_child_count() == app.model.messages.size(), "Chaque message reçu du moteur est consultable")
	var portrait := app.find_child("Art_mail_staff", true, false) as TextureRect
	check(portrait != null, "Illustration de la Réception chargée en jeu")
	if portrait != null:
		var crop := portrait.texture as AtlasTexture
		check(crop!=null and crop.atlas.resource_path.ends_with("mail-staff.png") and crop.region.size.y>=177.0 and absf(portrait.size.x-523.0)<1.0,"Le bandeau garde le portrait original à sa proportion approuvée")
		var pitch := app.find_child("Art_mail_pitch",true,false) as TextureRect
		check(pitch!=null and pitch.texture!=null and absf(pitch.get_global_rect().end.x-portrait.get_global_rect().position.x)<1.0,"La scène originale d’entraînement rejoint le portrait sans espace")
	await capture("05-reception-2560x1440")
	var first: Button = list.get_child(0)
	var original: String = first.get_meta("message_text")
	app.find_child("InboxFolder1", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	var last: Button = list.get_child(list.get_child_count()-1)
	var unread: String = last.get_meta("message_text")
	last.pressed.emit()
	await settle()
	check(app.find_child("InboxMessageText", true, false).text == unread, "Un message sélectionné reste lisible dans les non lus")
	app.find_child("InboxToggleRead", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	check(list.get_child_count() == app.model.messages.size()-1, "Le marquage explicite retire le message des non lus")
	app.find_child("InboxFolder0", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	first = list.get_child(0)
	first.pressed.emit()
	await settle()
	check(app.find_child("InboxMessageText", true, false).text == original, "La sélection affiche le texte complet reçu")
	app.find_child("InboxToggleFavorite", true, false).pressed.emit()
	app.find_child("InboxFolder2", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	check(list.get_child_count() == 1, "Favoris limité au message épinglé")
	app.find_child("InboxToggleArchive", true, false).pressed.emit()
	app.find_child("InboxFolder3", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	check(list.get_child_count() == 1 and list.get_child(0).get_meta("message_text") == original, "Le dossier Archives retrouve le message traité")
	app.find_child("InboxToggleArchive", true, false).pressed.emit()
	app.find_child("InboxFolder0", true, false).pressed.emit()
	await settle()
	list = app.find_child("InboxMessageRows", true, false)
	check(list.get_child_count() == app.model.messages.size(), "Réouvrir restaure le message dans la boîte")
	app.find_child("InboxOpenMessageAction", true, false).pressed.emit()
	await settle()
	check(app.route == "Effectif", "L'alerte contrat ouvre l'effectif réel")

func resize_shell() -> void:
	app._navigate("Bureau")
	await settle()
	var fixture: Control = app.find_child("OfficeFixture",true,false)
	var journal: Control = app.find_child("OfficeJournal",true,false)
	var timeline: Control = app.find_child("OfficeTimeline",true,false)
	var ground: Label = app.find_child("OfficeTimelineGround0",true,false)
	check(app.find_child("OfficeRecentResults",true,false)==null,"Les résultats attendent le premier match joué")
	var action: Button = app.find_child("ImmersiveContinue",true,false)
	var history: Array = app.navigation_controller.history.duplicate(true)
	for size in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720),Vector2i(1440,900),Vector2i(2560,1440)]:
		root.size = size
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
		await create_timer(.16).timeout
		await settle()
		var screen := Rect2(Vector2.ZERO,Vector2(root.size))
		check(root.size==size and app.size==Vector2(size),"Fenêtre et canvas natif redimensionnés à "+str(size))
		check(app.find_child("OfficeFixture",true,false)==fixture and app.navigation_controller.history==history,"Le resize conserve contrôles et navigation à "+str(size))
		for control: Control in [fixture,journal,timeline,action]:
			var box := control.get_global_transform()*Rect2(Vector2.ZERO,control.size)
			check(screen.grow(1).encloses(box),"%s entièrement visible à %s" % [control.name,str(size)])
		if size in [Vector2i(1280,720),Vector2i(1440,900)]:
			check(ground != null and ground.is_visible_in_tree() == (size.y == 900),"Le terrain apparaît lorsque le fil de saison dispose d'assez de hauteur à "+str(size))
			await capture("06-bureau-redimensionne-%dx%d" % [size.x,size.y])
	root.size = Vector2i(1440,900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await settle()
	app._navigate("Calendrier")
	await settle()
	var monthly: Control = app.find_child("CalendarMonthGrid",true,false)
	check(monthly!=null,"La vue mensuelle s’ouvre par défaut")
	var day: Control = app.find_child("MonthDay_"+str(app.model.calendarPlanning.today),true,false)
	check(day!=null and day.get_meta("countdown",false),"Le jour courant précède le prochain match")
	await capture("49-calendrier-mensuel-1440x900")
	var show_table: Button = app.find_child("CalendarShowTable",true,false)
	check(show_table!=null,"Le tableau historique reste accessible depuis la vue mensuelle")
	if show_table!=null:
		await click(show_table)
		await settle()
	var locations: Array[String] = []
	for marker: TextureRect in app.find_children("CalendarLocation","TextureRect",true,false):
		locations.append(marker.accessibility_name)
	check(locations.any(func(label): return "domicile" in label),"Le Calendrier identifie les matchs à domicile")
	check(locations.any(func(label): return "extérieur" in label),"Le Calendrier identifie les déplacements")
	await capture("14-calendrier-reperes-1440x900")
	var show_month: Button = app.find_child("CalendarShowMonth",true,false)
	check(show_month!=null,"La vue mensuelle reste accessible depuis le tableau")
	if show_month!=null:
		await click(show_month)
		await settle()
	root.size = Vector2i(2560,1440)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await settle()

func recent_office_results() -> void:
	var original: Dictionary = app.model
	app.model = original.duplicate(true)
	var fixtures: Array = app.model.calendar
	if fixtures.size() < 9:
		check(false,"La recette des résultats nécessite neuf rencontres")
		app.model = original
		return
	for index in 6:
		fixtures[index].played = true
		fixtures[index].score = [16 + index, 20]
	fixtures[8].neutral = true
	app.model.next = fixtures[6]
	app.model.meta.week = fixtures[6].week
	app._navigate("Bureau")
	await settle()
	root.size = Vector2i(1440,900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await settle()
	var results: Control = app.find_child("OfficeRecentResults",true,false)
	var timeline: Control = app.find_child("OfficeTimeline",true,false)
	var upcoming_crests := timeline.find_children("OfficeOpponentCrest*","Control",true,false)
	var next_opponent: Dictionary = fixtures[6].away if fixtures[6].home.id == app.model.club.id else fixtures[6].home
	check(upcoming_crests.size()==7 and upcoming_crests[0].get_meta("opponent_id")==next_opponent.id,"Les sept prochaines rencontres affichent les blasons adverses")
	var markers := app.find_children("OfficeVenueIcon*","TextureRect",true,false)
	var icons := markers.map(func(marker): return marker.texture)
	check(icons.size() >= 3 and icons[0] != null and icons[1] != null and icons[2] != null
		and icons[0] != icons[1] and icons[0] != icons[2] and icons[1] != icons[2],"Maison, bus et drapeau affichés dans le fil")
	if results != null:
		var scores := results.find_children("OfficeRecentScore","Label",true,false)
		check(scores.size()==5 and scores[0].text=="20 – 21","Cinq résultats du plus récent au plus ancien, score du club à gauche")
		var crests := results.find_children("OfficeOpponentCrest","Control",true,false)
		var last_opponent: Dictionary = fixtures[5].away if fixtures[5].home.id == app.model.club.id else fixtures[5].home
		check(crests.size()==5 and crests[0].get_meta("opponent_id")==last_opponent.id,"Les cinq derniers résultats affichent les blasons adverses")
		var viewport: Control = app.body_scroll
		check(viewport.get_global_rect().grow(1).encloses(results.get_global_rect()),"Cinq résultats entièrement visibles à 1440 × 900")
	check(results!=null,"La bande des résultats apparaît après des matchs joués")
	await capture("48-bureau-cinq-resultats-1440x900")
	app.model = original
	root.size = Vector2i(2560,1440)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app._navigate("Calendrier")
	await settle()

const FAMILIES = [
		["Recrutement","ImmersiveMarketRows","10-recrutement"],
		["Club","ClubStadium","11-club"],
		["Finances","FinanceLedgerPlot","12-finances"],
		["Classements","StandingsRows","13-competitions"],
		["Calendrier","CarnetCalendar","14-calendrier"],
		["Formation","AcademyImmersiveRows","15-formation"],
		["Staff","CarnetStaff","16-staff"],
		["Travail du club","CarnetSupport","17-travail-du-club"],
		["Stratégie","CarnetStrategie","18-strategie"],
		["Préparation","ImmersivePreparation","20-preparation"],
		["Plan de jeu","ImmersivePlaybook","21-plan-de-jeu"],
		["Centre","ImmersiveCentre","22-centre"],
		["Presse","PressDeskTitle","23-presse"],
		["Rivalités","RivalryWorkspace","24-rivalites"],
		["Vestiaire","ImmersiveLockerRoom","25-vestiaire"],
		["Carrière","ImmersiveManagerCareer","26-carriere"]
]

func families() -> void:
	var training: Button = app.find_child("Nav_Entraînement",true,false)
	await click(training)
	await settle()
	var week: Control = app.find_child("ImmersiveTraining",true,false)
	check(week!=null and app.management_ui.preparation.tab==2,"Rail Entraînement raccordé à la vraie préparation")
	if week!=null:
		await capture("09-entrainement-2560x1440")
		await click(week.find_child("TrainingBackToPreparation",true,false))
		await settle()
		check(app.route=="Préparation" and app.management_ui.preparation.tab==0,"Retour au dossier de préparation")
	for item: Array in FAMILIES:
		app._navigate(item[0])
		await settle()
		var view: Control = app.find_child(item[1],true,false)
		check(view!=null and view.is_visible_in_tree(),"Gabarit raccordé au vrai parcours · "+str(item[0]))
		if item[0]=="Formation":
			var selected: String = app.management_ui.immersive_academy.get("player","")
			var roster: Array = app.model.decisions.development.academy
			var matches := roster.filter(func(p: Dictionary): return p.id==selected)
			var general := app.find_child("AcademyGeneralRating",true,false) as Label
			check(matches.size()==1 and general!=null and general.text=="Niveau général · %d aujourd’hui" % int(matches[0].rating),"La progression Formation distingue le vrai niveau général de la note au poste")
		if item[0]=="Recrutement":
			check(caption_fits(app.find_child("MarketSort_Niveau",true,false)),"Le libellé de tri par niveau reste entier en 1440p")
		if view!=null: await capture(item[2]+"-2560x1440")
		if item[0]=="Presse" and view!=null: await press_panes()
	app._navigate("Finances")
	await settle()
	var wages: Button = app.find_child("FinanceTab_wages",true,false)
	check(wages!=null,"Onglet des salaires actif en Finances")
	if wages!=null:
		await click(wages)
		await settle()
		check(app.find_child("FinanceLedgerPlot",true,false)==null,"Les salaires ont leur propre composition")
		await capture("19-finances-salaires-2560x1440")
	app._navigate("Classements")
	await settle()
	var calendar: Button = app.find_child("Section_Calendrier",true,false)
	if calendar!=null: await click(calendar)
	await settle()
	check(app.route=="Calendrier","Compétitions ouvre le calendrier avec son onglet")
	app._navigate("Composition")
	await settle()
	var set_piece: Button = app.find_child("TacticsTab2",true,false)
	if set_piece!=null: await click(set_piece)
	await settle()
	check(app.route=="Plan de jeu" and app.find_child("PlaybookTabs",true,false).current_tab==1,"Phases arrêtées ouvre la bonne sous-vue tactique")
	var lineout: TextureRect = app.find_child("Art_lineout_analysis",true,false)
	check(lineout!=null and lineout.texture!=null and lineout.is_visible_in_tree(),"La photo de touche apparaît dans les phases arrêtées")
	await capture("38-plan-de-jeu-phases-2560x1440")

func press_panes() -> void:
	var tabs := app.find_child("PressTabs",true,false) as TabContainer
	check(tabs!=null and tabs.get_tab_count()==4 and tabs.get_tab_control(1).get_child_count()==0,"Presse ouvre le journal sans construire les onglets masqués")
	if tabs==null: return
	await click(app.find_child("PressCanvasTab1",true,false))
	await settle()
	var conference := tabs.get_tab_control(1).get_child(0) as Control
	check(conference!=null and tabs.current_tab==1 and conference.is_visible_in_tree(),"Le clic monte le contenu réel de la conférence")
	await capture("50-presse-conference-2560x1440")
	await click(app.find_child("PressCanvasTab3",true,false))
	await settle()
	var people := tabs.find_child("PressPersonPicker",true,false) as OptionButton
	check(tabs.current_tab==3 and people!=null and people.item_count>0,"Le carnet de portraits charge le vrai annuaire de Presse")
	await capture("51-presse-portraits-2560x1440")
	await click(app.find_child("PressCanvasTab1",true,false))
	await settle()
	check(tabs.get_tab_control(1).get_child(0)==conference,"Revenir à la conférence réutilise les mêmes contrôles")
	await click(app.find_child("PressCanvasTab0",true,false))
	await settle()

func desktop_1080() -> void:
	root.size=Vector2i(1920,1080)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	for item: Array in FAMILIES:
		app._navigate(item[0])
		await settle()
		var view: Control = app.find_child("ImmersiveFinance" if item[0]=="Finances" else item[1],true,false)
		check(view!=null and view.is_visible_in_tree(),"Vue immersive ouverte directement en 1080p · "+str(item[0]))
		var work: ScrollContainer = app.body_scroll
		var bar := work.get_v_scroll_bar()
		check(app.body.size.x<=work.size.x+1 and bar.max_value<=bar.page+1,"Gabarit contenu dans la surface 1080p · "+str(item[0]))
		if item[0]=="Recrutement":
			for id in ["MarketSort_Niveau","MarketSort_Âge"]:
				check(caption_fits(app.find_child(id,true,false)),"Libellé de tri entier en 1080p · "+id)
		if item[0] in ["Club","Recrutement"]: await capture(item[2]+"-1920x1080")
	app.Immersive.open_training(app)
	await settle()
	check(app.find_child("ImmersiveTraining",true,false)!=null,"Entraînement ouvre son gabarit à 1080p")
	await capture("09-entrainement-1920x1080")
	app._navigate("Match")
	await settle()
	var pitch: Control = app.find_child("ImmersiveMatchPitch",true,false)
	var tunnel: TextureRect = app.find_child("Art_match_tunnel",true,false)
	check(pitch!=null and tunnel!=null and tunnel.texture!=null and tunnel.is_visible_in_tree(),"Le jour de match conserve son visuel et la scène à 1080p")
	if pitch!=null:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(pitch.get_global_transform()*Rect2(Vector2.ZERO,pitch.size)),"Terrain directement accessible en 1080p")
	await capture("27-avant-match-1920x1080")
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	for route: String in ["Finances","Calendrier","Formation","Plan de jeu","Centre","Préparation","Recrutement",
		"Classements","Club","Staff","Travail du club","Stratégie","Presse","Rivalités","Vestiaire","Carrière"]:
		app._navigate(route)
		await settle()
		if route=="Calendrier":
			check(app.find_child("CalendarMonthGrid",true,false)!=null,"Grille mensuelle visible en 720p")
		elif route=="Rivalités":
			var hero := app.find_child("RivalryHero",true,false) as Control
			var photo := hero.find_child("Art_stadium",true,false) as TextureRect if hero!=null else null
			var tab := app.find_child("RivalryTab0",true,false) as Button
			check(photo!=null and photo.texture!=null and photo.is_visible_in_tree(),"Illustration originale visible dans les Rivalités paginées à 720p")
			check(tab!=null and tab.get_meta("immersive_style_applied",false) and tab.focus_mode==Control.FOCUS_ALL and not tab.disabled,"Le tableau paginé garde ses commandes immersives et accessibles à 720p")
			await capture("61-rivalites-1280x720")
		else:
			var art: Control = app.find_child("CompactRouteArt",true,false)
			var photo: TextureRect = art.get_child(0) as TextureRect if art!=null else null
			check(photo!=null and photo.texture!=null and art.is_visible_in_tree(),"Illustration visible dans le repli à 720p · "+route)
			check(app.body.get_child(0).get_meta("immersive_style_applied",false),"Les vraies actions de la page utilisent la DA compacte · "+route)
		check(app.body.size.x<=app.body_scroll.size.x+1,"Le repli ne rogne pas la largeur utile · "+route)
		if route=="Finances": await capture("12-finances-1280x720")
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()

func navigation_flow() -> void:
	app._navigate("Bureau")
	await settle()
	await click(app.find_child("OfficeTrainingAction",true,false))
	await settle()
	check(app.find_child("ImmersiveTraining",true,false)!=null,"Le dossier d’entraînement du Bureau ouvre sa vraie page")
	var command_id: int = app.bridge._next_id
	await click(app.find_child("ImmersiveContinue",true,false))
	await settle()
	check(app.route=="Match" and app._live().is_empty() and app.management_ui.preparation.tab==2 and app.bridge._next_id==command_id,"Continuer ouvre l’avant-match sans lancer la rencontre et mémorise l’entraînement")
	var back: Button = app.find_child("NavigationBack",true,false)
	var forward: Button = app.find_child("NavigationForward",true,false)
	check(back!=null and not back.disabled and forward!=null and forward.disabled,"L’historique de lecture est accessible à la souris")
	if back!=null: await click(back); await settle()
	else: await key(KEY_LEFT,false,true)
	check(app.find_child("ImmersiveTraining",true,false)!=null,"Retour restaure l’entraînement plutôt que le dossier adverse")
	await key(KEY_RIGHT,false,true)
	check(app.route=="Match" and app._live().is_empty(),"Alt droite rétablit l’avant-match")
	var original_size := root.size
	root.size = Vector2i(1280, 720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	app._navigate("Bureau")
	await settle()
	await click(app.find_child("ImmersiveContinue",true,false))
	await settle()
	await click(app.find_child("PreparationTabEntrainement",true,false))
	await settle()
	check(app.route=="Préparation" and app.management_ui.preparation.tab==2,"Entraînement est sélectionné dans Préparation compacte")
	command_id = app.bridge._next_id
	await click(app.find_child("ImmersiveContinue",true,false))
	await settle()
	check(app.route=="Match" and app._live().is_empty() and app.bridge._next_id==command_id,"Continuer ouvre l’avant-match compact sans commande")
	await key(KEY_LEFT,false,true)
	check(app.route=="Préparation" and app.management_ui.preparation.tab==2,"Alt gauche retrouve l’onglet Entraînement sélectionné sur place")
	await click(app.find_child("PreparationMatch",true,false))
	await settle()
	await key(KEY_LEFT,false,true)
	check(app.route=="Préparation" and app.management_ui.preparation.tab==2 and app.bridge._next_id==command_id,"Le lien local conserve aussi l’onglet et la navigation reste sans commande")
	root.size = original_size
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	app._navigate("Effectif")
	await settle()
	var player_id: String = app.selected_player
	await click(app.find_child("OpenPlayerFull",true,false))
	await settle()
	await click(app.find_child("Nav_Bureau",true,false))
	await settle()
	await key(KEY_LEFT,false,true)
	check(app.selected_player==player_id and app.find_child("ImmersivePlayerFull",true,false)!=null,"Retour historique restaure la fiche du même joueur")
	await key(KEY_LEFT,false,true)
	check(app.selected_player==player_id and app.find_child("ImmersiveRosterTable",true,false)!=null,"La fiche et le tableau de l’effectif sont deux étapes distinctes")
	app._navigate("Réception")
	await settle()
	var training_task: Button
	for task: Button in app.find_children("InboxRecommendation*","Button",true,false):
		if task.text == "Organiser la charge de la semaine": training_task = task; break
	check(training_task!=null,"La Réception propose la charge collective encore à décider")
	if training_task!=null:
		await click(training_task)
		await settle()
		check(app.find_child("ImmersiveTraining",true,false)!=null,"La recommandation de charge ouvre l’entraînement")

func dialogs() -> void:
	app._navigate("Bureau")
	await settle()
	var open_notebook: Button = app.find_child("OpenCoachNotebook",true,false)
	check(open_notebook!=null,"Le Bureau donne accès au carnet personnel")
	if open_notebook!=null:
		await click(open_notebook)
		await settle()
		var notebook: AcceptDialog = app.get_node_or_null("CoachNotebook")
		check(notebook!=null and notebook.visible and notebook.find_child("CoachNoteText",true,false)!=null,
			"Le carnet du Bureau ouvre le vrai éditeur de notes")
		if notebook!=null:
			await capture("39-carnet-coach-2560x1440")
			var editor := notebook.find_child("CoachNoteText",true,false) as TextEdit
			editor.grab_focus()
			editor.insert_text_at_caret("Repère de recette")
			root.size=Vector2i(1280,720)
			if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
			await create_timer(.17).timeout
			await settle()
			check(Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(notebook.position,notebook.size))
				and absi(notebook.position.x*2+notebook.size.x-root.size.x)<=2
				and editor.text=="Repère de recette" and editor.has_focus(),"Carnet centré après resize sans perdre la saisie ni le focus")
			await capture("40-carnet-coach-1280x720")
			app._clear_dialogs()
			root.size=Vector2i(2560,1440)
			if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
			await settle()
	await key(KEY_K,true)
	var palette: AcceptDialog = app.get_node_or_null("NavigationPalette")
	check(palette!=null and palette.visible,"Ctrl K ouvre la palette native")
	if palette!=null and palette.visible:
		await capture("31-recherche-2560x1440")
		var search: LineEdit = palette.find_child("NavigationSearch",true,false)
		search.text="entrainement"
		search.text_changed.emit(search.text)
		await key(KEY_ENTER)
		check(app.route=="Préparation" and app.find_child("ImmersiveTraining",true,false)!=null,"Recherche et Entrée ouvrent le véritable menu Entraînement")
	app.settings()
	await settle()
	var preferences: AcceptDialog = app.get_node_or_null("PreferencesDialog")
	check(preferences!=null and preferences.visible and preferences.find_child("PreferencesMotion",true,false)!=null,"Paramètres natifs et mode calme disponibles")
	if preferences!=null and preferences.visible:
		check(Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(preferences.position,preferences.size)),"La fenêtre de paramètres tient dans l’écran 1440p")
		await capture("32-parametres-2560x1440")
		var tabs: TabContainer = preferences.find_child("PreferencesTabs",true,false)
		tabs.current_tab=1
		await settle()
		check(tabs.find_child("PreferencesInterfaceVolume",true,false).is_visible_in_tree() and tabs.find_child("PreferencesStadiumVolume",true,false).is_visible_in_tree(),"L’onglet Son conserve les deux volumes indépendants")
		root.size=Vector2i(1440,900)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await create_timer(.17).timeout
		await settle()
		check(Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(preferences.position,preferences.size)) and tabs.current_tab==1,"Redimensionner conserve l’onglet et toute la fenêtre des paramètres")
		await capture("34-parametres-son-1440x900")
		preferences.canceled.emit()
		root.size=Vector2i(2560,1440)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await settle()
	app.pause_menu()
	await settle()
	var pause: AcceptDialog = app.get_node_or_null("ImmersivePauseMenu")
	check(pause!=null and pause.visible,"Menu carrière et sauvegardes ouvrable")
	if pause!=null and pause.visible:
		check(Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(pause.position,pause.size)),"Le menu carrière tient dans l’écran")
		await capture("33-menu-carriere-2560x1440")
		app.file_dialog.current_dir=OS.get_environment("CD_IMMERSIVE_ARTIFACTS")
		pause.custom_action.emit("export")
		await settle()
		check(app.file_dialog.visible and not app.import_mode,"Exporter ouvre le vrai choix du fichier")
		var filename: String = app.file_dialog.current_file
		await capture("41-export-carriere-2560x1440")
		root.size=Vector2i(1280,720)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await create_timer(.17).timeout
		await settle()
		var list_height := 0.0
		for list: ItemList in app.file_dialog.get_vbox().find_children("*","ItemList",true,false):
			if list.is_visible_in_tree(): list_height=maxf(list_height,list.size.y)
		check(list_height>=160 and app.file_dialog.current_file==filename,"Le sélecteur garde sa liste et le nom de fichier en 720p")
		await capture("42-export-carriere-1280x720")
		app.file_dialog.hide()
		root.size=Vector2i(2560,1440)
		if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
		await settle()
	await key(KEY_F1)
	check(app.coach.expanded,"F1 ouvre l’aide du coach")
	await capture("35-coach-gabi-2560x1440",false)
	app.coach.close()
	await key(KEY_S,true)
	await worker()
	check(app.last_command=="save" and app.bridge.last_response_ok,"Ctrl S sauvegarde via le moteur")

func footer_feedback() -> void:
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await create_timer(.26).timeout
	await settle()
	var button: Button = app.find_child("DecisionFeedbackButton",true,false)
	var dock: Control = app.find_child("CoachCompactDock",true,false)
	check(dock!=null and dock.get_global_rect().size.x>=100,"Place physique pour Gabi en 720p")
	check(button!=null and not button.disabled and not dock.get_global_rect().intersects(button.get_global_rect()),"Le reçu et le coach ont des cibles distinctes en 720p")
	if button!=null:
		await click(button)
		await settle()
		var feedback: AcceptDialog = app.get_node_or_null("DecisionFeedbackDialog")
		check(feedback!=null and feedback.visible,"Le premier clic réel ouvre le reçu, même avec Gabi")
		if feedback!=null: feedback.queue_free()
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()

func match_flow() -> void:
	app._navigate("Match")
	await settle()
	var frame: Control = app.find_child("ImmersiveMatchPitch",true,false)
	check(frame!=null and app.find_child("Art_match_tunnel",true,false)!=null,"Avant-match illustré dans le vrai écran de rencontre")
	if frame==null: return
	var scene: Node3D = app.match_view
	var match_ui: Control = app.match_screen
	await capture("27-avant-match-2560x1440")
	var kickoff: Button = app.pause_button
	var kickoff_rect := kickoff.get_global_rect()
	var event_seen := {"pressed":false}
	kickoff.pressed.connect(func(): event_seen.pressed=true,CONNECT_ONE_SHOT)
	await click(kickoff)
	await worker()
	check(app.model.live is Dictionary and app.match_view==scene and not match_ui.opening.visible,
		"Coup d’envoi réel conserve la scène et retire l’ouverture · clic=%s, commande=%s, erreur=%s, contrôle=%s"
		% [str(event_seen.pressed), app.last_command, app.last_error, str(kickoff_rect)])
	if not app.model.live is Dictionary: return
	await command("tick",{"steps":12})
	await command("pause",{"paused":true})
	check(match_ui.broadcast.visible and app.model.live.paused,"Bandeau du direct reflète la vraie pause")
	await capture("28-match-direct-2560x1440")
	var journal_tab: Button
	for button: Button in match_ui._tab_controls:
		if button.get_meta("match_tab")=="Journal": journal_tab=button; break
	if journal_tab!=null: await click(journal_tab)
	await settle()
	check(match_ui.journal.visible,"Le journal du match reste accessible au clic")
	var score_before: Array = app.model.live.score.duplicate()
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await create_timer(.16).timeout
	await settle()
	check(app.match_screen==match_ui and app.match_view==scene and match_ui.journal.visible and app.model.live.score==score_before,"Resize du direct préserve scène, onglet et score")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(frame.get_global_transform()*Rect2(Vector2.ZERO,frame.size)),"Terrain visible en 720p après resize")
	await capture("29-journal-direct-1280x720")
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	await command("delegate")
	check(app.model.live.finished and match_ui.result_strip.visible and not app.match_finish.disabled,"La fin du vrai match expose résultat et validation")
	await capture("30-resultat-2560x1440")
	await click(app.match_finish)
	await worker()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(app.model.live==null and not app.model.history.is_empty(),"La validation du résultat alimente l’historique de carrière")

func run() -> void:
	check(ResourceLoader.exists("res://ui/immersive08/components.gd"), "Composants natifs de la DA approuvée disponibles")
	if not failures.is_empty():
		print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
		quit(1)
		return
	var kit: GDScript = load("res://ui/immersive08/components.gd")
	check(kit.font(700).resource_path.ends_with("BarlowCondensed-Bold.ttf"), "Graisse700 exacte des titres approuvés")
	check(kit.font(500).resource_path.ends_with("BarlowCondensed-Medium.ttf"), "Graisse500 exacte des libellés approuvés")
	var card: Control = kit.card("TITRE RÉEL", Vector2(600, 400))
	root.add_child(card)
	await process_frame
	check(card is PanelContainer, "Tuile native indépendante")
	check(card.find_child("CardTitle", true, false).text == "TITRE RÉEL", "Titre éditable, pas texte dans une image")
	var button: Button = kit.button("Décider", func(): card.set_meta("action", true), true)
	card.get_meta("content").add_child(button)
	button.pressed.emit()
	check(card.get_meta("action", false), "Bouton fonctionnel")
	check(button.focus_mode == Control.FOCUS_ALL, "Action accessible au clavier")
	var photo: Control = kit.photo("office-hero", Vector2(400, 280))
	card.get_meta("content").add_child(photo)
	check(photo is TextureRect and photo.texture != null, "Illustration décodée par Godot")
	check(photo.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Illustration ne bloque pas les actions")
	for id in ["brand", "tactics-briefing", "training-session", "stadium", "academy-training", "trophy", "scouting", "hospitality", "forest", "player-hero", "recruit-profile", "mail-staff"]:
		var texture: Texture2D = kit.texture(id)
		check(texture != null and texture.get_width() > 0, "Texture native : " + id)
	card.queue_free()
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	var scope := OS.get_environment("CD_IMMERSIVE_SCOPE")
	if scope in ["pacific", "japan", "japan-d2", "nationale", "nationale-compact", "champ", "champ-compact"]:
		app.set_meta("calendar_table",true)
		match scope:
			"pacific": await pacific()
			"japan", "japan-d2": await japan(scope=="japan-d2")
			"champ", "champ-compact": await champ(scope=="champ-compact")
			_: await nationale(scope=="nationale-compact")
		app.queue_free()
		await settle()
		print("immersive08 ", scope, " : ", checks, " contrôles, ", failures.size(), " échecs")
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": await entry()
	await command("new_career", {"club":0, "mode":"fiction"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Bureau")
	await settle()
	check(app.find_child("ImmersiveShell", true, false) != null, "Raccordement dans le vrai rendu du jeu")
	var output := FileAccess.open(OS.get_environment("CD_IMMERSIVE_ARTIFACTS").path_join("model.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(app.model))
	output.close()
	check(ResourceLoader.exists("res://ui/immersive08/shell.gd"), "Shell immersif natif disponible")
	if ResourceLoader.exists("res://ui/immersive08/shell.gd"):
		var shell: GDScript = load("res://ui/immersive08/shell.gd")
		await command("export")
		var before: String = app.model.meta.exportText
		var disk := str(app.model.meta.dataDir).path_join("donnees.json")
		var bytes := FileAccess.get_file_as_bytes(disk)
		check(shell.render(app), "Rendu natif du Bureau pris en charge")
		await settle()
		for id in ["ImmersiveShell", "ImmersiveSidebar", "ImmersiveTopbar", "OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			check(app.find_child(id, true, false) != null, "Élément réel : " + id)
		check(app.size.x >= 2500, "2560p exploités sans agrandir un canvas 1600p")
		for id in ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]:
			var tile: Control = app.find_child(id, true, false)
			if tile == null: continue
			check(tile.get_global_rect().end.x <= app.size.x + 1, "Tuile dans la largeur : " + id)
			check(tile.size.x >= 300, "Largeur utile en 1440p : " + id)
			check(tile.get_global_rect().end.y <= app.body_scroll.get_global_rect().end.y + 1, "Tuile entièrement visible en 1440p : " + id)
		var city := app.find_child("OfficeCityPreview", true, false)
		var stadium := app.find_child("OfficeStadiumPreview", true, false)
		check(city != null and city.get_meta("photo_kind", "") == "generated" and stadium != null and stadium.get_meta("photo_kind", "") == "generated", "Le Bureau de base affiche les illustrations de ville et de stade")
		reference_rects({"OfficeFixture":Rect2(280,220,1360,418), "OfficeDecisions":Rect2(1656,220,872,418),
			"OfficeGroup":Rect2(280,654,422,448), "OfficeStandings":Rect2(718,654,684,448),
			"OfficeJournal":Rect2(1418,654,548,448), "OfficeRecruitment":Rect2(1982,654,546,448),
			"OfficeTimeline":Rect2(280,1118,2248,226)})
		await capture("01-bureau-2560x1440")
		app._navigate("Effectif")
		shell.render(app)
		await settle()
		var roster: Control = app.find_child("ImmersiveRosterTable", true, false)
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": check(roster != null, "Table Effectif dense de la référence 1440p")
		if roster != null:
			reference_rects({"ImmersiveRosterTable":Rect2(280,267,1704,1068), "PlayerDossier":Rect2(2000,207,528,1128),
				"RosterTab0":Rect2(280,207,199,42), "RosterSearch":Rect2(298,283,355,40), "RosterSearchGlyph":Rect2(311,293,21,21),
				"SelectedPlayerCard":Rect2(2000,207,528,432), "OpenPlayerFull":Rect2(2019,587,489,36)})
			var list: VBoxContainer = app.find_child("ImmersiveRosterRows", true, false)
			var row_buttons: Array = list.get_children().filter(func(node:Node):return node is Button)
			# La pagination à 24 lignes a été remplacée par une table complète à défilement interne
			# (voir godot-squad-column-sort : « au-delà de l'ancienne limite ») : chaque joueur du groupe a sa ligne.
			check(row_buttons.size() == app.model.squad.size(), "Une ligne par joueur du groupe dans la table à défilement interne")
			var all_ids: Array = row_buttons.map(func(node:Node):return str(node.get_meta("player_id")))
			check(app.find_child("RosterPaginationNext",true,false) == null, "Plus de pagination : le groupe entier défile dans la table")
			check(all_ids.size()==app.model.squad.size(), "Tout le groupe consultable sans changer de page")
			check(all_ids.all(func(id):return all_ids.count(id)==1), "Aucun joueur omis ou dupliqué dans la table")
			var roster_scroll := app.find_child("SquadScroll",true,false) as ScrollContainer
			check(roster_scroll != null, "Conteneur de défilement interne de la table")
			var saved_scroll: int = 0
			if roster_scroll != null:
				roster_scroll.scroll_vertical = 120
				await settle()
				saved_scroll = roster_scroll.scroll_vertical
			app._navigate("Bureau");app._navigate("Effectif");await settle()
			roster_scroll = app.find_child("SquadScroll",true,false) as ScrollContainer
			check(roster_scroll != null and roster_scroll.scroll_vertical == saved_scroll, "Retour respecte le défilement volontaire sans révéler à nouveau le dossier")
			list=app.find_child("ImmersiveRosterRows",true,false)
			for id in ["RosterColumnSalary", "RosterColumnFatigue", "RosterColumnPotential", "PlayerDossier", "OpenPlayerFull", "OfferRenewal", "OpenComparison"]:
				check(app.find_child(id, true, false) != null, "Fonction Effectif : " + id)
			var selected_before: String = app.selected_player
			var target: Dictionary = app.model.squad[1]
			var search: LineEdit = app.find_child("RosterSearch", true, false)
			search.text = str(target.name)
			search.text_changed.emit(search.text)
			await settle()
			check(list.get_children().filter(func(node:Node):return node is Button).size() == 1, "Recherche réelle réduit la liste")
			check(app.selected_player == selected_before, "Filtrer conserve le dossier lu")
			var person: Button = list.get_children().filter(func(node:Node):return node is Button)[0]
			person.pressed.emit()
			await settle()
			check(app.selected_player == str(target.id), "Sélection exacte par ID")
			check(str(app.find_child("PlayerDossier", true, false).get_meta("player_id", "")) == str(target.id), "Dossier actualisé sans changer la carrière")
			search.text = ""
			search.text_changed.emit("")
			await settle()
			check(list.get_children().filter(func(node:Node):return node is Button).size() == app.model.squad.size(), "Effacer la recherche retrouve le groupe entier")
			await capture("02-effectif-2560x1440")
			app.find_child("OpenPlayerFull",true,false).pressed.emit()
			await settle()
			var full:Control=app.find_child("ImmersivePlayerFull",true,false)
			check(full!=null,"La fiche complète est une vraie page, pas un bouton inerte")
			if full!=null:
				var shirt: Label = full.find_child("FullPlayerNumber",true,false)
				var expected_number := "—" if target.get("shirtNumber")==null else str(int(target.shirtNumber))
				check(shirt!=null and shirt.text==expected_number and shirt.get_theme_font_size("font_size")==82,"Le cartouche reprend le vrai numéro à la taille du visuel")
				var role_pitch: Control = full.find_child("PlayerRolePitch",true,false)
				check(role_pitch!=null and role_pitch.is_visible_in_tree() and role_pitch.size==Vector2(432,350),"Le terrain du poste est redessiné en perspective à la taille de la fiche")
				var global_rating := full.find_child("PlayerGlobalRating",true,false) as Label
				check(global_rating != null and global_rating.text.to_int() == int(target.rating), "Note globale exacte dans la fiche complète")
				check(app.find_child("ProfilePlayerName",true,false).text.to_lower()==str(target.name).to_lower(),"Identité exacte dans la fiche complète")
				check(app.find_child("OpenPlayerCoachNote",true,false)!=null,"Carnet personnel conservé sur la fiche")
				await capture("04-fiche-joueur-2560x1440")
				app.find_child("FullPlayerTab1",true,false).pressed.emit()
				await settle()
				var attributes: Dictionary = target.get("attributesV2", {})
				var detailed := app.find_child("PlayerDetailedAttributes",true,false) as Panel
				check(detailed != null and attributes.size() == 36 and detailed.find_children("PlayerDetailedAttribute_*", "Label", true, false).size() == 36, "Les 36 attributs du joueur sont affichés")
				check(app.find_children("PlayerAttribute_*", "Label", true, false).is_empty(), "Aucune grille des 11 qualités internes")
				for key: String in attributes:
					var value := app.find_child("PlayerDetailedAttribute_" + key,true,false) as Label
					check(value != null and value.text.replace(",", ".").to_float() == float(attributes[key]), "Attribut affiché à sa valeur exacte : " + key)
				app.find_child("FullPlayerTab5",true,false).pressed.emit()
				await settle()
				for id in ["ProfileContextCompetition","ProfileContextDevelopment","ProfileContextForm","ProfileContextStaff","ProfileMean_rating"]:
					check(app.find_child(id,true,false)!=null,"Contexte métier de la fiche complète : "+id)
				await capture("36-fiche-joueur-reperes-2560x1440")
				app.find_child("PlayerBackToSquad",true,false).pressed.emit()
				await settle()
				check(app.find_child("ImmersiveRosterTable",true,false)!=null,"Retour au tableau sans perdre le joueur")
			else:app.set_meta("immersive08_full_player",false)
		app._navigate("Composition")
		await settle()
		var tactics: Control = app.find_child("ImmersiveTactics",true,false)
		check(tactics != null,"Tactique native du gabarit approuvé")
		if tactics != null:
			reference_rects({"TacticsPitch":Rect2(280,264,1070,906), "TacticsIdentity":Rect2(1980,264,548,906),
				"TacticsBench":Rect2(1366,264,598,529), "TacticsOutside":Rect2(1366,809,598,361),
				"TacticsMatchup0":Rect2(280,1186,546,158), "TacticsMatchup1":Rect2(842,1186,546,158),
				"TacticsMatchup2":Rect2(1404,1186,546,158), "TacticsVigilance":Rect2(1966,1186,562,158),
				"TacticsSave":Rect2(1983,121,248,48), "TacticsValidate":Rect2(2247,121,281,48)})
			for slot in 23:
				var jersey: Button = app.find_child("LineupSlot%02d" % (slot+1),true,false)
				check(jersey != null,"Poste réel disponible : "+str(slot+1))
			check(app.find_child("Art_tactics_briefing",true,false)!=null,"Image approuvée du briefing intégrée")
			check(app.find_child("TacticsIdentity",true,false)!=null,"Consignes et indicateurs du XV sélectionné")
			await capture("03-tactique-2560x1440")
		for pair in [["OfficePreparationAction", "Préparation"], ["OfficeSquadAction", "Effectif"], ["OfficeStandingsAction", "Classements"], ["OfficeCalendarAction", "Calendrier"]]:
			app._navigate("Bureau")
			shell.render(app)
			await settle()
			var action: Button = app.find_child(pair[0], true, false)
			check(action != null, "Action réelle : " + pair[0])
			if action != null:
				action.pressed.emit()
				await settle()
				check(app.route == pair[1], "Navigation : " + pair[0])
		await command("export")
		check(before == app.model.meta.exportText, "Rendu et navigation préservent état et RNG")
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office":
			await reception()
		await resize_shell()
		await recent_office_results()
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office":
			await families()
			await desktop_1080()
			await navigation_flow()
		check(bytes == FileAccess.get_file_as_bytes(disk), "Rendu et navigation ne modifient aucun octet du profil")
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": await dialogs()
		app._navigate("Composition")
		await settle()
		var fly_half: Button=app.find_child("LineupSlot10",true,false)
		await click(fly_half,Vector2(.97,.92))
		await settle()
		var candidates: AcceptDialog = app.find_child("LineupCandidates",true,false)
		check(app.selected_slot==9 and candidates!=null,"Le bas du maillot 10 ouvre son poste malgré l’enveloppe voisine")
		if candidates!=null:
			root.size=Vector2i(1280,720)
			await settle()
			var visible := Rect2(Vector2.ZERO,root.get_visible_rect().size)
			var title_height := candidates.get_theme_constant("title_height","Window")
			var decoration := Vector2(0,title_height)
			var frame := Rect2(Vector2(candidates.position)-decoration,Vector2(candidates.size)+decoration)
			check(visible.encloses(frame),"La barre de titre et les actions du sélecteur restent visibles en 720p")
			check(candidates.get_theme_font("title_font","Window").resource_path.ends_with("BarlowCondensed-Bold.ttf"),"Le sélecteur de poste conserve la fonte du gabarit dans sa barre de titre")
			for action: Button in [candidates.get_ok_button(), candidates.find_child("LineupRemove",true,false)]:
				var bounds := action.get_global_rect()
				bounds.position+=Vector2(candidates.position)
				check(visible.encloses(bounds),"Action de la sélection entièrement visible en 720p · "+str(action.name))
			await capture("37-candidats-redimensionne-1280x720")
			for pressed in [true,false]:
				var escape := InputEventKey.new()
				escape.keycode=KEY_ESCAPE
				escape.pressed=pressed
				root.push_input(escape,true)
			await settle()
			check(app.find_child("LineupCandidates",true,false)==null,"Échap libère complètement le sélecteur de poste")
			root.size=Vector2i(2560,1440)
			await settle()
		app._clear_dialogs()
		await settle()
		var original_defense:String=app.model.tactics.defense
		var attack:Button=app.find_child("TacticsAttack_occupation",true,false)
		await click(attack)
		await worker()
		check(app.bridge.last_response_ok and app.model.tactics.attack=="occupation","Le bouton d’attaque commande réellement le moteur")
		check(app.model.tactics.defense==original_defense,"Changer l’attaque conserve la défense")
		var paths := app.find_child("TacticsOccupationOverlay",true,false) as TextureRect
		check(paths!=null and paths.texture!=null and paths.mouse_filter==Control.MOUSE_FILTER_IGNORE and paths.focus_mode==Control.FOCUS_NONE,"Les trajectoires Occupation sont un calque natif transparent aux actions")
		reference_rects({"TacticsOccupationOverlay":Rect2(304,509,1022,626)})
		var briefing := app.find_child("Art_tactics_briefing",true,false) as TextureRect
		var crop: AtlasTexture = briefing.texture as AtlasTexture if briefing!=null else null
		check(crop!=null and absf(crop.region.get_center().y-crop.atlas.get_height()/2.0)<.1,"Le briefing reprend le cadrage vertical centré du SVG")
		var summary := app.find_child("TacticsSummaryText2",true,false) as Label
		var summary_action := app.find_child("TacticsSummary2",true,false) as Button
		var attacks: Array = app.model.tactics.attacks
		var description: String = attacks[attacks.find_custom(func(option: Dictionary): return option.id=="occupation")].description
		check(summary!=null and summary_action!=null and summary.text==description and summary.max_lines_visible==2 and summary_action.tooltip_text.contains(description),"L’aperçu et l’infobulle conservent le texte complet du plan")
		await capture("03b-tactique-occupation-2560x1440")
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": await footer_feedback()
		app.find_child("TacticsSummary1",true,false).pressed.emit()
		await settle()
		var pressure:Button=app.find_child("TacticsDefense_pression",true,false)
		check(pressure!=null,"Sous-menu défensif fonctionnel")
		if pressure!=null:pressure.pressed.emit();await worker()
		check(app.bridge.last_response_ok and app.model.tactics.defense=="pression" and app.model.tactics.attack=="occupation","Consigne défensive enregistrée sans écraser l’attaque")
		app.find_child("LineupSlot01",true,false).pressed.emit()
		await settle()
		check(app.find_child("LineupCandidates",true,false)!=null,"Le maillot ouvre les choix du poste")
		var eligibility:Array=app.model.selection.slots[0].eligibleIds
		var chosen:String=""
		for candidate:Button in app.find_child("LineupCandidatesList",true,false).get_children():
			var player_id:String=candidate.get_meta("player_id")
			check(candidate.disabled==(player_id not in eligibility),"Qualifications réelles conservées : "+player_id)
			if chosen.is_empty() and not candidate.disabled and player_id!=str(app.model.selection.slots[0].playerId):chosen=player_id
		check(not chosen.is_empty(),"Autre joueur qualifié disponible dans la fixture")
		if not chosen.is_empty():
			app.find_child("LineupPlayer"+chosen.replace(":","_"),true,false).pressed.emit()
			await worker()
			check(app.bridge.last_response_ok and str(app.model.selection.slots[0].playerId)==chosen,"Affectation réelle du joueur qualifié")
			app.find_child("TacticsChoosePlayer",true,false).pressed.emit()
			await settle()
			var recovery:Button=app.find_child("IndividualLoad_repos",true,false)
			check(recovery!=null,"Sous-menu de consignes individuelles illustré")
			if recovery!=null:recovery.pressed.emit();await worker()
			var person:Dictionary=app.model.squad.filter(func(player:Dictionary):return str(player.id)==chosen)[0]
			check(app.bridge.last_response_ok and person.loadPlan=="repos","Charge individuelle enregistrée dans la partie")
		await command("save")
		await command("export")
		var saved:String=app.model.meta.exportText
		app.queue_free()
		await settle()
		app=load("res://main.tscn").instantiate()
		root.add_child(app)
		await worker()
		await command("export")
		check(saved==app.model.meta.exportText,"Reprise native : choix tactiques, composition et charge exactement conservés")
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": await match_flow()
	app.queue_free()
	await settle()
	print("immersive08 : ", checks, " contrôles, ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)
