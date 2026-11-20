extends SceneTree
## Zones de classement de la carrière Monde dans le vrai écran Compétitions (competition_canvas.gd).
## Les zones viennent de la donnée du moteur (native/engine/world-standings-zones.json), projetées comme
## world-model.cjs (zone de chaque ligne d'après son rang). Chaque ligne en zone porte liseré, symbole dessiné
## et libellé dans son nom accessible ; la légende, la note du règlement et la ligne « Champion » tiennent sous
## le tableau sans se chevaucher, à 1280 × 720 et 1920 × 1080. Même langage sur le classement court du Bureau
## (office_canvas.gd large, office.gd compact) : liseré, symbole, mot lu, légende des seules zones de l'extrait.
## Classements synthétiques : aucun résultat sportif.
const C = preload("res://ui/immersive08/components.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const OfficeCanvas = preload("res://ui/immersive08/office_canvas.gd")
const OfficeCompact = preload("res://ui/immersive08/office.gd")
const P = preload("res://ui/immersive08/projection.gd")
class ReadingApp extends Control:
	var model: Dictionary = {}
	var accent := Color("cc4d57")
	var management_ui: Dictionary = {}
	var table_division := "elite"
	var catalogue: Array = []
	var route := "Classements"
	var commands := 0
	func _navigate(destination: String, _remember: bool = true) -> void: route = destination
	func _render(_keep: bool = true) -> void: pass
	func _command(_id: String, _payload: Dictionary = {}) -> void: commands += 1
var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		if failures.size() <= 20: printerr("FAIL: ", description)

func _initialize() -> void: call_deferred("run")

## Classement synthétique de `size` clubs avec la zone de chaque rang (même règle que world-model.cjs).
func league_fixture(data: Dictionary, id: String, size: int, first_id: int, ended: bool) -> Dictionary:
	var table: Dictionary = data.competitions[id]
	var zones: Array = table.zones.map(func(z: Dictionary): return {"from": int(z.from), "to": int(z.to), "kind": z.kind, "label": z.label, "symbol": data.symbols[z.kind]})
	var rows: Array = []
	for i in size:
		var rank := i + 1
		var zone: Variant = null
		for z: Dictionary in zones:
			if rank >= z.from and rank <= z.to: zone = {"kind": z.kind, "label": z.label, "symbol": z.symbol}
		rows.append({"id": first_id + i, "name": "Club des Plaines " + str(rank), "rank": rank, "standingsOpen": true, "played": 26, "won": 20 - i,
			"drawn": 0, "lost": 6 + i, "pf": 600 - i * 10, "pa": 400 + i * 10, "bonus": 4, "points": 90 - i * 4, "form": ["V", "D", "V"], "zone": zone})
	var league := {"id": id, "name": id, "phase": "ended" if ended else "league", "rows": rows, "zones": zones, "zoneNote": table.get("note"), "zoneShortNote": table.get("shortNote"), "zoneScope": table.scope}
	if ended: league.merge({"champion": rows[1].duplicate(), "finalist": rows[2].duplicate()})
	return league

func run() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../engine/world-standings-zones.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data is Dictionary and data.get("competitions") is Dictionary, "Donnée des zones du moteur lisible : " + path)
	if not data is Dictionary:
		finish()
		return
	# Top 14 et URC terminés (Champion + Finaliste), Japon D1 en cours (pas de note ni de champion), Pro D2 en cours.
	var leagues: Array = [league_fixture(data, "elite", 14, 300, true), league_fixture(data, "urc", 16, 320, true),
		league_fixture(data, "jlo-d1", 12, 340, false), league_fixture(data, "accession", 16, 360, false)]
	for height in [720.0, 1080.0]:
		C.configure(height, height * 16.0 / 9.0)
		for league: Dictionary in leagues: await screen(league, leagues, int(height))
		# Bureau : classement court (club ± voisins) en haut et en bas de tableau, gabarit large (1920) et compact (1280).
		for league: Dictionary in leagues:
			for own_index in [1, league.rows.size() - 1]:
				for w in [540, 684, 1100]: await office_canvas(league, leagues, own_index, w, int(height))
				await office_compact(league, leagues, own_index, int(height))
	C.configure(1440, 2560)
	finish()

