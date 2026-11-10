extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for i in 10: await process_frame
func response(id: String) -> void:
	var until := Time.get_ticks_msec()+45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<until: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Commande "+id)
	await settle()
func command(id: String,payload: Dictionary={}) -> void:
	app._command(id,payload); await response(id)
func button(id: String) -> Button:
	for item: Button in app.find_children(id,"Button",true,false):
		if item.is_visible_in_tree() and not item.disabled:return item
	return null
func player_button(id: String,player_id: String) -> Button:
	for item: Button in app.find_children(id,"Button",true,false):
		if item.is_visible_in_tree() and not item.disabled and str(item.get_meta("player_id",""))==player_id:return item
	return null
func press(control: Control) -> void:
	check(is_instance_valid(control),"Commande clavier présente")
	if not is_instance_valid(control): return
	control.grab_focus(); await settle()
	check(control.is_visible_in_tree() and control.has_focus(),"Commande visible et focalisée : "+str(control.name))
	var ancestor := control.get_parent()
	while ancestor!=null and ancestor!=app:
		if ancestor is ScrollContainer: check(ancestor.get_global_rect().grow(2).encloses(control.get_global_rect()),"Commande entière dans le défilement : "+str(control.name))
		ancestor=ancestor.get_parent()
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
func dialog(id: String) -> AcceptDialog:
	return app.get_node_or_null(id) as AcceptDialog
func search(view: AcceptDialog,id: String,value: String) -> void:
	var field:=view.find_child(id,true,false) as LineEdit
	field.text=value;field.text_changed.emit(value);await settle()
func choose(view: AcceptDialog,id: String,index: int) -> void:
	var field:=view.find_child(id,true,false) as OptionButton
	field.select(index);field.item_selected.emit(index);await settle()
func cards(view: AcceptDialog,id: String) -> Array:
	return view.find_child(id,true,false).find_children("*","VBoxContainer",true,false).filter(func(c):return c.has_meta("player_id"))
func confirm_action() -> void:
	var windows:=app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
	check(windows.size()==1,"Confirmation publique réellement ouverte")
	if windows.size()==1: await press(windows[0].get_ok_button());await response("confirmation")
func open_scout() -> AcceptDialog:
	app._clear_dialogs();app._navigate("Recrutement");await settle()
	var tabs=app.body.find_child("MarketTabs",true,false)
	if tabs!=null:tabs.current_tab=1;await settle()
	await press(button("OpenRegenScouting"))
	var view:=dialog("RegenScouting")
	if view!=null:
		var field:=view.find_child("RegenScoutSearch",true,false) as Control
		check(view.scroll.get_global_rect().grow(2).encloses(field.get_global_rect()),"Filtres visibles à l’ouverture de la détection")
	return view
