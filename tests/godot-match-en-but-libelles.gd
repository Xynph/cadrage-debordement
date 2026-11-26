extends SceneTree
## Libellés d'un fait d'en-but sur de VRAIS faits du moteur (godot-match-en-but-libelles.cjs, faits.json) : la ligne d'état
## du terrain 2D (Between.etat_du_deroule), celle de la 3D (Regie.etat_du_plan) et le bandeau de la liaison
## (Liaison.libelle_arret) nomment l'équipe qui attaque (scene.team du fait) pour l'en-avant, le porteur tenu et le
## coup de pied aplati.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Liaison = preload("res://match_liaison.gd")
const MOTS := {"ingoal-knock-on": "En-avant", "held-up": "tenu", "attacking-kick-grounded": "aplati"}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func run() -> void:
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_EN_BUT_FAITS")))
	check(lu is Array and (lu as Array).size() >= 4, "faits d'en-but du moteur lus")
	for f: Dictionary in lu:
		var equipes: Array = f.equipes
		var camp := int(f.fait.team)
		var club := Between.etat_du_fait("try", camp, NAN, equipes).trim_prefix("Essai — ")
		var cause := str(f.fait.cause)
		var etiquette := "%s %s (%s)" % [f.source, cause, f.texte]
		var etat := ""
		if f.source == "plan": etat = Regie.etat_du_plan(f.plan, equipes)
		else: etat = Between.etat_du_deroule(f.item, equipes)
		check(not club.is_empty() and etat.contains(club), "ligne d'état sans l'équipe %s : « %s » pour %s" % [club, etat, etiquette])
		check(etat != "%s a le ballon" % club and not etat.contains("a le ballon"), "ligne d'état = possession, pas le fait : « %s » pour %s" % [etat, etiquette])
		check(etat.to_lower().contains(str(MOTS[cause]).to_lower()), "ligne d'état sans le fait (%s) : « %s »" % [cause, etat])
		var arret := Liaison.libelle_arret({"kind": "ingoal", "cause": cause, "equipe": camp})
		check(int(arret.equipe) == camp, "bandeau de liaison sans l'équipe %d : %s pour %s" % [camp, str(arret), etiquette])
		check(str(arret.libelle) != "Ballon mort", "bandeau de liaison « Ballon mort » pour %s" % etiquette)
		print("EN_BUT ", f.source, " ", cause, " -> ", etat, " | ", str(arret.libelle), " / equipe ", arret.equipe)
	if failures.is_empty(): print("EN_BUT_LIBELLES %d controles, 0 echec" % checks)
	else: print("EN_BUT_LIBELLES %d controles, %d echec" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
