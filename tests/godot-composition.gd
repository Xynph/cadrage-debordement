extends SceneTree
# Écran Composition (choix de Léo du 19/11/2026 : variante 1 « Terrain au centre, candidats dessous » + encart
# « Première ligne formée » de la variante 3), carrière Monde réelle, vrai moteur :
#  - tout ce qui a l'air cliquable change d'écran, de poste, de tri ou envoie une commande ; aucune Window ouverte ;
#  - aucune couleur or dans l'écran (l'or est réservé à Continuer, dans la coque) ;
#  - terrain aux proportions réelles, candidats dessous, encart première ligne sur les n° 1-3 / 16-18 ;
#  - clavier : Espace prend puis pose (échange réel), Échap annule ; clic sur un nom = fiche, survol = mini-fiche ;
#  - sous-page « Tireurs et lanceur » avec retour, Échap et historique.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
var Selection = load("res://ui/immersive08/tactics_selection.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
var sortie := OS.get_environment("CD_COMPOSITION_OUTPUT")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func settle(frames := 8) -> void:
	for frame in frames: await process_frame

func wait_idle(limit_ms := 240000) -> void:
	var until := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func finish() -> void:
	print("COMPOSITION : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func named(id: String) -> Control:
	return app.root_content.find_child(id, true, false) as Control

func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found

func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless" or sortie.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie.path_join(id + ".png"))

func key(code: Key, shift := false, ctrl := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		root.push_input(event, true)
		await process_frame
	await settle()

func composition() -> void:
	app._navigate("Composition")
	await settle(10)

func proche_de_l_or(couleur: Color) -> bool:
	return couleur.a > .05 and (Color(couleur, 1).is_equal_approx(Charte.OR) or Color(couleur, 1).is_equal_approx(Charte.OR_VIF))

## Toutes les couleurs posées par l'écran : textes, boutons, panneaux, traits, ovales et marqueurs dessinés.
func couleurs_or(node: Node) -> Array[String]:
	var found: Array[String] = []
	if node is Control:
		var control := node as Control
		for nom in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			if control.has_theme_color_override(nom) and proche_de_l_or(control.get_theme_color(nom)): found.append(str(control.name) + "/" + nom)
		for nom in ["panel", "normal", "hover", "pressed", "focus"]:
			if control.has_theme_stylebox_override(nom):
				var style := control.get_theme_stylebox(nom) as StyleBoxFlat
				if style != null and (proche_de_l_or(style.bg_color) or proche_de_l_or(style.border_color)): found.append(str(control.name) + "/" + nom)
		for propriete in ["fond", "bordure", "couleur", "color"]:
			var valeur: Variant = control.get(propriete)
			if valeur is Color and proche_de_l_or(valeur): found.append(str(control.name) + "/" + propriete)
	for child in node.get_children(): found.append_array(couleurs_or(child))
	return found

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
	await composition()

	# 1. Disposition de la variante 1.
	var page := named("ImmersiveTactics")
	check(page != null, "Écran Composition construit")
	if page == null: finish(); return
	check(named("TacticsOutside") == null and named("TacticsIdentity") == null and named("Art_tactics_briefing") == null, "Plus d'ancienne composition (hors groupe, identité de jeu, bandeau photo)")
	var pitch := named("TacticsPitch")
	var bench := named("TacticsBench")
	var impact := named("TacticsImpact")
	var under := named("TacticsCandidates")
	check(pitch != null and bench != null and impact != null and under != null, "Terrain, banc, impact et candidats")
	if pitch != null and bench != null and impact != null and under != null:
		var rp := pitch.get_global_rect()
		check(absf(rp.size.x / rp.size.y - 100.0 / 70.0) < .02, "Terrain aux proportions réelles (100 × 70, charte §6)")
		check(rp.end.x <= bench.get_global_rect().position.x + 1 and bench.get_global_rect().end.x <= impact.get_global_rect().position.x + 1, "Terrain, banc, impact de gauche à droite")
		check(under.get_global_rect().position.y >= rp.end.y - 1, "Candidats sous le terrain")
		for i in 15:
			var carte := named("LineupSlot%02d" % (i + 1))
			check(carte != null and rp.encloses(carte.get_global_rect()), "Carte du n° %d dans le terrain" % (i + 1))
	check(named("BenchPlayerRows") != null and named("BenchPlayerRows").get_child_count() == 8, "Banc : huit places")
	var bar: VScrollBar = (app.body_scroll as ScrollContainer).get_v_scroll_bar()
	check(bar.max_value <= bar.page + 1, "1920 × 1080 : l'écran tient sans défiler (%s / %s)" % [str(bar.max_value), str(bar.page)])
	check(couleurs_or(page).is_empty(), "Aucune couleur or dans l'écran : " + ", ".join(couleurs_or(page)))
	# Charte §3 « rayons 0 » : les fonds sont créés sans rayon (C.rayon_nul), plus de passe après coup sur l'écran.
	var arrondis: Array[String] = []
	# Nœuds internes du moteur exclus (« _focus » du ScrollContainer : style du thème, cadre non dessiné ici).
	for noeud in page.find_children("*", "Control", true, false):
		if str(noeud.name).begins_with("_"): continue
		for nom in ["panel", "normal", "hover", "pressed", "hover_pressed", "disabled", "focus", "read_only"]:
			if not (noeud as Control).has_theme_stylebox_override(nom): continue
			var style := (noeud as Control).get_theme_stylebox(nom) as StyleBoxFlat
			if style != null and (style.corner_radius_top_left > 0 or style.corner_radius_bottom_right > 0): arrondis.append(str(noeud.name) + "/" + nom)
	check(arrondis.is_empty(), "Angles droits partout dans l'écran (charte §3) : " + ", ".join(arrondis.slice(0, 6)))
	# Tout bouton visible fait quelque chose (pressed relié), sauf cases et listes qui ont leur propre signal.
	var muets: Array[String] = []
	for node in page.find_children("*", "BaseButton", true, false):
		var bouton := node as BaseButton
		if bouton is CheckBox or bouton is OptionButton or bouton is MenuButton or not bouton.is_visible_in_tree(): continue
		if bouton.pressed.get_connections().is_empty(): muets.append(str(bouton.name))
	check(muets.is_empty(), "Aucune zone cliquable sans effet : " + ", ".join(muets))
	await capture("composition-1920")

	# 2. Choisir des postes : terrain, banc, doublures ; candidats dessous, sans fenêtre.
	for numero in [5, 12, 19]:
		(named("LineupSlot%02d" % numero) as Button).pressed.emit()
		await settle()
		check(app.selected_slot == numero - 1 and str((named("TacticsCandidatesTitle") as Label).text).contains("N° %d" % numero), "Poste n° %d : ses candidats dessous" % numero)
	(named("TacticsDepth07") as Button).pressed.emit()
	await settle()
	check(app.selected_slot == 6, "Case des doublures du n° 7 : choisit le poste")
	check(windows(app).is_empty(), "Aucune fenêtre ouverte par le choix d'un poste")

	# 3. Encart « Première ligne formée » (emprunt de la variante 3) sur le n° 16, absent sur le n° 7.
	check(named("TacticsFrontRowRule") == null, "Pas d'encart première ligne sur le n° 7")
	(named("LineupSlot16") as Button).pressed.emit()
	await settle()
	var encart := named("TacticsFrontRowRule")
	check(encart != null, "Encart première ligne sur le n° 16")
	if encart != null:
		var lecture: Dictionary = Selection.premiere_ligne(app.model)
		var titre := named("TacticsFrontRowTitle") as Label
		check(titre != null and titre.text.contains("%d/6" % mini(int(lecture.formes), 6)), "Encart : nombre de formés lu sur la feuille (%s)" % (titre.text if titre != null else ""))
		var phrase := named("TacticsFrontRowSentence") as Label
		check(phrase != null and phrase.text.begins_with("Loi 3"), "Encart : la règle de la loi 3 en une phrase")
		await capture("composition-premiere-ligne-1920")

	# 4. Candidats : tri, filtre, non qualifié grisé avec sa raison, affectation réelle.
	(named("LineupSlot10") as Button).pressed.emit()
	await settle()
	(named("CandidateSort_condition") as Button).pressed.emit()
	await settle()
	check(app.management_ui.candidates_reading.key == "condition", "Tri des candidats par condition")
	(named("CandidateSort_note") as Button).pressed.emit()
	await settle()
	var lignes := named("TacticsCandidateRows")
	var eligibles: Array = Selection.slot(app.model, 9).get("eligibleIds", [])
	var hors_groupe := ""
	for ligne in (lignes.get_children() if lignes != null else []):
		if not ligne is Button: continue
		var id := str(ligne.get_meta("player_id", ""))
		if id in eligibles and Selection.source(app.model, id) < 0 and hors_groupe.is_empty(): hors_groupe = id
	# Le moteur ne restreint par qualification que la première ligne (loi 3) : un non qualifié se cherche au n° 1.
	(named("LineupSlot01") as Button).pressed.emit()
	await settle()
	var pilier: Array = Selection.slot(app.model, 0).get("eligibleIds", [])
	var non_qualifie: Button = null
	for ligne in named("TacticsCandidateRows").get_children():
		if ligne is Button and str(ligne.get_meta("player_id", "")) not in pilier:
			non_qualifie = ligne
			var statut := ligne.find_child("TacticsCandidateStatus", true, false) as Label
			check(statut != null and not statut.text.is_empty(), "Non qualifié : raison écrite dans la ligne (%s)" % (statut.text if statut != null else ""))
			break
	check(non_qualifie != null, "Un non qualifié au n° 1 reste visible dans la liste")
	if non_qualifie != null:
		var avant: Dictionary = app.model.selection.duplicate(true)
		non_qualifie.pressed.emit()
		await settle()
		var message := named("TacticsCandidateMessage") as Label
		check(message != null and message.text.contains("ne peut pas"), "Non qualifié : la raison est écrite, rien n'est affecté")
		check(app.model.selection == avant and not app.waiting, "Non qualifié : aucune commande envoyée")
	check(not hors_groupe.is_empty(), "Un joueur hors groupe qualifié au n° 10")
	if not hors_groupe.is_empty():
		var entrant := hors_groupe
		(named("LineupSlot10") as Button).pressed.emit()
		await settle()
		var ligne_entrant := named("TacticsCandidate_" + entrant.validate_node_name()) as Button
		check(ligne_entrant != null, "Le candidat hors groupe est dans la liste du n° 10")
		if ligne_entrant != null: ligne_entrant.pressed.emit()
		await wait_idle()
		check(app.bridge.last_response_ok and str(Selection.slot(app.model, 9).get("playerId")) == entrant, "Choisir un candidat : affectation réelle par le moteur")
	check(windows(app).is_empty(), "Affectation sans fenêtre")

	# 5. Clavier : Espace prend le n° 11, flèches / focus sur le n° 14, Espace pose → échange réel ; Échap annule.
	await composition()
	var onze := str(Selection.slot(app.model, 10).get("playerId"))
	var quatorze := str(Selection.slot(app.model, 13).get("playerId"))
	named("LineupSlot11").grab_focus()
	await settle()
	await key(KEY_SPACE)
	check(app.management_ui.tactics_reading.get("pris") is Dictionary and named("TacticsPris11") != null, "Espace : le n° 11 est pris")
	check(named("TacticsCible14") != null, "Destination compatible soulignée (n° 14)")
	named("LineupSlot11").grab_focus()
	await settle()
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	await key(KEY_ESCAPE)
	check(not app.management_ui.tactics_reading.has("pris") and app.route == "Composition", "Échap annule le « pris » sans quitter l'écran")
	named("LineupSlot11").grab_focus()
	await settle()
	await key(KEY_SPACE)
	named("LineupSlot14").grab_focus()
	await settle()
	await key(KEY_SPACE)
	await wait_idle()
	check(str(Selection.slot(app.model, 13).get("playerId")) == onze and str(Selection.slot(app.model, 10).get("playerId")) == quatorze, "Espace / Espace : échange réel des n° 11 et 14")

	# 6. Noms : survol = mini-fiche (Control, aucune fenêtre), clic = fiche complète.
	await composition()
	var nom := named("TacticsName02") as Button
	check(nom != null, "Nom du n° 2 cliquable")
	if nom != null:
		nom.mouse_entered.emit()
		await settle()
		var mini := MiniFiche.actuelle(app)
		check(mini != null and windows(app).is_empty(), "Survol du nom : mini-fiche sans fenêtre")
		nom.mouse_exited.emit()
		await settle()
		var id := str(Selection.slot(app.model, 1).get("playerId"))
		nom.pressed.emit()
		await settle()
		check(app.route == "Effectif" and app.get_meta("immersive08_full_player", false) and app.selected_player == id, "Clic sur le nom : fiche complète")

	# 7. Onglets et liens : chacun change d'écran.
	for paire: Array in [["TacticsTab1", "Préparation"], ["TacticsTab2", "Plan de jeu"], ["TacticsPlanModify", "Préparation"], ["TacticsOpponentFile", "Préparation"]]:
		await composition()
		var lien := named(paire[0]) as Button
		check(lien != null, "Présent : " + str(paire[0]))
		if lien == null: continue
		lien.pressed.emit()
		await settle()
		check(app.route == paire[1], "%s ouvre %s" % [paire[0], paire[1]])
	await composition()
	(named("TacticsTab4") as Button).pressed.emit()
	await settle()
	check(app.Immersive._is_training(app), "Onglet Entraînement")
	await composition()
	(named("BenchSort_name") as Button).pressed.emit()
	await settle()
	check(app.management_ui.bench_reading.key == "name", "Tri du banc par nom")

	# 8. Sous-page « Tireurs et lanceur » : retour, Échap, historique Précédent / Suivant.
	await composition()
	var roles := named("LineupRoles") as Button
	if roles != null:
		roles.pressed.emit()
		await settle()
		check(named("CompositionSubpage_roles") != null and named("TacticsRoles") != null and windows(app).is_empty(), "Tireurs et lanceur : sous-page, pas de fenêtre")
		await capture("composition-tireurs-1920")
		if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
		await key(KEY_ESCAPE)
		check(named("CompositionSubpage_roles") == null and named("TacticsPitch") != null, "Échap revient à la composition")
		app.navigation_controller._travel(-1)
		await settle()
		check(named("CompositionSubpage_roles") != null, "Précédent rouvre la sous-page")
		app.navigation_controller._travel(1)
		await settle()
		check(named("TacticsPitch") != null, "Suivant revient à la composition")
	else:
		check(Selection == null or app.model.get("tactics", {}).get("roles") == null, "Tireurs et lanceur absents seulement sans projection du moteur")

	# 8 bis. Relecture du 19/11 : noms de Vigilance et de la bulle de Gabi cliquables (fiche + mini-fiche), duels vers
	# le dossier adverse, avertissements en menu déroulant, « Libérer » avec confirmation, charge individuelle en sous-page.
	await composition()
	var sous_80 := 0
	for index in 23:
		var forme: Variant = Selection.occupant(app.model, index).get("condition")
		if (forme is int or forme is float) and float(forme) < 80: sous_80 += 1
	if sous_80 > 0:
		var noms_vigilance := named("TacticsVigilance").find_children("*Nom*", "Button", true, false)
		check(not noms_vigilance.is_empty(), "Vigilance : noms cliquables")
		for bouton in noms_vigilance: check(bouton.has_meta("mini_fiche_joueur") and not str((bouton as Button).text).ends_with("…"), "Vigilance : mini-fiche et nom entier · " + (bouton as Button).text)
		check(named("TacticsWarnings") is MenuButton and (named("TacticsWarnings") as MenuButton).get_popup().item_count == sous_80, "Avertissements : menu déroulant de %d joueurs" % sous_80)
		check(named("TacticsWarningName") != null and named("TacticsWarningName").has_meta("mini_fiche_joueur"), "Ligne de validité : nom du premier avertissement → fiche + mini-fiche")
	var conseil := named("TacticsStaffAdvice0")
	if conseil != null: check(not conseil.find_children("*Nom*", "Button", true, false).is_empty(), "Bulle de Gabi : noms cliquables")
	var duel := named("TacticsDuel_scrum") as Button
	if duel != null:
		duel.pressed.emit()
		await settle()
		check(app.route == "Préparation", "Duel « Mêlée » : ouvre le dossier adverse")
		await composition()
	check(named("TacticsFrontRowName01") == null or named("TacticsFrontRowName01").has_meta("mini_fiche_joueur"), "Encart : noms → fiche + mini-fiche")
	(named("LineupSlot03") as Button).pressed.emit()
	await settle()
	var titulaire := str(Selection.slot(app.model, 2).get("playerId"))
	(named("TacticsCandidate_" + titulaire.validate_node_name()) as Button).pressed.emit()
	await settle()
	check(str(Selection.slot(app.model, 2).get("playerId")) == titulaire and not app.waiting, "Clic sur la ligne du titulaire : rien n'est libéré")
	var liberer := named("LineupRemove") as Button
	check(liberer != null, "Lien « Libérer » du titulaire")
	if liberer != null:
		liberer.pressed.emit()
		await settle()
		var confirmation := app.get_node_or_null("LineupReleaseConfirm") as ConfirmationDialog
		check(confirmation != null and confirmation.visible and confirmation.get_ok_button().text == "LIBÉRER", "« Libérer » demande confirmation")
		if confirmation != null: confirmation.get_cancel_button().pressed.emit()
		await settle()
		check(str(Selection.slot(app.model, 2).get("playerId")) == titulaire, "Annuler : le titulaire reste")
	var lien_nom := named("TacticsName04") as Button
	if lien_nom != null:
		app.management_ui.immersive_player_tab = 0
		lien_nom.pressed.emit()
		await settle()
		var charge := named("PlayerLoad") as Button
		check(charge != null, "Fiche : « Régler la charge individuelle »")
		if charge != null:
			charge.pressed.emit()
			await settle()
			check(named("FicheChargePage") != null and named("IndividualLoad_repos") != null and windows(app).is_empty(), "Charge individuelle : sous-page de la fiche, sans fenêtre")
			if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
			await key(KEY_ESCAPE)
			check(named("FicheChargePage") == null and named("PlayerLoad") != null, "Échap revient à la fiche")
			app.navigation_controller._travel(-1)
			await settle()
			check(named("FicheChargePage") != null, "Précédent rouvre la sous-page de charge")

	# 9. Proposition du staff (commande réelle), puis Valider la feuille (Ctrl+Entrée) → préparation.
	await composition()
	(named("LineupAutomatic") as Button).pressed.emit()
	await wait_idle()
	check(app.bridge.last_response_ok and app.last_command == "auto_lineup", "Proposition du staff : commande réelle")
	await composition()
	var valider := named("TacticsValidate") as Button
	check(valider != null, "Bouton Valider la feuille")
	if valider != null:
		check(valider.disabled == not bool(app.model.selection.get("valid", false)), "Valider la feuille suit la validité du moteur")
		if not valider.disabled:
			named("LineupSlot03").grab_focus()
			await settle()
			await key(KEY_ENTER, false, true)
			check(app.route == "Préparation", "Ctrl+Entrée valide la feuille et ouvre la préparation")
	check(windows(app).is_empty(), "Aucune fenêtre ouverte pendant tout le parcours")

	# 10. 1280 × 720 : écran entier, texte jamais sous 12 px réels.
	root.size = Vector2i(1280, 720)
	await settle(4)
	await composition()
	var petits: Array[String] = []
	for node in named("ImmersiveTactics").find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_visible_in_tree() or label.text.strip_edges().is_empty(): continue
		var taille := label.get_theme_font_size("font_size") * label.get_global_transform_with_canvas().get_scale().y
		if taille < 11.4: petits.append("%s (%.1f px)" % [label.text.left(20), taille])
	check(petits.is_empty(), "1280 × 720 : aucun texte sous 12 px : " + ", ".join(petits.slice(0, 6)))
	await capture("composition-1280")
	finish()
