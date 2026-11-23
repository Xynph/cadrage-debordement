extends RefCounted
## Rapport d'analyste après match (revue FM27, idée 28) — PLANCHE A/B sous CD_VARIANTE_VISUELLE, rien sans variante.
## Sous la carte du compte rendu (article du dernier match, Réception) : l'analyse vidéo du match.
## A : verdicts par domaine en pastilles ▲/▼ + liste des « données clés » ; un clic sur une ligne = petite fenêtre
##     (essais minute par minute, nos joueurs, d'où partent les essais, conquête).
## B : panneau en largeur, verdicts en colonne à gauche, onglets à droite qui changent le contenu sur place.
## Données réelles seulement : `decisions.report` (stats, essais détaillés : minute, camp, origine, zone, marqueur) et
## `clubLife.matchNotes` (notes du dernier match, détail de nos joueurs). Domination, entrées dans les 22 m et carte de
## chaleur ne sont pas gardées après le match (seulement pendant le direct) : absentes ici.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Notes = preload("res://ui/notes_match.gd")
const Link = preload("res://ui/entity_link.gd")
const BanqueImages = preload("res://ui/banque_images.gd")

const NOUS := R.VERT
const EUX := R.BLEU
const ZONES := [["0-5 m", 5], ["5-22 m", 22], ["22-50 m", 50], ["+50 m", 100]]
const FENETRE := "AnalysteFenetre"
## [id, libellé, icône]
const DONNEES := [["essais", "Essais minute par minute", "ball"], ["joueurs", "Nos joueurs", "people"],
	["zones", "D'où partent les essais", "target"], ["conquete", "Conquête et discipline", "shield"]]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Le bloc d'analyse sous la carte du compte rendu, ou null (pas de variante, pas de match).
static func bloc(app: Control, carte_match: Control, largeur: float) -> Control:
	if variante().is_empty() or carte_match == null: return null
	var CR = load("res://ui/immersive08/compte_rendu_carte.gd")
	var report: Dictionary = load("res://ui/immersive08/avant_match_bilan.gd").rapport(app.model)
	if report.is_empty(): return null
	var ctx: Dictionary = CR._contexte(app, report)
	ctx["onglet"] = "essais"
	var racine := Control.new()
	racine.name = "AnalysteMatch"
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	ctx["racine"] = racine
	ctx["largeur"] = largeur
	var h := _bloc_a(racine, ctx, largeur) if variante() == "A" else _bloc_b(racine, ctx, largeur)
	racine.custom_minimum_size = Vector2(C.px(largeur), C.px(h))
	return racine

# ---- Données -------------------------------------------------------------------------------------------------------

static func _n(v: Variant) -> int:
	return roundi(float(v)) if v is int or v is float else 0

static func _couleur(ctx: Dictionary, camp: int) -> Color:
	return NOUS if camp == int(ctx.cote) else EUX

static func _essais_camp(ctx: Dictionary, camp: int) -> Array:
	var out: Array = []
	for e: Variant in ctx.essais:
		if e is Dictionary and _n(e.get("side")) == camp: out.append(e)
	out.sort_custom(func(a, b): return _n(a.get("minute")) < _n(b.get("minute")))
	return out

static func _stat(ctx: Dictionary, camp: int, cle: String) -> int:
	var s: Variant = ctx.report.get("stats")
	if s is Array and s.size() == 2 and s[camp] is Dictionary: return _n(s[camp].get(cle))
	return 0

static func _pct(gagnes: int, total: int) -> int:
	return roundi(100.0 * gagnes / total) if total > 0 else 0

