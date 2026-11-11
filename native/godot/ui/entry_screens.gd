extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const Packs = preload("res://ui/pack_views.gd")
const Club = preload("res://ui/club_views.gd")
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const CREATION_SELECTION := "creation_selection"
const TROPHIES := ["elite", "accession", "nationale", "prem", "champ", "champions", "challenge", "urc", "srp", "jlo-d1", "jlo-d2", "jlo-d3"]
const ARCHIVE_TROPHIES := ["eng-third", "jp-national", "jp-top-league", "jp-company", "sr-au", "sr-nz", "sr-trans-tasman", "other"]

class RatingRail extends Control:
	var value: float
	var tint: Color

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("384440"))
		draw_rect(Rect2(0, 0, size.x * clampf(value / 100.0, 0.0, 1.0), size.y), tint)

class PositionRank extends Control:
	var rank: int
	var clubs: int
	var tint: Color

	func _draw() -> void:
		var step := size.x / maxf(1, clubs)
		var gap := minf(3, step * .2)
		for index in clubs:
			var active := index + 1 == rank
			var height := size.y if active else size.y * .42
			draw_rect(Rect2(index * step, (size.y - height) / 2, step - gap, height), tint if active else Color("3c4944"))

static func _cover(club: Dictionary) -> Control:
	var identity := G.identity(club)
	if not club.is_empty(): return G.club_picture(club)
	var cover := ColorRect.new()
	cover.color = Color(identity.get("color", "#303c42")).darkened(.72)
	var inset := G.margin(12)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(inset)
	var content := G.v(8)
	inset.add_child(content)
	cover.set_meta("content", content)
	return cover

static func _territory(club: Dictionary) -> String:
	if club.get("country") == "JP": return str({"kanto":"Kantō, Japon", "chubu":"Chūbu, Japon", "kansai":"Kansai, Japon", "ouest":"Ouest du Japon"}.get(club.get("region", ""), "Japon"))
	if str(club.get("region", "")).begins_with("champ-"): return str(club.get("city", "Angleterre"))
	if str(club.get("region", "")).begins_with("nat-"): return str(club.get("city", {"nat-sud-ouest":"Sud-Ouest, France", "nat-atlantique":"Façade atlantique, France", "nat-alpes":"Arc alpin, France", "nat-nord":"Nord et Centre, France"}.get(club.get("region", ""), "France")))
	return str(club.get("city", {"GB":"Royaume-Uni","IE":"Irlande","IT":"Italie","ZA":"Afrique du Sud","GE":"Géorgie","FR":"France","NZ":"Nouvelle-Zélande","AU":"Australie","FJ":"Fidji"}.get(club.get("country"), "")))

