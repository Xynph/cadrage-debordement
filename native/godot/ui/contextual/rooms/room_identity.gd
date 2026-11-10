extends RefCounted

# Presentation values are resolved at entry, never persisted in the career.
const NEUTRAL_PRIMARY := Color("596368")

static func primary(identity: Dictionary) -> Color:
	var value: Variant = identity.get("color", "")
	if value is Color:
		return Color(value, 1.0)
	if value is String and Color.html_is_valid(value):
		return Color.from_string(value, NEUTRAL_PRIMARY)
	return NEUTRAL_PRIMARY

static func contrast(primary_color: Color) -> Color:
	# Neutral high-contrast ink/trim, explicitly not a claimed club secondary.
	var luminance := primary_color.get_luminance()
	return Color("252b2e") if luminance > 0.43 else Color("e8e5dc")
