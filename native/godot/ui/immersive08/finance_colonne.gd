extends RefCounted
## Finances : colonne de verdict fixe à gauche des onglets autres que la Synthèse (verdict, trésorerie, budget de transferts, marge, vigilances).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")
const Journal = preload("res://ui/immersive08/finance_journal.gd")

# ---- Verdict ------------------------------------------------------------------------------------------------

static func _verdict_panneau(app: Control, canvas: Control, rectangle: Rect2, v: Dictionary, compact: bool, tab: String) -> void:
	var largeur := rectangle.size.x
	var panel := Brique._panneau(canvas, rectangle, "Verdict" if compact else "Verdict de la semaine", "FinanceVerdict")
	if tab != "budget":
		var ouvrir := Brique._zone(panel, Rect2(0, 0, largeur, rectangle.size.y), func(): F._ouvrir_onglet(app, "budget"), "FinanceVerdictLink", "Voir le budget et ajuster les engagements")
		F._lier(app, ouvrir, F._onglet_cible("budget"), "Ouvrir · Budget")
		panel.move_child(ouvrir, 0)
		# La zone couvre le panneau mais reste sous les libellés (ils laissent passer la souris).
	var palier: int = v.palier
	var mot := Brique._titre(panel, 64, 100, str(v.mot).to_upper(), 42, Charte.IVOIRE, largeur - 318)
	mot.name = "FinanceVerdictWord"
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Brique._symbole(panel, Rect2(20, 68, 34, 34), Brique._forme_palier(palier) if palier >= 0 else "exclam", [Pieces.VERT, Pieces.ORANGE, Pieces.ROUGE][palier] if palier >= 0 else Charte.IVOIRE)
	var palier_texte := "palier %d sur 3" % (palier + 1) if palier >= 0 else "chiffres indisponibles"
	Brique._etiquette(panel, largeur - 20, 96, palier_texte, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var largeur_colonne := (largeur - 40.0 - 16.0) / 3.0
	# Les trois paliers : barre, symbole et mot ; le barème de chacun passe derrière un petit « i ».
	# Sans phrase dessous, le bloc est centré dans le panneau.
	var bas_bloc := 170.0 + (46.0 if v.margin != null else 0.0)
	var decalage := maxf(0.0, (rectangle.size.y - bas_bloc - 60.0) * .5)
	for composant: Node in panel.get_children():
		if composant.name in ["FinanceVerdictLink", "CardTitle"]: continue
		if composant is Control: (composant as Control).position.y += C.px(decalage)
	for i in 3:
		var x := 20.0 + i * (largeur_colonne + 8.0)
		var actif := i == palier
		var teinte: Color = [Pieces.VERT, Pieces.ORANGE, Pieces.ROUGE][i]
		Brique._bloc(panel, Rect2(x, 120 + decalage, largeur_colonne, 10), teinte if actif else Charte.PANNEAU_3)
		Brique._symbole(panel, Rect2(x, 142 + decalage, 20, 20), Brique._forme_palier(i), teinte if actif else Charte.IVOIRE_2)
		D.text(panel, x + 28, 159 + decalage, str(F.PALIERS[i][0]), 20, Charte.IVOIRE if actif else Charte.IVOIRE_2, 700, largeur_colonne - 64).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pieces.info(panel, x + largeur_colonne - 28, 139 + decalage, "%s : %s" % [F.PALIERS[i][0], F.PALIERS[i][1]], "Palier%d" % i)
	# Deux pastilles sous les paliers : marge de la semaine (→ Budget) et autonomie de trésorerie (→ Trésorerie).
	if v.margin != null:
		var marge := float(v.margin)
		var texte_marge := ("▲ +" if marge > 0.0 else "▼ " if marge < 0.0 else "") + U.amount(marge) + " / sem."
		var largeur_marge := Pieces.pastille(panel, 20, 180 + decalage, texte_marge, "", "FinanceVerdictMargin", "", Pieces.ROUGE if marge < 0.0 else Pieces.VERT, Charte.PANNEAU_3, func(): F._vers(app, "budget"))
		var texte_autonomie := "tient la saison" if v.autonomie == null else "tient " + P.plural(int(v.autonomie), "semaine", "semaines")
		var teinte_autonomie: Color = [Pieces.VERT, Pieces.ORANGE, Pieces.ROUGE][palier] if palier >= 0 else Charte.IVOIRE
		Pieces.pastille(panel, 20 + largeur_marge + 10, 180 + decalage, texte_autonomie, "clock", "FinanceVerdictAutonomy", "", teinte_autonomie, Charte.PANNEAU_3, func(): F._vers(app, "cash"))
	panel.accessibility_name = "%s, trésorerie %s" % [v.mot, U.amount(v.cash)]

# ---- Chiffres du haut -----------------------------------------------------------------------------------------

static func _dernieres_depenses(ledger: Array) -> String:
	var parts := PackedStringArray()
	for entry: Dictionary in ledger:
		if parts.size() >= 2: break
		var title := str(entry.get("title", ""))
		if Journal._category(title)[0] != "Contrat" or float(entry.get("amount", 0)) >= 0.0: continue
		var nom := title.get_slice(":", 1).strip_edges() if title.contains(":") else title
		parts.append("%s %s" % [nom, U.amount(absf(float(entry.amount)))])
	return " · ".join(parts)

static func _carte(app: Control, canvas: Control, rectangle: Rect2, id: String, cible: Dictionary, libelle: String, infobulle: String) -> Panel:
	var carte := Brique._panneau(canvas, rectangle, "", id)
	var ouvrir := Brique._zone(carte, Rect2(0, 0, rectangle.size.x, rectangle.size.y), func(): pass, id.replace("FinanceMetric", "FinanceMetricLink"), libelle)
	ouvrir.name = id.replace("FinanceMetric", "FinanceMetricLink")
	F._lier(app, ouvrir, cible, libelle)
	if not infobulle.is_empty(): ouvrir.tooltip_text = infobulle
	return carte

## Détail de la prévision (trésorerie + marge courante + autres apports = prévision), en infobulle de la carte.
static func _projection_reading(finance: Dictionary) -> String:
	var detail: Variant = finance.get("projection")
	if not (detail is Dictionary) or not finance.has("budget"): return "Hors billetterie aléatoire, primes et transferts futurs"
	if absf(float(detail.otherInflows)) < 1.0: return "Trésorerie + marge courante sur %d semaines" % int(detail.remainingWeeks)
	return "Trésorerie %s · marge courante %s · guichet, primes et soutien %s" % [U.amount(detail.cash), U.amount(detail.marginTotal), ("+" if float(detail.otherInflows) > 0.0 else "") + U.amount(detail.otherInflows)]

static func _carte_tresorerie(app: Control, canvas: Control, rectangle: Rect2, accounts: Dictionary, finance: Dictionary, v: Dictionary) -> void:
	# Sur l'onglet Trésorerie, le bloc mène au budget qui explique la prévision de fin de saison.
	var ici := F._onglet_courant(app) == "cash"
	var lecture := _projection_reading(finance)
	var bulle := "Trésorerie du club : prévision de fin de saison, dans l'onglet Budget." if ici else "Trésorerie du club : tous les mouvements et le solde, dans l'onglet Trésorerie."
	var carte := _carte(app, canvas, rectangle, "FinanceMetric0", F._onglet_cible("budget" if ici else "cash"), "Ouvrir · Budget" if ici else "Ouvrir · Trésorerie", bulle + "
" + lecture)
	var decalage := maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var cash: Variant = v.cash
	Brique._titre(carte, 20, 36 + decalage, "TRÉSORERIE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var montant := Brique._titre(carte, 20, 92 + decalage, U.amount(cash), 52, Charte.D if cash != null and float(cash) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40)
	montant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fin de saison prévue : une tuile à droite du montant.
	var prevue: Variant = v.forecast
	Pieces.tuile(carte, Rect2(rectangle.size.x - 20 - 150, 22 + decalage * .5, 150, 62), U.amount(prevue) if prevue != null else "—", "fin de saison", Pieces.ROUGE if prevue != null and float(prevue) < 0.0 else Pieces.VERT, "FinanceProjectionEnd", 26, "", "", false, func(): F._vers(app, "budget"))

static func _carte_budget(app: Control, canvas: Control, rectangle: Rect2, accounts: Dictionary, ledger: Array) -> void:
	var transfer := Budget.data(app.model)
	var marche: Array = app.model.get("market", [])
	var accessibles := marche.filter(func(player: Dictionary): return player.get("available",false))
	var cash: Variant = accounts.get("cash", app.model.club.get("cash"))
	var cible := {"kind":"menu", "route":"Recrutement"}
	var largeur := rectangle.size.x
	var decalage := maxf(0.0, (rectangle.size.y - 160.0) * .5 - 10.0)
	if transfer.is_empty():
		# Carrière sans budget de saison : on garde le marché du recrutement.
		var carte_marche := _carte(app, canvas, rectangle, "FinanceMetric1", cible, "Ouvrir · Recrutement", "%d profils au marché, %d accessibles." % [marche.size(), accessibles.size()])
		Brique._titre(carte_marche, 20, 36 + decalage, "MARCHÉ DU RECRUTEMENT", 22, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._titre(carte_marche, 20, 92 + decalage, "%d profils" % marche.size(), 46, Charte.IVOIRE, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(carte_marche, 20, 124 + decalage, "%d accessibles" % accessibles.size(), 17, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var total := Budget.season_total(transfer)
	var engage := maxi(0, int(transfer.get("depense", 0)) - int(transfer.get("reconstitue", 0)))
	var carte := _carte(app, canvas, rectangle, "FinanceMetric1", cible, "Ouvrir · Recrutement", Budget.detail(transfer, cash) + "\n%d profils au marché, %d accessibles." % [marche.size(), accessibles.size()])
	var titre := Brique._titre(carte, 20, 36 + decalage, "BUDGET DE TRANSFERTS", 22, Charte.IVOIRE_2, largeur - 40)
	titre.name = "CardTitle"
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cellule := (largeur - 40.0 - 16.0) / 3.0
	var valeurs := [["Alloué", G.euros(total), "FinanceTransferBudgetAllocated", Charte.IVOIRE], ["Engagé", G.euros(engage), "FinanceTransferBudgetEngaged", Charte.IVOIRE], ["Restant", Budget.remaining(transfer), "FinanceTransferBudgetAmount", Charte.IVOIRE if int(transfer.get("disponible", 0)) > 0 else Charte.D]]
	for i in 3:
		var x := 20.0 + i * (cellule + 8.0)
		Brique._bloc(carte, Rect2(x, 52 + decalage, cellule, 66))
		Brique._etiquette(carte, x + 10, 72 + decalage, valeurs[i][0], cellule - 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var valeur := Brique._titre(carte, x + 10, 106 + decalage, valeurs[i][1], 28, valeurs[i][3], cellule - 16)
		valeur.name = valeurs[i][2]
		valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var part := 100.0 * float(engage) / float(total) if total > 0 else 0.0
	D.bar(carte, Rect2(20, 128 + decalage, largeur - 40, 8), part, Charte.IVOIRE_2)
	var depenses := _dernieres_depenses(ledger)
	var limite := int(transfer.get("disponible", 0)) < int(transfer.get("reste", transfer.get("disponible", 0)))
	if not limite and depenses.is_empty():
		# Rien d'engagé : une pastille plutôt qu'une phrase.
		# (Le « Engagé 0 € » de la carte le dit déjà : pas de seconde pastille pour la même information.)
		pass
	else:
		var note := "Limité par la caisse du club" if limite else depenses
		Brique._texte(carte, 20, 160 + decalage, note, 16, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _carte_marge(app: Control, canvas: Control, rectangle: Rect2, finance: Dictionary, v: Dictionary) -> void:
	var ici := F._onglet_courant(app) == "budget"
	var carte := _carte(app, canvas, rectangle, "FinanceMetric2", F._onglet_cible("cash" if ici else "budget"), "Ouvrir · Trésorerie" if ici else "Ouvrir · Budget", "Recettes régulières moins charges de la semaine. Ne comprend pas les recettes de match, la prime de classement ni le soutien du propriétaire : voir la trésorerie prévue en fin de saison.")
	var decalage := maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var marge: Variant = v.margin
	Brique._titre(carte, 20, 36 + decalage, "MARGE COURANTE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := "—"
	if marge != null: texte = ("+" if float(marge) > 0.0 else "") + U.amount(marge)
	Brique._titre(carte, 20, 92 + decalage, texte + (" / sem." if marge != null else ""), 42, Charte.D if marge != null and float(marge) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var recettes: Variant = finance.get("weeklyIncome")
	var charges: Variant = finance.get("weeklyCosts")
	var valeurs := [["▲ " + U.amount(recettes), "recettes", "FinanceMarginIncome", Pieces.VERT], ["▼ " + U.amount(charges), "charges", "FinanceMarginCosts", Pieces.ROUGE]]
	# Recettes et charges : deux tuiles à droite de la marge.
	for k in 2: Pieces.tuile(carte, Rect2(rectangle.size.x - 20 - 2 * 124 - 8 + k * 132, 20 + decalage * .5, 124, 62), valeurs[k][0], valeurs[k][1], valeurs[k][3], valeurs[k][2], 22, "", "", false, func(): F._vers(app, "budget"))

# ---- Vigilances et échéances -----------------------------------------------------------------------------------

## Vigilances réelles : contrats à anticiper, devis d'infrastructures, masse salariale proche du plafond de la ligue.
static func _vigilances(app: Control, finance: Dictionary) -> Array:
	var lignes: Array = []
	var counts := P.contract_counts(app.model)
	var count := int(counts.by_horizon)
	if count > 0:
		lignes.append({"id": "FinanceWatchContracts", "titre": "Contrats à anticiper", "detail": "%s · %s en fin de saison · horizon fin %s" % [P.plural(count, "contrat à anticiper", "contrats à anticiper"), counts.end_of_season, G.season_label(counts.horizon_season)], "lien": "Contrats", "action": func(): F._open_wages(app, true), "tuiles": [[str(count), "contrats", "FinanceWatchContractsCount", Pieces.BLEU], [str(counts.end_of_season), "cette saison", "FinanceWatchContractsSeason", Pieces.ORANGE]]})
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		lignes.append({"id": "FinanceWatchFacilities", "titre": "Infrastructures", "detail": "Devis indicatif · " + G.euros(quote.cost), "lien": "Infrastructures", "action": func(): F._strategy(app)})
	var budget: Variant = finance.get("budget")
	if budget is Dictionary and budget.get("plafondSalarial") != null and float(budget.plafondSalarial) > 0.0 and budget.get("masseSalariale") != null:
		var part := roundi(100.0 * float(budget.masseSalariale) / float(budget.plafondSalarial))
		if part >= 80:
			lignes.append({"id": "FinanceWatchCap", "titre": "Masse salariale · joueurs", "detail": "%d %% du plafond de la ligue · marge restante : %s" % [part, U.amount(budget.get("margePlafond"))], "lien": "Budget" if F._onglet_courant(app) == "wages" else "Salaires", "action": func(): F._ouvrir_onglet(app, "budget") if F._onglet_courant(app) == "wages" else F._open_wages(app, false)})
	return lignes

static func _watch(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var lignes := _vigilances(app, finance)
	if not lignes.is_empty(): Brique._etiquette(card, largeur - 20, 38, "%d à traiter" % lignes.size(), 200, HORIZONTAL_ALIGNMENT_RIGHT)
	if lignes.is_empty():
		Brique._symbole(card, Rect2(20, 80, 26, 26), "coche", Charte.IVOIRE)
		Brique._texte(card, 58, 100, "Rien à surveiller cette semaine.", 20, Charte.IVOIRE, largeur - 80)
		return
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var y := 68.0 + i * 76.0
		var zone := Brique._zone(card, Rect2(10, y, largeur - 20, 70), ligne.action, str(ligne.id), "%s · %s" % [ligne.titre, ligne.detail])
		zone.accessibility_name = "%s · %s" % [ligne.titre, ligne.detail]
		Brique._symbole(card, Rect2(20, y + 20, 28, 28), "exclam", Charte.IVOIRE)
		Brique._texte(card, 62, y + 28, str(ligne.titre), 19, Charte.IVOIRE, 184 if ligne.has("tuiles") else largeur - 290).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ligne.has("tuiles"):
			# Compteurs du contrat à anticiper : deux tuiles (au total, et cette saison) au lieu d'une phrase.
			var tuiles: Array = ligne.tuiles
			for k in tuiles.size(): Pieces.tuile(card, Rect2(250 + k * 106, y + 4, 100, 62), tuiles[k][0], tuiles[k][1], tuiles[k][3], tuiles[k][2], 26, "", "", k == 1, func(): F._vers_contrats(app))
		else:
			# Le détail passe sous le lien (aligné sur le titre) et prend toute la largeur : plus de troncature à 1280.
			Brique._texte(card, 62, y + 56, str(ligne.detail), 16, Charte.IVOIRE_2, largeur - 86).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(card, largeur - 24, y + 28, str(ligne.lien) + " →", 17, Charte.IVOIRE, 220, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < lignes.size() - 1: D.line(card, Vector2(20, y + 73), Vector2(largeur - 20, y + 73), Color(Charte.FILET,.7))

# ---- Colonne de verdict fixe (onglets autres que la Synthèse) -------------------------------------------------------

static func _colonne(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary, tab: String) -> void:
	_verdict_panneau(app, canvas, Rect2(0, F.HAUT, F.COLONNE_W, 330), v, true, tab)
	_carte_tresorerie(app, canvas, Rect2(0, 492, F.COLONNE_W, 130), accounts, finance, v)
	_carte_budget(app, canvas, Rect2(0, 634, F.COLONNE_W, 190), accounts, ledger)
	_carte_marge(app, canvas, Rect2(0, 836, F.COLONNE_W, 130), finance, v)
	_watch(Brique._panneau(canvas, Rect2(0, 978, F.COLONNE_W, 252), "Vigilances", "FinanceWatch"), app, finance, F.COLONNE_W)
