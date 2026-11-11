extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
const Reading = preload("res://ui/management_state.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var speech_requests := 0
var speech_starts := 0
var captures: Array = []
var output := OS.get_environment("CD_MANAGEMENT_READING_FLOW_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> bool:
	var accepted: bool=app._command(id,payload)
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	var ok: bool=accepted and not app.waiting and app.bridge.last_response_ok
	check(ok,"Préparation par le vrai worker · "+id+" · "+app.last_error)
	await settle();return ok
func key(code: Key, alt: bool = false) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.pressed=down;event.alt_pressed=alt
		root.push_input(event,true);await process_frame
	await settle()
func activate(button: Button) -> void:
	check(button!=null and button.is_visible_in_tree() and not button.disabled,"Contrôle de consultation rendu")
	if button==null:return
	if button.name=="RelationshipCommitmentPlayerLink":trace_relations_scroll("before-focus-commitment")
	button.grab_focus();await settle()
	if button.name=="RelationshipCommitmentPlayerLink":trace_relations_scroll("after-focus-before-enter")
	check(button.has_focus() and button.focus_mode==Control.FOCUS_ALL,"Focus clavier du lien visible")
	await key(KEY_ENTER)
func back() -> void:
	app.get_viewport().gui_release_focus()
	await key(KEY_LEFT,true)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	check(picture.get_size()==Vector2i(2560,1440),"Vrais pixels 2560×1440 · "+name)
	var file:=output.path_join(name+".png")
	check(picture.save_png(file)==OK,"Capture réelle · "+name)
	captures.append({"file":file,"sha256":FileAccess.get_sha256(file)})
func trace_relations_scroll(boundary: String) -> void:
	var page:=app.find_child("CarnetRelations",true,false) as Control
	var focus:=app.get_viewport().gui_get_focus_owner()
	var scrolls: Array=[]
	if page!=null:
		for surface: ScrollContainer in page.find_children("*","ScrollContainer",true,false):
			scrolls.append({"name":str(surface.name),"path":str(app.root_content.get_path_to(surface)),"y":surface.scroll_vertical,"max":surface.get_v_scroll_bar().max_value,"page":surface.get_v_scroll_bar().page,"contains_focus":focus!=null and surface.is_ancestor_of(focus)})
	print("MANAGEMENT_SCROLL ",JSON.stringify({"boundary":boundary,"route":app.route,"focus":str(focus.name) if focus!=null else "","scrolls":scrolls}))
func trace_stored_scrolls() -> void:
	var nav: Node=app.navigation_controller
	if nav.cursor<0:return
	for address: Dictionary in nav.history[nav.cursor].get("reading",{}).get("scrolls",[]):
		var candidate: Node=app.root_content
		for index: int in address.get("path",[]):
			if candidate==null or index<0 or index>=candidate.get_child_count():candidate=null;break
			candidate=candidate.get_child(index)
		var resolved:=Reading._reading_control(app.root_content,address,"ScrollContainer") as ScrollContainer
		print("MANAGEMENT_STORED_SCROLL ",JSON.stringify({"stored_name":address.get("name",""),"stored_y":address.get("y",-1),"indices":address.get("path",[]),"candidate_name":str(candidate.name) if candidate!=null else "","candidate_class":candidate.get_class() if candidate!=null else "","resolved":resolved!=null,"actual_y":resolved.scroll_vertical if resolved!=null else -1}))
func trace_location(boundary: String) -> void:
	var window_size: Vector2i=app.get_window().size
	var viewport_size: Vector2=app.get_viewport_rect().size
	var trace: Dictionary={"boundary":boundary,"route":app.route,"last_command":app.last_command,"waiting":app.waiting,"last_error":app.last_error,"window_size":[window_size.x,window_size.y],"viewport_size":[viewport_size.x,viewport_size.y],"locker_tab":app.management_ui.get("immersive08_locker_tab","week"),"has_locker_canvas":app.find_child("ImmersiveLockerRoom",true,false)!=null,"has_relations_page":app.find_child("CarnetRelations",true,false)!=null,"contextual_kind":app.contextual_director.kind,"mandatory_meeting":app.contextual_director.active_meeting(),"match_immersed":app.contextual_director.match_immersed()}
	print("MANAGEMENT_LOCATION ",JSON.stringify(trace))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	app.coach.speech.requested.connect(func(_text: String):speech_requests+=1)
	app.coach.speech.started.connect(func(_id: int):speech_starts+=1)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until:await process_frame
	app.timer.stop();check(not app.model.is_empty(),"Vrai client connecté au worker")
	if app.model.is_empty():await finish();return
	if not await command("new_career",{"mode":"fiction","club":13}):await finish();return
	await Flow.settle_club_meetings(app,self,check)
	var event: Dictionary=app.model.clubLife.relationships.event
	var player_id:=str(event.playerId)
	var context: Dictionary=app.model.clubLife.relationships.context
	if not await command("relationship_conversation",{"context":context,"playerId":player_id,"choice":"rassurer"}):await finish();return
	if not await command("locker_room_decision",{"context":context,"eventKey":event.key,"choice":"responsabiliser"}):await finish();return
	for index in 8:
		if not await command("set_player_load",{"playerId":player_id,"mode":"repos" if index%2==0 else "normal"}):await finish();return
	app.management_ui.relationships={"playerId":player_id}
	app.management_ui.preparation={"tab":0,"outer":[0,0,0],"attack":1,"defense":2,"focus":["","",""]}
	trace_location("before-navigate-vestiaire")
	app._navigate("Vestiaire");await settle()
	trace_location("after-navigate-vestiaire")
	var locker:=app.find_child("ImmersiveLockerRoom",true,false) as Control
	check(app.route=="Vestiaire" and locker!=null,"La route Vestiaire affiche sa composition immersive réelle")
	check(app.management_ui.get("immersive08_locker_tab","week")=="week" and app.find_child("CarnetRelations",true,false)==null,"Ouverture réelle sur Cette semaine, avant la sélection du détail")
	var people_tab:=locker.find_child("LockerTab_people",true,false) as Button if locker!=null else null
	await activate(people_tab)
	trace_location("after-activate-locker-people")
	check(app.route=="Vestiaire" and app.management_ui.get("immersive08_locker_tab","")=="people" and app.find_child("CarnetRelations",true,false)!=null,"Entrée clavier sur Entretiens et duos ouvre le détail sans changer de route")
	await command("export")
	trace_location("after-export-on-vestiaire")
	var before: Dictionary=JSON.parse_string(app.model.meta.exportText).state
	var profile:=str(app.model.meta.dataDir).path_join("donnees.json")
	var profile_hash:=FileAccess.get_sha256(profile)
	var stored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile))
	var seed: int=stored.seed
	var clock: Variant=stored.clock
	var requests: int=app.bridge._next_id
	var draft: Dictionary=app.management_ui.preparation.duplicate(true)
	var receipt_before: Array=app.decision_feedback.receipts()
	var page:=app.find_child("CarnetRelations",true,false) as Control
	check(page!=null,"Le détail réel du vestiaire reste affiché après export")
	if page==null:
		await capture("vestiaire-page-manquante-2560")
		await finish();return
	var surfaces:=page.find_children("*","ScrollContainer",true,false)
	check(surfaces.size()>=2,"Deux listes de vestiaire contenues")
	if surfaces.size()<2:await finish();return
	check(surfaces[0].name=="RelationshipFollowScroll" and surfaces[1].name=="RelationshipPeopleScroll","Les deux colonnes de lecture ont des identifiants stables distincts")
	var right:=page.find_child("RelationshipPeopleScroll",true,false) as ScrollContainer
	if right==null:await finish();return
	right.scroll_vertical=mini(90,int(right.get_v_scroll_bar().max_value-right.get_v_scroll_bar().page));await settle()
	var expected_scroll:=right.scroll_vertical
	trace_relations_scroll("after-setting-right-scroll")
	check(expected_scroll>0,"Position de lecture non nulle réellement préparée")
	var commitment:=page.find_child("RelationshipCommitmentPlayerLink",true,false) as Button
	check(commitment!=null and commitment.get_meta("entity_id","")==player_id,"L’engagement porte l’ID du vrai personnage")
	await activate(commitment)
	check(app.route=="Effectif" and app.selected_player==player_id and app.get_meta("immersive08_full_player",false),"Engagement → fiche complète exacte")
	await back()
	check(app.route=="Vestiaire" and app.management_ui.relationships.playerId==player_id,"Retour au joueur sélectionné du vestiaire")
	trace_relations_scroll("after-back-to-relations")
	trace_stored_scrolls()
	page=app.find_child("CarnetRelations",true,false) as Control
	if page!=null:
		surfaces=page.find_children("*","ScrollContainer",true,false)
		var returned_right:=page.find_child("RelationshipPeopleScroll",true,false) as ScrollContainer
		check(returned_right!=null and abs(returned_right.scroll_vertical-expected_scroll)<=1,"Retour conserve le scroll de l’autre liste")
	check(app.management_ui.preparation==draft,"Brouillon de préparation conservé par la consultation")
	await capture("vestiaire-retour-fiche-2560")
	await activate(app.find_child("DecisionFeedbackButton",true,false) as Button)
	var dialog:=app.get_node_or_null("DecisionFeedbackDialog") as AcceptDialog
	check(dialog!=null and dialog.get_meta("navigation_read_only",false),"Historique réel ouvert en lecture seule")
	if dialog==null:await finish();return
	var links: Array=dialog.find_children("*","Button",true,false).filter(func(button):return button.get_meta("entity_kind","")=="player")
	check(links.size()==10,"Dix reçus réels ont leurs dix liens précis")
	if links.is_empty():await finish();return
	var source_id:=dialog.get_instance_id()
	var scroll:=dialog.get_node("DecisionFeedbackScroll") as ScrollContainer
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page);await settle()
	var link:=links.back() as Button
	link.grab_focus();await settle()
	var dialog_scroll:=scroll.scroll_vertical
	check(dialog_scroll>0 and link.has_focus(),"Ancien reçu atteint au clavier et scroll non nul")
	await key(KEY_ENTER)
	check(app.route=="Effectif" and app.selected_player==player_id,"Reçu → même fiche joueur par son ID enregistré")
	check(is_instance_valid(dialog) and not dialog.visible,"Fenêtre source conservée cachée par le contrôleur commun")
	await back()
	var returned:=app.get_node_or_null("DecisionFeedbackDialog") as AcceptDialog
	check(returned!=null and returned.get_instance_id()==source_id and returned.visible,"Back restitue exactement la même fenêtre de reçus")
	if returned!=null:
		check((returned.get_node("DecisionFeedbackScroll") as ScrollContainer).scroll_vertical==dialog_scroll,"Scroll du reçu restitué sans recalcul de mémoire")
		check(is_instance_valid(link) and link.has_focus(),"Focus rendu au lien de reçu d’origine")
		await capture("decisions-retour-fiche-2560")
		returned.get_ok_button().pressed.emit();await settle()
	check(app.decision_feedback.receipts()==receipt_before,"Reçus, citations, coûts et conséquences strictement inchangés")
	check(app.bridge._next_id==requests,"Aucune commande worker déclenchée par les liens ou leurs retours")
	check(FileAccess.get_sha256(profile)==profile_hash,"Profil sportif/RNG/horloge inchangé octet pour octet")
	await command("export")
	check(JSON.parse_string(app.model.meta.exportText).state==before,"État sportif réellement exporté identique après consultation")
	stored=JSON.parse_string(FileAccess.get_file_as_string(profile))
	check(stored.seed==seed and stored.clock==clock and FileAccess.get_sha256(profile)==profile_hash,"Export de contrôle sans RNG ni écriture")
	check(speech_requests==0 and speech_starts==0,"Compteurs Gabi : aucune demande ni démarrage de parole")
	await finish()
func finish() -> void:
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"speech_requests":speech_requests,"speech_starts":speech_starts,"scope":"Real game client/worker; requires common read-only window suspension before running."}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	if is_instance_valid(app):app.bridge.stop();app.queue_free();await settle()
	print("MANAGEMENT READING FLOW : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
