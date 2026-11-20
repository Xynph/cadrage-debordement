extends SceneTree
## Entracte du match, direction artistique du 19/11/2026 (variante 1 « Terrain au centre », panneau d'arrêt de la
## variante 3, colonne Plaquages de la variante 2 ; design/ux/14-match-entracte.md), sans moteur : une projection
## `live.direct` complète posée sur l'écran (match_between.gd) en 1920×1080 et 1280×720. Vérifie : les blocs de la
## maquette à l'écran et dans l'écran ; tout ce qui a l'air cliquable fait quelque chose (signal, panneau, vue,
## commande) ; aucun clic n'ouvre de fenêtre (seul le menu « Plus ▾ » est un menu déroulant, exception de Léo) ;
## aucune couleur or (réservée à Continuer) ; aucun texte sous 12 px ; les noms mènent à la fiche (survol :
## mini-fiche) ; le panneau d'arrêt prend la colonne de droite et bloque Équipe jusqu'au choix ; le clavier
## (Espace, Échap, T) suit la fiche UX.
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
		lineup.append({"id": id, "name": "Joueur Numéro%d" % (n + 1), "pos": POSTES[n], "condition": 38 if n == 6 else 70 + n, "injury": 0})
		notes[id] = {"note": 6.0 + n * 0.1, "faits": n}
		feuille.joueurs[id] = {"camp": 0, "plaquages": n % 7, "plaquagesManques": 1, "metres": n * 3, "essais": 1 if n == 11 else 0, "courses": 2, "passes": 3}
	var reserves: Array = []
	for n in 8: reserves.append({"id": "r%d" % (n + 16), "name": "Remplaçant Banc%d" % (n + 16), "pos": POSTES[n % 15]})
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
	var direct := {"camp": 0, "score": [10, 7], "borne": 0, "fil": [{"i": 3, "horloge": "38′", "kind": "try", "equipe": 0, "texte": "AFN · Essai de Joueur Numéro12."}], "tableau": tableau,
		"zone22": {"entrees": [5, 3], "points": [10, 7], "secondes": [150, 40]}, "domination": {"minutes": minutes, "miTemps": null},
		"reperes": [{"i": 3, "kind": "try", "equipe": 0, "horloge": "38′", "minute": 38, "x": 95}], "notes": notes, "feuille": feuille, "possession": 0, "zone": {"x": 60},
		"niveaux": [{"id": "aucun", "label": "Aucun"}, {"id": "resume", "label": "Résumé"}, {"id": "cles", "label": "Clés"}, {"id": "etendus", "label": "Étendus"}, {"id": "dynamique", "label": "Dynamique"}, {"id": "integral", "label": "Intégral"}],
		"niveau": "dynamique", "echantillon": {"minutes": 40, "suffisant": true, "seuil": 10},
		"journee": {"minute": 40, "classement": [{"rang": 1, "abbr": "HCX", "points": 9, "clubId": 1}, {"rang": 2, "abbr": "AFN", "points": 8, "clubId": 102, "nous": true}],
			"matchs": [{"id": "m1", "minute": 40, "home": {"abbr": "BTB", "score": 10, "id": 3}, "away": {"abbr": "GCR", "score": 6, "id": 4}}]}}
	return [equipes, live, direct]

func dans(r: Rect2, ecran: Vector2) -> bool:
	return Rect2(Vector2.ZERO, ecran).grow(1.0).encloses(r)

func etat(ecran: Control, app: Node) -> String:
	var fiche: Variant = ecran.get("fiche_match")
	return JSON.stringify([signaux.size(), ecran.vue_droite, ecran.vue_xv, fiche != null and is_instance_valid(fiche), (app.get("envois") as Array).size(), ecran.horloge, ecran.niveau_libelle()])

