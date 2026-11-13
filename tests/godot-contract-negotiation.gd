extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Negotiation = preload("res://ui/contract_negotiation.gd")
const Salary = preload("res://ui/salary_display.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_CONTRACT_NEGOTIATION_OUTPUT")
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); printerr("FAIL: ",text)
func settle() -> void:
	for frame in 10: await process_frame
func wait_response() -> void:
	var deadline := Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse réelle du moteur : "+str(app.last_error))
func command(id: String, payload: Dictionary = {}) -> void:
	print("SDK_COMMAND ",Time.get_ticks_msec()," godot-contract-negotiation ",id)
	var accepted: bool=app._command(id,payload)
	check(accepted,"Commande publique acceptée : "+id)
	if not accepted:return
	await wait_response()
func current(id: String, recruiting: bool) -> Dictionary:
	for player: Dictionary in app.model.get("market" if recruiting else "squad",[]):
		if str(player.id)==id: return player
	return {}
func open(id: String, recruiting: bool) -> ConfirmationDialog:
	app.SquadViews.contract(app,current(id,recruiting),recruiting)
	await settle()
	var dialog := app.find_child("ContractOffer",true,false) as ConfirmationDialog
	check(dialog != null and dialog.visible,"Dialogue commun raccordé : "+("recrutement" if recruiting else "prolongation"))
	return dialog
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"Capture réelle 2560×1440")
	check(image.save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func low_offer(id: String, recruiting: bool) -> void:
	var dialog: ConfirmationDialog = await open(id,recruiting)
	var salary := dialog.find_child("OfferSalary",true,false) as SpinBox
	var years := dialog.find_child("OfferYears",true,false) as SpinBox
	salary.value=1000
	years.value=years.min_value
	dialog.confirmed.emit()
	await wait_response()
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	var until := Time.get_ticks_msec()+45000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	check(not app.model.is_empty(),"Application reliée au vrai moteur")
	await command("new_career",{"mode":"common","club":0})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Recrutement");await settle()
	var target: Dictionary={}
	for player: Dictionary in app.model.market:
		if player.available and player.salary>1000: target=player;break
	check(not target.is_empty(),"Piste réelle négociable")
	if target.is_empty(): await app._close(1);return
	var id := str(target.id)
	var profile := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(profile)
	var cash: Variant=app.model.finance.cash
	var count: int=app.model.squad.size()
	var dialog: ConfirmationDialog=await open(id,true)
	var salary := dialog.find_child("OfferSalary",true,false) as SpinBox
	var years := dialog.find_child("OfferYears",true,false) as SpinBox
	check(dialog.size.x>=1450 and dialog.size.y<=1000,"Surface de négociation conçue pour1440p")
	check(salary.get_line_edit().get_theme_font_size("font_size")>=18 and salary.get_line_edit().get_theme_font_size("font_size")<=22,"Montant lisible en1440p")
	check(dialog.get_cancel_button().has_focus(),"Annulation focalisée par défaut")
	var portrait := dialog.find_child("ContractPlayerPortrait",true,false) as TextureRect
	check(portrait != null and portrait.get_meta("player_id","")==id,"Portrait existant rattaché au bon joueur")
	check(dialog.find_child("ContractNegotiationProgress",true,false).text.contains("1/3"),"Prochaine proposition1/3 explicite")
	salary.value=1000;years.value=years.min_value
	check(dialog.find_child("OfferSummary",true,false).text.contains("IMMÉDIAT") and dialog.find_child("OfferSummary",true,false).text.contains("ajout"),"Récapitulatif acquisition et ajout hebdomadaire")
	check(FileAccess.get_sha256(profile)==before and app.model.finance.cash==cash,"Saisie et lecture ne débitent ni écrivent")
	await capture("contrat-recrutement-initial-1440")
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true)
	await settle()
	check(not is_instance_valid(dialog) or not dialog.visible,"Échap ferme sans proposition")
	check(FileAccess.get_sha256(profile)==before,"Annuler n'envoie aucune proposition")
	await low_offer(id,true)
	check(app.model.meta.negotiation.status=="counter","Vraie contre-offre moteur")
	check(app.model.finance.cash==cash and app.model.squad.size()==count,"Contre-offre sans signature ni débit")
	await command("snapshot")
	var counter: Dictionary=current(id,true).negotiation.duplicate(true)
	var counter_disk := FileAccess.get_sha256(profile)
	dialog=await open(id,true)
	check(dialog.find_child("ContractCurrentNegotiation",true,false).text.contains(Salary.amount(counter.salary)),"Contre-offre retrouvée après snapshot")
	check(dialog.find_child("ContractNegotiationProgress",true,false).text.contains("1/3"),"Numéro réellement enregistré")
	check(dialog.find_child("ContractNextAction",true,false).text.contains("2/3"),"Prochaine tentative2/3")
	var reuse := dialog.find_child("ContractUseCounteroffer",true,false) as Button
	reuse.pressed.emit();await settle()
	salary=dialog.find_child("OfferSalary",true,false);years=dialog.find_child("OfferYears",true,false)
	check(Salary.input_weekly(salary)==roundi(counter.salary) and salary.value==snappedf(float(counter.salary)*Salary.factor(),100.0) and int(years.value)==int(counter.years),"Reprendre contre-offre copie conditions exactes")
	check(FileAccess.get_sha256(profile)==counter_disk and app.model.finance.cash==cash,"Reprendre conditions ne transmet pas l'offre")
	await capture("contrat-recrutement-contreoffre-1440")
	dialog.canceled.emit();await settle()
	await low_offer(id,true);await low_offer(id,true)
	check(current(id,true).negotiation.status=="withdrawn","Retrait réel après troisième refus")
	app.management_ui.market.navigation_id = id
	app._navigate("Recrutement");await settle()
	var consult := app.find_child("OfferRecruitment",true,false) as Button
	check(consult != null and not consult.disabled and consult.text.contains("Consulter"),"Recrutement propose une consultation du retrait")
	consult.pressed.emit();await settle()
	dialog = app.find_child("ContractOffer",true,false)
	check(dialog != null and dialog.visible,"La consultation réelle ouvre le dossier retiré")
	check(dialog.get_ok_button().disabled,"Retrait interdit la confirmation dans l'interface")
	check(dialog.find_child("ContractNextAction",true,false).text.contains("prochaine journée"),"Reprise le jour suivant expliquée")
	var withdrawn_disk := FileAccess.get_sha256(profile)
	dialog.confirmed.emit();await settle()
	check(FileAccess.get_sha256(profile)==withdrawn_disk and app.model.finance.cash==cash,"Confirmation forcée d'un dossier verrouillé ne commande rien")
	await capture("contrat-recrutement-retrait-1440")
	dialog.canceled.emit();await settle()
	var renewal: Dictionary={}
	for player: Dictionary in app.model.squad:
		if player.get("renewal",{}).get("available",false) and player.salary>2000: renewal=player;break
	check(not renewal.is_empty(),"Prolongation réelle disponible")
	if renewal.is_empty(): await app._close(1);return
	var renewal_id := str(renewal.id)
	await low_offer(renewal_id,false)
	check(current(renewal_id,false).renewal.negotiation.status=="counter","Contre-offre réelle pour prolongation")
	dialog=await open(renewal_id,false)
	check(dialog.find_child("OfferSummary",true,false).text.contains("écart") and dialog.find_child("OfferSummary",true,false).text.contains("Échéance actuelle"),"Contrat actuel et écart conservés")
	await capture("contrat-prolongation-contreoffre-1440")
	var renewal_quote: Dictionary=current(renewal_id,false).renewal.duplicate(true)
	dialog.find_child("ContractUseCounteroffer",true,false).pressed.emit();await settle()
	var agreed_salary := Salary.input_weekly(dialog.find_child("OfferSalary",true,false) as SpinBox)
	var pre_signature_cash: Variant=app.model.finance.cash
	dialog.confirmed.emit();await wait_response()
	check(app.model.meta.negotiation.status=="signed","Signature réelle après autorisation explicite")
	check(app.model.finance.cash==pre_signature_cash-renewal_quote.fee,"Prime unique débitée uniquement à signature")
	check(current(renewal_id,false).salary==agreed_salary,"Salaire signé égal au montant autorisé")
	check(app.model.squad.size()==count,"Prolongation ne duplique pas l'effectif")
	var second_renewal: Dictionary = {}
	for player: Dictionary in app.model.squad:
		if str(player.id)!=renewal_id and player.get("renewal",{}).get("available",false) and player.salary>2000: second_renewal=player;break
	check(not second_renewal.is_empty(),"Deuxième prolongation pour recevoir le retrait")
	if not second_renewal.is_empty():
		var second_id := str(second_renewal.id)
		var before_withdrawal: Variant = app.model.finance.cash
		for attempt in 3: await low_offer(second_id,false)
		check(current(second_id,false).renewal.negotiation.status=="withdrawn","Retrait réel imbriqué de prolongation")
		dialog=await open(second_id,false)
		check(dialog.get_ok_button().disabled and not dialog.find_child("OfferSalary",true,false).editable,"Prolongation retirée : champs et confirmation verrouillés")
		check(app.model.finance.cash==before_withdrawal,"Trois refus de prolongation sans débit")
		await capture("contrat-prolongation-retrait-1440")
		dialog.canceled.emit();await settle()
	var final := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	final.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"resolution":[2560,1440]},"  "));final.close()
	print("NÉGOCIATIONS CONTRACTUELLES1440 : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
