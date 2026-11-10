extends SceneTree
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
func choose(control: OptionButton, index: int) -> void:
	control.select(index)
	control.item_selected.emit(index)
	await settle()
func pure_cases() -> void:
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
	app._command("new_career", {"mode":"common","club":0})
	deadline = Time.get_ticks_msec() + 90000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(app.bridge.last_response_ok, "Carrière réelle créée")
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
	check(app.find_child("ContractReviewWage", true, false).text == app.SquadViews.G.euros(weekly), "Total hebdomadaire égal aux seules valeurs projetées")
	check(app.find_child("ContractReviewCount", true, false).text.contains("%d / %d" % [app.model.squad.size(),app.model.squad.size()]), "Tout l’effectif projeté est consultable")
	await capture("contrats-effectif")
	var season := app.find_child("ContractReviewSeason", true, false) as OptionButton
	await choose(season, 1)
	var expected: Array = Review.filtered(app.model.squad, app.management_ui.roster.contract_review)
	check(view.find_child("ContractReviewRows", true, false).get_child_count() == expected.size(), "Filtre saison reçu sur les bons identifiants")
	var target: Dictionary = expected[0]
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
