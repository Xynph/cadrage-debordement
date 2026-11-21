extends RefCounted
## Jauges compactes d'un jeune (sous-page « Suivi des jeunes ») : niveau posé sur la fourchette de potentiel, mini-jauges
## chiffrées (condition, fatigue), pastilles et icône d'état du suivi. Chaque valeur est écrite : la couleur ne porte
## jamais seule un signal. Tailles en unités du gabarit (C.px), couleurs et rayons de la charte finale.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")

## Icône de l'état du suivi (statuts du moteur `youth-development.cjs`) ; le libellé reste toujours écrit à côté.
const ICONES_ETAT := {"untracked": "search", "observing": "search", "context": "info", "review": "warning", "achieved": "check"}

## Rail 0-100 : segment de la fourchette de potentiel (vert franc, surface) et niveau actuel (barème) posé dessus.
class BarreFourchette extends Control:
	var niveau: float = -1.0
	var pmin: float = -1.0
	var pmax: float = -1.0
	var epaisseur := 8

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := float(epaisseur)
		var y := (size.y - h) * 0.5
		_bande(0.0, size.x, y, h, Charte.PANNEAU_3)
		if pmin >= 0 and pmax > pmin:
			_bande(size.x * pmin / 100.0, size.x * (pmax - pmin) / 100.0, y, h, Charte.VERT_FRANC)
		if niveau >= 0:
			_bande(0.0, size.x * niveau / 100.0, y + h * 0.25, h * 0.5, Charte.couleur_attribut(niveau))
			var x := clampf(size.x * niveau / 100.0, 1.0, size.x - 1.0)
			draw_line(Vector2(x, 0), Vector2(x, size.y), Charte.IVOIRE, 2.0, true)

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

## Bloc « niveau sur la fourchette » : niveau (barème) à gauche, potentiel à droite, rail 0-100 dessous.
static func niveau_sur_fourchette(niveau: Dictionary, potentiel: Dictionary, niveau_texte: String, potentiel_texte: String, largeur_min: int = 320) -> VBoxContainer:
	var bloc := C.v(4)
	bloc.name = "YouthLevelRange"
	bloc.custom_minimum_size.x = C.px(largeur_min)
	var tete := C.h(8)
	bloc.add_child(tete)
	var gauche := C.v(0)
	gauche.add_child(legende("Niveau"))
	var n_val: Variant = niveau.get("min")
	gauche.add_child(chiffre(niveau_texte, 34, Charte.couleur_attribut(n_val) if n_val != null else Charte.IVOIRE_3))
	tete.add_child(gauche)
	var vide := Control.new(); vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tete.add_child(vide)
	var droite := C.v(0)
	var leg := legende("Potentiel estimé")
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	droite.add_child(leg)
	var p_val: Variant = potentiel.get("min")
	var pot := chiffre(potentiel_texte, 34, Charte.couleur_attribut(p_val) if p_val != null else Charte.IVOIRE_3)
	pot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	droite.add_child(pot)
	tete.add_child(droite)
	var barre := BarreFourchette.new()
	barre.epaisseur = maxi(6, C.px(10))
	barre.custom_minimum_size = Vector2(0, C.px(18))
	barre.niveau = float(n_val) if n_val != null else -1.0
	barre.pmin = float(potentiel.min) if not potentiel.is_empty() else -1.0
	barre.pmax = float(potentiel.max) if not potentiel.is_empty() else -1.0
	barre.tooltip_text = "Niveau %s posé sur la fourchette de potentiel %s (échelle 0-100)" % [niveau_texte, potentiel_texte]
	bloc.add_child(barre)
	return bloc

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
static func pastille(texte: String, couleur: Color = Charte.IVOIRE_2, icone: String = "", taille: int = 17) -> PanelContainer:
	var cadre := PanelContainer.new()
	# Voile opaque (couleur à 14 % sur la carte), comme VOILE_DORE / VOILE_VERT de la charte.
	var style := Charte.sans_ombre(C.box(Charte.PANNEAU_2.lerp(couleur, .14), Color.TRANSPARENT, Charte.RAYON_PETIT, 0))
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

## Couleur de l'état du suivi : doré « à revoir », vert clair « atteint », gris-vert sinon (toujours avec le libellé).
static func couleur_etat(statut: String) -> Color:
	if statut == "review": return Charte.DORE
	if statut == "achieved": return Charte.VERT_CLAIR
	return Charte.GRIS_VERT
