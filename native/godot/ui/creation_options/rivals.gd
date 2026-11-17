extends RefCounted
## Écran « Options de carrière » · « Rivalités et derbys » : les rivaux du club (écusson, nom, jauge de
## tension) et les dates des derbys quand le calendrier les connaît.
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const SHOWN := 3

static func build(app: Control, parent: Node, selected: Dictionary, data: Dictionary, state: String) -> void:
	var column := Kit.block(parent, "CreationRivals", "Rivalités et derbys", 1.0, true)
	var list := C.v(16)
	list.name = "CreationRivalList"
	column.add_child(list)
	# Ambiance du tunnel dans la place restante (aucune hauteur imposée : rien ne déborde en petite fenêtre).
	var mood := C.photo("match-tunnel", Vector2.ZERO, true, .45)
	mood.name = "CreationRivalsMood"
	mood.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mood.modulate = Color(.78, .78, .78)
	mood.tooltip_text = ""
	column.add_child(mood)
	# Une bande trop fine ne se montre pas (le contrôle garde sa place pour suivre les redimensionnements).
	mood.resized.connect(func() -> void: mood.self_modulate.a = 1.0 if mood.size.y >= C.px(40) else 0.0)
	list.set_meta("division", str(selected.get("division", "")))
	var rivals: Array = data.get("rivals", []) if data.get("rivals") is Array else []
	if state == "pending" and rivals.is_empty():
		for index in SHOWN:
			var row := C.h(12)
			list.add_child(row)
			row.add_child(Kit.disc_ghost(48))
			var side := C.v(6)
			side.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(C.fill(side))
			side.add_child(Kit.ghost(180, 18))
			side.add_child(Kit.ghost(0, 7, true))
		return
	if rivals.is_empty():
		var calm := C.wrap("Les rivalités du club se vivent dans l’espace Rivalités, dès ton arrivée : chaque derby y garde sa tension.", 19, C.MUTED)
		calm.name = "CreationRivalsEmpty"
		list.add_child(calm)
		return
	for rival: Variant in rivals.slice(0, SHOWN):
		if rival is Dictionary: _rival(app, list, rival)

## Tension ramenée sur 100 (le moteur peut la donner sur 1, 5, 10 ou 100).
static func tension(value: Variant) -> float:
	var raw := float(value) if value is float or value is int else 0.0
	if raw <= 1.0: raw *= 100.0
	elif raw <= 5.0: raw *= 20.0
	elif raw <= 10.0: raw *= 10.0
	return clampf(raw, 0.0, 100.0)

static func _rival(app: Control, list: VBoxContainer, rival: Dictionary) -> void:
	var name := Kit.club_name(app, rival.get("id"), str(rival.get("name", "")))
	var heat := tension(rival.get("tension", 0))
	var color := C.ALERT if heat >= 80 else (C.AMBER if heat >= 70 else (Editorial.RAIL_GOLD if heat >= 50 else C.MUTED))
	var word := "Brûlante" if heat >= 80 else ("Vive" if heat >= 70 else ("Réelle" if heat >= 50 else "Cordiale"))
	var row := C.h(12)
	row.name = "CreationRival_" + str(rival.get("id", name))
	list.add_child(row)
	row.add_child(Kit.crest(app, rival.get("id"), name, C.px(56)))
	var side := C.v(3)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(C.fill(side))
	var head := C.h(8)
	side.add_child(head)
	head.add_child(C.fill(Kit.ellipsis(C.label(name, 22, C.IVORY, true, 700))))
	var level := C.label(word, 17, color, true, 700)
	level.name = "CreationRivalTension"
	head.add_child(level)
	var gauge := C.gauge(heat, color, 6)
	gauge.name = "CreationRivalGauge"
	gauge.set_meta("immersive_style_applied", true)
	gauge.tooltip_text = "Tension %d / 100" % roundi(heat)
	side.add_child(gauge)
	var dates: Array = rival.get("dates", []) if rival.get("dates") is Array else []
	var days := PackedStringArray()
	for iso: Variant in dates.slice(0, 3):
		var day := Kit.day_month(str(iso))
		if not day.is_empty(): days.append(day)
	var other := Kit.club_by_id(app, rival.get("id"))
	var elsewhere := not other.is_empty() and str(other.get("division", "")) != str(list.get_meta("division", ""))
	var note := "Derbys · " + " · ".join(days) if not days.is_empty() else ("Pas dans ta division cette saison" if elsewhere else "Dates des derbys au calendrier")
	var when := Kit.ellipsis(C.label(note, 17, C.MUTED, false))
	when.name = "CreationRivalDates"
	side.add_child(when)
