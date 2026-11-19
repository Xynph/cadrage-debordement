extends RefCounted
## Cadrage des temps forts (mode de base du match ; repli CD_MATCH_TEMPS_FORTS=0). Pendant un temps fort, la caméra
## du jeu (TV ou contact) se rapproche de l'action : le ballon, son porteur et les
## joueurs proches (hauteurs visibles : voir HAUTEUR), plus large pour un jeu au pied (le ballon et
## son point de chute) ou une longue course, serré sur le paquet en mêlée, touche et ruck. Le
## ballon ne sort jamais du champ. Présentation seulement :
## même amortissement que le recadrage des gestes (match_gestes.gd), qui s'applique
## par-dessus quand un geste est en cours. La vue tactique n'est jamais recadrée.
const Gestes = preload("res://match_gestes.gd")

const ENTREE := 1.0        # rapprochement, en secondes
const SORTIE := 1.5        # retour au cadrage large
## Hauteur visible minimale et maximale au point visé, en mètres (caméras en perspective depuis le
## 18 novembre 2026 : TV 22 à 34 m selon la dispersion du porteur et des joueurs proches, au lieu
## de 28 à 42 m en vue orthographique ; action 9 à 18 m).
const HAUTEUR := {"tv": [22.0, 34.0], "action": [9.0, 18.0]}
## Jeu au pied, longue course : hauteur visible maximale (le ballon et son point de chute).
const LARGE := {"tv": 50.0, "action": 34.0}
## Regroupement (mêlée, touche, ruck) : cadrage serré sur le paquet et les demis.
const SERRE := {"tv": [18.0, 28.0], "action": [9.0, 14.0]}
const MARGE := 1.25
const PROCHES := 9.0       # rayon des joueurs concernés autour du ballon
const TEMOINS_RAYON := 18.0  # rayon des témoins (joueurs les plus proches) quand peu de joueurs sont proches
const SUR := 0.8           # part du demi-champ où le ballon doit rester
const TAILLE_JOUEUR := 2.0
const VOLS := ["kick", "kickoff", "drop22", "goalLine", "reception", "touch", "goal", "miss", "transformation"]
## Arrêts de jeu (coup de sifflet, carton) : le ballon est mort, personne ne le porte et
## les joueurs se tiennent souvent à plus de PROCHES mètres. Le plan montre le groupe le
## plus proche (au moins TEMOINS joueurs), en plan large ; il ne cadre jamais l'herbe seule.
const ARRETS := ["penalty", "card", "advantage", "ingoal", "hand-fault"]
const TEMOINS := 6
## Hors temps fort (18 novembre 2026, soir) : le cadrage de base suit lui aussi les joueurs concernés
## (porteur, soutiens et défenseurs à SUIVI_RAYON m du ballon, au moins SUIVI_TEMOINS joueurs) au lieu
## d'une hauteur fixe : leur étendue, avec la marge SUIVI_MARGE (jeu ouvert : de l'espace autour),
## donne la hauteur visible, bornée par SUIVI (TV 26 à 42 m autour des 30 m de base, contact 13 à
## 24 m autour de 16 m) ; point visé rapproché du groupe de SUIVI_CENTRE (part de l'écart), le tout
## amorti en SUIVI_LISSAGE secondes pour éviter les à-coups.
const SUIVI := {"tv": [26.0, 42.0], "action": [13.0, 24.0]}
const SUIVI_MARGE := 1.6
const SUIVI_RAYON := 15.0
const SUIVI_TEMOINS := 4
const SUIVI_TEMOINS_RAYON := 25.0
const SUIVI_CENTRE := 0.35
const SUIVI_LISSAGE := 1.2

var view
var actif := false
var kind := ""
var large := false
var poids := 0.0
var _centre := Vector3.ZERO
var _vitesse_centre := Vector3.ZERO
var _taille := 0.0
var _vitesse_taille := 0.0
var _pose := false
## Parts de l'image couvertes par l'interface du direct, en haut (bandeau du score) et
## en bas (légende et commandes) : l'action est cadrée dans ce qui reste visible.
var couvert_haut := 0.0
var couvert_bas := 0.0
## Cadrage de base adaptatif (hors temps fort) : écart du point visé au suivi et hauteur visible,
## amortis ; `_suivi_mode` vide tant qu'il n'a pas été posé (premier cadrage, coupe, changement de vue).
var _suivi_ecart := Vector3.ZERO
var _suivi_ecart_vitesse := Vector3.ZERO
var _suivi_taille := 0.0
var _suivi_taille_vitesse := Vector3.ZERO
var _suivi_mode := ""
var _suivi_pose := false


