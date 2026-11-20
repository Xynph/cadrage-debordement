extends RefCounted
## XV de départ sur un terrain tracé (charte §6, maquette 10-composition-1) : jamais de pelouse verte ; panneau, lignes
## ivoire de 1 px, pointillés ivoire-3 pour les lignes des 5 m et des 15 m, proportions de la charte (100 × 70 en-buts
## compris, comme la maquette validée). Quinze cartes de poste : ovale aux couleurs du club, nom (clic = fiche, survol =
## mini-fiche), note au poste et condition sous 80 %. L'équipe attaque vers la droite.
## Exemple : `Terrain.build(app, page, Rect2(0, 246, 990, 693), choisir, clavier, avis, bleus)`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const PersonName = preload("res://ui/person_name.gd")
const CARTE := Vector2(200, 50)
## Centre de chaque carte en fraction du terrain (maquette validée), du n° 1 au n° 15.
## Cartes de 200 : les n° 4, 5 et 8 descendent d'un rien pour ne jamais chevaucher leurs voisines.
const PLACES := {1: Vector2(.895, .20), 2: Vector2(.895, .35), 3: Vector2(.895, .50), 4: Vector2(.72, .275), 5: Vector2(.72, .425),
	6: Vector2(.54, .18), 8: Vector2(.54, .35), 7: Vector2(.54, .50), 9: Vector2(.43, .62), 10: Vector2(.32, .70),
	11: Vector2(.26, .20), 12: Vector2(.22, .78), 13: Vector2(.12, .86), 14: Vector2(.36, .92), 15: Vector2(.11, .46)}

class Trace extends Control:
	## Charte §6 : 100 × 70 m en-buts compris (en-buts de 5 m, 90 m de jeu à l'échelle), comme la maquette validée.
	const LONGUEUR := 100.0
	const LARGEUR := 70.0
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PANNEAU)
		var tiret := maxf(3.0, C.px(6))
		# Lignes pleines : lignes d'essai, des 22 m, des 10 m et médiane.
		for metres: float in [5.0, 24.8, 41.0, 50.0, 59.0, 75.2, 95.0]:
			var x := roundf(w * metres / LONGUEUR) + .5
			draw_line(Vector2(x, 0), Vector2(x, h), Charte.IVOIRE, -1.0)
		# Pointillés ivoire-3 : lignes des 5 m et des 15 m parallèles à la touche, lignes des 5 m devant chaque ligne d'essai.
		var essai_gauche := w * 5.0 / LONGUEUR
		var essai_droit := w * 95.0 / LONGUEUR
		for metres: float in [5.0, 15.0, 55.0, 65.0]:
			var y := roundf(h * metres / LARGEUR) + .5
			draw_dashed_line(Vector2(essai_gauche, y), Vector2(essai_droit, y), Charte.IVOIRE_3, -1.0, tiret)
		for metres: float in [9.5, 90.5]:
			var x := roundf(w * metres / LONGUEUR) + .5
			draw_dashed_line(Vector2(x, 0), Vector2(x, h), Charte.IVOIRE_3, -1.0, tiret)
		draw_rect(Rect2(.5, .5, w - 1.0, h - 1.0), Charte.IVOIRE, false, -1.0)

## `choisir(slot)` sélectionne une place ; `clavier(event, slot, carte)` gère Espace / Échap / Maj+Entrée / I.
static func build(app: Control, page: Control, zone: Rect2, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary) -> Control:
	var terrain := Trace.new()
	terrain.name = "TacticsPitch"
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(terrain)
	D.place(terrain, zone)
	Kit.etiquette(terrain, zone.size.x - 16, 30, "Sens de l’attaque →", 300, true)
	var pris: Dictionary = Selection.state(app).get("pris", {}) if Selection.state(app).get("pris") is Dictionary else {}
	for numero: int in range(1, 16):
		var centre: Vector2 = PLACES[numero] * zone.size
		carte(app, terrain, Rect2(centre - CARTE / 2.0, CARTE), numero - 1, choisir, clavier, avis, bleus, pris)
	return terrain

