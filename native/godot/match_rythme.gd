extends RefCounted
## Rythme du direct d'origine (repli CD_MATCH_TEMPS_FORTS=0, ou projection des temps forts
## indisponible) : chaque fait montré reste à l'écran le temps d'être joué, selon son type, au
## lieu d'un pas fixe de 0,32 s. Présentation seulement : le moteur décide de tout.
##
## Le match en temps forts (mode de base) a ses propres durées de plan, côté moteur
## (native/engine/match-highlights.cjs, DUREES) ; celles-ci en reprennent l'ordre de grandeur.

## Secondes d'écran par type de fait, à la cadence ×1.
const DUREES := {
	"try": 3.0, "transformation": 2.5, "goal": 2.5, "miss": 2.5, "ingoal": 2.0,
	"kickoff": 2.0, "drop22": 2.0, "goalLine": 2.0,
	"scrum": 1.5, "lineout": 1.5, "setpiece-win": 1.5, "setpiece-loss": 1.5, "maul": 1.5,
	"penalty": 1.5, "card": 2.0, "kick": 1.5, "touch": 1.2, "reception": 1.2,
	"ruck": 1.0, "turnover": 1.0, "hand-fault": 1.2, "quick-tap": 1.0,
	"carry": 0.8, "pass": 0.8, "break": 2.0, "end": 2.0,
}
const DUREE_DEFAUT := 1.0
## Pas le plus court entre deux demandes au moteur (l'ancien pas fixe) : en cadence accélérée,
## plusieurs faits sont alors avancés d'un coup pour garder le multiplicateur.
const PAS_MIN := 0.32
## Intervalle de l'horloge qui surveille le rythme.
const SCRUTATION := 0.1
## Attente supplémentaire, au plus, pour que les joueurs proches du ballon finissent leur
## déplacement à l'écran (cadence ×1 seulement).
const ECHEANCE_PLACE := 1.5

static func duree(kind: String) -> float:
	return float(DUREES.get(kind, DUREE_DEFAUT))

## Prochaine demande au moteur après un fait `kind` montré, à la cadence `cadence` (1, 4, 12…) :
## {"secondes": attente à l'écran, "pas": faits à avancer}. Le débit vaut toujours `cadence`
## fois celui de la cadence ×1.
static func prochain(kind: String, cadence: int) -> Dictionary:
	var k := maxi(1, cadence)
	var attente := duree(kind) / float(k)
	var pas := 1
	if attente < PAS_MIN:
		pas = ceili(PAS_MIN / attente)
		attente = duree(kind) * float(pas) / float(k)
	return {"secondes": attente, "pas": pas}
