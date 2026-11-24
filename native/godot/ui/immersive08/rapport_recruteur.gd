extends RefCounted
## Rapport du recruteur (revue FM27 du 22/11/2026, idée n° 2) : sous-page du Recrutement pour une piste du marché.
## Lettre du staff (échelle unique E- à S+, relative à notre effectif, notation_staff.gd) avec le palier écrit, « Pour /
## Contre » en icônes, rang qu'aurait le joueur
## dans notre effectif au même poste (liste comparée façon Effectif), statut du transfert, indemnité et salaire demandé.
## Tout est lu dans le modèle (marché, effectif, rapports d'observation) : rien n'est inventé ; ce qui manque est absent.
## Mise en page choisie par Léo (planche A/B du 22/11/2026, option A) : identité et avis en tête, puis trois colonnes
## (qualités clés, pour / contre, notre effectif au poste).
## Coordonnées en unités du gabarit (2248 de large), jetons de la charte.
const Notation = preload("res://ui/notation_staff.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const G = preload("res://ui/game_skin.gd")
const Link = preload("res://ui/entity_link.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")

const LARGEUR := 2248.0
const HAUTEUR := 1000.0
const POSTES := ["Pilier gauche", "Talonneur", "Pilier droit", "2e ligne", "2e ligne", "3e ligne aile", "3e ligne aile",
	"Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
## Qualités clés par poste (clés attributesV2), les plus utiles d'abord.
const QUALITES := {
	1: ["scrumTechnique", "strength", "maul", "lineoutLift", "tackling", "endurance"],
	2: ["hooking", "lineoutThrow", "scrumTechnique", "strength", "tackling", "ruckClearout"],
	4: ["lineoutJump", "aerialAbility", "maul", "strength", "tackling", "ruckClearout"],
	6: ["tackling", "jackal", "workRate", "ruckClearout", "endurance", "ballCarry"],
	8: ["ballCarry", "tackling", "strength", "decisions", "workRate", "explosiveness"],
	9: ["passing", "decisions", "kickAccuracy", "vision", "acceleration", "ballHandling"],
	10: ["kickDistance", "kickAccuracy", "goalAccuracy", "decisions", "vision", "passing"],
	11: ["topSpeed", "acceleration", "evasion", "receiving", "aerialAbility", "kickChase"],
	12: ["ballCarry", "tackling", "passing", "evasion", "strength", "decisions"],
	15: ["aerialAbility", "kickDistance", "receiving", "topSpeed", "positioning", "evasion"],
}
const FAMILLE_QUALITES := {1: 1, 3: 1, 2: 2, 4: 4, 5: 4, 6: 6, 7: 6, 8: 8, 9: 9, 10: 10, 11: 11, 14: 11, 12: 12, 13: 12, 15: 15}

# --- Lecture des données ------------------------------------------------------------------------------------------------

static func _nombre(v: Variant) -> bool:
	return K.number(v)

## Piste demandée, sinon la piste choisie dans la liste, sinon la mieux connue du marché.
static func piste(app: Control, id: String) -> Dictionary:
	var marche: Array = app.model.get("market", [])
	if id.is_empty():
		var etat: Variant = app.management_ui.get("market")
		if etat is Dictionary: id = str(etat.get("player_id", ""))
	for p: Variant in marche:
		if p is Dictionary and str(p.get("id", "")) == id: return p
	# Par défaut : la piste la mieux connue au poste du premier besoin du club, sinon de tout le marché.
	var besoins: Array = app.model.get("decisions", {}).get("recruitment", {}).get("needs", [])
	var poste_besoin := str(besoins[0].get("pos", "")) if not besoins.is_empty() and besoins[0] is Dictionary else ""
	var au_poste := marche.filter(func(p: Variant): return p is Dictionary and not poste_besoin.is_empty() and str(p.get("pos", "")).begins_with(poste_besoin.substr(0, 5)))
	if not au_poste.is_empty(): marche = au_poste
	var meilleur: Dictionary = {}
	var rang := -1
	for p: Variant in marche:
		if not p is Dictionary: continue
		var stade := str(p.get("knowledge", {}).get("stage", "")) if p.get("knowledge") is Dictionary else ""
		var valeur := {"deep": 2, "observed": 1}.get(stade, 0) as int
		if valeur > rang or (valeur == rang and _note_marche(p, _poste(p)) > _note_marche(meilleur, _poste(meilleur))):
			rang = valeur
			meilleur = p
	return meilleur

## Poste principal (1-15) d'un joueur.
static func _poste(p: Dictionary) -> int:
	if p.is_empty(): return 0
	var principaux: Variant = p.get("primaryPositions")
	if principaux is Array and not principaux.is_empty() and _nombre(principaux[0]): return int(principaux[0])
	if _nombre(p.get("primaryPosition")): return int(p.primaryPosition)
	var nom := str(p.get("pos", ""))
	for i in POSTES.size():
		if nom.begins_with(str(POSTES[i]).substr(0, 6)): return i + 1
	return 0

## Postes équivalents (11 et 14, 12 et 13…) : même libellé.
static func _equivalents(numero: int) -> Array:
	var liste: Array = []
	if numero < 1: return liste
	for i in POSTES.size():
		if POSTES[i] == POSTES[numero - 1]: liste.append(i + 1)
	return liste

## Valeur cachée d'un joueur du marché au poste (tri et rang seulement, jamais affichée) : note au poste publiée, sinon
## milieu de la fourchette de niveau. À l'écran : `Notation.lettre_poste` (lettre estimée, double tant qu'il est à observer).
static func _note_marche(p: Dictionary, numero: int) -> float:
	if p.is_empty(): return -1.0
	var notes: Variant = p.get("positionRatings")
	if notes is Dictionary and _nombre(notes.get(str(numero))): return float(notes.get(str(numero)))
	var b := K.bounds(p, "rating")
	if not b.is_empty(): return (float(b.min) + float(b.max)) / 2.0
	return -1.0

## Joueurs de notre effectif à ce poste (principal ou secondaire, postes équivalents compris), du meilleur au moins bon.
static func comparaison(app: Control, numero: int) -> Array:
	var postes := _equivalents(numero)
	var liste: Array = []
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		var joue := false
		for cle in ["primaryPositions", "secondaryPositions"]:
			var valeurs: Variant = p.get(cle)
			if valeurs is Array:
				for n: Variant in valeurs:
					if _nombre(n) and int(n) in postes: joue = true
		if not joue and str(p.get("pos", "")) == POSTES[numero - 1]: joue = true
		if joue:
			var lettre := Notation.lettre_poste(app.model, p, numero, true)
			# Ordre = lettre MONTRÉE (milieu d'une double) ; à lettre égale, le nom : jamais le chiffre caché.
			liste.append({"joueur": p, "note": Notation.rang_lettre(lettre), "lettre": lettre})
	liste.sort_custom(func(a: Dictionary, b: Dictionary):
		if float(a.note) != float(b.note): return float(a.note) > float(b.note)
		return str(a.joueur.get("name", "")) < str(b.joueur.get("name", "")))
	return liste

## Lecture complète du rapport : piste, poste, note, rang, lettre du staff (E- à S+, même échelle que la fiche),
## pour / contre, qualités clés.
static func lire(app: Control, p: Dictionary) -> Dictionary:
	var numero := _poste(p)
	var lettre_piste := Notation.lettre_poste(app.model, p, numero, false)
	var note := Notation.rang_lettre(lettre_piste)
	var autres := comparaison(app, numero) if numero > 0 else []
	var rang := 1
	for ligne: Dictionary in autres:
		if float(ligne.note) > note: rang += 1
	var meilleur := float(autres[0].note) if not autres.is_empty() else note
	var ecart := note - meilleur if note >= 0 else -999.0
	var notation := Notation.resume(app.model, p, false)
	var indice := int(notation.niveau)
	var qualites: Array = []
	var attributs: Variant = p.get("attributesV2")
	if K.attributes_known(p) and attributs is Dictionary:
		for cle: String in QUALITES.get(FAMILLE_QUALITES.get(numero, 0), []):
			if _nombre(attributs.get(cle)): qualites.append([cle, float(attributs.get(cle))])
	var r := {"piste": p, "numero": numero, "poste": POSTES[numero - 1] if numero > 0 else str(p.get("pos", "—")), "note": note,
		"lettre_poste": lettre_piste, "rang": rang, "total": autres.size() + 1, "ecart": ecart, "indice": indice, "lettre": Notation.texte_lettre(indice),
		"couleur": Notation.couleur(indice), "notation": notation, "autres": autres, "qualites": qualites}
	r.pour = _pour(app, r)
	r.contre = _contre(app, r)
	return r

const NOMS_QUALITES := {"passing": "Passe", "receiving": "Réception", "offload": "Passe après contact", "ballCarry": "Portage",
	"evasion": "Évitement", "ballHandling": "Maniement", "kickDistance": "Jeu au pied long", "kickAccuracy": "Précision au pied",
	"goalAccuracy": "Buteur", "decisions": "Décisions", "anticipation": "Anticipation", "vision": "Vision du jeu",
	"positioning": "Placement", "composure": "Sang-froid", "discipline": "Discipline", "teamwork": "Jeu collectif",
	"leadership": "Leadership", "workRate": "Activité", "acceleration": "Accélération", "topSpeed": "Vitesse",
	"agility": "Agilité", "explosiveness": "Explosivité", "strength": "Force", "endurance": "Endurance", "jumping": "Détente",
	"kickChase": "Chasse au pied", "aerialAbility": "Jeu aérien", "tackling": "Plaquage", "jackal": "Grattage",
	"ruckClearout": "Nettoyage", "scrumTechnique": "Mêlée", "hooking": "Talonnage", "lineoutThrow": "Lancer en touche",
	"lineoutJump": "Saut en touche", "lineoutLift": "Lift en touche", "maul": "Maul"}

## Points forts : [icône, mot court, chiffre ou détail, action].
static func _pour(app: Control, r: Dictionary) -> Array:
	var p: Dictionary = r.piste
	var id := str(p.get("id", ""))
	var fiche := func(): app.navigation_controller.open_entity({"kind": "market", "id": id})
	var liste: Array = []
	if r.rang == 1 and r.total > 1: liste.append(["rating", "Titulaire chez nous", "n° 1", fiche])
	elif r.rang <= 2 and r.total > 2: liste.append(["rating", "Dans les 23", "n° %d" % r.rang, fiche])
	for q: Array in r.qualites:
		if float(q[1]) >= 70.0 and liste.size() < 4: liste.append(["target", str(NOMS_QUALITES.get(q[0], q[0])), G.n(q[1]), fiche])
	# Potentiel : phrase du staff (jamais l'écart chiffré entre niveau et potentiel).
	var phrase: Dictionary = r.notation.phrase
	if str(phrase.cran) in ["beaucoup", "marge"]: liste.append(["renew", str(phrase.texte), "", fiche])
	if _nombre(p.get("age")) and int(p.age) <= 23: liste.append(["school", "Jeune", "%d ans" % int(p.age), fiche])
	var faits: Dictionary = p.get("playerFacts", {}) if p.get("playerFacts") is Dictionary else {}
	if _nombre(faits.get("seniorCaps")) and int(faits.seniorCaps) > 0: liste.append(["flag", "International", "%d sél." % int(faits.seniorCaps), fiche])
	var quota: Variant = p.get("quota")
	if quota is Dictionary and bool(quota.get("counts", quota.get("jiff", false))): liste.append(["shield", "JIFF", "✓", fiche])
	var postes := 0
	for cle in ["primaryPositions", "secondaryPositions"]:
		if p.get(cle) is Array: postes += (p.get(cle) as Array).size()
	if postes >= 3: liste.append(["people", "Polyvalent", "%d postes" % postes, fiche])
	return liste

static func _contre(app: Control, r: Dictionary) -> Array:
	var p: Dictionary = r.piste
	var id := str(p.get("id", ""))
	var fiche := func(): app.navigation_controller.open_entity({"kind": "market", "id": id})
	var finances := func(): app.navigation_controller.open_entity({"kind": "finance", "id": "transfers"})
	var liste: Array = []
	if r.rang > 2: liste.append(["people", "Hors des 23", "n° %d" % r.rang, fiche])
	for q: Array in r.qualites:
		if float(q[1]) < 55.0 and liste.size() < 3: liste.append(["warning", str(NOMS_QUALITES.get(q[0], q[0])), G.n(q[1]), fiche])
	if _nombre(p.get("age")) and int(p.age) >= 31: liste.append(["hourglass", "Fin de carrière", "%d ans" % int(p.age), fiche])
	var raison := str(p.get("reason", ""))
	if not raison.is_empty() and not bool(p.get("available", false)):
		liste.append(["money" if raison.contains("udget") or raison.contains("résorerie") else "lock", raison.split(" · ")[0].substr(0, 26), "", finances])
	# Salaire au-dessus du mieux payé de nos joueurs au poste.
	var plafond := 0.0
	for ligne: Dictionary in r.autres:
		var s: Variant = ligne.joueur.get("salary")
		if _nombre(s): plafond = maxf(plafond, float(s))
	if _nombre(p.get("salary")) and plafond > 0 and float(p.salary) > plafond * 1.15:
		liste.append(["money", "Salaire au-dessus du groupe", "+%d %%" % int(100.0 * (float(p.salary) / plafond - 1.0)), finances])
	var stade := str(p.get("knowledge", {}).get("stage", "")) if p.get("knowledge") is Dictionary else ""
	if stade != "deep": liste.append(["search", "Qualités à confirmer", "", fiche])
	var quota: Variant = p.get("quota")
	if quota is Dictionary and quota.has("counts") and not bool(quota.counts): liste.append(["shield", "Non JIFF", "", fiche])
	return liste

# --- Construction --------------------------------------------------------------------------------------------------------

static func construire(app: Control, cadre: Control, titre: Label, courant: Dictionary) -> void:
	D.place(cadre, Rect2(0, 146, LARGEUR, HAUTEUR))
	var p := piste(app, str(courant.get("player_id", "")))
	if p.is_empty():
		Pieces.pastille(cadre, 28, 40, "Aucune piste", "search", "RapportRecruteurVide")
		return
	var r := lire(app, p)
	titre.text = "RAPPORT DU RECRUTEUR"
	cadre.set_meta("rapport", {"lettre": r.lettre, "rang": r.rang, "poste": r.numero, "pret": p.get("loan", {})})
	_mise_en_page(app, cadre, r)
	# Discussion avec l'agent (idée FM 24) : pastille à côté de la connaissance ; rouverte après une réponse du moteur.
	var Agent: Variant = load("res://ui/discussion_agent.gd")
	var stade := str(p.get("knowledge", {}).get("stage", "")) if p.get("knowledge") is Dictionary else ""
	var mot := {"deep": "Bien connu", "observed": "Observé"}.get(stade, "Non observé") as String
	var agent_nom := str(p.get("agent", {}).get("nom", "")) if p.get("agent") is Dictionary else ""
	Pieces.pastille(cadre, 172 + Pieces.largeur_pastille(mot, "search"), 124, "Parler à " + agent_nom if not agent_nom.is_empty() and agent_nom != "L’agent" else "Parler à l’agent", "people", "RapportAgentOuvrir", "", Pieces.BLEU, Charte.PANNEAU_3,
		func(): Agent.ouvrir(app, cadre.get_parent(), p))
	if bool(courant.get("agent", false)):
		courant.erase("agent")
		Agent.ouvrir(app, cadre.get_parent(), p)

## Identité : visage, nom (fiche), poste, âge.
static func _identite(app: Control, cadre: Control, r: Dictionary, x: float, y: float, cote: float) -> void:
	var p: Dictionary = r.piste
	var portrait: Control = load("res://ui/carnet_skin.gd").portrait(0, int(cote * C.density), p)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(portrait)
	D.place(portrait, Rect2(x, y, cote, cote))
	var id := str(p.get("id", ""))
	var nom := Link.styled_button(cadre, Rect2(x + cote + 22, y + 2, 560, 50), str(p.get("name", "—")), 32, Charte.IVOIRE, "RapportRecruteurNom")
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.pressed.connect(func(): app.navigation_controller.open_entity({"kind": "market", "id": id}))
	load("res://ui/carte_joueur_survol.gd").lier(app, nom, id, "market")
	var ligne := "%s · n° %d · %s ans" % [r.poste, r.numero, G.n(p.get("age", "—"))] if r.numero > 0 else str(p.get("pos", "—"))
	Kit.texte(cadre, x + cote + 24, y + 86, ligne, Charte.IVOIRE_2, 560, 20)

## Lettre de l'avis : carré coloré, clic = barème en petite fenêtre.
static func _lettre(app: Control, cadre: Control, r: Dictionary, zone: Rect2, taille: int) -> Button:
	var couleur: Color = r.couleur
	var bouton := Button.new()
	bouton.name = "RapportRecruteurLettre"
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Avis du recruteur " + str(r.lettre)
	# Pastille ronde (choix B de Léo, notation façon FM).
	var rayon := int(zone.size.y / 2.0)
	for etat in ["normal", "pressed", "focus"]: bouton.add_theme_stylebox_override(etat, C.box(couleur, Color.TRANSPARENT, rayon, 0))
	bouton.add_theme_stylebox_override("hover", C.box(couleur.lightened(.12), Color.TRANSPARENT, rayon, 0))
	cadre.add_child(bouton)
	D.place(bouton, zone)
	var texte := D.text(bouton, zone.size.x / 2.0, zone.size.y * 0.5 + taille * 0.36, str(r.lettre), taille, Notation.couleur_texte(int(r.indice)), 800, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	texte.add_theme_font_override("font", Charte.TITRE_FICHE)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bouton.pressed.connect(func(): _bareme(app, cadre, r, bouton))
	return bouton

## Petite fenêtre du barème : l'échelle unique E- à S+ (18 pastilles rondes, la nôtre détachée), puis rang et note au
## poste en tuiles et la lettre de notre n° 1 au poste.
static func _bareme(app: Control, cadre: Control, r: Dictionary, origine: Control) -> void:
	var page := cadre.get_parent() as Control
	var fond := Fenetre.ouvrir(page, "RapportRecruteurBareme", "Avis du recruteur", "rating", 1100, 360, func():
		if is_instance_valid(origine): origine.grab_focus())
	var x := 28.0
	for i in Notation.LETTRES.size():
		var actif := i == int(r.indice)
		var taille := 64.0 if actif else 50.0
		Notation.pastille(fond, x, 136.0, i, taille, "Bareme_" + str(Notation.LETTRES[i]).replace("+", "plus").replace("-", "moins"))
		x += taille + 8.0
	Pieces.tuile(fond, Rect2(28, 220, 200, 96), "%d / %d" % [r.rang, r.total], "rang au poste", Charte.IVOIRE, "BaremeRang", 34)
	_tuile_lettre(fond, Rect2(244, 220, 200, 96), r.lettre_poste, "note au poste", "BaremeNote", 50.0)
	if not r.autres.is_empty():
		var premier: Dictionary = r.autres[0].joueur
		var case_ := D.rect(fond, Rect2(460, 220, 320, 96), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		case_.name = "BaremeNotreNumero1"
		Notation.pastille(case_, 16, 48, int(Notation.resume(app.model, premier, true).niveau), 60, "BaremeLettreNumero1")
		D.text(case_, 90, 40, str(premier.get("name", "—")), 20, Charte.IVOIRE, 700, 216, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(case_, 90, 72, "notre n° 1 au poste", 16, Charte.IVOIRE_3, 600, 216)

## Pastilles du transfert et du prêt : statut (ouvert / raison), clic = offre au joueur ; prêt possible ou non (le club
## de la piste le prêterait-il ?), clic = fiche de la piste (l'offre au joueur ne propose pas de prêt entrant).
const RAISONS_PRET := {"jeune": "Jeune : son club le laisserait partir en prêt", "hors-23": "Hors des 23 de son club", "cadre": "Cadre de son club : pas de prêt"}

static func _transfert(app: Control, cadre: Control, r: Dictionary, x: float, y: float) -> float:
	var p: Dictionary = r.piste
	var id := str(p.get("id", ""))
	var ouvert := bool(p.get("available", false))
	var largeur := Pieces.pastille(cadre, x, y, "Transfert ouvert" if ouvert else "Transfert fermé", "check" if ouvert else "lock", "RapportRecruteurTransfert", str(p.get("reason", "")),
		Pieces.VERT if ouvert else Pieces.ROUGE, Charte.PANNEAU_3, func(): load("res://ui/immersive08/recruitment_pages.gd").ouvrir(app, "negociation", {"player_id": id}))
	var pret: Dictionary = p.get("loan", {}) if p.get("loan") is Dictionary else {}
	if not pret.is_empty():
		var possible := bool(pret.get("possible", false))
		largeur += 12 + Pieces.pastille(cadre, x + largeur + 12, y, "Prêt possible" if possible else "Prêt non", "renew" if possible else "lock", "RapportRecruteurPret",
			str(RAISONS_PRET.get(str(pret.get("reason", "")), "")), Pieces.VERT if possible else Pieces.ORANGE, Charte.PANNEAU_3,
			func(): app.navigation_controller.open_entity({"kind": "market", "id": id}))
	return largeur

## Connaissance du recruteur : non observé, observé, bien connu ; clic = fiche de la piste (observer, actualiser).
static func _connaissance(app: Control, cadre: Control, r: Dictionary, x: float, y: float) -> void:
	var p: Dictionary = r.piste
	var id := str(p.get("id", ""))
	var stade := str(p.get("knowledge", {}).get("stage", "")) if p.get("knowledge") is Dictionary else ""
	var mot := {"deep": "Bien connu", "observed": "Observé"}.get(stade, "Non observé") as String
	var couleur: Color = {"deep": Pieces.VERT, "observed": Pieces.BLEU}.get(stade, Pieces.ORANGE)
	Pieces.pastille(cadre, x, y, mot, "search", "RapportRecruteurConnaissance", "", couleur, Charte.PANNEAU_3,
		func(): app.navigation_controller.open_entity({"kind": "market", "id": id}))

## Tuiles d'argent : indemnité, salaire demandé (clic = offre), potentiel.
static func _tuiles(app: Control, cadre: Control, r: Dictionary, x: float, y: float, l: float, h: float, verticales: bool) -> void:
	var p: Dictionary = r.piste
	var id := str(p.get("id", ""))
	var offre := func(): load("res://ui/immersive08/recruitment_pages.gd").ouvrir(app, "negociation", {"player_id": id})
	var pas := Vector2(0, h + 12) if verticales else Vector2(l + 12, 0)
	_tuile_lettre(cadre, Rect2(x, y, l, h), r.lettre_poste, "Note au poste", "RapportRecruteurNote", 56.0, "rating", func(): app.navigation_controller.open_entity({"kind": "market", "id": id}))
	Pieces.tuile(cadre, Rect2(x + 2 * pas.x, y + 2 * pas.y, l, h), _compact(p.get("fee", p.get("price"))), "Indemnité", Pieces.ORANGE, "RapportRecruteurIndemnite", 38, "", "money", true, offre)
	Pieces.tuile(cadre, Rect2(x + 3 * pas.x, y + 3 * pas.y, l, h), G.salary_amount(p.get("salary")), "Salaire " + G.salary_period(true), Pieces.BLEU, "RapportRecruteurSalaire", 38, "", "money", true, offre)

## Tuile à lettre (note au poste, décision de Léo du 24/11) : pastille ronde ou double « B/A » à la place du chiffre,
## légende dessous. Méta « lettre » sur la pastille `<id>Lettre` ; le texte de la tuile (accessibilité) est la lettre.
static func _tuile_lettre(parent: Control, zone: Rect2, lettre: Dictionary, legende: String, id: String, taille: float, icone := "", action := Callable()) -> Panel:
	var carte := Pieces.tuile(parent, zone, Notation.texte_note(lettre), legende, Charte.IVOIRE, id, 30, "", icone, false, action)
	var valeur := carte.get_node_or_null(NodePath(id + "Valeur")) as Label
	if valeur != null: valeur.visible = false
	Notation.pastille_note(carte, 12, (zone.size.y - 24.0) / 2.0, lettre, taille, id + "Lettre")
	return carte

## Tuile Potentiel de la notation : lettre du staff + phrase (aucun chiffre) ; clic = fiche de la piste.
static func _tuile_potentiel(app: Control, cadre: Control, r: Dictionary, zone: Rect2) -> void:
	var note: Dictionary = r.notation
	var id := str(r.piste.get("id", ""))
	var fond := D.rect(cadre, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	fond.name = "RapportRecruteurPotentiel"
	D.text(fond, 14, 26, "POTENTIEL", 14, Charte.IVOIRE_3, 700, 120)
	var lp := Notation.pastille(fond, 14, 66, int(note.potentiel), 50)
	var phrase := D.text(fond, 14 + lp + 10, 58, str(note.phrase.texte), 17, note.phrase.couleur, 700, zone.size.x - lp - 34, HORIZONTAL_ALIGNMENT_LEFT, true)
	phrase.name = "RapportRecruteurPhrase"
	phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	phrase.size.y *= 3.0
	for enfant in fond.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Pieces.rendre_cliquable(fond, zone.size, func(): app.navigation_controller.open_entity({"kind": "market", "id": id}), "RapportRecruteurPotentielLien",
		"Potentiel %s %s" % [Notation.texte_lettre(int(note.potentiel)), str(note.phrase.texte)], "", Charte.RAYON_CARTE)

static func _compact(v: Variant) -> String:
	if not _nombre(v): return "—"
	var f := float(v)
	if f >= 1000000.0: return ("%.1f M€" % (f / 1000000.0)).replace(".", ",").replace(",0 ", " ")
	if f >= 1000.0: return "%d k€" % roundi(f / 1000.0)
	return "%d €" % roundi(f)

## Lignes Pour / Contre : icône teintée + mot + chiffre ; ligne entière cliquable.
static func _raisons(cadre: Control, x: float, y: float, l: float, titre: String, icone: String, couleur: Color, raisons: Array, id: String, pas := 52.0, max_lignes := 6) -> float:
	var tete := C.icon(icone, 26, couleur)
	cadre.add_child(tete)
	D.place(tete, Rect2(x, y, 26, 26))
	var t := D.text(cadre, x + 38, y + 23, titre, 26, couleur, 800, l - 40)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var ly := y + 44
	if raisons.is_empty():
		Kit.texte(cadre, x + 4, ly + 30, "—", Charte.IVOIRE_3, 200, 20)
		return ly + pas
	for i in mini(raisons.size(), max_lignes):
		var raison: Array = raisons[i]
		var ligne := Button.new()
		ligne.name = "%s_%d" % [id, i]
		ligne.accessibility_name = "%s %s" % [raison[1], raison[2]]
		Kit.styler_ligne(ligne, Charte.PANNEAU_2 if i % 2 == 0 else Charte.PANNEAU)
		cadre.add_child(ligne)
		D.place(ligne, Rect2(x, ly, l, pas - 6))
		if (raison[3] as Callable).is_valid(): ligne.pressed.connect(raison[3])
		var image := C.icon(str(raison[0]), 24, couleur)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(image)
		D.place(image, Rect2(14, (pas - 6 - 24) / 2.0, 24, 24))
		D.text(ligne, 52, (pas - 6) / 2.0 + 8, str(raison[1]), 21, Charte.IVOIRE, 600, l - 190).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not str(raison[2]).is_empty():
			var chiffre := D.text(ligne, l - 16, (pas - 6) / 2.0 + 9, str(raison[2]), 24, couleur, 800, 130, HORIZONTAL_ALIGNMENT_RIGHT)
			chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ly += pas
	return ly

## Qualités clés du poste : nom, barre, chiffre au barème des attributs.
static func _qualites(cadre: Control, r: Dictionary, x: float, y: float, l: float) -> float:
	Kit.etiquette(cadre, x, y + 20, "QUALITÉS CLÉS · " + str(r.poste).to_upper(), l)
	var ly := y + 40
	if r.qualites.is_empty():
		Pieces.pastille(cadre, x, ly, "À observer", "search", "RapportRecruteurQualitesInconnues", "", Pieces.ORANGE)
		return ly + 50
	for q: Array in r.qualites:
		var couleur := Charte.couleur_attribut(q[1])
		Kit.texte(cadre, x, ly + 26, str(NOMS_QUALITES.get(q[0], q[0])), Charte.IVOIRE, 250, 20)
		D.rect(cadre, Rect2(x + 260, ly + 12, l - 340, 12), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		D.rect(cadre, Rect2(x + 260, ly + 12, maxf(10.0, (l - 340) * clampf(float(q[1]) / 100.0, 0, 1)), 12), couleur, Charte.RAYON_PILULE)
		var chiffre := D.text(cadre, x + l, ly + 30, G.n(q[1]), 28, couleur, 800, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		ly += 58
	return ly

## Liste comparée façon Effectif : rang, visage, nom (fiche + carte au survol), note au poste en lettre, colonnes au choix.
## La piste est insérée à son rang, ligne détachée (fond vert de sélection + marqueur).
static func _liste(app: Control, cadre: Control, r: Dictionary, zone: Rect2, colonnes: Array, hauteur_ligne := 46.0, max_lignes := 12) -> void:
	var lignes: Array = []
	var place := false
	for ligne: Dictionary in r.autres:
		if not place and float(r.note) > float(ligne.note):
			lignes.append({"joueur": r.piste, "note": r.note, "lettre": r.lettre_poste, "piste": true})
			place = true
		lignes.append(ligne)
	if not place: lignes.append({"joueur": r.piste, "note": r.note, "lettre": r.lettre_poste, "piste": true})
	# Colonnes : [titre, largeur, sorte, paramètre] (voir _cellule).
	var x0 := zone.position.x
	var y := zone.position.y
	D.rect(cadre, Rect2(x0, y, zone.size.x, 34), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	var cx := x0 + 14
	for entete: Array in [["RG", 50], ["", 52], ["NOM", 0]] + colonnes:
		var largeur := float(entete[1]) if float(entete[1]) > 0 else zone.size.x - 14 - 50 - 52 - _somme(colonnes)
		D.text(cadre, cx, y + 23, str(entete[0]), 15, Charte.IVOIRE_3, 700, largeur - 8)
		cx += largeur
	y += 40
	for i in mini(lignes.size(), max_lignes):
		var ligne: Dictionary = lignes[i]
		var joueur: Dictionary = ligne.joueur
		var est_piste := bool(ligne.get("piste", false))
		var bouton := Button.new()
		bouton.name = "RapportRecruteurLigne_%d" % i if not est_piste else "RapportRecruteurLignePiste"
		Kit.styler_ligne(bouton, Charte.PANNEAU_2 if i % 2 == 0 else Charte.PANNEAU, est_piste, Charte.SELECTION)
		cadre.add_child(bouton)
		D.place(bouton, Rect2(x0, y, zone.size.x, hauteur_ligne - 4))
		var id := str(joueur.get("id", ""))
		var kind := "market" if est_piste else "player"
		bouton.pressed.connect(func(): app.navigation_controller.open_entity({"kind": kind, "id": id}))
		load("res://ui/carte_joueur_survol.gd").lier(app, bouton, id, "market" if est_piste else "squad")
		if est_piste: Kit.marqueur(bouton, Rect2(0, 6, 6, hauteur_ligne - 16), Charte.VERT_CLAIR)
		var base := (hauteur_ligne - 4) / 2.0 + 8
		var rg := D.text(bouton, 14, base + 1, str(i + 1), 24, Charte.VERT_CLAIR if est_piste else Charte.IVOIRE_2, 800, 40)
		rg.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var visage: Control = load("res://ui/carnet_skin.gd").portrait(0, int((hauteur_ligne - 10) * C.density), joueur)
		visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bouton.add_child(visage)
		D.place(visage, Rect2(64, 3, hauteur_ligne - 10, hauteur_ligne - 10))
		var largeur_nom := zone.size.x - 14 - 50 - 52 - _somme(colonnes)
		D.text(bouton, 116, base, Kit.casse(str(joueur.get("name", "—"))), 21, Charte.VERT_CLAIR if est_piste else Charte.IVOIRE, 700 if est_piste else 600, largeur_nom - 10, HORIZONTAL_ALIGNMENT_LEFT, true)
		cx = x0 + 14 + 50 + 52 + largeur_nom - x0
		for colonne: Array in colonnes:
			if str(colonne[2]) == "familiarite":
				# Familiarité au poste du rapport : barres 5 crans + mot (« — » si le poste du joueur est inconnu).
				Familiarite.poser(bouton, cx, base, Familiarite.niveau(joueur, int(r.numero)), 17, "RapportRecruteurFamiliarite_%d" % i)
				cx += float(colonne[1])
				continue
			if str(colonne[2]) == "potentiel":
				# Notation façon FM (planche 24/11) : lettre de potentiel estimée par le staff, relative à notre effectif.
				Notation.pastille(bouton, cx, (hauteur_ligne - 4) / 2.0, int(Notation.resume(app.model, joueur, not est_piste).potentiel), 34, "RapportRecruteurLettrePot_%d" % i)
				cx += float(colonne[1])
				continue
			if str(colonne[2]) == "note":
				# Note au poste en lettre (décision de Léo du 24/11) : pastille ronde, double « B/A » si le staff n'est pas sûr.
				var lettre: Dictionary = ligne.get("lettre", {})
				Notation.pastille_note(bouton, cx, (hauteur_ligne - 4) / 2.0, lettre, 34, "RapportRecruteurLettrePoste_%d" % i)
				cx += float(colonne[1])
				continue
			var valeur: Array = _cellule(colonne, joueur, ligne, est_piste)
			var t := D.text(bouton, cx, base + 1, str(valeur[0]), 22, valeur[1], 700, float(colonne[1]) - 10)
			t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
			cx += float(colonne[1])
		for enfant in bouton.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		y += hauteur_ligne
	if lignes.size() > max_lignes:
		Kit.texte(cadre, x0 + 14, y + 26, "+%d" % (lignes.size() - max_lignes), Charte.IVOIRE_3, 100, 18)

static func _somme(colonnes: Array) -> float:
	var total := 0.0
	for c: Array in colonnes: total += float(c[1])
	return total

static func _signe(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)

static func _col_note() -> Array: return ["NOTE", 90, "note", null]
static func _col_age() -> Array: return ["ÂGE", 70, "age", null]
static func _col_potentiel() -> Array: return ["POT.", 100, "potentiel", null]
static func _col_salaire() -> Array: return ["SALAIRE", 120, "salaire", null]
static func _col_familiarite() -> Array: return ["FAMILIARITÉ", 130, "familiarite", null]

## Valeur d'une cellule : [texte, couleur].
static func _cellule(colonne: Array, j: Dictionary, l: Dictionary, p: bool) -> Array:
	match str(colonne[2]):
		"note":
			return [Notation.texte_note(l.get("lettre", {})), Charte.IVOIRE_2]
		"age":
			return [G.n(j.get("age", "—")), Charte.IVOIRE_2]
		"potentiel":
			return [K.potential_text(j), K.POTENTIAL_COLOR]
		"salaire":
			return [G.salary_amount(j.get("salary")), Pieces.BLEU]
	return ["", Charte.IVOIRE_3]

# --- Mise en page (option A de la planche) ------------------------------------------------------------------------

static func _mise_en_page(app: Control, cadre: Control, r: Dictionary) -> void:
	# Notation façon FM (choix B de Léo, 24/11) : la grande lettre est le Niveau estimé par le staff (E- à S+, relatif à
	# notre effectif) avec le palier écrit ; la tuile Potentiel donne la lettre et la phrase du staff.
	var note: Dictionary = r.notation
	_identite(app, cadre, r, 28, 24, 110)
	_lettre(app, cadre, r, Rect2(760, 22, 116, 116), 70)
	Kit.etiquette(cadre, 900, 50, "NIVEAU · AVIS n° %d / %d" % [r.rang, r.total], 300)
	Notation.poser_palier(cadre, 900, 86, note.palier, 21, 400, "RapportRecruteurPalier")
	_transfert(app, cadre, r, 900, 116)
	_connaissance(app, cadre, r, 160, 124)
	_tuiles(app, cadre, r, 1310, 28, 220, 112, false)
	_tuile_potentiel(app, cadre, r, Rect2(1310 + 232, 28, 220, 112))
	D.line(cadre, Vector2(28, 172), Vector2(LARGEUR - 28, 172), Charte.FILET)
	# Colonne 1 : qualités clés.
	_qualites(cadre, r, 28, 196, 600)
	# Colonne 2 : pour / contre.
	var y := _raisons(cadre, 680, 206, 640, "POUR", "check", Pieces.VERT, r.pour, "RapportRecruteurPour", 62, 6)
	_raisons(cadre, 680, y + 30, 640, "CONTRE", "warning", Pieces.ROUGE, r.contre, "RapportRecruteurContre", 62, 4)
	# Colonne 3 : rang chez nous.
	Kit.etiquette(cadre, 1372, 216, "NOTRE EFFECTIF · " + str(r.poste).to_upper(), 840)
	_liste(app, cadre, r, Rect2(1372, 236, 848, 740), [_col_note(), _col_familiarite(), _col_potentiel(), _col_age(), _col_salaire()], 58, 12)
