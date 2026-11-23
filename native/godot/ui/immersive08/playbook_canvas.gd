extends Control
## Les quatre zones sont orientées depuis notre en-but. Le carnet utilise les choix du moteur.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Rules = preload("res://ui/playbook_view.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const GREEN = Charte.VERT_CLAIR
const GOLD = Charte.DORE
const TABS = ["Les quatre zones", "Phases arrêtées", "Lecture du match"]

class Field extends Control:
	var current := -1

	func _draw() -> void:
		var edges := [1.0, .78, .50, .22, 0.0]
		var colors := [Color("124934"), Color("18573d"), Color("154f38"), Color("1b5e43")]
		for i in 4:
			var start: float = edges[i + 1]
			var end: float = edges[i]
			draw_rect(Rect2(0, size.y * start, size.x, size.y * (end - start)), Color("287a4d") if i == current else colors[i])
		var chalk := Color("dce7cb", .80)
		var width := maxf(1.0, C.density * 2.0)
		draw_rect(Rect2(0, 0, size.x, size.y), chalk, false, width)
		for y: float in [.22, .50, .78]:
			draw_line(Vector2(0, size.y * y), Vector2(size.x, size.y * y), chalk, width)
		for y: float in [.11, .4, .60, .89]:
			draw_dashed_line(Vector2(0, size.y * y), Vector2(size.x, size.y * y), Color(chalk, .44), width, C.px(15))
		for x: float in [.085, .915]:
			draw_dashed_line(Vector2(size.x * x, 0), Vector2(size.x * x, size.y), Color(chalk, .46), width, C.px(15))

## Bande du terrain d'une carte de zone : de ton en-but (gauche) à l'en-but adverse (droite), la zone de la carte en clair.
class Bande extends Control:
	var indice := 0
	var actuelle := false

	func _draw() -> void:
		var largeur := size.x / 4.0
		for i in 4:
			var zone := Rect2(i * largeur + 1.0, 0, largeur - 2.0, size.y)
			var choisie := i == indice
			var fond := Charte.PANNEAU_3
			if choisie: fond = Charte.VERT_CLAIR if actuelle else Charte.IVOIRE_2
			draw_rect(zone, fond)
			draw_string(C.BOLD, Vector2(zone.position.x, size.y * .72), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, zone.size.x, maxi(12, int(size.y * .55)), Charte.PANNEAU if choisie else Charte.IVOIRE_3)

var app: Control
var data: Dictionary
var available := false
var zone_page: Control
var phase_page: Control
var advice_page: Control

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.name = "ImmersivePlaybook"
	page.app = application
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

func _build() -> void:
	data = app.model.get("clubLife", {}).get("playbook", {})
	available = data.get("available", false) and not app.waiting
	_header()
	if data.get("zones", []).is_empty():
		var empty := D.panel(self, Rect2(0, 229, 2248, 473), "Le carnet de jeu", "tactic")
		D.text(empty, 24, 124, data.get("reason", "Carnet indisponible dans cette carrière."), 31, C.IVORY, 600, 2163)
		D.photo(empty, "tactics-briefing", Rect2(22, 161, 2203, 289))
		return
	var tabs := TabContainer.new()
	tabs.name = "PlaybookTabs"
	tabs.add_theme_font_override("font", C.BOLD)
	tabs.add_theme_font_size_override("font_size", C.font_px(28))
	var panel := C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 0)
	for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: panel.set_content_margin(edge, 0)
	tabs.add_theme_stylebox_override("panel", panel)
	tabs.add_theme_stylebox_override("tab_selected", C.box(Charte.IVOIRE, Color.TRANSPARENT, Charte.RAYON_PILULE, 16))
	tabs.add_theme_stylebox_override("tab_unselected", C.box(Color.TRANSPARENT, Color.TRANSPARENT, Charte.RAYON_PILULE, 16))
	tabs.add_theme_stylebox_override("tab_hovered", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_PILULE, 16))
	tabs.add_theme_color_override("font_selected_color", Charte.PANNEAU)
	tabs.add_theme_color_override("font_unselected_color", C.MUTED)
	tabs.add_theme_color_override("font_hovered_color", C.IVORY)
	add_child(tabs)
	D.place(tabs, Rect2(0, 211, 2248, 1012))
	zone_page = _tab(tabs, TABS[0])
	phase_page = _tab(tabs, TABS[1])
	advice_page = _tab(tabs, TABS[2])
	_zones()
	_phases()
	_advice()
	tabs.current_tab = clampi(int(app.management_ui.get("playbook_tab", 0)), 0, TABS.size() - 1)
	tabs.tab_changed.connect(func(index: int): app.management_ui.playbook_tab = index)

