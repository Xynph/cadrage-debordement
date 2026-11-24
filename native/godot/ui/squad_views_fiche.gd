extends "res://ui/squad_views_socle.gd"
## Fiche joueur de l'Effectif : lien de lecture, fiche, aperçu, ajustement, attributs et contextes (découpe de squad_views.gd, sans changement).

static func _profile_reading_link(app: Control, content: Control, player_id: String, caption: String, id: String) -> Button:
	var link := Button.new()
	link.name = id
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", G.T.box(Color.TRANSPARENT, 2, G.GOLD))
	# Lien de lecture nu : l'habillage sombre (legacy_style) n'en fait pas un bouton encadré, le nom reste un titre.
	link.set_meta("plain_link", true)
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.accessibility_name = "Consulter la fiche · " + caption
	link.tooltip_text = link.accessibility_name
	link.set_meta("entity_kind", "player")
	link.set_meta("entity_id", player_id)
	link.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"player", "id":player_id}))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return link

static func _profile(app:Control,parent:VBoxContainer,p:Dictionary) -> void:
	parent.get_parent().size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var list:=G.scroll(parent)
	# Let the tabs share the actual dossier height inside its scroll viewport.
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.get_parent().name="ProfileScroll"
	list.add_theme_constant_override("separation",4)
	var top:=G.h(8)
	list.add_child(top)
	var portrait := G.portrait(int(p.get("portraitIndex",0)),48,p)
	top.add_child(_profile_reading_link(app,portrait,str(p.id),str(p.name),"ProfileOpenPlayerPortrait"))
	var identity:=G.v(3)
	G.fill(identity)
	top.add_child(identity)
	var name:=G.label(p.name,18,G.INK)
	name.name="ProfilePlayerName"
	name.add_theme_font_size_override("font_size",18)
	name.add_theme_font_override("font",G.T.DISPLAY)
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(_profile_reading_link(app,name,str(p.id),str(p.name),"ProfileOpenPlayerName"))
	identity.add_child(G.wrap("%s · %s ans"%[position_label(str(p.pos)),G.n(p.age)],12))
	var facts: Dictionary = p.get("playerFacts", {})
	# Encre claire : la ligne d'identité est faite de libellés immersifs, que l'habillage sombre ne repeint pas
	# (l'encre du carnet, sombre, la rendait illisible sur le panneau sombre de l'Effectif).
	if not facts.is_empty(): identity.add_child(preload("res://ui/player_identity.gd").row(facts,15,G.Base.MUTED,app))
	list.add_child(G.separator())
	var tabs:=TabContainer.new()
	tabs.name="ProfileTabs"
	tabs.theme=G.T.paper()
	tabs.custom_minimum_size.y=200
	G.fill(tabs,true)
	list.add_child(tabs)
	var overview:=G.scroll(tabs)
	overview.get_parent().name="ProfileOverview"
	var attributes:=G.scroll(tabs)
	attributes.get_parent().name="ProfileAttributes"
	var contracts:=G.scroll(tabs)
	contracts.get_parent().name="ProfileContract"
	var references_tab:=G.scroll(tabs)
	references_tab.get_parent().name="ProfileReferences"
	for i in 4:tabs.set_tab_title(i,["Aperçu","Attributs","Contrat","Repères"][i])
	tabs.current_tab=clampi(int(app.management_ui.get("profile_tab",0)),0,3)
	tabs.tab_changed.connect(func(index:int):app.management_ui.profile_tab=index)
	var details := PlayerAttributes.detail(p,true)
	var actions:=_profile_overview(overview,p,app.model.get("clubLife",{}).get("coachNotebook",{}).get("entries",[]),app,tabs,not details.is_empty())
	var note:=G.button("MA NOTE SUR CE JOUEUR",func(): preload("res://ui/coach_notes_view.gd").open(app,str(p.id)))
	note.name="OpenPlayerCoachNote"
	G.fill(note)
	actions.add_child(note)
	_profile_attributes(attributes,p,details)
	contracts.add_child(G.wrap("Fin de contrat : "+G.contract_year(p.get("contractEnd")),13))
	contracts.add_child(G.wrap(G.salary(p.get("salary",0)),12,G.MUTED))
	var compared:bool=str(p.id) in app.management_ui.compare
	var compare:=G.button("RETIRER DE LA COMPARAISON" if compared else "AJOUTER À LA COMPARAISON",func():
		if str(p.id) in app.management_ui.compare:app.management_ui.compare.erase(str(p.id))
		elif app.management_ui.compare.size()<2:app.management_ui.compare.append(str(p.id))
		app._render())
	compare.name="CompareSelected"
	compare.disabled=not compared and app.management_ui.compare.size()>=2
	compare.tooltip_text="Deux joueurs maximum. Le dialogue Comparer permet de changer les deux dossiers."
	G.fill(compare)
	actions.add_child(compare)
	var renewal:Dictionary=p.get("renewal",{})
	var extend:=G.button("PROPOSER UNE PROLONGATION",func(): contract(app,p,false))
	extend.name="OfferRenewal"
	extend.disabled=not renewal.get("available",false) or not app._live().is_empty()
	var renewal_reason := str(renewal.get("reason", ""))
	extend.tooltip_text=renewal_reason if not renewal_reason.is_empty() else ("Le contrat ne permet pas de prolongation supplémentaire dans la limite de trois saisons." if not renewal.get("available",false) else "Une offre sera soumise au joueur avant toute signature.")
	if not renewal_reason.is_empty(): contracts.add_child(G.wrap(renewal_reason,13,G.ALERT))
	contracts.add_child(extend)
	# Vente (vente-joueurs.cjs) : état, raison d'un blocage en clair, proposer / retirer, offres reçues.
	var sale: Dictionary = p.get("sale",{}) if p.get("sale") is Dictionary else {}
	if not sale.is_empty():
		var sale_status := Sales.status(p)
		var blocked := str(sale.get("blocked",""))
		var planned: bool = sale.get("pending") is Dictionary
		var listed := bool(sale.get("listed",false))
		var line := G.wrap(sale_status if not sale_status.is_empty() else blocked if not blocked.is_empty() else "Valeur estimée %s." % G.euros(sale.get("value",0)),Sales.TEXTE,G.ALERT if sale_status.is_empty() and not blocked.is_empty() else G.INK)
		line.name = "ProfileSaleStatus"
		contracts.add_child(line)
		var sell:=G.button("RETIRER DU MARCHÉ" if listed else "PROPOSER AUX AUTRES CLUBS",func(): Sales.toggle(app,p))
		sell.name = "ProfileSaleToggle"
		sell.disabled = planned or not app._live().is_empty() or (not listed and not blocked.is_empty())
		if sell.disabled and not blocked.is_empty(): sell.tooltip_text = blocked
		contracts.add_child(sell)
		Sales.lisible(line)
		Sales.lisible(sell)
		if sale.get("offerId") is String or planned:
			var offers:=G.button(Sales.caption(app.model).to_upper()+" →",func(): Sales.open(app))
			offers.name = "ProfileSaleOffers"
			contracts.add_child(offers)
			Sales.lisible(offers)
	contracts.add_child(G.label("CHARGE INDIVIDUELLE",13,G.MUTED))
	var load_plan:=OptionButton.new()
	var modes:Array=["collective","repos","normal","intense"]
	for text in ["Auto","Récupération individuelle","Charge normale","Charge intense"]:load_plan.add_item(text)
	load_plan.name="PlayerLoad"
	load_plan.select(maxi(0,modes.find(p.get("loadPlan","collective"))))
	var load_reason := player_load_unavailable_reason(app)
	load_plan.disabled = not load_reason.is_empty()
	load_plan.item_selected.connect(func(index:int):app._command("set_player_load",{"playerId":p.id,"mode":modes[index]}))
	contracts.add_child(load_plan)
	if not load_reason.is_empty():
		load_plan.focus_mode = Control.FOCUS_NONE
		var load_hint := G.wrap(load_reason,13)
		load_hint.name = "PlayerLoadUnavailableReason"
		contracts.add_child(load_hint)
	references_tab.add_child(G.section("Repères de départ","Situation du joueur au début de la carrière"))
	if PlayerAttributes.is_generated(p):
		var generated := G.wrap(PlayerAttributes.GENERATED_TITLE + ".",13,G.MUTED)
		generated.name = "ProfileGeneratedPlayer"
		references_tab.add_child(generated)
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile")!=null else {}
	if not roster.is_empty():
		var position:Dictionary=roster.get("position",{})
		var status:Dictionary=roster.get("status",{})
		var initial:Dictionary=roster.get("contract",{})
		references_tab.add_child(G.wrap("Poste principal : %s"%position.get("primary",p.pos),13,G.MUTED))
		references_tab.add_child(G.wrap("Qualification initiale de jeu : %s"%", ".join(position.get("qualifications",[])),13,G.MUTED))
		references_tab.add_child(G.wrap("Statut initial : %s"%str(status.get("value","inconnu")).capitalize(),13,G.MUTED))
		if status.get("professionalFromSeason")!=null: references_tab.add_child(G.wrap("Référence initiale : passage professionnel prévu en saison %s."%G.season_label(status.professionalFromSeason),12,G.MUTED))
		references_tab.add_child(G.wrap("Échéance initiale : %s (fin saison %s)."%[G.n(initial.get("endYear",0)),G.season_label(initial.get("endSeason",0))],13,G.MUTED))
	references_tab.add_child(G.wrap(portrait.tooltip_text,12,G.MUTED))
	var academy := preload("res://ui/immersive08/academy_canvas.gd")
	var player_id := str(p.id)
	if not academy.professional_progress(app, player_id).is_empty():
		var follow_up := G.button("OUVRIR LE SUIVI INDIVIDUEL", func():
			academy.open_professional_progress(app, player_id, "ProfileDevelopmentAction"))
		follow_up.name = "ProfileDevelopmentAction"
		references_tab.add_child(follow_up)
	# The scroll owns these callbacks; weak captures also survive queued calls
	# after a different player replaces its retired dossier.
	var refs:Array[WeakRef]=[weakref(app),weakref(parent),weakref(list),weakref(tabs),weakref(overview)]
	var fit:=func():
		var nodes:Array=[]
		for ref:WeakRef in refs:
			var node:Variant=ref.get_ref()
			if node==null:return
			nodes.append(node)
		_fit_profile(nodes[0],nodes[1],nodes[2],nodes[3],nodes[4])
	var schedule:=func():fit.call_deferred()
	list.get_parent().resized.connect(schedule)
	app.resized.connect(schedule)
	list.tree_exiting.connect(func():
		var owner:Control=refs[0].get_ref()
		if owner!=null and owner.resized.is_connected(schedule):owner.resized.disconnect(schedule))
	overview.minimum_size_changed.connect(func():fit.call_deferred())
	fit.call_deferred()

