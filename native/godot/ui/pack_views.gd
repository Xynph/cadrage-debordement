extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")

static func missing_warning(app: Control, parent: Container, scope: String, paper: bool = false) -> void:
	var messages: Array[String] = []
	var career_missing := false
	for warning: String in app.model.get("packs", {}).get("missing", []):
		if warning.begins_with("Pack de carrière absent") and scope != "creation":
			messages.append("Pack de carrière absent · Présentation de base anonymisée. Réimportez le pack pour retrouver vos identités.")
			career_missing = true
	if scope != "career" and _creation_missing(app):
		messages.append("Pack de création absent · Présentation de base anonymisée. Réimportez le pack ou choisissez Base pour créer une carrière.")
	if messages.is_empty(): return
	parent.add_child(G.wrap("\n".join(messages), 13, G.ALERT if paper else Color("f1b6a9")))
	parent.add_child(G.button("GÉRER LES PACKS", func(): app.pack_manager.open("career" if career_missing else "creation")))

static func _creation_missing(app: Control) -> bool:
	if not is_instance_valid(app.pack_manager): return false
	var chosen: String = app.pack_manager.selected_id("creation")
	return chosen != "base" and not app.pack_manager.installed("creation").any(func(pack: Dictionary): return str(pack.id) == chosen)

static func page(app: Control) -> Control:
	var window_size := app.get_window().size
	C.configure(window_size.y, window_size.x)
	var page := C.v(20)
	page.name = "CarnetPacks"
	C.fill(page)
	var creation: bool = app.pack_manager.scope == "creation"
	var edition := str({"world-champ":"MONDE", "world-nationale":"MONDE + NATIONALE", "world-japan":"MONDE + JAPON", "world-pacific":"MONDE + PACIFIQUE", "world":"MONDE"}.get(app.pack_manager.mode(), "FRANCE 30"))
	var installed: Array = app.pack_manager.installed()
	var preview: Dictionary = app.pack_manager.preview()
	var top := C.h(16)
	page.add_child(top)
	var back := C.button("← RETOUR", app.pack_manager.back)
	back.name = "PackBack"
	top.add_child(back)
	var heading := C.v(2)
	C.fill(heading)
	top.add_child(heading)
	heading.add_child(C.label("Vos packs", 32, C.IVORY, true, 700))
	heading.add_child(C.wrap(("NOUVELLE CARRIÈRE" if creation else "CARRIÈRE EN COURS") + "  /  " + edition, 19, C.GOLD, true))
	var importing := C.button("IMPORTER UN PACK ZIP", app.pack_manager.choose_file, installed.is_empty() and preview.is_empty())
	importing.name = "PackImportZip"
	importing.disabled = app.waiting
	top.add_child(importing)
	var calendar := C.button("ATELIER CALENDRIER", func(): preload("res://ui/competition_editor_view.gd").open(app))
	calendar.name = "OpenCompetitionEditor"
	calendar.disabled = app.waiting
	top.add_child(calendar)

	var compatible: bool = creation or app.model.get("meta", {}).get("database", {}).get("active", false)
	var packs: Dictionary = app.model.get("packs", {})
	var selected: String = app.pack_manager.selected_id()
	if not compatible:
		page.add_child(C.wrap("Cette ancienne carrière utilise des joueurs générés. Vous pouvez installer des packs ici et les utiliser dans une nouvelle carrière sur la base commune.", 21, C.ALERT))
	var missing: Array = packs.get("missing", []).filter(func(message: String): return message.begins_with("Stockage") or not creation and message.begins_with("Pack de carrière absent"))
	if creation and _creation_missing(app): missing.append("Pack de création absent dans cette édition")
	if not missing.is_empty():
		page.add_child(C.wrap("PACK MANQUANT · " + ", ".join(missing) + "\nLes identités concernées utilisent la base anonymisée. Réimportez le pack pour retrouver ses images et ses noms.", 21, C.ALERT))
	if not app.last_error.is_empty(): page.add_child(C.wrap(app.last_error, 21, C.ALERT))

	var inspected_id := str(preview.get("id", ""))
	var inspected_installed := installed.any(func(pack: Dictionary): return str(pack.id) == inspected_id)
	if not preview.is_empty() and not inspected_installed:
		_preview(app, page, preview)
	elif installed.is_empty():
		_empty(page)
	var featured: Dictionary = {}
	if not installed.is_empty():
		# After installation, surface the imported pack even if another pack is active.
		var spotlight_id := inspected_id if inspected_installed and app.last_command == "pack_install" else selected
		featured = installed[0]
		for pack: Dictionary in installed:
			if str(pack.id) == spotlight_id:
				featured = pack
				break
		_installed_card(app, page, featured, selected, compatible, creation, true)
	if installed.size() > 1:
		page.add_child(C.label("Autres packs installés", 28, C.IVORY, true, 700))
	for pack: Dictionary in installed:
		if pack.id != featured.id:
			_installed_card(app, page, pack, selected, compatible, creation, false)

	_catalogue(app, page, selected, compatible)
	app.status = C.wrap("Analyse en cours…" if app.waiting else "Installation locale · aucun téléchargement automatique", 19)
	page.add_child(app.status)
	return page

