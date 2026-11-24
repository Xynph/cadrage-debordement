extends RefCounted
## Jauges compactes d'un jeune (sous-page « Suivi des jeunes ») : niveau posé sur la fourchette de potentiel, mini-jauges
## chiffrées (condition, fatigue), pastilles et icône d'état du suivi. Chaque valeur est écrite : la couleur ne porte
## jamais seule un signal. Tailles en unités du gabarit (C.px), couleurs et rayons de la charte finale.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")

## Icône de l'état du suivi (statuts du moteur `youth-development.cjs`) ; le libellé reste toujours écrit à côté.
const ICONES_ETAT := {"untracked": "search", "observing": "search", "context": "info", "review": "warning", "achieved": "check"}

## Couleurs du suivi des jeunes (choix de Léo du 21/11/2026 : plus de couleur, aucun doré) ; toujours avec un texte.
const VERT := Color("7fbf7a")    ## condition, suivi actif, repère atteint
const ORANGE := Color("e0a04a")  ## fatigue, parcours à revoir, blessure
const BLEU := Color("5b9bd5")    ## observer, suivi à démarrer, progression

## Fenêtre de la barre niveau / potentiel : 40-100 (sous 40, le niveau reste collé au bord gauche).
const FENETRE_MIN := 40.0
const FENETRE_MAX := 100.0
const GRADUATIONS := [55, 70, 85]

## Rail 40-100 : fourchette de potentiel en bande claire, niveau actuel au barème des notes posé dessus, trois
## graduations discrètes chiffrées dessous.
class BarreFourchette extends Control:
	var niveau: float = -1.0
	var pmin: float = -1.0
	var pmax: float = -1.0
	var epaisseur := 8
	var police := 12

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _x(valeur: float) -> float:
		return size.x * clampf((valeur - FENETRE_MIN) / (FENETRE_MAX - FENETRE_MIN), 0.0, 1.0)

	func _draw() -> void:
		var h := float(epaisseur)
		var y := 2.0
		_bande(0.0, size.x, y, h, Charte.PANNEAU_3)
		if pmin >= 0 and pmax > pmin:
			_bande(_x(pmin), maxf(h, _x(pmax) - _x(pmin)), y, h, Charte.PANNEAU_3.lerp(Charte.IVOIRE, .38))
		if niveau >= 0:
			_bande(0.0, maxf(h, _x(niveau)), y, h, Charte.couleur_attribut(niveau))
			var x := clampf(_x(niveau), 1.0, size.x - 1.0)
			draw_line(Vector2(x, y - 2.0), Vector2(x, y + h + 2.0), Charte.IVOIRE, 2.0, true)
		for g: int in GRADUATIONS:
			var gx := _x(g)
			# Notation façon FM (24/11) : graduations sans chiffre (le Niveau reste caché, seule la lettre est écrite).
			draw_line(Vector2(gx, y + h + 1.0), Vector2(gx, y + h + 4.0), Charte.IVOIRE_3, 1.0)

	func _bande(x: float, largeur: float, y: float, h: float, couleur: Color) -> void:
		if largeur <= 0: return
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(roundi(h * 0.5))
		style.anti_aliasing = true
		draw_style_box(style, Rect2(x, y, largeur, h))

## Fine barre pleine (rayon pilule) : rail `PANNEAU_3`, remplissage `couleur`, proportion 0-1.
class BarreFine extends Control:
	var part: float = 0.0
	var couleur := Charte.GRIS_VERT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fond := StyleBoxFlat.new()
		fond.bg_color = Charte.PANNEAU_3
		fond.set_corner_radius_all(roundi(size.y * 0.5))
		fond.anti_aliasing = true
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		if part <= 0: return
		var plein := fond.duplicate() as StyleBoxFlat
		plein.bg_color = couleur
		draw_style_box(plein, Rect2(0, 0, maxf(size.y, size.x * clampf(part, 0.0, 1.0)), size.y))

static func _marque(controle: Control) -> Control:
	controle.set_meta("style_charte", true)
	controle.set_meta("immersive_style_applied", true)
	return controle

