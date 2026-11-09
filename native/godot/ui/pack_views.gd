extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")

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
	var back := C.button("← RETOUR", app.pack_manager.back)
	back.name = "PackBack"
	Editorial.action(back)
	top.add_child(back)
	var heading := C.v(2)
	C.fill(heading)
	top.add_child(heading)
	heading.add_child(C.wrap(("NOUVELLE CARRIÈRE" if creation else "CARRIÈRE EN COURS") + "  /  " + edition, 23, Editorial.BRASS, true))
	heading.add_child(C.wrap("Choisissez les identités de votre carrière.", 19))
	var importing := C.button("IMPORTER UN PACK ZIP", app.pack_manager.choose_file, installed.is_empty() and preview.is_empty())
	importing.name = "PackImportZip"
	Editorial.action(importing, installed.is_empty() and preview.is_empty())
	importing.disabled = app.waiting
	top.add_child(importing)
	var calendar := C.button("ATELIER CALENDRIER", func(): preload("res://ui/competition_editor_view.gd").open(app))
	calendar.name = "OpenCompetitionEditor"
	Editorial.action(calendar)
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
	var layouts := C.h(20)
	page.add_child(layouts)
	var base_column := C.v(0)
	C.fill(base_column, false, .39)
	layouts.add_child(base_column)
	var pack_column := C.v(14)
	C.fill(pack_column, false, .61)
	layouts.add_child(pack_column)
	var picture_height := clampf(window_size.y * .25, 150, 340)
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

	app.status = C.wrap("Analyse en cours…" if app.waiting else "Installation locale · aucun téléchargement automatique", 19)
	page.add_child(app.status)
	return page

static func _empty(parent: Container, picture_height: float) -> void:
	var content := _section(parent, "IMPORT LOCAL", "Importer une autre réalité", false, "match-tunnel", picture_height)
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

static func _section(parent: Container, caption: String, title: String, active: bool, art: String = "", picture_height: float = 0) -> VBoxContainer:
	var frame := PanelContainer.new()
	Editorial.surface(frame, Editorial.PANEL, Editorial.BRASS if active else Editorial.LINE, 20)
	parent.add_child(frame)
	var content := C.v(13)
	frame.add_child(content)
	if picture_height > 0: _picture(content, art, picture_height)
	content.add_child(C.label(caption, 20, Editorial.BRASS))
	content.add_child(C.wrap(title, 41, C.IVORY, true, 700))
	return content

static func _picture(parent: Container, art: String, height: float) -> void:
	var photo := C.photo(art, Vector2.ZERO, true, .56)
	photo.custom_minimum_size.y = height
	parent.add_child(photo)

static func _catalogue(app: Control, parent: Container, selected: String, compatible: bool, picture_height: float) -> void:
	var content := _section(parent, "BASE ANONYMISÉE · ACTIVE" if selected == "base" else "BASE ANONYMISÉE", "Jeu de base", selected == "base", "nationale-ground", picture_height)
	C.fill(content.get_parent(), true)
	var facts := C.h(18)
	content.add_child(facts)
	var database: Dictionary = app.pack_manager.database()
	Editorial.fact(facts, database.get("clubCount", 0), "Clubs")
	Editorial.divider(facts)
	Editorial.fact(facts, database.get("playerCount", 0), "Joueurs")
	content.add_child(C.rule())
	content.add_child(C.wrap("Clubs, joueurs et compétitions portent des identités fictives.", 22, C.IVORY))
	content.add_child(C.wrap("Les packs changent les identités et les visuels. Le calendrier et les règles restent ceux du monde commun.", 19))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(space)
	var base := C.button("UTILISER LA BASE ANONYMISÉE", func(): app.pack_manager.select("base"))
	base.name = "PackUseBase"
	base.disabled = app.waiting or not compatible
	Editorial.action(base)
	content.add_child(base)

static func _installed_card(app: Control, parent: Container, pack: Dictionary, selected: String, compatible: bool, creation: bool, featured: bool, picture_height: float) -> void:
	var id := str(pack.id)
	var active := id == selected
	var content := _section(parent, "PACK ACTIF" if active else "PACK INSTALLÉ", str(pack.get("name", "Pack personnalisé")), active, "pacific-ground", picture_height)
	if featured:
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
		Editorial.action(choice, not creation)
		actions.add_child(choice)
	if creation:
		var start := C.button("Nouvelle carrière", _create_with_pack.bind(app, id), true)
		start.name = "PackNewCareer" if featured else "PackNewCareer_" + id
		start.disabled = app.waiting or app.model.get("meta", {}).get("recoveryRequired", false)
		start.tooltip_text = "Choisir un club avec " + str(pack.get("name", "ce pack"))
		C.fill(start)
		Editorial.action(start, true, false, maxi(42, C.px(66)) if featured else 42)
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
	parent.add_child(C.label("INVENTAIRE DU PACK", 21, C.GOLD, true, 700))
	var tiles := C.h(12)
	parent.add_child(tiles)
	Editorial.fact(tiles, counts.get("clubs", 0), "Clubs personnalisés")
	Editorial.divider(tiles)
	Editorial.fact(tiles, counts.get("players", 0), "Identités de joueurs")
	Editorial.divider(tiles)
	if counts.has("competitions"):
		Editorial.fact(tiles, counts.competitions, "Compétitions")
	else:
		Editorial.fact(tiles, counts.get("logos", 0), "Blasons de clubs")
	var media: Array[String] = ["%s blasons de clubs · %s photos de joueurs · %s portraits IA" % [G.n(counts.get("logos", 0)), G.n(counts.get("official", 0)), G.n(counts.get("synthetic", 0))]]
	if counts.has("competitionLogos"):
		media[0] += " · %s logos de compétitions" % G.n(counts.competitionLogos)
	if counts.has("staff"):
		media.append("Staff · %s identités · %s photos officielles · %s illustrations IA" % [G.n(counts.staff), G.n(counts.get("staffOfficial", 0)), G.n(counts.get("staffSynthetic", 0))])
	if counts.has("cityPhotos") or counts.has("stadiumPhotos"):
		media.append("Lieux · %s villes en photo · %s stades en photo" % [G.n(counts.get("cityPhotos", 0)), G.n(counts.get("stadiumPhotos", 0))])
	for line: String in media:
		parent.add_child(C.wrap(line, 19))

static func _preview(app: Control, parent: Container, pack: Dictionary) -> void:
	var content := _section(parent, "PRÊT À INSTALLER", str(pack.get("name", "Pack personnalisé")), false)
	_inventory(content, pack)
	content.add_child(C.wrap("L’installation ajoute le pack à votre profil. Vous pourrez ensuite le sélectionner."))
	if pack.get("rightsStatus", "") == "not-cleared-for-public-distribution":
		content.add_child(C.wrap("Droits de redistribution publique des photos et logos à vérifier séparément."))
	var install := C.button("INSTALLER CE PACK", app.pack_manager.install, true)
	Editorial.action(install, true)
	install.disabled = app.waiting
	install.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content.add_child(install)
