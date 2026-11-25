extends Control
## Socle de la fenêtre « Équipe » : préchargements, constantes, état, accès au modèle du direct (live, XV, banc),
## actions (remplacer, crier, consignes, rôles) et petits utilitaires statiques. `_rafraichir` n'y est qu'un point d'entrée
## vide : la vraie reconstruction vit dans match_equipe.gd (qui la redéfinit).
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

const FocusLater = preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/contextual/skin.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const MenuJoueur = preload("res://ui/contextual/match_menu_joueur.gd")
const Notation = preload("res://ui/notation_staff.gd")
## Taille de la maquette : tout est écrit pour 1600×900 et mis à l'échelle (k) de la fenêtre.
const REF := Vector2(1600, 900)
## Place de chaque numéro sur le terrain (% de la largeur, % de la hauteur), avants à gauche, attaque ▸.
## Lignes de trois-quarts en colonnes (demis, centres, triangle du fond) : les médaillons agrandis ne se
## chevauchent plus (capture du 18/11/2026, la diagonale de la maquette les empilait).
const PLACES := {1: Vector2(14, 20), 2: Vector2(14, 50), 3: Vector2(14, 80), 4: Vector2(26, 34), 5: Vector2(26, 66),
	6: Vector2(38, 14), 7: Vector2(38, 86), 8: Vector2(38, 50), 9: Vector2(51, 30), 10: Vector2(51, 70),
	11: Vector2(77, 13), 12: Vector2(64, 30), 13: Vector2(64, 70), 14: Vector2(77, 87), 15: Vector2(89, 50)}
const ARBITRE_AXES := [["rucks", "Rucks"], ["melee", "Mêlée"], ["horsJeu", "Hors-jeu"], ["cartons", "Cartons"]]
const ARBITRE_MOTS := ["", "laisse jouer", "souple", "équilibré", "pointilleux", "très pointilleux"]
var view: Control
var app: Node
## « composition », « consignes » ou « roles ».
var onglet := "composition"
## Échelle de la maquette dans la fenêtre.
var k := 1.0
## Joueur du XV choisi (poste 0 à 14, -1 : aucun) et remplaçant choisi (id, "" : aucun).
var poste_choisi := -1
var entrant_choisi := ""
## Médaillons du terrain (poste → bouton) et tuiles du banc (id → bouton), pour les tests.
var medaillons: Dictionary = {}
var tuiles: Dictionary = {}
var _model: Dictionary = {}
var _cle := ""
var _veut_pause := false
var _veut_reprise := false
## Commande envoyée depuis la fenêtre, en attente de la réponse du moteur, et message à montrer ensuite.
var _attente := ""
var _succes := ""
var _message := ""
var _message_teinte := C.MUTED
var _conseil_ecarte := ""
var _page: Control
var _pied_ligne2: HBoxContainer  ## Seconde ligne du pied (arbitre) ; vide sur l'onglet Consignes.
var _gras: FontVariation
const CRAN_TAILLE := 14.0
const LIBELLES_COURTS := {"Chercher les points": "Points", "Chercher la pénaltouche": "Pénaltouche", "Jouer vite à la main": "Jeu rapide", "Selon le contexte": "Auto",
	"Montée agressive": "Montée", "Glissée prudente": "Glissée", "Jeu au large": "Large", "Jeu au près": "Près", "Jouer la montre": "La montre",
	"Presser l’ouvreur": "Ouvreur", "Leur aile faible": "Aile faible", "Sortir vite": "Vite"}
## Groupes de l'onglet Consignes (décision de Léo, 18/11/2026), dans cet ordre ; deux colonnes :
## Attaque et Défense à gauche, Conquête et Adversaire à droite. Libellés : `live.pilotage.groupes`.
const GROUPES := [["attaque", "Attaque", "avec le ballon"], ["defense", "Défense", "sans le ballon"], ["conquete", "Conquête", "phases arrêtées"], ["adversaire", "Adversaire", "leurs points faibles"]]

## Reconstruit la page (redéfinie dans match_equipe.gd : le socle ne la connaît pas, les actions la rappellent).
func _rafraichir() -> void:
	pass

