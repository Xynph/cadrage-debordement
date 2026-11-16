extends RefCounted
## « Premiers pas » : pendant la pré-saison d'une carrière Monde, Gabi propose quelques objectifs concrets, un à la
## fois, chacun avec un bouton qui mène au bon écran. Chaque objectif se coche quand le joueur a réellement agi :
##  - « conseil » : il a ouvert le Club (objectifs de la saison) ;
##  - « stage » : le stage de préparation est arrêté (par lui, ou confié à Gabi) — lu dans le modèle ;
##  - « composition » : une vraie commande de composition a été acceptée (set_lineup, auto_lineup) ;
##  - « recrutement » : il a ouvert le Recrutement.
## Rien de nouveau côté moteur ni carrière : la progression des écrans visités vit dans le profil du guide
## (guide.json, hors carrière, à côté des préférences), la même enveloppe que les autres souvenirs de Gabi.
## Une fois terminé (ou masqué), le profil s'en souvient : aucune répétition dans les carrières suivantes.

const Avis = preload("res://guide/gabi_avis.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")

const CLE := "premiers_pas"
const ORDRE := ["conseil", "stage", "composition", "recrutement"]
## Objectifs dont l'événement est observé dans l'interface (le stage se lit dans le modèle).
const VUS := ["conseil", "composition", "recrutement"]
const FINS := ["", "termine", "masque"]
const COMMANDES_COMPOSITION := ["set_lineup", "auto_lineup"]
const COMMANDES_NOUVELLE_CARRIERE := ["new_career", "import", "recover_profile", "restore_checkpoint"]

## Forme acceptée par le profil du guide (guide_profile.gd) : {fin, vus, club}.
static func valide(valeur: Variant) -> bool:
	if not valeur is Dictionary or (valeur as Dictionary).size() != 3: return false
	var fin: Variant = valeur.get("fin")
	var vus: Variant = valeur.get("vus")
	var club: Variant = valeur.get("club")
	if not fin is String or fin not in FINS or not club is String or club.length() > 64 or not vus is Array: return false
	if vus.size() > VUS.size(): return false
	var deja := {}
	for id: Variant in vus:
		if not id is String or id not in VUS or deja.has(id): return false
		deja[id] = true
	return true

static func etat(donnees: Dictionary) -> Dictionary:
	var brut: Variant = donnees.get(CLE)
	return (brut as Dictionary).duplicate(true) if valide(brut) else {"fin": "", "vus": [], "club": ""}

static func _club(model: Dictionary) -> String:
	return str(model.get("club", {}).get("id", "")) if model.get("club") is Dictionary else ""

## Carrière Monde, avant la 1re journée : aucun match joué, pas de direct, et pas le jour du match.
static func avant_premiere_journee(model: Dictionary) -> bool:
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	if not meta.get("hasCareer", false) or str(meta.get("mode", "")) != "world": return false
	if int(Semaine._nombre(meta.get("season"), 1)) != 1: return false
	if model.get("live") is Dictionary and not (model.live as Dictionary).is_empty(): return false
	var propre := _club(model)
	for fixture: Variant in model.get("calendar", []) if model.get("calendar") is Array else []:
		if not fixture is Dictionary or not fixture.get("played", false): continue
		if str(fixture.get("home", {}).get("id", "")) == propre or str(fixture.get("away", {}).get("id", "")) == propre: return false
	var prochain := Semaine.prochain_match(model)
	return prochain.is_empty() or Semaine.jours_avant(model, prochain) != 0

## La carte se montre : pas de fin enregistrée, Gabi présent (réglage), et avant la 1re journée.
static func visible(model: Dictionary, donnees: Dictionary) -> bool:
	return str(etat(donnees).fin).is_empty() and avant_premiere_journee(model)

static func _stage(model: Dictionary) -> Variant:
	var reprise: Variant = model.get("clubLife", {}).get("reprise") if model.get("clubLife") is Dictionary else null
	if not reprise is Dictionary or not reprise.get("decisions") is Array: return null
	for decision: Variant in reprise.decisions:
		if decision is Dictionary and decision.get("key") == "stage": return decision
	return null

static func _poste_faible(model: Dictionary) -> String:
	var data: Variant = model.get("decisions", {}).get("recruitment") if model.get("decisions") is Dictionary else null
	if not data is Dictionary or not data.get("needs") is Array: return ""
	for need: Variant in data.needs:
		if need is Dictionary and need.get("need", false): return str(need.get("pos", "")).to_lower()
	return ""

