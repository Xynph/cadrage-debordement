extends RefCounted
## Lecture seule de l’effectif : aucune règle médicale ni mutation de carrière.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Link = preload("res://ui/entity_link.gd")
const FILTERS := ["À ménager", "Blessés", "Suspendus", "En sélection", "Tout l’effectif"]
const PLANS := {"collective":"Suivre le collectif", "repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}
const SORT_KEYS := ["name", "pos", "condition", "physicalLoad", "minutes", "injury", "selection", "suspension", "loadPlan"]
const LOAD_LABELS := ["0–19", "20–39", "40–59", "60–79", "80–100"]

static func load_bucket(player: Dictionary) -> int:
	var value: Variant = numeric(player, "physicalLoad")
	return -1 if value == null else clampi(int(floorf(float(value) / 20.0)), 0, 4)

static func identifier(id: String) -> String:
	return id.replace(":", "_")

static func date_label(value: String) -> String:
	return value.substr(8, 2) + "/" + value.substr(5, 2) + "/" + value.substr(0, 4) if value.length() == 10 else "non renseigné"

static func overview(model: Dictionary, filter: String = "Tout l’effectif", sort_key: String = "priority", descending: bool = false) -> Dictionary:
	var called := {}
	for release: Dictionary in model.get("international", {}).get("availability", {}).get("players", []):
		called[str(release.id)] = release
	var rows: Array[Dictionary] = []
	var counts := {"watched":0, "injured":0, "suspended":0, "called":0, "suspension_unknown":0}
	for player: Dictionary in model.get("squad", []):
		var reason := U.watch_reason(player)
		var injury := float(player.get("injury", 0)) > 0
		var suspension_known: bool = numeric(player, "suspension") != null
		var suspension := suspension_known and float(player.suspension) > 0
		var international := called.has(str(player.id))
		var reasons := PackedStringArray()
		if injury: reasons.append("Blessure · %s sem." % G.n(player.injury))
		if suspension: reasons.append("Suspension · %s" % G.n(player.suspension))
		if international: reasons.append("En sélection · retour " + date_label(str(called[str(player.id)].get("returnDate", ""))))
		if not reason.is_empty(): reasons.append(reason)
		if reasons.is_empty(): reasons.append("Aucune alerte physique projetée")
		if not suspension_known: reasons.append("Suspension non renseignée")
		if not reason.is_empty(): counts.watched += 1
		if injury: counts.injured += 1
		if suspension: counts.suspended += 1
		if international: counts.called += 1
		if not suspension_known: counts.suspension_unknown += 1
		var row := {"player":player, "watch_reason":reason, "injured":injury, "suspended":suspension,
			"injury_known":numeric(player, "injury") != null,
			"suspension_known":suspension_known, "called":international, "reasons":reasons,
			"selection_known":model.get("international", {}).get("availability", {}).get("players") is Array,
			"rank":0 if injury else 1 if suspension else 2 if international else 3 if not reason.is_empty() else 4}
		if filter == "À ménager" and reason.is_empty(): continue
		if filter == "Blessés" and not injury: continue
		if filter == "Suspendus" and not suspension: continue
		if filter == "En sélection" and not international: continue
		rows.append(row)
	if sort_key in SORT_KEYS:
		rows.sort_custom(func(a: Dictionary, b: Dictionary): return less(a, b, sort_key, descending))
	else: rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.rank != b.rank: return a.rank < b.rank
		var left := float(a.player.get("physicalLoad", 0))
		var right := float(b.player.get("physicalLoad", 0))
		if left != right: return left > right
		return str(a.player.id) < str(b.player.id))
	return {"rows":rows, "counts":counts, "total":model.get("squad", []).size()}

static func numeric(player: Dictionary, key: String) -> Variant:
	var value: Variant = player.get(key)
	return value if (value is int or value is float) and is_finite(float(value)) else null

