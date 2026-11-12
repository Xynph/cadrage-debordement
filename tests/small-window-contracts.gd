extends SceneTree
const Negotiation = preload("res://ui/contract_negotiation.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const C = preload("res://ui/immersive08/components.gd")
class Host extends Control:
	var management_ui := {}
	var root_content: Control
	var soundscape: Node
	var waiting := false
	var model := {"meta":{"season":1},"finance":{"cash":12500000}}
	func _clear_dialogs() -> void:
		for child in get_children():
			if child is Window: child.queue_free()
	func _prepare_dialog(dialog: AcceptDialog, width: int) -> void: Dialogs.prepare(dialog,width,C.GOLD)
	func _live() -> Dictionary: return {}
	func _command(_command: String, _payload: Dictionary) -> void: pass
	func _set_display_mode(_mode: int) -> void: pass
var output := OS.get_environment("CD_SMALL_CONTRACT_OUTPUT")
var reports: Array = []
var shared_reports: Array = []
var failures: Array = []
var resize_report := {}
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in 8: await process_frame
func rect_data(rect: Rect2) -> Array: return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func overflow(rect: Rect2, bounds: Rect2) -> Array:
	return [maxf(0,bounds.position.x-rect.position.x),maxf(0,bounds.position.y-rect.position.y),maxf(0,rect.end.x-bounds.end.x),maxf(0,rect.end.y-bounds.end.y)]
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.mode=Window.MODE_WINDOWED
	root.gui_embed_subwindows=true
	var host := Host.new();root.add_child(host)
	if OS.get_environment("CD_SMALL_CONTRACT_RESIZE")=="1":
		await open_contract_resize(host)
	else:
		if OS.get_environment("CD_SMALL_CONTRACT_ONLY_SHARED")!="1": await contracts(host)
		if OS.get_environment("CD_SMALL_CONTRACT_SHARED")!="0": await shared_dialogs(host)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"display":DisplayServer.get_name(),"reports":reports,"shared_reports":shared_reports,"resize_report":resize_report,"failures":failures},"  "))
	print("SMALL CONTRACTS: ",failures.size()," failures; report ",output)
	quit(0 if failures.is_empty() else 1)

func contracts(host: Host) -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=resolution
		root.content_scale_size=resolution
		C.configure(resolution.y,resolution.x)
		await settle()
		for recruiting in [true,false]:
			var quote := {"available":true,"salary":14200,"fee":125000,"minYears":1,"maxYears":3,"negotiation":{"status":"counter","attempts":1,"salary":14800,"years":3}}
			var player := {"id":"geometry-contract","name":"Alexandre de Saint-Martin","salary":13500,"contractEnd":2,"renewal":quote}
			if recruiting: player.merge(quote)
			Negotiation.open(host,player,recruiting)
			await settle()
			var dialog := host.find_child("ContractOffer",true,false) as ConfirmationDialog
			var bounds := Rect2(Vector2.ZERO,Vector2(resolution))
			var dialog_rect := Rect2(Vector2(dialog.position),Vector2(dialog.size))
			var title_height := 0 if dialog.borderless else dialog.get_theme_constant("title_height","Window")
			var frame := dialog_rect.grow_individual(0,title_height,0,0)
			var report := {"frame":rect_data(frame),"frame_overflow":overflow(frame,bounds),"resolution":[resolution.x,resolution.y],"recruiting":recruiting,"dialog":rect_data(dialog_rect),"overflow":overflow(dialog_rect,bounds),"controls":[]}
			if report.frame_overflow.max()>1: failures.append("dialog frame "+str(resolution)+" "+str(recruiting))
			if report.overflow.max()>0: failures.append("dialog "+str(resolution)+" "+str(recruiting))
			for id in ["OfferSalary","OfferYears","ContractUseCounteroffer","OfferSummary","ContractNextAction","ok","cancel"]:
				var control: Control = dialog.get_ok_button() if id=="ok" else (dialog.get_cancel_button() if id=="cancel" else dialog.find_child(id,true,false))
				var scroll := control.get_parent()
				while scroll != dialog and not scroll is ScrollContainer: scroll=scroll.get_parent()
				if scroll is ScrollContainer:
					scroll.ensure_control_visible(control);await settle()
				var rect := control.get_global_rect()
				var visible_bounds := Rect2(Vector2.ZERO,Vector2(dialog.size)).intersection(Rect2(-Vector2(dialog.position),Vector2(root.size)))
				if scroll is ScrollContainer: visible_bounds=visible_bounds.intersection(scroll.get_global_rect())
				var outside := overflow(rect,visible_bounds)
				report.controls.append({"name":id,"rect":rect_data(rect),"global_rect":rect_data(Rect2(rect.position+Vector2(dialog.position),rect.size)),"visible_bounds":rect_data(visible_bounds),"overflow":outside})
				if outside.max()>1: failures.append(id+" "+str(resolution)+" "+str(recruiting))
			for child in dialog.find_children("*","ScrollContainer",true,false): child.scroll_vertical=0
			await settle()
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%dx%d-%s.png" % [resolution.x,resolution.y,"recruit" if recruiting else "renew"]))
			reports.append(report)
			dialog.queue_free();await settle()

