extends RefCounted
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const G = preload("res://ui/game_skin.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const History = preload("res://ui/club_memory_view.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Strategy = preload("res://ui/strategy_view.gd")
const KEY = "immersive08_club_tab"
const GOALS = {"wins":"Victoires", "points":"Points", "rank":"Place au classement", "cash":"Trésorerie"}
const GOAL_STATUS = {"pending":"À suivre", "met":"Atteint", "missed":"Manqué", "unverified":"Non vérifié"}

class TrustDial extends Control:
	var trust := 0.0
	func _draw() -> void:
		var radius := size.x * .43
		var center := Vector2(size.x * .5, size.y - C.px(5))
		var thickness := C.px(32)
		for segment in 8:
			var start := PI + PI * float(segment) / 8.0 + .01
			var end := PI + PI * float(segment + 1) / 8.0 - .01
			draw_arc(center, radius, start, end, 20, Color("2c3938"), thickness, true)
			var progress := clampf(trust * .08 - segment, 0.0, 1.0)
			if progress > .0:
				var color := Color("35c362").lerp(Color("a1efae"), float(segment) / 7.0)
				draw_arc(center, radius, start, lerpf(start, end, progress), 20, color, thickness, true)

static func build(app: Control, canvas: Control) -> void:
	canvas.name = "ImmersiveClub"
	var tab: String = str(app.management_ui.get(KEY, "history" if app.management_ui.get("club_tab",0) == 1 else "overview"))
	match app.route:
		"Stratégie": tab = "direction"
		"Staff", "Travail du club": tab = "staff"
	_header(app, canvas, tab)
	match app.route:
		"Stratégie": _direction(app, canvas)
		"Staff", "Travail du club": _staff_detail(app, canvas)
		_:
			match tab:
				"infrastructure": _infrastructure_detail(app, canvas)
				"history": _history(app, canvas)
				"territory": _territory(app, canvas)
				_: _overview(app, canvas)

static func _header(app: Control, canvas: Control, tab: String) -> void:
	D.photo(canvas, "club-forest", Rect2(930,0,1318,196))
	U.art_fade(canvas, Rect2(930,0,1318,196))
	var crest := G.crest(app.model.club, C.px(150))
	canvas.add_child(crest)
	D.place(crest, Rect2(24,9,150,176))
	var slash := Line2D.new()
	slash.default_color = C.GOLD
	slash.width = maxf(1,C.px(2))
	slash.antialiased = true
	slash.points = PackedVector2Array([Vector2(196,175)*C.density, Vector2(222,53)*C.density])
	canvas.add_child(slash)
	U.italic(D.text(canvas, 225, 47, "UN CLUB, UNE AMBITION", 32, C.GOLD, 700, 450), 700)
	D.line(canvas, Vector2(614,31), Vector2(917,31), Color(C.GOLD,.65))
	D.text(canvas, 220, 131, G.club_name(app.model.club)+".", 84, C.IVORY, 800, 1950)
	var identity := G.identity(app.model.club)
	D.text(canvas, 225, 174, "%s  ·  Saison %s" % [identity.get("stadium", "Stade"), G.n(app.model.meta.get("season", 1))], 28, C.IVORY, 500, 850)
	var tabs := [["overview","Vue d’ensemble",291],["direction","Direction",216],["infrastructure","Infrastructures",269],["staff","Staff",172],["history","Histoire",195]]
	var x := 1081
	for entry: Array in tabs:
		var key: String = entry[0]
		var id := "ClubTab_" + key
		U.tab(canvas, Rect2(x,145,entry[2],51), entry[1], key == tab or (key == "overview" and tab == "territory"), func(): _tab(app, key, id), id)
		x += int(entry[2]) + 6

static func _tab(app: Control, key: String, id: String = "") -> void:
	if key == "direction" or key == "staff":
		app._navigate("Stratégie" if key == "direction" else "Staff")
		return
	app.management_ui[KEY] = key
	app.management_ui.club_tab = 1 if key == "history" else 0
	if app.route != "Club": app._navigate("Club")
	else: U.select(app, KEY, key, id)

static func _overview(app: Control, canvas: Control) -> void:
	var strategy := U.strategy(app.model)
	var finance: Dictionary = strategy.get("finance", {})
	var board: Dictionary = strategy.get("board", {})
	_stadium(D.panel(canvas, Rect2(0,214,934,402), "", "", "", "ClubStadium"), app, strategy.get("fans", {}))
	_trust(D.panel(canvas, Rect2(950,214,443,402), "La confiance du conseil", "shield", "", "ClubTrust"), app, finance)
	_goals(D.panel(canvas, Rect2(1409,214,499,402), "Objectifs de la saison", "trophy", "", "ClubObjectives"), app, board)
	_locker(D.panel(canvas, Rect2(1924,214,324,402), "Le vestiaire", "people", "", "ClubLocker"), app)
	_installations(D.panel(canvas, Rect2(0,632,712,427), "Infrastructures", "train", "", "ClubFacilities"), app, finance)
	_staff(D.panel(canvas, Rect2(728,632,708,427), "L’encadrement", "people", "", "ClubStaff"), app)
	_fans(D.panel(canvas, Rect2(1452,632,796,427), "Vie du club", "mail", "", "ClubLife"), app, strategy)
	_footer(D.panel(canvas, Rect2(0,1075,2248,169), "", "", "", "ClubBoardAndBudget"), app, finance, board)

static func _venue_picture(identity: Dictionary, kind: String, allow_archive: bool = true) -> Control:
	var photo: Dictionary = identity.get("photos", {}).get(kind, {})
	var slug := str(identity.get("slug", "")) if allow_archive else ""
	return G.picture(slug, kind, false, str(photo.get("path", "")))

static func _venue_credit(control: Control, photo: Dictionary) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.tooltip_text = "%s\nSource : %s\nLicence : %s" % [photo.get("credit", ""), photo.get("source", ""), photo.get("license", "")]
	control.accessibility_name = control.tooltip_text

static func _overview_city(card: Panel, identity: Dictionary) -> void:
	var photo: Dictionary = identity.get("photos", {}).get("city", {})
	if photo.is_empty(): return
	var picture := _venue_picture(identity, "city", false)
	if not picture.get_meta("photo_from_pack", false):
		picture.free()
		return
	var preview := D.panel(card, Rect2(696,16,217,290), "", "", "", "ClubOverviewCity")
	preview.clip_contents = true
	preview.add_child(picture)
	D.place(picture, Rect2(1,1,215,202))
	D.text(preview, 10, 225, "VILLE DU CLUB", 16, C.GOLD, 700, 197)
	var place: Variant = identity.get("city")
	if place is String and not place.is_empty(): D.text(preview, 10, 251, place, 24, C.IVORY, 700, 197)
	var credit := D.text(preview, 10, 275, photo.get("credit", ""), 17, C.MUTED, 500, 197)
	credit.name = "VenuePhotoCredit_city"
	_venue_credit(credit, photo)

static func _stadium(card: Panel, app: Control, fans: Dictionary) -> void:
	card.clip_contents = true
	var identity := G.identity(app.model.club)
	var stadium_art := str(identity.get("stadiumImage",""))
	var pack_id := str(app.model.get("packs",{}).get("career","base"))
	var allow_archive := pack_id != "base" and not stadium_art.is_empty() and ResourceLoader.exists("res://"+stadium_art)
	var picture := _venue_picture(identity, "stadium", allow_archive)
	var has_photo: bool = picture.get_meta("has_photo", false)
	var from_pack: bool = picture.get_meta("photo_from_pack", false)
	if has_photo:
		card.add_child(picture)
		D.place(picture, Rect2(1,1,932,386))
	else:
		picture.free()
		var illustration := C.photo("stadium", Vector2.ZERO, false)
		card.add_child(illustration)
		D.place(illustration, Rect2(1,1,932,345))
	var gradient := Gradient.new()
	# Le raccord de l’illustration à son cartouche se trouve sous le fondu opaque.
	gradient.offsets = PackedFloat32Array([0.0, .46, .86] if has_photo else [0.0, .37, .54])
	gradient.colors = PackedColorArray([Color("0c181700"), Color("0c1817d9"), Color("0c1817")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2.DOWN
	var shade := TextureRect.new()
	shade.name = "StadiumCaptionShade"
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	D.place(shade, Rect2(1,278,932,123))
	var media_label := "PHOTO DU PACK" if from_pack else "PHOTO D’ARCHIVE" if has_photo else "ILLUSTRATION"
	var media_chip := D.chip(card, Rect2(21,16,175,27), media_label, C.GOLD)
	if from_pack:
		var photo: Dictionary = identity.photos.stadium
		_venue_credit(media_chip, photo)
		var backing := D.rect(card, Rect2(205,16,472,27), Color("14211d"), 5, C.LINE)
		var credit := D.text(backing, 10, 19, photo.get("credit", ""), 17, C.MUTED, 500, 452)
		credit.name = "VenuePhotoCredit_stadium"
		_venue_credit(credit, photo)
	_overview_city(card, identity)
	D.text(card, 23, 348, str(G.identity(app.model.club).get("stadium", "Le stade du club")), 41, C.IVORY, 700, 598)
	U.icon(card, "people", Vector2(24,363), C.MUTED, 24)
	var attendance := "Affluence prévue " + G.n(fans.expectedAttendance) if fans.has("expectedAttendance") else "Affluence indisponible"
	var capacity := " · " + G.n(fans.capacity) + " places simulées" if fans.has("capacity") else ""
	D.text(card, 60, 385, attendance + capacity, 23, C.MUTED, 500, 535)
	D.button(card, Rect2(697,337,216,48), "Voir le stade", func(): _tab(app, "territory"), false, "arrow", false, U.GREEN, "ClubSeeStadium")

static func _trust(card: Panel, app: Control, finance: Dictionary) -> void:
	var width := card.size.x / C.density
	var inset := (width - 443.0) * .5
	var trust: Variant = app.model.meta.get("trust")
	var dial := TrustDial.new()
	dial.name = "ClubTrustDial"
	dial.trust = float(trust) if trust != null else 0.0
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dial)
	D.place(dial, Rect2(55+inset,60,332,174))
	var trust_text := G.n(trust) if trust != null else "—"
	var value_width := C.EXTRA_BOLD.get_string_size(trust_text,HORIZONTAL_ALIGNMENT_LEFT,-1,C.px(76)).x/C.density
	D.text(card, 205+inset, 222, trust_text, 76, C.IVORY, 800, 165, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(card, 210+inset+value_width/2, 221, "/100", 31, C.MUTED, 600, 80)
	var history: Array = finance.get("boardHistory", [])
	var recent: Dictionary = history[0] if not history.is_empty() else {}
	var caption := "Premier bilan à venir"
	var change_color := C.MUTED
	if not recent.is_empty():
		var delta := int(recent.after) - int(recent.previous)
		caption = "%+d pts · dernier bilan" % delta
		change_color = C.MINT if delta >= 0 else C.ALERT
	D.text(card, 221+inset, 270, caption, 26, change_color, 600, 400, HORIZONTAL_ALIGNMENT_CENTER)
	D.line(card, Vector2(20,291), Vector2(width-20,291))
	U.icon(card, "info", Vector2(22,306), C.GOLD, 23)
	D.text(card, 57, 328, "Confiance du président", 23, C.IVORY, 600, width-88)
	var source := "Saison %s · journée %s" % [G.n(recent.season), G.n(recent.round)] if not recent.is_empty() else "Le conseil suit les résultats du club."
	D.text(card, 57, 363, source, 22, C.MUTED, 500, width-93)

static func _goals(card: Panel, app: Control, board: Dictionary) -> void:
	var goals: Array = board.get("objectives", [])
	var metrics: Dictionary = board.get("metrics", {})
	var rank: Variant = metrics.get("rank", app.model.club.get("rank"))
	var division_size := 0
	for league: Dictionary in app.model.get("leagues",[]):
		if league.get("id") == app.model.meta.get("leagueId"): division_size = league.get("rows",[]).size()
	U.icon(card, "trophy", Vector2(22,76), C.GOLD, 32)
	var objective := D.text(card, 72, 103, app.model.club.get("goal", "Projet sportif"), 30, C.IVORY, 700, 400)
	var font := objective.get_theme_font("font")
	var offset := 0
	if font.get_string_size(objective.text, HORIZONTAL_ALIGNMENT_LEFT, -1, objective.get_theme_font_size("font_size")).x > objective.size.x:
		objective.add_theme_font_size_override("font_size", maxi(12, C.px(26)))
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		objective.max_lines_visible = 2
		objective.add_theme_constant_override("line_spacing", 0)
		objective.position.y = C.px(64)
		objective.size.y = C.px(65)
		offset = 20
	D.text(card, 72, 139 + offset, "Classement actuel", 23, C.MUTED, 500, 279)
	if rank != null:
		var position := "%s%s" % [G.n(rank),"er" if int(rank) == 1 else "e"]
		if division_size > 0:
			position += " / %d" % division_size
			D.bar(card, Rect2(72,145 + offset,263,6), 100.0*(division_size-int(rank)+1)/division_size)
		D.chip(card, Rect2(355,111 + offset,120,33), position, C.MINT)
	D.line(card, Vector2(19,158 + offset), Vector2(480,158 + offset))
	for i in mini(2, goals.size()):
		var goal: Dictionary = goals[i]
		var kind := str(goal.get("type",""))
		var status := str(goal.get("status","pending"))
		var hue := C.MINT if status == "met" else C.ALERT if status == "missed" else C.AMBER
		var y := 169 + offset + i * 84
		U.icon(card, "flag", Vector2(23,y+15), hue, 25)
		D.text(card, 72, y+28, GOALS.get(kind,"Jalon du conseil"), 25, C.IVORY, 700, 252)
		var target: Variant = goal.get("target")
		var value := G.euros(target) if kind == "cash" else G.n(target)
		D.text(card, 72, y+58, "%s · sem. %s" % [value,G.n(goal.get("deadline","—"))], 22, C.MUTED, 500, 263)
		D.chip(card, Rect2(344,y+12,130,32), GOAL_STATUS.get(status,status), hue)
		if metrics.has(kind) and target != null and float(target)>0.0 and kind != "rank":
			D.bar(card, Rect2(72,y+63,263,6), 100.0*float(metrics[kind])/float(target), hue)
		D.line(card, Vector2(19,y+75), Vector2(480,y+75), Color(C.LINE,.65))
	if goals.is_empty():
		U.icon(card, "flag", Vector2(23,179 + offset), C.GOLD, 25)
		D.text(card, 72, 201 + offset, "Aucun jalon enregistré", 26, C.IVORY, 600, 405)
		D.text(card, 72, 238 + offset, "Fixez une échéance avec la direction.", 22, C.MUTED, 500, 400)
	D.button(card, Rect2(21,351,457,36), "Suivre les objectifs", func(): _open_strategy(app, 1), false, "arrow", true, U.GREEN, "ClubBoardGoals")

static func _locker(card: Panel, app: Control) -> void:
	var relationship: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var leader := P.player(app.model, str(relationship.get("leaderId","")))
	var group := P.group(app.model)
	var morale: Variant = app.model.meta.get("morale")
	var rows := [
		["heart","Moral",G.n(morale)+" / 100" if morale != null else "—",C.MINT],
		["people","Disponibles","%d / %d" % [group.available,group.total],C.GOLD],
		["star","Leader du vestiaire",leader.get("name","À déterminer"),C.MINT]
	]
	for i in rows.size():
		var item: Array = rows[i]
		var y := 73 + i * 83
		U.icon(card, item[0], Vector2(20,y+13), item[3], 35)
		var title := D.text(card, 73, y+22, item[1], 22, C.IVORY, 500, 225)
		var value := D.text(card, 73, y+57, item[2], 29, item[3], 700, 228)
		if i == 2 and value.get_theme_font("font").get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size("font_size")).x > value.size.x:
			value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			value.max_lines_visible = 2
			value.add_theme_constant_override("line_spacing", 0)
			value.size.y = value.get_minimum_size().y
			value.position.y = maxf(value.position.y, title.position.y + title.size.y + 1.0)
		if i < 2: D.line(card, Vector2(20,y+72), Vector2(304,y+72), Color(C.LINE,.65))
	D.button(card, Rect2(20,351,284,36), "Entrer au vestiaire", func(): app._navigate("Vestiaire"), false, "arrow", true, U.GREEN, "ClubLockerAction")

static func _academy(model: Dictionary) -> Dictionary:
	return model.get("clubLife", {}).get("academyPathways", {})

static func _installations(card: Panel, app: Control, finance: Dictionary) -> void:
	var facility: Variant = finance.get("facility")
	var academy_level: Variant = _academy(app.model).get("facilities")
	var support: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
	var medical: Array = support.get("medical", {}).get("players", [])
	var rows := [
		["train","Centre d’entraînement","Installations du club",str(int(facility.level))+" / 10" if facility is Dictionary else "Niveau indisponible"],
		["heart","Cellule médicale","Dossiers suivis",str(medical.size()) if not support.is_empty() else "—"],
		["school","Académie","Installations du centre",G.n(academy_level)+" / 3" if academy_level != null else "Niveau indisponible"]
	]
	for i in rows.size():
		var row: Array = rows[i]
		var y := 71 + i * 82
		U.icon(card, row[0], Vector2(23,y+13), C.IVORY, 37)
		D.text(card, 82, y+32, row[1], 28, C.IVORY, 700, 480)
		D.text(card, 82, y+62, row[2], 22, C.MUTED, 500, 400)
		var level_unavailable := i == 0 and not facility is Dictionary or i == 2 and academy_level == null
		D.text(card, 686, y+37, row[3], 23 if level_unavailable else 29, C.MUTED if level_unavailable else C.MINT, 700, 210, HORIZONTAL_ALIGNMENT_RIGHT)
		if i != 1 and not level_unavailable:
			var total := 10 if i == 0 else 3
			var value := int(academy_level) if i == 2 else int(facility.level)
			for segment in total:
				var spacing := 13 if total == 10 else 30
				D.rect(card, Rect2(687-(total-segment)*spacing,y+50,spacing-3,10), C.MINT if segment < value else Color("2a3735"), 3)
		D.line(card, Vector2(19,y+72), Vector2(691,y+72), Color(C.LINE,.65))
	var action := D.button(card, Rect2(19,327,672,74), "Projets et devis des infrastructures", func(): _tab(app, "infrastructure", "ClubTab_infrastructure"), false, "arrow", false, U.GREEN, "ClubFacilityDetails")
	var style: StyleBox = D.surface(672,74,Color("302918"),Color("191b14"),C.GOLD,8).duplicate()
	style.content_margin_left = C.px(18)
	style.content_margin_right = C.px(18)
	action.add_theme_stylebox_override("normal", style)

static func _members(app: Control) -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id",-1)) == int(app.model.club.id): return team.get("members", [])
	return []

static func _staff(card: Panel, app: Control) -> void:
	var people := _members(app)
	for i in mini(4, people.size()):
		var person: Dictionary = people[i]
		var y := 67 + i * 75
		var path := str(person.get("portraitPath",""))
		if not path.is_empty() and G._pack_texture(path) != null:
			var portrait := G.portrait(0, C.px(82), person)
			card.add_child(portrait)
			D.place(portrait, Rect2(18,y,82,65))
		else:
			D.rect(card, Rect2(18,y,82,65), Color("24322e"), 4)
			U.icon(card, "people", Vector2(39,y+11), C.MUTED, 41)
		D.text(card, 116, y+24, person.get("role","Encadrement"), 22, C.MUTED, 500, 390)
		D.text(card, 116, y+54, person.get("name","—"), 28, C.IVORY, 700, 407)
		D.text(card, 685, y+39, "Archive" if person.get("historical",false) else "Référence", 20, C.GOLD, 500, 128, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card, Vector2(18,y+69), Vector2(690,y+69), Color(C.LINE,.62))
	if people.is_empty():
		D.text(card, 24, 119, "Annuaire indisponible pour cette carrière", 28, C.IVORY, 700, 660)
		D.text(card, 24, 157, "Les responsabilités du staff restent accessibles.", 23, C.MUTED, 500, 660)
	D.button(card, Rect2(18,373,321,40), "Ouvrir l’annuaire", func(): app._navigate("Staff"), false, "arrow", true, U.GREEN, "ClubStaffDirectory")
	D.button(card, Rect2(351,373,339,40), "Travail du club", func(): app._navigate("Travail du club"), false, "arrow", true, U.GREEN, "ClubStaffWork")

static func _fans(card: Panel, app: Control, strategy: Dictionary) -> void:
	var fans: Dictionary = strategy.get("fans", {})
	var sponsor: Dictionary = {}
	for option: Dictionary in strategy.get("sponsors", []):
		if option.get("selected",false): sponsor = option; break
	U.icon(card, "people", Vector2(22,81), C.IVORY, 38)
	U.icon(card, "shield", Vector2(418,81), C.IVORY, 38)
	D.text(card, 78, 91, "Sentiment des supporters", 22, C.MUTED, 500, 310)
	D.text(card, 78, 130, G.n(fans.sentiment)+" / 100" if fans.has("sentiment") else "—", 41, C.IVORY, 700, 315)
	D.line(card, Vector2(397,73), Vector2(397,134))
	D.text(card, 476, 91, "Abonnés simulés", 22, C.MUTED, 500, 291)
	D.text(card, 476, 130, fans.get("subscribers","—"), 41, C.IVORY, 700, 290)
	D.line(card, Vector2(19,151), Vector2(777,151), Color(C.LINE,.7))
	U.icon(card, "money", Vector2(23,175), C.GOLD, 35)
	D.text(card, 78, 181, "Partenaire principal", 22, C.MUTED, 500, 518)
	D.text(card, 78, 218, sponsor.get("label","Aucun partenaire signé"), 35, C.IVORY, 700, 536)
	D.button(card, Rect2(563,173,214,43), "Supporters", func(): _open_strategy(app, 2), false, "arrow", true, U.GREEN, "ClubSupporters")
	D.line(card, Vector2(19,235), Vector2(777,235))
	D.text(card, 23, 269, "Dernières nouvelles du club", 26, C.IVORY, 700, 755)
	var news: Array = app.model.get("messages", [])
	for i in mini(2,news.size()):
		var y := 284 + i * 54
		D.rect(card, Rect2(22,y,4,43), C.BLUE if i == 0 else C.MINT, 2)
		var lines := D.words(str(news[i]), 85, 2)
		for j in lines.size():
			var label := D.text(card, 39, y+19+j*21, lines[j], 19, C.MUTED, 500, 727)
			label.tooltip_text = str(news[i])
	if news.is_empty(): D.text(card, 23, 320, "Aucun message enregistré.", 23, C.MUTED, 500, 739)

static func _footer(card: Panel, app: Control, finance: Dictionary, board: Dictionary) -> void:
	U.icon(card, "calendar", Vector2(22,18), C.GOLD, 29)
	D.text(card, 63, 43, "PROCHAIN JALON DU CONSEIL", 29, C.IVORY, 700, 715)
	D.line(card, Vector2(22,59), Vector2(970,59))
	var pending: Array = board.get("objectives", []).filter(func(goal: Dictionary): return goal.get("status") == "pending")
	pending.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.deadline) < int(b.deadline))
	var goal: Dictionary = pending[0] if not pending.is_empty() else {}
	D.chip(card, Rect2(22,82,287,52), "SEMAINE " + G.n(goal.deadline) if not goal.is_empty() else "À PLANIFIER", C.MINT if not goal.is_empty() else C.GOLD)
	D.text(card, 329, 115, GOALS.get(str(goal.get("type","")),"Aucune échéance fixée"), 27, C.IVORY, 600, 620)
	D.line(card, Vector2(991,16), Vector2(991,153))
	U.icon(card, "money", Vector2(1015,18), C.GOLD, 29)
	D.text(card, 1059, 43, "BUDGET", 29, C.IVORY, 700, 610)
	D.line(card, Vector2(1015,59), Vector2(2226,59))
	var cash: Variant = finance.get("cash",app.model.club.get("cash"))
	D.text(card, 1030, 114, U.amount(cash), 43, C.ALERT if cash != null and float(cash)<0.0 else C.MINT, 700, 330)
	D.text(card, 1030, 144, "Trésorerie du jeu", 22, C.MUTED, 500, 315)
	D.text(card, 1366, 107, "Salaires par semaine", 22, C.MUTED, 500, 355)
	D.text(card, 1366, 142, G.euros(finance.get("weeklyWages",app.model.get("finance",{}).get("wage",0))), 28, C.IVORY, 600, 361)
	var action := D.button(card, Rect2(1750,77,476,73), "Présenter une demande à la direction", func(): _open_strategy(app, 1), true, "arrow", false, Color("966419"), "ClubBoardRequest")
	var style: StyleBox = D.surface(476,73,Color("ab771e"),Color("694610"),Color("e7bc63"),7).duplicate()
	style.content_margin_left = C.px(18)
	style.content_margin_right = C.px(18)
	action.add_theme_stylebox_override("normal", style)

