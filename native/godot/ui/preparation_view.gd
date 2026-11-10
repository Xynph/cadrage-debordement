extends VBoxContainer
# Reading state belongs to the application UI, never the career or its RNG.
const G = preload("res://ui/carnet_skin.gd")
const Decisions = preload("res://ui/decision_views.gd")
const TABS = ["Dossier", "Consignes", "Entrainement"]
var app: Control
var state: Dictionary
var sections: Array[Control] = []
var tabs: Array[Button] = []
var tab_style: StyleBox
var tab_pressed_style: StyleBox
var restoring := true

static func build(application: Control) -> Control:
	var page := new()
	page.app = application
	page.name = "CarnetPreparation"
	G.fill(page, true)
	page.add_theme_constant_override("separation", 14)
	if not application.management_ui.get("preparation") is Dictionary:
		application.management_ui.preparation = {"tab":0,"outer":[0,0,0],"attack":0,"defense":0,"focus":["","",""]}
	page.state = application.management_ui.preparation
	page._build()
	return page

func _build() -> void:
	var bar := G.h(8)
	bar.name = "PreparationTabs"
	add_child(bar)
	for i in TABS.size():
		var button := G.button(["DOSSIER", "CONSIGNES", "ENTRAÎNEMENT"][i], func(): _choose(i))
		button.name = "PreparationTab" + TABS[i]
		button.toggle_mode = true
		button.tooltip_text = ["Adversaire et dossier du staff", "Avec et sans le ballon", "Charge, préparation spécifique et accès au match"][i]
		G.fill(button)
		bar.add_child(button)
		tabs.append(button)
		if tab_style == null:
			tab_style = button.get_theme_stylebox("normal")
			tab_pressed_style = button.get_theme_stylebox("pressed")
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT, KEY_RIGHT]:
				var next := posmod(i + (1 if event.keycode == KEY_RIGHT else -1), TABS.size())
				_choose(next)
				tabs[next].grab_focus()
				button.accept_event())
	for id in TABS:
		var section := G.v(14)
		section.name = "Preparation" + id
		G.fill(section, true)
		add_child(section)
		sections.append(section)
	Decisions.dossier_summary(app, sections[0])
	_consigne(sections[1])
	_training(sections[2])
	_observe(self)
	# The shell owns the outer viewport; each section remembers its own position.
	app.body_scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
		if not restoring: state.outer[int(state.tab)] = int(value))
	_show_tab()
	_restore.call_deferred()

func _consigne(parent: Control) -> void:
	var tactics: Dictionary = app.model.get("tactics", {})
	var row := G.h(14)
	G.fill(row, true)
	parent.add_child(row)
	for pair in [["attack","attacks","03","Avec le ballon","Attack"],["defense","defenses","04","Sans le ballon","Defense"]]:
		var card := G.panel(row)
		G.fill(card.get_parent(), true)
		G.chapter(card, pair[2], pair[3], "Votre intention de jeu pour la rencontre", app.accent)
		var list := G.scroll(card)
		var scroll: ScrollContainer = list.get_parent()
		scroll.name = "Preparation" + pair[4] + "Scroll"
		scroll.custom_minimum_size.y = 190
		scroll.get_v_scroll_bar().value_changed.connect(func(value: float):
			if not restoring: state[pair[0]] = int(value))
		for option in tactics.get(pair[1], []):
			var button := G.button(str(option.label).to_upper(), func():
				var current: Dictionary = app.model.get("tactics", {})
				var data: Dictionary = {"attack":current.get("attack","equilibre"),"defense":current.get("defense","equilibre")}
				data[pair[0]] = option.id
				app._command("set_tactics", data))
			button.name = "Preparation" + pair[4] + "_" + str(option.id)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.set_meta("tactic_id", str(option.id))
			if tactics.get(pair[0]) == option.id: G.selected(button, app.accent)
			button.disabled = not app._live().is_empty() and not app._live().get("paused", false)
			list.add_child(button)
			list.add_child(G.wrap(option.get("description", ""), 14))
			list.add_child(G.separator())

func _training(parent: Control) -> void:
	var training := G.panel(parent)
	# Keep the whole training form and match access above the fold at 720p 1:1.
	training.add_theme_constant_override("separation", 9)
	training.add_child(G.section("Le travail de la semaine", "La séance collective agit sur la récupération et le développement."))
	var choices := G.h(12)
	training.add_child(choices)
	for pair in [["repos","RÉCUPÉRATION"],["normal","CHARGE NORMALE"],["intense","INTENSIVE"]]:
		var button := G.button(pair[1], func(): app._command("train", {"mode":pair[0]}))
		button.name = "PreparationTrain_" + pair[0]
		G.fill(button)
		button.disabled = app.model.meta.get("trained", false) or not app._live().is_empty()
		choices.add_child(button)
	if app.model.meta.get("trained", false): training.add_child(G.label("Séance déjà effectuée cette semaine.", 14, G.GOOD))
	Decisions.training(app, training)
	var match_button := G.button("ALLER AU JOUR DE MATCH  →", func(): app._navigate("Match"), true)
	match_button.name = "PreparationMatch"
	training.add_child(match_button)

func _observe(node: Node) -> void:
	if node is BaseButton and node.focus_mode != Control.FOCUS_NONE:
		node.focus_entered.connect(func():
			if not restoring:
				var index := tabs.find(node) if node in tabs else int(state.tab)
				state.focus[index] = str(node.name))
	for child in node.get_children(): _observe(child)

func _choose(index: int) -> void:
	if int(state.tab) == index:
		tabs[index].set_pressed_no_signal(true)
		return
	state.outer[int(state.tab)] = app.body_scroll.scroll_vertical
	state.tab = index
	restoring = true
	_show_tab()
	app._observe_navigation()
	# Tab selection keeps focus on the tab; Tab then enters its visible content.
	_restore.call_deferred(false)

func _show_tab() -> void:
	for i in TABS.size():
		sections[i].visible = i == int(state.tab)
		tabs[i].set_pressed_no_signal(i == int(state.tab))
		if i == int(state.tab):
			G.selected(tabs[i], app.accent)
			tabs[i].add_theme_stylebox_override("pressed", tabs[i].get_theme_stylebox("normal"))
		elif tabs[i].has_meta("carnet_selection_skin"):
			G.clear_selection(tabs[i])
		else:
			tabs[i].add_theme_stylebox_override("normal", tab_style)
			tabs[i].add_theme_stylebox_override("pressed", tab_pressed_style)

func _restore(restore_focus: bool = true) -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	if tree == null: return
	await tree.process_frame
	await tree.process_frame
	if not is_inside_tree(): return
	var index := int(state.tab)
	for pair in [["PreparationAttackScroll","attack"],["PreparationDefenseScroll","defense"]]:
		var scroll: ScrollContainer = find_child(pair[0], true, false)
		scroll.scroll_vertical = int(state[pair[1]])
	app.body_scroll.scroll_vertical = int(state.outer[index])
	if restore_focus and not str(state.focus[index]).is_empty():
		var control: Control = find_child(str(state.focus[index]), true, false)
		if control != null and control.is_visible_in_tree():
			if control is BaseButton and control.disabled:
				tabs[index].grab_focus()
				state.focus[index] = str(tabs[index].name)
			else: control.grab_focus()
	restoring = false
