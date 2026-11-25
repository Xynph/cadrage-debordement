extends RefCounted
## Recherche ciblée (revue FM27, idée 26 ; option B choisie par Léo le 23/11/2026) : une seule page pour confier au
## recruteur une recherche sur un poste du XV. Terrain des postes + rôles du poste à gauche, critères en pastilles en
## haut, liste des joueurs DÉJÀ OBSERVÉS qui collent (filtrée en direct, estimations du recruteur en lettres E- à S+ : note
## au poste + familiarité, note du rôle, potentiel ; jamais de chiffre, décision de Léo du 24/11), priorité et recruteurs en bas. Chaque clic choisit et s'applique tout de suite
## (aucun bouton Confirmer) ; seule action payante : « Envoyer le recruteur · 5 000 € » (commande `scout_mission` avec
## les critères : le moteur cherche ensuite chez les libres et dans les autres clubs, puis repropose les profils connus
## et de nouveaux joueurs, qui deviennent observés). Données : clubLife.rechercheCiblee (native/engine/recherche-ciblee.cjs).
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
const Notation = preload("res://ui/notation_staff.gd")

const NOM := "RechercheCibleeFenetre"
## Seuils de note au poste et de potentiel en lettres (indices de Notation.LETTRES ; -1 = tous) : D, C, B, A, S.
const SEUILS := [-1, 4, 7, 10, 13, 16]
const AGES := [[18, 40, "Tous"], [18, 23, "18-23"], [21, 26, "21-26"], [24, 29, "24-29"], [27, 33, "27-33"]]
const INDEMNITES := [[0, "Libre"], [100000, "100 k€"], [400000, "400 k€"], [1000000, "1 M€"], [10000000, "Sans limite"]]
const LIGNES := 13
## Priorité : [id, mot, couleur, icône].
const PRIORITES := [["prioritaire", "Prioritaire", Charte.PERTE, "warning"], ["standard", "Standard", Charte.MORAL, "search"], ["continue", "Continue", Charte.REPOS, "renew"]]

static func _etat(app: Control) -> Dictionary:
	if not app.management_ui.get("recherche_ciblee") is Dictionary:
		app.management_ui.recherche_ciblee = {"poste": -1, "role": "", "note_l": 4, "pot_l": -1, "age": 0, "indemnite": 2, "priorite": "standard", "recruteurs": []}
	return app.management_ui.recherche_ciblee

static func _donnees(app: Control) -> Dictionary:
	var d: Variant = app.model.get("clubLife", {}).get("rechercheCiblee")
	return d if d is Dictionary else {}

## Ouvre la recherche sur `page` (toile du Recrutement), poste pré-choisi d'après un besoin (« Pilier », « Centre »…).
static func ouvrir(app: Control, page: Control, besoin: String = "") -> void:
	var e := _etat(app)
	if not besoin.is_empty():
		for i in Plan.POSTES.size():
			if besoin.to_lower().begins_with(str(Plan.POSTES[i].nom).to_lower().substr(0, 5)): e.poste = i
	e.ouverte = true
	_rendre(app, page)

## Écran du Recrutement reconstruit (réponse du moteur, retour depuis une fiche) : la recherche restée ouverte revient.
static func rouvrir(app: Control, page: Control) -> void:
	var e: Variant = app.management_ui.get("recherche_ciblee")
	if e is Dictionary and bool(e.get("ouverte", false)): _rendre(app, page)

static func _changer(app: Control, page: Control, cle: String, valeur: Variant) -> void:
	_etat(app)[cle] = valeur
	_rendre(app, page)

# --- Données ---------------------------------------------------------------------------------------------------------

static func _numero(e: Dictionary) -> int:
	return int(Plan.POSTES[int(e.poste)].n[0]) if int(e.poste) >= 0 else 0

static func _famille_role(e: Dictionary) -> String:
	var n := _numero(e)
	return str(Roles.FAMILLE[n - 1]) if n > 0 else ""

## Recruteurs du club : ceux du moteur (staff de carrière), sinon ceux du staff affiché. [{id, nom}]
static func recruteurs(app: Control) -> Array:
	var moteur: Variant = _donnees(app).get("recruteurs")
	if moteur is Array: return (moteur as Array).map(func(m: Dictionary): return {"id": str(m.get("id", "")), "nom": str(m.get("nom", ""))})
	var club := str(app.model.get("club", {}).get("id", ""))
	var sortie: Array = []
	for equipe: Variant in app.model.get("staff", {}).get("teams", []):
		if not equipe is Dictionary or str(equipe.get("id", "")) != club: continue
		for membre: Variant in equipe.get("members", []):
			if membre is Dictionary and str(membre.get("role", "")).to_lower() in ["scout", "recruteur"]: sortie.append({"id": str(membre.get("id", "")), "nom": str(membre.get("name", ""))})
	return sortie

