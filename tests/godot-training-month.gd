extends SceneTree
## Entraînement › Mois (22/11/2026) : grille du mois à trois créneaux par jour, petite fenêtre d'un jour (séances et
## effets), semaine type (quatre cartes, choix appliqué par le moteur), copier / coller, liens venus du Calendrier et de
## la date de la barre haute ; l'onglet Semaine reste en place.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Mois = preload("res://ui/immersive08/training_mois.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_worker() -> void:
	var until:=Time.get_ticks_msec()+30000
	while app.waiting and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id,payload),"Commande acceptée · "+id)
	await wait_worker()
	check(not app.waiting and app.bridge.last_response_ok,"Worker réel · "+id)
func found(id: String) -> Control: return app.find_child(id,true,false) as Control
func page() -> Control: return found("ImmersiveTraining")
func tab() -> int: return int(app.management_ui.get("immersive_training",{}).get("tab",-1))
func press(id: String) -> bool:
	var b:=found(id) as Button
	check(b!=null and b.is_visible_in_tree() and not b.disabled,"Bouton présent et actif · "+id)
	if b==null or b.disabled: return false
	b.pressed.emit(); await settle()
	return true
func escape() -> void:
	var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; root.push_input(key,true)
	key=key.duplicate(); key.pressed=false; root.push_input(key,true)
	await settle()
func planning() -> Dictionary: return app.model.get("calendarPlanning",{})
## Première semaine de la grille qui a un match encore modifiable (pastille de semaine type + « Coller » possible).
func semaines_modifiables() -> Array:
	var sortie: Array=[]
	for i in 6:
		var pastille:=found("TrainingMonthModel%dLien" % i)
		if pastille!=null and found("TrainingMonthWeek%d" % i).modulate.a>.9: sortie.append(i)
	return sortie
