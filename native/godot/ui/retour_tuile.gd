extends Control
## Retour visuel commun au survol et à l'appui de TOUTES les tuiles cliquables (idée 10 de Léo, 22/11/2026) : un seul
## endroit décide de ce que fait une tuile, une pastille, une carte ou une zone de lecture quand la souris passe dessus
## ou l'enfonce. Transition courte (80 ms), jamais de vert de sélection.
##
## Éclaircissement + liseré du club (choix de Léo, option A) : voile crème, filet clair en haut (relief), liseré gauche
## de 4 px à la couleur du club (même famille que le survol de ligne, ui/survol_ligne.gd) ; à l'appui, voile plus fort et
## filet sombre en haut (la tuile s'enfonce). Jamais d'ombre.
##
## Usage : `RetourTuile.brancher(zone, visuel, rayon_px)` ; `zone` reçoit la souris (bouton plat posé sur la tuile, ou la
## tuile elle-même), `visuel` est la carte dessinée. Pour un Button, ses états hover/pressed propres sont
## neutralisés : le retour vient d'ici seulement. Le focus clavier garde son contour crème.
## Branché par : reperes.cliquable, petites_pieces.rendre_cliquable, pastilles_club (tuiles et pastilles), lien_zone,
## et les tuiles propres du Bureau, de l'Effectif, du Club et des Classements.

const Charte = preload("res://ui/charte.gd")
const GROUPE := "retour_tuile"
const NOM := "RetourTuile"
const DUREE := 0.08
const LISERE := 4.0
## Voiles crème : survol, appui.
const VOILE := [0.10, 0.17]

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
var _accent := Color.TRANSPARENT

static func echelle(noeud: CanvasItem) -> float:
	var vue := noeud.get_viewport_rect().size if noeud.is_inside_tree() else Vector2(1920, 1080)
	return clampf(minf(vue.y / 1080.0, vue.x / 1920.0), 0.8, 1.6)

## Couleur du club rendue lisible sur fond sombre (même règle que le liseré du survol de ligne).
static func accent_lisible(couleur: Color) -> Color:
	if couleur.a <= 0.0 or couleur.s < 0.12: return Charte.IVOIRE
	return Color.from_hsv(couleur.h, clampf(couleur.s, 0.55, 0.85), maxf(couleur.v, 0.88))

## Branche le retour commun sur `zone` (idempotent). `rayon` en pixels ; `Charte.RAYON_PILULE` pour une pilule.
## `avec_lisere` : false quand la tuile porte déjà une barre de couleur à gauche (priorités du Bureau).
static func brancher(p_zone: Control, p_visuel: Control = null, p_rayon: float = -1.0, neutraliser: bool = true, avec_lisere: bool = true) -> Control:
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
	return retour

## ---- Branchement automatique ---------------------------------------------------------------------------------------
## Tout bouton qui a l'allure d'une tuile (zone plate posée sur une carte, bouton à fond) ou d'une pastille reçoit le
## retour commun à son premier survol : aucun écran n'a à y penser. Les liens de texte (soulignés au survol), les
## boutons dorés, les voiles plein écran et les boutons désactivés ne sont pas touchés ; une ligne de tableau reçoit le
## survol de ligne commun (ui/survol_ligne.gd) et sa rayure reste à l'écran qui la dessine. Un écran peut s'en retirer
## avec `set_meta("sans_retour", true)`.
const META_AUTO := "retour_tuile_auto"
static var _installe := false

static func installer(racine: Node) -> void:
	if _installe or racine == null or racine.get_tree() == null: return
	_installe = true
	racine.get_tree().node_added.connect(_noeud_ajoute)

static func _noeud_ajoute(noeud: Node) -> void:
	if noeud.has_meta(META_AUTO): return
	if noeud is BaseButton:
		noeud.set_meta(META_AUTO, true)
		noeud.mouse_entered.connect(_premier_survol.bind(noeud), CONNECT_ONE_SHOT)
	elif noeud is Panel or noeud is PanelContainer:
		# Tuile non bouton (carte qui écoute la souris elle-même) : vérifiée une fois construite.
		_zone_a_verifier.call_deferred(noeud)

static func _zone_a_verifier(zone: Control) -> void:
	if not is_instance_valid(zone) or zone.has_meta(META_AUTO) or not zone_cliquable(zone): return
	zone.set_meta(META_AUTO, true)
	zone.mouse_entered.connect(_premier_survol_zone.bind(zone), CONNECT_ONE_SHOT)

static func _premier_survol_zone(zone: Control) -> void:
	var retour = habiller_zone(zone)
	if retour != null: retour._entree()

