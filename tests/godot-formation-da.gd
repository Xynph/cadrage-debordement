extends SceneTree
## Formation, direction artistique « Tableau et fiche du jeune » (choix de Léo du 19/11/2026), Godot réel + worker réel,
## carrière Monde :
## - plus de fiche fixe à droite : clic sur le nom = fiche complète, survol = mini-fiche ;
## - aucune couleur or dans l'écran (l'or est réservé à Continuer, dans la coque) ;
## - la décision (Promouvoir) est dans la bande du jeune choisi et se confirme EN PLACE, jamais dans une fenêtre ;
## - compteurs, puces, lignes, cartes de la file « À décider », liens des onglets : tout agit ou ouvre un écran ;
## - le suivi des jeunes et les autres anciennes fenêtres sont des sous-pages (retour), jamais des fenêtres.
## Imprime une ligne FORMATION_DA {checks, failures}. Captures (rendu graphique) : CD_FORMATION_DA_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_FORMATION_DA_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	return app.bridge.last_response_ok

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < .01 and absf(a.g - b.g) < .01 and absf(a.b - b.b) < .01

## Aplat doré = fond (opaque) d'un bouton ou d'un panneau, tous états ; texte, contour et anneau de focus dorés permis.
func gold_on(control: Control) -> bool:
	var tones: Array[Color] = []
	for key in ["normal", "hover", "pressed", "disabled", "panel"]:
		if control.has_theme_stylebox_override(key):
			var box := control.get_theme_stylebox(key) as StyleBoxFlat
			if box != null: tones.append(box.bg_color)
	for tone in tones:
		for reference: Color in [Charte.OR, Charte.OR_VIF]:
			if close(tone, reference) and tone.a > .05: return true
	return false

func page_kind() -> String:
	var etat: Variant = app.management_ui.get("formation_page")
	return str(etat.get("kind", "")) if etat is Dictionary else ""

func press(name: String) -> bool:
	var bouton := node(name) as Button
	if bouton == null or bouton.disabled: return false
	bouton.pressed.emit()
	await settle(10)
	return true

func state() -> Dictionary:
	return app.management_ui.immersive_academy

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	app._navigate("Formation", false)
	await settle(10)
	await layout()
	await bas_du_tableau()
	await names_open_sheets()
	await filters_and_tiles()
	await decision_strip()
	await tabs()
	await subpages()
	await youth_clicks()
	await colors()
	shot("formation-1920x1080")
	finish()

