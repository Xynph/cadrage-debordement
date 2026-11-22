extends Control
## Survol de ligne commun à toutes les listes du jeu (Effectif, Contrats, Recrutement, Classements, Calendrier,
## Formation, Réception) : la ligne sous la souris se démarque par une bande plus claire et un liseré gauche de 4 px à
## la couleur du club (éclaircie sur fond sombre). Choix de Léo du 21/11 (option A de la planche).
##
## Décision de Léo : jamais de vert de sélection dans les listes. La ligne « choisie » (joueur courant, message lu…)
## garde son rôle (navigation clavier, retour de fiche, défilement) mais n'est plus colorée : seul le survol fait
## ressortir une ligne. Le focus clavier garde un contour crème discret (accessibilité).
##
## Deux usages, un seul dessin (`dessiner`) :
##  - ligne en Button (Effectif, Recrutement, Classements, Calendrier, Formation, Réception) :
##    `SurvolLigne.appliquer(ligne, …)` pose ce nœud en premier enfant (derrière les textes) et prend la main sur les
##    états normal/survol du bouton ;
##  - lignes dessinées (ui/socle/tableau.gd : Effectif, Contrats) : `SurvolLigne.dessiner(zone, rect, …)` dans le _draw.
## Le survol ne touche qu'au FOND de la ligne : les noms de joueurs (lien, mini-fiche) gardent leur propre survol.

const Charte = preload("res://ui/charte.gd")
const GROUPE := "survol_ligne"
const NOM := "SurvolLigne"
## Bande de survol : crème translucide (plus claire que le fond, quelle que soit la couleur de la ligne).
const BANDE := Color(0.96, 0.93, 0.86, 0.17)
const LISERE := 4.0
## Rayure d'une ligne sur deux (rang 1, 3, 5… dans l'ordre affiché) : crème très translucide, lisible sur la photo de
## fond assombrie comme sur un panneau. Nettement plus discrète que la bande de survol (0,17) : une rayure ne se
## confond jamais avec la ligne survolée. Choix de Léo du 21/11 (référence : liste de joueurs d'un autre jeu).
const RAYURE := Color(0.96, 0.93, 0.86, 0.065)
## Captures seulement : rang de ligne à montrer survolé dans les tableaux dessinés (-1 : jamais).
static var simulation_rang := -1

var ligne: Control
var choisi := false
var survole := false
## Ligne enfoncée (bouton tenu) : bande plus claire et filet sombre en haut, comme l'appui d'une tuile. Jamais d'ombre.
var appuye := false
var accent := Charte.IVOIRE
var rayon := float(Charte.RAYON_PETIT)
## Décalage du liseré en pixels (Classements : laisse la bande de zone des places 1 à 6 visible à sa gauche).
var decalage := 0.0

## Couleur du club rendue lisible sur le fond sombre (un bleu nuit ou un bordeaux deviendraient invisibles) : même
## règle que le retour commun des tuiles (ui/retour_tuile.gd).
static func accent_lisible(couleur: Color) -> Color:
	return load("res://ui/retour_tuile.gd").accent_lisible(couleur)

static func echelle(noeud: CanvasItem) -> float:
	var vue := noeud.get_viewport_rect().size if noeud.is_inside_tree() else Vector2(1920, 1080)
	return clampf(minf(vue.y / 1080.0, vue.x / 1920.0), 0.8, 1.6)

