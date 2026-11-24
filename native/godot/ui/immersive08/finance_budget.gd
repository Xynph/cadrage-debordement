extends RefCounted
## Finances › Budget : engagements, leviers, budget de saison, répartition des charges et échéances.
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")

## Répartition des charges : chaque ligne ouvre l'écran qui la détaille (salaires, budget, infrastructures).
static func _allocation(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var rows := F._weekly(finance)
	var total := float(finance.get("weeklyCosts",0))
	var remaining := int(finance.get("remainingWeeks",0))
	var destinations := [func(): F._open_wages(app, false), func(): F._vers_formation_ou_budget(app), func(): F._strategy(app)]
	var noms := ["Salaires", "Formation" if F._onglet_courant(app) == "budget" else "Budget", "Infrastructures"]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 70.0 + i * 74.0
		var ratio := float(item[2])*100.0/total if total > 0 and item[2] != null else 0.0
		var reste := "Reste de la saison : %s sur %d sem." % [U.amount(float(item[2])*remaining) if item[2] != null else "—", remaining]
		Brique._zone(card, Rect2(10, y - 4, largeur - 20, 66), destinations[i], "FinanceAllocationRow" + str(i), "Ouvrir · %s. %s" % [noms[i], reste])
		D.text(card, 22, y + 24, item[0], 22, Charte.IVOIRE, 600, largeur - 330).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.bar(card, Rect2(22, y + 40, largeur - 44, 9), ratio, Charte.IVOIRE_2)
		D.text(card, largeur - 22, y + 24, "%d %%" % roundi(ratio) if total > 0 else "—", 22, Charte.IVOIRE, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(card, largeur - 116, y + 24, G.euros(item[2]) if item[2] != null else "—", 19, Charte.IVOIRE_2, 500, 150, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deux mesures salariales distinctes : la charge versée (avec cotisations, comme l'écran Club) et les salaires des contrats.
	if app.model.has("figures"):
		var payroll := P.payroll(app.model)
		Pieces.tuile(card, Rect2(22, 296, 190, 66), G.salary_amount(payroll.players_weekly), "joueurs", Pieces.BLEU, "FinancePlayersPayroll", 26, "Salaires des joueurs, hors cotisations", "", false, func(): F._open_wages(app, false))
	Pieces.tuile(card, Rect2(22 + (200 if app.model.has("figures") else 0), 296, 140, 66), "%d" % remaining, "semaines prévues", Pieces.TURQUOISE, "FinanceForecastWeeks", 26, "Engagements connus · prévision sur %d sem." % remaining, "", false, func(): F._vers(app, "budget"))
	# Un seul bouton ivoire par écran : sur l'onglet Budget, c'est « Ouvrir les décisions financières » ; ici un lien.
	var sur_budget := F._onglet_courant(app) == "budget"
	Brique._bouton(card, Rect2(largeur - 262, 334, 242, 38), "Ajuster le budget" if sur_budget else "AJUSTER LE BUDGET", func(): F._strategy(app), "lien" if sur_budget else "ivoire", "arrow", "FinanceAdjustBudget")

static func _due(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var remaining := int(finance.get("remainingWeeks",0))
	var week := int(app.model.meta.get("week",0)) + 1
	Brique._etiquette(card, largeur - 20, 38, "semaine %d" % week, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	Brique._info_titre(card, "Prochaines échéances", "Chaque ligne se répète jusqu'à la fin de la saison · %d sem." % remaining, "FinanceDueInfo")
	if remaining <= 0:
		Brique._texte(card, 22, 119, "Aucun paiement restant", 20, Charte.IVOIRE_2, largeur - 44)
		return
	Brique._etiquette(card, 22, 84, "Date", 100)
	Brique._etiquette(card, 140, 84, "Échéance", 300)
	Brique._etiquette(card, largeur - 22, 84, "Montant", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	var rows := [["Salaires et cotisations" if finance.has("budget") else "Salaires de l’effectif", finance.get("weeklyWages"), func(): F._open_wages(app, false), "Salaires"],
		["Centre de formation" if finance.get("budget") is Dictionary else "Formation à la séance", F.formation_weekly(finance), func(): F._vers_formation_ou_budget(app), "Formation" if F._onglet_courant(app) == "budget" else "Budget"],
		["Recettes régulières hors guichet" if finance.has("budget") else "Recettes prévues au modèle", finance.get("weeklyIncome"), func(): F._ouvrir_onglet(app, "cash"), "Trésorerie"]]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 96.0 + i * 52.0
		Brique._zone(card, Rect2(10, y, largeur - 20, 48), item[2], "FinanceDueRow" + str(i), "Ouvrir · " + str(item[3]), true)
		Brique._texte(card, 22, y + 31, "Sem. %02d" % week, 17, Charte.IVOIRE_2, 110).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(card, 140, y + 31, str(item[0]), 19, Charte.IVOIRE, largeur - 360).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var amount: Variant = item[1]
		var prefix := "−" if i < 2 else "+"
		Brique._texte(card, largeur - 22, y + 31, prefix + G.euros(absf(float(amount))) if amount != null and float(amount) != 0.0 else G.euros(amount) if amount != null else "—", 19, Charte.IVOIRE, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---- Budget -------------------------------------------------------------------------------------------------

# Leviers de redressement (consultatifs) : le verdict du directeur financier, puis les leviers réels et ce
# que chacun rapporte à la prévision ; le détail complet de chaque levier est dans l'infobulle.
static func _levers(card: Panel, levers: Dictionary, largeur: float, y: float) -> float:
	var state := str(levers.get("etat",""))
	var verdict_texte := Brique._texte(card, 25, y, str(levers.get("conclusion","")), 20, Charte.IVOIRE, largeur - 50)
	verdict_texte.name = "FinanceLeversVerdict"
	var items: Array = levers.get("leviers", [])
	if items.is_empty():
		return y + 4.0
	var parts := PackedStringArray()
	var details := PackedStringArray()
	for item: Dictionary in items:
		var gain := float(item.get("effet",0))
		parts.append("%s%s" % [str(item.get("titre","")), " (+%s)" % G.euros(gain) if gain > 0.0 else ""])
		details.append("%s : %s" % [str(item.get("titre","")), str(item.get("contrepartie",""))])
	var line := Brique._texte(card, 25, y + 34, "Leviers : " + " · ".join(parts), 19, Charte.IVOIRE_2, largeur - 50)
	line.name = "FinanceLeversList"
	line.tooltip_text = "\n".join(details)
	if state.is_empty(): return y + 40.0
	return y + 40.0

# Budget de saison : quatre tuiles chiffre + légende courte (mécène, masse salariale, résultat prévu, prime ou amende),
# puis les repères de la ligue en pastilles. Le détail (« comble jusqu'à… », plafond, marges) est dans l'infobulle de chaque pièce.
# Gain en vert, perte en rouge : le signe (+ / −) ou le mot porte aussi l'information, jamais la couleur seule.
static func _season_budget(card: Panel, budget: Dictionary, largeur: float, y: float, app: Control) -> void:
	var owner: Dictionary = budget.get("proprietaire", {})
	var envelope := float(owner.get("enveloppe",0))
	var libelle := str(owner.get("libelle","—"))
	var comble := "%s : comble jusqu’à %s de pertes cette saison" % [libelle, U.amount(envelope)] if envelope > 0.0 else "%s : aucune perte comblée, chaque euro dépensé doit être gagné" % libelle
	var salaires := "Masse salariale : %s par an" % U.amount(budget.get("masseSalariale"))
	var resultat: Variant = budget.get("resultatPrevu")
	var prevu := "Saison prévue : recettes %s · charges %s · résultat %s" % [U.amount(budget.get("recettesPrevues")),U.amount(budget.get("chargesPrevues")),U.amount(resultat)]
	var fine := float(budget.get("amendePrevue",0))
	var prime: Variant = budget.get("primeClassementPrevue")
	var tuiles: Array = [
		[U.amount(envelope), libelle, Charte.IVOIRE, "FinanceSeasonBudgetOwner", comble, func(): F._vers(app, "cash")],
		[U.amount(budget.get("masseSalariale")), "Masse / an", Charte.IVOIRE, "FinanceSeasonBudgetPayroll", salaires, func(): F._open_wages(app, false)],
		[("+" if resultat != null and float(resultat) > 0.0 else "") + U.amount(resultat), "Résultat prévu", Pieces.VERT if resultat != null and float(resultat) >= 0.0 else (Pieces.ROUGE if resultat != null else Charte.IVOIRE), "FinanceSeasonBudgetResult", prevu, func(): F._vers(app, "cash")],
	]
	if fine > 0.0:
		tuiles.append(["−" + U.amount(fine), "Amende ligue", Pieces.ROUGE, "FinanceSeasonBudgetFine", "Amende de la ligue encourue : %s" % U.amount(fine), func(): F._open_wages(app, false)])
	else:
		tuiles.append(["+" + U.amount(prime), "Prime classement", Pieces.VERT, "FinanceSeasonBudgetBonus", "Aucune amende de la ligue encourue · prime de classement attendue %s" % U.amount(prime), func(): app._navigate("Classements")])
	var ecart := 12.0
	var tuile_w := (largeur - 50.0 - ecart * 3.0) / 4.0
	for i in tuiles.size():
		var item: Array = tuiles[i]
		var tuile := Pieces.tuile(card, Rect2(25 + i * (tuile_w + ecart), y, tuile_w, 84), item[0], item[1], item[2], item[3], 30, item[4], "info", item[2] != Charte.IVOIRE, item[5])
		tuile.tooltip_text = item[4]
	# Repères de la ligue : plafond salarial, limite de 52 % des recettes, recettes et charges prévues.
	var x := 25.0
	var ligne := y + 96.0
	var reperes: Array = []
	if budget.get("plafondSalarial") != null:
		reperes.append(["Plafond %s · marge %s" % [U.amount(budget.plafondSalarial), U.amount(budget.get("margePlafond"))], "shield", "FinanceSeasonBudgetCap", "Plafond salarial de la ligue %s, marge %s" % [U.amount(budget.plafondSalarial), U.amount(budget.get("margePlafond"))], Pieces.VERT if float(budget.get("margePlafond", 0)) >= 0.0 else Pieces.ROUGE])
	if budget.get("limiteRecettes") != null:
		reperes.append(["52 %% recettes %s · marge %s" % [U.amount(budget.limiteRecettes), U.amount(budget.get("margeRecettes"))], "shield", "FinanceSeasonBudgetRevenueLimit", "Limite de 52 %% des recettes %s, marge %s" % [U.amount(budget.limiteRecettes), U.amount(budget.get("margeRecettes"))], Pieces.VERT if float(budget.get("margeRecettes", 0)) >= 0.0 else Pieces.ROUGE])
	reperes.append(["Recettes %s" % U.amount(budget.get("recettesPrevues")), "arrow", "FinanceSeasonBudgetIncome", "Recettes prévues sur la saison", Pieces.VERT])
	reperes.append(["Charges %s" % U.amount(budget.get("chargesPrevues")), "arrow", "FinanceSeasonBudgetCosts", "Charges prévues sur la saison", Pieces.ROUGE])
	for repere: Array in reperes:
		if x + Pieces.largeur_pastille(repere[0], repere[1]) > largeur - 25.0: break
		x += Pieces.pastille(card, x, ligne, repere[0], repere[1], repere[2], repere[3], repere[4], Charte.PANNEAU_3, func(): F._vers(app, "cash")) + 10.0

static func _budget(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var x := zone.position.x
	var y0 := zone.position.y
	var largeur := zone.size.x
	var decisions := Brique._panneau(canvas, Rect2(x, y0, largeur, 600), "Engagements et investissements", "FinanceCommitments", "%d semaines restantes sur %d" % [int(finance.get("remainingWeeks",0)),int(finance.get("weeksPerSeason",0))])
	var cards := [["Formation","Investissement par séance",finance.get("academyInvestment"),func(): app._navigate("Formation"),"Formation"],["Installations","Niveau indisponible",null,func(): F._strategy(app),"Infrastructures"],["Partenaires","Recettes hebdomadaires du modèle",finance.get("weeklyIncome"),func(): F._ouvrir_onglet(app, "cash"),"Trésorerie"]]
	if finance.get("budget") is Dictionary and finance.budget.get("centreFormationHebdo") != null:
		cards[0][1] = "Centre de formation / sem." + (" · dont %s en plus" % U.amount(finance.get("academyInvestment")) if float(finance.get("academyInvestment", 0)) > 0.0 else "")
		cards[0][2] = F.formation_weekly(finance)
	if finance.get("budget") is Dictionary: cards[2] = ["Recettes régulières","Recettes / sem.",finance.get("weeklyIncome"),func(): F._ouvrir_onglet(app, "cash"),"Trésorerie"]
	var facility: Variant = finance.get("facility")
	if facility is Dictionary:
		cards[1][1] = "Niveau %s / 10 · devis" % G.n(facility.level)
		cards[1][2] = facility.cost
	var tuile_w := (largeur - 40.0 - 32.0) / 3.0
	for i in cards.size():
		var item: Array = cards[i]
		var tuile := Brique._panneau(decisions, Rect2(20 + i * (tuile_w + 16), 76, tuile_w, 150), "", "FinanceCommitment" + str(i))
		Brique._zone(tuile, Rect2(0, 0, tuile_w, 150), item[3], "FinanceCommitmentLink" + str(i), "Ouvrir · " + str(item[4]))
		Brique._etiquette(tuile, 18, 34, item[0], tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 1 and not facility is Dictionary:
			Brique._titre(tuile, 18, 90, "Aucun devis disponible", 28, Charte.IVOIRE, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			Brique._titre(tuile, 18, 92, U.amount(item[2]), 44, Charte.IVOIRE, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(tuile, 18, 126, item[1], 16, Charte.IVOIRE_2, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var levers: Variant = finance.get("levers")
	var suite := 280.0
	if levers is Dictionary:
		suite = _levers(decisions, levers, largeur, suite)
	else:
		suite += 4.0
	Brique._bouton(decisions, Rect2(25, suite + 10, 440, 46), "OUVRIR LES DÉCISIONS FINANCIÈRES", func(): F._strategy(app), "ivoire", "arrow", "FinanceBudgetDecisions")
	if finance.get("budget") is Dictionary: _season_budget(decisions, finance.budget, largeur, suite + 100.0, app)
	var bas := y0 + 616.0
	_allocation(Brique._panneau(canvas, Rect2(x, bas, 800, F.BAS - bas), "Répartition des charges connues", "FinanceAllocation", "par semaine"), app, finance, 800)
	_due(Brique._panneau(canvas, Rect2(x + 816, bas, largeur - 816, F.BAS - bas), "Prochaines échéances", "FinanceDue"), app, finance, largeur - 816)
