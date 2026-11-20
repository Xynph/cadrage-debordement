extends Control
## Formation (design/ux/19-formation.md, maquette 19-formation-retouche du 19/11/2026) : tableau des jeunes, décision du jeune
## choisi (promouvoir, avec confirmation EN PLACE) et file « À décider » aux raisons écrites. Nom d'un jeune : survol =
## mini-fiche, clic = fiche complète ; jamais de fiche fixe ni de petite fenêtre (sous-pages : formation_pages.gd).
## Coordonnées en unités du gabarit (2248 de large), couleurs uniquement depuis ui/charte.gd, aucun or.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Order = preload("res://ui/player_table_order.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const Pages = preload("res://ui/immersive08/formation_pages.gd")
const Identity = preload("res://ui/player_identity.gd")
const Words = preload("res://ui/management_state.gd")
const TABS = ["Effectif", "Progression", "Passerelles", "Encadrement"]
const GROUPES := {"u21":"U21", "u18":"U18", "academy":"Tous les Espoirs", "professional":"Jeunes professionnels"}
const TRIS := {"decide":"À décider d’abord", "note":"Niveau", "potential":"Potentiel", "age":"Âge", "name":"Nom"}
const WIDTH := 2248
const HAUTEUR := 1250
const ROW := 30.0
const HEADER_H := 34.0
const TABLE_TOP := 258.0
const ROWS_H := 560.0
const STRIP_TOP := 874.0
const CARTES_TOP := 1004.0

## Courbe de niveau des saisons passées (jetons de la charte : trait ivoire, dernier point plein).
class Trend extends Control:
	var levels: Array[float] = []
	var minimum := 0.0
	var maximum := 100.0

	func _draw() -> void:
		draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Charte.FILET, maxf(1.0, C.density))
		var points := PackedVector2Array()
		for i in levels.size():
			var fraction := float(i) / (levels.size() - 1) if levels.size() > 1 else 1.0
			points.append(Vector2(lerpf(size.x * .06, size.x * .94, fraction), size.y * (1.0 - inverse_lerp(minimum, maximum, levels[i]))))
		if points.size() > 1: draw_polyline(points, Charte.IVOIRE_2, maxf(1.5, C.px(2.0)), true)
		for index in points.size(): draw_circle(points[index], C.px(3.5) if index < points.size() - 1 else C.px(5.0), Charte.IVOIRE_2 if index < points.size() - 1 else Charte.IVOIRE, true, -1, true)

var app: Control
var state: Dictionary
var development: Dictionary
var pathway: Dictionary
var roster: Array
var professionals: Array
var academy_by_id: Dictionary = {}
var selected: Dictionary
var active_tab := 0
var staff: Array
var rows: Control
var strip: Control
var cards: Control
var shown: Array = []
var season := 1

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
		Kit.angles_droits(self)
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
	Kit.angles_droits(self)

# --- En-tête, compteurs, onglets ---------------------------------------------------------------------------------------

func _heading() -> void:
	var titre := Kit.titre(self, 0, 44, "Formation", 38, 700)
	titre.name = "AcademyTitle"
	app.heading = titre
	var decider := _compter(roster, "decide")
	var phrase := "La relève · %s" % P.plural(roster.size(), "espoir", "espoirs")
	if decider > 0: phrase += " · %s à trancher avant la fin de saison" % P.plural(decider, "contrat d’espoir", "contrats d’espoir")
	Kit.texte(self, 0, 78, phrase, Charte.IVOIRE_2, 0, 18)
	var suivi := Kit.lien(self, Rect2(Kit.largeur(phrase, 18) + 30, 52, 0, 34), "Suivre les objectifs et gains observés →", func(): Pages.ouvrir(app, "suivi"), "OpenYouthDevelopment", 18)
	suivi.tooltip_text = ""
	var u18 := roster.filter(func(p: Dictionary): return int(p.get("age", 0)) <= 18).size()
	var pepites := _compter(roster, "pepite")
	var recruitment: Dictionary = app.model.get("decisions", {}).get("recruitment", {})
	var places: Variant = recruitment.get("places")
	var capacite: Variant = recruitment.get("capacity")
	var tuiles := [
		["ESPOIRS", G.n(roster.size()), "%d U18 · %d U21" % [u18, roster.size() - u18], "AcademyTileEspoirs", func(): _fixer("status", ""), 262.0],
		["PÉPITES", "★ " + G.n(pepites), "potentiel ≥ 85", "AcademyTilePepites", func(): _fixer("status", "pepite"), 262.0],
		["À DÉCIDER", G.n(decider), "contrat à trancher", "AcademyTileDecider", func(): _fixer("status", "decide"), 262.0],
		["PLACES PRO LIBRES", G.n(places) if places is int or places is float else "—", "sur l’effectif de %s" % G.n(capacite) if capacite is int or capacite is float else "à l’effectif", "AcademyTilePlaces", func(): app._navigate("Effectif"), 300.0],
	]
	var x := float(WIDTH) - 4 * 12.0 + 12.0
	for tuile: Array in tuiles: x -= float(tuile[5])
	for index in tuiles.size():
		var tuile: Array = tuiles[index]
		_tuile(x, float(tuile[5]), str(tuile[0]), str(tuile[1]), str(tuile[2]), str(tuile[3]), tuile[4], index == 2)
		x += float(tuile[5]) + 12.0

func _tuile(x: float, largeur: float, etiquette: String, valeur: String, suite: String, id: String, action: Callable, marque: bool) -> void:
	var tuile := Button.new()
	tuile.name = id
	tuile.flat = true
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s : %s, %s" % [etiquette.capitalize(), valeur, suite]
	tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU, Color.TRANSPARENT, 0, 0))
	tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	tuile.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	tuile.pressed.connect(action)
	add_child(tuile)
	D.place(tuile, Rect2(x, 6, largeur, 116))
	if marque: Kit.marqueur(tuile, Rect2(0, 0, 8, 116))
	var gauche := 34 if marque else 16
	D.text(tuile, gauche, 36, etiquette, 16, Charte.IVOIRE_2, 700, largeur - 30)
	var nombre := D.text(tuile, gauche, 84, valeur, 46, Charte.IVOIRE, 800, largeur - 30)
	nombre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(tuile, gauche + Kit.largeur(valeur, 34) + 14, 82, suite, 16, Charte.IVOIRE_2, 600, largeur - gauche - Kit.largeur(valeur, 34) - 22)
	for enfant in tuile.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fixer(cle: String, valeur: Variant) -> void:
	state[cle] = valeur
	state.tab = 0
	state.table_scroll = 0
	app._render()

func _tabs() -> void:
	var x := 0.0
	for i in TABS.size():
		var libelle: String = TABS[i]
		var choisi := active_tab == i
		var largeur := Kit.largeur(libelle, 19) + 44
		var bouton := Button.new()
		bouton.name = "AcademyImmersiveTab" + str(i)
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
		bouton.set_pressed_no_signal(choisi)
		bouton.pressed.connect(func(): _open_tab(i))
		add_child(bouton)
		D.place(bouton, Rect2(x, 148, largeur, 44))
		x += largeur + 8
	D.line(self, Vector2(0, 192), Vector2(WIDTH, 192), Charte.FILET)
	_group_upgrade(x)

