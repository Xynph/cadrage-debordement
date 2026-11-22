extends Control
## Retour visuel commun au survol et à l'appui de TOUTES les tuiles cliquables (idée 10 de Léo, 22/11/2026) : un seul
## endroit décide de ce que fait une tuile, une pastille, une carte ou une zone de lecture quand la souris passe dessus
## ou l'enfonce. Transition courte (80 ms), jamais de vert de sélection.
##
## Deux variantes à départager sur captures (`CD_VARIANTE_VISUELLE=A|B`, A par défaut) :
##  A · éclaircissement + liseré du club : voile crème, filet clair en haut (relief), liseré gauche de 4 px à la couleur
##      du club (même famille que le survol de ligne, ui/survol_ligne.gd) ; à l'appui, voile plus fort et filet sombre
##      en haut (la tuile s'enfonce).
##  B · soulèvement : la tuile grossit à peine et pose une ombre courte vers le bas ; à l'appui, elle redescend sous sa
##      taille et l'ombre se resserre. Jamais d'ombre sur une pilule ni sur une ligne de liste (charte) : la pilule se
##      soulève seulement, la ligne garde son survol de ligne.
##
## Usage : `RetourTuile.brancher(zone, visuel, rayon_px)` ; `zone` reçoit la souris (bouton plat posé sur la tuile, ou la
## tuile elle-même), `visuel` est la carte dessinée (soulevée en B). Pour un Button, ses états hover/pressed propres sont
## neutralisés : le retour vient d'ici seulement. Le focus clavier garde son contour crème.
## Branché par : reperes.cliquable, petites_pieces.rendre_cliquable, pastilles_club (tuiles et pastilles), lien_zone,
## et les tuiles propres du Bureau, de l'Effectif, du Club et des Classements.

const Charte = preload("res://ui/charte.gd")
const GROUPE := "retour_tuile"
const NOM := "RetourTuile"
const NOM_OMBRE := "RetourTuileOmbre"
const DUREE := 0.08
const LISERE := 4.0
## Voiles crème (A) : survol, appui.
const VOILE_A := [0.10, 0.17]
## Voiles crème (B) : discrets, le relief vient de l'ombre et du soulèvement.
const VOILE_B := [0.05, 0.10]
## Échelle de la tuile en B : survolée, enfoncée.
const ECHELLE_B := [1.025, 0.985]

var zone: Control
var visuel: Control
var rayon := 12.0
var pilule := false
var lisere := true
var survol := 0.0:
	set(valeur):
		survol = valeur
		_rafraichir()
var appui := 0.0:
	set(valeur):
		appui = valeur
		_rafraichir()
var _dedans := false
var _enfonce := false
var _tween: Tween
var _ombre: Control
var _accent := Color.TRANSPARENT

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

static func echelle(noeud: CanvasItem) -> float:
	var vue := noeud.get_viewport_rect().size if noeud.is_inside_tree() else Vector2(1920, 1080)
	return clampf(minf(vue.y / 1080.0, vue.x / 1920.0), 0.8, 1.6)

## Couleur du club rendue lisible sur fond sombre (même règle que le liseré du survol de ligne).
static func accent_lisible(couleur: Color) -> Color:
	if couleur.a <= 0.0 or couleur.s < 0.12: return Charte.IVOIRE
	return Color.from_hsv(couleur.h, clampf(couleur.s, 0.55, 0.85), maxf(couleur.v, 0.88))

## Branche le retour commun sur `zone` (idempotent). `rayon` en pixels ; `Charte.RAYON_PILULE` pour une pilule.
## `avec_lisere` : false quand la tuile porte déjà une barre de couleur à gauche (priorités du Bureau).
## `avec_ombre` : false pour une zone qui se lit comme une ligne (B : soulèvement sans ombre).
static func brancher(p_zone: Control, p_visuel: Control = null, p_rayon: float = -1.0, neutraliser: bool = true, avec_lisere: bool = true, avec_ombre: bool = true) -> Control:
	if p_zone == null: return null
	var deja := p_zone.get_node_or_null(NOM)
	if deja != null: return deja
	var cible := p_visuel if p_visuel != null else p_zone
	if neutraliser and p_zone is Button: _neutraliser(p_zone as Button)
	var retour = load("res://ui/retour_tuile.gd").new()
	retour.name = NOM
	retour.zone = p_zone
	retour.visuel = cible
	retour.rayon = p_rayon if p_rayon >= 0.0 else float(Charte.RAYON_CARTE)
	retour.pilule = retour.rayon >= Charte.RAYON_PILULE / 2.0
	retour.lisere = avec_lisere
	retour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retour.focus_mode = Control.FOCUS_NONE
	retour.set_meta("immersive_style_applied", true)
	# Dans un conteneur, le calque échappe à la mise en page et suit la zone à chaque image où il se voit.
	if p_zone is Container: retour.top_level = true
	p_zone.add_child(retour)
	if not retour.top_level: retour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retour.add_to_group(GROUPE)
	p_zone.mouse_entered.connect(retour._entree)
	p_zone.mouse_exited.connect(retour._sortie)
	if p_zone is BaseButton:
		(p_zone as BaseButton).button_down.connect(retour._bas)
		(p_zone as BaseButton).button_up.connect(retour._haut)
	else:
		p_zone.gui_input.connect(retour._entree_souris)
	p_zone.tree_exiting.connect(retour._remettre)
	if variante() == "B" and not retour.pilule and avec_ombre: retour._poser_ombre()
	return retour