func _live() -> Dictionary:
	return _model.get("live", {}) if _model.get("live") is Dictionary else {}

## « Valider et reprendre » : la fenêtre se ferme et le match repart.
func fermer(reprendre: bool = true) -> void:
	hide()
	_veut_pause = false
	_veut_reprise = reprendre
	if view != null and view.has_method("equipe_fermee"): view.equipe_fermee()

func choisir_onglet(vers: String) -> void:
	onglet = vers
	_cle = ""
	_rafraichir()

func _pilotage() -> Dictionary:
	return Pilotage.pilotage(_live())

func _direct() -> Dictionary:
	return _live().get("direct") if _live().get("direct") is Dictionary else {}

func _lineup() -> Array:
	return _live().get("lineup", []) if _live().get("lineup") is Array else []

func _reserves() -> Array:
	return _live().get("reserves", []) if _live().get("reserves") is Array else []

## Fiche de l'effectif (niveau, index de portrait) : complète le joueur du direct.
func _fiche(id: String) -> Dictionary:
	for joueur: Variant in _model.get("squad", []):
		if joueur is Dictionary and str(joueur.get("id", "")) == id: return joueur
	return {}

## Joueur pour le portrait : le joueur du direct, complété par sa fiche de l'effectif.
func _joueur_complet(joueur: Dictionary) -> Dictionary:
	var complet := _fiche(str(joueur.get("id", ""))).duplicate()
	complet.merge(joueur, true)
	return complet

## Niveau du joueur en lettre du staff (notation façon FM : jamais le chiffre du moteur) : {bas, haut}, bas -1 s'il manque.
func _lettre_niveau(joueur: Dictionary) -> Dictionary:
	var fiche := _fiche(str(joueur.get("id", "")))
	if fiche.is_empty(): return {"bas": -1, "haut": -1}
	return Notation.lettre_champ(fiche, "rating", true, _model)

## Texte de la lettre du Niveau ; "" s'il manque.
func _niveau(joueur: Dictionary) -> String:
	var l := _lettre_niveau(joueur)
	return Notation.texte_note(l) if int(l.bas) >= 0 else ""

func _entrants(slot: int) -> Array:
	for option: Variant in _live().get("substitutions", []):
		if option is Dictionary and int(option.get("slot", -1)) == slot: return option.get("inIds", []) if option.get("inIds") is Array else []
	return []

func _autorise(slot: int, id: String) -> bool:
	return _entrants(slot).any(func(x: Variant) -> bool: return str(x) == id)

func _poste_de(id: String) -> int:
	var lineup := _lineup()
	for n in lineup.size():
		if lineup[n] is Dictionary and str(lineup[n].get("id", "")) == id: return n
	return -1

func _reserve(id: String) -> Dictionary:
	for joueur: Variant in _reserves():
		if joueur is Dictionary and str(joueur.get("id", "")) == id: return joueur
	return {}

static func nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.is_empty(): return ""
	var famille := " ".join(morceaux.slice(1)) if morceaux.size() > 1 else morceaux[0]
	return famille if famille.length() <= 11 else famille.substr(0, 10) + "."

static func teinte_energie(valeur: float) -> Color:
	if valeur >= 75.0: return C.MINT
	if valeur >= 60.0: return C.IVORY
	return C.ALERT

# --- Actions -------------------------------------------------------------------

func choisir_poste(slot: int) -> void:
	if not entrant_choisi.is_empty() and _autorise(slot, entrant_choisi):
		remplacer(slot, entrant_choisi)
		return
	poste_choisi = -1 if poste_choisi == slot else slot
	entrant_choisi = ""
	_message = ""
	_cle = ""
	_rafraichir()

func choisir_entrant(id: String) -> void:
	if poste_choisi >= 0 and _autorise(poste_choisi, id):
		remplacer(poste_choisi, id)
		return
	entrant_choisi = "" if entrant_choisi == id else id
	_message = ""
	_cle = ""
	_rafraichir()

