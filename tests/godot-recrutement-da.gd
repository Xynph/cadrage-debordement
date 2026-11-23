extends SceneTree
## Recrutement, direction artistique « Besoins en tête » + « Ce que coûte l'offre » (choix de Léo du 19/11/2026), Godot réel +
## worker réel, carrière Monde :
## - plus de fiche fixe à droite : le tableau prend la largeur ; clic sur un nom = fiche complète, survol = mini-fiche ;
## - aucune couleur or dans l'écran (l'or est réservé à Continuer, dans la coque) ;
## - le bloc « Ce que coûte l'offre » suit la piste choisie et porte la seule action principale (OfferRecruitment) ;
## - relève, marché entre clubs, offres reçues, missions et offre au joueur sont des sous-pages (retour + Échap), jamais des fenêtres ;
## - tout ce qui ressemble à un lien ou à un bouton de l'écran change d'écran ou agit : aucune petite fenêtre ouverte.
## Imprime une ligne RECRUTEMENT_DA {checks, failures}. Captures (rendu graphique) : CD_RECRUTEMENT_DA_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const G = preload("res://ui/game_skin.gd")
const Salary = preload("res://ui/salary_display.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_RECRUTEMENT_DA_CAPTURES")

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
	var etat: Variant = app.management_ui.get("recrutement_page")
	return str(etat.get("kind", "")) if etat is Dictionary else ""

func press(name: String) -> bool:
	var bouton := node(name) as Button
	if bouton == null or bouton.disabled: return false
	bouton.pressed.emit()
	await settle(10)
	return true

func back_to_list() -> void:
	var retour := node("RecrutementRetour") as Button
	check(retour != null, "Sous-page : lien « Retour au recrutement »")
	if retour != null: retour.pressed.emit()
	await settle(8)
	check(page_kind().is_empty() and node("MarketScroll") != null, "Retour : la liste du recrutement revient")

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
	app._navigate("Recrutement", false)
	await settle(10)
	await layout()
	await bas_du_tableau()
	await tuiles_cliquables()
	await names_open_sheets()
	await colors()
	await needs_and_sort()
	await listes()
	await subpages()
	await recherche_ciblee()
	await dossier_page()
	await observation_confirmation()
	await offer_page()
	shot("recrutement-1920x1080")
	finish()

