extends SceneTree
## Après-match (ui/contextual/apres_match.gd), sans moteur : projection de fin de match construite comme celle du
## moteur (`live.direct` : pourquoi, hommeDuMatch, marques, notes, journee.classement complet et journee.matchs ;
## zones de la compétition dans `leagues`). Vérifie : verdict en mots et pastille V/N/D, trois raisons et leur levier,
## classement complet (une ligne par club, zones lues dans les données, légende), autres matchs de la journée, tout ce
## qui a l'air cliquable ouvre un écran (cible de navigation) ou valide le résultat, aucune fenêtre ouverte, aucun or
## hors « Valider le résultat », sous-page « Voir plus » avec retour, défaite sans raison, tenue en 1280×720.
## CD_APRES_MATCH_PNG=<fichier.png> : capture 1920×1080 (rendu fenêtré requis).
const ApresMatch = preload("res://ui/contextual/apres_match.gd")
const Charte = preload("res://ui/charte.gd")
var checks := 0
var failures: Array[String] = []

class FauxDirecteur extends Node:
	var cibles: Array = []
	var commandes: Array = []
	func consulter(cible: Dictionary) -> bool:
		cibles.append(cible)
		return true
	func command(nom: String, _charge: Dictionary = {}) -> void: commandes.append(nom)
	func _refresh_controls() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

const NOMS := ["Alder Test", "Brook Test", "Cobalt Test", "Dune Test", "Elm Test", "Fern Test", "Glen Test", "Heath Test", "Iris Test", "Juniper Test", "Kestrel Test", "Larch Test"]

func modele(issue: String, raisons: bool) -> Dictionary:
	var lignes: Array = []
	var classement: Array = []
	for k in 12:
		var id := 100 + k
		lignes.append({"id": id, "name": NOMS[k], "abbr": NOMS[k].substr(0, 2).to_upper(), "color": "#%02x4a6b" % (40 + k * 12), "rank": k + 1, "played": 9})
		classement.append({"rang": k + 1, "clubId": id, "abbr": NOMS[k].substr(0, 2).to_upper(), "nom": NOMS[k], "joues": 9, "points": 34 - k * 2, "diff": 60 - k * 11,
			"gagnes": 7 - floori(k / 2.0), "nuls": k % 2, "perdus": 2 + floori(k / 2.0), "forme": ["W", "L", "D", "W", "W"], "bonusOff": 1 if k == 0 else 0, "bonusDef": 1 if k == 2 else 0,
			"rangOfficiel": k + 2 if k == 2 else k + 1, "delta": 1 if k == 2 else 0, "nous": k == 2})
	var matchs: Array = []
	for m in 5:
		matchs.append({"id": "f%d" % m, "home": {"id": 100 + (m * 2 + 3) % 12, "abbr": "XX", "nom": "", "score": 20 + m, "essais": 2}, "away": {"id": 100 + (m * 2 + 4) % 12, "abbr": "YY", "nom": "", "score": 13, "essais": 1}, "minute": 80, "fini": true})
	var pourquoi := {"issue": issue, "raisons": []}
	if raisons:
		pourquoi.raisons = [
			{"rang": 1, "levier": "condition", "levierLabel": "Condition", "sens": "positif", "texte": "Notre XV a fini à 71 % d’énergie contre 52 % en face.", "action": "Voir la condition", "route": "Effectif"},
			{"rang": 2, "levier": "tactique", "levierLabel": "Tactique", "sens": "positif", "texte": "Deux essais sur trois attaques au large.", "action": "Ajuster la tactique", "route": "Composition"},
			{"rang": 3, "levier": "discipline", "levierLabel": "Discipline", "sens": "negatif", "texte": "Onze pénalités concédées, dont six dans nos 22 mètres.", "action": "Travailler la discipline", "route": "Composition"}]
	var score := [24, 21] if issue == "victoire" else [17, 24]
	var direct := {"camp": 0, "score": score, "pourquoi": pourquoi,
		"hommeDuMatch": {"joueur": "p9", "camp": 0, "nom": "T. Harlow", "note": 8.1, "essais": 1, "plaquages": 9, "metres": 64},
		"marques": [{"horloge": "12′", "minute": 12, "kind": "goal", "equipe": 0, "joueur": "p9", "nom": "T. Harlow", "score": [3, 0], "texte": "Pénalité réussie."},
			{"horloge": "19′", "minute": 19, "kind": "try", "equipe": 1, "joueur": "x4", "nom": "J. Pell", "score": [3, 5], "texte": "Essai."}],
		"notes": {"p9": {"cote": 0, "note": 8.1}, "p10": {"cote": 0, "note": 6.4}, "x4": {"cote": 1, "note": 7.0}},
		"journee": {"minute": 80, "matchs": matchs, "classement": classement}}
	return {"club": {"id": 102, "name": NOMS[2], "color": "#6b2a2a"},
		"squad": [{"id": "p9", "name": "T. Harlow", "pos": "Demi d’ouverture"}, {"id": "p10", "name": "B. Amos", "pos": "Pilier"}],
		"next": {"id": "fx", "competitionId": "div-test", "label": "Division test · Journée 9", "date": "2026-11-21", "home": lignes[2], "away": lignes[0]},
		"leagues": [{"id": "div-test", "name": "Division test", "rows": lignes, "zoneShortNote": "Pas de relégation automatique",
			"zones": [{"from": 1, "to": 4, "kind": "playoff", "label": "Phases finales", "symbol": "●"}, {"from": 12, "to": 12, "kind": "relegation", "label": "Relégation", "symbol": "▼"}]}],
		"live": {"finished": true, "paused": false, "score": score, "tries": [2, 3], "teams": [lignes[2], lignes[0]],
			"events": [{"min": 12, "text": "Pénalité réussie."}, {"min": 19, "text": "Essai."}], "statsRows": [{"label": "Possession", "home": "52 %", "away": "48 %"}], "direct": direct}}

