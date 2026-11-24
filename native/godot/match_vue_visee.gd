extends RefCounted
## Bornes de visée, contournement des poteaux et regroupement cadré de la caméra du match 3D.
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde tout l'état ;
## découpées de match_view.gd le 24/11/2026 sans changement de comportement.

## Poteaux de but (montants en x = ±POTEAUX_X, z = ±POTEAUX_Z, hauts de POTEAU_HAUT m, barre à
## BARRE_Y m) : la caméra au contact pivote autour du point visé (jusqu'à CONTOURNEMENT_MAX rad, par
## pas de CONTOURNEMENT_PAS) quand un montant ou la barre, élargi de POTEAU_MARGE m, passe entre elle
## et l'action. Le pivot est amorti (pas d'à-coup) et revient à zéro dès que la vue est dégagée.
const POTEAUX_X := 50.0
const POTEAUX_Z := 2.8
const POTEAU_HAUT := 12.0
const BARRE_Y := 3.0
const POTEAU_MARGE := 0.6
const CONTOURNEMENT_MAX := 0.7
const CONTOURNEMENT_PAS := 0.05


## Pivot des gestes (caméra TV) : jamais plus de PIVOT_MAX rad autour de la direction de suivi, et
## rendu progressivement nul près d'une ligne de ballon mort (|x| de PIVOT_DEBUT à PIVOT_FIN) quand il
## tourne la vue vers le bout du terrain : un essai dans un coin ne montre pas la tribune.
const PIVOT_MAX := 0.2
const PIVOT_DEBUT := 25.0
const PIVOT_FIN := 42.0
## Point visé pendant un geste : dans l'aire de jeu, à |x| <= VISEE_GESTE.x et |z| <= VISEE_GESTE.y.
const VISEE_GESTE := Vector2(47.0, 28.0)


static func borner_pivot(look: Vector3, offset: Vector3, suivi: Vector3) -> Vector3:
	var avant := Vector2(suivi.x, suivi.z)
	var apres := Vector2(offset.x, offset.z)
	if avant.length() < 0.001 or apres.length() < 0.001:
		return offset
	# Angle de lacet autour de l'axe vertical (même sens que Vector3.rotated(Vector3.UP, angle)).
	var angle := wrapf(atan2(apres.x, apres.y) - atan2(avant.x, avant.y), -PI, PI)
	var permis := clampf(angle, -PIVOT_MAX, PIVOT_MAX)
	# La caméra regarde vers -offset : vers le bout du terrain le plus proche du point visé ?
	if -offset.x * look.x > 0.0:
		permis *= 1.0 - smoothstep(PIVOT_DEBUT, PIVOT_FIN, absf(look.x))
	if absf(permis - angle) < 0.00001:
		return offset
	return suivi.normalized().rotated(Vector3.UP, permis) * offset.length()


## Caméra au contact, en permanence : point visé à |x| <= VISEE_CONTACT.x et |z| <= VISEE_CONTACT.y.
const VISEE_CONTACT := Vector2(47.0, 30.0)


static func borner_visee(look: Vector3, limites: Vector2 = VISEE_GESTE) -> Vector3:
	return Vector3(borne_douce(look.x, limites.x), look.y, borne_douce(look.z, limites.y))


## Borne sans à-coup : identité jusqu'à `limite - VISEE_GENOU`, puis approche progressive de la limite
## (vitesse continue) ; un ballon qui file vers le coin ne fait pas s'arrêter net le point visé.
const VISEE_GENOU := 5.0
static func borne_douce(valeur: float, limite: float) -> float:
	var debut := limite - VISEE_GENOU
	if absf(valeur) <= debut:
		return valeur
	return signf(valeur) * (debut + VISEE_GENOU * tanh((absf(valeur) - debut) / VISEE_GENOU))


