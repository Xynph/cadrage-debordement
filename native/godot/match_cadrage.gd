extends RefCounted
## Cadrage des temps forts (mode de base du match ; repli CD_MATCH_TEMPS_FORTS=0). Pendant un temps fort, la caméra
## du jeu (TV ou contact) se rapproche de l'action : le ballon, son porteur et les
## joueurs proches (hauteurs visibles : voir HAUTEUR), plus large pour un jeu au pied (le ballon et
## son point de chute) ou une longue course, serré sur le paquet en mêlée, touche et ruck. Le
## ballon ne sort jamais du champ. Présentation seulement :
## même amortissement que le recadrage des gestes (match_gestes.gd), qui s'applique
## par-dessus quand un geste est en cours. La vue tactique n'est jamais recadrée.
const Gestes = preload("res://match_gestes.gd")
const ApresEssai = preload("res://match_apres_essai.gd")

const ENTREE := 1.0        # rapprochement, en secondes
const SORTIE := 1.5        # retour au cadrage large
## Hauteur visible minimale et maximale au point visé, en mètres (caméras en perspective depuis le
## 18 novembre 2026 : TV 22 à 34 m selon la dispersion du porteur et des joueurs proches, au lieu
## de 28 à 42 m en vue orthographique ; action 9 à 18 m). 19 novembre 2026 (soir) : vue TV plus basse
## (axe à 16°, match_view.gd) et plus serrée, TV 13 à 18 m (joueurs d'environ 75 à 100 px au point visé
## en 1280 x 720, au lieu de 35 à 55 px).
## 19 novembre 2026 (nuit) : caméra au contact 8 à 12,5 m (9 à 18 m avant), nettement plus serrée que
## la TV (voir SUIVI).
const HAUTEUR := {"tv": [13.0, 18.0], "action": [8.0, 12.5]}
## Jeu au pied, longue course : hauteur visible maximale (le ballon et son point de chute). TV : 50 m
## jusqu'au 19 novembre 2026 (soir), 30 m avec la vue plus basse (53 m de large au point visé ; au-delà,
## la caméra basse passerait sous le toit de la tribune proche dès le milieu du terrain).
const LARGE := {"tv": 30.0, "action": 34.0}
## Regroupement (mêlée, touche, ruck) : cadrage serré sur le paquet et les demis. 19/11/2026 : en TV,
## 18 m au moins de hauteur visible laissaient la mêlée en petite tache (un cinquième de la largeur) ;
## 13 m : les deux paquets et le demi occupent environ un tiers de l'image.
const SERRE := {"tv": [13.0, 24.0], "action": [9.0, 14.0]}
## Mêlée (préparation, introduction, poussée, sortie tenue par le demi) en vue TV. 19 novembre 2026 :
## à 13 m, les deux paquets (6 m des talons d'un n° 8 à l'autre, environ 7 m de corps) ne prenaient
## qu'un quart de la largeur du film en 16/9 et le demi et le ballon de l'introduction s'y perdaient ;
## à 7,5 m (13,3 m de large), ils en prennent environ la moitié. Le plafond laisse la place au demi
## qui ramasse derrière son n° 8 à la sortie. La caméra au contact garde SERRE.
const SERRE_MELEE := {"tv": [7.5, 12.0]}
const MELEES := ["melee", "sortie_melee"]
## Touche (19 novembre 2026, nuit) : vue TV moins plongeante, de côté et de 3/4, sur l'alignement et le
## lanceur. L'axe descend au plus à TOUCHE_INCLINAISON degrés au-dessus de l'horizon (16° hors touche) ;
## près de la touche proche (z du ballon de TOUCHE_GRUE_DEBUT à TOUCHE_GRUE_FIN m), la grue reprend la
## main comme ailleurs (sinon la caméra passerait sous le toit de la tribune proche et ouvrirait grand
## son angle). Amorti en ENTREE / SORTIE secondes, posé d'un coup sur une coupe.
## La caméra au contact garde ses 30° : à 20°, proche et basse, le haut de son image (2° sous l'horizon)
## montrait toute la tribune d'en face ; pour la borner à BORD_HAUT, le recentrage reculait le point visé
## à plus de 3 fois la hauteur visible de la touche lointaine (1,3 fois à 30°) et coupait le fond de
## l'alignement (sauteurs à 14,5 m de la touche sous le bas de l'image).
const TOUCHE_INCLINAISON := {"tv": 12.0}
const TOUCHE_GRUE_DEBUT := 4.0
const TOUCHE_GRUE_FIN := 30.0
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
## 19 novembre 2026 (soir) : plan large TV de 15 à 19 m autour des 18 m de base (axe à 16°) ; à 19 m,
## jeu au milieu, un joueur au point visé fait environ 68 px (1280 x 720), 80 px dans la moitié proche
## de l'image, et le public d'en face prend 13 % du haut de l'image (5 à 8 % à 26-42 m sous 24°).
## 19 novembre 2026 (nuit) : caméra au contact de 10 à 12,5 m autour des 12 m de base (13 à 24 m avant :
## presque le plan TV). Son plafond reste sous CONTACT_PART fois le plancher TV (12,75 m) : joueurs au
## point visé environ 1,35 fois plus grands qu'en TV, plan serré au cœur de l'action.
const SUIVI := {"tv": [15.0, 19.0], "action": [10.0, 12.5]}
const CONTACT_PART := 0.85
const SUIVI_MARGE := 1.6
const SUIVI_RAYON := 15.0
const SUIVI_TEMOINS := 4
const SUIVI_TEMOINS_RAYON := 25.0
const SUIVI_CENTRE := 0.35
const SUIVI_LISSAGE := 1.2
## Tir au but (transformation, pénalité tentée au but ; 19 novembre 2026) : caméra dans l'axe,
## derrière le buteur et un peu en hauteur (TIR_HAUTEUR m), ballon sur le tee et les deux poteaux
## au fond. Elle recule de TIR_RECUL[0] à TIR_RECUL[1] m derrière la marque, par pas de TIR_PAS m,
## jusqu'à voir le buteur, le ballon, le pied des deux montants, la barre et TIR_MONTANT m de
## montant, hors du bandeau et de la légende (marge TIR_MARGE). Pendant le vol, elle suit le
## ballon vers les perches : le buteur quitte le cadre, le ballon et sa course à venir (TIR_AVANCE,
## parts du vol) y entrent ; elle monte de TIR_MONTEE m ; ballon retombé, elle reprend le buteur avec
## les poteaux jusqu'au plan suivant. Amortie en TIR_LISSAGE s.
## Jamais dans une tribune : |x| <= TIR_BORNE.x, |z| <= TIR_BORNE.y (panneaux à |z| = 41,2 m,
## gradins à 45 m, tribunes d'en-but à 65 m).
const TIR_HAUTEUR := 2.8
const TIR_RECUL := [6.0, 45.0]
const TIR_PAS := 0.25
const TIR_MONTANT := 4.5
const TIR_MARGE := 0.05
const TIR_AVANCE := [0.15, 0.3]
const TIR_MONTEE := 1.2
const TIR_BORNE := Vector2(63.0, 44.0)
const TIR_LISSAGE := 0.15
## Montants des poteaux (repère de la vue) : x = ±50, z = ±POTEAUX_Z (match_view.gd).
const POTEAUX_Z := 2.8
const CHAMPS := {"tv": 24.0, "action": 36.0}
const TIR_GENRES := ["goal", "miss", "transformation"]
## Ralenti de l'essai (19 novembre 2026, match_rejeu.gd) : caméra latérale basse au bord du jeu, qui
## suit le ballon (le marqueur), à REJEU_HAUTEUR m au-dessus de la pelouse (la vue TV est à plus de
## 20 m), REJEU_RECUL m sur le côté du ballon et REJEU_RETRAIT m en deçà de lui (regard de biais vers
## l'en-but où il plonge). Côté de la tribune principale (même sens gauche-droite que la vue TV), sauf
## ballon trop près de la touche proche : contrechamp depuis l'autre côté. Jamais dans un panneau ni
## une tribune (REJEU_BORNE), jamais collée à un montant (REJEU_POTEAU m au moins).
const REJEU_HAUTEUR := 1.1
const REJEU_RECUL := 11.0
const REJEU_RETRAIT := 4.0
const REJEU_CHAMP := 30.0
const REJEU_VISEE := 0.9
const REJEU_BORNE := Vector2(60.0, 39.0)
const REJEU_POTEAU := 2.0

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
## Part (0 à 1, amortie) de la vue de touche moins plongeante (TOUCHE_INCLINAISON).
var _touche_poids := 0.0
## Tir au but filmé dans l'axe : {"marque": Vector3 (ballon sur le tee), "poteaux": Vector3 (milieu
## de la ligne de but visée), "buteur": id} ; vide hors tir. `_axe_actif` : la dernière image a été
## cadrée dans l'axe (la vue pose alors la caméra telle quelle). Caméra et point visé amortis.
var tir: Dictionary = {}
## Lois (coup franc, essai de pénalité ; 26 novembre 2026) : la régie fait entrer dans le cadre un témoin
## qui bouge (l'arbitre) et des points fixes (les poteaux), jusqu'au plan suivant (`regler` les efface).
var temoin: Node3D = null
var points_regie: Array[Vector3] = []
var _axe_actif := false
var _tir_camera := Vector3.ZERO
var _tir_camera_vitesse := Vector3.ZERO
var _tir_vise := Vector3.ZERO
var _tir_vise_vitesse := Vector3.ZERO


