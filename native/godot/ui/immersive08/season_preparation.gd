extends RefCounted
## Présentation et sélection de la commande native pendant une semaine sans match.

const ADVANCE_COMMANDS := ["advance_japan_preparation", "advance_pacific_preparation", "advance_champ_preparation"]
const ADVANCE_BUTTONS := [
	"OfficePreparationAction", "OfficePrimaryAction", "JapanPreparationDossierAdvance",
	"JapanPreparationAdvance", "PacificPreparationAdvance", "ChampPreparationAdvance", "CompetitionChampAdvance",
]
const IDLE_LABELS := &"season_preparation_idle_labels"

static func is_advance(command_name: String) -> bool:
	return command_name in ADVANCE_COMMANDS

static func show_pending(app: Control, pending: bool) -> void:
	if not is_instance_valid(app.root_content): return
	for button: Button in app.root_content.find_children("*", "Button", true, false):
		if button != app.primary_button and button.name not in ADVANCE_BUTTONS: continue
		if pending:
			if not button.has_meta(IDLE_LABELS):
				button.set_meta(IDLE_LABELS, [button.text, button.tooltip_text])
			button.text = "Simulation…"
			button.tooltip_text = "Simulation des semaines de préparation en cours."
			button.disabled = true
		elif button.has_meta(IDLE_LABELS):
			var labels: Array = button.get_meta(IDLE_LABELS)
			button.text = labels[0]
			button.tooltip_text = labels[1]
			button.remove_meta(IDLE_LABELS)
			# Sur ces commandes, l’attente est la seule condition d’inactivité.
			button.disabled = false

static func is_japan(meta: Dictionary) -> bool:
	return meta.get("leagueId") in ["jlo-d1", "jlo-d2"]

static func is_champ(meta: Dictionary) -> bool:
	return meta.get("leagueId") == "champ"

static func _kind(meta: Dictionary) -> String:
	if is_japan(meta): return "japan"
	if is_champ(meta): return "champ"
	return "pacific"

static func data(meta: Dictionary) -> Dictionary:
	return meta.get(_kind(meta) + "Preparation", {})

static func command(meta: Dictionary) -> String:
	return "advance_" + _kind(meta) + "_preparation"

static func ground(meta: Dictionary, fallback: String) -> String:
	if is_japan(meta): return "japan-ground"
	if is_champ(meta): return "champ-ground"
	if meta.get("leagueId") == "srp": return "pacific-ground"
	return fallback