static func _open_strategy(app: Control, index: int) -> void:
	app.management_ui.immersive08_strategy_tab = index
	app._navigate("Stratégie")

static func _direction(app: Control, canvas: Control) -> void:
	var data := U.strategy(app.model)
	var finance: Dictionary = data.get("finance",{})
	_trust(D.panel(canvas, Rect2(0,214,499,402), "La confiance du conseil", "shield"), app, finance)
	_goals(D.panel(canvas, Rect2(0,632,499,402), "Objectifs de la saison", "trophy"), app, data.get("board",{}))
	D.button(canvas, Rect2(0,1050,499,57), "Ouvrir les finances", func(): app._navigate("Finances"), false, "arrow", false, U.GREEN, "ClubDirectionFinance")
	var detail: Control = app.StrategyViews.build(app)
	var tabs: TabContainer = detail.find_child("StrategyTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_strategy_tab",1)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_strategy_tab = index)
	U.place_detail(canvas, Rect2(515,214,1733,1030), detail)
	Legacy.apply(detail, app.accent)

static func style_staff(detail: Control, accent: Color) -> void:
	Legacy.apply(detail, accent)
	for id in ["DelegateLineup", "DelegateTraining"]:
		var toggle := detail.find_child(id, true, false) as CheckBox
		if toggle != null: toggle.theme = detail.theme
	var clubs := detail.find_child("StaffClub", true, false) as OptionButton
	if clubs != null: clubs.get_popup().theme = detail.theme

