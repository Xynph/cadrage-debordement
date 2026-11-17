extends RefCounted
## Météo et vent du match, en mots de manager : écran Match avant le coup d'envoi (météo annoncée la
## veille, `next.meteo`), bandeau du direct (3D et entracte 2D), vestiaire d'avant-match et de mi-temps. Lit `live.meteo` (native/engine/model.cjs) : libellé, conseil du
## staff, et `ventDos` = [camp qui a le vent dans le dos en 1re période, en 2e période], null sinon.

const G = preload("res://ui/carnet_skin.gd")

static func meteo(live: Dictionary) -> Dictionary:
	return live.get("meteo", {}) if live.get("meteo") is Dictionary else {}

static func libelle(live: Dictionary) -> String:
	var texte := str(meteo(live).get("libelle", live.get("weather", ""))).strip_edges()
	return texte.substr(0, 1).to_upper() + texte.substr(1) if not texte.is_empty() else ""

## Camp (0 ou 1) qui a le vent dans le dos à la période donnée (1 ou 2), -1 sans vent orienté.
static func camp_vent(live: Dictionary, periode: int) -> int:
	var sens: Variant = meteo(live).get("ventDos")
	if not sens is Array or sens.size() != 2: return -1
	return int(sens[clampi(periode, 1, 2) - 1])

static func nom_camp(live: Dictionary, camp: int) -> String:
	var equipes: Array = live.get("teams", [])
	if camp < 0 or camp >= equipes.size() or not equipes[camp] is Dictionary: return "l’un des deux camps"
	return G.club_name(equipes[camp])

## Bandeau : « Grand vent · dans le dos de Toulon en 1re période » ; à la mi-temps, le changement de camp.
static func bandeau(live: Dictionary) -> String:
	if live.get("finished", false): return ""
	var titre := libelle(live)
	if titre.is_empty(): return ""
	if live.get("atBreak", false):
		var camp := camp_vent(live, 2)
		return "Mi-temps · changement de camp : le vent passe dans le dos de %s" % nom_camp(live, camp) if camp >= 0 else titre
	var periode := int(live.get("period", 1))
	var dos := camp_vent(live, periode)
	if dos < 0: return titre
	return "%s · dans le dos de %s en %s période" % [titre, nom_camp(live, dos), "1re" if periode == 1 else "2e"]

## Vestiaire : la phrase du vent pour la causerie d'avant-match (« pre ») ou de mi-temps (« half »).
static func phrase_vent(live: Dictionary, phase: String) -> String:
	var premiere := camp_vent(live, 1)
	if premiere < 0: return ""
	if phase == "half": return "On change de camp : le vent sera dans le dos de %s en seconde période." % nom_camp(live, camp_vent(live, 2))
	return "Le vent souffle dans le dos de %s en première période ; il changera de camp à la mi-temps." % nom_camp(live, premiere)

static func conseil(live: Dictionary) -> String:
	var texte: Variant = meteo(live).get("conseil")
	return str(texte) if texte is String else ""

## Prochain match vu comme un direct ({meteo, teams}) : mêmes textes avant le coup d'envoi, à partir de
## `next.meteo` (même format que `live.meteo`, présent dès la veille) ; vide sans météo annoncée.
static func annonce(next: Dictionary) -> Dictionary:
	if not next.get("meteo") is Dictionary: return {}
	return {"meteo": next.meteo, "teams": [next.get("home", {}), next.get("away", {})]}

## Bloc « La météo » de l'écran Match avant le coup d'envoi : [titre, ciel, vent, conseil] (lignes vides omises
## par l'écran). Sans annonce : quand elle tombera.
static func avant_match(next: Dictionary, aujourd_hui: String) -> Dictionary:
	var live := annonce(next)
	if live.is_empty():
		return {"titre": "LA MÉTÉO", "ciel": "", "vent": "", "conseil": "Bulletin météo la veille du match."}
	var jour := str(next.meteo.get("date", ""))
	return {"titre": "LA MÉTÉO DU MATCH" if jour == aujourd_hui or jour.is_empty() else "LA MÉTÉO DE DEMAIN",
		"ciel": libelle(live), "vent": phrase_vent(live, "pre"), "conseil": conseil(live)}
