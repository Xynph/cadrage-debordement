extends RefCounted
## Finances (direction artistique du 19/11/2026). Synthèse « façon Effectif » (finance_synthese.gd, choix du 22/11) :
## cinq tuiles-chiffres, trois colonnes de listes à lignes et « Solde sur 12 mois » (trésorerie semaine par semaine).
## Les autres onglets gardent une colonne de verdict fixe à gauche (verdict, trésorerie, budget de transferts, marge).
## Tout montant, ligne ou nom ouvre l'écran qui l'explique ; une semaine du solde ouvre une petite fenêtre visuelle ; aucun or (réservé à Continuer).
const FocusLater = preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Link = preload("res://ui/entity_link.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Traces = preload("res://ui/immersive08/finance_traces.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")
const Colonne = preload("res://ui/immersive08/finance_colonne.gd")
const Journal = preload("res://ui/immersive08/finance_journal.gd")
const Listes = preload("res://ui/immersive08/finance_listes.gd")
const OngletBudget = preload("res://ui/immersive08/finance_budget.gd")

const KEY = "immersive08_finance_tab"
const PAGE_KEY_PREFIX = "immersive08_finance_page_"
const LEDGER_SELECTION_KEY := "immersive08_finance_ledger_selection"
const WAGES_SCOPE_KEY = "immersive08_finance_wages_due"
const TABS = [["summary","Synthèse"],["cash","Trésorerie"],["wages","Salaires"],["transfers","Transferts"],["budget","Budget"],["clubs","Classement"]]
## Mouvements par page du journal (onglet Trésorerie) ; les autres journaux gardent huit lignes.
const LEDGER_PAGE := 14
## Largeur de la colonne de verdict et zone de contenu à sa droite (onglets autres que la Synthèse).
const COLONNE_W := 620.0
const CONTENU_X := 636.0
const CONTENU_W := 1612.0
const HAUT := 150.0
const BAS := 1230.0
const PALIERS := [
	["Saine", "les recettes couvrent les dépenses"],
	["Sous tension", "perte chaque semaine, trésorerie positive en fin de saison"],
	["En danger", "trésorerie négative en fin de saison"]]

## Ctrl+Tab : onglet suivant (Maj+Ctrl+Tab : précédent).
class Clavier extends Control:
	var ouvrir: Callable
	var courant := 0

	func _unhandled_key_input(event: InputEvent) -> void:
		if not (event is InputEventKey) or not event.pressed or event.echo or event.keycode != KEY_TAB or not event.ctrl_pressed: return
		get_viewport().set_input_as_handled()
		var suivant := posmod(courant + (-1 if event.shift_pressed else 1), TABS.size())
		ouvrir.call(str(TABS[suivant][0]))

# ---------------------------------------------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------------------------------------------

## Verdict de la semaine (seuils de design/ux/17-finances.md §13) : palier 0 = saine (marge ≥ 0), 1 = sous tension
## (marge < 0, trésorerie prévue en fin de saison ≥ 0), 2 = en danger (trésorerie ou prévision < 0) ; -1 = inconnu.
static func verdict(app: Control, accounts: Dictionary, finance: Dictionary) -> Dictionary:
	var cash: Variant = accounts.get("cash", app.model.get("club", {}).get("cash"))
	var forecast: Variant = finance.get("baseForecast")
	var margin: Variant = null
	if finance.has("weeklyIncome") and finance.has("weeklyCosts"): margin = float(finance.weeklyIncome) - float(finance.weeklyCosts)
	var palier := -1
	if (cash != null and float(cash) < 0.0) or (forecast != null and float(forecast) < 0.0): palier = 2
	elif margin != null: palier = 1 if margin < 0.0 else 0
	elif cash != null: palier = 0
	var phrase := "Les chiffres de la semaine ne sont pas disponibles."
	match palier:
		0: phrase = "Les recettes régulières couvrent les charges : %s par semaine en ce moment%s." % [U.amount(margin), ", trésorerie prévue à %s en fin de saison" % U.amount(forecast) if forecast != null else ""]
		1: phrase = "Tu perds %s par semaine en ce moment, mais la trésorerie reste positive jusqu'en fin de saison%s." % [U.amount(absf(float(margin))), " : %s prévus" % U.amount(forecast) if forecast != null else ""]
		2: phrase = "La trésorerie est prévue à %s en fin de saison. Ajuste les engagements avant de t'engager sur de nouvelles dépenses." % U.amount(forecast if forecast != null and float(forecast) < 0.0 else cash)
	# Autonomie : semaines que la trésorerie tient à la marge courante, plafonnées aux semaines restantes de la saison.
	var detail: Variant = finance.get("projection")
	var restantes: Variant = int(detail.remainingWeeks) if detail is Dictionary and detail.get("remainingWeeks") != null else null
	var autonomie: Variant = null
	if cash != null and margin != null:
		if float(cash) <= 0.0: autonomie = 0
		elif margin >= 0.0: autonomie = restantes
		else:
			autonomie = floori(float(cash) / -float(margin))
			if restantes != null: autonomie = mini(autonomie, int(restantes))
	return {"palier": palier, "mot": PALIERS[palier][0] if palier >= 0 else "Indisponible", "phrase": phrase, "margin": margin, "cash": cash, "forecast": forecast, "autonomie": autonomie}

static func _lier(app: Control, zone: Button, cible: Dictionary, libelle: String) -> void:
	Link.bind(zone, app, cible, libelle)

static func _onglet_courant(app: Control) -> String:
	return str(app.management_ui.get(KEY, "summary"))

## Étape suivante d'une ligne « Formation » : sur le Budget, l'écran Formation ; ailleurs, l'onglet Budget.
static func _vers_formation_ou_budget(app: Control) -> void:
	if _onglet_courant(app) == "budget": app._navigate("Formation")
	else: _ouvrir_onglet(app, "budget")

## Chiffre ou pastille cliquable : ouvre l'onglet voulu, ou la Trésorerie (puis le Budget) si l'on y est déjà.
static func _vers(app: Control, cle: String) -> void:
	if _onglet_courant(app) == cle: cle = "cash" if cle != "cash" else "budget"
	_ouvrir_onglet(app, cle)

## Contrats à échéance : l'Effectif, onglet Contrats, trié par échéance.
static func _vers_contrats(app: Control) -> void:
	var lecture: Dictionary = app.management_ui.roster
	lecture.immersive_tab = 2
	lecture.sort = "Échéance"
	lecture.descending = false
	app.roster_sort = "Échéance"
	app._navigate("Effectif")

static func _onglet_cible(cle: String) -> Dictionary:
	return {"kind": "finance", "id": cle}

static func _ouvrir_onglet(app: Control, cle: String) -> void:
	if cle == "wages": _open_wages(app, false)
	else: U.select(app, KEY, cle, "FinanceTab_" + cle)

static func _strategy(app: Control) -> void:
	app.management_ui.immersive08_strategy_tab = 0
	app._navigate("Stratégie")

# ---------------------------------------------------------------------------------------------------------------
# Accès depuis les autres écrans (conservés)
# ---------------------------------------------------------------------------------------------------------------

# Ledger receipts have no persisted accounting identifier. Their read-only
# locator binds an occurrence to the entire ordered projection: a new receipt,
# correction or reordering invalidates it instead of opening another operation.
static func _ledger_projection(app: Control) -> Array:
	var finance: Variant = app.model.get("finance")
	var entries: Variant = finance.get("ledger", app.model.get("ledger", [])) if finance is Dictionary else app.model.get("ledger", [])
	return entries if entries is Array else []

static func ledger_locator(entries: Array, index: int) -> String:
	if index < 0 or index >= entries.size() or not entries[index] is Dictionary: return ""
	var entry: Dictionary = entries[index]
	var amount: Variant = entry.get("amount")
	if not entry.get("title") is String or not (amount is int or amount is float) or not is_finite(float(amount)): return ""
	return "ledger:%s:%d" % [JSON.stringify(entries).sha256_text(), index]

static func ledger_index(app: Control, locator: Variant) -> int:
	if not locator is String: return -1
	var parts: PackedStringArray = locator.split(":")
	if parts.size() != 3 or parts[0] != "ledger" or not parts[2].is_valid_int(): return -1
	var index := parts[2].to_int()
	return index if ledger_locator(_ledger_projection(app),index) == locator else -1

static func target_available(app: Control, id: Variant) -> bool:
	return ledger_index(app,id) >= 0 or TABS.any(func(tab: Array): return tab[0] == str(id))

static func open_target(app: Control, id: Variant) -> bool:
	if not target_available(app, id): return false
	var index := ledger_index(app,id)
	app.management_ui[KEY] = "cash" if index >= 0 else str(id)
	if index >= 0:
		app.management_ui[LEDGER_SELECTION_KEY] = str(id)
		app.management_ui[PAGE_KEY_PREFIX + "cash"] = floori(float(index) / float(LEDGER_PAGE))
	app._navigate("Finances", false)
	if index >= 0:
		var target := app.find_child("FinanceLedgerTarget",true,false) as Control
		if target != null: FocusLater.grab(target)
	return true

# ---------------------------------------------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------------------------------------------

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveFinance"
	var tab := str(app.management_ui.get(KEY,"summary"))
	var accounts: Dictionary = app.model.get("finance", {})
	var finance: Dictionary = U.strategy(app.model).get("finance", {})
	var ledger: Array = accounts.get("ledger", app.model.get("ledger", []))
	var verdict_data := verdict(app, accounts, finance)
	_entete(app, canvas, tab)
	if tab == "summary":
		_synthese(app, canvas, accounts, finance, ledger, verdict_data)
		return
	Colonne._colonne(app, canvas, accounts, finance, ledger, verdict_data, tab)
	var zone := Rect2(CONTENU_X, HAUT, CONTENU_W, BAS - HAUT)
	match tab:
		"cash": Journal._cash(app, canvas, zone, ledger)
		"wages": Listes._wages(app, canvas, zone, finance)
		"transfers": Listes._transfers(app, canvas, zone, ledger)
		"clubs": Listes._clubs(app, canvas, zone, accounts)
		_: OngletBudget._budget(app, canvas, zone, finance)

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

static func _entete(app: Control, canvas: Control, tab: String) -> void:
	Brique._titre(canvas, 4, 52, "FINANCES", 62, Charte.IVOIRE, 520).add_theme_font_override("font", Charte.TITRE_FICHE)
	var semaine := int(app.model.meta.get("week",0)) + 1
	var etat := "bilan de la saison" if app.model.meta.get("phase","") == "ended" else "chiffres arrêtés à la semaine %d" % semaine
	Brique._texte(canvas, 300, 50, "Saison %s · %s" % [G.season_label(app.model.meta.get("season",1)), etat], 21, Charte.IVOIRE_2, 1100)
	D.line(canvas, Vector2(0, 134), Vector2(2248, 134), Charte.FILET)
	var clavier := Clavier.new()
	clavier.ouvrir = func(cle: String): _ouvrir_onglet(app, cle)
	clavier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in TABS.size():
		if TABS[i][0] == tab: clavier.courant = i
	canvas.add_child(clavier)
	var largeur := 226.0
	for i in TABS.size():
		var cle: String = TABS[i][0]
		var id := "FinanceTab_" + cle
		Brique._bouton(canvas, Rect2(i * (largeur + 6), 80, largeur, 54), TABS[i][1].to_upper(), func(): _ouvrir_onglet(app, cle), "onglet", "", id, cle == tab)

# ---- Synthèse -----------------------------------------------------------------------------------------------

static func _synthese(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary) -> void:
	# Synthèse « façon Effectif » (choix de Léo du 22/11/2026) : tuiles du bandeau, trois colonnes de listes, solde.
	load("res://ui/immersive08/finance_synthese.gd").construire(app, canvas, accounts, finance, ledger, v)

## Semaines des 12 derniers mois (relevés du moteur) ; la trésorerie du jour s'ajoute si elle a bougé depuis le dernier relevé.
static func solde_semaines(app: Control, accounts: Dictionary) -> Array:
	var lignes: Array = []
	for releve: Variant in accounts.get("cashHistory", []):
		if releve is Dictionary and releve.get("date") is String and releve.get("cash") != null:
			lignes.append({"date": str(releve.date), "cash": float(releve.cash)})
	var aujourdhui := str(app.model.get("meta", {}).get("calendarToday", ""))
	var cash: Variant = accounts.get("cash", app.model.get("club", {}).get("cash"))
	if cash != null and aujourdhui.length() == 10:
		if lignes.is_empty() or (aujourdhui > str(lignes.back().date) and absf(float(cash) - float(lignes.back().cash)) >= 1.0):
			lignes.append({"date": aujourdhui, "cash": float(cash)})
	if not lignes.is_empty():
		var limite := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(str(lignes.back().date)) - 364 * 86400)
		lignes = lignes.filter(func(ligne: Dictionary): return str(ligne.date) > limite)
		if lignes.size() > Traces.SoldePlot.CASES: lignes = lignes.slice(lignes.size() - Traces.SoldePlot.CASES)
		lignes.back().courant = true
	for i in lignes.size():
		lignes[i].variation = null
		if i > 0: lignes[i].variation = float(lignes[i].cash) - float(lignes[i - 1].cash)
	return lignes

