extends RefCounted
## Graphiques, tuiles d'offre et petites fenêtres de Club › Direction (revue visuelle du 21/11/2026, n° 2 ; choix de
## Léo : règle à crans de la relève, mini-histogrammes des partenaires, tuiles d'offre, anneau du sentiment).
## Aucune donnée propre : chaque chiffre vient de `clubLife.clubStrategy`. Palette commune des données, jamais seule
## porteuse d'un sens (chaque barre, cran, anneau ou pastille a son chiffre ou son mot écrit) ; pas de doré (Continuer).
## Exemple : `Visuel.tuile_offre(rangee, "video", "Analyse vidéo", "12 000 €", "paiement unique", pilule)`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

## Pictogrammes absents de immersive08/icon-paths.json (trait 24 × 24, même dessin que les icônes de la coque).
const PICTOS := {
	"video": "M16 13l5.2 3.5a.5.5 0 0 0 .8-.4V7.9a.5.5 0 0 0-.8-.4L16 10.5 M4 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z",
	"croix": "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
	"camion": "M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2 M15 18H9 M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14 M5 18a2 2 0 1 0 4 0a2 2 0 1 0-4 0 M15 18a2 2 0 1 0 4 0a2 2 0 1 0-4 0",
	"poignee": "M11 17l2 2a1 1 0 1 0 3-3 M14 14l2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4 M21 3l1 11h-2 M3 3L2 14l6.5 6.5a1 1 0 1 0 3-3 M3 4h8",
}
static var _textures: Dictionary = {}

## Palette commune des données du jeu (demande de Léo du 21/11/2026 : « plus en couleurs »). Le rouge reste aux erreurs.
const VERT := Color("7fbf7a")
const BLEU := Color("5b9bd5")
const VIOLET := Color("a88bd6")
const TURQUOISE := Color("4fb3a9")
const ORANGE := Color("e0a04a")
## Couleur de chaque famille d'offre, par son pictogramme.
const TEINTES := {"school": VERT, "settings": ORANGE, "poignee": BLEU, "video": VIOLET, "croix": TURQUOISE, "camion": ORANGE,
	"people": BLEU, "heart": VIOLET, "home": TURQUOISE, "star": VIOLET, "money": VERT, "target": TURQUOISE, "warning": ORANGE}
## Critères des partenaires, dans l'ordre semaine / avance / victoire.
const CRITERES := [BLEU, VIOLET, VERT]

static func teinte(icone: String) -> Color:
	return TEINTES.get(icone, Charte.IVOIRE_2)

static func picto_texture(id: String, color: Color = Charte.IVOIRE) -> Texture2D:
	if not PICTOS.has(id): return C.icon_texture(id, color)
	var key := id + ":" + color.to_html()
	if _textures.has(key): return _textures[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [PICTOS[id], color.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]

static func picto(id: String, width: int = 40, color: Color = Charte.IVOIRE) -> TextureRect:
	var image := TextureRect.new()
	image.texture = picto_texture(id, color)
	image.custom_minimum_size = Vector2(C.px(width), C.px(width))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return image

## Rend une zone activable comme un bouton (souris : main et survol éclairci ; clavier : focus, Entrée ou Espace). Sert
## aux tuiles qui agissent (clic = leur pilule) ; les zones qui changent d'écran passent par ui/lien_zone.gd.
static func zone_cliquable(zone: Control, action: Callable) -> void:
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_entered.connect(func(): zone.modulate = Color(1.12, 1.12, 1.12))
	zone.mouse_exited.connect(func(): zone.modulate = Color.WHITE)
	zone.gui_input.connect(func(event: InputEvent):
		var clic: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var touche: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		if clic or touche:
			zone.accept_event()
			action.call())

## Tuile d'offre : pictogramme teinté et titre, gros chiffre, légende, graphique éventuel ; en pied la pastille d'état
## (`etat` : Control de Tuile.pastille, ou null) et la pilule. Un clic sur la tuile vaut un clic sur sa pilule (même
## confirmation en place) ; pilule grisée : tuile inerte, la pastille ou l'info-bulle de la pilule dit pourquoi.
static func tuile_offre(parent: Container, icone: String, titre: String, chiffre: String, legende: String, pilule: Button, etat: Control = null, graphique: Control = null, detail: String = "") -> PanelContainer:
	var couleur := teinte(icone)
	var tuile = Tuile.new(titre, "", false, couleur, true, detail)
	tuile.custom_minimum_size.x = C.px(250)
	parent.add_child(tuile)
	var image := picto(icone, 34, couleur)
	if tuile.titre != null:
		var tete: Control = tuile.titre.get_parent()
		tete.add_child(image)
		tete.move_child(image, 0)
		# Hauteur de deux lignes de titre : chiffres et graphiques alignés d'une tuile à l'autre.
		tete.custom_minimum_size.y = C.px(64)
	else:
		tuile.contenu.add_child(image)
		image.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bloc := C.v(0)
	tuile.contenu.add_child(bloc)
	bloc.add_child(C.label(chiffre, 40, Charte.IVOIRE, true, 700))
	if not legende.is_empty(): bloc.add_child(C.label(legende, 19, Charte.IVOIRE_2))
	if graphique != null: tuile.contenu.add_child(graphique)
	if etat != null: tuile.pied.add_child(etat)
	var vide := Control.new()
	C.fill(vide)
	tuile.pied.add_child(vide)
	tuile.pied.add_child(pilule)
	Tuile.proteger(tuile)
	if not pilule.disabled: zone_cliquable(tuile, func(): if not pilule.disabled: pilule.pressed.emit())
	return tuile

## Chiffre clé avec pictogramme teinté (onglet Supporters) ; renvoie la ligne pour y brancher sa petite fenêtre.
static func chiffre_picto(parent: Container, icone: String, valeur: String, legende: String) -> HBoxContainer:
	var ligne := C.h(12)
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(ligne)
	ligne.add_child(picto(icone, 44, teinte(icone)))
	var colonne := C.v(2)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(colonne)
	colonne.add_child(C.label(valeur, 40, Charte.IVOIRE, true, 700))
	colonne.add_child(C.label(legende, 17, Charte.IVOIRE_2, true, 600))
	Tuile.proteger(ligne)
	return ligne

## Tuile chiffrée d'une petite fenêtre : pictogramme teinté, gros chiffre, légende ; voile de la couleur.
static func tuile_chiffre(icone: String, valeur: String, legende: String) -> PanelContainer:
	var couleur := teinte(icone)
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(C.box(Charte.PANNEAU_2.lerp(couleur, .12), Color.TRANSPARENT, Charte.RAYON_CARTE, 18), Charte.RAYON_CARTE))
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ligne := C.h(12)
	cadre.add_child(ligne)
	ligne.add_child(picto(icone, 40, couleur))
	var colonne := C.v(2)
	ligne.add_child(colonne)
	colonne.add_child(C.label(valeur, 40, Charte.IVOIRE, true, 700))
	colonne.add_child(C.label(legende.to_upper(), 16, Charte.IVOIRE_2, true, 600))
	return cadre

