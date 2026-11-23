extends RefCounted
## Onglet Blessures de la fiche joueur (revue FM27, idée 36 ; choix de Léo du 23/11/2026) : toutes les blessures du
## joueur, en cours et passées, en liste façon Effectif (date, zone sur le corps, blessure, durée, origine, état), avec
## le dernier test de reprise s'il en a passé un. Données du moteur : clubLife.testsPhysiques.historique[id]
## (native/engine/tests-physiques.cjs), de la plus récente à la plus ancienne.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Blessure = preload("res://ui/immersive08/fenetre_blessure.gd")
const Tests = preload("res://ui/immersive08/tests_physiques.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const LIGNE := 92.0
const MAX_LIGNES := 9
const CAUSES := {"match": ["Match", R.BLEU, "ball"], "entrainement": ["Entraînement", R.ORANGE, "train"], "rechute": ["Rechute", R.VIOLET, "renew"]}

static func historique(model: Dictionary, id: String) -> Array:
	var t: Variant = model.get("clubLife", {}).get("testsPhysiques", {})
	if not t is Dictionary or not t.get("historique") is Dictionary: return []
	var h: Variant = t.historique.get(id)
	return h if h is Array else []

static func _date(iso: String) -> String:
	return "%s/%s/%s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(0, 4)] if iso.length() >= 10 else "?"

static func _zone(type: String, droite: bool) -> String:
	var zone: Dictionary = Blessure.ZONES.get(type, {})
	var mot := str(zone.get("mot", ""))
	if mot.is_empty(): return "—"
	if not bool(zone.get("cote", false)): return mot
	var masculin := mot in ["Genou", "Mollet", "Ischios"]
	return mot + (" droit" if masculin else " droite") if droite else mot + " gauche"

static func construire(card: Panel, app: Control, player: Dictionary) -> void:
	var id := str(player.get("id", ""))
	var h := historique(app.model, id)
	var droite := hash(id + ":cote") % 2 == 0
	var en_cours := h.filter(func(e: Variant) -> bool: return e is Dictionary and bool(e.get("enCours", false))).size()
	var x := 330.0
	R.pastille(card, x, 50, "%d blessure%s" % [h.size(), "s" if h.size() > 1 else ""], Charte.IVOIRE_2, "heart", "FicheBlessuresTotal", 20)
	if en_cours > 0: R.pastille(card, x + 190, 50, "%d en cours" % en_cours, R.ROUGE, "warning", "FicheBlessuresEnCours", 20)
	var cols := [[24, "DATE"], [230, "ZONE"], [520, "BLESSURE"], [960, "DURÉE"], [1130, "ORIGINE"], [1370, "ÉTAT"]]
	D.rect(card, Rect2(16, 84, 1638, 42), Charte.BANDEAU_ENTETE, 6)
	for col: Array in cols: D.text(card, float(col[0]), 112, str(col[1]), 17, Charte.IVOIRE_3, 700, 300)
	if h.is_empty():
		D.text(card, 24, 190, "Aucune blessure", 26, Charte.IVOIRE_2, 600, 600).name = "FicheBlessuresVide"
		return
	var y := 134.0
	var i := 0
	for e: Variant in h.slice(0, MAX_LIGNES):
		if not e is Dictionary: continue
		i += 1
		var ligne := Control.new()
		ligne.name = "FicheBlessuresLigne%d" % i
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ligne)
		D.place(ligne, Rect2(16, y, 1638, LIGNE))
		if i % 2 == 0: D.rect(ligne, Rect2(0, 0, 1638, LIGNE), Charte.PANNEAU_2, 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var type := str(e.get("type", "")) if e.get("type") is String else ""
		var actif := bool(e.get("enCours", false))
		D.text(ligne, 8, 54, _date(str(e.get("date", ""))), 22, Charte.IVOIRE, 700, 200).name = "FicheBlessuresDate%d" % i
		Tests.corps(ligne, Rect2(214, 6, 70, LIGNE - 12), type, droite, "FicheBlessuresCorps%d" % i)
		D.text(ligne, 300, 54, _zone(type, droite), 22, Charte.IVOIRE, 600, 200).name = "FicheBlessuresZone%d" % i
		var libelle := ClubMail.injury_label(app.model, {"injuryType": type}) if not type.is_empty() else "Blessure"
		D.text(ligne, 504, 54, libelle, 22, R.ROUGE if actif else Charte.IVOIRE, 700, 430).name = "FicheBlessuresType%d" % i
		var semaines := int(Tests._n(e.get("semaines"), 1.0))
		D.text(ligne, 944, 54, "%d sem." % semaines, 24, R.ORANGE if semaines >= 4 else Charte.IVOIRE, 700, 160).name = "FicheBlessuresDuree%d" % i
		var cause: Array = CAUSES.get(str(e.get("cause", "")), [])
		if not cause.is_empty(): R.pastille(ligne, 1114, 54, str(cause[0]), cause[1], cause[2], "FicheBlessuresOrigine%d" % i, 19)
		if actif: R.pastille(ligne, 1354, 54, "En cours", R.ROUGE, "warning", "FicheBlessuresEtat%d" % i, 19)
		else: R.pastille(ligne, 1354, 54, "Guéri · " + _date(str(e.get("fin", ""))).substr(0, 5), R.VERT, "check", "FicheBlessuresEtat%d" % i, 19)
		D.line(ligne, Vector2(0, LIGNE - 1), Vector2(1638, LIGNE - 1), Charte.FILET, 1)
		y += LIGNE
	if h.size() > MAX_LIGNES: D.text(card, 24, y + 34, "+ %d" % (h.size() - MAX_LIGNES), 20, Charte.IVOIRE_2, 600, 200)

## Dernier test de reprise du joueur pour la prochaine rencontre (résultat, minutes conseillées), sinon rien.
static func test_reprise(card: Panel, app: Control, player: Dictionary) -> bool:
	var id := str(player.get("id", ""))
	for c: Dictionary in Tests.lignes(app.model):
		if str(c.j.get("id", "")) != id: continue
		var res: Array = Tests.RESULTATS[bool(c.ok)]
		var tests := Tests.donnees(app.model)
		var adv := str(tests.get("adversaire", "")) if tests.get("adversaire") is String else ""
		D.text(card, 24, 104, adv, 22, Charte.IVOIRE_2, 600, 500).name = "FicheBlessuresTestAdversaire"
		R.pastille(card, 24, 160, str(res[0]), res[1], res[2], "FicheBlessuresTestResultat", 24)
		Tests.barre_minutes(card, 24.0, 210.0, 300.0, int(c.minutes), "FicheBlessuresTestMinutes")
		return true
	return false
