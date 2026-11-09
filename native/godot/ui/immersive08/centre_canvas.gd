extends Control
## Coque illustrée du Centre, autour des mêmes parcours et contrôles métier.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Academy = preload("res://ui/academy_pathways_view.gd")
const GREEN = Color("64e896")
const GOLD = Color("f8cd73")
const ACCENT = Color("09673e")

var app: Control
var data: Dictionary
var state: Dictionary
var restore_ready := false

static func build(application: Control, canvas: Control) -> void:
	var page := new()
	page.app = application
	page.name = "ImmersiveCentre"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1230))
	page._build()

func _build() -> void:
	data = app.model.get("clubLife", {}).get("academyPathways", {})
	if not app.management_ui.get("immersive_centre") is Dictionary:
		app.management_ui.immersive_centre = {"tab":"","scroll":{}}
	state = app.management_ui.immersive_centre
	var club: Variant = app.model.get("club", {}).get("id")
	if state.get("club") != club:
		state.clear()
		state.merge({"club":club,"tab":"","scroll":{}})
	_hero()
	_workbench()
	_summary()

func _hero() -> void:
	var hero := D.panel(self, Rect2(0, 0, 2248, 200), "", "", "", "CentreHero")
	hero.clip_contents = true
	D.photo(hero, "club-forest", Rect2(1300, 1, 946, 198))
	D.photo(hero, "academy-training", Rect2(998, 1, 790, 198))
	var shade := Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(shade)
	D.place(shade, Rect2(910, 0, 500, 200))
	C.veil(shade)
	D.text(hero, 26, 36, "LE CENTRE DE FORMATION", 28, GOLD, 700, 1120)
	app.heading = D.text(hero, 25, 111, "Les chemins de la progression.", 68, C.IVORY, 800, 1140)
	D.text(hero, 28, 151, G.club_name(app.model.club) + "  ·  Détection, mentorat et compétition junior", 25, C.IVORY, 500, 1100)
	D.chip(hero, Rect2(29, 163, 288, 30), "PARCOURS ACTIFS" if data.get("active", false) else "PARCOURS À ACTIVER", GREEN if data.get("active", false) else GOLD)
	D.button(hero, Rect2(1840, 126, 388, 56), "Revenir à la formation", func(): app._navigate("Formation"), true, "arrow", false, ACCENT, "CentreBackFormation")

func _workbench() -> void:
	var surface := D.panel(self, Rect2(0, 218, 1513, 1005), "", "", "", "CentreWorkbench")
	surface.clip_contents = true
	# Les contrôles et commandes du Centre viennent de la vue métier partagée.
	# Son onglet international peut évoluer sans recopier ni figer sa structure.
	var controls := Academy.build(app)
	surface.add_child(controls)
	D.place(controls, Rect2(12, 12, 1489, 981))
	Legacy.apply(controls, ACCENT)
	var tabs := controls.find_child("AcademyTabs", true, false) as TabContainer
	if tabs == null: return
	_style_tabs(tabs)
	var scrolls: Dictionary = {}
	for i in tabs.get_tab_count():
		var tab := tabs.get_tab_control(i)
		var key := str(tab.name)
		var nodes := tab.find_children("*", "ScrollContainer", true, false)
		if not nodes.is_empty():
			var scroll: ScrollContainer = nodes[0]
			scrolls[key] = scroll
			scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
				if restore_ready: state.scroll[key] = int(value))
		if key == state.tab: tabs.current_tab = i
	tabs.tab_changed.connect(func(index: int): state.tab = str(tabs.get_tab_control(index).name))
	_restore.call_deferred(scrolls)

func _style_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_font_override("font", C.BOLD)
	tabs.add_theme_font_size_override("font_size", C.px(24))
	var selected := C.box(Color("0b5435"), GREEN, 6, 12)
	var unselected := C.box(Color("152322"), C.LINE, 6, 12)
	var hover := C.box(Color("204634"), GREEN, 6, 12)
	for style: StyleBoxFlat in [selected, unselected, hover]:
		style.content_margin_top = C.px(8)
		style.content_margin_bottom = C.px(8)
	tabs.add_theme_stylebox_override("tab_selected", selected)
	tabs.add_theme_stylebox_override("tab_unselected", unselected)
	tabs.add_theme_stylebox_override("tab_hovered", hover)
	tabs.add_theme_color_override("font_selected_color", C.IVORY)
	tabs.add_theme_color_override("font_unselected_color", C.MUTED)
	tabs.add_theme_color_override("font_hovered_color", C.IVORY)

func _restore(scrolls: Dictionary) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree(): return
	for key: String in scrolls:
		var scroll: ScrollContainer = scrolls[key]
		scroll.scroll_vertical = int(state.scroll.get(key, 0))
	restore_ready = true

func _summary() -> void:
	var active: bool = data.get("active", false)
	var panel := D.panel(self, Rect2(1531, 218, 717, 596), "Le tableau du centre", "school", "", "CentreStatus")
	var facts := [
		["ESPOIRS SUIVIS", G.n(data.get("players", []).size()), "people", GREEN],
		["ENVELOPPE JUNIOR", G.euros(data.recruitBudget) if data.has("recruitBudget") else "—", "money", GOLD],
		["COHÉSION DU CENTRE", G.n(data.get("cohesion", "—")), "heart", GREEN],
		["RÉPUTATION SIMULÉE", G.n(data.get("reputation", "—")), "star", GOLD],
	]
	for i in facts.size():
		var entry: Array = facts[i]
		var rect := Rect2(18 + (i % 2) * 345, 73 + floori(i / 2.0) * 108, 334, 97)
		var tile := D.panel(panel, rect)
		var icon := C.icon(entry[2], 32, entry[3])
		tile.add_child(icon)
		D.place(icon, Rect2(15, 27, 32, 32))
		D.text(tile, 61, 35, entry[0], 21, C.MUTED, 700, 265)
		D.text(tile, 61, 75, entry[1], 35, entry[3], 700, 262)
	D.line(panel, Vector2(17, 293), Vector2(699, 293))
	D.text(panel, 22, 339, "SAISON JUNIOR", 24, GOLD, 700, 660)
	var round := "Parcours à activer"
	if active:
		round = "%s / %s périodes" % [G.n(data.get("juniorRound", "—")), G.n(data.get("totalRounds", "—"))]
	D.text(panel, 22, 394, round, 39, C.IVORY, 700, 672)
	var note := str(data.get("description", "Le centre est disponible dans une carrière active."))
	var lines := D.words(note, 69, 3)
	for i in lines.size(): D.text(panel, 23, 439 + i * 27, lines[i], 23, C.MUTED, 500, 675)
	D.button(panel, Rect2(21, 522, 676, 55), "Consulter les Espoirs", func(): app._navigate("Formation"), false, "arrow", false, ACCENT, "CentreOpenAcademy")
	var lower := D.panel(self, Rect2(1531, 832, 717, 391), "De l’académie à l’équipe première", "trophy", "", "CentreDevelopment")
	D.photo(lower, "academy-training", Rect2(14, 70, 689, 211))
	var places := G.n(data.get("places", "—"))
	D.text(lower, 22, 328, "Places professionnelles disponibles", 26, C.IVORY, 700, 480)
	D.text(lower, 689, 340, places, 43, GREEN, 800, 183, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(lower, 23, 365, "La capacité tient compte des places réservées aux retours de prêt.", 20, C.MUTED, 500, 673)
