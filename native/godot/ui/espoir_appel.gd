extends RefCounted
## « Appeler un espoir » : feuille de match incomplète (l'effectif pro ne suffit pas à compléter les 23).
## Le moteur propose, pour chaque place vide, le meilleur jeune du centre apte au poste (selection.espoirs :
## 18 ans au moins, non blessé, JIFF préféré quand la feuille est sous l'exigence). Les deux choix, comme en vrai :
##  - « Appeler un espoir : nom, âge, poste, note » (choix par défaut quand il existe), prêté pour ce match seulement ;
##  - « Jouer à 22 » quand la règle le permet (selection.reducedBench, Nationale).
## Commandes : begin_match { espoirs: [{slot, playerId}] } ou { reducedBench: true } ; espoir_appeler { assignments }.
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const P = preload("res://ui/immersive08/projection.gd")

## Offre du moteur pour la feuille actuelle, ou {} (feuille valide, match en cours, aucun jeune apte).
static func offer(model: Dictionary) -> Dictionary:
	var selection: Variant = model.get("selection")
	if not selection is Dictionary or selection.get("valid", false): return {}
	if model.get("live") is Dictionary and not model.live.is_empty(): return {}
	var value: Variant = selection.get("espoirs")
	if not value is Dictionary or not value.get("available", false): return {}
	var slots: Variant = value.get("slots")
	return value if slots is Array and not slots.is_empty() else {}

static func describe(candidate: Dictionary) -> String:
	return "%s, %d ans, %s, note %d" % [candidate.get("name", "Jeune"), int(candidate.get("age", 0)), str(candidate.get("pos", "")).to_lower(), int(candidate.get("note", 0))]

static func _by_id(slot_offer: Dictionary, id: Variant) -> Dictionary:
	for candidate: Dictionary in slot_offer.get("candidates", []):
		if candidate.get("id") == id: return candidate
	return {}

## Choix proposés, le premier est celui par défaut. Chaque entrée : { id, label, payload } (payload fusionné dans
## begin_match). « Jouer à 22 » n'y figure que si `with_22` et que le moteur l'offre.
static func choices(model: Dictionary, with_22: bool = true) -> Array:
	var result: Array = []
	var value := offer(model)
	if not value.is_empty():
		var slots: Array = value.slots
		if slots.size() == 1:
			var candidates: Array = slots[0].get("candidates", [])
			for index in candidates.size():
				var c: Dictionary = candidates[index]
				var label := "Appeler un espoir : %s" % describe(c)
				if index > 0: label = "Ou plutôt : %s" % describe(c)
				if c.get("jiff", false): label += " · JIFF"
				result.append({"id": "espoir%d" % index, "label": label, "payload": {"espoirs": [{"slot": int(slots[0].slot), "playerId": c.id}]}})
		else:
			var parts: PackedStringArray = []
			var assignments: Array = []
			for slot_offer: Dictionary in slots:
				var c := _by_id(slot_offer, slot_offer.get("proposedId"))
				if c.is_empty(): continue
				parts.append("n° %d %s" % [int(slot_offer.number), describe(c)])
				assignments.append({"slot": int(slot_offer.slot), "playerId": c.id})
			if not assignments.is_empty():
				result.append({"id": "espoir0", "label": "Appeler %d espoirs : %s" % [assignments.size(), " · ".join(parts)], "payload": {"espoirs": assignments}})
	if with_22 and P.reduced_bench_number(model) != 0:
		result.append({"id": "a22", "label": "Jouer à 22", "payload": {"reducedBench": true}})
	return result

static func vacancy_text(model: Dictionary) -> String:
	var value := offer(model)
	var vacant := P.reduced_bench_number(model)
	if not value.is_empty():
		var parts: PackedStringArray = []
		for slot_offer: Dictionary in value.slots: parts.append("n° %d (%s)" % [int(slot_offer.number), str(slot_offer.label).to_lower()])
		return "Feuille incomplète : place%s %s sans joueur disponible." % ["s" if parts.size() > 1 else "", " et ".join(parts)]
	if vacant != 0: return P.reduced_bench_vacancy(vacant)
	return ""

## Ajoute au parent le bloc de choix (boutons radio, défaut sur le premier) et renvoie un Callable qui rend le choix
## sélectionné ({id, label, payload}). Rend un Callable vide si rien n'est à choisir.
static func add_choices(parent: Control, model: Dictionary, with_22: bool = true, on_change: Callable = Callable()) -> Callable:
	var list := choices(model, with_22)
	if list.is_empty(): return Callable()
	var box := C.v(6)
	box.name = "FeuilleIncompleteChoix"
	parent.add_child(box)
	var group := ButtonGroup.new()
	var buttons: Array[CheckBox] = []
	for index in list.size():
		var entry: Dictionary = list[index]
		var radio := CheckBox.new()
		radio.name = "FeuilleChoix_" + str(entry.id)
		radio.button_group = group
		radio.text = str(entry.label)
		radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		radio.custom_minimum_size = Vector2(560, 36)
		radio.add_theme_font_size_override("font_size", maxi(16, C.px(19)))
		radio.button_pressed = index == 0
		radio.set_meta("choix_id", entry.id)
		if on_change.is_valid(): radio.toggled.connect(func(_on: bool): on_change.call())
		box.add_child(radio)
		buttons.append(radio)
	return func() -> Dictionary:
		for index in buttons.size():
			if buttons[index].button_pressed: return list[index]
		return list[0]

## Fenêtre « Feuille incomplète » : au coup d'envoi (begin_match) ou depuis la composition (espoir_appeler seul).
static func ouvrir(app: Control, begin_match: bool) -> ConfirmationDialog:
	if app.waiting: return null
	var fixture: Variant = app.model.get("next")
	app._clear_dialogs()
	var dialog := ConfirmationDialog.new()
	dialog.name = "FeuilleIncompleteDialog"
	dialog.title = "Feuille incomplète"
	app._prepare_dialog(dialog, 640)
	var body := C.v(10)
	body.custom_minimum_size.x = 600
	dialog.add_child(body)
	body.add_child(C.wrap(vacancy_text(app.model), 18, C.AMBER))
	var has_22 := begin_match and P.reduced_bench_number(app.model) != 0
	var pick := add_choices(body, app.model, begin_match)
	var note := "Comme en vrai, le jeune est prêté à l'équipe première pour ce match seulement : pas de contrat professionnel, il retourne au centre ensuite et gagne de l'expérience."
	if has_22: note += "\nÀ 22, vous commencez avec 15 titulaires et 7 remplaçants ; si la première ligne ne peut plus être complétée, les mêlées deviennent non disputées."
	body.add_child(C.wrap(note, 15, C.MUTED))
	dialog.get_ok_button().text = "COUP D'ENVOI" if begin_match else "APPELER LE JEUNE"
	dialog.get_cancel_button().text = "ANNULER"
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	dialog.confirmed.connect(func():
		if app.waiting or not pick.is_valid(): return
		var choice: Dictionary = pick.call()
		var payload: Dictionary = choice.payload
		if begin_match:
			if app.route == "Match" and app.model.get("next") == fixture: app._command("begin_match", payload)
		elif payload.has("espoirs"):
			app._command("espoir_appeler", {"assignments": payload.espoirs}))
	Dialogs.show_centered(dialog, Vector2i(640, 290 if not has_22 else 340))
	dialog.get_ok_button().call_deferred("grab_focus")
	return dialog