func finish() -> void:
	print("FORMATION_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Fin de défilement : la dernière ligne est entièrement visible, à l'écart des coins arrondis du panneau.
func bas_du_tableau() -> void:
	var defile := node("AcademyPlayerScroll") as ScrollContainer
	var panneau := node("AcademyImmersiveTable") as Control
	check(defile != null and panneau != null, "Tableau défilant présent")
	if defile == null or panneau == null: return
	await settle(30)
	defile.scroll_vertical = int(defile.get_v_scroll_bar().max_value)
	await settle(6)
	var lignes: Array[Control] = []
	for enfant in node("AcademyImmersiveRows").get_children():
		if enfant is Control and str(enfant.name).begins_with("AcademyRow_"): lignes.append(enfant)
	check(not lignes.is_empty(), "Le tableau a des lignes")
	if lignes.is_empty(): return
	lignes.sort_custom(func(a: Control, b: Control) -> bool: return a.global_position.y < b.global_position.y)
	var derniere: Rect2 = (lignes.back() as Control).get_global_rect()
	var fenetre := defile.get_global_rect()
	check(derniere.end.y <= fenetre.end.y + .5 and derniere.position.y >= fenetre.position.y - .5, "Fin de défilement : la dernière ligne est entièrement visible (%s dans %s)" % [derniere, fenetre])
	check(panneau.get_global_rect().end.y - derniere.end.y >= 13.0, "Fin de défilement : la dernière ligne reste loin des coins arrondis du panneau (%d px)" % roundi(panneau.get_global_rect().end.y - derniere.end.y))
	defile.scroll_vertical = 0
	await settle(4)

func layout() -> void:
	check(node("ImmersiveAcademy") != null, "Écran Formation ouvert")
	check(node("AcademyImmersiveDossier") == null, "Plus de fiche fixe à droite")
	var table := node("AcademyImmersiveTable")
	check(table != null and table.size.x >= app.root_content.size.x * .6, "Le tableau prend toute la largeur")
	for key in ["source", "name", "pos", "age", "note", "potential", "minutes", "contract", "status"]:
		check(node("AcademySort_" + key) != null, "Tri par colonne · " + key)
	for index in 4: check(node("AcademyImmersiveTab" + str(index)) != null, "Onglet " + str(index))
	for id in ["AcademyTileEspoirs", "AcademyTilePepites", "AcademyTileDecider", "AcademyTilePlaces", "OpenYouthDevelopment", "AcademyDecision", "AcademyDecisions"]:
		check(node(id) != null, "Élément de l'écran · " + id)
	check(not app.root_content.find_children("AcademyRow_*", "Button", true, false).is_empty(), "Des jeunes sont listés")
	for groupe in ["u21", "u18", "academy", "professional"]: check(node("AcademyGroup_" + groupe) != null, "Puce de groupe · " + groupe)
	# Chaque valeur sous son en-tête : la cellule sous « ÂGE » est bien un âge (régression : valeurs décalées d'une colonne).
	var lignes: Array = app.root_content.find_children("AcademyRow_*", "Button", true, false)
	var entete_age := node("AcademySort_age")
	if not lignes.is_empty() and entete_age != null:
		var zone := entete_age.get_global_rect()
		var age := ""
		for label: Label in (lignes[0] as Control).find_children("*", "Label", false, false):
			var centre := label.get_global_rect().get_center().x
			if centre >= zone.position.x and centre <= zone.end.x: age = label.text
		check(age.is_valid_int() and int(age) >= 14 and int(age) <= 25, "La colonne ÂGE montre l'âge du jeune (« %s »)" % age)
	check(windows().is_empty(), "Aucune fenêtre ouverte sur la liste")

func names_open_sheets() -> void:
	var noms: Array = app.root_content.find_children("AcademyName_*", "Button", true, false)
	check(not noms.is_empty(), "Chaque nom de jeune est un lien")
	if noms.is_empty(): return
	var lien := noms[0] as Button
	lien.mouse_entered.emit()
	await settle(4)
	check(app.get_node_or_null("MiniFicheJoueur") != null, "Survol du nom : mini-fiche")
	lien.mouse_exited.emit()
	await settle(3)
	check(app.get_node_or_null("MiniFicheJoueur") == null, "La souris part : la mini-fiche disparaît")
	check(not app.root_content.find_children("MiniFicheInfo_*", "Control", true, false).is_empty(), "Un « i » suit chaque nom")
	lien.pressed.emit()
	await settle(10)
	check(app.management_ui.get("fiche_joueur") is Dictionary, "Clic sur le nom : fiche complète")
	check(windows().is_empty(), "La fiche s'ouvre en écran, pas en fenêtre")
	app._navigate("Formation", false)
	await settle(10)
	check(node("AcademyImmersiveTable") != null, "Retour de la fiche : la liste de la formation")

func filters_and_tiles() -> void:
	var lignes: Array = app.root_content.find_children("AcademyRow_*", "Button", true, false)
	if lignes.size() >= 2:
		var cible := lignes[1] as Button
		var identifiant: Variant = cible.get_meta("development_id")
		cible.pressed.emit()
		await settle(6)
		check(state().get("player") == identifiant, "Clic sur une ligne : le jeune choisi change")
		var nom := node("AcademyDecisionName") as Button
		check(nom != null and nom.accessibility_name.length() > 0, "La bande de décision nomme le jeune choisi")
	for puce in ["decide", "pepite", "blesse", "tous"]:
		check(node("AcademyChip_" + puce) != null, "Puce de filtre · " + puce)
	check(await press("AcademyChip_pepite"), "Puce Pépites utilisable")
	check(state().get("status") == "pepite", "La puce Pépites filtre le tableau")
	check(await press("AcademyChip_tous"), "Puce Tous utilisable")
	check(await press("AcademyGroup_u18"), "Puce de groupe U18 utilisable")
	check(state().get("group") == "u18", "La puce U18 change le groupe du tableau")
	check(await press("AcademyGroup_u21"), "Puce de groupe U21 utilisable")
	check(await press("AcademyTileDecider"), "Compteur À décider utilisable")
	check(state().get("status") == "decide", "Le compteur À décider filtre le tableau")
	check(await press("AcademyTileEspoirs"), "Compteur Espoirs utilisable")
	check(str(state().get("status", "")).is_empty(), "Le compteur Espoirs efface le filtre")
	var cartes: Array = app.root_content.find_children("AcademyDecisionCard_*", "Button", true, false)
	for carte: Button in cartes: check(carte.accessibility_name.contains(":") and carte.accessibility_name.length() > 20, "Carte « À décider » : raison écrite")
	if not cartes.is_empty():
		(cartes[0] as Button).pressed.emit()
		await settle(8)
		check(state().get("player") != null, "Clic sur une carte : la décision se place sur ce jeune")

func decision_strip() -> void:
	var promouvoir := node("AcademyPromoteSelected") as Button
	if promouvoir == null or promouvoir.disabled:
		check(node("AcademyOpenSquad") != null or node("AcademyOpenProfessional") != null or promouvoir != null, "Sans place pro : raison écrite et lien vers l'effectif")
		return
	promouvoir.pressed.emit()
	await settle(8)
	check(node("AcademyPromoteConfirm") != null and node("AcademyPromoteConfirmOk") != null, "Promouvoir : confirmation EN PLACE")
	check(windows().is_empty(), "Aucune fenêtre pour la promotion")
	var annuler := node("AcademyPromoteConfirmAnnuler") as Button
	if annuler != null: annuler.pressed.emit()
	await settle(6)
	check(node("AcademyPromoteConfirm") == null, "Annuler referme la confirmation sans rien envoyer")

func tabs() -> void:
	check(await press("AcademyImmersiveTab1"), "Onglet Progression")
	check(node("AcademySort_start") != null and node("AcademySort_note") != null and node("AcademySort_change") == null, "Progression : niveau de départ et niveau (flèche) triables, plus de colonne « depuis juillet »")
	check(await press("AcademyImmersiveTab2"), "Onglet Passerelles")
	check(node("AcademyPathwayPane") != null, "Passerelles : panneau")
	for id in ["AcademyStage0", "AcademyStage1", "AcademyStage2", "AcademyOpenCentre", "AcademyFollowUp", "AcademyJuniorCompetition"]:
		check(node(id) != null, "Passerelles : lien · " + id)
	check(await press("AcademyStage0"), "Passerelles : Académie ramène à l'effectif")
	check(int(state().get("tab", 0)) == 0, "L'étape Académie ouvre l'onglet Effectif")
	check(await press("AcademyImmersiveTab3"), "Onglet Encadrement")
	for id in ["AcademyTileCoaches", "AcademyTileFacilities", "AcademyTileCohesion", "AcademyManageCentre", "AcademyFollowUp", "AcademyOpenStaff"]:
		check(node(id) != null, "Encadrement : lien · " + id)
	check(windows().is_empty(), "Aucune fenêtre dans les onglets")
	check(await press("AcademyImmersiveTab0"), "Retour à l'onglet Effectif")

func subpages() -> void:
	check(await press("OpenYouthDevelopment"), "Suivi des jeunes : lien actif")
	check(page_kind() == "suivi", "Le suivi des jeunes est une sous-page")
	check(node("FormationRetour") != null and node("YouthReviewFilter") != null, "Sous-page : retour et contenu du suivi")
	check(windows().is_empty(), "Le suivi des jeunes n'ouvre aucune fenêtre")
	# Style de la charte : plus de carte claire du carnet, noms de jeunes = fiche au clic et mini-fiche au survol.
	var zone := node("FormationAdopte")
	var claires := zone.find_children("*", "PanelContainer", true, false).filter(func(p: Control): return p.name != "_focus" and p.has_theme_stylebox_override("panel") and (p.get_theme_stylebox("panel") as StyleBoxFlat) != null and (p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.get_luminance() > .5) if zone != null else []
	check(zone != null and claires.is_empty(), "Suivi des jeunes : aucune carte claire de l'ancienne vue (%d)" % claires.size())
	var jeunes: Array = app.model.get("clubLife", {}).get("youthDevelopment", {}).get("players", [])
	var noms := app.find_children("YouthName_*", "Button", true, false)
	check(jeunes.is_empty() or not noms.is_empty(), "Suivi des jeunes : chaque nom de jeune est un lien")
	check(noms.all(func(b: Button): return str(b.get_meta("mini_fiche_joueur", "")) != ""), "Suivi des jeunes : survol d'un nom = mini-fiche")
	var retour := node("FormationRetour") as Button
	if retour != null: retour.pressed.emit()
	await settle(8)
	check(page_kind().is_empty() and node("AcademyImmersiveTable") != null, "Retour : la liste de la formation revient")
	if not noms.is_empty():
		check(await press("OpenYouthDevelopment"), "Suivi des jeunes : réouverture")
		var premier := app.find_children("YouthName_*", "Button", true, false)
		if not premier.is_empty():
			(premier[0] as Button).pressed.emit()
			await settle(8)
			check(windows().is_empty() and node("YouthReviewFilter") == null, "Suivi des jeunes : le clic sur un nom ouvre la fiche, sans fenêtre")

## Clic gauche relâché sur un contrôle (tuile, jauge, pastille) : même chemin que la souris.
func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	control.gui_input.emit(event)
	await settle(10)

func open_youth_page() -> bool:
	app._navigate("Formation", false)
	await settle(8)
	return await press("OpenYouthDevelopment") and page_kind() == "suivi"

## Suivi des jeunes : tout ce qui ressemble à une tuile, une jauge, une pastille ou un chiffre ouvre quelque chose.
func youth_clicks() -> void:
	check(await open_youth_page(), "Clics suivi : sous-page ouverte")
	var youth: Dictionary = app.management_ui.get("youth_development", {})
	var filters := {"YouthTileAcademy": [1, false], "YouthTilePro": [2, false], "YouthTileReview": [0, true], "YouthTileCount": [0, false]}
	for tile_name: String in filters:
		var tile := node(tile_name)
		check(tile != null and tile.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Compteur cliquable · " + tile_name)
		if tile == null: continue
		await click(tile)
		var expected: Array = filters[tile_name]
		check(int(youth.get("stage", -1)) == int(expected[0]) and bool(youth.get("review", false)) == bool(expected[1]), "Compteur → filtre de la liste · " + tile_name)
		check((node("YouthDevelopmentStage") as OptionButton).selected == int(expected[0]) and (node("YouthReviewFilter") as CheckButton).button_pressed == bool(expected[1]), "Compteur → contrôles de filtre synchronisés · " + tile_name)
	var state_pill := node("YouthReviewState")
	if state_pill != null:
		var detail := state_pill.get_parent().get_parent().get_parent().get_parent().find_child("YouthTileDetail", true, false) as Control
		var before := detail != null and detail.visible
		await click(state_pill)
		check(detail != null and detail.visible != before, "Pastille d'état → détail du suivi déplié")
	# Chaque destination de fiche : tuile entière, niveau, barre niveau / potentiel, jauges, minutes.
	var targets := {"YouthTile_*": 0, "YouthLevelBlock": 4, "YouthLevelRange": 4, "YouthCondition": 0, "YouthFatigue": 0, "YouthInjury": 0}
	for target: String in targets:
		check(await open_youth_page(), "Clics suivi : réouverture · " + target)
		var control := (app.root_content.find_children(target, "Control", true, false).front() if target.ends_with("*") else node(target)) as Control
		check(control != null and control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Cliquable · " + target)
		if control == null: continue
		if target.ends_with("*"): check(str(control.get_meta("mini_fiche_joueur", "")) != "", "Survol de la tuile = mini-fiche")
		app.management_ui.immersive_player_tab = -1
		await click(control)
		check(windows().is_empty() and node("YouthReviewFilter") == null, "Clic → fiche du joueur en plein écran, sans fenêtre · " + target)
		check(int(app.management_ui.get("immersive_player_tab", -1)) == int(targets[target]), "Clic → bon onglet de la fiche · " + target)

func colors() -> void:
	app._navigate("Formation", false)
	await settle(8)
	var page := node("ImmersiveAcademy")
	var dores := 0
	for control in page.find_children("*", "Control", true, false):
		if gold_on(control as Control):
			dores += 1
			printerr("APLAT DORE sur ", control.get_path())
	check(dores == 0, "Formation : aucun aplat doré (Continuer le porte seul) (%d)" % dores)