static func _profile_overview(parent:VBoxContainer,p:Dictionary,notes:Array,app:Control,tabs:TabContainer,has_details:bool) -> HBoxContainer:
	var tiles:=G.h(6)
	tiles.name="ProfileOverviewTiles"
	G.fill(tiles)
	parent.add_child(tiles)
	var left:=G.v(6);G.fill(left);tiles.add_child(left)
	var right:=G.v(6);G.fill(right);tiles.add_child(right)
	var condition:=_profile_tile(left,"Condition","Situation et préparation")
	_profile_fact(condition,"ProfileConditionValue","Condition",G.n(p.get("condition",0))+"%")
	_profile_fact(condition,"ProfileLoadValue","Charge",G.n(p.get("physicalLoad",0)))
	_profile_fact(condition,"ProfileStatusValue","Sélection",str(p.get("status","—")))
	var plans:Dictionary={"collective":"Auto","repos":"Récupération","normal":"Normale","intense":"Intense"}
	_profile_fact(condition,"ProfilePlanValue","Charge prévue",str(plans.get(p.get("loadPlan","collective"),"—")))
	var contract_tile:=_profile_tile(right,"Contract","Contrat courant")
	var term:=G.wrap("Fin de contrat : "+G.contract_year(p.get("contractEnd")),12,G.INK)
	term.name="ProfileContractValue";contract_tile.add_child(term)
	_profile_fact(contract_tile,"ProfileSalaryValue",G.salary_period().capitalize(),G.salary_amount(p.get("salary",0)))
	var renewal:Dictionary=p.get("renewal",{})
	_profile_fact(contract_tile,"ProfileRenewalValue","Prolongation","Disponible" if renewal.get("available",false) else "Indisponible")
	if renewal.get("available",false):
		_profile_fact(contract_tile,"ProfileRenewalTerm","Durée possible","%s–%s saisons"%[G.n(renewal.get("minYears",1)),G.n(renewal.get("maxYears",1))])
	var season:=_profile_tile(left,"Season","Usage en saison")
	_profile_fact(season,"ProfileMinutesValue","Minutes",G.n(p.get("minutes",0)))
	_profile_fact(season,"ProfileAppearancesValue","Apparitions",G.n(p.get("appearances",0)))
	_profile_fact(season,"ProfileNumberValue","Numéro","—" if p.get("shirtNumber")==null else G.n(p.shirtNumber))
	var evaluation:=_profile_tile(right,"Evaluation","Évaluation")
	_profile_fact(evaluation,"ProfileRatingValue","Niveau général",G.rating_text(p,true))
	_profile_fact(evaluation,"ProfilePotentialValue","Potentiel",G.potential_text(p))
	var qualities := _profile_tile(left,"Attributes","Profil de jeu")
	if has_details:
		var detail_button := G.button("VOIR LES 36 ATTRIBUTS", func():
			tabs.current_tab = 1
			tabs.get_tab_bar().grab_focus())
		detail_button.name = "OpenCompactDetailedAttributes"
		qualities.add_child(detail_button)
	else:
		qualities.add_child(G.wrap("Détail des attributs indisponible.",12))
	var qualifications:=_profile_tile(right,"Qualifications","Postes")
	var roster:Dictionary=p.get("rosterProfile",{}) if p.get("rosterProfile") is Dictionary else {}
	var positions:Array=roster.get("position",{}).get("qualifications",[])
	var qualification_text:=G.wrap("Non renseignées" if positions.is_empty() else ", ".join(positions),12,G.INK)
	qualification_text.name="ProfileQualificationsValue"
	qualifications.add_child(qualification_text)
	qualifications.add_child(G.label("Détails dans Repères",11,G.MUTED))
	var note_home:=G.v(3);note_home.name="ProfileCompactNoteHome";qualifications.add_child(note_home)
	for entry:Dictionary in notes:
		if str(entry.get("target",""))!=str(p.id):continue
		var note_content:=G.v(3);note_content.name="ProfileNoteContent";note_home.add_child(note_content)
		note_content.add_child(G.separator())
		note_content.add_child(G.label("MA NOTE · %s / SEMAINE %s"%[G.season_label(entry.get("season",1)),G.n(int(entry.get("week",0))+1)],11,G.MUTED))
		var preview:=G.wrap(str(entry.get("text","")),12,G.INK)
		preview.name="ProfileNotePreview";preview.max_lines_visible=4
		preview.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.tooltip_text=preview.text;note_content.add_child(preview)
		break
	_profile_contexts(parent,p,app)
	var actions:=G.h(6)
	actions.name="ProfileOverviewActions"
	parent.add_child(actions)
	return actions

