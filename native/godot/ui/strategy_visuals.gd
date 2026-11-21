extends RefCounted
## Graphiques et cartes de Club › Direction (revue visuelle du 21/11/2026, n° 2) : cartes d'offre avec pictogramme,
## mini-histogramme des partenaires, règle à crans de la relève, barres groupées et anneau du sentiment.
## Aucune donnée propre : chaque chiffre vient de `clubLife.clubStrategy`. Couleurs : jetons de la charte (ui/charte.gd),
## jamais seules porteuses d'un sens (chaque barre, cran ou anneau a son chiffre écrit).
## Exemple : `Visuel.carte_offre(rangee, "video", "Analyse vidéo", "12 000 €", "paiement unique", bouton)`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")

## Pictogrammes absents de immersive08/icon-paths.json (trait 24 × 24, même dessin que les icônes de la coque).
const PICTOS := {
	"video": "M16 13l5.2 3.5a.5.5 0 0 0 .8-.4V7.9a.5.5 0 0 0-.8-.4L16 10.5 M4 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z",
	"croix": "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
	"camion": "M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2 M15 18H9 M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14 M5 18a2 2 0 1 0 4 0a2 2 0 1 0-4 0 M15 18a2 2 0 1 0 4 0a2 2 0 1 0-4 0",
	"poignee": "M11 17l2 2a1 1 0 1 0 3-3 M14 14l2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4 M21 3l1 11h-2 M3 3L2 14l6.5 6.5a1 1 0 1 0 3-3 M3 4h8",
}
static var _textures: Dictionary = {}
## Ouverture de l'écran Finances, posée par la vue à chaque construction (pastille « Trésorerie insuffisante »).
static var vers_finances: Callable

## Palette commune des données du jeu (demande de Léo du 21/11/2026 : « plus en couleurs »). Une couleur par donnée,
## jamais seule : le mot ou le chiffre est toujours écrit à côté. Pas de doré (réservé à Continuer).
const VERT := Color("7fbf7a")
const BLEU := Color("5b9bd5")
const VIOLET := Color("a88bd6")
const TURQUOISE := Color("4fb3a9")
const ORANGE := Color("e0a04a")
const ROUGE := Color("d9634f")
## Couleur de chaque famille d'offre, par son pictogramme.
const TEINTES := {"school": VERT, "settings": ORANGE, "poignee": BLEU, "video": VIOLET, "croix": ROUGE, "camion": ORANGE,
	"people": BLEU, "heart": VIOLET, "home": TURQUOISE, "star": VIOLET}
## Critères des partenaires, dans l'ordre semaine / avance / victoire.
const CRITERES := [BLEU, VIOLET, VERT]

## Rend une zone (carte, tuile chiffrée, jauge) cliquable au même titre qu'un bouton : souris (main, survol éclairci) et
## clavier (focus, Entrée ou Espace). Règle de Léo : ce qui ressemble à une tuile ouvre un écran ou agit.
static func zone_cliquable(zone: Control, action: Callable, nom: String = "") -> void:
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.focus_mode = Control.FOCUS_ALL
	if not nom.is_empty():
		zone.accessibility_name = nom
		zone.tooltip_text = nom
	zone.mouse_entered.connect(func(): zone.modulate = Color(1.15, 1.15, 1.15))
	zone.mouse_exited.connect(func(): zone.modulate = Color.WHITE)
	zone.gui_input.connect(func(event: InputEvent):
		var clic: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var touche: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		if clic or touche:
			zone.accept_event()
			action.call())

## Carte d'offre cliquable : un clic sur la carte vaut un clic sur sa pilule (même confirmation en place). Carte dont la
## pilule est grisée : rien, la pastille d'état dit pourquoi.
static func carte_agit(cadre: Control, bouton: Button) -> void:
	if bouton.disabled: return
	zone_cliquable(cadre, func(): if not bouton.disabled: bouton.pressed.emit())

static func teinte(icone: String) -> Color:
	return TEINTES.get(icone, Charte.IVOIRE_2)

## Fond de carte légèrement teinté (l'habillage des vues anciennes le ramène à ~10 % de la couleur sur le panneau).
static func cadre_teinte(contenu: Control, couleur: Color) -> void:
	var cadre := contenu.get_parent() as PanelContainer
	if cadre == null: return
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU.lerp(couleur, .30)
	style.set_corner_radius_all(Charte.RAYON_CARTE)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: style.set_content_margin(side, C.px(16))
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(style, Charte.RAYON_CARTE))
	# L'habillage des vues adoptées ramène les fonds verts au panneau : la teinte de la carte est voulue, on l'en exempte.
	cadre.set_meta("style_charte", true)

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
	return image

