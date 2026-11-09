extends Control
## Le journal, la conférence et ses archives gardent leurs décisions et leur brouillon.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/data_semantics.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Press = preload("res://ui/press_view.gd")
const People = preload("res://ui/press_people_view.gd")
const WIDTH := 2248
const LEFT := 1500
const RIGHT := 732
const PRIMARY := Color("106d43")
const TABS := ["Journal", "Conférence", "Historique", "Portraits"]
const TAB_ICONS := ["mail", "people", "calendar", "shield"]

var app: Control
var data: Dictionary
var tabs: TabContainer
var controls: Array[Button] = []
var draft_status: Label
var active := 0

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/press_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()

func _build() -> void:
	name = "CarnetPresse"
	data = app.model.get("clubLife", {}).get("press", {})
	active = clampi(int(app.management_ui.get("press_tab", 0)), 0, TABS.size() - 1)
	_hero()
	_nav()
	if data.is_empty():
		var panel := D.panel(self, Rect2(0, 405, WIDTH, 819), "Journal indisponible", "mail", "", "PressEmpty")
		D.text(panel, 24, 115, "Le journal sera disponible après création d’une carrière.", 31, C.MUTED, 500, WIDTH - 50)
		return
	_desk()
	_sidebar()

func _hero() -> void:
	var hero := D.panel(self, Rect2(0, 0, WIDTH, 315), "", "", "", "PressHero")
	hero.clip_contents = true
	D.photo(hero, "press-room", Rect2(787, 0, 1461, 315))
	C.veil(hero)
	D.text(hero, 28, 47, "LA VOIX DU CLUB", 31, C.GOLD, 800, 232)
	D.line(hero, Vector2(263, 34), Vector2(412, 34), C.GOLD, 2)
	D.text(hero, 22, 125, "Troisième Mi-Temps.", 86, C.IVORY, 800, 1130)
	var context: Dictionary = data.get("context", {})
	var subhead := G.club_name(app.model.club) + "  ·  Saison " + S.count_text(context.get("season"))
	if S.count_text(context.get("week")) != "—": subhead += "  ·  Semaine " + G.n(int(context.week) + 1)
	D.text(hero, 29, 166, subhead, 30, C.IVORY, 500, 1130)
	D.text(hero, 29, 202, "Le journal de la compétition et les échanges avec les médias.", 26, C.MUTED, 500, 1110)
	var metrics: Dictionary = data.get("metrics", {})
	for i in 5:
		var key: String = ["morale", "trust", "mediaTrust", "fanTrust", "boardPressure"][i]
		var label: String = ["Moral", "Direction", "Médias", "Supporters", "Pression"][i]
		var tint := C.AMBER if i == 4 else C.MINT
		var card := D.rect(hero, Rect2(28 + i * 292, 220, 276, 74), Color("142420"), 7, Color(tint, .53))
		_icon(card, ["heart", "shield", "mail", "people", "warning"][i], Rect2(14, 20, 32, 32), tint)
		D.text(card, 60, 31, label, 25, C.MUTED, 600, 123)
		var value := S.count_text(metrics.get(key))
		D.text(card, 256, 36, value + " / 100" if value != "—" else "—", 26, tint, 700, 92, HORIZONTAL_ALIGNMENT_RIGHT)
		if value != "—": D.bar(card, Rect2(62, 53, 192, 8), float(value), tint)

func _nav() -> void:
	for i in TABS.size():
		var button := D.button(self, Rect2(i * 289, 334, 275, 55), TABS[i], func(): _select(i), i == active, TAB_ICONS[i], false, PRIMARY, "PressCanvasTab" + str(i))
		button.disabled = data.is_empty()
		controls.append(button)
	for entry: Array in [[1520, "Classements", "trophy"], [1766, "Calendrier", "calendar"], [2012, "Rivalités", "shield"]]:
		var destination: String = entry[1]
		D.button(self, Rect2(entry[0], 339, 236, 45), destination, func(): app._navigate(destination), false, entry[2], true, PRIMARY, "Section_" + destination)

func _desk() -> void:
	var card := D.panel(self, Rect2(0, 405, LEFT, 819), "", "", "", "PressDesk")
	var headline := D.text(card, 58, 37, _heading(active), 30, C.IVORY, 800, LEFT - 80)
	headline.name = "PressDeskTitle"
	_icon(card, "mail", Rect2(18, 13, 28, 28), C.GOLD)
	D.line(card, Vector2(15, 55), Vector2(LEFT - 15, 55))
	tabs = TabContainer.new()
	tabs.name = "PressTabs"
	tabs.tabs_visible = false
	tabs.clip_contents = true
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	card.add_child(tabs)
	D.place(tabs, Rect2(17, 66, LEFT - 34, 736))
	if data.conference.get("available",false): Press._conference_draft(app,data)
	for title in ["Journal","Conférence","Historique","Relations"]:
		var slot := Control.new()
		slot.name = title
		tabs.add_child(slot)
	tabs.current_tab = active
	Legacy.apply(tabs, PRIMARY)
	_mount(active)
	tabs.tab_changed.connect(func(index: int):
		active = index
		app.management_ui.press_tab = index
		_mount(index)
		headline.text = _heading(index)
		_mark_tabs())

