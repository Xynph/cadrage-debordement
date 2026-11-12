extends RefCounted
## Cadrage des temps forts (mode de base du match ; repli CD_MATCH_TEMPS_FORTS=0). Pendant un temps fort, la caméra
## du jeu (TV ou contact) se rapproche de l'action : le ballon, son porteur et les
## joueurs proches, à une hauteur visible de 12 à 18 m, plus large pour un jeu au pied
## ou une longue course. Le ballon ne sort jamais du champ. Présentation seulement :
## même amortissement que le recadrage des gestes (match_gestes.gd), qui s'applique
## par-dessus quand un geste est en cours. La vue tactique n'est jamais recadrée.
const Gestes = preload("res://match_gestes.gd")

const ENTREE := 1.0        # rapprochement, en secondes
const SORTIE := 1.5        # retour au cadrage large
## Hauteur visible minimale et maximale, en mètres.
const HAUTEUR := {"tv": [12.0, 18.0], "action": [10.0, 16.0]}
const LARGE := 26.0        # jeu au pied, longue course
const MARGE := 1.25
const PROCHES := 9.0       # rayon des joueurs concernés autour du ballon
const SUR := 0.8           # part du demi-champ où le ballon doit rester
const TAILLE_JOUEUR := 2.0
const VOLS := ["kick", "kickoff", "drop22", "goalLine", "reception", "touch", "goal", "miss", "transformation"]
## Arrêts de jeu (coup de sifflet, carton) : le ballon est mort, personne ne le porte et
## les joueurs se tiennent souvent à plus de PROCHES mètres. Le plan montre le groupe le
## plus proche (au moins TEMOINS joueurs), en plan large ; il ne cadre jamais l'herbe seule.
const ARRETS := ["penalty", "card", "advantage", "ingoal", "hand-fault"]
const TEMOINS := 6

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


func frame_camera(focus: Vector3, size: float, offset: Vector3, aspect: float, mode: String, delta: float, cut: bool = false) -> Array:
	if not HAUTEUR.has(mode) or (not actif and poids <= 0.0):
		poids = 0.0
		return [focus, size, offset]
	var basis := Basis.looking_at(-offset, Vector3.UP)
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
func _but(basis: Basis, aspect: float, mode: String, base: float, focus: Vector3) -> Array:
	var ballon := _ballon(focus)
	var sol := Vector3(ballon.x, 0.0, ballon.z)
	var points: Array[Vector3] = [sol, sol + Vector3.UP * maxf(TAILLE_JOUEUR, ballon.y)]
	# Joueurs concernés : le porteur, ceux qui sont près du ballon ; au moins TEMOINS joueurs
	# (les plus proches, 30 m au plus), pour qu'un plan ne montre jamais un terrain vide.
	var distances: Array = []
	for id: String in view._actors:
		var place: Vector3 = view._actors[id].node.position
		var ecart := Vector2(place.x - sol.x, place.z - sol.z).length()
		distances.append([ecart, id])
	distances.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for rang in distances.size():
		var id: String = distances[rang][1]
		var ecart: float = distances[rang][0]
		if id == view._carrier_id or ecart <= PROCHES or (rang < TEMOINS and ecart <= 30.0):
			var place: Vector3 = view._actors[id].node.position
			points.append(Vector3(place.x, 0.0, place.z))
			points.append(Vector3(place.x, TAILLE_JOUEUR, place.z))
	if kind in VOLS and not view._ball_attached:
		# Ballon en l'air : son départ et son arrivée restent à l'image.
		for extremite: Vector3 in [view._ball_from, view._ball_target]:
			if extremite.is_finite(): points.append(Vector3(extremite.x, 0.0, extremite.z))
	var inverse := basis.inverse()
	var bas := Vector2(INF, INF)
	var haut := Vector2(-INF, -INF)
	for point: Vector3 in points:
		var local := inverse * point
		bas = Vector2(minf(bas.x, local.x), minf(bas.y, local.y))
		haut = Vector2(maxf(haut.x, local.x), maxf(haut.y, local.y))
	var bornes: Array = HAUTEUR[mode]
	var plus_large := LARGE if large else float(bornes[1])
	# Un geste de la vue choisit son propre cadrage, jamais plus large que celui-ci : on lui laisse la place.
	var gestes: Variant = view.get("_gestes")
	var plus_serre := float(bornes[1]) if gestes != null and gestes.active() else float(bornes[0])
	var etendue := haut - bas
	var visible := 1.0 - couvert_haut - couvert_bas
	var taille := clampf(maxf(etendue.y / visible, etendue.x / maxf(aspect, 0.1)) * MARGE, plus_serre, minf(maxf(plus_large, plus_serre), base))
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
