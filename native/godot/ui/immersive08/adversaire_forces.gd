extends RefCounted
## Points forts / points faibles de l'adversaire (revue FM27, idée 29) — PLANCHE A/B sous CD_VARIANTE_VISUELLE, rien
## sans variante. En tête de la sous-page « Rapport adverse » de la Préparation (rapport #1183, dessous inchangé).
## A : deux colonnes de lignes à icône (forts en vert, faibles en rouge) + colonne « hommes clés » (meilleure note,
##     meilleur marqueur, meilleur plaqueur) et l'entraîneur.
## B : bandeau entraîneur + pastilles vertes / rouges sur deux rangées, puis joueurs clés en liste façon Effectif.
## Tout vient de données réelles : fiche du club (club-sheet.cjs : bilan, essais détaillés, effectif et totaux de
## saison, entraîneur, stratégie) et l'avant-match (`clubLife.avantMatch.forces` : touche / mêlée en %).
## Seuils provisoires (à valider par Léo).

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Link = preload("res://ui/entity_link.gd")
const Notes = preload("res://ui/notes_match.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _n(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0

## Points relevés : [fort (true) / faible, icône, libellé, chiffre, détail (infobulle)].
static func points(page, donnees: Dictionary) -> Array:
	var out: Array = []
	var team: Dictionary = donnees.get("team", {}) if donnees.get("team") is Dictionary else {}
	var m := maxf(1.0, _n(team.get("matches")))
	if _n(team.get("matches")) >= 1:
		var em := _n(team.get("triesFor")) / m
		var ee := _n(team.get("triesAgainst")) / m
		if em >= 3.0: out.append([true, "ball", "Attaque prolifique", "%s essais/match" % _v(em), ""])
		elif em <= 1.5: out.append([false, "ball", "Attaque stérile", "%s essais/match" % _v(em), ""])
		if ee <= 1.5: out.append([true, "shield", "Défense hermétique", "%s encaissés/match" % _v(ee), ""])
		elif ee >= 3.0: out.append([false, "shield", "Défense poreuse", "%s encaissés/match" % _v(ee), ""])
	var essais: Array = donnees.get("rapport", {}).get("essais", []) if donnees.get("rapport") is Dictionary else []
	var pour := essais.filter(func(e): return e is Dictionary and bool(e.get("for", false)))
	var contre := essais.filter(func(e): return e is Dictionary and not bool(e.get("for", false)))
	if pour.size() >= 4:
		var porte := pour.filter(func(e): return str(e.get("origin", "")) == "b").size()
		if porte * 100 >= 30 * pour.size(): out.append([true, "people", "Ballon porté", "%d %% des essais" % roundi(100.0 * porte / pour.size()), ""])
		var fin := pour.filter(func(e): return int(_n(e.get("minute"))) >= 60).size()
		if fin * 100 >= 40 * pour.size(): out.append([true, "clock", "Finit fort", "%d %% après 60'" % roundi(100.0 * fin / pour.size()), ""])
		var loin := pour.filter(func(e): return int(_n(e.get("depth"))) > 50).size()
		if loin * 100 >= 25 * pour.size(): out.append([true, "arrow", "Contre-attaque", "%d %% de leur camp" % roundi(100.0 * loin / pour.size()), ""])
	if contre.size() >= 4:
		var fin_c := contre.filter(func(e): return int(_n(e.get("minute"))) >= 60).size()
		if fin_c * 100 >= 40 * contre.size(): out.append([false, "clock", "Craque en fin de match", "%d %% après 60'" % roundi(100.0 * fin_c / contre.size()), ""])
		var porte_c := contre.filter(func(e): return str(e.get("origin", "")) == "b").size()
		if porte_c * 100 >= 30 * contre.size(): out.append([false, "people", "Subit le ballon porté", "%d %% des essais" % roundi(100.0 * porte_c / contre.size()), ""])
	# Conquête (avant-match : moyennes de la saison, la leur).
	var am: Variant = page.app.model.get("clubLife", {}).get("avantMatch") if page.app.model.get("clubLife") is Dictionary else null
	if am is Dictionary and am.get("forces") is Dictionary:
		var equipes: Array = am.forces.get("equipes", [])
		var nous := 0 if page.fixture.get("home", {}).get("id") == page.app.model.club.get("id") else 1
		if equipes.size() == 2 and equipes[1 - nous] is Dictionary:
			var lui: Dictionary = equipes[1 - nous]
			for axe: Array in [["touches", "Touche"], ["melees", "Mêlée"]]:
				var v: Variant = lui.get(axe[0])
				if not (v is int or v is float): continue
				if v >= 90: out.append([true, "target", "%s solide" % axe[1], "%d %% gagnées" % roundi(v), ""])
				elif v <= 80: out.append([false, "target", "%s fragile" % axe[1], "%d %% gagnées" % roundi(v), ""])
	# Forme : 5 derniers résultats.
	var forme: Array = donnees.get("table", {}).get("form", []) if donnees.get("table") is Dictionary else []
	var v5 := forme.filter(func(x): return str(x) == "V").size()
	var d5 := forme.filter(func(x): return str(x) == "D").size()
	if forme.size() >= 3 and v5 >= 4: out.append([true, "trophy", "En confiance", "%d V sur %d" % [v5, forme.size()], ""])
	elif forme.size() >= 3 and d5 >= 3: out.append([false, "trophy", "En méforme", "%d D sur %d" % [d5, forme.size()], ""])
	# Absents parmi les titulaires habituels (blessés, suspendus).
	for j: Variant in donnees.get("squad", []):
		if j is Dictionary and int(_n(j.get("starts"))) >= 3 and (_n(j.get("injury")) > 0 or _n(j.get("suspension")) > 0):
			out.append([false, "heart" if _n(j.get("injury")) > 0 else "warning", "Absent : %s" % str(j.get("name", "")).split(" ")[-1], "%s · %d tit." % [str(j.get("pos", "")), int(_n(j.get("starts")))], str(j.get("id", ""))])
	return out

static func _v(x: float) -> String:
	return ("%.1f" % x).replace(".", ",")

## Hommes clés : [catégorie, icône, couleur, joueur, chiffre].
static func cles(donnees: Dictionary) -> Array:
	var squad: Array = donnees.get("squad", []).filter(func(j): return j is Dictionary)
	var out: Array = []
	var crit := [["Meilleure note", "star", R.ORANGE, func(j): return _n(j.get("average")) if _n(j.get("matches")) >= 2 else -1.0, func(j): return Notes.texte_note(_n(j.get("average")))],
		["Meilleur marqueur", "ball", R.VERT, func(j): return _n(j.get("tries")), func(j): return "%d essais" % int(_n(j.get("tries")))],
		["Meilleur plaqueur", "shield", R.VIOLET, func(j): return _n(j.get("tackles")), func(j): return "%d plaq." % int(_n(j.get("tackles")))]]
	for c: Array in crit:
		var best: Dictionary = {}
		var bv := 0.0
		for j: Dictionary in squad:
			var v: float = c[3].call(j)
			if v > bv:
				bv = v
				best = j
		if not best.is_empty(): out.append([c[0], c[1], c[2], best, c[4].call(best)])
	return out

# ---- Briques ---------------------------------------------------------------------------------------------------------

static func _portrait(parent: Control, zone: Rect2, joueur: Dictionary, bord: Color) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, bord)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var im: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, zone.size.y * .04, zone.size.x, zone.size.y * 1.12))

