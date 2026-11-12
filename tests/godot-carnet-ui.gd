extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var speech_requests := 0
var speech_starts := 0
var checks := 0
var failures: Array[String] = []
const ROUTES = {"Effectif":"CarnetSquad", "Composition":"CarnetLineup", "Préparation":"CarnetPreparation", "Recrutement":"CarnetMarket", "Finances":"CarnetFinance", "Club":"CarnetClub", "Calendrier":"CarnetCalendar", "Classements":"CarnetStandings", "Match":"CarnetMatch", "Accueil":"CarnetHome", "Création":"CarnetCreation", "Packs":"CarnetPacks"}
func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL: ", text)
func named(node: Node, id: String) -> Node:
	if str(node.name) == id: return node
	for child in node.get_children():
		var result := named(child, id)
		if result != null: return result
	return null
func button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children(true):
		var result := button(child, text)
		if result != null: return result
	return null
func page_for(route: String) -> Control:
	if route == "Match" and app.contextual_director.active() and app.contextual_director.kind == "live": return app.match_screen
	var page := named(app,ROUTES[route]) as Control
	if page!=null:return page
	var alternatives := {
		"Composition":["ImmersiveTactics"], "Préparation":["ImmersivePreparation","ImmersiveTraining"],
		"Finances":["ImmersiveFinance"], "Club":["ImmersiveClub"],
	}
	for id: String in alternatives.get(route,[]):
		page=named(app,id) as Control
		if page!=null:return page
	return null
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse native bornée")
func command(id: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND godot-carnet-ui ",id)
	app._command(id, payload)
	await wait_model()
	check(app.bridge.last_response_ok, "Commande réelle " + id + " / " + app.last_error)
func settle() -> void:
	for i in 5: await process_frame
func render(route: String) -> void:
	app._navigate(route)
	await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("CD_CARNET_CAPTURES")
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, "Capture native " + id)
func press(text: String) -> void:
	var b := button(app, text)
	check(b != null and not b.disabled, "Action utilisable " + text)
	if b != null and not b.disabled:
		b.grab_focus()
		await process_frame
		check(b.has_focus(), "Focus réel " + text)
		b.pressed.emit()
		await settle()
func bench_control(screen: Control, key: String) -> Button:
	var controls: Array = screen.drawer_body.find_children("*","Button",true,false).filter(func(control): return control.get_meta("match_bench_focus","") == key)
	check(controls.size() == 1,"Contrôle du banc lié à une identité unique : "+key)
	return controls[0] as Button if controls.size() == 1 else null
func activate_bench(control: Button, key: String) -> void:
	check(control != null and control.is_visible_in_tree() and not control.disabled,"Action réelle du banc disponible : "+key)
	if control == null or control.disabled: return
	control.grab_focus()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await settle()
	check(control.has_focus(),"Focus réel du banc : "+key)
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(2).encloses(control.get_global_rect()),"Commande du banc entière dans la fenêtre : "+key)
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
func press_match_drawer(caption: String, expected: String) -> void:
	var screen := page_for("Match")
	var matches := screen.find_children("*","Button",true,false).filter(func(control): return control.text == caption and control.is_visible_in_tree() and not control.disabled)
	check(matches.size()==1,"Action visible unique du vrai direct : "+caption)
	if matches.size()!=1: return
	var control := matches[0] as Button
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()
	check(control.has_focus(),"Focus réel du bouton du direct : "+caption)
	check(screen.drawer_tab==expected and screen.drawer.visible,"Le vrai clic ouvre le tiroir contextuel : "+expected)