## Pastille d'état (« ACTUEL », « SIGNÉ », « ENGAGÉ » en vert clair ; une raison de blocage en doré) : mot + couleur.
static func etat(texte: String, favorable: bool = true) -> PanelContainer:
	var couleur := VERT if favorable else ORANGE
	var cadre := PanelContainer.new()
	cadre.set_meta("immersive_style_applied", true)
	cadre.set_meta("style_charte", true)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.PANNEAU.lerp(couleur, .18)
	fond.set_corner_radius_all(Charte.RAYON_PETIT)
	fond.content_margin_left = C.px(10); fond.content_margin_right = C.px(12)
	fond.content_margin_top = C.px(4); fond.content_margin_bottom = C.px(4)
	cadre.add_theme_stylebox_override("panel", fond)
	var ligne := HBoxContainer.new()
	ligne.set_meta("immersive_style_applied", true)
	ligne.set_meta("style_charte", true)
	ligne.add_theme_constant_override("separation", C.px(6))
	cadre.add_child(ligne)
	var image := picto("check" if favorable else "warning", 20, couleur)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(image)
	# Une raison de blocage d'argent mène à l'écran qui l'explique (la vue fournit `vers_finances`).
	if not favorable and vers_finances.is_valid(): zone_cliquable(cadre, vers_finances, "Ouvrir les finances")
	var mot := Label.new()
	mot.set_meta("immersive_style_applied", true)
	mot.set_meta("style_charte", true)
	mot.text = texte.to_upper()
	mot.add_theme_font_override("font", C.BOLD)
	mot.add_theme_font_size_override("font_size", C.font_px(19))
	mot.add_theme_color_override("font_color", couleur)
	ligne.add_child(mot)
	return cadre
## Titre de carte : Barlow Condensed gras, crème, posé tel quel (l'habillage des vues anciennes ne le réduit pas).
static func titre_carte(texte: String, retour: bool = true) -> Label:
	var nom := Label.new()
	nom.set_meta("immersive_style_applied", true)
	nom.set_meta("style_charte", true)
	nom.text = texte
	if retour:
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nom.custom_minimum_size.x = C.px(120)
	nom.add_theme_font_override("font", C.BOLD)
	nom.add_theme_font_size_override("font_size", C.font_px(27))
	nom.add_theme_color_override("font_color", Charte.IVOIRE)
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return nom

## Carte d'offre (option A) : pictogramme et titre, gros chiffre, légende, état, éventuel graphique, pilule « Choisir ».
## `bouton` est construit par la vue (nom, commande, confirmation en place) ; la carte ne fait que le poser.
static func carte_offre(parent: Container, icone: String, titre: String, chiffre: String, legende: String, bouton: Button, statut: String = "", favorable: bool = true, graphique: Control = null) -> VBoxContainer:
	var contenu := G.card(parent)
	var cadre := contenu.get_parent() as Control
	G.fill(cadre)
	cadre.custom_minimum_size.x = C.px(250)
	contenu.add_theme_constant_override("separation", C.px(10))
	var tete := G.h(10)
	contenu.add_child(tete)
	var image := picto(icone, 38, teinte(icone))
	cadre_teinte(contenu, teinte(icone))
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(image)
	if not titre.is_empty():
		# Hauteur de deux lignes de titre : chiffres et graphiques alignés d'une carte à l'autre.
		tete.custom_minimum_size.y = C.px(72)
		var nom := titre_carte(titre)
		G.fill(nom)
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(nom)
	else:
		tete.add_child(G.spacer())
	var bloc := G.v(0)
	contenu.add_child(bloc)
	bloc.add_child(G.label(chiffre, 34, G.INK, true))
	if not legende.is_empty(): bloc.add_child(G.wrap(legende, 12, G.MUTED))
	if graphique != null: contenu.add_child(graphique)
	var bas := G.h(8)
	bas.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	contenu.add_child(bas)
	if not statut.is_empty():
		var pastille := etat(statut, favorable)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bas.add_child(pastille)
	var vide := Control.new()
	G.fill(vide)
	bas.add_child(vide)
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bas.add_child(bouton)
	carte_agit(cadre, bouton)
	return contenu

