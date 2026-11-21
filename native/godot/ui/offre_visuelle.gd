extends RefCounted
## Offre au joueur : deux présentations visuelles à départager (planche de choix du 21/11/2026, provisoire).
## CD_VARIANTE_VISUELLE=A : tuiles chiffres (prime, salaire, fin de contrat) et barre du budget de transferts.
## CD_VARIANTE_VISUELLE=B : règle demande / proposition, frise des saisons, jeton de prime.
## Sans la variable : l'écran d'offre reste celui de contract_negotiation.gd. Affichage seul : les champs de saisie
## (OfferSalary, OfferYears) restent ceux de la négociation ; un clic sur la règle ou la frise ne fait que les régler.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Salary = preload("res://ui/salary_display.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const LARGEUR := 1500.0
const HAUTEUR := 650.0
const COULEUR_SALAIRE := Pieces.BLEU
const COULEUR_DUREE := Pieces.VIOLET
const COULEUR_PRIME := Pieces.TURQUOISE

static func variante() -> String:
	var valeur := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return valeur if valeur in ["A", "B"] else ""

## `ctx` : app, player, quote, salary (SpinBox), years (SpinBox), first_season, negotiation, phase, reuse (Button).
static func construire(body: Control, ctx: Dictionary) -> Control:
	var v := variante()
	var toile := Control.new()
	toile.name = "OffreVisuelle"
	toile.custom_minimum_size = Vector2(LARGEUR, HAUTEUR) * C.density
	toile.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(toile)
	body.move_child(toile, 0)
	var dessin := Control.new()
	dessin.name = "OffreDessin"
	dessin.mouse_filter = Control.MOUSE_FILTER_PASS
	toile.add_child(dessin)
	D.place(dessin, Rect2(0, 0, LARGEUR, HAUTEUR))
	# Champs de la négociation repris sur la toile (au-dessus du dessin, jamais redessinés : le focus reste).
	for champ: SpinBox in [ctx.salary, ctx.years]:
		if champ.get_parent() != null: champ.get_parent().remove_child(champ)
		toile.add_child(champ)
	if v == "A":
		D.place(ctx.salary, Rect2(24, 244, 330, 50))
		D.place(ctx.years, Rect2(390, 244, 250, 50))
	else:
		D.place(ctx.salary, Rect2(1196, 232, 280, 50))
		D.place(ctx.years, Rect2(1196, 432, 280, 50))
	var redessiner := func(): _dessiner(toile, dessin, ctx, v)
	ctx.salary.value_changed.connect(func(_x: float): redessiner.call())
	ctx.years.value_changed.connect(func(_x: float): redessiner.call())
	redessiner.call()
	toile.set_meta("recap", func() -> Control: return recap(ctx, v))
	toile.set_meta("y_confirmation", 320.0 if v == "A" else 170.0)
	return toile

# --- Données ---------------------------------------------------------------------------------------------------------

static func valeurs(ctx: Dictionary) -> Dictionary:
	var quote: Dictionary = ctx.quote
	var propose := Salary.input_weekly(ctx.salary)
	var demande := int(quote.get("salary", propose))
	var annees := int(ctx.years.value)
	var fee: Variant = quote.get("fee")
	var premiere := int(ctx.first_season)
	return {
		"propose": propose, "demande": demande, "ecart": propose - demande, "annees": annees,
		"min": int(quote.get("minYears", 1)), "max": maxi(int(quote.get("maxYears", 3)), annees),
		"premiere": premiere, "fin": G.contract_year(premiere + annees - 1),
		"fee": int(fee) if fee is int or fee is float else -1,
		"budget": Budget.data(ctx.app.model), "cash": ctx.app.model.get("finance", {}).get("cash"),
	}

static func _signe(valeur: int) -> String:
	return ("+" if valeur >= 0 else "−") + G.euros(absi(valeur))

## Couleur de l'écart à la demande : au moins la demande vert, un peu en dessous orange, loin en dessous rouge.
static func _couleur_ecart(val: Dictionary) -> Color:
	if int(val.ecart) >= 0: return Pieces.VERT
	return Pieces.ORANGE if float(-int(val.ecart)) <= .1 * maxf(1.0, float(val.demande)) else Pieces.ROUGE