func run() -> void:
	root.size=Vector2i(2560,1440)
	app=load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	var until:=Time.get_ticks_msec()+30000
	while app.model.is_empty() and Time.get_ticks_msec()<until: await process_frame
	app.timer.stop()
	await command("new_career",{"mode":"world-champ","club":29})
	await ContextualFlow.settle_club_meetings(app,self,check)
	app.coach.close()
	# Date de la barre haute -> onglet Mois, au mois du jour.
	await press("ImmersiveCalendarDate")
	check(page()!=null and tab()==Mois.ONGLET,"Date de la barre haute -> Entraînement › Mois")
	check(found("TrainingMonthGrid")!=null,"Grille du mois présente")
	check(found("TrainingTab5")!=null and found("TrainingTab0")!=null,"Onglets Semaine et Mois présents")
	# Mois suivants jusqu'à trouver des matchs modifiables (l'avant-saison n'en a pas).
	var mois_vus:=0
	while semaines_modifiables().size()<2 and mois_vus<6:
		await press("TrainingMonthNext"); mois_vus+=1
	var semaines:=semaines_modifiables()
	check(semaines.size()>=2,"Deux semaines avec match à venir dans la grille")
	if semaines.size()<2:
		finish(); return
	# Jours : sept par semaine, trois créneaux au plus ; un jour à séances ouvre sa petite fenêtre (séances + effets).
	var jour_seances:=""
	for s: Variant in planning().get("sessions",[]):
		if s is Dictionary and found("TrainingMonthDayOpen_"+str(s.date))!=null:
			jour_seances=str(s.date); break
	check(not jour_seances.is_empty(),"Un jour à séances visible")
	for d in app.find_children("TrainingMonthDay_*","Panel",true,false):
		var creneaux:=d.find_children("TrainingMonthSlot_*","Panel",false,false).size()
		check(creneaux<=3,"Trois créneaux au plus · "+str(d.name))
	if await press("TrainingMonthDayOpen_"+jour_seances):
		check(found("TrainingMonthDayWindow")!=null,"Clic sur un jour -> petite fenêtre du jour")
		check(found("TrainingMonthDaySession0")!=null or found("TrainingMonthDaySession1")!=null,"Séances du jour en cartes")
		check(app.find_children("TrainingMonthDayEffect*","Panel",true,false).size()>0,"Effets de chaque séance affichés")
		await escape()
		check(found("TrainingMonthDayWindow")==null and tab()==Mois.ONGLET,"Échap ferme la petite fenêtre du jour")
	# Effets de la semaine dans la colonne de gauche.
	check(app.find_children("TrainingMonthWeekEffect*","Panel",true,false).size()>0,"Effets de semaine affichés")
	# Semaine type : quatre cartes avec leurs effets ; la carte « Matchs rapprochés » est appliquée par le moteur.
	var i: int=semaines[0]
	var fixture_id:=""
	await press("TrainingMonthModel%dLien" % i)
	check(found("TrainingMonthModelWindow")!=null,"Pastille de semaine type -> petite fenêtre des modèles")
	for id in ["standard","away","congested","break"]:
		check(found("TrainingMonthModelCard_"+id)!=null,"Carte de modèle · "+id)
		check(app.find_children("TrainingMonthModelEffect_%s_*" % id,"Panel",true,false).size()>0,"Effets du modèle · "+id)
	var avant: Dictionary=planning().get("programmeByFixture",{}).duplicate()
	var cible:="congested"
	if found("TrainingMonthModelPick_congested")==null: cible="standard"
	await press("TrainingMonthModelPick_"+cible)
	await wait_worker()
	var apres: Dictionary=planning().get("programmeByFixture",{})
	for k in apres.keys():
		if apres[k]==cible and avant.get(k)!=cible: fixture_id=str(k)
	check(not fixture_id.is_empty(),"Semaine type choisie appliquée par le moteur (%s)" % cible)
	check(tab()==Mois.ONGLET,"Retour sur l'onglet Mois après le choix")
	# Copier cette semaine, coller sur la suivante.
	semaines=semaines_modifiables()
	await press("TrainingMonthCopy%d" % i)
	check(str(page().state.get("modele_copie",""))==cible,"Copier retient la semaine type")
	check(found("TrainingMonthCopied")!=null,"Pastille « Copiée » dans la barre")
	var autre:=-1
	for k in semaines:
		var coller:=found("TrainingMonthPaste%d" % k) as Button
		if k!=i and coller!=null and not coller.disabled: autre=k; break
	check(autre>=0,"Une autre semaine accepte le collage")
	if autre>=0:
		var comptes:=0
		for v in planning().get("programmeByFixture",{}).values(): if v==cible: comptes+=1
		await press("TrainingMonthPaste%d" % autre)
		await wait_worker()
		var ensuite:=0
		for v in planning().get("programmeByFixture",{}).values(): if v==cible: ensuite+=1
		check(ensuite==comptes+1,"Coller applique la semaine type copiée à une autre semaine")
	# Barre de charge -> onglet Semaine, intact.
	var charge:=app.find_children("TrainingMonthCharge*","Button",true,false)
	check(charge.size()>0,"Barre de charge cliquable")
	if charge.size()>0:
		(charge[0] as Button).pressed.emit(); await settle()
		check(tab()==0 and found("TrainingWeekTable")!=null,"Charge -> onglet Semaine (tableau des volets)")
	# Calendrier (Compétitions) : liste des rencontres, plus de grille ; « Programme du mois » -> Mois.
	app._navigate("Calendrier"); await settle()
	check(found("MonthDay_"+jour_seances)==null,"Plus de grille mensuelle dans le Calendrier")
	if await press("CalendarShowMonth"):
		check(page()!=null and tab()==Mois.ONGLET,"Calendrier › Programme du mois -> Entraînement › Mois")
	# Lien d'une séance (rendez-vous, message) : le mois de ce jour, fenêtre du jour ouverte.
	var seance: Dictionary={}
	for s: Variant in planning().get("sessions",[]):
		if s is Dictionary and str(s.get("date",""))>=str(planning().get("today","")): seance=s; break
	if not seance.is_empty():
		check(app.Immersive.Competition.open_target(app,"session",seance.id),"Lien de séance accepté")
		await settle()
		check(tab()==Mois.ONGLET and found("TrainingMonthDayWindow")!=null,"Lien de séance -> Mois + petite fenêtre du jour")
	finish()
func finish() -> void:
	print("TRAINING MONTH : ",checks," contrôles ; ",failures.size()," échec(s)")
	if app!=null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
