extends RefCounted
## Composition, terrain vertical vert (Léo, 21/11/2026 : « ce terrain est juste immonde », écran « pas assez coloré ») :
## option A retenue (22/11/2026) : terrain plein cadre vu du dessus, gazon du direct 2D, cartes flottantes (portrait rond,
## numéro, nom entier, pastille au poste). L'attaque va vers le haut, les avants devant (en haut), l'arrière au fond
## (en bas, devant notre en-but). Banc en tuiles portraits (triable), doublures en cases colorées, impact en barres
## colorées (▲ vert / ▼ rouge, jamais la couleur seule), candidats dessous à droite. Clics, glisser-déposer et touches
## (Espace prendre / poser, Suppr libérer, I carte joueur, Maj+Entrée fiche) : tactics_canvas.gd.
## Exemple : `Vertical.build(app, page, choisir, clavier, avis, bleus, premiere)`.
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
const TableOrder = preload("res://ui/player_table_order.gd")
const FocusLater := preload("res://ui/focus_later.gd")

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

## Place de chaque numéro : x en fraction de la largeur, y en fraction de la hauteur (0 = en haut, en-but adverse).
## Schéma de jeu, attaque vers le haut : avants devant (1-2-3, 4-5, 6-8-7), charnière, centres et ailiers, arrière au fond.
const PLACES := {1: Vector2(.27, .19), 2: Vector2(.5, .19), 3: Vector2(.73, .19), 4: Vector2(.38, .31), 5: Vector2(.62, .31),
	6: Vector2(.2, .43), 8: Vector2(.5, .43), 7: Vector2(.8, .43), 9: Vector2(.38, .545), 10: Vector2(.63, .65),
	11: Vector2(.11, .78), 12: Vector2(.37, .78), 13: Vector2(.63, .78), 14: Vector2(.89, .78), 15: Vector2(.5, .905)}
## Taille d'une carte du XV (unités du gabarit).
const CARTE := Vector2(156, 132)

# --- Terrain ---------------------------------------------------------------------------------------------------------

## Pelouse vue du dessus, plein cadre (la largeur s'étire un peu au-delà de l'échelle pour remplir la colonne) : bandes de tonte de 10 m, lignes blanches du XV (essai, 22 m,
## 10 m en tirets, médiane, 5 m et 15 m en tirets, poteaux), en-buts plus sombres.
class Pelouse extends Control:
	## Rectangle du terrain dans le contrôle (pixels), en-buts compris.
	var cadre := Rect2()

	func point(x_m: float, y_m: float) -> Vector2:
		# y_m : 0 = fond de l'en-but adverse (haut), LONGUEUR = fond de notre en-but (bas).
		return cadre.position + Vector2(x_m / LARGEUR * cadre.size.x, y_m / LONGUEUR * cadre.size.y)

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

static func _pelouse(page: Control) -> Pelouse:
	var pelouse := Pelouse.new()
	pelouse.name = "TacticsPitch"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(pelouse)
	D.place(pelouse, TERRAIN)
	pelouse.cadre = Rect2(Vector2.ZERO, TERRAIN.size * C.density)
	return pelouse

## Repères sans phrase : « XV DE DÉPART » et légende des pastilles au-dessus du terrain, flèche d'attaque sur l'en-but
## adverse (en haut), à côté des poteaux.
static func _reperes(page: Control, pelouse: Pelouse) -> void:
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

## Centre d'un numéro (unités du gabarit, dans la page).
static func _place(pelouse: Pelouse, numero: int) -> Vector2:
	var f: Vector2 = PLACES[numero]
	return pelouse.point(f.x * LARGEUR, f.y * LONGUEUR) / C.density + TERRAIN.position

# --- Cartes du XV ----------------------------------------------------------------------------------------------------

static func build(app: Control, page: Control, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, premiere: Dictionary) -> void:
	var pelouse := _pelouse(page)
	var pris: Dictionary = Selection.state(app).get("pris", {}) if Selection.state(app).get("pris") is Dictionary else {}
	for numero: int in range(1, 16):
		carte(app, page, Rect2(_place(pelouse, numero) - CARTE / 2.0, CARTE), numero - 1, choisir, clavier, avis, bleus, pris)
	_reperes(page, pelouse)
	banc(app, page, choisir, clavier, avis, bleus, premiere, pris)
	doublures(app, page, choisir)
	Impact.colore = true
	Impact.build(app, page, IMPACT, _adversaire(app), choisir)
	Impact.colore = false

