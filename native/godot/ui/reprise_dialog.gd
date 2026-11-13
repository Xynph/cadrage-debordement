extends AcceptDialog
## La reprise (reprise.cjs) depuis la Préparation : date de reprise, groupe, jeunes, conseil de Gabi.
## Seules les commandes reprise_* quittent cette fenêtre ; elle se redessine à chaque modèle reçu.
const Reprise = preload("res://ui/reprise_view.gd")
var app: Control
var content: VBoxContainer

static func open(application: Control) -> AcceptDialog:
	var panel = load("res://ui/reprise_dialog.gd").new()
	panel.app = application
	application.add_child(panel)
	panel._build()
	panel.popup_centered_clamped(Vector2i(1240, 820), 0.92)
	return panel

func _build() -> void:
	name = "RepriseDialog"
	title = "La reprise"
	min_size = Vector2i(620, 420)
	ok_button_text = "Fermer"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var scroll := ScrollContainer.new()
	scroll.name = "RepriseScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	app.bridge.model_changed.connect(_model_changed)
	tree_exiting.connect(func():
		if app.bridge.model_changed.is_connected(_model_changed): app.bridge.model_changed.disconnect(_model_changed))
	_refresh()

func _model_changed(_model: Dictionary) -> void:
	_refresh.call_deferred()

func _refresh() -> void:
	if not is_instance_valid(content): return
	for child in content.get_children(): child.queue_free()
	Reprise.build(app, content)
