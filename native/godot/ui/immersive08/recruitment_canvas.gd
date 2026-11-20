extends Control
## Écran Recrutement (choix de Léo du 19/11/2026 : maquette « 1 · Besoins en tête, piste à droite » retouchée, SANS fiche
## fixe à droite, avec le bloc « Ce que coûte l'offre » de la maquette 3). De haut en bas : titre et budget de transferts,
## trois besoins du club, onglets et sources, filtres, tableau pleine largeur, coût de l'offre de la piste choisie.
## Un clic sur un nom ouvre la fiche complète de la piste ; le survol (ou le « i ») en montre la mini-fiche.
## Les actions longues (relève, marché entre clubs, offres reçues, missions, négociation, rapport) sont des sous-pages
## (recruitment_pages.gd), jamais de petites fenêtres. Coordonnées en unités du gabarit (2248 de large), jetons de la charte.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Link = preload("res://ui/entity_link.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const SalesView = preload("res://ui/player_sales_view.gd")
const Observation = preload("res://ui/player_observation.gd")
const Identity = preload("res://ui/player_identity.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const Attributs = preload("res://ui/player_attributes.gd")
const ROW_HEIGHT := 32
# Construction progressive de la liste : les premières lignes tout de suite, le reste sur les images suivantes.
const FIRST_ROWS := 26
const ROWS_PER_FRAME := 18
const VISIBLE_MARGIN := 6
const WIDTH := 2248
const HAUTEUR := 1250
const TABLE_TOP := 332.0
const HEADER_H := 32.0
const ROWS_H := 640.0
const COST_TOP := 1020.0
const TABS := ["Besoins du club", "Recherche", "Joueurs suivis", "Rapports"]
const WEEKS_PER_YEAR := 52

var app: Control
var state: Dictionary
var data: Dictionary
var tab := 0
var report_by_player := {}
var _generation := 0
var table_rows: Control
var count: Label
var table_scroll: ScrollContainer
var direction: Button
var position_filter: OptionButton
var sort_headers: Dictionary = {}
var tiles: Control
var cost: Control
var columns: Array = []
var _selected: Dictionary = {}
var _signature_entetes := ""
var _liens_filtre: Array = []
var _ids_affiches: Array = []

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
		Kit.angles_droits(self)
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
	U.restore(app, self, "market")
	Kit.angles_droits(self)
	# Courrier « offre_transfert » (Réception) : ouvre directement les offres reçues.
	if app.has_meta("open_player_sales"):
		app.remove_meta("open_player_sales")
		(func(): Pages.ouvrir(app, "offres")).call_deferred()

# --- En-tête, budget, besoins -----------------------------------------------------------------------------------

func _header() -> void:
	var titre := Kit.titre(self, 0, 44, "Recrutement", 38, 700)
	titre.name = "RecruitmentTitle"
	var curseur := 0.0
	Kit.texte(self, 0, 78, "Le prochain renfort", Charte.IVOIRE_2, 0, 18)
	curseur = Kit.largeur("Le prochain renfort", 18)
	# Calendrier du recrutement (calendrier-mutations.cjs, model.mutations) : période des joueurs sans club, raison et date de
	# réouverture en clair ; la période des mutations reste dans l'infobulle.
	var calendrier: Dictionary = app.model.get("mutations", {}) if app.model.get("mutations") is Dictionary else {}
	if calendrier.get("available", false):
		var libres: Dictionary = calendrier.get("freeAgents", {}) if calendrier.get("freeAgents") is Dictionary else {}
		var resume := str(calendrier.get("summary", ""))
		Kit.texte(self, curseur + 6, 78, "·", Charte.IVOIRE_3, 20, 18)
		var fenetre := Kit.texte(self, curseur + 26, 78, resume, Charte.IVOIRE if libres.get("open", true) else Charte.D, 0, 18)
		fenetre.name = "RecruitmentWindow"
		fenetre.tooltip_text = str(calendrier.get("detail", ""))
		fenetre.mouse_filter = Control.MOUSE_FILTER_PASS
		curseur += 26 + Kit.largeur(resume, 18)


## Tuiles du budget de transferts (finance.transferBudget) : alloué, engagé, restant (« après l'offre » si une piste est
## choisie). Absent ou inactif : la trésorerie du club reste la seule référence. Clic = Finances.
func _tuiles() -> void:
	for enfant in tiles.get_children():
		tiles.remove_child(enfant)
		enfant.queue_free()
	var budget := Budget.data(app.model)
	var cash: Variant = app.model.get("finance", {}).get("cash")
	var fee: Variant = _selected.get("fee") if not _selected.is_empty() and tab != 3 else null
	if budget.is_empty():
		_tuile(1700, 380, "Trésorerie du club", G.euros(cash) if cash is int or cash is float else "—", "", "RecruitmentTransferBudget", true, "Trésorerie du club")
	else:
		var total := Budget.season_total(budget)
		var depense := int(budget.get("depense", 0))
		var part := roundi(100.0 * depense / total) if total > 0 else 0
		var alloue := _tuile(1130, 292, "Budget alloué", G.euros(total), "par le conseil", "RecruitmentBudgetAllocated", false, "")
		alloue.tooltip_text = Budget.allocated(budget)
		_tuile(1430, 262, "Engagé", G.euros(depense), "%d %% du budget" % part, "RecruitmentBudgetSpent", false, "")
		var apres := Budget.LABEL
		if fee is int or fee is float: apres = "%s après l’offre" % G.euros(int(budget.get("disponible", 0)) - int(fee))
		var restant := _tuile(1700, 380, "Restant", Budget.remaining(budget), apres, "RecruitmentTransferBudget", true, Budget.LABEL)
		restant.tooltip_text = Budget.detail(budget, cash)
	var finances := Kit.lien(tiles, Rect2(2248, 100, 0, 36), "Finances →", func(): app.navigation_controller.open_entity({"kind":"finance", "id":"summary"}), "RecruitmentFinances", 19, true)
	finances.tooltip_text = ""

func _tuile(x: float, largeur: float, etiquette: String, montant: String, suite: String, id: String, marque: bool, libelle: String) -> Button:
	var tuile := Button.new()
	tuile.name = id
	tuile.flat = true
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fond := C.box(Charte.PANNEAU, Color.TRANSPARENT, 0, 0)
	tuile.add_theme_stylebox_override("normal", fond)
	tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	tuile.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	tiles.add_child(tuile)
	D.place(tuile, Rect2(x, 6, largeur, 116))
	if marque: Kit.marqueur(tuile, Rect2(0, 0, 8, 116))
	var gauche := 34 if marque else 16
	var courant := D.text(tuile, gauche, 36, etiquette.to_upper(), 16, Charte.IVOIRE_2, 700, largeur - 30)
	if id == "RecruitmentTransferBudget": courant.name = "RecruitmentTransferBudgetLabel"
	var valeur := D.text(tuile, gauche, 82, montant, 46, Charte.IVOIRE, 800, largeur - 30)
	valeur.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	if id == "RecruitmentTransferBudget": valeur.name = "RecruitmentTransferBudgetAmount"
	elif id == "RecruitmentBudgetAllocated": valeur.name = "RecruitmentTransferBudgetAllocated"
	if not suite.is_empty(): D.text(tuile, gauche, 108, suite, 16, Charte.IVOIRE_2, 600, largeur - 30)
	for enfant in tuile.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Link.bind(tuile, app, {"kind":"finance", "id":"summary"}, libelle if not libelle.is_empty() else etiquette)
	tuile.tooltip_text = ""
	return tuile

## « 10 fin(s) de contrat » du moteur : accord au nombre (jamais « fin(s) » à l'écran).
static func _pluriel(texte: String) -> String:
	if not texte.contains("(s)"): return texte
	var chiffres := ""
	for lettre in texte:
		if lettre >= "0" and lettre <= "9": chiffres += lettre
		elif not chiffres.is_empty(): break
	return texte.replace("(s)", "s" if not chiffres.is_empty() and int(chiffres) > 1 else "")
## Raison d'un besoin : « n fin(s) de contrat » est un total du club dans les données ; ici, le nombre AU POSTE (lu dans
## l'effectif), ou rien s'il n'y en a pas. Les autres raisons (relève insuffisante…) sont gardées telles quelles.
func _raison_au_poste(raison: String, role: String) -> String:
	if not raison.contains("contrat"): return _pluriel(raison)
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var fins := 0
	for joueur: Dictionary in app.model.get("squad", []):
		var fin: Variant = joueur.get("contractEnd")
		if str(joueur.get("pos", "")) == role and (fin is int or fin is float) and int(fin) <= saison: fins += 1
	return P.plural(fins, "fin de contrat", "fins de contrat") + " à ce poste cette saison" if fins > 0 else ""

func _needs() -> void:
	var needs: Array = []
	var seen: Array = []
	for need: Dictionary in data.get("needs", []):
		var position: Variant = need.get("pos")
		if position in seen: continue
		seen.append(position)
		needs.append(need)
		if needs.size() == 3: break
	if needs.is_empty():
		Kit.texte(self, 0, 168, "Les besoins de l’effectif ne sont pas renseignés.", Charte.IVOIRE_2, 1400, 19).name = "RecruitmentNoNeeds"
		return
	var largeur := (WIDTH - 2 * 14.0) / 3.0
	for i in mini(3, needs.size()):
		var need: Dictionary = needs[i]
		var role := str(need.get("pos", "Poste inconnu"))
		var choisi := str(state.get("position", "Tous")) == role
		var x := i * (largeur + 14)
		var stock: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == role).size()
		var suivies: int = app.model.get("market", []).filter(func(p: Dictionary): return p.get("pos") == role and str(p.id) in app.management_ui.shortlist).size()
		var carte: Control
		if stock > 0:
			var bouton_carte := Button.new()
			bouton_carte.flat = true
			bouton_carte.focus_mode = Control.FOCUS_ALL
			bouton_carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			bouton_carte.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3 if choisi else Charte.PANNEAU, Color.TRANSPARENT, 0, 0))
			bouton_carte.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
			bouton_carte.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
			var focus_carte := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
			focus_carte.set_border_width_all(2)
			bouton_carte.add_theme_stylebox_override("focus", focus_carte)
			bouton_carte.accessibility_name = "Filtrer sur %s" % role
			bouton_carte.pressed.connect(func(): Decisions.open_market_position(app, role))
			add_child(bouton_carte)
			D.place(bouton_carte, Rect2(x, 136, largeur, 90))
			carte = bouton_carte
		else:
			# Aucune piste pour ce poste : la carte n'est pas un lien vers une liste vide, elle propose une mission.
			carte = D.rect(self, Rect2(x, 136, largeur, 90), Charte.PANNEAU, 0)
			carte.mouse_filter = Control.MOUSE_FILTER_PASS
		carte.name = "MarketNeed_" + str(i)
		Kit.marqueur(carte, Rect2(18, 16, 8, 58), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		var mot := ("PRIORITÉ %d" if need.get("need", false) else "À SURVEILLER %d") % (i + 1)
		if i == 0 and need.get("need", false): mot += " · URGENT"
		D.text(carte, 44, 30, mot, 16, Charte.IVOIRE_2, 700, 330)
		var nom := D.text(carte, 44, 70, role, 34, Charte.IVOIRE, 800, 340)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var raisons: Array = need.get("reasons", [])
		var raison := _raison_au_poste(str(raisons[0]), role) if not raisons.is_empty() else "Couverture du poste à examiner"
		if not raison.is_empty(): Kit.texte(carte, largeur - 20, 34, raison, Charte.IVOIRE, 420, 17, HORIZONTAL_ALIGNMENT_RIGHT)
		if stock > 0:
			var piste := "%s · %s" % [P.plural(stock, "piste", "pistes"), P.plural(suivies, "suivie", "suivies")]
			Kit.texte(carte, largeur - 20, 70, piste, Charte.IVOIRE_2, 420, 17, HORIZONTAL_ALIGNMENT_RIGHT).name = "MarketPriorityStock" if i == 0 else "MarketNeedStock_" + str(i)
		for enfant in carte.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if stock == 0:
			var libelle_mission := "Lancer une mission pour ce poste →"
			var largeur_mission := Kit.largeur(libelle_mission, 18) + 14
			var lien_mission := Kit.lien(self, Rect2(x + largeur - 20 - largeur_mission, 136 + 50, largeur_mission, 34), libelle_mission, func(): _staff(1, role), "MarketNeedMission_" + str(i), 18)
			lien_mission.tooltip_text = ""


func _tabs() -> void:
	var x := 0.0
	for i in TABS.size():
		var id := "MarketFollowed" if i == 2 else "MarketTab" + str(i)
		var libelle: String = TABS[i]
		if i == 2: libelle += " %d" % app.management_ui.shortlist.size()
		if i == 3: libelle += " %d" % data.get("reports", []).size()
		var choisi := tab == i
		var largeur := Kit.largeur(libelle, 19) + 44
		var bouton := Button.new()
		bouton.name = id
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS if choisi else Charte.TITRE)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			bouton.add_theme_color_override(etat, Charte.IVOIRE if choisi else Charte.IVOIRE_2)
		bouton.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3 if choisi else Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		bouton.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
		bouton.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.toggle_mode = true
		bouton.button_pressed = choisi
		bouton.pressed.connect(func():
			state.immersive_tab = i
			state.navigation_id = ""
			state.followed = i == 2
			state.page = 0
			state.focus = "MarketSearch" if i == 1 else id
			app._render(false))
		add_child(bouton)
		D.place(bouton, Rect2(x, 244, largeur, 44))
		x += largeur + 8
	# Sources : le marché des joueurs (cette liste), les autres clubs et la relève sont des écrans à part.
	var droite := float(WIDTH) - 8.0
	var sources :=[["Relève", "releve", "OpenRegenScouting", "Repérer la relève : agents libres majeurs, centres de formation et petits clubs"], ["Entre clubs", "interclub", "OpenInterclubMarket", ""], ["Marché joueurs %d" % app.model.get("market", []).size(), "", "MarketSourcePlayers", ""]]
	var calendrier: Dictionary = app.model.get("mutations", {}) if app.model.get("mutations") is Dictionary else {}
	for source: Array in sources:
		var actif: bool = str(source[1]).is_empty()
		var largeur := Kit.largeur(str(source[0]), 18) + 40
		droite -= largeur
		var bouton := Button.new()
		bouton.name = str(source[2])
		bouton.text = str(source[0])
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(bouton, 20, actif)
		bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if actif:
			bouton.pressed.connect(func():
				state.immersive_tab = 1
				state.followed = false
				state.navigation_id = ""
				state.focus = "MarketSearch"
				app._render(false))
		else:
			var page: String = source[1]
			bouton.pressed.connect(func(): Pages.ouvrir(app, page))
		if str(source[2]) == "OpenInterclubMarket": bouton.tooltip_text = str(calendrier.get("interclub", {}).get("note", ""))
		elif not str(source[3]).is_empty(): bouton.tooltip_text = str(source[3])
		add_child(bouton)
		D.place(bouton, Rect2(droite, 248, largeur, 38))
		droite -= 8
	var etiquette := Kit.etiquette(self, droite - 8, 274, "Source", 90, true)
	etiquette.name = "RecruitmentSourceLabel"
	# Liens d'action de la ligne des onglets, de droite à gauche ; ce qui ne tient pas passe sur la ligne des filtres.
	var limite := droite - 8 - Kit.largeur("SOURCE", 16) - 40
	var libre := x + 24
	var offres := (SalesView.sales(app.model).get("offers", []) as Array).size()
	var expirant: int = (data.get("expiring", []) as Array).size()
	var liens: Array = [["OpenScoutMission", "Lancer une mission →", func(): _staff(1), false]]
	liens.append(["OpenPlayerSales", SalesView.caption(app.model) + " →", func(): Pages.ouvrir(app, "offres"), offres > 0])
	if expirant > 0: liens.append(["OpenExpiringContracts", P.plural(expirant, "fin de contrat", "fins de contrat") + " →", func(): _fins_de_contrat(), false])
	for lien: Array in liens:
		var largeur_lien := Kit.largeur(str(lien[1]), 18) + 12
		if limite - largeur_lien < libre:
			_liens_filtre.append(lien)
			continue
		var bouton := Kit.lien(self, Rect2(limite - largeur_lien, 250, largeur_lien, 36), str(lien[1]), lien[2], str(lien[0]), 18)
		bouton.tooltip_text = ""
		if lien[3]: bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		if lien[0] == "OpenPlayerSales": bouton.accessibility_name = bouton.text
		if lien[0] == "OpenExpiringContracts": bouton.accessibility_name = "Voir les fins de contrat de la saison dans l'effectif"
		limite -= largeur_lien + 18

