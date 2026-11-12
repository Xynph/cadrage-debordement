extends SceneTree

class Navigation extends Node:
	var targets: Array = []
	func open_entity(target: Dictionary) -> bool:
		targets.append(target.duplicate(true))
		return true

class Reader extends Control:
	var model := {}
	var management_ui := {}
	var navigation_controller: Node
	var accent := Color("176e49")
	var selected_staff_club := 1
	var waiting := false
	var commands := 0
	func _live() -> Dictionary: return {}
	func _command(_name: String, _payload: Dictionary = {}) -> void: commands += 1
	func _render(_remember: bool = true) -> void: pass
	func _navigate(_route: String) -> void: pass
	func confirm(_title: String, _message: String, _action: Callable) -> void: commands += 1

var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var nations = load("res://ui/international_view.gd")
	var staff = load("res://ui/staff_view.gd")
	var identity = load("res://ui/player_identity.gd")
	if nations == null or staff == null or identity == null:
		quit(1); return
	var app := Reader.new()
	app.navigation_controller = Navigation.new()
	app.add_child(app.navigation_controller)
	root.add_child(app)
	app.model = {"meta":{"season":1,"phase":"preparation"}, "club":{"id":1}, "staff":{"teams":[
		{"id":1,"name":"Club du manager","members":[{"id":"staff:one","name":"Camille Martin","role":"Adjoint","age":42,"contractEnd":3}]},
		{"id":2,"name":"Club adverse","members":[{"id":"staff:two","name":"Alex Bernard","role":"Préparateur"}]}]},
		"clubLife":{"staffCareer":{"active":false,"history":[{"id":"staff:one","season":1,"kind":"hire"}]}},
		"international":{"nation":"ENG","role":"nation", "teams":[{"id":"FRA","name":"France","flagCode":"fr"},{"id":"ENG","name":"Angleterre","flagCode":"gb-eng"}],
		"editions":[{"id":"six:2026","year":2026,"name":"Tournoi","fixtures":[{"id":"fixture:one","homeId":"FRA","awayId":"ENG","date":"2026-02-07","result":{"home":21,"away":14}}]}]}}
	var original := JSON.stringify(app.model)
	check(not nations.open_target(app,"UNKNOWN"), "Une nation absente est refusée")
	check(app.management_ui.is_empty(), "Le refus ne change pas les lectures")
	check(nations.open_target(app,"FRA"), "France disponible depuis rôle Angleterre")
	check(app.model.international.nation == "ENG", "La nation gérée reste Angleterre")
	var page: Control = nations.build(app)
	app.add_child(page)
	check(page.name == "InternationalNationDetails" and page.get_meta("nation_id") == "FRA", "La destination est exactement France")
	check(str(page.find_child("InternationalNationName",true,false).text) == "France", "Titre de la nation consultée")
	check(page.find_children("NationalJob*","Button",true,false).is_empty(), "Aucune prise de poste dans la consultation")
	check(page.find_children("NationalPlay*","Button",true,false).is_empty(), "Aucun match déclenchable depuis la consultation")
	page.free()
	check(identity.nation_for_flag(app.model,"fr") == "FRA", "Drapeau français résolu par ID projeté")
	check(identity.nation_for_flag(app.model,"xx").is_empty(), "Drapeau sans destination reste sans lien")
	check(identity.nation_for_flag({"international":null},"fr").is_empty(), "Absence de projection nationale sans lien trompeur")
	var facts: Control = identity.row({"nationality":"France","flagCode":"fr","seniorCaps":0},20,Color.WHITE,app)
	app.add_child(facts)
	var flag := facts.find_child("PlayerOriginNationLink",true,false) as Button
	check(flag != null and flag.get_meta("entity_id") == "FRA" and flag.focus_mode == Control.FOCUS_ALL, "Drapeau navigable au clavier vers France")
	flag.pressed.emit()
	check(app.navigation_controller.targets.back() == {"kind":"nation","id":"FRA"}, "Le drapeau transmet seulement le ciblage de lecture")
	facts.free()
	check(not staff.open_target(app,"missing"), "Staff absent refusé")
	check(staff.open_target(app,"staff:two"), "Staff adverse accessible par ID stable")
	var staff_page: Control = staff.build(app)
	app.add_child(staff_page)
	check(staff_page.find_child("StaffProfileName",true,false).text == "Alex Bernard", "Le profil ouvert correspond au staff ciblé")
	check(staff_page.find_children("StaffHire*","Button",true,false).is_empty(), "La fiche de lecture n'ouvre pas un recrutement")
	staff_page.free()
	check(staff.open_target(app,"staff:one"), "Staff du club accessible par ID")
	staff_page = staff.build(app)
	app.add_child(staff_page)
	check(staff_page.find_child("StaffProfileName",true,false).text == "Camille Martin", "Même profil stable pour le staff du club")
	staff_page.free()
	check(JSON.stringify(app.model) == original, "Projection sportive strictement inchangée")
	check(app.commands == 0, "Aucune commande ni confirmation métier lors de la consultation")
	app.free()
	print("ENTITY_PROJECTIONS ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
