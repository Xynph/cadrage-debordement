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
	if pacific:
		var country := str(identity.get("country", "")).to_lower()
		var art := "res://art/pacific/covers/%s.svg" % country
		if country in ["nz","au","fj"] and ResourceLoader.exists(art):
			cover.clip_contents = true
			var backdrop := TextureRect.new()
			backdrop.texture = load(art) as Texture2D
			backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cover.add_child(backdrop)
	var inset := G.margin(22 if pacific else 12)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(inset)
	var content := G.v(8)
	inset.add_child(content)
	cover.set_meta("content", content)
	return cover

static func _territory(club: Dictionary) -> String:
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
	var note := G.label("VERSION DE DÉVELOPPEMENT 0.5  ·  APPLICATION WINDOWS NATIVE", 12, G.WHITE)
	G.fill(note)
	footer.add_child(note)
	footer.add_child(G.button("CRÉDITS", app._credits))
	return page

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
	var pacific := mode == "world-pacific"
	var international := pacific or mode == "world"
	if not meta.get("worldCatalogue", []).is_empty():
		var edition_row := top
		var choices := [["world", "MONDE · 56 CLUBS"], ["common", "FRANCE · 30 CLUBS"]]
		if not meta.get("pacificCatalogue", []).is_empty():
			edition_row = G.h(8)
			edition_row.name = "CreationEditionRow"
			page.add_child(edition_row)
			edition_row.add_child(G.label("ÉDITION DE CARRIÈRE", 13, G.GOLD, true))
			choices.push_front(["world-pacific", "MONDE + PACIFIQUE · 66 CLUBS"])
		for item in choices:
			var choice := G.button(item[1], func(): app.pack_manager.creation_mode = item[0]; app._render())
			choice.name = "CreationMode_" + item[0]
			choice.disabled = app.waiting
			if mode == item[0]: G.selected(choice, app.accent)
			edition_row.add_child(choice)
	top.add_child(G.button("PACKS ET IDENTITÉS", func(): app.pack_manager.open("creation")))
	Packs.missing_warning(app, page, "creation")
	var candidates: Array = meta.get("pacificCatalogue", []) if pacific else (meta.get("worldCatalogue", []) if international else meta.get("legacyCatalogue", app.catalogue))
	var clubs: Array = candidates.filter(func(club: Dictionary): return club.get("playable", true))
	if clubs.is_empty():
		page.add_child(G.wrap("Le catalogue des clubs est en cours de chargement.", 15, G.WHITE))
		return page
	var division := str(app.club_division)
	var divisions_data := [["elite", "ÉLITE"], ["accession", "ACCESSION"], ["prem", "PREM"], ["urc", "URC"]] if international else [["elite", "ÉLITE"], ["accession", "ACCESSION"]]
	if pacific: divisions_data.append(["srp", "PACIFIQUE"])
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
	if is_srp:
		over.add_child(G.label("PACIFIQUE  /  SAISON 2027", 22, G.WHITE, true))
		over.add_child(G.label(_territory(selected).to_upper(), 13, G.WHITE))
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
	var pack_name := "MONDE D’OVAL LEGACY 27"
	for pack: Dictionary in installed:
		if str(pack.get("id", "")) == preferred:
			pack_name = str(pack.get("name", "Pack personnalisé")).to_upper()

	var pack_choice := OptionButton.new()
	pack_choice.name="CreationPackChoice"
	pack_choice.add_item("Monde d’Oval Legacy 27")
	var pack_ids: Array[String] = ["base"]
	for pack: Dictionary in installed:
		pack_choice.add_item(str(pack.get("name", "Pack personnalisé")))
		pack_ids.append(str(pack.id))
	var selected_pack := pack_ids.find(preferred)
	var unavailable := selected_pack < 0
	if unavailable:
		pack_name = "PACK INDISPONIBLE"
		selected_pack = pack_choice.item_count
		pack_choice.add_item("Pack indisponible · réimportez ou choisissez Base")
		pack_choice.set_item_disabled(selected_pack, true)
	pack_choice.select(selected_pack)
	list.add_child(G.wrap("IDENTITÉS  /  " + pack_name, 12, G.GOLD))
	pack_choice.disabled = app.waiting
	pack_choice.item_selected.connect(func(index: int):
		if index < pack_ids.size(): app.pack_manager.select(pack_ids[index], "creation"))
	list.add_child(pack_choice)
	var divisions := G.h(8)
	list.add_child(divisions)
	for item in divisions_data:
		var members: Array = clubs.filter(func(club: Dictionary): return club.division == item[0])
		var caption := "%s · %d" % [item[1], members.size()] if international else "%s  /  %d CLUBS" % [item[1], members.size()]
		var b := G.button(caption, func(): _division(app, item[0], members, mode))
		b.name = "CreationDivision_" + item[0]
		b.disabled = app.waiting or members.is_empty()
		G.fill(b)
		if app.club_division == item[0]: G.selected(b,app.accent)
		divisions.add_child(b)
	if is_srp:
		var facts := G.h(8)
		list.add_child(facts)
		for fact in [["16", "MATCHS PAR CLUB"], ["6", "QUALIFIÉS POUR LES FINALES"], ["FÉV.–JUIN", "SAISON 2027"]]:
			var tile := G.panel(facts, 1.0)
			tile.add_child(G.label(fact[0], 20, G.INK, true))
			tile.add_child(G.cell(fact[1], 45, G.MUTED, true))
	var bounds := Vector2i(0, division_clubs.size())
	if not is_srp:
		bounds = preload("res://ui/club_views.gd")._paged(app,list,"CreationPagination",division_clubs.size(),8,"creation_"+mode+"_"+division)
	var items := G.scroll(list)
	items.get_parent().name = "CreationClubsScroll"
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	G.fill(grid)
	items.add_child(grid)
	for club in division_clubs.slice(bounds.x,bounds.y):
		var b := G.button("", func(): app.selected_club = int(club.id); app._render())
		b.custom_minimum_size.y = clampf(app.get_viewport_rect().size.y * 0.045, 52.0, 66.0) if is_srp else 52.0
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
	var notice := "%s joueurs · %d clubs jouables · 4 championnats et 2 coupes d’Europe." % [G.n(meta.get("worldDatabase", {}).get("playerCount", 0)), clubs.size()] if international else "1 592 joueurs · 30 clubs · deux divisions reliées. Choisissez votre club et préparez votre première saison."
	if pacific: notice = "%s joueurs · %d clubs jouables · cinq championnats et deux coupes d’Europe." % [G.n(meta.get("pacificDatabase", {}).get("playerCount", 0)), clubs.size()]
	list.add_child(G.wrap(notice, 12))
	var start := G.button("PRENDRE LES RÊNES DE " + G.club_abbr(selected) + "  →", func(): _create(app, selected, mode), true)
	start.name="CreationStart"
	start.disabled = app.waiting or unavailable
	list.add_child(start)
	return page