static func sort_value(row: Dictionary, key: String) -> Variant:
	var player: Dictionary = row.player
	if key in ["condition", "physicalLoad", "minutes"]: return numeric(player, key)
	if key == "injury":
		var value: Variant = numeric(player, key)
		return null if value == null else U.fold("%s sem." % G.n(value) if float(value) > 0 else "Aucune projetée")
	if key == "selection":
		return U.fold("En sélection" if row.called else "Au club") if row.get("selection_known", false) else null
	if key == "suspension":
		return U.fold(G.n(player.suspension) if row.suspended else "Aucune projetée") if row.suspension_known else null
	if key == "loadPlan": return U.fold(PLANS[player.loadPlan]) if PLANS.has(player.get("loadPlan")) else null
	var value: Variant = player.get(key)
	return U.fold(value) if value is String and not value.strip_edges().is_empty() else null

static func less(a: Dictionary, b: Dictionary, key: String, descending: bool) -> bool:
	var left: Variant = sort_value(a, key)
	var right: Variant = sort_value(b, key)
	if left == null and right != null: return false
	if right == null and left != null: return true
	if left == right: return str(a.player.id) < str(b.player.id)
	return left > right if descending else left < right

static func sorted_players(source: Array, key: String, descending: bool) -> Array:
	if key not in SORT_KEYS: return source.duplicate()
	return overview({"squad":source}, FILTERS[4], key, descending).rows.map(func(row: Dictionary): return row.player)

static func compact_button(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", C.px(font_size))
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var compact_style := button.get_theme_stylebox(style_name).duplicate() as StyleBox
		compact_style.content_margin_top = 0
		compact_style.content_margin_bottom = 0
		button.add_theme_stylebox_override(style_name, compact_style)

static func entity_profile_link(app: Control, parent: Control, rectangle: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	var link := D.button(parent, rectangle, "", func(): pass, false, "", false, app.accent, id)
	compact_button(link, 18)
	link.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 2, 0))
	link.add_theme_stylebox_override("hover", C.box(Color(1, 1, 1, .04), C.GOLD, 2, 0))
	link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 2, 0))
	Link.bind(link, app, target, caption)
	return link

static func profile_link(app: Control, parent: Control, rectangle: Rect2, player: Dictionary, id: String) -> Button:
	return entity_profile_link(app,parent,rectangle,{"kind":"player", "id":str(player.id)},id,str(player.get("name", "Joueur")))

static func sort_header(app: Control, parent: Control, rectangle: Rect2, caption: String, key: String, state: Dictionary, prefix: String, id: String) -> Button:
	var active: bool = state.get(prefix + "_sort", "") == key
	var descending: bool = state.get(prefix + "_descending", false)
	var arrow := " ↓" if active and descending else " ↑" if active else " ↕"
	var button := D.button(parent, rectangle, caption + arrow, func():
		state[prefix + "_descending"] = not descending if active else false
		state[prefix + "_sort"] = key
		app._render()
		ClubUI.focus(app, id), false, "", false, app.accent, id)
	compact_button(button, 16)
	button.add_theme_color_override("font_color", C.GOLD if active else C.MUTED)
	button.set_meta("sort_key", key)
	button.set_meta("descending", active and descending)
	button.accessibility_name = "Trier par " + caption.to_lower() + " · prochain tri " + ("décroissant" if active and not descending else "croissant")
	button.tooltip_text = button.accessibility_name + " · valeurs non renseignées toujours en fin de liste"
	return button

static func load_blocker(app: Control) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	if not app._live().is_empty(): return "Charge indisponible avant la fin et la validation du match."
	if meta.get("phase") == "ended": return "Saison clôturée : les charges restent consultables."
	if meta.get("trained", false): return "Séance déjà effectuée : ajustez à la prochaine séance."
	return ""

