extends Control
## Survol de ligne commun à toutes les listes du jeu (Effectif, Contrats, Recrutement, Classements, Calendrier,
## Formation, Réception) : la ligne sous la souris se démarque, la ligne choisie se démarque davantage.
##
## Deux formes, à départager par Léo sur planche (CD_VARIANTE_VISUELLE=A|B, A par défaut) :
##  A « bande »  : bande plus claire sur toute la ligne + lisere gauche 4 px à la couleur du club ;
##                 ligne choisie : aplat SELECTION + lisere 6 px.
##  B « relief » : la ligne se soulève en carte (rayon 12, ombre, éclaircie, débord de 6 px), pilule à la couleur du
##                 club ; ligne choisie : carte SELECTION posée à plat, contour crème et pilule.
##
## Deux usages, un seul dessin (`dessiner`) :
##  - ligne en Button (Recrutement, Classements, Calendrier, Formation, Réception) : `SurvolLigne.appliquer(ligne, …)`
##    pose ce nœud en premier enfant (derrière les textes) et prend la main sur les états normal/survol du bouton ;
##  - lignes dessinées (ui/socle/tableau.gd : Effectif, Contrats) : `SurvolLigne.dessiner(zone, rect, …)` dans le _draw.
## Le survol ne touche qu'au FOND de la ligne : les noms de joueurs (lien, mini-fiche) gardent leur propre survol.

const Charte = preload("res://ui/charte.gd")
const GROUPE := "survol_ligne"
const NOM := "SurvolLigne"
## Captures seulement : rang de ligne à montrer survolé dans les tableaux dessinés (-1 : jamais).
static var simulation_rang := -1

var ligne: Control
var choisi := false
var survole := false
var accent := Charte.IVOIRE
var rayon := float(Charte.RAYON_PETIT)

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

## Couleur du club rendue lisible sur le fond sombre (un bleu nuit ou un bordeaux deviendraient invisibles).
static func accent_lisible(couleur: Color) -> Color:
	if couleur.a <= 0.0: return Charte.IVOIRE
	# Même teinte, plus lumineuse : la couleur du club reste reconnaissable (jamais délavée vers le blanc).
	if couleur.s < 0.12: return Charte.IVOIRE
	return Color.from_hsv(couleur.h, clampf(couleur.s, 0.55, 0.85), maxf(couleur.v, 0.88))

static func echelle(noeud: CanvasItem) -> float:
	var vue := noeud.get_viewport_rect().size if noeud.is_inside_tree() else Vector2(1920, 1080)
	return clampf(minf(vue.y / 1080.0, vue.x / 1920.0), 0.8, 1.6)

static func _boite(fond: Color, r: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(int(r))
	style.anti_aliasing = true
	return style

## Fond d'une ligne. `rect` : la ligne dans le repère de `toile` ; `k` : échelle (1 en 1920×1080).
static func dessiner(toile: CanvasItem, rect: Rect2, survol: bool, est_choisie: bool, couleur_club: Color, k: float = 1.0, r: float = Charte.RAYON_PETIT) -> void:
	if not survol and not est_choisie: return
	var club := accent_lisible(couleur_club)
	if variante() == "B":
		_dessiner_relief(toile, rect, survol, est_choisie, club, k)
	else:
		_dessiner_bande(toile, rect, survol, est_choisie, club, k, r)

static func _dessiner_bande(toile: CanvasItem, rect: Rect2, survol: bool, est_choisie: bool, club: Color, k: float, r: float) -> void:
	var fond := Charte.SELECTION.lightened(0.07) if est_choisie and survol else Charte.SELECTION if est_choisie else Color(Charte.IVOIRE, 0.17)
	toile.draw_style_box(_boite(fond, r * k), rect)
	var epaisseur := roundf((6.0 if est_choisie else 4.0) * k)
	var lisere := _boite(club, minf(r * k, epaisseur / 2.0))
	toile.draw_style_box(lisere, Rect2(rect.position, Vector2(epaisseur, rect.size.y)))

static func _dessiner_relief(toile: CanvasItem, rect: Rect2, survol: bool, est_choisie: bool, club: Color, k: float) -> void:
	var r := float(Charte.RAYON_CARTE) * k
	var carte: StyleBoxFlat
	if est_choisie:
		# Choisie : posée à plat (pas d'ombre), aplat SELECTION, contour crème 2 px : la plus marquée.
		carte = _boite(Charte.SELECTION.lightened(0.05) if survol else Charte.SELECTION, r)
		carte.border_color = Color(Charte.IVOIRE, 0.85)
		carte.set_border_width_all(maxi(2, roundi(2.0 * k)))
		carte.set_expand_margin_all(roundf(2.0 * k))
		carte.expand_margin_left = roundf(6.0 * k)
		carte.expand_margin_right = roundf(6.0 * k)
	else:
		# Survolée : la ligne se soulève (éclaircie, ombre portée vers le bas, remontée de 2 px).
		carte = _boite(Charte.PANNEAU_3.lightened(0.17), r)
		carte.shadow_color = Color(0, 0, 0, 0.7)
		carte.shadow_size = roundi(10.0 * k)
		carte.shadow_offset = Vector2(0, roundf(5.0 * k))
		carte.expand_margin_top = roundf(4.0 * k)
		carte.expand_margin_bottom = roundf(2.0 * k)
		carte.expand_margin_left = roundf(8.0 * k)
		carte.expand_margin_right = roundf(8.0 * k)
	toile.draw_style_box(carte, rect)
	var haut := rect.size.y * 0.22
	var pilule := _boite(club, 999)
	toile.draw_style_box(pilule, Rect2(rect.position.x + roundf(4.0 * k), rect.position.y + haut, roundf(6.0 * k), rect.size.y - 2.0 * haut))

## Ligne en Button : prend la main sur son fond (normal = `fond`, pas de survol propre au bouton), curseur main,
## anneau crème au focus clavier. Rappelable pour changer `choisi` sans reconstruire la ligne.
static func appliquer(bouton: Button, est_choisie: bool = false, fond: Color = Color.TRANSPARENT, couleur_club: Color = Charte.IVOIRE, r: float = Charte.RAYON_PETIT) -> Control:
	var plat := _boite(fond, r)
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, plat)
	var focus := _boite(Color.TRANSPARENT, r)
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fond_ligne = bouton.get_node_or_null(NOM)
	if fond_ligne == null:
		fond_ligne = load("res://ui/survol_ligne.gd").new()
		fond_ligne.name = NOM
		fond_ligne.ligne = bouton
		fond_ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond_ligne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bouton.add_child(fond_ligne)
		bouton.move_child(fond_ligne, 0)
		fond_ligne.add_to_group(GROUPE)
		bouton.mouse_entered.connect(fond_ligne._entree)
		bouton.mouse_exited.connect(fond_ligne._sortie)
	fond_ligne.choisi = est_choisie
	fond_ligne.accent = couleur_club
	fond_ligne.rayon = r
	fond_ligne.queue_redraw()
	return fond_ligne

