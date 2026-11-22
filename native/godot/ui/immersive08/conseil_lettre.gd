extends RefCounted
## Planche « Note du conseil en lettre » (revue FM27, idée n° 8, 22/11/2026) : options A et B sous CD_VARIANTE_VISUELLE.
## A « Bulletin » : bandeau à la couleur de la lettre (C+), éloges et critiques en lignes à pouces verts / rouges,
## installations avec une pastille d'état après le nom.
## B « Carnet de notes » : grande lettre, une lettre par domaine du bilan (résultats 55 %, finances 30 %, formation 15 %)
## avec sa courbe, bilans en lignes (lettre + trois pouces), installations en quatre pastilles d'état.
## Données : confiance du conseil (meta.trust) et bilans du moteur (finance.boardHistory : results, finances, youth).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")
const P = preload("res://ui/immersive08/projection.gd")

## Barème : lettre de la confiance (0-100), alignée sur les paliers Solide (70+), Fragile (40-69), Menacé (0-39).
const BAREME := [[92, "A+"], [85, "A"], [78, "A−"], [74, "B+"], [70, "B"], [65, "B−"], [60, "C+"], [50, "C"], [40, "C−"], [30, "D+"], [20, "D"], [10, "D−"], [0, "E"]]
## Éloge à partir de 65, critique sous 45 (notes de domaine du bilan, sur 100).
const ELOGE := 65
const CRITIQUE := 45
const DOMAINES := [["results", "Résultats", 55], ["finances", "Finances", 30], ["youth", "Formation", 15]]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v == "A" or v == "B" else ""

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

static func _vers_jalons(app: Control) -> void:
	app.management_ui.immersive08_strategy_tab = 1
	app._navigate("Stratégie")

static func _signe(valeur: int) -> String:
	return "+%d" % valeur if valeur > 0 else ("−%d" % absi(valeur) if valeur < 0 else "0")

# --- Pouce dessiné -------------------------------------------------------------------------------------------------------

## Pouce levé (éloge, vert), baissé (critique, rouge) ou tiret (neutre, gris) : la forme porte le sens, pas la couleur seule.
class Pouce extends Control:
	var genre := "up"
	func _draw() -> void:
		var s := minf(size.x, size.y)
		var w := maxf(1.5, s * .1)
		if genre == "neutre":
			draw_line(Vector2(s * .22, s * .5), Vector2(s * .78, s * .5), Charte.GRIS_VERT, w)
			return
		var c := Charte.GAIN if genre == "up" else Charte.PERTE
		var bas := genre == "down"
		var y := func(v: float) -> float: return (s - v * s) if bas else v * s
		# Manche (poignet) puis la main et le pouce, pleins.
		draw_rect(Rect2(s * .08, y.call(.46) if not bas else y.call(.92), s * .2, s * .46), c)
		var main := PackedVector2Array([Vector2(s * .34, y.call(.46)), Vector2(s * .5, y.call(.42)), Vector2(s * .56, y.call(.1)), Vector2(s * .68, y.call(.12)), Vector2(s * .66, y.call(.4)), Vector2(s * .9, y.call(.44)), Vector2(s * .84, y.call(.92)), Vector2(s * .34, y.call(.92))])
		draw_colored_polygon(main, c)

static func pouce(parent: Control, zone: Rect2, genre: String) -> Pouce:
	var p := Pouce.new()
	p.genre = genre
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	D.place(p, zone)
	return p

## Pastille ronde de la lettre (fond à la couleur, lettre en Anton, encre lisible).
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

# --- Éloges et critiques (données du moteur) ------------------------------------------------------------------------------

