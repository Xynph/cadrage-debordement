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
var systems_reception: Dictionary = {}
var file_reception: Dictionary = {}
var native06_reception: Dictionary = {}
var world_reception: Dictionary = {}

func _ready() -> void:call_deferred("_run")

func _check(value:bool,message:String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func _settle() -> void:
	for i in 5:await get_tree().process_frame

func _resize_window(resolution: Vector2i) -> void:
	var window := get_tree().root
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var deadline := Time.get_ticks_msec() + 2000
	if DisplayServer.get_name() != "headless":
		while DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Windowed mode settled before resizing")
	await _settle()
	window.size = resolution
	DisplayServer.window_set_size(resolution)
	var expected := resolution
	deadline = Time.get_ticks_msec() + 2000
	while (window.size != resolution or window.content_scale_size != expected) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(window.size == resolution and window.content_scale_size == expected, "Actual window and adaptive reference settled: " + str(resolution))
	# The production controller debounces its container/focus update by 80 ms.
	await get_tree().create_timer(.15).timeout
	await _settle()

func _display_reception() -> void:
	if DisplayServer.get_name() != "Windows":
		print("SKIP physical fullscreen/windowed reception: ",DisplayServer.get_name())
		return
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Windows starts in standard fullscreen before any resize")
	await _capture("accueil-plein-ecran")
	app.settings()
	await _settle()
	var dialog: AcceptDialog = app.find_child("PreferencesDialog",true,false)
	var tabs: TabContainer = dialog.find_child("PreferencesTabs",true,false)
	_check(tabs != null and tabs.get_tab_count() == 3,"Bundled preferences contain all three sections")
	if tabs != null: tabs.current_tab = 2
	await _settle()
	var windowed: Button = dialog.find_child("PreferencesWindowed",true,false)
	var fullscreen: Button = dialog.find_child("PreferencesFullscreen",true,false)
	_check(windowed != null and fullscreen != null,"Actual preferences expose both display modes")
	if windowed != null and fullscreen != null:
		for button in [windowed,fullscreen]:
			button.grab_focus()
			for down in [true,false]:
				var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
				Input.parse_input_event(event)
				await get_tree().process_frame
			await get_tree().create_timer(.2).timeout
			await _settle()
			var expected := DisplayServer.WINDOW_MODE_WINDOWED if button == windowed else DisplayServer.WINDOW_MODE_FULLSCREEN
			_check(DisplayServer.window_get_mode() == expected,"Actual keyboard display action switches mode: " + str(button.name))
			if button == windowed: _check(DisplayServer.window_get_size() == Vector2i(1440,900),"Actual windowed option is 1440x900")
			_check(button.has_focus(),"Display action retains keyboard focus: " + str(button.name))
			_check(button.is_visible_in_tree() and button.get_global_rect().end.y <= dialog.size.y,"Display action remains visible: " + str(button.name))
			await _capture("parametres-fenetre" if button == windowed else "parametres-plein-ecran")
	_dismiss()
	await _settle()

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

func _press_named(control_name: String, parent: Node = null) -> bool:
	var scope: Node = parent if parent != null else app.root_content
	var button := scope.find_child(control_name,true,false) as Button
	var available := button != null and button.is_visible_in_tree() and not button.disabled
	_check(available,"Visible action: " + control_name)
	if available: button.pressed.emit()
	return available

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
	# Compare canvas units with the real viewport, including the native1440p
	# reference; never infer its dimensions from a former stretch reference.
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
	var pending := 0
	var shortest_text := ""
	var shortest_length := INF
	for page: Dictionary in content.pages:
		for fragment: Dictionary in page.fragments:
			var text := str(fragment.text)
			if fragment.get("audioStatus") == "pending":
				pending += 1
				_check(not app.coach.speech.has_recording(text), "Pending text never uses an old recording: " + str(fragment.id))
				continue
			_check(app.coach.speech.has_recording(text), "Exact exported recording exists: " + str(fragment.id))
			if not app.coach.speech.has_recording(text): continue
			var stream := ResourceLoader.load(str(app.coach.speech.clips[text])) as AudioStreamWAV
			_check(stream != null and stream.get_length() > 0.5, "Imported PCK audio decodes: " + str(fragment.id))
			if stream == null: continue
			recordings += 1
			if stream.get_length() < shortest_length:
				shortest_length = stream.get_length(); shortest_text = text
	_check(recordings == 74 and app.coach.speech.clips.size() == 74 and app.coach.speech.has_complete_recordings(), "All 74 final recordings received without relying on system TTS")
	_check(pending == 0, "All final texts have an exact received recording")
	var available: bool = recordings > 0 or not app.coach.speech.voice_id.is_empty()
	if OS.get_environment("CD_GODOT_REQUIRE_TTS") == "1": _check(available, "French speech required for this Windows reception")
	if available:
		# Receive actual playback of a shipped clip in addition to decoding all
		# final recordings from the exported PCK above.
		app.coach.bubble.text = shortest_text
		app.coach.replay()
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
	coach_reception = {"voice_available":available,"voice_status":"complete" if app.coach.speech.has_complete_recordings() else "provisional","recordings_pending":pending,"recordings_decoded":recordings,"recording_played_to_end":shortest_text,"voice":app.coach.speech.voice_id,"starts":events.starts,"ends":events.ends,"test_volume":0,"separate_profile":FileAccess.file_exists(str(app.model.meta.dataDir).path_join("guide.json"))}
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
	await _display_reception()
	if OS.get_environment("CD_GODOT_QA_JAPAN") == "1":
		var japan: Node = preload("res://qa_japan.gd").new()
		add_child(japan)
		await japan.run(self)
		await _finish()
		return
	if OS.get_environment("CD_GODOT_QA_PACIFIC") == "1":
		await _pacific_reception()
		await _finish()
		return
	if OS.get_environment("CD_GODOT_QA_WORLD") == "1":
		await _world_reception()
		await _finish()
		return
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await _resize_window(resolution)
		app._navigate("Accueil")
		await _capture("accueil-"+str(resolution.x))
		app._navigate("Création")
		_press_named("CreationMode_common")
		_press_named("CreationDivision_accession")
		app.selected_club=29
		app._render()
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
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await _resize_window(resolution)
		var pages: Array[String] = []
		app._navigate("Bureau")
		_press_named("ImmersiveSearch")
		await _settle()
		var palette: AcceptDialog = app.navigation_controller.get("_dialog")
		_check(is_instance_valid(palette) and palette.visible, "Bundled navigation opens its real palette")
		if is_instance_valid(palette) and palette.visible:
			var bounds := Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)
			_check(bounds.encloses(Rect2(Vector2(palette.position),Vector2(palette.size))), "Palette position and size fit the actual client")
			var confirmation := palette.get_ok_button()
			var confirmation_rect := confirmation.get_global_rect()
			confirmation_rect.position += Vector2(palette.position)
			_check(confirmation.is_visible_in_tree() and bounds.encloses(confirmation_rect), "Palette OPEN action is entirely inside the client")
			await _capture("recherche-"+str(resolution.x))
			palette.hide()
		for chapter: Dictionary in app.NAV_CHAPTERS:
			for page: String in chapter.routes: pages.append(page)
		_check(pages.size() == 21 and pages.has("Réception"), "Every native career route, including the inbox, is included in the executable reception")
		for page in pages:
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
	_press_named("Nav_Entraînement")
	await _settle()
	_press_named("TrainingValidateWeek")
	await _settle()
	var session: AcceptDialog = app.get_node_or_null("TrainingSessionDialog")
	_check(session != null and session.visible, "Weekly training requires an explicit load choice")
	if session != null: _press_named("PreparationTrain_normal", session)
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
	await _systems_reception()
	await _readonly_export_reception()
	await _finish()

