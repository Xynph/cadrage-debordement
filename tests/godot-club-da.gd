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
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
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

## avec_focus = false : l'anneau de focus doré des pilules de la charte (C.style_bouton_contour, C.button) est permis ;
## seuls comptent alors les états affichés sans clavier (repos, survol, appui, grisé, panneau).
func gold_on(control: Control, avec_focus := true) -> bool:
	var tones: Array[Color] = []
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if key == "font_focus_color" and not avec_focus: continue
		if control.has_theme_color_override(key): tones.append(control.get_theme_color(key))
	for key in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if key == "focus" and not avec_focus: continue
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
	await conseil_lettre()
	await conseil_jeu()
	await names()
	await tabs()
	await confirmation_en_place()
	await staff_pages()
	await staff_tab()
	await staff_services()
	await overview()
	shot("club-1920x1080")
	root.size = Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await staff_open()
	check(node("CarnetStaff") != null and windows().is_empty(), "Staff à 1280 × 720 : tableau, aucune fenêtre")
	shot("club-staff-1280x720")
	finish()

func staff_open() -> void:
	app.management_ui.erase("club_page")
	# Tableau habituel (« Tout le staff ») ; la vue par service a sa propre suite (staff_services).
	app.management_ui["staff_services_vue"] = "tous"
	app.StaffViews.reading(app).navigation_id = ""
	app._navigate("Staff")
	await settle(12)