func measure_shared(dialog: AcceptDialog, label: String, ids: Array[String] = [], capture: bool = true) -> void:
	await settle()
	var bounds := Rect2(Vector2.ZERO,Vector2(root.size))
	var rect := Rect2(Vector2(dialog.position),Vector2(dialog.size))
	var title_height := 0 if dialog.borderless else dialog.get_theme_constant("title_height","Window")
	var frame := rect.grow_individual(0,title_height,0,0)
	var report := {"minimum":[dialog.min_size.x,dialog.min_size.y],"has_requested_size":dialog.has_meta("immersive_dialog_size"),"label":label,"resolution":[root.size.x,root.size.y],"dialog":rect_data(rect),"frame":rect_data(frame),"overflow":overflow(frame,bounds),"controls":[]}
	if report.overflow.max()>1: failures.append(label+" frame "+str(root.size))
	var controls: Array[Control] = [dialog.get_ok_button()]
	for id in ids: controls.append(dialog.find_child(id,true,false))
	if dialog is ConfirmationDialog: controls.append(dialog.get_cancel_button())
	for control in controls:
		var scroll := control.get_parent()
		while scroll != dialog and not scroll is ScrollContainer: scroll=scroll.get_parent()
		if scroll is ScrollContainer:
			scroll.ensure_control_visible(control);await settle()
		var control_rect := control.get_global_rect()
		var visible_bounds := Rect2(Vector2.ZERO,Vector2(dialog.size)).intersection(Rect2(-Vector2(dialog.position),Vector2(root.size)))
		if scroll is ScrollContainer: visible_bounds=visible_bounds.intersection(scroll.get_global_rect())
		var outside := overflow(control_rect,visible_bounds)
		report.controls.append({"name":str(control.name),"rect":rect_data(control_rect),"global_rect":rect_data(Rect2(control_rect.position+Vector2(dialog.position),control_rect.size)),"visible_bounds":rect_data(visible_bounds),"overflow":outside})
		if outside.max()>1: failures.append(label+" "+str(control.name)+" "+str(root.size))
	shared_reports.append(report)
	if capture and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("%dx%d-%s.png" % [root.size.x,root.size.y,label]))

func shared_dialogs(host: Host) -> void:
	var Preferences = load("res://ui/preferences_dialog.gd")
	var profile = load("res://ui/user_preferences.gd").new()
	for resolution in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size=resolution
		root.content_scale_size=resolution
		C.configure(resolution.y,resolution.x)
		await settle()
		var confirmation := ConfirmationDialog.new()
		Dialogs.prepare(confirmation,1540,C.GOLD)
		confirmation.dialog_text="Vérifiez les conditions de votre décision avant de confirmer."
		host.add_child(confirmation)
		Dialogs.show_centered(confirmation,Vector2i(1540,860))
		await measure_shared(confirmation,"confirmation")
		confirmation.queue_free();await settle()
		var picker := FileDialog.new()
		picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE
		picker.access=FileDialog.ACCESS_RESOURCES
		picker.theme=preload("res://ui/immersive08/legacy_style.gd").theme(C.GOLD)
		host.add_child(picker)
		Dialogs.watch_file_picker(picker)
		picker.popup_centered_ratio(.7)
		await measure_shared(picker,"file-picker")
		picker.queue_free();await settle()
		var preferences: AcceptDialog = Preferences.open(host,profile)
		var tabs := preferences.find_child("PreferencesTabs",true,false) as TabContainer
		for tab in 3:
			tabs.current_tab=tab
			var ids: Array[String] = []
			ids.assign([["PreferencesVolume","PreferencesMotion","PreferencesCamera","PreferencesQuality","PreferencesReset"],["PreferencesInterfaceVolume","PreferencesStadiumVolume"],["PreferencesDisplayScreen","PreferencesSalaryPeriod","PreferencesStadiumLighting","PreferencesFullscreen","PreferencesWindowed"]][tab])
			await measure_shared(preferences,"preferences-"+str(tab),ids)
		preferences.queue_free();await settle()
	# The same window must shrink, recenter and recover its preferred width.
	root.size=Vector2i(2560,1440);root.content_scale_size=root.size;await settle()
	var resizable := ConfirmationDialog.new()
	Dialogs.prepare(resizable,1540,C.GOLD)
	resizable.dialog_text="Une décision reste accessible après redimensionnement."
	host.add_child(resizable)
	# Direct popup callers do not record immersive_dialog_size.
	resizable.popup_centered(Vector2i(1540,860))
	await settle()
	for resolution in [Vector2i(1280,720),Vector2i(2560,1440)]:
		root.size=resolution;root.content_scale_size=resolution
		await measure_shared(resizable,"resize")
		if resolution.x==2560 and (resizable.size.x!=1540 or resizable.min_size.x!=1540): failures.append("preferred width restored")
	resizable.queue_free();await settle()

