extends RefCounted
## Présentation calculée depuis le modèle reçu ; aucune commande ou état global.
const Club = preload("res://ui/club_views.gd")
const G = preload("res://ui/game_skin.gd")

static func fixture_date(fixture: Dictionary) -> String:
	var date: Variant = fixture.get("date")
	return Club._calendar_date(date) if date is String else ""

static func fixture_venue(fixture: Dictionary) -> String:
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary: venue = venue.get("name")
	if venue is String and not venue.is_empty() and venue.to_lower() not in ["home","away","neutral"]: return venue
	if fixture.get("neutral",false): return "Terrain neutre"
	var home: Dictionary = fixture.get("home",{})
	return str(G.identity(home).get("stadium",home.get("stadium","")))

static func group(model: Dictionary) -> Dictionary:
	var squad: Array = model.get("squad", [])
	var injured := 0
	var condition := 0.0
	var rating := 0.0
	var watched := 0
	for player: Dictionary in squad:
		if float(player.get("injury", 0)) > 0: injured += 1
		condition += float(player.get("condition", 0))
		rating += float(player.get("rating", 0))
		if float(player.get("physicalLoad", 0)) >= 70 or float(player.get("condition", 100)) < 80: watched += 1
	return {"total":squad.size(), "available":squad.size()-injured, "injured":injured, "condition":roundi(condition/maxi(1,squad.size())), "rating":roundi(rating/maxi(1,squad.size())), "watched":watched}

static func contracts(model: Dictionary) -> Array:
	var result: Array = []
	for player: Dictionary in model.get("squad", []):
		if player.get("contractEnd") != null and int(player.contractEnd) <= int(model.get("meta", {}).get("season", 1)) + 1: result.append(player)
	return result

static func standings(model: Dictionary) -> Array:
	var rows: Array = model.get("league", [])
	for league: Dictionary in model.get("leagues", []):
		if league.get("id") == model.get("meta", {}).get("leagueId"): rows = league.get("rows", [])
	var own := 0
	for index in rows.size():
		if rows[index].get("id") == model.get("club", {}).get("id"): own = index; break
	return rows.slice(clampi(own-2,0,maxi(0,rows.size()-6)), clampi(own-2,0,maxi(0,rows.size()-6))+6)

static func league_name(model: Dictionary) -> String:
	for league: Dictionary in model.get("leagues", []):
		if league.get("id") == model.get("meta", {}).get("leagueId"): return str(league.get("name", "Championnat"))
	return "Championnat"

static func upcoming(model: Dictionary, limit: int = 7) -> Array:
	var result: Array = []
	for fixture: Dictionary in model.get("calendar", []):
		if not fixture.get("played", false) and int(fixture.get("week", 0)) >= int(model.get("meta", {}).get("week", 0)): result.append(fixture)
	result.sort_custom(func(first: Dictionary, second: Dictionary): return int(first.get("week", 0)) < int(second.get("week", 0)))
	return result.slice(0, limit)

static func player(model: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in model.get("squad", []):
		if str(person.get("id", "")) == id: return person
	return {}

static func safe_accent(color: Color) -> Color:
	var result := color
	while result.get_luminance() < .20: result = result.lightened(.10)
	return result