func screen(league: Dictionary, leagues: Array, height: int) -> void:
	var app := ReadingApp.new()
	app.model = {"club": league.rows[3].duplicate(), "meta": {"mode": "world", "leagueId": league.id, "season": 1}, "league": league.rows, "leagues": leagues}
	app.table_division = league.id
	var before := JSON.stringify(app.model)
	root.add_child(app)
	var canvas := Control.new()
	app.add_child(canvas)
	Competition.build(app, canvas)
	await process_frame
	var where := " (%s, %d p)" % [league.id, height]
	var rows := canvas.find_children("StandingsRow_*", "Button", true, false)
	check(rows.size() == league.rows.size() and canvas.find_child("StandingsPagination", true, false) == null, "Tout le classement sur une page" + where)
	var frame: Control = canvas.find_child("StandingsTableFrame", true, false)
	for i in mini(rows.size(), league.rows.size()):
		var row: Button = rows[i]
		var zone: Variant = league.rows[i].zone
		var edge: Control = row.find_child("StandingsZoneEdge", true, false)
		var mark: Control = row.find_child("StandingsZoneMark", true, false)
		if zone is Dictionary:
			check(edge != null and mark != null and str(mark.get_meta("zone_kind", "")) == zone.kind and str(row.get_meta("zone_kind", "")) == zone.kind, "Liseré et symbole au rang %d%s" % [i + 1, where])
			check(row.accessibility_name.contains(str(zone.label)), "Libellé « %s » annoncé au rang %d%s" % [zone.label, i + 1, where])
			check(mark != null and mark.get_child_count() == 1 and (mark.get_child(0) is Polygon2D or mark.get_child(0) is Line2D), "Symbole dessiné (aucune fonte du jeu n'a ★●▲◆▼○)" + where)
		else:
			check(edge == null and mark == null and not row.has_meta("zone_kind"), "Aucune zone au rang %d%s" % [i + 1, where])
	var kinds := {}
	for i in mini(rows.size(), league.rows.size()):
		var row: Button = rows[i]
		if row.has_meta("zone_kind"):
			var tint: Color = (row.find_child("StandingsZoneEdge", true, false) as Panel).get_theme_stylebox("panel").bg_color
			kinds[str(row.get_meta("zone_kind"))] = tint
	if kinds.has("relegation") and kinds.has("bye"): check(kinds.relegation != kinds.bye, "Relégation et qualification de teintes distinctes" + where)
	var legend: Control = canvas.find_child("StandingsZoneLegend", true, false)
	check(legend != null, "Légende sous le tableau" + where)
	if legend != null:
		for z: Dictionary in league.zones:
			var span := str(z.from) if z.from == z.to else "%d–%d" % [z.from, z.to]
			check(legend.accessibility_name.contains(str(z.symbol) + " " + span + " " + str(z.label)), "Légende « %s %s %s »%s" % [z.symbol, span, z.label, where])
		check(legend.find_children("StandingsZoneLegendMark_*", "Control", true, false).size() == league.zones.size(), "Un symbole par zone dans la légende" + where)
		var last_row: Control = rows[-1]
		check(last_row.get_global_rect().end.y <= legend.get_global_rect().position.y + 1, "Légende sous la dernière ligne" + where)
		var items := legend.find_children("StandingsZoneLegendItem_*", "Label", true, false)
		var right := 0.0
		for item: Label in items: right = maxf(right, item.get_global_rect().position.x + item.get_theme_font("font").get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.get_theme_font_size("font_size")).x)
		check(items.size() == league.zones.size() and right <= frame.get_global_rect().end.x, "Légende dans le cadre (%d / %d px)%s" % [roundi(right), roundi(frame.get_global_rect().end.x), where])
		check(not items.is_empty() and items.all(func(item: Label): return item.get_theme_font("font").get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.get_theme_font_size("font_size")).x <= item.size.x + 1), "Libellés de légende entiers" + where)
		var note: Label = canvas.find_child("StandingsZoneNote", true, false)
		var champion: Label = canvas.find_child("StandingsChampion", true, false)
		if league.zoneNote is String: check(note != null and note.text == league.zoneNote, "Note du règlement" + where)
		else: check(note == null, "Pas de note sans donnée" + where)
		check((champion != null) == league.has("champion"), "Ligne Champion avec le titre" + where)
		var stack: Array = [items[0]] if not items.is_empty() else []
		if note != null: stack.append(note)
		if champion != null: stack.append(champion)
		for k in range(1, stack.size()):
			# Texte visible : de la hauteur des capitales à la ligne de base + jambage (la boîte du Label déborde l'interligne).
			check(ink(stack[k - 1]).y <= ink(stack[k]).x + 1, "Pied sans chevauchement (%s / %s)%s" % [stack[k - 1].name, stack[k].name, where])
		if not stack.is_empty(): check(ink(stack[-1]).y <= frame.get_global_rect().end.y, "Pied dans le cadre" + where)
	check(app.commands == 0 and JSON.stringify(app.model) == before, "Affichage sans commande ni modification du modèle" + where)
	app.queue_free()
	await process_frame

