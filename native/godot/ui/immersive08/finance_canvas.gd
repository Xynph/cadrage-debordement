extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const KEY = "immersive08_finance_tab"
const TABS = [["summary","Synthèse"],["cash","Trésorerie"],["wages","Salaires"],["transfers","Transferts"],["budget","Budget"]]
const CHART_GREEN = Color("53cd75")
const CHART_RED = Color("ee7970")

class LedgerPlot extends Control:
	var operations: Array = []
	var minimum := 0.0
	var maximum := 1.0
	var cumulative := PackedFloat64Array()

	func set_operations(visible_operations: Array) -> void:
		operations = visible_operations.duplicate()
		operations.reverse()
		var net := 0.0
		for entry: Dictionary in operations:
			var amount := float(entry.get("amount", 0))
			net += amount
			cumulative.append(net)
			minimum = minf(minimum, net)
			maximum = maxf(maximum, maxf(absf(amount),net))
		queue_redraw()

	func _height(value: float) -> float:
		return size.y * (maximum - value) / (maximum - minimum)

	func _draw() -> void:
		for i in 6:
			var y := size.y * i / 5.0
			draw_line(Vector2(0,y), Vector2(size.x,y), Color(C.LINE,.57))
		draw_line(Vector2.ZERO, Vector2(0,size.y), C.MUTED)
		if operations.is_empty(): return
		var zero := _height(0)
		draw_line(Vector2(0,zero), Vector2(size.x,zero), C.MUTED)
		var stride := size.x / maxi(12,operations.size())
		var points := PackedVector2Array()
		for i in operations.size():
			var value := float(operations[i].get("amount",0))
			var x := size.x - stride * (operations.size()-i-.5)
			var top := _height(absf(value))
			var shade := CHART_GREEN if value >= 0 else CHART_RED
			if value != 0:
				draw_rect(Rect2(x-stride*.19,top,stride*.38,zero-top), shade)
			points.append(Vector2(x,_height(cumulative[i])))
		if points.size() > 1: draw_polyline(points,C.IVORY,maxf(1,C.px(3)),true)
		for point in points:
			draw_circle(point, C.px(7), C.BG)
			draw_circle(point, C.px(5), C.IVORY)

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveFinance"
	var tab := str(app.management_ui.get(KEY,"summary"))
	var accounts: Dictionary = app.model.get("finance", {})
	var finance: Dictionary = U.strategy(app.model).get("finance", {})
	var ledger: Array = accounts.get("ledger", app.model.get("ledger", []))
	_header(app, canvas, tab)
	_metrics(app, canvas, accounts, finance)
	match tab:
		"cash": _cash(app, canvas, ledger)
		"wages": _wages(app, canvas, finance)
		"transfers": _transfers(app, canvas, ledger)
		"budget": _budget(app, canvas, finance)
		_: _summary(app, canvas, finance, ledger)
	_footer(app, canvas, finance)

static func hospitality(parent: Node, rectangle: Rect2) -> void:
	var image := C.photo("finance-hospitality", Vector2.ZERO, true, .5) as C.ArtTexture
	if image.source != null:
		# Garder la terrasse et le terrain à droite de l’écusson de la maquette.
		var crop := AtlasTexture.new()
		crop.atlas = image.source
		crop.region = Rect2(265, 34, 324, 92)
		image.source = crop
		image.texture = crop
	parent.add_child(image)
	D.place(image, rectangle)

