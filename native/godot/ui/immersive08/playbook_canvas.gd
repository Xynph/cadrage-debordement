extends Control
## Les quatre zones sont orientées depuis notre en-but. Le carnet utilise les choix du moteur.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Rules = preload("res://ui/playbook_view.gd")
const GREEN = Color("64e896")
const GOLD = Color("f7ca68")
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
	tabs.add_theme_font_size_override("font_size", C.px(28))
	var panel := C.box(Color("0c1415"), C.LINE, 7, 0)
	for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: panel.set_content_margin(edge, 0)
	tabs.add_theme_stylebox_override("panel", panel)
	tabs.add_theme_stylebox_override("tab_selected", C.box(Color("0b5435"), GREEN, 7, 16))
	tabs.add_theme_stylebox_override("tab_unselected", C.box(Color("172321"), C.LINE, 7, 16))
	tabs.add_theme_stylebox_override("tab_hovered", C.box(Color("204434"), GREEN, 7, 16))
	tabs.add_theme_color_override("font_selected_color", C.IVORY)
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
	D.text(hero, 26, 36, "LE CARNET TACTIQUE", 27, GOLD, 700, 771)
	app.heading = D.text(hero, 24, 102, "Un plan pour chaque terrain.", 69, C.IVORY, 800, 1132)
	D.text(hero, 28, 145, "Consignes par zone · Mêlées · Touches · Renvois", 25, C.IVORY, 500, 1059)
	var general: Dictionary = data.get("general", {})
	_metric(hero, Rect2(28, 156, 490, 30), "Attaque principale", general.get("attackLabel", "—"), GREEN)
	_metric(hero, Rect2(530, 156, 500, 30), "Défense principale", general.get("defenceLabel", "—"), GOLD)
	var back := D.button(hero, Rect2(1845, 127, 381, 53), "Consignes principales", func():
		if not app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation = {"tab":1,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
		else: app.management_ui.preparation.tab = 1
		app._navigate("Préparation"), true, "arrow", false, Color("09673e"), "PlaybookOpenPreparation")
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
		for j in 2:
			var key: String = ["attack", "defence"][j]
			var options: Array = data.get(["attackOptions", "defenceOptions"][j], [])
			var effective: String = zone.get(["effectiveAttack", "effectiveDefence"][j], "")
			var chosen: String = str(zone.get(key, "inherit"))
			var top := 109 + j * 140
			_metric(tile, Rect2(22, top, 702, 29), "Attaque" if j == 0 else "Défense", _option_title(options, effective), GREEN if j == 0 else GOLD)
			_selector(tile, Rect2(22, top + 38, 703, 50), key, options, chosen, str(zone.id))
			var label := _description(options, chosen)
			var lines := D.words(label, 82, 2)
			for k in lines.size(): D.text(tile, 24, top + 112 + k * 23, lines[k], 20, C.MUTED, 500, 700)
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
		D.rect(field, Rect2(53, y - 24, 414, 49), Color("103127"), 5, GREEN if field.current == i else Color("45675a"))
		D.text(field, 260, y + 11, "%02d  ·  %s" % [i + 1, zones[i].label], 29, C.IVORY, 700, 391, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 346, 763, "VOTRE EN-BUT", 21, GREEN, 700, 602, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 346, 797, "Orientation selon votre équipe", 21, C.MUTED, 500, 602, HORIZONTAL_ALIGNMENT_CENTER)

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
		D.text(tile, 23, 228, "LES OPTIONS DE SIMULATION", 22, GOLD, 700, 667)
		var y := 247
		for option: Dictionary in options:
			var selected: bool = option.id == choice
			D.rect(tile, Rect2(20, y, 684, 94), Color("0c3227") if selected else Color("172321"), 5, Color(GREEN, .67) if selected else Color(C.LINE, .5))
			D.text(tile, 37, y + 29, option.label, 26, GREEN if selected else C.IVORY, 700, 643)
			var lines := D.words(str(option.get("description", "")), 72, 2)
			for j in lines.size(): D.text(tile, 37, y + 57 + j * 25, lines[j], 22, C.MUTED, 500, 643)
			y += 103
	D.photo(phase_page, "tactics-briefing", Rect2(16, 698, 2213, 153))
	_notice(phase_page, 872)

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
	var scene := D.panel(advice_page, Rect2(1476, 16, 755, 826), "Lecture du rapport de force", "tactic", "", "PlaybookAdviceContext")
	D.photo(scene, "tactics-briefing", Rect2(14, 67, 727, 200))
	var general: Dictionary = data.get("general", {})
	_metric(scene, Rect2(21, 288, 709, 55), "Attaque principale", general.get("attackLabel", "—"), GREEN)
	_metric(scene, Rect2(21, 355, 709, 55), "Défense principale", general.get("defenceLabel", "—"), GOLD)
	var context := "AVANT LE MATCH"
	if data.get("inMatch", false): context = "MATCH EN COURS"
	D.chip(scene, Rect2(21, 433, 321, 43), context, GREEN)
	var lines := D.words(str(data.get("reason", "")), 79, 4)
	for i in lines.size(): D.text(scene, 22, 531 + i * 31, lines[i], 24, C.MUTED, 500, 701)
	D.button(scene, Rect2(21, 729, 709, 62), "Ouvrir le match", func(): app._navigate("Match"), true, "arrow", false, Color("09673e"), "PlaybookGoMatch")
	_notice(advice_page, 872)

func _notice(parent: Node, y: int) -> void:
	var tile := D.panel(parent, Rect2(15, y, 2216, 60), "", "", "", "PlaybookNotice")
	var text := str(data.get("notice", "")) if available else str(data.get("reason", ""))
	if text.is_empty() and app.waiting: text = "Décision en cours de traitement…"
	D.text(tile, 21, 41, text, 24, C.MUTED if available else C.ALERT, 500, 2173)

func _selector(parent: Node, rectangle: Rect2, key: String, options: Array, selected: String, zone: String = "") -> void:
	var control := OptionButton.new()
	control.name = "Playbook_" + zone + "_" + key
	control.accessibility_name = key if zone.is_empty() else "%s · %s" % [zone, key]
	control.fit_to_longest_item = false
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.disabled = not available
	control.add_theme_font_override("font", C.BOLD)
	control.add_theme_font_size_override("font_size", C.px(24))
	control.add_theme_color_override("font_color", C.IVORY)
	control.add_theme_color_override("font_hover_color", C.IVORY)
	control.add_theme_color_override("font_disabled_color", C.MUTED)
	control.add_theme_stylebox_override("normal", C.box(Color("162723"), C.LINE, 6, 13))
	control.add_theme_stylebox_override("hover", C.box(Color("204434"), GREEN, 6, 13))
	control.add_theme_stylebox_override("disabled", C.box(Color("111c1b"), C.LINE, 6, 13))
	control.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, GOLD, 6, 0))
	var popup := control.get_popup()
	popup.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 5, 10))
	popup.add_theme_font_override("font", C.DISPLAY)
	popup.add_theme_font_size_override("font_size", C.px(23))
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
	var tile := D.rect(parent, rectangle, Color("132721"), 5, Color(C.LINE, .80))
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
