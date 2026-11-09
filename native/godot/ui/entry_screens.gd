extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Packs = preload("res://ui/pack_views.gd")
const Club = preload("res://ui/club_views.gd")
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const CREATION_SELECTION := "creation_selection"

static func _cover(club: Dictionary) -> Control:
	var identity := G.identity(club)
	var slug := str(identity.get("slug", "perpignan"))
	var supplied: Dictionary = identity.get("photos", {}).get("stadium", {})
	var stadium_path := str(supplied.get("path", ""))
	if not stadium_path.is_empty():
		var picture := G.picture(slug, "stadium", true, stadium_path)
		if picture.get_meta("has_photo", false):
			if picture.get_meta("photo_from_pack", false): picture.tooltip_text = str(supplied.get("credit", ""))
			return picture
		picture.free()
	if ResourceLoader.exists("res://assets/club-atlas/%s-stadium.webp" % slug):
		return G.picture(slug)
	var cover := ColorRect.new()
	cover.color = Color(identity.get("color", "#303c42")).darkened(.72)
	var pacific := slug.begins_with("srp-")
	var japan := slug.begins_with("jlo-")
	var nationale := slug.begins_with("nat-")
	var champ := slug.begins_with("champ-")
	if pacific or japan or nationale or champ:
		var country := str(identity.get("country", "")).to_lower()
		var region := str(identity.get("region", ""))
		var art := "res://art/pacific/covers/%s.svg" % country if pacific else (("res://art/nationale/covers/%s.svg" if nationale else "res://art/japan/covers/%s.svg") % region)
		if champ: art = "res://art/champ/covers/champ-england.svg"
		if ResourceLoader.exists(art):
			cover.clip_contents = true
			var backdrop := TextureRect.new()
			backdrop.texture = load(art) as Texture2D
			backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cover.add_child(backdrop)
	var inset := G.margin(22 if pacific or japan or nationale or champ else 12)
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
		var identity := G.h(12)
		choices.add_child(identity)
		identity.add_child(G.crest(club, 44))
		var current := G.v(1)
		G.fill(current)
		identity.add_child(current)
		current.add_child(G.label("CARNET EN COURS", 11, G.GOLD))
		current.add_child(G.wrap(str(G.identity(club).get("city", "Votre territoire")), 18, G.INK))
		choices.add_child(G.label("VOTRE CARRIÈRE", 12, G.GOLD))
		choices.add_child(G.wrap(G.club_name(club), 26, G.INK))
		choices.add_child(G.label("Saison %s · %s" % [G.n(app.model.meta.get("season", 1)), app.model.meta.get("roundLabel", "Journée " + G.n(int(app.model.meta.get("round", 0)) + 1))], 12, G.MUTED))
		choices.add_child(G.button("REPRENDRE LA CARRIÈRE  →", func(): app._navigate("Bureau"), true))
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
	var illustration := C.photo("trophy", Vector2.ZERO, true, .39)
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

static func _club_preview(parent: VBoxContainer, club: Dictionary, photo_height: float) -> void:
	var photo := _cover(club)
	photo.name = "CreationStadium"
	photo.custom_minimum_size.y = photo_height
	parent.add_child(photo)
	var identity := C.h(18)
	parent.add_child(identity)
	identity.add_child(G.crest(club, C.px(98)))
	var copy := C.v(2)
	G.fill(copy)
	identity.add_child(copy)
	var title := C.wrap(G.club_name(club), 42, C.IVORY, true, 700)
	title.name = "CreationClubTitle"
	copy.add_child(title)
	copy.add_child(C.wrap(str(club.get("stadium", "")), 23))
	var roster: Dictionary = club.get("startingRoster", {})
	if not roster.is_empty():
		parent.add_child(C.rule())
		var metrics := C.h(18)
		metrics.name = "CreationRosterSummary"
		parent.add_child(metrics)
		Editorial.fact(metrics, _rating(roster), "Note moyenne")
		Editorial.divider(metrics)
		Editorial.fact(metrics, roster.get("forwards", 0), "Avants")
		Editorial.divider(metrics)
		Editorial.fact(metrics, roster.get("backs", 0), "Trois-quarts")
	parent.add_child(C.rule())
	_dossier_line(parent, "Objectif du conseil", str(club.get("goal", "Développer le projet sportif")))
	if club.has("cashMillions"):
		_dossier_line(parent, "Trésorerie de départ simulée", G.euros(roundi(float(club.cashMillions) * 1_000_000)))
	if not roster.is_empty():
		parent.add_child(C.rule())
		var balance := C.h(18)
		parent.add_child(balance)
		for item in [["POINTS FORTS", "strengths"], ["BESOINS PRIORITAIRES", "needs"]]:
			var column := C.v(3)
			C.fill(column)
			balance.add_child(column)
			column.add_child(C.label(item[0], 21, Editorial.BRASS))
			column.add_child(C.wrap(str(roster.get(item[1], "")), 23, C.IVORY))

