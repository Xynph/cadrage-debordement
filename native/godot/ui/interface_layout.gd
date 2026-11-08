extends Node
## Physical window reference. Presentation only: never rerender or send commands.
var app: Control
var _debounce: Timer
var _revision := 0

func setup(owner_app: Control) -> void:
	app = owner_app
	name = "InterfaceLayout"
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = .08
	add_child(_debounce)
	_debounce.timeout.connect(_settle_layout)
	app.get_window().size_changed.connect(_window_changed)
	_window_changed()

func _window_changed() -> void:
	if not is_instance_valid(app) or not app.is_inside_tree(): return
	var window := app.get_window()
	var physical := window.size
	# Headless roots start at 64x64 before their fixture configures a real window.
	if physical.x < 1280 or physical.y < 720: return
	var reference := Vector2i(mini(physical.x,1920),mini(physical.y,1080))
	if window.content_scale_size != reference: window.content_scale_size = reference
	_revision += 1
	_debounce.start()

func _settle_layout() -> void:
	if not is_instance_valid(app) or not app.is_inside_tree(): return
	var revision := _revision
	var tree := get_tree()
	# The reference change updates Control geometry before container sorting.
	await tree.process_frame
	if not is_instance_valid(app) or not app.is_inside_tree() or revision != _revision: return
	var compact := app.size.y <= 760
	var content := app.find_child("CareerContent",true,false)
	if content is BoxContainer: content.add_theme_constant_override("separation",9 if compact else 13)
	var search := app.find_child("RosterSearch",true,false)
	if search != null and search.get_parent() is BoxContainer:
		search.get_parent().add_theme_constant_override("separation",7 if compact else 14)
	var slot := app.find_child("LineupSlot01",true,false)
	if slot != null and slot.get_parent().get_parent() is BoxContainer:
		slot.get_parent().get_parent().add_theme_constant_override("separation",3 if compact else 14)
	# Keep the live nodes (including generic field names, modal contents, drafts,
	# camera and journal) instead of serializing/rebuilding their transient state.
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(app) or not app.is_inside_tree() or revision != _revision: return
	var focus := app.get_viewport().gui_get_focus_owner()
	if not is_instance_valid(focus) or not focus.is_inside_tree() or not focus.is_visible_in_tree(): return
	var parent := focus.get_parent()
	while parent != null and parent != app:
		if parent is ScrollContainer and not parent.get_global_rect().encloses(focus.get_global_rect()):
			parent.ensure_control_visible(focus)
		parent = parent.get_parent()
