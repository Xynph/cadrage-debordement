extends Node

# Fixed, in-process reception of the exact shipped app; no external UI inputs.
# It refuses existing data and only runs with an explicit disposable profile.
var app:Control
var failures:Array[String]=[]
var checks:=0
var captures:=""
var engine_pid:=-1
var coach_reception: Dictionary = {}
var layout_reception: Array[Dictionary] = []

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

func _keyboard_focus() -> void:
	var buttons:Array=app.root_content.find_children("*","Button",true,false)
	for button in buttons:
		if button is Button and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			_check(button.has_focus(),"Keyboard focus reaches visible action")
			var next:Control=button.find_next_valid_focus()
			_check(next!=null and next.is_visible_in_tree(),"Keyboard traversal has next visible control")
			if next!=null:next.grab_focus()
			return
	_check(false,"Keyboard accessible action exists")

func _capture(name:String) -> void:
	await _settle()
	# CanvasItem transforms end in logical viewport units, before window stretch.
	# A 1280x800 window uses a 1440x900 viewport in this project's canvas_items mode.
	var logical:Vector2=get_tree().root.get_visible_rect().size
	var end:Vector2=app.root_content.get_global_transform_with_canvas()*app.root_content.size
	layout_reception.append({"capture":name,"viewport":[logical.x,logical.y],"window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"root_end":[end.x,end.y]})
	_check(end.x<=logical.x+1 and end.y<=logical.y+1,"Root fits client: "+name)
	if is_instance_valid(app.body) and app.route not in ["Accueil","Création"]:
		# The page content may extend vertically inside CareerWorkspace. Check
		# its visible viewport, while still refusing horizontal content clipping.
		var workspace: Control = app.body_scroll if is_instance_valid(app.body_scroll) else app.body
		end=workspace.get_global_transform_with_canvas()*workspace.size
		_check(end.x<=logical.x+1 and end.y<=logical.y+1,"Page fits client: "+name+" "+str(end))
		_check(app.body.size.x<=workspace.size.x+1,"Page content fits workspace width: "+name)
	for dialog in app.get_children():
		if not dialog is AcceptDialog or not dialog.visible:continue
		var client:Vector2=get_tree().root.get_visible_rect().size
		_check(Vector2(dialog.size).x<=client.x and Vector2(dialog.size).y<=client.y,"Dialog fits client: "+name)
		var ok:Button=dialog.get_ok_button()
		_check(ok.is_visible_in_tree() and ok.get_global_rect().end.y<=dialog.size.y,"Dialog confirmation is visible: "+name)
		if dialog is ConfirmationDialog:
			var cancel:Button=dialog.get_cancel_button()
			_check(cancel.is_visible_in_tree() and cancel.get_global_rect().end.y<=dialog.size.y,"Dialog cancel is visible: "+name)
	if captures.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image:=get_tree().root.get_texture().get_image()
	_check(image.get_size()==DisplayServer.window_get_size(),"Native capture dimensions "+name)
	_check(image.save_png(captures.path_join(name+".png"))==OK,"Capture saved "+name)

func _coverage() -> void:
	await _ask("auto_lineup")
	if app.model.get("selection",{}).get("valid",true):return
	# This real paid action repairs injuries and qualified bench shortages.
	await _ask("promote_cover",{"confirmed":true})
	_dismiss()
	_check(app.model.get("selection",{}).get("valid",false),"Native promotions restore legal selection")

func _coach_reception() -> void:
	_check(is_instance_valid(app.coach), "Shipped executable contains the native coach")
	if not is_instance_valid(app.coach): return
	app._navigate("Bureau")
	await _ask("export")
	var before: String = app.model.meta.exportText
	var profile: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var disk_before := FileAccess.get_sha256(profile)
	var requests: Array[String] = []
	var events := {"starts":0, "ends":0}
	app.coach.speech.requested.connect(func(text: String): requests.append(text))
	app.coach.speech.started.connect(func(_id: int): events.starts += 1)
	app.coach.speech.ended.connect(func(_id: int): events.ends += 1)
	# Audio runs at volume zero only in this disposable reception profile.
	app.coach.speech.volume = 0
	app.coach.open_help()
	await _settle()
	_check(app.coach.expanded, "Coach opens from the actual app")
	_check(app.root_content.offset_bottom == 0 and app.coach.mouse_filter == Control.MOUSE_FILTER_IGNORE and app.coach.size.x <= 500, "Coach floats without reserving or intercepting the workspace")
	_check(app.coach.portrait.texture is AtlasTexture and app.coach.portrait.texture.atlas != null, "Exported atlas is loaded")
	await _capture("coach-developpe")
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://guide/dialogues.json"))
	var recordings := 0
	var shortest_text := ""
	var shortest_length := INF
	for page: Dictionary in content.pages:
		for fragment: Dictionary in page.fragments:
			var text := str(fragment.text)
			_check(app.coach.speech.has_recording(text), "Exact exported recording exists: " + str(fragment.id))
			if not app.coach.speech.has_recording(text): continue
			var stream := ResourceLoader.load(str(app.coach.speech.clips[text])) as AudioStreamWAV
			_check(stream != null and stream.get_length() > 0.5, "Imported PCK audio decodes: " + str(fragment.id))
			if stream == null: continue
			recordings += 1
			if stream.get_length() < shortest_length:
				shortest_length = stream.get_length(); shortest_text = text
	_check(recordings == 38 and app.coach.speech.clips.size() == 38, "All 38 exported recordings received without relying on system TTS")
	var available: bool = recordings > 0 or not app.coach.speech.voice_id.is_empty()
	if OS.get_environment("CD_GODOT_REQUIRE_TTS") == "1": _check(available, "French speech required for this Windows reception")
	if available:
		_check(not requests.is_empty() and requests.back() == app.coach.bubble.text, "Spoken text equals the actual bubble")
		var deadline := Time.get_ticks_msec() + 8000
		while events.starts == 0 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		_check(events.starts > 0 and app.coach.speech.speaking, "Real exported speech starts")
		_check(app.coach.speech.player.playing and app.coach.speech.player.stream is AudioStreamWAV, "Real local Gabi recording plays in the executable")
		var frames := {}
		deadline = Time.get_ticks_msec() + 650
		while Time.get_ticks_msec() < deadline:
			frames[str(app.coach.portrait.frame_texture.region)] = true
			await get_tree().process_frame
		_check(frames.size() >= 2, "Actual speaking portrait changes frames")
		# Play an actual shipped fragment through its natural end callback.
		app.coach.bubble.text = shortest_text
		app.coach.replay()
		var previous_end: int = events.ends
		deadline = Time.get_ticks_msec() + int(shortest_length * 2000) + 3000
		while events.ends == previous_end and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		_check(events.ends > previous_end and not app.coach.speech.speaking, "Real exported recording finishes naturally")
		_check(requests.back() == app.coach.bubble.text, "Replay uses the same bubble")
	app.coach.close()
	app.coach.speech.volume = 75
	_check(not app.coach.speech.speaking, "Closing the exported coach stops speech")
	await _ask("export")
	_check(app.model.meta.exportText == before and FileAccess.get_sha256(profile) == disk_before, "Coach leaves the actual career and its disk unchanged")
	coach_reception = {"voice_available":available,"recordings_decoded":recordings,"recording_played_to_end":shortest_text,"voice":app.coach.speech.voice_id,"starts":events.starts,"ends":events.ends,"test_volume":0,"separate_profile":FileAccess.file_exists(str(app.model.meta.dataDir).path_join("guide.json"))}
	await _capture("coach-integre")

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
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
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
	_check(app.model.get("meta",{}).get("mode")=="common" and int(app.model.club.id)==29,"Actual common30-club career created through UI")
	_check(app.model.get("meta",{}).get("database",{}).get("playerCount")==1592,"Shared source retains1592players")
	_check(app.model.meta.get("rosterFoundation",{}).get("version") == 2, "Shipped registry initializes new careers in v2")
	if not app._has_career():await _finish();return
	_check(app.model.get("squad",[]).size()>=23,"Real squad for club29")
	_check(app.model.get("leagues",[]).size()==2,"Both divisions projected")
	await _coach_reception()
	for resolution in [Vector2i(1280,800),Vector2i(1440,900),Vector2i(1920,1080)]:
		if DisplayServer.get_name()=="headless":get_tree().root.size=resolution
		else:DisplayServer.window_set_size(resolution)
		for page in ["Bureau","Effectif","Composition","Préparation","Calendrier","Classements","Recrutement","Formation","Staff","Finances","Club","Match"]:
			app._navigate(page)
			await _capture(page.to_lower()+"-"+str(resolution.x))
			_keyboard_focus()
	# Submit a real offer through the contract dialog rather than a synthetic UI value.
	app._navigate("Recrutement")
	for candidate in app.model.get("market",[]):
		if not candidate.get("available",false):continue
		app.SquadViews.contract(app,candidate,true)
		await _capture("offre-contrat")
		var d:ConfirmationDialog=null
		for child in app.get_children():
			if child is ConfirmationDialog and child.visible:d=child
		_check(d!=null,"Contract offer is explicit before signature")
		if d!=null:
			var fields:Array=d.find_children("*","SpinBox",true,false)
			if not fields.is_empty():fields[0].value=minf(100000,float(candidate.salary)*2)
			_confirm()
			await _wait()
			_check(app.bridge.last_response_ok,"Native negotiation returns through UI")
			var signed:bool=app.model.get("squad",[]).any(func(p):return p.id==candidate.id)
			var response:Dictionary=app.model.meta.get("negotiation",{})
			_check(signed== (response.get("status")=="signed"),"Only confirmed negotiation adds recruited player")
			_dismiss()
		break
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
	if not app.model.get("selection",{}).get("valid",true):
		app._navigate("Composition")
		_press("COMPLÉTER AVEC LE CENTRE DE FORMATION")
		await _capture("renforts-confirmation")
		_confirm()
		await _wait()
		_check(app.bridge.last_response_ok and app.model.selection.valid,"Explicit paid promotions restore initial source coverage")
		_dismiss()
	var tactics:Dictionary=app.model.get("tactics",{})
	for option in tactics.get("attacks",[]):
		if option.id!=tactics.get("attack"):
			await _ask("set_tactics",{"attack":option.id,"defense":tactics.defense})
			_check(app.model.tactics.attack==option.id,"Attack decision persisted")
			break
	app._navigate("Préparation")
	_press("CHARGE NORMALE")
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
	_check(app.model.live!=null,"Second actual match starts without navigating away: "+app.last_error)
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
	if not app.model.meta.get("canAdvanceSeason",false):await _finish();return
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
	var legacy_fixture := OS.get_environment("CD_GODOT_QA_V1_FIXTURE")
	if not legacy_fixture.is_empty():
		var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(legacy_fixture))
		app.import_mode = true
		app._file_selected(legacy_fixture)
		_confirm(); await _wait()
		_check(app.bridge.last_response_ok and app.model.meta.get("rosterFoundation",{}).get("version") == 1, "Actual shipped UI imports the genuine v1 career without migration")
		await _ask("export")
		var observed: Dictionary = JSON.parse_string(app.model.meta.exportText)
		_check(observed.state == legacy.state, "Actual v1 player profiles, contracts and progress remain exact")
		_dismiss()
		app.import_mode = true
		app._file_selected(exported)
		_confirm(); await _wait()
		_check(app.bridge.last_response_ok and app.model.meta.get("rosterFoundation",{}).get("version") == 2, "Actual shipped UI restores its v2 season2 career")
		_dismiss()
	await _finish()

func _finish() -> void:
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	app.bridge.stop()
	var deadline:=Time.get_ticks_msec()+2500
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	_check(app.bridge.child_pid<=0,"Owned worker stopped")
	var final_club:Dictionary=app.model.club if app.model.get("club") is Dictionary else {}
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_display":DisplayServer.get_name(),"captures":captures,"pid":OS.get_process_id(),"engine_pid":engine_pid,"executable":OS.get_executable_path(),"season":app.model.get("meta",{}).get("season"),"club":final_club.get("id"),"coach":coach_reception,"layout":layout_reception}
	if not captures.is_empty():
		var file:=FileAccess.open(captures.path_join("report.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
