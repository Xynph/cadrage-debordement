extends SceneTree
## Fenêtre « Équipe » du match en direct (profil Monde préparé par tests/godot-fenetre-equipe.cjs, jour de match) :
## un seul bouton ÉQUIPE (plus de TACTIQUE ni de BANC), la fenêtre s'ouvre en plein écran et met le match en
## pause ; quinze médaillons avec portrait et banc en tuiles ; un vrai remplacement (charge `substitute`
## {slot, outId, inId} lue par le vrai moteur) ; une consigne depuis l'onglet Consignes (`set_consignes`) ;
## les cris de la touche envoient `cri` ; rien ne déborde en 1280×720, 1920×1080 et 2560×1440 ;
## « Valider et reprendre » relance le match. Pour des captures proches de la maquette (match à peine commencé :
## tout le monde frais), le modèle montré varie énergies, états et notes, et complète ce que le moteur n'a pas
## encore à dire (conseil de changement, adversaire) ; les champs réels du moteur sont gardés quand ils existent.
## Captures (affichage graphique) : CD_EQUIPE_OUTPUT=<dossier>.
var app: Control
var director: Node
var vue: Control
var fenetre: Control
var sortie := OS.get_environment("CD_EQUIPE_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var rapport := {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 8) -> void:
	for i in images: await process_frame

func jusqua(condition: Callable, limite_ms: int = 30000) -> bool:
	var fin := Time.get_ticks_msec() + limite_ms
	while Time.get_ticks_msec() < fin:
		if condition.call(): return true
		await process_frame
	return condition.call()

func attendre(commande: String) -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, commande + " : réponse du vrai moteur " + str(app.last_error))
	await poser(6)

func demander(commande: String, payload := {}) -> void:
	app._command(commande, payload)
	await attendre(commande)

func live() -> Dictionary:
	return app.model.get("live") if app.model.get("live") is Dictionary else {}

func talk() -> Dictionary:
	var v: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return v if v is Dictionary else {}

func boutons_textes(racine: Node) -> Array:
	return racine.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree()).map(func(b: Button) -> String: return b.text.strip_edges().to_upper())

func taille(largeur: int, hauteur: int) -> void:
	root.size = Vector2i(largeur, hauteur)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await poser(10)

func capturer(nom: String) -> void:
	await poser(12)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

## Modèle montré : le vrai modèle, plus les champs de pilotage que le moteur n'expose pas encore.
func modele_enrichi() -> Dictionary:
	var m: Dictionary = app.model.duplicate(true)
	var l: Dictionary = m.live
	var lineup: Array = l.get("lineup", [])
	var reserves: Array = l.get("reserves", [])
	var notes := {}
	for n in lineup.size():
		if not lineup[n] is Dictionary: continue
		if not lineup[n].has("rating"): lineup[n]["rating"] = 72 + (n * 7) % 14
		lineup[n]["condition"] = [71, 52, 61, 74, 77, 63, 66, 80, 82, 79, 88, 85, 83, 90, 86][n]
		notes[str(lineup[n].id)] = {"note": 5.9 + float((n * 3) % 22) / 10.0, "faits": 3}
	for n in reserves.size():
		if reserves[n] is Dictionary and not reserves[n].has("rating"): reserves[n]["rating"] = 72 + (n * 5) % 6
	if reserves.size() > 0 and reserves[0] is Dictionary: reserves[0]["conseil"] = "Veut se montrer"
	var direct: Dictionary = l.get("direct") if l.get("direct") is Dictionary else {}
	direct["notes"] = notes
	l["direct"] = direct
	var p: Dictionary = l.get("pilotage") if l.get("pilotage") is Dictionary else {}
	var joueurs := {}
	var etats := [["galvanise", "Galvanisé"], ["tendu", "Tendu"], ["indifferent", "Indifférent"], ["motive", "Motivé"], ["indifferent", "Indifférent"], ["vexe", "Vexé"], ["indifferent", "Indifférent"], ["serein", "Serein"], ["motive", "Motivé"], ["galvanise", "Galvanisé"]]
	for n in mini(lineup.size(), etats.size()):
		if lineup[n] is Dictionary: joueurs[str(lineup[n].id)] = {"etat": etats[n][0], "label": etats[n][1], "phase": "pre", "confiance": 60}
	p["joueurs"] = joueurs
	var consignes: Dictionary = p.get("consignes", {}).duplicate() if p.get("consignes") is Dictionary else {}
	consignes["rucks"] = "agressive"
	p["consignes"] = consignes
	p["bilans"] = [{"axe": "rucks", "valeur": "agressive", "depuis": 41, "texte": "Rucks « Contester » depuis 41′ : 3 pénalités, 2 ballons arrachés."}]
	if not p.get("cris") is Dictionary: p["cris"] = {"options": [{"id": "encourager", "label": "Encourager", "note": "Rassure les tendus", "disponible": true},
		{"id": "exiger", "label": "Exiger", "note": "Déjà crié à 41′ : s’use", "disponible": true},
		{"id": "calmer", "label": "Calmer", "note": "Moins de fautes au sol", "disponible": true},
		{"id": "defense", "label": "Serrer la défense", "note": "Ils attaquent large", "disponible": true},
		{"id": "tout", "label": "Tout donner", "note": "Pour la fin de match", "disponible": false}], "actif": {"id": "calmer", "label": "Calmer", "jusqua": 58}}
	if lineup.size() >= 7:
		# Prévision : celle du moteur si elle existe (recalée sur les énergies montrées), sinon quatre joueurs.
		var prevision: Array = p.get("fatigue") if p.get("fatigue") is Array and not (p.fatigue as Array).is_empty() else [1, 2, 5, 6].map(func(n: int) -> Dictionary: return {"id": str(lineup[n].id), "condition": 100, "prevue": 93})
		for ligne: Variant in prevision:
			for joueur: Variant in lineup:
				if ligne is Dictionary and joueur is Dictionary and str(joueur.id) == str(ligne.id):
					var baisse := float(ligne.condition) - float(ligne.prevue)
					ligne["condition"] = joueur.condition
					ligne["prevue"] = int(joueur.condition) - maxi(4, roundi(baisse))
		p["fatigue"] = prevision
		var entrant := ""
		for option: Variant in l.get("substitutions", []):
			if option is Dictionary and int(option.slot) == 1 and not (option.get("inIds", []) as Array).is_empty(): entrant = str(option.inIds[0])
		if entrant.is_empty() and reserves.size() > 0: entrant = str(reserves[0].id)
		if not p.get("conseilChangement") is Dictionary: p["conseilChangement"] = {"slot": 1, "outId": str(lineup[1].id), "inId": entrant, "texte": "Le talonneur est à 52 %, deux lancers ratés. Le remplaçant est frais et veut se montrer."}
	var adversaire: Dictionary = p.get("adversaire") if p.get("adversaire") is Dictionary else {}
	var leurs: Dictionary = adversaire.get("consignes", {}).duplicate() if adversaire.get("consignes") is Dictionary else {}
	if leurs.values().all(func(v: Variant) -> bool: return str(v) in ["normal", "normale"]):
		leurs["rucks"] = "agressive"
		leurs["piedJeu"] = "plus"
	adversaire["consignes"] = leurs
	if not adversaire.get("derniers") is Array or (adversaire.derniers as Array).is_empty():
		adversaire["derniers"] = [{"minute": 12, "texte": "Ils contestent chaque ruck."}, {"minute": 18, "texte": "Ils occupent au pied dès la sortie de leurs 22."}]
	adversaire["lecture"] = "Ils concèdent des pénalités au sol : jouer vite les ballons les punit."
	p["adversaire"] = adversaire
	# Avis du staff : celui du moteur s'il en a un, sinon un avis type (à la 0e minute il n'a encore rien vu).
	var staff: Dictionary = p.get("staff") if p.get("staff") is Dictionary else {}
	if not staff.get("propositions") is Array or (staff.propositions as Array).is_empty():
		staff = {"niveau": 64, "minute": 45, "propositions": [
			{"axe": "discipline", "valeur": "stricte", "label": "Discipline", "actuelLabel": "Normale", "valeurLabel": "Zéro faute", "raison": "3 pénalités concédées en 5 minutes."},
			{"axe": "touche", "valeur": "sure", "label": "Touche", "actuelLabel": "Normale", "valeurLabel": "Assurer", "raison": "2 touches perdues en 5 minutes."}]}
	p["staff"] = staff
	l["pilotage"] = p
	return m

