extends RefCounted
## Onglets Consignes, Phases arrêtées et Entraînement de la Tactique (Léo, 22/11/2026 : « tout l'écran Tactique trop
## moche, pas assez coloré, pas dans notre DA ») : même page que la Composition, même en-tête (titre Anton, pastilles,
## bandeau du match aux couleurs des clubs, onglets), contenu en cartes flottantes, terrains verts et pastilles franches.
## Mise en page « Terrain » (choix de Léo, 22/11/2026) : celle de la Composition, grand terrain vertical à gauche et
## cartes à droite.
## Aucune phrase d'aide : les descriptions du moteur passent en infobulle. Commandes du moteur seulement
## (`set_tactics`, `playbook_set`) ; les écrans complets (Préparation, Plan de jeu, Entraînement) restent ouverts par
## le bouton de l'en-tête et par chaque tuile qui y mène.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Entete = preload("res://ui/immersive08/tactics_entete.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Consignes = preload("res://ui/immersive08/preparation_consignes.gd")
const Rules = preload("res://ui/playbook_view.gd")
const Watch = preload("res://ui/management_state.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

const NOMS := {1: "Consignes", 2: "Phases arrêtées", 4: "Entraînement"}
const ATTAQUE := Pieces.BLEU
const DEFENSE := Pieces.VIOLET
const HAUT := 196.0
const BAS := 1298.0
const ICONES_PHASE := {"scrum": "people", "lineout": "flag", "kickoff": "ball"}
const COULEURS_PHASE := {"scrum": Pieces.ORANGE, "lineout": Pieces.TURQUOISE, "kickoff": Pieces.BLEU}
## Zones de chute des renvois (mètres depuis la médiane).
const PORTEES := {"normal": Vector2(10, 22), "court": Vector2(10, 14), "long": Vector2(25, 35)}

static func actuel(app: Control) -> int:
	var onglet := int(app.management_ui.get("tactique_onglet", 0))
	return onglet if NOMS.has(onglet) else 0

static func choisir_onglet(app: Control, index: int) -> void:
	app.management_ui.tactique_onglet = index if NOMS.has(index) else 0
	app._render()

static func build(app: Control, page: Control, onglet: int) -> void:
	_entete(app, page, onglet)
	match onglet:
		1: _consignes(app, page)
		2: _phases(app, page)
		4: _entrainement(app, page)

# --- En-tête ---------------------------------------------------------------------------------------------------------

static func _entete(app: Control, page: Control, onglet: int) -> void:
	var nom: String = NOMS[onglet]
	var titre := Kit.titre_page(page, 0, 40, nom, 38, 700)
	titre.name = "TacticsTabTitle"
	var x := Charte.TITRE_FICHE.get_string_size(nom.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(38))).x / C.density + 24
	titre.size.x = (x - 20) * C.density
	var y := Entete.LIGNE_1 + 4
	match onglet:
		1:
			var t: Dictionary = app.model.get("tactics", {})
			x += _pastille(page, x, y, "Attaque · " + _libelle(t.get("attacks", []), t.get("attack")), "ball", "TacticsTabAttack", ATTAQUE) + 10
			x += _pastille(page, x, y, "Défense · " + _libelle(t.get("defenses", []), t.get("defense")), "shield", "TacticsTabDefense", DEFENSE) + 10
			var locales := 0
			for zone: Dictionary in _carnet(app).get("zones", []):
				if str(zone.get("attack", "inherit")) != "inherit" or str(zone.get("defence", "inherit")) != "inherit": locales += 1
			x += _pastille(page, x, y, "Zones · %d/4" % locales, "flag", "TacticsTabZones", Pieces.VERT if locales > 0 else Charte.IVOIRE_2, func(): _ouvrir_carnet(app, 0)) + 10
			Entete.bouton(page, 2248, "Préparation du match", "tactic", func(): app.Immersive.open_preparation(app, 0), "TacticsTabOpenFull")
		2:
			for phase: Dictionary in _carnet(app).get("setPieces", []):
				var cle := str(phase.get("key", ""))
				x += _pastille(page, x, y, "%s · %s" % [str(phase.get("label", "")), _libelle(phase.get("options", []), phase.get("selected"))], ICONES_PHASE.get(cle, "flag"), "TacticsTabPhase_" + cle, COULEURS_PHASE.get(cle, Charte.IVOIRE)) + 10
			Entete.bouton(page, 2248, "Carnet de jeu", "tactic", func(): _ouvrir_carnet(app, 1), "TacticsTabOpenFull")
		4:
			var meta: Dictionary = app.model.get("meta", {})
			var fait := bool(meta.get("trained", false))
			x += _pastille(page, x, y, "Séance faite" if fait else "Séance à faire", "check" if fait else "train", "TacticsTabSeance", Pieces.VERT if fait else Pieces.ORANGE, func(): _ouvrir_entrainement(app, 0)) + 10
			x += _pastille(page, x, y, "Semaine %d" % (int(meta.get("week", 0)) + 1), "calendar", "TacticsTabSemaine", Pieces.BLEU, func(): app._navigate("Calendrier")) + 10
			Entete.bouton(page, 2248, "Plan d'entraînement", "train", func(): _ouvrir_entrainement(app, 0), "TacticsTabOpenFull")
	Entete._bandeau(app, page)
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)

static func _pastille(page: Control, x: float, y: float, texte: String, icone: String, id: String, couleur: Color, action: Callable = Callable(), bulle: String = "") -> float:
	return Pieces.pastille(page, x, y, texte, icone, id, bulle, couleur, Charte.PANNEAU_3, action)

static func _libelle(options: Variant, id: Variant) -> String:
	if options is Array:
		for option: Variant in options:
			if option is Dictionary and str(option.get("id")) == str(id): return str(option.get("label", id))
	return "—"

