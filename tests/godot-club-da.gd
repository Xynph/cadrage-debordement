extends SceneTree
## Club, direction artistique « Deux colonnes, le conseil à gauche » (choix de Léo du 20/11/2026), Godot réel + worker réel,
## carrière Monde :
## - le conseil (confiance en chiffre, mot et seuils), « À décider », vestiaire et installations sont présents ;
## - aucune couleur or dans l'écran (l'or est réservé à Continuer, dans la coque) ;
## - tout ce qui ressemble à un lien, une ligne ou un chiffre change d'écran : aucune petite fenêtre ouverte ;
## - les noms de joueurs ouvrent la fiche (clic) ou la mini-fiche (survol) ;
## - les confirmations d'argent s'ouvrent EN PLACE ; contrat, mentorat et engagements du staff sont des sous-pages (retour + Échap).
## Imprime une ligne CLUB_DA {checks, failures}. Captures (rendu graphique) : CD_CLUB_DA_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const Pages = preload("res://ui/immersive08/club_pages.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_CLUB_DA_CAPTURES")

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

func overview() -> void:
	app.management_ui[app.Immersive.ClubCanvas.KEY] = "overview"
	app._navigate("Club")
	await settle(10)

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
	await overview()
	await layout()
	await colors()
	await links()
	await names()
	await tabs()
	await confirmation_en_place()
	await staff_pages()
	await overview()
	shot("club-1920x1080")
	finish()

