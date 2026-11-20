extends SceneTree
## Vente de joueurs dans le vrai jeu (profil préparé par tests/godot-vente-joueurs.cjs, vrai moteur), fenêtre 1280×720 :
## Recrutement → « Offres reçues » (bouton OpenPlayerSales), boîte PlayerSales (SalesWindow, SaleOffer_*, SaleAccept,
## SaleAcceptReason, SalePending_*), confirmation SaleConfirmation (libellé = action, focus sur Annuler ; SaleConfirmCash,
## SaleConfirmSquad, SaleConfirmBudget), fiche joueur onglet Contrat (PlayerSalePanel, PlayerSaleStatus, PlayerSaleReason,
## PlayerSaleToggle, PlayerSaleOffers), Effectif (ProfileSaleStatus, ProfileSaleToggle, ProfileSaleOffers) et lien du
## courrier « offre_transfert » (écran « ventes »). Textes ≥ 13 px, aucun chevauchement.
const G = preload("res://ui/carnet_skin.gd")
const ClubMail = preload("res://ui/club_mail.gd")
## Plancher de lisibilité de la nouvelle direction artistique : 12 px réels (brief du 19/11/2026).
const TAILLE_MIN := 12
var app: Control
var sortie := OS.get_environment("CD_VENTE_OUTPUT")
var attendu: Dictionary = {}
var echecs: Array[String] = []
var controles := 0

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func capturer(nom: String) -> void:
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom)) == OK, "capture " + nom)

func noeud(parent: Node, nom: String) -> Node:
	return parent.find_child(nom, true, false) if parent != null else null

func texte(parent: Node, nom: String) -> String:
	var n := noeud(parent, nom)
	if n is Label: return (n as Label).text
	if n is Button: return (n as Button).text
	return ""

func taille(control: Control) -> int:
	return control.get_theme_font_size("font_size")