static func home(app: Control) -> Control:
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	var page := _cover(club)
	page.name="CarnetHome"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02,0.04,0.06,0.78))
	gradient.set_color(1, Color(0.02,0.04,0.06,0.45))
	gradient.add_point(0.60, Color(0.02,0.04,0.06,0.12))
	var shade := GradientTexture2D.new()
	shade.gradient=gradient
	shade.fill_from=Vector2(0,0.5)
	shade.fill_to=Vector2(1,0.5)
	veil.texture=shade
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(veil)
	page.move_child(veil, page.get_child_count() - 2)
	var over: VBoxContainer = page.get_meta("content")
	over.add_child(G.label("OVAL LEGACY 27  /  BUILD YOUR CLUB. LEAVE YOUR MARK.", 14, G.WHITE))
	over.add_child(G.spacer())
	var row := G.h(28)
	over.add_child(row)
	var intro := G.v(4)
	G.fill(intro)
	row.add_child(intro)
	var logo := TextureRect.new()
	logo.texture = load("res://branding/oval-legacy-27-logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(360, 180)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	logo.tooltip_text = "Oval Legacy 27 — Rugby Manager"
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	logo.material = composite
	intro.add_child(logo)
	intro.add_child(G.wrap("Un club. Un territoire.\nUne saison à écrire.", 26, G.WHITE))
	var choices := G.panel(row)
	choices.get_parent().custom_minimum_size.x=380
	choices.get_parent().size_flags_horizontal=Control.SIZE_SHRINK_END
	choices.add_child(G.section("Ouvrir le carnet","Votre prochain chapitre commence ici."))
	choices.add_child(G.separator())
	if not club.is_empty():
		var national: bool = app.Immersive.Selections.nation_only(app.model)
		var team: Dictionary = app.Immersive.Selections.managed_team(app.model)
		var identity := G.h(12)
		choices.add_child(identity)
		identity.add_child(app.Immersive.Selections.nation_badge(team, 44) if national else G.crest(club, 44))
		var current := G.v(1)
		G.fill(current)
		identity.add_child(current)
		current.add_child(G.label("CARNET EN COURS", 11, G.GOLD))
		current.add_child(G.wrap("Sélection nationale" if national else str(G.identity(club).get("city", "Votre territoire")), 18, G.INK))
		choices.add_child(G.label("VOTRE CARRIÈRE", 12, G.GOLD))
		choices.add_child(G.wrap(str(team.get("name", "Sélection")) if national else G.club_name(club), 26, G.INK))
		choices.add_child(G.label("Saison %s · %s" % [G.n(app.model.meta.get("season", 1)), app.model.meta.get("roundLabel", "Journée " + G.n(int(app.model.meta.get("round", 0)) + 1))], 12, G.MUTED))
		choices.add_child(G.button("REPRENDRE LA CARRIÈRE  →", func(): app._navigate("Réception"), true))
	var locked:bool=app.model.is_empty() or app.model.get("meta",{}).get("recoveryRequired",false)
	var new_career:=G.button("NOUVELLE CARRIÈRE", func(): begin_creation(app), club.is_empty())
	new_career.disabled=locked
	choices.add_child(new_career)
	var importing:=G.button("IMPORTER UNE CARRIÈRE", func(): app.open_file(true))
	importing.disabled=locked
	choices.add_child(importing)
	choices.add_child(G.button("PARAMÈTRES", app.settings))
	choices.add_child(G.button("QUITTER", app.request_quit))
	Packs.missing_warning(app, choices, "all",true)
	var meta: Dictionary = app.model.get("meta", {})
	if meta.get("recoveryRequired", false):
		choices.add_child(G.wrap("Le profil ne peut pas être chargé. Sa copie sera conservée avant toute récupération.", 13, G.ALERT))
		choices.add_child(G.button("RÉCUPÉRER LE PROFIL", app.recover_profile))
	elif app.connection_error or not app.last_error.is_empty():
		choices.add_child(G.wrap(app.last_error, 13, G.ALERT))
		choices.add_child(G.button("RÉESSAYER LA CONNEXION", app.reconnect) if app.connection_error else G.button("CHOISIR À NOUVEAU UN CLUB",func():app._navigate("Création")))
	over.add_child(G.spacer())
	var footer := G.h()
	over.add_child(footer)
	var note := G.label("VERSION DE DÉVELOPPEMENT %s  ·  APPLICATION WINDOWS NATIVE" % str(ProjectSettings.get_setting("application/config/version", "")), 12, G.WHITE)
	G.fill(note)
	footer.add_child(note)
	footer.add_child(G.button("CRÉDITS", app._credits))
	return page

const CREATION_COUNTRIES := {
	"FR": ["France", preload("res://art/flags/fr.svg")],
	"GB": ["Angleterre", preload("res://art/flags/gb-eng.svg")],
	"JP": ["Japon", preload("res://art/flags/jp.svg")],
	"international": ["International", null],
}
const CREATION_COUNTRY_SCOPES := {
	"FR": "Championnats de France",
	"GB": "Championnats d’Angleterre",
	"JP": "Championnats du Japon",
	"international": "Championnats internationaux",
}

# Format joué par le moteur du Monde complet pour la première saison.
const CREATION_FORMATS := {
	"elite": ["26 matchs par club, en aller-retour. Les six premiers disputent les phases finales.", "Le dernier descend. Le 13e dispute un barrage contre le finaliste de deuxième division."],
	"accession": ["30 matchs par club, en aller-retour. Les six premiers disputent les phases finales.", "Le champion monte en première division et le finaliste joue un barrage. Le dernier descend et le 15e joue un barrage chez le finaliste de troisième division."],
	"nationale": ["26 matchs par club, en aller-retour. Les six premiers disputent les phases finales.", "Le champion monte en deuxième division. Le finaliste reçoit le 15e de deuxième division pour un barrage."],
	"prem": ["18 matchs par club, en aller-retour. Les quatre premiers jouent les demi-finales.", "Le jeu conserve les mêmes clubs dans les deux divisions anglaises."],
	"champ": ["26 matchs par club, en aller-retour. Les six premiers disputent les phases finales.", "Le jeu conserve les mêmes clubs dans les deux divisions anglaises."],
	"jlo-d1": ["18 matchs par club. Les six premiers disputent les phases finales.", "Les deux derniers du classement final jouent des barrages aller-retour contre les deux premiers de Division 2."],
	"jlo-d2": ["14 matchs par club, en aller-retour. Le premier au classement est champion.", "Les deux premiers disputent des barrages aller-retour contre des clubs de Division 1."],
	"urc": ["18 matchs par club, dont trois rencontres régionales retour. Les huit premiers accèdent aux quarts de finale.", "Le jeu conserve les participants d’une saison à l’autre."],
	"srp": ["16 matchs par club. Les six premiers disputent les phases finales.", "Le jeu conserve les participants d’une saison à l’autre."],
}

static func begin_creation(app: Control) -> void:
	app.management_ui.erase(CREATION_SELECTION)
	app.management_ui.erase("creation_role")
	app.management_ui.erase("creation_nation")
	app.management_ui.erase("creation_vary_current")
	app._navigate("Création")

static func _creation_country(club: Dictionary) -> String:
	if club.get("division") in ["urc", "srp"]: return "international"
	return str(club.get("country", "FR"))

static func _division(app: Control, id: String, clubs: Array, mode: String) -> void:
	var changed: bool = app.club_division != id
	app.club_division = id
	if app.pack_manager.creation_mode == "auto":
		if changed: app.management_ui.erase(CREATION_SELECTION)
	elif not clubs.any(func(club: Dictionary): return int(club.id) == app.selected_club):
		app.selected_club = int(clubs[0].id)
		app.management_ui["creation_" + mode + "_" + id] = {"page":0}
	app._render()

static func _select_club(app: Control, id: int, modern: bool) -> void:
	app.selected_club = id
	if not modern:
		app._render()
		return
	var old_list := app.find_child("CreationClubsScroll", true, false) as ScrollContainer
	var scroll := old_list.scroll_vertical
	var focus := app.get_viewport().gui_get_focus_owner()
	var restore_focus := focus != null and str(focus.name) == "CreationClub" + str(id)
	app.management_ui[CREATION_SELECTION] = id
	app._render()
	var list := app.find_child("CreationClubsScroll", true, false) as ScrollContainer
	await app.get_tree().process_frame
	if not is_instance_valid(list) or not list.is_inside_tree(): return
	if restore_focus:
		var button := list.find_child("CreationClub" + str(id), true, false) as Button
		if button != null: button.grab_focus()
	list.scroll_vertical = scroll

static func _competition_identity(app: Control, id: String) -> Dictionary:
	if app.pack_manager.has_method("competition"): return app.pack_manager.competition(id, "creation")
	return {}

static func _competition_summary(app: Control, parent: VBoxContainer, division: String, club_count: int, photo_height: float) -> void:
	var identity := _competition_identity(app, division)
	var title := str(identity.get("name", Club.competition_name(division)))
	var illustration := C.photo("maquette-onglets-stadium", Vector2.ZERO, true, .5)
	illustration.custom_minimum_size.y = photo_height
	parent.add_child(illustration)
	var row := C.h(14)
	parent.add_child(row)
	var logo := str(identity.get("logoPath", ""))
	if not logo.is_empty(): row.add_child(G.crest({"logoPath":logo, "name":title}, 60))
	var heading := C.wrap(title, 44, C.IVORY, true, 700)
	heading.name = "CreationCompetitionSummary"
	G.fill(heading)
	row.add_child(heading)
	parent.add_child(C.rule())
	var facts := C.h(18)
	parent.add_child(facts)
	Editorial.fact(facts, club_count, "Clubs du championnat")
	Editorial.divider(facts)
	Editorial.fact(facts, "2027" if division == "srp" else "2026–27", "Saison de départ")
	var format: Array = CREATION_FORMATS.get(division, [])
	if not format.is_empty():
		parent.add_child(C.rule())
		parent.add_child(C.label("FORMAT ET ENJEUX", 21, Editorial.BRASS))
		for detail: String in format: parent.add_child(C.wrap(detail, 23, C.IVORY))
	parent.add_child(C.wrap("Choisissez un club pour découvrir son stade et son effectif.", 21))

static func _rating(roster: Dictionary) -> String:
	return String.num(float(roster.get("average", 0)), 1).replace(".", ",")

static func _creation_crest(club: Dictionary, width: int, use_mockup: bool) -> Control:
	if use_mockup and int(club.id) == 0:
		var crest := C.photo("maquette-onglets-toulouse", Vector2.ZERO, false)
		crest.custom_minimum_size = Vector2(width, width)
		crest.tooltip_text = G.club_name(club)
		return crest
	return G.crest(club, width)

static func _club_preview(app: Control, parent: VBoxContainer, club: Dictionary, championship: String, base_identity: bool) -> void:
	var toulouse := base_identity and int(club.id) == 0
	var compact := app.get_window().size.y < 850
	var history: Dictionary = club.get("history", {})
	var results: Array = history.get("results", [])
	var hero := C.h(16)
	parent.add_child(hero)
	var identity := C.h(12)
	hero.add_child(C.fill(identity, false, .53))
	var crest := _creation_crest(club, C.px(105), base_identity)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(crest)
	var copy := C.v(2)
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	G.fill(copy)
	identity.add_child(copy)
	var title_text := "Toulouse\nCapitole XV" if toulouse else G.club_name(club)
	var title := C.wrap(title_text, 42, C.IVORY, true, 800)
	title.name = "CreationClubTitle"
	title.uppercase = true
	title.add_theme_constant_override("line_spacing", -C.px(5))
	copy.add_child(title)
	copy.add_child(C.wrap(_territory(club), 20, C.IVORY))
	if history.has("founded"):
		var founded := C.label("Fondé en %d" % int(history.founded), 19, Editorial.RAIL_GOLD, true, 700)
		founded.name = "CreationClubFounded"
		copy.add_child(founded)
	var photo := G.club_picture(club, "stadium", false)
	photo.name = "CreationStadium"
	photo.custom_minimum_size.y = C.px(118 if compact else 154)
	photo.mouse_filter = Control.MOUSE_FILTER_PASS
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var venue := str(club.get("stadium", ""))
	if photo.tooltip_text.is_empty(): photo.tooltip_text = venue
	elif not venue.is_empty(): photo.tooltip_text = "%s\n%s" % [venue, photo.tooltip_text]
	var stadium := C.v(2)
	hero.add_child(C.fill(stadium, false, .47))
	stadium.add_child(photo)
	if not venue.is_empty(): stadium.add_child(C.wrap(venue, 16, C.MUTED))
	var roster: Dictionary = club.get("startingRoster", {})
	if not compact: parent.add_child(C.rule())
	var metrics := C.h(12)
	parent.add_child(metrics)
	if not roster.is_empty():
		var summary := _dossier_fact(metrics, "Note moyenne", _rating(roster), "rating", compact)
		summary.name = "CreationRosterSummary"
		_rating_rail(summary, float(roster.average), Editorial.RAIL_GOLD)
	_dossier_fact(metrics, "Objectif du conseil", str(club.get("goal", "Développer le projet sportif")), "target", compact)
	if club.has("cashMillions"):
		_dossier_fact(metrics, "Trésorerie de départ", G.euros(roundi(float(club.cashMillions) * 1_000_000)), "money", compact)
	parent.add_child(C.rule())
	parent.add_child(C.label("LE CLUB", 19, Editorial.RAIL_GOLD, true, 700))
	var city := str(club.get("city", "")).strip_edges()
	var introduction := str(history.get("bio", ""))
	if introduction.is_empty():
		introduction = "%s débute la saison en %s." % [G.club_name(club), championship]
		if not city.is_empty() and not venue.is_empty():
			introduction += " À %s, ses matchs à domicile se jouent à « %s »." % [city, venue]
	var presentation := C.wrap(introduction, 19, C.IVORY)
	presentation.name = "CreationClubPresentation"
	parent.add_child(presentation)
	if not compact: parent.add_child(C.rule())
	if not results.is_empty():
		_dossier_honours(app, parent, results, compact)
		parent.add_child(C.rule())
	if not str(roster.get("strengths", "")).is_empty():
		var comparison := C.h(18)
		comparison.name = "CreationComparison"
		parent.add_child(comparison)
		var strength: Dictionary = roster.strengthDetail
		_dossier_position(comparison, str(roster.strengths), strength, true, compact)
		if not str(roster.get("needs", "")).is_empty():
			Editorial.divider(comparison)
			var weakness: Dictionary = roster.weaknessDetail
			_dossier_position(comparison, str(roster.needs), weakness, false, compact)
	if app.get_window().size.y >= 1200:
		var spare := Control.new()
		spare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(C.fill(spare, true))
		var city_picture := G.club_picture(club, "city", false)
		city_picture.name = "CreationCity"
		city_picture.custom_minimum_size = Vector2.ZERO
		city_picture.hide()
		spare.add_child(city_picture)
		city_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		spare.resized.connect(func(): city_picture.visible = spare.size.y >= spare.size.x * .18)

static func _history_competition(app: Control, id: String) -> String:
	var historical := {
		"eng-third": "Troisième division anglaise",
		"jlo-d3": "Troisième division japonaise",
		"jp-top-league": "Ancienne élite japonaise",
		"jp-company": "Championnat national des entreprises",
		"jp-national": "Championnat national du Japon",
		"jp-top-challenge": "Ancienne deuxième division japonaise",
		"sr-au": "Championnat australien 2020–21",
		"sr-nz": "Championnat néo-zélandais 2020–21",
		"sr-trans-tasman": "Championnat trans-tasman 2021",
	}
	var label := str(_competition_identity(app, id).get("name", historical.get(id, Club.competition_name(id))))
	if id == "elite" and label.to_lower() == "top 14": return "Championnat de France"
	return label

static func _history_placement(result: Dictionary) -> String:
	var year := int(result.get("year", 0))
	var rank := int(result.get("rank", 0))
	var finish := str({"final":"Finaliste", "semi":"Demi-finaliste", "quarter":"Quart de finaliste"}.get(result.get("finish"), ""))
	if rank > 0: finish = "%s place" % ("1re" if rank == 1 else "%de" % rank)
	return finish + (" · %d" % year if year > 0 else "")

static func _trophy_texture(competition: String) -> Texture2D:
	var index := TROPHIES.find(competition)
	var current := index >= 0
	if not current:
		index = ARCHIVE_TROPHIES.find(competition)
		if index < 0: index = ARCHIVE_TROPHIES.size() - 1
	var path := "res://art/trophies/competitions.png" if current else "res://art/trophies/archives.png"
	if not ResourceLoader.exists(path): return C.icon_texture("trophy", Editorial.RAIL_GOLD)
	var source := load(path) as Texture2D
	var cell := source.get_size() / Vector2(4, 3 if current else 2)
	var tile := AtlasTexture.new()
	tile.atlas = source
	tile.region = Rect2(Vector2(index % 4, floori(index / 4.0)) * cell, cell)
	tile.filter_clip = true
	return tile

static func _dossier_honours(app: Control, parent: VBoxContainer, results: Array, compact: bool) -> void:
	parent.add_child(C.label("PALMARÈS", 19, Editorial.RAIL_GOLD, true, 700))
	var honours := GridContainer.new()
	honours.name = "CreationHonours"
	var dense := app.get_window().size.y < 1080 and results.size() > 4
	honours.columns = 3 if results.size() == 3 or (results.size() > 4 and not dense) else 2
	honours.add_theme_constant_override("h_separation", C.px(6))
	honours.add_theme_constant_override("v_separation", C.px(4))
	parent.add_child(honours)
	for result: Dictionary in results:
		var competition := str(result.competition)
		var count := int(result.get("titles", 0))
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", C.box(Color("182322"), C.LINE, 3, 1 if dense else 3))
		honours.add_child(C.fill(frame))
		var row := C.h(5)
		frame.add_child(row)
		if count > 0:
			var trophy := TextureRect.new()
			trophy.name = "CreationTrophy_" + competition
			trophy.texture = _trophy_texture(competition)
			trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var edge := C.px(32 if dense else 42 if compact else 72)
			trophy.custom_minimum_size = Vector2(edge, edge)
			trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(trophy)
		var label := _history_competition(app, competition)
		var year := int(result.get("year", 0))
		var record := "%d titre%s" % [count, "s" if count > 1 else ""] if count > 0 else _history_placement(result)
		if (compact or dense) and count > 0 and year > 0: record += " · %d" % year
		if dense:
			var caption := C.wrap("%s · %s" % [label, record], 16, C.IVORY, true, 700)
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(C.fill(caption))
			continue
		var copy := C.v(0)
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(C.fill(copy))
		copy.add_child(C.wrap(label, 17, C.IVORY, true, 700))
		if count > 0:
			copy.add_child(C.wrap(record, 25, Editorial.RAIL_GOLD, true, 800))
			if not compact and year > 0:
				copy.add_child(C.wrap("Dernier en %d" % year if count > 1 else str(year), 16, C.MUTED, true))
		else:
			copy.add_child(C.wrap(record, 18, C.MUTED, true, 700))

static func _rating_rail(parent: Container, value: float, tint: Color) -> void:
	var rail := RatingRail.new()
	rail.name = "CreationRatingRail"
	rail.value = value
	rail.tint = tint
	rail.custom_minimum_size.y = maxi(2, C.px(5))
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.resized.connect(rail.queue_redraw)
	parent.add_child(rail)

static func _dossier_position(parent: Container, position: String, detail: Dictionary, strength: bool, compact: bool) -> void:
	var starters: Dictionary = detail.starters
	var reserves: Dictionary = detail.reserves
	var clubs := int(detail.clubs)
	var starter_rank := int(starters.rank)
	var reserve_rank := int(reserves.rank)
	var starter_gap := int(starters.expected) - int(starters.filled)
	var reserve_gap := int(reserves.expected) - int(reserves.filled)
	var mid_table := ceili(clubs / 2.0)
	var complete := starter_gap == 0 and reserve_gap == 0
	var heading := "Atout actuel" if strength else ("Marge de progression" if complete and maxi(starter_rank, reserve_rank) <= mid_table else "Point à renforcer")
	var tint := Color("a5c78f") if strength else Color("d79a7a")
	var column := C.v(2)
	parent.add_child(C.fill(column))
	if compact:
		column.add_child(C.wrap(heading + " · " + position, 22, Editorial.RAIL_GOLD, true, 700))
	else:
		column.add_child(C.wrap(heading, 17, C.IVORY))
		column.add_child(C.wrap(position, 24, tint, true, 700))
	_position_rank(column, "Titulaires", starters, clubs, tint)
	_position_rank(column, "Remplaçants", reserves, clubs, tint)
	var insight := "Titulaires et remplaçants au même rang."
	if starter_gap > 0:
		insight = "%d %s à couvrir dans le XV." % [starter_gap, "place" if starter_gap == 1 else "places"]
	elif reserve_gap > 0:
		insight = "Il manque %d %s." % [reserve_gap, "remplaçant" if reserve_gap == 1 else "remplaçants"]
	elif strength:
		if maxi(starter_rank, reserve_rank) <= ceili(clubs / 3.0):
			insight = "Un poste solide jusque sur le banc."
		elif starter_rank < reserve_rank:
			insight = "L’avantage vient du XV de départ."
		elif reserve_rank < starter_rank:
			insight = "Les remplaçants font la différence."
	elif maxi(starter_rank, reserve_rank) <= mid_table:
		insight = "Le XV peut progresser." if starter_rank >= reserve_rank else "De la marge chez les remplaçants."
	elif starter_rank >= reserve_rank:
		insight = "Chercher un titulaire à ce poste."
	else:
		insight = "Renforcer le niveau des remplaçants."
	var summary := C.h(5)
	column.add_child(summary)
	var icon := C.icon("check" if strength else "search", 17, tint)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	summary.add_child(icon)
	summary.add_child(C.fill(C.wrap(insight, 17, C.IVORY, compact)))

static func _position_rank(parent: Container, caption: String, line: Dictionary, clubs: int, tint: Color) -> void:
	var row := C.h(8)
	parent.add_child(row)
	row.add_child(C.fill(C.wrap(caption, 17, C.MUTED, true, 700)))
	var rank := int(line.rank)
	var ordinal := "%d%s" % [rank, "er" if rank == 1 else "e"]
	var label := C.label("%s%s / %d clubs" % [ordinal, " ex æquo" if line.tied else "", clubs], 21, tint, true, 700)
	row.add_child(label)
	var track := PositionRank.new()
	track.name = "CreationPositionRank_" + caption
	track.rank = rank
	track.clubs = clubs
	track.tint = tint
	track.custom_minimum_size.y = maxi(4, C.px(9))
	track.accessibility_name = caption + " · " + label.text + " à ce poste"
	track.mouse_filter = Control.MOUSE_FILTER_PASS
	track.tooltip_text = "Rang à ce poste dans le championnat, selon les notes et les places couvertes."
	track.resized.connect(track.queue_redraw)
	parent.add_child(track)

static func _dossier_fact(parent: Container, caption: String, detail: String, icon: String, compact: bool) -> VBoxContainer:
	var row := C.h(6)
	parent.add_child(C.fill(row))
	var pictogram := C.icon(icon, 19 if compact else 25, Editorial.RAIL_GOLD)
	pictogram.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pictogram)
	var fact := C.v(0)
	row.add_child(C.fill(fact))
	fact.add_child(C.wrap(caption, 17, C.MUTED, compact))
	fact.add_child(C.wrap(detail, 23, C.IVORY, true, 700))
	return fact

