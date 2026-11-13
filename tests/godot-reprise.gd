extends SceneTree
# Reprise choisie (reprise.cjs) : départ de la partie à la création, puis décision de reprise
# dans la Préparation, avec le vrai moteur Monde (world-champ).
const Entry = preload("res://ui/entry_screens.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_REPRISE_UI_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 12: await process_frame
func response() -> void:
	var deadline := Time.get_ticks_msec()+120000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse du vrai moteur : "+app.last_error)
func press(button: BaseButton) -> void:
	button.grab_focus(); await settle()
	button.pressed.emit(); await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
	root.size=Vector2i(1920,1080)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+90000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.model.is_empty(),"Application et catalogue réels prêts")
	app.timer.stop()
	check(app.model.get("meta",{}).get("repriseCreation",{}).get("elite",{}).get("0","")=="2026-07-27","Dates de reprise de l’Élite exposées à la création")
	Entry.begin_creation(app); await settle()
	var clubs := app.find_child("CreationClubGrid",true,false) as GridContainer
	check(clubs!=null and clubs.get_child_count()>0,"Vrais clubs disponibles")
	await press(clubs.get_child(0) as Button)
	var choice := app.find_child("CreationStartChoice",true,false) as OptionButton
	check(choice!=null and choice.item_count==3,"Trois départs proposés")
	check(choice.selected==0 and choice.get_item_text(0).contains("13 juillet"),"Départ par défaut : reprise des premiers clubs")
	var sentence := app.find_child("CreationStartSentence",true,false) as Label
	check(sentence!=null and sentence.text.contains("13 juillet 2026"),"Phrase claire des conséquences")
	choice.select(1); choice.item_selected.emit(1); await settle()
	check(sentence.text.contains("reprise de votre club"),"La phrase suit le choix")
	choice.select(0); choice.item_selected.emit(0); await settle()
	await capture("reprise-creation")
	var start := app.find_child("CreationStart",true,false) as Button
	check(start!=null and not start.disabled,"Création disponible")
	await press(start); await response()
	check(app.model.get("clubLife",{}).get("reprise",{}).get("start","")=="premiers-clubs","Départ transmis au moteur")
	check(str(app.model.meta.get("calendarToday",""))=="2026-07-13","La carrière commence le 13 juillet 2026")
	app._navigate("Préparation"); await settle()
	var panel := app.find_child("RepriseDecision",true,false)
	check(panel!=null,"Décision de reprise dans la Préparation")
	check(app.find_child("RepriseGabi",true,false)!=null,"Conseil de Gabi")
	check(app.find_child("RepriseInternationals",true,false)!=null,"Internationaux en congés visibles")
	var option := app.find_child("RepriseOption_2026-07-20",true,false) as Button
	check(option!=null,"Lundi 20 juillet proposé")
	if option != null:
		await press(option); await response()
		check(str(app.model.clubLife.reprise.club.date)=="2026-07-20","Choix de reprise appliqué par le moteur")
	app._navigate("Préparation"); await settle()
	await capture("reprise-decision")
	var result := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()},"  ")); result.close()
	print("REPRISE UI : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