static func _staff_detail(app: Control, canvas: Control) -> void:
	_staff(D.panel(canvas, Rect2(0,214,708,427), "L’encadrement", "people"), app)
	var diagnostic: Dictionary = app.model.get("clubLife",{}).get("clubSupport",{}).get("diagnostic",{})
	var card := D.panel(canvas, Rect2(0,657,708,360), "Diagnostic de la semaine", "heart", "", "ClubStaffDiagnostic")
	if diagnostic.is_empty():
		D.text(card, 24, 127, "Diagnostic indisponible dans cette carrière.", 28, C.MUTED, 600, 660)
	else:
		var rows := [["Condition moyenne",diagnostic.get("mean","—")],["Moral du groupe",diagnostic.get("morale","—")],["Joueurs sous 65 de condition",diagnostic.get("fatigue","—")]]
		for i in rows.size():
			var y := 104+i*60
			D.text(card, 24, y, rows[i][0], 26, C.IVORY, 600, 507)
			D.text(card, 683, y, rows[i][1], 30, C.MINT if i < 2 else C.AMBER, 700, 145, HORIZONTAL_ALIGNMENT_RIGHT)
			D.line(card, Vector2(24,y+16), Vector2(684,y+16), Color(C.LINE,.6))
		var reason := str(diagnostic.get("reason",""))
		var lines := D.words(reason,63,2)
		for i in lines.size(): D.text(card, 24, 291+i*30, lines[i], 23, C.MUTED, 500, 660)
	var detail: Control = app.StaffViews.build(app) if app.route == "Staff" else app.SupportViews.build(app)
	var tabs: TabContainer = detail.find_child("SupportTabs", true, false)
	if tabs != null:
		tabs.current_tab = clampi(int(app.management_ui.get("immersive08_support_tab",0)), 0, 2)
		tabs.tab_changed.connect(func(index: int): app.management_ui.immersive08_support_tab = index)
	U.place_detail(canvas, Rect2(724,214,1524,1030), detail)
	if app.route == "Staff": style_staff(detail, app.accent)
	else: Legacy.apply(detail, app.accent)