## Le bouton ne dessine plus de survol ni d'appui à lui : son fond reste celui de l'état normal.
static func _neutraliser(bouton: Button) -> void:
	var normal := bouton.get_theme_stylebox("normal")
	for etat in ["hover", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, normal)

func _ready() -> void:
	set_process(false)

## Ombre courte (B) : dessinée DERRIÈRE la carte (enfant `show_behind_parent`, ou frère posé juste avant elle).
func _poser_ombre() -> void:
	_ombre = Control.new()
	_ombre.name = NOM_OMBRE
	_ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ombre.set_meta("immersive_style_applied", true)
	if visuel is Container:
		var parent := visuel.get_parent() as Control
		if parent == null or parent is Container:
			_ombre = null
			return
		parent.add_child(_ombre)
		parent.move_child(_ombre, visuel.get_index())
	else:
		_ombre.show_behind_parent = true
		visuel.add_child(_ombre)
	_ombre.draw.connect(_dessiner_ombre)

func _entree() -> void:
	_dedans = true
	_viser()

func _sortie() -> void:
	# La souris peut passer sur un enfant (nom, « i ») sans quitter la tuile : on vérifie le rectangle à chaque image.
	if is_instance_valid(zone) and zone.is_visible_in_tree() and zone.get_global_rect().has_point(zone.get_global_mouse_position()):
		set_process(true)
		return
	_dedans = false
	_enfonce = false
	_viser()

func _bas() -> void:
	_enfonce = true
	_viser()

func _haut() -> void:
	_enfonce = false
	_viser()

func _entree_souris(evenement: InputEvent) -> void:
	var clic := evenement as InputEventMouseButton
	if clic == null or clic.button_index != MOUSE_BUTTON_LEFT: return
	_enfonce = clic.pressed
	_viser()

func _process(_delta: float) -> void:
	if top_level: _suivre()
	if _dedans and not (is_instance_valid(zone) and zone.is_visible_in_tree() and zone.get_global_rect().has_point(zone.get_global_mouse_position())):
		_dedans = false
		_enfonce = false
		_viser()
	if not _dedans and survol <= 0.0 and appui <= 0.0: set_process(false)

## Anime vers l'état voulu en 80 ms.
func _viser() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	if not is_inside_tree(): return
	set_process(true)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "survol", 1.0 if _dedans or _enfonce else 0.0, DUREE)
	_tween.tween_property(self, "appui", 1.0 if _enfonce else 0.0, DUREE)

## Captures et suites : pose l'état sans animation.
func forcer(p_survol: float, p_appui: float) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_dedans = p_survol > 0.0
	_enfonce = p_appui > 0.0
	survol = p_survol
	appui = p_appui

func _remettre() -> void:
	if is_instance_valid(visuel): visuel.scale = Vector2.ONE

func _suivre() -> void:
	if not is_instance_valid(zone): return
	global_position = zone.global_position
	size = zone.size

func _rafraichir() -> void:
	if not is_inside_tree(): return
	if top_level: _suivre()
	queue_redraw()
	if variante() == "B" and is_instance_valid(visuel):
		var facteur := lerpf(1.0, ECHELLE_B[0], survol)
		facteur = lerpf(facteur, ECHELLE_B[1], appui)
		visuel.pivot_offset = visuel.size / 2.0
		visuel.scale = Vector2(facteur, facteur)
	if _ombre != null and is_instance_valid(_ombre): _ombre.queue_redraw()