## Un montant ou la barre des poteaux (élargis de POTEAU_MARGE) coupe le segment `depart` -> `arrivee`.
static func poteau_entre(depart: Vector3, arrivee: Vector3, m: float = POTEAU_MARGE) -> bool:
	for x in [-POTEAUX_X, POTEAUX_X]:
		var boites: Array[AABB] = [
			AABB(Vector3(x - m, 0.0, -POTEAUX_Z - m), Vector3(2.0 * m, POTEAU_HAUT + m, 2.0 * m)),
			AABB(Vector3(x - m, 0.0, POTEAUX_Z - m), Vector3(2.0 * m, POTEAU_HAUT + m, 2.0 * m)),
			AABB(Vector3(x - m, BARRE_Y - m, -POTEAUX_Z - m), Vector3(2.0 * m, 2.0 * m, 2.0 * POTEAUX_Z + 2.0 * m)),
		]
		for boite: AABB in boites:
			if boite.intersects_segment(depart, arrivee) != null:
				return true
	return false


## Cibles que la caméra au contact doit voir : le point visé (à hauteur d'homme) et le ballon.
static func _cibles_camera(v: NativeMatchView, look: Vector3) -> Array[Vector3]:
	var cibles: Array[Vector3] = [Vector3(look.x, 1.0, look.z)]
	if is_instance_valid(v._ball) and v._ball.visible:
		cibles.append(v._ball.global_position)
	return cibles


## Un poteau masque une des cibles pour la caméra posée sur `look` dans la direction `offset`.
static func poteau_masque(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, marge: float = POTEAU_MARGE) -> bool:
	var camera: Vector3 = v.pose_camera(look, size, offset)[0]
	for cible: Vector3 in _cibles_camera(v, look):
		if poteau_entre(camera, cible, marge):
			return true
	return false


## Plus petit pivot (rad) qui dégage la vue des poteaux ; le sens déjà pris est essayé d'abord. Une
## caméra déjà tournée ne revient que si la vue d'origine est dégagée avec POTEAU_RELACHE m de marge
## (hystérésis : pas d'aller-retour quand le point visé glisse un peu en tournant).
const POTEAU_RELACHE := 1.5
## 19 novembre 2026 (nuit) : touche près de l'en-but en TV (pivot des gestes compris), la caméra se
## posait entre les poteaux et un montant blanc, protection comprise, couvrait le tiers droit de l'image.
## Le contournement vaut aussi pour la TV ; la caméra TV ne contourne que le premier plan (un montant
## au loin, derrière l'action, est une image de retransmission normale). En TV, le premier sens essayé
## ramène la caméra vers le milieu du terrain (le pivot des gestes est défait d'abord).
static func contournement_poteaux(v: NativeMatchView, look: Vector3, size: float, offset: Vector3) -> float:
	# Loin des poteaux : rien à chercher (coût nul la plupart du temps).
	if absf(absf(look.x) - POTEAUX_X) > 40.0:
		return 0.0
	var tourne := absf(v._contournement) > 0.01
	var marge := POTEAU_RELACHE if tourne else POTEAU_MARGE
	var relache := POTEAU_RELACHE if tourne else 0.0
	if not _poteau_gene(v, look, size, offset, marge, relache, true):
		return 0.0
	var sens := -1.0 if v._contournement < 0.0 else 1.0
	if not tourne and v._camera_mode != "action":
		# offset.rotated(UP, a) déplace la caméra en x de offset.z * a : vers le milieu d'abord.
		sens = -1.0 if look.x * offset.z > 0.0 else 1.0
	var pas := int(round(CONTOURNEMENT_MAX / CONTOURNEMENT_PAS))
	# D'abord ni masque ni premier plan ; sinon (caméra au contact) au moins rien entre elle et l'action.
	for complet: bool in [true, false]:
		if not complet and v._camera_mode != "action":
			break
		for k in range(1, pas + 1):
			for signe: float in [sens, -sens]:
				var angle := signe * k * CONTOURNEMENT_PAS
				if not _poteau_gene(v, look, size, offset.rotated(Vector3.UP, angle), marge, relache, complet):
					return angle
	return sens * CONTOURNEMENT_MAX


## Gêne d'un poteau pour la caméra suivie : masque l'action (caméra au contact seulement) ou, si
## `premier_plan`, montant ou barre au premier plan (poteau_premier_plan).
static func _poteau_gene(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, marge: float, relache: float, premier_plan: bool) -> bool:
	if v._camera_mode == "action" and poteau_masque(v, look, size, offset, marge):
		return true
	return premier_plan and poteau_premier_plan(v, look, size, offset, relache)


