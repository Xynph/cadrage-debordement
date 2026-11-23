extends RefCounted
## Offre guidée (idée FM27 n° 17, choix B de Léo du 23/11/2026) : le recruteur du club pose ses conseils sur chaque réglage
## de l'offre (zone ouverture → demande sur la règle, saison conseillée sur la frise, cran de prime, niveau de clause) ; un
## clic sur un conseil l'applique tout de suite. Barre de coût par saison en bas, place sous le plafond salarial affichée.
## Prime à la signature négociable (crans de 5, 10, 15 % des salaires : le joueur baisse d'autant son salaire minimum) et
## clause libératoire (sans, haute, moyenne, basse : −2, −4, −7 % de salaire demandé, mais un club peut la payer) :
## native/engine/clauses-contrat.cjs, projection `market[].offre`.
## L'ouverture conseillée reste SOUS la demande (bas du seuil du moteur, 86 à 93 %, `reservationWage`) : le joueur peut
## contre-proposer (3 propositions). Même grammaire pour le marché entre clubs (`bande_interclub`).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Salary = preload("res://ui/salary_display.gd")
const SEMAINES := 52
const NIVEAUX := ["sans", "haute", "moyenne", "basse"]
const NOMS := {"sans": "Sans", "haute": "Haute", "moyenne": "Moyenne", "basse": "Basse"}
const COULEURS_CLAUSE := {"sans": Charte.IVOIRE_2, "haute": Pieces.VERT, "moyenne": Pieces.ORANGE, "basse": Pieces.ROUGE}

## Hauteur ajoutée sous l'offre pour la bande des coûts.
static func supplement() -> float:
	return 130.0

# --- Données -----------------------------------------------------------------------------------------------------------

## Réglages de l'offre au-delà du salaire et de la durée : cran de prime (indice) et niveau de clause.
static func extras(ctx: Dictionary) -> Dictionary:
	if not ctx.has("extras"): ctx["extras"] = {"cran": 0, "clause": "sans"}
	return ctx.extras

static func offre(ctx: Dictionary) -> Dictionary:
	var o: Variant = ctx.quote.get("offre")
	return o if o is Dictionary else {}

## Crans de prime en plus pour une durée (euros), 0 en premier.
static func crans(ctx: Dictionary, annees: int) -> Array:
	var tous: Variant = offre(ctx).get("crans", {})
	if not tous is Dictionary: return [0]
	var liste: Variant = tous.get(str(clampi(annees, 1, 3)), [0])
	return liste if liste is Array and not liste.is_empty() else [0]

static func prime_en_plus(ctx: Dictionary, annees: int) -> int:
	var liste := crans(ctx, annees)
	return int(liste[clampi(int(extras(ctx).cran), 0, liste.size() - 1)])

static func clauses(ctx: Dictionary) -> Array:
	var liste: Variant = offre(ctx).get("clauses", [])
	return liste if liste is Array else []

static func clause(ctx: Dictionary, niveau: String) -> Dictionary:
	for c: Variant in clauses(ctx):
		if c is Dictionary and str(c.get("niveau", "")) == niveau: return c
	return {"niveau": "sans", "montant": 0, "remise": 0.0}

static func semaines(ctx: Dictionary) -> int:
	return maxi(1, int(offre(ctx).get("semaines", 46)))

## Charge utile ajoutée à la commande recruit : prime totale et clause.
static func charge(ctx: Dictionary, annees: int) -> Dictionary:
	if offre(ctx).is_empty(): return {}
	return {"prime": int(offre(ctx).get("primeBase", ctx.quote.get("fee", 0))) + prime_en_plus(ctx, annees), "clause": str(extras(ctx).clause)}

## Salaire minimum estimé avec la clause et la prime en plus (même calcul que le moteur, sur la demande affichée).
static func baisse(ctx: Dictionary, demande: int, annees: int, niveau: String, extra: int) -> int:
	var apres := float(demande) * (1.0 - float(clause(ctx, niveau).get("remise", 0.0)))
	var moins := minf(float(extra) / (semaines(ctx) * maxi(1, annees)), .15 * demande)
	return roundi(float(demande) - (apres - moins))