## Onglet Staff (DA du 20/11/2026) : tableau dense sans cadre ni numéro, un seul ivoire plein, noms et lignes vers la fiche,
## lignes de gauche vers une page, départ confirmé EN PLACE.
func staff_tab() -> void:
	await staff_open()
	for id in ["CarnetStaff", "StaffTableHead", "StaffList", "ClubStaffPeople", "ClubStaffDiagnostic", "ClubStaffContracts", "ClubStaffTable"]:
		check(node(id) != null, "Staff : " + id)
	var page := node("ImmersiveClub")
	var numeros := 0
	var cadres := 0
	var pleins := 0
	for control in page.find_children("*", "Control", true, false):
		if control is Label and str(control.text).strip_edges() in ["09", "10"]: numeros += 1
		# Nœuds internes du moteur (focus d'un défilement, liste d'un menu déroulant fermé) : hors de la page.
		if str(control.name).begins_with("_") or (control as Control).get_window() != page.get_window(): continue
		# Charte finale : un seul aplat doré par écran, Continuer (dans la coque) ; aucun dans l'onglet.
		if control is Button and (control as Control).has_theme_stylebox_override("normal"):
			var fond := (control as Control).get_theme_stylebox("normal") as StyleBoxFlat
			if fond != null and fond.bg_color.a > .5 and (close(fond.bg_color, Charte.OR) or close(fond.bg_color, Charte.OR_VIF)): pleins += 1
		# Panneaux sans bordure (boutons secondaires et champs gardent leur contour fin, permis par la charte).
		if not (control is Panel or control is PanelContainer): continue
		for etat in ["panel"]:
			if not (control as Control).has_theme_stylebox_override(etat): continue
			var boite := (control as Control).get_theme_stylebox(etat) as StyleBoxFlat
			if boite != null and boite.border_width_left > 0 and boite.border_width_top > 0 and boite.border_width_right > 0 and boite.border_width_bottom > 0 and boite.border_color.a > .05:
				cadres += 1
				printerr("CADRE sur ", control.get_path())
	check(numeros == 0, "Staff : plus de numéros de chapitre (%d)" % numeros)
	check(cadres == 0, "Staff : panneaux sans bordure (%d)" % cadres)
	check(pleins == 0, "Staff : aucun aplat doré dans l'onglet, Continuer reste seul (%d)" % pleins)
	for id in ["ClubStaffPeople", "ClubStaffTable"]:
		var style := node(id).get_theme_stylebox("panel") as StyleBoxFlat if node(id) != null else null
		check(style != null and style.corner_radius_top_left >= 12, "Staff : panneau %s arrondi" % id)
	check(windows().is_empty(), "Staff : aucune fenêtre")
	shot("club-staff-1920x1080")
	# Nom dans le tableau, ligne du tableau, nom à gauche : la fiche du membre, puis retour à l'annuaire.
	for motif in ["StaffOpenName_*", "StaffRow_*", "ClubStaffName_*"]:
		await staff_open()
		var cibles: Array = app.root_content.find_children(motif, "Button", true, false)
		check(not cibles.is_empty(), "Staff : élément cliquable " + motif)
		if cibles.is_empty(): continue
		(cibles[0] as Button).pressed.emit()
		await settle(10)
		check(node("StaffProfile") != null and node("StaffProfileName") != null, "Staff : %s ouvre la fiche du membre" % motif)
		check(windows().is_empty(), "Staff : la fiche s'ouvre sans fenêtre (%s)" % motif)
		if motif == "StaffOpenName_*": shot("club-staff-fiche-1920x1080")
		var retour := node("StaffProfileDirectory") as Button
		check(retour != null, "Fiche du staff : retour à l'annuaire")
		if retour != null: retour.pressed.emit()
		await settle(8)
		check(node("StaffProfile") == null and node("StaffTableHead") != null, "Retour à l'annuaire du staff (%s)" % motif)
	# Lignes de la colonne de gauche : chacune mène quelque part (tableau, sous-page ou travail du club).
	for id in ["ClubStaffCount", "ClubStaffContractsEnding", "ClubStaffCandidates", "ClubStaffMentoring", "ClubStaffBudget", "ClubStaffDiagnosticRow0", "ClubStaffWork"]:
		await staff_open()
		var bouton := node(id) as Button
		if bouton == null: continue
		var avant := "%s|%s|%s" % [app.route, Pages.actuelle(app), str(app.StaffViews.reading(app).get("tab", 0))]
		bouton.pressed.emit()
		await settle(10)
		var apres := "%s|%s|%s" % [app.route, Pages.actuelle(app), str(app.StaffViews.reading(app).get("tab", 0))]
		check(avant != apres or (id in ["ClubStaffCount", "ClubStaffContractsEnding"] and node("StaffTableHead") != null), "%s : mène quelque part (%s -> %s)" % [id, avant, apres])
		check(windows().is_empty(), "%s : aucune fenêtre" % id)
	# Départ (ou activation des carrières du staff) : confirmation EN PLACE, Annuler n'envoie rien.
	await staff_open()
	var depart := node("StaffRelease") as Button
	if depart == null: depart = node("EnableStaffCareer") as Button
	if depart != null:
		var commandes := int(app.bridge._next_id)
		depart.pressed.emit()
		await settle(6)
		check(node("ClubConfirmation") != null and windows().is_empty(), "Staff : confirmation en place, sans fenêtre (%s)" % depart.name)
		var non := node("ClubConfirmationAnnuler") as Button
		if non != null: non.pressed.emit()
		await settle(4)
		check(int(app.bridge._next_id) == commandes, "Staff : Annuler n'envoie rien")
	app.StaffViews.reading(app).tab = 0

