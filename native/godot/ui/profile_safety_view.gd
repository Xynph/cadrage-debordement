extends AcceptDialog
## Only a matching engine receipt confirms a restoration or deletion.
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const DIALOG_SIZE := Vector2i(1460, 1080)
const CONFIRM_SIZE := Vector2i(1080, 480)
const REASONS := {"import":"Avant un import", "nouvelle-carriere":"Avant une nouvelle carrière", "restauration":"Avant une restauration", "adaptation-reprise":"Avant adaptation à la reprise"}
var _app: Control
var _body: VBoxContainer
var _surface: ScrollContainer
var _status: Label
var _pending: Dictionary = {}
var _buttons: Array[Button] = []

func _reading_label(text: Variant, size: int, color: Color = G.INK, heading: bool = false) -> Label:
	var label := G.label(text, size, color, heading)
	# These 1440p reading surfaces use real pixel sizes, not the legacy dense scale.
	label.add_theme_font_size_override("font_size", size)
	return label

func _reading_wrap(text: Variant, size: int, color: Color = G.MUTED) -> Label:
	var label := _reading_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func open(app: Control) -> AcceptDialog:
	var existing: Node = app.get_node_or_null("ProfileSafety")
	if existing != null and not existing.is_queued_for_deletion():
		Dialogs.show_centered(existing, DIALOG_SIZE)
		existing._readable_footer()
		return existing
	app._clear_dialogs()
	var popup: AcceptDialog = load("res://ui/profile_safety_view.gd").new()
	popup._setup(app)
	app.add_child(popup)
	Dialogs.show_centered(popup, DIALOG_SIZE)
	popup._readable_footer()
	return popup

func _readable_action(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 22)
	# AcceptDialog lays out internal actions from intrinsic minimum sizes.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = 80
		style.content_margin_right = 80
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		button.add_theme_stylebox_override(state, style)

func _readable_footer() -> void:
	for frame in 4: await get_tree().process_frame
	if not is_inside_tree() or not visible: return
	_readable_action(get_ok_button())

func _setup(app: Control) -> void:
	_app = app
	name = "ProfileSafety"
	title = "Copies de sécurité de vos carrières"
	app._prepare_dialog(self, DIALOG_SIZE.x)
	get_ok_button().text = "FERMER"
	get_ok_button().set_meta("immersive_style_applied", true)
	get_ok_button().add_theme_font_size_override("font_size", 22)
	get_ok_button().custom_minimum_size = Vector2(200, 58)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var surface := ScrollContainer.new()
	_surface = surface
	surface.name = "ProfileSafetyScroll"
	surface.set_meta("immersive_style_applied", true)
	surface.custom_minimum_size = Vector2(1360, 900)
	surface.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.follow_focus = true
	add_child(surface)
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", G.T.box(G.PAPER, 6, G.LINE))
	surface.add_child(paper)
	var margins := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margins.add_theme_constant_override("margin_" + edge, 28)
	paper.add_child(margins)
	_body = G.v(18)
	_body.custom_minimum_size.x = 1240
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.add_child(_body)
	_fit_reading()
	app.get_window().size_changed.connect(_fit_reading)
	_render()
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)

func _fit_reading() -> void:
	if not is_instance_valid(_surface) or not is_instance_valid(_body): return
	var available := _app.get_window().size - Vector2i(28, 68)
	var width := minf(1360, maxf(1, available.x - 60))
	_surface.custom_minimum_size = Vector2(width, minf(900, maxf(1, available.y - 140)))
	_body.custom_minimum_size.x = minf(1240, maxf(1, width - 56))