static func _mot_ecart(val: Dictionary) -> String:
	if int(val.ecart) == 0: return "Demande respectée"
	return "%s au-dessus" % _signe(int(val.ecart)) if int(val.ecart) > 0 else "%s sous la demande" % _signe(int(val.ecart))

# --- Dessin ----------------------------------------------------------------------------------------------------------

static func _vider(noeud: Node) -> void:
	for enfant in noeud.get_children():
		noeud.remove_child(enfant)
		enfant.queue_free()

## Habillage déjà conforme à la charte : la page adoptée ne doit pas le reteindre.
static func _marquer(noeud: Node) -> void:
	noeud.set_meta("style_charte", true)
	for enfant in noeud.get_children(): _marquer(enfant)

static func _dessiner(toile: Control, dessin: Control, ctx: Dictionary, v: String) -> void:
	if not is_instance_valid(dessin): return
	_vider(dessin)
	var val := valeurs(ctx)
	_identite(toile, dessin, ctx, val, v)
	if v == "A":
		_proposition_a(dessin, val)
		_tuiles(toile, dessin, val, 330.0, 120.0, 46)
		_budget(toile, dessin, val, 470.0, true)
	else:
		_regle(toile, dessin, ctx, val, 170.0, true)
		_frise(toile, dessin, ctx, val, Rect2(0, 370, LARGEUR, 130), true)
		_jeton(toile, dessin, val, Rect2(0, 520, LARGEUR, 120))
	_marquer(toile)

static func _etiquette(parent: Node, x: float, y: float, texte: String, largeur: float = 600) -> Label:
	var l := D.text(parent, x, y, texte.to_upper(), 16, Charte.IVOIRE_2, 700, largeur)
	l.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return l

