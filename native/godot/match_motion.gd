extends RefCounted
## Interpolation de présentation uniquement. Les points du moteur restent intacts.

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