static func _carnet(app: Control) -> Dictionary:
	return app.model.get("clubLife", {}).get("playbook", {})

static func _ouvrir_carnet(app: Control, onglet: int) -> void:
	app.management_ui.playbook_tab = onglet
	app._navigate("Plan de jeu")

static func _ouvrir_entrainement(app: Control, onglet: int) -> void:
	if not app.management_ui.get("immersive_training") is Dictionary: app.management_ui.immersive_training = {}
	app.management_ui.immersive_training.tab = onglet
	app.Immersive.open_training(app)

# --- Pièces communes -------------------------------------------------------------------------------------------------

## Titre de bloc en Anton avec un epais de couleur à gauche.
static func _titre_bloc(page: Control, x: float, y: float, texte: String, couleur: Color, largeur: float = 600) -> float:
	Kit.marqueur(page, Rect2(x, y + 4, 5, 30), couleur)
	var t := Kit.titre(page, x + 16, y + 30, texte, 28, largeur)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsBloc_" + texte.validate_node_name()
	return x + 16 + Charte.TITRE_FICHE.get_string_size(texte.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(28))).x / C.density + 18

## Fond d'une carte : panneau presque opaque, comme les plaques posées sur la pelouse.
static func _fond() -> Color:
	return Color(Charte.PANNEAU, .9)

## Carte de choix (bouton) : contour franc de la couleur quand elle est retenue ; posée avant son contenu.
static func _carte(page: Control, zone: Rect2, id: String, choisi: bool, couleur: Color, actif: bool, action: Callable, bulle: String) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = bulle
	b.accessibility_name = bulle
	var fond := _fond()
	var normal := C.box(fond.lerp(couleur, .10) if choisi else fond, couleur if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 0)
	normal.set_border_width_all(3 if choisi else 0)
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = normal.bg_color.lightened(.07)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_CARTE, 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	Charte.sans_ombre(focus)
	for etat in ["normal", "pressed", "disabled"]: b.add_theme_stylebox_override(etat, normal)
	b.add_theme_stylebox_override("hover", survol if actif and not choisi else normal)
	b.add_theme_stylebox_override("hover_pressed", survol)
	b.add_theme_stylebox_override("focus", focus)
	b.disabled = not actif or choisi
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not b.disabled else Control.CURSOR_ARROW
	b.pressed.connect(action)
	page.add_child(b)
	D.place(b, zone)
	return b

## Pastilles d'effet (▲ / ▼ / =) en ligne, retour à la ligne si la place manque. Rend le bas.
static func _effets(parent: Control, x: float, y: float, largeur: float, effets: Array, prefixe: String) -> float:
	var cx := x
	var cy := y
	for effet: Array in effets:
		var texte := str(effet[0])
		var w := Pieces.largeur_pastille(texte)
		if cx > x and cx + w > x + largeur:
			cx = x
			cy += 42
		Pieces.pastille(parent, cx, cy, texte, "", prefixe + texte.validate_node_name(), "", effet[1], Charte.PANNEAU_3)
		cx += w + 8
	return cy + 34

static func _effets_intention(cote: String, id: String) -> Array:
	var rendu: Array = []
	for e: Array in Consignes.EFFETS.get(cote, {}).get(id, []):
		var signe := "▲ " if e[1] == "haut" else "▼ " if e[1] == "bas" else "= "
		rendu.append([signe + str(e[0]), e[2]])
	return rendu

static func _effets_phase(cle: String, id: String) -> Array:
	var rendu: Array = []
	for e: Array in load("res://ui/immersive08/playbook_canvas.gd").EFFETS.get(cle, {}).get(id, []):
		var signe := str(e[2])
		var couleur: Color = Pieces.VERT if signe == "+" else Pieces.ROUGE if signe == "−" else Charte.IVOIRE_2
		rendu.append([("▲ " if signe == "+" else "▼ " if signe == "−" else "= ") + str(e[1]), couleur])
	return rendu

static func _transparent(noeud: Node) -> void:
	for enfant in noeud.get_children():
		if enfant is Control and not enfant is Button: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transparent(enfant)

## Pelouse verticale de la Composition, à la même place que le terrain du XV.
static func _pelouse(page: Control) -> Control:
	var pelouse = Vertical.Pelouse.new()
	pelouse.name = "TacticsTabPitch"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(pelouse)
	D.place(pelouse, Vertical.TERRAIN)
	pelouse.cadre = Rect2(Vector2.ZERO, Vertical.TERRAIN.size * C.density)
	return pelouse

## Point de la pelouse verticale en unités de la page (x en mètres depuis la touche gauche, y depuis l'en-but adverse).
static func _point(x_m: float, y_m: float) -> Vector2:
	return Vertical.TERRAIN.position + Vector2(x_m / Vertical.LARGEUR * Vertical.TERRAIN.size.x, y_m / Vertical.LONGUEUR * Vertical.TERRAIN.size.y)

static func _intentions_editables(app: Control) -> bool:
	var live: Variant = app.model.get("live")
	return not bool(app.get("waiting")) and not (live is Dictionary and not live.is_empty()) and str(app.model.get("meta", {}).get("phase", "")) != "ended"

# --- Consignes -------------------------------------------------------------------------------------------------------

