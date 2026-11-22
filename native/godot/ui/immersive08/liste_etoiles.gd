extends RefCounted
## Effectif : « poste → étoiles » (revue FM27, idée 5, planche A/B du 22/11/2026, pas encore tranchée par Léo).
## Un poste choisi au-dessus de la liste : chaque joueur montre ses étoiles À CE POSTE (capacité au poste uniquement,
## barème de la carte joueur). Badges de statut colorés (Blessé, Suspendu, Sélection, Offre, Départ, Jeune).
##   A : rangée de boutons de poste (numéros) à droite des pastilles de groupe ; la colonne POSTE devient « ★ poste ».
##   B : petit terrain cliquable des 15 postes (couleur = nombre de joueurs à 4 étoiles et plus) ; tri automatique par
##       étoiles ; badges courts derrière le nom.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")

## Boutons de poste : [numéro de référence, libellé du bouton, nom du poste, numéros couverts].
const POSTES := [
	[1, "1", "Pilier gauche", [1]], [2, "2", "Talonneur", [2]], [3, "3", "Pilier droit", [3]],
	[4, "4·5", "Deuxième ligne", [4, 5]], [6, "6·7", "3e ligne aile", [6, 7]], [8, "8", "Numéro 8", [8]],
	[9, "9", "Demi de mêlée", [9]], [10, "10", "Demi d’ouverture", [10]], [12, "12·13", "Centre", [12, 13]],
	[11, "11·14", "Ailier", [11, 14]], [15, "15", "Arrière", [15]],
]
## Terrain couché, on attaque vers la droite : place de chaque numéro (fractions largeur, hauteur).
const PLACES := {1: Vector2(.1, .2), 2: Vector2(.1, .5), 3: Vector2(.1, .8), 4: Vector2(.22, .35), 5: Vector2(.22, .65),
	6: Vector2(.31, .14), 7: Vector2(.31, .86), 8: Vector2(.37, .5), 9: Vector2(.5, .36), 10: Vector2(.6, .62),
	12: Vector2(.71, .36), 13: Vector2(.8, .62), 11: Vector2(.84, .1), 14: Vector2(.84, .9), 15: Vector2(.93, .5)}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return "B" if v == "B" else "A"

## Numéro de référence du poste (12 pour 12 et 13…) et son nom.
static func poste_reference(numero: int) -> int:
	for p: Array in POSTES:
		if numero in p[3]: return int(p[0])
	return numero

static func nom_poste(numero: int) -> String:
	for p: Array in POSTES:
		if numero in p[3]: return str(p[2])
	return ""

## Poste principal du joueur en abrégé (PG, T, 2L, DO…) ; "" si inconnu.
static func abrege(joueur: Dictionary) -> String:
	var sigles := {1: "PG", 2: "T", 3: "PD", 4: "2L", 5: "2L", 6: "3L", 7: "3L", 8: "N8", 9: "DM", 10: "DO", 11: "AL", 12: "C", 13: "C", 14: "AL", 15: "AR"}
	var source: Variant = joueur.get("primaryPositions", [joueur.get("primaryPosition")])
	if source is Array:
		for v: Variant in source:
			if (v is int or v is float) and sigles.has(int(v)): return str(sigles[int(v)])
	return ""

static func etoiles(joueur: Dictionary, numero: int) -> float:
	return CarteSurvol.etoiles_poste(joueur, numero) if numero > 0 else -1.0

## Joueurs à 4 étoiles et plus au poste (profondeur du poste).
static func profondeur(joueurs: Array, numero: int) -> int:
	var n := 0
	for p: Variant in joueurs:
		if p is Dictionary and etoiles(p, numero) >= 4.0: n += 1
	return n

static func couleur_profondeur(n: int) -> Color:
	if n <= 0: return R.ROUGE
	if n == 1: return R.ORANGE
	if n == 2: return Charte.couleur_attribut(60)
	return R.VERT

# ---------------------------------------------------------------- badges de statut

