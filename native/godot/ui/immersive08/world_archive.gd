extends RefCounted
const Club = preload("res://ui/club_views.gd")
const SHORT_NAMES := {"elite":"Élite","accession":"Accession","prem":"PREM","urc":"URC","srp":"SRP","champions":"Champions","challenge":"Challenge"}

static func short_name(id: String, full_name: String) -> String:
	return str(SHORT_NAMES.get(id,full_name))

static func preparation_note(preparation: Dictionary) -> String:
	var date := Club._calendar_date(str(preparation.get("nextDate","")))
	var weeks := int(preparation.get("weeksUntil",0))
	return "Prochain match le %s · %d semaine%s" % [date,weeks,"s" if weeks>1 else ""]

static func name_for(model: Dictionary, id: String) -> String:
	var fallback := "Championnat" if id.is_empty() else Club.competition_name(id)
	for competition: Dictionary in model.get("leagues",[]):
		if competition.get("id") == id: return str(competition.get("name",fallback))
	return fallback

static func titles(year: Dictionary) -> Array:
	# Le lecteur Monde fournit déjà la projection commune des titres.
	var club_views: GDScript = Club
	if club_views.has_method("archive_titles"): return club_views.call("archive_titles",year)
	var champions: Variant = year.get("champions",[])
	if champions is Array: return champions
	return []

static func club_seasons(model: Dictionary, club_id: int) -> Array:
	var years: Array = []
	for archive: Dictionary in model.get("archives",{}).get("seasons",[]):
		var year := {"season":int(archive.get("season",0)), "league_id":"", "rank":null, "division_size":null, "titles":[], "promoted":false, "relegated":false}
		var standings: Dictionary = archive.get("standings",{})
		for id: String in standings:
			var table: Array = standings[id]
			for index in table.size():
				if int(table[index]) != club_id: continue
				year.league_id = id
				year.rank = index+1
				year.division_size = table.size()
				break
		for title: Dictionary in titles(archive):
			if title.get("clubId") != null and int(title.clubId) == club_id: year.titles.append(str(title.leagueId))
		var movement: Variant = archive.get("movement")
		if movement is Dictionary:
			year.promoted = movement.get("promoted",[]).any(func(id: Variant): return int(id)==club_id)
			year.relegated = movement.get("relegated",[]).any(func(id: Variant): return int(id)==club_id)
		if year.rank != null or not year.titles.is_empty() or year.promoted or year.relegated: years.append(year)
	years.sort_custom(func(a: Dictionary,b: Dictionary): return a.season>b.season)
	return years
