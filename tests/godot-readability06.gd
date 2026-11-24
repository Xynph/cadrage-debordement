extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const G = preload("res://ui/carnet_skin.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
var proof := OS.get_environment("CD_READABILITY06_ARTIFACTS")
var scenario := OS.get_environment("CD_READABILITY06_CASE")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.12).timeout
	for i in 6: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty(), "Vrai worker disponible")
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload); await worker()
	check(app.bridge.last_response_ok, "Commande réelle " + id + " : " + app.last_error)
func named(id: String) -> Control: return app.find_child(id, true, false)
func resize_to(resolution: Vector2i) -> void:
	root.size = resolution
	DisplayServer.window_set_size(resolution)
	await settle()
	check(root.size == resolution and app.size == Vector2(resolution), "Viewport natif à la taille physique " + str(resolution))
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var requested := OS.get_environment("CD_READABILITY06_CAPTURE")
	if not requested.is_empty() and label != requested: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(proof.path_join(label + ".png")) == OK, "Capture " + label)
func contrast(a: Color, b: Color) -> float:
	var x := a.srgb_to_linear().get_luminance()
	var y := b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+.05)/(minf(x,y)+.05)
func finish() -> void:
	var report := {"checks":checks,"failures":failures,"measurements":measurements,
		"display_server":DisplayServer.get_name(),"real_dpi_tested":false}
	if DisplayServer.get_name() != "headless":
		report["reported_screen_dpi"] = DisplayServer.screen_get_dpi()
		report["reported_screen_scale"] = DisplayServer.screen_get_scale()
	var file := FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	if app != null: app.closing = true; app.bridge.stop()
	print("Lisibilité06 : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	# main removes a retired root before queue_free; resize/deferred calls must
	# never touch its viewport or move its retired controls afterwards.
	var retired:=preload("res://ui/office_view.gd").OfficeColumns.new()
	retired.size=Vector2(1000,400)
	root.add_child(retired)
	root.remove_child(retired)
	await process_frame
	check(not retired.compact,"Bureau retiré : adaptation différée ignorée sans viewport")
	retired._adapt()
	check(not retired.compact,"Bureau retiré : signal tardif ignoré sans viewport")
	retired.free()
	if OS.get_environment("CD_READABILITY06_TEARDOWN_ONLY")=="1":finish();return
	var heading := G.section("Un titre à sa juste place", "Une explication lisible")
	check(heading.get_child(0).get_theme_font_size("font_size") <= 22,"Titre du carnet réduit à22px maximum")
	heading.free()
	# A selected row remains identifiable under pointer, keyboard and pressed states.
	var selected := G.button("Échéance de l’équipe — sélection", func(): pass)
	check(selected.custom_minimum_size.y <= 36,"Commande générale limitée à36px")
	G.selected(selected,Color("ffe032"))
	for state in ["normal","hover","pressed"]:
		var style: StyleBoxFlat = selected.get_theme_stylebox(state)
		# Charte finale : le choix courant est une pilule cerclée d'encre (forme), jamais la seule couleur.
		var contour := mini(mini(style.border_width_left, style.border_width_right), mini(style.border_width_top, style.border_width_bottom))
		check(contour >= 2 and contrast(style.border_color, style.bg_color) >= 3.0, "Repère géométrique sélection conservé : " + state)
		check(contrast(selected.get_theme_color("font_color"),style.bg_color) >= 4.5, "Contraste sélection : " + state)
	selected.free()
	var cleared := G.button("Ancienne sélection",func(): pass)
	G.selected(cleared,Color("b94850"))
	G.clear_selection(cleared)
	for state in ["normal","hover","pressed"]:
		check(not cleared.has_theme_stylebox_override(state),"Ancien repère retiré : " + state)
	cleared.free()
	var metric := G.metric("123 456 789 €", "Engagement hebdomadaire connu")
	var value: Label = metric.get_child(0)
	check(value.autowrap_mode != TextServer.AUTOWRAP_OFF, "Valeur longue autorisée sur plusieurs lignes")
	check(value.get_theme_font_size("font_size") > metric.get_child(1).get_theme_font_size("font_size"), "Valeur hiérarchisée devant explication")
	check(value.get_theme_font_size("font_size") <= 24,"Métrique réduite à24px maximum")
	var metric_tile := PanelContainer.new()
	root.add_child(metric_tile)
	metric_tile.size = Vector2(150,100)
	metric_tile.add_child(metric)
	await settle()
	check(metric_tile.size.x <= 150 and value.get_global_rect().end.x <= metric_tile.get_global_rect().end.x,"Grand montant réellement contenu dans une tuile de150px")
	metric_tile.free()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("new_career", {"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	var annotated := _reference_player()
	var annotated_id := str(annotated.id)
	var annotation := "Repère de recette du dossier — uniquement pour ce joueur."
	await command("coach_note_save",{"context":app.model.clubLife.coachNotebook.context,"target":annotated_id,"text":annotation})
	await command("export")
	var before: String = app.model.meta.exportText
	var disk := str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	check(not bytes.is_empty(), "Profil réel pour la comparaison disque")
	var formats := {"reading720":Vector2i(1280,720),"reading900":Vector2i(1600,900),"reading1080":Vector2i(1920,1080),"reading1440":Vector2i(2560,1440)}
	var selected_formats: Array = [formats[scenario]] if scenario in formats else []
	for resolution: Vector2i in selected_formats:
		await resize_to(resolution)
		await office_reading(resolution)
		await roster_reading(resolution, annotated, annotation)
		await route_reading(resolution)
		await navigate("Création")
		for id in ["CreationNext", "CreationClubsScroll"]:
			check(inside(named(id)), "Création : contrôle directement visible %s %s" % [id,resolution])
		await capture("creation-dense-" + str(resolution.x))
	if scenario == "responsive":
		await resize_to(Vector2i(1280,720))
		await navigate("Effectif")
		await visit_all_players("compact 720p")
		await responsive_reading(annotated, annotation)
	if scenario == "drafts":
		await resize_to(Vector2i(2560,1440))
		app.selected_player = annotated_id
		await navigate("Effectif")
		await visit_all_players("1440p")
		app.selected_player = annotated_id
		await navigate("Effectif")
		await immersive_drafts(annotated, annotation)
	check(scenario in formats or scenario in ["responsive","drafts"], "Scénario de couverture explicite et reconnu")
	check(FileAccess.get_file_as_bytes(disk) == bytes, "Consultation, clavier et resize : octets du profil inchangés")
	await command("export")
	check(app.model.meta.exportText == before, "Consultation et resize : état complet et RNG identiques")
	finish()

func _reference_player() -> Dictionary:
	for player: Dictionary in app.model.squad:
		var peers: Array = app.model.squad.filter(func(member: Dictionary): return member.id != player.id and member.pos == player.pos)
		if not peers.is_empty() and player.renewal.available and player.get("rosterProfile") is Dictionary: return player
	check(false, "La fixture doit contenir un joueur prolongeable avec un pair et des sources")
	return app.model.squad[0]

func navigate(route: String) -> void:
	app._navigate(route)
	await settle()
	app.coach.close()
	await settle()

func rect(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)

func inside(control: Control, viewport: Control = null) -> bool:
	if control == null or not control.is_visible_in_tree(): return false
	var bounds := rect(control)
	if bounds.size.x <= 0 or bounds.size.y <= 0: return false
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	return screen.grow(1).encloses(bounds) and (viewport == null or rect(viewport).grow(1).encloses(bounds))

func keyboard(button: BaseButton, description: String) -> void:
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Commande clavier disponible · " + description)
	if button == null or button.disabled or not button.is_visible_in_tree(): return
	var id := str(button.name)
	button.grab_focus()
	await settle()
	# Un rendu de l'écran pendant l'attente (réponse du moteur) reconstruit la commande : le jeu
	# garde le focus par nom (management_state.gd). On suit donc le même contrôle reconstruit,
	# qui doit toujours avoir le focus clavier.
	if not is_instance_valid(button): button = named(id) as BaseButton
	check(button != null and button.has_focus(), "Focus clavier · " + description)
	if button == null: return
	await key(KEY_ENTER)

func expose_office(control: Control) -> void:
	if control == null: return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			await settle()
		parent = parent.get_parent()

func office_contained(control: Control) -> bool:
	if not inside(control, app.body_scroll): return false
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer and not inside(control,parent): return false
		parent = parent.get_parent()
	return true

func office_card_readable(card: Control) -> bool:
	if card == null: return false
	await expose_office(card)
	if office_contained(card): return true
	var viewport := named("OfficeReadingScroll") as ScrollContainer
	if viewport == null or not inside(viewport,app.body_scroll): return false
	var bounds := rect(card)
	var visible := rect(viewport).grow(1)
	if bounds.position.x < visible.position.x or bounds.end.x > visible.end.x: return false
	var facts := 0
	for control: Control in card.find_children("*","Control",true,false):
		if not control.is_visible_in_tree() or not (control is Label or control is BaseButton): continue
		facts += 1
		await expose_office(control)
		if not office_contained(control): return false
	print("OFFICE_BOUNDED_CARD ",JSON.stringify({"card":str(card.name),"bounds":str(bounds),"viewport":str(rect(viewport)),"readable_facts":facts}))
	return facts > 0

func office_reading(resolution: Vector2i) -> void:
	await navigate("Bureau")
	var tiles := ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline"]
	# Sous 1600 de large, le Bureau en conteneurs défile d'un seul tenant : chaque tuile est amenée à l'écran avant lecture.
	var scrolling := resolution.x < 1600
	# Dès 1600 px de large, le Bureau dessiné (avec Gabi) n'a plus « Le profil à suivre » : il est au Recrutement.
	if not scrolling: tiles.erase("OfficeRecruitment")
	for id: String in tiles:
		var tile := named(id)
		var readable := inside(tile,app.body_scroll)
		if scrolling: readable = await office_card_readable(tile)
		check(readable, "Tuile entière dans le Bureau %s %s" % [id,resolution])
	var decisions := named("OfficeDecisions")
	check(decisions != null and rect(decisions).size.x >= 280, "Espace utile pour les décisions " + str(resolution))
	for id in ["OfficePreparationAction", "OfficeSelectionAction", "OfficeSquadAction", "OfficeStandingsAction", "OfficeCalendarAction"]:
		var action := named(id) as Button
		if scrolling and action != null:
			action.grab_focus()
			await expose_office(action)
			check(action.has_focus(), "Accès métier garde son focus dans le vrai défilement " + id)
		check(office_contained(action) if scrolling else inside(action,app.body_scroll), "Accès métier visible depuis le Bureau %s %s" % [id,resolution])
	if scrolling:
		var reading := named("OfficeReadingScroll") as ScrollContainer
		if reading != null: reading.scroll_vertical = 0
		app.body_scroll.scroll_vertical = 0
		await settle()
	await capture("bureau-" + str(resolution.x))

func roster_rows(roster: Control) -> Array[Node]:
	if roster == null: return []
	# Une ligne par joueur : le « + » du comparateur posé au bout de la ligne porte le même identifiant, il n'est pas une ligne.
	return roster.find_children("*","Button",true,false).filter(func(row: Node): return row.has_meta("player_id") and not str(row.name).begins_with("RosterCompare_"))

func roster_row_readable(row: Control, viewport: Control) -> bool:
	# The continuous table reserves a trailing gutter under its scrollbar.
	# Assert the painted facts, not that blank button gutter, plus the full
	# line height. No salary, term, identity or status may be clipped.
	if row == null or viewport == null: return false
	var bounds := rect(row)
	var visible := rect(viewport).grow(1)
	if bounds.position.y < visible.position.y or bounds.end.y > visible.end.y: return false
	var facts := row.find_children("*","Label",true,false)
	if facts.is_empty(): return false
	# La boîte d'un texte va de l'ascendante à la descendante de la police (Barlow : bien plus haute que le corps) et peut
	# dépasser de la ligne, qui la rogne (clip_contents), sans que rien ne se voie. On contrôle la bande des lettres :
	# le cadratin (taille du corps) posé sur la ligne de base, entier dans la ligne peinte et dans le viewport.
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size)).grow(1)
	for label: Label in facts:
		if not label.is_visible_in_tree(): return false
		var texte := rect(label)
		var corps := float(label.get_theme_font_size("font_size"))
		var base := texte.position.y + label.get_theme_font("font").get_ascent(int(corps))
		var lettres := Rect2(texte.position.x, base - 0.8 * corps, texte.size.x, corps)
		if row.clip_contents and not bounds.grow(1).encloses(lettres): return false
		if not visible.encloses(lettres) or not ecran.encloses(lettres): return false
	return true

func first_roster_page() -> void:
	var search := named("RosterSearch")
	var scroll := named("SquadScroll") as ScrollContainer
	check(scroll != null and search != null, "Liste continue et recherche de l’effectif présentes")
	if scroll == null or search == null: return
	var selected: String = app.selected_player
	scroll.scroll_vertical = 0
	scroll.scroll_horizontal = 0
	await settle()
	check(scroll.scroll_vertical == 0 and named("RosterSearch") == search, "Début de liste atteint sans remplacer la recherche")
	check(app.selected_player == selected, "Défilement conserve le dossier choisi")

func visit_all_players(format: String) -> void:
	await first_roster_page()
	var scroll := named("SquadScroll") as ScrollContainer
	var search := named("RosterSearch")
	var rows := roster_rows(scroll)
	var seen: Array[String] = []
	for row: Button in rows: seen.append(str(row.get_meta("player_id")))
	var expected: Array[String] = []
	for player: Dictionary in app.model.squad: expected.append(str(player.id))
	expected.sort(); seen.sort()
	check(seen == expected, "Exactement tous les identifiants, sans doublon, dans la liste continue · " + format)
	if rows.is_empty(): return
	# The real keyboard command opens each edge dossier and focus scrolls the
	# same continuous list, without synthesizing pages that no longer exist.
	# Effectif actuel : le focus choisit la ligne, Entrée ouvre la fiche complète (un écran), « ← Effectif » y ramène.
	var recherche := (search as LineEdit).text if search is LineEdit else ""
	for index in [0, rows.size()-1]:
		var row := rows[index] as Button
		var id := str(row.get_meta("player_id"))
		scroll.ensure_control_visible(row)
		row.grab_focus()
		await settle()
		check(app.selected_player == id, "Le focus clavier choisit la ligne du joueur · " + format)
		check(row.has_focus() and roster_row_readable(row, scroll), "Faits de la ligne focalisée entièrement exposés · " + format)
		await keyboard(row, "dossier au bord de la liste · " + format)
		var fiche := named("ImmersivePlayerFull")
		check(fiche != null and str(fiche.get_meta("player_id", "")) == id and app.selected_player == id, "Dossier exact ouvert par le clavier · " + format)
		await keyboard(named("PlayerBackToSquad") as BaseButton, "retour à l’effectif depuis la fiche · " + format)
		scroll = named("SquadScroll") as ScrollContainer
		search = named("RosterSearch")
		check(search is LineEdit and (search as LineEdit).text == recherche, "Lecture clavier conserve la recherche · " + format)
		var retour: Array = roster_rows(scroll).filter(func(r: Node): return str(r.get_meta("player_id")) == id)
		check(retour.size() == 1 and roster_row_readable(retour[0], scroll), "Retour de fiche : la ligne du joueur ouvert reste entière à l’écran · " + format)
		rows = roster_rows(scroll)
	if named("ImmersiveRosterTable") != null:
		if not rows.is_empty():
			(rows[-1] as Control).grab_focus()
			await settle()
		await key(KEY_HOME)
		check(rows[0].has_focus() and roster_row_readable(rows[0],scroll), "Début rejoint le premier joueur au clavier")
		await key(KEY_PAGEDOWN)
		check(scroll.scroll_vertical > 0 and scroll.is_ancestor_of(root.gui_get_focus_owner()), "Page suivante déplace réellement le focus et la lecture")
		await key(KEY_END)
		check(rows[-1].has_focus() and roster_row_readable(rows[-1],scroll), "Fin rejoint le dernier joueur au clavier")

func roster_reading(resolution: Vector2i, player: Dictionary, annotation: String) -> void:
	app.selected_player = str(player.id)
	await navigate("Effectif")
	await first_roster_page()
	var roster := named("SquadScroll")
	var rows := roster_rows(roster)
	var complete := rows.filter(func(row: Control): return roster_row_readable(row, roster))
	var immersive := named("ImmersiveRosterTable") != null
	if immersive and resolution.y >= 1080 and rows.size() >= 24:
		# Le bandeau des filtres (recherche, tuiles des totaux, pastilles de poste, en-têtes : choix de Léo du 21/11/2026)
		# prend la hauteur de ~3 lignes : le tableau montre 21 lignes entières à 1080p et 1440p, plus les 24 d'avant.
		# On fait défiler jusqu'à la 24e ligne et on exige entières toutes celles qui tiennent dans la zone visible.
		var pas_haut := rect(rows[1]).position.y - rect(rows[0]).position.y
		var tiennent := floori(rect(roster).size.y / maxf(1.0, pas_haut))
		check(tiennent >= 20, "Au moins 20 lignes tiennent dans le tableau de l’Effectif " + str(resolution) + " · " + str(tiennent))
		(roster as ScrollContainer).ensure_control_visible(rows[23])
		await settle()
		complete = rows.filter(func(row: Control): return roster_row_readable(row, roster))
		for row: Control in rows.slice(maxi(0, 24 - tiennent), 24):
			check(roster_row_readable(row,roster), "Les lignes visibles de l’Effectif sont entières après défilement " + str(row.get_meta("player_id")))
	# Depuis la refonte de l'Effectif, un seul gabarit : le tableau continu, de 720p à 1440p (plus de repli compact).
	check(immersive, "Gabarit attendu de l’Effectif (tableau continu) " + str(resolution))
	check(roster != null and not rows.is_empty(), "Table d’effectif natif renseignée " + str(resolution))
	if roster == null or rows.is_empty(): return
	# Lignes entières : 24 dès 1080p ; plus bas, le tableau à l'échelle a moins de hauteur : son viewport doit être rempli
	# de lignes entières (au plus la bannière de famille et une ligne coupée en moins), jamais moins de 12.
	var pas := rect(rows[1]).position.y - rect(rows[0]).position.y if rows.size() > 1 else rect(rows[0]).size.y
	var place := floori(rect(roster).size.y / maxf(1.0, pas))
	var attendu := maxi(12, place - 2)
	check(rows.size() == app.model.squad.size() and complete.size() >= attendu, "Liste immersive complète et %d lignes de faits entières %s · reçu %d/%d" % [attendu,resolution,complete.size(),rows.size()])
	for id in ["RosterScrollHint", "OpenComparison", "RosterSearch"]:
		check(inside(named(id), app.body_scroll), "Colonne ou commande visible %s %s" % [id,resolution])
	# Chaque fait de l'ancien tableau unique a sa colonne dans l'un des quatre onglets de l'Effectif (vue d'ensemble,
	# condition, contrats, développement) : potentiel, fatigue, minutes, fin de contrat et salaire restent lisibles à l'écran.
	var colonnes := {"POT.": false, "FAT.": false, "MIN.": false, "FIN DE CONTRAT": false, "SALAIRE": false}
	for vue in 4:
		await keyboard(named("RosterTab" + str(vue)) as BaseButton, "onglet %d de l’Effectif" % vue)
		var zone := named("RosterHeader") if vue != 2 else named("CarnetSquad")
		if zone == null: zone = app.body
		for control: Control in zone.find_children("*", "Control", true, false):
			if not (control is Label or control is Button) or not inside(control, app.body_scroll): continue
			var texte := str(control.text).replace("▲", "").replace("▼", "").strip_edges().to_upper()
			for cle: String in colonnes:
				if texte == cle or (cle == "SALAIRE" and texte.begins_with("SALAIRE")) or (cle == "FIN DE CONTRAT" and vue == 2 and texte == "FIN"): colonnes[cle] = true
	for cle: String in colonnes:
		check(colonnes[cle], "Colonne visible %s %s" % [cle, resolution])
	check(colonnes["MIN."], "Colonne Minutes visible " + str(resolution))
	await keyboard(named("RosterTab0") as BaseButton, "retour à la vue d’ensemble de l’Effectif")
	roster = named("SquadScroll")
	rows = roster_rows(roster)
	for row: Control in rows:
		check(rect(row).size.y <= 34, "Ligne dense et entière " + str(row.name))
	measurements.append({"window":str(resolution),"canvas":str(app.size),"roster_rows":complete.size(),
		"roster_height":rect(roster).size.y if roster != null else 0,"row_height":rect(rows[0]).size.y if not rows.is_empty() else 0,
		"office_tiles":7,"roster_variant":"immersive"})
	await capture("effectif-" + str(resolution.x))
	# Entrée sur la ligne du joueur ouvre sa fiche complète (l'ancien bouton « Fiche complète » n'existe plus).
	var ligne: Array = rows.filter(func(r: Node): return str(r.get_meta("player_id")) == str(player.id))
	check(ligne.size() == 1, "Ligne du joueur annoté dans l’Effectif " + str(resolution))
	if ligne.is_empty(): return
	(roster as ScrollContainer).ensure_control_visible(ligne[0])
	await keyboard(ligne[0] as BaseButton, "ouvrir la fiche joueur complète")
	await immersive_profile(player, resolution)
	await keyboard(named("PlayerBackToSquad") as BaseButton, "retour à l’effectif")
	check(named("ImmersiveRosterTable") != null and app.selected_player == str(player.id), "Retour au tableau sans perdre le joueur")

func labels(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node == null: return result
	for label: Label in node.find_children("*", "Label", true, false): result.append(label.text)
	return result

func fact(id: String, value: Variant) -> void:
	var label := named(id) as Label
	check(label != null and label.text == str(value), "Fait projeté exactement · %s = %s" % [id,value])

func immersive_profile(player: Dictionary, resolution: Vector2i) -> void:
	var profile := named("ImmersivePlayerFull")
	check(profile != null and str(profile.get_meta("player_id", "")) == str(player.id), "Dossier immersif ouvert depuis l’effectif " + str(resolution))
	if profile == null: return
	fact("ProfilePlayerName", str(player.name).to_upper())
	var hero := labels(named("FullPlayerHero"))
	for value in [G.rating_text(player,true), G.potential_text(player)]:
		check(value in hero, "Identité et niveau du vrai dossier " + value)
	# Le poste est dans le surtitre de la fiche (« FICHE JOUEUR · PILIER GAUCHE »).
	var kicker := named("FullPlayerKicker") as Label
	check(kicker != null and kicker.text.contains(str(player.pos).to_upper()), "Identité et niveau du vrai dossier " + str(player.pos).to_upper())
	# Fiche actuelle : cinq onglets (vue d'ensemble avec les attributs, performances, contrat, développement, repères).
	for i in [0, 2, 3, 4, 5]: check(inside(named("FullPlayerTab"+str(i)), app.body_scroll), "Onglet immersif visible " + str(i))
	check(inside(named("OpenPlayerCoachNote"), app.body_scroll) and inside(named("FullPlayerCompare"), app.body_scroll), "Carnet et comparaison visibles sur la fiche")
	await keyboard(named("FullPlayerTab0"), "attributs du joueur (vue d’ensemble)")
	var detailed := named("PlayerDetailedAttributes")
	check(detailed != null and detailed.find_children("PlayerDetailedAttribute_*", "Label", true, false).size() == 36, "Les 36 attributs sont présents dans la fiche immersive")
	for attribute: String in player.attributesV2:
		var label := named("PlayerDetailedAttribute_" + attribute) as Label
		check(inside(label, app.body_scroll) and label.text == PlayerAttributes.caption(player.attributesV2[attribute]), "Attribut visible issu du moteur " + attribute)
	check(app.find_children("PlayerAttribute_*", "Label", true, false).is_empty(), "Fiche immersive sans projection des onze compétences")
	await keyboard(named("FullPlayerTab2"), "performances du joueur")
	var performances := labels(named("ImmersivePlayerFull"))
	for value in [G.n(player.appearances), G.n(player.minutes)]:
		check(value in performances, "Performances fidèles " + value)
	check("NOTE AU POSTE" not in performances,"La note au poste reste réservée à la tactique")
	# Condition et charge : carte Disponibilité des Performances (l'onglet Contrat montre le temps de jeu promis, idée 16).
	check(G.n(player.condition) + " %" in performances and G.n(player.physicalLoad) in performances, "Condition et charge exactes dans Performances")
	check(inside(named("PlayerLoad"), app.body_scroll), "Charge individuelle visible dans Performances")
	await keyboard(named("FullPlayerTab3"), "contrat du joueur")
	var contract := labels(named("ImmersivePlayerFull"))
	check(G.salary(player.salary) in contract and G.contract_year(player.get("contractEnd")) in contract, "Salaire et échéance exacts dans Contrat")
	check(inside(named("PlayerPlayingTime"), app.body_scroll), "Temps de jeu promis visible dans Contrat")
	var renewal := named("OfferRenewal") as Button
	check(inside(renewal, app.body_scroll) and renewal.disabled == not bool(player.renewal.available), "Offre de prolongation visible et disponibilité exacte")
	await keyboard(named("FullPlayerTab4"), "développement du joueur")
	# Joueur de l'effectif : progression par qualité (courbe 12 mois du relevé mensuel, 36 qualités à cocher).
	var development := labels(named("ProgressionCourbeCarte"))
	check(inside(named("ProgressionCourbeCarte"), app.body_scroll) and G.n(player.rating) in development and G.potential_text(player) in development, "Niveau et potentiel lisibles dans Développement")
	check(inside(named("ProgressionCourbe"), app.body_scroll), "Courbe des 12 mois visible")
	var coches: Array = named("ProgressionGrille").find_children("ProgressionCoche_*", "Button", true, false) if named("ProgressionGrille") != null else []
	check(coches.size() == 36, "Les 36 qualités à cocher")
	for attribute: String in player.attributesV2:
		var note := named("ProgressionNote_" + attribute) as Label
		check(note != null and note.text == G.n(roundi(float(player.attributesV2[attribute]))), "Note de la qualité issue du moteur " + attribute)
	await keyboard(named("FullPlayerTab5"), "repères du joueur")
	var sources := labels(named("ImmersivePlayerFull"))
	var position: Dictionary = player.rosterProfile.position
	check("Poste d’origine : " + str(position.primary) in sources and
		"Qualifications de départ : " + ", ".join(position.qualifications) in sources, "Poste d’origine et qualifications exacts dans Repères")
	await keyboard(named("FullPlayerTab0"), "revenir à l’aperçu")
	await capture("fiche-joueur-" + str(resolution.x))

func route_reading(resolution: Vector2i) -> void:
	for route in ["Effectif","Composition","Préparation","Recrutement","Calendrier","Classements","Finances","Club"]:
		await navigate(route)
		check(inside(app.body_scroll), "Espace de travail visible %s %s" % [route,resolution])
		if resolution.x == 2560:
			var outer: VScrollBar = app.body_scroll.get_v_scroll_bar()
			if route == "Calendrier":
				# Toute la saison sur une page qui défile (décision de Léo, #1028) : plus de pagination, la page
				# globale ne défile que de ce que la liste dépasse de son cadre d'origine (760 unités).
				var season := named("CalendarScroll")
				check(named("CalendarPagination") == null and season != null and outer.max_value - outer.page <= rect(season).size.y - 760.0 * rect(app.body).size.x / 2248.0 + 1.0, "Calendrier : toute la saison sur une page qui défile, sans autre débord · " + str(resolution))
			else: check(outer.max_value <= outer.page + 1, "Aucun défilement global nécessaire en 1440p · " + route)
		if route == "Composition":
			for id in ["LineupSlot01", "LineupAutomatic"]:
				check(inside(named(id), app.body_scroll), "Commande de composition directement visible %s %s" % [id,resolution])
		if route == "Préparation":
			# Entraînement est rangé sous Tactique : onglet « Entraînement » de la Préparation (plus d'entrée de rail).
			await keyboard(named("PreparationTabEntrainement"), "ouvrir Entraînement depuis la Préparation")
			var native := named("ImmersiveTraining") != null
			var controls := ["TrainingValidateWeek", "TrainingEditSelected", "TrainingBackToPreparation"] if native else ["PreparationTrain_repos", "PreparationTrain_normal", "PreparationTrain_intense", "CollectiveFocus", "OpponentLevel", "PreparationMatch"]
			for id: String in controls:
				check(inside(named(id), app.body_scroll), "Action d’entraînement directement visible %s %s" % [id,resolution])
		if route == "Recrutement":
			var tab := named("MarketTab1") as Button
			var immersive_market := tab != null
			if immersive_market: await keyboard(tab, "ouvrir les joueurs du marché")
			var market := named("ImmersiveMarketRows" if immersive_market else "MarketScroll")
			check(market != null and inside(market, app.body_scroll), "Joueurs du marché dans un vrai viewport " + str(resolution))
			if market != null:
				var offers := market.find_children("*", "Button", true, false)
				check(not offers.is_empty(), "Marché : des actions ou lignes sont présentes")
				for button: Button in offers:
					check(inside(button, market), "Offre, ligne ou suivi visible " + str(button.name))
			if immersive_market:
				check(inside(named("OfferRecruitment"), app.body_scroll), "Offre du joueur sélectionné accessible dans le marché immersif")
				var follow := app.body.find_child("Follow*", true, false) as Button
				check(inside(follow, app.body_scroll), "Suivi du joueur sélectionné accessible dans le marché immersif")
		for list_id in ["CalendarScroll","StandingsScroll","FinanceScroll"]:
			var list := named(list_id) as ScrollContainer
			if list == null: continue
			check(inside(list, app.body_scroll), "Viewport visible " + list_id)
			check(list.get_v_scroll_bar().max_value <= list.get_v_scroll_bar().page + 1, "Page paginée sans défilement local " + list_id)
		for pager_id in ["RosterPagination","MarketPagination","CalendarPagination","StandingsPagination","FinancePagination"]:
			var pager := named(pager_id)
			if pager != null and pager.is_visible_in_tree():
				check(inside(pager, app.body_scroll), "Pagination directement accessible %s %s" % [pager_id,resolution])
		if route == "Finances": await capture("finances-"+str(resolution.x))
		await capture(route.to_lower()+"-dense-"+str(resolution.x))

func responsive_reading(player: Dictionary, annotation: String) -> void:
	await navigate("Bureau")
	var office := named("ImmersiveOffice")
	var standings := named("OfficeStandings")
	var standings_action := named("OfficeStandingsAction") as Button
	check(office != null and standings != null and standings_action != null, "Le Bureau compact et le cap sportif sont montés")
	if standings_action != null:
		standings_action.grab_focus()
		await settle()
		for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(1280,720)]:
			await resize_to(resolution)
			check(named("ImmersiveOffice") == office and named("OfficeStandings") == standings and named("OfficeStandingsAction") == standings_action, "Bureau adapté sur les mêmes instances " + str(resolution))
			check(standings_action.has_focus() and inside(standings_action, app.body_scroll), "Cap sportif garde le focus et sa visibilité " + str(resolution))
	app.selected_player = str(player.id)
	await navigate("Effectif")
	var search := named("RosterSearch") as LineEdit
	check(search != null, "Champ de recherche de l’Effectif")
	if search == null: return
	search.text = "Équipe œuvrée — éléphant"
	search.caret_column = 10
	search.select(2, 10)
	search.grab_focus()
	var table := named("ImmersiveRosterTable")
	check(table != null, "Tableau de l’Effectif disponible avant les redimensionnements")
	await settle()
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(2560,1440), Vector2i(1920,1080)]:
		await resize_to(resolution)
		check(named("RosterSearch") == search and search.text == "Équipe œuvrée — éléphant" and search.caret_column == 10 and search.has_selection(), "Saisie Unicode, caret et sélection conservés " + str(resolution))
		check(search.has_focus() and named("ImmersiveRosterTable") == table and app.selected_player == str(player.id), "Focus et dossier conservés au redimensionnement " + str(resolution))
	search.text = ""
	search.text_changed.emit("")
	await settle()
	await first_roster_page()
	# Le contexte du joueur (moyennes de l'effectif, pairs du même poste, développement) est l'onglet Repères de sa fiche.
	var ligne: Array = roster_rows(named("SquadScroll")).filter(func(r: Node): return str(r.get_meta("player_id")) == str(player.id))
	check(ligne.size() == 1, "Ligne du joueur annoté accessible au clavier")
	if ligne.is_empty(): return
	(named("SquadScroll") as ScrollContainer).ensure_control_visible(ligne[0])
	await keyboard(ligne[0] as BaseButton, "ouvrir la fiche du joueur annoté")
	await keyboard(named("FullPlayerTab5"), "repères du joueur annoté")
	var contextes := named("ProfileContexts")
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(2560,1440), Vector2i(1920,1080)]:
		await resize_to(resolution)
		var cohort := named("ProfileContextCohort")
		check(cohort != null and cohort.is_visible_in_tree() and inside(named("FullPlayerContexts"), app.body_scroll), "Contexte du joueur lisible dans sa fiche " + str(resolution))
		var peers := named("ProfileContextPeers")
		var same: Array = app.model.squad.filter(func(member: Dictionary): return member.id != player.id and member.pos == player.pos)
		check(peers != null and peers.find_children("ProfilePeerCompare*", "Button", true, false).filter(func(action: Control): return action.is_visible_in_tree()).size() == mini(5, same.size()), "Jusqu’à cinq coéquipiers du même poste " + str(resolution))
	await compact_context(player)
	await navigate("Effectif")
	await first_roster_page()
	var second: Button
	for row: Button in roster_rows(named("SquadScroll")):
		if str(row.get_meta("player_id")) != str(player.id): second = row; break
	check(second != null, "Autre joueur accessible au clavier")
	if second == null: return
	var second_id := str(second.get_meta("player_id"))
	await keyboard(second, "ouvrir un autre dossier par ID")
	var fiche := named("ImmersivePlayerFull")
	check(app.selected_player == second_id and fiche != null and str(fiche.get_meta("player_id", "")) == second_id, "Le nouveau dossier est celui de la ligne choisie")
	await keyboard(named("FullPlayerTab5"), "repères de l’autre joueur")
	check(named("ProfileNotePreview") == null, "Aucune note inventée pour l’autre identifiant")
	await keyboard(named("OpenPlayerCoachNote"), "ouvrir le carnet de l’autre joueur")
	var notebook := app.get_node_or_null("CoachNotebook") as AcceptDialog
	var editor := named("CoachNoteText") as TextEdit
	check(notebook != null and editor != null and editor.text.is_empty() and editor.text != annotation, "L’autre dossier ouvre son propre carnet vide")
	if notebook != null:
		notebook.hide()
		notebook.queue_free()
		await settle()
	for resolution in [Vector2i(1600,900), Vector2i(1280,720)]:
		await resize_to(resolution)
		var apres := named("ImmersivePlayerFull")
		check(apres != null and str(apres.get_meta("player_id", "")) == second_id and app.selected_player == second_id, "Dossier remplacé puis redimensionné sans changer de joueur")
	await capture("effectif-focus-" + str(root.size.x))