## Staff par service (revue FM27 n° 22, choix A de Léo) : vue par défaut de l'onglet, quatre colonnes du moteur
## (postes occupés / visés, silhouettes, avis des dirigeants), rangée « En plus » réglée d'un clic (− / +) sans
## confirmation, bonus et salaire suivis à l'écran, « Tout le staff » rend le tableau, silhouette = fiche du membre.
func staff_services() -> void:
	app.management_ui.erase("club_page")
	app.management_ui.erase("staff_services_vue")
	app.StaffViews.reading(app).navigation_id = ""
	app._navigate("Staff")
	await settle(12)
	var projection: Dictionary = app.model.get("clubLife", {}).get("staffServices", {})
	check(projection.get("available", false) == true, "Staff par service : projection du moteur")
	check(node("CarnetStaff") == null, "Staff : la vue par service remplace le tableau par défaut")
	for id in ["coaching", "fitness", "medical", "club"]:
		check(node("StaffService_" + id) != null, "Staff par service : colonne " + id)
		check(node("StaffAvis_" + id) != null, "Staff par service : avis des dirigeants " + id)
		check(node("StaffBonus_" + id) != null and node("StaffSalaire_" + id) != null, "Staff par service : bonus et salaire " + id)
		check(node("StaffCible_%s_plus" % id) is Button and node("StaffCible_%s_moins" % id) is Button, "Staff par service : − / + " + id)
	for id in ["StaffAffectations", "StaffResponsabilites", "StaffContratsServices", "StaffSalaireTotal"]: check(node(id) != null, "Staff par service : " + id)
	check(windows().is_empty(), "Staff par service : aucune fenêtre")
	var pleins := 0
	for control in node("ImmersiveClub").find_children("*", "Button", true, false):
		if gold_on(control as Control, false): pleins += 1
	check(pleins == 0, "Staff par service : aucun or au repos (%d)" % pleins)
	# Service avec un membre en surnombre : « + » applique tout de suite (aucune confirmation).
	var choisi := ""
	for s: Dictionary in projection.get("services", []):
		if choisi.is_empty() and not (s.get("surnombre", []) as Array).is_empty(): choisi = str(s.id)
	check(not choisi.is_empty(), "Staff par service : un membre en surnombre au départ")
	if not choisi.is_empty():
		var plus := node("StaffCible_%s_plus" % choisi) as Button
		var compte_avant := (node("StaffServiceCompte_" + choisi) as Label).text
		plus.pressed.emit()
		await wait_engine()
		check(node("ClubConfirmation") == null and windows().is_empty(), "« + » : appliqué sans confirmation")
		var apres: Dictionary = {}
		for s: Dictionary in app.model.get("clubLife", {}).get("staffServices", {}).get("services", []):
			if str(s.id) == choisi: apres = s
		check(int(apres.get("cible", 0)) == 1 and (apres.get("enPlus", []) as Array).size() == 1, "« + » : un poste en plus tenu (%s)" % JSON.stringify(apres.get("cible")))
		var bonus := node("StaffBonus_" + choisi) as Label
		check(bonus != null and (bonus.text.begins_with("+") or bonus.text.begins_with("−")), "Bonus non nul affiché : %s" % (bonus.text if bonus else "?"))
		var salaire := node("StaffSalaire_" + choisi) as Label
		check(salaire != null and salaire.text.begins_with("−"), "Salaire du poste affiché : %s" % (salaire.text if salaire else "?"))
		var compte := node("StaffServiceCompte_" + choisi) as Label
		check(compte != null and compte.text != compte_avant, "Compte occupés / visés suivi : %s → %s" % [compte_avant, compte.text if compte else "?"])
		check(node("StaffEnPlusSilhouette_%s_0" % choisi) != null, "Silhouette du poste en plus")
		shot("club-staff-services-1920x1080")
		var moins := node("StaffCible_%s_moins" % choisi) as Button
		check(moins != null and not moins.disabled, "« − » disponible")
		if moins != null: moins.pressed.emit()
		await wait_engine()
		for s: Dictionary in app.model.get("clubLife", {}).get("staffServices", {}).get("services", []):
			if str(s.id) == choisi: check(int(s.cible) == 0, "« − » : retour au minimum")
		check((node("StaffCible_%s_moins" % choisi) as Button).disabled, "« − » grisé au minimum")
	# Silhouette d'un membre : sa fiche.
	var silhouette := node("StaffSilhouette_assistant_0") as Button
	check(silhouette != null, "Silhouette de l'adjoint")
	if silhouette != null:
		silhouette.pressed.emit()
		await settle(10)
		check(node("StaffProfile") != null, "Silhouette : fiche du membre")
		app.StaffViews.reading(app).navigation_id = ""
		app._navigate("Staff")
		await settle(10)
	# Colonne : petite fenêtre visuelle du service.
	var ouvrir := node("StaffServiceOuvrir_medical") as Button
	if ouvrir != null:
		ouvrir.pressed.emit()
		await settle(6)
		check(node("StaffFenetreService") != null, "Petite fenêtre du service médical")
		FenetreVisuelle.fermer(node("ImmersiveClub"), "StaffFenetreService")
		await settle(4)
	# « Tout le staff » : le tableau ; « Par service » : retour.
	(node("StaffVue_tous") as Button).pressed.emit()
	await settle(10)
	check(node("CarnetStaff") != null and node("StaffService_coaching") == null, "« Tout le staff » : tableau habituel")
	(node("StaffVue_services") as Button).pressed.emit()
	await settle(10)
	check(node("StaffService_coaching") != null, "« Par service » : retour aux colonnes")
	app.management_ui["staff_services_vue"] = "tous"

