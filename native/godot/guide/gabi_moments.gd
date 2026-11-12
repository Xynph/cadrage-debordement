extends RefCounted
## Cohérence entre ce que dit Gabi et ce qu'il fait (demande de Léo, 11 novembre 2026).
## Chaque bulle est rangée dans une catégorie de moment ; chaque catégorie a ses gestes et son ton.
## Le hasard ne choisit qu'entre gestes équivalents d'une même catégorie (sans répéter le précédent).
## Table documentée dans docs/gabi-mixamo-20261111.md (« Gestes cohérents avec le moment »).
##
## Tons : « positif » (sourire possible, sourire des yeux marqué), « neutre » (sourire léger
## possible), « negatif » (ni sourire, ni bâillement, ni tablette ; regard plus bas).

const POSITIF := "positif"
const NEUTRE := "neutre"
const NEGATIF := "negatif"

## Catégorie → gestes du Gabi Mixamo, geste du Gabi d'origine, ton.
## Gestes jamais joués : bras_croises (jugé raté), assis_* / debout_assis / assis_debout (aucune
## chaise dans le portrait), marche, tourne_g, tourne_d, telephone, telephone_marche (il sortirait du
## cadre ou téléphonerait pendant qu'il parle au coach), rit (le personnage sourit plutôt que de rire),
## surpris, remercie (aucun moment du jeu ne les appelle encore).
const CATEGORIES := {
	"accueil": {"mixamo": [&"salut"], "origine": [&"Salut"], "ton": POSITIF},
	"consigne": {"mixamo": [&"explique", &"montre", &"insiste", &"argumente"], "origine": [&"Explication"], "ton": NEUTRE},
	"mise_en_garde": {"mixamo": [&"insiste", &"refuse", &"argumente"], "origine": [&"Explication"], "ton": NEUTRE},
	"question": {"mixamo": [&"sceptique", &"hausse"], "origine": [&"Ecoute"], "ton": NEUTRE},
	"approbation": {"mixamo": [&"approuve", &"approuve_fort", &"pouce"], "origine": [&"Approbation"], "ton": POSITIF},
	"bonne_nouvelle": {"mixamo": [&"content", &"approuve_fort", &"pouce", &"applaudit"], "origine": [&"Approbation"], "ton": POSITIF},
	"mauvaise_nouvelle": {"mixamo": [&"decu", &"reflechit", &"regarde_bas"], "origine": [&"RegardCarnet"], "ton": NEGATIF},
	"souvenir": {"mixamo": [&"reflechit", &"hausse"], "origine": [&"Ecoute"], "ton": NEUTRE},
	"regret": {"mixamo": [&"reflechit", &"regarde_bas"], "origine": [&"RegardCarnet"], "ton": NEGATIF},
}

## Attente (le coach lit ou choisit) : petits gestes selon le ton. « rares » : au plus un sur six,
## jamais pendant une mauvaise nouvelle.
const ATTENTE := {
	"mixamo": [&"repos_respire", &"appui", &"regarde_bas", &"reflechit"],
	"mixamo_rares": [&"tablette", &"baille"],
	"mixamo_negatif": [&"repos_respire", &"appui", &"regarde_bas", &"reflechit"],
	"origine": [&"Ecoute", &"RegardCarnet"],
}

## Gestes pendant lesquels Gabi regarde son carnet (ou la tablette) : le regard suit.
const REGARD_CARNET := [&"regarde_bas", &"tablette", &"decu", &"RegardCarnet"]
## Gestes de réflexion : le regard part sur le côté, un peu en haut.
const REGARD_PENSIF := [&"reflechit", &"sceptique", &"Ecoute"]

