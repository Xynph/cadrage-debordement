extends SceneTree
const Salary = preload("res://ui/salary_display.gd")
const Prefs = preload("res://ui/user_preferences.gd")
const G = preload("res://ui/game_skin.gd")
const Rooms = preload("res://qa_runner.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var output := OS.get_environment("CD_SALARY_LIVE_OUTPUT")
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL: ",message)
func settle() -> void:
	# Let deferred controls/layout settle, then observe the actual rendered frame.
	# Fixed twelve-frame waits multiplied the software-rendering cost per dialog.
	for frame in 2:await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
func wait_response() -> void:
	var deadline := Time.get_ticks_msec()+45000
	while app.waiting and Time.get_ticks_msec()<deadline:await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok,"Réponse moteur : "+str(app.last_error))
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==Vector2i(2560,1440),"Capture2560×1440")
	check(image.save_png(output.path_join(name+".png"))==OK,"Capture "+name)
func choose_unit(unit: String, screenshot: bool=false) -> void:
	app.settings();await settle()
	var dialog := app.find_child("PreferencesDialog",true,false) as AcceptDialog
	var tabs := dialog.find_child("PreferencesTabs",true,false) as TabContainer
	tabs.current_tab=2;await settle()
	var choice := dialog.find_child("PreferencesSalaryPeriod",true,false) as OptionButton
	check(choice != null,"Réglage salaires présent")
	var index := Salary.PERIODS.find(unit)
	choice.select(index);choice.item_selected.emit(index);await settle()
	check(app.user_preferences.data.salary_period==unit and Salary.period==unit,"Unité appliquée : "+unit)
	if screenshot:await capture("parametres-salaires-1440")
	dialog.confirmed.emit();await settle()
func texts(node: Node) -> Array[String]:
	var result: Array[String]=[]
	for child in node.find_children("*","Label",true,false):result.append(child.text)
	return result
func current_target(id: String) -> Dictionary:
	for player: Dictionary in app.model.market:
		if str(player.id)==id:return player
	return {}