static func _dossier_line(parent: Container, caption: String, detail: String) -> void:
	var line := C.h(16)
	parent.add_child(line)
	var title := C.label(caption, 23, C.IVORY)
	title.custom_minimum_size.x = C.px(190)
	line.add_child(title)
	var value := C.wrap(detail, 22)
	C.fill(value)
	line.add_child(value)

static func _create(app: Control, selected: Dictionary, mode: String) -> void:
	var action := func(): app._command("new_career", {"club":int(selected.id),"mode":mode}, "Bureau")
	if app._has_career():
		app.confirm("Une nouvelle histoire", "La carrière actuelle sera remplacée dans ce profil. Exportez-la depuis le menu pour la conserver séparément. Prendre les rênes de %s ?" % G.club_name(selected), action)
	else:
		action.call()

static func creation(app: Control) -> Control:
	var screen := app.get_window().size
	C.configure(screen.y, screen.x)
	var modern: bool = app.pack_manager.creation_mode == "auto"
	var page := G.v(10 if modern else 16)
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
	Packs.missing_warning(app, page, "creation")
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
	var row := C.h(22) if modern else G.h(24)
	G.fill(row, true)
	if not modern: page.add_child(row)
	var is_srp := pacific and division == "srp"
	var is_japan := japan and division in ["jlo-d1", "jlo-d2"]
	var is_nationale := nationale and division == "nationale"
	var is_champ := champ and division == "champ"
	if modern:
		var panel := G.panel(row, 0.39)
		Editorial.surface(panel.get_parent(), Editorial.PANEL, Editorial.LINE, 15)
		var preview := G.scroll(panel)
		preview.get_parent().name = "CreationPreviewScroll"
		preview.add_theme_constant_override("separation", C.px(12))
		var photo_height := clampf(screen.y * .235, 155, 338)
		if selected.is_empty(): _competition_summary(app, preview, division, division_clubs.size(), photo_height)
		else: _club_preview(preview, selected, photo_height)
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
	var list := G.panel(row, 0.61 if modern else 1.2)
	if modern:
		Editorial.surface(list.get_parent(), Editorial.INK, Color.TRANSPARENT, 0)
	else:
		G.chapter(list,"01","Prendre les rênes","Choisissez les identités puis votre club.",app.accent)
	var installed: Array = app.pack_manager.installed("creation")
	var preferred: String = app.pack_manager.selected_id("creation")
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
		filters = C.h(20) if screen.x >= 1480 else C.v(9)
		page.add_child(filters)
	if countries.size() > 1:
		var tabs := G.h(8)
		tabs.name = "CreationCountries"
		filters.add_child(tabs)
		if modern: C.fill(tabs, false, .56)
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
				Editorial.action(tab, false, country == group, maxi(32, C.px(47)))
			elif country == group: G.selected(tab, app.accent)
			tabs.add_child(tab)
	var divisions := G.h(8)
	if modern:
		if filters is HBoxContainer and countries.size() > 1: Editorial.divider(filters)
		C.fill(divisions, false, .44)
	filters.add_child(divisions)
	for item: Array in divisions_data:
		var members: Array = clubs.filter(func(club: Dictionary): return club.division == item[0])
		if members.is_empty(): continue
		var name: String = item[1]
		if modern:
			var identity := _competition_identity(app, item[0])
			name = str(identity.get("shortName", identity.get("name", name)))
		var caption := "%s · %d" % [name, members.size()] if international else "%s  /  %d CLUBS" % [name, members.size()]
		var b := G.button(caption, func(): _division(app, item[0], members, mode))
		b.name = "CreationDivision_" + item[0]
		if modern:
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.tooltip_text = caption
		b.disabled = app.waiting
		G.fill(b)
		if modern:
			Editorial.action(b, false, app.club_division == item[0], maxi(32, C.px(47)))
		elif app.club_division == item[0]: G.selected(b, app.accent)
		divisions.add_child(b)
	if modern:
		page.add_child(C.rule())
		page.add_child(row)
		var intro := C.h(12)
		list.add_child(intro)
		intro.add_child(C.label("Clubs du championnat", 34, C.IVORY, true, 700))
		Editorial.divider(intro)
		var identity := _competition_identity(app, division)
		var logo := str(identity.get("logoPath", ""))
		if not logo.is_empty(): intro.add_child(G.crest({"logoPath":logo, "name":identity.name}, C.px(48)))
		var heading := C.wrap("%s  ·  %d clubs" % [identity.get("name", Club.competition_name(division)), division_clubs.size()], 21)
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		C.fill(heading)
		intro.add_child(heading)
		if screen.x >= 1550:
			var key := C.label("NOTE MOYENNE · EFFECTIF DE DÉPART", 18, Editorial.BRASS)
			key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			intro.add_child(key)
		list.add_child(C.rule())
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
	items.get_parent().name = "CreationClubsScroll"
	var grid:=GridContainer.new()
	grid.name = "CreationClubGrid"
	if modern:
		grid.columns = 3 if app.get_window().size.x >= 1660 else 2
	else:
		grid.columns = 3 if is_nationale or is_champ or (is_japan and app.get_viewport_rect().size.x >= 1660) else 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	G.fill(grid)
	items.add_child(grid)
	var grid_rows := ceili(float(division_clubs.size()) / grid.columns)
	var modern_tile_height := clampi(floori((screen.y * .66 - 119) / grid_rows), 64, 153)
	for club in division_clubs.slice(bounds.x,bounds.y):
		var b := G.button("", func(): _select_club(app, int(club.id), modern))
		b.custom_minimum_size.y = clampf(app.get_viewport_rect().size.y * 0.045, 52.0, 66.0) if is_srp else (44.0 if is_japan or is_nationale or is_champ else 52.0)
		b.name="CreationClub"+str(int(club.id))
		b.tooltip_text=G.club_name(club)+" · "+_territory(club)
		G.fill(b)
		if modern:
			Editorial.action(b, false, club.get("id") == selected.get("id"), modern_tile_height, true)
		elif club.get("id") == selected.get("id"): G.selected(b,Color(club.color))
		var inset := G.margin(8)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inset)
		var line := G.h(16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(line)
		line.add_child(G.crest(club, clampi(C.px(59), 30, 55) if modern else 32))
		var names := G.v(0)
		G.fill(names)
		line.add_child(names)
		if modern:
			names.alignment = BoxContainer.ALIGNMENT_CENTER
			var name := C.wrap(G.club_name(club), 26, C.IVORY, true, 700)
			names.add_child(name)
			var roster: Dictionary = club.get("startingRoster", {})
			var detail := _territory(club)
			if not roster.is_empty():
				detail += "  ·  %s joueurs" % G.n(int(roster.get("forwards", 0)) + int(roster.get("backs", 0)))
				b.tooltip_text += " · Note moyenne " + _rating(roster)
			var subtitle := C.label(detail, 18, C.MUTED, false)
			subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			names.add_child(subtitle)
			if not roster.is_empty():
				line.add_child(C.label(_rating(roster), 27, Editorial.BRASS, true, 700))
		else:
			names.add_child(G.cell(G.club_name(club),60,G.INK,true))
			names.add_child(G.cell(_territory(club),60,G.MUTED,true))
		line.add_child(G.label("→", 24, G.GOLD))
		grid.add_child(b)
	var database: Dictionary = app.pack_manager.database("creation")
	var world_info := "%s joueurs · %d clubs jouables" % [G.n(database.get("playerCount", 0)), playable.size()]
	if not modern: list.add_child(G.wrap(world_info, 12))
	var caption := "CHOISISSEZ UN CLUB" if selected.is_empty() else "PRENDRE LES RÊNES DE " + G.club_abbr(selected) + "  →"
	var start := G.button(caption, func():
		if not selected.is_empty(): _create(app, selected, mode), true)
	start.name="CreationStart"
	start.disabled = app.waiting or unavailable or selected.is_empty()
	if modern:
		page.add_child(C.rule())
		var footer := C.h(20)
		page.add_child(footer)
		var status := C.label(world_info, 21, C.MUTED, false)
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		C.fill(status)
		footer.add_child(status)
		start.custom_minimum_size.x = C.px(440)
		Editorial.action(start, true, false, maxi(40, C.px(62)))
		footer.add_child(start)
		var safe_space := Control.new()
		safe_space.custom_minimum_size.x = 142
		footer.add_child(safe_space)
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
	return page
