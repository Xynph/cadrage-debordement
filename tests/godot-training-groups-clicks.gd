extends SceneTree
const C = preload("res://ui/immersive08/components.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
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
func click_control(control: Control) -> void:
	check(control!=null and control.is_visible_in_tree(),"Élément présent et visible")
	if control!=null: await click(control.get_global_rect().get_center())
func page() -> Control: return found("ImmersiveTraining")
func groups_tab() -> void:
	page()._open_tab(1); await settle()
func tab() -> int: return int(app.management_ui.get("immersive_training",{}).get("tab",-1))
func close_panel() -> void:
	var close:=found("TrainingGroupClose")
	if close!=null: await click_control(close)
	check(found("TrainingGroupPanel")==null,"Panneau fermé")
func expect_panel(label: String, expected: int) -> void:
	var panel:=found("TrainingGroupPanel")
	check(panel!=null,"Panneau de joueurs ouvert · "+label)
	if panel==null: return
	var names:=panel.find_children("TrainingGroupName_*","Button",true,false)
	check(names.size()==expected,"%s : %d joueur(s) attendus, %d affichés" % [label,expected,names.size()])
	if not names.is_empty():
		var id:=str(names[0].get_meta("entity_id"))
		await click_control(names[0])
		check(app.route=="Effectif" and app.selected_player==id,"%s : un nom ouvre la fiche du joueur" % label)
		app.navigation_controller._travel(-1); await settle()
		await groups_tab()
		await close_panel()
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await command("new_career",{"mode":"world-champ","club":29})
	await ContextualFlow.settle_club_meetings(app,self,check)
	app.coach.close()
	app.Immersive.open_training(app); await settle()
	await groups_tab()
	# Tuiles du haut : condition, charge, à surveiller -> Fatigue ; moral -> Vestiaire.
	for i in [0,2,3]:
		await click_control(found("TrainingMetric"+str(i)))
		check(tab()==4,"Tuile %d -> onglet Fatigue" % i)
		await groups_tab()
	await click_control(found("TrainingMetric1"))
	check(app.route=="Vestiaire","Tuile Moral -> Vestiaire")
	app.navigation_controller._travel(-1); await settle(); await groups_tab()
	# Plans : chaque part non vide (ligne de légende et anneau) ouvre ses joueurs.
	var plans: Array = app.model.clubLife.clubSupport.training.plans
	check(not plans.is_empty(),"Plans de travail présents")
	for plan: Dictionary in plans:
		var key:=str(plan.key)
		var modes:=[["repos"],["normal","collective"],["intense"]]
		for k in 3:
			var expected:=0
			for row: Dictionary in plan.players:
				if str(row.plan) in modes[k]: expected+=1
			var row_button:=found("TrainingPlanPart_%s_%d" % [key,k])
			check((row_button!=null)==(expected>0),"Part vide neutre, part pleine cliquable · %s/%d" % [key,k])
			if expected==0: continue
			await click_control(row_button); await expect_panel("%s part %d (légende)" % [key,k],expected)
			# Même part depuis l'anneau : point au milieu de la part.
			var somme:=0.0; var depart:=0.0
			for j in 3: somme+=float(plan.counts.get(["repos","normal","intense"][j],0))+(float(plan.counts.get("collective",0)) if j==1 else 0.0)
			for j in k: depart+=(float(plan.counts.get(["repos","normal","intense"][j],0))+(float(plan.counts.get("collective",0)) if j==1 else 0.0))/somme
			var share: float=(float(expected))/somme
			var angle: float=-PI/2.0+(depart+share/2.0)*TAU
			var ring:Control=found("TrainingPlanTile_"+key).find_child("RepartitionAnneau",true,false)
			var radius: float=ring.size.x*0.5*(1.0-float(ring.get("epaisseur_relative")))
			await click(ring.get_global_transform_with_canvas()*(ring.size/2.0+Vector2(cos(angle),sin(angle))*radius))
			await expect_panel("%s part %d (anneau)" % [key,k],expected)
	# Graphique : chaque poste ouvre ses joueurs.
	var chart:=found("TrainingLoadChart")
	var bars:=0
	for child in chart.get_children():
		if child is Panel and child.tooltip_text.contains("charge moyenne"): bars+=1
	check(bars>=10,"Graphique : barres de charge et de condition dessinées (%d)" % bars)
	var zones:=0
	for i in 7:
		var zone:=found("TrainingChartFamily"+str(i))
		if zone==null: continue
		zones+=1
		await click_control(zone)
		check(found("TrainingGroupPanel")!=null,"Poste %d -> panneau de joueurs" % i)
		await close_panel()
	check(zones>=5,"Graphique : postes cliquables (%d)" % zones)
	finish()
func finish() -> void:
	print("TRAINING GROUPS CLICKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
