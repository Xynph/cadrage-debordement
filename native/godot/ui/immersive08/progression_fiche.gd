extends RefCounted
## Planche FM27 n° 14 « Progression par qualité » (onglet Développement de la fiche joueur), sous CD_VARIANTE_VISUELLE=A|B.
## A : grande courbe sur 12 mois des qualités cochées (une couleur par qualité) au-dessus de la grille des 36 attributs
##     à cases, écart sur 12 mois à côté de chaque note ; pastille « Niveau » = courbe globale (niveau + potentiel).
## B : liste style Effectif des 36 qualités triée par progression (mini-courbe 12 mois, écart, note), courbe à droite
##     (Niveau par défaut, familles en légende) ; un clic sur une ligne la pose sur la courbe.
## Le moteur ne garde AUCUN relevé mensuel des attributs (attributesV2 ne bouge qu'à l'intersaison) : la série de
## 13 relevés mensuels est ici reconstituée pour la planche (déterministe, finit sur la valeur actuelle).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")

const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
## Une couleur franche par qualité cochée (six au plus), jetons de la charte puis rose et citron.
const TEINTES := [Color("5b9bd5"), Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("e07bb0"), Color("d4e35c")]
const FAMILLES := [Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("5b9bd5")]
const MAX_COCHES := 6

## Potentiel en chiffre pour la courbe (milieu de la fourchette connue), sinon le niveau.
static func potentiel(player: Dictionary, defaut: float) -> float:
	var b: Dictionary = Knowledge.bounds(player, "potential", true)
	if b.is_empty() or b.get("min") == null: return defaut
	return (float(b.min) + float(b.get("max", b.min))) / 2.0

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

# --- Données ---------------------------------------------------------------------------------------------------------

static func _hash(texte: String) -> int:
	return absi(hash(texte))

## Écart sur 12 mois d'une qualité (planche : âge du joueur et famille, déterministe).
static func _ecart(player: Dictionary, cle: String, famille: int) -> int:
	var age := int(player.get("age", 26))
	var h := _hash(str(player.get("id", "")) + ":" + cle) % 100
	var base := 2 if age <= 22 else 1 if age <= 26 else 0
	if age >= 31 and famille == 2: base = -1
	if h < 36: return 0
	if h < 42: return -1
	if h < 50: return maxi(0, base - 1)
	if h < 75: return base
	if h < 92: return base + 1
	return base + 2

## 13 relevés mensuels (il y a 12 mois → aujourd'hui) de la qualité `cle`.
static func serie(player: Dictionary, cle: String, valeur: float, famille: int) -> Array[float]:
	var e := _ecart(player, cle, famille)
	var depart := valeur - e
	var h := _hash(str(player.get("id", "")) + "/" + cle)
	var sortie: Array[float] = []
	for m in 13:
		var t := float(m) / 12.0
		# Paliers : la qualité monte par à-coups (séances, matchs), jamais en ligne droite.
		var palier := floorf(t * absf(e) + .35 + float((h >> m) & 1) * .3) if e != 0 else 0.0
		palier = minf(palier, absf(e))
		if m > 0: palier = maxf(palier, absf(sortie[m - 1] - depart))
		sortie.append(depart + signf(e) * palier)
	sortie[12] = valeur
	return sortie

static func valeurs(player: Dictionary) -> Dictionary:
	var v: Variant = player.get("attributesV2")
	return v if v is Dictionary and v.size() == 36 else {}

## [{cle, libelle, famille, valeur, ecart, serie}] pour les 36 qualités.
static func qualites(player: Dictionary) -> Array:
	var v := valeurs(player)
	var sortie: Array = []
	for f in PlayerAttributes.GROUPS.size():
		for pair: Array in PlayerAttributes.GROUPS[f][1]:
			var valeur: Variant = v.get(pair[0])
			if not (valeur is int or valeur is float): continue
			var s := serie(player, str(pair[0]), float(valeur), f)
			sortie.append({"cle": pair[0], "libelle": pair[1], "famille": f, "valeur": float(valeur), "ecart": int(roundf(s[12] - s[0])), "serie": s})
	return sortie

