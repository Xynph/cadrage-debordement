extends RefCounted
## Page « Dans le monde » (revue FM27, idée 30) — PLANCHE A/B sous CD_VARIANTE_VISUELLE, rien sans variante : un onglet
## de plus dans Compétitions. Données réelles seulement : les résultats du monde (`model.history` : date, ligue, score,
## essais, affluence) et les classements de toutes les ligues (`model.leagues`). Les « actus » sont tirées des résultats
## (plus large victoire, exploit d'un mal classé, festival d'essais, leader) ; le moteur ne garde aucun transfert entre
## clubs adverses : pas de carte « dernière minute » (question pour Léo).
## A : journal (bandeau des affiches, grande une avec image, deux cartes, liste d'actus, championnats en vignettes).
## B : listes (bandeau des affiches, actus en lignes façon Effectif, championnats en lignes avec leurs trois premiers).

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const BanqueImages = preload("res://ui/banque_images.gd")

const W := 2248.0
## Couleur de chaque ligue (aucune couleur de ligue dans les données : palette fixe, à valider).
const PALETTE := [Color("5b9bd5"), Color("7fbf7a"), Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("d9634f"), Color("d7aa5a"), Color("c77dba"), Color("8fb3c9"), Color("b5c46a")]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _n(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0

# ---- Données -------------------------------------------------------------------------------------------------------

static func _club(page, id: Variant) -> Dictionary:
	return page._target_club(page.app, str(roundi(_n(id))) if id is float else str(id))

static func _ligues(page) -> Array:
	var out: Array = []
	var i := 0
	for l: Variant in page.app.model.get("leagues", []):
		if not l is Dictionary or (l.get("rows", []) as Array).is_empty(): continue
		var rows: Array = (l.rows as Array).duplicate()
		rows.sort_custom(func(a, b): return _n(a.get("points")) > _n(b.get("points")) or (_n(a.get("points")) == _n(b.get("points")) and _n(a.get("pf")) - _n(a.get("pa")) > _n(b.get("pf")) - _n(b.get("pa"))))
		out.append({"id": str(l.get("id", "")), "nom": str(l.get("name", "")), "rows": rows, "couleur": PALETTE[i % PALETTE.size()]})
		i += 1
	return out

static func _couleur_ligue(ligues: Array, id: String) -> Color:
	for l: Dictionary in ligues:
		if l.id == id: return l.couleur
	return Charte.IVOIRE_2

static func _nom_ligue(ligues: Array, id: String) -> String:
	for l: Dictionary in ligues:
		if l.id == id: return l.nom
	return id

static func _rang(ligues: Array, lid: String, club_id: Variant) -> int:
	for l: Dictionary in ligues:
		if l.id != lid: continue
		for k in (l.rows as Array).size():
			if _n(l.rows[k].get("id")) == _n(club_id): return k + 1
	return 0

## Résultats des deux dernières dates jouées (les affiches du jour), plus récents d'abord.
static func _affiches(page) -> Array:
	var hist: Array = page.app.model.get("history", []).filter(func(r): return r is Dictionary and r.get("pair") is Array and r.get("score") is Array and r.get("date") is String)
	var dates := {}
	for r: Dictionary in hist: dates[r.date] = true
	var liste := dates.keys()
	liste.sort()
	var garde := liste.slice(maxi(0, liste.size() - 2))
	var out := hist.filter(func(r): return r.date in garde)
	out.sort_custom(func(a, b): return str(a.date) > str(b.date))
	return out

## Actus tirées des résultats de la dernière journée de chaque ligue : [priorité, titre, image, ligue, résultat, club mis en avant].
static func _actus(page, ligues: Array) -> Array:
	var hist: Array = page.app.model.get("history", []).filter(func(r): return r is Dictionary and r.get("pair") is Array and r.get("score") is Array)
	var out: Array = []
	for l: Dictionary in ligues:
		var res := hist.filter(func(r): return str(r.get("leagueId", r.get("competitionId", ""))) == l.id)
		if res.is_empty(): continue
		var dates := {}
		for r: Dictionary in res: dates[str(r.get("date", ""))] = true
		var tri := dates.keys()
		tri.sort()
		var garde := tri.slice(maxi(0, tri.size() - 2))
		var jour := res.filter(func(r): return str(r.get("date", "")) in garde)
		var ecart_max := -1.0
		var large: Dictionary = {}
		for r: Dictionary in jour:
			var s: Array = r.score
			var g := 0 if _n(s[0]) >= _n(s[1]) else 1
			var e := absf(_n(s[0]) - _n(s[1]))
			if e > ecart_max:
				ecart_max = e
				large = r
			var rg := _rang(ligues, l.id, r.pair[g])
			var rp := _rang(ligues, l.id, r.pair[1 - g])
			if e > 0 and rg > 0 and rp > 0 and rg >= rp + 5:
				out.append([4, "%s fait tomber %s" % [G.club_name(_club(page, r.pair[g])), G.club_name(_club(page, r.pair[1 - g]))], "resultat-victoire", l.id, r, r.pair[g]])
			var t: Array = r.get("tries", [0, 0]) if r.get("tries") is Array else [0, 0]
			if _n(t[0]) + _n(t[1]) >= 9:
				out.append([2, "Festival : %d essais" % int(_n(t[0]) + _n(t[1])), "action-essai", l.id, r, r.pair[g]])
		if not large.is_empty() and ecart_max >= 20 and not out.any(func(x): return x[4] is Dictionary and str(x[4].get("fixtureId", "")) == str(large.get("fixtureId", "-"))):
			var g2 := 0 if _n(large.score[0]) >= _n(large.score[1]) else 1
			out.append([3, "%s écrase %s" % [G.club_name(_club(page, large.pair[g2])), G.club_name(_club(page, large.pair[1 - g2]))], "action-franchissement", l.id, large, large.pair[g2]])
		var chef: Dictionary = l.rows[0]
		if _n(chef.get("played")) > 0:
			out.append([1, "%s en tête" % G.club_name(chef), "resultat-titre-trophee-leve", l.id, {}, chef.get("id")])
	out.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	# Notre ligue d'abord à priorité égale : la une parle de notre championnat quand elle le peut.
	var nous := str(page.app.model.get("meta", {}).get("leagueId", ""))
	var i0 := -1
	for k in out.size():
		if str(out[k][3]) == nous and int(out[k][0]) >= 3:
			i0 = k
			break
	if i0 > 0: out.push_front(out.pop_at(i0))
	return out

# ---- Briques -------------------------------------------------------------------------------------------------------

static func _image(parent: Control, id: String, zone: Rect2, rayon: int = 12) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, rayon)
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tex: Texture2D = BanqueImages.texture(id)
	if tex == null: return
	var im := TextureRect.new()
	im.texture = tex
	im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, 0, zone.size.x, zone.size.y))

