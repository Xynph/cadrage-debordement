extends RefCounted
## Note du conseil en lettre (revue FM27, idée n° 8 ; option B « carnet de notes » choisie par Léo le 22/11/2026).
## Panneau « Le conseil » de Club › Vue d'ensemble : grande lettre de la confiance (clic = petite fenêtre de la note et de
## ses bilans), une ligne par domaine du bilan (poids, lettre, courbe des bilans, dernière note, flèche ▲ / ▼), puis les
## bilans en lignes (journée, lettre, évolution, résultat du match, flèche et lettre par domaine). Installations : pastille
## d'état et pictogramme coloré par ligne.
## Données du moteur : confiance (meta.trust) et bilans (finance.boardHistory : results, finances, youth sur 100).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")

## Barème validé par Léo (22/11/2026) : lettre de la confiance sur 100, alignée sur les paliers Solide (70+), Fragile
## (40-69) et Menacé (0-39).
const BAREME := [[92, "A+"], [85, "A"], [78, "A−"], [74, "B+"], [70, "B"], [65, "B−"], [60, "C+"], [50, "C"], [40, "C−"], [30, "D+"], [20, "D"], [10, "D−"], [0, "E"]]
## Avis d'un domaine : ▲ à partir de 65, ▼ sous 45 (notes du bilan sur 100).
const ELOGE := 65
const CRITIQUE := 45
## Domaines et poids du bilan du moteur (dist/career-integration.js, CAREER_BOARD_WEIGHTS).
const DOMAINES := [["results", "Résultats", 70], ["finances", "Finances", 20], ["youth", "Formation", 10]]

static func lettre(valeur: Variant) -> String:
	if not (valeur is int or valeur is float): return "—"
	for palier: Array in BAREME:
		if float(valeur) >= float(palier[0]): return str(palier[1])
	return "E"

## Couleur de la lettre : vert foncé (A), vert (B+, B), citron (B−, C+), orange (C, C−), rouge (D, E).
static func couleur(valeur: Variant) -> Color:
	if not (valeur is int or valeur is float): return Charte.GRIS_VERT
	var v := float(valeur)
	if v >= 78: return Charte.NOTE_EXCELLENTE
	if v >= 70: return Charte.CONDITION
	if v >= 60: return Charte.ATTRIBUT_55
	if v >= 40: return Charte.INTENSIF
	return Charte.PERTE

static func encre(valeur: Variant) -> Color:
	return Color.WHITE if (valeur is int or valeur is float) and float(valeur) >= 78 else Charte.ENCRE

static func palier(valeur: Variant) -> String:
	if not (valeur is int or valeur is float): return ""
	return "Solide" if float(valeur) >= 70 else ("Fragile" if float(valeur) >= 40 else "Menacé")

static func avis(note: Variant) -> String:
	if not (note is int or note is float): return "neutre"
	return "up" if float(note) >= ELOGE else ("down" if float(note) < CRITIQUE else "neutre")

static func _signe(valeur: int) -> String:
	return "+%d" % valeur if valeur > 0 else ("−%d" % absi(valeur) if valeur < 0 else "0")

static func _vers_jalons(app: Control) -> void:
	app.management_ui.immersive08_strategy_tab = 1
	app._navigate("Stratégie")

# --- Formes ------------------------------------------------------------------------------------------------------------

## Flèche ▲ verte (éloge), ▼ rouge (critique) ou tiret gris (neutre) : la forme porte le sens, jamais la couleur seule.
class Fleche extends Control:
	var genre := "up"
	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		match genre:
			"up": draw_colored_polygon(PackedVector2Array([o + Vector2(s * .5, s * .14), o + Vector2(s * .9, s * .82), o + Vector2(s * .1, s * .82)]), Charte.GAIN)
			"down": draw_colored_polygon(PackedVector2Array([o + Vector2(s * .1, s * .18), o + Vector2(s * .9, s * .18), o + Vector2(s * .5, s * .86)]), Charte.PERTE)
			_: draw_line(o + Vector2(s * .22, s * .5), o + Vector2(s * .78, s * .5), Charte.GRIS_VERT, maxf(1.5, s * .12))

