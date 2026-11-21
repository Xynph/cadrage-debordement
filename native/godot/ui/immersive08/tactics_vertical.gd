extends RefCounted
## Composition, terrain vertical vert (Léo, 21/11/2026 : « ce terrain est juste immonde », écran « pas assez coloré ») :
## deux options à départager sur captures, CD_VARIANTE_VISUELLE=TERRAIN_A | TERRAIN_B (sans variante : écran actuel).
## - A : terrain plein cadre vu du dessus, gazon du direct 2D, cartes flottantes (portrait rond + pastille au poste) ;
## - B : terrain sur une plaque en légère perspective (le haut fuit), cartes pleines plus grandes.
## Commun : notre en-but en bas, attaque vers le haut ; banc en tuiles portraits, doublures en cases colorées, impact en
## barres colorées (▲ vert / ▼ rouge, jamais la couleur seule), candidats dessous. Mêmes noms de nœuds, mêmes clics,
## même glisser-déposer et mêmes touches que l'écran actuel (tactics_terrain.gd, tactics_banc.gd).
## Exemple : `Vertical.build(app, page, choisir, clavier, avis, bleus, premiere)` quand `Vertical.variante() != ""`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Poste = preload("res://ui/immersive08/tactics_poste.gd")
const Impact = preload("res://ui/immersive08/tactics_impact.gd")
const Candidats = preload("res://ui/immersive08/tactics_candidats.gd")
const Visuels = preload("res://ui/contextual/training_visuels.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")

## Bandeau du terrain (titre, légende) au-dessus de la pelouse.
const BANDEAU := Rect2(0, 190, 770, 40)
const TERRAIN := Rect2(0, 238, 770, 1060)
const DROITE := 794.0
const BANC := Rect2(794, 192, 868, 452)
const DOUBLURES := Rect2(794, 660, 868, 240)
const IMPACT := Rect2(1678, 192, 570, 708)
const CANDIDATS := Rect2(794, 916, 1454, 382)

## Mètres : en-buts de 5 m (lisibles sans écraser le jeu), 100 m entre les lignes d'essai, 70 m de large.
const EN_BUT := 5.0
const LONGUEUR := 110.0
const LARGEUR := 70.0

## Place de chaque numéro : x en fraction de la largeur, y en fraction de la hauteur (0 = en haut, adversaire).
## Schéma de jeu : avants groupés en bas (1-2-3, 4-5, 6-8-7), charnière, centres et ailiers, arrière en haut.
const PLACES := {1: Vector2(.27, .81), 2: Vector2(.5, .81), 3: Vector2(.73, .81), 4: Vector2(.38, .69), 5: Vector2(.62, .69),
	6: Vector2(.2, .57), 8: Vector2(.5, .57), 7: Vector2(.8, .57), 9: Vector2(.38, .455), 10: Vector2(.63, .35),
	11: Vector2(.11, .22), 12: Vector2(.37, .22), 13: Vector2(.63, .22), 14: Vector2(.89, .22), 15: Vector2(.5, .085)}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return "A" if v == "TERRAIN_A" else ("B" if v == "TERRAIN_B" else "")

# --- Terrain ---------------------------------------------------------------------------------------------------------

