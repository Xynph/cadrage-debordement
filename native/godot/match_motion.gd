extends RefCounted
## Interpolation de présentation uniquement. Les points du moteur restent intacts.

## Durée la plus courte d'un déplacement (petit ajustement de place), en secondes.
const DUREE_MIN := 0.55
## Allure de pointe à l'écran, en m/s : un sprint d'ailier, jamais plus (même plafond que
## les mises en place des gestes, match_gestes.gd PACE_BACK).
const ALLURE_MAX := 7.5
## Au-delà de ce trajet (m), un joueur n'est plus montré en train de courir : il est replacé
## pendant une coupe (match_view.gd), ou hors champ s'il n'est pas à l'image.
const TRAJET_REPLACEMENT := 22.0
## Derniers pas d'un joueur replacé : il réapparaît à cette distance de sa place, en m.
const DERNIERS_PAS := 1.2

## Durée du trajet `from` -> `target` pour que l'allure de pointe ne dépasse jamais ALLURE_MAX :
## la courbe de position_at culmine à (1 + 0,5 × poids de foulée) fois l'allure moyenne.
static func duree(from: Vector3, target: Vector3) -> float:
	var distance := Vector2(target.x - from.x, target.z - from.z).length()
	return maxf(DUREE_MIN, distance * (1.0 + 0.5 * _stride_weight(from, target)) / ALLURE_MAX)

static func tangent(velocity: Vector3, displacement: Vector3, duration: float) -> Vector3:
	# A bounded Hermite tangent preserves a continuing stride without overshooting
	# an authored endpoint. An axis reversal brakes before changing support.
	var result := velocity * duration
	for axis in 3:
		var limit := displacement[axis]
		result[axis] = clampf(result[axis], minf(0.0, limit * 2.0), maxf(0.0, limit * 2.0))
	return result

static func position_at(from: Vector3, target: Vector3, initial: Vector3, progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var weight := _stride_weight(from, target)
	return from + (target - from) * lerpf(t, t * t * (3.0 - 2.0 * t), weight) + initial * (t * (1.0 - t) * (1.0 - t) * weight)

static func velocity_at(from: Vector3, target: Vector3, initial: Vector3, progress: float, duration: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	if t >= 1.0:
		return Vector3.ZERO
	var weight := _stride_weight(from, target)
	return ((target - from) * lerpf(1.0, 6.0 * t * (1.0 - t), weight) + initial * (1.0 - 4.0 * t + 3.0 * t * t) * weight) / duration

static func _stride_weight(from: Vector3, target: Vector3) -> float:
	# Sparse scenes can reform a whole team across the pitch. Such a transition
	# is not an athletic sprint: avoid an extra speed peak and camera lurch.
	return clampf((20.0 - from.distance_to(target)) / 12.0, 0.0, 1.0)