func finish() -> void:
	print("CLUB_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Mise en page : titre, cinq onglets, bandeau, deux colonnes (conseil, installations / à décider, vestiaire).
func layout() -> void:
	check(node("ImmersiveClub") != null and node("ClubOverview") != null, "Écran Club ouvert (vue d'ensemble)")
	check(node("ClubTitle") != null and node("ClubSubtitle") != null, "Titre et sous-titre")
	for cle in ["overview", "jeu", "direction", "infrastructure", "staff", "history"]: check(node("ClubTab_" + cle) != null, "Onglet " + cle)
	check(node("ClubStadium") != null, "Bandeau du club")
	for id in ["ClubCouncil", "ClubFacilities", "ClubDecide", "ClubLocker"]: check(node(id) != null, "Bloc " + id)
	var conseil := node("ClubCouncil")
	var decider := node("ClubDecide")
	check(conseil != null and decider != null and conseil.global_position.x < decider.global_position.x, "Le conseil est à gauche, « À décider » à droite")
	check(node("ClubTrustValue") != null, "Confiance en chiffre")
	check(node("ClubTrustWord") != null or node("ClubLastReview") != null, "Confiance dite en mot (ou premier bilan à venir)")
	check(node("ClubObjectives") != null and node("ClubGoal") != null, "Objectif de la saison")
	check(node("ClubTrustTable") != null, "Bilans du conseil en lignes")
	check(node("ConseilLettre") != null, "Note du conseil en lettre")
	check(node("ClubFacilityDetails") != null and node("ClubFacilityTraining") != null, "Installations en tableau")
	check(node("ClubCashLink") != null or app.navigation_controller == null, "Lien trésorerie")
	check(windows().is_empty(), "Aucune fenêtre ouverte sur la vue d'ensemble")
	# Charte finale : aucun aplat crème hors onglet (Continuer porte l'unique aplat doré) ; l'action de « À décider »
	# est une pilule à contour.
	var aplats := 0
	for bouton in node("ClubOverview").find_children("*", "Button", true, false):
		var fond := (bouton as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if fond != null and close(fond.bg_color, Charte.IVOIRE) and fond.bg_color.a > .5: aplats += 1
	check(aplats == 0, "Aucun bouton en aplat crème sur la vue d'ensemble (%d)" % aplats)
	var ligne_decider := node("ClubDecideRow0")
	if ligne_decider != null:
		var pilules := 0
		for bouton in node("ClubDecide").find_children("*", "Button", true, false):
			var fond := (bouton as Button).get_theme_stylebox("normal") as StyleBoxFlat
			if fond != null and fond.corner_radius_top_left >= 999 and fond.border_width_left > 0: pilules += 1
		check(pilules >= 1, "« À décider » : action principale en pilule à contour")
	for id in ["ClubCouncil", "ClubFacilities", "ClubDecide", "ClubLocker"]:
		var panneau := node(id) as Panel
		var style := panneau.get_theme_stylebox("panel") as StyleBoxFlat if panneau != null else null
		check(style != null and style.corner_radius_top_left >= 8 and style.border_width_left == 0, "Bloc %s : panneau arrondi sans bordure" % id)

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

## Note du conseil en lettre (idée n° 8, option B) : la lettre ouvre sa petite fenêtre (familles A-E, histogramme des
## bilans ; Fermer et Échap la ferment), chaque domaine ouvre son écran, chaque bilan porte une lettre et une flèche par domaine.
func conseil_lettre() -> void:
	const Lettre = preload("res://ui/immersive08/conseil_lettre.gd")
	check(Lettre.lettre(98) == "A+" and Lettre.lettre(62) == "C+" and Lettre.lettre(33) == "D+" and Lettre.lettre(5) == "E", "Barème des lettres")
	check(Lettre.palier(70) == "Solide" and Lettre.palier(69) == "Fragile" and Lettre.palier(39) == "Menacé", "Lettre alignée sur les paliers")
	# Deux bilans du moteur (mêmes champs que finance.boardHistory) pour voir lignes, lettres et flèches.
	var finance: Dictionary = app.model.clubLife.clubStrategy.finance
	var avant: Array = finance.get("boardHistory", [])
	finance.boardHistory = [{"season": 1, "round": 6, "previous": 60, "after": 48, "results": 30, "finances": 90, "youth": 50, "supporters": 72, "jeu": 35, "score": 44}, {"season": 1, "round": 3, "previous": 60, "after": 60, "results": 50, "finances": 70, "youth": 50, "score": 56}]
	await overview()
	check(node("ClubTrustRow0") != null and node("ClubTrustRow1") != null, "Bilans : une ligne par bilan")
	var ligne := node("ClubTrustRow0")
	check(ligne != null and ligne.find_child("Fleche_down", true, false) != null and ligne.find_child("Fleche_up", true, false) != null, "Bilan : flèches ▲ / ▼ par domaine")
	check(node("ConseilDomaine_results") != null and node("ConseilDomaine_results").find_child("Fleche_down", true, false) != null, "Résultats 30 : flèche ▼")
	check(node("ConseilDomaine_supporters") != null and node("ConseilDomaine_supporters").find_child("Fleche_up", true, false) != null, "Supporters 72 : flèche ▲")
	check(node("ConseilDomaine_jeu") != null and node("ConseilDomaine_jeu").find_child("Fleche_down", true, false) != null, "Notre jeu 35 : flèche ▼")
	var cinquieme := node("ConseilDomaine_jeu")
	var conseil := node("ClubCouncil")
	check(cinquieme != null and conseil != null and cinquieme.global_position.y + cinquieme.size.y <= conseil.global_position.y + 306.0 * float(load("res://ui/immersive08/components.gd").density) + 1.0, "Cinq domaines tiennent avant le filet du conseil")
	var lettre := node("ConseilLettre") as Button
	check(lettre != null, "Grande lettre cliquable")
	if lettre != null:
		lettre.pressed.emit()
		await settle(6)
		var fenetre := app.get_node_or_null("ConseilFenetreLettre")
		check(fenetre != null and fenetre.find_child("ConseilHistogramme", true, false) != null, "Lettre : petite fenêtre avec l'histogramme des bilans")
		check(fenetre != null and fenetre.find_child("ConseilFamille_C", true, false) != null, "Lettre : familles A à E")
		shot("conseil-lettre-fenetre-1920x1080")
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			root.size = Vector2i(2560, 1440)
			DisplayServer.window_set_size(root.size)
			await settle(8)
			shot("conseil-lettre-fenetre-2560x1440")
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(root.size)
			await settle(8)
		var fermer := fenetre.find_child("ConseilFenetreLettreFermer", true, false) as Button if fenetre != null else null
		if fermer != null: fermer.pressed.emit()
		await settle(4)
		check(not is_instance_valid(app.get_node_or_null("ConseilFenetreLettre")) or app.get_node_or_null("ConseilFenetreLettre").is_queued_for_deletion(), "Fermer ferme la petite fenêtre")
		lettre = node("ConseilLettre") as Button
		lettre.pressed.emit()
		await settle(4)
		check(load("res://ui/petite_fenetre.gd").fermer_derniere(self), "Échap ferme la petite fenêtre")
		await settle(4)
	for domaine: Array in [["results", "Classements"], ["finances", "Finances"], ["youth", "Centre"], ["supporters", "Stratégie"], ["jeu", "Club"]]:
		await overview()
		var bouton := node("ConseilDomaine_" + str(domaine[0])) as Button
		check(bouton != null, "Domaine %s : ligne" % domaine[0])
		if bouton == null: continue
		bouton.pressed.emit()
		await settle(10)
		check(app.route == str(domaine[1]), "Domaine %s : ouvre %s (%s)" % [domaine[0], domaine[1], app.route])
		if domaine[0] == "jeu": check(node("ConseilJeu") != null and str(app.management_ui.get(app.Immersive.ClubCanvas.KEY, "")) == "jeu", "Domaine jeu : ouvre Club › Notre jeu")
	finance.boardHistory = avant
	await overview()

## Avis du conseil sur notre jeu (idée n° 31, option A) : jeu de données du moteur (même forme que clubLife.conseilJeu),
## 6 familles et 16 chiffres.
func fixture_jeu() -> Dictionary:
	var familles := [["plan", "Plan de jeu", "tactic", ["victoires", "ecart"], 2], ["conquete", "Conquête", "people", ["melee", "touche", "possession"], 1],
		["spectacle", "Spectacle", "star", ["essais", "bonus"], 3], ["attaque", "Attaque", "ball", ["points", "entrees22", "territoire", "buteur"], 3],
		["defense", "Défense", "shield", ["encaisses", "essais_enc", "penalites", "jaunes"], 1], ["formation", "Formation", "school", ["jeunes"], 1]]
	var unites := {"victoires": "%", "melee": "%", "touche": "%", "possession": "%", "bonus": "%", "territoire": "%", "buteur": "%"}
	var noms := {"entrees22": "Entrées dans les 22 m", "jeunes": "Jeunes titulaires (−23 ans)"}
	var indicateurs := {}
	var matchs: Array = []
	for j in 6: matchs.append({"journee": j + 1, "valeurs": {}})
	var fams: Array = []
	var k := 0
	for f: Array in familles:
		for id: String in f[3]:
			var sens := -1 if id in ["encaisses", "essais_enc", "penalites", "jaunes"] else 1
			var nous := 10.0 + k
			indicateurs[id] = {"id": id, "nom": str(noms.get(id, id.capitalize())), "unite": str(unites.get(id, "")), "sens": sens, "nous": nous, "moyenne": nous + (1.5 if k % 2 == 0 else -1.5),
				"rang": 1 + k % 14, "clubs": 14, "note": float(10 + k * 5), "avis": ["up", "down", "neutre"][k % 3], "matchs": 6}
			if id == "entrees22": indicateurs[id]["total"] = 62
			for m: Dictionary in matchs: m.valeurs[id] = nous + float(int(m.journee) % 3) - 1.0
			k += 1
		fams.append({"id": f[0], "nom": f[1], "picto": f[2], "indicateurs": f[3], "note": float(30 + fams.size() * 10), "attente": f[4]})
	return {"available": true, "saison": 1, "courante": true, "competition": "elite", "profil": "spectacle", "identite": "Spectacle", "matchs": matchs, "indicateurs": indicateurs, "familles": fams, "note": 55.0, "dernierBilan": null}

func jeu_ouvert() -> void:
	app.management_ui.erase("club_page")
	app.management_ui[app.Immersive.ClubCanvas.KEY] = "jeu"
	app._navigate("Club")
	await settle(10)

## Onglet Notre jeu : vide avant tout match ; avec les chiffres, bandeau (lettre, humeur, identité), une tête par famille
## avec son attente en crans, une ligne par chiffre, intitulés posés exactement sur leurs chiffres ; lignes, têtes et
## lettre ouvrent leur petite fenêtre (Échap ferme) ; plus de variante B ni de switch.
func conseil_jeu() -> void:
	var source := FileAccess.get_file_as_string("res://ui/immersive08/conseil_jeu.gd")
	check(source.find("CD_VARIANTE_VISUELLE") < 0 and source.find("_option_b") < 0, "Notre jeu : variante B et switch retirés")
	var vie: Dictionary = app.model.get("clubLife", {})
	var avant: Variant = vie.get("conseilJeu")
	await jeu_ouvert()
	check(node("ClubTab_jeu") != null and node("ClubTab_jeu").button_pressed, "Onglet Notre jeu choisi")
	if not (avant is Dictionary and bool(avant.get("available", false))): check(node("ConseilJeuVide") != null, "Notre jeu : avant le premier match, rien à juger")
	vie["conseilJeu"] = fixture_jeu()
	await jeu_ouvert()
	for id in ["ConseilJeuBandeau", "ConseilJeuLettre", "ConseilJeuReaction", "ConseilJeuIdentite", "ConseilJeuMatchs"]: check(node(id) != null, "Notre jeu : " + id)
	var lignes := 0
	var tetes := 0
	for b: Node in node("ConseilJeu").find_children("ConseilJeu*", "Button", true, false):
		if str(b.name).begins_with("ConseilJeuLigne_"): lignes += 1
		elif str(b.name).begins_with("ConseilJeuFamille_"): tetes += 1
	check(tetes == 6 and lignes == 16, "Notre jeu : 6 familles, 16 chiffres (%d, %d)" % [tetes, lignes])
	check(node("ConseilJeuAttente_spectacle") != null and int(node("ConseilJeuAttente_spectacle").get("niveau")) == 3 and int(node("ConseilJeuAttente_conquete").get("niveau")) == 1, "Attentes du conseil en crans par famille")
	var points: Variant = node("ConseilJeuPoints_entrees22")
	check(points != null and (points.get("couleurs") as Array).size() == 6, "Entrées dans les 22 m : un point par match")
	# Intitulés alignés : même bord droit que les chiffres de chaque ligne.
	for col: Array in [["Nous", "ConseilJeuNous"], ["Moyenne", "ConseilJeuMoyenne"], ["Écart", "ConseilJeuEcart"], ["Rang", "ConseilJeuRang"]]:
		var tete := node("ConseilJeuColonne_" + str(col[0])) as Label
		var ok := tete != null and tete.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		for i in 16:
			var ligne := node("ConseilJeuLigne_%d" % i)
			var chiffre := ligne.find_child(str(col[1]), true, false) as Label if ligne != null else null
			if chiffre == null or tete == null: ok = false; continue
			ok = ok and chiffre.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and absf(tete.global_position.x + tete.size.x - chiffre.global_position.x - chiffre.size.x) < 1.5
		check(ok, "Colonne %s : intitulé aligné sur ses chiffres" % col[0])
	var bas := 0.0
	for b: Node in node("ConseilJeu").find_children("ConseilJeuLigne_*", "Button", true, false): bas = maxf(bas, (b as Control).global_position.y + (b as Control).size.y)
	var panneau := node("ConseilJeu")
	check(bas <= panneau.global_position.y + panneau.size.y + 1.0, "Les 16 lignes tiennent dans le panneau")
	var dores := 0
	for control in panneau.find_children("*", "Control", true, false): if gold_on(control as Control, false): dores += 1
	check(dores == 0, "Notre jeu : aucun or (%d)" % dores)
	shot("conseil-jeu-1920x1080")
	# Clic sur la ligne des entrées dans les 22 m : petite fenêtre avec le total de la saison et un bâton par match.
	var ligne22: Button = null
	for b: Node in panneau.find_children("ConseilJeuLigne_*", "Button", true, false): if str(b.get_meta("indicateur", "")) == "entrees22": ligne22 = b
	check(ligne22 != null, "Ligne des entrées dans les 22 m")
	if ligne22 != null:
		ligne22.pressed.emit()
		await settle(6)
		var fenetre := app.get_node_or_null("ConseilJeuFenetre")
		check(fenetre != null and fenetre.find_child("ConseilJeuHistogramme", true, false) != null and fenetre.find_child("ConseilJeuFenetreSaison", true, false) != null, "Entrées dans les 22 m : total de la saison et bâtons par match")
		check(windows().is_empty(), "Petite fenêtre dessinée, pas de fenêtre système")
		shot("conseil-jeu-fenetre-1920x1080")
		check(load("res://ui/petite_fenetre.gd").fermer_derniere(self), "Échap ferme la petite fenêtre")
		await settle(4)
	for id in ["ConseilJeuFamille_attaque", "ConseilJeuLettre"]:
		var bouton := node(id) as Button
		if bouton == null: check(false, id + " absent"); continue
		bouton.pressed.emit()
		await settle(6)
		var fenetre := app.get_node_or_null("ConseilJeuFenetre")
		check(fenetre != null and fenetre.find_child("ConseilJeuFenetreAttente" if id == "ConseilJeuFamille_attaque" else "ConseilJeuFenetreFamille_formation", true, false) != null, id + " : petite fenêtre")
		var fermer := fenetre.find_child("ConseilJeuFenetreFermer", true, false) as Button if fenetre != null else null
		if fermer != null: fermer.pressed.emit()
		await settle(4)
		check(not is_instance_valid(app.get_node_or_null("ConseilJeuFenetre")) or app.get_node_or_null("ConseilJeuFenetre").is_queued_for_deletion(), id + " : Fermer ferme")
	if avant == null: vie.erase("conseilJeu")
	else: vie["conseilJeu"] = avant
	await overview()

## Noms de joueurs : survol = carte joueur (même composant que partout), clic = fiche complète.
func names() -> void:
	var noms: Array = app.root_content.find_children("Club*Link", "Button", true, false).filter(func(b: Node): return str(b.name) == "ClubLeaderLink")
	noms.append_array(app.root_content.find_children("ClubAbsentName*", "Button", true, false))
	if noms.is_empty():
		check(node("ClubAbsentNone") != null, "Aucun absent : le dit")
		return
	var lien := noms[0] as Button
	var Carte = load("res://ui/carte_joueur_survol.gd")
	check(lien.has_meta("carte_joueur") and str(lien.get_meta("carte_joueur")) != "", "Survol du nom : carte joueur branchée")
	check(lien.tooltip_text.is_empty(), "Nom : pas d'info-bulle système par-dessus la carte")
	var carte := Carte.montrer(app, str(lien.get_meta("carte_joueur")), str(lien.get_meta("carte_source", "squad")), lien) as Control
	await settle(4)
	check(carte != null and carte.is_visible_in_tree() and Carte.actuelle(app) == carte, "Survol du nom : la carte joueur apparaît")
	check(carte != null and Rect2(Vector2.ZERO, app.get_viewport_rect().size).encloses(carte.get_global_rect()), "Carte joueur entièrement dans l'écran")
	check(windows().is_empty(), "Survol du nom : aucune fenêtre")
	Carte.cacher(app)
	await settle(3)
	check(Carte.actuelle(app) == null, "La souris part : la carte disparaît")
	lien.pressed.emit()
	await settle(10)
	check(app.route == "Effectif", "Clic sur le nom : fiche joueur complète (%s)" % app.route)
	check(windows().is_empty(), "La fiche s'ouvre en écran")
	await overview()

## Chaque onglet s'affiche sans fenêtre ni or (hors anneau de focus des pilules de la charte).
func tabs() -> void:
	for cle in ["jeu", "infrastructure", "history", "direction", "staff", "overview"]:
		var onglet := node("ClubTab_" + cle) as Button
		check(onglet != null, "Onglet " + cle + " cliquable")
		if onglet == null: continue
		onglet.pressed.emit()
		await settle(12)
		check(node("ClubTab_" + cle) != null and node("ClubTab_" + cle).button_pressed, "Onglet " + cle + " choisi")
		check(windows().is_empty(), "Onglet " + cle + " : aucune fenêtre")
		var dores := 0
		var noms_dores: PackedStringArray = []
		for control in node("ImmersiveClub").find_children("*", "Control", true, false):
			# Staff (charte finale) : le doré est permis pour le focus et l'attention écrite (« ✕ Libérer », « ! ») ;
			# seul un aplat doré est interdit (vérifié par staff_tab). Les autres onglets gardent l'ancienne règle.
			if cle == "staff": continue
			# Charte finale : l'anneau de focus doré des pilules est permis (comme au Staff) ; aucun or au repos.
			if gold_on(control as Control, false):
				dores += 1
				if not noms_dores.has(str(control.name)): noms_dores.append(str(control.name))
		check(dores == 0, "Onglet " + cle + " : aucune couleur or (%d) %s" % [dores, ", ".join(noms_dores.slice(0, 16))])
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
