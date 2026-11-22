extends RefCounted
## Avant-match : les deux XV face à face sur un même terrain (choix de Léo du 22/11/2026, idée FM27 n° 7), posé dans
## l'espace libre entre l'affiche et les tuiles de vérification. Nos 15 : la feuille (model.selection) ; leurs 15 : le
## XV de leur fiche club (native/engine/club-sheet.cjs, XV le plus fréquent complété par le XV probable). La météo du
## jour est posée sur le terrain, avec la flèche du vent de la 1re période. Clic sur un maillot : fiche du joueur ;
## survol : mini-fiche. Petite fenêtre (1280 × 720) : pas de terrain, l'écran reste celui d'avant.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const RI = preload("res://ui/contextual/rooms/room_identity.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Nom = preload("res://ui/person_name.gd")
const MeteoTexte = preload("res://ui/contextual/meteo_texte.gd")

## Place de chaque maillot sur un demi-terrain : x = profondeur (0 = sa ligne d'essai, 1 = ligne médiane), y = largeur.
const PLACES := {1: Vector2(.93, .30), 2: Vector2(.93, .50), 3: Vector2(.93, .70), 4: Vector2(.84, .40), 5: Vector2(.84, .60),
	6: Vector2(.84, .16), 7: Vector2(.84, .84), 8: Vector2(.75, .50), 9: Vector2(.66, .64), 10: Vector2(.56, .40),
	12: Vector2(.48, .26), 13: Vector2(.42, .14), 11: Vector2(.34, .04), 14: Vector2(.34, .96), 15: Vector2(.18, .52)}
const BLEU_METEO := Color("8fc1e8")

## Le terrain est affiché dès que la fenêtre n'est pas la petite (1280 × 720).
static func visible() -> bool:
	return not C.dense()

## Nos 15 (la feuille) et leurs 15 (leur XV) ; `pret` faux tant que la fiche adverse n'est pas arrivée.
static func donnees(app: Control, model: Dictionary, next: Dictionary, nous: int) -> Dictionary:
	var clubs := [next.get("home", {}), next.get("away", {})]
	var adverse: Dictionary = clubs[1 - nous]
	var sortie := {"nous": clubs[nous], "eux": adverse, "nos": [], "leurs": [], "pret": false}
	for i in 15:
		sortie.nos.append({})
		sortie.leurs.append({})
	for slot: Dictionary in model.get("selection", {}).get("slots", []):
		var n := int(slot.get("slot", -1))
		if n < 0 or n >= 15: continue
		var joueur := P.player(model, str(slot.get("playerId", "")))
		if not joueur.is_empty(): sortie.nos[n] = joueur
	var id_v: Variant = adverse.get("id")
	if not (id_v is int or id_v is float): return sortie
	var fiche: Dictionary = ClubSheet.cached(app, int(id_v))
	if fiche.is_empty():
		ClubSheet.request(app, int(id_v))
		return sortie
	var effectif := {}
	for j: Dictionary in fiche.get("squad", []): effectif[str(j.get("id", ""))] = j
	for s: Dictionary in fiche.get("xv", {}).get("slots", []):
		var n := int(s.get("jersey", 0)) - 1
		if n >= 0 and n < 15 and s.get("id") != null: sortie.leurs[n] = effectif.get(str(s.id), {})
	sortie.pret = true
	return sortie

static func couleur(club: Dictionary) -> Color:
	return RI.primary(G.identity(club))

## Section posée entre l'affiche et les tuiles de vérification.
static func section(ecran, app: Control, model: Dictionary, next: Dictionary, nous: int) -> Control:
	var d := donnees(app, model, next, nous)
	var zone := MarginContainer.new()
	zone.name = "AvantFaceAFace"
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, ecran.M(32))
	zone.add_theme_constant_override("margin_top", ecran.M(14))
	zone.add_theme_constant_override("margin_bottom", ecran.M(14))
	var tile := PanelContainer.new()
	tile.name = "AvantTerrainPanneau"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU, .94)
	style.set_corner_radius_all(Charte.RAYON_PANNEAU)
	style.set_content_margin_all(ecran.M(12))
	tile.add_theme_stylebox_override("panel", Charte.ombrer(style))
	zone.add_child(tile)
	var t := Terrain.new()
	t.name = "AvantTerrain"
	t.custom_minimum_size = Vector2(ecran.M(400), ecran.M(150))
	t.echelle = ecran.M(100) / 100.0
	tile.add_child(t)
	t.ajouter_equipe(app, d.nos, couleur(d.nous), 0)
	if d.pret: t.ajouter_equipe(app, d.leurs, couleur(d.eux), 1)
	# Météo posée sur le terrain : ciel + vent, et la flèche du vent pour la 1re période (nous à gauche).
	if next.get("meteo") is Dictionary:
		var annonce := MeteoTexte.annonce(next)
		var vent := clampi(int(next.meteo.get("vent", 0)), 0, 2)
		var mots: Array[String] = [MeteoTexte.libelle(annonce)]
		if vent > 0 and mots[0].to_lower().find("vent") < 0: mots.append(["", "vent", "grand vent"][vent])
		t.meteo = " · ".join(mots).to_upper()
		t.vent = vent
		t.sens = 1 if MeteoTexte.camp_vent(annonce, 1) == nous else -1
	return zone

static func ouvrir_joueur(app: Control, pid: String) -> void:
	for genre in ["player", "market"]:
		if app.navigation_controller.open_entity({"kind": genre, "id": pid}): return

