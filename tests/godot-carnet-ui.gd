extends SceneTree
var app: Control
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
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse native bornée")
func command(id: String, payload: Dictionary = {}) -> void:
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
func bounds(route: String) -> void:
	var page: Control = named(app, ROUTES[route])
	check(page != null, "Vue carnet " + route)
	if page == null: return
	check(page.get_global_rect().end.x <= app.size.x + 1 and page.get_global_rect().end.y <= app.size.y + 1, "Vue dans la fenêtre " + route + " " + str(page.get_global_rect()))
	for child in page.find_children("*", "ScrollContainer", true, false):
		if child.is_visible_in_tree(): check(child.follow_focus, "Défilement suit le focus " + route)
	for b in page.find_children("*", "Button", true, false):
		if b is Button and not b.disabled:
			check(b.focus_mode == Control.FOCUS_ALL, "Commande clavier " + route)
			check(b.size.y >= 30 and b.size.x >= 20, "Cible utilisable " + route + " " + b.text)
func contrast(first: Color, second: Color) -> float:
	var a:=first.srgb_to_linear().get_luminance()
	var b:=second.srgb_to_linear().get_luminance()
	return (maxf(a,b)+.05)/(minf(a,b)+.05)
func readability() -> void:
	await render("Composition")
	var board: Control = app.body.find_children("*", "Control", true, false).filter(func(c):return c.get_script()!=null and c.get_script().resource_path.ends_with("lineup_board.gd"))[0]
	for tile: Button in board.tiles:
		var caption: Label = tile.find_children("*", "Label", true, false)[0]
		var background: StyleBoxFlat = tile.get_theme_stylebox("normal")
		var ink := caption.get_theme_color("font_color").srgb_to_linear().get_luminance()
		var paper := background.bg_color.srgb_to_linear().get_luminance()
		check((maxf(ink,paper)+.05)/(minf(ink,paper)+.05)>=4.5,"Contraste lisible carte de terrain " + caption.text)
	for b in app.body.find_children("*","Button",true,false):
		var style:StyleBoxFlat=b.get_theme_stylebox("normal")
		check(contrast(b.get_theme_color("font_focus_color"),style.bg_color)>=4.5,"Contraste du texte au focus " + b.text)
	app.settings()
	for d in dialogs():
		var border: StyleBoxFlat=d.get_theme_stylebox("embedded_border","Window")
		check(contrast(d.get_theme_color("title_color","Window"),border.bg_color)>=4.5,"Titre du dialogue lisible")
	app._clear_dialogs()
	await settle()
	await render("Match")
	var rail: Control = named(app,"MatchNotebook")
	check(rail != null and rail.size.x <= 360,"Le carnet de match laisse la priorité au terrain")
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
		check(Vector2(d.size).x<=client.x and Vector2(d.size).y<=client.y,"Dialogue dans la fenêtre " + id)
		check(d.get_ok_button().is_visible_in_tree(),"Validation du dialogue visible " + id)
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
	await capture_dialog("parametres-1440")
	await press("Packs et identités")
	check(app.route=="Packs" and app.pack_manager.scope=="career","Paramètres ouvrent les packs de carrière")
	await press("IMPORTER UN PACK ZIP")
	check(app.pack_manager.picker.visible,"Vrai dialogue ZIP accessible")
	for list in app.pack_manager.picker.find_children("*","ItemList",true,false):
		if list.is_visible_in_tree():
			check(contrast(list.get_theme_color("font_selected_color"),Color("f3eddf"))>=4.5,"Nom de fichier sélectionné lisible dans le dialogue papier")
	await capture("import-pack-1440")
	app.pack_manager.picker.hide()
	app.pack_manager.back()
	await settle()
	app.pause_menu()
	await capture_dialog("menu-carriere-1440")
	app._clear_dialogs()
	await settle()
