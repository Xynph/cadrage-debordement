extends RefCounted
## Finances › Trésorerie : courbe des mouvements, catégories, pagination et journal des flux.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Link = preload("res://ui/entity_link.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")
const Traces = preload("res://ui/immersive08/finance_traces.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")

static func _chart(app: Control, card: Panel, ledger: Array, largeur: float) -> void:
	var recent := ledger.slice(0,12)
	var graph := Traces.LedgerPlot.new()
	graph.name = "FinanceLedgerPlot"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.trait_club = Charte.VERT_CLAIR
	graph.set_operations(recent)
	card.add_child(graph)
	var haut := 84.0
	var hauteur := card.size.y / maxf(C.density, .01) - 150.0
	D.place(graph, Rect2(150, haut, largeur - 190, hauteur))
	if not recent.is_empty():
		for valeur: float in graph.graduations():
			var y := haut + hauteur * (graph.maximum - valeur) / (graph.maximum - graph.minimum)
			Brique._texte(card, 134, y + 6, "0 €" if is_zero_approx(valeur) else U.amount(valeur), 16, Charte.IVOIRE_2, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	var pas := (largeur - 190) / 12.0
	for i in recent.size():
		var x := 150.0 + (largeur - 190) - pas * (i + .5)
		var locator := F.ledger_locator(ledger,i)
		if not locator.is_empty():
			var link := Button.new()
			link.name = "FinanceChartOperation_" + str(i)
			link.flat = true
			link.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			link.add_theme_stylebox_override("hover",Brique._style(Color(Charte.IVOIRE,.08),Charte.IVOIRE_2,2))
			link.add_theme_stylebox_override("focus",Brique._style(Color.TRANSPARENT,Charte.IVOIRE,2))
			link.set_meta("ledger_index",i)
			var caption := "Mouvement %s · %s · %s" % ["le plus récent" if i == 0 else "n° %d en remontant" % (i+1),str(recent[i].title),G.euros(recent[i].amount)]
			Link.bind(link,app,{"kind":"finance","id":locator},caption)
			card.add_child(link)
			D.place(link,Rect2(x-pas*.5,haut,pas,hauteur))
	# Légende : forme et mot (série « nous » en trait du club, entrées pleines, sorties hachurées).
	var trait_legende := Brique._bloc(card, Rect2(480, 28, 30, 5), Charte.VERT_CLAIR)
	trait_legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Brique._texte(card, 520, 38, "Solde cumulé de ces mouvements", 16, Charte.IVOIRE, 440)
	Brique._hachure_legende(card, 980, 24, true)
	Brique._texte(card, 1008, 38, "Entrées", 16, Charte.IVOIRE, 130)
	Brique._hachure_legende(card, 1150, 24, false)
	Brique._texte(card, 1178, 38, "Sorties (hachurées)", 16, Charte.IVOIRE, 300)
	Pieces.info(card, largeur - 46, 18, "Du plus ancien au plus récent · un clic sur un mouvement ouvre son détail", "FinanceChartInfo")
	if recent.is_empty():
		Brique._titre(card, largeur * .5, 190, "Le premier mouvement reste à venir", 36, Charte.IVOIRE, 900, HORIZONTAL_ALIGNMENT_CENTER)

static func _category(title: String) -> Array:
	var key := title.to_lower()
	if key.begins_with("vente :") or key.begins_with("signature :") or key.begins_with("prolongation") or key.begins_with("signature agent"):
		return ["Contrat","people",C.BLUE]
	if key.contains("salaires"): return ["Salaires","people",C.ALERT]
	if key.ends_with("investissements : staff"): return ["Staff","people",C.AMBER]
	# Primes et frais payés sur les recettes de guichet imprévues (club-budget.cjs, fraisDeMatch) : une charge, pas une prime reçue.
	if key.contains("frais de match"): return ["Matchs","home",C.AMBER]
	if key.contains("billetterie"): return ["Billetterie","home",C.MINT]
	if key.contains("partenaire") or key.contains("sponsor"): return ["Partenaire","shield",C.MINT]
	if key.contains("installations"): return ["Installations","settings",C.AMBER]
	if key.contains("formation"): return ["Formation","school",C.AMBER]
	if key.contains("prime"): return ["Prime","star",C.MINT]
	return ["Autre","money",C.GOLD]

## Écran qui explique une catégorie de mouvement : contrats, installations, salaires, sinon le budget.
static func _destination_categorie(app: Control, categorie: String) -> Array:
	match categorie:
		"Contrat": return ["Salaires et contrats", func(): F._open_wages(app, false)]
		"Salaires", "Staff": return ["Salaires", func(): F._open_wages(app, false)]
		"Installations": return ["Infrastructures", func(): F._strategy(app)]
		"Billetterie", "Partenaire", "Matchs", "Prime": return ["Budget", func(): F._ouvrir_onglet(app, "budget")]
	return ["Budget", func(): F._ouvrir_onglet(app, "budget")]

static func _pagination(app: Control, card: Panel, total: int, limit: int, key: String, largeur: float) -> int:
	var state_key := F.PAGE_KEY_PREFIX + key
	var page_count := maxi(1,ceili(float(total)/limit))
	var page := clampi(int(app.management_ui.get(state_key,0)),0,page_count-1)
	var previous_id := "FinancePrev_" + key
	var next_id := "FinanceNext_" + key
	# Largeurs prévues pour le plancher de 12 px (1280 × 720) : « Préc. » ne chevauche plus le compteur.
	var previous := Brique._bouton(card, Rect2(largeur - 410, 10, 130, 36), "Préc.", func(): _page(app, state_key, page-1, previous_id, next_id), "lien", "", previous_id)
	var next := Brique._bouton(card, Rect2(largeur - 150, 10, 130, 36), "Suiv.", func(): _page(app, state_key, page+1, next_id, previous_id), "lien", "", next_id)
	previous.disabled = page == 0
	next.disabled = page + 1 >= page_count
	Brique._texte(card, largeur - 215, 36, "%d / %d" % [page+1,page_count], 17, Charte.IVOIRE_2, 130, HORIZONTAL_ALIGNMENT_CENTER)
	return page*limit

static func _page(app: Control, key: String, page: int, focus_id: String, alternate_id: String) -> void:
	app.management_ui[key] = page
	app._render()
	U.focus(app, focus_id, alternate_id)

## Journal des mouvements : chaque ligne ouvre l'écran de sa catégorie ; le mouvement visé depuis la courbe est surligné.
static func _ledger(card: Panel, app: Control, ledger: Array, limit: int, key: String, largeur: float) -> void:
	var first := _pagination(app, card, ledger.size(), limit, key, largeur)
	var droite_sorties := largeur - 30.0
	var droite_entrees := largeur - 250.0
	var chip_x := largeur - 600.0
	Brique._bloc(card, Rect2(10, 60, largeur - 20, 36), Charte.PANNEAU_2)
	Brique._etiquette(card, 24, 84, "N°", 60)
	Brique._etiquette(card, 113, 84, "Mouvement", 400)
	Brique._etiquette(card, chip_x, 84, "Catégorie", 200)
	Brique._etiquette(card, droite_entrees, 84, "Entrées", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	Brique._etiquette(card, droite_sorties, 84, "Sorties", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	if ledger.is_empty():
		Brique._titre(card, 23, 160, "Aucune opération enregistrée", 30, Charte.IVOIRE, largeur - 46)
	var selected_index := F.ledger_index(app,app.management_ui.get(F.LEDGER_SELECTION_KEY,"")) if key == "cash" else -1
	for i in mini(limit,ledger.size()-first):
		var entry: Dictionary = ledger[first+i]
		var title := str(entry.get("title","Opération"))
		var category := _category(title)
		var amount := float(entry.get("amount",0))
		var y := 100.0 + i * 33.0
		var selected := selected_index == first+i
		if selected: Brique._bloc(card, Rect2(12, y, largeur - 24, 32), Charte.PANNEAU_3, Charte.IVOIRE).name = "FinanceLedgerSelection"
		var destination := _destination_categorie(app, str(category[0]))
		Brique._zone(card, Rect2(12, y, largeur - 24, 32), destination[1], "FinanceLedgerRow_%d" % (first+i), "Ouvrir · %s : %s" % [destination[0], title], true)
		Brique._texte(card, 24, y + 22, "%02d" % (first+i+1), 17, Charte.IVOIRE_2, 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title_label := Brique._texte(card, 113, y + 22, title, 19, Charte.IVOIRE, chip_x - 130)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if selected:
			title_label.name = "FinanceLedgerTarget"
			title_label.focus_mode = Control.FOCUS_ALL
			title_label.set_meta("ledger_index",selected_index)
			title_label.set_meta("ledger_entry",entry.duplicate(true))
			title_label.accessibility_name = "Mouvement n° %d · %s · %s" % [selected_index+1,title,G.euros(amount)]
		U.icon(card, category[1], Vector2(chip_x, y + 5), Charte.IVOIRE_2, 21)
		Brique._texte(card, chip_x + 30, y + 22, category[0], 17, Charte.IVOIRE_2, 170).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(card, droite_entrees, y + 22, "+"+G.euros(amount) if amount > 0 else G.euros(amount) if amount == 0 else "—", 18, Charte.IVOIRE if amount > 0 else Charte.IVOIRE_3, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._texte(card, droite_sorties, y + 22, "−"+G.euros(absf(amount)) if amount < 0 else "—", 18, Charte.IVOIRE if amount < 0 else Charte.IVOIRE_3, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _cash(app: Control, canvas: Control, zone: Rect2, ledger: Array) -> void:
	var x := zone.position.x
	_chart(app, Brique._panneau(canvas, Rect2(x, zone.position.y, zone.size.x, 330), "Solde et mouvements", "FinanceChart"), ledger, zone.size.x)
	var incoming := 0.0
	var outgoing := 0.0
	for entry: Dictionary in ledger:
		var amount := float(entry.get("amount",0))
		incoming += maxf(0.0,amount)
		outgoing += maxf(0.0,-amount)
	var totals := Brique._panneau(canvas, Rect2(x, zone.position.y + 346, zone.size.x, 104), "", "FinanceJournalTotals")
	var details := [["Entrées enregistrées", "+" + G.euros(incoming)], ["Sorties enregistrées", "−" + G.euros(outgoing)], ["Solde net des mouvements", ("+" if incoming - outgoing > 0 else "") + G.euros(incoming - outgoing).replace("-", "−")]]
	var colonne := zone.size.x / 3.0
	for i in details.size():
		# Chaque total a l'allure des chiffres cliquables du haut : il ouvre le Budget (recettes et charges de la saison).
		var total_lien := Brique._zone(totals, Rect2(i * colonne + 6, 6, colonne - 12, 92), func(): F._ouvrir_onglet(app, "budget"), "FinanceTotalLink" + str(i), "Ouvrir · Budget : recettes et charges prévues de la saison")
		F._lier(app, total_lien, F._onglet_cible("budget"), "Ouvrir · Budget")
		Brique._etiquette(totals, 20 + i * colonne, 34, details[i][0], colonne - 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Brique._titre(totals, 20 + i * colonne, 82, details[i][1], 38, Charte.IVOIRE, colonne - 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte_mouvements := P.plural(ledger.size(), "mouvement conservé", "mouvements conservés")
	var largeur_mouvements := Pieces.pastille(canvas, x + 4, zone.position.y + 448, texte_mouvements, "", "FinanceLedgerCount")
	Pieces.info(canvas, x + 4 + largeur_mouvements + 8, zone.position.y + 452, "Un clic sur une ligne ouvre l'écran qui l'explique · le journal ne se confond pas avec la trésorerie du club.", "FinanceLedgerInfo")
	var journal := Brique._panneau(canvas, Rect2(x, zone.position.y + 484, zone.size.x, 100 + F.LEDGER_PAGE * 33 + 14), "Journal des flux", "FinanceLedger")
	_ledger(journal, app, ledger, F.LEDGER_PAGE, "cash", zone.size.x)