## Conseil du recruteur : durée selon l'âge, clause selon l'âge (jeune protégé, trentenaire bradé), premier cran de prime si
## le budget de transferts le permet (le dernier si le plafond salarial est serré), ouverture au bas du seuil du moteur.
static func conseil(ctx: Dictionary, val: Dictionary) -> Dictionary:
	var demande := int(val.demande)
	var age := int(ctx.player.get("age", 25))
	var mini := int(val.min)
	var maxi_ := int(ctx.quote.get("maxYears", 3))
	var duree := clampi(2 if age >= 31 else 3, mini, maxi_)
	var effet := 0
	if duree == 1: effet = 8
	elif duree == 3: effet = 12 if age >= 31 else -4
	var niveau := "haute" if age <= 24 else "basse" if age >= 30 else "moyenne"
	if clauses(ctx).is_empty(): niveau = "sans"
	var liste := crans(ctx, duree)
	var cran := 0
	var budget: Dictionary = val.budget
	var base := maxi(0, int(offre(ctx).get("primeBase", val.get("fee_base", 0))))
	if liste.size() > 1 and (budget.is_empty() or int(budget.get("disponible", 0)) - base >= 2 * int(liste[1])): cran = 1
	var place := place_salariale(ctx, demande)
	if not place.is_empty() and float(place.reste) < .05 * float(place.limite): cran = liste.size() - 1
	var plancher := int(ctx.app.model.get("finance", {}).get("salaryFloor", 1000))
	var ouverture := floori((demande * .88 - baisse(ctx, demande, duree, niveau, int(liste[cran]))) / 100.0) * 100
	return {"ouverture": clampi(ouverture, plancher, maxi(plancher, demande)), "plafond": roundi(demande / 100.0) * 100, "duree": duree, "effet": effet,
		"clause": niveau, "cran": cran}

## Place sous le plafond salarial de la ligue (sinon sous 52 % des recettes) après ce salaire : {reste, limite, libelle}.
static func place_salariale(ctx: Dictionary, salaire: int) -> Dictionary:
	# Budget de la saison (club-budget.cjs) : clubLife.clubStrategy.finance.budget, sinon finance.budget.
	var budget: Variant = ctx.app.model.get("clubLife", {}).get("clubStrategy", {}).get("finance", {}).get("budget")
	if not budget is Dictionary: budget = ctx.app.model.get("finance", {}).get("budget")
	if not budget is Dictionary: return {}
	for cle: Array in [["plafondSalarial", "margePlafond", "Plafond"], ["limiteRecettes", "margeRecettes", "52 % recettes"]]:
		if budget.get(cle[0]) != null and budget.get(cle[1]) != null and float(budget.get(cle[0])) > 0:
			var avant := float(ctx.player.get("salary", 0)) * SEMAINES if ctx.get("prolongation", false) else 0.0
			return {"reste": roundi(float(budget.get(cle[1])) + avant - float(salaire) * SEMAINES), "limite": float(budget.get(cle[0])), "libelle": cle[2]}
	return {}

static func couts(val: Dictionary) -> Dictionary:
	var prime := maxi(0, int(val.fee))
	var saison := int(val.propose) * SEMAINES
	return {"immediat": prime, "saison": saison, "total": prime + saison * int(val.annees), "annees": int(val.annees)}

static func redessiner(ctx: Dictionary) -> void:
	var f: Variant = ctx.get("redessiner")
	if f is Callable and (f as Callable).is_valid(): (f as Callable).call()

static func appliquer(ctx: Dictionary, salaire: int, duree: int) -> void:
	if salaire > 0 and ctx.salary.editable: Salary.set_input_weekly(ctx.salary, float(salaire))
	if duree > 0 and ctx.years.editable: ctx.years.value = duree

static func choisir_cran(ctx: Dictionary, cran: int) -> void:
	if not ctx.salary.editable: return
	extras(ctx).cran = cran
	redessiner(ctx)

static func choisir_clause(ctx: Dictionary, niveau: String) -> void:
	if not ctx.salary.editable: return
	extras(ctx).clause = niveau
	redessiner(ctx)

## « Utiliser sa suggestion » : tous les conseils d'un coup (clause, prime, durée, salaire d'ouverture).
static func suggestion(ctx: Dictionary, cs: Dictionary) -> void:
	if not ctx.salary.editable: return
	extras(ctx).clause = str(cs.clause)
	extras(ctx).cran = int(cs.cran)
	appliquer(ctx, int(cs.ouverture), int(cs.duree))
	redessiner(ctx)

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

