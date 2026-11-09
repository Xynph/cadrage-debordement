extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Packs = preload("res://ui/pack_views.gd")

static func _cover(club: Dictionary) -> Control:
	var identity := G.identity(club)
	var slug := str(identity.get("slug", "perpignan"))
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
	var new_career:=G.button("NOUVELLE CARRIÈRE", func(): app._navigate("Création"), club.is_empty())
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

static func _creation_country(club: Dictionary) -> String:
	if club.get("division") in ["urc", "srp"]: return "international"
	return str(club.get("country", "FR"))

static func _division(app: Control, id: String, clubs: Array, mode: String) -> void:
	app.club_division = id
	if not clubs.any(func(club: Dictionary): return int(club.id) == app.selected_club):
		app.selected_club = int(clubs[0].id)
		app.management_ui["creation_" + mode + "_" + id] = {"page":0}
	app._render()

static func _create(app: Control, selected: Dictionary, mode: String) -> void:
	var action := func(): app._command("new_career", {"club":int(selected.id),"mode":mode}, "Bureau")
	if app._has_career():
		app.confirm("Une nouvelle histoire", "La carrière actuelle sera remplacée dans ce profil. Exportez-la depuis le menu pour la conserver séparément. Prendre les rênes de %s ?" % G.club_name(selected), action)
	else:
		action.call()

