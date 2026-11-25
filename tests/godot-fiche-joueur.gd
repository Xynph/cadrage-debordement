extends SceneTree
# Fiche joueur complète et mini-fiche au survol (décisions de Léo du 19/11/2026), carrière Monde réelle :
# 36 attributs sur la première page, couleur de chaque palier, chiffre toujours écrit, drapeau d'un flagCode connu,
# survol du (i) du nom (0,5 s) = mini-fiche Control (aucune Window), clic sur le nom = fiche complète, attributs inconnus = « — ».
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Identity = preload("res://ui/player_identity.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Carte = preload("res://ui/carte_joueur_survol.gd")
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
	print("FICHE JOUEUR : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

func windows(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children():
		if child is Window and child.visible and not child.is_queued_for_deletion(): found.append(child)
		found.append_array(windows(child))
	return found

func color_of(label: Label) -> Color:
	return label.get_theme_color("font_color")

## Les 36 valeurs d'une grille : chiffre écrit (ou « — » ivoire-3 si inconnu) et couleur du barème.
func check_grid(root: Node, prefix: String, values: Dictionary, label: String) -> void:
	var count := 0
	var good := 0
	for group: Array in PlayerAttributes.GROUPS:
		for pair: Array in group[1]:
			var node := root.find_child(prefix + str(pair[0]), true, false) as Label
			if node == null: continue
			count += 1
			var value: Variant = values.get(pair[0])
			var expected := PlayerAttributes.caption(value)
			if node.text == expected and not node.text.is_empty() and color_of(node).is_equal_approx(Charte.couleur_attribut(value)) and node.is_visible_in_tree(): good += 1
			else: printerr("  ", label, " ", pair[0], " : « ", node.text, " » ", color_of(node), " attendu « ", expected, " »")
	check(count == 36, label + " : 36 attributs affichés (" + str(count) + ")")
	check(good == 36, label + " : chiffre écrit et couleur du barème pour chacun (" + str(good) + "/36)")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()

	# Barème : six paliers, bornes exactes, inconnu en ivoire-3.
	var paliers := {0:Charte.ATTRIBUT_0, 39:Charte.ATTRIBUT_0, 40:Charte.ATTRIBUT_40, 54:Charte.ATTRIBUT_40, 55:Charte.ATTRIBUT_55, 64:Charte.ATTRIBUT_55,
		65:Charte.ATTRIBUT_65, 74:Charte.ATTRIBUT_65, 75:Charte.ATTRIBUT_75, 84:Charte.ATTRIBUT_75, 85:Charte.ATTRIBUT_85, 99:Charte.ATTRIBUT_85}
	for value: int in paliers: check(Charte.couleur_attribut(value) == paliers[value], "Palier de %d" % value)
	check(Charte.couleur_attribut(null) == Charte.IVOIRE_3, "Valeur inconnue : ivoire-3")
	check([Charte.ATTRIBUT_0, Charte.ATTRIBUT_40, Charte.ATTRIBUT_55, Charte.ATTRIBUT_65, Charte.ATTRIBUT_75, Charte.ATTRIBUT_85] == [Color("ee6f5f"), Color("f2a04a"), Color("d4e35c"), Color("a8d878"), Color("4fcb78"), Color("3debb4")], "Jetons exacts du barème")
	check(Identity.flag_texture("fr") != null and Identity.flag_texture("gb-eng") != null, "Drapeaux en couleur chargés pour un flagCode connu")

	app._command("new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"})
	await wait_idle()
	await Flow.settle_club_meetings(app, self, check)
	if is_instance_valid(app.coach): app.coach.close()
	app._navigate("Effectif")
	await settle(10)
	check(app.find_child("PlayerDossier", true, false) == null and app.find_child("SelectedPlayerCard", true, false) == null, "Effectif : plus de fiche fixe à droite")
	var table := app.find_child("ImmersiveRosterTable", true, false) as Control
	# Panneaux XV / SEMAINE / GROUPE à gauche (21/11/2026) : le tableau prend toute la largeur restante.
	var reserve: float = preload("res://ui/immersive08/panneaux_effectif.gd").reserve(app)
	check(table != null and table.size.x >= (2200 - reserve) * preload("res://ui/immersive08/components.gd").density, "Effectif : le tableau prend la largeur restante")

	# Joueur de l'effectif dont le drapeau existe.
	var target: Dictionary = {}
	for player: Dictionary in app.model.squad:
		var facts: Dictionary = player.get("playerFacts", {})
		if Identity.flag_texture(str(facts.get("flagCode", ""))) != null and PlayerAttributes.detail(player, true).size() == 36:
			target = player
			break
	check(not target.is_empty(), "Un joueur de l'effectif avec drapeau et 36 attributs")
	if target.is_empty(): return finish()
	var id := str(target.id)
	var link := app.find_child("SquadOpenPlayer_" + id.validate_node_name(), true, false) as Button
	var scroll := app.find_child("SquadScroll", true, false) as ScrollContainer
	for frame in 30:
		if link != null: break
		await process_frame
		link = app.find_child("SquadOpenPlayer_" + id.validate_node_name(), true, false) as Button
	check(link != null, "Nom cliquable du joueur dans l'effectif")
	if link == null: return finish()
	if scroll != null: scroll.ensure_control_visible(link)
	await settle()
	check(link.tooltip_text.is_empty(), "Nom : pas d'info-bulle système par-dessus la mini-fiche")

	# Survol du nom : carte joueur (demande de Léo du 21/11/2026, même composant que le direct), Control posé dans la
	# coque, aucune fenêtre, entière à l'écran. Le vrai survol à la souris est contrôlé par godot-poste-carte-survol.
	check(link.get_meta("carte_joueur", "") == id, "Survol du nom : carte joueur branchée")
	var noeud: Node = Carte.montrer(app, id, "squad", link)
	await settle(2)
	var mini := noeud as Control
	check(mini != null and not (noeud is Window) and mini.is_visible_in_tree(), "Survol du nom : la carte joueur apparaît (Control)")
	check(windows(app).is_empty() and windows(root).is_empty(), "Survol : aucune fenêtre ouverte")
	if mini != null:
		var screen := Rect2(Vector2.ZERO, app.get_viewport_rect().size)
		check(screen.encloses(mini.get_global_rect()), "Carte joueur entièrement dans l'écran")
		check_grid(mini, "CarteJoueurAttribut_", PlayerAttributes.detail(target, true), "Carte joueur")
		var nom := mini.find_child("CarteJoueurNom", true, false) as Label
		check(nom != null and nom.text == str(target.name).to_upper(), "Carte joueur : nom du joueur")
		check(mini.find_child("CarteJoueurEtat", true, false) != null and mini.find_child("CarteJoueurPolyvalence", true, false) != null, "Carte joueur : état et postes")
	Carte.cacher(app)
	await settle(2)
	check(Carte.actuelle(app) == null, "La souris quitte le nom : la carte disparaît")

	# Le « i » voisin : même carte.
	var info := app.find_child("CarteJoueurInfo_" + id.validate_node_name(), true, false) as Control
	check(info != null and info.get_meta("carte_joueur", "") == id and info.has_meta("carte_info"), "Petit « i » à côté du nom : seul à ouvrir la carte joueur (survol 0,5 s)")
	check(not link.has_meta("carte_info"), "Le nom lui-même n'ouvre rien au survol")

	# Clavier : focus sur le nom + I.
	link.grab_focus()
	var touche := InputEventKey.new()
	touche.keycode = KEY_I
	touche.pressed = true
	link.gui_input.emit(touche)
	await settle(2)
	check(Carte.actuelle(app) != null, "Focus sur le nom + I : carte joueur")
	link.gui_input.emit(touche)
	await settle(2)
	check(Carte.actuelle(app) == null, "I de nouveau : la carte se ferme")

	# Clic sur le nom : route de la fiche complète.
	link.pressed.emit()
	await settle(8)
	var full := app.find_child("ImmersivePlayerFull", true, false) as Control
	check(app.route == "Effectif" and app.get_meta("immersive08_full_player", false) and app.selected_player == id and full != null, "Clic sur le nom : fiche complète du joueur")
	check(Carte.actuelle(app) == null, "Fiche ouverte : plus de carte joueur")
	if full == null: return finish()
	check(full.find_child("FullPlayerTab1", true, false) == null and full.find_child("FullPlayerTab0", true, false) != null, "Plus d'onglet Attributs : Vue d'ensemble en premier")
	check_grid(full, "PlayerDetailedAttribute_", PlayerAttributes.detail(target, true), "Fiche complète, première page")
	check(full.find_child("LegendeBaremeAttributs", true, false) != null, "Fiche complète : légende du barème")
	for i in 4:
		var moyenne := full.find_child("PlayerDetailedAttributeMoyenne" + str(i), true, false) as Label
		check(moyenne != null and color_of(moyenne).is_equal_approx(Charte.couleur_attribut(int(moyenne.text))), "Moyenne colorée de la famille " + str(i))
	var flag := full.find_child("PlayerOriginFlag", true, false) as TextureRect
	check(flag != null and flag.texture != null, "Bandeau : drapeau du pays chargé")
	var heading := full.find_child("ProfilePlayerName", true, false) as Label
	check(heading != null and heading.text == str(target.name).to_upper(), "Bandeau : nom du joueur")
	# Agent nommé (retour de Léo du 23/11/2026) : « Agent : <nom> » dans le bandeau, clic = sa petite fenêtre.
	var agent_lien := full.find_child("PlayerAgentLink", true, false) as Button
	check(agent_lien != null and agent_lien.text.begins_with("Agent : ") and agent_lien.text.length() > 9, "Bandeau : « Agent : <nom> » cliquable")
	if agent_lien != null:
		agent_lien.pressed.emit()
		await settle(4)
		check(app.find_child("FenetreAgentJoueur", true, false) != null and app.find_child("FenetreAgentClientVise", true, false) != null and windows(app).is_empty(), "Clic sur l'agent : petite fenêtre (Control), joueur surligné")
		preload("res://ui/petite_fenetre.gd").fermer_derniere(self)
		await settle(4)
	check(windows(app).is_empty(), "Fiche complète : aucune fenêtre")

	# Apprendre un poste (choix de Léo du 23/11/2026) : clic = petite fenêtre des postes, un clic sur un poste l'applique
	# (sans Valider), re-clic sur la cible ou ✕ arrête ; ni poste principal ni 1re ligne non qualifiée dans la liste.
	var apprendre := full.find_child("PlayerLearnPosition", true, false) as Button
	check(apprendre != null and (apprendre.find_child("PlayerLearnPositionTexte", true, false) as Label).text == "Apprendre un poste", "Apprendre un poste : bouton sans cible")
	if apprendre != null:
		apprendre.pressed.emit()
		await settle(4)
		var fenetre := app.find_child("ApprendrePosteFenetre", true, false) as Control
		check(fenetre != null and windows(app).is_empty(), "Apprendre un poste : petite fenêtre (Control, pas de fenêtre système)")
		var principaux: Array = target.get("primaryPositions", [])
		var lignes := 0
		var premier := 0
		for n in range(1, 16):
			var l := app.find_child("ApprendrePoste_%d" % n, true, false)
			if l != null:
				lignes += 1
				if premier == 0 and n > 3: premier = n
				check(not (n in principaux), "Apprendre : pas le poste principal %d" % n)
		check(lignes >= 10 and premier > 0, "Apprendre : postes proposés (%d)" % lignes)
		var ligne := app.find_child("ApprendrePoste_%d" % premier, true, false) as Button
		if ligne != null:
			ligne.pressed.emit()
			await wait_idle()
			await settle(6)
			var joueur: Dictionary = {}
			for p: Dictionary in app.model.squad:
				if str(p.id) == id: joueur = p
			check(int(joueur.get("positionLearning", 0)) == premier, "Clic sur un poste : appliqué au moteur sans Valider")
			check(app.find_child("ApprendrePosteFenetre", true, false) == null or not (app.find_child("ApprendrePosteFenetre", true, false) as Control).is_visible_in_tree(), "Clic sur un poste : la fenêtre se ferme")
			var texte := app.find_child("PlayerLearnPositionTexte", true, false) as Label
			check(texte != null and texte.text == "Apprendre un poste : %d · %s" % [premier, preload("res://ui/immersive08/liste_etoiles.gd").nom_poste(premier)], "Cible affichée sur la fiche")
			# Re-clic sur la cible dans la fenêtre : arrêt.
			(app.find_child("PlayerLearnPosition", true, false) as Button).pressed.emit()
			await settle(4)
			(app.find_child("ApprendrePoste_%d" % premier, true, false) as Button).pressed.emit()
			await wait_idle()
			await settle(6)
			for p: Dictionary in app.model.squad:
				if str(p.id) == id: joueur = p
			check(joueur.get("positionLearning") == null, "Re-clic sur la cible : arrêt")
			# ✕ sur la fiche : arrêt.
			(app.find_child("PlayerLearnPosition", true, false) as Button).pressed.emit()
			await settle(4)
			(app.find_child("ApprendrePoste_%d" % premier, true, false) as Button).pressed.emit()
			await wait_idle()
			await settle(6)
			var arret := app.find_child("PlayerLearnPositionStop", true, false) as Button
			check(arret != null, "✕ à côté de la cible")
			if arret != null:
				arret.pressed.emit()
				await wait_idle()
				await settle(6)
				for p: Dictionary in app.model.squad:
					if str(p.id) == id: joueur = p
				check(joueur.get("positionLearning") == null and app.find_child("PlayerLearnPositionStop", true, false) == null, "✕ : arrêt")
		full = app.find_child("ImmersivePlayerFull", true, false) as Control

	# Joueur suivant (liste d'origine), puis Échap.
	var ids := Commune.liste(app, "squad")
	var rang := ids.find(id)
	var suivant := app.find_child("FicheSuivant", true, false) as Button
	check(suivant != null and rang >= 0, "Barre : joueur suivant")
	if suivant != null and rang >= 0 and rang < ids.size() - 1:
		suivant.pressed.emit()
		await settle(8)
		check(app.selected_player == ids[rang + 1] and app.find_child("ImmersivePlayerFull", true, false) != null, "Joueur suivant de la liste d'origine")
	var retour := app.find_child("PlayerBackToSquad", true, false) as Button
	retour.pressed.emit()
	await settle(6)
	check(not app.get_meta("immersive08_full_player", false) and app.route == "Effectif", "Retour à l'effectif")

	# Piste du marché aux attributs inconnus : « — » en ivoire-3, phrase d'observation, fiche complète au clic.
	var piste: Dictionary = {}
	for player: Dictionary in app.model.get("market", []):
		if Commune.valeurs(player, "market").is_empty():
			piste = player
			break
	check(not piste.is_empty(), "Une piste du marché aux attributs inconnus")
	if not piste.is_empty():
		check(app.navigation_controller.open_entity({"kind":"market", "id":str(piste.id)}), "Lien de la piste disponible")
		await settle(10)
		var page := app.find_child("ImmersivePlayerFull", true, false) as Control
		check(app.route == "Recrutement" and page != null and page.get_meta("fiche_source", "") == "market", "Piste : fiche complète dans Recrutement")
		if page != null:
			check_grid(page, "PlayerDetailedAttribute_", {}, "Piste inconnue")
			var observe := page.find_child("PlayerObserveAttributes", true, false) as Button
			check(observe != null and observe.text == "Fais-le observer pour connaître ses attributs", "Phrase cliquable « Fais-le observer… »")
		var back := app.find_child("PlayerBackToSquad", true, false) as Button
		if back != null:
			back.pressed.emit()
			await settle(10)
		check(app.route == "Recrutement" and app.find_child("ImmersivePlayerFull", true, false) == null, "Retour à la liste du recrutement")
		var nom_piste := app.find_child("MarketEntity_" + str(piste.id).validate_node_name(), true, false) as Button
		if nom_piste != null:
			var mini_piste := Carte.montrer(app, str(piste.id), "market", nom_piste)
			await settle(2)
			check(mini_piste != null and nom_piste.has_meta("carte_joueur"), "Recrutement : survol du nom = carte joueur")
			if mini_piste != null: check_grid(mini_piste, "CarteJoueurAttribut_", {}, "Carte d'une piste inconnue")
			Carte.cacher(app)
			await settle(2)
	finish()