func _readonly_export_reception() -> void:
	var destination := OS.get_environment("CD_GODOT_QA_DENIED_EXPORT")
	if destination.is_empty():
		file_reception = {"executed":false}
		return
	_check(destination.is_absolute_path() and FileAccess.file_exists(destination), "Readonly export fixture is explicit and already exists")
	if not destination.is_absolute_path() or not FileAccess.file_exists(destination): return
	var original := FileAccess.get_file_as_bytes(destination)
	var profile := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(profile)
	app.import_mode = false
	app._file_selected(destination)
	await _wait()
	await _settle()
	var visible_refusal: bool = app.last_error.contains("refus") and is_instance_valid(app.status) and app.status.text.contains("ACTION NON EFFECTUÉE")
	var original_preserved := FileAccess.get_file_as_bytes(destination) == original
	var profile_preserved := FileAccess.get_sha256(profile) == before
	_check(visible_refusal, "Bundled atomic replacement reports a real readonly refusal")
	_check(original_preserved, "Readonly destination retains every original byte")
	_check(profile_preserved, "Failed native UI export never changes the career profile")
	await _capture("export-refuse")
	file_reception = {"executed":true,"readonly_export":visible_refusal,"original_preserved":original_preserved,"profile_preserved":profile_preserved}
	_dismiss()
	await _ask("snapshot")