static func build(app: Control, parent: Control, state: Dictionary) -> void:
	var selected := str(state.get("fatigue_filter", FILTERS[4]))
	if selected not in FILTERS: selected = FILTERS[4]
	var key := str(state.get("fatigue_sort", "priority"))
	var descending: bool = state.get("fatigue_descending", false)
	var data := overview(app.model, selected, key, descending)
	var selected_bin := int(state.get("fatigue_load_bin", -1))
	if selected_bin >= 0 and selected_bin < LOAD_LABELS.size():
		data.rows = data.rows.filter(func(row: Dictionary): return load_bucket(row.player) == selected_bin)
	var stats: Dictionary = data.counts
	var captions := ["À ménager", "Blessés", "Suspendus connus", "En sélection"]
	var values := [stats.watched, stats.injured, stats.suspended, stats.called]
	var filters := [FILTERS[0], FILTERS[1], FILTERS[2], FILTERS[3]]
	var summary := D.panel(parent, Rect2(4, 252, 1010, 68), "", "", "", "FatigueSummary")
	for i in 4:
		var hit := D.button(summary, Rect2(7 + i * 250, 5, 245, 57), "", func(): _filter(app, state, filters[i]), false, "", false, app.accent, "FatigueSummaryOpen" + str(i))
		hit.accessibility_name = captions[i] + " · " + G.n(values[i])
		hit.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		hit.add_theme_stylebox_override("hover", C.box(Color(1, 1, 1, .04), C.GOLD, 5, 0))
		D.text(hit, 9, 22, captions[i], 17, C.MUTED, 600, 210)
		D.text(hit, 9, 49, G.n(values[i]), 26, C.GOLD if values[i] > 0 else C.MINT, 700, 80)
		if i == 2: D.text(hit, 59, 47, "%d non renseignés" % stats.suspension_unknown, 16, C.MUTED, 500, 175)
	_distribution(app, parent, state)
	for i in FILTERS.size():
		var button := ClubUI.tab(parent, Rect2(4 + i * 307, 334, 294, 42), FILTERS[i], selected == FILTERS[i], func(): _filter(app, state, FILTERS[i]), "FatigueFilter" + str(i))
		button.add_theme_font_size_override("font_size", C.px(20))
	D.button(parent, Rect2(1575, 334, 669, 42), "Ouvrir la composition →", func(): app._navigate("Composition"), true, "people", false, app.accent, "FatigueOpenLineup").add_theme_font_size_override("font_size", C.px(20))
	var panel := D.panel(parent, Rect2(4, 391, 2240, 814), "Rotation et charge individuelle", "heart", "", "FatigueTable")
	var display_rows: Array = data.rows
	var note := "Blessure, suspension et sélection restent distinctes. Repères de simulation, pas un diagnostic médical."
	if selected_bin >= 0 and selected_bin < LOAD_LABELS.size():
		note = "Charge %s / 100 · %d joueur%s · Tout l’effectif pour retirer ce filtre." % [LOAD_LABELS[selected_bin], display_rows.size(), "s" if display_rows.size() > 1 else ""]
	elif display_rows.is_empty():
		display_rows = overview(app.model, FILTERS[4], key, descending).rows
		note = "Aucun profil « %s » : effectif complet ci-dessous pour comparer les plans et préparer la rotation." % selected
	D.text(panel, 18, 87, note, 17, C.MUTED, 500, 2180).name = "FatigueEmpty" if data.rows.is_empty() else "FatigueReadingGuide"
	for column in [["JOUEUR", 32, 325, "name"], ["POSTE", 365, 210, "pos"], ["CONDITION", 587, 150, "condition"], ["CHARGE", 748, 155, "physicalLoad"], ["MIN.", 910, 105, "minutes"], ["BLESSURE", 1028, 175, "injury"], ["SÉLECTION", 1208, 210, "selection"], ["SUSPENSION", 1428, 175, "suspension"], ["PLAN", 1613, 275, "loadPlan"]]:
		sort_header(app, panel, Rect2(column[1], 95, column[2], 30), column[0], column[3], state, "fatigue", "FatigueSort_" + str(column[3]))
	var scroll := ScrollContainer.new()
	scroll.name = "FatigueScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	D.place(scroll, Rect2(15, 132, 2210, 636))
	var list := C.v(1)
	C.fill(list)
	scroll.add_child(list)
	for row: Dictionary in display_rows: _row(app, list, row)
	if display_rows.is_empty(): list.add_child(C.wrap("Aucun joueur dans cette tranche de charge." if selected_bin >= 0 else "Aucun joueur projeté dans cette carrière.", 18, C.MUTED))
	var blocker := load_blocker(app)
	var footer := blocker if not blocker.is_empty() else "Régler prépare le plan ; seule la séance applique ses effets. Chaque modification est confirmée."
	D.text(panel, 18, 796, footer, 17, C.GOLD if not blocker.is_empty() else C.MUTED, 500, 2178).name = "FatigueLoadPolicy"

