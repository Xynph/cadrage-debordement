extends SceneTree
## Écran entre deux temps forts (lot 5, 16/11/2026) : statistiques et lecture de Gabi sur un
## échantillon court. Projection `direct` de fixture (forme de native/engine/match-direct.cjs) :
## à la 2e minute, parts masquées, chiffres atténués, Gabi sans pourcentage ni ton alarmiste ;
## à la 12e minute, chiffres pleins et lecture de l'occupation. Bandeau du direct à l'échelle ;
## légende d'un essai retenue jusqu'à l'aplatissement.
const Between = preload("res://ui/contextual/match_between.gd")
const LiveView = preload("res://ui/contextual/live_view.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func rang(cle: String, valeurs: Array, vide: bool, court: bool, unite: String = "") -> Dictionary:
	return {"cle": cle, "label": cle, "valeurs": valeurs, "unite": unite, "vide": vide, "court": court}

func direct(minute: int, seuil: int = 10) -> Dictionary:
	var court := minute < seuil
	return {"version": 1, "camp": 1, "score": [0, 0], "possession": 0, "zone": {"x": 30.0},
		"echantillon": {"minutes": minute, "suffisant": not court, "seuil": seuil},
		"tableau": [rang("possession", [57, 43], court, court, "%"), rang("occupation", [70, 30], court, court, "%"),
			rang("metres", [23, 34], false, court), rang("plaquages", [3, 12], false, court)],
		"fil": [{"i": 0, "horloge": "%d′" % minute, "texte": "Coup d’envoi.", "kind": "kickoff", "equipe": 0}],
		"domination": {"minutes": [10, 20], "miTemps": null}, "reperes": [], "deroule": [], "borne": 1, "notes": {}, "cartons": []}

func texte_gabi(between: Control) -> String:
	var morceaux: PackedStringArray = []
	for label: Label in between.adjoint.find_children("*", "Label", true, false): morceaux.append(label.text)
	return " ".join(morceaux)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var between: Control = Between.new()
	between.size = Vector2(1920, 940)
	root.add_child(between)
	for i in 3: await process_frame
	var equipes := [{"name": "Domicile XV", "abbr": "DOM"}, {"name": "Visiteurs XV", "abbr": "VIS"}]
	var live := {"teams": equipes, "events": [{}], "lineup": [], "minute": 2}
	between.update_frame({}, live, direct(2), func(_c: Variant): pass)
	for i in 2: await process_frame
	check(between.echantillon_court, "2e minute : échantillon court")
	check(is_equal_approx(between.chiffres.modulate.a, Between.ATTENUE), "2e minute : chiffres atténués")
	check(between.precision_chiffres.text.contains("trop tôt") and between.precision_chiffres.text.contains("10′"), "2e minute : le titre dit quand conclure (" + between.precision_chiffres.text + ")")
	var possession: Label = between.chiffres.get_child(0).get_child(1)
	check(possession.text == "—", "2e minute : possession masquée (" + possession.text + ")")
	var gabi := texte_gabi(between)
	check(not gabi.contains("%") and not gabi.contains("trop") and gabi.contains("se met en place"), "2e minute : Gabi posé, sans pourcentage (" + gabi + ")")
	# 12e minute : chiffres pleins, Gabi lit l'occupation (30 % pour son camp, écart net).
	live.minute = 12
	between.update_frame({}, live, direct(12), func(_c: Variant): pass)
	for i in 2: await process_frame
	check(not between.echantillon_court and between.chiffres.modulate.a == 1.0, "12e minute : chiffres pleins")
	check(between.precision_chiffres.text == "comparées", "12e minute : titre ordinaire")
	possession = between.chiffres.get_child(0).get_child(1)
	check(possession.text == "57%", "12e minute : possession affichée (" + possession.text + ")")
	gabi = texte_gabi(between)
	check(gabi.contains("30 %") and gabi.contains("dégagement") and not gabi.contains("trop dans notre camp"), "12e minute : lecture de l'occupation, sans alarme (" + gabi + ")")
	# Projection d'avant le lot 5 (sans `echantillon`) : rien n'est atténué.
	var ancien := direct(12)
	ancien.erase("echantillon")
	check(not Between.est_court(ancien), "Ancienne projection : échantillon jugé suffisant")
	# Bandeau et légende du direct : 1 jusqu'en 1080p, ×1,33 en 1440p.
	check(LiveView.echelle_pour(720.0) == 1.0 and LiveView.echelle_pour(1080.0) == 1.0, "Bandeau : jamais réduit sous 1080p")
	check(is_equal_approx(LiveView.echelle_pour(1440.0), 1440.0 / 1080.0), "Bandeau : agrandi en 1440p")
	check(roundi(LiveView.BANDEAU_TAILLES.legende * LiveView.echelle_pour(1080.0)) >= 22, "Légende du temps fort lisible en 1080p")
	check(Between.muette("Les indicateurs ne justifient pas de changement offensif prioritaire.") and not Between.muette("Occupation de 30 % : rechercher du terrain au pied."), "Conseil sans proposition : Gabi lit le match montré")
	# Essai : rien n'est écrit ni acclamé avant que le ballon soit aplati (fin du mouvement du plan).
	var essai := {"kind": "try", "mouvement": 2.4, "duree": 3.4}
	check(Regie.essai_en_cours(essai, 0.0) and Regie.essai_en_cours(essai, 2.3), "Essai : légende tue pendant la course")
	check(not Regie.essai_en_cours(essai, 2.4), "Essai : légende à l'aplatissement")
	check(not Regie.essai_en_cours({"kind": "try", "mouvement": 0.0}, 0.0), "Essai sans mouvement : légende tout de suite")
	check(not Regie.essai_en_cours({"kind": "carry", "mouvement": 2.0}, 0.5), "Course : légende inchangée")
	print("MATCH_ECHANTILLON %d controles, %d echec" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
