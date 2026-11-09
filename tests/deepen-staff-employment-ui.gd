extends SceneTree
const Career = preload("res://ui/staff_career_view.gd")
class App extends Control:
	var model := {}
	var management_ui := {}
	var last_command := ""
	var last_payload := {}
	func _clear_dialogs() -> void:
		for child in get_children():
			if child is Window: remove_child(child); child.queue_free()
	func _prepare_dialog(dialog: AcceptDialog, width: int) -> void: dialog.size = Vector2i(width,540)
	func _command(command: String,payload: Dictionary) -> void: last_command=command; last_payload=payload
	func confirm(_title: String,_text: String,callback: Callable) -> void: callback.call()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app:=App.new(); root.add_child(app)
	var data: Dictionary={"available":true,"enabled":false,"canEnable":true,"locked":false,"context":{"season":1,"week":0,"club":0},"own":[],"candidates":[],"remainingCurrentSeason":29,"weeksPerSeason":29}
	app.model={"clubLife":{"staffEmployment":data}}
	var box:=VBoxContainer.new();app.add_child(box)
	Career._employment(app,box)
	var enable: Button=box.find_child("StaffEmploymentEnable",true,false); assert(enable!=null);enable.pressed.emit();assert(app.last_command=="staff_employment_enable")
	data.enabled=true
	var person: Dictionary={"id":"staff:test","name":"Entraîneur témoin","role":"coach","roleLabel":"Entraîneur","age":50,"canHire":true,"minYears":1,"maxYears":3}
	data.candidates=[{"id":"staff:test","salary":500,"employed":false}]
	Career._contract(app,person,{"context":data.context},false)
	var cost: Label=app.find_child("StaffEmploymentCommitment",true,false);assert(cost!=null and cost.text.contains("14"))
	var confirm: Button=app.find_child("StaffContractConfirm",true,false);confirm.pressed.emit()
	assert(app.last_command=="staff_employment_hire" and app.last_payload.salary==500 and app.last_payload.years==1)
	data.own=[{"id":"staff:test","salary":500,"paidSalary":500,"employed":true,"severance":1000,"remainingPayments":29}]
	Career._departure(app,box,person,{"context":data.context},"staff_release","LIBÉRER","Libérer le contrat.")
	var release: Button=box.find_child("StaffRelease",true,false);release.pressed.emit()
	assert(app.last_command=="staff_employment_release" and app.last_payload.severance==1000)
	print("DEEPEN_STAFF_UI_PASS: activation, devis, salaire, durée, rupture contextualisée")
	app.free();quit(0)