func ouvrir_par_le_bouton() -> void:
	var bouton: Button = vue.find_child("MatchBetweenTeam", true, false)
	verifier(bouton != null, "bouton ÉQUIPE de l'écran intermédiaire")
	if bouton == null: bouton = vue.find_child("MatchTeamButton", true, false)
	if bouton != null:
		bouton.disabled = false
		bouton.pressed.emit()
	await poser(4)

func controler_mise_en_page(contexte: String) -> void:
	await poser(6)
	verifier(fenetre.is_visible_in_tree(), contexte + " : fenêtre visible")
	var cadre := fenetre.get_global_rect()
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
	verifier(ecran.grow(1).encloses(cadre), contexte + " : fenêtre dans l'écran %s" % cadre)
	for echec in fenetre.debordements(): verifier(false, contexte + " : " + echec)
	var page: Control = fenetre.find_child("TeamPage", true, false)
	verifier(page != null and ecran.grow(1).encloses(page.get_global_rect()), contexte + " : page de la maquette dans l'écran")
	controler_charte(contexte)

const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const ETATS_STYLE := ["panel", "normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const COULEURS_POLICE := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]

static func proche_or(couleur: Color) -> bool:
	for o: Color in [Charte.OR, Charte.OR_VIF, C.OR, C.OR_VIF]:
		if absf(couleur.r - o.r) < 0.03 and absf(couleur.g - o.g) < 0.03 and absf(couleur.b - o.b) < 0.03 and couleur.a > 0.0: return true
	return false

## Charte finale (art-bible §3, §4.3, §7.1, adoptée le 20/11/2026) sur les contrôles visibles de la page : un seul
## aplat doré, « Valider et reprendre » (TeamResume), en pilule ; le doré reste permis en texte, en liseré et en anneau
## de focus ; boutons arrondis (hors terrain) ; ombre portée des jetons (noir 50 %, 4 px, sans décalage) sur chaque
## panneau, carte ou tuile, aucune sur pilules, boutons, cases ni lignes (choix de Léo du 20/11/2026) ; aucun panneau encadré sur ses quatre côtés (l'anneau de
## focus excepté) ; le lien « ← Retour au direct » et des textes d'au moins 12 px.
## Panneaux et tuiles à angles droits qui portent l'ombre par leur rôle (préfixes de noms).
const PANNEAUX_OMBRES := ["TeamHeader", "TeamFooter", "TeamPitchOmbre", "TeamFatigue", "TeamAdvice", "TeamConsignes", "TeamMatchSummary", "TeamStaffNote", "TeamGamePlan", "TeamReferee", "TeamOpponent"]

func _ombre_de_role(c: Control) -> bool:
	var nom := str(c.name)
	if nom.begins_with("TeamBench") and nom.substr(9).is_valid_int(): return c is BaseButton # carte du banc
	return not c is BaseButton and (nom in PANNEAUX_OMBRES or nom.begins_with("Role_"))

func controler_charte(contexte: String) -> void:
	var terrain: Control = fenetre.find_child("TeamPitchField", true, false)
	var ors: Array[String] = []
	var arrondis: Array[String] = []
	var ombres: Array[String] = []
	var sans_ombre: Array[String] = []
	var tuiles := 0
	var vus_par_role: Array[String] = []
	var seuil: int = fenetre.px(Charte.RAYON_CARTE) if fenetre.has_method("px") else Charte.RAYON_CARTE
	var cadres: Array[String] = []
	var petits: Array[String] = []
	var pleins: Array[String] = []
	for c: Control in fenetre.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree(): continue
		var sur_terrain := terrain != null and terrain.is_ancestor_of(c)
		for etat: String in ETATS_STYLE:
			if not c.has_theme_stylebox_override(etat): continue
			var s := c.get_theme_stylebox(etat) as StyleBoxFlat
			if s == null: continue
			# Aplat doré : le fond au repos d'un contrôle (bouton ou panneau) ; le survol (OR_VIF) suit le même bouton.
			if (etat == "normal" or etat == "panel") and proche_or(s.bg_color) and s.bg_color.a > 0.5: ors.append(str(c.name))
			# Bouton arrondi : tout bouton qui dessine un fond ou un contour au repos, hors terrain.
			if etat == "normal" and c is BaseButton and not sur_terrain and (s.bg_color.a > 0.0 or s.border_width_left + s.border_width_top + s.border_width_right + s.border_width_bottom > 0) 					and mini(mini(s.corner_radius_top_left, s.corner_radius_top_right), mini(s.corner_radius_bottom_left, s.corner_radius_bottom_right)) <= 0:
				arrondis.append(str(c.name))
			# Ombre : un fond plein de carte (rayon ≥ 12 à l'échelle) qui n'est pas une pilule porte l'ombre des jetons ;
			# tout le reste (pilule, case, ligne, contour seul) n'en a aucune.
			var r := maxi(maxi(s.corner_radius_top_left, s.corner_radius_top_right), maxi(s.corner_radius_bottom_left, s.corner_radius_bottom_right))
			var pilule := r >= Charte.RAYON_PILULE or float(r) * 2.0 >= minf(c.size.x, c.size.y) - 1.0
			# Panneaux et tuiles à angles droits de la fenêtre (bandeau, pied, terrain, banc, cartes, sections) : l'ombre
			# vient de leur rôle, quel que soit le rayon (Léo, 20/11/2026 : l'ombre sur toutes les tuiles).
			var par_role := _ombre_de_role(c) and s.draw_center and s.bg_color.a > 0.0 and etat != "focus"
			if par_role:
				tuiles += 1
				vus_par_role.append(str(c.name))
				if not Charte.porte_ombre(s): sans_ombre.append("%s.%s" % [c.name, etat])
			elif s.draw_center and s.bg_color.a > 0.0 and r >= seuil and not pilule:
				tuiles += 1
				if not Charte.porte_ombre(s): sans_ombre.append("%s.%s" % [c.name, etat])
			elif s.shadow_size > 0: ombres.append("%s.%s" % [c.name, etat])
			# Aucun cadre complet (panneaux, tuiles, crans, éteint) : au plus un filet ; l'anneau de focus doré est la règle.
			if etat != "focus" and s.border_width_left > 0 and s.border_width_top > 0 and s.border_width_right > 0 and s.border_width_bottom > 0: cadres.append("%s.%s" % [c.name, etat])
			# Un fond de bouton clair (ivoire ou proche) se lit comme un second bouton principal.
			if etat == "normal" and c is BaseButton and s.bg_color.a > 0.99 and (s.bg_color.is_equal_approx(Charte.IVOIRE) or s.bg_color.get_luminance() > 0.5): pleins.append(str(c.name))
		if c is Label or c is Button:
			if c.has_theme_font_size_override("font_size") and c.get_theme_font_size("font_size") < 12: petits.append("%s (%d)" % [c.name, c.get_theme_font_size("font_size")])
	verifier(ors == ["TeamResume"], contexte + " : un seul aplat doré, « Valider et reprendre » (%s)" % str(ors.slice(0, 6)))
	var reprendre: Button = fenetre.find_child("TeamResume", true, false)
	var style_reprendre := reprendre.get_theme_stylebox("normal") as StyleBoxFlat if reprendre != null else null
	verifier(style_reprendre != null and style_reprendre.corner_radius_top_left >= reprendre.size.y * 0.5 - 1.0, contexte + " : « Valider et reprendre » en pilule")
	verifier(arrondis.is_empty(), contexte + " : boutons arrondis hors terrain (%s)" % str(arrondis.slice(0, 6)))
	verifier(ombres.is_empty(), contexte + " : aucune ombre sur pilules, boutons, cases ni lignes (%s)" % str(ombres.slice(0, 6)))
	verifier(sans_ombre.is_empty(), contexte + " : %d panneau(x), carte(s) ou tuile(s), tous avec l'ombre des jetons (sans : %s)" % [tuiles, str(sans_ombre.slice(0, 6))])
	verifier(not vus_par_role.is_empty() and vus_par_role.has("TeamHeader") and vus_par_role.has("TeamFooter"), contexte + " : bandeau du haut et pied portent l'ombre (%s)" % str(vus_par_role.slice(0, 6)))
	if fenetre.onglet == "composition": verifier(vus_par_role.has("TeamPitchOmbre") and vus_par_role.filter(func(n: String) -> bool: return n.begins_with("TeamBench")).size() >= 8, contexte + " : terrain et cartes du banc portent l'ombre (%s)" % str(vus_par_role.filter(func(n: String) -> bool: return n.begins_with("TeamBench")).size()))
	verifier(cadres.is_empty(), contexte + " : aucun panneau encadré sur ses quatre côtés (%s)" % str(cadres.slice(0, 6)))
	verifier(petits.is_empty(), contexte + " : textes d'au moins 12 px (%s)" % str(petits.slice(0, 6)))
	verifier(pleins == ["TeamResume"], contexte + " : un seul bouton en aplat clair, « Valider et reprendre » (%s)" % str(pleins))
	var retour: Button = fenetre.find_child("TeamBackToLive", true, false)
	verifier(retour != null and retour.is_visible_in_tree() and retour.text == "← Retour au direct" and retour.has_meta("lien"), contexte + " : lien « ← Retour au direct » en tête de page")
	var choisis := fenetre.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree() and bool(b.get_meta("coche", false)))
	verifier(choisis.all(func(b: Button) -> bool: return b.icon != null or b.find_child("Coche", true, false) != null), contexte + " : chaque choix courant porte sa coche")
	var onglet: Button = fenetre.find_child({"composition": "TeamTabComposition", "consignes": "TeamTabConsignes", "roles": "TeamTabRoles"}[fenetre.onglet], true, false)
	verifier(onglet != null and bool(onglet.get_meta("coche", false)), contexte + " : onglet courant coché")
	# Choix courant : fond sombre relevé (jamais ivoire) et filet GAUCHE épais, sans filet sur les autres côtés.
	for b: Button in choisis:
		var s := b.get_theme_stylebox("normal") as StyleBoxFlat
		if s == null or b.icon == null: continue
		verifier(s.border_width_left >= 2 and s.border_width_top == 0 and s.border_width_right == 0 and s.border_width_bottom == 0 and s.bg_color.get_luminance() < 0.3, contexte + " : choix « %s » en filet gauche sur fond sombre" % b.name)
	# Menus déroulants du plan de jeu : fond PANNEAU, angles droits, sans ombre.
	for choix: OptionButton in fenetre.find_children("*", "OptionButton", true, false):
		var fond := choix.get_popup().get_theme_stylebox("panel") as StyleBoxFlat
		verifier(fond != null and fond.bg_color.is_equal_approx(Charte.PANNEAU) and fond.shadow_size == 0, contexte + " : menu de « %s » habillé (PANNEAU, sans ombre)" % choix.name)
	verifier(fenetre.name == "MatchTeamPage", contexte + " : calque nommé MatchTeamPage (%s)" % fenetre.name)