func office_app(league: Dictionary, leagues: Array, own_index: int) -> ReadingApp:
	var app := ReadingApp.new()
	app.route = "Bureau"
	app.model = {"club": league.rows[own_index].duplicate(), "meta": {"mode": "world", "leagueId": league.id, "season": 1}, "league": league.rows, "leagues": leagues}
	root.add_child(app)
	return app

## Zones attendues dans l'extrait du Bureau : celles des lignes affichées, dans l'ordre, chacune une fois.
func expected_zones(app: ReadingApp) -> Array:
	var seen := {}
	var result: Array = []
	var rows_vues: Array = P.standings(app.model)
	if large_rows: rows_vues = OfficeCanvas.short_rows(rows_vues, app.model.club.id, OfficeCanvas.STANDINGS_ROWS)
	for row: Dictionary in rows_vues:
		if row.zone is Dictionary and not seen.has(row.zone.kind):
			seen[row.zone.kind] = true
			result.append(row.zone)
	return result

## Lignes du classement court : liseré, symbole dessiné et libellé dit sur chaque ligne en zone, rien ailleurs.
## `scope` rend le nœud qui porte liseré et symbole pour un bouton de ligne.
func office_rows(app: ReadingApp, holder: Control, scope: Callable, where: String) -> void:
	var shown := P.standings(app.model)
	check(shown.size() == 6, "Six lignes dans l'extrait" + where)
	# Bureau large (≥ 900 de large) : 4 lignes consécutives qui gardent notre club ; zones et légende suivent ces lignes.
	if large_rows: shown = OfficeCanvas.short_rows(shown, app.model.club.id, OfficeCanvas.STANDINGS_ROWS)
	for club: Dictionary in shown:
		var hit: Button = holder.find_child("OfficeStandingRow_" + str(club.id), true, false)
		check(hit != null, "Ligne du club %s%s" % [club.id, where])
		if hit == null: continue
		var area: Node = scope.call(hit)
		var edge: Control = area.find_child("StandingsZoneEdge", true, false)
		var mark: Control = area.find_child("StandingsZoneMark", true, false)
		if club.zone is Dictionary:
			check(edge != null and edge.visible and mark != null and str(mark.get_meta("zone_kind", "")) == club.zone.kind, "Bureau : liseré et symbole au rang %d%s" % [club.rank, where])
			check(mark != null and mark.get_child_count() == 1 and (mark.get_child(0) is Polygon2D or mark.get_child(0) is Line2D), "Bureau : symbole dessiné au rang %d%s" % [club.rank, where])
			# Symbole du Bureau : environ 11 px réels, sans toucher le rang ni le nom.
			var px := mark.get_global_rect().size.x if mark != null else 0.0
			check(px >= 10.5 and px <= 12.5, "Bureau : symbole d'environ 11 px (%.1f px)%s" % [px, where])
			if mark != null:
				var after := mark.get_global_rect().end.x
				for cell in rank_cells(hit, mark):
					check(after <= cell.get_global_rect().position.x + 0.5, "Bureau : symbole sans toucher le rang au rang %d (%.1f / %.1f)%s" % [club.rank, after, cell.get_global_rect().position.x, where])
			check(hit.accessibility_name.contains(str(club.zone.label)) and str(hit.get_meta("zone_kind", "")) == club.zone.kind, "Bureau : « %s » annoncé au rang %d%s" % [club.zone.label, club.rank, where])
		else:
			check(edge == null and mark == null and not hit.has_meta("zone_kind"), "Bureau : aucune zone au rang %d%s" % [club.rank, where])

