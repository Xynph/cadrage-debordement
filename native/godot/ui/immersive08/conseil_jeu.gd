extends RefCounted
## Avis du conseil sur notre jeu (revue FM27, idée n° 31 ; option A choisie par Léo le 23/11/2026), onglet Club › Notre jeu.
## Bandeau : lettre du jeu (clic = petite fenêtre des familles), humeur des dirigeants, identité de jeu du club (ses
## attentes), plan de jeu, ▲ / ▼. Puis une ligne par chiffre, rangées par famille (tête : lettre et attente du conseil en
## crans) : avis, chiffre, nous, moyenne du championnat, écart, rang, un point par match, réaction du conseil. Intitulés
## de colonnes posés exactement sur leurs chiffres (même x, même largeur, même alignement).
## Données du moteur (clubLife.conseilJeu, native/engine/conseil-jeu.cjs) : rien n'est recalculé ici. La note du jeu
## compte réellement au bilan du conseil, avec sa part de hasard ; cet effet n'est jamais chiffré à l'écran.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")
const Lettre = preload("res://ui/immersive08/conseil_lettre.gd")

## Colonnes des lignes : intitulé, x (dans la ligne), largeur, chiffre aligné à droite. L'intitulé reprend x, largeur et
## alignement de son chiffre.
const COLONNES := [["", 8.0, 30.0, false], ["", 52.0, 360.0, false], ["Nous", 420.0, 140.0, true], ["Moyenne", 600.0, 150.0, true], ["Écart", 790.0, 130.0, true], ["Rang", 960.0, 110.0, true], ["Match par match", 1120.0, 700.0, false], ["Conseil", 2000.0, 180.0, false]]
const LIGNE := 34.0
const TETE := 42.0
## Crans d'attente du conseil (importance 1 à 3 de la famille pour l'identité du club).
const ATTENTES := {1: "Secondaire", 2: "Attendu", 3: "Prioritaire"}

static func donnees(model: Dictionary) -> Dictionary:
	var d: Variant = model.get("clubLife", {}).get("conseilJeu", {})
	return d if d is Dictionary and bool(d.get("available", false)) else {}

## Réaction du conseil en un mot coloré (d'après la note sur 100 de la famille ou du chiffre).
static func reaction(note: float) -> Array:
	if note >= 75: return ["Ravi", Charte.NOTE_EXCELLENTE]
	if note >= 58: return ["Content", Charte.CONDITION]
	if note > 42: return ["Partagé", Charte.ATTRIBUT_55]
	if note > 25: return ["Déçu", Charte.INTENSIF]
	return ["Inquiet", Charte.PERTE]

static func chiffre(indic: Dictionary, valeur: float) -> String:
	if str(indic.id) == "ecart":
		var arrondi := snappedf(valeur, 0.1)
		return ("+%.1f" % arrondi if arrondi > 0 else ("−%.1f" % absf(arrondi) if arrondi < 0 else "0")).replace(".", ",")
	if str(indic.unite) == "%": return "%d %%" % roundi(valeur)
	return ("%.1f" % valeur).replace(".", ",")

static func ecart(indic: Dictionary) -> String:
	var d := float(indic.nous) - float(indic.moyenne)
	var texte := "%d pts" % roundi(absf(d)) if str(indic.unite) == "%" else ("%.1f" % absf(d)).replace(".", ",")
	var nul := roundi(absf(d)) == 0 if str(indic.unite) == "%" else snappedf(absf(d), 0.1) == 0.0
	return ("" if nul else ("+" if d > 0.0 else "−")) + texte

static func couleur_avis(avis: String) -> Color:
	return Charte.GAIN if avis == "up" else (Charte.PERTE if avis == "down" else Charte.IVOIRE_2)

# --- Petites fenêtres -----------------------------------------------------------------------------------------------------