func _systems_reception() -> void:
	# Exercise the actual relocated engine and resources, after the full season.
	# These are real, visible decisions in the disposable S2 reception career.
	var initial_failures := failures.size()
	var domains := ["press","relationships","clubWorld","academyPathways","clubStrategy","clubSupport","managerCareer","playbook","coachNotebook"]
	for domain in domains:
		_check(app.model.get("clubLife",{}).has(domain), "Bundled engine projects native domain: " + domain)
	await _native06_reception()
	var professional_ids: Array = app.model.squad.map(func(p: Dictionary): return str(p.id))
	app._navigate("Centre")
	_press("ACTIVER LES PARCOURS")
	await _settle()
	_confirm()
	await _wait()
	_check(app.model.clubLife.academyPathways.active, "Actual exported UI activates academy pathways")
	_check(app.model.squad.map(func(p: Dictionary): return str(p.id)) == professional_ids, "Academy activation preserves the professional roster")
	await _capture("centre-parcours-s2")
	var press: Dictionary = app.model.clubLife.press
	var five_tones: bool = press.conference.available
	_check(press.people.size() == 30, "Bundled press retains all thirty journalists")
	if press.conference.available:
		var answers: Array = []
		for question: Dictionary in press.conference.questions:
			five_tones = five_tones and question.answers.size() == 5 and question.answers.any(func(a: Dictionary): return str(a.id) == "r4" and str(a.toneLabel) == "Humour")
			_check(question.answers.size() == 5, "Every executable conference question offers five tones")
			_check(question.answers.any(func(a: Dictionary): return str(a.id) == "r4" and str(a.toneLabel) == "Humour"), "The fifth response is the actual Humour tone")
			answers.append({"questionId":question.id,"answerId":"r4"})
		await _ask("press_conference", {"context":press.context,"answers":answers})
		_check(app.model.clubLife.press.lastOutcome != null, "Bundled conference persists its actual outcome")
	else:
		_check(false, "S2 reception has a real conference available")
	app._navigate("Presse")
	var press_tabs: TabContainer = app.root_content.find_child("PressTabs",true,false)
	_check(press_tabs != null and press_tabs.get_tab_count() == 4, "Exported press exposes Journal, Conference, History and Relations")
	if press_tabs != null: press_tabs.current_tab = 3
	await _capture("presse-relations-s2")
	var support: Dictionary = app.model.clubLife.clubSupport
	await _ask("staff_meeting", {"context":support.context,"plan":"cohesion"})
	_check(app.model.clubLife.clubSupport.meeting.lastDecision != null, "Bundled staff meeting records its weekly decision")
	var strategy: Dictionary = app.model.clubLife.clubStrategy
	await _ask("club_board_priority", {"context":strategy.context,"key":"effectif"})
	_check(app.model.clubLife.clubStrategy.board.priority == "effectif", "Bundled board priority is applied")
	var playbook: Dictionary = app.model.clubLife.playbook
	_check(playbook.zones.size() == 4, "Bundled playbook exposes four field zones")
	var zone: String = str(playbook.zones[0].id)
	var attack: String = str(playbook.attackOptions[1].id)
	await _ask("playbook_set", {"context":playbook.context,"key":"attack","zone":zone,"value":attack})
	_check(app.model.clubLife.playbook.zones[0].attack == attack, "Bundled local tactical instruction persists")
	await _ask("export")
	var before: String = app.model.meta.exportText
	_check(app.user_preferences.set_value("volume",40), "Bundled atomic helper saves local volume")
	_check(app.user_preferences.set_value("camera","action"), "Bundled atomic helper saves preferred camera")
	_check(app.user_preferences.set_value("quality","economy"), "Bundled atomic helper saves visual quality")
	app._navigate("Match")
	await _settle()
	_check(app.match_view._camera_mode == "action" and app.match_view._quality == "economy", "Exported scene applies the saved camera and quality")
	_check(app.user_preferences.set_value("reduced_motion",true), "Bundled calm preference is saved")
	_check(app.match_view._camera_mode == "tactical", "Exported calm mode uses a fixed tactical camera")
	_check(app.user_preferences.set_value("reduced_motion",false), "Bundled calm mode can be disabled")
	_check(app.match_view._camera_mode == "action", "Exported scene restores the preferred camera")
	await _ask("export")
	_check(app.model.meta.exportText == before, "Local comfort settings never change the career")
	var before_document: Dictionary = JSON.parse_string(before)
	var profile_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var private_before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	await _ask("import", {"text":before})
	await _ask("export")
	var after_document: Dictionary = JSON.parse_string(app.model.meta.exportText)
	# In the actual application, import advances the wall clock. Only the export
	# envelope date changes; compare every career field and its checksum exactly.
	var exact_import: bool = after_document.state == before_document.state and after_document.checksum == before_document.checksum and after_document.format == before_document.format and after_document.exportVersion == before_document.exportVersion
	_check(exact_import and app.model.clubLife.academyPathways.active, "New native domains survive exact import in the executable")
	var private_after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	_check(private_after.seed == private_before.seed, "Executable import preserves the actual private RNG cursor")
	_check(app.user_preferences.data.camera == "action" and app.user_preferences.data.volume == 40, "Career import preserves the independent local preferences")
	systems_reception = {"passed":failures.size() == initial_failures,"domains":domains,"academy_active":app.model.clubLife.academyPathways.active,"press_five_tones":five_tones,"staff_decision":app.model.clubLife.clubSupport.meeting.lastDecision != null,"board_priority":app.model.clubLife.clubStrategy.board.priority,"atomic_preferences":app.user_preferences.data.camera == "action" and app.user_preferences.data.volume == 40,"exact_import":exact_import,"rng_preserved":private_after.seed == private_before.seed}

