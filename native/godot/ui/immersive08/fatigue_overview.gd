extends RefCounted
## Lecture seule de l’effectif : aucune règle médicale ni mutation de carrière.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const ClubUI = preload("res://ui/immersive08/club_ui.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const FILTERS := ["À ménager", "Blessés", "Suspendus", "En sélection", "Tout l’effectif"]
const PLANS := {"collective":"Suivre le collectif", "repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}

static func identifier(id: String) -> String:
	return id.replace(":", "_")

static func date_label(value: String) -> String:
	return value.substr(8, 2) + "/" + value.substr(5, 2) + "/" + value.substr(0, 4) if value.length() == 10 else "non renseigné"

static func overview(model: Dictionary, filter: String = "Tout l’effectif") -> Dictionary:
	var called := {}
	for release: Dictionary in model.get("international", {}).get("availability", {}).get("players", []):
		called[str(release.id)] = release
	var rows: Array[Dictionary] = []
	var counts := {"watched":0, "injured":0, "suspended":0, "called":0, "suspension_unknown":0}
	for player: Dictionary in model.get("squad", []):
		var reason := U.watch_reason(player)
		var injury := float(player.get("injury", 0)) > 0
		var suspension_known := player.has("suspension") and (player.suspension is float or player.suspension is int)
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
			"suspension_known":suspension_known, "called":international, "reasons":reasons,
			"rank":0 if injury else 1 if suspension else 2 if international else 3 if not reason.is_empty() else 4}
		if filter == "À ménager" and reason.is_empty(): continue
		if filter == "Blessés" and not injury: continue
		if filter == "Suspendus" and not suspension: continue
		if filter == "En sélection" and not international: continue
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.rank != b.rank: return a.rank < b.rank
		var left := float(a.player.get("physicalLoad", 0))
		var right := float(b.player.get("physicalLoad", 0))
		if left != right: return left > right
		return str(a.player.id) < str(b.player.id))
	return {"rows":rows, "counts":counts, "total":model.get("squad", []).size()}

static func load_blocker(app: Control) -> String:
	var meta: Dictionary = app.model.get("meta", {})
	if not app._live().is_empty(): return "Charge indisponible avant la fin et la validation du match."
	if meta.get("phase") == "ended": return "Saison clôturée : les charges restent consultables."
	if meta.get("trained", false): return "Séance déjà effectuée : ajustez à la prochaine séance."
	return ""

static func build(app: Control, parent: Control, state: Dictionary) -> void:
	var selected := str(state.get("fatigue_filter", FILTERS[4]))
	if selected not in FILTERS: selected = FILTERS[4]
	var data := overview(app.model, selected)
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
	_distribution(app.model, parent)
	for i in FILTERS.size():
		var button := ClubUI.tab(parent, Rect2(4 + i * 307, 334, 294, 42), FILTERS[i], selected == FILTERS[i], func(): _filter(app, state, FILTERS[i]), "FatigueFilter" + str(i))
		button.add_theme_font_size_override("font_size", C.px(20))
	D.button(parent, Rect2(1575, 334, 669, 42), "Ouvrir la composition →", func(): app._navigate("Composition"), true, "people", false, app.accent, "FatigueOpenLineup").add_theme_font_size_override("font_size", C.px(20))
	var panel := D.panel(parent, Rect2(4, 391, 2240, 814), "Rotation et charge individuelle", "heart", "", "FatigueTable")
	var display_rows: Array = data.rows
	var note := "Blessure, suspension et sélection restent distinctes. Repères de simulation, pas un diagnostic médical."
	if display_rows.is_empty():
		display_rows = overview(app.model, FILTERS[4]).rows
		note = "Aucun profil « %s » : effectif complet ci-dessous pour comparer les plans et préparer la rotation." % selected
	D.text(panel, 18, 87, note, 17, C.MUTED, 500, 2180).name = "FatigueEmpty" if data.rows.is_empty() else "FatigueReadingGuide"
	for column in [["JOUEUR", 47, 310], ["POSTE", 380, 205], ["CONDITION", 602, 145], ["CHARGE", 763, 150], ["MIN.", 925, 95], ["BLESSURE", 1043, 170], ["SÉLECTION", 1223, 200], ["SUSPENSION", 1443, 170], ["PLAN", 1628, 265]]:
		D.text(panel, column[1], 120, column[0], 16, C.MUTED, 700, column[2])
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
	if display_rows.is_empty(): list.add_child(C.wrap("Aucun joueur projeté dans cette carrière.", 18, C.MUTED))
	var blocker := load_blocker(app)
	var footer := blocker if not blocker.is_empty() else "Régler prépare le plan ; seule la séance applique ses effets. Chaque modification est confirmée."
	D.text(panel, 18, 796, footer, 17, C.GOLD if not blocker.is_empty() else C.MUTED, 500, 2178).name = "FatigueLoadPolicy"

