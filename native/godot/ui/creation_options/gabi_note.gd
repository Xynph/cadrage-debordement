extends RefCounted
## Écran « Options de carrière » · « Gabi se présente » : portrait de Gabi (planche 2D du guide, pose
## « territoire ») dans un disque cerclé d'or et une bulle courte (181 caractères au plus) qui résume ce que
## changent les options choisies : championnats suivis et vitesse, départ, variation du niveau.
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const LeagueDetail = preload("res://ui/league_detail_view.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const PORTRAIT = preload("res://guide/coach_portrait.gd")
const LIMIT := 181

## Rend un Callable `refresh(start)` qui réécrit la bulle quand le départ change.
static func build(app: Control, parent: Node, selected: Dictionary, choosable: bool, catalogue: Array) -> Callable:
	var column := Kit.block(parent, "CreationGabiNote", "Gabi se présente", 1.0, true)
	var row := C.h(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var medallion := Medallion.new()
	medallion.name = "CreationGabiPortrait"
	medallion.custom_minimum_size = Vector2(C.px(150), C.px(150))
	medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(medallion)
	var face := PORTRAIT.new() as TextureRect
	face.name = "CreationGabiFace"
	medallion.disc.add_child(face)
	face.set_context("territoire")
	var side := C.v(6)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(C.fill(side))
	var who := C.h(8)
	side.add_child(who)
	who.add_child(C.label("Gabi", 30, C.IVORY, true, 800))
	var role := C.label("l’ancien du club, à tes côtés", 17, C.MUTED, false)
	role.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	who.add_child(role)
	var bubble := PanelContainer.new()
	bubble.name = "CreationGabiBubble"
	bubble.set_meta("immersive_style_applied", true)
	var style := C.box(Color("22302c"), Editorial.RAIL_GOLD, 6, 12)
	style.border_width_left = maxi(3, C.px(4))
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	bubble.add_theme_stylebox_override("panel", style)
	side.add_child(bubble)
	var speech := C.wrap("", 20, C.IVORY)
	speech.name = "CreationGabiSpeech"
	bubble.add_child(speech)
	var own := str(selected.get("division", ""))
	var refresh := func(start: String) -> void:
		speech.text = text(app, own, catalogue, start if choosable else "", bool(app.management_ui.get("creation_vary_current", true)))
	refresh.call(str(app.management_ui.get("creation_start", "premiers-clubs")))
	return refresh

## Bulle de Gabi (au plus 181 caractères) : une phrase par option, la moins utile tombe si la bulle déborde.
static func text(app: Control, own: String, catalogue: Array, start: String, vary: bool) -> String:
	var all := LeagueDetail.leagues(app, catalogue)
	var ids := LeagueDetail.selected(app, own, all)
	var result := LeagueDetail.estimate(LeagueDetail.benchmark(app).get("costs", {}), ids)
	var leagues := "Ton championnat suivi de près, le reste de loin." if ids.size() <= 1 else "%d championnats suivis de près." % ids.size()
	if not result.is_empty():
		var label := str((result.level as Dictionary).get("label", "")).to_lower()
		if not label.is_empty(): leagues = leagues.trim_suffix(".") + (", allure %s." % label)
	var arrival := ""
	match start:
		"premiers-clubs": arrival = "Le 13 juillet, c’est toi qui fixes la reprise."
		"club": arrival = "Tu arrives le jour de la reprise, le groupe t’attend."
		"veille": arrival = "Tu arrives la veille du match : j’aurai tout préparé."
	var level := "Les niveaux bougeront un peu, garde l’œil ouvert." if vary else "Les niveaux restent tels quels, seul le potentiel bouge."
	var lines: Array[String] = [leagues]
	if not arrival.is_empty(): lines.append(arrival)
	lines.append(level)
	var speech := " ".join(lines)
	while speech.length() > LIMIT and lines.size() > 1:
		lines.pop_back()
		speech = " ".join(lines)
	return speech.substr(0, LIMIT)

## Disque cerclé d'or qui découpe le portrait (zoom sur la tête et les épaules), comme le médaillon du guide.
class Medallion extends Control:
	var disc := Control.new()
	func _init() -> void:
		disc.name = "CreationGabiDisc"
		disc.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.draw.connect(func() -> void: disc.draw_circle(disc.size / 2.0, minf(disc.size.x, disc.size.y) / 2.0, Color.WHITE))
		add_child(disc)
		resized.connect(_fit)
	func _fit() -> void:
		var gap := maxf(2.0, size.x * .05)
		disc.position = Vector2(gap, gap)
		disc.size = size - Vector2(gap, gap) * 2.0
		disc.queue_redraw()
		if disc.get_child_count() > 0:
			var face := disc.get_child(0) as Control
			var zoomed := disc.size * 1.45
			face.size = zoomed
			face.position = disc.size / 2.0 - Vector2(.52, .42) * zoomed
		queue_redraw()
	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		draw_circle(center + Vector2(0, radius * .06), radius, Color(0, 0, 0, .35))
		draw_circle(center, radius, Color("0f2a20"))
		for i in 6:
			draw_circle(center + Vector2(0, -radius * .18), radius * (.78 - i * .1), Color(Editorial.RAIL_GOLD, .04))
		draw_arc(center, radius - 1.5, 0, TAU, 96, Editorial.RAIL_GOLD, maxf(2.0, radius * .05), true)
