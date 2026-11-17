extends RefCounted
## Écran « Options de carrière » · « Championnats suivis » : les championnats du Monde regroupés par pays
## (drapeaux et nom), chacun avec son logo (identité du pack, sinon trophée de la compétition, sinon blason
## généré), son nom, son nombre de clubs et son état. Un clic bascule le championnat entre détail complet et
## consultation ; le championnat du club reste en détail. Raccourcis et vitesse estimée restent compacts.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const GameSkin = preload("res://ui/game_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const LeagueDetail = preload("res://ui/league_detail_view.gd")
const Kit = preload("res://ui/creation_options/kit.gd")

## Pays (ou ensemble de pays) : identifiant, nom, drapeaux (art/flags), championnats dans l'ordre du jeu.
const GROUPS := [
	["FR", "France", ["fr"], ["elite", "accession", "nationale"]],
	["GB", "Angleterre", ["gb-eng"], ["prem", "champ"]],
	["URC", "Irlande · Galles · Écosse · Italie · Afrique du Sud", ["ie", "gb-wls", "gb-sct", "it", "za"], ["urc"]],
	["SRP", "Nouvelle-Zélande · Australie · Pacifique", ["nz", "au", "fj"], ["srp"]],
	["JP", "Japon", ["jp"], ["jlo-d1", "jlo-d2"]],
]
const PILL_HEIGHT := 78
const LOGO := 58

static func build(app: Control, parent: Node, own: String, catalogue: Array) -> VBoxContainer:
	var all := LeagueDetail.leagues(app, catalogue)
	var column := Kit.block(parent, "CreationLeagueDetail", "Championnats suivis", 1.0, true)
	if all.size() < 2:
		column.add_child(C.wrap("Ton championnat est suivi en détail complet : notes des joueurs, équipes-types et feuilles de match.", 19, C.MUTED))
		return column
	LeagueDetail.request_benchmark(app)
	var ids := LeagueDetail.selected(app, own, all)
	var count := C.label("%d en détail complet sur %d" % [ids.size(), all.size()], 19, C.IVORY, false, 600)
	count.name = "CreationLeagueDetailCount"
	count.tooltip_text = "Les autres championnats sont suivis en consultation."
	count.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.aside(column).add_child(count)
	LeagueDetail.gauge(column, app, ids, true, true)
	var shortcuts := C.h(8)
	shortcuts.name = "CreationLeaguePresets"
	column.add_child(shortcuts)
	var presets := [["auto", "Selon ton PC"], ["all", "Tout en détail"], ["own", "Seulement mon championnat"]]
	for item: Array in presets:
		var shortcut := G.button(item[1], LeagueDetail.preset.bind(app, own, catalogue, item[0]))
		shortcut.name = "CreationLeaguePreset_" + item[0]
		shortcut.disabled = app.waiting or (item[0] == "auto" and LeagueDetail.benchmark(app).get("costs", {}).is_empty())
		if item[0] == "auto": shortcut.tooltip_text = "Choix automatique selon ton PC : le plus de championnats en détail sans ralentir la partie."
		Editorial.action(shortcut, false, false, maxi(28, C.px(40)))
		shortcut.add_theme_font_size_override("font_size", maxi(13, C.px(19)))
		shortcuts.add_child(shortcut)
	var hint := C.wrap("Détail complet : notes, équipes-types et feuilles de match. Consultation : scores, classements et blessures, et le monde avance plus vite. Clique sur un championnat pour changer.", 17, C.MUTED)
	hint.name = "CreationLeagueHint"
	column.add_child(hint)
	var known := {}
	for league: Dictionary in all: known[str(league.id)] = league
	var present: Array = []
	for group: Array in GROUPS:
		var members: Array = (group[3] as Array).filter(func(id: String): return known.has(id))
		if not members.is_empty(): present.append([group, members])
	# Deux colonnes équilibrées (pays entiers, dans l'ordre du jeu).
	var split := _split(present)
	var columns := C.h(14)
	columns.name = "CreationLeagueColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	for side in 2:
		var stack := C.v(10)
		C.fill(stack)
		columns.add_child(stack)
		for entry: Array in (present.slice(0, split) if side == 0 else present.slice(split)):
			_country(app, stack, entry[0], entry[1], known, ids, own, catalogue)
	var later := C.h(6)
	later.name = "CreationLeagueLater"
	later.size_flags_vertical = Control.SIZE_SHRINK_END
	column.add_child(later)
	var gear := C.icon("settings", 17, C.FAINT)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	later.add_child(gear)
	later.add_child(C.fill(C.wrap("Ce choix reste modifiable en cours de partie, dans les Réglages.", 17, C.FAINT)))
	return column

