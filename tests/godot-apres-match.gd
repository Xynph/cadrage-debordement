extends SceneTree
## Après-match (ui/contextual/apres_match.gd), sans moteur : projection de fin de match construite comme celle du
## moteur (`live.direct` : pourquoi, hommeDuMatch, marques, notes, journee.classement complet et journee.matchs ;
## zones de la compétition dans `leagues`). Vérifie : verdict en mots et pastille V/N/D, trois raisons et leur levier,
## classement complet (une ligne par club, zones lues dans les données, légende), autres matchs de la journée, tout ce
## qui a l'air cliquable ouvre un écran (cible de navigation) ou valide le résultat, aucune fenêtre ouverte, charte finale
## (20/11/2026 : un seul aplat doré, « Valider le résultat » en pilule ; panneaux arrondis sans bordure ; pastilles V/N/D
## en pilule lisibles sans la couleur ; couleur des clubs seulement sur leur écusson ; pas de bandes alternées), sous-page
## « Voir plus » avec retour, défaite sans raison, tenue en 1280×720.
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

## Navigation du jeu : la fiche du club 111 est indisponible (lien grisé et raison écrite).
class FauxNavigation extends Node:
	func entity_available(cible: Dictionary) -> bool:
		return not (str(cible.get("kind", "")) == "club" and str(cible.get("id", "")) == "111")