func _entree() -> void:
	_marquer(true)

## La souris peut passer sur un enfant (nom, étoile) sans quitter la ligne : on vérifie le rectangle à chaque image
## tant que la ligne est survolée (une seule ligne à la fois).
func _sortie() -> void:
	if ligne != null and ligne.get_global_rect().has_point(ligne.get_global_mouse_position()):
		set_process(true)
		return
	_marquer(false)

func _process(_delta: float) -> void:
	if ligne == null or not ligne.is_visible_in_tree() or not ligne.get_global_rect().has_point(ligne.get_global_mouse_position()):
		set_process(false)
		_marquer(false)

func _marquer(valeur: bool) -> void:
	if survole == valeur: return
	survole = valeur
	# B : la carte soulevée et son ombre passent au-dessus des lignes voisines.
	if ligne != null: ligne.z_index = 1 if valeur and variante() == "B" else 0
	queue_redraw()

func _ready() -> void:
	set_process(false)

func _draw() -> void:
	dessiner(self, Rect2(Vector2.ZERO, size), survole, choisi, accent, echelle(self), rayon)

## Captures : simule le survol d'une ligne visible (la 3e non choisie) et, si l'écran n'a pas de ligne choisie,
## en marque une (la 5e). Renvoie le nombre de listes touchées.
static func simuler(arbre: SceneTree) -> int:
	var touchees := 0
	var vue := arbre.root.get_visible_rect()
	var lignes: Array = []
	for noeud in arbre.get_nodes_in_group(GROUPE):
		var fond_ligne = noeud
		if not (fond_ligne is Control) or not fond_ligne.is_visible_in_tree() or fond_ligne.ligne == null: continue
		if not vue.encloses(fond_ligne.ligne.get_global_rect()): continue
		lignes.append(fond_ligne)
	# Regroupées par liste (même parent), dans l'ordre vertical.
	var listes := {}
	for fond_ligne in lignes:
		var cle = fond_ligne.ligne.get_parent().get_instance_id()
		if not listes.has(cle): listes[cle] = []
		listes[cle].append(fond_ligne)
	for cle in listes:
		var liste: Array = listes[cle]
		if liste.size() < 4: continue
		liste.sort_custom(func(a, b): return a.ligne.global_position.y < b.ligne.global_position.y)
		var a_choisie := liste.any(func(l): return l.choisi)
		if not a_choisie and liste.size() >= 6:
			liste[4].choisi = true
			liste[4].queue_redraw()
		var libres := liste.filter(func(l): return not l.choisi)
		if libres.size() >= 3:
			libres[2]._marquer(true)
			touchees += 1
	simulation_rang = 2
	for tableau in arbre.get_nodes_in_group("survol_tableau"):
		if (tableau as Control).is_visible_in_tree() and tableau.has_method("simuler_survol"):
			tableau.simuler_survol(2)
			touchees += 1
	return touchees