func _init(owner: Node3D) -> void:
	view = owner


## Appelée par la régie à chaque plan. `longue` : course ou jeu au pied à cadrer plus large.
## Un plan qui suit un tir au but filmé dans l'axe repart d'une coupe (retour à la caméra de la tribune).
func regler(on: bool, plan_kind: String = "", longue: bool = false) -> void:
	actif = on
	kind = plan_kind
	temoin = null
	points_regie.clear()
	large = longue or plan_kind in VOLS or plan_kind in ARRETS
	if not tir.is_empty():
		tir = {}
		couper()
		if view != null and "_camera_cut" in view: view._camera_cut = true


## Tir au but (transformation ou pénalité tentée) : caméra dans l'axe, derrière le buteur, jusqu'au
## plan suivant. `marque` : ballon sur le tee ; `poteaux_x` : ligne de but visée (repère de la vue, ±50).
func viser_poteaux(marque: Vector3, poteaux_x: float, buteur: String = "") -> void:
	tir = {"marque": Vector3(marque.x, 0.0, marque.z), "poteaux": Vector3(poteaux_x, 0.0, 0.0), "buteur": buteur}
	couper()


## La dernière image est cadrée dans l'axe d'un tir au but (la vue la pose sans autre recadrage).
func dans_l_axe() -> bool:
	return _axe_actif and actif and not tir.is_empty()


