extends PanelContainer
## Écran « Avant-match » (écran 12 de la revue DA du 19/11/2026, variante 1 « L'affiche, puis les quatre vérifications »,
## plaques inclinées de la variante 3). Hors coque (charte §7) : illustration du tunnel plein cadre (variantes météo),
## bandeau haut (Menu, statut de feuille, date, « Déléguer le match », « COUP D'ENVOI » : le seul aplat or de l'écran),
## affiche (compétition, journée, lieu ; plaques inclinées aux couleurs des deux clubs ; heure ; forme, classement,
## confrontations, météo) puis quatre vérifications : feuille, conditions du match, adversaire, mot de Gabi. Chaque
## vérification mène à l'écran où l'on agit (Composition, Plan de jeu, Effectif, Préparation, Vestiaire).
## Clic sur un nom de joueur : fiche complète ; survol : mini-fiche (mini_fiche.gd). Aucune fenêtre : la délégation et
## l'appel d'un espoir sont des sous-pages (avant_match_pages.gd) gardées par l'historique (`management_ui.avant_page`).
## Toutes les valeurs viennent du modèle natif : `next`, `selection`, `squad`, `clubLife.avantMatch`
## (native/engine/avant-match.cjs). Rien n'est inventé : une donnée absente devient une phrase ou une ligne omise.
## Tailles données en pixels d'un écran 1080p (`M`), à l'échelle de la fenêtre comme le reste de l'interface.

const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const Present = preload("res://ui/immersive08/projection.gd")
const MeteoTexte = preload("res://ui/contextual/meteo_texte.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Pages = preload("res://ui/immersive08/avant_match_pages.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const RI = preload("res://ui/contextual/rooms/room_identity.gd")
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
		page, play.text, play.disabled, play.tooltip_text, etat.mot, app.accent.to_html(), model.get("decisions", {}).get("delegation")])
	if key == _key: return
	_key = key
	_page_ouverte = page
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_construire(model, next, play, etat, page)

func _page_possible(model: Dictionary, page: String) -> bool:
	if not model.get("next") is Dictionary or model.next.is_empty(): return false
	if page == "espoir": return not Espoir.offer(model).is_empty() or Present.reduced_bench_number(model) != 0
	return page == "delegation"

func _construire(model: Dictionary, next: Dictionary, play: Button, etat: Dictionary, page: String) -> void:
	var data: Dictionary = model.get("clubLife", {}).get("avantMatch") if model.get("clubLife", {}).get("avantMatch") is Dictionary else {}
	if str(data.get("fixtureId", "")) != str(next.get("id", data.get("fixtureId", ""))): data = {}
	var fond := Control.new()
	fond.name = "MatchPoster"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(fond, true)
	content.add_child(fond)
	_fond(fond, model, next)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.add_child(colonne)
	colonne.add_child(_bandeau(next, play, etat, not page.is_empty()))
	if next.is_empty():
		colonne.add_child(_vide(model))
		colonne.add_child(_pied(false))
		return
	if not page.is_empty():
		colonne.add_child(Pages.construire(self, app, model, page))
		colonne.add_child(_pied(true))
		return
	var cote := _cote(model, next)
	colonne.add_child(_affiche(model, next, data, cote))
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(vide)
	colonne.add_child(_verifications(model, next, data, cote, etat))
	colonne.add_child(_pied(false))
	_donner_le_focus.call_deferred(page)

func _donner_le_focus(page: String) -> void:
	if not is_instance_valid(kickoff) or not kickoff.is_inside_tree() or not page.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus != kickoff and is_ancestor_of(focus): return
	if not kickoff.disabled: kickoff.grab_focus()

func _cote(model: Dictionary, next: Dictionary) -> int:
	var club_id: Variant = model.get("club", {}).get("id")
	return 1 if next.get("away", {}).get("id") == club_id and club_id != null else 0

func _vide(model: Dictionary) -> Control:
	var zone := CenterContainer.new()
	C.fill(zone, true)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", M(12))
	zone.add_child(colonne)
	var fin: bool = model.get("meta", {}).get("canAdvanceSeason", false)
	var message := texte("Saison terminée." if fin else "Aucune rencontre à préparer pour le moment.", 26, C.IVORY, true, 700)
	message.name = "MatchAucuneRencontre"
	colonne.add_child(message)
	var calendrier := _bouton_lien("Voir le calendrier →", func(): _aller("Calendrier"), "MatchOpenCalendar", 18)
	colonne.add_child(calendrier)
	return zone

# ---- Fond -------------------------------------------------------------------------------------------------------

## Illustration plein cadre (tunnel ou pelouse selon l'heure et la météo) recolorée aux couleurs du club, sous un voile
## qui garantit le contraste du texte (C5).
func _fond(parent: Control, model: Dictionary, next: Dictionary) -> void:
	var id := photo_meteo(next) if not next.is_empty() else PHOTO_ORIGINE
	var photo := C.photo(id, Vector2.ZERO, true, .3)
	photo.name = "MatchPosterPhoto"
	photo.set_meta("photo_meteo", id)
	var identite: Dictionary = G.identity(model.get("club", {}))
	BanqueImages.recolorer(photo, id, RI.primary(identite), RI.secondary(identite))
	photo.tooltip_text = ""
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Charte.NUIT, .72))
	gradient.set_color(1, Color(Charte.NUIT, .94))
	gradient.add_point(.22, Color(Charte.NUIT, .34))
	gradient.add_point(.58, Color(Charte.NUIT, .22))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = gradient
	veil_texture.fill_from = Vector2.ZERO
	veil_texture.fill_to = Vector2.DOWN
	var veil := TextureRect.new()
	veil.name = "MatchPosterVeil"
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ---- Bandeau haut -----------------------------------------------------------------------------------------------

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

