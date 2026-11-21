extends SceneTree
## Entracte du match, mise en page « Bord de terrain » (choix de Léo du 21/11/2026 ; avant : direction artistique du
## 19/11/2026), sans moteur : une projection `live.direct` complète posée sur l'écran (match_between.gd) en 2560×1440
## (référence de Léo) et 1920×1080 (1280×720 ne compte pas pour cet écran, décision de Léo du 21/11/2026). Vérifie : les blocs de la
## maquette à l'écran et dans l'écran ; tout ce qui a l'air cliquable fait quelque chose (signal, panneau, vue,
## commande) ; aucun clic n'ouvre de fenêtre (seul le menu « Plus ▾ » est un menu déroulant, exception de Léo) ;
## un seul aplat doré (bouton principal) ; aucun texte sous 12 px ; les noms mènent à la fiche (survol :
## mini-fiche) ; le panneau d'arrêt prend la colonne de droite et bloque Équipe jusqu'au choix ; le clavier
## (Espace, Échap, T) suit la fiche UX. Charte finale du 20/11/2026 (design/art/art-bible.md) : panneaux arrondis sans
## cadre, cases et lignes à 6 px, aucune bande alternée, titres droits, nous vert clair / adversaire doré dans les
## comparaisons (jamais la couleur d'un club), rouge réservé aux cartons.
const Between = preload("res://ui/contextual/match_between.gd")
const Charte = preload("res://ui/charte.gd")
var checks := 0
var failures: Array[String] = []
var signaux: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func fausse_app() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Control\nvar envois: Array = []\nvar model: Dictionary = {}\nfunc _command(command: String, payload: Dictionary = {}, _route: String = \"\") -> bool:\n\tenvois.append([command, payload])\n\treturn true\n"
	script.reload()
	var app := Control.new()
	app.set_script(script)
	return app

func fausse_vue(app: Node) -> Control:
	var script := GDScript.new()
	script.source_code = "extends Control\nvar app: Node\n"
	script.reload()
	var vue := Control.new()
	vue.set_script(script)
	vue.set("app", app)
	vue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return vue

const POSTES := ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne", "Troisième ligne", "Numéro 8",
	"Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]

func donnees() -> Array:
	var equipes := [{"id": 102, "name": "Alder Fen XV", "abbr": "AFN", "color": "#b8343c"}, {"id": 7, "name": "Trentwood Archers", "abbr": "TWA", "color": "#2a5bd7"}]
	var lineup: Array = []
	var notes := {}
	var feuille := {"joueurs": {}}
	for n in 15:
		var id := "p%d" % (n + 1)
		lineup.append({"id": id, "name": "Darren DOWNES" if n == 12 else "Joueur Numéro%d" % (n + 1), "pos": POSTES[n], "condition": 38 if n == 6 else 70 + n, "injury": 0})
		notes[id] = {"note": 6.0 + n * 0.1, "faits": n}
		feuille.joueurs[id] = {"camp": 0, "plaquages": n % 7, "plaquagesManques": 1, "metres": n * 3, "essais": 1 if n == 11 else 0, "courses": 2, "passes": 3}
	var reserves: Array = []
	# Le 21 porte le nom le plus long du banc d'un vrai match (« Matthew BOOTHROYD ») : il doit se lire en entier.
	for n in 8: reserves.append({"id": "r%d" % (n + 16), "name": "Matthew BOOTHROYD" if n == 5 else "Remplaçant Banc%d" % (n + 16), "pos": POSTES[n % 15]})
	var live := {"teams": equipes, "events": [], "finished": false, "paused": false, "atBreak": true, "minute": 40, "lineup": lineup, "reserves": reserves, "remplacementsRestants": 8,
		"pilotage": {"conseilChangement": {"outId": "p7", "inId": "r20"}}}
	var tableau := [
		{"cle": "possession", "label": "Possession", "valeurs": [54, 46], "unite": "%"},
		{"cle": "occupation", "label": "Occupation", "valeurs": [58, 42], "unite": "%"},
		{"cle": "plaquages", "label": "Plaquages réussis", "valeurs": [55, 78]},
		{"cle": "plaquages_manques", "label": "Plaquages manqués", "valeurs": [5, 16]},
		{"cle": "melees", "label": "Mêlées gagnées", "valeurs": [4, 3], "sur": [5, 4]},
		{"cle": "touches", "label": "Touches gagnées", "valeurs": [7, 5], "sur": [8, 7]},
		{"cle": "penalites", "label": "Pénalités concédées", "valeurs": [4, 6]}]
	var minutes: Array = []
	for m in 40: minutes.append(int(sin(m * 0.4) * 60.0))
	var direct := {"camp": 0, "score": [10, 7], "borne": 0, "cartons": [{"id": "p13", "retour": 42}], "fil": [{"i": 3, "horloge": "38′", "kind": "try", "equipe": 0, "texte": "AFN · Essai de Joueur Numéro12."}], "tableau": tableau,
		"zone22": {"entrees": [5, 3], "points": [10, 7], "secondes": [150, 40]}, "domination": {"minutes": minutes, "miTemps": null},
		"reperes": [{"i": 3, "kind": "try", "equipe": 0, "horloge": "38′", "minute": 38, "x": 95, "nom": "Joueur Numéro12", "score": [10, 7]}, {"i": 2, "kind": "goal", "equipe": 1, "horloge": "12′", "minute": 12, "x": 20, "score": [0, 3]}, {"i": 1, "kind": "goal", "equipe": 1, "horloge": "13′", "minute": 13, "x": 20, "score": [0, 6]}], "notes": notes, "feuille": feuille, "possession": 0, "zone": {"x": 60},
		"niveaux": [{"id": "aucun", "label": "Aucun"}, {"id": "resume", "label": "Résumé"}, {"id": "cles", "label": "Clés"}, {"id": "etendus", "label": "Étendus"}, {"id": "dynamique", "label": "Dynamique"}, {"id": "integral", "label": "Intégral"}],
		"niveau": "dynamique", "echantillon": {"minutes": 40, "suffisant": true, "seuil": 10},
		"journee": {"minute": 40, "classement": [{"rang": 1, "abbr": "HCX", "points": 9, "clubId": 1}, {"rang": 2, "abbr": "AFN", "points": 8, "clubId": 102, "nous": true}],
			"matchs": [{"id": "m1", "minute": 40, "home": {"abbr": "BTB", "score": 10, "id": 3}, "away": {"abbr": "GCR", "score": 6, "id": 4}}]}}
	return [equipes, live, direct]

func dans(r: Rect2, ecran: Vector2) -> bool:
	return Rect2(Vector2.ZERO, ecran).grow(1.0).encloses(r)

func etat(ecran: Control, app: Node) -> String:
	var fiche: Variant = ecran.get("fiche_match")
	return JSON.stringify([signaux.size(), ecran.vue_droite, ecran.vue_xv, fiche != null and is_instance_valid(fiche), (app.get("envois") as Array).size(), ecran.horloge, ecran.niveau_libelle(), ecran.tri_xv, ecran.tri_inverse])

## Couleurs posées sur un contrôle (polices et styles) : aucune ne doit être l'or de Continuer.
## Aplat doré = fond (opaque) d'un bouton ou d'un panneau, dans l'un de ses états ; texte, contour et anneau permis.
func aplat_or(noeud: Control) -> bool:
	for cle in ["normal", "hover", "pressed", "disabled", "panel"]:
		if noeud.has_theme_stylebox_override(cle):
			var s := noeud.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null and s.bg_color.a > .05 and (Color(s.bg_color, 1.0).is_equal_approx(Charte.OR) or Color(s.bg_color, 1.0).is_equal_approx(Charte.OR_VIF)): return true
	return false

func ors(noeud: Control) -> Array:
	var trouves: Array = []
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		if noeud.has_theme_color_override(cle):
			var c := noeud.get_theme_color(cle)
			if c.is_equal_approx(Charte.OR) or c.is_equal_approx(Charte.OR_VIF): trouves.append(cle)
	for cle in ["normal", "hover", "pressed", "focus", "disabled", "panel"]:
		if noeud.has_theme_stylebox_override(cle):
			var s := noeud.get_theme_stylebox(cle) as StyleBoxFlat
			if s != null:
				for c: Color in [s.bg_color, s.border_color]:
					if Color(c, 1.0).is_equal_approx(Charte.OR) or Color(c, 1.0).is_equal_approx(Charte.OR_VIF): trouves.append(cle)
	return trouves

func run() -> void:
	for taille: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = taille
		var cadre := "%dx%d" % [taille.x, taille.y]
		var app := fausse_app()
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(app)
		var vue := fausse_vue(app)
		root.add_child(vue)
		var ecran: Control = Between.new()
		ecran.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vue.add_child(ecran)
		for i in 4: await process_frame
		signaux.clear()
		for nom in ["tiroir_demande", "joueur_choisi", "reprise_demandee", "pause_demandee", "horloge_choisie", "niveau_choisi", "delegation_demandee", "camera_demandee", "consigne_bonus", "fiche_ouverte", "journal_demande", "stats_demandees", "club_demande", "confier_fin_demande", "stat_demandee", "match_demande"]:
			var signal_nom: String = nom
			ecran.connect(signal_nom, func(a = null, _b = null): signaux.append([signal_nom, a]))
		# Plein écran obligatoire : un joueur cliqué ouvre sa petite fenêtre (branchée par la régie ; ici, un signal noté).
		ecran.fiche_vers = func(id: String): signaux.append(["fiche", id])
		var d := donnees()
		ecran.update_frame({}, d[1], d[2], func(_c): pass)
		for i in 6: await process_frame
		var ecran_rect := Vector2(taille)
		# Blocs de la maquette, visibles et entiers dans l'écran.
		for nom in ["MatchBetweenMain", "MatchBetweenPitchTile", "MatchBetweenDuel", "MatchBetweenMomentumTile", "MatchBetweenAdviceCard", "MatchBetweenKeys"]:
			var bloc := ecran.find_child(nom, true, false) as Control
			check(bloc != null and bloc.is_visible_in_tree() and dans(bloc.get_global_rect(), ecran_rect), cadre + " : bloc %s visible dans l'écran (%s)" % [nom, str(bloc.get_global_rect()) if bloc != null else "absent"])
		var bas := (ecran.find_child("MatchBetweenMain", true, false) as Control).get_global_rect()
		var centre := (ecran.find_child("MatchBetweenPitchTile", true, false) as Control).get_global_rect()
		var gauche := (ecran.find_child("MatchBetweenDuel", true, false) as Control).get_global_rect()
		var miroirs: Array = [ecran.find_child("MatchBetweenMirror0", true, false), ecran.find_child("MatchBetweenMirror1", true, false)]
		check(gauche.end.x <= centre.position.x and bas.position.y >= centre.end.y and miroirs.all(func(m: Variant): return m is Control and (m as Control).is_visible_in_tree()) and (miroirs[0] as Control).get_global_rect().end.x <= centre.position.x + 1.0 and (miroirs[1] as Control).get_global_rect().position.x >= centre.end.x - 1.0, cadre + " : événements à gauche, terrain au centre entre les chiffres en miroir, Mon XV en barre basse")
		check(centre.get_area() > gauche.get_area() and centre.size.x > (miroirs[0] as Control).size.x, cadre + " : le terrain est le plus grand bloc")
		var lignes: Array = ecran.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer"))
		check(lignes.size() == 15, cadre + " : quinze lignes dans Mon XV (%d)" % lignes.size())
		var entete := ecran.find_child("MatchBetweenSquadHeader", true, false)
		var colonnes: Array = entete.find_children("MatchBetweenSort_*", "Button", true, false).map(func(b: Button): return str(b.get_meta("libelle"))) if entete != null else []
		check(colonnes == ["N°", "JOUEUR", "ÉNERGIE", "PLAQ.", "NOTE"], cadre + " : colonnes de Mon XV avec Plaquages " + str(colonnes))
		# Tri par l'en-tête : énergie la plus basse d'abord, note la plus haute d'abord, second clic = sens inverse, N° = postes.
		var ordre_lignes := func() -> Array: return ecran.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer")).map(func(n: Node): return str(n.name).trim_prefix("MatchBetweenPlayer").to_int())
		(entete.find_child("MatchBetweenSort_energie", true, false) as Button).pressed.emit()
		check(ordre_lignes.call()[0] == 7 and (entete.find_child("MatchBetweenSort_energie", true, false) as Button).text.ends_with("▲"), cadre + " : tri par énergie, le plus fatigué (7) en tête " + str(ordre_lignes.call().slice(0, 3)))
		(entete.find_child("MatchBetweenSort_note", true, false) as Button).pressed.emit()
		check(ordre_lignes.call()[0] == 15 and ordre_lignes.call()[-1] == 1, cadre + " : tri par note, la meilleure (15) en tête " + str(ordre_lignes.call().slice(0, 3)))
		(entete.find_child("MatchBetweenSort_note", true, false) as Button).pressed.emit()
		check(ordre_lignes.call()[0] == 1 and (entete.find_child("MatchBetweenSort_note", true, false) as Button).text.ends_with("▼"), cadre + " : second clic, sens inverse " + str(ordre_lignes.call().slice(0, 3)))
		(entete.find_child("MatchBetweenSort_numero", true, false) as Button).pressed.emit()
		check(ordre_lignes.call() == range(1, 16), cadre + " : « N° » revient à l'ordre des postes " + str(ordre_lignes.call()))
		ecran.choisir_vue_xv("adverse")
		check((entete.find_child("MatchBetweenSort_note", true, false) as Button).disabled, cadre + " : tri grisé sur le XV adverse")
		ecran.choisir_vue_xv("tableau")
		var ligne7: Node = ecran.xv.find_child("MatchBetweenPlayer7", true, false)
		var textes7: Array = ligne7.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if ligne7 != null else []
		check(textes7.has("épuisé") and textes7.has("! 38 %"), cadre + " : l'alerte s'écrit en mots et en chiffres " + str(textes7))
		var ligne1: Node = ecran.xv.find_child("MatchBetweenPlayer1", true, false)
		var plaq1: Array = ligne1.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if ligne1 != null else []
		check(plaq1.has("0") and plaq1.has("6,0"), cadre + " : plaquages et note réels du joueur " + str(plaq1))
		var banc: Array = ecran.banc.get_children().filter(func(n: Node): return n is Button)
		check(banc.size() == 8 and ecran.precision_banc.text.contains("8 changements possibles"), cadre + " : banc de huit et changements restants (%d, %s)" % [banc.size(), ecran.precision_banc.text])
		var chiffres: Array = ecran.chiffres.get_children().map(func(n: Node): return str(n.name).trim_prefix("MatchBetweenFigure_"))
		check(chiffres == ["possession", "occupation", "penalites", "zone22", "plaquages_reussis", "melees", "touches"], cadre + " : chiffres clés de la maquette, données réelles " + str(chiffres))
		var reussis: Node = ecran.chiffres.find_child("MatchBetweenFigure_plaquages_reussis", true, false)
		var textes_reussis: Array = reussis.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if reussis != null else []
		check(textes_reussis.has("92 %") and textes_reussis.has("83 %"), cadre + " : plaquages réussis = réussis / tentés " + str(textes_reussis))
		var remplacer := ecran.find_child("MatchBetweenReplace", true, false) as Button
		check(remplacer != null and remplacer.text == "Remplacer le 7 par Banc20 →", cadre + " : Gabi propose le remplaçant conseillé (%s)" % (remplacer.text if remplacer != null else "absent"))
		check(ecran.phase.text.begins_with("Mi-temps"), cadre + " : la barre dit la mi-temps (%s)" % ecran.phase.text)
		# Aucun texte sous 12 px ; l'or n'est un aplat que pour le bouton principal (texte doré permis).
		var petits: Array = []
		var dores: Array = []
		for noeud: Node in ecran.find_children("*", "Control", true, false):
			var c := noeud as Control
			if not c.is_visible_in_tree(): continue
			if (c is Label or c is Button) and c.get_theme_font_size("font_size") < 12: petits.append(str(c.name))
			if aplat_or(c) and not (c is BaseButton): dores.append(str(c.name))
		check(petits.is_empty(), cadre + " : aucun texte sous 12 px " + str(petits.slice(0, 6)))
		# Titres droits (plus de coupe italique), rouge réservé aux cartons (aucun texte rouge).
		var penches: Array = []
		var rouges: Array = []
		for noeud: Node in ecran.find_children("*", "Control", true, false):
			var c := noeud as Control
			if not c.is_visible_in_tree(): continue
			if (c is Label or c is Button) and c.get_theme_font("font") != null and c.get_theme_font("font").resource_path.to_lower().contains("italic"): penches.append(str(c.name))
			if c.has_theme_color_override("font_color") and c.get_theme_color("font_color").is_equal_approx(Charte.ROUGE): rouges.append(str(c.name))
		check(penches.is_empty(), cadre + " : titres droits, aucune coupe italique " + str(penches.slice(0, 6)))
		check(rouges.is_empty(), cadre + " : aucun texte rouge (réservé aux cartons) " + str(rouges.slice(0, 6)))
		# Pas de bandes alternées : lignes de Mon XV et du banc transparentes, filet entre elles (seule une ligne
		# signalée porte le voile doré, avec son mot).
		var bandes: Array = []
		var lignes_vues := 0
		for ligne: Node in ecran.find_children("MatchBetween*", "Button", true, false):
			var n := str(ligne.name)
			if not (n.begins_with("MatchBetweenPlayer") or n.begins_with("MatchBetweenBench")) or n.begins_with("MatchBetweenPlayerName_"): continue
			var normal := (ligne as Control).get_theme_stylebox("normal") as StyleBoxFlat
			if normal == null: continue
			lignes_vues += 1
			# Mon XV en cartes (rayon 12 de la charte), sur le relief ou le voile doré d'une alerte.
			if n.begins_with("MatchBetweenPlayer"):
				if normal.corner_radius_top_left != Charte.RAYON_CARTE or not normal.bg_color.is_equal_approx(Charte.VOILE_DORE if ligne.has_meta("signale") else Charte.PANNEAU_2): bandes.append(n + " carte")
				continue
			if ligne.has_meta("signale"):
				if not normal.bg_color.is_equal_approx(Charte.VOILE_DORE): bandes.append(n + " signalée")
			elif normal.bg_color.a > 0.05 or normal.border_width_bottom < 1: bandes.append(n)
		check(lignes_vues >= 23 and bandes.is_empty(), cadre + " : %d joueurs : cartes de Mon XV rayon 12, banc sans bandes alternées %s" % [lignes_vues, str(bandes.slice(0, 6))])
		# Comparaisons aux couleurs des deux clubs (choix de Léo du 21/11/2026), chiffres en miroir autour du terrain.
		var barres: Array = ecran.chiffres.find_children("*", "Control", true, false).filter(func(n: Node): return n.get("valeurs") != null and n.get("couleurs") != null)
		check(not barres.is_empty() and barres.all(func(b: Control): return (b.get("couleurs") as Array) == ecran._teintes_duel()), cadre + " : barres des chiffres aux couleurs des deux clubs")
		var ligne_miroir := ecran.find_child("MatchBetweenMirror_possession_0", true, false) as Button
		check(ligne_miroir != null and ligne_miroir.is_visible_in_tree() and ecran.find_child("MatchBetweenMirror_possession_1", true, false) != null, cadre + " : chiffres des deux clubs en miroir autour du terrain")
		check(dores.is_empty(), cadre + " : aucun aplat doré hors bouton principal " + str(dores.slice(0, 6)))
		# Banc : zone fixe, entière dans l'écran ; barème des notes écrit ; terrain qui remplit sa tuile.
		var zone_banc := ecran.find_child("MatchBetweenBenchZone", true, false) as Control
		check(zone_banc != null and zone_banc.is_visible_in_tree() and dans(zone_banc.get_global_rect(), ecran_rect) and not (ecran.find_child("MatchBetweenSquadScroll", true, false) as Node).is_ancestor_of(zone_banc), cadre + " : banc dans une zone fixe, visible en entier")
		check(banc.all(func(b: Control): return zone_banc.get_global_rect().grow(1.0).encloses(b.get_global_rect())), cadre + " : les huit remplaçants à l'écran")
		# Défauts du match (20/11) : la dernière ligne de Mon XV et le total de l'équipe sont entiers à l'écran, et aucun
		# nom de joueur (Mon XV, banc) n'est tronqué.
		var defile_xv := ecran.find_child("MatchBetweenSquadScroll", true, false) as ScrollContainer
		var dernier := ecran.find_child("MatchBetweenPlayer15", true, false) as Control
		var total_equipe := ecran.find_child("MatchBetweenTeamTotal", true, false) as Control
		check(dernier != null and defile_xv != null and defile_xv.get_global_rect().grow(1.0).encloses(dernier.get_global_rect()), cadre + " : la dernière ligne de Mon XV (15) est entière dans la zone de défilement (%s dans %s)" % [str(dernier.get_global_rect()) if dernier != null else "absente", str(defile_xv.get_global_rect()) if defile_xv != null else "absent"])
		check(total_equipe != null and total_equipe.is_visible_in_tree() and dans(total_equipe.get_global_rect(), ecran_rect) and not defile_xv.is_ancestor_of(total_equipe) and total_equipe.get_global_rect().end.y <= dernier.get_global_rect().position.y + 1.0, cadre + " : le total « Équipe » est fixe, entier, dans l'en-tête de Mon XV (%s)" % (str(total_equipe.get_global_rect()) if total_equipe != null else "absente"))
		check(not (ecran.tuile_principale as Control).is_ancestor_of(zone_banc) and ecran.banc_cadre.is_ancestor_of(zone_banc), cadre + " : le banc a son cadre, sous les événements")
		for i in 3: await process_frame
		var total_coupe: Array = []
		for etiquette: Label in total_equipe.find_children("*", "Label", true, false):
			var large := etiquette.get_theme_font("font").get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x
			if etiquette.visible and etiquette.size.x + 1.0 < large: total_coupe.append("%s (%d sur %d px)" % [etiquette.text, int(etiquette.size.x), int(large)])
		check(total_coupe.is_empty(), cadre + " : la ligne « Équipe » se lit en entier " + str(total_coupe))
		var coupes: Array = []
		for lien: Button in ecran.find_children("MatchBetweenPlayerName_*", "Button", true, false):
			var entier := str(lien.get_meta("nom_entier", lien.text))
			var largeur := lien.get_theme_font("font").get_string_size(entier, HORIZONTAL_ALIGNMENT_LEFT, -1, lien.get_theme_font_size("font_size")).x
			# Alerte longue à côté du nom : le prénom devient une initiale (« D. DOWNES »), jamais de « … » sur le nom.
			var abrege := lien.text != entier and not lien.text.contains("…") and lien.text.ends_with(entier.get_slice(" ", entier.get_slice_count(" ") - 1))
			var largeur_vue := lien.get_theme_font("font").get_string_size(lien.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lien.get_theme_font_size("font_size")).x
			if (lien.text != entier and not abrege) or (not abrege and lien.size.x + 1.0 < largeur) or (abrege and lien.size.x + 1.0 < largeur_vue): coupes.append("%s (%s, %d px sur %d)" % [entier, lien.text, int(lien.size.x), int(largeur)])
		check(coupes.is_empty(), cadre + " : aucun nom de joueur tronqué " + str(coupes))
		var bouton_downes := ecran.find_child("MatchBetweenPlayerName_p13", true, false) as Button
		check(bouton_downes != null and not bouton_downes.text.contains("…") and bouton_downes.text.ends_with("DOWNES") and (bouton_downes.text == "Darren DOWNES" or bouton_downes.text == "D. DOWNES"), cadre + " : avec une alerte longue, le nom de famille n'est jamais coupé (%s)" % (bouton_downes.text if bouton_downes != null else "absent"))
		var bouton_boothroyd := ecran.find_child("MatchBetweenPlayerName_r21", true, false) as Button
		check(bouton_boothroyd != null and bouton_boothroyd.text == "Matthew BOOTHROYD", cadre + " : « Matthew BOOTHROYD » se lit en entier sur le banc (%s)" % (bouton_boothroyd.text if bouton_boothroyd != null else "absent"))
		# Légende des notes retirée (demande de Léo du 21/11/2026) : la note est écrite dans sa pastille de couleur.
		var pastille_note: Node = ligne1.find_child("MatchBetweenPlayerNote", true, false) if ligne1 != null else null
		check(ecran.find_child("MatchBetweenNotesLegend", true, false) == null and pastille_note != null and pastille_note.find_children("*", "Label", true, false).any(func(l: Label): return l.text == "6,0"), cadre + " : plus de légende des notes, la note écrite dans sa pastille")
		check(not Charte.ATTRIBUT_85.is_equal_approx(Charte.ATTRIBUT_65) and not Between._teinte_note(7.8).is_equal_approx(Charte.V) and not Between._teinte_note(7.2).is_equal_approx(Charte.V), cadre + " : deux verts distincts, jamais le vert de la victoire")
		var terrain: Control = ecran.terrain
		check(terrain.champ().size.x >= terrain.size.x * 0.8, cadre + " : le terrain remplit sa tuile (%d sur %d px)" % [int(terrain.champ().size.x), int(terrain.size.x)])
		check(terrain.plancher_pastilles == 0.0 and terrain.rayon() >= 4.0 and terrain.rayon() <= terrain.echelle() * 3.0, cadre + " : pastilles à l'échelle du terrain, jamais une masse (rayon %.1f px)" % terrain.rayon())
		# Un seul aplat doré à l'écran : le bouton principal.
		var pleins := ecran.find_children("*", "BaseButton", true, false).filter(func(b: Control): return b.is_visible_in_tree() and aplat_or(b))
		check(pleins.size() == 1, cadre + " : un seul aplat doré (%s)" % str(pleins.map(func(b: Control): return str(b.name))))
		# Repères de la domination : type, marqueur, score, sans chevauchement ; clic = journal à ce fait.
		var frise: Control = ecran.domination
		check(frise.texte_repere(d[2].reperes[0]) == "E · Joueur Numéro12 38′ 10-7", cadre + " : repère « type · marqueur minute score » (%s)" % frise.texte_repere(d[2].reperes[0]))
		var rects: Array = frise._etiquettes.map(func(e: Array): return e[0])
		var chevauchent := false
		for a in rects.size():
			for b in range(a + 1, rects.size()): chevauchent = chevauchent or (rects[a] as Rect2).intersects(rects[b])
		check(rects.size() == 3 and not chevauchent, cadre + " : trois repères dessinés, sans chevauchement")
		signaux.clear()
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		clic.position = (rects[0] as Rect2).get_center() if not rects.is_empty() else Vector2.ZERO
		frise._gui_input(clic)
		check(signaux.size() == 1 and signaux[0][0] == "journal_demande", cadre + " : clic sur un repère = le journal à ce fait " + str(signaux))
		# Pastille du terrain : clic = le joueur choisi dans Mon XV.
		ecran._choix_pastille("0:2")
		await process_frame
		check(root.gui_get_focus_owner() != null and str(root.gui_get_focus_owner().name) == "MatchBetweenPlayer3", cadre + " : clic sur la pastille 3 = le 3 choisi dans Mon XV")
		# Plus : en entracte 2D, les caméras sont grisées et dites « en 3D seulement ».
		var menu_plus := (ecran.find_child("MatchBetweenMore", true, false) as MenuButton).get_popup()
		menu_plus.about_to_popup.emit()
		var cams: Array = range(menu_plus.item_count).filter(func(k: int): return menu_plus.get_item_metadata(k) is String)
		check(cams.size() == 3 and cams.all(func(k: int): return menu_plus.is_item_disabled(k) and menu_plus.get_item_text(k).ends_with("en 3D seulement") and menu_plus.is_item_radio_checkable(k)), cadre + " : caméras grisées en 2D, cochables")		# Noms : lien vers la fiche, mini-fiche au survol.
		var noms: Array = ecran.find_children("MatchBetweenPlayerName_*", "Button", true, false)
		var nom1 := ecran.find_child("MatchBetweenPlayerName_p1", true, false) as Button
		check(nom1 != null and nom1.text in ["Joueur Numéro1", "J. Numéro1"] and nom1.size.x >= nom1.get_theme_font("font").get_string_size(nom1.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nom1.get_theme_font_size("font_size")).x, cadre + " : le nom se lit en entier (%s)" % (str(nom1.size) if nom1 != null else "absent"))
		check(noms.size() == 23 and noms.all(func(b: Button): return b.has_meta("player_id") and b.has_meta("mini_fiche_joueur") and b.pressed.get_connections().size() > 0), cadre + " : 23 noms, chacun lien vers sa fiche et mini-fiche au survol (%d)" % noms.size())
		# Tout ce qui a l'air cliquable fait quelque chose, sans ouvrir de fenêtre (le menu Plus est l'exception).
		var fenetres_avant := root.get_children().filter(func(n: Node): return n is Window and (n as Window).visible).size()
		var muets: Array = []
		var boutons: Array = ecran.find_children("*", "BaseButton", true, false)
		for objet: Variant in boutons:
			if not is_instance_valid(objet): continue
			var b := objet as BaseButton
			if not b.is_visible_in_tree() or b.disabled or b is MenuButton or str(b.name).begins_with("MatchBetweenPlayerName_"): continue
			var avant := etat(ecran, app)
			b.pressed.emit()
			await process_frame
			if etat(ecran, app) == avant: muets.append(str(b.name) + " « " + (b.text if b is Button else "") + " »")
			var fenetres := root.get_children().filter(func(n: Node): return n is Window and (n as Window).visible).size()
			if fenetres != fenetres_avant: muets.append(str(b.name) + " ouvre une fenêtre")
			ecran.montrer_droite("chiffres")
			if ecran.vue_xv != "tableau": ecran.choisir_vue_xv("tableau")
		check(muets.is_empty(), cadre + " : chaque bouton fait quelque chose, sans fenêtre " + str(muets))
		ecran.tri_xv = ""
		ecran.tri_inverse = false
		ecran._poser_entete_tri()
		ecran.choisir_vue_xv("tableau")
		var plus := ecran.find_child("MatchBetweenMore", true, false) as MenuButton
		check(plus != null and plus.get_popup().item_count >= 7, cadre + " : menu Plus (statistiques, journal, délégation, autres matchs, caméras)")
		# Réglages et autres matchs : à la place des chiffres clés, Échap y revient.
		ecran.montrer_droite("reglages")
		await process_frame
		check(ecran.panneau_parametres.is_visible_in_tree() and not (ecran.find_child("MatchBetweenDuel", true, false) as Control).is_visible_in_tree() and ecran.grille_niveaux.get_child_count() == 6, cadre + " : Réglages à la place des chiffres clés, six niveaux")
		var echap := InputEventKey.new()
		echap.keycode = KEY_ESCAPE
		echap.pressed = true
		ecran._input(echap)
		check(ecran.vue_droite == "chiffres", cadre + " : Échap ramène aux chiffres clés")
		ecran.montrer_droite("journee")
		await process_frame
		check(ecran.classement_tuile.is_visible_in_tree() and ecran.multiplex.is_visible_in_tree(), cadre + " : autres matchs et classement en direct dans la colonne de droite")
		# Classement et multiplex : chaque club mène à sa fiche (clic), jamais une zone muette.
		signaux.clear()
		var clic_club := InputEventMouseButton.new()
		clic_club.button_index = MOUSE_BUTTON_LEFT
		clic_club.pressed = true
		var ligne_nous := ecran.classement_lignes.find_child("MatchBetweenLiveRow2", false, false) as Control
		if ligne_nous != null: ligne_nous.gui_input.emit(clic_club)
		var carte := ecran.multiplex_cartes.get_child(0) as Control if ecran.multiplex_cartes.get_child_count() > 0 else null
		if carte != null: carte.gui_input.emit(clic_club)
		check(signaux.size() == 2 and signaux[0] == ["club_demande", 102] and signaux[1][0] == "match_demande" and str(signaux[1][1].get("id", "")) == "m1" and ligne_nous.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, cadre + " : clic sur un club du classement = sa fiche, sur un match du multiplex = sa fenêtre " + str(signaux))
		var muettes: Array = ecran.classement_lignes.get_children().filter(func(n: Node): return str(n.name).begins_with("MatchBetweenLiveRow") and not n.has_meta("club_id"))
		check(muettes.is_empty(), cadre + " : toutes les lignes du classement sont cliquables " + str(muettes))
		ecran.montrer_droite("chiffres")
		# Clavier : Espace à la mi-temps reprend, T ouvre Équipe.
		signaux.clear()
		var espace := InputEventKey.new()
		espace.keycode = KEY_SPACE
		espace.pressed = true
		ecran._input(espace)
		var t := InputEventKey.new()
		t.keycode = KEY_T
		t.pressed = true
		ecran._input(t)
		check(signaux.map(func(s: Array): return s[0]) == ["reprise_demandee", "tiroir_demande"], cadre + " : Espace reprend, T ouvre Équipe " + str(signaux))
		# Panneau d'arrêt : il prend la colonne de droite, Équipe et Réglages attendent le choix.
		ecran.montrer_arret({"cle": "incident-1", "raison": "blessure", "horloge": "38′", "texte": "AFN · Blessure de Joueur Numéro13.",
			"choix": {"type": "entrant", "options": [{"id": "r23", "nom": "Lucas Fetuao", "poste": "centre", "energie": 100, "actuel": true}, {"id": "r22", "nom": "Declan Moss", "poste": "ouverture", "energie": 100}]}})
		for i in 3: await process_frame
		var arret := ecran.find_child("MatchBetweenStop", true, false) as Control
		check(arret.is_visible_in_tree() and not (ecran.find_child("MatchBetweenDuel", true, false) as Control).is_visible_in_tree() and dans(arret.get_global_rect(), ecran_rect) and arret.get_global_rect().end.x <= centre.position.x + 1.0, cadre + " : panneau d'arrêt à la place des événements, à gauche")
		check(ecran.equipe.disabled and ecran.parametres.disabled and ecran.arret_reprendre.text == "VALIDER LE CHOIX", cadre + " : Équipe et Réglages attendent le choix, « Valider le choix »")
		var ligne_bloquee := ecran.xv.find_child("MatchBetweenPlayer1", false, false) as Button
		check(ligne_bloquee != null and ligne_bloquee.disabled and ligne_bloquee.modulate.a < 0.9 and ecran.arret_aide.visible and ecran.arret_aide.text.contains("Mon XV"), cadre + " : lignes de Mon XV bloquées et atténuées, raison écrite")
		var pleins_arret := ecran.find_children("*", "BaseButton", true, false).filter(func(b: Control): return b.is_visible_in_tree() and aplat_or(b))
		check(pleins_arret.size() == 1 and pleins_arret[0] == ecran.arret_reprendre, cadre + " : en arrêt, le seul aplat doré est « Valider le choix »")
		# Options d'arrêt : un « i » vers la fiche complète sur chaque joueur proposé, le clic sur la ligne reste le choix.
		var options_arret: Array = ecran.arret_options.get_children().filter(func(n: Node): return n is Button)
		var infos_ok := options_arret.size() == 2
		for b: Button in options_arret:
			var i := b.find_child("MatchBetweenStopInfo", false, false) as Button
			infos_ok = infos_ok and i != null and i.text == "i" and str(i.get_meta("player_id", "")) == str(b.get_meta("option_id")) and i.pressed.get_connections().size() > 0
		check(infos_ok, cadre + " : « i » vers la fiche sur chaque option d'arrêt")
		# Charte finale : aucun cadre complet, hors les deux contours permis (anneau de focus doré ; bouton secondaire
		# ou éteint : pilule à contour `FILET`), quel que soit l'état (arrêt et option retenue compris).
		var cadres: Array = []
		var carres: Array = []
		for noeud: Node in ecran.find_children("*", "Control", true, false):
			# Nœuds internes du moteur (« _focus » des défilements : anneau de focus clavier) : hors de l'écran dessiné.
			if str(noeud.name).begins_with("_"): continue
			for etat_style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed", "panel"]:
				var s := (noeud as Control).get_theme_stylebox(etat_style) as StyleBoxFlat if (noeud as Control).has_theme_stylebox_override(etat_style) else null
				if s == null: continue
				if s.border_width_left > 0 and s.border_width_right > 0 and s.border_width_top > 0 and s.border_width_bottom > 0:
					var anneau: bool = etat_style == "focus" and Color(s.border_color, 1.0).is_equal_approx(Charte.OR)
					var secondaire: bool = Color(s.border_color, 1.0).is_equal_approx(Charte.FILET) and s.corner_radius_top_left >= Charte.RAYON_PILULE
					# Grandes tuiles de l'écran 2D : fin liseré blanc (choix de Léo du 21/11/2026), rayon 18, 1 px.
					var tuile: bool = s.border_color.is_equal_approx(Between.LISERE) and s.border_width_left == 1 and s.corner_radius_top_left == Charte.RAYON_PANNEAU
					if not anneau and not secondaire and not tuile: cadres.append("%s:%s" % [noeud.name, etat_style])
				# Tout aplat visible est arrondi (panneau 18, carte 12, case 6, pilule) ; seul le fondu du multiplex, de la
				# couleur du panneau qu'il recouvre (invisible sur lui), garde ses angles.
				if s.bg_color.a > 0.05 and s.corner_radius_top_left < Charte.RAYON_PETIT and str(noeud.name) != "MatchBetweenMultiplexFade": carres.append("%s:%s" % [noeud.name, etat_style])
		check(cadres.is_empty(), cadre + " : aucun cadre complet hors anneau de focus et bouton secondaire " + str(cadres.slice(0, 6)))
		check(carres.is_empty(), cadre + " : aucun aplat à angles droits (charte finale : 18 / 12 / 6 / pilule) " + str(carres.slice(0, 6)))
		# Menus déroulants habillés : carte opaque arrondie (12), sans ombre.
		for menu_style: PopupMenu in [menu_plus, ecran.menu_reglages]:
			var fond_menu := menu_style.get_theme_stylebox("panel") as StyleBoxFlat
			check(fond_menu != null and fond_menu.bg_color.a == 1.0 and fond_menu.corner_radius_top_left == Charte.RAYON_CARTE and fond_menu.shadow_size == 0, cadre + " : menu %s à la charte" % menu_style.name)
		ecran.arret_reprendre.pressed.emit()
		for i in 2: await process_frame
		var envois: Array = app.get("envois")
		check(not envois.is_empty() and envois[-1] == ["match_incident_choice", {"cle": "incident-1", "id": "r23"}], cadre + " : « Valider le choix » envoie le choix du staff " + str(envois.slice(-1)))
		check(not ecran.equipe.disabled and ecran.arret_reprendre.text == "REPRENDRE LE MATCH", cadre + " : après le choix, Équipe revient et le bouton reprend le match")
		ecran.montrer_arret({})
		await process_frame
		check((ecran.find_child("MatchBetweenDuel", true, false) as Control).is_visible_in_tree(), cadre + " : arrêt fini, les chiffres clés reviennent")
		# Temps fort 3D (entracte caché, la barre reste dans la bande du direct) : Réglages devient un menu déroulant
		# (vitesse, temps forts), « Confier la fin » passe par le menu du match, « Autres matchs » est grisé et dit pourquoi.
		ecran.visible = false
		await process_frame
		signaux.clear()
		ecran._ouvrir_parametres()
		await process_frame
		var menu_reglages: PopupMenu = ecran.menu_reglages
		check(menu_reglages.visible and menu_reglages.item_count == 4 + 6 + 2 and ecran.vue_droite == "chiffres", cadre + " : en 3D, Réglages ouvre un menu déroulant (%d choix)" % menu_reglages.item_count)
		check(menu_reglages.is_item_checked(menu_reglages.get_item_index(Between.HORLOGES_IDS.find(ecran.horloge))),cadre + " : l'horloge courante est cochée")
		menu_reglages.id_pressed.emit(2)
		menu_reglages.id_pressed.emit(101)
		check(ecran.horloge == "rapide" and signaux == [["horloge_choisie", "rapide"], ["niveau_choisi", "resume"]], cadre + " : le menu change l'horloge et les temps forts " + str(signaux))
		menu_reglages.hide()
		menu_plus.about_to_popup.emit()
		check(menu_plus.is_item_disabled(3) and menu_plus.get_item_text(3).ends_with("à l’entracte"), cadre + " : en 3D, autres matchs grisés et dits (%s)" % menu_plus.get_item_text(3))
		signaux.clear()
		menu_plus.id_pressed.emit(menu_plus.get_item_id(2))
		check(signaux == [["confier_fin_demande", null]] and ecran.vue_droite == "chiffres", cadre + " : en 3D, « Confier la fin » passe par le menu du match " + str(signaux))
		ecran.visible = true
		vue.queue_free()
		app.queue_free()
		for i in 2: await process_frame
	print("MATCH_ENTRACTE_DA_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
