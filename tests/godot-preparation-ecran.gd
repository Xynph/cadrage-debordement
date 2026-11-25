extends SceneTree
## Écran « Préparation » (dossier adverse, revue DA du 19/11/2026) : tout ce qui a l'air cliquable change d'écran ou de
## sous-page, aucune petite fenêtre ouverte par un clic (hors « Préparer la suite » et « La reprise », partagées),
## aucun or hors Continuer, remarque de l'adjoint lue dans le staff. Carrière world-champ préparée par le .cjs.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_PREPARATION_ARTIFACTS")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 12: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func named(id: String) -> Control: return app.body.find_child(id, true, false)

## Fenêtres visibles (AcceptDialog, popup, Window) sous la racine, hors fenêtre principale.
func open_windows() -> Array[String]:
	var found: Array[String] = []
	for node: Node in root.find_children("*", "Window", true, false):
		if (node as Window).visible: found.append(str(node.name))
	return found

func reset() -> void:
	app._clear_dialogs()
	app.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""],"sub":""}
	app._navigate("Bureau")
	await settle()
	app._navigate("Préparation")
	await settle()

## Presse la commande et renvoie un résumé « route|onglet|sous-page » après le clic.
func press(button: Button) -> String:
	button.pressed.emit()
	await settle()
	var prep: Dictionary = app.management_ui.get("preparation", {})
	return "%s|%s|%s" % [app.route, str(prep.get("tab", 0)), str(prep.get("sub", ""))]

func gold_used(node: Node) -> int:
	var count := 0
	for control: Node in node.find_children("*", "Control", true, false):
		# Charte finale : le doré de l'adversaire dans une comparaison (barres du rapport de force) n'est pas une action.
		if str(control.name).begins_with("PreparationBarreAdverse"): continue
		# Charte finale : un texte doré (attention, toujours avec un mot) est permis ; seul l'aplat doré est réservé à Continuer.
		for style_name: String in ["panel", "normal", "hover", "pressed", "focus"]:
			var style := (control as Control).get_theme_stylebox(style_name) as StyleBoxFlat
			if style != null and (style.bg_color.is_equal_approx(Charte.OR) or style.bg_color.is_equal_approx(Charte.OR_VIF) or style.border_color.is_equal_approx(Charte.OR)): count += 1
	return count

func ouvrir_consignes() -> void:
	await reset()
	await press(named("PreparationTabConsignes") as Button)

## Consignes (option A de la revue du 21/11) : chaque tuile a son schéma et ses pastilles, et la tuile entière choisit
## l'intention (vraie commande set_tactics), sans toucher l'autre côté ; aucune phrase d'aide visible.
func consignes_tuiles() -> void:
	await ouvrir_consignes()
	for cote: Array in [["attack", "attacks", "Attack", "defense"], ["defense", "defenses", "Defense", "attack"]]:
		var options: Array = app.model.tactics.get(cote[1], [])
		check(options.size() >= 2, "Intentions disponibles : " + str(cote[0]))
		for option: Dictionary in options:
			await ouvrir_consignes()
			var id := "Preparation%s_%s" % [cote[2], str(option.id)]
			var tuile := named(id) as Button
			check(tuile != null and tuile.has_meta("tactic_id"), "Tuile cliquable " + id)
			check(named("Schema_" + str(option.id)) != null, "Schéma de terrain dessiné pour " + id)
			var parent := tuile.get_parent() if tuile != null else null
			var effets := 0
			if parent != null:
				for enfant: Node in parent.get_children():
					if str(enfant.name).begins_with("Effet_"): effets += 1
			check(effets >= 2, "Au moins deux pastilles d'effet sur " + id)
			if tuile == null or tuile.disabled: continue
			var autre: String = app.model.tactics.get(cote[3])
			tuile.pressed.emit()
			await worker()
			check(str(app.model.tactics.get(cote[0])) == str(option.id) and str(app.model.tactics.get(cote[3])) == autre, "Clic sur %s : intention choisie, l'autre côté conservé" % id)
			check(named("Preparation%s_%s" % [cote[2], str(option.id)]) != null and named("PreparationChoix" + str(cote[2])) != null, "Pastille du choix affichée après " + id)
	var phrases: Array[String] = []
	for label: Node in named("PreparationConsignes").find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text.split(" ").size() >= 7: phrases.append((label as Label).text)
	check(phrases.is_empty(), "Aucune phrase d'aide à l'écran des consignes : " + str(phrases))
	for id in ["PreparationIntentInfoAttack", "PreparationIntentInfoDefense", "PreparationZonesInfo"]:
		check(named(id) != null and not (named(id) as Control).tooltip_text.is_empty(), "Explication rangée dans le « i » " + id)
	var zones := named("PreparationOpenZones") as Button
	if zones != null:
		var resume := await press(zones)
		check(app.route == "Plan de jeu", "Consignes par zone : ouvre le carnet de jeu (%s)" % resume)

