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
