extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Priorities = preload("res://ui/immersive08/office_priorities.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/data_semantics.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const UPCOMING_TILE = Color("26231b")
const UPCOMING_BORDER = Color("706042")

static func _live_fixture(model: Dictionary, pair: Array, include_next: bool = true) -> Dictionary:
	if pair.size() != 2: return {}
	var week := int(model.get("meta", {}).get("week", -1))
	var next: Variant = model.get("next")
	if include_next and next is Dictionary and next.get("pair", []) == pair and int(next.get("week", -2)) == week:
		return next
	var fixtures: Array = model.get("calendar", []).filter(func(fixture: Dictionary):
		return not fixture.get("played", false) and int(fixture.get("week", -2)) == week \
			and fixture.get("home", {}).get("id") == pair[0] and fixture.get("away", {}).get("id") == pair[1]
	)
	return fixtures[0] if fixtures.size() == 1 else {}

static func upcoming_matches(model: Dictionary) -> Array:
	var live: Variant = model.get("live")
	if not live is Dictionary or live.is_empty(): return P.upcoming(model)
	var current := _live_fixture(model, live.get("pair", []), false)
	var fixture_id := str(current.get("id", ""))
	if fixture_id.is_empty(): return P.upcoming(model)
	var fixtures := P.upcoming(model, 8)
	return fixtures.filter(func(fixture: Dictionary): return fixture.get("id") != fixture_id).slice(0, 7)

static func _live_status(live: Dictionary) -> Dictionary:
	var finished: bool = live.get("finished", false)
	var phase := "En jeu"
	if finished: phase = "Résultat à valider"
	elif live.get("atBreak", false): phase = "Mi-temps"
	elif live.get("paused", false): phase = "En pause"
	var state := "%s′ · %s" % [G.n(live.get("minute", 0)), phase]
	if int(live.get("nominationSize", 23)) == 22: state += " · Feuille à 22"
	var score: Array = live.get("score", [])
	return {
		"heading": "MATCH TERMINÉ" if finished else "MATCH EN COURS",
		"finished": finished,
		"state": state,
		"score": "%s – %s" % [G.n(score[0]), G.n(score[1])] if score.size() == 2 else "",
	}

static func live_match(model: Dictionary) -> Dictionary:
	var live: Variant = model.get("live")
	if not live is Dictionary or live.is_empty(): return {}
	var summary := _live_status(live)
	var fixture := _live_fixture(model, live.get("pair", []))
	var details: Array[String] = []
	for detail in [P.fixture_date(fixture, true), P.fixture_venue(fixture, false, false)]:
		if not detail.is_empty(): details.append(detail)
	summary.teams = live.get("teams", [])
	summary.detail = " · ".join(details)
	summary.location = {"neutral":"NEUTRE", "home":"À DOMICILE", "away":"À L’EXTÉRIEUR"}.get(
		P.fixture_location_kind(fixture, model.get("club", {}).get("id")), ""
	) if not fixture.is_empty() else ""
	return summary

static func update_live_card(app: Control) -> void:
	var live: Dictionary = app._live()
	if live.is_empty() or not is_instance_valid(app.root_content): return
	var card: Node = app.root_content.find_child("OfficeFixture", true, false)
	if card == null: return
	var summary := _live_status(live)
	var fields := {"heading":"OfficeLiveHeading", "score":"OfficeLiveScore", "state":"OfficeLiveState"}
	for field in fields:
		var label := card.find_child(fields[field], true, false) as Label
		if label != null: label.text = summary[field]
	var primary := card.find_child("OfficePreparationAction", true, false) as Button
	if primary != null: primary.text = app.primary_text().trim_suffix("  →")
	var review := card.find_child("OfficeMatchReviewAction", true, false) as Button
	if review != null: review.visible = summary.finished
	var priority := app.root_content.find_child("OfficeLivePriorityAction",true,false) as Button
	if priority != null:
		for item: Dictionary in priorities(app.model):
			if item.id != "OfficeLivePriorityAction": continue
			var number := int(priority.get_meta("priority_number",1))
			priority.text = "%d. %s" % [number,item.title]
			priority.tooltip_text = item.title + "\n" + priority_description(item)
			priority.accessibility_name = priority.tooltip_text.replace("\n"," · ")
			for pair in [["OfficePriorityDeadline",item.deadline],["OfficePriorityReason",item.detail]]:
				var label := app.root_content.find_child(str(pair[0])+str(number),true,false) as Label
				if label != null: label.text = pair[1]

static func _card(parent: Node, id: String, title: String, height: int, ratio: float = 1.0) -> PanelContainer:
	var frame := C.card(title, Vector2(0, height))
	frame.name = id
	C.fill(frame, true, ratio)
	parent.add_child(frame)
	return frame

static func _link(parent: Node, id: String, text: String, app: Control, route: String, primary: bool = false) -> Button:
	var action := C.button(text, func(): app._navigate(route), primary, app.accent)
	action.name = id
	parent.add_child(action)
	return action

# Old visual hosts intentionally have no controller. Keep their original
# controls instead of turning a missing destination into an inert button.
static func _reading_navigation(app: Control) -> Node:
	for field: Dictionary in app.get_property_list():
		if field.name != "navigation_controller": continue
		var navigation: Variant = app.get("navigation_controller")
		if navigation is Node and is_instance_valid(navigation) and navigation.has_method("entity_available") and navigation.has_method("open_entity"): return navigation
	return null

static func reading_available(app: Control, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var navigation := _reading_navigation(app)
	return navigation != null and navigation.entity_available(target)

static func club_reading_target(app: Control, club: Dictionary) -> Dictionary:
	if club.get("id") == null: return {}
	var target := {"kind":"club", "id":str(club.id)}
	return target if reading_available(app, target) else {}

static func date_reading_target(app: Control, fixture: Dictionary) -> Dictionary:
	var date: Variant = fixture.get("date")
	if not Agenda.valid_date(date): return {}
	var target := {"kind":"date", "id":date}
	return target if reading_available(app, target) else {}

static func score_reading_target(app: Control, fixture: Dictionary) -> Dictionary:
	var id: Variant = fixture.get("id")
	var score: Variant = fixture.get("score")
	if not id is String or id.is_empty() or not score is Array or score.size() != 2: return {}
	if S.count_text(score[0]) == "—" or S.count_text(score[1]) == "—": return {}
	var target := {"kind":"fixture", "id":id}
	if not reading_available(app, target): return {}
	# Runtime load avoids CompetitionCanvas -> Office's existing preload cycle.
	var competition = load("res://ui/immersive08/competition_canvas.gd")
	var found: Dictionary = competition._target_fixture(app, id)
	if found.is_empty() or found.get("score") != score: return {}
	for side: String in ["home", "away"]:
		var shown: Variant = fixture.get(side)
		var resolved: Variant = found.get(side)
		if not shown is Dictionary or not resolved is Dictionary or shown.get("id") == null or resolved.get("id") == null: return {}
		if str(shown.id) != str(resolved.id): return {}
	if fixture.has("date") and fixture.get("date") != found.get("date"): return {}
	if fixture.has("winner") and fixture.get("winner") != found.get("winner"): return {}
	# The common lookup rejects conflicting identities/dates. Also reject two
	# published scores for the same ID, rather than trusting the first row.
	for source: Array in [app.model.get("calendar", []), app.model.get("calendarPlanning", {}).get("fixtures", [])]:
		for candidate: Dictionary in source:
			if candidate.get("id") == id and candidate.has("score") and candidate.get("score") != score: return {}
	for result: Dictionary in app.model.get("history", []):
		if result.get("fixtureId") == id and result.has("score") and result.get("score") != score: return {}
	return target

static func fixture_opponent(model: Dictionary, fixture: Dictionary) -> Dictionary:
	var own: Variant = model.get("club", {}).get("id")
	if own == null: return {}
	var home: Dictionary = fixture.get("home", {})
	var away: Dictionary = fixture.get("away", {})
	if home.get("id") == own: return away
	if away.get("id") == own: return home
	return {}

static func _reading_button(app: Control, target: Dictionary, id: String, caption: String) -> Button:
	if not reading_available(app, target): return null
	var link := Button.new()
	link.name = id
	link.set_meta("immersive_style_applied", true)
	for style: String in ["normal", "hover", "pressed", "disabled"]: link.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 3, 0))
	EntityLink.bind(link, app, target, caption)
	return link