## Bulle → catégorie. Les identifiants de dialogues.json sont stables (voix enregistrée).
const BULLES := {
	"bienvenue-caractere": "accueil", "bienvenue-01": "souvenir", "bienvenue-02": "approbation",
	"club-caractere": "consigne", "club-01": "consigne", "club-02": "question",
	"bureau-caractere": "consigne", "bureau-01": "consigne", "bureau-02": "souvenir",
	"decision-saison": "consigne",
	"effectif-caractere": "mise_en_garde", "effectif-01": "consigne", "effectif-02": "consigne",
	"composition-caractere": "approbation", "composition-01": "mise_en_garde", "composition-02": "consigne",
	"entrainement-caractere": "mise_en_garde", "entrainement-01": "consigne", "entrainement-02": "question", "entrainement-03": "consigne",
	"tactique-caractere": "consigne", "tactique-01": "consigne", "tactique-02": "souvenir",
	"premier-match-caractere": "approbation", "premier-match-01": "approbation", "premier-match-02": "consigne",
	"resultat-caractere": "resultat", "resultat-01": "consigne", "resultat-02": "consigne",
	"calendrier-caractere": "consigne", "calendrier-01": "consigne", "calendrier-02": "regret",
	"classements-caractere": "consigne", "classements-01": "consigne", "classements-02": "mise_en_garde", "classements-03": "approbation",
	"finances-caractere": "mise_en_garde", "finances-01": "souvenir", "finances-02": "consigne", "finances-03": "mise_en_garde",
	"decision-tresorerie": "mauvaise_nouvelle",
	"packs-caractere": "consigne", "packs-01": "consigne", "packs-02": "souvenir",
	"recrutement-caractere": "consigne", "recrutement-01": "question", "recrutement-02": "mise_en_garde",
	"decision-contrat": "bonne_nouvelle",
	"territoire-caractere": "consigne", "territoire-01": "consigne", "territoire-02": "souvenir",
	"staff-caractere": "consigne", "staff-01": "mise_en_garde", "staff-02": "souvenir",
	"formation-caractere": "mise_en_garde", "formation-01": "regret", "formation-02": "consigne", "formation-03": "mise_en_garde",
	"plan-jeu-caractere": "consigne", "plan-jeu-01": "question",
	"vestiaire-caractere": "consigne", "vestiaire-01": "mise_en_garde",
	"centre-caractere": "consigne", "centre-01": "question",
	"presse-caractere": "mise_en_garde", "presse-01": "mise_en_garde",
	"rivalites-caractere": "consigne", "rivalites-01": "consigne",
	"travail-club-caractere": "consigne", "travail-club-01": "consigne",
	"strategie-caractere": "souvenir", "strategie-01": "consigne",
	"carriere-caractere": "question", "carriere-01": "consigne",
}

## Écran sans bulle connue (ancien appel set_context) : catégorie par défaut de la page.
const PAGES := {"composition": "approbation", "premier-match": "approbation", "resultat": "resultat", "bienvenue": "accueil"}


## Moment d'une bulle : {id, categorie, ton}. Le résultat du dernier match (s'il est terminé et
## lisible dans le modèle) donne victoire, défaite ou nul sur la page « resultat » ; il colore aussi
## le ton des autres bulles de cette page.
static func moment(page: String, fragment_id: String, model: Dictionary = {}) -> Dictionary:
	var category: String = BULLES.get(fragment_id, "")
	if category.is_empty():
		category = PAGES.get(page, "consigne")
	var tone: String = CATEGORIES.get(category, {}).get("ton", NEUTRE)
	if page == "resultat" or category == "resultat":
		var outcome := match_outcome(model)
		if category == "resultat":
			category = {"victoire": "bonne_nouvelle", "defaite": "mauvaise_nouvelle", "nul": "souvenir"}.get(outcome, "consigne")
			tone = CATEGORIES[category].ton
		elif outcome == "defaite":
			tone = NEGATIF
		elif outcome == "victoire":
			tone = POSITIF
	var key := fragment_id if not fragment_id.is_empty() else "page:" + page
	return {"id": key, "categorie": category, "ton": tone}


## Issue du match en direct terminé, du point de vue du club du coach : victoire, defaite, nul ou "".
static func match_outcome(model: Dictionary) -> String:
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	var club: Dictionary = model.get("club", {}) if model.get("club") is Dictionary else {}
	if not live.get("finished", false) or not live.get("score") is Array or not live.get("pair") is Array: return ""
	var score: Array = live.score
	var pair: Array = live.pair
	if score.size() != 2 or pair.size() != 2 or not club.has("id"): return ""
	var side := -1
	for index in 2:
		if str(pair[index]) == str(club.id): side = index
	if side < 0 or not (score[0] is float or score[0] is int) or not (score[1] is float or score[1] is int): return ""
	var ours := float(score[side])
	var theirs := float(score[1 - side])
	return "victoire" if ours > theirs else ("defaite" if ours < theirs else "nul")


## Gestes d'une catégorie pour un profil de clips (« mixamo » ou « origine »).
static func gestures(category: String, profile: String) -> Array:
	return CATEGORIES.get(category, CATEGORIES.consigne).get(profile, [])