func bounds(route: String) -> void:
	var page := page_for(route)
	check(page != null, "Vue carnet " + route)
	if page == null: return
	if route == "Préparation":
		var viewport: ScrollContainer = named(app, "CareerWorkspace")
		check(viewport != null and viewport.get_global_rect().end.x <= app.size.x + 1 and viewport.get_global_rect().end.y <= app.size.y + 1, "Viewport réel de préparation borné dans la fenêtre")
		check(page.get_global_rect().end.x <= viewport.get_global_rect().end.x + 1, "Préparation sans débordement horizontal")
		for b: Button in page.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.disabled:
				b.grab_focus()
				viewport.ensure_control_visible(b)
				check(b.has_focus(), "Préparation : commande réelle accessible par focus " + b.text)
				# Inner lists have their own viewport; the outer viewport must reveal
				# each whole command when that command belongs directly to this page.
				if not b.has_meta("tactic_id"):
					check(viewport.get_global_rect().encloses(b.get_global_rect()), "Préparation : commande révélée par défilement " + b.text)
	else:
		check(page.get_global_rect().end.x <= app.size.x + 1 and page.get_global_rect().end.y <= app.size.y + 1, "Vue dans la fenêtre " + route + " " + str(page.get_global_rect()))
	for child in page.find_children("*", "ScrollContainer", true, false):
		if child.is_visible_in_tree(): check(child.follow_focus, "Défilement suit le focus " + route)
	for b: Button in page.find_children("*", "Button", true, false):
		if not b.disabled and b.is_visible_in_tree():
			check(b.focus_mode == Control.FOCUS_ALL, "Commande clavier " + route)
			var hit := b.get_global_rect()
			var scale := b.get_global_transform().get_scale().y
			var font_size := b.get_theme_font_size("font_size")
			var text_height := b.get_theme_font("font").get_height(font_size)*scale
			check(hit.size.x>=20 and hit.size.y>=maxf(18,text_height), "Cible et texte utilisables " + route + " " + str(b.name))
			if b.name == "CompetitionNextDateLink":
				var date_caption := named(page,"CompetitionNextDate") as Label
				check(date_caption != null and not date_caption.text.strip_edges().is_empty() and b.accessibility_name.contains(date_caption.text),"Lien de date : libellé visible et nom accessible concordants")
func contrast(first: Color, second: Color) -> float:
	var a:=first.srgb_to_linear().get_luminance()
	var b:=second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+.05)/(minf(a,b)+.05)
func readability() -> void:
	await render("Composition")
	for number in range(1,16):
		var tile := named(app,"LineupSlot%02d"%number) as Button
		check(tile!=null,"Poste réel du terrain "+str(number))
		if tile==null:continue
		var captions := tile.find_children("*","Label",true,false)
		var caption := captions.back() as Label if not captions.is_empty() else null
		var background := tile.get_theme_stylebox("normal") as StyleBoxFlat
		var surfaces := tile.find_children("*","Panel",true,false)
		if background==null and not surfaces.is_empty():background=surfaces.back().get_theme_stylebox("panel") as StyleBoxFlat
		check(caption!=null and background!=null and contrast(caption.get_theme_color("font_color"),background.bg_color)>=4.5,"Contraste lisible carte de terrain "+str(number))
	for b in app.body.find_children("*","Button",true,false):
		var style := b.get_theme_stylebox("normal") as StyleBoxFlat
		if style!=null and style.bg_color.a>.9 and not b.text.is_empty():
			check(contrast(b.get_theme_color("font_focus_color"),style.bg_color)>=4.5,"Contraste du texte au focus " + b.text)
	app.settings()
	for d in dialogs():
		var border: StyleBoxFlat=d.get_theme_stylebox("embedded_border","Window")
		check(contrast(d.get_theme_color("title_color","Window"),border.bg_color)>=4.5,"Titre du dialogue lisible")
	app._clear_dialogs()
	await settle()
	await render("Match")
	var rail: Control = named(app,"MatchNotebook")
	var pitches: Array = app.match_screen.find_children("*","SubViewportContainer",true,false)
	var pitch := pitches[0] as Control if not pitches.is_empty() else null
	check(rail!=null and pitch!=null and pitch.get_global_rect().size.x>rail.get_global_rect().size.x,"Le carnet de match laisse la priorité au vrai terrain")
func state() -> Dictionary:
	await command("export")
	return JSON.parse_string(app.model.meta.exportText).state
func options(node: Node) -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	if node is OptionButton: result.append(node)
	for child in node.get_children(): result.append_array(options(child))
	return result
func texts(node: Node) -> String:
	var result: String = node.text + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += texts(child)
	return result
func dialogs() -> Array[AcceptDialog]:
	var result: Array[AcceptDialog] = []
	for child in app.get_children():
		if child is AcceptDialog and child.visible and child != app.file_dialog: result.append(child)
	return result
