extends RefCounted
## Foule du stade (19/11/2026) : intensité d'ambiance continue et part de spectateurs debout, tirées
## de l'image montrée (scène du direct ou plan des temps forts), jamais du moteur. Présentation seule.
##
## Intensité (0 à 1) : rumeur au repos (CALME) ; elle enfle quand l'équipe en possession entre dans
## les 22 mètres adverses (ENTREE_22) et jusqu'à LIGNE près de l'en-but ; elle explose à l'essai
## (ESSAI, tenue TENUE_ESSAI secondes) puis retombe lentement (DESCENTE).
## Debout : part de chaque tribu (domicile, extérieur, neutres) levée ; la vue lève les spectateurs
## dans l'ordre de leur rang (match_view.gd, shaders/foule.gdshader), le son suit l'intensité
## (audio/soundscape.gd). Le camp 0 (domicile) attaque vers x = 100 (dist/restarts.js, ownGoal).

## Arrêt de jeu montré (sifflet de l'arbitre) : pénalité, mêlée, touche, essai, mi-temps, fin.
signal arret(kind: String)
## Essai montré : camp qui marque (0 domicile, 1 extérieur, -1 inconnu).
signal essai(camp: int)

const CALME := 0.22
const ENTREE_22 := 0.5
const LIGNE := 0.8
const ESSAI := 1.0
## Mètres restants jusqu'à la ligne d'essai sous lesquels l'intensité atteint LIGNE.
const PRES_LIGNE := 5.0
const TENUE_ESSAI := 4.5
## Vitesse de variation de l'intensité (par seconde) : montée franche, retombée lente.
const MONTEE := 0.9
const DESCENTE := 0.16
## Vitesse de lever / rassoir (part de la tribu par seconde) : un lever en vague, pas d'un bloc.
const LEVER := 0.9
const RASSOIR := 0.3
## Parts debout visées (domicile, extérieur, neutres).
const DEBOUT_REPOS := 0.02
const DEBOUT_22 := 0.5
const DEBOUT_ESSAI := 0.92
const DEBOUT_ESSAI_NEUTRES := 0.55
const BRAS_ESSAI := 0.7
const ARRETS := ["penalty", "scrum", "touch", "lineout", "try"]
const SIFFLET_MIN_S := 1.5

var intensite := CALME
var cible := CALME
## Camp en possession dans les 22 mètres adverses, -1 sinon.
var camp_offensif := -1
var essai_camp := -1
var essai_restant := 0.0
## Parts debout et bras levés par tribu : [domicile, extérieur, neutres].
var debout: Array[float] = [0.0, 0.0, 0.0]
var bras: Array[float] = [0.0, 0.0, 0.0]
## Part de chaque tribu dans le public (posée par la vue à la construction des tribunes).
var repartition: Array[float] = [0.55, 0.15, 0.30]
## Vrai tant que la vue montre encore la course vers l'en-but (match_view.gd, essai_aplati).
var essai_suspendu := false
const SUSPENSION_MAX := 15.0
var _attente_essai := 0.0
var _cle_essai := ""
var _kind := ""
var _arret_vu := false
var _depuis_sifflet := 99.0
var _pause := false

## Image montrée : `live` tel que reçu par la vue (scene, paused, atBreak, finished).
func observer(live: Dictionary) -> void:
	var scene: Dictionary = live.get("scene", {}) if live.get("scene") is Dictionary else {}
	var pause_avant := _pause
	_pause = bool(live.get("paused", false)) or bool(live.get("atBreak", false)) or bool(live.get("finished", false))
	var kind := str(scene.get("kind", ""))
	var cle := str(scene.get("key", ""))
	# Arrêt de jeu : à l'entrée dans une phase arrêtée, ou au passage à la mi-temps / fin.
	var arrete := kind in ARRETS
	if (arrete and not _arret_vu) or (bool(live.get("atBreak", false)) or bool(live.get("finished", false))) and not pause_avant:
		if _depuis_sifflet >= SIFFLET_MIN_S:
			_depuis_sifflet = 0.0
			arret.emit(kind if arrete else ("fin" if bool(live.get("finished", false)) else "mi-temps"))
	_arret_vu = arrete
	_kind = kind
	if kind == "try":
		var camp := _camp(scene.get("team", scene.get("possession", -1)))
		var identite := cle if not cle.is_empty() else JSON.stringify([scene.get("team"), scene.get("ball"), scene.get("score")])
		if identite != _cle_essai:
			_cle_essai = identite
			essai_camp = camp
			essai_restant = TENUE_ESSAI
			essai.emit(camp)
		camp_offensif = -1
		cible = ESSAI
		return
	camp_offensif = -1
	cible = CALME * (0.8 if _pause else 1.0)
	var ballon: Variant = scene.get("ball")
	var possession := _camp(scene.get("possession", -1))
	if _pause or not ballon is Dictionary or not (ballon as Dictionary).has("x") or possession < 0:
		return
	var reste := restant(float(ballon.x), possession)
	if reste <= 22.0:
		camp_offensif = possession
		cible = lerpf(ENTREE_22, LIGNE, clampf((22.0 - reste) / (22.0 - PRES_LIGNE), 0.0, 1.0))

