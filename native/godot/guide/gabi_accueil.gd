extends RefCounted
## Gabi guide les deux premières semaines d'une carrière Monde : au premier passage sur chaque écran clé
## (Réception, Effectif, Composition, Match, Finances, Formation), une bulle courte (deux phrases) avec une ou
## deux actions directes. Pendant ces 14 jours, ces bulles ne comptent pas dans la limite d'une intervention
## spontanée par jour. Le 15e jour, Gabi dit qu'il se met en retrait, puis il reprend son rythme normal.
## « Je connais déjà » (création) coupe tout cela pour la carrière.
## État dans le profil du guide (guide.json, hors carrière) : {club, debut, vus, connu}. Aucune écriture de carrière.

const Semaine = preload("res://guide/gabi_semaine.gd")

const CLE := "accueil"
const DUREE_JOURS := 14
const FIN := "fin"
const COMMANDES_NOUVELLE_CARRIERE := ["new_career"]

## Écrans clés : titre, texte (deux phrases, au tutoiement) et actions {libelle, type, ...} (suivre_conseil).
const ECRANS := {
	"Réception": {
		"titre": "LE COURRIER",
		"texte": "Tout arrive ici : staff, joueurs, président. Lis, réponds si on te le demande, puis Continuer fait avancer les jours.",
		"actions": [{"libelle": "Ouvrir le mail suivant", "type": "courrier"}],
	},
	"Effectif": {
		"titre": "TON GROUPE",
		"texte": "Regarde d'abord la condition et les blessés : un joueur à plat, c'est un match à l'envers. Clique sur un nom pour sa fiche.",
		"actions": [{"libelle": "Préparer le XV", "type": "ecran", "route": "Composition"}],
	},
	"Composition": {
		"titre": "LA FEUILLE",
		"texte": "Quinze titulaires, huit remplaçants, chacun à un poste qu'il sait tenir. Pressé ? Le staff te propose une feuille complète.",
		"actions": [{"libelle": "Le staff compose pour moi", "type": "commande", "command": "auto_lineup", "message": "Voilà une feuille propre. Change ce que tu veux : c'est toi qui signes."}],
	},
	"Match": {
		"titre": "LE MATCH",
		"texte": "Avant le coup d'envoi : météo, adversaire, ta feuille. Pendant le match, mets en pause pour changer un joueur ou le plan.",
		"actions": [{"libelle": "Revoir la feuille", "type": "ecran", "route": "Composition"}],
	},
	"Finances": {
		"titre": "LES COMPTES",
		"texte": "Une seule règle : ne pas finir dans le rouge. Les salaires partent chaque semaine, les recettes arrivent surtout les soirs de match à domicile.",
		"actions": [{"libelle": "Les attentes du président", "type": "ecran", "route": "Club"}],
	},
	"Formation": {
		"titre": "LES JEUNES",
		"texte": "Ton centre de formation, c'est l'avenir pas cher. Un espoir progresse en jouant : donne-lui des minutes en préparation.",
		"actions": [{"libelle": "Voir le centre", "type": "ecran", "route": "Centre"}],
	},
}
const TEXTE_FIN := "Deux semaines que tu es là, tu connais la maison. Je me mets en retrait : clique sur ma tête quand tu veux mon avis."

static func valide(valeur: Variant) -> bool:
	if not valeur is Dictionary or (valeur as Dictionary).size() != 4: return false
	var club: Variant = valeur.get("club")
	var debut: Variant = valeur.get("debut")
	var vus: Variant = valeur.get("vus")
	if not club is String or club.length() > 64 or not debut is String or debut.length() > 10 or not valeur.get("connu") is bool: return false
	if not vus is Array or vus.size() > ECRANS.size() + 1: return false
	var deja := {}
	for id: Variant in vus:
		if not id is String or (id not in ECRANS and id != FIN) or deja.has(id): return false
		deja[id] = true
	return true

static func etat(donnees: Dictionary) -> Dictionary:
	var brut: Variant = donnees.get(CLE)
	return (brut as Dictionary).duplicate(true) if valide(brut) else {}

static func _club(model: Dictionary) -> String:
	return str(model.get("club", {}).get("id", "")) if model.get("club") is Dictionary else ""

static func _aujourdhui(model: Dictionary) -> String:
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	return str(meta.get("calendarToday", "")).substr(0, 10)

## Jours écoulés depuis la création (calendrier du jeu) ; -1 si inconnu.
static func jours(model: Dictionary, donnees: Dictionary) -> int:
	var a := Semaine._unix(str(etat(donnees).get("debut", "")))
	var b := Semaine._unix(_aujourdhui(model))
	if a < 0 or b < 0: return -1
	return roundi((b - a) / 86400.0)

static func _concerne(model: Dictionary, donnees: Dictionary) -> bool:
	var cur := etat(donnees)
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	return not cur.is_empty() and not bool(cur.connu) and meta.get("hasCareer", false) and str(meta.get("mode", "")) == "world" and str(cur.club) == _club(model)

## Les deux premières semaines sont en cours (et pas « je connais déjà »).
static func actif(model: Dictionary, donnees: Dictionary) -> bool:
	if not _concerne(model, donnees): return false
	var j := jours(model, donnees)
	return j >= 0 and j < DUREE_JOURS

## Ce que Gabi dit sur cet écran maintenant : {cle, titre, texte, actions} ou {}.
static func a_dire(route: String, model: Dictionary, donnees: Dictionary) -> Dictionary:
	if not _concerne(model, donnees): return {}
	var vus: Array = etat(donnees).vus
	var j := jours(model, donnees)
	if j >= DUREE_JOURS:
		# Une seule fois, sur un écran calme : Gabi se met en retrait.
		if FIN in vus or route not in ["Réception", "Bureau"]: return {}
		return {"cle": FIN, "titre": "GABI", "texte": TEXTE_FIN, "actions": []}
	if j < 0 or not ECRANS.has(route) or route in vus: return {}
	var ecran: Dictionary = ECRANS[route]
	return {"cle": route, "titre": "GABI · " + str(ecran.titre), "texte": str(ecran.texte), "actions": (ecran.actions as Array).duplicate(true)}

## Mémorise qu'un écran a été expliqué. Renvoie true si le profil a été écrit.
static func marquer(profile: Object, cle: String) -> bool:
	var cur := etat(profile.data)
	if cur.is_empty() or cle in cur.vus: return false
	cur.vus.append(cle)
	profile.data[CLE] = cur
	return profile.save_profile(profile.data)

## Nouvelle carrière acceptée : les deux semaines repartent du jour de la création.
static func observer(profile: Object, model: Dictionary, command: String, reponse_ok: bool, connu: bool) -> bool:
	if profile == null or not reponse_ok or command not in COMMANDES_NOUVELLE_CARRIERE: return false
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	if not meta.get("hasCareer", false): return false
	# main.gd rappelle ceci à chaque rendu tant que la dernière commande reste « new_career » : même club, même
	# jour de départ = déjà fait (seul « je connais déjà » peut changer).
	var cur := etat(profile.data)
	if not cur.is_empty() and str(cur.club) == _club(model) and str(cur.debut) == _aujourdhui(model):
		if bool(cur.connu) == connu: return false
		cur.connu = connu
		profile.data[CLE] = cur
		return profile.save_profile(profile.data)
	profile.data[CLE] = {"club": _club(model), "debut": _aujourdhui(model), "vus": [], "connu": connu}
	return profile.save_profile(profile.data)