func capture_dialog(id: String) -> void:
	await settle()
	var client := Vector2(root.size)
	for d in dialogs():
		check(Vector2(d.size).x<=client.x and Vector2(d.size).y<=client.y,"Dialogue dans la fenêtre %s (%s dans %s)" % [id,d.size,root.size])
		var confirmation := d.get_ok_button()
		check(confirmation.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(d.size)).encloses(confirmation.get_global_rect()),"Validation du dialogue entière " + id)
		for spin in d.find_children("*","SpinBox",true,false):
			var background: StyleBoxFlat=spin.get_line_edit().get_theme_stylebox("normal")
			check(contrast(spin.get_theme_color("up_icon_modulate"),background.bg_color)>=3.0,"Flèches de saisie lisibles " + id)
	await capture(id)
func reading_actions() -> void:
	await render("Effectif")
	var family:OptionButton=named(app,"RosterFamily")
	check(family!=null and named(app,"RosterSort")!=null and named(app,"PlayerLoad")!=null,"Filtres, tri et charge individuelle conservés")
	family.select(2)
	family.item_selected.emit(2)
	await settle()
	check(app.roster_filter=="Arrières","Filtre réel des arrières")
	var shown: Array = app.body.find_children("SquadPlayer*","Button",true,false)
	for row in shown:
		var id: String = row.get_meta("player_id")
		check(app.model.squad.any(func(p):return str(p.id)==id and float(p.fam)>3),"Filtre appliqué aux bons joueurs")
	var sorting:OptionButton=named(app,"RosterSort")
	for i in sorting.item_count:
		if sorting.get_item_text(i)=="Niveau":sorting.select(i);sorting.item_selected.emit(i);break
	await settle()
	check(app.roster_sort=="Niveau","Tri réel par niveau")
	shown=app.body.find_children("SquadPlayer*","Button",true,false)
	var previous:=101.0
	for row in shown:
		var id: String = row.get_meta("player_id")
		var player: Dictionary = app.model.squad.filter(func(p):return str(p.id)==id)[0]
		check(float(player.rating)<=previous,"Ordre décroissant du niveau")
		previous=float(player.rating)
	check(not shown.is_empty(),"Vraie sélection de joueur possible")
	var chosen: Button = shown[-1]
	chosen.grab_focus()
	await settle()
	check(chosen.has_focus(),"La dernière ligne défile jusqu’au focus")
	var chosen_id: String=str(chosen.get_meta("player_id"))
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=chosen.get_global_rect().get_center()
		root.push_input(event,true)
		await process_frame
	await settle()
	check(app.selected_player==chosen_id,"Fiche sélectionnée par ID après filtre et tri")
	app.roster_filter="Tous"
	app.roster_sort="Poste"
	await render("Classements")
	var leagues: Array=app.model.leagues
	if leagues.size()>1:
		await press(str(leagues[1].name).to_upper())
		check(app.table_division==leagues[1].id,"Changement réel de division")
	app.settings()
	var preference_tabs := named(app,"PreferencesTabs") as TabContainer
	check(preference_tabs!=null,"Onglets réels des paramètres")
	if preference_tabs!=null:
		for index in preference_tabs.get_tab_count():
			if preference_tabs.get_tab_title(index)=="Affichage":preference_tabs.current_tab=index;break
	await settle()
	await capture_dialog("parametres-1440")
	var packs_button: Button = button(app,"Importez un pack personnalisé")
	check(packs_button != null and packs_button.is_visible_in_tree(),"Accès personnalisé aux packs visible dans les paramètres")
	await press("Importez un pack personnalisé")
	check(app.route=="Packs" and app.pack_manager.scope=="career","Paramètres ouvrent les packs de carrière")
	await press("Importer une autre réalité")
	check(app.pack_manager.picker.visible,"Vrai dialogue ZIP accessible")
	for list in app.pack_manager.picker.find_children("*","ItemList",true,false):
		if list.is_visible_in_tree():
			for state in ["selected","selected_focus"]:
				var style := list.get_theme_stylebox(state) as StyleBoxFlat
				check(style!=null and contrast(list.get_theme_color("font_selected_color"),style.bg_color)>=4.5,"Nom de fichier sélectionné lisible sur son vrai fond "+state)
	await capture("import-pack-1440")
	app.pack_manager.picker.hide()
	app.pack_manager.back()
	await settle()
	app.pause_menu()
	await capture_dialog("menu-carriere-1440")
	app._clear_dialogs()
	await settle()