## Badges colorés du joueur : [{id, t (mot), court, c, icone, cible}] ; cible = "fiche", "contrat", "formation", "selections".
static func badges(app: Control, joueur: Dictionary) -> Array:
	var sortie: Array = []
	var U = load("res://ui/management_state.gd")
	match U.indisponibilite(joueur):
		"blesse":
			var semaines := ceili(float(joueur.get("injury", 0)))
			sortie.append({"id": "Blesse", "t": "Blessé · %d sem." % semaines, "court": "✚ %d sem." % semaines, "c": R.ROUGE, "icone": "", "cible": "fiche"})
		"suspendu":
			sortie.append({"id": "Suspendu", "t": "! Suspendu", "court": "! Susp.", "c": R.ROUGE, "icone": "", "cible": "fiche"})
		"selection":
			sortie.append({"id": "Selection", "t": "◇ Sélection", "court": "◇ Sél.", "c": R.BLEU, "icone": "", "cible": "selections"})
	var vente: Variant = joueur.get("sale")
	if vente is Dictionary:
		if vente.get("pending") is Dictionary: sortie.append({"id": "Depart", "t": "Départ", "court": "Départ", "c": R.ROUGE, "icone": "money", "cible": "contrat"})
		elif vente.get("offerId") is String: sortie.append({"id": "Offre", "t": "Offre", "court": "Offre", "c": R.ORANGE, "icone": "money", "cible": "contrat"})
	var age: Variant = joueur.get("age")
	if (age is int or age is float) and int(age) <= 21:
		sortie.append({"id": "Jeune", "t": "Jeune", "court": "Jeune", "c": R.VERT, "icone": "", "cible": "formation"})
	return sortie

static func ouvrir_badge(app: Control, joueur: Dictionary, b: Dictionary) -> void:
	var id := str(joueur.get("id", ""))
	match str(b.cible):
		"formation": app._navigate("Formation")
		"selections": app._navigate("Sélections")
		_:
			app.selected_player = id
			app.navigation_controller.open_entity({"kind": "player", "id": id, "section": "contract" if b.cible == "contrat" else ""})

## Pose les badges en ligne à partir de x (unités du gabarit) ; renvoie la largeur occupée. `courts` : libellé court.
static func poser_badges(app: Control, rangee: Control, joueur: Dictionary, x: float, base: float, courts: bool, largeur_max: float, taille := 19) -> float:
	var depart := x
	for b: Dictionary in badges(app, joueur):
		var texte := str(b.court if courts else b.t)
		var l := 12.0 + (float(taille) + 9.0 if not str(b.icone).is_empty() else 0.0) + R.largeur(texte, taille) + 2.0 + 12.0
		if x + l - depart > largeur_max: break
		var fond := R.pastille(rangee, x, base, texte, b.c, str(b.icone), "RosterBadge_" + str(b.id), taille)
		fond.tooltip_text = str(b.t)
		var bouton := R.cliquable(fond, ouvrir_badge.bind(app, joueur, b), "RosterBadgeOuvrir_" + str(b.id), str(b.t) + " · " + str(joueur.get("name", "")))
		bouton.tooltip_text = str(b.t)
		x += l + 6.0
	return x - depart

# ---------------------------------------------------------------- A : rangée de boutons de poste

static func rangee_postes(parent: Control, origine: Vector2, actif: int, choisir: Callable) -> Control:
	var rangee := Control.new()
	rangee.name = "EtoilesPostes"
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rangee)
	var repere := D.text(rangee, 0, 29, "★", 26, Charte.couleur_attribut(80) if actif > 0 else Charte.IVOIRE_2, 800, 30)
	repere.name = "EtoilesPostesRepere"
	repere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 34.0
	for p: Array in POSTES:
		var numero := int(p[0])
		var est := numero == actif
		var texte := str(p[1])
		var l := R.largeur(texte, 19, 700) + 26.0
		var b := Button.new()
		b.name = "EtoilesPoste_%d" % numero
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = str(p[2])
		b.accessibility_name = "Étoiles au poste · %s%s" % [p[2], " · actif" if est else ""]
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(maxi(2, C.px(Charte.RAYON_PETIT)))
			s.bg_color = Charte.IVOIRE if est else (Charte.PANNEAU_2 if etat == "hover" else Charte.PANNEAU_3)
			if etat == "focus":
				s.bg_color = Color.TRANSPARENT
				s.border_color = Charte.IVOIRE
				s.set_border_width_all(maxi(1, C.px(2)))
				s.set_expand_margin_all(2)
			b.add_theme_stylebox_override(etat, s)
		rangee.add_child(b)
		D.place(b, Rect2(x, 0, l, 40))
		var t := D.text(b, l / 2.0, 27, texte, 19, Charte.PANNEAU if est else Charte.IVOIRE, 700, l, HORIZONTAL_ALIGNMENT_CENTER)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): choisir.call(0 if est else numero))
		x += l + 6.0
	D.place(rangee, Rect2(origine, Vector2(x, 40)))
	return rangee

