extends RefCounted

const G = preload("res://ui/game_skin.gd")
const OfficeRoom = preload("res://ui/contextual/rooms/office_room.gd")
const LockerRoom = preload("res://ui/contextual/rooms/locker_room.gd")
const TrainingRoom = preload("res://ui/contextual/rooms/training_room.gd")

# Pure construction: caller owns the returned room and attaches it to its 3D viewport.
# Rooms do not own UI, career state, match simulation or navigation.
static func build(kind: String, club: Dictionary) -> Node3D:
	var room: Node3D
	match kind:
		"office", "bureau": room = OfficeRoom.new()
		"locker", "vestiaire": room = LockerRoom.new()
		"training", "terrain": room = TrainingRoom.new()
		"medical": room = load("res://ui/contextual/rooms/medical_room.gd").new()
		"board": room = load("res://ui/contextual/rooms/board_room.gd").new()
		_:
			push_warning("Unknown contextual room: " + kind)
			return null
	var identity: Dictionary = G.identity(club).duplicate(true)
	if not identity.has("color") and club.has("color"):
		identity["color"] = club["color"]
	if not identity.has("name") and club.has("name"):
		identity["name"] = club["name"]
	# Same resolver as the interface: pack crest, official badge, else the club's
	# recoloured crest with its initials (rendered from the interface control).
	var texture: Texture2D = G.crest_surface_texture(club)
	room.name = "Contextual" + kind.capitalize()
	room.configure(identity, texture)
	return room
