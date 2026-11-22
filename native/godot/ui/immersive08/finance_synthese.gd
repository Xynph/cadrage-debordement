extends RefCounted
## Finances › Synthèse « façon Effectif » (choix de Léo du 22/11/2026, option B) : bandeau de cinq tuiles-chiffres
## colorées (sans sous-tuile), trois colonnes de listes à lignes (verdict + vigilances, échéances + transferts, où va
## l'argent), puis la courbe « Solde sur 12 mois ». Mêmes destinations de clic que l'ancienne Synthèse.
## Coordonnées en unités du gabarit (toile 2248 × 1230).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Charte = preload("res://ui/charte.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")

const LARGEUR := 2248.0
const HAUT := 150.0
const Y_SOLDE := 862.0
const TITRE_H := 60.0

## Couleur franche par poste (palette commune de charte.gd), toujours avec un mot, un chiffre ou un signe.
const SALAIRES := Charte.MORAL
const FORMATION := Charte.CONFIANCE
const FONCTIONNEMENT := Charte.INTENSIF
const TRESORERIE := Charte.MORAL
const TRANSFERTS := Charte.REPOS
const GAIN := Charte.GAIN
const PERTE := Charte.PERTE

static func construire(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary) -> void:
	_colonnes(app, canvas, accounts, finance, ledger, v)
	var solde := F._panneau(canvas, Rect2(0, Y_SOLDE, LARGEUR, 1230 - Y_SOLDE), "Solde sur 12 mois", "FinanceSolde")
	_anton(solde)
	F._solde(app, canvas, solde, accounts, LARGEUR)

static func _colonnes(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary) -> void:
	_bandeau_tuiles(app, canvas, Rect2(0, HAUT, LARGEUR, 116), finance, v)
	var y := HAUT + 132.0
	var bas := Y_SOLDE - 16.0
	var c1 := 720.0
	var c2 := 744.0
	var x2 := c1 + 16.0
	var x3 := x2 + c2 + 16.0
	_verdict(app, canvas, Rect2(0, y, c1, 256), v)
	_vigilances(app, canvas, Rect2(0, y + 272, c1, bas - y - 272), finance)
	_echeances(app, canvas, Rect2(x2, y, c2, 256), finance)
	_transferts(app, canvas, Rect2(x2, y + 272, c2, bas - y - 272), accounts, ledger, 56.0)
	_ou_va_l_argent(app, canvas, Rect2(x3, y, LARGEUR - x3, bas - y), finance)

## Bandeau de cinq tuiles-chiffres colorées, sans tuile imbriquée : trésorerie, fin de saison, guichet et soutien,
## marge courante, transferts restants.
static func _bandeau_tuiles(app: Control, canvas: Control, zone: Rect2, finance: Dictionary, v: Dictionary) -> void:
	var transfer := Budget.data(app.model)
	var marge: Variant = v.margin
	var detail: Variant = finance.get("projection")
	var defs := [
		["FinanceMetric0", "TRÉSORERIE", U.amount(v.cash), "", TRESORERIE if v.cash == null or float(v.cash) >= 0.0 else PERTE, "money", _lien_carte(app, F._onglet_cible("cash"), "Ouvrir · Trésorerie")],
		["FinanceProjectionEnd", "FIN DE SAISON PRÉVUE", U.amount(v.forecast), "", PERTE if v.forecast != null and float(v.forecast) < 0.0 else GAIN, "calendar", func(): F._vers(app, "budget"), F._projection_reading(finance)],
	]
	if detail is Dictionary and finance.has("budget") and absf(float(detail.otherInflows)) >= 1.0:
		var autres := float(detail.otherInflows)
		defs.append(["FinanceProjectionBox", "GUICHET · SOUTIEN", ("▲ +" if autres > 0.0 else "▼ ") + U.amount(autres), "saison", GAIN if autres > 0.0 else PERTE, "home", func(): F._vers(app, "budget")])
	defs.append(["FinanceMetric2", "MARGE COURANTE", ("—" if marge == null else ("▲ +" if float(marge) > 0.0 else "▼ " if float(marge) < 0.0 else "") + U.amount(marge)), "/ sem.", PERTE if marge != null and float(marge) < 0.0 else GAIN, "renew", _lien_carte(app, F._onglet_cible("budget"), "Ouvrir · Budget")])
	if not transfer.is_empty():
		defs.append(["FinanceTransfersLeft", "TRANSFERTS RESTANTS", G.euros(transfer.get("disponible", 0)), "", TRANSFERTS if int(transfer.get("disponible", 0)) > 0 else PERTE, "people", _lien_carte(app, {"kind": "menu", "route": "Recrutement"}, "Ouvrir · Recrutement")])
	var ecart := 16.0
	var l := (zone.size.x - ecart * (defs.size() - 1)) / defs.size()
	for i in defs.size():
		_tuile(canvas, Rect2(zone.position.x + i * (l + ecart), zone.position.y, l, zone.size.y), defs[i], 50)