## Terrain dessiné en largeur (pelouse, lignes) avec des maillots cliquables posés dessus : camp 0 (nous) à gauche.
class Terrain extends Control:
	var echelle := 1.0
	var meteo := ""
	var vent := 0
	var sens := 1
	var _maillots: Array = []
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(_placer)
	func ajouter_equipe(app: Control, joueurs: Array, teinte: Color, camp: int) -> void:
		for i in mini(15, joueurs.size()):
			var j: Dictionary = joueurs[i]
			var m := Maillot.new()
			m.numero = i + 1
			m.teinte = teinte
			m.camp = camp
			m.nom = Nom.surname(str(j.get("name", ""))).to_upper() if not j.is_empty() else ""
			m.name = "Maillot_%d_%d" % [camp, i + 1]
			if not j.is_empty():
				var pid := str(j.get("id", ""))
				m.pressed.connect(func(): load("res://ui/immersive08/avant_match_terrain.gd").ouvrir_joueur(app, pid))
				MiniFiche.lier(app, m, pid, "squad" if not P.player(app.model, pid).is_empty() else "adverse")
				m.accessibility_name = "%d · %s" % [i + 1, str(j.get("name", ""))]
			else: m.disabled = true
			add_child(m)
			_maillots.append(m)
		_placer()
	func _zone() -> Rect2:
		return Rect2(Vector2(4, 4), size - Vector2(8, 8))
	func _placer() -> void:
		var z := _zone()
		var cote := clampf(minf(z.size.x, z.size.y) * 0.105, 22.0, 48.0)
		for m: Maillot in _maillots:
			var p: Vector2 = PLACES.get(m.numero, Vector2(.5, .5))
			var centre: Vector2
			if m.camp == 0: centre = z.position + Vector2(z.size.x * p.x * .5, z.size.y * p.y)
			else: centre = z.position + Vector2(z.size.x * (1.0 - p.x * .5), z.size.y * (1.0 - p.y))
			# Ailiers ramenés dans la pelouse (le nom passe sous le maillot).
			centre.y = clampf(centre.y, z.position.y + cote * .7, z.end.y - cote * 1.6)
			m.cote = cote
			m.size = Vector2(cote * 2.6, cote * 1.55)
			m.position = centre - Vector2(m.size.x / 2.0, cote / 2.0)
			m.queue_redraw()
		queue_redraw()
	func _draw() -> void:
		var z := _zone()
		var fond := StyleBoxFlat.new()
		fond.bg_color = Charte.PELOUSE
		fond.set_corner_radius_all(Charte.RAYON_CARTE)
		draw_style_box(fond, z)
		var trait_ := Color(Charte.CREME, .28)
		var pas := 12
		for k in pas:
			if k % 2 == 1: draw_rect(Rect2(z.position + Vector2(z.size.x * k / pas, 0), Vector2(z.size.x / pas, z.size.y)), Charte.PELOUSE_2)
		# Lignes d'essai, des 22 mètres et médiane.
		for f in [0.04, 0.24, 0.5, 0.76, 0.96]:
			var x: float = z.position.x + z.size.x * f
			draw_line(Vector2(x, z.position.y), Vector2(x, z.end.y), trait_, 2.0 if f in [0.04, 0.5, 0.96] else 1.0)
		if not meteo.is_empty():
			var police: Font = Charte.TITRE_GRAS
			var t := 15 * echelle
			var largeur := police.get_string_size(meteo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t)).x
			var boite := Rect2(z.position.x + z.size.x / 2.0 - largeur / 2.0 - 14, z.position.y + 8, largeur + 28 + (34.0 * echelle if vent > 0 else 0.0), t + 12)
			var pil := StyleBoxFlat.new()
			pil.bg_color = Color(Charte.NOIR_PANNEAU, .82)
			pil.set_corner_radius_all(int(boite.size.y / 2.0))
			draw_style_box(pil, boite)
			draw_string(police, Vector2(boite.position.x + 14, boite.position.y + t + 3), meteo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t), BLEU_METEO)
			if vent > 0:
				# Flèche du vent (1re période) : vers la droite = dans notre dos quand nous sommes à gauche.
				var y := boite.position.y + boite.size.y / 2.0
				var x0 := boite.end.x - 34.0 * echelle
				var x1 := boite.end.x - 12.0
				if sens < 0:
					var tmp := x0
					x0 = x1
					x1 = tmp
				draw_line(Vector2(x0, y), Vector2(x1, y), BLEU_METEO, 2.0 + vent)
				draw_colored_polygon(PackedVector2Array([Vector2(x1 + 4.0 * sens, y), Vector2(x1 - 6.0 * sens, y - 6), Vector2(x1 - 6.0 * sens, y + 6)]), BLEU_METEO)

## Maillot : rond à la couleur du club, numéro au centre, nom de famille dessous.
class Maillot extends Button:
	var numero := 0
	var teinte := Color.GRAY
	var camp := 0
	var nom := ""
	var cote := 30.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for look in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(look, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var c := Vector2(size.x / 2.0, cote / 2.0)
		var r := cote / 2.0
		if is_hovered() or has_focus(): draw_circle(c, r + 4, Color(Charte.CREME, .9))
		draw_circle(c, r + 1.5, Color(0, 0, 0, .45))
		draw_circle(c, r, teinte)
		var police: Font = Charte.TITRE_FICHE
		var t := int(r * 1.05)
		draw_string(police, Vector2(0, c.y + t * .36), str(numero), HORIZONTAL_ALIGNMENT_CENTER, size.x, t, RI.contrast(teinte))
		if not nom.is_empty():
			var tn := int(clampf(cote * .36, 10, 16))
			var largeur := Charte.TITRE_GRAS.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
			var fond := Rect2(size.x / 2.0 - largeur / 2.0 - 4, cote + 2, largeur + 8, tn + 4)
			draw_rect(fond, Color(Charte.NOIR_PANNEAU, .72))
			draw_string(Charte.TITRE_GRAS, Vector2(fond.position.x + 4, fond.position.y + tn), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Charte.CREME)
