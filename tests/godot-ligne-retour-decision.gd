extends SceneTree
## Ligne de retour d'action du pied de page (« Conférence tenue », composant commun decision_feedback) :
## une seule ligne, entière (ni coupée ni réduite à « … »), sans recouvrir raccourcis ni bouton « Dernières décisions »,
## à 1920×1080 comme à 1280×720, sur chaque écran du pied de page. Vraie carrière Monde, vraie conférence de presse.
const ROUTES := ["Bureau","Effectif","Calendrier","Réception"]
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_LIGNE_RETOUR_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	for i in range(10): await process_frame
func wait_response() -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting,"réponse worker reçue")
	await settle()
func ask(command: String, payload: Dictionary = {}) -> void:
	app._command(command,payload)
	await wait_response()
	check(app.bridge.last_response_ok,"commande worker : " + command)
func screen_rect(node: Control) -> Rect2:
	return node.get_global_transform() * Rect2(Vector2.ZERO,node.size)
func inspect(tag: String) -> void:
	var status: Label = app.status
	check(is_instance_valid(status) and status.is_visible_in_tree(),tag + " : ligne de retour visible")
	if not is_instance_valid(status) or not status.is_visible_in_tree(): return
	check(status.text.begins_with("Conférence tenue"),tag + " : ligne « Conférence tenue » (" + status.text + ")")
	check(status.get_line_count() == 1,tag + " : une seule ligne (%d)" % status.get_line_count())
	var font: Font = status.get_theme_font("font")
	var pixels: int = status.get_theme_font_size("font_size")
	var needed: float = font.get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	check(needed <= status.size.x + 0.5,tag + " : texte entier sans coupe ni « … » (%.0f / %.0f)" % [needed,status.size.x])
	check(status.size.y + 0.5 >= font.get_height(pixels),tag + " : hauteur de ligne suffisante")
	var rect := screen_rect(status)
	var window := Rect2(Vector2.ZERO,Vector2(root.size))
	check(window.encloses(rect.grow(-0.5)),tag + " : dans la fenêtre " + str(rect))
	var feedback := app.find_child("DecisionFeedbackButton",true,false) as Control
	if feedback != null and feedback.is_visible_in_tree():
		check(not rect.intersects(screen_rect(feedback).grow(-0.5)),tag + " : ne recouvre pas « Dernières décisions »")
	var shortcuts := app.find_child("ImmersiveShortcuts",true,false) as Control
	if shortcuts != null and shortcuts.is_visible_in_tree():
		check(not rect.intersects(screen_rect(shortcuts).grow(-0.5)),tag + " : ne recouvre pas le pied de raccourcis")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await ask("new_career",{"mode":"world-champ","club":0})
	var press: Dictionary = app.model.clubLife.press
	check(press.get("conference",{}).get("questions",[]).size() > 0,"conférence de presse réelle disponible")
	var answers: Array = []
	for question: Dictionary in press.conference.questions: answers.append({"questionId":question.id,"answerId":question.answers[0].id})
	await ask("press_conference",{"context":press.context,"invitationId":press.conference.invitationId,"answers":answers})
	check(app.decision_feedback.status_text().begins_with("Conférence tenue"),"reçu « Conférence tenue » enregistré : " + app.decision_feedback.status_text())
	var long_cash := "Conférence tenue · Trésorerie : 123 456 789 € → 123 456 789 € (stable) · Salaires par semaine : 12 345 678 € → 12 345 678 € (stable) · Moral collectif : 100 → 100 / 100 (stable)"
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		for route in ROUTES:
			app._navigate(route); await settle()
			inspect("%dx%d %s" % [resolution.x,resolution.y,route])
			# Pire cas : reçu long (grosses sommes, deux mesures) publié après coup, comme après une réponse du moteur.
			app.decision_feedback._receipts.append({"command":"press_conference","title":"Conférence tenue","text":"","summary":long_cash,"before":{},"after":{},"targets":[]})
			app.status.text = app._settled_status_text()
			if app.has_method("_refit_status"): app._refit_status()
			await settle()
			inspect("%dx%d %s (reçu long)" % [resolution.x,resolution.y,route])
			app.decision_feedback._receipts.pop_back()
			app.status.text = app._settled_status_text()
			if app.has_method("_refit_status"): app._refit_status()
	var report := {"checks":checks,"failures":failures}
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report)); file.close()
	print("Ligne de retour : %d contrôles, %d échecs" % [checks,failures.size()])
	app.bridge.stop(); app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
