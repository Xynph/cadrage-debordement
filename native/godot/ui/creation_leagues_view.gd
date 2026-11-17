extends RefCounted
## Écran « Options de carrière » : les championnats du Monde regroupés par pays (drapeaux, nom du pays),
## une vignette par championnat (photo, logo, nom, nombre de clubs, état). Un clic bascule le championnat
## entre détail complet et consultation ; le championnat du club reste toujours en détail.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const LeagueDetail = preload("res://ui/league_detail_view.gd")

## Pays (ou ensemble de pays) : identifiant, nom, drapeaux (art/flags), championnats dans l'ordre du jeu.
const GROUPS := [
	["FR", "France", ["fr"], ["elite", "accession", "nationale"]],
	["GB", "Angleterre", ["gb-eng"], ["prem", "champ"]],
	["URC", "Irlande · Galles · Écosse · Italie · Afrique du Sud", ["ie", "gb-wls", "gb-sct", "it", "za"], ["urc"]],
	["SRP", "Nouvelle-Zélande · Australie · Pacifique", ["nz", "au", "fj"], ["srp"]],
	["JP", "Japon", ["jp"], ["jlo-d1", "jlo-d2"]],
]
## Photo d'ambiance de chaque championnat (art/immersive08).
const ART := {
	"elite": "maquette-onglets-stadium", "accession": "stadium", "nationale": "nationale-ground",
	"prem": "match-tunnel", "champ": "champ-ground", "urc": "club-forest", "srp": "pacific-ground",
	"jlo-d1": "japan-ground", "jlo-d2": "training-session",
}
const CARD_WIDTH := 300
const PHOTO_HEIGHT := 118

static func build(app: Control, parent: Node, own: String, catalogue: Array) -> void:
	var all := LeagueDetail.leagues(app, catalogue)
	if all.size() < 2: return
	LeagueDetail.request_benchmark(app)
	var ids := LeagueDetail.selected(app, own, all)
	var count := C.label("%d en détail complet sur %d · les autres en consultation" % [ids.size(), all.size()], 22, C.IVORY, false, 600)
	count.name = "CreationLeagueDetailCount"
	parent.add_child(count)
	parent.add_child(C.wrap("En détail complet : notes des joueurs, équipes-types et feuilles de match de chaque rencontre. En consultation : scores, classements et blessures, et le monde avance plus vite. Clique sur un championnat pour changer.", 18, C.MUTED))
	LeagueDetail.gauge(parent, app, ids, true)
	var shortcuts := C.h(10)
	shortcuts.name = "CreationLeaguePresets"
	parent.add_child(shortcuts)
	var presets := [["auto", "Choix automatique selon ton PC"], ["all", "Tout en détail"], ["own", "Seulement mon championnat"]]
	for item: Array in presets:
		var shortcut := G.button(item[1], LeagueDetail.preset.bind(app, own, catalogue, item[0]))
		shortcut.name = "CreationLeaguePreset_" + item[0]
		shortcut.disabled = app.waiting or (item[0] == "auto" and LeagueDetail.benchmark(app).get("costs", {}).is_empty())
		Editorial.action(shortcut, false, false, maxi(32, C.px(46)))
		shortcuts.add_child(shortcut)
	var known := {}
	for league: Dictionary in all: known[str(league.id)] = league
	for group: Array in GROUPS:
		var members: Array = (group[3] as Array).filter(func(id: String): return known.has(id))
		if members.is_empty(): continue
		_country(app, parent, group, members, known, ids, own, catalogue)

static func _country(app: Control, parent: Node, group: Array, members: Array, known: Dictionary, ids: Array, own: String, catalogue: Array) -> void:
	var block := C.v(8)
	block.name = "CreationLeagueCountry_" + str(group[0])
	parent.add_child(block)
	var head := C.h(10)
	block.add_child(head)
	for flag: String in group[2]:
		var image := TextureRect.new()
		image.texture = load("res://art/flags/%s.svg" % flag)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(C.px(42), C.px(28))
		image.tooltip_text = str(group[1])
		head.add_child(image)
	var title := C.label(str(group[1]), 24, C.IVORY, true, 700)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var followed := members.filter(func(id: String): return id in ids).size()
	var tally := C.label("%d / %d en détail" % [followed, members.size()], 18, C.GOLD if followed > 0 else C.MUTED, false, 600)
	tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tally)
	var cards := HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", C.px(12))
	cards.add_theme_constant_override("v_separation", C.px(12))
	block.add_child(cards)
	for id: String in members:
		_card(app, cards, known[id], id in ids, id == own, own, catalogue)

static func _card(app: Control, parent: Node, league: Dictionary, detailed: bool, mine: bool, own: String, catalogue: Array) -> void:
	var id := str(league.id)
	var card := Button.new()
	card.name = "CreationLeagueCard_" + id
	card.toggle_mode = false
	card.disabled = app.waiting
	card.custom_minimum_size = Vector2(C.px(CARD_WIDTH), C.px(PHOTO_HEIGHT + 104))
	card.accessibility_name = "%s, %s" % [league.name, "ton championnat" if mine else ("en détail complet" if detailed else "en consultation")]
	card.tooltip_text = "Ton championnat : toujours en détail complet." if mine else ("Passer en consultation" if detailed else "Suivre en détail complet")
	Editorial.action(card, false, detailed, C.px(PHOTO_HEIGHT + 104), true)
	if detailed:
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := card.get_theme_stylebox(state) as StyleBoxFlat
			if style == null: continue
			style = style.duplicate()
			style.border_color = Editorial.RAIL_GOLD
			style.set_border_width_all(maxi(2, C.px(3)))
			card.add_theme_stylebox_override(state, style)
	if not mine: card.pressed.connect(LeagueDetail.toggle.bind(app, own, catalogue, id))
	parent.add_child(card)
	var column := C.v(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(column)
	var photo := C.photo(str(ART.get(id, "stadium")), Vector2(CARD_WIDTH, PHOTO_HEIGHT), true, .5)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.clip_contents = true
	if not detailed: photo.modulate = Color(.62, .62, .62)
	column.add_child(photo)
	var identity: Dictionary = app.pack_manager.competition(id, "creation") if app.pack_manager.has_method("competition") else {}
	var logo := str(identity.get("logoPath", ""))
	if not logo.is_empty():
		var crest := G.crest({"logoPath":logo, "name":league.name}, C.px(46))
		crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.add_child(crest)
		crest.position = Vector2(C.px(10), C.px(PHOTO_HEIGHT - 56))
	var inset := C.margin(10)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(inset)
	var text := C.v(2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(text)
	var name := C.wrap(str(league.name), 21, C.IVORY, true, 700)
	name.name = "CreationLeagueCardName"
	name.max_lines_visible = 2
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name)
	var state := "Ton championnat" if mine else ("✓ Détail complet" if detailed else "Consultation")
	var status := C.label("%d clubs · %s" % [int(league.clubs), state], 17, C.GOLD if mine else (C.MINT if detailed else C.MUTED), false, 600)
	status.name = "CreationLeagueCardState"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(status)
