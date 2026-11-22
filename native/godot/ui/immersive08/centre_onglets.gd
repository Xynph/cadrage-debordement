extends RefCounted
## Les six onglets du Centre de formation (parcours actifs), choix de Léo du 22/11/2026 : structure « chemin » pour
## Centre, Parcours, Passerelle pro et Générations, structure « cartes » pour Centres et Filières, habillage de
## l'Effectif (panneaux à gauche, listes à lignes à droite). Pièces communes : centre_visuel.gd (V).
const V = preload("res://ui/immersive08/centre_visuel.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Juniors = preload("res://ui/immersive08/centre_juniors.gd")

const GAUCHE := V.COLONNE
const X_LISTE := V.COLONNE + 24.0
const L_LISTE := V.LARGEUR - X_LISTE
const ECART := 16.0

static func onglet(ctx: Dictionary, nom: String, zone: Rect2) -> void:
	match nom:
		"Parcours": _parcours(ctx, zone)
		"Centres": _centres(ctx, zone)
		"Filières": _filieres(ctx, zone)
		"Passerelle pro": _passerelle(ctx, zone)
		"Générations": _generations(ctx, zone)
		_: _centre(ctx, zone)

static func _fleche_droite(parent: Control, x: float, y: float) -> void:
	V.icone(parent, Rect2(x, y - 14, 28, 28), "arrow", Charte.IVOIRE_2)

static func _fleche_bas(parent: Control, x: float, y: float) -> void:
	var f := V.icone(parent, Rect2(x - 13, y, 26, 26), "arrow", Charte.IVOIRE_2)
	f.pivot_offset = f.size / 2.0
	f.rotation = PI / 2.0

## Ligne de chiffre dans un panneau (comme les jauges du panneau Groupe de l'Effectif) : icône, intitulé, valeur
## colorée à droite ; toute la ligne mène à `action`.
static func _ligne_chiffre(parent: Control, zone: Rect2, icone_id: String, libelle: String, valeur: String, couleur: Color, action: Callable, id: String) -> void:
	V.icone(parent, Rect2(zone.position.x, zone.position.y + (zone.size.y - 24) / 2.0, 24, 24), icone_id, couleur)
	V.texte(parent, zone.position.x + 36, zone.position.y + zone.size.y / 2.0 + 7, libelle, 20, Charte.IVOIRE, zone.size.x - 200, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	V.chiffre(parent, zone.end.x - 8, zone.position.y + zone.size.y / 2.0 + 11, valeur, 30, couleur, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	if action.is_valid(): V.zone_cliquable(parent, Rect2(zone.position.x - 8, zone.position.y, zone.size.x + 8, zone.size.y), action, id, libelle)

## Jauge du panneau (Cohésion, Réputation) : icône, intitulé, rail coloré, chiffre.
static func _jauge(parent: Control, zone: Rect2, icone_id: String, libelle: String, v: float, couleur: Color, action: Callable, id: String) -> void:
	V.icone(parent, Rect2(zone.position.x, zone.position.y + 13, 24, 24), icone_id, couleur)
	V.texte(parent, zone.position.x + 34, zone.position.y + 33, libelle, 20, Charte.IVOIRE, 150, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	var rail := Rect2(zone.position.x + 170, zone.position.y + 20, zone.size.x - 170 - 70, 10)
	D.rect(parent, rail, Charte.PANNEAU_3, 5)
	D.rect(parent, Rect2(rail.position, Vector2(maxf(10.0, rail.size.x * clampf(v / 100.0, 0, 1)), 10)), couleur, 5)
	V.chiffre(parent, zone.end.x, zone.position.y + 38, G.n(v), 30, couleur, 64, HORIZONTAL_ALIGNMENT_RIGHT)
	if action.is_valid(): V.zone_cliquable(parent, Rect2(zone.position.x - 6, zone.position.y, zone.size.x + 12, 50), action, id, libelle)

# --- Centre : le chemin de la détection à l'équipe première ---------------------------------------------------------

const MODES := [["equilibre", "Équilibré", Charte.MORAL], ["performance", "Performance", Charte.INTENSIF], ["developpement", "Développement", Charte.CONFIANCE], ["repos", "Repos", Charte.REPOS]]
const OBJECTIFS := [["formation", "2 objectifs individuels", Charte.GAIN], ["promotions", "2 promotions pro", Charte.INTENSIF], ["prets", "1 prêt à 200 min", Charte.MORAL]]
const IDENTITES := [["polyvalence", "Polyvalence", Charte.MORAL], ["mouvement", "Mouvement", Charte.REPOS], ["puissance", "Puissance", Charte.PERTE], ["defense", "Défense", Charte.CONFIANCE]]

static func _centre(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var racine: Control = ctx.racine
	var verrou: bool = data.get("locked", false)
	var h_regl := 258.0
	var h := zone.size.y - h_regl - ECART
	var y := zone.position.y
	var fl := 40.0
	var w1 := 430.0
	var w2 := 560.0
	var w3 := 600.0
	var w4 := zone.size.x - w1 - w2 - w3 - 3 * fl
	var x := 0.0
	# 1. Détection
	var det := V.panneau(racine, Rect2(x, y, w1, h), "Détection", "search", "CentreDetection", V.aller(ctx, "Filières"))
	var scout := V.cout(ctx, "scout", 35000)
	var faite: bool = data.get("nextScouted", false)
	V.texte(det, 22, 112, "DÉTECTION ANNUELLE", 17, Charte.IVOIRE_3, 380, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	V.chiffre(det, 22, 176, V.euros(scout), 54, Charte.IVOIRE_3 if faite else V.DEPENSE, 380)
	if faite: R.pastille(det, 22, 232, "Faite", V.PROGRES, "check", "CentreDetectionFaite", 20)
	else: V.pilule(det, 22, 204, "Lancer", V.DEPENSE, true, func(): V.envoyer(ctx, "academy_scout", {}, scout, "Détection annuelle"), "CentreDetectionLancer", "", not verrou)
	D.line(det, Vector2(22, 278), Vector2(w1 - 22, 278))
	var observes: int = data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size()
	var lignes := [
		["search", "Centres observés", G.n(observes), V.MINUTES, V.aller(ctx, "Centres")],
		["people", "Jeunes repérés", G.n(data.get("prospects", []).size()), V.PROGRES, V.aller(ctx, "Filières")],
		["flag", "Clubs partenaires", G.n(data.get("partners", []).size()), V.COHESION, V.aller(ctx, "Filières")],
		["money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE, V.aller(ctx, "Centres")],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		_ligne_chiffre(det, Rect2(22, 296 + i * 62, w1 - 44, 56), l[0], l[1], l[2], l[3], l[4], "CentreDetectionLigne%d" % i)
	_fleche_droite(racine, x + w1 + 6, y + h / 2.0)
	x += w1 + fl
	# 2. Le centre
	var ctr := V.panneau(racine, Rect2(x, y, w2, h), "Le centre", "school", "CentreLeCentre", V.aller(ctx, "Parcours"), G.n(data.get("players", []).size()), V.PROGRES)
	_jauge(ctr, Rect2(22, 82, w2 - 44, 50), "heart", "Cohésion", float(data.get("cohesion", 0)), V.COHESION, Callable(), "")
	_jauge(ctr, Rect2(22, 142, w2 - 44, 50), "star", "Réputation", float(data.get("reputation", 0)), V.REPUTATION, V.aller(ctx, "Générations"), "CentreJaugeReputation")
	# Espoirs par étape, comme une rangée de compteurs.
	var joueurs: Array = data.get("players", [])
	var we := (w2 - 44 - 2 * 12) / 3.0
	for i in V.ETAPES.size():
		var e: Array = V.ETAPES[i]
		var n := joueurs.filter(func(p: Dictionary): return V.etape(p) == str(e[0])).size()
		var r := Rect2(22 + i * (we + 12), 214, we, 96)
		var c := D.rect(ctr, r, Charte.PANNEAU_2, Charte.RAYON_CARTE)
		D.rect(c, Rect2(0, 0, 6, 96), e[2], 3)
		V.chiffre(c, 20, 54, G.n(n), 42, e[2], we - 30)
		V.texte(c, 20, 82, str(e[1]).to_upper(), 15, Charte.IVOIRE_2, we - 26, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.zone_cliquable(c, Rect2(Vector2.ZERO, r.size), V.aller(ctx, "Parcours", "etape", str(e[0])), "CentreEtape_" + str(e[0]), str(e[1]), Charte.RAYON_CARTE)
	D.line(ctr, Vector2(22, 336), Vector2(w2 - 22, 336))
	var yy := 352.0
	for k in 2:
		var kind := "facilities" if k == 0 else "coaches"
		var niveau := int(data.get(kind, 0))
		var prix := _cout_niveau(data, kind, niveau, (niveau + 1) * (85000 if k == 0 else 55000)) if niveau < 3 else 0
		var titre := "Installations" if k == 0 else "Éducateurs"
		V.icone(ctr, Rect2(22, yy + 16, 24, 24), "home" if k == 0 else "people", V.PROGRES)
		V.texte(ctr, 58, yy + 35, titre, 20, Charte.IVOIRE, 170, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.crans(ctr, 220, yy + 23, niveau, 3, V.PROGRES, 30, 10)
		if niveau < 3: V.pilule(ctr, w2 - 22 - V.largeur(V.euros(prix), 19) - 58, yy + 8, V.euros(prix), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_upgrade", {"kind": kind}, prix, titre), "CentreAmeliorer_" + kind, "", not verrou)
		else: R.pastille(ctr, w2 - 120, yy + 35, "3 / 3", V.PROGRES, "check", "CentreMax_" + kind, 19)
		yy += 64.0
	var reunion := V.cout(ctx, "meeting", 2000)
	V.icone(ctr, Rect2(22, yy + 16, 24, 24), "people", V.COHESION)
	V.texte(ctr, 58, yy + 35, "Réunion de cohésion", 20, Charte.IVOIRE, 260, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	V.pilule(ctr, w2 - 22 - V.largeur(V.euros(reunion), 19) - 58, yy + 8, V.euros(reunion), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_meeting", {}, reunion, "Réunion de cohésion"), "CentreReunion", "", not verrou)
	_fleche_droite(racine, x + w2 + 6, y + h / 2.0)
	x += w2 + fl
	# 3. Rencontres juniors
	var ren := V.panneau(racine, Rect2(x, y, w3, h), "Rencontres juniors", "trophy", "CentreRencontres", func(): Juniors.ouvrir(ctx.app, ctx.page))
	var ronde := int(data.get("juniorRound", 0))
	var total := maxi(1, int(data.get("totalRounds", 26)))
	V.chiffre(ren, 22, 140, G.n(ronde), 64, V.MINUTES, 120)
	V.texte(ren, 22 + R.largeur(G.n(ronde), 64, 800) + 12, 134, "/ %d  PÉRIODES" % total, 20, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	var wc := (w3 - 44 - (total - 1) * 4) / total
	for i in total:
		D.rect(ren, Rect2(22 + i * (wc + 4), 166, wc, 16), Color(V.MINUTES, .9) if i < ronde else Charte.PANNEAU_3, 3)
	var resultats: Array = data.get("results", []).duplicate()
	resultats.reverse()
	var club := int(data.get("clubId", -1))
	var ry := 214.0
	V.texte(ren, 22, ry, "DERNIERS MATCHS", 17, Charte.IVOIRE_3, 300, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	ry += 14
	for i in mini(resultats.size(), 6):
		var r: Dictionary = resultats[i]
		var dom := int(r.get("home", -1)) == club
		var pour := int(r.score[0] if dom else r.score[1])
		var contre := int(r.score[1] if dom else r.score[0])
		var teinte := V.PROGRES if pour > contre else (V.ALERTE if pour < contre else Charte.IVOIRE_2)
		var lz := Rect2(14, ry, w3 - 28, 52)
		var ligne := V.zone_cliquable(ren, lz, func(): Juniors.ouvrir(ctx.app, ctx.page), "CentreResultat%d" % i, "Période %d" % (int(r.get("round", 0)) + 1), 6)
		D.rect(ligne, Rect2(8, 9, 34, 34), Color(teinte, .2), 6)
		V.chiffre(ligne, 25, 36, "V" if pour > contre else ("D" if pour < contre else "N"), 24, teinte, 30, HORIZONTAL_ALIGNMENT_CENTER)
		V.texte(ligne, 56, 33, "P%d" % (int(r.get("round", 0)) + 1), 18, Charte.IVOIRE_3, 50, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.chiffre(ligne, 110, 36, "%d – %d" % [pour, contre], 26, Charte.IVOIRE, 120)
		V.texte(ligne, 236, 33, str(r.get("awayCenter") if dom else r.get("homeCenter")), 19, Charte.IVOIRE_2, lz.size.x - 250)
		D.line(ren, Vector2(14, ry + 52), Vector2(w3 - 14, ry + 52))
		ry += 54.0
	var mode := "developpement" if str(data.get("mode", "")) == "formation" else str(data.get("mode", ""))
	for m: Array in MODES:
		if m[0] == mode: R.pastille(ren, 22, h - 30, str(m[1]), m[2], "calendar", "CentrePlanActif", 19)
	_fleche_droite(racine, x + w3 + 6, y + h / 2.0)
	x += w3 + fl
	# 4. Équipe première
	var prem := V.panneau(racine, Rect2(x, y, w4, h), "Équipe 1re", "shield", "CentrePremiere", func(): ctx.app._navigate("Effectif"))
	var places := int(data.get("places", 0))
	V.chiffre(prem, 22, 150, G.n(places), 72, V.REPUTATION, 140)
	V.texte(prem, 22 + R.largeur(G.n(places), 72, 800) + 14, 146, "PLACES PRO LIBRES", 18, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	var cote := 52.0
	var par := maxi(1, floori((w4 - 44 + 10) / (cote + 10)))
	for i in places:
		var s := D.rect(prem, Rect2(22 + (i % par) * (cote + 10), 182 + floori(i / float(par)) * (cote + 10), cote, cote), Color.TRANSPARENT, 999, V.REPUTATION)
		(s.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(2)))
		V.icone(s, Rect2(14, 14, 24, 24), "people", Color(V.REPUTATION, .8))
	var y4 := 182 + ceili(places / float(par)) * (cote + 10) + 20
	D.line(prem, Vector2(22, y4), Vector2(w4 - 22, y4))
	_ligne_chiffre(prem, Rect2(22, y4 + 14, w4 - 44, 56), "trophy", "Promus", G.n(data.get("promotions", []).size()), V.DEPENSE, V.aller(ctx, "Passerelle pro"), "CentrePromus")
	_ligne_chiffre(prem, Rect2(22, y4 + 76, w4 - 44, 56), "people", "Effectif pro", "%s / %s" % [G.n(data.get("occupied", 0)), G.n(data.get("capacity", 0))], Charte.IVOIRE, func(): ctx.app._navigate("Effectif"), "CentreEffectifPro")
	_ligne_chiffre(prem, Rect2(22, y4 + 138, w4 - 44, 56), "bus", "En prêt", G.n(data.get("loans", []).size()), V.COHESION, V.aller(ctx, "Passerelle pro"), "CentrePrets")
	# Réglages du centre : pastilles compactes, la valeur active en aplat de sa couleur.
	var yr := y + h + ECART
	var regl := V.panneau(racine, Rect2(0, yr, zone.size.x, h_regl), "Réglages", "settings", "CentreReglages")
	var choix := func(commande: String, cle: String) -> Callable:
		return func(v: Variant): V.envoyer(ctx, commande, {cle: v})
	var rangs := [["Plan des rencontres", MODES, mode, choix.call("academy_mode", "mode"), "CentreMode"], ["Objectif annuel", OBJECTIFS, str(data.get("goal", "")), choix.call("academy_goal", "goal"), "CentreObjectif"], ["Identité", IDENTITES, str(data.get("identity", "")), choix.call("academy_identity", "identity"), "CentreIdentite"]]
	for i in rangs.size():
		var rg: Array = rangs[i]
		var defs: Array = []
		for o: Array in rg[1]: defs.append([o[0], o[1], o[2], "", not verrou])
		V.reglage(regl, 22, 74.0 + i * 56.0, zone.size.x - 44, str(rg[0]), defs, rg[2], rg[3], str(rg[4]))

## Prix indexé du niveau suivant (moteur), sinon `defaut`.
static func _cout_niveau(data: Dictionary, kind: String, niveau: int, defaut: int) -> int:
	return load("res://ui/academy_pathways_view.gd").cost(data, kind, defaut, niveau)

# --- Parcours : les Espoirs sur le chemin -------------------------------------------------------------------------

static func _chemin(ctx: Dictionary, zone: Rect2, etapes: Array, actif: String, cle: String, id: String, titre: String, fin: Array) -> void:
	var p := V.panneau(ctx.racine, Rect2(0, zone.position.y, GAUCHE, zone.size.y), titre, "arrow", id)
	var n := etapes.size() + (1 if not fin.is_empty() else 0)
	var fl := 34.0
	var hb := (zone.size.y - V.ENTETE - 18 - fl * (n - 1)) / n
	var y := V.ENTETE + 4.0
	for i in etapes.size():
		var e: Array = etapes[i]
		var valeur := str(e[0])
		var choisi := valeur == actif
		var r := Rect2(16, y, GAUCHE - 32, hb)
		var c := D.rect(p, r, Charte.PANNEAU_2.lerp(e[2], .28) if choisi else Charte.PANNEAU_2, Charte.RAYON_CARTE, e[2] if choisi else Color.TRANSPARENT)
		if choisi: (c.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(2)))
		D.rect(c, Rect2(0, 0, 6, hb), e[2], 3)
		V.texte(c, 22, 34, str(e[1]).to_upper(), 19, Charte.IVOIRE, r.size.x - 150, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.chiffre(c, r.size.x - 18, 50, str(e[3]), 48, e[2], 130, HORIZONTAL_ALIGNMENT_RIGHT)
		var visages: Array = e[4]
		var par := floori((r.size.x - 36) / 46.0)
		for k in mini(visages.size(), par * 2):
			V.portrait(c, Rect2(22 + (k % par) * 46, hb - 100 + floori(k / float(par)) * 46, 40, 40), visages[k], e[2], true)
		var suite := "" if choisi else valeur
		V.zone_cliquable(c, Rect2(Vector2.ZERO, r.size), V.aller(ctx, ctx.onglet, cle, suite), "%sEtape_%s" % [id, valeur], str(e[1]), Charte.RAYON_CARTE)
		y += hb
		if i < n - 1:
			_fleche_bas(p, GAUCHE / 2.0, y + 4)
			y += fl
	if not fin.is_empty():
		var r2 := Rect2(16, y, GAUCHE - 32, hb)
		var c2 := D.rect(p, r2, Charte.PANNEAU_2, Charte.RAYON_CARTE)
		D.rect(c2, Rect2(0, 0, 6, hb), fin[2], 3)
		V.texte(c2, 22, 34, str(fin[0]).to_upper(), 19, Charte.IVOIRE, r2.size.x - 150, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.chiffre(c2, r2.size.x - 18, 50, str(fin[1]), 48, fin[2], 130, HORIZONTAL_ALIGNMENT_RIGHT)
		V.texte(c2, 22, hb - 22, str(fin[3]), 18, Charte.IVOIRE_2, r2.size.x - 40, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.zone_cliquable(c2, Rect2(Vector2.ZERO, r2.size), fin[4], id + "Fin", str(fin[0]), Charte.RAYON_CARTE)

static func _par_potentiel(a: Dictionary, b: Dictionary) -> bool:
	return V.valeur(a, "potential") > V.valeur(b, "potential")

static func _parcours(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var tous: Array = data.get("players", [])
	var etape := str(ctx.state.get("etape", ""))
	var filtre := str(ctx.state.get("filtre_traj", ""))
	var etapes: Array = []
	for e: Array in V.ETAPES:
		var liste: Array = tous.filter(func(p: Dictionary): return V.etape(p) == str(e[0]))
		liste.sort_custom(_par_potentiel)
		etapes.append([e[0], e[1], e[2], liste.size(), liste])
	_chemin(ctx, zone, etapes, etape, "etape", "CentreChemin", "Le chemin", ["Équipe 1re", G.n(data.get("places", 0)), V.REPUTATION, "%s promus" % G.n(data.get("promotions", []).size()), func(): ctx.app._navigate("Effectif")])
	var lz := Rect2(X_LISTE, zone.position.y, L_LISTE, zone.size.y)
	var joueurs: Array = tous.filter(func(p: Dictionary): return (etape.is_empty() or V.etape(p) == etape) and (filtre.is_empty() or str(p.path) == filtre))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 380.0, "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "x": 410.0, "w": 190.0, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "x": 610.0, "w": 60.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "x": 690.0, "w": 70.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "x": 780.0, "w": 100.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "x": 920.0, "w": 200.0, "tri": true, "desc": false},
		{"k": "min", "t": "MINUTES", "x": 1140.0, "w": 330.0, "tri": true},
		{"k": "spe", "t": "SPÉCIALITÉ", "x": 1500.0, "w": 130.0, "tri": true, "desc": false},
		{"k": "cond", "t": "COND.", "x": 1630.0, "w": 80.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
	]
	var cellule := func(ligne: Control, col: Dictionary, p: Dictionary, h: float, base: float):
		var x: float = col.ax
		var w: float = col.w
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		match str(col.k):
			"nom": V.cellule_joueur(ctx, ligne, x, h, base, p, w)
			"poste": V.texte(ligne, x, base, str(p.pos), 19, Charte.IVOIRE, w, a, 500)
			"age": V.texte(ligne, x, base, G.n(p.age), 19, Charte.IVOIRE_2, w, a, 500)
			"niv": V.texte(ligne, x, base, V.niveau_txt(p), 21, V.couleur(V.valeur(p, "rating")), w, a, 700, false)
			"pot": V.texte(ligne, x, base, V.potentiel_txt(p), 21, V.couleur(V.valeur(p, "potential")), w, a, 700, false)
			"traj":
				var t := V.trajectoire(str(p.path))
				R.pastille(ligne, x, base, str(t[1]), t[3], str(t[2]), "", 18)
			"min":
				var cible := float(p.get("target", 0))
				var m := float(p.get("minutes", 0))
				V.barre(ligne, Rect2(x, 0, w, h), m / (cible if cible > 0 else 480.0), V.MINUTES, ("%s / %s" % [V.mille(m), V.mille(cible)]) if cible > 0 else V.mille(m))
			"spe": V.texte(ligne, x, base, str(p.get("program", "")).capitalize() if p.get("program") != null else "—", 19, V.REPUTATION if p.get("program") != null else Charte.IVOIRE_3, w, a, 600)
			"cond":
				var cd := float(p.get("condition", 0))
				V.texte(ligne, x, base, "%d %%" % int(cd), 19, Charte.CONDITION if cd >= 85 else (Charte.INTENSIF if cd >= 60 else Charte.PERTE), w, a, 600)
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"traj": return str(V.trajectoire(str(p.path))[1])
			"min": return float(p.get("minutes", 0))
			"spe": return str(p.get("program", "")) if p.get("program") != null else "~"
			"cond": return float(p.get("condition", 0))
		return null
	var groupes: Array = []
	if etape.is_empty():
		for e: Array in V.ETAPES:
			var eid := str(e[0])
			groupes.append([str(e[1]), e[2], func(p: Dictionary): return V.etape(p) == eid])
	var table := V.liste(ctx, lz, 62, colonnes, joueurs, cellule, cle, func(p: Dictionary, _l: Control): V.fenetre_parcours(ctx, str(p.id)), func(_p: Dictionary, rang: int): return "CentreVisuelJoueur%d" % rang, "CentreParcoursListe", groupes, ["pot", true])
	var defs: Array = [["", "Tous", Charte.IVOIRE, G.n(tous.filter(func(p: Dictionary): return etape.is_empty() or V.etape(p) == etape).size())]]
	for t: Array in V.TRAJECTOIRES:
		var tid := str(t[0])
		defs.append([tid, t[1], t[3], G.n(tous.filter(func(p: Dictionary): return str(p.path) == tid and (etape.is_empty() or V.etape(p) == etape)).size())])
	V.pilules(table, 16, 12, defs, filtre, func(v: Variant):
		ctx.state.filtre_traj = str(v)
		(ctx.reconstruire as Callable).call(), "CentreFiltreTrajectoire")

# --- Centres : les centres des autres clubs -----------------------------------------------------------------------

static func _centres(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var world: bool = data.get("world", false)
	var verrou: bool = data.get("locked", false)
	var observe := V.cout(ctx, "centerScout", 1200)
	var centres: Array = data.get("centers", []).filter(func(c: Dictionary): return not c.get("own", false) and (not world or c.scouted or c.count > 15))
	var vus: Array = centres.filter(func(c: Dictionary): return c.scouted)
	var candidats: Array = []
	for c: Dictionary in vus:
		for p: Dictionary in c.get("candidates", []):
			var q := p.duplicate()
			q.centre = str(c.name)
			candidats.append(q)
	candidats.sort_custom(_par_potentiel)
	# Colonne : l'observation puis les candidats des centres observés (cartes visage + potentiel).
	var obs := V.panneau(ctx.racine, Rect2(0, zone.position.y, GAUCHE, 236), "Observation", "search", "CentresObservation")
	_ligne_chiffre(obs, Rect2(22, 74, GAUCHE - 44, 50), "search", "Centres observés", "%d / %d" % [vus.size(), centres.size()], V.MINUTES, Callable(), "")
	_ligne_chiffre(obs, Rect2(22, 124, GAUCHE - 44, 50), "money", "Une observation", V.euros(observe), V.DEPENSE, Callable(), "")
	_ligne_chiffre(obs, Rect2(22, 174, GAUCHE - 44, 50), "money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE, Callable(), "")
	var hc := zone.size.y - 236 - ECART
	var cand := V.panneau(ctx.racine, Rect2(0, zone.position.y + 236 + ECART, GAUCHE, hc), "Candidats", "people", "CentresCandidats", Callable(), G.n(candidats.size()), V.PROGRES)
	var yk := V.ENTETE + 4.0
	for i in candidats.size():
		if yk + 84 > hc - 8: break
		var p: Dictionary = candidats[i]
		var fee := int(p.get("fee", 0))
		var pid := str(p.id)
		var pt := V.couleur(V.valeur(p, "potential"))
		var b := V.zone_cliquable(cand, Rect2(12, yk, GAUCHE - 24, 80), func(): V.envoyer(ctx, "academy_recruit", {"playerId": pid, "offer": fee}, fee, "Recruter " + str(p.name)), "CentresCandidat%d" % i, str(p.name), Charte.RAYON_CARTE)
		V.portrait(b, Rect2(10, 10, 60, 60), p, pt, true)
		V.texte(b, 84, 34, str(p.name), 20, Charte.IVOIRE, 220, HORIZONTAL_ALIGNMENT_LEFT, 700)
		V.texte(b, 84, 60, str(p.pos), 16, Charte.IVOIRE_2, 220)
		V.chiffre(b, GAUCHE - 40, 44, V.potentiel_txt(p), 32, pt, 130, HORIZONTAL_ALIGNMENT_RIGHT)
		V.texte(b, GAUCHE - 40, 68, V.euros(fee), 17, V.DEPENSE, 130, HORIZONTAL_ALIGNMENT_RIGHT, 700, false)
		yk += 86.0
	# Liste des centres.
	var filtre := str(ctx.state.get("filtre_centres", ""))
	var montres: Array = centres.filter(func(c: Dictionary): return filtre.is_empty() or (filtre == "vus") == bool(c.scouted))
	var max_n := 1
	for c: Dictionary in centres: max_n = maxi(max_n, int(c.count))
	var colonnes := [
		{"k": "nom", "t": "CENTRE", "x": 16.0, "w": 520.0, "tri": true, "desc": false},
		{"k": "n", "t": "JEUNES", "x": 560.0, "w": 380.0, "tri": true},
		{"k": "cand", "t": "CANDIDATS", "x": 970.0, "w": 330.0},
		{"k": "pot", "t": "MEILLEUR POT.", "x": 1300.0, "w": 150.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "act", "t": "", "x": 1500.0, "w": 220.0},
	]
	var meilleur := func(c: Dictionary) -> float:
		var m := -1.0
		for p: Dictionary in c.get("candidates", []): m = maxf(m, V.valeur(p, "potential"))
		return m
	var cellule := func(ligne: Control, col: Dictionary, c: Dictionary, h: float, base: float):
		var x: float = col.ax
		var w: float = col.w
		match str(col.k):
			"nom":
				V.blason(ligne, Rect2(x, 5, 32, 32), str(c.name), V.MINUTES if c.scouted else Charte.IVOIRE_3)
				V.texte(ligne, x + 46, base, str(c.name), 20, Charte.IVOIRE, w - 50)
			"n": V.barre(ligne, Rect2(x, 0, w, h), float(c.count) / max_n, V.MINUTES if c.scouted else Charte.IVOIRE_2, G.n(c.count))
			"cand":
				var k := 0
				for p: Dictionary in c.get("candidates", []).slice(0, 7):
					V.portrait(ligne, Rect2(x + k * 40, (h - 34) / 2.0, 34, 34), p, V.couleur(V.valeur(p, "potential")), true)
					k += 1
			"pot":
				var m: float = meilleur.call(c)
				V.texte(ligne, x, base, "—" if m < 0 else str(roundi(m)), 21, V.couleur(m), w, HORIZONTAL_ALIGNMENT_RIGHT, 700, false)
			"act":
				if c.scouted: R.pastille(ligne, x, base, "Observé", V.PROGRES, "check", "", 18)
				else: R.pastille(ligne, x, base, "Observer · " + V.euros(observe), V.DEPENSE, "search", "", 18)
	var cle := func(c: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(c.name)
			"n": return int(c.count)
			"pot": return meilleur.call(c)
		return null
	var au_clic := func(c: Dictionary, _l: Control):
		if verrou: return
		if c.scouted: _fenetre_candidats(ctx, c)
		else: V.envoyer(ctx, "academy_center_scout", {"centerId": str(c.id)}, observe, "Observer " + str(c.name))
	var groupes: Array = [["Observés", V.MINUTES, func(c: Dictionary): return c.scouted], ["À observer", Charte.IVOIRE_3, func(c: Dictionary): return not c.scouted]]
	var table := V.liste(ctx, Rect2(X_LISTE, zone.position.y, L_LISTE, zone.size.y), 62, colonnes, montres, cellule, cle, au_clic, func(c: Dictionary, _r: int): return "CentreLigne_" + str(c.id).validate_node_name(), "CentresListe", groupes, ["n", true])
	V.pilules(table, 16, 12, [["", "Tous", Charte.IVOIRE, G.n(centres.size())], ["vus", "Observés", V.MINUTES, G.n(vus.size())], ["avoir", "À observer", Charte.IVOIRE_2, G.n(centres.size() - vus.size())]], filtre, func(v: Variant):
		ctx.state.filtre_centres = str(v)
		(ctx.reconstruire as Callable).call(), "CentresFiltre")

static func _fenetre_candidats(ctx: Dictionary, c: Dictionary) -> void:
	var elements: Array = []
	for p: Dictionary in c.get("candidates", []):
		elements.append({"id": str(p.id), "libelle": str(p.name), "sous": "%s · pot. %s · %s" % [p.pos, V.potentiel_txt(p), V.euros(p.get("fee", 0))], "couleur": V.couleur(V.valeur(p, "potential"))})
	V.fenetre_liste(ctx, "CentresCandidatsFenetre", str(c.name), "people", elements, func(id: Variant):
		for p: Dictionary in c.get("candidates", []):
			if str(p.id) == str(id): V.envoyer(ctx, "academy_recruit", {"playerId": str(p.id), "offer": int(p.fee)}, int(p.fee), "Recruter " + str(p.name)))

# --- Filières : régions, clubs formateurs et jeunes repérés --------------------------------------------------------

static func _filieres(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var verrou: bool = data.get("locked", false)
	var prospects: Array = data.get("prospects", [])
	var regions: Array = data.get("regions", [])
	var region_f := str(ctx.state.get("region", ""))
	var discover := V.cout(ctx, "discover", 3000)
	var partner := V.cout(ctx, "partner", 2000)
	var h_reg := V.ENTETE + 8 + regions.size() * 54.0 + 10
	var reg := V.panneau(ctx.racine, Rect2(0, zone.position.y, GAUCHE, h_reg), "Régions", "globe", "FilieresRegions")
	for i in regions.size():
		var region := str(regions[i])
		var teinte: Color = V.COULEURS[i % V.COULEURS.size()]
		var n := prospects.filter(func(p: Dictionary): return str(p.region) == region).size()
		var y := V.ENTETE + 6 + i * 54.0
		var choisi := region == region_f
		var b := V.zone_cliquable(reg, Rect2(10, y, GAUCHE - 20, 50), V.aller(ctx, "Filières", "region", "" if choisi else region), "FilieresRegion%d" % i, region, 8)
		if choisi: b.add_theme_stylebox_override("normal", V.plat(Charte.PANNEAU_2.lerp(teinte, .3), teinte, 1, 8))
		D.rect(b, Rect2(12, 19, 12, 12), teinte, Charte.RAYON_PILULE)
		V.texte(b, 36, 32, region, 20, Charte.IVOIRE, 200, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
		V.chiffre(b, 262, 35, G.n(n), 28, teinte, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		V.pilule(b, GAUCHE - 30 - V.largeur(V.euros(discover), 17) - 54, 7, V.euros(discover), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_discover", {"region": region}, discover, "Détecter · " + region), "FilieresDetecter%d" % i, "", not verrou, 36, 17)
	var yf := zone.position.y + h_reg + ECART
	var feeders: Array = data.get("feeders", [])
	var partenaires: Array = data.get("partners", [])
	var fp := V.panneau(ctx.racine, Rect2(0, yf, GAUCHE, zone.size.y - h_reg - ECART), "Clubs formateurs", "flag", "FilieresFormateurs", Callable(), G.n(partenaires.size()), V.PROGRES)
	var hl := minf(40.0, (zone.size.y - h_reg - ECART - V.ENTETE - 12) / maxf(1, feeders.size()))
	for i in feeders.size():
		var f: Dictionary = feeders[i]
		var fid := str(f.id)
		var ok := partenaires.has(fid)
		var y := V.ENTETE + 4 + i * hl
		var nom_f := str(f.name)
		var b := V.zone_cliquable(fp, Rect2(10, y, GAUCHE - 20, hl - 2), func(): _partenariat(ctx, fid, nom_f, ok or verrou, partner), "FilieresFormateur_" + fid.validate_node_name(), nom_f, 6)
		V.icone(b, Rect2(10, (hl - 2 - 20) / 2.0, 20, 20), "check" if ok else "flag", V.PROGRES if ok else Charte.IVOIRE_3)
		V.texte(b, 40, hl / 2.0 + 6, str(f.name), 18, Charte.IVOIRE if ok else Charte.IVOIRE_2, 270, HORIZONTAL_ALIGNMENT_LEFT, 600)
		V.texte(b, GAUCHE - 34, hl / 2.0 + 6, "Partenaire" if ok else V.euros(partner), 17, V.PROGRES if ok else V.DEPENSE, 120, HORIZONTAL_ALIGNMENT_RIGHT, 700, false)
	# Jeunes repérés.
	var filtre := str(ctx.state.get("filtre_prospects", ""))
	var garde := func(p: Dictionary, f: String) -> bool:
		match f:
			"zero": return int(p.scouted) == 0
			"suivis": return int(p.scouted) > 0 and not p.trial
			"essai": return bool(p.trial)
		return true
	var dans_region := prospects.filter(func(p: Dictionary): return region_f.is_empty() or str(p.region) == region_f)
	var montres := dans_region.filter(func(p: Dictionary): return garde.call(p, filtre))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 330.0, "tri": true, "desc": false},
		{"k": "club", "t": "CLUB FORMATEUR", "x": 360.0, "w": 290.0, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "x": 660.0, "w": 50.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "poste", "t": "POSTE", "x": 740.0, "w": 180.0, "tri": true, "desc": false},
		{"k": "pot", "t": "POT.", "x": 930.0, "w": 100.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "obs", "t": "OBSERVATIONS", "x": 1070.0, "w": 170.0, "tri": true},
		{"k": "essai", "t": "ESSAI", "x": 1260.0, "w": 120.0, "tri": true},
		{"k": "suite", "t": "", "x": 1400.0, "w": 320.0},
	]
	var watch := V.cout(ctx, "watch", 500)
	var trial := V.cout(ctx, "trial", 1000)
	var recruit := V.cout(ctx, "recruit", 8000)
	var cellule := func(ligne: Control, col: Dictionary, p: Dictionary, h: float, base: float):
		var x: float = col.ax
		var w: float = col.w
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		match str(col.k):
			"nom": V.cellule_joueur(ctx, ligne, x, h, base, p, w, "")
			"club": V.texte(ligne, x, base, str(p.clubName), 18, Charte.IVOIRE_2, w, a, 500)
			"age": V.texte(ligne, x, base, G.n(p.age), 19, Charte.IVOIRE_2, w, a, 500)
			"poste": V.texte(ligne, x, base, str(p.pos), 19, Charte.IVOIRE, w, a, 500)
			"pot":
				var vu := int(p.scouted) > 0
				V.texte(ligne, x, base, V.potentiel_txt(p) if vu else "?", 21, V.couleur(V.valeur(p, "potential")) if vu else Charte.IVOIRE_3, w, a, 700, false)
			"obs":
				V.crans(ligne, x, h / 2.0 - 5, int(p.scouted), 3, V.MINUTES, 30, 10)
				V.texte(ligne, x + 112, base, "%d/3" % int(p.scouted), 18, V.MINUTES if int(p.scouted) > 0 else Charte.IVOIRE_3, 50, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
			"essai":
				if p.trial: R.pastille(ligne, x, base, "Fait", V.PROGRES, "check", "", 17)
				else: V.texte(ligne, x, base, "—", 19, Charte.IVOIRE_3, w)
			"suite":
				var s := _suite_prospect(p, watch, trial, recruit)
				if not s.is_empty(): R.pastille(ligne, x, base, str(s[1]), s[2], str(s[3]), "", 17)
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"club": return str(p.clubName)
			"age": return int(p.age)
			"poste": return str(p.pos)
			"pot": return V.valeur(p, "potential") if int(p.scouted) > 0 else -1.0
			"obs": return int(p.scouted)
			"essai": return 1 if p.trial else 0
		return null
	var table := V.liste(ctx, Rect2(X_LISTE, zone.position.y, L_LISTE, zone.size.y), 62, colonnes, montres, cellule, cle, func(p: Dictionary, _l: Control): _fenetre_prospect(ctx, p), func(p: Dictionary, _r: int): return "FilieresJeune_" + str(p.id).validate_node_name(), "FilieresListe", [], ["obs", true])
	var defs := [["", "Tous", Charte.IVOIRE, G.n(dans_region.size())], ["zero", "À observer", Charte.IVOIRE_2, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "zero")).size())], ["suivis", "Observés", V.MINUTES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "suivis")).size())], ["essai", "Essai fait", V.PROGRES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "essai")).size())]]
	V.pilules(table, 16, 12, defs, filtre, func(v: Variant):
		ctx.state.filtre_prospects = str(v)
		(ctx.reconstruire as Callable).call(), "FilieresFiltre")

static func _partenariat(ctx: Dictionary, fid: String, nom: String, ferme: bool, prix: int) -> void:
	if not ferme: V.envoyer(ctx, "academy_partner", {"feederId": fid}, prix, "Partenariat · " + nom)

## Prochaine étape d'un jeune repéré : [action, libellé, couleur, icône].
static func _suite_prospect(p: Dictionary, watch: int, trial: int, recruit: int) -> Array:
	if int(p.scouted) < 1: return ["watch", "Observer · " + V.euros(watch), V.MINUTES, "search"]
	if not p.trial: return ["trial", "Essai · " + V.euros(trial), V.PROGRES, "train"]
	if int(p.scouted) >= 2 and int(p.age) >= 16: return ["recruit", "Proposer · " + V.euros(recruit), V.DEPENSE, "trophy"]
	return ["watch", "Observer · " + V.euros(watch), V.MINUTES, "search"]

static func _fenetre_prospect(ctx: Dictionary, p: Dictionary) -> void:
	var data: Dictionary = ctx.data
	var id := str(p.id)
	var watch := V.cout(ctx, "watch", 500)
	var trial := V.cout(ctx, "trial", 1000)
	var recruit := V.cout(ctx, "recruit", 8000)
	var a: bool = not bool(data.get("locked", false))
	var L := 1100.0
	var fond := Fenetre.ouvrir(ctx.page, "FilieresProspectFenetre", str(p.name).to_upper(), "search", L, 330.0)
	var vu := int(p.scouted) > 0
	var pt := V.couleur(V.valeur(p, "potential")) if vu else Charte.IVOIRE_3
	V.portrait(fond, Rect2(30, 78, 84, 84), p, pt, true)
	V.texte(fond, 134, 104, "%s · %s ans · %s" % [p.pos, G.n(p.age), p.clubName], 20, Charte.IVOIRE_2, 560)
	V.crans(fond, 134, 128, int(p.scouted), 3, V.MINUTES, 34, 10)
	if p.trial: R.pastille(fond, 270, 140, "Essai", V.PROGRES, "check", "", 17)
	V.chiffre(fond, L - 40, 140, V.potentiel_txt(p) if vu else "?", 54, pt, 260, HORIZONTAL_ALIGNMENT_RIGHT)
	var defs: Array = [["watch", "Observer", V.MINUTES, V.euros(watch), a and int(p.scouted) < 3], ["trial", "Essai", V.PROGRES, V.euros(trial), a and not p.trial and int(p.scouted) > 0]]
	if str(p.union) != str(data.get("homeUnion", "FR")): defs.append(["clearance", "Autorisation", V.COHESION, "", a and int(p.age) >= 18 and p.trial and not p.get("clearanceRecorded", false)])
	defs.append(["recruit", "Proposer le projet", V.DEPENSE, V.euros(recruit), a and int(p.scouted) >= 2 and p.trial and int(p.age) >= 16])
	V.pilules(fond, 30, 210, defs, null, func(v: Variant): _action_prospect(ctx, id, str(v), watch, trial, recruit), "FilieresAction", 44.0, 19, L - 60)

static func _action_prospect(ctx: Dictionary, id: String, action: String, watch: int, trial: int, recruit: int) -> void:
	Fenetre.fermer(ctx.page, "FilieresProspectFenetre")
	if action == "watch": V.envoyer(ctx, "academy_watch", {"playerId": id}, watch, "Observer")
	elif action == "trial": V.envoyer(ctx, "academy_trial", {"playerId": id}, trial, "Essai")
	elif action == "clearance": V.envoyer(ctx, "academy_clearance", {"playerId": id})
	else: V.envoyer(ctx, "academy_feeder_recruit", {"playerId": id}, recruit, "Proposer le projet")

# --- Passerelle pro : jeunes pros, prêts, retours ------------------------------------------------------------------

static func _passerelle(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var jeunes: Array = data.get("seniors", []).filter(func(s: Dictionary): return int(s.age) <= 23 or s.get("loanEligible", false))
	var prets: Array = data.get("loans", [])
	var hotes := {}
	for cl: Dictionary in data.get("loanClubs", []): hotes[int(cl.id)] = str(cl.name)
	var elements: Array = jeunes.duplicate()
	for pr: Dictionary in prets:
		var e := pr.duplicate()
		e.pret = true
		e.hote = hotes.get(int(pr.to), "club %d" % int(pr.to))
		elements.append(e)
	var pretables := jeunes.filter(func(s: Dictionary): return s.get("loanEligible", false))
	var etape := str(ctx.state.get("etape_pro", ""))
	var etapes := [
		["jeunes", "Jeunes pros", V.PROGRES, jeunes.size(), jeunes.slice(0, 5)],
		["pretables", "Prêtables", V.MINUTES, pretables.size(), pretables.slice(0, 5)],
		["prets", "En prêt", V.REPUTATION, prets.size(), []],
	]
	_chemin(ctx, zone, etapes, etape, "etape_pro", "PasserelleChemin", "Le chemin", ["Retour", G.n(prets.size()), V.COHESION, "à l’intersaison", Callable()])
	var montres := elements.filter(func(e: Dictionary): return _garde_pro(e, etape))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 400.0, "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "x": 430.0, "w": 220.0, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "x": 660.0, "w": 60.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "x": 740.0, "w": 70.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "x": 830.0, "w": 100.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "statut", "t": "STATUT", "x": 980.0, "w": 420.0},
		{"k": "act", "t": "", "x": 1420.0, "w": 300.0},
	]
	var cellule := func(ligne: Control, col: Dictionary, e: Dictionary, h: float, base: float):
		var x: float = col.ax
		var w: float = col.w
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		var pret: bool = e.get("pret", false)
		match str(col.k):
			"nom": V.cellule_joueur(ctx, ligne, x, h, base, e, w, "" if pret else "squad")
			"poste": V.texte(ligne, x, base, str(e.get("pos", "—")), 19, Charte.IVOIRE, w, a, 500)
			"age": V.texte(ligne, x, base, G.n(e.get("age", "—")), 19, Charte.IVOIRE_2, w, a, 500)
			"niv": V.texte(ligne, x, base, V.niveau_txt(e) if not pret else "—", 21, V.couleur(V.valeur(e, "rating")), w, a, 700, false)
			"pot": V.texte(ligne, x, base, V.potentiel_txt(e) if not pret else "—", 21, V.couleur(V.valeur(e, "potential")), w, a, 700, false)
			"statut":
				if pret: R.pastille(ligne, x, base, "En prêt · " + str(e.hote), V.REPUTATION, "bus", "", 18)
				elif e.get("loanEligible", false): R.pastille(ligne, x, base, "Prêtable", V.MINUTES, "bus", "", 18)
				else: R.pastille(ligne, x, base, "Effectif", Charte.IVOIRE_3, "lock", "", 18)
			"act":
				if not pret and e.get("loanEligible", false): R.pastille(ligne, x, base, "Prêter", V.MINUTES, "arrow", "", 18)
	var cle := func(e: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(e.get("name", ""))
			"poste": return str(e.get("pos", ""))
			"age": return int(e.get("age", 0))
			"niv": return V.valeur(e, "rating")
			"pot": return V.valeur(e, "potential")
		return null
	var au_clic := func(e: Dictionary, _l: Control):
		if e.get("pret", false): return
		var sid := str(e.id)
		if e.get("loanEligible", false) and not data.get("locked", false): _fenetre_pret(ctx, sid)
		else: V.ouvrir_fiche(ctx, sid)
	var groupes: Array = [["Prêtables", V.MINUTES, func(e: Dictionary): return e.get("loanEligible", false) and not e.get("pret", false)], ["En effectif", Charte.IVOIRE_3, func(e: Dictionary): return not e.get("loanEligible", false) and not e.get("pret", false)], ["En prêt", V.REPUTATION, func(e: Dictionary): return e.get("pret", false)]]
	var table := V.liste(ctx, Rect2(X_LISTE, zone.position.y, L_LISTE, zone.size.y), 62, colonnes, montres, cellule, cle, au_clic, func(e: Dictionary, _r: int): return "PasserelleLigne_" + str(e.get("id", e.get("name", ""))).validate_node_name(), "PasserelleListe", groupes, ["age", false])
	var defs := [["", "Tous", Charte.IVOIRE, G.n(elements.size())], ["pretables", "Prêtables", V.MINUTES, G.n(pretables.size())], ["prets", "En prêt", V.REPUTATION, G.n(prets.size())]]
	V.pilules(table, 16, 12, defs, etape, func(v: Variant):
		ctx.state.etape_pro = str(v)
		(ctx.reconstruire as Callable).call(), "PasserelleFiltre")

static func _garde_pro(e: Dictionary, etape: String) -> bool:
	if etape == "pretables": return e.get("loanEligible", false)
	if etape == "prets": return e.get("pret", false)
	if etape == "jeunes": return not e.get("pret", false)
	return true

static func _fenetre_pret(ctx: Dictionary, id: String) -> void:
	var clubs: Array = ctx.data.get("loanClubs", []).duplicate()
	clubs.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name) < str(b.name))
	var elements: Array = []
	for cl: Dictionary in clubs: elements.append({"id": int(cl.id), "libelle": str(cl.name)})
	V.fenetre_liste(ctx, "PasserellePretFenetre", "Club d’accueil", "bus", elements, func(to: Variant): V.envoyer(ctx, "academy_loan", {"playerId": id, "to": to}, 0, "Confirmer le prêt"))

# --- Générations : la frise des saisons ------------------------------------------------------------------------------

static func _generations(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var gens: Array = data.get("generations", []).duplicate()
	var colonnes_frise: Array = []
	for g: Dictionary in gens:
		colonnes_frise.append({"titre": G.season_label(g.season), "joueurs": g.players, "promus": int(g.get("graduates", 0)), "reputation": int(g.get("reputation", 0))})
	colonnes_frise.append({"titre": "En cours", "joueurs": data.get("players", []), "promus": data.get("promotions", []).size(), "reputation": int(data.get("reputation", 0)), "courante": true})
	var choix := int(ctx.state.get("generation", colonnes_frise.size() - 1))
	choix = clampi(choix, 0, colonnes_frise.size() - 1)
	var hf := 320.0
	var frise := V.panneau(ctx.racine, Rect2(0, zone.position.y, zone.size.x, hf), "La frise des générations", "trophy", "GenerationsFrise")
	var wc := minf(440.0, (zone.size.x - 44 - 20 * (colonnes_frise.size() - 1)) / colonnes_frise.size())
	var max_j := 1
	for f: Dictionary in colonnes_frise: max_j = maxi(max_j, (f.joueurs as Array).size())
	D.rect(frise, Rect2(22, 96, zone.size.x - 44, 3), Color(V.REPUTATION, .6), 2)
	for i in colonnes_frise.size():
		var f: Dictionary = colonnes_frise[i]
		var x := 22 + i * (wc + 20)
		var choisi := i == choix
		var teinte := V.MINUTES if f.get("courante", false) else V.REPUTATION
		D.rect(frise, Rect2(x + 16, 88, 18, 18), teinte, Charte.RAYON_PILULE)
		var b := V.zone_cliquable(frise, Rect2(x, 112, wc, hf - 124), V.aller(ctx, "Générations", "generation", i), "GenerationsSaison%d" % i, str(f.titre), Charte.RAYON_CARTE)
		if choisi: b.add_theme_stylebox_override("normal", V.plat(Charte.PANNEAU_2.lerp(teinte, .18), teinte, 1, Charte.RAYON_CARTE))
		var t := V.chiffre(b, 16, 42, str(f.titre).to_upper(), 28, Charte.IVOIRE, wc - 30)
		t.add_theme_font_override("font", Charte.TITRE_FICHE)
		var barres := [[(f.joueurs as Array).size(), max_j, "JOUEURS", V.PROGRES], [int(f.promus), maxi(1, max_j / 4), "PROMUS", V.DEPENSE], [int(f.reputation), 100, "RÉPUTATION", V.REPUTATION]]
		for k in barres.size():
			var br: Array = barres[k]
			var by := 66 + k * 46
			V.texte(b, 16, by + 22, br[2], 15, Charte.IVOIRE_2, 110, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
			var rail := Rect2(128, by + 10, wc - 128 - 80, 14)
			D.rect(b, rail, Charte.PANNEAU_3, 4)
			if int(br[0]) > 0: D.rect(b, Rect2(rail.position, Vector2(maxf(6.0, rail.size.x * clampf(float(br[0]) / float(br[1]), 0, 1)), 14)), br[3], 4)
			V.chiffre(b, wc - 16, by + 26, G.n(br[0]), 26, br[3], 70, HORIZONTAL_ALIGNMENT_RIGHT)
	# La génération choisie en liste.
	var f: Dictionary = colonnes_frise[choix]
	var courante: bool = f.get("courante", false)
	var joueurs: Array = f.joueurs
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "x": 16.0, "w": 440.0, "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "x": 470.0, "w": 230.0, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "x": 720.0, "w": 60.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "x": 800.0, "w": 80.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "x": 900.0, "w": 110.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "min", "t": "MINUTES", "x": 1060.0, "w": 140.0, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "x": 1260.0, "w": 260.0, "tri": true, "desc": false},
	]
	var cellule := func(ligne: Control, col: Dictionary, p: Dictionary, h: float, base: float):
		var x: float = col.ax
		var w: float = col.w
		var a: HorizontalAlignment = col.get("a", HORIZONTAL_ALIGNMENT_LEFT)
		match str(col.k):
			"nom": V.cellule_joueur(ctx, ligne, x, h, base, p, w, "academy" if not V.joueur(data, str(p.id)).is_empty() else "")
			"poste": V.texte(ligne, x, base, str(p.pos), 19, Charte.IVOIRE, w, a, 500)
			"age": V.texte(ligne, x, base, G.n(p.age), 19, Charte.IVOIRE_2, w, a, 500)
			"niv": V.texte(ligne, x, base, V.niveau_txt(p), 21, V.couleur(V.valeur(p, "rating")), w, a, 700, false)
			"pot": V.texte(ligne, x, base, V.potentiel_txt(p), 21, V.couleur(V.valeur(p, "potential")), w, a, 700, false)
			"min": V.texte(ligne, x, base, V.mille(p.get("minutes", 0)), 19, V.MINUTES, w, a, 700, false)
			"traj":
				var t := V.trajectoire(str(p.get("path", p.get("strategy", "equilibre"))))
				R.pastille(ligne, x, base, str(t[1]), t[3], str(t[2]), "", 18)
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"min": return int(p.get("minutes", 0))
			"traj": return str(p.get("path", p.get("strategy", "")))
		return null
	var au_clic := func(p: Dictionary, _l: Control):
		var pid := str(p.id)
		if not V.joueur(data, pid).is_empty(): V.fenetre_parcours(ctx, pid)
		else: V.ouvrir_fiche(ctx, pid)
	var yl := zone.position.y + hf + ECART
	var table := V.liste(ctx, Rect2(0, yl, zone.size.x, zone.size.y - hf - ECART), 0, colonnes, joueurs, cellule, cle, au_clic, func(p: Dictionary, _r: int): return "GenerationsJoueur_" + str(p.id).validate_node_name(), "GenerationsListe", [], ["pot", true])
	table.set_meta("courante", courante)
