extends PanelContainer
## Écran « Avant-match » (voir match_avant.gd) — Socle : préchargements, constantes, variables, outils de texte et de date, construction, navigation entre sous-pages et rafraîchissement.

const C = preload("res://ui/immersive08/components.gd")
const CarteClub = preload("res://ui/carte_club_survol.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const Present = preload("res://ui/immersive08/projection.gd")
const MeteoTexte = preload("res://ui/contextual/meteo_texte.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Pages = preload("res://ui/immersive08/avant_match_pages.gd")
const Reperes = preload("res://ui/immersive08/reperes.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const RI = preload("res://ui/contextual/rooms/room_identity.gd")
const Bilan = preload("res://ui/immersive08/avant_match_bilan.gd")
const FaceAFace = preload("res://ui/immersive08/avant_match_terrain.gd")
const Tests = preload("res://ui/immersive08/tests_physiques.gd")
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const JOURS := ["DIM.", "LUN.", "MAR.", "MER.", "JEU.", "VEN.", "SAM."]
## Photo du tunnel selon la météo annoncée (forte pluie > pluie > vent > chaleur > sec ; sans annonce : neutre).
## Variante absente du jeu : la photo d'origine (pluie fine).
const PHOTO_ORIGINE := "match-tunnel"
## Verrou d'ouverture (fiche UX 12 §7) : Entrée et Espace sont ignorés pendant cette durée après l'ouverture.
const VERROU_SECONDES := 0.5
## Deux couleurs de club plus proches que cela (distance RVB) : l'adversaire passe en anneau ivoire.
const CLUBS_PROCHES := 0.22
## Seuil de condition d'un titulaire (en %).
const CONDITION_MINI := 80

var app: Control
var kickoff: Button
var delegate: Button
var status: Label
var match_date: Label
var content: VBoxContainer
var _key := ""
var _model: Dictionary = {}
var _play: Button
var _raison: Label
var _indice: Label
var _ouvert_a := 0
var _page_ouverte := ""

## Pixels d'un écran 1080p, à la densité courante (1080p : 1 pour 1).
static func M(value: float) -> int:
	return roundi(value * C.density / 0.75)

static func texte(value: Variant, size: float, color: Color = C.IVORY, display: bool = true, weight: int = 600) -> Label:
	return C.label(value, roundi(size / 0.75), color, display, weight)

static func lignes(value: Variant, size: float, color: Color, max_lines: int, display: bool = false, weight: int = 500) -> Label:
	var label := texte(value, size, color, display, weight)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## Titre en vraie italique de la charte (Barlow Condensed) ; `extra` : graisse maximale (noms de clubs, heure).
static func italique(label: Label, extra: bool = false, gras: bool = true) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE if extra else Charte.TITRE_GRAS_ITALIQUE if gras else Charte.TITRE_ITALIQUE)
	return label

static func virgule(value: Variant, decimals: int = 1) -> String:
	if not (value is float or value is int): return "—"
	return String.num(float(value), decimals).replace(".", ",") if decimals > 0 else str(roundi(float(value)))

## « SAM. 24 OCT. 2026 » (date ISO du match).
static func date_longue(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return iso
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var jour: int = Time.get_datetime_dict_from_unix_time(unix).weekday
	return "%s %d %s %s" % [JOURS[jour], int(parts[2]), MOIS[clampi(int(parts[1]) - 1, 0, 11)].to_upper(), parts[0]]

## « sam. 21 nov. 2026 » (en minuscules, comme la barre haute de la coque).
static func date_courte(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return iso
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var jour: int = Time.get_datetime_dict_from_unix_time(unix).weekday
	return "%s %d %s %s" % [str(JOURS[jour]).to_lower(), int(parts[2]), MOIS[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]

static func mois_annee(iso: Variant) -> String:
	var parts := str(iso).split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return "—"
	return "%s %s" % [MOIS[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]

## Photo d'avant-match selon la météo annoncée (`next.meteo`) et l'heure du coup d'envoi : en journée, la
## pelouse sous le ciel du jour (banque d'images) ; le soir et la nuit, l'entrée des joueurs par le tunnel
## éclairé (photos de la maquette validée).
static func photo_meteo(next: Dictionary) -> String:
	var moment := BanqueImages.moment(next.get("kickoffLocal"), next.get("date", ""))
	# Grande enceinte (20 000 places et plus) : soir sec et nuit pluvieuse aussi (banque lot-13).
	if BanqueImages.niveau_stade(next.get("capacity")) >= 5 and moment in ["soir", "nuit"]:
		var grand := BanqueImages.choisir("avant-match", {"moment": moment, "meteo": BanqueImages.meteo(next.get("meteo")), "taille": "grand"})
		if not grand.is_empty() and BanqueImages.info(grand).get("etiquettes", {}).get("moment") == moment and BanqueImages.texture(grand) != null: return grand
	if moment == "jour":
		# Grande enceinte (20 000 places et plus) par temps sec ; sinon la pelouse d'un stade de club.
		var taille := "grand" if BanqueImages.niveau_stade(next.get("capacity")) >= 5 else "club"
		var pelouse := BanqueImages.choisir("avant-match", {"moment": "jour", "meteo": BanqueImages.meteo(next.get("meteo")), "taille": taille})
		if not pelouse.is_empty() and BanqueImages.texture(pelouse) != null: return pelouse
	var meteo: Variant = next.get("meteo")
	var id := "match-tunnel-neutre"
	if meteo is Dictionary:
		if int(meteo.get("pluie", 0)) >= 2: id = "match-tunnel-forte-pluie"
		elif int(meteo.get("pluie", 0)) == 1: id = PHOTO_ORIGINE
		elif int(meteo.get("vent", 0)) > 0: id = "match-tunnel-vent"
		elif int(meteo.get("chaleur", 0)) > 0: id = "match-tunnel-chaleur"
		else: id = "match-tunnel-sec"
	return id if C.texture(id) != null else PHOTO_ORIGINE

func _init() -> void:
	name = "MatchOpening"
	# Style propre à l'écran : la passe de style héritée (legacy_style.gd) ne doit ni repeindre les pastilles ni
	# agrandir les textes ; elle s'arrête à ce nœud.
	set_meta("immersive_style_applied", true)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

## `on_kickoff` : lancement du direct (match_screen._act). `on_delegate` est conservé pour compatibilité : la délégation
## est maintenant une sous-page de cet écran.
func setup(owner: Control, on_kickoff: Callable, _on_delegate: Callable = Callable()) -> void:
	app = owner
	_on_kickoff_cb = on_kickoff
	_ouvert_a = Time.get_ticks_msec()
	var stage := Control.new()
	stage.name = "MatchStage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(stage, true)
	add_child(stage)
	content = VBoxContainer.new()
	content.name = "MatchPrematchBoard"
	content.add_theme_constant_override("separation", 0)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(content)

func _bouton_lien(caption: String, callback: Callable, node_name: String, size: float = 14.0, corps: bool = true) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, roundi(size / .75))
	if corps: button.add_theme_font_override("font", C.BODY)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	return button

## Pictogramme à gauche d'un lien (dessiné dans le lien : le clic le couvre) ; `taille` en pixels d'un écran 1080p.
func _icone_dans_lien(lien: Button, texture: Texture2D, taille: float) -> void:
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := lien.get_theme_stylebox(look) as StyleBoxFlat
		if style != null: style.content_margin_left = M(taille + 12)
	var image := TextureRect.new()
	image.name = "LienIcone"
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	image.offset_left = M(4)
	image.offset_right = M(4 + taille)
	image.offset_top = -M(taille / 2.0)
	image.offset_bottom = M(taille / 2.0)
	lien.add_child(image)
# ---- Navigation -------------------------------------------------------------------------------------------------

func _aller(route: String) -> void:
	app._navigate(route)

func _ouvrir_preparation() -> void:
	if app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation.tab = 0
	app._navigate("Préparation")

func _ouvrir_joueur(id: String) -> void:
	if app.navigation_controller.open_entity({"kind": "player", "id": id}): return
	_ouvrir_preparation()

func _ouvrir_club(club: Dictionary) -> void:
	var id: Variant = club.get("id")
	if not (id is int or id is float): return
	if not app.navigation_controller.open_entity({"kind": "club", "id": str(int(id))}): _aller("Classements")

## « ← Retour » : l'écran d'où l'on vient (historique, comme Alt+←) ; sans historique, la Préparation.
func _retour_precedent() -> void:
	var nav: Node = app.get("navigation_controller")
	if is_instance_valid(nav) and nav.cursor >= 0 and nav.cursor < nav.history.size():
		# L'avant-match n'est pas encore une étape d'historique juste après l'ouverture : on rejoint alors l'étape courante.
		var direction := -1 if nav.history[nav.cursor].route == "Match" else 0
		if nav._destination(direction) >= 0:
			nav._travel(direction)
			return
	_aller("Préparation")

## Ouvre une sous-page (« delegation », « espoir ») : une étape d'historique, Échap ou « Retour » la ferme.
func ouvrir_page(nom: String) -> void:
	if app == null or app.waiting or not app._live().is_empty() or not app.model.get("next") is Dictionary: return
	if nom == "espoir" and Espoir.offer(app.model).is_empty() and Present.reduced_bench_number(app.model) == 0: return
	_changer_page(nom)

func fermer_page() -> void:
	if page_ouverte().is_empty(): return
	var nav: Node = app.get("navigation_controller")
	# Retour à l'étape d'historique de l'avant-match quand elle précède la page : « Annuler » = Précédent.
	if is_instance_valid(nav) and nav.cursor > 0 and nav.history[nav.cursor - 1].route == "Match" and str(nav.history[nav.cursor - 1].get("avant_page", "")).is_empty() and nav._destination(-1) == nav.cursor - 1:
		nav._travel(-1)
		return
	_changer_page("")

func page_ouverte() -> String:
	return str(app.management_ui.get("avant_page", "")) if app != null else ""

func _changer_page(nom: String) -> void:
	var nav: Node = app.get("navigation_controller")
	if is_instance_valid(nav): nav.capture_current()
	app.management_ui["avant_page"] = nom
	if is_instance_valid(nav): nav.observe("Match")
	_key = ""
	if not _model.is_empty() and is_instance_valid(_play): refresh(_model, _play)

## Rafraîchit l'écran (reconstruit seulement quand les données montrées changent).
func refresh(model: Dictionary, play: Button) -> void:
	_model = model
	_play = play
	var next: Dictionary = model.next if model.get("next") is Dictionary else {}
	var selection: Dictionary = model.get("selection", {})
	var page := page_ouverte()
	if not next.is_empty() and not page.is_empty() and not _page_possible(model, page):
		app.management_ui["avant_page"] = ""
		page = ""
	var etat := _etat_feuille(model, play)
	var key := JSON.stringify([next, model.get("clubLife", {}).get("avantMatch"), selection.get("slots", []), selection.get("valid", false), selection.get("errors", []),
		model.get("squad", []).map(func(p: Dictionary): return [p.get("id"), p.get("condition"), p.get("injury")]), model.get("meta", {}).get("calendarToday"),
		page, play.text, play.disabled, play.tooltip_text, etat.mot, app.accent.to_html(), model.get("decisions", {}).get("delegation"),
		model.clubSheet.get("id") if model.get("clubSheet") is Dictionary and FaceAFace.visible() else null, C.dense()])
	if key == _key: return
	_key = key
	_page_ouverte = page
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_construire(model, next, play, etat, page)

## Construit l'écran : définie dans match_avant.gd (chaîne d'héritage), appelée par refresh.
func _construire(_model_: Dictionary, _next: Dictionary, _play_: Button, _etat: Dictionary, _page: String) -> void:
	pass

func _page_possible(model: Dictionary, page: String) -> bool:
	if not model.get("next") is Dictionary or model.next.is_empty(): return false
	if page == "espoir": return not Espoir.offer(model).is_empty() or Present.reduced_bench_number(model) != 0
	if page == "tests": return not Tests.lignes(model).is_empty()
	return page == "delegation"

## État de la feuille : mot, détail, nombre d'avertissements, cause d'un blocage.
func _etat_feuille(model: Dictionary, play: Button) -> Dictionary:
	var selection: Dictionary = model.get("selection", {})
	var slots: Array = selection.get("slots", [])
	var remplis := slots.filter(func(s: Dictionary): return s.get("playerId") != null).size()
	var valide: bool = selection.get("valid", false)
	var conditions: Array = []
	var bas: Array = []
	for assignment: Dictionary in slots:
		var slot := int(assignment.get("slot", -1))
		if slot < 0 or slot >= 15: continue
		var person := Present.player(model, str(assignment.get("playerId", "")))
		if person.is_empty(): continue
		var condition: Variant = person.get("condition")
		if not (condition is float or condition is int): continue
		conditions.append(float(condition))
		if float(condition) < CONDITION_MINI: bas.append({"slot": slot, "name": str(person.get("name", "")), "id": str(person.get("id", "")), "condition": roundi(float(condition))})
	bas.sort_custom(func(a: Dictionary, b: Dictionary): return a.condition < b.condition)
	var moyenne := 0.0
	for x in conditions: moyenne += x
	moyenne = moyenne / conditions.size() if not conditions.is_empty() else -1.0
	var avertissements := bas.size()
	var erreurs: Array = selection.get("errors", []) if selection.get("errors") is Array else []
	var mot := "Feuille validée"
	var incomplete := not valide
	if incomplete: mot = "Feuille incomplète"
	elif avertissements > 0: mot = "Feuille à vérifier"
	return {"mot": mot, "valide": valide, "incomplete": incomplete, "avertissements": avertissements, "bas": bas, "remplis": remplis, "total": slots.size(),
		"moyenne": moyenne, "erreurs": erreurs, "conditions": conditions}

var _on_kickoff_cb: Callable