## Passage à 30 U18 et 30 U21 : lien dans la ligne des onglets ; confirmation EN PLACE ; raison écrite dans la page.
func _group_upgrade(depart: float) -> void:
	var meta: Dictionary = app.model.get("meta", {})
	if int(meta.get("academyGroupPolicy", 0)) >= 2: return
	var apercu: Dictionary = meta.get("academyGroups", {})
	var zone := Rect2(WIDTH, 152, 0, 38)
	if apercu.is_empty():
		var lien := Kit.lien(self, zone, "Vérifier le passage à 30 U18 et 30 U21 →", func(): app._command("academy_groups_preview"), "AcademyGroupsPreview", 18, true)
		lien.tooltip_text = ""
		return
	if not apercu.get("available", false):
		var raison := Kit.lien(self, zone, "Pourquoi la mise à jour attend →", func():
			state.groupes_raison = not bool(state.get("groupes_raison", false))
			app._render(), "AcademyGroupsBlocked", 18, true)
		raison.tooltip_text = ""
		if state.get("groupes_raison", false):
			var note := D.rect(self, Rect2(WIDTH - 900, 196, 900, 70), Charte.PANNEAU_3, 0)
			note.name = "AcademyGroupsReason"
			note.z_index = 5
			var texte := C.wrap(str(apercu.get("reason", "Réessaie après la prochaine intersaison.")), 18, Charte.IVOIRE)
			note.add_child(texte)
			D.place(texte, Rect2(16, 10, 868, 52))
		return
	var texte_confirmation := "Compléter les Crabos et Espoirs des %d clubs ? %d jeunes rejoindront les centres. Les joueurs en place garderont leur fiche et leurs acquis." % [int(apercu.centers), int(apercu.additions)]
	var lien := Kit.lien(self, zone, "Compléter les centres de formation →", func():
		var bloc := EnPlace.ouvrir(app, self, "AcademyGroupsConfirm", "30 U18 et 30 U21 par club", [texte_confirmation], "Compléter les centres", func():
			app._command("academy_groups_enable", {"confirmed": true, "context": apercu.context}))
		D.place(bloc, Rect2(WIDTH - 1000, 200, 1000, 10)), "AcademyGroupsEnable", 18, true)
	lien.tooltip_text = ""
	lien.add_theme_font_override("font", Charte.TITRE_GRAS)

func _open_tab(index: int) -> void:
	state.tab = index
	state.table_scroll = 0
	state.page = 0
	app._render()
	U.focus(app, "AcademyImmersiveTab" + str(index))

# --- Filtres -----------------------------------------------------------------------------------------------------------

func _compter(people: Array, statut: String) -> int:
	return people.filter(func(p: Dictionary): return _est(p, statut)).size()

func _est(p: Dictionary, statut: String) -> bool:
	match statut:
		"decide": return _a_decider(p)
		"pepite": return _pepite(p)
		"blesse": return float(p.get("injury", 0)) > 0
	return true

func _a_decider(p: Dictionary) -> bool:
	var fin: Variant = p.get("contractEnd")
	return (fin is int or fin is float) and int(fin) <= season

func _pepite(p: Dictionary) -> bool:
	var potentiel: Variant = G.knowledge_sort_value(p, "potential")
	return potentiel != null and potentiel >= 85

## Liste du groupe choisi ; `avec_statut` ajoute la puce de statut (le total des puces ne la subit pas).
func _filtered(group: String, avec_statut: bool) -> Array:
	var people := professionals if group == "professional" else roster
	var recherche := Words.fold(str(state.get("search", ""))).strip_edges()
	return people.filter(func(p: Dictionary):
		var age := int(p.get("age", 0))
		if group == "u18" and age > 18: return false
		if group == "u21" and (age <= 18 or age > 21): return false
		if not str(state.get("position", "")).is_empty() and p.get("pos") != state.position: return false
		if not recherche.is_empty() and not Words.fold(str(p.get("name", "")) + " " + str(p.get("pos", ""))).contains(recherche): return false
		if avec_statut and not str(state.get("status", "")).is_empty() and not _est(p, str(state.status)): return false
		return true)

func _filters(group: String) -> void:
	var recherche := LineEdit.new()
	recherche.name = "AcademySearch"
	recherche.placeholder_text = "Chercher un jeune…"
	recherche.text = str(state.get("search", ""))
	recherche.clear_button_enabled = true
	recherche.accessibility_name = "Chercher un jeune par nom ou poste"
	recherche.add_theme_font_override("font", Charte.TEXTE)
	recherche.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	recherche.add_theme_color_override("font_color", Charte.IVOIRE)
	recherche.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	recherche.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, 0, 10))
	var focus := C.box(Charte.PANNEAU_3, Charte.IVOIRE, 0, 10)
	focus.set_border_width_all(2)
	recherche.add_theme_stylebox_override("focus", focus)
	add_child(recherche)
	D.place(recherche, Rect2(0, 204, 330, 38))
	recherche.text_changed.connect(func(value: String):
		state.search = value
		state.search_focus = true
		state.table_scroll = 0
		app._render())
	if state.get("search_focus", false):
		state.erase("search_focus")
		recherche.grab_focus.call_deferred()
		recherche.set_deferred("caret_column", recherche.text.length())
	var base := _filtered(group, false)
	var puces := [["", "Tous", base.size()], ["decide", "À décider", _compter(base, "decide")], ["pepite", "Pépites", _compter(base, "pepite")], ["blesse", "Blessés", _compter(base, "blesse")]]
	var x := 346.0
	for puce: Array in puces:
		var choisie := str(state.get("status", "")) == str(puce[0])
		var libelle := "%s  %d" % [puce[1], puce[2]]
		var largeur := Kit.largeur(libelle, 18) + 34
		var bouton := Button.new()
		bouton.name = "AcademyChip_" + (str(puce[0]) if not str(puce[0]).is_empty() else "tous")
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.toggle_mode = true
		bouton.set_pressed_no_signal(choisie)
		bouton.add_theme_font_override("font", Charte.TEXTE)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(etat, Charte.IVOIRE if choisie else Charte.IVOIRE_2)
		var fond := C.box(Charte.PANNEAU_3 if choisie else Charte.PANNEAU, Charte.IVOIRE if choisie else Charte.IVOIRE_3, 0, 8)
		fond.set_border_width_all(1)
		bouton.add_theme_stylebox_override("normal", fond)
		bouton.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Charte.IVOIRE_2, 0, 8))
		bouton.add_theme_stylebox_override("pressed", fond)
		var focus_puce := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus_puce.set_border_width_all(2)
		bouton.add_theme_stylebox_override("focus", focus_puce)
		var valeur: String = str(puce[0])
		bouton.pressed.connect(func(): _set_filter("status", valeur))
		add_child(bouton)
		D.place(bouton, Rect2(x, 204, largeur, 38))
		x += largeur + 8
	# Groupe (maquette : U21 / U18 / Tous en puces, pas en liste) puis menus déroulants à droite : poste, tri.
	var positions := {"": "Tous"}
	for p: Dictionary in (professionals if group == "professional" else roster):
		var poste := str(p.get("pos", ""))
		if not poste.is_empty(): positions[poste] = poste
	var droite := float(WIDTH)
	droite -= 360
	_picker(Rect2(droite, 204, 360, 38), "AcademyImmersiveSort", "Tri", TRIS, str(state.get("table_sort", "decide")), func(value): _sort_choice(str(value)))
	droite -= 292
	_picker(Rect2(droite, 204, 280, 38), "AcademyImmersivePosition", "Poste", positions, state.get("position", ""), func(value): _set_filter("position", value))
	var puces_groupe: Array = []
	for cle: String in ["professional", "academy", "u18", "u21"]:
		var effectif: int = professionals.size() if cle == "professional" else roster.size() if cle == "academy" else roster.filter(func(p: Dictionary): return int(p.get("age", 0)) <= 18 if cle == "u18" else (int(p.get("age", 0)) > 18 and int(p.get("age", 0)) <= 21)).size()
		var court: String = {"u21":"U21", "u18":"U18", "academy":"Tous", "professional":"Jeunes pros"}[cle]
		puces_groupe.append([cle, "%s  %d" % [court, effectif]])
	droite -= 16
	for puce: Array in puces_groupe:
		var choisi := group == str(puce[0])
		var largeur_g := Kit.largeur(str(puce[1]), 18) + 34
		droite -= largeur_g
		var bouton_g := Button.new()
		bouton_g.name = "AcademyGroup_" + str(puce[0])
		bouton_g.text = str(puce[1])
		bouton_g.accessibility_name = "Groupe : " + str(GROUPES.get(str(puce[0]), ""))
		bouton_g.focus_mode = Control.FOCUS_ALL
		bouton_g.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton_g.toggle_mode = true
		bouton_g.set_pressed_no_signal(choisi)
		bouton_g.add_theme_font_override("font", Charte.TEXTE)
		bouton_g.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton_g.add_theme_color_override(etat, Charte.IVOIRE if choisi else Charte.IVOIRE_2)
		var fond_g := C.box(Charte.PANNEAU_3 if choisi else Charte.PANNEAU, Charte.IVOIRE if choisi else Charte.IVOIRE_3, 0, 8)
		fond_g.set_border_width_all(1)
		bouton_g.add_theme_stylebox_override("normal", fond_g)
		bouton_g.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Charte.IVOIRE_2, 0, 8))
		bouton_g.add_theme_stylebox_override("pressed", fond_g)
		var focus_g := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus_g.set_border_width_all(2)
		bouton_g.add_theme_stylebox_override("focus", focus_g)
		var cle_groupe: String = puce[0]
		bouton_g.pressed.connect(func(): _set_filter("group", cle_groupe))
		add_child(bouton_g)
		D.place(bouton_g, Rect2(droite, 204, largeur_g, 38))
		if choisi: Kit.marqueur(bouton_g, Rect2(0, 0, 5, 38))
		droite -= 8

