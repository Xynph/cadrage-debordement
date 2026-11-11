extends "small-window-geometry.gd"
# Additional public UI factories, using the real disposable career projection.
# Confirmation callbacks are never invoked.
func dialogs() -> void:
	app.navigation_controller.open_palette()
	await dialog_measure("navigation-palette")
	if app.decision_feedback != null:
		app.decision_feedback._open()
		await dialog_measure("decision-feedback")
	app.SquadViews.comparison(app)
	await dialog_measure("player-comparison")
	load("res://ui/immersive08/tactics_canvas.gd")._candidates(app,22)
	await dialog_measure("lineup-candidates")
	load("res://ui/immersive08/tactics_canvas.gd")._defense(app)
	await dialog_measure("defense-instructions")
	load("res://ui/immersive08/tactics_canvas.gd")._individual(app,app.model.squad[0])
	await dialog_measure("individual-instructions")
	load("res://ui/decision_views.gd").dossier(app)
	await dialog_measure("opposition-dossier")
	load("res://ui/decision_views.gd").recruitment(app)
	await dialog_measure("recruitment-needs")
	load("res://ui/club_views.gd").season_archives(app)
	await dialog_measure("season-archives")
	var preview: Script = load("res://ui/decision_preview.gd")
	var detail: Dictionary = preview.describe("club_academy_investment",{"amount":4000},app.model)
	if not detail.is_empty():
		preview.open(app,"Préparer la décision","Vérifier les conséquences avant de confirmer.",detail,func():check(false,"Aucune décision de recette ne doit être validée"))
		await dialog_measure("decision-preview")

	load("res://ui/coach_notes_view.gd").open(app)
	await dialog_measure("coach-notebook")
	load("res://ui/regen_scouting_view.gd").open(app)
	await dialog_measure("regen-scouting")
	load("res://ui/youth_development_view.gd").open(app)
	await dialog_measure("youth-development")
	load("res://ui/interclub_market_view.gd").open(app)
	await dialog_measure("interclub-market")
	load("res://ui/competition_editor_view.gd").open(app)
	await dialog_measure("competition-editor")
	if app.model.get("epcrPreparation") is Dictionary:
		load("res://ui/epcr_preparation_dialog.gd").open(app)
		await dialog_measure("epcr-preparation")
	else:
		records.append({"label":"epcr-preparation","resolution":[root.size.x,root.size.y],"status":"not_available_in_common_fixture"})
	app.pack_manager.choose_file()
	await dialog_measure("pack-file-picker",app.pack_manager.picker)
	app.open_profile_safety()
	await dialog_measure("profile-safety")

	if root.size == Vector2i(1280,720):
		app.open_profile_safety(); await settle()
		var popup := app.find_child("ProfileSafety",true,false) as AcceptDialog
		var instance := popup.get_instance_id()
		for resolution: Vector2i in [Vector2i(2560,1440),Vector2i(1280,720),Vector2i(2560,1440)]:
			root.size=resolution; DisplayServer.window_set_size(resolution); await settle()
			var bounds := Rect2(Vector2(popup.position),Vector2(popup.size))
			var close := popup.get_ok_button()
			var close_bounds := Rect2(close.get_global_rect().position+Vector2(popup.position),close.size)
			check(popup.get_instance_id()==instance and Rect2(Vector2.ZERO,Vector2(resolution)).grow(1.5).encloses(bounds),"Même fenêtre de sauvegardes entière après resize "+str(resolution))
			check(Rect2(Vector2.ZERO,Vector2(resolution)).grow(1.5).encloses(close_bounds),"Fermer les sauvegardes reste accessible après resize "+str(resolution))
			records.append({"label":"profile-safety-live-resize","resolution":[resolution.x,resolution.y],"dialog":rect(bounds),"close":rect(close_bounds),"instance":str(instance)})
		popup.hide(); popup.queue_free(); await settle()
		root.size=Vector2i(1280,720); DisplayServer.window_set_size(root.size); await settle()
	await safety_entries()

func window_origin(window: Window) -> Vector2:
	# Embedded windows, including child confirmations, use root coordinates.
	return Vector2(window.position) if window.is_embedded() else Vector2(window.position-root.position)
func safety_visible(window: Window, control: Control) -> Rect2:
	var origin := window_origin(window)
	var visible := Rect2(origin,Vector2(window.size)).intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != window:
		if ancestor is Control and ancestor.clip_contents:
			var clip: Rect2 = ancestor.get_global_rect()
			visible = visible.intersection(Rect2(clip.position+origin,clip.size))
		ancestor = ancestor.get_parent()
	return visible
