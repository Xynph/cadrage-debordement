extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
const Analysis = preload("res://ui/performance_analysis_view.gd")
const Club = preload("res://ui/immersive08/club_canvas.gd")
const Skin = preload("res://ui/game_skin.gd")
var app: Control
var nav: Node
var failures: Array[String] = []
var checks := 0
var requested := 0
var started := 0
var captures: Array[Dictionary] = []
var visits: Array[Dictionary] = []
var output := OS.get_environment("CD_ANALYSIS_CLUB_GRAPHICS_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> bool:
	var accepted: bool=app._command(id,payload)
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	var ok: bool=accepted and not app.waiting and app.bridge.last_response_ok
	check(ok,"Préparation publique · "+id+" · "+app.last_error)
	await settle(); return ok
func found(id: String) -> Node: return app.find_child(id,true,false)
func key(code: Key, alt: bool = false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.pressed=down; event.alt_pressed=alt
		root.push_input(event,true); await process_frame
	await settle()
func reveal(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await settle()
func activate(control: Control, pointer: bool = false) -> void:
	check(control!=null and control.is_visible_in_tree(),"Lien graphique réellement rendu")
	if control==null: return
	await reveal(control)
	control.grab_focus(); await settle()
	check(control.has_focus(),"Focus prêt · "+str(control.name))
	visits.append({"name":str(control.name),"kind":control.get_meta("entity_kind",""),"id":control.get_meta("entity_id",""),"activation":"mouse" if pointer else "Enter"})
	if not pointer: await key(KEY_ENTER); return
	var point:=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	root.push_input(move,true); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"Capture réelle aux dimensions 2560×1440")
	var file:=output.path_join(id+".png")
	check(image.save_png(file)==OK,"PNG obtenu · "+id)
	captures.append({"file":file,"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(file),"route":app.route})
func prepare_public_checkpoint() -> bool:
	if not await command("new_career",{"mode":"world-champ","club":29}): return false
	if not await Flow.settle_club_meetings(app,self,check): return false
	if not await Flow.prepare_match_day(app,self,check): return false
	await command("auto_lineup")
	await command("begin_match")
	await Flow.skip_talk(app,self,"pre",check)
	await command("delegate")
	if app.model.get("clubLife",{}).get("matchTalks",{}).get("scene") is Dictionary:
		await Flow.skip_talk(app,self,"post",check)
	elif app.model.get("live") is Dictionary: await command("finish_round")
	if not await Flow.settle_club_meetings(app,self,check): return false
	var completed_week: int=app.model.meta.week
	return await Flow.finish_match_week(app,self,check,completed_week)
func history_page() -> void:
	app.management_ui[Club.KEY]="history"
	app._navigate("Club"); await settle()
func overview_page() -> void:
	app.management_ui[Club.KEY]="overview"
	app._navigate("Club"); await settle()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(2560,1440); DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	check(not app.model.is_empty(),"Projection réelle reçue")
	if app.model.is_empty(): finish(); return
	app.timer.stop(); app.coach.speech.set_muted(true)
	app.coach.speech.requested.connect(func(_text: String): requested+=1)
	app.coach.speech.started.connect(func(_id: int): started+=1)
	nav=app.navigation_controller
	if OS.get_environment("CD_ANALYSIS_CLUB_GRAPHICS_COPIED")!="1":
		if not await prepare_public_checkpoint(): finish(); return
	else:
		check(app.model.get("club") is Dictionary,"Copie locale chargée sans créer une autre carrière")
		if not await Flow.settle_club_meetings(app,self,check): finish(); return
	app.coach.close()
	var expected:=OS.get_environment("CD_ANALYSIS_CLUB_GRAPHICS_EXPECTED_FIXTURE")
	var data: Dictionary=app.model.get("clubLife",{}).get("performanceAnalysis",{})
	var target: Dictionary={}
	var result: Dictionary={}
	for candidate: Dictionary in data.get("matches",[]):
		if not expected.is_empty() and str(candidate.get("fixtureId",""))!=expected: continue
		var available:=Analysis._match_target(app,candidate,data.get("clubId"))
		if not available.is_empty(): target=available; result=candidate; break
	check(not target.is_empty(),"Score collectif sûr disponible depuis une vraie rencontre archivée")
	if target.is_empty():
		printerr("UNAVAILABLE: aucune rencontre du checkpoint ne possède fixtureId/saison/équipes/score/phase concordants")
		finish(); return
	var archived: Array=app.model.get("history",[]).filter(func(item: Dictionary): return str(item.get("fixtureId",""))==str(target.id))
	check(archived.size()==1 and int(result.season)==int(app.model.meta.season),"Identifiant réellement archivé, unique et de la bonne saison")
	# Explicit setup boundary: never requested by a player, club or score link.
	var register: Dictionary=app.model.get("clubLife",{}).get("playerMatchHistory",{})
	if not register.get("enabled",false):
		check(register.get("canEnable",false),"Registre activable par décision explicite de préparation")
		if not register.get("canEnable",false): finish(); return
		if not await command("player_match_history_enable",{"context":register.context.duplicate(true),"confirmed":true}): finish(); return
	await command("export")
	var before: Dictionary=JSON.parse_string(app.model.meta.exportText).state
	var save_path:=str(app.model.meta.dataDir).path_join("donnees.json")
	var saved:=FileAccess.get_file_as_bytes(save_path)
	var requests: int=app.bridge._next_id
	await history_page()
	var score:=found("PerformanceMatchScore_"+str(target.id).validate_node_name()) as Button
	check(score!=null and str(score.get_meta("entity_id",""))==str(target.id),"Vrai score collectif rendu comme lien exact")
	if score==null: finish(); return
	await reveal(score); score.grab_focus(); await settle()
	var scroll:=found("ClubMemoryScroll") as ScrollContainer
	var source_scroll: int=scroll.scroll_vertical
	await capture("analyse-rencontre-reelle-2560")
	await activate(score)
	var detail:=found("CompetitionFixtureDetails") as Window
	check(detail!=null and detail.visible and str(detail.get_meta("entity_id",""))==str(target.id),"Score ouvre la fiche de sa vraie rencontre")
	await capture("fiche-rencontre-reelle-2560")
	await key(KEY_LEFT,true)
	check(is_instance_valid(score) and score.is_visible_in_tree() and score.has_focus() and scroll.scroll_vertical==source_scroll,"Retour exact au score source : même instance, focus et défilement")
	var opponent:=found("PerformanceOpponent_"+str(target.id).validate_node_name()) as Button
	await activate(opponent,true)
	var club:=found("CompetitionClubDetails") as Window
	check(club!=null and club.visible and str(club.get_meta("entity_id",""))==str(result.opponent),"Adversaire ouvre le club du résultat exact")
	check(club!=null and club.title==Skin.club_name(app.Immersive.Competition._target_club(app,str(result.opponent))),"Titre du club conforme à son identité publique")
	await key(KEY_LEFT,true)
	check(is_instance_valid(opponent) and opponent.has_focus(),"Retour exact au lien adversaire")
	var choice:=found("PerformancePlayerChoice") as OptionButton
	check(choice!=null and choice.item_count>1,"Sélecteur joueur réel disponible après préparation explicite")
	if choice!=null and choice.item_count>1:
		choice.select(1); choice.item_selected.emit(1); await settle()
		var player:=found("PerformancePlayerLink") as Button
		var player_id:=str(player.get_meta("entity_id"))
		await activate(player)
		check(app.route=="Effectif" and app.selected_player==player_id and app.get_meta("immersive08_full_player",false),"Sélection joueur puis fiche complète exacte")
		await key(KEY_LEFT,true)
		choice=found("PerformancePlayerChoice") as OptionButton
		check(choice!=null and choice.selected==1 and str(found("PerformancePlayerLink").get_meta("entity_id"))==player_id,"Retour conserve le joueur sélectionné")
	await overview_page()
	var staff:=app.find_children("ClubStaffName_*","Button",true,false)
	check(not staff.is_empty(),"Nom de staff réellement projeté sur Club")
	if not staff.is_empty():
		var staff_id:=str(staff[0].get_meta("entity_id"))
		await activate(staff[0])
		check(app.route=="Staff" and app.StaffViews.reading(app).navigation_id==staff_id,"Staff : bon profil par ID")
		await key(KEY_LEFT,true)
	for item: Array in [["ClubCashLink","cash"],["ClubWagesLink","wages"]]:
		await activate(found(item[0]) as Control)
		check(app.route=="Finances" and app.management_ui.immersive08_finance_tab==item[1],"Bon onglet financier · "+str(item[1]))
		await key(KEY_LEFT,true)
	check(app.bridge._next_id==requests and saved==FileAccess.get_file_as_bytes(save_path),"Liens graphiques sans commande ni écriture de sauvegarde")
	await command("export")
	check(before==JSON.parse_string(app.model.meta.exportText).state,"État sportif, registre, RNG inchangés après consultation")
	finish()
func finish() -> void:
	check(requested==0 and started==0 and (app==null or int(app.coach.speech._id)==0),"Silence : compteurs de parole à zéro")
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"visits":visits,"sha":OS.get_environment("CD_ANALYSIS_CLUB_GRAPHICS_SHA"),"expected_fixture":OS.get_environment("CD_ANALYSIS_CLUB_GRAPHICS_EXPECTED_FIXTURE")})); file.close()
	print("ANALYSIS CLUB GRAPHICS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
