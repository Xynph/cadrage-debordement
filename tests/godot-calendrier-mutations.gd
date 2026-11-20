extends SceneTree
## Calendrier du recrutement dans le vrai jeu (profil préparé par tests/godot-calendrier-mutations.cjs, vrai moteur),
## fenêtre 1280×720 : Recrutement (RecruitmentWindow), Marché entre clubs (InterclubWindow, InterclubPreContractFilter,
## InterclubPreContractStatus, fenêtre du pré-contrat PreContractNote/PreContractSalary/PreContractYears/
## PreContractPremium/PreContractSubmit, confirmation PreContractConfirmation : libellé = action, focus sur Annuler), fiche
## joueur onglet Contrat (PlayerPreContract) et lien du courrier « precontrat_approche » (« Proposer une prolongation »,
## fiche du joueur sur l'onglet Contrat). Textes ≥ 13 px, aucun chevauchement.
const G = preload("res://ui/carnet_skin.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const TAILLE_MIN := 13
const PLANCHER_RECEPTION := 12
var app: Control
var sortie := OS.get_environment("CD_CALENDRIER_OUTPUT")
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
	return control.get_theme_font_size("normal_font_size" if control is RichTextLabel else "font_size")

## Texte affiché d'un Label ou d'un RichTextLabel (lettre de la Réception : BBCode avec liens, texte brut rendu).
func texte_affiche(c: Control) -> String:
	if c is RichTextLabel: return (c as RichTextLabel).get_parsed_text()
	if c is Label: return (c as Label).text
	return ""

## Tous les textes visibles d'un sous-arbre font au moins TAILLE_MIN px.
func textes_lisibles(parent: Node, contexte: String, minimum := TAILLE_MIN) -> void:
	var petits: Array[String] = []
	for n in parent.find_children("*", "Label", true, false) + parent.find_children("*", "Button", true, false) + parent.find_children("*", "RichTextLabel", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree() or (c is Label and (c as Label).text.is_empty()) or (c is Button and (c as Button).text.is_empty()) or (c is RichTextLabel and (c as RichTextLabel).get_parsed_text().strip_edges().is_empty()): continue
		if taille(c) < minimum: petits.append("%s (%d px)" % [c.name, taille(c)])
	verifier(petits.is_empty(), contexte + " : textes sous %d px : %s" % [minimum, ", ".join(petits)])

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

## Lignes à puces « • » d'un texte.
func puces(t: String) -> int:
	var n := 0
	for l in t.split("\n"): if l.begins_with("• "): n += 1
	return n

## Textes d'un bouton et de ses libellés.
func textes_de(n: Node) -> String:
	var parts := PackedStringArray([(n as Button).text if n is Button else ""])
	for l: Label in n.find_children("*", "Label", true, false): parts.append(l.text)
	return " ".join(parts)

## Ouvre un courrier du club en Réception : corps à retours à la ligne, entier, lisible, sans chevauchement ; capture.
## Rend le texte affiché.
func courrier(info: Dictionary, capture: String, contexte: String) -> String:
	app._reset_reception(str(info.id))
	app._navigate("Réception", false)
	await poser(24)
	var detail := noeud(app.root_content, "InboxDetail") as Control
	# Nouvelle Réception (lettre papier) : le corps est un RichTextLabel (noms en liens BBCode) ; l'ancien Label reste accepté.
	var corps := noeud(app.root_content, "InboxMessageText") as Control
	var lisible := corps is Label or corps is RichTextLabel
	verifier(detail != null and lisible and corps.is_visible_in_tree(), contexte + " : courrier ouvert en Réception")
	if detail == null or not lisible: return ""
	var affiche := texte_affiche(corps)
	var paragraphes := affiche.split("\n").size()
	# Le titre de la lettre est en capitales : comparaison sans casse.
	verifier(textes_de(detail).to_lower().contains(str(info.sujet).to_lower()), contexte + " : sujet « %s » affiché" % str(info.sujet))
	verifier(corps.get("autowrap_mode") != TextServer.AUTOWRAP_OFF, contexte + " : retours à la ligne automatiques")
	verifier(corps.get_line_count() >= paragraphes, contexte + " : une ligne par puce (%d lignes pour %d paragraphes)" % [corps.get_line_count(), paragraphes])
	if corps is Label: verifier((corps as Label).max_lines_visible < 0 or (corps as Label).get_visible_line_count() >= corps.get_line_count(), contexte + " : texte entier")
	else: verifier((corps as RichTextLabel).get_visible_line_count() >= corps.get_line_count(), contexte + " : texte entier (%d/%d lignes)" % [(corps as RichTextLabel).get_visible_line_count(), corps.get_line_count()])
	var d := detail.get_global_rect()
	var c := corps.get_global_rect()
	verifier(c.position.x >= d.position.x - 1.0 and c.end.x <= d.end.x + 1.0, contexte + " : texte dans la largeur du courrier (%s ⊂ %s)" % [str(c), str(d)])
	# Réception (coque immersive) : plancher de la coque en 1280×720, 12 px (comme tests/godot-courrier-club.gd).
	textes_lisibles(detail, contexte, PLANCHER_RECEPTION)
	sans_chevauchement(detail, ["InboxReadingScroll", "InboxReplyHeading", "InboxClubMailOpen"], contexte)
	await capturer(capture)
	return affiche

func executer() -> void:
	attendu = JSON.parse_string(OS.get_environment("CD_CALENDRIER_ATTENDU"))
	var demande := OS.get_environment("CD_CALENDRIER_SIZE").split("x")
	root.size = Vector2i(int(demande[0]), int(demande[1])) if demande.size() == 2 and int(demande[0]) > 0 else Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	verifier(str(app.model.get("mutations", {}).get("summary", "")) == str(attendu.summary), "calendrier lu par Godot = moteur")

	# 1. Recrutement : période des joueurs sans club écrite au-dessus des accès au marché.
	app._navigate("Recrutement"); await poser(20)
	var fenetre := noeud(app, "RecruitmentWindow") as Label
	verifier(fenetre != null and fenetre.is_visible_in_tree(), "période des joueurs sans club visible dans Recrutement")
	if fenetre != null:
		verifier(fenetre.text == str(attendu.summary), "libellé : « %s »" % fenetre.text)
		verifier(taille(fenetre) >= TAILLE_MIN, "période lisible (%d px)" % taille(fenetre))
		verifier(fenetre.tooltip_text.contains("1er mai"), "infobulle : période des mutations (" + fenetre.tooltip_text + ")")
	var page := noeud(app, "CarnetMarket") as Control
	if page != null: sans_chevauchement(page, ["RecruitmentWindow", "OpenPlayerSales", "OpenRegenScouting", "OpenInterclubMarket", "MarketTab0", "RecruitmentTransferBudget"], "Recrutement")
	var acces := noeud(app, "OpenInterclubMarket") as Button
	verifier(acces != null and acces.tooltip_text == str(attendu.interclubNote), "accès au marché entre clubs : période en infobulle")
	await capturer("calendrier-recrutement.png")

	# 2. Marché entre clubs : période des mutations, filtre des fins de contrat, pré-contrat signé.
	var marche: AcceptDialog = load("res://ui/interclub_market_view.gd").open(app)
	await poser(12)
	verifier(marche != null and marche.visible, "marché entre clubs ouvert")
	if marche != null:
		verifier(texte(marche, "InterclubWindow") == str(attendu.interclubNote) and texte(marche, "InterclubWindow").contains("1er mai"), "période des mutations écrite : " + texte(marche, "InterclubWindow"))
		var filtre := noeud(marche, "InterclubPreContractFilter") as CheckButton
		verifier(filtre != null, "filtre des fins de contrat")
		if filtre != null: filtre.button_pressed = true
		await poser(6)
		# Recherche sur le nom du joueur signé (pré-contrat) : sa carte affiche l'arrivée au 1er juillet.
		var nom := ""
		for person: Dictionary in marche._data().get("candidates", []):
			if str(person.id) == str(attendu.signe.id): nom = str(person.name)
		marche.search_field.text = nom
		marche.search_field.text_changed.emit(nom)
		await poser(8)
		verifier(texte(marche, "InterclubPreContractStatus") == str(attendu.signe.label), "pré-contrat signé : " + texte(marche, "InterclubPreContractStatus"))
		verifier(str(attendu.signe.label).contains("1er juillet"), "arrivée au 1er juillet")
		textes_lisibles(marche, "marché entre clubs")
		await capturer("calendrier-marche.png")

		# 3. Fenêtre « Proposer un pré-contrat » (devis du moteur) et confirmation W1.
		marche._precontract(attendu.devis)
		await poser(10)
		var devis: Dictionary = attendu.devis.preContract
		verifier(texte(marche, "PreContractNote").contains("1er juillet"), "arrivée écrite : " + texte(marche, "PreContractNote"))
		verifier(noeud(marche, "PreContractSalary") is SpinBox and noeud(marche, "PreContractYears") is SpinBox, "salaire et durée")
		verifier(texte(marche, "PreContractPremium").contains(G.euros(devis.premium)), "prime à la signature : " + texte(marche, "PreContractPremium"))
		var envoyer := noeud(marche, "PreContractSubmit") as Button
		verifier(envoyer != null and not envoyer.disabled, "« Proposer le pré-contrat » disponible")
		textes_lisibles(marche, "fenêtre du pré-contrat")
		await capturer("calendrier-precontrat.png")
		if envoyer != null:
			envoyer.pressed.emit()
			await poser(10)
			var confirmation := noeud(marche, "PreContractConfirmation") as ConfirmationDialog
			verifier(confirmation != null and confirmation.visible, "confirmation ouverte")
			if confirmation != null:
				verifier(confirmation.get_ok_button().text.begins_with("SIGNER LE PRÉ-CONTRAT AVEC"), "libellé = action : " + confirmation.get_ok_button().text)
				verifier(confirmation.get_cancel_button().text == "ANNULER", "bouton Annuler")
				verifier(confirmation.gui_get_focus_owner() == confirmation.get_cancel_button(), "focus sur Annuler")
				verifier(texte(confirmation, "PreContractConfirmHeading").contains("Aucune indemnité"), "sans indemnité : " + texte(confirmation, "PreContractConfirmHeading"))
				verifier(texte(confirmation, "PreContractConfirmPremium").contains(G.euros(devis.premium)), "prime : " + texte(confirmation, "PreContractConfirmPremium"))
				textes_lisibles(confirmation, "confirmation du pré-contrat")
				await capturer("calendrier-confirmation.png")
				confirmation.get_cancel_button().pressed.emit()
				await poser(6)
		verifier(not app.waiting, "Annuler n’envoie rien au moteur")
		marche.hide(); marche.queue_free()
		await poser(6)

	# 4. Fiche joueur, onglet Contrat : approche d'un autre club.
	app.selected_player = str(attendu.approche.playerId)
	app.management_ui.immersive_player_tab = 3
	app._navigate("Effectif"); await poser(10)
	app.set_meta("immersive08_full_player", true)
	app._render(); await poser(20)
	var panneau := noeud(app, "PlayerSalePanel") as Control
	verifier(panneau != null and panneau.is_visible_in_tree(), "carte Marché des transferts sur la fiche")
	if panneau != null:
		verifier(texte(panneau, "PlayerPreContract") == str(attendu.approche.short), "approche sur la fiche : " + texte(panneau, "PlayerPreContract"))
		var ligne := noeud(panneau, "PlayerPreContract") as Label
		if ligne != null: verifier(taille(ligne) >= TAILLE_MIN, "approche lisible (%d px)" % taille(ligne))
		sans_chevauchement(panneau, ["PlayerSaleStatus", "PlayerPreContract", "PlayerSaleToggle", "PlayerSaleOffers"], "fiche")
		textes_lisibles(panneau, "fiche · marché")
	await capturer("calendrier-fiche.png")

	# 5. Courrier « precontrat_approche » : lien « Proposer une prolongation » vers la fiche, onglet Contrat.
	var courrier: Dictionary = {}
	for mail: Dictionary in ClubMail.mails(app.model):
		if str(mail.get("type", "")) == "precontrat_approche": courrier = mail
	verifier(not courrier.is_empty(), "courrier d’approche en Réception")
	verifier(str(courrier.get("nature", "")) == "info" and not bool(courrier.get("arret", true)), "courrier d’information, sans arrêt de « Continuer »")
	verifier(ClubMail.caption(str(courrier.get("ecran", ""))) == "Proposer une prolongation", "lien : " + ClubMail.caption(str(courrier.get("ecran", ""))))
	app.management_ui.immersive_player_tab = 0
	app.selected_player = ""
	ClubMail.open_screen(app, str(courrier.get("ecran", "")), str(courrier.get("joueur", "")))
	await poser(24)
	verifier(app.selected_player == str(attendu.approche.playerId), "le lien ouvre la fiche du joueur approché")
	verifier(int(app.management_ui.immersive_player_tab) == 3, "onglet Contrat ouvert")

	# 6. Écran des ventes : une vente acceptée prend effet au changement de saison (1er juillet), jamais tout de suite.
	var ventes: AcceptDialog = load("res://ui/player_sales_view.gd").open(app)
	await poser(14)
	verifier(ventes != null and ventes.visible, "écran des ventes ouvert")
	if ventes != null:
		var periode := texte(ventes, "SalesWindow")
		verifier(periode.contains("1er juillet") and periode.contains("changement de saison"), "ventes : effet au 1er juillet : " + periode)
		verifier(not periode.contains("tout de suite") and not periode.contains("1er mai"), "ventes : ni « tout de suite » ni « 1er mai » : " + periode)
		verifier(ventes.find_children("SaleOffer_*", "", true, false).size() >= 3, "offres reçues affichées")
		var ligne_periode := noeud(ventes, "SalesWindow") as Label
		if ligne_periode != null: verifier(ligne_periode.get_visible_line_count() >= ligne_periode.get_line_count(), "période des ventes entière")
		textes_lisibles(ventes, "écran des ventes")
		await capturer("calendrier-ventes.png")
		ventes.hide(); ventes.queue_free()
		await poser(6)

	# 7. Réception : « Point mercato » (offres reçues regroupées, lien « Ouvrir · Offres reçues ») et « Échos du mercato »
	# (liste à puces puis « et N autres »).
	var point := await courrier(attendu.point, "calendrier-point-mercato.png", "Point mercato")
	verifier(point.contains("Offres reçues pour nos joueurs :"), "Point mercato : offres reçues regroupées")
	verifier(puces(point) >= 3, "Point mercato : une puce par offre")
	var lien := noeud(app.root_content, "InboxClubMailOpen") as Control
	verifier(lien != null and lien.is_visible_in_tree() and textes_de(lien).to_lower().contains("offres reçues"), "lien « Ouvrir · Offres reçues » : " + ("" if lien == null else textes_de(lien)))
	var echos := await courrier(attendu.echos, "calendrier-echos-mercato.png", "Échos du mercato")
	verifier(puces(echos) == 6, "Échos : six lignes à puces")
	verifier(echos.contains("\net 2 autres\n"), "Échos : « et 2 autres » sur sa ligne")

	# 8. Arrêt de « Continuer » « Effectif trop juste » (arrêt réel du moteur) dans le panneau de Continuer.
	var progression = app.continue_progress
	var court: Dictionary = attendu.court
	verifier(progression != null, "panneau de Continuer")
	if progression != null:
		progression.begin({"date": str(court.get("from", attendu.today))}, false)
		await poser(4)
		progression.finish(court)
		await poser(6)
		verifier(progression.visible, "panneau d’arrêt affiché")
		verifier(progression.title.text == "Effectif trop juste", "titre de l’arrêt : " + progression.title.text)
		verifier(progression.detail.text == str(court.stop.detail) and progression.detail.text.contains("pilier droit"), "détail de l’arrêt : " + progression.detail.text)
		verifier(progression.detail.get_visible_line_count() >= progression.detail.get_line_count(), "détail de l’arrêt entier (%d/%d lignes)" % [progression.detail.get_visible_line_count(), progression.detail.get_line_count()])
		textes_lisibles(progression.card, "panneau d’arrêt")
		# Taille réellement affichée (la carte est mise à l'échelle de la fenêtre).
		var petits: Array[String] = []
		for l: Label in progression.card.find_children("*", "Label", true, false):
			if l.is_visible_in_tree() and not l.text.is_empty() and taille(l) * progression.card.scale.y < TAILLE_MIN - 0.01: petits.append("%s (%.1f px)" % [l.name, taille(l) * progression.card.scale.y])
		verifier(petits.is_empty(), "panneau d’arrêt : textes affichés sous %d px : %s" % [TAILLE_MIN, ", ".join(petits)])
		var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
		var carte: Rect2 = progression.card.get_global_transform() * Rect2(Vector2.ZERO, progression.card.size)
		verifier(ecran.encloses(carte), "carte d’arrêt dans la fenêtre : " + str(carte))
		var zones: Array = []
		for nom: String in ["ContinueProgressSheet", "ContinueProgressTitle", "ContinueProgressDetail", "ContinueProgressBar"]:
			var c := noeud(progression.card, nom) as Control
			if c == null or not c.is_visible_in_tree(): continue
			var r: Rect2 = c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
			verifier(carte.grow(1.0).encloses(r), "panneau d’arrêt : %s dans la carte" % nom)
			for autre: Array in zones: verifier(not (autre[1] as Rect2).grow(-1.0).intersects(r.grow(-1.0)), "panneau d’arrêt : %s ne chevauche pas %s" % [nom, autre[0]])
			zones.append([nom, r])
		await capturer("calendrier-effectif-court.png")
		progression.dismiss()

	print("CALENDRIER ", JSON.stringify({"controles": controles, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
