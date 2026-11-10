extends RefCounted
const Club = preload("res://ui/club_views.gd")
const DIVISIONS := ["elite", "accession", "nationale"]

static func lines(app: Control, year: Dictionary, club_id: int = -1) -> Array[String]:
	var nationale: Dictionary = year.get("nationale", {})
	var result: Array[String] = []
	if nationale.is_empty(): return result
	var members: Dictionary = nationale.get("members", {})
	var movement: Dictionary = nationale.get("movement", {})
	var access: Dictionary = nationale.get("access", {})
	var boundary: Dictionary = movement.get("nationaleBoundary", year.get("movement", {}).get("nationaleBoundary", access))
	var witness: Dictionary = nationale.get("witness", {}) if nationale.get("witness") is Dictionary else {}
	var pair: Array = witness.get("pair", [])
	var score: Array = witness.get("score", [])
	if pair.size() == 2 and score.size() == 2 and (club_id < 0 or _includes(pair, club_id)):
		var date: Variant = witness.get("date")
		var caption := Club.competition_name("access-nationale", app.model)
		if date is String and not date.is_empty(): caption += " · " + Club._calendar_date(date)
		result.append("%s · %s %d – %d %s" % [caption, Club._archive_club(app, pair[0]), int(score[0]), int(score[1]), Club._archive_club(app, pair[1])])
		var winner: Variant = witness.get("winner", access.get("winner"))
		if score[0] == score[1] and winner != null:
			result.append("Vainqueur après départage · " + Club._archive_club(app, winner))
	elif club_id < 0 and access.get("status") == "ready" and access.has("fixture") and access.fixture == null:
		result.append("Aucun barrage interdivision organisé")
	for entry: Array in [["promoted", "Montée en Accession"], ["relegated", "Descente en division fédérale"], ["retained", "Maintien en Accession"]]:
		var names: Array[String] = []
		for id: Variant in boundary.get(entry[0], []):
			if club_id < 0 or int(id) == club_id: names.append(Club._archive_club(app, id))
		if not names.is_empty(): result.append(entry[1] + " · " + ", ".join(names))
	if club_id < 0:
		var counts: Array[String] = []
		for id: String in DIVISIONS:
			if members.get(id) is Array: counts.append("%s %d" % [Club.competition_name(id, app.model), members[id].size()])
		if not counts.is_empty(): result.append("Clubs de la saison · " + " · ".join(counts))
	elif _includes(members.get("nationale", []), club_id) or _includes(movement.get("nationale", []), club_id):
		for id: String in DIVISIONS:
			if _includes(movement.get(id, []), club_id):
				result.append("Division suivante · " + Club.competition_name(id, app.model))
				break
	return result

static func _includes(ids: Array, club_id: int) -> bool:
	return ids.any(func(id: Variant): return int(id) == club_id)
