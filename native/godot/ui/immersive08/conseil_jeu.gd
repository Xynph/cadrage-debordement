extends RefCounted
## Avis du conseil sur notre jeu (revue FM27, idée n° 31) : PLANCHE A/B sous CD_VARIANTE_VISUELLE, onglet Club › Notre jeu.
## Raccordé à la note du conseil en lettre (#1180) : même barème de lettres, mêmes flèches ▲ / ▼.
## Données du moteur seulement : les matchs de la saison dans notre championnat (model.history : score, essais, mêlées,
## touches, possession, territoire, pénalités, cartons, tirs au but) comparés à la moyenne du championnat et au rang de
## chaque club. Le conseil n'a pas (encore) d'avis propre dans le moteur : la réaction se déduit de l'écart (seuils provisoires).
## A : bandeau de la lettre du style puis réactions rangées par famille (lignes façon Effectif).
## B : une ligne par famille, sa lettre, puis ses chiffres en colonnes colorées.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")
const Lettre = preload("res://ui/immersive08/conseil_lettre.gd")

## Seuils provisoires : ▲ à +8 % au-dessus de la moyenne du championnat, ▼ à 8 % en dessous ; lettre à 50 au niveau de la
## moyenne, 100 à +35 %, 0 à −35 %.
const SEUIL := 0.08
const PLEIN := 0.35

## Indicateurs : id, libellé, unité, sens (+1 = plus c'est haut mieux c'est).
const INDICATEURS := {
	"victoires": ["Victoires", "%", 1], "ecart": ["Écart de points", "", 1],
	"melee": ["Mêlées gagnées", "%", 1], "touche": ["Touches gagnées", "%", 1], "possession": ["Possession", "%", 1],
	"essais": ["Essais par match", "", 1], "bonus": ["Matchs à 4 essais", "%", 1],
	"points": ["Points marqués", "", 1], "territoire": ["Territoire", "%", 1], "buteur": ["Réussite au but", "%", 1],
	"encaisses": ["Points encaissés", "", -1], "essais_enc": ["Essais encaissés", "", -1], "penalites": ["Pénalités concédées", "", -1], "jaunes": ["Cartons jaunes", "", -1],
}
## Familles (adaptées au rugby) : id, nom, pictogramme, indicateurs.
const FAMILLES := [
	["plan", "Plan de jeu", "tactic", ["victoires", "ecart"]],
	["conquete", "Conquête", "people", ["melee", "touche", "possession"]],
	["spectacle", "Spectacle", "star", ["essais", "bonus"]],
	["attaque", "Attaque", "ball", ["points", "territoire", "buteur"]],
	["defense", "Défense", "shield", ["encaisses", "essais_enc", "penalites", "jaunes"]],
]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _joue(m: Dictionary, club_id: int) -> bool:
	for c: Variant in m.get("pair", []):
		if int(c) == club_id: return true
	return false

# --- Données ------------------------------------------------------------------------------------------------------------

## Valeurs d'un côté d'un match (i = nous, j = eux), null quand le moteur n'a pas la donnée.
static func _echantillon(m: Dictionary, i: int) -> Dictionary:
	var j := 1 - i
	var score: Array = m.get("score", [0, 0])
	var essais: Array = m.get("tries", [0, 0])
	var stats: Array = m.get("stats", [])
	var s: Dictionary = stats[i] if stats.size() > i and stats[i] is Dictionary else {}
	var t: Dictionary = stats[j] if stats.size() > j and stats[j] is Dictionary else {}
	var e := {
		"victoires": 100.0 if float(score[i]) > float(score[j]) else (50.0 if float(score[i]) == float(score[j]) else 0.0),
		"ecart": float(score[i]) - float(score[j]),
		"essais": float(essais[i]), "bonus": 100.0 if int(essais[i]) >= 4 else 0.0,
		"points": float(score[i]), "encaisses": float(score[j]), "essais_enc": float(essais[j]),
	}
	if int(s.get("scrums", 0)) > 0: e.melee = 100.0 * float(s.get("scrumsWon", 0)) / float(s.scrums)
	if int(s.get("lineouts", 0)) > 0: e.touche = 100.0 * float(s.get("lineoutsWon", 0)) / float(s.lineouts)
	if s.has("possession"): e.possession = float(s.possession)
	if s.has("territory") and t.has("territory") and float(s.territory) + float(t.territory) > 0:
		e.territoire = 100.0 * float(s.territory) / (float(s.territory) + float(t.territory))
	var tentatives := int(s.get("goalAttempts", 0)) + int(s.get("conversionAttempts", 0))
	if tentatives > 0: e.buteur = 100.0 * float(int(s.get("goals", 0)) + int(s.get("conversions", 0))) / float(tentatives)
	if s.has("penalties"): e.penalites = float(s.penalties)
	if s.has("yellows"): e.jaunes = float(s.yellows)
	return e

