extends RefCounted
## Planche « Recherche ciblée » (revue FM27, idée 26) sous CD_VARIANTE_VISUELLE=A|B : confier au recruteur une recherche
## sur un poste du XV. Chaque clic choisit et s'applique tout de suite (aucun bouton Confirmer) ; seule action dorée :
## envoyer la mission (commande moteur `scout_mission`, 5 000 €).
## Données : postes du XV (planificateur), rôles du poste (fiche_roles.gd, table de l'écran), note au poste / 100
## (positionRatings), potentiel, âge, indemnité et salaire des pistes du marché, recruteurs du staff (rôle « scout »).
## Le moteur ne filtre aujourd'hui que famille de poste, âge maximum, indemnité et salaire : rôle, note et potentiel
## minimum, âge minimum, priorité et recruteurs affectés sont à brancher (petit ajout dans le tri du rapport).
##  A : assistant en deux étapes — 1. terrain + rôles du poste ; 2. critères en lignes, priorité, recruteurs.
##  B : une seule page — terrain et rôles à gauche, critères en pastilles en haut, pistes déjà connues qui
##      correspondent en liste façon Effectif (aperçu immédiat), priorité et recruteurs en bas.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Plan = preload("res://ui/immersive08/planificateur.gd")
const Roles = preload("res://ui/immersive08/fiche_roles.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const Liste = preload("res://ui/immersive08/liste_etoiles.gd")
const Salary = preload("res://ui/salary_display.gd")
const Visuel = preload("res://ui/immersive08/centre_visuel.gd")

const NOM := "RechercheCibleeFenetre"
const NOTES := [0, 40, 50, 60, 70, 80]
const POTENTIELS := [0, 50, 60, 70, 80, 90]
const AGES := [[18, 40, "Tous"], [18, 23, "18-23"], [21, 26, "21-26"], [24, 29, "24-29"], [27, 33, "27-33"]]
const INDEMNITES := [[0, "Libre"], [100000, "100 k€"], [400000, "400 k€"], [1000000, "1 M€"], [10000000, "Sans limite"]]
const SALAIRES := [4000, 8000, 12000, 20000, 100000]
## Priorité : [id, mot, couleur, icône].
const PRIORITES := [["prioritaire", "Prioritaire", Charte.PERTE, "warning"], ["standard", "Standard", Charte.MORAL, "search"], ["continue", "Continue", Charte.REPOS, "renew"]]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _etat(app: Control) -> Dictionary:
	if not app.management_ui.get("recherche_ciblee") is Dictionary:
		app.management_ui.recherche_ciblee = {"etape": 1, "poste": -1, "role": "", "note": 50, "pot": 0, "age": 0, "indemnite": 2, "salaire": 2, "priorite": "standard", "recruteurs": []}
	return app.management_ui.recherche_ciblee

## Ouvre la recherche sur `page` (toile du Recrutement), poste pré-choisi d'après un besoin (« Pilier », « Centre »…).
static func ouvrir(app: Control, page: Control, besoin: String = "") -> void:
	var e := _etat(app)
	if not besoin.is_empty():
		for i in Plan.POSTES.size():
			if besoin.to_lower().begins_with(str(Plan.POSTES[i].nom).to_lower().substr(0, 5)): e.poste = i
	_rendre(app, page)

static func _rendre(app: Control, page: Control) -> void:
	if variante() == "B": _page_b(app, page)
	else: _assistant_a(app, page)

static func _changer(app: Control, page: Control, cle: String, valeur: Variant) -> void:
	_etat(app)[cle] = valeur
	_rendre(app, page)

# --- Données ---------------------------------------------------------------------------------------------------------

static func _numero(e: Dictionary) -> int:
	return int(Plan.POSTES[int(e.poste)].n[0]) if int(e.poste) >= 0 else 0

static func _famille_role(e: Dictionary) -> String:
	var n := _numero(e)
	return str(Roles.FAMILLE[n - 1]) if n > 0 else ""

static func recruteurs(app: Control) -> Array:
	var club := str(app.model.get("club", {}).get("id", ""))
	var sortie: Array = []
	for equipe: Variant in app.model.get("staff", {}).get("teams", []):
		if not equipe is Dictionary or str(equipe.get("id", "")) != club: continue
		for membre: Variant in equipe.get("members", []):
			if membre is Dictionary and str(membre.get("role", "")).to_lower() in ["scout", "recruteur"]: sortie.append(membre)
	return sortie

## Pistes du marché déjà connues qui passent les critères (aperçu ; la mission cherche aussi chez les agents libres).
static func pistes(app: Control, e: Dictionary) -> Array:
	var n := _numero(e)
	var famille: int = Familiarite.FAMILLES[n - 1] if n > 0 else -1
	var age: Array = AGES[int(e.age)]
	var plafond := int(INDEMNITES[int(e.indemnite)][0])
	var salaire := int(SALAIRES[int(e.salaire)])
	var sortie: Array = []
	for p: Variant in app.model.get("market", []):
		if not p is Dictionary: continue
		if famille >= 0:
			var fam: int = -1
			for v: Variant in p.get("primaryPositions", [p.get("primaryPosition")]):
				if (v is int or v is float) and int(v) >= 1 and int(v) <= 15: fam = Familiarite.FAMILLES[int(v) - 1]
			if fam != famille: continue
		var a := int(p.get("age", 0))
		if a < int(age[0]) or a > int(age[1]): continue
		if float(p.get("fee", 0)) > plafond: continue
		if float(p.get("salary", 0)) > salaire: continue
		var note: float = Liste.note_poste(p, n) if n > 0 else Plan.note_globale(p)
		if int(e.note) > 0 and note >= 0 and note < int(e.note): continue
		var pot := Plan.potentiel(p)
		if int(e.pot) > 0 and pot >= 0 and pot < int(e.pot): continue
		sortie.append({"p": p, "note": note, "pot": pot})
	sortie.sort_custom(func(x: Dictionary, y: Dictionary): return float(x.note) > float(y.note))
	return sortie

static func _meilleur_chez_nous(app: Control, numero: int) -> float:
	var m := -1.0
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary: m = maxf(m, Liste.note_poste(p, numero))
	return m

static func _salaire(hebdo: int) -> String:
	if hebdo >= 100000: return "Sans limite"
	var v := roundi(hebdo * Salary.factor())
	return ("%d k€" % roundi(v / 1000.0)) if v >= 10000 else G.euros(v)

static func lancer(app: Control, e: Dictionary) -> void:
	var n := _numero(e)
	if n <= 0: return
	app._command("scout_mission", {"family": int(Familiarite.FAMILLES[n - 1]), "maxAge": int(AGES[int(e.age)][1]),
		"budget": int(INDEMNITES[int(e.indemnite)][0]), "maxWage": int(SALAIRES[int(e.salaire)]), "confirmed": true})

# --- Pièces communes -------------------------------------------------------------------------------------------------

## Terrain des 11 postes (paires regroupées) : carte cliquable = poste choisi ; note du meilleur de chez nous.
static func _terrain(app: Control, page: Control, fond: Control, zone: Rect2, e: Dictionary, apres: Callable) -> void:
	var pelouse := D.rect(fond, zone, Color("1e3a2a"), 12)
	pelouse.name = "RechercheTerrain"
	var ligne := Color(Charte.IVOIRE, .2)
	for f: float in [.04, .5, .96]: D.line(pelouse, Vector2(12, zone.size.y * f), Vector2(zone.size.x - 12, zone.size.y * f), ligne, 2)
	var lc := (zone.size.x - 48) / 3.0
	var hc := (zone.size.y - 30 - 3 * 18) / 4.0
	for i in Plan.POSTES.size():
		var poste: Dictionary = Plan.POSTES[i]
		var b: Vector2 = poste.b
		var r := Rect2(12 + b.x * (zone.size.x - 24 - lc), 15 + b.y * (hc + 18), lc, hc)
		var choisi := i == int(e.poste)
		var carte := D.rect(pelouse, r, Charte.IVOIRE if choisi else Color(Charte.NOIR_PANNEAU, .9), Charte.RAYON_CARTE)
		carte.name = "RecherchePoste_%d" % i
		var encre: Color = Charte.ENCRE if choisi else Charte.IVOIRE
		var sigle := D.text(carte, 14, hc * .48, str(poste.sigle), 30, encre, 800, 70)
		sigle.add_theme_font_override("font", Charte.TITRE_FICHE)
		sigle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(carte, 14, hc - 12, str(poste.nom), 15, Charte.ENCRE_2 if choisi else Charte.IVOIRE_2, 600, lc - 20).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nous := _meilleur_chez_nous(app, int(poste.n[0]))
		if nous >= 0:
			var l := Familiarite.poser_note(carte, lc - 66, hc * .48, nous, 26, 52, "RecherchePosteNous_%d" % i)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if choisi: l.add_theme_color_override("font_color", Charte.ENCRE)
		var index := i
		Pieces.rendre_cliquable(carte, r.size, func():
			e.poste = index
			e.role = ""
			apres.call(), "RecherchePosteChoisir_%d" % i, str(poste.nom), "", Charte.RAYON_CARTE)

## Rangée de pastilles d'un critère : la pastille pleine est la valeur retenue ; clic = appliquée.
static func _rangee(app: Control, page: Control, parent: Control, x: float, y: float, cle: String, valeurs: Array, mots: Array, couleur: Color, prefixe: String) -> float:
	var e := _etat(app)
	for k in valeurs.size():
		var actif: bool = e.get(cle) == valeurs[k]
		var w := Pieces.pastille(parent, x, y, str(mots[k]), "", "%s_%d" % [prefixe, k], "", Charte.ENCRE if actif else couleur, couleur if actif else Charte.PANNEAU_3)
		var valeur: Variant = valeurs[k]
		Pieces.rendre_cliquable(parent.get_node("%s_%d" % [prefixe, k]), Vector2(w, 34), func(): _changer(app, page, cle, valeur), "%sChoisir_%d" % [prefixe, k], str(mots[k]), "", Charte.RAYON_PILULE)
		x += w + 10
	return x

static func _mots_notes(liste: Array, zero: String) -> Array:
	return liste.map(func(v: int): return zero if v == 0 else "≥ %d" % v)

## Recruteurs du staff : un rond par personne (initiales), plein = affecté ; clic = affecter / retirer.
static func _recruteurs(app: Control, page: Control, parent: Control, x: float, y: float) -> void:
	var e := _etat(app)
	var gens := recruteurs(app)
	if gens.is_empty():
		Pieces.pastille(parent, x, y + 8, "Aucun recruteur", "warning", "RechercheSansRecruteur", "", Charte.INTENSIF)
		return
	for k in gens.size():
		var m: Dictionary = gens[k]
		var id := str(m.get("id", k))
		var affecte: bool = id in e.recruteurs or (e.recruteurs.is_empty() and k == 0)
		var rond := D.rect(parent, Rect2(x + k * 250, y, 50, 50), Charte.MORAL if affecte else Charte.PANNEAU_3, 999, Charte.IVOIRE if affecte else Color.TRANSPARENT)
		rond.name = "RechercheRecruteur_%d" % k
		var mots := Array(str(m.get("name", "?")).split(" ", false))
		var ini := "".join(PackedStringArray(mots.map(func(w: String): return w.substr(0, 1)))).substr(0, 2).to_upper()
		D.text(rond, 25, 33, ini, 20, Charte.ENCRE if affecte else Charte.IVOIRE_2, 800, 50, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(parent, x + k * 250 + 60, y + 22, str(m.get("name", "")), 19, Charte.IVOIRE if affecte else Charte.IVOIRE_2, 700, 180).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(parent, x + k * 250 + 60, y + 46, "Affecté" if affecte else "Libre", 15, Charte.MORAL if affecte else Charte.IVOIRE_3, 700, 180).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pieces.rendre_cliquable(rond, Vector2(50, 50), func():
			var liste: Array = e.recruteurs.duplicate()
			if id in liste: liste.erase(id)
			else: liste.append(id)
			_changer(app, page, "recruteurs", liste), "RechercheRecruteurChoisir_%d" % k, str(m.get("name", "")), "", Charte.RAYON_PILULE)

static func _bouton_lancer(app: Control, parent: Control, r: Rect2, e: Dictionary) -> void:
	var b := D.button(parent, r, "Envoyer le recruteur · 5 000 €", func():
		lancer(app, e)
		Fenetre.fermer(parent, NOM), true, "arrow", false, Charte.DORE, "RechercheLancer")
	b.disabled = int(e.poste) < 0 or not bool(app.model.get("decisions", {}).get("recruitment", {}).get("missionAvailable", true))

# --- A : assistant en deux étapes ---------------------------------------------------------------------------------

static func _assistant_a(app: Control, page: Control) -> void:
	var e := _etat(app)
	var etape := int(e.etape) if int(e.poste) >= 0 else 1
	var fond := Fenetre.ouvrir(page, NOM, "RECHERCHE CIBLÉE", "search", 1640, 1060)
	# Étapes en pastilles (clic = y revenir) et rappel du choix.
	var x := 330.0
	for k in 2:
		var mot: String = ["1  Poste et rôle", "2  Critères"][k]
		var actif := etape == k + 1
		var w := Pieces.pastille(fond, x, 26, mot, "", "RechercheEtape_%d" % (k + 1), "", Charte.ENCRE if actif else Charte.IVOIRE_2, Charte.IVOIRE if actif else Charte.PANNEAU_3)
		if k == 1 and int(e.poste) < 0: continue
		var cible := k + 1
		Pieces.rendre_cliquable(fond.get_node("RechercheEtape_%d" % (k + 1)), Vector2(w, 34), func(): _changer(app, page, "etape", cible), "RechercheEtapeOuvrir_%d" % (k + 1), mot, "", Charte.RAYON_PILULE)
		x += w + 12
	if etape == 1: _etape_1(app, page, fond, e)
	else: _etape_2(app, page, fond, e)

static func _etape_1(app: Control, page: Control, fond: Control, e: Dictionary) -> void:
	_terrain(app, page, fond, Rect2(30, 92, 700, 940), e, func(): _rendre(app, page))
	# Rôles du poste en lignes : nom, quatre qualités clés ; clic = rôle choisi, étape 2 tout de suite.
	var panneau := D.rect(fond, Rect2(760, 92, 850, 940), Color(Charte.PANNEAU_3, .45), Charte.RAYON_CARTE)
	panneau.name = "RechercheRoles"
	if int(e.poste) < 0:
		var ic := C.icon("search", 80, Charte.IVOIRE_3)
		panneau.add_child(ic)
		D.place(ic, Rect2(385, 400, 80, 80))
		return
	var poste: Dictionary = Plan.POSTES[int(e.poste)]
	var titre := D.text(panneau, 30, 62, str(poste.nom).to_upper(), 40, Charte.IVOIRE, 800, 600)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var marche := pistes(app, {"poste": e.poste, "note": 0, "pot": 0, "age": 0, "indemnite": 4, "salaire": 4})
	Pieces.pastille(panneau, 600, 30, "%d pistes" % marche.size(), "search", "RecherchePistesPoste", "", Charte.MORAL)
	var roles: Array = [["", "", "Tous les rôles", [], []]] + Roles.roles_famille(_famille_role(e))
	for k in roles.size():
		var r: Array = roles[k]
		var y := 100.0 + k * 150.0
		var choisi: bool = str(e.role) == str(r[0])
		var ligne := D.rect(panneau, Rect2(16, y, 818, 138), Color(Charte.IVOIRE, .08) if choisi else (Color(Charte.IVOIRE, .03) if k % 2 == 1 else Color.TRANSPARENT), Charte.RAYON_PETIT, Charte.IVOIRE if choisi else Color.TRANSPARENT)
		ligne.name = "RechercheRole_%d" % k
		var nom := D.text(ligne, 24, 46, str(r[2]).to_upper(), 30, Charte.IVOIRE, 800, 600)
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var xq := 24.0
		for q: String in r[3]:
			xq += Pieces.pastille(ligne, xq, 74, Roles.libelle(q), "", "", "", Roles.CLE) + 8
		if r[3].is_empty(): Pieces.pastille(ligne, 24, 74, str(poste.sigle), "", "RechercheRoleLibre", "", Charte.IVOIRE_2)
		var id := str(r[0])
		Pieces.rendre_cliquable(ligne, Vector2(818, 138), func():
			e.role = id
			e.etape = 2
			_rendre(app, page), "RechercheRoleChoisir_%d" % k, str(r[2]), "", Charte.RAYON_PETIT)

static func _etape_2(app: Control, page: Control, fond: Control, e: Dictionary) -> void:
	var poste: Dictionary = Plan.POSTES[int(e.poste)]
	var role_nom := "Tous les rôles"
	if not str(e.role).is_empty(): role_nom = str(Roles.role(str(e.role))[2])
	# Rappel : poste · rôle (clic = étape 1).
	var rappel := D.rect(fond, Rect2(30, 92, 1580, 90), Charte.IVOIRE, Charte.RAYON_CARTE)
	rappel.name = "RechercheRappel"
	var t := D.text(rappel, 30, 60, "%s  ·  %s" % [str(poste.nom).to_upper(), role_nom.to_upper()], 38, Charte.ENCRE, 800, 1100)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nous := _meilleur_chez_nous(app, int(poste.n[0]))
	if nous >= 0:
		D.text(rappel, 1300, 56, "Chez nous", 18, Charte.ENCRE_2, 700, 140).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Familiarite.poser_note(rappel, 1450, 60, nous, 36, 80, "RechercheRappelNous").mouse_filter = Control.MOUSE_FILTER_IGNORE
	Pieces.rendre_cliquable(rappel, Vector2(1580, 90), func(): _changer(app, page, "etape", 1), "RechercheRappelOuvrir", "Poste et rôle", "", Charte.RAYON_CARTE)
	# Critères en lignes (libellé à gauche, pastilles à droite), une rayure sur deux.
	var lignes := [
		["NOTE AU POSTE", "note", NOTES, _mots_notes(NOTES, "Toutes"), Charte.ATTRIBUT_65],
		["POTENTIEL", "pot", POTENTIELS, _mots_notes(POTENTIELS, "Tous"), Charte.CONFIANCE],
		["ÂGE", "age", range(AGES.size()), AGES.map(func(a: Array): return str(a[2])), Charte.MORAL],
		["INDEMNITÉ MAX.", "indemnite", range(INDEMNITES.size()), INDEMNITES.map(func(a: Array): return str(a[1])), Charte.INTENSIF],
		["SALAIRE MAX. " + G.salary_period(true).to_upper(), "salaire", range(SALAIRES.size()), SALAIRES.map(func(v: int): return _salaire(v)), Charte.INTENSIF],
		["PRIORITÉ", "priorite", PRIORITES.map(func(p: Array): return p[0]), PRIORITES.map(func(p: Array): return p[1]), Charte.MORAL],
	]
	for k in lignes.size():
		var l: Array = lignes[k]
		var y := 200.0 + k * 84.0
		if k % 2 == 0: D.rect(fond, Rect2(30, y, 1580, 76), Color(Charte.IVOIRE, .035), Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(fond, 54, y + 46, str(l[0]), 20, Charte.IVOIRE_2, 700, 380)
		if l[1] == "priorite":
			var x := 440.0
			for p: Array in PRIORITES:
				var actif: bool = str(e.priorite) == str(p[0])
				var w := Pieces.pastille(fond, x, y + 21, str(p[1]), str(p[3]), "RecherchePriorite_" + str(p[0]), "", Charte.ENCRE if actif else p[2], p[2] if actif else Charte.PANNEAU_3)
				var id := str(p[0])
				Pieces.rendre_cliquable(fond.get_node("RecherchePriorite_" + id), Vector2(w, 34), func(): _changer(app, page, "priorite", id), "RecherchePrioriteChoisir_" + id, str(p[1]), "", Charte.RAYON_PILULE)
				x += w + 10
		else: _rangee(app, page, fond, 440, y + 21, str(l[1]), l[2], l[3], l[4], "RechercheCritere_" + str(l[1]))
	# Lieux de recherche : agents libres (ce que le moteur fouille aujourd'hui).
	var y_lieu := 200.0 + lignes.size() * 84.0
	D.text(fond, 54, y_lieu + 46, "OÙ CHERCHER", 20, Charte.IVOIRE_2, 700, 380)
	Pieces.pastille(fond, 440, y_lieu + 21, "Agents libres", "people", "RechercheLieu", "", Charte.ENCRE, Charte.GAIN)
	# Recruteurs affectés.
	var y_rec := y_lieu + 96.0
	D.text(fond, 54, y_rec + 34, "RECRUTEURS", 20, Charte.IVOIRE_2, 700, 380)
	_recruteurs(app, page, fond, 440, y_rec + 4)
	# Pied : pistes déjà connues qui passent (gros chiffre, clic = étape 1 n'a pas de sens : neutre), action dorée.
	var n := pistes(app, e).size()
	var tuile := D.rect(fond, Rect2(30, 940, 420, 96), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	tuile.name = "RecherchePistesTuile"
	D.text(tuile, 24, 30, "PISTES DÉJÀ CONNUES", 15, Charte.IVOIRE_3, 700, 380)
	var chiffre := D.text(tuile, 24, 80, str(n), 44, Charte.MORAL, 800, 120)
	chiffre.add_theme_font_override("font", Charte.TITRE_FICHE)
	_bouton_lancer(app, fond, Rect2(1130, 960, 480, 64), e)

# --- B : une page, aperçu des pistes ------------------------------------------------------------------------------

static func _page_b(app: Control, page: Control) -> void:
	var e := _etat(app)
	var fond := Fenetre.ouvrir(page, NOM, "RECHERCHE CIBLÉE", "search", 2120, 1110)
	_terrain(app, page, fond, Rect2(30, 92, 560, 760), e, func(): _rendre(app, page))
	# Rôles du poste en pastilles sous le terrain (clic = choisi).
	var roles: Array = [["", "", "Tous les rôles"]]
	if int(e.poste) >= 0: roles += Roles.roles_famille(_famille_role(e))
	for k in roles.size():
		var r: Array = roles[k]
		var actif: bool = str(e.role) == str(r[0])
		var y := 870.0 + k * 46.0
		var w := Pieces.pastille(fond, 30, y, str(r[2]), "tactic" if not str(r[0]).is_empty() else "", "RechercheRole_%d" % k, "", Charte.ENCRE if actif else Charte.IVOIRE, Charte.IVOIRE if actif else Charte.PANNEAU_3)
		var id := str(r[0])
		Pieces.rendre_cliquable(fond.get_node("RechercheRole_%d" % k), Vector2(w, 34), func(): _changer(app, page, "role", id), "RechercheRoleChoisir_%d" % k, str(r[2]), "", Charte.RAYON_PILULE)
	# Critères : une rangée de pastilles par critère, libellé court devant.
	var criteres := [
		["NOTE", "note", NOTES, _mots_notes(NOTES, "Toutes"), Charte.ATTRIBUT_65],
		["POTENTIEL", "pot", POTENTIELS, _mots_notes(POTENTIELS, "Tous"), Charte.CONFIANCE],
		["ÂGE", "age", range(AGES.size()), AGES.map(func(a: Array): return str(a[2])), Charte.MORAL],
		["INDEMNITÉ", "indemnite", range(INDEMNITES.size()), INDEMNITES.map(func(a: Array): return str(a[1])), Charte.INTENSIF],
	]
	for k in criteres.size():
		var c: Array = criteres[k]
		var x := 620.0 + (k % 2) * 750.0
		var y := 92.0 + (k / 2) * 50.0
		D.text(fond, x, y + 24, str(c[0]), 16, Charte.IVOIRE_3, 700, 120)
		_rangee(app, page, fond, x + 124, y, str(c[1]), c[2], c[3], c[4], "RechercheCritere_" + str(c[1]))
	# Liste des pistes connues qui passent, façon Effectif : visage, nom, âge, note au poste + familiarité, potentiel,
	# indemnité, salaire. Clic sur le nom = sa fiche.
	var liste := D.rect(fond, Rect2(620, 200, 1470, 720), Color(Charte.PANNEAU_3, .35), Charte.RAYON_CARTE)
	liste.name = "RecherchePistes"
	D.rect(liste, Rect2(0, 0, 1470, 44), Charte.BANDEAU_ENTETE, Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := [["JOUEUR", 70.0], ["ÂGE", 520.0], ["NOTE AU POSTE", 620.0], ["POT.", 900.0], ["INDEMNITÉ", 1010.0], ["SALAIRE", 1220.0]]
	for col: Array in cols: D.text(liste, float(col[1]), 29, str(col[0]), 15, Charte.IVOIRE_3, 700, 200)
	var trouves := pistes(app, e)
	var n := _numero(e)
	var h := 48.0
	for i in mini(trouves.size(), 13):
		var t: Dictionary = trouves[i]
		var p: Dictionary = t.p
		var y := 50.0 + i * h
		var ligne := D.rect(liste, Rect2(6, y, 1458, h - 2), Color(Charte.IVOIRE, .035) if i % 2 == 1 else Color.TRANSPARENT, Charte.RAYON_PETIT)
		ligne.name = "RecherchePiste_%d" % i
		Visuel.portrait(ligne, Rect2(14, 6, 36, 36), p)
		D.text(ligne, 64, 31, str(p.get("name", "")), 20, Charte.IVOIRE, 700, 380)
		D.text(ligne, 514, 31, str(int(p.get("age", 0))), 20, Charte.IVOIRE_2, 700, 60)
		if n > 0:
			Familiarite.poser_note(ligne, 614, 32, float(t.note), 24, 50, "RecherchePisteNote_%d" % i)
			Familiarite.poser_barres(ligne, 680, 32, Familiarite.niveau(p, n), 20, "RecherchePisteFam_%d" % i)
		var pot := float(t.pot)
		D.text(ligne, 894, 31, str(int(pot)) if pot >= 0 else "?", 20, Charte.couleur_attribut(pot) if pot >= 0 else Charte.IVOIRE_3, 800, 80)
		D.text(ligne, 1004, 31, load("res://ui/offre_guidee.gd").court(int(p.get("fee", 0))), 20, Charte.INTENSIF, 700, 180)
		D.text(ligne, 1214, 31, Salary.amount(p.get("salary", 0)), 20, Charte.IVOIRE_2, 700, 220)
		var id := str(p.get("id", ""))
		Pieces.rendre_cliquable(ligne, Vector2(1458, h - 2), func():
			app.selected_player = id
			app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""}), "RecherchePisteOuvrir_%d" % i, str(p.get("name", "")), "", Charte.RAYON_PETIT)
	if trouves.is_empty():
		Pieces.pastille(liste, 40, 80, "0 piste connue", "search", "RechercheAucune", "", Charte.IVOIRE_2)
	# Pied : priorité, recruteurs, action dorée.
	var x := 620.0
	for p: Array in PRIORITES:
		var actif: bool = str(e.priorite) == str(p[0])
		var w := Pieces.pastille(fond, x, 958, str(p[1]), str(p[3]), "RecherchePriorite_" + str(p[0]), "", Charte.ENCRE if actif else p[2], p[2] if actif else Charte.PANNEAU_3)
		var id := str(p[0])
		Pieces.rendre_cliquable(fond.get_node("RecherchePriorite_" + id), Vector2(w, 34), func(): _changer(app, page, "priorite", id), "RecherchePrioriteChoisir_" + id, str(p[1]), "", Charte.RAYON_PILULE)
		x += w + 10
	_recruteurs(app, page, fond, x + 30, 950)
	Pieces.pastille(fond, 620, 1010, "%d pistes connues" % trouves.size(), "search", "RecherchePistesCompte", "", Charte.MORAL)
	_bouton_lancer(app, fond, Rect2(1610, 1000, 480, 64), e)