static func _consignes(app: Control, page: Control) -> void:
	var t: Dictionary = app.model.get("tactics", {})
	var cotes := [["attack", "attacks", "Avec le ballon", "Attack", ATTAQUE], ["defense", "defenses", "Sans le ballon", "Defense", DEFENSE]]
	# Composition : terrain vertical des zones à gauche, cartes d'intention à droite.
	_zones_verticales(app, page)
	var gauche := Vertical.DROITE
	var largeur := 2248.0 - gauche
	_titre_bloc(page, gauche, HAUT - 4, str(cotes[0][2]), ATTAQUE)
	_grille_intentions(app, page, Rect2(gauche, HAUT + 44, largeur, 490), cotes[0], t, 1)
	_titre_bloc(page, gauche, 752, str(cotes[1][2]), DEFENSE)
	_grille_intentions(app, page, Rect2(gauche, 800, largeur, BAS - 800), cotes[1], t, 1)

## Une ligne de cartes d'intention : schéma dessiné, titre en Anton, pastilles d'effet ; la carte entière choisit.
static func _grille_intentions(app: Control, page: Control, zone: Rect2, cote: Array, t: Dictionary, _lignes: int) -> void:
	var options: Array = t.get(cote[1], [])
	if options.is_empty(): return
	var choisie := str(t.get(cote[0], ""))
	var ecart := 16.0
	var w := (zone.size.x - ecart * (options.size() - 1)) / options.size()
	var h := zone.size.y
	var actif := _intentions_editables(app)
	for n in options.size():
		var option: Dictionary = options[n]
		var id := str(option.get("id", ""))
		var choisi := id == choisie
		var rect := Rect2(zone.position.x + n * (w + ecart), zone.position.y, w, h)
		var cle: String = cote[0]
		var carte := _carte(page, rect, "TacticsTab%s_%s" % [cote[3], id], choisi, cote[4], actif, func(): _choisir_intention(app, cle, id), "%s\n%s" % [str(option.get("label", "")), str(option.get("description", ""))])
		var schema = Consignes.Schema.new()
		schema.name = "Schema_" + id
		schema.cote = cle
		schema.id = id
		schema.accent = cote[4]
		carte.add_child(schema)
		var haut_schema := h - 190.0
		D.place(schema, Rect2(12, 12, w - 24, haut_schema))
		var titre := Kit.titre(carte, 16, haut_schema + 50, str(option.get("label", "")), 28, w - 32)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		titre.add_theme_color_override("font_color", cote[4] if choisi else Charte.IVOIRE)
		_effets(carte, 16, haut_schema + 66, w - 32, _effets_intention(cle, id), "Effet_%s_" % id)
		if choisi: Consignes.coche(carte, w - 22, 22)
		_transparent(carte)

static func _choisir_intention(app: Control, cle: String, id: String) -> void:
	var t: Dictionary = app.model.get("tactics", {})
	var payload := {"attack": t.get("attack", "equilibre"), "defense": t.get("defense", "equilibre")}
	payload[cle] = id
	app._command("set_tactics", payload)

## Données d'une zone du carnet : [n°, libellé, attaque effective, défense effective, locale ?, actuelle ?].
static func _zone(app: Control, i: int) -> Array:
	var carnet := _carnet(app)
	var zone: Dictionary = carnet.get("zones", [])[i]
	var locale := str(zone.get("attack", "inherit")) != "inherit" or str(zone.get("defence", "inherit")) != "inherit"
	return [i + 1, str(zone.get("label", "")), _libelle(carnet.get("attackOptions", []), zone.get("effectiveAttack")), _libelle(carnet.get("defenceOptions", []), zone.get("effectiveDefence")), locale, carnet.get("currentZone") == zone.get("id"), str(zone.get("id", i))]

## Plaque d'une zone (posée sur le terrain) : n°, nom, pastilles Attaque / Défense, état ; clic → Plan de jeu.
static func _plaque_zone(app: Control, page: Control, rect: Rect2, z: Array) -> void:
	var plaque := D.rect(page, rect, Color(Charte.PANNEAU, .9), Charte.RAYON_CARTE, Charte.VERT_CLAIR if z[5] else Color.TRANSPARENT)
	plaque.name = "TacticsZone_%s" % z[6]
	var numero := D.text(plaque, 16, 46, "%02d" % int(z[0]), 40, Charte.VERT_CLAIR if z[5] else Charte.IVOIRE, 500, 70)
	numero.add_theme_font_override("font", Charte.TITRE_FICHE)
	var nom := Kit.titre(plaque, 86, 40, str(z[1]), 24, rect.size.x - 100)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	Pieces.pastille(plaque, 16, 60, str(z[2]), "ball", "TacticsZoneAttaque_%s" % z[6], "", ATTAQUE)
	Pieces.pastille(plaque, 16, 102, str(z[3]), "shield", "TacticsZoneDefense_%s" % z[6], "", DEFENSE)
	var etat := "Locale" if z[4] else "Plan principal"
	Pieces.pastille(plaque, rect.size.x - 16 - Pieces.largeur_pastille(etat, "flag"), 14, etat, "flag" if z[4] else "renew", "TacticsZoneEtat_%s" % z[6], "", Pieces.VERT if z[4] else Charte.IVOIRE_2)
	_transparent(plaque)
	Pieces.rendre_cliquable(plaque, rect.size, func(): _ouvrir_carnet(app, 0), "TacticsZoneLien_%s" % z[6], "Zone %d · %s" % [int(z[0]), str(z[1])], "", Charte.RAYON_CARTE)

## Les quatre zones en bandes sur la pelouse verticale (en-but adverse en haut).
static func _zones_verticales(app: Control, page: Control) -> void:
	var t := Kit.titre(page, 0, Vertical.BANDEAU.position.y + 32, "PAR ZONE", 28, 300)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsTabPitchTitle"
	_pelouse(page)
	var zones: Array = _carnet(app).get("zones", [])
	var bornes := [[83.0, 105.0], [55.0, 83.0], [27.0, 55.0], [5.0, 27.0]]
	for i in mini(4, zones.size()):
		var z := _zone(app, i)
		var a := _point(0, bornes[i][0])
		var b := _point(Vertical.LARGEUR, bornes[i][1])
		if z[5]: D.rect(page, Rect2(a, b - a), Color(Charte.VERT_CLAIR, .16)).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var centre := (a + b) / 2.0
		_plaque_zone(app, page, Rect2(centre.x - 300, centre.y - 75, 600, 150), z)