## Saison en cours dans notre championnat : nos matchs, moyennes par club, moyenne du championnat, rang, note par indicateur.
static func donnees(model: Dictionary) -> Dictionary:
	var club_id := int(model.get("club", {}).get("id", -1))
	var historique: Array = model.get("history", [])
	var nos_matchs: Array = []
	var saison := -1
	var competition := ""
	for m: Variant in historique:
		if not m is Dictionary or not _joue(m, club_id) or str(m.get("phase", "")) != "league": continue
		saison = maxi(saison, int(m.get("season", 0)))
	for m: Variant in historique:
		if not m is Dictionary or not _joue(m, club_id) or int(m.get("season", 0)) != saison or str(m.get("phase", "")) != "league": continue
		competition = str(m.get("competitionId", ""))
	if competition.is_empty(): return {}
	var par_club := {}
	for m: Variant in historique:
		if not m is Dictionary or int(m.get("season", 0)) != saison or str(m.get("competitionId", "")) != competition or str(m.get("phase", "")) != "league": continue
		var pair: Array = m.get("pair", [])
		for i in 2:
			var e := _echantillon(m, i)
			var cle := int(pair[i])
			if not par_club.has(cle): par_club[cle] = []
			par_club[cle].append(e)
			if cle == club_id: nos_matchs.append({"match": m, "valeurs": e})
	nos_matchs.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.match.get("round", 0)) < int(b.match.get("round", 0)))
	var moyennes_clubs := {}
	for cle: Variant in par_club:
		moyennes_clubs[cle] = _moyennes(par_club[cle])
	var resultat := {"competition": competition, "matchs": nos_matchs, "indicateurs": {}, "familles": []}
	for id: String in INDICATEURS:
		var sens := int(INDICATEURS[id][2])
		var valeurs: Array = []
		for cle: Variant in moyennes_clubs:
			if moyennes_clubs[cle].has(id): valeurs.append(float(moyennes_clubs[cle][id]))
		var nous: Variant = moyennes_clubs.get(club_id, {}).get(id)
		if nous == null or valeurs.is_empty(): continue
		var somme := 0.0
		for v: float in valeurs: somme += v
		var moyenne := somme / valeurs.size()
		var rang := 1
		for v: float in valeurs:
			if (v > float(nous) and sens > 0) or (v < float(nous) and sens < 0): rang += 1
		# Écart relatif orienté (positif = mieux que la moyenne) ; l'écart de points se mesure sur 10 points.
		var relatif := 0.0
		if id == "ecart": relatif = (float(nous) - moyenne) / 10.0 * PLEIN
		elif absf(moyenne) > 0.01: relatif = sens * (float(nous) - moyenne) / absf(moyenne)
		else: relatif = -sens * float(nous) * .2
		var note := 50.0 + 50.0 * clampf(relatif / PLEIN, -1.0, 1.0)
		resultat.indicateurs[id] = {"id": id, "nous": float(nous), "moyenne": moyenne, "rang": rang, "clubs": valeurs.size(), "note": note,
			"avis": "up" if relatif >= SEUIL else ("down" if relatif <= -SEUIL else "neutre"), "relatif": relatif}
	var total := 0.0
	var n := 0
	for f: Array in FAMILLES:
		var notes: Array = []
		for id: String in f[3]:
			if resultat.indicateurs.has(id): notes.append(float(resultat.indicateurs[id].note))
		if notes.is_empty(): continue
		var s := 0.0
		for v: float in notes: s += v
		var famille := {"id": f[0], "nom": f[1], "picto": f[2], "indicateurs": f[3], "note": s / notes.size()}
		resultat.familles.append(famille)
		total += famille.note
		n += 1
	resultat.note = total / maxf(1.0, n)
	return resultat

