extends SceneTree

const MedicalView = preload("res://ui/contextual/medical_room_view.gd")
const MedicalRoom = preload("res://ui/contextual/rooms/medical_room.gd")
var failures: Array[String] = []
var checks := 0

class FakeApp extends Control:
	var model: Dictionary = {}
	var waiting := false
	var last_error := ""

class FakeDirector extends Node:
	var app: Control
	var view: Control
	var commands: Array[Dictionary] = []
	var closes := 0
	func command(command_name: String, payload: Dictionary = {}) -> void:
		if not app.waiting: commands.append({"command":command_name, "payload":payload.duplicate(true)})
	func close_room() -> void:
		if not app.waiting: closes += 1
	func _refresh_controls() -> void:
		if view == null: return
		for control in view.find_children("*", "BaseButton", true, false):
			if control.has_meta("contextual_enabled"):
				control.disabled = app.waiting or not bool(control.get_meta("contextual_enabled"))

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("MEDICAL FAIL: ", message)

func fixture() -> Dictionary:
	return {"club":{"id":7,"name":"Club actif","color":"#176ca4"}, "live":null,
		"meta":{"hasCareer":true,"trained":false,"phase":"league","week":3},
		"squad":[{"id":"injured:real","name":"Joueur suivi","pos":"Pilier gauche","condition":62,"physicalLoad":48,"injury":2,"loadPlan":"collective","portraitIndex":4},
			{"id":"return:real","name":"Joueur en reprise","pos":"Demi de mêlée","condition":71,"physicalLoad":35,"injury":0,"loadPlan":"normal","portraitIndex":7}],
		"staff":{"teams":[{"id":3,"members":[{"id":"foreign:medic","name":"Autre club","role":"medical"}]},
			{"id":7,"members":[{"id":"staff:medical:real","name":"Membre médical du club","role":"medical","roleLabel":"Médecin"}]}]},
		"clubLife":{"clubSupport":{"context":{"season":1,"week":3,"club":7},"medical":{
			"available":true,"protocols":[{"key":"prudent","label":"Rééducation prudente","description":"Récupération sans raccourci ; priorité à la condition et à la baisse de charge."},
				{"key":"standard","label":"Suivi standard","description":"Durée habituelle, remise en forme progressive."},
				{"key":"accelere","label":"Retour accéléré","description":"Possibilité de gagner une semaine, mais risque de rechute et de fatigue."}],
			"players":[{"id":"injured:real","injury":2,"condition":62,"fatigue":48,"protocol":"standard","stage":"blesse"},
				{"id":"return:real","injury":0,"condition":71,"fatigue":35,"protocol":"standard","stage":"reprise"}]}}}}

