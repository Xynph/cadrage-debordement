extends SceneTree

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

func click(control: Control, fraction: Vector2 = Vector2(.5,.5)) -> void:
	var point := control.get_global_transform()*(control.size*fraction)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
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
	await capture("00-accueil-2560x1440")
	var new_career: Button = app.find_child("EntryNewCareer",true,false)
	if new_career==null: return
	await click(new_career)
	await settle()
	check(app.route=="Création" and app.find_child("CreationStart",true,false)!=null,"Nouvelle carrière ouvre le vrai catalogue et l’action de création")
	await capture("07-creation-2560x1440")
	app._navigate("Accueil")
	await settle()
	var packs: Button = app.find_child("EntryPacks",true,false)
	await click(packs)
	await settle()
	check(app.route=="Packs" and app.pack_manager.scope=="creation" and app.find_child("CarnetPacks",true,false)!=null,"L’atelier des identités conserve le gestionnaire de packs de création")
	await capture("08-packs-2560x1440")
	app.pack_manager.back()
	await settle()
	check(app.route=="Accueil","Retour depuis l’atelier conserve le parcours d’entrée")

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
	check(app.find_child("Art_mail_staff", true, false) != null, "Illustration de la Réception chargée en jeu")
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
			await capture("06-bureau-redimensionne-%dx%d" % [size.x,size.y])

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
		if view!=null: await capture(item[2]+"-2560x1440")
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
		if item[0] in ["Club","Recrutement"]: await capture(item[2]+"-1920x1080")
	app.Immersive.open_training(app)
	await settle()
	check(app.find_child("ImmersiveTraining",true,false)!=null,"Entraînement ouvre son gabarit à 1080p")
	await capture("09-entrainement-1920x1080")
	root.size=Vector2i(1280,720)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(root.size)
	await settle()
	for route: String in ["Finances","Calendrier","Formation","Plan de jeu","Centre"]:
		app._navigate(route)
		await settle()
		var art: Control = app.find_child("CompactRouteArt",true,false)
		var photo: TextureRect = art.get_child(0) as TextureRect if art!=null else null
		check(photo!=null and photo.texture!=null and art.is_visible_in_tree(),"Illustration visible dans le repli à 720p · "+route)
		check(app.body.get_child(0).get_meta("immersive_style_applied",false),"Les vraies actions de la page utilisent la DA compacte · "+route)
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
	await click(app.find_child("ImmersiveContinue",true,false))
	await settle()
	check(app.find_child("ImmersivePreparation",true,false)!=null and app.management_ui.preparation.tab==0,"Continuer ouvre le dossier de match après l’entraînement")
	var back: Button = app.find_child("NavigationBack",true,false)
	var forward: Button = app.find_child("NavigationForward",true,false)
	check(back!=null and not back.disabled and forward!=null and forward.disabled,"L’historique de lecture est accessible à la souris")
	if back!=null: await click(back); await settle()
	else: await key(KEY_LEFT,false,true)
	check(app.find_child("ImmersiveTraining",true,false)!=null,"Retour restaure l’entraînement plutôt que le dossier adverse")
	await key(KEY_RIGHT,false,true)
	check(app.find_child("ImmersivePreparation",true,false)!=null,"Alt droite rétablit le dossier de match")
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
		pause.custom_action.emit("export")
		await settle()
		check(app.file_dialog.visible and not app.import_mode,"Exporter ouvre le vrai choix du fichier")
		app.file_dialog.hide()
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
	var event_seen := {"pressed":false}
	kickoff.pressed.connect(func(): event_seen.pressed=true,CONNECT_ONE_SHOT)
	await click(kickoff)
	await worker()
	check(app.model.live is Dictionary and app.match_view==scene and not match_ui.opening.visible,
		"Coup d’envoi réel conserve la scène et retire l’ouverture · clic=%s, commande=%s, erreur=%s, contrôle=%s"
		% [str(event_seen.pressed), app.last_command, app.last_error, str(kickoff.get_global_rect())])
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
	if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": await entry()
	await command("new_career", {"club":0, "mode":"fiction"})
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
		check(app.find_child("Art_office_hero", true, false) != null, "Image originale présente dans le Bureau réel")
		var positions := {"OfficeFixture":Vector2(280,220), "OfficeDecisions":Vector2(1656,220), "OfficeGroup":Vector2(280,654), "OfficeStandings":Vector2(718,654), "OfficeJournal":Vector2(1418,654), "OfficeRecruitment":Vector2(1982,654), "OfficeTimeline":Vector2(280,1118)}
		for id in positions:
			var tile: Control = app.find_child(id,true,false)
			check(tile != null and tile.global_position.distance_to(positions[id]) <= 1.5, "Coordonnées exactes du gabarit : " + id + " " + str(tile.global_position if tile != null else Vector2.ZERO))
		await capture("01-bureau-2560x1440")
		app._navigate("Effectif")
		shell.render(app)
		await settle()
		var roster: Control = app.find_child("ImmersiveRosterTable", true, false)
		if OS.get_environment("CD_IMMERSIVE_SCOPE") != "office": check(roster != null, "Table Effectif dense de la référence 1440p")
		if roster != null:
			var list: VBoxContainer = app.find_child("ImmersiveRosterRows", true, false)
			var row_buttons: Array = list.get_children().filter(func(node:Node):return node is Button)
			check(row_buttons.size() == mini(24,app.model.squad.size()), "24 lignes du gabarit approuvé, pagination des joueurs supplémentaires")
			var all_ids: Array = row_buttons.map(func(node:Node):return str(node.get_meta("player_id")))
			var next_page: Button = app.find_child("RosterPaginationNext",true,false)
			check(next_page != null, "Pagination conservée depuis natif07")
			while next_page != null and not next_page.disabled:
				next_page.pressed.emit()
				await settle()
				all_ids.append_array(list.get_children().filter(func(node:Node):return node is Button).map(func(node:Node):return str(node.get_meta("player_id"))))
			check(all_ids.size()==app.model.squad.size(), "Tout le groupe consultable à travers les pages")
			check(all_ids.all(func(id):return all_ids.count(id)==1), "Aucun joueur omis ou dupliqué dans la pagination")
			var saved_page: int = app.management_ui.roster.page
			app._navigate("Bureau");app._navigate("Effectif");await settle()
			check(int(app.management_ui.roster.page)==saved_page,"Retour respecte la page volontaire sans révéler à nouveau le dossier")
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
			check(list.get_children().filter(func(node:Node):return node is Button).size() == mini(24,app.model.squad.size()), "Effacer la recherche retrouve le groupe paginé")
			await capture("02-effectif-2560x1440")
			app.find_child("OpenPlayerFull",true,false).pressed.emit()
			await settle()
			var full:Control=app.find_child("ImmersivePlayerFull",true,false)
			check(full!=null,"La fiche complète est une vraie page, pas un bouton inerte")
			if full!=null:
				check(app.find_child("ProfilePlayerName",true,false).text.to_lower()==str(target.name).to_lower(),"Identité exacte dans la fiche complète")
				for attribute in target.get("attributes",{}):
					check(app.find_child("PlayerAttribute_"+attribute,true,false)!=null,"Aptitude réelle dans la fiche : "+attribute)
				check(app.find_child("OpenPlayerCoachNote",true,false)!=null,"Carnet personnel conservé sur la fiche")
				await capture("04-fiche-joueur-2560x1440")
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
			for action: Button in [candidates.get_ok_button(), candidates.find_child("LineupRemove",true,false)]:
				var bounds := action.get_global_rect()
				bounds.position+=Vector2(candidates.position)
				check(visible.encloses(bounds),"Action de la sélection entièrement visible en 720p · "+str(action.name))
			await capture("37-candidats-redimensionne-1280x720")
			root.size=Vector2i(2560,1440)
			await settle()
		app._clear_dialogs()
		await settle()
		var original_defense:String=app.model.tactics.defense
		var attack:Button=app.find_child("TacticsAttack_occupation",true,false)
		attack.pressed.emit()
		await worker()
		check(app.bridge.last_response_ok and app.model.tactics.attack=="occupation","Le bouton d’attaque commande réellement le moteur")
		check(app.model.tactics.defense==original_defense,"Changer l’attaque conserve la défense")
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