## Cases de texte à droite du symbole : le rang et le nom (Bureau large : textes posés sur le bloc ; compact : frères de la tête de ligne).
func rank_cells(hit: Button, mark: Control) -> Array:
	var result: Array = []
	var lead := mark.get_parent().get_parent()
	if lead is HBoxContainer and lead.name == "StandingsZoneLead":
		for sibling in lead.get_parent().get_children():
			if sibling is Label and sibling.text != "" and sibling.get_global_rect().position.x > lead.get_global_rect().position.x: result.append(sibling)
		return result.slice(0, 2)
	var card := hit.get_parent()
	for sibling in card.get_children():
		if sibling is Label and sibling.get_global_rect().position.y < hit.get_global_rect().end.y and sibling.get_global_rect().end.y > hit.get_global_rect().position.y and sibling.get_global_rect().position.x > hit.get_global_rect().position.x and sibling.get_global_rect().position.x < hit.get_global_rect().position.x + C.px(120):
			result.append(sibling)
	return result

## Légende : une forme et un mot par zone visible dans l'extrait (« ★ Demi-finale directe · ▼ Relégation »).
func office_legend(app: ReadingApp, holder: Control, where: String) -> Control:
	var zones := expected_zones(app)
	var legend: Control = holder.find_child("StandingsZoneLegend", true, false)
	if zones.is_empty():
		check(legend == null, "Bureau : pas de légende sans zone dans l'extrait" + where)
		return null
	check(legend != null, "Bureau : légende sous le classement court" + where)
	if legend == null: return null
	var spoken: Array[String] = []
	for zone: Dictionary in zones: spoken.append(str(zone.symbol) + " " + str(zone.label))
	check(str(legend.get_meta("legend_text", "")).begins_with(" · ".join(spoken)) and legend.accessibility_name.contains(" · ".join(spoken)), "Bureau : légende « %s »%s" % [" · ".join(spoken), where])
	var marks := legend.find_children("StandingsZoneLegendMark_*", "Control", true, false)
	check(marks.size() == zones.size() and marks.all(func(m: Control): return m.get_child_count() == 1), "Bureau : un symbole dessiné par zone de la légende" + where)
	var items := legend.find_children("StandingsZoneLegendItem_*", "Label", true, false)
	check(items.size() == zones.size() and items.all(func(item: Label): return item.get_theme_font("font").get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.get_theme_font_size("font_size")).x <= item.size.x + 1), "Bureau : libellés de légende entiers" + where)
	check(items.all(func(item: Label): return item.get_theme_font_size("font_size") >= C.px(18)), "Bureau : légende à 18 au moins" + where)
	return legend

## Vrai quand le Bureau large est examiné (4 lignes au lieu de 6).
var large_rows := false

