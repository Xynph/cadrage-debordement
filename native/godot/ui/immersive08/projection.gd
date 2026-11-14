extends RefCounted
## Présentation calculée depuis le modèle reçu ; aucune commande ou état global.
const Club = preload("res://ui/club_views.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

## Classement ouvert = au moins un match joué dans la division. Avant la 1re journée, tous les clubs sont à 0 point
## et leur « rang » n'est qu'un ordre d'identifiant : l'interface n'en fait pas un classement.
static func standings_open(club: Dictionary) -> bool:
	if club.has("standingsOpen"): return bool(club.get("standingsOpen"))
	if club.has("played"): return int(club.get("played", 0)) > 0
	return true

static func rank_ordinal(club: Dictionary) -> String:
	var rank: Variant = club.get("rank")
	if not standings_open(club) or not (rank is int or rank is float) or rank < 1: return "—"
	return "1er" if int(rank) == 1 else "%de" % int(rank)

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

## Prochaine rencontre du club, avant-saison comprise : une seule définition pour le Bureau, la Tactique,
## l'Entraînement, la Préparation et les Compétitions. Le moteur désigne la rencontre (figures.nextFixtureId) ;
## à défaut, la rencontre à préparer (model.next), puis la première rencontre non jouée du calendrier.
static func next_fixture(model: Dictionary) -> Dictionary:
	var next: Variant = model.get("next")
	if next is Dictionary and not next.is_empty(): return next
	var figures: Variant = model.get("figures")
	var wanted := str(figures.get("nextFixtureId","")) if figures is Dictionary and figures.get("nextFixtureId") != null else ""
	if not wanted.is_empty():
		for fixture: Dictionary in model.get("calendar", []):
			if str(fixture.get("id","")) == wanted and not fixture.get("played", false): return fixture
	return next_scheduled_fixture(model)

## Intitulé court de la rencontre pour les bandeaux (adversaire, lieu, journée), jamais « aucune » si le calendrier en publie une.
static func next_fixture_caption(model: Dictionary, empty_text: String) -> String:
	var fixture := next_fixture(model)
	if fixture.is_empty(): return empty_text
	return G.club_name(fixture.get("home",{})) + " – " + G.club_name(fixture.get("away",{})) + " · " + str(fixture.get("label",""))

static func plural(count: int, one: String, many: String) -> String:
	return "%d %s" % [count, one if absi(count) <= 1 else many]

## Masses salariales : trois mesures distinctes, lues au même endroit (engine : figures.payroll).
##   players_weekly : salaires des contrats (base 52 semaines) ; charge_weekly : versé sur la saison, cotisations comprises.
static func payroll(model: Dictionary) -> Dictionary:
	var figures: Variant = model.get("figures")
	var source: Variant = figures.get("payroll") if figures is Dictionary else null
	if source is Dictionary and source.has("joueursHebdo"):
		return {"players_weekly": float(source.joueursHebdo), "paid_weekly": float(source.get("verseHebdo", source.joueursHebdo)),
			"charge_weekly": float(source.get("chargeHebdo", source.joueursHebdo)), "weeks": int(source.get("semainesDePaie", 0)),
			"contributions": float(source.get("tauxCotisations", 0.0))}
	var total := 0.0
	for player: Dictionary in model.get("squad", []): total += float(player.get("salary", 0))
	return {"players_weekly": total, "paid_weekly": total, "charge_weekly": total, "weeks": 0, "contributions": 0.0}

## Échéances de contrat : fin de saison (contractEnd <= saison) et horizon (jusqu'à la fin de la saison suivante).
static func contract_counts(model: Dictionary) -> Dictionary:
	var season := int(model.get("meta", {}).get("season", 1))
	var ending := contracts_ending(model)
	return {"end_of_season": ending.size(), "by_horizon": contracts(model).size(), "horizon_season": season + 1}

static func contracts_ending(model: Dictionary) -> Array:
	var result: Array = []
	var season := int(model.get("meta", {}).get("season", 1))
	for player: Dictionary in model.get("squad", []):
		if player.get("contractEnd") != null and int(player.contractEnd) <= season: result.append(player)
	return result

static func fixture_venue(fixture: Dictionary, neutral_fallback: bool = true, home_fallback: bool = true) -> String:
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary: venue = venue.get("name")
	if venue is String and not venue.is_empty() and venue.to_lower() not in ["home","away","neutral"]: return venue
	if fixture.get("neutral",false): return "Terrain neutre" if neutral_fallback else ""
	if not home_fallback: return ""
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
	var rated := 0
	var watched := 0
	for player: Dictionary in squad:
		if float(player.get("injury", 0)) > 0: injured += 1
		condition += float(player.get("condition", 0))
		var level := G.knowledge_bounds(player,"rating",true)
		if not level.is_empty() and level.min == level.max:
			rating += float(level.min)
			rated += 1
		if not U.watch_reason(player).is_empty(): watched += 1
	return {"total":squad.size(), "available":squad.size()-injured, "injured":injured, "condition":roundi(condition/maxi(1,squad.size())), "rating":roundi(rating/squad.size()) if not squad.is_empty() and rated == squad.size() else "—", "watched":watched}

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

static func lineup_condition(model: Dictionary) -> String:
	var total := 0.0
	var starters := 0
	for assignment: Dictionary in model.get("selection", {}).get("slots", []):
		var slot := int(assignment.get("slot", -1))
		if slot < 0 or slot >= 15: continue
		var person := player(model, str(assignment.get("playerId", "")))
		var condition: Variant = person.get("condition")
		if condition is not float and condition is not int: continue
		total += float(condition)
		starters += 1
	if starters == 0: return "—"
	var caption := "%d %%" % roundi(total / starters)
	if starters < 15: caption += " (%d/15)" % starters
	return caption

static func player_in_recovery(model: Dictionary, id: String) -> bool:
	var medical: Array = model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", [])
	return medical.any(func(record: Dictionary): return record.get("id") == id and record.get("stage") == "reprise")

static func safe_accent(color: Color) -> Color:
	var result := color
	while result.get_luminance() < .20: result = result.lightened(.10)
	return result