static func _fit_profile(app:Control,parent:VBoxContainer,list:VBoxContainer,tabs:TabContainer,overview:VBoxContainer) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():return
	if not is_instance_valid(list) or not list.is_inside_tree() or not parent.is_ancestor_of(list):return
	var desktop:bool=app.size.y>=1000
	overview.get_node("ProfileContexts").visible=desktop
	var peer_rows:VBoxContainer=overview.find_child("ProfileContextPeerRows",true,false)
	for i in peer_rows.get_child_count():peer_rows.get_child(i).visible=i<(5 if app.size.y>=1200 else 3)
	var content:=overview.find_child("ProfileNoteContent",true,false)
	if content!=null:
		var destination:=overview.find_child("ProfileStaffNoteSlot" if desktop else "ProfileCompactNoteHome",true,false)
		if content.get_parent()!=destination:content.reparent(destination,false)
	for label:Label in overview.find_children("ProfileContextText*","Label",true,false):label.max_lines_visible=3 if app.size.y>=1200 else 2
	tabs.custom_minimum_size.y=overview.get_combined_minimum_size().y+tabs.get_tab_bar().get_combined_minimum_size().y+16
	var budget:float=app.body_scroll.size.y-12.0 if is_instance_valid(app.body_scroll) else app.size.y-180.0
	if budget>0:list.get_parent().custom_minimum_size.y=minf(list.get_combined_minimum_size().y,budget)

