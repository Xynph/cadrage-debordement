extends RefCounted

const G = preload("res://ui/game_skin.gd")
const XV := ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne",
	"Troisième ligne", "Troisième ligne", "Numéro 8", "Demi de mêlée", "Demi d’ouverture",
	"Ailier", "Centre", "Centre", "Ailier", "Arrière"]
const BENCH := ["Talonneur", "Pilier gauche", "Pilier droit", "Deuxième ligne", "Troisième ligne",
	"Demi de mêlée", "Lignes arrière", "Trois-quarts / arrière"]

static func slots(international: Dictionary) -> Array:
	var choices: Variant = international.get("choicesBySlot")
	if not choices is Dictionary: return []
	var lineup: Variant = choices.get("lineup")
	var reserves: Variant = choices.get("reserves")
	if not lineup is Array or not reserves is Array or lineup.size() != XV.size() or reserves.size() != BENCH.size(): return []
	return lineup + reserves

static func normalize(draft: Array, available: Array) -> Array:
	var selected := {}
	var clean: Array = []
	clean.resize(available.size())
	for slot in mini(draft.size(), available.size()):
		var id: Variant = draft[slot]
		if id is String and available[slot] is Array and id in available[slot] and not selected.has(id):
			selected[id] = true
			clean[slot] = id
	return clean

static func _draft_key(international: Dictionary, fixture: Dictionary) -> String:
	return "%s/%s" % [international.get("nation", ""), fixture.id]

static func draft_for(app: Control, international: Dictionary, fixture: Dictionary, available: Array) -> Array:
	var state: Dictionary = app.management_ui.get("national_sheet", {})
	return normalize(state.get("draft", []) if state.get("key") == _draft_key(international, fixture) else [], available)

static func build(app: Control, international: Dictionary, fixture: Dictionary, available: Array) -> Control:
	var view := G.v(10)
	view.name = "Feuille de match"
	var players := {}
	for player: Dictionary in international.get("squad", []):
		players[player.id] = player
	var draft := draft_for(app, international, fixture, available)
	app.management_ui.national_sheet = {"key":_draft_key(international, fixture), "draft":draft}
	var suggestion: Variant = international.get("sheet")
	var suggested: Array = suggestion.get("lineup", []) + suggestion.get("reserves", []) if suggestion is Dictionary else []
	var top := G.h(12)
	view.add_child(top)
	var instructions := G.wrap("Choisissez vos joueurs par poste. Le moteur complète les places automatiques au coup d’envoi.", 15)
	G.fill(instructions)
	top.add_child(instructions)
	var reset := Button.new()
	reset.text = "Tout remettre en automatique"
	reset.name = "NationalSheetReset"
	top.add_child(reset)
	var row := G.h(12)
	view.add_child(row)
	var editors: Array[OptionButton] = []
	for group in 2:
		var list := G.panel(row)
		list.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		list.add_child(G.section("XV de départ" if group == 0 else "Remplaçants"))
		var labels := XV if group == 0 else BENCH
		for index in labels.size():
			var slot := index if group == 0 else index + XV.size()
			var field := G.h(8)
			list.add_child(field)
			var caption := "%02d · %s" % [slot + 1, labels[index]]
			var label := G.label(caption, 15)
			label.custom_minimum_size.x = 175
			field.add_child(label)
			var option := OptionButton.new()
			option.name = "NationalSheetSlot%02d" % (slot + 1)
			option.accessibility_name = caption
			option.custom_minimum_size.y = 32
			option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			option.fit_to_longest_item = false
			G.fill(option)
			field.add_child(option)
			option.add_item("Automatique")
			if available[slot] is Array:
				for id: Variant in available[slot]:
					if not players.has(id): continue
					var player: Dictionary = players[id]
					option.add_item("%s · %s · %s" % [player.name, player.pos, G.n(player.rating)])
					option.set_item_metadata(option.item_count - 1, id)
					if draft[slot] == id: option.select(option.item_count - 1)
			option.item_selected.connect(func(item: int):
				draft[slot] = option.get_item_metadata(item)
				_refresh(editors, draft, suggested, players, reset))
			editors.append(option)
	reset.pressed.connect(func():
		draft.fill(null)
		for option in editors: option.select(0)
		_refresh(editors, draft, suggested, players, reset))
	_refresh(editors, draft, suggested, players, reset)
	return view

static func _refresh(editors: Array[OptionButton], draft: Array, suggested: Array, players: Dictionary, reset: Button) -> void:
	reset.disabled = draft.all(func(id: Variant): return id == null)
	for slot in editors.size():
		var option := editors[slot]
		var id: Variant = suggested[slot] if slot < suggested.size() else null
		var player: Dictionary = players.get(id, {})
		var automatic := "Automatique"
		if not player.is_empty() and id not in draft:
			automatic += " · " + str(player.name)
		option.set_item_text(0, automatic)
		for item in range(1, option.item_count):
			id = option.get_item_metadata(item)
			option.set_item_disabled(item, id in draft and id != draft[slot])