## Une carte (Panel, PanelContainer) qui reçoit la souris et traite elle-même les clics.
static func zone_cliquable(zone: Control) -> bool:
	return zone.mouse_filter == Control.MOUSE_FILTER_STOP and zone.gui_input.get_connections().size() > 0

static func habiller_zone(zone: Control) -> Variant:
	if not is_instance_valid(zone) or not zone.is_inside_tree() or zone.has_node(NOM) or zone.has_meta("sans_retour"): return null
	var vue := zone.get_viewport_rect().size
	if zone.size.x < 40.0 or zone.size.y < 24.0 or (zone.size.x >= vue.x * 0.7 and zone.size.y >= vue.y * 0.5): return null
	var rayon_px := float(Charte.RAYON_CARTE)
	var style := zone.get_theme_stylebox("panel")
	if style is StyleBoxFlat: rayon_px = float((style as StyleBoxFlat).get_corner_radius(CORNER_TOP_LEFT))
	return brancher(zone, zone, rayon_px if rayon_px >= 3.0 else float(Charte.RAYON_PETIT))

static func _premier_survol(bouton: BaseButton) -> void:
	var retour = habiller(bouton)
	if retour != null: retour._entree()

## Branche le retour qui convient à ce bouton (null s'il n'en reçoit pas). Renvoie le composant posé.
static func habiller(bouton: BaseButton) -> Variant:
	if not is_instance_valid(bouton) or not bouton.is_inside_tree(): return null
	var genre := classer(bouton)
	if genre.is_empty(): return null
	var normal := bouton.get_theme_stylebox("normal")
	var rayon_px := float(normal.get_corner_radius(CORNER_TOP_LEFT)) if normal is StyleBoxFlat else float(Charte.RAYON_CARTE)
	if genre == "pastille": return brancher(bouton, bouton, float(Charte.RAYON_PILULE))
	if genre == "ligne":
		var fond = load("res://ui/survol_ligne.gd").appliquer(bouton, false, Color.TRANSPARENT, Color.TRANSPARENT)
		fond.sans_rayure = true
		return fond
	return brancher(bouton, bouton, maxf(float(Charte.RAYON_PETIT), minf(rayon_px, float(Charte.RAYON_CARTE))) if rayon_px < Charte.RAYON_PILULE / 2.0 else float(Charte.RAYON_CARTE))

## "tuile", "pastille", "ligne" ou "" (pas de retour) selon l'allure du bouton.
static func classer(bouton: BaseButton) -> String:
	if bouton.disabled or bouton.has_meta("sans_retour") or bouton.has_node(NOM) or bouton.has_node("SurvolLigne"): return ""
	if bouton is CheckBox or bouton is CheckButton or bouton is LinkButton: return ""
	var taille := bouton.size
	var vue := bouton.get_viewport_rect().size
	if taille.x < 16.0 or taille.y < 16.0: return ""
	# Voile plein écran ou grande zone de fond : jamais.
	if taille.x >= vue.x * 0.7 and taille.y >= vue.y * 0.5: return ""
	var k := echelle(bouton)
	var normal := bouton.get_theme_stylebox("normal")
	var texte: String = (bouton as Button).text if bouton is Button else ""
	var avec_texte: bool = not texte.strip_edges().is_empty() or (bouton is Button and (bouton as Button).icon != null)
	var transparent := normal == null or normal is StyleBoxEmpty
	if normal is StyleBoxFlat:
		var plat := normal as StyleBoxFlat
		if plat.bg_color.a < 0.05 and plat.border_width_left == 0 and plat.border_width_right == 0 and plat.border_width_top == 0 and plat.border_width_bottom == 0: transparent = true
		# Lien souligné : sa marque de survol est le trait.
		if plat.bg_color.a < 0.05 and plat.border_width_bottom > 0 and plat.border_width_top == 0: return ""
		# Bouton principal doré : un seul aplat doré par écran, il garde son propre état.
		if plat.bg_color.a > 0.5 and (plat.bg_color.is_equal_approx(Charte.OR) or plat.bg_color.is_equal_approx(Charte.OR_VIF)): return ""
	if transparent:
		if avec_texte: return ""
		var ratio := taille.x / maxf(1.0, taille.y)
		if ratio > 9.0: return "ligne" if taille.y >= 24.0 * k * 0.8 and taille.x >= 450.0 * k else ""
		return "tuile" if taille.y >= 34.0 * k * 0.8 and taille.x >= 40.0 * k * 0.8 else ""
	if taille.y > 80.0 * k and taille.x / taille.y > 9.0: return "ligne"
	var rayon_px := float((normal as StyleBoxFlat).get_corner_radius(CORNER_TOP_LEFT)) if normal is StyleBoxFlat else 0.0
	if normal is StyleBoxFlat and (rayon_px * 2.0 >= minf(taille.x, taille.y) * 0.8 or rayon_px >= Charte.RAYON_PILULE / 2.0): return "pastille"
	return "tuile"