func finish() -> void:
	print("RECRUTEMENT_DA ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Fin de défilement : la dernière ligne est entièrement visible, à l'écart des coins arrondis du panneau.
func bas_du_tableau() -> void:
	var defile := node("MarketScroll") as ScrollContainer
	var panneau := node("ImmersiveMarketTable") as Control
	check(defile != null and panneau != null, "Tableau défilant présent")
	if defile == null or panneau == null: return
	await settle(30)
	defile.scroll_vertical = int(defile.get_v_scroll_bar().max_value)
	await settle(6)
	var lignes: Array[Control] = []
	for enfant in node("ImmersiveMarketRows").get_children():
		if enfant is Control and str(enfant.name).begins_with("MarketPlayer_"): lignes.append(enfant)
	check(not lignes.is_empty(), "Le tableau a des lignes")
	if lignes.is_empty(): return
	lignes.sort_custom(func(a: Control, b: Control) -> bool: return a.global_position.y < b.global_position.y)
	var derniere: Rect2 = (lignes.back() as Control).get_global_rect()
	var fenetre := defile.get_global_rect()
	check(derniere.end.y <= fenetre.end.y + .5 and derniere.position.y >= fenetre.position.y - .5, "Fin de défilement : la dernière ligne est entièrement visible (%s dans %s)" % [derniere, fenetre])
	check(panneau.get_global_rect().end.y - derniere.end.y >= 13.0, "Fin de défilement : la dernière ligne reste loin des coins arrondis du panneau (%d px)" % roundi(panneau.get_global_rect().end.y - derniere.end.y))
	defile.scroll_vertical = 0
	await settle(4)

## Mise en page : plus de panneau fixe, tableau pleine largeur, budget, besoins, coût de l'offre.
func layout() -> void:
	check(node("CarnetMarket") != null, "Écran Recrutement ouvert")
	check(node("RecruitmentProfile") == null and node("RecruitmentProfilePanel") == null, "Plus de fiche fixe à droite")
	var table := node("ImmersiveMarketTable") as Control
	check(table != null and table.size.x >= app.root_content.size.x * .6, "Le tableau prend toute la largeur")
	check(node("MarketScroll") != null and node("MarketSort_Niveau") != null and node("MarketSort_Nom") != null, "Tableau triable")
	check(node("MarketNeed_0") != null, "Besoin n° 1 en tête, cliquable")
	# L'écran arrive filtré sur le poste du besoin n° 1. Depuis le barème V3 des notes, le besoin n° 1 du club 102 est
	# un poste sans aucune piste sur le marché (demi d'ouverture, alors que les pistes initiales sont des premières
	# lignes) : l'écran le dit et propose « Voir tout le marché », que le manager suit ici comme en jeu.
	if app.root_content.find_children("MarketPlayer_*", "Button", true, false).is_empty() and not (app.model.get("market", []) as Array).is_empty():
		var tout := node("MarketShowAll") as Button
		check(tout != null, "Besoin n° 1 sans piste : lien « Voir tout le marché »")
		if tout != null:
			tout.pressed.emit()
			await settle(10)
	check(node("RecruitmentCost") != null and node("OfferRecruitment") != null, "Bloc « Ce que coûte l'offre » et action principale")
	check(node("RecruitmentTransferBudget") != null, "Budget de transferts visible")
	var lignes: Array = app.root_content.find_children("MarketPlayer_*", "Button", true, false)
	check(not lignes.is_empty(), "Des pistes sont listées")
	if lignes.size() >= 2:
		var suivante := lignes[1] as Button
		var avant := str(app.management_ui.market.get("player_id", ""))
		var id_attendu := str(suivante.get_meta("player_id"))
		var nom_attendu := str(suivante.accessibility_name).split(",")[0].to_lower()
		suivante.pressed.emit()
		await settle(8)
		check(str(app.management_ui.market.get("player_id", "")) == id_attendu, "Clic sur une ligne : la piste choisie change")
		check(avant != str(app.management_ui.market.get("player_id", "")), "La sélection a bougé")
		var nom := node("RecruitmentCostName") as Label
		check(nom != null and nom.text.to_lower().contains(nom_attendu), "Le bloc de coût suit la piste choisie")
	check(windows().is_empty(), "Aucune fenêtre ouverte sur la liste")

## Chaque tuile et pastille de l'écran mène à l'écran pertinent (jamais de fenêtre) : on clique, on vérifie l'arrivée.
## Élément → destination : budget (alloué, engagé, restant) → Finances › Transferts ; « N pistes » du bandeau → liste filtrée
## sur le poste ; « N suivie » → onglet Joueurs suivis ; « N fin » → Effectif trié par échéance ; pastille du marché →
## onglet Recherche ; salaire et durée → offre au joueur ; masse salariale → Finances › Salaires ; observation → confirmation.
func tuiles_cliquables() -> void:
	app._navigate("Recrutement", false)
	await settle(10)
	for budget in ["RecruitmentTransferBudget", "RecruitmentBudgetAllocated", "RecruitmentBudgetSpent"]:
		var tuile := node(budget) as Button
		if tuile == null: continue
		tuile.pressed.emit()
		await settle(10)
		check(app.route == "Finances" and str(app.management_ui.get("immersive08_finance_tab", "")) == "transfers", "Tuile budget « %s » → Finances › Transferts (%s)" % [budget, app.route])
		app._navigate("Recrutement", false)
		await settle(10)
	var pastille := node("RecruitmentWindowLien") as Button
	if pastille != null:
		app.management_ui.market.immersive_tab = 0
		pastille.pressed.emit()
		await settle(8)
		check(int(app.management_ui.market.get("immersive_tab", -1)) == 1, "Pastille du marché → onglet Recherche")
		app.management_ui.market.immersive_tab = 0
		app._navigate("Recrutement", false)
		await settle(8)
	for nom in ["MarketNeedFollowed_0", "MarketNeedFollowed_1", "MarketNeedFollowed_2"]:
		var suivie := node(nom + "Lien") as Button
		if suivie == null: continue
		suivie.pressed.emit()
		await settle(8)
		check(int(app.management_ui.market.get("immersive_tab", -1)) == 2, "Pastille « suivie » (%s) → Joueurs suivis" % nom)
		app.management_ui.market.immersive_tab = 0
		app.management_ui.market.followed = false
		app._navigate("Recrutement", false)
		await settle(8)
		break
	for nom in ["MarketPriorityStock", "MarketNeedStock_1", "MarketNeedStock_2"]:
		var pistes := node(nom + "Lien") as Button
		if pistes == null: continue
		pistes.pressed.emit()
		await settle(8)
		check(windows().is_empty() and node("CarnetMarket") != null, "Pastille « pistes » (%s) → liste du poste, sans fenêtre" % nom)
		app._navigate("Recrutement", false)
		await settle(8)
		break
	# Bloc de coût : salaire et durée → offre ; masse salariale → Finances › Salaires.
	var salaire := node("RecruitmentCostSalaryLien") as Button
	if salaire != null:
		salaire.pressed.emit()
		await settle(10)
		check(node("RecrutementSubpage_negociation") != null or app.find_child("RecrutementSubpage_negociation", true, false) != null, "Tuile salaire → offre au joueur (sous-page)")
		app._navigate("Recrutement", false)
		await settle(10)
	var masse := node("RecruitmentCostPayrollLien") as Button
	if masse != null:
		masse.pressed.emit()
		await settle(10)
		check(app.route == "Finances" and str(app.management_ui.get("immersive08_finance_tab", "")) == "wages", "Tuile masse salariale → Finances › Salaires (%s)" % app.route)
		app._navigate("Recrutement", false)
		await settle(10)
	check(windows().is_empty(), "Aucune fenêtre ouverte par les tuiles et pastilles")

## Clic sur le nom = fiche complète ; survol = carte joueur ; jamais de fenêtre.
func names_open_sheets() -> void:
	var noms: Array = app.root_content.find_children("MarketEntity_*", "Button", true, false)
	check(not noms.is_empty(), "Chaque nom de piste est un lien")
	if noms.is_empty(): return
	var lien := noms[0] as Button
	var carte = load("res://ui/carte_joueur_survol.gd")
	check(lien.has_meta("carte_joueur") and carte.montrer(app, str(lien.get_meta("carte_joueur")), "market", lien) != null, "Survol du nom : carte joueur")
	carte.cacher(app)
	await settle(3)
	check(carte.actuelle(app) == null, "La souris part : la carte disparaît")
	var infos: Array = app.root_content.find_children("CarteJoueurInfo_*", "Control", true, false)
	check(not infos.is_empty(), "Un « i » suit chaque nom")
	lien.pressed.emit()
	await settle(10)
	check(app.management_ui.get("fiche_joueur") is Dictionary, "Clic sur le nom : fiche complète de la piste")
	check(windows().is_empty(), "La fiche s'ouvre en écran, pas en fenêtre")
	var retour := app.root_content.find_child("PlayerBackToSquad", true, false) as Button
	if retour != null: retour.pressed.emit()
	else: app.management_ui.erase("fiche_joueur"); app._navigate("Recrutement", false)
	await settle(10)
	check(node("CarnetMarket") != null and node("MarketScroll") != null, "Retour de la fiche : la liste du recrutement")

## Aucun or (réservé à Continuer, dans la coque) dans l'écran ; chaque bouton est nommé et actif ou grisé avec sa raison.
func colors() -> void:
	var page := node("CarnetMarket")
	var dores := 0
	for control in page.find_children("*", "Control", true, false):
		if gold_on(control as Control):
			dores += 1
			printerr("OR sur ", control.get_path())
	check(dores == 0, "Aucune couleur or dans l'écran Recrutement (%d)" % dores)

## Les accès longs sont des sous-pages : retour, Échap, jamais de fenêtre.
func subpages() -> void:
	for acces in [["OpenRegenScouting", "releve"], ["OpenInterclubMarket", "interclub"], ["OpenPlayerSales", "offres"], ["OpenScoutMission", "missions"]]:
		var ouvert := await press(str(acces[0]))
		check(ouvert, "Accès « %s » cliquable" % acces[0])
		if not ouvert: continue
		check(page_kind() == str(acces[1]), "« %s » ouvre la sous-page %s" % [acces[0], acces[1]])
		check(windows().is_empty(), "« %s » : aucune fenêtre ouverte" % acces[0])
		check(node("RecrutementSubpageTitle") != null and node("RecrutementAdopte") != null and node("RecrutementAdopte").get_child_count() > 0, "« %s » : contenu dans la page" % acces[1])
		# Le lien de retour est aussi la cible d'Échap (raccourcis_clavier.gd).
		await back_to_list()

## Recherche ciblée (idée FM27 n° 26, option B) : une page en petite fenêtre ; liste = joueurs déjà observés seulement ;
## chaque clic s'applique ; « Envoyer le recruteur · 5 000 € » débite et lance la recherche (pastille « en cours »).
func recherche_ciblee() -> void:
	app._navigate("Recrutement", false)
	await settle(10)
	var ouvert := await press("RechercheCibleeOuvrir")
	check(ouvert, "Lien « Recherche ciblée » cliquable")
	var fenetre := app.find_child("RechercheCibleeFenetre", true, false)
	check(fenetre != null, "Recherche ciblée : petite fenêtre ouverte")
	if fenetre == null: return
	var donnees: Dictionary = app.model.get("clubLife", {}).get("rechercheCiblee", {})
	var observes := {}
	for x: Dictionary in donnees.get("connus", []):
		check(str(x.get("suivi", "")) in ["observed", "deep"], "Liste : joueur observé seulement")
		observes[str(x.id)] = true
	var lignes: Array = fenetre.find_children("RecherchePisteOuvrir_*", "Button", true, false)
	check(lignes.size() <= observes.size(), "Liste : aucune ligne sans joueur observé (%d / %d)" % [lignes.size(), observes.size()])
	check(fenetre.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "?" or l.text.contains("★")).is_empty(), "Ni « ? » ni étoile dans la recherche")
	var bouton := app.find_child("RechercheLancer", true, false) as Button
	check(bouton != null and bouton.disabled, "Envoi impossible tant qu'aucun poste n'est choisi")
	var poste := app.find_child("RecherchePosteChoisir_8", true, false) as Button
	check(poste != null, "Poste cliquable sur le terrain")
	if poste == null: return
	poste.pressed.emit(); await settle(6)
	var etat: Dictionary = app.management_ui.recherche_ciblee
	check(int(etat.poste) == 8, "Clic sur un poste : choisi tout de suite")
	var role := app.find_child("RechercheRoleChoisir_1", true, false) as Button
	check(role != null, "Rôles du poste en pastilles")
	if role != null: role.pressed.emit(); await settle(6)
	check(not str(etat.role).is_empty(), "Clic sur un rôle : appliqué tout de suite")
	var prio := app.find_child("RecherchePrioriteChoisir_prioritaire", true, false) as Button
	if prio != null: prio.pressed.emit(); await settle(6)
	check(str(etat.priorite) == "prioritaire", "Clic sur une priorité : appliquée tout de suite")
	await command("export")
	var avant: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var caisse := float(avant.clubs[int(avant.club)].cash)
	bouton = app.find_child("RechercheLancer", true, false) as Button
	check(bouton != null and not bouton.disabled and bouton.text.contains("5 000"), "Envoyer le recruteur · 5 000 € (%s · %s)" % [bouton.text if bouton != null else "absent", JSON.stringify(app.model.get("clubLife", {}).get("rechercheCiblee", {}).get("disponible"))])
	if bouton == null or bouton.disabled: return
	bouton.pressed.emit()
	await wait_engine()
	await command("export")
	var apres: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	check(is_equal_approx(caisse - float(apres.clubs[int(apres.club)].cash), 5000.0), "5 000 € débités à l'envoi")
	var mission: Dictionary = (apres.manager.missions as Array).back()
	check(mission.get("cible") is Dictionary and int(mission.cible.position) == 12 and str(mission.cible.priority) == "prioritaire" and str(mission.cible.role) == str(etat.role), "Critères envoyés au moteur (poste, rôle, priorité)")
	check(app.find_child("RechercheCibleeFenetre", true, false) != null, "Recherche restée ouverte après l'envoi")
	check(app.find_child("RechercheEnCours_0", true, false) != null, "Recherche en cours affichée")
	load("res://ui/immersive08/fenetre_visuelle.gd").fermer(app, "RechercheCibleeFenetre")
	await settle(6)