func open_youth() -> AcceptDialog:
	app._clear_dialogs();app._navigate("Formation");await settle();await press(button("OpenYouthDevelopment"))
	var view:=dialog("YouthDevelopment")
	if view!=null:
		var field:=view.find_child("YouthDevelopmentSearch",true,false) as Control
		check(view.scroll.get_global_rect().grow(2).encloses(field.get_global_rect()),"Filtres visibles à l’ouverture du suivi")
	return view
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_YOUTH_SCOUT_CAPTURES").path_join(id+".png"))==OK,"Capture "+id)
func run() -> void:
	root.size=Vector2i(1280,800)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await command("snapshot");await command("new_career",{"mode":"common","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Formation");await settle()
	check(button("OpenYouthDevelopment")!=null,"Entrée progression jeunes compacte")
	app._navigate("Recrutement");await settle()
	var tabs=app.body.find_child("MarketTabs",true,false)
	if tabs!=null:tabs.current_tab=1;await settle()
	check(button("OpenRegenScouting")!=null,"Entrée détection compacte")
	root.size=Vector2i(1920,1080);app._navigate("Formation");await settle()
	check(button("OpenYouthDevelopment")!=null,"Entrée progression jeunes immersive")
	app._navigate("Recrutement");await settle()
	check(button("OpenRegenScouting")!=null,"Entrée détection immersive")
	var scouting: Dictionary=app.model.get("clubLife",{}).get("regenScouting",{})
	var youth: Dictionary=app.model.get("clubLife",{}).get("youthDevelopment",{})
	check(scouting.get("available",false) and scouting.get("candidates",[]).size()>20,"Vrai vivier adulte projeté, pagination exerçable")
	check(youth.get("canEnable",false) and not youth.get("enabled",true),"Suivi jeunes non activé implicitement")
	if scouting.get("candidates",[]).is_empty() or youth.is_empty():await finish();return
	await command("export")
	var before: String=app.model.meta.exportText
	var profile: String=str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes:=FileAccess.get_file_as_bytes(profile)
	var scout:=await open_scout()
	check(scout!=null and scout.visible,"Dialogue détection réellement ouvert")
	if scout==null:await finish();return
	check(cards(scout,"RegenScoutRows").size()==20,"Détection borne les cartes à20")
	await press(button("RegenScoutNext"))
	check(int(scout.state.page)==1 and cards(scout,"RegenScoutRows").size()<=20,"Page suivante bornée")
	await choose(scout,"RegenScoutOrigin",1)
	check(cards(scout,"RegenScoutRows").all(func(c):return str(c.get_meta("player_id")) in scouting.candidates.filter(func(p):return p.origin.kind=="academy").map(func(p):return p.id)),"Filtre centres sans faux diplômé")
	await choose(scout,"RegenScoutOrigin",0)
	for size in [Vector2i(720,800),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=size;await settle()
		check(scout.size.x<=size.x and scout.size.y<=size.y,"Dialogue détection tient dans "+str(size.x))
		await press(button("RegenScoutMissions"))
		check(app.find_child("ScoutTabs",true,false)!=null,"Réemploi vrai dialogue missions")
		scout=await open_scout()
		await capture("detection-"+str(size.x))
	await press(scout.get_ok_button());await settle()
	var young:=await open_youth()
	check(young!=null and young.visible,"Dialogue progression réellement ouvert")
	if young==null:await finish();return
	check(cards(young,"YouthDevelopmentRows").size()<=20,"Progression borne les cartes à20")
	for p:Dictionary in youth.players:check(p.baseline==null and p.deltas==null,"Aucun gain historique inventé avant activation")
	for size in [Vector2i(720,800),Vector2i(1280,800),Vector2i(1920,1080)]:
		root.size=size;await settle()
		check(young.size.x<=size.x and young.size.y<=size.y,"Dialogue jeunes tient dans "+str(size.x))
		await capture("progression-"+str(size.x))
	await press(young.get_ok_button());await settle()
	await command("export")
	check(app.model.meta.exportText==before and FileAccess.get_file_as_bytes(profile)==bytes,"Lecture, filtres, pagination et redimensionnement sans mutation/RNG/disque")
	# Public watch command from the actual dialog; then close/reopen and snapshot.
	scout=await open_scout()
	var follow:=button("RegenScoutWatch")
	check(follow!=null,"Suivi disponible")
	var watched_id: String=str(follow.get_meta("player_id")) if follow!=null else ""
	if follow!=null:await press(follow);await response("regen_shortlist")
	check(app.model.clubLife.regenScouting.shortlist.any(func(p):return p.id==watched_id),"Suivi enregistré par le vrai worker")
	await press(scout.get_ok_button());await settle();await command("snapshot")
	scout=await open_scout()
	check(app.model.clubLife.regenScouting.shortlist.any(func(p):return p.id==watched_id),"Suivi conservé après fermeture/réouverture")
	var watched:=scout.find_child("RegenScoutWatched",true,false) as CheckBox
	await press(watched)
	check(cards(scout,"RegenScoutRows").size()==1,"Filtre liste suivie persistante")
	await press(button("RegenScoutWatch"));await response("retirer suivi")
	check(not app.model.clubLife.regenScouting.shortlist.any(func(p):return p.id==watched_id),"Retrait du suivi réel")
	# A genuinely watched non-regen profile appears as an unavailable archive.
	var candidate_ids: Array=app.model.clubLife.regenScouting.candidates.map(func(p):return p.id)
	var external: Array=app.model.market.filter(func(p):return p.id not in candidate_ids)
	if not external.is_empty():
		var archived_id: String=str(external[0].id)
		await command("manager_recruitment_watch",{"context":app.model.clubLife.managerCareer.context.duplicate(true),"playerId":archived_id})
		scout=await open_scout()
		var archived: Array=app.model.clubLife.regenScouting.shortlist.filter(func(p):return p.id==archived_id)
		check(archived.size()==1 and not archived[0].has("name"),"Archive sans nom ni identité inventés par le backend")
		check(cards(scout,"RegenScoutRows").size()==1,"Archive indisponible lisible et filtrable")
		await press(button("RegenScoutWatch"));await response("retirer archive")
		check(not app.model.clubLife.regenScouting.shortlist.any(func(p):return p.id==archived_id),"Archive indisponible retirable par vraie commande")
	# The existing public mission charges exactly once, through its confirmation.
	await press(button("RegenScoutMissions"))
	var cash: float=float(app.model.finance.cash)
	await press(button("CreateScoutMission"));await confirm_action()
	check(is_equal_approx(cash-float(app.model.finance.cash),5000),"Mission existante facturée exactement5000€")
	check(not app.model.clubLife.regenScouting.missions.is_empty(),"Mission réelle conservée")
	# Genuine recruitment via the existing offer dialog, never an alternate engine.
	scout=await open_scout()
	watched=scout.find_child("RegenScoutWatched",true,false) as CheckBox
	if watched.button_pressed:await press(watched)
	var offer:=button("RegenScoutOffer")
	check(offer!=null,"Piste réellement approchable")
	var signed_id: String=str(offer.get_meta("player_id")) if offer!=null else ""
	if offer!=null:
		await press(player_button("RegenScoutWatch",signed_id));await response("suivre avant contrat")
		offer=player_button("RegenScoutOffer",signed_id)
		await press(offer)
		var contract:=dialog("ContractOffer")
		check(contract!=null,"Réemploi vrai dialogue contrat")
		if contract!=null:
			var years:=contract.find_child("OfferYears",true,false) as SpinBox;years.value=years.min_value
			await press(contract.get_ok_button());await response("recruit")
			check(app.model.squad.any(func(p):return p.id==signed_id),"Recrutement réel dans effectif")
			scout=await open_scout()
			var archive: Array=app.model.clubLife.regenScouting.shortlist.filter(func(p):return p.id==signed_id)
			check(archive.size()==1 and not archive[0].has("name"),"Joueur signé devient archive suivie sans identité inventée")
			watched=scout.find_child("RegenScoutWatched",true,false) as CheckBox
			if not watched.button_pressed:await press(watched)
			check(cards(scout,"RegenScoutRows").size()==1,"Archive du joueur signé consultable")
			await press(player_button("RegenScoutWatch",signed_id));await response("retirer joueur signé")
			check(not app.model.clubLife.regenScouting.shortlist.any(func(p):return p.id==signed_id),"Archive du joueur signé retirable")
	# Opt-in creates the reference; changing the plan grants no immediate growth.
	young=await open_youth();await press(button("YouthDevelopmentEnable"));await confirm_action()
	check(app.model.clubLife.youthDevelopment.enabled,"Activation explicite persistante")
	young=await open_youth()
	var xp: Dictionary={};var annual: Dictionary={}
	for person:Dictionary in app.model.clubLife.youthDevelopment.players:
		if person.model=="xp" and person.stage=="academy" and xp.is_empty():xp=person
		if person.model=="annual-v11" and annual.is_empty():annual=person
	check(not xp.is_empty() and not annual.is_empty(),"Profils XP et annuels présents")
	if not xp.is_empty():
		await search(young,"YouthDevelopmentSearch",xp.name)
		var plan:=young.find_child("YouthPlan",true,false) as OptionButton
		for i in plan.item_count:
			if plan.get_item_metadata(i)=="integration":await choose(young,"YouthPlan",i)
		var quality:=young.find_child("YouthFocus",true,false) as OptionButton
		check(quality.visible and quality.item_count>0,"Plan intégration XP cible une qualité publique")
		await press(button("YouthPlanSave"));await confirm_action()
		var actual: Dictionary=app.model.clubLife.youthDevelopment.players.filter(func(p):return p.id==xp.id)[0]
		check(actual.plan=="integration" and actual.focus!=null,"Plan XP réel enregistré")
		check(actual.rating==xp.rating and actual.current.attributes==xp.current.attributes,"Changer objectif n’ajoute aucun gain immédiat")
	if not annual.is_empty():
		young=await open_youth();await search(young,"YouthDevelopmentSearch",annual.name)
		var plan:=young.find_child("YouthPlan",true,false) as OptionButton
		var keys: Array=[]
		for i in plan.item_count:keys.append(plan.get_item_metadata(i))
		check(not keys.has("specialist"),"Progression annuelle : spécialiste indisponible dans l’UI")
		await press(button("YouthPlanSave"));await confirm_action()
		var actual: Dictionary=app.model.clubLife.youthDevelopment.players.filter(func(p):return p.id==annual.id)[0]
		check(actual.plan=="general" and actual.focus==null and actual.rating==annual.rating,"Objectif annuel réel, sans gain ni focus inventé")
	app._clear_dialogs();await command("snapshot")
	check(app.model.clubLife.youthDevelopment.players.any(func(p):return p.id==xp.get("id") and p.plan=="integration"),"Objectif conservé après snapshot")
	await command("train",{"mode":"normal"})
	var trained: Dictionary=app.model.clubLife.youthDevelopment.players.filter(func(p):return p.id==xp.id)[0]
	check(trained.observations.any(func(o):return o.reason=="trainWeek"),"Vraie séance enregistrée dans les observations")
	check(trained.deltas.generalXP>0 and trained.deltas.focusedXP>0,"Gains XP réellement observés après séance")
	young=await open_youth();await search(young,"YouthDevelopmentSearch",xp.name)
	check(button("YouthPlanSave")==null,"Objectif verrouillé après séance")
	var text: String=""
	for label: Label in young.find_children("*","Label",true,false):text+="\n"+label.text
	check(text.contains("Séance") and text.contains("Objectifs verrouillés"),"Séance et prochaine possibilité de révision expliquées")
	check(not text.contains("V11") and not text.contains("annual-v11"),"Aucun jargon modèle dans le parcours")
	await capture("progression-apres-seance")
	await finish()
func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
