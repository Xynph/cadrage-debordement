extends AcceptDialog
## « Mes carrières » : plusieurs carrières enregistrées (native/engine/career-slots.cjs).
## La carrière ouverte est enregistrée avant chaque changement ; la suppression demande une confirmation.
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const DIALOG_SIZE := Vector2i(1460, 1080)
const CONFIRM_SIZE := Vector2i(1080, 480)
var _app: Control
var _body: VBoxContainer
var _status: Label
var _pending := ""
var _buttons: Array[Button] = []

static func open(app: Control, start_new := false) -> AcceptDialog:
	app._clear_dialogs()
	var popup: AcceptDialog = load("res://ui/career_slots_view.gd").new()
	popup._setup(app)
	app.add_child(popup)
	Dialogs.show_centered(popup, DIALOG_SIZE)
	if start_new: popup._start_new()
	else: app._command("career_slots", {"action":"list"})
	return popup

func _label(text: Variant, size: int, color: Color = G.INK, heading := false) -> Label:
	var label := G.label(text, size, color, heading)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _setup(app: Control) -> void:
	_app = app
	name = "CareerSlots"
	title = "Mes carrières"
	app._prepare_dialog(self, DIALOG_SIZE.x)
	get_ok_button().text = "FERMER"
	get_ok_button().add_theme_font_size_override("font_size", 22)
	get_ok_button().custom_minimum_size = Vector2(200, 58)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var surface := ScrollContainer.new()
	surface.name = "CareerSlotsScroll"
	surface.custom_minimum_size = Vector2(1360, 900)
	surface.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(surface)
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", G.T.box(G.PAPER, 6, G.LINE))
	surface.add_child(paper)
	var margins := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margins.add_theme_constant_override("margin_" + edge, 28)
	paper.add_child(margins)
	_body = G.v(18)
	_body.custom_minimum_size.x = 1240
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.add_child(_body)
	_render()
	app.bridge.career_slots_changed.connect(_on_slots)
	app.bridge.command_failed.connect(_on_failure)

static func describe(entry: Dictionary) -> String:
	var parts: Array[String] = []
	if entry.get("season") != null: parts.append("Saison " + G.season_label(entry.season))
	if entry.get("round") != null: parts.append("Journée %d" % (int(entry.round) + 1))
	var date := str(entry.get("savedAt", ""))
	if date.length() >= 16: parts.append("Enregistrée le %s/%s/%s à %s" % [date.substr(8, 2), date.substr(5, 2), date.substr(0, 4), date.substr(11, 5)])
	return " · ".join(parts)

func _card(entry: Dictionary, current: bool) -> VBoxContainer:
	var card := G.panel(_body)
	card.add_theme_constant_override("separation", 14)
	var style := G.T.box(Color("fcfcf8"), 6, G.GOLD if current else G.LINE)
	for edge in ["left", "right", "top", "bottom"]: style.set("content_margin_" + edge, 22)
	card.get_parent().add_theme_stylebox_override("panel", style)
	card.add_child(_label(str(entry.get("club", "Carrière")) + ("  ·  en cours" if current else ""), 28, G.INK, true))
	card.add_child(_label(describe(entry), 20, G.MUTED))
	return card

func _action(parent: Container, text: String, callback: Callable, node_name: String, primary := false) -> void:
	var button := G.button(text, callback, primary)
	button.name = node_name
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(320, 60)
	button.disabled = _app.waiting or not _pending.is_empty()
	parent.add_child(button)
	_buttons.append(button)

func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var slots: Dictionary = _app.bridge.career_slots
	_body.add_child(_label("Tes carrières enregistrées", 32, G.INK, true))
	_body.add_child(_label("Chaque carrière garde sa progression. Ta carrière en cours est enregistrée avant d’en ouvrir une autre ou d’en commencer une nouvelle.", 22, G.MUTED))
	var current: Variant = slots.get("active")
	if current is Dictionary: _card(current, true)
	var saved: Array = slots.get("saved", [])
	for entry: Dictionary in saved:
		var card := _card(entry, false)
		var actions := G.h(20)
		card.add_child(actions)
		var id := str(entry.id)
		_action(actions, "Ouvrir cette carrière", func(): _open(id), "CareerSlotsOpen_" + id, true)
		_action(actions, "Supprimer", func(): _confirm_remove(entry), "CareerSlotsRemove_" + id)
	if not current is Dictionary and saved.is_empty() and not slots.is_empty():
		_body.add_child(_label("Aucune carrière enregistrée pour l’instant.", 22, G.MUTED))
	var actions := G.h(20)
	_body.add_child(actions)
	_action(actions, "Nouvelle carrière", _start_new, "CareerSlotsNew", true)
	_status = _label("", 20, G.MUTED)
	_status.name = "CareerSlotsStatus"
	_body.add_child(_status)

func _send(action: String, payload: Dictionary, message: String, route := "") -> void:
	if _app.waiting or not _pending.is_empty(): return
	_pending = action
	for button in _buttons: button.disabled = true
	_status.text = message
	var request := payload.duplicate()
	request["action"] = action
	if not _app._command("career_slots", request, route): _on_failure("Commande non transmise ; rien n’a changé.")

func _open(id: String) -> void:
	_send("open", {"id":id}, "Enregistrement de ta carrière en cours, puis ouverture…", "Réception")

func _start_new() -> void:
	_send("new", {}, "Enregistrement de ta carrière en cours…")

func _confirm_remove(entry: Dictionary) -> void:
	if _app.waiting or not _pending.is_empty(): return
	var dialog := ConfirmationDialog.new()
	dialog.name = "CareerSlotsConfirm"
	_app._prepare_dialog(dialog, CONFIRM_SIZE.x)
	dialog.title = "Supprimer cette carrière ?"
	dialog.dialog_text = "%s (%s) sera supprimée définitivement.\n\nTes autres carrières sont conservées." % [str(entry.get("club", "Cette carrière")), describe(entry)]
	dialog.get_ok_button().text = "SUPPRIMER"
	dialog.get_cancel_button().text = "ANNULER"
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_send("delete", {"id":str(entry.id), "confirmed":true}, "Suppression…"))
	Dialogs.show_centered(dialog, CONFIRM_SIZE)
	dialog.get_cancel_button().grab_focus()

func _on_slots(_slots: Dictionary) -> void:
	var done := _pending
	_pending = ""
	if done in ["open", "new"] and _app.bridge.last_response_ok:
		queue_free()
		if done == "new": preload("res://ui/entry_screens.gd").begin_creation(_app)
		return
	_render()
	if done == "delete": _status.text = "Carrière supprimée."

func _on_failure(message: String) -> void:
	if _pending.is_empty(): return
	_pending = ""
	_render()
	_status.text = message
	_status.add_theme_color_override("font_color", G.ALERT)
