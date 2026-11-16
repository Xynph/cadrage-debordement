extends RefCounted
## Comparateur unique de deux joueurs (mon effectif et marché) : consultation seulement, toutes les valeurs
## proviennent de la projection courante (aucun appel au moteur). La mémoire du premier joueur est
## `management_ui.compare`, partagée avec l’Effectif et la fiche joueur.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/decision_views.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const U = preload("res://ui/management_state.gd")
const A = preload("res://ui/player_attributes.gd")
const G = preload("res://ui/game_skin.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const NotesMatch = preload("res://ui/notes_match.gd")

## Repères où l’écart désigne le meilleur des deux (qualité sportive). Âge, salaire, prime et échéance ne
## sont jamais présentés comme un avantage à eux seuls.
const HIGHER_BETTER := ["rating", "potential", "condition", "seasonNote"]

## Postes proches (même famille) : repli du second choix quand mon effectif n'a personne au poste de A.
const FAMILIES := [["Pilier gauche", "Pilier droit", "Talonneur"], ["Deuxième ligne", "Troisième ligne", "Numéro 8"], ["Demi de mêlée", "Demi d’ouverture"], ["Centre", "Ailier", "Arrière"]]
## Taille minimale lisible (px) des commandes du comparateur, comme le reste de l'interface (720p compris).
const MIN_FONT := 13

static func fs(value: float) -> int:
	return maxi(MIN_FONT, C.px(value))

static func close_position(first: String, second: String) -> bool:
	for family: Array in FAMILIES:
		if first in family and second in family: return true
	return false

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func delta(left: Variant, right: Variant, unit: String = "") -> String:
	if not numeric(left) or not numeric(right): return "Non comparable"
	var difference := float(right) - float(left)
	return ("+" if difference > 0 else "") + A.caption(snappedf(difference, 0.1)) + unit

static func own(player: Dictionary) -> bool:
	return bool(player.get("__own", false))

static func value(player: Dictionary, key: String, _reports: Dictionary = {}) -> Variant:
	if key in ["rating","potential"]: return G.knowledge_sort_value(player,key,own(player))
	if key.begins_with("attribute:"): return A.detail(player,own(player)).get(key.trim_prefix("attribute:"))
	return player.get(key)

## 0 si A est meilleur, 1 si B l’est, -1 sinon (égalité, valeur inconnue, fourchettes qui se chevauchent).
static func leader(key: String, pair: Array) -> int:
	if not (key in HIGHER_BETTER or key.begins_with("attribute:")): return -1
	if key in ["rating","potential"]:
		var first := G.knowledge_bounds(pair[0],key,own(pair[0]))
		var second := G.knowledge_bounds(pair[1],key,own(pair[1]))
		if first.is_empty() or second.is_empty(): return -1
		if float(first.min) > float(second.max): return 0
		if float(second.min) > float(first.max): return 1
		return -1
	var left: Variant = value(pair[0],key)
	var right: Variant = value(pair[1],key)
	if not numeric(left) or not numeric(right) or float(left) == float(right): return -1
	return 0 if float(left) > float(right) else 1

## Joueur prêt à afficher : copie légère portant l’appartenance à l’effectif et la moyenne de la saison.
static func prepared(app: Control, player: Dictionary, mine: bool) -> Dictionary:
	var result := player.duplicate()
	result["__own"] = mine
	if mine:
		var average: Variant = NotesMatch.joueur(app.model, str(player.get("id", ""))).get("moyenne")
		if numeric(average): result["seasonNote"] = float(average)
	return result

## Second choix par défaut : {"id", "tier"}. tier 0 = même poste dans mon effectif, 1 = poste proche dans mon effectif,
## 2 = même poste ailleurs, 3 = poste proche ailleurs, 4 = meilleur disponible.
static func second_choice(players: Array, left: String, own_ids: Array = []) -> Dictionary:
	var position := ""
	for player: Dictionary in players:
		if str(player.id) == left: position = str(player.get("pos", ""))
	for tier in 5:
		var best := -INF
		var found := ""
		for player: Dictionary in players:
			var id := str(player.id)
			if id == left: continue
			var mine := id in own_ids
			var pos := str(player.get("pos", ""))
			var fits := (mine if tier < 2 else true) and (pos == position if tier in [0, 2] else close_position(position, pos) if tier in [1, 3] else true)
			if fits and float(player.get("rating", 0)) > best:
				best = float(player.get("rating", 0))
				found = id
		if not found.is_empty(): return {"id": found, "tier": tier}
	return {"id": "", "tier": 4}

static func initial_ids(players: Array, chosen: String, saved: Array, own_ids: Array = []) -> Array[String]:
	var ids: Array[String] = []
	for player: Dictionary in players: ids.append(str(player.id))
	var left := chosen if chosen in ids else str(saved[0]) if saved.size() > 0 and str(saved[0]) in ids else ids[0] if not ids.is_empty() else ""
	var right := str(saved[1]) if saved.size() > 1 and str(saved[0]) == left and str(saved[1]) in ids and str(saved[1]) != left else ""
	if right.is_empty(): right = str(second_choice(players, left, own_ids).id)
	return [left, right]

## Mention affichée quand B n'est pas au même poste que A (choix par défaut seulement), sinon vide.
static func default_note(players: Array, left: String, right: String, own_ids: Array = []) -> String:
	var choice := second_choice(players, left, own_ids)
	if str(choice.id) != right: return ""
	match int(choice.tier):
		1: return "Aucun autre joueur de votre effectif à ce poste : B est un poste proche."
		2: return "Aucun autre joueur de votre effectif à ce poste : B vient du marché."
		3: return "Aucun joueur à ce poste : B est un poste proche."
		4: return "Aucun joueur à ce poste ni à un poste proche : B est le meilleur disponible."
	return ""

static func candidates(players: Array, query: String, position: String, chosen: Array) -> Array:
	var term := U.fold(query).strip_edges()
	return players.filter(func(player: Dictionary):
		if str(player.id) in chosen: return true
		return (position.is_empty() or player.get("pos") == position) and (term.is_empty() or U.fold(str(player.get("name", "")) + " " + str(player.get("pos", ""))).contains(term)))

## Réserve : joueurs de mon effectif d’abord, puis marché (sans doublon).
static func pool(model: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for source in ["squad", "market"]:
		for player: Dictionary in model.get(source, []):
			var id := str(player.get("id", ""))
			if id.is_empty() or seen.has(id): continue
			seen[id] = true
			result.append(player)
	return result

static func open(app: Control, chosen: String, reports: Dictionary, return_focus: String = "") -> void:
	var players: Array = pool(app.model)
	var own_ids: Array = app.model.get("squad", []).map(func(player: Dictionary): return str(player.get("id", "")))
	var width := mini(1940, maxi(620, int(app.get_viewport_rect().size.x) - 48))
	var view := D.dialog(app, "Comparer deux joueurs", "MarketComparison", width)
	var dialog: AcceptDialog = view[0]
	var content: VBoxContainer = view[1]
	var memory: Array = app.management_ui.compare
	var selected := initial_ids(players, chosen, memory, own_ids)
	memory.assign(selected.filter(func(id: String): return not id.is_empty()))
	# Un seul titre : celui de la fenêtre. Marge sous la barre, puis une ligne de lecture de l'écart.
	var top_margin := Control.new()
	top_margin.custom_minimum_size.y = C.px(8)
	content.add_child(top_margin)
	var compact := app.get_viewport_rect().size.y < 900
	var reading := C.wrap("Écart B − A : une valeur positive signifie que B est plus élevé. L’âge et le coût ne constituent pas, à eux seuls, un avantage.", 18, C.MUTED)
	reading.name = "MarketComparisonReading"
	content.add_child(reading)
	var filters := C.h(24)
	content.add_child(filters)
	var search := LineEdit.new()
	search.name = "MarketComparisonSearch"
	search.placeholder_text = "Chercher un nom ou un poste…"
	search.accessibility_name = "Chercher les joueurs à comparer"
	search.clear_button_enabled = true
	search.set_meta("immersive_style_applied", true)
	search.add_theme_font_override("font", C.BODY)
	search.add_theme_font_size_override("font_size", fs(18))
	search.custom_minimum_size.y = C.px(38)
	C.fill(search)
	filters.add_child(search)
	var same_position := CheckButton.new()
	same_position.name = "MarketComparisonSamePosition"
	same_position.text = "Même poste que A"
	same_position.accessibility_name = same_position.text
	same_position.set_meta("immersive_style_applied", true)
	same_position.add_theme_font_override("font", C.DISPLAY)
	same_position.add_theme_font_size_override("font_size", fs(18))
	same_position.button_pressed = true
	same_position.custom_minimum_size.y = C.px(38)
	filters.add_child(same_position)
	var choices := C.h(28)
	content.add_child(choices)
	var picks: Array[OptionButton] = []
	for slot in 2:
		var column := C.v(10)
		C.fill(column)
		choices.add_child(column)
		column.add_child(C.label("JOUEUR " + ["A", "B"][slot], 27, C.GOLD))
		var picker := OptionButton.new()
		picker.name = "MarketComparisonPlayer" + str(slot)
		picker.accessibility_name = "Choisir le joueur " + ["A", "B"][slot]
		picker.set_meta("immersive_style_applied", true)
		picker.add_theme_font_override("font", C.DISPLAY)
		picker.add_theme_font_size_override("font_size", fs(20))
		picker.get_popup().add_theme_font_size_override("font_size", fs(18))
		picker.custom_minimum_size.y = C.px(38)
		picker.fit_to_longest_item = false
		picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		C.fill(picker)
		column.add_child(picker)
		picks.append(picker)
	# Dictionnaire : une lambda ne modifie pas une chaîne capturée.
	var note := {"text": default_note(players, selected[0], selected[1], own_ids)}
	var count := C.wrap("", 18)
	count.name = "MarketComparisonCount"
	content.add_child(count)
	var detail := C.v(20)
	detail.name = "MarketComparisonDetails"
	content.add_child(detail)
	var redraw := func():
		_clear(detail)
		memory.assign(selected.filter(func(id: String): return not id.is_empty()))
		var pair: Array[Dictionary] = [{}, {}]
		for slot in 2:
			for player: Dictionary in players:
				if str(player.id) == selected[slot]: pair[slot] = prepared(app, player, str(player.id) in own_ids); break
		if pair[0].is_empty() or pair[1].is_empty():
			detail.add_child(C.wrap("Choisissez deux joueurs pour consulter leurs différences. Les profils indisponibles restent consultables.", 18))
			return
		if selected[0] == selected[1]:
			detail.add_child(C.wrap("Sélectionnez deux joueurs distincts.", 18, C.ALERT))
			return
		_cards(detail, pair, reports,app)
		var tabs := TabContainer.new()
		tabs.name = "MarketComparisonTabs"
		tabs.set_meta("immersive_style_applied", true)
		tabs.add_theme_font_override("font", C.BOLD)
		tabs.add_theme_font_size_override("font_size", fs(20))
		tabs.get_tab_bar().add_theme_font_size_override("font_size", fs(20))
		detail.add_child(tabs)
		var overview := C.v(6)
		overview.name = "Vue d’ensemble"
		tabs.add_child(overview)
		_header(overview)
		for field in [["Poste", "pos", ""], ["Âge", "age", " ans"], ["Niveau / 100", "rating", ""], ["Potentiel / 100", "potential", ""], ["Condition", "condition", " %"], ["Moyenne de la saison", "seasonNote", ""], ["Fin de contrat", "contractEnd", ""], ["Prime à la signature", "fee", " €"], ["Salaire "+G.salary_period(), "salary", " €"]]:
			_row(overview, str(field[0]), str(field[1]), pair, reports, str(field[2]))
		var footnote := "Pour un joueur à recruter, prime et salaire sont des demandes distinctes ; pour un joueur de votre effectif, ce sont ses conditions actuelles. Aucun contrat n’est signé depuis cette comparaison. Le potentiel provient des rapports datés. En vert : le meilleur des deux."
		if compact:
			# Petite fenêtre : la note passe en info-bulle pour que la synthèse tienne sans défilement.
			overview.tooltip_text = footnote
			reading.tooltip_text = footnote
			overview.mouse_filter = Control.MOUSE_FILTER_PASS
			reading.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			overview.add_child(C.wrap(footnote, 18))
		var attributes := C.v(8)
		attributes.name = "36 attributs"
		tabs.add_child(attributes)
		attributes.add_child(C.wrap("Notes de simulation sur 100. Le même attribut peut avoir une importance différente selon le poste.", 18))
		var group_links := C.h(18)
		attributes.add_child(group_links)
		for index in A.GROUPS.size():
			var target_id := "ComparisonAttributeGroup" + str(index)
			var jump := C.button(["Ballon et pied", "Lecture et collectif", "Physique et aérien", "Défense et conquête"][index], func():
				var target := attributes.find_child(target_id, true, false) as Control
				if target != null: _jump_to_section(target))
			jump.name = "MarketComparisonGroupJump" + str(index)
			jump.set_meta("immersive_style_applied", true)
			jump.add_theme_font_size_override("font_size", fs(16))
			jump.custom_minimum_size.y = C.px(34)
			C.fill(jump)
			group_links.add_child(jump)
		for index in A.GROUPS.size():
			var group: Array = A.GROUPS[index]
			var group_title := C.label(str(group[0]).to_upper(), 20, C.GOLD)
			group_title.name = "ComparisonAttributeGroup" + str(index)
			group_title.focus_mode = Control.FOCUS_ALL
			attributes.add_child(group_title)
			_header(attributes)
			for field in group[1]: _row(attributes, str(field[1]), "attribute:" + str(field[0]), pair, reports)
	var refresh_pickers := func():
		var position := ""
		if same_position.button_pressed:
			for player: Dictionary in players:
				if str(player.id) == selected[0]: position = str(player.get("pos", ""))
		var filtered := candidates(players, search.text, position, selected)
		count.text = "%d joueurs proposés · les deux choix restent visibles · indisponibles consultables" % filtered.size() + ("\n" + str(note.text) if not str(note.text).is_empty() else "")
		for slot in 2:
			picks[slot].clear()
			picks[slot].add_item("Choisir un joueur")
			picks[slot].set_item_metadata(0, "")
			for player: Dictionary in filtered:
				picks[slot].add_item(str(player.name) + " · " + str(player.pos) + (" · mon effectif" if str(player.id) in own_ids else " · indisponible" if not player.get("available", false) else ""))
				var index := picks[slot].item_count - 1
				picks[slot].set_item_metadata(index, str(player.id))
				picks[slot].set_item_tooltip(index, picks[slot].get_item_text(index))
				if str(player.id) == selected[slot]: picks[slot].select(index)
	for slot in 2:
		picks[slot].item_selected.connect(func(index: int):
			selected[slot] = str(picks[slot].get_item_metadata(index))
			note.text = ""
			refresh_pickers.call()
			redraw.call())
	search.text_changed.connect(func(_text: String): refresh_pickers.call())
	same_position.toggled.connect(func(_pressed: bool): refresh_pickers.call())
	refresh_pickers.call()
	redraw.call()
	dialog.canceled.connect(func(): _restore_focus(app, return_focus))
	dialog.confirmed.connect(func(): _restore_focus(app, return_focus))
	var height := mini(1220, int(app.get_viewport_rect().size.y) - 100)
	Dialogs.show_centered(dialog, Vector2i(width, height))
	_fit_height.call_deferred(dialog, content, width, height)
	dialog.add_theme_font_size_override("title_font_size", C.px(30))
	dialog.get_ok_button().add_theme_font_size_override("font_size", fs(18))
	dialog.get_ok_button().custom_minimum_size.y = C.px(34)
	FocusLater.grab(picks[1])

## Ajuste la hauteur de la fenêtre au contenu de la synthèse (jamais au-delà du maximum) : pas de grand vide sous
## le tableau en 1440p. Le défilement reste disponible pour l'onglet des 36 attributs.
static func _fit_height(dialog: AcceptDialog, content: Control, width: int, maximum: int) -> void:
	for i in 3: await dialog.get_tree().process_frame
	if not is_instance_valid(dialog) or not dialog.visible: return
	var wanted := ceili(content.get_combined_minimum_size().y) + C.px(150)
	if wanted < maximum - C.px(40):
		Dialogs.show_centered(dialog, Vector2i(width, maxi(wanted, C.px(520))))

static func _jump_to_section(target: Control) -> void:
	target.grab_focus()
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			var requested: int = ancestor.scroll_vertical + roundi(target.get_global_rect().position.y - ancestor.get_global_rect().position.y)
			ancestor.set_deferred("scroll_vertical", requested)
			return
		ancestor = ancestor.get_parent()

static func _restore_focus(app: Control, return_focus: String = "") -> void:
	if not return_focus.is_empty():
		# Ouvert depuis l’Effectif ou la fiche : la mémoire A/B a pu changer, les compteurs sont redessinés.
		app._render()
		preload("res://ui/immersive08/club_ui.gd").focus(app, return_focus)
		return
	var button := app.find_child("CompareMarket", true, false) as Button
	if button != null: FocusLater.grab(button)

static func _cards(parent: Node, pair: Array[Dictionary], reports: Dictionary,app: Control) -> void:
	var cards := C.h(28)
	parent.add_child(cards)
	for slot in 2:
		var panel := PanelContainer.new()
		panel.name = "MarketComparisonCard" + str(slot)
		panel.add_theme_stylebox_override("panel", C.box(C.RAISED, C.MINT if slot == 0 else C.GOLD, 12, 18))
		C.fill(panel)
		cards.add_child(panel)
		var body := C.v(12)
		panel.add_child(body)
		var player: Dictionary = pair[slot]
		body.add_child(C.wrap(["A · ", "B · "][slot] + str(player.get("name", "—")), 24, C.IVORY, true, 700))
		if own(player):
			var squad_status := C.wrap("Dans votre effectif · " + str(player.get("status", "")), 18, C.MINT)
			squad_status.name = "MarketComparisonAvailability" + str(slot)
			body.add_child(squad_status)
			body.add_child(C.wrap(str(player.get("contractLabel", "")), 18, C.GOLD))
			continue
		var available := bool(player.get("available", false))
		var status := C.wrap("Offre possible" if available else "Offre indisponible · " + str(player.get("reason", "Motif non communiqué")), 18, C.MINT if available else C.ALERT)
		status.name = "MarketComparisonAvailability" + str(slot)
		body.add_child(status)
		var observer := C.button("",func(): pass)
		body.add_child(observer)
		preload("res://ui/player_observation.gd").configure(observer,app,player)
		var report: Dictionary = reports.get(str(player.get("id", "")), {})
		body.add_child(C.wrap(str(report.get("assessment", {}).get("source", "Aucun rapport daté")), 18, C.GOLD))

static func _header(parent: Node) -> void:
	var row := C.h(24)
	parent.add_child(row)
	for title in ["REPÈRE", "A", "B", "ÉCART B − A"]:
		var label := C.label(title, 18, C.GOLD)
		C.fill(label, false, 1.5 if title == "REPÈRE" else 1.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if title == "REPÈRE" else HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)

static func _row(parent: Node, title: String, key: String, pair: Array[Dictionary], reports: Dictionary, unit: String = "") -> void:
	var row := C.h(24)
	row.name = "MarketComparisonRow_" + key.replace(":", "_")
	row.custom_minimum_size.y = C.px(34)
	parent.add_child(row)
	var label := C.wrap(title, 18)
	C.fill(label, false, 1.5)
	row.add_child(label)
	var values: Array = []
	var best := leader(key, pair)
	for slot in 2:
		var player: Dictionary = pair[slot]
		var datum: Variant = value(player, key, reports)
		values.append(datum)
		var caption := "Non communiqué" if datum == null else G.salary_amount(datum) if key == "salary" and numeric(datum) else G.euros(datum) if key == "fee" and numeric(datum) else G.contract_year(datum) if key == "contractEnd" else NotesMatch.texte_note(datum) if key == "seasonNote" else A.caption(datum) + unit if numeric(datum) else str(datum)
		if key == "fee" and datum == null and own(player): caption = "Sous contrat"
		elif key == "rating": caption = G.rating_text(player, own(player))
		elif key == "potential": caption = G.potential_text(player)
		var text := C.wrap(caption, 20, G.POTENTIAL_COLOR if key == "potential" else C.IVORY, true)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		C.fill(text)
		row.add_child(text)
		if best == slot:
			text.add_theme_color_override("font_color", C.MINT)
			text.tooltip_text = "Le meilleur des deux sur ce repère"
			text.mouse_filter = Control.MOUSE_FILTER_PASS
	var difference_text := delta(values[0],values[1],unit) if key != "pos" else "Même poste" if values[0] == values[1] else "Postes différents"
	if key in ["rating","potential"]: difference_text = K.range_delta(pair[0],pair[1],key,own(pair[0]),own(pair[1]))
	elif key == "contractEnd" and numeric(values[0]) and numeric(values[1]):
		var years := int(values[1]) - int(values[0])
		difference_text = "Même échéance" if years == 0 else ("+" if years > 0 else "") + str(years) + (" an" if absi(years) == 1 else " ans")
	elif key == "seasonNote" and numeric(values[0]) and numeric(values[1]):
		difference_text = ("+" if float(values[1]) > float(values[0]) else "") + NotesMatch.texte_note(float(values[1]) - float(values[0]))
	if key == "salary" and numeric(values[0]) and numeric(values[1]):
		var wage_difference := float(values[1])-float(values[0])
		difference_text = ("+" if wage_difference > 0 else "") + G.salary_amount(wage_difference)
	var difference := C.wrap(difference_text,20,C.GOLD,true)
	difference.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difference.name = "MarketComparisonDelta_" + key.replace(":", "_")
	C.fill(difference)
	row.add_child(difference)
	parent.add_child(HSeparator.new())

static func _clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()