static func carte(app: Control, parent: Control, zone: Rect2, slot: int, choisir: Callable, clavier: Callable, avis: Dictionary, bleus: Dictionary, pris: Dictionary) -> Button:
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	var choisi: bool = app.selected_slot == slot
	var bouton := Selection.PlayerButton.new()
	bouton.name = "LineupSlot%02d" % (slot + 1)
	Kit.styler_ligne(bouton, Charte.PANNEAU_2, choisi)
	if person.is_empty():
		var vide := C.box(Charte.PANNEAU_3 if choisi else Charte.PANNEAU, Charte.IVOIRE_3, 0, 0)
		vide.border_color = Charte.IVOIRE_3
		for etat in ["normal", "pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, vide)
	parent.add_child(bouton)
	D.place(bouton, zone)
	Selection.wire(bouton, app, id, slot, slot, str(person.get("name", "Poste vacant")))
	if choisi: Kit.marqueur(bouton, Rect2(-11, 5, 4, zone.size.y - 10))
	# Petite fenêtre (plancher de 12 px) : ovale plus petit et note seule, pour garder le nom lisible.
	var dense := C.dense()
	var gauche := 36.0 if dense else 56.0
	Kit.ovale(bouton, Rect2(3, (zone.size.y - 22) / 2.0, 31, 22) if dense else Rect2(6, (zone.size.y - 30) / 2.0, 45, 30), str(slot + 1), app.accent)
	var accessible := "Poste n° %d · " % (slot + 1)
	if person.is_empty():
		Kit.texte(bouton, gauche, 31, "Poste n° %d vide" % (slot + 1), Charte.IVOIRE_2, zone.size.x - 66, 17)
		accessible += "vide"
	else:
		var court := Kit.casse(str(person.get("name", "")), true)
		Kit.nom(app, bouton, Rect2(gauche, 1, zone.size.x - gauche - 2, 25), court, id, "TacticsName%02d" % (slot + 1), Charte.IVOIRE, 17)
		var note := Selection.rating_text(app.model, person, slot)
		var chiffre := D.text(bouton, gauche + 4, 43, note, 18, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
		chiffre.add_theme_font_override("font", Kit.texte_gras())
		chiffre.name = "TacticsPositionRating%02d" % (slot + 1)
		var x := gauche + 4 + Kit.largeur(note, 18) + 6
		var forme: Variant = person.get("condition")
		var bas := (forme is int or forme is float) and float(forme) < 80
		# Sous 80 % : « 65 · ! 76 % » (la condition remplace « au poste » pour tenir dans la carte).
		if not bas and not dense: D.text(bouton, x, 43, "au poste", 16, Charte.IVOIRE_2, 500, 80, HORIZONTAL_ALIGNMENT_LEFT, true)
		accessible += "%s · %s au poste" % [str(person.get("name", "")), note]
		if bas:
			var alerte := D.text(bouton, x, 43, ("!%d%%" if dense else "· ! %d %%") % roundi(float(forme)), 16, Charte.D, 700, 70, HORIZONTAL_ALIGNMENT_LEFT, true)
			alerte.name = "TacticsCondition%02d" % (slot + 1)
			accessible += " · condition %d %%" % roundi(float(forme))
	if avis.has(slot):
		Kit.puce(bouton, Rect2(-6, -8, 18, 20), "!", Charte.IVOIRE_2, Charte.NUIT, "TacticsStaffAdviceMark%02d" % (slot + 1))
		accessible += " · " + str(avis[slot])
	if bleus.has(slot):
		Kit.puce(bouton, Rect2(zone.size.x - 30, -8, 28, 20), "33", Charte.D, Charte.NUIT, "TacticsBleusMark%02d" % (slot + 1))
		accessible += " · liste des 33 : doit souffler"
	# Pendant un « prendre / poser » : les destinations possibles sont soulignées, la source est marquée « pris ».
	if not pris.is_empty():
		if str(pris.get("player_id", "")) == id and not id.is_empty():
			D.rect(bouton, Rect2(0, 0, zone.size.x, 3), Charte.IVOIRE, 0).name = "TacticsPris%02d" % (slot + 1)
		elif Selection.can_drop(app, Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))), slot):
			D.rect(bouton, Rect2(0, zone.size.y - 3, zone.size.x, 3), Charte.IVOIRE_2, 0).name = "TacticsCible%02d" % (slot + 1)
	bouton.accessibility_name = accessible
	bouton.pressed.connect(func(): choisir.call(slot))
	bouton.gui_input.connect(func(event: InputEvent): clavier.call(event, slot, bouton))
	return bouton
