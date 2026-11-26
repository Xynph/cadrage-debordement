extends SceneTree
## Écran 13 « Match en direct » dans le vrai jeu (godot-match-direct-da.cjs prépare la carrière Monde).
## Décisions contrôlées (charte finale du 20/11/2026) : bandeau du score sur panneau rayon 18, couleur des clubs sur
## l'écusson seul, bannière d'essai en aplat à la couleur du club qui marque (exception de Léo), menu du match par Échap (seule fenêtre
## permise), plein écran obligatoire : plaques et noms de nos joueurs → petite fenêtre visuelle par-dessus le match
## (Échap, ✕, clic à côté la ferment), noms liés dans le journal, un seul aplat doré (« Valider la journée »).
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

## Aplats dorés (fond d'un bouton ou d'un panneau, tous états) : charte finale, un seul par écran, l'action principale.
func aplats_or(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	var noeuds: Array = [racine]
	noeuds.append_array(racine.find_children("*", "Control", true, false))
	for n: Variant in noeuds:
		var c := n as Control
		if c == null: continue
		for cle in ["panel", "normal", "hover", "pressed", "disabled"]:
			if not c.has_theme_stylebox_override(cle): continue
			var s := c.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null and dore(s.bg_color):
				trouves.append(str(c.name))
				break
		if c is ColorRect and dore((c as ColorRect).color): trouves.append(str(c.name))
	return trouves

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

## Aplats ou cadres à angles droits sous `racine` (charte finale §3 : panneaux 18, cartes 12, cases 6, pilules ;
## « droit partout » vaut pour les titres et les traits, pas pour les surfaces). Un soulignement seul (lien) n'est
## pas une surface.
func angles_droits(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	var noeuds: Array = [racine]
	noeuds.append_array(racine.find_children("*", "Control", true, false))
	for n: Variant in noeuds:
		var c := n as Control
		if c == null: continue
		for cle in ["panel", "normal", "hover", "pressed", "focus", "disabled"]:
			if not c.has_theme_stylebox_override(cle): continue
			var s := c.get_theme_stylebox(cle) as StyleBoxFlat
			if s == null: continue
			var cotes := [s.border_width_left, s.border_width_top, s.border_width_right, s.border_width_bottom].filter(func(l: int) -> bool: return l > 0).size()
			var surface := s.bg_color.a > 0.05 or (s.border_color.a > 0.05 and cotes >= 2)
			if surface and s.corner_radius_top_left + s.corner_radius_top_right + s.corner_radius_bottom_left + s.corner_radius_bottom_right == 0: trouves.append("%s<%s.%s" % [c.name, c.get_parent().name if c.get_parent() != null else "", cle])
	return trouves

## Rayon (coin haut gauche) du style `cle` d'un contrôle ; -1 sans StyleBoxFlat.
func rayon(c: Control, cle: String) -> int:
	var s := c.get_theme_stylebox(cle) as StyleBoxFlat if c != null else null
	return s.corner_radius_top_left if s != null else -1

## Styles à cadre complet (quatre côtés) sous `racine`, hors focus (anneau de focus accepté) et hors contour 1 px
## `FILET` d'une pilule (champ, bouton secondaire : seul contour permis par la charte finale §3).
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
			if s == null or (s.corner_radius_top_left >= Charte.RAYON_PILULE and s.border_color == Charte.FILET and s.border_width_left <= 1): continue
			if s.border_color.a > 0.0 and s.border_width_left > 0 and s.border_width_right > 0 and s.border_width_top > 0 and s.border_width_bottom > 0: trouves.append("%s.%s" % [c.name, cle])
	return trouves

## Boutons actifs et visibles sans aucune action branchée.
func muets(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in racine.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.disabled or not b.is_visible_in_tree() or b is OptionButton or b is MenuButton or b is CheckBox or b is CheckButton: continue
		if b.get_signal_connection_list("pressed").is_empty() and b.get_signal_connection_list("toggled").is_empty(): trouves.append(str(b.name))
	return trouves

## Fenêtre visuelle : aucun bloc de texte (étiquette de plus de 4 mots ou de 32 signes, hors titre).
func pas_de_phrase(racine: Node) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in racine.find_children("*", "Label", true, false):
		var t := (n as Label).text
		if str(n.name).ends_with("Titre"): continue
		if t.split(" ", false).size() > 4 or t.length() > 32: trouves.append(t)
	return trouves

## Toujours dans le match : même direct, route Match, aucune page du direct ni fenêtre système.
func dans_le_match(view: Control) -> bool:
	var p: Variant = view.get("page")
	return surface() == view and app.route == "Match" and fenetres().is_empty() and (p == null or not (p as Control).visible)

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

	# 1. Bandeau du score : en haut à gauche, petit, un panneau 90 % rayon 18 ; la couleur des clubs seulement sur
	# l'écusson (puce du sigle, rayon 6) ; score crème 40 px.
	var bandeau: Control = view.get("_coque_score")
	var r := bandeau.get_global_rect()
	check(r.position.x <= 48 and r.position.y <= 48 and r.size.y <= 1080 * 0.08 and r.size.x <= 1920 * 0.55, "Bandeau du score en haut à gauche, petit (agrandi de 28 %, retouche de Léo du 21/11/2026) : " + str(r))
	check(view.score.get_theme_font_size("font_size") == roundi(40 * view.BARRE_HAUT) and view.score.get_theme_color("font_color") == Charte.IVOIRE, "Score ivoire 40 px en 1080p")
	check(LiveView.BandeauAngle.FOND == Color(Charte.PANNEAU, 0.9), "Bandeau du score sur PANNEAU 90 %")
	check(view.plaques.size() == 2 and view.plaques.all(func(p: Control) -> bool: return not p.has_meta("fond") and Charte.contraste(Charte.IVOIRE, p.get_meta("ecusson")) >= 4.5), "Plaques sans fond de club ; sigle crème lisible sur l'écusson")
	var equipes: Array = app.model.live.teams
	for cote in 2:
		var voulu := LiveView.fond_plaque(Color.from_string(str(Base.identity(equipes[cote]).get("color", "")), Charte.CLUB))
		var puce: Control = view.plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
		var fond_puce := puce.get_theme_stylebox("panel") as StyleBoxFlat if puce != null else null
		check((view.plaques[cote].get_meta("ecusson") as Color).is_equal_approx(voulu) and fond_puce != null and fond_puce.bg_color.is_equal_approx(voulu) and fond_puce.corner_radius_top_left == Charte.RAYON_PETIT, "Écusson %d à la couleur du club, case rayon 6" % cote)
	# Logo du club à la place de la pastille du sigle, jamais les deux. Jeu de base : l'écusson dessiné, initiales lisibles.
	for cote in 2:
		var puce: Control = view.plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
		var logo: Control = view.plaques[cote].find_child("MatchClubCrest%d" % cote, true, false)
		var initiales: Array = logo.find_children("*", "Label", true, false) if logo != null else []
		check(logo != null and logo.is_visible_in_tree() and puce != null and not puce.visible, "Logo %d à la place de la pastille du sigle, jamais les deux" % cote)
		check(logo != null and not logo.has_meta("logo_pack") and initiales.size() == 1 and (initiales[0] as Label).is_visible_in_tree() and (initiales[0] as Label).text == Base.club_abbr(equipes[cote]) and (initiales[0] as Label).get_theme_font_size("font_size") >= 11, "Jeu de base : écusson dessiné %d aux initiales du club, lisibles" % cote)
		check(logo != null and logo.get_global_rect().size.y >= 40.0 and view.plaques[cote].get_global_rect().encloses(logo.get_global_rect()) and logo.find_children("*", "Control", true, false).all(func(c: Control) -> bool: return c.mouse_filter == Control.MOUSE_FILTER_IGNORE) and logo.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.plaques[cote].mouse_filter == Control.MOUSE_FILTER_STOP, "Logo %d dans la plaque cliquable (clic : fiche du club)" % cote)
		check(view.plaques[cote].get_global_rect().end.x <= r.end.x + 1.0 and view.plaques[cote].get_global_rect().position.x >= r.position.x - 1.0, "Plaque %d avec son logo dans le bandeau" % cote)
	# Faux pack d'identité (image générée pendant le test) : son logo remplace l'écusson dessiné, toujours sans pastille.
	var dossier_pack := OS.get_user_data_dir().path_join("faux-pack-bandeau")
	DirAccess.make_dir_recursive_absolute(dossier_pack)
	var image_logo := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image_logo.fill(Color(0.1, 0.6, 0.9))
	var chemin_logo := dossier_pack.path_join("logo-0.png")
	image_logo.save_png(chemin_logo)
	var avec_pack: Array = equipes.duplicate(true)
	if avec_pack[0].get("presentation") is Dictionary: avec_pack[0].presentation["logoPath"] = chemin_logo
	else: avec_pack[0]["logoPath"] = chemin_logo
	view.set("_plaques_cle", "")
	view._poser_plaques(avec_pack)
	await settle(2)
	var logo_pack: Control = view.plaques[0].find_child("MatchClubCrest0", true, false)
	var puce_pack: Control = view.plaques[0].find_child("MatchClubChip0", true, false)
	check(logo_pack is TextureRect and logo_pack.has_meta("logo_pack") and (logo_pack as TextureRect).texture != null and (logo_pack as TextureRect).texture.get_image().get_pixel(32, 32).is_equal_approx(image_logo.get_pixel(32, 32)) and not puce_pack.visible and view.plaques[0].find_children("MatchClubCrest*", "", true, false).size() == 1, "Pack d'identité : son logo à la place de l'écusson dessiné, sans pastille")
	check(not view.plaques[1].find_child("MatchClubCrest1", true, false).has_meta("logo_pack"), "Club sans logo de pack : écusson dessiné")
	view.set("_plaques_cle", "")
	view._poser_plaques(equipes)
	await settle(2)
	check(not view.plaques[0].find_child("MatchClubCrest0", true, false).has_meta("logo_pack") and view.plaques[0].find_children("MatchClubCrest*", "", true, false).size() == 1, "Sans pack : retour à l'écusson dessiné")
	DirAccess.remove_absolute(chemin_logo)
	check(angles_droits(bandeau).is_empty(), "Bandeau du score : aucun aplat à angles droits : " + str(angles_droits(bandeau)))
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
	# Coup de pied trop long pour une ligne : le receveur reste lisible, c'est la fin du geste qui saute (réserve de #1307).
	var riche_j: RichTextLabel = lignes[0][1]
	var taille_j := riche_j.get_theme_font_size("normal_font_size")
	var attendu := "Donal GANNON (AFN) tape par-dessus la défense ; Fraser BUSH récupère pour MBR."
	var place := Charte.texte_moyen().get_string_size(attendu, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_j).x + 1.0
	var pied := LiveView.ligne_tenue("Donal GANNON (AFN) tape par-dessus la défense, trop long ; Fraser BUSH récupère pour MBR.", Charte.texte_moyen(), taille_j, place)
	check(pied == attendu, "Coup de pied : receveur gardé dans le journal : " + pied)
	var serre := LiveView.ligne_tenue("Donal GANNON (AFN) tente le coup de pied croisé ; Aidan GORMLEY récupère pour MBR.", Charte.texte_moyen(), taille_j, place - 60.0)
	check(serre.ends_with(" … ; Aidan GORMLEY récupère pour MBR.") and serre.begins_with("Donal GANNON (AFN) tente"), "Coup de pied serré : geste coupé, receveur gardé : " + serre)
	var notre: Dictionary = app.model.squad[0]
	var riche: RichTextLabel = lignes[0][1]
	view._survol_joueur(str(notre.id), riche)
	await settle(2)
	var mini := app.get_node_or_null("MiniFicheJoueur")
	check(mini != null and mini.visible and fenetres().is_empty(), "Survol d'un nom : mini-fiche posée dans le jeu, pas une fenêtre")
	view._mini_fiche().cacher(app)

	# 3. Un seul aplat doré dans l'écran : « Valider la journée » (action principale). Texte doré, contours et focus permis.
	var mes_noeuds: Array = [bandeau, view.play, view.get("indice_menu"), journal_panneau, view.get("_meteo_boite"), view.barre_commandes, view.drawer, view.regie.bandeau, view.regie.mention]
	var dores: Array[String] = []
	for n: Node in mes_noeuds:
		for nom in aplats_or(n):
			if not dores.has(nom): dores.append(nom)
	check(dores == ["MatchFinishButton"], "Un seul aplat doré dans l'écran, « Valider la journée » : " + str(dores))
	var valider := view.find_child("MatchFinishButton", true, false) as Button
	var fond_valider := valider.get_theme_stylebox("normal") as StyleBoxFlat if valider != null else null
	check(fond_valider != null and fond_valider.corner_radius_top_left >= 999, "« Valider la journée » : pilule (rayon 999)")

	# 4. Plein écran obligatoire (règle de Léo du 21/11/2026) : la plaque de chaque club ouvre une petite fenêtre
	# visuelle par-dessus le match (écusson, forme en pastilles, score et chiffres du match en tuiles), jamais une page
	# qui remplace la vue ; le match se met en pause, Échap ferme la fenêtre (pas le menu) et le match repart.
	if proof != "": await capture("match-1920")
	for cote in 2:
		if app.model.live.get("paused", false): await command("pause", {"paused": false})
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		view.plaques[cote].gui_input.emit(clic)
		await wait_command()
		await settle(6)
		var hote: Control = view.get("fenetre_hote")
		var panneau: Control = hote.find_child("MatchFenetreClubPanneau", true, false) if hote != null else null
		check(view.fenetre_ouverte() and panneau != null and panneau.is_visible_in_tree(), "Plaque %d : petite fenêtre du club par-dessus le match" % cote)
		if panneau == null: continue
		check(int(panneau.get_meta("club_id", -1)) == int(float(app.model.live.teams[cote].id)), "Plaque %d : la fenêtre est celle de ce club" % cote)
		# Le score du bandeau (ce qui a été montré), jamais celui du moteur en avance.
		var marque: Array = view.score_affiche()
		var score_tuile: Label = panneau.find_child("MatchFenetreClubScoreValeur", true, false)
		check(score_tuile != null and score_tuile.text == "%d – %d" % [int(marque[cote]), int(marque[1 - cote])], "Plaque %d : score du match de son point de vue en tuile (%s)" % [cote, score_tuile.text if score_tuile != null else "?"])
		var essais_tuile: Label = panneau.find_child("MatchFenetreClubEssaisValeur", true, false)
		check(essais_tuile != null and essais_tuile.text.is_valid_int() and int(essais_tuile.text) * 5 <= int(marque[cote]), "Plaque %d : essais jamais en avance sur le score montré (%s)" % [cote, essais_tuile.text if essais_tuile != null else "?"])
		check(["MatchFenetreClubEcusson", "MatchFenetreClubForme", "MatchFenetreClubRang", "MatchFenetreClubPoints", "MatchFenetreClubEssais", "MatchFenetreClubPossession", "MatchFenetreClubTerritoire", "MatchFenetreClubPénalités", "MatchFenetreClubLieu"].all(func(n: String) -> bool: return panneau.find_child(n, true, false) != null), "Plaque %d : écusson, forme, rang, points, chiffres du match, lieu" % cote)
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panneau.get_global_rect()), "Plaque %d : fenêtre entière à l'écran" % cote)
		check(pas_de_phrase(panneau).is_empty(), "Plaque %d : aucun bloc de texte : %s" % [cote, str(pas_de_phrase(panneau))])
		check(aplats_or(hote).is_empty() and angles_droits(panneau).is_empty(), "Plaque %d : aucun aplat doré ni à angles droits (%s / %s)" % [cote, str(aplats_or(hote)), str(angles_droits(panneau))])
		check(dans_le_match(view), "Plaque %d : toujours dans le match (même direct, aucune page, aucune fenêtre système)" % cote)
		# La pause part dès que le moteur est libre (demande différée pendant une réponse).
		await until(func(): return bool(app.model.live.get("paused", false)) and not app.waiting, 10000)
		check(bool(app.model.live.get("paused", false)), "Plaque %d : le match se met en pause pendant la fenêtre" % cote)
		if proof != "": await capture("fenetre-club-%d" % cote)
		touche(KEY_ESCAPE)
		await until(func(): return not bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
		await settle(4)
		check(not view.fenetre_ouverte() and not (view.get("menu") != null and view.menu.visible), "Plaque %d : Échap ferme la fenêtre, pas le menu du match" % cote)
		check(dans_le_match(view) and not bool(app.model.live.get("paused", false)), "Plaque %d : après Échap, toujours dans le match, qui repart" % cote)
	# ✕ et clic à côté ferment aussi.
	view.ouvrir_fiche_club(0)
	await wait_command()
	await settle(4)
	var croix: Button = view.get("fenetre_hote").find_child("MatchFenetreClubFermer", true, false) if view.fenetre_ouverte() else null
	check(croix != null, "Fenêtre du club : ✕")
	if croix != null: croix.pressed.emit()
	await wait_command()
	await settle(2)
	check(not view.fenetre_ouverte() and dans_le_match(view), "✕ ferme la fenêtre, toujours dans le match")
	view.ouvrir_fiche_club(1)
	await wait_command()
	await settle(4)
	var a_cote: Button = view.get("fenetre_hote").find_child("MatchFenetreACote", true, false) if view.fenetre_ouverte() else null
	check(a_cote != null and a_cote.is_visible_in_tree(), "Fenêtre du club : voile sur tout l'écran")
	if a_cote != null: a_cote.pressed.emit()
	await wait_command()
	await settle(2)
	check(not view.fenetre_ouverte() and dans_le_match(view), "Clic à côté ferme la fenêtre, toujours dans le match")

	# 4 bis. Nom d'un de nos joueurs cliqué dans le journal : sa petite fenêtre (portrait, poste, note, énergie en jauge,
	# niveau, chiffres du match en tuiles) ; Échap la ferme, toujours dans le match.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	riche.meta_clicked.emit(str(notre.id))
	await wait_command()
	await settle(6)
	var hote_joueur: Control = view.get("fenetre_hote")
	var fiche_joueur: Control = hote_joueur.find_child("MatchFenetreJoueurPanneau", true, false) if hote_joueur != null else null
	check(view.fenetre_ouverte() and fiche_joueur != null and str(fiche_joueur.get_meta("player_id", "")) == str(notre.id), "Nom du journal : petite fenêtre du joueur par-dessus le match")
	if fiche_joueur != null:
		check(["MatchFenetreJoueurPortrait", "MatchFenetreJoueurNote", "MatchFenetreJoueurEnergie", "MatchFenetreJoueurNiveau", "MatchFenetreJoueurEssais", "MatchFenetreJoueurPlaquages", "MatchFenetreJoueurMetres"].all(func(n: String) -> bool: return fiche_joueur.find_child(n, true, false) != null), "Fenêtre du joueur : portrait, note, énergie, niveau, chiffres du match")
		var titre_joueur: Label = fiche_joueur.find_child("MatchFenetreJoueurTitre", true, false)
		check(titre_joueur != null and titre_joueur.text == str(notre.name).to_upper(), "Fenêtre du joueur : son nom en titre")
		check(pas_de_phrase(fiche_joueur).is_empty(), "Fenêtre du joueur : aucun bloc de texte : " + str(pas_de_phrase(fiche_joueur)))
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(fiche_joueur.get_global_rect()) and aplats_or(hote_joueur).is_empty(), "Fenêtre du joueur : entière à l'écran, sans aplat doré")
		check(dans_le_match(view) and bool(app.model.live.get("paused", false)), "Fenêtre du joueur : toujours dans le match, en pause")
		if proof != "": await capture("fenetre-joueur")
	touche(KEY_ESCAPE)
	await until(func(): return not bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	await settle(4)
	check(not view.fenetre_ouverte() and not (view.get("menu") != null and view.menu.visible) and dans_le_match(view) and not bool(app.model.live.get("paused", false)), "Fenêtre du joueur : Échap la ferme, toujours dans le match, qui repart")
	var page: Control = null

	# 4 ter. Tiroir Journal (Plus → Journal du match) : jetons de la Charte, aucun cadre complet, noms de nos joueurs
	# liés ; « Relire » ouvre une page du direct avec « ← Retour au direct », jamais une fenêtre.
	if app.model.live.get("paused", false): await command("pause", {"paused": false})
	view._toggle_drawer("Journal")
	await settle(6)
	var tiroir_journal: Control = view.get("journal")
	check(view.drawer.visible and bool(tiroir_journal.get("charte")), "Tiroir Journal ouvert, habillé à la Charte")
	check(aplats_or(view.drawer).is_empty() and ors(view.drawer).all(func(n: String) -> bool: return n.ends_with(".focus")), "Tiroir Journal : aucun or hors anneau de focus : " + str(ors(view.drawer)))
	check(cadres_complets(view.drawer).is_empty(), "Tiroir Journal : aucun cadre complet : " + str(cadres_complets(view.drawer)))
	var fond_tiroir := view.drawer.get_theme_stylebox("panel") as StyleBoxFlat
	check(fond_tiroir != null and fond_tiroir.corner_radius_top_left == Charte.RAYON_PANNEAU and fond_tiroir.border_width_left + fond_tiroir.border_width_top + fond_tiroir.border_width_right + fond_tiroir.border_width_bottom == 0, "Tiroir Journal : panneau rayon 18 sans bordure")
	check(angles_droits(view.drawer).is_empty(), "Tiroir Journal : aucun aplat à angles droits : " + str(angles_droits(view.drawer)))
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
		page = view.get("page")
		check(page.visible and page.find_child("ActionReviewPage", true, false) != null and fenetres().is_empty() and app.find_child("MatchActionReview", true, false) == null, "Relire : page du direct, pas une fenêtre")
		check(app.model.live.get("paused", false), "Relire : le match est en pause")
		check(aplats_or(page).is_empty() and angles_droits(page).is_empty(), "Page de relecture : aucun aplat doré (anneau de focus permis), aucun aplat à angles droits (%s / %s)" % [str(aplats_or(page)), str(angles_droits(page))])
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
	check(view.fenetre_ouverte() and view.get("fenetre_hote").find_child("MatchFenetreJoueurPanneau", true, false) != null and dans_le_match(view), "Bannière : clic sur notre marqueur = sa petite fenêtre, toujours dans le match")
	view.fermer_fenetre()
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
	# Lot 10 : plus de phrase d'explication ; la minute est une pastille, les raccourcis sont derrière un « ? ».
	check(menu.find_child("MatchMenuMinute", true, false) != null and menu.find_child("MatchMenuAide", true, false) != null, "Menu du match : pastille de la minute et « ? » des raccourcis")
	for etiquette in menu.find_children("*", "Label", true, false):
		var ligne := (etiquette as Label).text
		check(not ligne.contains("carrière reste fermé") and not ligne.contains("s’applique dès") and not ligne.contains("son, image"), "Menu du match : phrase retirée absente (« %s »)" % ligne)
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
	check(not view.fenetre_ouverte() and menu.visible, "Plaque inactive tant que le menu est ouvert")
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
	page = view.get("page")
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
	# Clic sur le voile, hors du panneau : le menu se ferme et le match repart ; menu en panneau 18, commandes en
	# pilule, puces de touche en case 6, focus en anneau doré.
	view.ouvrir_menu()
	await until(func(): return bool(app.model.live.get("paused", false)) and not app.waiting, 20000)
	await settle(2)
	var indice: Control = view.get("indice_menu")
	check(angles_droits(menu).is_empty() and angles_droits(view.play).is_empty() and angles_droits(indice).is_empty(), "Menu, Pause, rappel Échap : aucun aplat à angles droits : " + str(angles_droits(menu) + angles_droits(view.play) + angles_droits(indice)))
	check(rayon(panneau, "panel") == Charte.RAYON_PANNEAU and rayon(view.play, "normal") >= Charte.RAYON_PILULE and rayon(indice, "normal") >= Charte.RAYON_PILULE and rayon(view.play.get_node("Touche"), "panel") == Charte.RAYON_PETIT, "Menu en panneau 18, Pause et rappel en pilule, puce de touche en case 6")
	var focus_pause := view.play.get_theme_stylebox("focus") as StyleBoxFlat
	check(focus_pause != null and dore(focus_pause.border_color) and focus_pause.border_width_left == 2 and focus_pause.border_width_bottom == 2, "Focus de Pause : anneau doré de 2 px")
	check(aplats_or(menu).is_empty(), "Menu du match : aucun aplat doré : " + str(aplats_or(menu)))
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

	# 8. Bannière d'essai : aplat à la couleur du club qui marque (exception de Léo du 20/11/2026), assombri pour la
	# crème, jamais l'or (club jaune : bordeaux de la charte) ; « +5 » et le score, 600 ms d'animation.
	var cadre: PanelContainer = Regie.construire_bandeau()
	root.add_child(cadre)
	var rouge := Color("b0302a")
	Regie.habiller_bandeau(cadre, "ESSAI", "Ethan Amos", "Alder Fen XV · 52e minute", 1080.0, rouge, "+5\n15 – 7")
	cadre.show()
	await settle(2)
	var fond_essai := cadre.get("fond") as Color
	check(fond_essai.is_equal_approx(Regie.fond_bandeau(rouge)) and absf(fond_essai.h - rouge.h) < 0.02 and Charte.contraste(Charte.IVOIRE, fond_essai) >= 4.5, "Bannière à la couleur du club qui marque, crème lisible (4,5:1 au moins)")
	var fond_jaune := Regie.fond_bandeau(Color("e8c03a"))
	check(not dore(fond_jaune) and Charte.contraste(Charte.IVOIRE, fond_jaune) >= 4.5, "Club jaune : la bannière ne prend jamais l'or")
	check((cadre.find_child("MatchMomentPoints", true, false) as Label).text.begins_with("+5") and ors(cadre).is_empty() and not dore(fond_essai), "Points et score, aucun or")
	check(is_equal_approx(Regie.BANDEAU_ENTREE + Regie.BANDEAU_FONDU, 0.6), "600 ms d'animation au total")
	Regie.habiller_bandeau(cadre, "MI-TEMPS", "A   3 — 0   B", "", 1080.0)
	check((cadre.get("fond") as Color) == Charte.PANNEAU, "Mi-temps : bannière sur panneau, sans couleur de club")
	cadre.queue_free()

	# Captures : un moment de jeu ordinaire, puis la bannière d'essai si un essai passe.
	if proof != "": await capture("jeu")
	# Le direct en 1280 × 720 (même vue, mise à l'échelle).
	if proof != "" and DisplayServer.get_name() != "headless":
		if app.model.live.get("paused", false) and not app.model.live.get("finished", false): await command("pause", {"paused": false})
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		await settle(30)
		# Le match en jeu (terrain 3D), pas l'entracte : on attend un temps fort joué.
		await until(func(): return view.regie.etat == Regie.JEU and not view.regie.between.is_visible_in_tree(), 90000)
		await settle(20)
		check(view.regie.etat == Regie.JEU, "1280 × 720 : le match en jeu (terrain 3D) pour la capture")
		await capture("match-1280")
		view.ouvrir_fiche_club(0)
		await wait_command()
		await settle(10)
		await capture("fenetre-club-0-1280")
		view.fermer_fenetre()
		await wait_command()
		view.ouvrir_joueur(str(notre.id))
		await wait_command()
		await settle(10)
		await capture("fenetre-joueur-1280")
		view.fermer_fenetre()
		await wait_command()
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