func boutons(ecran: Control) -> Array:
	return ecran.find_children("*", "BaseButton", true, false).filter(func(b: BaseButton): return b.is_visible_in_tree())

func or_hors_valider(ecran: Control) -> Array[String]:
	var fautes: Array[String] = []
	var ors := [Charte.OR, Charte.OR_VIF]
	for n: Node in ecran.find_children("*", "", true, false):
		if n is Label and (n as Label).get_theme_color("font_color") in ors: fautes.append(str(n.get_path()))
		if n.get("couleur") is Color and n.get("couleur") in ors and n.name != "ApresMatchValiderFond": fautes.append(str(n.get_path()))
		if n is PanelContainer:
			var s := (n as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
			if s != null and s.bg_color in ors: fautes.append(str(n.get_path()))
	return fautes

func run() -> void:
	# Comme la coque du jeu (shell.gd) : pas d'étirement, un pixel de l'écran = un pixel réel.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	var app := Control.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	var directeur := FauxDirecteur.new()
	root.add_child(directeur)
	var ecran: Control = ApresMatch.new()
	ecran.app = app
	ecran.director = directeur
	app.add_child(ecran)
	ecran.update_frame(modele("victoire", true))
	for i in 8: await process_frame
	# Verdict et score.
	var verdict := ecran.find_child("ApresMatchVerdict", true, false) as Label
	check(verdict != null and verdict.text == "VICTOIRE", "Verdict en mots : " + (verdict.text if verdict != null else "absent"))
	check(ecran.find_child("ApresMatchPastilleV", true, false) != null, "Pastille ovale V")
	var titre := ecran.find_child("ApresMatchPourquoiTitre", true, false) as Label
	check(titre != null and titre.text == "POURQUOI ON A GAGNÉ", "Titre du pourquoi selon l’issue")
	for rang in [1, 2, 3]: check(ecran.find_child("ApresMatchRaison%d" % rang, true, false) != null, "Raison n° %d" % rang)
	var contexte := ecran.find_child("ApresMatchContexte", true, false) as Label
	check(contexte != null and contexte.text.begins_with("Division test · J9"), "Compétition et journée lues dans les données : " + (contexte.text if contexte != null else ""))
	check(ecran.find_child("ApresMatchRang", true, false) != null, "Classement avant → après dans le bandeau")
	# Classement complet, zones des données, légende.
	for rang in range(1, 13): check(ecran.find_child("ApresMatchLigne%d" % rang, true, false) != null, "Ligne du classement n° %d" % rang)
	var premiere := ecran.find_child("ApresMatchLigne1", true, false)
	var derniere := ecran.find_child("ApresMatchLigne12", true, false)
	check(premiere != null and premiere.get_meta("zone") == "playoff" and derniere != null and derniere.get_meta("zone") == "relegation", "Zones réelles du championnat sur les lignes")
	check(ecran.find_child("ApresMatchLegende", true, false) != null, "Légende des zones")
	check(premiere != null and premiere.find_child("StandingsZoneMark", true, false) != null, "Symbole de zone dessiné")
	var forme := premiere.find_child("Forme", true, false) if premiere != null else null
	check(forme != null and forme.get_child_count() == 5, "Forme : cinq pastilles")
	for m in 5: check(ecran.find_child("ApresMatchAutreMatch%d" % m, true, false) != null, "Autre match de la journée n° %d" % m)
	check(ecran.find_child("ApresMatchTaPlace", true, false) != null, "Ta place")
	check(ecran.find_child("ApresMatchFil", true, false) != null, "Fil du score")
	var gabi := ecran.find_child("ApresMatchGabiPhrase", true, false) as Label
	check(gabi != null and gabi.text.contains("discipline"), "Gabi nomme le levier à corriger : " + (gabi.text if gabi != null else ""))
	# Aucun or hors « Valider le résultat ».
	var fautes := or_hors_valider(ecran)
	check(fautes.is_empty(), "Aucun or hors Valider le résultat : " + str(fautes))
	check(ecran.find_child("ApresMatchValiderFond", true, false) != null, "Bouton or Valider le résultat")
	var capture := OS.get_environment("CD_APRES_MATCH_PNG")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK, "Capture : " + capture)
	# Tout ce qui a l'air cliquable ouvre quelque chose.
	var connus := ["club", "player", "menu", "date", "competition"]
	for b: BaseButton in boutons(ecran):
		if b is MenuButton:
			var cibles: Array = b.get_meta("cibles", [])
			check(cibles.size() >= 2, "Menu Plus : au moins deux entrées")
			for k in range(1, cibles.size()):
				directeur.cibles.clear()
				(b as MenuButton).get_popup().id_pressed.emit(k)
				check(directeur.cibles.size() == 1, "Entrée %d du menu Plus ouvre un écran" % k)
			continue
		if b.name == "ApresMatchValider":
			b.pressed.emit()
			check(directeur.commandes == ["finish_round"], "Valider le résultat envoie finish_round")
			continue
		var cible: Dictionary = b.get_meta("cible", {})
		if str(cible.get("kind", "")) == "detail": continue
		directeur.cibles.clear()
		b.pressed.emit()
		var ok: bool = directeur.cibles.size() == 1 and str(directeur.cibles[0].get("kind", "")) in connus and (not str(directeur.cibles[0].get("id", "")).is_empty() or not str(directeur.cibles[0].get("route", "")).is_empty())
		check(ok, "Clic sur %s ouvre un écran : %s" % [b.name, str(directeur.cibles)])
	var leviers := ["condition", "tactique", "discipline"]
	for levier in leviers:
		var b := ecran.find_child("ApresMatchLevier_" + levier, true, false) as Button
		check(b != null, "Lien du levier " + levier)
	check(ecran.find_child("ApresMatchJoueur_p9", true, false) != null and ecran.find_child("ApresMatchJoueur_p9", true, false).has_meta("mini_fiche_joueur"), "Homme du match : fiche au clic, mini-fiche au survol")
	var club_ligne := ecran.find_child("ApresMatchClubLigne5", true, false) as Button
	directeur.cibles.clear()
	if club_ligne != null: club_ligne.pressed.emit()
	check(directeur.cibles == [{"kind": "club", "id": "104"}], "Club du classement → sa fiche : " + str(directeur.cibles))
	# Aucune fenêtre ouverte par ces clics.
	var fenetres := root.find_children("*", "Window", true, false).filter(func(w: Window): return w.visible)
	check(fenetres.is_empty(), "Aucune fenêtre ouverte : " + str(fenetres))
	# Sous-page « Voir plus » et retour.
	(ecran.find_child("ApresMatchVoirPlus", true, false) as Button).pressed.emit()
	for i in 4: await process_frame
	check(ecran.find_child("ApresMatchDetailTitre", true, false) != null and ecran.find_child("ApresMatchJournal", true, false) != null, "Voir plus : statistiques, notes, journal")
	check(ecran.find_child("ApresMatchClassement", true, false) != null, "Le classement reste à droite pendant le détail")
	var retour := ecran.find_child("ApresMatchRetour", true, false) as Button
	check(retour != null, "Retour au pourquoi")
	if retour != null: retour.pressed.emit()
	for i in 4: await process_frame
	check(ecran.find_child("ApresMatchPourquoiTitre", true, false) != null, "Retour au verdict")
	# Défaite sans raison : verdict, message au lieu d'un bloc muet.
	ecran.update_frame(modele("defaite", false))
	for i in 4: await process_frame
	verdict = ecran.find_child("ApresMatchVerdict", true, false) as Label
	check(verdict != null and verdict.text == "DÉFAITE", "Défaite en mots")
	check(ecran.find_child("ApresMatchPastilleD", true, false) != null, "Pastille D")
	check(ecran.find_child("ApresMatchSansRaison", true, false) != null, "Aucune raison : message affiché")
	# 1280×720 : tout tient, rien sous 12 px.
	root.size = Vector2i(1280, 720)
	ecran.update_frame(modele("victoire", true))
	for i in 10: await process_frame
	var valider := ecran.find_child("ApresMatchValider", true, false) as Control
	check(valider != null and valider.get_global_rect().end.y <= 721.0 and valider.get_global_rect().end.x <= 1281.0, "1280×720 : Valider le résultat dans l’écran (%s)" % (str(valider.get_global_rect()) if valider != null else "absent"))
	var petits := ecran.find_children("*", "Label", true, false).filter(func(l: Label): return l.is_visible_in_tree() and l.get_theme_font_size("font_size") < 12)
	check(petits.is_empty(), "1280×720 : aucun texte sous 12 px (%d)" % petits.size())
	var derniere_ligne := ecran.find_child("ApresMatchLigne12", true, false) as Control
	check(derniere_ligne != null and derniere_ligne.get_global_rect().end.y <= 721.0, "1280×720 : classement complet visible")
	if failures.is_empty(): print("Après-match Godot · %d contrôles réussis" % checks)
	else: printerr("Après-match Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