## Un chiffre : nous, moyenne, rang, réaction (et total de la saison pour un cumul), puis un bâton par match.
static func fenetre_indicateur(app: Control, d: Dictionary, id: String) -> Control:
	var indic: Dictionary = d.indicateurs[id]
	var re := reaction(float(indic.note))
	var tuiles: Array = [
		Pastilles.tuile(chiffre(indic, indic.nous), "Nous", couleur_avis(str(indic.avis)), Charte.PANNEAU_2, 40, "ConseilJeuFenetreNous"),
		Pastilles.tuile(chiffre(indic, indic.moyenne), "Moyenne", Charte.IVOIRE, Charte.PANNEAU_2, 40, "ConseilJeuFenetreMoyenne"),
		Pastilles.tuile("%d/%d" % [int(indic.rang), int(indic.clubs)], "Rang", Lettre.couleur(indic.note), Charte.PANNEAU_2, 40, "ConseilJeuFenetreRang"),
		Pastilles.tuile(str(re[0]), "Conseil", re[1], Charte.PANNEAU_2, 40, "ConseilJeuFenetreReaction"),
	]
	if indic.has("total"):
		tuiles.insert(1, Pastilles.tuile(G.n(roundi(float(indic.total))), "Saison", Charte.IVOIRE, Charte.PANNEAU_2, 40, "ConseilJeuFenetreSaison"))
	for t: Control in tuiles: t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blocs: Array = [Visuel.rangee(tuiles)]
	var barres: Array = []
	var maximum := 1.0
	for m: Dictionary in d.matchs:
		if m.valeurs.has(id): maximum = maxf(maximum, absf(float(m.valeurs[id])))
	for m: Dictionary in d.matchs:
		if not m.valeurs.has(id): continue
		var v := float(m.valeurs[id])
		var mieux := (v - float(indic.moyenne)) * float(indic.sens) >= 0
		var montant := ("V" if v > 50 else ("N" if v == 50 else "D")) if id == "victoires" else chiffre(indic, v)
		barres.append({"valeur": maxf(absf(v), maximum * .5) if id == "victoires" else absf(v), "maximum": maximum, "montant": montant, "critere": "J%s" % G.n(int(m.journee)), "couleur": Charte.GAIN if mieux else Charte.PERTE})
	if not barres.is_empty():
		var histo := Visuel.Histogramme.new(barres, 200)
		histo.name = "ConseilJeuHistogramme"
		blocs.append(histo)
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", str(indic.nom), blocs)

## Une famille : sa lettre, l'attente du conseil, puis une tuile par chiffre (clic = fenêtre du chiffre).
static func fenetre_famille(app: Control, d: Dictionary, famille: Dictionary) -> Control:
	var tuiles: Array = [Pastilles.tuile(Lettre.lettre(famille.note), "Lettre", Lettre.couleur(famille.note), Charte.PANNEAU_2, 48, "ConseilJeuFenetreLettre"),
		Pastilles.tuile(str(ATTENTES.get(int(famille.attente), "")), "Attente", Pastilles.TURQUOISE if int(famille.attente) >= 3 else Charte.IVOIRE, Charte.PANNEAU_2, 30, "ConseilJeuFenetreAttente")]
	for id: String in famille.indicateurs:
		var indic: Dictionary = d.indicateurs[id]
		var cle := id
		tuiles.append(Pastilles.tuile(chiffre(indic, indic.nous), str(indic.nom), couleur_avis(str(indic.avis)), Charte.PANNEAU_2, 40, "ConseilJeuFenetre_" + id, false, func(): fenetre_indicateur(app, d, cle)))
	for t: Control in tuiles: t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", "%s · %s" % [famille.nom, Lettre.lettre(famille.note)], [Visuel.rangee(tuiles)])

## La lettre du jeu : une tuile lettre par famille (clic = fenêtre de la famille).
static func fenetre_style(app: Control, d: Dictionary) -> Control:
	var tuiles: Array = []
	for famille: Dictionary in d.familles:
		var f := famille
		var t := Pastilles.tuile(Lettre.lettre(famille.note), str(famille.nom), Lettre.couleur(famille.note), Charte.PANNEAU_2, 48, "ConseilJeuFenetreFamille_" + str(famille.id), false, func(): fenetre_famille(app, d, f))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuiles.append(t)
	return Visuel.petite_fenetre(app, "ConseilJeuFenetre", "Notre jeu · %s" % Lettre.lettre(d.note), [Visuel.rangee(tuiles)])

# --- Écran -------------------------------------------------------------------------------------------------------------

