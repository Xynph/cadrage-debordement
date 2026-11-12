extends "godot-youth-scout-ui.gd"

func run() -> void:
	root.size = Vector2i(1280,800)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	# Le moteur envoie lui-même le premier instantané au démarrage : on attend sa réponse (comme la recette parente)
	# au lieu de le redemander, car la commande est refusée tant que cet instantané initial est en vol (rendu logiciel lent).
	await response("snapshot initial"); print("review.snapshot"); await command("new_career",{"mode":"common","club":0}); print("review.career")
	await ContextualFlow.settle_club_meetings(app, self, check)
	var view := await open_youth(); print("review.open")
	check(view != null,"Dialogue suivi existant")
	if view == null: quit(1); return
	check(view.find_child("YouthReviewLabel",true,false) != null,"Bilan consultatif rendu pour les profils sans référence")
	var filter := view.find_child("YouthReviewFilter",true,false) as CheckButton
	check(filter != null,"Filtre parcours à revoir")
	await press(button("YouthDevelopmentEnable")); await confirm_action(); print("review.enabled")
	view = await open_youth()
	check(view.find_child("YouthReviewAdvice",true,false) != null,"Conseil factuel rendu après activation")
	var youth: Dictionary = app.model.clubLife.youthDevelopment
	check(youth.enabled,"Activation de suivi reçue")
	var candidate: Dictionary = {}
	for p: Dictionary in youth.players:
		if p.stage == "academy" and p.age >= 18 and p.review.recommendation.suggestedPlan == "integration": candidate=p; break
	check(not candidate.is_empty(),"Jeune avec passerelle professionnelle conseillée")
	if not candidate.is_empty():
		await search(view,"YouthDevelopmentSearch",candidate.name)
		var prepare := button("YouthReviewPrepare")
		check(prepare != null,"Réorientation à préparer sans mutation")
		var before := JSON.stringify(app.model.clubLife.youthDevelopment)
		await press(prepare); print("review.prepared")
		check(JSON.stringify(app.model.clubLife.youthDevelopment) == before,"Préparation locale ne modifie pas le modèle")
		var plan := view.find_child("YouthPlan",true,false) as OptionButton
		check(str(plan.get_item_metadata(plan.selected)) == "integration","Plan conseillé présélectionné")
		await press(button("YouthPlanSave")); await confirm_action()
		var updated: Dictionary = app.model.clubLife.youthDevelopment.players.filter(func(p): return p.id==candidate.id)[0]
		check(updated.plan == "integration","Objectif réellement confirmé par commande existante")
		view = await open_youth()
		await search(view,"YouthDevelopmentSearch",candidate.name)
		var navigate := button("YouthReviewNavigate")
		check(navigate != null,"Lien de parcours disponible")
		await press(navigate)
		check(dialog("YouthDevelopment") == null,"Dialogue fermé avant navigation")
		check(app.find_child("CarnetAcademyPathways",true,false) != null,"Parcours du centre effectivement ouvert")
	view = await open_youth()
	filter = view.find_child("YouthReviewFilter",true,false) as CheckButton
	filter.button_pressed=true;filter.toggled.emit(true);await settle()
	for card in cards(view,"YouthDevelopmentRows"):
		var id: String = str(card.get_meta("player_id"))
		var p: Dictionary = app.model.clubLife.youthDevelopment.players.filter(func(x): return x.id==id)[0]
		check(str(p.review.status) in ["review","context"],"Filtre limité aux dossiers à revoir")
	app.bridge.stop()
	print("Bilan jeunes : %s contrôles, %s échecs" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