## Petite baisse de salaire dans la période affichée (semaine, mois, saison), à la dizaine : « 20 € ».
static func petit_salaire(hebdo: int) -> String:
	return G.euros(maxi(10, roundi(hebdo * Salary.factor() / 10.0) * 10))

## Montant court pour les pastilles : 480 k€, 1,2 M€.
static func court(montant: int) -> String:
	if montant >= 1000000: return ("%.1f M€" % (montant / 1000000.0)).replace(".", ",")
	if montant >= 10000: return "%d k€" % roundi(montant / 1000.0)
	return G.euros(montant)

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

## Petite marque « Conseil » du recruteur (loupe orange) posée au-dessus d'un réglage.
static func _marque(parent: Node, x: float, y: float, id: String, texte: String = "Conseil") -> void:
	var l := Pieces.largeur_pastille(texte, "search")
	Pieces.pastille(parent, x - l / 2.0, y, texte, "search", id, "", Pieces.ORANGE, Charte.PANNEAU_3)

# --- Dessin de l'offre au joueur ---------------------------------------------------------------------------------------

static func dessiner(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, largeur: float, hauteur: float) -> void:
	_carte_conseil(vue, toile, parent, ctx, val, largeur)
	_bande_couts(vue, toile, parent, ctx, val, Rect2(0, hauteur, largeur, supplement() - 12))