# --- Phases arrêtées -------------------------------------------------------------------------------------------------

static func _phases(app: Control, page: Control) -> void:
	var carnet := _carnet(app)
	var phases: Array = carnet.get("setPieces", [])
	var actif := bool(carnet.get("available", false)) and not bool(app.get("waiting"))
	_terrain_phases(app, page, phases)
	var gauche := Vertical.DROITE
	var w := (2248.0 - gauche - 2 * 20) / 3.0
	for i in phases.size():
		_colonne_phase(app, page, Rect2(gauche + i * (w + 20), HAUT - 4, w, BAS - HAUT + 4), phases[i], actif)

## Colonne d'une phase : titre (icône, Anton), puis une carte par choix (croquis, nom, pastilles d'effet).
static func _colonne_phase(app: Control, page: Control, zone: Rect2, phase: Dictionary, actif: bool) -> void:
	var cle := str(phase.get("key", ""))
	var couleur: Color = COULEURS_PHASE.get(cle, Charte.IVOIRE)
	_titre_bloc(page, zone.position.x, zone.position.y, str(phase.get("label", "")), couleur, zone.size.x - 20)
	var options: Array = phase.get("options", [])
	var choisie := str(phase.get("selected", ""))
	var haut := zone.position.y + 48
	var h := minf(250.0, (zone.end.y - haut - 16 * 3) / 4.0)
	for n in options.size():
		var option: Dictionary = options[n]
		var id := str(option.get("id", ""))
		var choisi := id == choisie
		var rect := Rect2(zone.position.x, haut + n * (h + 16), zone.size.x, h)
		var carte := _carte(page, rect, "TacticsTabPhase_%s_%s" % [cle, id], choisi, couleur, actif, func(): Rules._choose(app, cle, id), "%s\n%s" % [str(option.get("label", "")), str(option.get("description", ""))])
		var cote := h - 24
		var croquis := Croquis.new()
		croquis.name = "Croquis_%s_%s" % [cle, id]
		croquis.cle = cle
		croquis.id = id
		croquis.accent = couleur
		carte.add_child(croquis)
		D.place(croquis, Rect2(12, 12, minf(cote * 1.25, zone.size.x * .42), cote))
		var x := 12 + minf(cote * 1.25, zone.size.x * .42) + 16
		var titre := Kit.titre(carte, x, 46, str(option.get("label", "")), 26, zone.size.x - x - 20)
		titre.add_theme_font_override("font", Charte.TITRE_FICHE)
		titre.add_theme_color_override("font_color", couleur if choisi else Charte.IVOIRE)
		_effets(carte, x, 66, zone.size.x - x - 14, _effets_phase(cle, id), "Effet_%s_%s_" % [cle, id])
		if choisi: Consignes.coche(carte, zone.size.x - 14, h - 48)
		_transparent(carte)

## Repères des phases sur la pelouse verticale (mêlée, touche, zone de chute du renvoi choisi).
static func _terrain_phases(app: Control, page: Control, phases: Array) -> void:
	var t := Kit.titre(page, 0, Vertical.BANDEAU.position.y + 32, "SUR LE TERRAIN", 28, 360)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsTabPitchTitle"
	_pelouse(page)
	var choix := {}
	for phase: Dictionary in phases: choix[str(phase.get("key", ""))] = [str(phase.get("label", "")), _libelle(phase.get("options", []), phase.get("selected")), str(phase.get("selected", ""))]
	# Renvoi : depuis la médiane vers l'en-but adverse (en haut), zone de chute du choix en clair.
	if choix.has("kickoff"):
		var portee: Vector2 = PORTEES.get(choix.kickoff[2], PORTEES.normal)
		var a := _point(4, 55.0 - portee.y)
		var b := _point(Vertical.LARGEUR - 4, 55.0 - portee.x)
		D.rect(page, Rect2(a, b - a), Color(COULEURS_PHASE.kickoff, .35), Charte.RAYON_PETIT, COULEURS_PHASE.kickoff).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_repere(page, _point(Vertical.LARGEUR / 2.0, 55.0 - (portee.x + portee.y) / 2.0), choix.kickoff, "kickoff")
	if choix.has("scrum"): _repere(page, _point(Vertical.LARGEUR * .4, 72), choix.scrum, "scrum")
	if choix.has("lineout"): _repere(page, _point(Vertical.LARGEUR * .26, 92), choix.lineout, "lineout")

static func _repere(page: Control, centre: Vector2, choix: Array, cle: String) -> void:
	var couleur: Color = COULEURS_PHASE.get(cle, Charte.IVOIRE)
	var texte := "%s · %s" % [str(choix[0]).to_upper(), str(choix[1])]
	var w := Kit.largeur(texte, 20) + 64
	var plaque := D.rect(page, Rect2(centre.x - w / 2.0, centre.y - 24, w, 48), Color(Charte.PANNEAU, .92), Charte.RAYON_PILULE, couleur)
	plaque.name = "TacticsTabRepere_" + cle
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icone := C.icon(ICONES_PHASE.get(cle, "flag"), 24, couleur)
	plaque.add_child(icone)
	D.place(icone, Rect2(16, 12, 24, 24))
	Kit.texte(plaque, 48, 32, texte, couleur, w - 56, 20)