static func _affectes(app: Control, e: Dictionary) -> Array:
	var gens := recruteurs(app)
	var ids: Array = gens.map(func(m: Dictionary): return str(m.id))
	var choisis: Array = (e.recruteurs as Array).filter(func(id: String): return id in ids)
	if choisis.is_empty() and not ids.is_empty(): choisis = [ids[0]]
	return choisis

## Estimation du recruteur pour un joueur observé : [note au poste, familiarité, maillot] au maillot n (meilleur poste
## si n = 0).
static func _note(x: Dictionary, n: int) -> Array:
	var postes: Dictionary = x.get("estime", {}).get("postes", {})
	var fam: Array = x.get("familiarite", [])
	if n > 0: return [float(postes.get(str(n), -1)), int(fam[n - 1]) if fam.size() == 15 else -1, n]
	var meilleur := [-1.0, -1, 0]
	for k: String in postes:
		if float(postes[k]) > float(meilleur[0]): meilleur = [float(postes[k]), int(fam[int(k) - 1]) if fam.size() == 15 else -1, int(k)]
	return meilleur

## Valeur cachée minimale qui donne au moins la lettre `i` (moteur : minNote, minPotential) ; 0 = pas de seuil.
static func _seuil(app: Control, i: int) -> int:
	if i < 0: return 0
	return maxi(0, floori(Notation.reference_effectif(app.model) + (float(i - Notation.REFERENCE) - 0.5) * Notation.PAS))

## Joueurs déjà observés qui passent les critères, filtrés en direct (rôle choisi : classés par la note du rôle).
static func pistes(app: Control, e: Dictionary) -> Array:
	var n := _numero(e)
	var age: Array = AGES[int(e.age)]
	var plafond := int(INDEMNITES[int(e.indemnite)][0])
	var role := str(e.role)
	var sortie: Array = []
	for x: Variant in _donnees(app).get("connus", []):
		if not x is Dictionary: continue
		var na := _note(x, n)
		if float(na[0]) < 0.0: continue
		var a := int(x.get("age", 0))
		if a < int(age[0]) or a > int(age[1]): continue
		if float(x.get("indemnite", 0)) > plafond: continue
		# Lettres du staff (même échelle que le Niveau) : les seuils portent sur la lettre montrée, jamais sur un chiffre.
		var lettre := Notation.lettre_note(app.model, x, float(na[0]), false, Notation.cle_poste(int(na[2])), int(na[1]) if int(na[1]) >= 0 else Familiarite.NATUREL)
		if int(e.get("note_l", -1)) >= 0 and Notation.rang_lettre(lettre) < int(e.get("note_l", -1)): continue
		var pot := float(x.get("estime", {}).get("potentiel", -1))
		var lettre_pot: Dictionary = Notation.lettre_note(app.model, x, pot, false, "pot") if pot >= 0.0 else {"bas": -1, "haut": -1}
		if int(e.get("pot_l", -1)) >= 0 and Notation.rang_lettre(lettre_pot) < int(e.get("pot_l", -1)): continue
		var nr := float(x.get("estime", {}).get("roles", {}).get(role, -1)) if not role.is_empty() else -1.0
		var lettre_role: Dictionary = Notation.lettre_note(app.model, x, nr, false, "role:" + role) if nr >= 0.0 else {"bas": -1, "haut": -1}
		sortie.append({"x": x, "note": float(na[0]), "lettre": lettre, "fam": int(na[1]), "pot": pot, "lettre_pot": lettre_pot, "role": nr, "lettre_role": lettre_role,
			"tri": nr * .6 + float(na[0]) * .4 if nr >= 0.0 else float(na[0])})
	sortie.sort_custom(func(p: Dictionary, q: Dictionary): return float(p.tri) > float(q.tri))
	return sortie

## Notre meilleur joueur au poste (valeur cachée pour le choisir seulement) : sa lettre au poste ; {} si aucun connu.
static func _meilleur_chez_nous(app: Control, numero: int) -> Dictionary:
	var m := -1.0
	var meilleur: Dictionary = {}
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and Liste.note_poste(p, numero) > m:
			m = Liste.note_poste(p, numero)
			meilleur = p
	return Notation.lettre_poste(app.model, meilleur, numero, true) if not meilleur.is_empty() else {}

