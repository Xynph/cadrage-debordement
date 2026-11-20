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

func gold_on(control: Control) -> bool:
	var tones: Array[Color] = []
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if control.has_theme_color_override(key): tones.append(control.get_theme_color(key))
	for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if control.has_theme_stylebox_override(key):
			var box := control.get_theme_stylebox(key) as StyleBoxFlat
			if box != null: tones.append_array([box.bg_color, box.border_color])
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
	await names_open_sheets()
	await filters_and_tiles()
	await decision_strip()
	await tabs()
	await subpages()
	await colors()
	shot("formation-1920x1080")
	finish()

func finish() -> void:
	print("FORMATION_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func layout() -> void:
	check(node("ImmersiveAcademy") != null, "Écran Formation ouvert")
	check(node("AcademyImmersiveDossier") == null, "Plus de fiche fixe à droite")
	var table := node("AcademyImmersiveTable")
	check(table != null and table.size.x >= app.root_content.size.x * .6, "Le tableau prend toute la largeur")
	for key in ["source", "name", "pos", "age", "note", "potential", "change", "minutes", "contract", "status"]:
		check(node("AcademySort_" + key) != null, "Tri par colonne · " + key)
	for index in 4: check(node("AcademyImmersiveTab" + str(index)) != null, "Onglet " + str(index))
	for id in ["AcademyTileEspoirs", "AcademyTilePepites", "AcademyTileDecider", "AcademyTilePlaces", "OpenYouthDevelopment", "AcademyDecision", "AcademyDecisions"]:
		check(node(id) != null, "Élément de l'écran · " + id)
	check(not app.root_content.find_children("AcademyRow_*", "Button", true, false).is_empty(), "Des jeunes sont listés")
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
	check(node("AcademySort_start") != null and node("AcademySort_change") != null, "Progression : niveau de départ et gain triables")
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
	var retour := node("FormationRetour") as Button
	if retour != null: retour.pressed.emit()
	await settle(8)
	check(page_kind().is_empty() and node("AcademyImmersiveTable") != null, "Retour : la liste de la formation revient")

func colors() -> void:
	app._navigate("Formation", false)
	await settle(8)
	var page := node("ImmersiveAcademy")
	var dores := 0
	for control in page.find_children("*", "Control", true, false):
		if gold_on(control as Control):
			dores += 1
			printerr("OR sur ", control.get_path())
	check(dores == 0, "Aucune couleur or dans l'écran Formation (%d)" % dores)