func compact_context(player: Dictionary) -> void:
	var cohort := named("ProfileContextCohort")
	var peers := named("ProfileContextPeers")
	check(cohort != null and peers != null and cohort.is_visible_in_tree() and peers.is_visible_in_tree(), "Deux contextes desktop distincts des six faits")
	if cohort == null or peers == null: return
	check(app.find_children("ProfileContext*", "PanelContainer", true, false).size() == 4, "Quatre panneaux de contexte dans les repères du joueur")
	for field in ["rating", "condition", "age", "salary"]:
		var total := 0.0
		for member: Dictionary in app.model.squad: total += float(member[field])
		var average := named("ProfileMean_" + field) as Label
		check(average != null and average.text.contains(" / "), "Moyenne comparative présente " + field)
		if average == null or not average.text.contains(" / "): continue
		var mean: float = total / app.model.squad.size()
		var expected := G.salary_amount(mean) if field == "salary" else ("%.1f" % mean).replace(".",",") + ("%" if field == "condition" else " ans" if field == "age" else "")
		check(average.text.split(" / ")[1] == expected, "Moyenne publique exacte et unité affichée " + field)

	var same: Array = app.model.squad.filter(func(member: Dictionary): return str(member.id) != str(player.id) and member.pos == player.pos)
	var actions := peers.find_children("ProfilePeerCompare*", "Button", true, false).filter(func(action: Control): return action.is_visible_in_tree())
	check(actions.size() == mini(5, same.size()), "Jusqu’à cinq coéquipiers du même poste dans les repères")
	for action: Button in actions:
		check(same.any(func(member: Dictionary): return str(member.id) == str(action.get_meta("peer_id"))), "Cible du même poste par identifiant")
	var professional: Array = app.model.decisions.development.professionals.filter(func(record: Dictionary): return record.id == player.id)
	var delta := named("ProfileDevelopmentDelta") as Label
	check(not professional.is_empty() and delta != null and delta.text.to_int() == int(professional[0].rating-professional[0].development.seasonStart), "Développement comparé au début de saison")
	if actions.is_empty(): return
	var peer := actions[0] as Button
	var requested := [str(player.id), str(peer.get_meta("peer_id"))]
	var defile := peer.get_parent()
	while defile != null and not defile is ScrollContainer: defile = defile.get_parent()
	if defile != null: (defile as ScrollContainer).ensure_control_visible(peer)
	await keyboard(peer, "comparer un pair du même poste")
	# Le comparateur est un écran (plus une fenêtre) : les deux joueurs demandés, par identifiant, puis retour.
	check(app.route == "Comparateur" and named("ImmersiveComparateur") != null, "Vrai comparateur ouvert")
	if named("ImmersiveComparateur") == null: return
	for slot in 2:
		var choice := named("ComparateurJoueur"+str(slot)) as OptionButton
		check(choice != null and str(choice.get_item_metadata(choice.selected)) == requested[slot], "Comparateur ouvre le dossier exact " + str(slot))
	await keyboard(named("ComparateurRetour"), "retour du comparateur")

