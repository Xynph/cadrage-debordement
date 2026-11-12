extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
var directory := OS.get_environment("CD_DEEP_MARKET_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message); printerr("FAIL: "+message)
func settle() -> void:
	for i in range(8): await process_frame
func wait_response() -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	check(not app.waiting,"réponse worker reçue")
	await settle()
func ask(command: String,payload: Dictionary={}) -> void:
	app._command(command,payload)
	await wait_response()
	check(app.bridge.last_response_ok,"commande "+command+" · "+str(app.last_error))
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline:=Time.get_ticks_msec()+30000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec()<deadline: await process_frame
	app.timer.stop()
	await ask("new_career",{"mode":"common","club":0})
	# Une carrière neuve ouvre d'abord le rendez-vous de direction : tant qu'il n'est pas traité, le moteur refuse toute négociation.
	await preload("res://qa_runner.gd").settle_club_meetings(app,self,check)
	await ask("export")
	var initial: String=app.model.meta.exportText
	var profile: String=str(app.model.meta.dataDir).path_join("donnees.json")
	var disk:=FileAccess.get_file_as_bytes(profile)
	var data: Dictionary=app.model.clubLife.interclubMarket
	var person: Dictionary={}
	for candidate: Dictionary in data.candidates:
		if candidate.available: person=candidate; break
	check(not person.is_empty(),"cible disponible")
	var view: AcceptDialog=load("res://ui/interclub_market_view.gd").open(app)
	view._offer(person)
	await settle()
	check(view.visible,"dialogue de négociation visible")
	view.fee_input.value=0
	view.salary_input.value=1000
	view._negotiate()
	await wait_response()
	check(is_instance_valid(view) and view.visible,"consultation conserve la saisie")
	check(view.local_message.text.contains("demande"),"contre-propositions affichées")
	check(view.offer_fee==0 and view.offer_salary==1000,"saisie basse conservée")
	await ask("export")
	check(app.model.meta.exportText==initial,"consultation garde export exact")
	check(FileAccess.get_file_as_bytes(profile)==disk,"consultation garde disque exact")
	var best_salary:=int(person.salary)
	var best_fee:=int(person.fee)
	for offer: Dictionary in view.negotiation.get("offers",[]):
		best_salary=maxi(best_salary,int(offer.salary))
		best_fee=maxi(best_fee,int(offer.fee))
	view.fee_input.value=best_fee+1000
	view.salary_input.value=best_salary+1000
	check(view.close_button.disabled,"modifier invalide l'ancien devis")
	view._negotiate()
	await wait_response()
	check(view.negotiation.get("winner",{}).get("human",false),"offre améliorée remporte le devis")
	var payload: Dictionary=view._payload()
	var winner: Dictionary=view.negotiation.winner
	payload.context.week=int(payload.context.week)+1
	payload.merge({"expectedWinner":int(winner.clubId),"expectedFee":int(winner.fee),"expectedSalary":int(winner.salary),"confirmed":true})
	view.pending=true
	app._command("interclub_auction",payload)
	await wait_response()
	check(not app.bridge.last_response_ok,"devis périmé refusé")
	check(is_instance_valid(view) and view.visible,"refus conserve le dialogue")
	check(view.local_message.text.contains("conservées"),"refus local explicite")
	check(view.offer_fee==best_fee+1000 and view.offer_salary==best_salary+1000,"montants conservés après refus")
	view._negotiate()
	await wait_response()
	view._confirm_auction()
	var confirmation: ConfirmationDialog=view.get_node_or_null("InterclubAuctionConfirmation")
	check(confirmation!=null,"confirmation avant transaction définitive")
	confirmation.confirmed.emit()
	await wait_response()
	check(app.bridge.last_response_ok,"clôture acceptée")
	check(view.local_message.text.contains("votre club"),"résultat réel affiché")
	view.queue_free()
	await settle()
	await ask("export")
	check(app.model.meta.exportText!=initial,"achat persistant change la carrière")
	var report:=FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures}));report.close()
	app.bridge.stop();app.queue_free();await settle()
	print("Marché approfondi : %d contrôles UI" % checks)
	quit(0 if failures.is_empty() else 1)