## Les objectifs du moment, dans l'ordre, chacun {cle, titre, texte, libelle, fait, action}.
## Le stage n'est proposé que si le moteur l'offre ; les autres le sont toujours.
static func objectifs(model: Dictionary, donnees: Dictionary) -> Array:
	var vus: Array = etat(donnees).vus
	var liste: Array = []
	for cle: String in ORDRE:
		var fait := cle in vus
		var objectif := {"cle": cle, "fait": fait}
		match cle:
			"conseil":
				objectif.titre = "Les attentes du conseil"
				objectif.texte = "Avant de toucher à quoi que ce soit, regarde ce que le conseil attend de toi cette saison. C'est au Club."
				objectif.libelle = "Voir les objectifs"
				objectif.action = {"type": "ecran", "route": "Club"}
			"stage":
				var decision: Variant = _stage(model)
				if decision == null: continue
				fait = decision.get("selected") != null
				objectif.fait = fait
				objectif.titre = "Le stage de préparation"
				objectif.texte = "Le stage, c'est toi qui l'orientes : foncier, cohésion ou tactique. Choisis, je te dirai ce que j'en pense."
				objectif.libelle = "Choisir le stage"
				objectif.action = {"type": "reprise"}
			"composition":
				objectif.titre = "Ton XV de départ"
				objectif.texte = "Compose ton XV. Un groupe qui connaît sa place prend ses marques plus vite."
				objectif.libelle = "Ouvrir la composition"
				objectif.action = {"type": "ecran", "route": "Composition"}
			"recrutement":
				var poste := _poste_faible(model)
				objectif.titre = "Un œil au recrutement"
				objectif.texte = ("Il y a un trou au poste de %s. Jette un œil au recrutement, sans signer dans la précipitation." % poste) if not poste.is_empty() else "Jette un œil au recrutement : mieux vaut repérer les postes faibles avant que la saison commence."
				objectif.libelle = "Voir le recrutement"
				objectif.action = {"type": "ecran", "route": "Recrutement"}
		liste.append(objectif)
	return liste

## Premier objectif non fait, ou {} si tout est fait.
static func courant(liste: Array) -> Dictionary:
	for objectif: Dictionary in liste:
		if not objectif.fait: return objectif
	return {}

static func faits(liste: Array) -> int:
	return liste.filter(func(objectif: Dictionary) -> bool: return objectif.fait).size()

## Observe un événement réel (écran ouvert, commande acceptée) et enregistre la progression dans le profil du
## guide. Aucune écriture de carrière. Renvoie true si le profil a changé.
static func observer(profile: Object, route: String, model: Dictionary, command: String, reponse_ok: bool) -> bool:
	if profile == null or not model.get("meta") is Dictionary or not model.meta.get("hasCareer", false): return false
	var donnees: Dictionary = profile.data
	var cur := etat(donnees)
	var club := _club(model)
	var change := false
	# Nouvelle carrière (ou autre club) : la progression des écrans visités repart de zéro.
	var nouvelle: bool = reponse_ok and command in COMMANDES_NOUVELLE_CARRIERE
	if nouvelle or str(cur.club) != club:
		if not (cur.vus as Array).is_empty() or str(cur.club) != club: change = true
		cur.vus = []
		cur.club = club
	if str(cur.fin).is_empty() and avant_premiere_journee(model) and not nouvelle:
		var evenements: Array = []
		if route == "Club": evenements.append("conseil")
		if route == "Recrutement": evenements.append("recrutement")
		if reponse_ok and command in COMMANDES_COMPOSITION: evenements.append("composition")
		for cle: String in evenements:
			if cle not in cur.vus: cur.vus.append(cle); change = true
		donnees = donnees.duplicate(true)
		donnees[CLE] = cur
		var liste := objectifs(model, donnees)
		if not liste.is_empty() and courant_vide(liste):
			cur.fin = "termine"; change = true
	if not change: return false
	profile.data[CLE] = cur
	return profile.save_profile(profile.data)

static func courant_vide(liste: Array) -> bool:
	return courant(liste).is_empty()

## « Masquer » : plus de carte, y compris dans les carrières suivantes.
static func masquer(profile: Object) -> bool:
	var cur := etat(profile.data)
	cur.fin = "masque"
	profile.data[CLE] = cur
	return profile.save_profile(profile.data)