## Niveau général sur 12 mois (somme des écarts / 6, arrondie), finit sur le niveau actuel.
static func niveau(player: Dictionary, liste: Array) -> Array[float]:
	var actuel := float(player.get("rating", 60))
	var sortie: Array[float] = []
	for m in 13:
		var total := 0.0
		for q: Dictionary in liste: total += float(q.serie[m]) - float(q.serie[12])
		sortie.append(actuel + roundf(total / maxf(1.0, liste.size()) * 1.4))
	return sortie

static func moyenne_famille(liste: Array, famille: int) -> Array[float]:
	var sortie: Array[float] = []
	for m in 13:
		var total := 0.0
		var n := 0
		for q: Dictionary in liste:
			if int(q.famille) == famille:
				total += float(q.serie[m])
				n += 1
		sortie.append(total / maxf(1, n))
	return sortie

## Libellés des 13 mois, le dernier = mois de la date du jeu.
static func mois(app: Control) -> Array[String]:
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	var p := today.split("-")
	var dernier := int(p[1]) - 1 if p.size() >= 2 and p[1].is_valid_int() else 10
	var sortie: Array[String] = []
	for k in 13: sortie.append(MOIS[posmod(dernier - 12 + k, 12)])
	return sortie

# --- État ------------------------------------------------------------------------------------------------------------

static func etat(app: Control, player: Dictionary, liste: Array, par_defaut: String) -> Dictionary:
	var e: Variant = app.management_ui.get("progression")
	if e is Dictionary and str(e.get("joueur", "")) == str(player.get("id", "")): return e
	var tri := liste.duplicate()
	tri.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.ecart) > int(b.ecart) or (int(a.ecart) == int(b.ecart) and float(a.valeur) > float(b.valeur)))
	var coches: Array = []
	for q: Dictionary in tri.slice(0, 3): coches.append(q.cle)
	var neuf := {"joueur": str(player.get("id", "")), "coches": coches, "vue": par_defaut, "tri": "ecart", "familles": [0, 1, 2, 3] if par_defaut == "niveau" else []}
	app.management_ui["progression"] = neuf
	return neuf

static func _basculer(app: Control, e: Dictionary, cle: String) -> void:
	var coches: Array = e.coches
	if cle in coches: coches.erase(cle)
	elif coches.size() < MAX_COCHES: coches.append(cle)
	else:
		coches.pop_front()
		coches.append(cle)
	app._render()

static func _vue(app: Control, e: Dictionary, vue: String) -> void:
	e.vue = vue
	app._render()

static func teinte(e: Dictionary, cle: String) -> Color:
	var i: int = (e.coches as Array).find(cle)
	return TEINTES[i % TEINTES.size()] if i >= 0 else Charte.IVOIRE_3

# --- Courbes ---------------------------------------------------------------------------------------------------------