## Croquis d'une phase arrêtée sur un carré de pelouse : mêlée (deux paquets), touche (alignement et lancer), renvoi
## (demi-terrain, zone de chute).
class Croquis extends Control:
	var cle := "scrum"
	var id := ""
	var accent := Color.WHITE

	func _fleche(a: Vector2, b: Vector2, couleur: Color, e: float) -> void:
		draw_line(a, b, couleur, e, true)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var t := e * 3.0
		draw_colored_polygon(PackedVector2Array([b + d * t * .6, b - d * t + n * t * .8, b - d * t - n * t * .8]), couleur)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Charte.VERT_FRANC)
		var craie := Color(1, 1, 1, .35)
		var e := maxf(1.0, h * .012)
		var r := h * .05
		var nous := Charte.IVOIRE
		var eux := Color(Pieces.ORANGE, .9)
		var epais := maxf(2.0, h * .03)
		match cle:
			"scrum":
				draw_line(Vector2(w * .5, h * .1), Vector2(w * .5, h * .9), craie, e)
				for p in [Vector2(.42, .38), Vector2(.42, .5), Vector2(.42, .62), Vector2(.33, .42), Vector2(.33, .58), Vector2(.25, .36), Vector2(.25, .5), Vector2(.25, .64)]:
					draw_circle(Vector2(w * p.x, h * p.y), r, nous)
				for p in [Vector2(.58, .38), Vector2(.58, .5), Vector2(.58, .62), Vector2(.67, .42), Vector2(.67, .58), Vector2(.75, .36), Vector2(.75, .5), Vector2(.75, .64)]:
					draw_circle(Vector2(w * p.x, h * p.y), r, eux)
				match id:
					"pousser": _fleche(Vector2(w * .2, h * .84), Vector2(w * .72, h * .84), accent, epais * 1.4)
					"securiser": _fleche(Vector2(w * .3, h * .5), Vector2(w * .1, h * .82), accent, epais)
					_: _fleche(Vector2(w * .28, h * .84), Vector2(w * .5, h * .84), accent, epais)
			"lineout":
				draw_line(Vector2(w * .08, h * .05), Vector2(w * .08, h * .95), Color(1, 1, 1, .8), e * 1.5)
				draw_circle(Vector2(w * .04, h * .5), r, nous)
				var cible := {"courte": .26, "fond": .86, "maul": .4}.get(id, .55) as float
				for k in 6:
					draw_circle(Vector2(w * (.2 + k * .13), h * .42), r, nous)
					draw_circle(Vector2(w * (.2 + k * .13), h * .6), r, eux)
				var arc := PackedVector2Array()
				for k in 11:
					var t := k / 10.0
					arc.append(Vector2(lerpf(w * .06, w * cible, t), h * .42 - sin(t * PI) * h * .3))
				for k in 10: draw_line(arc[k], arc[k + 1], accent, epais, true)
				draw_circle(arc[10], r * 1.3, accent)
				if id == "maul": _fleche(Vector2(w * .4, h * .78), Vector2(w * .75, h * .78), accent, epais * 1.4)
			_:
				# Renvoi : médiane à gauche, ligne des 10 m en tirets, zone de chute du choix.
				var metre := w / 40.0
				draw_line(Vector2(0, 0), Vector2(0, h), Color(1, 1, 1, .8), e * 2)
				draw_dashed_line(Vector2(10 * metre, 0), Vector2(10 * metre, h), Color(1, 1, 1, .5), e, maxf(3.0, h * .05))
				draw_line(Vector2(22 * metre, 0), Vector2(22 * metre, h), craie, e)
				var portee: Vector2 = PORTEES.get(id, Vector2(10, 22))
				draw_rect(Rect2(portee.x * metre, h * .12, (portee.y - portee.x) * metre, h * .76), Color(accent, .5))
				draw_circle(Vector2(w * .02, h * .5), r, nous)
				var vol := PackedVector2Array()
				for k in 11:
					var t := k / 10.0
					vol.append(Vector2(lerpf(w * .03, (portee.x + portee.y) / 2.0 * metre, t), h * .5 - sin(t * PI) * h * .32))
				for k in 10:
					if k % 2 == 0: draw_line(vol[k], vol[k + 1], Charte.IVOIRE, epais, true)

# --- Entraînement ----------------------------------------------------------------------------------------------------

