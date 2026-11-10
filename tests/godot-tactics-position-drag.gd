extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_TACTICS_DRAG_OUTPUT")
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle() -> void:
	for frame in 10:await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline:await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Commande réelle : "+str(app.last_error))
func named(id: String) -> Control:return app.root_content.find_child(id,true,false)
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	var deadline := Time.get_ticks_msec()+45000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.model.is_empty(),"Application prête")
	app.timer.stop();app._command("new_career",{"mode":"common","club":0});await worker()
	app._navigate("Composition");await settle();app.coach.close()
	check(named("TacticsPitch")!=null and named("TacticsIdentity")!=null and named("TacticsBench")!=null,"Trois colonnes existantes conservées")
	check(named("TacticsRosterTab")!=null,"Accès Effectif intégré au panneau Banc")
	check(named("TacticsSelectedRating")!=null,"Note au numéro choisi identifiée")
	finish()
func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	app.closing=true;app.bridge.stop()
	print("TACTIQUE : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