func _picker(zone: Rect2, id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> void:
	var control := OptionButton.new()
	control.name = id
	control.accessibility_name = caption
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for key: Variant in choices:
		control.add_item(caption + " : " + str(choices[key]))
		control.set_item_metadata(control.item_count - 1, key)
		if key == chosen: control.select(control.item_count - 1)
	control.item_selected.connect(func(index: int): callback.call(control.get_item_metadata(index)))
	add_child(control)
	D.place(control, zone)
	Kit.styler_liste(control)

func _set_filter(key: String, value: Variant) -> void:
	state[key] = value
	if key == "group":
		state.erase("position")
		state.erase("status")
	state.table_scroll = 0
	app._render()

func _sort_choice(key: String) -> void:
	state.table_sort = key
	state.table_descending = key in ["note", "potential"]
	state.table_scroll = 0
	app._render()

func _select_visible(people: Array) -> void:
	selected = {}
	if people.is_empty(): return
	for person: Dictionary in people:
		if person.id == state.get("player"):
			selected = person
			return
	selected = people[0]
	state.player = selected.id

# --- Tableau -----------------------------------------------------------------------------------------------------------

func _columns() -> Array:
	if active_tab == 1:
		return [{"id":"num", "titre":"#", "tri":"source", "x":22.0, "w":40.0, "align":1}, {"id":"name", "titre":"JOUEUR", "tri":"name", "x":132.0, "w":420.0, "align":0},
			{"id":"pos", "titre":"POSTE", "tri":"pos", "x":580.0, "w":200.0, "align":0}, {"id":"age", "titre":"ÂGE", "tri":"age", "x":800.0, "w":70.0, "align":2},
			{"id":"start", "titre":"NIV. EN JUILLET", "tri":"start", "x":890.0, "w":170.0, "align":2}, {"id":"note", "titre":"NIV.", "tri":"note", "x":1080.0, "w":80.0, "align":2},
			{"id":"change", "titre":"PROG. DEPUIS JUILLET", "tri":"change", "x":1180.0, "w":260.0, "align":2}, {"id":"trend", "titre":"SAISONS PASSÉES", "tri":"", "x":1480.0, "w":260.0, "align":0},
			{"id":"minutes", "titre":"MINUTES", "tri":"minutes", "x":1780.0, "w":140.0, "align":2}, {"id":"status", "titre":"STATUT", "tri":"status", "x":1950.0, "w":290.0, "align":0}]
	return [{"id":"num", "titre":"#", "tri":"source", "x":22.0, "w":40.0, "align":1}, {"id":"name", "titre":"JOUEUR", "tri":"name", "x":132.0, "w":420.0, "align":0},
		{"id":"pos", "titre":"POSTE", "tri":"pos", "x":580.0, "w":190.0, "align":0}, {"id":"age", "titre":"ÂGE", "tri":"age", "x":790.0, "w":70.0, "align":2},
		{"id":"note", "titre":"NIV.", "tri":"note", "x":880.0, "w":80.0, "align":2}, {"id":"potential", "titre":"POTENTIEL", "tri":"potential", "x":980.0, "w":150.0, "align":2},
		{"id":"change", "titre":"PROG. DEPUIS JUILLET", "tri":"change", "x":1150.0, "w":240.0, "align":2}, {"id":"minutes", "titre":"MINUTES", "tri":"minutes", "x":1420.0, "w":130.0, "align":2},
		{"id":"contract", "titre":"FIN DU CONTRAT", "tri":"contract", "x":1580.0, "w":170.0, "align":2}, {"id":"status", "titre":"STATUT", "tri":"status", "x":1790.0, "w":450.0, "align":0}]

func _col(columns: Array, id: String) -> Dictionary:
	for col: Dictionary in columns:
		if col.id == id: return col
	return {}

func _table(group: String) -> void:
	var columns := _columns()
	var panel := D.rect(self, Rect2(0, TABLE_TOP, WIDTH, HEADER_H + ROWS_H + 4), Charte.PANNEAU, 0)
	panel.name = "AcademyImmersiveTable"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var header := D.rect(panel, Rect2(0, 0, WIDTH, HEADER_H), Charte.PANNEAU_2, 0)
	header.name = "AcademyHeader"
	for col: Dictionary in columns:
		var key: String = col.tri
		if key.is_empty():
			D.text(header, col.x, 23, str(col.titre), 16, Charte.IVOIRE_2, 700, col.w)
			continue
		var tri := Button.new()
		tri.name = "AcademySort_" + key
		var actif := str(state.get("table_sort", "decide")) == key
		tri.text = str(col.titre) + ((" ↓" if state.get("table_descending", false) else " ↑") if actif else " ↕")
		tri.flat = true
		tri.alignment = HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_CENTER if col.align == 1 else HORIZONTAL_ALIGNMENT_LEFT
		tri.clip_text = true
		tri.add_theme_font_override("font", Charte.TITRE_GRAS)
		tri.add_theme_font_size_override("font_size", maxi(12, C.px(16)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: tri.add_theme_color_override(etat, Charte.IVOIRE if actif else Charte.IVOIRE_2)
		tri.add_theme_color_override("font_hover_color", Charte.IVOIRE)
		tri.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		tri.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		tri.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		tri.add_theme_stylebox_override("focus", focus)
		tri.tooltip_text = "Trier par " + str(col.titre).to_lower() + " · valeurs inconnues en dernier"
		tri.pressed.connect(_sort_by.bind(key))
		header.add_child(tri)
		D.place(tri, Rect2(col.x - 8, 0, col.w + 16, HEADER_H))
	var scroll := ScrollContainer.new()
	scroll.name = "AcademyPlayerScroll"
	scroll.mouse_force_pass_scroll_events = false
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	D.place(scroll, Rect2(0, HEADER_H, WIDTH, ROWS_H))
	rows = Control.new()
	rows.name = "AcademyImmersiveRows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.custom_minimum_size = Vector2(C.px(WIDTH), C.px(ROW * maxi(1, shown.size())))
	scroll.add_child(rows)
	_draw_rows(columns)
	scroll.get_v_scroll_bar().value_changed.connect(func(value): state.table_scroll = value)
	scroll.set_deferred("scroll_vertical", int(state.get("table_scroll", 0)))

func _source_index(person: Dictionary) -> int:
	var source: Array = professionals if _professional(person) else roster
	for index in source.size():
		if source[index].id == person.id: return index
	return -1

func _sort_value(person: Dictionary, key: String) -> Variant:
	if key in ["note", "rating", "potential"]: return G.knowledge_sort_value(person, "rating" if key == "note" else key, true)
	if key == "source": return _source_index(person)
	if key == "status": return _status(person)[0]
	if key == "decide":
		var rang := 0.0 if _a_decider(person) else 1000.0 if float(person.get("injury", 0)) <= 0 else 1500.0
		var niveau: Variant = G.knowledge_sort_value(person, "rating", true)
		return rang + 100.0 - (float(niveau) if niveau != null else 0.0)
	if key == "contract":
		var fin: Variant = person.get("contractEnd")
		return fin if fin is int or fin is float else null
	if key == "start":
		var depart: Variant = person.get("development", {}).get("seasonStart")
		return depart if depart is int or depart is float else null
	if key == "minutes":
		if pathway.get("active", false) and not _professional(person): return _path(person).get("minutes", person.get("minutes"))
		return person.get("minutes")
	if key == "change":
		var start: Variant = person.get("development", {}).get("seasonStart")
		if not (start is int or start is float) or not (person.get("rating") is int or person.get("rating") is float): return null
		return roundi(float(person.rating) - float(start))
	return person.get(key)

func _sort_by(key: String) -> void:
	state.table_descending = not state.get("table_descending", false) if state.get("table_sort", "decide") == key else key in ["note", "potential", "change"]
	state.table_sort = key
	state.table_scroll = 0
	app._render()
	U.focus(app, "AcademySort_" + key)

func _draw_rows(columns: Array) -> void:
	if shown.is_empty():
		D.text(rows, 24, 52, "Aucun jeune ne correspond.", 26, Charte.IVOIRE, 600, 1301)
		var efface := Kit.lien(rows, Rect2(24, 66, 0, 36), "Effacer les filtres →", func():
			state.erase("status"); state.erase("position"); state.erase("search")
			app._render(), "AcademyClearFilters", 19)
		efface.tooltip_text = ""
		return
	for i in shown.size():
		var p: Dictionary = shown[i]
		var status := _status(p)
		var hit := Button.new()
		hit.name = "AcademyRow_" + str(p.id).replace(":", "_")
		hit.focus_mode = Control.FOCUS_ALL
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.set_meta("development_id", p.id)
		hit.set_meta("zebra", i % 2)
		hit.accessibility_name = "%s · %s · %s" % [str(p.name), str(p.pos), str(status[0])]
		hit.tooltip_text = ""
		rows.add_child(hit)
		D.place(hit, Rect2(0, i * ROW, WIDTH, ROW))
		hit.pressed.connect(func(): _select(p))
		Kit.styler_ligne(hit, Charte.PANNEAU if i % 2 == 0 else Charte.PANNEAU_2, p.id == selected.get("id"))
		var marque := Kit.marqueur(hit, Rect2(2, 3, 6, ROW - 6))
		marque.name = "Marqueur"
		marque.visible = p.id == selected.get("id")
		_cellule(hit, _col(columns, "num"), G.n(_source_index(p) + 1), Charte.IVOIRE_2)
		_portrait(hit, p, Rect2(64, 1, 28, 28))
		_drapeau(hit, p, Rect2(98, 6, 26, 18))
		var nom := D.text(hit, 132, 21, str(p.name), 20, Charte.IVOIRE, 700, 340)
		nom.name = "AcademyNom"
		_cellule(hit, _col(columns, "pos"), str(p.pos), Charte.IVOIRE_2)
		_cellule(hit, _col(columns, "age"), G.n(p.age), Charte.IVOIRE)
		var niveau: Variant = G.knowledge_sort_value(p, "rating")
		_cellule(hit, _col(columns, "note"), G.rating_text(p, true), Charte.couleur_attribut(niveau) if niveau != null else Charte.IVOIRE_3, true)
		var potentiel: Variant = G.knowledge_sort_value(p, "potential")
		if not _col(columns, "potential").is_empty():
			var texte_pot := ("★ " if _pepite(p) else "") + G.potential_text(p)
			_cellule(hit, _col(columns, "potential"), texte_pot, Charte.couleur_attribut(potentiel) if potentiel != null else Charte.IVOIRE_3, true)
		var gain: Variant = _delta(p)
		if not _col(columns, "change").is_empty():
			var colonne_gain := _col(columns, "change")
			var mot := "—" if gain == null else ("▲ +%d" % int(gain)) if int(gain) > 0 else ("▼ %d" % int(gain)) if int(gain) < 0 else "—"
			_cellule(hit, colonne_gain, mot, Charte.V if gain != null and int(gain) > 0 else Charte.D if gain != null and int(gain) < 0 else Charte.IVOIRE_3, true)
		if not _col(columns, "start").is_empty():
			var depart: Variant = p.get("development", {}).get("seasonStart")
			_cellule(hit, _col(columns, "start"), G.n(depart) if depart is int or depart is float else "—", Charte.IVOIRE_2)
		if not _col(columns, "trend").is_empty(): _courbe(hit, p, _col(columns, "trend"))
		_cellule(hit, _col(columns, "minutes"), G.n(_minutes(p)) + " min", Charte.IVOIRE_2)
		if not _col(columns, "contract").is_empty():
			var fin: Variant = p.get("contractEnd")
			var colonne_fin := _col(columns, "contract")
			_cellule(hit, colonne_fin, G.contract_year(fin) if fin is int or fin is float else "—", Charte.IVOIRE if _a_decider(p) else Charte.IVOIRE_2)
		var colonne_statut := _col(columns, "status")
		_statut(hit, p, colonne_statut.x)
		D.line(hit, Vector2(0, ROW - 1), Vector2(WIDTH, ROW - 1), Color(Charte.FILET, .5))
		var police_nom := nom.get_theme_font("font")
		var largeur_nom: float = police_nom.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nom.get_theme_font_size("font_size")).x / C.density if police_nom != null else Kit.largeur(str(p.name), 20)
		_lien_nom(hit, p, Rect2(60, 0, 520, ROW), largeur_nom)

func _cellule(row: Control, col: Dictionary, texte: String, couleur: Color, gras: bool = false) -> void:
	if col.is_empty(): return
	var align := HORIZONTAL_ALIGNMENT_RIGHT if col.align == 2 else HORIZONTAL_ALIGNMENT_CENTER if col.align == 1 else HORIZONTAL_ALIGNMENT_LEFT
	# D.text prend le bord droit pour un texte aligné à droite et le centre pour un texte centré.
	var ancre: float = col.x + col.w if col.align == 2 else col.x + col.w / 2.0 if col.align == 1 else col.x
	var cellule := D.text(row, ancre, 21, texte, 20, couleur, 700 if gras else 500, col.w, align)
	cellule.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Statut écrit, jamais la couleur seule : puce (symbole) + mot ; une blessure s'ajoute avec sa durée.
func _statut(row: Control, p: Dictionary, x: float) -> void:
	var courant := x
	var principal := _status(p)
	if _a_decider(p):
		Kit.puce(row, Rect2(courant, 5, 20, 20), "!", Charte.IVOIRE, Charte.ENCRE)
		D.text(row, courant + 28, 21, "À décider", 20, Charte.IVOIRE, 700, 140)
		courant += 170
	var blessure := float(p.get("injury", 0))
	if blessure > 0:
		Kit.puce(row, Rect2(courant, 5, 20, 20), "✕", Charte.D, Charte.ENCRE)
		D.text(row, courant + 28, 21, "Blessé · %d sem." % ceili(blessure), 20, Charte.D, 700, 200)
		return
	if _a_decider(p): return
	var symbole := "✓" if principal[1] == Charte.V else "!" if principal[1] == Charte.N else "•"
	Kit.puce(row, Rect2(courant, 5, 20, 20), symbole, principal[1] if principal[1] != Charte.IVOIRE else Charte.IVOIRE_2, Charte.ENCRE)
	D.text(row, courant + 28, 21, str(principal[0]), 20, Charte.IVOIRE_2 if principal[1] == Charte.IVOIRE or principal[1] == Charte.V else principal[1], 600, 280)

func _delta(p: Dictionary) -> Variant:
	var baseline: Variant = p.get("development", {}).get("seasonStart")
	if not (baseline is int or baseline is float) or not (p.get("rating") is int or p.get("rating") is float): return null
	return roundi(float(p.rating) - float(baseline))

func _courbe(parent: Control, p: Dictionary, col: Dictionary) -> void:
	var history: Array = p.get("development", {}).get("history", [])
	var courbe := Trend.new()
	courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for year: Dictionary in history:
		var value: Variant = year.get("end")
		if value is float or value is int: courbe.levels.append(float(value))
	if p.get("rating") is float or p.get("rating") is int: courbe.levels.append(float(p.rating))
	if courbe.levels.size() < 2:
		D.text(parent, col.x, 21, "Historique à l’intersaison", 17, Charte.IVOIRE_3, 500, col.w)
		courbe.queue_free()
		return
	courbe.minimum = maxf(0, floorf((float(courbe.levels.min()) - 2) / 5.0) * 5.0)
	courbe.maximum = minf(100, ceilf((float(courbe.levels.max()) + 2) / 5.0) * 5.0)
	parent.add_child(courbe)
	D.place(courbe, Rect2(col.x, 4, col.w, ROW - 8))

func _select(p: Dictionary) -> void:
	state.player = p.id
	selected = p
	for i in rows.get_child_count():
		var child := rows.get_child(i)
		if not child is Button or not child.has_meta("development_id"): continue
		var actif: bool = child.get_meta("development_id", "") == p.id
		Kit.styler_ligne(child, Charte.PANNEAU if int(child.get_meta("zebra", 0)) == 0 else Charte.PANNEAU_2, actif)
		var marque := child.get_node_or_null("Marqueur") as Control
		if marque != null: marque.visible = actif
	_strip()

## Nom d'un jeune : survol (ou focus + I) = mini-fiche, clic = fiche complète ; « i » après le nom.
func _lien_nom(parent: Control, p: Dictionary, zone: Rect2, largeur_mesuree: float = -1.0) -> void:
	var id := str(p.get("id", ""))
	var pro := _professional(p)
	var cible := {"kind":"player" if pro else "academy", "id":id}
	if id.is_empty() or not app.navigation_controller.entity_available(cible): return
	var lien := Button.new()
	lien.name = "AcademyName_" + id.validate_node_name()
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	lien.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lien.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	lien.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color.TRANSPARENT, 0, 0))
	lien.add_theme_stylebox_override("pressed", C.box(Color(Charte.IVOIRE, .1), Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	lien.add_theme_stylebox_override("focus", focus)
	lien.accessibility_name = "Ouvrir la fiche · " + str(p.get("name", ""))
	lien.pressed.connect(func(): app.navigation_controller.open_entity(cible))
	parent.add_child(lien)
	var largeur: float = largeur_mesuree if largeur_mesuree > 0 else Kit.largeur(str(p.get("name", "")), 20)
	D.place(lien, Rect2(zone.position.x, 0, 72 + 70 + minf(340.0, largeur) + 8, ROW))
	MiniFiche.lier(app, lien, id, "squad" if pro else "academy")
	var taille_i := maxf(20.0, ceilf(16.0 / C.density))
	MiniFiche.icone(app, parent, Rect2(132 + minf(340.0, largeur) + 8, (ROW - taille_i) / 2.0, taille_i, taille_i), id, "squad" if pro else "academy")

func _drapeau(parent: Control, p: Dictionary, zone: Rect2) -> void:
	var facts: Variant = p.get("playerFacts")
	if not facts is Dictionary: facts = _path(p).get("playerFacts")
	if not facts is Dictionary: facts = P.player(app.model, str(p.get("id", ""))).get("playerFacts")
	if not facts is Dictionary: return
	var drapeau := Identity.flag_texture(str(facts.get("flagCode", "")))
	if drapeau == null: return
	var image := TextureRect.new()
	image.name = "AcademyDrapeau"
	image.texture = drapeau
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.tooltip_text = str(facts.get("nationality", ""))
	parent.add_child(image)
	D.place(image, zone)

# --- Décision du jeune choisi ------------------------------------------------------------------------------------------

## Raison écrite de chaque ligne de la file « À décider » (données réelles du jeune uniquement).
func _raison(p: Dictionary) -> String:
	var parts: Array[String] = []
	var niveau := G.rating_text(p, true)
	var potentiel := G.potential_text(p)
	if _a_decider(p):
		parts.append("Contrat d’espoir à trancher cette saison : %s avant qu’un autre club ne s’y intéresse." % ("le promouvoir" if development.get("promotionAvailable", false) else "décide de son avenir"))
	if _pepite(p): parts.append("Pépite : potentiel estimé %s, niveau %s." % [potentiel, niveau])
	var blessure := float(p.get("injury", 0))
	if blessure > 0: parts.append("Blessé %s ; il manque les prochains matchs." % P.plural(ceili(blessure), "semaine", "semaines"))
	var gain: Variant = _delta(p)
	if gain != null and int(gain) == 0 and int(p.get("age", 0)) >= 20: parts.append("Aucune progression cette saison à %d ans." % int(p.age))
	if parts.is_empty(): parts.append("Niveau %s, potentiel %s." % [niveau, potentiel])
	return " ".join(parts)

func _strip() -> void:
	if strip == null: return
	for enfant in strip.get_children():
		strip.remove_child(enfant)
		enfant.queue_free()
	var fond := D.rect(strip, Rect2(0, 0, WIDTH, 100), Charte.PANNEAU, 0)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected.is_empty():
		D.text(strip, 22, 58, "Choisis un jeune dans la liste pour décider de son avenir.", 20, Charte.IVOIRE_2, 600, 1400)
		return
	var p := selected
	var pro := _professional(p)
	D.text(strip, 22, 26, "DÉCISION POUR", 16, Charte.IVOIRE_2, 700, 300)
	var nom := Button.new()
	nom.name = "AcademyDecisionName"
	nom.text = str(p.name)
	nom.flat = true
	nom.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nom.focus_mode = Control.FOCUS_ALL
	nom.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.add_theme_font_size_override("font_size", maxi(12, C.px(32)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: nom.add_theme_color_override(etat, Charte.IVOIRE)
	var plat := C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	plat.content_margin_left = 0
	nom.add_theme_stylebox_override("normal", plat)
	nom.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	nom.add_theme_stylebox_override("focus", focus)
	var cible := {"kind":"player" if pro else "academy", "id":str(p.id)}
	nom.accessibility_name = "Ouvrir la fiche · " + str(p.name)
	nom.pressed.connect(func(): app.navigation_controller.open_entity(cible))
	strip.add_child(nom)
	D.place(nom, Rect2(22, 30, 480, 44))
	MiniFiche.lier(app, nom, str(p.id), "squad" if pro else "academy")
	var fin: Variant = p.get("contractEnd")
	var contrat := " · contrat d’espoir jusqu’en %s" % G.contract_year(fin) if (fin is int or fin is float) and not pro else ""
	Kit.texte(strip, 22, 92, "%s · %s ans%s" % [str(p.pos), G.n(p.age), contrat], Charte.IVOIRE_2, 520, 17)
	D.line(strip, Vector2(540, 14), Vector2(540, 86), Charte.FILET)
	if pro:
		var fiche := Kit.lien(strip, Rect2(570, 30, 0, 40), "Ouvrir sa fiche : suivi, contrat, développement →", func(): open_professional_progress(app, str(p.id)), "AcademyOpenProfessional", 19)
		fiche.tooltip_text = ""
		return
	var apercu: Dictionary = app.DevelopmentViews.contract_preview(app.model, p)
	var disponible: bool = development.get("promotionAvailable", false)
	var promouvoir := Kit.bouton_ivoire(strip, Rect2(570, 22, 300, 52), "Promouvoir" if disponible else "Premier contrat pro", func(): _confirmer_promotion(p), "AcademyPromoteSelected")
	promouvoir.set_meta("promote_id", p.id)
	promouvoir.disabled = app.waiting or not disponible
	var x := 900.0
	var termes := str(apercu.get("terms", ""))
	var restriction := str(apercu.get("restriction", ""))
	var capacite := str(apercu.get("capacity", ""))
	var texte_contrat := termes if disponible else (restriction + " " + capacite).strip_edges()
	if not texte_contrat.is_empty():
		var contrat_note := Kit.texte(strip, x, 36, texte_contrat, Charte.IVOIRE if disponible else Charte.IVOIRE_2, 760, 17)
		contrat_note.name = "AcademyContractNote"
	if not disponible:
		var effectif := Kit.lien(strip, Rect2(x, 52, 0, 34), "Voir l’effectif et les places →", func(): app._navigate("Effectif"), "AcademyOpenSquad", 18)
		effectif.tooltip_text = ""
	elif pathway.get("active", false) and not _path(p).is_empty():
		var salaires: Array = _path(p).get("promotionSalary", [])
		var offre_x := x
		for i in salaires.size():
			var annees := i + 1
			var libelle := "%d saison%s · %s" % [annees, "s" if annees > 1 else "", G.salary(salaires[i])]
			var offre := Kit.lien(strip, Rect2(offre_x, 54, 0, 34), libelle + " →", func(): _confirmer_promotion(p, annees, salaires[annees - 1]), "AcademyOfferYears" + str(annees), 18)
			offre.disabled = pathway.get("locked", false) or not pathway.get("promotionAvailable", false) or app.waiting
			offre.tooltip_text = "Premier contrat professionnel de %d saison%s" % [annees, "s" if annees > 1 else ""]
			offre_x += offre.size.x / C.density + 26
	var intake: Dictionary = app.model.get("clubLife", {}).get("academyIntake", {})
	if intake.get("available", false):
		var revue := Kit.lien(strip, Rect2(WIDTH, 30, 0, 40), "Nouvelle génération : %s à examiner (garder, libérer) →" % P.plural(int(intake.get("players", []).size()), "jeune", "jeunes"), func(): Pages.ouvrir(app, "revue"), "AcademyIntakeOpen", 19, true)
		revue.tooltip_text = ""

## Promotion : confirmation EN PLACE (jamais une fenêtre), puis la commande du moteur.
func _confirmer_promotion(p: Dictionary, annees: int = 0, salaire: Variant = null) -> void:
	if app.waiting or p.is_empty() or _professional(p): return
	var fin_saison := season + (2 if app.model.get("meta", {}).get("phase") == "ended" else 1)
	var lignes: Array = []
	var envoyer: Callable
	if annees == 0:
		lignes.append("%s rejoindra l’effectif professionnel et ajoutera %s de salaire. Fin de contrat à la fin de la saison %s." % [p.name, G.salary(p.get("salary")), G.season_label(fin_saison)])
		envoyer = func(): app._command("promote_academy", {"playerId": p.id, "confirmed": true})
	else:
		lignes.append("%s quittera le centre et ajoutera %s à la masse salariale pour %d saison%s." % [p.name, G.salary(salaire), annees, "s" if annees > 1 else ""])
		var args: Dictionary = pathway.get("context", {}).duplicate()
		args.merge({"playerId": p.id, "years": annees, "confirmed": true})
		envoyer = func(): app._command("academy_promote", args)
	var bloc := EnPlace.ouvrir(app, self, "AcademyPromoteConfirm", "Promouvoir " + str(p.name), lignes, "Confirmer la promotion", envoyer)
	D.place(bloc, Rect2(570, STRIP_TOP - 6, 1100, 10))

func _cartes() -> void:
	if cards == null: return
	for enfant in cards.get_children():
		cards.remove_child(enfant)
		enfant.queue_free()
	var file: Array = []
	for p: Dictionary in Order.ordered(roster, "decide", false, _sort_value):
		if _a_decider(p) or _pepite(p) or float(p.get("injury", 0)) > 0: file.append(p)
	var titre := Kit.titre(cards, 0, 28, "À décider avant la fin de saison", 26, 800)
	titre.name = "AcademyDecisionsTitle"
	var resume := "%s · %s" % [P.plural(_compter(roster, "decide"), "contrat d’espoir", "contrats d’espoir"), P.plural(int((app.model.get("decisions", {}).get("recruitment", {}) as Dictionary).get("places", 0)), "place pro libre", "places pro libres")]
	Kit.texte(cards, WIDTH, 26, resume + " · clic sur une carte : la décision se place sur ce jeune", Charte.IVOIRE_2, 1300, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	if file.is_empty():
		Kit.texte(cards, 0, 90, "Aucun jeune ne demande de décision pour le moment.", Charte.IVOIRE_2, 1000, 19).name = "AcademyNoDecision"
		return
	var nombre := mini(4, file.size())
	var largeur := (WIDTH - (nombre - 1) * 14.0) / maxf(1.0, float(nombre)) if nombre > 0 else 0.0
	largeur = minf(largeur, 551.0)
	for i in nombre:
		var p: Dictionary = file[i]
		var carte := Button.new()
		carte.name = "AcademyDecisionCard_" + str(p.id).validate_node_name()
		carte.flat = true
		carte.focus_mode = Control.FOCUS_ALL
		carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		carte.accessibility_name = "Décider pour %s : %s" % [str(p.name), _raison(p)]
		var fond := C.box(Charte.PANNEAU_3 if p.id == selected.get("id") else Charte.PANNEAU, Color.TRANSPARENT, 0, 0)
		carte.add_theme_stylebox_override("normal", fond)
		carte.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		carte.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		carte.add_theme_stylebox_override("focus", focus)
		carte.pressed.connect(func(): _choisir_depuis_carte(p))
		cards.add_child(carte)
		D.place(carte, Rect2(i * (largeur + 14.0), 44, largeur, 142))
		Kit.marqueur(carte, Rect2(14, 18, 8, 96), Charte.IVOIRE if p.id == selected.get("id") else Charte.IVOIRE_2)
		var entete := D.text(carte, 40, 38, "%s, %s, %s ans" % [str(p.name), str(p.pos).to_lower(), G.n(p.age)], 22, Charte.IVOIRE, 700, largeur - 60)
		entete.add_theme_font_override("font", Charte.TITRE_GRAS)
		var raison := C.wrap(_raison(p), 17, Charte.IVOIRE_2)
		carte.add_child(raison)
		D.place(raison, Rect2(40, 54, largeur - 60, 84))
		raison.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for enfant in carte.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _choisir_depuis_carte(p: Dictionary) -> void:
	# La ligne doit exister dans le tableau : le filtre qui la cacherait est levé.
	var deja_visible := shown.any(func(x: Dictionary): return x.id == p.id)
	state.player = p.id
	if not deja_visible:
		state.erase("status"); state.erase("position"); state.erase("search")
		state.group = "professional" if _professional(p) else ("u18" if int(p.get("age", 0)) <= 18 else "u21")
		app._render()
		return
	_select(p)
	_cartes()
	var index := -1
	for i in shown.size():
		if shown[i].id == p.id: index = i
	var defilement := find_child("AcademyPlayerScroll", true, false) as ScrollContainer
	if defilement != null and index >= 0:
		defilement.scroll_vertical = int(maxf(0.0, index * ROW * C.density - defilement.size.y * .5))
	var action := strip.find_child("AcademyPromoteSelected", true, false) as Control
	if action != null and not (action as Button).disabled: action.grab_focus.call_deferred()

func _pied(group: String) -> void:
	D.line(self, Vector2(0, HAUTEUR - 52), Vector2(WIDTH, HAUTEUR - 52), Charte.FILET)
	var total := (professionals if group == "professional" else roster).size()
	var libelle: String = str(GROUPES.get(group, ""))
	var tri := str(TRIS.get(str(state.get("table_sort", "decide")), "colonne choisie"))
	var texte := "%d sur %d jeunes · %s · ★ pépite : potentiel estimé ≥ 85 · tri : %s" % [shown.size(), total, libelle, tri.to_lower()]
	var compte := Kit.texte(self, 0, HAUTEUR - 18, texte, Charte.IVOIRE_2, 1300, 17)
	compte.name = "AcademyCount"
	var droite := float(WIDTH)
	for touche: Array in [["Échap", "menu"], ["I", "aperçu"]]:
		var mot: String = touche[1]
		droite -= Kit.largeur(mot, 17) + 6
		Kit.texte(self, droite, HAUTEUR - 18, mot, Charte.IVOIRE_2, 0, 17)
		var large := Kit.touche(self, droite - 8, HAUTEUR - 17, str(touche[0]), true)
		droite -= large + 22

# --- Passerelles -------------------------------------------------------------------------------------------------------

func _inactive_pathway_status() -> String:
	return "Parcours à activer" if pathway.get("available", false) else "Au calendrier des Espoirs"

func _pathways() -> void:
	var panel := D.rect(self, Rect2(0, 216, WIDTH, 980), Charte.PANNEAU, 0)
	panel.name = "AcademyPathwayPane"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.titre(panel, 24, 52, "Du centre au rugby professionnel", 30, 1200)
	Kit.texte(panel, 24, 86, Copy.notice("academy", pathway.get("description", "Choisis un Espoir pour suivre sa progression.")), Charte.IVOIRE_2, 1700, 18)
	var loans: Array = pathway.get("loans", [])
	var promoted: Array = pathway.get("promotions", [])
	var active: bool = pathway.get("active", false)
	var entries := [
		["ACADÉMIE", P.plural(roster.size(), "espoir", "espoirs"), "Meilleurs potentiels", _prospects(), func(): _open_tab(0), "AcademyStage0"],
		["PASSERELLES", P.plural(loans.size(), "prêt en cours", "prêts en cours") if active else _inactive_pathway_status(), "Joueurs en prêt", loans, func(): app._navigate("Centre"), "AcademyStage1"],
		["ÉQUIPE PREMIÈRE", P.plural(promoted.size(), "promotion", "promotions") if active else "Premiers contrats", "Joueurs promus", promoted, func(): app._navigate("Effectif"), "AcademyStage2"],
	]
	var largeur := (WIDTH - 48.0 - 2 * 24.0) / 3.0
	for i in entries.size():
		var entry: Array = entries[i]
		var x := 24.0 + i * (largeur + 24.0)
		var tuile := Button.new()
		tuile.name = str(entry[5])
		tuile.flat = true
		tuile.focus_mode = Control.FOCUS_ALL
		tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tuile.accessibility_name = "%s : %s" % [str(entry[0]), str(entry[1])]
		tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
		tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		tuile.add_theme_stylebox_override("focus", focus)
		tuile.pressed.connect(entry[4])
		panel.add_child(tuile)
		D.place(tuile, Rect2(x, 122, largeur, 104))
		Kit.marqueur(tuile, Rect2(0, 0, 8, 104), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		D.text(tuile, 34, 44, str(entry[0]), 30, Charte.IVOIRE, 700, largeur - 60).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(tuile, 34, 84, str(entry[1]) + "  →", 22, Charte.IVOIRE_2, 600, largeur - 60)
		for enfant in tuile.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.etiquette(panel, x, 270, str(entry[2]), largeur)
		var people: Array = entry[3]
		if people.is_empty():
			var legende := "Aucun dossier"
			if not active and i > 0: legende = "Disponible dans le centre" if pathway.get("available", false) else "—"
			Kit.texte(panel, x, 312, legende, Charte.IVOIRE_3, largeur, 18)
		for j in mini(8, people.size()):
			_ligne_personne(panel, people[j], Rect2(x, 288 + j * 40, largeur, 38), i == 0)
	var centre := Kit.lien(panel, Rect2(24, 650, 0, 40), "Ouvrir les parcours du centre : mentorats, prêts et détection →", func(): app._navigate("Centre"), "AcademyOpenCentre", 20)
	centre.tooltip_text = ""
	var suivi := Kit.lien(panel, Rect2(24, 698, 0, 40), "Suivre les objectifs et gains observés →", func(): Pages.ouvrir(app, "suivi"), "AcademyFollowUp", 20)
	suivi.tooltip_text = ""
	_junior(panel)

## Ligne d'un jeune des parcours : portrait, nom (fiche / mini-fiche), poste et âge, potentiel.
func _ligne_personne(parent: Control, p: Dictionary, zone: Rect2, avec_potentiel: bool) -> void:
	var ligne := D.rect(parent, zone, Charte.PANNEAU if int(zone.position.y / 40.0) % 2 == 0 else Charte.PANNEAU_2, 0)
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait(ligne, p, Rect2(6, 4, 30, 30))
	var id := str(p.get("id", ""))
	var cible := {"kind":"academy", "id":id}
	var nom_texte := str(p.get("name", "Joueur"))
	var lien: Control = null
	if not id.is_empty() and app.navigation_controller.entity_available(cible):
		var bouton := Button.new()
		bouton.name = "AcademyPathway_" + id.replace(":", "_")
		bouton.flat = true
		bouton.text = nom_texte
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(etat, Charte.IVOIRE)
		bouton.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		bouton.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .08), Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.pressed.connect(func():
			state.player = id
			app.navigation_controller.open_entity(cible))
		ligne.add_child(bouton)
		D.place(bouton, Rect2(44, 0, 300, zone.size.y))
		MiniFiche.lier(app, bouton, id, "academy")
		lien = bouton
	else:
		D.text(ligne, 44, 26, nom_texte, 22, Charte.IVOIRE, 700, 300)
	Kit.texte(ligne, 360, 26, "%s · %s ans" % [str(p.get("pos", "Carrière")), G.n(p.get("age", "—"))], Charte.IVOIRE_2, zone.size.x - 520, 17)
	if avec_potentiel:
		var potentiel: Variant = G.knowledge_sort_value(p, "potential")
		D.text(ligne, zone.size.x - 14, 27, ("★ " if _pepite(p) else "") + G.potential_text(p), 20, Charte.couleur_attribut(potentiel) if potentiel != null else Charte.IVOIRE_3, 700, 160, HORIZONTAL_ALIGNMENT_RIGHT)

func _prospects() -> Array:
	var prospects := roster.duplicate()
	prospects.sort_custom(_potential_before)
	return prospects

func _junior(parent: Control) -> void:
	var results: Array = pathway.get("results", [])
	var contexte := _inactive_pathway_status()
	if pathway.get("active", false):
		var tour := int(pathway.get("juniorRound", 0))
		var total := int(pathway.get("totalRounds", 0))
		contexte = "période %d / %d" % [mini(tour + 1, total), total] if tour < total else "périodes terminées"
	Kit.etiquette(parent, 24, 790, "Compétition junior", 600)
	var phrase := "Calendrier indépendant du championnat pro" if pathway.get("available", false) else "Suivi des Espoirs dans Formation"
	if not results.is_empty():
		var dernier: Dictionary = results[-1]
		var club: Dictionary = app.model.club
		var domicile: bool = dernier.get("home") == club.get("id")
		var adverse := _club(dernier.get("away") if domicile else dernier.get("home"))
		var score: Array = dernier.get("score", [])
		if score.size() == 2: phrase = "Dernier résultat connu · période %s · %s %s – %s %s" % [G.n(int(dernier.get("round", 0)) + 1), G.club_abbr(club), G.n(score[0 if domicile else 1]), G.n(score[1 if domicile else 0]), G.club_abbr(adverse)]
	var ligne := Kit.lien(parent, Rect2(24, 806, 0, 40), "%s · %s →" % [contexte.capitalize(), phrase], func(): app._navigate("Centre"), "AcademyJuniorCompetition", 19)
	ligne.tooltip_text = ""

# --- Encadrement -------------------------------------------------------------------------------------------------------

func _staff_page() -> void:
	var panel := D.rect(self, Rect2(0, 216, WIDTH, 980), Charte.PANNEAU, 0)
	panel.name = "AcademyStaffPane"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.titre(panel, 24, 52, "Le centre de formation", 30, 1200)
	Kit.texte(panel, 24, 86, Copy.notice("academy", pathway.get("description", "Aucune donnée d’encadrement disponible.")), Charte.IVOIRE_2, 1700, 18)
	var labels := [["Éducateurs", G.n(pathway.get("coaches", "—")), "Staff", "AcademyTileCoaches"], ["Installations", G.n(pathway.get("facilities", "—")), "Club", "AcademyTileFacilities"], ["Cohésion", G.n(pathway.get("cohesion", "—")), "Centre", "AcademyTileCohesion"]]
	var largeur := (WIDTH - 48.0 - 2 * 24.0) / 3.0
	for i in labels.size():
		var item: Array = labels[i]
		var tuile := Button.new()
		tuile.name = str(item[3])
		tuile.flat = true
		tuile.focus_mode = Control.FOCUS_ALL
		tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tuile.accessibility_name = "%s : %s" % [str(item[0]), str(item[1])]
		tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
		tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus.set_border_width_all(2)
		tuile.add_theme_stylebox_override("focus", focus)
		var destination: String = item[2]
		tuile.pressed.connect(func(): app._navigate(destination))
		panel.add_child(tuile)
		D.place(tuile, Rect2(24 + i * (largeur + 24.0), 122, largeur, 140))
		Kit.marqueur(tuile, Rect2(0, 0, 8, 140), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		D.text(tuile, 34, 40, str(item[0]).to_upper(), 16, Charte.IVOIRE_2, 700, largeur - 60)
		D.text(tuile, 34, 108, str(item[1]), 64, Charte.IVOIRE, 800, largeur - 60).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(tuile, largeur - 20, 124, "ouvrir →", 17, Charte.IVOIRE_2, 600, 160, HORIZONTAL_ALIGNMENT_RIGHT)
		for enfant in tuile.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.etiquette(panel, 24, 318, "Encadrement de l’académie", 600)
	for i in 3:
		var p: Dictionary = staff[i] if i < staff.size() else {}
		var etiquette: Array = [["Éducateurs", "Niveau " + G.n(pathway.get("coaches", "—"))], ["Installations", "Niveau " + G.n(pathway.get("facilities", "—"))], ["Cohésion du centre", G.n(pathway.get("cohesion", "—")) + " / 100"]][i]
		var ligne := Button.new()
		ligne.name = "AcademyStaffRow" + str(i)
		ligne.flat = true
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ligne.accessibility_name = "%s : %s" % [str(p.get("name", etiquette[0])), str(p.get("role", etiquette[1]))]
		ligne.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU if i % 2 == 0 else Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
		ligne.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		var focus_ligne := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
		focus_ligne.set_border_width_all(2)
		ligne.add_theme_stylebox_override("focus", focus_ligne)
		ligne.pressed.connect(func(): app._navigate("Staff"))
		panel.add_child(ligne)
		D.place(ligne, Rect2(24, 336 + i * 64, 1100, 60))
		_portrait(ligne, p, Rect2(8, 6, 48, 48), false, ["training-coach", "mail-trainer", "mail-medical"][i])
		D.text(ligne, 72, 28, str(p.get("name", etiquette[0])), 24, Charte.IVOIRE, 700, 700)
		D.text(ligne, 72, 52, str(p.get("role", etiquette[1])), 18, Charte.IVOIRE_2, 500, 700)
		for enfant in ligne.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gerer := Kit.lien(panel, Rect2(24, 560, 0, 40), "Gérer le centre →", func(): app._navigate("Centre"), "AcademyManageCentre", 20)
	gerer.tooltip_text = ""
	var suivi := Kit.lien(panel, Rect2(24, 608, 0, 40), "Suivi des jeunes →", func(): Pages.ouvrir(app, "suivi"), "AcademyFollowUp", 20)
	suivi.tooltip_text = ""
	var equipe := Kit.lien(panel, Rect2(24, 656, 0, 40), "Ouvrir le staff →", func(): app._navigate("Staff"), "AcademyOpenStaff", 20)
	equipe.tooltip_text = ""

func _academy_staff() -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if team.get("id") != app.model.get("club", {}).get("id"): continue
		var members: Array = team.get("members", [])
		return members.filter(func(p: Dictionary):
			var role := str(p.get("role", "")).to_lower()
			return role.contains("espoir") or role.contains("formation") or role.contains("académie") or role.contains("junior"))
	return []

func _club(club_id: Variant) -> Dictionary:
	for entry: Dictionary in app.model.get("meta", {}).get("catalogue", []):
		if entry.get("id") == club_id: return entry
	return {"name":"Centre", "abbr":"Centre", "color":"#436859"}

# --- Outils ------------------------------------------------------------------------------------------------------------

static func professional_progress(app: Control, player_id: String) -> Dictionary:
	var people: Array = app.model.get("decisions", {}).get("development", {}).get("professionals", [])
	for person: Dictionary in people:
		if str(person.id) == player_id: return person
	return {}

## Suivi individuel d'un jeune professionnel : onglet Développement de sa fiche complète (plus de fenêtre).
static func open_professional_progress(app: Control, player_id: String, _source_id: String = "") -> void:
	if professional_progress(app, player_id).is_empty(): return
	app.management_ui.immersive_player_tab = 4
	if not app.navigation_controller.open_entity({"kind":"player", "id":player_id}):
		app.selected_player = player_id
		app.set_meta("immersive08_full_player", true)
		app._render()
	U.focus(app, "FullPlayerTab4")

## Liste déroulante de la charte (utilisée aussi par la fiche complète : spécialisation).
static func _option(id: String, caption: String, choices: Dictionary, chosen: Variant, callback: Callable) -> OptionButton:
	var control := OptionButton.new()
	control.name = id
	control.accessibility_name = caption
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for key: Variant in choices:
		control.add_item(caption + " : " + str(choices[key]))
		control.set_item_metadata(control.item_count - 1, key)
		if key == chosen: control.select(control.item_count - 1)
	control.item_selected.connect(func(index: int): callback.call(control.get_item_metadata(index)))
	Kit.styler_liste(control)
	return control

func _minutes(p: Dictionary) -> Variant:
	if pathway.get("active", false) and not _professional(p): return _path(p).get("minutes", p.get("minutes", 0))
	return p.get("minutes", 0)

func _path(p: Dictionary) -> Dictionary:
	return academy_by_id.get(p.get("id", ""), {})

func _professional(p: Dictionary) -> bool:
	return p in professionals

## [mot, couleur] du statut principal (un mot toujours écrit à côté de la couleur).
func _status(p: Dictionary) -> Array:
	var info := _path(p)
	if float(p.get("injury", 0)) > 0: return ["Blessé", Charte.D]
	if float(p.get("condition", 100)) < 70: return ["Condition à surveiller", Charte.N]
	if _professional(p): return ["Jeune professionnel", Charte.IVOIRE]
	if info.get("path") == "professionnel": return ["Parcours professionnel", Charte.V]
	if float(info.get("target", 0)) > 0 and float(info.get("minutes", 0)) >= float(info.target): return ["Objectif atteint", Charte.V]
	return ["En formation", Charte.V]

func _portrait(parent: Node, p: Dictionary, rectangle: Rect2, _large: bool = false, fallback: String = "") -> void:
	if not str(p.get("id", "")).is_empty():
		var portrait := G.portrait(int(p.get("portraitIndex", 0)), 0, p)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		parent.add_child(portrait)
		D.place(portrait, rectangle)
	elif not fallback.is_empty():
		D.photo(parent, fallback, rectangle)
	else:
		var id := str(p.get("id", ""))
		var from_squad := P.player(app.model, id)
		var index := int(from_squad.get("portraitIndex", p.get("portraitIndex", id.hash())))
		D.photo(parent, "player-%02d" % posmod(index, 16), rectangle)

static func _potential_before(a: Dictionary, b: Dictionary) -> bool:
	var av: Variant = G.knowledge_sort_value(a, "potential")
	var bv: Variant = G.knowledge_sort_value(b, "potential")
	if av == null or bv == null:
		if av != bv: return av != null
	elif av != bv: return av > bv
	return str(a.get("id", "")) < str(b.get("id", ""))
