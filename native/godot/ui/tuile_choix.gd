extends PanelContainer
## Tuile de choix : carte de la charte (rayon 12, sans bordure, ombre des jetons) avec une icône et un titre, puis un
## contenu libre (`contenu`) et un pied (`pied`) aligné en bas, où se posent pastille et pilule d'action. Les tuiles
## d'une même rangée prennent la même hauteur. Composant partagé (Travail du club, Entraînement › Groupes, Observer la
## préparation). Exemple :
##   var t := TuileChoix.new("Cohésion de groupe", "people")
##   rangee.add_child(t); t.contenu.add_child(...); t.pied.add_child(...)
## `proteger(racine)` soustrait un bloc déjà habillé à la charte aux habillages des vues anciennes (Legacy, liens).
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

var contenu: VBoxContainer
var pied: HBoxContainer
var titre: Label

## `teinte` : couleur de l'effet principal (icône teintée ; avec `fond_teinte`, léger voile de 12 % sur la carte).
## `detail` : texte d'explication, derrière un repère « i » à droite du titre (jamais en phrase dans la tuile).
func _init(p_titre: String = "", icone: String = "", choisie: bool = false, teinte: Color = Color.TRANSPARENT, fond_teinte: bool = false, detail: String = "") -> void:
	set_meta("semantic_role", "tuile_choix")
	set_meta("style_charte", true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fond := Charte.PANNEAU_2.lerp(teinte, .12) if fond_teinte and teinte.a > 0 else Charte.PANNEAU_2
	fond.a = 1.0
	var style := C.box(fond, Charte.IVOIRE if choisie else Color.TRANSPARENT, Charte.RAYON_CARTE, 20)
	if choisie: style.set_border_width_all(2)
	add_theme_stylebox_override("panel", Charte.ombrer(style, Charte.RAYON_CARTE))
	var colonne := C.v(14)
	add_child(colonne)
	if not p_titre.is_empty():
		var tete := C.h(12)
		colonne.add_child(tete)
		if not icone.is_empty():
			var image := C.icon(icone, 30, teinte if teinte.a > 0 else Charte.IVOIRE)
			image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tete.add_child(image)
		titre = C.label(p_titre.to_upper(), 27, Charte.IVOIRE, true, 700)
		titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		C.fill(titre)
		tete.add_child(titre)
		if not detail.is_empty(): tete.add_child(info(detail))
	contenu = C.v(12)
	C.fill(contenu, true)
	colonne.add_child(contenu)
	C.fill(colonne, true)
	pied = C.h(12)
	pied.alignment = BoxContainer.ALIGNMENT_END
	colonne.add_child(pied)

## Pilule d'action secondaire de la charte (contour, texte crème) : Continuer garde l'unique aplat doré de l'écran.
## Désactivée, elle reste grisée et sa raison est écrite à côté par l'appelant (et en info-bulle ici).
static func pilule(texte: String, nom: String, active: bool, raison: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.name = nom.replace(":", "_")
	b.disabled = not active
	b.tooltip_text = "" if active else raison
	C.style_bouton_contour(b, 20)
	b.custom_minimum_size.y = maxf(28.0, float(C.px(44)))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	b.set_meta("style_charte", true)
	b.set_meta("immersive_style_applied", true)
	return b

## Pastille d'état (rayon 6, voile de la couleur, texte de la couleur) : une icône et un mot ou un chiffre, jamais une
## phrase ; le détail éventuel passe en info-bulle.
static func pastille(texte: String, couleur: Color = Charte.GRIS_VERT, icone: String = "", detail: String = "") -> Control:
	var p := C.chip(texte, couleur)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not icone.is_empty():
		var legende := p.get_child(0)
		var ligne := C.h(6)
		p.remove_child(legende)
		p.add_child(ligne)
		var image := C.icon(icone, 20, couleur)
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(image)
		ligne.add_child(legende)
	if not detail.is_empty():
		p.tooltip_text = detail
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## Repère « i » : le mode d'emploi ou la règle reste derrière, en info-bulle (jamais en phrase à l'écran).
static func info(detail: String) -> Control:
	var rond := PanelContainer.new()
	var style := C.box(Color.TRANSPARENT, Charte.IVOIRE_3, Charte.RAYON_PILULE, 0)
	style.content_margin_left = C.px(9); style.content_margin_right = C.px(9)
	style.content_margin_top = 0; style.content_margin_bottom = 0
	rond.add_theme_stylebox_override("panel", style)
	var lettre := C.label("i", 19, Charte.IVOIRE_2, true, 700)
	lettre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rond.add_child(lettre)
	rond.tooltip_text = detail
	rond.accessibility_name = detail
	rond.mouse_filter = Control.MOUSE_FILTER_STOP
	rond.mouse_default_cursor_shape = Control.CURSOR_HELP
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rond

## Titre de bloc (Barlow, capitales) suivi, s'il y a lieu, de son repère « i ».
static func titre_bloc(texte: String, detail: String = "") -> HBoxContainer:
	var ligne := C.h(10)
	ligne.add_child(C.label(texte.to_upper(), 30, Charte.IVOIRE, true, 700))
	if not detail.is_empty(): ligne.add_child(info(detail))
	return ligne

static func proteger(racine: Node) -> void:
	if racine is Control:
		racine.set_meta("style_charte", true)
		racine.set_meta("immersive_style_applied", true)
	for enfant in racine.find_children("*", "Control", true, false):
		enfant.set_meta("style_charte", true)
		enfant.set_meta("immersive_style_applied", true)