func _init(owner: Node3D) -> void:
	view = owner


## Appelée par la régie à chaque plan. `longue` : course ou jeu au pied à cadrer plus large.
func regler(on: bool, plan_kind: String = "", longue: bool = false) -> void:
	actif = on
	kind = plan_kind
	large = longue or plan_kind in VOLS or plan_kind in ARRETS


## Parts de la hauteur d'image masquées par l'interface, données par la régie.
func couvrir(haut: float, bas: float) -> void:
	couvert_haut = clampf(haut, 0.0, 0.3)
	couvert_bas = clampf(bas, 0.0, 0.35)


## Coupe : le prochain cadrage est posé d'un coup, sans rapprochement.
func couper() -> void:
	_pose = true
	_suivi_pose = true


func frame_camera(focus: Vector3, size: float, offset: Vector3, aspect: float, mode: String, delta: float, cut: bool = false) -> Array:
	if not HAUTEUR.has(mode):
		poids = 0.0
		_suivi_mode = ""
		return [focus, size, offset]
	var basis := Basis.looking_at(-offset, Vector3.UP)
	# Cadrage de base adaptatif : point de départ du temps fort, et cadrage hors temps fort.
	var suivi := _suivre(focus, basis, aspect, mode, delta, cut or _suivi_pose)
	_suivi_pose = false
	focus = suivi[0]
	size = suivi[1]
	if not actif and poids <= 0.0:
		poids = 0.0
		return [focus, size, offset]
	if actif:
		var but := _but(basis, aspect, mode, size, focus)
		if _pose or poids <= 0.0 or _taille <= 0.0:
			_centre = but[0]
			_taille = but[1]
			_vitesse_centre = Vector3.ZERO
			_vitesse_taille = 0.0
		elif delta > 0.0:
			var pas_centre: Array = Gestes._damp3(_centre, but[0], _vitesse_centre, delta)
			_centre = pas_centre[0]
			_vitesse_centre = pas_centre[1]
			var pas_taille: Array = Gestes._damp1(_taille, but[1], _vitesse_taille, delta)
			_taille = pas_taille[0]
			_vitesse_taille = pas_taille[1]
		poids = 1.0 if _pose or cut else minf(1.0, poids + delta / ENTREE)
		_pose = false
		_centre = _garder(_ballon(focus), _centre, _taille, basis, aspect)
	else:
		poids = maxf(0.0, poids - delta / SORTIE)
		if poids <= 0.0:
			return [focus, size, offset]
	if not _centre.is_finite() or not is_finite(_taille) or _taille < 2.0:
		poids = 0.0
		return [focus, size, offset]
	var w := smoothstep(0.0, 1.0, poids)
	return [focus.lerp(_centre, w), size * pow(_taille / size, w), offset]


## Cadrage de base adaptatif : [point visé, hauteur visible] qui englobent le porteur et les joueurs
## proches, amortis (SUIVI_LISSAGE) ; posés d'un coup à la première image et sur une coupe.
func _suivre(focus: Vector3, basis: Basis, aspect: float, mode: String, delta: float, pose: bool) -> Array:
	var but := _but_suivi(focus, basis, aspect, mode)
	var ecart: Vector3 = but[0]
	var taille: float = but[1]
	if pose or _suivi_mode != mode or _suivi_taille <= 0.0 or not _suivi_ecart.is_finite():
		_suivi_mode = mode
		_suivi_ecart = ecart
		_suivi_taille = taille
		_suivi_ecart_vitesse = Vector3.ZERO
		_suivi_taille_vitesse = Vector3.ZERO
	elif delta > 0.0:
		var pas_ecart: Array = Gestes._damp3(_suivi_ecart, ecart, _suivi_ecart_vitesse, delta, SUIVI_LISSAGE)
		_suivi_ecart = pas_ecart[0]
		_suivi_ecart_vitesse = pas_ecart[1]
		var pas_taille: Array = Gestes._damp3(Vector3(_suivi_taille, 0.0, 0.0), Vector3(taille, 0.0, 0.0), _suivi_taille_vitesse, delta, SUIVI_LISSAGE)
		_suivi_taille = (pas_taille[0] as Vector3).x
		_suivi_taille_vitesse = pas_taille[1]
	return [focus + _suivi_ecart, _suivi_taille]