func finish() -> void:
	print("CLUB_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Mise en page : titre, cinq onglets, bandeau, deux colonnes (conseil, installations / à décider, vestiaire).
func layout() -> void:
	check(node("ImmersiveClub") != null and node("ClubOverview") != null, "Écran Club ouvert (vue d'ensemble)")
	check(node("ClubTitle") != null and node("ClubSubtitle") != null, "Titre et sous-titre")
	for cle in ["overview", "direction", "infrastructure", "staff", "history"]: check(node("ClubTab_" + cle) != null, "Onglet " + cle)
	check(node("ClubStadium") != null, "Bandeau du club")
	for id in ["ClubCouncil", "ClubFacilities", "ClubDecide", "ClubLocker"]: check(node(id) != null, "Bloc " + id)
	var conseil := node("ClubCouncil")
	var decider := node("ClubDecide")
	check(conseil != null and decider != null and conseil.global_position.x < decider.global_position.x, "Le conseil est à gauche, « À décider » à droite")
	check(node("ClubTrustValue") != null, "Confiance en chiffre")
	check(node("ClubTrustWord") != null or node("ClubTrustNone") != null, "Confiance dite en mot (ou premier bilan à venir)")
	check(node("ClubObjectives") != null and node("ClubGoal") != null, "Objectif de la saison")
	check(node("ClubTrustTable") != null, "Tableau « ce qui a fait bouger la confiance »")
	check(node("ClubFacilityDetails") != null and node("ClubFacilityTraining") != null, "Installations en tableau")
	check(node("ClubCashLink") != null or app.navigation_controller == null, "Lien trésorerie")
	check(windows().is_empty(), "Aucune fenêtre ouverte sur la vue d'ensemble")
	var seul_plein := 0
	for bouton in node("ClubOverview").find_children("*", "Button", true, false):
		if bouton.find_child("FondIvoire", false, false) != null: seul_plein += 1
	check(seul_plein <= 1, "Au plus un bouton ivoire plein sur la vue d'ensemble (%d)" % seul_plein)

func colors() -> void:
	var page := node("ImmersiveClub")
	var dores := 0
	for control in page.find_children("*", "Control", true, false):
		if gold_on(control as Control):
			dores += 1
			printerr("OR sur ", control.get_path())
	check(dores == 0, "Aucune couleur or dans l'écran Club (%d)" % dores)

## Chaque ligne, lien ou tuile de la vue d'ensemble agit : change d'écran, d'onglet ou de sous-page, sans fenêtre.
func links() -> void:
	var cibles := ["ClubStadium", "ClubFacilityTraining", "ClubFacilityMedical", "ClubFacilityAcademy", "ClubFacilityStadium", "ClubFacilityDetails", "ClubBoardGoals", "ClubLockerAction", "ClubMorale", "ClubAvailable", "ClubObjectiveRow0", "ClubTrustRow0", "ClubTrustAll", "ClubFixMilestone", "ClubQuoteLink", "ClubBoardRequest"]
	for id: String in cibles:
		await overview()
		var bouton := node(id) as Button
		if bouton == null: continue
		check(not bouton.disabled, "%s : actif" % id)
		var avant := "%s|%s|%s" % [app.route, str(app.management_ui.get(app.Immersive.ClubCanvas.KEY, "")), str(app.management_ui.get("immersive08_strategy_tab", ""))]
		var historique := int(app.navigation_controller.history.size()) if app.navigation_controller != null and "history" in app.navigation_controller else 0
		bouton.pressed.emit()
		await settle(10)
		var apres := "%s|%s|%s" % [app.route, str(app.management_ui.get(app.Immersive.ClubCanvas.KEY, "")), str(app.management_ui.get("immersive08_strategy_tab", ""))]
		var change: bool = avant != apres or app.route != "Club" or (app.navigation_controller != null and "history" in app.navigation_controller and int(app.navigation_controller.history.size()) != historique)
		check(change, "%s : mène quelque part (%s -> %s)" % [id, avant, apres])
		check(windows().is_empty(), "%s : aucune fenêtre ouverte" % id)
	await overview()

## Noms de joueurs : survol = mini-fiche, clic = fiche complète.
func names() -> void:
	var noms: Array = app.root_content.find_children("Club*Link", "Button", true, false).filter(func(b: Node): return str(b.name) == "ClubLeaderLink")
	noms.append_array(app.root_content.find_children("ClubAbsentName*", "Button", true, false))
	if noms.is_empty():
		check(node("ClubAbsentNone") != null, "Aucun absent : le dit")
		return
	var lien := noms[0] as Button
	lien.mouse_entered.emit()
	await settle(4)
	check(app.get_node_or_null("MiniFicheJoueur") != null, "Survol du nom : mini-fiche")
	lien.mouse_exited.emit()
	await settle(3)
	check(app.get_node_or_null("MiniFicheJoueur") == null, "La souris part : la mini-fiche disparaît")
	lien.pressed.emit()
	await settle(10)
	check(app.route == "Effectif", "Clic sur le nom : fiche joueur complète (%s)" % app.route)
	check(windows().is_empty(), "La fiche s'ouvre en écran")
	await overview()

## Chaque onglet s'affiche sans fenêtre ni or.
func tabs() -> void:
	for cle in ["infrastructure", "history", "direction", "staff", "overview"]:
		var onglet := node("ClubTab_" + cle) as Button
		check(onglet != null, "Onglet " + cle + " cliquable")
		if onglet == null: continue
		onglet.pressed.emit()
		await settle(12)
		check(node("ClubTab_" + cle) != null and node("ClubTab_" + cle).button_pressed, "Onglet " + cle + " choisi")
		check(windows().is_empty(), "Onglet " + cle + " : aucune fenêtre")
		var dores := 0
		for control in node("ImmersiveClub").find_children("*", "Control", true, false):
			if gold_on(control as Control): dores += 1
		check(dores == 0, "Onglet " + cle + " : aucune couleur or (%d)" % dores)
	await overview()

## Une confirmation d'argent s'ouvre dans la page (bloc), jamais en fenêtre ; Annuler la ferme sans rien envoyer.
func confirmation_en_place() -> void:
	var commandes := int(app.bridge._next_id)
	app.confirm("Investir", "Une dépense de test.", func(): app._command("noop", {}))
	await settle(6)
	check(node("ClubConfirmation") != null and node("ClubConfirmationOk") != null, "Confirmation : bloc en place avec « Confirmer »")
	check(windows().is_empty(), "La confirmation n'ouvre aucune fenêtre")
	check(int(app.bridge._next_id) == commandes, "Rien n'est envoyé avant la confirmation")
	var non := node("ClubConfirmationAnnuler") as Button
	if non != null: non.pressed.emit()
	await settle(4)
	check(node("ClubConfirmation") == null, "Annuler referme la confirmation")
	check(int(app.bridge._next_id) == commandes, "Annuler n'envoie rien")

## Contrat, mentorat, engagements : sous-pages du Staff, retour, Échap, jamais de fenêtre.
func staff_pages() -> void:
	app._navigate("Staff")
	await settle(10)
	for page in ["engagements", "mentorat", "mentor", "contrat"]:
		Pages.ouvrir(app, page, {"staff_id": "inconnu", "renew": false})
		await settle(10)
		check(Pages.actuelle(app) == page, "Sous-page %s ouverte" % page)
		check(windows().is_empty(), "Sous-page %s : aucune fenêtre" % page)
		check(node("ClubSubpageTitle") != null and node("ClubRetour") != null and node("ClubSubpageScroll") != null, "Sous-page %s : titre, retour et contenu" % page)
		var retour := node("ClubRetour") as Button
		if retour != null: retour.pressed.emit()
		await settle(10)
		check(Pages.actuelle(app) != page or page == "mentor", "Retour de %s" % page)
	check(Pages.actuelle(app) in ["", "mentorat"], "Retour : le staff ou le mentorat")
	app.management_ui.erase("club_page")
	app._navigate("Staff")
	await settle(8)
	check(Pages.actuelle(app).is_empty() and node("ClubRetour") == null, "Staff : plus de sous-page")