func _world_match(expected_competition: String) -> bool:
	for week in 12:
		if app.model.get("next") is Dictionary: break
		if not await _ask("finish_round"): return false
	var next: Variant = app.model.get("next")
	_check(next is Dictionary and next.get("competitionId") == expected_competition,"Actual fixture: " + expected_competition)
	if not next is Dictionary or next.get("competitionId") != expected_competition: return false
	if not app.model.selection.valid:
		await _ask("auto_lineup")
		if not app.model.selection.valid and not await _ask("promote_cover",{"confirmed":true}): return false
	if not await _ask("begin_match"): return false
	app.timer.stop()
	app._navigate("Match")
	await _capture("monde-match-" + expected_competition)
	if not await _ask("delegate"): return false
	_check(app.model.live is Dictionary and app.model.live.finished,"Native rugby match finishes: " + expected_competition)
	if not await _ask("finish_round"): return false
	var recorded: bool = app.model.history.any(func(r): return r.get("competitionId") == expected_competition and r.get("pair", []).has(app.model.club.id) and r.get("stats") is Array)
	_check(recorded,"Competition-specific result and match statistics recorded")
	return recorded

func _world_creation(club_id: int, league: String, edition: String = "world") -> bool:
	app._navigate("Création")
	await _settle()
	if not _press_named("CreationMode_" + edition): return false
	await _settle()
	if not _press_named("CreationDivision_" + league): return false
	await _settle()
	if not _press_named("CreationClub" + str(club_id)): return false
	await _settle()
	var replacing: bool = app._has_career()
	if not _press_named("CreationStart"): return false
	if replacing:
		await _settle()
		_confirm()
	await _wait()
	var created: bool = app.model.get("club") is Dictionary and int(app.model.club.id) == club_id and app.model.meta.mode == "world" and app.model.meta.get("edition","world") == edition
	_check(created,"World career created through actual club picker")
	return created

