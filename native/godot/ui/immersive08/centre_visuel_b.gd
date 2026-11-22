extends RefCounted
## Centre de formation, direction B « Le chemin » (planche A/B, CD_VARIANTE_VISUELLE=B ; en attente du choix de Léo).
## Chaque onglet se lit de gauche à droite, de l'académie vers l'équipe première : étapes reliées par des flèches,
## Espoirs en jetons-visages placés à leur étape, réglages en pilules segmentées dans la page (pas de fenêtre de
## réglage). Un visage ouvre le parcours individuel (petite fenêtre commune de centre_visuel.gd). Aucune phrase d'aide.
## Coordonnées en unités du gabarit, relatives à la zone de l'onglet.
const V = preload("res://ui/immersive08/centre_visuel.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")

const ETAPE_1 := Charte.REPOS        ## 17 ans et moins
const ETAPE_2 := Charte.GAIN         ## 18-19 ans
const ETAPE_3 := Charte.INTENSIF     ## 20 ans et plus
const PREMIERE := Charte.CONFIANCE   ## équipe première
const COULEURS_REGIONS := [Charte.REPOS, Charte.GAIN, Charte.MORAL, Charte.CONFIANCE, Charte.INTENSIF, Charte.PERTE]

static func onglet(ctx: Dictionary, nom: String, zone: Rect2) -> void:
	var cadre := Control.new()
	cadre.name = "CentreVisuelB"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.racine.add_child(cadre)
	D.place(cadre, zone)
	match nom:
		"Parcours": _parcours(ctx, cadre, zone)
		"Centres": _centres(ctx, cadre, zone)
		"Filières": _filieres(ctx, cadre, zone)
		"Passerelle pro": _passerelle(ctx, cadre, zone)
		"Générations": _generations(ctx, cadre, zone)
		_: _centre(ctx, cadre, zone)

# --- Pièces du chemin -----------------------------------------------------------------------------------------------

## Flèche d'une étape à la suivante : trait et pointe, de la couleur de l'étape d'arrivée.
static func _fleche(parent: Control, x1: float, x2: float, y: float, couleur: Color) -> void:
	D.line(parent, Vector2(x1, y - 2), Vector2(x2 - 14, y + 2), Color(couleur, .8), 4)
	V.icone(parent, Rect2(x2 - 24, y - 14, 28, 28), "arrow", couleur)

## En-tête d'étape : pictogramme, nom en titre, compteur à droite.
static func _entete(parent: Control, largeur: float, titre: String, icone_id: String, couleur: Color, compte: String = "") -> void:
	V.icone(parent, Rect2(20, 20, 32, 32), icone_id, couleur)
	var t := V.chiffre(parent, 64, 48, titre.to_upper(), 30, Charte.IVOIRE, largeur - 180)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	if not compte.is_empty(): V.chiffre(parent, largeur - 20, 52, compte, 44, couleur, 160, HORIZONTAL_ALIGNMENT_RIGHT)
	D.rect(parent, Rect2(20, 66, largeur - 40, 4), Color(couleur, .7), Charte.RAYON_PILULE)

## Pilules segmentées d'un réglage : nom à gauche, choix côte à côte, le courant en aplat de sa couleur.
static func _segments(ctx: Dictionary, parent: Control, x: float, y: float, largeur: float, titre: String, options: Array, courant: String, commande: String, cle: String, id: String) -> void:
	V.petit(parent, x, y + 40, titre.to_upper(), 20, Charte.IVOIRE_2, 250)
	var x0 := x + 260.0
	var w := (largeur - 260.0) / options.size()
	D.rect(parent, Rect2(x0, y + 6, largeur - 260.0, 58), Charte.PANNEAU_3, Charte.RAYON_PILULE)
	var verrou: bool = ctx.data.get("locked", false)
	for i in options.size():
		var o: Array = options[i]
		var choisi := str(o[0]) == courant
		var zone := Rect2(x0 + i * w + 4, y + 10, w - 8, 50)
		var pilule := D.rect(parent, zone, o[3] if choisi else Color.TRANSPARENT, Charte.RAYON_PILULE)
		pilule.name = "%s_%s" % [id, str(o[0]).validate_node_name()]
		var encre: Color = Charte.PANNEAU if choisi else o[3]
		V.icone(pilule, Rect2(18, 13, 24, 24), str(o[2]), encre)
		V.petit(pilule, 50, 33, str(o[1]), 21, Charte.PANNEAU if choisi else Charte.IVOIRE, zone.size.x - 60)
		if not choisi and not verrou:
			var valeur: String = str(o[0])
			Pieces.rendre_cliquable(pilule, zone.size, func(): V.envoyer(ctx, commande, {cle: valeur}), pilule.name + "Lien", str(o[1]), "", Charte.RAYON_PILULE)