## Pelouse vue du dessus (A) ou en légère perspective (B) : bandes de tonte de 10 m, lignes blanches du XV (essai, 22 m,
## 10 m en tirets, médiane, 5 m et 15 m en tirets, poteaux), en-buts plus sombres.
class Pelouse extends Control:
	var fuite := 0.0
	## Rectangle du terrain dans le contrôle (pixels), en-buts compris.
	var cadre := Rect2()

	func point(x_m: float, y_m: float) -> Vector2:
		# y_m : 0 = fond de l'en-but adverse (haut), LONGUEUR = fond de notre en-but (bas).
		var t := y_m / LONGUEUR
		var echelle := lerpf(1.0 - fuite, 1.0, t)
		var cx := cadre.position.x + cadre.size.x / 2.0
		var y := cadre.position.y + cadre.size.y * (t if fuite <= 0.0 else (t * (1.0 - fuite * .35) + fuite * .35 * t * t))
		return Vector2(cx + (x_m / LARGEUR - .5) * cadre.size.x * echelle, y)

	func _quad(y0: float, y1: float, couleur: Color) -> void:
		draw_colored_polygon(PackedVector2Array([point(0, y0), point(LARGEUR, y0), point(LARGEUR, y1), point(0, y1)]), couleur)

	func _ligne(y_m: float, couleur: Color, epaisseur: float, tirets: bool = false) -> void:
		if tirets: draw_dashed_line(point(0, y_m), point(LARGEUR, y_m), couleur, epaisseur, maxf(4.0, C.px(14)))
		else: draw_line(point(0, y_m), point(LARGEUR, y_m), couleur, epaisseur, true)

	func _draw() -> void:
		var fine := maxf(1.5, C.px(3))
		# Gazon et bandes de tonte (10 m), en-buts assombris.
		_quad(0, LONGUEUR, Terrain2D.GAZON)
		for k in 10:
			if k % 2 == 1: _quad(EN_BUT + k * 10.0, EN_BUT + (k + 1) * 10.0, Terrain2D.GAZON_TONTE)
		_quad(0, EN_BUT, Color(0, 0, 0, .14))
		_quad(LONGUEUR - EN_BUT, LONGUEUR, Color(0, 0, 0, .14))
		var blanc := Color(1, 1, 1, .92)
		var pale := Color(1, 1, 1, .6)
		# Lignes pleines : ballon mort, essai, 22 m, médiane ; tirets : 10 m, 5 m devant l'essai.
		for y: float in [0.0, LONGUEUR]: _ligne(y, blanc, fine)
		for y: float in [EN_BUT, LONGUEUR - EN_BUT]: _ligne(y, blanc, fine * 1.4)
		for y: float in [EN_BUT + 22.0, LONGUEUR - EN_BUT - 22.0, LONGUEUR / 2.0]: _ligne(y, blanc, fine)
		for y: float in [EN_BUT + 40.0, LONGUEUR - EN_BUT - 40.0]: _ligne(y, pale, fine, true)
		for y: float in [EN_BUT + 5.0, LONGUEUR - EN_BUT - 5.0]: _ligne(y, pale, fine * .8, true)
		# Touches, puis lignes des 5 m et des 15 m parallèles à la touche (tirets).
		draw_line(point(0, 0), point(0, LONGUEUR), blanc, fine, true)
		draw_line(point(LARGEUR, 0), point(LARGEUR, LONGUEUR), blanc, fine, true)
		for x: float in [5.0, 15.0, LARGEUR - 15.0, LARGEUR - 5.0]:
			draw_dashed_line(point(x, EN_BUT), point(x, LONGUEUR - EN_BUT), Color(1, 1, 1, .32), fine * .8, maxf(4.0, C.px(14)))
		# Poteaux (5,6 m entre les montants) sur chaque ligne d'essai.
		for y: float in [EN_BUT, LONGUEUR - EN_BUT]:
			var a := point(LARGEUR / 2.0 - 2.8, y)
			var b := point(LARGEUR / 2.0 + 2.8, y)
			draw_line(a, b, Charte.IVOIRE, fine * 2.2, true)
			for p: Vector2 in [a, b]: draw_circle(p, fine * 2.4, Charte.IVOIRE)