static func _profile_attributes(parent: VBoxContainer, player: Dictionary, details: Dictionary) -> void:
	if details.is_empty():
		_profile_fact(parent, "ProfileDetailedFallbackRating", "Niveau général", G.rating_text(player,true))
		parent.add_child(G.wrap("Les attributs détaillés sont indisponibles pour ce dossier.",12))
		return
	parent.add_child(G.label("36 ATTRIBUTS · " + PlayerAttributes.SUBTITLE.to_upper(), 12, G.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	G.fill(grid)
	parent.add_child(grid)
	for index in PlayerAttributes.GROUPS.size():
		var group: Array = PlayerAttributes.GROUPS[index]
		var card := _profile_tile(grid, str(index), group[0], "ProfileDetailedGroup")
		for pair: Array in group[1]:
			var row := G.h(5)
			card.add_child(row)
			row.add_child(G.fill(G.wrap(pair[1], 12, G.MUTED)))
			var caption := G.label(PlayerAttributes.caption(details.get(pair[0])), 13, G.INK)
			caption.name = "PlayerDetailedAttribute_" + pair[0]
			caption.accessibility_name = "%s : %s sur 100" % [pair[1], caption.text]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			caption.custom_minimum_size.x = 37
			row.add_child(caption)

static func _profile_contexts(parent:VBoxContainer,p:Dictionary,app:Control) -> void:
	var grid:=GridContainer.new();grid.name="ProfileContexts";grid.columns=2;G.fill(grid)
	grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6)
	grid.visible=app.size.y>=1000;parent.add_child(grid)
	var competition:=_profile_tile(grid,"Competition","Concurrence au poste","ProfileContext")
	var cohort:=G.v(3);cohort.name="ProfileContextCohort";competition.add_child(cohort)
	var squad:Array=app.model.get("squad",[])
	cohort.add_child(G.label("Joueur / moyenne de l’effectif · %d joueurs"%squad.size(),11,G.MUTED))
	for field:Array in [["rating","Niveau",""],["condition","Condition","%"],["age","Âge"," ans"],["salary","Salaire "+G.salary_period(),""]]:
		var total:=0.0
		for member:Dictionary in squad:total+=float(member.get(field[0],0))
		var mean:float=total/squad.size() if not squad.is_empty() else NAN
		var average:String="—" if not is_finite(mean) else G.salary_amount(mean) if field[0]=="salary" else ("%.1f"%mean).replace(".",",")+field[2]
		var own:String=G.rating_text(p,true) if field[0]=="rating" else G.salary_amount(p.get(field[0],0)) if field[0]=="salary" else G.n(p.get(field[0],0))+field[2]
		_profile_fact(cohort,"ProfileMean_"+str(field[0]),field[1],own+" / "+average)
	var peers:=G.v(3);peers.name="ProfileContextPeers";competition.add_child(peers)
	peers.add_child(G.label("Même poste principal · "+str(p.pos)+" · niveau / condition",11,G.MUTED))
	var people:Array=squad.filter(func(person):return str(person.id)!=str(p.id) and person.pos==p.pos).slice(0,5)
	var rows:=G.v(3);rows.name="ProfileContextPeerRows";peers.add_child(rows)
	for i in people.size():
		var person:Dictionary=people[i];var row:=G.h(5);rows.add_child(row)
		var name:=G.label(person.name,12,G.INK);G.fill(name);name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;name.tooltip_text=person.name;row.add_child(name)
		row.add_child(G.label(G.rating_text(person,true)+" / "+G.n(person.condition)+"%",11,G.MUTED))
		var compare:=G.button("Comparer",func():app.management_ui.compare=[str(p.id),str(person.id)];comparison(app))
		compare.name="ProfilePeerCompare"+str(i);compare.set_meta("peer_id",str(person.id));compare.custom_minimum_size.y=24;row.add_child(compare)
	if people.is_empty():_context_text(peers,"Aucun autre coéquipier à afficher au même poste principal.","PeersEmpty")
	var development:=_profile_tile(grid,"Development","Développement","ProfileContext")
	var records:Array=app.model.get("decisions",{}).get("development",{}).get("professionals",[]).filter(func(person):return str(person.id)==str(p.id))
	if records.is_empty():_context_text(development,"Aucun suivi de développement disponible.","DevelopmentEmpty")
	else:
		var record:Dictionary=records[0];var data:Dictionary=record.get("development",{});var focus:="—"
		for option:Dictionary in data.get("options",[]):
			if option.id==data.get("focus"):focus=str(option.label)
		_profile_fact(development,"ProfileDevelopmentFocus","Orientation",focus)
		if data.get("seasonStart")!=null:
			_profile_fact(development,"ProfileDevelopmentStart","Début de saison",G.n(data.seasonStart))
			var delta:float=float(record.rating)-float(data.seasonStart)
			_profile_fact(development,"ProfileDevelopmentDelta","Évolution du niveau",("+" if delta>=0 else "")+G.n(delta))
		var history:Array=data.get("history",[])
		if history.is_empty():_context_text(development,"Premier bilan annuel à venir.","AnnualEmpty")
		for year:Dictionary in history.slice(maxi(0,history.size()-2)):_context_text(development,"%s · %s → %s · %s min / %s app."%[G.season_label(year.get("season","—")),G.n(year.get("start","—")),G.n(year.get("end","—")),G.n(year.get("minutes","—")),G.n(year.get("appearances","—"))],"Annual")
		var reason:=str(data.get("reason",""))
		if not reason.is_empty():_context_text(development,"Progression annuelle." if reason.begins_with("Évolution annuelle") else reason,"DevelopmentReason")
	var form:=_profile_tile(grid,"Form","Forme & prestations","ProfileContext")
	_profile_fact(form,"ProfileFormAvailability","Disponibilité","Blessure en cours" if float(p.get("injury",0))>0 else "Disponible")
	_profile_fact(form,"ProfileFormCondition","Condition / charge",G.n(p.get("condition",0))+"% / "+G.n(p.get("physicalLoad",0)))
	if int(p.get("appearances",0))==0 and float(p.get("minutes",0))==0:_context_text(form,"Première apparition à venir.","FirstAppearance")
	elif int(p.get("appearances",0))>0:_profile_fact(form,"ProfileMinutesPerAppearance","Minutes par apparition",("%.1f"%(float(p.get("minutes",0))/int(p.appearances))).replace(".",","))
	else:_profile_fact(form,"ProfileFormMinutes","Temps de jeu cumulé",G.n(p.get("minutes",0))+" min")
	var staff:=_profile_tile(grid,"Staff","Staff & carnet","ProfileContext")
	var advice:=str(app.model.get("decisions",{}).get("training",{}).get("advice",""))
	if not advice.is_empty():staff.add_child(G.label("Consigne collective",11,G.MUTED));_context_text(staff,advice.replace("Effectif & 23","Effectif"),"CollectiveAdvice")
	var reports:Array=app.model.get("decisions",{}).get("recruitment",{}).get("reports",[]).filter(func(report):return str(report.get("playerId",""))==str(p.id))
	if reports.is_empty():_context_text(staff,"Aucun avis individuel archivé.","IndividualEmpty")
	else:
		var assessment:Dictionary=reports[0].get("assessment",{})
		_context_text(staff,str(assessment.get("source","Rapport conservé")),"ReportDate")
		for opinion:String in assessment.get("estimates",[]).slice(0,1):_context_text(staff,opinion,"ReportOpinion")
	var slot:=G.v(3);slot.name="ProfileStaffNoteSlot";staff.add_child(slot)
	if parent.find_child("ProfileNoteContent",true,false)==null:_context_text(slot,"Aucune note personnelle pour ce joueur.","NoteEmpty")