static func _distribution(app: Control, parent: Control, state: Dictionary) -> void:
	var chart := D.panel(parent, Rect2(1027, 252, 670, 68), "", "", "", "FatigueDistribution")
	D.text(chart, 12, 22, "CHARGE ACTUELLE / 100", 16, C.MUTED, 600, 230)
	var bins := [0, 0, 0, 0, 0]
	var families := [0, 0, 0]
	for player: Dictionary in app.model.get("squad", []):
		var index := load_bucket(player)
		if index >= 0: bins[index] += 1
		if not player.has("fam"): families[2] += 1
		elif float(player.fam) <= 3: families[0] += 1
		else: families[1] += 1
	var maximum := maxi(1, bins.max())
	for i in 5:
		var x := 240 + i * 83
		var hit := D.button(chart, Rect2(x - 3, 2, 82, 63), "", func():
			state.fatigue_filter = FILTERS[4]
			state.fatigue_load_bin = i
			app._render()
			ClubUI.focus(app, "FatigueLoadBucket" + str(i)), false, "", false, app.accent, "FatigueLoadBucket" + str(i))
		hit.accessibility_name = "Voir les joueurs : charge " + LOAD_LABELS[i] + " sur 100 · " + G.n(bins[i])
		hit.tooltip_text = hit.accessibility_name
		hit.set_meta("load_bucket", i)
		hit.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, C.GOLD if int(state.get("fatigue_load_bin", -1)) == i else Color.TRANSPARENT, 3, 0))
		hit.add_theme_stylebox_override("hover", C.box(Color(1, 1, 1, .04), C.GOLD, 3, 0))
		D.rect(hit, Rect2(3, 31 - 25.0 * bins[i] / maximum, 34, 25.0 * bins[i] / maximum), C.GOLD if i >= 3 else C.MINT, 2)
		D.text(hit, 43, 25, G.n(bins[i]), 17, C.IVORY, 600, 36)
		D.text(hit, 3, 55, LOAD_LABELS[i], 16, C.MUTED, 500, 78)
	var positions := D.panel(parent, Rect2(1710, 252, 534, 68), "", "", "", "FatiguePositionDistribution")
	D.text(positions, 12, 23, "EFFECTIF PAR LIGNE", 16, C.MUTED, 600, 440)
	D.text(positions, 12, 52, "%d avants   /   %d arrières   /   %d non renseignés" % families, 19, C.IVORY, 600, 510)