static func reading_control(app: Control, content: Control, target: Dictionary, id: String, caption: String) -> Control:
	var link := _reading_button(app, target, id, caption)
	if link == null: return content
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.size_flags_horizontal = content.size_flags_horizontal
	link.size_flags_vertical = content.size_flags_vertical
	link.size_flags_stretch_ratio = content.size_flags_stretch_ratio
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.minimum_size_changed.connect(func():
		if is_instance_valid(link): link.custom_minimum_size.y = content.get_combined_minimum_size().y)
	return link

static func reading_overlay(app: Control, parent: Node, rectangle: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	var link := _reading_button(app, target, id, caption)
	if link == null: return null
	link.custom_minimum_size = Vector2.ZERO
	parent.add_child(link)
	link.position = rectangle.position * C.density
	link.size = rectangle.size * C.density
	return link

static func recruitment_availability(market: Array) -> String:
	var offers := market.filter(func(player: Dictionary): return player.get("available", false)).size()
	var summary := "%d piste%s · %d offre%s possible%s" % [
		market.size(), "s" if market.size() > 1 else "", offers, "s" if offers > 1 else "", "s" if offers > 1 else ""
	]
	if offers == 0 and not market.is_empty():
		var reason := str(market[0].get("reason", ""))
		if not reason.is_empty() and market.all(func(player: Dictionary): return player.get("reason", "") == reason):
			summary += " · " + reason
	return summary

static func _open_player(app: Control, id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

static func open_notebook(app: Control) -> void:
	preload("res://ui/coach_notes_view.gd").open(app, "career")

static func scheduled_opponent(app: Control, fixture: Dictionary) -> String:
	var home: Dictionary = fixture.get("home", {})
	return G.club_name(fixture.get("away", {}) if home.get("id") == app.model.club.id else home)

static func scheduled_when(app: Control, fixture: Dictionary) -> String:
	var date := P.fixture_date(fixture, true)
	if date.is_empty(): date = timeline_period(fixture)
	var location := P.fixture_location_kind(fixture, app.model.club.id)
	var place: String = {"home":"À domicile","away":"À l’extérieur","neutral":"Terrain neutre"}.get(location,"")
	return date if place.is_empty() else date + " · " + place

static func scheduled_venue(app: Control, fixture: Dictionary) -> String:
	var location := P.fixture_location_kind(fixture, app.model.club.id)
	return P.fixture_venue(fixture, false, location != "neutral")

static func territory_art(club: Dictionary) -> VBoxContainer:
	var identity := G.identity(club)
	var photos: Dictionary = identity.get("photos", {})
	var cards := C.v(6)
	cards.name = "OfficeTerritoryPreviews"
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for info in [["city","VILLE DU CLUB","OfficeCityPreview"],["stadium","STADE DU CLUB","OfficeStadiumPreview"]]:
		var kind: String = info[0]
		var photo: Dictionary = photos.get(kind, {})
		var location: Variant = identity.get(kind)
		var place := str(location).strip_edges() if location != null else ""
		if place.is_empty() and photo.is_empty(): continue
		var picture := G.club_picture(club, kind)
		picture.name = info[2]
		picture.custom_minimum_size = Vector2.ZERO
		C.fill(picture, true)
		cards.add_child(picture)
		var content: VBoxContainer = picture.get_meta("content")
		content.add_theme_constant_override("separation", C.px(3))
		content.add_child(G.spacer())
		var title := C.label(info[1] + " · " + (place if not place.is_empty() else "—"), 20, C.IVORY, true, 700)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(title)
		var caption := str({"pack":photo.get("credit", ""), "archive":"Photo d’archive"}.get(picture.get_meta("photo_kind"), "Vue du club"))
		var credit := C.label(caption, 17, C.MUTED)
		credit.name = "OfficePhotoCredit"
		credit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(credit)
		describe_fixture(credit, title.text + "\n" + picture.tooltip_text)
	if cards.get_child_count() > 0: return cards
	cards.free()
	return null

static func build(app: Control) -> Control:
	var page := C.v(16)
	page.name = "ImmersiveOffice"
	C.fill(page, true)
	var top := C.h(16)
	page.add_child(top)
	var hero := _card(top, "OfficeFixture", "", 418, 1.56)
	_fixture(hero, app)
	var priorities := _card(top, "OfficeDecisions", "▦  Vos trois priorités", 418)
	_priorities(C.content(priorities), app)
	# Keep the next decision visible while the secondary cards share the
	# remaining workspace. Their natural minima can exceed a small window.
	var scroll := ScrollContainer.new()
	scroll.name = "OfficeReadingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	C.fill(scroll, true)
	page.add_child(scroll)
	var reading := C.v(16)
	C.fill(reading, true)
	scroll.add_child(reading)
	var middle := C.h(16)
	reading.add_child(middle)
	_group(C.content(_card(middle, "OfficeGroup", "♡  État du groupe", 448, .77)), app)
	_standings(C.content(_card(middle, "OfficeStandings", "♜  Classement · " + P.league_name(app.model), 448, 1.25)), app)
	_journal(C.content(_card(middle, "OfficeJournal", "✉  Dans votre Bureau", 448)), app)
	_recruitment(C.content(_card(middle, "OfficeRecruitment", "⌕  Le profil à suivre", 448)), app)
	_timeline(C.content(_card(reading, "OfficeTimeline", "▦  Prochains matchs", 226)), app)
	var results := recent_results(app)
	if results != null: reading.add_child(results)
	return page

static func recent_results(app: Control) -> PanelContainer:
	var played: Array = app.model.get("calendar", []).filter(func(fixture: Dictionary):
		var score: Variant = fixture.get("score")
		return fixture.get("played", false) and score is Array and score.size() == 2
	)
	if played.is_empty(): return null
	played.reverse()
	var panel := C.card()
	panel.name = "OfficeRecentResults"
	panel.add_theme_stylebox_override("panel",C.box(Color("121c27"),Color("61798f"),6,10))
	var content := C.content(panel)
	var header := C.h(8)
	content.add_child(header)
	header.add_child(C.icon("check",22,C.BLUE))
	header.add_child(C.label("RÉSULTATS · CINQ DERNIERS MATCHS",24,C.BLUE,true,700))
	var row := C.h(12)
	content.add_child(row)
	var club_id: Variant = app.model.club.id
	for fixture: Dictionary in played.slice(0,5):
		var side := 0 if fixture.home.get("id") == club_id else 1
		var opponent: Dictionary = fixture.away if side == 0 else fixture.home
		var score: Array = fixture.score
		var outcome: Variant = fixture.get("winner")
		var result := "Nul"
		var tint := C.GOLD
		if score[side] != score[1-side] or outcome != null:
			var won: bool = (outcome == club_id) if score[side] == score[1-side] else score[side] > score[1-side]
			result = "Victoire" if won else "Défaite"
			tint = C.MINT if won else C.ALERT
		var location := P.fixture_location_kind(fixture, club_id)
		var place: String = {"home":"Domicile","away":"Extérieur","neutral":"Terrain neutre"}.get(location,"")
		var tile := C.card()
		tile.add_theme_stylebox_override("panel",C.box(Color("1a2936"),Color("52677d"),5,8))
		row.add_child(C.fill(tile))
		var matchup := C.h(12)
		C.content(tile).add_child(matchup)
		var points := C.label("%s – %s" % [G.n(score[side]),G.n(score[1-side])],29,tint,true,700)
		points.name = "OfficeRecentScore"
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_card := PanelContainer.new()
		score_card.custom_minimum_size = Vector2(C.px(102),C.px(50))
		score_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_card.add_theme_stylebox_override("panel",C.box(Color("101a23").lerp(tint,.12),tint,5,4))
		score_card.add_child(points)
		var fixture_key := str(fixture.get("id", fixture.get("date", ""))).validate_node_name()
		matchup.add_child(reading_control(app, score_card, score_reading_target(app, fixture), "OfficeRecentFixture_" + fixture_key, "Rencontre · " + points.text))
		var crest := opponent_crest(opponent,48)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		matchup.add_child(reading_control(app, crest, club_reading_target(app, opponent), "OfficeRecentClubCrest_" + fixture_key, G.club_name(opponent)))
		var details := C.v(0)
		matchup.add_child(C.fill(details))
		var name := C.label(G.club_name(opponent),23)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(reading_control(app, name, club_reading_target(app, opponent), "OfficeRecentClubName_" + fixture_key, name.text))
		var description := C.label(result + (" · " + place if not place.is_empty() else ""),19,C.MUTED)
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(description)
		describe_fixture(tile," · ".join([timeline_period(fixture),name.text,points.text,description.text]))
	for index in range(played.size(),5):
		row.add_child(C.fill(Control.new()))
	return panel

static func opponent_crest(opponent: Dictionary, width: int) -> Control:
	var crest := G.crest(opponent,C.px(width))
	crest.name = "OfficeOpponentCrest"
	crest.set_meta("opponent_id",opponent.get("id"))
	crest.accessibility_name = "Blason · " + G.club_name(opponent)
	return crest

static func _fixture(frame: PanelContainer, app: Control) -> void:
	frame.clip_contents = true
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var territory := territory_art(app.model.club)
	if territory == null:
		var backdrop := Control.new()
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(backdrop)
		frame.move_child(backdrop, 0)
		var ground := P.fixture_ground(app.model.meta,"office-hero")
		var image := C.photo(ground,Vector2.ZERO,true,.53 if ground != "office-hero" else 0.0)
		backdrop.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.anchor_left = .51
		C.veil(backdrop)
	var row := C.h(0)
	C.fill(row, true)
	C.content(frame).add_child(row)
	var left := C.v(8)
	C.fill(left, true, 1.1)
	row.add_child(left)
	if territory != null:
		C.fill(territory, true)
		row.add_child(territory)
	else:
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(space)
		row.add_child(space)
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	var preparation := SeasonPreparation.data(app.model.meta)
	var match_info := live_match(app.model)
	if not match_info.is_empty():
		_live_content(left, match_info)
	elif next.is_empty():
		var upcoming := P.next_nationale_fixture(app.model)
		var scheduled := P.next_scheduled_fixture(app.model)
		if not upcoming.is_empty():
			left.add_child(C.label("SEMAINE EXEMPTE",21,C.GOLD,true,700))
			var opponent := C.wrap(scheduled_opponent(app,upcoming),42,C.IVORY,true,800)
			opponent.name = "UpcomingOpponent"
			left.add_child(reading_control(app, opponent, club_reading_target(app, fixture_opponent(app.model, upcoming)), "OfficeScheduledOpponent", opponent.text))
			var kickoff := C.wrap("Prochain match · " + scheduled_when(app,upcoming),25,C.IVORY,true)
			kickoff.name = "UpcomingWhen"
			left.add_child(reading_control(app, kickoff, date_reading_target(app, upcoming), "OfficeScheduledDate", kickoff.text))
			var venue := scheduled_venue(app,upcoming)
			if not venue.is_empty(): left.add_child(C.wrap("Lieu · " + venue,18))
		elif preparation.is_empty() and not scheduled.is_empty():
			left.add_child(C.label("PROCHAINE RENCONTRE",22,C.GOLD,true,700))
			left.add_child(reading_control(app, C.wrap(scheduled_opponent(app,scheduled),39,C.IVORY,true,800), club_reading_target(app, fixture_opponent(app.model, scheduled)), "OfficeScheduledOpponent", scheduled_opponent(app,scheduled)))
			left.add_child(reading_control(app, C.wrap(scheduled_when(app,scheduled),25,C.IVORY,true), date_reading_target(app, scheduled), "OfficeScheduledDate", scheduled_when(app,scheduled)))
			left.add_child(C.wrap(P.fixture_venue(scheduled),20))
		elif preparation.is_empty():
			left.add_child(C.label("LE PROCHAIN CHAPITRE", 21, C.GOLD))
			left.add_child(C.wrap("La saison se termine." if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue.", 42, C.IVORY, true))
			left.add_child(C.wrap("Retrouvez les résultats et préparez la suite du projet.", 20))
		elif SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			if fixture.is_empty():
				left.add_child(C.wrap("Préparation · " + World.name_for(app.model, "champ"),42,C.IVORY,true))
				left.add_child(C.wrap(World.preparation_note(preparation),25,C.IVORY,true))
			else:
				left.add_child(C.label("PRÉPARATION",21,C.GOLD,true,700))
				var opponent := C.wrap(scheduled_opponent(app,fixture),42,C.IVORY,true,800)
				opponent.name = "UpcomingOpponent"
				left.add_child(reading_control(app, opponent, club_reading_target(app, fixture_opponent(app.model, fixture)), "OfficeScheduledOpponent", opponent.text))
				var kickoff := C.wrap(scheduled_when(app,fixture),25,C.IVORY,true)
				kickoff.name = "UpcomingWhen"
				left.add_child(reading_control(app, kickoff, date_reading_target(app, fixture), "OfficeScheduledDate", kickoff.text))
				var venue := scheduled_venue(app,fixture)
				if not venue.is_empty(): left.add_child(C.wrap("Lieu · " + venue,18))

		else:
			left.add_child(C.label(World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(),21,C.GOLD))
			left.add_child(C.wrap("Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),42,C.IVORY,true))
			left.add_child(C.wrap(World.preparation_note(preparation),20))
	else:
		var tags := C.h(12)
		left.add_child(tags)
		tags.add_child(C.label("PROCHAIN MATCH",21,C.GOLD,true,700))
		var match_label := str(next.get("label", "Prochain match"))
		var stage := C.chip(fixture_stage(app.model,next,match_label),C.MINT)
		describe_fixture(stage,match_label)
		tags.add_child(stage)
		var location: String = "NEUTRE" if next.get("neutral", false) else "À DOMICILE" if next.get("home", {}).get("id") == app.model.club.id else "À L’EXTÉRIEUR"
		tags.add_child(C.chip(location, C.GOLD))
		var teams := C.h(16)
		left.add_child(teams)
		teams.add_child(reading_control(app, G.crest(next.get("home", {}), C.px(82)), club_reading_target(app, next.get("home", {})), "OfficeNextHomeClubCrest", G.club_name(next.get("home", {}))))
		teams.add_child(C.label("VS", 23, C.GOLD))
		teams.add_child(reading_control(app, G.crest(next.get("away", {}), C.px(82)), club_reading_target(app, next.get("away", {})), "OfficeNextAwayClubCrest", G.club_name(next.get("away", {}))))
		var names := C.v(2)
		C.fill(names)
		teams.add_child(names)
		names.add_child(reading_control(app, C.wrap(G.club_name(next.get("home", {})), 32, C.IVORY, true), club_reading_target(app, next.get("home", {})), "OfficeNextHomeClubName", G.club_name(next.get("home", {}))))
		names.add_child(reading_control(app, C.wrap(G.club_name(next.get("away", {})), 30, C.IVORY, true), club_reading_target(app, next.get("away", {})), "OfficeNextAwayClubName", G.club_name(next.get("away", {}))))
		var date := P.fixture_date(next, true)
		if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week",0))+1]
		var timing := C.wrap(date+" · "+fixture_competition(app.model,next),25,C.IVORY,true)
		timing.name="OfficeFixtureDate"
		left.add_child(reading_control(app, timing, date_reading_target(app, next), "OfficeNextDate", timing.text))
		var venue_name := P.fixture_venue(next,false)
		if not venue_name.is_empty():
			var venue := C.wrap(venue_name,18)
			venue.name="OfficeFixtureVenue"
			left.add_child(venue)
		var valid: bool = app.model.get("selection",{}).get("valid",false)
		left.add_child(C.label("Feuille complète" if valid else "Feuille à préparer",21,C.MINT if valid else C.AMBER,true,700))
	var spacer := Control.new()
	C.fill(spacer, true)
	left.add_child(spacer)
	var actions := C.h(12)
	left.add_child(actions)
	if next.is_empty() or not match_info.is_empty():
		var caption: String = app.primary_text()
		if not match_info.is_empty(): caption = caption.trim_suffix("  →")
		var primary := C.button(caption,app.primary_action,true,app.accent)
		primary.name="OfficePreparationAction"
		actions.add_child(primary)
		C.fill(primary)
	else: C.fill(_link(actions, "OfficePreparationAction", "PRÉPARER LE MATCH  →", app, "Préparation", true))
	if match_info.is_empty():
		C.fill(_link(actions, "OfficeSelectionAction", "Vérifier les 23", app, "Composition"))
	else:
		var review := _link(actions, "OfficeMatchReviewAction", "Revoir le match", app, "Match")
		review.visible = match_info.finished
		C.fill(review)

static func _live_content(left: VBoxContainer, match_info: Dictionary) -> void:
	var tags := C.h(12)
	left.add_child(tags)
	var heading := C.chip(match_info.heading, C.MINT)
	heading.get_child(0).name = "OfficeLiveHeading"
	tags.add_child(heading)
	if not match_info.location.is_empty(): tags.add_child(C.chip(match_info.location, C.GOLD))
	var row := C.h(12)
	left.add_child(row)
	var teams: Array = match_info.teams
	if teams.size() == 2: row.add_child(G.crest(teams[0], C.px(74)))
	var score := C.label(match_info.score, 31, C.IVORY, true)
	score.name = "OfficeLiveScore"
	row.add_child(score)
	if teams.size() == 2:
		row.add_child(G.crest(teams[1], C.px(74)))
		var names := C.v(2)
		C.fill(names)
		row.add_child(names)
		for team: Dictionary in teams: names.add_child(C.wrap(G.club_name(team), 29, C.IVORY, true))
	var state := C.wrap(match_info.state, 21, C.GOLD, true)
	state.name = "OfficeLiveState"
	left.add_child(state)
	if not match_info.detail.is_empty():
		var detail := C.wrap(match_info.detail, 18)
		detail.name = "OfficeLiveFixtureDetail"
		left.add_child(detail)

static func priorities(model: Dictionary) -> Array[Dictionary]:
	return Priorities.select(model)

static func priority_color(item: Dictionary) -> Color:
	return C.ALERT if item.level == "urgent" else C.GOLD if item.level == "important" else C.MINT

static func open_priority(app: Control, item: Dictionary) -> void:
	match item.action:
		"press": app._show_press_inbox()
		"match": app._navigate("Match")
		"standings": open_current_standings(app)
		"selection": app._navigate("Composition")
		"finance": app._navigate("Finances")
		"international":
			app.management_ui.international_section = "availability"
			app._navigate("Sélections")
		"squad": app.navigation_controller.open_roster_group()
		"contract": _open_player(app,str(item.player))
		"preparation": app._navigate("Préparation")
		"training": app.Immersive.open_training(app)
		"recruitment": app._navigate("Recrutement")

static func priority_description(item: Dictionary) -> String:
	return str(item.deadline) + " · " + str(item.detail)

static func _priorities(parent: VBoxContainer, app: Control) -> void:
	var choices := priorities(app.model)
	if choices.is_empty(): parent.add_child(C.wrap("Reprenez une carrière pour retrouver les décisions de votre club.",18,C.MUTED))
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var tint := priority_color(choice)
		var tile := C.card()
		tile.name = "OfficePriority" + str(i+1)
		tile.add_theme_stylebox_override("panel", C.box(Color(tint,.035),Color(tint,.24),4,6))
		parent.add_child(tile)
		var line := C.h(10)
		C.content(tile).add_child(line)
		var mark := C.icon(choice.icon,22,tint)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(mark)
		var text := C.v(2)
		C.fill(text)
		line.add_child(text)
		var action := C.button(str(i+1) + ". " + str(choice.title) + "  →",open_priority.bind(app,choice))
		action.name = choice.id
		action.set_meta("priority_number",i+1)
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.clip_text = true
		action.custom_minimum_size.y = C.px(34)
		action.tooltip_text = choice.title + "\n" + priority_description(choice)
		action.accessibility_name = action.tooltip_text.replace("\n"," · ")
		action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
		text.add_child(action)
		var due := C.label(choice.deadline,15,tint,true)
		due.name = "OfficePriorityDeadline" + str(i+1)
		text.add_child(due)
		var detail := C.wrap(choice.detail,17,C.MUTED)
		detail.name = "OfficePriorityReason" + str(i+1)
		text.add_child(detail)
	var shortcuts := C.h(8)
	parent.add_child(shortcuts)
	if not choices.any(func(item: Dictionary): return item.id == "OfficeTrainingAction") and not app.model.meta.get("canAdvanceSeason",false) and app.model.meta.get("phase","") != "ended":
		var training := C.button("Entraînement",func():app.Immersive.open_training(app),false,app.accent)
		training.name = "OfficeTrainingAction"
		shortcuts.add_child(C.fill(training))
	var notebook := C.button("Mon carnet personnel",func():open_notebook(app),false,app.accent)
	notebook.name = "OpenCoachNotebook"
	notebook.custom_minimum_size.y = maxi(30,C.px(40))
	shortcuts.add_child(C.fill(notebook))

static func _group(parent: VBoxContainer, app: Control) -> void:
	var group := P.group(app.model)
	var counts := C.h(20)
	parent.add_child(counts)
	for pair in [[group.available, "disponibles", C.MINT], [group.injured, "blessés", C.ALERT]]:
		var col := C.h(10)
		C.fill(col)
		counts.add_child(col)
		col.add_child(C.label(pair[0], 58, pair[2]))
		col.add_child(C.label(pair[1], 23))
	parent.add_child(C.rule())
	for pair in [["Condition physique", group.condition, C.MINT], ["Moral du groupe", app.model.meta.get("morale", 0), C.GOLD]]:
		var caption := C.h(5)
		parent.add_child(caption)
		var name := C.label(pair[0], 22, C.MUTED)
		C.fill(name)
		caption.add_child(name)
		caption.add_child(C.label(str(int(pair[1])) + " %", 24, pair[2]))
		parent.add_child(C.gauge(float(pair[1]), pair[2]))
	parent.add_child(C.rule())
	if group.watched > 0:
		var watched := C.button(U.watch_caption(group.watched) + "  →", app.navigation_controller.open_watched_roster)
		watched.name = "OfficeWatchedAction"
		watched.add_theme_color_override("font_color", C.AMBER)
		parent.add_child(watched)
	else:
		parent.add_child(C.wrap("Aucune alerte physique", 22, C.MINT, true))
	var roster := C.button("Consulter le groupe  →", app.navigation_controller.open_roster_group)
	roster.name = "OfficeSquadAction"
	parent.add_child(roster)

static func _standings(parent: VBoxContainer, app: Control) -> void:
	var rows := P.standings(app.model)
	var header := C.h(8)
	parent.add_child(header)
	for pair in [["#", 30], ["CLUB", 0], ["J", 36], ["DIFF.", 55], ["PTS", 40]]:
		var caption := C.label(pair[0], 18, C.MUTED)
		if pair[1] == 0: C.fill(caption)
		else: caption.custom_minimum_size.x = C.px(pair[1])
		header.add_child(caption)
	for club: Dictionary in rows:
		var tile := PanelContainer.new()
		var own: bool = club.get("id") == app.model.club.id
		tile.add_theme_stylebox_override("panel", C.box(Color(app.accent, .22) if own else Color.TRANSPARENT, Color.TRANSPARENT, 3, 4))
		parent.add_child(tile)
		tile.add_child(standing_action(app,club))
		var row := C.h(8)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tile.add_child(row)
		var values: Array = [G.n(club.get("rank", "—")), G.club_name(club), G.n(club.get("played", 0)), "%+d" % (int(club.get("pf", 0))-int(club.get("pa", 0))), G.n(club.get("points", 0))]
		for i in values.size():
			var cell := C.label(values[i], 23, C.MINT if own else C.IVORY)
			if i == 1:
				C.fill(cell)
				cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			else: cell.custom_minimum_size.x = C.px([30, 0, 36, 55, 40][i])
			row.add_child(cell)
	if rows.is_empty(): parent.add_child(C.wrap("Le classement sera disponible lorsque le championnat sera ouvert.", 20))
	_link(parent, "OfficeStandingsAction", "Classement complet  →", app, "Classements")

static func final_standings_detail(model: Dictionary) -> String:
	var club_id: Variant = model.get("club", {}).get("id")
	for row: Dictionary in P.standings(model):
		if row.get("id") != club_id: continue
		var rank: Variant = row.get("rank")
		if not (rank is int or rank is float) or rank < 1: break
		var detail := "1er" if rank == 1 else "%se" % G.n(rank)
		var points: Variant = row.get("points")
		if points is int or points is float: detail += " · %s pts" % G.n(points)
		return detail
	return "Résultats de la division."

static func open_current_standings(app: Control) -> void:
	app.table_division = str(app.model.meta.get("leagueId", app.table_division))
	app._navigate("Classements")

static func standing_action(app: Control, club: Dictionary) -> Button:
	var action := Button.new()
	action.name="OfficeStandingRow_"+G.n(club.get("id",""))
	action.flat=true
	action.set_meta("club_id",club.get("id"))
	for key in ["won","drawn","lost"]: action.set_meta(key,S.count_text(club.get(key)))
	action.tooltip_text="%s\nVictoires %s  ·  Nuls %s  ·  Défaites %s\nOuvrir le classement complet" % [G.club_name(club),action.get_meta("won"),action.get_meta("drawn"),action.get_meta("lost")]
	action.accessibility_name=action.tooltip_text.replace("\n"," · ")
	var focus := C.box(Color(C.MINT,.07),C.GOLD,4,0)
	focus.set_border_width_all(2)
	action.add_theme_stylebox_override("focus",focus)
	action.add_theme_stylebox_override("hover",C.box(Color(C.MINT,.07),Color(C.MINT,.68),4,0))
	action.pressed.connect(open_current_standings.bind(app))
	return action

static func _journal(parent: VBoxContainer, app: Control) -> void:
	var messages: Array = app.model.get("messages", [])
	if messages.is_empty(): parent.add_child(C.wrap("Les nouvelles de votre carrière apparaîtront ici.", 21))
	for index in mini(3, messages.size()):
		parent.add_child(C.label("CARRIÈRE  ·  ÉVÉNEMENT %02d" % (index+1), 18, [C.BLUE, C.ALERT, C.GOLD][index]))
		var note := C.wrap(Copy.news(str(messages[index])).replace("l’onglet Contrats", "les fiches joueurs"), 19)
		note.max_lines_visible = 3
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		parent.add_child(note)
		if index < 2: parent.add_child(C.rule())

static func recruitment_spotlight(model: Dictionary) -> Dictionary:
	var market: Array = model.get("market", [])
	var needs: Array = model.get("decisions", {}).get("recruitment", {}).get("needs", [])
	var need: Dictionary = needs[0] if not needs.is_empty() else {}
	var position := str(need.get("pos", "")).strip_edges()
	var candidates := market.filter(func(player: Dictionary):
		return not str(player.get("id", "")).is_empty() and (position.is_empty() or player.get("pos") == position))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var available_a: bool = a.get("available", false)
		var available_b: bool = b.get("available", false)
		if available_a != available_b: return available_a
		var av: Variant = G.knowledge_sort_value(a,"rating")
		var bv: Variant = G.knowledge_sort_value(b,"rating")
		if av == null or bv == null:
			if av != bv: return av != null
		elif av != bv: return av > bv
		return str(a.id) < str(b.id))
	var heading := "Priorité de recrutement" if need.get("need", false) else "Poste à surveiller"
	var empty_title := "Aucune piste sur le marché" if market.is_empty() or position.is_empty() else "Aucune piste au poste suivi"
	return {
		"player": candidates[0] if not candidates.is_empty() else {},
		"need": heading + " · " + position if not position.is_empty() else "",
		"empty": empty_title,
	}

static func open_spotlight(app: Control, id: String) -> void:
	if not app.navigation_controller.open_market_player(id): app.navigation_controller.open_market_player("")

static func _recruitment(parent: VBoxContainer, app: Control) -> void:
	var spotlight := recruitment_spotlight(app.model)
	var player: Dictionary = spotlight.player
	if player.is_empty():
		parent.add_child(C.photo("scouting", Vector2(0, 150)))
		parent.add_child(C.wrap(spotlight.empty, 23, C.IVORY, true))
	else:
		var row := C.h(14)
		parent.add_child(row)
		row.add_child(G.portrait(int(player.get("portraitIndex", 0)), C.px(125), player))
		var identity := C.v(6)
		C.fill(identity)
		row.add_child(identity)
		identity.add_child(C.wrap(player.name, 30, C.IVORY, true))
		identity.add_child(C.wrap(str(player.pos) + " · " + G.n(player.age) + " ans", 20))
		identity.add_child(C.chip("NIVEAU  " + G.rating_text(player)))
		parent.add_child(C.wrap(G.euros(player.fee) + " · " + G.salary(player.salary), 24, C.IVORY, true))
		var available: bool = player.get("available", false)
		var status := "Offre possible" if available else "Offre indisponible"
		var reason := str(player.get("reason", ""))
		if not reason.is_empty(): status += " · " + reason
		parent.add_child(C.wrap(status, 19, C.MINT if available else C.ALERT, true))
	if not str(spotlight.need).is_empty(): parent.add_child(C.wrap(spotlight.need, 20, C.MUTED))
	var action := C.button("Ouvrir le recrutement" if player.is_empty() else "Voir cette piste", open_spotlight.bind(app, str(player.get("id", ""))), false, app.accent)
	action.name = "OfficeMarketAction"
	parent.add_child(action)

static func fixture_competition(model: Dictionary, fixture: Dictionary) -> String:
	var competition := str(fixture.get("competitionId",""))
	if competition.is_empty(): return P.league_name(model)
	for league: Dictionary in model.get("leagues",[]):
		if league.get("id")==competition: return str(league.get("name","Championnat"))
	return str(fixture.get("label","Championnat")).get_slice(" · ",0)

static func fixture_stage(model: Dictionary, fixture: Dictionary, label: String) -> String:
	return label.trim_prefix(fixture_competition(model,fixture) + " · ")

static func short_fixture_label(model: Dictionary, fixture: Dictionary) -> String:
	var label := str(fixture.get("label","Rencontre"))
	if not fixture.has("competitionId"): return label
	var id := str(fixture.competitionId)
	var competition := World.name_for(model,id)
	if label.begins_with(competition+" · "):
		return World.short_name(id,competition,model)+label.trim_prefix(competition)
	return label

static func describe_fixture(node: Control, detail: String) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.tooltip_text = detail
	node.accessibility_name = detail.replace("\n"," · ")

static func timeline_period(fixture: Dictionary) -> String:
	var date := P.fixture_date(fixture)
	return date if not date.is_empty() else "SEM. %02d" % (int(fixture.get("week", 0))+1)

static func _timeline(parent: VBoxContainer, app: Control) -> void:
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var row := C.h(12)
	parent.add_child(row)
	var fixtures := upcoming_matches(app.model)
	if fixtures.is_empty():
		parent.add_child(C.wrap("Aucune rencontre programmée. Retrouvez les résultats dans le calendrier.", 21))
	for fixture: Dictionary in fixtures:
		var tile := C.card()
		tile.add_theme_stylebox_override("panel",C.box(UPCOMING_TILE,UPCOMING_BORDER,6,12))
		C.fill(tile)
		row.add_child(tile)
		var list := C.content(tile)
		list.add_theme_constant_override("separation", C.px(4))
		var period := C.label(timeline_period(fixture), 21, C.GOLD)
		period.name = "OfficeTimelineDate"
		period.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var local_date := P.fixture_date(fixture, true)
		if not local_date.is_empty(): describe_fixture(period, local_date)
		var fixture_key := str(fixture.get("id", fixture.get("date", ""))).validate_node_name()
		list.add_child(reading_control(app, period, date_reading_target(app, fixture), "OfficeTimelineDateLink_" + fixture_key, period.text))
		list.add_child(C.rule())
		var opponent: Dictionary = fixture.get("away", {}) if fixture.get("home", {}).get("id") == app.model.club.id else fixture.get("home", {})
		var name := C.label(G.club_name(opponent), 24)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var matchup := C.h(6)
		list.add_child(matchup)
		var crest := opponent_crest(opponent,36)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		matchup.add_child(reading_control(app, crest, club_reading_target(app, opponent), "OfficeTimelineClubCrest_" + fixture_key, G.club_name(opponent)))
		matchup.add_child(C.fill(reading_control(app, name, club_reading_target(app, opponent), "OfficeTimelineClubName_" + fixture_key, name.text)))
		var location := P.fixture_location_kind(fixture, app.model.club.id)
		var marker := C.icon(C.fixture_location_icon(location,true),46,C.GOLD)
		marker.name = "OfficeVenueIcon"
		matchup.add_child(marker)
		var label := str(fixture.get("label","Rencontre"))
		list.add_child(C.label(short_fixture_label(app.model,fixture) if japan else label,19,C.MUTED))
		if japan:
			var place := "Neutre" if fixture.get("neutral",false) else "Domicile" if fixture.get("home",{}).get("id")==app.model.club.id else "Extérieur"
			list.add_child(C.label(place,18,C.MUTED))
			describe_fixture(tile,"\n".join([G.club_name(opponent),label,place,P.fixture_venue(fixture)]).strip_edges())
	var action := _link(parent, "OfficeCalendarAction", "Tout le calendrier  →", app, "Calendrier")
	var title: Label = parent.find_child("CardTitle", true, false)
	parent.remove_child(title)
	parent.remove_child(action)
	var heading := C.h(12)
	parent.add_child(heading)
	parent.move_child(heading, 0)
	C.fill(title)
	heading.add_child(title)
	heading.add_child(action)
	action.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	action.add_theme_font_size_override("font_size", C.px(21))
	action.custom_minimum_size.y = C.px(30)
	action.size_flags_horizontal = Control.SIZE_SHRINK_END
