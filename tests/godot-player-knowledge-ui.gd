extends SceneTree
const G = preload("res://ui/game_skin.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const Observation = preload("res://ui/player_observation.gd")
const Comparison = preload("res://ui/immersive08/recruitment_comparison.gd")
const U = preload("res://ui/management_state.gd")
const A = preload("res://ui/player_attributes.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_KNOWLEDGE_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8:await process_frame
func ready_engine() -> void:
	var deadline:=Time.get_ticks_msec()+45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vraie réponse moteur : "+app.last_error)
	await settle()
func ask(id: String,payload: Dictionary={}) -> void:
	app._command(id,payload);await ready_engine()
func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(filename+".png"))==OK,"Capture1440 "+filename)
func labels(node: Node) -> Array:
	var result: Array=[]
	for child in node.get_children():
		if child is Label:result.append(child)
		result.append_array(labels(child))
	return result
func clear_dialogs() -> void:
	app._clear_dialogs();await settle()
func run() -> void:
	var worker:=OS.get_environment("CD_KNOWLEDGE_WORKER")
	if not worker.is_empty():ProjectSettings.set_setting("native_engine/worker_path",worker)
	root.size=Vector2i(2560,1440)
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await ready_engine()
	await ask("new_career",{"mode":"common","club":29});app.timer.stop()
	var original: Dictionary=app.model.duplicate(true)
	var canonical: bool=original.squad[0].get("knowledge") is Dictionary
	check(canonical,"Le banc exige la nouvelle vraie projection knowledge du worker")
	if not canonical:await app._close(1);return
	var profile:=str(original.meta.dataDir).path_join("donnees.json")
	var before:=FileAccess.get_sha256(profile)
	var commands: int=app.bridge._next_id
	for person: Dictionary in original.squad:
		check(person.knowledge.owned and G.rating_text(person)==G.n(person.rating),"Niveau exact du propre effectif")
		check(person.potential==null and person.potentialRange.max-person.potentialRange.min==4,"Potentiel propre : cinq valeurs fournies")
	app._navigate("Effectif");await settle()
	for row: Node in app.find_child("CarnetSquad",true,false).rows.get_children():
		if not row.has_meta("player_id"):continue
		var person: Dictionary=original.squad.filter(func(p:Dictionary):return str(p.id)==str(row.get_meta("player_id")))[0]
		var level:=row.find_child("RosterLevel",true,false) as Label
		var potential:=row.find_child("RosterPotential",true,false) as Label
		check(potential!=null and potential.text==G.potential_text(person),"Colonne propre reprend sa fourchette")
		check(potential.get_theme_color("font_color")==G.POTENTIAL_COLOR,"Potentiel orange")
	await capture("effectif-connaissance-modele-reel-1440")
	var own: Dictionary=original.squad[0]
	app.selected_player=str(own.id);app.set_meta("immersive08_full_player",true);app._render();await settle()
	check(labels(app).any(func(label:Label):return label.text==G.potential_text(own)),"Fiche propre affiche la fourchette, pas le potentiel exact")
	await capture("fiche-potentiel-modele-reel-1440")
	app.set_meta("immersive08_full_player",false)
	app._navigate("Recrutement");await settle()
	var target: Dictionary=original.market.filter(func(p:Dictionary):return p.get("scouting",{}).get("available",false))[0]
	check(G.rating_text(target)=="—" and G.potential_text(target)=="—","Étranger non observé : niveau et potentiel inconnus")
	check(A.detail(target).is_empty(),"Attributs étrangers non observés masqués")
	var page: Control=app.find_child("CarnetMarket",true,false)
	page.state.player_id=str(target.id)
	page.state.immersive_tab=1;app._render(false);await settle()
	await capture("recrutement-inconnu-modele-reel-1440")
	var button: Button=app.find_child("ObservePlayer_"+str(target.id).replace(":","_"),true,false)
	check(button!=null and button.visible and not button.disabled,"Action Observer issue de l’API réelle")
	if button!=null:
		button.pressed.emit();await settle()
		var dialog: AcceptDialog=null
		for child in app.get_children():
			if child is AcceptDialog and child.visible and child!=app.file_dialog:dialog=child
		check(dialog!=null and dialog.dialog_text.contains("5 000") and dialog.dialog_text.contains(G.n(target.scouting.workCycles)+" semaine"),"Confirmation : frais et délai réels")
		check(FileAccess.get_sha256(profile)==before and app.bridge._next_id==commands,"Ouvrir l’observation ne change ni argent ni connaissance")
		await capture("observation-confirmation-modele-reel-1440")
		if dialog!=null:dialog.canceled.emit();dialog.queue_free();await settle()
	check(FileAccess.get_sha256(profile)==before and app.bridge._next_id==commands,"Consultation et annulation sans mutation")
	for scenario: String in ["missing","own","pending","unavailable","waiting","live"]:
		var person: Dictionary=target.duplicate(true)
		if scenario=="missing":person.erase("scouting")
		elif scenario=="own":person.knowledge.owned=true
		elif scenario=="pending":person.scouting.pending=true;person.scouting.job={"remainingWeeks":1}
		elif scenario=="unavailable":person.scouting.available=false;person.scouting.reason=""
		elif scenario=="waiting":app.waiting=true
		elif scenario=="live":app.model.live={"finished":false}
		var control:=Button.new();app.add_child(control);Observation.configure(control,app,person)
		check(not control.visible if scenario in ["missing","own"] else control.disabled,"Observation protégée : "+scenario)
		if scenario=="pending":check(control.tooltip_text.contains("1 semaine"),"Délai restant fourni, pas calculé par l’UI")
		control.queue_free();app.waiting=false;app.model=original.duplicate(true)
	var export_file:=output.path_join("carriere-exportee.json")
	app.export_path=export_file;await ask("export")
	check(FileAccess.get_file_as_string(export_file)==str(app.model.meta.exportText),"Export intégral conservé byte pour byte")
	var doc: Variant=JSON.parse_string(FileAccess.get_file_as_string(export_file))
	check(doc is Dictionary and doc.get("state") is Dictionary,"Export demeure un document restaurable")
	check(not labels(app).any(func(label:Label):return label.text.contains('"potential":') or label.text.contains('"exportedAt":')),"Aucun JSON joueur brut affiché dans les labels")
	for stage: String in ["observed","deep"]:
		var model_file:=OS.get_environment("CD_KNOWLEDGE_"+stage.to_upper()+"_MODEL")
		if model_file.is_empty():continue
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(model_file))
		var model: Dictionary=data.model if data.get("model") is Dictionary else data
		app.model=model.duplicate(true);U.sync(app,true)
		app.management_ui.market.immersive_tab=3
		app._navigate("Recrutement");await settle()
		var report: Dictionary=app.model.decisions.recruitment.reports[0]
		check(report.knowledge.stage==stage,"Rapport réellement obtenu par mission : "+stage)
		check(report.ratingRange.max-report.ratingRange.min==(8 if stage=="observed" else 4),"Fourchette niveau réelle "+stage)
		check(report.potentialRange.max-report.potentialRange.min==(10 if stage=="observed" else 4),"Fourchette potentiel réelle "+stage)
		check(labels(app).any(func(label:Label):return label.text==G.potential_text(report)),"Rapport UI lit la fourchette réelle "+stage)
		check(app.find_child("CandidateRatingRange",true,false)!=null and app.find_child("CandidatePotentialRange",true,false)!=null,"Comparaison de l’archive visualise les deux intervalles, pas des tirets")
		await capture("recrutement-"+stage+"-modele-reel-1440")
	app.model=original.duplicate(true);U.sync(app,true);app._navigate("Recrutement");await settle()
	# Cas contrôlés de rendu : aucune mission ni mesure sportive n'est fabriquée.
	var fixture: Array[Dictionary]=[]
	for i in 2:
		var p: Dictionary=original.market[i].duplicate(true)
		p.merge({"rating":99,"potential":100,"ratingRange":{"min":70+i*2,"max":78+i*2},"potentialRange":{"min":80+i*2,"max":90+i*2},"knowledge":{"owned":false,"stage":"observed"},"attributesV2":original.squad[0].get("attributesV2",{})},true)
		fixture.append(p)
	app.model.market=fixture
	Comparison.open(app,str(fixture[0].id),{});await settle()
	var comparison: AcceptDialog=app.find_child("MarketComparison",true,false)
	var rating_row: HBoxContainer=comparison.find_child("MarketComparisonRow_rating",true,false)
	var potential_row: HBoxContainer=comparison.find_child("MarketComparisonRow_potential",true,false)
	check(rating_row.get_child(1).text=="70–78" and rating_row.get_child(2).text=="72–80","Comparateur : intervalles fournis, scalaires étrangers ignorés")
	check(comparison.find_child("MarketComparisonDelta_rating",true,false).text=="-6 à +10","Comparateur : écart intervalle, pas fausse différence exacte")
	check(potential_row.get_child(1).text=="80–90" and potential_row.get_child(1).get_theme_color("font_color")==G.POTENTIAL_COLOR,"Comparateur : potentiel orange")
	check(Comparison.value(fixture[0],"attribute:tackling",{})==null,"Attributs contrôlés masqués au premier suivi")
	await capture("comparaison-fourchettes-cas-ui-controle-1440")
	await clear_dialogs()
	check(FileAccess.get_sha256(profile)==before,"Toutes les consultations laissent la carrière et le RNG inchangés")
	var unchanged:=FileAccess.get_sha256(profile)==before
	app.model=original.duplicate(true);U.sync(app,true)
	app.management_ui.market.player_id=str(target.id);app.management_ui.market.immersive_tab=1
	app._navigate("Recrutement");await settle()
	var observe: Button=app.find_child("ObservePlayer_"+str(target.id).replace(":","_"),true,false)
	if observe!=null:
		observe.pressed.emit();await settle()
		for child in app.get_children():
			if child is AcceptDialog and child.visible and child!=app.file_dialog:child.confirmed.emit();break
		await ready_engine()
		var after: Dictionary=app.model.market.filter(func(p:Dictionary):return p.id==target.id)[0]
		check(after.scouting.pending and after.knowledge.stage=="unobserved","Confirmation réelle planifie sans révéler immédiatement le joueur")
		check(int(app.model.finance.cash)==int(original.finance.cash)-int(target.scouting.cost),"Confirmation réelle débite exactement le coût fourni")
		await capture("observation-programmee-modele-reel-1440")
	var report_file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	report_file.store_string(JSON.stringify({"checks":checks,"failures":failures,"profile_unchanged":unchanged,"canonical":canonical}));report_file.close()
	print("CONNAISSANCE UI NATIVE : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