static func _row(app: Control, list: VBoxContainer, row: Dictionary) -> void:
	var player: Dictionary = row.player
	var item := Control.new()
	item.name = "FatigueRow_" + identifier(str(player.id))
	item.set_meta("player_id", player.id)
	item.custom_minimum_size.y = C.px(29)
	item.tooltip_text = str(player.get("name", "")) + " · " + " · ".join(row.reasons)
	list.add_child(item)
	D.rect(item, Rect2(0, 0, 2190, 28), C.RAISED if int(row.rank) < 4 else C.PANEL, 2)
	var link := profile_link(app, item, Rect2(0, 0, 357, 28), player, "FatigueOpenPlayer_" + identifier(str(player.id)))
	var portrait := G.portrait(int(player.get("portraitIndex", 0)), 0, player)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(portrait)
	D.place(portrait, Rect2(1, 1, 25, 26))
	D.text(link, 32, 22, player.get("name", "—"), 20, C.IVORY, 600, 325)
	D.text(item, 365, 22, player.get("pos", "—"), 18, C.MUTED, 500, 205)
	D.text(item, 587, 22, _number(player, "condition", "%"), 19, C.MINT, 600, 68)
	if player.has("condition"): D.bar(item, Rect2(655, 12, 76, 5), float(player.condition), C.MINT)
	D.text(item, 748, 22, _number(player, "physicalLoad", ""), 19, C.GOLD if not str(row.watch_reason).is_empty() else C.IVORY, 600, 65)
	if player.has("physicalLoad"): D.bar(item, Rect2(816, 12, 76, 5), float(player.physicalLoad), C.GOLD)
	D.text(item, 910, 22, _number(player, "minutes", ""), 18, C.IVORY, 500, 100)
	if row.injured: _status_icon(item, "heart", 1028, C.ALERT)
	D.text(item, 1050, 22, "%s sem." % G.n(player.get("injury", 0)) if row.injured else "Aucune projetée" if row.injury_known else "Non renseignée", 18, C.ALERT if row.injured else C.MUTED, 500, 148)
	var release: String = "En sélection" if row.called else "Non renseigné" if not row.selection_known else "Au club"
	if row.called: _status_icon(item, "flag", 1208, C.BLUE)
	D.text(item, 1230, 22, release, 18, C.BLUE if row.called else C.MUTED, 500, 178)
	if row.suspended: _status_icon(item, "warning", 1428, C.ALERT)
	D.text(item, 1450, 22, G.n(player.suspension) if row.suspended else "Aucune projetée" if row.suspension_known else "Non renseignée", 18, C.ALERT if row.suspended else C.MUTED, 500, 148)
	D.text(item, 1613, 22, PLANS.get(player.get("loadPlan", ""), "Non renseigné"), 18, C.IVORY, 500, 265)
	var button := D.button(item, Rect2(1910, 0, 260, 28), "Régler", func(): open_adjustment(app, player), false, "", false, app.accent, "FatigueAdjust_" + identifier(str(player.id)))
	button.set_meta("player_id", player.id)
	button.accessibility_name = "Ajuster la charge de " + str(player.name)
	compact_button(button, 18)
	button.tooltip_text = load_blocker(app) if not load_blocker(app).is_empty() else item.tooltip_text + " · Choisir puis confirmer le plan"

static func _status_icon(parent: Control, kind: String, left: float, tone: Color) -> void:
	var icon := C.icon(kind, 16, tone)
	parent.add_child(icon)
	D.place(icon, Rect2(left, 7, 16, 16))

static func _number(player: Dictionary, key: String, suffix: String) -> String:
	return G.n(player[key]) + suffix if player.has(key) and (player[key] is float or player[key] is int) else "—"

static func _filter(app: Control, state: Dictionary, value: String) -> void:
	state.fatigue_filter = value
	state.erase("fatigue_load_bin")
	app._render()
	ClubUI.focus(app, "FatigueFilter" + str(FILTERS.find(value)))

static func open_adjustment(app: Control, player: Dictionary) -> void:
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "FatigueAdjustmentDialog"
	dialog.title = "Charge individuelle · " + str(player.name)
	app._prepare_dialog(dialog, C.px(850))
	dialog.get_ok_button().text = "Fermer"
	var body := C.v(12)
	dialog.add_child(body)
	body.add_child(C.wrap(str(player.name) + " · " + str(player.pos), 24, C.IVORY))
	body.add_child(C.wrap("Ce choix prépare la séance suivante. Il ne lance aucun entraînement et ne modifie pas les convocations.", 18, C.MUTED))
	if float(player.get("injury", 0)) > 0:
		body.add_child(C.wrap("Blessure : le moteur applique la récupération pendant la séance, quel que soit le plan choisi.", 18, C.GOLD))
	var blocker := load_blocker(app)
	if not blocker.is_empty(): body.add_child(C.wrap(blocker, 18, C.GOLD))
	for mode: String in PLANS:
		var button := C.button(str(PLANS[mode]) + (" · plan actuel" if player.get("loadPlan") == mode else ""), func():
			app.confirm("Confirmer la charge individuelle", str(player.name) + " · " + str(player.pos) + "\nPlan proposé : " + str(PLANS[mode]) + "\nLa séance n’est pas lancée par cette action.", func():
				app._command("set_player_load", {"playerId":player.id, "mode":mode}), true))
		button.name = "FatiguePlan_" + mode
		button.set_meta("player_id", player.id)
		button.disabled = not blocker.is_empty()
		button.add_theme_font_size_override("font_size", C.px(20))
		body.add_child(button)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	Dialogs.show_centered(dialog, Vector2i(C.px(800), C.px(460)))
