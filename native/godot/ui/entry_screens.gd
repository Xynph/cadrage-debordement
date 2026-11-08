extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const Packs = preload("res://ui/pack_views.gd")

static func home(app: Control) -> Control:
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	var slug: String = G.identity(club).get("slug", "perpignan")
	var page := G.picture(slug)
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
	page.move_child(veil,2)
	var over: VBoxContainer = page.get_meta("content")
	over.add_child(G.label("OVAL LEGACY 27  /  BUILD YOUR CLUB. LEAVE YOUR MARK.", 14, G.WHITE))
	over.add_child(G.spacer())
	var row := G.h(48)
	over.add_child(row)
	var intro := G.v(4)
	G.fill(intro)
	row.add_child(intro)
	var logo := TextureRect.new()
	logo.texture = load("res://branding/oval-legacy-27-logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(460, 230)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	logo.tooltip_text = "Oval Legacy 27 — Rugby Manager"
	var composite := ShaderMaterial.new()
	composite.shader = load("res://branding/black_key.gdshader")
	logo.material = composite
	intro.add_child(logo)
	intro.add_child(G.wrap("Un club. Un territoire.\nUne saison à écrire.", 26, G.WHITE))
	var choices := G.panel(row)
	choices.get_parent().custom_minimum_size.x=430
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
		choices.add_child(G.label(G.club_name(club), 26, G.INK, true))
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
	top.add_child(G.button("PACKS ET IDENTITÉS", func(): app.pack_manager.open("creation")))
	Packs.missing_warning(app, page, "creation")
	var row := G.h(24)
	G.fill(row, true)
	page.add_child(row)
	var selected: Dictionary = app.catalogue[app.selected_club]
	var photo := G.picture(selected.slug)
	G.fill(photo, true, 0.95)
	row.add_child(photo)
	var over: VBoxContainer = photo.get_meta("content")
	over.add_child(G.label("VOTRE FUTUR CLUB", 14, G.WHITE))
	over.add_child(G.spacer())
	over.add_child(G.crest(selected, 96))
	var name := G.label(selected.name, 38, G.WHITE, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over.add_child(name)
	over.add_child(G.label(selected.city, 18,G.WHITE))
	over.add_child(G.wrap(selected.stadium, 14, G.WHITE))
	over.add_child(G.label("OBJECTIF  /  " + selected.goal.to_upper(), 14, G.WHITE))
	var list := G.panel(row,1.2)
	G.chapter(list,"01","Prendre les rênes","Choisissez les identités puis votre club.",app.accent)
	var packs: Dictionary = app.model.get("packs", {})
	var pack_name := "BASE ANONYMISÉE"
	for pack: Dictionary in packs.get("installed", []):
		if str(pack.get("id", "")) == str(packs.get("creation", "base")):
			pack_name = str(pack.get("name", "Pack personnalisé")).to_upper()

	var pack_choice := OptionButton.new()
	pack_choice.name="CreationPackChoice"
	pack_choice.add_item("Base anonymisée")
	var pack_ids: Array[String] = ["base"]
	for pack: Dictionary in packs.get("installed", []):
		pack_choice.add_item(str(pack.get("name", "Pack personnalisé")))
		pack_ids.append(str(pack.id))
	var selected_pack := pack_ids.find(str(packs.get("creation", "base")))
	var unavailable := selected_pack < 0
	if unavailable:
		pack_name = "PACK INDISPONIBLE"
		selected_pack = pack_choice.item_count
		pack_choice.add_item("Pack indisponible · réimportez ou choisissez Base")
		pack_choice.set_item_disabled(selected_pack, true)
	pack_choice.select(selected_pack)
	list.add_child(G.wrap("IDENTITÉS  /  " + pack_name, 12, G.GOLD))
	pack_choice.disabled = app.waiting
	pack_choice.item_selected.connect(func(index: int): app._command("pack_select", {"id":pack_ids[index],"scope":"creation"}))
	list.add_child(pack_choice)
	var divisions := G.h(8)
	list.add_child(divisions)
	for item in [["elite", "ÉLITE  /  14 CLUBS"], ["accession", "ACCESSION  /  16 CLUBS"]]:
		var b := G.button(item[1], func(): app.club_division = item[0]; app._render())
		G.fill(b)
		if app.club_division == item[0]: G.selected(b,app.accent)
		divisions.add_child(b)
	var items := G.scroll(list)
	for club in app.catalogue:
		if club.division != app.club_division: continue
		var b := G.button("", func(): app.selected_club = int(club.id); app._render())
		b.custom_minimum_size.y = 64
		if club.id == app.selected_club: G.selected(b,Color(club.color))
		var inset := G.margin(8)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inset)
		var line := G.h(16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(line)
		line.add_child(G.crest(club, 46))
		var names := G.v(0)
		G.fill(names)
		names.add_child(G.label(club.name, 19, G.INK))
		names.add_child(G.label(club.city, 13, G.MUTED))
		line.add_child(names)
		line.add_child(G.label("→", 24, G.GOLD))
		items.add_child(b)
	list.add_child(G.wrap("Base commune de 1 592 joueurs · identités anonymisées ou personnalisées. Capacités et finances de simulation, non officielles. Deux divisions reliées ; monde fermé à 30 clubs.", 12))
	var start := G.button("PRENDRE LES RÊNES DE " + selected.abbr + "  →", func(): app.create_career(int(selected.id)), true)
	start.disabled = app.waiting or unavailable
	list.add_child(start)
	return page