func check_completed_player_load() -> void:
	var original_size := root.size
	await render("Effectif")
	var profile_tabs := named(app,"ProfileTabs") as TabContainer
	profile_tabs.current_tab = 2
	await settle()
	var compact := named(app,"PlayerLoad") as OptionButton
	var compact_reason := named(app,"PlayerLoadUnavailableReason") as Label
	check(compact != null and compact.is_visible_in_tree() and compact.disabled and compact.focus_mode == Control.FOCUS_NONE,"Fiche compacte : charge verrouillée après séance")
	check(compact_reason != null and compact_reason.is_visible_in_tree() and "Séance" in compact_reason.text,"Fiche compacte : motif visible à côté de la charge")
	root.size = Vector2i(1920,1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await render("Effectif")
	var open_full := named(app,"OpenPlayerFull") as Button
	check(open_full != null,"Fiche large accessible")
	if open_full != null:
		open_full.pressed.emit()
		await settle()
		var load := named(app,"PlayerLoad") as Button
		check(load != null and not load.disabled and load.focus_mode == Control.FOCUS_ALL,"Fiche large : lecture du plan accessible au clavier")
		if load != null:
			load.pressed.emit()
			await settle()
			var rest := named(app,"IndividualLoad_repos") as Button
			var reason := named(app,"PlayerLoadUnavailableReason") as Label
			check(rest != null and rest.disabled and rest.focus_mode == Control.FOCUS_NONE,"Fiche large : récupération verrouillée après séance")
			check(reason != null and reason.is_visible_in_tree() and "Séance" in reason.text,"Fiche large : motif visible à côté des choix")
	app._clear_dialogs()
	root.size = original_size
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await settle()

func decisions() -> void:
	await command("new_career",{"club":29,"mode":"france"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await render("Effectif")
	var player_id: String = str(app.model.squad[0].id)
	app.selected_player=player_id
	await render("Effectif")
	var profile_tabs:TabContainer=named(app,"ProfileTabs")
	profile_tabs.current_tab=2
	await settle()
	var load_choice: OptionButton=named(app,"PlayerLoad")
	check(load_choice.is_visible_in_tree(),"Charge accessible dans la tuile Contrat")
	load_choice.item_selected.emit(1)
	await wait_model()
	check(app.model.squad.filter(func(p):return str(p.id)==player_id)[0].loadPlan=="repos","Charge individuelle réellement enregistrée")
	await render("Composition")
	for slot: Dictionary in app.model.selection.slots:
		var found:=false
		for id in slot.get("eligibleIds",[]):
			if id==slot.get("playerId"): continue
			app.selected_slot=int(slot.slot)
			await render("Composition")
			for control in app.body.find_children("*","Button",true,false):
				if str(control.get_meta("player_id",""))==str(id) and not control.disabled:
					control.pressed.emit()
					await wait_model()
					check(app.model.lineup[int(slot.slot)]==id,"La vraie liste affecte le joueur au poste choisi")
					found=true
					break
			if found: break
		if found: break
	await render("Préparation")
	await press("CONSIGNES")
	var attack: Dictionary=app.model.tactics.attacks.filter(func(t):return t.id!=app.model.tactics.attack)[0]
	check(button(app,str(attack.label).to_upper()).is_visible_in_tree(),"Consigne visible dans son sous-onglet")
	await press(str(attack.label).to_upper())
	await wait_model()
	check(app.model.tactics.attack==attack.id,"Consigne enregistrée via le bouton réel")
	await press("ENTRAÎNEMENT")
	check(button(app,"CHARGE NORMALE").is_visible_in_tree(),"Charge visible dans son sous-onglet")
	await press("CHARGE NORMALE")
	await wait_model()
	check(app.model.meta.trained,"Séance collective réellement effectuée")
	await check_completed_player_load()
	await render("Recrutement")
	var available: Array=app.model.market.filter(func(p):return p.get("available",false))
	check(not available.is_empty(),"Un vrai candidat est disponible dans cette carrière")
	if not available.is_empty():
		var candidate: Dictionary=available[0]
		var market_search:LineEdit=named(app,"MarketSearch")
		market_search.text=str(candidate.name)
		market_search.text_changed.emit(market_search.text)
		await settle()
		check(named(app,"MarketSearch")==market_search,"Recherche du candidat hors page sans reconstruire le champ")
		for b in app.body.find_children("*","Button",true,false):
			if str(b.get_meta("player_id",""))==str(candidate.id): b.pressed.emit();break
		await capture_dialog("offre-contrat-1440")
		var d: ConfirmationDialog=dialogs()[0]
		var fields:=d.find_children("*","SpinBox",true,false)
		fields[0].value=minf(100000,float(candidate.salary)*2)
		fields[1].value=candidate.get("minYears",1)
		d.confirmed.emit()
		await wait_model()
		check(app.bridge.last_response_ok and app.model.meta.get("negotiation") is Dictionary,"Négociation réelle reçue")
		var response: Dictionary=app.model.meta.get("negotiation",{})
		check(app.model.squad.any(func(p):return p.id==candidate.id)==(response.get("status")=="signed"),"Seule une négociation acceptée ajoute le bon ID à l’effectif")
		await capture_dialog("reponse-contrat-1440")
		app._clear_dialogs()
		await settle()
	await command("auto_lineup")
	if not await ContextualFlow.prepare_match_day(app,self,check): return
	await render("Match")
	var previous_week: int=app.model.meta.week
	await press("COUP D'ENVOI");await wait_model()
	await ContextualFlow.skip_talk(app,self,"pre",check)
	check(not app._live().is_empty() and app.contextual_director.kind=="live","Coup d’envoi et vraie entrée dans le direct")
	await command("pause",{"paused":true})
	var live_before:=await state()
	var live_bytes:=FileAccess.get_file_as_bytes(str(app.model.meta.dataDir).path_join("donnees.json"))
	for route in ["Effectif","Composition","Préparation","Recrutement"]:
		await render(route)
		check(app.route=="Match" and app.contextual_director.kind=="live" and not app.root_content.is_visible_in_tree(),"Le direct verrouille la gestion : "+route)
	check(await state()==live_before and FileAccess.get_file_as_bytes(str(app.model.meta.dataDir).path_join("donnees.json"))==live_bytes,"Tenter une navigation du direct ne modifie ni état ni disque")
	await render("Match")
	await capture("match-pause-1440")
	var actual: Dictionary=app.model
	var long_names: Dictionary=actual.duplicate(true)
	for group in [long_names.live.lineup,long_names.live.reserves]:
		for p in group:
			if p is Dictionary:p.name="Joueur de réception au nom particulièrement long pour éprouver le banc et les remplacements"
	app.model=long_names
	await render("Match")
	await press_match_drawer("BANC","Banc")
	bounds("Match")
	await capture("match-banc-projection-long")
	app.model=actual
	await render("Match")
	await press_match_drawer("STATS","Stats")
	await capture("match-statistiques-1440")
	await press_match_drawer("BANC","Banc")
	await capture("match-banc-1440")
	var screen: Control=app.match_screen
	var incoming: Dictionary={}
	for sub: Dictionary in app.model.live.get("substitutions",[]):
		if not sub.get("inIds",[]).is_empty(): incoming=sub;break
	if not incoming.is_empty():
		check(app.model.live.lineup[int(incoming.slot)].id == incoming.outId,"Le poste publié désigne le vrai joueur sortant")
		await activate_bench(bench_control(screen,"sortant:"+str(int(incoming.slot))),"sortant:"+str(int(incoming.slot)))
		for player: Dictionary in app.model.live.reserves:
			var candidate := bench_control(screen,"entrant:"+str(player.id))
			check(candidate != null and candidate.disabled == (not player.id in incoming.inIds),"Le banc respecte les aptitudes publiées et refuse les positions interdites : "+str(player.id))
		var reserve: Dictionary=app.model.live.reserves.filter(func(p):return p is Dictionary and p.id==incoming.inIds[0])[0]
		await activate_bench(bench_control(screen,"entrant:"+str(reserve.id)),"entrant:"+str(reserve.id))
		await wait_model()
		check(app.bridge.last_response_ok and app.model.live.lineup.any(func(p):return p is Dictionary and p.id==reserve.id),"Remplacement réel depuis le banc")
	await command("delegate")
	await render("Effectif")
	check(app.route=="Match" and app.contextual_director.kind=="live" and not app.root_content.is_visible_in_tree(),"La gestion reste verrouillée avant validation du résultat")
	await render("Match")
	await capture("match-resultat-1440")
	await press("VALIDER LA JOURNÉE  →")
	await wait_model()
	await ContextualFlow.finish_match_week(app,self,check,previous_week)
	check(int(app.model.meta.week)==previous_week+1,"Résultat validé une fois")
	app.selected_player = player_id
	await render("Effectif")
	(named(app,"ProfileTabs") as TabContainer).current_tab = 2
	await settle()
	var next_load := named(app,"PlayerLoad") as OptionButton
	check(next_load != null and next_load.is_visible_in_tree() and not next_load.disabled,"Charge réactivée la semaine suivante")
	if next_load != null and not next_load.disabled:
		next_load.item_selected.emit(2)
		await wait_model()
		check(app.bridge.last_response_ok and app.model.squad.any(func(p):return str(p.id)==player_id and p.loadPlan=="normal"),"Charge réellement réglée la semaine suivante")
	await render("Finances")
	check(not app.model.finance.ledger.is_empty(),"Vrais flux financiers après la journée")
	await capture("finances-flux-reels-1440")
	await render("Calendrier")
	await capture("calendrier-resultat-reel-1440")
func variants() -> void:
	for setup in [[29,"common"],[0,"france"],[0,"fiction"]]:
		await command("new_career",{"club":setup[0],"mode":setup[1]})
		await ContextualFlow.settle_club_meetings(app, self, check)
		for route in ["Effectif","Composition","Préparation","Recrutement","Finances","Club","Calendrier","Classements","Match"]:
			await render(route)
			bounds(route)
			if route in ["Effectif","Classements"]:await capture(route.to_lower()+"-"+str(setup[1])+"-"+str(setup[0]))
func projections() -> void:
	var saved: Dictionary=app.model.duplicate(true)
	var projected: Dictionary=saved.duplicate(true)
	projected.club.presentation.name="Club de réception au nom particulièrement long pour éprouver les espaces et l’accès au menu"
	projected.club.presentation.color="#ffff00"
	for p: Dictionary in projected.squad: p.name="Joueur au nom particulièrement long pour éprouver les fiches et la sélection "+str(p.id)
	projected.packs={"missing":["Pack de carrière absent : réception"]}
	app.model=projected
	app.accent=Color("ffff00")
	for route in ["Effectif","Composition","Club","Calendrier","Classements"]:
		await render(route)
		bounds(route)
		await capture(route.to_lower()+"-projection-long-jaune-pack-absent")
	app.model=saved
	app.accent=Color(app.G.identity(saved.club).get("color","#d43e47"))
	await render("Bureau")
func finish() -> void:
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech), "Voix du client disponible pour le contrôle final")
	if is_instance_valid(app.coach) and is_instance_valid(app.coach.speech):
		check(speech_requests == 0 and speech_starts == 0 and app.coach.speech._id == 0, "Client Carnet : aucune parole demandée ni démarrée, identifiant vocal nul")
		print("CARNET_SPEECH requested=", speech_requests, " started=", speech_starts, " id=", app.coach.speech._id)
	print("CARNET : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.closing=true
	if is_instance_valid(app.coach):app.coach.destroy()
	app.bridge.stop()
	var deadline := Time.get_ticks_msec()+2300
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await process_frame
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	# The single client is muted synchronously after _ready, before any awaited frame.
	check(is_instance_valid(app.coach) and is_instance_valid(app.coach.speech), "Voix du client disponible dès son instanciation")
	if is_instance_valid(app.coach) and is_instance_valid(app.coach.speech):
		app.coach.speech.requested.connect(func(_text: String): speech_requests += 1)
		app.coach.speech.started.connect(func(_id: int): speech_starts += 1)
		app.coach.speech.set_muted(true)
		check(app.coach.speech._id == 0, "Client Carnet : aucune parole avant la mise en sourdine précoce")
	await wait_model()
	app.timer.stop()
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	for route in ROUTES:
		await render(route)
		check(page_for(route) != null, "Composition carnet présente " + route)
	if not failures.is_empty(): await finish(); return
	await readability()
	var before: Dictionary = await state()
	var export_before: String = app.model.meta.exportText
	var filename: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(filename)
	for resolution in [Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080)]:
		root.size = resolution
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
		await settle()
		for route in ROUTES:
			await render(route)
			bounds(route)
			await capture(route.to_lower() + "-" + str(resolution.x))
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await reading_actions()
	var after: Dictionary = await state()
	check(before == after, "Toutes vues et tailles : S/RNG identiques")
	check(export_before == app.model.meta.exportText, "Toutes vues : export complet identique octet pour octet")
	check(bytes == FileAccess.get_file_as_bytes(filename), "Toutes vues : octets sauvegarde identiques")
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await decisions()
	await variants()
	await projections()
	await finish()
