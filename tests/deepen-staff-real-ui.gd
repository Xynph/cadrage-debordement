extends "godot-youth-scout-ui.gd"

var profile := ""
func exported_state() -> String:
	await command("export")
	return JSON.stringify(JSON.parse_string(app.model.meta.exportText).state)
func staff_page(name_filter: String = "") -> void:
	app._clear_dialogs(); app._navigate("Staff"); await settle()
	if not name_filter.is_empty():
		var field := app.find_child("StaffSearch",true,false) as LineEdit
		check(field != null,"Recherche nominative du staff réelle")
		if field != null: field.text = name_filter; field.text_changed.emit(name_filter); await settle()
func confirmation() -> ConfirmationDialog:
	var windows := app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
	check(windows.size()==1,"Une confirmation publique réelle")
	return windows[0] if windows.size()==1 else null
func geometry(view: Window,label: String) -> void:
	check(Rect2i(Vector2i.ZERO,root.size).encloses(Rect2i(view.position,view.size)),label+" contenu dans la fenêtre")
	if view is AcceptDialog:
		check(Rect2(Vector2.ZERO,Vector2(view.size)).grow(2).encloses(view.get_ok_button().get_global_rect()),label+" confirmation entièrement visible")
func cancel_confirmation() -> void:
	var view := confirmation()
	if view != null: await press(view.get_cancel_button())
func adoption_confirmation() -> ConfirmationDialog:
	await press(button("StaffEmploymentAdopt"))
	var view := confirmation()
	if view != null: check(view.dialog_text.contains("500") and view.dialog_text.contains("engagement restant"),"Devis salaire et engagement visibles avant adoption")
	return view
func run() -> void:
	root.size = Vector2i(1920,1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await command("snapshot"); await command("new_career",{"mode":"fiction","club":0})
	await staff_page()
	if not app.model.clubLife.staffCareer.get("active",false):
		await press(button("EnableStaffCareer")); await confirm_action(); await staff_page()
	var before := await exported_state()
	profile = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(profile)
	await press(button("StaffEmploymentEnable")); await cancel_confirmation()
	check(await exported_state()==before,"Annuler activation conserve carrière")
	check(FileAccess.get_file_as_bytes(profile)==bytes,"Annuler activation conserve profil")
	await staff_page(); await press(button("StaffEmploymentEnable")); await confirm_action()
	check(app.model.clubLife.staffEmployment.enabled and int(app.model.clubLife.staffEmployment.weeklyWages)==0,"Activation réellement reçue sans adopter les contrats")
	var coach: Dictionary = {}
	for person: Dictionary in app.model.clubLife.staffEmployment.own:
		if person.role=="coach": coach=person; break
	check(not coach.is_empty(),"Entraîneur nominatif recruté par la carrière")
	if coach.is_empty(): await finish(); return
	before = await exported_state(); bytes = FileAccess.get_file_as_bytes(profile)
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size; await staff_page(str(coach.name))
		await press(button("StaffEmploymentBudgetOpen"))
		var budget := dialog("StaffEmploymentBudget")
		check(budget!=null,"Budget staff réel ouvert")
		if budget!=null: geometry(budget,"Budget "+str(size)); await press(budget.get_ok_button())
		await staff_page(str(coach.name))
		var adopt := await adoption_confirmation()
		if adopt!=null: geometry(adopt,"Adoption "+str(size)); await press(adopt.get_cancel_button())
		check(await exported_state()==before,"Prévisualisation et annulation sans mutation "+str(size))
		check(FileAccess.get_file_as_bytes(profile)==bytes,"Aucun fichier écrit par les aperçus "+str(size))
	# A failed real disk transaction must not publish an adopted contract.
	check(DirAccess.rename_absolute(profile,profile+".before")==OK,"Sauvegarde profil avant refus disque")
	check(DirAccess.make_dir_absolute(profile)==OK,"Obstacle disque réel créé")
	await staff_page(str(coach.name))
	var failed_adoption := await adoption_confirmation()
	if failed_adoption!=null:
		await press(failed_adoption.get_ok_button())
		var deadline := Time.get_ticks_msec()+45000
		while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
		await settle()
		check(not app.bridge.last_response_ok and not str(app.last_error).is_empty(),"Refus disque réellement visible après confirmation")
	check(DirAccess.remove_absolute(profile)==OK,"Obstacle disque retiré")
	check(DirAccess.rename_absolute(profile+".before",profile)==OK,"Profil original restauré")
	app._clear_dialogs(); await settle()
	check(await exported_state()==before,"Refus disque conserve carrière avant adoption")
	check(FileAccess.get_file_as_bytes(profile)==bytes,"Refus disque conserve octets du profil")
	await staff_page(str(coach.name)); await adoption_confirmation(); await confirm_action()
	check(int(app.model.clubLife.staffEmployment.weeklyWages)==500,"Adoption confirmée vaut 500 €/semaine")
	await command("train",{"mode":"normal"}); await command("auto_lineup"); await command("begin_match"); await command("delegate"); await command("finish_round")
	var paid_state: Dictionary = JSON.parse_string(await exported_state())
	check(paid_state.staffEmployment.payments.size()==1 and int(paid_state.staffEmployment.payments[0].amount)==500,"Une vraie semaine paie exactement 500 € une seule fois")
	check(paid_state.ledger.any(func(row):return str(row.title).begins_with("Salaires du staff") and int(row.amount)==-500),"Débit réel présent dans le grand livre")
	await staff_page(str(coach.name)); await press(button("StaffRelease"))
	var release := confirmation()
	if release!=null: check(release.dialog_text.contains("1") and release.dialog_text.contains("indemnité".capitalize()),"Indemnité de rupture affichée avant validation"); await press(release.get_cancel_button())
	before = await exported_state()
	await staff_page(str(coach.name)); await press(button("StaffRelease")); await cancel_confirmation()
	check(await exported_state()==before,"Annuler rupture garde engagement et trésorerie")
	var cash := int(app.model.club.cash)
	await staff_page(str(coach.name)); await press(button("StaffRelease")); await confirm_action()
	check(int(app.model.clubLife.staffEmployment.weeklyWages)==0 and int(app.model.club.cash)==cash-1000,"Rupture confirmée débite deux paies et arrête le salaire")
	before = await exported_state()
	app.bridge.stop()
	var until := Time.get_ticks_msec()+6000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<until: await process_frame
	check(app.bridge.child_pid<=0,"Moteur réel fermé avant reprise")
	app.queue_free(); await process_frame
	app=load("res://main.tscn").instantiate(); root.add_child(app); await response("reprise du profil")
	check(await exported_state()==before,"Reprise réelle du profil après rupture identique")
	check(int(app.model.clubLife.staffEmployment.weeklyWages)==0,"Reprise ne recrée aucun salaire résilié")
	print("DEEPEN_STAFF_REAL_UI: "+str(checks)+" contrôles, "+str(failures.size())+" échec(s)")
	await finish()
