extends RefCounted
## Offre au joueur : valeurs de l'offre (demande, proposition, durée, prime, budgets) et petites fenêtres visuelles des
## chiffres, communes à la négociation avec l'agent (negociation_agent.gd, idée 18) et à l'offre guidée (offre_guidee.gd).
## Affichage seul : les champs de saisie (OfferSalary, OfferYears) restent ceux de contract_negotiation.gd.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const G = preload("res://ui/game_skin.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Salary = preload("res://ui/salary_display.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Guidee = preload("res://ui/offre_guidee.gd")
const COULEUR_SALAIRE := Pieces.BLEU
const COULEUR_DUREE := Pieces.VIOLET
const COULEUR_PRIME := Pieces.TURQUOISE

# --- Données ---------------------------------------------------------------------------------------------------------

static func valeurs(ctx: Dictionary) -> Dictionary:
	var quote: Dictionary = ctx.quote
	var propose := Salary.input_weekly(ctx.salary)
	var demande := int(quote.get("salary", propose))
	# Rôle promis choisi (temps de jeu, idée 16) : la demande est celle de ce rôle (moteur : quote.roles, role-contrat.cjs).
	var du_role := demande_du_role(quote, str(ctx.get("role", "")))
	if du_role >= 0: demande = du_role
	var annees := int(ctx.years.value)
	var fee: Variant = quote.get("fee")
	var premiere := int(ctx.first_season)
	# Offre guidée : prime de base + cran choisi, clause choisie (recrutement seulement).
	var en_plus := 0 if ctx.get("prolongation", false) else Guidee.prime_en_plus(ctx, annees)
	var niveau := "sans" if ctx.get("prolongation", false) else str(Guidee.extras(ctx).clause)
	return {
		"propose": propose, "demande": demande, "ecart": propose - demande, "annees": annees,
		"min": int(quote.get("minYears", 1)), "max": maxi(int(quote.get("maxYears", 3)), annees),
		"premiere": premiere, "fin": G.contract_year(premiere + annees - 1),
		"fee": int(fee) + en_plus if fee is int or fee is float else -1, "fee_base": int(fee) if fee is int or fee is float else -1,
		"clause": niveau, "clause_montant": int(Guidee.clause(ctx, niveau).get("montant", 0)),
		"budget": {} if ctx.get("prolongation", false) else Budget.data(ctx.app.model), "cash": ctx.app.model.get("finance", {}).get("cash"),
		"prolongation": bool(ctx.get("prolongation", false)),
		"actuel": int(ctx.player.get("salary", 0)), "fin_actuelle": ctx.player.get("contractEnd"),
	}

## Salaire demandé pour un rôle promis (-1 si le moteur ne le donne pas).
static func demande_du_role(quote: Dictionary, role: String) -> int:
	var roles: Variant = quote.get("roles")
	if role.is_empty() or not (roles is Dictionary) or not (roles.get("liste") is Array): return -1
	for r: Variant in roles.liste:
		if r is Dictionary and str(r.get("role", "")) == role and (r.get("salary") is int or r.get("salary") is float): return int(r.salary)
	return -1

## Écart de salaire au format des salaires affichés (arrondi et période du jeu).
static func hausse(val: Dictionary) -> int:
	return roundi(float(val.propose) / 100.0) * 100 - roundi(float(val.actuel) / 100.0) * 100

static func signe_salaire(valeur: int) -> String:
	return ("+" if valeur >= 0 else "−") + G.salary_amount(absi(valeur))

static func _signe(valeur: int) -> String:
	return ("+" if valeur >= 0 else "−") + G.euros(absi(valeur))

## Couleur de l'écart à la demande : au moins la demande vert, un peu en dessous orange, loin en dessous rouge.
static func _couleur_ecart(val: Dictionary) -> Color:
	if int(val.ecart) >= 0: return Pieces.VERT
	return Pieces.ORANGE if float(-int(val.ecart)) <= .1 * maxf(1.0, float(val.demande)) else Pieces.ROUGE

# --- Dessin ----------------------------------------------------------------------------------------------------------

static func _vider(noeud: Node) -> void:
	for enfant in noeud.get_children():
		noeud.remove_child(enfant)
		enfant.queue_free()