## Parts de la hauteur d'image masquées par l'interface, données par la régie.
func couvrir(haut: float, bas: float) -> void:
	couvert_haut = clampf(haut, 0.0, 0.3)
	couvert_bas = clampf(bas, 0.0, 0.35)


## Coupe : le prochain cadrage est posé d'un coup, sans rapprochement.
func couper() -> void:
	_pose = true
	_suivi_pose = true


func frame_camera(focus: Vector3, size: float, offset: Vector3, aspect: float, mode: String, delta: float, cut: bool = false) -> Array:
	_axe_actif = false
	if not HAUTEUR.has(mode):
		poids = 0.0
		_suivi_mode = ""
		_touche_poids = 0.0
		return [focus, size, offset]
	# Touche pendant un temps fort : axe moins plongeant (amorti), avant tout cadrage qui en dépend.
	var en_touche := actif and tir.is_empty() and _en_touche()
	if cut or _pose or delta <= 0.0:
		_touche_poids = 1.0 if en_touche else 0.0
	elif en_touche:
		_touche_poids = minf(1.0, _touche_poids + delta / ENTREE)
	else:
		_touche_poids = maxf(0.0, _touche_poids - delta / SORTIE)
	if _touche_poids > 0.0:
		offset = incliner_touche(offset, focus.z, mode, smoothstep(0.0, 1.0, _touche_poids))
	if actif and not tir.is_empty():
		# Tir au but : plan dans l'axe, derrière le buteur (le plan suivant repart d'une coupe).
		var axial := _cadrer_tir(aspect, mode, delta, cut or _pose)
		if not axial.is_empty():
			_pose = false
			_axe_actif = true
			poids = 1.0
			return axial
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