func _world_reception() -> void:
	var pack := OS.get_environment("CD_GODOT_WORLD_PACK")
	_check(not pack.is_empty() and FileAccess.file_exists(pack),"Private world pack supplied to the disposable test profile")
	if pack.is_empty() or not FileAccess.file_exists(pack): return
	if not await _ask("pack_inspect",{"path":pack,"mode":"world"}): return
	var preview: Dictionary = app.model.packs.preview
	_check(int(preview.counts.clubs) == 58 and int(preview.counts.players) == int(app.model.meta.worldDatabase.playerCount) and int(preview.counts.staff) >= 808,"Full world pack reconciled with bundled catalogue")
	if not await _ask("pack_install",{"path":pack,"digest":preview.digest}): return
	if not await _ask("pack_select",{"id":preview.id,"scope":"creation","mode":"world"}): return
	if not await _world_creation(30,"prem"): return
	_check(app.model.packs.career == preview.id and FileAccess.file_exists(app.model.club.get("logoPath","")),"Installed real club logo selected by default in the test career")
	_check(app.model.staff.teams.size() == 58 and app.model.leagues.size() == 6,"World staff and all competitions exposed")
	_check(app.model.squad.any(func(p): return FileAccess.file_exists(p.get("portraitPath",""))),"Actual squad portrait assets resolve on disk")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await _resize_window(resolution)
		for route_name in ["Création","Bureau","Effectif","Calendrier","Classements","Staff"]:
			app._navigate(route_name)
			await _capture("monde-" + route_name.to_lower() + "-" + str(resolution.x))
	if not await _world_match("prem"): return
	if not await _world_creation(40,"urc"): return
	if not await _world_match("urc"): return
	var euro := OS.get_environment("CD_GODOT_WORLD_EURO_EXPORT")
	var final_doc := OS.get_environment("CD_GODOT_WORLD_FINAL_EXPORT")
	_check(FileAccess.file_exists(euro) and FileAccess.file_exists(final_doc),"Both exact-season career checkpoints supplied")
	if not FileAccess.file_exists(euro) or not FileAccess.file_exists(final_doc): return
	if not await _ask("import",{"text":FileAccess.get_file_as_string(euro)}): return
	if not await _world_match("champions"): return
	# Exercise the actual file picker handler, not just the engine import command.
	var file := FileAccess.open(final_doc,FileAccess.READ)
	if file == null: return
	var final_size := file.get_length()
	file.close()
	_check(final_size > 8 * 1024 * 1024,"World season checkpoint exceeds the historical limit")
	app.open_file(true)
	app.file_dialog.hide()
	app.file_dialog.file_selected.emit(final_doc)
	await _settle()
	_confirm()
	await _wait()
	_check(app.bridge.last_response_ok and app.model.meta.canAdvanceSeason,"File picker restores a finished world season")
	if not app.model.meta.canAdvanceSeason: return
	if not await _ask("next_season",{"confirmed":true}): return
	_check(int(app.model.meta.season)==2 and app.model.archives.seasons.size()==1,"Interseason, promotions and European qualification run in the exported app")
	app._navigate("Classements")
	await _capture("monde-intersaison-2560")
	world_reception={"passed":failures.is_empty(),"pack":preview.counts,"competitions_played":["prem","urc","champions"],"season_export_bytes":final_size,"second_season":int(app.model.meta.season)}