static func _split(present: Array) -> int:
	var weights: Array[int] = []
	var total := 0
	for entry: Array in present:
		var weight: int = 1 + (entry[1] as Array).size() * 2
		weights.append(weight)
		total += weight
	var best := ceili(present.size() / 2.0)
	var gap := total
	var running := 0
	for index in present.size():
		running += weights[index]
		if absi(total - 2 * running) < gap:
			gap = absi(total - 2 * running)
			best = index + 1
	return clampi(best, 1, maxi(1, present.size() - 1)) if present.size() > 1 else present.size()

static func _country(app: Control, parent: Node, group: Array, members: Array, known: Dictionary, ids: Array, own: String, catalogue: Array) -> void:
	var block := C.v(6)
	block.name = "CreationLeagueCountry_" + str(group[0])
	parent.add_child(block)
	var head := C.h(8)
	block.add_child(head)
	var flags := C.h(4)
	flags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(flags)
	for flag: String in group[2]:
		var image := TextureRect.new()
		image.name = "CreationLeagueFlag_" + flag
		image.texture = load("res://art/flags/%s.svg" % flag)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(C.px(33), C.px(22))
		image.tooltip_text = str(group[1])
		image.mouse_filter = Control.MOUSE_FILTER_PASS
		flags.add_child(image)
	var title := C.wrap(str(group[1]), 21, C.IVORY, true, 700)
	title.name = "CreationLeagueCountryName"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(C.fill(title))
	var followed := members.filter(func(id: String): return id in ids).size()
	var tally := C.label("%d/%d en détail" % [followed, members.size()], 17, C.GOLD if followed > 0 else C.MUTED, false, 600)
	tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tally)
	for id: String in members:
		_card(app, block, known[id], id in ids, id == own, own, catalogue)

## Logo du championnat : identité du pack, sinon trophée de la compétition, sinon blason généré.
static func logo(app: Control, id: String, name: String, width: int) -> Control:
	var identity: Dictionary = app.pack_manager.competition(id, "creation") if app.pack_manager.has_method("competition") else {}
	var texture: Texture2D = GameSkin._pack_texture(str(identity.get("logoPath", "")))
	if texture == null: texture = Kit.entry().call("_trophy_texture", id)
	if texture == null:
		var badge := G.crest({"name":name}, width)
		badge.name = "CreationLeagueLogo_" + id
		return badge
	var image := TextureRect.new()
	image.name = "CreationLeagueLogo_" + id
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(width, width)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

static func _card(app: Control, parent: Node, league: Dictionary, detailed: bool, mine: bool, own: String, catalogue: Array) -> void:
	var id := str(league.id)
	var card := Button.new()
	card.name = "CreationLeagueCard_" + id
	card.disabled = app.waiting
	card.focus_mode = Control.FOCUS_ALL
	card.accessibility_name = "%s, %s" % [league.name, "ton championnat" if mine else ("en détail complet" if detailed else "en consultation")]
	card.tooltip_text = "Ton championnat : toujours en détail complet." if mine else ("Détail complet · clique pour passer en consultation" if detailed else "Consultation · clique pour suivre en détail complet")
	Editorial.action(card, false, detailed, C.px(PILL_HEIGHT), true)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := card.get_theme_stylebox(state) as StyleBoxFlat
		if style == null: continue
		style = style.duplicate()
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		if state != "focus":
			style.bg_color = Color("2b2a20") if detailed else Kit.DEEP
			if state == "hover": style.bg_color = style.bg_color.lightened(.07)
			style.border_color = Editorial.RAIL_GOLD if detailed else Color(Editorial.LINE, .7)
			style.set_border_width_all(1)
			if detailed: style.border_width_left = maxi(3, C.px(5))
		card.add_theme_stylebox_override(state, style)
	if not mine: card.pressed.connect(LeagueDetail.toggle.bind(app, own, catalogue, id))
	parent.add_child(card)
	var inset := C.margin(8)
	inset.add_theme_constant_override("margin_left", C.px(12))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(inset)
	var row := C.h(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)
	var badge := logo(app, id, str(league.name), C.px(LOGO))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not detailed: badge.modulate = Color(1, 1, 1, .62)
	row.add_child(badge)
	var text := C.v(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(C.fill(text))
	var name := Kit.ellipsis(C.label(str(league.name), 23, C.IVORY if detailed else Color(C.IVORY, .82), true, 700))
	name.name = "CreationLeagueCardName"
	text.add_child(name)
	var state := "Ton championnat" if mine else ("Détail complet" if detailed else "Consultation")
	var status := Kit.ellipsis(C.label("%d clubs · %s" % [int(league.clubs), state], 17, C.GOLD if mine else (C.MINT if detailed else C.MUTED), false, 600))
	status.name = "CreationLeagueCardState"
	text.add_child(status)
	var mark := C.icon("shield" if mine else ("check" if detailed else "search"), 22, C.GOLD if mine else (C.MINT if detailed else C.FAINT))
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	card.custom_minimum_size.y = C.px(PILL_HEIGHT)
