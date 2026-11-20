extends RefCounted
## « Déléguer le match » avant le coup d'envoi : règles de la sous-page (immersive08/avant_match_pages.gd), qui a remplacé
## l'ancienne fenêtre de confirmation. Une case « Confier aussi la composition au staff », cochée par défaut, décochable :
## cochée, le staff refait la feuille du jour avec la sélection automatique (comme le bouton « Sélection du staff »,
## règle JIFF comprise) avant le match ; décochée, la feuille du joueur est jouée telle quelle. Le choix est mémorisé
## dans la carrière (decisions.delegation.matchLineup) et proposé tel quel la fois suivante.
## Feuille incomplète (pilier de remplacement manquant...) : la page propose « Appeler un espoir : nom, âge, poste,
## note » (choix par défaut : le meilleur jeune du centre apte au poste, prêté pour ce match) ou « Jouer à 22 » quand la
## règle le permet (Nationale) : begin_match { espoirs } ou { reducedBench }.
## Commandes : begin_match { delegated: true, composition } puis delegate (chaînées par app.queued_action).
const Avis = preload("res://guide/gabi_avis.gd")

## Valeur mémorisée du choix (cochée tant que le joueur n'a rien décidé, y compris sur une ancienne sauvegarde).
static func composition_confiee(model: Dictionary) -> bool:
	var delegation: Variant = model.get("decisions", {}).get("delegation") if model.get("decisions") is Dictionary else null
	return not (delegation is Dictionary and delegation.get("matchLineup", true) == false)

## Phrase sous la case, selon qu'elle est cochée ou non.
static func detail_texte(model: Dictionary, composition: bool) -> String:
	var fatigue := Avis.fatigue_donnees(model)
	var fatigues := int(fatigue.get("count", 0)) if not fatigue.is_empty() else 0
	if composition:
		return "Le staff refait la feuille avant le coup d'envoi : les joueurs fatigués se reposent, les mieux placés jouent. Tu peux décocher pour garder ta feuille."
	return "Ta feuille est jouée telle quelle%s. Sans rotation, le groupe s'épuise de semaine en semaine." % (" : %d titulaire%s sous 70 %% de condition" % [fatigues, "s" if fatigues > 1 else ""] if fatigues > 0 else "")

## Le coup d'envoi puis la délégation du match : la seconde commande part dès la réponse de la première.
static func valider(app: Control, payload: Dictionary) -> void:
	if app.waiting or not app._live().is_empty() or not app.model.get("next") is Dictionary: return
	app.management_ui["avant_page"] = ""
	if app._command("begin_match", payload):
		app.queued_action = {"command": "delegate", "payload": {}, "target_route": ""}