static func fleche(parent: Control, zone: Rect2, genre: String) -> Fleche:
	var f := Fleche.new()
	f.genre = genre
	f.name = "Fleche_" + genre
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(f)
	D.place(f, zone)
	return f

## Pastille arrondie de la lettre (fond à la couleur, lettre en Anton, encre lisible).
static func disque(parent: Control, zone: Rect2, valeur: Variant, taille: int) -> Panel:
	var fond := D.rect(parent, zone, couleur(valeur), int(zone.size.y / 2.0))
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := D.text(fond, zone.size.x / 2.0, zone.size.y * .5 + taille * .36, lettre(valeur), taille, encre(valeur), 700, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", Charte.TITRE_FICHE)
	l.name = "Lettre"
	return fond

static func _ligne(parent: Control, zone: Rect2, id: String, nom: String, action: Callable) -> Button:
	var rangee := Button.new()
	rangee.name = id
	Kit.styler_ligne(rangee, Color.TRANSPARENT)
	rangee.accessibility_name = nom
	rangee.pressed.connect(action)
	parent.add_child(rangee)
	D.place(rangee, zone)
	return rangee

## Mini-courbe des notes d'un domaine sur les bilans (du plus ancien au plus récent), points à la couleur de leur lettre.
class Courbe extends Control:
	var valeurs: Array = []
	func _draw() -> void:
		if valeurs.is_empty(): return
		draw_line(Vector2(0, size.y * .5), Vector2(size.x, size.y * .5), Charte.FILET, 1.0)
		var pts := PackedVector2Array()
		var n := valeurs.size()
		for i in n:
			var x := size.x * (0.5 if n == 1 else float(i) / float(n - 1))
			pts.append(Vector2(x, size.y - 4.0 - (size.y - 8.0) * clampf(float(valeurs[i]) / 100.0, 0.0, 1.0)))
		if n > 1: draw_polyline(pts, Charte.IVOIRE_2, maxf(1.5, size.y * .05), true)
		for i in n: draw_circle(pts[i], maxf(3.0, size.y * .1), _teinte(float(valeurs[i])))
	func _teinte(v: float) -> Color:
		if v >= 78: return Charte.NOTE_EXCELLENTE
		if v >= 70: return Charte.CONDITION
		if v >= 60: return Charte.ATTRIBUT_55
		if v >= 40: return Charte.INTENSIF
		return Charte.PERTE

# --- Petite fenêtre : la lettre et ses bilans ---------------------------------------------------------------------------

static func fenetre_lettre(app: Control, confiance: Variant, historique: Array) -> Control:
	var tuiles: Array = []
	for famille: Array in [["A", 78, "78 et plus"], ["B", 65, "65 à 77"], ["C", 40, "40 à 64"], ["D", 10, "10 à 39"], ["E", 0, "moins de 10"]]:
		var actuelle := lettre(confiance).begins_with(str(famille[0]))
		var t := Pastilles.tuile(str(famille[0]), str(famille[2]), couleur(int(famille[1]) + 1) if actuelle else Charte.IVOIRE_2, Charte.PANNEAU_2, 44 if actuelle else 30, "ConseilFamille_" + str(famille[0]))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuiles.append(t)
	var blocs: Array = [Visuel.rangee(tuiles)]
	if not historique.is_empty():
		var barres: Array = []
		for i in range(mini(8, historique.size()) - 1, -1, -1):
			var b: Dictionary = historique[i]
			barres.append({"valeur": b.after, "maximum": 100, "montant": "%s · %s" % [lettre(b.after), G.n(b.after)], "critere": "J%s" % G.n(b.round), "couleur": couleur(b.after)})
		var histo := Visuel.Histogramme.new(barres, 180)
		histo.name = "ConseilHistogramme"
		blocs.append(histo)
	return Visuel.petite_fenetre(app, "ConseilFenetreLettre", "Note du conseil · %s" % lettre(confiance), blocs)

# --- Le conseil : lettre et domaines -----------------------------------------------------------------------------------

## Zone haute du panneau (y 70 à 290) : grande lettre à gauche, tableau des trois domaines à droite.
static func conseil(panneau: Control, app: Control, finance: Dictionary, largeur: float) -> void:
	var confiance: Variant = app.model.meta.get("trust")
	var historique: Array = finance.get("boardHistory", [])
	var bouton := Button.new()
	bouton.name = "ConseilLettre"
	bouton.flat = false
	for etat in ["normal", "hover", "pressed"]:
		bouton.add_theme_stylebox_override(etat, C.box(couleur(confiance).lightened(.08 if etat != "normal" else 0.0), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Note du conseil %s · confiance %s sur 100" % [lettre(confiance), G.n(confiance) if confiance != null else "—"]
	bouton.pressed.connect(func(): fenetre_lettre(app, confiance, historique))
	panneau.add_child(bouton)
	D.place(bouton, Rect2(24, 70, 190, 190))
	var grande := D.text(bouton, 95, 140, lettre(confiance), 112, encre(confiance), 700, 190, HORIZONTAL_ALIGNMENT_CENTER)
	grande.add_theme_font_override("font", Charte.TITRE_FICHE)
	grande.name = "Lettre"
	var sous := D.text(bouton, 95, 176, ("%s · %s" % [palier(confiance), G.n(confiance)]).to_upper() if confiance != null else "—", 18, encre(confiance), 700, 190, HORIZONTAL_ALIGNMENT_CENTER)
	sous.name = "ClubTrustValue"
	# Tableau des domaines : Domaine | Poids | Note | Bilans | Dernier | Avis.
	var x0 := 240.0
	var tl := largeur - x0 - 24.0
	var cols := [["Domaine", 0.0, 200.0, false], ["Poids", 210.0, 90.0, true], ["Note", 338.0, 80.0, false], ["Bilans", 450.0, tl - 600.0, false], ["Dernier", tl - 140.0, 80.0, true], ["Avis", tl - 40.0, 40.0, false]]
	for c: Array in cols: Kit.etiquette(panneau, x0 + float(c[1]) + (float(c[2]) if c[3] else 0.0), 84, str(c[0]), float(c[2]), c[3])
	D.line(panneau, Vector2(x0, 94), Vector2(x0 + tl, 94), Charte.FILET)
	var dernier: Dictionary = historique[0] if not historique.is_empty() else {}
	var actions := {"results": func(): app._navigate("Classements"), "finances": func(): app._navigate("Finances"), "youth": func(): app._navigate("Centre")}
	for i in DOMAINES.size():
		var dom: Array = DOMAINES[i]
		var haut := 98.0 + i * 54.0
		if i > 0: D.line(panneau, Vector2(x0, haut), Vector2(x0 + tl, haut), Charte.FILET)
		var rangee := _ligne(panneau, Rect2(x0, haut, tl, 54), "ConseilDomaine_" + str(dom[0]), str(dom[1]), actions[dom[0]])
		var nom := Kit.texte(rangee, 0, 34, str(dom[1]), Charte.IVOIRE, 200, 21)
		nom.add_theme_font_override("font", Kit.texte_gras())
		Kit.texte(rangee, 300, 34, "%d %%" % int(dom[2]), Charte.IVOIRE_2, 90, 19, HORIZONTAL_ALIGNMENT_RIGHT)
		var note: Variant = dernier.get(dom[0])
		if note != null: disque(rangee, Rect2(338, 8, 64, 38), note, 26)
		else: Kit.texte(rangee, 370, 34, "—", Charte.IVOIRE_3, 64, 20, HORIZONTAL_ALIGNMENT_CENTER)
		var valeurs: Array = []
		for j in range(mini(8, historique.size()) - 1, -1, -1): valeurs.append(historique[j].get(dom[0], 0))
		var courbe := Courbe.new()
		courbe.valeurs = valeurs
		courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(courbe)
		D.place(courbe, Rect2(450, 7, tl - 620, 40))
		Kit.texte(rangee, tl - 60, 34, G.n(note) if note != null else "—", Charte.IVOIRE, 80, 20, HORIZONTAL_ALIGNMENT_RIGHT)
		fleche(rangee, Rect2(tl - 34, 15, 24, 24), avis(note))

## Bilans en lignes : journée, lettre, évolution, résultat du match (`lier` : ovale et lien vers la fiche du match), puis
## flèche et lettre par domaine. Une ligne sans match ouvre le suivi des objectifs.
static func bilans(panneau: Control, app: Control, historique: Array, x: float, y: float, largeur: float, lier: Callable = Callable()) -> void:
	var bloc := Control.new()
	bloc.name = "ClubTrustTable"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(bloc)
	D.place(bloc, Rect2(x, y, largeur, 320))
	Kit.etiquette(bloc, 0, 22, "Bilans du conseil", largeur)
	if historique.is_empty():
		Kit.texte(bloc, 0, 96, "—", Charte.IVOIRE_2, largeur, 34).name = "ClubTrustTableEmpty"
		return
	var depart := 300.0
	var part := (largeur - depart) / 3.0
	var cols := [["J.", 8.0], ["Note", 70.0], ["Évol.", 150.0], ["Rés.", 226.0], ["Résultats", depart], ["Finances", depart + part], ["Formation", depart + 2.0 * part]]
	for c: Array in cols: Kit.etiquette(bloc, float(c[1]), 60, str(c[0]), 160)
	D.line(bloc, Vector2(0, 70), Vector2(largeur, 70), Charte.FILET)
	for i in mini(5, historique.size()):
		var b: Dictionary = historique[i]
		var haut := 74.0 + i * 36.0
		if i > 0: D.line(bloc, Vector2(0, haut), Vector2(largeur, haut), Charte.FILET)
		var rangee := _ligne(bloc, Rect2(0, haut, largeur, 36), "ClubTrustRow%d" % i, "Bilan du conseil, journée %s" % G.n(b.round), _vers_jalons.bind(app))
		Kit.texte(rangee, 8, 25, "J%s" % G.n(b.round), Charte.IVOIRE_2, 50, 18)
		disque(rangee, Rect2(66, 5, 54, 26), b.after, 19)
		var delta := int(b.after) - int(b.previous)
		fleche(rangee, Rect2(148, 10, 16, 16), "up" if delta > 0 else ("down" if delta < 0 else "neutre"))
		Kit.texte(rangee, 170, 25, _signe(delta), Charte.GAIN if delta > 0 else (Charte.PERTE if delta < 0 else Charte.IVOIRE_2), 50, 18)
		if lier.is_valid(): lier.call(rangee, b)
		for k in DOMAINES.size():
			var cx := depart + k * part
			var note: Variant = b.get(DOMAINES[k][0])
			fleche(rangee, Rect2(cx, 9, 18, 18), avis(note))
			var l := Kit.texte(rangee, cx + 28, 25, lettre(note), couleur(note), 50, 19)
			l.add_theme_font_override("font", Charte.TITRE_FICHE)
	Kit.lien(bloc, Rect2(0, 74 + 5 * 36 + 12, 0, 34), "Tous les bilans du conseil →", _vers_jalons.bind(app), "ClubTrustAll", 18).tooltip_text = ""

# --- Installations : pictogramme et pastille d'état --------------------------------------------------------------------

const PICTOS_INSTALLATIONS := {"ClubFacilityTraining": "settings", "ClubFacilityMedical": "croix", "ClubFacilityAcademy": "star", "ClubFacilityStadium": "home"}

## État d'une installation (mot + icône + couleur), d'après les données déjà affichées sur la ligne.
static func etat_installation(id: String, app: Control, finance: Dictionary, strategie: Dictionary) -> Dictionary:
	match id:
		"ClubFacilityTraining":
			var devis: Variant = finance.get("facility")
			if not devis is Dictionary: return {}
			var n := int(devis.level)
			if n >= 9: return {"mot": "Excellent", "couleur": Charte.NOTE_EXCELLENTE, "icone": "check"}
			if n >= 7: return {"mot": "Très bon", "couleur": Charte.CONDITION, "icone": "check"}
			if n >= 5: return {"mot": "Correct", "couleur": Charte.ATTRIBUT_55, "icone": "check"}
			if n >= 3: return {"mot": "Vieillissant", "couleur": Charte.INTENSIF, "icone": "warning"}
			return {"mot": "Insuffisant", "couleur": Charte.PERTE, "icone": "warning"}
		"ClubFacilityMedical":
			var soutien: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
			if soutien.is_empty(): return {}
			var n: int = soutien.get("medical", {}).get("players", []).size()
			if n == 0: return {"mot": "Infirmerie vide", "couleur": Charte.CONDITION, "icone": "check"}
			if n <= 2: return {"mot": "%d en soins" % n, "couleur": Charte.ATTRIBUT_55, "icone": "warning"}
			return {"mot": "%d en soins" % n, "couleur": Charte.PERTE, "icone": "warning"}
		"ClubFacilityAcademy":
			var niveau: Variant = app.model.get("clubLife", {}).get("academyPathways", {}).get("facilities")
			if niveau == null:
				var suivi: Dictionary = app.model.get("clubLife", {}).get("academyFollowUp", {})
				if suivi.get("available", false) != true: return {}
				var remplissage := float(suivi.get("total", 0)) / maxf(1.0, float(suivi.get("capacity", 75)))
				if remplissage >= .9: return {"mot": "Complète", "couleur": Charte.INTENSIF, "icone": "warning"}
				return {"mot": "Places libres", "couleur": Charte.CONDITION, "icone": "check"}
			if int(niveau) >= 3: return {"mot": "Excellente", "couleur": Charte.NOTE_EXCELLENTE, "icone": "check"}
			if int(niveau) == 2: return {"mot": "Correcte", "couleur": Charte.ATTRIBUT_55, "icone": "check"}
			return {"mot": "Basique", "couleur": Charte.INTENSIF, "icone": "warning"}
		"ClubFacilityStadium":
			var fans: Dictionary = strategie.get("fans", {})
			if not fans.has("capacity") or not fans.has("expectedAttendance"): return {}
			var taux := float(fans.expectedAttendance) / maxf(1.0, float(fans.capacity))
			if taux >= .9: return {"mot": "Plein", "couleur": Charte.CONDITION, "icone": "people"}
			if taux >= .6: return {"mot": "Bien rempli", "couleur": Charte.ATTRIBUT_55, "icone": "people"}
			return {"mot": "Clairsemé", "couleur": Charte.INTENSIF, "icone": "people"}
	return {}

## Pastille d'état posée dans la colonne « État » de la ligne.
static func pastille_ligne(rangee: Control, etat: Dictionary, x: float, id: String) -> void:
	if etat.is_empty():
		Kit.texte(rangee, x, 27, "—", Charte.IVOIRE_3, 40, 18)
		return
	var p := Pastilles.pastille(str(etat.mot), etat.couleur, str(etat.icone), "", 16, id)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Pastilles.poser(rangee, p, x, 7)

## Pictogramme de l'installation en tête de ligne (ivoire-2, comme les icônes au repos).
static func picto_ligne(rangee: Control, id: String, zone: Rect2) -> void:
	var picto := Visuel.picto(PICTOS_INSTALLATIONS.get(id, "settings"), int(zone.size.x), Charte.IVOIRE_2)
	rangee.add_child(picto)
	D.place(picto, zone)