func _bandeau(next: Dictionary, play: Button, etat: Dictionary, en_page: bool) -> Control:
	var barre := MarginContainer.new()
	barre.name = "MatchPrematchHeader"
	barre.mouse_filter = Control.MOUSE_FILTER_PASS
	for edge in ["left", "right"]: barre.add_theme_constant_override("margin_" + edge, M(32))
	barre.add_theme_constant_override("margin_top", M(14))
	barre.add_theme_constant_override("margin_bottom", M(8))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(18))
	barre.add_child(ligne)
	# Menu : menu de la carrière (Échap), seule fenêtre de l'écran avec la mini-fiche.
	var menu := Button.new()
	menu.name = "MatchMenu"
	menu.text = "Menu"
	menu.set_meta("immersive_style_applied", true)

	menu.add_theme_font_override("font", C.BODY)
	menu.add_theme_font_size_override("font_size", maxi(12, M(15)))
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Charte.NUIT, .55) if look != "hover" else Charte.PANNEAU_2
		style.border_color = Charte.IVOIRE if look == "focus" else Charte.IVOIRE_3
		style.set_border_width_all(2 if look == "focus" else 1)
		style.set_corner_radius_all(0)
		style.content_margin_left = M(12)
		style.content_margin_right = M(12)
		style.content_margin_top = M(6)
		style.content_margin_bottom = M(6)
		menu.add_theme_stylebox_override(look, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: menu.add_theme_color_override(key, Charte.IVOIRE)
	menu.tooltip_text = "Menu : sauvegardes, réglages, quitter · Échap"
	menu.accessibility_name = "Menu · Échap"
	menu.pressed.connect(app.pause_menu)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(menu)
	var jour := italique(texte("JOUR DE MATCH", 14, Charte.IVOIRE, true, 700), false, true)
	jour.name = "MatchDayTitle"
	jour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(jour)
	status = texte("", 15, Charte.IVOIRE, false, 700)
	status.name = "MatchPrematchStatus"
	status.visible = false
	ligne.add_child(status)
	if en_page:
		var retour := _bouton_lien("← Retour à l'avant-match", fermer_page, "MatchPageBack", 15)
		retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(retour)
	elif not next.is_empty():
		ligne.add_child(_statut_feuille(etat))
	var espace := Control.new()
	espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(espace)
	ligne.add_child(espace)
	match_date = texte(date_courte(str(next.get("date", ""))) if not next.is_empty() else "", 15, Charte.IVOIRE, false, 500)
	match_date.name = "MatchPrematchDate"
	match_date.add_theme_font_override("font", C.BODY)
	match_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(match_date)
	delegate = Button.new()
	delegate.name = "MatchOpenDelegation"
	delegate.text = "Déléguer le match →"
	delegate.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(delegate, roundi(15 / .75))
	delegate.add_theme_font_override("font", C.BODY)
	delegate.pressed.connect(func(): ouvrir_page("delegation"))
	delegate.visible = not next.is_empty() and not en_page
	delegate.disabled = play.disabled
	delegate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(delegate)
	_raison = null
	if not next.is_empty() and not en_page:
		if play.disabled and not play.tooltip_text.is_empty():
			_raison = lignes(play.tooltip_text, 13, Charte.IVOIRE_2, 2, false, 500)
			_raison.name = "MatchKickoffReason"
			_raison.custom_minimum_size.x = M(260)
			_raison.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_raison.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ligne.add_child(_raison)
		ligne.add_child(_bouton_coup_d_envoi(play))
	else:
		kickoff = null
	return barre

## « ✓ Feuille validée · 23 / 23 · condition moyenne 95 % » : mot cliquable (Composition), symbole et mot, jamais la couleur seule.
func _statut_feuille(etat: Dictionary) -> Control:
	var ligne := HBoxContainer.new()
	ligne.name = "MatchSheetStatus"
	ligne.add_theme_constant_override("separation", M(6))
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var alerte: bool = etat.incomplete or etat.avertissements > 0
	var symbole := C.icon("warning" if alerte else "check", roundi(16 / .75), Charte.D if etat.incomplete else Charte.N if alerte else Charte.V)
	symbole.custom_minimum_size = Vector2(M(16), M(16))
	symbole.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(symbole)
	var lien := _bouton_lien(str(etat.mot), func(): _aller("Composition"), "MatchOpenSheetStatus", 15)
	lien.tooltip_text = "Ouvrir la composition"
	ligne.add_child(lien)
	var suite: Array[String] = []
	if etat.incomplete and not etat.erreurs.is_empty(): suite.append(str(etat.erreurs[0]))
	elif etat.avertissements > 0: suite.append("(%d avertissement%s)" % [etat.avertissements, "s" if etat.avertissements > 1 else ""])
	suite.append("%d / %d" % [etat.remplis, etat.total])
	if etat.moyenne >= 0: suite.append("condition moyenne %d %%" % roundi(etat.moyenne))
	var reste := texte(" · ".join(suite), 15, Charte.IVOIRE, false, 500)
	reste.add_theme_font_override("font", C.BODY)
	reste.name = "MatchSheetStatusDetail"
	reste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(reste)
	return ligne

## Le bouton or : aplat or, bord droit incliné de 10° (charte §7), texte nuit, « Entrée » à droite. Le seul or de l'écran.
class PlaqueOr extends Control:
	var couleur := Color.WHITE
	var anneau := Color.TRANSPARENT
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var d := Charte.decalage(size.y)
		var points := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x - d, size.y), Vector2(0, size.y)])
		draw_colored_polygon(points, couleur)
		if anneau.a > 0.0:
			var contour := points.duplicate()
			contour.append(points[0])
			draw_polyline(contour, anneau, 2.0, true)

func _bouton_coup_d_envoi(play: Button) -> Control:
	var on_kickoff: Callable = _on_kickoff
	kickoff = Button.new()
	kickoff.name = "MatchKickoff"
	kickoff.text = play.text
	kickoff.set_meta("immersive_style_applied", true)
	kickoff.disabled = play.disabled
	kickoff.tooltip_text = play.tooltip_text
	kickoff.accessibility_name = "%s · Entrée" % play.text.capitalize()
	kickoff.custom_minimum_size = Vector2(M(250), M(48))
	for look in ["normal", "hover", "pressed", "disabled"]: kickoff.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(0)
	focus.set_expand_margin_all(M(3))
	kickoff.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]: kickoff.add_theme_color_override(key, Color.TRANSPARENT)
	kickoff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plaque := PlaqueOr.new()
	plaque.name = "MatchKickoffPlate"
	plaque.couleur = Charte.OR if not play.disabled else Charte.PANNEAU_3
	plaque.show_behind_parent = true
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kickoff.add_child(plaque)
	var encre := Charte.NUIT if not play.disabled else Charte.IVOIRE_3
	var libelle := italique(texte(play.text.to_upper(), 24, encre, true, 800), true)
	libelle.name = "MatchKickoffLabel"
	libelle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	libelle.offset_left = M(22)
	libelle.offset_right = -M(96)
	libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	libelle.autowrap_mode = TextServer.AUTOWRAP_OFF
	libelle.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	kickoff.add_child(libelle)
	var filet := ColorRect.new()
	filet.color = Color(encre, .35)
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filet.anchor_left = 1.0
	filet.anchor_right = 1.0
	filet.anchor_top = .26
	filet.anchor_bottom = .74
	filet.offset_left = -M(96)
	filet.offset_right = -M(96) + 1
	kickoff.add_child(filet)
	_indice = texte("Entrée", 14, encre, false, 500)
	_indice.name = "MatchKickoffHint"
	_indice.add_theme_font_override("font", C.BODY)
	_indice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_indice.anchor_left = 1.0
	_indice.offset_left = -M(88)
	_indice.offset_right = -M(26)
	_indice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_indice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kickoff.add_child(_indice)
	kickoff.pressed.connect(on_kickoff)
	# Verrou d'ouverture : Entrée, Espace et touche maintenue sont ignorés pendant 0,5 s (fiche UX 12 §7) ; la souris non.
	kickoff.gui_input.connect(_garde_ouverture)
	if not play.disabled and verrou_actif():
		_indice.text = "…"
		get_tree().create_timer(VERROU_SECONDES).timeout.connect(_fin_verrou.bind(kickoff))
	return kickoff

var _on_kickoff_cb: Callable

func _on_kickoff() -> void:
	if _on_kickoff_cb.is_valid(): _on_kickoff_cb.call()

func verrou_actif() -> bool:
	return float(Time.get_ticks_msec() - _ouvert_a) / 1000.0 < VERROU_SECONDES