## Petite fenêtre visuelle (règle de Léo du 21/11/2026 : permise si elle reste en tuiles et couleurs, sans bloc de texte) :
## voile sur la page, carte centrée avec titre, pilule « Fermer » et `blocs` (tuiles, anneaux, histogrammes). Fermée par
## « Fermer », un clic sur le voile ou Échap (mécanisme commun ui/petite_fenetre.gd). `nom` : nom du calque.
static func petite_fenetre(app: Control, nom: String, titre: String, blocs: Array) -> Control:
	var ancien := app.get_node_or_null(nom)
	if ancien != null: ancien.queue_free()
	var calque := Control.new()
	calque.name = nom
	calque.set_anchors_preset(Control.PRESET_FULL_RECT)
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	calque.z_index = 50
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, .55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	calque.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	var carte := PanelContainer.new()
	carte.name = nom + "Carte"
	carte.custom_minimum_size.x = minf(C.px(1180), app.size.x - 80.0)
	carte.add_theme_stylebox_override("panel", Charte.ombrer(C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 28), Charte.RAYON_PANNEAU))
	centre.add_child(carte)
	var colonne := C.v(18)
	carte.add_child(colonne)
	var tete := C.h(12)
	colonne.add_child(tete)
	var intitule := Tuile.titre_bloc(titre)
	C.fill(intitule)
	tete.add_child(intitule)
	var fermer := func():
		if is_instance_valid(calque):
			calque.remove_from_group(PetiteFenetre.GROUPE)
			calque.queue_free()
	tete.add_child(Tuile.pilule("Fermer", nom + "Fermer", true, "", fermer))
	for bloc: Control in blocs: colonne.add_child(bloc)
	voile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: fermer.call())
	Tuile.proteger(calque)
	app.add_child(calque)
	PetiteFenetre.enregistrer(calque, fermer)
	return calque

## Rangée de tuiles d'une petite fenêtre, de même hauteur.
static func rangee(tuiles: Array) -> HBoxContainer:
	var ligne := C.h(14)
	for tuile: Control in tuiles: ligne.add_child(tuile)
	return ligne

