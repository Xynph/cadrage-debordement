extends RefCounted
## Finances › Synthèse : courbe « Solde sur 12 mois » et petite fenêtre d'une semaine.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const F = preload("res://ui/immersive08/finance_canvas.gd")
const Traces = preload("res://ui/immersive08/finance_traces.gd")
const Brique = preload("res://ui/immersive08/finance_briques.gd")

const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

static func _mois(date: String) -> String:
	return MOIS[clampi(date.substr(5, 2).to_int() - 1, 0, 11)]

static func _date_courte(date: String) -> String:
	return "%d %s %s" % [date.substr(8, 2).to_int(), _mois(date), date.substr(0, 4)]

static func _solde(app: Control, canvas: Control, card: Panel, accounts: Dictionary, largeur: float) -> void:
	var semaines := F.solde_semaines(app, accounts)
	var graph := Traces.SoldePlot.new()
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
		var y := haut + hauteur * Traces.SoldePlot.PART_COURBE * (graph.maximum - valeur) / (graph.maximum - graph.minimum)
		Brique._texte(card, 134, y + 6, "0 €" if is_zero_approx(valeur) else U.amount(valeur), 16, Charte.IVOIRE_2, 110, HORIZONTAL_ALIGNMENT_RIGHT)
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
				Brique._texte(card, x - case_largeur * .5 + 4, haut + hauteur + 26, mois, 16, Charte.IVOIRE_2, 80).mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		zone.add_theme_stylebox_override("hover", Brique._style(Color(Charte.IVOIRE, .08)))
		zone.add_theme_stylebox_override("pressed", Brique._style(Color(Charte.IVOIRE, .12)))
		zone.add_theme_stylebox_override("focus", Brique._style(Color.TRANSPARENT, Charte.IVOIRE, 2))
		var variation: Variant = semaine.get("variation")
		zone.tooltip_text = "%s · %s%s" % [_date_courte(str(semaine.date)), U.amount(semaine.cash), "" if variation == null else " · %s%s" % ["+" if float(variation) > 0.0 else "", U.amount(variation)]]
		zone.accessibility_name = zone.tooltip_text
		zone.pressed.connect(func(): _fenetre_semaine(app, canvas, semaine, x))
		card.add_child(zone)
		D.place(zone, Rect2(x - case_largeur * .5, haut, case_largeur, hauteur))
	if not semaines.is_empty() and semaines.back().get("courant", false):
		var x_courant := gauche + large - case_largeur * .5
		Brique._texte(card, x_courant - 150, haut - 8, "cette semaine", 15, Charte.IVOIRE_2, 140, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Légende : forme et mot (trait du solde, barres ▲ gain et ▼ perte).
	Brique._bloc(card, Rect2(380, 28, 30, 5), Charte.IVOIRE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Brique._texte(card, 420, 38, "Solde", 16, Charte.IVOIRE, 120)
	Brique._bloc(card, Rect2(520, 22, 12, 18), Pieces.VERT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Brique._texte(card, 540, 38, "▲ Gain", 16, Pieces.VERT, 120)
	Brique._bloc(card, Rect2(640, 22, 12, 18), Pieces.ROUGE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Brique._texte(card, 660, 38, "▼ Perte", 16, Pieces.ROUGE, 120)
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
	D.place(calque, Rect2(0, 0, 2248, F.BAS))
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
	D.place(voile, Rect2(0, 0, 2248, F.BAS))
	var largeur := 460.0
	var cadre := Rect2(clampf(x - largeur * .5, 0.0, 2248.0 - largeur), 610, largeur, 232)
	var fond := D.rect(calque, cadre, Charte.PANNEAU, Charte.RAYON_PANNEAU, Charte.IVOIRE_3)
	fond.name = "FinanceSoldeFenetrePanneau"
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	Brique._titre(fond, 22, 46, _date_courte(str(semaine.date)).to_upper(), 26, Charte.IVOIRE, largeur - 90).mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		F._ouvrir_onglet(app, "cash")
	Pieces.pastille(fond, 22, 176, "Trésorerie", "money", "FinanceSoldeFenetreTresorerie", "", Charte.IVOIRE, Charte.PANNEAU_3, aller)
