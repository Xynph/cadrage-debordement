extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
var proof := OS.get_environment("CD_LINEUP_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in 10: await process_frame
func worker() -> void:
	var limit := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<limit: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Worker répond")
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload)
	await worker()
	check(app.bridge.last_response_ok,"Worker réel " + id+" "+app.last_error)
func named(id: String) -> Control: return app.body.find_child(id,true,false)
func board() -> Control:
	for c in app.body.find_children("*","Control",true,false):
		if c.get_script()==load("res://ui/lineup_board.gd"): return c
	return null
func click(c: Control) -> void:
	app.body_scroll.ensure_control_visible(c)
	await settle()
	var point := c.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
		root.push_input(event,true)
		await process_frame
	await settle()
func enter(c: Control) -> void:
	c.grab_focus()
	await settle()
	for down in [true,false]:
		var event := InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down
		Input.parse_input_event(event)
		await process_frame
	await worker()
func bench23() -> Button:
	for b in app.body.find_children("*","Button",true,false):
		if b.text=="23":return b
	return null
func qualifications() -> void:
	var slot:Dictionary={}
	for item in app.model.selection.slots:
		if int(item.slot)==app.selected_slot:slot=item
	for b in named("LineupCandidatesScroll").find_children("*","Button",true,false):
		var id:String=b.get_meta("player_id","")
		var p:Dictionary=app.model.squad.filter(func(player):return str(player.id)==id)[0]
		var allowed:bool=float(p.get("injury",0))<=0 and id in slot.eligibleIds
		check(b.disabled==not allowed,"Qualification worker respectée "+id)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join(id+".png"))
