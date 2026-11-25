extends SceneTree
# Écran Composition (choix de Léo du 19/11/2026 : variante 1 « Terrain au centre, candidats dessous » + encart
# « Première ligne formée » de la variante 3), carrière Monde réelle, vrai moteur :
#  - tout ce qui a l'air cliquable change d'écran, de poste, de tri ou envoie une commande ; aucune Window ouverte ;
#  - aucune couleur or dans l'écran (l'or est réservé à Continuer, dans la coque) ;
#  - terrain vertical vert (option A de Léo, 22/11/2026) : attaque vers le haut, avants en haut, arrière en bas ;
#    candidats sous le banc, encart première ligne sur les n° 1-3 / 16-18 ;
#  - clavier : Espace prend puis pose (échange réel), Échap annule, Suppr libère (confirmation), I carte joueur ;
#  - vraie souris : glisser-déposer (échange réel), clic sur une carte, survol d'un nom = carte joueur ; clic = fiche ;
#  - sous-page « Tireurs et lanceur » avec retour, Échap et historique.
const Flow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
var Vertical = load("res://ui/immersive08/tactics_vertical.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Carte = preload("res://ui/carte_joueur_survol.gd")
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

var _souris_avant := Vector2.ZERO

## Mouvement de souris réel (le glisser cumule le déplacement relatif depuis l'appui).
func souris(position: Vector2, masque: int = 0) -> void:
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = position
	mouvement.global_position = position
	mouvement.relative = position - _souris_avant
	_souris_avant = position
	mouvement.button_mask = masque
	root.push_input(mouvement)
	await process_frame

## Attente en horloge réelle (le délai de la carte ne dépend pas de la cadence d'images).
func attendre_ms(ms: int) -> void:
	var fin := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < fin: await process_frame

func clic(position: Vector2, appui: bool) -> void:
	var bouton := InputEventMouseButton.new()
	bouton.button_index = MOUSE_BUTTON_LEFT
	bouton.pressed = appui
	bouton.button_mask = MOUSE_BUTTON_MASK_LEFT if appui else 0
	bouton.position = position
	bouton.global_position = position
	root.push_input(bouton)
	await process_frame

## Vrai glisser-déposer : appui, déplacement par petits pas (le jeu cumule le déplacement relatif), `pendant` appelé
## une fois la souris sur la cible (bouton toujours enfoncé), relâche ; attend la réponse du moteur.
func glisser_souris(depart: Vector2, arrivee: Vector2, pendant: Callable = Callable()) -> void:
	await souris(depart)
	await clic(depart, true)
	for etape in range(1, 16): await souris(depart.lerp(arrivee, etape / 15.0), MOUSE_BUTTON_MASK_LEFT)
	await souris(arrivee + Vector2(1, 1), MOUSE_BUTTON_MASK_LEFT)
	await settle(2)
	if pendant.is_valid(): await pendant.call()
	await clic(arrivee, false)
	await wait_idle()
	await settle()

## Tactique › Entraînement « façon Effectif » (choix du 22/11/2026) : quatre petites tuiles, la semaine en bande de
## sept jours, « À surveiller » en liste à lignes triable avec filtres en pastilles ; ligne = fiche joueur.
func entrainement_facon_effectif() -> void:
	await composition()
	var onglet := named("TacticsTab4") as Button
	check(onglet != null, "Onglet Entraînement présent")
	if onglet == null: return
	onglet.pressed.emit()
	await settle()
	for i in 4:
		var tuile := named("TacticsTabTuile%dLien" % i) as Button
		check(tuile != null and tuile.is_visible_in_tree(), "Entraînement : tuile %d cliquable" % i)
		var fond := named("TacticsTabTuile%d" % i)
		if fond != null: check(fond.get_global_rect().size.y < app.size.y * .08, "Entraînement : tuile %d compacte" % i)
	var jours := 0
	for i in 7: if named("TacticsTabJourLien%d" % i) is Button: jours += 1
	check(jours == 0 or jours == 7, "Entraînement : semaine en bande de sept jours (%d)" % jours)
	if jours == 7: check(absf(named("TacticsTabJour0").get_global_rect().position.y - named("TacticsTabJour6").get_global_rect().position.y) < 1.0, "Entraînement : jours sur une seule rangée")
	check(named("TacticsTabSurveilles") != null, "Entraînement : liste « À surveiller »")
	for filtre in ["tous", "cond", "charge"]: check(named("TacticsTabFiltre_" + filtre) != null, "Entraînement : filtre en pastille " + filtre)
	var tri := named("TacticsTabTri_charge") as Button
	check(tri != null, "Entraînement : colonne Charge triable")
	if tri != null:
		tri.pressed.emit()
		await settle()
		if named("TacticsTabSurveilles") == null:
			(named("TacticsTab4") as Button).pressed.emit()
			await settle()
		var ordre: Variant = app.management_ui.get("tactique_entrainement_tri")
		check(ordre is Array and str(ordre[0]) == "charge", "Entraînement : tri par charge appliqué")
	if named("TacticsTabSurveilles") == null and named("TacticsTab4") != null:
		(named("TacticsTab4") as Button).pressed.emit()
		await settle()
	var ligne := named("TacticsTabSurveille0") as Button
	if ligne != null:
		check(ligne.get_node_or_null("SurvolLigne") != null, "Entraînement : survol de ligne façon Effectif")
		ligne.pressed.emit()
		await settle()
		check(app.route == "Effectif", "Entraînement : une ligne ouvre la fiche joueur (%s)" % app.route)
	app.management_ui.erase("tactique_entrainement_tri")

func composition() -> void:
	app._navigate("Composition")
	await settle(10)

const ENTETE := ["CompositionTitle", "TacticsValidity", "TacticsCountStarters", "TacticsCountBench", "TacticsCountFrontRow", "LineupAutomatic", "LineupRoles", "TacticsValidate", "TacticsFixtureHome", "TacticsFixtureAway", "TacticsFixtureCompetition", "TacticsFixtureDate", "TacticsFixtureVenue", "TacticsFixturePlace", "TacticsPlanSummary", "TacticsDefenseSummary"]

## En-tête visuel (demande de Léo du 22/11/2026) : pastilles et bandeau sans chevauchement ni texte coupé (1920 et
## 2560), plus de phrase d'aide dans la bulle de Gabi ; chaque pastille et écusson mène à sa destination.
func entete_visuel() -> void:
	for taille: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = taille
		await settle(4)
		await composition()
		var page := named("ImmersiveTactics")
		var cadres: Array[Rect2] = []
		var manquants: Array[String] = []
		for id: String in ENTETE:
			var n := named(id)
			if n == null or not n.is_visible_in_tree(): manquants.append(id); continue
			cadres.append(n.get_global_rect())
		check(manquants.is_empty(), "%d : en-tête complet (manque %s)" % [taille.x, ", ".join(manquants)])
		var chevauchent: Array[String] = []
		for i in cadres.size():
			if cadres[i].end.x > page.get_global_rect().end.x + 1: chevauchent.append(ENTETE[i] + " hors de l'écran")
			for j in range(i + 1, cadres.size()):
				if cadres[i].grow(-1).intersects(cadres[j].grow(-1)): chevauchent.append(ENTETE[i] + "/" + ENTETE[j])
		check(chevauchent.is_empty(), "%d : aucun chevauchement dans l'en-tête : %s" % [taille.x, ", ".join(chevauchent)])
		var coupes: Array[String] = []
		for id: String in ENTETE:
			var n := named(id)
			if n == null: continue
			var labels: Array = n.find_children("*", "Label", true, false)
			if n is Label: labels.append(n)
			for node in labels:
				var label := node as Label
				var largeur := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
				if label.text.ends_with("…") or largeur > label.size.x + 1: coupes.append(label.text)
			if n is Button and not (n as Button).text.is_empty():
				var b := n as Button
				var texte := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
				if texte + C.px(20) > b.size.x: coupes.append(b.text)
		check(coupes.is_empty(), "%d : aucun texte coupé dans l'en-tête : %s" % [taille.x, ", ".join(coupes)])
		var ecusson := named("TacticsFixtureHome").find_child("Ecusson", true, false) if named("TacticsFixtureHome") != null else null
		check(ecusson != null and ecusson.has_meta("bulle_survol"), "%d : écusson à mini-carte club au survol" % taille.x)
		check(not _contient_texte(named("TacticsStaffAdvice"), "Clique un poste"), "Bulle de Gabi : plus de « Clique un poste… »")
		if is_instance_valid(app.coach):
			if app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
			if app.coach.has_method("close"): app.coach.close()
		await settle(2)
		await capture("composition-entete-%d" % taille.x)
	root.size = Vector2i(1920, 1080)
	await settle(4)
	# Clics : chaque pastille et écusson mène à sa destination.
	var domicile := _contient_texte(named("TacticsFixturePlace"), "DOM.")
	for paire: Array in [["TacticsFixtureHome", "Club" if domicile else "Fiche club"], ["TacticsFixtureAway", "Fiche club" if domicile else "Club"], ["TacticsFixtureCompetitionLien", "Classements"], ["TacticsFixtureDateLien", "Calendrier"], ["TacticsFixtureVenueLien", "Club" if domicile else "Fiche club"], ["TacticsPlanModify", "Composition"], ["TacticsDefenseSummaryLien", "Composition"]]:
		await composition()
		var b := named(paire[0]) as Button
		check(b != null, "Présent : " + str(paire[0]))
		if b == null: continue
		b.pressed.emit()
		await settle()
		check(app.route == paire[1], "%s → %s (route : %s)" % [paire[0], paire[1], app.route])
		# Plan et Défense : onglet Consignes de la même page.
		if str(paire[0]) in ["TacticsPlanModify", "TacticsDefenseSummaryLien"]: check(int(app.management_ui.get("tactique_onglet", 0)) == 1, "%s → onglet Consignes" % paire[0])
	for paire: Array in [["TacticsCountStartersLien", -1], ["TacticsCountBenchLien", 15], ["TacticsCountFrontRowLien", 0]]:
		await composition()
		app.selected_slot = 7
		var b := named(paire[0]) as Button
		check(b != null, "Présent : " + str(paire[0]))
		if b == null: continue
		b.pressed.emit()
		await settle()
		var attendu: int = paire[1]
		check(app.route == "Composition" and (app.selected_slot == attendu if attendu >= 0 else app.selected_slot < 15) and named("TacticsCandidateRows") != null, "%s → candidats du n° %d" % [paire[0], app.selected_slot + 1])
	await composition()
	var valide := named("TacticsValidityLien") as Button
	if valide != null:
		valide.pressed.emit()
		await settle()
		check(app.route == "Composition" and (named("TacticsValidate") as Control).has_focus(), "Pastille Valide → bouton Valider la feuille")
	else:
		check(named("TacticsCorriger") != null, "Pastille Incomplète → place à corriger")

func _contient_texte(noeud: Node, morceau: String) -> bool:
	if noeud == null: return false
	for n in noeud.find_children("*", "Label", true, false):
		if (n as Label).text.contains(morceau): return true
	return false

func proche_de_l_or(couleur: Color) -> bool:
	return couleur.a > .05 and (Color(couleur, 1).is_equal_approx(Charte.OR) or Color(couleur, 1).is_equal_approx(Charte.OR_VIF))

## Aplats dorés posés par l'écran : fonds de bouton ou de panneau, rectangles et ovales dessinés. Le texte doré, les contours
## et l'anneau de focus restent permis (charte finale) ; Continuer, dans la coque, porte le seul aplat doré.
func couleurs_or(node: Node) -> Array[String]:
	var found: Array[String] = []
	if node is Control:
		var control := node as Control
		for nom in ["panel", "normal", "hover", "pressed"]:
			if control.has_theme_stylebox_override(nom):
				var style := control.get_theme_stylebox(nom) as StyleBoxFlat
				if style != null and proche_de_l_or(style.bg_color): found.append(str(control.name) + "/" + nom)
		for propriete in ["fond", "couleur", "color"]:
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
		check(rp.size.y > rp.size.x * 1.25 and rp.size.y < rp.size.x * 1.7, "Terrain vertical, en-buts en haut et en bas (%s)" % str(rp.size))
		check(rp.end.x <= bench.get_global_rect().position.x + 1 and bench.get_global_rect().end.x <= impact.get_global_rect().position.x + 1, "Terrain, banc, impact de gauche à droite")
		check(under.get_global_rect().position.y >= bench.get_global_rect().end.y - 1 and under.get_global_rect().position.x >= rp.end.x - 1, "Candidats sous le banc, à droite du terrain")
		# Attaque vers le haut : avants devant (en haut), arrière au fond (en bas), pastille « ▲ ATTAQUE » en haut.
		var centre := func(n: int) -> float: return named("LineupSlot%02d" % n).get_global_rect().get_center().y if named("LineupSlot%02d" % n) != null else -1.0
		check(centre.call(2) < centre.call(8) and centre.call(8) < centre.call(9) and centre.call(9) < centre.call(12) and centre.call(12) < centre.call(15), "Avants en haut, charnière, centres, arrière en bas")
		var attaque := named("TacticsAttackDirection")
		check(attaque != null and attaque.get_global_rect().get_center().y < centre.call(1), "Pastille « ▲ ATTAQUE » en haut du terrain")
		for i in 15:
			var carte := named("LineupSlot%02d" % (i + 1))
			check(carte != null and rp.encloses(carte.get_global_rect()), "Carte du n° %d dans le terrain" % (i + 1))
	check(named("BenchPlayerRows") != null and named("BenchPlayerRows").get_child_count() == 8, "Banc : huit places")
	var bar: VScrollBar = (app.body_scroll as ScrollContainer).get_v_scroll_bar()
	check(bar.max_value <= bar.page + 1, "1920 × 1080 : l'écran tient sans défiler (%s / %s)" % [str(bar.max_value), str(bar.page)])
	check(couleurs_or(page).is_empty(), "Aucun aplat doré dans l'écran (Continuer le porte seul) : " + ", ".join(couleurs_or(page)))
	# Charte finale §3 (arrondis) : panneaux rayon 18, lignes et cases rayon 6, onglets en pilule ; aucun fond plein
	# à angles droits dans l'écran. Le voile à peine teinté du lien survolé (souligné, charte §7.1 « lien ») n'est pas
	# un fond : seuls les aplats d'opacité ≥ 50 % comptent.
	var droits: Array[String] = []
	# Nœuds internes du moteur exclus (« _focus » du ScrollContainer : style du thème, cadre non dessiné ici).
	for noeud in page.find_children("*", "Control", true, false):
		if str(noeud.name).begins_with("_"): continue
		for nom in ["panel", "normal", "hover", "pressed", "hover_pressed", "disabled", "read_only"]:
			if not (noeud as Control).has_theme_stylebox_override(nom): continue
			var style := (noeud as Control).get_theme_stylebox(nom) as StyleBoxFlat
			if style != null and style.bg_color.a >= .5 and (style.corner_radius_top_left <= 0 or style.corner_radius_bottom_right <= 0): droits.append(str(noeud.name) + "/" + nom)
	check(droits.is_empty(), "Aucun fond à angles droits dans l'écran (charte §3) : " + ", ".join(droits.slice(0, 6)))
	for id in ["TacticsBench", "TacticsImpact", "TacticsCandidates"]:
		var bloc_style := named(id).get_theme_stylebox("panel") as StyleBoxFlat if named(id) != null else null
		check(bloc_style != null and bloc_style.corner_radius_top_left == maxi(3, C.px(Charte.RAYON_PANNEAU)), "Panneau %s : rayon 18 (charte §3)" % id)
	var onglet := named("TacticsTab0") as Button
	if onglet == null: onglet = named("TacticsTab3") as Button
	var onglet_style := onglet.get_theme_stylebox("normal") as StyleBoxFlat if onglet != null else null
	check(onglet_style != null and onglet_style.corner_radius_top_left >= Charte.RAYON_PILULE, "Onglets en pilule (charte §7.1)")
	# Tout bouton visible fait quelque chose (pressed relié), sauf cases et listes qui ont leur propre signal.
	var muets: Array[String] = []
	for node in page.find_children("*", "BaseButton", true, false):
		var bouton := node as BaseButton
		if bouton is CheckBox or bouton is OptionButton or bouton is MenuButton or not bouton.is_visible_in_tree(): continue
		if bouton.pressed.get_connections().is_empty(): muets.append(str(bouton.name))
	check(muets.is_empty(), "Aucune zone cliquable sans effet : " + ", ".join(muets))
	await capture("composition-1920")
	await entete_visuel()

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
	# 4 bis. Liste des candidats : le pourcentage de condition ne touche jamais le statut (2560 et 1920).
	for taille in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = taille
		await settle(6)
		var rangs := 0
		var colles: Array[String] = []
		for ligne in named("TacticsCandidateRows").get_children():
			var statut := ligne.find_child("TacticsCandidateStatus", true, false) as Label
			if statut == null: continue
			for enfant in ligne.get_children():
				var pourcent := enfant as Label
				if pourcent == null or not pourcent.text.ends_with("%"): continue
				rangs += 1
				var fonte := pourcent.get_theme_font("font")
				var texte_l := fonte.get_string_size(pourcent.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pourcent.get_theme_font_size("font_size")).x
				var droite := pourcent.global_position.x + pourcent.size.x
				if texte_l > pourcent.size.x + 1 or droite > statut.global_position.x - 8: colles.append("%s | %s" % [pourcent.text, statut.text])
		check(rangs > 3 and colles.is_empty(), "%d : pourcentage de condition distinct du statut (%d lignes) : %s" % [taille.x, rangs, ", ".join(colles.slice(0, 4))])
		await capture("composition-candidats-%d" % taille.x)
	root.size = Vector2i(1920, 1080)
	await settle(4)
	(named("CandidateSort_condition") as Button).pressed.emit()
	await settle()
	check(app.management_ui.candidates_reading.key == "condition", "Tri des candidats par condition")
	(named("CandidateSort_note") as Button).pressed.emit()
	await settle()
	var lignes := named("TacticsCandidateRows")
	var eligibles: Array = Selection.slot(app.model, 9).get("eligibleIds", [])
	# Tri cohérent (25/11) : les indisponibles et non qualifiés restent sous un séparateur visible, jamais mêlés au tri.
	var separateur := lignes.find_child("TacticsCandidatesSeparateur", false, false) as Control if lignes != null else null
	var melange := 0
	var grises := 0
	for ligne in (lignes.get_children() if lignes != null else []):
		if not ligne is Button: continue
		var gris := not bool(ligne.get_meta("eligible", true))
		if gris: grises += 1
		if separateur != null and gris and (ligne as Control).position.y < separateur.position.y: melange += 1
	check(grises == 0 or (separateur != null and separateur.is_visible_in_tree()), "Candidats : séparateur visible au-dessus des indisponibles (%d grisés)" % grises)
	check(melange == 0, "Candidats : aucun indisponible mêlé aux choisissables (%d)" % melange)
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

	# 5 bis. Vraie souris : glisser le n° 12 sur le n° 13 (appui, déplacement, relâche) → échange réel par le moteur.
	await composition()
	var douze := str(Selection.slot(app.model, 11).get("playerId"))
	var treize := str(Selection.slot(app.model, 12).get("playerId"))
	var depart := named("LineupSlot12").get_global_rect().get_center()
	var arrivee := named("LineupSlot13").get_global_rect().get_center()
	await souris(depart, MOUSE_BUTTON_MASK_LEFT)
	await clic(depart, true)
	for etape in range(1, 13): await souris(depart.lerp(arrivee, etape / 12.0), MOUSE_BUTTON_MASK_LEFT)
	await clic(arrivee, false)
	await wait_idle()
	await settle()
	check(str(Selection.slot(app.model, 11).get("playerId")) == treize and str(Selection.slot(app.model, 12).get("playerId")) == douze, "Glisser-déposer à la souris : échange réel des n° 12 et 13")
	# Vrai clic sur une carte du terrain : ses candidats dessous.
	await composition()
	var point_7 := named("LineupSlot07").get_global_rect().get_center()
	await souris(point_7)
	await clic(point_7, true)
	await clic(point_7, false)
	await settle()
	check(app.selected_slot == 6, "Clic souris sur le n° 7 : ses candidats")
	# Vrai survol d'un nom : la carte joueur apparaît après le délai, sans fenêtre.
	await souris(Vector2(4, 4))
	await settle(4)
	var nom_survol := named("TacticsName10") as Control
	if nom_survol != null:
		# Règle de Léo (25/11) : le survol du NOM ne fait rien ; seul le bouton (i) ouvre la carte, après 0,5 s.
		await souris(nom_survol.get_global_rect().get_center())
		await attendre_ms(1000)
		check(Carte.actuelle(app) == null, "Survol du nom du n° 10 pendant 1 s : aucune carte")
		var info_survol := nom_survol.find_child("CarteJoueurInfo_*", false, false) as Control
		check(info_survol != null and info_survol.has_meta("carte_info") and info_survol.is_visible_in_tree(), "Nom du n° 10 : bouton (i) visible")
		if info_survol != null:
			var ecran_vue := Rect2(Vector2.ZERO, Vector2(root.size))
			check(ecran_vue.encloses(info_survol.get_global_rect()) and info_survol.size.x >= 14.0, "Bouton (i) du n° 10 : entier dans l'écran")
			await souris(Vector2(4, 4))
			await settle(4)
			await souris(info_survol.get_global_rect().get_center())
			await attendre_ms(250)
			check(Carte.actuelle(app) == null, "Survol court du (i) (0,25 s) : aucune carte")
			await souris(Vector2(4, 4))
			await attendre_ms(100)
			await souris(info_survol.get_global_rect().get_center())
			var limite := Time.get_ticks_msec() + 3000
			while Carte.actuelle(app) == null and Time.get_ticks_msec() < limite: await process_frame
			check(Carte.actuelle(app) != null and windows(app).is_empty(), "Survol souris du (i) du n° 10 : carte joueur")
			await souris(Vector2(4, 4))
			await settle(10)
			check(Carte.actuelle(app) == null, "Souris partie : la carte se ferme")
	# Touche I sur une carte du XV : montre puis cache la carte joueur.
	await composition()
	named("LineupSlot06").grab_focus()
	await settle()
	await key(KEY_I)
	check(Carte.actuelle(app) != null, "Touche I : carte joueur du n° 6")
	named("LineupSlot06").grab_focus()
	await key(KEY_I)
	check(Carte.actuelle(app) == null, "Touche I de nouveau : la carte se ferme")
	# Suppr sur une carte du XV : « Libérer » demande confirmation, Annuler garde le joueur.
	var sixieme := str(Selection.slot(app.model, 5).get("playerId"))
	named("LineupSlot06").grab_focus()
	await settle()
	await key(KEY_DELETE)
	var confirme := app.get_node_or_null("LineupReleaseConfirm") as ConfirmationDialog
	check(confirme != null and confirme.visible, "Suppr : confirmation avant de libérer le n° 6")
	if confirme != null: confirme.get_cancel_button().pressed.emit()
	await settle()
	check(str(Selection.slot(app.model, 5).get("playerId")) == sixieme, "Suppr puis Annuler : le n° 6 reste")

	# 5 ter. Hors groupe : tout le reste de l'effectif en tuiles, filtres par ligne, glisser-déposer à la vraie souris.
	await composition()
	(named("TacticsBottomOutside") as Button).pressed.emit()
	await settle()
	var hors_hg: Array = Vertical.hors_groupe_joueurs(app)
	check(named("TacticsHorsGroupe") != null and named("TacticsOutsideTiles") != null and named("TacticsOutsideTiles").get_child_count() == hors_hg.size(), "Hors groupe : une tuile par joueur hors feuille (%d)" % hors_hg.size())
	var coupes_hg: Array[String] = []
	for tuile_hg in named("TacticsOutsideTiles").get_children():
		for n in (tuile_hg as Node).find_children("TacticsOutsideName_*", "Button", true, false):
			var b := n as Button
			if b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x > b.size.x + 2: coupes_hg.append(b.text)
		if not (tuile_hg as Control).get_global_rect().grow(1).encloses(((tuile_hg as Node).find_child("TacticsOutsideName_*", true, false) as Control).get_global_rect()): coupes_hg.append(str(tuile_hg.name))
	check(coupes_hg.is_empty(), "Hors groupe : noms entiers dans leur tuile " + str(coupes_hg.slice(0, 4)))
	for p: Dictionary in hors_hg:
		var etat_d_hg: Dictionary = Commune.disponibilite(app, p, "squad")
		if etat_d_hg.etat in ["blesse", "suspendu"]:
			var t := named("TacticsOutside_" + str(p.get("id", "")).validate_node_name())
			check(t != null and t.find_child("TacticsOutsideState", true, false) != null, "Hors groupe : %s visible, grisé, pastille d'état" % str(p.get("name", "")))
	(named("TacticsOutsideLine_1re") as Button).pressed.emit()
	await settle()
	var premiere_ok_hg := true
	for tuile_hg in named("TacticsOutsideTiles").get_children():
		var pp_hg: Variant = Selection.player(app.model, str(tuile_hg.get_meta("player_id", ""))).get("primaryPosition")
		if not (pp_hg is int or pp_hg is float) or int(pp_hg) > 3: premiere_ok_hg = false
	check(premiere_ok_hg, "Filtre « 1re ligne » : seulement des piliers et talonneurs")
	(named("TacticsOutsideLine_tous") as Button).pressed.emit()
	await settle()
	# Hors groupe → poste : un joueur apte et éligible glissé sur une place du terrain ou du banc.
	var choix_hg := {}
	for p: Dictionary in hors_hg:
		if Commune.disponibilite(app, p, "squad").etat in ["blesse", "suspendu"]: continue
		for place in 23:
			if str(p.get("id", "")) in Selection.slot(app.model, place).get("eligibleIds", []) and named("TacticsOutside_" + str(p.get("id", "")).validate_node_name()) != null:
				choix_hg = {"id": str(p.get("id", "")), "place": place}
				break
		if not choix_hg.is_empty(): break
	check(not choix_hg.is_empty(), "Un joueur hors groupe apte et éligible à une place")
	if not choix_hg.is_empty():
		var tuile_d := named("TacticsOutside_" + str(choix_hg.id).validate_node_name())
		(named("TacticsOutsideScroll") as ScrollContainer).ensure_control_visible(tuile_d)
		await settle()
		var cible_p := named("LineupSlot%02d" % (int(choix_hg.place) + 1))
		var pendant_hg := func():
			check(root.gui_is_dragging(), "Glisser depuis le hors groupe : la tuile suit la souris")
			check(int(cible_p.get_meta("depot", 0)) == 2 and cible_p.find_child("TacticsDropPreview", true, false) != null, "Place survolée en surbrillance avec la pastille au poste du joueur traîné")
			await capture("composition-glisser")
		await glisser_souris(tuile_d.get_global_rect().get_center(), cible_p.get_global_rect().get_center(), pendant_hg)
		check(str(Selection.slot(app.model, int(choix_hg.place)).get("playerId")) == str(choix_hg.id), "Hors groupe → n° %d : affectation réelle" % (int(choix_hg.place) + 1))
	# Refus du jeu : un trois-quarts glissé sur le n° 1 (pilier) → rouge, rien ne change.
	await composition()
	var refuse_hg := {}
	for p: Dictionary in Vertical.hors_groupe_joueurs(app):
		if str(p.get("id", "")) not in Selection.slot(app.model, 0).get("eligibleIds", []) and named("TacticsOutside_" + str(p.get("id", "")).validate_node_name()) != null:
			refuse_hg = p
			break
	if not refuse_hg.is_empty():
		var avant_1 := str(Selection.slot(app.model, 0).get("playerId"))
		var tuile_r := named("TacticsOutside_" + str(refuse_hg.get("id", "")).validate_node_name())
		(named("TacticsOutsideScroll") as ScrollContainer).ensure_control_visible(tuile_r)
		await settle()
		var pilier_d := named("LineupSlot01")
		var pendant_r := func(): check(int(pilier_d.get_meta("depot", 0)) == -1, "Place refusée par le jeu : contour rouge ✕")
		await glisser_souris(tuile_r.get_global_rect().get_center(), pilier_d.get_global_rect().get_center(), pendant_r)
		check(str(Selection.slot(app.model, 0).get("playerId")) == avant_1, "Refus : le n° 1 ne change pas")
	# Banc → terrain : un remplaçant glissé sur une place du XV qu'il peut tenir (échange).
	await composition()
	var paire_hg := []
	for b in range(15, 23):
		var id_b_hg := str(Selection.slot(app.model, b).get("playerId"))
		for t in 15:
			if id_b_hg in Selection.slot(app.model, t).get("eligibleIds", []):
				paire_hg = [b, t, id_b_hg, str(Selection.slot(app.model, t).get("playerId"))]
				break
		if not paire_hg.is_empty(): break
	check(not paire_hg.is_empty(), "Un remplaçant éligible à une place du XV")
	if not paire_hg.is_empty():
		await glisser_souris(named("LineupSlot%02d" % (paire_hg[0] + 1)).get_global_rect().get_center(), named("LineupSlot%02d" % (paire_hg[1] + 1)).get_global_rect().get_center())
		check(str(Selection.slot(app.model, paire_hg[1]).get("playerId")) == paire_hg[2], "Banc n° %d → terrain n° %d : affectation réelle" % [paire_hg[0] + 1, paire_hg[1] + 1])
	# Retour au hors_hg groupe : le n° 20 glissé sur le panneau Hors groupe quitte la feuille.
	await composition()
	var vingt_hg := str(Selection.slot(app.model, 19).get("playerId"))
	await glisser_souris(named("LineupSlot20").get_global_rect().get_center(), named("TacticsHorsGroupe").get_global_rect().get_center() + Vector2(0, 40))
	check(Selection.slot(app.model, 19).get("playerId") == null and Selection.source(app.model, vingt_hg) < 0, "Place du banc glissée sur le hors groupe : le joueur quitte la feuille")
	app._command("auto_lineup")
	await wait_idle()
	Selection.state(app).bas = "candidats"

	# 6. Noms : survol = carte joueur (Control, aucune fenêtre), clic = fiche complète.
	await composition()
	var nom := named("TacticsName02") as Button
	check(nom != null, "Nom du n° 2 cliquable")
	if nom != null:
		check(nom.has_meta("carte_joueur"), "Nom du n° 2 : carte joueur liée (ouverte par son bouton (i))")
		var carte := Carte.montrer(app, str(nom.get_meta("carte_joueur")), "squad", nom)
		await settle()
		check(carte != null and Carte.actuelle(app) != null and windows(app).is_empty(), "Survol du nom : carte joueur sans fenêtre")
		Carte.cacher(app)
		nom.mouse_exited.emit()
		await settle()
		var id := str(Selection.slot(app.model, 1).get("playerId"))
		var centre_nom := nom.get_global_rect().get_center()
		await souris(centre_nom)
		await clic(centre_nom, true)
		await clic(centre_nom, false)
		await settle()
		check(app.route == "Effectif" and app.get_meta("immersive08_full_player", false) and app.selected_player == id, "Clic réel sur le nom : fiche complète (Effectif)")

	# 7. Onglets et liens : chacun change d'écran.
	# Onglets Consignes, Phases arrêtées, Entraînement : même page, même en-tête (tactics_onglets.gd).
	for paire: Array in [["TacticsTab1", 1], ["TacticsTab2", 2], ["TacticsTab4", 4], ["TacticsPlanModify", 1]]:
		await composition()
		var bouton_onglet := named(paire[0]) as Button
		check(bouton_onglet != null, "Présent : " + str(paire[0]))
		if bouton_onglet == null: continue
		bouton_onglet.pressed.emit()
		await settle()
		check(app.route == "Composition" and int(app.management_ui.get("tactique_onglet", 0)) == paire[1] and named("TacticsTabTitle") != null and named("TacticsFixtureHome") != null, "%s ouvre l'onglet %d" % [paire[0], paire[1]])
		var complet := named("TacticsTabOpenFull") as Button
		check(complet != null, "Onglet %d : bouton vers l'écran complet" % paire[1])
	await entrainement_facon_effectif()
	app.management_ui.tactique_onglet = 0
	await composition()
	var dossier := named("TacticsOpponentFile") as Button
	if dossier != null:
		dossier.pressed.emit()
		await settle()
		check(app.route == "Préparation", "TacticsOpponentFile ouvre Préparation")
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
		for bouton in noms_vigilance: check(bouton.has_meta("carte_joueur") and not str((bouton as Button).text).ends_with("…"), "Vigilance : carte joueur et nom entier · " + (bouton as Button).text)
		check(named("TacticsWarnings") is MenuButton and (named("TacticsWarnings") as MenuButton).get_popup().item_count == sous_80, "Avertissements : menu déroulant de %d joueurs" % sous_80)
		check(named("TacticsWarningName") != null and named("TacticsWarningName").has_meta("carte_joueur"), "Ligne de validité : nom du premier avertissement → fiche + carte joueur")
	var conseil := named("TacticsStaffAdvice0")
	if conseil != null: check(not conseil.find_children("*Nom*", "Button", true, false).is_empty(), "Bulle de Gabi : noms cliquables")
	var duel := named("TacticsDuel_scrum") as Button
	if duel != null:
		duel.pressed.emit()
		await settle()
		check(app.route == "Préparation", "Duel « Mêlée » : ouvre le dossier adverse")
		await composition()
	check(named("TacticsFrontRowName01") == null or named("TacticsFrontRowName01").has_meta("carte_joueur"), "Encart : noms → fiche + carte joueur")
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
