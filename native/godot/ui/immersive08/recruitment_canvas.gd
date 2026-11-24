extends "res://ui/immersive08/recruitment_tableau.gd"
## Écran Recrutement (choix de Léo du 19/11/2026 : maquette « 1 · Besoins en tête, piste à droite » retouchée, SANS fiche
## fixe à droite, avec le bloc « Ce que coûte l'offre » de la maquette 3). De haut en bas : titre et budget de transferts,
## trois besoins du club, onglets et sources, filtres, tableau pleine largeur, coût de l'offre de la piste choisie.
## Un clic sur un nom ouvre la fiche complète de la piste ; le survol (ou le « i ») en montre la mini-fiche.
## Les actions longues (relève, marché entre clubs, offres reçues, missions, négociation, rapport) sont des sous-pages
## (recruitment_pages.gd), jamais de petites fenêtres. Coordonnées en unités du gabarit (2248 de large), jetons de la charte.
## Découpé sans changement : constantes et aides dans recruitment_socle.gd, puis en-tête, filtres, coût, lignes et tableau (chaîne d’héritage, voir le socle).
const Socle = preload("res://ui/immersive08/recruitment_socle.gd")
const Entete = preload("res://ui/immersive08/recruitment_entete.gd")

## Points d’entrée publics (fiches, tests) : redéfinis ici, car `has_method` d’un script ne voit pas les statiques hérités.
static func fenetre_courte(resume: String) -> String: return Entete.fenetre_courte(resume)
static func _portrait(parent: Node, area: Rect2, player: Dictionary, player_id: String, full: bool = false) -> void: Socle._portrait(parent, area, player, player_id, full)

static func _target_report(owner_app: Control, id: Variant) -> Dictionary:
	if str(id).is_empty(): return {}
	var found: Dictionary = {}
	for report: Dictionary in owner_app.model.get("decisions", {}).get("recruitment", {}).get("reports", []):
		if str(report.get("id", "")) != str(id): continue
		if not found.is_empty(): return {}
		found = report
	return found

static func target_available(owner_app: Control, id: Variant) -> bool:
	return not _target_report(owner_app, id).is_empty()

## Rapport d'observation daté : une sous-page du Recrutement (la fenêtre d'origine est adoptée, voir recruitment_pages.gd).
static func open_target(owner_app: Control, id: Variant) -> bool:
	if _target_report(owner_app, id).is_empty(): return false
	Pages.ouvrir(owner_app, "rapport", {"report_id": str(id)})
	return true

## Construit la fenêtre du rapport (appelée par la sous-page « rapport » pour l'adopter).
static func open_report(owner_app: Control, id: String) -> bool:
	var report := _target_report(owner_app, id)
	if report.is_empty(): return false
	var view := Decisions.dialog(owner_app, "Rapport d’observation", "RecruitmentReport", 920)
	view[0].set_meta("navigation_read_only", true)
	view[0].set_meta("entity_kind", "report")
	view[0].set_meta("entity_id", str(report.id))
	# Ce rapport archivé reste lisible même si le joueur a quitté le marché : lien vers son dossier actuel seulement s'il existe.
	var player_id := str(report.get("playerId", ""))
	var current: Array = owner_app.model.get("market", []).filter(func(player: Dictionary): return str(player.get("id", "")) == player_id)
	if not player_id.is_empty() and current.size() == 1:
		var link := Link.button(owner_app, "Dossier actuel · " + str(current[0].get("name", "")), {"kind":"market", "id":player_id}, "ReportCurrentPlayer", view[0])
		link.clip_text = true
		view[1].add_child(link)
	Decisions.scout_report(view[1], report)
	return true

## Quitter le Recrutement (menu, historique) : la sous-page et sa fenêtre d'origine sont oubliées.
static func oublier_page(owner_app: Control) -> void:
	if owner_app.get_node_or_null(Pages.HOTE) != null: Pages._vider_hote(owner_app)
	owner_app.management_ui.erase("recrutement_page")

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/recruitment_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, HAUTEUR))
	canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, HAUTEUR * C.density)
	page._build()

func _build() -> void:
	name = "CarnetMarket"
	state = app.management_ui.market
	data = app.model.get("decisions", {}).get("recruitment", {})
	var sous := Pages.actuelle(app)
	if not sous.is_empty():
		Pages.build(app, self, sous)
		return
	tab = clampi(int(state.get("immersive_tab", 2 if state.get("followed", false) else 0)), 0, TABS.size() - 1)
	if not str(state.get("navigation_id", "")).is_empty():
		tab = 1
		state.immersive_tab = 1
		state.followed = false
	for report: Dictionary in data.get("reports", []):
		var key := str(report.get("playerId", ""))
		if key.is_empty(): continue
		var previous: Dictionary = report_by_player.get(key, {})
		if int(report.get("week", -1)) >= int(previous.get("week", -1)):
			report_by_player[key] = report
	var positions: Array = app.SquadViews._positions(app.model.get("market", []))
	# Onglet « Besoins du club » : arrive filtré sur le poste du besoin n° 1 (maquette) ; « Poste : Tous » reste un choix libre.
	if tab == 0 and str(state.get("position", "Tous")) == "Tous" and not bool(state.get("position_libre", false)):
		var besoins: Array = data.get("needs", [])
		if not besoins.is_empty() and not str(besoins[0].get("pos", "")).is_empty(): state.position = str(besoins[0].pos)
	# Le menu « Poste » dit toujours le filtre actif, même pour un poste sans aucune piste sur le marché.
	if str(state.get("position", "Tous")) not in positions: positions.append(str(state.position))
	_header()
	_needs()
	_tabs()
	_filters(positions)
	_pastilles_postes()
	_table()
	tiles = Control.new()
	tiles.name = "RecruitmentBudgetTiles"
	add_child(tiles)
	D.place(tiles, Rect2(0, 0, WIDTH, 120))
	cost = Control.new()
	cost.name = "RecruitmentCost"
	add_child(cost)
	D.place(cost, Rect2(0, COST_TOP, WIDTH, 200))
	_refresh()
	_pied()
	# Une case de forme porte le même nom sur chaque ligne : on ne lui rend pas le focus (il sauterait en tête de liste).
	if str(state.get("focus", "")).begins_with("FormeMatch"): state.focus = ""
	U.restore(app, self, "market")
	# Recherche ciblée restée ouverte (envoi du recruteur, retour depuis une fiche) : elle revient par-dessus.
	load("res://ui/immersive08/recherche_ciblee.gd").rouvrir(app, self)
	# Courrier « offre_transfert » (Réception) : ouvre directement les offres reçues.
	if app.has_meta("open_player_sales"):
		app.remove_meta("open_player_sales")
		(func(): Pages.ouvrir(app, "offres")).call_deferred()
