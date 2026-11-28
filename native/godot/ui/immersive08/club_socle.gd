extends RefCounted
## Socle de l'écran Club (club_canvas.gd) : préchargements, constantes, outils communs (coche, liens, bandeau, pied de carte).
const EntityLink = preload("res://ui/entity_link.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Palmares = preload("res://ui/immersive08/palmares_text.gd")
const G = preload("res://ui/game_skin.gd")
const ClubViews = preload("res://ui/club_views.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const History = preload("res://ui/club_memory_view.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Strategy = preload("res://ui/strategy_view.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const HistoireVisuels = preload("res://ui/immersive08/histoire_visuels.gd")
const Pages = preload("res://ui/immersive08/club_pages.gd")
const Habillage = preload("res://ui/immersive08/recruitment_pages.gd")
const Etat = preload("res://ui/management_state.gd")
const StaffTable = preload("res://ui/staff_career_view.gd")
const ConseilLettre = preload("res://ui/immersive08/conseil_lettre.gd")
const ConseilJeu = preload("res://ui/immersive08/conseil_jeu.gd")
const StaffServices = preload("res://ui/immersive08/staff_services.gd")
## Organigramme du club en cercles (planche du 24/11/2026, organigramme.gd).
const Organigramme = preload("res://ui/immersive08/organigramme.gd")
const KEY = "immersive08_club_tab"
const GOALS = {"wins":"Victoires", "points":"Points", "rank":"Place au classement", "cash":"Trésorerie"}
const GOAL_STATUS = {"pending":"À suivre", "met":"Atteint", "missed":"Manqué", "unverified":"Non vérifié"}
const W := 2248.0
const TOP := 132.0
const HAUT := 1244.0
## « Notre jeu » : avis du conseil sur notre style (revue FM27 n° 31, conseil_jeu.gd).
const TABS := [["overview", "Vue d’ensemble"], ["jeu", "Notre jeu"], ["direction", "Direction"], ["infrastructure", "Infrastructures"], ["staff", "Staff"], ["organigramme", "Organigramme"], ["history", "Histoire"]]
const LIGNE := 32.0

## Case dessinée de la charte : coche (ok), point d'exclamation (alerte), croix (menace), tiret (neutre). Le sens est
## dans la forme, jamais dans la couleur seule.
class Coche extends Control:
	var genre := "ok"
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var s := minf(size.x, size.y)
		draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)).grow(-1.0), couleur, false, maxf(1.5, s * .08))
		var w := maxf(1.5, s * .1)
		match genre:
			"ok": draw_polyline(PackedVector2Array([Vector2(s * .24, s * .54), Vector2(s * .44, s * .74), Vector2(s * .78, s * .28)]), couleur, w)
			"croix":
				draw_line(Vector2(s * .28, s * .28), Vector2(s * .72, s * .72), couleur, w)
				draw_line(Vector2(s * .72, s * .28), Vector2(s * .28, s * .72), couleur, w)
			"alerte":
				draw_line(Vector2(s * .5, s * .2), Vector2(s * .5, s * .6), couleur, w)
				draw_rect(Rect2(s * .44, s * .7, s * .12, s * .12), couleur)
			_: draw_line(Vector2(s * .28, s * .5), Vector2(s * .72, s * .5), couleur, w)

## Entier avec espace fine-insécable (« 19 500 ») : lisible sans décimale ni point.
static func _milliers(valeur: Variant) -> String:
	if not (valeur is int or valeur is float): return str(valeur)
	var chiffres := str(absi(int(valeur)))
	var groupe := ""
	for index in chiffres.length():
		if index > 0 and (chiffres.length() - index) % 3 == 0: groupe += " "
		groupe += chiffres[index]
	return ("−" if int(valeur) < 0 else "") + groupe

static func _coche(parent: Control, zone: Rect2, genre: String, couleur: Color = Charte.IVOIRE) -> Coche:
	var forme := Coche.new()
	forme.genre = genre
	forme.couleur = couleur
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(forme)
	D.place(forme, zone)
	return forme

