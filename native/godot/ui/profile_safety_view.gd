extends AcceptDialog
## Only a matching engine receipt confirms a restoration or deletion.
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const REASONS := {"import":"Avant un import", "nouvelle-carriere":"Avant une nouvelle carrière", "restauration":"Avant une restauration", "adaptation-reprise":"Avant adaptation à la reprise"}
var _app: Control
var _body: VBoxContainer
var _status: Label
var _pending: Dictionary = {}
var _buttons: Array[Button] = []

static func open(app: Control) -> AcceptDialog:
	var existing: Node = app.get_node_or_null("ProfileSafety")
	if existing != null and not existing.is_queued_for_deletion():
		Dialogs.show_centered(existing, Vector2i(880, 560))
		return existing
	app._clear_dialogs()
	var popup: AcceptDialog = load("res://ui/profile_safety_view.gd").new()
	popup._setup(app)
	app.add_child(popup)
	Dialogs.show_centered(popup, Vector2i(880, 560))
	return popup

func _setup(app: Control) -> void:
	_app = app
	name = "ProfileSafety"
	title = "Copies de sécurité de vos carrières"
	app._prepare_dialog(self, 880)
	get_ok_button().text = "FERMER"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var surface := ScrollContainer.new()
	surface.custom_minimum_size = Vector2(720, 430)
	surface.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.follow_focus = true
	add_child(surface)
	_body = G.v(12)
	_body.custom_minimum_size.x = 720
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_child(_body)
	_render()
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)

func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var data: Dictionary = _app.model.get("meta", {}).get("profileSafety", {})
	var entries: Array = data.get("entries", [])
	_body.add_child(G.label("Retrouver une carrière, sans écraser à l'aveugle", 20, G.INK, true))
	_body.add_child(G.wrap("Une copie durable est conservée avant un import, une nouvelle carrière ou une adaptation de reprise. Le fichier de la journée précédente reste distinct. Gardez aussi un export sur un autre support.", 13))
	_body.add_child(G.wrap("Le profil brut d'origine est archivé à l'identique. La reprise utilise une carrière vérifiée et adaptée à cette version : un match en cours repart en pause.", 12))
	var storage: String = "%d / %d copies · %.1f / %.0f Mio" % [entries.size(), int(data.get("maxEntries", 8)), float(data.get("usedBytes", 0)) / 1048576.0, float(data.get("maxBytes", 268435456)) / 1048576.0]
	var quota := G.label(storage, 15, G.GOLD, true)
	quota.name = "ProfileSafetyQuota"
	_body.add_child(quota)
	_body.add_child(G.wrap("Aucune copie n'est effacée automatiquement. À la limite, le remplacement est refusé jusqu'à la suppression explicite d'une copie.", 12))
	if not str(data.get("error", "")).is_empty():
		_body.add_child(G.wrap(str(data.error), 13, G.ALERT))
	if entries.is_empty():
		var empty := G.wrap("Aucune copie durable pour le moment. Votre premier remplacement de carrière en créera une automatiquement, avant publication.", 14)
		empty.name = "ProfileSafetyEmpty"
		_body.add_child(empty)
	for entry: Dictionary in entries:
		var card := G.panel(_body)
		card.add_child(G.label(str(entry.get("club", "Copie indisponible")), 17, G.INK, true))
		var date := str(entry.get("createdAt", "Date inconnue")).replace("T", " · ").replace("Z", " UTC")
		if date.contains("."): date = date.get_slice(".", 0) + " UTC"
		card.add_child(G.wrap("%s · Saison %s · Journée %s" % [date, G.n(entry.get("season", "?")), str(int(entry.get("round", 0)) + 1)], 12))
		card.add_child(G.wrap("%s · %.1f Mio" % [str(REASONS.get(str(entry.get("reason", "")), "Origine non vérifiable")), float(entry.get("bytes", 0)) / 1048576.0], 12))
		if not bool(entry.get("available", false)):
			card.add_child(G.wrap(str(entry.get("error", "Cette copie ne peut pas être reprise.")), 12, G.ALERT))
		var actions := G.h(8)
		card.add_child(actions)
		var id := str(entry.id)
		var restore := G.button("REPRENDRE CETTE COPIE", func(): _confirm_restore(entry), true)
		restore.name = "ProfileSafetyRestore_" + id
		restore.disabled = not bool(entry.get("available", false)) or _app.waiting or bool(_app.model.get("meta", {}).get("recoveryRequired", false)) or not _pending.is_empty()
		actions.add_child(restore)
		_buttons.append(restore)
		var remove := G.button("SUPPRIMER", func(): _confirm_remove(entry))
		remove.name = "ProfileSafetyRemove_" + id
		remove.disabled = _app.waiting or not _pending.is_empty()
		actions.add_child(remove)
		_buttons.append(remove)
	_status = G.wrap("Les empreintes et la carrière sont contrôlées avant toute reprise. Aucun chargement n'est automatique.", 12)
	_status.name = "ProfileSafetyStatus"
	_body.add_child(_status)

func _confirm_restore(entry: Dictionary) -> void:
	_confirm("Reprendre cette copie ?", "La carrière actuelle sera conservée dans une nouvelle copie avant remplacement.\n\nVous reprendrez %s, saison %d. Les matchs en cours seront remis en pause. Si les vérifications ou l'écriture échouent, votre carrière actuelle restera intacte." % [str(entry.get("club", "cette carrière")), int(entry.get("season", 0))], "REPRENDRE", "restore_checkpoint", str(entry.id))

func _confirm_remove(entry: Dictionary) -> void:
	_confirm("Supprimer cette copie ?", "Seule la copie sélectionnée sera supprimée : %s.\n\nLa carrière actuelle et les autres copies seront conservées. Cette suppression est définitive." % str(entry.get("club", "copie indisponible")), "SUPPRIMER", "remove_checkpoint", str(entry.id))

func _confirm(caption: String, text: String, action: String, command: String, id: String) -> void:
	if _app.waiting or not _pending.is_empty(): return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ProfileSafetyConfirm"
	_app._prepare_dialog(dialog, 600)
	dialog.title = caption
	dialog.dialog_text = text
	dialog.get_ok_button().text = action
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_pending = {"command":command, "id":id}
		for button in _buttons: button.disabled = true
		_status.text = "Vérification et reprise en cours…" if command == "restore_checkpoint" else "Suppression de la copie sélectionnée…"
		if not _app._command(command, {"id":id,"confirmed":true}, "Réception" if command == "restore_checkpoint" else ""):
			_on_failure("Commande non transmise ; aucune action confirmée."))
	Dialogs.show_centered(dialog, Vector2i(600, 250))

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
