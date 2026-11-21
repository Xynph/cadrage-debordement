extends Panel
## Bandeau des filtres commun à toutes les listes à filtres (Effectif, Contrats, Recrutement, Classements, Calendrier en
## tableau, Formation, Réception). Demande de Léo du 21/11/2026 : le bloc au-dessus de la liste (recherche, pastilles,
## menus, en-têtes de colonnes) se lit comme un bandeau d'une autre couleur que les lignes de joueurs, bien détouré.
##
## Dessin : panneau teinté `Charte.BANDEAU`, contour 1 px crème 22 % (`Charte.BANDEAU_BORD`, comme les grandes tuiles du
## direct), coins de carte (`Charte.RAYON_CARTE`), ombre de la charte. Facultatif : la bande des en-têtes de colonnes au
## bas du bandeau (`Charte.BANDEAU_ENTETE`, même famille, plus sombre), séparée du reste par un filet.
##
## Usage : `Bandeau.poser(parent, zone, hauteur_entete)` le pose DERRIÈRE les commandes déjà présentes dans `parent`
## (premier enfant), en unités du gabarit (zone × C.density) ; `bandeau.suivre(tableau)` le garde aligné sur la largeur
## réelle du tableau (colonne de panneaux ouverte à gauche, fenêtre redimensionnée…). Les commandes posées dessus gardent
## leur place ; l'écran les décale de `MARGE` pour les marges intérieures.

const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const NOM := "BandeauFiltres"
## Marge intérieure (unités du gabarit) entre le contour et les commandes.
const MARGE := 16.0
## Écart (unités du gabarit) entre le bas du bandeau et la première ligne de la liste.
const ECART_LIGNES := 8.0

## Hauteur de la bande des en-têtes, en pixels (0 : pas de bande).
var hauteur_entete := 0.0
var _bande: Panel
var _filet: ColorRect
var _cible: Control

## Pose le bandeau dans `parent`, derrière tous ses enfants. `zone` et `entete` en unités du gabarit.
static func poser(parent: Control, zone: Rect2, entete := 0.0, nom := NOM) -> Panel:
	var bandeau: Panel = load("res://ui/bandeau_filtres.gd").new()
	bandeau.name = nom
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_theme_stylebox_override("panel", style())
	bandeau.hauteur_entete = entete * C.density
	parent.add_child(bandeau)
	parent.move_child(bandeau, 0)
	bandeau.position = zone.position * C.density
	bandeau.size = zone.size * C.density
	bandeau._mettre_entete()
	return bandeau

## Style du bandeau (aussi pour un conteneur : PanelContainer des Contrats).
static func style(marge := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Charte.BANDEAU
	s.border_color = Charte.BANDEAU_BORD
	s.set_border_width_all(1)
	s.set_corner_radius_all(maxi(3, C.px(Charte.RAYON_CARTE)))
	s.anti_aliasing = true
	s.set_content_margin_all(C.px(marge))
	return Charte.ombrer(s, Charte.RAYON_CARTE)

## En-têtes de colonnes dans le panneau du tableau (Recrutement, Formation, Contrats) : bande de la même famille que le
## bandeau (fond `BANDEAU_ENTETE`, contour crème 22 %), coins du haut arrondis comme le panneau qui la porte.
static func style_entete(rayon_haut: int = Charte.RAYON_PANNEAU) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Charte.BANDEAU_ENTETE
	s.border_color = Charte.BANDEAU_BORD
	s.set_border_width_all(1)
	var r := maxi(3, C.px(rayon_haut))
	s.corner_radius_top_left = r
	s.corner_radius_top_right = r
	s.anti_aliasing = true
	return s

## Peint `bande` (Panel déjà posé) en bande d'en-têtes.
static func peindre_entete(bande: Panel, rayon_haut: int = Charte.RAYON_PANNEAU) -> void:
	bande.add_theme_stylebox_override("panel", style_entete(rayon_haut))

## Garde le bandeau aligné sur `cible` (même abscisse, même largeur) quand elle bouge ou change de taille (colonne de
## panneaux de l'Effectif, fenêtre redimensionnée…) : toujours UN SEUL bloc, recherche comprise.
func suivre(cible: Control) -> void:
	_cible = cible
	if cible == null: return
	cible.item_rect_changed.connect(_aligner)
	cible.visibility_changed.connect(_aligner)
	_aligner()

func _aligner() -> void:
	if not is_instance_valid(_cible) or get_parent() == null: return
	var parent := get_parent() as Control
	var x := _cible.global_position.x - (parent.global_position.x if parent != null else 0.0)
	if parent != null and parent.get_global_transform().get_scale().x != 0.0:
		x /= parent.get_global_transform().get_scale().x
	position = Vector2(x, position.y)
	size = Vector2(_cible.size.x * _cible.scale.x, size.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _mettre_entete()

func _mettre_entete() -> void:
	if hauteur_entete <= 0.0:
		if _bande != null: _bande.visible = false
		return
	if _bande == null:
		_bande = Panel.new()
		_bande.name = "BandeauEntete"
		_bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = Charte.BANDEAU_ENTETE
		var r := maxi(2, C.px(Charte.RAYON_CARTE) - 1)
		s.corner_radius_bottom_left = r
		s.corner_radius_bottom_right = r
		s.anti_aliasing = true
		_bande.add_theme_stylebox_override("panel", s)
		add_child(_bande)
		_filet = ColorRect.new()
		_filet.name = "BandeauFilet"
		_filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_filet.color = Charte.BANDEAU_BORD
		add_child(_filet)
	_bande.visible = true
	_bande.position = Vector2(1, size.y - hauteur_entete)
	_bande.size = Vector2(maxf(0.0, size.x - 2), hauteur_entete - 1)
	_filet.position = Vector2(1, size.y - hauteur_entete)
	_filet.size = Vector2(maxf(0.0, size.x - 2), 1)
