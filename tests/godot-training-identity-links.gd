extends SceneTree
const C = preload("res://ui/immersive08/components.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var requested := 0
var started := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande de préparation acceptée · "+id)
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel · "+id)
	await settle()
func found(id: String) -> Control: return app.find_child(id,true,false) as Control
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
		Input.parse_input_event(event); await process_frame
	await settle()
func adjustment_click(control: Control, local_design_point: Vector2) -> void:
	# Dedicated pages are scaled by the shell. An untransformed offset added
	# to global_position can land on the identity zone instead of this label.
	var point := control.get_global_transform_with_canvas() * (local_design_point * C.density)
	check(Rect2(Vector2.ZERO,control.size).has_point(local_design_point*C.density),"Point de réglage dans la carte rendue")
	for child: Node in control.get_children():
		var identity := child as Control
		if identity == null or not identity.has_meta("entity_kind"): continue
		var child_point: Vector2 = identity.get_global_transform_with_canvas().affine_inverse() * point
		check(not Rect2(Vector2.ZERO,identity.size).has_point(child_point),"Clic de réglage hors zone d’identité · "+str(identity.name))
	await click(point)

func activate(link: Control, keyboard: bool) -> void:
	check(link!=null,"Zone identité présente")
	if link==null: return
	if not keyboard:
		await click(link.get_global_rect().get_center()); return
	link.grab_focus(); await settle()
	check(link.has_focus(),"Focus visible sur le lien d’identité")
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=down
		Input.parse_input_event(event); await process_frame
	await settle()
func profile(id: String) -> void:
	check(app.route=="Effectif" and app.selected_player==id and app.get_meta("immersive08_full_player",false),"Fiche complète du bon joueur par ID")
	check(found("TrainingIndividualDialog")==null,"L’identité ne déclenche pas le réglage de charge")
func back() -> void:
	app.navigation_controller._travel(-1); await settle()
	check(found("ImmersiveTraining")!=null and int(app.management_ui.get("immersive_training",{}).get("tab",0))==0,"Retour sur la semaine d’entraînement")
func vigilance_component(player: Dictionary) -> Control:
	# Component fixture: retain a real projected player, without manufacturing
	# an alert, changing his condition or writing any worker/model state.
	var page:=found("ImmersiveTraining")
	var risk:=found("TrainingRisk")
	if risk!=null: risk.get_parent().remove_child(risk); risk.queue_free()
	page.watched=[player]
	page._vigilance()
	return found("TrainingRiskPlayer_"+str(player.id).validate_node_name())
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.requested.connect(func(_text: String): requested+=1)
	app.coach.speech.started.connect(func(_id: int): started+=1)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.model.is_empty(),"Projection initiale reçue")
	await command("new_career",{"mode":"common","club":29})
	await ContextualFlow.settle_club_meetings(app,self,check)
	app.coach.close()
	await command("export")
	var before: Dictionary=JSON.parse_string(app.model.meta.exportText).state
	var saved_path:=str(app.model.meta.dataDir).path_join("donnees.json")
	var saved:=FileAccess.get_file_as_bytes(saved_path)
	var requests: int=app.bridge._next_id
	app.Immersive.open_training(app); await settle()
	var names:=app.find_children("TrainingAxisPlayerName_*","Button",true,false)
	check(not names.is_empty(),"Professionnels réels présentés dans les axes individuels")
	if names.is_empty(): finish(); return
	var axis_name:=str(names[0].name)
	var player_id:=str(names[0].get_meta("entity_id"))
	await activate(names[0],true); profile(player_id); await back()
	await activate(found("TrainingAxisPlayerPortrait_"+player_id.validate_node_name()),false); profile(player_id); await back()
	var axis:=found("TrainingAxis0")
	await adjustment_click(axis,Vector2(170,62))
	check(found("TrainingIndividualDialog")!=null,"La zone d’axe hors identité conserve le vrai réglage")
	app._clear_dialogs(); await settle()
	var staff_names:=app.find_children("TrainingStaffName_TrainingStaff_*","Button",true,false)
	check(not staff_names.is_empty(),"Personne réelle du staff disponible par ID projeté")
	if not staff_names.is_empty():
		var staff_id:=str(staff_names[0].get_meta("entity_id"))
		await activate(staff_names[0],true)
		check(app.route=="Staff" and app.StaffViews.reading(app).navigation_id==staff_id,"Profil exact du staff depuis son nom")
		await back()
		await activate(found("TrainingStaffPortrait_TrainingStaff_"+staff_id.validate_node_name()),false)
		check(app.route=="Staff" and app.StaffViews.reading(app).navigation_id==staff_id,"Profil exact du staff depuis son portrait")
		await back()
	var page:=found("ImmersiveTraining")
	var count:=page.get_child_count()
	check(page._person_link(page,Rect2(0,0,20,20),"staff",{},"TrainingNoPerson")==null and page.get_child_count()==count,"Placeholder médical sans personne : aucune cible ni bouton créé")
	check(page._person_link(page,Rect2(0,0,20,20),"staff",{"id":"absent"},"TrainingAbsentPerson")==null,"Personne absente refusée sans homonyme")
	var player: Dictionary=app.model.squad[0]
	await activate(vigilance_component(player),true); profile(str(player.id)); await back()
	vigilance_component(player)
	var risk:=found("TrainingRisk_0")
	await adjustment_click(risk,Vector2(420,20))
	check(found("TrainingIndividualDialog")!=null,"La zone de vigilance hors nom conserve le réglage")
	app._clear_dialogs(); await settle()
	check(app.bridge._next_id==requests and saved==FileAccess.get_file_as_bytes(saved_path),"Consultation et ouverture des réglages sans commande ni écriture sportive")
	await command("export")
	check(before==JSON.parse_string(app.model.meta.exportText).state,"État sportif et RNG inchangés")
	check(requested==0 and started==0 and int(app.coach.speech._id)==0,"Gabi silencieuse : compteurs de demande et départ à zéro")
	finish()
func finish() -> void:
	print("TRAINING IDENTITY LINKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