class FauxApp extends Control:
	var model: Dictionary = {}
	var navigation_controller: Node

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
		classement.append({"rang": k + 1, "clubId": id, "abbr": NOMS[k].substr(0, 2).to_upper(), "nom": NOMS[k], "joues": 9, "points": 30 if k == 3 else 34 - k * 2, "diff": 60 - k * 11,
			"gagnes": 7 - floori(k / 2.0), "nuls": k % 2, "perdus": 2 + floori(k / 2.0), "forme": ["V", "D", "N", "V", "V"] if k != 5 else ["W", "D", "L"], "bonusOff": 1 if k == 0 else 0, "bonusDef": 1 if k == 2 else 0,
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
		"marques": [{"horloge": "12′", "minute": 12, "kind": "goal", "nature": "penalite", "equipe": 0, "joueur": "p9", "nom": "T. Harlow", "buteur": null, "score": [3, 0], "texte": "Pénalité réussie."},
			{"horloge": "19′", "minute": 19, "kind": "try", "nature": "essai-transforme", "equipe": 1, "joueur": "x4", "nom": "J. Pell", "buteur": {"joueur": "x10", "nom": "R. Howell"}, "score": [3, 7], "texte": "Essai."}],
		"adversaire": [{"joueur": "x4", "nom": "J. Pell", "poste": "Ailier", "note": 7.0, "essais": 1, "plaquages": 4, "metres": 58}],
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

## Aplats dorés (charte finale : un seul par écran, l'action principale). Le doré reste permis en texte, contour,
## pictogramme (triangle ▲ ▼ accompagné d'un mot) et anneau de focus.
func aplats_dores(ecran: Control) -> Array[String]:
	var trouves: Array[String] = []
	var ors := [Charte.OR, Charte.OR_VIF]
	for n: Node in ecran.find_children("*", "", true, false):
		if n.get("couleur") is Color and n.get("couleur") in ors and str(n.get("forme")) == "pave": trouves.append(str(n.name))
		# Un liseré (zone du classement, 3 px) ou un filet n'est pas un aplat.
		if n is ColorRect and (n as ColorRect).color in ors and minf((n as ColorRect).size.x, (n as ColorRect).size.y) > 6.0: trouves.append(str(n.name))
		if n is Control:
			for cle in ["panel", "normal", "hover", "pressed"]:
				if not (n as Control).has_theme_stylebox_override(cle): continue
				var s := (n as Control).get_theme_stylebox(cle) as StyleBoxFlat
				if s != null and s.draw_center and s.bg_color in ors:
					trouves.append(str(n.name))
					break
	return trouves

## Styles à cadre complet hors anneau de focus (charte : panneaux sans bordure ; contour 1 px seulement pour un bouton
## secondaire, en pilule).
func cadres_complets(ecran: Control) -> Array[String]:
	var trouves: Array[String] = []
	for n: Node in ecran.find_children("*", "Control", true, false):
		# Le menu déroulant « Plus » (exception permise) a son propre habillage de thème.
		if (n as Control).get_window() != ecran.get_window(): continue
		for cle in ["panel", "normal", "hover", "pressed"]:
			if not (n as Control).has_theme_stylebox_override(cle): continue
			var s := (n as Control).get_theme_stylebox(cle) as StyleBoxFlat
			if s == null or s.border_color.a <= 0.0 or s.border_width_left <= 0 or s.border_width_right <= 0 or s.border_width_top <= 0 or s.border_width_bottom <= 0: continue
			if s.corner_radius_top_left >= Charte.RAYON_PILULE: continue
			trouves.append("%s.%s" % [ecran.get_path_to(n), cle])
	return trouves

func run() -> void:
	# Comme la coque du jeu (shell.gd) : pas d'étirement, un pixel de l'écran = un pixel réel.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	var app := FauxApp.new()
	app.navigation_controller = FauxNavigation.new()
	app.add_child(app.navigation_controller)
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
	check(ecran.find_child("ApresMatchPastilleV", true, false) != null, "Pastille V")
	var titre := ecran.find_child("ApresMatchPourquoiTitre", true, false) as Label
	check(titre != null and titre.text == "POURQUOI ON A GAGNÉ", "Titre du pourquoi selon l’issue")
	for rang in [1, 2, 3]: check(ecran.find_child("ApresMatchRaison%d" % rang, true, false) != null, "Raison n° %d" % rang)
	var contexte := ecran.find_child("ApresMatchContexte", true, false) as Label
	check(contexte != null and contexte.text.begins_with("Division test · J9"), "Compétition et journée lues dans les données : " + (contexte.text if contexte != null else ""))
	check(ecran.find_child("ApresMatchRang", true, false) != null, "Classement avant → après dans le bandeau")
	# Bandeau photo du vestiaire : 30 % de la hauteur (324 px sur 1080), choix de Léo du 20/11 (charte : bandeau 30 %).
	var bandeau_photo := ecran.find_child("ApresMatchBandeau", true, false) as Control
	var part_bandeau := bandeau_photo.size.y / 1080.0 if bandeau_photo != null else 0.0
	check(bandeau_photo != null and absf(bandeau_photo.size.y - 324.0) <= 1.0 and part_bandeau > 0.29 and part_bandeau < 0.31, "Bandeau photo à 30 %% de la hauteur : %.1f %% (%s px)" % [part_bandeau * 100.0, str(bandeau_photo.size.y) if bandeau_photo != null else "absent"])
	# Classement complet, zones des données, légende.
	for rang in range(1, 13): check(ecran.find_child("ApresMatchLigne%d" % rang, true, false) != null, "Ligne du classement n° %d" % rang)
	var premiere := ecran.find_child("ApresMatchLigne1", true, false)
	var derniere := ecran.find_child("ApresMatchLigne12", true, false)
	check(premiere != null and premiere.get_meta("zone") == "playoff" and derniere != null and derniere.get_meta("zone") == "relegation", "Zones réelles du championnat sur les lignes")
	check(ecran.find_child("ApresMatchLegende", true, false) != null, "Légende des zones")
	check(premiere != null and premiere.find_child("StandingsZoneMark", true, false) != null, "Symbole de zone dessiné")
	var forme := premiere.find_child("Forme", true, false) if premiere != null else null
	check(forme != null and forme.get_child_count() == 5, "Forme : cinq pastilles")
	# Forme du moteur en V / N / D (D = défaite) ; une forme brute W / D / L (D = nul) est convertie.
	check(forme != null and forme.get_child(2).name.begins_with("ApresMatchPastilleN") and forme.get_child(1).name.begins_with("ApresMatchPastilleD"), "Forme : un nul s'affiche N, une défaite D")
	check(ApresMatch.forme_vnd(["W", "D", "L"]) == ["V", "N", "D"] and ApresMatch.forme_vnd(["V", "N", "D"]) == ["V", "N", "D"], "Forme brute W/D/L : le nul (D) devient N")
	var sixieme := ecran.find_child("ApresMatchLigne6", true, false)
	var forme6 := sixieme.find_child("Forme", true, false) if sixieme != null else null
	check(forme6 != null and forme6.get_child_count() == 3 and forme6.get_child(1).name.begins_with("ApresMatchPastilleN"), "Forme W/D/L affichée V N D")
	for m in 5: check(ecran.find_child("ApresMatchAutreMatch%d" % m, true, false) != null, "Autre match de la journée n° %d" % m)
	check(ecran.find_child("ApresMatchTaPlace", true, false) != null, "Ta place")
	check(ecran.find_child("ApresMatchFil", true, false) != null, "Fil du score")
	var gabi := ecran.find_child("ApresMatchGabiPhrase", true, false) as Label
	check(gabi != null and gabi.text.contains("discipline"), "Gabi nomme le levier à corriger : " + (gabi.text if gabi != null else ""))
	# Charte finale : un seul aplat doré, « Valider le résultat », en pilule.
	var dores := aplats_dores(ecran)
	check(dores == ["ApresMatchValiderFond"], "Un seul aplat doré, Valider le résultat : " + str(dores))
	var fond_valider := ecran.find_child("ApresMatchValiderFond", true, false)
	check(fond_valider != null and float(fond_valider.get("rayon")) < 0.0, "Valider le résultat : pilule dorée")
	var texte_valider := ecran.find_child("ApresMatchValiderTexte", true, false) as Label
	check(texte_valider != null and texte_valider.get_theme_color("font_color") == Charte.PANNEAU, "Valider le résultat : texte PANNEAU sur le doré")
	# Panneaux arrondis à 18, sans bordure ; aucun cadre complet hors focus et pilules.
	for nom in ["ApresMatchClassement", "ApresMatchFil", "ApresMatchGabi", "ApresMatchTaPlace", "ApresMatchAutresMatchs", "ApresMatchScoreCadre"]:
		var panneau := ecran.find_child(nom, true, false) as PanelContainer
		var sp := panneau.get_theme_stylebox("panel") as StyleBoxFlat if panneau != null else null
		check(sp != null and sp.corner_radius_top_left == Charte.RAYON_PANNEAU and sp.border_width_left + sp.border_width_top + sp.border_width_right + sp.border_width_bottom == 0, "Panneau %s : rayon 18, sans bordure" % nom)
	check(cadres_complets(ecran).is_empty(), "Aucun cadre complet : " + str(cadres_complets(ecran)))
	# Couleur des clubs seulement sur leur écusson : le score et les plaques posent sur PANNEAU, pas sur la couleur du club.
	for cote in 2:
		var plaque := ecran.find_child("ApresMatchPlaque%d" % cote, true, false)
		var traces: Array = plaque.find_children("*", "Control", true, false).filter(func(n: Node): return n.get("forme") == "pave" and n.name != "Ecusson") if plaque != null else [null]
		check(plaque != null and traces.is_empty() and plaque.find_child("Ecusson", true, false) != null, "Plaque %d : écusson du club, sans fond à sa couleur" % cote)
	# Pastilles V / N / D : pilule, lettre écrite, forme lisible sans la couleur (pleine, demi-pleine, contour).
	var fond_v := ecran.find_child("ApresMatchPastilleV", true, false).find_child("FondPastille", true, false)
	check(fond_v != null and float(fond_v.get("rayon")) < 0.0 and fond_v.get("couleur") == Charte.V, "Pastille V : pilule pleine vert clair")
	var forme_d: Node = forme.get_child(1).find_child("FondPastille", true, false) if forme != null else null
	check(forme_d != null and (forme_d.get("couleur") as Color).a == 0.0 and forme_d.get("bord") == Charte.D, "Pastille D : contour doré, sans aplat")
	var texte_d: Node = forme.get_child(1).find_children("*", "Label", true, false)[0] if forme != null and forme.get_child(1).find_children("*", "Label", true, false).size() > 0 else null
	check(texte_d != null and (texte_d as Label).get_theme_color("font_color") == Charte.IVOIRE, "Pastille D : lettre en crème (pas de doré en plus du contour)")
	var forme_n: Node = forme.get_child(2).find_child("FondPastille", true, false) if forme != null else null
	check(forme_n != null and (forme_n.get("couleur") as Color).a > 0.0 and (forme_n.get("couleur") as Color).a < 1.0, "Pastille N : demi-pleine")
	# Classement : pas de bandes alternées ; notre club en ligne sélectionnée (coins de 6 px).
	var fonds_lignes: Array = []
	for rang in range(1, 13):
		var ligne_c := ecran.find_child("ApresMatchLigne%d" % rang, true, false) as PanelContainer
		var sl := ligne_c.get_theme_stylebox("panel") as StyleBoxFlat if ligne_c != null else null
		if sl != null and rang != 3: fonds_lignes.append(sl.bg_color.a)
	check(fonds_lignes.size() == 11 and fonds_lignes.all(func(a: float): return a == 0.0), "Classement sans bandes alternées : " + str(fonds_lignes))
	var notre_ligne := ecran.find_child("ApresMatchLigne3", true, false) as PanelContainer
	var style_nous := notre_ligne.get_theme_stylebox("panel") as StyleBoxFlat if notre_ligne != null else null
	check(style_nous != null and style_nous.bg_color == Charte.SELECTION and style_nous.corner_radius_top_left > 0, "Notre club : ligne sélectionnée (SELECTION, coins arrondis)")
	var capture := OS.get_environment("CD_APRES_MATCH_PNG")
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture) == OK, "Capture : " + capture)
	# Tout ce qui a l'air cliquable ouvre quelque chose.
	var connus := ["club", "player", "menu", "date", "competition", "training"]
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
		if str(cible.get("kind", "")) == "detail" or b.disabled: continue
		directeur.cibles.clear()
		b.pressed.emit()
		var ok: bool = directeur.cibles.size() == 1 and str(directeur.cibles[0].get("kind", "")) in connus and (not str(directeur.cibles[0].get("id", "")).is_empty() or not str(directeur.cibles[0].get("route", "")).is_empty())
		check(ok, "Clic sur %s ouvre un écran : %s" % [b.name, str(directeur.cibles)])
	# Chaque levier mène à sa section.
	var attendus := {"condition": {"kind": "menu", "route": "Effectif"}, "tactique": {"kind": "menu", "route": "Plan de jeu"}, "discipline": {"kind": "training", "id": "team"}}
	for levier: String in attendus:
		var b := ecran.find_child("ApresMatchLevier_" + levier, true, false) as Button
		check(b != null and b.get_meta("cible", {}) == attendus[levier], "Levier %s : %s" % [levier, str(b.get_meta("cible", {}) if b != null else "absent")])
	check(ApresMatch.cible_levier({"levier": "composition"}).cible == {"kind": "menu", "route": "Composition"}, "Levier composition : Composition")
	# Joueur adverse : clic = XV type de son club, survol = mini-fiche « ce que le jeu connaît » (pas une fenêtre).
	var adverse := ecran.find_child("ApresMatchJoueur_x4", true, false) as Button
	check(adverse != null and adverse.get_meta("cible", {}) == {"kind": "club", "id": "100", "onglet": 2}, "Joueur adverse : XV type de son club")
	check(adverse != null and adverse.has_meta("fiche_adverse"), "Joueur adverse : mini-fiche au survol")
	if adverse != null:
		var fiche: Control = ecran.montrer_fiche_adverse(adverse, "x4", "J. Pell", {"id": 100, "name": NOMS[0]}, 1)
		var textes: Array = fiche.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if fiche != null else []
		check(fiche != null and not fiche.is_class("Window") and ("Ailier · " + NOMS[0]) in textes and "—" in textes, "Mini-fiche adverse : poste, club, niveau inconnu : " + str(textes))
		ecran.cacher_fiche_adverse()
	# Fil du score : nature écrite, auteur de la transformation.
	var natures: Array = ecran.find_children("Nature", "Label", true, false).map(func(l: Label): return l.text)
	check(natures == ["PÉNALITÉ", "ESSAI TRANSFORMÉ"], "Fil du score : nature de chaque marque : " + str(natures))
	check(ecran.find_child("ApresMatchJoueur_x10", true, false) != null, "Fil du score : auteur de la transformation")
	# Lien indisponible : grisé, raison écrite, aucun clic silencieux.
	var indispo := ecran.find_child("ApresMatchClubLigne12", true, false) as Button
	check(indispo != null and indispo.disabled and indispo.tooltip_text.begins_with("Fiche du club indisponible"), "Club indisponible : lien grisé et raison écrite")
	# Ta place : écarts écrits sans ambiguïté.
	var place := ecran.find_child("ApresMatchTaPlace", true, false)
	var textes_place: Array = place.find_children("*", "Control", true, false).filter(func(n: Control): return n is Label or n is Button).map(func(n: Control): return n.get("text")) if place != null else []
	check(textes_place.any(func(x: String): return x.begins_with("à égalité avec le 4e")) and textes_place.any(func(x: String): return x.begins_with("à 4 pts du 1er")), "Ta place : écarts écrits : " + str(textes_place))
	# Autres matchs : jamais de troncature.
	var autres := ecran.find_child("ApresMatchAutresMatchs", true, false)
	var coupes: Array = autres.find_children("*", "Label", true, false).filter(func(l: Label): return l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) if autres != null else [null]
	check(coupes.is_empty(), "Autres matchs sans troncature")
	# Anneau de focus du bouton doré : jamais au repos ni à la souris, seulement au clavier ; doré, en pilule.
	var cadre_focus := ecran.find_child("ApresMatchValiderFocus", true, false) as Control
	check(cadre_focus != null and not cadre_focus.visible, "Bouton or : pas de cadre de focus au repos")
	var anneau := cadre_focus.get_theme_stylebox("panel") as StyleBoxFlat if cadre_focus != null else null
	check(anneau != null and anneau.border_color == Charte.OR and anneau.border_width_left == 2 and anneau.corner_radius_top_left >= Charte.RAYON_PILULE, "Anneau de focus : doré, 2 px, en pilule")
	var touche := InputEventKey.new()
	touche.keycode = KEY_TAB
	touche.pressed = true
	ecran._input(touche)
	(ecran.find_child("ApresMatchValider", true, false) as Control).grab_focus()
	await process_frame
	check(cadre_focus != null and cadre_focus.visible, "Bouton or : cadre de focus en navigation au clavier")
	var souris := InputEventMouseButton.new()
	souris.pressed = true
	ecran._input(souris)
	check(cadre_focus != null and not cadre_focus.visible, "Bouton or : cadre retiré dès la souris")
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
	var gabi_720 := ecran.find_child("ApresMatchGabi", true, false) as Control
	check(gabi_720 != null and gabi_720.get_global_rect().end.y <= 721.0, "1280×720 : Gabi dans l'écran")
	var place_720 := ecran.find_child("ApresMatchTaPlace", true, false) as Control
	check(place_720 != null and place_720.is_visible_in_tree(), "1280×720 : Ta place reste (ligne condensée)")
	var derniere_ligne := ecran.find_child("ApresMatchLigne12", true, false) as Control
	check(derniere_ligne != null and derniere_ligne.get_global_rect().end.y <= 721.0, "1280×720 : classement complet visible")
	if failures.is_empty(): print("Après-match Godot · %d contrôles réussis" % checks)
	else: printerr("Après-match Godot · %d échec(s) sur %d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