static func _history(app: Control, canvas: Control) -> void:
	var card := D.panel(canvas, Rect2(0,214,610,612), "Les archives du club", "trophy", "", "ClubHistorySummary")
	D.photo(card, "club-forest", Rect2(20,69,570,164))
	var data := History.project(app.model,int(app.model.club.id))
	var international: bool = app.model.meta.get("mode") == "world"
	if international: data.seasons = History.world_seasons(app,int(app.model.club.id))
	var titles := 0
	for year: Dictionary in data.seasons: titles += year.get("titles",[]).size()
	var rows := [["Saisons archivées",data.seasons.size()],["Titres conservés",titles],["Rencontres au registre récent",data.events.size()]]
	for i in rows.size():
		var y := 278+i*73
		D.text(card, 24, y, rows[i][0], 29, C.IVORY, 600, 475)
		D.text(card, 586, y, rows[i][1], 35, C.MINT, 700, 118, HORIZONTAL_ALIGNMENT_RIGHT)
		D.line(card, Vector2(24,y+18), Vector2(586,y+18), Color(C.LINE,.6))
	D.button(card, Rect2(24,520,562,58), "Ouvrir les compétitions", func(): app._navigate("Classements"), false, "arrow", false, U.GREEN, "ClubHistoryCompetitions")
	if international: _world_history(app,canvas,data)
	else: U.place_detail(canvas, Rect2(626,214,1622,1030), History.build(app))