static func _moyennes(echantillons: Array) -> Dictionary:
	var sommes := {}
	var comptes := {}
	for e: Dictionary in echantillons:
		for cle: String in e:
			sommes[cle] = float(sommes.get(cle, 0.0)) + float(e[cle])
			comptes[cle] = int(comptes.get(cle, 0)) + 1
	var r := {}
	for cle: String in sommes: r[cle] = float(sommes[cle]) / float(comptes[cle])
	return r

## Réaction du conseil en un mot coloré (d'après la note sur 100 de la famille ou de l'indicateur).
static func reaction(note: float) -> Array:
	if note >= 75: return ["Ravi", Charte.NOTE_EXCELLENTE]
	if note >= 58: return ["Content", Charte.CONDITION]
	if note > 42: return ["Partagé", Charte.ATTRIBUT_55]
	if note > 25: return ["Déçu", Charte.INTENSIF]
	return ["Inquiet", Charte.PERTE]

static func chiffre(id: String, valeur: float) -> String:
	var unite := str(INDICATEURS[id][1])
	if id == "ecart": return ("+%.1f" % valeur if valeur > 0 else ("−%.1f" % absf(valeur) if valeur < 0 else "0")).replace(".", ",")
	if unite == "%": return "%d %%" % roundi(valeur)
	return ("%.1f" % valeur).replace(".", ",")

static func ecart(indic: Dictionary) -> String:
	var id := str(indic.id)
	var d := float(indic.nous) - float(indic.moyenne)
	var texte := ""
	if str(INDICATEURS[id][1]) == "%": texte = "%d pts" % roundi(absf(d))
	else: texte = ("%.1f" % absf(d)).replace(".", ",")
	return ("+" if d > 0 else ("−" if d < 0 else "")) + texte

static func couleur_avis(avis: String) -> Color:
	return Charte.GAIN if avis == "up" else (Charte.PERTE if avis == "down" else Charte.IVOIRE_2)

# --- Petites fenêtres -----------------------------------------------------------------------------------------------------

## Un indicateur : nous, championnat, rang, puis un bâton par match (vert = au-dessus de la moyenne, rouge = en dessous).
static func fenetre_indicateur(app: Control, d: Dictionary, id: String) -> Control:
	var indic: Dictionary = d.indicateurs[id]
	var sens := int(INDICATEURS[id][2])
	var tuiles: Array = [
		Pastilles.tuile(chiffre(id, indic.nous), "Nous", couleur_avis(str(indic.avis)), Charte.PANNEAU_2, 40, "ConseilJeuFenetreNous"),
		Pastilles.tuile(chiffre(id, indic.moyenne), "Championnat", Charte.IVOIRE, Charte.PANNEAU_2, 40, "ConseilJeuFenetreMoyenne"),
		Pastilles.tuile("%d/%d" % [int(indic.rang), int(indic.clubs)], "Rang", Lettre.couleur(indic.note), Charte.PANNEAU_2, 40, "ConseilJeuFenetreRang"),
		Pastilles.tuile(reaction(float(indic.note))[0], "Conseil", reaction(float(indic.note))[1], Charte.PANNEAU_2, 40, "ConseilJeuFenetreReaction"),
	]
	for t: Control in tuiles: t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blocs: Array = [Visuel.rangee(tuiles)]
	var barres: Array = []
	var maximum := 1.0
	for m: Dictionary in d.matchs:
		if m.valeurs.has(id): maximum = maxf(maximum, absf(float(m.valeurs[id])))
	for m: Dictionary in d.matchs:
		if not m.valeurs.has(id): continue
		var v := float(m.valeurs[id])
		var mieux := (v - float(indic.moyenne)) * sens >= 0
		var montant := ("V" if v > 50 else ("N" if v == 50 else "D")) if id == "victoires" else chiffre(id, v)
		barres.append({"valeur": maxf(absf(v), maximum * .5) if id == "victoires" else absf(v), "maximum": maximum, "montant": montant, "critere": "J%s" % G.n(int(m.match.get("competitionRound", m.match.get("round", 0))) + 1), "couleur": Charte.GAIN if mieux else Charte.PERTE})
	if not barres.is_empty():
		var histo := Visuel.Histogramme.new(barres, 200)
		histo.name = "ConseilJeuHistogramme"
		blocs.append(histo)
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", str(INDICATEURS[id][0]), blocs)