static func _identite(toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, v: String) -> void:
	var joueur: Dictionary = ctx.player
	var portrait := G.portrait(0, 150, joueur)
	portrait.name = "ContractPlayerPortrait"
	portrait.set_meta("player_id", str(joueur.get("id", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.clip_contents = true
	parent.add_child(portrait)
	D.place(portrait, Rect2(0, 0, 150, 150))
	var fond_portrait := D.rect(parent, Rect2(0, 0, 150, 150), Color.TRANSPARENT, Charte.RAYON_CARTE, Charte.FILET)
	fond_portrait.name = "OffrePortraitCadre"
	var nom := D.text(parent, 176, 58, str(joueur.get("name", "—")).to_upper(), 46, Charte.IVOIRE, 800, 900)
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.name = "OffreNom"
	var id := str(joueur.get("id", ""))
	var app: Control = ctx.app
	Pieces.rendre_cliquable(fond_portrait, Vector2(150, 150), func(): app.navigation_controller.open_entity({"kind":"market", "id":id}), "OffrePortraitLien", "Fiche · " + str(joueur.get("name", "")), "", Charte.RAYON_CARTE)
	var zone_nom := Control.new()
	zone_nom.name = "OffreNomZone"
	parent.add_child(zone_nom)
	D.place(zone_nom, Rect2(170, 10, 620, 60))
	Pieces.rendre_cliquable(zone_nom, Vector2(620, 60), func(): app.navigation_controller.open_entity({"kind":"market", "id":id}), "OffreNomLien", "Fiche · " + str(joueur.get("name", "")), "", Charte.RAYON_PETIT)
	var detail := "%s · %s ans" % [str(joueur.get("pos", "—")), G.n(joueur.get("age", "—"))]
	D.text(parent, 178, 94, detail, 21, Charte.IVOIRE_2, 600, 700, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OffreDetail"
	# Pastilles : étape de la discussion, demande du joueur, écart (A), contre-offre.
	var x := 176.0
	var phase: Dictionary = ctx.phase
	var bloque := bool(phase.get("blocked", false))
	x += Pieces.pastille(parent, x, 112, str(phase.action) if not bloque else "Discussion close", "renew" if not bloque else "lock", "OffreEtape", "", Pieces.ROUGE if bloque else Pieces.BLEU) + 10
	x += Pieces.pastille(parent, x, 112, "Demande %s" % G.salary(val.demande), "money", "OffreDemande", "", Pieces.VERT,
		Charte.PANNEAU_3, func(): _fenetre_salaire(toile, val)) + 10
	if v == "A":
		x += Pieces.pastille(parent, x, 112, _mot_ecart(val), "check" if int(val.ecart) >= 0 else "warning", "OffreEcart", "", _couleur_ecart(val),
			Charte.PANNEAU_3, func(): _fenetre_salaire(toile, val)) + 10
	var negociation: Dictionary = ctx.negotiation
	if str(negociation.get("status", "")) == "counter":
		var reprendre: Button = ctx.reuse
		Pieces.pastille(parent, x, 112, "Contre-offre %s · %d an(s)" % [G.salary(negociation.get("salary")), int(negociation.get("years", 1))], "mail", "OffreContreOffre", "", Pieces.ORANGE,
			Charte.PANNEAU_3, func(): if is_instance_valid(reprendre) and not reprendre.disabled: reprendre.pressed.emit())

# --- Option A ----------------------------------------------------------------------------------------------------------

static func _proposition_a(parent: Control, val: Dictionary) -> void:
	D.rect(parent, Rect2(0, 172, LARGEUR, 136), Charte.PANNEAU_2, Charte.RAYON_CARTE).name = "OffreProposition"
	_etiquette(parent, 24, 204, "Ta proposition", 300)
	D.text(parent, 24, 232, "SALAIRE " + G.salary_period(true).to_upper(), 14, COULEUR_SALAIRE, 700, 330).name = "OffreChampSalaire"
	D.text(parent, 390, 232, "DURÉE", 14, COULEUR_DUREE, 700, 250).name = "OffreChampDuree"
	# Rappel de la demande à droite : salaire et durées acceptées.
	_etiquette(parent, 760, 204, "Ce qu’il demande", 300)
	var bornes := "%d an" % int(val.min) if int(val.min) == int(val.max) else "%d à %d ans" % [int(val.min), int(val.max)]
	var x := 760.0
	x += Pieces.pastille(parent, x, 244, G.salary(val.demande), "money", "OffreRappelSalaire", "", Pieces.VERT) + 10
	Pieces.pastille(parent, x, 244, bornes, "calendar", "OffreRappelDuree", "", COULEUR_DUREE)

static func _tuiles(toile: Control, parent: Control, val: Dictionary, y: float, hauteur: float, taille: int) -> void:
	var largeur := (LARGEUR - 2 * 20) / 3.0
	var fee := int(val.fee)
	Pieces.tuile(parent, Rect2(0, y, largeur, hauteur), G.euros(fee) if fee >= 0 else "—", "Prime à la signature", COULEUR_PRIME, "OffreTuilePrime", taille, "", "money", true, func(): _fenetre_budget(toile, val))
	Pieces.tuile(parent, Rect2(largeur + 20, y, largeur, hauteur), G.salary(val.propose), "Salaire proposé", COULEUR_SALAIRE, "OffreTuileSalaire", taille, "", "people", true, func(): _fenetre_salaire(toile, val))
	Pieces.tuile(parent, Rect2(2 * (largeur + 20), y, largeur, hauteur), str(val.fin), "Fin de contrat · %d an(s)" % int(val.annees), COULEUR_DUREE, "OffreTuileFin", taille, "", "calendar", true, func(): _fenetre_duree(toile, val))

## Barre du budget de transferts : déjà engagé, cette prime, reste (même lecture que « Ce que coûte l'offre »).
static func _budget(toile: Control, parent: Control, val: Dictionary, y: float, complet: bool, large: float = LARGEUR) -> void:
	var hauteur := 150.0 if complet else 96.0
	var cadre := D.rect(parent, Rect2(0, y, large, hauteur), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreBudget"
	var budget: Dictionary = val.budget
	var fee := maxi(0, int(val.fee))
	if budget.is_empty():
		_etiquette(cadre, 24, 36, "Trésorerie du club", 500)
		var montant := D.text(cadre, 24, 84, G.euros(val.cash) if val.cash is int or val.cash is float else "—", 38, Charte.IVOIRE, 800, 600)
		montant.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		return
	var total := Budget.season_total(budget)
	var depense := int(budget.get("depense", 0))
	var reste := int(budget.get("disponible", 0)) - fee
	_etiquette(cadre, 24, 36, "Budget de transferts · %s" % G.euros(total), 900)
	var bx := 24.0
	var by := 52.0 if complet else 46.0
	var bw := large - 48
	var bh := 30.0 if complet else 20.0
	D.rect(cadre, Rect2(bx, by, bw, bh), Charte.PANNEAU_3, Charte.RAYON_PILULE)
	if total > 0:
		var l_dep := bw * clampf(float(depense) / total, 0, 1)
		var l_fee := maxf(6.0 if fee > 0 else 0.0,bw * clampf(float(fee) / total, 0, 1 - l_dep / bw))
		if l_dep > 0: D.rect(cadre, Rect2(bx, by, l_dep, bh), Charte.IVOIRE_3, Charte.RAYON_PILULE)
		if l_fee > 0: D.rect(cadre, Rect2(bx + l_dep, by, l_fee, bh), COULEUR_PRIME, Charte.RAYON_PILULE).name = "OffreBudgetPrime"
		var l_reste := maxf(0, bw - l_dep - l_fee)
		if l_reste > 0: D.rect(cadre, Rect2(bx + l_dep + l_fee, by, l_reste, bh), Color(Pieces.VERT, .22), Charte.RAYON_PILULE, Pieces.VERT).name = "OffreBudgetReste"
	var legende := [["Déjà engagé", G.euros(depense), Charte.IVOIRE_3], ["Cette prime", G.euros(fee), COULEUR_PRIME], ["Reste", G.euros(reste), Pieces.VERT if reste >= 0 else Pieces.ROUGE]]
	var lx := 24.0
	var ly := by + bh + (40.0 if complet else 30.0)
	for element: Array in legende:
		D.rect(cadre, Rect2(lx, ly - 15, 16, 16), element[2], 4)
		var mot := D.text(cadre, lx + 26, ly, element[0], 19, Charte.IVOIRE_2, 600, 0, HORIZONTAL_ALIGNMENT_LEFT, true)
		var largeur_mot := mot.size.x / C.density
		var chiffre := D.text(cadre, lx + 34 + largeur_mot, ly + 1, element[1], 24, element[2] if element[2] != Charte.IVOIRE_3 else Charte.IVOIRE, 800, 0)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		lx += 34 + largeur_mot + chiffre.size.x / C.density + 60
	if reste < 0:
		Pieces.pastille(cadre, large - 220, ly - 26, "Hors budget", "warning", "OffreHorsBudget", "", Pieces.ROUGE)
	Pieces.rendre_cliquable(cadre, Vector2(large, hauteur), func(): _fenetre_budget(toile, val), "OffreBudgetLien", "Budget de transferts", "", Charte.RAYON_CARTE)

# --- Option B ----------------------------------------------------------------------------------------------------------

## Règle de salaire : repère de la demande, curseur de la proposition, écart entre les deux. Un clic sur la règle règle le salaire.
static func _regle(toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, y: float, interactif: bool) -> void:
	var hauteur := 180.0 if interactif else 128.0
	var large := LARGEUR if interactif else LARGEUR - 40
	var cadre := D.rect(parent, Rect2(0, y, large, hauteur), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreRegle" if interactif else "OffreRegleFigee"
	_etiquette(cadre, 24, 34, "Salaire " + G.salary_period(true), 300)
	var couleur := _couleur_ecart(val)
	var ecart := D.text(cadre, 24 + Pieces.largeur_titre("SALAIRE " + G.salary_period(true).to_upper(), 16) + 22, 38, _signe(int(val.ecart)), 30, couleur, 800, 300)
	ecart.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	ecart.name = "OffreRegleEcart"
	# Positions aux montants affichés (arrondis à la centaine comme les salaires du jeu).
	var demande := roundf(float(val.demande) / 100.0) * 100.0
	var propose := roundf(float(val.propose) / 100.0) * 100.0
	var bas := maxf(0.0, minf(demande * .5, propose * .8))
	var haut := maxf(demande * 1.5, propose * 1.2)
	bas = floorf(bas / 100.0) * 100.0
	haut = ceilf(haut / 100.0) * 100.0
	if haut <= bas: haut = bas + 100.0
	var x0 := 40.0
	var w := (1150.0 if interactif else large - 40) - x0
	var ty := 84.0 if interactif else 70.0
	var vers_x := func(valeur: float) -> float: return x0 + w * clampf((valeur - bas) / (haut - bas), 0, 1)
	D.rect(cadre, Rect2(x0, ty, w, 10), Charte.PANNEAU_3, Charte.RAYON_PILULE)
	# Graduations.
	for i in 5:
		var valeur := bas + (haut - bas) * i / 4.0
		var gx: float = vers_x.call(valeur)
		D.rect(cadre, Rect2(gx - 1, ty + 14, 2, 8), Charte.IVOIRE_3)
		if interactif: D.text(cadre, gx, ty + 44, G.salary_amount(valeur), 15, Charte.IVOIRE_3, 600, 140, HORIZONTAL_ALIGNMENT_CENTER, true)
	var xd: float = vers_x.call(demande)
	var xp: float = vers_x.call(propose)
	if absf(xp - xd) > 1: D.rect(cadre, Rect2(minf(xd, xp), ty, absf(xp - xd), 10), couleur, Charte.RAYON_PILULE).name = "OffreRegleEcartBande"
	# Repère de la demande (vert, au-dessus) et curseur de la proposition (bleu, rond).
	D.rect(cadre, Rect2(xd - 2, ty - 22, 4, 54), Pieces.VERT, 2).name = "OffreRegleDemande"
	D.text(cadre, xd, ty - 28, "DEMANDE " + G.salary_amount(val.demande), 15, Pieces.VERT, 700, 220, HORIZONTAL_ALIGNMENT_CENTER)
	var curseur := D.rect(cadre, Rect2(xp - 14, ty - 9, 28, 28), COULEUR_SALAIRE, Charte.RAYON_PILULE, Charte.IVOIRE)
	curseur.name = "OffreRegleCurseur"
	if not interactif:
		D.text(cadre, xp, ty + 50, "TA PROPOSITION " + G.salary_amount(val.propose), 15, COULEUR_SALAIRE, 700, 260, HORIZONTAL_ALIGNMENT_CENTER)
		return
	D.text(cadre, xp, ty + 72, "TA PROPOSITION " + G.salary_amount(val.propose), 16, COULEUR_SALAIRE, 700, 260, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, 1196, 54, "SALAIRE " + G.salary_period(true).to_upper(), 14, COULEUR_SALAIRE, 700, 280)
	var salaire: SpinBox = ctx.salary
	var zone := Button.new()
	zone.name = "OffreRegleClic"
	zone.flat = true
	zone.focus_mode = Control.FOCUS_NONE
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	zone.accessibility_name = "Régler le salaire sur la règle"
	cadre.add_child(zone)
	D.place(zone, Rect2(x0 - 20, ty - 40, w + 40, 100))
	zone.gui_input.connect(func(evenement: InputEvent):
		if evenement is InputEventMouseButton and evenement.pressed and evenement.button_index == MOUSE_BUTTON_LEFT and salaire.editable:
			var unites: float = evenement.position.x / C.density + (x0 - 20)
			var valeur := bas + (haut - bas) * clampf((unites - x0) / w, 0, 1)
			Salary.set_input_weekly(salaire, roundf(valeur / 100.0) * 100.0))

## Frise des saisons : un segment par saison possible, plein jusqu'à la fin proposée. Un clic sur un segment règle la durée.
static func _frise(toile: Control, parent: Control, ctx: Dictionary, val: Dictionary, zone: Rect2, interactif: bool) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreFrise" if interactif else "OffreFriseFigee"
	_etiquette(cadre, 24, 34, "Durée", 200)
	var fin := D.text(cadre, 24 + Pieces.largeur_titre("DURÉE", 16) + 22, 38, "FIN %s" % str(val.fin), 30, COULEUR_DUREE, 800, 300)
	fin.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	fin.name = "OffreFriseFin"
	var x0 := 40.0
	var w := (1150.0 if interactif else zone.size.x - 80) - x0
	var n := maxi(1, int(val.max))
	var pas := w / n
	var sy := 56.0 if interactif else 48.0
	var annees: SpinBox = ctx.years
	for i in n:
		var choisi := i < int(val.annees)
		var hors := i + 1 < int(val.min)
		var segment := D.rect(cadre, Rect2(x0 + i * pas + 3, sy, pas - 6, 30), COULEUR_DUREE if choisi else Charte.PANNEAU_3, Charte.RAYON_PETIT, Color.TRANSPARENT if choisi else Charte.FILET)
		segment.name = "OffreFriseSaison_%d" % (i + 1)
		D.text(segment, (pas - 6) / 2.0, 22, "%d" % (i + 1), 17, Charte.ENCRE if choisi else Charte.IVOIRE_3, 800, pas - 12, HORIZONTAL_ALIGNMENT_CENTER)
		if interactif and not hors:
			var duree := i + 1
			Pieces.rendre_cliquable(segment, Vector2(pas - 6, 30), func(): if annees.editable: annees.value = duree, "OffreFriseClic_%d" % duree, "%d saison(s)" % duree, "", Charte.RAYON_PETIT)
	# Années aux jointures : du début de la première saison à la fin de la dernière.
	for i in n + 1:
		var annee := G.contract_year(int(val.premiere) + i - 1)
		var couleur := COULEUR_DUREE if i == int(val.annees) else Charte.IVOIRE_3
		D.text(cadre, x0 + i * pas, sy + (58 if interactif else 52), annee, 16 if i != int(val.annees) else 19, couleur, 700, 90, HORIZONTAL_ALIGNMENT_CENTER)
	if interactif: D.text(cadre, 1196, zone.size.y - 74 - 18, "SAISONS", 14, COULEUR_DUREE, 700, 280)

## Jeton de la prime à la signature et ce qu'il reste du budget de transferts.
static func _jeton(toile: Control, parent: Control, val: Dictionary, zone: Rect2) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "OffreJeton"
	var d := zone.size.y - 24
	var rond := D.rect(cadre, Rect2(20, 12, d, d), Color(COULEUR_PRIME, .18), Charte.RAYON_PILULE, COULEUR_PRIME)
	rond.name = "OffreJetonRond"
	var icone := TextureRect.new()
	icone.texture = C.icon_texture("money", COULEUR_PRIME)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rond.add_child(icone)
	D.place(icone, Rect2(d / 2 - 22, d / 2 - 22, 44, 44))
	var fee := int(val.fee)
	var montant := D.text(cadre, 40 + d, zone.size.y / 2 + 6, G.euros(fee) if fee >= 0 else "—", 44, COULEUR_PRIME, 800, 360)
	montant.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	montant.name = "OffreJetonMontant"
	D.text(cadre, 42 + d, zone.size.y / 2 + 34, "PRIME À LA SIGNATURE", 15, Charte.IVOIRE_2, 700, 360)
	Pieces.rendre_cliquable(rond, Vector2(d, d), func(): _fenetre_budget(toile, val), "OffreJetonLien", "Prime à la signature", "", Charte.RAYON_PILULE)
	var budget: Dictionary = val.budget
	var x := 40.0 + d + 300.0
	var py := zone.size.y / 2 - 17
	var etroit := zone.size.x < 1000
	if not budget.is_empty():
		var reste := int(budget.get("disponible", 0)) - maxi(0, fee)
		x += Pieces.pastille(cadre, x, py, "Reste %s" % G.euros(reste), "check" if reste >= 0 else "warning", "OffreJetonReste", "", Pieces.VERT if reste >= 0 else Pieces.ROUGE,
			Charte.PANNEAU_3, func(): _fenetre_budget(toile, val)) + 12
		if etroit: return
		x += Pieces.pastille(cadre, x, py, "Engagé %s" % G.euros(budget.get("depense", 0)), "", "OffreJetonEngage", "", Charte.IVOIRE,
			Charte.PANNEAU_3, func(): _fenetre_budget(toile, val)) + 12
	if (val.cash is int or val.cash is float) and not etroit:
		Pieces.pastille(cadre, x, py, "Trésorerie %s" % G.euros(val.cash), "money", "OffreJetonTresorerie", "", Charte.IVOIRE, Charte.PANNEAU_3, func(): _fenetre_budget(toile, val))

# --- Récapitulatif de la confirmation ------------------------------------------------------------------------------------

## Récapitulatif figé inséré dans la confirmation en place (aucune phrase : les mêmes pièces que l'écran, sans saisie).
static func recap(ctx: Dictionary, v: String) -> Control:
	var val := valeurs(ctx)
	var hauteur := 236.0 if v == "A" else 272.0
	var boite := Control.new()
	boite.name = "OffreRecap"
	boite.custom_minimum_size = Vector2(LARGEUR - 40, hauteur) * C.density
	boite.mouse_filter = Control.MOUSE_FILTER_PASS
	var toile := boite
	if v == "A":
		_tuiles_recap(boite, val)
		_budget(toile, boite, val, 128, false, LARGEUR - 40)
	else:
		_regle(toile, boite, ctx, val, 0, false)
		_frise(toile, boite, ctx, val, Rect2(0, 140, 820, 110), false)
		_jeton(toile, boite, val, Rect2(840, 140, LARGEUR - 40 - 840, 110))
	_marquer(boite)
	return boite

static func _tuiles_recap(parent: Control, val: Dictionary) -> void:
	var largeur := (LARGEUR - 40 - 2 * 16) / 3.0
	var fee := int(val.fee)
	Pieces.tuile(parent, Rect2(0, 0, largeur, 112), G.euros(fee) if fee >= 0 else "—", "Prime à la signature", COULEUR_PRIME, "OffreRecapPrime", 42, "", "money", true)
	Pieces.tuile(parent, Rect2(largeur + 16, 0, largeur, 112), G.salary(val.propose), "Salaire · " + _mot_ecart(val).to_lower(), COULEUR_SALAIRE, "OffreRecapSalaire", 42, "", "people", true)
	Pieces.tuile(parent, Rect2(2 * (largeur + 16), 0, largeur, 112), str(val.fin), "Fin de contrat · %d an(s)" % int(val.annees), COULEUR_DUREE, "OffreRecapFin", 42, "", "calendar", true)

# --- Petites fenêtres visuelles ------------------------------------------------------------------------------------------

## Petite fenêtre sur la toile : tuiles seulement ; ✕, Échap ou un clic à côté la ferment.
static func _fenetre(toile: Control, id: String, titre: String, tuiles: Array, couleur: Color) -> Control:
	var ancien := toile.get_node_or_null("OffrePetiteFenetre")
	if ancien != null:
		toile.remove_child(ancien)
		ancien.queue_free()
	var taille_toile := toile.size / C.density
	var calque := Control.new()
	calque.name = "OffrePetiteFenetre"
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	toile.add_child(calque)
	D.place(calque, Rect2(Vector2.ZERO, taille_toile))
	var fermer := func():
		if is_instance_valid(calque):
			if calque.get_parent() != null: calque.get_parent().remove_child(calque)
			calque.queue_free()
	var a_cote := Button.new()
	a_cote.name = "OffrePetiteFenetreACote"
	a_cote.flat = true
	a_cote.focus_mode = Control.FOCUS_NONE
	for etat in ["normal", "hover", "pressed", "focus"]: a_cote.add_theme_stylebox_override(etat, StyleBoxEmpty.new())
	a_cote.pressed.connect(fermer)
	calque.add_child(a_cote)
	D.place(a_cote, Rect2(Vector2.ZERO, taille_toile))
	var n := maxi(1, tuiles.size())
	var largeur := minf(taille_toile.x - 40, 40 + n * 250 + (n - 1) * 14)
	var panneau := D.rect(calque, Rect2((taille_toile.x - largeur) / 2, 150, largeur, 200), Charte.PANNEAU, Charte.RAYON_PANNEAU, couleur)
	panneau.name = id
	panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	Charte.ombrer(panneau.get_theme_stylebox("panel") as StyleBoxFlat)
	var tete := D.text(panneau, 24, 40, titre.to_upper(), 22, couleur, 800, largeur - 90)
	tete.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	var croix := Button.new()
	croix.name = id + "Fermer"
	croix.text = "✕"
	croix.flat = true
	croix.focus_mode = Control.FOCUS_ALL
	croix.add_theme_color_override("font_color", Charte.IVOIRE_2)
	croix.add_theme_font_size_override("font_size", maxi(14, C.px(24)))
	croix.pressed.connect(fermer)
	panneau.add_child(croix)
	D.place(croix, Rect2(largeur - 56, 8, 44, 44))
	var tl := (largeur - 40 - (n - 1) * 14) / n
	for i in tuiles.size():
		var t: Array = tuiles[i]
		Pieces.tuile(panneau, Rect2(20 + i * (tl + 14), 70, tl, 110), t[0], t[1], t[2], "%sTuile_%d" % [id, i], 36, "", t[3] if t.size() > 3 else "", true)
	_marquer(calque)
	PetiteFenetre.enregistrer(calque, fermer)
	croix.grab_focus.call_deferred()
	return calque

static func _fenetre_salaire(toile: Control, val: Dictionary) -> void:
	_fenetre(toile, "OffreFenetreSalaire", "Salaire " + G.salary_period(true), [
		[G.salary(val.demande), "Demande", Pieces.VERT, "money"],
		[G.salary(val.propose), "Ta proposition", COULEUR_SALAIRE, "people"],
		[_signe(int(val.ecart)), "Écart", _couleur_ecart(val), "check" if int(val.ecart) >= 0 else "warning"],
	], COULEUR_SALAIRE)

static func _fenetre_duree(toile: Control, val: Dictionary) -> void:
	_fenetre(toile, "OffreFenetreDuree", "Durée du contrat", [
		[G.contract_year(int(val.premiere) - 1), "Signature", Charte.IVOIRE, "check"],
		["%d an(s)" % int(val.annees), "Ta proposition", COULEUR_DUREE, "calendar"],
		[str(val.fin), "Fin de contrat", COULEUR_DUREE, "flag"],
		["%d à %d ans" % [int(val.min), int(val.max)] if int(val.min) != int(val.max) else "%d an" % int(val.min), "Accepté par le joueur", Pieces.VERT, "people"],
	], COULEUR_DUREE)

static func _fenetre_budget(toile: Control, val: Dictionary) -> void:
	var budget: Dictionary = val.budget
	var fee := maxi(0, int(val.fee))
	var tuiles: Array = []
	if not budget.is_empty():
		var reste := int(budget.get("disponible", 0)) - fee
		tuiles = [
			[G.euros(Budget.season_total(budget)), "Alloués par le conseil", Charte.IVOIRE, "shield"],
			[G.euros(budget.get("depense", 0)), "Déjà engagé", Charte.IVOIRE_2, "lock"],
			[G.euros(fee), "Cette prime", COULEUR_PRIME, "money"],
			[G.euros(reste), "Reste", Pieces.VERT if reste >= 0 else Pieces.ROUGE, "check" if reste >= 0 else "warning"],
		]
	else:
		tuiles = [[G.euros(fee), "Cette prime", COULEUR_PRIME, "money"]]
	if val.cash is int or val.cash is float: tuiles.append([G.euros(val.cash), "Trésorerie", Charte.IVOIRE, "money"])
	_fenetre(toile, "OffreFenetreBudget", "Budget de transferts", tuiles, COULEUR_PRIME)
