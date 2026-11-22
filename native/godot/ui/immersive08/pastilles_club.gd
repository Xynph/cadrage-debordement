extends RefCounted
## Pastilles, tuiles de chiffre et petit « i » des écrans Club, Formation et Vestiaire (revue « phrases à retirer » du 21/11/2026).
## Règle : un compteur devient une tuile (gros chiffre + légende courte), un état une pastille (icône + un mot), une consigne
## disparaît ou passe derrière un « i » (infobulle) ; la couleur ne porte jamais seule le sens (icône ou mot, ▲ / ▼).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")

const VERT := Color("7fbf7a")       ## bon, gain
const ORANGE := Color("e0a04a")     ## vigilance
const ROUGE := Color("d9634f")      ## danger, perte
const BLEU := Color("5b9bd5")       ## information, moral
const VIOLET := Color("a88bd6")     ## confiance
const TURQUOISE := Color("4fb3a9")  ## repère neutre vivant (jalon, potentiel, fin)

## Pastille d'état : voile de la couleur, texte de la couleur, icône facultative (icon-paths.json), infobulle facultative.
static func pastille(texte: String, couleur: Color = BLEU, icone: String = "", bulle: String = "", taille: int = 18, id: String = "", action: Callable = Callable()) -> Control:
	var cadre := PanelContainer.new()
	var fond := C.box(Color(couleur, .15), Color.TRANSPARENT, Charte.RAYON_PETIT, 8)
	fond.content_margin_left = C.px(10)
	fond.content_margin_right = C.px(10)
	fond.content_margin_top = C.px(3)
	fond.content_margin_bottom = C.px(3)
	cadre.add_theme_stylebox_override("panel", fond)
	if not id.is_empty(): cadre.name = id
	var rangee := C.h(6)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(rangee)
	if not icone.is_empty():
		var pictogramme := C.icon(icone, taille, couleur)
		pictogramme.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(pictogramme)
	if not texte.is_empty():
		var mot := C.label(texte, taille, couleur, true, 600)
		rangee.add_child(mot)
	cadre.tooltip_text = bulle if not bulle.is_empty() else texte
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cadre.accessibility_name = cadre.tooltip_text
	return _cliquable(cadre, action, Charte.RAYON_PETIT)

## Tuile de chiffre : gros chiffre + légende courte en capitales (charte : carte rayon 12, ombre de tuile).
static func tuile(valeur: String, legende: String, couleur: Color = Charte.IVOIRE, fond: Color = Charte.PANNEAU_2, taille: int = 34, id: String = "", en_ligne: bool = false, action: Callable = Callable()) -> Control:
	var cadre := PanelContainer.new()
	# Tuile colorée : léger fond teinté (alerte, gain) ; chiffre ivoire = tuile neutre.
	if couleur != Charte.IVOIRE: fond = fond.lerp(couleur, .14)
	var style := C.box(fond, Color.TRANSPARENT, Charte.RAYON_CARTE, 10)
	style.content_margin_top = C.px(6)
	style.content_margin_bottom = C.px(8)
	cadre.add_theme_stylebox_override("panel", style)
	if not id.is_empty(): cadre.name = id
	var colonne: BoxContainer = C.h(8) if en_ligne else C.v(0)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(colonne)
	var chiffre := C.label(valeur, taille, couleur, true, 800)
	chiffre.name = "Valeur"
	colonne.add_child(chiffre)
	var mot := C.label(legende.to_upper(), maxi(13, int(taille * .42)), Charte.IVOIRE_2, true, 600)
	mot.name = "Legende"
	if en_ligne: mot.size_flags_vertical = Control.SIZE_SHRINK_END
	colonne.add_child(mot)
	cadre.tooltip_text = "%s %s" % [valeur, legende]
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.accessibility_name = cadre.tooltip_text
	return _cliquable(cadre, action, Charte.RAYON_CARTE)

