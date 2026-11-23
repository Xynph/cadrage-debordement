extends SceneTree
# Écran Effectif de la revue DA du 19/11/2026 (variante « nouvelle 1 ») : tuiles, infobulle « Équilibre par poste »,
# puces de filtre, onglets, tableau pleine largeur, tout cliquable, aucune fenêtre ouverte par un clic, aucun or,
# fenêtre étroite sans texte sous 12 px. Carrière Monde réelle.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const U = preload("res://ui/management_state.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
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
	print("EFFECTIF DA : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found

func page() -> Control:
	return app.find_child("CarnetSquad", true, false)

func player_rows() -> Array:
	return page().rows.get_children().filter(func(node: Node): return node is Button and node.has_meta("player_id"))

func press(id: String) -> bool:
	var button := app.find_child(id, true, false) as Button
	check(button != null and button.is_visible_in_tree(), "Contrôle cliquable présent : " + id)
	if button == null: return false
	button.pressed.emit()
	await settle(8)
	return true

func is_gold(color: Color) -> bool:
	return color.is_equal_approx(Charte.OR) or color.is_equal_approx(Charte.OR_VIF)

func gold_free(node: Node) -> bool:
	if node is Label and is_gold((node as Label).get_theme_color("font_color")): return false
	if node is Control:
		for style_name: String in ["panel", "normal", "hover", "pressed", "focus"]:
			var style := (node as Control).get_theme_stylebox(style_name) if (node as Control).has_theme_stylebox_override(style_name) else null
			if style is StyleBoxFlat and (is_gold(style.bg_color) or is_gold(style.border_color)): return false
	if node is Polygon2D and is_gold((node as Polygon2D).color): return false
	for child in node.get_children():
		if not gold_free(child): return false
	return true

## Aucun aplat ni marqueur vert de sélection (décision de Léo : seul le survol fait ressortir une ligne).
func selection_free(node: Node) -> bool:
	if node is Control:
		for style_name: String in ["panel", "normal", "pressed", "focus"]:
			var style := (node as Control).get_theme_stylebox(style_name) if (node as Control).has_theme_stylebox_override(style_name) else null
			if style is StyleBoxFlat and style.bg_color.a > 0.0 and style.bg_color.is_equal_approx(Charte.SELECTION): return false
	if node is Polygon2D and (node as Polygon2D).visible and node.name == "RosterMarqueur": return false
	for child in node.get_children():
		if not selection_free(child): return false
	return true

func survols(rows: Array) -> Array:
	return rows.map(func(r: Button): return r.get_node_or_null("SurvolLigne")).filter(func(n): return n != null)

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
	app._navigate("Effectif")
	await settle(12)
	check(page() != null, "Écran Effectif construit")
	if page() == null: return finish()
	# Survol de ligne (option A) : aucune ligne verte à l'arrivée, survol = bande claire + liseré club.
	var arrivee := player_rows()
	var fonds := survols(arrivee)
	check(not arrivee.is_empty() and fonds.size() == arrivee.size(), "Chaque ligne porte le survol commun")
	check(selection_free(page()), "Arrivée sur l'Effectif : aucune ligne verte ni marqueur de sélection")
	check(fonds.all(func(f): return not f.survole), "Arrivée : aucune ligne survolée")
	check(arrivee.all(func(r: Button): return r.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND), "Lignes : curseur main")
	# Rayures : une ligne sur 2 (rang impair, dans l'ordre affiché), nettement moins visibles que le survol.
	var rangs := fonds.map(func(f): return f.rang())
	check(rangs == range(fonds.size()), "Rayures : rang des lignes dans l'ordre affiché (en-têtes de groupe exclus)")
	check(fonds[0].RAYURE.a > 0.0 and fonds[0].RAYURE.a * 2.0 < fonds[0].BANDE.a, "Rayure plus discrète que la bande de survol")
	var survolee := arrivee[2] as Button
	survolee.mouse_entered.emit()
	await settle()
	var fond_survol = survolee.get_node("SurvolLigne")
	check(fond_survol.survole and survols(arrivee).filter(func(f): return f.survole).size() == 1, "Survol : seule la ligne sous la souris se démarque")
	check(fond_survol.get_index() == 0 and fond_survol.accent == app.accent, "Survol : bande derrière les textes, liseré à la couleur du club")
	var club_lisible: Color = fond_survol.accent_lisible(app.accent)
	check(club_lisible.v >= 0.85, "Liseré éclairci sur fond sombre")
	survolee.mouse_exited.emit()
	await settle()
	check(not fond_survol.survole, "La bande disparaît à la sortie de la souris")
	var squad: Array = app.model.squad
	var unavailable := squad.filter(func(p: Dictionary): return not U.indisponibilite(p).is_empty()).size()
	var season := int(app.model.meta.season)
	var expiring := squad.filter(func(p: Dictionary): return p.get("contractEnd") != null and int(p.contractEnd) <= season).size()

	# Titre et tuiles.
	check(app.find_child("RosterTitre", true, false) != null and (app.find_child("RosterTitre", true, false) as Label).text == "EFFECTIF", "Titre EFFECTIF")
	for id in ["Aptes", "Indisponibles", "Contrats", "Niveau"]:
		check(app.find_child("EffectifTuile" + id, true, false) is Button, "Tuile cliquable : " + id)
	var tile_values := func(id: String) -> String: return (app.find_child("EffectifTuile" + id, true, false).find_child("EffectifTuileValeur", true, false) as Label).text
	check(tile_values.call("Aptes") == str(squad.size() - unavailable), "Tuile Aptes : nombre exact d'aptes")
	check(tile_values.call("Indisponibles") == str(unavailable), "Tuile Indisponibles : nombre exact")
	check(tile_values.call("Contrats") == str(expiring), "Tuile Fins de contrat : nombre exact")

	# Infobulle « Équilibre par poste » : un Control (pas une fenêtre), disparaît à la sortie.
	var aptes := app.find_child("EffectifTuileAptes", true, false) as Button
	aptes.mouse_entered.emit()
	await settle()
	var bulle := app.get_node_or_null("EquilibrePostes") as Control
	check(bulle != null and bulle.is_visible_in_tree(), "Survol d'Aptes : infobulle Équilibre par poste")
	check(bulle != null and bulle.find_children("*", "Label", true, false).size() >= 11 * 4, "Infobulle : onze postes, effectif, aptes, fins")
	check(windows(app).is_empty(), "Infobulle : aucune fenêtre")
	aptes.mouse_exited.emit()
	await settle()
	check(app.get_node_or_null("EquilibrePostes") == null, "L'infobulle se ferme à la sortie")

	# Puces : chaque puce filtre réellement, avec son compteur.
	for id in ["tous", "avants", "arrieres", "indisponibles", "fin", "surveiller"]:
		check(app.find_child("RosterChip_" + id, true, false) is Button, "Puce cliquable : " + id)
	await press("RosterChip_indisponibles")
	check(player_rows().size() == unavailable, "Puce Indisponibles : %d lignes" % unavailable)
	await press("RosterChip_fin")
	check(player_rows().size() == expiring, "Puce Fin de contrat : %d lignes" % expiring)
	await press("RosterChip_avants")
	check(player_rows().all(func(r: Button): return float(app.model.squad.filter(func(p: Dictionary): return str(p.id) == str(r.get_meta("player_id")))[0].fam) <= 3), "Puce Avants : que des avants")
	await press("EffectifTuileIndisponibles")
	check(player_rows().size() == unavailable, "Tuile Indisponibles = puce Indisponibles")
	await press("EffectifTuileAptes")
	check(player_rows().size() == squad.size() - unavailable, "Tuile Aptes ne garde que les aptes")
	await press("RosterChip_tous")
	check(player_rows().size() == squad.size(), "Puce Tous : tout le groupe")
	check(windows(app).is_empty(), "Puces et tuiles : aucune fenêtre ouverte")

	# Onglets et tri.
	await press("RosterTab1")
	check(app.find_child("RosterColumnFatigue", true, false) != null, "Onglet Condition : colonne Fatigue")
	await press("RosterTab3")
	check(app.find_child("RosterColumnPotential", true, false) != null, "Onglet Développement : colonne Potentiel")
	await press("RosterTab2")
	check(app.find_child("ImmersiveRosterTable", true, false) == null, "Onglet Contrats : revue des contrats")
	await press("RosterTab0")
	await press("Sort_Niveau")
	check(page().state.sort == "Niveau", "En-tête de colonne : tri par niveau")
	check(windows(app).is_empty(), "Onglets et tris : aucune fenêtre")

	# Listes (choix de Léo du 21/11/2026) : en-tête trié souligné ▲/▼, pastilles de poste, tuiles des totaux, forme en cases.
	await press("Sort_Âge")
	var entete_age: Dictionary = page().sort_headers.get("Âge", {})
	check(page().state.sort == "Âge", "Clic sur l'en-tête ÂGE : tri par âge")
	check(not entete_age.is_empty() and ((entete_age.label as Label).text.ends_with(" ▲") or (entete_age.label as Label).text.ends_with(" ▼")), "En-tête trié : flèche ▲ ou ▼")
	var souligne := (entete_age.button as Button).get_theme_stylebox("normal") as StyleBoxFlat
	check(souligne != null and souligne.border_width_bottom > 0, "En-tête trié : souligné")
	var fleche := (entete_age.label as Label).text.right(1)
	await press("Sort_Âge")
	check((page().sort_headers["Âge"].label as Label).text.right(1) != fleche, "Second clic : sens du tri inversé")
	var deuxieme := squad.filter(func(p: Dictionary): return Listes.groupe_de(p) == "deuxieme").size()
	check(app.find_child("PostePastille_tous", true, false) is Button, "Pastille Tous postes")
	await press("PostePastille_deuxieme")
	check(player_rows().size() == deuxieme, "Pastille 2e ligne : %d lignes" % deuxieme)
	var total_joueurs := app.find_child("TotalTuile_Joueurs", true, false)
	check(total_joueurs != null and (total_joueurs.find_child("TuileValeur", true, false) as Label).text == str(deuxieme), "Tuile Joueurs : suit le filtre de poste")
	check(app.find_child("TotalTuile_Fins", true, false) == null, "Pas de tuile Fins de contrat (déjà en haut de l'écran)")
	await press("PostePastille_tous")
	check(player_rows().size() == squad.size(), "Pastille Tous postes : tout le groupe")
	await press("TotalTuileOuvrir_Niveau")
	check(page().state.sort == "Niveau", "Tuile Niveau moyen : trie par niveau")
	await press("TotalTuileOuvrir_Masse")
	check(app.route == "Finances", "Tuile Masse salariale : écran Finances")
	app._navigate("Effectif")
	await settle(12)
	# Bandeau des filtres (21/11/2026) : panneau teinté détouré, derrière la recherche, les tuiles, les pastilles et les
	# en-têtes, à la largeur du tableau ; il suit le tableau quand une colonne s'ouvre à gauche (la tête reste en place).
	var bandeau := page().find_child("BandeauFiltres", false, false) as Panel
	var table := page().find_child("ImmersiveRosterTable", false, false) as Control
	check(bandeau != null and bandeau.get_index() == 0, "Bandeau des filtres derrière les commandes")
	if bandeau != null and table != null:
		var style := bandeau.get_theme_stylebox("panel") as StyleBoxFlat
		check(style != null and style.bg_color == Charte.BANDEAU and style.border_color == Charte.BANDEAU_BORD and style.border_width_top == 1, "Bandeau : teinte et contour 1 px de la charte")
		check(absf(bandeau.position.x - table.position.x) < 1.0 and absf(bandeau.size.x - table.size.x) < 1.0, "Bandeau à la largeur du tableau")
		var recherche := page().find_child("RosterSearch", true, false) as Control
		check(recherche != null and bandeau.get_rect().encloses(recherche.get_rect()), "Recherche dans le bandeau")
		var entete := table.find_child("RosterHeader", false, false) as Control
		check(entete != null and absf(bandeau.get_rect().end.y - (table.position.y + entete.position.y + entete.size.y)) < 2.0, "Les en-têtes de colonnes ferment le bas du bandeau")
		check(bandeau.find_child("BandeauEntete", false, false) != null, "Bande des en-têtes au bas du bandeau")
		table.position.x += 300.0
		table.size.x -= 300.0
		await settle(2)
		check(absf(bandeau.position.x - table.position.x) < 1.0 and absf(bandeau.size.x - table.size.x) < 1.0, "Bandeau : suit le tableau décalé")
		check(page().find_child("BandeauFiltresTete", false, false) == null, "Bandeau : un seul bloc, jamais coupé en deux")
		app._render(false)
		await settle(12)
	# Moral et condition : mini-courbe au survol des tuiles (relevé hebdomadaire du moteur, quand il existe).
	check(app.find_child("TotalTuileOuvrir_Moral", true, false) is Button, "Tuile Moral cliquable")
	if (app.model.get("groupHistory", []) as Array).size() >= 2:
		var cond := app.find_child("TotalTuileOuvrir_Condition", true, false) as Control
		check(cond != null and str(cond.get_meta("bulle_survol", "")) == "courbe:condition", "Tuile Condition : courbe au survol")
	await press("TotalTuileOuvrir_Moral")
	check(app.route == "Vestiaire", "Tuile Moral : Vestiaire (%s)" % app.route)
	app._navigate("Effectif")
	await settle(12)
	# Forme récente : cinq cases colorées (note dedans), clic = petite fenêtre du match avec le score.
	var cible := str(squad[0].id)
	var vie: Dictionary = app.model.get("clubLife", {})
	if not vie.get("matchNotes") is Dictionary: vie["matchNotes"] = {"joueurs": {}}
	if not vie.matchNotes.get("joueurs") is Dictionary: vie.matchNotes["joueurs"] = {}
	var matchs := []
	for k in 5: matchs.append({"note": 5.0 + k, "semaine": k, "adversaire": "Rivaux %d" % k, "adversaireId": 1, "scorePour": 20 + k, "scoreContre": 12})
	vie.matchNotes.joueurs[cible] = {"forme": [5.0, 6.0, 7.0, 8.0, 9.0], "formeMatchs": matchs, "historique": []}
	app.model["clubLife"] = vie
	app._render(false)
	await settle(12)
	var ligne: Button = null
	for r: Button in player_rows():
		if str(r.get_meta("player_id")) == cible: ligne = r
	check(ligne != null, "Ligne du joueur à forme connue")
	if ligne != null:
		var case_ := ligne.find_child("FormeMatch4", true, false) as Button
		check(case_ != null, "Cinq cases de forme")
		if case_ != null:
			check((case_.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(Charte.couleur_note(9.0)), "Case de forme : couleur du barème des notes")
			check(case_.tooltip_text.contains("Rivaux 4") and case_.tooltip_text.contains("9,0"), "Survol d'une case : adversaire et note")
			case_.pressed.emit()
			await settle(8)
			var fenetre := app.find_child("FormeMatchFenetre", true, false)
			check(fenetre != null, "Clic sur une case : petite fenêtre du match")
			var score := app.find_child("FormeMatchScore", true, false) as Label
			check(score != null and score.text == "24 – 12", "Petite fenêtre : score du match")
			check(app.route == "Effectif", "Petite fenêtre : on reste sur l'Effectif")
			var echap := InputEventKey.new()
			echap.keycode = KEY_ESCAPE
			for down in [true, false]:
				echap.pressed = down
				Input.parse_input_event(echap)
				await process_frame
			await settle(8)
			check(app.find_child("FormeMatchFenetre", true, false) == null and app.route == "Effectif", "Échap ferme la petite fenêtre du match")
	# Le focus rendu à la case a pu faire glisser la liste de quelques pixels : on repart du haut pour la suite.
	page().state.scroll = 0
	(app.find_child("SquadScroll", true, false) as ScrollContainer).scroll_vertical = 0
	await settle(2)

	# Lignes : focus clavier, clic = fiche complète, retour.
	var rows := player_rows()
	check(rows.size() == squad.size() and rows.all(func(r: Button): return r.find_child("SquadOpenPlayer_*", true, false) != null), "Chaque ligne a son nom cliquable")
	check(page().find_children("RosterNumero", "Label", true, false).size() == squad.size(), "Chaque ligne a son numéro ou son tiret")
	var statuts: Array = page().find_children("RosterStatut", "Label", true, false)
	check(statuts.size() == squad.size() and statuts.all(func(l: Label): return not l.text.is_empty()), "Chaque ligne écrit son statut (jamais la couleur seule)")
	var second := rows[1] as Button
	second.grab_focus()
	await settle()
	check(app.selected_player == str(second.get_meta("player_id")), "Le focus clavier change le joueur courant")
	check(selection_free(page()), "Le focus clavier ne colore pas la ligne (contour discret seulement)")
	var anneau := second.get_theme_stylebox("focus") as StyleBoxFlat
	check(anneau != null and anneau.border_width_left >= 2 and anneau.bg_color.a == 0.0, "Focus clavier : contour crème sans fond")
	check(gold_free(page()), "Aucun or dans l'écran Effectif")
	second.pressed.emit()
	await settle(10)
	check(app.find_child("ImmersivePlayerFull", true, false) != null, "Clic sur une ligne : fiche complète")
	check(windows(app).is_empty(), "Ouvrir une fiche n'ouvre aucune fenêtre")
	app._navigate("Effectif")
	await settle(10)

	# Un joueur éloigné dans la liste est ramené dans la zone visible à l'ouverture de l'écran.
	var last_id := ""
	var candidates := player_rows()
	candidates.reverse()
	for candidate: Button in candidates:
		if str(candidate.get_meta("player_id")).begins_with("world:"):
			last_id = str(candidate.get_meta("player_id"))
			break
	app.selected_player = last_id
	app._navigate("Bureau")
	await settle(6)
	app._navigate("Effectif")
	await settle(14)
	var list_scroll := app.find_child("SquadScroll", true, false) as ScrollContainer
	var last_row := app.find_child("SquadPlayer" + last_id.replace(":", "_"), true, false) as Control
	check(list_scroll != null and last_row != null and list_scroll.get_global_rect().intersects(last_row.get_global_rect()), "Le joueur choisi, même éloigné, est visible dans la liste")
	check(selection_free(page()), "Retour sur l'Effectif : le joueur choisi est montré sans être coloré")
	app.selected_player = str(squad[0].id)

	# Comparateur : page pleine (jamais une fenêtre), ajout à la souris, emplacements vides, radar 8 axes, Échap.
	app.management_ui.compare = []
	app._navigate("Bureau")
	await settle(6)
	app._navigate("Effectif")
	await settle(12)
	var plus := player_rows()[0].find_child("RosterCompare_*", true, false) as Button
	check(plus != null, "Repère du comparateur sur chaque ligne")
	if plus != null:
		plus.pressed.emit()
		await settle()
		check(app.management_ui.compare.size() == 1 and plus.text == "A" and plus.visible, "Le repère de la ligne ajoute le joueur au comparateur (A)")
	check((app.find_child("OpenComparison", true, false) as Button).text.begins_with("Comparer 1/2"), "Compteur Comparer 1/2")
	await press("OpenComparison")
	check(app.route == "Comparateur" and app.find_child("ImmersiveComparateur", true, false) != null, "Comparer ouvre l'écran Comparateur")
	check(windows(app).is_empty(), "Le comparateur n'est pas une fenêtre")
	check(app.find_child("ComparateurVide1", true, false) != null, "À 1 joueur : emplacement « Choisir un joueur »")
	var choix := app.find_child("ComparateurJoueur1", true, false) as OptionButton
	check(choix != null and choix.item_count > 3, "Sélecteur de joueur par colonne")
	if choix != null:
		choix.item_selected.emit(2)
		await settle(10)
	check(app.management_ui.compare.size() == 2, "Le sélecteur ajoute un second joueur")
	check(app.find_child("RadarDessin", true, false) != null, "Radar dessiné")
	check(app.find_children("RadarAxe?", "Button", true, false).size() == 8, "Huit axes cliquables")
	check(app.find_child("ComparateurJoueur2", true, false) == null, "Deux joueurs au plus : pas de troisième colonne")
	var poste := app.find_child("RadarSynthese0_Auposte", true, false) as Label
	check(poste != null and not poste.text.contains("★"), "Note au poste chiffrée, sans étoiles")
	var chiffre_poste := poste.text.replace("▲", "").strip_edges() if poste != null else ""
	if chiffre_poste.is_valid_int():
		check(poste.get_theme_color("font_color").is_equal_approx(Charte.couleur_attribut(chiffre_poste.to_int())), "Note au poste colorée au barème")
	check(app.find_child("RadarFamiliarite0", true, false) != null, "Emplacement de la familiarité au poste")
	await press("RadarAxe0")
	var fenetre_axe := app.find_child("RadarAxeFenetre", true, false)
	check(fenetre_axe != null and fenetre_axe.find_child("RadarFenetreLigne_tackling", true, false) != null, "Clic sur Défense : ses qualités en barres miroir")
	var echap_fenetre := InputEventKey.new()
	echap_fenetre.keycode = KEY_ESCAPE
	for down in [true, false]:
		echap_fenetre.pressed = down
		Input.parse_input_event(echap_fenetre)
		await process_frame
	await settle(4)
	check(app.route == "Comparateur" and (app.find_child("RadarAxeFenetre", true, false) == null or app.find_child("RadarAxeFenetre", true, false).is_queued_for_deletion()), "Échap ferme d'abord la petite fenêtre")
	await press("RadarSynthese0_Pointfort")
	check(app.find_child("RadarAxeFenetre", true, false) != null, "Clic sur le point fort : petite fenêtre de l'axe")
	var croix := app.find_child("RadarAxeFenetreFermer", true, false) as Button
	if croix != null:
		croix.pressed.emit()
		await settle(4)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	for down in [true, false]:
		escape.pressed = down
		Input.parse_input_event(escape)
		await process_frame
	await settle(10)
	check(app.route == "Effectif", "Échap ramène à l'écran d'origine")
	if app.model.get("epcrPreparation") is Dictionary:
		await press("OpenEpcrPreparation")
		check(app.route == "Préparation Europe" and windows(app).is_empty(), "Préparer l'Europe : un écran, pas une fenêtre")
		await press("EuropeRetour")
		check(app.route == "Effectif", "Retour de la préparation européenne")
	app.management_ui.compare = []
	# Tuile active : marqueur ivoire incliné.
	await press("EffectifTuileIndisponibles")
	check((app.find_child("EffectifTuileIndisponibles", true, false).find_child("EffectifTuileActive", true, false) as Node2D).visible, "Tuile Indisponibles active : marqueur ivoire")
	await press("RosterChip_tous")

	# Fenêtre étroite : même tableau, colonnes retirées, aucun texte sous 12 px.
	root.size = Vector2i(1280, 720)
	await settle(12)
	app._navigate("Effectif")
	await settle(12)
	check(page() != null and app.find_child("Sort_Autres postes", true, false) == null, "1280 : colonne Autres postes retirée")
	check(app.find_child("Sort_Nom", true, false) != null and app.find_child("Sort_Statut", true, false) != null, "1280 : nom et statut conservés")
	var small := 0
	for label: Node in page().find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).get_theme_font_size("font_size") < 12: small += 1
	check(small == 0, "1280 : aucun texte sous 12 px (%d)" % small)
	finish()
