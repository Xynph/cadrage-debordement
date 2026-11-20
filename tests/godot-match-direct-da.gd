extends SceneTree
## Écran 13 « Match en direct » dans le vrai jeu (godot-match-direct-da.cjs prépare la carrière Monde).
## Décisions contrôlées : variante 1 « Bandeau d'angle » (charte §7), bannière d'essai à la couleur du club,
## menu du match par Échap (seule petite fenêtre permise), plaques → fiche du club sans casser le match,
## noms de nos joueurs liés dans le journal, aucun or, aucune fenêtre ouverte par un clic.
const Charte = preload("res://ui/charte.gd")
const LiveView = preload("res://ui/contextual/live_view.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Base = preload("res://ui/game_skin.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_MATCH_DIRECT_DA_ARTIFACTS")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(3)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()

func surface() -> Control:
	return app.contextual_director.view if app.contextual_director.active() and app.contextual_director.kind == "live" else null

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

## Or de Continuer (et ancien or des skins) : interdit dans l'écran.
func dore(c: Color) -> bool:
	for o: Color in [Charte.OR, Charte.OR_VIF, Base.GOLD, Color("e0b35a")]:
		if c.a > 0.05 and absf(c.r - o.r) + absf(c.g - o.g) + absf(c.b - o.b) < 0.12: return true
	return false

func ors(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	var noeuds: Array = [racine]
	noeuds.append_array(racine.find_children("*", "Control", true, false))
	for n: Variant in noeuds:
		var c := n as Control
		if c == null: continue
		for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "default_color"]:
			if c.has_theme_color_override(cle) and dore(c.get_theme_color(cle)): trouves.append("%s.%s" % [c.name, cle])
		for cle in ["panel", "normal", "hover", "pressed", "focus"]:
			if not c.has_theme_stylebox_override(cle): continue
			var s := c.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null and (dore(s.bg_color) or (s.border_width_bottom + s.border_width_top + s.border_width_left > 0 and dore(s.border_color))): trouves.append("%s.%s" % [c.name, cle])
		if c is ColorRect and dore((c as ColorRect).color): trouves.append(str(c.name))
		if c.has_meta("fond") and c.get_meta("fond") is Color and dore(c.get_meta("fond")): trouves.append(str(c.name) + ".fond")
	return trouves

## Boutons actifs d'une page du direct qui mènent hors du match (hors onglets, tri, suivi) : doivent être grisés.
func actifs_hors_place(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in racine.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.disabled or not b.is_visible_in_tree(): continue
		if LiveView.ACTIONS_SUR_PLACE.any(func(p: String) -> bool: return str(b.name).begins_with(p)): continue
		# Nom d'un de nos joueurs : reste actif, ouvre sa fiche dans le direct (contrôlé à part).
		if b.has_meta("fiche_en_match"): continue
		trouves.append(str(b.name))
	return trouves

## Styles arrondis (charte §3 : rayons 0) sous `racine`.
func arrondis(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	var noeuds: Array = [racine]
	noeuds.append_array(racine.find_children("*", "Control", true, false))
	for n: Variant in noeuds:
		var c := n as Control
		if c == null: continue
		for cle in ["panel", "normal", "hover", "pressed", "focus", "disabled"]:
			if not c.has_theme_stylebox_override(cle): continue
			var s := c.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null and s.corner_radius_top_left + s.corner_radius_top_right + s.corner_radius_bottom_left + s.corner_radius_bottom_right > 0: trouves.append("%s<%s.%s" % [c.name, c.get_parent().name if c.get_parent() != null else "", cle])
	return trouves

## Styles à cadre complet (quatre côtés) sous `racine`, hors focus (indicateur de focus accepté).
func cadres_complets(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	var noeuds: Array = [racine]
	noeuds.append_array(racine.find_children("*", "Control", true, false))
	for n: Variant in noeuds:
		var c := n as Control
		if c == null: continue
		for cle in ["panel", "normal", "hover", "pressed", "disabled"]:
			if not c.has_theme_stylebox_override(cle): continue
			var s := c.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null and s.border_color.a > 0.0 and s.border_width_left > 0 and s.border_width_right > 0 and s.border_width_top > 0 and s.border_width_bottom > 0: trouves.append("%s.%s" % [c.name, cle])
	return trouves

## Boutons actifs et visibles sans aucune action branchée.
func muets(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in racine.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.disabled or not b.is_visible_in_tree() or b is OptionButton or b is MenuButton or b is CheckBox or b is CheckButton: continue
		if b.get_signal_connection_list("pressed").is_empty() and b.get_signal_connection_list("toggled").is_empty(): trouves.append(str(b.name))
	return trouves

func fenetres() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Window) -> bool: return w.visible)

func touche(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var relache: InputEventKey = ev.duplicate()
	relache.pressed = false
	root.push_input(relache)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("monde.json"))})
	await command("begin_match")
	var limite := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < limite and (surface() == null or surface().regie == null):
		var scene: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
		if scene is Dictionary and not app.waiting: await command("match_talk_continue", {"key": scene.key, "phase": scene.phase, "skip": true})
		await settle(2)
	var view := surface()
	check(view != null and view.regie != null, "Le direct en temps forts s'ouvre")
	if view == null or view.regie == null:
		finir()
		return
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	# Un premier fait écrit : le journal se remplit.
	await until(func(): return not view.journal_affiche().is_empty(), 90000)
	await settle(4)
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))

	# 1. Bandeau d'angle : en haut à gauche, petit, plaques à la couleur des clubs, score ivoire 40 px.
	var bandeau: Control = view.get("_coque_score")
	var r := bandeau.get_global_rect()
	check(r.position.x <= 48 and r.position.y <= 48 and r.size.y <= 1080 * 0.08 and r.size.x <= 1920 * 0.5, "Bandeau du score en haut à gauche, petit : " + str(r))
	check(view.score.get_theme_font_size("font_size") == 40 and view.score.get_theme_color("font_color") == Charte.IVOIRE, "Score ivoire 40 px en 1080p")
	check(view.plaques.size() == 2 and view.plaques.all(func(p: Control) -> bool: return Charte.contraste(Charte.IVOIRE, p.get_meta("fond")) >= 4.5), "Plaques des deux clubs lisibles en ivoire")
	var equipes: Array = app.model.live.teams
	for cote in 2:
		var voulu := LiveView.fond_plaque(Color.from_string(str(Base.identity(equipes[cote]).get("color", "")), Charte.CLUB))
		check((view.plaques[cote].get_meta("fond") as Color).is_equal_approx(voulu), "Plaque %d à la couleur du club" % cote)
	check(not view.home.text.is_empty() and not view.away.text.is_empty() and not view.phase.text.is_empty(), "Noms des clubs et période écrits (%s / %s / %s)" % [view.home.text, view.away.text, view.phase.text])
	var bande: Control = view.get("bande_temps_forts")
	check(bande != null and bande.get_global_rect().position.x >= r.end.x - 1.0 and view.play.get_global_rect().position.x >= bande.get_global_rect().end.x - 1.0 and ecran.encloses(view.play.get_global_rect()), "Commandes en haut à droite, Pause en dernier")
	var journal_panneau: Control = view.get("_legende")
	var j := journal_panneau.get_global_rect()
	check(j.position.x <= 48 and j.end.y >= 1080 - 60 and absf(j.size.x - 744.0) <= 2.0, "Journal en bas à gauche, 744 px : " + str(j))
	var lignes: Array = view.get("_journal_lignes")
	check((lignes[0][1] as RichTextLabel).get_theme_font_size("normal_font_size") == 16, "Journal en 16 px")
	check(view.journal_affiche().size() >= 1, "Journal écrit : " + str(view.journal_affiche()))

	# 2. Noms de nos joueurs liés dans le journal (survol : mini-fiche ; adversaires : texte).
	var lie := LiveView.liens_joueurs("Bickerstaff gagne la touche, Gannon écarte vers Haworth [x].", [{"id": 11, "name": "Piers Bickerstaff"}, {"id": 12, "name": "Donal Gannon"}])
	check(lie.contains("[url=11]Bickerstaff[/url]") and lie.contains("[url=12]Gannon[/url]") and not lie.contains("[url=13]") and lie.contains("Haworth [lb]x]"), "Noms liés dans le journal : " + lie)
	var notre: Dictionary = app.model.squad[0]
	var riche: RichTextLabel = lignes[0][1]
	view._survol_joueur(str(notre.id), riche)
	await settle(2)
	var mini := app.get_node_or_null("MiniFicheJoueur")
	check(mini != null and mini.visible and fenetres().is_empty(), "Survol d'un nom : mini-fiche posée dans le jeu, pas une fenêtre")
	view._mini_fiche().cacher(app)

	# 3. Aucun or dans l'écran (bandeau, commandes, journal, barre du bas, bannière, mention).
	var mes_noeuds: Array = [bandeau, view.play, view.get("indice_menu"), journal_panneau, view.get("_meteo_boite"), view.barre_commandes, view.drawer, view.regie.bandeau, view.regie.mention]
	var dores: Array[String] = []
	for n: Node in mes_noeuds: dores.append_array(ors(n))
	check(dores.is_empty(), "Aucun or dans l'écran : " + str(dores))

	# 4. Plaque cliquée : fiche du club dans le direct, match en pause, aucune fenêtre ; retour au direct.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	view.plaques[1].gui_input.emit(clic)
	await wait_command()
	await settle(6)
	var page: Control = view.get("page")
	check(page != null and page.visible and page.find_child("MatchClubSheetCanvas", true, false) != null, "Plaque du visiteur : la fiche du club s'ouvre dans le direct")
	check(surface() == view and app.route == "Match", "La fiche ne casse pas le match (même direct, route Match)")
	check(fenetres().is_empty(), "Aucune fenêtre ouverte par le clic : " + str(fenetres().map(func(w: Window): return w.name)))
	await until(func(): return page.find_child("FicheClub", true, false) != null and page.find_child("ClubSheetLoading", true, false) == null, 30000)
	check(page.find_child("FicheClub", true, false) != null, "Fiche du club construite")
	var toile: Control = page.find_child("MatchClubSheetCanvas", true, false)
	var apres: Label = toile.find_child("ClubSheetAfterMatch", true, false) as Label
	check(["ClubSheetCalendar", "ClubSheetCompare", "ClubSheetRecruit"].all(func(n: String) -> bool: return toile.find_child(n, true, false) == null) and apres != null and apres.text.contains("après le match"), "Fiche du club en match : Calendrier, Comparer, Recruter écrits « disponibles après le match »")
	check(actifs_hors_place(toile).is_empty(), "Fiche du club en match : tout lien vers un autre écran est grisé : " + str(actifs_hors_place(toile)))
	check(muets(page).is_empty(), "Fiche du club en match : aucun clic sans réponse : " + str(muets(page)))
	check(toile.find_child("ClubSheetLiveMatch", true, false) != null, "La fiche du club sait que le match est en cours")
	if proof != "": await capture("fiche-club")
	var retour: Button = page.find_child("MatchPageBack", true, false)
	check(retour != null and retour.text.contains("Retour au direct"), "Lien « Retour au direct »")
	if retour != null: retour.pressed.emit()
	await wait_command()
	check(not page.visible and surface() == view and not app.has_meta("fiche_club_en_match"), "Retour au direct")
	# Notre club : ni suivi, ni comparaison, ni recrutement.
	var notre_cote := 0 if int(app.model.live.teams[0].get("id", -1)) == int(app.model.club.id) else 1
	view.ouvrir_fiche_club(notre_cote)
	await wait_command()
	await until(func(): return page.find_child("FicheClub", true, false) != null and page.find_child("ClubSheetLoading", true, false) == null, 30000)
	check(page.find_child("ClubSheetFollow", true, false) == null and page.find_child("ClubSheetAfterMatch", true, false) != null, "Notre club : pas de « Suivre », calendrier après le match")
	# Onglet Effectif de notre club : chaque ligne de joueur ouvre sa fiche complète dans le direct (pas grisée).
	var onglet_effectif: Button = page.find_child("ClubSheetTab1", true, false)
	if onglet_effectif != null: onglet_effectif.pressed.emit()
	await until(func(): return page.find_child("ClubSheetPlayer0", true, false) != null, 15000)
	await settle(2)
	var ligne_joueur := page.find_child("ClubSheetPlayer0", true, false) as BaseButton
	check(ligne_joueur != null and not ligne_joueur.disabled and ligne_joueur.has_meta("fiche_en_match"), "Effectif de notre club en match : la ligne d'un joueur reste active")
	if ligne_joueur != null and not ligne_joueur.disabled:
		ligne_joueur.pressed.emit()
		await wait_command()
		await settle(4)
		check(page.visible and page.find_child("MatchPlayerSheet", true, false) != null and fenetres().is_empty(), "Effectif de notre club : clic sur un joueur = sa fiche complète dans le direct")
	view.fermer_page()
	await wait_command()

	# 4 bis. Nom d'un de nos joueurs dans le journal : sa fiche complète dans le direct, retour au direct.
	view.ouvrir_joueur(str(notre.id))
	await wait_command()
	await settle(4)
	var fiche_joueur: Control = page.find_child("MatchPlayerSheet", true, false)
	check(page.visible and fiche_joueur != null and fenetres().is_empty(), "Nom du journal : fiche complète du joueur dans le direct")
	if fiche_joueur != null:
		var retour_effectif: Control = fiche_joueur.find_child("PlayerBackToSquad", true, false)
		check(retour_effectif == null or not retour_effectif.visible, "Le retour vers l'Effectif laisse place à « Retour au direct »")
		check(actifs_hors_place(fiche_joueur).is_empty() and muets(page).is_empty(), "Fiche joueur en match : liens hors match grisés, aucun clic muet (%s / %s)" % [str(actifs_hors_place(fiche_joueur)), str(muets(page))])
		var onglet: Button = fiche_joueur.find_child("FullPlayerTab2", true, false)
		if onglet != null:
			onglet.pressed.emit()
			await settle(4)
			check(page.visible and page.find_child("MatchPlayerSheet", true, false) != null and int(app.management_ui.get("immersive_player_tab", 0)) == 2, "Onglet de la fiche joueur : sur place, dans le direct")
	if proof != "": await capture("fiche-joueur")
	view.fermer_page()
	await wait_command()
	check(not page.visible, "Retour au direct depuis la fiche joueur")

	# 4 ter. Tiroir Journal (Plus → Journal du match) : jetons de la Charte, aucun cadre complet, noms de nos joueurs
	# liés ; « Relire » ouvre une page du direct avec « ← Retour au direct », jamais une fenêtre.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	view._toggle_drawer("Journal")
	await settle(6)
	var tiroir_journal: Control = view.get("journal")
	check(view.drawer.visible and bool(tiroir_journal.get("charte")), "Tiroir Journal ouvert, habillé à la Charte")
	check(ors(view.drawer).is_empty(), "Tiroir Journal : aucun or : " + str(ors(view.drawer)))
	check(cadres_complets(view.drawer).is_empty(), "Tiroir Journal : aucun cadre complet : " + str(cadres_complets(view.drawer)))
	check(arrondis(view.drawer).is_empty(), "Tiroir Journal : rayons 0 : " + str(arrondis(view.drawer)))
	var nom_notre := str(notre.get("name", ""))
	check(str((tiroir_journal.get("lier") as Callable).call("Essai de " + nom_notre + ".")).contains("[url=%s]" % str(notre.id)), "Tiroir Journal : nos joueurs liés (survol : mini-fiche, clic : fiche)")
	await until(func(): return not (tiroir_journal.get("visible_events") as Array).is_empty(), 30000)
	var textes_lies: Array = tiroir_journal.find_children("JournalEventText", "RichTextLabel", true, false)
	check(not textes_lies.is_empty() and textes_lies.all(func(t: RichTextLabel) -> bool: return t.get_signal_connection_list("meta_clicked").size() > 0), "Faits du tiroir : texte riche, noms cliquables")
	var relire: Button = tiroir_journal.find_child("MatchJournalReview", true, false)
	if relire != null and not relire.disabled:
		relire.pressed.emit()
		await wait_command()
		await settle(6)
		check(page.visible and page.find_child("ActionReviewPage", true, false) != null and fenetres().is_empty() and app.find_child("MatchActionReview", true, false) == null, "Relire : page du direct, pas une fenêtre")
		check(app.model.live.get("paused", false), "Relire : le match est en pause")
		check(ors(page).is_empty() and arrondis(page).is_empty(), "Page de relecture : aucun or, rayons 0 (%s / %s)" % [str(ors(page)), str(arrondis(page))])
		check(muets(page).is_empty(), "Page de relecture : aucun clic sans réponse : " + str(muets(page)))
		if proof != "": await capture("relecture")
		var retour_relecture: Button = page.find_child("MatchPageBack", true, false)
		check(retour_relecture != null and retour_relecture.text.contains("Retour au direct"), "Relecture : « ← Retour au direct »")
		if retour_relecture != null: retour_relecture.pressed.emit()
		await wait_command()
		check(not page.visible, "Retour au direct depuis la relecture")
	else: check(false, "Bouton Relire du tiroir absent ou grisé")
	if view.drawer.visible: view._fermer_tiroir()

	# 4 quater. Bannière d'essai : notre marqueur est un lien (souligné, fiche au clic) ; un adversaire reste du texte.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	var morceaux := nom_notre.split(" ")
	morceaux[morceaux.size() - 1] = morceaux[morceaux.size() - 1].to_upper()
	view.regie.montrer_bandeau("ESSAI", " ".join(morceaux), "Club · 12e minute", 3.0, Color("b0302a"), "+5\n5 – 0")
	await settle(2)
	var nom_banniere: Label = view.regie.bandeau.find_child("MatchMomentNom", true, false)
	var souligne: Control = nom_banniere.get_node_or_null("Souligne")
	check(nom_banniere.mouse_filter == Control.MOUSE_FILTER_STOP and souligne != null and souligne.visible and nom_banniere.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Bannière : notre marqueur souligné, cliquable")
	var clic_nom := InputEventMouseButton.new()
	clic_nom.button_index = MOUSE_BUTTON_LEFT
	clic_nom.pressed = true
	nom_banniere.gui_input.emit(clic_nom)
	await wait_command()
	await settle(4)
	check(page.visible and page.find_child("MatchPlayerSheet", true, false) != null and fenetres().is_empty(), "Bannière : clic sur notre marqueur = sa fiche complète dans le direct")
	view.fermer_page()
	await wait_command()
	view.regie.montrer_bandeau("ESSAI", "Zzyzx QUELCONQUE", "Club · 13e minute", 3.0, Color("b0302a"), "+5\n5 – 5")
	await settle(2)
	check(nom_banniere.mouse_filter == Control.MOUSE_FILTER_IGNORE and not souligne.visible, "Bannière : marqueur adverse en texte inerte, sans soulignement")
	view.regie.bandeau.hide()

	# 5. Échap : pause et menu du match (Reprendre en tête, Réglages, Vitesse, Quitter), voile sous le bandeau.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	touche(KEY_ESCAPE)
	await until(func(): return bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	await settle(4)
	var menu: Control = view.get("menu")
	check(menu != null and menu.visible and app.model.live.paused, "Échap : match en pause et menu du match ouvert")
	check(app.find_child("ImmersivePauseMenu", true, false) == null and fenetres().is_empty(), "Échap n'ouvre jamais le menu de carrière ni une fenêtre")
	var noms := ["MatchMenuReprendre", "MatchMenuReglages", "MatchMenuVitesse", "MatchMenuQuitter"]
	check(noms.all(func(n: String) -> bool: return menu.find_child(n, true, false) != null), "Options du menu : Reprendre, Réglages, Vitesse, Quitter")
	var panneau: Control = view.get("_menu_panneau")
	check(absf(panneau.size.x - 480.0) <= 2.0, "Panneau de 480 px : " + str(panneau.size))
	var voile: Control = view.get("_menu_voile")
	var rangee_haut: Control = view.get("_rangee_haut")
	check(voile.visible and voile.get_index() > view.score.find_parent("MatchHud").get_parent().get_index() and bandeau.z_index > voile.z_index and rangee_haut.z_index <= voile.z_index, "Voile sur le jeu, l'entracte et les commandes ; seul le bandeau du score passe au-dessus")
	# Rien de cliquable sous le menu : la plaque ne réagit pas, le bouton Pause est sous le voile.
	var clic_menu := InputEventMouseButton.new()
	clic_menu.button_index = MOUSE_BUTTON_LEFT
	clic_menu.pressed = true
	view.plaques[0].gui_input.emit(clic_menu)
	await settle(2)
	check(not view.get("page").visible and menu.visible, "Plaque inactive tant que le menu est ouvert")
	check(view.get_viewport().gui_get_focus_owner() == menu.find_child("MatchMenuReprendre", true, false), "Focus sur « Reprendre le match »")
	if proof != "": await capture("menu-echap")
	var vitesse_avant := str(view.regie.horloge)
	(menu.find_child("MatchMenuVitesse", true, false) as Button).pressed.emit()
	await settle(2)
	check(str(view.regie.horloge) != vitesse_avant, "Vitesse du match changée (%s → %s)" % [vitesse_avant, str(view.regie.horloge)])
	var ordre := ["lente", "normale", "rapide", "eclair"]
	var rang_plus := ordre.find(str(view.regie.horloge))
	(menu.find_child("MatchMenuVitesseMoins", true, false) as Button).pressed.emit()
	await settle(2)
	check(ordre.find(str(view.regie.horloge)) == wrapi(rang_plus - 1, 0, 4), "◂ ralentit (%s)" % str(view.regie.horloge))
	(menu.find_child("MatchMenuVitessePlus", true, false) as Button).pressed.emit()
	await settle(2)
	check(ordre.find(str(view.regie.horloge)) == rang_plus, "▸ accélère (%s)" % str(view.regie.horloge))
	view.regie.choisir_horloge(vitesse_avant)
	(menu.find_child("MatchMenuQuitter", true, false) as Button).pressed.emit()
	await settle(2)
	var precision: Label = menu.find_child("MatchMenuQuitter", true, false).find_child("Precision", true, false)
	check(precision != null and precision.text.begins_with("Appuie encore") and not app.closing, "Quitter : un premier appui prévient, rien ne se ferme")
	(menu.find_child("MatchMenuReglages", true, false) as Button).pressed.emit()
	await settle(4)
	check(page.visible and page.find_child("PreferencesPage", true, false) != null and not menu.visible and fenetres().is_empty(), "Réglages : page du direct, pas une fenêtre")
	for nom in ["PreferencesLeagueDetail", "PreferencesPack", "PreferencesCoachHelp"]:
		var b := page.find_child(nom, true, false) as Button
		check(b == null or (b.disabled and b.text.contains("disponible après le match")), "Réglages en match : « %s » grisé, « disponible après le match »" % nom)
	check(muets(page).is_empty(), "Réglages en match : aucun clic sans réponse : " + str(muets(page)))
	(page.find_child("MatchPageBack", true, false) as Button).pressed.emit()
	await settle(4)
	check(not page.visible and menu.visible, "Retour des réglages au menu du match")
	touche(KEY_ESCAPE)
	await until(func(): return not bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	check(not menu.visible and not app.model.live.paused, "Échap referme le menu et le match repart")
	# Clic sur le voile, hors du panneau : le menu se ferme et le match repart ; puces et menu à angles droits.
	view.ouvrir_menu()
	await until(func(): return bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	await settle(2)
	check(arrondis(menu).is_empty() and arrondis(view.play).is_empty() and arrondis(view.get("indice_menu")).is_empty(), "Menu et puces de touche : rayons 0 : " + str(arrondis(menu) + arrondis(view.play)))
	var droite_quitter: Label = menu.find_child("MatchMenuQuitter", true, false).find_child("Droite", true, false) as Label
	check(droite_quitter != null and droite_quitter.text.to_lower().contains("ferme le jeu"), "Quitter le match : dit qu'il ferme le jeu")
	var clic_voile := InputEventMouseButton.new()
	clic_voile.button_index = MOUSE_BUTTON_LEFT
	clic_voile.pressed = true
	voile.gui_input.emit(clic_voile)
	await until(func(): return not bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	check(not menu.visible and not voile.visible and not app.model.live.paused, "Clic sur le voile : menu fermé, le match repart")

	# 6. Rappel « Échap · Pause et menu » cliquable ; « Confier la fin » se confirme dans le menu, pas une fenêtre.
	(view.get("indice_menu") as Button).pressed.emit()
	await wait_command()
	check(menu.visible, "Le rappel Échap ouvre le menu")
	view.fermer_menu(true)
	await wait_command()
	view.confier_fin()
	await wait_command()
	check(menu.visible and menu.find_child("MatchMenuConfirmer", true, false) != null and fenetres().is_empty(), "Confier la fin : confirmation dans le menu du match")
	(menu.find_child("MatchMenuAnnuler", true, false) as Button).pressed.emit()
	await wait_command()
	check(not menu.visible and not app.model.live.get("finished", false), "Annuler : rien n'est confié")

	# 7. Tout ce qui est cliquable dans mes éléments fait quelque chose.
	var muets: Array[String] = []
	for n: Node in [view.play, view.get("indice_menu"), view.barre_commandes]:
		var boutons: Array = [n] if n is BaseButton else []
		boutons.append_array(n.find_children("*", "BaseButton", true, false))
		for b: BaseButton in boutons:
			if b is OptionButton or b is MenuButton: continue
			if b.get_signal_connection_list("pressed").is_empty(): muets.append(str(b.name))
	for p: Control in view.plaques:
		if p.get_signal_connection_list("gui_input").is_empty() or p.mouse_filter != Control.MOUSE_FILTER_STOP: muets.append(str(p.name))
	check(muets.is_empty(), "Aucune commande muette : " + str(muets))

	# 8. Bannière d'essai : couleur du club qui marque, « +5 » et le score, 600 ms d'animation, sans or.
	var cadre: PanelContainer = Regie.construire_bandeau()
	root.add_child(cadre)
	var rouge := Color("b0302a")
	Regie.habiller_bandeau(cadre, "ESSAI", "Ethan Amos", "Alder Fen XV · 52e minute", 1080.0, rouge, "+5\n15 – 7")
	cadre.show()
	await settle(2)
	check((cadre.get("fond") as Color).is_equal_approx(Regie.fond_bandeau(rouge)) and Charte.contraste(Charte.IVOIRE, cadre.get("fond")) >= 4.5, "Bannière à la couleur du club, ivoire lisible")
	check((cadre.find_child("MatchMomentPoints", true, false) as Label).text.begins_with("+5") and ors(cadre).is_empty(), "Points et score, aucun or")
	check(is_equal_approx(Regie.BANDEAU_ENTREE + Regie.BANDEAU_FONDU, 0.6), "600 ms d'animation au total")
	Regie.habiller_bandeau(cadre, "MI-TEMPS", "A   3 — 0   B", "", 1080.0)
	check((cadre.get("fond") as Color) == Charte.PANNEAU_3, "Mi-temps : bannière sur panneau")
	cadre.queue_free()

	# Captures : un moment de jeu ordinaire, puis la bannière d'essai si un essai passe.
	if proof != "": await capture("jeu")
	finir()

func capture(nom: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join("direct-%s.png" % nom))

func finir() -> void:
	print("MATCH_DIRECT_DA %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