static func _pelouse(page: Control, v: String) -> Pelouse:
	var pelouse := Pelouse.new()
	pelouse.name = "TacticsPitch"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if v == "B":
		# Plaque : panneau sombre arrondi, ombre, pelouse en légère perspective.
		var plaque := D.rect(page, TERRAIN, Charte.PANNEAU, Charte.RAYON_PANNEAU)
		plaque.name = "TacticsPitchPlate"
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(pelouse)
	D.place(pelouse, TERRAIN)
	# A : plein cadre (la largeur s'étire un peu au-delà de l'échelle pour remplir la colonne) ; B : plaque, marge.
	var marge := 22.0 if v == "B" else 0.0
	var h := TERRAIN.size.y - 2.0 * marge
	var w := TERRAIN.size.x - 2.0 * marge
	pelouse.fuite = 0.18 if v == "B" else 0.0
	pelouse.cadre = Rect2(marge * C.density, marge * C.density, w * C.density, h * C.density)
	return pelouse

## Repères sans phrase : « XV DE DÉPART » et légende des pastilles au-dessus du terrain, flèche d'attaque sur l'en-but
## adverse (en haut), à côté des poteaux.
static func _reperes(page: Control, pelouse: Pelouse, v: String) -> void:
	var t := Kit.titre(page, 0, BANDEAU.position.y + 32, "XV DE DÉPART", 28, 300)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsPitchTitle"
	var legende := Control.new()
	legende.name = "TacticsPitchLegend"
	legende.mouse_filter = Control.MOUSE_FILTER_PASS
	legende.tooltip_text = "Note au poste /100 · 2e poste · dépanne · Espace prendre / poser"
	page.add_child(legende)
	var entrees := [["72", Charte.couleur_attribut(72), Charte.ENCRE], ["2e poste", Color(Charte.V_DALTONIEN, .22), Charte.V_DALTONIEN], ["Dépanne", Color(Charte.PERTE, .22), Charte.PERTE]]
	var total := Kit.largeur("au poste", 15) + 4
	for entree: Array in entrees: total += Kit.largeur(str(entree[0]), 15) + 22 + 8
	D.place(legende, Rect2(BANDEAU.end.x - total, BANDEAU.position.y + 6, total, 28))
	var x := 0.0
	for entree: Array in entrees:
		var l := Kit.largeur(str(entree[0]), 15) + 22
		var p := D.rect(legende, Rect2(x, 2, l, 24), entree[1], Charte.RAYON_PILULE)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(p, l / 2.0, 18, str(entree[0]), 15, entree[2], 700, l, HORIZONTAL_ALIGNMENT_CENTER, true)
		x += l + 8
	D.text(legende, x, 20, "au poste", 15, Charte.IVOIRE_2, 600, total - x + 4, HORIZONTAL_ALIGNMENT_LEFT, true)
	# Sens d'attaque : pastille sur l'en-but adverse, à droite des poteaux.
	var haut := pelouse.point(LARGEUR * .77, EN_BUT * .5) / C.density + TERRAIN.position
	var fleche := D.rect(page, Rect2(haut.x - 64, haut.y - 16, 128, 32), Color(Charte.PANNEAU, .88), Charte.RAYON_PILULE)
	fleche.name = "TacticsAttackDirection"
	fleche.mouse_filter = Control.MOUSE_FILTER_PASS
	fleche.tooltip_text = "Sens de l’attaque"
	D.text(fleche, 64, 23, "▲ ATTAQUE", 17, Charte.CONDITION, 700, 124, HORIZONTAL_ALIGNMENT_CENTER, true)

## Centre d'un numéro (unités du gabarit, dans la page) et échelle de sa carte.
static func _place(pelouse: Pelouse, numero: int) -> Array:
	var f: Vector2 = PLACES[numero]
	var p := pelouse.point(f.x * LARGEUR, f.y * LONGUEUR)
	var echelle := lerpf(1.0 - pelouse.fuite * .8, 1.0, f.y) if pelouse.fuite > 0.0 else 1.0
	return [p / C.density + TERRAIN.position, echelle]

# --- Cartes du XV ----------------------------------------------------------------------------------------------------