## Une famille : sa lettre et une tuile par indicateur (clic = fenêtre de l'indicateur).
static func fenetre_famille(app: Control, d: Dictionary, famille: Dictionary) -> Control:
	var tuiles: Array = [Pastilles.tuile(Lettre.lettre(famille.note), "Lettre", Lettre.couleur(famille.note), Charte.PANNEAU_2, 48, "ConseilJeuFenetreLettre")]
	for id: String in famille.indicateurs:
		if not d.indicateurs.has(id): continue
		var indic: Dictionary = d.indicateurs[id]
		tuiles.append(Pastilles.tuile(chiffre(id, indic.nous), str(INDICATEURS[id][0]), couleur_avis(str(indic.avis)), Charte.PANNEAU_2, 40, "ConseilJeuFenetre_" + id, false, func(): fenetre_indicateur(app, d, id)))
	for t: Control in tuiles: t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", "%s · %s" % [famille.nom, Lettre.lettre(famille.note)], [Visuel.rangee(tuiles)])

## La lettre du style : une tuile lettre par famille.
static func fenetre_style(app: Control, d: Dictionary) -> Control:
	var tuiles: Array = []
	for famille: Dictionary in d.familles:
		var t := Pastilles.tuile(Lettre.lettre(famille.note), str(famille.nom), Lettre.couleur(famille.note), Charte.PANNEAU_2, 48, "ConseilJeuFenetreFamille_" + str(famille.id), false, func(): fenetre_famille(app, d, famille))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuiles.append(t)
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", "Notre jeu · %s" % Lettre.lettre(d.note), [Visuel.rangee(tuiles)])

# --- Écran -------------------------------------------------------------------------------------------------------------

static func build(app: Control, corps: Control) -> void:
	var d := donnees(app.model)
	var panneau := D.rect(corps, Rect2(0, 214, 2248, 1030), Charte.PANNEAU, 24)
	panneau.name = "ConseilJeu"
	panneau.mouse_filter = Control.MOUSE_FILTER_PASS
	if d.is_empty() or d.familles.is_empty():
		Kit.titre(panneau, 24, 40, "Notre jeu", 28)
		Kit.texte(panneau, 24, 120, "—", Charte.IVOIRE_2, 400, 34).name = "ConseilJeuVide"
		return
	if variante() == "B": _option_b(app, panneau, d)
	else: _option_a(app, panneau, d)

