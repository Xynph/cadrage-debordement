extends SceneTree
const Career = preload("res://ui/staff_career_view.gd")
class App extends Control:
	var model := {}
	var last_command := ""
	var last_payload := {}
	func _clear_dialogs() -> void:
		for child in get_children():
			if child is Window: remove_child(child); child.queue_free()
	func _prepare_dialog(dialog: AcceptDialog, width: int) -> void:
		dialog.size = Vector2i(width, 540)
	func _command(command: String, payload: Dictionary) -> void:
		last_command = command; last_payload = payload
	func confirm(_title: String, _message: String, callback: Callable) -> void:
		callback.call()
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var app := App.new()
	root.add_child(app)
	var data := {"available":true,"enabled":false,"canEnable":true,"locked":false,"context":{"season":1,"week":0,"club":0},"assignments":[],"mentors":[],"players":[]}
	app.model = {"clubLife":{"staffMentoring":data}}
	var parent := VBoxContainer.new()
	app.add_child(parent)
	Career._mentoring(app, parent)
	var open: Button = parent.find_child("StaffMentoringOpen", true, false)
	assert(open != null)
	open.pressed.emit()
	var enable: Button = app.find_child("StaffMentoringEnable", true, false)
	assert(enable != null and not enable.disabled)
	enable.pressed.emit()
	assert(app.last_command == "staff_mentoring_enable")
	data.enabled = true
	data.mentors = [{"id":"mentor:test","name":"Ancien capitaine","observedSessions":3,"converted":true}]
	data.players = [{"id":"young:test","name":"Jeune témoin","pos":"Pilier","focusOptions":[{"key":"scrum","label":"Mêlée"}]}]
	Career._mentor_dialog(app, data)
	var confirm: Button = app.find_child("StaffMentorConfirm", true, false)
	assert(confirm != null)
	confirm.pressed.emit()
	assert(app.last_command == "staff_mentor_assign")
	assert(app.last_payload.staffId == "mentor:test" and app.last_payload.playerId == "young:test" and app.last_payload.focus == "scrum")
	assert(app.last_payload.context == {"season":1,"week":0,"club":0})
	print("STAFF_MENTORING_UI_PASS: activation, choix, qualité et contexte")
	app.free()
	quit(0)
