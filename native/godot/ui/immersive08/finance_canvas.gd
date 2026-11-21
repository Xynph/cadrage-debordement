extends RefCounted
## Finances (direction artistique, variante 1 « Verdict en tête, quatre blocs », revue du 19/11/2026).
## Synthèse : verdict en mots, trésorerie, budget de transferts (alloué / engagé / restant), marge, puis vigilances,
## échéances, répartition et « Solde sur 12 mois » (trésorerie semaine par semaine). Les autres onglets gardent une colonne de verdict fixe à gauche.
## Tout montant, ligne ou nom ouvre l'écran qui l'explique ; une semaine du solde ouvre une petite fenêtre visuelle ; aucun or (réservé à Continuer).
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
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
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

## Solde sur 12 mois : trésorerie relevée chaque semaine (finance.cashHistory), les semaines disponibles étirées sur
## toute la largeur (52 au plus), la plus récente à droite.
## Haut : courbe du solde ; bas : barre de variation de la semaine (gain vert vers le haut, perte rouge vers le bas).
class SoldePlot extends Control:
	var semaines: Array = []
	var minimum := 0.0
	var maximum := 1.0
	var pas := 1.0
	var variation_max := 1.0
	const CASES := 52
	## Plafond de largeur d'une barre (unités du gabarit) : pas de barre énorme avec deux ou trois semaines.
	const BARRE_MAX := 34.0
	const PART_COURBE := .66

	func set_semaines(liste: Array) -> void:
		semaines = liste.duplicate()
		var bas := INF
		var haut := -INF
		variation_max = 1.0
		for semaine: Dictionary in semaines:
			bas = minf(bas, float(semaine.cash))
			haut = maxf(haut, float(semaine.cash))
			if semaine.get("variation") != null: variation_max = maxf(variation_max, absf(float(semaine.variation)))
		if semaines.is_empty():
			bas = 0.0
			haut = 1.0
		if bas < 0.0: haut = maxf(haut, 0.0)
		if haut - bas < 1.0:
			bas -= maxf(1000.0, absf(bas) * .1)
			haut += maxf(1000.0, absf(haut) * .1)
		var brut := (haut - bas) / 4.0
		var ordre := pow(10.0, floorf(log(brut) / log(10.0)))
		var rapport := brut / ordre
		pas = (1.0 if rapport <= 1.0 else 2.0 if rapport <= 2.0 else 5.0 if rapport <= 5.0 else 10.0) * ordre
		maximum = ceilf(haut / pas - 1e-9) * pas
		minimum = floorf(bas / pas + 1e-9) * pas
		if is_equal_approx(maximum, minimum): maximum += pas
		queue_redraw()

	func graduations() -> Array:
		var valeurs := []
		for i in roundi((maximum - minimum) / pas) + 1: valeurs.append(maximum - i * pas)
		return valeurs

	func largeur_case() -> float:
		return size.x / maxi(1, semaines.size())

	## Abscisse de la semaine i (0 = la plus ancienne).
	func x_de(i: int) -> float:
		return size.x - largeur_case() * (semaines.size() - i - .5)

	func y_de(valeur: float) -> float:
		return size.y * PART_COURBE * (maximum - valeur) / (maximum - minimum)

	func milieu_barres() -> float:
		return size.y * (PART_COURBE + (1.0 - PART_COURBE) * .55)

	func _draw() -> void:
		for valeur in graduations():
			draw_line(Vector2(0, y_de(valeur)), Vector2(size.x, y_de(valeur)), Color(Charte.FILET, .7))
		draw_line(Vector2.ZERO, Vector2(0, size.y), Charte.IVOIRE_3)
		if minimum < 0.0 and maximum > 0.0:
			draw_dashed_line(Vector2(0, y_de(0)), Vector2(size.x, y_de(0)), Charte.IVOIRE_2, maxf(1, C.px(2)), maxf(4, C.px(8)))
		var milieu := milieu_barres()
		var demi := size.y * (1.0 - PART_COURBE) * .42
		draw_line(Vector2(0, milieu), Vector2(size.x, milieu), Color(Charte.IVOIRE_3, .8), 1.0)
		if semaines.is_empty(): return
		var largeur := largeur_case()
		var points := PackedVector2Array()
		for i in semaines.size():
			var x := x_de(i)
			var variation: Variant = semaines[i].get("variation")
			if variation != null and absf(float(variation)) >= 1.0:
				var h := maxf(2.0, demi * absf(float(variation)) / variation_max)
				var epaisseur := minf(largeur * .6, C.px(BARRE_MAX))
				var barre := Rect2(x - epaisseur * .5, milieu - h if float(variation) > 0.0 else milieu, epaisseur, h)
				draw_rect(barre, Pieces.VERT if float(variation) > 0.0 else Pieces.ROUGE)
			points.append(Vector2(x, y_de(float(semaines[i].cash))))
		var courant: Dictionary = semaines.back()
		if courant.get("courant", false):
			var xc := points[points.size() - 1].x
			draw_dashed_line(Vector2(xc, 0), Vector2(xc, size.y), Charte.IVOIRE_2, 1.0, maxf(4, C.px(6)))
		if points.size() > 1: draw_polyline(points, Charte.IVOIRE, maxf(2, C.px(3)), true)
		for k in points.size():
			var negatif := float(semaines[k].cash) < 0.0
			var rayon := C.px(9) if k == points.size() - 1 else C.px(5)
			draw_circle(points[k], rayon + C.px(2), Charte.PANNEAU)
			draw_circle(points[k], rayon, Pieces.ROUGE if negatif else Charte.IVOIRE)

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