static func _world_history(app: Control, canvas: Control, data: Dictionary) -> void:
	var card := D.panel(canvas,Rect2(626,214,1622,1030),"L’histoire de "+str(data.club_name),"trophy","","CarnetClubMemory")
	var scroll := ScrollContainer.new()
	scroll.name = "ClubMemoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	card.add_child(scroll)
	D.place(scroll,Rect2(22,69,1578,939))
	var list := C.v(15)
	C.fill(list)
	scroll.add_child(list)
	var years: Array = data.seasons
	list.add_child(C.wrap("Saisons archivées et rencontres conservées dans cette carrière. Les rangs concernent la phase régulière.",22,C.MUTED,true))
	if years.size() >= 2: _world_comparison(app,list,years)
	if years.is_empty(): list.add_child(C.wrap("Aucune saison archivée pour ce club.",26,C.IVORY,true,700))
	for year: Dictionary in years: list.add_child(_world_year(app,year))
	list.add_child(C.rule())
	list.add_child(C.label("LES RENCONTRES CONSERVÉES",27,C.GOLD,true,700))
	if data.events.is_empty(): list.add_child(C.wrap("Aucun résultat de ce club dans le registre récent.",22,C.MUTED,true))
	for event: Dictionary in data.events:
		var result := C.card("Saison %s · %s" % [G.n(event.get("season","—")),World.name_for(app.model,str(event.get("leagueId","")))])
		list.add_child(result)
		var notes := C.content(result)
		notes.add_child(C.wrap("%s  %s – %s  %s" % [event.home_name,G.n(event.get("home","—")),G.n(event.get("away","—")),event.away_name],27,C.IVORY,true,700))
		if event.get("winner") != null and event.get("home") == event.get("away"):
			notes.add_child(C.wrap("Vainqueur après départage : "+str(event.get("winner_name","—")),22,C.GOLD,true))
		if not str(event.get("reaction","")).is_empty():
			notes.add_child(C.wrap("Réaction simulée · %s  « %s »" % [event.get("reaction_club_name","Banc"),event.reaction],21,C.MUTED,true))
	list.add_child(C.rule())
	list.add_child(C.label("LE PARCOURS DU COACH",27,C.GOLD,true,700))
	if data.manager_current_from != null: list.add_child(C.label("Mandat actuel depuis la saison "+G.n(data.manager_current_from),24))
	if data.manager_history.is_empty(): list.add_child(C.wrap("Aucune prise de poste antérieure enregistrée.",22,C.MUTED,true))
	for move: Dictionary in data.manager_history:
		list.add_child(C.wrap("Saison %s · %s  →  %s" % [G.n(move.get("arrivalSeason","—")),move.from_name,move.to_name],23,C.IVORY,true))