func keyboard_key(dialog: Window, code: int, shift := false, control := false, character := 0) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.unicode=character
	event.shift_pressed=shift
	event.ctrl_pressed=control
	event.pressed=true
	dialog.push_input(event,true)
	event=event.duplicate()
	event.pressed=false
	dialog.push_input(event,true)
	await settle()

func type_salary(dialog: Window, text: String) -> void:
	await keyboard_key(dialog,KEY_A,false,true)
	for character in text:
		await keyboard_key(dialog,character.unicode_at(0),false,false,character.unicode_at(0))

func contract_focus(dialog: Window, controls: Dictionary) -> String:
	var focused := dialog.gui_get_focus_owner()
	if focused==null: return "none"
	for id in controls:
		if controls[id]==focused or controls[id].is_ancestor_of(focused): return id
	return str(focused.get_path())

func open_contract_resize(host: Host) -> void:
	root.size=Vector2i(2560,1440);root.content_scale_size=root.size
	C.configure(1440,2560)
	await settle()
	var player := {"id":"geometry-resize-contract","name":"Alexandre de Saint-Martin","salary":14200,"available":true,"fee":125000,"minYears":1,"maxYears":3,"negotiation":{"status":"counter","attempts":1,"salary":14800,"years":3}}
	Negotiation.open(host,player,true)
	await settle()
	var dialog := host.find_child("ContractOffer",true,false) as ConfirmationDialog
	var salary := dialog.find_child("OfferSalary",true,false) as SpinBox
	var years := dialog.find_child("OfferYears",true,false) as SpinBox
	var edit := salary.get_line_edit()
	var controls := {"salary":salary,"years":years,"reuse":dialog.find_child("ContractUseCounteroffer",true,false),"ok":dialog.get_ok_button(),"cancel":dialog.get_cancel_button()}
	var dialog_id := dialog.get_instance_id()
	var salary_id := salary.get_instance_id()
	var years_id := years.get_instance_id()
	salary.value=18700;years.value=3
	edit.grab_focus()
	await type_salary(dialog,"18900")
	resize_report={"dialog_id":dialog_id,"salary_id":salary_id,"years_id":years_id,"stages":[],"keyboard":{}}
	var expected_value := 18700
	var expected_text := "18900"
	for resolution in [Vector2i(2560,1440),Vector2i(1280,720),Vector2i(2560,1440)]:
		root.size=resolution;root.content_scale_size=resolution
		await settle()
		var state := {"resolution":[resolution.x,resolution.y],"dialog_id":dialog.get_instance_id(),"salary_id":salary.get_instance_id(),"years_id":years.get_instance_id(),"salary_value":salary.value,"salary_text":edit.text,"years":years.value,"focus":contract_focus(dialog,controls)}
		if dialog.get_instance_id()!=dialog_id or salary.get_instance_id()!=salary_id or years.get_instance_id()!=years_id: failures.append("open contract controls recreated during resize")
		if int(salary.value)!=expected_value or int(years.value)!=3 or edit.text!=expected_text: failures.append("salary draft or duration lost during resize "+str(resolution))
		if not edit.has_focus(): failures.append("salary keyboard focus lost during resize "+str(resolution))
		await measure_shared(dialog,"open-contract-resize",["OfferSalary","OfferYears","ContractUseCounteroffer","OfferSummary","ContractNextAction"],false)
		state["geometry"]=shared_reports.back()
		resize_report.stages.append(state)
		if resolution.x==1280:
			await keyboard_key(dialog,KEY_TAB)
			var next := contract_focus(dialog,controls)
			if next=="salary" or next=="none": failures.append("Tab does not leave salary input")
			await keyboard_key(dialog,KEY_TAB,true)
			var previous := contract_focus(dialog,controls)
			if previous!="salary": failures.append("Shift+Tab does not return to salary input")
			var visited: Array[String] = ["salary"]
			for step in 16:
				await keyboard_key(dialog,KEY_TAB)
				var focus := contract_focus(dialog,controls)
				visited.append(focus)
				if focus=="salary": break
			for essential in controls:
				if essential not in visited: failures.append("Tab cannot reach contract control "+essential)
			resize_report.keyboard={"tab":next,"shift_tab":previous,"cycle":visited,"committed_salary":salary.value}
			if int(salary.value)!=18900: failures.append("Tab did not commit typed salary")
			edit.grab_focus()
			await type_salary(dialog,"19100")
			expected_value=18900;expected_text="19100"
	if dialog.size.x!=1540 or dialog.min_size.x!=1540: failures.append("open contract preferred width not restored")
	dialog.queue_free();await settle()