func _garde_ouverture(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed: return
	if touche.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: return
	if verrou_actif() or touche.echo: kickoff.accept_event()

func _fin_verrou(bouton: Button) -> void:
	if is_instance_valid(_indice) and is_instance_valid(bouton) and bouton == kickoff: _indice.text = "Entrée"

# ---- Affiche ----------------------------------------------------------------------------------------------------

## Plaque inclinée aux couleurs d'un club : écusson, nom en 64 px, bord incliné de 10° ; clic : fiche du club.
class Plaque extends Button:
	var couleur := Color.WHITE
	var anneau := false
	var droite := false
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		var d := Charte.decalage(size.y)
		var points := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x - d, size.y), Vector2(0, size.y)]) if not droite \
			else PackedVector2Array([Vector2(d, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
		if anneau:
			draw_colored_polygon(points, Color(Charte.NUIT, .55))
			var contour := points.duplicate()
			contour.append(points[0])
			draw_polyline(contour, Charte.IVOIRE, 3.0, true)
		else:
			draw_colored_polygon(points, couleur)
		if is_hovered() or has_focus():
			var contour_f := points.duplicate()
			contour_f.append(points[0])
			draw_polyline(contour_f, Charte.IVOIRE, 3.0 if has_focus() else 2.0, true)

func _distance(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))

func _plaque(club: Dictionary, droite: bool, anneau: bool, ma_couleur: Color) -> Button:
	var plaque := Plaque.new()
	plaque.name = "MatchPosterHome" if not droite else "MatchPosterAway"
	plaque.flat = true
	plaque.set_meta("immersive_style_applied", true)
	plaque.couleur = ma_couleur
	plaque.anneau = anneau
	plaque.droite = droite
	for look in ["normal", "hover", "pressed", "disabled"]: plaque.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	plaque.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	plaque.custom_minimum_size = Vector2(M(640), M(100))
	plaque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plaque.tooltip_text = "Fiche du club : %s" % G.club_name(club)
	plaque.accessibility_name = "Fiche du club %s" % G.club_name(club)
	plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plaque.pressed.connect(func(): _ouvrir_club(club))
	var encre := Charte.IVOIRE if anneau or Charte.contraste(Charte.IVOIRE, ma_couleur) >= 3.0 else Charte.NUIT
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(22))
	ligne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ligne.offset_left = M(26)
	ligne.offset_right = -M(26)
	ligne.alignment = BoxContainer.ALIGNMENT_BEGIN if not droite else BoxContainer.ALIGNMENT_END
	plaque.add_child(ligne)
	var crest := G.crest(club, M(70))
	crest.custom_minimum_size = Vector2(M(70), M(78))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nom := texte(G.club_name(club).to_upper(), 64, encre, true, 800)
	italique(nom, true)
	nom.name = "MatchPosterName"
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_OFF
	nom.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_ajuster_nom(nom, M(640) - M(26) * 2 - M(70) - M(22) - M(24))
	if not droite:
		ligne.add_child(crest)
		ligne.add_child(nom)
	else:
		ligne.add_child(nom)
		ligne.add_child(crest)
	return plaque

## Réduit la taille du nom (jamais tronqué) jusqu'à ce qu'il tienne dans la plaque ; plancher 30 px.
func _ajuster_nom(nom: Label, largeur: int) -> void:
	var police: Font = nom.get_theme_font("font")
	var taille := nom.get_theme_font_size("font_size")
	var plancher := maxi(12, M(30))
	while taille > plancher and police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur: taille -= 1
	nom.add_theme_font_size_override("font_size", taille)
	nom.custom_minimum_size.x = minf(float(largeur), police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 2.0)

func _affiche(model: Dictionary, next: Dictionary, data: Dictionary, nous: int) -> Control:
	var zone := MarginContainer.new()
	zone.name = "MatchAffiche"
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, M(32))
	zone.add_theme_constant_override("margin_top", M(34 if C.density >= .6 else 14))
	var pile := VBoxContainer.new()
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_theme_constant_override("separation", M(10 if C.density >= .6 else 6))
	zone.add_child(pile)
	var venue := Present.fixture_venue(next, false)
	var haut := texte("  ·  ".join([str(next.get("label", "")), venue].filter(func(x: String): return not x.is_empty())).to_upper(), 14, Charte.IVOIRE, true, 700)
	haut.name = "MatchFixtureVenue"
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	haut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	haut.clip_text = true
	pile.add_child(haut)
	var clubs := [next.get("home", {}), next.get("away", {})]
	var couleurs: Array[Color] = []
	for club: Dictionary in clubs: couleurs.append(RI.primary(G.identity(club)))
	var eux := 1 - nous
	var proches := _distance(couleurs[nous], couleurs[eux]) < CLUBS_PROCHES
	var forme: Array = data.get("forme", [[], []])
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_theme_constant_override("separation", 0)
	pile.add_child(rangee)
	var colonnes: Array[VBoxContainer] = []
	var plaques: Array[Button] = []
	for side in 2:
		var colonne := VBoxContainer.new()
		colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.add_theme_constant_override("separation", M(6))
		colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colonne.size_flags_stretch_ratio = 1.0
		colonnes.append(colonne)
		var lieu := "TERRAIN NEUTRE" if next.get("neutral", false) else ("DOMICILE" if side == 0 else "EXTÉRIEUR")
		var etiquette := texte(("TON ÉQUIPE · " + lieu.capitalize()) if side == nous else lieu.capitalize(), 13, Charte.IVOIRE if side == nous else Charte.IVOIRE_2, false, 600)
		etiquette.name = "MatchPosterSide%d" % side
		etiquette.add_theme_font_override("font", C.BODY)
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		colonne.add_child(etiquette)
		var anneau: bool = proches and side == eux
		var plaque := _plaque(clubs[side], side == 1, anneau, couleurs[side])
		plaques.append(plaque)
		colonne.add_child(plaque)
		colonne.add_child(_classement(clubs[side], side, forme[side] if forme.size() > side and forme[side] is Array else []))
	rangee.add_child(colonnes[0])
	rangee.add_child(_centre(next, data, nous))
	rangee.add_child(colonnes[1])
	return zone

func _centre(next: Dictionary, data: Dictionary, nous: int) -> Control:
	var colonne := VBoxContainer.new()
	colonne.name = "MatchPosterKickoff"
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.custom_minimum_size.x = M(300)
	colonne.add_theme_constant_override("separation", M(4))
	var heure := texte(str(next.get("kickoffLocal", "")) if next.get("kickoffLocal") is String else "—", 64, Charte.IVOIRE, true, 800)
	italique(heure, true)
	heure.name = "MatchPosterTime"
	heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(heure)
	var jour := texte("coup d'envoi · " + date_courte(str(next.get("date", ""))), 14, Charte.IVOIRE, false, 500)
	jour.add_theme_font_override("font", C.BODY)
	jour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(jour)
	# Confrontations : clic = la fiche du club adverse (son historique).
	var bilan: Dictionary = data.get("confrontations", {})
	var joues := int(bilan.get("joues", 0))
	var legende := "Première confrontation" if joues == 0 else "Confrontations : %s" % bilan_court(bilan, true)
	if data.is_empty(): legende = "Avant-match"
	var adverse: Dictionary = next.get("away", {}) if nous == 0 else next.get("home", {})
	var lien := _bouton_lien(legende, func(): _ouvrir_club(adverse), "MatchPosterHeadToHead", 14)
	lien.tooltip_text = "Fiche du club adverse : %s" % G.club_name(adverse)
	lien.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lien.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(lien)
	if next.get("meteo") is Dictionary:
		var meteo := _ligne_meteo(next, nous)
		colonne.add_child(meteo)
	return colonne

