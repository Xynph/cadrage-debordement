extends Control
const S = preload("res://ui/contextual/skin.gd")
var director: Node
var app: Control
var model: Dictionary = {}
var ui: Control
var _fingerprint := ""
var maintained := false

func _ready() -> void:
	name = "ContextualTraining"
	app = director.app
	S.room(self, "training", app.model.get("club", {}))

func update_frame(value: Dictionary, _data: Dictionary = {}) -> void:
	model = value
	var fingerprint := JSON.stringify([value.get("meta", {}).get("trained"), value.get("meta", {}).get("training"), value.get("squad", []), value.get("decisions", {}).get("training", {}), value.get("clubLife", {}).get("clubSupport", {})])
	if fingerprint == _fingerprint: return
	_fingerprint = fingerprint
	_draw()

func _draw() -> void:
	if is_instance_valid(ui): remove_child(ui); ui.queue_free()
	ui = Control.new()
	S.full(ui)
	add_child(ui)
	var column := S.frame(ui, 24)
	var trained: bool = model.get("meta", {}).get("trained", false)
	S.heading(column, model.get("club", {}), "Bilan de la séance" if trained else "Observer la préparation", "Entraînement · décisions du staff")
	var content := S.G.h(20)
	S.G.fill(content, true)
	column.add_child(content)
	var facts := S.panel(content, 16)
	S.G.fill(facts.get_parent(), true)
	var scroll := S.G.scroll(facts)
	S.G.fill(scroll.get_parent(), true)
	var training: Dictionary = model.get("decisions", {}).get("training", {})
	var support: Dictionary = model.get("clubLife", {}).get("clubSupport", {})
	var plan_data: Dictionary = support.get("training", {})
	var session: Dictionary = plan_data.get("session", {})
	scroll.add_child(S.label("Le retour du préparateur", 21, S.GOLD))
	if trained:
		scroll.add_child(S.wrap(str(session.get("reason")) if session.get("reason") != null else "Séance effectuée. Aucun compte rendu détaillé n’est enregistré pour cette séance.", 17, S.TEXT))
	else: scroll.add_child(S.wrap(str(training.get("advice", "Aucun diagnostic disponible pour cette semaine.")), 17, S.TEXT))
	scroll.add_child(S.label("État actuel du groupe", 16, S.GOLD))
	for player: Dictionary in model.get("squad", []):
		var row := S.G.h(9)
		scroll.add_child(row)
		row.add_child(S.G.portrait(int(player.get("portraitIndex", 0)), 34, player))
		var fatigue: Variant = player.get("physicalLoad", {})
		if fatigue is Dictionary: fatigue = fatigue.get("fatigue", "—")
		var injury := int(player.get("injury", 0))
		row.add_child(S.wrap("%s · condition %s · charge %s%s" % [str(player.get("name", "")), str(player.get("condition", "—")), str(fatigue), " · indisponible (%d sem.)" % injury if injury > 0 else ""], 13, S.TEXT))
	var air := Control.new()
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(air, true)
	content.add_child(air)
	var actions := S.panel(content, 16)
	actions.get_parent().custom_minimum_size.x = 390
	actions.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var list := S.G.scroll(actions)
	S.G.fill(list.get_parent(), true)
	if trained:
		list.add_child(S.label("Séance déjà effectuée", 21, S.GOLD))
		list.add_child(S.wrap("Les décisions de cette séance sont en lecture seule.", 16))
	else:
		list.add_child(S.label("Préparer la séance", 21, S.GOLD))
		list.add_child(S.wrap("Configurer les charges et la priorité ne lance pas la séance.", 14))
		var current_mode: String = {"repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}.get(str(model.get("meta", {}).get("training", "normal")), str(model.get("meta", {}).get("training", "normal")))
		list.add_child(S.label("Séance prévue : " + current_mode, 14, S.GOLD))
		list.add_child(S.button("MAINTENIR LES RÉGLAGES", func(): maintained = true; _draw()))
		if maintained: list.add_child(S.label("Réglages conservés. La séance reste à effectuer.", 12, S.GOLD))
		for plan: Dictionary in plan_data.get("plans", []):
			list.add_child(S.wrap(str(plan.get("detail", "")), 13))
			list.add_child(S.button(str(plan.get("label", "")), func(): director.command("training_plan", {"context":support.get("context"), "plan":plan.get("key")}), plan_data.get("available", false)))
		var collective: Dictionary = training.get("collective", {})
		list.add_child(S.label("Changer la priorité", 16, S.GOLD))
		for option: Dictionary in collective.get("options", []):
			var focus := S.button(str(option.get("label", "")), func(): director.command("set_collective_focus", {"focus":option.get("id")}), collective.get("available", false))
			if collective.get("selected") == option.get("id"): S.selected(focus, S.GOLD)
			list.add_child(focus)
		list.add_child(S.button("EFFECTUER LA SÉANCE", _perform_training, plan_data.get("available", false), true))
	column.add_child(S.button("FERMER L’OBSERVATION", director.close_training))
	director._refresh_controls()

func _perform_training() -> void:
	if model.get("meta", {}).get("trained", false): return
	# Maintaining the plan must preserve the actual collective mode, including
	# recovery/intensive. A training_plan response may explicitly change it.
	director.command("train", {"mode":str(model.get("meta", {}).get("training", "normal"))})
