extends RefCounted
## Offre guidée (idée FM27 n° 17, planche A/B) : le recruteur du club conseille l'offre au joueur en chiffres
## (salaire d'ouverture, plafond, durée, prime) et « Utiliser sa suggestion » remplit l'offre ; coût immédiat et coût
## total en bas. Variantes sous CD_VARIANTE_VISUELLE : A = colonne de bulles à droite, B = repères posés sur la règle
## et la frise + bande des coûts. Sans variante : écran inchangé.
## Données : demande du joueur, durées permises, prime, budget de transferts (déjà dans le devis). L'ouverture reprend le
## bas du seuil d'acceptation du moteur (86 à 93 % de la demande, `reservationWage`), à la centaine inférieure : une contre-offre reste possible (3 propositions) ; durée : 3 saisons −4 %, 1 saison
## +8 %, 3 saisons à 31 ans et plus +12 % (même formule).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Salary = preload("res://ui/salary_display.gd")
const SEMAINES := 52
const COLONNE := 436.0

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Largeur utile des pièces de l'offre (la colonne du recruteur prend la droite en A).
static func utile(largeur: float) -> float:
	return largeur - COLONNE - 24 if variante() == "A" else largeur

## Hauteur ajoutée sous l'offre pour la bande des coûts.
static func supplement() -> float:
	return {"A": 120.0, "B": 150.0}.get(variante(), 0.0)

# --- Conseil -----------------------------------------------------------------------------------------------------------

static func conseil(ctx: Dictionary, val: Dictionary) -> Dictionary:
	var demande := int(val.demande)
	var age := int(ctx.player.get("age", 25))
	var mini := int(val.min)
	var maxi_ := int(ctx.quote.get("maxYears", 3))
	var duree := clampi(2 if age >= 31 else 3, mini, maxi_)
	var effet := 0
	if duree == 1: effet = 8
	elif duree == 3: effet = 12 if age >= 31 else -4
	var plancher := int(ctx.app.model.get("finance", {}).get("salaryFloor", 1000))
	return {"ouverture": clampi(floori(demande * .88 / 100.0) * 100, plancher, maxi(plancher, demande)), "plafond": roundi(demande / 100.0) * 100, "duree": duree, "effet": effet,
		"prime": maxi(0, int(val.fee))}

static func couts(val: Dictionary) -> Dictionary:
	var prime := maxi(0, int(val.fee))
	var saison := int(val.propose) * SEMAINES
	return {"immediat": prime, "saison": saison, "total": prime + saison * int(val.annees), "annees": int(val.annees)}

static func appliquer(ctx: Dictionary, salaire: int, duree: int) -> void:
	if salaire > 0 and ctx.salary.editable: Salary.set_input_weekly(ctx.salary, float(salaire))
	if duree > 0 and ctx.years.editable: ctx.years.value = duree

static func suggestion(ctx: Dictionary, cs: Dictionary) -> void:
	appliquer(ctx, int(cs.ouverture), int(cs.duree))

## Recruteur du club (rôle « scout » du staff projeté), sinon fiche vide.
static func recruteur(app: Control) -> Dictionary:
	var club := str(app.model.get("club", {}).get("id", ""))
	for equipe: Variant in app.model.get("staff", {}).get("teams", []):
		if not equipe is Dictionary or str(equipe.get("id", "")) != club: continue
		for membre: Variant in equipe.get("members", []):
			if membre is Dictionary and str(membre.get("role", "")).to_lower() in ["scout", "recruteur"]: return membre
	return {}

static func _effet(cs: Dictionary) -> String:
	var e := int(cs.effet)
	return "" if e == 0 else ("%s%d %%" % ["+" if e > 0 else "−", absi(e)])