## Ciel et vent en une ligne (icône + mot) ; clic : le plan de jeu, pour l'adapter aux conditions.
func _ligne_meteo(next: Dictionary, nous: int) -> Control:
	var annonce := MeteoTexte.annonce(next)
	var meteo: Dictionary = next.meteo
	var bouton := Button.new()
	bouton.name = "MatchFixtureWeather"
	bouton.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(bouton, roundi(14 / .75))
	bouton.add_theme_font_override("font", C.BODY)
	bouton.icon = icone_meteo(meteo, Charte.IVOIRE)
	bouton.expand_icon = true
	bouton.add_theme_constant_override("icon_max_width", M(18))
	bouton.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ciel := MeteoTexte.libelle(annonce)
	var vent: String = ["", "Vent", "Grand vent"][clampi(int(meteo.get("vent", 0)), 0, 2)]
	var mots: Array[String] = [ciel]
	if not vent.is_empty() and ciel.to_lower().find("vent") < 0: mots.append(vent.to_lower())
	bouton.text = " · ".join(mots)
	bouton.tooltip_text = "Adapter le plan de jeu aux conditions"
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton.pressed.connect(func(): _aller("Plan de jeu"))
	bouton.set_meta("vent", phrase_vent(next, nous))
	var enveloppe := CenterContainer.new()
	enveloppe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enveloppe.add_child(bouton)
	return enveloppe
## Rang, points et forme d'un club : rang cliquable (Classements), pastilles V / N / D à lettre et forme.
func _classement(club: Dictionary, side: int, forme: Array) -> Control:
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(8))
	ligne.alignment = BoxContainer.ALIGNMENT_BEGIN if side == 0 else BoxContainer.ALIGNMENT_END
	ligne.name = "MatchPosterRank%d" % side
	var ouvert := Present.standings_open(club)
	var rang := "%s · %s pts" % [Present.rank_ordinal(club), G.n(club.get("points", 0))] if ouvert else "Classement ouvert après la 1re journée"
	var lien := _bouton_lien(rang, func(): _aller("Classements"), "MatchPosterStanding%d" % side, 14)
	lien.tooltip_text = "Ouvrir le classement"
	ligne.add_child(lien)
	var pastilles := HBoxContainer.new()
	pastilles.name = "MatchPosterForm"
	pastilles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilles.add_theme_constant_override("separation", M(5))
	for resultat in forme:
		var p := pastille(str(resultat), 24)
		p.pressed.connect(func(): _ouvrir_club(club))
		p.tooltip_text = "Forme sur les 5 derniers matchs, du plus ancien au plus récent · fiche du club"
		pastilles.add_child(p)
	ligne.add_child(pastilles)
	return ligne

## Pastille de résultat : lettre dedans, forme différente par résultat (V plein, N carré arrondi, D anneau) ; un bouton.
static func pastille(result: String, size: float) -> Button:
	var bouton := Button.new()
	bouton.name = "Pastille" + result
	bouton.text = result
	bouton.set_meta("immersive_style_applied", true)
	bouton.custom_minimum_size = Vector2(M(size), M(size))
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_font_size_override("font_size", maxi(12, M(size * .5)))
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var couleur := Charte.V if result == "V" else Charte.D if result == "D" else Charte.N
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var anneau := result == "D"
		style.bg_color = Color(Charte.NUIT, .6) if anneau else couleur
		style.border_color = Charte.IVOIRE if look in ["hover", "focus"] else couleur
		style.set_border_width_all(M(3) if look in ["hover", "focus"] else (M(2) if anneau else 0))
		if result == "N": style.set_corner_radius_all(M(6))
		else: style.set_corner_radius_all(M(size / 2.0))
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		bouton.add_theme_stylebox_override(look, style)
	var encre := couleur if result == "D" else Charte.NUIT
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: bouton.add_theme_color_override(key, encre)
	return bouton

## « 1 V · 0 N · 3 D » (ou « 1 V – 3 D » sans nul).
static func bilan_court(bilan: Dictionary, avec_nuls: bool = false) -> String:
	var parts: Array[String] = ["%d V" % int(bilan.get("victoires", 0))]
	if avec_nuls or int(bilan.get("nuls", 0)) > 0: parts.append("%d N" % int(bilan.get("nuls", 0)))
	parts.append("%d D" % int(bilan.get("defaites", 0)))
	return " · ".join(parts) if avec_nuls else " – ".join(parts)

## Phrase du vent : « dans le dos de X en 1re période, dans le nôtre après la pause ».
static func phrase_vent(next: Dictionary, nous: int) -> String:
	var annonce := MeteoTexte.annonce(next)
	var premiere := MeteoTexte.camp_vent(annonce, 1)
	if premiere < 0: return ""
	var seconde := MeteoTexte.camp_vent(annonce, 2)
	var qui := func(camp: int) -> String: return "le nôtre" if camp == nous else "le leur"
	var nom := "nous" if premiere == nous else MeteoTexte.nom_camp(annonce, premiere)
	if premiere == nous: return "dans notre dos en 1re période, dans le leur après la pause"
	return "dans le dos de %s en 1re période, dans %s après la pause" % [nom, qui.call(seconde)]

## Icône du ciel (vent, pluie, soleil, nuage) dessinée en SVG, comme les icônes du jeu.
static func icone_meteo(meteo: Dictionary, color: Color) -> Texture2D:
	var ink := "#" + color.to_html(false)
	var corps := '<path d="M6 17h10a4 4 0 1 0-1.1-7.85A5.5 5.5 0 0 0 4.3 11.2 3 3 0 0 0 6 17z"/>'
	if meteo.is_empty(): corps = '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'
	elif int(meteo.get("pluie", 0)) > 0: corps = '<path d="M6 13h10a4 4 0 1 0-1.1-7.85A5.5 5.5 0 0 0 4.3 7.2 3 3 0 0 0 6 13z"/><path d="M8 16l-1 3M12 16l-1 3M16 16l-1 3"/>' + ('<path d="M10 20l-.6 2M14 20l-.6 2"/>' if int(meteo.get("pluie", 0)) >= 2 else "")
	elif int(meteo.get("vent", 0)) > 0: corps = '<path d="M3 8h11a3 3 0 1 0-3-3"/><path d="M3 12h16a3 3 0 1 1-3 3"/><path d="M3 16h8"/>'
	else: corps = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [ink, corps]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	return ImageTexture.create_from_image(image)

# ---- Pied -------------------------------------------------------------------------------------------------------

func _touche(libelle: String) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(0)
	style.content_margin_left = M(8)
	style.content_margin_right = M(8)
	style.content_margin_top = M(2)
	style.content_margin_bottom = M(2)
	cadre.add_theme_stylebox_override("panel", style)
	var l := texte(libelle, 13, Charte.IVOIRE, false, 700)
	l.add_theme_font_override("font", C.BODY)
	cadre.add_child(l)
	return cadre

## Rappel des touches : Entrée / Espace sur le bouton, Tab, Échap (retour), F1 (aide de Gabi, cliquable).
func _pied(en_page: bool) -> Control:
	var marge := MarginContainer.new()
	marge.name = "MatchFooterHints"
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: marge.add_theme_constant_override("margin_" + edge, M(32))
	marge.add_theme_constant_override("margin_top", M(8))
	marge.add_theme_constant_override("margin_bottom", M(10))
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(10))
	marge.add_child(ligne)
	var morceaux: Array = [["Entrée", "ou", "Espace", "sur le bouton"], ["Tab", "élément suivant"], ["Échap", "retour" if en_page else "menu"]] if not en_page else [["Tab", "élément suivant"], ["Échap", "retour à l'avant-match"]]
	for groupe: Array in morceaux:
		for partie: String in groupe:
			var est_touche: bool = partie in ["Entrée", "Espace", "Tab", "Échap"]
			if est_touche: ligne.add_child(_touche(partie))
			else:
				var mot := texte(partie, 13, Charte.IVOIRE_2, false, 500)
				mot.add_theme_font_override("font", C.BODY)
				ligne.add_child(mot)
		var espace := Control.new()
		espace.custom_minimum_size.x = M(16)
		espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(espace)
	ligne.add_child(_touche("F1"))
	var aide := _bouton_lien("aide", func(): app._open_coach(), "MatchOpenHelp", 13)
	aide.tooltip_text = "Aide de Gabi · F1"
	ligne.add_child(aide)
	# Ligne d'état de la carrière (sauvegarde, action refusée) : le pied de la coque n'existe pas ici, elle vit dans ce pied.
	var etat := texte(app._status_line_text() if app.has_method("_status_line_text") else "", 13, Charte.IVOIRE_2, false, 500)
	etat.name = "ImmersiveSaveStatus"
	etat.add_theme_font_override("font", C.BODY)
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	C.fill(etat)
	ligne.add_child(etat)
	app.status = etat
	return marge