func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	var portrait_path := "/tmp/oval-medical-room-portrait.png"
	var supplied_image := Image.create(30,40,false,Image.FORMAT_RGBA8)
	supplied_image.fill(Color("c83c64"))
	check(supplied_image.save_png(portrait_path) == OK, "create supplied portrait fixture")
	var app := FakeApp.new()
	app.model = fixture()
	app.model.squad[0]["portraitPath"] = portrait_path
	app.model.staff.teams[1].members[0]["portraitPath"] = portrait_path
	root.add_child(app)
	var director := FakeDirector.new()
	director.app = app
	root.add_child(director)
	var view := MedicalView.new()
	view.director = director
	director.view = view
	app.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var original := app.model.duplicate(true)
	view.update_frame(app.model)
	await settle()
	check(view.selected_id == "injured:real", "actual followed player selected first")
	check(app.model == original and director.commands.is_empty(), "opening is pure: no injury/condition/charge/week or command change")
	view._continue()
	check(director.closes == 0 and view.find_child("MedicalClose", true, false).disabled, "mandatory exchange cannot be bypassed before server completion")
	var portrait: TextureRect = view.find_child("MedicalPlayerPortrait", true, false)
	check(portrait != null and portrait.get_meta("person_id") == "injured:real", "portrait bound to actual selected player")
	check(portrait != null and portrait.texture.get_width() == 30, "actual supplied player portrait wins over fallback")
	var staff_portrait: TextureRect = view.find_child("MedicalStaffPortrait", true, false)
	check(staff_portrait != null and staff_portrait.get_meta("person_id") == "staff:medical:real", "medical member belongs to current club")
	check(staff_portrait != null and staff_portrait.texture.get_height() == 40, "actual supplied staff portrait wins over fallback")
	var confirm: Button = view.find_child("MedicalConfirmProtocol", true, false)
	check(confirm != null and not confirm.disabled, "injured player with available source has protocol decision")
	view.selected_protocol = "prudent"
	view._confirm_protocol()
	check(director.commands.size() == 1 and director.commands[0] == {"command":"medical_protocol", "payload":{"context":{"season":1,"week":3,"club":7},"id":"injured:real","protocol":"prudent"}}, "exact existing protocol command and context/id/key")
	check(app.model == original, "command does not optimistically heal or alter source")
	director.commands.clear()
	app.waiting = true
	director._refresh_controls()
	check(confirm.disabled, "waiting disables protocol confirmation")
	view._confirm_protocol()
	check(director.commands.is_empty(), "waiting blocks direct confirm callback")
	app.waiting = false
	view.selected_protocol = "invented"
	view._confirm_protocol()
	check(director.commands.is_empty(), "unoffered protocol rejected locally")
	view.selected_protocol = "prudent"
	app.model.meta.trained = true
	view.update_frame(app.model)
	await settle()
	confirm = view.find_child("MedicalConfirmProtocol", true, false)
	check(confirm.disabled, "applied session is read only")
	view._confirm_protocol()
	check(director.commands.is_empty(), "trained state blocks protocol callbacks")
	app.model = fixture()
	view.update_frame(app.model, {"playerId":"return:real"})
	await settle()
	check(view.find_child("MedicalConfirmProtocol", true, false) == null, "injury zero has no treatment or surgery action")
	view._set_load("repos")
	check(director.commands.size() == 1 and director.commands[0] == {"command":"set_player_load", "payload":{"playerId":"return:real","mode":"repos"}}, "reprise sets only the actual player's next load")
	check(app.model.squad[1].condition == 71 and app.model.squad[1].physicalLoad == 35 and app.model.meta.week == 3, "load choice does not invent instant recovery or consume week")
	director.commands.clear()
	app.waiting = true
	view._set_load("repos")
	check(director.commands.is_empty(), "waiting blocks load decision")
	app.waiting = false
	app.model.live = {"paused":true}
	view.update_frame(app.model, {"playerId":"return:real"})
	view._set_load("repos")
	check(director.commands.is_empty(), "match state blocks load even when paused")
	app.model = fixture()
	app.model.clubLife.clubSupport.medical.available = false
	view.update_frame(app.model, {"playerId":"injured:real"})
	view._confirm_protocol()
	check(director.commands.is_empty(), "authoritative medical refusal respected")
	app.last_error = "Décision périmée : consultez la semaine actuelle."
	check(app.model.squad[0].injury == 2 and view._followup().protocol == "standard", "refused response does not fabricate successful treatment")
	view.update_frame(app.model, {"meetingId":"medical:read-only", "playerId":"injured:real", "completed":false, "ackAllowed":true})
	await settle()
	check(view.find_child("MedicalAcknowledge", true, false) != null, "server may authorize acknowledgement when medical decision unavailable")
	view._acknowledge()
	check(director.commands.size() == 1 and director.commands[0] == {"command":"club_meeting_ack", "payload":{"meetingId":"medical:read-only"}}, "factual acknowledgement uses exact authoritative meeting ID")
	check(not bool(view.meeting_data.get("completed", false)), "acknowledgement does not optimistically complete meeting")
	director.commands.clear()
	app.waiting = true
	view._acknowledge()
	check(director.commands.is_empty(), "waiting blocks acknowledgement")
	app.waiting = false
	view.update_frame(app.model, {"meetingId":"medical:decision", "playerId":"injured:real", "completed":false, "ackAllowed":false})
	view._acknowledge()
	check(director.commands.is_empty() and view.find_child("MedicalAcknowledge", true, false) == null, "required medical decision cannot be bypassed by acknowledgement")
	check(view.find_child("MedicalPlayerPicker", true, false).disabled, "mandatory meeting retains its actual assigned player")
	app.model = fixture()
	app.model.staff = {"teams":[]}
	view.update_frame(app.model, {"playerId":"gone:player"})
	await settle()
	check(view._player().is_empty() and view.find_child("MedicalPlayerPortrait", true, false) == null, "departed player is not silently replaced")
	check(view.find_child("MedicalStaffPortrait", true, false) == null, "unknown doctor has no invented portrait")
	view._confirm_protocol()
	view._set_load("repos")
	check(director.commands.is_empty(), "departed player cannot receive decisions")
	app.model = fixture()
	app.model.erase("clubLife")
	view.update_frame(app.model, {"playerId":"injured:real"})
	view._confirm_protocol()
	check(director.commands.is_empty(), "missing medical projection cannot fabricate a protocol command")
	app.model = fixture()
	app.model.squad[0].name = "Nom de joueur très long destiné à vérifier que le dossier garde une largeur bornée à toutes les résolutions"
	view.update_frame(app.model, {"playerId":"injured:real"})
	for size_ in [Vector2i(1280,720), Vector2i(1600,900)]:
		root.size = size_
		app.size = Vector2(size_)
		await settle()
		var close: Button = view.find_child("MedicalClose", true, false)
		check(Rect2(Vector2.ZERO,Vector2(size_)).encloses(close.get_global_rect()), "close visible at " + str(size_))
		confirm = view.find_child("MedicalConfirmProtocol", true, false)
		check(confirm != null and confirm.get_parent().get_parent() is ScrollContainer, "medical decisions remain in bounded scroll surface")
		var picker: OptionButton = view.find_child("MedicalPlayerPicker", true, false)
		check(Rect2(Vector2.ZERO,Vector2(size_)).encloses(picker.get_global_rect()), "long names remain inside viewport at " + str(size_))
	view.update_frame(app.model, {"playerId":"injured:real", "meetingId":"medical:fixture", "completed":true})
	await settle()
	check(not view.find_child("MedicalClose", true, false).disabled, "only server completed projection enables Continue")
	view._continue()
	check(director.closes == 1, "completed exchange returns to management")
	# Standalone room needs no club mark when missing, and has actual geometry/camera.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var room := MedicalRoom.new()
	room.configure({"name":"Club actif","color":"#176ca4"}, null)
	viewport.add_child(room)
	await settle()
	check(room.primary == Color("176ca4"), "3D room uses actual club color")
	check(room.find_children("*", "Camera3D", true, false).size() == 1, "3D room contains current camera")
	check(room.find_child("Treatment couch pad", true, false) != null, "medical room is real treatment couch geometry")
	check(room.find_child("ManagedClubCrest", true, false) == null, "missing logo leaves neutral physical surfaces")
	check(room.find_children("*", "Control", true, false).is_empty(), "3D room contains no fake UI")
	var branded := MedicalRoom.new()
	branded.configure({"name":"Autre club","color":"#c83c64"},ImageTexture.create_from_image(supplied_image))
	viewport.add_child(branded)
	await settle()
	check(branded.primary == Color("c83c64") and branded.crest_texture.get_width() == 30, "fresh room receives changed club color and supplied crest")
	var crest_count := 0
	for mesh: MeshInstance3D in branded.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_texture == branded.crest_texture: crest_count += 1
	check(crest_count == 2, "actual supplied crest is placed on wall and dossier")
	viewport.free()
	DirAccess.remove_absolute(portrait_path)
	app.free()
	director.free()
	print("MEDICAL_ROOM_CHECKS ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