static func _navigation(app: Control) -> Node:
	for field: Dictionary in app.get_property_list():
		if field.name == "navigation_controller": return app.get("navigation_controller") as Node
	return null

static func _reading_area(app: Control, parent: Control, rectangle: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	var navigation := _navigation(app)
	if not is_instance_valid(navigation) or not navigation.has_method("entity_available") or not navigation.entity_available(target): return null
	var button := Button.new()
	button.name = id
	button.flat = true
	button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	button.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	EntityLink.bind(button, app, target, caption)
	button.tooltip_text = ""
	parent.add_child(button)
	D.place(button, rectangle)
	return button

## Président du conseil, lu dans les données du club quand elles le publient (jamais figé dans le code).
static func _president(app: Control) -> String:
	var sources: Array = [app.model.get("club", {}), app.model.get("clubLife", {}), U.strategy(app.model).get("board", {})]
	for source: Variant in sources:
		if not source is Dictionary: continue
		var valeur: Variant = source.get("president")
		if valeur is Dictionary and not str(valeur.get("name", "")).strip_edges().is_empty(): return str(valeur.name).strip_edges()
		if valeur is String and not valeur.strip_edges().is_empty(): return valeur.strip_edges()
	return ""

static func _sous_titre(app: Control) -> String:
	var identite := G.identity(app.model.club)
	var fans: Dictionary = U.strategy(app.model).get("fans", {})
	var parts: Array[String] = []
	var stade := str(identite.get("stadium", "")).strip_edges()
	if not stade.is_empty(): parts.append(stade)
	if fans.has("capacity"): parts.append(_milliers(fans.capacity) + " places")
	var histoire: Variant = identite.get("history")
	if histoire is Dictionary and histoire.has("founded"): parts.append("fondé en %d" % int(histoire.founded))
	var president := _president(app)
	if not president.is_empty(): parts.append("conseil présidé par " + president)
	return " · ".join(parts)

static func _tab(app: Control, key: String, id: String = "") -> void:
	if key == "direction" or key == "staff":
		app.management_ui.erase("club_page")
		app._navigate("Stratégie" if key == "direction" else "Staff")
		return
	app.management_ui.erase("club_page")
	app.management_ui[KEY] = key
	app.management_ui.club_tab = 1 if key == "history" else 0
	if app.route != "Club": app._navigate("Club")
	else: U.select(app, KEY, key, id)

static func _open_strategy(app: Control, index: int) -> void:
	app.management_ui.immersive08_strategy_tab = index
	app._navigate("Stratégie")

# --- Vue d'ensemble ------------------------------------------------------------------------------------------------------

static func _panneau(parent: Control, zone: Rect2, titre: String, id: String, filet: bool = false) -> Panel:
	# Charte §3 : panneau de page rayon 18 px (24 en référence 2560, comme D.panel), sans bordure.
	var panneau := D.rect(parent, zone, Charte.PANNEAU, 24)
	panneau.name = id
	panneau.mouse_filter = Control.MOUSE_FILTER_PASS
	var entete := Kit.titre(panneau, 24, 40, titre, 28, zone.size.x - 300)
	entete.name = "CardTitle"
	if filet: D.line(panneau, Vector2(18, 56), Vector2(zone.size.x - 18, 56), Charte.FILET)
	return panneau

static func _signe(valeur: int) -> String:
	return "+%d" % valeur if valeur > 0 else ("−%d" % absi(valeur) if valeur < 0 else "0")

static func _texte_lignes(parent: Control, x: float, haut: float, largeur: float, valeur: String, taille: int, police: Font, couleur: Color, lignes: int) -> Label:
	var label := C.label(valeur, taille, couleur, false, 700)
	label.add_theme_font_override("font", police)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = lignes
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	D.place(label, Rect2(x, haut, largeur, taille * 1.32 * lignes + 4))
	return label

static func _lien(parent: Control, zone: Rect2, texte: String, action: Callable, id: String, taille: int = 19) -> Button:
	var bouton := Kit.lien(parent, zone, texte, action, id, taille)
	bouton.tooltip_text = ""
	return bouton

static func _academy(model: Dictionary) -> Dictionary:
	return model.get("clubLife", {}).get("academyPathways", {})

## Trésorerie et salaires : deux liens vers Finances (valeurs du moteur ; texte simple si la navigation est indisponible).
static func _footer(card: Panel, app: Control, finance: Dictionary, _board: Dictionary) -> void:
	var cash: Variant = finance.get("cash", app.model.get("club", {}).get("cash"))
	var largeur := card.size.x / C.density
	var texte_cash := "Trésorerie · " + U.amount(cash) + " →"
	var etiquette := Kit.texte(card, 30, 372, texte_cash, Charte.D if cash != null and float(cash) < 0.0 else Charte.IVOIRE, 500, 19)
	etiquette.add_theme_font_override("font", Kit.texte_gras())
	var lien_cash := _reading_area(app, card, Rect2(24, 346, 520, 40), {"kind": "finance", "id": "cash"}, "ClubCashLink", "Trésorerie")
	# Mini-courbe de la trésorerie au survol (choix de Léo, 21/11/2026).
	if lien_cash != null: preload("res://ui/mini_courbe_survol.gd").lier(app, lien_cash, "cash", "Trésorerie")
	var salaires := "Salaires et cotisations · %s par semaine →" % G.euros(P.payroll(app.model).charge_weekly)
	var etiquette_salaires := Kit.texte(card, 30, 410, salaires, Charte.IVOIRE, 760, 19)
	etiquette_salaires.add_theme_font_override("font", Kit.texte_gras())
	_reading_area(app, card, Rect2(24, 384, largeur - 48, 40), {"kind": "finance", "id": "wages"}, "ClubWagesLink", "Salaires")

# --- Vestiaire -----------------------------------------------------------------------------------------------------------

## Bandeau du club : onglet Infrastructures -> le stade du club à sa taille (banque d'images, d'après la capacité),
## sinon la vue habituelle.
static func photo_entete(model: Dictionary, tab: String) -> String:
	if tab != "infrastructure":
		var sol := BanqueImages.region(G.identity(model.get("club", {})))
		return sol if not sol.is_empty() and BanqueImages.texture(sol) != null else "club-forest"
	var fans: Variant = U.strategy(model).get("fans", {})
	var niveau := BanqueImages.niveau_stade(fans.get("capacity") if fans is Dictionary else null)
	var id := BanqueImages.choisir("infrastructures", {"categorie_image": "stade", "niveau_infrastructure": niveau}) if niveau > 0 else ""
	return id if not id.is_empty() and BanqueImages.texture(id) != null else "club-forest"

static func _segments(parent: Control, x: float, y: float, largeur: float, total: int, rempli: int) -> void:
	var ecart := 3.0
	var part := (largeur - ecart * (total - 1)) / total
	for i in total: D.rect(parent, Rect2(x + i * (part + ecart), y, part, 10), Charte.IVOIRE_2 if i < rempli else Charte.PANNEAU_3, 0)

static func _venue_caption(picture: Control) -> String:
	match picture.get_meta("photo_kind", ""):
		# Immersion : le crédit, jamais la provenance (pack, archive).
		"pack", "archive": return "Crédit photo"
		_: return "Vue du club"

static func _venue_credit(control: Control, photo: Dictionary) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.tooltip_text = "%s\nSource : %s\nLicence : %s" % [photo.get("credit", ""), photo.get("source", ""), photo.get("license", "")]
	control.accessibility_name = control.tooltip_text

static func _members(app: Control) -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id",-1)) == int(app.model.club.id): return team.get("members", [])
	return []