func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var data: Dictionary = _app.model.get("meta", {}).get("profileSafety", {})
	var entries: Array = data.get("entries", [])
	_body.add_child(_reading_label("Retrouver une carrière", 32, G.INK, true))
	_body.add_child(_reading_wrap("Vos copies sont conservées avant un import, une nouvelle carrière ou une adaptation à la reprise. Choisissez celle que vous souhaitez retrouver.", 22))
	_body.add_child(_reading_wrap("Le fichier d’origine est conservé à l’identique. La copie reprise est vérifiée pour cette version ; les matchs en cours repartent en pause. Gardez aussi un export sur un autre support.", 20))
	var storage: String = "%d / %d copies · %.1f / %.0f Mio" % [entries.size(), int(data.get("maxEntries", 8)), float(data.get("usedBytes", 0)) / 1048576.0, float(data.get("maxBytes", 268435456)) / 1048576.0]
	var quota := _reading_label(storage, 24, G.GOLD, true)
	quota.name = "ProfileSafetyQuota"
	_body.add_child(quota)
	_body.add_child(_reading_wrap("Aucune copie n’est effacée automatiquement. Si la limite est atteinte, supprimez une copie de votre choix avant de remplacer une carrière.", 20))
	if not str(data.get("error", "")).is_empty():
		_body.add_child(_reading_wrap(str(data.error), 22, G.ALERT))
	if entries.is_empty():
		var empty := _reading_wrap("Vous n’avez pas encore de copie de sécurité. Votre premier remplacement de carrière en conservera une avant de modifier votre profil.", 22)
		empty.name = "ProfileSafetyEmpty"
		_body.add_child(empty)
	for entry: Dictionary in entries:
		var card := G.panel(_body)
		card.add_theme_constant_override("separation", 16)
		var style := G.T.box(Color("fcfcf8"), 6, G.LINE)
		for edge in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 22)
		card.get_parent().add_theme_stylebox_override("panel", style)
		card.add_child(_reading_label(str(entry.get("club", "Copie indisponible")), 28, G.INK, true))
		var date := str(entry.get("createdAt", "Date inconnue")).replace("T", " · ").replace("Z", " UTC")
		if date.contains("."): date = date.get_slice(".", 0) + " UTC"
		card.add_child(_reading_wrap("%s · Saison %s · Journée %s" % [date, G.season_label(entry.get("season", "?")), str(int(entry.get("round", 0)) + 1)], 20))
		card.add_child(_reading_wrap("%s · %.1f Mio" % [str(REASONS.get(str(entry.get("reason", "")), "Origine non vérifiable")), float(entry.get("bytes", 0)) / 1048576.0], 20))
		if not bool(entry.get("available", false)):
			card.add_child(_reading_wrap(str(entry.get("error", "Cette copie ne peut pas être reprise.")), 22, G.ALERT))
		var actions := G.h(20)
		card.add_child(actions)
		var id := str(entry.id)
		var restore := G.button("Reprendre cette copie", func(): _confirm_restore(entry), true)
		restore.name = "ProfileSafetyRestore_" + id
		restore.add_theme_font_size_override("font_size", 22)
		restore.custom_minimum_size = Vector2(340, 60)
		restore.disabled = not bool(entry.get("available", false)) or _app.waiting or bool(_app.model.get("meta", {}).get("recoveryRequired", false)) or not _pending.is_empty()
		actions.add_child(restore)
		_buttons.append(restore)
		var remove := G.button("Supprimer cette copie", func(): _confirm_remove(entry))
		remove.name = "ProfileSafetyRemove_" + id
		remove.add_theme_font_size_override("font_size", 22)
		remove.custom_minimum_size = Vector2(300, 60)
		remove.disabled = _app.waiting or not _pending.is_empty()
		actions.add_child(remove)
		_buttons.append(remove)
	_status = _reading_wrap("L’intégrité de la copie et la carrière sont contrôlées avant toute reprise. Rien n’est chargé sans votre confirmation.", 20)
	_status.name = "ProfileSafetyStatus"
	_body.add_child(_status)

func _confirm_restore(entry: Dictionary) -> void:
	_confirm("Reprendre cette copie ?", "La carrière actuelle sera conservée dans une nouvelle copie avant remplacement.\n\nVous reprendrez %s, saison %s. Les matchs en cours seront remis en pause. Si les vérifications ou l'écriture échouent, votre carrière actuelle restera intacte." % [str(entry.get("club", "cette carrière")), G.season_label(entry.get("season", 0))], "REPRENDRE", "restore_checkpoint", str(entry.id))

func _confirm_remove(entry: Dictionary) -> void:
	_confirm("Supprimer cette copie ?", "Seule la copie sélectionnée sera supprimée : %s.\n\nLa carrière actuelle et les autres copies seront conservées. Cette suppression est définitive." % str(entry.get("club", "copie indisponible")), "SUPPRIMER", "remove_checkpoint", str(entry.id))

func _confirm(caption: String, text: String, action: String, command: String, id: String) -> void:
	if _app.waiting or not _pending.is_empty(): return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ProfileSafetyConfirm"
	_app._prepare_dialog(dialog, CONFIRM_SIZE.x)
	dialog.title = caption
	dialog.dialog_text = text
	dialog.get_ok_button().text = action
	dialog.get_cancel_button().text = "ANNULER"
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		button.set_meta("immersive_style_applied", true)
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(220, 60)
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_pending = {"command":command, "id":id}
		for button in _buttons: button.disabled = true
		_status.text = "Vérification et reprise en cours…" if command == "restore_checkpoint" else "Suppression de la copie sélectionnée…"
		if not _app._command(command, {"id":id,"confirmed":true}, "Réception" if command == "restore_checkpoint" else ""):
			_on_failure("Commande non transmise ; aucune action confirmée."))
	Dialogs.show_centered(dialog, CONFIRM_SIZE)
	dialog.get_label().add_theme_font_size_override("font_size", 24)
	dialog.get_cancel_button().grab_focus()
	_align_confirmation(dialog)

func _align_confirmation(dialog: ConfirmationDialog) -> void:
	# Embedded child windows use root coordinates; the generic fit helper uses
	# this parent window's width. Center the confirmation in the actual 1440p app.
	for frame in 4: await get_tree().process_frame
	if not is_instance_valid(dialog) or not dialog.visible: return
	dialog.position = (Vector2i(_app.get_viewport_rect().size) - dialog.size) / 2
	dialog.get_label().add_theme_font_size_override("font_size", 24)
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]: _readable_action(button)
	dialog.get_cancel_button().grab_focus()

func _on_model(model: Dictionary) -> void:
	if _pending.is_empty(): return
	var receipt: Variant = model.get("meta", {}).get("profileSafetyReceipt")
	if not _app.bridge.last_response_ok or not receipt is Dictionary: return
	if receipt.get("command") != _pending.command or receipt.get("id") != _pending.id: return
	var restored: bool = _pending.command == "restore_checkpoint"
	_pending.clear()
	if restored:
		queue_free()
		return
	_render()
	_status.text = "Copie supprimée. Votre carrière actuelle est conservée."

func _on_failure(message: String) -> void:
	if _pending.is_empty(): return
	_pending.clear()
	_render()
	_status.text = message
	_status.add_theme_color_override("font_color", G.ALERT)