static func _entrainement(app: Control, page: Control) -> void:
	var squad: Array = app.model.get("squad", [])
	var meta: Dictionary = app.model.get("meta", {})
	var charge := 0.0
	for p: Dictionary in squad: charge += float(p.get("physicalLoad", 0))
	var surveilles := squad.filter(func(p: Dictionary) -> bool: return not Watch.watch_reason(p).is_empty())
	surveilles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("condition", 100)) < float(b.get("condition", 100)))
	var tuiles := [
		["%d %%" % roundi(float(P.group(app.model).get("condition", 0))), "Condition", Charte.CONDITION, "heart", func(): _ouvrir_entrainement(app, 4)],
		[str(roundi(float(meta.get("morale", 0)))) if meta.get("morale") is float or meta.get("morale") is int else "—", "Moral", Charte.MORAL, "people", func(): app._navigate("Vestiaire")],
		["%d" % roundi(charge / maxi(1, squad.size())), "Charge /100", Charte.INTENSIF, "train", func(): _ouvrir_entrainement(app, 4)],
		[str(surveilles.size()), "À surveiller", Charte.PERTE if not surveilles.is_empty() else Charte.IVOIRE_2, "warning", func(): _ouvrir_entrainement(app, 4)],
	]
	var gauche := Vertical.DROITE
	var largeur := 2248.0 - gauche
	_carte_forme(app, page)
	# Variantes visuelles A/B à l'essai (CD_VARIANTE_VISUELLE) : seule la colonne de droite change.
	var Variantes = load("res://ui/immersive08/tactics_entrainement_variantes.gd")
	var variante: String = Variantes.variante()
	if not variante.is_empty():
		Variantes.construire(app, page, variante, tuiles, surveilles)
		return
	# Tuiles de chiffres (clic → onglet Fatigue de l'entraînement ou Vestiaire).
	_titre_bloc(page, gauche, HAUT, "Le groupe", Charte.CONDITION)
	var tw := (largeur - 3 * 16) / 4.0
	for i in tuiles.size():
		var tuile: Array = tuiles[i]
		Pieces.tuile(page, Rect2(gauche + i * (tw + 16), HAUT + 48, tw, 130), tuile[0], tuile[1], tuile[2], "TacticsTabTuile%d" % i, 56, "", tuile[3], true, tuile[4])
	# Semaine : un grand pavé par jour, couleur de la séance.
	var y := HAUT + 204
	_titre_bloc(page, gauche, y, "La semaine", Charte.REPOS)
	_semaine(app, page, Rect2(gauche, y + 48, largeur, 230))
	y += 300
	_titre_bloc(page, gauche, y, "À surveiller", Charte.PERTE)
	_surveilles(app, page, Rect2(gauche, y + 48, largeur, BAS - y - 48), surveilles)