static func legende(texte: String, taille: int = 16, couleur: Color = Charte.IVOIRE_3) -> Label:
	var etiquette := C.label(texte.to_upper(), taille, couleur, true, 700)
	etiquette.add_theme_font_override("font", Charte.TITRE_GRAS)
	_marque(etiquette)
	return etiquette

static func chiffre(texte: String, taille: int, couleur: Color) -> Label:
	var etiquette := C.label(texte, taille, couleur, true, 800)
	etiquette.add_theme_font_override("font", Charte.TITRE_GRAS)
	_marque(etiquette)
	return etiquette

## Barre de la tuile : niveau posé sur la fourchette de potentiel (fenêtre 40-100), valeurs écrites en infobulle et
## déjà en gros chiffres dans la tuile.
static func barre_niveau_potentiel(niveau: Dictionary, potentiel: Dictionary, niveau_texte: String, potentiel_texte: String) -> BarreFourchette:
	var barre := BarreFourchette.new()
	barre.name = "YouthLevelRange"
	barre.epaisseur = maxi(6, C.px(12))
	barre.police = maxi(12, C.px(15))
	barre.custom_minimum_size = Vector2(0, barre.epaisseur + barre.police + 10)
	var n_val: Variant = niveau.get("min")
	barre.niveau = float(n_val) if n_val != null else -1.0
	barre.pmin = float(potentiel.min) if not potentiel.is_empty() else -1.0
	barre.pmax = float(potentiel.max) if not potentiel.is_empty() else -1.0
	barre.tooltip_text = "Niveau %s · potentiel estimé %s" % [niveau_texte, potentiel_texte]
	return barre

## Mini-jauge chiffrée : légende, valeur écrite, fine barre (part 0-1 ; négative = pas de barre).
static func mini_jauge(nom: String, libelle: String, valeur: String, part: float, couleur: Color, couleur_valeur: Color = Charte.IVOIRE, largeur_min: int = 150) -> VBoxContainer:
	var bloc := C.v(3)
	bloc.name = nom
	bloc.custom_minimum_size.x = C.px(largeur_min)
	bloc.add_child(legende(libelle))
	bloc.add_child(chiffre(valeur, 26, couleur_valeur))
	if part >= 0:
		var barre := BarreFine.new()
		barre.part = part
		barre.couleur = couleur
		barre.custom_minimum_size = Vector2(0, maxi(4, C.px(6)))
		bloc.add_child(barre)
	return bloc

## Pastille de la charte (coins 6, voile de la couleur, texte de la couleur), avec icône facultative.
## `fond` faux : même icône et même texte, sans voile (apparence neutre d'un état qui n'ouvre rien).
static func pastille(texte: String, couleur: Color = Charte.IVOIRE_2, icone: String = "", taille: int = 17, fond: bool = true) -> PanelContainer:
	var cadre := PanelContainer.new()
	# Voile opaque (couleur à 14 % sur la carte), comme VOILE_DORE / VOILE_VERT de la charte.
	var style := Charte.sans_ombre(C.box(Charte.PANNEAU_2.lerp(couleur, .14) if fond else Color(Charte.PANNEAU_2, 0.0), Color.TRANSPARENT, Charte.RAYON_PETIT, 0))
	style.content_margin_left = C.px(10); style.content_margin_right = C.px(10)
	style.content_margin_top = C.px(3); style.content_margin_bottom = C.px(3)
	cadre.add_theme_stylebox_override("panel", style)
	_marque(cadre)
	var ligne := C.h(6)
	if not icone.is_empty(): ligne.add_child(C.icon(icone, taille, couleur))
	var etiquette := C.label(texte, taille, couleur, false, 600)
	etiquette.add_theme_font_override("font", Charte.TEXTE)
	_marque(etiquette)
	ligne.add_child(etiquette)
	cadre.add_child(ligne)
	return cadre

## Couleur de l'état du suivi : orange « à revoir », vert « atteint », bleu « observer », gris-vert sinon (avec le libellé).
static func couleur_etat(statut: String) -> Color:
	if statut == "review": return ORANGE
	if statut == "achieved": return VERT
	if statut in ["untracked", "observing"]: return BLEU
	return Charte.GRIS_VERT