static func _fit_creation_grid(view: ScrollContainer, grid: GridContainer, rows: int) -> void:
	var gaps := grid.get_theme_constant("v_separation") * (rows - 1)
	var height := clampi(floori((view.size.y - gaps - 1) / rows), 0, C.px(144))
	for card: Button in grid.get_children(): card.custom_minimum_size.y = height

static func _connected_country(tabs: HBoxContainer, button: Button, active: bool, last: bool) -> void:
	var group := C.v(0)
	tabs.add_child(C.fill(group))
	group.add_child(button)
	var line := ColorRect.new()
	line.color = Editorial.RAIL_GOLD if active else Color.TRANSPARENT
	line.custom_minimum_size.y = maxi(2, C.px(5))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(line)
	var bridge := Control.new()
	bridge.custom_minimum_size.y = C.px(23)
	bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(bridge)
	if active:
		var stem := ColorRect.new()
		stem.name = "CreationCountryConnector"
		stem.color = Editorial.RAIL_GOLD
		stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bridge.add_child(stem)
		stem.anchor_bottom = 1
		stem.offset_left = C.px(62)
		stem.offset_right = stem.offset_left + maxi(2, C.px(4))
		var joint := ColorRect.new()
		joint.color = Editorial.RAIL_GOLD
		joint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bridge.add_child(joint)
		joint.anchor_top = 1
		joint.anchor_bottom = 1
		joint.offset_top = -C.px(5)
		joint.offset_left = C.px(56)
		joint.offset_right = C.px(72)
	if not last:
		var separator := ColorRect.new()
		separator.color = Editorial.LINE
		separator.custom_minimum_size = Vector2(1, C.px(44))
		separator.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tabs.add_child(separator)

