extends RefCounted
## Read-only planning: confirmed call-ups and announced windows remain distinct.
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")

static func data(model: Dictionary) -> Dictionary:
	return model.get("international", {}).get("availability", {})

static func _date(value: Variant) -> String:
	return P.fixture_date({"date":value}) if value is String and not value.is_empty() else "—"

static func open(app: Control) -> void:
	app.management_ui.international_section = "availability"
	app._navigate("Sélections")

static func _player(app: Control, id: String) -> void:
	app.selected_player = id
	app._navigate("Effectif")

static func calendar_summary(app: Control) -> Control:
	var state := data(app.model)
	var card := C.card()
	card.name = "InternationalAvailabilitySummary"
	var content := C.content(card)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", C.px(18))
	flow.add_theme_constant_override("v_separation", C.px(8))
	content.add_child(flow)
	var count := int(state.get("absentCount", 0))
	var title := "%d joueur%s en sélection" % [count, "s" if count != 1 else ""]
	if count == 0: title = "Anticiper les fenêtres internationales"
	flow.add_child(C.label(title, 25, C.GOLD, true, 700))
	var detail := "Convocations confirmées · retour prévu à partir du " + _date(state.get("nextReturn")) if count > 0 else "Aucun absent confirmé aujourd’hui. Les prochaines fenêtres sont consultables."
	# Un texte à retour automatique dans un HFlowContainer reçoit une largeur nulle (une lettre par ligne) : largeur minimale explicite.
	var explanation := C.wrap(detail, 18, C.MUTED)
	explanation.name = "InternationalAvailabilityDetail"
	explanation.custom_minimum_size.x = C.px(420)
	flow.add_child(explanation)
	var action := C.button("Préparer les absences →", open.bind(app))
	action.name = "InternationalAvailabilityOpen"
	flow.add_child(action)
	return card