static func largeur_rangee() -> float:
	var x := 34.0
	for p: Array in POSTES: x += R.largeur(str(p[1]), 19, 700) + 26.0 + 6.0
	return x

# ---------------------------------------------------------------- B : petit terrain cliquable

static func terrain_postes(parent: Control, zone: Rect2, joueurs: Array, actif: int, choisir: Callable) -> Control:
	var pelouse := D.rect(parent, zone, Charte.PELOUSE, 12)
	pelouse.name = "EtoilesTerrain"
	pelouse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ligne := Color(Charte.CREME, .22)
	for f: float in [.04, .45, .96]:
		var filet := D.rect(pelouse, Rect2(zone.size.x * f, 6, 1.5, zone.size.y - 12), ligne)
		filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := clampf(zone.size.y * .27, 26.0, 36.0)
	for n: int in PLACES:
		var ref := poste_reference(n)
		var prof := profondeur(joueurs, n)
		var couleur := couleur_profondeur(prof)
		var est := ref == actif
		var c: Vector2 = Vector2(PLACES[n].x * zone.size.x, PLACES[n].y * zone.size.y)
		var b := Button.new()
		b.name = "EtoilesTerrainPoste_%d" % n
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%d · %s · %d ★4+" % [n, nom_poste(n), prof]
		b.accessibility_name = "Étoiles au poste %d, %s, %d joueurs à 4 étoiles et plus%s" % [n, nom_poste(n), prof, " · actif" if est else ""]
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(999)
			s.bg_color = couleur.lightened(.2) if etat == "hover" else couleur
			if est or etat == "focus":
				s.border_color = Charte.CREME
				s.set_border_width_all(maxi(2, C.px(3)))
				s.set_expand_margin_all(maxi(2, C.px(3)))
			b.add_theme_stylebox_override(etat, s)
		pelouse.add_child(b)
		D.place(b, Rect2(c.x - d / 2.0, c.y - d / 2.0, d, d))
		var t := D.text(b, d / 2.0, d / 2.0 + 7, str(n), 19, Charte.ENCRE, 800, d, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_font_override("font", Charte.TITRE_GRAS)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): choisir.call(0 if est else ref))
	return pelouse

## Légende du terrain B : poste choisi en grand + nombre de joueurs à 4 étoiles et plus ; rien si aucun poste.
static func titre_poste(parent: Control, x: float, base: float, joueurs: Array, actif: int, effacer: Callable) -> void:
	if actif <= 0: return
	var nom := nom_poste(actif).to_upper()
	var numeros: Array = []
	for p: Array in POSTES:
		if int(p[0]) == actif: numeros = p[3]
	var titre := D.text(parent, x, base, nom, 34, Charte.IVOIRE, 800, 520)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "EtoilesTitrePoste"
	var l := R.largeur(nom, 34, 800) + 18.0
	var prof := profondeur(joueurs, actif)
	var pastille := R.pastille(parent, x + l, base - 4, "%d × ★4+" % prof, couleur_profondeur(prof), "", "EtoilesProfondeur", 20)
	pastille.tooltip_text = "Joueurs à 4 étoiles et plus au poste " + "·".join(numeros.map(func(v): return str(v)))
	var fermer := Button.new()
	fermer.name = "EtoilesEffacer"
	fermer.text = "✕"
	fermer.tooltip_text = "Retirer les étoiles"
	fermer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	C.style_bouton_lien(fermer, 19)
	parent.add_child(fermer)
	D.place(fermer, C.reach_rect(Rect2(x + l + pastille.size.x / C.density + 12.0, base - 30, 40, 40)))
	fermer.pressed.connect(func(): effacer.call(0))