## Mètres jusqu'à la ligne d'essai adverse pour le camp en possession (négatif : dans l'en-but).
static func restant(x: float, possession: int) -> float:
	return 100.0 - x if possession == 0 else x

static func _camp(valeur: Variant) -> int:
	if typeof(valeur) in [TYPE_INT, TYPE_FLOAT] and int(valeur) in [0, 1]:
		return int(valeur)
	return -1

func avancer(delta: float) -> void:
	if delta <= 0.0:
		return
	_depuis_sifflet += delta
	# Plan de l'essai reçu mais course encore à l'écran : le public monte comme près de la ligne,
	# l'explosion (et sa tenue) part à l'aplati montré.
	# Attente bornée (SUSPENSION_MAX) : un essai reçu finit toujours par être fêté.
	_attente_essai = _attente_essai + delta if essai_suspendu and essai_restant > 0.0 else 0.0
	var suspendu := essai_suspendu and essai_restant > 0.0 and _attente_essai < SUSPENSION_MAX
	if essai_restant > 0.0 and not suspendu:
		essai_restant = maxf(0.0, essai_restant - delta)
	var vise := (LIGNE if suspendu else ESSAI) if essai_restant > 0.0 else cible
	intensite = move_toward(intensite, vise, delta * (MONTEE if vise > intensite else DESCENTE))
	var cibles_debout: Array[float] = [DEBOUT_REPOS, DEBOUT_REPOS, DEBOUT_REPOS]
	var cibles_bras: Array[float] = [0.0, 0.0, 0.0]
	var offensif := essai_camp if suspendu else camp_offensif
	if essai_restant > 0.0 and not suspendu:
		if essai_camp in [0, 1]:
			cibles_debout[essai_camp] = DEBOUT_ESSAI
			cibles_bras[essai_camp] = BRAS_ESSAI
		else:
			cibles_debout[0] = DEBOUT_ESSAI_NEUTRES
		cibles_debout[2] = DEBOUT_ESSAI_NEUTRES
		cibles_bras[2] = BRAS_ESSAI * 0.3
	elif offensif in [0, 1]:
		# Plus l'action approche de l'en-but, plus les supporters de l'attaque se lèvent.
		var monte := clampf((intensite - CALME) / (LIGNE - CALME), 0.0, 1.0)
		cibles_debout[offensif] = maxf(DEBOUT_REPOS, DEBOUT_22 * monte)
		cibles_debout[2] = maxf(DEBOUT_REPOS, DEBOUT_22 * 0.35 * monte)
		cibles_bras[offensif] = 0.12 * monte
	for t in 3:
		debout[t] = move_toward(debout[t], cibles_debout[t], delta * (LEVER if cibles_debout[t] > debout[t] else RASSOIR))
		bras[t] = move_toward(bras[t], minf(cibles_bras[t], debout[t]), delta * (LEVER * 1.5 if cibles_bras[t] > bras[t] else RASSOIR * 2.0))

## Part de tout le public debout (0 à 1).
func part_debout() -> float:
	var total := 0.0
	var poids := 0.0
	for t in 3:
		total += debout[t] * repartition[t]
		poids += repartition[t]
	return total / poids if poids > 0.0 else 0.0

func etat() -> Dictionary:
	return {"intensite": snappedf(intensite, 0.001), "debout": snappedf(part_debout() * 100.0, 0.1), "essai": essai_restant > 0.0 and not (essai_suspendu and _attente_essai < SUSPENSION_MAX), "camp_offensif": camp_offensif}