## Approcher : l'offre est un écran (valider en ivoire plein, annuler en lien), rien ne s'ouvre en fenêtre.
## Négociation avec l'agent (idée 18, choix A de Léo du 23/11/2026) : rôle promis obligatoire avant le contrat ; la
## signature part en un seul clic (règle du 23/11 : pas de confirmation en place).
func offer_page() -> void:
	var bouton := node("OfferRecruitment") as Button
	check(bouton != null, "Action principale présente")
	if bouton == null or bouton.disabled:
		check(bouton != null and bouton.tooltip_text != "", "Approcher grisé : la raison est écrite")
		return
	bouton.pressed.emit()
	await settle(12)
	check(page_kind() == "negociation", "Approcher ouvre l'écran « Offre au joueur »")
	await offer_pieces()
	check(windows().is_empty(), "L'offre n'ouvre aucune fenêtre")
	check(node("RecrutementPageValider") != null and node("RecrutementPageAnnuler") != null, "Valider et annuler sont ceux de la page")
	shot("recrutement-offre-1920x1080")
	var annuler := node("RecrutementPageAnnuler") as Button
	if annuler != null:
		annuler.pressed.emit()
		await settle(12)
	check(page_kind().is_empty(), "Annuler ferme l'écran d'offre sans rien envoyer")