## Remarques du dernier bilan (un domaine = une ligne), puis jalons atteints / manqués et promesses publiques.
static func remarques(app: Control, finance: Dictionary, board: Dictionary) -> Array:
	var sortie: Array = []
	var historique: Array = finance.get("boardHistory", [])
	var dernier: Dictionary = historique[0] if not historique.is_empty() else {}
	var club: Dictionary = app.model.get("club", {})
	for ligne: Dictionary in P.standings(app.model):
		if ligne.get("id") == club.get("id"): club = ligne
	var faits := {
		"results": "%sV · %sN · %sD" % [G.n(club.get("won", 0)), G.n(club.get("drawn", 0)), G.n(club.get("lost", 0))],
		"finances": "trésorerie " + Pastilles.euros_courts(finance.get("cash", 0)),
		"youth": "",
	}
	if dernier.has("youth"):
		var promus := maxi(0, roundi((float(dernier.youth) - 50.0) / 20.0))
		faits.youth = "%d jeune%s promu%s" % [promus, "s" if promus > 1 else "", "s" if promus > 1 else ""]
	var actions := {"results": func(): app._navigate("Classements"), "finances": func(): app._navigate("Finances"), "youth": func(): app._navigate("Centre")}
	if not dernier.is_empty():
		for domaine: Array in DOMAINES:
			var note: Variant = dernier.get(domaine[0])
			sortie.append({"genre": avis(note), "domaine": domaine[1], "fait": faits[domaine[0]], "note": note, "quand": "J%s" % G.n(dernier.round), "action": actions[domaine[0]], "id": "ConseilRemarque_" + str(domaine[0])})
	for objectif: Dictionary in board.get("objectives", []):
		var etat := str(objectif.get("status", ""))
		if etat != "met" and etat != "missed": continue
		var genre := str(objectif.get("type", ""))
		var cible: Variant = objectif.get("target")
		var libelle: String = str({"wins": "Victoires ≥ ", "points": "Points ≥ ", "rank": "Classement ≤ ", "cash": "Trésorerie ≥ "}.get(genre, "")) + str(G.euros(cible) if genre == "cash" else G.n(cible))
		sortie.append({"genre": "up" if etat == "met" else "down", "domaine": "Jalon", "fait": libelle, "note": null, "quand": "S%s" % G.n(objectif.get("deadline", 0)), "action": _vers_jalons.bind(app), "id": "ConseilRemarque_jalon_" + genre})
	var promesses: Variant = app.model.get("clubLife", {}).get("pressPromises", {})
	for promesse: Dictionary in (promesses.get("active", []) if promesses is Dictionary else []):
		var suit: Variant = promesse.get("progress", {}).get("onTrack")
		if suit == null: continue
		sortie.append({"genre": "up" if suit else "down", "domaine": "Promesse", "fait": str(promesse.get("short", "")), "note": null, "quand": "", "action": func(): app._navigate("Presse"), "id": "ConseilRemarque_promesse_%d" % sortie.size()})
	return sortie

# --- Petite fenêtre : la lettre et ses bilans ---------------------------------------------------------------------------

static func fenetre_lettre(app: Control, confiance: Variant, historique: Array) -> void:
	var tuiles: Array = []
	for famille: Array in [["A", 78, "78 et plus"], ["B", 65, "65 à 77"], ["C", 40, "40 à 64"], ["D", 10, "10 à 39"], ["E", 0, "moins de 10"]]:
		var actuelle := lettre(confiance).begins_with(str(famille[0]))
		var t := Pastilles.tuile(str(famille[0]), str(famille[2]), couleur(int(famille[1]) + 1) if actuelle else Charte.IVOIRE_2, Charte.PANNEAU_2, 44 if actuelle else 30)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuiles.append(t)
	var blocs: Array = [Visuel.rangee(tuiles)]
	if not historique.is_empty():
		var barres: Array = []
		for i in range(mini(8, historique.size()) - 1, -1, -1):
			var b: Dictionary = historique[i]
			barres.append({"valeur": b.after, "maximum": 100, "montant": "%s · %s" % [lettre(b.after), G.n(b.after)], "critere": "J%s" % G.n(b.round), "couleur": couleur(b.after)})
		blocs.append(Visuel.Histogramme.new(barres, 180))
	Visuel.petite_fenetre(app, "ConseilFenetreLettre", "Note du conseil · %s" % lettre(confiance), blocs)

# --- Option A : bulletin ---------------------------------------------------------------------------------------------------