## Match en direct : la pastille d'état et « Mettre en pause » tiennent dans l'en-tête, sans chevaucher titre, choix ni « i ».
func consignes_direct() -> void:
	await ouvrir_consignes()
	var page := app.find_child("ImmersivePreparation", true, false)
	check(page != null, "Page de préparation présente")
	if page == null: return
	var contexte = page.match_context
	var faux: Dictionary = app.model.duplicate()
	for etat: Array in [[{"minute": 23, "teams": [], "score": [3, 0]}, "En direct", true], [{"minute": 41, "paused": true}, "En pause", false], [{"minute": 40, "atBreak": true}, "Mi-temps", false]]:
		faux.live = etat[0]
		contexte._on_model_changed(faux)
		var rangee = named("PreparationMatchStateRow")
		rangee.maj()
		await settle()
		var pastille := rangee.find_child("PreparationMatchStatePastille", true, false) as Control
		check(pastille != null and pastille.is_visible_in_tree(), "Pastille d'état « %s » visible" % etat[1])
		var mot: Array = pastille.find_children("*", "Label", true, false) if pastille != null else []
		check(not mot.is_empty() and (mot[0] as Label).text == etat[1], "Mot de l'état : " + str(etat[1]))
		check(pastille != null and not pastille.tooltip_text.is_empty(), "Phrase complète de l'état en infobulle")
		var pause := named("PreparationPauseMatch") as Control
		check(pause.visible == etat[2], "Bouton pause visible seulement en direct (%s)" % etat[1])
		var zones: Array[Control] = [pastille, named("PreparationChoixAttack"), named("PreparationIntentInfoAttack"), named("PreparationAttackScroll")]
		if pause.visible: zones.append(pause)
		var titre := named("PreparationAttack").find_child("CardTitle", true, false) as Control
		if titre != null: zones.append(titre)
		for i in zones.size():
			for j in range(i + 1, zones.size()):
				if zones[i] == null or zones[j] == null: continue
				# Le titre de carte occupe toute la largeur : seule sa partie écrite compte.
				var a := zones[i].get_global_rect()
				var b := zones[j].get_global_rect()
				if zones[i] == titre or zones[j] == titre: continue
				check(not a.grow(-1).intersects(b.grow(-1)), "En-tête en direct sans chevauchement : %s / %s" % [zones[i].name, zones[j].name])
		var carte := named("PreparationAttack") as Control
		check(carte.get_global_rect().grow(1).encloses(pastille.get_global_rect()) and carte.get_global_rect().grow(1).encloses(pause.get_global_rect()), "État et pause dans la carte (%s)" % etat[1])
		if etat[1] == "En direct" and not DisplayServer.get_name() == "headless" and not proof.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(proof.path_join("preparation-consignes-direct-1920.png")) == OK, "Capture des consignes en direct")
	contexte._on_model_changed(app.model)
	named("PreparationMatchStateRow").call("maj")
	await settle()
	check(not (named("PreparationMatchStateRow") as Control).visible and not named("PreparationPauseMatch").visible, "Avant le match : ni état ni pause")

