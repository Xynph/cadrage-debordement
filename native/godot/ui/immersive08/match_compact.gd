extends "res://ui/match_screen.gd"

const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")

var location: HBoxContainer
var position_label: Label
var venue_label: Label

func _ready() -> void:
	super._ready()
	location = C.h(16)
	location.hide()
	var scoreboard := _score_sheet.get_child(0) as VBoxContainer
	scoreboard.add_child(location)
	position_label = C.label("",26,C.GOLD,true,700)
	position_label.name = "MatchFixturePosition"
	location.add_child(position_label)
	venue_label = C.wrap("",26,C.IVORY,true,600)
	venue_label.name = "MatchFixtureVenue"
	C.fill(venue_label)
	location.add_child(venue_label)

func update_frame(value: Dictionary) -> void:
	super.update_frame(value)
	if not is_instance_valid(location): return
	var fixture: Variant = value.get("next")
	var live: Dictionary = value.live if value.get("live") is Dictionary else {}
	location.visible = fixture is Dictionary and not fixture.is_empty() and live.is_empty()
	if not location.visible: return
	position_label.text = P.fixture_position(fixture,value.get("club",{}).get("id"))
	venue_label.text = P.fixture_venue(fixture,false)
	venue_label.visible = not venue_label.text.is_empty()