## Montant ou barre des poteaux au premier plan : une partie (protection de 0,42 m de côté, POTEAU_DEMI m
## de demi-largeur) dans l'image, devant la caméra, assez près pour couvrir plus de POTEAU_PREMIER_PLAN
## de la largeur de l'image (TV : à moins de 7 m environ ; contact : 4,5 m). Film du 19/11 : 16 % à 3,4 m.
## Un montant à 12 m devant la caméra TV, entre elle et un essai sous les poteaux (4,6 %), est une image
## de retransmission normale : pas de contournement. `relache` (m) élargit le montant et allonge la
## distance (hystérésis du contournement).
const POTEAU_DEMI := 0.21
const POTEAU_PREMIER_PLAN := 0.08
static func poteau_premier_plan(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, relache: float = 0.0) -> bool:
	var pose := v.pose_camera(look, size, offset)
	var camera: Vector3 = pose[0]
	var pente := tan(deg_to_rad(float(pose[1]) * 0.5))
	var ecran := v.get_viewport().get_visible_rect().size if v.is_inside_tree() else Vector2(16.0, 9.0)
	var pente_large := pente * (ecran.x / ecran.y if ecran.y > 0.0 else 16.0 / 9.0)
	var limite := POTEAU_DEMI / (POTEAU_PREMIER_PLAN * pente_large) + 2.0 * relache
	var demi := POTEAU_DEMI + relache
	var inverse := Basis.looking_at(-offset, Vector3.UP).inverse()
	for x: float in [-POTEAUX_X, POTEAUX_X]:
		# Loin de cette ligne de but : rien au premier plan.
		if absf(camera.x - x) > limite + POTEAUX_Z:
			continue
		var points: Array[Vector3] = []
		for z: float in [-POTEAUX_Z, POTEAUX_Z]:
			for h in int(POTEAU_HAUT) + 1:
				points.append(Vector3(x, float(h), z))
		for i in 9:
			points.append(Vector3(x, BARRE_Y, lerpf(-POTEAUX_Z, POTEAUX_Z, i / 8.0)))
		for point: Vector3 in points:
			var local := inverse * (point - camera)
			var profondeur := -local.z
			if profondeur <= 0.3 or profondeur >= limite:
				continue
			if absf(local.x) - demi <= profondeur * pente_large and absf(local.y) - demi <= profondeur * pente:
				return true
	return false


## Regroupement en cours (mêlée, touche, ruck) : places du paquet et des demis, pour un cadrage serré
## sur lui plutôt que sur les arrières écartés. Vide hors regroupement.
static func regroupement(v: NativeMatchView) -> Array[Vector3]:
	var ids: Array = []
	var formation: Dictionary = v._formations.formation if v._formations and v._formations.active() else {}
	var roles: Dictionary = formation.get("roles", {})
	var retenus: Array = []
	match str(formation.get("type", "")):
		"melee", "sortie_melee":
			retenus = ["pack", "demi_intro", "demi_adverse", "demi_sortie"]
		"touche":
			retenus = ["lanceur", "alignement", "sauteur", "demi"]
	for id: String in roles:
		if roles[id] in retenus:
			ids.append(id)
	if ids.is_empty() and not v._impacts.ruck.is_empty():
		ids = v._impacts.ruck.keys()
		for autre: String in [v._impacts.porteur, v._impacts.plaqueur]:
			if not autre.is_empty() and autre not in ids:
				ids.append(autre)
	var centre := v._ball.global_position if v._ball.visible else v._camera_focus
	var places: Array[Vector3] = []
	for id: String in ids:
		if v._actors.has(id):
			var place: Vector3 = (v._actors[id].node as Node3D).position
			# Un demi resté loin (touche) ne fait pas partie du regroupement.
			if Vector2(place.x - centre.x, place.z - centre.z).length() <= 18.0:
				places.append(Vector3(place.x, 0.0, place.z))
	return places