func run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await worker()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	app._navigate("Composition");await settle();app.coach.close()
	await command("export")
	var before: String=app.model.meta.exportText
	var disk := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	check(not bytes.is_empty(),"Invariant disque sur un vrai profil non vide")
	for mode in ["production","adaptive"]:
		for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
			root.size=resolution;DisplayServer.window_set_size(resolution)
			root.content_scale_size=Vector2i(mini(resolution.x,1920),mini(resolution.y,1080)) if mode=="adaptive" else Vector2i(1440,900)
			app._render();await settle();app.coach.close()
			var field := board()
			var overlaps := 0
			for i in 15:
				var tile: Control=field.tiles[i]
				check(Rect2(Vector2.ZERO,field.size).encloses(Rect2(tile.position,tile.size)),"Carte entière %d %s %s"%[i+1,mode,resolution])
				for j in range(i+1,15):
					if tile.get_global_rect().intersects(field.tiles[j].get_global_rect()):overlaps+=1
			check(overlaps==0,"Zéro chevauchement %s %s (%d)"%[mode,resolution,overlaps])
			measurements.append({"mode":mode,"resolution":str(resolution),"canvas":str(app.size),"field":str(field.size),"tile":str(field.tiles[0].size),"overlaps":overlaps})
			if mode=="adaptive":await capture("composition-"+str(resolution.x))
			if mode=="adaptive" and resolution.x==1280:
				for slot in 15:
					check(app.body_scroll.get_global_rect().encloses(board().tiles[slot].get_global_rect()),"15 cartes entières avant défilement %d"%(slot+1))
				for slot in 15:
					await click(board().tiles[slot])
					check(app.selected_slot==slot,"Centre cliquable distinct %d"%(slot+1))
					qualifications()
				await enter(bench23())
				check(app.selected_slot==22,"Vrai poste 23 au clavier")
				check(bench23().has_focus(),"Focus du banc maintenu après sélection")
				check(app.body_scroll.get_global_rect().encloses(bench23().get_global_rect()),"Banc maintenu visible après rebuild")
				await capture("composition-1280-banc23")
				app._navigate("Effectif");await settle();app.coach.close()
				var roster:ScrollContainer=named("SquadScroll")
				var complete:=0
				for row in roster.find_children("*","Button",true,false):
					if roster.get_global_rect().encloses(row.get_global_rect()):complete+=1
				check(complete>=3,"Effectif court : au moins trois lignes complètes (%d)"%complete)
				measurements.append({"roster_height":roster.size.y,"roster_complete":complete})
				await capture("effectif-1280")
				app._navigate("Composition");await settle()
				check(bench23().has_focus() and app.body_scroll.get_global_rect().encloses(bench23().get_global_rect()),"Retour Composition conserve contexte du banc")
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Lecture : profil inchangé")
	await command("export")
	check(app.model.meta.exportText==before,"Lecture : export S/RNG identique")
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size);root.content_scale_size=Vector2i(1280,720)
	app._render();await settle()
	await enter(bench23());qualifications()
	await enter(named("LineupRemove"))
	check(app.model.squad.filter(func(p):return p.get("shirtNumber")==23).is_empty(),"Libération du vrai poste 23")
	check(named("LineupRemove").has_focus(),"Libération conserve le focus")
	var chosen:Button
	for b in named("LineupCandidatesScroll").find_children("*","Button",true,false):
		if not b.disabled:chosen=b
	var chosen_id:String=chosen.get_meta("player_id")
	var chosen_name:String=chosen.name
	chosen.grab_focus();await settle()
	var list_before:int=named("LineupCandidatesScroll").scroll_vertical
	var outer_before:int=app.body_scroll.scroll_vertical
	await enter(chosen)
	print("LINEUP_ASSIGN_SCROLL ",JSON.stringify({"list_before":list_before,"list_after":named("LineupCandidatesScroll").scroll_vertical,"outer_before":outer_before,"outer_after":app.body_scroll.scroll_vertical,"state":app.management_ui.lineup,"list_max":named("LineupCandidatesScroll").get_v_scroll_bar().max_value,"list_page":named("LineupCandidatesScroll").get_v_scroll_bar().page}))
	check(app.model.squad.filter(func(p):return str(p.id)==chosen_id)[0].shirtNumber==23,"Affectation worker au vrai poste 23")
	check(named(chosen_name).has_focus(),"Affectation conserve focus candidat")
	var candidate_scroll:ScrollContainer=named("LineupCandidatesScroll")
	var bar:=candidate_scroll.get_v_scroll_bar()
	check(candidate_scroll.scroll_vertical==mini(list_before,int(bar.max_value-bar.page)) and app.body_scroll.scroll_vertical==outer_before,"Affectation conserve les scrolls dans leur plage valide")
	check(candidate_scroll.get_global_rect().encloses(named(chosen_name).get_global_rect()),"Candidat affecté reste entièrement visible")
	await command("export")
	var saved:String=app.model.meta.exportText
	for reset in ["import","new_career"]:
		var retiring:Control=named("CarnetLineup")
		var previous:Dictionary=app.management_ui.lineup
		previous.focus="LineupSlot23";previous.outer=999;previous.list=999
		await command(reset,{"text":saved} if reset=="import" else {"club":0,"mode":"common"})
		app._navigate("Composition");await settle()
		check(app.management_ui.lineup.outer==0 and app.management_ui.lineup.list==0 and app.management_ui.lineup.focus=="","Reset UI sans ancien dictionnaire "+reset)
		check(not is_instance_valid(retiring),"Ancienne vue libérée "+reset)
	# Both a not-started restoration and an awaiting one can retire safely.
	var detached:Control=load("res://ui/squad_views.gd").lineup(app)
	app.body.add_child(detached);detached._restore();app.body.remove_child(detached);detached._restore()
	await settle();detached.queue_free();await settle()
	for i in 3:app._render()
	await settle()
	check(named("CarnetLineup")!=null,"Rebuilds rapides sans restauration d'une vue retirée")
	# A genuinely unreadable disposable profile exercises the shared recovery reset.
	app.closing=true;app.bridge.stop()
	var stop_limit:=Time.get_ticks_msec()+5000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<stop_limit:await process_frame
	check(app.bridge.child_pid<=0,"Premier worker arrêté avant récupération")
	root.remove_child(app);app.queue_free();await settle()
	var broken:=FileAccess.open(disk,FileAccess.WRITE);broken.store_string("{profil-prive-illisible");broken.close()
	app=load("res://main.tscn").instantiate();root.add_child(app);await worker()
	app.management_ui.lineup={"outer":999,"list":999,"focus":"LineupSlot23"}
	await command("recover_profile",{"confirmed":true})
	check(not app.management_ui.has("lineup"),"Récupération réelle remet la mémoire Composition")
	var backup:=str(app.model.meta.get("recoveryBackup",""))
	check(FileAccess.file_exists(backup) and FileAccess.get_file_as_string(backup)=="{profil-prive-illisible","Récupération préserve le profil illisible privé")
	var file:=FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"geometry":measurements},"  "));file.close()
	app.closing=true;app.bridge.stop()
	print("Composition : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