## Courbe multi-séries : [{valeurs: Array[float], couleur, libelle, pointille}], axe Y bas/haut, 13 mois en X.
class Courbe extends Control:
	var series: Array = []
	var etiquettes: Array[String] = []
	var bas := 20.0
	var haut := 100.0
	var pas := 10.0

	func _y(v: float, top: float, bottom: float) -> float:
		return lerpf(bottom, top, inverse_lerp(bas, haut, v))

	func _draw() -> void:
		var font: Font = C.font(600)
		var px := maxi(12, C.px(18))
		var left := float(C.px(56))
		var right := size.x - C.px(150)
		var top := float(C.px(16))
		var bottom := size.y - C.px(40)
		var v := bas
		while v <= haut + .01:
			var y := _y(v, top, bottom)
			draw_line(Vector2(left, y), Vector2(right, y), Color(Charte.FILET, .9), 1.0)
			draw_string(font, Vector2(0, y + px * .35), str(roundi(v)), HORIZONTAL_ALIGNMENT_RIGHT, left - C.px(12), px, Charte.IVOIRE_3)
			v += pas
		for k in etiquettes.size():
			var x := lerpf(left, right, float(k) / 12.0)
			if k % 2 == 0 or k == 12:
				var mot := "auj." if k == 12 else etiquettes[k]
				var large := font.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				draw_string(font, Vector2(x - large / 2.0, size.y - C.px(8)), mot, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Charte.IVOIRE_2)
				draw_line(Vector2(x, bottom), Vector2(x, bottom + C.px(6)), Charte.IVOIRE_3, 1.0)
		var fin_y: Array[float] = []
		for s: Dictionary in series:
			var points := PackedVector2Array()
			var vals: Array = s.valeurs
			for k in vals.size(): points.append(Vector2(lerpf(left, right, float(k) / 12.0), _y(float(vals[k]), top, bottom)))
			var couleur: Color = s.couleur
			var epais := maxf(2.0, C.px(4 if not s.get("fin", false) else 2))
			if s.get("pointille", false):
				for k in points.size() - 1: draw_dashed_line(points[k], points[k + 1], couleur, maxf(1.5, C.px(2.5)), C.px(10))
			else:
				draw_polyline(points, couleur, epais, true)
				draw_circle(points[-1], maxf(3.0, C.px(7)), couleur, true, -1, true)
			# Étiquette en bout de courbe, décalée si elle chevauche la précédente.
			var ey := points[-1].y
			for autre: float in fin_y:
				if absf(autre - ey) < px * 1.15: ey = autre + px * 1.15
			fin_y.append(ey)
			var libelle := "%s %s" % [str(s.get("court", "")), str(roundi(float(vals[-1])))]
			draw_string(font, Vector2(right + C.px(16), ey + px * .35), libelle, HORIZONTAL_ALIGNMENT_LEFT, C.px(134), px, couleur)

## Mini-courbe d'une ligne (12 mois), couleur de l'écart.
class MiniCourbe extends Control:
	var valeurs: Array[float] = []
	var couleur := Charte.IVOIRE_2

	func _draw() -> void:
		if valeurs.size() < 2: return
		var lo: float = valeurs.min() - 1.0
		var hi: float = valeurs.max() + 1.0
		var points := PackedVector2Array()
		for k in valeurs.size():
			points.append(Vector2(lerpf(2, size.x - 6, float(k) / (valeurs.size() - 1)), lerpf(size.y - 3, 3, inverse_lerp(lo, hi, valeurs[k]))))
		draw_line(Vector2(0, points[0].y), Vector2(size.x, points[0].y), Color(Charte.FILET, .9), 1.0)
		draw_polyline(points, couleur, maxf(1.5, C.px(3)), true)
		draw_circle(points[-1], maxf(2.5, C.px(4.5)), couleur, true, -1, true)

# --- Pièces communes ---------------------------------------------------------------------------------------------------

static func _pilule(parent: Control, zone: Rect2, texte: String, choisi: bool, id: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = texte
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Charte.texte_moyen() if choisi else C.BODY)
	b.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for etat_police in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(etat_police, Charte.PANNEAU if choisi else Charte.IVOIRE_2)
	var fond := C.box(Charte.IVOIRE if choisi else Color.TRANSPARENT, Color.TRANSPARENT if choisi else Color(Charte.CREME, .25), Charte.RAYON_PILULE, 10)
	if not choisi: fond.set_border_width_all(1)
	var survol := C.box(Charte.IVOIRE if choisi else Charte.PANNEAU_2, Color(Charte.CREME, .25), Charte.RAYON_PILULE, 10)
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, Charte.sans_ombre(fond))
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, Charte.sans_ombre(survol))
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

