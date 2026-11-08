extends AcceptDialog
## Plain personal text; only a matching worker receipt means it was saved.
const G = preload("res://ui/carnet_skin.gd")
var _app: Control
var _data: Dictionary = {}
var _target := "career"
var _source := ""
var _pending: Dictionary = {}
var _picker: OptionButton
var _editor: TextEdit
var _counter: Label
var _status: Label
var _save_button: Button
var _cancel_button: Button
var _remove_button: Button

static func open(app: Control, target: String = "career") -> AcceptDialog:
	var existing: Node = app.get_node_or_null("CoachNotebook")
	if existing != null and not existing.is_queued_for_deletion():
		existing._request_target(target)
		existing.popup_centered(Vector2i(820, 500))
		return existing
	app._clear_dialogs()
	var popup: AcceptDialog = load("res://ui/coach_notes_view.gd").new()
	popup._setup(app, target)
	app.add_child(popup)
	popup.popup_centered(Vector2i(820, 500))
	return popup

func _setup(app: Control, target: String) -> void:
	_app = app
	_target = target
	_data = app.model.get("clubLife", {}).get("coachNotebook", {})
	name = "CoachNotebook"
	title = "Mon carnet personnel"
	app._prepare_dialog(self, 820)
	get_ok_button().text = "FERMER"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	# Bound the window independently of wrapped-label minimum heights during
	# the first layout pass; any overflow stays inside this scroll surface.
	var surface := ScrollContainer.new()
	surface.custom_minimum_size = Vector2(680, 390)
	surface.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.follow_focus = true
	add_child(surface)
	var body := G.v(8)
	body.custom_minimum_size.x = 680
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_child(body)
	body.add_child(G.label("Mes intentions, mes repères", 18, G.INK, true))
	body.add_child(G.wrap("Notes propres à cette carrière, conservées après mobilité. Aucune décision automatique.", 12))
	_picker = OptionButton.new()
	_picker.name = "CoachNoteTarget"
	_picker.custom_minimum_size.y = 32
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.get_popup().max_size.y = 320
	body.add_child(_picker)
	_picker.item_selected.connect(func(index: int): _request_target(str(_picker.get_item_metadata(index))))
	_editor = TextEdit.new()
	_editor.name = "CoachNoteText"
	_editor.custom_minimum_size = Vector2(0, 170)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_FILL
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.add_theme_font_size_override("font_size", 13)
	body.add_child(_editor)
	_editor.text_changed.connect(_changed)
	_counter = G.label("", 12)
	_counter.name = "CoachNoteCount"
	body.add_child(_counter)
	_status = G.wrap("", 12)
	_status.name = "CoachNoteStatus"
	body.add_child(_status)
	var actions := G.h(8)
	body.add_child(actions)
	_save_button = G.button("ENREGISTRER", _save_note, true)
	_save_button.name = "CoachNoteSave"
	actions.add_child(_save_button)
	_cancel_button = G.button("ANNULER LA SAISIE", func(): _load_target(_target))
	_cancel_button.name = "CoachNoteCancel"
	actions.add_child(_cancel_button)
	_remove_button = G.button("SUPPRIMER LA NOTE", _confirm_remove)
	_remove_button.name = "CoachNoteRemove"
	actions.add_child(_remove_button)
	_fill_targets()
	_load_target(target)
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)

func _entry(target: String) -> Dictionary:
	for entry: Dictionary in _data.get("entries", []):
		if entry.target == target: return entry
	return {}

func _fill_targets() -> void:
	_picker.clear()
	var choices: Array = _data.get("targets", []).duplicate(true)
	for entry: Dictionary in _data.get("entries", []):
		if not choices.any(func(row: Dictionary) -> bool: return row.target == entry.target): choices.append(entry)
	if not choices.any(func(row: Dictionary) -> bool: return row.target == _target): choices.append({"target":_target,"name":null,"available":false})
	for choice: Dictionary in choices:
		var caption: String = str(choice.get("name")) if choice.get("name") != null else "Dossier indisponible"
		_picker.add_item(caption)
		_picker.set_item_metadata(_picker.item_count - 1, choice.target)
		_picker.set_item_tooltip(_picker.item_count - 1, caption)
		if choice.target == _target: _picker.select(_picker.item_count - 1)

func _request_target(target: String) -> void:
	if target == _target: return
	if target != _target and (not _pending.is_empty() or _editor.text != _source):
		for index in _picker.item_count:
			if _picker.get_item_metadata(index) == _target: _picker.select(index)
		_status.text = "Enregistrez ou annulez la saisie avant de changer de dossier."
		return
	_load_target(target)