func _header() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 195), "", "", "", "PlaybookHero")
	hero.clip_contents = true
	D.photo(hero, "tactics-briefing", Rect2(1068, 1, 1178, 192))
	var shadow := Control.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(shadow)
	D.place(shadow, Rect2(1030, 1, 480, 192))
	C.veil(shadow)
	app.heading = D.text(hero, 24, 112, "PLAN DE JEU", 69, C.IVORY, 800, 1132)
	app.heading.add_theme_font_override("font", Charte.TITRE_FICHE)
	# La règle des consignes locales passe derrière un « i » à côté du surtitre.
	var regle := _notice_text()
	if not regle.is_empty() and available: Pastilles.poser(hero, Pastilles.info(regle, "i", "PlaybookRuleInfo"), 390, 70)
	var general: Dictionary = data.get("general", {})
	_metric(hero, Rect2(28, 156, 490, 30), "Attaque principale", general.get("attackLabel", "—"), GREEN)
	_metric(hero, Rect2(530, 156, 500, 30), "Défense principale", general.get("defenceLabel", "—"), GOLD)
	var back := D.button(hero, Rect2(1845, 127, 381, 53), "Consignes principales", func():
		if not app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation = {"tab":1,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
		else: app.management_ui.preparation.tab = 1
		app._navigate("Préparation"), false, "arrow", false, Color("09673e"), "PlaybookOpenPreparation")
	back.tooltip_text = "Régler les intentions de jeu avec et sans le ballon"

func _tab(parent: TabContainer, caption: String) -> Control:
	var page := Control.new()
	page.name = caption
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	return page

func _zones() -> void:
	var zones: Array = data.get("zones", [])
	for i in zones.size():
		var zone: Dictionary = zones[i]
		var x := 15 + (i % 2) * 762
		var y := 16 + floori(i / 2.0) * 421
		var active: bool = data.get("currentZone") == zone.id
		var tile := D.panel(zone_page, Rect2(x, y, 747, 405), "%02d  /  %s" % [i + 1, zone.label], "flag", "", "PlaybookZone_" + str(zone.id))
		D.text(tile, 23, 91, "ZONE ACTUELLE" if active else "PRIORITÉ LOCALE", 21, GREEN if active else C.MUTED, 700, 700)
		var bande := Bande.new()
		bande.name = "PlaybookZoneBande_" + str(zone.id)
		bande.indice = i
		bande.actuelle = active
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(bande)
		D.place(bande, Rect2(747 - 22 - 240, 14, 240, 30))
		for j in 2:
			var key: String = ["attack", "defence"][j]
			var options: Array = data.get(["attackOptions", "defenceOptions"][j], [])
			var effective: String = zone.get(["effectiveAttack", "effectiveDefence"][j], "")
			var chosen: String = str(zone.get(key, "inherit"))
			var top := 109 + j * 140
			_metric(tile, Rect2(22, top, 702, 29), "Attaque" if j == 0 else "Défense", _option_title(options, effective), GREEN if j == 0 else GOLD)
			_selector(tile, C.reach_rect(Rect2(22, top + 38, 703, 50)), key, options, chosen, str(zone.id))
			# État de la ligne : « Plan principal » (suit le choix général) ou « Consigne locale » (un clic revient au plan principal).
			var locale := chosen != "inherit"
			var retour := func(): Rules._choose(app, key, "inherit", str(zone.id))
			Pastilles.poser(tile, Pastilles.pastille("Consigne locale" if locale else "Plan principal", GREEN if locale else Charte.IVOIRE_2, "flag" if locale else "renew", "Revenir au plan principal" if locale else "Cette zone suit le plan principal", 18, "PlaybookEtat_%s_%s" % [zone.id, key], retour if locale and available else Callable()), 22, top + 98)
			# La description d'une consigne locale passe en infobulle du sélecteur (plus de phrase sous la ligne).
			var selecteur := tile.find_child("Playbook_%s_%s" % [zone.id, key], false, false)
			if selecteur != null and locale: selecteur.tooltip_text = _description(options, chosen)
	_field(zones)
	_notice(zone_page, 872)

func _field(zones: Array) -> void:
	var panel := D.panel(zone_page, Rect2(1539, 16, 692, 826), "Les zones du terrain", "tactic", "", "PlaybookPitch")
	D.text(panel, 346, 98, "EN-BUT ADVERSE", 21, GOLD, 700, 602, HORIZONTAL_ALIGNMENT_CENTER)
	var field := Field.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in zones.size():
		if zones[i].id == data.get("currentZone"): field.current = i
	panel.add_child(field)
	D.place(field, Rect2(86, 116, 520, 608))
	var centers := [.89, .64, .36, .11]
	for i in mini(centers.size(), zones.size()):
		var y: float = 608.0 * centers[i]
		D.rect(field, Rect2(53, y - 24, 414, 49), Color("103127"), Charte.RAYON_PETIT, GREEN if field.current == i else Color("45675a"))
		D.text(field, 260, y + 11, "%02d  ·  %s" % [i + 1, zones[i].label], 29, C.IVORY, 700, 391, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 346, 763, "TON EN-BUT", 21, GREEN, 700, 602, HORIZONTAL_ALIGNMENT_CENTER)

func _phases() -> void:
	var phases: Array = data.get("setPieces", [])
	var icons := ["people", "flag", "ball"]
	for i in phases.size():
		var phase: Dictionary = phases[i]
		var tile := D.panel(phase_page, Rect2(16 + i * 744, 16, 725, 665), str(phase.label), icons[i % icons.size()], "", "PlaybookPhase_" + str(phase.key))
		var options: Array = phase.get("options", [])
		var choice: String = str(phase.get("selected", ""))
		_metric(tile, Rect2(23, 74, 677, 42), "Choix retenu", _option_title(options, choice), GREEN)
		_selector(tile, Rect2(22, 135, 680, 56), str(phase.key), options, choice)
		D.text(tile, 23, 228, "LES CHOIX DE JEU", 22, GOLD, 700, 667)
		var y := 247
		for option: Dictionary in options:
			_choix(tile, y, str(phase.key), option, option.id == choice)
			y += 103
	var intentions := D.panel(phase_page, Rect2(16, 698, 1022, 153), "Repères retenus", "flag")
	for i in mini(3, phases.size()):
		var phase: Dictionary = phases[i]
		var y := 71 + i * 29
		D.text(intentions, 24, y, phase.get("label", "Phase"), 23, C.MUTED, 500, 355)
		D.text(intentions, 388, y, _option_title(phase.get("options", []), str(phase.get("selected", ""))), 25, C.IVORY, 700, 610)
	D.photo(phase_page, "lineout-analysis", Rect2(1056, 698, 1173, 153))
	_notice(phase_page, 872)

## Effets d'un choix de phase arrêtée : [icône, mot, signe] ; « + » gain (vert), « − » perte (rouge), « = » habituel.
## La phrase du moteur reste en infobulle de la ligne. Renvois : portée en mètres depuis la ligne médiane.
const EFFETS := {
	"scrum": {
		"equilibre": [["renew", "Compromis habituel", "="]],
		"securiser": [["shield", "Conservation", "+"], ["arrow", "Mètres", "−"], ["target", "Essai direct", "−"]],
		"pousser": [["arrow", "Mètres si gagnée", "+"], ["shield", "Conservation", "−"]],
	},
	"lineout": {
		"equilibre": [["renew", "Compromis habituel", "="]],
		"courte": [["shield", "Conservation", "+"], ["arrow", "Terrain", "−"]],
		"fond": [["arrow", "Mètres", "+"], ["people", "Jeu derrière", "+"], ["target", "Lancer sûr", "−"]],
		"maul": [["people", "Puissance des avants", "+"], ["shield", "Conservation", "−"]],
	},
	"kickoff": {
		"normal": [["flag", "Distance", "="], ["ball", "Contest", "="]],
		"court": [["ball", "Récupération", "+"], ["flag", "Territoire", "−"]],
		"long": [["flag", "Territoire", "+"], ["ball", "Récupération", "−"]],
	},
}
const PORTEES := {"court": Vector2(10, 14), "long": Vector2(18, 26)}

## Demi-terrain du renvoi : ligne médiane à gauche, ligne des 10 m, zone de chute du choix en clair.
class Portee extends Control:
	var zone := Vector2.ZERO
	var choisie := false

	func _draw() -> void:
		var metre := size.x / 50.0
		draw_rect(Rect2(Vector2.ZERO, size), Color("18573d"))
		var craie := Color("dce7cb", .8)
		var epais := maxf(1.0, C.density * 2.0)
		draw_line(Vector2(0, 0), Vector2(0, size.y), craie, epais * 1.5)
		draw_dashed_line(Vector2(10 * metre, 0), Vector2(10 * metre, size.y), Color(craie, .55), epais, C.px(6))
		draw_line(Vector2(28 * metre, 0), Vector2(28 * metre, size.y), Color(craie, .4), epais)
		if zone != Vector2.ZERO:
			draw_rect(Rect2(zone.x * metre, 2, (zone.y - zone.x) * metre, size.y - 4), Color(Charte.VERT_CLAIR if choisie else Charte.IVOIRE_2, .85))
		var police := C.BOLD
		var taille := maxi(11, int(size.y * .42))
		var texte := "%d–%d m" % [int(zone.x), int(zone.y)] if zone != Vector2.ZERO else "≥ 10 m"
		draw_string(police, Vector2(0, size.y * .7), texte, HORIZONTAL_ALIGNMENT_RIGHT, size.x - C.px(6), taille, Charte.IVOIRE)

## Une ligne de choix : nom + pastilles d'effet (+ portée pour les renvois) ; toute la ligne choisit l'option.
func _choix(tile: Control, y: int, cle: String, option: Dictionary, selected: bool) -> void:
	var id := str(option.id)
	D.rect(tile, Rect2(20, y, 684, 94), Charte.SELECTION if selected else Charte.PANNEAU_2, Charte.RAYON_PETIT, Color(GREEN, .67) if selected else Color(C.LINE, .5))
	var ligne := Button.new()
	ligne.name = "PlaybookChoix_%s_%s" % [cle, id]
	ligne.flat = true
	ligne.focus_mode = Control.FOCUS_ALL
	ligne.set_meta("immersive_style_applied", true)
	ligne.tooltip_text = "%s · %s" % [option.label, option.get("description", "")]
	ligne.accessibility_name = ligne.tooltip_text
	var vide := StyleBoxEmpty.new()
	var survol := C.box(Color(Charte.IVOIRE, .06), Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
	Charte.sans_ombre(survol)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PETIT, 0)
	Charte.sans_ombre(focus)
	focus.set_border_width_all(2)
	for etat in ["normal", "disabled", "pressed"]: ligne.add_theme_stylebox_override(etat, vide)
	ligne.add_theme_stylebox_override("hover", survol)
	ligne.add_theme_stylebox_override("focus", focus)
	ligne.disabled = not available or selected
	ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not ligne.disabled else Control.CURSOR_ARROW
	ligne.pressed.connect(func(): Rules._choose(app, cle, id))
	tile.add_child(ligne)
	D.place(ligne, Rect2(20, y, 684, 94))
	D.text(tile, 37, y + 33, option.label, 26, GREEN if selected else C.IVORY, 700, 420 if PORTEES.has(id) or cle == "kickoff" else 643)
	if cle == "kickoff":
		var portee := Portee.new()
		portee.name = "PlaybookPortee_" + id
		portee.zone = PORTEES.get(id, Vector2.ZERO)
		portee.choisie = selected
		portee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(portee)
		D.place(portee, Rect2(470, y + 12, 216, 28))
	var x := 37.0
	for effet: Array in EFFETS.get(cle, {}).get(id, []):
		var signe: String = effet[2]
		var couleur: Color = Pastilles.VERT if signe == "+" else Pastilles.ROUGE if signe == "−" else Charte.IVOIRE_2
		var texte: String = effet[1] if signe == "=" else "%s %s" % [signe, effet[1]]
		var pastille := Pastilles.pastille(texte, couleur, effet[0], "", 17, "PlaybookEffet_%s_%s_%d" % [cle, id, int(x)])
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x += Pastilles.poser(tile, pastille, x, y + 50) + 8.0

func _advice() -> void:
	var analysis := D.panel(advice_page, Rect2(16, 16, 1444, 826), "Ce que voit l’adjoint", "people", "", "PlaybookAdviceAnalysis")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	analysis.add_child(scroll)
	D.place(scroll, Rect2(19, 65, 1406, 741))
	var content := C.v(12)
	C.fill(content)
	scroll.add_child(content)
	Rules._advice(app, content, data, available)
	Legacy.apply(content, Color("09673e"))
	C.reach_controls(content)
	var scene := D.panel(advice_page, Rect2(1476, 16, 755, 826), "Lecture du rapport de force", "tactic", "", "PlaybookAdviceContext")
	D.photo(scene, "analysis-room", Rect2(14, 67, 727, 200), .50)
	var general: Dictionary = data.get("general", {})
	_metric(scene, Rect2(21, 288, 709, 55), "Attaque principale", general.get("attackLabel", "—"), GREEN)
	_metric(scene, Rect2(21, 355, 709, 55), "Défense principale", general.get("defenceLabel", "—"), GOLD)
	var context := "AVANT LE MATCH"
	if data.get("inMatch", false): context = "MATCH EN COURS"
	D.chip(scene, Rect2(21, 433, 321, 43), context, GREEN)
	# Décision fermée : une pastille (cadenas + mot), la phrase du moteur en infobulle.
	var raison := str(data.get("reason", ""))
	if not raison.is_empty():
		var mot := "Match à mettre en pause" if data.get("inMatch", false) or raison.contains("pause") else "Saison terminée"
		Pastilles.poser(scene, Pastilles.pastille(mot, Pastilles.ORANGE, "lock", raison, 20, "PlaybookAdviceVerrou"), 21, 500)
	D.button(scene, Rect2(21, 729, 709, 62), "Ouvrir le match", func(): app._navigate("Match"), false, "arrow", false, Color("09673e"), "PlaybookGoMatch")
	_notice(advice_page, 872)

func _notice_text() -> String:
	return Copy.notice("playbook", data.get("notice", "")) if available else str(data.get("reason", ""))

## La règle d'usage est derrière le « i » du surtitre ; la bande ne s'affiche que pour une alerte (carnet indisponible)
## ou un traitement en cours.
func _notice(parent: Node, y: int) -> void:
	var text := _notice_text()
	if available: return
	if text.is_empty() and app.waiting: text = "Décision en cours de traitement…"
	if text.is_empty(): return
	var tile := D.panel(parent, Rect2(15, y, 2216, 60), "", "", "", "PlaybookNotice")
	D.text(tile, 21, 41, text, 24, C.ALERT, 500, 2173)

func _selector(parent: Node, rectangle: Rect2, key: String, options: Array, selected: String, zone: String = "") -> void:
	var control := OptionButton.new()
	control.name = "Playbook_" + zone + "_" + key
	control.accessibility_name = key if zone.is_empty() else "%s · %s" % [zone, key]
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.disabled = not available
	control.add_theme_font_override("font", C.BOLD)
	control.add_theme_font_size_override("font_size", C.font_px(24))
	control.add_theme_color_override("font_color", C.IVORY)
	control.add_theme_color_override("font_hover_color", C.IVORY)
	control.add_theme_color_override("font_disabled_color", C.MUTED)
	control.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_PILULE, 13))
	control.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Charte.IVOIRE_3, Charte.RAYON_PILULE, 13))
	control.add_theme_stylebox_override("disabled", C.box(Charte.PANNEAU, Charte.FILET, Charte.RAYON_PILULE, 13))
	control.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, GOLD, Charte.RAYON_PILULE, 0))
	var popup := control.get_popup()
	popup.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 5, 10))
	popup.add_theme_font_override("font", C.DISPLAY)
	popup.add_theme_font_size_override("font_size", C.font_px(23))
	popup.add_theme_color_override("font_color", C.IVORY)
	popup.add_theme_color_override("font_hover_color", C.IVORY)
	for option: Dictionary in options:
		control.add_item(str(option.label))
		control.set_item_metadata(control.item_count - 1, str(option.id))
		if option.id == selected: control.select(control.item_count - 1)
	control.item_selected.connect(func(index: int): Rules._choose(app, key, str(control.get_item_metadata(index)), zone))
	parent.add_child(control)
	D.place(control, rectangle)

func _metric(parent: Node, rectangle: Rect2, label: String, value: Variant, tone: Color) -> void:
	var tile := D.rect(parent, rectangle, Charte.PANNEAU_2, Charte.RAYON_PETIT, Color(C.LINE, .80))
	var middle := rectangle.size.y / 2.0 + 7
	D.text(tile, 12, middle, label, 21, C.MUTED, 500, rectangle.size.x * .46)
	D.text(tile, rectangle.size.x - 12, middle, value, 24, tone, 700, rectangle.size.x * .55, HORIZONTAL_ALIGNMENT_RIGHT)

func _option_title(options: Array, id: String) -> String:
	for entry: Dictionary in options:
		if entry.id == id: return str(entry.label)
	return "—"

func _description(options: Array, id: String) -> String:
	for entry: Dictionary in options:
		if entry.id == id: return str(entry.get("description", ""))
	return ""
