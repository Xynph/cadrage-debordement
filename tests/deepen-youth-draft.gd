extends "deepen-youth-ui.gd"

func select_key(field: OptionButton, key: String) -> void:
	for i in field.item_count:
		if str(field.get_item_metadata(i))==key:
			field.select(i)
			field.item_selected.emit(i)
			await settle()
			return
	check(false,"Option disponible : "+key)

func current_choice(view: AcceptDialog) -> Dictionary:
	var plan := view.find_child("YouthPlan",true,false) as OptionButton
	var focus := view.find_child("YouthFocus",true,false) as OptionButton
	return {"plan":str(plan.get_item_metadata(plan.selected)),"focus":str(focus.get_item_metadata(focus.selected))}

func run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await response("startup")
	await command("new_career",{"mode":"common","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	var view := await open_youth()
	await press(button("YouthDevelopmentEnable"))
	await confirm_action()
	var people: Array = app.model.clubLife.youthDevelopment.players.filter(func(p):return p.model=="xp" and p.focusOptions.size()>1)
	check(not people.is_empty(),"Jeune XP avec deux qualités réelles")
	if people.is_empty(): await finish(); return
	var person: Dictionary = people[0]
	var alternatives: Array = person.focusOptions.filter(func(option):return option.key!=person.defaultFocus)
	var target: String = str(alternatives[0].key)
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	await command("export")
	var before: String = app.model.meta.exportText
	var profile: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(profile)
	await select_key(view.find_child("YouthPlan",true,false),"specialist")
	await select_key(view.find_child("YouthFocus",true,false),target)
	await press(button("YouthPlanSave"))
	var confirmations := app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
	check(confirmations.size()==1,"Confirmation explicite du brouillon")
	if confirmations.size()==1: await press(confirmations[0].get_cancel_button())
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	check(current_choice(view)=={"plan":"specialist","focus":target},"Annulation conserve exactement plan et qualité choisis")
	await command("export")
	check(before==app.model.meta.exportText and bytes==FileAccess.get_file_as_bytes(profile),"Annulation : état et profil identiques")
	var backup := profile.get_base_dir().path_join("donnees-precedentes.json")
	var held := backup+".youth-draft-held"
	check(DirAccess.rename_absolute(backup,held)==OK,"Mise à l’écart réversible de la sauvegarde précédente")
	check(DirAccess.make_dir_absolute(backup)==OK,"Panne disque réelle préparée")
	await press(button("YouthPlanSave"))
	confirmations = app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
	if confirmations.size()==1:
		await press(confirmations[0].get_ok_button())
		var deadline := Time.get_ticks_msec()+45000
		while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.bridge.last_response_ok and not app.last_error.is_empty(),"Refus disque du vrai worker visible")
	check(bytes==FileAccess.get_file_as_bytes(profile),"Refus disque : profil inchangé")
	check(DirAccess.remove_absolute(backup)==OK,"Obstacle disque retiré")
	check(DirAccess.rename_absolute(held,backup)==OK,"Sauvegarde précédente restaurée")
	await command("export")
	check(before==app.model.meta.exportText,"Refus disque : état exporté inchangé")
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	check(current_choice(view)=={"plan":"specialist","focus":target},"Refus conserve exactement plan et qualité pour réessayer")
	await press(button("YouthPlanSave"))
	await confirm_action()
	var updated: Dictionary = app.model.clubLife.youthDevelopment.players.filter(func(p):return p.id==person.id)[0]
	check(updated.plan=="specialist" and updated.focus==target,"Nouvelle confirmation applique enfin le même brouillon")
	check(updated.rating==person.rating and updated.current.attributes==person.current.attributes,"Réessayer ne crée aucun gain de qualité ou niveau")
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	await select_key(view.find_child("YouthPlan",true,false),"integration")
	app._clear_dialogs()
	if not await ContextualFlow.prepare_match_day(app,self,check): await finish(); return
	var previous_week: int=app.model.meta.week
	await command("begin_match")
	await ContextualFlow.skip_talk(app, self, "pre", check)
	await command("delegate")
	await command("finish_round")
	await ContextualFlow.finish_match_week(app,self,check,previous_week)
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	check(current_choice(view).plan=="specialist","Nouvelle semaine invalide le brouillon non confirmé")
	check(str(view.counter.text).contains("réinitialisés"),"Changement de contexte expliqué au manager")
	await select_key(view.find_child("YouthPlan",true,false),"integration")
	await command("export")
	var saved: String = app.model.meta.exportText
	await command("import",{"text":saved})
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	check(current_choice(view).plan=="specialist","Import même carrière/contexte efface le brouillon local")
	await select_key(view.find_child("YouthPlan",true,false),"integration")
	await command("new_career",{"mode":"common","club":0})
	check(not app.management_ui.has("youth_development"),"Nouvelle carrière même club efface les brouillons")
	app._clear_dialogs()
	app.bridge.stop()
	print("Brouillon jeunes : ",checks," contrôles, ",failures.size()," échecs")
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