## Captures et audit : applique tout de suite le branchement automatique aux boutons visibles.
static func balayer(arbre: SceneTree) -> int:
	var n := 0
	var pile: Array = [arbre.root]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		for enfant in noeud.get_children(): pile.append(enfant)
		if noeud is BaseButton and (noeud as Control).is_visible_in_tree() and habiller(noeud as BaseButton) != null: n += 1
		elif (noeud is Panel or noeud is PanelContainer) and (noeud as Control).is_visible_in_tree() and zone_cliquable(noeud as Control) and habiller_zone(noeud as Control) != null: n += 1
	return n

## Le bouton ne dessine plus de survol ni d'appui à lui : son fond reste celui de l'état normal.
static func _neutraliser(bouton: Button) -> void:
	var normal := bouton.get_theme_stylebox("normal")
	for etat in ["hover", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, normal)

func _ready() -> void:
	set_process(false)

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

func _suivre() -> void:
	if not is_instance_valid(zone): return
	global_position = zone.global_position
	size = zone.size

func _rafraichir() -> void:
	if not is_inside_tree(): return
	if top_level: _suivre()
	queue_redraw()

func _couleur_club() -> Color:
	if _accent.a > 0.0: return _accent
	_accent = accent_lisible(couleur_du_club(self))
	return _accent

## Couleur du club de la partie : propriété `accent` de l'écran principal (cherchée en remontant l'arbre, puis sur la
## scène courante).
static func couleur_du_club(noeud: Node) -> Color:
	var n: Node = noeud
	while n != null:
		var c: Variant = n.get("accent")
		if c is Color and (c as Color).a > 0.0: return c
		n = n.get_parent()
	var scene := noeud.get_tree().current_scene if noeud.is_inside_tree() else null
	var couleur: Variant = scene.get("accent") if scene != null else null
	return couleur if couleur is Color else Charte.IVOIRE

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
	var voile := lerpf(float(VOILE[0]) * survol, float(VOILE[1]), appui)
	draw_style_box(_boite(Color(Charte.IVOIRE, voile), r), rect)
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

## Captures : met une tuile en survol et une autre en appui (noms de zone dans CD_FILM_RETOUR_TUILE_CIBLES, sinon les
## deux plus grandes tuiles entièrement visibles). Renvoie les noms des zones touchées.
static func simuler(arbre: SceneTree) -> Array:
	balayer(arbre)
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

## Audit (captures) : liste les boutons et zones cliquables visibles qui n'ont ni retour de tuile ni survol de ligne.
static func auditer(arbre: SceneTree) -> Array:
	balayer(arbre)
	var vue := arbre.root.get_visible_rect()
	var lignes: Array = []
	var pile: Array = [arbre.root]
	while not pile.is_empty():
		var noeud: Node = pile.pop_back()
		for enfant in noeud.get_children(): pile.append(enfant)
		if not (noeud is Control) or not (noeud as Control).is_visible_in_tree(): continue
		var c := noeud as Control
		var cliquable := (c is BaseButton and not (c as BaseButton).disabled and c.mouse_filter != Control.MOUSE_FILTER_IGNORE) or (c.mouse_filter == Control.MOUSE_FILTER_STOP and c.gui_input.get_connections().size() > 0)
		if not cliquable: continue
		if c.has_node(NOM) or c.has_node("SurvolLigne"): continue
		var rect := c.get_global_rect()
		if rect.size.x < 16 or rect.size.y < 16 or not vue.intersects(rect): continue
		if c is OptionButton or c is MenuButton: pass
		var parent_script := ""
		var p: Node = c
		while p != null and parent_script.is_empty():
			var s = p.get_script()
			if s != null: parent_script = str(s.resource_path).get_file()
			p = p.get_parent()
		var texte := str(c.get("text")) if c.get("text") != null else ""
		var normal := (c as Control).get_theme_stylebox("normal") if c is Button else null
		var genre := "zone"
		if c is Button:
			genre = "plat" if (normal is StyleBoxEmpty or (normal is StyleBoxFlat and (normal as StyleBoxFlat).bg_color.a < 0.05 and (normal as StyleBoxFlat).border_width_left == 0)) else "bouton"
		lignes.append("%s|%s|%s|%s|%dx%d@%d,%d|%s" % [genre, c.get_class(), c.name, parent_script, rect.size.x, rect.size.y, rect.position.x, rect.position.y, texte.left(24)])
	return lignes
