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
## Recrutement : depuis l'écran Recrutement, l'offre est une sous-page « Offre au joueur » (recruitment_pages.gd) qui adopte
## le contenu de la fenêtre commune (masquée). Prolongation : la fenêtre commune reste affichée.
func open(id: String, recruiting: bool) -> ConfirmationDialog:
	app.SquadViews.contract(app,current(id,recruiting),recruiting)
	await settle()
	var dialog := app.find_child("ContractOffer",true,false) as ConfirmationDialog
	if recruiting:
		var state: Variant = app.management_ui.get("recrutement_page")
		check(dialog != null and not dialog.visible and offer_page() != null and state is Dictionary and state.get("kind") == "negociation" and str(state.get("player_id","")) == id,"Écran commun raccordé : recrutement (Offre au joueur)")
	else:
		check(dialog != null and dialog.visible,"Dialogue commun raccordé : prolongation")
	return dialog
func offer_page() -> Control:
	var page := app.find_child("RecrutementSubpage_negociation",true,false) as Control
	return page if page != null and page.is_visible_in_tree() else null
## Élément de l'offre : dans la page « Offre au joueur » si elle est ouverte, sinon dans la fenêtre.
func part(dialog: ConfirmationDialog, id: String) -> Node:
	var page := offer_page()
	if page != null: return page.find_child(id,true,false)
	return dialog.find_child(id,true,false) if is_instance_valid(dialog) else null
func shown(dialog: ConfirmationDialog, id: String) -> Control:
	var node := part(dialog,id) as Control
	return node if node != null and node.is_visible_in_tree() else null
## Petite fenêtre « La discussion » (pastille d'étape) : valeur d'une tuile, puis fermeture par ✕.
func discussion_tile(dialog: ConfirmationDialog, index: int) -> String:
	var link := shown(dialog,"OffreEtapeLien") as Button
	check(link != null,"Pastille d'étape de la discussion cliquable")
	if link == null: return ""
	link.pressed.emit();await settle()
	var value := shown(dialog,"OffreFenetreDiscussionTuile_%dValeur" % index) as Label
	var text := value.text if value != null else ""
	var close := shown(dialog,"OffreFenetreDiscussionFermer") as Button
	check(value != null and close != null,"Petite fenêtre de la discussion ouverte, avec ✕")
	if close != null:
		close.pressed.emit();await settle()
	return text
## Envoi : page = deux temps (« Envoyer l'offre » puis « Confirmer » en place) ; fenêtre = validation.
func send(dialog: ConfirmationDialog) -> void:
	if offer_page() == null:
		dialog.confirmed.emit();return
	var valider := shown(dialog,"RecrutementPageValider") as Button
	check(valider != null and not valider.disabled,"Envoyer l'offre disponible")
	if valider == null: return
	valider.pressed.emit();await settle()
	var ok := app.find_child("ContractSignatureConfirmationOk",true,false) as Button
	check(ok != null and ok.is_visible_in_tree(),"Confirmation en place avant l'envoi")
	if ok != null: ok.pressed.emit()