## Jeton-visage d'un Espoir : portrait rond dans l'anneau de ses minutes, point de trajectoire, potentiel en chiffre.
static func _jeton(ctx: Dictionary, parent: Control, cellule: Rect2, p: Dictionary, id_bouton: String, action: Callable, cote: float = 66.0, anneau: bool = true, source: String = "academy", sous: String = "potentiel") -> Button:
	var bouton := V.cliquable(parent, cellule, action, id_bouton, str(p.get("name", "")), Charte.RAYON_CARTE)
	var porteur := bouton.get_parent() as Control
	if not source.is_empty() and not str(p.get("id", "")).is_empty(): CarteSurvol.lier(ctx.app, porteur, str(p.id), source)
	var cx := cellule.size.x / 2.0
	var bord := 6.0
	var zone_visage := Rect2(cx - cote / 2.0, bord + 4, cote, cote)
	if anneau:
		var cible := float(p.get("target", 0))
		var part := float(p.get("minutes", 0)) / (cible if cible > 0 else 480.0)
		var rond := Control.new()
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		porteur.add_child(rond)
		D.place(rond, Rect2(zone_visage.position - Vector2(bord, bord), zone_visage.size + Vector2(bord, bord) * 2))
		rond.draw.connect(func():
			var r := rond.size.x / 2.0 - maxf(2.0, C.px(3))
			var e := maxf(3.0, float(C.px(5)))
			rond.draw_arc(rond.size / 2.0, r, 0, TAU, 48, Charte.PANNEAU_3, e, true)
			if part > 0.0: rond.draw_arc(rond.size / 2.0, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(part, 0.0, 1.0), 48, V.MINUTES, e, true))
	V.portrait(ctx, porteur, zone_visage, p, Color.TRANSPARENT, 0, "")
	if p.has("path"):
		var t := V.trajectoire(str(p.path))
		var point := D.rect(porteur, Rect2(zone_visage.end.x - 16, zone_visage.end.y - 18, 22, 22), t[3], 999, Charte.PANNEAU)
		(point.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	var y := zone_visage.end.y + bord + 28
	if sous == "potentiel" and V.valeur(p, "potential") < 0.0:
		V.chiffre(porteur, cx, y, "%s ans" % G.n(p.get("age", 0)), 22, Charte.IVOIRE_2, cellule.size.x - 6, HORIZONTAL_ALIGNMENT_CENTER)
	elif sous == "potentiel":
		V.chiffre(porteur, cx, y, V.potentiel_txt(p), 26, V.couleur(V.valeur(p, "potential")), cellule.size.x - 6, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		V.chiffre(porteur, cx, y, V.niveau_txt(p), 26, V.couleur(V.valeur(p, "rating")), cellule.size.x - 6, HORIZONTAL_ALIGNMENT_CENTER)
	var morceaux := str(p.get("name", "")).split(" ")
	V.petit(porteur, cx, y + 20, morceaux[morceaux.size() - 1], 15, Charte.IVOIRE_2, cellule.size.x - 6, HORIZONTAL_ALIGNMENT_CENTER)
	return bouton

static func _par_potentiel(a: Dictionary, b: Dictionary) -> bool:
	return V.valeur(a, "potential") > V.valeur(b, "potential")

static func _aller_onglet(ctx: Dictionary, nom: String) -> Callable:
	return func():
		ctx.state.tab = nom
		ctx.state.erase("fenetre")
		(ctx.reconstruire as Callable).call()

# --- Centre : détection → centre → rencontres juniors → équipe première ---------------------------------------------

static func _centre(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var largeurs := [400.0, 640.0, 640.0, 400.0]
	var ecart := (zone.size.x - 2080.0) / 3.0
	var h := 580.0
	var x := 0.0
	var noeuds: Array[Rect2] = []
	for w: float in largeurs:
		noeuds.append(Rect2(x, 0, w, h))
		x += w + ecart
	_noeud_detection(ctx, cadre, noeuds[0])
	_noeud_centre(ctx, cadre, noeuds[1])
	_noeud_rencontres(ctx, cadre, noeuds[2])
	_noeud_premiere(ctx, cadre, noeuds[3])
	var couleurs := [V.MINUTES, V.PROGRES, PREMIERE]
	for i in 3:
		_fleche(cadre, noeuds[i].end.x + 4, noeuds[i + 1].position.x - 2, h / 2.0, couleurs[i])
	# Réglages en pilules segmentées, sous le chemin.
	var y := h + 26.0
	var lw := zone.size.x - 520.0
	_segments(ctx, cadre, 0, y, lw, "Plan des rencontres", [["equilibre", "Équilibré", "target", Charte.MORAL], ["performance", "Performance", "trophy", Charte.INTENSIF], ["developpement", "Développement", "rating", Charte.CONFIANCE], ["repos", "Repos", "heart", Charte.REPOS]], str(data.get("mode", "")), "academy_mode", "mode", "CVBMode")
	_segments(ctx, cadre, 0, y + 92, lw, "Objectif annuel", [["formation", "2 objectifs", "target", Charte.GAIN], ["promotions", "2 promotions", "trophy", Charte.INTENSIF], ["prets", "1 prêt · 200 min", "bus", Charte.MORAL]], str(data.get("goal", "")), "academy_goal", "goal", "CVBObjectif")
	_segments(ctx, cadre, 0, y + 184, lw, "Identité", [["polyvalence", "Polyvalence", "renew", Charte.MORAL], ["mouvement", "Mouvement", "arrow", Charte.REPOS], ["puissance", "Puissance", "shield", Charte.PERTE], ["defense", "Défense", "lock", Charte.CONFIANCE]], str(data.get("identity", "")), "academy_identity", "identity", "CVBIdentite")
	# Réunion de cohésion : tuile chiffrée.
	var cout := int(data.get("costs", {}).get("meeting", 2000))
	var tuile := V.carte(cadre, Rect2(zone.size.x - 480, y + 6, 480, 248), V.COHESION, "CVBReunion")
	V.icone(tuile, Rect2(24, 24, 40, 40), "people", V.COHESION)
	V.chiffre(tuile, 80, 60, "RÉUNION DE COHÉSION", 28, Charte.IVOIRE, 380)
	V.chiffre(tuile, 24, 172, G.euros(cout), 64, V.DEPENSE, 300)
	V.chiffre(tuile, 456, 172, "+", 64, V.COHESION, 80, HORIZONTAL_ALIGNMENT_RIGHT)
	V.petit(tuile, 24, 220, "COHÉSION %s" % G.n(data.get("cohesion", 0)), 18, V.COHESION, 400)
	if not data.get("locked", false):
		Pieces.rendre_cliquable(tuile, Vector2(480, 248), func(): V.envoyer(ctx, "academy_meeting", {}, cout, "Réunion de cohésion"), "CVBReunionLien", "Réunion de cohésion", "", Charte.RAYON_CARTE)

static func _noeud_detection(ctx: Dictionary, parent: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var n := V.carte(parent, zone, V.DEPENSE, "CVBDetection")
	_entete(n, zone.size.x, "Détection", "search", V.DEPENSE)
	var faite: bool = data.get("nextScouted", false)
	var cout := Academy.cost(data, "scout", 35000)
	# Tuile de la campagne : coût en grand, cochée une fois lancée.
	var tuile := V.carte(n, Rect2(20, 92, zone.size.x - 40, 170), V.PROGRES if faite else V.DEPENSE, "CVBDetectionCampagne")
	V.chiffre(tuile, 20, 82, G.euros(cout), 54, V.PROGRES if faite else V.DEPENSE, zone.size.x - 120)
	Pieces.pastille(tuile, 20, 112, "Faite" if faite else "Lancer", "check" if faite else "search", "CVBDetectionEtat", "", V.PROGRES if faite else V.DEPENSE)
	if not faite and not data.get("locked", false):
		Pieces.rendre_cliquable(tuile, Vector2(zone.size.x - 40, 170), func(): V.envoyer(ctx, "academy_scout", {}, cout, "Détection annuelle"), "CVBDetectionLien", "Détection annuelle", "", Charte.RAYON_CARTE)
	# Enveloppe junior et centres observés.
	V.chiffre(n, 24, 340, G.euros(data.get("recruitBudget", 0)), 46, V.PROGRES, zone.size.x - 48)
	V.petit(n, 24, 372, "ENVELOPPE JUNIOR", 18, Charte.IVOIRE_2, zone.size.x - 48)
	var observes: int = data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size()
	var bloc := V.carte(n, Rect2(20, 400, zone.size.x - 40, 120), Color.TRANSPARENT, "CVBCentresObserves")
	V.chiffre(bloc, 20, 72, G.n(observes), 54, V.COHESION, 120)
	V.petit(bloc, 130, 58, "CENTRES", 20, Charte.IVOIRE, 200)
	V.petit(bloc, 130, 84, "OBSERVÉS", 20, Charte.IVOIRE_2, 200)
	V.icone(bloc, Rect2(zone.size.x - 90, 40, 36, 36), "arrow", Charte.IVOIRE_2)
	Pieces.rendre_cliquable(bloc, Vector2(zone.size.x - 40, 120), _aller_onglet(ctx, "Centres"), "CVBCentresObservesLien", "Centres observés", "", Charte.RAYON_CARTE)

static func _noeud_centre(ctx: Dictionary, parent: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var n := V.carte(parent, zone, V.MINUTES, "CVBLeCentre")
	_entete(n, zone.size.x, "Le centre", "school", V.MINUTES)
	# Espoirs en grand → onglet Parcours.
	var espoirs := V.carte(n, Rect2(20, 92, 200, 196), Color.TRANSPARENT, "CVBEspoirs")
	V.chiffre(espoirs, 100, 120, G.n(data.get("players", []).size()), 84, Charte.IVOIRE, 190, HORIZONTAL_ALIGNMENT_CENTER)
	V.petit(espoirs, 100, 166, "ESPOIRS", 20, Charte.IVOIRE_2, 190, HORIZONTAL_ALIGNMENT_CENTER)
	Pieces.rendre_cliquable(espoirs, Vector2(200, 196), _aller_onglet(ctx, "Parcours"), "CVBEspoirsLien", "Espoirs", "", Charte.RAYON_CARTE)
	# Cohésion et réputation en anneaux.
	var anneaux := [["cohesion", "Cohésion", V.COHESION, "heart", "CVBCohesion"], ["reputation", "Réputation", V.REPUTATION, "star", "CVBReputation"]]
	for i in anneaux.size():
		var a: Array = anneaux[i]
		var jauge := JaugeAnneau.new(float(data.get(a[0], 0)), str(a[1]), a[2], 100.0, str(a[3]))
		jauge.name = str(a[4])
		jauge.diametre = 120.0
		n.add_child(jauge)
		var rect := Rect2(236 + i * 196, 96, 180, 176)
		D.place(jauge, rect)
		var action := (func(): V.envoyer(ctx, "academy_meeting", {}, int(data.get("costs", {}).get("meeting", 2000)), "Réunion de cohésion")) if i == 0 else _aller_onglet(ctx, "Générations")
		V.cliquable(n, rect, action, str(a[4]) + "Lien", str(a[1]), Charte.RAYON_CARTE)
	# Installations et éducateurs : crans + coût du niveau suivant.
	var niveaux := [["facilities", "Installations", 85000, "home"], ["coaches", "Éducateurs", 55000, "people"]]
	for i in niveaux.size():
		var nv: Array = niveaux[i]
		var niveau := int(data.get(nv[0], 0))
		var y := 306.0 + i * 112.0
		var ligne := V.carte(n, Rect2(20, y, zone.size.x - 40, 100), Color.TRANSPARENT, "CVBNiveau_" + str(nv[0]))
		V.icone(ligne, Rect2(18, 18, 30, 30), str(nv[3]), V.PROGRES)
		V.petit(ligne, 58, 42, str(nv[1]).to_upper(), 20, Charte.IVOIRE, 220)
		V.chiffre(ligne, 58, 86, "%d/3" % niveau, 34, V.PROGRES, 90)
		V.crans(ligne, 150, 68, niveau, 3, V.PROGRES, 46, 14)
		if niveau < 3:
			var cout := Academy.cost(data, str(nv[0]), (niveau + 1) * int(nv[2]), niveau)
			var tuile := V.carte(ligne, Rect2(zone.size.x - 300, 12, 248, 76), V.DEPENSE, "CVBMonter_" + str(nv[0]))
			V.icone(tuile, Rect2(14, 24, 28, 28), "arrow", V.DEPENSE)
			V.chiffre(tuile, 50, 50, G.euros(cout), 32, V.DEPENSE, 190)
			if not data.get("locked", false):
				var cle: String = nv[0]
				Pieces.rendre_cliquable(tuile, Vector2(248, 76), func(): V.envoyer(ctx, "academy_upgrade", {"kind": cle}, cout, "%s niveau %d" % [nv[1], niveau + 1]), tuile.name + "Lien", str(nv[1]), "", Charte.RAYON_CARTE)
		else:
			Pieces.pastille(ligne, zone.size.x - 220, 32, "Maximum", "check", "CVBMax_" + str(nv[0]), "", V.PROGRES)

static func _noeud_rencontres(ctx: Dictionary, parent: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var n := V.carte(parent, zone, V.PROGRES, "CVBRencontres")
	var periode := int(data.get("juniorRound", 0))
	var total := maxi(1, int(data.get("totalRounds", 26)))
	_entete(n, zone.size.x, "Rencontres juniors", "trophy", V.PROGRES)
	V.chiffre(n, 24, 160, "%d" % periode, 84, Charte.IVOIRE, 140)
	V.chiffre(n, 24 + C.EXTRA_BOLD.get_string_size(str(periode), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(84))).x / C.density + 10, 160, "/ %d" % total, 40, Charte.IVOIRE_2, 140)
	V.petit(n, 24, 192, "PÉRIODES", 18, Charte.IVOIRE_2, 200)
	# Frise des périodes : jouée, en cours, à venir ; un résultat colore sa case.
	var resultats := {}
	for r: Dictionary in data.get("results", []): resultats[int(r.get("round", -1))] = r
	var club := int(data.get("clubId", -1))
	var x0 := 24.0
	var w := (zone.size.x - 48.0) / total
	for i in total:
		var couleur := Charte.PANNEAU_3
		if resultats.has(i): couleur = _couleur_resultat(resultats[i], club)
		elif i < periode: couleur = Color(V.MINUTES, .55)
		var case_h := 44.0 if i == periode else 30.0
		D.rect(n, Rect2(x0 + i * w + 2, 236 - case_h / 2.0, w - 4, case_h), couleur, 4, Charte.IVOIRE if i == periode else Color.TRANSPARENT)
	# Derniers résultats en cases : lettre, score, adversaire.
	var derniers: Array = data.get("results", []).slice(-4)
	derniers.reverse()
	var cw := (zone.size.x - 48.0 - 3 * 12.0) / 4.0
	for i in derniers.size():
		var r: Dictionary = derniers[i]
		var c := _couleur_resultat(r, club)
		var nous := int(r.get("home", -1)) == club
		var pour := int(r.score[0]) if nous else int(r.score[1])
		var contre := int(r.score[1]) if nous else int(r.score[0])
		var lettre := "V" if pour > contre else ("D" if pour < contre else "N")
		var case_r := V.carte(n, Rect2(24 + i * (cw + 12), 284, cw, 170), c, "CVBResultat%d" % i)
		V.chiffre(case_r, 16, 58, lettre, 46, c, 60)
		V.petit(case_r, cw - 14, 50, "P%d" % (int(r.get("round", 0)) + 1), 17, Charte.IVOIRE_3, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		V.chiffre(case_r, 16, 116, "%d – %d" % [pour, contre], 38, Charte.IVOIRE, cw - 24)
		var adv := str(r.get("awayCenter", "")) if nous else str(r.get("homeCenter", ""))
		V.petit(case_r, 16, 150, adv.split(" (")[0], 15, Charte.IVOIRE_2, cw - 24)
	var mode := str(data.get("mode", ""))
	var libelles := {"equilibre": ["Équilibré", "target", Charte.MORAL], "performance": ["Performance", "trophy", Charte.INTENSIF], "developpement": ["Développement", "rating", Charte.CONFIANCE], "repos": ["Repos", "heart", Charte.REPOS]}
	if libelles.has(mode):
		var l: Array = libelles[mode]
		Pieces.pastille(n, 24, 476, str(l[0]), str(l[1]), "CVBModeCourant", "", l[2])
	Pieces.rendre_cliquable(n, zone.size, func(): load("res://ui/immersive08/centre_juniors.gd").ouvrir(ctx.app, ctx.page), "CVBRencontresLien", "Rencontres juniors", "", Charte.RAYON_CARTE)

static func _couleur_resultat(r: Dictionary, club: int) -> Color:
	var nous := int(r.get("home", -1)) == club
	var s: Array = r.get("score", [0, 0])
	var pour := int(s[0]) if nous else int(s[1])
	var contre := int(s[1]) if nous else int(s[0])
	return Charte.GAIN if pour > contre else (Charte.PERTE if pour < contre else Charte.IVOIRE_2)

static func _noeud_premiere(ctx: Dictionary, parent: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var n := V.carte(parent, zone, PREMIERE, "CVBPremiere")
	_entete(n, zone.size.x, "Équipe première", "shield", PREMIERE)
	var places := int(data.get("places", 0))
	V.chiffre(n, 24, 170, G.n(places), 96, PREMIERE, 200)
	V.petit(n, 24, 204, "PLACES PRO LIBRES", 18, Charte.IVOIRE_2, 340)
	# Sièges de l'effectif professionnel : occupés pleins, libres en creux.
	var capacite := int(data.get("capacity", 0))
	var occupes := int(data.get("occupied", 0))
	var par_ligne := 7
	while ceili(capacite / float(par_ligne)) * ((zone.size.x - 48.0 - (par_ligne - 1) * 8.0) / par_ligne + 8.0) > 250.0 and par_ligne < 14: par_ligne += 1
	var cote := minf((zone.size.x - 48.0 - (par_ligne - 1) * 8.0) / par_ligne, 40.0)
	for i in capacite:
		var libre := i >= occupes
		var s := D.rect(n, Rect2(24 + (i % par_ligne) * (cote + 8), 236 + floori(i / float(par_ligne)) * (cote + 8), cote, cote), Color.TRANSPARENT if libre else Color(Charte.IVOIRE, .35), 8, PREMIERE if libre else Color.TRANSPARENT)
		if libre: (s.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	var promus: int = data.get("promotions", []).size()
	V.chiffre(n, 24, 556, G.n(promus), 40, V.DEPENSE, 70)
	V.petit(n, 90, 548, "PROMUS", 18, Charte.IVOIRE_2, 200)
	Pieces.rendre_cliquable(n, zone.size, func(): ctx.app._navigate("Effectif"), "CVBPremiereLien", "Équipe première", "", Charte.RAYON_CARTE)

# --- Parcours : les Espoirs placés par étape d'âge, jusqu'à l'équipe première --------------------------------------

static func _parcours(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var tous: Array = data.get("players", [])
	var filtre := str(ctx.state.get("filtre_b", ""))
	# Pilules filtre par trajectoire, avec compteurs.
	var x := 0.0
	var filtres: Array = [["", "Tous", "people", Charte.IVOIRE]]
	for t: Array in V.TRAJECTOIRES: filtres.append(t)
	for f: Array in filtres:
		var n := tous.size() if str(f[0]).is_empty() else tous.filter(func(p: Dictionary): return str(p.path) == str(f[0])).size()
		var choisi := filtre == str(f[0])
		var texte := "%s  %d" % [f[1], n]
		var w := Pieces.largeur_pastille(texte, str(f[2])) + 16
		var fond: Color = Charte.PANNEAU_2.lerp(f[3], .45) if choisi else Charte.PANNEAU_3
		var valeur: String = str(f[0])
		Pieces.pastille(cadre, x, 4, texte, str(f[2]), "CVBFiltre_" + (valeur if not valeur.is_empty() else "tous"), "", f[3], fond, func():
			ctx.state.filtre_b = valeur
			(ctx.reconstruire as Callable).call())
		x += w + 10
	var joueurs: Array = tous.filter(func(p: Dictionary): return filtre.is_empty() or str(p.path) == filtre)
	var etapes := [["17 ans et moins", ETAPE_1, func(p: Dictionary): return int(p.age) <= 17],
		["18-19 ans", ETAPE_2, func(p: Dictionary): return int(p.age) >= 18 and int(p.age) <= 19],
		["20 ans et plus", ETAPE_3, func(p: Dictionary): return int(p.age) >= 20]]
	var ecart := 30.0
	var w_premiere := 330.0
	var w_col := (zone.size.x - w_premiere - ecart * 3) / 3.0
	var cellule := Vector2(112, 136)
	var par_ligne := floori((w_col - 20) / cellule.x)
	var colonnes: Array = []
	var lignes_max := 1
	for e: Array in etapes:
		var liste: Array = joueurs.filter(e[2])
		liste.sort_custom(func(a: Dictionary, b: Dictionary): return _par_potentiel(a, b))
		colonnes.append(liste)
		lignes_max = maxi(lignes_max, ceili(liste.size() / float(par_ligne)))
	var hauteur := 96.0 + lignes_max * cellule.y + 20
	var contenu := V.zone_defilante(ctx, Rect2(zone.position.x, zone.position.y + 54, zone.size.x, zone.size.y - 54), hauteur, "CVBParcoursDefile")
	var h_col := maxf(hauteur, (zone.size.y - 54) / 1.0) - 6
	var rang := 0
	for i in 3:
		var e: Array = etapes[i]
		var x0 := i * (w_col + ecart)
		var col := V.carte(contenu, Rect2(x0, 0, w_col, h_col), e[1], "CVBEtape%d" % i)
		_entete(col, w_col, str(e[0]), "people", e[1], G.n(colonnes[i].size()))
		var liste: Array = colonnes[i]
		var marge := (w_col - par_ligne * cellule.x) / 2.0
		for k in liste.size():
			var p: Dictionary = liste[k]
			var cel := Rect2(marge + (k % par_ligne) * cellule.x, 86 + floori(k / float(par_ligne)) * cellule.y, cellule.x, cellule.y)
			var pid := str(p.id)
			_jeton(ctx, col, cel, p, "CentreVisuelJoueur%d" % rang, func(): V.fenetre_parcours(ctx, pid))
			rang += 1
		if i < 3: _fleche(contenu, x0 + w_col + 2, x0 + w_col + ecart - 2, 40, [ETAPE_2, ETAPE_3, PREMIERE][i])
	# Équipe première : places professionnelles libres en sièges vides.
	var xp := 3 * (w_col + ecart)
	var premiere := V.carte(contenu, Rect2(xp, 0, w_premiere, h_col), PREMIERE, "CVBEtapePremiere")
	_entete(premiere, w_premiere, "Équipe 1re", "shield", PREMIERE, G.n(data.get("places", 0)))
	var places := int(data.get("places", 0))
	for i in places:
		var s := D.rect(premiere, Rect2(34 + (i % 3) * 92, 96 + floori(i / 3.0) * 92, 76, 76), Color.TRANSPARENT, 999, PREMIERE)
		(s.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
		V.icone(s, Rect2(24, 24, 28, 28), "people", Color(PREMIERE, .7))
	var promus: Array = data.get("promotions", [])
	var y_p := 96 + ceili(places / 3.0) * 92 + 20
	V.chiffre(premiere, 34, y_p + 44, G.n(promus.size()), 44, V.DEPENSE, 80)
	V.petit(premiere, 100, y_p + 36, "PROMUS", 18, Charte.IVOIRE_2, 200)
	Pieces.rendre_cliquable(premiere, Vector2(w_premiere, h_col), func(): ctx.app._navigate("Effectif"), "CVBEtapePremiereLien", "Équipe première", "", Charte.RAYON_CARTE)

# --- Centres : les centres des autres clubs en lignes à barres ------------------------------------------------------

static func _centres(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var monde: bool = data.get("world", false)
	var centres: Array = data.get("centers", []).filter(func(c: Dictionary): return not c.get("own", false) and (not monde or c.get("scouted", false) or int(c.count) > 15))
	centres.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.scouted != b.scouted: return a.scouted
		return int(a.count) > int(b.count))
	var cout := Academy.cost(data, "centerScout", 1200)
	var maximum := 1
	for c: Dictionary in centres: maximum = maxi(maximum, int(c.count))
	# Bandeau de chiffres.
	var observes := centres.filter(func(c: Dictionary): return c.scouted).size()
	var tuiles := [[G.n(observes), "Centres observés", V.COHESION, "search"], [G.n(centres.size()), "Centres", Charte.IVOIRE, "school"],
		[G.euros(data.get("recruitBudget", 0)), "Enveloppe junior", V.PROGRES, "money"], [G.euros(cout), "Observation", V.DEPENSE, "search"]]
	for i in tuiles.size():
		var t: Array = tuiles[i]
		Pieces.tuile(cadre, Rect2(i * 300.0, 0, 286, 96), str(t[0]), str(t[1]), t[2], "CVBCentresTuile%d" % i, 40, "", str(t[3]), true)
	# En-tête des colonnes.
	var xb := 440.0
	var wb := 500.0
	var xa := 1070.0
	var xc := 1250.0
	V.petit(cadre, 20, 132, "CENTRE", 16, Charte.IVOIRE_3, 300)
	V.petit(cadre, xb, 132, "JEUNES", 16, Charte.IVOIRE_3, 300)
	V.petit(cadre, xc, 132, "CANDIDATS · POTENTIEL", 16, Charte.IVOIRE_3, 600)
	var hauteurs: Array = []
	var total := 0.0
	for c: Dictionary in centres:
		var h := 124.0 if c.scouted and not c.get("candidates", []).is_empty() else 66.0
		hauteurs.append(h)
		total += h + 8
	var contenu := V.zone_defilante(ctx, Rect2(zone.position.x, zone.position.y + 146, zone.size.x, zone.size.y - 146), total, "CVBCentresDefile")
	var y := 0.0
	var verrou: bool = data.get("locked", false)
	for i in centres.size():
		var c: Dictionary = centres[i]
		var h: float = hauteurs[i]
		var ligne := D.rect(contenu, Rect2(0, y, zone.size.x - 22, h), Charte.PANNEAU_2.lerp(V.COHESION, .12) if c.scouted else Charte.PANNEAU_2, Charte.RAYON_CARTE)
		ligne.name = "CVBCentre_" + str(c.id).validate_node_name()
		var peut: bool = not c.scouted and int(c.count) > 15 and not verrou
		var cid := str(c.id)
		var action := (func(): V.envoyer(ctx, "academy_center_scout", {"centerId": cid}, cout, "Observer " + str(c.name))) if peut else (func(): pass)
		Pieces.rendre_cliquable(ligne, Vector2(zone.size.x - 22, h), action, ligne.name + "Lien", str(c.name), "", Charte.RAYON_CARTE)
		var milieu := h / 2.0
		V.chiffre(ligne, 20, milieu + 11, str(c.name), 24, Charte.IVOIRE, 420)
		V.jauge(ligne, Rect2(xb, milieu - 9, wb, 18), float(c.count) / maximum, V.COHESION if c.scouted else Color(V.COHESION, .55))
		V.chiffre(ligne, xb + wb + 20, milieu + 15, G.n(c.count), 38, V.COHESION, 90)
		if c.scouted: Pieces.pastille(ligne, xa, milieu - 17, "Observé", "check", ligne.name + "Etat", "", V.PROGRES)
		elif int(c.count) <= 15: Pieces.pastille(ligne, xa, milieu - 17, "Fermé", "lock", ligne.name + "Etat", "", Charte.IVOIRE_3)
		else: Pieces.pastille(ligne, xa, milieu - 17, G.euros(cout), "search", ligne.name + "Etat", "", V.DEPENSE)
		if c.scouted:
			var cands: Array = c.get("candidates", [])
			for k in mini(cands.size(), 6):
				var p: Dictionary = cands[k]
				var cel := Rect2(xc + k * 156.0, 0, 150, h)
				var pidc := str(p.id)
				var frais := int(p.get("fee", 0))
				var b := V.cliquable(ligne, cel, func(): V.envoyer(ctx, "academy_recruit", {"playerId": pidc, "offer": frais}, frais, "Proposer à " + str(p.name)), "CVBCandidat_" + pidc.validate_node_name(), str(p.name), Charte.RAYON_CARTE)
				var porteur := b.get_parent() as Control
				V.portrait(ctx, porteur, Rect2(8, 10, 52, 52), p, Color.TRANSPARENT, 0, "")
				V.chiffre(porteur, 66, 46, V.potentiel_txt(p), 26, V.couleur(V.valeur(p, "potential")), 82)
				V.petit(porteur, 8, 88, str(p.pos), 14, Charte.IVOIRE_2, 140)
				V.chiffre(porteur, 8, 112, G.euros(frais), 20, V.DEPENSE, 140)
		y += h + 8

# --- Filières : régions, clubs partenaires, puis l'entonnoir des prospects -----------------------------------------

static func _filieres(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var verrou: bool = data.get("locked", false)
	var regions: Array = data.get("regions", [])
	var prospects: Array = data.get("prospects", [])
	var cout_region := Academy.cost(data, "discover", 3000)
	var w := (zone.size.x - (regions.size() - 1) * 12.0) / maxi(1, regions.size())
	for i in regions.size():
		var r := str(regions[i])
		var couleur: Color = COULEURS_REGIONS[i % COULEURS_REGIONS.size()]
		var tuile := V.carte(cadre, Rect2(i * (w + 12), 0, w, 104), couleur, "CVBRegion%d" % i)
		V.icone(tuile, Rect2(16, 16, 26, 26), "globe", couleur)
		V.petit(tuile, 50, 38, r.to_upper(), 19, Charte.IVOIRE, w - 60)
		V.chiffre(tuile, 16, 90, G.n(prospects.filter(func(p: Dictionary): return str(p.get("region", "")) == r).size()), 42, couleur, 80)
		V.chiffre(tuile, w - 14, 88, G.euros(cout_region), 24, V.DEPENSE, w - 110, HORIZONTAL_ALIGNMENT_RIGHT)
		if not verrou: Pieces.rendre_cliquable(tuile, Vector2(w, 104), func(): V.envoyer(ctx, "academy_discover", {"region": r}, cout_region, "Détecter · " + r), tuile.name + "Lien", r, "", Charte.RAYON_CARTE)
	# Clubs partenaires en pilules.
	var partenaires: Array = data.get("partners", [])
	var cout_p := Academy.cost(data, "partner", 2000)
	var x := 0.0
	var y := 120.0
	for f: Dictionary in data.get("feeders", []):
		var lie := partenaires.has(f.id)
		var texte := str(f.name)
		var lw := Pieces.largeur_pastille(texte, "check")
		if x + lw > zone.size.x:
			x = 0.0
			y += 44.0
		var fid := str(f.id)
		var action := Callable() if lie or verrou else func(): V.envoyer(ctx, "academy_partner", {"feederId": fid}, cout_p, "Partenariat · " + texte)
		Pieces.pastille(cadre, x, y, texte, "check" if lie else "flag", "CVBPartenaire_" + fid.validate_node_name(), "", V.PROGRES if lie else Charte.IVOIRE_2, Charte.PANNEAU_3, action)
		x += lw + 10
	y += 56.0
	# Entonnoir : 0 observation → 1-2 → 3 → essai fait.
	var etapes := [["0 obs.", Charte.IVOIRE_2, func(p: Dictionary): return not p.trial and int(p.scouted) == 0],
		["1-2 obs.", V.COHESION, func(p: Dictionary): return not p.trial and int(p.scouted) in [1, 2]],
		["3 obs.", V.MINUTES, func(p: Dictionary): return not p.trial and int(p.scouted) >= 3],
		["Essai fait", V.PROGRES, func(p: Dictionary): return p.trial]]
	var ecart := 30.0
	var cellule := Vector2(110, 136)
	var colonnes: Array = []
	for e: Array in etapes:
		var l: Array = prospects.filter(e[2])
		l.sort_custom(func(a: Dictionary, b: Dictionary): return _par_potentiel(a, b))
		colonnes.append(l)
	# Largeur de chaque étape selon son nombre de prospects (au moins deux visages de front).
	var utile := zone.size.x - ecart * 3
	var poids: Array[float] = []
	var somme := 0.0
	for l: Array in colonnes:
		poids.append(maxf(4.0, float(l.size())))
		somme += poids[poids.size() - 1]
	var largeurs: Array[float] = []
	for k in 4: largeurs.append(maxf(3 * cellule.x + 40, utile * minf(.55, poids[k] / somme)))
	var reste := utile - (largeurs[0] + largeurs[1] + largeurs[2] + largeurs[3])
	largeurs[0] += reste
	var lignes := 1
	for k in 4: lignes = maxi(lignes, ceili(colonnes[k].size() / float(maxi(1, floori((largeurs[k] - 16) / cellule.x)))))
	var hauteur := 90.0 + lignes * cellule.y + 16
	var contenu := V.zone_defilante(ctx, Rect2(zone.position.x, zone.position.y + y, zone.size.x, zone.size.y - y), hauteur, "CVBFilieresDefile")
	var h_col := maxf(hauteur, zone.size.y - y) - 6
	var x0 := 0.0
	for i in etapes.size():
		var e: Array = etapes[i]
		var w_col: float = largeurs[i]
		var par_ligne := maxi(1, floori((w_col - 16) / cellule.x))
		var col := V.carte(contenu, Rect2(x0, 0, w_col, h_col), e[1], "CVBEntonnoir%d" % i)
		_entete(col, w_col, str(e[0]), "search" if i < 3 else "check", e[1], G.n(colonnes[i].size()))
		var marge := (w_col - par_ligne * cellule.x) / 2.0
		var liste: Array = colonnes[i]
		for k in liste.size():
			var p: Dictionary = liste[k]
			var cel := Rect2(marge + (k % par_ligne) * cellule.x, 84 + floori(k / float(par_ligne)) * cellule.y, cellule.x, cellule.y)
			var pid := str(p.id)
			_jeton(ctx, col, cel, p, "CVBProspect_" + pid.validate_node_name(), func(): _fenetre_prospect(ctx, pid), 62.0, false, "")
		if i < 3: _fleche(contenu, x0 + w_col + 2, x0 + w_col + ecart - 2, 40, etapes[i + 1][1])
		x0 += w_col + ecart

static func _fenetre_prospect(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var p := {}
	for q: Dictionary in data.get("prospects", []):
		if str(q.id) == id: p = q
	if p.is_empty(): return
	var maison := str(data.get("homeUnion", "FR"))
	var options: Array = [
		["watch", "Observer %d/3" % int(p.scouted), "search", V.COHESION, G.euros(500), int(p.scouted) < 3],
		["trial", "Essai", "target", V.PROGRES, G.euros(1000), not p.trial and int(p.scouted) > 0],
	]
	if str(p.get("union", "")) != maison:
		options.append(["clearance", "Autorisation", "shield", V.REPUTATION, str(p.get("union", "")), int(p.age) >= 18 and p.trial and not p.get("clearanceRecorded", false)])
	options.append(["recruit", "Proposer", "trophy", V.DEPENSE, G.euros(8000), int(p.scouted) >= 2 and p.trial and int(p.age) >= 16])
	var nom := str(p.name)
	V.fenetre_choix(ctx, "CVBProspectFenetre", nom, "search", options, null, func(v: Variant): _action_prospect(ctx, id, nom, str(v)))

static func _action_prospect(ctx: Dictionary, id: String, nom: String, action: String) -> void:
	match action:
		"watch": V.envoyer(ctx, "academy_watch", {"playerId": id}, 500, "Observer " + nom)
		"trial": V.envoyer(ctx, "academy_trial", {"playerId": id}, 1000, "Essai · " + nom)
		"clearance": V.envoyer(ctx, "academy_clearance", {"playerId": id})
		"recruit": V.envoyer(ctx, "academy_feeder_recruit", {"playerId": id}, 8000, "Proposer le projet · " + nom)

# --- Passerelle pro : jeunes pros → en prêt → retour ----------------------------------------------------------------

static func _passerelle(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var jeunes: Array = data.get("seniors", []).filter(func(s: Dictionary): return int(s.age) <= 23 or s.get("loanEligible", false))
	jeunes.sort_custom(func(a: Dictionary, b: Dictionary):
		if bool(a.get("loanEligible", false)) != bool(b.get("loanEligible", false)): return a.get("loanEligible", false)
		return V.valeur(a, "rating") > V.valeur(b, "rating"))
	var prets: Array = data.get("loans", [])
	var ecart := 34.0
	var largeurs := [1060.0, 0.0, 0.0]
	largeurs[1] = (zone.size.x - largeurs[0] - ecart * 2) * .55
	largeurs[2] = zone.size.x - largeurs[0] - largeurs[1] - ecart * 2
	var couleurs := [V.PROGRES, V.COHESION, V.REPUTATION]
	var titres := [["Jeunes pros", "people"], ["En prêt", "bus"], ["Retour", "home"]]
	var eligibles := jeunes.filter(func(s: Dictionary): return s.get("loanEligible", false)).size()
	var comptes := ["%d/%d" % [eligibles, jeunes.size()], G.n(prets.size()), G.n(prets.size())]
	var x := 0.0
	var cols: Array[Panel] = []
	for i in 3:
		var col := V.carte(cadre, Rect2(x, 0, largeurs[i], zone.size.y), couleurs[i], "CVBPasserelle%d" % i)
		_entete(col, largeurs[i], str(titres[i][0]), str(titres[i][1]), couleurs[i], comptes[i])
		cols.append(col)
		if i < 2: _fleche(cadre, x + largeurs[i] + 2, x + largeurs[i] + ecart - 2, zone.size.y / 2.0, couleurs[i + 1])
		x += largeurs[i] + ecart
	# Jeunes pros : éligibles en clair, les autres grisés avec cadenas.
	var cellule := Vector2(170, 190)
	var par_ligne := floori((largeurs[0] - 20) / cellule.x)
	var marge: float = (largeurs[0] - par_ligne * cellule.x) / 2.0
	var verrou: bool = data.get("locked", false) or ctx.app.waiting
	for k in jeunes.size():
		var s: Dictionary = jeunes[k]
		var cel := Rect2(marge + (k % par_ligne) * cellule.x, 90 + floori(k / float(par_ligne)) * cellule.y, cellule.x, cellule.y)
		var ok: bool = s.get("loanEligible", false) and not verrou
		var sid := str(s.id)
		var b := _jeton(ctx, cols[0], cel, s, "CVBJeunePro_" + sid.validate_node_name(), (func(): _fenetre_pret(ctx, sid)) if ok else (func(): pass), 104.0, false, "squad", "niveau")
		if not s.get("loanEligible", false):
			(b.get_parent() as Control).modulate = Color(1, 1, 1, .5)
			V.icone(b.get_parent(), Rect2(cellule.x - 34, 8, 24, 24), "lock", Charte.IVOIRE_2)
	# En prêt et retour : visages des prêtés, club d'accueil.
	for i in prets.size():
		var l: Dictionary = prets[i]
		var hote := "club %d" % int(l.get("to", -1))
		for c: Dictionary in data.get("loanClubs", []):
			if int(c.id) == int(l.get("to", -1)): hote = str(c.name)
		var y := 96.0 + i * 96.0
		var visage := {"id": str(l.get("id", l.get("playerId", ""))), "name": str(l.get("name", ""))}
		for s: Dictionary in data.get("seniors", []):
			if str(s.id) == visage.id: visage = s
		V.portrait(ctx, cols[1], Rect2(24, y, 72, 72), visage, V.COHESION, 3, "squad")
		V.chiffre(cols[1], 110, y + 32, str(l.get("name", "")), 24, Charte.IVOIRE, largeurs[1] - 130)
		V.petit(cols[1], 110, y + 62, hote, 18, V.COHESION, largeurs[1] - 130)
		V.portrait(ctx, cols[2], Rect2(24, y, 72, 72), visage, V.REPUTATION, 3, "squad")
		V.icone(cols[2], Rect2(110, y + 22, 28, 28), "calendar", V.REPUTATION)
	if prets.is_empty():
		for i in [1, 2]:
			V.chiffre(cols[i], largeurs[i] / 2.0, zone.size.y / 2.0 + 40, "0", 120, Color(couleurs[i], .5), largeurs[i] - 40, HORIZONTAL_ALIGNMENT_CENTER)

static func _fenetre_pret(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var s := {}
	for q: Dictionary in data.get("seniors", []):
		if str(q.id) == id: s = q
	if s.is_empty(): return
	var L := 1600.0
	var H := 960.0
	var fond := Fenetre.ouvrir(ctx.page, "CVBPretFenetre", str(s.name).to_upper(), "bus", L, H)
	V.portrait(ctx, fond, Rect2(30, 80, 96, 96), s, V.COHESION, 3, "squad")
	V.chiffre(fond, 146, 130, V.niveau_txt(s), 48, V.couleur(V.valeur(s, "rating")), 120)
	V.petit(fond, 146, 164, "%s · %s ans" % [s.pos, G.n(s.age)], 20, Charte.IVOIRE_2, 600)
	var defile := ScrollContainer.new()
	defile.name = "CVBPretClubs"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(defile)
	D.place(defile, Rect2(30, 200, L - 60, H - 230))
	var clubs: Array = data.get("loanClubs", []).duplicate()
	clubs.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name) < str(b.name))
	var par_ligne := 4
	var w := (L - 60 - 20 - (par_ligne - 1) * 12.0) / par_ligne
	var contenu := Control.new()
	contenu.custom_minimum_size = Vector2(L - 80, ceili(clubs.size() / float(par_ligne)) * 72.0) * C.density
	defile.add_child(contenu)
	for k in clubs.size():
		var c: Dictionary = clubs[k]
		var cid := int(c.id)
		var tuile := V.carte(contenu, Rect2((k % par_ligne) * (w + 12), floori(k / float(par_ligne)) * 72.0, w, 62), V.COHESION, "CVBPretClub_%d" % cid)
		V.icone(tuile, Rect2(14, 18, 26, 26), "shield", V.COHESION)
		V.petit(tuile, 50, 39, str(c.name), 20, Charte.IVOIRE, w - 60)
		Pieces.rendre_cliquable(tuile, Vector2(w, 62), func(): V.envoyer(ctx, "academy_loan", {"playerId": id, "to": cid}, 0, "Prêt · %s → %s" % [s.name, c.name]), tuile.name + "Lien", str(c.name), "", Charte.RAYON_CARTE)

# --- Générations : frise des saisons --------------------------------------------------------------------------------

static func _generations(ctx: Dictionary, cadre: Control, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var saisons: Array = []
	for g: Dictionary in data.get("generations", []):
		saisons.append({"titre": G.season_label(g.season), "joueurs": g.get("players", []), "promus": int(g.get("graduates", 0)), "reputation": int(g.get("reputation", 0)), "archive": true, "season": g.season})
	# Génération en cours, au bout de la frise.
	saisons.append({"titre": "En cours", "joueurs": data.get("players", []), "promus": data.get("promotions", []).size(), "reputation": int(data.get("reputation", 0)), "archive": false, "season": data.get("context", {}).get("season", 0)})
	var maxi_joueurs := 1
	for s: Dictionary in saisons: maxi_joueurs = maxi(maxi_joueurs, s.joueurs.size())
	var ecart := 40.0
	var w := clampf((zone.size.x - (saisons.size() - 1) * ecart) / saisons.size(), 520.0, 1080.0)
	var total := saisons.size() * w + (saisons.size() - 1) * ecart
	# Frise horizontale qui défile si les saisons dépassent.
	var defile := ScrollContainer.new()
	defile.name = "CVBGenerationsDefile"
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cadre.add_child(defile)
	D.place(defile, Rect2(0, 0, zone.size.x, zone.size.y))
	var contenu := Control.new()
	contenu.custom_minimum_size = Vector2(maxf(total, zone.size.x - 4), zone.size.y - 24) * C.density
	defile.add_child(contenu)
	D.rect(contenu, Rect2(0, 54, maxf(total, zone.size.x - 4), 6), Color(V.REPUTATION, .5), Charte.RAYON_PILULE)
	for i in saisons.size():
		var s: Dictionary = saisons[i]
		var x := i * (w + ecart)
		var couleur := V.REPUTATION if s.archive else V.MINUTES
		D.rect(contenu, Rect2(x + w / 2.0 - 16, 41, 32, 32), couleur, 999, Charte.PANNEAU)
		var col := V.carte(contenu, Rect2(x, 96, w, zone.size.y - 130), couleur, "CVBGeneration%d" % i)
		var titre := V.chiffre(col, 24, 56, str(s.titre).to_upper(), 40, Charte.IVOIRE, w - 48)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		# Trois barres : joueurs suivis, promotions, réputation.
		var barres := [[s.joueurs.size(), maxi_joueurs, "Joueurs", V.MINUTES], [s.promus, maxi(5, s.promus), "Promus", V.DEPENSE], [s.reputation, 100, "Réputation", V.REPUTATION]]
		var bw := (w - 48 - 2 * 24) / 3.0
		var base := 440.0
		for k in 3:
			var b: Array = barres[k]
			var bx := 24 + k * (bw + 24)
			var hb := maxf(6.0, 280.0 * clampf(float(b[0]) / float(b[1]), 0.0, 1.0))
			D.rect(col, Rect2(bx, base - 280, bw, 280), Charte.PANNEAU_3, 10)
			D.rect(col, Rect2(bx, base - hb, bw, hb), b[3], 10)
			V.chiffre(col, bx + bw / 2.0, base - hb - 12, G.n(b[0]), 40, b[3], bw + 20, HORIZONTAL_ALIGNMENT_CENTER)
			V.petit(col, bx + bw / 2.0, base + 30, str(b[2]).to_upper(), 16, Charte.IVOIRE_2, bw + 20, HORIZONTAL_ALIGNMENT_CENTER)
		# Bande des meilleurs potentiels.
		var meilleurs: Array = s.joueurs.duplicate()
		meilleurs.sort_custom(func(a: Dictionary, b: Dictionary): return _par_potentiel(a, b))
		var cote := 92.0
		var nb := mini(floori((w - 48) / 118.0), meilleurs.size())
		for k in nb:
			var p: Dictionary = meilleurs[k]
			var px := 24 + k * ((w - 48 - cote) / maxf(1.0, nb - 1.0))
			V.portrait(ctx, col, Rect2(px, 530, cote, cote), p, V.couleur(V.valeur(p, "potential")), 3, "academy")
			V.chiffre(col, px + cote / 2.0, 664, V.potentiel_txt(p), 26, V.couleur(V.valeur(p, "potential")), cote + 30, HORIZONTAL_ALIGNMENT_CENTER)
			var morceaux := str(p.get("name", "")).split(" ")
			V.petit(col, px + cote / 2.0, 690, morceaux[morceaux.size() - 1], 15, Charte.IVOIRE_2, cote + 30, HORIZONTAL_ALIGNMENT_CENTER)
		V.cliquable(col, Rect2(0, 0, w, 500), func(): _fenetre_generation(ctx, s), "CVBGenerationLien%d" % i, str(s.titre), Charte.RAYON_CARTE)

static func _fenetre_generation(ctx: Dictionary, s: Dictionary) -> void:
	var joueurs: Array = s.joueurs.duplicate()
	joueurs.sort_custom(func(a: Dictionary, b: Dictionary): return _par_potentiel(a, b))
	var L := 1900.0
	var H := 1080.0
	var fond := Fenetre.ouvrir(ctx.page, "CVBGenerationFenetre", "GÉNÉRATION · " + str(s.titre).to_upper(), "trophy", L, H)
	var tuiles := [[G.n(joueurs.size()), "Joueurs", V.MINUTES], [G.n(s.promus), "Promus", V.DEPENSE], [G.n(s.reputation), "Réputation", V.REPUTATION]]
	for i in 3:
		Pieces.tuile(fond, Rect2(30 + i * 250.0, 76, 236, 92), str(tuiles[i][0]), str(tuiles[i][1]), tuiles[i][2], "CVBGenTuile%d" % i, 40, "", "", true)
	var defile := ScrollContainer.new()
	defile.name = "CVBGenerationVisages"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(defile)
	D.place(defile, Rect2(30, 190, L - 60, H - 220))
	var cellule := Vector2(150, 176)
	var par_ligne := floori((L - 80) / cellule.x)
	var contenu := Control.new()
	contenu.custom_minimum_size = Vector2(L - 80, ceili(joueurs.size() / float(par_ligne)) * cellule.y) * C.density
	defile.add_child(contenu)
	for k in joueurs.size():
		var p: Dictionary = joueurs[k]
		var x := (k % par_ligne) * cellule.x
		var y := floori(k / float(par_ligne)) * cellule.y
		var pc := V.couleur(V.valeur(p, "potential"))
		V.portrait(ctx, contenu, Rect2(x + 35, y + 6, 80, 80), p, pc, 3, "academy")
		V.chiffre(contenu, x + 75, y + 118, V.potentiel_txt(p), 24, pc, cellule.x - 8, HORIZONTAL_ALIGNMENT_CENTER)
		var morceaux := str(p.get("name", "")).split(" ")
		V.petit(contenu, x + 75, y + 140, morceaux[morceaux.size() - 1], 15, Charte.IVOIRE_2, cellule.x - 8, HORIZONTAL_ALIGNMENT_CENTER)
		V.chiffre(contenu, x + 75, y + 164, "%s min" % G.n(p.get("minutes", 0)), 16, V.MINUTES, cellule.x - 8, HORIZONTAL_ALIGNMENT_CENTER)