static func creation(app: Control) -> Control:
	var page := G.v(16)
	page.name="CarnetCreation"
	G.fill(page,true)
	var top := G.h()
	page.add_child(top)
	top.add_child(G.button("← ACCUEIL", func(): app._navigate("Accueil")))
	var title := G.label("Choisissez votre histoire", 36, G.WHITE, true)
	G.fill(title)
	top.add_child(title)
	var meta: Dictionary = app.model.get("meta", {})
	var mode: String = app.pack_manager.mode("creation")
	var champ := mode == "world-champ"
	var nationale := champ or mode == "world-nationale"
	var japan := nationale or mode == "world-japan"
	var pacific := japan or mode == "world-pacific"
	var international := pacific or mode == "world"
	top.add_child(G.button("PACKS ET IDENTITÉS", func(): app.pack_manager.open("creation")))
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
		if int(club.id) == app.selected_club: country = group
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
	var selected: Dictionary = division_clubs[0]
	for club: Dictionary in division_clubs:
		if int(club.id) == app.selected_club:
			selected = club
			break
	app.selected_club = int(selected.id)
	var row := G.h(24)
	G.fill(row, true)
	page.add_child(row)
	var photo := _cover(selected)
	G.fill(photo, true, 0.95)
	row.add_child(photo)
	var over: VBoxContainer = photo.get_meta("content")
	over.add_child(G.label("VOTRE FUTUR CLUB", 14, G.WHITE))
	var is_srp := pacific and division == "srp"
	var is_japan := japan and division in ["jlo-d1", "jlo-d2"]
	var is_nationale := nationale and division == "nationale"
	var is_champ := champ and division == "champ"
	if is_champ:
		over.add_child(G.label("CHAMP RUGBY  /  SAISON 2026–27", 22, G.WHITE, true))
	if is_nationale:
		over.add_child(G.label("NATIONALE  /  SAISON 2026–27", 22, G.WHITE, true))
	if is_srp:
		over.add_child(G.label("PACIFIQUE  /  SAISON 2027", 22, G.WHITE, true))
		over.add_child(G.label(_territory(selected).to_upper(), 13, G.WHITE))
	if is_japan:
		over.add_child(G.label("LEAGUE ONE  /  " + ("DIVISION 1" if division == "jlo-d1" else "DIVISION 2"), 22, G.WHITE, true))
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
	var list := G.panel(row,1.2)
	G.chapter(list,"01","Prendre les rênes","Choisissez les identités puis votre club.",app.accent)
	var installed: Array = app.pack_manager.installed("creation")
	var preferred: String = app.pack_manager.selected_id("creation")
	var pack_name := "JEU DE BASE"
	for pack: Dictionary in installed:
		if str(pack.get("id", "")) == preferred:
			pack_name = str(pack.get("name", "Pack personnalisé")).to_upper()

	var unavailable := preferred != "base" and not installed.any(func(pack: Dictionary): return str(pack.id) == preferred)
	if unavailable: pack_name = "PACK INDISPONIBLE"
	list.add_child(G.wrap("IDENTITÉS  /  " + pack_name, 12, G.GOLD))
	var presentations := G.h(8)
	list.add_child(presentations)
	var base := G.button("Jeu de base", func(): app.pack_manager.select("base", "creation"))
	base.name = "CreationBaseIdentity"
	base.disabled = app.waiting or preferred == "base"
	presentations.add_child(base)
	var import_button := G.button("Importer une autre réalité", app.pack_manager.choose_creation_file, true)
	import_button.name = "CreationImportReality"
	import_button.disabled = app.waiting
	presentations.add_child(import_button)
	if countries.size() > 1:
		var tabs := G.h(8)
		tabs.name = "CreationCountries"
		list.add_child(tabs)
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
			if country == group: G.selected(tab, app.accent)
			tabs.add_child(tab)
	var divisions := G.h(8)
	list.add_child(divisions)
	for item: Array in divisions_data:
		var members: Array = clubs.filter(func(club: Dictionary): return club.division == item[0])
		if members.is_empty(): continue
		var caption := "%s · %d" % [item[1], members.size()] if international else "%s  /  %d CLUBS" % [item[1], members.size()]
		var b := G.button(caption, func(): _division(app, item[0], members, mode))
		b.name = "CreationDivision_" + item[0]
		b.disabled = app.waiting
		G.fill(b)
		if app.club_division == item[0]: G.selected(b, app.accent)
		divisions.add_child(b)
	if is_srp or is_japan or is_nationale or is_champ:
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
	if not is_srp and not is_japan and not is_nationale and not is_champ:
		bounds = preload("res://ui/club_views.gd")._paged(app,list,"CreationPagination",division_clubs.size(),8,"creation_"+mode+"_"+division)
	var items := G.scroll(list)
	items.get_parent().name = "CreationClubsScroll"
	var grid:=GridContainer.new()
	grid.columns=3 if is_nationale or is_champ or (is_japan and app.get_viewport_rect().size.x >= 1660) else 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	G.fill(grid)
	items.add_child(grid)
	for club in division_clubs.slice(bounds.x,bounds.y):
		var b := G.button("", func(): app.selected_club = int(club.id); app._render())
		b.custom_minimum_size.y = clampf(app.get_viewport_rect().size.y * 0.045, 52.0, 66.0) if is_srp else (44.0 if is_japan or is_nationale or is_champ else 52.0)
		b.name="CreationClub"+str(int(club.id))
		b.tooltip_text=G.club_name(club)+" · "+_territory(club)
		G.fill(b)
		if club.id == app.selected_club: G.selected(b,Color(club.color))
		var inset := G.margin(8)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inset)
		var line := G.h(16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(line)
		line.add_child(G.crest(club, 32))
		var names := G.v(0)
		G.fill(names)
		names.add_child(G.cell(G.club_name(club),60,G.INK,true))
		names.add_child(G.cell(_territory(club),60,G.MUTED,true))
		line.add_child(names)
		line.add_child(G.label("→", 24, G.GOLD))
		grid.add_child(b)
	var notice := "%s joueurs · %d clubs jouables · 4 championnats et 2 coupes d’Europe." % [G.n(meta.get("worldDatabase", {}).get("playerCount", 0)), playable.size()] if international else "1 592 joueurs · 30 clubs · deux divisions reliées. Choisissez votre club et préparez votre première saison."
	if pacific: notice = "%s joueurs · %d clubs jouables · cinq championnats et deux coupes d’Europe." % [G.n(meta.get("pacificDatabase", {}).get("playerCount", 0)), playable.size()]
	if japan: notice = "%s joueurs · %d clubs jouables · sept championnats et deux coupes d’Europe." % [G.n(meta.get("japanDatabase", {}).get("playerCount", 0)), playable.size()]
	if nationale: notice = "%s joueurs · %d clubs jouables · huit championnats et deux coupes d’Europe." % [G.n(meta.get("nationaleDatabase", {}).get("playerCount", 0)), playable.size()]
	if champ: notice = "%s joueurs · %d clubs jouables · neuf championnats et deux coupes d’Europe." % [G.n(meta.get("champDatabase", {}).get("playerCount", 0)), playable.size()]
	list.add_child(G.wrap(notice, 12))
	var start := G.button("PRENDRE LES RÊNES DE " + G.club_abbr(selected) + "  →", func(): _create(app, selected, mode), true)
	start.name="CreationStart"
	start.disabled = app.waiting or unavailable
	if japan:
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