func _pacific_reception() -> void:
	var pack := OS.get_environment("CD_GODOT_PACIFIC_PACK")
	var final_doc := OS.get_environment("CD_GODOT_PACIFIC_FINAL_EXPORT")
	var complete := OS.get_environment("CD_GODOT_PACIFIC_EXPECT_COMPLETE") == "1"
	_check(FileAccess.file_exists(pack) and FileAccess.file_exists(final_doc), "Pack and completed Pacific career supplied")
	if not FileAccess.file_exists(pack) or not FileAccess.file_exists(final_doc): return
	app._navigate("Création")
	await _settle()
	_check(app.pack_manager.mode("creation") == "world-pacific", "Pacific edition is the new career default")
	app.pack_manager.open("creation")
	await _settle()
	app.pack_manager.picker.file_selected.emit(pack)
	if not await _wait(): return
	var preview: Dictionary = app.pack_manager.preview()
	_check(not preview.is_empty(), "File picker inspects the Pacific archive in its own edition")
	if preview.is_empty(): return
	var counts: Dictionary = preview.counts
	_check(int(counts.clubs) == 68 and int(counts.logos) == 68 and int(counts.players) == 3589 and int(counts.staff) == 947, "Pacific pack has the exact merged catalogues")
	if complete:
		_check(int(counts.official + counts.synthetic) == 3589 and int(counts.staffOfficial + counts.staffSynthetic) == 947, "All player and staff portraits resolve in the release pack")
	app.pack_manager.install()
	if not await _wait() or not app.bridge.last_response_ok:
		_check(false,"Pacific pack installs through the native pack page")
		return
	app.pack_manager.select(preview.id,"creation")
	if not await _wait() or not app.bridge.last_response_ok:
		_check(false,"Pacific pack is selected for creation")
		return
	if not await _world_creation(58,"srp","world-pacific"): return
	_check(app.model.meta.worldCatalogue.size() == 58 and app.model.meta.pacificCatalogue.size() == 68 and app.model.leagues.size() == 7, "Both editions and five domestic leagues stay distinct")
	_check(app.model.packs.career == preview.id and FileAccess.file_exists(app.model.club.get("logoPath","")) and app.model.staff.teams.size() == 68, "Real club identity and staff are attached to the career")
	_check(app.model.squad.any(func(p): return FileAccess.file_exists(p.get("portraitPath",""))), "Squad has decoded pack portraits")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await _resize_window(resolution)
		for route_name in ["Création","Bureau","Effectif","Calendrier","Classements","Rivalités","Staff"]:
			app._navigate(route_name)
			await _capture("pacifique-" + route_name.to_lower() + "-" + str(resolution.x))
			if route_name == "Création":
				var list := app.find_child("CreationClubsScroll",true,false) as ScrollContainer
				var last := app.find_child("CreationClub67",true,false) as Button
				_check(last != null and list != null and list.get_global_rect().encloses(last.get_global_rect()), "All ten Pacific clubs are visible without changing page at " + str(resolution.x))
	app._navigate("Rivalités")
	await _settle()
	for i in 6:
		if app.model.get("next") is Dictionary: break
		if not _press_named("PacificPreparationAdvance"): return
		if not await _wait() or not app.bridge.last_response_ok:
			_check(false, "Pacific preparation progresses from the real button")
			return
	_check(int(app.model.meta.week) == 23 and app.model.next is Dictionary and app.model.next.date == "2027-02-13", "Preparation stops before the first official match of the selected Pacific club")
	if not await _world_match("srp"): return
	var file := FileAccess.open(final_doc,FileAccess.READ)
	if file == null:
		_check(false, "Pacific checkpoint readable")
		return
	var final_size := file.get_length()
	file.close()
	_check(final_size > 8 * 1024 * 1024 and final_size <= 16 * 1024 * 1024,"Pacific checkpoint uses the world transport limit")
	app.open_file(true)
	app.file_dialog.hide()
	app.file_dialog.file_selected.emit(final_doc)
	await _settle()
	_confirm()
	await _wait()
	_check(app.bridge.last_response_ok and app.model.meta.canAdvanceSeason and app.model.meta.edition == "world-pacific", "Native file picker loads the completed Pacific season")
	if not app.model.meta.canAdvanceSeason: return
	if not await _ask("next_season",{"confirmed":true}): return
	_check(int(app.model.meta.season) == 2 and app.model.archives.seasons.size() == 1 and app.model.leagues.size() == 7, "Pacific season two and annual European qualification are live")
	if not await _ask("export"): return
	var before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	before.erase("identityPack")
	if not await _ask("pack_select",{"id":preview.id,"scope":"career","mode":"world-pacific"}): return
	_check(app.model.packs.career == preview.id, "Pacific pack can be attached in an existing career")
	if not await _ask("export"): return
	var after: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	after.erase("identityPack")
	_check(before == after, "Changing presentation keeps all simulation state")
	app._navigate("Classements")
	await _capture("pacifique-intersaison-2560")
	world_reception = {"passed":failures.is_empty(),"edition":"world-pacific","pack":counts,"pack_complete_requested":complete,"competitions_played":["srp"],"season_export_bytes":final_size,"second_season":int(app.model.meta.season)}