# ---------------------------------------------------------------------------------------------------------------
# Pièces graphiques
# ---------------------------------------------------------------------------------------------------------------

static func _style(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, bas_seulement: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(Charte.RAYON_PETIT)
	if bord.a > 0.0 and epaisseur > 0:
		style.border_color = bord
		if bas_seulement: style.border_width_bottom = epaisseur
		else: style.set_border_width_all(epaisseur)
	return style

static func _pilule(fond: Color, contour: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := C.box(fond, contour, Charte.RAYON_PILULE, 12)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
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
	# Panneau de l'écran (rayon 6 propre aux Finances) : ombre portée de la charte, comme tout panneau.
	panel.add_theme_stylebox_override("panel", Charte.ombrer(_style(Charte.PANNEAU), Charte.RAYON_PANNEAU))
	parent.add_child(panel)
	D.place(panel, rectangle)
	if not titre.is_empty():
		var entete := _titre(panel, 20, 40, titre.to_upper(), 26, Charte.IVOIRE, rectangle.size.x - 40)
		entete.name = "CardTitle"
		if not legende.is_empty():
			var droite := _etiquette(panel, rectangle.size.x - 20, 38, legende, rectangle.size.x * .6, HORIZONTAL_ALIGNMENT_RIGHT)
			droite.name = "CardCaption"
	return panel

## Petit « i » juste après le titre d'un panneau (l'explication passe en infobulle).
static func _info_titre(panel: Panel, titre: String, bulle: String, id: String) -> void:
	Pieces.info(panel, 20.0 + Pieces.largeur_titre(titre.to_upper(), 26) + 12.0, 18, bulle, id)

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
	var texte: Color = Charte.IVOIRE if (mode in ["lien", "ivoire"] or choisi) else Charte.IVOIRE_2
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, texte)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var normal := _style(Charte.PANNEAU_3 if mode == "onglet" and choisi else Charte.IVOIRE if mode == "ivoire" else Color.TRANSPARENT, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var survol := _style(Charte.IVOIRE_2 if mode == "ivoire" else Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var inactif := _style(Charte.PANNEAU_3 if mode == "ivoire" else Color.TRANSPARENT)
	if mode in ["onglet", "ivoire"]:
		# Charte finale : pilule. Onglet actif = aplat crème ; bouton « ivoire » = pilule à contour (un seul aplat doré : Continuer).
		var plein := mode == "onglet" and choisi
		normal = _pilule(Charte.IVOIRE if plein else Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		survol = _pilule(Charte.IVOIRE if plein else Charte.PANNEAU_2, Charte.IVOIRE_3 if mode == "ivoire" else Color.TRANSPARENT)
		inactif = _pilule(Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			bouton.add_theme_color_override(etat, Charte.PANNEAU if plein else (Charte.IVOIRE_2 if mode == "onglet" and etat == "font_color" else Charte.IVOIRE))
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
		bouton.icon = C.icon_texture(icone, Charte.PANNEAU if mode == "onglet" and choisi else Charte.IVOIRE)
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
	var panel := _panneau(canvas, rectangle, "Verdict" if compact else "Verdict de la semaine", "FinanceVerdict")
	if tab != "budget":
		var ouvrir := _zone(panel, Rect2(0, 0, largeur, rectangle.size.y), func(): _ouvrir_onglet(app, "budget"), "FinanceVerdictLink", "Voir le budget et ajuster les engagements")
		_lier(app, ouvrir, _onglet_cible("budget"), "Ouvrir · Budget")
		panel.move_child(ouvrir, 0)
		# La zone couvre le panneau mais reste sous les libellés (ils laissent passer la souris).
	var palier: int = v.palier
	var mot := _titre(panel, 64, 100, str(v.mot).to_upper(), 42, Charte.IVOIRE, largeur - 318)
	mot.name = "FinanceVerdictWord"
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_symbole(panel, Rect2(20, 68, 34, 34), _forme_palier(palier) if palier >= 0 else "exclam", [Pieces.VERT, Pieces.ORANGE, Pieces.ROUGE][palier] if palier >= 0 else Charte.IVOIRE)
	var palier_texte := "palier %d sur 3" % (palier + 1) if palier >= 0 else "chiffres indisponibles"
	_etiquette(panel, largeur - 20, 96, palier_texte, 200, HORIZONTAL_ALIGNMENT_RIGHT)
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
		_bloc(panel, Rect2(x, 120 + decalage, largeur_colonne, 10), teinte if actif else Charte.PANNEAU_3)
		_symbole(panel, Rect2(x, 142 + decalage, 20, 20), _forme_palier(i), teinte if actif else Charte.IVOIRE_2)
		D.text(panel, x + 28, 159 + decalage, str(PALIERS[i][0]), 20, Charte.IVOIRE if actif else Charte.IVOIRE_2, 700, largeur_colonne - 64).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pieces.info(panel, x + largeur_colonne - 28, 139 + decalage, "%s : %s" % [PALIERS[i][0], PALIERS[i][1]], "Palier%d" % i)
	# Deux pastilles sous les paliers : marge de la semaine (→ Budget) et autonomie de trésorerie (→ Trésorerie).
	if v.margin != null:
		var marge := float(v.margin)
		var texte_marge := ("▲ +" if marge > 0.0 else "▼ " if marge < 0.0 else "") + U.amount(marge) + " / sem."
		var largeur_marge := Pieces.pastille(panel, 20, 180 + decalage, texte_marge, "", "FinanceVerdictMargin", "", Pieces.ROUGE if marge < 0.0 else Pieces.VERT, Charte.PANNEAU_3, func(): _vers(app, "budget"))
		var texte_autonomie := "tient la saison" if v.autonomie == null else "tient " + P.plural(int(v.autonomie), "semaine", "semaines")
		var teinte_autonomie: Color = [Pieces.VERT, Pieces.ORANGE, Pieces.ROUGE][palier] if palier >= 0 else Charte.IVOIRE
		Pieces.pastille(panel, 20 + largeur_marge + 10, 180 + decalage, texte_autonomie, "clock", "FinanceVerdictAutonomy", "", teinte_autonomie, Charte.PANNEAU_3, func(): _vers(app, "cash"))
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

## Détail de la prévision (trésorerie + marge courante + autres apports = prévision), en infobulle de la carte.
static func _projection_reading(finance: Dictionary) -> String:
	var detail: Variant = finance.get("projection")
	if not (detail is Dictionary) or not finance.has("budget"): return "Hors billetterie aléatoire, primes et transferts futurs"
	if absf(float(detail.otherInflows)) < 1.0: return "Trésorerie + marge courante sur %d semaines" % int(detail.remainingWeeks)
	return "Trésorerie %s · marge courante %s · guichet, primes et soutien %s" % [U.amount(detail.cash), U.amount(detail.marginTotal), ("+" if float(detail.otherInflows) > 0.0 else "") + U.amount(detail.otherInflows)]

static func _carte_tresorerie(app: Control, canvas: Control, rectangle: Rect2, accounts: Dictionary, finance: Dictionary, v: Dictionary) -> void:
	# Sur l'onglet Trésorerie, le bloc mène au budget qui explique la prévision de fin de saison.
	var ici := _onglet_courant(app) == "cash"
	var haute := rectangle.size.y >= 200.0
	var lecture := _projection_reading(finance)
	var bulle := "Trésorerie du club : prévision de fin de saison, dans l'onglet Budget." if ici else "Trésorerie du club : tous les mouvements et le solde, dans l'onglet Trésorerie."
	var carte := _carte(app, canvas, rectangle, "FinanceMetric0", _onglet_cible("budget" if ici else "cash"), "Ouvrir · Budget" if ici else "Ouvrir · Trésorerie", bulle + "
" + lecture)
	# Carte haute (Synthèse) : titre et montant en haut, deux tuiles dessous (fin de saison prévue, guichet et soutien).
	var decalage := maxf(0.0, (rectangle.size.y - 200.0) * .5 - 10.0) if haute else maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var cash: Variant = v.cash
	_titre(carte, 20, 36 + decalage, "TRÉSORERIE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var montant := _titre(carte, 20, 92 + decalage, U.amount(cash), 52, Charte.D if cash != null and float(cash) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40)
	montant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prevue: Variant = v.forecast
	var detail: Variant = finance.get("projection")
	var tuiles: Array = [[U.amount(prevue) if prevue != null else "—", "fin de saison", Pieces.ROUGE if prevue != null and float(prevue) < 0.0 else Pieces.VERT, "FinanceProjectionEnd"]]
	if detail is Dictionary and finance.has("budget"):
		if absf(float(detail.otherInflows)) >= 1.0: tuiles.append([("+" if float(detail.otherInflows) > 0.0 else "") + U.amount(detail.otherInflows), "guichet · soutien", Pieces.VERT if float(detail.otherInflows) > 0.0 else Pieces.ROUGE, "FinanceProjectionBox"])
		else: tuiles.append([U.amount(detail.marginTotal), "marge · %d sem." % int(detail.remainingWeeks), Pieces.VERT if float(detail.marginTotal) >= 0.0 else Pieces.ROUGE, "FinanceProjectionMargin"])
	if haute:
		var largeur_tuile := (rectangle.size.x - 40.0 - 8.0 * (tuiles.size() - 1)) / tuiles.size()
		for k in tuiles.size(): Pieces.tuile(carte, Rect2(20 + k * (largeur_tuile + 8), 138 + decalage, largeur_tuile, 68), tuiles[k][0], tuiles[k][1], tuiles[k][2], tuiles[k][3], 30, "", "", false, func(): _vers(app, "budget"))
	else:
		# Carte basse (autres onglets) : une seule tuile, à droite du montant.
		Pieces.tuile(carte, Rect2(rectangle.size.x - 20 - 150, 22 + decalage * .5, 150, 62), tuiles[0][0], tuiles[0][1], tuiles[0][2], tuiles[0][3], 26, "", "", false, func(): _vers(app, "budget"))

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
	if not limite and depenses.is_empty():
		# Rien d'engagé : une pastille plutôt qu'une phrase.
		Pieces.pastille(carte, 20, 142 + decalage, "0 € engagé", "check", "FinanceNothingCommitted", "", Pieces.VERT, Charte.PANNEAU_3, func(): _vers(app, "transfers"))
	else:
		var note := "Limité par la caisse du club" if limite else depenses
		_texte(carte, 20, 160 + decalage, note, 16, Charte.IVOIRE_2, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _carte_marge(app: Control, canvas: Control, rectangle: Rect2, finance: Dictionary, v: Dictionary) -> void:
	var ici := _onglet_courant(app) == "budget"
	var carte := _carte(app, canvas, rectangle, "FinanceMetric2", _onglet_cible("cash" if ici else "budget"), "Ouvrir · Trésorerie" if ici else "Ouvrir · Budget", "Recettes régulières moins charges de la semaine. Ne comprend pas les recettes de match, la prime de classement ni le soutien du propriétaire : voir la trésorerie prévue en fin de saison.")
	var decalage := maxf(0.0, (rectangle.size.y - 120.0) * .5 - 10.0)
	var marge: Variant = v.margin
	_titre(carte, 20, 36 + decalage, "MARGE COURANTE", 22, Charte.IVOIRE_2, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := "—"
	if marge != null: texte = ("+" if float(marge) > 0.0 else "") + U.amount(marge)
	_titre(carte, 20, 92 + decalage, texte + (" / sem." if marge != null else ""), 52 if rectangle.size.y >= 200.0 else 42, Charte.D if marge != null and float(marge) < 0.0 else Charte.IVOIRE, rectangle.size.x - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var recettes: Variant = finance.get("weeklyIncome")
	var charges: Variant = finance.get("weeklyCosts")
	var valeurs := [["▲ " + U.amount(recettes), "recettes", "FinanceMarginIncome", Pieces.VERT], ["▼ " + U.amount(charges), "charges", "FinanceMarginCosts", Pieces.ROUGE]]
	if rectangle.size.y >= 200.0:
		# Carte haute (Synthèse) : recettes et charges en deux tuiles sous la marge.
		var largeur_tuile := (rectangle.size.x - 40.0 - 8.0) / 2.0
		for k in 2: Pieces.tuile(carte, Rect2(20 + k * (largeur_tuile + 8), 138 + decalage, largeur_tuile, 68), valeurs[k][0], valeurs[k][1], valeurs[k][3], valeurs[k][2], 26, "", "", false, func(): _vers(app, "budget"))
	else:
		# Carte basse (autres onglets) : tuiles à droite de la marge.
		for k in 2: Pieces.tuile(carte, Rect2(rectangle.size.x - 20 - 2 * 124 - 8 + k * 132, 20 + decalage * .5, 124, 62), valeurs[k][0], valeurs[k][1], valeurs[k][3], valeurs[k][2], 22, "", "", false, func(): _vers(app, "budget"))

# ---- Synthèse -----------------------------------------------------------------------------------------------

static func _synthese(app: Control, canvas: Control, accounts: Dictionary, finance: Dictionary, ledger: Array, v: Dictionary) -> void:
	_verdict_panneau(app, canvas, Rect2(0, HAUT, 880, 300), v, false, "summary")
	_carte_tresorerie(app, canvas, Rect2(896, HAUT, 400, 300), accounts, finance, v)
	_carte_budget(app, canvas, Rect2(1312, HAUT, 500, 300), accounts, ledger)
	_carte_marge(app, canvas, Rect2(1828, HAUT, 420, 300), finance, v)
	_watch(_panneau(canvas, Rect2(0, 466, 690, 380), "Vigilances", "FinanceWatch"), app, finance, 690)
	_due(_panneau(canvas, Rect2(706, 466, 840, 380), "Prochaines échéances", "FinanceDue"), app, finance, 840)
	_allocation(_panneau(canvas, Rect2(1562, 466, 686, 380), "Où va l'argent", "FinanceAllocation", "par semaine"), app, finance, 686)
	_solde(app, canvas, _panneau(canvas, Rect2(0, 862, 2248, 368), "Solde sur 12 mois", "FinanceSolde"), accounts, 2248)

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
		if lignes.size() > SoldePlot.CASES: lignes = lignes.slice(lignes.size() - SoldePlot.CASES)
		lignes.back().courant = true
	for i in lignes.size():
		lignes[i].variation = null
		if i > 0: lignes[i].variation = float(lignes[i].cash) - float(lignes[i - 1].cash)
	return lignes

static func _mois(date: String) -> String:
	return MOIS[clampi(date.substr(5, 2).to_int() - 1, 0, 11)]

static func _date_courte(date: String) -> String:
	return "%d %s %s" % [date.substr(8, 2).to_int(), _mois(date), date.substr(0, 4)]

static func _solde(app: Control, canvas: Control, card: Panel, accounts: Dictionary, largeur: float) -> void:
	var semaines := solde_semaines(app, accounts)
	var graph := SoldePlot.new()
	graph.name = "FinanceSoldePlot"
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.set_semaines(semaines)
	card.add_child(graph)
	var haut := 70.0
	var hauteur := card.size.y / maxf(C.density, .01) - 120.0
	var gauche := 150.0
	var large := largeur - 190.0
	D.place(graph, Rect2(gauche, haut, large, hauteur))
	for valeur: float in graph.graduations():
		var y := haut + hauteur * SoldePlot.PART_COURBE * (graph.maximum - valeur) / (graph.maximum - graph.minimum)
		_texte(card, 134, y + 6, "0 €" if is_zero_approx(valeur) else U.amount(valeur), 16, Charte.IVOIRE_2, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	var case_largeur := large / maxi(1, semaines.size())
	var mois_precedent := ""
	var x_mois := -INF
	for i in semaines.size():
		var semaine: Dictionary = semaines[i]
		var x := gauche + large - case_largeur * (semaines.size() - i - .5)
		var mois := _mois(str(semaine.date))
		# Un repère par nouveau mois ; son nom seulement s'il ne touche pas le précédent.
		if mois != mois_precedent:
			if x - case_largeur * .5 - x_mois >= 64.0:
				_texte(card, x - case_largeur * .5 + 4, haut + hauteur + 26, mois, 16, Charte.IVOIRE_2, 80).mouse_filter = Control.MOUSE_FILTER_IGNORE
				x_mois = x - case_largeur * .5
			D.line(card, Vector2(x - case_largeur * .5, haut + hauteur), Vector2(x - case_largeur * .5, haut + hauteur + 8), Charte.IVOIRE_3)
			mois_precedent = mois
		var rang := semaines.size() - 1 - i
		var zone := Button.new()
		zone.name = "FinanceSoldeSemaine_%d" % rang
		zone.flat = true
		zone.focus_mode = Control.FOCUS_ALL
		zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		zone.add_theme_stylebox_override("hover", _style(Color(Charte.IVOIRE, .08)))
		zone.add_theme_stylebox_override("pressed", _style(Color(Charte.IVOIRE, .12)))
		zone.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
		var variation: Variant = semaine.get("variation")
		zone.tooltip_text = "%s · %s%s" % [_date_courte(str(semaine.date)), U.amount(semaine.cash), "" if variation == null else " · %s%s" % ["+" if float(variation) > 0.0 else "", U.amount(variation)]]
		zone.accessibility_name = zone.tooltip_text
		zone.pressed.connect(func(): _fenetre_semaine(app, canvas, semaine, x))
		card.add_child(zone)
		D.place(zone, Rect2(x - case_largeur * .5, haut, case_largeur, hauteur))
	if not semaines.is_empty() and semaines.back().get("courant", false):
		var x_courant := gauche + large - case_largeur * .5
		_texte(card, x_courant - 150, haut - 8, "cette semaine", 15, Charte.IVOIRE_2, 140, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Légende : forme et mot (trait du solde, barres ▲ gain et ▼ perte).
	_bloc(card, Rect2(380, 28, 30, 5), Charte.IVOIRE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 420, 38, "Solde", 16, Charte.IVOIRE, 120)
	_bloc(card, Rect2(520, 22, 12, 18), Pieces.VERT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 540, 38, "▲ Gain", 16, Pieces.VERT, 120)
	_bloc(card, Rect2(640, 22, 12, 18), Pieces.ROUGE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 660, 38, "▼ Perte", 16, Pieces.ROUGE, 120)
	Pieces.info(card, largeur - 46, 18, "Trésorerie relevée chaque semaine · barres : variation de la semaine", "FinanceSoldeInfo")

## Petite fenêtre d'une semaine : date, solde et variation en tuiles, pastille vers la Trésorerie. Échap, ✕ ou clic à côté la ferment.
static func _fenetre_semaine(app: Control, canvas: Control, semaine: Dictionary, x: float) -> void:
	var ancienne := canvas.find_child("FinanceSoldeFenetre", false, false)
	if ancienne != null:
		ancienne.name = "FinanceSoldeFenetreFermee"
		ancienne.remove_from_group(PetiteFenetre.GROUPE)
		ancienne.queue_free()
	var calque := Control.new()
	calque.name = "FinanceSoldeFenetre"
	canvas.add_child(calque)
	D.place(calque, Rect2(0, 0, 2248, BAS))
	var fermer := func():
		if is_instance_valid(calque): calque.queue_free()
	PetiteFenetre.enregistrer(calque, fermer)
	var refermer := func(): PetiteFenetre.fermer_derniere(calque.get_tree())
	var voile := Button.new()
	voile.name = "FinanceSoldeFenetreVoile"
	voile.flat = true
	voile.focus_mode = Control.FOCUS_NONE
	voile.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	voile.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	voile.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	voile.pressed.connect(refermer)
	calque.add_child(voile)
	D.place(voile, Rect2(0, 0, 2248, BAS))
	var largeur := 460.0
	var cadre := Rect2(clampf(x - largeur * .5, 0.0, 2248.0 - largeur), 610, largeur, 232)
	var fond := D.rect(calque, cadre, Charte.PANNEAU, Charte.RAYON_PANNEAU, Charte.IVOIRE_3)
	fond.name = "FinanceSoldeFenetrePanneau"
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	_titre(fond, 22, 46, _date_courte(str(semaine.date)).to_upper(), 26, Charte.IVOIRE, largeur - 90).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var croix := Button.new()
	croix.name = "FinanceSoldeFenetreFermer"
	croix.text = "✕"
	croix.flat = true
	croix.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	croix.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	croix.add_theme_color_override("font_color", Charte.IVOIRE_2)
	croix.accessibility_name = "Fermer"
	croix.pressed.connect(refermer)
	fond.add_child(croix)
	D.place(croix, Rect2(largeur - 56, 14, 40, 40))
	var cash := float(semaine.cash)
	var variation: Variant = semaine.get("variation")
	var tuile_largeur := (largeur - 44.0 - 10.0) / 2.0
	Pieces.tuile(fond, Rect2(22, 70, tuile_largeur, 76), U.amount(cash), "solde", Pieces.ROUGE if cash < 0.0 else Charte.IVOIRE, "FinanceSoldeFenetreSolde", 30)
	var texte_variation := "—" if variation == null else ("▲ +" if float(variation) > 0.0 else "▼ " if float(variation) < 0.0 else "") + U.amount(variation)
	var couleur_variation: Color = Charte.IVOIRE_2 if variation == null else Pieces.ROUGE if float(variation) < 0.0 else Pieces.VERT
	Pieces.tuile(fond, Rect2(32 + tuile_largeur, 70, tuile_largeur, 76), texte_variation, "semaine", couleur_variation, "FinanceSoldeFenetreVariation", 30)
	var aller := func():
		PetiteFenetre.fermer_derniere(calque.get_tree())
		_ouvrir_onglet(app, "cash")
	Pieces.pastille(fond, 22, 176, "Trésorerie", "money", "FinanceSoldeFenetreTresorerie", "", Charte.IVOIRE, Charte.PANNEAU_3, aller)

static func _chart(app: Control, card: Panel, ledger: Array, largeur: float) -> void:
	var recent := ledger.slice(0,12)
	var graph := LedgerPlot.new()
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
	var trait_legende := _bloc(card, Rect2(480, 28, 30, 5), Charte.VERT_CLAIR)
	trait_legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texte(card, 520, 38, "Solde cumulé de ces mouvements", 16, Charte.IVOIRE, 440)
	_hachure_legende(card, 980, 24, true)
	_texte(card, 1008, 38, "Entrées", 16, Charte.IVOIRE, 130)
	_hachure_legende(card, 1150, 24, false)
	_texte(card, 1178, 38, "Sorties (hachurées)", 16, Charte.IVOIRE, 300)
	Pieces.info(card, largeur - 46, 18, "Du plus ancien au plus récent · un clic sur un mouvement ouvre son détail", "FinanceChartInfo")
	if recent.is_empty():
		_titre(card, largeur * .5, 190, "Le premier mouvement reste à venir", 36, Charte.IVOIRE, 900, HORIZONTAL_ALIGNMENT_CENTER)

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
		var reste := "Reste de la saison : %s sur %d sem." % [U.amount(float(item[2])*remaining) if item[2] != null else "—", remaining]
		_zone(card, Rect2(10, y - 4, largeur - 20, 66), destinations[i], "FinanceAllocationRow" + str(i), "Ouvrir · %s. %s" % [noms[i], reste])
		D.text(card, 22, y + 24, item[0], 22, Charte.IVOIRE, 600, largeur - 330).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.bar(card, Rect2(22, y + 40, largeur - 44, 9), ratio, Charte.IVOIRE_2)
		D.text(card, largeur - 22, y + 24, "%d %%" % roundi(ratio) if total > 0 else "—", 22, Charte.IVOIRE, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(card, largeur - 116, y + 24, G.euros(item[2]) if item[2] != null else "—", 19, Charte.IVOIRE_2, 500, 150, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deux mesures salariales distinctes : la charge versée (avec cotisations, comme l'écran Club) et les salaires des contrats.
	if app.model.has("figures"):
		var payroll := P.payroll(app.model)
		Pieces.tuile(card, Rect2(22, 296, 190, 66), G.salary_amount(payroll.players_weekly), "joueurs", Pieces.BLEU, "FinancePlayersPayroll", 26, "Salaires des joueurs, hors cotisations", "", false, func(): _open_wages(app, false))
	Pieces.tuile(card, Rect2(22 + (200 if app.model.has("figures") else 0), 296, 140, 66), "%d" % remaining, "semaines prévues", Pieces.TURQUOISE, "FinanceForecastWeeks", 26, "Engagements connus · prévision sur %d sem." % remaining, "", false, func(): _vers(app, "budget"))
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
		_titre(card, 23, 160, "Aucune opération enregistrée", 30, Charte.IVOIRE, largeur - 46)
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
		lignes.append({"id": "FinanceWatchContracts", "titre": "Contrats à anticiper", "detail": "%s · %s en fin de saison · horizon fin %s" % [P.plural(count, "contrat à anticiper", "contrats à anticiper"), counts.end_of_season, G.season_label(counts.horizon_season)], "lien": "Contrats", "action": func(): _open_wages(app, true), "tuiles": [[str(count), "contrats", "FinanceWatchContractsCount", Pieces.BLEU], [str(counts.end_of_season), "cette saison", "FinanceWatchContractsSeason", Pieces.ORANGE]]})
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		lignes.append({"id": "FinanceWatchFacilities", "titre": "Infrastructures", "detail": "Devis indicatif · " + G.euros(quote.cost), "lien": "Infrastructures", "action": func(): _strategy(app)})
	var budget: Variant = finance.get("budget")
	if budget is Dictionary and budget.get("plafondSalarial") != null and float(budget.plafondSalarial) > 0.0 and budget.get("masseSalariale") != null:
		var part := roundi(100.0 * float(budget.masseSalariale) / float(budget.plafondSalarial))
		if part >= 80:
			lignes.append({"id": "FinanceWatchCap", "titre": "Masse salariale · joueurs à %d %% du plafond de la ligue" % part, "detail": "marge restante : %s" % U.amount(budget.get("margePlafond")), "lien": "Budget" if _onglet_courant(app) == "wages" else "Salaires", "action": func(): _ouvrir_onglet(app, "budget") if _onglet_courant(app) == "wages" else _open_wages(app, false)})
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
		_texte(card, 62, y + 28, str(ligne.titre), 19, Charte.IVOIRE, 220 if ligne.has("tuiles") else largeur - 290).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ligne.has("tuiles"):
			# Compteurs du contrat à anticiper : deux tuiles (au total, et cette saison) au lieu d'une phrase.
			var tuiles: Array = ligne.tuiles
			for k in tuiles.size(): Pieces.tuile(card, Rect2(290 + k * 118, y + 4, 110, 62), tuiles[k][0], tuiles[k][1], tuiles[k][3], tuiles[k][2], 26, "", "", k == 1, func(): _vers_contrats(app))
		else:
			# Le détail passe sous le lien (aligné sur le titre) et prend toute la largeur : plus de troncature à 1280.
			_texte(card, 62, y + 56, str(ligne.detail), 16, Charte.IVOIRE_2, largeur - 86).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_texte(card, largeur - 24, y + 28, str(ligne.lien) + " →", 17, Charte.IVOIRE, 220, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < lignes.size() - 1: D.line(card, Vector2(20, y + 73), Vector2(largeur - 20, y + 73), Color(Charte.FILET,.7))

static func _due(card: Panel, app: Control, finance: Dictionary, largeur: float) -> void:
	var remaining := int(finance.get("remainingWeeks",0))
	var week := int(app.model.meta.get("week",0)) + 1
	_etiquette(card, largeur - 20, 38, "semaine %d" % week, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	_info_titre(card, "Prochaines échéances", "Chaque ligne se répète jusqu'à la fin de la saison · %d sem." % remaining, "FinanceDueInfo")
	if remaining <= 0:
		_texte(card, 22, 119, "Aucun paiement restant", 20, Charte.IVOIRE_2, largeur - 44)
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
	var texte_mouvements := P.plural(ledger.size(), "mouvement conservé", "mouvements conservés")
	var largeur_mouvements := Pieces.pastille(canvas, x + 4, zone.position.y + 448, texte_mouvements, "", "FinanceLedgerCount")
	Pieces.info(canvas, x + 4 + largeur_mouvements + 8, zone.position.y + 452, "Un clic sur une ligne ouvre l'écran qui l'explique · le journal ne se confond pas avec la trésorerie du club.", "FinanceLedgerInfo")
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
		var fin_saison: int = P.contract_counts(app.model).end_of_season
		var horizon_texte := "Jusqu’à la fin de %s" % G.season_label(horizon)
		var largeur_echeances := Pieces.pastille(wages, 380, 10, P.plural(squad.size(), "échéance", "échéances"), "calendar", "FinanceWagesScope", horizon_texte, Pieces.BLEU, Charte.PANNEAU_3, func(): _vers_contrats(app))
		Pieces.pastille(wages, 380 + largeur_echeances + 8, 10, "%d en fin de saison" % fin_saison, "", "FinanceWagesSeasonEnd", "", Pieces.ORANGE, Charte.PANNEAU_3, func(): _vers_contrats(app))
		_bouton(wages, Rect2(largeur - 330, 10, 310, 36), "Tous les %d joueurs" % all_players.size(), func(): _open_wages(app, false), "lien", "arrow", "FinanceWagesAll")
	else:
		var texte_joueurs := P.plural(squad.size(), "joueur", "joueurs")
		Pieces.pastille(wages, largeur - 20 - Pieces.largeur_pastille(texte_joueurs, "people"), 10, texte_joueurs, "people", "FinanceWagesCount", "", Pieces.BLEU, Charte.PANNEAU_3, func(): app._navigate("Effectif"))
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
	_bouton(card, Rect2(23, 196, largeur - 46, 50), "OUVRIR LE RECRUTEMENT", func(): app._navigate("Recrutement"), "ivoire", "arrow", "FinanceRecruitment")
	D.line(card, Vector2(23, 280), Vector2(largeur - 23, 280), Charte.FILET)
	_titre(card, 23, 336, "Contrats du groupe", 34, Charte.IVOIRE, largeur - 46)
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
	_info_titre(panel, "Santé financière des clubs · %s" % P.league_name(app.model), "Du plus solide au plus fragile, d’après la trésorerie de chaque club rapportée à la réserve qu’il se fixe.", "FinanceClubsInfo")
	var head := [["#",25,60],["Club",95,440],["Santé",560,170],["Propriétaire",760,300],["Trois dernières saisons" + (" · à venir" if sans_courbe else ""),1090,480]]
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
		return y + 4.0
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
		[U.amount(envelope), libelle, Charte.IVOIRE, "FinanceSeasonBudgetOwner", comble, func(): _vers(app, "cash")],
		[U.amount(budget.get("masseSalariale")), "Masse / an", Charte.IVOIRE, "FinanceSeasonBudgetPayroll", salaires, func(): _open_wages(app, false)],
		[("+" if resultat != null and float(resultat) > 0.0 else "") + U.amount(resultat), "Résultat prévu", Pieces.VERT if resultat != null and float(resultat) >= 0.0 else (Pieces.ROUGE if resultat != null else Charte.IVOIRE), "FinanceSeasonBudgetResult", prevu, func(): _vers(app, "cash")],
	]
	if fine > 0.0:
		tuiles.append(["−" + U.amount(fine), "Amende ligue", Pieces.ROUGE, "FinanceSeasonBudgetFine", "Amende de la ligue encourue : %s" % U.amount(fine), func(): _open_wages(app, false)])
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
		x += Pieces.pastille(card, x, ligne, repere[0], repere[1], repere[2], repere[3], repere[4], Charte.PANNEAU_3, func(): _vers(app, "cash")) + 10.0

static func _budget(app: Control, canvas: Control, zone: Rect2, finance: Dictionary) -> void:
	var x := zone.position.x
	var y0 := zone.position.y
	var largeur := zone.size.x
	var decisions := _panneau(canvas, Rect2(x, y0, largeur, 600), "Engagements et investissements", "FinanceCommitments", "%d semaines restantes sur %d" % [int(finance.get("remainingWeeks",0)),int(finance.get("weeksPerSeason",0))])
	var cards := [["Formation","Investissement par séance",finance.get("academyInvestment"),func(): app._navigate("Formation"),"Formation"],["Installations","Niveau indisponible",null,func(): _strategy(app),"Infrastructures"],["Partenaires","Recettes hebdomadaires du modèle",finance.get("weeklyIncome"),func(): _ouvrir_onglet(app, "cash"),"Trésorerie"]]
	if finance.get("budget") is Dictionary and finance.budget.get("centreFormationHebdo") != null:
		cards[0][1] = "Centre de formation / sem." + (" · dont %s en plus" % U.amount(finance.get("academyInvestment")) if float(finance.get("academyInvestment", 0)) > 0.0 else "")
		cards[0][2] = formation_weekly(finance)
	if finance.get("budget") is Dictionary: cards[2] = ["Recettes régulières","Recettes / sem.",finance.get("weeklyIncome"),func(): _ouvrir_onglet(app, "cash"),"Trésorerie"]
	var facility: Variant = finance.get("facility")
	if facility is Dictionary:
		cards[1][1] = "Niveau %s / 10 · devis" % G.n(facility.level)
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
		suite += 4.0
	_bouton(decisions, Rect2(25, suite + 10, 440, 46), "OUVRIR LES DÉCISIONS FINANCIÈRES", func(): _strategy(app), "ivoire", "arrow", "FinanceBudgetDecisions")
	if finance.get("budget") is Dictionary: _season_budget(decisions, finance.budget, largeur, suite + 100.0, app)
	var bas := y0 + 616.0
	_allocation(_panneau(canvas, Rect2(x, bas, 800, BAS - bas), "Répartition des charges connues", "FinanceAllocation", "par semaine"), app, finance, 800)
	_due(_panneau(canvas, Rect2(x + 816, bas, largeur - 816, BAS - bas), "Prochaines échéances", "FinanceDue"), app, finance, largeur - 816)