## Mêlée liée en cours (formation de la vue « melee » ou « sortie_melee », pas encore déliée) : cadrage
## SERRE_MELEE au lieu de SERRE (touche et ruck gardent SERRE).
func _en_melee() -> bool:
	var formations: Variant = view.get("_formations")
	if formations == null or not formations.has_method("active") or not formations.active():
		return false
	return str((formations.formation as Dictionary).get("type", "")) in MELEES


## Alignement de touche en place (formation « touche » de la vue).
func _en_touche() -> bool:
	if view == null:
		return false
	var formations: Variant = view.get("_formations")
	if formations == null or not formations.has_method("active") or not formations.active():
		return false
	return str((formations.formation as Dictionary).get("type", "")) == "touche"


## Direction de caméra `offset` abaissée vers TOUCHE_INCLINAISON[mode] (jamais relevée), pour la part
## `w` ; sans effet près de la touche proche (grue, `profondeur` : z du ballon). Lacet et distance gardés.
static func incliner_touche(offset: Vector3, profondeur: float, mode: String, w: float) -> Vector3:
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	if horizontal.length() < 0.001 or not TOUCHE_INCLINAISON.has(mode) or w <= 0.0:
		return offset
	var depart := atan2(offset.y, horizontal.length())
	var plafond := lerpf(deg_to_rad(float(TOUCHE_INCLINAISON[mode])), depart, smoothstep(TOUCHE_GRUE_DEBUT, TOUCHE_GRUE_FIN, profondeur))
	var elevation := lerpf(depart, minf(depart, plafond), clampf(w, 0.0, 1.0))
	return (horizontal.normalized() * cos(elevation) + Vector3.UP * sin(elevation)) * offset.length()


## Point visé au sol et hauteur visible qui contiennent l'action, vus sous l'angle de la caméra.
func _but(basis: Basis, aspect: float, mode: String, _base: float, focus: Vector3) -> Array:
	var ballon := _ballon(focus)
	var sol := Vector3(ballon.x, 0.0, ballon.z)
	var points: Array[Vector3] = [sol, sol + Vector3.UP * maxf(TAILLE_JOUEUR, ballon.y)]
	var bornes: Array = HAUTEUR[mode]
	var plus_large := float(LARGE[mode]) if large else float(bornes[1])
	# Mêlée, touche, ruck : le paquet et les demis seulement, pas les arrières écartés.
	var groupe: Array = view.regroupement() if view.has_method("regroupement") else []
	if kind == "coup_franc" and is_instance_valid(temoin):
		# Coup franc, plan serré (option B) : le ballon et l'arbitre au bras plié, de près.
		bornes = SERRE_MELEE.get(mode, SERRE[mode])
		plus_large = float(bornes[1])
	elif not groupe.is_empty():
		bornes = SERRE_MELEE[mode] if SERRE_MELEE.has(mode) and _en_melee() else SERRE[mode]
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
	# Lois : l'arbitre (bras levé compris) et les poteaux visés restent à l'image.
	if is_instance_valid(temoin):
		points.append(Vector3(temoin.position.x, 0.0, temoin.position.z))
		points.append(Vector3(temoin.position.x, TAILLE_JOUEUR + 0.4, temoin.position.z))
	points.append_array(points_regie)
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


