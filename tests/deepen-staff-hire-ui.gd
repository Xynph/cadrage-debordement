extends "deepen-staff-real-ui.gd"

func candidates_page(name_filter: String) -> void:
	await staff_page()
	var tab := app.find_child("StaffCareerTab",true,false) as OptionButton
	check(tab != null,"Onglet candidats staff public")
	if tab!=null: tab.select(1); tab.item_selected.emit(1); await settle()
	var search := app.find_child("StaffSearch",true,false) as LineEdit
	if search!=null: search.text=name_filter; search.text_changed.emit(name_filter); await settle()
func employed_page(name_filter: String) -> void:
	await staff_page(name_filter)
	# Directory reading survives navigation. Select the real team tab rather
	# than relying on a render to reset the previously visited candidates tab.
	var tab := app.find_child("StaffCareerTab",true,false) as OptionButton
	check(tab != null,"Onglet équipe du staff public après recrutement")
	if tab!=null: tab.select(0); tab.item_selected.emit(0); await settle()
func choose_years(value: int) -> void:
	var field := app.find_child("StaffContractYears",true,false) as OptionButton
	check(field!=null,"Choix de durée public")
	if field==null:return
	for i in field.item_count:
		if int(field.get_item_metadata(i))==value:field.select(i);field.item_selected.emit(i);await settle();return
	check(false,"Durée "+str(value)+" disponible")
func selected_years() -> int:
	var field := app.find_child("StaffContractYears",true,false) as OptionButton
	return int(field.get_item_metadata(field.selected)) if field!=null and field.selected>=0 else -1
func run() -> void:
	if OS.has_environment("CD_STAFF_REAL_WORKER"): ProjectSettings.set_setting("native_engine/worker_path",OS.get_environment("CD_STAFF_REAL_WORKER"))
	root.size=Vector2i(1920,1080)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await response("snapshot initial");await command("new_career",{"mode":"fiction","club":0}); await ContextualFlow.settle_club_meetings(app, self, check);await staff_page()
	if not app.model.clubLife.staffCareer.get("active",false):await press(button("EnableStaffCareer"));await confirm_action();await staff_page()
	await press(button("StaffEmploymentEnable"));await confirm_action()
	var candidate: Dictionary={}
	for person: Dictionary in app.model.clubLife.staffEmployment.candidates:
		if person.role=="coach" and person.retireAge-person.age>=3:candidate=person;break
	check(not candidate.is_empty(),"Candidat apte à signer deux puis trois saisons")
	if candidate.is_empty():await finish();return
	var before:=await exported_state()
	profile=str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes:=FileAccess.get_file_as_bytes(profile)
	await candidates_page(str(candidate.name));await press(button("StaffHire"));await choose_years(2)
	var contract:=dialog("StaffContract")
	check(contract!=null,"Devis nominatif réel ouvert")
	if contract!=null:geometry(contract,"Devis recrutement");await press(contract.get_ok_button())
	check(await exported_state()==before and FileAccess.get_file_as_bytes(profile)==bytes,"Annuler le devis ne signe ni ne débite")
	root.size=Vector2i(1280,720)
	await candidates_page(str(candidate.name));await press(button("StaffHire"));await choose_years(2)
	geometry(dialog("StaffContract"),"Devis recrutement 720p")
	check(DirAccess.rename_absolute(profile,profile+".before")==OK,"Sauvegarde avant refus recrutement")
	check(DirAccess.make_dir_absolute(profile)==OK,"Obstacle disque recrutement créé")
	await press(button("StaffContractConfirm"))
	var deadline:=Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline:await process_frame
	await settle()
	check(not app.bridge.last_response_ok and not str(app.last_error).is_empty(),"Refus recrutement réel affiché")
	check(DirAccess.remove_absolute(profile)==OK,"Obstacle recrutement retiré")
	check(DirAccess.rename_absolute(profile+".before",profile)==OK,"Profil recrutement restauré")
	app._clear_dialogs();await settle()
	check(await exported_state()==before and FileAccess.get_file_as_bytes(profile)==bytes,"Refus recrutement conserve export et profil")
	await candidates_page(str(candidate.name));await press(button("StaffHire"))
	check(selected_years()==2,"Réessai conserve les deux saisons choisies après refus disque")
	check(app.find_child("StaffContractRetryNotice",true,false)!=null and button("StaffContractConfirm").text.contains("RÉESSAYER"),"Refus et possibilité de réessai expliqués dans le devis conservé")
	if selected_years()!=2:await finish();return
	await press(button("StaffContractConfirm"));await response("recrutement réessayé")
	check(not app.management_ui.get("staff_contract_drafts",{}).has(str(candidate.id)+":hire"),"Brouillon recrutement effacé uniquement après succès")
	root.size=Vector2i(1920,1080)
	var employed: Dictionary={}
	for person: Dictionary in app.model.clubLife.staffEmployment.own:
		if person.id==candidate.id:employed=person;break
	check(not employed.is_empty() and employed.contractEnd==2 and employed.employed,"Recrutement confirmé deux saisons, contrat réellement rémunéré")
	await employed_page(str(candidate.name));await press(button("StaffRenew"));await choose_years(3)
	contract=dialog("StaffContract")
	if contract!=null:geometry(contract,"Devis prolongation");await press(contract.get_ok_button())
	before=await exported_state()
	await employed_page(str(candidate.name));await press(button("StaffRenew"))
	check(selected_years()==3,"Prolongation préparée trois saisons conservée après fermeture")
	await press(button("StaffContractConfirm"));await response("prolongation rémunérée")
	var state: Dictionary=JSON.parse_string(await exported_state())
	var financial: Array=state.staffEmployment.contracts.filter(func(c):return c.staffId==candidate.id)
	check(financial.size()==1 and financial[0].endSeason==3 and financial[0].salary==500,"Prolongation réelle trois saisons sans contrat financier en double")
	before=await exported_state()
	app.bridge.stop();deadline=Time.get_ticks_msec()+6000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await process_frame
	app.queue_free();await process_frame
	app=load("res://main.tscn").instantiate();root.add_child(app);await response("reprise recrutement prolongé")
	check(await exported_state()==before,"Reprise exacte du recrutement et de la prolongation")
	print("DEEPEN_STAFF_HIRE_UI: "+str(checks)+" contrôles, "+str(failures.size())+" échec(s)")
	await finish()
