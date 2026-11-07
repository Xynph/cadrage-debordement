extends Node

# Fixed, in-process reception of the exact shipped app; no external UI inputs.
# It refuses existing data and only runs with an explicit disposable profile.
var app:Control
var failures:Array[String]=[]
var checks:=0
var captures:=""
var engine_pid:=-1

func _ready() -> void:call_deferred("_run")

func _check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func _settle() -> void:
	for i in 5:await get_tree().process_frame

func _wait() -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	_check(not app.waiting and not app.model.is_empty(),"Engine response is bounded")
	return not app.waiting and not app.model.is_empty()

func _ask(command:String,payload:Dictionary={},allow_refusal:bool=false) -> bool:
	app._command(command,payload)
	await _wait()
	var success:bool=app.bridge.last_response_ok
	if not allow_refusal:_check(success,command+" succeeds: "+app.last_error)
	return success

func _dismiss() -> void:
	for child in app.get_children():
		if child is AcceptDialog and child!=app.file_dialog:
			child.hide()
			child.queue_free()

func _confirm() -> void:
	for child in app.get_children():
		if child is ConfirmationDialog and child.visible:
			child.confirmed.emit()
			return
	_check(false,"Expected confirmation is visible")

func _press(text:String) -> void:
	for item in app.root_content.find_children("*","Button",true,false):
		if item is Button and item.text==text and item.is_visible_in_tree():
			_check(not item.disabled,"Control enabled: "+text)
			if not item.disabled:item.pressed.emit()
			return
	_check(false,"Control exists: "+text)

func _capture(name:String) -> void:
	await _settle()
	var logical:Vector2=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else get_tree().root.size
	var end:Vector2=app.root_content.get_global_transform_with_canvas()*app.root_content.size
	_check(end.x<=logical.x+1 and end.y<=logical.y+1,"Root fits client: "+name)
	if is_instance_valid(app.body) and app.route not in ["Accueil","Création"]:
		end=app.body.get_global_transform_with_canvas()*app.body.size
		_check(end.x<=logical.x+1 and end.y<=logical.y+1,"Page fits client: "+name+" "+str(end))
	if captures.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image:=get_tree().root.get_texture().get_image()
	_check(image.get_size()==DisplayServer.window_get_size(),"Native capture dimensions "+name)
	_check(image.save_png(captures.path_join(name+".png"))==OK,"Capture saved "+name)

func _coverage() -> void:
	await _ask("auto_lineup")
	if app.model.get("selection",{}).get("valid",true):return
	# The manager resolves real squad shortages through actual recruitment.
	for slot in app.model.get("selection",{}).get("slots",[]).slice(0,3):
		if slot.get("eligibleIds",[]).size()>1:continue
		for p in app.model.get("market",[]):
			if not p.get("available",false) or p.get("pos")!=slot.get("label"):continue
			await _ask("recruit",{"playerId":p.id,"salary":int(p.salary)*2,"years":2,"confirmed":true},true)
			_dismiss()
			break
	await _ask("auto_lineup")