## Trois colonnes : budgets à gauche, rôle promis puis lignes du contrat au centre, bulles de l'agent à droite ; chaque
## chiffre ou carte ouvre une petite fenêtre visuelle, fermée tour à tour par ✕, Échap et un clic à côté.
func offer_pieces() -> void:
	var PetiteFenetre: Variant = load("res://ui/petite_fenetre.gd")
	for id in ["NegoIdentite", "NegoMasse", "NegoTransferts", "NegoContrat", "NegoAgent", "NegoRoleCarte_titulaire", "NegoRoleCarte_appoint", "NegoLigneSalaire", "NegoLigneDuree", "NegoLignePrime", "NegoBulle_0"]:
		check(node(id) != null, "Négociation : pièce %s affichée" % id)
	check(node("ContractTransferBudget") == null or not node("ContractTransferBudget").is_visible_in_tree(), "Offre au joueur : plus de phrase « Disponible pour les transferts »")
	# Rôle promis obligatoire : contrat fermé, signature grisée.
	await create_timer(.3).timeout
	var signer := node("RecrutementPageValider") as Button
	check(not node("OfferSalary").is_visible_in_tree() and (node("NegoLigneSalaire") as Control).get_meta("etat", "") == "attente", "Sans rôle promis : contrat fermé")
	check(signer != null and signer.disabled, "Sans rôle promis : signature grisée")
	var commandes := int(app.bridge._next_id)
	var promis := ""
	for role in ["rotation", "titulaire", "espoir", "appoint"]:
		var carte := node("NegoRole_" + role) as Button
		if carte != null:
			carte.pressed.emit()
			promis = role
			break
	await settle(3)
	await create_timer(.3).timeout
	check(not promis.is_empty() and node("NegoRoleChoisi") != null, "Un clic promet le rôle (%s)" % promis)
	check(node("OfferSalary").is_visible_in_tree() and node("OfferYears").is_visible_in_tree(), "Rôle promis : champs salaire et durée visibles")
	signer = node("RecrutementPageValider") as Button
	check(signer != null and not signer.disabled and signer.text.to_lower().begins_with("signer"), "Rôle promis : « Signer si accord » en un clic (%s)" % (signer.text if signer != null else "—"))
	var liens := ["OffreEtapeLien", "NegoLigneSalaireLien", "NegoLigneDureeLien", "NegoLignePrimeLien", "NegoMasseLien", "NegoTransfertsLien", "NegoAgentLien", "NegoCoutSaisonLien"]
	var manieres := ["croix", "echap", "a_cote"]
	var vus := 0
	for i in liens.size():
		var lien := node(liens[i]) as Button
		if lien == null:
			# Offre guidée absente (devis sans crans) : pas de tuiles de coût.
			check(liens[i] in ["NegoCoutSaisonLien"], "Négociation : %s cliquable" % liens[i])
			continue
		vus += 1
		lien.pressed.emit()
		await settle(3)
		var calque := node("OffrePetiteFenetre")
		check(calque != null and PetiteFenetre.ouverte(self) == calque, "%s ouvre une petite fenêtre" % liens[i])
		check(windows().is_empty(), "%s : petite fenêtre visuelle, pas de fenêtre système" % liens[i])
		if calque == null: continue
		var maniere: String = manieres[i % manieres.size()]
		match maniere:
			"croix":
				var croix: Button = null
				for b: Node in calque.find_children("*Fermer", "Button", true, false): croix = b
				check(croix != null, "%s : bouton ✕" % liens[i])
				if croix != null: croix.pressed.emit()
			"echap":
				check(PetiteFenetre.fermer_derniere(self), "%s : Échap ferme la petite fenêtre" % liens[i])
			"a_cote":
				var a_cote := calque.find_child("OffrePetiteFenetreACote", true, false) as Button
				check(a_cote != null, "%s : clic à côté possible" % liens[i])
				if a_cote != null: a_cote.pressed.emit()
		await settle(3)
		check(node("OffrePetiteFenetre") == null and PetiteFenetre.ouverte(self) == null, "%s : petite fenêtre fermée (%s)" % [liens[i], maniere])
	check(vus >= 7, "Négociation : au moins sept pièces cliquables (%d)" % vus)
	check(int(app.bridge._next_id) == commandes, "Promettre un rôle et régler l'offre n'envoie aucune commande")
	await offre_guidee()