func _load_target(target: String) -> void:
	_target = target
	var entry := _entry(target)
	_source = str(entry.get("text", ""))
	_editor.text = _source
	for index in _picker.item_count:
		if _picker.get_item_metadata(index) == target: _picker.select(index)
	if not entry.is_empty() and not entry.get("available", false):
		_status.text = "Dossier indisponible dans le monde actuel. La note reste modifiable."
	elif not entry.is_empty():
		_status.text = "Note personnelle enregistrée · saison %d · semaine %d." % [entry.season, int(entry.week) + 1]
	else:
		_status.text = "Aucune note enregistrée pour ce dossier."
	_changed()

func _valid_text() -> bool:
	var text := _editor.text
	if text.length() < 1 or text.length() > 2000 or text.strip_edges().is_empty(): return false
	var visible := false
	for i in text.length():
		var n := text.unicode_at(i)
		if n != 9 and n != 10 and (n < 32 or n >= 127 and n <= 159 or n >= 0xd800 and n <= 0xdfff): return false
		if not (n in [9,10,32,0x00a0,0x1680,0x2028,0x2029,0x202f,0x205f,0x3000,0xfeff] or n >= 0x2000 and n <= 0x200a): visible = true
	return visible

func _changed() -> void:
	if _save_button == null: return
	var dirty := _editor.text != _source
	var available: bool = not _entry(_target).is_empty() or _data.get("targets", []).any(func(row: Dictionary) -> bool: return row.target == _target)
	_counter.text = "%d / 2 000 caractères · 100 notes maximum, selon la taille de carrière" % _editor.text.length()
	_counter.add_theme_color_override("font_color", G.ALERT if _editor.text.length() > 2000 else G.MUTED)
	_save_button.disabled = not _pending.is_empty() or not dirty or not _valid_text() or not available
	_cancel_button.disabled = not _pending.is_empty() or not dirty
	_remove_button.disabled = not _pending.is_empty() or _entry(_target).is_empty()
	_editor.editable = _pending.is_empty()
	_picker.disabled = not _pending.is_empty()

func _save_note() -> void:
	if _save_button.disabled: return
	_send("coach_note_save", {"context":_data.context.duplicate(true),"target":_target,"text":_editor.text})

func _send(command: String, payload: Dictionary) -> void:
	if _app.waiting or _app.closing:
		_status.text = "Une décision est en cours. Votre brouillon est conservé ; réessayez après sa réponse."
		return
	_pending = {"command":command,"target":payload.target,"context":payload.context.duplicate(true),"text":payload.get("text", "")}
	_status.text = "Enregistrement en cours…" if command == "coach_note_save" else "Suppression en cours…"
	_changed()
	if not _app._command(command, payload) and not _pending.is_empty(): _on_failure("Commande non transmise. Votre saisie est conservée.")

func _confirm_remove() -> void:
	if _remove_button.disabled: return
	var confirmation := ConfirmationDialog.new()
	confirmation.name = "CoachNoteDeleteConfirm"
	confirmation.title = "Supprimer cette note ?"
	confirmation.dialog_text = "La note de ce dossier sera supprimée de cette carrière. Confirmer ?"
	confirmation.get_ok_button().text = "SUPPRIMER"
	add_child(confirmation)
	confirmation.canceled.connect(confirmation.queue_free)
	confirmation.confirmed.connect(func():
		confirmation.queue_free()
		_send("coach_note_remove", {"context":_data.context.duplicate(true),"target":_target,"confirmed":true}))
	confirmation.popup_centered(Vector2i(520, 160))

func _on_model(model: Dictionary) -> void:
	if _app.bridge.last_response_ok and _app.last_command in ["new_career", "import", "recover_profile"]:
		queue_free()
		return
	_data = model.get("clubLife", {}).get("coachNotebook", {})
	var receipt: Variant = model.get("meta", {}).get("coachNote")
	if not _pending.is_empty() and _app.bridge.last_response_ok and receipt is Dictionary:
		var matches: bool = receipt.get("command") == _pending.command and receipt.get("target") == _pending.target and receipt.get("context") == _pending.context
		if matches:
			var removed: bool = _pending.command == "coach_note_remove"
			if removed and not _entry(_target).is_empty() or not removed and _entry(_target).get("text") != _pending.text:
				# A stale model or another response must not settle this command.
				return
			_pending.clear()
			_fill_targets()
			_load_target(_target)
			_status.text = "Note supprimée." if removed else "Enregistré dans cette carrière."
			return
	_changed()

func _on_failure(message: String) -> void:
	if _pending.is_empty(): return
	_pending.clear()
	_status.text = "Non enregistré · " + message + " · Brouillon conservé."
	_changed()

func _exit_tree() -> void:
	if not is_instance_valid(_app) or not is_instance_valid(_app.bridge): return
	if _app.bridge.model_changed.is_connected(_on_model): _app.bridge.model_changed.disconnect(_on_model)
	if _app.bridge.command_failed.is_connected(_on_failure): _app.bridge.command_failed.disconnect(_on_failure)
