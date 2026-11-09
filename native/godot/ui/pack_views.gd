extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")

static func _action(button: Button, primary: bool = false, height: int = 42) -> void:
	Editorial.action(button, primary, false, height)
	button.add_theme_font_override("font", Editorial.sans_bold() if primary else C.BODY)

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
	var page := C.v(15)
	page.name = "CarnetPacks"
	C.fill(page)
	var creation: bool = app.pack_manager.scope == "creation"
	var edition := str({"world-champ":"MONDE", "world-nationale":"MONDE + NATIONALE", "world-japan":"MONDE + JAPON", "world-pacific":"MONDE + PACIFIQUE", "world":"MONDE"}.get(app.pack_manager.mode(), "FRANCE 30"))
	var installed: Array = app.pack_manager.installed()
	var preview: Dictionary = app.pack_manager.preview()
	var top := C.h(16)
	page.add_child(top)
	var back := C.button("← Retour", app.pack_manager.back)
	back.name = "PackBack"
	_action(back)
	top.add_child(back)
	var heading := C.v(2)
	var importing := C.button("Importer une autre réalité", app.pack_manager.choose_file)
	importing.name = "PackImportZip"
	_action(importing)
	importing.disabled = app.waiting
	top.add_child(importing)
	var calendar := C.button("Atelier calendrier", func(): preload("res://ui/competition_editor_view.gd").open(app))
	calendar.name = "OpenCompetitionEditor"
	_action(calendar)
	calendar.disabled = app.waiting
	top.add_child(calendar)
	C.fill(heading)
	top.add_child(heading)
	var edition_label := C.label(("NOUVELLE CARRIÈRE" if creation else "CARRIÈRE EN COURS") + "  /  " + edition, 18, C.MUTED)
	edition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	edition_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	heading.add_child(edition_label)
	page.add_child(C.rule())

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
	var layouts := C.h(20)
	page.add_child(layouts)
	var base_column := C.v(0)
	C.fill(base_column, false, .375)
	layouts.add_child(base_column)
	var pack_column := C.v(14)
	C.fill(pack_column, false, .625)
	layouts.add_child(pack_column)
	var picture_height := clampf(window_size.y * .235, 140, 330)
	_catalogue(app, base_column, selected, compatible, picture_height)
	var analysing := not preview.is_empty() and not inspected_installed
	if analysing:
		_preview(app, pack_column, preview)
	elif installed.is_empty():
		_empty(pack_column, picture_height)
	var featured: Dictionary = {}
	if not installed.is_empty():
		# After installation, surface the imported pack even if another pack is active.
		var spotlight_id := inspected_id if inspected_installed and app.last_command == "pack_install" else selected
		featured = installed[0]
		for pack: Dictionary in installed:
			if str(pack.id) == spotlight_id:
				featured = pack
				break
		_installed_card(app, pack_column, featured, selected, compatible, creation, true, 0 if analysing else picture_height)
	if installed.size() > 1:
		pack_column.add_child(C.label("Autres packs installés", 28, C.IVORY, true, 700))
	for pack: Dictionary in installed:
		if pack.id != featured.id:
			_installed_card(app, pack_column, pack, selected, compatible, creation, false, 0)

	page.add_child(C.rule())
	app.status = C.wrap("Analyse en cours…" if app.waiting else "OVAL LEGACY 27     /     Installation locale", 18)
	page.add_child(app.status)
	return page

static func _empty(parent: Container, picture_height: float) -> void:
	var content := _section(parent, "Import local", "Importer une autre réalité", "match-tunnel", picture_height)
	for step in [["01", "Ouvrir le ZIP", "Choisissez une archive sur votre ordinateur."], ["02", "Vérifier le contenu", "Consultez les clubs, joueurs, compétitions et médias fournis."], ["03", "Installer", "Le pack devient disponible pour vos prochaines carrières."]]:
		content.add_child(C.rule())
		var line := C.h(14)
		content.add_child(line)
		line.add_child(C.label(step[0], 23, Editorial.BRASS))
		var title := C.label(step[1], 23, C.IVORY, true, 700)
		title.custom_minimum_size.x = C.px(190)
		line.add_child(title)
		var detail := C.wrap(step[2], 19)
		C.fill(detail)
		line.add_child(detail)

static func _section(parent: Container, caption: String, title: String, art: String = "", picture_height: float = 0, fill_height: bool = false) -> VBoxContainer:
	var frame := PanelContainer.new()
	Editorial.surface(frame, Editorial.PANEL, Editorial.LINE, 1)
	if fill_height: C.fill(frame, true)
	parent.add_child(frame)
	var column := C.v(0)
	frame.add_child(column)
	if picture_height > 0: _picture(column, art, picture_height)
	var inset := C.margin(36)
	inset.add_theme_constant_override("margin_top", C.px(16))
	inset.add_theme_constant_override("margin_bottom", C.px(19))
	C.fill(inset, true)
	column.add_child(inset)
	var content := C.v(12)
	inset.add_child(content)
	var heading := C.h(14)
	content.add_child(heading)
	heading.add_child(C.fill(Editorial.sans_heading(title, 44)))
	if not caption.is_empty():
		var badge := PanelContainer.new()
		Editorial.surface(badge, Editorial.PANEL, Editorial.BRASS, 5)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(C.label(caption, 19, Editorial.BRASS, false))
		heading.add_child(badge)
	return content

static func _picture(parent: Container, art: String, height: float) -> void:
	var photo := C.photo(art, Vector2.ZERO, true, .56)
	photo.custom_minimum_size.y = height
	parent.add_child(photo)