## Offre guidée (idée 17) dans les lignes du contrat : crans de prime et niveaux de clause, conseil du recruteur entouré,
## conseils posés sur le salaire et la durée ; un clic applique ; rien n'est envoyé avant la signature.
func offre_guidee() -> void:
	var commandes := int(app.bridge._next_id)
	for id in ["NegoLigneClause", "NegoPrimeCran_0", "NegoClause_sans", "NegoClause_basse", "NegoCoutImmediat", "NegoCoutTotal"]:
		check(node(id) != null, "Offre guidée : %s affiché" % id)
	check(node("OffreGuideeCarte") == null and node("OffreRegle") == null, "Ancienne présentation de l'offre retirée")
	var conseils := 0
	for n: Node in app.find_children("Nego*", "Panel", true, false):
		if n.get_meta("conseil", false): conseils += 1
	check(conseils >= 1, "Offre guidée : conseil du recruteur entouré sur la prime ou la clause (%d)" % conseils)
	var montant := node("NegoLignePrimeValeur") as Label
	var avant := montant.text if montant != null else ""
	var cran := node("NegoPrimeCran_1Lien") as Button
	if cran != null:
		cran.pressed.emit()
		await settle(3)
		montant = node("NegoLignePrimeValeur") as Label
		check(montant != null and montant.text != avant, "Prime : un clic sur un cran change la prime (%s → %s)" % [avant, montant.text if montant != null else "—"])
	var basse := node("NegoClause_basseLien") as Button
	check(basse != null, "Clause basse cliquable")
	if basse != null:
		basse.pressed.emit()
		await settle(3)
		var clause := node("NegoLigneClauseValeur") as Label
		check(clause != null and clause.text != "Sans", "Clause : un clic choisit la clause basse (%s)" % (clause.text if clause != null else "—"))
	var salaire := node("OfferSalary") as SpinBox
	var conseil := node("NegoConseilSalaireLien") as Button
	check(conseil != null, "Conseil du recruteur posé sur le salaire")
	if salaire != null and conseil != null:
		var texte := str((node("NegoConseilSalaireTexte") as Label).text)
		conseil.pressed.emit()
		await settle(3)
		check(texte.ends_with(G.salary_amount(Salary.input_weekly(salaire))), "Conseil de salaire : un clic l'applique (%s, %s)" % [texte, G.salary_amount(Salary.input_weekly(salaire))])
	check(int(app.bridge._next_id) == commandes, "Offre guidée : aucun envoi avant la signature")