## Tir au but filmé dans l'axe : [point visé, hauteur visible, direction de la caméra] tels que la
## vue (pose_camera) place la caméra derrière le buteur, un peu en hauteur, regard vers les poteaux.
## Rend [] si le tir n'a pas d'axe (marque sur la ligne de but).
func _cadrer_tir(aspect: float, mode: String, delta: float, pose: bool) -> Array:
	var marque: Vector3 = tir.marque
	var poteaux: Vector3 = tir.poteaux
	var axe := Vector3(marque.x - poteaux.x, 0.0, marque.z - poteaux.z)
	var distance := axe.length()
	if distance < 1.0:
		return []
	axe /= distance
	var devant := -axe
	var pente := tan(deg_to_rad(float(CHAMPS.get(mode, 24.0))) * 0.5)
	var ballon: Vector3 = marque
	if is_instance_valid(view._ball) and view._ball.visible:
		ballon = view._ball.global_position
	# Essentiel : ballon, pied des montants, barre et montants ; en plus : la course à venir du ballon.
	# Essai de pénalité : pas de ballon à suivre (il reste au point de la faute), l'arbitre à sa place.
	var essentiels: Array[Vector3] = []
	if not tir.get("sans_ballon", false):
		essentiels.append(ballon)
	if is_instance_valid(temoin):
		essentiels.append(Vector3(temoin.position.x, 0.0, temoin.position.z))
		essentiels.append(Vector3(temoin.position.x, TAILLE_JOUEUR + 0.4, temoin.position.z))
	for z: float in [-POTEAUX_Z, POTEAUX_Z]:
		for h: float in [0.0, 3.0, TIR_MONTANT]:
			essentiels.append(Vector3(poteaux.x, h, z))
	# Part du vol déjà faite (0 sur le tee, 1 retombé) ; le tir part de la marque (pose « prêt » :
	# ballon posé sur la marque, rien ne vole encore, course prévue vers le milieu des perches).
	var depart: Vector3 = view._ball_from
	var arrivee: Vector3 = view._ball_target
	var en_vol: bool = str(view._kind) in ["goal", "miss"] and not bool(view._ball_attached) and depart.is_finite() and arrivee.is_finite() \
		and Vector2(depart.x - marque.x, depart.z - marque.z).length() < 1.5 and Vector2(arrivee.x - marque.x, arrivee.z - marque.z).length() > 1.0
	var vole: float = clampf(float(view._ball_travel), 0.0, 1.0) if en_vol else 0.0
	if not en_vol:
		depart = Vector3(marque.x, 0.23, marque.z)
		arrivee = Vector3(poteaux.x, 0.23, 0.0)
	var en_plus: Array[Vector3] = []
	for avance: float in TIR_AVANCE:
		en_plus.append(ApresEssai.vol(depart, arrivee, minf(1.0, vole + avance)))
	if vole < 0.05 or vole >= 0.999:
		# Le buteur (élan compris) et le ballon sur le tee, jusqu'à la frappe : essentiels eux aussi ;
		# de nouveau une fois le ballon retombé, jusqu'au plan suivant (match filmé du 25/11 : deux à
		# trois secondes de poteaux et de défenseurs sans buteur après chaque tir).
		var pied := marque
		var id := str(tir.get("buteur", ""))
		if view._actors.has(id):
			pied = (view._actors[id].node as Node3D).position
		essentiels.append(Vector3(pied.x, 0.0, pied.z))
		essentiels.append(Vector3(pied.x, TAILLE_JOUEUR, pied.z))
		essentiels.append(Vector3(marque.x, 0.2, marque.z))
	# Fenêtre sûre : sous le bandeau du score, au-dessus de la légende (angles depuis l'axe).
	var fenetre := Vector3(atan((1.0 - 2.0 * (couvert_haut + TIR_MARGE)) * pente), atan((-1.0 + 2.0 * (couvert_bas + TIR_MARGE)) * pente), (1.0 - 2.0 * TIR_MARGE) * pente * maxf(aspect, 0.1))
	var hauteur := TIR_HAUTEUR + TIR_MONTEE * vole
	var tous: Array[Vector3] = essentiels.duplicate()
	tous.append_array(en_plus)
	var place := _placer_tir(tous, marque, axe, hauteur, fenetre)
	if not bool(place[2]):
		# Tout ne tient pas (stade trop proche) : d'abord le buteur, le ballon et les poteaux.
		var essentielle := _placer_tir(essentiels, marque, axe, hauteur, fenetre)
		if (essentielle[0] as Vector3).is_finite():
			place = essentielle
	var camera: Vector3 = place[0]
	var tangage: float = place[1]
	if not camera.is_finite():
		return []
	var regard := devant * cos(tangage) + Vector3.UP * sin(tangage)
	var portee := clampf(camera.y / sin(-tangage), 8.0, 120.0) if tangage < -0.03 else 40.0
	var vise := camera + regard * portee
	if pose or delta <= 0.0 or not _tir_camera.is_finite() or _tir_camera == Vector3.ZERO:
		_tir_camera = camera
		_tir_vise = vise
		_tir_camera_vitesse = Vector3.ZERO
		_tir_vise_vitesse = Vector3.ZERO
	else:
		var pas_camera: Array = Gestes._damp3(_tir_camera, camera, _tir_camera_vitesse, delta, TIR_LISSAGE)
		_tir_camera = pas_camera[0]
		_tir_camera_vitesse = pas_camera[1]
		var pas_vise: Array = Gestes._damp3(_tir_vise, vise, _tir_vise_vitesse, delta, TIR_LISSAGE)
		_tir_vise = pas_vise[0]
		_tir_vise_vitesse = pas_vise[1]
	var direction := _tir_camera - _tir_vise
	var recule := direction.length()
	if recule < 1.0:
		return []
	return [_tir_vise, 2.0 * recule * pente, direction / recule]