static func _ligne_bouton(parent: Control, zone: Rect2, id: String, marque: bool, action: Callable, tip: String) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	var fond := Charte.sans_ombre(C.box(Charte.SELECTION if marque else Color.TRANSPARENT, Color.TRANSPARENT, 6, 0))
	var survol := Charte.sans_ombre(C.box(Charte.PANNEAU_2 if not marque else Color("24473a"), Color(Charte.CREME, .3), 6, 0))
	survol.set_border_width_all(1)
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, fond)
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, survol)
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

## « ▲ 2 » vert, « ▼ 1 » rouge, « = » gris : forme + couleur.
static func _ecart_texte(parent: Control, x: float, y: float, ecart: int, taille: int, largeur: float, id: String) -> Label:
	var texte := "▲ %d" % ecart if ecart > 0 else "▼ %d" % absi(ecart) if ecart < 0 else "="
	var couleur := Charte.GAIN if ecart > 0 else Charte.PERTE if ecart < 0 else Charte.IVOIRE_3
	var l := D.text(parent, x, y, texte, taille, couleur, 800, largeur, HORIZONTAL_ALIGNMENT_RIGHT)
	l.name = id
	return l

static func _tuile(parent: Control, zone: Rect2, titre: String, chiffre: String, couleur: Color, sous: String, sous_couleur: Color, id: String, action: Callable) -> void:
	var b := _ligne_bouton(parent, zone, id, false, action, titre)
	b.add_theme_stylebox_override("normal", Charte.sans_ombre(C.box(Color(couleur, .12), Color.TRANSPARENT, Charte.RAYON_CARTE, 0)))
	D.text(parent, zone.position.x + 16, zone.position.y + 26, titre, 15, Charte.IVOIRE_2, 700, zone.size.x - 32)
	var n := D.text(parent, zone.position.x + 16, zone.position.y + zone.size.y - 14, chiffre, 38, couleur, 800, 110)
	n.add_theme_font_override("font", Charte.TITRE_FICHE)
	if not sous.is_empty(): D.text(parent, zone.position.x + zone.size.x - 16, zone.position.y + zone.size.y - 18, sous, 21, sous_couleur, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)

static func _specialisation(card: Control, app: Control, player: Dictionary, zone: Rect2) -> void:
	var record := Academy.professional_progress(app, str(player.get("id", "")))
	var development: Dictionary = record.get("development", {}) if record.get("development") is Dictionary else {}
	var choix := {}
	for option: Variant in development.get("options", []):
		if option is Dictionary: choix[option.get("id")] = option.get("label")
	if choix.is_empty(): return
	var control := Academy._option("ProgressionFocus", "Spécialisation", choix, development.get("focus"), func(value):
		app._command("set_development_focus", {"playerId": record.get("id", player.get("id")), "focus": value}))
	control.disabled = not development.get("available", false)
	card.add_child(control)
	D.place(control, zone)

static func _saisons(card: Control, app: Control, player: Dictionary, x: float, y: float, largeur: float) -> void:
	var record := Academy.professional_progress(app, str(player.get("id", "")))
	var development: Dictionary = record.get("development", {}) if record.get("development") is Dictionary else {}
	var history: Array = development.get("history", []) if development.get("history") is Array else []
	D.text(card, x, y, "SAISONS", 15, Charte.IVOIRE_3, 700, 200)
	if history.is_empty():
		D.text(card, x, y + 34, "—", 22, Charte.IVOIRE_3, 700, 60)
		return
	for i in mini(3, history.size()):
		var an: Dictionary = history[history.size() - 1 - i]
		var debut := int(an.get("start", 0))
		var fin := int(an.get("end", 0))
		D.text(card, x, y + 34 + i * 32, G.season_label(an.get("season", "—")), 19, Charte.IVOIRE_2, 600, 140)
		D.text(card, x + 150, y + 34 + i * 32, "%d → %d" % [debut, fin], 19, Charte.IVOIRE, 700, 120)
		_ecart_texte(card, x + largeur, y + 34 + i * 32, fin - debut, 19, 70, "ProgressionSaison%d" % i)

