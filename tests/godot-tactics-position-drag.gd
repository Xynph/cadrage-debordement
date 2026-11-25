extends SceneTree
const Rooms = preload("res://qa_runner.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_TACTICS_DRAG_OUTPUT")
var Selection = load("res://ui/immersive08/tactics_selection.gd")
var Notation = load("res://ui/notation_staff.gd")
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle() -> void:
	for frame in 10:await process_frame
func worker() -> void:
	if OS.get_environment("CD_TACTICS_DRAG_TRACE")=="1":print("TACTICS_COMMAND ",Time.get_ticks_msec()," ",app.last_command," checks=",checks)
	var deadline := Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline:await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Commande réelle : "+str(app.last_error))
func named(id: String) -> Control:return app.root_content.find_child(id,true,false)
func enter(control: Control) -> void:
	control.grab_focus();await settle()
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down
		Input.parse_input_event(event);await process_frame
	await worker()
func assignment(index: int) -> Dictionary:return Selection.slot(app.model,index)
func motion(point: Vector2,relative: Vector2=Vector2.ZERO,held: bool=false) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative
	if held:event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true);await process_frame
func mouse(point: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	root.push_input(event,true);await process_frame
func drag(from: Control,to: Control,cancel: bool=false) -> void:
	var start:=from.get_global_rect().get_center();var target:=to.get_global_rect().get_center()
	await motion(start);await mouse(start,true)
	await motion(start+Vector2(30,0),Vector2(30,0),true);await settle()
	check(root.gui_is_dragging(),"Vrai glisser souris démarré")
	await motion(target,target-start-Vector2(30,0),true);await settle()
	if cancel:
		var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await process_frame
		await mouse(target,false);await settle()
	else:
		await mouse(target,false);await worker()
	check(not root.gui_is_dragging(),"Glisser terminé")
func labels(node: Node) -> Array[String]:
	var result:Array[String]=[]
	if node==null:return result
	for label:Label in node.find_children("*","Label",true,false):result.append(label.text)
	return result
## Note au poste montrée en LETTRE (décision de Léo du 24/11/2026) : méta « lettre » = lettre du staff, écrite dans la
## pastille, et aucun chiffre dans la valeur au poste.
func lettre_montree(node: Node,lettre: Dictionary) -> bool:
	if node==null:return false
	var attendu:String=Notation.texte_note(lettre)
	var pastille:=node.find_child("Pastille",true,false)
	var ecrit:="".join(labels(pastille))
	var sans_chiffre:=true
	for label:Label in node.find_children("*","Label",true,false):
		if label.name=="MarqueMot":continue
		for c in label.text:if c>="0" and c<="9":sans_chiffre=false
	return str(node.get_meta("lettre",""))==attendu and attendu!="?" and ecrit!="" and sans_chiffre and ecrit.begins_with(attendu.split("/")[0])
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(id+".png"))==OK,"Capture "+id)
func partition() -> void:
	var seen:Array=[]
	for i in 23:
		var id:Variant=assignment(i).get("playerId")
		if id!=null:
			check(id not in seen,"ID unique sur feuille "+str(id));seen.append(id)
	var expected:Array=[]
	for person:Dictionary in app.model.squad:
		if str(person.id) not in seen:expected.append(str(person.id))
	expected.sort()
	if named("TacticsOutsideTiles")!=null:
		var outside:Array=[]
		for button in named("TacticsOutsideTiles").get_children():
			if button is Button:outside.append(button.get_meta("player_id"))
		outside.sort()
		check(outside==expected,"Partition exacte XV / Banc / Hors groupe")
	check(named("BenchPlayerRows").get_child_count()==8,"Huit places légales du banc conservées")
