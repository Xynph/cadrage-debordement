extends SceneTree
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const Recruitment = preload("res://ui/immersive08/recruitment_canvas.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
class ReadingApp extends Control:
	var model: Dictionary
	var catalogue: Array = []
	var management_ui: Dictionary = {}
	var table_division := "elite"
	var route := "Réception"
	var commands := 0
	func _navigate(destination: String, _remember: bool = true) -> void:
		route = destination
	func _command(_id: String, _payload: Dictionary = {}) -> void:
		commands += 1
var failures: Array[String] = []
var checks := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description); printerr("FAIL: ", description)
func _initialize() -> void:
	var app := ReadingApp.new()
	# Synthetic fixtures test identifier collision/lookup failure, never sporting results.
	app.model = {"club":{"id":1,"name":"Club géré"},"meta":{"leagueId":"elite","date":"2026-11-11"},"leagues":[{"id":"elite","rows":[{"id":1,"name":"Club géré","rank":2},{"id":2,"name":"Adversaire","rank":1}]}],"calendar":[{"id":"known","home":{"id":1},"away":{"id":2},"date":"2026-11-12","played":false}],"history":[{"fixtureId":"past","pair":[1,2],"score":[12,15],"phase":"league"}]}
	var original := JSON.stringify(app.model)
	check(Competition.target_available(app,"club","2"),"Identifiant club string résout l’ID natif entier")
	check(not Competition.target_available(app,"club","999"),"Club absent refusé sans repli sur le club géré")
	check(Competition.target_available(app,"fixture","known"),"Rencontre actuelle par ID exact")
	check(Competition.target_available(app,"fixture","past"),"Rencontre historique retenue par fixtureId")
	check(not Competition.target_available(app,"fixture",""),"ID vide refuse le prochain match implicite")
	check(not Competition.target_available(app,"fixture","unknown"),"Rencontre disparue refusée")
	app.model.calendar.append({"id":"known","home":{"id":2},"away":{"id":1},"date":"2026-11-12"})
	check(not Competition.target_available(app,"fixture","known"),"ID ambigu entre adversaires ou domicile refusé")
	app.model.calendar.pop_back()
	app.model.calendar.append({"id":"known","home":{"id":1},"away":{"id":2},"date":"2027-11-12"})
	check(not Competition.target_available(app,"fixture","known"),"ID réemployé sur une autre date refusé")
	app.model.calendar.pop_back()
	check(Competition.target_available(app,"date","2028-02-29") and not Competition.target_available(app,"date","2027-02-29"),"Date calendaire réelle sans normalisation silencieuse")
	check(not Competition.open_target(app,"competition","absent") and app.route=="Réception","Compétition absente ne change pas de route")
	check(Competition.open_target(app,"competition","elite") and app.route=="Classements" and app.table_division=="elite","Compétition cible le classement réel")
	app.management_ui.calendar_reading = {"filter":"matches","view":"week","scroll":47}
	check(Competition.open_target(app,"date","2026-11-12") and app.route=="Calendrier","Date ouvre le calendrier")
	check(app.management_ui.calendar_reading.selected=="2026-11-12" and app.management_ui.calendar_reading.filter=="matches" and app.management_ui.calendar_reading.view=="week" and app.management_ui.calendar_reading.scroll==47,"Date ciblée conserve filtre vue et lecture existante")
	for tab: String in ["summary","cash","wages","transfers","budget"]:
		check(Finance.open_target(app,tab) and app.route=="Finances" and app.management_ui[Finance.KEY]==tab,"Onglet financier réel : "+tab)
	check(not Finance.open_target(app,"unknown") and app.management_ui[Finance.KEY]=="budget","Onglet absent refusé sans écraser la sélection")
	check(app.commands==0 and JSON.stringify(app.model)==original,"Lecture laisse modèle sportif inchangé et n’émet aucune commande")
	app.model.club = null
	check(not Competition.target_available(app,"club","999") and Competition.target_available(app,"club","2"),"Nation sans club : lookup public résolu sans repli sur un club géré")
	var context: Control = Competition.new()
	context.app = app
	app.management_ui.competition = {"club_league":"other","tab":"stats"}
	app.table_division = "other"
	context._context(true)
	check(context.own.is_empty() and app.management_ui.competition.club_league=="other" and app.management_ui.competition.tab=="stats" and app.table_division=="other","Contexte sans club conserve division et onglet de lecture")
	context.free()
	app.model.decisions = {"recruitment":{"reports":[{"id":"report-1","playerId":"former-market","name":"Nom archivé","assessment":{"observed":["Fait conservé"]}}]}}
	app.model.market = []
	var report_model := JSON.stringify(app.model)
	check(Recruitment.target_available(app,"report-1"),"Rapport archivé accessible même après sortie du marché")
	check(not Recruitment.target_available(app,"missing") and not Recruitment.target_available(app,""),"Rapport absent ou sans ID refusé")
	app.model.decisions.recruitment.reports.append({"id":"report-1","playerId":"other"})
	check(not Recruitment.target_available(app,"report-1"),"ID de rapport ambigu refusé")
	app.model.decisions.recruitment.reports.pop_back()
	check(JSON.stringify(app.model)==report_model and app.commands==0,"Résolution des rapports conserve modèle et commandes")
	app.free()
	print("WORLD ENTITY TARGETS : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)