static func _header(app: Control, canvas: Control, tab: String) -> void:
	hospitality(canvas, Rect2(1370,0,878,185))
	U.art_fade(canvas, Rect2(1370,0,185,185))
	D.chip(canvas, Rect2(2005,11,147,26), "ILLUSTRATION", C.GOLD).name = "FinanceHospitalityIllustration"
	D.text(canvas, 2, 38, "L’ÉQUILIBRE DU PROJET", 31, C.GOLD, 700, 400)
	D.line(canvas, Vector2(329,23), Vector2(650,23), Color(C.GOLD,.65))
	U.italic(D.text(canvas, 7, 106, "Garder une longueur d’avance.", 76, C.IVORY, 800, 1280), 800)
	var period := D.rect(canvas, Rect2(940,36,408,76), Color("101c19"), 5, Color(C.MINT,.7))
	U.icon(period, "calendar", Vector2(18,19), C.GOLD, 28)
	var week := int(app.model.meta.get("week",0)) + 1
	var stage := "BILAN" if app.model.meta.get("phase","") == "ended" else "SEM. %d" % week
	D.text(period, 57, 37, "SAISON %s  ·  %s" % [G.n(app.model.meta.get("season",1)),stage], 31, C.IVORY, 700, 329)
	D.text(period, 57, 63, P.league_name(app.model), 22, C.MUTED, 500, 322)
	for i in TABS.size():
		var key: String = TABS[i][0]
		var id := "FinanceTab_" + key
		U.tab(canvas, Rect2(i*273,130,264,51), TABS[i][1], key == tab, func(): U.select(app, KEY, key, id), id)

static func _metrics(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary) -> void:
	var cash: Variant = accounts.get("cash",app.model.club.get("cash"))
	var wages: Variant = accounts.get("wage",finance.get("weeklyWages"))
	var margin: Variant = float(finance.weeklyIncome)-float(finance.weeklyCosts) if finance.has("weeklyIncome") and finance.has("weeklyCosts") else null
	var market: Array = app.model.get("market", [])
	var available := market.filter(func(player: Dictionary): return player.get("available",false))
	var captions := [
		["Trésorerie", "money", U.amount(cash), "Montants de jeu", C.ALERT if cash != null and float(cash)<0.0 else C.MINT],
		["Marché du recrutement", "search", "%d profils" % market.size(), "%d accessibles" % available.size(), C.MINT],
		["Masse salariale", "people", U.amount(wages), "par semaine", C.MINT],
		["Marge hebdomadaire connue", "shield", U.amount(margin), "Recettes − charges", C.AMBER if margin != null and float(margin)<0.0 else C.MINT]
	]
	for i in captions.size():
		var item: Array = captions[i]
		var card := D.panel(canvas, Rect2(i*566,195,550,135), item[0], item[1], "", "FinanceMetric"+str(i))
		D.text(card, 23, 111, item[2], 54, item[4], 800, 323)
		D.chip(card, Rect2(346,70,181,46), item[3], item[4])

static func _summary(app: Control, canvas: Control, finance: Dictionary, ledger: Array) -> void:
	_chart(D.panel(canvas, Rect2(0,346,1398,375), "Flux de trésorerie", "money", "", "FinanceChart"), ledger)
	_allocation(D.panel(canvas, Rect2(1414,346,834,375), "Répartition des charges connues", "money", "", "FinanceAllocation"), finance)
	_ledger(D.panel(canvas, Rect2(0,737,1398,392), "Flux récents", "calendar", "", "FinanceLedger"), app, ledger, 8, "summary")
	_watch(D.panel(canvas, Rect2(1414,737,834,185), "Vigilances", "warning", "", "FinanceWatch"), app, finance)
	_due(D.panel(canvas, Rect2(1414,938,834,191), "Prochaines échéances", "calendar", "", "FinanceDue"), app, finance)

