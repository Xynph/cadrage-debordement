extends SceneTree
## Zones de classement de la carrière Monde dans le vrai écran Compétitions (competition_canvas.gd).
## Les zones viennent de la donnée du moteur (native/engine/world-standings-zones.json), projetées comme
## world-model.cjs (zone de chaque ligne d'après son rang). Chaque ligne en zone porte liseré, symbole dessiné
## et libellé dans son nom accessible ; la légende, la note du règlement et la ligne « Champion » tiennent sous
## le tableau sans se chevaucher, à 1280 × 720 et 1920 × 1080. Classements synthétiques : aucun résultat sportif.
const C = preload("res://ui/immersive08/components.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
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
	var league := {"id": id, "name": id, "phase": "ended" if ended else "league", "rows": rows, "zones": zones, "zoneNote": table.get("note"), "zoneScope": table.scope}
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

## Encre verticale d'un texte d'une ligne : (haut des capitales, bas des jambages) en pixels globaux.
func ink(label: Label) -> Vector2:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var base := label.get_global_rect().position.y + font.get_ascent(size)
	return Vector2(base - 0.72 * size, base + font.get_descent(size))

func finish() -> void:
	print("ZONES CLASSEMENT : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
