extends SceneTree
const Rooms = preload("res://qa_runner.gd")
const Review = preload("res://ui/contract_review.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func wheel(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	await process_frame

func choose(control: OptionButton, index: int) -> void:
	control.select(index)
	control.item_selected.emit(index)
	await settle()
func pure_cases() -> void:
	check(Review.projected_mark({"rating":77,"note":91,"potential":88}, "rating") == "77", "Niveau global lu sans utiliser la note au poste")
	check(Review.projected_mark({"rating":77,"potential":99,"potentialRange":{"min":86,"max":90}}, "potential") == "86–90", "Potentiel fourni en fourchette, jamais scalaire")
	check(Review.projected_mark({"potential":99}, "potential") == "—", "Ancien potentiel scalaire masqué")
	check(Review.projected_mark({}, "rating") == "—" and Review.projected_mark({"potential":null}, "potential") == "—", "Notes absentes affichées sans zéro inventé")
	var sorting: Array = [{"id":"a","name":"Émile","pos":"Ailier","rating":70,"potential":90,"age":23,"contractEnd":2,"salary":10000,"minutes":20,"status":"Titulaire","renewal":{"available":true}}, {"id":"b","name":"Alice","pos":"Centre","rating":80,"potential":85,"age":24,"contractEnd":1,"salary":2000,"minutes":10,"status":"Hors groupe","renewal":{"available":false,"reason":"Z"}}, {"id":"u","name":"","pos":""}]
	for person: Dictionary in sorting:
		if person.has("potential"): person.potentialRange={"min":int(person.potential)-2,"max":int(person.potential)+2}
	var tied: Dictionary = sorting[0].duplicate(true)
	tied.id = "c"
	sorting.append(tied)
	for scenario in [["salary", ["b","a","c","u"], ["a","c","b","u"]], ["rating", ["a","c","b","u"], ["b","a","c","u"]], ["potential", ["b","a","c","u"], ["a","c","b","u"]], ["name", ["b","a","c","u"], ["a","c","b","u"]], ["contractEnd", ["b","a","c","u"], ["a","c","b","u"]]]:
		for descending in [false, true]:
			var ordered: Array = Review.filtered(sorting, {"sort":scenario[0], "descending":descending}).map(func(player): return player.id)
			check(ordered == scenario[2 if descending else 1], "Tri %s %s : valeurs exactes, égalités par ID et inconnues dernières" % [scenario[0], "descendant" if descending else "ascendant"])
	for key in Review.SORT_KEYS:
		for descending in [false,true]: check(Review.filtered(sorting, {"sort":key,"descending":descending})[-1].id == "u", "Inconnues dernières pour " + key)
	var players: Array = []
	for index in 25: players.append({"id":"p:%d" % index,"name":"Joueur %02d" % index,"pos":"Pilier gauche","contractEnd":1,"salary":3000,"renewal":{"available":true}})
	players.append({"id":"future","name":"Après","pos":"Talonneur","contractEnd":2,"renewal":{"available":false}})
	players.append({"id":"unknown","name":"Sans échéance","pos":"Pilier gauche","contractEnd":null,"renewal":{}})
	var filtered: Array = Review.filtered(players, {"season":1})
	check(filtered.size() == 25, "Vingt-cinq échéances de saison ne sont pas converties en dates ou urgences")
	check(Review.coverage(players, 1)[0].ending == 25 and Review.coverage(players, 1)[0].unknown == 1, "Poste : échéances et inconnues comptées séparément")
	check(Review.filtered(players, {"precision":"Non renseignée"})[0].id == "unknown", "Filtre échéance inconnue sans date inventée")
	check(Review.filtered(players, {"status":"Sans contrat renseigné"}).size() == 1, "Situation contractuelle filtrée")
	check(Review.filtered(players, {"status":"Prolongation accessible"}).size() == 25, "Prolongations accessibles filtrées sur la projection")
	check(Review.filtered(players, {"position":"Talonneur"})[0].id == "future", "Filtre poste principal")
	check(Review.filtered(players, {"search":"ÉCHÉANCE"})[0].id == "unknown", "Recherche indépendante des accents")
	check(Review.filtered(players, {})[-1].id == "unknown", "Échéances connues classées avant les inconnues")
	check(Review.renewal_reason(players[0], true).contains("Match"), "Verrou match lisible")
	var withdrawn := {"renewal":{"available":false,"reason":"Les échanges sont clos pour cette journée","negotiation":{"status":"withdrawn"}}}
	check(Review.renewal_reason(withdrawn, false) == withdrawn.renewal.reason, "Motif moteur conservé")
	var roles: Array = [{"id":"a8","name":"Centre","pos":"Troisième ligne","primaryPositions":[8],"fam":3,"contractEnd":2}, {"id":"z6","name":"Aile","pos":"Troisième ligne","primaryPositions":[7,6],"fam":3,"contractEnd":1}]
	var original_roles := JSON.stringify(roles)
	check(Review.filtered(roles, {"position":"Troisième ligne aile"}).map(func(person): return person.id) == ["z6"], "Contrats : filtre 6–7 sur le poste principal publié")
	check(Review.filtered(roles, {"position":"Troisième ligne centre"}).map(func(person): return person.id) == ["a8"], "Contrats : filtre 8 distinct des troisièmes lignes aile")
	check(Review.filtered(roles, {"search":"3E L"}).map(func(person): return person.id) == ["z6"], "Contrats : recherche de l’abréviation 3E L")
	check(Review.filtered(roles, {"search":"8"}).map(func(person): return person.id) == ["a8"], "Contrats : recherche du numéro 8")
	check(Review.filtered(roles, {"sort":"pos"}).map(func(person): return person.id) == ["z6","a8"], "Contrats : tri des postes distingue aile et centre au lieu de départager les pos bruts par ID")
	var role_groups: Array = Review.coverage(roles, 1)
	check(role_groups.size() == 2, "Couverture contrats : deux groupes distincts pour les 6–7 et le 8")
	if role_groups.size() == 2:
		check(role_groups[0].position == "Troisième ligne aile" and role_groups[0].ending == 1 and role_groups[0].total == 1, "Couverture aile : échéance et total fidèles")
		check(role_groups[1].position == "Troisième ligne centre" and role_groups[1].remaining == 1 and role_groups[1].total == 1, "Couverture centre : contrat futur et total fidèles")
	check(JSON.stringify(roles) == original_roles, "Présentation des postes sans modifier les pos ni les numéros publiés")
func review() -> Control: return app.find_child("ContractReview", true, false)
func button(prefix: String, id: String) -> Button: return app.find_child(Review.action_id(prefix, id), true, false) as Button
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(2560,1440), "Image exclusivement 1440p")
	check(image.save_png(OS.get_environment("CD_CONTRACT_REVIEW_OUTPUT").path_join(id + ".png")) == OK, "Capture : " + id)