## Couleurs posées sur un contrôle (polices et styles) : aucune ne doit être l'or de Continuer.
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
	for taille: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
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
		for nom in ["tiroir_demande", "joueur_choisi", "reprise_demandee", "pause_demandee", "horloge_choisie", "niveau_choisi", "delegation_demandee", "camera_demandee", "consigne_bonus", "fiche_ouverte"]:
			var signal_nom: String = nom
			ecran.connect(signal_nom, func(a = null, _b = null): signaux.append([signal_nom, a]))
		var d := donnees()
		ecran.update_frame({}, d[1], d[2], func(_c): pass)
		for i in 6: await process_frame
		var ecran_rect := Vector2(taille)
		# Blocs de la maquette, visibles et entiers dans l'écran.
		for nom in ["MatchBetweenMain", "MatchBetweenPitchTile", "MatchBetweenDuel", "MatchBetweenMomentumTile", "MatchBetweenAdviceCard", "MatchBetweenKeys"]:
			var bloc := ecran.find_child(nom, true, false) as Control
			check(bloc != null and bloc.is_visible_in_tree() and dans(bloc.get_global_rect(), ecran_rect), cadre + " : bloc %s visible dans l'écran (%s)" % [nom, str(bloc.get_global_rect()) if bloc != null else "absent"])
		var gauche := (ecran.find_child("MatchBetweenMain", true, false) as Control).get_global_rect()
		var centre := (ecran.find_child("MatchBetweenPitchTile", true, false) as Control).get_global_rect()
		var droite := (ecran.find_child("MatchBetweenDuel", true, false) as Control).get_global_rect()
		check(gauche.end.x <= centre.position.x and centre.end.x <= droite.position.x, cadre + " : Mon XV à gauche, terrain au centre, chiffres clés à droite")
		check(centre.size.x > gauche.size.x and centre.size.x > droite.size.x, cadre + " : le terrain est le plus grand bloc")
		var lignes: Array = ecran.xv.get_children().filter(func(n: Node): return n is Button and str(n.name).begins_with("MatchBetweenPlayer"))
		check(lignes.size() == 15, cadre + " : quinze lignes dans Mon XV (%d)" % lignes.size())
		var entete := ecran.find_child("MatchBetweenSquadHeader", true, false)
		var colonnes: Array = entete.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if entete != null else []
		check(colonnes == ["N°", "JOUEUR", "ÉNERGIE", "PLAQ.", "NOTE"], cadre + " : colonnes de Mon XV avec Plaquages " + str(colonnes))
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
		check(remplacer != null and remplacer.text == "Remplacer le 7 par Banc20", cadre + " : Gabi propose le remplaçant conseillé (%s)" % (remplacer.text if remplacer != null else "absent"))
		check(ecran.phase.text.begins_with("Mi-temps"), cadre + " : la barre dit la mi-temps (%s)" % ecran.phase.text)
		# Aucun texte sous 12 px, aucun or.
		var petits: Array = []
		var dores: Array = []
		for noeud: Node in ecran.find_children("*", "Control", true, false):
			var c := noeud as Control
			if not c.is_visible_in_tree(): continue
			if (c is Label or c is Button) and c.get_theme_font_size("font_size") < 12: petits.append(str(c.name))
			if not ors(c).is_empty(): dores.append(str(c.name))
		check(petits.is_empty(), cadre + " : aucun texte sous 12 px " + str(petits.slice(0, 6)))
		check(dores.is_empty(), cadre + " : aucune couleur or (réservée à Continuer) " + str(dores.slice(0, 6)))
		# Noms : lien vers la fiche, mini-fiche au survol.
		var noms: Array = ecran.find_children("MatchBetweenPlayerName_*", "Button", true, false)
		var nom1 := ecran.find_child("MatchBetweenPlayerName_p1", true, false) as Button
		check(nom1 != null and nom1.text == "Joueur Numéro1" and nom1.size.x >= nom1.get_theme_font("font").get_string_size(nom1.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nom1.get_theme_font_size("font_size")).x, cadre + " : le nom se lit en entier (%s)" % (str(nom1.size) if nom1 != null else "absent"))
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
		check(arret.is_visible_in_tree() and not (ecran.find_child("MatchBetweenDuel", true, false) as Control).is_visible_in_tree() and dans(arret.get_global_rect(), ecran_rect) and arret.get_global_rect().position.x >= centre.end.x - 1.0, cadre + " : panneau d'arrêt dans la colonne de droite")
		check(ecran.equipe.disabled and ecran.parametres.disabled and ecran.arret_reprendre.text == "VALIDER LE CHOIX", cadre + " : Équipe et Réglages attendent le choix, « Valider le choix »")
		ecran.arret_reprendre.pressed.emit()
		for i in 2: await process_frame
		var envois: Array = app.get("envois")
		check(not envois.is_empty() and envois[-1] == ["match_incident_choice", {"cle": "incident-1", "id": "r23"}], cadre + " : « Valider le choix » envoie le choix du staff " + str(envois.slice(-1)))
		check(not ecran.equipe.disabled and ecran.arret_reprendre.text == "REPRENDRE LE MATCH", cadre + " : après le choix, Équipe revient et le bouton reprend le match")
		ecran.montrer_arret({})
		await process_frame
		check((ecran.find_child("MatchBetweenDuel", true, false) as Control).is_visible_in_tree(), cadre + " : arrêt fini, les chiffres clés reviennent")
		vue.queue_free()
		app.queue_free()
		for i in 2: await process_frame
	print("MATCH_ENTRACTE_DA_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