static func build(app: Control, page: Control, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, premiere: Dictionary) -> void:
	var v := variante()
	var pelouse := _pelouse(page, v)
	var pris: Dictionary = Selection.state(app).get("pris", {}) if Selection.state(app).get("pris") is Dictionary else {}
	var taille := Vector2(156, 132) if v == "A" else Vector2(160, 128)
	for numero: int in range(1, 16):
		var lieu := _place(pelouse, numero)
		var t: Vector2 = taille * float(lieu[1])
		carte(app, page, Rect2(lieu[0] - t / 2.0, t), numero - 1, choisir, clavier, avis, bleus, pris, v)
	_reperes(page, pelouse, v)
	banc(app, page, choisir, clavier, avis, bleus, premiere, pris)
	doublures(app, page, choisir)
	Impact.colore = true
	Impact.build(app, page, IMPACT, _adversaire(app), choisir)
	Impact.colore = false

static func _adversaire(app: Control) -> String:
	var Canvas: Script = load("res://ui/immersive08/tactics_canvas.gd")
	return Canvas._adversaire(app)

## Nom court en entier : la taille descend jusqu'à 13 plutôt que de couper.
static func _taille_nom(texte: String, largeur: float, taille: int) -> int:
	var t := taille
	while t > 13 and Kit.largeur(texte, t) > largeur: t -= 1
	return t

