extends SceneTree
# Classements (variante 1 « Tableau et rendez-vous à droite », décision de Léo du 20/11/2026), carrière Monde réelle :
# tout ce qui ressemble à un lien en est un (club, rencontre, date, compétition, en-tête de colonne), aucune fenêtre ouverte
# par un clic (la rencontre et les archives sont des sous-pages avec retour), aucun or, un seul ivoire plein au plus.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle(frames := 6) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func finish() -> void:
	print("CALENDRIER DA : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found

func page() -> Control:
	return app.find_child("CarnetStandings", true, false) as Control

func fill_of(button: Button, state: String) -> Color:
	var style := button.get_theme_stylebox(state) as StyleBoxFlat
	return style.bg_color if style != null else Color(0, 0, 0, 0)

## Aucun or (Continuer seul, hors page), un ivoire plein au plus, aucun bouton visible sans effet.
func check_buttons(label: String) -> void:
	var plein := 0
	var morts: Array[String] = []
	for button: Button in page().find_children("*", "Button", true, false):
		if not button.is_visible_in_tree(): continue
		for state in ["normal", "hover", "pressed"]:
			var fond := fill_of(button, state)
			check(not fond.is_equal_approx(Charte.OR) and not fond.is_equal_approx(Charte.OR_VIF), label + " : pas d'or sur " + button.name)
		if fill_of(button, "normal").is_equal_approx(Charte.IVOIRE): plein += 1
		if not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE and button.get_signal_connection_list("pressed").is_empty(): morts.append(str(button.name))
	check(plein <= 1, label + " : un seul bouton ivoire plein (" + str(plein) + ")")
	check(morts.is_empty(), label + " : aucun bouton sans effet " + str(morts))

func click(button: Button) -> void:
	var nom := str(button.name)
	button.pressed.emit()
	await settle(10)
	check(windows(app).is_empty(), "Aucune fenêtre après le clic sur " + nom)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await wait_idle()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Classements")
	await settle(10)
	check(page() != null, "La page Classements est affichée (route " + str(app.route) + ")")
	if page() == null: return finish()

	# Tableau : chaque ligne ouvre la fiche du club ; un en-tête de colonne trie ; zones en mot et symbole.
	var rows := page().find_children("StandingsRow_*", "Button", true, false)
	check(rows.size() >= 6, "Le tableau liste les clubs (" + str(rows.size()) + ")")
	check(rows.all(func(row: Button): return row.get_meta("entity_kind", "") == "club"), "Chaque ligne est un lien vers la fiche du club")
	check(page().find_child("StandingsOwnMarker", true, false) != null and page().find_child("StandingsOwnTrait", true, false) != null, "Notre ligne : marqueur incliné et club-trait")
	var legend := page().find_child("StandingsZoneLegend", true, false)
	if legend != null: check(str(legend.get_meta("legend_text", "")) != "", "Légende des zones écrite (symbole et mot)")
	check(page().find_children("StandingsSort_*", "Button", true, false).size() >= 8, "Colonnes triables : un bouton par en-tête")
	var points := page().find_child("StandingsSort_points", true, false) as Button
	if points != null:
		await click(points)
		var ordered := page().find_children("StandingsRow_*", "Button", true, false)
		check(ordered.size() == rows.size(), "Le tri garde tous les clubs")
		await click(page().find_child("StandingsSort_rank", true, false))
	# Colonne de droite : ta place, trois écarts, prochain rendez-vous, calendrier du club.
	check(page().find_child("CompetitionPlace", true, false) != null, "Carte « Ta place »")
	check(page().find_child("CompetitionNextFixture", true, false) != null, "Carte « Prochain rendez-vous »")
	check(page().find_child("CompetitionCalendarPreview", true, false) != null, "Carte « Calendrier du club »")
	for gap: Button in page().find_children("CompetitionGapLink_*", "Button", true, false):
		check(gap.get_meta("entity_kind", "") == "club", "Un écart ouvre la fiche du club")
	check(page().find_child("CompetitionPrepareMatch", true, false) != null or page().find_child("UpcomingOpponent", true, false) != null or page().find_child("CompetitionCalendarLink", true, false) != null, "Un rendez-vous ou son action est affiché")
	# Sélecteur de compétition : menu déroulant dans la page, jamais une fenêtre.
	var menu := page().find_child("StandingsDivisionMenu", true, false) as Button
	check(menu != null and page().find_children("StandingsDivision_*", "Button", true, false).size() >= 1, "Sélecteur de compétition (menu dans la page)")
	if menu != null:
		await click(menu)
		check((page().find_child("StandingsDivisionList", true, false) as Control).visible, "Le menu s'ouvre dans la page")
		await click(menu)
	check_buttons("Classement")

	# Une ligne du calendrier ouvre la rencontre (sous-page avec retour) ; Retour revient au classement.
	var fixtures := page().find_children("CalendarFixture_*", "Button", true, false)
	check(not fixtures.is_empty(), "Le calendrier du club liste des rencontres")
	if not fixtures.is_empty():
		await click(fixtures[0])
		check(app.route == "Classements" and app.management_ui.get("competition_page", {}).get("kind", "") == "fixture", "La rencontre s'ouvre en sous-page de Classements")
		check(page() != null and page().find_child("CompetitionFixtureDetails", true, false) != null, "La page de la rencontre est affichée")
		# Gabarit du « Prochain rendez-vous » : deux plaques de clubs, chacune ouvre la fiche du club.
		for side in ["home", "away"]:
			var plate := page().find_child("FixtureClub_" + side, true, false) as Button
			check(plate != null and plate.get_meta("entity_kind", "") == "club", "Rencontre : plaque du club (" + side + ") reliée à sa fiche")
		check_buttons("Rencontre")
		var retour := page().find_child("CompetitionPageBack", true, false) as Button
		check(retour != null, "Retour au classement présent")
		if retour != null:
			await click(retour)
			check(not app.management_ui.has("competition_page") and page().find_child("StandingsTableFrame", true, false) != null, "Retour : le classement revient")
	# Archives : sous-page aussi.
	# Une saison archivée (projection : les identifiants sont ceux des vrais clubs de la carrière) : le champion cité est un lien.
	var league_rows: Array = app.model.leagues[0].get("rows", [])
	var champion_id: Variant = league_rows[0].id if not league_rows.is_empty() else null
	var saved_archives: Variant = app.model.get("archives")
	if champion_id != null: app.model.archives = {"seasons": [{"season": 1, "champions": [{"leagueId": str(app.model.leagues[0].id), "clubId": champion_id}]}]}
	var archives := page().find_child("OpenArchives", true, false) as Button
	check(archives != null, "Archives des saisons accessibles")
	if archives != null:
		await click(archives)
		check(page() != null and page().find_child("SeasonArchives", true, false) != null, "Les archives sont une page, pas une fenêtre")
		if champion_id != null:
			var champion_link := page().find_child("SeasonArchiveClub_" + str(int(champion_id)), true, false) as Button
			check(champion_link != null and champion_link.get_meta("entity_kind", "") == "club", "Archives : le champion ouvre la fiche de son club")
		check_buttons("Archives")
		var retour := page().find_child("CompetitionPageBack", true, false) as Button
		if retour != null: await click(retour)
	if saved_archives != null: app.model.archives = saved_archives
	else: app.model.erase("archives")
	# Libellés de phase : lus par type, jamais un nom de compétition figé dans le code.
	var canvas: GDScript = load("res://ui/immersive08/competition_canvas.gd")
	check(canvas._phase({"phase": "quarter", "competitionId": "jlo-d1"}) == "Quart de finale", "Phase finale : libellé du type de phase, sans nom de compétition figé")
	check(canvas._phase({"phase": "promotion", "competitionId": "jlo-d1-d2", "leg": 2}) == "Barrage aller-retour · Manche 2", "Barrage aller-retour : manche lue dans la rencontre")
	# Barrages japonais des archives : noms lus dans les identités de compétition, lignes omises sans nom publié.
	var archive_world: GDScript = load("res://ui/immersive08/world_archive.gd")
	var barrage := {"pair": {"upperId": 1, "lowerId": 2}, "legs": [{"pair": [1, 2], "score": [10, 5]}], "outcome": {"promoted": true, "upperNext": 1, "lowerNext": 2}}
	var identites: Variant = app.model.meta.get("competitionIdentities")
	app.model.meta.competitionIdentities = {}
	var sans_nom: Array = archive_world.japan_lines(app, barrage)
	check(sans_nom.size() == 1 and sans_nom[0].begins_with("Manche 1"), "Barrage japonais : sans nom publié, seules les manches sont écrites (%s)" % str(sans_nom))
	app.model.meta.competitionIdentities = {"jlo-d1-d2": {"name": "Nom A"}, "jlo-d1": {"name": "Nom B"}, "jlo-d2": {"name": "Nom C"}}
	var avec_noms: Array = archive_world.japan_lines(app, barrage)
	check(avec_noms.size() == 3 and avec_noms[0].begins_with("Nom A") and avec_noms[2].contains("Nom B") and avec_noms[2].contains("Nom C"), "Barrage japonais : les noms viennent des données de la compétition (%s)" % str(avec_noms))
	if identites != null: app.model.meta.competitionIdentities = identites
	else: app.model.meta.erase("competitionIdentities")
	# Grille mensuelle du Calendrier : la même rangée d'onglets que Classements, marqueur incliné du jour courant.
	app.set_meta("calendar_table", false)
	app._navigate("Calendrier")
	await settle(10)
	var tabs := app.find_child("CalendarCompetitionTabs", true, false) as Control
	check(tabs != null and tabs.get_child_count() == 5, "Grille mensuelle : rangée d'onglets Classements · Phases finales · Calendrier · Statistiques · Rivalités")
	var today_day := app.find_child("MonthDay_" + str(app.management_ui.get("calendar_reading", {}).get("today", "")), true, false)
	if today_day != null: check(today_day.find_child("MonthTodayMarker", true, false) != null, "Jour courant : marqueur incliné")
	var to_standings := tabs.find_child("Section_Classements", true, false) as Button if tabs != null else null
	if to_standings != null:
		to_standings.pressed.emit()
		await settle(10)
		check(app.route == "Classements" and page() != null, "L'onglet Classements de la grille rouvre le classement")
	# Un clic sur une ligne change d'écran (fiche du club), sans fenêtre.
	rows = page().find_children("StandingsRow_*", "Button", true, false)
	var autre: Button = null
	for row: Button in rows:
		if str(row.get_meta("club_id", "")) != str(app.model.club.id):
			autre = row
			break
	if autre != null:
		await click(autre)
		check(app.route != "Classements", "Un clic sur un club ouvre sa fiche (écran " + app.route + ")")
	finish()