static func _empty(parent: Container) -> void:
	var frame := C.card()
	parent.add_child(frame)
	var content := C.content(frame)
	content.add_child(C.label("Votre premier pack", 42, C.IVORY, true, 700))
	content.add_child(C.wrap("Personnalisez les noms, les blasons et les portraits à partir d’un fichier ZIP sur votre ordinateur."))
	var steps := C.h()
	content.add_child(steps)
	_metric(steps, "01", "Ouvrez le fichier ZIP", C.GOLD)
	_metric(steps, "02", "Vérifiez l’inventaire", C.GOLD)
	_metric(steps, "03", "Installez le pack dans votre profil", C.GOLD)

static func _catalogue(app: Control, parent: Container, selected: String, compatible: bool) -> void:
	var frame := C.card()
	parent.add_child(frame)
	var content := C.content(frame)
	var row := C.h(24)
	content.add_child(row)
	var info := C.v(4)
	C.fill(info)
	row.add_child(info)
	info.add_child(C.label("Catalogue du jeu", 27, C.IVORY, true, 700))
	var database: Dictionary = app.pack_manager.database()
	if not database.is_empty():
		info.add_child(C.wrap("%s clubs · %s joueurs dans cette édition" % [G.n(database.get("clubCount", 0)), G.n(database.get("playerCount", 0))]))
	if selected == "base":
		info.add_child(C.label("ACTUELLEMENT · BASE ANONYMISÉE", 19, C.GOLD))
	var base := C.button("UTILISER LA BASE ANONYMISÉE", func(): app.pack_manager.select("base"))
	base.name = "PackUseBase"
	base.disabled = app.waiting or not compatible
	base.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(base)
	content.add_child(C.wrap("Les packs personnalisent la présentation. Les joueurs générés gardent des identités fictives."))
	content.add_child(C.wrap("Les packs installés et leurs médias sont stockés dans votre profil local.", 19))

static func _installed_card(app: Control, parent: Container, pack: Dictionary, selected: String, compatible: bool, creation: bool, featured: bool) -> void:
	var id := str(pack.id)
	var active := id == selected
	var frame := C.card()
	parent.add_child(frame)
	if active or featured:
		var surface := C.box(C.RAISED, C.MINT if active else C.GOLD, 8, 22)
		surface.border_width_left = maxi(3, C.px(6))
		frame.add_theme_stylebox_override("panel", surface)
	var content := C.content(frame)
	content.add_child(C.label("PACK ACTIF" if active else "PACK INSTALLÉ", 21, C.MINT if active else C.GOLD, true, 700))
	content.add_child(C.wrap(pack.get("name", "Pack personnalisé"), 58 if featured else 32, C.IVORY, true, 700))
	if featured:
		var summary := "Ce pack est prêt à être utilisé."
		if active:
			summary = "Ce pack est sélectionné pour vos prochaines créations." if creation else "Ce pack habille la carrière ouverte."
		content.add_child(C.wrap(summary))
		_inventory(content, pack)
		content.add_child(C.rule())
	else:
		var counts: Dictionary = pack.get("counts", {})
		content.add_child(C.wrap("%s identités de joueurs · %s blasons de clubs" % [G.n(counts.get("players", 0)), G.n(counts.get("logos", 0))]))
	if active and not creation: return
	var actions := C.h(14)
	content.add_child(actions)
	if not active:
		var choice := C.button("UTILISER CE PACK  →", func(): app.pack_manager.select(id), not creation)
		choice.disabled = app.waiting or not compatible
		actions.add_child(choice)
	if creation:
		var start := C.button("Nouvelle carrière", _create_with_pack.bind(app, id), true)
		start.name = "PackNewCareer" if featured else "PackNewCareer_" + id
		start.disabled = app.waiting or app.model.get("meta", {}).get("recoveryRequired", false)
		start.tooltip_text = "Choisir un club avec " + str(pack.get("name", "ce pack"))
		start.custom_minimum_size = Vector2(maxi(260, C.px(480)), maxi(50, C.px(86)) if featured else 34)
		start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if featured:
			start.add_theme_font_size_override("font_size", maxi(22, C.px(34)))
			actions.add_child(C.fill(Control.new()))
			var next := C.label("Étape suivante · choisir votre club", 20, C.MUTED, false)
			next.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			actions.add_child(next)
		actions.add_child(start)

