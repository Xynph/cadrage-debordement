extends RefCounted
## Cadre commun des petites fenêtres visuelles de la coque (règle de Léo du 21/11/2026 : permises si elles restent
## visuelles, jamais un bloc de texte). Voile sombre sur toute la toile, panneau rayon 18, titre, ✕ ; Échap, ✕ et clic à
## côté la ferment (mécanisme commun petite_fenetre.gd). Coordonnées en unités du gabarit (2248 × 1230).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

## Ouvre la fenêtre `nom` sur `page` (la toile de l'écran) et rend son panneau, où poser le contenu. Une fenêtre du même
## nom déjà ouverte est remplacée. `apres_fermeture` est appelé à la fermeture (rend le focus à l'élément cliqué).
static func ouvrir(page: Control, nom: String, titre: String, icone: String, largeur: float, hauteur: float, apres_fermeture: Callable = Callable()) -> Panel:
	var ancienne := page.find_child(nom, true, false)
	if ancienne != null:
		ancienne.name = nom + "Fermee"
		ancienne.remove_from_group(PetiteFenetre.GROUPE)
		ancienne.queue_free()
	var calque := Control.new()
	calque.name = nom
	page.add_child(calque)
	D.place(calque, Rect2(0, 0, 2248, 1230))
	var fermer := func():
		if is_instance_valid(calque): calque.queue_free()
		if apres_fermeture.is_valid(): apres_fermeture.call()
	PetiteFenetre.enregistrer(calque, fermer)
	var refermer := func(): PetiteFenetre.fermer_derniere(calque.get_tree())
	var voile := Button.new()
	voile.name = nom + "Voile"
	voile.focus_mode = Control.FOCUS_NONE
	for etat: String in ["normal", "hover", "pressed"]:
		var fond_voile := StyleBoxFlat.new()
		fond_voile.bg_color = Color(Charte.NUIT, .45)
		voile.add_theme_stylebox_override(etat, fond_voile)
	voile.pressed.connect(refermer)
	calque.add_child(voile)
	D.place(voile, Rect2(0, 0, 2248, 1230))
	var fond := D.panel(calque, Rect2((2248 - largeur) / 2.0, maxf(40.0, (1230 - hauteur) / 2.0 - 40.0), largeur, hauteur), "", "", "", nom + "Panneau")
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	if not icone.is_empty():
		var image := C.icon(icone, 30, Charte.DORE)
		fond.add_child(image)
		D.place(image, Rect2(28, 26, 30, 30))
	var intitule := D.text(fond, 70 if not icone.is_empty() else 28, 52, titre, 30, Charte.IVOIRE, 800, largeur - 140)
	intitule.name = nom + "Titre"
	intitule.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var croix := Button.new()
	croix.name = nom + "Fermer"
	croix.text = "✕"
	croix.flat = true
	croix.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	croix.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
	croix.add_theme_color_override("font_color", Charte.IVOIRE_2)
	croix.accessibility_name = "Fermer"
	croix.pressed.connect(refermer)
	fond.add_child(croix)
	D.place(croix, Rect2(largeur - 62, 18, 44, 44))
	croix.grab_focus.call_deferred()
	return fond

## Referme la fenêtre `nom` si elle est ouverte (action choisie dans la fenêtre).
static func fermer(page: Node, nom: String) -> void:
	var calque := page.find_child(nom, true, false)
	if calque == null: return
	if calque.is_in_group(PetiteFenetre.GROUPE): PetiteFenetre.fermer_derniere(page.get_tree())
	else: calque.queue_free()