static func _boite(fond: Color, r: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(int(r))
	style.anti_aliasing = true
	return style

## Rayure de fond d'une ligne de rang impair (le rang compte les lignes affichées, après tri et filtre ; les en-têtes
## de groupe ne comptent pas). Les lignes de rang pair gardent leur fond de base.
static func rayer(toile: CanvasItem, rect: Rect2, rang: int, k: float = 1.0, r: float = Charte.RAYON_PETIT) -> void:
	if rang % 2 != 1: return
	toile.draw_style_box(_boite(RAYURE, r * k), rect)

## Fond d'une ligne survolée. `rect` : la ligne dans le repère de `toile` ; `k` : échelle (1 en 1920×1080) ;
## `decal` : décalage du liseré en pixels. Rien n'est dessiné hors survol (pas de couleur de sélection).
static func dessiner(toile: CanvasItem, rect: Rect2, survol: bool, couleur_club: Color, k: float = 1.0, r: float = Charte.RAYON_PETIT, decal: float = 0.0) -> void:
	if not survol: return
	toile.draw_style_box(_boite(BANDE, r * k), rect)
	var epaisseur := roundf(LISERE * k)
	var lisere := _boite(accent_lisible(couleur_club), minf(r * k, epaisseur / 2.0))
	toile.draw_style_box(lisere, Rect2(rect.position + Vector2(decal, 0), Vector2(epaisseur, rect.size.y)))

## Contour du focus clavier : crème discret, sans fond (la ligne focalisée n'est pas colorée).
static func style_focus(r: float = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var focus := _boite(Color.TRANSPARENT, r)
	focus.border_color = Color(Charte.IVOIRE, 0.55)
	focus.set_border_width_all(2)
	focus.draw_center = false
	return focus

## Ligne en Button : prend la main sur son fond (normal = `fond`, pas de survol propre au bouton), curseur main,
## contour crème discret au focus clavier. Rappelable sans reconstruire la ligne. `est_choisie` est mémorisé (lecture
## par les suites) mais n'est jamais dessiné.
static func appliquer(bouton: Button, est_choisie: bool = false, fond: Color = Color.TRANSPARENT, couleur_club: Color = Charte.IVOIRE, r: float = Charte.RAYON_PETIT, decal: float = 0.0) -> Control:
	var plat := _boite(fond, r)
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, plat)
	bouton.add_theme_stylebox_override("focus", style_focus(r))
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
		bouton.button_down.connect(fond_ligne._appui.bind(true))
		bouton.button_up.connect(fond_ligne._appui.bind(false))
	fond_ligne.choisi = est_choisie
	fond_ligne.accent = couleur_club
	fond_ligne.rayon = r
	fond_ligne.decalage = decal
	fond_ligne.queue_redraw()
	return fond_ligne

func _appui(valeur: bool) -> void:
	appuye = valeur
	queue_redraw()

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
	queue_redraw()

func _ready() -> void:
	set_process(false)

## Rang de la ligne parmi les lignes visibles de sa liste (frères portant ce composant : les en-têtes de groupe et
## autres nœuds n'en font pas partie).
func rang() -> int:
	if ligne == null or ligne.get_parent() == null: return 0
	var n := 0
	for frere in ligne.get_parent().get_children():
		if frere == ligne: return n
		if frere is Control and frere.visible and frere.has_node(NOM): n += 1
	return n

func _draw() -> void:
	rayer(self, Rect2(Vector2.ZERO, size), rang(), echelle(self), rayon)
	dessiner(self, Rect2(Vector2.ZERO, size), survole or appuye, accent, echelle(self), rayon, decalage)
	if appuye:
		var k := echelle(self)
		draw_style_box(_boite(Color(Charte.IVOIRE, 0.08), rayon * k), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(rayon * k, 0, maxf(0.0, size.x - rayon * k * 2.0), maxf(2.0, roundf(2.0 * k))), Color(0, 0, 0, 0.4))

## Captures du retour commun : la 6e ligne visible de chaque liste est montrée enfoncée (bouton tenu).
static func simuler_appui(arbre: SceneTree) -> int:
	var listes := {}
	var vue := arbre.root.get_visible_rect()
	for fond_ligne in arbre.get_nodes_in_group(GROUPE):
		if not (fond_ligne is Control) or not fond_ligne.is_visible_in_tree() or fond_ligne.ligne == null: continue
		if not vue.encloses(fond_ligne.ligne.get_global_rect()): continue
		var cle = fond_ligne.ligne.get_parent().get_instance_id()
		if not listes.has(cle): listes[cle] = []
		listes[cle].append(fond_ligne)
	var touchees := 0
	for cle in listes:
		var liste: Array = listes[cle]
		if liste.size() < 7: continue
		liste.sort_custom(func(a, b): return a.ligne.global_position.y < b.ligne.global_position.y)
		liste[5]._appui(true)
		touchees += 1
	return touchees

## Captures et suites : simule le survol d'une ligne visible (la 3e) dans chaque liste. Renvoie le nombre de listes
## touchées.
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
		liste[2]._marquer(true)
		touchees += 1
	simulation_rang = 2
	for tableau in arbre.get_nodes_in_group("survol_tableau"):
		if (tableau as Control).is_visible_in_tree() and tableau.has_method("simuler_survol"):
			tableau.simuler_survol(2)
			touchees += 1
	return touchees
