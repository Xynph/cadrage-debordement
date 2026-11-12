extends SceneTree
const International = preload("res://ui/international_view.gd")

class Navigation extends Node:
	var targets: Array = []
	var available := {"nation:FRA":true, "nation:ENG":true, "player:known":true}
	func entity_available(target: Dictionary) -> bool:
		return available.get(str(target.get("kind", "")) + ":" + str(target.get("id", "")), false)
	func open_entity(target: Dictionary) -> bool:
		if not entity_available(target): return false
		targets.append(target.duplicate(true))
		return true

class Host extends Control:
	var navigation_controller: Node
	var model := {"international":{"nation":"ENG","role":"nation"}}
	var accent := Color("176e49")
	var commands := 0
	func _command(_id: String, _payload: Dictionary = {}) -> void: commands += 1

var checks := 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func words(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): result += words(child)
	return result
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app := Host.new()
	app.navigation_controller = Navigation.new()
	app.add_child(app.navigation_controller)
	root.add_child(app)
	var original := JSON.stringify(app.model)
	var names := {"FRA":"France", "ENG":"Angleterre", "UNKNOWN":"Nation non publiée"}
	var projection := {"callups":[{"nation":"FRA", "from":"2026-11-01", "through":"2026-11-30", "players":[{"id":"known", "name":"Joueur connu", "pos":"Centre", "age":24, "knowledge":{"stage":"observed","owned":false}, "ratingRange":{"min":66,"max":74}}, {"id":"absent", "name":"Joueur sans fiche", "pos":"Ailier", "age":22}]}]}
	var callups: Control = International._callups(app, projection, names)
	app.add_child(callups)
	check(words(callups).contains("France") and words(callups).contains("2026-11-01 au 2026-11-30"), "Titre et dates de convocation inchangés")
	check(words(callups).contains("Joueur connu · Centre · 24 ans · Niveau 66–74"), "Libellé et fourchette conservés mot pour mot")
	check(words(callups).contains("Joueur sans fiche · Ailier · 22 ans · Niveau —"), "Joueur non consultable reste affiché sans note inventée")
	var nation := callups.find_child("InternationalCallupNation_FRA", true, false) as Button
	var player := callups.find_child("InternationalCallupPlayer_known", true, false) as Button
	check(nation != null and player != null, "Nation et joueur disponibles deviennent contrôles de lecture")
	check(callups.find_child("InternationalCallupPlayer_absent", true, false) == null, "Aucun faux lien pour joueur absent des destinations")
	nation.pressed.emit()
	check(app.navigation_controller.targets.back() == {"kind":"nation", "id":"FRA"}, "Convocation France vise France malgré mandat Angleterre")
	player.pressed.emit()
	check(app.navigation_controller.targets.back() == {"kind":"player", "id":"known"}, "Joueur transmis par identifiant stable")
	var standings := VBoxContainer.new()
	app.add_child(standings)
	International._edition_standings(app, standings, [{"rows":[{"teamId":"FRA", "rank":1,"played":3,"points":14},{"teamId":"UNKNOWN","rank":2,"played":3,"points":8}]}], names, {})
	check(words(standings).contains("1. France · 3 J · 14 pts"), "Classement et points inchangés")
	var row := standings.find_child("InternationalStandingNation_FRA", true, false) as Button
	check(row != null and row.focus_mode == Control.FOCUS_ALL, "Classement nation accessible au clavier")
	check(standings.find_child("InternationalStandingNation_UNKNOWN", true, false) == null and words(standings).contains("Nation non publiée"), "Nation sans destination conserve son texte sans faux lien")
	row.pressed.emit()
	check(app.navigation_controller.targets.back() == {"kind":"nation", "id":"FRA"}, "Classement ouvre la nation exacte")
	app.navigation_controller.available.erase("player:known")
	var restricted: Control = International._callups(app, projection, names)
	app.add_child(restricted)
	check(restricted.find_child("InternationalCallupPlayer_known", true, false) == null, "Mandat ou contexte refusant joueur conserve seulement le texte")
	check(JSON.stringify(app.model) == original and app.commands == 0, "Lecture sans changement de mandat ni commande")
	app.queue_free()
	await process_frame
	print("NATIONAL_READING_LINKS ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