static func _argent(montant: int) -> String:
	if montant >= 1000000: return ("%.1f M€" % (montant / 1000000.0)).replace(".", ",")
	if montant >= 10000: return "%d k€" % roundi(montant / 1000.0)
	return G.euros(montant)

static func lancer(app: Control, e: Dictionary) -> bool:
	var n := _numero(e)
	if n <= 0: return false
	var age: Array = AGES[int(e.age)]
	return app._command("scout_mission", {"family": int(Familiarite.FAMILLES[n - 1]), "maxAge": int(age[1]), "budget": int(INDEMNITES[int(e.indemnite)][0]),
		"maxWage": 100000, "confirmed": true, "position": n, "role": str(e.role), "minNote": _seuil(app, int(e.get("note_l", -1))), "minPotential": _seuil(app, int(e.get("pot_l", -1))),
		"minAge": int(age[0]), "priority": str(e.priorite), "scouts": _affectes(app, e)})

# --- Page --------------------------------------------------------------------------------------------------------------

static func _rendre(app: Control, page: Control) -> void:
	var e := _etat(app)
	var fond := Fenetre.ouvrir(page, NOM, "RECHERCHE CIBLÉE", "search", 2120, 1110, func(): e.ouverte = false)
	_terrain(app, page, fond, Rect2(30, 92, 560, 760), e)
	_roles(app, page, fond, e)
	_criteres(app, page, fond)
	_liste(app, fond, e)
	_pied(app, page, fond, e)

## Terrain des 11 postes (paires regroupées) : carte cliquable = poste choisi ; note du meilleur de chez nous.
static func _terrain(app: Control, page: Control, fond: Control, zone: Rect2, e: Dictionary) -> void:
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
		if Notation.rang_lettre(nous) >= 0.0:
			Familiarite.poser_note(carte, lc - 66, hc * .48, nous, 26, 52, "RecherchePosteNous_%d" % i).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index := i
		Pieces.rendre_cliquable(carte, r.size, func():
			e.poste = index
			e.role = ""
			_rendre(app, page), "RecherchePosteChoisir_%d" % i, str(poste.nom), "", Charte.RAYON_CARTE)

## Rôles du poste en pastilles sous le terrain (clic = choisi).
static func _roles(app: Control, page: Control, fond: Control, e: Dictionary) -> void:
	var roles: Array = [["", "", "Tous les rôles"]]
	if int(e.poste) >= 0: roles += Roles.roles_famille(_famille_role(e))
	for k in roles.size():
		var r: Array = roles[k]
		var actif: bool = str(e.role) == str(r[0])
		var w := Pieces.pastille(fond, 30, 870.0 + k * 46.0, str(r[2]), "tactic" if not str(r[0]).is_empty() else "", "RechercheRole_%d" % k, "", Charte.ENCRE if actif else Charte.IVOIRE, Charte.IVOIRE if actif else Charte.PANNEAU_3)
		var id := str(r[0])
		Pieces.rendre_cliquable(fond.get_node("RechercheRole_%d" % k), Vector2(w, 34), func(): _changer(app, page, "role", id), "RechercheRoleChoisir_%d" % k, str(r[2]), "", Charte.RAYON_PILULE)

## Rangée de pastilles d'un critère : la pastille pleine est la valeur retenue ; clic = appliquée.
static func _rangee(app: Control, page: Control, parent: Control, x: float, y: float, cle: String, valeurs: Array, mots: Array, couleur: Color, prefixe: String) -> float:
	var e := _etat(app)
	for k in valeurs.size():
		var actif: bool = e.get(cle, -1) == valeurs[k]
		var w := Pieces.pastille(parent, x, y, str(mots[k]), "", "%s_%d" % [prefixe, k], "", Charte.ENCRE if actif else couleur, couleur if actif else Charte.PANNEAU_3)
		var valeur: Variant = valeurs[k]
		Pieces.rendre_cliquable(parent.get_node("%s_%d" % [prefixe, k]), Vector2(w, 34), func(): _changer(app, page, cle, valeur), "%sChoisir_%d" % [prefixe, k], str(mots[k]), "", Charte.RAYON_PILULE)
		x += w + 10
	return x

static func _mots_notes(liste: Array, zero: String) -> Array:
	return liste.map(func(v: int): return zero if v < 0 else "≥ " + Notation.texte_lettre(v))

