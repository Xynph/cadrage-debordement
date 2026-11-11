extends SceneTree
const Office = preload("res://ui/immersive08/office.gd")
const Canvas = preload("res://ui/immersive08/office_canvas.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")

class BareHost extends Control:
	var model: Dictionary
	var catalogue: Array = []
	var accent := Color("176e49")
	var route := "Bureau"
	var commands := 0
	var primary_calls := 0
	func _navigate(destination: String) -> void: route = destination
	func _command(_id: String, _payload: Dictionary = {}) -> void: commands += 1
	func primary_text() -> String: return "Continuer"
	func primary_action() -> void: primary_calls += 1

class Host extends BareHost:
	var navigation_controller: Node

class Navigation extends Node:
	var app: Control
	var targets: Array = []
	func entity_available(target: Dictionary) -> bool:
		var kind := str(target.get("kind", ""))
		if kind == "player": return app.model.get("squad", []).any(func(person: Dictionary): return str(person.id) == str(target.get("id", "")))
		if kind in ["club", "fixture", "date"]: return Competition.target_available(app, kind, target.get("id", ""))
		return false
	func open_entity(target: Dictionary) -> bool:
		if not entity_available(target): return false
		targets.append(target.duplicate(true))
		return true
	func open_watched_roster() -> void: targets.append({"kind":"watch-list"})
	func open_roster_group() -> void: targets.append({"kind":"squad-list"})