func office_canvas(league: Dictionary, leagues: Array, own_index: int, w: int, height: int) -> void:
	var app := office_app(league, leagues, own_index)
	var before := JSON.stringify(app.model)
	var card := Panel.new()
	app.add_child(card)
	card.size = Vector2(w, 448) * C.density
	large_rows = w >= 900
	OfficeCanvas._standings(card, app, w)
	await process_frame
	var where := " (Bureau large %d, %s, club %d, %d p)" % [w, league.id, own_index + 1, height]
	office_rows(app, card, func(hit: Button): return hit, where)
	var legend := office_legend(app, card, where)
	if legend != null:
		var bottom := 0.0
		for row: Control in card.find_children("OfficeStandingRow_*", "Button", true, false): bottom = maxf(bottom, row.get_global_rect().end.y)
		var labels: Array = legend.find_children("Standings*", "Label", true, false)
		var right := 0.0
		for label: Label in labels: right = maxf(right, label.get_global_rect().position.x + label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)
		check(right <= card.get_global_rect().end.x - C.px(20), "Bureau : légende dans le bloc (%d / %d px)%s" % [roundi(right), roundi(card.get_global_rect().end.x - C.px(20)), where])
		var first: Label = legend.find_child("StandingsZoneLegendItem_0", true, false)
		check(first != null and ink(first).x >= bottom, "Bureau : légende sous la dernière ligne" + where)
		var form_top := 370.0 * C.density + card.get_global_rect().position.y
		check(first != null and ink(first).y <= form_top, "Bureau : légende au-dessus de la forme" + where)
		var note: Label = legend.find_child("StandingsZoneNote", true, false)
		var expected_note: Variant = league.zoneShortNote if league.zoneShortNote is String else league.zoneNote
		if league.zoneShortNote is String:
			# La note courte tient sur la ligne de la légende quand il reste la place ; sinon rien (jamais tronquée).
			var tail: Label = legend.find_child("StandingsZoneLegendItem_%d" % (expected_zones(app).size() - 1), true, false)
			var font := C.font(500)
			var room := (legend.size.x - (tail.get_global_rect().position.x - legend.get_global_rect().position.x) - tail.get_theme_font("font").get_string_size(tail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tail.get_theme_font_size("font_size")).x) / C.density - 20.0
			var fits: bool = font.get_string_size(league.zoneShortNote, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density <= room
			check((note != null) == fits and (note == null or note.text == league.zoneShortNote and note.text.length() <= 30), "Bureau : note courte « %s » %s%s" % [league.zoneShortNote, "présente" if fits else "absente faute de place", where])
			if note != null: print("NOTE_VISIBLE ", where)
		if note != null:
			check(expected_note is String and note.text == expected_note, "Bureau : note exacte" + where)
			var last: Label = legend.find_child("StandingsZoneLegendItem_%d" % (expected_zones(app).size() - 1), true, false)
			check(last != null and note.get_global_rect().position.x >= last.get_global_rect().position.x + last.size.x, "Bureau : note sans chevaucher la légende" + where)
	check(app.commands == 0 and JSON.stringify(app.model) == before, "Bureau : affichage sans commande ni modification" + where)
	app.queue_free()
	await process_frame
	large_rows = false

func office_compact(league: Dictionary, leagues: Array, own_index: int, height: int) -> void:
	var app := office_app(league, leagues, own_index)
	var before := JSON.stringify(app.model)
	var box := VBoxContainer.new()
	app.add_child(box)
	box.size = Vector2(C.px(560), 0)
	OfficeCompact._standings(box, app)
	await process_frame
	await process_frame
	var where := " (Bureau compact, %s, club %d, %d p)" % [league.id, own_index + 1, height]
	office_rows(app, box, func(hit: Button): return hit.get_parent(), where)
	var legend := office_legend(app, box, where)
	var action: Control = box.find_child("OfficeStandingsAction", true, false)
	if legend != null: check(action != null and legend.get_global_rect().end.y <= action.get_global_rect().position.y + 1, "Bureau : légende avant le lien du classement complet" + where)
	var note: Label = box.find_child("StandingsZoneNote", true, false)
	if league.zoneShortNote is String and legend != null:
		check(note != null and note.text == league.zoneShortNote, "Bureau compact : note courte présente" + where)
		if note != null:
			check(note.get_global_rect().position.y >= legend.get_global_rect().end.y - 1 and note.get_global_rect().end.y <= action.get_global_rect().position.y + 1, "Bureau compact : note sous la légende, avant le lien" + where)
			check(note.get_theme_font("font").get_string_size(note.text, HORIZONTAL_ALIGNMENT_LEFT, -1, note.get_theme_font_size("font_size")).x <= note.size.x + 1, "Bureau compact : note entière" + where)
	elif legend != null: check(note == null, "Bureau compact : pas de note sans note courte" + where)
	check(app.commands == 0 and JSON.stringify(app.model) == before, "Bureau : affichage sans commande ni modification" + where)
	app.queue_free()
	await process_frame

## Encre verticale d'un texte d'une ligne : (haut des capitales, bas des jambages) en pixels globaux.
func ink(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var base := label.get_global_rect().position.y + font.get_ascent(size)
	return Vector2(base - 0.72 * size, base + font.get_descent(size))

func finish() -> void:
	print("ZONES CLASSEMENT : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