const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")

## Lien du nom d'un de nos joueurs sous `racine` : mini-fiche au survol (`MiniFiche.lier`) et fiche au clic.
static func lien_fiche(racine: Node) -> Button:
	if racine == null: return null
	for b: Button in racine.find_children("*", "Button", true, false):
		if b.has_meta("mini_fiche_joueur") and b.has_meta("fiche_joueur"): return b
	return null

## Règle de Léo sur les noms de nos joueurs : chaque médaillon, tuile du banc, bloc « Dans 10 minutes » et la carte
## de Gabi portent un nom lié (mini-fiche au survol, fiche complète au clic), lié au bon joueur.
func controler_noms(contexte: String) -> void:
	var lineup: Array = fenetre._lineup()
	for slot: int in fenetre.medaillons:
		var lien := lien_fiche(fenetre.medaillons[slot])
		var attendu := str(lineup[slot].get("id", "")) if slot < lineup.size() and lineup[slot] is Dictionary else ""
		verifier(lien != null and str(lien.get_meta("mini_fiche_joueur")) == attendu and str(lien.get_meta("fiche_joueur")) == attendu, contexte + " : nom lié du médaillon %d" % (slot + 1))
	for id: String in fenetre.tuiles:
		var lien := lien_fiche(fenetre.tuiles[id])
		verifier(lien != null and str(lien.get_meta("mini_fiche_joueur")) == id, contexte + " : nom lié du remplaçant " + id)
	var blocs := fenetre.find_children("TeamFatigue_*", "", true, false)
	verifier(not blocs.is_empty(), contexte + " : blocs « Dans 10 minutes »")
	for bloc: Control in blocs:
		var lien := lien_fiche(bloc)
		verifier(lien != null and bloc.has_meta("fiche_joueur") and str(lien.get_meta("mini_fiche_joueur")) == str(bloc.get_meta("fiche_joueur")) and bloc.mouse_filter == Control.MOUSE_FILTER_STOP, contexte + " : bloc fatigue %s lié à la fiche" % bloc.name)
	var conseil: Control = fenetre.find_child("TeamAdvice", true, false)
	var liens_conseil := conseil.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.has_meta("mini_fiche_joueur")) if conseil != null else []
	verifier(liens_conseil.size() >= 2, contexte + " : sortant et entrant nommés en liens dans le conseil de Gabi (%d)" % liens_conseil.size())