## But du cadrage de base : [écart du point visé au suivi, hauteur visible].
func _but_suivi(focus: Vector3, basis: Basis, aspect: float, mode: String) -> Array:
	var bornes: Array = SUIVI[mode]
	var ballon := _ballon(focus)
	var sol := Vector3(ballon.x, 0.0, ballon.z)
	var points: Array[Vector3] = [sol, sol + Vector3.UP * maxf(TAILLE_JOUEUR, ballon.y)]
	var distances: Array = []
	for id: String in view._actors:
		var place: Vector3 = view._actors[id].node.position
		distances.append([Vector2(place.x - sol.x, place.z - sol.z).length(), id])
	distances.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for rang in distances.size():
		var ecart: float = distances[rang][0]
		var id: String = distances[rang][1]
		# Rang 0 : le joueur le plus proche du ballon (souvent le porteur) ; puis SUIVI_TEMOINS autres.
		if id == view._carrier_id or ecart <= SUIVI_RAYON or (rang <= SUIVI_TEMOINS and ecart <= SUIVI_TEMOINS_RAYON):
			var place: Vector3 = view._actors[id].node.position
			points.append(Vector3(place.x, 0.0, place.z))
			points.append(Vector3(place.x, TAILLE_JOUEUR, place.z))
	var inverse := basis.inverse()
	var bas := Vector2(INF, INF)
	var haut := Vector2(-INF, -INF)
	for point: Vector3 in points:
		var local := inverse * point
		bas = Vector2(minf(bas.x, local.x), minf(bas.y, local.y))
		haut = Vector2(maxf(haut.x, local.x), maxf(haut.y, local.y))
	var etendue := haut - bas
	var visible := 1.0 - couvert_haut - couvert_bas
	var taille := clampf(maxf(etendue.y / visible, etendue.x / maxf(aspect, 0.1)) * SUIVI_MARGE, float(bornes[0]), float(bornes[1]))
	var milieu := (bas + haut) * 0.5
	var centre := basis * Vector3(milieu.x, milieu.y, 0.0)
	var axe := -basis.z
	if absf(axe.y) > 0.01:
		centre += axe * (-centre.y / axe.y)
	var ecart_centre := Vector3(centre.x - focus.x, 0.0, centre.z - focus.z) * SUIVI_CENTRE
	if not ecart_centre.is_finite() or not is_finite(taille):
		return [Vector3.ZERO, float(bornes[0] + bornes[1]) * 0.5]
	return [ecart_centre, taille]


## Dernier mot après le recadrage d'un geste (angle et taille choisis par lui) : le point
## visé est déplacé juste assez pour que le ballon reste à l'image pendant un temps fort.
func garder_ballon(look: Vector3, size: float, offset: Vector3, aspect: float) -> Vector3:
	if not actif or not is_finite(size) or size < 2.0 or not is_instance_valid(view._ball) or not view._ball.visible:
		return look
	return _garder(view._ball.global_position, look, size, Basis.looking_at(-offset, Vector3.UP), aspect)


func _ballon(focus: Vector3) -> Vector3:
	var ball: Node3D = view._ball
	return ball.global_position if is_instance_valid(ball) and ball.visible else focus