static func _chart(card: Panel, ledger: Array) -> void:
	var recent := ledger.slice(0,12)
	var graph := LedgerPlot.new()
	graph.name = "FinanceLedgerPlot"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.set_operations(recent)
	card.add_child(graph)
	D.place(graph, Rect2(134,96,1239,208))
	for i in 6:
		var y := 96.0 + i*41.6
		if not recent.is_empty():
			D.text(card, 113, y+7, U.amount(lerpf(graph.maximum,graph.minimum,float(i)/5.0)), 21, C.MUTED, 500, 103, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in recent.size():
		var stride := 1239.0/12.0
		var x := 1373.0 - stride*(i+.5)
		D.text(card, x, 330, "n° %d" % (i+1), 20, C.MUTED, 500, 96, HORIZONTAL_ALIGNMENT_CENTER)
	var labels := [["Cumul net affiché",C.IVORY,800],["Entrées",CHART_GREEN,1044],["Sorties",CHART_RED,1182]]
	for entry: Array in labels:
		D.rect(card, Rect2(entry[2],25,19,12), entry[1], 2)
		D.text(card, entry[2]+28, 40, entry[0], 20, C.IVORY, 500, 206 if entry[2] == 800 else 121)
	if recent.is_empty():
		D.text(card, 754, 196, "La première écriture reste à venir", 39, C.IVORY, 700, 960, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card, 754, 234, "Le graphique se remplit après une journée jouée ou une décision financière.", 24, C.MUTED, 500, 1040, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(card, 134, 356, "Douze écritures au plus · n° 1 en tête du journal · cumul net de ces seules écritures", 20, C.MUTED, 500, 1228)

static func _weekly(finance: Dictionary) -> Array:
	var wages: Variant = finance.get("weeklyWages")
	var academy: Variant = finance.get("academyInvestment")
	var maintenance: Variant = null
	if wages != null and academy != null and finance.has("weeklyCosts"):
		maintenance = maxf(0.0,float(finance.weeklyCosts)-float(wages)-float(academy))
	return [["Salaires","people",wages],["Formation","school",academy],["Installations","settings",maintenance]]

static func _allocation(card: Panel, finance: Dictionary) -> void:
	var rows := _weekly(finance)
	var total := float(finance.get("weeklyCosts",0))
	var remaining := int(finance.get("remainingWeeks",0))
	for i in rows.size():
		var item: Array = rows[i]
		var y := 72 + i*43
		var ratio := float(item[2])*100.0/total if total > 0 and item[2] != null else 0.0
		U.icon(card, item[1], Vector2(22,y+2), C.IVORY, 26)
		D.text(card, 60, y+24, item[0], 24, C.IVORY, 600, 205)
		D.bar(card, Rect2(275,y+8,432,14), ratio, CHART_GREEN)
		D.text(card, 808, y+24, "%d %%" % roundi(ratio) if total > 0 else "—", 23, C.IVORY, 600, 84, HORIZONTAL_ALIGNMENT_RIGHT)
	D.rect(card, Rect2(9,205,816,32), Color("182426"), 3)
	D.text(card, 22, 228, "POSTE", 20, C.MUTED, 700, 235)
	D.text(card, 529, 228, "PAR SEMAINE", 20, C.MUTED, 700, 214, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(card, 808, 228, "RESTE DE LA SAISON", 20, C.MUTED, 700, 250, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in rows.size():
		var item: Array = rows[i]
		var y := 244 + i*35
		D.text(card, 22, y+23, item[0], 22, C.IVORY, 500, 235)
		D.text(card, 529, y+23, G.euros(item[2]) if item[2] != null else "—", 23, C.IVORY, 600, 230, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, 808, y+23, U.amount(float(item[2])*remaining) if item[2] != null else "—", 23, C.MINT, 600, 235, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card, Vector2(20,y+29), Vector2(812,y+29), Color(C.LINE,.45))
	D.text(card, 22, 365, "Engagements connus · hypothèse du moteur sur %d semaine(s)" % remaining, 18, C.MUTED, 500, 786)

static func _category(title: String) -> Array:
	var key := title.to_lower()
	if key.begins_with("vente :") or key.begins_with("signature :") or key.begins_with("prolongation") or key.begins_with("signature agent"):
		return ["Contrat","people",C.BLUE]
	if key.contains("salaires"): return ["Salaires","people",C.ALERT]
	if key.contains("billetterie"): return ["Billetterie","home",C.MINT]
	if key.contains("partenaire") or key.contains("sponsor"): return ["Partenaire","shield",C.MINT]
	if key.contains("installations"): return ["Installations","settings",C.AMBER]
	if key.contains("formation"): return ["Formation","school",C.AMBER]
	if key.contains("prime"): return ["Prime","star",C.MINT]
	return ["Autre","money",C.GOLD]

static func _pagination(app: Control, card: Panel, total: int, limit: int, key: String) -> int:
	var state_key := "immersive08_finance_page_" + key
	var page_count := maxi(1,ceili(float(total)/limit))
	var page := clampi(int(app.management_ui.get(state_key,0)),0,page_count-1)
	var previous_id := "FinancePrev_" + key
	var next_id := "FinanceNext_" + key
	var previous := D.button(card, Rect2(1007,12,105,36), "Préc.", func(): _page(app, state_key, page-1, previous_id, next_id), false, "", true, U.GREEN, previous_id)
	var next := D.button(card, Rect2(1268,12,111,36), "Suiv.", func(): _page(app, state_key, page+1, next_id, previous_id), false, "", true, U.GREEN, next_id)
	previous.disabled = page == 0
	next.disabled = page + 1 >= page_count
	D.text(card, 1190, 38, "%d / %d" % [page+1,page_count], 23, C.MUTED, 600, 135, HORIZONTAL_ALIGNMENT_CENTER)
	return page*limit

static func _page(app: Control, key: String, page: int, focus_id: String, alternate_id: String) -> void:
	app.management_ui[key] = page
	app._render()
	U.focus(app, focus_id, alternate_id)

static func _ledger(card: Panel, app: Control, ledger: Array, limit: int, key: String) -> void:
	var first := _pagination(app, card, ledger.size(), limit, key)
	D.rect(card, Rect2(10,60,1378,41), Color("182426"), 3)
	for item: Array in [["N°",24],["OPÉRATION",113],["CATÉGORIE",749],["ENTRÉES",993],["SORTIES",1191]]:
		D.text(card, item[1], 87, item[0], 20, C.MUTED, 700, 169)
	if ledger.is_empty():
		D.text(card, 23, 161, "Aucune opération enregistrée dans ce journal.", 31, C.IVORY, 700, 1350)
		D.text(card, 23, 196, "Les écritures seront consultables ici au fil de la carrière.", 23, C.MUTED, 500, 1350)
	for i in mini(limit,ledger.size()-first):
		var entry: Dictionary = ledger[first+i]
		var title := str(entry.get("title","Opération"))
		var category := _category(title)
		var amount := float(entry.get("amount",0))
		var y := 103+i*33
		if i%2 == 0: D.rect(card, Rect2(12,y,1374,32), Color("131e20"))
		D.text(card, 24, y+24, "%02d" % (first+i+1), 21, C.MUTED, 500, 47)
		U.icon(card, category[1], Vector2(77,y+6), category[2], 21)
		D.text(card, 113, y+24, title, 23, C.IVORY, 500, 610)
		D.chip(card, Rect2(749,y+3,163,27), category[0], category[2])
		D.text(card, 1112, y+24, "+"+G.euros(amount) if amount > 0 else G.euros(amount) if amount == 0 else "—", 22, C.MINT if amount > 0 else C.MUTED, 600, 183, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, 1367, y+24, G.euros(amount) if amount < 0 else "—", 22, C.ALERT if amount < 0 else C.MUTED, 600, 203, HORIZONTAL_ALIGNMENT_RIGHT)

static func _watch(card: Panel, app: Control, finance: Dictionary) -> void:
	card.add_theme_stylebox_override("panel", D.surface(834,185,Color("2c2819"),Color("151914"),Color(C.GOLD,.85)))
	U.italic(card.get_node("CardTitle"), 700)
	var count := P.contracts(app.model).size()
	var quote: Variant = finance.get("facility")
	var contracts := "%d contrat%s à anticiper" % [count, "" if count == 1 else "s"]
	var facilities := "Devis indicatif · " + G.euros(quote.cost) if quote is Dictionary else "Aucun devis disponible"
	_watch_row(card, 65, "calendar", contracts, "Échéances d’ici la saison prochaine", func(): U.select(app, KEY, "wages", "FinanceTab_wages"), "FinanceWatchContracts")
	D.line(card, Vector2(19,117), Vector2(815,117), Color(C.GOLD,.28))
	_watch_row(card, 121, "settings", "Infrastructures", facilities, func(): _strategy(app), "FinanceWatchFacilities")

static func _watch_row(card: Panel, y: int, icon: String, title: String, detail: String, action: Callable, id: String) -> void:
	var row := D.button(card, Rect2(19,y,796,48), "", action, false, "", true, U.GREEN, id)
	row.accessibility_name = "%s · %s" % [title,detail]
	row.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT,Color.TRANSPARENT,4,0))
	row.add_theme_stylebox_override("hover", C.box(Color("372f1e"),C.GOLD,4,0))
	row.add_theme_stylebox_override("pressed", C.box(Color("43361c"),C.GOLD,4,0))
	U.icon(row, icon, Vector2(12,9), C.AMBER, 30)
	D.text(row, 57, 20, title, 24, C.IVORY, 700, 684)
	D.text(row, 57, 43, detail, 18, C.MUTED, 500, 684)
	U.icon(row, "arrow", Vector2(756,13), C.AMBER, 22)

static func _due(card: Panel, app: Control, finance: Dictionary) -> void:
	var remaining := int(finance.get("remainingWeeks",0))
	var week := int(app.model.meta.get("week",0)) + 1
	if remaining <= 0:
		D.text(card, 22, 119, "Aucun paiement hebdomadaire restant dans la projection.", 24, C.MUTED, 500, 788)
		return
	var rows := [["Salaires de l’effectif","people",finance.get("weeklyWages")],["Formation à la séance","school",finance.get("academyInvestment")],["Recettes prévues au modèle","money",finance.get("weeklyIncome")]]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 64+i*38
		D.text(card, 23, y+26, "Sem. %02d" % week, 21, C.MUTED, 500, 119)
		U.icon(card, item[1], Vector2(155,y+5), C.IVORY, 22)
		D.text(card, 190, y+26, item[0], 23, C.IVORY, 600, 441)
		var amount: Variant = item[2]
		var prefix := "−" if i < 2 else "+"
		D.text(card, 807, y+26, prefix+G.euros(amount) if amount != null and float(amount)>0.0 else G.euros(amount) if amount != null else "—", 22, C.ALERT if i < 2 else C.MINT, 600, 172, HORIZONTAL_ALIGNMENT_RIGHT)
		if i < rows.size()-1: D.line(card, Vector2(21,y+35), Vector2(813,y+35), Color(C.LINE,.55))

static func _footer(app: Control, canvas: Control, finance: Dictionary) -> void:
	var card := D.panel(canvas, Rect2(0,1145,2248,99), "", "", "", "FinanceProjection")
	U.icon(card, "money", Vector2(24,32), C.GOLD, 36)
	U.italic(D.text(card, 79, 61, "PROJECTION DES ENGAGEMENTS", 34, C.IVORY, 700, 488), 700)
	var forecast: Variant = finance.get("baseForecast")
	var hue := C.MUTED if forecast == null else C.ALERT if float(forecast) < 0.0 else C.MINT
	D.text(card, 576, 66, U.amount(forecast), 51, hue, 800, 270)
	D.line(card, Vector2(861,19), Vector2(861,80))
	var trend := "Indisponible" if forecast == null else "Solde négatif" if float(forecast) < 0.0 else "Solde positif" if float(forecast) > 0.0 else "À l’équilibre"
	D.chip(card, Rect2(885,27,183,46), trend, hue)
	D.text(card, 1086, 44, "Trésorerie projetée sur les engagements connus", 25, C.IVORY, 600, 650)
	D.text(card, 1086, 72, "Hors billetterie aléatoire, primes et transferts futurs", 22, C.MUTED, 500, 650)
	D.button(card, Rect2(1758,21,467,58), "Ajuster les engagements", func(): _strategy(app), true, "arrow", false, U.GREEN, "FinanceAdjustBudget")

static func _strategy(app: Control) -> void:
	app.management_ui.immersive08_strategy_tab = 0
	app._navigate("Stratégie")

static func _cash(app: Control, canvas: Control, ledger: Array) -> void:
	_chart(D.panel(canvas, Rect2(0,346,1398,375), "Flux de trésorerie", "money", "", "FinanceChart"), ledger)
	_ledger(D.panel(canvas, Rect2(0,737,1398,392), "Journal des flux", "calendar", "", "FinanceLedger"), app, ledger, 8, "cash")
	var totals := D.panel(canvas, Rect2(1414,346,834,783), "Écritures du journal", "money", "", "FinanceJournalTotals")
	var incoming := 0.0
	var outgoing := 0.0
	for entry: Dictionary in ledger:
		var amount := float(entry.get("amount",0))
		incoming += maxf(0.0,amount)
		outgoing += maxf(0.0,-amount)
	var details := [["Entrées enregistrées",incoming,C.MINT],["Sorties enregistrées",outgoing,C.ALERT],["Solde net des écritures",incoming-outgoing,C.IVORY]]
	for i in details.size():
		var item: Array = details[i]
		var y := 90+i*125
		D.text(totals, 24, y+20, item[0], 25, C.MUTED, 500, 775)
		D.text(totals, 24, y+71, G.euros(item[1]), 43, item[2], 700, 775)
		D.line(totals, Vector2(24,y+95), Vector2(810,y+95), Color(C.LINE,.65))
	D.text(totals, 24, 506, "%d écritures conservées" % ledger.size(), 30, C.IVORY, 600, 775)
	D.text(totals, 24, 550, "Le journal partiel peut inclure des écritures de saisons précédentes.", 23, C.MUTED, 500, 775)
	D.text(totals, 24, 588, "Le total des flux affichés diffère de la trésorerie du club.", 23, C.MUTED, 500, 775)

static func _wages(app: Control, canvas: Control, finance: Dictionary) -> void:
	var wages := D.panel(canvas, Rect2(0,346,1398,783), "Contrats et salaires", "people", "", "FinanceSalaryTable")
	var squad: Array = app.model.get("squad",[]).duplicate()
	squad.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.get("salary",0)) > float(b.get("salary",0)))
	var first := _pagination(app, wages, squad.size(),16,"wages")
	D.rect(wages, Rect2(12,62,1374,40), Color("182426"), 3)
	for item: Array in [["JOUEUR",25],["POSTE",491],["ÉCHÉANCE",703],["PAR SEMAINE",950]]:
		D.text(wages, item[1], 88, item[0], 21, C.MUTED, 700, 170)
	for i in mini(16,squad.size()-first):
		var player: Dictionary = squad[first+i]
		var y := 106+i*41
		if i%2 == 0: D.rect(wages, Rect2(12,y,1374,39), Color("131e20"))
		D.text(wages, 25, y+27, player.get("name","—"), 25, C.IVORY, 700, 450)
		D.text(wages, 491, y+27, player.get("pos","—"), 23, C.MUTED, 500, 198)
		D.text(wages, 703, y+27, player.get("contractLabel","—"), 23, C.MUTED, 500, 228)
		D.text(wages, 1096, y+27, G.euros(player.get("salary",0)), 23, C.IVORY, 600, 148, HORIZONTAL_ALIGNMENT_RIGHT)
		D.button(wages, Rect2(1120,y+3,247,33), "Voir le contrat", func(): _open_player(app, str(player.id)), false, "arrow", true, U.GREEN, "FinancePlayer_"+str(player.id).replace(":","_"))
	if squad.is_empty(): D.text(wages, 24, 153, "Aucun joueur sous contrat dans cette carrière.", 30, C.MUTED, 600, 1350)
	_allocation(D.panel(canvas, Rect2(1414,346,834,375), "Répartition des charges connues", "money"), finance)
	_due(D.panel(canvas, Rect2(1414,737,834,191), "Prochaines échéances", "calendar"), app, finance)
	var agents := D.panel(canvas, Rect2(1414,944,834,185), "Négociations", "people")
	D.text(agents, 24, 101, "Les mandats et accords à confirmer sont dans le travail du club.", 22, C.MUTED, 500, 786)
	D.button(agents, Rect2(24,117,786,49), "Ouvrir le travail du club", func(): app._navigate("Travail du club"), false, "arrow", true, U.GREEN, "FinanceAgents")