func run() -> void:
	pure_cases()
	root.size = Vector2i(2560,1440)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	# Le club10 contient le n°8 lnr:1909 du registre reçu et des 6–7.
	# Cette recette vérifie les deux rôles sans modifier les données du joueur.
	app._command("new_career", {"mode":"common","club":10})
	deadline = Time.get_ticks_msec() + 90000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.bridge.last_response_ok, "Carrière réelle créée")
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var file: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(file)
	app._navigate("Effectif")
	await settle()
	var tab := app.find_child("RosterTab2", true, false) as Button
	check(tab != null, "Onglet Contrats disponible depuis l’effectif")
	tab.pressed.emit()
	await settle()
	check(review() != null, "Revue raccordée à l’onglet Contrats")
	var view := review()
	check(view.get_global_rect().end.x <= root.size.x and view.get_global_rect().end.y <= root.size.y, "Revue entièrement visible à 1440p")
	var readable := true
	for label: Label in view.find_children("*", "Label", true, false):
		if not label.text.is_empty() and label.get_theme_font_size("font_size") < 16: readable = false
	check(readable, "Textes denses à 16 px réels minimum")
	var weekly := 0.0
	for player: Dictionary in app.model.squad: weekly += float(player.salary)
	check(app.find_child("ContractReviewWage", true, false).text == app.SquadViews.G.salary_amount(weekly), "Total hebdomadaire égal aux seules valeurs projetées")
	check(app.find_child("ContractReviewCount", true, false).text.contains("%d / %d" % [app.model.squad.size(),app.model.squad.size()]), "Tout l’effectif projeté est consultable")
	var position_options := view.find_child("ContractReviewPosition", true, false) as OptionButton
	var captions: Array[String] = []
	for index in position_options.item_count: captions.append(position_options.get_item_text(index))
	var found_roles: Array[String] = []
	for person: Dictionary in app.model.squad:
		var numbers: Array = []
		for number: Variant in person.get("primaryPositions", []): numbers.append(int(number))
		numbers.sort()
		var caption := "Troisième ligne aile" if numbers == [6,7] or numbers == [7,6] else "Troisième ligne centre" if numbers == [8] else ""
		if caption.is_empty(): continue
		if not caption in found_roles: found_roles.append(caption)
		var row := view.find_child(Review.action_id("ContractRow", str(person.id)), true, false)
		var position_label := row.get_child(0).get_child(1) as Label
		check(position_label.text == ("3E L" if caption == "Troisième ligne aile" else "8") and position_label.tooltip_text.contains(caption), "Colonne POSTE réelle : rôle distinct et nom principal complet pour " + str(person.id))
	for caption in ["Troisième ligne aile", "Troisième ligne centre"]:
		check(caption in found_roles and caption in captions, "Filtre réel : poste principal complet disponible pour " + caption)
		check(view.find_child("ContractReviewCoverage_" + str(caption).sha256_text().substr(0,16), true, false) != null, "Couverture réelle : groupe distinct pour " + caption)
	await capture("contrats-effectif")
	for period in ["monthly","annual","weekly"]:
		check(app.user_preferences.set_value("salary_period",period),"Préférence salariale enregistrée : "+period)
		app._render(false); await settle()
		view = review()
		check(app.find_child("ContractReviewWage",true,false).text == app.SquadViews.G.salary_amount(weekly),"Total salarial converti : "+period)
		var person: Dictionary = app.model.squad[0]
		check(app.find_child(Review.action_id("ContractSalary",str(person.id)),true,false).text == app.SquadViews.G.salary_amount(person.salary),"Salaire individuel converti : "+period)
		check(app.find_child("ContractSort_salary",true,false).text.contains(app.SquadViews.G.salary_period(true).to_upper()),"En-tête unité active : "+period)
		if period != "weekly": await capture("contrats-"+period)

	var inner := view.find_child("ContractReviewScroll",true,false) as ScrollContainer
	var headers: Button = app.find_child("ContractSort_name",true,false)
	var fixed_header := headers.get_global_rect()
	var fixed_filter: Rect2 = app.find_child("ContractReviewSeason",true,false).get_global_rect()
	var global_scroll: int = app.body_scroll.scroll_vertical
	check(app.find_child("RosterPaginationNext",true,false) == null, "Aucune pagination dans la revue des contrats")
	var initial_rows := view.find_child("ContractReviewRows",true,false).get_children()
	var first_button: Button = initial_rows[0].find_children("*","Button",true,false)[0]
	var point := first_button.get_global_rect().get_center()
	await wheel(point)
	await settle()
	check(inner.scroll_vertical > 0, "Molette sur le bouton de ligne fait défiler les joueurs")
	for tick in 200:
		if inner.scroll_vertical >= int(inner.get_v_scroll_bar().max_value - inner.get_v_scroll_bar().page) - 1: break
		await wheel(point)
	await settle()
	var last_row: Control = initial_rows[-1]
	check(last_row.get_global_rect().end.y <= inner.get_global_rect().end.y + 2 and last_row.get_global_rect().intersects(inner.get_global_rect()), "Dernier joueur atteint à la molette sans changer de page")
	for tick in 5: await wheel(point)
	await settle()
	check(headers.get_global_rect() == fixed_header and app.find_child("ContractReviewSeason",true,false).get_global_rect() == fixed_filter, "En-têtes et filtres restent fixes pendant la molette")
	check(app.body_scroll.scroll_vertical == global_scroll, "Molette en butée ne se propage pas au défilement global")
	inner.scroll_vertical = 0
	await settle()

	var selected_player: String = app.selected_player
	for key: String in Review.SORT_KEYS:
		var sort := app.find_child("ContractSort_" + key, true, false) as Button
		check(sort != null and not sort.disabled, "En-tête cliquable : " + key)
		for click in 2:
			sort.grab_focus()
			sort.pressed.emit()
			await settle()
			var reading: Dictionary = app.management_ui.roster.contract_review
			var actual: Array = view.find_child("ContractReviewRows",true,false).get_children().map(func(row): return row.get_meta("player_id"))
			var expected_ids: Array = Review.filtered(app.model.squad, reading).map(func(player): return str(player.id))
			check(actual == expected_ids and reading.sort == key, "Clic trie les lignes sur " + key)
			check(sort.has_focus() and app.selected_player == selected_player, "Tri préserve focus et sélection : " + key)
			check(sort.text.ends_with("▼" if reading.descending else "▲"), "Sens de tri visible : " + key)
	app.find_child("ContractSort_contractEnd",true,false).pressed.emit()
	await settle()

	var season := app.find_child("ContractReviewSeason", true, false) as OptionButton
	await choose(season, 1)
	var expected: Array = Review.filtered(app.model.squad, app.management_ui.roster.contract_review)
	check(view.find_child("ContractReviewRows", true, false).get_child_count() == expected.size(), "Filtre saison reçu sur les bons identifiants")
	var target: Dictionary = expected[0]
	var level := app.find_child(Review.action_id("ContractLevel", str(target.id)), true, false) as Label
	var potential := app.find_child(Review.action_id("ContractPotential", str(target.id)), true, false) as Label
	check(level != null and level.text == Review.projected_mark(target, "rating"), "Colonne Niveau égale au niveau global projeté")
	check(potential != null and potential.text == Review.projected_mark(target, "potential"), "Colonne Potentiel égale au potentiel projeté")
	check(level.get_index() == 2 and potential.get_index() == 3, "Niveau et Potentiel côte à côte après le poste")
	var profile := button("ContractProfile", str(target.id))
	view.find_child("ContractReviewScroll", true, false).ensure_control_visible(profile)
	profile.grab_focus()
	await settle()
	check(profile.get_meta("player_id") == target.id and profile.has_focus(), "Fiche accessible au clavier par identifiant")
	profile.pressed.emit()
	await settle()
	check(app.selected_player == str(target.id) and app.get_meta("immersive08_full_player", false), "La bonne fiche complète est ouverte")
	var back := app.find_child("PlayerBackToSquad", true, false) as Button
	check(back != null, "Retour natif à l’effectif disponible")
	back.pressed.emit()
	await settle()
	view = review()
	check(view != null and int(app.management_ui.roster.contract_review.season) == Review.horizon(target), "Filtre saison conservé au retour")
	profile = button("ContractProfile", str(target.id))
	check(profile != null and profile.has_focus(), "Focus rendu à la fiche consultée")
	var eligible: Dictionary = {}
	for player: Dictionary in expected:
		if player.get("renewal", {}).get("available", false): eligible = player; break
	check(not eligible.is_empty(), "Une prolongation moteur est disponible dans la recette")
	if not eligible.is_empty():
		var quote := button("ContractRenew", str(eligible.id))
		quote.pressed.emit()
		await settle()
		var dialog := app.get_node_or_null("ContractOffer") as ConfirmationDialog
		check(dialog != null and dialog.title.contains(str(eligible.name)), "Prolongation ouvre le bon joueur sans signature")
		dialog.canceled.emit()
		dialog.hide()
		await settle()
	var precision := app.find_child("ContractReviewPrecision", true, false) as OptionButton
	await choose(precision, 2)
	check(app.find_child("ContractReviewCount", true, false).text.begins_with("0 /"), "Filtre inconnu produit un état vide explicite")
	app.find_child("ContractReviewReset", true, false).pressed.emit()
	await settle()
	check(app.find_child("ContractReviewCount", true, false).text.contains("%d / %d" % [app.model.squad.size(),app.model.squad.size()]), "Réinitialisation retrouve l’effectif")
	var original: Dictionary = app.model.squad[0].duplicate(true)
	app.model.squad[0].name = "Jean-Baptiste des Très Longs Noms de Club et de Famille pour la Lecture des Contrats"
	app.management_ui.roster.contract_review.search = "Très Longs"
	app._render(false)
	await settle()
	check(app.find_child("ContractReviewCount", true, false).text.begins_with("1 /"), "Nom long filtré sans ambiguïté")
	check(review().get_global_rect().end.x <= root.size.x, "Nom long n’élargit pas la vue hors écran")
	await capture("contrats-nom-long")
	app.model.squad[0] = original
	check(FileAccess.get_sha256(file) == before, "Filtres, fiches et dialogue de proposition n’écrivent pas la carrière")
	var report := FileAccess.open(OS.get_environment("CD_CONTRACT_REVIEW_OUTPUT").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}, "  "))
	report.close()
	print("REVUE CONTRATS : %d contrôles ; %d échec(s)" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