## Point visé au sol et hauteur visible qui contiennent l'action, vus sous l'angle de la caméra.
func _but(basis: Basis, aspect: float, mode: String, _base: float, focus: Vector3) -> Array:
	var ballon := _ballon(focus)
	var sol := Vector3(ballon.x, 0.0, ballon.z)
	var points: Array[Vector3] = [sol, sol + Vector3.UP * maxf(TAILLE_JOUEUR, ballon.y)]
	var bornes: Array = HAUTEUR[mode]
	var plus_large := float(LARGE[mode]) if large else float(bornes[1])
	# Mêlée, touche, ruck : le paquet et les demis seulement, pas les arrières écartés.
	var groupe: Array = view.regroupement() if view.has_method("regroupement") else []
	if not groupe.is_empty():
		bornes = SERRE[mode]
		plus_large = float(bornes[1])
		for place: Vector3 in groupe:
			points.append(place)
			points.append(place + Vector3.UP * TAILLE_JOUEUR)
	else:
		# Joueurs concernés : le porteur, ceux qui sont près du ballon ; au moins TEMOINS joueurs
		# (les plus proches, TEMOINS_RAYON m au plus), pour qu'un plan ne montre jamais un terrain vide.
		var distances: Array = []
		for id: String in view._actors:
			var place: Vector3 = view._actors[id].node.position
			var ecart := Vector2(place.x - sol.x, place.z - sol.z).length()
			distances.append([ecart, id])
		distances.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		# Arrêt de jeu, ou presque personne autour du ballon : témoins cherchés jusqu'à 30 m.
		var rayon := TEMOINS_RAYON
		if kind in ARRETS or distances.size() < 2 or float(distances[1][0]) > TEMOINS_RAYON:
			rayon = 30.0
		for rang in distances.size():
			var id: String = distances[rang][1]
			var ecart: float = distances[rang][0]
			if id == view._carrier_id or ecart <= PROCHES or (rang < TEMOINS and ecart <= rayon):
				var place: Vector3 = view._actors[id].node.position
				points.append(Vector3(place.x, 0.0, place.z))
				points.append(Vector3(place.x, TAILLE_JOUEUR, place.z))
	if kind in VOLS:
		# Ballon en l'air : son départ et son point de chute restent à l'image ; le cadrage vise
		# entre les deux et s'élargit (pistes du chorégraphe ou trajectoire du direct).
		var chute: Variant = null
		if view.has_method("choregraphie_active") and view.choregraphie_active() and view._choregraphie.has_method("chute_ballon"):
			chute = view._choregraphie.chute_ballon()
		if chute is Vector3:
			points.append(chute)
		elif not view._ball_attached:
			for extremite: Vector3 in [view._ball_from, view._ball_target]:
				if extremite.is_finite(): points.append(Vector3(extremite.x, 0.0, extremite.z))
	var inverse := basis.inverse()
	var bas := Vector2(INF, INF)
	var haut := Vector2(-INF, -INF)
	for point: Vector3 in points:
		var local := inverse * point
		bas = Vector2(minf(bas.x, local.x), minf(bas.y, local.y))
		haut = Vector2(maxf(haut.x, local.x), maxf(haut.y, local.y))
	# Un geste de la vue choisit son propre cadrage, jamais plus large que celui-ci : on lui laisse la place.
	var gestes: Variant = view.get("_gestes")
	var plus_serre := float(bornes[1]) if gestes != null and gestes.active() else float(bornes[0])
	var etendue := haut - bas
	var visible := 1.0 - couvert_haut - couvert_bas
	# Plafond : la hauteur voulue (jeu au pied compris), même au-delà du cadrage de base de la caméra.
	var taille := clampf(maxf(etendue.y / visible, etendue.x / maxf(aspect, 0.1)) * MARGE, plus_serre, maxf(plus_large, plus_serre))
	var milieu := (bas + haut) * 0.5
	# L'action est centrée dans la partie de l'image que l'interface ne couvre pas.
	milieu.y -= (couvert_bas - couvert_haut) * 0.5 * taille
	var centre := basis * Vector3(milieu.x, milieu.y, 0.0)
	var axe := -basis.z
	if absf(axe.y) > 0.01:
		centre += axe * (-centre.y / axe.y)
	return [Vector3(centre.x, 0.0, centre.z), taille]


## Déplace le point visé juste assez pour que le ballon reste dans la zone sûre de l'image.
func _garder(ballon: Vector3, centre: Vector3, taille: float, basis: Basis, aspect: float) -> Vector3:
	var relatif := basis.inverse() * (ballon - centre)
	var demi := Vector2(taille * aspect * 0.5 * SUR, taille * 0.5)
	var dx := relatif.x - clampf(relatif.x, -demi.x, demi.x)
	var marge := (1.0 - SUR) * 0.5
	var dy := relatif.y - clampf(relatif.y, -demi.y + taille * (couvert_bas + marge), demi.y - taille * (couvert_haut + marge))
	if dx != 0.0:
		var droite := Vector3(basis.x.x, 0.0, basis.x.z)
		if droite.length() > 0.01:
			centre += droite / droite.length() * (dx / droite.length())
	if dy != 0.0:
		var avant := Vector3(basis.y.x, 0.0, basis.y.z)
		if avant.length() > 0.01:
			centre += avant / avant.length() * (dy / avant.length())
	return centre