func _filters(positions: Array) -> void:
	var recherche := LineEdit.new()
	recherche.name = "MarketSearch"
	recherche.placeholder_text = "Rechercher une piste…"
	recherche.text = str(state.get("search", ""))
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Rechercher une piste par nom ou poste"
	recherche.add_theme_font_override("font", Charte.TEXTE)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	recherche.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, 0, 10))
	var focus := C.box(Charte.PANNEAU_3, Charte.IVOIRE, 0, 10)
	focus.set_border_width_all(2)
	recherche.add_theme_stylebox_override("focus", focus)
	add_child(recherche)
	D.place(recherche, Rect2(0, 292, 330, 38))
	recherche.text_changed.connect(func(value: String):
		state.search = value
		state.navigation_id = ""
		_filter_changed())
	var k := 1.3 if C.density < .75 else 1.0
	var x := 346.0
	position_filter = _choice(Rect2(x, 292, 270, 38), "MarketPosition", "Poste", positions, state.position, func(value: String): state.position = value; state.position_libre = true; _filter_changed())
	x += 282
	_choice(Rect2(x, 292, 190, 38), "MarketAge", "Âge", ["Tous", "≤ 22 ans", "23–28 ans", "≥ 29 ans"], state.get("age_filter", "Tous"), func(value: String): state.age_filter = value; _filter_changed())
	x += 202
	_choice(Rect2(x, 292, 210, 38), "MarketAvailability", "Offres", ["Tous", "Disponibles", "Indisponibles"], state.available, func(value: String): state.available = value; _filter_changed())
	x += 222
	_choice(Rect2(x, 292, 250 * k, 38), "MarketBudget", "Indemnité", ["Toutes", "≤ 100 k€", "≤ 400 k€", "≤ 1 M€"], state.get("budget_filter", "Toutes"), func(value: String): state.budget_filter = value; _filter_changed())
	x += 262 * k
	_choice(Rect2(x, 292, 290, 38), "MarketObservation", "Observation", ["Toutes", "Observées", "Non observées"], state.get("observation", "Toutes"), func(value: String): state.observation = value; _filter_changed())
	x += 302
	var reset := Kit.lien(self, Rect2(x, 296, 0, 32), "Réinitialiser", func():
		app.management_ui.market = U.defaults()
		app.management_ui.market.immersive_tab = tab
		app.management_ui.market.followed = tab == 2
		app.management_ui.market.focus = "MarketReset"
		app._render(false), "MarketReset", 18)
	reset.tooltip_text = ""
	# Liens d'action, de droite à gauche : « Comparer », puis ceux de la ligne des onglets qui n'y tenaient pas.
	var droite := float(WIDTH)
	var comparer := Kit.lien(self, Rect2(droite, 296, 0, 32), "Comparer →", func(): _compare(), "CompareMarket", 18, true)
	comparer.accessibility_name = "Comparer deux pistes de recrutement"
	droite -= comparer.size.x / C.density + 18
	for lien: Array in _liens_filtre:
		var bouton := Kit.lien(self, Rect2(droite, 296, 0, 32), str(lien[1]), lien[2], str(lien[0]), 18, true)
		bouton.tooltip_text = ""
		if lien[3]: bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		droite -= bouton.size.x / C.density + 18	# Barre des rapports (onglet Rapports) : les filtres de la liste n'y servent pas.
	for nom in ["MarketPosition", "MarketAge", "MarketAvailability", "MarketBudget", "MarketObservation", "MarketSearch"]:
		var champ := get_node_or_null(nom) as Control
		if champ != null: champ.visible = tab != 3
	reset.visible = tab != 3
	var missions := Kit.lien(self, Rect2(0, 296, 0, 32), "Missions et échéances →", func(): _staff(1), "OpenRecruitmentMissions", 18)
	missions.visible = tab == 3