func source_fiche(sorte: String, id_banc: String) -> Control:
	match sorte:
		"medaillon": return lien_fiche(fenetre.medaillons.get(0))
		"banc": return lien_fiche(fenetre.tuiles.get(id_banc))
		"fatigue":
			var blocs := fenetre.find_children("TeamFatigue_*", "", true, false)
			return blocs[0] if not blocs.is_empty() else null
		"conseil": return lien_fiche(fenetre.find_child("TeamAdvice", true, false))
	return null

## Clic sur un nom : la fiche complète s'ouvre dans une page du direct, la page Équipe reste ouverte dessous et on la
## retrouve au retour ; le clic sur le médaillon ou la tuile garde son action (choisir un poste, un entrant).
func controler_fiches() -> void:
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(6)
	fenetre.poste_choisi = -1
	fenetre.entrant_choisi = ""
	(fenetre.medaillons[0] as Button).pressed.emit()
	await poser(2)
	verifier(fenetre.poste_choisi == 0, "clic sur le médaillon : choisit le poste")
	(fenetre.medaillons[0] as Button).pressed.emit()
	await poser(2)
	verifier(fenetre.poste_choisi == -1, "second clic sur le médaillon : poste rendu")
	var id_banc: String = fenetre.tuiles.keys()[0] if not fenetre.tuiles.is_empty() else ""
	if not id_banc.is_empty():
		(fenetre.tuiles[id_banc] as Button).pressed.emit()
		await poser(2)
		verifier(fenetre.entrant_choisi == id_banc, "clic sur la tuile : choisit l'entrant")
		(fenetre.tuiles[id_banc] as Button).pressed.emit()
		await poser(2)
		verifier(fenetre.entrant_choisi == "", "second clic sur la tuile : entrant rendu")
	var lien := lien_fiche(fenetre.medaillons[0])
	verifier(lien != null, "nom lié du médaillon 1")
	if lien == null: return
	var id := str(lien.get_meta("fiche_joueur"))
	lien.mouse_entered.emit()
	await poser(2)
	var mini: Control = MiniFiche.actuelle(app)
	verifier(mini != null and str(mini.get_meta("player_id", "")) == id, "survol du nom : mini-fiche du joueur")
	lien.mouse_exited.emit()
	await poser(2)
	verifier(MiniFiche.actuelle(app) == null, "la souris part : mini-fiche cachée")
	# Chaque source est recherchée après reconstruction de la page (les nœuds d'avant peuvent avoir été libérés).
	for paire: Array in [["nom du médaillon", "medaillon"], ["nom du banc", "banc"], ["bloc fatigue", "fatigue"], ["nom dans le conseil de Gabi", "conseil"]]:
		var source := source_fiche(str(paire[1]), id_banc)
		verifier(source != null, str(paire[0]) + " présent")
		if source == null: continue
		var attendu := str(source.get_meta("fiche_joueur", ""))
		if source is Button: (source as Button).pressed.emit()
		else:
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = true
			source.gui_input.emit(clic)
		await poser(6)
		# Plein écran obligatoire : la fiche du joueur est une petite fenêtre par-dessus le direct (jamais une page).
		var hote: Control = vue.get("fenetre_hote") if vue.fenetre_ouverte() else null
		var panneau: Control = hote.find_child("MatchFenetreJoueurPanneau", true, false) if hote != null else null
		verifier(panneau != null and str(panneau.get_meta("player_id", "")) == attendu, str(paire[0]) + " : petite fenêtre du joueur par-dessus le direct")
		verifier(fenetre.visible and hote != null and hote.get_index() > fenetre.get_index(), str(paire[0]) + " : page Équipe ouverte dessous")
		var croix: Button = hote.find_child("MatchFenetreJoueurFermer", true, false) if hote != null else null
		verifier(croix != null, str(paire[0]) + " : ✕ sur la fenêtre")
		if croix != null: croix.pressed.emit()
		else: vue.fermer_fenetre()
		await poser(10)
		verifier(not vue.fenetre_ouverte() and fenetre.visible and fenetre.medaillons.size() == 15, str(paire[0]) + " : fenêtre fermée, la page Équipe est retrouvée")
		verifier(bool(live().get("paused", false)) and not bool(vue.get("_reprendre_apres")), str(paire[0]) + " : le match reste arrêté après la fiche")
		fenetre.update_frame(modele_enrichi())
		await poser(4)