static func _world_year(app: Control, year: Dictionary) -> PanelContainer:
	var card := C.card("Saison "+G.n(year.season))
	C.fill(card)
	var content := C.content(card)
	var rank := "%s · rang %s / %s" % [World.name_for(app.model,str(year.league_id)),G.n(year.rank),G.n(year.division_size)] if year.rank != null else "Rang de phase régulière indisponible"
	content.add_child(C.wrap(rank,25,C.IVORY,true,600))
	for id: String in year.titles:
		content.add_child(C.wrap("Champion · "+World.name_for(app.model,id),23,C.MINT,true,600))
	if year.promoted: content.add_child(C.label("Montée en Élite",22,C.MINT))
	if year.relegated: content.add_child(C.label("Descente en Accession",22,C.AMBER))
	for line: String in year.get("nationale_lines",[]): content.add_child(C.wrap(line,22,C.IVORY))
	for barrage: Dictionary in year.japan_barrages:
		for line: String in World.japan_lines(app,barrage): content.add_child(C.wrap(line,22,C.IVORY))
	return card

static func _world_comparison(app: Control, list: VBoxContainer, years: Array) -> void:
	var panel := C.card("Comparer deux saisons")
	list.add_child(panel)
	var contents := C.content(panel)
	var selectors := C.h(16)
	var comparison := C.h(16)
	contents.add_child(selectors)
	contents.add_child(comparison)
	var indexes := [0,1]
	var redraw := func():
		for child in comparison.get_children():
			comparison.remove_child(child)
			child.queue_free()
		for index: int in indexes: comparison.add_child(_world_year(app,years[index]))
	for i in 2:
		var key := "club_memory_season_a" if i == 0 else "club_memory_season_b"
		var selector := OptionButton.new()
		selector.name = "ClubMemorySeasonA" if i == 0 else "ClubMemorySeasonB"
		selector.custom_minimum_size.y = C.px(40)
		C.fill(selector)
		var chosen := int(app.management_ui.get(key,years[i].season))
		for year: Dictionary in years:
			selector.add_item("Saison "+G.n(year.season),int(year.season))
			if int(year.season) == chosen: indexes[i] = selector.item_count-1
		selector.select(indexes[i])
		selectors.add_child(selector)
		selector.item_selected.connect(func(index: int):
			indexes[i] = index
			app.management_ui[key] = int(years[index].season)
			redraw.call())
	redraw.call()