func _choice(zone: Rect2, id: String, caption: String, values: Array, current: Variant, change: Callable) -> OptionButton:
	var champ := OptionButton.new()
	champ.name = id
	champ.fit_to_longest_item = false
	champ.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	champ.accessibility_name = caption
	for valeur in values: champ.add_item(caption + " : " + str(valeur))
	champ.select(maxi(0, values.find(current)))
	champ.item_selected.connect(func(index: int): change.call(str(values[index])))
	add_child(champ)
	D.place(champ, zone)
	Kit.styler_liste(champ)
	return champ

# --- Tableau ----------------------------------------------------------------------------------------------------

## Colonnes selon l'onglet et les données connues : une colonne sans aucune valeur (club, attributs, fin de contrat) est omise.
func _columns_for(players: Array) -> Array:
	if tab == 3:
		return [{"id":"nom", "titre":"JOUEUR OBSERVÉ", "tri":"Nom", "x":128, "w":520, "align":0},
			{"id":"poste", "titre":"POSTE", "tri":"Poste", "x":680, "w":330, "align":0},
			{"id":"date", "titre":"RAPPORT", "tri":"Date du rapport", "x":1040, "w":520, "align":0},
			{"id":"obs", "titre":"OBSERVATION", "tri":"Avis", "x":1600, "w":420, "align":0}]
	var avec_club := players.any(func(p: Dictionary): return not _club(p).is_empty())
	var avec_attributs := C.density >= .75 and players.any(func(p: Dictionary): return not Attributs.detail(p, false).is_empty())
	var avec_fin := C.density >= .75 and players.any(func(p: Dictionary): return p.get("contractEnd") is int or p.get("contractEnd") is float)
	var definitions: Array = [["nom", "JOUEUR", "Nom", 330, 0], ["poste", "POSTE", "Poste", 190, 0]]
	if avec_club: definitions.append(["club", "CLUB", "", 280, 0])
	definitions.append_array([["age", "ÂGE", "Âge", 60, 2], ["niveau", "NIV.", "Niveau", 80, 2], ["potentiel", "POT.", "Potentiel", 120, 2]])
	if avec_attributs:
		for attribut: Array in [["touche", "TOUCHE"], ["melee", "MÊLÉE"], ["gratt", "GRATT."], ["plaq", "PLAQ."]]: definitions.append([attribut[0], attribut[1], "", 84, 2])
	if avec_fin: definitions.append(["fin", "FIN CTR", "", 100, 2])
	definitions.append_array([["indemnite", "INDEMNITÉ", "Prime", 160, 2], ["salaire", "SALAIRE / SEM.", "Salaire", 170, 2]])
	var colonnes: Array = [{"id":"suivi", "titre":"★", "tri":"Suivi", "x":8.0, "w":44.0, "align":0}]
	var x := 128.0
	for definition: Array in definitions:
		colonnes.append({"id":definition[0], "titre":definition[1], "tri":definition[2], "x":x, "w":float(definition[3]), "align":definition[4]})
		x += float(definition[3]) + 22
	var action := 150.0
	colonnes.append({"id":"obs", "titre":"OBSERVATION", "tri":"Avis", "x":x, "w":WIDTH - x - action - 22, "align":0})
	colonnes.append({"id":"action", "titre":"ACTION", "tri":"", "x":WIDTH - action, "w":action, "align":1})
	return colonnes