## Textes non tronqués : les étiquettes qui passent à la ligne montrent toutes leurs lignes, celles d'une seule
## ligne tiennent dans leur largeur ; les crans partagent une seule taille de police et ont l'infobulle complète.
func controler_textes(contexte: String) -> void:
	for nom in ["TeamShoutLabel", "TeamShoutNote", "TeamMatchConsignes"]:
		for l: Label in fenetre.find_children(nom, "Label", true, false):
			if not l.is_visible_in_tree(): continue
			verifier(l.get_visible_line_count() >= l.get_line_count(), contexte + " : « %s » entier (%d/%d lignes)" % [l.text, l.get_visible_line_count(), l.get_line_count()])
	var arbitre: Label = fenetre.find_child("TeamFooterReferee", true, false)
	if arbitre != null:
		var police: Font = arbitre.get_theme_font("font")
		var besoin := police.get_string_size(arbitre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, arbitre.get_theme_font_size("font_size")).x
		verifier(besoin <= arbitre.size.x + 1.0, contexte + " : ligne arbitre du pied entière (%d > %d)" % [roundi(besoin), roundi(arbitre.size.x)])
		verifier(arbitre.get_parent().name == "TeamFooterLine2", contexte + " : arbitre sur sa propre ligne")
	var tailles := {}
	for b: Button in fenetre.find_children("Consigne_*_*", "Button", true, false):
		if not b.has_meta("axe"): continue
		tailles[b.get_theme_font_size("font_size")] = true
		var largeur := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		verifier(largeur <= b.size.x - 2.0, contexte + " : cran « %s » non tronqué (%d > %d)" % [b.text, roundi(largeur), roundi(b.size.x)])
		verifier(b.tooltip_text.begins_with(b.text) or b.tooltip_text.length() > b.text.length(), contexte + " : infobulle du cran « %s »" % b.text)
		verifier(b.autowrap_mode == TextServer.AUTOWRAP_OFF, contexte + " : cran « %s » sur une ligne" % b.text)
	if not tailles.is_empty(): verifier(tailles.size() == 1, contexte + " : crans à une seule taille de police (%s)" % str(tailles.keys()))
	var plan: Button = fenetre.find_child("Consigne_penalites_touch", true, false)
	if plan != null: verifier(plan.text == "Pénaltouche" and plan.tooltip_text.begins_with("Chercher la pénaltouche"), contexte + " : « Pénaltouche » court, libellé complet en infobulle")

func composition_enrichie(contexte: String) -> void:
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(8)
	var terrain: Control = fenetre.find_child("TeamPitch", true, false)
	verifier(fenetre.medaillons.size() == 15, contexte + " : 15 médaillons (%d)" % fenetre.medaillons.size())
	var portraits := 0
	for slot: int in fenetre.medaillons:
		var m: Control = fenetre.medaillons[slot]
		if m.find_child("Portrait", true, false) != null: portraits += 1
		if terrain != null: verifier(terrain.get_global_rect().grow(2).encloses(m.get_global_rect()), contexte + " : médaillon %d dans le terrain" % (slot + 1))
	verifier(portraits == 15, contexte + " : 15 portraits sur le terrain (%d)" % portraits)
	var niveaux: int = fenetre.medaillons.values().filter(func(m: Variant) -> bool: return not str(m.get("niveau")).is_empty()).size()
	verifier(niveaux == 15, contexte + " : badge de niveau sur les 15 (%d)" % niveaux)
	var etats := fenetre.find_children("TeamPlayerState", "", true, false).size()
	verifier(etats >= 5, contexte + " : états après causerie (%d)" % etats)
	verifier(fenetre.find_children("TeamPlayerNote", "", true, false).size() == 15, contexte + " : note du match sous chaque nom")
	verifier(fenetre.tuiles.size() == live().get("reserves", []).size() and fenetre.tuiles.size() > 0, contexte + " : une tuile par remplaçant (%d)" % fenetre.tuiles.size())
	for id: String in fenetre.tuiles: verifier(fenetre.tuiles[id].find_child("Portrait", true, false) != null, contexte + " : portrait du remplaçant " + id)
	for nom in ["TeamShouts", "TeamFatigue", "TeamAdvice", "TeamFooterReferee"]:
		var n: Control = fenetre.find_child(nom, true, false)
		verifier(n != null and n.is_visible_in_tree(), contexte + " : bloc " + nom)
	controler_noms(contexte + " composition")
	controler_textes(contexte + " composition")
	await controler_mise_en_page(contexte + " composition")