# ---- Les quatre vérifications -----------------------------------------------------------------------------------

func _verifications(model: Dictionary, next: Dictionary, data: Dictionary, nous: int, etat: Dictionary) -> Control:
	var marge := MarginContainer.new()
	marge.name = "MatchPrematchTiles"
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: marge.add_theme_constant_override("margin_" + edge, M(32))
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(16))
	marge.add_child(ligne)
	ligne.add_child(_feuille(model, etat))
	ligne.add_child(_meteo(model, next, nous, data))
	ligne.add_child(_adversaire(model, next, data, nous))
	ligne.add_child(_gabi(data))
	return marge

func _tuile(id: String, titre: String, legende: String = "") -> VBoxContainer:
	var tile := PanelContainer.new()
	tile.name = id
	tile.clip_contents = true
	tile.set_meta("prematch_tile", true)
	C.fill(tile)
	tile.size_flags_stretch_ratio = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU, .94)
	style.set_corner_radius_all(0)
	style.content_margin_left = M(18)
	style.content_margin_right = M(18)
	style.content_margin_top = M(12)
	style.content_margin_bottom = M(12)
	tile.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", M(5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tete)
	var heading := italique(texte(titre.to_upper(), 18, Charte.IVOIRE, true, 700))
	heading.name = "TileTitle"
	C.fill(heading)
	tete.add_child(heading)
	if not legende.is_empty():
		var droite := texte(legende.to_upper(), 12, Charte.IVOIRE_2, true, 600)
		droite.name = "TileLegend"
		droite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(droite)
	var filet := ColorRect.new()
	filet.color = Charte.FILET
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filet)
	tile.set_meta("content", column)
	return column

func _tile_of(column: VBoxContainer) -> PanelContainer:
	return column.get_parent() as PanelContainer

func _pousse(column: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

## Ligne « ÉTIQUETTE  valeur » (étiquette en petites capitales de 12 px, valeur à droite).
func _rang(column: VBoxContainer, etiquette: String, valeur: Control, node_name: String = "") -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(12))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.custom_minimum_size.y = M(26)
	if not node_name.is_empty(): ligne.name = node_name
	var cle := texte(etiquette.to_upper(), 12, Charte.IVOIRE_2, true, 600)
	cle.custom_minimum_size.x = M(84)
	cle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(cle)
	valeur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not valeur.size_flags_horizontal & Control.SIZE_EXPAND: C.fill(valeur)
	ligne.add_child(valeur)
	column.add_child(ligne)
	var filet := ColorRect.new()
	filet.color = Color(Charte.FILET, .55)
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filet)
	return ligne

func _valeur(texte_: String, size: float = 13, couleur: Color = Charte.IVOIRE, max_lignes: int = 2, gras: bool = false) -> Label:
	var l := lignes(texte_, size, couleur, max_lignes, false, 700 if gras else 500)
	l.clip_text = true
	return l

## Ligne de liens en bas d'une tuile.
func _liens(column: VBoxContainer, liens: Array) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(14))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entree: Array in liens:
		var lien := _bouton_lien(str(entree[0]), entree[1], str(entree[2]), 14)
		if entree.size() > 3: lien.tooltip_text = str(entree[3])
		ligne.add_child(lien)
	column.add_child(ligne)
	return ligne

## 1. Ta feuille : repères de condition des quinze titulaires (clic = fiche, survol = mini-fiche), alerte en mots.
func _feuille(model: Dictionary, etat: Dictionary) -> Control:
	var legende := "%d / %d" % [etat.remplis, etat.total]
	if etat.valide and etat.total > 0: legende += " · complète"
	var column := _tuile("TuileFeuille", "Ta feuille", legende)
	var selection: Dictionary = model.get("selection", {})
	var conditions: Array = []
	var noms: Array = []
	var ids: Array = []
	for i in 15: conditions.append(-1.0); noms.append(""); ids.append("")
	for assignment: Dictionary in selection.get("slots", []):
		var slot := int(assignment.get("slot", -1))
		if slot < 0 or slot >= 15: continue
		var person := Present.player(model, str(assignment.get("playerId", "")))
		if person.is_empty() or not (person.get("condition") is float or person.get("condition") is int): continue
		conditions[slot] = float(person.condition)
		noms[slot] = str(person.get("name", ""))
		ids[slot] = str(person.get("id", ""))
	var intro := texte("Condition des titulaires, repère à %d %%" % CONDITION_MINI, 13, Charte.IVOIRE, false, 500)
	intro.add_theme_font_override("font", C.BODY)
	intro.name = "FeuilleConsigne"
	column.add_child(intro)
	# Petite fenêtre (1280 × 720) : deux rangées de repères (1 à 8, 9 à 15) pour garder des cibles d'au moins 20 px.
	var deux_rangees := C.dense()
	var barres := VBoxContainer.new()
	barres.name = "FeuilleConditions"
	barres.add_theme_constant_override("separation", M(4))
	barres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rangees: Array[HBoxContainer] = []
	for r in (2 if deux_rangees else 1):
		var rangee := HBoxContainer.new()
		rangee.add_theme_constant_override("separation", M(3))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.size_flags_vertical = Control.SIZE_EXPAND_FILL
		barres.add_child(rangee)
		rangees.append(rangee)
	barres.custom_minimum_size.y = M(190 if deux_rangees else 130)
	for i in 15:
		var barre := Barre.new()
		barre.name = "FeuilleBarre%d" % (i + 1)
		barre.valeur = conditions[i]
		barre.numero = i + 1
		barre.mini = CONDITION_MINI
		barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.size_flags_vertical = Control.SIZE_EXPAND_FILL
		barre.custom_minimum_size = Vector2(M(18), M(92 if deux_rangees else 110))
		if not str(ids[i]).is_empty():
			barre.tooltip_text = ""
			barre.accessibility_name = "N° %d, %s, condition %d %%" % [i + 1, noms[i], roundi(conditions[i])]
			var id: String = ids[i]
			barre.pressed.connect(func(): _ouvrir_joueur(id))
			MiniFiche.lier(app, barre, id, "squad")
		else:
			barre.disabled = true
			barre.mouse_default_cursor_shape = Control.CURSOR_ARROW
		rangees[1 if deux_rangees and i >= 8 else 0].add_child(barre)
	if deux_rangees:
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangees[1].add_child(vide)
	column.add_child(barres)
	var note_texte := ""
	if etat.incomplete:
		note_texte = str(etat.erreurs[0]) if not etat.erreurs.is_empty() else "Il manque des joueurs sur la feuille."
	elif etat.bas.size() > 0:
		var morceaux: Array[String] = []
		for b: Dictionary in etat.bas.slice(0, 2): morceaux.append("%s (n° %d) à %d %%" % [b.name, b.slot + 1, b.condition])
		note_texte = "%d titulaire%s sous %d %% : %s" % [etat.bas.size(), "s" if etat.bas.size() > 1 else "", CONDITION_MINI, ", ".join(morceaux)]
	else:
		note_texte = "Tous les titulaires à %d %% ou plus" % CONDITION_MINI
	var alerte: bool = etat.incomplete or etat.bas.size() > 0
	var note := HBoxContainer.new()
	note.add_theme_constant_override("separation", M(6))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var symbole := C.icon("warning" if alerte else "check", roundi(14 / .75), Charte.D if alerte else Charte.V)
	symbole.custom_minimum_size = Vector2(M(14), M(14))
	symbole.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.add_child(symbole)
	var phrase := lignes(note_texte, 13, Charte.IVOIRE, 2, false, 500)
	phrase.name = "FeuilleAlerte"
	C.fill(phrase)
	note.add_child(phrase)
	column.add_child(note)
	var injured := int(Present.group(model).get("injured", 0))
	var groupe := lignes(("%d blessé%s écarté%s" % [injured, "s" if injured > 1 else "", "s" if injured > 1 else ""] if injured > 0 else "Aucun blessé") + " · état du groupe", 13, Charte.IVOIRE_2, 1, false, 500)
	groupe.name = "FeuilleGroupe"
	column.add_child(groupe)
	_pousse(column)
	_liens(column, [["Vérifier la feuille →", func(): _aller("Composition"), "MatchOpenSheet", "Ouvrir la composition"],
		["État du groupe →", func(): _aller("Effectif"), "MatchOpenSquad", "Ouvrir l'effectif : blessures, fatigue, forme"]])
	return _tile_of(column)