static func _crest(parent: Control, club: Dictionary, zone: Rect2) -> void:
	var cr := G.crest(club, C.px(zone.size.x))
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	D.place(cr, zone)

static func _survol(ligne: Panel) -> void:
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := (ligne.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var base := style.bg_color
	ligne.add_theme_stylebox_override("panel", style)
	ligne.mouse_entered.connect(func(): style.bg_color = Charte.SELECTION)
	ligne.mouse_exited.connect(func(): style.bg_color = base)

static func _clic(page, cible: Control, actu_ou_res: Variant, nom: String, aide: String) -> void:
	var action := func(): pass
	if actu_ou_res is Dictionary and not (actu_ou_res as Dictionary).is_empty() and actu_ou_res.get("fixtureId") != null:
		var fid := str(actu_ou_res.fixtureId)
		action = func(): page.open_target(page.app, "fixture", fid)
	R.cliquable(cible, action, nom, aide).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _titre(parent: Control, x: float, y: float, texte: String, couleur: Color = Charte.IVOIRE) -> void:
	var t := D.text(parent, x, y, texte, 26, couleur, 800, 900)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)

static func _pastille_ligue(parent: Control, x: float, baseline: float, ligues: Array, lid: String, taille: int = 15) -> Panel:
	return R.pastille(parent, x, baseline, _nom_ligue(ligues, lid), _couleur_ligue(ligues, lid), "trophy", "", taille)