func _couleur_club() -> Color:
	if _accent.a > 0.0: return _accent
	var scene := get_tree().current_scene if is_inside_tree() else null
	var couleur: Variant = scene.get("accent") if scene != null else null
	_accent = accent_lisible(couleur if couleur is Color else Charte.IVOIRE)
	return _accent

func _boite(fond: Color, r: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(int(r))
	style.anti_aliasing = true
	return style

func _draw() -> void:
	var force := maxf(survol, appui)
	if force <= 0.001: return
	var k := echelle(self)
	var rect := Rect2(Vector2.ZERO, size)
	var r := minf(rayon, minf(size.x, size.y) / 2.0)
	var voiles: Array = VOILE_A if variante() == "A" else VOILE_B
	var voile := lerpf(float(voiles[0]) * survol, float(voiles[1]), appui)
	draw_style_box(_boite(Color(Charte.IVOIRE, voile), r), rect)
	if variante() != "A": return
	# Relief : filet clair en haut quand la tuile est survolée, filet sombre quand elle est enfoncée.
	var filet := maxf(1.0, roundf(1.5 * k))
	var haut := Rect2(r * 0.6, 0, maxf(0.0, size.x - r * 1.2), filet)
	if survol > 0.0 and appui < 1.0: draw_rect(haut, Color(Charte.IVOIRE, 0.32 * survol * (1.0 - appui)))
	if appui > 0.0: draw_rect(Rect2(haut.position, Vector2(haut.size.x, filet * 1.5)), Color(0, 0, 0, 0.42 * appui))
	# Liseré du club à gauche (pas sur une pilule : le liseré y serait coupé par l'arrondi).
	if pilule or not lisere: return
	var epaisseur := roundf(LISERE * k)
	var marge := minf(r * 0.5, size.y / 4.0)
	var couleur := _couleur_club()
	draw_style_box(_boite(Color(couleur, force), epaisseur / 2.0), Rect2(0, marge, epaisseur, maxf(epaisseur, size.y - marge * 2.0)))

## Ombre courte sous la tuile soulevée (B), dans le repère de la carte.
func _dessiner_ombre() -> void:
	if _ombre == null or survol <= 0.001 or not is_instance_valid(visuel): return
	var k := echelle(_ombre)
	var style := _boite(Color(0, 0, 0, 0.0), minf(rayon, minf(visuel.size.x, visuel.size.y) / 2.0))
	style.shadow_color = Color(0, 0, 0, 0.55 * survol * (1.0 - 0.5 * appui))
	style.shadow_size = int(roundf(lerpf(7.0, 3.0, appui) * k))
	style.shadow_offset = Vector2(0, roundf(lerpf(5.0, 1.0, appui) * k))
	var origine := Vector2.ZERO if _ombre.get_parent() == visuel else visuel.position - _ombre.position
	_ombre.draw_style_box(style, Rect2(origine, visuel.size))

## Captures : met une tuile en survol et une autre en appui (noms de zone dans CD_FILM_RETOUR_TUILE_CIBLES, sinon les
## deux plus grandes tuiles entièrement visibles). Renvoie les noms des zones touchées.
static func simuler(arbre: SceneTree) -> Array:
	var vue := arbre.root.get_visible_rect()
	var voulues := PackedStringArray()
	for nom in OS.get_environment("CD_FILM_RETOUR_TUILE_CIBLES").split(",", false): voulues.append(nom.strip_edges())
	var candidats: Array = []
	for noeud in arbre.get_nodes_in_group(GROUPE):
		var retour = noeud
		if not is_instance_valid(retour.zone) or not retour.zone.is_visible_in_tree(): continue
		var rect: Rect2 = retour.zone.get_global_rect()
		if not vue.encloses(rect) or rect.size.x < 24 or rect.size.y < 20: continue
		candidats.append(retour)
	var choisis: Array = []
	for nom in voulues:
		for retour in candidats:
			if str(retour.zone.name) == nom and not choisis.has(retour):
				choisis.append(retour)
				break
	for pilules in [false, true]:
		if choisis.size() >= 2: break
		var tries := candidats.filter(func(r): return not choisis.has(r) and r.pilule == pilules)
		tries.sort_custom(func(a, b): return a.zone.size.x * a.zone.size.y > b.zone.size.x * b.zone.size.y)
		for retour in tries:
			if choisis.size() >= 2: break
			choisis.append(retour)
	var noms: Array = []
	for i in choisis.size():
		choisis[i].forcer(1.0, 0.0 if i == 0 else 1.0)
		noms.append(("survol " if i == 0 else "appui ") + str(choisis[i].zone.name))
	return noms