func bottom(tab: String) -> void:
	var pill:=named("TacticsBottomOutside" if tab=="hors" else "TacticsBottomCandidates") as Button
	check(pill!=null,"Pilule du bas "+tab)
	if pill!=null:pill.pressed.emit();await settle()
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	var deadline := Time.get_ticks_msec()+45000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.model.is_empty(),"Application prête")
	app.timer.stop();app._command("new_career",{"mode":"common","club":0});await worker()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	app._navigate("Composition");await settle();app.coach.close()
	check(named("TacticsPitch")!=null and named("TacticsBench")!=null and named("TacticsCandidates")!=null,"Terrain vertical, banc en tuiles et candidats présents")
	check(named("TacticsOutside")==null and named("TacticsIdentity")==null and named("TacticsSelectedPlayer")==null and named("TacticsRosterTab")==null,"Plus d'ancienne mise en page (colonnes, identité, carte sélectionnée)")
	check(named("TacticsBottomCandidates")!=null and named("TacticsBottomOutside")!=null and named("TacticsHorsGroupe")==null,"Pilules Candidats / Hors groupe : candidats d'abord")
	check(named("TacticsPitch").get_global_rect().end.x<=named("TacticsBench").get_global_rect().position.x+1 and named("TacticsCandidates").get_global_rect().position.y>=named("TacticsBench").get_global_rect().end.y-1,"Terrain à gauche, banc à droite, candidats sous le banc")
	partition()
	for i in 15:
		var portrait:=named("TacticsFace%02d" % (i+1))
		var photo:=portrait.find_children("*","TextureRect",true,false).filter(func(node):return node.texture!=null) if portrait!=null else []
		check(portrait!=null and not photo.is_empty(),"Portrait chargé au poste "+str(i+1))
		var person:Dictionary=Selection.player(app.model,str(assignment(i).get("playerId","")))
		check(Selection.rating(app.model,person,i)!=null,"Projection moteur présente au poste "+str(i+1))
		check(lettre_montree(named("TacticsPositionRating%02d" % (i+1)),Selection.lettre(app.model,person,i)),"Note projetée au poste en lettre, sans chiffre "+str(i+1)+" "+str(labels(named("TacticsPositionRating%02d" % (i+1)))))
		var card:=named("TacticsCardPlate%02d" % (i+1))
		for j in range(i+1,15):check(not card.get_global_rect().intersects(named("TacticsCardPlate%02d" % (j+1)).get_global_rect()),"Plaques de nom distinctes %d/%d" % [i+1,j+1])
	var pillar_id:=str(assignment(0).get("playerId"))
	var pillar:Dictionary=Selection.player(app.model,pillar_id)
	var own_note:Variant=Selection.rating(app.model,pillar,0);var wrong_note:Variant=Selection.rating(app.model,pillar,9)
	check(own_note!=null and wrong_note!=null and float(own_note)-float(wrong_note)>=35,"Pilier au n°10 : forte chute issue du moteur")
	check(Selection.rating(app.model,{"note":99},9)==null,"Note principale jamais substituée à une projection manquante")
	check(Selection.rating(app.model,{"positionRatings":{"10":0}},9)==0,"Aptitude nulle conservée")
	check(Selection.rating(app.model,{"positionRatings":{"10":"88"}},9)==null,"Donnée de note invalide signalée absente")
	check(Selection.number(app.model,22)==11,"Aptitude du banc23 issue de la projection canonique")
	var profile:=str(app.model.meta.dataDir).path_join("donnees.json")
	var before:=FileAccess.get_sha256(profile)
	await enter(named("LineupSlot10"))
	check(app.selected_slot==9 and (named("TacticsCandidatesTitle") as Label).text.contains("N° 10"),"Clavier choisit cible10 et ses candidats")
	check(named("LineupSlot10").has_focus(),"Focus conservé sur cible10")
	check(FileAccess.get_sha256(profile)==before,"Consultation des postes ne modifie pas le profil")
	await capture("tactique-portraits-horsgroupe-1440")
	if OS.get_environment("CD_TACTICS_DRAG_PREVIEW")=="1":finish();return
	var from:=named("LineupSlot11");var to:=named("LineupSlot14")
	var source_id:=str(assignment(10).playerId);var displaced:=str(assignment(13).playerId)
	var payload:Variant=Selection.payload(app,source_id,10)
	check(to._can_drop_data(Vector2.ZERO,payload),"Dépôt ailier11 vers14 autorisé par le moteur")
	check(not to._can_drop_data(Vector2.ZERO,{"kind":"foreign"}),"Dépôt étranger refusé")
	var unknown:Dictionary=payload.duplicate();unknown.player_id="unknown"
	check(not to._can_drop_data(Vector2.ZERO,unknown),"ID inconnu refusé")
	var foreign:Dictionary=payload.duplicate();foreign.club_id="foreign"
	check(not to._can_drop_data(Vector2.ZERO,foreign),"Source d’un autre club refusée")
	check(not named("LineupSlot01")._can_drop_data(Vector2.ZERO,payload),"Arrière vers première ligne refusé malgré une note chiffrée")
	await drag(from,to,true)
	check(FileAccess.get_sha256(profile)==before and str(assignment(10).playerId)==source_id,"Annulation réelle : profil et sélection inchangés")
	await drag(named("LineupSlot11"),named("LineupSlot14"))
	check(str(assignment(13).playerId)==source_id and str(assignment(10).playerId)==displaced,"Vrai dépôt : échange atomique des deux ailiers")
	check(not Selection.can_drop(app,payload,13),"Source périmée refusée après déplacement")
	partition()
	var bench_id:=str(assignment(20).playerId);var field_id:=str(assignment(8).playerId)
	await drag(named("LineupSlot21"),named("LineupSlot09"))
	check(str(assignment(8).playerId)==bench_id and str(assignment(20).playerId)==field_id,"Banc21 vers terrain9 : échange réel sans doublon")
	partition()
	app.selected_slot=9;await bottom("hors")
	check(named("TacticsHorsGroupe")!=null and named("TacticsOutsideTiles")!=null,"Onglet Hors groupe : tuiles des joueurs hors feuille")
	partition()
	var candidate:Control
	for row in named("TacticsOutsideTiles").get_children():
		if row is Button and Selection.eligible(app,str(row.get_meta("player_id","")),9):candidate=row;break
	check(candidate!=null,"Candidat hors groupe éligible à la cible10")
	if candidate!=null:
		var incoming:=str(candidate.get_meta("player_id"));var outgoing:=str(assignment(9).playerId)
		await enter(candidate)
		check(str(assignment(9).playerId)==incoming,"Clic/clavier hors groupe affecte au numéro actif")
		check(Selection.source(app.model,outgoing)==-1 and named("TacticsOutside_"+outgoing.validate_node_name())!=null,"Joueur délogé rejoint Hors groupe")
		partition()
		check(named("TacticsOutside_"+incoming.validate_node_name())==null,"Joueur affecté quitte Hors groupe")
	var scroll:=named("TacticsOutsideScroll") as ScrollContainer
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
	var last:Control=named("TacticsOutsideTiles").get_children().back()
	check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()),"Dernier joueur Hors groupe accessible sans pagination")
	await capture("tactique-affectation-horsgroupe-1440")
	# Source hors feuille, déposée avec de vrais événements sur le terrain.
	app.selected_slot=9;app._render();await settle()
	var outside_source:Control
	for row in named("TacticsOutsideTiles").get_children():
		if row is Button and Selection.eligible(app,str(row.get_meta("player_id","")),9):outside_source=row;break
	if outside_source!=null:
		var outside_id:=str(outside_source.get_meta("player_id"))
		(named("TacticsOutsideScroll") as ScrollContainer).ensure_control_visible(outside_source);await settle()
		await drag(outside_source,named("LineupSlot10"))
		check(str(assignment(9).playerId)==outside_id,"Hors groupe vers terrain10 : vrai dépôt affecté")
		partition()
	# Terrain vers Hors groupe : la place se libère, le joueur rejoint les tuiles.
	var released:=str(assignment(10).playerId)
	await drag(named("LineupSlot11"),named("TacticsHorsGroupe"))
	check(assignment(10).playerId==null and Selection.source(app.model,released)==-1,"Terrain11 vers Hors groupe : place libérée")
	check(named("TacticsOutside_"+released.validate_node_name())!=null,"Joueur libéré visible dans Hors groupe")
	partition()
	var back:=named("TacticsOutside_"+released.validate_node_name())
	(named("TacticsOutsideScroll") as ScrollContainer).ensure_control_visible(back);await settle()
	await drag(back,named("LineupSlot11"))
	check(str(assignment(10).playerId)==released,"Hors groupe vers terrain11 : retour réel")
	await bottom("candidats")
	var current_id:=str(assignment(9).playerId)
	var valid_payload:Variant=Selection.payload(app,current_id,9)
	app._command("save")
	check(app.waiting and not Selection.can_drop(app,valid_payload,8) and Selection.payload(app,current_id,9)==null,"Commande réellement en attente verrouille le déplacement")
	await worker()
	var consultation_hash:=FileAccess.get_sha256(profile)
	await enter(named("LineupSlot10"))
	var rows:=named("TacticsCandidateRows")
	check(rows!=null and rows.get_child_count()>0,"Liste des candidats du poste actif accessible au clavier")
	if rows!=null:
		for row in rows.get_children():
			var id:=str(row.get_meta("player_id",""))
			var status:=row.find_child("TacticsCandidateStatus",true,false) as Label
			if status!=null and status.text=="Non qualifié au poste":check(not Selection.eligible(app,id,9),"Non qualifié = refusé par le moteur "+id)
	check(FileAccess.get_sha256(profile)==consultation_hash,"Consultation des candidats ne modifie pas le profil")
	var pillar_ready:bool=Selection.eligible(app,pillar_id,9)
	check(pillar_ready,"Le moteur autorise le pilier au n°10 avec son aptitude de dépannage")
	if pillar_ready:
		var displaced_id:=str(assignment(9).playerId)
		var swap_back:bool=displaced_id in assignment(0).get("eligibleIds",[])
		await drag(named("LineupSlot01"),named("LineupSlot10"))
		check(str(assignment(9).playerId)==pillar_id,"Pilier1 vers10 : affectation réelle")
		if swap_back:check(str(assignment(0).playerId)==displaced_id,"Déplacé qualifié au n°1 : échange réel")
		else:check(assignment(0).playerId==null,"Déplacé non qualifié au n°1 : source libérée")
		var lettre_10:Dictionary=Selection.lettre(app.model,Selection.player(app.model,pillar_id),9)
		check(lettre_montree(named("TacticsPositionRating10"),lettre_10),"La carte10 affiche la faible note réelle du pilier en lettre "+str(labels(named("TacticsPositionRating10"))))
		check(Notation.rang_lettre(lettre_10)<Notation.rang_lettre(Notation.lettre_poste(app.model,Selection.player(app.model,pillar_id),1,true)),"Lettre du pilier au n°10 sous celle de son poste")
		check(Selection.player(app.model,pillar_id).get("note")==pillar.get("note"),"Note principale du joueur inchangée après déplacement")
		if not swap_back:check(app.model.meta.get("lineupChange",{}).get("vacatedSlot")==0,"Reçu moteur explicite la place source laissée vacante")
		partition()
		await capture("tactique-pilier-au10-1440")
	# Le mode hebdomadaire fictif permet un vrai coup d'envoi sans avancer le calendrier commun.
	app._command("new_career",{"mode":"fiction","club":0});await worker()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var press:Dictionary=app.model.get("clubLife",{}).get("press",{})
	var conference:Dictionary=press.get("conference",{})
	if conference.get("available",false):
		var answers:Array=[]
		for question:Dictionary in conference.get("questions",[]):answers.append({"questionId":question.id,"answerId":question.answers[0].id})
		app._command("press_conference",{"context":press.get("context"),"invitationId":conference.get("invitationId"),"answers":answers});await worker()
	app._command("begin_match");await worker()
	if not await Rooms.continue_match_phase(app,self,check,"pre"):await app._close(1);return
	app._navigate("Composition");await settle()
	check(not app._live().is_empty(),"Vrai match lancé pour vérifier le verrouillage")
	check(app.route=="Match" and app.contextual_director.match_immersed(),"La scène immersive garde le direct lorsqu’on tente de revenir à Composition")
	var live_id:=str(assignment(10).playerId)
	var locked_payload:={"kind":"tactics_player","player_id":live_id,"source_slot":10,"club_id":app.model.club.id}
	check(Selection.payload(app,live_id,10)==null and not Selection.can_drop(app,locked_payload,13),"Glisser-déposer indisponible pendant le match")
	check(not Selection.editable(app) and not Selection.apply(app,locked_payload,13),"Affectation de composition indisponible pendant le match")
	var live_profile:=str(app.model.meta.dataDir).path_join("donnees.json")
	var live_hash:=FileAccess.get_sha256(live_profile)
	var live_selection:Dictionary=app.model.selection.duplicate(true)
	app._command("set_lineup",{"slot":13,"playerId":live_id})
	var refusal_deadline:=Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<refusal_deadline:await process_frame
	await settle()
	check(not app.waiting and not app.bridge.last_response_ok,"Le moteur refuse aussi une commande directe de composition pendant le match")
	check(app.model.selection==live_selection and FileAccess.get_sha256(live_profile)==live_hash,"Refus pendant le direct : feuille et sauvegarde inchangées")

	finish()
func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	app.closing=true;app.bridge.stop()
	print("TACTIQUE : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