static func _show_creation_waiting(app: Control, workspace: Control) -> void:
	var start := workspace.find_child("CreationStart", true, false) as Button
	if start == null: return
	start.accessibility_live = AccessibilityServer.LIVE_POLITE
	start.text = "Création en cours…"
	for button: BaseButton in workspace.find_children("*", "BaseButton", true, false):
		button.disabled = true
	# A failed reply with a model already rebuilds the page. A transport error
	# without a model can leave this button in place when replacing a career.
	var restore := func(_message: String):
		if app.route == "Création" and not app.waiting: app._render(false)
	app.bridge.command_failed.connect(restore)
	start.tree_exiting.connect(func():
		if is_instance_valid(app.bridge): app.bridge.command_failed.disconnect(restore), CONNECT_ONE_SHOT)

static func _create(app: Control, selected: Dictionary, mode: String) -> void:
	var role: String = app.management_ui.get("creation_role", "club") if mode == "world-champ" else "club"
	var payload := {"mode":mode,"varyCurrent":bool(app.management_ui.get("creation_vary_current",true))}
	if role != "nation": payload.club = int(selected.id)
	if role in ["dual", "nation"]:
		payload.nationalRole = role
		payload.nation = app.management_ui.get("creation_nation", "")
	var action := func():
		if app._command("new_career", payload) and is_instance_valid(app.entry_scroll):
			_show_creation_waiting(app, app.entry_scroll)
	if app._has_career():
		app.confirm("Une nouvelle histoire", "La carrière actuelle sera remplacée dans ce profil. Vous pouvez l’exporter depuis le menu pour la conserver.", action, true)
	else:
		action.call()