func safety_expose(window: Window, control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != window:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			for frame in 2: await process_frame
		ancestor = ancestor.get_parent()
func safety_measure(window: AcceptDialog, label: String, count: int) -> void:
	await settle()
	var origin := window_origin(window)
	var bounds := Rect2(origin,Vector2(window.size))
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1.5).encloses(bounds),"Fenêtre entière "+label+" "+str(root.size))
	var close := window.get_ok_button()
	var initial_close := close.get_global_rect()
	await capture(label+"-initial")
	var controls: Array = []
	for control: Control in window.find_children("*","Control",true,false):
		if not control.is_visible_in_tree(): continue
		var essential: bool = control is BaseButton or control is LineEdit or control is TextEdit or control.name in ["ProfileSafetyQuota","ProfileSafetyStatus"]
		if not essential: continue
		await safety_expose(window,control)
		var local := control.get_global_rect()
		var physical := Rect2(local.position+origin,local.size)
		var visible := safety_visible(window,control)
		var accessible := visible.grow(1.5).encloses(physical)
		check(accessible,"Copie de présentation : contrôle exposable "+label+" "+str(control.name)+" "+str(root.size))
		controls.append({"name":str(control.name),"rect":rect(physical),"visible_bounds":rect(visible),"accessible":accessible})
	check(close.get_global_rect().is_equal_approx(initial_close),"Bouton Fermer fixe "+label)
	records.append({"label":label,"resolution":[root.size.x,root.size.y],"dialog":rect(bounds),"fixture":"presentation_only","entries":count,"controls":controls})
	await capture(label+"-last-content")
func safety_click(window: Window, control: Control) -> void:
	await safety_expose(window,control)
	var point := control.get_global_rect().get_center()+window_origin(window)
	var motion := InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	root.push_input(motion,true); await process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		root.push_input(event,true); await process_frame
	await settle()
func safety_entries() -> void:
	var had: bool = app.model.meta.has("profileSafety")
	var original: Variant = app.model.meta.get("profileSafety")
	var commands: int = app.bridge._next_id
	var entries: Array = []
	for index in 8:
		entries.append({"id":"geometry_only_"+str(index),"club":str(app.model.club.name)+" · copie "+str(index+1),"season":index+1,"round":index+2,"createdAt":"2026-11-11T12:00:00.000Z","reason":"nouvelle-carriere","bytes":10485760,"available":true})
	app.model.meta.profileSafety={"entries":entries,"maxEntries":8,"usedBytes":83886080,"maxBytes":268435456}
	app.open_profile_safety(); await settle()
	var view := app.find_child("ProfileSafety",true,false) as AcceptDialog
	await safety_measure(view,"profile-safety-eight",8)
	for action: String in ["Restore","Remove"]:
		var button := view.find_child("ProfileSafety"+action+"_geometry_only_0",true,false) as Button
		check(button != null and not button.disabled,"Action de copie disponible : "+action)
		if button == null: continue
		await safety_click(view,button)
		var confirmation := view.find_child("ProfileSafetyConfirm",true,false) as ConfirmationDialog
		check(confirmation != null and confirmation.visible,"Confirmation de copie ouverte : "+action)
		if confirmation == null: continue
		await safety_measure(confirmation,"profile-safety-eight-"+action.to_lower()+"-confirmation",8)
		var cancelled := [false]
		confirmation.canceled.connect(func(): cancelled[0]=true)
		var cancel := confirmation.get_cancel_button()
		check(cancel.text=="ANNULER","Annulation explicite de la copie : "+action)
		await safety_click(confirmation,cancel)
		check(cancelled[0] and (not is_instance_valid(confirmation) or not confirmation.visible),"Confirmation de copie réellement annulée : "+action)
		check(app.bridge._next_id==commands,"Aucune reprise ou suppression envoyée : "+action)
		records.append({"label":"profile-safety-eight-"+action.to_lower()+"-cancelled","resolution":[root.size.x,root.size.y],"cancelled":cancelled[0],"commands_delta":app.bridge._next_id-commands,"fixture":"presentation_only"})
	view.hide(); view.queue_free(); await settle()
	if had: app.model.meta.profileSafety=original
	else: app.model.meta.erase("profileSafety")
