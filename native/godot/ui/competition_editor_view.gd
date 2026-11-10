extends AcceptDialog
## Atelier local, distinct des packs d'identités et des carrières.
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Atomic = preload("res://atomic_file.gd")
const MAX_BYTES := 1048576
var app: Control
var title_input: LineEdit
var names_input: TextEdit
var json_input: TextEdit
var fixture_output: TextEdit
var round_choice: OptionButton
var double_round: CheckButton
var message: Label
var generate_button: Button
var validate_button: Button
var export_button: Button
var launch_button: Button
var launch_notice: Label
var play_club: OptionButton
var copy_button: Button
var preview: Dictionary = {}
var pending := false
var editing := false
var validated_text := ""

static func open(owner_app: Control) -> AcceptDialog:
	for child in owner_app.get_children():
		if child is AcceptDialog and child.visible: return null
	owner_app._clear_dialogs()
	var dialog: AcceptDialog = load("res://ui/competition_editor_view.gd").new()
	dialog.app = owner_app
	dialog._build()
	return dialog

func _build() -> void:
	name = "CompetitionEditorDialog"
	title = "Atelier de calendrier fictif"
	get_ok_button().text = "FERMER L’ATELIER"
	var width := mini(1040, app.get_window().size.x - 64)
	var height := mini(880, app.get_window().size.y - 100)
	app._prepare_dialog(self, width)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 32, height - 64)
	scroll.follow_focus = true
	add_child(scroll)
	var body := G.v(10)
	body.custom_minimum_size.x = width - 54
	scroll.add_child(body)
	body.add_child(G.wrap("Créez et échangez un calendrier. Les formats 14 clubs aller-retour permettent de lancer une carrière fictive ; les autres restent échangeables. Aucune compétition officielle n’est modifiée.", 17))
	title_input = LineEdit.new()
	title_input.name = "CompetitionEditorTitle"
	title_input.text = "Ma ligue fictive"
	title_input.max_length = 80
	body.add_child(title_input)
	body.add_child(G.label("Clubs · un nom par ligne · 2 à 32 clubs", 14))
	names_input = TextEdit.new()
	names_input.name = "CompetitionEditorClubs"
	names_input.custom_minimum_size.y = 100
	names_input.text = "Les Aigles\nLes Loups\nLes Lions\nLes Renards"
	body.add_child(names_input)
	double_round = CheckButton.new()
	double_round.text = "Matchs aller-retour"
	double_round.button_pressed = true
	body.add_child(double_round)
	generate_button = G.button("GÉNÉRER LE CALENDRIER", _generate, true)
	generate_button.name = "CompetitionEditorGenerate"
	body.add_child(generate_button)
	body.add_child(G.button("MODÈLE JOUABLE · 14 CLUBS", _playable_template))
	body.add_child(G.label("Document JSON · modifiable et échangeable", 14))
	json_input = TextEdit.new()
	json_input.name = "CompetitionEditorJson"
	json_input.custom_minimum_size.y = 150
	json_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body.add_child(json_input)
	json_input.text_changed.connect(_document_changed)
	var tools := G.h(8)
	body.add_child(tools)
	tools.add_child(G.button("IMPORTER JSON", _choose_import))
	validate_button = G.button("VÉRIFIER", _validate)
	validate_button.name = "CompetitionEditorValidate"
	tools.add_child(validate_button)
	export_button = G.button("EXPORTER JSON", _choose_export)
	export_button.disabled = true
	tools.add_child(export_button)
	copy_button = G.button("COPIER JSON", _copy)
	copy_button.disabled = true
	tools.add_child(copy_button)
	message = G.wrap("Votre brouillon reste dans cette fenêtre jusqu’à sa fermeture. Exportez-le pour le conserver.", 14)
	message.name = "CompetitionEditorMessage"
	body.add_child(message)
	launch_notice = G.wrap("Vérifiez le calendrier pour connaître son format jouable.", 14)
	launch_notice.name = "CustomCompetitionSupport"
	body.add_child(launch_notice)
	play_club = OptionButton.new()
	play_club.name = "CustomCompetitionClub"
	play_club.disabled = true
	body.add_child(play_club)
	launch_button = G.button("CRÉER UNE CARRIÈRE FICTIVE", _launch)
	launch_button.name = "CustomCompetitionLaunch"
	launch_button.disabled = true
	body.add_child(launch_button)
	round_choice = OptionButton.new()
	round_choice.item_selected.connect(func(_index: int): _show_round())
	body.add_child(round_choice)
	fixture_output = TextEdit.new()
	fixture_output.editable = false
	fixture_output.custom_minimum_size.y = 120
	body.add_child(fixture_output)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	app.add_child(self)
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)
	Dialogs.show_centered(self, Vector2i(width, height))