## Place de la caméra dans l'axe (derrière la marque, à `hauteur` m) qui montre tous les `points` :
## [caméra, tangage (rad, positif vers le haut), vrai si tout tient dans la fenêtre sûre]. Elle
## recule par pas de TIR_PAS m ; aux bornes du stade, la place la plus reculée, cadrage centré.
## `fenetre` : angles haut et bas permis depuis l'axe, et demi-largeur permise (tangente).
func _placer_tir(points: Array[Vector3], marque: Vector3, axe: Vector3, hauteur: float, fenetre: Vector3) -> Array:
	var devant := -axe
	var droite := Vector3(-devant.z, 0.0, devant.x)
	var camera := Vector3.INF
	var tangage := 0.0
	var recul: float = TIR_RECUL[0]
	while recul <= float(TIR_RECUL[1]) + 0.001:
		var c := marque + axe * recul + Vector3.UP * hauteur
		if absf(c.x) > TIR_BORNE.x or absf(c.z) > TIR_BORNE.y:
			break
		var e_min := INF
		var e_max := -INF
		var dedans := true
		for p: Vector3 in points:
			var d := p - c
			var loin := d.x * devant.x + d.z * devant.z
			if loin < 1.0 or absf((d.x * droite.x + d.z * droite.z) / loin) > fenetre.z:
				dedans = false
				break
			var e := atan2(d.y, loin)
			e_min = minf(e_min, e)
			e_max = maxf(e_max, e)
		if dedans:
			camera = c
			tangage = ((e_max - fenetre.x) + (e_min - fenetre.y)) * 0.5
			if e_max - e_min <= fenetre.x - fenetre.y:
				return [camera, tangage, true]
		recul += TIR_PAS
	return [camera, tangage, false]


## Ralenti d'un essai aplati en `ballon` (repère de la vue) : [sens de l'en-but (+1 : x = +50),
## côté de la caméra (+1 : tribune principale, z > 0)], fixés pour tout le ralenti.
static func cote_rejeu(ballon: Vector3) -> Vector2:
	var sens := 1.0 if ballon.x >= 0.0 else -1.0
	var cote := 1.0 if ballon.z + REJEU_RECUL <= REJEU_BORNE.y else -1.0
	return Vector2(sens, cote)


