extends Node
## État des commandes propre aux deux vues de Préparation.
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const PRE_MATCH_HINT = "Le choix principal s’applique en l’absence d’une consigne par zone."

enum Phase { BEFORE, RUNNING, PAUSED, HALFTIME, FINISHED, SEASON_ENDED }

var consignes: Control
var status: Label
var status_row: Control
var pause_button: Button
var match_button: Button
var focus_fallback: Button
var tactics: Array[Button] = []
var app: Control
var bridge: Node
var current_phase := Phase.BEFORE
var tactics_available := false
var phase_applied := false
var engine_was_busy := false

static func match_available(model: Dictionary) -> bool:
	var live: Variant = model.get("live")
	var fixture: Variant = model.get("next")
	return (live is Dictionary and not live.is_empty()) or (fixture is Dictionary and not fixture.is_empty() and SeasonPreparation.data(model.get("meta", {})).is_empty())

func bind(application: Control) -> void:
	app = application
	bridge = app.bridge
	_on_model_changed(app.model)
	bridge.model_changed.connect(_on_model_changed)

func _exit_tree() -> void:
	if is_instance_valid(bridge) and bridge.model_changed.is_connected(_on_model_changed):
		bridge.model_changed.disconnect(_on_model_changed)

func open_match() -> void:
	if match_available(app.model):
		app._navigate("Match")

func pause_match() -> void:
	if not _engine_busy() and _phase(app.model) == Phase.RUNNING:
		if app._command("pause", {"paused": true}):
			if pause_button.has_focus(): focus_fallback.grab_focus()
			_sync_actions()

func can_edit_tactics() -> bool:
	return not _engine_busy() and _tactics_available(app.model, _phase(app.model))

func _phase(model: Dictionary) -> Phase:
	var live: Variant = model.get("live")
	if live is Dictionary and not live.is_empty():
		if live.get("finished", false): return Phase.FINISHED
		if live.get("atBreak", false): return Phase.HALFTIME
		if live.get("paused", false): return Phase.PAUSED
		return Phase.RUNNING
	return Phase.SEASON_ENDED if model.get("meta", {}).get("phase") == "ended" else Phase.BEFORE

func _tactics_available(model: Dictionary, phase: Phase) -> bool:
	if phase == Phase.BEFORE: return true
	if phase not in [Phase.PAUSED, Phase.HALFTIME]: return false
	# The live playbook publishes the presentation lock for matches it supports.
	# Older formats without its live projection keep the existing pause guard.
	var playbook: Variant = model.get("clubLife", {}).get("playbook")
	return not (playbook is Dictionary and not playbook.get("preview", []).is_empty()) or bool(playbook.get("available", false))

func _on_model_changed(model: Dictionary) -> void:
	var phase := _phase(model)
	var available := _tactics_available(model, phase)
	if phase_applied and phase == current_phase and available == tactics_available: return
	phase_applied = true
	current_phase = phase
	tactics_available = available
	if match_button != null:
		var caption := "Aller au jour de match"
		if phase == Phase.FINISHED: caption = "Voir le résultat"
		elif phase in [Phase.RUNNING, Phase.PAUSED, Phase.HALFTIME]: caption = "Reprendre le match"
		match_button.text = caption.to_upper() + "  →" if status_row != null else caption
	if status != null:
		status.text = _status_text(phase, available)
		status.tooltip_text = status.text
		if status_row != null: status_row.visible = phase != Phase.BEFORE
		if phase != Phase.RUNNING and pause_button.has_focus(): focus_fallback.grab_focus()
		pause_button.visible = phase == Phase.RUNNING
	set_process(consignes != null and (phase == Phase.RUNNING or available))
	_sync_actions(true)

func _status_text(phase: Phase, available: bool) -> String:
	var edit_hint := "Vous pouvez modifier vos consignes." if available else "Les consignes sont momentanément indisponibles."
	match phase:
		Phase.RUNNING: return "Match en cours · Pause requise pour modifier vos consignes."
		Phase.PAUSED: return "Match en pause · " + edit_hint
		Phase.HALFTIME: return "Mi-temps · " + edit_hint
		Phase.FINISHED: return "Match terminé · Les consignes sont closes."
		Phase.SEASON_ENDED: return "Saison terminée · Les consignes sont closes."
	return PRE_MATCH_HINT

func _engine_busy() -> bool:
	return app.waiting or app.closing or app.connection_error

func _process(_delta: float) -> void:
	# There is no signal when a request starts. Poll the local guard while
	# the controls can act, without redrawing or replacing any of them.
	if consignes.is_visible_in_tree(): _sync_actions()

func _sync_actions(force: bool = false) -> void:
	var busy := _engine_busy()
	if not force and busy == engine_was_busy: return
	engine_was_busy = busy
	if pause_button != null: pause_button.disabled = busy
	for button in tactics:
		button.disabled = not tactics_available or busy