## Critères en pastilles, deux par rangée.
static func _criteres(app: Control, page: Control, fond: Control) -> void:
	var criteres := [
		["NOTE", "note_l", SEUILS, _mots_notes(SEUILS, "Toutes"), Charte.ATTRIBUT_65],
		["POTENTIEL", "pot_l", SEUILS, _mots_notes(SEUILS, "Tous"), Charte.CONFIANCE],
		["ÂGE", "age", range(AGES.size()), AGES.map(func(a: Array): return str(a[2])), Charte.MORAL],
		["INDEMNITÉ", "indemnite", range(INDEMNITES.size()), INDEMNITES.map(func(a: Array): return str(a[1])), Charte.INTENSIF],
	]
	for k in criteres.size():
		var c: Array = criteres[k]
		var x := 620.0 + (k % 2) * 750.0
		var y := 92.0 + (k / 2) * 50.0
		D.text(fond, x, y + 24, str(c[0]), 16, Charte.IVOIRE_3, 700, 120)
		_rangee(app, page, fond, x + 124, y, str(c[1]), c[2], c[3], c[4], "RechercheCritere_" + str(c[1]))

## Liste des joueurs déjà observés qui passent, façon Effectif : visage, nom, club (Libre en vert), âge, note au poste +
## familiarité, note du rôle choisi, potentiel, indemnité, salaire. Clic sur la ligne = sa fiche.
static func _liste(app: Control, fond: Control, e: Dictionary) -> void:
	var liste := D.rect(fond, Rect2(620, 200, 1470, 720), Color(Charte.PANNEAU_3, .35), Charte.RAYON_CARTE)
	liste.name = "RecherchePistes"
	D.rect(liste, Rect2(0, 0, 1470, 44), Charte.BANDEAU_ENTETE, Charte.RAYON_CARTE).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var role := str(e.role)
	var cols := [["JOUEUR", 70.0], ["CLUB", 420.0], ["ÂGE", 640.0], ["NOTE AU POSTE", 720.0], ["RÔLE", 980.0], ["POT.", 1070.0], ["INDEMNITÉ", 1160.0], ["SALAIRE", 1300.0]]
	for col: Array in cols:
		if str(col[0]) == "RÔLE" and role.is_empty(): continue
		D.text(liste, float(col[1]), 29, str(col[0]), 15, Charte.IVOIRE_3, 700, 200)
	var trouves := pistes(app, e)
	var h := 50.0
	for i in mini(trouves.size(), LIGNES):
		var t: Dictionary = trouves[i]
		var x: Dictionary = t.x
		var y := 50.0 + i * h
		var ligne := D.rect(liste, Rect2(6, y, 1458, h - 2), Color(Charte.IVOIRE, .035) if i % 2 == 1 else Color.TRANSPARENT, Charte.RAYON_PETIT)
		ligne.name = "RecherchePiste_%d" % i
		Visuel.portrait(ligne, Rect2(14, 7, 36, 36), {"id": x.get("id", ""), "name": x.get("nom", ""), "age": x.get("age", 0)})
		D.text(ligne, 64, 32, str(x.get("nom", "")), 20, Charte.IVOIRE, 700, 340)
		var club: Variant = x.get("club")
		if club is Dictionary: D.text(ligne, 414, 32, str(club.get("nom", "")), 18, Charte.IVOIRE_2, 600, 210)
		else: Pieces.pastille(ligne, 414, 7, "Libre", "", "RecherchePisteLibre_%d" % i, "", Charte.GAIN)
		D.text(ligne, 634, 32, str(int(x.get("age", 0))), 20, Charte.IVOIRE_2, 700, 60)
		Familiarite.poser_note(ligne, 714, 33, t.lettre, 24, 50, "RecherchePisteNote_%d" % i)
		Familiarite.poser(ligne, 780, 32, int(t.fam), 18, "RecherchePisteFam_%d" % i)
		if not role.is_empty() and Notation.rang_lettre(t.lettre_role) >= 0.0:
			Notation.pastille_note(ligne, 974, (h - 2) / 2.0, t.lettre_role, 32, "RecherchePisteRole_%d" % i)
		if Notation.rang_lettre(t.lettre_pot) >= 0.0: Notation.pastille_note(ligne, 1064, (h - 2) / 2.0, t.lettre_pot, 32, "RecherchePistePot_%d" % i)
		else: D.text(ligne, 1064, 32, "—", 20, Charte.IVOIRE_3, 800, 80)
		D.text(ligne, 1154, 32, _argent(int(x.get("indemnite", 0))), 20, Charte.INTENSIF, 700, 140)
		D.text(ligne, 1294, 32, Salary.amount(x.get("salaire", 0)), 20, Charte.IVOIRE_2, 700, 160)
		var id := str(x.get("id", ""))
		Pieces.rendre_cliquable(ligne, Vector2(1458, h - 2), func():
			app.selected_player = id
			app.navigation_controller.open_entity({"kind": "player", "id": id, "section": ""}), "RecherchePisteOuvrir_%d" % i, str(x.get("nom", "")), "", Charte.RAYON_PETIT)
	if trouves.is_empty():
		Pieces.pastille(liste, 40, 80, "0 joueur observé", "search", "RechercheAucune", "", Charte.IVOIRE_2)

