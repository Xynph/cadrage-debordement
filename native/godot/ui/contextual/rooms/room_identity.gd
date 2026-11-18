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

## Deuxième couleur du club (maillots, liserés, écussons) : ui/couleurs_clubs.json par slug, généré par
## tools/banque-images/couleurs-clubs.py ; repli sur l'encre neutre de contraste.
const COULEURS_CLUBS := "res://ui/couleurs_clubs.json"
static var _secondaires: Dictionary = {}

static func secondary(identity: Dictionary, primary_color: Color = NEUTRAL_PRIMARY) -> Color:
	if _secondaires.is_empty() and FileAccess.file_exists(COULEURS_CLUBS):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(COULEURS_CLUBS))
		_secondaires = data.get("couleurs", {}) if data is Dictionary else {}
		if _secondaires.is_empty(): _secondaires = {"": ""}
	var value: Variant = identity.get("color2", _secondaires.get(str(identity.get("slug", "")), ""))
	if value is String and Color.html_is_valid(value): return Color.from_string(value, primary_color)
	return contrast(primary_color)
