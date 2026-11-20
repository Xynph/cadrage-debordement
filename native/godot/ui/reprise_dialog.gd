extends Control
## La reprise (reprise.cjs) : date de reprise, groupe, jeunes, conseil de Gabi. Sous-page pleine page de la Préparation (jamais une fenêtre).
## Seules les commandes reprise_* quittent cette page ; elle se redessine à chaque modèle reçu.
const Reprise = preload("res://ui/reprise_view.gd")
var app: Control
var content: VBoxContainer

## Ouvre la sous-page « La reprise » de la Préparation (écran plein, retour et historique de la coque).
static func open(application: Control) -> void:
	load("res://ui/immersive08/preparation_canvas.gd").ouvrir_sous_page(application, "reprise")

## Construit la reprise dans `parent` (un Control déjà placé).
static func embed(application: Control, parent: Control) -> Control:
	var panel = load("res://ui/reprise_dialog.gd").new()
	panel.app = application
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._build()
	return panel
func _build() -> void:
	name = "RepriseDialog"
	var scroll := ScrollContainer.new()
	scroll.name = "RepriseScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