## Barre de condition d'un titulaire : valeur au-dessus (jamais la couleur seule), numéro dessous, repère à 80 %.
class Barre extends Button:
	var valeur := -1.0
	var numero := 0
	var mini := 80
	func _ready() -> void:
		flat = true
		for look in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(look, StyleBoxEmpty.new())
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		resized.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _draw() -> void:
		var police: Font = Charte.TEXTE
		var taille := 12
		# Barres étroites (fenêtre 1280) : les valeurs voisines se décalent d'un étage pour ne pas se chevaucher.
		var etage: bool = size.x < float(taille) * 1.9
		var haut := float(taille) * (2.0 if etage else 1.0) + 4.0
		var bas := float(taille) + 4.0
		var zone := Rect2(0, haut, size.x, maxf(4.0, size.y - haut - bas))
		draw_rect(zone, Charte.PANNEAU_2)
		var bas_niveau := valeur >= 0.0 and valeur < float(mini)
		if valeur >= 0.0:
			var hauteur := zone.size.y * clampf(valeur / 100.0, .04, 1.0)
			draw_rect(Rect2(zone.position.x, zone.end.y - hauteur, zone.size.x, hauteur), Charte.IVOIRE_3 if bas_niveau else Charte.IVOIRE_2)
		var y_mini := zone.end.y - zone.size.y * float(mini) / 100.0
		for x in range(0, int(zone.size.x), 6): draw_line(Vector2(zone.position.x + x, y_mini), Vector2(minf(zone.end.x, zone.position.x + x + 3), y_mini), Color(Charte.IVOIRE, .7), 1.0)
		var texte_valeur := "%d" % roundi(valeur) if valeur >= 0.0 else "—"
		var y_valeur := haut - 4.0 - (float(taille) if etage and numero % 2 == 0 else 0.0)
		draw_string(police, Vector2(-3.0, y_valeur), texte_valeur, HORIZONTAL_ALIGNMENT_CENTER, size.x + 6.0, taille, Charte.D if bas_niveau else Charte.IVOIRE)
		if bas_niveau and not etage: draw_string(police, Vector2(0, y_valeur - float(taille)), "!", HORIZONTAL_ALIGNMENT_CENTER, size.x, taille, Charte.D)
		draw_string(police, Vector2(0, size.y - 3.0), str(numero), HORIZONTAL_ALIGNMENT_CENTER, size.x, taille, Charte.IVOIRE_2)
		if is_hovered() or has_focus(): draw_rect(Rect2(0, 0, size.x, size.y), Charte.IVOIRE, false, 2.0 if has_focus() else 1.0)

## 2. Conditions du match : météo annoncée la veille, vent, conseil du staff, arbitre et ses quatre tendances en mots.
func _meteo(model: Dictionary, next: Dictionary, nous: int, data: Dictionary) -> Control:
	var bloc := MeteoTexte.avant_match(next, str(model.get("meta", {}).get("calendarToday", "")))
	var legende := "Annoncées la veille" if next.get("meteo") is Dictionary else ""
	var column := _tuile("TuileMeteo", "Conditions du match", legende)
	var annonce := MeteoTexte.annonce(next)
	var arbitre: Dictionary = data.get("arbitre") if data.get("arbitre") is Dictionary and not str(data.arbitre.get("nom", "")).is_empty() else {}
	if annonce.is_empty():
		var message := lignes(str(bloc.conseil), 15, Charte.IVOIRE, 2, false, 600)
		message.name = "MeteoAnnonce"
		column.add_child(message)
		column.add_child(lignes("Le staff fixe la météo et le sens du vent la veille ; un courrier te les annonce.", 13, Charte.IVOIRE_2, 2))
	else:
		var meteo: Dictionary = next.meteo
		var ciel_ligne := HBoxContainer.new()
		ciel_ligne.add_theme_constant_override("separation", M(8))
		ciel_ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := TextureRect.new()
		icone.texture = icone_meteo(meteo, Charte.IVOIRE)
		icone.custom_minimum_size = Vector2(M(20), M(20))
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ciel_ligne.add_child(icone)
		var ciel := texte(str(bloc.ciel), 15, Charte.IVOIRE, false, 700)
		ciel.add_theme_font_override("font", C.BODY)
		ciel.name = "MeteoCiel"
		ciel_ligne.add_child(ciel)
		var pelouse := texte("· pelouse %s" % ("lourde" if str(meteo.get("terrain", "")) == "lourd" else "souple"), 13, Charte.IVOIRE_2, false, 500)
		pelouse.add_theme_font_override("font", C.BODY)
		ciel_ligne.add_child(pelouse)
		_rang(column, "Météo", ciel_ligne, "MeteoLigne")
		var phrase := phrase_vent(next, nous)
		var vent := HBoxContainer.new()
		vent.add_theme_constant_override("separation", M(8))
		vent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vent.add_child(_jauge_vent(int(meteo.get("vent", 0))))
		var mot_vent: String = ["Pas de vent notable", "Vent", "Grand vent"][clampi(int(meteo.get("vent", 0)), 0, 2)]
		var detail_vent := lignes(mot_vent + (" · " + phrase if not phrase.is_empty() else ""), 13, Charte.IVOIRE, 3, false, 500)
		detail_vent.name = "MeteoVent"
		C.fill(detail_vent)
		vent.add_child(detail_vent)
		_rang(column, "Vent", vent, "MeteoVentLigne")
		var conseil_texte := MeteoTexte.conseil(annonce)
		if not conseil_texte.is_empty():
			var conseil := lignes("« %s »" % conseil_texte, 13, Charte.IVOIRE, 2, false, 500)
			conseil.name = "MeteoConseil"
			conseil.tooltip_text = conseil_texte
			conseil.mouse_filter = Control.MOUSE_FILTER_PASS
			column.add_child(conseil)
	if not arbitre.is_empty(): _arbitre(column, arbitre)
	_pousse(column)
	_liens(column, [["Adapter le plan de jeu →", func(): _aller("Plan de jeu"), "MatchOpenWeatherPlan", "Ouvrir le plan de jeu"]])
	return _tile_of(column)