func cancel(dialog: ConfirmationDialog) -> void:
	var page_cancel := shown(dialog,"RecrutementPageAnnuler") as Button
	if page_cancel != null: page_cancel.pressed.emit()
	elif is_instance_valid(dialog): dialog.canceled.emit()
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"Capture réelle 2560×1440")
	check(image.save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func low_offer(id: String, recruiting: bool) -> void:
	var dialog: ConfirmationDialog = await open(id,recruiting)
	var salary := part(dialog,"OfferSalary") as SpinBox
	var years := part(dialog,"OfferYears") as SpinBox
	salary.value=1000
	years.value=years.min_value
	await send(dialog)
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
	var page := offer_page()
	var salary := part(dialog,"OfferSalary") as SpinBox
	var years := part(dialog,"OfferYears") as SpinBox
	var viewport := Rect2(Vector2.ZERO,root.get_visible_rect().size)
	check(page != null and page.size.x>=1450 and viewport.grow(1).encloses(page.get_global_rect()) and salary.is_visible_in_tree() and years.is_visible_in_tree(),"Surface de négociation conçue pour1440p")
	check(salary.get_line_edit().get_theme_font_size("font_size")>=18 and salary.get_line_edit().get_theme_font_size("font_size")<=22,"Montant lisible en1440p")
	var page_cancel := shown(dialog,"RecrutementPageAnnuler") as Button
	check(page_cancel != null and page_cancel.has_focus(),"Annulation focalisée par défaut")
	var portrait := shown(dialog,"ContractPlayerPortrait") as TextureRect
	check(portrait != null and portrait.get_meta("player_id","")==id,"Portrait existant rattaché au bon joueur")
	check(await discussion_tile(dialog,0) == "1 / 3","Prochaine proposition1/3 explicite")
	salary=part(dialog,"OfferSalary");years=part(dialog,"OfferYears")
	salary.value=1000;years.value=years.min_value
	await settle()
	# Récapitulatif visuel figé (acquisition, ajout hebdomadaire) : premier temps de l'envoi, rien n'est transmis.
	var requests: int=app.bridge._next_id
	var valider := shown(dialog,"RecrutementPageValider") as Button
	check(valider != null and not valider.disabled,"Envoyer l'offre disponible")
	if valider != null:
		valider.pressed.emit();await settle()
	var recap := app.find_child("OffreRecap",true,false) as Control
	check(recap != null and recap.is_visible_in_tree() and app.find_child("ContractSignatureConfirmationOk",true,false) != null,"Récapitulatif acquisition et ajout hebdomadaire")
	var no := app.find_child("ContractSignatureConfirmationAnnuler",true,false) as Button
	if no != null:
		no.pressed.emit();await settle()
	check(app.bridge._next_id==requests and FileAccess.get_sha256(profile)==before and app.model.finance.cash==cash,"Saisie et lecture ne débitent ni écrivent")
	await capture("contrat-recrutement-initial-1440")
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true)
	await settle()
	check(offer_page() == null,"Échap ferme sans proposition")
	check(FileAccess.get_sha256(profile)==before,"Annuler n'envoie aucune proposition")
	if offer_page() != null: await cancel(dialog)
	await low_offer(id,true)
	check(app.model.meta.negotiation.status=="counter","Vraie contre-offre moteur")
	check(app.model.finance.cash==cash and app.model.squad.size()==count,"Contre-offre sans signature ni débit")
	await command("snapshot")
	var counter: Dictionary=current(id,true).negotiation.duplicate(true)
	var counter_disk := FileAccess.get_sha256(profile)
	dialog=await open(id,true)
	var counter_chip := shown(dialog,"OffreContreOffreTexte") as Label
	check(counter_chip != null and counter_chip.text.contains(Salary.amount(counter.salary)),"Contre-offre retrouvée après snapshot")
	check(int(counter.attempts)==1,"Numéro réellement enregistré")
	check(await discussion_tile(dialog,0) == "2 / 3","Prochaine tentative2/3")
	var reuse := shown(dialog,"OffreContreOffreLien") as Button
	check(reuse != null,"Contre-offre cliquable")
	if reuse != null:
		reuse.pressed.emit();await settle()
	salary=part(dialog,"OfferSalary");years=part(dialog,"OfferYears")
	check(Salary.input_weekly(salary)==roundi(counter.salary) and salary.value==snappedf(float(counter.salary)*Salary.factor(),100.0) and int(years.value)==int(counter.years),"Reprendre contre-offre copie conditions exactes")
	check(FileAccess.get_sha256(profile)==counter_disk and app.model.finance.cash==cash,"Reprendre conditions ne transmet pas l'offre")
	await capture("contrat-recrutement-contreoffre-1440")
	await cancel(dialog)
	check(offer_page() == null,"Annuler ferme l'écran d'offre")
	await low_offer(id,true);await low_offer(id,true)
	check(current(id,true).negotiation.status=="withdrawn","Retrait réel après troisième refus")
	app.management_ui.market.navigation_id = id
	app._navigate("Recrutement");await settle()
	var consult := app.find_child("OfferRecruitment",true,false) as Button
	check(consult != null and not consult.disabled and consult.text.to_lower().contains("consulter"),"Recrutement propose une consultation du retrait")
	if consult != null:
		consult.pressed.emit();await settle()
	dialog = app.find_child("ContractOffer",true,false)
	check(dialog != null and offer_page() != null,"La consultation réelle ouvre le dossier retiré")
	valider = shown(dialog,"RecrutementPageValider") as Button
	check(valider != null and valider.disabled,"Retrait interdit la confirmation dans l'interface")
	var step := shown(dialog,"OffreEtapeTexte") as Label
	check(step != null and step.text == "Discussion close","Dossier retiré : discussion close affichée")
	check(str(Negotiation.state_text(current(id,true)).action).contains("prochaine journée"),"Reprise le jour suivant expliquée")
	var withdrawn_disk := FileAccess.get_sha256(profile)
	if valider != null: valider.pressed.emit()
	dialog.confirmed.emit();await settle()
	check(FileAccess.get_sha256(profile)==withdrawn_disk and app.model.finance.cash==cash,"Confirmation forcée d'un dossier verrouillé ne commande rien")
	await capture("contrat-recrutement-retrait-1440")
	await cancel(dialog)
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