## Surface dessinée : texte posé à la ligne de base, police et couleur de la charte.
class Dessin extends Control:
	func ecrire(police: Font, position: Vector2, texte: String, taille: int, couleur: Color, largeur: float = -1, alignement: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string(police, position, texte, alignement, largeur, taille, couleur)

## Mini-histogramme : une barre par entrée, rapportée à son `maximum` ; montant écrit au-dessus, critère écrit dessous
## (dans la couleur de la barre). `barres` : [{valeur, maximum, montant, critere, couleur?}] ; sans couleur, l'ordre des
## critères des partenaires (semaine bleu, avance violet, victoire vert).
class Histogramme extends Dessin:
	var barres: Array = []
	func _init(liste: Array = [], hauteur: float = 150.0) -> void:
		barres = liste
		custom_minimum_size.y = C.px(hauteur)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if barres.is_empty(): return
		var n := barres.size()
		var colonne := size.x / n
		var haut_texte := C.px(26)
		var bas_texte := C.px(28)
		var zone := size.y - haut_texte - bas_texte
		for i in n:
			var barre: Dictionary = barres[i]
			var couleur: Color = barre.get("couleur", CRITERES[i % CRITERES.size()])
			var x := i * colonne
			var largeur := minf(colonne * .56, C.px(64))
			var gauche := x + (colonne - largeur) / 2.0
			var part := clampf(float(barre.valeur) / maxf(1.0, float(barre.maximum)), 0.0, 1.0)
			var socle := size.y - bas_texte
			draw_rect(Rect2(gauche, haut_texte, largeur, zone), Charte.PANNEAU_3)
			var hauteur := maxf(C.px(3), zone * part)
			draw_rect(Rect2(gauche, socle - hauteur, largeur, hauteur), couleur if part > 0 else Charte.FILET)
			ecrire(C.BOLD, Vector2(x, socle - hauteur - C.px(7)), str(barre.montant), C.font_px(17), Charte.IVOIRE, colonne, HORIZONTAL_ALIGNMENT_CENTER)
			ecrire(Charte.TEXTE, Vector2(x, size.y - C.px(6)), str(barre.critere), C.font_px(16), couleur, colonne, HORIZONTAL_ALIGNMENT_CENTER)

## Règle à crans : un rail, un cran par montant placé à l'échelle, une pilule cliquable sous chaque cran ; le cran actuel
## est plein et marqué « ACTUEL » (mot écrit, pas seulement la couleur). Un clic sur un cran vaut un clic sur sa pilule.
## `crans` : [{valeur, actuel}] ; `boutons` : une pilule par cran, construite par la vue (commande, confirmation en place).
class Regle extends Dessin:
	var crans: Array = []
	var boutons: Array = []
	const MARGE := 130.0
	const RAIL_Y := 58.0
	func _init(liste: Array = [], pilules: Array = []) -> void:
		crans = liste
		boutons = pilules
		custom_minimum_size.y = C.px(150)
		for bouton: Button in boutons: add_child(bouton)
		resized.connect(_placer)
		for bouton: Button in boutons: bouton.minimum_size_changed.connect(_placer)
	func _ready() -> void: _placer.call_deferred()
	func _cran(position: Vector2) -> int:
		if absf(position.y - C.px(RAIL_Y)) > C.px(30): return -1
		for i in crans.size():
			if absf(position.x - _x(i)) <= C.px(30) and i < boutons.size() and not (boutons[i] as Button).disabled: return i
		return -1
	## Centre d'un cran, dans le repère de la règle (tests : clic réel sur le cran).
	func centre_cran(index: int) -> Vector2:
		return Vector2(_x(index), C.px(RAIL_Y))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _cran(event.position) >= 0 else Control.CURSOR_ARROW
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var i := _cran(event.position)
			if i >= 0:
				accept_event()
				(boutons[i] as Button).pressed.emit()
	func _x(index: int) -> float:
		var maximum := 1.0
		for cran: Dictionary in crans: maximum = maxf(maximum, float(cran.valeur))
		var gauche := float(C.px(MARGE))
		return gauche + (size.x - 2.0 * gauche) * float(crans[index].valeur) / maximum
	func _placer() -> void:
		if not is_inside_tree(): return
		for i in boutons.size():
			var bouton: Button = boutons[i]
			var taille := bouton.get_combined_minimum_size()
			bouton.size = taille
			bouton.position = Vector2(_x(i) - taille.x / 2.0, C.px(RAIL_Y) + C.px(28))
		queue_redraw()
	func _draw() -> void:
		if crans.is_empty(): return
		var y := float(C.px(RAIL_Y))
		var debut := _x(0)
		var fin := _x(crans.size() - 1)
		var epaisseur := float(C.px(10))
		draw_rect(Rect2(debut, y - epaisseur / 2.0, fin - debut, epaisseur), Charte.PANNEAU_3)
		for i in crans.size():
			if crans[i].actuel and i > 0: draw_rect(Rect2(debut, y - epaisseur / 2.0, _x(i) - debut, epaisseur), VERT)
		for i in crans.size():
			var x := _x(i)
			var actuel: bool = crans[i].actuel
			draw_circle(Vector2(x, y), C.px(16), Charte.PANNEAU)
			draw_circle(Vector2(x, y), C.px(14), VERT if actuel else Charte.PANNEAU_3)
			if not actuel: draw_arc(Vector2(x, y), C.px(13), 0, TAU, 48, Charte.IVOIRE_2, C.px(3), true)
			if actuel: ecrire(C.BOLD, Vector2(x - C.px(100), y - C.px(26)), "ACTUEL", C.font_px(20), VERT, C.px(200), HORIZONTAL_ALIGNMENT_CENTER)