## Carte d'une place du XV : portrait rond (anneau = condition), ovale du numéro aux couleurs du club, nom entier
## (clic = fiche, survol = carte joueur), pastille de note au poste (+ « 2e poste » / « Dépanne »).
static func carte(app: Control, page: Control, zone: Rect2, slot: int, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, pris: Dictionary, v: String) -> Button:
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	var choisi: bool = app.selected_slot == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "LineupSlot%02d" % (slot + 1)
	var w := zone.size.x
	var h := zone.size.y
	# A : carte transparente (seule la pilule du nom est pleine) ; B : carte pleine arrondie.
	var fond := Color(Charte.PANNEAU, .9) if v == "B" else Color.TRANSPARENT
	var normal := C.box(fond, Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
	normal.set_border_width_all(3 if choisi else 0)
	var survol := C.box(Color(Charte.PANNEAU_3, .9) if v == "B" else Color(1, 1, 1, .1), Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
	survol.set_border_width_all(3 if choisi else 0)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
	focus.set_border_width_all(2)
	for etat in ["normal", "pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("hover_pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	page.add_child(bouton)
	D.place(bouton, zone)
	Selection.wire(bouton, app, id, slot, slot, str(person.get("name", "Poste vacant")))
	# Plaque du nom en bas (nom + pastille), portrait au-dessus : rien ne sort de la carte, même rétrécie (B).
	var bas_y := h - 56.0
	var cote := minf(bas_y - 6.0, 74.0)
	var accessible := "Poste n° %d · " % (slot + 1)
	if person.is_empty():
		var vide := D.rect(bouton, Rect2((w - cote) / 2.0, 6, cote, cote), Color(Charte.PANNEAU, .7), Charte.RAYON_PILULE, Charte.IVOIRE_2)
		vide.name = "TacticsEmpty%02d" % (slot + 1)
		D.text(vide, cote / 2.0, cote / 2.0 + 9, str(slot + 1), 26, Charte.IVOIRE, 700, cote, HORIZONTAL_ALIGNMENT_CENTER, true)
		var pilule_v := D.rect(bouton, Rect2(4, cote + 12, w - 8, 30), Color(Charte.PANNEAU, .88), Charte.RAYON_PILULE)
		pilule_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(pilule_v, (w - 8) / 2.0, 21, "Poste vide", 16, Charte.PERTE, 700, w - 12, HORIZONTAL_ALIGNMENT_CENTER, true)
		accessible += "vide"
	else:
		var portrait := Visuels.portrait_anneau(person, cote * C.density, maxf(3.0, 4.0 * C.density))
		portrait.name = "TacticsFace%02d" % (slot + 1)
		bouton.add_child(portrait)
		portrait.position = Vector2((w - cote) / 2.0, 4) * C.density
		portrait.size = Vector2(cote, cote) * C.density
		Kit.ovale(bouton, Rect2((w + cote) / 2.0 - 22, cote - 18, 38, 26), str(slot + 1), app.accent)
		# Pilule du nom + pastille au poste.
		var court := Kit.casse(str(person.get("name", "")), true)
		var pilule := D.rect(bouton, Rect2(2, bas_y, w - 4, h - bas_y - 2), Color(Charte.PANNEAU, .9), Charte.RAYON_CARTE)
		pilule.name = "TacticsCardPlate%02d" % (slot + 1)
		pilule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var taille := _taille_nom(court, w - 16, 18 if v == "B" else 17)
		var largeur_nom := minf(w - 12, Kit.largeur(court, taille) + 6)
		Kit.nom(app, bouton, Rect2((w - largeur_nom) / 2.0, bas_y + 1, largeur_nom, 26), court, id, "TacticsName%02d" % (slot + 1), Charte.IVOIRE, taille)
		var note: Variant = Selection.rating(app.model, person, slot)
		var familiarite := Selection.familiarite(app.model, person, slot)
		var forme: Variant = person.get("condition")
		var faible := (forme is int or forme is float) and float(forme) < 80
		var dispo := w - 12 - (52.0 if faible else 0.0)
		var abrege := Poste.largeur(note, familiarite, 20) > dispo
		var l := minf(dispo, Poste.largeur(note, familiarite, 20, abrege))
		var total := l + (52.0 if faible else 0.0)
		var valeur := Poste.poser(bouton, Rect2((w - total) / 2.0, bas_y + 30, l, 20), note, familiarite, "TacticsPositionRating%02d" % (slot + 1), false, abrege)
		accessible += "%s · %s" % [str(person.get("name", "")), Poste.accessible(note, familiarite)]
		if faible:
			var x := (w - total) / 2.0 + float(valeur.get_meta("largeur", l)) + 6
			var alerte := D.text(bouton, x, bas_y + 46, "%d %%" % roundi(float(forme)), 15, Charte.PERTE, 700, 50, HORIZONTAL_ALIGNMENT_LEFT, true)
			alerte.name = "TacticsCondition%02d" % (slot + 1)
			accessible += " · condition %d %%" % roundi(float(forme))
	if avis.has(slot):
		Kit.puce(bouton, Rect2(4, 4, 22, 24), "!", Charte.INTENSIF, Charte.ENCRE, "TacticsStaffAdviceMark%02d" % (slot + 1))
		accessible += " · " + str(avis[slot])
	if bleus.has(slot):
		Kit.puce(bouton, Rect2(w - 36, 4, 32, 24), "33", Charte.MORAL, Charte.ENCRE, "TacticsBleusMark%02d" % (slot + 1))
		accessible += " · liste des 33 : doit souffler"
	if not pris.is_empty():
		if str(pris.get("player_id", "")) == id and not id.is_empty():
			D.rect(bouton, Rect2(0, 0, w, 4), Charte.IVOIRE, Charte.RAYON_PILULE).name = "TacticsPris%02d" % (slot + 1)
		elif Selection.can_drop(app, Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))), slot):
			D.rect(bouton, Rect2(0, h - 4, w, 4), Charte.CONDITION, Charte.RAYON_PILULE).name = "TacticsCible%02d" % (slot + 1)
	bouton.accessibility_name = accessible
	bouton.pressed.connect(func(): choisir.call(slot))
	bouton.gui_input.connect(func(event: InputEvent): clavier.call(event, slot, bouton))
	return bouton

# --- Banc en tuiles --------------------------------------------------------------------------------------------------

static func _titre_bloc(bloc: Control, texte: String, largeur: float) -> void:
	var t := Kit.titre(bloc, 22, 40, texte, 26, largeur)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)

