extends RefCounted
## Entity links share the current skins and the controller's reading-only guard.
const C = preload("res://ui/immersive08/components.gd")

static func button(app: Control, label: String, target: Dictionary, id: String = "", source_window: Window = null) -> Button:
	var link := C.button(label, func(): pass)
	if not id.is_empty(): link.name = id
	bind(link, app, target, label, source_window)
	return link

static func bind(link: BaseButton, app: Control, target: Dictionary, label: String = "", source_window: Window = null) -> void:
	var destination := target.duplicate(true)
	link.set_meta("entity_kind", str(destination.get("kind", "")))
	link.set_meta("entity_id", str(destination.get("id", "")))
	link.focus_mode = Control.FOCUS_ALL
	var caption: String = label if not label.is_empty() else (str(link.get("text")) if link is Button else "")
	if not caption.is_empty():
		link.tooltip_text = "Ouvrir · " + caption
		link.accessibility_name = "Ouvrir · " + caption
	link.pressed.connect(func():
		if is_instance_valid(app.navigation_controller):
			app.navigation_controller.open_entity(destination, source_window))

# ---- Nom cliquable générique (fiche club, 14/11/2026) ------------------------------------------
# Un seul composant pour tout nom d'entité affiché dans une page immersive : club, joueur,
# compétition, sélection nationale, entraîneur/staff, stade. La destination passe toujours par
# navigation_controller.open_entity (historique ←/→, lecture seule, contrôle de disponibilité).
# Branchements actuels :
#   club        → fiche du club (club_sheet_canvas.gd) ; le club du manager → écran « Club » ;
#   player      → fiche joueur (effectif) ou fiche du marché ; sinon `market` / dossier interclub ;
#   competition → classement de la compétition ; nation → écran Sélections ; staff → écran Staff ;
#   stadium     → aucun écran : le nom reste un texte non cliquable.
# Une future fiche (compétition, sélection, entraîneur) se branche en changeant seulement la
# destination de son type dans navigation_controller.open_entity : tous les noms déjà affichés
# avec name_link deviennent cliquables vers elle sans autre modification.
const KIND_ALIASES := {"coach":"staff", "entraineur":"staff", "selection":"nation", "team":"club"}

static func target(kind: String, id: Variant) -> Dictionary:
	var resolved := str(KIND_ALIASES.get(kind, kind))
	if resolved == "stadium" or str(id).is_empty(): return {}
	return {"kind":resolved, "id":str(id)}

static func available(app: Control, kind: String, id: Variant) -> bool:
	var destination := target(kind, id)
	return not destination.is_empty() and is_instance_valid(app.navigation_controller) and app.navigation_controller.entity_available(destination)

## Bouton plat au style d'un nom (texte aligné à gauche, soulignement doré au survol).
static func styled_button(parent: Node, rectangle: Rect2, caption: String, font_size: int = 24, color: Color = C.IVORY, control_name: String = "") -> Button:
	var button := Button.new()
	if not control_name.is_empty(): button.name = control_name
	button.text = caption
	button.flat = true
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", C.font(700))
	button.add_theme_font_size_override("font_size", maxi(12, C.px(font_size)))
	for state in ["font_color", "font_focus_color"]: button.add_theme_color_override(state, color)
	for state in ["font_hover_color", "font_pressed_color"]: button.add_theme_color_override(state, C.GOLD)
	var plain := C.box(Color.TRANSPARENT, Color.TRANSPARENT, 4, 0)
	plain.content_margin_left = C.px(4)
	plain.content_margin_right = C.px(4)
	var hover := C.box(Color(C.GOLD, .07), Color.TRANSPARENT, 4, 0)
	hover.content_margin_left = C.px(4)
	hover.content_margin_right = C.px(4)
	hover.border_color = C.GOLD
	hover.border_width_bottom = 2
	var focus := C.box(Color.TRANSPARENT, C.GOLD, 4, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	button.position = rectangle.position * C.density
	button.size = rectangle.size * C.density
	return button

## Nom cliquable placé aux coordonnées de référence : bouton-lien si une destination existe,
## sinon simple texte (jamais de lien mort).
static func name_link(app: Control, parent: Node, rectangle: Rect2, kind: String, id: Variant, caption: String, font_size: int = 24, color: Color = C.IVORY, control_name: String = "") -> Control:
	if not available(app, kind, id):
		var label := C.label(caption, font_size, color, true, 700)
		if not control_name.is_empty(): label.name = control_name
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.tooltip_text = caption
		parent.add_child(label)
		label.position = (rectangle.position + Vector2(4, 0)) * C.density
		label.size = rectangle.size * C.density
		return label
	var button := styled_button(parent, rectangle, caption, font_size, color, control_name)
	bind(button, app, target(kind, id), caption)
	return button