## Formation par semaine : le centre de formation (coût réel du budget de saison, compris dans le fonctionnement du
## moteur) plus l'investissement « formation payée » éventuel. Sans budget de saison, seul l'investissement existe.
static func formation_weekly(finance: Dictionary) -> Variant:
	var paid: Variant = finance.get("academyInvestment")
	var budget: Variant = finance.get("budget")
	if budget is Dictionary and budget.get("centreFormationHebdo") != null and paid != null:
		return float(paid) + float(budget.centreFormationHebdo)
	return paid

static func _weekly(finance: Dictionary) -> Array:
	var wages: Variant = finance.get("weeklyWages")
	var academy: Variant = formation_weekly(finance)
	var maintenance: Variant = null
	if wages != null and academy != null and finance.has("weeklyCosts"):
		maintenance = maxf(0.0,float(finance.weeklyCosts)-float(wages)-float(academy))
	# Carrières au budget de saison : les cotisations suivent les salaires, le reste est le fonctionnement du club.
	if finance.has("budget"): return [["Salaires et cotisations","people",wages],["Formation","school",academy],["Staff et fonctionnement","settings",maintenance]]
	return [["Salaires","people",wages],["Formation","school",academy],["Installations","settings",maintenance]]

static func _open_wages(app: Control, due_only: bool) -> void:
	if due_only or app.management_ui.get(WAGES_SCOPE_KEY, false):
		app.management_ui[PAGE_KEY_PREFIX + "wages"] = 0
	app.management_ui[WAGES_SCOPE_KEY] = due_only
	U.select(app, KEY, "wages", "FinanceWagesAll" if due_only else "FinanceTab_wages")

static func _wage_value(player: Dictionary, key: String) -> Variant:
	if key == "name" or key == "pos":
		var value := str(player.get(key, "")).strip_edges()
		return null if value.is_empty() else preload("res://ui/management_state.gd").fold(value)
	var value: Variant = player.get(key)
	return value if (value is int or value is float) and is_finite(float(value)) else null

static func wage_rows(players: Array, key: String, descending: bool) -> Array:
	var result := players.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var first: Variant = _wage_value(a,key)
		var second: Variant = _wage_value(b,key)
		if first == null or second == null:
			if first != second: return second == null
		elif first != second:
			if first is String:
				var comparison := str(first).naturalnocasecmp_to(str(second))
				if comparison != 0: return comparison > 0 if descending else comparison < 0
			else: return first > second if descending else first < second
		return str(a.get("id","")) < str(b.get("id","")))
	return result