static func build(app: Control, corps: Control) -> void:
	var d := donnees(app.model)
	var panneau := D.rect(corps, Rect2(0, 214, 2248, 1030), Charte.PANNEAU, 24)
	panneau.name = "ConseilJeu"
	panneau.mouse_filter = Control.MOUSE_FILTER_PASS
	if d.is_empty() or d.get("familles", []).is_empty() or d.get("note") == null:
		Kit.titre(panneau, 24, 40, "Notre jeu", 28)
		Kit.texte(panneau, 24, 120, "—", Charte.IVOIRE_2, 400, 34).name = "ConseilJeuVide"
		return
	_bandeau(app, panneau, d)
	_tableau(app, panneau, d)

static func _bouton_lettre(app: Control, parent: Control, zone: Rect2, d: Dictionary, taille: int) -> Button:
	var bouton := Button.new()
	bouton.name = "ConseilJeuLettre"
	for etat in ["normal", "hover", "pressed"]:
		bouton.add_theme_stylebox_override(etat, C.box(Lettre.couleur(d.note).lightened(.08 if etat != "normal" else 0.0), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Note du conseil sur notre jeu %s" % Lettre.lettre(d.note)
	bouton.pressed.connect(func(): fenetre_style(app, d))
	parent.add_child(bouton)
	D.place(bouton, zone)
	var l := D.text(bouton, zone.size.x / 2.0, zone.size.y * .5 + taille * .36, Lettre.lettre(d.note), taille, Lettre.encre(d.note), 700, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", Charte.TITRE_FICHE)
	l.name = "Lettre"
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

## Bandeau : lettre, titre, humeur des dirigeants, identité du club (ses attentes), plan de jeu, ▲ / ▼, matchs.
static func _bandeau(app: Control, panneau: Control, d: Dictionary) -> void:
	var largeur := 2248.0
	var bandeau := D.rect(panneau, Rect2(18, 18, largeur - 36, 132), Lettre.couleur(d.note).darkened(.62), 18)
	bandeau.name = "ConseilJeuBandeau"
	bandeau.mouse_filter = Control.MOUSE_FILTER_PASS
	_bouton_lettre(app, bandeau, Rect2(18, 16, 100, 100), d, 64)
	var titre := Kit.titre(bandeau, 146, 56, "LE CONSEIL ET NOTRE JEU", 34, 900)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var r := reaction(float(d.note))
	var x := 146.0
	x += Pastilles.poser(bandeau, Pastilles.pastille(str(r[0]), r[1], "", "", 22, "ConseilJeuReaction", func(): fenetre_style(app, d)), x, 74) + 24.0
	x += Pastilles.poser(bandeau, Pastilles.pastille("Identité · %s" % str(d.get("identite", "")), Pastilles.TURQUOISE, "star", "", 19, "ConseilJeuIdentite", func(): fenetre_style(app, d)), x, 76) + 12.0
	_pilules_plan(app, bandeau, x, 76)
	var c := _compteurs(d)
	Lettre.fleche(bandeau, Rect2(largeur - 470, 46, 34, 34), "up")
	Kit.texte(bandeau, largeur - 428, 76, str(c[0]), Charte.GAIN, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Lettre.fleche(bandeau, Rect2(largeur - 360, 46, 34, 34), "down")
	Kit.texte(bandeau, largeur - 318, 76, str(c[1]), Charte.PERTE, 60, 40).add_theme_font_override("font", Charte.TITRE_FICHE)
	Kit.texte(bandeau, largeur - 64, 76, "%d matchs" % d.matchs.size(), Charte.IVOIRE_2, 200, 22, HORIZONTAL_ALIGNMENT_RIGHT).name = "ConseilJeuMatchs"

## Crans d'attente du conseil : trois pastilles, pleines selon l'importance de la famille pour l'identité du club.
class Crans extends Control:
	var niveau := 1
	func _draw() -> void:
		var r := size.y * .32
		for i in 3:
			var centre := Vector2(r + i * r * 2.9, size.y * .5)
			if i < niveau: draw_circle(centre, r, Pastilles.TURQUOISE)
			else: draw_arc(centre, r - 1.0, 0, TAU, 20, Charte.IVOIRE_3, 1.6, true)

## Tableau : une tête par famille, une ligne par chiffre ; intitulés alignés sur les chiffres.
static func _tableau(app: Control, panneau: Control, d: Dictionary) -> void:
	var x0 := 24.0
	var tl := 2248.0 - 48.0
	for col: Array in COLONNES:
		if str(col[0]).is_empty(): continue
		Kit.etiquette(panneau, x0 + float(col[1]), 184, str(col[0]), float(col[2]), col[3]).name = "ConseilJeuColonne_" + str(col[0])
	var y := 194.0
	var k := 0
	for famille: Dictionary in d.familles:
		var f := famille
		var tete := _ligne(panneau, Rect2(x0, y, tl, TETE), "ConseilJeuFamille_" + str(famille.id), str(famille.nom), func(): fenetre_famille(app, d, f))
		var picto := Visuel.picto(str(famille.picto), 24, Lettre.couleur(famille.note))
		picto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tete.add_child(picto)
		D.place(picto, Rect2(8, 9, 24, 24))
		var nom := Kit.texte(tete, 52, 31, str(famille.nom).to_upper(), Charte.IVOIRE, 300, 25)
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		var fin_nom := 52 + Kit.largeur(str(famille.nom).to_upper(), 25) + 20
		Lettre.disque(tete, Rect2(fin_nom, 7, 56, 28), famille.note, 20)
		var crans := Crans.new()
		crans.name = "ConseilJeuAttente_" + str(famille.id)
		crans.niveau = int(famille.attente)
		crans.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tete.add_child(crans)
		D.place(crans, Rect2(fin_nom + 72, 11, 60, 20))
		y += TETE
		for id: String in famille.indicateurs:
			var indic: Dictionary = d.indicateurs[id]
			var cle := id
			var rangee := _ligne(panneau, Rect2(x0, y, tl, LIGNE), "ConseilJeuLigne_%d" % k, str(indic.nom), func(): fenetre_indicateur(app, d, cle))
			rangee.set_meta("indicateur", id)
			Kit.styler_ligne(rangee, Charte.PANNEAU_2 if k % 2 == 0 else Color.TRANSPARENT)
			var base := 24.0
			Lettre.fleche(rangee, Rect2(COLONNES[0][1], 8, 18, 18), str(indic.avis))
			Kit.texte(rangee, COLONNES[1][1], base, str(indic.nom), Charte.IVOIRE, COLONNES[1][2], 19)
			var v := Kit.texte(rangee, COLONNES[2][1], base + 1, chiffre(indic, indic.nous), couleur_avis(str(indic.avis)), COLONNES[2][2], 22, HORIZONTAL_ALIGNMENT_RIGHT)
			v.add_theme_font_override("font", Kit.texte_gras())
			v.name = "ConseilJeuNous"
			Kit.texte(rangee, COLONNES[3][1], base, chiffre(indic, indic.moyenne), Charte.IVOIRE_2, COLONNES[3][2], 19, HORIZONTAL_ALIGNMENT_RIGHT).name = "ConseilJeuMoyenne"
			Kit.texte(rangee, COLONNES[4][1], base, ecart(indic), couleur_avis(str(indic.avis)), COLONNES[4][2], 19, HORIZONTAL_ALIGNMENT_RIGHT).name = "ConseilJeuEcart"
			Kit.texte(rangee, COLONNES[5][1], base, "%d/%d" % [int(indic.rang), int(indic.clubs)], Lettre.couleur(indic.note), COLONNES[5][2], 20, HORIZONTAL_ALIGNMENT_RIGHT).name = "ConseilJeuRang"
			_points_matchs(rangee, Rect2(COLONNES[6][1], 8, COLONNES[6][2], 18), d, id)
			var re := reaction(float(indic.note))
			var p := Pastilles.pastille(str(re[0]), re[1], "", "", 17, "ConseilJeuAvis_%d" % k)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pastilles.poser(rangee, p, COLONNES[7][1], 3)
			y += LIGNE
			k += 1
		y += 4.0

## Un point par match : vert au-dessus de la moyenne du championnat, rouge en dessous (sens du chiffre respecté).
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
	var points := Points.new()
	points.name = "ConseilJeuPoints_" + id
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m: Dictionary in d.matchs:
		if not m.valeurs.has(id): continue
		var delta := (float(m.valeurs[id]) - float(indic.moyenne)) * float(indic.sens)
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