func _mount(index: int) -> void:
	var slot := tabs.get_tab_control(index)
	if slot.get_child_count() != 0: return
	var page: Control
	match index:
		0: page = Press._journal(app,data)
		1: page = Press._conference(app,data)
		2: page = Press._history(app,data)
		3: page = People.build(app,data)
		_: return
	slot.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Legacy.apply(page, PRIMARY)
	for answer: Button in page.find_children("PressAnswer_*", "Button", true, false):
		answer.pressed.connect(_update_draft)

func _sidebar() -> void:
	var conference: Dictionary = data.get("conference", {})
	var section := D.panel(self, Rect2(LEFT + 16, 405, RIGHT, 437), "La salle de presse", "people", "", "PressConferenceBrief")
	var picture := D.photo(section, "press-room", Rect2(16, 67, RIGHT - 32, 158))
	picture.tooltip_text = "Illustration fictive d’une conférence de presse"
	var available: bool = conference.get("available", false)
	var questions: Array = conference.get("questions", [])
	var status := "Conférence ouverte" if available else "Conférence indisponible"
	D.text(section, 19, 266, status, 33, C.IVORY, 800, RIGHT - 38)
	var context := "%d question(s) à préparer" % questions.size() if available else str(conference.get("reason", ""))
	D.text(section, 19, 304, context, 25, C.MUTED, 500, RIGHT - 40)
	draft_status = D.text(section, 19, 341, "", 23, C.GOLD, 600, RIGHT - 36)
	draft_status.name = "PressDraftStatus"
	_update_draft()
	D.button(section, Rect2(17, 368, RIGHT - 34, 53), "Préparer la conférence" if available else "Consulter le compte rendu", func(): _select(1), true, "arrow", false, PRIMARY, "OpenPressConference")
	var memory := D.panel(self, Rect2(LEFT + 16, 858, RIGHT, 366), "Mémoire des échanges", "calendar", "", "PressMemoryBrief")
	var history: Array = data.get("history", [])
	var people: Array = data.get("people", [])
	var notes := D.rect(memory, Rect2(17, 68, RIGHT - 34, 82), Color("142420"), 7, C.LINE)
	D.text(notes, 19, 34, "%d déclaration(s) conservée(s)" % history.size(), 31, C.IVORY, 700, RIGHT - 72)
	D.text(notes, 20, 65, "%d journaliste(s) et personnage(s)" % people.size(), 25, C.MUTED, 500, RIGHT - 72)
	var notice := C.wrap(str(data.get("notice", "")), 21, C.MUTED)
	memory.add_child(notice)
	D.place(notice, Rect2(22, 167, RIGHT - 44, 100))
	D.button(memory, Rect2(17, 298, 335, 49), "Historique des conférences", func(): _select(2), false, "calendar", true, PRIMARY, "OpenPressHistory")
	D.button(memory, Rect2(365, 298, 350, 49), "Portraits et relations", func(): _select(3), false, "people", true, PRIMARY, "OpenPressPeople")

func _select(index: int) -> void:
	if tabs != null: tabs.current_tab = index

func _mark_tabs() -> void:
	for i in controls.size():
		var style := D.surface(275, 55, Color("1a6744") if i == active else Color("182426"), Color("0b3928") if i == active else Color("101819"), Color("79cf99") if i == active else C.LINE, 6)
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(18)
		controls[i].add_theme_stylebox_override("normal", style)

func _update_draft() -> void:
	if draft_status == null: return
	var draft: Dictionary = app.get_meta("press_draft_choices", {}) if data.conference.get("available",false) else {}
	draft_status.text = "%d réponse(s) en brouillon" % draft.size() if not draft.is_empty() else ""

static func _heading(index: int) -> String:
	return ["LE JOURNAL SPORTIF", "CONFÉRENCE DE PRESSE", "DÉCLARATIONS ARCHIVÉES", "PORTRAITS & RELATIONS"][index]

static func _icon(parent: Node, key: String, area: Rect2, tint: Color) -> void:
	var icon := C.icon(key, int(area.size.x), tint)
	parent.add_child(icon)
	D.place(icon, area)
