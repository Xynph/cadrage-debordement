extends SceneTree
## Entraînement › Semaine : chaque pièce visuelle ajoutée aux cartes (crans, cases, portraits, blasons, pastilles)
## mène à sa destination (choix appliqué, onglet, écran ou petite fenêtre) ; Échap ferme la petite fenêtre de joueurs.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_worker() -> void:
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande acceptée · "+id)
	await wait_worker()
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel · "+id)
func found(id: String) -> Control: return app.find_child(id,true,false) as Control
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	Input.parse_input_event(move); await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; event.global_position=point
		Input.parse_input_event(event); await process_frame
	await settle()
func click_id(id: String) -> bool:
	var control:=found(id)
	check(control!=null and control.is_visible_in_tree(),"Présent et visible · "+id)
	if control==null: return false
	await click(control.get_global_rect().get_center())
	return true
## Fenêtre de dialogue ouverte et visible (un Window n'est pas un Control).
func dialog(id: String) -> bool:
	var window:=app.find_child(id,true,false) as Window
	return window!=null and window.visible
func page() -> Control: return found("ImmersiveTraining")
func week() -> void:
	app._clear_dialogs()
	if page()==null:
		app.Immersive.open_training(app); await settle()
	page()._open_tab(0); await settle()
func tab() -> int: return int(app.management_ui.get("immersive_training",{}).get("tab",-1))
func back() -> void:
	app.navigation_controller._travel(-1); await settle()
	await week()
func expect_dialog(label: String) -> void:
	check(dialog("TrainingIndividualDialog"),label+" -> fiche de charge du joueur")
	app._clear_dialogs(); await settle()
func expect_panel(label: String, expected: int) -> void:
	var panel:=found("TrainingGroupPanel")
	check(panel!=null,label+" -> petite fenêtre de joueurs")
	if panel==null: return
	var names:=panel.find_children("TrainingGroupName_*","Button",true,false)
	check(names.size()==expected,"%s : %d joueur(s) attendus, %d affichés" % [label,expected,names.size()])
	# Échap ferme la petite fenêtre et ne fait rien d'autre.
	var route: String=app.route
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; root.push_input(escape,true)
	escape=escape.duplicate(); escape.pressed=false; root.push_input(escape,true)
	await settle()
	check(found("TrainingGroupPanel")==null and app.route==route,label+" : Échap ferme la petite fenêtre")
	if found("TrainingGroupPanel")!=null: await click_id("TrainingGroupClose")
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
	await week()
	check(tab()==0,"Onglet Semaine ouvert")
	await layout()
	var squad: Array=app.model.squad
	# Séance collective : chaque cran choisit la charge.
	for mode in ["repos","intense","normal"]:
		if await click_id("TrainingWeekMode_%sLink" % mode):
			check(str(app.management_ui.immersive_training.get("mode",""))==mode,"Cran de charge -> "+mode)
			check(found("TrainingWeekMode_%sWord" % mode)!=null,"Le cran retenu est nommé · "+mode)
	# Travail spécifique : un point non retenu applique ce travail, le retenu ouvre le choix.
	var collective: Dictionary=app.model.decisions.training.collective
	for option: Dictionary in collective.options:
		if option.id==collective.selected: continue
		if await click_id("TrainingWeekFocusLink_"+str(option.id)):
			await wait_worker(); await week()
			check(app.model.decisions.training.collective.selected==option.id,"Point de travail -> "+str(option.id))
		break
	if await click_id("TrainingWeekFocusLink_"+str(app.model.decisions.training.collective.selected)):
		check(dialog("TrainingChoices"),"Point retenu -> choix du travail spécifique")
	await week()
	# Plans des groupes -> onglet Groupes.
	if not app.model.clubLife.clubSupport.training.plans.is_empty():
		if await click_id("TrainingWeekPlans"): check(tab()==1,"Barre de plan -> onglet Groupes")
		await week()
	# Avants et arrières -> petite fenêtre de joueurs.
	var forwards:=squad.filter(func(p: Dictionary): return int(p.get("fam",-1)) in [0,1,2,3]).size()
	var backs:=squad.filter(func(p: Dictionary): return int(p.get("fam",-1))>=4).size()
	if await click_id("TrainingWeekLine0"): await expect_panel("Avants",forwards)
	if await click_id("TrainingWeekLine1"): await expect_panel("Arrières",backs)
	# Axes individuels : portrait -> fiche de charge ; « +N » -> tous.
	if await click_id("TrainingWeekAxis0"): await expect_dialog("Portrait d'axe")
	var professionals: Array=app.model.decisions.development.professionals
	if professionals.size()>3 and await click_id("TrainingWeekAxisMoreLink"): await expect_panel("Axes individuels",professionals.size())
	# Vigilance : portrait et « +N ».
	var watch_count: int=int(found("TrainingWeekWatchMore")!=null)
	if found("TrainingWeekWatch0")!=null:
		await click_id("TrainingWeekWatch0"); await expect_dialog("Portrait à surveiller")
	if watch_count==1 and await click_id("TrainingWeekWatchMoreLink"): check(found("TrainingGroupPanel")!=null,"« +N » à surveiller -> petite fenêtre"); await expect_panel("À surveiller",page().watched.size())
	# Suivi médical.
	if found("TrainingWeekMedical0")!=null:
		await click_id("TrainingWeekMedical0"); await expect_dialog("Portrait suivi médical")
	# Charge individuelle : une exception posée, sa case ouvre ses joueurs ; les cases vides restent neutres.
	await command("set_player_load",{"playerId":squad[0].id,"mode":"repos"})
	await week()
	check(found("TrainingWeekLoad_intenseLink")==null or app.model.squad.any(func(p: Dictionary): return p.get("loadPlan")=="intense"),"Case vide sans destination")
	var resting: int=app.model.squad.filter(func(p: Dictionary): return p.get("loadPlan")=="repos").size()
	if await click_id("TrainingWeekLoad_reposLink"): await expect_panel("Charge individuelle repos",resting)
	# Niveau adverse : cran non retenu appliqué, cran retenu ouvre le choix.
	var difficulty: Dictionary=app.model.decisions.difficulty
	for option: Dictionary in difficulty.options:
		if option.id==difficulty.selected: continue
		if await click_id("TrainingWeekLevel_%sLink" % option.id):
			await wait_worker(); await week()
			check(app.model.decisions.difficulty.selected==option.id,"Cran de niveau adverse -> "+str(option.id))
		break
	if await click_id("TrainingWeekLevel_%sLink" % app.model.decisions.difficulty.selected): check(dialog("TrainingChoices"),"Niveau retenu -> choix du niveau adverse")
	await week()
	# Feuille de match -> Composition ; jour de match -> Match.
	if await click_id("TrainingWeekSheet0Link"): check(app.route=="Composition","Case XV -> Composition")
	await back()
	if found("TrainingWeekFixture")!=null:
		await click_id("TrainingWeekFixture"); check(app.route=="Match","Blasons -> Match")
		await back()
	# Conseil et délégation -> onglet Staff.
	if await click_id("TrainingWeekAdviceLink"): check(tab()==3,"Pastille du conseil -> onglet Staff")
	await week()
	if await click_id("TrainingWeekDelegation_trainingLink"): check(tab()==3,"Case de délégation -> onglet Staff")
	finish()
