extends SceneTree
# Reprise avant le match (décision de Léo, 16/11/2026) : pendant un match (direct, entracte, causeries, résultat
# pas encore validé), « Quitter » (menu de la carrière, fermeture de la fenêtre) demande confirmation avec un texte du
# point de vue du manager ; hors match, aucune confirmation. Vrai jeu (main.tscn) et vrai moteur ; seul le modèle
# présenté est posé à la main (direct, puis résultat validé, puis aucun match). La fermeture réelle est neutralisée
# dès le départ (closing vrai : _close ne fait rien) : une sortie sans confirmation se voit à l'absence de la boîte.
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_QUITTER_MATCH_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func quit_dialog() -> ConfirmationDialog:
	for child in app.get_children():
		if child is ConfirmationDialog and not child.is_queued_for_deletion() and child.title == "Quitter pendant le match": return child
	return null
func dismiss() -> void:
	var dialog := quit_dialog()
	if dialog != null: dialog.get_cancel_button().pressed.emit()
	await settle()
func in_progress() -> bool:
	if not app.has_method("match_in_progress"):
		check(false,"main.gd expose match_in_progress()")
		return false
	return app.match_in_progress()
func with_model(live: Dictionary, confirmed: bool) -> void:
	var value: Dictionary = app.model.duplicate(true)
	var meta: Dictionary = value.get("meta",{})
	meta["calendarCadence"] = {"day":0,"matchReady":false,"canAdvance":false} if not confirmed else {"day":0,"matchReady":false,"canAdvance":true,"resultConfirmed":true}
	value["meta"] = meta
	if live.is_empty(): value.erase("live")
	else: value["live"] = live
	app.model = value
func quit_from_menu() -> void:
	app.pause_menu(); await settle()
	var menu := app.find_child("ImmersivePauseMenu",true,false) as AcceptDialog
	check(menu!=null,"Menu de la carrière ouvert")
	if menu != null: menu.custom_action.emit("quit")
	await settle()
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	var deadline := Time.get_ticks_msec()+90000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.model.is_empty(),"Application et moteur réels prêts")
	app.timer.stop()
	app.closing = true
	# 1. Direct en cours (en pause : le menu de la carrière ne renvoie pas de commande au moteur).
	with_model({"minute":18,"paused":true,"finished":false,"score":[3,7]}, false)
	check(in_progress(),"Match en cours reconnu")
	await quit_from_menu()
	var dialog := quit_dialog()
	check(dialog!=null,"« Quitter » du menu demande confirmation pendant le match")
	if dialog != null:
		check(dialog.dialog_text.contains("Le match est en cours") and dialog.dialog_text.contains("tu reprendras avant le coup d’envoi"),"Texte clair du point de vue du manager : "+dialog.dialog_text)
		check(dialog.get_cancel_button().has_focus(),"« Annuler » a le focus par défaut")
	await dismiss()
	check(quit_dialog()==null,"Annuler referme la confirmation")
	# 2. Fermeture de la fenêtre pendant l'entracte ou une causerie (match terminé, résultat pas encore validé).
	with_model({"minute":80,"paused":true,"finished":true,"score":[21,17]}, false)
	check(in_progress(),"Résultat pas encore validé : match toujours en cours")
	root.close_requested.emit(); await settle()
	check(quit_dialog()!=null,"Fermeture de la fenêtre : confirmation avant validation du résultat")
	await dismiss()
	# 3. Résultat validé : plus de match en cours, plus de confirmation.
	with_model({"minute":80,"paused":true,"finished":true,"score":[21,17]}, true)
	check(not in_progress(),"Résultat validé : plus de match en cours")
	root.close_requested.emit(); await settle()
	check(quit_dialog()==null,"Résultat validé : fermeture sans confirmation")
	# 4. Hors match : « Quitter » va directement à la fermeture, sans boîte de dialogue.
	with_model({}, false)
	check(not in_progress(),"Hors match : aucun match en cours")
	app.request_quit(); await settle()
	check(quit_dialog()==null,"Hors match : « Quitter » sans confirmation")
	await quit_from_menu()
	check(quit_dialog()==null,"Hors match : « Quitter » du menu sans confirmation")
	print("QUITTER PENDANT LE MATCH : ",checks," contrôles, ",failures.size()," échec(s)")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures})); file.close()
	app.timer.stop(); app.bridge.stop()
	var stop_deadline := Time.get_ticks_msec()+5000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < stop_deadline: await process_frame
	quit(0 if failures.is_empty() else 1)