func _jauge_vent(level: int) -> Control:
	var gauge := HBoxContainer.new()
	gauge.name = "MeteoForceVent"
	gauge.add_theme_constant_override("separation", M(3))
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var bar := Panel.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(M(6), M(8 + i * 5))
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.IVOIRE if level > 0 and i <= level else Color(Charte.IVOIRE, .2)
		style.set_corner_radius_all(0)
		bar.add_theme_stylebox_override("panel", style)
		gauge.add_child(bar)
	return gauge

## Arbitre : nom et ses quatre tendances en mots (souple / équilibré / pointilleux) avec repères.
func _arbitre(column: VBoxContainer, arbitre: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "MatchArbitre"
	bloc.add_theme_constant_override("separation", M(1))
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bloc)
	var nom := texte(str(arbitre.get("nom", "")), 13, Charte.IVOIRE, false, 700)
	nom.add_theme_font_override("font", C.BODY)
	nom.name = "MatchArbitreNom"
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var resume := str(arbitre.get("resume", "")).strip_edges()
	if not resume.is_empty():
		nom.tooltip_text = resume
		nom.mouse_filter = Control.MOUSE_FILTER_PASS
	_rang(bloc, "Arbitre", nom)
	for axe: Array in [["rucks", "Rucks"], ["melee", "Mêlée"], ["horsJeu", "Hors-jeu"], ["cartons", "Cartons"]]:
		_rang(bloc, str(axe[1]), jauge_arbitre(str(axe[1]), arbitre.get(axe[0])))

## Tendance d'un arbitre en mot, avec trois repères (1 laisse jouer ... 5 pointilleux).
static func mot_arbitre(niveau: int) -> String:
	return "non renseigné" if niveau <= 0 else "Souple" if niveau <= 2 else "Équilibré" if niveau == 3 else "Pointilleux"

static func jauge_arbitre(libelle: String, valeur: Variant) -> Control:
	var niveau: int = clampi(int(valeur), 0, 5) if valeur is int or valeur is float else 0
	var ligne := HBoxContainer.new()
	ligne.name = "ArbitreJauge_" + libelle
	ligne.add_theme_constant_override("separation", M(8))
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.tooltip_text = "%s : %s" % [libelle, ("%d sur 5" % niveau) if niveau > 0 else "non renseigné"]
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var mot := texte(mot_arbitre(niveau), 13, Charte.IVOIRE, false, 500)
	mot.add_theme_font_override("font", C.BODY)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(mot)
	ligne.add_child(mot)
	var crans := HBoxContainer.new()
	crans.add_theme_constant_override("separation", M(2))
	crans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crans.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var allumes := 0 if niveau <= 0 else 1 if niveau <= 2 else 2 if niveau == 3 else 3
	for i in 3:
		var cran := Panel.new()
		cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cran.custom_minimum_size = Vector2(M(14 if i == allumes - 1 else 10), M(5))
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.IVOIRE if i == allumes - 1 and allumes > 0 else Color(Charte.IVOIRE, .22)
		style.set_corner_radius_all(0)
		cran.add_theme_stylebox_override("panel", style)
		crans.add_child(cran)
	ligne.add_child(crans)
	ligne.set_meta("niveau", niveau)
	return ligne

## 3. L'adversaire : plan probable lu par le staff, point fort, joueurs à surveiller (clic : dossier adverse), rapport de force.
const CONFIANCE := {"sure": "Lecture nette", "probable": "Probable", "incertaine": "Incertain"}

func _adversaire(model: Dictionary, next: Dictionary, data: Dictionary, nous: int) -> Control:
	var plan: Dictionary = data.get("planAdverse") if data.get("planAdverse") is Dictionary else {}
	var eux: Dictionary = next.get("away", {}) if nous == 0 else next.get("home", {})
	var legende := ""
	if Present.standings_open(eux): legende = "%s · %s pts" % [Present.rank_ordinal(eux), G.n(eux.get("points", 0))]
	var column := _tuile("TuileJoueurs", "L’adversaire", legende)
	if not plan.is_empty(): _plan_adverse(column, plan)
	else:
		column.add_child(lignes("Leur plan de jeu n'est pas encore connu : le staff le lit la veille du match.", 13, Charte.IVOIRE_2, 2))
	var surveiller: Dictionary = data.get("aSurveiller", {})
	var joueurs: Array = surveiller.get("joueurs", [])
	if not plan.is_empty(): joueurs = joueurs.slice(0, 2)
	if str(surveiller.get("source", "")) == "probable":
		column.add_child(lignes("Pas encore de statistiques cette saison : leur XV probable.", 13, Charte.IVOIRE_2, 2))
	if joueurs.is_empty() and plan.is_empty():
		column.add_child(lignes("Leur effectif n'a pas encore de statistiques ni de XV connu.", 13, Charte.IVOIRE_2, 3))
	for joueur: Dictionary in joueurs:
		var ligne := HBoxContainer.new()
		ligne.name = "Surveille_" + str(joueur.get("categorie", ""))
		ligne.add_theme_constant_override("separation", M(8))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var numero := PanelContainer.new()
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Charte.NUIT, .4)
		style.border_color = Charte.IVOIRE
		style.set_border_width_all(1)
		style.set_corner_radius_all(M(11))
		numero.add_theme_stylebox_override("panel", style)
		numero.custom_minimum_size = Vector2(M(24), M(22))
		numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := texte(str(int(joueur.get("numero", 0))) if joueur.get("numero") != null else "—", 13, Charte.IVOIRE, true, 700)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		numero.add_child(n)
		ligne.add_child(numero)
		var id := str(joueur.get("id", ""))
		var lien := _bouton_lien(str(joueur.get("name", "")), _ouvrir_joueur_adverse.bind(id), "SurveilleNom_" + str(joueur.get("categorie", "")), 13, true)
		lien.tooltip_text = "Dossier adverse"
		lien.set_meta("joueur_id", id)
		MiniFiche.lier(app, lien, id, "market")
		if lien.tooltip_text.is_empty(): lien.tooltip_text = ""
		ligne.add_child(lien)
		var detail := "%s · %s" % [str(joueur.get("poste", "")), str(joueur.get("role", ""))]
		if joueur.get("chiffre") is String: detail += " · " + str(joueur.chiffre)
		var role := lignes(detail, 13, Charte.IVOIRE_2, 1, false, 500)
		role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		C.fill(role)
		ligne.add_child(role)
		column.add_child(ligne)
	_force_relative(column, data, nous)
	_pousse(column)
	var liens: Array = []
	if not plan.is_empty():
		var route := "Plan de jeu" if str(plan.get("action", "")) == "consignes" else "Composition"
		liens.append([str(plan.get("libelle", "Ouvrir la composition")) + " →", func(): _aller(route), "MatchCounterPlan", "Conseil de Gabi : " + str(plan.get("conseil", ""))])
	liens.append(["Dossier adverse →", _ouvrir_preparation, "MatchOpenPreparation", "Préparation, dossier de l'adversaire"])
	liens.append(["Rapport de force →", _ouvrir_preparation, "MatchOpenForces", "Préparation, rapport de force"])
	_liens(column, liens)
	return _tile_of(column)

