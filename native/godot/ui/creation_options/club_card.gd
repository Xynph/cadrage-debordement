extends RefCounted
## Écran « Options de carrière » · rappel du club choisi : photo du stade en fond, écusson, nom, territoire,
## fondation, puis le niveau (palier écrit) et l'effectif de départ en grand.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")

static func build(app: Control, parent: Node, selected: Dictionary, base_identity: bool) -> void:
	var frame := PanelContainer.new()
	frame.name = "CreationOptionsClub"
	frame.set_meta("immersive_style_applied", true)
	var style := C.box(Kit.DEEP, Editorial.LINE, 0, 0)
	style.set_corner_radius_all(0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, 1)
	frame.add_theme_stylebox_override("panel", style)
	frame.clip_contents = true
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var photo := G.club_picture(selected, "stadium", true)
	photo.name = "CreationStadium"
	photo.custom_minimum_size = Vector2(0, C.px(250))
	photo.mouse_filter = Control.MOUSE_FILTER_PASS
	var venue := str(selected.get("stadium", ""))
	if not venue.is_empty(): photo.tooltip_text = venue if photo.tooltip_text.is_empty() else "%s\n%s" % [venue, photo.tooltip_text]
	frame.add_child(photo)
	var veil := ColorRect.new()
	veil.color = Color(Kit.DEEP, .35)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(veil)
	var inset := C.margin(16)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inset)
	var stack := C.v(6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(stack)
	stack.add_child(Kit.caps("Ton club"))
	var identity := C.h(14)
	stack.add_child(identity)
	var crest: Control = Kit.entry().call("_creation_crest", selected, C.px(96), base_identity)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(crest)
	var copy := C.v(0)
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(C.fill(copy))
	var title := C.wrap(G.club_name(selected), 36, C.IVORY, true, 800)
	title.name = "CreationClubTitle"
	title.uppercase = true
	title.max_lines_visible = 2
	title.add_theme_constant_override("line_spacing", -C.px(5))
	copy.add_child(title)
	copy.add_child(Kit.ellipsis(C.label(str(Kit.entry().call("_territory", selected)), 18, C.IVORY, false)))
	var history: Dictionary = selected.get("history", {}) if selected.get("history") is Dictionary else {}
	if history.has("founded"):
		var founded := C.label("Fondé en %d" % int(history.founded), 17, Editorial.RAIL_GOLD, true, 700)
		founded.name = "CreationClubFounded"
		copy.add_child(founded)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(C.fill(spacer, true))
	var facts := C.h(14)
	facts.name = "CreationOptionsClubFacts"
	stack.add_child(facts)
	var roster: Dictionary = selected.get("startingRoster", {}) if selected.get("startingRoster") is Dictionary else {}
	if not roster.is_empty():
		var rating := Kit.figure(facts, str(Kit.entry().call("_rating", roster)), "niveau", C.IVORY, 26)
		rating.name = "CreationRosterSummary"
		Kit.divider(facts)
		Kit.figure(facts, str(int(roster.get("forwards", 0)) + int(roster.get("backs", 0))), "joueurs", C.IVORY, 36)
	if not venue.is_empty():
		if not roster.is_empty(): Kit.divider(facts)
		var ground := C.v(0)
		facts.add_child(C.fill(ground))
		var place := C.wrap(venue, 20, C.IVORY, true, 700)
		place.max_lines_visible = 2
		ground.add_child(place)
		ground.add_child(C.label("à domicile", 17, C.MUTED, false))
