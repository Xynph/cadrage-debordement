extends RefCounted
## Rapport de l'analyste vidéo après le match (revue FM27, idée 28 ; choix B de Léo du 23/11/2026) : son propre message
## « Analyse vidéo » dans la Réception (club-mail.cjs, type analyse_video). Panneau en largeur : verdicts de l'analyste
## en colonne à gauche (un clic = petite fenêtre de la donnée), quatre onglets à droite qui changent le contenu sur place
## (occasions, domination, nos joueurs, conquête et discipline).
## Données du vrai match seulement : `decisions.report` (stats, essais détaillés, `analyse` : domination minute par minute
## et entrées dans les 22 datées, gardées dans la carrière à la clôture, match-direct.cjs analyseVideo) et
## `clubLife.matchNotes` (notes et détail de nos joueurs). Seul le message du dernier match porte le panneau.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Notes = preload("res://ui/notes_match.gd")
const Link = preload("res://ui/entity_link.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const TYPE := "analyse_video"
const NOUS := R.VERT
const EUX := R.BLEU
const FENETRE := "AnalysteFenetre"
const HAUTEUR := 700.0
const GAUCHE := 300.0
## Onglets : [id, libellé, icône].
const ONGLETS := [["occasions", "Occasions", "target"], ["domination", "Domination", "flag"], ["joueurs", "Nos joueurs", "people"],
	["conquete", "Conquête et discipline", "shield"]]

## Le panneau d'analyse du message `mail` (courrier du club), ou null : autre type, pas de match, ou message d'un match
## plus ancien que le dernier rapport.
static func bloc_mail(app: Control, mail: Dictionary, largeur: float) -> Control:
	if str(mail.get("type", "")) != TYPE: return null
	var report: Dictionary = load("res://ui/immersive08/avant_match_bilan.gd").rapport(app.model)
	if report.is_empty(): return null
	if mail.get("club") == null or _n(mail.get("club")) != _n(report.teams[1 - int(report.side)].get("id")): return null
	var dernier := -1
	for autre: Dictionary in ClubMail.mails(app.model):
		if str(autre.get("type", "")) == TYPE: dernier = maxi(dernier, str(autre.get("id", "")).trim_prefix("mail-").to_int())
	if str(mail.get("id", "")).trim_prefix("mail-").to_int() != dernier: return null
	return bloc(app, report, largeur)

static func bloc(app: Control, report: Dictionary, largeur: float) -> Control:
	var CR = load("res://ui/immersive08/compte_rendu_carte.gd")
	var ctx: Dictionary = CR._contexte(app, report)
	ctx["analyse"] = report.get("analyse") if report.get("analyse") is Dictionary else {}
	ctx["onglet"] = "occasions"
	var racine := Control.new()
	racine.name = "AnalysteMatch"
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	ctx["racine"] = racine
	ctx["largeur"] = largeur
	_panneau(racine, ctx, largeur)
	racine.custom_minimum_size = Vector2(C.px(largeur), C.px(HAUTEUR + 8.0))
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

## Entrées dans les 22 adverses : minutes de chaque camp, triées ([] sans analyse gardée).
static func _occasions_camp(ctx: Dictionary, camp: int) -> Array:
	var out: Array = []
	var liste: Variant = ctx.analyse.get("occasions")
	if liste is Array:
		for o: Variant in liste:
			if o is Array and o.size() == 2 and _n(o[1]) == camp: out.append(_n(o[0]))
	out.sort()
	return out

static func _a_occasions(ctx: Dictionary) -> bool:
	return ctx.analyse.get("occasions") is Array and ctx.analyse.get("zone22") is Dictionary

static func _zone22(ctx: Dictionary, cle: String, camp: int) -> int:
	var z: Variant = ctx.analyse.get("zone22")
	if z is Dictionary and z.get(cle) is Array and (z[cle] as Array).size() == 2: return _n(z[cle][camp])
	return 0

## Domination minute par minute vue de notre camp (+ : nous, − : eux).
static func _domination(ctx: Dictionary) -> Array:
	var out: Array = []
	var d: Variant = ctx.analyse.get("domination")
	if not d is Array: return out
	var signe := 1 if int(ctx.cote) == 0 else -1
	for v: Variant in d: out.append(_n(v) * signe)
	return out

## Part des minutes dominées : [nous, eux] en %, ou [] sans courbe.
static func _parts_domination(ctx: Dictionary) -> Array:
	var dom := _domination(ctx)
	var a := 0
	var b := 0
	for v: int in dom:
		if v > 0: a += 1
		elif v < 0: b += 1
	if a + b == 0: return []
	var p := roundi(100.0 * a / (a + b))
	return [p, 100 - p]

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
		out.append({"id": id, "nom": str(fiche.get("name", "—")), "poste": str(fiche.get("pos", "")), "note": float(n.get("note", 0)),
			"minutes": _n(n.get("minutes")), "essais": _n(n.get("essais")), "plaquages": _n(n.get("plaquages")), "metres": _n(n.get("metres")), "detail": detail})
	out.sort_custom(func(a, b): return a.note > b.note)
	return out

## Verdicts de l'analyste : [id, domaine, icône, sens (1 ▲, 0 =, -1 ▼), chiffre, donnée ouverte en petite fenêtre].
static func _verdicts(ctx: Dictionary) -> Array:
	var nous := int(ctx.cote)
	var eux := 1 - nous
	var out: Array = []
	var e := [_essais_camp(ctx, 0).size(), _essais_camp(ctx, 1).size()]
	out.append(["attaque", "Attaque", "ball", signi(e[nous] - e[eux]), "%d – %d" % [e[nous], e[eux]], "occasions"])
	if _a_occasions(ctx):
		var o := [_zone22(ctx, "entrees", 0), _zone22(ctx, "entrees", 1)]
		out.append(["occasions", "Entrées 22 m", "target", signi(o[nous] - o[eux]) if absi(o[nous] - o[eux]) >= 2 else 0, "%d – %d" % [o[nous], o[eux]], "occasions"])
	var parts := _parts_domination(ctx)
	if not parts.is_empty():
		out.append(["domination", "Domination", "flag", 1 if parts[0] >= 55 else -1 if parts[0] <= 45 else 0, "%d %%" % parts[0], "domination"])
	var cq := [0, 0]
	var ct := [0, 0]
	for camp in 2:
		cq[camp] = _stat(ctx, camp, "scrumsWon") + _stat(ctx, camp, "lineoutsWon")
		ct[camp] = _stat(ctx, camp, "scrums") + _stat(ctx, camp, "lineouts")
	var pc := [_pct(cq[0], ct[0]), _pct(cq[1], ct[1])]
	out.append(["conquete", "Conquête", "shield", signi(pc[nous] - pc[eux]) if absi(pc[nous] - pc[eux]) >= 5 else 0, "%d %%" % pc[nous], "conquete"])
	var pen := [_stat(ctx, 0, "penalties"), _stat(ctx, 1, "penalties")]
	out.append(["discipline", "Discipline", "warning", signi(pen[eux] - pen[nous]) if absi(pen[eux] - pen[nous]) >= 2 else 0, "%d – %d" % [pen[nous], pen[eux]], "conquete"])
	var pl := 0
	for j: Dictionary in _nos_joueurs(ctx): pl += int(j.plaquages)
	out.append(["defense", "Défense", "people", 1 if e[eux] <= 1 else -1 if e[eux] >= 3 else 0, "%d plaq." % pl, "joueurs"])
	return out

static func _sens(v: int) -> Array:
	return ["▲", R.VERT] if v > 0 else ["▼", R.ROUGE] if v < 0 else ["=", R.BLEU]

## Chiffre clé de chaque onglet : [texte, couleur].
static func _chiffre(ctx: Dictionary, id: String) -> Array:
	var nous := int(ctx.cote)
	match id:
		"occasions":
			var a := _zone22(ctx, "entrees", nous) if _a_occasions(ctx) else _essais_camp(ctx, nous).size()
			var b := _zone22(ctx, "entrees", 1 - nous) if _a_occasions(ctx) else _essais_camp(ctx, 1 - nous).size()
			return ["%d – %d" % [a, b], R.VERT if a > b else R.ROUGE if a < b else R.BLEU]
		"domination":
			var parts := _parts_domination(ctx)
			if parts.is_empty(): return ["—", Charte.IVOIRE_2]
			return ["%d %%" % parts[0], R.VERT if parts[0] > 50 else R.ROUGE if parts[0] < 50 else R.BLEU]
		"joueurs":
			var j := _nos_joueurs(ctx)
			if j.is_empty(): return ["—", Charte.IVOIRE_2]
			return ["%s  %s" % [str(j[0].nom).split(" ")[-1], Notes.texte_note(j[0].note)], R.ORANGE]
		_:
			var m := "%d/%d" % [_stat(ctx, nous, "scrumsWon"), _stat(ctx, nous, "scrums")]
			var t := "%d/%d" % [_stat(ctx, nous, "lineoutsWon"), _stat(ctx, nous, "lineouts")]
			return ["M %s · T %s" % [m, t], R.VIOLET]

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

static func _legende(cadre: Control, ctx: Dictionary, x: float, chiffres: Array) -> void:
	for camp in 2:
		var lx := x + camp * 380.0
		var cr := G.crest(ctx.clubs[camp], C.px(26))
		cadre.add_child(cr)
		D.place(cr, Rect2(lx, 12, 26, 26))
		D.rect(cadre, Rect2(lx + 34, 22, 30, 6), _couleur(ctx, camp), 3)
		D.text(cadre, lx + 72, 33, G.club_abbr(ctx.clubs[camp]), 18, _couleur(ctx, camp), 800, 70)
		if camp < chiffres.size(): D.text(cadre, lx + 140, 33, str(chiffres[camp]), 18, Charte.IVOIRE, 800, 200)

## Ballon d'un essai (clic = fiche du marqueur) et étiquette « minute + nom », posée à droite ou à gauche, dessous ou
## dessus, à la première place libre (`places` : zones déjà prises du cadre, `largeur` : largeur du cadre).
static func _ballon(cadre: Control, ctx: Dictionary, e: Dictionary, camp: int, i: int, centre: Vector2, etiquette_dessous: bool, places: Array, largeur: float) -> void:
	var couleur := _couleur(ctx, camp)
	var rond := D.rect(cadre, Rect2(centre.x - 16, centre.y - 16, 32, 32), couleur, 16)
	rond.name = "AnalysteEssai%d_%d" % [camp, i]
	places.append(Rect2(centre.x - 16, centre.y - 16, 32, 32))
	var ball := C.icon("ball", C.px(18), Charte.ENCRE)
	rond.add_child(ball)
	D.place(ball, Rect2(7, 7, 18, 18))
	var nom := str(e.get("name")) if e.get("name") != null else "—"
	var pid := str(e.get("id", "")) if e.get("id") != null else ""
	R.cliquable(rond, func(): _ouvrir_joueur(ctx, pid), "AnalysteEssaiLien%d_%d" % [camp, i], "%d' · %s" % [_n(e.get("minute")), nom])
	var etiquette := "%d' %s" % [_n(e.get("minute")), nom.split(" ")[-1]]
	var lw := R.largeur(etiquette, 16) + 16
	var ys := [centre.y + 8.0, centre.y - 34.0] if etiquette_dessous else [centre.y - 34.0, centre.y + 8.0]
	var choix := Rect2()
	var trouve := false
	for x: float in [centre.x + 18.0, centre.x - 18.0 - lw]:
		for y: float in ys:
			var r := Rect2(x, y, lw, 26)
			if r.position.x < 4 or r.end.x > largeur - 4: continue
			var libre := true
			for autre: Rect2 in places:
				if autre.grow(-1).intersects(r): libre = false; break
			if libre and not trouve: choix = r; trouve = true
	if not trouve: choix = Rect2(clampf(centre.x + 18.0, 4.0, largeur - 4.0 - lw), ys[0], lw, 26)
	places.append(choix)
	var fond_e := D.rect(cadre, choix, Charte.PANNEAU_3, 6, couleur)
	fond_e.name = "AnalysteEtiquette%d_%d" % [camp, i]
	D.text(fond_e, 8, 19, etiquette, 16, Charte.IVOIRE, 800, lw - 12)

# ---- Contenus (onglet, petite fenêtre) -----------------------------------------------------------------------------

static func _contenu(parent: Control, ctx: Dictionary, id: String, zone: Rect2) -> void:
	match id:
		"occasions": _occasions(parent, ctx, zone)
		"domination": _domination_vue(parent, ctx, zone)
		"joueurs": _joueurs(parent, ctx, zone)
		_: _conquete(parent, ctx, zone)

## Courbe cumulée des occasions (entrées dans les 22 adverses) des deux équipes, 0-80', mi-temps, et chaque essai posé
## sur la courbe de son équipe à sa minute (clic = fiche du marqueur). Sans analyse gardée : la courbe des essais.
static func _occasions(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteOccasions"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var avec := _a_occasions(ctx)
	var gx := 70.0
	var gy := 64.0
	var gw := zone.size.x - 120.0
	var gh := zone.size.y - 120.0
	var fin := 80.0
	var series := []
	var maxi_e := 1
	for camp in 2:
		var minutes: Array = []
		if avec: minutes = _occasions_camp(ctx, camp)
		else:
			for e: Dictionary in _essais_camp(ctx, camp): minutes.append(_n(e.get("minute")))
		for m: int in minutes: fin = maxf(fin, float(m))
		series.append(minutes)
		maxi_e = maxi(maxi_e, minutes.size())
	var pas := maxi(1, ceili(maxi_e / 6.0))
	for k in range(0, maxi_e + 1, pas):
		var y := gy + gh - gh * k / float(maxi_e)
		D.line(cadre, Vector2(gx, y), Vector2(gx + gw, y), Color(Charte.FILET, .6))
		D.text(cadre, gx - 14, y + 7, str(k), 17, Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_RIGHT)
	for m: int in [0, 20, 40, 60, 80]:
		var x := gx + gw * m / fin
		D.text(cadre, x, gy + gh + 32, "MT" if m == 40 else "%d'" % m, 17, Charte.IVOIRE if m == 40 else Charte.IVOIRE_2, 700, 60, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(cadre, Rect2(gx + gw * 40.0 / fin - 1, gy - 10, 2, gh + 10), Color(Charte.IVOIRE_2, .7), 0)
	var niveau_a := func(camp: int, minute: int) -> int:
		var n := 0
		for m: int in series[camp]:
			if m <= minute: n += 1
		return n
	for camp in 2:
		var couleur := _couleur(ctx, camp)
		var px := gx
		var niveau := 0
		for m: int in series[camp] + [int(fin)]:
			var x := gx + gw * clampf(float(m), 0, fin) / fin
			var y := gy + gh - gh * niveau / float(maxi_e)
			D.rect(cadre, Rect2(px, y - 2.5, maxf(5.0, x - px), 5), couleur, 2)
			if niveau >= (series[camp] as Array).size(): break
			var y2 := gy + gh - gh * (niveau + 1) / float(maxi_e)
			D.rect(cadre, Rect2(x - 2.5, y2, 5, y - y2), couleur, 2)
			niveau += 1
			px = x
	var places: Array = [Rect2(0, 0, zone.size.x, 44)]
	for camp in 2:
		var i := 0
		for e: Dictionary in _essais_camp(ctx, camp):
			var minute := _n(e.get("minute"))
			var x := gx + gw * clampf(float(minute), 0, fin) / fin
			var y: float = gy + gh - gh * float(niveau_a.call(camp, minute)) / float(maxi_e)
			_ballon(cadre, ctx, e, camp, i, Vector2(x, y), camp != int(ctx.cote), places, zone.size.x)
			i += 1
	var chiffres: Array = []
	for camp in 2:
		var essais := _essais_camp(ctx, camp).size()
		chiffres.append(("%d entrée%s  ·  " % [(series[camp] as Array).size(), "s" if (series[camp] as Array).size() > 1 else ""] if avec else "") + "%d essai%s" % [essais, "s" if essais > 1 else ""])
	_legende(cadre, ctx, gx, chiffres)
	var ic := C.icon("target" if avec else "ball", C.px(22), Charte.IVOIRE_2)
	cadre.add_child(ic)
	D.place(ic, Rect2(zone.size.x - 46, 14, 22, 22))

## Domination minute par minute : une barre par minute, au-dessus de l'axe quand nous dominons (notre couleur), dessous
## quand ils dominent ; mi-temps ; ballons des essais à leur minute ; part du temps dominé de chaque côté.
static func _domination_vue(parent: Control, ctx: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, 12)
	cadre.name = "AnalysteDomination"
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	var dom := _domination(ctx)
	var parts := _parts_domination(ctx)
	var chiffres: Array = []
	for camp in 2:
		chiffres.append("—" if parts.is_empty() else "%d %%" % parts[0 if camp == int(ctx.cote) else 1])
	_legende(cadre, ctx, 70.0, chiffres)
	var gx := 70.0
	var gw := zone.size.x - 120.0
	var haut := 96.0
	var bas := zone.size.y - 84.0
	var axe := (haut + bas) / 2.0
	var demi := (bas - haut) / 2.0 - 24.0
	var fin := maxf(80.0, float(dom.size()))
	D.line(cadre, Vector2(gx, axe), Vector2(gx + gw, axe), Color(Charte.IVOIRE_2, .6))
	for m: int in [0, 20, 40, 60, 80]:
		D.text(cadre, gx + gw * m / fin, zone.size.y - 14, "MT" if m == 40 else "%d'" % m, 17, Charte.IVOIRE if m == 40 else Charte.IVOIRE_2, 700, 60, HORIZONTAL_ALIGNMENT_CENTER)
	var mt: Variant = ctx.analyse.get("miTemps")
	var x_mt := gx + gw * (float(mt) if mt is int or mt is float else 40.0) / fin
	D.rect(cadre, Rect2(x_mt - 1, haut, 2, bas - haut), Color(Charte.IVOIRE_2, .7), 0)
	if dom.is_empty():
		D.text(cadre, zone.size.x / 2.0, axe - 12, "—", 40, Charte.IVOIRE_2, 800, 100, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var bw := gw / fin
	for i in dom.size():
		var v: int = dom[i]
		if v == 0: continue
		var h := demi * absf(v) / 100.0
		var couleur := NOUS if v > 0 else EUX
		var barre := D.rect(cadre, Rect2(gx + i * bw + 1, axe - h if v > 0 else axe, maxf(2.0, bw - 2), h), Color(couleur, .55 + .45 * absf(v) / 100.0), 2)
		barre.name = "AnalysteDomMinute%d" % (i + 1)
		barre.tooltip_text = "%d'" % (i + 1)
		barre.mouse_filter = Control.MOUSE_FILTER_PASS
	# Ballons des essais : les nôtres au-dessus, les leurs dessous.
	var places: Array = [Rect2(0, 0, zone.size.x, 44)]
	for camp in 2:
		var i := 0
		var dessus := camp == int(ctx.cote)
		for e: Dictionary in _essais_camp(ctx, camp):
			var x := gx + gw * clampf(float(_n(e.get("minute"))) - 0.5, 0, fin) / fin
			_ballon(cadre, ctx, e, camp, i, Vector2(x, haut + 4.0 if dessus else bas + 4.0), not dessus, places, zone.size.x)
			i += 1

## Nos joueurs en liste façon Effectif : poste, nom (fiche), note colorée, minutes, essais, mètres, plaquages,
## franchissements, plaquages manqués, en barres de couleur sur le maximum de l'équipe.
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

## Conquête et discipline : barres miroir (mêlées, touches, pénalités, possession, territoire, entrées dans les 22 et
## points qui en découlent).
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
	if _a_occasions(ctx):
		for c: Array in [["Entrées dans les 22", "entrees"], ["Points après entrée", "points"]]:
			var a := _zone22(ctx, c[1], nous)
			var b := _zone22(ctx, c[1], 1 - nous)
			lignes.append([c[0], a, b, str(a), str(b), false])
	var mi := zone.size.x / 2.0
	var demi := mi - 260.0
	var hl := minf(64.0, (zone.size.y - 60.0) / lignes.size())
	for k in 2:
		var cr := G.crest(ctx.clubs[nous if k == 0 else 1 - nous], C.px(28))
		cadre.add_child(cr)
		D.place(cr, Rect2(20.0 if k == 0 else zone.size.x - 48.0, 14, 28, 28))
	for i in lignes.size():
		var l: Array = lignes[i]
		var y := 52.0 + i * hl
		var ligne := D.rect(cadre, Rect2(8, y, zone.size.x - 16, hl - 4), Color.TRANSPARENT, 6)
		ligne.name = "AnalysteConq%d" % i
		_survol(ligne)
		D.text(ligne, mi - 8, hl * .32, str(l[0]).to_upper(), 15, Charte.IVOIRE_2, 800, 300, HORIZONTAL_ALIGNMENT_CENTER)
		var tot := float(l[1] + l[2])
		for k in 2:
			var part := float(l[1 + k]) / tot if tot > 0 else 0.0
			var w := demi * part
			var bx := (mi - 8 - 40 - w) if k == 0 else mi - 8 + 40
			D.rect(ligne, Rect2((mi - 8 - 40 - demi) if k == 0 else mi - 8 + 40, hl * .5, demi, 14), Charte.PANNEAU_3, 7)
			if w > 2: D.rect(ligne, Rect2(bx, hl * .5, w, 14), NOUS if k == 0 else EUX, 7)
			var gagne: bool = (l[1 + k] < l[2 - k]) if l[5] else (l[1 + k] > l[2 - k])
			D.text(ligne, 12.0 if k == 0 else zone.size.x - 28.0, hl * .5 + 14, str(l[3 + k]), 22, (NOUS if k == 0 else EUX) if gagne else Charte.IVOIRE, 800, 140, HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT)

# ---- Panneau : verdicts en colonne, onglets à droite ---------------------------------------------------------------

static func _panneau(racine: Control, ctx: Dictionary, W: float) -> void:
	var fond := D.rect(racine, Rect2(0, 8, W, HAUTEUR), Charte.PANNEAU, Charte.RAYON_CARTE)
	fond.name = "AnalysteFond"
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait_analyste(fond, Rect2(24, 20, 64, 64))
	var t := D.text(fond, 100, 50, "ANALYSE VIDÉO", 22, Charte.IVOIRE, 800, GAUCHE - 106)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	# Le match analysé : score (domicile d'abord), couleur du résultat.
	var sc: Array = ctx.report.score
	var nous := int(ctx.cote)
	var ecart := _n(sc[nous]) - _n(sc[1 - nous])
	var score := D.text(fond, 100, 80, "%s %d – %d %s" % [G.club_abbr(ctx.clubs[0]), _n(sc[0]), _n(sc[1]), G.club_abbr(ctx.clubs[1])], 18,
		R.VERT if ecart > 0 else R.ROUGE if ecart < 0 else R.BLEU, 800, GAUCHE - 106)
	score.name = "AnalysteScore"
	var verdicts := _verdicts(ctx)
	var y := 102.0
	var pas := (HAUTEUR - y - 14.0) / verdicts.size()
	for i in verdicts.size():
		var v: Array = verdicts[i]
		var s := _sens(int(v[3]))
		var ligne := D.rect(fond, Rect2(16, y, GAUCHE - 24, pas - 8), Color(s[1], .16), 10, Color(s[1], .6))
		ligne.name = "AnalysteVerdict_%s" % v[0]
		var ic := C.icon(str(v[2]), C.px(22), s[1])
		ligne.add_child(ic)
		D.place(ic, Rect2(14, 12, 22, 22))
		D.text(ligne, 46, 30, str(v[1]).to_upper(), 17, Charte.IVOIRE, 800, GAUCHE - 110)
		D.text(ligne, GAUCHE - 40, (pas - 8) * .5 + 12, str(s[0]), 34, s[1], 800, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(ligne, 46, pas - 20, str(v[4]), 24, s[1], 800, GAUCHE - 110)
		var donnee := str(v[5])
		var titre := str(v[1])
		R.cliquable(ligne, func(): ouvrir_fenetre(ctx, donnee, titre), "AnalysteVerdictLien_%s" % v[0], "%s · %s" % [v[1], v[4]])
		y += pas
	D.line(fond, Vector2(GAUCHE + 4, 20), Vector2(GAUCHE + 5, HAUTEUR - 20), Charte.FILET)
	var corps := Control.new()
	corps.name = "AnalysteCorps"
	corps.mouse_filter = Control.MOUSE_FILTER_PASS
	fond.add_child(corps)
	D.place(corps, Rect2(GAUCHE + 20, 16, W - GAUCHE - 40, HAUTEUR - 32))
	ctx["corps"] = corps
	_onglets(ctx)

static func _onglets(ctx: Dictionary) -> void:
	var corps: Control = ctx.corps
	for enfant in corps.get_children():
		corps.remove_child(enfant)
		enfant.queue_free()
	var w := float(ctx.largeur) - GAUCHE - 40.0
	var ow := (w - 3 * 10.0) / ONGLETS.size()
	for i in ONGLETS.size():
		var d: Array = ONGLETS[i]
		var actif := str(d[0]) == str(ctx.onglet)
		var ch := _chiffre(ctx, str(d[0]))
		var onglet := D.rect(corps, Rect2(i * (ow + 10), 0, ow, 76), Charte.PANNEAU_3 if actif else Charte.PANNEAU_2, 10, ch[1] if actif else Color.TRANSPARENT)
		onglet.name = "AnalysteOnglet_%s" % d[0]
		if actif: (onglet.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
		var ic := C.icon(str(d[2]), C.px(22), ch[1] if actif else Charte.IVOIRE_2)
		onglet.add_child(ic)
		D.place(ic, Rect2(14, 12, 22, 22))
		D.text(onglet, 46, 30, str(d[1]).to_upper(), 15, Charte.IVOIRE if actif else Charte.IVOIRE_2, 800, ow - 56)
		D.text(onglet, 14, 64, str(ch[0]), 22, ch[1], 800, ow - 24)
		var id := str(d[0])
		R.cliquable(onglet, func():
			ctx.onglet = id
			_onglets(ctx), "AnalysteOngletLien_%s" % id, str(d[1]))
	_contenu(corps, ctx, str(ctx.onglet), Rect2(0, 90, w, HAUTEUR - 32 - 92))

## Petite fenêtre d'une donnée (clic sur un verdict) : la même vue en grand.
static func ouvrir_fenetre(ctx: Dictionary, id: String, titre: String) -> void:
	var page: Control = ctx.app.find_child("ImmersiveInbox", true, false)
	if page == null: page = ctx.racine
	var fond := Fenetre.ouvrir(page, FENETRE, titre.to_upper(), "", 1500, 760)
	_contenu(fond, ctx, id, Rect2(28, 84, 1444, 650))
