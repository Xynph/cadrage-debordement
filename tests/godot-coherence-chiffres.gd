extends SceneTree
## Cohérence des chiffres et du calendrier, carrière Monde (Lyon Confluences XV, avant-saison 2026-2027).
## Parcourt les vrais écrans et vérifie que chaque indicateur y est lu au même endroit, avec des libellés distincts
## quand deux chiffres mesurent des choses différentes. Contrôle aussi qu'aucun texte à retour automatique n'a une
## largeur nulle (une lettre par ligne) : le défaut de l'écran Calendrier.
const Rooms = preload("res://qa_runner.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_COHERENCE_OUTPUT")
var capture_prefix := OS.get_environment("CD_COHERENCE_CAPTURE")
var viewport_size := Vector2i(1920, 1080)

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle() -> void:
	for frame in 10: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Vraie réponse du moteur : " + app.last_error)
	await settle()

func capture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless" or capture_prefix.is_empty(): return
	var image := root.get_texture().get_image()
	check(image.save_png(capture_prefix + name + ".png") == OK, "Capture " + name)

func texts(node: Node) -> String:
	var parts: Array[String] = []
	for child: Node in node.find_children("*", "", true, false):
		if not (child is Control) or not child.is_visible_in_tree(): continue
		if child is Label and str(child.text).strip_edges() != "": parts.append(str(child.text))
		elif child is Button and str(child.text).strip_edges() != "": parts.append(str(child.text))
		if str(child.tooltip_text).strip_edges() != "" and child is Button: parts.append(str(child.tooltip_text))
	return "\n".join(parts)

## Texte à retour automatique réduit à une colonne étroite : largeur inférieure à quelques caractères, ou presque
## autant de lignes que de lettres. Retourne les libellés fautifs.
func narrow_texts(node: Node) -> Array[String]:
	var found: Array[String] = []
	for label: Label in node.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree() or label.autowrap_mode == TextServer.AUTOWRAP_OFF: continue
		var text := str(label.text).strip_edges()
		if text.length() < 12: continue
		var size := label.get_theme_font_size("font_size")
		if label.size.x < float(size) * 3.0 or label.get_line_count() > maxi(3, text.length() / 3):
			found.append("%s (%d px, %d lignes)" % [text.left(40), roundi(label.size.x), label.get_line_count()])
	return found

func other_club(fixture: Dictionary) -> String:
	var club_id: Variant = app.model.get("club", {}).get("id")
	var home: Dictionary = fixture.get("home", {})
	return G.club_name(fixture.get("away", {}) if home.get("id") == club_id else home)

func forbidden_none(text: String, route: String) -> void:
	for phrase in ["Aucun prochain match", "Aucune rencontre annoncée", "Aucune rencontre programmée", "contrat(s)", "expire(nt)", "profil(s)", "joueur(s) dans"]:
		check(not text.contains(phrase), route + " : pas de « " + phrase + " »")

func synthetic_detector() -> void:
	# Le détecteur voit bien le défaut d'origine : un texte à retour automatique dans un HFlowContainer sans largeur minimale.
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(900, 0)
	var lonely := Label.new()
	lonely.text = "Convocations confirmées · retour prévu à partir du 10/08/2026"
	lonely.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow.add_child(lonely)
	var other := Label.new()
	other.text = "7 joueurs en sélection"
	flow.add_child(other)
	root.add_child(flow)
	await settle()
	check(not narrow_texts(flow).is_empty(), "Détecteur : un texte à retour automatique sans largeur minimale est signalé")
	root.remove_child(flow)
	flow.queue_free()