## Petite carte du recruteur en haut à droite (visage + suggestion complète) ; ses repères vont sur chaque réglage.
static func _carte_conseil(_vue, _toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, largeur: float) -> void:
	var cs := conseil(ctx, val)
	var r := recruteur(ctx.app)
	var cadre := D.rect(parent, Rect2(largeur - 580, 0, 580, 150), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreGuideeCarte"
	_visage(cadre, Rect2(18, 18, 64, 64), r)
	_grand(cadre, 98, 48, str(r.get("name", "Recruteur")).to_upper(), 24, Charte.IVOIRE, 400)
	_etiquette(cadre, 98, 74, str(r.get("roleLabel", "Recruteur")), Pieces.ORANGE, 400)
	if not r.is_empty():
		var app: Control = ctx.app
		var id := str(r.get("id", ""))
		Pieces.rendre_cliquable(cadre.get_node("OffreGuideeVisage"), Vector2(64, 64), func(): app.navigation_controller.open_entity({"kind": "staff", "id": id}), "OffreGuideeRecruteurLien", "Recruteur", "", Charte.RAYON_PILULE)
	var texte := "Sa suggestion · %s · %d saison%s" % [G.salary_amount(cs.ouverture), int(cs.duree), "s" if int(cs.duree) > 1 else ""]
	if str(cs.clause) != "sans": texte += " · clause " + str(NOMS[cs.clause]).to_lower()
	var bouton := Kit.bouton_ivoire(cadre, Rect2(18, 94, 544, 44), texte, func(): suggestion(ctx, cs), "OffreGuideeSuggestion")
	bouton.disabled = not ctx.salary.editable

## Zone d'accord (ouverture → demande) et drapeau d'ouverture sur la règle ; un clic applique l'ouverture.
static func reperes_regle(cadre: Control, ctx: Dictionary, val: Dictionary, vers_x: Callable, ty: float) -> void:
	var cs := conseil(ctx, val)
	var xo: float = vers_x.call(float(cs.ouverture))
	var xp: float = vers_x.call(float(cs.plafond))
	var zone := D.rect(cadre, Rect2(xo, ty - 16, maxf(4, xp - xo), 42), Color(Pieces.VERT, .16), Charte.RAYON_PETIT, Color(Pieces.VERT, .45))
	zone.name = "OffreGuideeZone"
	cadre.move_child(zone, 1)
	Pieces.rendre_cliquable(zone, Vector2(maxf(4, xp - xo), 42), func(): appliquer(ctx, int(cs.ouverture), 0), "OffreGuideeZoneLien", "Zone d'accord", "", Charte.RAYON_PETIT)
	D.rect(cadre, Rect2(xo - 2, ty - 22, 4, 54), Pieces.BLEU, 2).name = "OffreGuideeOuverture"
	var drapeau := D.text(cadre, xo, ty - 28, "OUVERTURE " + G.salary_amount(cs.ouverture), 15, Pieces.BLEU, 700, 220, HORIZONTAL_ALIGNMENT_CENTER)
	drapeau.name = "OffreGuideeOuvertureTexte"
	var lien := Control.new()
	lien.name = "OffreGuideeOuvertureZone"
	cadre.add_child(lien)
	D.place(lien, Rect2(xo - 110, ty - 48, 220, 26))
	Pieces.rendre_cliquable(lien, Vector2(220, 26), func(): appliquer(ctx, int(cs.ouverture), 0), "OffreGuideeOuvertureLien", "Ouverture", "", Charte.RAYON_PETIT)

## Saison conseillée entourée sur la frise, avec l'effet sur le salaire ; un clic l'applique.
static func repere_frise(cadre: Control, ctx: Dictionary, val: Dictionary, x0: float, pas: float, sy: float) -> void:
	var cs := conseil(ctx, val)
	var i := int(cs.duree) - 1
	var anneau := D.rect(cadre, Rect2(x0 + i * pas - 1, sy - 4, pas + 2, 38), Color.TRANSPARENT, Charte.RAYON_PETIT, Pieces.ORANGE)
	anneau.name = "OffreGuideeSaison"
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := "Conseil" + ("" if _effet(cs).is_empty() else " " + _effet(cs))
	var l := Pieces.largeur_pastille(texte, "search")
	Pieces.pastille(cadre, x0 + (i + 1) * pas - l, 4, texte, "search", "OffreGuideeSaisonPastille", "", Pieces.ORANGE, Charte.PANNEAU_3,
		func(): appliquer(ctx, 0, int(cs.duree)))

## Prime à la signature (gauche) et clause libératoire (droite) : jeton, crans cliquables, conseil entouré.
static func reglages(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, zone: Rect2) -> void:
	var cs := conseil(ctx, val)
	var demi := (zone.size.x - 16) / 2.0
	_prime(vue, toile, parent, ctx, val, cs, Rect2(zone.position, Vector2(demi, zone.size.y)))
	_clause(vue, toile, parent, ctx, val, cs, Rect2(zone.position + Vector2(demi + 16, 0), Vector2(demi, zone.size.y)))

static func _prime(vue, toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, cs: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreJeton"
	_etiquette(cadre, 24, 32, "Prime à la signature", Charte.IVOIRE_2, 260)
	var montant := _grand(cadre, 24, 78, G.euros(int(val.fee)), 36, Pieces.TURQUOISE, 250)
	montant.name = "OffreJetonMontant"
	var lien := Control.new()
	lien.name = "OffreJetonZone"
	cadre.add_child(lien)
	D.place(lien, Rect2(16, 8, 250, 80))
	Pieces.rendre_cliquable(lien, Vector2(250, 80), func(): vue._fenetre_budget(toile, val), "OffreJetonLien", "Prime à la signature", "", Charte.RAYON_PETIT)
	var budget: Dictionary = val.budget
	if not budget.is_empty():
		var reste := int(budget.get("disponible", 0)) - maxi(0, int(val.fee))
		Pieces.pastille(cadre, 24, zone.size.y - 46, "Reste %s" % court(reste), "check" if reste >= 0 else "warning", "OffreJetonReste", "", Pieces.VERT if reste >= 0 else Pieces.ROUGE,
			Charte.PANNEAU_3, func(): vue._fenetre_budget(toile, val))
	var liste := crans(ctx, int(val.annees))
	var choisi := clampi(int(extras(ctx).cran), 0, liste.size() - 1)
	var conseille := clampi(int(cs.cran), 0, liste.size() - 1)
	var x0 := 280.0
	var lt := minf(120.0, (zone.size.x - x0 - 20 - (liste.size() - 1) * 10) / maxf(1, liste.size()))
	for i in liste.size():
		var extra := int(liste[i])
		var effet := baisse(ctx, int(val.demande), int(val.annees), "sans", extra)
		var actif := i == choisi
		var tuile := D.rect(cadre, Rect2(x0 + i * (lt + 10), 44, lt, 84), Color(Pieces.TURQUOISE, .22) if actif else Charte.PANNEAU_3, Charte.RAYON_PETIT,
			Pieces.TURQUOISE if actif else Pieces.ORANGE if i == conseille else Charte.FILET)
		tuile.name = "OffrePrimeCran_%d" % i
		_grand(tuile, lt / 2.0, 30, "Base" if extra == 0 else "+" + court(extra), 20, Pieces.TURQUOISE if actif else Charte.IVOIRE, lt - 10, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tuile, lt / 2.0, 52, "salaire", 13, Charte.IVOIRE_3, 600, lt - 10, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tuile, lt / 2.0, 72, "—" if effet <= 0 else "−" + petit_salaire(effet), 15, Pieces.VERT if effet > 0 else Charte.IVOIRE_3, 700, lt - 10, HORIZONTAL_ALIGNMENT_CENTER)
		var cran := i
		Pieces.rendre_cliquable(tuile, Vector2(lt, 84), func(): choisir_cran(ctx, cran), "OffrePrimeCranLien_%d" % i, "Prime", "", Charte.RAYON_PETIT)
		if i == conseille: _marque(cadre, x0 + i * (lt + 10) + lt / 2.0, 4, "OffreGuideePrimeConseil")

static func _clause(_vue, _toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, cs: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreClause"
	var niveau := str(extras(ctx).clause)
	var c := clause(ctx, niveau)
	_etiquette(cadre, 24, 32, "Clause libératoire", Charte.IVOIRE_2, 260)
	_grand(cadre, 24, 78, "Sans" if niveau == "sans" else court(int(c.get("montant", 0))), 36, COULEURS_CLAUSE[niveau], 250).name = "OffreClauseMontant"
	var risque: Array = {"sans": ["Aucun risque", "lock", Charte.IVOIRE_2], "haute": ["Risque faible", "shield", Pieces.VERT], "moyenne": ["Risque moyen", "warning", Pieces.ORANGE], "basse": ["Risque fort", "warning", Pieces.ROUGE]}[niveau]
	Pieces.pastille(cadre, 24, zone.size.y - 46, str(risque[0]), str(risque[1]), "OffreClauseRisque", "", risque[2], Charte.PANNEAU_3)
	var liste := clauses(ctx)
	if liste.is_empty(): return
	var x0 := 280.0
	var lt := minf(120.0, (zone.size.x - x0 - 20 - (liste.size() - 1) * 10) / maxf(1, liste.size()))
	for i in liste.size():
		var cl: Dictionary = liste[i]
		var nom := str(cl.get("niveau", "sans"))
		var actif := nom == niveau
		var couleur: Color = COULEURS_CLAUSE.get(nom, Charte.IVOIRE)
		var tuile := D.rect(cadre, Rect2(x0 + i * (lt + 10), 44, lt, 84), Color(couleur, .2) if actif else Charte.PANNEAU_3, Charte.RAYON_PETIT,
			couleur if actif else Pieces.ORANGE if nom == str(cs.clause) else Charte.FILET)
		tuile.name = "OffreClauseNiveau_%s" % nom
		_grand(tuile, lt / 2.0, 30, str(NOMS.get(nom, nom)), 20, couleur if actif else Charte.IVOIRE, lt - 10, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(tuile, lt / 2.0, 52, "—" if int(cl.get("montant", 0)) <= 0 else court(int(cl.get("montant", 0))), 14, couleur, 700, lt - 6, HORIZONTAL_ALIGNMENT_CENTER)
		var remise := roundi(float(cl.get("remise", 0.0)) * 100)
		D.text(tuile, lt / 2.0, 72, "—" if remise == 0 else "−%d %%" % remise, 15, Pieces.VERT if remise > 0 else Charte.IVOIRE_3, 700, lt - 10, HORIZONTAL_ALIGNMENT_CENTER)
		Pieces.rendre_cliquable(tuile, Vector2(lt, 84), func(): choisir_clause(ctx, nom), "OffreClauseLien_%s" % nom, "Clause " + str(NOMS.get(nom, nom)).to_lower(), "", Charte.RAYON_PETIT)
		if nom == str(cs.clause): _marque(cadre, x0 + i * (lt + 10) + lt / 2.0, 4, "OffreGuideeClauseConseil")

## Bande des coûts : barre empilée prime + saisons de salaire, chiffres dessous, place sous le plafond salarial.
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
		var barre := D.rect(cadre, Rect2(x, 16, maxf(3, l - 3), 30), s[1], Charte.RAYON_PETIT)
		barre.name = "OffreGuideeSegment_%d" % i
		if l > 120: D.text(barre, 10, 21, str(s[2]).to_upper(), 14, Charte.ENCRE, 800, l - 16)
		Pieces.rendre_cliquable(barre, Vector2(maxf(3, l - 3), 30), budget if i == 0 else total, "OffreGuideeSegmentLien_%d" % i, str(s[2]), "", Charte.RAYON_PETIT)
		x += l
	_etiquette(cadre, x0, 74, "Immédiat", Pieces.TURQUOISE, 300)
	_grand(cadre, x0, 108, G.euros(c.immediat), 32, Pieces.TURQUOISE, 340)
	_etiquette(cadre, x0 + 360, 74, "Par saison", Pieces.BLEU, 300)
	_grand(cadre, x0 + 360, 108, G.euros(c.saison), 32, Pieces.BLEU, 340)
	_etiquette(cadre, x0 + 720, 74, "Total · %d saison%s" % [int(c.annees), "s" if int(c.annees) > 1 else ""], Charte.IVOIRE_2, 340)
	_grand(cadre, x0 + 720, 108, G.euros(c.total), 32, Charte.IVOIRE, 340)
	var place := place_salariale(ctx, int(val.propose))
	if not place.is_empty():
		var ok := int(place.reste) >= 0
		var texte := "%s · reste %s" % [str(place.libelle), court(absi(int(place.reste)))] if ok else "%s · dépassé de %s" % [str(place.libelle), court(absi(int(place.reste)))]
		var l := Pieces.largeur_pastille(texte, "shield")
		Pieces.pastille(cadre, zone.size.x - 28 - l, 74, texte, "shield", "OffreGuideePlafond", "", Pieces.VERT if ok else Pieces.ROUGE, Charte.PANNEAU_3,
			func(): vue._fenetre(toile, "OffreGuideeFenetrePlafond", str(place.libelle), [
				[court(int(place.limite)), "Limite de la ligue", Charte.IVOIRE, "shield"],
				[G.euros(int(val.propose) * SEMAINES), "Ce salaire / saison", Pieces.BLEU, "calendar"],
				[court(int(place.reste)), "Reste après", Pieces.VERT if ok else Pieces.ROUGE, "check" if ok else "warning"]], Pieces.VERT if ok else Pieces.ROUGE))

# --- Marché entre clubs ------------------------------------------------------------------------------------------------

## Bande du recruteur dans la négociation entre clubs : conseils posés sur l'indemnité et le salaire (clic = appliqué),
## clause libératoire du joueur, barre de coût par saison (indemnité + saisons de salaire restantes), place salariale.
## `appliquer_indemnite` / `appliquer_salaire` : Callable(int) qui règle les champs de la vue.
static func bande_interclub(app: Control, parent: Container, personne: Dictionary, indemnite: int, salaire: int, appliquer_indemnite: Callable, appliquer_salaire: Callable) -> Control:
	var hauteur := 300.0
	const L := 1080.0
	var boite := Control.new()
	boite.name = "InterclubGuidee"
	boite.custom_minimum_size = Vector2(L, hauteur) * C.density
	boite.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(boite)
	var demande := int(personne.get("fee", 0))
	var clause_ := int(personne.get("clause", 0))
	var requise := bool(personne.get("clauseRequise", false))
	var ouverture := clause_ if requise else floori(demande * .9 / 1000.0) * 1000
	var r := recruteur(app)
	var tete := D.rect(boite, Rect2(0, 0, L, 64), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	tete.name = "InterclubGuideeRecruteur"
	_visage(tete, Rect2(10, 8, 48, 48), r)
	_grand(tete, 70, 30, str(r.get("name", "Recruteur")).to_upper(), 20, Charte.IVOIRE, 360)
	_etiquette(tete, 70, 52, str(r.get("roleLabel", "Recruteur")), Pieces.ORANGE, 360)
	var bouton := Kit.bouton_ivoire(tete, Rect2(L - 380, 12, 370, 40), "Sa suggestion · %s" % court(ouverture), func():
		appliquer_indemnite.call(ouverture)
		appliquer_salaire.call(int(personne.get("salary", salaire))), "InterclubGuideeSuggestion")
	bouton.disabled = app.waiting
	# Indemnité : ouverture conseillée, demande du vendeur, clause.
	var ligne := D.rect(boite, Rect2(0, 74, L, 74), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	ligne.name = "InterclubGuideeIndemnite"
	_etiquette(ligne, 16, 28, "Indemnité", Charte.IVOIRE_2, 200)
	_grand(ligne, 16, 60, court(indemnite), 26, Pieces.BLEU, 190).name = "InterclubGuideeIndemniteMontant"
	var x := 210.0
	var reperes: Array = []
	if not requise: reperes.append(["Ouverture %s" % court(ouverture), "search", Pieces.ORANGE, ouverture, "InterclubGuideeOuverture"])
	if not requise: reperes.append(["Demande %s" % court(demande), "money", Pieces.VERT, demande, "InterclubGuideeDemande"])
	if clause_ > 0: reperes.append(["Clause %s" % court(clause_), "lock" if requise else "shield", Pieces.ROUGE if requise else Pieces.TURQUOISE, clause_, "InterclubGuideeClause"])
	for rep: Array in reperes:
		var montant := int(rep[3])
		var actif := indemnite == montant
		x += Pieces.pastille(ligne, x, 20, str(rep[0]), str(rep[1]), str(rep[4]), "", rep[2], Color(rep[2], .22) if actif else Charte.PANNEAU_3, func(): appliquer_indemnite.call(montant)) + 10
	# Salaire : demande du joueur.
	var ligne_s := D.rect(boite, Rect2(0, 158, L, 64), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	ligne_s.name = "InterclubGuideeSalaire"
	_etiquette(ligne_s, 16, 26, "Salaire " + G.salary_period(true), Charte.IVOIRE_2, 200)
	_grand(ligne_s, 16, 54, G.salary_amount(salaire), 24, Pieces.BLEU, 190)
	var demande_s := int(personne.get("salary", salaire))
	Pieces.pastille(ligne_s, 210, 15, "Demande %s" % G.salary_amount(demande_s), "money", "InterclubGuideeSalaireDemande", "", Pieces.VERT,
		Color(Pieces.VERT, .22) if salaire == demande_s else Charte.PANNEAU_3, func(): appliquer_salaire.call(demande_s))
	# Coûts par saison : indemnité puis saisons de salaire jusqu'à l'échéance conservée.
	var saisons := maxi(1, int(personne.get("contractEnd", 0)) - int(app.model.get("meta", {}).get("season", 0)) + 1)
	var bande := D.rect(boite, Rect2(0, 232, L, 64), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	bande.name = "InterclubGuideeCouts"
	var segments: Array = [[indemnite, Pieces.TURQUOISE]]
	for i in saisons: segments.append([salaire * SEMAINES, Pieces.BLEU if i % 2 == 0 else Pieces.BLEU.darkened(.25)])
	var somme := 0.0
	for s: Array in segments: somme += float(s[0])
	var bx := 16.0
	var bw := L - 380.0
	for i in segments.size():
		var l := bw * float(segments[i][0]) / maxf(1.0, somme)
		# Aplats simples (ColorRect) : la page adoptée retouche les styles de panneau partagés.
		if l >= 1:
			var segment := ColorRect.new()
			segment.name = "InterclubGuideeSegment_%d" % i
			segment.color = segments[i][1]
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bande.add_child(segment)
			D.place(segment, Rect2(bx, 18, maxf(3, l - 3), 28))
		bx += l
	_grand(bande, L - 360, 42, court(roundi(somme)), 24, Charte.IVOIRE, 120)
	_etiquette(bande, L - 360, 58, "%d saison%s" % [saisons, "s" if saisons > 1 else ""], Charte.IVOIRE_3, 140)
	var place := place_salariale({"app": app, "player": {}}, salaire)
	if not place.is_empty():
		var ok := int(place.reste) >= 0
		var texte := "%s · %s %s" % [str(place.libelle), "reste" if ok else "dépassé de", court(absi(int(place.reste)))]
		Pieces.pastille(bande, L - 16 - Pieces.largeur_pastille(texte, "shield"), 15, texte, "shield", "InterclubGuideePlafond", "", Pieces.VERT if ok else Pieces.ROUGE, Charte.PANNEAU_3)
	# Habillage déjà conforme à la charte : la page adoptée (recruitment_pages.gd) ne doit pas le reteindre.
	boite.set_meta("style_charte", true)
	for enfant in boite.find_children("*", "Control", true, false): enfant.set_meta("style_charte", true)
	return boite
