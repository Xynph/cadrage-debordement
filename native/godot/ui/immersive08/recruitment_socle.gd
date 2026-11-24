extends Control
## Écran Recrutement, socle (découpe de recruitment_canvas.gd, sans changement) : constantes, état partagé, petites aides en statiques, actions de navigation.
## Chaîne d'héritage : socle ← en-tête, besoins et onglets ← filtres ← coût de l'offre ← lignes ← tableau ← recruitment_canvas.gd (fichier public).
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const Decisions = preload("res://ui/decision_views.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Link = preload("res://ui/entity_link.gd")
const Sort = preload("res://ui/recruitment_sort.gd")
const Budget = preload("res://ui/transfer_budget.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const SalesView = preload("res://ui/player_sales_view.gd")
const Observation = preload("res://ui/player_observation.gd")
const Identity = preload("res://ui/player_identity.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const Attributs = preload("res://ui/player_attributes.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
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
## Marge sous la dernière ligne : elle reste entière et loin des coins arrondis du panneau en fin de défilement.
const BAS_TABLEAU := 22.0
const COST_TOP := 1020.0
## Bandeau des filtres (demande de Léo du 21/11/2026) : sous les onglets, filtres puis pastilles de poste, détouré.
const Y_BANDEAU := 294.0
const Y_FILTRES := Y_BANDEAU + 10.0
const TABS := ["Besoins du club", "Recherche", "Joueurs suivis", "Rapports"]
const WEEKS_PER_YEAR := 52

var app: Control
var state: Dictionary
var data: Dictionary
var tab := 0
var report_by_player := {}
var _generation := 0
var table_rows: Control
var count: Control
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
## Le tableau descend sous la rangée des pastilles de poste (choix de Léo du 21/11/2026).
var _dy := 0.0
func _club(player: Dictionary) -> String:
	for key in ["clubName", "club"]:
		var valeur: Variant = player.get(key)
		if valeur is String and not valeur.strip_edges().is_empty(): return valeur
		if valeur is Dictionary and str(valeur.get("name", "")) != "": return str(valeur.name)
	return ""

var _results_count := 0

func _observed(player: Dictionary) -> bool:
	return str(player.get("knowledge", {}).get("stage", "")) in ["observed", "deep"] or report_by_player.has(str(player.get("id", "")))

func _sort_column() -> String:
	return str(state.get("report_sort", "Date du rapport")) if tab == 3 else str(state.get("sort", "Poste"))

func _sort_descending() -> bool:
	return bool(state.get("report_descending", true)) if tab == 3 else bool(state.get("descending", false))

func _col(id: String) -> Dictionary:
	for col: Dictionary in columns:
		if col.id == id: return col
	return {}

func _approcher(player: Dictionary) -> void:
	Pages.ouvrir(app, "negociation", {"player_id": str(player.get("id", ""))})

# --- Divers -----------------------------------------------------------------------------------------------------

## Recherche ciblée du recruteur (petite fenêtre) : poste pré-choisi d'après un besoin.
func _recherche(role: String = "") -> void:
	load("res://ui/immersive08/recherche_ciblee.gd").ouvrir(app, self, role)

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
	link.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
	link.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .06), Color(Charte.IVOIRE, .5), 8, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
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

## Montant court pour une tuile : 43 680 € → « 43,7 k€ », 5 000 € → « 5 k€ », 1 200 000 € → « 1,2 M€ ».
static func _compact(valeur: int) -> String:
	var absolu := absf(float(valeur))
	if absolu >= 1000000.0: return ("%.1f" % (absolu / 1000000.0)).replace(".", ",").trim_suffix(",0") + " M€"
	if absolu >= 1000.0: return ("%.1f" % (absolu / 1000.0)).replace(".", ",").trim_suffix(",0") + " k€"
	return "%d €" % int(absolu)

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

## Reconstruit la liste, les tuiles et le coût : défini dans recruitment_tableau.gd ; ce vide laisse les couches du dessous l'appeler.
func _refresh() -> void: pass