## Besoins du club : arrive filtré sur le poste du besoin n° 1 ; une carte sans piste propose une mission ; « ★ » trie.
func needs_and_sort() -> void:
	var besoins: Array = app.model.get("decisions", {}).get("recruitment", {}).get("needs", [])
	if not besoins.is_empty():
		var poste := str(besoins[0].get("pos", ""))
		var stock: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == poste).size()
		check(str(app.management_ui.market.get("position", "Tous")) == poste or int(app.management_ui.market.get("immersive_tab", 0)) != 0, "Onglet Besoins : filtré sur le poste du besoin n° 1 (%s)" % poste)
		var carte := node("MarketNeed_0")
		check(carte != null, "Carte du besoin n° 1")
		if stock == 0: check(node("MarketNeedMission_0") != null, "Carte sans piste : lien « Lancer une mission pour ce poste »")
	var etoile := node("MarketSort_Suivi") as Button
	check(etoile != null, "En-tête ★ : bouton de tri")
	if etoile != null:
		etoile.pressed.emit()
		await settle(6)
		check(str(app.management_ui.market.get("sort", "")) == "Suivi", "★ trie les pistes suivies d'abord")

## Listes (choix de Léo du 21/11/2026) : en-tête trié souligné ▲/▼, pastilles de poste, forme récente en cases.
func listes() -> void:
	app._navigate("Recrutement", false)
	await settle(8)
	await press("MarketSort_Niveau")
	var tri := node("MarketSort_Niveau") as Button
	check(str(app.management_ui.market.get("sort", "")) == "Niveau", "Clic sur l'en-tête NIV. : tri par niveau")
	check(tri != null and (tri.text.ends_with(" ▲") or tri.text.ends_with(" ▼")), "En-tête trié : flèche ▲ ou ▼")
	check(tri != null and (tri.get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom > 0, "En-tête trié : souligné")
	# Bandeau des filtres (21/11/2026) : derrière la recherche, les menus et les pastilles de poste, à la largeur du
	# tableau ; la bande des en-têtes du tableau est de la même famille.
	var marche := node("CarnetMarket") as Control
	var bandeau := marche.find_child("BandeauFiltres", false, false) as Panel if marche != null else null
	var tableau := node("ImmersiveMarketTable") as Control
	check(bandeau != null and bandeau.get_index() == 0, "Bandeau des filtres derrière les commandes")
	if bandeau != null and tableau != null:
		check(absf(bandeau.position.x - tableau.position.x) < 1.0 and absf(bandeau.size.x - tableau.size.x) < 1.0, "Bandeau à la largeur du tableau")
		check(bandeau.get_rect().end.y < tableau.position.y, "Bandeau au-dessus du tableau, séparé de la 1re ligne")
		for nom in ["MarketSearch", "MarketPosition", "PostePastille_tous"]:
			var c := node(nom) as Control
			check(c != null and bandeau.get_global_rect().encloses(c.get_global_rect()), "%s dans le bandeau" % nom)
		var entete := node("MarketHeader") as Panel
		check(entete != null and (entete.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Charte.BANDEAU_ENTETE, "En-têtes : bande de la famille du bandeau")
	# « Entre clubs » : forme compacte du moteur ([note × 10, semaine, adversaire, pour, contre]) → cases de forme.
	var forme: Dictionary = load("res://ui/interclub_market_view.gd").forme_recente({"forme": [[65], [72, 3, 7, 24, 10]]}, {7: "Rivaux"})
	check(forme.get("matchs", []).size() == 2 and is_equal_approx(float(forme.matchs[0].note), 6.5) and str(forme.matchs[1].adversaire) == "Rivaux" and int(forme.matchs[1].scorePour) == 24, "Entre clubs : forme compacte lue")
	check(load("res://ui/interclub_market_view.gd").forme_recente({}, {}).is_empty(), "Entre clubs : pas de forme sans match noté")
	check(node("PostePastille_tous") is Button, "Pastille Tous postes")
	await press("PostePastille_deuxieme")
	var lignes: Array = app.root_content.find_children("MarketPlayer_*", "Button", true, false)
	var hors: Array = lignes.filter(func(r: Node): return Listes.groupe_de(app.model.market.filter(func(p: Dictionary): return str(p.id) == str(r.get_meta("player_id")))[0]) != "deuxieme")
	check(hors.is_empty(), "Pastille 2e ligne : que des deuxième ligne (%d lignes)" % lignes.size())
	await press("PostePastille_tous")
	app.management_ui.market.position = "Tous"
	app.management_ui.market.search = ""
	app._navigate("Recrutement", false)
	await settle(8)
	lignes = app.root_content.find_children("MarketPlayer_*", "Button", true, false)
	check(not lignes.is_empty(), "Liste du marché")
	if lignes.is_empty(): return
	var id := str(lignes[0].get_meta("player_id"))
	var matchs := []
	for k in 5: matchs.append({"note": 5.0 + k, "semaine": k, "adversaire": "Rivaux %d" % k, "adversaireId": 1, "scorePour": 10, "scoreContre": 15 + k})
	for p: Dictionary in app.model.market:
		if str(p.id) == id: p["formeRecente"] = {"forme": [5.0, 6.0, 7.0, 8.0, 9.0], "matchs": matchs}
	app._navigate("Recrutement", false)
	await settle(10)
	var ligne := node("MarketPlayer_" + id.replace(":", "_"))
	var case_ := ligne.find_child("FormeMatch4", true, false) as Button if ligne != null else null
	check(case_ != null, "Recrutement : cinq cases de forme pour une piste qui a joué")
	if case_ == null: return
	check(case_.tooltip_text.contains("Rivaux 4"), "Survol d'une case : adversaire")
	case_.pressed.emit()
	await settle(8)
	var score := node("FormeMatchScore") as Label
	check(node("FormeMatchFenetre") != null and score != null and score.text == "10 – 19", "Clic sur une case : petite fenêtre du match avec le score")
	var echap := InputEventKey.new()
	echap.keycode = KEY_ESCAPE
	for down in [true, false]:
		echap.pressed = down
		Input.parse_input_event(echap)
		await process_frame
	await settle(8)
	check(node("FormeMatchFenetre") == null and app.route == "Recrutement", "Échap ferme la petite fenêtre du match")
	for p: Dictionary in app.model.market: p.erase("formeRecente")
	app._navigate("Recrutement", false)
	await settle(8)

## Dossier : sous-page (retour au catalogue, Échap), jamais une fenêtre.
func dossier_page() -> void:
	await press("OpenRegenScouting")
	var ouverture: Array = app.find_children("*", "Button", true, false).filter(func(b: Node): return b.has_meta("entity_kind") and str(b.get_meta("entity_kind")) == "prospect" and not (b as Button).disabled)
	if ouverture.is_empty():
		await back_to_list()
		return
	(ouverture[0] as Button).pressed.emit()
	await settle(10)
	check(page_kind() == "dossier", "Nom d'une piste du catalogue : sous-page Dossier")
	check(windows().is_empty(), "Le dossier n'ouvre aucune fenêtre")
	check(node("ProspectProfileTabs") != null and node("RecrutementRetour") != null, "Dossier : onglets et retour au catalogue")
	var retour := node("RecrutementRetour") as Button
	if retour != null: retour.pressed.emit()
	await settle(10)
	check(page_kind() == "releve", "Retour du dossier : la relève")
	await back_to_list()

## Observation payante : « Observer → » ouvre une confirmation EN PLACE (5 000 €), rien ne part avant « Lancer l'observation ».
func observation_confirmation() -> void:
	var lien := node("ObserveRecruitment") as Button
	if lien == null or lien.disabled: return
	var commandes := int(app.bridge._next_id)
	lien.pressed.emit()
	await settle(6)
	check(node("ObservationConfirmation") != null and node("ObservationConfirmationOk") != null, "Observer : confirmation en place")
	check(int(app.bridge._next_id) == commandes and windows().is_empty(), "Observer : aucune commande ni fenêtre avant confirmation")
	var non := node("ObservationConfirmationAnnuler") as Button
	if non != null: non.pressed.emit()
	await settle(4)
	check(node("ObservationConfirmation") == null, "Annuler referme la confirmation d'observation")