func _document_changed() -> void:
	if editing: return
	validated_text = ""
	launch_button.disabled = true
	play_club.disabled = true
	export_button.disabled = true
	copy_button.disabled = true
	fixture_output.text = "Document modifié : vérifiez-le pour actualiser l’aperçu."
	message.text = "Brouillon non vérifié. Les noms, journées et confrontations seront contrôlés."

func _generate() -> void:
	if names_input.text.length() > 4096:
		message.text = "Liste trop longue : 32 clubs de 80 caractères au maximum."
		return
	var clubs: Array = []
	for line: String in names_input.text.split("\n"):
		if not line.strip_edges().is_empty(): clubs.append(line.strip_edges())
	_request({"action":"generate", "name":title_input.text.strip_edges(), "clubs":clubs, "doubleRound":double_round.button_pressed})

func _validate() -> void:
	if pending: return
	_document_changed()
	if json_input.text.to_utf8_buffer().size() > MAX_BYTES:
		message.text = "Document trop volumineux : limite de 1 Mio."
		return
	var parser := JSON.new()
	if parser.parse(json_input.text) != OK or not parser.data is Dictionary:
		message.text = "JSON illisible : fournissez un objet calendrier complet."
		return
	_request({"action":"validate", "document":parser.data})

func _request(payload: Dictionary) -> void:
	if pending or app.waiting:
		message.text = "Une action est en cours. Réessayez après sa réponse."
		return
	pending = true
	generate_button.disabled = true
	validate_button.disabled = true
	export_button.disabled = true
	copy_button.disabled = true
	launch_button.disabled = true
	play_club.disabled = true
	json_input.editable = false
	message.text = "Contrôle du calendrier…"
	if not app._command("competition_editor_preview", payload):
		_on_failure("La vérification n’a pas pu démarrer.")

func _finish() -> void:
	pending = false
	generate_button.disabled = false
	validate_button.disabled = false
	json_input.editable = true
	export_button.disabled = validated_text.is_empty()
	copy_button.disabled = validated_text.is_empty()
	var has_match: bool = app.model.get("live") is Dictionary and not app.model.live.is_empty()
	var playable: bool = not has_match and not validated_text.is_empty() and bool(preview.get("launch", {}).get("playable", false))
	launch_button.disabled = not playable
	play_club.disabled = not playable

func _on_model(value: Dictionary) -> void:
	if not pending or not app.bridge.last_response_ok or app.last_command != "competition_editor_preview": return
	var data: Variant = value.get("competitionEditor")
	if not data is Dictionary: return
	preview = data.duplicate(true)
	validated_text = str(preview.get("exportText", ""))
	editing = true
	json_input.text = validated_text
	editing = false
	play_club.clear()
	for club: Dictionary in preview.get("document", {}).get("clubs", []): play_club.add_item(str(club.get("name", "Club")))
	launch_notice.text = str(preview.get("launch", {}).get("reason", "Format non jouable."))
	_finish()
	var summary: Dictionary = preview.get("summary", {})
	message.text = "%d clubs · %d journées · %d rencontres · %d repos par club. %s" % [int(summary.get("clubs", 0)), int(summary.get("rounds", 0)), int(summary.get("matches", 0)), int(summary.get("byesPerClub", 0)), str(preview.get("notice", ""))]
	round_choice.clear()
	for index in range(int(summary.get("rounds", 0))): round_choice.add_item("Journée " + str(index + 1))
	_show_round()

func _on_failure(error: String) -> void:
	if not pending: return
	_finish()
	message.text = error + " Le brouillon a été conservé."

func _show_round() -> void:
	var doc: Dictionary = preview.get("document", {})
	var clubs: Dictionary = {}
	for club: Dictionary in doc.get("clubs", []): clubs[str(club.id)] = str(club.name)
	var lines := PackedStringArray()
	var played: Dictionary = {}
	for fixture: Dictionary in doc.get("fixtures", []):
		if int(fixture.round) != round_choice.selected + 1: continue
		lines.append(str(clubs.get(str(fixture.homeId), "?")) + " — " + str(clubs.get(str(fixture.awayId), "?")))
		played[str(fixture.homeId)] = true
		played[str(fixture.awayId)] = true
	for id: String in clubs:
		if not played.has(id): lines.append("Repos : " + str(clubs[id]))
	fixture_output.text = "\n".join(lines)