static func _open_player(app: Control, player_id: String) -> void:
	app.selected_player = player_id
	app._navigate("Effectif")

static func _transfers(app: Control, canvas: Control, ledger: Array) -> void:
	var contracts := ledger.filter(func(entry: Dictionary): return _category(str(entry.get("title","")))[0] == "Contrat")
	_ledger(D.panel(canvas, Rect2(0,346,1398,783), "Écritures de contrats et transferts", "calendar", "", "FinanceTransferLedger"), app, contracts, 20, "transfers")
	var card := D.panel(canvas, Rect2(1414,346,834,783), "Préparer le recrutement", "search", "", "FinanceTransferActions")
	var market: Array = app.model.get("market",[])
	D.text(card, 23, 132, "%d profils au marché" % market.size(), 44, C.IVORY, 700, 785)
	D.text(card, 23, 181, "Les offres détaillent la prime et le salaire avant signature.", 25, C.MUTED, 500, 785)
	D.button(card, Rect2(23,210,787,55), "Ouvrir le recrutement", func(): app._navigate("Recrutement"), true, "arrow", false, U.GREEN, "FinanceRecruitment")
	D.line(card, Vector2(23,290), Vector2(810,290))
	D.text(card, 23, 345, "Contrats du groupe", 38, C.IVORY, 700, 785)
	D.text(card, 23, 387, "Les prolongations se négocient depuis les dossiers joueurs.", 25, C.MUTED, 500, 785)
	D.button(card, Rect2(23,412,787,55), "Consulter les salaires et les échéances", func(): U.select(app, KEY, "wages", "FinanceTab_wages"), false, "arrow", false, U.GREEN, "FinanceTransferContracts")