static func _choose_role(app: Control, teams: Array) -> void:
	var roles := ["club", "dual", "nation"]
	var dialog := ConfirmationDialog.new()
	dialog.name = "CreationRoleDialog"
	dialog.title = "Votre rôle"
	app._prepare_dialog(dialog, 630)
	dialog.get_ok_button().text = "Confirmer"
	dialog.get_cancel_button().text = "Annuler"
	var fields := G.v()
	dialog.add_child(fields)
	fields.add_child(G.wrap("Choisissez la responsabilité avec laquelle vous commencez."))
	var roles_list := OptionButton.new()
	roles_list.name = "CreationCareerRole"
	for title: String in ["Club", "Club et sélection", "Sélection seule"]: roles_list.add_item(title)
	roles_list.select(maxi(0, roles.find(app.management_ui.get("creation_role", "club"))))
	fields.add_child(roles_list)
	var nations := OptionButton.new()
	nations.name = "CreationCareerNation"
	for index in teams.size():
		nations.add_item(str(teams[index].name))
		if teams[index].id == app.management_ui.get("creation_nation", ""): nations.select(index)
	if nations.selected < 0: nations.select(0)
	nations.disabled = roles_list.selected == 0
	fields.add_child(nations)
	roles_list.item_selected.connect(func(index: int): nations.disabled = index == 0)
	dialog.confirmed.connect(func():
		app.management_ui.creation_role = roles[roles_list.selected]
		app.management_ui.creation_nation = str(teams[nations.selected].id)
		dialog.queue_free()
		app._render(false))
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(630, 245))