func _choose_import() -> void:
	if pending: return
	var chooser := FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.filters = PackedStringArray(["*.json ; Calendrier JSON"])
	chooser.file_selected.connect(func(path: String):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			message.text = "Lecture refusée : " + error_string(FileAccess.get_open_error())
		elif file.get_length() > MAX_BYTES:
			file.close()
			message.text = "Document trop volumineux : limite de 1 Mio."
		else:
			json_input.text = file.get_as_text()
			_document_changed()
			file.close()
			_validate()
		chooser.queue_free())
	chooser.canceled.connect(chooser.queue_free)
	add_child(chooser)
	chooser.popup_centered_ratio(0.75)

func _choose_export() -> void:
	if validated_text.is_empty() or pending: return
	var chooser := FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	chooser.filters = PackedStringArray(["*.json ; Calendrier JSON"])
	chooser.current_file = "calendrier-fictif.json"
	chooser.file_selected.connect(func(path: String):
		_export_to(path)
		chooser.queue_free())
	chooser.canceled.connect(chooser.queue_free)
	add_child(chooser)
	chooser.popup_centered_ratio(0.75)

func _export_to(path: String) -> void:
	if validated_text.is_empty() or pending: return
	var destination := path if path.ends_with(".json") else path + ".json"
	var temporary := destination + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		message.text = "Écriture refusée : " + error_string(FileAccess.get_open_error())
		return
	file.store_string(validated_text)
	file.flush()
	var result := file.get_error()
	file.close()
	var failure := error_string(result) if result != OK else Atomic.replace_staged(temporary, destination)
	if not failure.is_empty():
		DirAccess.remove_absolute(temporary)
		message.text = "Export refusé : " + failure + " Le brouillon est conservé."
		return
	message.text = "Calendrier fictif exporté : " + destination

func _copy() -> void:
	if validated_text.is_empty() or pending: return
	DisplayServer.clipboard_set(validated_text)
	message.text = "Calendrier fictif copié. Il ne modifie aucune carrière."

func _playable_template() -> void:
	if pending: return
	var names := PackedStringArray()
	for i in range(14): names.append("Club des vallées " + str(i + 1))
	names_input.text = "\n".join(names)
	double_round.button_pressed = true
	_generate()

func _launch() -> void:
	if app.model.get("live") is Dictionary and not app.model.live.is_empty():
		message.text = "Terminez et validez le match avant de créer une autre carrière."
		return
	if pending or app.waiting or validated_text.is_empty() or not preview.get("launch", {}).get("playable", false): return
	if validated_text != json_input.text:
		_document_changed()
		message.text = "Vérifiez votre document modifié avant de créer une carrière."
		return
	var confirmation := ConfirmationDialog.new()
	confirmation.name = "CustomCompetitionConfirmation"
	confirmation.title = "Nouvelle carrière fictive"
	var explanation := "Prendre la direction de %s ?\nLa carrière courante sera remplacée. Exportez-la avant de poursuivre si vous souhaitez la conserver.\n14 clubs fictifs, 26 journées et phases finales historiques ; couleurs, budgets et niveaux des emplacements fictifs conservés." % play_club.get_item_text(play_club.selected)
	confirmation.get_ok_button().text = "CRÉER ET REMPLACER"
	confirmation.get_cancel_button().text = "GARDER LE BROUILLON"
	app._prepare_dialog(confirmation, mini(760, app.get_window().size.x - 96))
	var options := G.v(10)
	confirmation.add_child(options)
	options.add_child(G.wrap(explanation,17))
	var vary_current := CheckBox.new()
	vary_current.name = "CustomCreationVaryCurrent"
	vary_current.text = "Faire légèrement varier le niveau actuel"
	vary_current.button_pressed = true
	vary_current.add_theme_font_size_override("font_size",17)
	vary_current.tooltip_text = "Les qualités de départ varient légèrement, jusqu’à ±3. Le potentiel varie toujours, jusqu’à ±5."
	options.add_child(vary_current)
	options.add_child(G.wrap("Le potentiel varie à chaque nouvelle carrière (jusqu’à ±5), même lorsque cette case est décochée.",14,G.MUTED))
	var chosen := play_club.selected
	var document: Dictionary = preview.get("document", {}).duplicate(true)
	confirmation.confirmed.connect(func():
		app._command("new_career", {"mode":"custom", "club":chosen, "document":document, "confirmed":true, "varyCurrent":vary_current.button_pressed})
		confirmation.queue_free())
	confirmation.canceled.connect(confirmation.queue_free)
	add_child(confirmation)
	Dialogs.show_centered(confirmation, Vector2i(mini(760, app.get_window().size.x - 96), 420))