func _club(player: Dictionary) -> String:
	for key in ["clubName", "club"]:
		var valeur: Variant = player.get(key)
		if valeur is String and not valeur.strip_edges().is_empty(): return valeur
		if valeur is Dictionary and str(valeur.get("name", "")) != "": return str(valeur.name)
	return ""

func _table() -> void:
	var panel := D.rect(self, Rect2(0, TABLE_TOP, WIDTH, HEADER_H + ROWS_H + 4), Charte.PANNEAU, 0)
	panel.name = "ImmersiveMarketTable"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var entete := D.rect(panel, Rect2(0, 0, WIDTH, HEADER_H), Charte.PANNEAU_2, 0)
	entete.name = "MarketHeader"
	entete.set_meta("rows_origin", Vector2(0, TABLE_TOP))
	table_scroll = ScrollContainer.new()
	table_scroll.name = "MarketScroll"
	table_scroll.follow_focus = true
	table_scroll.mouse_force_pass_scroll_events = false
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(table_scroll)
	D.place(table_scroll, Rect2(0, HEADER_H, WIDTH, ROWS_H))
	table_scroll.get_v_scroll_bar().value_changed.connect(func(value: float): state.scroll = int(value))
	table_rows = Control.new()
	table_rows.name = "ImmersiveMarketRows"
	table_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(table_rows)