static func _score(r: Dictionary) -> String:
	return "%d – %d" % [int(_n(r.score[0])), int(_n(r.score[1]))] if not r.is_empty() else ""

# ---- Bandeau des affiches (A et B) ---------------------------------------------------------------------------------

static func _bandeau(page, y: float, ligues: Array) -> float:
	var res := _affiches(page)
	_titre(page, 0, y + 30, "AFFICHES DU JOUR")
	var n := mini(res.size(), 10)
	var tw := (W - 9 * 10.0) / 10.0
	for i in n:
		var r: Dictionary = res[i]
		var lid := str(r.get("leagueId", r.get("competitionId", "")))
		var col := _couleur_ligue(ligues, lid)
		var tuile := D.rect(page, Rect2(i * (tw + 10), y + 48, tw, 104), Charte.PANNEAU, 10)
		tuile.name = "MondeAffiche%d" % i
		_survol(tuile)
		D.rect(tuile, Rect2(0, 0, tw, 6), col, 3)
		for k in 2:
			var club := _club(page, r.pair[k])
			_crest(tuile, club, Rect2(12, 18 + k * 40, 28, 28))
			var gagne := _n(r.score[k]) > _n(r.score[1 - k])
			D.text(tuile, 48, 40 + k * 40, G.club_abbr(club), 19, Charte.IVOIRE if gagne else Charte.IVOIRE_2, 800, tw - 110)
			D.text(tuile, tw - 14, 40 + k * 40, str(int(_n(r.score[k]))), 22, col if gagne else Charte.IVOIRE_2, 800, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		_clic(page, tuile, r, "MondeAfficheLien%d" % i, "%s · %s" % [_nom_ligue(ligues, lid), _score(r)])
	if n == 0: D.text(page, 0, y + 100, "—", 24, Charte.IVOIRE_2, 800, 40)
	return y + 170.0

# ---- Option A : journal ----------------------------------------------------------------------------------------------

static func construire(page) -> float:
	var ligues := _ligues(page)
	var y := _bandeau(page, 150.0, ligues)
	return _a(page, y, ligues) if variante() == "A" else _b(page, y, ligues)

static func _a(page, y: float, ligues: Array) -> float:
	var actus := _actus(page, ligues)
	var gauche := 1380.0
	_titre(page, 0, y + 30, "À LA UNE")
	if not actus.is_empty():
		var u: Array = actus[0]
		var une := D.rect(page, Rect2(0, y + 48, gauche, 430), Charte.PANNEAU, Charte.RAYON_CARTE)
		une.name = "MondeUne"
		_survol(une)
		_image(une, str(u[2]), Rect2(0, 0, 640, 430), Charte.RAYON_CARTE)
		D.rect(une, Rect2(0, 0, 10, 430), _couleur_ligue(ligues, str(u[3])), 4)
		_pastille_ligue(une, 676, 44, ligues, str(u[3]), 17)
		var titre := D.text(une, 676, 200, str(u[1]).to_upper(), 46, Charte.IVOIRE, 800, gauche - 710)
		titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.fit_title(titre, gauche - 710, 150, 3, 26)
		var r: Dictionary = u[4]
		if not r.is_empty():
			for k in 2:
				var club := _club(page, r.pair[k])
				_crest(une, club, Rect2(676 + k * 330, 250, 64, 64))
				D.text(une, 676 + k * 330 + 76, 294, G.club_name(club), 20, Charte.IVOIRE_2, 800, 220)
			var sc := D.text(une, 676, 390, _score(r), 64, _couleur_ligue(ligues, str(u[3])), 800, 400)
			sc.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			if r.get("affluence") != null: R.pastille(une, 1080, 380, "%d spectateurs" % int(_n(r.affluence)), R.ORANGE, "people", "", 17)
		else:
			var club := _club(page, u[5])
			_crest(une, club, Rect2(676, 240, 110, 110))
		_clic(page, une, r, "MondeUneLien", str(u[1]))
	# Deux cartes sous la une.
	var cw := (gauche - 16) / 2.0
	for k in 2:
		if actus.size() <= k + 1: break
		var a: Array = actus[k + 1]
		var carte := D.rect(page, Rect2(k * (cw + 16), y + 494, cw, 300), Charte.PANNEAU, Charte.RAYON_CARTE)
		carte.name = "MondeCarte%d" % k
		_survol(carte)
		_image(carte, str(a[2]), Rect2(0, 0, 260, 300), Charte.RAYON_CARTE)
		D.rect(carte, Rect2(0, 0, 8, 300), _couleur_ligue(ligues, str(a[3])), 4)
		_pastille_ligue(carte, 284, 48, ligues, str(a[3]))
		var t := D.text(carte, 284, 120, str(a[1]), 28, Charte.IVOIRE, 800, cw - 310)
		D.fit_title(t, cw - 310, 110, 3, 18)
		var r2: Dictionary = a[4]
		if not r2.is_empty(): D.text(carte, 284, 250, _score(r2), 40, _couleur_ligue(ligues, str(a[3])), 800, 260).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		_clic(page, carte, r2, "MondeCarteLien%d" % k, str(a[1]))
	# Plus d'actus (liste).
	var x := gauche + 24
	var lw := W - x
	_titre(page, x, y + 30, "PLUS D'ACTUS")
	var yy := y + 48
	var i := 0
	for a: Array in actus.slice(3, 13):
		var ligne := D.rect(page, Rect2(x, yy, lw, 72), Charte.PANNEAU if i % 2 == 0 else Charte.PANNEAU_2, 10)
		ligne.name = "MondeActu%d" % i
		_survol(ligne)
		_image(ligne, str(a[2]), Rect2(8, 8, 96, 56), 8)
		D.rect(ligne, Rect2(112, 10, 5, 52), _couleur_ligue(ligues, str(a[3])), 2)
		D.text(ligne, 128, 32, str(a[1]), 19, Charte.IVOIRE, 800, lw - 250)
		D.text(ligne, 128, 58, _nom_ligue(ligues, str(a[3])), 15, _couleur_ligue(ligues, str(a[3])), 800, lw - 250)
		var r3: Dictionary = a[4]
		if not r3.is_empty(): D.text(ligne, lw - 16, 46, _score(r3), 24, Charte.IVOIRE, 800, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		_clic(page, ligne, r3, "MondeActuLien%d" % i, str(a[1]))
		yy += 80
		i += 1
	# Tous les championnats en vignettes aux couleurs de la ligue.
	var yv := y + 830.0
	_titre(page, 0, yv, "TOUS LES CHAMPIONNATS")
	var n := mini(ligues.size(), 6)
	var vw := (W - (n - 1) * 14.0) / maxf(1.0, n)
	for k in n:
		var l: Dictionary = ligues[k]
		var v := D.rect(page, Rect2(k * (vw + 14), yv + 18, vw, 250), Charte.PANNEAU, Charte.RAYON_CARTE)
		v.name = "MondeLigue%d" % k
		_survol(v)
		var tete := D.rect(v, Rect2(0, 0, vw, 52), Color(l.couleur, .85), Charte.RAYON_CARTE)
		D.text(tete, 16, 36, str(l.nom).to_upper(), 19, Charte.ENCRE, 800, vw - 32)
		for j in mini(5, (l.rows as Array).size()):
			var club: Dictionary = l.rows[j]
			var ly := 66.0 + j * 36.0
			D.text(v, 16, ly + 24, str(j + 1), 17, l.couleur if j == 0 else Charte.IVOIRE_2, 800, 30)
			_crest(v, club, Rect2(46, ly + 4, 24, 24))
			D.text(v, 80, ly + 24, G.club_name(club), 17, Charte.IVOIRE, 700, vw - 150)
			D.text(v, vw - 16, ly + 24, str(int(_n(club.get("points")))), 18, l.couleur if j == 0 else Charte.IVOIRE, 800, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		var lid := str(l.id)
		R.cliquable(v, func(): page.open_target(page.app, "competition", lid), "MondeLigueLien%d" % k, str(l.nom)).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return yv + 290.0

# ---- Option B : listes -----------------------------------------------------------------------------------------------

static func _b(page, y: float, ligues: Array) -> float:
	var actus := _actus(page, ligues)
	var gauche := 1160.0
	_titre(page, 0, y + 30, "ACTUALITÉS")
	for c: Array in [["LIGUE", 96], ["", 330], ["SCORE", gauche - 130]]: D.text(page, c[1], y + 62, c[0], 15, Charte.IVOIRE_3, 800, 200)
	var yy := y + 76
	var i := 0
	for a: Array in actus.slice(0, 14):
		var col := _couleur_ligue(ligues, str(a[3]))
		var ligne := D.rect(page, Rect2(0, yy, gauche, 62), Charte.PANNEAU if i % 2 == 0 else Charte.PANNEAU_2, 8)
		ligne.name = "MondeActu%d" % i
		_survol(ligne)
		D.rect(ligne, Rect2(0, 0, 8, 62), col, 3)
		_image(ligne, str(a[2]), Rect2(16, 7, 70, 48), 6)
		var p := _pastille_ligue(ligne, 96, 40, ligues, str(a[3]), 14)
		p.size.x = minf(p.size.x, C.px(220))
		p.clip_contents = true
		var club := _club(page, a[5])
		_crest(ligne, club, Rect2(330, 14, 34, 34))
		D.text(ligne, 376, 40, str(a[1]), 20, Charte.IVOIRE, 800, gauche - 540)
		var r: Dictionary = a[4]
		if not r.is_empty(): D.text(ligne, gauche - 16, 42, _score(r), 24, col, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)
		_clic(page, ligne, r, "MondeActuLien%d" % i, str(a[1]))
		yy += 66
		i += 1
	# Championnats en lignes : couleur, nom, leader, ses points, puis 2e et 3e en écussons ; clic = classement.
	var x := gauche + 28
	var lw := W - x
	_titre(page, x, y + 30, "TOUS LES CHAMPIONNATS")
	for c: Array in [["LEADER", 330], ["PTS", lw - 330], ["2E · 3E", lw - 200]]: D.text(page, x + c[1], y + 62, c[0], 15, Charte.IVOIRE_3, 800, 160)
	var yl := y + 76
	for k in ligues.size():
		var l: Dictionary = ligues[k]
		if yl > y + 1000: break
		var ligne := D.rect(page, Rect2(x, yl, lw, 62), Charte.PANNEAU if k % 2 == 0 else Charte.PANNEAU_2, 8)
		ligne.name = "MondeLigue%d" % k
		_survol(ligne)
		D.rect(ligne, Rect2(0, 0, 10, 62), l.couleur, 3)
		D.text(ligne, 24, 40, str(l.nom), 20, l.couleur, 800, 300)
		var chef: Dictionary = l.rows[0]
		_crest(ligne, chef, Rect2(330, 14, 34, 34))
		D.text(ligne, 374, 40, G.club_name(chef), 19, Charte.IVOIRE, 800, lw - 760)
		D.text(ligne, lw - 280, 42, str(int(_n(chef.get("points")))), 24, l.couleur, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		for j in range(1, mini(3, (l.rows as Array).size())):
			_crest(ligne, l.rows[j], Rect2(lw - 200 + (j - 1) * 48, 14, 34, 34))
		D.text(ligne, lw - 16, 42, "J%d" % int(_n(chef.get("played"))), 17, Charte.IVOIRE_2, 800, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		var lid := str(l.id)
		R.cliquable(ligne, func(): page.open_target(page.app, "competition", lid), "MondeLigueLien%d" % k, str(l.nom)).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		yl += 66
	return maxf(yy, yl) + 20.0
