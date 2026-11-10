extends RefCounted
## Présentation calculée depuis le modèle reçu ; aucune commande ou état global.
const Club = preload("res://ui/club_views.gd")
const G = preload("res://ui/game_skin.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

static func fixture_date(fixture: Dictionary, show_timezone: bool = false) -> String:
	var date: Variant = fixture.get("date")
	if not date is String or date.is_empty(): return ""
	var caption := Club._calendar_date(date)
	var local_time: Variant = fixture.get("kickoffLocal")
	if local_time is String and not local_time.is_empty():
		caption += " · " + local_time
		if show_timezone and fixture.get("timezone") == "Europe/London": caption += " (heure locale)"
	return caption

static func fixture_ground(meta: Dictionary, fallback: String) -> String:
	if meta.get("leagueId") == "nationale": return "nationale-ground"
	return SeasonPreparation.ground(meta, fallback)

static func next_nationale_fixture(model: Dictionary) -> Dictionary:
	if model.get("meta", {}).get("leagueId") != "nationale": return {}
	return next_scheduled_fixture(model)

static func next_scheduled_fixture(model: Dictionary) -> Dictionary:
	var week := int(model.get("meta", {}).get("week", 0))
	for fixture: Dictionary in model.get("calendar", []):
		if not fixture.get("played", false) and int(fixture.get("week", 0)) > week: return fixture
	return {}

static func fixture_venue(fixture: Dictionary, neutral_fallback: bool = true) -> String:
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary: venue = venue.get("name")
	if venue is String and not venue.is_empty() and venue.to_lower() not in ["home","away","neutral"]: return venue
	if fixture.get("neutral",false): return "Terrain neutre" if neutral_fallback else ""
	var home: Dictionary = fixture.get("home",{})
	var stadium: Variant = G.identity(home).get("stadium",home.get("stadium"))
	return stadium if stadium is String else ""

static func fixture_location_kind(fixture: Dictionary, club_id: Variant) -> String:
	if fixture.get("neutral", false): return "neutral"
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary:
		if venue.get("neutral", false): return "neutral"
		venue = venue.get("kind", "")
	if venue is String and venue.to_lower() in ["home", "away", "neutral"]: return venue.to_lower()
	if club_id != null and fixture.get("home", {}).get("id") == club_id: return "home"
	if club_id != null and fixture.get("away", {}).get("id") == club_id: return "away"
	return ""

static func fixture_position(fixture: Dictionary, club_id: Variant) -> String:
	if fixture.get("neutral",false): return "TERRAIN NEUTRE"
	return "À DOMICILE" if fixture.get("home",{}).get("id")==club_id else "À L’EXTÉRIEUR"

static func reduced_bench_number(model: Dictionary) -> int:
	var selection: Variant = model.get("selection")
	if model.get("live") is Dictionary and not model.live.is_empty(): return 0
	if not model.get("next") is Dictionary or model.next.is_empty(): return 0
	if not selection is Dictionary or selection.get("valid",false): return 0
	var offer: Variant = selection.get("reducedBench")
	if not offer is Dictionary or not is_nomination_at_22(offer.get("size")): return 0
	var vacant: Variant = offer.get("vacantNumber")
	if not (vacant is int or vacant is float): return 0
	return int(vacant) if vacant == 17 or vacant == 18 else 0

static func is_nomination_at_22(value: Variant) -> bool:
	return (value is int or value is float) and value == 22

static func reduced_bench_vacancy(vacant: int) -> String:
	return "Pilier %s de remplacement manquant (n° %d)." % ["gauche" if vacant == 17 else "droit",vacant]

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

static func player_in_recovery(model: Dictionary, id: String) -> bool:
	var medical: Array = model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", [])
	return medical.any(func(record: Dictionary): return record.get("id") == id and record.get("stage") == "reprise")

static func safe_accent(color: Color) -> Color:
	var result := color
	while result.get_luminance() < .20: result = result.lightened(.10)
	return result