## En-têtes : boutons de tri aux colonnes de l'onglet courant (recréés à chaque rafraîchissement).
func _entetes() -> void:
	var entete := get_node("ImmersiveMarketTable/MarketHeader") as Control
	# Mêmes colonnes qu'au rafraîchissement précédent : les boutons de tri restent les mêmes (le focus clavier y reste).
	var signature := str(tab) + ":" + ",".join(columns.map(func(col: Dictionary): return str(col.id) + str(int(col.x))))
	if signature == _signature_entetes and not sort_headers.is_empty(): return
	_signature_entetes = signature
	for enfant in entete.get_children():
		entete.remove_child(enfant)
		enfant.queue_free()
	sort_headers.clear()
	for col: Dictionary in columns:
		if str(col.tri) == "":
			if col.id == "action": D.text(entete, col.x + col.w - 4, 22, "ACTION", 16, Charte.IVOIRE_2, 700, col.w, HORIZONTAL_ALIGNMENT_RIGHT)
			else: D.text(entete, col.x + (col.w if col.align == 2 else 0), 22, str(col.titre), 16, Charte.IVOIRE_2, 700, col.w, HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_LEFT)
			continue
		var tri := Button.new()
		tri.name = "MarketSort_" + str(col.tri)
		tri.text = str(col.titre) + " ↕"
		tri.flat = true
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_LEFT
		tri.clip_text = true
		tri.add_theme_font_override("font", Charte.TITRE_GRAS)
		tri.add_theme_font_size_override("font_size", maxi(12, C.px(16)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: tri.add_theme_color_override(etat, Charte.IVOIRE_2)
		tri.add_theme_color_override("font_hover_color", Charte.IVOIRE)
		tri.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		tri.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		tri.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		tri.add_theme_stylebox_override("focus", focus)
		tri.set_meta("sort_caption", str(col.titre))
		var cle: String = col.tri
		sort_headers[cle] = tri
		tri.pressed.connect(func():
			var same: bool = _sort_column() == cle
			state["report_descending" if tab == 3 else "descending"] = not _sort_descending() if same else cle in ["Niveau", "Potentiel", "Date du rapport", "Suivi"]
			state["report_sort" if tab == 3 else "sort"] = cle
			_filter_changed())
		entete.add_child(tri)
		D.place(tri, Rect2(col.x - 8, 0, col.w + 16, HEADER_H))

func _pied() -> void:
	D.line(self, Vector2(0, HAUTEUR - 52), Vector2(WIDTH, HAUTEUR - 52), Charte.FILET)
	count = Kit.texte(self, 0, HAUTEUR - 18, "", Charte.IVOIRE_2, 1000, 17)
	count.name = "MarketCount"
	direction = Kit.lien(self, Rect2(1010, HAUTEUR - 46, 0, 34), "↓ Décroissant", func():
		state["report_descending" if tab == 3 else "descending"] = not _sort_descending()
		_filter_changed(), "MarketDirection", 17)
	direction.tooltip_text = ""
	_refresh_count()
	# Raccourcis lisibles (la ligne dit ce que fait chaque touche ; elle n'est jamais cliquable).
	var droite := float(WIDTH)
	for touche: Array in [["Échap", "menu"], ["I", "aperçu"], ["A", "approcher"], ["↑ ↓", "choisir"]]:
		var mot: String = touche[1]
		droite -= Kit.largeur(mot, 17) + 6
		Kit.texte(self, droite, HAUTEUR - 18, mot, Charte.IVOIRE_2, 0, 17)
		var large := Kit.touche(self, droite - 8, HAUTEUR - 17, str(touche[0]), true)
		droite -= large + 22


func _refresh_count() -> void:
	if count == null: return
	var colonne := _sort_column().to_lower()
	var sens := "décroissant" if _sort_descending() else "croissant"
	var total: int = app.model.get("market", []).size()
	count.text = "%d rapports conservés · tri : %s %s" % [data.get("reports", []).size(), colonne, sens] if tab == 3 else "%d / %d pistes · %d suivies" % [_results_count, total, app.management_ui.shortlist.size()]
	direction.text = "↓ Décroissant" if _sort_descending() else "↑ Croissant"
	direction.position.x = C.px(Kit.largeur(count.text, 17) + 24)

var _results_count := 0

func _filter_changed() -> void:
	state.page = 0
	state.scroll = 0
	if table_scroll != null: table_scroll.scroll_vertical = 0
	_refresh()

func _filtered() -> Array:
	if tab == 3:
		var archive: Array = data.get("reports", []).duplicate()
		return Sort.sorted(archive, _sort_column(), _sort_descending(), report_by_player, true)
	var query_state := state.duplicate()
	query_state.search = ""
	var players := U.players(app.model.get("market", []), query_state, int(app.model.meta.get("season", 1)), true, app.management_ui.shortlist, false)
	var terms: PackedStringArray = []
	if str(state.get("navigation_id", "")).is_empty():
		terms = U.fold(str(state.get("search", ""))).split(" ", false)
	var fee := float({"≤ 100 k€": 100000, "≤ 400 k€": 400000, "≤ 1 M€": 1000000}.get(state.get("budget_filter"), INF))
	var ages: Vector2 = {"≤ 22 ans": Vector2(0, 22), "23–28 ans": Vector2(23, 28), "≥ 29 ans": Vector2(29, INF)}.get(state.get("age_filter"), Vector2(0, INF))
	var observation := str(state.get("observation", "Toutes"))
	var filtered := players.filter(func(p: Dictionary):
		var raw_age: Variant = p.get("age")
		var age_known: bool = (raw_age is int or raw_age is float) and is_finite(float(raw_age))
		var raw_fee: Variant = p.get("fee")
		var fee_known: bool = (raw_fee is int or raw_fee is float) and is_finite(float(raw_fee))
		var searchable := U.fold(str(p.get("name", "")) + " " + str(p.get("pos", "")))
		for term in terms:
			if not searchable.contains(term): return false
		if state.available == "Indisponibles" and p.get("available", false): return false
		if state.get("age_filter", "Tous") != "Tous" and (not age_known or float(raw_age) < ages.x or float(raw_age) > ages.y): return false
		if state.get("budget_filter", "Toutes") != "Toutes" and (not fee_known or float(raw_fee) > fee): return false
		var observe: bool = _observed(p)
		if observation == "Observées" and not observe: return false
		if observation == "Non observées" and observe: return false
		return true)
	if _sort_column() == "Suivi":
		# Suivies d'abord (ou en dernier), puis l'ordre des postes.
		var base: Array = Sort.sorted(filtered, "Poste", false, report_by_player)
		var suivies: Array = base.filter(func(p: Dictionary): return str(p.id) in app.management_ui.shortlist)
		var autres: Array = base.filter(func(p: Dictionary): return str(p.id) not in app.management_ui.shortlist)
		return suivies + autres if _sort_descending() else autres + suivies
	return Sort.sorted(filtered, _sort_column(), _sort_descending(), report_by_player)

func _observed(player: Dictionary) -> bool:
	return str(player.get("knowledge", {}).get("stage", "")) in ["observed", "deep"] or report_by_player.has(str(player.get("id", "")))

func _sort_column() -> String:
	return str(state.get("report_sort", "Date du rapport")) if tab == 3 else str(state.get("sort", "Poste"))

func _sort_descending() -> bool:
	return bool(state.get("report_descending", true)) if tab == 3 else bool(state.get("descending", false))

func _sort_arrows() -> void:
	for column: String in sort_headers:
		var button: Button = sort_headers[column]
		var active := column == _sort_column()
		button.text = str(button.get_meta("sort_caption")) + (" ↓" if _sort_descending() else " ↑") if active else str(button.get_meta("sort_caption")) + " ↕"
		button.add_theme_color_override("font_color", Charte.IVOIRE if active else Charte.IVOIRE_2)
		button.tooltip_text = "Trier par %s · %s · valeurs inconnues en dernier" % ["observation" if column == "Avis" else "indemnité" if column == "Prime" else column.to_lower(), "croissant au prochain clic" if active and _sort_descending() else "décroissant au prochain clic" if active else "activer le tri"]
		button.accessibility_name = button.text + " · " + button.tooltip_text

func _refresh() -> void:
	var scroll := table_scroll.scroll_vertical
	_clear(table_rows)
	var results := _filtered()
	_results_count = results.size()
	_ids_affiches = results.map(func(p: Dictionary): return str(p.get("playerId", p.id)))
	columns = _columns_for(results if tab != 3 else [])
	_entetes()
	table_rows.custom_minimum_size = Vector2(0, C.px(maxi(80, results.size() * ROW_HEIGHT)))
	var current := str(state.get("report_id" if tab == 3 else "player_id", ""))
	if not results.is_empty() and not results.any(func(p: Dictionary): return str(p.id) == current):
		current = str(results[0].id)
		state["report_id" if tab == 3 else "player_id"] = current
	_refresh_count()
	_sort_arrows()
	var selected_index := -1
	_selected = {}
	for i in results.size():
		if str(results[i].id) == current:
			_selected = results[i]
			selected_index = i
			break
	_generation += 1
	var built := mini(results.size(), FIRST_ROWS)
	if selected_index >= 0: built = maxi(built, mini(results.size(), selected_index + VISIBLE_MARGIN))
	_build_rows(results, current, 0, built)
	if built < results.size(): _build_remaining(results, current, built, _generation)
	if results.is_empty():
		var caption := "Aucun rapport conservé. Confie une mission pour observer des pistes." if tab == 3 else "Aucune piste ne correspond aux filtres actuels."
		Kit.texte(table_rows, 24, 40, caption, Charte.IVOIRE_2, WIDTH - 50, 20)
	_tuiles()
	_cout()
	table_scroll.set_deferred("scroll_vertical", scroll)

func _build_rows(items: Array, current: String, from: int, to: int) -> void:
	for i in range(from, to):
		var item: Dictionary = items[i]
		_row(item, i, str(item.id) == current)

func _build_remaining(items: Array, current: String, from: int, generation: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var next := from
	while next < items.size():
		await tree.process_frame
		if not is_instance_valid(self) or generation != _generation or not is_inside_tree(): return
		var upto := mini(items.size(), next + ROWS_PER_FRAME)
		_build_rows(items, current, next, upto)
		next = upto

## Raccourcis écrits au pied de page : « A » approche la piste choisie, ↑ ↓ passent à la piste voisine (focus sur une ligne).
func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	if not is_visible_in_tree() or tab == 3 or table_rows == null or not Pages.actuelle(app).is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is OptionButton or focus is SpinBox or focus is TextEdit: return
	if touche.keycode == KEY_A and not touche.shift_pressed:
		var offre := cost.find_child("OfferRecruitment", true, false) as Button
		if offre != null and not offre.disabled:
			get_viewport().set_input_as_handled()
			offre.pressed.emit()
	elif touche.keycode in [KEY_UP, KEY_DOWN] and focus is Button and focus.has_meta("player_id") and table_rows.is_ancestor_of(focus):
		var rang := _ids_affiches.find(str(focus.get_meta("player_id")))
		var voisin := rang + (1 if touche.keycode == KEY_DOWN else -1)
		if rang < 0 or voisin < 0 or voisin >= _ids_affiches.size(): return
		get_viewport().set_input_as_handled()
		state.player_id = str(_ids_affiches[voisin])
		_refresh()
		var cible := table_rows.get_node_or_null("MarketPlayer_" + str(_ids_affiches[voisin]).replace(":", "_")) as Button
		if cible != null: FocusLater.grab(cible)

func _col(id: String) -> Dictionary:
	for col: Dictionary in columns:
		if col.id == id: return col
	return {}

func _cellule(row: Control, id: String, valeur: String, couleur: Color = Charte.IVOIRE, gras: bool = false) -> Label:
	var col := _col(id)
	if col.is_empty(): return null
	var droite: bool = col.align == 2
	var texte := D.text(row, col.x + (col.w if droite else 0), 22, valeur, 20 if gras else 18, couleur, 700 if gras else 600, col.w, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT)
	texte.tooltip_text = ""
	return texte

func _observation_text(item: Dictionary, report: Dictionary) -> Array:
	var scouting: Dictionary = item.get("scouting", {}) if item.get("scouting") is Dictionary else {}
	if scouting.get("pending", false):
		var job: Variant = scouting.get("job")
		var reste := ""
		if job is Dictionary and job.get("remainingWeeks") != null: reste = " · " + P.plural(int(job.remainingWeeks), "semaine restante", "semaines restantes")
		return ["◷ Observation en cours" + reste, Charte.IVOIRE]
	if not report.is_empty():
		var source := str(report.get("assessment", {}).get("source", ""))
		return [source if not source.is_empty() else "Rapport conservé", Charte.IVOIRE]
	if _observed(item): return [Sort.report_label(item), Charte.IVOIRE_2]
	return ["Non observé", Charte.IVOIRE_3]

func _row(item: Dictionary, index: int, selected: bool) -> void:
	var player := item if tab != 3 else _market_player(str(item.get("playerId", "")))
	var report: Dictionary = item if tab == 3 else report_by_player.get(str(item.id), {})
	var player_id := str(item.get("playerId", item.id))
	var row := Button.new()
	row.name = "MarketReport_" + str(item.id) if tab == 3 else "MarketPlayer_" + player_id.replace(":", "_")
	row.set_meta("player_id", player_id)
	row.accessibility_name = "%s, %s" % [item.get("name", "Joueur inconnu"), item.get("pos", "Poste inconnu")]
	row.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3 if selected else Charte.PANNEAU if index % 2 == 0 else Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	row.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	row.add_theme_stylebox_override("focus", focus)
	table_rows.add_child(row)
	D.place(row, Rect2(0, index * ROW_HEIGHT, WIDTH, ROW_HEIGHT))
	if selected: Kit.marqueur(row, Rect2(2, 3, 6, ROW_HEIGHT - 6))
	var assessment: Dictionary = report.get("assessment", {})
	var suivi: bool = player_id in app.management_ui.shortlist
	_portrait(row, Rect2(56, 2, 28, 28), player, player_id)
	var drapeau := Identity.flag_texture(str(player.get("playerFacts", {}).get("flagCode", "")) if player.get("playerFacts") is Dictionary else "")
	var x_nom := 128.0
	if drapeau != null:
		var image := TextureRect.new()
		image.name = "MarketFlag"
		image.texture = drapeau
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		D.place(image, Rect2(92, 7, 26, 18))
		x_nom = 128.0
	var ligne_nom := D.text(row, x_nom, 22, str(item.get("name", "—")), 20, Charte.IVOIRE, 700, 300)
	ligne_nom.name = "MarketName"
	if tab == 3:
		_cellule(row, "poste", str(item.get("pos", "—")))
		_cellule(row, "date", str(assessment.get("source", "Date non conservée")), Charte.IVOIRE_2)
		_cellule(row, "obs", _report_label(report), Charte.IVOIRE)
	else:
		_cellule(row, "poste", str(item.get("pos", "—")), Charte.IVOIRE_2)
		var nom_club := _club(item)
		if not nom_club.is_empty(): _cellule(row, "club", nom_club, Charte.IVOIRE_2)
		_cellule(row, "age", G.n(item.get("age", "—")))
		var niveau: Variant = G.knowledge_sort_value(item, "rating")
		_cellule(row, "niveau", G.rating_text(item), Charte.couleur_attribut(niveau) if niveau != null else Charte.IVOIRE_3, true)
		_cellule(row, "potentiel", G.potential_text(item if not item.is_empty() else report), Charte.IVOIRE_2, true)
		var attributs := Attributs.detail(item, false)
		if not attributs.is_empty():
			for pair: Array in [["touche", "lineoutThrow"], ["melee", "scrumTechnique"], ["gratt", "jackal"], ["plaq", "tackling"]]:
				var valeur: Variant = attributs.get(pair[1])
				if valeur is int or valeur is float: _cellule(row, pair[0], G.n(valeur), Charte.couleur_attribut(valeur), true)
		var fin: Variant = item.get("contractEnd")
		if fin is int or fin is float: _cellule(row, "fin", G.contract_year(fin), Charte.IVOIRE_2)
		_cellule(row, "indemnite", _money(item.get("fee")), Charte.IVOIRE, true)
		_cellule(row, "salaire", G.salary(item.get("salary")), Charte.IVOIRE_2)
		var observation := _observation_text(item, report)
		_cellule(row, "obs", str(observation[0]), observation[1])
	# Étoile : suivre / ne plus suivre (l'état est dit en mots dans l'infobulle et le nom accessible).
	if tab != 3 and not player.is_empty():
		var etoile := Button.new()
		etoile.name = "Star_" + player_id.replace(":", "_")
		etoile.flat = true
		etoile.text = "★" if suivi else "☆"
		etoile.add_theme_font_override("font", Charte.TITRE_GRAS)
		etoile.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: etoile.add_theme_color_override(etat, Charte.IVOIRE if suivi else Charte.IVOIRE_3)
		etoile.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		etoile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		etoile.add_theme_stylebox_override("focus", focus)
		etoile.accessibility_name = ("Retirer du suivi : " if suivi else "Suivre cette piste : ") + str(item.get("name", ""))
		etoile.tooltip_text = ""
		var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
		etoile.disabled = app.waiting or not app._live().is_empty() or app.model.meta.get("phase", "") == "ended" or not context is Dictionary
		etoile.pressed.connect(func(): app._command("manager_recruitment_watch", {"context": context.duplicate(true), "playerId": player_id}))
		row.add_child(etoile)
		D.place(etoile, Rect2(8, 0, 44, ROW_HEIGHT))
	# Action de la ligne : Observer (choisit la piste, le coût s'affiche en bas), En cours, Approcher (écran d'offre).
	if tab != 3 and not player.is_empty():
		var col := _col("action")
		var en_cours: bool = item.get("scouting", {}).get("pending", false) if item.get("scouting") is Dictionary else false
		var approcher: bool = _observed(item) and not en_cours
		var libelle := "En cours" if en_cours else "Approcher" if approcher else "Observer"
		var action := Button.new()
		action.name = "MarketRowAction_" + player_id.replace(":", "_")
		action.text = libelle
		action.focus_mode = Control.FOCUS_ALL
		action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		C.style_bouton_lien(action, 17)
		action.add_theme_color_override("font_color", Charte.IVOIRE if approcher else Charte.IVOIRE_2)
		action.text = "Approcher →" if approcher else libelle
		action.alignment = HORIZONTAL_ALIGNMENT_LEFT
		action.disabled = en_cours
		action.accessibility_name = "%s : %s" % [libelle, item.get("name", "")]
		action.pressed.connect(func():
			if approcher: _approcher(item)
			else:
				state.player_id = str(item.id)
				_refresh()
				var bloc := cost.find_child("ObserveRecruitment", true, false) as Control
				if bloc != null: bloc.grab_focus.call_deferred())
		row.add_child(action)
		D.place(action, Rect2(col.x + 14, 3, col.w - 44, ROW_HEIGHT - 6))
	# Nom : survol (ou focus + I) = mini-fiche, clic = fiche complète ; « i » juste après le nom.
	var entity_target := {"kind":"report", "id":str(item.id)} if tab == 3 else {"kind":"market", "id":player_id}
	if tab != 3 and not player.is_empty():
		var portrait_lien := _reading_area(row, Rect2(52, 0, 72, ROW_HEIGHT), entity_target, "MarketPortrait_" + str(item.id).validate_node_name(), str(item.get("name", "Dossier")))
		if portrait_lien != null: MiniFiche.lier(app, portrait_lien, player_id, "market")
	var nom_lien := _reading_area(row, Rect2(x_nom - 4, 0, 330, ROW_HEIGHT), entity_target, "MarketEntity_" + str(item.id).validate_node_name(), str(item.get("name", "Dossier")))
	if tab != 3 and nom_lien != null and not player.is_empty():
		MiniFiche.lier(app, nom_lien, player_id, "market")
		var police: Font = C.font(700)
		var largeur := minf(300.0, police.get_string_size(str(item.get("name", "—")), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density)
		MiniFiche.icone(app, row, Rect2(x_nom + largeur + 8, 7, 18, 18), player_id, "market")
	if tab != 3 and not report.is_empty():
		var col := _col("obs")
		if not col.is_empty(): _reading_area(row, Rect2(col.x - 4, 0, mini(col.w, 360), ROW_HEIGHT), {"kind":"report", "id":str(report.get("id", ""))}, "MarketReportLink_" + str(report.get("id", "")).validate_node_name(), "Rapport d’observation · " + str(item.get("name", "")))
	row.pressed.connect(func():
		state["report_id" if tab == 3 else "player_id"] = str(item.id)
		var target := str(row.name)
		_refresh()
		var focused := table_rows.get_node_or_null(target) as Button
		if focused != null: FocusLater.grab(focused))

# --- Coût de l'offre --------------------------------------------------------------------------------------------

## « Ce que coûte l'offre » (maquette 3) : indemnité, salaire demandé, durée, effet sur le budget de transferts et la
## masse salariale de la piste choisie ; l'action principale de l'écran (ivoire plein) est ici et nulle part ailleurs.
func _cout() -> void:
	_clear(cost)
	D.rect(cost, Rect2(0, 0, WIDTH, 172), Charte.PANNEAU, 0)
	var player := _selected if tab != 3 else _market_player(str(_selected.get("playerId", "")))
	var report: Dictionary = _selected if tab == 3 else report_by_player.get(str(_selected.get("id", "")), {})
	Kit.etiquette(cost, 24, 34, "Ce que coûte l’offre", 330)
	if player.is_empty():
		Kit.texte(cost, 24, 84, "Aucune piste sélectionnée : choisis une ligne pour voir ce que coûterait son arrivée.", Charte.IVOIRE_2, 1100, 19).name = "RecruitmentCostEmpty"
		var besoins := Kit.lien(cost, Rect2(24, 108, 0, 36), "Besoins, missions et rapports →", func(): _staff(0), "OpenEmptyRecruitmentNeeds", 19)
		besoins.tooltip_text = ""
		return
	var player_id := str(player.get("id", ""))
	var nom := D.text(cost, 24, 82, str(player.get("name", "—")).to_upper(), 36, Charte.IVOIRE, 800, 420)
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.name = "RecruitmentCostName"
	var bouton_nom := _reading_area(cost, Rect2(20, 44, 430, 50), {"kind":"market", "id":player_id}, "RecruitmentNameLink", str(player.get("name", "Dossier")))
	if bouton_nom != null: MiniFiche.lier(app, bouton_nom, player_id, "market")
	var statut: String = {"counter":"contre-offre reçue", "withdrawn":"discussion rompue", "signed":"contrat signé"}.get(str(player.get("negotiation", {}).get("status", "")) if player.get("negotiation") is Dictionary else "", "avant négociation")
	var detail := "%s · %s ans · %s" % [str(player.get("pos", "—")), G.n(player.get("age", "—")), statut]
	Kit.texte(cost, 24, 116, detail, Charte.IVOIRE_2, 440, 18)
	# Budget de transferts : déjà engagé, cette indemnité, reste.
	var budget := Budget.data(app.model)
	var fee: Variant = player.get("fee")
	var fee_known: bool = fee is int or fee is float
	if not budget.is_empty():
		var total := Budget.season_total(budget)
		var depense := int(budget.get("depense", 0))
		Kit.etiquette(cost, 500, 34, "Budget de transferts · %s alloués" % G.euros(total), 520)
		var barre := Rect2(500, 52, 700, 20)
		D.rect(cost, barre, Charte.PANNEAU_3, 0)
		if total > 0:
			var largeur_depense := 700.0 * clampf(float(depense) / total, 0, 1)
			var largeur_offre := 700.0 * clampf(float(fee if fee_known else 0) / total, 0, 1 - largeur_depense / 700.0)
			if largeur_depense > 0: D.rect(cost, Rect2(500, 52, largeur_depense, 20), Charte.IVOIRE_3, 0)
			if largeur_offre > 0: D.rect(cost, Rect2(500 + largeur_depense, 52, largeur_offre, 20), Charte.IVOIRE, 0)
			D.rect(cost, Rect2(500 + largeur_depense + largeur_offre, 52, maxf(0, 700 - largeur_depense - largeur_offre), 20), Color.TRANSPARENT, 0, Charte.IVOIRE_3)
		var reste := int(budget.get("disponible", 0)) - (int(fee) if fee_known else 0)
		var apres := Kit.texte(cost, 500, 140, "après l’offre : %s restants" % G.euros(reste) if fee_known else "disponible : %s" % Budget.remaining(budget), Charte.IVOIRE if reste >= 0 else Charte.D, 700, 19)
		apres.add_theme_font_override("font", Charte.texte_moyen())
		apres.name = "RecruitmentCostAfter"
		var legende := [["Déjà engagé", G.euros(depense), Charte.IVOIRE_3, true]]
		if fee_known: legende.append(["Cette indemnité", G.euros(fee), Charte.IVOIRE, true])
		legende.append(["Reste", G.euros(reste), Charte.IVOIRE_3, false])
		var lx := 500.0
		for element: Array in legende:
			D.rect(cost, Rect2(lx, 92, 14, 14), element[2] if element[3] else Color.TRANSPARENT, 0, Charte.IVOIRE_3 if not element[3] else Color.TRANSPARENT)
			var texte := "%s %s" % [element[0], element[1]]
			Kit.texte(cost, lx + 22, 104, texte, Charte.IVOIRE_2, 300, 17)
			lx += Kit.largeur(texte, 17) + 50
		if fee_known and reste < 0:
			Kit.texte(cost, 500, 164, "Hors budget : le conseil peut accorder une rallonge si la caisse le permet.", Charte.D, 700, 17).name = "RecruitmentCostOverBudget"
	else:
		var cash: Variant = app.model.get("finance", {}).get("cash")
		Kit.etiquette(cost, 500, 34, "Trésorerie du club", 520)
		Kit.texte(cost, 500, 82, G.euros(cash) if cash is int or cash is float else "—", Charte.IVOIRE, 400, 30)
	# Indemnité, salaire, durée.
	var quote := player
	Kit.texte(cost, 1290, 34, "Indemnité de transfert", Charte.IVOIRE_2, 330, 17)
	var montant := D.text(cost, 1290, 84, _money(quote.get("fee", quote.get("price"))), 40, Charte.IVOIRE, 800, 330)
	montant.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	montant.name = "RecruitmentCostFee"
	var max_years := int(player.get("maxYears", 0))
	var annees := "%s à %s ans" % [G.n(player.get("minYears", 1)), G.n(max_years)] if max_years > 1 else "1 an" if max_years == 1 else ""
	var salaire_txt := G.salary(quote.get("salary"))
	Kit.texte(cost, 1290, 116, "Salaire demandé · " + salaire_txt + ((" · " + annees) if not annees.is_empty() else ""), Charte.IVOIRE_2, 440, 17).name = "RecruitmentCostSalary"
	if (quote.get("salary") is int or quote.get("salary") is float) and max_years > 0:
		var total_salaire := int(quote.salary) * WEEKS_PER_YEAR * max_years
		Kit.texte(cost, 1290, 146, "Masse salariale sur %d ans : +%s" % [max_years, G.euros(total_salaire)], Charte.IVOIRE, 440, 17).name = "RecruitmentCostPayroll"
	# Observation (frais et délai) lue sur le joueur, jamais inventée.
	var scouting: Dictionary = player.get("scouting", {}) if player.get("scouting") is Dictionary else {}
	var frais := ""
	if not scouting.is_empty() and not scouting.get("pending", false) and scouting.has("cost"): frais = "Observer : %s · %s" % [G.euros(scouting.get("cost", 0)), G.n(scouting.get("workCycles", 0)) + (" semaines" if scouting.get("workUnit") == "week" else " cycles")]
	# Actions : principale (ivoire plein), puis liens.
	# Actions : principale (ivoire plein, un seul par écran), puis liens à la suite.
	var consultation: bool = player.get("negotiation", {}).get("status", "") == "withdrawn" if player.get("negotiation") is Dictionary else false
	var observable := player.get("scouting") is Dictionary and not Observation.reason(app, player) == "Joueur de ton club"
	var principal := Kit.bouton_ivoire(cost, Rect2(1790, 20, 440, 44), "Consulter la discussion" if consultation else "Approcher le joueur", func(): _approcher(player), "OfferRecruitment")
	principal.set_meta("player_id", player_id)
	principal.disabled = app.waiting or (not player.get("available", false) and not consultation) or not app._live().is_empty()
	principal.tooltip_text = str(player.get("reason", "")) if not player.is_empty() else ""
	if principal.disabled and not str(player.get("reason", "")).is_empty():
		Kit.texte(cost, 1790, 92, str(player.get("reason", "")), Charte.D, 440, 17).name = "RecruitmentCostBlocked"
	elif not frais.is_empty():
		Kit.texte(cost, 1790, 92, frais, Charte.IVOIRE_2, 440, 17).name = "RecruitmentCostObservation"
	var liens: Array = []
	if observable: liens.append(["Observer →" if Observation.caption(player) == "Observer" else Observation.caption(player) + " →", "ObserveRecruitment", func(): _confirmer_observation(player), not Observation.reason(app, player).is_empty()])
	liens.append(["Ouvrir la fiche →", "OpenRecruitmentPlayer", func(): app.navigation_controller.open_entity({"kind":"market", "id":player_id}), false])
	var context_suivi: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
	var peut_suivre: bool = not app.waiting and app._live().is_empty() and app.model.meta.get("phase", "") != "ended" and context_suivi is Dictionary
	liens.append(["Retirer du suivi" if player_id in app.management_ui.shortlist else "Suivre cette piste", "Follow" + player_id.replace(":", "_"), func(): app._command("manager_recruitment_watch", {"context": context_suivi.duplicate(true), "playerId": player_id}), not peut_suivre])
	if tab == 3 or not report.is_empty(): liens.append(["Lire le rapport complet →", "OpenScoutReport", func(): _report_page(report), false])
	var lx2 := 1790.0
	var ly := 100.0
	for lien: Array in liens:
		var largeur := Kit.largeur(str(lien[0]), 18) + 12
		if lx2 + largeur > 2240 and lx2 > 1790:
			lx2 = 1790.0
			ly += 30
		var bouton := Kit.lien(cost, Rect2(lx2, ly, largeur, 30), str(lien[0]), lien[2], str(lien[1]), 18)
		bouton.tooltip_text = ""
		bouton.disabled = lien[3]
		if str(lien[1]).begins_with("Follow"): bouton.set_meta("follow_id", player_id)
		lx2 += largeur + 18

## Observation payante : confirmation EN PLACE (deux temps, aucune fenêtre), sur la partie droite du bloc de coût.
func _confirmer_observation(player: Dictionary) -> void:
	if Observation.reason(app, player) != "" or not player.get("scouting") is Dictionary: return
	var scouting: Dictionary = player.scouting
	var phrase := "Frais : %s · délai : %s. Le rapport arrive à la fin de la mission." % [G.euros(scouting.get("cost", 0)), G.n(scouting.get("workCycles", 0)) + (" semaines" if scouting.get("workUnit") == "week" else " cycles")]
	var envoyer := func(): _observer(player)
	var bloc := EnPlace.ouvrir(app, cost, "ObservationConfirmation", "Observer " + str(player.get("name", "")), [{"id":"ObservationConfirmPhrase", "text":phrase}], "Lancer l’observation · " + G.euros(scouting.get("cost", 0)), envoyer)
	D.place(bloc, Rect2(1100, 0, WIDTH - 1100, 10))

func _observer(player: Dictionary) -> void:
	# Le coût et le délai sont écrits à côté du bouton : cliquer vaut confirmation (aucune fenêtre).
	if Observation.reason(app, player) != "" or not player.get("scouting") is Dictionary: return
	var context: Variant = player.scouting.get("context")
	if not context is Dictionary: return
	app._command("observe_player", {"playerId": Observation.player_id(player), "confirmed": true, "context": context.duplicate(true)})

func _approcher(player: Dictionary) -> void:
	Pages.ouvrir(app, "negociation", {"player_id": str(player.get("id", ""))})

# --- Divers -----------------------------------------------------------------------------------------------------

func _staff(index: int, role: String = "") -> void:
	Pages.ouvrir(app, "missions", {"tab": index, "role": role})

func _fins_de_contrat() -> void:
	var lecture: Dictionary = app.management_ui.roster
	lecture.immersive_tab = 2
	lecture.sort = "Échéance"
	lecture.descending = false
	app.roster_sort = "Échéance"
	app._navigate("Effectif")

func _reading_area(parent: Node, area: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	if not app.navigation_controller.entity_available(target): return null
	var link := Button.new()
	link.name = id
	link.flat = true
	link.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	link.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color(Charte.IVOIRE, .5), 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	link.add_theme_stylebox_override("focus", focus)
	Link.bind(link, app, target, caption)
	parent.add_child(link)
	D.place(link, area)
	return link

func _report_page(report: Dictionary) -> void:
	app.navigation_controller.open_entity({"kind":"report", "id":str(report.get("id", ""))})

func _compare() -> void:
	# Le comparateur est l'écran « Comparateur » (agent de l'Effectif).
	load("res://ui/immersive08/comparateur_canvas.gd").ouvrir(app, str(_selected.get("id", "")))

func _market_player(player_id: String) -> Dictionary:
	for person: Dictionary in app.model.get("market", []):
		if str(person.id) == player_id: return person
	return {}

static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func _report_label(report: Dictionary) -> String:
	return Sort.report_label(report)

static func _money(value: Variant) -> String:
	return G.euros(value) if value is int or value is float else "—"

static func _portrait(parent: Node, area: Rect2, player: Dictionary, player_id: String, full: bool = false) -> void:
	if str(player.get("id", "")).is_empty():
		D.photo(parent, "recruit-profile" if full else "player-%02d" % posmod(player_id.hash(), 16), area)
		return
	# Lignes de la liste : cases vides remplies par tranches (portrait_loader).
	var photo: Control = G.portrait(0, C.px(minf(area.size.x, area.size.y)), player) if full else G.portrait_lazy(0, C.px(minf(area.size.x, area.size.y)), player)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(photo)
	D.place(photo, area)