## Mise en page « façon Effectif » (choix du 22/11/2026) : quatre petites tuiles-chiffres en tête, les sept volets en
## sept lignes (deux cases chacune), plus aucune colonne de cartes ; survol de ligne ; clic volet / case / tuile.
func layout() -> void:
	for i in 4:
		var tuile:=found("TrainingMetric%d" % i)
		check(tuile is Button and tuile.is_visible_in_tree(),"Tuile-chiffre %d en tête" % i)
		if tuile!=null: check(tuile.size.y<=found("ImmersiveTraining").size.y*.1,"Tuile-chiffre %d compacte" % i)
	check(found("TrainingMetrics")==null and found("TrainingWeekColumn0")==null,"Ancienne rangée de chiffres et colonnes de cartes retirées")
	check(found("TrainingWeekTable")!=null,"Tableau de la semaine présent")
	var y_precedent:=-1.0
	for i in 7:
		var ligne:=found("TrainingWeekRow%d" % i)
		check(ligne!=null and ligne.is_visible_in_tree(),"Volet %d en ligne" % i)
		if ligne==null: continue
		check(ligne.get_global_rect().position.y>y_precedent,"Volets empilés de haut en bas · %d" % i)
		y_precedent=ligne.get_global_rect().position.y
		check(ligne.get_node_or_null(SurvolLigne.NOM)!=null,"Survol de ligne posé · volet %d" % i)
		for k in 2: check(ligne.find_child("TrainingStep%d" % (i*2+k),true,false) is Button,"Case %d dans le volet %d" % [i*2+k,i])
		check(ligne.find_child("TrainingWeekVolet%d" % i,true,false) is Button,"Nom du volet %d cliquable" % i)
	# Clic sur un nom de volet : sa première case est retenue (contour) et la séance sélectionnée suit.
	(found("TrainingWeekVolet3") as Button).pressed.emit(); await settle()
	check(int(page().state.get("slot",-1))==6,"Volet Vigilance -> case Récupération retenue")
	check(found("TrainingWeekPick6")!=null and found("TrainingWeekPick6").visible and not found("TrainingWeekPick0").visible,"Contour sur la case retenue")
	(found("TrainingStep11") as Button).pressed.emit(); await settle()
	check(int(page().state.get("slot",-1))==11 and found("TrainingWeekPick11").visible,"Case Jour de match retenue")
	# Tuiles : moral -> Vestiaire ; condition -> onglet Fatigue.
	(found("TrainingMetric0") as Button).pressed.emit(); await settle()
	check(tab()==4,"Tuile Condition -> onglet Fatigue")
	await week()
	(found("TrainingMetric1") as Button).pressed.emit(); await settle()
	check(app.route=="Vestiaire","Tuile Moral -> Vestiaire")
	await back()
func finish() -> void:
	print("TRAINING WEEK CLICKS : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