# --- Option A : courbe en haut, grille cochable ------------------------------------------------------------------------

static func construire_a(page: Control, app: Control, player: Dictionary, top: float) -> void:
	var liste := qualites(player)
	var e := etat(app, player, liste, "qualites")
	var etiquettes := mois(app)
	var haut := D.panel(page, Rect2(0, top, 2248, 480), "", "", "", "ProgressionCourbeCarte")
	var titre := D.text(haut, 24, 46, "PROGRESSION · 12 MOIS", 26, Charte.IVOIRE, 700, 520)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	_pilule(haut, Rect2(560, 16, 150, 40), "Qualités", e.vue == "qualites", "ProgressionVue_qualites", func(): _vue(app, e, "qualites"))
	_pilule(haut, Rect2(720, 16, 150, 40), "Niveau", e.vue == "niveau", "ProgressionVue_niveau", func(): _vue(app, e, "niveau"))
	var niv := niveau(player, liste)
	var gain := int(niv[12] - niv[0])
	_tuile(haut, Rect2(1290, 10, 220, 74), "NIVEAU", G.n(roundi(niv[12])), Charte.IVOIRE, ("▲ %d" % gain) if gain > 0 else ("▼ %d" % absi(gain)) if gain < 0 else "=", Charte.GAIN if gain >= 0 else Charte.PERTE, "ProgressionTuileNiveau", func(): _vue(app, e, "niveau"))
	_tuile(haut, Rect2(1522, 10, 220, 74), "POTENTIEL", G.potential_text(player), Charte.CONFIANCE, "", Charte.IVOIRE, "ProgressionTuilePotentiel", func(): _vue(app, e, "niveau"))
	_specialisation(haut, app, player, Rect2(1760, 24, 466, 46))
	var courbe := Courbe.new()
	courbe.name = "ProgressionCourbe"
	courbe.etiquettes = etiquettes
	courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.vue == "niveau":
		courbe.series.append({"valeurs": niv, "couleur": Charte.IVOIRE, "court": "Niveau"})
		var pot: Array[float] = []
		for k in 13: pot.append(potentiel(player, niv[12]))
		courbe.series.append({"valeurs": pot, "couleur": Charte.CONFIANCE, "court": "Potentiel", "pointille": true})
		_cadre_y(courbe, niv + pot)
		haut.add_child(courbe)
		D.place(courbe, Rect2(24, 96, 1700, 370))
		_saisons(haut, app, player, 1780, 140, 440)
	else:
		var vals: Array[float] = []
		for q: Dictionary in liste:
			if q.cle in e.coches:
				courbe.series.append({"valeurs": q.serie, "couleur": teinte(e, q.cle), "court": _court(str(q.libelle))})
				vals.append_array(q.serie)
		_cadre_y(courbe, vals)
		haut.add_child(courbe)
		D.place(courbe, Rect2(24, 96, 2200, 370))
	# Grille des 36 qualités à cocher.
	var bas_y := top + 496
	var grille := D.panel(page, Rect2(0, bas_y, 2248, 1246 - bas_y), "", "", "", "ProgressionGrille")
	var colonne := (2248.0 - 48 - 3 * 28) / 4.0
	for f in PlayerAttributes.GROUPS.size():
		var x := 24 + f * (colonne + 28)
		D.rect(grille, Rect2(x, 18, 6, 26), FAMILLES[f], 3)
		D.text(grille, x + 16, 40, str(PlayerAttributes.GROUPS[f][0]).to_upper(), 18, Charte.IVOIRE, 700, colonne - 100)
		D.text(grille, x + colonne - 70, 40, "12 MOIS", 14, Charte.IVOIRE_3, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		var j := 0
		for q: Dictionary in liste:
			if int(q.famille) != f: continue
			var y := 50 + j * 38.0
			var coche: bool = q.cle in e.coches
			var c := teinte(e, q.cle)
			var cle := str(q.cle)
			_ligne_bouton(grille, Rect2(x - 6, y, colonne + 12, 36), "ProgressionCoche_" + cle, coche, func(): _basculer(app, e, cle), "%s · %s" % [q.libelle, "retirer de la courbe" if coche else "voir sur la courbe"])
			# Case : rond plein à la couleur de la courbe quand coché, anneau vide sinon.
			if coche: D.rect(grille, Rect2(x + 4, y + 8, 20, 20), c, 10)
			else: D.rect(grille, Rect2(x + 4, y + 8, 20, 20), Color.TRANSPARENT, 10, Color(Charte.CREME, .45))
			D.text(grille, x + 36, y + 25, q.libelle, 20, Charte.IVOIRE if coche else Charte.IVOIRE_2, 600 if coche else 500, colonne - 160, HORIZONTAL_ALIGNMENT_LEFT, true)
			if int(q.ecart) != 0: _ecart_texte(grille, x + colonne - 56, y + 25, int(q.ecart), 18, 70, "ProgressionEcart_" + cle)
			D.text(grille, x + colonne, y + 26, G.n(roundi(float(q.valeur))), 23, Charte.couleur_attribut(q.valeur), 700, 46, HORIZONTAL_ALIGNMENT_RIGHT).name = "ProgressionNote_" + cle
			j += 1

static func _court(libelle: String) -> String:
	return libelle if libelle.length() <= 11 else libelle.substr(0, 10).strip_edges() + "."

static func _cadre_y(courbe: Courbe, vals: Array) -> void:
	if vals.is_empty(): return
	var lo: float = vals.min()
	var hi: float = vals.max()
	courbe.pas = 5.0 if hi - lo <= 25 else 10.0
	courbe.bas = maxf(0.0, floorf((lo - 3) / courbe.pas) * courbe.pas)
	courbe.haut = minf(100.0, ceilf((hi + 3) / courbe.pas) * courbe.pas)

# --- Option B : liste triée par progression + courbe à droite ----------------------------------------------------------

static func construire_b(page: Control, app: Control, player: Dictionary, top: float) -> void:
	var liste := qualites(player)
	var e := etat(app, player, liste, "niveau")
	var familles: Array = e.get("familles", [])
	var gauche := D.panel(page, Rect2(0, top, 1440, 1246 - top), "", "", "", "ProgressionListe")
	var titre := D.text(gauche, 24, 46, "QUALITÉS · 12 MOIS", 26, Charte.IVOIRE, 700, 520)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var tri := liste.duplicate()
	match str(e.tri):
		"note": tri.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.valeur) > float(b.valeur))
		"qualite": tri.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.libelle) < str(b.libelle))
		_: tri.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.ecart) > int(b.ecart) or (int(a.ecart) == int(b.ecart) and float(a.valeur) > float(b.valeur)))
	# Compteurs en pastilles : qualités en hausse / stables / en baisse.
	var hausse := tri.filter(func(q: Dictionary): return int(q.ecart) > 0).size()
	var baisse := tri.filter(func(q: Dictionary): return int(q.ecart) < 0).size()
	D.rect(gauche, Rect2(1016, 20, 120, 34), Color(Charte.GAIN, .16), 17)
	D.text(gauche, 1076, 44, "▲ %d" % hausse, 20, Charte.GAIN, 800, 120, HORIZONTAL_ALIGNMENT_CENTER).name = "ProgressionHausse"
	D.rect(gauche, Rect2(1146, 20, 120, 34), Color(Charte.IVOIRE_3, .16), 17)
	D.text(gauche, 1206, 44, "= %d" % (tri.size() - hausse - baisse), 20, Charte.IVOIRE_2, 800, 120, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(gauche, Rect2(1276, 20, 120, 34), Color(Charte.PERTE, .16), 17)
	D.text(gauche, 1336, 44, "▼ %d" % baisse, 20, Charte.PERTE, 800, 120, HORIZONTAL_ALIGNMENT_CENTER).name = "ProgressionBaisse"
	var largeur := 676.0
	for col in 2:
		var x := 24 + col * (largeur + 40)
		var entete_y := 96.0
		_tri_entete(gauche, app, e, Rect2(x + 22, entete_y - 22, 200, 30), "QUALITÉ", "qualite", "ProgressionTri_qualite%d" % col)
		D.text(gauche, x + 300, entete_y, "12 MOIS", 15, Charte.IVOIRE_3, 700, 200)
		_tri_entete(gauche, app, e, Rect2(x + 500, entete_y - 22, 90, 30), "ÉCART", "ecart", "ProgressionTri_ecart%d" % col)
		_tri_entete(gauche, app, e, Rect2(x + 600, entete_y - 22, 76, 30), "NOTE", "note", "ProgressionTri_note%d" % col)
		D.line(gauche, Vector2(x, entete_y + 10), Vector2(x + largeur, entete_y + 10), Color(Charte.FILET, .9))
		for r in 18:
			var i := col * 18 + r
			if i >= tri.size(): break
			var q: Dictionary = tri[i]
			var y := entete_y + 16 + r * 44.0
			var cle := str(q.cle)
			var coche: bool = cle in e.coches
			_ligne_bouton(gauche, Rect2(x - 6, y, largeur + 12, 42), "ProgressionLigne_" + cle, coche, func(): _basculer(app, e, cle), "%s · %s" % [q.libelle, "retirer de la courbe" if coche else "voir sur la courbe"])
			# Liseré de famille à gauche ; rond à la couleur de la courbe quand la ligne y est posée.
			D.rect(gauche, Rect2(x, y + 8, 5, 26), FAMILLES[int(q.famille)], 2)
			if coche: D.rect(gauche, Rect2(x + 14, y + 13, 16, 16), teinte(e, cle), 8)
			D.text(gauche, x + 40, y + 29, q.libelle, 20, Charte.IVOIRE, 600 if coche else 500, 250, HORIZONTAL_ALIGNMENT_LEFT, true)
			var mini := MiniCourbe.new()
			mini.name = "ProgressionMini_" + cle
			mini.valeurs = q.serie
			mini.couleur = teinte(e, cle) if coche else (Charte.GAIN if int(q.ecart) > 0 else Charte.PERTE if int(q.ecart) < 0 else Charte.IVOIRE_3)
			mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gauche.add_child(mini)
			D.place(mini, Rect2(x + 300, y + 6, 180, 30))
			_ecart_texte(gauche, x + 580, y + 29, int(q.ecart), 20, 80, "ProgressionEcart_" + cle)
			D.text(gauche, x + largeur, y + 30, G.n(roundi(float(q.valeur))), 24, Charte.couleur_attribut(q.valeur), 700, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	# Colonne droite : courbe Niveau / Qualités, familles en légende cliquable, saisons, spécialisation.
	var droite := D.panel(page, Rect2(1456, top, 792, 1246 - top), "", "", "", "ProgressionCourbeCarte")
	_pilule(droite, Rect2(24, 16, 150, 40), "Niveau", e.vue == "niveau", "ProgressionVue_niveau", func(): _vue(app, e, "niveau"))
	_pilule(droite, Rect2(184, 16, 150, 40), "Qualités", e.vue == "qualites", "ProgressionVue_qualites", func(): _vue(app, e, "qualites"))
	var niv := niveau(player, liste)
	var gain := int(niv[12] - niv[0])
	var n := D.text(droite, 768, 52, G.n(roundi(niv[12])), 44, Charte.IVOIRE, 800, 100, HORIZONTAL_ALIGNMENT_RIGHT)
	n.add_theme_font_override("font", Charte.TITRE_FICHE)
	_ecart_texte(droite, 660, 48, gain, 22, 80, "ProgressionGainNiveau")
	var courbe := Courbe.new()
	courbe.name = "ProgressionCourbe"
	courbe.etiquettes = mois(app)
	courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vals: Array[float] = []
	if e.vue == "niveau":
		courbe.series.append({"valeurs": niv, "couleur": Charte.IVOIRE, "court": "Niveau"})
		var pot: Array[float] = []
		for k in 13: pot.append(potentiel(player, niv[12]))
		courbe.series.append({"valeurs": pot, "couleur": Charte.CONFIANCE, "court": "Potent.", "pointille": true})
		vals.append_array(niv)
		vals.append_array(pot)
		for f: int in familles:
			var m := moyenne_famille(liste, f)
			courbe.series.append({"valeurs": m, "couleur": FAMILLES[f], "court": _court(str(PlayerAttributes.GROUPS[f][0]).split(" ")[0]), "fin": true})
			vals.append_array(m)
	else:
		for q: Dictionary in liste:
			if q.cle in e.coches:
				courbe.series.append({"valeurs": q.serie, "couleur": teinte(e, q.cle), "court": _court(str(q.libelle))})
				vals.append_array(q.serie)
	_cadre_y(courbe, vals)
	droite.add_child(courbe)
	D.place(courbe, Rect2(16, 84, 760, 400))
	# Familles : moyenne et écart, un clic pose la famille sur la courbe Niveau.
	D.text(droite, 24, 530, "FAMILLES", 15, Charte.IVOIRE_3, 700, 200)
	for f in 4:
		var m := moyenne_famille(liste, f)
		var y := 546 + f * 46.0
		var marque: bool = f in familles
		var ff := f
		_ligne_bouton(droite, Rect2(16, y, 760, 42), "ProgressionFamille%d" % f, marque, func(): _famille(app, e, ff), str(PlayerAttributes.GROUPS[f][0]))
		D.rect(droite, Rect2(28, y + 13, 16, 16), FAMILLES[f], 8)
		D.text(droite, 56, y + 29, PlayerAttributes.GROUPS[f][0], 20, Charte.IVOIRE, 600, 480, HORIZONTAL_ALIGNMENT_LEFT, true)
		_ecart_texte(droite, 680, y + 29, int(roundf(m[12] - m[0])), 20, 80, "ProgressionFamilleEcart%d" % f)
		D.text(droite, 760, y + 30, G.n(roundi(m[12])), 24, Charte.couleur_attribut(m[12]), 700, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	_saisons(droite, app, player, 24, 756, 360)
	D.text(droite, 420, 756, "POTENTIEL", 15, Charte.IVOIRE_3, 700, 200)
	var pot_l := D.text(droite, 420, 812, G.potential_text(player), 44, Charte.CONFIANCE, 800, 140)
	pot_l.add_theme_font_override("font", Charte.TITRE_FICHE)
	_specialisation(droite, app, player, Rect2(420, 834, 350, 46))

static func _famille(app: Control, e: Dictionary, f: int) -> void:
	var familles: Array = e.get("familles", [])
	if f in familles: familles.erase(f)
	else: familles.append(f)
	e.familles = familles
	e.vue = "niveau"
	app._render()

static func _tri_entete(parent: Control, app: Control, e: Dictionary, zone: Rect2, texte: String, cle: String, id: String) -> void:
	var actif := str(e.tri) == cle
	var b := Button.new()
	b.name = id
	b.text = texte + (" ▼" if actif else "")
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", C.font(700))
	b.add_theme_font_size_override("font_size", maxi(12, C.px(15)))
	for s in ["font_color", "font_focus_color", "font_pressed_color"]: b.add_theme_color_override(s, Charte.IVOIRE if actif else Charte.IVOIRE_3)
	b.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	b.pressed.connect(func():
		e.tri = cle
		app._render())
	parent.add_child(b)
	D.place(b, zone)