func _run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():get_tree().quit(2);return
	captures=OS.get_environment("CD_GODOT_QA_CAPTURES")
	if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
	if not await _wait():await _finish();return
	engine_pid=app.bridge.child_pid
	app.timer.stop()
	var data_dir:String=app.model.get("meta",{}).get("dataDir",OS.get_environment("CD_GODOT_DATA_DIR"))
	if FileAccess.file_exists(data_dir.path_join("donnees.json")):
		printerr("Reception requires a fresh empty profile; existing career was not modified.")
		app.bridge.stop()
		get_tree().quit(2)
		return
	_check(not app._has_career() and app.route=="Accueil","Fresh profile opens menu without creating career")
	for resolution in [Vector2i(1440,900),Vector2i(1920,1080)]:
		if DisplayServer.get_name()=="headless":get_tree().root.size=resolution
		else:DisplayServer.window_set_size(resolution)
		await _settle()
		app._navigate("Accueil")
		await _capture("accueil-"+str(resolution.x))
		app.club_division="accession"
		app.selected_club=29
		app._navigate("Création")
		await _capture("creation-"+str(resolution.x))
	_press("PRENDRE LES RÊNES DE VDX  →")
	await _wait()
	_check(app.model.get("meta",{}).get("mode")=="france30" and int(app.model.club.id)==29,"Actual30-clubcareer created through UI")
	if not app._has_career():await _finish();return
	_check(app.model.get("squad",[]).size()>=23,"Real squad for club29")
	_check(app.model.get("leagues",[]).size()==2,"Both divisions projected")
	for resolution in [Vector2i(1440,900),Vector2i(1920,1080)]:
		if DisplayServer.get_name()=="headless":get_tree().root.size=resolution
		else:DisplayServer.window_set_size(resolution)
		for page in ["Bureau","Effectif","Composition","Préparation","Calendrier","Classements","Recrutement","Finances","Club","Match"]:
			app._navigate(page)
			await _capture(page.to_lower()+"-"+str(resolution.x))
	app._navigate("Composition")
	var selection:Dictionary=app.model.get("selection",{})
	if not selection.get("slots",[]).is_empty():
		var slot:Dictionary=selection.slots[0]
		for id in slot.get("eligibleIds",[]):
			if id!=slot.get("playerId"):
				await _ask("set_lineup",{"playerId":id,"slot":0})
				_check(app.model.lineup[0]==id,"Lineup decision really changes selected player")
				break
	await _ask("auto_lineup")
	var tactics:Dictionary=app.model.get("tactics",{})
	for option in tactics.get("attacks",[]):
		if option.id!=tactics.get("attack"):
			await _ask("set_tactics",{"attack":option.id,"defense":tactics.defense})
			_check(app.model.tactics.attack==option.id,"Attack decision persisted")
			break
	app._navigate("Préparation")
	_press("ÉQUILIBRÉE")
	await _wait()
	_check(app.model.meta.trained,"Training performed via real control")
	app._navigate("Match")
	_press("COUP D'ENVOI")
	await _wait()
	_check(app.model.live!=null,"Actual fixture begins")
	if app.model.live==null:await _finish();return
	await _ask("tick",{"steps":12})
	await _ask("pause",{"paused":true})
	_check(app.model.live.paused,"Real pause")
	await _capture("match-live")
	app.match_view.set_camera("tactical")
	await _capture("match-tactical")
	var changes:Array=app.model.live.get("substitutions",[])
	for change in changes:
		if not change.get("inIds",[]).is_empty():
			var incoming:String=change.inIds[0]
			await _ask("substitute",{"outId":change.outId,"inId":incoming})
			_check(app.model.live.lineup.any(func(p):return p is Dictionary and p.get("id")==incoming),"Actual substitution reaches live lineup")
			break
	await _ask("delegate")
	_check(app.model.live.finished,"Actual match finishes")
	await _capture("resultat")
	var same_page:Node=app.match_page
	_press("VALIDER LA JOURNÉE  →")
	await _wait()
	_check(app.match_page==same_page,"Match panel remains stable across week")
	_check(int(app.model.meta.week)==1,"Both competitions advance once")
	await _coverage()
	_check(not app.pause_button.disabled,"Second kickoff reenabled")
	_press("COUP D'ENVOI")
	await _wait()
	_check(app.model.live!=null,"Second actual match starts without navigating away")
	if app.model.live==null:await _finish();return
	await _ask("delegate")
	await _ask("finish_round")
	app._navigate("Bureau")
	var rounds:=0
	while not app.model.meta.get("canAdvanceSeason",false) and rounds<40:
		if not app.model.meta.get("trained",false):await _ask("train",{"mode":"repos"})
		if app.model.get("next")!=null:
			await _coverage()
			if not await _ask("begin_match",{},true):break
			await _ask("delegate")
		await _ask("finish_round")
		rounds+=1
	_check(app.model.meta.get("canAdvanceSeason",false),"Complete season reaches interseason")
	await _capture("fin-saison")
	if app.model.meta.get("canAdvanceSeason",false):
		await _ask("next_season",{"confirmed":true})
		_check(int(app.model.meta.season)==2,"Native interseason changes season")
	var exported:=data_dir.path_join("reception-export.json")
	app.import_mode=false
	app._file_selected(exported)
	await _wait()
	_check(FileAccess.file_exists(exported),"Native UI export written")
	await _ask("new_career",{"club":0,"mode":"france"})
	app._navigate("Bureau")
	await _capture("bureau-toulouse")
	app.import_mode=true
	app._file_selected(exported)
	_confirm()
	await _wait()
	_check(int(app.model.club.id)==29 and int(app.model.meta.season)==2,"UI import restores exact club and season")
	_dismiss()
	await _finish()

func _finish() -> void:
	app.bridge.stop()
	var deadline:=Time.get_ticks_msec()+2500
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	_check(app.bridge.child_pid<=0,"Owned worker stopped")
	var final_club:Dictionary=app.model.club if app.model.get("club") is Dictionary else {}
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_display":DisplayServer.get_name(),"captures":captures,"pid":OS.get_process_id(),"engine_pid":engine_pid,"executable":OS.get_executable_path(),"season":app.model.get("meta",{}).get("season"),"club":final_club.get("id")}
	if not captures.is_empty():
		var file:=FileAccess.open(captures.path_join("report.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