static func _bouton_lettre(app: Control, parent: Control, zone: Rect2, d: Dictionary, taille: int) -> Button:
	var bouton := Button.new()
	bouton.name = "ConseilJeuLettre"
	for etat in ["normal", "hover", "pressed"]:
		bouton.add_theme_stylebox_override(etat, C.box(Lettre.couleur(d.note).lightened(.08 if etat != "normal" else 0.0), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Note du conseil sur notre jeu %s" % Lettre.lettre(d.note)
	bouton.pressed.connect(func(): fenetre_style(app, d))
	parent.add_child(bouton)
	D.place(bouton, zone)
	var l := D.text(bouton, zone.size.x / 2.0, zone.size.y * .5 + taille * .36, Lettre.lettre(d.note), taille, Lettre.encre(d.note), 700, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", Charte.TITRE_FICHE)
	return bouton

## Pilules du plan de jeu (attaque, défense) : ouvrent le Plan de jeu.
static func _pilules_plan(app: Control, parent: Control, x: float, y: float) -> float:
	var tactique: Dictionary = app.model.get("tactics", {})
	var libelles := {}
	for liste: String in ["attacks", "defenses"]:
		for o: Variant in tactique.get(liste, []):
			if o is Dictionary: libelles[liste + str(o.get("id", ""))] = str(o.get("label", ""))
	for p: Array in [["attacks", "attack", "Attaque", Pastilles.BLEU], ["defenses", "defense", "Défense", Pastilles.VIOLET]]:
		var libelle := str(libelles.get(str(p[0]) + str(tactique.get(p[1], "")), ""))
		if libelle.is_empty(): continue
		var pastille := Pastilles.pastille("%s · %s" % [p[2], libelle], p[3], "", "", 19, "ConseilJeuPlan_" + str(p[1]), func(): app._navigate("Plan de jeu"))
		x += Pastilles.poser(parent, pastille, x, y) + 10.0
	return x

static func _compteurs(d: Dictionary) -> Array:
	var haut := 0
	var bas := 0
	for id: String in d.indicateurs:
		if d.indicateurs[id].avis == "up": haut += 1
		elif d.indicateurs[id].avis == "down": bas += 1
	return [haut, bas]

## A : bandeau de la lettre, puis les réactions rangées par famille (une ligne par chiffre, colonnes façon Effectif).
static func _option_a(app: Control, panneau: Control, d: Dictionary) -> void:
	var largeur := 2248.0
	# Bandeau : lettre, réaction, plan de jeu, ▲ / ▼.
	var bandeau := D.rect(panneau, Rect2(18, 18, largeur - 36, 132), Lettre.couleur(d.note).darkened(.62), 18)
	bandeau.name = "ConseilJeuBandeau"
	bandeau.mouse_filter = Control.MOUSE_FILTER_PASS
	_bouton_lettre(app, bandeau, Rect2(18, 16, 100, 100), d, 64)
	var titre := Kit.titre(bandeau, 146, 56, "LE CONSEIL ET NOTRE JEU", 34, 900)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var r := reaction(float(d.note))
	Pastilles.poser(bandeau, Pastilles.pastille(str(r[0]), r[1], "", "", 22, "ConseilJeuReaction", func(): fenetre_style(app, d)), 146, 74)
	_pilules_plan(app, bandeau, 146 + Kit.largeur(str(r[0]), 22) + 50, 76)
	var c := _compteurs(d)
	Lettre.fleche(bandeau, Rect2(largeur - 470, 46, 34, 34), "up")
	Kit.texte(bandeau, largeur - 428, 76, str(c[0]), Charte.GAIN, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Lettre.fleche(bandeau, Rect2(largeur - 360, 46, 34, 34), "down")
	Kit.texte(bandeau, largeur - 318, 76, str(c[1]), Charte.PERTE, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Kit.texte(bandeau, largeur - 64, 76, "%d matchs" % d.matchs.size(), Charte.IVOIRE_2, 200, 22, HORIZONTAL_ALIGNMENT_RIGHT)
	# Colonnes : Avis | Indicateur | Nous | Championnat | Écart | Rang | Match par match | Réaction.
	var x0 := 24.0
	var tl := largeur - 48.0
	var cols := [["", 0.0, 40.0, false], ["", 52.0, 360.0, false], ["Nous", 430.0, 130.0, true], ["Championnat", 590.0, 170.0, true], ["Écart", 790.0, 120.0, true], ["Rang", 950.0, 110.0, true], ["Match par match", 1110.0, 700.0, false], ["Conseil", tl - 200.0, 200.0, false]]
	for col: Array in cols: Kit.etiquette(panneau, x0 + float(col[1]) + (float(col[2]) if col[3] else 0.0), 184, str(col[0]), float(col[2]), col[3])
	var y := 196.0
	var k := 0
	for famille: Dictionary in d.familles:
		# Tête de famille : nom en Anton, petite lettre (clic = fenêtre de la famille).
		var tete := _ligne(panneau, Rect2(x0, y, tl, 46), "ConseilJeuFamille_" + str(famille.id), str(famille.nom), func(): fenetre_famille(app, d, famille))
		var picto := Visuel.picto(str(famille.picto), 26, Lettre.couleur(famille.note))
		picto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tete.add_child(picto)
		D.place(picto, Rect2(8, 10, 26, 26))
		var nom := Kit.texte(tete, 52, 34, str(famille.nom).to_upper(), Charte.IVOIRE, 300, 26)
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		Lettre.disque(tete, Rect2(52 + Kit.largeur(str(famille.nom).to_upper(), 26) + 22, 8, 58, 30), famille.note, 21)
		y += 46.0
		for id: String in famille.indicateurs:
			if not d.indicateurs.has(id): continue
			var indic: Dictionary = d.indicateurs[id]
			var rangee := _ligne(panneau, Rect2(x0, y, tl, 38), "ConseilJeuLigne_%d" % k, str(INDICATEURS[id][0]), func(): fenetre_indicateur(app, d, id))
			Kit.styler_ligne(rangee, Charte.PANNEAU_2 if k % 2 == 0 else Color.TRANSPARENT)
			Lettre.fleche(rangee, Rect2(8, 9, 20, 20), str(indic.avis))
			Kit.texte(rangee, 52, 27, str(INDICATEURS[id][0]), Charte.IVOIRE, 360, 19)
			var v := Kit.texte(rangee, 430, 28, chiffre(id, indic.nous), couleur_avis(str(indic.avis)), 130, 22, HORIZONTAL_ALIGNMENT_RIGHT)
			v.add_theme_font_override("font", Kit.texte_gras())
			Kit.texte(rangee, 590, 27, chiffre(id, indic.moyenne), Charte.IVOIRE_2, 170, 19, HORIZONTAL_ALIGNMENT_RIGHT)
			Kit.texte(rangee, 790, 27, ecart(indic), couleur_avis(str(indic.avis)), 120, 19, HORIZONTAL_ALIGNMENT_RIGHT)
			Kit.texte(rangee, 950, 27, "%d/%d" % [int(indic.rang), int(indic.clubs)], Lettre.couleur(indic.note), 110, 20, HORIZONTAL_ALIGNMENT_RIGHT)
			_points_matchs(rangee, Rect2(1110, 9, 700, 20), d, id)
			var re := reaction(float(indic.note))
			var p := Pastilles.pastille(str(re[0]), re[1], "", "", 17, "ConseilJeuAvis_%d" % k)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pastilles.poser(rangee, p, tl - 200, 4)
			y += 38.0
			k += 1
		y += 6.0

## Un point par match : vert au-dessus de la moyenne du championnat, rouge en dessous (sens de l'indicateur respecté).
class Points extends Control:
	var couleurs: Array = []
	func _draw() -> void:
		var n := couleurs.size()
		if n == 0: return
		var pas := minf(size.x / n, size.y * 2.2)
		var r := minf(size.y * .42, pas * .38)
		for i in n: draw_circle(Vector2(pas * (i + .5), size.y * .5), r, couleurs[i])

static func _points_matchs(parent: Control, zone: Rect2, d: Dictionary, id: String) -> void:
	var indic: Dictionary = d.indicateurs[id]
	var sens := int(INDICATEURS[id][2])
	var points := Points.new()
	points.name = "ConseilJeuPoints_" + id
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m: Dictionary in d.matchs:
		if not m.valeurs.has(id): continue
		var delta := (float(m.valeurs[id]) - float(indic.moyenne)) * sens
		points.couleurs.append(Charte.GAIN if delta > 0 else (Charte.PERTE if delta < 0 else Charte.IVOIRE_3))
	parent.add_child(points)
	D.place(points, zone)

static func _ligne(parent: Control, zone: Rect2, id: String, nom: String, action: Callable) -> Button:
	var rangee := Button.new()
	rangee.name = id
	Kit.styler_ligne(rangee, Color.TRANSPARENT)
	rangee.accessibility_name = nom
	rangee.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rangee.pressed.connect(action)
	parent.add_child(rangee)
	D.place(rangee, zone)
	return rangee

## B : une ligne par famille (nom, lettre, réaction, ▲ / ▼), puis ses chiffres en colonnes colorées ; à gauche, la grande
## lettre du style et le plan de jeu.
static func _option_b(app: Control, panneau: Control, d: Dictionary) -> void:
	var largeur := 2248.0
	# Colonne gauche : grande lettre, réaction, plan de jeu.
	_bouton_lettre(app, panneau, Rect2(24, 24, 300, 300), d, 190)
	var titre := Kit.titre(panneau, 24, 372, "NOTRE JEU", 40, 300)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var r := reaction(float(d.note))
	Pastilles.poser(panneau, Pastilles.pastille(str(r[0]), r[1], "", "", 24, "ConseilJeuReaction", func(): fenetre_style(app, d)), 24, 396)
	var tactique: Dictionary = app.model.get("tactics", {})
	var y_plan := 470.0
	for p: Array in [["attacks", "attack", "Attaque", Pastilles.BLEU], ["defenses", "defense", "Défense", Pastilles.VIOLET]]:
		var libelle := ""
		for o: Variant in tactique.get(p[0], []):
			if o is Dictionary and str(o.get("id", "")) == str(tactique.get(p[1], "")): libelle = str(o.get("label", ""))
		if libelle.is_empty(): continue
		Kit.etiquette(panneau, 24, y_plan, str(p[2]), 300)
		Pastilles.poser(panneau, Pastilles.pastille(libelle, p[3], "", "", 21, "ConseilJeuPlan_" + str(p[1]), func(): app._navigate("Plan de jeu")), 24, y_plan + 10)
		y_plan += 84.0
	var c := _compteurs(d)
	Lettre.fleche(panneau, Rect2(24, y_plan + 10, 34, 34), "up")
	Kit.texte(panneau, 66, y_plan + 42, str(c[0]), Charte.GAIN, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Lettre.fleche(panneau, Rect2(140, y_plan + 10, 34, 34), "down")
	Kit.texte(panneau, 182, y_plan + 42, str(c[1]), Charte.PERTE, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Kit.texte(panneau, 24, y_plan + 90, "%d matchs" % d.matchs.size(), Charte.IVOIRE_2, 300, 20)
	# Tableau des familles.
	var x0 := 370.0
	var tl := largeur - x0 - 24.0
	var cols := [["Famille", 0.0, 320.0], ["Lettre", 330.0, 100.0], ["Conseil", 450.0, 160.0], ["Chiffres · nous / championnat · rang", 640.0, 1000.0]]
	for col: Array in cols: Kit.etiquette(panneau, x0 + float(col[1]), 52, str(col[0]), float(col[2]))
	D.line(panneau, Vector2(x0, 64), Vector2(x0 + tl, 64), Charte.FILET)
	var haut := 184.0
	var y := 70.0
	var k := 0
	for famille: Dictionary in d.familles:
		var rangee := _ligne(panneau, Rect2(x0, y, tl, haut - 8), "ConseilJeuFamille_" + str(famille.id), str(famille.nom), func(): fenetre_famille(app, d, famille))
		Kit.styler_ligne(rangee, Charte.PANNEAU_2)
		var picto := Visuel.picto(str(famille.picto), 34, Lettre.couleur(famille.note))
		picto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(picto)
		D.place(picto, Rect2(16, 30, 34, 34))
		var nom := Kit.texte(rangee, 64, 62, str(famille.nom).to_upper(), Charte.IVOIRE, 260, 32)
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		# Flèches de la famille sous le nom.
		var fx := 64.0
		for id: String in famille.indicateurs:
			if not d.indicateurs.has(id): continue
			Lettre.fleche(rangee, Rect2(fx, 92, 22, 22), str(d.indicateurs[id].avis))
			fx += 28.0
		Lettre.disque(rangee, Rect2(330, 30, 96, 60), famille.note, 40)
		var re := reaction(float(famille.note))
		var p := Pastilles.pastille(str(re[0]), re[1], "", "", 20, "ConseilJeuAvisFamille_" + str(famille.id))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pastilles.poser(rangee, p, 450, 42)
		# Chiffres en colonnes : un bloc cliquable par indicateur.
		var bx := 640.0
		var bl := (tl - 640.0 - 16.0) / 4.0
		for id: String in famille.indicateurs:
			if not d.indicateurs.has(id): continue
			var indic: Dictionary = d.indicateurs[id]
			var bloc := _ligne(rangee, Rect2(bx, 10, bl - 12, haut - 28), "ConseilJeuLigne_%d" % k, str(INDICATEURS[id][0]), func(): fenetre_indicateur(app, d, id))
			Kit.styler_ligne(bloc, Color(couleur_avis(str(indic.avis)), .10))
			Kit.etiquette(bloc, 16, 30, str(INDICATEURS[id][0]), bl - 40)
			var v := Kit.texte(bloc, 16, 86, chiffre(id, indic.nous), couleur_avis(str(indic.avis)) if indic.avis != "neutre" else Charte.IVOIRE, 220, 46)
			v.add_theme_font_override("font", Charte.TITRE_FICHE)
			Lettre.fleche(bloc, Rect2(bl - 56, 50, 28, 28), str(indic.avis))
			Kit.texte(bloc, 16, 124, "champ. %s" % chiffre(id, indic.moyenne), Charte.IVOIRE_2, 220, 18)
			Kit.texte(bloc, bl - 30, 124, "%d/%d" % [int(indic.rang), int(indic.clubs)], Lettre.couleur(indic.note), 120, 20, HORIZONTAL_ALIGNMENT_RIGHT).add_theme_font_override("font", Kit.texte_gras())
			_points_matchs(bloc, Rect2(16, 136, bl - 48, 14), d, id)
			bx += bl
			k += 1
		y += haut