## Plan du ralenti quand le ballon est en `ballon` : {"camera", "vise", "champ"} (repère de la vue).
static func plan_rejeu(ballon: Vector3, cote: Vector2, retrait: float = REJEU_RETRAIT) -> Dictionary:
	var sens := 1.0 if cote.x >= 0.0 else -1.0
	var lateral := 1.0 if cote.y >= 0.0 else -1.0
	var camera := Vector3(ballon.x - sens * retrait, REJEU_HAUTEUR, ballon.z + lateral * REJEU_RECUL)
	camera.x = clampf(camera.x, -REJEU_BORNE.x, REJEU_BORNE.x)
	camera.z = clampf(camera.z, -REJEU_BORNE.y, REJEU_BORNE.y)
	# Ballon dans l'en-but : la caméra pourrait frôler un montant ; elle reste alors dans le terrain.
	for z: float in [-POTEAUX_Z, POTEAUX_Z]:
		if Vector2(camera.x - sens * 50.0, camera.z - z).length() < REJEU_POTEAU:
			camera.x = sens * (50.0 - REJEU_POTEAU)
	return {"camera": camera, "vise": Vector3(ballon.x, REJEU_VISEE, ballon.z), "champ": REJEU_CHAMP}


## Gêne d'un plan de ralenti (0 : rien ne masque) : un joueur (ou l'arbitre) debout entre la caméra
## et le ballon le cache d'autant plus qu'il est près de l'objectif ; un joueur à moins de
## REJEU_PRES m de la caméra et dans le champ remplit l'image même sans cacher le ballon.
## `places` : pieds de chaque personne (repère de la vue).
const REJEU_PRES := 6.5
const REJEU_CARRURE := 0.45
static func gene_rejeu(plan: Dictionary, places: PackedVector3Array) -> float:
	var camera: Vector3 = plan.camera
	var vise: Vector3 = plan.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5: return 0.0
	regard /= portee
	var demi_champ := deg_to_rad(float(plan.get("champ", REJEU_CHAMP))) * 0.5 * 16.0 / 9.0
	var gene := 0.0
	for p: Vector3 in places:
		var rel := Vector2(p.x - camera.x, p.z - camera.z)
		var loin := rel.dot(regard)
		if loin <= 0.3: continue
		var travers := absf(rel.x * regard.y - rel.y * regard.x)
		# Devant le ballon (au moins 1,5 m avant lui) et sur la ligne de visée : le marqueur est caché.
		if loin < portee - 1.5 and travers < REJEU_CARRURE + loin / portee:
			gene += 4.0 / maxf(loin, 1.0)
		# Tout près de l'objectif et dans le champ : un corps en gros plan.
		if loin < REJEU_PRES and atan2(travers, loin) < demi_champ:
			gene += 3.0 / maxf(loin, 1.0)
	return gene


## Gêne des poteaux pour un plan de ralenti : un montant (pied et protection, POTEAU_CARRURE m de large)
## devant le ballon et près de la ligne de visée, ou tout près de l'objectif et dans le champ, passe au
## premier plan (19/11/2026 : pied de poteau en gros plan à l'aplati).
const POTEAU_CARRURE := 0.7
static func gene_poteaux(plan: Dictionary) -> float:
	var camera: Vector3 = plan.camera
	var vise: Vector3 = plan.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5: return 0.0
	regard /= portee
	var demi_champ := deg_to_rad(float(plan.get("champ", REJEU_CHAMP))) * 0.5 * 16.0 / 9.0
	var gene := 0.0
	for x: float in [-50.0, 50.0]:
		for z: float in [-POTEAUX_Z, POTEAUX_Z]:
			var rel := Vector2(x - camera.x, z - camera.z)
			var loin := rel.dot(regard)
			if loin <= 0.3: continue
			var travers := absf(rel.x * regard.y - rel.y * regard.x)
			if loin < portee - 0.5 and travers < POTEAU_CARRURE + loin / portee:
				gene += 4.0 / maxf(loin, 1.0)
			if loin < REJEU_PRES and atan2(travers, loin) < demi_champ:
				gene += 3.0 / maxf(loin, 1.0)
	return gene