func _ouvrir_joueur_adverse(_id: String) -> void:
	_ouvrir_preparation()

## « Mêlée : 64 contre 67 ▼ −3 » depuis `forces` (moyennes de la saison, la nôtre contre la leur) ; ligne omise sans donnée.
func _force_relative(column: VBoxContainer, data: Dictionary, nous: int) -> void:
	var forces: Variant = data.get("forces")
	if not forces is Dictionary: return
	var equipes: Array = forces.get("equipes", [])
	if equipes.size() < 2 or not equipes[0] is Dictionary or not equipes[1] is Dictionary: return
	var moi: Dictionary = equipes[nous]
	var lui: Dictionary = equipes[1 - nous]
	for axe: Array in [["melees", "Mêlée"], ["touches", "Touche"]]:
		var a: Variant = moi.get(axe[0])
		var b: Variant = lui.get(axe[0])
		if not (a is int or a is float) or not (b is int or b is float): continue
		var ecart := roundi(float(a)) - roundi(float(b))
		var signe := "▲ +%d" % ecart if ecart > 0 else "▼ −%d" % absi(ecart) if ecart < 0 else "= 0"
		var valeur := lignes("%d %% contre %d %% · %s" % [roundi(float(a)), roundi(float(b)), signe], 13, Charte.IVOIRE, 1, false, 500)
		valeur.name = "Force_" + str(axe[0])
		_rang(column, str(axe[1]), valeur)
		return

func _plan_adverse(column: VBoxContainer, plan: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "PlanAdverse"
	bloc.add_theme_constant_override("separation", 0)
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var lecteur: Dictionary = plan.get("lecteur", {}) if plan.get("lecteur") is Dictionary else {}
	var source := "Lecture de %s (%s)" % [str(lecteur.nom), str(lecteur.get("role", "staff"))] if lecteur.get("nom") is String else "Lecture du staff"
	bloc.tooltip_text = "%s, d'après leurs derniers matchs, la météo annoncée et notre feuille actuelle. Une lecture peut se tromper." % source
	column.add_child(bloc)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(8))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var puce := PanelContainer.new()
	puce.name = "PlanAdverseConfiance"
	puce.set_meta("confiance", str(plan.get("confiance", "")))
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(0)
	style.content_margin_left = M(6)
	style.content_margin_right = M(6)
	style.content_margin_top = M(1)
	style.content_margin_bottom = M(1)
	puce.add_theme_stylebox_override("panel", style)
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(texte(str(CONFIANCE.get(str(plan.get("confiance", "probable")), "Probable")).to_upper(), 12, Charte.IVOIRE, true, 700))
	ligne.add_child(puce)
	var titre := lignes(str(plan.get("titre", "")), 13, Charte.IVOIRE, 1, false, 700)
	titre.name = "PlanAdverseTitre"
	C.fill(titre)
	ligne.add_child(titre)
	_rang(bloc, "Plan", ligne, "PlanLigne")
	var raison := str(plan.get("raison", ""))
	var pourquoi := lignes(raison.substr(0, 1).to_upper() + raison.substr(1), 13, Charte.IVOIRE, 2, false, 500)
	pourquoi.name = "PlanAdverseRaison"
	pourquoi.tooltip_text = raison
	pourquoi.mouse_filter = Control.MOUSE_FILTER_PASS
	_rang(bloc, "Point fort", pourquoi)
## 4. Le mot de Gabi : trois clés (numéros, titre, précision), plan de jeu et causerie ; médaillon de Gabi cliquable.
func _gabi(data: Dictionary) -> Control:
	var column := _tuile("TuileGabi", "Le mot de Gabi", "%d clés" % data.get("gabi", {}).get("cles", []).size() if data.get("gabi", {}).get("cles") is Array and not data.get("gabi", {}).get("cles", []).is_empty() else "")
	var gabi: Dictionary = data.get("gabi", {})
	var phrase := lignes("« %s »" % str(gabi.get("phrase", "On prépare ce match ensemble. Trois clés pour moi :")), 13, Charte.IVOIRE_2, 2, false, 500)
	phrase.name = "GabiPhrase"
	column.add_child(phrase)
	var cles := VBoxContainer.new()
	cles.name = "GabiCles"
	cles.add_theme_constant_override("separation", M(4))
	cles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cles)
	var liste: Array = gabi.get("cles", []) if gabi.get("cles") is Array else []
	if liste.is_empty():
		cles.add_child(lignes("Gabi n'a pas de clés pour ce match.", 13, Charte.IVOIRE_2, 2))
	var rang := 0
	for cle: Dictionary in liste:
		rang += 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", M(10))
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var numero := italique(texte(str(rang), 17, Charte.IVOIRE, true, 700))
		numero.custom_minimum_size.x = M(14)
		numero.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(numero)
		var mots := VBoxContainer.new()
		mots.add_theme_constant_override("separation", 0)
		mots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(mots)
		var titre := texte(str(cle.get("titre", "")), 14, Charte.IVOIRE, false, 700)
		titre.add_theme_font_override("font", C.BODY)
		titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		titre.clip_text = true
		mots.add_child(titre)
		var detail := lignes(str(cle.get("detail", "")), 12, Charte.IVOIRE_2, 2, false, 500)
		mots.add_child(detail)
		ligne.add_child(mots)
		cles.add_child(ligne)
	_pousse(column)
	var bas := HBoxContainer.new()
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_theme_constant_override("separation", M(8))
	var liens := VBoxContainer.new()
	liens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(liens)
	liens.add_theme_constant_override("separation", M(2))
	bas.add_child(liens)
	var plan := _bouton_lien("Ouvrir le plan de jeu →", func(): _aller("Plan de jeu"), "MatchOpenPlaybook", 14)
	var causerie := _bouton_lien("Préparer la causerie →", func(): _aller("Vestiaire"), "MatchOpenTalk", 14)
	causerie.tooltip_text = "La causerie se tient au vestiaire, au coup d'envoi : l'humeur du groupe pour la préparer."
	liens.add_child(plan)
	liens.add_child(causerie)
	var medaillon := Control.new()
	medaillon.name = "GabiMedaillon"
	medaillon.custom_minimum_size = Vector2(M(84), M(56))
	medaillon.size_flags_vertical = Control.SIZE_SHRINK_END
	medaillon.set_meta("compact", true)
	bas.add_child(medaillon)
	column.add_child(bas)
	if is_instance_valid(app.get("coach")) and app.coach.has_method("installer_bandeau"): app.coach.installer_bandeau(medaillon)
	else: medaillon.hide()
	return _tile_of(column)

## Contrôle « rien ne déborde » (tests) : chaque tuile contient son contenu, l'écran tient dans sa zone.
func overflows() -> Array:
	var failures: Array = []
	for tile in find_children("*", "PanelContainer", true, false):
		if not tile.get_meta("prematch_tile", false): continue
		var inner: Control = tile.get_meta("content")
		var needed: Vector2 = tile.get_combined_minimum_size()
		if needed.y > tile.size.y + 0.5 or needed.x > tile.size.x + 0.5: failures.append("%s : %s pour %s" % [tile.name, needed, tile.size])
		if inner.get_combined_minimum_size().y > inner.size.y + 0.5: failures.append("%s : contenu %s pour %s" % [tile.name, inner.get_combined_minimum_size(), inner.size])
	var needed_all := get_combined_minimum_size()
	if needed_all.y > size.y + 0.5: failures.append("écran : %s pour %s" % [needed_all, size])
	return failures