func consignes_enrichies(contexte: String) -> void:
	fenetre.choisir_onglet("consignes")
	fenetre.update_frame(modele_enrichi())
	await poser(8)
	for nom in ["TeamConsignes", "TeamReferee", "TeamOpponent"]:
		var n: Control = fenetre.find_child(nom, true, false)
		verifier(n != null and n.is_visible_in_tree(), contexte + " : bloc " + nom)
	# Quatre groupes dans l'ordre de Léo (Attaque, Défense | Conquête, Adversaire) quand le moteur les donne.
	var axes: Array = live().get("pilotage", {}).get("axes", [])
	var attendu := 0
	for axe: Variant in axes: attendu += (axe.get("options", []) as Array).size() if axe is Dictionary else 0
	var crans := fenetre.find_children("Consigne_*_*", "Button", true, false).size()
	verifier(crans == attendu and attendu >= 15, contexte + " : un bouton par cran de chaque axe (%d/%d)" % [crans, attendu])
	if axes.any(func(a: Variant) -> bool: return a is Dictionary and a.has("groupe")):
		var gauche: Control = fenetre.find_child("TeamConsignesLeft", true, false)
		var droite: Control = fenetre.find_child("TeamConsignesRight", true, false)
		for paire: Array in [["attaque", gauche], ["defense", gauche], ["conquete", droite], ["adversaire", droite]]:
			var g: Control = fenetre.find_child("TeamGroup_" + str(paire[0]), true, false)
			verifier(g != null and paire[1] != null and (paire[1] as Control).is_ancestor_of(g), contexte + " : groupe %s dans sa colonne" % paire[0])
		var ga: Control = fenetre.find_child("TeamGroup_attaque", true, false)
		var gd: Control = fenetre.find_child("TeamGroup_defense", true, false)
		verifier(ga != null and gd != null and ga.get_global_rect().position.y < gd.get_global_rect().position.y, contexte + " : Attaque au-dessus de Défense")
		var defile: ScrollContainer = fenetre.find_child("TeamConsignesScroll", true, false)
		rapport["defilement_" + contexte] = defile.get_v_scroll_bar().visible if defile != null else null
		if contexte != "1280x720": verifier(defile != null and not defile.get_v_scroll_bar().visible, contexte + " : les quatre groupes tiennent sans défilement")
	var jauges := fenetre.find_children("TeamRefereeGauge_*", "", true, false).size()
	verifier(jauges == 4, contexte + " : 4 jauges de l'arbitre (%d)" % jauges)
	verifier(fenetre.find_child("TeamMatchSummary", true, false) != null, contexte + " : colonne de droite comblée (point sur le match)")
	controler_textes(contexte + " consignes")
	await controler_mise_en_page(contexte + " consignes")

func roles_enrichis(contexte: String) -> void:
	fenetre.choisir_onglet("roles")
	fenetre.update_frame(modele_enrichi())
	await poser(8)
	var roles: Variant = live().get("pilotage", {}).get("roles")
	verifier(roles is Dictionary, contexte + " : rôles dans le modèle")
	for id in ["buteur", "secours", "lanceur", "pied"]:
		var carte: Control = fenetre.find_child("Role_" + id, true, false)
		verifier(carte != null and carte.is_visible_in_tree(), contexte + " : carte du rôle " + id)
		if carte != null: verifier(carte.find_children("Role_%s_*" % id, "Button", true, false).size() >= 1, contexte + " : candidats du rôle " + id)
	await controler_mise_en_page(contexte + " rôles")