## Tout ce qui a l'air cliquable l'est : avec une action, la pastille ou la tuile devient un vrai bouton (même nom, signal
## `pressed`, survol, focus clavier) qui change d'écran ; sans action, elle reste un simple affichage (aucun survol, aucun curseur).
static func _cliquable(contenu: PanelContainer, action: Callable, rayon: int) -> Control:
	_marquer(contenu)
	if not action.is_valid(): return contenu
	var bouton := Button.new()
	bouton.set_meta("immersive_style_applied", true)
	bouton.name = contenu.name if contenu.name != &"" and not str(contenu.name).begins_with("@") else "Pastille"
	bouton.flat = true
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = contenu.tooltip_text
	bouton.accessibility_name = contenu.accessibility_name
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(maxi(3, C.px(rayon)))
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .1)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: bouton.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: bouton.add_theme_stylebox_override(etat, survol)
	bouton.add_theme_stylebox_override("focus", focus)
	contenu.name = "Contenu"
	contenu.tooltip_text = ""
	bouton.add_child(contenu)
	_ignorer(contenu)
	var minimum := contenu.get_combined_minimum_size()
	# Cible d'au moins 30 px de haut (plancher des commandes), contenu centré.
	var haut := maxf(minimum.y, 30.0)
	contenu.position = Vector2(0, (haut - minimum.y) / 2.0)
	contenu.size = minimum
	bouton.custom_minimum_size = Vector2(minimum.x, haut)
	bouton.size = Vector2(minimum.x, haut)
	bouton.pressed.connect(action)
	# Survol et appui : retour commun des tuiles cliquables (ui/retour_tuile.gd).
	load("res://ui/retour_tuile.gd").brancher(bouton, bouton, vide.corner_radius_top_left)
	return bouton

## Le style de la page (legacy_style) ne retouche pas ces contrôles : couleurs, rayons et focus sont déjà ceux de la charte.
static func _marquer(noeud: Node) -> void:
	noeud.set_meta("immersive_style_applied", true)
	for enfant in noeud.get_children(): _marquer(enfant)

static func _ignorer(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for enfant in noeud.get_children(): _ignorer(enfant)

## Petit « i » : la règle ou la légende en infobulle. `signe` vaut « ? » pour les raccourcis clavier.
static func info(texte: String, signe: String = "i", id: String = "", cote: int = 26) -> Button:
	var bouton := Button.new()
	if not id.is_empty(): bouton.name = id
	bouton.text = signe
	bouton.flat = false
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_HELP
	bouton.tooltip_text = texte
	bouton.accessibility_name = ("Aide · " if signe == "?" else "Légende · ") + texte
	# Cible cliquable d'au moins 24 px à l'écran quelle que soit la résolution (à 1280×720, 26 unités du gabarit ne font
	# que 13 px) : plancher de 26 px, la coque réduisant encore un peu la page (≈ 0,98) à cette taille. Le rond dessiné
	# garde sa taille du gabarit : seule la zone cliquable s'agrandit autour de lui (marges négatives des styles).
	var rond := float(C.px(cote))
	var cote_px := maxf(26.0, rond)
	var retrait := -(cote_px - rond) / 2.0
	bouton.custom_minimum_size = Vector2(cote_px, cote_px)
	bouton.add_theme_font_override("font", C.BOLD)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(cote * .62)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(etat, BLEU)
	for etat in ["normal", "hover", "pressed", "disabled"]:
		var style := C.box(Color.TRANSPARENT if etat == "normal" else Charte.PANNEAU_2, BLEU, Charte.RAYON_PILULE, 0)
		Charte.sans_ombre(style)
		style.set_border_width_all(1)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.set_expand_margin_all(retrait)
		bouton.add_theme_stylebox_override(etat, style)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(retrait)
	Charte.sans_ombre(focus)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.set_meta("immersive_style_applied", true)
	return bouton

## Pose un contrôle construit ci-dessus dans une page dessinée en unités du gabarit : (x, haut) = coin haut gauche.
## Rend sa largeur en unités du gabarit pour enchaîner la pastille suivante.
static func poser(parent: Control, controle: Control, x: float, haut: float) -> float:
	parent.add_child(controle)
	var minimum := controle.get_combined_minimum_size()
	controle.position = Vector2(x, haut) * C.density
	controle.size = minimum
	return minimum.x / C.density

## Aligne un contrôle à droite : (x_droit, haut) = coin haut droit.
static func poser_a_droite(parent: Control, controle: Control, x_droit: float, haut: float) -> float:
	parent.add_child(controle)
	var minimum := controle.get_combined_minimum_size()
	controle.position = Vector2(x_droit * C.density - minimum.x, haut * C.density)
	controle.size = minimum
	return minimum.x / C.density

## « 750 000 » → « 750 k€ », « 1 250 000 » → « 1,25 M€ », sous 1 000 : « 800 € ».
static func euros_courts(valeur: Variant) -> String:
	if valeur == null: return "—"
	var v := float(valeur)
	var a := absf(v)
	var signe := "−" if v < 0.0 else ""
	if a >= 1000000.0: return signe + ("%s M€" % String.num(a / 1000000.0, 2).rstrip("0").rstrip(".")).replace(".", ",")
	if a >= 1000.0: return signe + "%d k€" % roundi(a / 1000.0)
	return signe + "%d €" % roundi(a)