func immersive_drafts(player: Dictionary, annotation: String) -> void:
	# Entrée sur la ligne du joueur ouvre sa fiche (l'ancien bouton « Fiche complète » n'existe plus).
	var ligne: Array = roster_rows(named("SquadScroll")).filter(func(r: Node): return str(r.get_meta("player_id")) == str(player.id))
	if not ligne.is_empty(): (named("SquadScroll") as ScrollContainer).ensure_control_visible(ligne[0])
	await keyboard(ligne[0] as BaseButton if not ligne.is_empty() else null, "ouvrir le dossier du joueur annoté")
	await keyboard(named("FullPlayerTab2"), "ouvrir ses Performances (carte Disponibilité)")
	await keyboard(named("PlayerLoad"), "ouvrir le réglage de charge")
	# La charge individuelle est une sous-page de la fiche (jamais une fenêtre) : les quatre vrais choix, puis retour.
	check(named("IndividualInstructions") != null and named("FicheChargePage") != null, "Le bouton Charge ouvre les vrais choix")
	for mode in ["collective","repos","normal","intense"]:
		var choix := named("IndividualLoad_"+mode)
		check(choix != null and inside(choix, app.body_scroll), "Mode de charge réel " + mode)
	await keyboard(named("FicheChargeRetour"), "retour de la charge à la fiche")
	if named("ImmersivePlayerFull") == null or named("OfferRenewal") == null:
		var retour: Array = roster_rows(named("SquadScroll")).filter(func(r: Node): return str(r.get_meta("player_id")) == str(player.id))
		if not retour.is_empty():
			(named("SquadScroll") as ScrollContainer).ensure_control_visible(retour[0])
			await keyboard(retour[0] as BaseButton, "rouvrir le dossier du joueur annoté")
		await keyboard(named("FullPlayerTab3"), "rouvrir son Contrat")
	await keyboard(named("OfferRenewal"), "ouvrir la vraie offre sans la confirmer")
	var offer := app.get_node_or_null("ContractOffer") as ConfirmationDialog
	var salary_box := named("OfferSalary") as SpinBox
	check(offer != null and salary_box != null, "Dialogue natif d’offre de contrat")
	if offer != null and salary_box != null:
		var salary := salary_box.get_line_edit()
		salary.grab_focus()
		await settle()
		salary.text = "12345"
		salary.caret_column = 3
		for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
			await resize_to(resolution)
			check(is_instance_valid(offer) and offer.visible and salary.text == "12345" and salary.caret_column == 3, "Brouillon du même dialogue préservé " + str(resolution))
			await capture("contrat-" + str(resolution.x))
		offer.hide()
		offer.queue_free()
		await settle()
	await keyboard(named("OpenPlayerCoachNote"), "ouvrir la vraie note du joueur")
	var notebook := app.get_node_or_null("CoachNotebook") as AcceptDialog
	var editor := named("CoachNoteText") as TextEdit
	var picker := named("CoachNoteTarget") as OptionButton
	check(notebook != null and editor != null and editor.text == annotation, "La fiche immersive ouvre la seule note persistée")
	check(picker != null and str(picker.get_item_metadata(picker.selected)) == str(player.id), "Le carnet vise l’identifiant exact de la fiche")
	if notebook == null or editor == null: return
	editor.text = "Repère PC : garder ce brouillon 😀"
	editor.text_changed.emit()
	for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,900), Vector2i(1920,1080), Vector2i(2560,1440)]:
		await resize_to(resolution)
		check(app.get_node_or_null("CoachNotebook") == notebook and editor.text == "Repère PC : garder ce brouillon 😀", "Même carnet et brouillon Unicode après resize " + str(resolution))
	notebook.hide()
	notebook.queue_free()
	await settle()
	app.management_ui.compare = []
	await keyboard(named("FullPlayerCompare"), "comparer depuis la fiche immersive")
	# Le comparateur est un écran : la fiche ouverte en premier joueur, le second choix ouvert à tout l'effectif.
	check(app.route == "Comparateur" and named("ImmersiveComparateur") != null, "La fiche immersive ouvre le comparateur réel")
	if named("ImmersiveComparateur") == null: return
	var first := named("ComparateurJoueur0") as OptionButton
	var other := named("ComparateurJoueur1") as OptionButton
	check(first != null and str(first.get_item_metadata(first.selected)) == str(player.id), "Le comparateur conserve l’identifiant de la fiche ouverte")
	check(other != null and other.item_count >= app.model.squad.size() + 1, "Le second comparateur expose tous les joueurs de l’effectif")
	await keyboard(named("ComparateurRetour"), "retour du comparateur")