static func banc(app: Control, page: Control, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, premiere: Dictionary, pris: Dictionary) -> Panel:
	var bloc := D.rect(page, BANC, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	bloc.name = "TacticsBench"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var remplis := 0
	for slot in range(15, 23):
		if not Selection.occupant(app.model, slot).is_empty(): remplis += 1
	_titre_bloc(bloc, "BANC", 200)
	var w := BANC.size.x
	# Tuiles chiffres du titre : remplis / 8 et première ligne formée.
	var ok_banc := remplis >= 8
	_chip(bloc, Rect2(110, 14, 84, 32), "%d/8" % remplis, Charte.CONDITION if ok_banc else Charte.PERTE, "BenchCount")
	var formes := mini(int(premiere.formes), int(premiere.cible))
	var ok_pl := formes >= int(premiere.cible)
	var chip_pl := _chip(bloc, Rect2(w - 22 - 170, 14, 170, 32), "1re ligne %d/%d" % [formes, int(premiere.cible)], Charte.CONFIANCE if ok_pl else Charte.PERTE, "BenchFrontRowCount")
	chip_pl.tooltip_text = "Première ligne formée (loi 3)"
	var colonnes := 4
	var ecart := 12.0
	var tw := (w - 44 - ecart * (colonnes - 1)) / colonnes
	var th := (BANC.size.y - 64 - 18 - ecart) / 2.0
	var lignes := Control.new()
	lignes.name = "BenchPlayerRows"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(lignes)
	D.place(lignes, Rect2(22, 64, w - 44, th * 2 + ecart))
	for i in 8:
		var slot := 15 + i
		_tuile_banc(app, lignes, Rect2((i % colonnes) * (tw + ecart), int(i / colonnes) * (th + ecart), tw, th), slot, choisir, clavier, avis, bleus, pris)
	return bloc

static func _chip(parent: Control, zone: Rect2, texte: String, couleur: Color, id: String) -> Panel:
	var p := D.rect(parent, zone, Color(couleur, .2), Charte.RAYON_PILULE)
	p.name = id
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := D.text(p, zone.size.x / 2.0, zone.size.y / 2.0 + 7, texte, 18, couleur, 700, zone.size.x - 8, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.add_theme_font_override("font", Kit.texte_gras())
	return p

static func _tuile_banc(app: Control, parent: Control, zone: Rect2, slot: int, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, pris: Dictionary) -> void:
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	var choisi: bool = app.selected_slot == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "LineupSlot%02d" % (slot + 1)
	Kit.styler_ligne(bouton, Charte.PANNEAU_2, choisi, Charte.SELECTION)
	for etat in ["normal", "pressed", "disabled", "hover", "hover_pressed"]:
		var s := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		if s != null:
			s = s.duplicate() as StyleBoxFlat
			s.set_corner_radius_all(int(Charte.RAYON_CARTE * C.density))
			if choisi:
				s.border_color = Charte.IVOIRE
				s.set_border_width_all(2)
			bouton.add_theme_stylebox_override(etat, s)
	parent.add_child(bouton)
	D.place(bouton, zone)
	Selection.wire(bouton, app, id, slot, slot, str(person.get("name", "Poste vacant")))
	var w := zone.size.x
	var cote := minf(zone.size.y - 92, 84.0)
	Kit.ovale(bouton, Rect2(8, 8, 40, 26), str(slot + 1), app.accent)
	var accessible := "Remplaçant n° %d · " % (slot + 1)
	if person.is_empty():
		D.rect(bouton, Rect2((w - cote) / 2.0, 10, cote, cote), Charte.PANNEAU_3, Charte.RAYON_PILULE, Charte.IVOIRE_3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(bouton, w / 2.0, cote + 40, "Place vide", 17, Charte.PERTE, 700, w - 12, HORIZONTAL_ALIGNMENT_CENTER, true)
		accessible += "place vide"
	else:
		var portrait := Visuels.portrait_anneau(person, cote * C.density, maxf(3.0, 4.0 * C.density))
		portrait.name = "BenchFace%02d" % (slot + 1)
		bouton.add_child(portrait)
		portrait.position = Vector2((w - cote) / 2.0, 8) * C.density
		portrait.size = Vector2(cote, cote) * C.density
		var court := Kit.casse(str(person.get("name", "")), true)
		var taille := _taille_nom(court, w - 16, 18)
		var ln := minf(w - 12, Kit.largeur(court, taille) + 6)
		Kit.nom(app, bouton, Rect2((w - ln) / 2.0, cote + 12, ln, 28), court, id, "BenchName%02d" % (slot + 1), Charte.IVOIRE, taille)
		# Postes couverts en petites cases, « 1re ligne » en pastille violette, condition en chiffre coloré.
		var postes := Selection.positions(person)
		var y := cote + 46
		var morceaux := postes.split(" · ") if " · " in postes else postes.split("·")
		var cases: Array = []
		for m in morceaux:
			var s2 := str(m).strip_edges()
			if not s2.is_empty(): cases.append(s2)
		var formee := Selection.premiere_ligne_formee(app.model, person)
		var largeur_cases := 0.0
		for c2: String in cases: largeur_cases += Kit.largeur(c2, 15) + 14 + 4
		if formee: largeur_cases += Kit.largeur("1re ligne", 15) + 16 + 4
		var x := maxf(6.0, (w - largeur_cases) / 2.0)
		for c2: String in cases:
			var lc := Kit.largeur(c2, 15) + 14
			if x + lc > w - 6: break
			var case_ := D.rect(bouton, Rect2(x, y, lc, 24), Charte.PANNEAU_3, Charte.RAYON_PETIT)
			case_.mouse_filter = Control.MOUSE_FILTER_IGNORE
			D.text(case_, lc / 2.0, 17, c2, 15, Charte.IVOIRE, 700, lc, HORIZONTAL_ALIGNMENT_CENTER, true)
			x += lc + 4
		if formee:
			var lf := Kit.largeur("1re ligne", 15) + 16
			var marque := D.rect(bouton, Rect2(minf(x, w - 6 - lf), y, lf, 24), Color(Charte.CONFIANCE, .25), Charte.RAYON_PILULE)
			marque.name = "BenchFrontRow%02d" % (slot + 1)
			marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
			D.text(marque, lf / 2.0, 17, "1re ligne", 15, Charte.CONFIANCE, 700, lf, HORIZONTAL_ALIGNMENT_CENTER, true)
		var forme: Variant = person.get("condition")
		if forme is int or forme is float:
			var cond := D.text(bouton, w - 10, 28, "%d %%" % roundi(float(forme)), 16, Visuels.couleur_condition(float(forme)), 700, 70, HORIZONTAL_ALIGNMENT_RIGHT, true)
			cond.name = "BenchCondition%02d" % (slot + 1)
		accessible += "%s · couvre %s" % [str(person.get("name", "")), postes]
	if avis.has(slot):
		Kit.puce(bouton, Rect2(52, 8, 22, 24), "!", Charte.INTENSIF, Charte.ENCRE, "TacticsStaffAdviceMark%02d" % (slot + 1))
		accessible += " · " + str(avis[slot])
	if bleus.has(slot): Kit.puce(bouton, Rect2(78, 8, 32, 24), "33", Charte.MORAL, Charte.ENCRE, "TacticsBleusMark%02d" % (slot + 1))
	if not pris.is_empty() and str(pris.get("player_id", "")) != id and Selection.can_drop(app, Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))), slot):
		D.rect(bouton, Rect2(0, zone.size.y - 4, w, 4), Charte.CONDITION, Charte.RAYON_PILULE).name = "TacticsCible%02d" % (slot + 1)
	bouton.accessibility_name = accessible
	bouton.pressed.connect(func(): choisir.call(slot))
	bouton.gui_input.connect(func(event: InputEvent): clavier.call(event, slot, bouton))