static func _create_with_pack(app: Control, id: String) -> void:
	if app.waiting:
		app._refuse_action("Attendez la réponse du moteur avant de continuer.")
		return
	if id == app.pack_manager.selected_id("creation"):
		app._navigate("Création")
	else:
		app._command("pack_select", {"id":id, "scope":"creation", "mode":app.pack_manager.mode("creation")}, "Création")

static func _metric(parent: Container, value: Variant, caption: String, tint: Color = C.IVORY) -> void:
	var tile := C.card()
	C.fill(tile)
	tile.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 6, 13))
	parent.add_child(tile)
	var content := C.content(tile)
	content.add_child(C.label(value, 40, tint, true, 700))
	content.add_child(C.wrap(caption, 21))

static func _inventory(parent: VBoxContainer, pack: Dictionary) -> void:
	var counts: Dictionary = pack.get("counts", {})
	parent.add_child(C.label("INVENTAIRE DU PACK", 21, C.GOLD, true, 700))
	var tiles := C.h(12)
	parent.add_child(tiles)
	_metric(tiles, counts.get("clubs", 0), "Clubs personnalisés")
	_metric(tiles, counts.get("players", 0), "Identités de joueurs")
	_metric(tiles, counts.get("logos", 0), "Blasons de clubs")
	if counts.has("competitions"):
		_metric(tiles, counts.competitions, "Compétitions personnalisées")
	if counts.has("competitionLogos"):
		_metric(tiles, counts.competitionLogos, "Logos de compétitions")
	var media: Array[String] = ["Portraits de joueurs recensés dans le pack · %s photos officielles · %s illustrations IA" % [G.n(counts.get("official", 0)), G.n(counts.get("synthetic", 0))]]
	if counts.has("staff"):
		media.append("Staff · %s identités · %s photos officielles · %s illustrations IA" % [G.n(counts.staff), G.n(counts.get("staffOfficial", 0)), G.n(counts.get("staffSynthetic", 0))])
	if counts.has("cityPhotos") or counts.has("stadiumPhotos"):
		media.append("Lieux · %s villes en photo · %s stades en photo" % [G.n(counts.get("cityPhotos", 0)), G.n(counts.get("stadiumPhotos", 0))])
	for line: String in media:
		parent.add_child(C.wrap(line, 21))

static func _preview(app: Control, parent: Container, pack: Dictionary) -> void:
	var frame := C.card()
	parent.add_child(frame)
	var content := C.content(frame)
	content.add_child(C.label("PRÊT À INSTALLER", 21, C.GOLD, true, 700))
	content.add_child(C.wrap(pack.get("name", "Pack personnalisé"), 46, C.IVORY, true, 700))
	_inventory(content, pack)
	content.add_child(C.wrap("L’installation ajoute le pack à votre profil. Vous pourrez ensuite le sélectionner."))
	if pack.get("rightsStatus", "") == "not-cleared-for-public-distribution":
		content.add_child(C.wrap("Droits de redistribution publique des photos et logos à vérifier séparément."))
	var install := C.button("INSTALLER CE PACK", app.pack_manager.install, true)
	install.disabled = app.waiting
	install.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(install)
