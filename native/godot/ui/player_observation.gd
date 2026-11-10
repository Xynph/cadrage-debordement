extends RefCounted
## L'API du moteur fournit frais, disponibilité et contexte ; seule la confirmation écrit.
const G = preload("res://ui/game_skin.gd")
const K = preload("res://ui/player_knowledge_text.gd")

static func player_id(person: Dictionary) -> String:
	return str(person.get("playerId",person.get("id","")))

static func caption(person: Dictionary) -> String:
	var scouting: Dictionary = person.get("scouting",{})
	if scouting.get("pending",false): return "Observation en cours"
	return "Approfondir" if person.get("knowledge",{}).get("stage","") == "observed" else "Observer"

static func delay(scouting: Dictionary) -> String:
	return G.n(scouting.get("workCycles",0)) + (" semaines de travail du recruteur" if scouting.get("workUnit")=="week" else " cycles de travail du recruteur")

static func reason(app: Control,person: Dictionary) -> String:
	if not person.get("scouting") is Dictionary: return ""
	var scouting: Dictionary = person.scouting
	if K.owned(person): return "Joueur de votre club"
	if app.waiting: return "Une décision est en cours"
	if not app._live().is_empty(): return "Indisponible pendant le match"
	if scouting.get("pending",false): return "Observation en cours" + (" · %s semaine(s) restante(s)" % G.n(scouting.job.remainingWeeks) if scouting.get("job") is Dictionary and scouting.job.get("remainingWeeks") != null else "")
	if not scouting.get("available",false): return str(scouting.reason) if not str(scouting.get("reason","")).is_empty() else "Observation indisponible"
	if player_id(person).is_empty() or not scouting.get("context") is Dictionary: return "Contexte d’observation indisponible"
	return ""

static func configure(button: Button,app: Control,person: Dictionary) -> void:
	button.name = "ObservePlayer_"+player_id(person).replace(":","_")
	button.set_meta("observation_player_id",player_id(person))
	button.text = caption(person)
	button.visible = person.get("scouting") is Dictionary and not K.owned(person)
	var refusal := reason(app,person)
	button.disabled = not refusal.is_empty() or not button.visible
	var scouting: Dictionary = person.get("scouting",{})
	button.tooltip_text = refusal if not refusal.is_empty() else "%s · %s" % [G.euros(scouting.get("cost",0)),delay(scouting)]
	button.pressed.connect(func(): request(app,person))

static func request(app: Control,person: Dictionary) -> void:
	if not person.get("scouting") is Dictionary or K.owned(person) or not reason(app,person).is_empty(): return
	var scouting: Dictionary = person.scouting
	var context: Variant = scouting.get("context")
	if not context is Dictionary: return
	app.confirm("Observer "+str(person.get("name","ce joueur")),"Frais : %s. Délai : %s. Le rapport sera disponible à la fin de la mission." % [G.euros(scouting.get("cost",0)),delay(scouting)],func():
		app._command("observe_player",{"playerId":player_id(person),"confirmed":true,"context":context.duplicate(true)}))
