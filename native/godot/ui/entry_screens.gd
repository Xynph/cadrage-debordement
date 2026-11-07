extends RefCounted
const G = preload("res://ui/game_skin.gd")

static func home(app: Control) -> Control:
	var club: Dictionary = app.model.get("club", {}) if app.model.get("club") is Dictionary else {}
	var slug: String = G.identity(club).get("slug", "perpignan")
	var page := G.picture(slug)
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
	over.add_child(G.label("OVAL LEGACY 27  /  BUILD YOUR CLUB. LEAVE YOUR MARK.", 14, G.GOLD))
	over.add_child(G.spacer())
	var row := G.h(70)
	over.add_child(row)
	var intro := G.v(4)
	G.fill(intro)
	row.add_child(intro)
	intro.add_child(G.label("OVAL", 90, G.INK, true))
	var edition := G.h(18)
	intro.add_child(edition)
	edition.add_child(G.label("LEGACY", 90, G.INK, true))
	edition.add_child(G.label("27", 72, G.GOLD, true))
	intro.add_child(G.wrap("Un club. Un territoire.\nUne saison à écrire.", 23, G.INK))
	intro.add_child(G.label("RUGBY MANAGER", 18, G.GOLD))
	var choices := G.v(9)
	choices.custom_minimum_size.x = 330
	row.add_child(choices)
	if not club.is_empty():
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
	var meta: Dictionary = app.model.get("meta", {})
	if meta.get("recoveryRequired", false):
		choices.add_child(G.wrap("Le profil ne peut pas être chargé. Sa copie sera conservée avant toute récupération.", 12, Color("f1b6a9")))
		choices.add_child(G.button("RÉCUPÉRER LE PROFIL", app.recover_profile))
	elif app.connection_error or not app.last_error.is_empty():
		choices.add_child(G.wrap(app.last_error, 12, Color("f1b6a9")))
		choices.add_child(G.button("RÉESSAYER LA CONNEXION", app.reconnect) if app.connection_error else G.button("CHOISIR À NOUVEAU UN CLUB",func():app._navigate("Création")))
	over.add_child(G.spacer())
	var footer := G.h()
	over.add_child(footer)
	var note := G.label("VERSION DE DÉVELOPPEMENT 0.3  ·  APPLICATION WINDOWS NATIVE", 11, G.MUTED)
	G.fill(note)
	footer.add_child(note)
	footer.add_child(G.button("CRÉDITS", app._credits))
	return page

static func creation(app: Control) -> Control:
	var page := G.v(16)
	var top := G.h()
	page.add_child(top)
	top.add_child(G.button("← ACCUEIL", func(): app._navigate("Accueil")))
	var title := G.label("CHOISISSEZ VOTRE HISTOIRE", 42, G.INK, true)
	G.fill(title)
	top.add_child(title)
	top.add_child(G.button("PACKS ET IDENTITÉS", func(): app.pack_manager.open("creation")))
	var row := G.h(24)
	G.fill(row, true)
	page.add_child(row)
	var selected: Dictionary = app.catalogue[app.selected_club]
	var photo := G.picture(selected.slug)
	G.fill(photo, true, 0.95)
	row.add_child(photo)
	var over: VBoxContainer = photo.get_meta("content")
	over.add_child(G.label("VOTRE FUTUR CLUB", 12, G.GOLD))
	over.add_child(G.spacer())
	over.add_child(G.crest(selected, 96))
	var name := G.label(selected.name, 42, G.INK, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over.add_child(name)
	over.add_child(G.label(selected.city, 18))
	over.add_child(G.wrap(selected.stadium, 14, G.MUTED))
	over.add_child(G.label("OBJECTIF  /  " + selected.goal.to_upper(), 12, G.GOLD))
	var list := G.v(12)
	G.fill(list, true, 1.2)
	row.add_child(list)
	var packs: Dictionary = app.model.get("packs", {})
	var pack_name := "BASE ANONYMISÉE"
	for pack: Dictionary in packs.get("installed", []):
		if str(pack.get("id", "")) == str(packs.get("creation", "base")):
			pack_name = str(pack.get("name", "Pack personnalisé")).to_upper()
	list.add_child(G.wrap("IDENTITÉS  /  " + pack_name, 12, G.GOLD))
	var pack_choice := OptionButton.new()
	pack_choice.add_item("Base anonymisée")
	var pack_ids: Array[String] = ["base"]
	for pack: Dictionary in packs.get("installed", []):
		pack_choice.add_item(str(pack.get("name", "Pack personnalisé")))
		pack_ids.append(str(pack.id))
	pack_choice.select(maxi(0, pack_ids.find(str(packs.get("creation", "base")))))
	pack_choice.disabled = app.waiting
	pack_choice.item_selected.connect(func(index: int): app._command("pack_select", {"id":pack_ids[index],"scope":"creation"}))
	list.add_child(pack_choice)
	var divisions := G.h(8)
	list.add_child(divisions)
	for item in [["elite", "ÉLITE  /  14 CLUBS"], ["accession", "ACCESSION  /  16 CLUBS"]]:
		var b := G.button(item[1], func(): app.club_division = item[0]; app._render())
		G.fill(b)
		if app.club_division == item[0]: b.add_theme_stylebox_override("normal", G.T.box(Color("4a3930"), 4, G.GOLD))
		divisions.add_child(b)
	var items := G.scroll(list)
	for club in app.catalogue:
		if club.division != app.club_division: continue
		var b := G.button("", func(): app.selected_club = int(club.id); app._render())
		b.custom_minimum_size.y = 64
		if club.id == app.selected_club: b.add_theme_stylebox_override("normal", G.T.box(Color(club.color).darkened(0.65), 5, Color(club.color)))
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
		names.add_child(G.label(club.name, 22, G.INK, true))
		names.add_child(G.label(club.city, 11, G.MUTED))
		line.add_child(names)
		line.add_child(G.label("→", 24, G.GOLD))
		items.add_child(b)
	list.add_child(G.wrap("Base commune de 1 592 joueurs · identités anonymisées ou personnalisées. Capacités et finances de simulation, non officielles. Deux divisions reliées ; monde fermé à 30 clubs.", 12))
	list.add_child(G.button("PRENDRE LES RÊNES DE " + selected.abbr + "  →", func(): app.create_career(int(selected.id)), true))
	return page
