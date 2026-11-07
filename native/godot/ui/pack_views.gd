extends RefCounted
const G = preload("res://ui/game_skin.gd")

static func page(app: Control) -> Control:
	var page := G.v(18)
	var top := G.h(18)
	page.add_child(top)
	top.add_child(G.button("← RETOUR", app.pack_manager.back))
	var title := G.label("VOTRE RUGBY. VOS IDENTITÉS.", 40, G.INK, true)
	G.fill(title)
	top.add_child(title)
	top.add_child(G.label("NOUVELLE CARRIÈRE" if app.pack_manager.scope == "creation" else "CARRIÈRE EN COURS", 12, G.GOLD))
	var row := G.h(24)
	G.fill(row, true)
	page.add_child(row)
	var intro := G.panel(row, 0.8)
	intro.add_child(G.label("UNE BASE COMMUNE", 13, G.GOLD))
	intro.add_child(G.label("30 CLUBS\n1 592 JOUEURS", 46, G.INK, true))
	intro.add_child(G.wrap("Les mêmes joueurs. Les mêmes capacités. Une autre façon de les reconnaître.", 22, G.INK))
	intro.add_child(G.separator())
	intro.add_child(G.wrap("Le jeu de base utilise des identités fictives. Un pack personnalise les noms, les blasons et les portraits. Les résultats, les contrats et la progression restent ceux de votre carrière.", 15))
	intro.add_child(G.wrap("Les joueurs générés au fil des saisons restent fictifs. Les photos officielles et les illustrations IA sont distinguées sur les fiches.", 12))
	intro.add_child(G.spacer())
	var base := G.button("UTILISER LA BASE ANONYMISÉE", func(): app.pack_manager.select("base"))
	base.disabled = app.waiting
	intro.add_child(base)
	var content := G.panel(row, 1.6)
	var commands := G.h()
	content.add_child(commands)
	var heading := G.label("VOS PACKS", 25, G.INK, true)
	G.fill(heading)
	commands.add_child(heading)
	var importing := G.button("IMPORTER UN PACK ZIP", app.pack_manager.choose_file, true)
	importing.disabled = app.waiting
	commands.add_child(importing)
	var packs: Dictionary = app.model.get("packs", {})
	var selected := str(packs.get(app.pack_manager.scope, "base"))
	content.add_child(G.wrap("Sélection pour la création uniquement : la carrière ouverte n’est pas modifiée." if app.pack_manager.scope == "creation" else "Cette sélection s’applique à la carrière ouverte et sera conservée dans ses sauvegardes.", 12))
	var missing: Array = packs.get("missing", [])
	if not missing.is_empty():
		content.add_child(G.wrap("PACK MANQUANT · " + ", ".join(missing) + "\nLa base anonymisée est affichée. Réimportez votre pack pour retrouver ses images et ses noms.", 13, Color("f1b6a9")))
	var list := G.scroll(content)
	var preview: Dictionary = packs.get("preview", {}) if packs.get("preview") is Dictionary else {}
	if not preview.is_empty():
		_preview(app, list, preview)
	var installed: Array = packs.get("installed", [])
	if installed.is_empty():
		list.add_child(G.label("VOTRE PREMIER PACK", 22, G.INK, true))
		list.add_child(G.wrap("Importez Rugby_Reel.zip ou un pack personnalisé. Le jeu analysera le contenu avant de vous proposer son installation.", 16))
	for pack: Dictionary in installed:
		var card := G.v(8)
		list.add_child(card)
		card.add_child(G.separator())
		card.add_child(G.label(str(pack.get("name", "Pack personnalisé")), 27, G.INK, true))
		card.add_child(G.wrap(_coverage(pack), 13))
		var active: bool = str(pack.get("id", "")) == selected
		var choice := G.button("PACK ACTIF" if active else "UTILISER CE PACK  →", func(): app.pack_manager.select(str(pack.id)), not active)
		choice.disabled = active or app.waiting
		card.add_child(choice)
	if selected == "base": content.add_child(G.label("ACTUELLEMENT · BASE ANONYMISÉE", 11, G.GOLD))
	if not app.last_error.is_empty(): content.add_child(G.wrap(app.last_error, 13, Color("f1b6a9")))
	app.status = G.label("Analyse en cours…" if app.waiting else "Installation locale · aucun téléchargement automatique", 11, G.MUTED)
	page.add_child(app.status)
	return page

static func _coverage(pack: Dictionary) -> String:
	var counts: Dictionary = pack.get("counts", {})
	return "%s identités · %s blasons · %s photos officielles · %s illustrations IA" % [G.n(counts.get("players", 0)), G.n(counts.get("logos", 0)), G.n(counts.get("official", 0)), G.n(counts.get("synthetic", 0))]

static func _preview(app: Control, parent: VBoxContainer, pack: Dictionary) -> void:
	parent.add_child(G.label("PRÊT À INSTALLER", 12, G.GOLD))
	parent.add_child(G.label(pack.get("name", "Pack personnalisé"), 30, G.INK, true))
	parent.add_child(G.wrap(_coverage(pack), 14))
	parent.add_child(G.wrap("L’installation ajoute le pack à votre profil. Vous pourrez ensuite le sélectionner ; votre carrière ne sera pas remplacée.", 12))
	if pack.get("rightsStatus", "") == "not-cleared-for-public-distribution":
		parent.add_child(G.wrap("Pack fourni pour votre installation locale. Son inventaire ne valide pas une redistribution publique des photos et logos.", 11))
	var install := G.button("INSTALLER CE PACK", app.pack_manager.install, true)
	install.disabled = app.waiting
	parent.add_child(install)
	parent.add_child(G.separator())
