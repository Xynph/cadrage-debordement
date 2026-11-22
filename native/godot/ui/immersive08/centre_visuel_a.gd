extends RefCounted
## Centre de formation, direction A « Les cartes » (planche A/B, CD_VARIANTE_VISUELLE=A ; en attente du choix de Léo).
## Tout se lit en cartes, comme le Vestiaire et la Composition : chaque Espoir est une carte (visage, niveau et
## potentiel en grand, jauge de minutes, pastille de trajectoire), chaque réglage du centre une tuile dont le clic ouvre
## une petite fenêtre de tuiles. Un visage montre la carte joueur au survol ; une carte ouvre le parcours individuel.
## Coordonnées en unités du gabarit, relatives à la zone de l'onglet.
const V = preload("res://ui/immersive08/centre_visuel.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const Juniors = preload("res://ui/immersive08/centre_juniors.gd")

const COULEURS := [Charte.REPOS, Charte.GAIN, Charte.MORAL, Charte.CONFIANCE, Charte.INTENSIF, Charte.PERTE]
const CARTE := Vector2(356, 252)
const ECART := 16.0

static func onglet(ctx: Dictionary, nom: String, zone: Rect2) -> void:
	match nom:
		"Parcours": _parcours(ctx, zone)
		"Centres": _centres(ctx, zone)
		"Filières": _filieres(ctx, zone)
		"Passerelle pro": _passerelle(ctx, zone)
		"Générations": _generations(ctx, zone)
		_: _centre(ctx, zone)

# --- Carte d'un Espoir ----------------------------------------------------------------------------------------------

## Carte joueur : visage cerclé de la couleur de sa trajectoire, nom, poste et âge, niveau et potentiel en grand,
## jauge des minutes. Le clic ouvre `action` ; le visage, la carte joueur au survol.
static func carte_espoir(ctx: Dictionary, parent: Control, zone: Rect2, p: Dictionary, id_bouton: String, action: Callable, source: String = "academy", minutes: bool = true) -> Panel:
	var traj := V.trajectoire(str(p.get("path", p.get("strategy", "equilibre"))))
	var teinte: Color = traj[3]
	var c := V.carte(parent, zone, teinte, "CVACarte_" + str(p.id).validate_node_name())
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	Pieces.rendre_cliquable(c, zone.size, action, id_bouton, str(p.name), "", Charte.RAYON_CARTE)
	var visage := V.portrait(ctx, c, Rect2(16, 16, 96, 96), p, teinte, 4, source)
	visage.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT: action.call())
	var nom := str(p.name)
	var l := V.petit(c, 126, 44, nom, 23, Charte.IVOIRE, zone.size.x - 138)
	l.add_theme_font_override("font", C.EXTRA_BOLD)
	V.petit(c, 126, 70, "%s · %s ans" % [str(p.pos), G.n(p.get("age", "—"))], 17, Charte.IVOIRE_2, zone.size.x - 138)
	Pieces.pastille(c, 126, 82, str(traj[1]), str(traj[2]), "", "", teinte)
	var nv := V.valeur(p, "rating")
	var pt := V.valeur(p, "potential")
	V.chiffre(c, 18, 178, V.niveau_txt(p), 50, V.couleur(nv), 150)
	V.petit(c, 18, 198, "NIVEAU", 15, Charte.IVOIRE_3, 140)
	V.chiffre(c, zone.size.x - 18, 178, V.potentiel_txt(p), 50, V.couleur(pt), 190, HORIZONTAL_ALIGNMENT_RIGHT)
	V.petit(c, zone.size.x - 18, 198, "POTENTIEL", 15, Charte.IVOIRE_3, 180, HORIZONTAL_ALIGNMENT_RIGHT)
	if minutes and p.has("minutes"):
		var cible := float(p.get("target", 0))
		var m := float(p.minutes)
		V.jauge(c, Rect2(18, 216, zone.size.x - 150, 14), m / (cible if cible > 0 else 480.0), V.MINUTES)
		var texte := "%s / %s" % [G.n(int(m)), G.n(int(cible))] if cible > 0 else "%s min" % G.n(int(m))
		V.chiffre(c, zone.size.x - 18, 232, texte, 22, V.MINUTES, 128, HORIZONTAL_ALIGNMENT_RIGHT)
	return c

## Tuile de réglage : pictogramme, intitulé court, valeur en grand de sa couleur, coût éventuel ; clic = `action`.
static func tuile_reglage(parent: Control, zone: Rect2, titre: String, valeur: String, icone_id: String, teinte: Color, action: Callable, id: String, cout: String = "", actif: bool = true) -> Panel:
	var c := V.carte(parent, zone, teinte, id)
	V.icone(c, Rect2(18, 18, 38, 38), icone_id, teinte if actif else Charte.IVOIRE_3)
	V.petit(c, 68, 46, titre.to_upper(), 18, Charte.IVOIRE_2, zone.size.x - 80)
	var t := V.chiffre(c, 18, zone.size.y - (58 if not cout.is_empty() else 30), valeur, 40, teinte if actif else Charte.IVOIRE_3, zone.size.x - 30)
	D.fit_title(t, zone.size.x - 30, 90, 2, 24)
	if not cout.is_empty():
		D.rect(c, Rect2(18, zone.size.y - 46, zone.size.x - 36, 32), Charte.PANNEAU_3.lerp(V.DEPENSE, .18), Charte.RAYON_PILULE)
		V.chiffre(c, zone.size.x / 2.0, zone.size.y - 22, cout, 22, V.DEPENSE if actif else Charte.IVOIRE_3, zone.size.x - 40, HORIZONTAL_ALIGNMENT_CENTER)
	if actif and action.is_valid(): Pieces.rendre_cliquable(c, zone.size, action, id + "Lien", titre, "", Charte.RAYON_CARTE)
	else: c.modulate = Color(1, 1, 1, .6)
	return c