## Zone haute du panneau « Le conseil » (y 60 à 300) : bandeau de la lettre à gauche, éloges et critiques à droite.
static func conseil_a(panneau: Control, app: Control, finance: Dictionary, board: Dictionary, largeur: float) -> void:
	var confiance: Variant = app.model.meta.get("trust")
	var historique: Array = finance.get("boardHistory", [])
	var teinte := couleur(confiance)
	var bandeau := Button.new()
	bandeau.name = "ConseilBandeauLettre"
	bandeau.flat = false
	for etat in ["normal", "hover", "pressed", "focus"]:
		var fond := C.box(Charte.PANNEAU_2.lerp(teinte, .30 if etat == "normal" else .40), Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
		if etat == "focus":
			fond = C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
			fond.set_border_width_all(2)
		bandeau.add_theme_stylebox_override(etat, fond)
	bandeau.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bandeau.accessibility_name = "Note du conseil %s" % lettre(confiance)
	bandeau.pressed.connect(func(): fenetre_lettre(app, confiance, historique))
	panneau.add_child(bandeau)
	var l := 560.0
	D.place(bandeau, Rect2(24, 66, l, 218))
	disque(bandeau, Rect2(22, 22, 120, 120), confiance, 66)
	var mot := Kit.titre(bandeau, 164, 62, palier(confiance) if palier(confiance) != "" else "Pas de note", 38, 360)
	mot.name = "ConseilPalier"
	Kit.etiquette(bandeau, 166, 96, "Confiance du conseil", 300)
	var chiffre := D.text(bandeau, 164, 140, G.n(confiance) if confiance != null else "—", 44, Charte.IVOIRE, 800, 120)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	chiffre.name = "ClubTrustValue"
	Kit.texte(bandeau, 164 + Charte.TITRE_EXTRA_ITALIQUE.get_string_size(chiffre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(44))).x / C.density + 8, 138, "/ 100", Charte.IVOIRE_2, 80, 20)
	if not historique.is_empty():
		var dernier: Dictionary = historique[0]
		var delta := int(dernier.after) - int(dernier.previous)
		var p := Pastilles.pastille("%s après J%s" % [_signe(delta), G.n(dernier.round)], Charte.GAIN if delta > 0 else (Charte.PERTE if delta < 0 else Charte.GRIS_VERT), "", "", 17, "ClubTrustChange")
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pastilles.poser(bandeau, p, 22, 166)
	else:
		var p := Pastilles.pastille("1er bilan à venir", Pastilles.BLEU, "clock", "", 17, "ClubLastReview")
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Pastilles.poser(bandeau, p, 22, 166)
	# Échelle des lettres E → A, la famille actuelle à sa couleur.
	var x := l - 22.0 - 5 * 36.0
	for famille: Array in [["E", 5], ["D", 25], ["C", 50], ["B", 72], ["A", 85]]:
		var actuelle := lettre(confiance).begins_with(str(famille[0]))
		var case := D.rect(bandeau, Rect2(x, 170, 32, 32), couleur(famille[1]) if actuelle else Color(Charte.PANNEAU, .6), Charte.RAYON_PETIT)
		case.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := D.text(case, 16, 24, str(famille[0]), 20, encre(famille[1]) if actuelle else Charte.IVOIRE_2, 700, 32, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_font_override("font", Charte.TITRE_FICHE)
		x += 36.0
	# Éloges et critiques.
	var gx := 24.0 + l + 28.0
	var gl := largeur - gx - 24.0
	Kit.etiquette(panneau, gx, 84, "Éloges et critiques", gl)
	var lignes := remarques(app, finance, board)
	if lignes.is_empty():
		Kit.texte(panneau, gx, 130, "—", Charte.IVOIRE_2, 60, 30).name = "ConseilRemarquesVide"
	for i in mini(5, lignes.size()):
		var r: Dictionary = lignes[i]
		var haut := 96.0 + i * 38.0
		if i > 0: D.line(panneau, Vector2(gx, haut), Vector2(gx + gl, haut), Charte.FILET)
		var rangee := _ligne(panneau, Rect2(gx, haut, gl, 38), str(r.id), "%s · %s" % [r.domaine, r.fait], r.action)
		pouce(rangee, Rect2(6, 8, 22, 22), str(r.genre))
		var dom := Kit.texte(rangee, 40, 26, str(r.domaine), Charte.IVOIRE, 150, 19)
		dom.add_theme_font_override("font", Kit.texte_gras())
		Kit.texte(rangee, 170, 26, str(r.fait), Charte.IVOIRE_2, gl - 300, 18)
		if r.note != null:
			var n := Kit.texte(rangee, gl - 64, 26, lettre(r.note), couleur(r.note), 50, 20, HORIZONTAL_ALIGNMENT_RIGHT)
			n.add_theme_font_override("font", Charte.TITRE_FICHE)
		Kit.texte(rangee, gl - 6, 26, str(r.quand), Charte.IVOIRE_3, 54, 16, HORIZONTAL_ALIGNMENT_RIGHT)

# --- Option B : carnet de notes ----------------------------------------------------------------------------------------------

## Mini-courbe des notes d'un domaine sur les bilans (du plus ancien au plus récent), points à la couleur de la lettre.
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

static func conseil_b(panneau: Control, app: Control, finance: Dictionary, largeur: float) -> void:
	var confiance: Variant = app.model.meta.get("trust")
	var historique: Array = finance.get("boardHistory", [])
	# Grande lettre (carré arrondi à la couleur), cliquable : petite fenêtre de la note et de ses bilans.
	var bouton := Button.new()
	bouton.name = "ConseilBandeauLettre"
	bouton.flat = false
	for etat in ["normal", "hover", "pressed"]:
		bouton.add_theme_stylebox_override(etat, C.box(couleur(confiance).lightened(.08 if etat != "normal" else 0.0), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.accessibility_name = "Note du conseil %s" % lettre(confiance)
	bouton.pressed.connect(func(): fenetre_lettre(app, confiance, historique))
	panneau.add_child(bouton)
	D.place(bouton, Rect2(24, 70, 190, 190))
	var grande := D.text(bouton, 95, 140, lettre(confiance), 112, encre(confiance), 700, 190, HORIZONTAL_ALIGNMENT_CENTER)
	grande.add_theme_font_override("font", Charte.TITRE_FICHE)
	grande.name = "Lettre"
	var sous := D.text(bouton, 95, 176, ("%s · %s" % [palier(confiance), G.n(confiance)]).to_upper() if confiance != null else "—", 18, encre(confiance), 700, 190, HORIZONTAL_ALIGNMENT_CENTER)
	sous.name = "ClubTrustValue"
	# Tableau des domaines : Domaine | Poids | Note | Bilans | Avis.
	var x0 := 240.0
	var tl := largeur - x0 - 24.0
	var cols := [["Domaine", 0.0, 200.0, false], ["Poids", 210.0, 90.0, true], ["Note", 330.0, 80.0, false], ["Bilans", 440.0, tl - 600.0, false], ["Dernier", tl - 140.0, 80.0, true], ["Avis", tl - 40.0, 40.0, false]]
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
		pouce(rangee, Rect2(tl - 34, 15, 26, 26), avis(note))

## Bilans en lignes (remplace « Ce qui a fait bouger la confiance ») : journée, lettre, évolution, trois pouces par domaine.
static func bilans_b(panneau: Control, app: Control, historique: Array, x: float, y: float, largeur: float) -> void:
	var bloc := Control.new()
	bloc.name = "ClubTrustTable"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(bloc)
	D.place(bloc, Rect2(x, y, largeur, 320))
	Kit.etiquette(bloc, 0, 22, "Bilans du conseil", largeur)
	if historique.is_empty():
		Kit.texte(bloc, 0, 96, "—", Charte.IVOIRE_2, largeur, 34).name = "ClubTrustTableEmpty"
		return
	var cols := [["J.", 8.0], ["Note", 70.0], ["Évol.", 150.0], ["Résultats", 250.0], ["Finances", 250.0 + (largeur - 250.0) / 3.0], ["Formation", 250.0 + 2.0 * (largeur - 250.0) / 3.0]]
	for c: Array in cols: Kit.etiquette(bloc, float(c[1]), 60, str(c[0]), 160)
	D.line(bloc, Vector2(0, 70), Vector2(largeur, 70), Charte.FILET)
	for i in mini(6, historique.size()):
		var b: Dictionary = historique[i]
		var haut := 74.0 + i * 36.0
		if i > 0: D.line(bloc, Vector2(0, haut), Vector2(largeur, haut), Charte.FILET)
		var rangee := _ligne(bloc, Rect2(0, haut, largeur, 36), "ClubTrustRow%d" % i, "Bilan du conseil, journée %s" % G.n(b.round), _vers_jalons.bind(app))
		Kit.texte(rangee, 8, 25, "J%s" % G.n(b.round), Charte.IVOIRE_2, 50, 18)
		disque(rangee, Rect2(66, 5, 54, 26), b.after, 19)
		var delta := int(b.after) - int(b.previous)
		Kit.texte(rangee, 150, 25, ("▲ " if delta > 0 else ("▼ " if delta < 0 else "")) + _signe(delta), Charte.GAIN if delta > 0 else (Charte.PERTE if delta < 0 else Charte.IVOIRE_2), 80, 18)
		for k in DOMAINES.size():
			var cx := 250.0 + k * (largeur - 250.0) / 3.0
			pouce(rangee, Rect2(cx, 7, 22, 22), avis(b.get(DOMAINES[k][0])))
			Kit.texte(rangee, cx + 32, 25, lettre(b.get(DOMAINES[k][0])), couleur(b.get(DOMAINES[k][0])), 50, 19).add_theme_font_override("font", Charte.TITRE_FICHE)

# --- Installations : pastilles d'état ----------------------------------------------------------------------------------------

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
				var part := float(suivi.get("total", 0)) / maxf(1.0, float(suivi.get("capacity", 75)))
				if part >= .9: return {"mot": "Complète", "couleur": Charte.INTENSIF, "icone": "warning"}
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

## Option A : pastille d'état posée juste après le nom de chaque ligne.
static func pastille_ligne(rangee: Control, etat: Dictionary, x: float, id: String) -> void:
	if etat.is_empty(): return
	var p := Pastilles.pastille(str(etat.mot), etat.couleur, str(etat.icone), "", 16, id)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Pastilles.poser(rangee, p, x, 6)

## Option B : les quatre installations en pastilles d'état côte à côte (icône, nom, état, niveau), chacune cliquable.
static func installations_b(panneau: Control, rangees: Array, etats: Array, largeur: float) -> void:
	var n := rangees.size()
	var ecart := 14.0
	var l := (largeur - 48.0 - ecart * (n - 1)) / n
	var icones := {"ClubFacilityTraining": "settings", "ClubFacilityMedical": "croix", "ClubFacilityAcademy": "star", "ClubFacilityStadium": "home"}
	for i in n:
		var r: Dictionary = rangees[i]
		var etat: Dictionary = etats[i]
		var teinte: Color = etat.get("couleur", Charte.GRIS_VERT)
		var carte := Button.new()
		carte.name = str(r.id)
		carte.flat = false
		for e in ["normal", "hover", "pressed"]:
			carte.add_theme_stylebox_override(e, C.box(Charte.PANNEAU_2.lerp(teinte, .10 if e == "normal" else .18), Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
		focus.set_border_width_all(2)
		carte.add_theme_stylebox_override("focus", focus)
		carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		carte.accessibility_name = str(r.nom)
		carte.pressed.connect(r.action)
		panneau.add_child(carte)
		D.place(carte, Rect2(24 + i * (l + ecart), 76, l, 176))
		var picto := Visuel.picto(icones.get(str(r.id), "settings"), 40, teinte)
		carte.add_child(picto)
		D.place(picto, Rect2(18, 18, 40, 40))
		var nom := Kit.texte(carte, 70, 46, str(r.nom), Charte.IVOIRE, l - 84, 20)
		nom.add_theme_font_override("font", Kit.texte_gras())
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not etat.is_empty():
			var p := Pastilles.pastille(str(etat.mot), teinte, str(etat.icone), "", 19, "%sEtat" % r.id)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pastilles.poser(carte, p, 18, 78)
		Kit.texte(carte, 18, 148, str(r.niveau), Charte.IVOIRE_2, l - 36, 18)
		if not str(r.statut).is_empty(): Kit.texte(carte, l - 18, 148, str(r.statut), Charte.IVOIRE_3, l * .5, 16, HORIZONTAL_ALIGNMENT_RIGHT)