## Marqueur masqué à un instant du ralenti (verdict, pas une gêne) : un montant, protection comprise
## (POTEAU_PROTECTION m de demi-largeur : la protection fait 0,42 m de côté, vue en biais 0,6 m), ou un
## joueur debout (REJEU_CARRURE) coupe le cône qui va de l'objectif au marqueur couché (REJEU_CORPS m
## de part et d'autre du ballon). Un montant juste derrière le ballon compte aussi (le corps du marqueur
## s'étend au-delà du ballon) ; un joueur à moins de 1,5 m du ballon est le marqueur ou son plaqueur.
## Caméra à 1,1 m, protection haute de 1,6 m et montant de 12 m : rien ne passe au-dessus.
## (19/11/2026 : marqueur aplati derrière la protection, angle gardé car un montant à moins de 0,5 m
## du ballon n'était pas compté et la gêne moyenne diluait l'aplati.)
const POTEAU_PROTECTION := 0.3
const REJEU_CORPS := 0.6
static func masque_rejeu(plan: Dictionary, places: PackedVector3Array) -> bool:
	var camera: Vector3 = plan.camera
	var vise: Vector3 = plan.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5: return false
	regard /= portee
	for x: float in [-50.0, 50.0]:
		for z: float in [-POTEAUX_Z, POTEAUX_Z]:
			var rel := Vector2(x - camera.x, z - camera.z)
			var loin := rel.dot(regard)
			if loin <= 0.3 or loin > portee + REJEU_CORPS: continue
			var travers := absf(rel.x * regard.y - rel.y * regard.x)
			if travers < POTEAU_PROTECTION + REJEU_CORPS * minf(loin / portee, 1.0):
				return true
	for p: Vector3 in places:
		var rel := Vector2(p.x - camera.x, p.z - camera.z)
		var loin := rel.dot(regard)
		if loin <= 0.3 or loin >= portee - 1.5: continue
		var travers := absf(rel.x * regard.y - rel.y * regard.x)
		if travers < REJEU_CARRURE + REJEU_CORPS * loin / portee:
			return true
	return false


## Premier plan d'un instant du ralenti : chaque joueur (ou montant) dans le champ à moins de
## REJEU_PREMIER_PLAN m de l'objectif compte de 0 (à cette distance) à 1 (à REJEU_TRES_PRES m ou
## moins) ; somme. Un corps à 5 m remplit déjà les deux tiers de la hauteur de l'image (champ de 30°).
const REJEU_PREMIER_PLAN := 6.5
const REJEU_TRES_PRES := 3.5
static func premier_plan_rejeu(plan: Dictionary, places: PackedVector3Array) -> float:
	var camera: Vector3 = plan.camera
	var vise: Vector3 = plan.vise
	var regard := Vector2(vise.x - camera.x, vise.z - camera.z)
	var portee := regard.length()
	if portee < 0.5: return 0.0
	regard /= portee
	var demi_champ := deg_to_rad(float(plan.get("champ", REJEU_CHAMP))) * 0.5 * 16.0 / 9.0
	var obstacles := places.duplicate()
	for x: float in [-50.0, 50.0]:
		for z: float in [-POTEAUX_Z, POTEAUX_Z]:
			obstacles.append(Vector3(x, 0.0, z))
	var somme := 0.0
	for p: Vector3 in obstacles:
		var rel := Vector2(p.x - camera.x, p.z - camera.z)
		var loin := rel.dot(regard)
		if loin <= 0.3 or loin >= minf(REJEU_PREMIER_PLAN, portee - 1.5): continue
		var travers := absf(rel.x * regard.y - rel.y * regard.x)
		# Le bord du corps (0,3 m) suffit à entrer dans l'image.
		if atan2(maxf(travers - 0.3, 0.0), loin) < demi_champ:
			somme += clampf((REJEU_PREMIER_PLAN - loin) / (REJEU_PREMIER_PLAN - REJEU_TRES_PRES), 0.0, 1.0)
	return somme


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