func decisions() -> void:
	await command("new_career",{"club":29,"mode":"france"})
	await render("Effectif")
	var player_id: String = str(app.model.squad[0].id)
	app.selected_player=player_id
	await render("Effectif")
	var load_choice: OptionButton=named(app,"PlayerLoad")
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
	var attack: Dictionary=app.model.tactics.attacks.filter(func(t):return t.id!=app.model.tactics.attack)[0]
	await press(str(attack.label).to_upper())
	await wait_model()
	check(app.model.tactics.attack==attack.id,"Consigne enregistrée via le bouton réel")
	await press("CHARGE NORMALE")
	await wait_model()
	check(app.model.meta.trained,"Séance collective réellement effectuée")
	await render("Recrutement")
	var available: Array=app.model.market.filter(func(p):return p.get("available",false))
	check(not available.is_empty(),"Un vrai candidat est disponible dans cette carrière")
	if not available.is_empty():
		var candidate: Dictionary=available[0]
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
	await render("Match")
	await press("COUP D'ENVOI")
	await wait_model()
	check(not app._live().is_empty(),"Coup d’envoi réel")
	await command("pause",{"paused":true})
	await render("Effectif")
	check(named(app,"PlayerLoad").disabled,"Charge verrouillée pendant le direct")
	check(button(app,"PROPOSER UNE PROLONGATION").disabled,"Prolongation verrouillée pendant le direct")
	await render("Composition")
	check(button(app,"SÉLECTION AUTOMATIQUE DU STAFF").disabled,"Sélection verrouillée pendant le direct")
	await render("Préparation")
	check(button(app,"CHARGE NORMALE").disabled,"Séance verrouillée pendant le direct")
	await render("Match")
	await capture("match-pause-1440")
	var actual: Dictionary=app.model
	var long_names: Dictionary=actual.duplicate(true)
	for group in [long_names.live.lineup,long_names.live.reserves]:
		for p in group:
			if p is Dictionary:p.name="Joueur de réception au nom particulièrement long pour éprouver le banc et les remplacements"
	app.model=long_names
	await render("Match")
	await press("BANC")
	bounds("Match")
	await capture("match-banc-projection-long")
	app.model=actual
	await render("Match")
	await press("STATS")
	await capture("match-statistiques-1440")
	await press("BANC")
	await capture("match-banc-1440")
	var screen: Control=app.match_screen
	var incoming: Dictionary={}
	for sub: Dictionary in app.model.live.get("substitutions",[]):
		if not sub.get("inIds",[]).is_empty(): incoming=sub;break
	if not incoming.is_empty():
		screen.selected_slot=int(incoming.slot)
		screen.presence_key=""
		screen._side()
		var reserve: Dictionary=app.model.live.reserves.filter(func(p):return p is Dictionary and p.id==incoming.inIds[0])[0]
		await press(str(reserve.name))
		await wait_model()
		check(app.model.live.lineup.any(func(p):return p is Dictionary and p.id==reserve.id),"Remplacement réel depuis le banc")
	await command("delegate")
	await render("Match")
	await capture("match-resultat-1440")
	await press("VALIDER LA JOURNÉE  →")
	await wait_model()
	check(int(app.model.meta.week)==1,"Résultat validé une fois")
	await render("Finances")
	check(not app.model.finance.ledger.is_empty(),"Vrais flux financiers après la journée")
	await capture("finances-flux-reels-1440")
	await render("Calendrier")
	await capture("calendrier-resultat-reel-1440")
func variants() -> void:
	for setup in [[29,"common"],[0,"france"],[0,"fiction"]]:
		await command("new_career",{"club":setup[0],"mode":setup[1]})
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
	print("CARNET : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_model()
	app.timer.stop()
	await command("new_career", {"club":0,"mode":"common"})
	for route in ROUTES:
		await render(route)
		check(named(app, ROUTES[route]) != null, "Composition carnet présente " + route)
	if not failures.is_empty(): finish(); return
	await readability()
	var before: Dictionary = await state()
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
	check(bytes == FileAccess.get_file_as_bytes(filename), "Toutes vues : octets sauvegarde identiques")
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await decisions()
	await variants()
	await projections()
	finish()
