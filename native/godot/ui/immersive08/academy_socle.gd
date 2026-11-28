extends Control
## Écran Formation, socle (découpe de academy_canvas.gd, sans changement) : constantes, état partagé, courbe de niveau, lecture des jeunes et outils (statiques).
## Chaîne d’héritage : socle ← filtres ← en-tête ← décision ← tableau ← passerelles ← encadrement ← academy_canvas.gd (fichier public).
const Notation = preload("res://ui/notation_staff.gd")
const Fleches = preload("res://ui/fleches_progression.gd")
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
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Identity = preload("res://ui/player_identity.gd")
const Words = preload("res://ui/management_state.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const TABS = ["Effectif", "Progression", "Passerelles", "Encadrement"]
const GROUPES := {"u21":"U21", "u18":"U18", "academy":"Tous les Espoirs", "professional":"Jeunes professionnels"}
const TRIS := {"decide":"À décider d’abord", "note":"Niveau", "potential":"Potentiel", "age":"Âge", "name":"Nom"}
const WIDTH := 2248
const HAUTEUR := 1250
## Ligne de 34 unités et pastilles de 32 : mêmes tailles que l'Effectif (écart du vérificateur, 25/11) ; DY recentre le
## contenu dessiné pour l'ancienne ligne de 30.
const ROW := 34.0
const DY := 2.0
const PASTILLE := 32.0
const HEADER_H := 34.0
const TABLE_TOP := 258.0
const ROWS_H := 610.0
## Marge sous la dernière ligne : elle reste entière et loin des coins arrondis du panneau en fin de défilement.
const BAS_TABLEAU := 22.0
const STRIP_TOP := 924.0
const CARTES_TOP := 1054.0

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

func _source_index(person: Dictionary) -> int:
	var source: Array = professionals if _professional(person) else roster
	for index in source.size():
		if source[index].id == person.id: return index
	return -1

func _sort_value(person: Dictionary, key: String) -> Variant:
	if key in ["note", "rating", "potential"]: return Notation.tri_champ(person, "rating" if key == "note" else key, true, app.model)
	if key == "source": return _source_index(person)
	if key == "status": return _status(person)[0]
	if key == "decide":
		var rang := 0.0 if _a_decider(person) else 1000.0 if float(person.get("injury", 0)) <= 0 else 1500.0
		var niveau: Variant = Notation.tri_champ(person, "rating", true, app.model)
		return rang + 100.0 - (float(niveau) * 5.0 if niveau != null else 0.0)
	if key == "contract":
		var fin: Variant = person.get("contractEnd")
		return fin if fin is int or fin is float else null
	if key == "start":
		var r := Notation.rang_lettre(_lettre_juillet(person))
		return r if r >= 0.0 else null
	if key == "minutes":
		if pathway.get("active", false) and not _professional(person): return _path(person).get("minutes", person.get("minutes"))
		return person.get("minutes")
	if key == "change": return _delta(person)
	return person.get(key)

## Niveau de début de saison (juillet) en lettre du staff : même erreur fixe, même référence et même calage sur le
## Niveau calculé que la colonne NIV.
func _lettre_juillet(p: Dictionary) -> Dictionary:
	var depart: Variant = p.get("development", {}).get("seasonStart")
	if not (depart is int or depart is float): return {"bas": -1, "haut": -1}
	return Notation.lettre_note(app.model, p, float(depart) + Notation.decalage_niveau(p), true, "niveau")

## Progression depuis juillet en crans de lettre MONTRÉS (▲/▼ seulement à l'écran) ; null si inconnue.
func _delta(p: Dictionary) -> Variant:
	var avant := Notation.rang_lettre(_lettre_juillet(p))
	var maintenant := Notation.rang_lettre(Notation.lettre_champ(p, "rating", true, app.model))
	if avant < 0.0 or maintenant < 0.0: return null
	return roundi(maintenant - avant)

static func _ignorer_souris(noeud: Node) -> void:
	for enfant in noeud.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorer_souris(enfant)

## « 2027-2028 » → « 2027-28 ».
static func _saison_courte(valeur: Variant) -> String:
	var libelle := G.season_label(valeur)
	var morceaux := libelle.split("-")
	if morceaux.size() == 2 and morceaux[1].length() == 4: return "%s-%s" % [morceaux[0], morceaux[1].substr(2)]
	return libelle

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
	# Ordre de la lettre de potentiel montrée ; à lettre égale, identifiant (jamais le chiffre caché).
	var av: Variant = Notation.tri_champ(a, "potential", true)
	var bv: Variant = Notation.tri_champ(b, "potential", true)
	if av == null or bv == null:
		if av != bv: return av != null
	elif av != bv: return av > bv
	return str(a.get("id", "")) < str(b.get("id", ""))
