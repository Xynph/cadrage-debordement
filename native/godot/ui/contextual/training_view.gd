extends Control
const S = preload("res://ui/contextual/skin.gd")
const TV = preload("res://ui/contextual/training_visuels.gd")
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
	# Colonne de largeur fixe : sans elle, le panneau se réduisait à sa largeur minimale et le texte s'écrivait lettre par lettre.
	facts.get_parent().custom_minimum_size.x = TV.LARGEUR_COLONNE
	facts.get_parent().size_flags_horizontal = Control.SIZE_FILL
	var scroll := S.G.scroll(facts)
	S.G.fill(scroll.get_parent(), true)
	var training: Dictionary = model.get("decisions", {}).get("training", {})
	var support: Dictionary = model.get("clubLife", {}).get("clubSupport", {})
	var plan_data: Dictionary = support.get("training", {})
	var session: Dictionary = plan_data.get("session", {})
	# Avis du préparateur : une pastille d'état (moteur : adviceState), la phrase complète en infobulle ; clic -> Effectif & 23.
	if trained:
		scroll.add_child(S.wrap(str(session.get("reason")) if session.get("reason") != null else "Séance effectuée. Aucun compte rendu détaillé n’est enregistré pour cette séance.", 17, S.TEXT))
	else: scroll.add_child(TV.pastille_avis(training, func():
		director.close_training()
		app._navigate("Effectif")))
	scroll.add_child(S.label("Le groupe", 19, S.GOLD))
	TV.colonne_groupe(self, scroll, model.get("squad", []))
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
		var current_mode: String = {"repos":"Récupération", "normal":"Charge normale", "intense":"Intensive"}.get(str(model.get("meta", {}).get("training", "normal")), str(model.get("meta", {}).get("training", "normal")))
		var mode := str(model.get("meta", {}).get("training", "normal"))
		var seance := TV.pastille({"repos": "renew", "intense": "train"}.get(mode, "check"), current_mode, TV.couleur_mode(mode), 17)
		seance.name = "TrainingCurrentMode"
		list.add_child(seance)
		list.add_child(S.button("MAINTENIR LES RÉGLAGES", func(): maintained = true; _draw()))
		if maintained: list.add_child(S.label("Réglages conservés. La séance reste à effectuer.", 12, S.GOLD))
		list.add_child(S.label("Plans du staff", 16, S.GOLD))
		for plan: Dictionary in plan_data.get("plans", []):
			var appliquer := func(): director.command("training_plan", {"context":support.get("context"), "plan":plan.get("key")})
			list.add_child(TV.tuile_plan(plan, appliquer, plan_data.get("available", false)))
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

## Condition et charge s'affichent en entiers (le moteur renvoie des décimales longues).
static func _entier(valeur: Variant) -> String:
	return str(roundi(float(valeur))) if valeur is int or valeur is float else str(valeur)
