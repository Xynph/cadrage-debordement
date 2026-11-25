extends "res://ui/immersive08/academy_encadrement.gd"
## Formation (design/ux/19-formation.md, maquette 19-formation-retouche du 19/11/2026) : tableau des jeunes, décision du jeune
## choisi (promouvoir, avec confirmation EN PLACE) et file « À décider » aux raisons écrites. Nom d'un jeune : survol =
## mini-fiche, clic = fiche complète ; jamais de fiche fixe ni de petite fenêtre (sous-pages : formation_pages.gd).
## Coordonnées en unités du gabarit (2248 de large), couleurs uniquement depuis ui/charte.gd, aucun or.
## Découpé sans changement : constantes et outils dans academy_socle.gd, puis filtres, en-tête, décision, tableau, passerelles, encadrement (chaîne d’héritage, voir le socle).
const Socle = preload("res://ui/immersive08/academy_socle.gd")

## Points d’entrée publics (fiches, tests) : redéfinis ici, car `has_method` d’un script ne voit pas les statiques hérités.
static func professional_progress(app: Control, player_id: String) -> Dictionary: return Socle.professional_progress(app, player_id)
static func open_professional_progress(app: Control, player_id: String, _source_id: String = "") -> void: Socle.open_professional_progress(app, player_id, _source_id)
static func _option(id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> OptionButton: return Socle._option(id, caption, choices, chosen, callback)

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.app = application
	page.name = "ImmersiveAcademy"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, HAUTEUR))
	canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, HAUTEUR * C.density)
	page._build()

## Quitter la Formation : la sous-page et sa fenêtre d'origine sont oubliées.
static func oublier_page(owner_app: Control) -> void:
	Pages.oublier(owner_app)

func _build() -> void:
	development = app.model.get("decisions", {}).get("development", {})
	pathway = app.model.get("clubLife", {}).get("academyPathways", {})
	season = int(app.model.get("meta", {}).get("season", 1))
	roster = development.get("academy", [])
	professionals = development.get("professionals", []).filter(func(p: Dictionary): return int(p.get("age", 99)) <= 23)
	for person: Dictionary in pathway.get("players", []): academy_by_id[person.id] = person
	staff = _academy_staff()
	if not app.management_ui.get("immersive_academy") is Dictionary:
		app.management_ui.immersive_academy = {}
	state = app.management_ui.immersive_academy
	var club_id: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club_id:
		state.clear()
		state.club = club_id
	var sous := Pages.actuelle(app)
	if not sous.is_empty():
		Pages.build(app, self, sous)
		return
	active_tab = clampi(int(state.get("tab", 0)), 0, TABS.size() - 1)
	var group := str(state.get("group", "u21"))
	shown = Order.ordered(_filtered(group, true), str(state.get("table_sort", "decide")), bool(state.get("table_descending", false)), _sort_value)
	_select_visible(shown)
	_heading()
	_tabs()
	match active_tab:
		0, 1:
			_filters(group)
			_table(group)
			strip = Control.new()
			strip.name = "AcademyDecision"
			add_child(strip)
			D.place(strip, Rect2(0, STRIP_TOP, WIDTH, 112))
			cards = Control.new()
			cards.name = "AcademyDecisions"
			add_child(cards)
			D.place(cards, Rect2(0, CARTES_TOP, WIDTH, 190))
			_strip()
			_cartes()
			_pied(group)
		2: _pathways()
		3: _staff_page()