## Tous les textes visibles d'un sous-arbre font au moins TAILLE_MIN px.
func textes_lisibles(parent: Node, contexte: String) -> void:
	var petits: Array[String] = []
	for n in parent.find_children("*", "Label", true, false) + parent.find_children("*", "Button", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree() or (c is Label and (c as Label).text.is_empty()) or (c is Button and (c as Button).text.is_empty()): continue
		if taille(c) < TAILLE_MIN: petits.append("%s (%d px)" % [c.name, taille(c)])
	verifier(petits.is_empty(), contexte + " : textes sous %d px : %s" % [TAILLE_MIN, ", ".join(petits)])

## Rectangles sans chevauchement deux à deux, tous dans le cadre.
func sans_chevauchement(cadre: Control, noms: Array, contexte: String) -> void:
	var rects: Array = []
	for nom: String in noms:
		var c := noeud(cadre, nom) as Control
		if c == null or not c.is_visible_in_tree(): continue
		var r := c.get_global_rect()
		verifier(cadre.get_global_rect().grow(1.0).encloses(r), "%s : %s dans son cadre (%s ⊂ %s)" % [contexte, nom, str(r), str(cadre.get_global_rect())])
		for autre: Array in rects:
			verifier(not (autre[1] as Rect2).grow(-1.0).intersects(r.grow(-1.0)), "%s : %s ne chevauche pas %s" % [contexte, nom, autre[0]])
		rects.append([nom, r])

func executer() -> void:
	attendu = JSON.parse_string(OS.get_environment("CD_VENTE_ATTENDU"))
	# CD_VENTE_SIZE (« 1920x1080 ») : autre taille de fenêtre pour les captures ; 1280×720 par défaut.
	var demande := OS.get_environment("CD_VENTE_SIZE").split("x")
	root.size = Vector2i(int(demande[0]), int(demande[1])) if demande.size() == 2 and int(demande[0]) > 0 else Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var offre: Dictionary = attendu.offre
	var fauche: Dictionary = attendu.fauche
	var accord: Dictionary = attendu.accord
	var n_offres := int(attendu.offres)
	verifier((app.model.get("sales", {}).get("offers", []) as Array).size() == n_offres, "offres lues par Godot = moteur (%d)" % n_offres)

	# 1. Recrutement : accès « Offres reçues · n ».
	app._navigate("Recrutement"); await poser(20)
	var acces := noeud(app, "OpenPlayerSales") as Button
	verifier(acces != null and acces.is_visible_in_tree(), "bouton « Offres reçues » visible dans Recrutement")
	if acces != null:
		verifier(acces.text.begins_with("Offres reçues · %d" % n_offres), "libellé : « %s »" % acces.text)
		verifier(taille(acces) >= TAILLE_MIN, "bouton Offres reçues lisible (%d px)" % taille(acces))
		var page := noeud(app, "CarnetMarket") as Control
		if page != null: sans_chevauchement(page, ["OpenPlayerSales", "OpenRegenScouting", "OpenInterclubMarket", "MarketTab0", "RecruitmentTransferBudget"], "Recrutement")
	await capturer("vente-recrutement.png")

	# 2. Boîte des offres : période des mutations, offres, raisons écrites, vente en attente.
	if acces != null: acces.pressed.emit()
	await poser(12)
	var boite := noeud(app, "PlayerSales") as AcceptDialog
	verifier(boite != null and not boite.visible and noeud(app, "RecrutementSubpage_offres") != null, "« Offres reçues » : sous-page du Recrutement, aucune fenêtre")
	if boite != null:
		verifier(texte(app, "SalesWindow").contains("Période des mutations") and texte(app, "SalesWindow").contains("1er mai"), "période des mutations écrite : " + texte(app, "SalesWindow"))
		var carte := noeud(app, "SaleOffer_" + str(offre.id).validate_node_name())
		verifier(carte != null, "offre « %s » affichée" % str(offre.id))
		if carte != null:
			verifier(texte(carte, "SaleOfferFee").contains(G.euros(offre.fee)) and texte(carte, "SaleOfferFee").contains(str(offre.buyer)), "montant et acheteur : " + texte(carte, "SaleOfferFee"))
			var oui := noeud(carte, "SaleAccept") as Button
			verifier(oui != null and not oui.disabled, "« Conclure l’accord » disponible")
			verifier(texte(carte, "SaleDeferredNote").contains("1er mai"), "accord effectif à l’ouverture : " + texte(carte, "SaleDeferredNote"))
			for pct in [5, 10, 15]: verifier(noeud(carte, "SaleCounter%d" % pct) != null, "« Demander +%d %% »" % pct)
			verifier(noeud(carte, "SaleDecline") != null, "« Refuser »")
		var bloquee := noeud(app, "SaleOffer_" + str(fauche.id).validate_node_name())
		if bloquee != null:
			verifier(texte(bloquee, "SaleAcceptReason") == str(fauche.accept.reason), "raison écrite en clair : « %s »" % texte(bloquee, "SaleAcceptReason"))
			verifier((noeud(bloquee, "SaleAccept") as Button).disabled, "« Accepter » grisé quand l’acheteur n’a plus les moyens")
		else: verifier(false, "offre bloquée affichée")
		verifier(texte(app, "SalePending_" + str(accord.id).validate_node_name()).begins_with("Vente en attente : départ pour"), "vente en attente : " + texte(app, "SalePending_" + str(accord.id).validate_node_name()))
		textes_lisibles(noeud(app, "RecrutementAdopte"), "page des offres")
		await capturer("vente-offres.png")
		# 3. Confirmation (W1) : libellé = action, focus sur Annuler ; caisse, effectif, budget.
		if carte != null and noeud(carte, "SaleAccept") != null:
			(noeud(carte, "SaleAccept") as Button).pressed.emit()
			await poser(10)
			var confirmation := noeud(app, "SaleConfirmation") as Control
			verifier(confirmation != null and confirmation.is_visible_in_tree() and (app.find_children("*", "ConfirmationDialog", true, false).filter(func(d): return d.visible)).is_empty(), "confirmation EN PLACE (deux temps, aucune fenêtre)")
			if confirmation != null:
				verifier((noeud(app, "SaleConfirmationOk") as Button).text.begins_with("CONCLURE L’ACCORD AVEC"), "libellé = action : " + (noeud(app, "SaleConfirmationOk") as Button).text)
				verifier((noeud(app, "SaleConfirmationAnnuler") as Button).text == "Annuler", "bouton Annuler")
				verifier(root.gui_get_focus_owner() == noeud(app, "SaleConfirmationAnnuler"), "focus sur Annuler")
				verifier(texte(confirmation, "SaleConfirmCash").contains("+" + G.euros(offre.fee)) and texte(confirmation, "SaleConfirmCash").contains("1er mai"), "caisse : " + texte(confirmation, "SaleConfirmCash"))
				verifier(texte(confirmation, "SaleConfirmSquad").contains("Effectif après la vente : %d" % int(offre.squadAfter)), "effectif après vente : " + texte(confirmation, "SaleConfirmSquad"))
				verifier(texte(confirmation, "SaleConfirmBudget").begins_with("Budget de transferts"), "part rendue au budget : " + texte(confirmation, "SaleConfirmBudget"))
				textes_lisibles(confirmation, "confirmation")
				await capturer("vente-confirmation.png")
				(noeud(app, "SaleConfirmationAnnuler") as Button).pressed.emit()
				await poser(6)
		(noeud(app, "RecrutementRetour") as Button).pressed.emit()
		await poser(6)

	# 4. Fiche joueur, onglet Contrat : carte « Marché des transferts ».
	app.selected_player = str(attendu.propose)
	app.management_ui.immersive_player_tab = 3
	# _navigate("Effectif") revient à la liste : la fiche complète s'ouvre ensuite (comme « Ouvrir la fiche joueur »).
	app._navigate("Effectif"); await poser(10)
	app.set_meta("immersive08_full_player", true)
	app._render(); await poser(20)
	var panneau := noeud(app, "PlayerSalePanel") as Control
	verifier(panneau != null and panneau.is_visible_in_tree(), "carte Marché des transferts sur la fiche")
	if panneau != null:
		verifier(texte(panneau, "PlayerSaleStatus").begins_with("Offre reçue"), "état de vente : " + texte(panneau, "PlayerSaleStatus"))
		verifier(texte(panneau, "PlayerSaleToggle") == "Retirer du marché", "bouton : " + texte(panneau, "PlayerSaleToggle"))
		verifier(texte(panneau, "PlayerSaleOffers").begins_with("Offres reçues"), "accès aux offres depuis la fiche")
		sans_chevauchement(panneau, ["PlayerSaleStatus", "PlayerSaleReason", "PlayerSaleToggle", "PlayerSaleOffers"], "fiche")
		textes_lisibles(panneau, "fiche · marché")
	await capturer("vente-fiche.png")
	app.selected_player = str(attendu.recrue)
	app._render(); await poser(16)
	panneau = noeud(app, "PlayerSalePanel") as Control
	if panneau != null:
		verifier(texte(panneau, "PlayerSaleReason") == str(attendu.raisonRecrue), "raison de blocage en clair : " + texte(panneau, "PlayerSaleReason"))
		verifier((noeud(panneau, "PlayerSaleToggle") as Button).disabled, "« Proposer aux autres clubs » grisé pour une recrue")
		sans_chevauchement(panneau, ["PlayerSaleStatus", "PlayerSaleReason", "PlayerSaleToggle", "PlayerSaleOffers"], "fiche recrue")
	app.selected_player = str(attendu.enAttente)
	app._render(); await poser(16)
	panneau = noeud(app, "PlayerSalePanel") as Control
	if panneau != null:
		verifier(texte(panneau, "PlayerSaleStatus").begins_with("Vente en attente : départ pour"), "vente en attente sur la fiche : " + texte(panneau, "PlayerSaleStatus"))
		verifier((noeud(panneau, "PlayerSaleToggle") as Button).disabled, "pas de remise en vente d’un joueur déjà vendu")
	await capturer("vente-fiche-accord.png")

	# 5. Effectif : état de vente et boutons dans le dossier du joueur.
	app.set_meta("immersive08_full_player", false)
	app.selected_player = str(attendu.propose)
	app._navigate("Effectif"); await poser(20)
	var etat := noeud(app, "ProfileSaleStatus") as Label
	var bascule: Button = (noeud(app, "SquadSaleAction") if etat == null else noeud(app, "ProfileSaleToggle")) as Button
	verifier(etat != null or noeud(app, "SquadSaleAction") != null, "état de vente dans l’Effectif")
	if etat != null:
		verifier(etat.text.begins_with("Offre reçue"), "Effectif : " + etat.text)
		verifier(taille(etat) >= TAILLE_MIN, "Effectif : texte lisible (%d px)" % taille(etat))
		verifier(bascule != null and bascule.text == "RETIRER DU MARCHÉ", "Effectif : bouton retirer")
		verifier(noeud(app, "ProfileSaleOffers") != null, "Effectif : accès aux offres")
	elif bascule != null:
		verifier(bascule.text == "Voir l’offre", "Effectif (grand écran) : " + bascule.text)
	await capturer("vente-effectif.png")

	# 6. Courrier « offre_transfert » : « Ouvrir · Offres reçues » mène à Recrutement et ouvre la boîte.
	var courrier: Dictionary = {}
	for mail: Dictionary in ClubMail.mails(app.model):
		if str(mail.get("type", "")) == "offre_transfert": courrier = mail
	verifier(not courrier.is_empty(), "courrier « offre_transfert » en Réception")
	verifier(str(courrier.get("nature", "")) == "info" and not bool(courrier.get("arret", true)), "courrier d’information, sans arrêt de « Continuer »")
	verifier(ClubMail.caption(str(courrier.get("ecran", ""))) == "Ouvrir · Offres reçues", "lien : " + ClubMail.caption(str(courrier.get("ecran", ""))))
	if not courrier.is_empty() and DisplayServer.get_name() != "headless":
		app._reset_reception(str(courrier.id))
		app._navigate("Réception", false); await poser(20)
		await capturer("vente-courrier.png")
	ClubMail.open_screen(app, str(courrier.get("ecran", "")), "")
	await poser(24)
	verifier(app.route == "Recrutement", "le lien ouvre Recrutement (route %s)" % str(app.route))
	var rouverte := noeud(app, "PlayerSales") as AcceptDialog
	verifier(rouverte != null and not rouverte.visible and noeud(app, "RecrutementSubpage_offres") != null, "le lien ouvre la page des offres reçues")

	print("VENTE ", JSON.stringify({"controles": controles, "failures": echecs, "offres": n_offres}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