static func _catalogue(app: Control, parent: Container, selected: String, compatible: bool, picture_height: float) -> void:
	var content := _section(parent, "Réalité active" if selected == "base" else "", "Jeu de base", "maquette-reality-base", picture_height, true)
	content.add_child(C.label("Identités fictives", 25, C.IVORY, false))
	content.add_child(C.wrap("Une réalité construite pour Oval Legacy, avec des clubs, des joueurs et des compétitions anonymisés.", 21, C.IVORY))
	content.add_child(C.rule())
	var facts := C.h(18)
	content.add_child(facts)
	var database: Dictionary = app.pack_manager.database()
	_fact(facts, database.get("clubCount", 0), "Clubs")
	Editorial.divider(facts)
	_fact(facts, database.get("playerCount", 0), "Joueurs")
	content.add_child(C.rule())
	content.add_child(C.wrap("Les packs changent les identités et les visuels. Le calendrier et les règles restent ceux du monde commun.", 19))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(space)
	var base := C.button("Choisir le jeu de base", func(): app.pack_manager.select("base"))
	base.name = "PackUseBase"
	base.disabled = app.waiting or not compatible
	_action(base)
	base.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(base)

static func _installed_card(app: Control, parent: Container, pack: Dictionary, selected: String, compatible: bool, creation: bool, featured: bool, picture_height: float) -> void:
	var id := str(pack.id)
	var active := id == selected
	var content := _section(parent, "Pack actif" if active else "Pack installé", str(pack.get("name", "Pack personnalisé")), "maquette-reality-pack", picture_height)
	if featured:
		content.add_child(C.wrap("Les identités et les médias fournis par votre pack, dans le monde commun d’Oval Legacy 27.", 21, C.IVORY))
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
		_action(choice, not creation)
		actions.add_child(choice)
	if creation:
		actions.add_child(C.fill(Control.new()))
		var start := C.button("Nouvelle carrière", _create_with_pack.bind(app, id), true)
		start.name = "PackNewCareer" if featured else "PackNewCareer_" + id
		start.disabled = app.waiting or app.model.get("meta", {}).get("recoveryRequired", false)
		start.tooltip_text = "Choisir un club avec " + str(pack.get("name", "ce pack"))
		start.icon = C.icon_texture("arrow", Editorial.INK)
		start.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		start.expand_icon = true
		start.add_theme_constant_override("icon_max_width", C.px(31))
		start.custom_minimum_size.x = C.px(390)
		_action(start, true, maxi(42, C.px(66)) if featured else 42)
		actions.add_child(start)

static func _create_with_pack(app: Control, id: String) -> void:
	if app.waiting:
		app._refuse_action("Attendez la réponse du moteur avant de continuer.")
		return
	if id == app.pack_manager.selected_id("creation"):
		app._navigate("Création")
	else:
		app._command("pack_select", {"id":id, "scope":"creation", "mode":app.pack_manager.mode("creation")}, "Création")

static func _inventory(parent: VBoxContainer, pack: Dictionary) -> void:
	var counts: Dictionary = pack.get("counts", {})
	parent.add_child(C.rule())
	var tiles := C.h(12)
	parent.add_child(tiles)
	_fact(tiles, counts.get("clubs", 0), "Clubs")
	Editorial.divider(tiles)
	_fact(tiles, counts.get("players", 0), "Joueurs")
	Editorial.divider(tiles)
	if counts.has("competitions"):
		_fact(tiles, counts.competitions, "Compétitions")
	else:
		_fact(tiles, counts.get("logos", 0), "Blasons")
	var media := [["Portraits", "%s photos de joueurs · %s portraits IA" % [G.n(counts.get("official", 0)), G.n(counts.get("synthetic", 0))]]]
	var identities := "%s blasons de clubs" % G.n(counts.get("logos", 0))
	if counts.has("competitionLogos"):
		identities += " · %s logos de compétitions" % G.n(counts.competitionLogos)
	media.append(["Identités", identities])
	if counts.has("staff"):
		media.append(["Staff", "%s identités · %s photos officielles · %s illustrations IA" % [G.n(counts.staff), G.n(counts.get("staffOfficial", 0)), G.n(counts.get("staffSynthetic", 0))]])
	if counts.has("cityPhotos") or counts.has("stadiumPhotos"):
		media.append(["Lieux", "%s villes en photo · %s stades en photo" % [G.n(counts.get("cityPhotos", 0)), G.n(counts.get("stadiumPhotos", 0))]])
	for item: Array in media:
		parent.add_child(C.rule())
		var line := C.h(16)
		parent.add_child(line)
		var label := Editorial.sans_heading(item[0], 20)
		label.custom_minimum_size.x = C.px(225)
		line.add_child(label)
		line.add_child(C.fill(C.wrap(item[1], 19, C.IVORY)))

static func _fact(parent: Container, value: Variant, caption: String) -> void:
	var line := C.h(8)
	C.fill(line)
	parent.add_child(line)
	var number := Editorial.sans_heading(G.n(value), 29)
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(number)
	var label := C.wrap(caption, 22, C.IVORY)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(C.fill(label))

static func _preview(app: Control, parent: Container, pack: Dictionary) -> void:
	var content := _section(parent, "Prêt à installer", str(pack.get("name", "Pack personnalisé")))
	_inventory(content, pack)
	content.add_child(C.wrap("L’installation ajoute le pack à votre profil. Vous pourrez ensuite le sélectionner."))
	if pack.get("rightsStatus", "") == "not-cleared-for-public-distribution":
		content.add_child(C.wrap("Droits de redistribution publique des photos et logos à vérifier séparément."))
	var install := C.button("INSTALLER CE PACK", app.pack_manager.install, true)
	_action(install, true)
	install.disabled = app.waiting
	install.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(install)
