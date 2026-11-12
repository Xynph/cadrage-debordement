extends RefCounted
## Complement to the shared Analysis/Club replay: no setup, worker command or
## profile copy here. The caller owns one checkpoint, one baseline and timeout.
const Office = preload("res://ui/immersive08/office.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")

static func _closed(window: Variant) -> bool:
	return not is_instance_valid(window) or not window.visible

static func _next_fixture(model: Dictionary) -> Dictionary:
	var current: Variant = model.get("next")
	if current is Dictionary and not current.is_empty(): return current
	var announced := Office.P.next_nationale_fixture(model)
	return announced if not announced.is_empty() else Office.P.next_scheduled_fixture(model)

static func _unavailable(harness: Node, id: String, reason: String) -> void:
	harness.visits.append({"name":id,"scope":"office","available":false,"reason":reason})

static func _back_from_dialog(harness: Node, window: Window, label: String) -> bool:
	await harness.key(KEY_LEFT, true)
	var returned := _closed(window) and not harness.nav._blocked()
	harness.check(_closed(window), "Bureau · Back masque ou libère le lecteur · " + label)
	harness.check(not harness.nav._blocked(), "Bureau · navigation disponible après Back · " + label)
	return returned

static func run(harness: Node, expected_fixture: String) -> void:
	var app: Control = harness.app
	# Do not hide an upstream Back failure by switching the route behind a modal.
	if harness.nav._blocked():
		harness.check(false, "Bureau · le scope attend un vrai retour hors du lecteur précédent")
		return
	var requests: int = app.bridge._next_id
	app._navigate("Bureau")
	await harness.settle()
	harness.check(app.route == "Bureau" and harness.found("ImmersiveOffice") != null, "Bureau · vraie page du client reçue")
	await harness.capture("bureau-liens-reels-2560")
	var fixture := _next_fixture(app.model)
	var opponent := Office.fixture_opponent(app.model, fixture)
	if not fixture.is_empty() and not opponent.is_empty():
		var own: Variant = app.model.club.id
		var id := "OfficeNextAwayClubName" if fixture.get("home", {}).get("id") == own else "OfficeNextHomeClubName"
		var source := harness.found(id) as Button
		if source == null: source = harness.found("OfficeScheduledOpponent") as Button
		harness.check(source != null and str(source.get_meta("entity_id", "")) == str(opponent.id), "Bureau · prochain adversaire publié lié au bon ID")
		if source == null: return
		await harness.reveal(source)
		var before_scroll: int = app.body_scroll.scroll_vertical
		await harness.activate(source, true)
		var detail := harness.found("CompetitionClubDetails") as Window
		harness.check(detail != null and detail.visible and str(detail.get_meta("entity_id", "")) == str(opponent.id), "Bureau · clic réel vers le club adverse du prochain match")
		if detail == null: return
		if not await _back_from_dialog(harness, detail, "prochain adversaire"): return
		harness.check(is_instance_valid(source) and source.is_visible_in_tree() and source.has_focus() and app.body_scroll.scroll_vertical == before_scroll, "Bureau · retour exact au prochain adversaire, focus et défilement")
	else:
		_unavailable(harness, "OfficeNextOpponent", "Aucune fixture annoncée avec adversaire du club géré dans ce checkpoint")
	if Agenda.valid_date(fixture.get("date")):
		var date_link := harness.found("OfficeNextDate") as Button
		if date_link == null: date_link = harness.found("OfficeScheduledDate") as Button
		harness.check(date_link != null and str(date_link.get_meta("entity_id", "")) == str(fixture.date), "Bureau · date publiée liée au jour exact")
		if date_link == null: return
		var date_name := str(date_link.name)
		await harness.reveal(date_link)
		var before_scroll: int = app.body_scroll.scroll_vertical
		await harness.activate(date_link)
		harness.check(app.route == "Calendrier" and app.management_ui.calendar_reading.selected == fixture.date, "Bureau · Entrée ouvre le calendrier au jour annoncé")
		await harness.key(KEY_LEFT, true)
		date_link = harness.found(date_name) as Button
		harness.check(app.route == "Bureau" and date_link != null and date_link.has_focus() and app.body_scroll.scroll_vertical == before_scroll, "Bureau · Back de calendrier conserve date source, focus et scroll")
	else:
		_unavailable(harness, "OfficeNextDate", "Aucune date ISO publiée pour la prochaine rencontre ; semaine seule laissée en texte")
	var watched: Array = app.model.get("squad", []).filter(func(player: Dictionary): return not Office.U.watch_reason(player).is_empty())
	if not watched.is_empty():
		var player: Dictionary = watched[0]
		var id := "OfficeWatchedPlayer_" + str(player.id).validate_node_name()
		var alert := harness.found(id) as Button
		harness.check(alert != null and str(alert.get_meta("entity_id", "")) == str(player.id), "Bureau · vraie alerte physique publiée liée à son joueur")
		if alert == null: return
		await harness.reveal(alert)
		var before_scroll: int = app.body_scroll.scroll_vertical
		await harness.activate(alert, true)
		harness.check(app.route == "Effectif" and app.selected_player == str(player.id) and app.get_meta("immersive08_full_player", false), "Bureau · clic sur alerte ouvre la bonne fiche complète")
		await harness.key(KEY_LEFT, true)
		alert = harness.found(id) as Button
		harness.check(app.route == "Bureau" and alert != null and alert.has_focus() and app.body_scroll.scroll_vertical == before_scroll, "Bureau · retour à l'alerte exacte et à sa lecture")
	else:
		_unavailable(harness, "OfficeWatchedPlayer", "Aucun joueur à surveiller publié dans le checkpoint ; aucun faux cas de fatigue fabriqué")
	var played: Array = app.model.get("calendar", []).filter(func(candidate: Dictionary):
		return candidate.get("played", false) and str(candidate.get("id", "")) == expected_fixture)
	if played.size() == 1 and not Office.score_reading_target(app, played[0]).is_empty():
		var id := "OfficeRecentFixture_" + expected_fixture.validate_node_name()
		var score := harness.found(id) as Button
		harness.check(score != null and str(score.get_meta("entity_id", "")) == expected_fixture, "Bureau · score de la vraie rencontre archivée rendu comme lien exact")
		if score == null: return
		await harness.reveal(score)
		var before_scroll: int = app.body_scroll.scroll_vertical
		await harness.activate(score)
		var detail := harness.found("CompetitionFixtureDetails") as Window
		harness.check(detail != null and detail.visible and str(detail.get_meta("entity_id", "")) == expected_fixture, "Bureau · score ouvre le détail de la rencontre concordante")
		if detail == null: return
		if not await _back_from_dialog(harness, detail, "score réel"): return
		harness.check(is_instance_valid(score) and score.is_visible_in_tree() and score.has_focus() and app.body_scroll.scroll_vertical == before_scroll, "Bureau · retour exact au score, même instance et même défilement")
	else:
		_unavailable(harness, "OfficeRecentFixture", "La rencontre attendue n'est pas un résultat de calendrier unique et concordant dans les cinq résultats du Bureau")
	harness.check(app.bridge._next_id == requests, "Bureau · aucune requête worker par les liens, sans action primaire ni préparation supplémentaire")