static func _survol(ligne: Panel) -> void:
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := (ligne.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var base := style.bg_color
	ligne.add_theme_stylebox_override("panel", style)
	ligne.mouse_entered.connect(func(): style.bg_color = Charte.SELECTION)
	ligne.mouse_exited.connect(func(): style.bg_color = base)

static func _ouvrir_joueur(page, id: String) -> void:
	if Link.available(page.app, "player", id): page.app.navigation_controller.open_entity({"kind": "player", "id": id})

## Clic sur un point : petite fenêtre visuelle (le point en grand, sa couleur, son chiffre ; un joueur → sa fiche).
static func _fenetre_point(page, p: Array) -> void:
	if not str(p[4]).is_empty():
		_ouvrir_joueur(page, str(p[4]))
		return
	var couleur: Color = R.VERT if p[0] else R.ROUGE
	var fond := Fenetre.ouvrir(page, "AdversaireForceFenetre", ("POINT FORT" if p[0] else "POINT FAIBLE"), "", 720, 300)
	var rond := D.rect(fond, Rect2(40, 100, 140, 140), Color(couleur, .2), 70, couleur)
	var ic := C.icon(str(p[1]), C.px(70), couleur)
	rond.add_child(ic)
	D.place(ic, Rect2(35, 35, 70, 70))
	D.text(fond, 210, 160, str(p[2]).to_upper(), 34, Charte.IVOIRE, 800, 470).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(fond, 210, 214, str(p[3]), 32, couleur, 800, 470)

# ---- Bloc ------------------------------------------------------------------------------------------------------------

## Dessine le bloc en haut de `section` (y = 66) ; rend sa hauteur (0 sans variante).
static func construire(page, section: Control, donnees: Dictionary) -> float:
	if variante().is_empty(): return 0.0
	var pts := points(page, donnees)
	var cl := cles(donnees)
	return _a(page, section, donnees, pts, cl) if variante() == "A" else _b(page, section, donnees, pts, cl)

static func _a(page, section: Control, donnees: Dictionary, pts: Array, cl: Array) -> float:
	var H := 360.0
	var y0 := 66.0
	var lw := 760.0
	for k in 2:
		var fort := k == 0
		var couleur: Color = R.VERT if fort else R.ROUGE
		var liste := pts.filter(func(p): return bool(p[0]) == fort)
		var panneau: Panel = page._panneau(section, Rect2(k * (lw + 16), y0, lw, H), "Points forts" if fort else "Points faibles", "AdversaireForces%s" % ("Forts" if fort else "Faibles"), "%d" % liste.size())
		D.text(panneau, lw - 90, 50, "▲" if fort else "▼", 30, couleur, 800, 40, HORIZONTAL_ALIGNMENT_CENTER)
		var y := 66.0
		var i := 0
		for p: Array in liste.slice(0, 5):
			var ligne := D.rect(panneau, Rect2(16, y, lw - 32, 52), Charte.PANNEAU_2 if i % 2 == 0 else Color.TRANSPARENT, 8)
			ligne.name = "AdversairePoint%s%d" % ["Fort" if fort else "Faible", i]
			_survol(ligne)
			var rond := D.rect(ligne, Rect2(10, 8, 36, 36), Color(couleur, .22), 18, couleur)
			var ic := C.icon(str(p[1]), C.px(20), couleur)
			rond.add_child(ic)
			D.place(ic, Rect2(8, 8, 20, 20))
			D.text(ligne, 62, 34, str(p[2]), 22, Charte.IVOIRE, 800, 380)
			D.text(ligne, lw - 48, 34, str(p[3]), 21, couleur, 800, 280, HORIZONTAL_ALIGNMENT_RIGHT)
			var pc: Array = p
			R.cliquable(ligne, func(): _fenetre_point(page, pc), ligne.name + "Lien", str(p[2])).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			y += 56.0
			i += 1
		if liste.is_empty(): D.text(panneau, 32, 110, "—", 26, Charte.IVOIRE_2, 800, 60)
	# Hommes clés + entraîneur.
	var x := 2 * (lw + 16)
	var w := 2248.0 - x
	var cles_p: Panel = page._panneau(section, Rect2(x, y0, w, H), "Hommes clés", "AdversaireCles")
	var y := 62.0
	var i := 0
	for c: Array in cl:
		var j: Dictionary = c[3]
		var ligne := D.rect(cles_p, Rect2(14, y, w - 28, 68), Charte.PANNEAU_2, 8)
		ligne.name = "AdversaireCle%d" % i
		_survol(ligne)
		_portrait(ligne, Rect2(8, 6, 56, 56), j, c[2])
		var ic := C.icon(str(c[1]), C.px(16), c[2])
		ligne.add_child(ic)
		D.place(ic, Rect2(76, 12, 16, 16))
		D.text(ligne, 98, 27, str(c[0]).to_upper(), 14, c[2], 800, w - 260)
		Link.name_link(page.app, ligne, Rect2(74, 30, w - 260, 34), "player", str(j.get("id", "")), str(j.get("name", "")), 19, Charte.IVOIRE, "AdversaireCleNom%d" % i)
		D.text(ligne, w - 44, 46, str(c[4]), 22, c[2], 800, 150, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 74.0
		i += 1
	var coach := str(donnees.get("coach")) if donnees.get("coach") is String else "—"
	var strat: String = load("res://ui/immersive08/club_sheet_canvas.gd")._strategy(donnees.get("strategy"))
	var cadre := D.rect(cles_p, Rect2(14, H - 66, w - 28, 54), Color(R.BLEU, .14), 8, Color(R.BLEU, .5))
	cadre.name = "AdversaireCoach"
	var ic2 := C.icon("people", C.px(20), R.BLEU)
	cadre.add_child(ic2)
	D.place(ic2, Rect2(12, 17, 20, 20))
	D.text(cadre, 42, 34, coach, 19, Charte.IVOIRE, 800, (w - 28) * .55)
	D.text(cadre, w - 44, 34, strat, 17, R.BLEU, 800, (w - 28) * .4, HORIZONTAL_ALIGNMENT_RIGHT)
	return H + 14.0

static func _b(page, section: Control, donnees: Dictionary, pts: Array, cl: Array) -> float:
	var H := 330.0
	var y0 := 66.0
	var fond: Panel = page._panneau(section, Rect2(0, y0, 2248, H), "Fiche de l'adversaire", "AdversaireFiche")
	# Bandeau : entraîneur et stratégie, à droite du titre.
	var coach := str(donnees.get("coach")) if donnees.get("coach") is String else "—"
	var strat: String = load("res://ui/immersive08/club_sheet_canvas.gd")._strategy(donnees.get("strategy"))
	var px := 2248.0 - 24.0 - (R.largeur(strat, 18) + 52)
	R.pastille(fond, px, 44, strat, R.BLEU, "flag", "AdversaireStrategie", 18)
	var pc := px - 12.0 - (R.largeur(coach, 18) + 52)
	R.pastille(fond, pc, 44, coach, Charte.IVOIRE_2, "people", "AdversaireCoach", 18)
	# Deux rangées de pastilles : forts puis faibles.
	for k in 2:
		var fort := k == 0
		var couleur: Color = R.VERT if fort else R.ROUGE
		var y := 108.0 + k * 62.0
		D.text(fond, 24, y + 4, "▲" if fort else "▼", 30, couleur, 800, 34)
		var x := 64.0
		var i := 0
		for p: Array in pts.filter(func(q): return bool(q[0]) == fort):
			var texte := "%s · %s" % [p[2], p[3]]
			var lw := R.largeur(texte, 22) + 60
			if x + lw > 2224: break
			var pa := R.pastille(fond, x, y, texte, couleur, str(p[1]), "AdversairePoint%s%d" % ["Fort" if fort else "Faible", i], 22)
			var pcopy: Array = p
			R.cliquable(pa, func(): _fenetre_point(page, pcopy), pa.name + "Lien", str(p[2])).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			x += lw + 12
			i += 1
		if i == 0: D.text(fond, x, y, "—", 22, Charte.IVOIRE_2, 800, 40)
	# Joueurs clés en liste (grammaire Effectif) : portrait, nom, poste, note, essais, plaquages, mètres, matchs.
	D.line(fond, Vector2(16, 178), Vector2(2232, 179), Charte.FILET)
	var cols := [["NOTE", 900.0], ["ESSAIS", 1150.0], ["PLAQUAGES", 1400.0], ["MÈTRES", 1650.0], ["MATCHS", 1900.0]]
	for c: Array in cols: D.text(fond, c[1], 206, c[0], 15, Charte.IVOIRE_2, 800, 200)
	var y := 216.0
	var i := 0
	for c: Array in cl:
		var j: Dictionary = c[3]
		var ligne := D.rect(fond, Rect2(16, y, 2216, 34), Charte.PANNEAU_2 if i % 2 == 0 else Color.TRANSPARENT, 6)
		ligne.name = "AdversaireCle%d" % i
		_survol(ligne)
		var pa := R.pastille(ligne, 8, 24, str(c[0]), c[2], str(c[1]), "", 15)
		pa.size.x = C.px(220)
		Link.name_link(page.app, ligne, Rect2(250, 0, 380, 34), "player", str(j.get("id", "")), str(j.get("name", "")), 19, Charte.IVOIRE, "AdversaireCleNom%d" % i)
		D.text(ligne, 650, 24, str(j.get("pos", "")), 17, Charte.IVOIRE_2, 800, 200)
		if _n(j.get("average")) > 0: Notes.pastille(ligne, Rect2(884, 4, 54, 26), _n(j.get("average")), 0.55 * C.density)
		var vals := [[int(_n(j.get("tries"))), R.VERT, 1134.0], [int(_n(j.get("tackles"))), R.VIOLET, 1384.0], [int(_n(j.get("metres"))), R.BLEU, 1634.0], [int(_n(j.get("matches"))), Charte.IVOIRE, 1884.0]]
		for v: Array in vals: D.text(ligne, v[2], 25, str(v[0]), 20, v[1], 800, 120)
		y += 36.0
		i += 1
	return H + 14.0