## Plan du staff : intention, lignes du rapport de force et pastilles d'effet mènent toutes quelque part.
func plan_du_staff() -> void:
	await reset()
	await press(named("OpenOppositionDossier") as Button)
	check(named("PreparationAdvice") != null, "Plan du staff ouvert")
	var ids: Array[String] = []
	for pattern in ["PreparationAdviceIntent_*", "PreparationAdviceSector_*", "PreparationAdviceCondition", "PreparationAdviceEffect_*Zone"]:
		for button: Node in app.find_children(pattern, "Button", true, false): ids.append(str(button.name))
	check(ids.filter(func(i: String): return i.begins_with("PreparationAdviceIntent_")).size() == 2, "Deux intentions conseillées cliquables")
	check(ids.filter(func(i: String): return i.begins_with("PreparationAdviceEffect_")).size() >= 4, "Pastilles d'effet du plan cliquables")
	check(ids.filter(func(i: String): return i.begins_with("PreparationAdviceSector_")).size() >= 1, "Barres du rapport de force cliquables")
	for id in ids:
		await reset()
		await press(named("OpenOppositionDossier") as Button)
		var button := named(id) as Button
		if button == null:
			check(false, "Commande retrouvée : " + id)
			continue
		var resume := await press(button)
		check(resume != "Préparation|0|conseils", "« %s » mène ailleurs (%s)" % [id, resume])
		if id.begins_with("PreparationAdviceIntent_") or id.begins_with("PreparationAdviceEffect_"):
			check(resume == "Préparation|1|", "« %s » ouvre l'onglet Consignes (%s)" % [id, resume])
	var phrases: Array[String] = []
	await reset()
	await press(named("OpenOppositionDossier") as Button)
	for label: Node in named("PreparationAdvice").find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text.split(" ").size() >= 7: phrases.append((label as Label).text)
	check(phrases.is_empty(), "Aucune phrase dans le plan du staff : " + str(phrases))
	var adopter := named("AdoptDossierPlan") as Button
	check(adopter != null, "Adopter ce plan présent")
	if adopter != null and not adopter.disabled:
		var conseil: Dictionary = app.model.decisions.preparation.get("advice", {})
		adopter.pressed.emit()
		await worker()
		check(app.model.tactics.attack == conseil.get("attack") and app.model.tactics.defense == conseil.get("defence"), "Adopter ce plan applique les deux intentions")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await worker()
	await command("import", {"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await reset()
	var dossier := named("PreparationDossier")
	check(dossier != null and dossier.is_visible_in_tree(), "Dossier adverse affiché")
	for id in ["PreparationDanger", "PreparationComparison", "PreparationRecommendation", "PreparationRecent", "PreparationThreats"]:
		check(named(id) != null, "Panneau présent : " + id)
	# Leur XV probable arrive par la lecture seule « club_sheet » : on attend la reconstruction.
	for i in 240:
		if not app.find_children("PreparationTheirXIName_*", "Button", true, false).is_empty(): break
		await process_frame
	check(app.find_children("PreparationTheirXIName_*", "Button", true, false).size() == 15, "Leur XV probable : quinze noms cliquables")
	var adjoint := {}
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		for member: Dictionary in team.get("members", []):
			if str(member.get("role", "")) != "assistant": continue
			if team.get("id") == app.model.club.get("id"): adjoint = member
			elif adjoint.is_empty(): adjoint = member
	# Tableau détaillé de leur XV : sous-page avec la colonne « remarque de ton adjoint » et le nom de l'adjoint lu dans le staff.
	var tableau := named("PreparationTheirXIAll") as Button
	check(tableau != null, "Lien vers le tableau détaillé de leur XV")
	if tableau != null:
		if not adjoint.is_empty(): check(tableau.text.contains(str(adjoint.get("name", ""))), "Le nom de l'adjoint est lu dans le staff du club, jamais figé")
		var ouverture := await press(tableau)
		check(ouverture == "Préparation|0|xv" and named("PreparationTheirXITable") != null and open_windows().is_empty(), "Tableau détaillé : sous-page, pas une fenêtre (%s)" % ouverture)
		for i in 240:
			if not app.find_children("PreparationTheirXIName_*", "Button", true, false).is_empty(): break
			await process_frame
		check(app.find_children("PreparationTheirXIName_*", "Button", true, false).size() == 15, "Tableau détaillé : quinze noms cliquables")
		if not adjoint.is_empty(): check(named("PreparationAdjointLink") != null, "Lien vers la fiche de l'adjoint")
		await press(named("PreparationSubBack") as Button)
	# Rapport adverse (idée n° 10 de la revue FM27) : sous-page, XV habituel en maillots sur un terrain, bandes d'où partent
	# les essais, essais par tranche de 10 min ; un maillot ouvre une petite fenêtre (choix de Léo : visuelle), Échap la ferme.
	await reset()
	for i in 240:
		if named("PreparationRapportAdverseLien") != null: break
		await process_frame
	var lien_rapport := named("PreparationRapportAdverseLien") as Button
	check(lien_rapport != null, "Lien vers le rapport adverse")
	if lien_rapport != null:
		var ouverture := await press(lien_rapport)
		check(ouverture == "Préparation|0|adversaire" and open_windows().is_empty(), "Rapport adverse : sous-page, pas une fenêtre (%s)" % ouverture)
		for id in ["RapportAdverseXV", "RapportAdverseZones", "RapportAdverseTemps", "RapportAdverseMatchs", "RapportAdverseClub"]:
			check(named(id) != null, "Rapport adverse : " + id)
		check(app.body.find_children("RapportAdverseMaillot*", "Button", true, false).size() == 15, "Rapport adverse : quinze maillots cliquables")
		check(app.body.find_children("RapportAdverseTranche*", "Button", true, false).size() == 8, "Rapport adverse : huit tranches de 10 min")
		check(gold_used(named("PreparationDossier")) == 0, "Aucun or dans le rapport adverse")
		var maillot := named("RapportAdverseMaillot1") as Button
		if maillot != null:
			maillot.pressed.emit()
			await settle()
			check(named("RapportAdverseFenetre") != null and open_windows().is_empty(), "Maillot : petite fenêtre visuelle dans la page")
			var fermer := InputEventKey.new()
			fermer.keycode = KEY_ESCAPE
			fermer.pressed = true
			Input.parse_input_event(fermer)
			await settle()
			check(str(app.management_ui.preparation.get("sub", "")) == "adversaire", "Échap ferme d'abord la petite fenêtre, pas la sous-page")
		# Points forts / faibles (idée n° 29, option A) : trois colonnes, entraîneur et style, tout cliquable, plus de variante.
		for id in ["AdversaireForcesForts", "AdversaireForcesFaibles", "AdversaireCles", "AdversaireCoach"]:
			check(named(id) != null, "Points forts / faibles : " + id)
		var source_forces := FileAccess.get_file_as_string("res://ui/immersive08/adversaire_forces.gd")
		check(not source_forces.contains("CD_VARIANTE_VISUELLE") and not source_forces.contains("static func _b("), "Variante B et switch retirés")
		var lignes_cles: Array = app.body.find_children("AdversaireCle*", "Panel", true, false).filter(func(n: Node): return str(n.name).trim_prefix("AdversaireCle").is_valid_int())
		check(app.body.find_children("AdversaireCleLien*", "Button", true, false).size() == lignes_cles.size(), "Chaque homme clé ouvre sa fiche")
		var points: Array = app.body.find_children("AdversairePoint*Lien", "Button", true, false)
		for bouton: Button in points:
			if bouton.tooltip_text.begins_with("Ouvrir"): continue
			bouton.pressed.emit()
			await settle()
			check(named("AdversaireForceFenetre") != null and named("AdversaireForceBarreLigue") != null, "Point : petite fenêtre eux / moyenne du championnat")
			PetiteFenetre.fermer_derniere(app.get_tree())
			await settle()
			break
		var style := named("AdversaireCoachStyleLien") as Button
		if style != null:
			style.pressed.emit()
			await settle()
			check(named("AdversaireStyle_conquete") != null, "Style de l'entraîneur : petite fenêtre des quatre styles")
			PetiteFenetre.fermer_derniere(app.get_tree())
			await settle()
		# Petit terrain : habituel / dernier match / probable, un clic change le XV montré.
		for mode in ["dernier", "probable", "habituel"]:
			var pastille := named("RapportAdverseXVModeLien_" + mode) as Button
			check(pastille != null, "Petit terrain : pastille " + mode)
			if pastille == null: continue
			pastille.pressed.emit()
			await settle()
			check(app.body.find_children("RapportAdverseMaillot*", "Button", true, false).filter(func(b): return not b.is_queued_for_deletion()).size() == 15, "Petit terrain %s : quinze maillots" % mode)
		await press(named("PreparationSubBack") as Button)
		check(str(app.management_ui.preparation.get("sub", "")) == "", "Retour du rapport adverse au dossier")
	await reset()
	check(gold_used(named("PreparationDossier")) == 0 and gold_used(named("PreparationTabs")) == 0, "Aucun or dans l'écran (réservé à Continuer)")
	var sector_buttons := app.find_children("PreparationSector_*", "Button", true, false)
	check(sector_buttons.size() >= 1, "Chaque secteur du rapport de force est cliquable")
	var windows_before := open_windows()
	# Rapport de force : chaque ligne change d'écran ou d'onglet.
	for i in sector_buttons.size():
		await reset()
		var button := app.find_children("PreparationSector_*", "Button", true, false)[i] as Button
		var nom := str(button.name)
		var summary := await press(button)
		check(summary != "Préparation|0|", "Ligne du rapport de force « %s » mène ailleurs (%s)" % [nom, summary])
		check(open_windows() == windows_before, "Aucune fenêtre ouverte par « %s » : %s" % [nom, str(open_windows())])
	# Repères : chaque ligne agit sans fenêtre.
	await reset()
	var briefing_ids: Array[String] = []
	for button: Node in app.find_children("PreparationBriefing_*", "Button", true, false): briefing_ids.append(str(button.name))
	check(not briefing_ids.is_empty(), "Repères « À faire avant le match » cliquables")
	for id in briefing_ids:
		await reset()
		var button := named(id) as Button
		if button == null: continue
		var summary := await press(button)
		check(summary != "Préparation|0|" or id == "PreparationBriefing_live", "Repère « %s » mène ailleurs (%s)" % [id, summary])
		check(open_windows() == windows_before, "Aucune fenêtre ouverte par « %s » : %s" % [id, str(open_windows())])
	# Sous-pages : conseils et repères, retour, historique Précédent.
	await reset()
	var conseils := await press(named("OpenOppositionDossier") as Button)
	check(conseils == "Préparation|0|conseils" and named("PreparationAdvice") != null and open_windows() == windows_before, "Conseils détaillés : sous-page, pas une fenêtre")
	check(gold_used(named("PreparationDossier")) == 0, "Aucun or dans les conseils")
	var retour := await press(named("PreparationSubBack") as Button)
	check(retour == "Préparation|0|" and named("PreparationComparison") != null, "Retour au dossier adverse")
	var reperes := await press(named("PreparationBriefingAll") as Button)
	check(reperes == "Préparation|0|reperes" and named("PreparationAllChecks") != null and open_windows() == windows_before, "Tous les repères : sous-page, pas une fenêtre")
	app.navigation_controller._travel(-1)
	await settle()
	check(str(app.management_ui.preparation.get("sub", "")) == "" and named("PreparationComparison") != null, "Précédent revient du sous-écran au dossier")
	# Planning du manager et reprise : sous-pages pleine page (jamais une fenêtre), Échap ramène au dossier.
	for pair: Array in [["PreparationManagerPlanning", "planning", "ManagerPlanning"], ["PreparationReprise", "reprise", "RepriseDialog"]]:
		await reset()
		var lien := named(pair[0]) as Button
		if lien == null: continue
		var resume := await press(lien)
		check(resume == "Préparation|0|" + str(pair[1]) and named(pair[2]) != null and open_windows() == windows_before, "%s : sous-page pleine page (%s)" % [pair[0], resume])
		check(open_windows().is_empty() and app.find_children("*", "AcceptDialog", true, false).filter(func(w: Node): return (w as Window).visible).is_empty(), "Aucune AcceptDialog pour " + str(pair[0]))
		var echap := InputEventKey.new()
		echap.keycode = KEY_ESCAPE
		echap.pressed = true
		Input.parse_input_event(echap)
		await settle()
		check(str(app.management_ui.preparation.get("sub", "")) == "" and named("PreparationComparison") != null, "Échap ferme la sous-page " + str(pair[1]))
	# Mini-fiche d'un joueur adverse : ce que le jeu connaît (poste, âge, club), attributs « — », jamais une fenêtre.
	await reset()
	for i in 240:
		if named("PreparationTheirXIName_1") != null: break
		await process_frame
	var nom1 := named("PreparationTheirXIName_1")
	check(nom1 != null, "Nom du n° 1 adverse présent")
	if nom1 != null:
		var mini = load("res://ui/immersive08/mini_fiche.gd").montrer(app, str(nom1.get_meta("entity_id", "")), "adverse", nom1)
		await settle()
		check(mini != null and is_instance_valid(mini) and mini.find_child("MiniFichePoste", true, false) != null, "Mini-fiche d'un joueur adverse construite avec les données connues")
		if mini != null: load("res://ui/immersive08/mini_fiche.gd").cacher(app)
	# Noms : joueurs surveillés, XV adverse, clubs -> un écran, jamais une fenêtre.
	var noms: Array[String] = []
	for pattern in ["PreparationThreatName*", "PreparationThreatCard*", "PreparationTheirXIName_1", "PreparationTheirXICellZone*", "PreparationOpponentLink", "PreparationTagZone*", "PreparationFormClub", "PreparationFormRow*", "PreparationOpponentFormZone*", "PreparationContextClubOpponent"]:
		for button: Node in app.find_children(pattern, "Button", true, false): noms.append(str(button.name))
	check(noms.size() >= 3, "Noms cliquables : joueurs, XV adverse, clubs (%d)" % noms.size())
	for id in noms:
		await reset()
		var button := named(id) as Button
		if button == null or button.disabled: continue
		var avant: String = app.route
		var summary := await press(button)
		# Joueur adverse (décision de Léo, 25/11) : le clic ouvre SA fiche = le dossier du marché entre clubs (fenêtre), comme
		# depuis l'effectif de la page club ; clubs et autres noms : un écran, jamais une fenêtre.
		var ouvertes := open_windows()
		var dossier := ouvertes.has("ProspectProfile")
		check(dossier or app.route != "Préparation" or avant != app.route, "Nom « %s » ouvre un écran ou le dossier du joueur (%s)" % [id, summary])
		var etrangeres := 0
		for fenetre: String in ouvertes:
			if not (fenetre in windows_before) and not (fenetre in ["InterclubMarket", "ProspectProfile"]): etrangeres += 1
		check(etrangeres == 0 and (ouvertes == windows_before or dossier), "Seul le dossier du joueur ouvre une fenêtre (« %s » : %s)" % [id, str(ouvertes)])
	# Consignes : or interdit aussi, et onglet Entraînement atteignable.
	await reset()
	await press(named("PreparationTabConsignes") as Button)
	check(gold_used(named("PreparationConsignes")) == 0 and gold_used(named("PreparationTabs")) == 0, "Aucun or dans les consignes")
	await consignes_tuiles()
	await consignes_direct()
	await plan_du_staff()
	if not DisplayServer.get_name() == "headless" and not proof.is_empty():
		await reset()
		await settle()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(proof.path_join("preparation-1920.png")) == OK, "Capture du dossier")
	print("PREPARATION_ECRAN ", JSON.stringify({"controles":checks, "failures":failures}))
	app.closing = true
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