## Nos joueurs du dernier match (notes, minutes, essais, plaquages, mètres) + détail de la feuille (historique[0]).
static func _nos_joueurs(ctx: Dictionary) -> Array:
	var out: Array = []
	var notes: Array = ctx.dernier.get("notes", []) if ctx.dernier.get("notes") is Array else []
	var mn: Dictionary = ctx.model.get("clubLife", {}).get("matchNotes", {}) if ctx.model.get("clubLife") is Dictionary else {}
	var joueurs: Dictionary = mn.get("joueurs", {}) if mn.get("joueurs") is Dictionary else {}
	for n: Variant in notes:
		if not n is Dictionary or _n(n.get("cote")) != int(ctx.cote): continue
		var id := str(n.get("id", ""))
		var fiche := {}
		for p: Variant in ctx.model.get("squad", []):
			if p is Dictionary and str(p.get("id", "")) == id: fiche = p
		var detail := {}
		var j: Variant = joueurs.get(id)
		if j is Dictionary and j.get("historique") is Array and not (j.historique as Array).is_empty() and j.historique[0] is Dictionary: detail = j.historique[0]
		out.append({"id": id, "nom": str(fiche.get("name", "—")), "poste": str(fiche.get("pos", "")), "fiche": fiche, "note": float(n.get("note", 0)),
			"minutes": _n(n.get("minutes")), "essais": _n(n.get("essais")), "plaquages": _n(n.get("plaquages")), "metres": _n(n.get("metres")), "detail": detail})
	out.sort_custom(func(a, b): return a.note > b.note)
	return out

## Verdicts de l'analyste par domaine : [domaine, icône, sens (1 ▲, 0 =, -1 ▼), chiffre].
static func _verdicts(ctx: Dictionary) -> Array:
	var nous := int(ctx.cote)
	var eux := 1 - nous
	var out: Array = []
	var e := [_essais_camp(ctx, 0).size(), _essais_camp(ctx, 1).size()]
	out.append(["Attaque", "ball", signi(e[nous] - e[eux]), "%d – %d" % [e[nous], e[eux]]])
	var cq := [0, 0]
	var ct := [0, 0]
	for camp in 2:
		cq[camp] = _stat(ctx, camp, "scrumsWon") + _stat(ctx, camp, "lineoutsWon")
		ct[camp] = _stat(ctx, camp, "scrums") + _stat(ctx, camp, "lineouts")
	var pc := [_pct(cq[0], ct[0]), _pct(cq[1], ct[1])]
	out.append(["Conquête", "shield", signi(pc[nous] - pc[eux]) if absi(pc[nous] - pc[eux]) >= 5 else 0, "%d %%" % pc[nous]])
	var te := [0.0, 0.0]
	var s: Variant = ctx.report.get("stats")
	if s is Array and s.size() == 2 and s[0] is Dictionary and s[1] is Dictionary: te = [float(s[0].get("territory", 0)), float(s[1].get("territory", 0))]
	var tt: float = float(te[0]) + float(te[1])
	var tn: int = roundi(100.0 * float(te[nous]) / tt) if tt > 0 else 50
	out.append(["Territoire", "flag", 1 if tn >= 55 else -1 if tn <= 45 else 0, "%d %%" % tn])
	var pen := [_stat(ctx, 0, "penalties"), _stat(ctx, 1, "penalties")]
	out.append(["Discipline", "warning", signi(pen[eux] - pen[nous]) if absi(pen[eux] - pen[nous]) >= 2 else 0, "%d – %d" % [pen[nous], pen[eux]]])
	var pl := [0, 0]
	var notes: Array = ctx.dernier.get("notes", []) if ctx.dernier.get("notes") is Array else []
	for n: Variant in notes:
		if n is Dictionary: pl[clampi(_n(n.get("cote")), 0, 1)] += _n(n.get("plaquages"))
	out.append(["Défense", "people", 1 if e[eux] <= 1 else -1 if e[eux] >= 3 else 0, "%d plaq." % pl[nous]])
	return out

static func _sens(v: int) -> Array:
	return ["▲", R.VERT] if v > 0 else ["▼", R.ROUGE] if v < 0 else ["=", R.BLEU]

# ---- Briques -------------------------------------------------------------------------------------------------------

static func _portrait_analyste(parent: Control, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, R.TURQUOISE)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cadre.name = "AnalystePortrait"
	var tex: Texture2D = BanqueImages.texture("staff-analyste")
	if tex != null:
		var im := TextureRect.new()
		im.texture = tex
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		im.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(im)
		D.place(im, Rect2(0, 0, zone.size.x, zone.size.y))