## Carte d'offre couchée (une seule offre sur la ligne) : pictogramme, titre et légende, chiffre, état, pilule.
static func carte_couchee(parent: Container, icone: String, titre: String, chiffre: String, legende: String, bouton: Button, statut: String = "", favorable: bool = true, info: Control = null) -> HBoxContainer:
	var contenu := G.card(parent)
	var ligne := G.h(16)
	contenu.add_child(ligne)
	var image := picto(icone, 38, teinte(icone))
	cadre_teinte(contenu, teinte(icone))
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(image)
	var texte := G.v(2)
	G.fill(texte)
	ligne.add_child(texte)
	var tete := G.h(10)
	texte.add_child(tete)
	tete.add_child(titre_carte(titre, false))
	if info != null: tete.add_child(info)
	if not legende.is_empty(): texte.add_child(G.wrap(legende, 12, G.MUTED))
	texte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var montant := G.label(chiffre, 34, G.INK, true)
	montant.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(montant)
	if not statut.is_empty():
		var pastille := etat(statut, favorable)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(pastille)
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(bouton)
	carte_agit(contenu.get_parent() as Control, bouton)
	return ligne

## Chiffre clé avec pictogramme (option B, onglet Supporters).
static func chiffre_picto(parent: Container, icone: String, valeur: String, legende: String) -> void:
	var ligne := G.h(12)
	parent.add_child(ligne)
	var image := picto(icone, 44, teinte(icone))
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(image)
	var colonne := G.v(2)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(colonne)
	colonne.add_child(G.label(valeur, 34, G.INK, true))
	colonne.add_child(G.label(legende, 12, G.MUTED))