func check_salary_input(input: SpinBox,unit: String) -> void:
	var number := input.get_line_edit().text.trim_suffix(input.suffix).strip_edges().replace(" ","")
	check(number.is_valid_int(),"Vrai formulaire sans décimales "+unit+" : "+input.get_line_edit().text)
	check(is_equal_approx(input.value,snappedf(input.value,100.0)),"Vrai formulaire en centaines "+unit)
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	var deadline := Time.get_ticks_msec()+45000
	while app.model.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.model.is_empty(),"Vraie application prête")
	app.timer.stop()
	app._command("new_career",{"mode":"common","club":0});await wait_response()
	if not await Rooms.settle_club_meetings(app,self,check):await app._close(1);return
	var person: Dictionary=app.model.squad[0]
	app.selected_player=str(person.id);app._navigate("Effectif");await settle()
	var profile := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(profile)
	for unit in Salary.PERIODS:
		await choose_unit(unit,unit=="monthly")
		check(app.route=="Effectif","Changer unité garde écran et joueur")
		check(Salary.format(person.salary) in texts(app.root_content),"Fiche actualisée sans navigation : "+unit)
		var reopened := Prefs.new()
		check(reopened.load_profile(str(app.model.meta.dataDir)) and reopened.data.salary_period==unit,"Choix réellement relu sur disque : "+unit)
		check(FileAccess.get_sha256(profile)==before,"Préférence ne modifie pas carrière : "+unit)
		var comparison_holder := VBoxContainer.new()
		var a: Dictionary=app.model.market[0]
		var b: Dictionary=app.model.market[-1]
		preload("res://ui/immersive08/recruitment_comparison.gd")._row(comparison_holder,"Salaire","salary",[a,b],{}," €")
		var row := comparison_holder.get_child(0)
		check(row.get_child(1).text==Salary.amount(a.salary),"Comparateur montant salarial dans unité "+unit)
		var delta := float(b.salary)-float(a.salary)
		check(row.get_child(3).text==("+" if delta>0 else "")+Salary.amount(delta),"Écart salarial comparable sans précision perdue : "+unit)
		comparison_holder.free()
		await capture("salaire-joueur-"+unit+"-1440")
	var target: Dictionary={}
	for candidate: Dictionary in app.model.market:
		if candidate.available and candidate.salary>1000 and candidate.salary<10000:target=candidate;break
	check(not target.is_empty(),"Piste réelle pour vérifier commande")
	if target.is_empty():await app._close(1);return
	var id := str(target.id)
	for unit in Salary.PERIODS:
		await choose_unit(unit)
		app.SquadViews.contract(app,target,true);await settle()
		var offer := app.find_child("ContractOffer",true,false) as ConfirmationDialog
		var wage := offer.find_child("OfferSalary",true,false) as SpinBox
		check_salary_input(wage,unit)
		check(Salary.input_weekly(wage)==int(target.salary),"Formulaire inchangé conserve source exacte "+unit)
		await capture("offre-salaire-"+unit+"-1440")
		offer.canceled.emit();await settle()
		check(FileAccess.get_sha256(profile)==before,"Annuler formulaire ne modifie pas carrière "+unit)
	await choose_unit("monthly")
	app.SquadViews.contract(app,target,true);await settle()
	var dialog := app.find_child("ContractOffer",true,false) as ConfirmationDialog
	var input := dialog.find_child("OfferSalary",true,false) as SpinBox
	check(Salary.input_weekly(input)==int(target.salary),"Montant moteur exact sans édition en mensuel")
	check(input.suffix.contains("mois"),"Saisie dans unité choisie")
	check_salary_input(input,"monthly commande réelle")
	Salary.set_input_weekly(input,1000)
	check_salary_input(input,"monthly contre-offre")
	var years := dialog.find_child("OfferYears",true,false) as SpinBox;years.value=years.min_value
	var cash: Variant=app.model.finance.cash
	var roster_count: int=app.model.squad.size()
	check(FileAccess.get_sha256(profile)==before,"Modifier saisie mensuelle sans débit ni écriture")
	dialog.confirmed.emit();await wait_response()
	check(app.model.meta.negotiation.status=="counter" and app.model.finance.cash==cash,"Offre mensuelle basse devient vraie contre-offre sans débit")
	app._command("export");await wait_response()
	var exported: Dictionary=JSON.parse_string(app.model.meta.exportText)
	var found := false
	for talk: Dictionary in exported.state.economy.talks.values():
		if talk.id==id and talk.kind=="recruit":found=int(talk.salary)==1000
	check(found,"Commande persistée conserve1000euros HEBDO, pas4333euros")
	await choose_unit("annual")
	app.SquadViews.contract(app,current_target(id),true);await settle()
	dialog=app.find_child("ContractOffer",true,false)
	input=dialog.find_child("OfferSalary",true,false)
	Salary.set_input_weekly(input,100000)
	check_salary_input(input,"annual commande réelle")
	check(is_equal_approx(input.value,5200000),"100000hebdo affichés5200000annuels")
	years=dialog.find_child("OfferYears",true,false);years.value=years.min_value
	var fee: Variant=current_target(id).fee
	dialog.confirmed.emit();await wait_response()
	check(app.model.meta.negotiation.status=="signed","Signature autorisée depuis saisie annuelle")
	check(app.model.finance.cash==cash-fee,"Prime unique inchangée par unité")
	var signed_salary: Variant=null
	for player: Dictionary in app.model.squad:
		if str(player.id)==id:signed_salary=player.salary
	check(signed_salary==100000 and app.model.squad.size()==roster_count+1,"Moteur signe100000hebdo, pas5200000")
	var result := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"resolution":[2560,1440]},"  "));result.close()
	print("SALAIRES GLOBAUX : %d contrôles ; %d échecs" % [checks,failures.size()])
	await app._close(0 if failures.is_empty() else 1)