static func _semaine(app: Control, page: Control, zone: Rect2) -> void:
	var Panneaux = load("res://ui/immersive08/panneaux_effectif.gd")
	var jours: Array = Panneaux._jours_programme(app)
	if jours.is_empty(): return
	var w := (zone.size.x - 6 * 12) / 7.0
	for i in jours.size():
		var j: Dictionary = jours[i]
		var kind := str(j.get("kind", "repos"))
		var couleur: Color = Panneaux._couleur_jour(j)
		var rect := Rect2(zone.position.x + i * (w + 12), zone.position.y, w, zone.size.y)
		var pave := D.rect(page, rect, Charte.PANNEAU_2.lerp(couleur, .22) if kind != "repos" else Charte.PANNEAU_2, Charte.RAYON_CARTE, Charte.IVOIRE if bool(j.get("today", false)) else Color.TRANSPARENT)
		pave.name = "TacticsTabJour%d" % i
		if bool(j.get("past", false)): pave.modulate = Color(1, 1, 1, .55)
		D.rect(pave, Rect2(0, 0, w, 10), couleur, Charte.RAYON_PETIT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lettre := D.text(pave, 18, 70, str(j.get("lettre", "")), 48, couleur if kind != "repos" else Charte.IVOIRE_2, 500, 60)
		lettre.add_theme_font_override("font", Charte.TITRE_FICHE)
		var icone_id: String = Panneaux.JOURS.get(kind, ["", ""])[0]
		if bool(j.get("done", false)) or (kind == "match" and bool(j.get("played", false))): icone_id = "check"
		if not icone_id.is_empty():
			var icone := C.icon(icone_id, 40, couleur if kind != "repos" else Charte.IVOIRE_2)
			pave.add_child(icone)
			D.place(icone, Rect2(w - 58, 24, 40, 40))
		var mot: String = Panneaux.JOURS.get(kind, ["", kind])[1]
		Kit.titre(pave, 18, 140, mot, 24, w - 30).add_theme_font_override("font", Charte.TITRE_FICHE)
		if kind == "seance":
			var ch := str(j.get("charge", "normal"))
			var c: Color = {"repos": Charte.REPOS, "intense": Charte.INTENSIF}.get(ch, Charte.NORMAL)
			Pieces.pastille(pave, 18, 168, str(Panneaux.CHARGES.get(ch, "")), "train", "TacticsTabCharge%d" % i, "", c)
		D.text(pave, 18, zone.size.y - 14, str(j.get("date", "")), 15, Charte.IVOIRE_2, 600, w - 30)
		_transparent(pave)
		var aide := "%s · %s" % [str(j.get("date", "")), mot]
		Pieces.rendre_cliquable(pave, rect.size, func(): _ouvrir_entrainement(app, 0), "TacticsTabJourLien%d" % i, aide, "", Charte.RAYON_CARTE)

## Joueurs à surveiller : tuile portrait (anneau = condition), nom (survol = carte joueur, clic = fiche), chiffres.
static func _surveilles(app: Control, page: Control, zone: Rect2, joueurs: Array) -> void:
	var colonnes := 4
	var w := (zone.size.x - (colonnes - 1) * 12) / colonnes
	var h := 112.0
	var lignes := floori((zone.size.y + 12) / (h + 12))
	for n in mini(joueurs.size(), colonnes * lignes):
		var p: Dictionary = joueurs[n]
		var rect := Rect2(zone.position.x + (n % colonnes) * (w + 12), zone.position.y + floorf(n / float(colonnes)) * (h + 12), w, h)
		var tuile := D.rect(page, rect, Charte.PANNEAU_2, Charte.RAYON_CARTE)
		tuile.name = "TacticsTabSurveille%d" % n
		tuile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := Vertical._portrait(p, 84)
		tuile.add_child(portrait)
		portrait.position = Vector2(14, 14) * C.density
		portrait.size = Vector2(84, 84) * C.density
		var court := Kit.casse(str(p.get("name", "")), true)
		Kit.nom(app, tuile, Rect2(112, 14, minf(w - 124, Kit.largeur(court, 20) + 6), 30), court, str(p.get("id", "")), "TacticsTabSurveilleNom%d" % n, Charte.IVOIRE, 20)
		var x := 112.0
		var cond := float(p.get("condition", 100))
		if cond < 80: x += Pieces.pastille(tuile, x, 62, "%d %%" % roundi(cond), "heart", "TacticsTabSurveilleCond%d" % n, "", Charte.PERTE if cond < 70 else Pieces.ORANGE) + 8
		var ch := float(p.get("physicalLoad", 0))
		if ch >= 70 and x + 90 < w: Pieces.pastille(tuile, x, 62, "%d" % roundi(ch), "train", "TacticsTabSurveilleCharge%d" % n, "", Charte.INTENSIF)

## La pelouse verticale porte le XV de la feuille, anneau et chiffre de condition (carte de forme).
static func _carte_forme(app: Control, page: Control) -> void:
	var t := Kit.titre(page, 0, Vertical.BANDEAU.position.y + 32, "FORME DU XV", 28, 360)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.name = "TacticsTabPitchTitle"
	_pelouse(page)
	for numero: int in range(1, 16):
		var person := Selection.occupant(app.model, numero - 1)
		if person.is_empty(): continue
		var f: Vector2 = Vertical.PLACES[numero]
		var centre := _point(f.x * Vertical.LARGEUR, f.y * Vertical.LONGUEUR)
		var cote := 70.0
		var portrait := Vertical._portrait(person, cote)
		portrait.name = "TacticsTabForme%02d" % numero
		page.add_child(portrait)
		portrait.position = (centre - Vector2(cote / 2.0, cote / 2.0 + 18)) * C.density
		portrait.size = Vector2(cote, cote) * C.density
		var cond := float(person.get("condition", 100))
		var couleur: Color = Charte.CONDITION if cond >= 80 else Pieces.ORANGE if cond >= 70 else Charte.PERTE
		var texte := "%d %%" % roundi(cond)
		var lw := Kit.largeur(texte, 17) + 22
		var pilule := D.rect(page, Rect2(centre.x - lw / 2.0, centre.y + 22, lw, 26), Color(Charte.PANNEAU, .9), Charte.RAYON_PILULE)
		pilule.name = "TacticsTabFormeCond%02d" % numero
		pilule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(pilule, lw / 2.0, 19, texte, 17, couleur, 700, lw, HORIZONTAL_ALIGNMENT_CENTER, true)
		var court := Kit.casse(str(person.get("name", "")), true)
		var nw := minf(150, Kit.largeur(court, 15) + 6)
		# Plaque sombre sous le nom : il ne se perd plus dans les lignes blanches du terrain.
		var pw := nw + 16.0
		var plaque := D.rect(page, Rect2(centre.x - pw / 2.0, centre.y + 49, pw, 24), Color(Charte.PANNEAU, .9), Charte.RAYON_PILULE)
		plaque.name = "TacticsTabFormePlaque%02d" % numero
		plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.nom(app, page, Rect2(centre.x - nw / 2.0, centre.y + 49, nw, 24), court, str(person.get("id", "")), "TacticsTabFormeNom%02d" % numero, Charte.IVOIRE, 15)

# --- Alertes des sélections (ligne des onglets) ---------------------------------------------------------------

## Pastilles des sélections à droite des onglets : Bleus (liste des 33) et qualifications de Nationale. Rend x.
static func alertes(app: Control, page: Control, x: float, y: float) -> float:
	var bleus: Dictionary = app.SquadViews.bleus_resume(app)
	if not bleus.is_empty():
		var nb: int = (bleus.get("noms", []) as Array).size()
		x += Pieces.pastille(page, x, y, "33 · %d au repos" % nb, "flag-solid", "LineupBleusNotice", "", Charte.MORAL, Charte.PANNEAU_3, func(): _fenetre_bleus(app, page)) + 10
	var nationale: Dictionary = app.model.get("selection", {}).get("nationaleQualification", {})
	var notice: Dictionary = nationale.get("notice", {})
	if not notice.is_empty():
		var alerte: bool = notice.get("tone") == "alert"
		var v: Dictionary = nationale.get("verified", {})
		var l: Dictionary = nationale.get("limits", {})
		var texte := "FFR · B/C %d/%d · C %d/%d" % [int(v.get("B", 0)) + int(v.get("C", 0)), int(l.get("bc", 0)), int(v.get("C", 0)), int(l.get("c", 0))]
		x += Pieces.pastille(page, x, y, texte, "warning" if alerte else "shield", "NationaleLicenceNotice", "", Pieces.ROUGE if alerte else Pieces.TURQUOISE, Charte.PANNEAU_3, func(): _fenetre_nationale(app, page)) + 10
	return x

## Petite fenêtre des Bleus : qui souffle (portrait + 33), qui le remplace (portrait + condition), « Faire souffler ».
static func _fenetre_bleus(app: Control, page: Control) -> void:
	var bleus: Dictionary = app.SquadViews.bleus_resume(app)
	if bleus.is_empty(): return
	var echanges: Array = bleus.get("echanges", [])
	var ids: Array = []
	for item: Variant in app.model.get("clubLife", {}).get("doublons", {}).get("reposer", []):
		if item is Dictionary: ids.append(str(item.get("playerId", "")))
	var lignes := maxi(echanges.size(), 1) if not echanges.is_empty() else ceili(ids.size() / 3.0)
	var hauteur := 120.0 + lignes * 132 + (90.0 if not echanges.is_empty() else 20.0)
	var fond := Fenetre.ouvrir(page, "TacticsBleusFenetre", "BLEUS · LISTE DES 33", "flag", 900, hauteur)
	var y := 96.0
	if echanges.is_empty():
		for n in ids.size():
			_tuile_joueur(app, fond, Rect2(28 + (n % 3) * 286, y + floorf(n / 3.0) * 132, 270, 116), Selection.player(app.model, ids[n]), "33", Charte.MORAL, "TacticsBleusJoueur%d" % n)
	else:
		for n in echanges.size():
			var e: Dictionary = echanges[n]
			var rang := y + n * 132
			_tuile_joueur(app, fond, Rect2(28, rang, 380, 116), Selection.player(app.model, str(e.get("sortant", ""))), "33", Charte.MORAL, "TacticsBleusSortant%d" % n)
			D.text(fond, 450, rang + 72, "→", 40, Charte.IVOIRE_2, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
			var entrant := Selection.player(app.model, str(e.get("playerId", "")))
			_tuile_joueur(app, fond, Rect2(492, rang, 380, 116), entrant, "%d %%" % roundi(float(entrant.get("condition", 0))), Charte.CONDITION, "TacticsBleusEntrant%d" % n)
		var lot: Array = bleus.get("lot", [])
		var faire := Entete.bouton(fond, 900 - 28, "Faire souffler", "check", func():
			Fenetre.fermer(page, "TacticsBleusFenetre")
			app._command("set_lineup", {"changes": lot}), "LineupBleusRestAll", true)
		D.place(faire, Rect2(900 - 28 - faire.size.x / C.density, hauteur - 74, faire.size.x / C.density, 48))
		faire.disabled = not Selection.editable(app)

## Petite fenêtre des qualifications de Nationale : tuiles de chiffres, puis les joueurs de la feuille par carte A/B/C/?.
static func _fenetre_nationale(app: Control, page: Control) -> void:
	var nationale: Dictionary = app.model.get("selection", {}).get("nationaleQualification", {})
	var entrees: Array = nationale.get("entries", [])
	var groupes := {"A": [], "B": [], "C": [], "?": []}
	for e: Variant in entrees:
		if e is Dictionary: groupes[str(e.get("code")) if str(e.get("code")) in ["A", "B", "C"] else "?"].append(str(e.get("playerId", "")))
	var maximum := 1
	for k: String in groupes: maximum = maxi(maximum, (groupes[k] as Array).size())
	var hauteur := 96.0 + 120 + 60 + mini(maximum, 9) * 62 + 30
	var fond := Fenetre.ouvrir(page, "TacticsNationaleFenetre", "QUALIFICATIONS FFR", "shield", 1180, hauteur)
	var v: Dictionary = nationale.get("verified", {})
	var l: Dictionary = nationale.get("limits", {})
	var bc := int(v.get("B", 0)) + int(v.get("C", 0))
	var tuiles := [["%d/%d" % [bc, int(l.get("bc", 0))], "B / C", Pieces.ROUGE if bc > int(l.get("bc", 0)) else Pieces.VERT],
		["%d/%d" % [int(v.get("C", 0)), int(l.get("c", 0))], "C", Pieces.ROUGE if int(v.get("C", 0)) > int(l.get("c", 0)) else Pieces.VERT],
		[str(int(nationale.get("unverified", 0))), "Non vérifiées", Pieces.ORANGE if int(nationale.get("unverified", 0)) > 0 else Charte.IVOIRE_2]]
	for i in tuiles.size():
		Pieces.tuile(fond, Rect2(28 + i * 380, 90, 360, 110), tuiles[i][0], tuiles[i][1], tuiles[i][2], "TacticsNationaleTuile%d" % i, 44, "", "", true)
	var couleurs := {"A": Pieces.VERT, "B": Pieces.ORANGE, "C": Pieces.ROUGE, "?": Charte.IVOIRE_2}
	var x := 28.0
	for k: String in ["A", "B", "C", "?"]:
		Pieces.pastille(fond, x, 222, "Carte %s · %d" % [k, (groupes[k] as Array).size()], "", "TacticsNationaleCarte" + ("X" if k == "?" else k), "", couleurs[k])
		var ids: Array = groupes[k]
		for n in mini(ids.size(), 9):
			var p := Selection.player(app.model, ids[n])
			var court := Kit.casse(str(p.get("name", "")), true)
			var ligne := D.rect(fond, Rect2(x, 270 + n * 62, 272, 54), Charte.PANNEAU_2, Charte.RAYON_CARTE)
			ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Kit.marqueur(ligne, Rect2(6, 10, 4, 34), couleurs[k])
			var portrait := Vertical._portrait(p, 42)
			ligne.add_child(portrait)
			portrait.position = Vector2(18, 6) * C.density
			portrait.size = Vector2(42, 42) * C.density
			Kit.nom(app, ligne, Rect2(70, 12, minf(190, Kit.largeur(court, 18) + 6), 30), court, str(p.get("id", "")), "TacticsNationaleNom_%s_%d" % [("X" if k == "?" else k), n], Charte.IVOIRE, 18)
		x += 286

## Tuile joueur des petites fenêtres : portrait, nom (survol = carte, clic = fiche), puce de valeur.
static func _tuile_joueur(app: Control, parent: Control, rect: Rect2, p: Dictionary, valeur: String, couleur: Color, id: String) -> void:
	var tuile := D.rect(parent, rect, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	tuile.name = id
	tuile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := Vertical._portrait(p, 84)
	tuile.add_child(portrait)
	portrait.position = Vector2(14, 16) * C.density
	portrait.size = Vector2(84, 84) * C.density
	var court := Kit.casse(str(p.get("name", "")), true)
	Kit.nom(app, tuile, Rect2(112, 20, minf(rect.size.x - 124, Kit.largeur(court, 20) + 6), 30), court, str(p.get("id", "")), id + "Nom", Charte.IVOIRE, 20)
	Kit.puce(tuile, Rect2(112, 66, Kit.largeur(valeur, 16) + 24, 28), valeur, couleur, Charte.ENCRE, id + "Puce")