static func _budget(app: Control, canvas: Control, finance: Dictionary) -> void:
	_allocation(D.panel(canvas, Rect2(0,346,834,375), "Répartition des charges connues", "money", "", "FinanceAllocation"), finance)
	_due(D.panel(canvas, Rect2(0,737,834,191), "Prochaines échéances", "calendar"), app, finance)
	_watch(D.panel(canvas, Rect2(0,944,834,185), "Vigilances", "warning"), app, finance)
	var decisions := D.panel(canvas, Rect2(850,346,1398,783), "Engagements et investissements", "money", "", "FinanceCommitments")
	D.text(decisions, 25, 125, "Des choix pour le projet du club", 47, C.IVORY, 700, 1348)
	D.text(decisions, 25, 173, "%d semaines restantes sur %d" % [int(finance.get("remainingWeeks",0)),int(finance.get("weeksPerSeason",0))], 28, C.GOLD, 600, 1348)
	var cards := [["Formation","school","Investissement par séance",finance.get("academyInvestment")],["Installations","settings","Niveau indisponible",null],["Partenaires","shield","Recettes hebdomadaires du modèle",finance.get("weeklyIncome")]]
	var facility: Variant = finance.get("facility")
	if facility is Dictionary:
		cards[1][2] = "Niveau actuel %s / 10 · devis suivant" % G.n(facility.level)
		cards[1][3] = facility.cost
	for i in cards.size():
		var item: Array = cards[i]
		var tile := D.panel(decisions, Rect2(25+i*448,217,436,205), item[0], item[1])
		if i == 1 and not facility is Dictionary:
			D.text(tile, 22, 116, "Aucun devis disponible", 31, C.IVORY, 700, 392)
		else:
			D.text(tile, 22, 116, U.amount(item[3]), 47, C.MINT, 700, 392)
		D.text(tile, 22, 158, item[2], 23, C.MUTED, 500, 392)
	D.text(decisions, 25, 488, "Les montants appartiennent à la simulation.", 26, C.MUTED, 500, 1348)
	D.text(decisions, 25, 529, "Les devis et conditions de signature sont détaillés dans les décisions du club.", 26, C.MUTED, 500, 1348)
	D.button(decisions, Rect2(25,575,550,58), "Ouvrir les décisions financières", func(): _strategy(app), true, "arrow", false, U.GREEN, "FinanceBudgetDecisions")