## Échéances de la semaine en liste à lignes (date, échéance, montant signé et coloré).
static func _echeances(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var remaining := int(finance.get("remainingWeeks", 0))
	var week := int(app.model.meta.get("week", 0)) + 1
	var p := _panneau(canvas, zone, "Prochaines échéances", "calendar", "FinanceDue", "", Charte.IVOIRE)
	Pieces.info(p, 58 + _largeur("PROCHAINES ÉCHÉANCES", 28, false, 400, true) + 12, 17, "Chaque ligne se répète jusqu'à la fin de la saison · %d sem." % remaining, "FinanceDueInfo")
	_etiquette(p, zone.size.x - 22, 40, "semaine %d" % week, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var w := zone.size.x
	if remaining <= 0:
		_t(p, 22, TITRE_H + 50, "0 paiement restant", 20, Charte.IVOIRE_2, w - 44)
		return
	_entete_colonnes(p, Rect2(12, TITRE_H, w - 24, 34), [["Date", 22, 100, HORIZONTAL_ALIGNMENT_LEFT], ["Échéance", 130, 300, HORIZONTAL_ALIGNMENT_LEFT], ["Montant", w - 34, 200, HORIZONTAL_ALIGNMENT_RIGHT]])
	var rows := [["Salaires et cotisations" if finance.has("budget") else "Salaires de l’effectif", finance.get("weeklyWages"), func(): F._open_wages(app, false), "Salaires", "people", SALAIRES, -1.0],
		["Centre de formation" if finance.get("budget") is Dictionary else "Formation à la séance", F.formation_weekly(finance), func(): F._vers_formation_ou_budget(app), "Formation" if F._onglet_courant(app) == "budget" else "Budget", "school", FORMATION, -1.0],
		["Recettes régulières hors guichet" if finance.has("budget") else "Recettes prévues au modèle", finance.get("weeklyIncome"), func(): F._ouvrir_onglet(app, "cash"), "Trésorerie", "money", GAIN, 1.0]]
	var h := minf(56.0, (zone.size.y - TITRE_H - 34 - 18) / rows.size())
	for i in rows.size():
		var item: Array = rows[i]
		var y := TITRE_H + 40 + i * h
		_ligne(p, Rect2(12, y, w - 24, h - 2), i, item[2], "FinanceDueRow" + str(i), "Ouvrir · " + str(item[3]))
		var base := y + h / 2.0 + 7.0
		_t(p, 22, base, "Sem. %02d" % week, 18, Charte.IVOIRE_2, 100)
		_icone(p, Rect2(130, y + (h - 24) / 2.0, 24, 24), str(item[4]), item[5])
		_t(p, 166, base, str(item[0]), 20, Charte.IVOIRE, w - 166 - 230)
		_t(p, w - 34, base, _signe(item[1], float(item[6])), 22, GAIN if float(item[6]) > 0.0 else PERTE, 210, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)

## Où va l'argent en liste : poste, barre colorée, montant, part ; puis recettes et charges de la semaine.
static func _ou_va_l_argent(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var p := _panneau(canvas, zone, "Où va l'argent", "money", "FinanceAllocation", "", Charte.IVOIRE)
	_etiquette(p, zone.size.x - 22, 40, "par semaine", 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var w := zone.size.x
	var rows := F._weekly(finance)
	var total := float(finance.get("weeklyCosts", 0))
	var remaining := int(finance.get("remainingWeeks", 0))
	var destinations := [func(): F._open_wages(app, false), func(): F._vers_formation_ou_budget(app), func(): F._strategy(app)]
	var noms := ["Salaires", "Formation" if F._onglet_courant(app) == "budget" else "Budget", "Infrastructures"]
	var couleurs := [SALAIRES, FORMATION, FONCTIONNEMENT]
	_entete_colonnes(p, Rect2(12, TITRE_H, w - 24, 34), [["Poste", 22, 240, HORIZONTAL_ALIGNMENT_LEFT], ["Part", 300, 200, HORIZONTAL_ALIGNMENT_LEFT], ["Montant", w - 112, 160, HORIZONTAL_ALIGNMENT_RIGHT], ["%", w - 34, 70, HORIZONTAL_ALIGNMENT_RIGHT]])
	var y := TITRE_H + 40.0
	var rang := 0
	for i in rows.size():
		var item: Array = rows[i]
		var ratio := float(item[2]) * 100.0 / total if total > 0 and item[2] != null else 0.0
		var reste := "Reste de la saison : %s sur %d sem." % [U.amount(float(item[2]) * remaining) if item[2] != null else "—", remaining]
		_ligne(p, Rect2(12, y, w - 24, 52), rang, destinations[i], "FinanceAllocationRow" + str(i), "Ouvrir · %s. %s" % [noms[i], reste])
		rang += 1
		_icone(p, Rect2(22, y + 14, 24, 24), str(item[1]), couleurs[i])
		_t(p, 56, y + 33, str(item[0]), 20, Charte.IVOIRE, 236)
		_barre(p, Rect2(300, y + 22, w - 300 - 300, 9), ratio, couleurs[i])
		_t(p, w - 112, y + 34, _signe(item[2], -1.0), 22, PERTE, 170, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)
		_t(p, w - 34, y + 34, "%d %%" % roundi(ratio) if total > 0 else "—", 22, couleurs[i], 70, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)
		y += 54.0
		# Salaires des joueurs hors cotisations : sous-ligne de « Salaires et cotisations ».
		if i == 0 and app.model.has("figures"):
			var payroll := P.payroll(app.model)
			_ligne(p, Rect2(12, y, w - 24, 44), rang, func(): F._open_wages(app, false), "FinancePlayersPayroll", "Salaires des joueurs, hors cotisations")
			rang += 1
			D.rect(p, Rect2(34, y + 8, 2, 28), Charte.FILET)
			_t(p, 56, y + 29, "dont joueurs", 18, Charte.IVOIRE_2, 200)
			_t(p, w - 112, y + 29, G.salary_amount(payroll.players_weekly), 20, SALAIRES, 170, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)
			y += 46.0
	y += 10.0
	D.line(p, Vector2(22, y), Vector2(w - 22, y), Color(Charte.FILET, .9))
	y += 10.0
	var recettes: Variant = finance.get("weeklyIncome")
	var charges: Variant = finance.get("weeklyCosts")
	for k in 2:
		var gain := k == 0
		var valeur: Variant = recettes if gain else charges
		_ligne(p, Rect2(12, y, w - 24, 48), rang, func(): F._vers(app, "budget"), "FinanceMarginIncome" if gain else "FinanceMarginCosts", "Ouvrir · Budget")
		rang += 1
		_t(p, 22, y + 32, "▲" if gain else "▼", 20, GAIN if gain else PERTE, 30, HORIZONTAL_ALIGNMENT_LEFT, 700, true)
		_t(p, 56, y + 32, "Recettes" if gain else "Charges", 20, Charte.IVOIRE, 240)
		_t(p, w - 112, y + 33, ("+" if gain else "−") + U.amount(absf(float(valeur))) if valeur != null else "—", 22, GAIN if gain else PERTE, 210, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)
		y += 50.0
	var bas := zone.size.y - 58.0
	var sur_budget := F._onglet_courant(app) == "budget"
	Pieces.pastille(p, 22, bas + 6, "%d semaines prévues" % remaining, "clock", "FinanceForecastWeeks", "", TRANSFERTS, Charte.PANNEAU_3, func(): F._vers(app, "budget"))
	F._bouton(p, Rect2(w - 262, bas + 4, 242, 40), "Ajuster le budget" if sur_budget else "AJUSTER LE BUDGET", func(): F._strategy(app), "lien" if sur_budget else "ivoire", "arrow", "FinanceAdjustBudget")

# --- Pièces --------------------------------------------------------------------------------

## Verdict de la semaine (paliers et deux pastilles validés par Léo), titre en Anton.
static func _verdict(app: Control, canvas: Control, zone: Rect2, v: Dictionary) -> void:
	F._verdict_panneau(app, canvas, zone, v, false, "summary")
	var panneau := canvas.get_node_or_null("FinanceVerdict")
	if panneau != null: _anton(panneau)

## Budget de transferts en trois lignes (alloué, engagé avec sa barre, restant) ; chaque ligne mène au Recrutement.
static func _transferts(app: Control, canvas: Control, zone: Rect2, accounts: Dictionary, ledger: Array, h: float) -> void:
	var transfer := Budget.data(app.model)
	var marche: Array = app.model.get("market", [])
	var accessibles := marche.filter(func(player: Dictionary): return player.get("available", false))
	var cash: Variant = accounts.get("cash", app.model.club.get("cash"))
	var cible := {"kind": "menu", "route": "Recrutement"}
	var w := zone.size.x
	var p := _panneau(canvas, zone, "Transferts" if not transfer.is_empty() else "Marché", "people", "FinanceMetric1", "", Charte.IVOIRE)
	var lignes: Array = []
	if transfer.is_empty():
		lignes = [["Profils au marché", str(marche.size()), Charte.IVOIRE, -1.0, "FinanceMarketCount"], ["Accessibles", str(accessibles.size()), TRANSFERTS, -1.0, "FinanceMarketAvailable"]]
	else:
		var total := Budget.season_total(transfer)
		var engage := maxi(0, int(transfer.get("depense", 0)) - int(transfer.get("reconstitue", 0)))
		var part := 100.0 * float(engage) / float(total) if total > 0 else 0.0
		lignes = [["Alloué", G.euros(total), Charte.IVOIRE, -1.0, "FinanceTransferBudgetAllocated"], ["Engagé", G.euros(engage), FONCTIONNEMENT if engage > 0 else Charte.IVOIRE_2, part, "FinanceTransferBudgetEngaged"], ["Restant", Budget.remaining(transfer), TRANSFERTS if int(transfer.get("disponible", 0)) > 0 else PERTE, -1.0, "FinanceTransferBudgetAmount"]]
		# État de l'engagement : pastille à droite du titre (« 0 € engagé » → Transferts, ou limite de la caisse).
		var depenses := F._dernieres_depenses(ledger)
		var limite := int(transfer.get("disponible", 0)) < int(transfer.get("reste", transfer.get("disponible", 0)))
		if limite:
			var lp := Pieces.largeur_pastille("Limité par la caisse", "warning")
			Pieces.pastille(p, w - 20 - lp, 13, "Limité par la caisse", "warning", "FinanceTransferLimited", Budget.detail(transfer, cash), Charte.INTENSIF, Charte.PANNEAU_3, func(): F._vers(app, "transfers"))
		elif depenses.is_empty():
			var lz := Pieces.largeur_pastille("0 € engagé", "check")
			Pieces.pastille(p, w - 20 - lz, 13, "0 € engagé", "check", "FinanceNothingCommitted", "", GAIN, Charte.PANNEAU_3, func(): F._vers(app, "transfers"))
	var bulle := (Budget.detail(transfer, cash) + "\n" if not transfer.is_empty() else "") + "%d profils au marché, %d accessibles." % [marche.size(), accessibles.size()]
	var rh := minf(h, (zone.size.y - TITRE_H - 10) / maxi(1, lignes.size()))
	for i in lignes.size():
		var l: Array = lignes[i]
		var y := TITRE_H + 2 + i * rh
		var zone_ligne := _ligne(p, Rect2(12, y, w - 24, rh - 2), i, func(): pass, "FinanceTransferRow%d" % i, bulle)
		F._lier(app, zone_ligne, cible, "Ouvrir · Recrutement")
		zone_ligne.tooltip_text = bulle
		var base := y + rh / 2.0 + 7.0
		_t(p, 22, base, str(l[0]), 20, Charte.IVOIRE, 180)
		if float(l[3]) >= 0.0: _barre(p, Rect2(200, y + rh / 2.0 - 4, w - 200 - 250, 9), float(l[3]), FONCTIONNEMENT)
		var valeur := _t(p, w - 24, base + 1, str(l[1]), 24, l[2], 220, HORIZONTAL_ALIGNMENT_RIGHT, 800, false)
		valeur.name = str(l[4])

## Vigilances en lignes : point d'exclamation orange, titre, pastilles des compteurs, flèche ; vide = une coche.
static func _vigilances(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var lignes := F._vigilances(app, finance)
	var w := zone.size.x
	var p := _panneau(canvas, zone, "Vigilances", "warning", "FinanceWatch", str(lignes.size()) if not lignes.is_empty() else "", Charte.INTENSIF)
	if lignes.is_empty():
		F._symbole(p, Rect2(22, TITRE_H + 14, 26, 26), "coche", GAIN)
		_t(p, 60, TITRE_H + 34, "0 à traiter", 20, GAIN, w - 80, HORIZONTAL_ALIGNMENT_LEFT, 700)
		return
	var h := minf(56.0, (zone.size.y - TITRE_H - 10) / lignes.size())
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var y := TITRE_H + 2 + i * h
		var zone_ligne := _ligne(p, Rect2(12, y, w - 24, h - 2), i, ligne.action, str(ligne.id), "%s · %s" % [ligne.titre, ligne.detail])
		zone_ligne.accessibility_name = "%s · %s" % [ligne.titre, ligne.detail]
		F._symbole(p, Rect2(22, y + (h - 24) / 2.0, 24, 24), "exclam", Charte.INTENSIF)
		var titre := str(ligne.titre)
		var lt := minf(_largeur(titre, 19), w - 300)
		_t(p, 58, y + h / 2.0 + 7, titre, 19, Charte.IVOIRE, lt + 4)
		var x := 58 + lt + 16
		var py := y + (h - 34) / 2.0
		if ligne.has("tuiles"):
			for k in ligne.tuiles.size():
				var t: Array = ligne.tuiles[k]
				x += Pieces.pastille(p, x, py, "%s %s" % [t[0], t[1]], "", str(t[2]), "", t[3], Charte.PANNEAU_3, func(): F._vers_contrats(app)) + 8
		else:
			Pieces.pastille(p, x, py, str(ligne.detail), "", str(ligne.id) + "Detail", "", Charte.INTENSIF, Charte.PANNEAU_3)
		_icone(p, Rect2(w - 46, y + (h - 22) / 2.0, 22, 22), "arrow", Charte.IVOIRE_2)

## Tuile-chiffre cliquable du bandeau : léger fond de la couleur du chiffre, liseré gauche, intitulé en capitales,
## pictogramme teinté, chiffre coloré, suffixe.
static func _tuile(parent: Control, zone: Rect2, d: Array, taille: int) -> void:
	var couleur: Color = d[4]
	var fond := Charte.PANNEAU.lerp(couleur, .13)
	var tuile := Button.new()
	tuile.name = str(d[0])
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [d[1], d[2], d[3]]
	# Infobulle : la lecture de la prévision quand la tuile en porte une (fin de saison), sinon le libellé.
	tuile.tooltip_text = str(d[7]) if d.size() > 7 else tuile.accessibility_name
	tuile.add_theme_stylebox_override("normal", Charte.ombrer(_plat(fond, 12), Charte.RAYON_CARTE))
	tuile.add_theme_stylebox_override("hover", Charte.ombrer(_plat(fond.lightened(.06), 12), Charte.RAYON_CARTE))
	tuile.add_theme_stylebox_override("pressed", _plat(fond.lightened(.1), 12))
	var focus := _plat(Color.TRANSPARENT, 12)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	parent.add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(Charte.RAYON_CARTE))
	D.rect(tuile, Rect2(0, 14, 5, zone.size.y - 28), couleur, 3)
	var gauche := 22.0
	_t(tuile, gauche, 36, str(d[1]), 18, Charte.IVOIRE_2, zone.size.x - gauche - 40, HORIZONTAL_ALIGNMENT_LEFT, 700, false)
	_icone(tuile, Rect2(zone.size.x - 38, 16, 22, 22), str(d[5]), couleur)
	var base := zone.size.y - 22.0
	var v := _t(tuile, gauche, base, str(d[2]), taille, couleur, zone.size.x - gauche - 12, HORIZONTAL_ALIGNMENT_LEFT, 800, false)
	v.add_theme_font_override("font", Charte.TITRE_EXTRA)
	v.name = str(d[0]) + "Valeur"
	if not str(d[3]).is_empty():
		var l := _largeur(str(d[2]), taille, false, 800)
		_t(tuile, gauche + l + 10, base - 3, str(d[3]), 18, Charte.IVOIRE_2, zone.size.x - l - gauche - 20)
	var action: Variant = d[6]
	if action is Callable: tuile.pressed.connect(action)

## Lien d'une carte de main (Link.bind) rendu en Callable : même destination que la carte d'origine.
static func _lien_carte(app: Control, cible: Dictionary, _libelle: String) -> Callable:
	return func():
		if is_instance_valid(app.navigation_controller): app.navigation_controller.open_entity(cible.duplicate(true), null)

## Panneau de la Synthèse (rayon des Finances) avec titre Anton, pictogramme et compteur coloré.
static func _panneau(parent: Control, zone: Rect2, titre: String, icone_id: String, id: String, compte: String, couleur_compte: Color) -> Panel:
	var p := F._panneau(parent, zone, "", id)
	_icone(p, Rect2(20, 17, 26, 26), icone_id, Charte.IVOIRE_2)
	var t := _t(p, 58, 42, titre.to_upper(), 28, Charte.IVOIRE, zone.size.x - 260, HORIZONTAL_ALIGNMENT_LEFT, 400, false)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "CardTitle"
	if not compte.is_empty():
		var c := _t(p, 58 + _largeur(titre.to_upper(), 28, false, 400, true) + 14, 43, compte, 28, couleur_compte, 120, HORIZONTAL_ALIGNMENT_LEFT, 800, false)
		c.add_theme_font_override("font", Charte.TITRE_EXTRA)
	return p

## Titre de panneau de main (CardTitle) passé en Anton.
static func _anton(panneau: Node) -> void:
	var titre := panneau.get_node_or_null("CardTitle") as Label
	if titre != null: titre.add_theme_font_override("font", Charte.TITRE_FICHE)

## Bande des en-têtes de colonnes : [libellé, x d'ancrage, largeur, alignement].
static func _entete_colonnes(parent: Control, zone: Rect2, colonnes: Array) -> void:
	var bande := Panel.new()
	bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := _plat(Charte.BANDEAU_ENTETE, 6)
	s.border_color = Charte.BANDEAU_BORD
	s.set_border_width_all(1)
	bande.add_theme_stylebox_override("panel", s)
	parent.add_child(bande)
	D.place(bande, zone)
	for col: Array in colonnes:
		_t(parent, col[1], zone.position.y + zone.size.y / 2.0 + 6, str(col[0]).to_upper(), 16, Charte.IVOIRE_3, col[2], col[3], 700, false)

## En-tête de groupe (comme « AVANTS 16 » de l'Effectif) : repère coloré, titre, montant coloré. Renvoie le y suivant.
## Ligne cliquable : survol commun (bande claire + liseré club), rayure une ligne sur deux (rang dans sa liste).
static func _ligne(parent: Control, zone: Rect2, rang: int, action: Callable, id: String, bulle: String) -> Button:
	var b := F._zone(parent, zone, action, id, bulle, true)
	var fond := b.get_node_or_null("SurvolLigne")
	if fond != null:
		fond.rang_fixe = rang
		fond.queue_redraw()
	return b

static func _barre(parent: Control, zone: Rect2, part: float, couleur: Color) -> void:
	D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	if part > 0.0: D.rect(parent, Rect2(zone.position, Vector2(maxf(zone.size.y, zone.size.x * clampf(part / 100.0, 0.0, 1.0)), zone.size.y)), couleur, Charte.RAYON_PILULE)

static func _icone(parent: Control, zone: Rect2, id: String, couleur: Color) -> void:
	var i := C.icon(id, int(zone.size.x), couleur)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(i)
	D.place(i, zone)

static func _t(parent: Node, x: float, base: float, valeur: Variant, taille: int, couleur: Color, largeur: float = 0.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, graisse: int = 500, corps: bool = true) -> Label:
	var l := D.text(parent, x, base, valeur, taille, couleur, graisse, largeur, align, corps)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _etiquette(parent: Node, x: float, base: float, valeur: String, largeur: float, align: HorizontalAlignment) -> void:
	_t(parent, x, base, valeur.to_upper(), 15, Charte.IVOIRE_2, largeur, align, 600, false)

## Largeur (unités) d'un texte : corps (DM Sans), Barlow Condensed de graisse `graisse`, ou Anton (`anton`).
static func _largeur(t: String, taille: int, corps: bool = true, graisse: int = 600, anton: bool = false) -> float:
	var police: Font = Charte.TITRE_FICHE if anton else (C.BODY if corps else C.font(graisse))
	return police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

static func _plat(fond: Color, rayon: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(maxi(2, C.px(rayon)))
	s.anti_aliasing = true
	return s

## Montant signé : `sens` < 0 charge (−), > 0 recette (+), 0 signe du montant.
static func _signe(valeur: Variant, sens: float) -> String:
	if valeur == null: return "—"
	var x := float(valeur)
	if is_zero_approx(x): return G.euros(0)
	var negatif := sens < 0.0 or (sens == 0.0 and x < 0.0)
	return ("−" if negatif else "+") + G.euros(absf(x))