## Surface dessinée : texte posé à la ligne de base, police et couleur de la charte.
class Dessin extends Control:
	func ecrire(police: Font, position: Vector2, texte: String, taille: int, couleur: Color, largeur: float = -1, alignement: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string(police, position, texte, alignement, largeur, taille, couleur)

## Mini-histogramme (option A) : une barre par critère, rapportée au meilleur partenaire sur ce critère ; montant écrit
## au-dessus, critère écrit dessous. `barres` : [{valeur, maximum, montant, critere}].
class Histogramme extends Dessin:
	var barres: Array = []
	func _init(liste: Array = []) -> void:
		barres = liste
		custom_minimum_size.y = C.px(150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if barres.is_empty(): return
		var n := barres.size()
		var colonne := size.x / n
		var haut_texte := C.px(26)
		var bas_texte := C.px(28)
		var zone := size.y - haut_texte - bas_texte
		var taille := C.font_px(17)
		for i in n:
			var barre: Dictionary = barres[i]
			var x := i * colonne
			var largeur := minf(colonne * .56, C.px(64))
			var gauche := x + (colonne - largeur) / 2.0
			var part := clampf(float(barre.valeur) / maxf(1.0, float(barre.maximum)), 0.0, 1.0)
			var socle := size.y - bas_texte
			draw_rect(Rect2(gauche, haut_texte, largeur, zone), Charte.PANNEAU_3)
			var hauteur := maxf(C.px(3), zone * part)
			draw_rect(Rect2(gauche, socle - hauteur, largeur, hauteur), (CRITERES[i % CRITERES.size()] as Color) if part > 0 else Charte.FILET)
			ecrire(C.BOLD, Vector2(x, socle - hauteur - C.px(7)), str(barre.montant), taille, Charte.IVOIRE, colonne, HORIZONTAL_ALIGNMENT_CENTER)
			ecrire(Charte.TEXTE, Vector2(x, size.y - C.px(6)), str(barre.critere), C.font_px(16), CRITERES[i % CRITERES.size()], colonne, HORIZONTAL_ALIGNMENT_CENTER)

## Barres groupées (option B) : un groupe par critère, une barre par partenaire, nom et montant écrits.
## `groupes` : [{titre, lignes: [{nom, valeur, montant}]}] ; chaque groupe a son échelle (son meilleur partenaire).
class BarresGroupees extends Dessin:
	var groupes: Array = []
	## Pilule de chaque partenaire (même ordre que les lignes d'un groupe) : un clic sur sa barre la presse.
	var actions: Array = []
	const LIGNE := 40.0
	const TITRE := 40.0
	const ECART := 16.0
	func _init(liste: Array = []) -> void:
		groupes = liste
		var hauteur := 0.0
		for groupe: Dictionary in groupes: hauteur += TITRE + LIGNE * (groupe.lignes as Array).size() + ECART
		custom_minimum_size.y = C.px(hauteur)
	func _ligne(y_clic: float) -> int:
		var y := 0.0
		for groupe: Dictionary in groupes:
			y += C.px(TITRE)
			for i in (groupe.lignes as Array).size():
				if y_clic >= y and y_clic < y + C.px(LIGNE): return i
				y += C.px(LIGNE)
			y += C.px(ECART)
		return -1
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var i := _ligne(event.position.y)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i >= 0 and i < actions.size() and not (actions[i] as Button).disabled else Control.CURSOR_ARROW
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var i := _ligne(event.position.y)
			if i >= 0 and i < actions.size() and not (actions[i] as Button).disabled:
				accept_event()
				(actions[i] as Button).pressed.emit()
	func _draw() -> void:
		var y := 0.0
		var nom_largeur := C.px(270)
		var montant_largeur := C.px(150)
		var rail := maxf(10.0, size.x - nom_largeur - montant_largeur - C.px(24))
		for g in groupes.size():
			var groupe: Dictionary = groupes[g]
			var couleur: Color = CRITERES[g % CRITERES.size()]
			ecrire(C.BOLD, Vector2(0, y + C.px(28)), str(groupe.titre).to_upper(), C.font_px(19), couleur)
			y += C.px(TITRE)
			var maximum := 1.0
			for ligne: Dictionary in groupe.lignes: maximum = maxf(maximum, float(ligne.valeur))
			for ligne: Dictionary in groupe.lignes:
				var milieu := y + C.px(LIGNE) / 2.0
				ecrire(Charte.TEXTE, Vector2(0, milieu + C.px(7)), str(ligne.nom), C.font_px(19), Charte.IVOIRE, nom_largeur - C.px(10))
				var gauche := nom_largeur
				var epaisseur := C.px(18)
				draw_rect(Rect2(gauche, milieu - epaisseur / 2.0, rail, epaisseur), Charte.PANNEAU_3)
				var part := clampf(float(ligne.valeur) / maximum, 0.0, 1.0)
				if part > 0: draw_rect(Rect2(gauche, milieu - epaisseur / 2.0, maxf(C.px(3), rail * part), epaisseur), couleur)
				ecrire(C.BOLD, Vector2(gauche + rail + C.px(14), milieu + C.px(8)), str(ligne.montant), C.font_px(22), Charte.IVOIRE, montant_largeur)
				y += C.px(LIGNE)
			y += C.px(ECART)

## Anneau (option B) : part de `valeur` sur `maximum`, chiffre au centre (« 50 » et « / 100 »).
class Anneau extends Dessin:
	var valeur := 0.0
	var maximum := 100.0
	func _init(v: float = 0.0, m: float = 100.0) -> void:
		valeur = v
		maximum = m
		custom_minimum_size = Vector2(C.px(150), C.px(150))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var centre := size / 2.0
		var epaisseur := float(C.px(16))
		var rayon := minf(size.x, size.y) / 2.0 - epaisseur / 2.0 - 1.0
		draw_arc(centre, rayon, 0, TAU, 96, Charte.PANNEAU_3, epaisseur, true)
		var part := clampf(valeur / maxf(1.0, maximum), 0.0, 1.0)
		if part > 0: draw_arc(centre, rayon, -PI / 2.0, -PI / 2.0 + TAU * part, 96, TURQUOISE, epaisseur, true)
		ecrire(C.BOLD, Vector2(0, centre.y + C.px(14)), str(roundi(valeur)), C.font_px(52), Charte.IVOIRE, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		ecrire(Charte.TEXTE, Vector2(0, centre.y + C.px(40)), "/ %d" % roundi(maximum), C.font_px(17), Charte.IVOIRE_2, size.x, HORIZONTAL_ALIGNMENT_CENTER)

## Règle à crans (option B) : un rail, un cran par montant placé à l'échelle, une pilule cliquable sous chaque cran ;
## le cran actuel est plein et marqué « ACTUEL » (mot écrit, pas seulement la couleur). `crans` : [{valeur, actuel}],
## `boutons` : une pilule par cran, construite par la vue (nom, commande, confirmation en place).
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
	## Un clic sur un cran (ou tout près) presse sa pilule, comme la pilule elle-même.
	func _cran(position: Vector2) -> int:
		if absf(position.y - C.px(RAIL_Y)) > C.px(30): return -1
		for i in crans.size():
			if absf(position.x - _x(i)) <= C.px(30) and i < boutons.size() and not (boutons[i] as Button).disabled: return i
		return -1
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
