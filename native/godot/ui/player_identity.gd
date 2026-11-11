extends RefCounted

const C = preload("res://ui/immersive08/components.gd")

static func identity_parts(facts: Dictionary) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if facts.is_empty(): return parts
	var origin := str(facts.get("nationality", "—"))
	var flag := str(facts.get("flagCode", "")) if facts.get("flagCode") is String else ""
	var selection := str(facts.get("seniorNationName", "")) if facts.get("seniorNationName") is String else ""
	var selection_flag := str(facts.get("seniorFlagCode", "")) if facts.get("seniorFlagCode") is String else ""
	var caps := "%d sélections XV" % int(facts.get("seniorCaps", 0))
	var same_team := not selection.is_empty() and (origin == selection or (not flag.is_empty() and flag == selection_flag))
	parts.append({"flag": flag, "text": origin + (" · " + caps if same_team else ""), "key": "Origin"})
	var sizes: Array[String] = []
	if facts.get("heightCm") is float or facts.get("heightCm") is int: sizes.append("%d cm" % int(facts.heightCm))
	if facts.get("weightKg") is float or facts.get("weightKg") is int: sizes.append("%d kg" % int(facts.weightKg))
	if not sizes.is_empty(): parts.append({"flag": "", "text": " · ".join(sizes), "key": "Dimensions"})
	if not same_team:
		parts.append({"flag": selection_flag, "text": (selection + " · " if not selection.is_empty() else "") + caps, "key": "Caps"})
	return parts

static func flag_texture(code: String) -> Texture2D:
	if code.is_empty() or code.length() > 6 or code.validate_filename() != code or code.contains("."): return null
	var path := "res://art/flags/%s.svg" % code
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func nation_for_flag(model: Dictionary, flag: String) -> String:
	if flag.is_empty(): return ""
	var international: Variant = model.get("international")
	if not international is Dictionary: return ""
	for team: Dictionary in international.get("teams", []):
		if str(team.get("flagCode", "")) == flag: return str(team.get("id", ""))
	return ""

static func row(facts: Dictionary, size: int, color: Color, app: Control = null) -> HBoxContainer:
	var body := C.h(7)
	body.name = "PlayerIdentityFacts"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: Dictionary in identity_parts(facts):
		if body.get_child_count() > 0: body.add_child(C.label("·", size, color))
		var texture := flag_texture(part.flag)
		if texture != null:
			var flag := TextureRect.new()
			flag.name = "Player" + str(part.key) + "Flag"
			flag.texture = texture
			flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flag.custom_minimum_size = Vector2(C.px(size + 5), C.px(size))
			flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var nation_id := nation_for_flag(app.model, str(part.flag)) if app != null else ""
			if not nation_id.is_empty():
				var link := Button.new()
				link.name = "Player" + str(part.key) + "NationLink"
				link.custom_minimum_size = flag.custom_minimum_size + Vector2(6, 4)
				link.accessibility_name = "Consulter la sélection · " + str(part.text).get_slice(" · ", 0)
				link.tooltip_text = link.accessibility_name
				link.set_meta("entity_kind", "nation")
				link.set_meta("entity_id", nation_id)
				link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				link.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, C.GOLD, 2, 1))
				link.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"nation", "id":nation_id}))
				body.add_child(link)
				link.add_child(flag)
				flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			else: body.add_child(flag)
		var label := C.label(part.text, size, color)
		label.name = "Player" + str(part.key) + "Fact"
		body.add_child(label)
	return body
