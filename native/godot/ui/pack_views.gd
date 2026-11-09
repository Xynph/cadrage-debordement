extends RefCounted
const G = preload("res://ui/carnet_skin.gd")

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
	var page := G.v(18)
	page.name="CarnetPacks"
	G.fill(page,true)
	var top := G.h(18)
	page.add_child(top)
	top.add_child(G.button("← RETOUR", app.pack_manager.back))
	var title := G.label("Votre rugby. Vos identités.", 36, G.WHITE, true)
	G.fill(title)
	top.add_child(title)
	var creation: bool = app.pack_manager.scope == "creation"
	var edition := str({"world-japan":"MONDE + JAPON", "world-pacific":"MONDE + PACIFIQUE", "world":"MONDE"}.get(app.pack_manager.mode(), "FRANCE 30"))
	top.add_child(G.label(("NOUVELLE CARRIÈRE" if creation else "CARRIÈRE EN COURS") + " · " + edition, 13, G.WHITE))
	var row := G.h(24)
	G.fill(row, true)
	page.add_child(row)
	var intro_frame := G.panel(row, 0.85)
	var intro := G.scroll(intro_frame)
	var compatible: bool = creation or app.model.get("meta", {}).get("database", {}).get("active", false)
	var database: Dictionary = app.pack_manager.database()
	intro.add_child(G.label("BASE COMMUNE · " + edition, 13, G.GOLD))
	if not database.is_empty():
		intro.add_child(G.label("%s CLUBS\n%s JOUEURS" % [G.n(database.get("clubCount", 0)), G.n(database.get("playerCount", 0))], 42, G.INK, true))
	intro.add_child(G.wrap("Les mêmes joueurs. Les mêmes capacités. Une autre façon de les reconnaître.", 22, G.INK))
	intro.add_child(G.separator())
	intro.add_child(G.wrap("Le jeu de base utilise des identités fictives. Un pack personnalise les noms, les blasons et les portraits. Les résultats, les contrats et la progression restent ceux de votre carrière.", 15))
	intro.add_child(G.wrap("Les joueurs générés au fil des saisons restent fictifs. Les photos officielles et les illustrations IA sont distinguées sur les fiches.", 12))
	intro.add_child(G.spacer())
	var base := G.button("UTILISER LA BASE ANONYMISÉE", func(): app.pack_manager.select("base"))
	base.disabled = app.waiting or not compatible
	intro.add_child(base)
	var content := G.panel(row, 1.6)
	var commands := G.h()
	content.add_child(commands)
	var heading := G.label("Vos packs", 27, G.INK, true)
	G.fill(heading)
	commands.add_child(heading)
	var importing := G.button("IMPORTER UN PACK ZIP", app.pack_manager.choose_file, true)
	importing.disabled = app.waiting
	commands.add_child(importing)
	var packs: Dictionary = app.model.get("packs", {})
	var selected: String = app.pack_manager.selected_id()
	content.add_child(G.wrap("Choix enregistré pour vos prochaines créations dans cette édition." if creation else "Cette sélection s’applique à la carrière ouverte et sera conservée dans ses sauvegardes.", 12))
	if not compatible:
		content.add_child(G.wrap("Cette ancienne carrière utilise des joueurs générés. Créez une carrière sur la base commune pour pouvoir changer ses identités. Vous pouvez déjà installer vos packs ici.", 13, G.ALERT))
	var missing: Array = packs.get("missing", []).filter(func(message: String): return message.begins_with("Stockage") or not creation and message.begins_with("Pack de carrière absent"))
	if creation and _creation_missing(app): missing.append("Pack de création absent dans cette édition")
	if not missing.is_empty():
		content.add_child(G.wrap("PACK MANQUANT · " + ", ".join(missing) + "\nLes identités concernées utilisent la base anonymisée. Réimportez le pack pour retrouver ses images et ses noms.", 13, G.ALERT))
	var list := G.scroll(content)
	var installed: Array = app.pack_manager.installed()
	var preview: Dictionary = app.pack_manager.preview()
	if not preview.is_empty() and not installed.any(func(pack: Dictionary): return pack.id == preview.id):
		_preview(app, list, preview)
	if installed.is_empty():
		var empty := G.card(list, G.GOLD)
		empty.add_child(G.label("01 / VOTRE PREMIER PACK", 26, G.INK, true))
		empty.add_child(G.wrap("Importez un pack personnalisé pour retrouver noms, blasons et portraits dans toutes les fiches.", 17))
	for pack: Dictionary in installed:
		var card := G.card(list, G.GOLD if str(pack.get("id", "")) == selected else G.LINE)
		card.add_child(G.separator())
		var pack_title := G.label(str(pack.get("name", "Pack personnalisé")), 27, G.INK, true)
		pack_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(pack_title)
		card.add_child(G.wrap(_coverage(pack), 13))
		var active: bool = str(pack.get("id", "")) == selected
		var choice := G.button("PACK ACTIF" if active else "UTILISER CE PACK  →", func(): app.pack_manager.select(str(pack.id)), not active)
		choice.disabled = active or app.waiting or not compatible
		card.add_child(choice)
	if selected == "base": content.add_child(G.label("ACTUELLEMENT · BASE ANONYMISÉE", 11, G.GOLD))
	if not app.last_error.is_empty(): content.add_child(G.wrap(app.last_error, 13, G.ALERT))
	app.status = G.label("Analyse en cours…" if app.waiting else "Installation locale · aucun téléchargement automatique", 12, G.WHITE)
	page.add_child(app.status)
	return page

static func _coverage(pack: Dictionary) -> String:
	var counts: Dictionary = pack.get("counts", {})
	var coverage := "%s joueurs · %s blasons · %s photos officielles · %s illustrations IA" % [G.n(counts.get("players", 0)), G.n(counts.get("logos", 0)), G.n(counts.get("official", 0)), G.n(counts.get("synthetic", 0))]
	if counts.has("staff"): coverage += " · %s membres du staff, %s photos" % [G.n(counts.staff), G.n(counts.get("staffOfficial", 0))]
	return coverage

static func _preview(app: Control, parent: VBoxContainer, pack: Dictionary) -> void:
	parent.add_child(G.label("PRÊT À INSTALLER", 12, G.GOLD))
	var title := G.label(pack.get("name", "Pack personnalisé"), 30, G.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(title)
	parent.add_child(G.wrap(_coverage(pack), 14))
	parent.add_child(G.wrap("L’installation ajoute le pack à votre profil. Vous pourrez ensuite le sélectionner ; votre carrière ne sera pas remplacée.", 12))
	if pack.get("rightsStatus", "") == "not-cleared-for-public-distribution":
		parent.add_child(G.wrap("Pack fourni pour votre installation locale. Son inventaire ne valide pas une redistribution publique des photos et logos.", 11))
	var install := G.button("INSTALLER CE PACK", app.pack_manager.install, true)
	install.disabled = app.waiting
	parent.add_child(install)
	parent.add_child(G.separator())
