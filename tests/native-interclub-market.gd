extends SceneTree
var checks := 0
var failures := 0
class Office extends Control:
	var model: Dictionary
	var waiting := false
	var confirmation: Callable
	var command := ""
	var payload: Dictionary
	func _clear_dialogs() -> void: pass
	func _prepare_dialog(_dialog: AcceptDialog, _width: int) -> void: pass
	func confirm(_title: String, _message: String, callback: Callable) -> void: confirmation = callback
	func _command(value: String, data: Dictionary) -> void:
		command = value
		payload = data
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
	checks += 1
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var app := Office.new()
	var people: Array = []
	for i in range(25): people.append({"id":"person-%d" % i,"name":"Joueur %d" % i,"clubId":1,"club":"Club voisin","pos":"Centre","age":24,"fee":100000,"salary":5000,"sourceSalary":4700,"contractEnd":2,"available":i!=0,"reason":"Prêt en cours" if i==0 else ""})
	app.model = {"clubLife":{"interclubMarket":{"candidates":people,"context":{"season":1,"week":0,"club":0},"notice":"Accord fictif"}}}
	root.add_child(app)
	var view: AcceptDialog = load("res://ui/interclub_market_view.gd").open(app)
	await process_frame
	check(view.visible,"dialogue visible")
	check(view.rows.get_child_count()==13,"navigation et douze profils par page")
	var first: Button = view.rows.get_child(1).find_child("InterclubOffer",true,false)
	check(first.disabled,"offre indisponible désactivée")
	var second: Button = view.rows.get_child(2).find_child("InterclubOffer",true,false)
	second.pressed.emit()
	check(app.command.is_empty(),"confirmation avant mutation")
	check(app.confirmation.is_valid(),"confirmation offerte")
	app.confirmation.call()
	check(app.command=="interclub_transfer","commande correcte")
	check(app.payload.playerId=="person-1" and app.payload.fee==100000,"devis du bon joueur")
	var search: LineEdit = view.find_child("InterclubSearch",true,false)
	search.text = "Joueur 24"
	search.text_changed.emit(search.text)
	await process_frame
	check(view.rows.get_child_count()==2,"filtre appliqué sans conserver les autres lignes")
	check(view.page==0,"filtre remet à la première page")
	view.queue_free()
	app.queue_free()
	await process_frame
	print("Marché interclubs Godot : %d contrôles réussis" % checks)
	quit(1 if failures else 0)