static func _distribution(model: Dictionary, parent: Control) -> void:
	var chart := D.panel(parent, Rect2(1027, 252, 670, 68), "", "", "", "FatigueDistribution")
	D.text(chart, 12, 22, "CHARGE ACTUELLE / 100", 16, C.MUTED, 600, 230)
	var bins := [0, 0, 0, 0, 0]
	var families := [0, 0, 0]
	for player: Dictionary in model.get("squad", []):
		if player.has("physicalLoad"):
			var index := clampi(int(float(player.physicalLoad) / 20), 0, 4)
			bins[index] += 1
		if not player.has("fam"): families[2] += 1
		elif float(player.fam) <= 3: families[0] += 1
		else: families[1] += 1
	var maximum := maxi(1, bins.max())
	for i in 5:
		var x := 240 + i * 83
		D.rect(chart, Rect2(x, 33 - 25.0 * bins[i] / maximum, 34, 25.0 * bins[i] / maximum), C.GOLD if i >= 3 else C.MINT, 2)
		D.text(chart, x + 40, 27, G.n(bins[i]), 17, C.IVORY, 600, 40)
		D.text(chart, x, 57, ["0–19", "20–39", "40–59", "60–79", "80–100"][i], 16, C.MUTED, 500, 80)
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
	var portrait := G.portrait(int(player.get("portraitIndex", 0)), 0, player)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(portrait)
	D.place(portrait, Rect2(1, 1, 25, 26))
	D.text(item, 32, 22, player.get("name", "—"), 20, C.IVORY, 600, 325)
	D.text(item, 365, 22, player.get("pos", "—"), 18, C.MUTED, 500, 205)
	D.text(item, 587, 22, _number(player, "condition", "%"), 19, C.MINT, 600, 68)
	if player.has("condition"): D.bar(item, Rect2(655, 12, 76, 5), float(player.condition), C.MINT)
	D.text(item, 748, 22, _number(player, "physicalLoad", ""), 19, C.GOLD if not str(row.watch_reason).is_empty() else C.IVORY, 600, 65)
	if player.has("physicalLoad"): D.bar(item, Rect2(816, 12, 76, 5), float(player.physicalLoad), C.GOLD)
	D.text(item, 910, 22, _number(player, "minutes", ""), 18, C.IVORY, 500, 100)
	if row.injured: _status_icon(item, "heart", 1028, C.ALERT)
	D.text(item, 1050, 22, "%s sem." % G.n(player.get("injury", 0)) if row.injured else "Aucune projetée", 18, C.ALERT if row.injured else C.MUTED, 500, 148)
	var release: String = "En sélection" if row.called else "Non renseigné" if not app.model.get("international", {}).has("availability") else "Au club"
	if row.called: _status_icon(item, "flag", 1208, C.BLUE)
	D.text(item, 1230, 22, release, 18, C.BLUE if row.called else C.MUTED, 500, 178)
	if row.suspended: _status_icon(item, "warning", 1428, C.ALERT)
	D.text(item, 1450, 22, G.n(player.suspension) if row.suspended else "Aucune projetée" if row.suspension_known else "Non renseignée", 18, C.ALERT if row.suspended else C.MUTED, 500, 148)
	D.text(item, 1613, 22, PLANS.get(player.get("loadPlan", ""), "Non renseigné"), 18, C.IVORY, 500, 265)
	var button := D.button(item, Rect2(1910, 0, 260, 28), "Régler", func(): open_adjustment(app, player), false, "", false, app.accent, "FatigueAdjust_" + identifier(str(player.id)))
	button.set_meta("player_id", player.id)
	button.accessibility_name = "Ajuster la charge de " + str(player.name)
	button.add_theme_font_size_override("font_size", C.px(18))
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var compact_style := button.get_theme_stylebox(style_name).duplicate() as StyleBox
		compact_style.content_margin_top = 0
		compact_style.content_margin_bottom = 0
		button.add_theme_stylebox_override(style_name, compact_style)
	button.tooltip_text = load_blocker(app) if not load_blocker(app).is_empty() else item.tooltip_text + " · Choisir puis confirmer le plan"

static func _status_icon(parent: Control, kind: String, left: float, tone: Color) -> void:
	var icon := C.icon(kind, 16, tone)
	parent.add_child(icon)
	D.place(icon, Rect2(left, 7, 16, 16))

static func _number(player: Dictionary, key: String, suffix: String) -> String:
	return G.n(player[key]) + suffix if player.has(key) and (player[key] is float or player[key] is int) else "—"

static func _filter(app: Control, state: Dictionary, value: String) -> void:
	state.fatigue_filter = value
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