func run() -> void:
	root.size = viewport_size
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(viewport_size)
	await synthetic_detector()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	# Création : la marque est « Rugby Legacy 27 », jamais « Rugby Legacy ».
	app._navigate("Création")
	await settle()
	var creation := texts(app)
	check(not creation.to_upper().contains("RUGBY LEGACY"), "Création : aucune marque « Rugby Legacy »")
	var mark := app.find_child("EntryWordmark", true, false)
	check(mark != null and texts(mark).contains("RUGBY LEGACY") and texts(mark).contains("27"), "Création : lettrage RUGBY LEGACY 27")
	await capture("creation")
	# Carrière Monde : Lyon Confluences XV.
	app._command("new_career", {"mode": "world-champ", "club": 7})
	await wait_engine()
	app.timer.stop()
	if not await Rooms.settle_club_meetings(app, self, check):
		await app._close(1)
		return
	var model: Dictionary = app.model
	check(model.club.get("name") == "Lyon Confluences XV" and str(model.meta.get("mode")) == "world", "Carrière Monde, Lyon Confluences XV")
	check(model.get("figures") is Dictionary, "Le moteur publie les chiffres partagés (figures)")
	var fixture := P.next_fixture(model)
	check(not fixture.is_empty() and model.get("next") == null, "Avant-saison : pas de rencontre à préparer, mais une prochaine rencontre au calendrier")
	var opponent := other_club(fixture)
	var payroll := P.payroll(model)
	var counts := P.contract_counts(model)
	var finance: Dictionary = model.clubLife.clubStrategy.finance
	check(is_equal_approx(float(payroll.charge_weekly), float(finance.weeklyWages)), "Charge salariale lue = weeklyWages du moteur")
	check(float(payroll.charge_weekly) > float(payroll.players_weekly), "Deux mesures salariales distinctes (cotisations)")
	check(int(counts.end_of_season) == model.decisions.recruitment.expiring.size(), "Fin de saison : Recrutement et chiffres partagés d'accord")
	check(int(counts.by_horizon) > int(counts.end_of_season), "L'horizon est plus large que la fin de saison")
	# Bureau
	app._navigate("Bureau")
	await settle()
	var office := texts(app)
	await capture("bureau")
	check(office.contains(opponent), "Bureau : prochaine rencontre contre " + opponent)
	check(office.contains("%d échéances de contrat" % int(counts.by_horizon)) and office.contains("dont %d en fin de saison" % int(counts.end_of_season)), "Bureau : échéances à l'horizon ET en fin de saison, avec leur périmètre")
	forbidden_none(office, "Bureau")
	# Tactique, Entraînement, Compétitions : même rencontre que le Bureau
	app._navigate("Composition")
	await settle()
	var tactics := texts(app)
	check(tactics.contains(opponent.to_upper()) or tactics.contains(opponent), "Tactique : prochaine rencontre contre " + opponent)
	forbidden_none(tactics, "Tactique")
	app.Immersive.open_training(app)
	await settle()
	var training := texts(app)
	check(training.contains(opponent), "Entraînement : prochaine rencontre contre " + opponent)
	forbidden_none(training, "Entraînement")
	app._navigate("Classements")
	await settle()
	var competitions := texts(app)
	check(competitions.contains(opponent), "Compétitions : prochain rendez-vous contre " + opponent)
	forbidden_none(competitions, "Compétitions")
	check(app.find_child("StandingsPaginationNext", true, false) == null and app.find_child("StandingsPagination", true, false) == null, "Classement de 14 clubs : une seule page")
	check(app.find_children("StandingsRow_*", "Button", true, false).size() == 14, "Classement : les 14 clubs sont affichés")
	for tab: Button in app.find_children("StandingsDivision_*", "Button", true, false):
		var style := tab.get_theme_stylebox("normal")
		var room := tab.size.x - style.content_margin_left - style.content_margin_right
		var width := tab.get_theme_font("font").get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab.get_theme_font_size("font_size")).x
		check(width <= room + 1.0, "Onglet de championnat non coupé : " + tab.text)
	await capture("competitions")
	# Club : charge salariale avec cotisations, libellé distinct
	app._navigate("Club")
	await settle()
	var club := texts(app)
	check(club.contains("Salaires et cotisations") and club.contains(G.euros(payroll.charge_weekly)), "Club : « Salaires et cotisations » = " + G.euros(payroll.charge_weekly))
	await capture("club")
	# Finances
	app.management_ui["immersive08_finance_tab"] = "summary"
	app._navigate("Finances")
	await settle()
	await settle()
	var money := texts(app)
	var dump := FileAccess.open(output.path_join("finances.txt"), FileAccess.WRITE)
	dump.store_string(money)
	dump.close()
	check(money.to_lower().contains("masse salariale · joueurs") and money.contains(G.salary_amount(payroll.players_weekly)), "Finances : masse salariale des joueurs = " + G.salary_amount(payroll.players_weekly))
	check(money.contains("hors cotisations"), "Finances : « hors cotisations » annoncé")
	check(money.contains("Salaires et cotisations") and money.contains(G.euros(payroll.charge_weekly)), "Finances : la répartition donne la même charge que le Club")
	check(money.to_lower().count("masse salariale") == money.to_lower().count("masse salariale · joueurs"), "Finances : « Masse salariale » toujours qualifiée")
	check(money.to_lower().contains("marge courante") and money.contains("hors guichet"), "Finances : la marge hebdomadaire est qualifiée")
	var projection: Dictionary = finance.projection
	check(money.contains("marge courante " + U.amount(projection.marginTotal)) and money.contains("guichet, primes et soutien +" + U.amount(projection.otherInflows)), "Finances : la projection relie marge courante et trésorerie prévue")
	check(money.contains("%d contrats à anticiper" % int(counts.by_horizon)) and money.contains("%d en fin de saison" % int(counts.end_of_season)), "Finances : échéances à l'horizon et en fin de saison")
	forbidden_none(money, "Finances")
	await capture("finances")
	# Réception et Recrutement : pluriels accordés
	for route in ["Réception", "Recrutement"]:
		app._navigate(route)
		await settle()
		forbidden_none(texts(app), route)
	# Calendrier : aucun texte à largeur nulle
	app._navigate("Calendrier")
	await settle()
	var calendar := app.find_child("CarnetCalendar", true, false)
	check(calendar != null, "Calendrier présent")
	var detail := app.find_child("InternationalAvailabilityDetail", true, false)
	check(detail != null, "Calendrier : convocations internationales annoncées (7 joueurs du club en sélection)")
	if detail != null: check(detail.size.x >= 300.0 and detail.get_line_count() <= 3, "Calendrier : le texte des convocations a une largeur lisible")
	var narrow := narrow_texts(app)
	check(narrow.is_empty(), "Calendrier : aucun texte à largeur nulle : " + str(narrow))
	check(app.find_child("CalendarProgramScroll", true, false) != null and app.find_children("MonthDay_*", "Control", true, false).size() >= 28, "Calendrier : la grille du mois est affichée")
	await capture("calendrier")
	var report := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "display": DisplayServer.get_name()}, "  "))
	report.close()
	print("COHÉRENCE DES CHIFFRES : %d contrôles ; %d échecs" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)
