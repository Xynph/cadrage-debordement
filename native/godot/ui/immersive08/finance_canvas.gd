extends RefCounted
## Finances (direction artistique, variante 1 « Verdict en tête, quatre blocs », revue du 19/11/2026).
## Synthèse : verdict en mots, trésorerie, budget de transferts (alloué / engagé / restant), marge, puis vigilances,
## échéances, répartition et courbe. Les autres onglets gardent une colonne de verdict fixe à gauche.
## Tout montant, ligne ou nom ouvre l'écran qui l'explique ; aucune fenêtre ; aucun or (réservé à Continuer).
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Link = preload("res://ui/entity_link.gd")
const G = preload("res://ui/game_skin.gd")
const Health = preload("res://ui/immersive08/finance_health.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const Charte = preload("res://ui/charte.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
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

## Courbe des mouvements : série « nous » en trait du club ; sorties hachurées, entrées pleines (forme, pas couleur).
class LedgerPlot extends Control:
	var operations: Array = []
	var minimum := 0.0
	var maximum := 1.0
	var cumulative := PackedFloat64Array()
	var trait_club := Charte.CLUB_TRAIT
	var pas := 0.2

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
		# Graduations rondes (1, 2 ou 5 × 10^n) avec le zéro sur une graduation : « 0 € » et non « −880 € ».
		var brut := (maximum - minimum) / 5.0
		var ordre := pow(10.0, floorf(log(brut) / log(10.0)))
		var rapport := brut / ordre
		pas = (1.0 if rapport <= 1.0 else 2.0 if rapport <= 2.0 else 5.0 if rapport <= 5.0 else 10.0) * ordre
		maximum = ceilf(maximum / pas - 1e-9) * pas
		minimum = floorf(minimum / pas + 1e-9) * pas
		queue_redraw()

	## Valeurs des graduations, de la plus haute à la plus basse.
	func graduations() -> Array:
		var valeurs := []
		var nombre := roundi((maximum - minimum) / pas)
		for i in nombre + 1: valeurs.append(maximum - i * pas)
		return valeurs

	func _height(value: float) -> float:
		return size.y * (maximum - value) / (maximum - minimum)

	func _draw() -> void:
		for valeur in graduations():
			var y := _height(valeur)
			draw_line(Vector2(0,y), Vector2(size.x,y), Color(Charte.FILET,.7))
		draw_line(Vector2.ZERO, Vector2(0,size.y), Charte.IVOIRE_3)
		if operations.is_empty(): return
		var zero := _height(0)
		draw_dashed_line(Vector2(0,zero), Vector2(size.x,zero), Charte.IVOIRE_2, maxf(1,C.px(2)), maxf(4,C.px(8)))
		var stride := size.x / maxi(12,operations.size())
		var points := PackedVector2Array()
		for i in operations.size():
			var value := float(operations[i].get("amount",0))
			var x := size.x - stride * (operations.size()-i-.5)
			var top := _height(absf(value))
			if value != 0:
				var bar := Rect2(x-stride*.19,top,stride*.38,zero-top)
				if value > 0:
					draw_rect(bar, Charte.IVOIRE_2)
				else:
					draw_rect(bar, Color(Charte.IVOIRE_2,.18))
					draw_rect(bar, Charte.IVOIRE_2, false, maxf(1,C.px(2)))
					var step := maxf(5.0,C.px(7))
					var offset := step
					while offset < bar.size.x + bar.size.y:
						var a := Vector2(bar.position.x + minf(offset,bar.size.x), bar.position.y + maxf(0.0,offset - bar.size.x))
						var b := Vector2(bar.position.x + maxf(0.0,offset - bar.size.y), bar.position.y + minf(offset,bar.size.y))
						draw_line(a, b, Charte.IVOIRE_2, 1.0)
						offset += step
			points.append(Vector2(x,_height(cumulative[i])))
		if points.size() > 1: draw_polyline(points,trait_club,maxf(2,C.px(3)),true)
		for point in points:
			draw_circle(point, C.px(7), Charte.FOND)
			draw_circle(point, C.px(5), trait_club)

## Pictogramme dessiné d'un état (coche, point d'exclamation, croix) : toujours accompagné d'un mot.
class Symbole extends Control:
	var forme := "coche"
	var couleur := Charte.IVOIRE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var epaisseur := maxf(2.0, w * .09)
		draw_rect(Rect2(1, 1, w - 2, h - 2), couleur, false, maxf(1.5, w * .07))
		match forme:
			"coche": draw_polyline(PackedVector2Array([Vector2(w * .24, h * .54), Vector2(w * .43, h * .72), Vector2(w * .78, h * .28)]), couleur, epaisseur)
			"croix":
				draw_line(Vector2(w * .27, h * .27), Vector2(w * .73, h * .73), couleur, epaisseur)
				draw_line(Vector2(w * .73, h * .27), Vector2(w * .27, h * .73), couleur, epaisseur)
			_:
				draw_line(Vector2(w * .5, h * .2), Vector2(w * .5, h * .58), couleur, epaisseur)
				draw_rect(Rect2(w * .5 - epaisseur * .6, h * .7, epaisseur * 1.2, epaisseur * 1.2), couleur)

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
	return {"palier": palier, "mot": PALIERS[palier][0] if palier >= 0 else "Indisponible", "phrase": phrase, "margin": margin, "cash": cash, "forecast": forecast}

# ---------------------------------------------------------------------------------------------------------------
# Pièces graphiques
# ---------------------------------------------------------------------------------------------------------------

static func _style(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, bas_seulement: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(0)
	if bord.a > 0.0 and epaisseur > 0:
		style.border_color = bord
		if bas_seulement: style.border_width_bottom = epaisseur
		else: style.set_border_width_all(epaisseur)
	return style

static func _titre(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := D.text(parent, x, baseline, valeur, taille, couleur, 700, largeur, aligne)
	label.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return label

static func _texte(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur, taille, couleur, 500, largeur, aligne, true)

static func _etiquette(parent: Node, x: float, baseline: float, valeur: String, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur.to_upper(), 15, Charte.IVOIRE_2, 600, largeur, aligne)

static func _panneau(parent: Node, rectangle: Rect2, titre: String, id: String, legende: String = "") -> Panel:
	var panel := Panel.new()
	panel.name = id
	panel.add_theme_stylebox_override("panel", _style(Charte.PANNEAU))
	parent.add_child(panel)
	D.place(panel, rectangle)
	if not titre.is_empty():
		var entete := _titre(panel, 20, 40, titre.to_upper(), 26, Charte.IVOIRE, rectangle.size.x - 40)
		entete.name = "CardTitle"
		if not legende.is_empty():
			var droite := _etiquette(panel, rectangle.size.x - 20, 38, legende, rectangle.size.x * .6, HORIZONTAL_ALIGNMENT_RIGHT)
			droite.name = "CardCaption"
	return panel

static func _bloc(parent: Node, rectangle: Rect2, fond: Color = Charte.PANNEAU_2, bord: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fond, bord, 2 if bord.a > 0.0 else 0))
	parent.add_child(panel)
	D.place(panel, rectangle)
	return panel

static func _symbole(parent: Node, rectangle: Rect2, forme: String, couleur: Color = Charte.IVOIRE) -> Symbole:
	var symbole := Symbole.new()
	symbole.forme = forme
	symbole.couleur = couleur
	symbole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(symbole)
	D.place(symbole, rectangle)
	return symbole

## Fenêtre étroite (sous 1920 × 1080) : le plancher de 12 px grossit nettement le petit texte par rapport au gabarit.
static func _etroit() -> bool:
	return float(C.font_px(16)) > float(C.px(16)) * 1.2

static func _forme_palier(palier: int) -> String:
	return "coche" if palier == 0 else "croix" if palier == 2 else "exclam"

## Boutons de la charte : « lien » (texte ivoire + flèche), « ivoire » (l'action principale de l'écran), « onglet ».
static func _bouton(parent: Node, rectangle: Rect2, libelle: String, action: Callable, mode: String, icone: String, id: String, choisi: bool = false) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = libelle
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.clip_text = true
	bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER if mode == "onglet" else HORIZONTAL_ALIGNMENT_RIGHT
	var titre := mode in ["ivoire", "onglet"]
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS if titre else C.font(600))
	bouton.add_theme_font_size_override("font_size", C.font_px(21 if titre else 18))
	var texte: Color = Charte.FOND if mode == "ivoire" else Charte.IVOIRE if (mode == "lien" or choisi) else Charte.IVOIRE_2
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, texte)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var normal := _style(Charte.PANNEAU_3 if mode == "onglet" and choisi else Charte.IVOIRE if mode == "ivoire" else Color.TRANSPARENT, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var survol := _style(Charte.IVOIRE_2 if mode == "ivoire" else Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var inactif := _style(Charte.PANNEAU_3 if mode == "ivoire" else Color.TRANSPARENT)
	for style: StyleBoxFlat in [normal, survol, inactif]:
		style.content_margin_left = C.px(12)
		style.content_margin_right = C.px(12)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bouton.add_theme_stylebox_override("normal", normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)
	bouton.add_theme_stylebox_override("hover_pressed", survol)
	bouton.add_theme_stylebox_override("disabled", inactif)
	bouton.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
	if not icone.is_empty():
		bouton.icon = C.icon_texture(icone, Charte.FOND if mode == "ivoire" else Charte.IVOIRE)
		bouton.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bouton.expand_icon = true
		bouton.add_theme_constant_override("icon_max_width", C.px(20))
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, C.reach_rect(rectangle))
	return bouton

## Zone cliquable d'une ligne ou d'un bloc (posée AVANT son texte : les libellés laissent passer la souris).
static func _zone(parent: Node, rectangle: Rect2, action: Callable, id: String, infobulle: String) -> Button:
	var zone := Button.new()
	zone.name = id
	zone.flat = true
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("hover", _style(Charte.PANNEAU_2))
	zone.add_theme_stylebox_override("pressed", _style(Charte.PANNEAU_3))
	zone.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
	zone.tooltip_text = infobulle
	zone.accessibility_name = infobulle
	zone.pressed.connect(action)
	parent.add_child(zone)
	D.place(zone, rectangle)
	return zone

static func _lier(app: Control, zone: Button, cible: Dictionary, libelle: String) -> void:
	Link.bind(zone, app, cible, libelle)

static func _onglet_courant(app: Control) -> String:
	return str(app.management_ui.get(KEY, "summary"))

## Étape suivante d'une ligne « Formation » : sur le Budget, l'écran Formation ; ailleurs, l'onglet Budget.
static func _vers_formation_ou_budget(app: Control) -> void:
	if _onglet_courant(app) == "budget": app._navigate("Formation")
	else: _ouvrir_onglet(app, "budget")

static func _onglet_cible(cle: String) -> Dictionary:
	return {"kind": "finance", "id": cle}

static func _ouvrir_onglet(app: Control, cle: String) -> void:
	if cle == "wages": _open_wages(app, false)
	else: U.select(app, KEY, cle, "FinanceTab_" + cle)

static func _strategy(app: Control) -> void:
	app.management_ui.immersive08_strategy_tab = 0
	app._navigate("Stratégie")

static func _hachure_legende(parent: Node, x: float, y: float, plein: bool) -> void:
	var cadre := _bloc(parent, Rect2(x, y, 19, 13), Color(Charte.IVOIRE_2, 1.0 if plein else .18), Charte.IVOIRE_2)
	if not plein:
		for i in 3: D.line(cadre, Vector2(3 + i * 5, 11), Vector2(8 + i * 5, 1), Charte.IVOIRE_2)

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
	_colonne(app, canvas, accounts, finance, ledger, verdict_data, tab)
	var zone := Rect2(CONTENU_X, HAUT, CONTENU_W, BAS - HAUT)
	match tab:
		"cash": _cash(app, canvas, zone, ledger)
		"wages": _wages(app, canvas, zone, finance)
		"transfers": _transfers(app, canvas, zone, ledger)
		"clubs": _clubs(app, canvas, zone, accounts)
		_: _budget(app, canvas, zone, finance)

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
	_titre(canvas, 4, 52, "FINANCES", 62, Charte.IVOIRE, 520)
	var semaine := int(app.model.meta.get("week",0)) + 1
	var etat := "bilan de la saison" if app.model.meta.get("phase","") == "ended" else "chiffres arrêtés à la semaine %d" % semaine
	_texte(canvas, 300, 50, "Saison %s · %s" % [G.season_label(app.model.meta.get("season",1)), etat], 21, Charte.IVOIRE_2, 1100)
	_texte(canvas, 2248, 50, "Ctrl+Tab · onglet suivant", 17, Charte.IVOIRE_2, 400, HORIZONTAL_ALIGNMENT_RIGHT)
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
		_bouton(canvas, Rect2(i * (largeur + 6), 80, largeur, 54), TABS[i][1].to_upper(), func(): _ouvrir_onglet(app, cle), "onglet", "", id, cle == tab)

# ---- Verdict ------------------------------------------------------------------------------------------------

static func _verdict_panneau(app: Control, canvas: Control, rectangle: Rect2, v: Dictionary, compact: bool, tab: String) -> void:
	var largeur := rectangle.size.x
	var panel := _panneau(canvas, rectangle, "Verdict" if compact else "Verdict de la semaine", "FinanceVerdict", "visible sur chaque onglet" if compact else "")
	if tab != "budget":
		var ouvrir := _zone(panel, Rect2(0, 0, largeur, rectangle.size.y), func(): _ouvrir_onglet(app, "budget"), "FinanceVerdictLink", "Voir le budget et ajuster les engagements")
		_lier(app, ouvrir, _onglet_cible("budget"), "Ouvrir · Budget")
		panel.move_child(ouvrir, 0)
		# La zone couvre le panneau mais reste sous les libellés (ils laissent passer la souris).
	var palier: int = v.palier
	var mot := _titre(panel, 64, 100, str(v.mot).to_upper(), 42, Charte.IVOIRE, largeur - 260)
	mot.name = "FinanceVerdictWord"
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_symbole(panel, Rect2(20, 68, 34, 34), _forme_palier(palier) if palier >= 0 else "exclam", Charte.IVOIRE)
	var palier_texte := "palier %d sur 3" % (palier + 1) if palier >= 0 else "chiffres indisponibles"
	_etiquette(panel, largeur - 20, 96, palier_texte, 240, HORIZONTAL_ALIGNMENT_RIGHT)
	var largeur_colonne := (largeur - 40.0 - 16.0) / 3.0
	# Petite fenêtre : le plancher de 12 px grossit les descriptions, qui débordaient sur la phrase. On garde les
	# trois paliers (mot + symbole) et la phrase ; le barème complet passe dans l'infobulle du bloc.
	var etroit := _etroit()
	for i in 3:
		var x := 20.0 + i * (largeur_colonne + 8.0)
		var actif := i == palier
		_bloc(panel, Rect2(x, 120, largeur_colonne, 10), Charte.IVOIRE if actif else Charte.PANNEAU_3)
		_symbole(panel, Rect2(x, 142, 20, 20), _forme_palier(i), Charte.IVOIRE if actif else Charte.IVOIRE_2)
		D.text(panel, x + 28, 159, str(PALIERS[i][0]), 20, Charte.IVOIRE if actif else Charte.IVOIRE_2, 700, largeur_colonne - 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if etroit: continue
		var description := C.wrap(str(PALIERS[i][1]), 16, Charte.IVOIRE if actif else Charte.IVOIRE_2)
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(description)
		D.place(description, Rect2(x, 172, largeur_colonne, 70))
	var phrase := C.wrap(str(v.phrase), 19 if compact else 20, Charte.IVOIRE)
	phrase.name = "FinanceVerdictSentence"
	phrase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(phrase)
	var phrase_y := 184.0 if etroit else 258.0 if compact else 248.0
	D.place(phrase, Rect2(20, phrase_y, largeur - 40, 90))
	if etroit:
		var bareme := PackedStringArray()
		for palier_bareme: Array in PALIERS: bareme.append("%s : %s" % palier_bareme)
		panel.tooltip_text = "\n".join(bareme)
		var lien := panel.find_child("FinanceVerdictLink", false, false) as Control
		if lien != null: lien.tooltip_text = "Voir le budget et ajuster les engagements\n" + panel.tooltip_text
	panel.accessibility_name = "%s, trésorerie %s" % [v.mot, U.amount(v.cash)]

# ---- Chiffres du haut -----------------------------------------------------------------------------------------

static func _dernieres_depenses(ledger: Array) -> String:
	var parts := PackedStringArray()
	for entry: Dictionary in ledger:
		if parts.size() >= 2: break
		var title := str(entry.get("title", ""))
		if _category(title)[0] != "Contrat" or float(entry.get("amount", 0)) >= 0.0: continue
		var nom := title.get_slice(":", 1).strip_edges() if title.contains(":") else title
		parts.append("%s %s" % [nom, U.amount(absf(float(entry.amount)))])
	return " · ".join(parts)

static func _carte(app: Control, canvas: Control, rectangle: Rect2, id: String, cible: Dictionary, libelle: String, infobulle: String) -> Panel:
	var carte := _panneau(canvas, rectangle, "", id)
	var ouvrir := _zone(carte, Rect2(0, 0, rectangle.size.x, rectangle.size.y), func(): pass, id.replace("FinanceMetric", "FinanceMetricLink"), libelle)
	ouvrir.name = id.replace("FinanceMetric", "FinanceMetricLink")
	_lier(app, ouvrir, cible, libelle)
	if not infobulle.is_empty(): ouvrir.tooltip_text = infobulle
	return carte

static func _carte_tresorerie(app: Control, canvas: Control, rectangle: Rect2, accounts: Dictionary, finance: Dictionary, v: Dictionary) -> void:
	# Sur l'onglet Trésorerie, le bloc mène au budget qui explique la prévision de fin de saison.
	var ici := _onglet_courant(app) == "cash"
	var carte := _carte(app, canvas, rectangle, "FinanceMetric0", _onglet_cible("budget" if ici else "cash"), "Ouvrir · Budget" if ici else "Ouvrir · Trésorerie", "Trésorerie du club : prévision de fin de saison, dans l'onglet Budget." if ici else "Trésorerie du club : tous les mouvements et le solde, dans l'onglet Trésorerie.")
	var decalage := maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var cash: Variant = v.cash
	_titre(carte, 20, 36 + decalage, "TRÉSORERIE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var montant := _titre(carte, 20, 92 + decalage, U.amount(cash), 52, Charte.D if cash != null and float(cash) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40)
	montant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prevue: Variant = v.forecast
	_texte(carte, 20, 124 + decalage, "fin de saison prévue : %s" % U.amount(prevue) if prevue != null else "fin de saison prévue : —", 17, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		_titre(carte_marche, 20, 36 + decalage, "MARCHÉ DU RECRUTEMENT", 22, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_titre(carte_marche, 20, 92 + decalage, "%d profils" % marche.size(), 46, Charte.IVOIRE, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(carte_marche, 20, 124 + decalage, "%d accessibles" % accessibles.size(), 17, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var total := Budget.season_total(transfer)
	var engage := maxi(0, int(transfer.get("depense", 0)) - int(transfer.get("reconstitue", 0)))
	var carte := _carte(app, canvas, rectangle, "FinanceMetric1", cible, "Ouvrir · Recrutement", Budget.detail(transfer, cash) + "\n%d profils au marché, %d accessibles." % [marche.size(), accessibles.size()])
	var titre := _titre(carte, 20, 36 + decalage, "BUDGET DE TRANSFERTS", 22, Charte.IVOIRE_2, largeur - 40)
	titre.name = "CardTitle"
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cellule := (largeur - 40.0 - 16.0) / 3.0
	var valeurs := [["Alloué", G.euros(total), "FinanceTransferBudgetAllocated", Charte.IVOIRE], ["Engagé", G.euros(engage), "FinanceTransferBudgetEngaged", Charte.IVOIRE], ["Restant", Budget.remaining(transfer), "FinanceTransferBudgetAmount", Charte.IVOIRE if int(transfer.get("disponible", 0)) > 0 else Charte.D]]
	for i in 3:
		var x := 20.0 + i * (cellule + 8.0)
		_bloc(carte, Rect2(x, 52 + decalage, cellule, 66))
		_etiquette(carte, x + 10, 72 + decalage, valeurs[i][0], cellule - 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var valeur := _titre(carte, x + 10, 106 + decalage, valeurs[i][1], 28, valeurs[i][3], cellule - 16)
		valeur.name = valeurs[i][2]
		valeur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var part := 100.0 * float(engage) / float(total) if total > 0 else 0.0
	D.bar(carte, Rect2(20, 128 + decalage, largeur - 40, 8), part, Charte.IVOIRE_2)
	var depenses := _dernieres_depenses(ledger)
	var limite := int(transfer.get("disponible", 0)) < int(transfer.get("reste", transfer.get("disponible", 0)))
	var note := "Limité par la caisse du club" if limite else depenses if not depenses.is_empty() else "Rien d'engagé pour l'instant"
	_texte(carte, 20, 160 + decalage, note, 16, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _carte_marge(app: Control, canvas: Control, rectangle: Rect2, finance: Dictionary, v: Dictionary) -> void:
	var ici := _onglet_courant(app) == "budget"
	var carte := _carte(app, canvas, rectangle, "FinanceMetric2", _onglet_cible("cash" if ici else "budget"), "Ouvrir · Trésorerie" if ici else "Ouvrir · Budget", "Recettes régulières moins charges de la semaine. Ne comprend pas les recettes de match, la prime de classement ni le soutien du propriétaire : voir la trésorerie prévue en fin de saison.")
	var decalage := maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var marge: Variant = v.margin
	_titre(carte, 20, 36 + decalage, "MARGE COURANTE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := "—"
	if marge != null: texte = ("+" if float(marge) > 0.0 else "") + U.amount(marge)
	_titre(carte, 20, 92 + decalage, texte + (" / sem." if marge != null else ""), 52, Charte.D if marge != null and float(marge) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var recettes: Variant = finance.get("weeklyIncome")
	var charges: Variant = finance.get("weeklyCosts")
	if _etroit() and rectangle.size.y >= 200.0:
		# Carte étroite de la Synthèse : recettes et charges sur deux lignes plutôt que tronquées.
		_texte(carte, 20, 124 + decalage, "recettes %s" % U.amount(recettes), 17, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(carte, 20, 152 + decalage, "charges %s" % U.amount(charges), 17, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_texte(carte, 20, 124 + decalage, "recettes %s · charges %s" % [U.amount(recettes), U.amount(charges)], 17, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---- Synthèse -----------------------------------------------------------------------------------------------

static func _synthese(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary) -> void:
	_verdict_panneau(app, canvas, Rect2(0, HAUT, 880, 300), v, false, "summary")
	_carte_tresorerie(app, canvas, Rect2(896, HAUT, 400, 300), accounts, finance, v)
	_carte_budget(app, canvas, Rect2(1312, HAUT, 500, 300), accounts, ledger)
	_carte_marge(app, canvas, Rect2(1828, HAUT, 420, 300), finance, v)
	_watch(_panneau(canvas, Rect2(0, 466, 690, 380), "Vigilances", "FinanceWatch"), app, finance, 690)
	_due(_panneau(canvas, Rect2(706, 466, 840, 380), "Prochaines échéances", "FinanceDue"), app, finance, 840)
	_allocation(_panneau(canvas, Rect2(1562, 466, 686, 380), "Où va l'argent", "FinanceAllocation", "par semaine"), app, finance, 686)
	_chart(app, _panneau(canvas, Rect2(0, 862, 2248, 368), "Les 12 derniers mouvements", "FinanceChart"), ledger, 2248)

static func _chart(app: Control, card: Panel, ledger: Array, largeur: float) -> void:
	var recent := ledger.slice(0,12)
	var graph := LedgerPlot.new()
	graph.name = "FinanceLedgerPlot"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.trait_club = Charte.club_trait(app.accent)
	graph.set_operations(recent)
	card.add_child(graph)
	var haut := 84.0
	var hauteur := card.size.y / maxf(C.density, .01) - 150.0
	D.place(graph, Rect2(150, haut, largeur - 190, hauteur))
	if not recent.is_empty():
		for valeur: float in graph.graduations():
			var y := haut + hauteur * (graph.maximum - valeur) / (graph.maximum - graph.minimum)
			_texte(card, 134, y + 6, "0 €" if is_zero_approx(valeur) else U.amount(valeur), 16, Charte.IVOIRE_2, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	var pas := (largeur - 190) / 12.0
	for i in recent.size():
		var x := 150.0 + (largeur - 190) - pas * (i + .5)
		var locator := ledger_locator(ledger,i)
		if not locator.is_empty():
			var link := Button.new()
			link.name = "FinanceChartOperation_" + str(i)
			link.flat = true
			link.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			link.add_theme_stylebox_override("hover",_style(Color(Charte.IVOIRE,.08),Charte.IVOIRE_2,2))
			link.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,Charte.IVOIRE,2))
			link.set_meta("ledger_index",i)
			var caption := "Mouvement %s · %s · %s" % ["le plus récent" if i == 0 else "n° %d en remontant" % (i+1),str(recent[i].title),G.euros(recent[i].amount)]
			Link.bind(link,app,{"kind":"finance","id":locator},caption)
			card.add_child(link)
			D.place(link,Rect2(x-pas*.5,haut,pas,hauteur))
	# Légende : forme et mot (série « nous » en trait du club, entrées pleines, sorties hachurées).
	var trait_legende := _bloc(card, Rect2(480, 28, 30, 5), Charte.club_trait(app.accent))
	trait_legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 520, 38, "Solde cumulé de ces mouvements", 16, Charte.IVOIRE, 440)
	_hachure_legende(card, 980, 24, true)
	_texte(card, 1008, 38, "Entrées", 16, Charte.IVOIRE, 130)
	_hachure_legende(card, 1150, 24, false)
	_texte(card, 1178, 38, "Sorties (hachurées)", 16, Charte.IVOIRE, 300)
	if largeur > 2000: _texte(card, largeur - 20, 38, "plus ancien → plus récent · clic : le mouvement", 15, Charte.IVOIRE_2, 700, HORIZONTAL_ALIGNMENT_RIGHT)
	if recent.is_empty():
		_titre(card, largeur * .5, 190, "Le premier mouvement reste à venir", 36, Charte.IVOIRE, 900, HORIZONTAL_ALIGNMENT_CENTER)
		_texte(card, largeur * .5, 226, "La courbe se remplit après une journée jouée ou une décision financière.", 19, Charte.IVOIRE_2, 1000, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var bas := haut + hauteur + 26.0
		_texte(card, 150, bas, "plus ancien", 16, Charte.IVOIRE_2, 300)
		_texte(card, largeur - 40, bas, "plus récent", 16, Charte.IVOIRE_2, 300, HORIZONTAL_ALIGNMENT_RIGHT)

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

## Répartition des charges : chaque ligne ouvre l'écran qui la détaille (salaires, budget, infrastructures).
static func _allocation(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var rows := _weekly(finance)
	var total := float(finance.get("weeklyCosts",0))
	var remaining := int(finance.get("remainingWeeks",0))
	var destinations := [func(): _open_wages(app, false), func(): _vers_formation_ou_budget(app), func(): _strategy(app)]
	var noms := ["Salaires", "Formation" if _onglet_courant(app) == "budget" else "Budget", "Infrastructures"]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 70.0 + i * 74.0
		var ratio := float(item[2])*100.0/total if total > 0 and item[2] != null else 0.0
		var reste := "Reste de la saison : %s sur %d semaine(s)." % [U.amount(float(item[2])*remaining) if item[2] != null else "—", remaining]
		_zone(card, Rect2(10, y - 4, largeur - 20, 66), destinations[i], "FinanceAllocationRow" + str(i), "Ouvrir · %s. %s" % [noms[i], reste])
		D.text(card, 22, y + 24, item[0], 22, Charte.IVOIRE, 600, largeur - 330).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.bar(card, Rect2(22, y + 40, largeur - 44, 9), ratio, Charte.IVOIRE_2)
		D.text(card, largeur - 22, y + 24, "%d %%" % roundi(ratio) if total > 0 else "—", 22, Charte.IVOIRE, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(card, largeur - 116, y + 24, G.euros(item[2]) if item[2] != null else "—", 19, Charte.IVOIRE_2, 500, 150, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 22, 326, "Engagements connus · prévision sur %d semaine(s)" % remaining, 16, Charte.IVOIRE_2, largeur - 44)
	# Un seul bouton ivoire par écran : sur l'onglet Budget, c'est « Ouvrir les décisions financières » ; ici un lien.
	var sur_budget := _onglet_courant(app) == "budget"
	_bouton(card, Rect2(largeur - 262, 334, 242, 38), "Ajuster le budget" if sur_budget else "AJUSTER LE BUDGET", func(): _strategy(app), "lien" if sur_budget else "ivoire", "arrow", "FinanceAdjustBudget")

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
		"Contrat": return ["Salaires et contrats", func(): _open_wages(app, false)]
		"Salaires", "Staff": return ["Salaires", func(): _open_wages(app, false)]
		"Installations": return ["Infrastructures", func(): _strategy(app)]
		"Billetterie", "Partenaire", "Matchs", "Prime": return ["Budget", func(): _ouvrir_onglet(app, "budget")]
	return ["Budget", func(): _ouvrir_onglet(app, "budget")]

static func _pagination(app: Control, card: Panel, total: int, limit: int, key: String, largeur: float) -> int:
	var state_key := PAGE_KEY_PREFIX + key
	var page_count := maxi(1,ceili(float(total)/limit))
	var page := clampi(int(app.management_ui.get(state_key,0)),0,page_count-1)
	var previous_id := "FinancePrev_" + key
	var next_id := "FinanceNext_" + key
	# Largeurs prévues pour le plancher de 12 px (1280 × 720) : « Préc. » ne chevauche plus le compteur.
	var previous := _bouton(card, Rect2(largeur - 410, 10, 130, 36), "Préc.", func(): _page(app, state_key, page-1, previous_id, next_id), "lien", "", previous_id)
	var next := _bouton(card, Rect2(largeur - 150, 10, 130, 36), "Suiv.", func(): _page(app, state_key, page+1, next_id, previous_id), "lien", "", next_id)
	previous.disabled = page == 0
	next.disabled = page + 1 >= page_count
	_texte(card, largeur - 215, 36, "%d / %d" % [page+1,page_count], 17, Charte.IVOIRE_2, 130, HORIZONTAL_ALIGNMENT_CENTER)
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
	_bloc(card, Rect2(10, 60, largeur - 20, 36), Charte.PANNEAU_2)
	_etiquette(card, 24, 84, "N°", 60)
	_etiquette(card, 113, 84, "Mouvement", 400)
	_etiquette(card, chip_x, 84, "Catégorie", 200)
	_etiquette(card, droite_entrees, 84, "Entrées", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	_etiquette(card, droite_sorties, 84, "Sorties", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	if ledger.is_empty():
		_titre(card, 23, 160, "Aucune opération enregistrée dans ce journal.", 30, Charte.IVOIRE, largeur - 46)
		_texte(card, 23, 196, "Les mouvements seront consultables ici au fil de la carrière.", 20, Charte.IVOIRE_2, largeur - 46)
	var selected_index := ledger_index(app,app.management_ui.get(LEDGER_SELECTION_KEY,"")) if key == "cash" else -1
	for i in mini(limit,ledger.size()-first):
		var entry: Dictionary = ledger[first+i]
		var title := str(entry.get("title","Opération"))
		var category := _category(title)
		var amount := float(entry.get("amount",0))
		var y := 100.0 + i * 33.0
		var selected := selected_index == first+i
		if selected: _bloc(card, Rect2(12, y, largeur - 24, 32), Charte.PANNEAU_3, Charte.IVOIRE).name = "FinanceLedgerSelection"
		elif i%2 == 0: _bloc(card, Rect2(12, y, largeur - 24, 32), Charte.PANNEAU_2)
		var destination := _destination_categorie(app, str(category[0]))
		_zone(card, Rect2(12, y, largeur - 24, 32), destination[1], "FinanceLedgerRow_%d" % (first+i), "Ouvrir · %s : %s" % [destination[0], title])
		_texte(card, 24, y + 22, "%02d" % (first+i+1), 17, Charte.IVOIRE_2, 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title_label := _texte(card, 113, y + 22, title, 19, Charte.IVOIRE, chip_x - 130)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if selected:
			title_label.name = "FinanceLedgerTarget"
			title_label.focus_mode = Control.FOCUS_ALL
			title_label.set_meta("ledger_index",selected_index)
			title_label.set_meta("ledger_entry",entry.duplicate(true))
			title_label.accessibility_name = "Mouvement n° %d · %s · %s" % [selected_index+1,title,G.euros(amount)]
		U.icon(card, category[1], Vector2(chip_x, y + 5), Charte.IVOIRE_2, 21)
		_texte(card, chip_x + 30, y + 22, category[0], 17, Charte.IVOIRE_2, 170).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(card, droite_entrees, y + 22, "+"+G.euros(amount) if amount > 0 else G.euros(amount) if amount == 0 else "—", 18, Charte.IVOIRE if amount > 0 else Charte.IVOIRE_3, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(card, droite_sorties, y + 22, "−"+G.euros(absf(amount)) if amount < 0 else "—", 18, Charte.IVOIRE if amount < 0 else Charte.IVOIRE_3, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---- Vigilances et échéances -----------------------------------------------------------------------------------

## Vigilances réelles : contrats à anticiper, devis d'infrastructures, masse salariale proche du plafond de la ligue.
static func _vigilances(app: Control, finance: Dictionary) -> Array:
	var lignes: Array = []
	var counts := P.contract_counts(app.model)
	var count := int(counts.by_horizon)
	if count > 0:
		lignes.append({"id": "FinanceWatchContracts", "titre": P.plural(count, "contrat à anticiper", "contrats à anticiper"), "detail": "%s en fin de saison · horizon fin %s" % [counts.end_of_season, G.season_label(counts.horizon_season)], "lien": "Contrats", "action": func(): _open_wages(app, true)})
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		lignes.append({"id": "FinanceWatchFacilities", "titre": "Infrastructures", "detail": "Devis indicatif · " + G.euros(quote.cost), "lien": "Infrastructures", "action": func(): _strategy(app)})
	var budget: Variant = finance.get("budget")
	if budget is Dictionary and budget.get("plafondSalarial") != null and float(budget.plafondSalarial) > 0.0 and budget.get("masseSalariale") != null:
		var part := roundi(100.0 * float(budget.masseSalariale) / float(budget.plafondSalarial))
		if part >= 80:
			lignes.append({"id": "FinanceWatchCap", "titre": "Masse salariale à %d %% du plafond de la ligue" % part, "detail": "marge restante : %s" % U.amount(budget.get("margePlafond")), "lien": "Budget" if _onglet_courant(app) == "wages" else "Salaires", "action": func(): _ouvrir_onglet(app, "budget") if _onglet_courant(app) == "wages" else _open_wages(app, false)})
	return lignes

static func _watch(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var lignes := _vigilances(app, finance)
	if not lignes.is_empty(): _etiquette(card, largeur - 20, 38, "%d à traiter" % lignes.size(), 200, HORIZONTAL_ALIGNMENT_RIGHT)
	if lignes.is_empty():
		_symbole(card, Rect2(20, 80, 26, 26), "coche", Charte.IVOIRE)
		_texte(card, 58, 100, "Rien à surveiller cette semaine.", 20, Charte.IVOIRE, largeur - 80)
		return
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var y := 68.0 + i * 76.0
		var zone := _zone(card, Rect2(10, y, largeur - 20, 70), ligne.action, str(ligne.id), "%s · %s" % [ligne.titre, ligne.detail])
		zone.accessibility_name = "%s · %s" % [ligne.titre, ligne.detail]
		_symbole(card, Rect2(20, y + 20, 28, 28), "exclam", Charte.IVOIRE)
		_texte(card, 62, y + 28, str(ligne.titre), 19, Charte.IVOIRE, largeur - 290).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Le détail passe sous le lien (aligné sur le titre) et prend toute la largeur : plus de troncature à 1280.
		_texte(card, 62, y + 56, str(ligne.detail), 16, Charte.IVOIRE_2, largeur - 86).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(card, largeur - 24, y + 28, str(ligne.lien) + " →", 17, Charte.IVOIRE, 220, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < lignes.size() - 1: D.line(card, Vector2(20, y + 73), Vector2(largeur - 20, y + 73), Color(Charte.FILET,.7))

static func _due(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var remaining := int(finance.get("remainingWeeks",0))
	var week := int(app.model.meta.get("week",0)) + 1
	_etiquette(card, largeur - 20, 38, "semaine %d" % week, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	if remaining <= 0:
		_texte(card, 22, 119, "Aucun paiement hebdomadaire restant dans la projection.", 20, Charte.IVOIRE_2, largeur - 44)
		return
	_etiquette(card, 22, 84, "Date", 100)
	_etiquette(card, 140, 84, "Échéance", 300)
	_etiquette(card, largeur - 22, 84, "Montant", 160, HORIZONTAL_ALIGNMENT_RIGHT)
	var rows := [["Salaires et cotisations" if finance.has("budget") else "Salaires de l’effectif", finance.get("weeklyWages"), func(): _open_wages(app, false), "Salaires"],
		["Centre de formation" if finance.get("budget") is Dictionary else "Formation à la séance", formation_weekly(finance), func(): _vers_formation_ou_budget(app), "Formation" if _onglet_courant(app) == "budget" else "Budget"],
		["Recettes régulières hors guichet" if finance.has("budget") else "Recettes prévues au modèle", finance.get("weeklyIncome"), func(): _ouvrir_onglet(app, "cash"), "Trésorerie"]]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 96.0 + i * 52.0
		if i % 2 == 0: _bloc(card, Rect2(10, y, largeur - 20, 48), Charte.PANNEAU_2)
		_zone(card, Rect2(10, y, largeur - 20, 48), item[2], "FinanceDueRow" + str(i), "Ouvrir · " + str(item[3]))
		_texte(card, 22, y + 31, "Sem. %02d" % week, 17, Charte.IVOIRE_2, 110).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(card, 140, y + 31, str(item[0]), 19, Charte.IVOIRE, largeur - 360).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var amount: Variant = item[1]
		var prefix := "−" if i < 2 else "+"
		_texte(card, largeur - 22, y + 31, prefix + G.euros(absf(float(amount))) if amount != null and float(amount) != 0.0 else G.euros(amount) if amount != null else "—", 19, Charte.IVOIRE, 190, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 22, 276, "Chaque ligne se répète jusqu'à la fin de la saison · %d sem." % remaining, 16, Charte.IVOIRE_2, largeur - 44)

# ---- Colonne de verdict fixe (onglets autres que la Synthèse) -------------------------------------------------------

static func _colonne(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary, tab: String) -> void:
	_verdict_panneau(app, canvas, Rect2(0, HAUT, COLONNE_W, 330), v, true, tab)
	_carte_tresorerie(app, canvas, Rect2(0, 492, COLONNE_W, 130), accounts, finance, v)
	_carte_budget(app, canvas, Rect2(0, 634, COLONNE_W, 190), accounts, ledger)
	_carte_marge(app, canvas, Rect2(0, 836, COLONNE_W, 130), finance, v)
	_watch(_panneau(canvas, Rect2(0, 978, COLONNE_W, 252), "Vigilances", "FinanceWatch"), app, finance, COLONNE_W)

static func _cash(app: Control, canvas: Control, zone: Rect2, ledger: Array) -> void:
	var x := zone.position.x
	_chart(app, _panneau(canvas, Rect2(x, zone.position.y, zone.size.x, 330), "Solde et mouvements", "FinanceChart"), ledger, zone.size.x)
	var incoming := 0.0
	var outgoing := 0.0
	for entry: Dictionary in ledger:
		var amount := float(entry.get("amount",0))
		incoming += maxf(0.0,amount)
		outgoing += maxf(0.0,-amount)
	var totals := _panneau(canvas, Rect2(x, zone.position.y + 346, zone.size.x, 104), "", "FinanceJournalTotals")
	var details := [["Entrées enregistrées", "+" + G.euros(incoming)], ["Sorties enregistrées", "−" + G.euros(outgoing)], ["Solde net des mouvements", ("+" if incoming - outgoing > 0 else "") + G.euros(incoming - outgoing).replace("-", "−")]]
	var colonne := zone.size.x / 3.0
	for i in details.size():
		# Chaque total a l'allure des chiffres cliquables du haut : il ouvre le Budget (recettes et charges de la saison).
		var total_lien := _zone(totals, Rect2(i * colonne + 6, 6, colonne - 12, 92), func(): _ouvrir_onglet(app, "budget"), "FinanceTotalLink" + str(i), "Ouvrir · Budget : recettes et charges prévues de la saison")
		_lier(app, total_lien, _onglet_cible("budget"), "Ouvrir · Budget")
		_etiquette(totals, 20 + i * colonne, 34, details[i][0], colonne - 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_titre(totals, 20 + i * colonne, 82, details[i][1], 38, Charte.IVOIRE, colonne - 30).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(canvas, x + 4, zone.position.y + 470, "%d mouvements conservés · clic sur une ligne : l'écran qui l'explique · le journal ne se confond pas avec la trésorerie du club." % ledger.size(), 16, Charte.IVOIRE_2, zone.size.x - 8)
	var journal := _panneau(canvas, Rect2(x, zone.position.y + 484, zone.size.x, 100 + LEDGER_PAGE * 33 + 14), "Journal des flux", "FinanceLedger")
	_ledger(journal, app, ledger, LEDGER_PAGE, "cash", zone.size.x)

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

static func _wage_sort(app: Control, key: String) -> void:
	var due_only: bool = app.management_ui.get(WAGES_SCOPE_KEY,false)
	var state: Dictionary = app.management_ui.get("finance_wage_sort",{"key":"contractEnd" if due_only else "salary","descending":not due_only})
	app.management_ui.finance_wage_sort = {"key":key,"descending":not bool(state.get("descending",false)) if state.get("key") == key else key == "salary"}
	app.management_ui["finance_wage_scroll"] = 0
	app._render()
	var button := app.find_child("FinanceSort_"+key,true,false)
	if button != null: FocusLater.grab(button)

static func _wages(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var largeur := zone.size.x
	var wages := _panneau(canvas, Rect2(zone.position.x, zone.position.y, largeur, zone.size.y), "Contrats et salaires", "FinanceSalaryTable")
	var all_players: Array = app.model.get("squad", [])
	var due_only: bool = app.management_ui.get(WAGES_SCOPE_KEY, false)
	var squad := P.contracts(app.model) if due_only else all_players.duplicate()
	if due_only:
		var horizon := int(app.model.meta.get("season", 1)) + 1
		var scope := "%s jusqu’à la fin de %s · dont %d en fin de saison" % [P.plural(squad.size(), "échéance", "échéances"), G.season_label(horizon), P.contract_counts(app.model).end_of_season]
		_texte(wages, 380, 36, scope, 18, Charte.IVOIRE, 640).name = "FinanceWagesScope"
		_bouton(wages, Rect2(largeur - 330, 10, 310, 36), "Tous les %d joueurs" % all_players.size(), func(): _open_wages(app, false), "lien", "arrow", "FinanceWagesAll")
	else:
		_etiquette(wages, largeur - 20, 38, "%d joueurs · clic sur un nom : sa fiche" % squad.size(), 500, HORIZONTAL_ALIGNMENT_RIGHT)
	var sort_state: Dictionary = app.management_ui.get("finance_wage_sort", {"key":"contractEnd" if due_only else "salary", "descending":not due_only})
	squad = wage_rows(squad,str(sort_state.key),bool(sort_state.descending))
	_bloc(wages, Rect2(12, 62, largeur - 24, 38), Charte.PANNEAU_2)
	var colonnes := [["JOUEUR",25,"name",520],["POSTE",575,"pos",250],["FIN DE CONTRAT",850,"contractEnd",260],[G.salary_period().to_upper(),1130,"salary",230]]
	for item: Array in colonnes:
		var arrow := (" ▼" if sort_state.descending else " ▲") if sort_state.key == item[2] else " ↕"
		var tri := _bouton(wages, Rect2(item[1]-4, 63, item[3], 36), str(item[0])+arrow, _wage_sort.bind(app,str(item[2])), "lien", "", "FinanceSort_"+str(item[2]))
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if item[2] == "salary" else HORIZONTAL_ALIGNMENT_LEFT
	var scroll := ScrollContainer.new()
	scroll.name = "FinanceWageScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events = false
	wages.add_child(scroll)
	D.place(scroll,Rect2(12,104,largeur - 24,zone.size.y - 120))
	var rows := Control.new()
	rows.name = "FinanceWageRows"
	rows.custom_minimum_size = Vector2(C.px(largeur - 50),C.px(maxi(1,squad.size())*34))
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(rows)
	scroll.set_deferred("scroll_vertical",int(app.management_ui.get("finance_wage_scroll",0)))
	scroll.get_v_scroll_bar().value_changed.connect(func(value): app.management_ui["finance_wage_scroll"] = int(value))
	for i in squad.size():
		var player: Dictionary = squad[i]
		var y := i*34
		if i%2 == 0: _bloc(rows, Rect2(0,y,largeur - 50,33), Charte.PANNEAU_2)
		var name_link := _bouton(rows, Rect2(21,y+1,520,31), str(player.get("name","—")), func(): pass, "lien", "", "FinancePlayerName_"+str(player.id).validate_node_name())
		name_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Link.bind(name_link,app,{"kind":"player","id":str(player.id),"section":"contract"},"Consulter le contrat · " + str(player.get("name","")))
		MiniFiche.lier(app, name_link, str(player.id), "squad")
		D.text(rows, 575, y + 23, player.get("pos","—"), 18, Charte.IVOIRE_2, 500, 250, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(rows, 850, y + 23, G.contract_year(player.get("contractEnd")), 18, Charte.IVOIRE_2, 500, 260, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(rows, 1330, y + 23, G.salary_amount(player.get("salary",0)), 18, Charte.IVOIRE, 700, 200, HORIZONTAL_ALIGNMENT_RIGHT)
		_bouton(rows, Rect2(1356,y+1,200,31), "Voir le contrat", func(): _open_player(app, str(player.id)), "lien", "arrow", "FinancePlayer_"+str(player.id).replace(":","_"))
	if squad.is_empty():
		var empty := "Aucun contrat à anticiper d’ici cette échéance." if due_only else "Aucun joueur sous contrat dans cette carrière."
		_titre(wages, 24, 153, empty, 28, Charte.IVOIRE_2, largeur - 48)

static func _open_player(app: Control, player_id: String) -> void:
	app.navigation_controller.open_entity({"kind":"player","id":player_id,"section":"contract"})

static func _transfers(app: Control, canvas: Control, zone: Rect2, ledger: Array) -> void:
	var contracts := ledger.filter(func(entry: Dictionary): return _category(str(entry.get("title","")))[0] == "Contrat")
	var gauche := 1070.0
	var x := zone.position.x
	_ledger(_panneau(canvas, Rect2(x, zone.position.y, gauche, zone.size.y), "Mouvements de contrats et transferts", "FinanceTransferLedger"), app, contracts, 20, "transfers", gauche)
	var card := _panneau(canvas, Rect2(x + gauche + 16, zone.position.y, zone.size.x - gauche - 16, zone.size.y), "Préparer le recrutement", "FinanceTransferActions")
	var largeur := zone.size.x - gauche - 16
	var market: Array = app.model.get("market",[])
	_titre(card, 23, 132, "%d profils au marché" % market.size(), 40, Charte.IVOIRE, largeur - 46)
	_texte(card, 23, 172, "Prime et salaire détaillés avant signature.", 19, Charte.IVOIRE_2, largeur - 46)
	_bouton(card, Rect2(23, 196, largeur - 46, 50), "OUVRIR LE RECRUTEMENT", func(): app._navigate("Recrutement"), "ivoire", "arrow", "FinanceRecruitment")
	D.line(card, Vector2(23, 280), Vector2(largeur - 23, 280), Charte.FILET)
	_titre(card, 23, 336, "Contrats du groupe", 34, Charte.IVOIRE, largeur - 46)
	_texte(card, 23, 372, "Prolongations : depuis les fiches joueurs.", 19, Charte.IVOIRE_2, largeur - 46)
	_bouton(card, Rect2(23, 394, largeur - 46, 44), "Consulter les salaires et les échéances", func(): _open_wages(app, false), "lien", "arrow", "FinanceTransferContracts")

# Classement financier du championnat (native/engine/club-finance-health.cjs) : du club le plus solide au plus fragile,
# avec l’étiquette, le propriétaire et la courbe des trois dernières saisons. Aucun montant : un club ne publie pas sa caisse.
static func _clubs(app: Control, canvas: Control, zone: Rect2, accounts: Dictionary) -> void:
	var clubs: Array = accounts.get("clubs", [])
	var largeur := zone.size.x
	var panel := _panneau(canvas, Rect2(zone.position.x, zone.position.y, largeur, zone.size.y), "Santé financière des clubs · %s" % P.league_name(app.model), "FinanceClubsHealth")
	if clubs.is_empty():
		_titre(panel, 25, 140, "Les comptes des clubs ne sont pas encore connus.", 28, Charte.IVOIRE_2, largeur - 50)
		return
	# Sans saison close, la même phrase sur chaque ligne n'apprend rien : elle est dite une fois, ici.
	var sans_courbe := clubs.all(func(club: Dictionary): return not (club.get("courbe") is Array) or (club.courbe as Array).is_empty())
	_texte(panel, 25, 88, "Du plus solide au plus fragile, d’après la trésorerie de chaque club rapportée à la réserve qu’il se fixe." + (" Les trois dernières saisons se rempliront à la première saison close." if sans_courbe else ""), 18, Charte.IVOIRE_2, largeur - 50)
	var head := [["#",25,60],["Club",95,440],["Santé",560,170],["Propriétaire",760,300],["Trois dernières saisons",1090,480]]
	for h: Array in head: D.text(panel, h[1], 126, h[0], 15, Charte.IVOIRE_2, 600, h[2])
	var row_height := minf(38.0, (zone.size.y - 150.0) / maxf(1.0, clubs.size()))
	for i in clubs.size():
		var club: Dictionary = clubs[i]
		var y := 140.0 + i * row_height
		var own := bool(club.get("own", false))
		if own:
			# Ton club : fond relevé + liseré ivoire à gauche (pas de cadre complet), et « · ton club » écrit.
			_bloc(panel, Rect2(14, y + 1, largeur - 28, row_height - 2), Charte.PANNEAU_3)
			_bloc(panel, Rect2(14, y + 1, 5, row_height - 2), Charte.IVOIRE)
		elif i % 2 == 1: _bloc(panel, Rect2(14, y + 1, largeur - 28, row_height - 2), Charte.PANNEAU_2)
		var base := y + row_height * .72
		D.text(panel, 25, base, str(i + 1), 20, Charte.IVOIRE_2, 600, 60)
		var caption := G.club_name(club) + ("  · ton club" if own else "")
		Link.name_link(app, panel, Rect2(95, y + 3, 440, row_height - 6), "club", str(int(club.get("id", -1))), caption, 21, Charte.IVOIRE, "FinanceClubName" + str(i))
		# Santé : liseré teinté + mot (charte : ni pastille arrondie ni cadre complet, la couleur jamais seule).
		var sante := Control.new()
		sante.name = "FinanceClubHealth" + str(i)
		sante.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(sante)
		D.place(sante, Rect2(560, y + (row_height - 32) * .5, 180, 32))
		_bloc(sante, Rect2(0, 5, 8, 22), Health.color(club))
		D.text(sante, 20, 24, Health.label(club), 20, Charte.IVOIRE, 700, 160).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(panel, 760, base, Health.owner(club), 20, Charte.IVOIRE, 500, 300)
		Health.sparkline(panel, Rect2(1090, y + 3, 120, row_height - 6), club, "FinanceClubCurve" + str(i))
		if not sans_courbe: D.text(panel, 1230, base, Health.reading(club), 17, Charte.IVOIRE_2, 500, largeur - 1250)

# ---- Budget -------------------------------------------------------------------------------------------------

# Leviers de redressement (consultatifs) : le verdict du directeur financier, puis les leviers réels et ce
# que chacun rapporte à la prévision ; le détail complet de chaque levier est dans l'infobulle.
static func _levers(card: Panel, levers: Dictionary, largeur: float, y: float) -> float:
	var state := str(levers.get("etat",""))
	var verdict_texte := _texte(card, 25, y, str(levers.get("conclusion","")), 20, Charte.IVOIRE, largeur - 50)
	verdict_texte.name = "FinanceLeversVerdict"
	var items: Array = levers.get("leviers", [])
	if items.is_empty():
		_texte(card, 25, y + 34, "Les devis et conditions de signature sont détaillés dans les décisions du club.", 19, Charte.IVOIRE_2, largeur - 50).name = "FinanceLeversList"
		return y + 40.0
	var parts := PackedStringArray()
	var details := PackedStringArray()
	for item: Dictionary in items:
		var gain := float(item.get("effet",0))
		parts.append("%s%s" % [str(item.get("titre","")), " (+%s)" % G.euros(gain) if gain > 0.0 else ""])
		details.append("%s : %s" % [str(item.get("titre","")), str(item.get("contrepartie",""))])
	var line := _texte(card, 25, y + 34, "Leviers : " + " · ".join(parts), 19, Charte.IVOIRE_2, largeur - 50)
	line.name = "FinanceLeversList"
	line.tooltip_text = "\n".join(details)
	if state.is_empty(): return y + 40.0
	return y + 40.0

# Budget de saison : propriétaire, règles de la ligue et prévision, en lignes de texte sous les décisions.
static func _season_budget(card: Panel, budget: Dictionary, largeur: float, y: float) -> void:
	var owner: Dictionary = budget.get("proprietaire", {})
	var envelope := float(owner.get("enveloppe",0))
	var lines := ["Propriétaire : %s · %s" % [str(owner.get("libelle","—")), "comble jusqu’à %s de pertes cette saison" % U.amount(envelope) if envelope > 0.0 else "aucune perte comblée, chaque euro dépensé doit être gagné"]]
	var rules := "Masse salariale : %s par an" % U.amount(budget.get("masseSalariale"))
	if budget.get("plafondSalarial") != null: rules += " · plafond de la ligue %s, marge %s" % [U.amount(budget.plafondSalarial),U.amount(budget.get("margePlafond"))]
	if budget.get("limiteRecettes") != null: rules += " · limite de 52 %% des recettes %s, marge %s" % [U.amount(budget.limiteRecettes),U.amount(budget.get("margeRecettes"))]
	lines.append(rules)
	lines.append("Saison prévue : recettes %s · charges %s · résultat %s" % [U.amount(budget.get("recettesPrevues")),U.amount(budget.get("chargesPrevues")),U.amount(budget.get("resultatPrevu"))])
	var fine := float(budget.get("amendePrevue",0))
	lines.append("Amende de la ligue encourue : %s" % U.amount(fine) if fine > 0.0 else "Aucune amende de la ligue encourue · prime de classement attendue %s" % U.amount(budget.get("primeClassementPrevue")))
	for i in lines.size():
		var line := _texte(card, 25, y + i * 30, lines[i], 18, Charte.IVOIRE if i == 0 else Charte.IVOIRE_2, largeur - 50)
		line.name = "FinanceSeasonBudget%d" % i

static func _budget(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var x := zone.position.x
	var y0 := zone.position.y
	var largeur := zone.size.x
	var decisions := _panneau(canvas, Rect2(x, y0, largeur, 600), "Engagements et investissements", "FinanceCommitments", "%d semaines restantes sur %d" % [int(finance.get("remainingWeeks",0)),int(finance.get("weeksPerSeason",0))])
	var cards := [["Formation","Investissement par séance",finance.get("academyInvestment"),func(): app._navigate("Formation"),"Formation"],["Installations","Niveau indisponible",null,func(): _strategy(app),"Infrastructures"],["Partenaires","Recettes hebdomadaires du modèle",finance.get("weeklyIncome"),func(): _ouvrir_onglet(app, "cash"),"Trésorerie"]]
	if finance.get("budget") is Dictionary and finance.budget.get("centreFormationHebdo") != null:
		cards[0][1] = "Centre de formation · par semaine" + (" dont %s payés en plus" % U.amount(finance.get("academyInvestment")) if float(finance.get("academyInvestment", 0)) > 0.0 else "")
		cards[0][2] = formation_weekly(finance)
	if finance.get("budget") is Dictionary: cards[2] = ["Recettes régulières","Par semaine · partenaires, ligue, abonnés",finance.get("weeklyIncome"),func(): _ouvrir_onglet(app, "cash"),"Trésorerie"]
	var facility: Variant = finance.get("facility")
	if facility is Dictionary:
		cards[1][1] = "Niveau actuel %s / 10 · devis suivant" % G.n(facility.level)
		cards[1][2] = facility.cost
	var tuile_w := (largeur - 40.0 - 32.0) / 3.0
	for i in cards.size():
		var item: Array = cards[i]
		var tuile := _panneau(decisions, Rect2(20 + i * (tuile_w + 16), 76, tuile_w, 150), "", "FinanceCommitment" + str(i))
		_zone(tuile, Rect2(0, 0, tuile_w, 150), item[3], "FinanceCommitmentLink" + str(i), "Ouvrir · " + str(item[4]))
		_etiquette(tuile, 18, 34, item[0], tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 1 and not facility is Dictionary:
			_titre(tuile, 18, 90, "Aucun devis disponible", 28, Charte.IVOIRE, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_titre(tuile, 18, 92, U.amount(item[2]), 44, Charte.IVOIRE, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(tuile, 18, 126, item[1], 16, Charte.IVOIRE_2, tuile_w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var levers: Variant = finance.get("levers")
	var suite := 280.0
	if levers is Dictionary:
		suite = _levers(decisions, levers, largeur, suite)
	else:
		_texte(decisions, 25, suite, "Les montants reprennent les engagements du club.", 20, Charte.IVOIRE_2, largeur - 50)
		_texte(decisions, 25, suite + 34, "Les devis et conditions de signature sont détaillés dans les décisions du club.", 19, Charte.IVOIRE_2, largeur - 50)
		suite += 40.0
	_bouton(decisions, Rect2(25, suite + 10, 440, 46), "OUVRIR LES DÉCISIONS FINANCIÈRES", func(): _strategy(app), "ivoire", "arrow", "FinanceBudgetDecisions")
	if finance.get("budget") is Dictionary: _season_budget(decisions, finance.budget, largeur, suite + 100.0)
	var bas := y0 + 616.0
	_allocation(_panneau(canvas, Rect2(x, bas, 800, BAS - bas), "Répartition des charges connues", "FinanceAllocation", "par semaine"), app, finance, 800)
	_due(_panneau(canvas, Rect2(x + 816, bas, largeur - 816, BAS - bas), "Prochaines échéances", "FinanceDue"), app, finance, largeur - 816)
