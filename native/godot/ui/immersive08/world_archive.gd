extends RefCounted
const Club = preload("res://ui/club_views.gd")
static func short_name(id: String, full_name: String, model: Dictionary = {}) -> String:
	return str(model.get("meta", {}).get("competitionIdentities", {}).get(id, {}).get("shortName", full_name))

static func preparation_note(preparation: Dictionary) -> String:
	var date := Club._calendar_date(str(preparation.get("nextDate","")))
	var weeks := int(preparation.get("weeksUntil",0))
	return "Prochain match le %s · %d semaine%s" % [date,weeks,"s" if weeks>1 else ""]

static func name_for(model: Dictionary, id: String) -> String:
	var fallback := "Championnat" if id.is_empty() else Club.competition_name(id, model)
	for competition: Dictionary in model.get("leagues",[]):
		if competition.get("id") == id: return str(competition.get("name",fallback))
	return fallback

# Division d'arrivée d'une montée ou d'une descente : le nom vient des données (pack compris), jamais du code.
const PROMOTION := {"accession":"elite", "nationale":"accession", "champ":"prem", "jlo-d2":"jlo-d1"}
const RELEGATION := {"elite":"accession", "accession":"nationale", "prem":"champ", "jlo-d1":"jlo-d2"}

static func movement_lines(model: Dictionary, league_id: String, promoted: bool, relegated: bool) -> Array[String]:
	var lines: Array[String] = []
	if promoted: lines.append("Montée en " + name_for(model, PROMOTION[league_id]) if PROMOTION.has(league_id) else "Montée en division supérieure")
	if relegated: lines.append("Descente en " + name_for(model, RELEGATION[league_id]) if RELEGATION.has(league_id) else "Descente en division inférieure")
	return lines

static func titles(year: Dictionary) -> Array:
	# Le lecteur Monde fournit déjà la projection commune des titres.
	var club_views: GDScript = Club
	if club_views.has_method("archive_titles"): return club_views.call("archive_titles",year)
	var champions: Variant = year.get("champions",[])
	if champions is Array: return champions
	return []

static func japan_barrages(year: Dictionary, club_id: int = -1) -> Array:
	var results: Array = []
	var japan: Variant = year.get("japan")
	if not japan is Dictionary: return results
	var pairs: Array = japan.get("pairs",[])
	var legs: Array = japan.get("legs",[])
	var outcomes: Array = japan.get("outcomes",[])
	for index in mini(pairs.size(),outcomes.size()):
		var pair: Dictionary = pairs[index]
		if not outcomes[index] is Dictionary: continue
		if club_id >= 0 and club_id not in [int(pair.upperId),int(pair.lowerId)]: continue
		var prefix := str(pair.id) + ":"
		var matches := legs.filter(func(leg: Dictionary): return str(leg.fixtureId).begins_with(prefix))
		matches.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.fixtureId) < str(b.fixtureId))
		results.append({"pair":pair,"legs":matches,"outcome":outcomes[index]})
	return results

## Nom publié par les données de la compétition (identités du modèle) ; vide si la donnée manque : aucun nom figé dans le code.
static func published_name(model: Dictionary, id: String) -> String:
	return str(model.get("meta", {}).get("competitionIdentities", {}).get(id, {}).get("name", "")).strip_edges()

## Lignes d'un barrage japonais. Les noms des compétitions viennent des données ; sans nom publié, la ligne qui en dépend est omise.
static func japan_lines(app: Control, barrage: Dictionary) -> Array[String]:
	var pair: Dictionary = barrage.pair
	var outcome: Dictionary = barrage.outcome
	var lines: Array[String] = []
	var title := published_name(app.model, "jlo-d1-d2")
	if not title.is_empty():
		lines.append("%s · %s – %s" % [title,Club._archive_club(app,pair.upperId),Club._archive_club(app,pair.lowerId)])
	for i in barrage.legs.size():
		var leg: Dictionary = barrage.legs[i]
		lines.append("Manche %d · %s %d – %d %s" % [i+1,Club._archive_club(app,leg.pair[0]),int(leg.score[0]),int(leg.score[1]),Club._archive_club(app,leg.pair[1])])
	var upper_name := published_name(app.model, "jlo-d1")
	var lower_name := published_name(app.model, "jlo-d2")
	if not upper_name.is_empty() and not lower_name.is_empty():
		var upper := Club._archive_club(app,outcome.upperNext)
		var lower := Club._archive_club(app,outcome.lowerNext)
		if outcome.promoted:
			lines.append("Montée · %s · %s  /  Descente · %s · %s" % [upper_name,upper,lower_name,lower])
		else:
			lines.append("Maintien · %s · %s  /  Maintien · %s · %s" % [upper_name,upper,lower_name,lower])
	return lines

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
		year.japan_barrages = japan_barrages(archive,club_id)
		if year.rank != null or not year.titles.is_empty() or year.promoted or year.relegated or not year.japan_barrages.is_empty(): years.append(year)
	years.sort_custom(func(a: Dictionary,b: Dictionary): return a.season>b.season)
	return years