static func _territory(app: Control, canvas: Control) -> void:
	var page := Control.new()
	page.name = "ClubTerritory"
	canvas.add_child(page)
	D.place(page, Rect2(0,214,2248,1030))
	var identity := G.identity(app.model.club)
	for i in 2:
		var kind := "stadium" if i == 0 else "city"
		var panel := D.panel(page, Rect2(i*1132,0,1116,821), "Le stade" if i == 0 else "Le territoire", "home")
		var picture := _venue_picture(identity, kind)
		var from_pack: bool = picture.get_meta("photo_from_pack", false)
		var caption := "Photographie d’archive · crédits accessibles"
		if picture.get_meta("has_photo", false):
			panel.add_child(picture)
			D.place(picture, Rect2(16,68,1084,642))
		else:
			picture.free()
			D.photo(panel, "stadium" if i == 0 else "club-forest", Rect2(16,68,1084,642))
			caption = "Illustration fictive"
		D.text(panel, 24, 760, identity.get("stadium",app.model.club.get("stadium","Le stade")) if i == 0 else identity.get("city","Le territoire"), 43, C.IVORY, 700, 1064)
		var photo: Dictionary = identity.get("photos", {}).get(kind, {})
		var credit := D.text(panel, 24, 798, "Photo · " + str(photo.get("credit", "")) if from_pack else caption, 23, C.MUTED, 500, 1064)
		if from_pack:
			credit.name = "VenuePhotoCredit_" + kind
			_venue_credit(credit, photo)
	var links := D.panel(page, Rect2(0,837,2248,193), "Un territoire, une identité", "shield")
	D.text(links, 24, 116, "Retrouvez les archives du territoire et écrivez la suite de l’histoire du club.", 31, C.IVORY, 600, 1360)
	D.button(links, Rect2(1415,80,373,59), "Crédits et licences", app._credits, false, "info", false, U.GREEN, "ClubAtlasCredits")
	D.button(links, Rect2(1804,80,420,59), "Revenir à la vue d’ensemble", func(): _tab(app, "overview", "ClubTab_overview"), true, "arrow", false, U.GREEN, "ClubAtlasBack")

