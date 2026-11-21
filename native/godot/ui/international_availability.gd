extends RefCounted
## Read-only planning: confirmed call-ups and announced windows remain distinct.
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const PastillesClub = preload("res://ui/immersive08/pastilles_club.gd")
const Charte = preload("res://ui/charte.gd")

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

## Bandeau du Calendrier : tuile « N en sélection », pastille de retour (ou « 0 absent »), bouton vers les disponibilités.
## Aucune phrase : le chiffre, un mot et une date suffisent (règle « phrases à retirer » du 21/11/2026).
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
	var ouvrir := open.bind(app)
	flow.add_child(PastillesClub.tuile(str(count), "en sélection" if count > 0 else "absent", C.GOLD if count > 0 else Charte.IVOIRE, Charte.PANNEAU_2, 30, "InternationalAvailabilityTile", true, ouvrir))
	if count > 0:
		var retour := _date(state.get("nextReturn"))
		var pastille := PastillesClub.pastille("Retour " + retour, PastillesClub.TURQUOISE, "hourglass", "Convocations confirmées · retour prévu à partir du " + retour, 20, "InternationalAvailabilityDetail", ouvrir)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(pastille)
	var action := C.button("Préparer les absences →" if count > 0 else "Fenêtres internationales →", ouvrir)
	action.name = "InternationalAvailabilityOpen"
	flow.add_child(action)
	return card