static func _grand(parent: Node, x: float, y: float, texte: String, taille: int, couleur: Color, largeur: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, y, texte, taille, couleur, 800, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return l

static func _etiquette(parent: Node, x: float, y: float, texte: String, couleur: Color, largeur: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := D.text(parent, x, y, texte.to_upper(), 15, couleur, 700, largeur, align)
	l.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return l

static func _icone(parent: Node, zone: Rect2, id: String, couleur: Color) -> void:
	var image := TextureRect.new()
	image.texture = C.icon_texture(id, couleur)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	D.place(image, zone)

static func _visage(parent: Node, zone: Rect2, personne: Dictionary) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_PILULE, Pieces.ORANGE)
	cadre.clip_contents = true
	cadre.name = "OffreGuideeVisage"
	if personne.is_empty():
		_icone(cadre, Rect2(zone.size * .2, zone.size * .6), "search", Pieces.ORANGE)
		return
	var p := G.portrait(int(personne.get("portraitIndex", 0)), int(zone.size.x), personne)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2.ZERO
	cadre.add_child(p)
	D.place(p, Rect2(Vector2.ZERO, zone.size))

# --- Dessin ------------------------------------------------------------------------------------------------------------

static func dessiner(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, largeur: float, hauteur: float) -> void:
	match variante():
		"A": _colonne(vue, toile, parent, ctx, val, largeur)
		"B": _carte_conseil(vue, toile, parent, ctx, val, largeur)
		_: return
	_bande_couts(vue, toile, parent, ctx, val, Rect2(0, hauteur, largeur, supplement() - 12))

## A : colonne du recruteur, quatre bulles chiffrées, bouton de suggestion.
static func _colonne(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, largeur: float) -> void:
	var cs := conseil(ctx, val)
	var x := largeur - COLONNE
	var cadre := D.rect(parent, Rect2(x, 0, COLONNE, 640), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreGuideeColonne"
	var r := recruteur(ctx.app)
	_visage(cadre, Rect2(20, 18, 72, 72), r)
	_grand(cadre, 108, 52, str(r.get("name", "Recruteur")).to_upper(), 26, Charte.IVOIRE, COLONNE - 124)
	_etiquette(cadre, 108, 80, str(r.get("roleLabel", "Recruteur")), Pieces.ORANGE, COLONNE - 124)
	if not r.is_empty():
		var app: Control = ctx.app
		var id := str(r.get("id", ""))
		Pieces.rendre_cliquable(cadre.get_node("OffreGuideeVisage"), Vector2(72, 72), func(): app.navigation_controller.open_entity({"kind": "staff", "id": id}), "OffreGuideeRecruteurLien", "Recruteur", "", Charte.RAYON_PILULE)
	var bulles := [
		["OffreGuideeOuverture", "flag", Pieces.BLEU, G.salary(cs.ouverture), "Ouverture", func(): appliquer(ctx, int(cs.ouverture), 0)],
		["OffreGuideePlafond", "warning", Pieces.ORANGE, G.salary(cs.plafond), "Plafond", func(): appliquer(ctx, int(cs.plafond), 0)],
		["OffreGuideeDuree", "calendar", Pieces.VIOLET, "%d saison%s %s" % [int(cs.duree), "s" if int(cs.duree) > 1 else "", _effet(cs)], "Durée", func(): appliquer(ctx, 0, int(cs.duree))],
		["OffreGuideePrime", "money", Pieces.TURQUOISE, G.euros(cs.prime), "Prime · 1 versement", func(): vue._fenetre_budget(toile, val)],
	]
	var y := 112.0
	for b: Array in bulles:
		var bulle := D.rect(cadre, Rect2(20, y, COLONNE - 40, 92), Charte.PANNEAU_3, Charte.RAYON_CARTE, Color(b[2], .55))
		bulle.name = b[0]
		# Queue de bulle vers le visage.
		var queue := D.rect(cadre, Rect2(12, y + 22, 16, 16), Charte.PANNEAU_3, 3)
		queue.rotation_degrees = 45
		queue.pivot_offset = Vector2(8, 8) * C.density
		cadre.move_child(queue, bulle.get_index())
		D.rect(bulle, Rect2(0, 14, 6, 64), b[2], 3)
		_icone(bulle, Rect2(22, 28, 36, 36), b[1], b[2])
		_grand(bulle, 72, 50, b[3], 32, b[2], COLONNE - 130)
		_etiquette(bulle, 74, 78, b[4], Charte.IVOIRE_2, COLONNE - 130)
		Pieces.rendre_cliquable(bulle, Vector2(COLONNE - 40, 92), b[5], b[0] + "Lien", b[4], "", Charte.RAYON_CARTE)
		y += 104.0
	var bouton := Kit.bouton_ivoire(cadre, Rect2(20, 548, COLONNE - 40, 60), "Utiliser sa suggestion", func(): suggestion(ctx, cs), "OffreGuideeSuggestion")
	bouton.disabled = not ctx.salary.editable

## B : petite carte du recruteur en haut à droite (visage + bouton) ; ses repères vont sur la règle et la frise.
static func _carte_conseil(_vue, _toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, largeur: float) -> void:
	var cs := conseil(ctx, val)
	var r := recruteur(ctx.app)
	var cadre := D.rect(parent, Rect2(largeur - 580, 0, 580, 150), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreGuideeCarte"
	_visage(cadre, Rect2(18, 18, 64, 64), r)
	_grand(cadre, 98, 48, str(r.get("name", "Recruteur")).to_upper(), 24, Charte.IVOIRE, 400)
	_etiquette(cadre, 98, 74, str(r.get("roleLabel", "Recruteur")), Pieces.ORANGE, 400)
	var bouton := Kit.bouton_ivoire(cadre, Rect2(18, 94, 544, 44), "Utiliser sa suggestion · %s · %d saisons" % [G.salary_amount(cs.ouverture), int(cs.duree)], func(): suggestion(ctx, cs), "OffreGuideeSuggestion")
	bouton.disabled = not ctx.salary.editable

## B : zone d'accord (ouverture → plafond) et drapeau d'ouverture sur la règle.
static func reperes_regle(cadre: Control, ctx: Dictionary, val: Dictionary, vers_x: Callable, ty: float) -> void:
	if variante() != "B": return
	var cs := conseil(ctx, val)
	var xo: float = vers_x.call(float(cs.ouverture))
	var xp: float = vers_x.call(float(cs.plafond))
	var zone := D.rect(cadre, Rect2(xo, ty - 16, maxf(4, xp - xo), 42), Color(Pieces.VERT, .16), Charte.RAYON_PETIT, Color(Pieces.VERT, .45))
	zone.name = "OffreGuideeZone"
	cadre.move_child(zone, 1)
	Pieces.rendre_cliquable(zone, Vector2(maxf(4, xp - xo), 42), func(): appliquer(ctx, int(cs.ouverture), 0), "OffreGuideeZoneLien", "Zone d'accord", "", Charte.RAYON_PETIT)
	D.rect(cadre, Rect2(xo - 2, ty - 22, 4, 54), Pieces.BLEU, 2).name = "OffreGuideeOuverture"
	D.text(cadre, xo, ty - 28, "OUVERTURE " + G.salary_amount(cs.ouverture), 15, Pieces.BLEU, 700, 220, HORIZONTAL_ALIGNMENT_CENTER).name = "OffreGuideeOuvertureTexte"

## B : saison conseillée entourée sur la frise, avec l'effet sur le salaire.
static func repere_frise(cadre: Control, ctx: Dictionary, val: Dictionary, x0: float, pas: float, sy: float) -> void:
	if variante() != "B": return
	var cs := conseil(ctx, val)
	var i := int(cs.duree) - 1
	var anneau := D.rect(cadre, Rect2(x0 + i * pas - 1, sy - 4, pas + 2, 38), Color.TRANSPARENT, Charte.RAYON_PETIT, Pieces.ORANGE)
	anneau.name = "OffreGuideeSaison"
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := "Conseil" + ("" if _effet(cs).is_empty() else " " + _effet(cs))
	var l := Pieces.largeur_pastille(texte, "search")
	Pieces.pastille(cadre, x0 + (i + 1) * pas - l, 4, texte, "search", "OffreGuideeSaisonPastille", "", Pieces.ORANGE, Charte.PANNEAU_3,
		func(): appliquer(ctx, 0, int(cs.duree)))

## Bande des coûts : A = deux grands chiffres ; B = barre empilée prime + saisons de salaire, chiffres dessous.
static func _bande_couts(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, zone: Rect2) -> void:
	var c := couts(val)
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreGuideeCouts"
	var budget := func(): vue._fenetre_budget(toile, val)
	var total := func(): vue._fenetre(toile, "OffreGuideeFenetreTotal", "Coût total", [
		[G.euros(c.immediat), "Prime", Pieces.TURQUOISE, "money"],
		[G.euros(c.saison), "Salaire / saison", Pieces.BLEU, "calendar"],
		["× %d" % int(c.annees), "Saisons", Pieces.VIOLET, "flag"],
		[G.euros(c.total), "Total", Charte.IVOIRE, "shield"]], Pieces.BLEU)
	if variante() == "A":
		var demi := zone.size.x / 2.0
		var gauche := Control.new()
		gauche.name = "OffreGuideeImmediat"
		cadre.add_child(gauche)
		D.place(gauche, Rect2(0, 0, demi, zone.size.y))
		_icone(gauche, Rect2(28, zone.size.y / 2 - 24, 48, 48), "money", Pieces.TURQUOISE)
		_etiquette(gauche, 96, 38, "Coût immédiat", Charte.IVOIRE_2, 400)
		_grand(gauche, 96, 86, G.euros(c.immediat), 44, Pieces.TURQUOISE, 600)
		Pieces.rendre_cliquable(gauche, Vector2(demi, zone.size.y), budget, "OffreGuideeImmediatLien", "Coût immédiat", "", Charte.RAYON_CARTE)
		var droite := Control.new()
		droite.name = "OffreGuideeTotal"
		cadre.add_child(droite)
		D.place(droite, Rect2(demi, 0, demi, zone.size.y))
		D.rect(cadre, Rect2(demi, 18, 2, zone.size.y - 36), Charte.FILET)
		_icone(droite, Rect2(28, zone.size.y / 2 - 24, 48, 48), "shield", Charte.IVOIRE)
		_etiquette(droite, 96, 38, "Coût total · %d saison%s" % [int(c.annees), "s" if int(c.annees) > 1 else ""], Charte.IVOIRE_2, 500)
		_grand(droite, 96, 86, G.euros(c.total), 44, Charte.IVOIRE, 600)
		Pieces.rendre_cliquable(droite, Vector2(demi, zone.size.y), total, "OffreGuideeTotalLien", "Coût total", "", Charte.RAYON_CARTE)
		return
	# B : barre empilée.
	var x0 := 28.0
	var w := zone.size.x - 56
	var segments: Array = [[c.immediat, Pieces.TURQUOISE, "Prime"]]
	for i in int(c.annees): segments.append([c.saison, Pieces.BLEU if i % 2 == 0 else Pieces.BLEU.darkened(.25), "Saison %d" % (i + 1)])
	var somme := maxf(1.0, float(c.total))
	var x := x0
	for i in segments.size():
		var s: Array = segments[i]
		var l := w * float(s[0]) / somme
		if l < 1: continue
		var barre := D.rect(cadre, Rect2(x, 20, l - 3, 34), s[1], Charte.RAYON_PETIT)
		barre.name = "OffreGuideeSegment_%d" % i
		if l > 120: D.text(barre, 10, 24, str(s[2]).to_upper(), 14, Charte.ENCRE, 800, l - 16)
		Pieces.rendre_cliquable(barre, Vector2(l - 3, 34), budget if i == 0 else total, "OffreGuideeSegmentLien_%d" % i, str(s[2]), "", Charte.RAYON_PETIT)
		x += l
	_etiquette(cadre, x0, 86, "Immédiat", Pieces.TURQUOISE, 300)
	_grand(cadre, x0, 128, G.euros(c.immediat), 38, Pieces.TURQUOISE, 400)
	_etiquette(cadre, x0 + 420, 86, "Par saison", Pieces.BLEU, 300)
	_grand(cadre, x0 + 420, 128, G.euros(c.saison), 38, Pieces.BLEU, 400)
	_etiquette(cadre, x0 + w - 500, 86, "Total · %d saison%s" % [int(c.annees), "s" if int(c.annees) > 1 else ""], Charte.IVOIRE_2, 500, HORIZONTAL_ALIGNMENT_RIGHT)
	_grand(cadre, x0 + w - 500, 128, G.euros(c.total), 44, Charte.IVOIRE, 500, HORIZONTAL_ALIGNMENT_RIGHT)
