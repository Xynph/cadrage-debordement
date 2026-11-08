extends RefCounted
## Indice de proximité visuelle, jamais identité de plaqueur ni résultat sportif.
## Les racines restent sur leurs trajectoires. Aucun timer de choc ne se rejoue.

const MAX_DISTANCE := 2.6

static func plan(scene: Dictionary) -> Dictionary:
	if str(scene.get("kind", "")) not in ["carry", "turnover"]:
		return {}
	var ball: Dictionary = scene.get("ball", {})
	if not _point_valid(ball) or int(scene.get("possession", -1)) not in [0, 1]:
		return {}
	var carrier: Dictionary = {}
	var players: Array = scene.get("players", [])
	for player: Dictionary in players:
		if _player_valid(player) and player.get("featured", false) and int(player.side) == int(scene.possession):
			# Several highlighted possessors would not identify a unique carrier.
			if not carrier.is_empty(): return {}
			carrier = player
	if carrier.is_empty() or _point(carrier).distance_to(_point(ball)) > 0.5:
		return {}
	var opponent := ""
	var nearest := MAX_DISTANCE
	for player: Dictionary in players:
		if not _player_valid(player) or int(player.side) == int(carrier.side): continue
		var distance := _point(carrier).distance_to(_point(player))
		var id := str(player.id)
		if distance < nearest or (is_equal_approx(distance, nearest) and (opponent.is_empty() or id < opponent)):
			nearest = distance
			opponent = id
	return {} if opponent.is_empty() else {"carrier": str(carrier.id), "opponent": opponent}

static func strength(carrier: Vector3, opponent: Vector3) -> float:
	var displacement := opponent - carrier
	displacement.y = 0.0
	var distance := displacement.length()
	# Exact coincidence is a schematic overlap, not evidence of a collision.
	return smoothstep(0.42, 0.72, distance) * (1.0 - smoothstep(1.05, MAX_DISTANCE, distance))

static func _point_valid(point: Dictionary) -> bool:
	return point.has("x") and point.has("y") and is_finite(float(point.x)) and is_finite(float(point.y))

static func _player_valid(player: Dictionary) -> bool:
	return not str(player.get("id", "")).is_empty() and int(player.get("side", -1)) in [0, 1] and _point_valid(player)

static func _point(point: Dictionary) -> Vector2:
	return Vector2(float(point.x), float(point.y))
