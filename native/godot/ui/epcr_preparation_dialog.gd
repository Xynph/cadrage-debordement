extends AcceptDialog
## Brouillon consultatif : aucune inscription ni modification de carrière.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
var app: Control
var preview: Dictionary
var selected: Dictionary = {}
var choices: Array[CheckButton] = []
var count: Label
var result: Label
var verify: Button
var pending := false
var requested_ids: Array = []

static func open(owner_app: Control) -> AcceptDialog:
	var data: Variant = owner_app.model.get("epcrPreparation")
	if not data is Dictionary: return null
	for child in owner_app.get_children():
		if child is ConfirmationDialog and child.visible: return null
	owner_app._clear_dialogs()
	var dialog: AcceptDialog = load("res://ui/epcr_preparation_dialog.gd").new()
	dialog.app = owner_app
	dialog.preview = data.duplicate(true)
	dialog._build()
	return dialog

func _build() -> void:
	name = "EpcrPreparationDialog"
	title = "Préparer l’Europe"
	get_ok_button().text = "FERMER LE BROUILLON"
	var width := mini(1000,app.get_window().size.x-64)
	var height := mini(820,app.get_window().size.y-100)
	app._prepare_dialog(self,width)
	var scroll := ScrollContainer.new()
	scroll.name = "EpcrPreparationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(width-32,mini(440,height-64))
	add_child(scroll)
	var body := C.v(12)
	body.custom_minimum_size.x = width-54
	C.fill(body,true)
	scroll.add_child(body)
	body.add_child(C.label(app.pack_manager.competition(str(preview.get("competitionId", "")), "career").get("name", "Coupe d’Europe") + " · " + str(preview.get("season","")),26,C.GOLD))
	var notice := C.wrap("Préparez une liste pour vérifier ses limites et la présence de votre feuille actuelle. Ce brouillon ne vaut pas inscription officielle et sera effacé à la fermeture.",18,C.IVORY)
	notice.name = "EpcrPreparationNotice"
	body.add_child(notice)
	var detail := C.wrap(str(preview.get("notice","Les qualifications de première ligne, contrats et inscriptions restent à confirmer.")),17,C.MUTED)
	body.add_child(detail)
	count = C.label("",20,C.GOLD)
	count.name = "EpcrPreparationCount"
	body.add_child(count)
	var tools := C.h(10)
	body.add_child(tools)
	var all := G.button("Tout sélectionner",func():_select_all(true))
	all.name = "EpcrSelectAll"
	tools.add_child(all)
	var none := G.button("Vider la liste",func():_select_all(false))
	none.name = "EpcrSelectNone"
	tools.add_child(none)
	var roster := ScrollContainer.new()
	roster.name = "EpcrCandidateScroll"
	roster.custom_minimum_size.y = 210
	roster.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster.follow_focus = true
	body.add_child(roster)
	var rows := C.v(4)
	C.fill(rows)
	roster.add_child(rows)
	for candidate: Dictionary in preview.get("candidates",[]):
		var id := str(candidate.id)
		selected[id] = true
		var box := CheckButton.new()
		box.name = "EpcrCandidate" + str(choices.size())
		box.text = str(candidate.get("name",id)) + " · " + str(candidate.get("pos","Poste à confirmer"))
		box.tooltip_text = "Qualification de première ligne à confirmer" if not candidate.get("qualificationKnown",false) else "Qualification de première ligne renseignée"
		box.set_meta("player_id",id)
		box.custom_minimum_size.y = 32
		box.button_pressed = selected.has(id)
		box.toggled.connect(func(value: bool):
			if value: selected[id] = true
			else: selected.erase(id)
			_changed())
		rows.add_child(box)
		choices.append(box)
	verify = G.button("Vérifier ce brouillon",_verify)
	verify.name = "EpcrVerify"
	body.add_child(verify)
	result = C.wrap("",18,C.IVORY)
	result.name = "EpcrPreparationResult"
	body.add_child(result)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	app.add_child(self)
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)
	_changed()
	verify.disabled = not preview.get("supported",false)
	if verify.disabled: result.text = "La référence 2026/27 ne permet pas de vérifier cette saison."
	Dialogs.show_centered(self,Vector2i(width,height))
	verify.call_deferred("grab_focus")

func _ids() -> Array:
	var ids: Array = []
	for box in choices:
		var id := str(box.get_meta("player_id"))
		if selected.has(id): ids.append(id)
	return ids

func _changed() -> void:
	count.text = "%d joueurs dans le brouillon · plafond initial : 42" % selected.size()
	result.text = "Brouillon modifié : relancez la vérification."

func _select_all(value: bool) -> void:
	if pending: return
	selected.clear()
	for box in choices:
		box.set_pressed_no_signal(value)
		if value: selected[str(box.get_meta("player_id"))] = true
	_changed()

func _verify() -> void:
	if pending: return
	if app.waiting:
		result.text = "Une action est en cours. Réessayez après sa réponse."
		return
	requested_ids = _ids()
	pending = true
	verify.disabled = true
	for box in choices: box.disabled = true
	result.text = "Vérification du brouillon…"
	if not app._command("epcr_preview",{"registeredIds":requested_ids,"competitionId":preview.get("competitionId","")}):
		_on_failure("La vérification n’a pas pu démarrer. Réessayez.")

func _on_model(value: Dictionary) -> void:
	if not pending or not app.bridge.last_response_ok or app.last_command != "epcr_preview": return
	var data: Variant = value.get("epcrPreparation")
	if not data is Dictionary: return
	# Une réponse d'une autre action ne doit jamais valider ce brouillon.
	if data.get("registeredIds",[]) != requested_ids: return
	preview = data.duplicate(true)
	_finish_request()
	_show_report()
	verify.call_deferred("grab_focus")

func _on_failure(message: String) -> void:
	if not pending: return
	_finish_request()
	result.text = message

func _finish_request() -> void:
	pending = false
	verify.disabled = false
	for box in choices: box.disabled = false

func _show_report() -> void:
	count.text = "%d joueurs dans le brouillon · plafond initial : 42" % selected.size()
	verify.disabled = not preview.get("supported",false)
	var lines: Array[String] = []
	for key in ["registration","teamSheet"]:
		var report: Dictionary = preview.get(key,{})
		var caption := "Liste" if key == "registration" else "Feuille actuelle"
		var state := str(report.get("status","unknown"))
		lines.append(caption + " : " + {"valid":"critères contrôlés respectés", "invalid":"points à corriger", "unknown":"informations à confirmer"}.get(state,"non vérifiée"))
		for message in report.get("messages",[]): lines.append("• " + str(message))
		for message in report.get("pendingMessages",[]): lines.append("• À confirmer : " + str(message))
	if not preview.get("supported",false): lines.append("La référence 2026/27 ne permet pas de vérifier cette saison.")
	lines.append("Les qualifications et l’inscription officielle ne sont pas certifiées par ce contrôle.")
	result.text = "\n".join(lines)
