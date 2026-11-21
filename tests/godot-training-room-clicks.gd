extends SceneTree
## Observer la préparation (revue du 21/11/2026, n° 7, option B) : Godot réel + worker réel, carrière Monde.
## Tuiles Aptes / Blessés / Chargés filtrent la grille ; chaque portrait ouvre la petite fenêtre du joueur
## (Échap, × et clic à côté la ferment ; « Ouvrir la fiche » mène à la fiche) ; chaque plan du staff montre la
## répartition du moteur (effectiveCounts) et s'applique au clic ; aucun nom tronqué, colonne jamais écrasée.
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var director: Node
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_engine() -> void:
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande acceptée · "+id)
	await wait_engine()
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel · "+id)
func view() -> Control: return director.view
func found(id: String) -> Control: return view().find_child(id,true,false) as Control if is_instance_valid(view()) else null
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
		Input.parse_input_event(event); await process_frame
	await settle()
func click_control(control: Control, label: String) -> void:
	check(control!=null and control.is_visible_in_tree(),"Présent et visible · "+label)
	if control!=null: await click(control.get_global_rect().get_center())
## Bouton de la petite fenêtre : signal `pressed` (le clic souris synthétique n'atteint pas le centre de l'écran sans fenêtre).
func press(control: Control, label: String) -> void:
	check(control is BaseButton and control.is_visible_in_tree(),"Bouton présent et visible · "+label)
	if control is BaseButton: (control as BaseButton).pressed.emit()
	await settle()
func escape() -> void:
	for down: bool in [true,false]:
		var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.physical_keycode=KEY_ESCAPE; key.pressed=down
		Input.parse_input_event(key); await process_frame
	await settle()
func cells() -> Array:
	var grid:=found("TrainingPlayerGrid")
	return grid.find_children("TrainingPlayerCell_*","Control",false,false) if grid!=null else []
func squad() -> Array: return app.model.get("squad",[])
func open_room() -> void:
	director.open_training(); await settle()
	check(director.kind=="training" and found("TrainingPlayerGrid")!=null,"Salle d'entraînement ouverte avec la grille")
func first_cell() -> Control:
	var all:=cells()
	return all[0] if not all.is_empty() else null
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await command("new_career",{"mode":"world-champ","club":102})
	await ContextualFlow.settle_club_meetings(app,self,check)
	app.coach.close()
	director=app.contextual_director
	await open_room()
	# Colonne du groupe : largeur fixe (jamais une lettre par ligne), une case par joueur.
	var grid:=found("TrainingPlayerGrid")
	check(grid!=null and grid.get_global_rect().size.x>=400.0,"Colonne du groupe assez large (%s)" % (str(grid.size) if grid!=null else "absente"))
	check(cells().size()==squad().size(),"Une case par joueur (%d / %d)" % [cells().size(),squad().size()])
	var tronques:=0
	if grid!=null:
		for l: Label in grid.find_children("*","Label",true,false):
			var police:=l.get_theme_font("font")
			if police!=null and police.get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,l.get_theme_font_size("font_size")).x>l.size.x+1.0: tronques+=1
	check(tronques==0,"Aucun nom tronqué dans la grille (%d)" % tronques)
	# Filtres : le deuxième clic rend tout le groupe.
	var blesses:=squad().filter(func(p: Dictionary) -> bool: return int(p.get("injury",0))>0).size()
	for f: Array in [["blesses",blesses],["aptes",squad().size()-blesses]]:
		await click_control(found("TrainingRoomFilter_"+str(f[0])),"filtre "+str(f[0]))
		check(cells().size()==int(f[1]),"Filtre %s : %d joueur(s) attendus, %d affichés" % [f[0],f[1],cells().size()])
		await click_control(found("TrainingRoomFilter_"+str(f[0])),"filtre "+str(f[0])+" (retour)")
		check(cells().size()==squad().size(),"Filtre %s retiré : tout le groupe" % f[0])
	# Petite fenêtre du joueur : trois façons de la fermer, puis la fiche.
	for fermeture in ["echap","croix","voile"]:
		await click_control(first_cell(),"portrait")
		check(found("TrainingPlayerWindow")!=null,"Portrait -> petite fenêtre du joueur ("+fermeture+")")
		match fermeture:
			"echap": await escape()
			"croix": await press(found("TrainingPlayerClose"),"×")
			"voile": await press(found("TrainingPlayerVeil"),"clic à côté")
		check(found("TrainingPlayerWindow")==null,"Petite fenêtre fermée · "+fermeture)
		check(director.active() and director.kind=="training","La salle reste ouverte · "+fermeture)
	var cell:=first_cell()
	var id:=str(cell.name).trim_prefix("TrainingPlayerCell_") if cell!=null else ""
	await click_control(cell,"portrait")
	await press(found("TrainingPlayerOpenSheet"),"Ouvrir la fiche")
	await wait_engine()
	check(not director.active() and app.route=="Effectif" and str(app.selected_player).validate_node_name()==id,"Ouvrir la fiche -> fiche du joueur (%s, %s)" % [app.route,str(app.selected_player)])
	await open_room()
	# Avis du préparateur : pastille d'état du moteur (pas de phrase), clic -> Effectif & 23.
	var avis:=found("TrainingAdvice")
	check(avis!=null and str(app.model.decisions.training.get("adviceState",{}).get("kind","")) in ["pret","charge","fatigue"],"Avis du préparateur en pastille d'état")
	if avis!=null:
		await press(avis.get_meta("bouton"),"avis du préparateur")
		check(not director.active() and app.route=="Effectif","Avis du préparateur -> Effectif & 23 (%s)" % app.route)
	await open_room()
	# Plans du staff : pilules = répartition du moteur, clic = plan appliqué par le worker.
	var plans: Array = app.model.clubLife.clubSupport.training.plans
	check(plans.size()==3,"Trois plans du staff projetés")
	for plan: Dictionary in plans:
		var tuile:=found("TrainingRoomPlan_"+str(plan.key))
		check(tuile!=null,"Tuile du plan "+str(plan.key))
		if tuile==null: continue
		var attendues:=0
		for mode in ["repos","normal","intense"]:
			if int(plan.get("effectiveCounts",{}).get(mode,0))>0: attendues+=1
		var split:=tuile.find_child("TrainingPlanSplit",true,false)
		check(split!=null and split.get_child_count()==attendues,"Plan %s : %d pilule(s) du moteur" % [plan.key,attendues])
	await click_control(found("TrainingRoomPlan_proteger"),"plan Protéger le XV")
	await wait_engine()
	check(app.bridge.last_response_ok and not bool(app.model.meta.get("trained",false)),"Plan appliqué sans lancer la séance")
	finish()
func finish() -> void:
	print("TRAINING ROOM CLICKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