static func _survol(ligne: Panel) -> void:
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := (ligne.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var base := style.bg_color
	ligne.add_theme_stylebox_override("panel", style)
	ligne.mouse_entered.connect(func(): style.bg_color = Charte.SELECTION)
	ligne.mouse_exited.connect(func(): style.bg_color = base)

static func _ouvrir_joueur(ctx: Dictionary, id: String) -> void:
	if Link.available(ctx.app, "player", id): ctx.app.navigation_controller.open_entity({"kind": "player", "id": id})

## Chiffre clé de chaque donnée (ligne de A, onglet de B) : [texte, couleur].
static func _chiffre(ctx: Dictionary, id: String) -> Array:
	var nous := int(ctx.cote)
	match id:
		"essais":
			var a := _essais_camp(ctx, nous).size()
			var b := _essais_camp(ctx, 1 - nous).size()
			return ["%d – %d" % [a, b], R.VERT if a > b else R.ROUGE if a < b else R.BLEU]
		"joueurs":
			var j := _nos_joueurs(ctx)
			if j.is_empty(): return ["—", Charte.IVOIRE_2]
			return ["%s  %s" % [str(j[0].nom).split(" ")[-1], Notes.texte_note(j[0].note)], R.ORANGE]
		"zones":
			var compte := [0, 0, 0, 0]
			for e: Dictionary in _essais_camp(ctx, nous): compte[_zone(e)] += 1
			var best := 0
			for i in 4:
				if compte[i] > compte[best]: best = i
			return [str(ZONES[best][0]) if compte[best] > 0 else "—", R.TURQUOISE]
		_:
			var m := "%d/%d" % [_stat(ctx, nous, "scrumsWon"), _stat(ctx, nous, "scrums")]
			var t := "%d/%d" % [_stat(ctx, nous, "lineoutsWon"), _stat(ctx, nous, "lineouts")]
			return ["M %s · T %s" % [m, t], R.VIOLET]

static func _zone(e: Dictionary) -> int:
	var z := _n(e.get("zone"))
	for i in 4:
		if z <= int(ZONES[i][1]): return i
	return 3

# ---- Contenus (fenêtre de A, onglet de B) ----------------------------------------------------------------------------

static func _contenu(parent: Control, ctx: Dictionary, id: String, zone: Rect2) -> void:
	match id:
		"essais": _courbe(parent, ctx, zone)
		"joueurs": _joueurs(parent, ctx, zone)
		"zones": _zones(parent, ctx, zone)
		_: _conquete(parent, ctx, zone)

## Courbe cumulée des essais (marches) des deux équipes, 0-80', mi-temps, ballon sur chaque essai (clic = fiche).
static func _courbe(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteCourbe"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var gx := 70.0
	var gy := 50.0
	var gw := zone.size.x - 110.0
	var gh := zone.size.y - 110.0
	var fin := 80.0
	var maxi_e := 1
	for camp in 2: maxi_e = maxi(maxi_e, _essais_camp(ctx, camp).size())
	for k in range(0, maxi_e + 1):
		var y := gy + gh - gh * k / float(maxi_e)
		D.line(cadre, Vector2(gx, y), Vector2(gx + gw, y), Color(Charte.FILET, .6))
		D.text(cadre, gx - 14, y + 7, str(k), 17, Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_RIGHT)
	for m: int in [0, 20, 40, 60, 80]:
		var x := gx + gw * m / fin
		D.text(cadre, x, gy + gh + 32, "MT" if m == 40 else "%d'" % m, 17, Charte.IVOIRE if m == 40 else Charte.IVOIRE_2, 700, 60, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(cadre, Rect2(gx + gw / 2.0 - 1, gy - 10, 2, gh + 10), Color(Charte.IVOIRE_2, .7), 0)
	for camp in 2:
		var couleur := _couleur(ctx, camp)
		var liste := _essais_camp(ctx, camp)
		var px := gx
		var niveau := 0
		var i := 0
		for e: Dictionary in liste + [{"minute": 80, "fin": true}]:
			var x := gx + gw * clampf(float(_n(e.get("minute"))), 0, fin) / fin
			var y := gy + gh - gh * niveau / float(maxi_e)
			D.rect(cadre, Rect2(px, y - 2.5, maxf(5.0, x - px), 5), couleur, 2)
			if e.get("fin", false): break
			var y2 := gy + gh - gh * (niveau + 1) / float(maxi_e)
			D.rect(cadre, Rect2(x - 2.5, y2, 5, y - y2), couleur, 2)
			niveau += 1
			var rond := D.rect(cadre, Rect2(x - 16, y2 - 16, 32, 32), couleur, 16)
			rond.name = "AnalysteEssai%d_%d" % [camp, i]
			var ball := C.icon("ball", C.px(18), Charte.ENCRE)
			rond.add_child(ball)
			D.place(ball, Rect2(7, 7, 18, 18))
			var nom := str(e.get("name")) if e.get("name") != null else "—"
			var pid := str(e.get("id", ""))
			R.cliquable(rond, func(): _ouvrir_joueur(ctx, pid), "AnalysteEssaiLien%d_%d" % [camp, i], "%d' · %s" % [_n(e.get("minute")), nom]).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var etiquette := "%d' %s" % [_n(e.get("minute")), nom.split(" ")[-1]]
			var fond_e := D.rect(cadre, Rect2(x + 18, y2 - 40, R.largeur(etiquette, 16) + 16, 26), Charte.PANNEAU_3, 6, couleur)
			D.text(fond_e, 8, 19, etiquette, 16, Charte.IVOIRE, 800, R.largeur(etiquette, 16) + 4)
			px = x
			i += 1
	# Légende : écussons + nombre d'essais.
	for camp in 2:
		var lx := gx + (0.0 if camp == 0 else 260.0)
		var cr := G.crest(ctx.clubs[camp], C.px(26))
		cadre.add_child(cr)
		D.place(cr, Rect2(lx, 12, 26, 26))
		D.rect(cadre, Rect2(lx + 34, 22, 30, 6), _couleur(ctx, camp), 3)
		D.text(cadre, lx + 72, 33, G.club_abbr(ctx.clubs[camp]), 18, _couleur(ctx, camp), 800, 160)

## Nos joueurs en liste façon Effectif : nom (fiche), note colorée, minutes, essais, mètres, plaquages, franchissements,
## plaquages manqués, en barres de couleur sur le maximum de l'équipe.
static func _joueurs(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteJoueurs"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var joueurs := _nos_joueurs(ctx)
	var cols := [["min", "minutes", Charte.IVOIRE_2], ["Essais", "essais", NOUS], ["Mètres", "metres", R.BLEU], ["Plaq.", "plaquages", R.VIOLET],
		["Franch.", "franchissements", R.ORANGE], ["Manqués", "plaquagesManques", R.ROUGE]]
	var maxi_c := {}
	for c: Array in cols:
		var m := 1
		for j: Dictionary in joueurs: m = maxi(m, _val(j, str(c[1])))
		maxi_c[c[1]] = m
	var x0 := 330.0
	var cw := (zone.size.x - x0 - 20.0) / cols.size()
	D.text(cadre, 90, 34, "JOUEUR", 15, Charte.IVOIRE_2, 800, 200)
	D.text(cadre, 262, 34, "NOTE", 15, Charte.IVOIRE_2, 800, 60)
	for k in cols.size(): D.text(cadre, x0 + k * cw, 34, str(cols[k][0]).to_upper(), 15, cols[k][2], 800, cw - 8)
	var rang := 0
	var hl := minf(40.0, (zone.size.y - 50.0) / maxf(1.0, joueurs.size()))
	for j: Dictionary in joueurs:
		var y := 46.0 + rang * hl
		if y + hl > zone.size.y - 4: break
		var ligne := D.rect(cadre, Rect2(8, y, zone.size.x - 16, hl - 2), Charte.PANNEAU_3 if rang % 2 == 0 else Color.TRANSPARENT, 6)
		ligne.name = "AnalysteJoueur%d" % rang
		_survol(ligne)
		D.text(ligne, 10, hl * .68, str(j.poste).split(" ")[0], 15, Charte.IVOIRE_2, 800, 76)
		Link.name_link(ctx.app, ligne, Rect2(90, 0, 160, hl - 2), "player", j.id, str(j.nom), 17, Charte.IVOIRE, "AnalysteJoueurNom%d" % rang)
		Notes.pastille(ligne, Rect2(252, (hl - 28) / 2.0, 50, 26), float(j.note), 0.55 * C.density)
		for k in cols.size():
			var v := _val(j, str(cols[k][1]))
			var bx := x0 - 8 + k * cw
			D.rect(ligne, Rect2(bx, hl * .5 - 4, (cw - 76) * v / float(maxi_c[cols[k][1]]), 8), Color(cols[k][2], .85), 4)
			D.text(ligne, bx + cw - 54, hl * .68, str(v), 17, Charte.IVOIRE if v > 0 else Charte.IVOIRE_2, 800, 44, HORIZONTAL_ALIGNMENT_RIGHT)
		rang += 1

static func _val(j: Dictionary, cle: String) -> int:
	if j.has(cle): return _n(j.get(cle))
	return _n(j.detail.get(cle))

## D'où partent les essais : quatre bandes du terrain (0-5 m … +50 m), nos essais à gauche, les leurs à droite.
static func _zones(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteZones"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var compte := [[0, 0, 0, 0], [0, 0, 0, 0]]
	for camp in 2:
		for e: Dictionary in _essais_camp(ctx, camp):
			compte[camp][_zone(e)] += 1
	var nous := int(ctx.cote)
	var m := 1
	for camp in 2:
		for v: int in compte[camp]: m = maxi(m, v)
	var bh := (zone.size.y - 70.0) / 4.0
	var mi := zone.size.x / 2.0
	for camp in 2:
		var cr := G.crest(ctx.clubs[camp], C.px(28))
		cadre.add_child(cr)
		var tx := mi - 200.0 if camp == nous else mi + 172.0
		D.place(cr, Rect2(tx, 14, 28, 28))
	for i in 4:
		var y := 56.0 + i * bh
		var bande := D.rect(cadre, Rect2(mi - 70, y + 4, 140, bh - 8), Color(R.VERT, .18 + .12 * (3 - i)), 8)
		bande.name = "AnalysteZone%d" % i
		D.text(bande, 70, bh * .5 + 4, str(ZONES[i][0]), 18, Charte.IVOIRE, 800, 130, HORIZONTAL_ALIGNMENT_CENTER)
		for camp in 2:
			var v: int = compte[camp][i]
			var w := (mi - 200.0) * v / float(m)
			var gauche := camp == nous
			var bx := (mi - 80.0 - w) if gauche else mi + 80.0
			if v > 0: D.rect(cadre, Rect2(bx, y + bh * .25, w, bh * .5), _couleur(ctx, camp), 8)
			var tx := (mi - 80.0 - w - 12.0) if gauche else (mi + 80.0 + w + 12.0)
			D.text(cadre, tx, y + bh * .5 + 10, str(v), 28, _couleur(ctx, camp) if v > 0 else Charte.IVOIRE_2, 800, 50, HORIZONTAL_ALIGNMENT_RIGHT if gauche else HORIZONTAL_ALIGNMENT_LEFT)

## Conquête et discipline : barres miroir (mêlées, touches, pénalités, possession, territoire).
static func _conquete(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteConquete"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var nous := int(ctx.cote)
	var lignes: Array = []
	for c: Array in [["Mêlées gagnées", "scrumsWon", "scrums"], ["Touches gagnées", "lineoutsWon", "lineouts"]]:
		var g := [_stat(ctx, nous, c[1]), _stat(ctx, 1 - nous, c[1])]
		var t := [_stat(ctx, nous, c[2]), _stat(ctx, 1 - nous, c[2])]
		lignes.append([c[0], _pct(g[0], t[0]), _pct(g[1], t[1]), "%d/%d" % [g[0], t[0]], "%d/%d" % [g[1], t[1]], false])
	var pen := [_stat(ctx, nous, "penalties"), _stat(ctx, 1 - nous, "penalties")]
	lignes.append(["Pénalités concédées", pen[0], pen[1], str(pen[0]), str(pen[1]), true])
	var s: Variant = ctx.report.get("stats")
	if s is Array and s.size() == 2 and s[0] is Dictionary and s[1] is Dictionary:
		for c: Array in [["Possession", "possession"], ["Territoire", "territory"]]:
			var a := float(s[nous].get(c[1], 0))
			var b := float(s[1 - nous].get(c[1], 0))
			var p := roundi(100.0 * a / (a + b)) if a + b > 0 else 50
			lignes.append([c[0], p, 100 - p, "%d %%" % p, "%d %%" % (100 - p), false])
	var mi := zone.size.x / 2.0
	var demi := mi - 260.0
	var hl := minf(64.0, (zone.size.y - 60.0) / lignes.size())
	for k in 2:
		var cr := G.crest(ctx.clubs[nous if k == 0 else 1 - nous], C.px(28))
		cadre.add_child(cr)
		D.place(cr, Rect2(20.0 if k == 0 else zone.size.x - 48.0, 14, 28, 28))
	for i in lignes.size():
		var l: Array = lignes[i]
		var y := 56.0 + i * hl
		var ligne := D.rect(cadre, Rect2(8, y, zone.size.x - 16, hl - 4), Color.TRANSPARENT, 6)
		ligne.name = "AnalysteConq%d" % i
		_survol(ligne)
		D.text(ligne, mi - 8, hl * .3, str(l[0]).to_upper(), 15, Charte.IVOIRE_2, 800, 300, HORIZONTAL_ALIGNMENT_CENTER)
		var tot := float(l[1] + l[2])
		for k in 2:
			var part := float(l[1 + k]) / tot if tot > 0 else 0.0
			var w := demi * part
			var bx := (mi - 8 - 40 - w) if k == 0 else mi - 8 + 40
			D.rect(ligne, Rect2((mi - 8 - 40 - demi) if k == 0 else mi - 8 + 40, hl * .5, demi, 14), Charte.PANNEAU_3, 7)
			if w > 2: D.rect(ligne, Rect2(bx, hl * .5, w, 14), NOUS if k == 0 else EUX, 7)
			var gagne: bool = (l[1 + k] < l[2 - k]) if l[5] else (l[1 + k] > l[2 - k])
			D.text(ligne, 12.0 if k == 0 else zone.size.x - 28.0, hl * .5 + 14, str(l[3 + k]), 22, (NOUS if k == 0 else EUX) if gagne else Charte.IVOIRE, 800, 140, HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT)

# ---- Option A : verdicts en pastilles + liste des données clés → petite fenêtre -----------------------------------

static func _bloc_a(racine: Control, ctx: Dictionary, W: float) -> float:
	var H := 120.0 + DONNEES.size() * 76.0 + 20.0
	var fond := D.rect(racine, Rect2(0, 16, W, H), Charte.PANNEAU, Charte.RAYON_CARTE)
	fond.name = "AnalysteFond"
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait_analyste(fond, Rect2(24, 20, 72, 72))
	var t := D.text(fond, 112, 52, "ANALYSE VIDÉO", 26, Charte.IVOIRE, 800, 300)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(fond, 112, 84, "DONNÉES CLÉS", 16, R.TURQUOISE, 800, 300)
	# Verdicts par domaine (le « récapitulatif » de l'analyste, sans phrase) : pastilles ▲ / = / ▼.
	var x := W - 24.0
	var verdicts := _verdicts(ctx)
	for i in range(verdicts.size() - 1, -1, -1):
		var v: Array = verdicts[i]
		var s := _sens(int(v[2]))
		var texte := "%s %s" % [s[0], v[0]]
		var lw := R.largeur(texte, 17) + 52
		x -= lw + 10
		var p := R.pastille(fond, x, 64, texte, s[1], str(v[1]), "AnalysteVerdict%d" % i, 17)
		p.tooltip_text = "%s · %s" % [v[0], v[3]]
	var y := 120.0
	for i in DONNEES.size():
		var d: Array = DONNEES[i]
		var ligne := D.rect(fond, Rect2(20, y, W - 40, 68), Charte.PANNEAU_2, 10)
		ligne.name = "AnalysteDonnee_%s" % d[0]
		_survol(ligne)
		var ic := D.rect(ligne, Rect2(12, 10, 48, 48), Charte.PANNEAU_3, 10)
		var icone := C.icon(str(d[2]), C.px(26), R.TURQUOISE)
		ic.add_child(icone)
		D.place(icone, Rect2(11, 11, 26, 26))
		D.text(ligne, 80, 43, str(d[1]), 22, Charte.IVOIRE, 800, 520)
		var ch := _chiffre(ctx, str(d[0]))
		D.text(ligne, W - 120, 45, str(ch[0]), 26, ch[1], 800, 420, HORIZONTAL_ALIGNMENT_RIGHT)
		var fl := C.icon("arrow", C.px(22), Charte.IVOIRE_2)
		ligne.add_child(fl)
		D.place(fl, Rect2(W - 90, 23, 22, 22))
		var id := str(d[0])
		var titre := str(d[1])
		R.cliquable(ligne, func(): ouvrir_fenetre(ctx, id, titre), "AnalysteOuvrir_%s" % id, titre).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		y += 76.0
	return H + 16.0

static func ouvrir_fenetre(ctx: Dictionary, id: String, titre: String) -> void:
	var page: Control = ctx.app.find_child("ImmersiveInbox", true, false)
	if page == null: page = ctx.racine
	var fond := Fenetre.ouvrir(page, FENETRE, titre.to_upper(), "", 1400, 720)
	_contenu(fond, ctx, id, Rect2(28, 84, 1344, 610))

# ---- Option B : panneau en largeur, verdicts à gauche, onglets à droite --------------------------------------------

static func _bloc_b(racine: Control, ctx: Dictionary, W: float) -> float:
	var H := 640.0
	var fond := D.rect(racine, Rect2(0, 16, W, H), Charte.PANNEAU, Charte.RAYON_CARTE)
	fond.name = "AnalysteFond"
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	var gauche := 300.0
	_portrait_analyste(fond, Rect2(24, 22, 64, 64))
	var t := D.text(fond, 100, 52, "ANALYSE", 24, Charte.IVOIRE, 800, gauche - 110)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(fond, 100, 80, "VIDÉO", 16, R.TURQUOISE, 800, gauche - 110)
	var y := 110.0
	var verdicts := _verdicts(ctx)
	for i in verdicts.size():
		var v: Array = verdicts[i]
		var s := _sens(int(v[2]))
		var ligne := D.rect(fond, Rect2(16, y, gauche - 24, 92), Color(s[1], .16), 10, Color(s[1], .6))
		ligne.name = "AnalysteVerdict%d" % i
		_survol(ligne)
		var ic := C.icon(str(v[1]), C.px(22), s[1])
		ligne.add_child(ic)
		D.place(ic, Rect2(14, 14, 22, 22))
		D.text(ligne, 46, 32, str(v[0]).to_upper(), 17, Charte.IVOIRE, 800, gauche - 110)
		D.text(ligne, gauche - 40, 40, str(s[0]), 34, s[1], 800, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(ligne, 46, 74, str(v[3]), 24, s[1], 800, gauche - 110)
		y += 102.0
	D.line(fond, Vector2(gauche + 4, 20), Vector2(gauche + 5, H - 20), Charte.FILET)
	var corps := Control.new()
	corps.name = "AnalysteCorps"
	corps.mouse_filter = Control.MOUSE_FILTER_PASS
	fond.add_child(corps)
	D.place(corps, Rect2(gauche + 20, 16, W - gauche - 40, H - 32))
	ctx["corps"] = corps
	_onglets_b(ctx)
	return H + 16.0

static func _onglets_b(ctx: Dictionary) -> void:
	var corps: Control = ctx.corps
	for enfant in corps.get_children(): enfant.queue_free()
	var w := float(ctx.largeur) - 340.0
	var ow := (w - 3 * 10.0) / DONNEES.size()
	for i in DONNEES.size():
		var d: Array = DONNEES[i]
		var actif := str(d[0]) == str(ctx.onglet)
		var ch := _chiffre(ctx, str(d[0]))
		var onglet := D.rect(corps, Rect2(i * (ow + 10), 0, ow, 76), Charte.PANNEAU_3 if actif else Charte.PANNEAU_2, 10, ch[1] if actif else Color.TRANSPARENT)
		onglet.name = "AnalysteOnglet_%s" % d[0]
		if actif: (onglet.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
		else: _survol(onglet)
		var ic := C.icon(str(d[2]), C.px(22), ch[1] if actif else Charte.IVOIRE_2)
		onglet.add_child(ic)
		D.place(ic, Rect2(14, 12, 22, 22))
		D.text(onglet, 46, 30, str(d[1]).to_upper(), 15, Charte.IVOIRE if actif else Charte.IVOIRE_2, 800, ow - 56)
		D.text(onglet, 14, 64, str(ch[0]), 22, ch[1], 800, ow - 24)
		var id := str(d[0])
		R.cliquable(onglet, func():
			ctx.onglet = id
			_onglets_b(ctx), "AnalysteOngletLien_%s" % id, str(d[1])).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contenu(corps, ctx, str(ctx.onglet), Rect2(0, 90, w, 518))
