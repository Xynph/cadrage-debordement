extends SceneTree
## Texte et image du match 3D en temps forts : le journal ouvert, le bandeau du haut et la ligne météo
## ne disent un fait qu'au début de sa lecture 3D, jamais quand le moteur le calcule ou que la régie le
## met en file. Fixture de temps fort (forme de native/engine/match-direct.cjs), régie hors arbre :
## essai pas encore aplati, transformation et tir au but avant la frappe, pistes avant leur jalon,
## mi-temps atteinte par le moteur pendant la dernière action.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func textes(live: Dictionary) -> Array:
	return (live.get("events", []) as Array).map(func(e: Variant) -> String: return str(e.get("text", "")) if e is Dictionary else str(e))

## Régie posée sur le plan `k` du temps fort, dans la phase donnée.
func poser(regie: Node, k: int, phase: String, temps: float, essai_montre: bool = true, jalon_montre: bool = false) -> void:
	regie.etat = Regie.JEU
	regie.index = k
	regie.phase = phase
	regie.temps = temps
	regie._essai_montre = essai_montre
	regie._jalon_montre = jalon_montre

func run() -> void:
	var equipes := [{"name": "Domicile XV", "abbr": "DOM"}, {"name": "Visiteurs XV", "abbr": "VIS"}]
	var events := [
		{"min": 10, "text": "Coup d'envoi."},
		{"min": 11, "text": "Course de Martin."},
		{"min": 12, "text": "Essai de Bernard, transformé par Petit : 7-0."},
		{"min": 14, "text": "Pénalité réussie par Petit : 10-0."},
	]
	var scene := {"possession": 0, "ball": {"x": 85.0, "y": 30.0}, "players": []}
	var plans := [
		{"index": 1, "kind": "carry", "texte": "Course de Martin.", "scene": scene},
		{"index": 2, "kind": "try", "texte": "Essai de Bernard.", "mouvement": 2.4, "duree": 3.4, "scene": scene},
		{"index": 2, "kind": "transformation", "annonce": "Transformation.", "texte": "Transformation réussie.", "scene": scene},
		{"index": 3, "kind": "goal", "annonce": "Tir au but.", "texte": "Pénalité réussie par Petit : 10-0.", "scene": scene},
	]
	var live := {"teams": equipes, "events": events, "minute": 14, "score": [10, 0]}
	var regie: Node = Regie.new()
	regie.tf = {"plans": plans}
	regie._events = events
	regie._teams = equipes
	regie._vus = 1

	# Course : son fait est au journal dès le début du plan.
	poser(regie, 0, "jeu", 0.0)
	check(textes(regie.montre(live)) == ["Coup d'envoi.", "Course de Martin."], "Course : le journal dit le plan en cours, rien après (" + str(textes(regie.montre(live))) + ")")

	# Essai joué mais pas encore aplati : ni la légende ni le journal ne l'annoncent.
	poser(regie, 1, "jeu", 1.0, false)
	var avant := textes(regie.montre(live))
	check(avant == ["Coup d'envoi.", "Course de Martin."], "Essai pas encore aplati : absent du journal (" + str(avant) + ")")
	check(not Regie.fait_a_l_ecran(plans[1], "jeu", 1.0, false, false), "Essai pas encore aplati : pas à l'écran")

	# Essai aplati : il entre au journal, sans sa transformation ni le score.
	poser(regie, 1, "jeu", 2.5, true)
	var aplati := textes(regie.montre(live))
	check(aplati.size() == 3 and aplati[2] == "Essai de Bernard.", "Essai aplati : au journal sans la transformation (" + str(aplati) + ")")
	check(str(events[2].text).contains("transformé"), "Le journal du moteur n'est pas modifié")

	# Transformation : pose « prêt » puis frappe ; le résultat n'entre qu'après RESULTAT.
	poser(regie, 2, "pret", 0.5)
	check(textes(regie.montre(live)) == ["Coup d'envoi.", "Course de Martin.", "Essai de Bernard."], "Transformation, pose prêt : l'essai reste au journal, sans le résultat")
	poser(regie, 2, "jeu", Regie.RESULTAT - 0.1)
	check(textes(regie.montre(live))[2] == "Essai de Bernard.", "Transformation avant le résultat : rien du tir au journal")
	poser(regie, 2, "jeu", Regie.RESULTAT + 0.1)
	check(textes(regie.montre(live))[2] == "Essai de Bernard, transformé par Petit : 7-0.", "Transformation vue : le journal donne le texte entier")

	# Tir au but : rien du résultat pendant la pose ni avant la frappe.
	poser(regie, 3, "pret", 0.0)
	check(textes(regie.montre(live)).size() == 3, "Tir au but, pose prêt : résultat absent du journal")
	poser(regie, 3, "jeu", 0.4)
	check(textes(regie.montre(live)).size() == 3, "Tir au but avant la frappe : résultat absent du journal")
	poser(regie, 3, "jeu", Regie.RESULTAT)
	check(textes(regie.montre(live)).size() == 4, "Tir au but vu : résultat au journal")

	# Pistes du chorégraphe : le fait attend son jalon.
	poser(regie, 0, "choregraphie", 0.0, true, false)
	check(textes(regie.montre(live)).size() == 1, "Pistes avant le jalon : le fait n'est pas au journal")
	poser(regie, 0, "choregraphie", 0.0, true, true)
	check(textes(regie.montre(live)).size() == 2, "Pistes au jalon : le fait entre au journal")

	# Faits déjà connus du joueur avant le temps fort : jamais retirés.
	regie._vus = 4
	poser(regie, 1, "jeu", 0.5, false)
	check(textes(regie.montre(live)).size() == 4, "Faits déjà connus : le journal les garde")
	regie._vus = 1

	# Outils de coupe.
	check(Regie.sans_transformation("Essai de Bernard, transformé par Petit : 7-0.") == "Essai de Bernard.", "Coupe de l'essai à la transformation")
	check(Regie.sans_transformation("Essai de pénalité.") == "Essai.", "Essai sans transformation dans le texte : « Essai. » (comme le moteur)")

	# Mi-temps atteinte par le moteur pendant la dernière action : bandeau du haut et ligne météo
	# disent l'action montrée, « Mi-temps » attend la fin du temps fort.
	var etat := Regie.etat_du_plan(plans[0], equipes)
	check(etat.contains("a le ballon dans les 22 mètres adverses") and not etat.contains("Mi-temps"), "Bandeau du haut pendant l'action : possession montrée (" + etat + ")")
	check(Regie.etat_du_plan({"kind": "carry"}, equipes) == "Le match", "Plan sans scène : bandeau neutre")
	var pause := {"teams": equipes, "atBreak": true, "period": 1, "meteo": {"libelle": "grand vent", "ventDos": [0, 1]}}
	check(Meteo.bandeau(pause).begins_with("Mi-temps"), "Le moteur est à la mi-temps (fixture)")
	var pendant := Meteo.bandeau(Regie.meteo_montree(pause, true))
	check(not pendant.begins_with("Mi-temps") and pendant.contains("1re période"), "Ligne météo pendant la dernière action : pas encore la mi-temps (" + pendant + ")")
	check(Meteo.bandeau(Regie.meteo_montree(pause, false)).begins_with("Mi-temps"), "Ligne météo après l'action : la mi-temps")
	check(bool(pause.atBreak), "Le modèle du moteur n'est pas modifié")

	regie.free()
	print("MATCH_TEXTE_IMAGE %d controles, %d echec" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