static func _infrastructure_detail(app: Control, canvas: Control) -> void:
	var data := U.strategy(app.model)
	var finance: Dictionary = data.get("finance",{})
	_installations(D.panel(canvas, Rect2(0,214,712,427), "Infrastructures", "train"), app, finance)
	_stadium(D.panel(canvas, Rect2(0,657,934,402), "", ""), app, data.get("fans",{}))
	var projects := D.panel(canvas, Rect2(950,214,1298,845), "Les moyens du club", "settings", "", "ClubFacilityProjects")
	var quote: Variant = finance.get("facility")
	if quote is Dictionary:
		D.text(projects, 24, 109, "Installations du club · niveau %s / 10" % G.n(quote.level), 39, C.IVORY, 700, 1244)
		D.text(projects, 24, 154, "Niveau suivant %s · %s" % [G.n(quote.nextLevel),G.euros(quote.cost)], 30, C.GOLD, 600, 1244)
		var action := D.button(projects, Rect2(24,185,450,51), "Examiner le devis", func(): Strategy._send(app, "club_facility_upgrade", {"cost":quote.cost,"level":quote.level}, "Investir %s pour passer les installations au niveau %s ?" % [G.euros(quote.cost),G.n(quote.nextLevel)]), true, "arrow", false, U.GREEN, "ClubFacilityQuote")
		action.disabled = not data.get("available",false) or app.waiting or app.model.meta.get("trained",false) or app.model.meta.get("phase","") != "league" or quote.used or not quote.affordable
		var reason := "Un investissement par saison · avant la séance de la semaine."
		if quote.used: reason = "Une amélioration a déjà été engagée cette saison."
		elif not quote.affordable: reason = "La trésorerie disponible est insuffisante pour ce devis."
		D.text(projects, 24, 269, reason, 24, C.MUTED, 500, 1228)
	else: D.text(projects, 24, 126, "Aucun devis d’installations disponible.", 31, C.MUTED, 600, 1228)
	D.line(projects, Vector2(24,296), Vector2(1274,296))
	D.text(projects, 24, 346, "Centre de formation", 36, C.IVORY, 700, 1228)
	D.text(projects, 24, 385, "L’investissement hebdomadaire suit la séance de formation.", 24, C.MUTED, 500, 1228)
	D.button(projects, Rect2(24,411,450,51), "Ouvrir le centre de formation", func(): app._navigate("Centre"), false, "arrow", false, U.GREEN, "ClubAcademyFacilities")
	D.line(projects, Vector2(24,488), Vector2(1274,488))
	D.text(projects, 24, 537, "Cellule médicale", 36, C.IVORY, 700, 1228)
	D.text(projects, 24, 576, "Protocoles et décisions de retour des joueurs suivis.", 24, C.MUTED, 500, 1228)
	D.button(projects, Rect2(24,602,450,51), "Ouvrir le travail du club", func(): app._navigate("Travail du club"), false, "arrow", false, U.GREEN, "ClubFacilityMedical")
	D.button(projects, Rect2(24,760,450,51), "Décisions d’investissement", func(): _open_strategy(app, 0), false, "arrow", false, U.GREEN, "ClubFacilityStrategy")