## Remplacement : `substitute {slot, outId, inId}` (le moteur vérifie poste, première ligne et cartons).
func remplacer(slot: int, in_id: String) -> void:
	var lineup := _lineup()
	if slot < 0 or slot >= lineup.size(): return
	var sortant: Variant = lineup[slot]
	var out_id: Variant = sortant.get("id") if sortant is Dictionary else null
	var entrant := _reserve(in_id)
	var payload := {"slot": slot, "outId": out_id, "inId": in_id}
	poste_choisi = -1
	entrant_choisi = ""
	if app._command("substitute", payload):
		_attente = "substitute"
		_succes = "%s entre à la place de %s." % [nom_court(str(entrant.get("name", "Le remplaçant"))), nom_court(str(sortant.get("name", "")) if sortant is Dictionary else "poste vacant")]
		_message = "Changement demandé…"
		_message_teinte = C.MUTED
	_cle = ""
	_rafraichir()

func crier(id: String) -> void:
	if app._command("cri", {"id": id}):
		_attente = "cri"
		_succes = "Le message est passé depuis la touche."
	_cle = ""
	_rafraichir()

func _envoyer_consigne(axe: String, valeur: String) -> void:
	if view != null and view.has_method("_envoyer_consigne"): view._envoyer_consigne(axe, valeur)
	else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))
	_cle = ""
	_rafraichir()

## « Appliquer ces consignes » : l'avis du staff en attente, en une commande, sans pause.
func appliquer_staff() -> void:
	if app._command("appliquer_staff", {}):
		_attente = "staff"
		_succes = "Consignes du staff appliquées."
	_cle = ""
	_rafraichir()

## Rôle en direct : joueur sur le terrain (id) ou retour au choix du staff (id vide).
func choisir_role(role: String, id: String) -> void:
	if app._command("set_role_direct", {"role": role, "id": null if id.is_empty() else id}):
		_attente = "role"
		_succes = "C'est noté : le staff passe le mot."
	_cle = ""
	_rafraichir()

func _plan(cle: String, id: Variant) -> void:
	var courant: Dictionary = _model.get("tactics", {}) if _model.get("tactics") is Dictionary else {}
	var payload := {"attack": courant.get("attack", "equilibre"), "defense": courant.get("defense", "equilibre")}
	payload[cle] = id
	app._command("set_tactics", payload)

# --- Construction --------------------------------------------------------------

## Libellé d'un cran sur une seule ligne (« Pénaltouche ») ; le texte complet reste en infobulle.
static func libelle_court(texte: String) -> String:
	return str(LIBELLES_COURTS.get(texte, texte))

## Bilan court d'un axe : ce qui suit « : » dans le bilan du moteur (« 3 pénalités, 2 ballons arrachés »).
static func bilan_court(p: Dictionary, axe: String) -> String:
	for bilan: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if bilan is Dictionary and str(bilan.get("axe", "")) == axe:
			var texte := str(bilan.get("texte", ""))
			var coupe := texte.find(" : ")
			var morceaux := texte.substr(coupe + 3).trim_suffix(".") if coupe >= 0 else texte
			return "Depuis %d′ : %s" % [int(bilan.get("depuis", 0)), morceaux] if bilan.get("depuis") != null else morceaux
	return ""

# --- Onglet Composition ----------------------------------------------------------

## Cran sans effet d'un axe : `neutre` du moteur, sinon le premier cran « équilibré / contexte / aucun »
## pour le plan de jeu et le point faible, sinon le cran du milieu.
static func cran_neutre(axe: Dictionary) -> String:
	if not str(axe.get("neutre", "")).is_empty(): return str(axe.neutre)
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	if options.is_empty(): return ""
	if bool(axe.get("pause", false)) or str(axe.get("id", "")) == "cible":
		for option: Variant in options:
			var id := str(option.get("id", "")) if option is Dictionary else ""
			if id.begins_with("equilibr") or id in ["contexte", "context", "aucune", "aucun", "normal"]: return id
		return str(options[0].get("id", ""))
	return str(options[1 if options.size() >= 3 else 0].get("id", ""))