static func _libelle(options: Array, valeur: String) -> Array:
	for o: Array in options:
		if str(o[0]) == valeur: return o
	return options[0]

const MODES := [["equilibre", "Équilibré", "target", Charte.MORAL], ["performance", "Performance", "trophy", Charte.INTENSIF], ["developpement", "Développement", "rating", Charte.CONFIANCE], ["repos", "Repos", "heart", Charte.REPOS]]
const OBJECTIFS := [["formation", "2 objectifs", "target", Charte.GAIN], ["promotions", "2 promotions", "trophy", Charte.INTENSIF], ["prets", "1 prêt · 200 min", "bus", Charte.MORAL]]
const IDENTITES := [["polyvalence", "Polyvalence", "renew", Charte.MORAL], ["mouvement", "Mouvement", "arrow", Charte.REPOS], ["puissance", "Puissance", "shield", Charte.PERTE], ["defense", "Défense", "lock", Charte.CONFIANCE]]

# --- Onglet Centre --------------------------------------------------------------------------------------------------

static func _centre(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var cadre := Control.new()
	cadre.name = "CentreVisuelA"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.racine.add_child(cadre)
	D.place(cadre, zone)
	var L := zone.size.x
	# Rangée 1 : les Espoirs à suivre (objectifs en cours puis meilleurs potentiels) + le pouls du centre.
	var pouls := 560.0
	var vitrine := L - pouls - ECART
	var joueurs: Array = data.get("players", []).duplicate()
	joueurs.sort_custom(_ordre)
	var n := mini(joueurs.size(), floori((vitrine + ECART) / (CARTE.x + ECART)))
	var w := (vitrine - ECART * (n - 1)) / maxf(1, n)
	for i in n:
		var p: Dictionary = joueurs[i]
		var pid := str(p.id)
		carte_espoir(ctx, cadre, Rect2(i * (w + ECART), 0, w, CARTE.y), p, "CentreVisuelJoueur%d" % i, func(): V.fenetre_parcours(ctx, pid))
	var bloc := V.carte(cadre, Rect2(L - pouls, 0, pouls, CARTE.y), Color.TRANSPARENT, "CVAPouls")
	var anneaux := [[float(data.get("cohesion", 0)), "Cohésion", V.COHESION, "heart"], [float(data.get("reputation", 0)), "Réputation", V.REPUTATION, "star"]]
	for i in anneaux.size():
		var a: Array = anneaux[i]
		var j := JaugeAnneau.new(a[0], a[1], a[2], 100.0, a[3])
		j.diametre = 150.0
		j.name = "CVAAnneau_" + str(a[1]).validate_node_name()
		bloc.add_child(j)
		D.place(j, Rect2(20 + i * 270, 18, 250, 216))
	# Rangée 2 : les réglages du centre en tuiles (clic = petite fenêtre de tuiles).
	var y := CARTE.y + 26
	var reglages := 7
	var wt := (L - ECART * (reglages - 1)) / reglages
	var ht := 236.0
	var verrou: bool = data.get("locked", false)
	var scout := Academy.cost(data, "scout", 35000)
	var faite: bool = data.get("nextScouted", false)
	tuile_reglage(cadre, Rect2(0, y, wt, ht), "Détection", "Faite" if faite else "À lancer", "search", V.PROGRES if faite else V.DEPENSE, func(): V.envoyer(ctx, "academy_scout", {}, scout, "Détection annuelle"), "CVADetection", G.euros(scout), not verrou and not faite)
	var mode := _libelle(MODES, str(data.get("mode", "")))
	tuile_reglage(cadre, Rect2(1 * (wt + ECART), y, wt, ht), "Rencontres", str(mode[1]), str(mode[2]), mode[3], func(): V.fenetre_choix(ctx, "CVAModeFenetre", "Plan des rencontres", "calendar", MODES, data.get("mode"), func(v: Variant): V.envoyer(ctx, "academy_mode", {"mode": v})), "CVAMode", "", not verrou)
	var but := _libelle(OBJECTIFS, str(data.get("goal", "")))
	tuile_reglage(cadre, Rect2(2 * (wt + ECART), y, wt, ht), "Objectif annuel", str(but[1]), str(but[2]), but[3], func(): V.fenetre_choix(ctx, "CVAObjectifFenetre", "Objectif annuel", "target", OBJECTIFS, data.get("goal"), func(v: Variant): V.envoyer(ctx, "academy_goal", {"goal": v})), "CVAObjectif", "", not verrou)
	var ident := _libelle(IDENTITES, str(data.get("identity", "")))
	tuile_reglage(cadre, Rect2(3 * (wt + ECART), y, wt, ht), "Identité", str(ident[1]), str(ident[2]), ident[3], func(): V.fenetre_choix(ctx, "CVAIdentiteFenetre", "Identité de formation", "shield", IDENTITES, data.get("identity"), func(v: Variant): V.envoyer(ctx, "academy_identity", {"identity": v})), "CVAIdentite", "", not verrou)
	for k in 2:
		var kind := "facilities" if k == 0 else "coaches"
		var niveau := int(data.get(kind, 0))
		var prix := Academy.cost(data, kind, (niveau + 1) * (85000 if k == 0 else 55000), niveau) if niveau < 3 else 0
		var titre := "Installations" if k == 0 else "Éducateurs"
		var t := tuile_reglage(cadre, Rect2((4 + k) * (wt + ECART), y, wt, ht), titre, "%d / 3" % niveau, "home" if k == 0 else "people", V.PROGRES, func(): V.envoyer(ctx, "academy_upgrade", {"kind": kind}, prix, titre), "CVA" + kind.capitalize(), G.euros(prix) if niveau < 3 else "", not verrou and niveau < 3)
		V.crans(t, 128, ht - 112, niveau, 3, V.PROGRES, 40, 14)
	var reunion := Academy.cost(data, "meeting", 2000)
	tuile_reglage(cadre, Rect2(6 * (wt + ECART), y, wt, ht), "Réunion", "Cohésion", "people", V.COHESION, func(): V.envoyer(ctx, "academy_meeting", {}, reunion, "Réunion de cohésion"), "CVAReunion", G.euros(reunion), not verrou)
	# Rangée 3 : la saison junior (frise des périodes, scores) et les chiffres du centre.
	y += ht + 26
	var hs := zone.size.y - y
	var saison := V.carte(cadre, Rect2(0, y, L * .62, hs), Color.TRANSPARENT, "CVASaison")
	V.icone(saison, Rect2(18, 18, 32, 32), "trophy", V.MINUTES)
	V.petit(saison, 60, 44, "SAISON JUNIOR", 20, Charte.IVOIRE_2, 300)
	var ronde := int(data.get("juniorRound", 0))
	var total := maxi(1, int(data.get("totalRounds", 26)))
	V.chiffre(saison, L * .62 - 20, 52, "%d / %d" % [ronde, total], 40, V.MINUTES, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	var wc := (L * .62 - 36 - (total - 1) * 4) / total
	for i in total:
		var fait := i < ronde
		D.rect(saison, Rect2(18 + i * (wc + 4), 68, wc, 18), Color(V.MINUTES, .85) if fait else Charte.PANNEAU_3, 4)
	var resultats: Array = data.get("results", []).duplicate()
	resultats.reverse()
	var club := int(data.get("clubId", -1))
	var nr := mini(resultats.size(), 6)
	var wr := (L * .62 - 36 - (nr - 1) * 12) / maxf(1, nr)
	for i in nr:
		var r: Dictionary = resultats[i]
		var nous_domicile := int(r.get("home", -1)) == club
		var a := int(r.score[0])
		var b := int(r.score[1])
		var pour := a if nous_domicile else b
		var contre := b if nous_domicile else a
		var teinte := V.PROGRES if pour > contre else (V.ALERTE if pour < contre else Charte.IVOIRE_2)
		var case_r := V.carte(saison, Rect2(18 + i * (wr + 12), 104, wr, hs - 122), teinte, "CVAResultat%d" % i)
		V.chiffre(case_r, 14, 46, "V" if pour > contre else ("D" if pour < contre else "N"), 36, teinte, 40)
		V.petit(case_r, wr - 14, 40, "P%d" % (int(r.get("round", 0)) + 1), 17, Charte.IVOIRE_3, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		V.chiffre(case_r, wr / 2.0, 104, "%d – %d" % [pour, contre], 38, Charte.IVOIRE, wr - 16, HORIZONTAL_ALIGNMENT_CENTER)
		var adv := str(r.get("awayCenter") if nous_domicile else r.get("homeCenter"))
		V.petit(case_r, wr / 2.0, 134, adv, 15, Charte.IVOIRE_2, wr - 16, HORIZONTAL_ALIGNMENT_CENTER)
	Pieces.rendre_cliquable(saison, Vector2(L * .62, hs), func(): Juniors.ouvrir(ctx.app, ctx.page), "CVASaisonLien", "Saison junior", "", Charte.RAYON_CARTE)
	var xr := L * .62 + ECART
	var wf := (L - xr - ECART) / 2.0
	var hf := (hs - ECART) / 2.0
	var faits := [
		[G.n(data.get("players", []).size()), "Espoirs", "people", V.PROGRES, func(): ctx.state.tab = "Parcours"; (ctx.reconstruire as Callable).call()],
		[G.n(data.get("places", 0)), "Places pro", "shield", V.REPUTATION, func(): ctx.app._navigate("Effectif")],
		[G.euros(data.get("recruitBudget", 0)), "Enveloppe junior", "money", V.DEPENSE, func(): ctx.app._navigate("Finances")],
		[G.n(data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size()), "Centres observés", "search", V.MINUTES, func(): ctx.state.tab = "Centres"; (ctx.reconstruire as Callable).call()],
	]
	for i in faits.size():
		var f: Array = faits[i]
		var r := Rect2(xr + (i % 2) * (wf + ECART), y + floori(i / 2.0) * (hf + ECART), wf, hf)
		var t := V.carte(cadre, r, f[3], "CVAFait%d" % i)
		V.icone(t, Rect2(18, 18, 30, 30), str(f[2]), f[3])
		V.petit(t, 58, 42, str(f[1]).to_upper(), 18, Charte.IVOIRE_2, wf - 70)
		V.chiffre(t, 18, hf - 22, f[0], 54, f[3], wf - 30)
		Pieces.rendre_cliquable(t, r.size, f[4], "CVAFait%dLien" % i, str(f[1]), "", Charte.RAYON_CARTE)

## Objectifs en cours d'abord, puis potentiel décroissant.
static func _ordre(a: Dictionary, b: Dictionary) -> bool:
	var ta := float(a.get("target", 0)) > 0
	var tb := float(b.get("target", 0)) > 0
	if ta != tb: return ta
	return V.valeur(a, "potential") > V.valeur(b, "potential")

# --- Onglet Parcours ------------------------------------------------------------------------------------------------

const FILTRES := [["all", "Tous", "people"], ["young", "20 ans et moins", "school"], ["minutes", "Moins de 240 min", "clock"], ["ready", "20 ans et plus", "trophy"]]

static func _garde(filtre: String, p: Dictionary) -> bool:
	match filtre:
		"young": return int(p.age) <= 20
		"minutes": return int(p.minutes) < 240
		"ready": return int(p.age) >= 20
	return true

static func _parcours(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var tous: Array = data.get("players", [])
	var filtre := str(ctx.state.get("filtre_a", "all"))
	var barre := Control.new()
	barre.name = "CVAFiltres"
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.racine.add_child(barre)
	D.place(barre, Rect2(zone.position, Vector2(zone.size.x, 44)))
	var x := 0.0
	for f: Array in FILTRES:
		var valeur := str(f[0])
		var n := tous.filter(func(p: Dictionary): return _garde(valeur, p)).size()
		var choisi := valeur == filtre
		var texte := "%s   %d" % [f[1], n]
		var fond := Charte.CREME if choisi else Charte.PANNEAU_3
		x += Pieces.pastille(barre, x, 4, texte, str(f[2]), "CVAFiltre_" + valeur, "", Charte.PANNEAU if choisi else Charte.IVOIRE, fond, func():
			ctx.state.filtre_a = valeur
			(ctx.reconstruire as Callable).call()) + 10
	# Compteurs par trajectoire, à droite (clic = rien de plus à ouvrir : forme neutre).
	var xd := zone.size.x
	for i in range(V.TRAJECTOIRES.size() - 1, -1, -1):
		var t: Array = V.TRAJECTOIRES[i]
		var n := tous.filter(func(p: Dictionary): return str(p.path) == str(t[0])).size()
		var texte := "%s  %d" % [t[1], n]
		xd -= Pieces.largeur_pastille(texte, str(t[2])) + 10
		Pieces.pastille(barre, xd, 4, texte, str(t[2]), "CVATrajectoire_" + str(t[0]), "", t[3])
	var joueurs: Array = tous.filter(func(p: Dictionary): return _garde(filtre, p))
	joueurs.sort_custom(_ordre)
	var par_ligne := floori((zone.size.x - 18 + ECART) / (CARTE.x + ECART))
	var w := (zone.size.x - 18 - ECART * (par_ligne - 1)) / par_ligne
	var lignes := ceili(joueurs.size() / float(par_ligne))
	var contenu := V.zone_defilante(ctx, Rect2(zone.position.x, zone.position.y + 58, zone.size.x, zone.size.y - 58), lignes * (CARTE.y + ECART), "CVAParcoursDefile")
	for i in joueurs.size():
		var p: Dictionary = joueurs[i]
		var pid := str(p.id)
		carte_espoir(ctx, contenu, Rect2((i % par_ligne) * (w + ECART), floori(i / float(par_ligne)) * (CARTE.y + ECART), w, CARTE.y), p, "CentreVisuelJoueur%d" % i, func(): V.fenetre_parcours(ctx, pid))

# --- Onglet Centres -------------------------------------------------------------------------------------------------

static func _initiales(nom: String) -> String:
	var mots := nom.split(" ", false)
	var s := ""
	for m: String in mots:
		if m.length() > 0 and m[0] == m[0].to_upper() and s.length() < 3: s += m[0]
	return s if not s.is_empty() else "XV"

static func _centres(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var world: bool = data.get("world", false)
	var verrou: bool = data.get("locked", false)
	var observe := Academy.cost(data, "centerScout", 1200)
	var centres: Array = data.get("centers", []).filter(func(c: Dictionary): return not c.get("own", false) and (not world or c.scouted or c.count > 15))
	var vus: Array = centres.filter(func(c: Dictionary): return c.scouted)
	var autres: Array = centres.filter(func(c: Dictionary): return not c.scouted)
	autres.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.count) > int(b.count))
	var L := zone.size.x - 18
	var h_vu := 300.0
	var par_ligne := 5
	var wc := (L - ECART * (par_ligne - 1)) / par_ligne
	var hc := 150.0
	var hauteur := vus.size() * (h_vu + ECART) + ceili(autres.size() / float(par_ligne)) * (hc + ECART)
	var contenu := V.zone_defilante(ctx, zone, hauteur, "CVACentresDefile")
	var y := 0.0
	for c: Dictionary in vus:
		var bloc := V.carte(contenu, Rect2(0, y, L, h_vu), V.MINUTES, "CVACentre_" + str(c.id).validate_node_name())
		_blason(bloc, Rect2(20, 20, 72, 72), str(c.name), V.MINUTES)
		var titre := V.chiffre(bloc, 108, 58, str(c.name), 34, Charte.IVOIRE, 520)
		titre.add_theme_font_override("font", C.EXTRA_BOLD)
		V.chiffre(bloc, 108, 98, "%s jeunes" % G.n(c.count), 26, V.MINUTES, 300)
		Pieces.pastille(bloc, 20, 120, "Observé", "check", "", "", V.PROGRES)
		var cand: Array = c.get("candidates", [])
		var wk := (L - 660 - ECART * (maxi(1, cand.size()) - 1)) / maxf(1, cand.size())
		wk = minf(wk, 330)
		for k in cand.size():
			var p: Dictionary = cand[k]
			var fee := int(p.get("fee", 0))
			var pid := str(p.id)
			var cz := Rect2(640 + k * (wk + ECART), 18, wk, h_vu - 36)
			var ck := V.carte(bloc, cz, V.couleur(V.valeur(p, "potential")), "CVACandidat_" + pid.validate_node_name())
			Pieces.rendre_cliquable(ck, cz.size, func(): V.envoyer(ctx, "academy_recruit", {"playerId": pid, "offer": fee}, fee, "Recruter " + str(p.name)), "CVACandidat%dLien" % k, str(p.name), "", Charte.RAYON_CARTE)
			V.portrait(ctx, ck, Rect2((wk - 84) / 2.0, 14, 84, 84), p, Color.TRANSPARENT, 3, "")
			V.petit(ck, wk / 2.0, 124, str(p.name), 19, Charte.IVOIRE, wk - 16, HORIZONTAL_ALIGNMENT_CENTER)
			V.petit(ck, wk / 2.0, 146, str(p.pos), 15, Charte.IVOIRE_2, wk - 16, HORIZONTAL_ALIGNMENT_CENTER)
			V.chiffre(ck, wk / 2.0, 196, V.potentiel_txt(p), 40, V.couleur(V.valeur(p, "potential")), wk - 16, HORIZONTAL_ALIGNMENT_CENTER)
			D.rect(ck, Rect2(12, cz.size.y - 44, wk - 24, 32), Charte.PANNEAU_3.lerp(V.DEPENSE, .18), Charte.RAYON_PILULE)
			V.chiffre(ck, wk / 2.0, cz.size.y - 20, G.euros(fee), 21, V.DEPENSE, wk - 30, HORIZONTAL_ALIGNMENT_CENTER)
		y += h_vu + ECART
	for i in autres.size():
		var c: Dictionary = autres[i]
		var r := Rect2((i % par_ligne) * (wc + ECART), y + floori(i / float(par_ligne)) * (hc + ECART), wc, hc)
		var teinte: Color = COULEURS[i % COULEURS.size()]
		var bloc := V.carte(contenu, r, Color.TRANSPARENT, "CVACentre_" + str(c.id).validate_node_name())
		_blason(bloc, Rect2(16, 16, 56, 56), str(c.name), teinte)
		var nom := V.petit(bloc, 84, 40, str(c.name), 20, Charte.IVOIRE, wc - 96)
		nom.add_theme_font_override("font", C.EXTRA_BOLD)
		V.chiffre(bloc, 84, 72, G.n(c.count), 30, teinte, 80)
		V.petit(bloc, 136, 70, "JEUNES", 15, Charte.IVOIRE_3, 100)
		var cid := str(c.id)
		var bouton := Rect2(16, hc - 52, wc - 32, 38)
		D.rect(bloc, bouton, Charte.PANNEAU_3.lerp(V.DEPENSE, .2), Charte.RAYON_PILULE)
		V.icone(bloc, Rect2(30, hc - 44, 22, 22), "search", V.DEPENSE)
		V.chiffre(bloc, wc / 2.0 + 12, hc - 24, G.euros(observe), 22, V.DEPENSE, wc - 90, HORIZONTAL_ALIGNMENT_CENTER)
		if not verrou and int(c.count) > 15:
			Pieces.rendre_cliquable(bloc, r.size, func(): V.envoyer(ctx, "academy_center_scout", {"centerId": cid}, observe, "Observer " + str(c.name)), "CVACentre%dLien" % i, str(c.name), "", Charte.RAYON_CARTE)

static func _blason(parent: Control, zone: Rect2, nom: String, teinte: Color) -> void:
	var rond := D.rect(parent, zone, Charte.PANNEAU_3.lerp(teinte, .35), 999, teinte)
	(rond.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	V.chiffre(rond, zone.size.x / 2.0, zone.size.y / 2.0 + zone.size.y * .17, _initiales(nom), int(zone.size.y * .4), Charte.IVOIRE, zone.size.x - 6, HORIZONTAL_ALIGNMENT_CENTER)

# --- Onglet Filières ------------------------------------------------------------------------------------------------

static func _filieres(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var verrou: bool = data.get("locked", false)
	var L := zone.size.x - 18
	var regions: Array = data.get("regions", [])
	var feeders: Array = data.get("feeders", [])
	var prospects: Array = data.get("prospects", []).duplicate()
	prospects.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.scouted) != int(b.scouted): return int(a.scouted) > int(b.scouted)
		return V.valeur(a, "potential") > V.valeur(b, "potential"))
	var par_ligne := 6
	var wp := (L - ECART * (par_ligne - 1)) / par_ligne
	var hp := 300.0
	var h_reg := 150.0
	var h_fee := 64.0
	var lignes_fee := ceili(feeders.size() / 4.0)
	var y_pros := h_reg + ECART + lignes_fee * (h_fee + 10) + 16
	var contenu := V.zone_defilante(ctx, zone, y_pros + ceili(prospects.size() / float(par_ligne)) * (hp + ECART), "CVAFilieresDefile")
	# Régions : six tuiles de couleur, clic = détecter dans la région.
	var discover := Academy.cost(data, "discover", 3000)
	var wr := (L - ECART * (maxi(1, regions.size()) - 1)) / maxf(1, regions.size())
	for i in regions.size():
		var region := str(regions[i])
		var teinte: Color = COULEURS[i % COULEURS.size()]
		var n := prospects.filter(func(p: Dictionary): return str(p.region) == region).size()
		var t := tuile_reglage(contenu, Rect2(i * (wr + ECART), 0, wr, h_reg), region, G.n(n), "globe", teinte, func(): V.envoyer(ctx, "academy_discover", {"region": region}, discover, "Détecter · " + region), "CVARegion%d" % i, G.euros(discover), not verrou)
		t.name = "CVARegion%d" % i
	# Clubs formateurs en pilules (partenaire coché).
	var partenaires: Array = data.get("partners", [])
	var partner := Academy.cost(data, "partner", 2000)
	var wf := (L - 10 * 3) / 4.0
	for i in feeders.size():
		var f: Dictionary = feeders[i]
		var fid := str(f.id)
		var ok := partenaires.has(fid)
		var teinte := V.PROGRES if ok else Charte.IVOIRE_2
		var r := Rect2((i % 4) * (wf + 10), h_reg + ECART + floori(i / 4.0) * (h_fee + 10), wf, h_fee)
		var pill := D.rect(contenu, r, Charte.PANNEAU_3.lerp(V.PROGRES, .22) if ok else Charte.PANNEAU_2, Charte.RAYON_PILULE)
		pill.name = "CVAFormateur_" + fid.validate_node_name()
		V.icone(pill, Rect2(18, 18, 28, 28), "check" if ok else "flag", teinte)
		V.petit(pill, 58, 30, str(f.name), 19, Charte.IVOIRE, wf - 200)
		V.petit(pill, 58, 52, str(f.region), 14, Charte.IVOIRE_3, wf - 200)
		V.chiffre(pill, wf - 22, 42, "Partenaire" if ok else G.euros(partner), 22, V.PROGRES if ok else V.DEPENSE, 150, HORIZONTAL_ALIGNMENT_RIGHT)
		if not ok and not verrou:
			Pieces.rendre_cliquable(pill, r.size, func(): V.envoyer(ctx, "academy_partner", {"feederId": fid}, partner, "Partenariat · " + str(f.name)), pill.name + "Lien", str(f.name), "", Charte.RAYON_PILULE)
	# Jeunes repérés : cartes (visage, potentiel, observations en crans, essai) ; clic = petite fenêtre d'actions.
	for i in prospects.size():
		var p: Dictionary = prospects[i]
		var r := Rect2((i % par_ligne) * (wp + ECART), y_pros + floori(i / float(par_ligne)) * (hp + ECART), wp, hp)
		var pt := V.valeur(p, "potential")
		var c := V.carte(contenu, r, V.couleur(pt) if int(p.scouted) > 0 else Color.TRANSPARENT, "CVAProspect_" + str(p.id).validate_node_name())
		var pid := str(p.id)
		Pieces.rendre_cliquable(c, r.size, func(): _fenetre_prospect(ctx, pid), "CVAProspect%dLien" % i, str(p.name), "", Charte.RAYON_CARTE)
		V.portrait(ctx, c, Rect2(16, 16, 80, 80), p, V.couleur(pt) if int(p.scouted) > 0 else Color.TRANSPARENT, 3, "")
		var nom := V.petit(c, 108, 42, str(p.name), 20, Charte.IVOIRE, wp - 118)
		nom.add_theme_font_override("font", C.EXTRA_BOLD)
		V.petit(c, 108, 66, "%s · %s ans" % [p.pos, G.n(p.age)], 15, Charte.IVOIRE_2, wp - 118)
		V.petit(c, 108, 88, str(p.clubName), 14, Charte.IVOIRE_3, wp - 118)
		V.chiffre(c, 16, 168, V.potentiel_txt(p), 48, V.couleur(pt), wp - 30)
		V.petit(c, 16, 188, "POTENTIEL", 14, Charte.IVOIRE_3, 140)
		V.crans(c, 16, 214, int(p.scouted), 3, V.MINUTES, 42, 12)
		V.petit(c, 166, 226, "%d / 3" % int(p.scouted), 16, V.MINUTES, 80)
		var essai: bool = p.get("trial", false)
		Pieces.pastille(c, 16, hp - 54, "Essai" if essai else "Sans essai", "check" if essai else "hourglass", "", "", V.PROGRES if essai else Charte.IVOIRE_3)

static func _fenetre_prospect(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var p: Dictionary = {}
	for x: Dictionary in data.get("prospects", []):
		if str(x.id) == id: p = x
	if p.is_empty(): return
	var home := str(data.get("homeUnion", "FR"))
	var opts: Array = [
		["watch", "Observer", "search", V.MINUTES, G.euros(500), int(p.scouted) < 3],
		["trial", "Essai", "train", V.PROGRES, G.euros(1000), not p.trial and int(p.scouted) > 0],
	]
	if str(p.union) != home: opts.append(["clearance", "Autorisation", "flag", V.COHESION, "", int(p.age) >= 18 and p.trial and not p.get("clearanceRecorded", false)])
	opts.append(["recruit", "Proposer", "trophy", V.DEPENSE, G.euros(8000), int(p.scouted) >= 2 and p.trial and int(p.age) >= 16])
	V.fenetre_choix(ctx, "CVAProspectFenetre", str(p.name), "search", opts, null, func(v: Variant):
		match str(v):
			"watch": V.envoyer(ctx, "academy_watch", {"playerId": id}, 500, "Observer")
			"trial": V.envoyer(ctx, "academy_trial", {"playerId": id}, 1000, "Essai")
			"clearance": V.envoyer(ctx, "academy_clearance", {"playerId": id})
			"recruit": V.envoyer(ctx, "academy_feeder_recruit", {"playerId": id}, 8000, "Proposer le projet"))

# --- Onglet Passerelle pro ------------------------------------------------------------------------------------------

static func _passerelle(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var L := zone.size.x - 18
	var jeunes: Array = data.get("seniors", []).filter(func(s: Dictionary): return int(s.age) <= 23 or s.get("loanEligible", false))
	jeunes.sort_custom(func(a: Dictionary, b: Dictionary):
		if bool(a.get("loanEligible", false)) != bool(b.get("loanEligible", false)): return a.get("loanEligible", false)
		return int(a.age) < int(b.age))
	var prets: Array = data.get("loans", [])
	var par_ligne := floori((L + ECART) / (CARTE.x + ECART))
	var w := (L - ECART * (par_ligne - 1)) / par_ligne
	var h_tuiles := 150.0
	var lignes := ceili(jeunes.size() / float(par_ligne))
	var y_prets := h_tuiles + ECART + 40 + lignes * (CARTE.y + ECART) + 10
	var contenu := V.zone_defilante(ctx, zone, y_prets + 40 + ceili(prets.size() / float(par_ligne)) * (CARTE.y + ECART), "CVAPasserelleDefile")
	var eligibles := jeunes.filter(func(s: Dictionary): return s.get("loanEligible", false)).size()
	var tuiles := [[G.n(jeunes.size()), "Jeunes pros", "people", V.PROGRES], [G.n(eligibles), "Prêtables", "bus", V.MINUTES], [G.n(prets.size()), "En prêt", "globe", V.REPUTATION], [G.n(data.get("places", 0)), "Places pro", "shield", V.COHESION]]
	var wt := (L - ECART * 3) / 4.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		var c := V.carte(contenu, Rect2(i * (wt + ECART), 0, wt, h_tuiles), t[3], "CVAPasserelleTuile%d" % i)
		V.icone(c, Rect2(18, 18, 32, 32), str(t[2]), t[3])
		V.petit(c, 62, 44, str(t[1]).to_upper(), 19, Charte.IVOIRE_2, wt - 80)
		V.chiffre(c, 18, h_tuiles - 22, t[0], 62, t[3], wt - 30)
	V.petit(contenu, 0, h_tuiles + ECART + 28, "JEUNES PROFESSIONNELS", 20, Charte.IVOIRE_2, 600)
	for i in jeunes.size():
		var s: Dictionary = jeunes[i]
		var sid := str(s.id)
		var ok: bool = s.get("loanEligible", false)
		var r := Rect2((i % par_ligne) * (w + ECART), h_tuiles + ECART + 40 + floori(i / float(par_ligne)) * (CARTE.y + ECART), w, CARTE.y)
		var action := func():
			if ok:
				_fenetre_pret(ctx, sid)
				return
			ctx.app.selected_player = sid
			ctx.app.navigation_controller.open_entity({"kind": "player", "id": sid, "section": ""})
		var s2 := s.duplicate()
		s2.path = "minutes" if ok else "equilibre"
		var c := carte_espoir(ctx, contenu, r, s2, "CVAJeunePro%d" % i, action, "squad", false)
		if not ok: Pieces.pastille(c, w - 150, 18, "Effectif", "lock", "", "", Charte.IVOIRE_3)
		else: Pieces.pastille(c, w - 130, 18, "Prêt", "bus", "", "", V.MINUTES)
	V.petit(contenu, 0, y_prets + 28, "EN PRÊT", 20, Charte.IVOIRE_2, 600)
	for i in prets.size():
		var pr: Dictionary = prets[i]
		var hote := "club %d" % int(pr.to)
		for cl: Dictionary in data.get("loanClubs", []):
			if int(cl.id) == int(pr.to): hote = str(cl.name)
		var r := Rect2((i % par_ligne) * (w + ECART), y_prets + 40 + floori(i / float(par_ligne)) * (CARTE.y + ECART), w, CARTE.y)
		var c := V.carte(contenu, r, V.REPUTATION, "CVAPret%d" % i)
		V.icone(c, Rect2(18, 18, 36, 36), "bus", V.REPUTATION)
		V.chiffre(c, 18, 110, str(pr.get("name", "")), 30, Charte.IVOIRE, w - 30)
		V.chiffre(c, 18, 170, hote, 26, V.REPUTATION, w - 30)

static func _fenetre_pret(ctx: Dictionary, id: String) -> void:
	var data: Dictionary = ctx.data
	var clubs: Array = data.get("loanClubs", []).duplicate()
	clubs.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.name) < str(b.name))
	var L := 1500.0
	var H := 900.0
	var fond := Fenetre.ouvrir(ctx.page, "CVAPretFenetre", "Club d’accueil", "bus", L, H)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fond.add_child(defile)
	D.place(defile, Rect2(24, 80, L - 48, H - 104))
	var par_ligne := 4
	var w := (L - 48 - 18 - 10 * (par_ligne - 1)) / par_ligne
	var contenu := Control.new()
	contenu.custom_minimum_size = Vector2(L - 66, ceili(clubs.size() / float(par_ligne)) * 70) * C.density
	defile.add_child(contenu)
	for i in clubs.size():
		var cl: Dictionary = clubs[i]
		var to := int(cl.id)
		var r := Rect2((i % par_ligne) * (w + 10), floori(i / float(par_ligne)) * 70, w, 60)
		var t := V.carte(contenu, r, COULEURS[i % COULEURS.size()], "CVAPretClub%d" % to)
		_blason(t, Rect2(10, 8, 44, 44), str(cl.name), COULEURS[i % COULEURS.size()])
		V.petit(t, 66, 38, str(cl.name), 19, Charte.IVOIRE, w - 76)
		Pieces.rendre_cliquable(t, r.size, func():
			Fenetre.fermer(ctx.page, "CVAPretFenetre")
			V.envoyer(ctx, "academy_loan", {"playerId": id, "to": to}, 0, "Confirmer le prêt"), "CVAPretClub%dLien" % to, str(cl.name), "", Charte.RAYON_CARTE)

# --- Onglet Générations ---------------------------------------------------------------------------------------------

static func _generations(ctx: Dictionary, zone: Rect2) -> void:
	var data: Dictionary = ctx.data
	var gens: Array = data.get("generations", []).duplicate()
	gens.reverse()
	var L := zone.size.x - 18
	var par_ligne := floori((L + ECART) / (CARTE.x + ECART))
	var w := (L - ECART * (par_ligne - 1)) / par_ligne
	var h_tete := 170.0
	var hauteur := 0.0
	for g: Dictionary in gens: hauteur += h_tete + 20 + ceili(g.players.size() / float(par_ligne)) * (CARTE.y + ECART) + 30
	if gens.is_empty(): hauteur = 300
	var contenu := V.zone_defilante(ctx, zone, hauteur, "CVAGenerationsDefile")
	if gens.is_empty():
		var c := V.carte(contenu, Rect2(0, 0, 420, 170), Charte.IVOIRE_2, "CVAGenerationsVide")
		V.icone(c, Rect2(18, 18, 32, 32), "trophy", Charte.IVOIRE_2)
		V.chiffre(c, 18, 140, "0", 70, Charte.IVOIRE_2, 200)
		return
	var y := 0.0
	for gi in gens.size():
		var g: Dictionary = gens[gi]
		var tete := V.carte(contenu, Rect2(0, y, L, h_tete), V.REPUTATION, "CVAGeneration%d" % gi)
		V.icone(tete, Rect2(22, 22, 40, 40), "trophy", V.REPUTATION)
		var titre := V.chiffre(tete, 76, 60, "GÉNÉRATION " + G.season_label(g.season), 44, Charte.IVOIRE, 760)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		var minutes := 0
		for p: Dictionary in g.players: minutes += int(p.get("minutes", 0))
		var faits := [[G.n(g.players.size()), "Joueurs", V.PROGRES], [G.n(g.get("graduates", 0)), "Promus", Charte.INTENSIF], [G.n(g.get("reputation", 0)), "Réputation", V.REPUTATION], [G.n(minutes), "Minutes", V.MINUTES]]
		for k in faits.size():
			var f: Array = faits[k]
			var x := L - (faits.size() - k) * 250.0
			V.chiffre(tete, x, 96, f[0], 62, f[2], 230)
			V.petit(tete, x, 134, str(f[1]).to_upper(), 18, Charte.IVOIRE_2, 230)
		var joueurs: Array = g.players.duplicate()
		joueurs.sort_custom(func(a: Dictionary, b: Dictionary): return V.valeur(a, "potential") > V.valeur(b, "potential"))
		y += h_tete + 20
		for i in joueurs.size():
			var p: Dictionary = joueurs[i]
			var pid := str(p.id)
			var r := Rect2((i % par_ligne) * (w + ECART), y + floori(i / float(par_ligne)) * (CARTE.y + ECART), w, CARTE.y)
			carte_espoir(ctx, contenu, r, p, "CVAGenJoueur%d_%d" % [gi, i], func():
				if not V.joueur(data, pid).is_empty(): V.fenetre_parcours(ctx, pid)
				else:
					ctx.app.selected_player = pid
					ctx.app.navigation_controller.open_entity({"kind": "player", "id": pid, "section": ""}), "academy", true)
		y += ceili(joueurs.size() / float(par_ligne)) * (CARTE.y + ECART) + 30
