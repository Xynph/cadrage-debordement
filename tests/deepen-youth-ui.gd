extends "godot-youth-scout-ui.gd"

func response(id: String) -> void:
	var deadline := Time.get_ticks_msec()+45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok,"Vrai worker : "+id+" · "+str(app.last_error))
	app.timer.stop()
	await settle()

func visible_dialog(view: AcceptDialog) -> void:
	if view == null: return
	var title := Vector2(0,view.get_theme_constant("title_height","Window"))
	var rectangle := Rect2(Vector2(view.position)-title,Vector2(view.size)+title)
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(rectangle),"Dialogue et titre contenus dans la fenêtre hôte : "+str(view.name))

func run() -> void:
	root.size = Vector2i(1920,1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await response("startup")
	await command("new_career",{"mode":"common","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	var view := await open_youth()
	await press(button("YouthDevelopmentEnable"))
	await confirm_action()
	var people: Array = app.model.clubLife.youthDevelopment.players
	var eligible := people.filter(func(p: Dictionary): return p.stage=="academy" and p.age>=18 and p.review.recommendation.key=="promotion")
	check(not eligible.is_empty(),"Jeune réellement éligible au premier contrat")
	if eligible.is_empty(): await finish(); return
	var person: Dictionary = eligible[0]
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size = resolution
		view = await open_youth()
		await search(view,"YouthDevelopmentSearch",person.name)
		check(view.find_child("YouthRecentReview",true,false)!=null,"Bilan récent rendu "+str(resolution))
		await command("export")
		var before: String = app.model.meta.exportText
		await press(button("YouthReviewPrepare"))
		await command("export")
		check(before==app.model.meta.exportText,"Aperçu local sans mutation "+str(resolution))
		await press(button("YouthPlanSave"))
		var confirmations := app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
		check(confirmations.size()==1,"Confirmation explicite du plan")
		if confirmations.size()==1: await press(confirmations[0].get_cancel_button())
		await command("export")
		check(before==app.model.meta.exportText,"Annuler le plan conserve la carrière")
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	await press(button("YouthReviewPrepare"))
	await press(button("YouthPlanSave"))
	await confirm_action()
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	var objective := view.find_child("YouthShortTermObjective",true,false) as Label
	check(objective!=null and objective.text.contains("Décision S1 semaine 0") and objective.text.contains("réexamen S1 semaine 4"),"Objectif court terme daté reçu du worker")
	await command("export")
	var before_promotion: String = app.model.meta.exportText
	await press(button("YouthReviewPromotion"))
	check(app.route=="Formation" and dialog("YouthPromotionPathway")!=null,"Réorientation ouvre le vrai parcours Formation de ce joueur")
	visible_dialog(dialog("YouthPromotionPathway"))
	var promote := button("YouthPathwayPromote")
	check(promote!=null and str(promote.get_meta("promote_id",""))==str(person.id),"Décision ciblée sur le bon joueur")
	await press(promote)
	var confirmations := app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
	check(confirmations.size()==1 and confirmations[0].dialog_text.contains("salaire"),"Premier contrat conserve sa confirmation salariale")
	if confirmations.size()==1: await press(confirmations[0].get_cancel_button())
	await command("export")
	check(before_promotion==app.model.meta.exportText,"Annuler le premier contrat conserve carrière et hasard")
	view = await open_youth()
	await search(view,"YouthDevelopmentSearch",person.name)
	await press(button("YouthReviewPromotion"))
	await press(button("YouthPathwayPromote"))
	await confirm_action()
	check(app.model.squad.filter(func(p):return p.id==person.id).size()==1,"Premier contrat réel : identité unique dans les professionnels")
	check(not app.model.decisions.development.academy.any(func(p):return p.id==person.id),"Premier contrat réel : départ du centre")
	await command("export")
	var after: String = app.model.meta.exportText
	app._command("promote_academy",{"playerId":person.id,"confirmed":true})
	var deadline := Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.bridge.last_response_ok and not app.last_error.is_empty(),"Rejouer une décision périmée produit un refus réel visible")
	await settle()
	await command("export")
	check(after==app.model.meta.exportText,"Refus du doublon atomique")
	app._clear_dialogs()
	await command("import",{"text":FileAccess.get_file_as_string(OS.get_environment("CD_DEEPEN_YOUTH_FIXTURE"))})
	var loan_candidates: Array = app.model.clubLife.youthDevelopment.players.filter(func(p):return p.review.recommendation.key=="loan")
	check(not loan_candidates.is_empty(),"Quatre vraies semaines du worker justifient le conseil de prêt")
	if not loan_candidates.is_empty():
		var loan_player: Dictionary = loan_candidates[0]
		view = await open_youth()
		await search(view,"YouthDevelopmentSearch",loan_player.name)
		var recent := view.find_child("YouthRecentReview",true,false) as Label
		check(recent!=null and recent.text.contains("4 semaines"),"Fenêtre récente réelle rendue dans le suivi")
		await command("export")
		var before_loan: String = app.model.meta.exportText
		await press(button("YouthReviewLoan"))
		check(app.route=="Centre" and dialog("YouthLoanPathway")!=null,"Réorientation ouvre le parcours de prêt du joueur")
		visible_dialog(dialog("YouthLoanPathway"))
		var choice := dialog("YouthLoanPathway").find_child("YouthPathwayLoanClub",true,false) as OptionButton
		check(choice!=null and choice.item_count>1 and str(choice.get_meta("player_id",""))==str(loan_player.id),"Clubs d’accueil et identité issus de la projection existante")
		if choice!=null and choice.item_count>1:
			await choose(dialog("YouthLoanPathway"),"YouthPathwayLoanClub",1)
			confirmations = app.find_children("*","ConfirmationDialog",true,false).filter(func(d):return d.visible)
			check(confirmations.size()==1,"Prêt soumis à confirmation distincte")
			if confirmations.size()==1: await press(confirmations[0].get_cancel_button())
			await command("export")
			check(before_loan==app.model.meta.exportText,"Annuler le prêt conserve la carrière")
			view = await open_youth()
			await search(view,"YouthDevelopmentSearch",loan_player.name)
			await press(button("YouthReviewLoan"))
			await choose(dialog("YouthLoanPathway"),"YouthPathwayLoanClub",1)
			await confirm_action()
			check(not app.model.squad.any(func(p):return p.id==loan_player.id),"Prêt réel : départ de l’effectif courant")
			check(not app.model.clubLife.youthDevelopment.players.any(func(p):return p.id==loan_player.id),"Prêt réel : suivi limité au club courant")
			check(app.model.clubLife.academyPathways.loans.any(func(p):return p.id==loan_player.id),"Prêt réel enregistré dans le parcours existant")
			await command("export")
			var saved: String = app.model.meta.exportText
			app.queue_free()
			await settle()
			app = load("res://main.tscn").instantiate()
			root.add_child(app)
			await response("startup")
			await command("export")
			check(saved==app.model.meta.exportText,"Reprise disque exacte après prêt et réorientation")
	app._clear_dialogs()
	app.bridge.stop()
	print("Approfondissement jeunes : ",checks," contrôles, ",failures.size()," échecs")
	app.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)