static func _adversaire(app: Control) -> String:
	var Canvas: Script = load("res://ui/immersive08/tactics_canvas.gd")
	return Canvas._adversaire(app)

## Portrait rond à anneau de condition, transparent à la souris (l'anneau dessiné arrêtait les clics et le glisser).
static func _portrait(person: Dictionary, cote: float) -> Control:
	var portrait := Visuels.portrait_anneau(person, cote * C.density, maxf(3.0, 4.0 * C.density))
	_transparent(portrait)
	return portrait

static func _transparent(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for enfant in noeud.get_children(): _transparent(enfant)

## Nom court en entier : la taille descend jusqu'à 13 plutôt que de couper.
static func _taille_nom(texte: String, largeur: float, taille: int) -> int:
	var t := taille
	while t > 13 and Kit.largeur(texte, t) > largeur: t -= 1
	return t

## Carte d'une place du XV : portrait rond (anneau = condition), ovale du numéro aux couleurs du club, nom entier
## (clic = fiche, survol = carte joueur), pastille de note au poste (+ « 2e poste » / « Dépanne »).
static func carte(app: Control, page: Control, zone: Rect2, slot: int, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, pris: Dictionary) -> Button:
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	var choisi: bool = app.selected_slot == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "LineupSlot%02d" % (slot + 1)
	var w := zone.size.x
	var h := zone.size.y
	# Carte transparente : seule la plaque du nom est pleine (le gazon reste visible autour du portrait).
	var normal := C.box(Color.TRANSPARENT, Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
	normal.set_border_width_all(3 if choisi else 0)
	# Voile de survol sur une carte transparente : pas une tuile, donc sans ombre (celle de la plaque suffit).
	var survol := Charte.sans_ombre(C.box(Color(1, 1, 1, .1), Charte.IVOIRE if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0))
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
	glisser(app, bouton, person, true)
	# Plaque du nom en bas (nom + pastille), portrait au-dessus : rien ne sort de la carte.
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
		var portrait := _portrait(person, cote)
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
		var taille := _taille_nom(court, w - 16, 17)
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
	_tris(app, bloc)
	var colonnes := 4
	var ecart := 12.0
	var tw := (w - 44 - ecart * (colonnes - 1)) / colonnes
	var th := (BANC.size.y - 64 - 18 - ecart) / 2.0
	var lignes := Control.new()
	lignes.name = "BenchPlayerRows"
	lignes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(lignes)
	D.place(lignes, Rect2(22, 64, w - 44, th * 2 + ecart))
	var lecture: Dictionary = app.management_ui.bench_reading
	var entrees: Array = []
	for slot in range(15, 23):
		var person := Selection.occupant(app.model, slot)
		entrees.append({"id":str(person.get("id", "vacant")) + "/" + str(slot), "slot":slot, "person":person})
	entrees = TableOrder.ordered(entrees, lecture.key, lecture.descending, func(entree: Dictionary, cle: String):
		if cle == "slot": return entree.slot
		if cle == "pos": return Selection.positions(entree.person) if not entree.person.is_empty() else null
		return entree.person.get(cle))
	for i in entrees.size():
		_tuile_banc(app, lignes, Rect2((i % colonnes) * (tw + ecart), int(i / colonnes) * (th + ecart), tw, th), int(entrees[i].slot), choisir, clavier, avis, bleus, pris)
	return bloc

## Tri du banc en pastilles (n°, nom, postes, condition) : un second appui inverse l'ordre ; ▲ / ▼ sur la pastille active.
static func _tris(app: Control, bloc: Control) -> void:
	var lecture: Dictionary = app.management_ui.get("bench_reading", {"key":"slot", "descending":false})
	app.management_ui.bench_reading = lecture
	var x := 214.0
	for colonne: Array in [["N°", "slot"], ["Nom", "name"], ["Postes", "pos"], ["Cond.", "condition"]]:
		var cle: String = colonne[1]
		var actif: bool = lecture.key == cle
		var texte: String = str(colonne[0]).to_upper() + ((" ▼" if lecture.descending else " ▲") if actif else "")
		var l := Kit.largeur(texte, 15) + 26
		var tri := Button.new()
		tri.name = "BenchSort_" + cle
		tri.text = texte
		tri.add_theme_font_override("font", Kit.texte_gras())
		tri.add_theme_font_size_override("font_size", maxi(12, C.px(15)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			tri.add_theme_color_override(etat, Charte.ENCRE if actif else Charte.IVOIRE_2)
		var fond := C.box(Charte.IVOIRE if actif else Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
		for etat in ["normal", "pressed", "hover_pressed"]: tri.add_theme_stylebox_override(etat, fond)
		tri.add_theme_stylebox_override("hover", fond if actif else C.box(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PILULE, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
		focus.set_border_width_all(2)
		tri.add_theme_stylebox_override("focus", focus)
		tri.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tri.tooltip_text = "Trier par " + str(colonne[0]).to_lower()
		tri.pressed.connect(func():
			lecture.descending = not lecture.descending if lecture.key == cle else false
			lecture.key = cle
			app._render()
			var cible: Control = app.root_content.find_child("BenchSort_" + cle, true, false)
			if cible != null: FocusLater.grab(cible))
		bloc.add_child(tri)
		D.place(tri, Rect2(x, 16, l, 28))
		x += l + 6

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
			Charte.ombrer(s, Charte.RAYON_CARTE) # tuile du banc : l'ombre des jetons, comme toute tuile
			if choisi:
				s.border_color = Charte.IVOIRE
				s.set_border_width_all(2)
			bouton.add_theme_stylebox_override(etat, s)
	parent.add_child(bouton)
	D.place(bouton, zone)
	Selection.wire(bouton, app, id, slot, slot, str(person.get("name", "Poste vacant")))
	glisser(app, bouton, person, true)
	var w := zone.size.x
	var cote := minf(zone.size.y - 92, 84.0)
	Kit.ovale(bouton, Rect2(8, 8, 40, 26), str(slot + 1), app.accent)
	var accessible := "Remplaçant n° %d · " % (slot + 1)
	if person.is_empty():
		D.rect(bouton, Rect2((w - cote) / 2.0, 10, cote, cote), Charte.PANNEAU_3, Charte.RAYON_PILULE, Charte.IVOIRE_3).mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(bouton, w / 2.0, cote + 40, "Place vide", 17, Charte.PERTE, 700, w - 12, HORIZONTAL_ALIGNMENT_CENTER, true)
		accessible += "place vide"
	else:
		var portrait := _portrait(person, cote)
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

# --- Glisser : aperçu qui suit la souris, pastille au poste sur la place survolée -------------------------------------

## Tuile qui suit la souris pendant un glisser : portrait rond et nom.
static func apercu_glisser(person: Dictionary) -> Control:
	var boite := Control.new()
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var court := Kit.casse(str(person.get("name", "")), true)
	var l := Kit.largeur(court, 17) + 90
	var fond := D.rect(boite, Rect2(-30, -30, l, 60), Color(Charte.PANNEAU_3, .95), Charte.RAYON_PILULE, Charte.CONDITION)
	fond.name = "TacticsDragTile"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := _portrait(person, 52)
	fond.add_child(portrait)
	portrait.position = Vector2(4, 4) * C.density
	portrait.size = Vector2(52, 52) * C.density
	D.text(fond, 64, 37, court, 17, Charte.IVOIRE, 700, l - 70, HORIZONTAL_ALIGNMENT_LEFT, true)
	boite.modulate = Color(1, 1, 1, .92)
	return boite

## Sur la place survolée : la pastille au poste du joueur traîné (note à ce poste + 2e poste / dépanne).
static func apercu_depot(app: Control, bouton: Control, data: Variant) -> void:
	if not data is Dictionary: return
	var slot := int(bouton.get("target_slot"))
	var person := Selection.player(app.model, str(data.get("player_id", "")))
	if person.is_empty(): return
	var w := bouton.size.x / C.density
	var h := bouton.size.y / C.density
	var note: Variant = Selection.rating(app.model, person, slot) if slot < 15 else _note_principale(person)
	var familiarite := Selection.familiarite(app.model, person, slot) if slot < 15 else 3
	var l := minf(w - 8, Poste.largeur(note, familiarite, 22, true) + 16)
	var cadre := D.rect(bouton, Rect2((w - l) / 2.0, h / 2.0 - 18, l, 36), Color(Charte.PANNEAU, .94), Charte.RAYON_PILULE, Charte.CONDITION)
	cadre.name = "TacticsDropPreview"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Poste.poser(cadre, Rect2(8, 7, l - 16, 22), note, familiarite, "TacticsDropRating", false, true)

static func _note_principale(person: Dictionary) -> Variant:
	var principal: Variant = person.get("primaryPosition")
	var notes: Variant = person.get("positionRatings")
	if not (principal is int or principal is float) or not notes is Dictionary: return null
	var v: Variant = notes.get(str(int(principal)))
	return v if (v is int or v is float) and is_finite(float(v)) else null

## Branche l'aperçu du glisser et la pastille de dépôt sur une place (terrain, banc) ou une tuile.
static func glisser(app: Control, bouton: Control, person: Dictionary, place: bool) -> void:
	if not person.is_empty(): bouton.set("make_preview", func(): return apercu_glisser(person))
	if place: bouton.set("apercu_depot", func(b: Control, data: Variant): apercu_depot(app, b, data))

# --- Bas de l'écran : Candidats du poste ou Hors groupe ---------------------------------------------------------------

const LIGNES := [["tous", "Tous", []], ["1re", "1re ligne", [1, 2, 3]], ["2e", "2e ligne", [4, 5]], ["3e", "3e ligne", [6, 7, 8]],
	["demis", "Demis", [9, 10]], ["arrieres", "Trois-quarts", [11, 12, 13, 14, 15]]]

static func _principal(person: Dictionary) -> int:
	var p: Variant = person.get("primaryPosition")
	return int(p) if (p is int or p is float) else 99

static func hors_groupe_joueurs(app: Control) -> Array:
	var liste: Array = []
	for person: Variant in app.model.get("squad", []):
		if person is Dictionary and Selection.source(app.model, str(person.get("id", ""))) < 0: liste.append(person)
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := _principal(a)
		var pb := _principal(b)
		return pa < pb if pa != pb else str(a.get("name", "")) < str(b.get("name", "")))
	return liste

## Onglets du bas en pilules : « Candidats · n° X » (liste du poste choisi) / « Hors groupe · n » (tuiles du reste de
## l'effectif). Le libellé du premier porte le numéro du poste (TacticsCandidatesTitle).
static func onglets_bas(app: Control, bloc: Control) -> float:
	var etat := Selection.state(app)
	var mode := str(etat.get("bas", "candidats"))
	var slot: int = clampi(int(app.selected_slot), 0, 22)
	var poste := Selection.slot(app.model, slot)
	var x := 22.0
	var entrees := [["candidats", "CANDIDATS · N° %d · %s" % [slot + 1, str(poste.get("label", "")).to_upper()], "TacticsBottomCandidates"],
		["hors_groupe", "HORS GROUPE · %d" % hors_groupe_joueurs(app).size(), "TacticsBottomOutside"]]
	for entree: Array in entrees:
		var actif: bool = mode == entree[0]
		var l := Kit.largeur(str(entree[1]), 18) + 36
		var bouton := Button.new()
		bouton.name = str(entree[2])
		_styler_pilule(bouton, actif)
		bloc.add_child(bouton)
		D.place(bouton, Rect2(x, 10, l, 36))
		var libelle := D.text(bouton, l / 2.0, 25, str(entree[1]), 18, Charte.ENCRE if actif else Charte.IVOIRE, 700, l - 8, HORIZONTAL_ALIGNMENT_CENTER, true)
		libelle.add_theme_font_override("font", Kit.texte_gras())
		if entree[0] == "candidats": libelle.name = "TacticsCandidatesTitle"
		var cle: String = entree[0]
		bouton.pressed.connect(func():
			etat.bas = cle
			app._render())
		x += l + 8
	return x

static func _styler_pilule(bouton: Button, actif: bool, couleur: Color = Charte.IVOIRE) -> void:
	var fond := C.box(couleur if actif else Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
	for etat in ["normal", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, fond)
	bouton.add_theme_stylebox_override("hover", fond if actif else C.box(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PILULE, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Panneau « Hors groupe » : reçoit un joueur de la feuille glissé dessus (il quitte la feuille, sa place reste vide).
class DepotHorsGroupe extends Panel:
	var app: Control
	var survol := false
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var Sel: Script = load("res://ui/immersive08/tactics_selection.gd")
		var ok: bool = data is Dictionary and data.get("kind") == "tactics_player" and int(data.get("source_slot", -1)) >= 0 and Sel.editable(app)
		if ok != survol:
			survol = ok
			queue_redraw()
		return ok
	func _drop_data(_at: Vector2, data: Variant) -> void:
		var ok := _can_drop_data(_at, data)
		survol = false
		queue_redraw()
		if not ok: return
		var slot := int(data.source_slot)
		var lecture: Variant = app.management_ui.get("tactics_reading")
		if lecture is Dictionary: lecture["message"] = "Poste n° %d libéré." % (slot + 1)
		app._command("set_lineup", {"playerId": null, "slot": slot})
	func _notification(what: int) -> void:
		if (what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT) and survol:
			survol = false
			queue_redraw()
	func _draw() -> void:
		if not survol: return
		var bord := StyleBoxFlat.new()
		bord.bg_color = Color(Charte.CONDITION, .08)
		bord.border_color = Charte.CONDITION
		bord.set_border_width_all(3)
		bord.set_corner_radius_all(int(Charte.RAYON_PANNEAU * C.density))
		draw_style_box(bord, Rect2(Vector2.ZERO, size))

## Hors groupe : tout le reste de l'effectif en tuiles (portrait, nom entier, postes, pastille au poste principal,
## condition), filtrable par ligne ; blessés et suspendus grisés avec leur pastille d'état. Clic = le choisir pour le
## poste sélectionné ; glisser vers une place du terrain ou du banc ; une place de la feuille glissée ici la libère.
static func hors_groupe(app: Control, page: Control, zone: Rect2, haut_alertes: float) -> Panel:
	var bloc := DepotHorsGroupe.new()
	bloc.app = app
	bloc.name = "TacticsHorsGroupe"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	bloc.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 0))
	page.add_child(bloc)
	D.place(bloc, zone)
	var x := onglets_bas(app, bloc)
	var etat := Selection.state(app)
	var ligne := str(etat.get("ligne", "tous"))
	var joueurs := hors_groupe_joueurs(app)
	# Filtres par ligne de poste (pilules avec le nombre de joueurs).
	var fx := x + 16
	for entree: Array in LIGNES:
		var postes: Array = entree[2]
		var n := 0
		for p: Dictionary in joueurs:
			if postes.is_empty() or _principal(p) in postes: n += 1
		var texte := "%s %d" % [str(entree[1]).to_upper(), n]
		var l := Kit.largeur(texte, 15) + 24
		var filtre := Button.new()
		filtre.name = "TacticsOutsideLine_" + str(entree[0])
		_styler_pilule(filtre, ligne == entree[0], Charte.MORAL)
		bloc.add_child(filtre)
		D.place(filtre, Rect2(fx, 14, l, 28))
		var lib := D.text(filtre, l / 2.0, 20, texte, 15, Charte.ENCRE if ligne == entree[0] else Charte.IVOIRE_2, 700, l - 4, HORIZONTAL_ALIGNMENT_CENTER, true)
		lib.add_theme_font_override("font", Kit.texte_gras())
		var cle: String = entree[0]
		filtre.pressed.connect(func():
			etat.ligne = cle
			etat.scroll_hors = 0
			app._render())
		fx += l + 6
	var postes_filtre: Array = []
	for entree: Array in LIGNES:
		if entree[0] == ligne: postes_filtre = entree[2]
	var visibles: Array = []
	for p: Dictionary in joueurs:
		if postes_filtre.is_empty() or _principal(p) in postes_filtre: visibles.append(p)
	var haut := 56.0 + haut_alertes
	var defilement := ScrollContainer.new()
	defilement.name = "TacticsOutsideScroll"
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.mouse_filter = Control.MOUSE_FILTER_PASS
	bloc.add_child(defilement)
	D.place(defilement, Rect2(22, haut, zone.size.x - 44, zone.size.y - haut - 14))
	var largeur := zone.size.x - 44 - 18
	var ecart := 8.0
	var colonnes := maxi(1, int((largeur + ecart) / (180.0 + ecart)))
	var tw := (largeur - ecart * (colonnes - 1)) / colonnes
	var th := 96.0
	var grille := Control.new()
	grille.name = "TacticsOutsideTiles"
	grille.mouse_filter = Control.MOUSE_FILTER_PASS
	grille.custom_minimum_size = Vector2(largeur, ceilf(visibles.size() / float(colonnes)) * (th + ecart)) * C.density
	defilement.add_child(grille)
	for i in visibles.size():
		_tuile_hors_groupe(app, grille, Rect2((i % colonnes) * (tw + ecart), int(i / colonnes) * (th + ecart), tw, th), visibles[i])
	defilement.set_deferred("scroll_vertical", int(etat.get("scroll_hors", 0)))
	defilement.get_v_scroll_bar().value_changed.connect(func(valeur: float): etat.scroll_hors = int(valeur))
	return bloc

static func _tuile_hors_groupe(app: Control, parent: Control, zone: Rect2, person: Dictionary) -> void:
	var id := str(person.get("id", ""))
	var bouton := Selection.PlayerButton.new()
	bouton.name = "TacticsOutside_" + id.validate_node_name()
	bouton.set_meta("player_id", id)
	Kit.styler_ligne(bouton, Charte.PANNEAU_2)
	for etat in ["normal", "pressed", "disabled", "hover", "hover_pressed", "focus"]:
		var s := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		if s != null:
			s = s.duplicate() as StyleBoxFlat
			s.set_corner_radius_all(int(Charte.RAYON_CARTE * C.density))
			bouton.add_theme_stylebox_override(etat, s)
	parent.add_child(bouton)
	D.place(bouton, zone)
	Selection.wire(bouton, app, id, -1, -1, str(person.get("name", "")))
	glisser(app, bouton, person, false)
	# Laisse remonter le dépôt au panneau : une place de la feuille lâchée sur une tuile rejoint aussi le hors groupe.
	bouton.mouse_filter = Control.MOUSE_FILTER_PASS
	var Commune: Script = load("res://ui/immersive08/fiche_commune.gd")
	var dispo: Dictionary = Commune.disponibilite(app, person, "squad")
	var indispo: bool = dispo.etat in ["blesse", "suspendu"]
	var w := zone.size.x
	var contenu := Control.new()
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bouton.add_child(contenu)
	D.place(contenu, Rect2(0, 0, w, zone.size.y))
	if indispo: contenu.modulate = Color(1, 1, 1, .5)
	var portrait := _portrait(person, 62)
	contenu.add_child(portrait)
	portrait.position = Vector2(8, 8) * C.density
	portrait.size = Vector2(62, 62) * C.density
	var court := Kit.casse(str(person.get("name", "")), true)
	var dispo_nom := w - 82
	var taille := _taille_nom(court, dispo_nom, 17)
	Kit.nom(app, bouton, Rect2(76, 4, minf(dispo_nom, Kit.largeur(court, taille) + 6), 26), court, id, "TacticsOutsideName_" + id.validate_node_name(), Charte.IVOIRE_2 if indispo else Charte.IVOIRE, taille)
	# Postes en petites cases (principal d'abord, bleuté).
	var x := 76.0
	var postes := Selection.positions(person).split(" · ")
	for i in mini(postes.size(), 4):
		var lc := Kit.largeur(postes[i], 14) + 12
		if x + lc > w - 6: break
		var case_ := D.rect(contenu, Rect2(x, 34, lc, 22), Charte.PANNEAU_3 if i > 0 else Color(Charte.MORAL, .3), Charte.RAYON_PETIT)
		case_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(case_, lc / 2.0, 16, postes[i], 14, Charte.IVOIRE, 700, lc, HORIZONTAL_ALIGNMENT_CENTER, true)
		x += lc + 4
	var accessible := "%s · postes %s" % [str(person.get("name", "")), Selection.positions(person)]
	if indispo:
		var mot := ("✚ Blessé" if dispo.etat == "blesse" else "! Suspendu")
		var couleur := Charte.PERTE if dispo.etat == "blesse" else Charte.INTENSIF
		var lp := Kit.largeur(mot, 14) + 18
		var p := D.rect(bouton, Rect2(76, 64, lp, 24), Color(couleur, .25), Charte.RAYON_PILULE)
		p.name = "TacticsOutsideState"
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(p, lp / 2.0, 17, mot, 14, couleur, 700, lp, HORIZONTAL_ALIGNMENT_CENTER, true)
		bouton.tooltip_text = str(dispo.texte)
		accessible += " · " + str(dispo.texte)
	else:
		Poste.poser(contenu, Rect2(76, 64, 60, 22), _note_principale(person), 3, "TacticsOutsideRating")
		var forme: Variant = person.get("condition")
		if forme is int or forme is float:
			D.text(contenu, w - 8, 82, "%d %%" % roundi(float(forme)), 15, Visuels.couleur_condition(float(forme)), 700, 60, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "TacticsOutsideCondition"
	bouton.accessibility_name = accessible
	bouton.pressed.connect(func(): Candidats.activer(app, id, clampi(int(app.selected_slot), 0, 22)))