# --- Doublures en cases colorées -------------------------------------------------------------------------------------

## Pour chaque poste, nombre de joueurs du métier sur la feuille : vert ≥ 2, orange 1 (« seul »), rouge 0 ; le chiffre
## porte toujours l'info (jamais la couleur seule). Une case choisit le poste (ses candidats dessous).
static func doublures(app: Control, page: Control, choisir: Callable) -> Panel:
	var bloc := D.rect(page, DOUBLURES, Charte.PANNEAU, Charte.RAYON_PANNEAU)
	bloc.name = "TacticsDepth"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	_titre_bloc(bloc, "DOUBLURES", 260)
	var comptes := {}
	for poste in range(1, 16): comptes[poste] = 0
	for slot in 23:
		var person := Selection.occupant(app.model, slot)
		if person.is_empty(): continue
		for poste in _postes(person):
			if comptes.has(poste): comptes[poste] += 1
	var seuls := 0
	for poste in range(1, 16):
		if int(comptes[poste]) <= 1: seuls += 1
	var resume := _chip(bloc, Rect2(DOUBLURES.size.x - 22 - 150, 14, 150, 32), ("✓ 15/15" if seuls == 0 else "! %d seul%s" % [seuls, "s" if seuls > 1 else ""]), Charte.CONDITION if seuls == 0 else Charte.INTENSIF, "TacticsDepthSummary")
	resume.tooltip_text = "Postes doublés par un joueur du métier"
	var w := DOUBLURES.size.x - 44
	var ecart := 6.0
	var cw := (w - 7 * ecart) / 8.0
	var ch := (DOUBLURES.size.y - 64 - 16 - ecart) / 2.0
	for poste in range(1, 16):
		var rang := poste - 1
		var zone := Rect2(22 + (rang % 8) * (cw + ecart), 64 + int(rang / 8) * (ch + ecart), cw, ch)
		var compte: int = comptes[poste]
		var couleur := Charte.CONDITION if compte >= 2 else (Charte.INTENSIF if compte == 1 else Charte.PERTE)
		var case_ := Button.new()
		case_.name = "TacticsDepth%02d" % poste
		var choisi: bool = app.selected_slot == poste - 1
		var normal := C.box(Color(couleur, .16), Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
		normal.set_border_width_all(2 if choisi else 0)
		var survol := C.box(Color(couleur, .3), Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
		survol.set_border_width_all(2 if choisi else 0)
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
		focus.set_border_width_all(2)
		for etat in ["normal", "pressed", "disabled"]: case_.add_theme_stylebox_override(etat, normal)
		case_.add_theme_stylebox_override("hover", survol)
		case_.add_theme_stylebox_override("hover_pressed", survol)
		case_.add_theme_stylebox_override("focus", focus)
		case_.focus_mode = Control.FOCUS_ALL
		case_.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bloc.add_child(case_)
		D.place(case_, zone)
		D.rect(case_, Rect2(0, 0, cw, 5), couleur, Charte.RAYON_PILULE).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(case_, cw / 2.0, ch * .5 + 2, str(poste), 26, Charte.IVOIRE, 700, cw - 4, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_GRAS)
		var c := D.text(case_, cw / 2.0, ch - 12, "×%d" % compte, 17, couleur, 700, cw - 4, HORIZONTAL_ALIGNMENT_CENTER, true)
		c.add_theme_font_override("font", Kit.texte_gras())
		case_.accessibility_name = "Poste n° %d · %d joueur%s du métier sur la feuille" % [poste, compte, "s" if compte > 1 else ""]
		case_.tooltip_text = case_.accessibility_name
		case_.pressed.connect(func(): choisir.call(poste - 1))
	return bloc

static func _postes(person: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var principal: Variant = person.get("primaryPosition")
	if principal is int or principal is float: result.append(int(principal))
	for autre: Variant in person.get("secondaryPositions", []):
		if (autre is int or autre is float) and int(autre) not in result: result.append(int(autre))
	return result