## Recruteurs du staff : un rond par personne (initiales), plein = affecté ; clic = affecter / retirer.
static func _recruteurs(app: Control, page: Control, parent: Control, x: float, y: float) -> void:
	var e := _etat(app)
	var gens := recruteurs(app)
	if gens.is_empty():
		Pieces.pastille(parent, x, y + 8, "Aucun recruteur", "warning", "RechercheSansRecruteur", "", Charte.INTENSIF)
		return
	var affectes := _affectes(app, e)
	for k in gens.size():
		var m: Dictionary = gens[k]
		var id := str(m.id)
		var affecte: bool = id in affectes
		var rond := D.rect(parent, Rect2(x + k * 280, y, 50, 50), Charte.MORAL if affecte else Charte.PANNEAU_3, 999, Charte.IVOIRE if affecte else Color.TRANSPARENT)
		rond.name = "RechercheRecruteur_%d" % k
		var mots := Array(str(m.nom).split(" ", false))
		var ini := "".join(PackedStringArray(mots.map(func(w: String): return w.substr(0, 1)))).substr(0, 2).to_upper()
		D.text(rond, 25, 33, ini, 20, Charte.ENCRE if affecte else Charte.IVOIRE_2, 800, 50, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(parent, x + k * 280 + 60, y + 22, str(m.nom), 19, Charte.IVOIRE if affecte else Charte.IVOIRE_2, 700, 210).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(parent, x + k * 280 + 60, y + 46, "Affecté" if affecte else "Libre", 15, Charte.MORAL if affecte else Charte.IVOIRE_3, 700, 210).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pieces.rendre_cliquable(rond, Vector2(50, 50), func():
			var liste: Array = affectes.duplicate()
			if id in liste: liste.erase(id)
			else: liste.append(id)
			_changer(app, page, "recruteurs", liste), "RechercheRecruteurChoisir_%d" % k, str(m.nom), "", Charte.RAYON_PILULE)

## Pied : priorité, recruteurs, recherches en cours, nombre de joueurs observés qui collent, action dorée.
static func _pied(app: Control, page: Control, fond: Control, e: Dictionary) -> void:
	var x := 620.0
	for p: Array in PRIORITES:
		var actif: bool = str(e.priorite) == str(p[0])
		var w := Pieces.pastille(fond, x, 944, str(p[1]), str(p[3]), "RecherchePriorite_" + str(p[0]), "", Charte.ENCRE if actif else p[2], p[2] if actif else Charte.PANNEAU_3)
		var id := str(p[0])
		Pieces.rendre_cliquable(fond.get_node("RecherchePriorite_" + id), Vector2(w, 34), func(): _changer(app, page, "priorite", id), "RecherchePrioriteChoisir_" + id, str(p[1]), "", Charte.RAYON_PILULE)
		x += w + 10
	_recruteurs(app, page, fond, x + 30, 936)
	# Recherches en cours : poste + semaines restantes, couleur de la priorité.
	var xm := 620.0
	var en_cours: Array = _donnees(app).get("missions", [])
	for k in mini(en_cours.size(), 4):
		var mis: Dictionary = en_cours[k]
		var n := int(mis.get("maillot", 0))
		var couleur: Color = Charte.MORAL
		for p: Array in PRIORITES:
			if str(p[0]) == str(mis.get("priorite", "")): couleur = p[2]
		var sigle := str(Roles.POSTE.get(str(Roles.FAMILLE[n - 1]), "")) if n >= 1 and n <= 15 else "?"
		var mot := "%s · %d sem." % [sigle, int(mis.get("remaining", 0))] if str(mis.get("status", "")) == "active" else "%s · en file" % sigle
		xm += Pieces.pastille(fond, xm, 1018, mot, "renew" if str(mis.get("priorite", "")) == "continue" else "search", "RechercheEnCours_%d" % k, "", couleur) + 10
	Pieces.pastille(fond, xm, 1018, "%d observés" % pistes(app, e).size(), "people", "RecherchePistesCompte", "", Charte.IVOIRE_2)
	var b := D.button(fond, Rect2(1610, 1000, 480, 64), "Envoyer le recruteur · 5 000 €", func():
		lancer(app, e), true, "arrow", false, Charte.DORE, "RechercheLancer")
	b.disabled = int(e.poste) < 0 or not bool(_donnees(app).get("disponible", false))