func executer() -> void:
	await taille(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await attendre("ouverture")
	director = app.find_child("ContextualDirector", true, false)
	await demander("begin_match")
	if director != null and director.view != null and director.view.has_method("_continue") and not talk().is_empty():
		director.view._continue(true)
		await attendre("match_talk_continue")
	await jusqua(func() -> bool: return app.find_child("ContextualLiveMatch", true, false) != null, 20000)
	vue = app.find_child("ContextualLiveMatch", true, false)
	verifier(vue != null and "equipe" in vue, "direct ouvert avec la fenêtre Équipe")
	if vue == null or not "equipe" in vue:
		_fin()
		return
	fenetre = vue.equipe
	# Un seul bouton ÉQUIPE : plus de TACTIQUE ni de BANC nulle part dans le direct.
	await jusqua(func() -> bool: return live().get("direct") is Dictionary, 30000)
	await poser(10)
	var textes := boutons_textes(vue)
	rapport.boutons = textes
	verifier("ÉQUIPE" in textes, "bouton ÉQUIPE visible (%s)" % str(textes))
	verifier(not "TACTIQUE" in textes and not "BANC" in textes, "ni TACTIQUE ni BANC (%s)" % str(textes))
	for nom in ["MatchBetweenTactics", "MatchBetweenBench"]: verifier(vue.find_child(nom, true, false) == null, "ancien bouton absent : " + nom)
	verifier(vue.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return b.text.strip_edges().to_upper() not in ["TACTIQUE", "BANC"]), "aucun bouton TACTIQUE ou BANC, même masqué")
	# Ouverture : plein écran, le match se met en pause.
	await ouvrir_par_le_bouton()
	verifier(fenetre.visible, "la fenêtre s'ouvre")
	verifier(await jusqua(func() -> bool: return bool(live().get("paused", false)) and not app.waiting, 30000), "le match se met en pause à l'ouverture")
	var minute := int(live().get("minute", 0))
	await poser(90)
	verifier(int(live().get("minute", 0)) == minute and bool(live().get("paused", false)), "le match reste en pause fenêtre ouverte")
	# Modèle réel (sans les champs à venir) : blocs optionnels masqués, rien ne casse.
	fenetre.update_frame(app.model)
	await poser(6)
	verifier(fenetre.medaillons.size() == 15, "15 médaillons sur le vrai modèle")
	var p_reel: Dictionary = live().get("pilotage") if live().get("pilotage") is Dictionary else {}
	if not p_reel.has("cris"): verifier(fenetre.find_child("TeamShouts", true, false) == null, "sans cris dans le modèle : colonne masquée")
	if not p_reel.has("fatigue"): verifier(fenetre.find_child("TeamFatigue", true, false) == null, "sans prévision : bande « Dans 10 minutes » masquée")
	if not p_reel.has("conseilChangement"): verifier(fenetre.find_child("TeamAdvice", true, false) == null, "sans conseil : carte de Gabi masquée")
	# Remplacement réel : un joueur du XV, puis un remplaçant autorisé par le moteur.
	var slot := -1
	var entrant := ""
	for option: Variant in live().get("substitutions", []):
		if option is Dictionary and not (option.get("inIds", []) as Array).is_empty() and slot < 0:
			slot = int(option.slot)
			entrant = str(option.inIds[0])
	verifier(slot >= 0, "au moins un changement autorisé match arrêté")
	if slot >= 0:
		var sortant := str(live().lineup[slot].id)
		fenetre.choisir_poste(slot)
		await poser(4)
		verifier(fenetre.poste_choisi == slot, "joueur du XV choisi")
		var tuile: Button = fenetre.tuiles.get(entrant)
		verifier(tuile != null and bool(tuile.get_meta("eligible", false)), "remplaçant autorisé en clair")
		var interdit: Array = fenetre.tuiles.keys().filter(func(id: String) -> bool: return not bool(fenetre.tuiles[id].get_meta("eligible", true)))
		for id: String in interdit: verifier(fenetre.tuiles[id].modulate.a < 0.6, "remplaçant non autorisé atténué " + id)
		if tuile != null: tuile.pressed.emit()
		verifier(app.last_command == "substitute", "clic sur le remplaçant : commande substitute")
		await attendre("substitute")
		rapport.remplacement = {"slot": slot, "outId": sortant, "inId": entrant, "apres": str(live().lineup[slot].id)}
		verifier(str(live().lineup[slot].id) == entrant, "le moteur a fait entrer %s au poste %d" % [entrant, slot + 1])
		verifier(not live().get("reserves", []).any(func(r: Variant) -> bool: return r is Dictionary and str(r.id) == entrant), "le remplaçant a quitté le banc")
		await poser(4)
		var statut: Label = fenetre.find_child("TeamStatus", true, false)
		rapport.statut = statut.text if statut != null else ""
		verifier(statut != null and statut.text.contains("entre à la place"), "message du changement : « %s »" % rapport.statut)
	# Onglet Consignes : un cran envoie set_consignes, le moteur le garde.
	(fenetre.find_child("TeamTabConsignes", true, false) as Button).pressed.emit()
	await poser(4)
	verifier(fenetre.onglet == "consignes", "onglet Consignes")
	var cran: Button = fenetre.find_child("Consigne_rythme_rapide", true, false)
	verifier(cran != null, "cran Rythme · Accélérer")
	if cran != null:
		cran.pressed.emit()
		verifier(app.last_command == "set_consignes", "clic sur un cran : set_consignes")
		await attendre("set_consignes")
		verifier(str(live().get("pilotage", {}).get("consignes", {}).get("rythme", "")) == "rapide", "consigne Rythme gardée par le moteur")
		await poser(4)
		var ligne: Control = fenetre.find_child("Consigne_rythme", true, false)
		verifier(ligne != null and bool(ligne.get_meta("modifie", false)), "ligne Rythme relevée (cran non neutre)")
	# Plan de jeu (axe « match en pause ») : la même commande, match arrêté.
	var plan: Dictionary = {}
	for axe: Variant in live().get("pilotage", {}).get("axes", []):
		if axe is Dictionary and str(axe.get("id", "")) == "planAttaque": plan = axe
	if not plan.is_empty():
		var autre := ""
		for option: Variant in plan.get("options", []):
			if autre.is_empty() and str(option.id) != str(plan.get("valeur", "")): autre = str(option.id)
		var bouton_plan: Button = fenetre.find_child("Consigne_planAttaque_" + autre, true, false)
		verifier(bouton_plan != null and not bouton_plan.disabled and fenetre.find_child("ConsignePause", true, false) != null, "plan de jeu modifiable match arrêté")
		if bouton_plan != null:
			bouton_plan.pressed.emit()
			await attendre("set_consignes plan")
			var apres := ""
			for axe: Variant in live().get("pilotage", {}).get("axes", []):
				if axe is Dictionary and str(axe.get("id", "")) == "planAttaque": apres = str(axe.get("valeur", ""))
			rapport.plan = [str(plan.get("valeur", "")), autre, apres, str(app.last_error)]
			verifier(apres == autre, "plan de jeu gardé par le moteur (%s)" % str(rapport.plan))
	# Cris de la touche : le bouton envoie `cri`.
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(4)
	var cris_reels: Variant = live().get("pilotage", {}).get("cris")
	rapport.cris_moteur = cris_reels is Dictionary
	var id_cri := ""
	if cris_reels is Dictionary:
		for option: Variant in cris_reels.get("options", []):
			if id_cri.is_empty() and option is Dictionary and bool(option.get("disponible", false)): id_cri = str(option.id)
	else: id_cri = "encourager"
	var cri: Button = fenetre.find_child("TeamShout_" + id_cri, true, false)
	verifier(cri != null and not cri.disabled, "cri « %s » disponible" % id_cri)
	if cri != null:
		# Charte finale : un cri est une carte arrondie (rayon 12) sans bordure.
		var repos := cri.get_theme_stylebox("normal") as StyleBoxFlat
		verifier(repos != null and repos.corner_radius_top_left >= 3 and repos.border_width_left == 0 and repos.border_width_top == 0 and repos.border_width_right == 0 and repos.border_width_bottom == 0, "cri au repos : carte arrondie sans bordure")
		cri.pressed.emit()
		verifier(app.last_command == "cri", "clic sur un cri : commande cri")
		await jusqua(func() -> bool: return not app.waiting, 20000)
		rapport.cri_reponse = str(app.last_error)
		if cris_reels is Dictionary:
			verifier(app.last_error.is_empty() and str(live().get("pilotage", {}).get("cris", {}).get("actif", {}).get("id", "") if live().get("pilotage", {}).get("cris", {}).get("actif") is Dictionary else "") == id_cri, "le moteur garde le cri actif")
			fenetre.update_frame(app.model)
			await poser(4)
			var actif: Button = fenetre.find_child("TeamShout_" + id_cri, true, false)
			verifier(actif != null and actif.disabled, "cri actif non relançable")
	# Avis du staff : le bouton « Appliquer ces consignes » envoie une seule commande (à la 0e minute le moteur
	# n'a rien à proposer et refuse en clair ; l'application réelle est vérifiée par tests/match-staff-roles.cjs).
	fenetre.choisir_onglet("consignes")
	fenetre.update_frame(modele_enrichi())
	await poser(6)
	var appliquer: Button = fenetre.find_child("TeamStaffApply", true, false)
	verifier(appliquer != null and appliquer.is_visible_in_tree() and not appliquer.disabled, "bouton Appliquer ces consignes")
	if appliquer != null:
		appliquer.pressed.emit()
		verifier(app.last_command == "appliquer_staff", "clic : commande appliquer_staff")
		await jusqua(func() -> bool: return not app.waiting, 20000)
		rapport.staff_reponse = str(app.last_error)
	# Onglet Rôles : un autre buteur parmi les joueurs sur le terrain, gardé par le moteur.
	(fenetre.find_child("TeamTabRoles", true, false) as Button).pressed.emit()
	fenetre.update_frame(app.model)
	await poser(6)
	verifier(fenetre.onglet == "roles", "onglet Rôles")
	var buteur: Dictionary = {}
	var roles_reels: Variant = live().get("pilotage", {}).get("roles")
	if roles_reels is Dictionary:
		for r: Variant in roles_reels.get("roles", []):
			if r is Dictionary and str(r.get("id", "")) == "buteur": buteur = r
	verifier(not buteur.is_empty(), "rôle buteur dans le modèle")
	if not buteur.is_empty():
		var choix := ""
		var numero := 0
		for c: Variant in buteur.get("candidats", []):
			if choix.is_empty() and c is Dictionary and str(c.id) != str(buteur.get("enJeu", {}).get("id", "")):
				choix = str(c.id)
				numero = int(c.num)
		# Nœud nommé par le numéro du joueur (un identifiant peut contenir des caractères refusés dans un nom de nœud).
		var bouton_role: Button = fenetre.find_child("Role_buteur_%d" % numero, true, false)
		if bouton_role != null: verifier(str(bouton_role.get_meta("joueur", "")) == choix, "bouton du candidat lié au bon joueur")
		verifier(bouton_role != null and not bouton_role.disabled, "candidat buteur cliquable")
		if bouton_role != null:
			bouton_role.pressed.emit()
			verifier(app.last_command == "set_role_direct", "clic : commande set_role_direct")
			await attendre("set_role_direct")
			var apres: String = ""
			for r: Variant in live().get("pilotage", {}).get("roles", {}).get("roles", []):
				if r is Dictionary and str(r.get("id", "")) == "buteur" and r.get("enJeu") is Dictionary: apres = str(r.enJeu.id)
			verifier(apres == choix, "le moteur garde le nouveau buteur (%s → %s)" % [choix, apres])
	# Mise en page : trois tailles, trois onglets ; captures en 1080p et 720p.
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		await taille(t.x, t.y)
		var nom := "%dx%d" % [t.x, t.y]
		await composition_enrichie(nom)
		if t.x != 2560: await capturer("equipe-composition-" + nom)
		await consignes_enrichies(nom)
		if t.x != 2560: await capturer("equipe-consignes-" + nom)
		await roles_enrichis(nom)
		if t.x != 2560: await capturer("equipe-roles-" + nom)
	await taille(1920, 1080)
	# Noms de nos joueurs : mini-fiche au survol, fiche complète au clic, page Équipe retrouvée au retour.
	await controler_fiches()
	# Joueur choisi puis remplaçant (état sélectionné) pour la capture.
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(4)
	fenetre.choisir_poste(1)
	await capturer("equipe-composition-selection-1920x1080")
	# « ← Retour au direct » : la page se ferme sans valider (le match reste arrêté), puis on la rouvre.
	fenetre.update_frame(app.model)
	await poser(2)
	var retour: Button = fenetre.find_child("TeamBackToLive", true, false)
	verifier(retour != null, "lien « ← Retour au direct »")
	if retour != null:
		retour.pressed.emit()
		verifier(not fenetre.visible, "« ← Retour au direct » ferme la page")
		await poser(30)
		verifier(bool(live().get("paused", false)) and not bool(fenetre.get("_veut_reprise")), "« ← Retour au direct » : le match reste arrêté (rien n'est validé)")
		vue.ouvrir_equipe()
		await poser(4)
		verifier(fenetre.visible, "la page se rouvre après le retour au direct")
	# Valider et reprendre : la fenêtre se ferme, le match repart.
	fenetre.update_frame(app.model)
	var reprise: Button = fenetre.find_child("TeamResume", true, false)
	verifier(reprise != null, "bouton Valider et reprendre")
	if reprise != null: reprise.pressed.emit()
	verifier(not fenetre.visible, "la fenêtre se ferme")
	verifier(await jusqua(func() -> bool: return not bool(live().get("paused", true)), 30000), "le match repart")
	_fin()

func _fin() -> void:
	print("EQUIPE ", JSON.stringify({"controles": controles, "failures": echecs, "rapport": rapport}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