static func creation(app: Control) -> Control:
	var screen := app.get_window().size
	C.configure(screen.y, screen.x)
	var modern: bool = app.pack_manager.creation_mode == "auto"
	var page := C.v(10) if modern else G.v(16)
	page.name="CarnetCreation"
	G.fill(page,true)
	var top := G.h()
	page.add_child(top)
	var back := G.button("← ACCUEIL", func(): app._navigate("Accueil"))
	top.add_child(back)
	var title := G.label("Choisissez votre histoire", 36, G.WHITE, true) if not modern else C.label("", 23, C.MUTED)
	G.fill(title)
	top.add_child(title)
	var mode: String = app.pack_manager.mode("creation")
	var preferred: String = app.pack_manager.selected_id("creation")
	var champ := mode == "world-champ"
	var nationale := champ or mode == "world-nationale"
	var japan := nationale or mode == "world-japan"
	var pacific := japan or mode == "world-pacific"
	var international := pacific or mode == "world"
	var manage := G.button("PACKS ET IDENTITÉS", func(): app.pack_manager.open("creation"))
	top.add_child(manage)
	if modern:
		Editorial.action(back, false, false, 34)
		Editorial.action(manage, false, false, 34)
	var teams: Array = app.model.get("international", {}).get("teams", []) if champ else []
	var role: String = app.management_ui.get("creation_role", "club") if not teams.is_empty() else "club"
	var nation := {}
	for team: Dictionary in teams:
		if team.id == app.management_ui.get("creation_nation", ""):
			nation = team
			break
	if not teams.is_empty():
		var caption: String = {"club":"Rôle · Club", "dual":"Rôle · Club et sélection", "nation":"Rôle · Sélection seule"}.get(role, "Rôle · Club")
		var choose := G.button(caption, _choose_role.bind(app, teams))
		choose.name = "CreationChooseRole"
		top.add_child(choose)
		top.move_child(choose, manage.get_index())
		if modern: Editorial.action(choose, false, false, 34)
	Packs.missing_warning(app, page, "creation")
	if role == "nation":
		_nation_creation(app, page, mode, preferred, nation, modern)
		return page
	var candidates: Array = app.pack_manager.creation_catalogue()
	var playable: Array = candidates.filter(func(club: Dictionary): return club.get("playable", true))
	if playable.is_empty():
		page.add_child(G.wrap("Le catalogue des clubs est en cours de chargement.", 15, G.WHITE))
		return page
	var countries := {}
	var country := _creation_country(playable[0])
	for club: Dictionary in playable:
		var group := _creation_country(club)
		if not countries.has(group): countries[group] = []
		countries[group].append(club)
		if (modern and club.division == app.club_division) or (not modern and int(club.id) == app.selected_club):
			country = group
	var clubs: Array = countries[country]
	var division := str(app.club_division)
	var divisions_data := [["elite", "ÉLITE"], ["accession", "ACCESSION"], ["prem", "PREM"], ["urc", "URC"]] if international else [["elite", "ÉLITE"], ["accession", "ACCESSION"]]
	if pacific: divisions_data.append(["srp", "SUPER RUGBY PACIFIC"])
	if japan: divisions_data.append_array([["jlo-d1", "JAPON D1"], ["jlo-d2", "JAPON D2"]])
	if nationale: divisions_data.append(["nationale", "NATIONALE"])
	if champ: divisions_data.append(["champ", "CHAMP"])
	if not clubs.any(func(club: Dictionary): return club.division == division): division = str(clubs[0].division)
	app.club_division = division
	var division_clubs: Array = clubs.filter(func(club: Dictionary): return club.division == division)
	var selected: Dictionary = {} if modern else division_clubs[0]
	var selection := int(app.management_ui.get(CREATION_SELECTION, -1)) if modern else int(app.selected_club)
	for club: Dictionary in division_clubs:
		if int(club.id) == selection:
			selected = club
			break
	if not modern: app.selected_club = int(selected.id)
	var row := C.h(21) if modern else G.h(24)
	G.fill(row, true)
	if not modern: page.add_child(row)
	var is_srp := pacific and division == "srp"
	var is_japan := japan and division in ["jlo-d1", "jlo-d2"]
	var is_nationale := nationale and division == "nationale"
	var is_champ := champ and division == "champ"
	var dossier: VBoxContainer
	if modern:
		var dossier_width := .38 if screen.y < 850 else .34
		dossier = G.panel(row, dossier_width)
		dossier.name = "CreationDossier"
		dossier.add_theme_constant_override("separation", C.px(7))
		Editorial.surface(dossier.get_parent(), Color("142020"), Editorial.LINE, 14)
		var preview := C.v(3 if screen.y < 850 else 5)
		dossier.add_child(C.fill(preview, true))
		var photo_height := clampf(screen.y * .181, 124, 262)
		if selected.is_empty(): _competition_summary(app, preview, division, division_clubs.size(), photo_height)
		else:
			var championship := str(_competition_identity(app, division).get("name", Club.competition_name(division)))
			_club_preview(app, preview, selected, championship, preferred == "base")
	else:
		var photo := _cover(selected)
		G.fill(photo, true, 0.95)
		row.add_child(photo)
		var over: VBoxContainer = photo.get_meta("content")
		over.add_child(G.label("VOTRE FUTUR CLUB", 14, G.WHITE))
		if is_champ:
			over.add_child(G.label(str(_competition_identity(app, division).get("name", Club.competition_name(division))).to_upper() + "  /  SAISON 2026–27", 22, G.WHITE, true))
		if is_nationale:
			over.add_child(G.label("NATIONALE  /  SAISON 2026–27", 22, G.WHITE, true))
		if is_srp:
			over.add_child(G.label("PACIFIQUE  /  SAISON 2027", 22, G.WHITE, true))
			over.add_child(G.label(_territory(selected).to_upper(), 13, G.WHITE))
		if is_japan:
			over.add_child(G.label(str(_competition_identity(app, division).get("name", Club.competition_name(division))).to_upper(), 22, G.WHITE, true))
		over.add_child(G.spacer())
		over.add_child(G.crest(selected, 96))
		var name := G.label(G.club_name(selected), 38, G.WHITE, true)
		name.name = "CreationClubTitle"
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		over.add_child(name)
		over.add_child(G.label(_territory(selected), 18,G.WHITE))
		over.add_child(G.wrap(selected.get("stadium", ""), 14, G.WHITE))
		var goal := str(selected.get("goal", ""))
		if not goal.is_empty(): over.add_child(G.label("OBJECTIF  /  " + goal.to_upper(), 14, G.WHITE))
	var list := G.panel(row, (.62 if screen.y < 850 else .66) if modern else 1.2)
	if modern:
		Editorial.surface(list.get_parent(), Color.TRANSPARENT, Color.TRANSPARENT, 0)
	else:
		G.chapter(list,"01","Prendre les rênes","Choisissez les identités puis votre club.",app.accent)
	var installed: Array = app.pack_manager.installed("creation")
	var pack_name := "JEU DE BASE"
	for pack: Dictionary in installed:
		if str(pack.get("id", "")) == preferred:
			pack_name = str(pack.get("name", "Pack personnalisé")).to_upper()

	var unavailable := preferred != "base" and not installed.any(func(pack: Dictionary): return str(pack.id) == preferred)
	if unavailable: pack_name = "PACK INDISPONIBLE"
	if modern: title.text = "RÉALITÉ ACTIVE   /   " + pack_name
	else: list.add_child(G.wrap("IDENTITÉS  /  " + pack_name, 12, G.GOLD))
	var presentations := G.h(8)
	if modern:
		top.add_child(presentations)
		top.move_child(manage, -1)
	else: list.add_child(presentations)
	var base := G.button("Jeu de base", func(): app.pack_manager.select("base", "creation"))
	base.name = "CreationBaseIdentity"
	base.disabled = app.waiting or preferred == "base"
	presentations.add_child(base)
	var import_button := G.button("Importer une autre réalité", app.pack_manager.choose_creation_file, true)
	import_button.name = "CreationImportReality"
	import_button.disabled = app.waiting
	presentations.add_child(import_button)
	if modern:
		Editorial.action(base, false, false, 34)
		Editorial.action(import_button, false, false, 34)
	var filters: Container = list
	if modern:
		filters = C.v(0)
		page.add_child(filters)
	if countries.size() > 1:
		var tabs := G.h(8)
		tabs.name = "CreationCountries"
		filters.add_child(tabs)
		var groups := countries.keys()
		groups.sort()
		for group: String in groups:
			var members: Array = countries[group]
			var info: Array = CREATION_COUNTRIES.get(group, [group, null])
			var tab := G.button(info[0], func():
				if country == group: return
				var first_division := str(members[0].division)
				var first_members := members.filter(func(club: Dictionary): return club.division == first_division)
				_division(app, first_division, first_members, mode))
			tab.name = "CreationCountry_" + group
			tab.icon = info[1]
			for state in ["normal", "hover", "pressed", "focus"]:
				tab.add_theme_color_override("icon_" + state + "_color", Color.WHITE)
			tab.disabled = app.waiting
			G.fill(tab)
			if modern:
				if group == "international": tab.icon = C.icon_texture("globe", C.IVORY)
				Editorial.route_tab(tab, country == group, true)
				_connected_country(tabs, tab, country == group, group == groups.back())
			else:
				if country == group: G.selected(tab, app.accent)
				tabs.add_child(tab)
	var divisions := HFlowContainer.new()
	divisions.add_theme_constant_override("h_separation", C.px(12))
	divisions.add_theme_constant_override("v_separation", C.px(6))
	if modern:
		var scope := PanelContainer.new()
		Editorial.surface(scope, Color("152020"), Editorial.BRASS, 9)
		var scope_style := scope.get_theme_stylebox("panel") as StyleBoxFlat
		scope_style.content_margin_left = C.px(44)
		scope_style.border_color = Editorial.RAIL_GOLD
		filters.add_child(scope)
		var competition_row := C.h(15)
		scope.add_child(competition_row)
		var icon := TextureRect.new()
		icon.texture = CREATION_COUNTRIES.get(country, ["", null])[1]
		if country == "international": icon.texture = C.icon_texture("globe", C.IVORY)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(C.px(58), C.px(35))
		competition_row.add_child(icon)
		var country_heading := C.label(CREATION_COUNTRY_SCOPES.get(country, "Championnats"), 32, C.IVORY, true, 700)
		country_heading.name = "CreationChampionshipsScope"
		country_heading.custom_minimum_size.x = C.px(325)
		country_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		competition_row.add_child(country_heading)
		Editorial.divider(competition_row)
		competition_row.add_child(G.fill(divisions))
	else:
		filters.add_child(divisions)
	for item: Array in divisions_data:
		var members: Array = clubs.filter(func(club: Dictionary): return club.division == item[0])
		if members.is_empty(): continue
		var identity := _competition_identity(app, item[0])
		var name: String = item[1]
		if modern or preferred != "base":
			name = str(identity.get("shortName", identity.get("name", name)))
		var caption := "%s · %d" % [name, members.size()] if international else "%s  /  %d CLUBS" % [name, members.size()]
		var b := G.button(caption, func(): _division(app, item[0], members, mode))
		b.name = "CreationDivision_" + item[0]
		b.icon = GameSkin._pack_texture(str(identity.get("logoPath", "")))
		if b.icon != null:
			var icon_width := minf(58, 32.0 * b.icon.get_width() / b.icon.get_height())
			b.add_theme_constant_override("icon_max_width", maxi(1, C.px(icon_width)))
			b.add_theme_constant_override("h_separation", C.px(10))
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_color_override("icon_" + state + "_color", Color.WHITE)
		b.disabled = app.waiting
		if modern:
			b.custom_minimum_size.x = C.px(235)
			Editorial.route_tab(b, app.club_division == item[0], false)
		else:
			if app.club_division == item[0]: G.selected(b, app.accent)
		divisions.add_child(b)
		var max_tab_width := floorf(screen.x * .65)
		if b.get_combined_minimum_size().x > max_tab_width:
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = max_tab_width
	if modern:
		page.add_child(row)
		list.add_child(C.rule())
		var intro := C.h(12)
		list.add_child(intro)
		var identity := _competition_identity(app, division)
		var country_name := str(CREATION_COUNTRIES.get(country, [country, null])[0])
		var name := str(identity.get("name", Club.competition_name(division)))
		var logo := str(identity.get("logoPath", ""))
		if not logo.is_empty(): intro.add_child(G.crest({"logoPath":logo, "name":identity.name}, C.px(48)))
		var heading := C.wrap("%s / %s" % [country_name, name], 52, C.IVORY, true, 800)
		heading.name = "CreationDivisionHeading"
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		C.fill(heading)
		intro.add_child(heading)
		var count := C.label("%d clubs" % division_clubs.size(), 28, C.IVORY, false)
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		intro.add_child(count)
		var rule := ColorRect.new()
		rule.color = Editorial.RAIL_GOLD
		rule.custom_minimum_size = Vector2(C.px(310), 2)
		rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		list.add_child(rule)
	if not modern and (is_srp or is_japan or is_nationale or is_champ):
		var facts := G.h(8)
		list.add_child(facts)
		var fact_data := [["16", "MATCHS PAR CLUB"], ["6", "QUALIFIÉS POUR LES FINALES"], ["FÉV.–JUIN", "SAISON 2027"]]
		if is_japan:
			fact_data = [["18", "MATCHS PAR CLUB"], ["6", "QUALIFIÉS POUR LES FINALES"], ["DÉC.–JUIN", "SAISON 2026–27"]] if division == "jlo-d1" else [["14", "MATCHS PAR CLUB"], ["2", "PLACES EN BARRAGES"], ["DÉC.–MAI", "SAISON 2026–27"]]
		if is_nationale:
			fact_data = [["26", "MATCHS PAR CLUB"], ["6", "QUALIFIÉS POUR LES FINALES"], ["PRO D2", "ACCESSION SPORTIVE"]]
		if is_champ:
			fact_data = [["26", "MATCHS PAR CLUB"], ["6", "QUALIFIÉS POUR LES FINALES"], ["SEPT.–MAI", "SAISON 2026–27"]]
		for fact in fact_data:
			var tile := G.panel(facts, 1.0)
			tile.add_child(G.label(fact[0], 20, G.INK, true))
			tile.add_child(G.cell(fact[1], 45, G.MUTED, true))
	var bounds := Vector2i(0, division_clubs.size())
	if not modern and not is_srp and not is_japan and not is_nationale and not is_champ:
		bounds = Club._paged(app,list,"CreationPagination",division_clubs.size(),8,"creation_"+mode+"_"+division)
	var items := G.scroll(list)
	var list_scroll := items.get_parent() as ScrollContainer
	list_scroll.name = "CreationClubsScroll"
	var grid:=GridContainer.new()
	grid.name = "CreationClubGrid"
	if modern:
		grid.columns = 3
	else:
		grid.columns = 3 if is_nationale or is_champ or (is_japan and app.get_viewport_rect().size.x >= 1660) else 2
	grid.add_theme_constant_override("h_separation", C.px(9) if modern else 8)
	grid.add_theme_constant_override("v_separation", C.px(11) if modern else 8)
	G.fill(grid)
	items.add_child(grid)
	var grid_rows := ceili(float(division_clubs.size()) / grid.columns)
	for club in division_clubs.slice(bounds.x,bounds.y):
		var b := G.button("", func(): _select_club(app, int(club.id), modern))
		b.custom_minimum_size.y = clampf(app.get_viewport_rect().size.y * 0.045, 52.0, 66.0) if is_srp else (44.0 if is_japan or is_nationale or is_champ else 52.0)
		b.name="CreationClub"+str(int(club.id))
		b.accessibility_name = G.club_name(club)
		b.accessibility_description = _territory(club)
		G.fill(b)
		if modern:
			Editorial.action(b, false, club.get("id") == selected.get("id"), C.px(106), true)
			if club.get("id") == selected.get("id"):
				for state in ["normal", "hover", "pressed"]:
					var style := b.get_theme_stylebox(state) as StyleBoxFlat
					style.border_color = Editorial.RAIL_GOLD
					style.set_border_width_all(maxi(2, C.px(3)))
					style.bg_color = Color("302d22") if state == "normal" else Color("403724")
		elif club.get("id") == selected.get("id"): G.selected(b,Color(club.color))
		var inset := G.margin(C.px(8) if modern else 8)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inset)
		var line := C.h(14) if modern else G.h(16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(line)
		var crest := _creation_crest(club, clampi(C.px(84), 30, 84) if modern else 32, modern and preferred == "base")
		crest.tooltip_text = ""
		line.add_child(crest)
		var names := G.v(0)
		G.fill(names)
		line.add_child(names)
		if modern:
			names.alignment = BoxContainer.ALIGNMENT_CENTER
			var name := C.wrap(G.club_name(club), 30, C.IVORY, true, 700)
			name.max_lines_visible = 2
			name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			names.add_child(name)
			var roster: Dictionary = club.get("startingRoster", {})
			var subtitle := C.label(_territory(club), 22, C.IVORY, false)
			subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			names.add_child(subtitle)
			if not roster.is_empty():
				var roster_count := int(roster.get("forwards", 0)) + int(roster.get("backs", 0))
				b.accessibility_description += " · Note moyenne %s · %d joueurs" % [_rating(roster), roster_count]
				Editorial.divider(line)
				var figures := C.v(0)
				figures.alignment = BoxContainer.ALIGNMENT_CENTER
				line.add_child(figures)
				figures.add_child(C.label(_rating(roster), 32, C.IVORY, true, 700))
				figures.add_child(C.label("%d j." % roster_count, 23, C.IVORY))
		else:
			names.add_child(G.cell(G.club_name(club),60,G.INK,true))
			names.add_child(G.cell(_territory(club),60,G.MUTED,true))
			line.add_child(G.label("→", 24, G.GOLD))
		grid.add_child(b)
	if modern: list_scroll.resized.connect(_fit_creation_grid.bind(list_scroll, grid, grid_rows))
	var database: Dictionary = app.pack_manager.database("creation")
	var world_info := "%s joueurs · %d clubs jouables" % [G.n(database.get("startingPlayerCount", database.get("playerCount", 0))), playable.size()]
	if not modern: list.add_child(G.wrap(world_info, 12))
	var caption := "CHOISISSEZ UN CLUB" if selected.is_empty() else "PRENDRE LES RÊNES DE " + G.club_abbr(selected) + "  →"
	if modern: caption = "Choisissez un club" if selected.is_empty() else "Prendre les rênes  →"
	_career_variation_controls(app,dossier if modern else list,modern)
	var can_start := not selected.is_empty() and (role == "club" or not nation.is_empty())
	var start := G.button(caption, func():
		if can_start: _create(app, selected, mode), true)
	start.name="CreationStart"
	start.disabled = app.waiting or unavailable or not can_start
	if modern:
		Editorial.action(start, true, false, maxi(40, C.px(72)))
		start.add_theme_font_size_override("font_size", maxi(20, C.px(41)))
		dossier.add_child(start)
		var status := C.label(world_info, 18, C.MUTED, false)
		list.add_child(status)
	elif japan:
		var actions := G.h(8)
		list.add_child(actions)
		actions.add_child(start)
		G.fill(start)
		var safe_space := Control.new()
		safe_space.custom_minimum_size.x = 152
		actions.add_child(safe_space)
	else:
		list.add_child(start)
	if app.waiting and app.last_command == "new_career": _show_creation_waiting(app, page)
	return page

static func _nation_creation(app: Control, page: Control, mode: String, preferred: String, nation: Dictionary, modern: bool) -> void:
	var panel := G.panel(page)
	panel.name = "CreationNationalDossier"
	var identity := C.h(20)
	panel.add_child(identity)
	identity.add_child(app.Immersive.Selections.nation_badge(nation, C.px(82)))
	var details := G.v()
	identity.add_child(details)
	var nation_name := str(nation.get("name", "Votre sélection"))
	details.add_child(C.label("MANDAT INTERNATIONAL", 24, C.GOLD, true, 700))
	details.add_child(C.label(nation_name, 48, C.IVORY, true, 700))
	panel.add_child(C.wrap("Vous dirigez cette sélection. Retrouvez vos convocations, votre calendrier et vos résultats dans la Réception et l’espace Sélections.", 26, C.IVORY))
	var installed: Array = app.pack_manager.installed("creation")
	var missing := preferred != "base" and not installed.any(func(pack: Dictionary): return str(pack.id) == preferred)
	_career_variation_controls(app,panel,modern)
	var start := G.button("Diriger " + nation_name + "  →", _create.bind(app, {}, mode), true)
	start.name = "CreationStart"
	start.disabled = app.waiting or missing or nation.is_empty()
	if modern:
		Editorial.surface(panel.get_parent(), Color("142020"), Editorial.LINE, 14)
		Editorial.action(start, true, false, maxi(40, C.px(72)))
		start.add_theme_font_size_override("font_size", maxi(20, C.px(41)))
	panel.add_child(start)
	if app.waiting and app.last_command == "new_career": _show_creation_waiting(app, page)

static func _career_variation_controls(app: Control, parent: Node, modern: bool) -> void:
	var group := C.v(4)
	group.name = "CreationCareerVariation"
	parent.add_child(group)
	var option := CheckBox.new()
	option.name = "CreationVaryCurrent"
	option.text = "Faire légèrement varier le niveau actuel"
	option.button_pressed = bool(app.management_ui.get("creation_vary_current",true))
	option.add_theme_font_size_override("font_size",C.px(20) if modern else 16)
	option.tooltip_text = "Les qualités de départ varient légèrement, jusqu’à ±3. Le potentiel varie toujours, jusqu’à ±5."
	option.toggled.connect(func(value: bool): app.management_ui.creation_vary_current = value)
	group.add_child(option)
	group.add_child(C.wrap("Le potentiel varie à chaque nouvelle carrière (jusqu’à ±5), même lorsque cette case est décochée.",17,C.MUTED))