func _finish() -> void:
	app.closing = true
	app.timer.stop()
	if is_instance_valid(app.coach): app.coach.destroy()
	if is_instance_valid(app.soundscape): app.soundscape.dispose()
	app.bridge.stop()
	var deadline:=Time.get_ticks_msec()+2500
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	_check(app.bridge.child_pid<=0,"Owned worker stopped")
	var final_club:Dictionary=app.model.club if app.model.get("club") is Dictionary else {}
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_display":DisplayServer.get_name(),"captures":captures,"pid":OS.get_process_id(),"engine_pid":engine_pid,"executable":OS.get_executable_path(),"season":app.model.get("meta",{}).get("season"),"club":final_club.get("id"),"coach":coach_reception,"layout":layout_reception}
	result.systems = systems_reception
	result.files = file_reception
	result.native06 = native06_reception
	result.world = world_reception
	if not captures.is_empty():
		var file:=FileAccess.open(captures.path_join("report.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

func _key_action(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "Native06 keyboard target is visible")
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return
	control.grab_focus()
	await _settle()
	_check(control.has_focus(), "Native06 action has keyboard focus: " + str(control.name))
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != app:
		if ancestor is ScrollContainer:
			_check(ancestor.get_global_rect().encloses(control.get_global_rect()), "Native06 keyboard action fits its real scroll viewport: " + str(control.name))
		ancestor = ancestor.get_parent()
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_ENTER; event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()

func _key_text(line: LineEdit, text: String) -> void:
	line.grab_focus(); await _settle()
	# Enter ends editing in Godot 4.7 while retaining focus. Re-enter by keyboard.
	if not line.is_editing(): await _key_action(line)
	line.select_all()
	for character in text:
		for down in [true,false]:
			var event := InputEventKey.new()
			event.keycode = character.unicode_at(0); event.unicode = character.unicode_at(0); event.pressed = down
			Input.parse_input_event(event)
			await get_tree().process_frame
	await _settle()

func _native06_reception() -> void:
	var initial_failures := failures.size()
	_check(is_instance_valid(app.soundscape) and app.soundscape_ready and app.sound_profile_loaded, "Native06 sound manager and actual profile are loaded")
	if not is_instance_valid(app.soundscape): return
	var assets: Array[String] = []
	for id in app.soundscape.ASSETS:
		var path: String = "res://audio/assets/" + str(app.soundscape.ASSETS[id])
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path) if OS.has_feature("editor") and FileAccess.file_exists(path) else ResourceLoader.load(path) as AudioStreamWAV
		_check(stream != null and stream.get_length() > 0, "Native06 exported WAV decodes: " + str(id))
		if stream != null: assets.append(str(id))
	_check(assets.size() == 6, "Native06 all six original WAVs received")
	app._navigate("Bureau"); await _settle()
	await _key_action(app.root_content.find_child("OpenCoachNotebook",true,false))
	var popup: AcceptDialog = app.get_node_or_null("CoachNotebook")
	_check(popup != null and popup.visible, "Native06 notebook opens from Bureau by keyboard")
	if popup == null: return
	var editor: TextEdit = popup.find_child("CoachNoteText",true,false)
	editor.text = "Mon cap de réception : avancer ensemble. 😀"; editor.text_changed.emit()
	await _key_action(popup.find_child("CoachNoteSave",true,false)); await _wait(); await _settle()
	_check(app.bridge.last_response_ok and app.model.clubLife.coachNotebook.entries.any(func(row): return row.target == "career" and row.text == editor.text), "Native06 career note reaches the actual worker")
	popup.hide(); popup.queue_free(); await _settle()
	var player_id: String = str(app.model.squad[0].id)
	app.selected_player = player_id
	app.management_ui.profile_tab = 0
	app._navigate("Effectif"); await _settle()
	var full_profile := app.root_content.find_child("OpenPlayerFull",true,false) as Button
	if full_profile != null:
		await _key_action(full_profile)
		await _settle()
	await _key_action(app.root_content.find_child("OpenPlayerCoachNote",true,false))
	popup = app.get_node_or_null("CoachNotebook")
	_check(popup != null and popup.visible, "Native06 player note opens from Overview by keyboard")
	if popup == null: return
	var picker: OptionButton = popup.find_child("CoachNoteTarget",true,false)
	_check(str(picker.get_item_metadata(picker.selected)) == player_id, "Native06 player note uses the current stable ID")
	editor = popup.find_child("CoachNoteText",true,false)
	editor.text = "Mon repère personnel sur ce joueur."; editor.text_changed.emit()
	await _key_action(popup.find_child("CoachNoteSave",true,false)); await _wait(); await _settle()
	_check(app.bridge.last_response_ok and app.model.clubLife.coachNotebook.entries.any(func(row): return row.target == player_id and row.text == editor.text), "Native06 player note is persisted by ID")
	popup.hide(); popup.queue_free(); await _settle()
	await _ask("export")
	var before: String = app.model.meta.exportText
	var directory: String = str(app.model.meta.dataDir)
	var private_before := FileAccess.get_file_as_bytes(directory.path_join("donnees.json"))
	var interface_before := FileAccess.get_file_as_bytes(directory.path_join("interface.json")) if FileAccess.file_exists(directory.path_join("interface.json")) else PackedByteArray()
	var master_gain := AudioServer.get_bus_volume_linear(0)
	var master_mute := AudioServer.is_bus_mute(0)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		await _resize_window(resolution)
		app.settings(); await _settle()
		var dialog: AcceptDialog = app.get_node("PreferencesDialog")
		var tabs: TabContainer = dialog.find_child("PreferencesTabs",true,false)
		_check(tabs != null and tabs.get_tab_count() == 3, "Native06 three compact settings tabs")
		var client := Rect2i(Vector2i.ZERO, Vector2i(get_tree().root.get_visible_rect().size))
		var dialog_bounds := Rect2i(dialog.position, dialog.size)
		_check(dialog.visible and client.encloses(dialog_bounds), "Native06 settings fit the actual client: " + str(dialog_bounds))
		_check(dialog.find_child("PreferencesScroll",true,false) == null, "Native06 settings need no global scroll")
		var groups := [["PreferencesVolume","PreferencesMotion","PreferencesCamera","PreferencesQuality","PreferencesReset"],["PreferencesInterfaceVolume","PreferencesStadiumVolume"],["PreferencesFullscreen","PreferencesWindowed"]]
		for index in 3:
			tabs.current_tab = index; await _settle()
			for id: String in groups[index]:
				var control: Control = dialog.find_child(id,true,false)
				_check(control.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(dialog.size)).encloses(control.get_global_rect()), "Native06 setting is entirely visible: " + id)
			tabs.get_tab_bar().grab_focus()
			_check(tabs.get_tab_bar().has_focus(), "Native06 tab bar accepts keyboard focus")
			dialog.get_ok_button().grab_focus()
			_check(dialog.get_ok_button().has_focus() and dialog.get_ok_button().is_visible_in_tree(), "Native06 settings can be closed from every tab")
		tabs.current_tab = 1; await _settle()
		var interface_volume: SpinBox = dialog.find_child("PreferencesInterfaceVolume",true,false)
		var stadium_volume: SpinBox = dialog.find_child("PreferencesStadiumVolume",true,false)
		for pair in [[interface_volume,"interface_volume"],[stadium_volume,"stadium_volume"]]:
			var field: SpinBox = pair[0]
			var line := field.get_line_edit()
			var previous: int = app.soundscape.preferences.get_value(pair[1])
			await _key_text(line,"0")
			_check(app.soundscape.preferences.get_value(pair[1]) == previous, "Native06 sound typing does not write before commit")
			await _key_action(line)
			_check(app.soundscape.preferences.get_value(pair[1]) == 0 and int(field.value) == 0, "Native06 sound zero commits from keyboard")
			_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Interface" if pair[1] == "interface_volume" else "Stade")), "Native06 zero really mutes its independent bus")
			await _key_text(line,"36" if pair[1] == "interface_volume" else "26")
			await _key_action(line)
			_check(app.soundscape.preferences.get_value(pair[1]) == (36 if pair[1] == "interface_volume" else 26), "Native06 sound volume commits from keyboard: " + str(pair[1]) + "=" + str(app.soundscape.preferences.get_value(pair[1])) + ", text=" + line.text)
		dialog.hide(); dialog.queue_free(); await _settle()
	var reloaded = preload("res://audio/sound_preferences.gd").new()
	_check(reloaded.load_profile(directory) and reloaded.get_value("interface_volume") == 36 and reloaded.get_value("stadium_volume") == 26, "Native06 sound.json reloads both persisted channels")
	_check((FileAccess.get_file_as_bytes(directory.path_join("interface.json")) if FileAccess.file_exists(directory.path_join("interface.json")) else PackedByteArray()) == interface_before, "Native06 sound settings leave interface.json byte exact")
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(0),master_gain) and AudioServer.is_bus_mute(0) == master_mute, "Native06 sound settings preserve Master gain and mute")
	await _ask("export")
	_check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(directory.path_join("donnees.json")) == private_before, "Native06 local sound UI leaves career and RNG bytes exact")
	native06_reception = {"passed":failures.size() == initial_failures,"assets":assets,"notes_by_id":true,"settings_tabs":3,"sound_independent":true,"sound_volumes":reloaded.data.duplicate(true)}