## Habillage déjà conforme à la charte : la page adoptée ne doit pas le reteindre.
static func _marquer(noeud: Node) -> void:
	noeud.set_meta("style_charte", true)
	# Petite fenêtre de jeu (1280 × 720) : chaque cible garde au moins C.TARGET_MIN px, agrandie autour de son centre.
	if noeud is Button:
		var bouton := noeud as Button
		var manque := Vector2(maxf(0.0, C.TARGET_MIN - bouton.size.x), maxf(0.0, C.TARGET_MIN - bouton.size.y))
		if manque != Vector2.ZERO:
			bouton.position -= manque / 2.0
			bouton.size += manque
	for enfant in noeud.get_children(): _marquer(enfant)

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
	var panneau := D.rect(calque, Rect2((taille_toile.x - largeur) / 2, clampf((taille_toile.y - 200) / 2, 10, 150), largeur, 200), Charte.PANNEAU, Charte.RAYON_PANNEAU, couleur)
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
	var tuiles: Array = []
	if val.get("prolongation", false): tuiles.append([G.salary(val.actuel), "Actuel", Charte.IVOIRE, "lock"])
	tuiles.append_array([
		[G.salary(val.demande), "Demande", Pieces.VERT, "money"],
		[G.salary(val.propose), "Ta proposition", COULEUR_SALAIRE, "people"],
		[_signe(int(val.ecart)), "Écart", _couleur_ecart(val), "check" if int(val.ecart) >= 0 else "warning"],
	])
	if val.get("prolongation", false): tuiles.append([signe_salaire(hausse(val)), "vs actuel", Pieces.VERT if hausse(val) <= 0 else Pieces.ORANGE, "renew"])
	_fenetre(toile, "OffreFenetreSalaire", "Salaire " + G.salary_period(true), tuiles, COULEUR_SALAIRE)

static func _fenetre_duree(toile: Control, val: Dictionary) -> void:
	var tuiles: Array = []
	if val.get("prolongation", false): tuiles.append(["—" if val.fin_actuelle == null else G.contract_year(val.fin_actuelle), "Fin actuelle", Charte.IVOIRE, "lock"])
	else: tuiles.append([G.contract_year(int(val.premiere) - 1), "Signature", Charte.IVOIRE, "check"])
	_fenetre(toile, "OffreFenetreDuree", "Durée du contrat", tuiles + [
		["%d an(s)" % int(val.annees), "Ta proposition", COULEUR_DUREE, "calendar"],
		[str(val.fin), "Fin de contrat", COULEUR_DUREE, "flag"],
		["%d à %d ans" % [int(val.min), int(val.max)] if int(val.min) != int(val.max) else "%d an" % int(val.min), "Accepté par le joueur", Pieces.VERT, "people"],
	], COULEUR_DUREE)

static func _essais(ctx: Dictionary) -> int:
	return load("res://ui/contract_negotiation.gd").essais(ctx.get("quote", {}) if ctx.get("quote") is Dictionary else {})

static func _fenetre_discussion(toile: Control, ctx: Dictionary, val: Dictionary) -> void:
	var negociation: Dictionary = ctx.negotiation
	var contre := str(negociation.get("status", "")) == "counter"
	var tentatives := int(negociation.get("attempts", 0))
	_fenetre(toile, "OffreFenetreDiscussion", "La discussion", [
		["%d / %d" % [mini(_essais(ctx), tentatives + 1), _essais(ctx)], "Proposition", COULEUR_SALAIRE, "renew"],
		[G.salary(negociation.get("salary")) if contre else "—", "Contre-offre", Pieces.ORANGE, "mail"],
		[G.salary(val.demande), "Demande", Pieces.VERT, "money"],
	], COULEUR_SALAIRE)

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
	if val.get("prolongation", false) and (val.cash is int or val.cash is float):
		tuiles.append([G.euros(int(val.cash) - fee), "Après la prime", Pieces.VERT if int(val.cash) >= fee else Pieces.ROUGE, "check" if int(val.cash) >= fee else "warning"])
	_fenetre(toile, "OffreFenetreBudget", "Prime de prolongation" if val.get("prolongation", false) else "Budget de transferts", tuiles, COULEUR_PRIME)
