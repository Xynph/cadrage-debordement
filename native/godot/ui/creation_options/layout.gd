extends RefCounted
## Écran « Options de carrière » (étape 03 de la création, après le choix du club) : une page dense et
## éditoriale, sans défilement en 1920×1080. Grille en trois colonnes alignées sur deux rangs :
##   rang 1 · ton club (photo du stade) | ta première saison (frise et départ) | Gabi se présente
##   rang 2 · le mot du président, rivalités | championnats suivis, puis « Changer de club » et « Prendre
##            les rênes » | ton vestiaire et niveau de départ, les rendez-vous.
## Les blocs qui dépendent de l'aperçu moteur (`club_preview`) montrent des emplacements tant qu'il manque,
## puis se replient sur le catalogue de création si le moteur ne le fournit pas.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const ClubCard = preload("res://ui/creation_options/club_card.gd")
const Timeline = preload("res://ui/creation_options/season_timeline.gd")
const Gabi = preload("res://ui/creation_options/gabi_note.gd")
const President = preload("res://ui/creation_options/president_word.gd")
const Rivals = preload("res://ui/creation_options/rivals.gd")
const Leagues = preload("res://ui/creation_options/leagues.gd")
const Faces = preload("res://ui/creation_options/squad_faces.gd")
const Appointments = preload("res://ui/creation_options/appointments.gd")
## Largeur relative des trois colonnes (club et président | championnats et frise | vestiaire et Gabi).
const RATIOS := [.25, .43, .32]
const GAP := 14
## Les six blocs ajoutés (contrôlés par les tests de l'écran).
const BLOCKS := ["CreationSeasonTimeline", "CreationPresidentWord", "CreationGabiNote", "CreationAppointments", "CreationRivals", "CreationSquadFaces"]

static func build(app: Control, page: Control, selected: Dictionary, mode: String, role: String, nation: Dictionary, candidates: Array, preferred: String, division: String) -> void:
	var club_id := int(selected.get("id", -1))
	var data := Kit.preview(app, club_id)
	var state := Kit.preview_state(app, club_id)
	var choosable := mode == "world-champ" and role != "nation"
	var own := str(selected.get("division", division))
	var scroll := ScrollContainer.new()
	scroll.name = "CreationCareerOptionsScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	C.fill(scroll, true)
	page.add_child(scroll)
	var grid := C.v(GAP)
	grid.name = "CreationCareerOptions"
	grid.set_meta("preview_state", state)
	C.fill(grid, true)
	scroll.add_child(grid)
	var listeners: Array[Callable] = []
	var changed := func(start: String) -> void:
		for listener: Callable in listeners:
			if listener.is_valid(): listener.call(start)
	# Rang 1 : le club, la frise de la première saison, Gabi.
	var top := C.h(GAP)
	top.name = "CreationOptionsTop"
	grid.add_child(top)
	ClubCard.build(app, top, selected, preferred == "base")
	Timeline.build(app, top, selected, choosable, data, state, changed)
	var gabi := Gabi.build(app, top, selected, choosable, candidates)
	listeners.append(gabi)
	_ratios(top)
	# Rang 2 : trois colonnes.
	var bottom := C.h(GAP)
	bottom.name = "CreationOptionsColumns"
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(bottom)
	var left := C.v(GAP)
	left.name = "CreationOptionsLeft"
	bottom.add_child(left)
	President.build(app, left, selected, data, state)
	Rivals.build(app, left, selected, data, state)
	var middle := C.v(GAP)
	middle.name = "CreationOptionsMiddle"
	bottom.add_child(middle)
	Leagues.build(app, middle, own if role != "nation" else "", candidates if mode.begins_with("world") else [])
	var right := C.v(GAP)
	right.name = "CreationOptionsRight"
	bottom.add_child(right)
	Faces.build(app, right, selected, data, state, func(_value: bool) -> void:
		if gabi.is_valid(): gabi.call(str(app.management_ui.get("creation_start", "premiers-clubs"))))
	listeners.append(Appointments.build(app, right, selected, choosable, data))
	_actions(app, middle, selected, mode, role, nation, preferred)
	_ratios(bottom)
	Kit.request_preview(app, club_id)

static func _ratios(row: HBoxContainer) -> void:
	for index in mini(row.get_child_count(), RATIOS.size()):
		var child := row.get_child(index) as Control
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		child.size_flags_stretch_ratio = RATIOS[index]

## « Changer de club » et « Prendre les rênes » (création de la carrière).
static func _actions(app: Control, parent: Node, selected: Dictionary, mode: String, role: String, nation: Dictionary, preferred: String) -> void:
	var row := C.h(10)
	row.name = "CreationOptionsActions"
	parent.add_child(row)
	var back := G.button("←  Changer de club", func() -> void:
		app.management_ui["creation_step"] = "club"
		app._render())
	back.name = "CreationBackToClubs"
	back.disabled = app.waiting
	Editorial.action(back, false, false, maxi(36, C.px(66)))
	back.add_theme_font_size_override("font_size", maxi(14, C.px(22)))
	row.add_child(back)
	var installed: Array = app.pack_manager.installed("creation")
	var unavailable := preferred != "base" and not installed.any(func(pack: Dictionary) -> bool: return str(pack.id) == preferred)
	var can_start := role == "club" or not nation.is_empty()
	var start := G.button("Prendre les rênes  →", func() -> void:
		if can_start: Kit.entry().call("_create", app, selected, mode), true)
	start.name = "CreationStart"
	start.disabled = app.waiting or unavailable or not can_start
	Editorial.action(start, true, false, maxi(36, C.px(66)))
	start.add_theme_font_size_override("font_size", maxi(18, C.px(36)))
	row.add_child(C.fill(start))