var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func words(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children(): result += words(child)
	return result
func panel(host: Control) -> Panel:
	var value := Panel.new()
	host.add_child(value)
	return value
func fixture_frame(host: Control) -> PanelContainer:
	var frame := Office.C.card()
	host.add_child(frame)
	Office._fixture(frame, host)
	return frame
func press(host: Host, scope: Node, id: String, target: Dictionary) -> void:
	var button := scope.find_child(id, true, false) as Button
	check(button != null, "Lien réel construit : " + id)
	if button == null: return
	check(button.focus_mode == Control.FOCUS_ALL and not button.accessibility_name.is_empty(), "Lien nommé et accessible au clavier : " + id)
	button.pressed.emit()
	check(host.navigation_controller.targets.back() == target, "Cible stable exacte : " + id)
func run() -> void:
	root.size = Vector2i(2560, 1440)
	var home := {"id":1,"name":"Club du manager","abbr":"CDM"}
	var away := {"id":2,"name":"Club adverse","abbr":"CAD"}
	var played := {"id":"fixture:past","home":home,"away":away,"date":"2026-11-04","week":0,"played":true,"score":[17,12]}
	var next := {"id":"fixture:next","home":away,"away":home,"date":"2026-11-18","week":2,"played":false,"label":"Championnat"}
	var model := {"club":home,"meta":{"mode":"common","season":1,"week":1,"phase":"league","leagueId":"elite","trust":60,"morale":70},"next":next,"calendar":[played,next],"leagues":[{"id":"elite","name":"Championnat","rows":[home,away]}],"squad":[{"id":"player:watched","name":"Joueur à surveiller","pos":"Centre","age":25,"condition":72,"physicalLoad":74}],"selection":{"valid":true}}
	var host := Host.new()
	host.model = model.duplicate(true)
	host.navigation_controller = Navigation.new()
	host.navigation_controller.app = host
	host.add_child(host.navigation_controller)
	root.add_child(host)
	var before := JSON.stringify(host.model)
	var canvas_fixture := panel(host)
	Canvas._fixture(canvas_fixture, host)
	press(host, canvas_fixture, "OfficeNextHomeClubName", {"kind":"club","id":"2"})
	press(host, canvas_fixture, "OfficeNextAwayClubCrest", {"kind":"club","id":"1"})
	press(host, canvas_fixture, "OfficeNextDate", {"kind":"date","id":"2026-11-18"})
	check(canvas_fixture.find_child("OfficePreparationAction",true,false) != null and canvas_fixture.find_child("OfficeSelectionAction",true,false) != null, "Les actions de préparation et composition restent présentes")
	var compact := fixture_frame(host)
	press(host, compact, "OfficeNextHomeClubCrest", {"kind":"club","id":"2"})
	press(host, compact, "OfficeNextAwayClubName", {"kind":"club","id":"1"})
	press(host, compact, "OfficeNextDate", {"kind":"date","id":"2026-11-18"})
	check(words(canvas_fixture).contains("CLUB ADVERSE") and words(compact).contains("Club adverse"), "Les libellés des deux gabarits restent inchangés")
	var group := panel(host)
	Canvas._group(group, host)
	press(host, group, "OfficeWatchedPlayer_player_watched", {"kind":"player","id":"player:watched"})
	check(group.find_child("OfficeWatchedAction",true,false) != null, "L'action de liste surveillée reste distincte")
	var timeline := panel(host)
	Canvas._timeline(timeline, host, null)
	press(host, timeline, "OfficeTimelineDateLink_fixture_next", {"kind":"date","id":"2026-11-18"})
	press(host, timeline, "OfficeTimelineClubName_fixture_next", {"kind":"club","id":"2"})
	var compact_timeline := VBoxContainer.new()
	host.add_child(compact_timeline)
	# The compact helper moves its card title into its header after construction.
	compact_timeline.add_child(Office.C.label("Prochains matchs",20))
	compact_timeline.get_child(0).name = "CardTitle"
	Office._timeline(compact_timeline, host)
	press(host, compact_timeline, "OfficeTimelineClubCrest_fixture_next", {"kind":"club","id":"2"})
	var recent := Office.recent_results(host)
	host.add_child(recent)
	press(host, recent, "OfficeRecentFixture_fixture_past", {"kind":"fixture","id":"fixture:past"})
	press(host, recent, "OfficeRecentClubName_fixture_past", {"kind":"club","id":"2"})
	check(words(recent).contains("17 – 12"), "Score affiché conservé")
	var mismatch := played.duplicate(true)
	mismatch.score = [12,17]
	check(Office.score_reading_target(host,mismatch).is_empty(), "Score différent du lookup exact sans lien")
	mismatch = played.duplicate(true)
	mismatch.home = away; mismatch.away = home
	check(Office.score_reading_target(host,mismatch).is_empty(), "Adversaires inversés refusés")
	mismatch = played.duplicate(true)
	mismatch.id = ""
	check(Office.score_reading_target(host,mismatch).is_empty(), "Score sans ID sans lien")
	mismatch = played.duplicate(true)
	mismatch.date = "2026-11-05"
	check(Office.score_reading_target(host,mismatch).is_empty(), "Date différente refusée malgré ID identique")
	host.model.calendar.append(mismatch)
	check(Office.score_reading_target(host,played).is_empty(), "Lookup ambigu refuse le lien de score")
	host.model.calendar.pop_back()
	mismatch = played.duplicate(true)
	mismatch.score = [25,22]
	host.model.calendar.append(mismatch)
	check(Office.score_reading_target(host,played).is_empty(), "Deux scores publiés pour le même ID restent sans lien")
	host.model.calendar.pop_back()
	check(Office.date_reading_target(host,{"week":4}).is_empty(), "Semaine seule ne devient pas une date inventée")
	check(Office.club_reading_target(host,{"name":"Club absent"}).is_empty(), "Club sans ID reste sans lien")
	check(Office.fixture_opponent(host.model,{"home":{"id":5},"away":{"id":6}}).is_empty(), "Fixture sans club géré ne choisit pas un adversaire arbitraire")
	var bare := BareHost.new()
	bare.model = model.duplicate(true)
	root.add_child(bare)
	var bare_canvas := panel(bare)
	Canvas._fixture(bare_canvas,bare)
	check(bare_canvas.find_child("OfficeNextDate",true,false) == null and words(bare_canvas).contains("CLUB ADVERSE"), "Fakehost sans navigation conserve ses vrais labels sans bouton mort")
	var bare_recent := Office.recent_results(bare)
	bare.add_child(bare_recent)
	check(bare_recent.find_children("OfficeRecentFixture*","Button",true,false).is_empty() and words(bare_recent).contains("17 – 12"), "Résultat sans contrôleur reste du texte")
	check(JSON.stringify(host.model) == before and host.commands == 0 and host.primary_calls == 0 and host.route == "Bureau", "Liens sans commande, action primaire, changement du modèle ou route implicite")
	bare.queue_free(); host.queue_free()
	await process_frame
	print("OFFICE_ENTITY_LINKS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
