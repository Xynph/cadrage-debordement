extends SceneTree
const Career = preload("res://ui/staff_career_view.gd")
class Transport extends Node:
	signal model_changed(model: Dictionary)
	signal command_failed(message: String)
	var last_response_ok := false
class Host extends Control:
	var management_ui := {}
	var model := {"clubLife":{"staffEmployment":{}}}
	var waiting := false
	var last_command := ""
	var bridge: Transport
	var synchronous_failure := false
	func _clear_dialogs() -> void:
		for child in get_children():
			if child is Window: remove_child(child); child.queue_free()
	func _prepare_dialog(dialog: AcceptDialog,width: int) -> void: dialog.size=Vector2i(width,540)
	func _command(command: String,_payload: Dictionary) -> bool:
		last_command=command; waiting=true
		if synchronous_failure: waiting=false; bridge.command_failed.emit("Processus arrêté");return false
		return true
var failures: Array[String]=[]
func check(value: bool,text: String) -> void:
	if not value:failures.append(text);printerr("FAIL: "+text)
func _initialize() -> void:call_deferred("run")
func submit(app: Host,person: Dictionary,data: Dictionary,renew: bool,years: int) -> void:
	Career._contract(app,person,data,renew)
	var field: OptionButton=app.find_child("StaffContractYears",true,false)
	for i in field.item_count:
		if int(field.get_item_metadata(i))==years:field.select(i);field.item_selected.emit(i)
	var button: Button=app.find_child("StaffContractConfirm",true,false)
	button.pressed.emit();await process_frame
func run() -> void:
	var app:=Host.new();app.bridge=Transport.new();app.add_child(app.bridge);root.add_child(app)
	var person: Dictionary={"id":"proof:mentor","name":"Mentor témoin","role":"coach","minYears":1,"maxYears":3}
	var data: Dictionary={"context":{"season":1,"week":0,"club":0}}
	var models:=app.bridge.model_changed.get_connections().size()
	var errors:=app.bridge.command_failed.get_connections().size()
	for attempt in 3:
		await submit(app,person,data,false,2)
		app.waiting=false;app.bridge.command_failed.emit("Processus arrêté")
		check(app.bridge.model_changed.get_connections().size()==models,"Pas d’observateur modèle accumulé après panne "+str(attempt))
		check(app.bridge.command_failed.get_connections().size()==errors,"Pas d’observateur erreur accumulé après panne "+str(attempt))
	app.bridge.last_response_ok=true;app.bridge.model_changed.emit({"snapshot":true})
	check(app.management_ui.staff_contract_drafts.has("proof:mentor:hire"),"Un snapshot de reconnexion ne valide pas une signature")
	Career._contract(app,person,data,false)
	var field: OptionButton=app.find_child("StaffContractYears",true,false)
	check(int(field.get_item_metadata(field.selected))==2,"Deux saisons conservées après trois pannes et snapshot")
	app._clear_dialogs();await process_frame
	app.synchronous_failure=true;await submit(app,person,data,false,2)
	check(app.bridge.model_changed.get_connections().size()==models and app.bridge.command_failed.get_connections().size()==errors,"Refus synchrone sans observateur résiduel")
	app.synchronous_failure=false
	await submit(app,person,data,false,2)
	app.waiting=false;app.bridge.last_response_ok=true
	var ack: Dictionary={"meta":{"staffCareerAction":{"command":"staff_hire","staffId":"proof:mentor"}},"clubLife":{"staffCareer":{"context":data.context,"teams":[{"id":0,"members":[{"id":"proof:mentor","clubId":0,"contractEnd":1}]}]}}}
	app.bridge.model_changed.emit(ack)
	check(app.management_ui.staff_contract_drafts.has("proof:mentor:hire"),"Un accusé avec mauvaise échéance conserve la saisie")
	ack.clubLife.staffCareer.teams[0].members[0].contractEnd=2
	await submit(app,person,data,false,2);app.waiting=false;ack.clubLife.staffCareer.context={"season":1,"week":1,"club":0};app.bridge.model_changed.emit(ack)
	check(app.management_ui.staff_contract_drafts.has("proof:mentor:hire"),"Accusé d’un autre contexte conserve la saisie")
	ack.clubLife.staffCareer.context=data.context
	await submit(app,person,data,false,2);app.waiting=false;ack.meta.staffCareerAction.staffId="proof:other";app.bridge.model_changed.emit(ack)
	check(app.management_ui.staff_contract_drafts.has("proof:mentor:hire"),"Accusé d’une autre personne conserve la saisie")
	ack.meta.staffCareerAction.staffId="proof:mentor"
	await submit(app,person,data,false,2);app.waiting=false;app.bridge.model_changed.emit(ack)
	check(not app.management_ui.staff_contract_drafts.has("proof:mentor:hire"),"Accusé cohérent de la bonne personne efface le brouillon")
	person.minYears=3
	await submit(app,person,data,true,3);app.waiting=false;ack.meta.staffCareerAction.command="staff_renew";ack.clubLife.staffCareer.teams[0].members[0].contractEnd=3;app.bridge.model_changed.emit(ack)
	check(not app.management_ui.staff_contract_drafts.has("proof:mentor:renew"),"Prolongation cohérente efface son brouillon")
	person.id="proof:paid";person.minYears=1
	app.model.clubLife.staffEmployment={"enabled":true,"context":data.context,"own":[],"candidates":[{"id":"proof:paid","salary":500}],"remainingCurrentSeason":29,"weeksPerSeason":29}
	var financial: Dictionary={"meta":{"staffEmploymentAction":{"command":"staff_employment_hire"}},"clubLife":{"staffCareer":{"context":data.context,"teams":[{"id":0,"members":[{"id":"proof:paid","clubId":0,"contractEnd":2}]}]},"staffEmployment":{"context":data.context,"own":[{"id":"proof:paid","employed":true,"paidSalary":250,"contractEnd":2}]}}}
	await submit(app,person,data,false,2);app.waiting=false;app.bridge.model_changed.emit(financial)
	check(app.management_ui.staff_contract_drafts.has("proof:paid:hire"),"Mauvais salaire financier ne valide pas le devis")
	financial.clubLife.staffEmployment.own[0].paidSalary=500
	await submit(app,person,data,false,2);app.waiting=false;app.bridge.model_changed.emit(financial)
	check(not app.management_ui.staff_contract_drafts.has("proof:paid:hire"),"Accusé financier cohérent valide le contrat rémunéré")
	check(app.bridge.model_changed.get_connections().size()==models and app.bridge.command_failed.get_connections().size()==errors,"Aucune connexion conservée après les accusés")
	print("DEEPEN_STAFF_TRANSPORT_UI: "+str(failures.size())+" échec(s)")
	app.free();quit(0 if failures.is_empty() else 1)
