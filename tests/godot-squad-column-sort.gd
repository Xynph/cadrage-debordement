extends SceneTree
const Squad = preload("res://ui/immersive08/squad_canvas.gd")
const U = preload("res://ui/management_state.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_SQUAD_SORT_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for i in 8: await process_frame
func person(id: String) -> Dictionary:
	return {"id":id,"name":id,"pos":"Pilier gauche","fam":0,"age":25,"shirtNumber":1,"rating":70,"potential":75,"condition":95,"physicalLoad":10,"note":70,"salary":1000,"contractEnd":2,"minutes":0,"status":"Titulaire","injury":0}
func names(players: Array) -> Array:
	return players.map(func(player: Dictionary):return player.id)
func projections() -> void:
	var numeric := {"Numéro":"shirtNumber","Âge":"age","Niveau":"rating","Potentiel":"potential","Condition":"condition","Fatigue":"physicalLoad","Note":"note","Salaire":"salary","Échéance":"contractEnd","Minutes":"minutes"}
	for key: String in numeric:
		var source: Array = []
		for pair in [["h",10],["u",null],["b",2],["a",2],["z",0]]:
			var player := person(pair[0]); player[numeric[key]] = pair[1]; source.append(player)
		var before := JSON.stringify(source)
		var reading := U.defaults(); reading.sort = key
		check(names(Squad.ordered_players(source,reading,1)) == ["z","a","b","h","u"],"Numérique croissant, zéro connu, nul dernier et égalités ID : "+key)
		reading.descending = true
		check(names(Squad.ordered_players(source,reading,1)) == ["h","a","b","z","u"],"Numérique décroissant, inconnu toujours dernier : "+key)
		check(JSON.stringify(source) == before,"Source numérique intacte : "+key)
	var source: Array = []
	for pair in [["z","Zoé"],["u",null],["b","émile"],["a","Émile"]]:
		var player := person(pair[0]);player.name = pair[1];source.append(player)
	var reading := U.defaults();reading.sort = "Nom"
	check(names(Squad.ordered_players(source,reading,1)) == ["a","b","z","u"],"Texte accentué plié et égalités ID stables")
	reading.descending = true
	check(names(Squad.ordered_players(source,reading,1)) == ["z","a","b","u"],"Texte décroissant et inconnu dernier")
	source = [person("b"),person("a"),person("u")]
	source[0].status = "Titulaire";source[1].status = "Hors groupe";source[2].status = null
	reading.sort = "Statut";reading.descending = false
	check(names(Squad.ordered_players(source,reading,1)) == ["a","b","u"],"Statut trié comme texte affiché")
	reading.descending = true
	check(names(Squad.ordered_players(source,reading,1)) == ["b","a","u"],"Statut décroissant conserve les inconnus derniers")
	source[1].injury = 2
	check(Squad.sort_value(source[1],"Statut") == "blesse","Blessure utilise le statut effectivement affiché")
	source = [person("c"),person("a"),person("b"),person("u")]
	source[0].condition = 70;source[1].physicalLoad = 80;source[2].physicalLoad = 80
	reading.sort = "Motif";reading.descending = false
	check(names(Squad.ordered_players(source,reading,1)) == ["a","b","c","u"],"Motif de surveillance textuel, vide dernier")
	reading.descending = true
	check(names(Squad.ordered_players(source,reading,1)) == ["c","a","b","u"],"Motif décroissant et égalités stables")
func wait_engine() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : "+app.last_error)
	await settle()
func table() -> Control:return app.find_child("CarnetSquad",true,false)
func visible_ids() -> Array:
	return table().rows.get_children().filter(func(node: Node):return node is Button and node.has_meta("player_id")).map(func(node: Node):return node.get_meta("player_id"))
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down
		Input.parse_input_event(event);await process_frame
	await settle()
func mouse(point: Vector2,index: MouseButton) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=index;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
	projections()
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await wait_engine()
	app._command("new_career",{"mode":"common","club":29});await wait_engine();app.timer.stop()
	var original: Dictionary=app.model.duplicate(true)
	var file:=str(original.meta.dataDir).path_join("donnees.json")
	var hash:=FileAccess.get_sha256(file)
	var commands: int=app.bridge._next_id
	app._navigate("Effectif");await settle()
	check(table()!=null,"Vrai tableau d’effectif raccordé")
	check(visible_ids().size()==original.squad.size() and original.squad.size()>24,"Tous les joueurs ont une ligne, au-delà de l’ancienne limite")
	check(app.find_child("RosterPaginationNext",true,false)==null and app.find_child("RosterPaginationPrevious",true,false)==null,"Pagination supprimée")
	var keys: Array=["Numéro","Nom","Poste","Âge","Niveau","Potentiel","Condition","Fatigue","Note","Salaire","Échéance","Minutes","Statut"]
	for criterion: String in keys:
		var button:=app.find_child("Sort_"+criterion,true,false) as Button
		check(button!=null,"En-tête triable : "+criterion)
		if button==null:continue
		await mouse(button.get_global_rect().get_center(),MOUSE_BUTTON_LEFT)
		var first_direction: bool=table().state.descending
		check(table().state.sort==criterion and button.has_focus(),"Clic trie et conserve le focus : "+criterion)
		button.grab_focus();await process_frame;await key(KEY_ENTER)
		check(table().state.sort==criterion and table().state.descending!=first_direction,"Entrée inverse le sens : "+criterion)
		var label: Label=table().sort_headers[criterion].label
		check(label.text.ends_with("↓" if table().state.descending else "↑"),"Flèche du sens actif : "+criterion)
	var controlled:=original.duplicate(true)
	for player: Dictionary in controlled.squad:player.note=0
	controlled.squad[-1].note=100
	app.model=controlled;app._navigate("Effectif");await settle()
	table()._toggle_sort("Note")
	if not table().state.descending:table()._toggle_sort("Note")
	check(visible_ids()[0]==str(controlled.squad[-1].id),"Tri sur la liste entière, même pour le dernier joueur source")
	app.model=original.duplicate(true);app._navigate("Effectif");await settle()
	var scroll:=app.find_child("SquadScroll",true,false) as ScrollContainer
	var header:=app.find_child("RosterHeader",true,false) as Control
	var search:=app.find_child("RosterSearch",true,false) as Control
	var profile:=app.find_child("PlayerDossier",true,false) as Control
	var positions: Array=[header.global_position,search.global_position,profile.global_position]
	scroll.scroll_vertical=0;await settle()
	for i in 8:await mouse(scroll.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical>0,"La molette défile les lignes dans le conteneur interne")
	check(positions==[header.global_position,search.global_position,profile.global_position],"En-tête, filtres et dossier fixes pendant la molette")
	var items: Array=table().rows.get_children().filter(func(node: Node):return node is Button and node.has_meta("player_id"))
	items[0].grab_focus();await settle();await key(KEY_END)
	check(root.gui_get_focus_owner()==items[-1],"Fin atteint le dernier joueur sans page intermédiaire")
	check(scroll.get_global_rect().intersects(items[-1].get_global_rect()),"Dernier joueur visible dans le viewport interne")
	check(positions==[header.global_position,search.global_position,profile.global_position],"Cadre fixe après accès clavier au dernier joueur")
	await capture("effectif-dernier-joueur-1440")
	await key(KEY_HOME)
	check(root.gui_get_focus_owner()==items[0],"Début revient au premier joueur")
	await capture("effectif-tris-1440")
	for player: Dictionary in controlled.squad:player.physicalLoad=80
	app.model=controlled;app.roster_filter=U.WATCH_FILTER;app.management_ui.roster.family=U.WATCH_FILTER
	app._navigate("Effectif");await settle()
	var reason:=app.find_child("Sort_Motif",true,false) as Button
	check(reason!=null,"Motif de surveillance dispose aussi de son en-tête triable")
	if reason!=null:
		reason.grab_focus();await key(KEY_ENTER);var initial: bool=table().state.descending;await key(KEY_ENTER)
		check(table().state.sort=="Motif" and table().state.descending!=initial,"Motif change de sens au clavier")
	await capture("effectif-motif-cas-controle-1440")
	app.model=original
	check(app.bridge._next_id==commands and FileAccess.get_sha256(file)==hash,"Tri et défilement sans commande ni mutation de carrière")
	var report:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"profile_unchanged":FileAccess.get_sha256(file)==hash},"  "));report.close()
	print("EFFECTIF TRI : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
