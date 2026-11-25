extends Control
## Après-match (apres_match.gd), morceau : préchargements, dessin de la charte (`Trace`), variables, lecture du modèle du direct (issue, compétition, clubs) et petits formats de texte.
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.
## `_reconstruire` n'y est qu'un point d'entrée vide : la vraie construction vit dans apres_match.gd (qui la redéfinit).

const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const PORTRAIT = preload("res://guide/assets/coach-poses.png")
const MATTE = preload("res://guide/coach_matte.gdshader")

## Dessin de la charte finale : forme arrondie droite (`pave` : écusson et sigle de club à 6 px, pastille V/N/D et bouton
## doré en pilule, liseré) ou triangle (▲ ▼ : aucune police du jeu n'a ces glyphes), avec un contour facultatif.
class Trace extends Control:
	var forme := "pave"
	var couleur := Color.WHITE
	var bord := Color(0, 0, 0, 0)
	## Rayon des coins ; négatif : pilule (demi-hauteur).
	var rayon := -1.0
	var epaisseur := 2.0
	func _init(f: String = "pave", c: Color = Color.WHITE, r: float = -1.0) -> void:
		forme = f
		couleur = c
		rayon = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 1 or r.size.y < 1: return
		match forme:
			"haut": draw_colored_polygon(PackedVector2Array([Vector2(r.size.x / 2.0, 0), r.end, Vector2(0, r.end.y)]), couleur)
			"bas": draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(r.end.x, 0), Vector2(r.size.x / 2.0, r.end.y)]), couleur)
			_:
				var s := StyleBoxFlat.new()
				s.bg_color = couleur
				s.draw_center = couleur.a > 0.0
				s.set_corner_radius_all(roundi(minf(r.size.x, r.size.y) / 2.0 if rayon < 0.0 else rayon))
				s.border_color = bord
				s.set_border_width_all(roundi(epaisseur) if bord.a > 0.0 else 0)
				s.anti_aliasing = true
				draw_style_box(s, r)

var app: Control
var director: Node
var model: Dictionary = {}
## Sous-page « Voir plus » (statistiques, notes de ton XV, journal) à la place du verdict, avec retour.
var detail := false
var bouton_valider: Button
var _cle := ""
var _e := 1.0
var _clubs: Dictionary = {}
var _droite: VBoxContainer
var _ta_place: Control
var _autres: Control
static var _gras: FontVariation

## DM Sans graisse 700 : les valeurs des lignes d'information (classement, essais).
static func texte_gras() -> Font:
	if _gras == null:
		_gras = FontVariation.new()
		_gras.base_font = Charte.TEXTE
		_gras.variation_opentype = {"wght": 700}
	return _gras

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func _direct() -> Dictionary:
	var live := _live()
	return live.get("direct", {}) if live.get("direct") is Dictionary else {}

func _camp() -> int:
	var camp := int(_direct().get("camp", -1))
	if camp in [0, 1]: return camp
	var equipes: Array = _live().get("teams", [])
	var nous: Variant = model.get("club", {}).get("id") if model.get("club") is Dictionary else null
	for k in mini(2, equipes.size()):
		if equipes[k] is Dictionary and nous != null and equipes[k].get("id") == nous: return k
	return 0

## « victoire », « defaite » ou « nul » (le moteur le dit dans `pourquoi.issue`, sinon le score).
func issue() -> String:
	var bloc: Variant = _direct().get("pourquoi")
	if bloc is Dictionary and str(bloc.get("issue", "")) in ["victoire", "defaite", "nul"]: return str(bloc.issue)
	var score: Array = _live().get("score", [0, 0])
	var c := _camp()
	if score.size() < 2: return "nul"
	return "victoire" if int(score[c]) > int(score[1 - c]) else ("defaite" if int(score[c]) < int(score[1 - c]) else "nul")

func _journee() -> Dictionary:
	var j: Variant = _direct().get("journee")
	return j if j is Dictionary else {}

func _classement() -> Array:
	var c: Variant = _journee().get("classement")
	return c if c is Array else []

func _fixture() -> Dictionary:
	var next: Variant = model.get("next")
	return next if next is Dictionary else {}

## Compétition de la rencontre (projection `leagues` du modèle), {} si inconnue.
func _ligue() -> Dictionary:
	var id := str(_fixture().get("competitionId", model.get("meta", {}).get("leagueId", "")))
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary and str(ligue.get("id", "")) == id: return ligue
	return {}

func _nom_competition() -> String:
	var ligue := _ligue()
	if not ligue.is_empty(): return str(ligue.get("name", ""))
	return str(_fixture().get("label", "")).get_slice(" · ", 0)

## Étape de la rencontre (« Journée 9 ») lue dans son libellé.
func _etape() -> String:
	var label := str(_fixture().get("label", ""))
	var competition := _nom_competition()
	if label.is_empty(): return ""
	return label.trim_prefix(competition + " · ") if label.begins_with(competition + " · ") else ""

## « J9 » depuis « Journée 9 », sinon l'étape telle quelle.
func _etape_courte() -> String:
	var m := RegEx.create_from_string("(\\d+)").search(_etape())
	return "J" + m.get_string(1) if m != null and _etape().to_lower().begins_with("journ") else _etape()

func _club(id: Variant) -> Dictionary:
	return _clubs.get(_cle_id(id), {})

static func _cle_id(id: Variant) -> String:
	return str(int(id)) if id is float or id is int else str(id)

func _indexer_clubs() -> void:
	_clubs = {}
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary:
			for club: Variant in ligue.get("rows", []):
				if club is Dictionary and club.get("id") != null: _clubs[_cle_id(club.id)] = club
	for club: Variant in (model.get("league", []) if model.get("league") is Array else []):
		if club is Dictionary and club.get("id") != null and not _clubs.has(_cle_id(club.id)): _clubs[_cle_id(club.id)] = club
	for club: Variant in _live().get("teams", []):
		if club is Dictionary and club.get("id") != null: _clubs[_cle_id(club.id)] = club

## Vraie couleur du club (identité), sinon neutre.
func _couleur(club: Dictionary) -> Color:
	var texte := str(G.identity(club).get("color", club.get("color", "")))
	if texte.begins_with("#") and (texte.length() == 7 or texte.length() == 9): return Color(texte)
	return Color(0, 0, 0, 0)

static func ordinal(rang: int) -> String:
	return "1er" if rang == 1 else "%de" % rang

static func signe(n: int) -> String:
	return ("+%d" % n) if n > 0 else ("−%d" % -n if n < 0 else "0")

static func note_texte(note: Variant) -> String:
	return ("%.1f" % float(note)).replace(".", ",") if note is float or note is int else ""

func _reconstruire() -> void: pass

## Navigation au clavier en cours (dernière entrée : une touche), pour le cadre de focus du bouton or.
var clavier := false
