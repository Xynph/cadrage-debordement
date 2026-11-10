extends AcceptDialog
## Objectifs et changements réellement observés dans le club courant.
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const PAGE_SIZE := 20
const ATTRIBUTES := {"scrum":"Mêlée","lineout":"Touche","tackle":"Plaquage","speed":"Vitesse","pass":"Passe","kick":"Jeu au pied","goal":"But","power":"Puissance","stamina":"Endurance","mental":"Mental","discipline":"Discipline"}
const REASONS := {"enable":"Référence initiale","plan":"Objectif révisé","trainWeek":"Séance","recordDevelopmentMatch":"Match","rollDevelopmentYear":"Bilan annuel","advanceSeason":"Nouvelle saison","promoteYouth":"Passage professionnel","managerMobilityOnSeasonStart":"Changement de club"}
var app: Control
var state: Dictionary
var body: VBoxContainer
var scroll: ScrollContainer
var list: VBoxContainer
var counter: Label
var previous: Button
var next: Button
var page_label: Label

static func entry(owner_app: Control,parent: Container) -> Button:
	var button := G.button("SUIVRE LES JEUNES →",func(): open(owner_app))
	button.name = "OpenYouthDevelopment"; parent.add_child(button); return button

static func open(owner_app: Control) -> AcceptDialog:
	owner_app._clear_dialogs()
	var view: AcceptDialog = load("res://ui/youth_development_view.gd").new()
	view.app = owner_app; view._build(); return view

func _data() -> Dictionary:
	return app.model.get("clubLife",{}).get("youthDevelopment",{})

func _build() -> void:
	name = "YouthDevelopment"; title = "Accompagner les jeunes"; get_ok_button().text = "FERMER"
	app._prepare_dialog(self,360)
	_sync_drafts()
	scroll = ScrollContainer.new(); scroll.name = "YouthDevelopmentScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true; add_child(scroll)
	body = G.v(10); G.fill(body,true); scroll.add_child(body)
	body.add_child(G.section("Des objectifs, puis des faits", "Académie et jeunes professionnels · club courant"))
	body.add_child(G.wrap("Les plans répartissent le futur budget XP existant, sans gain immédiat ajouté. Pour les profils à progression annuelle, ils servent uniquement d’objectifs de suivi : ils ne changent ni leur courbe, ni leur exposition. Blessures, fatigue et minutes réellement jouées restent déterminantes.",14))
	var data := _data()
	if not str(data.get("reason","")).is_empty(): body.add_child(G.wrap(str(data.reason),13))
	if data.get("canEnable",false):
		var enable := G.button("DÉMARRER LE SUIVI DES JEUNES",_enable); enable.name = "YouthDevelopmentEnable"; enable.disabled = app.waiting; body.add_child(enable)
	var filters := HFlowContainer.new(); body.add_child(filters)
	var search := LineEdit.new(); search.name = "YouthDevelopmentSearch"; search.placeholder_text = "Nom ou poste…"; search.text = str(state.query); search.custom_minimum_size = Vector2(230,36); filters.add_child(search)
	search.text_changed.connect(func(value: String): state.query = value; state.page = 0; _redraw())
	var stage := OptionButton.new(); stage.name = "YouthDevelopmentStage"
	for label in ["Tous les jeunes","Académie","Jeunes professionnels"]: stage.add_item(label)
	stage.select(int(state.stage)); filters.add_child(stage)
	stage.item_selected.connect(func(index: int): state.stage = index; state.page = 0; _redraw())
	var review_filter := CheckButton.new(); review_filter.name = "YouthReviewFilter"; review_filter.text = "PARCOURS À REVOIR"; review_filter.button_pressed = bool(state.get("review",false)); filters.add_child(review_filter)
	review_filter.toggled.connect(func(value: bool): state.review = value; state.page = 0; _redraw())
	counter = G.wrap("",13); counter.name = "YouthDevelopmentCount"; body.add_child(counter)
	list = G.v(8); list.name = "YouthDevelopmentRows"; body.add_child(list)
	var paging := G.h(8); body.add_child(paging)
	previous = G.button("← PRÉCÉDENT",func(): state.page -= 1; _redraw()); previous.name = "YouthDevelopmentPrevious"; paging.add_child(previous)
	page_label = G.label("",12); paging.add_child(page_label)
	next = G.button("SUIVANT →",func(): state.page += 1; _redraw()); next.name = "YouthDevelopmentNext"; paging.add_child(next)
	confirmed.connect(queue_free); canceled.connect(queue_free); app.add_child(self)
	app.bridge.model_changed.connect(func(_model: Dictionary):
		if not app.bridge.last_response_ok: return
		if app.last_command in ["new_career","import","recover_profile","restore_checkpoint"]: queue_free()
		else: _redraw())
	app.get_window().size_changed.connect(_fit)
	_redraw(); _fit()
	get_tree().process_frame.connect(_initial_focus.bind(search),CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _initial_focus(search: LineEdit) -> void:
	if not is_visible(): return
	search.grab_focus()
	scroll.scroll_vertical = 0

func _fit() -> void:
	var host: Vector2i = app.get_window().size
	var width := mini(1060,host.x-48)
	body.custom_minimum_size.x = width-48; scroll.custom_minimum_size.y = mini(600,host.y-160)
	Dialogs.show_centered(self,Vector2i(width,mini(780,host.y-80)))

# Only UI memory: U.sync discards it on new career/import, including equal IDs.
# A week/season/club change also makes an unconfirmed choice obsolete.
func _sync_drafts() -> void:
	if not app.management_ui.get("youth_development") is Dictionary:
		app.management_ui.youth_development = {"page":0,"query":"","stage":0,"review":false}
	state = app.management_ui.youth_development
	var context: Dictionary = _data().get("context",{}).duplicate(true)
	context.career = app.management_ui.get("career","")
	if state.get("draft_context",{}) != context:
		var previous: Dictionary = state.get("drafts",{})
		state.draft_notice = "Les choix locaux ont été réinitialisés : la semaine, la saison ou le club a changé. Relisez le contexte avant de confirmer." if not previous.is_empty() else ""
		state.drafts = {}
		state.draft_context = context
	if not state.get("drafts") is Dictionary: state.drafts = {}

func _remember_draft(player_id: String, plan: String, focus: Variant) -> void:
	_sync_drafts()
	state.drafts[player_id] = {"plan":plan,"focus":focus}

func _redraw() -> void:
	_sync_drafts()
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var query := U.fold(str(state.query)).strip_edges()
	var source: Array = _data().get("players",[])
	var people := source.filter(func(p: Dictionary): return (query.is_empty() or U.fold(str(p.name)+" "+str(p.pos)).contains(query)) and (int(state.stage)==0 or str(p.stage)==["","academy","professional"][int(state.stage)]))
	if state.get("review",false): people = people.filter(func(p: Dictionary): return str(p.get("review",{}).get("status","")) in ["review","context"])
	state.page = clampi(int(state.page),0,maxi(0,ceili(float(people.size())/PAGE_SIZE)-1))
	var start: int = int(state.page)*PAGE_SIZE
	for person: Dictionary in people.slice(start,start+PAGE_SIZE): _person(person)
	if people.is_empty(): list.add_child(G.wrap("Aucun jeune dans cette sélection.",14))
	counter.text = "%d jeunes · %s" % [people.size(),"suivi actif" if _data().get("enabled",false) else "suivi à démarrer"]
	if not str(state.get("draft_notice","")).is_empty(): counter.text += "\n"+str(state.draft_notice)
	if _data().get("locked",false): counter.text += "\nObjectifs verrouillés : révisez-les avant la séance, hors match et pendant la saison régulière."
	previous.disabled = start==0; next.disabled = start+PAGE_SIZE>=people.size()
	page_label.text = "%d / %d" % [int(state.page)+1,maxi(1,ceili(float(people.size())/PAGE_SIZE))]

func _person(person: Dictionary) -> void:
	var card := G.card(list); card.name = "YouthDevelopmentCard"; card.set_meta("player_id",str(person.id))
	var row := G.h(10); card.add_child(row); row.add_child(G.portrait(0,64,person))
	var info := G.v(4); G.fill(info); row.add_child(info)
	info.add_child(G.wrap("%s · %s · %s ans" % [str(person.name),str(person.pos),G.n(person.age)],20,G.INK))
	var annual: bool = str(person.get("model",""))=="annual-v11"
	info.add_child(G.wrap("Progression annuelle : les qualités évoluent au bilan annuel selon l’exposition réelle. La spécialisation d’XP n’est pas disponible pour ce profil." if annual else "Progression par XP : le plan répartit le budget existant, sans XP supplémentaire.",13))
	info.add_child(G.wrap("Niveau général %s · potentiel au poste %s · condition %s %% · fatigue %s / 100 · blessure %s semaine(s)" % [G.n(person.get("rating",0)),G.n(person.get("potential",0)),G.n(person.get("condition",0)),G.n(person.get("fatigue",0)),G.n(person.get("injury",0))],13))
	var current: Dictionary = person.get("current",{})
	var minutes := "Minutes de carrière : %s" % G.n(person.get("careerMinutes",current.get("careerMinutes",0)))
	if not annual: minutes += " · XP générale %s · XP ciblée %s" % [_decimal(current.get("generalXP",0)),_decimal(current.get("focusedXP",0))]
	info.add_child(G.wrap(minutes,12))
	var baseline: Variant = person.get("baseline")
	var deltas: Variant = person.get("deltas")
	if not baseline is Dictionary or not deltas is Dictionary:
		info.add_child(G.wrap("Pas encore de référence suivie : aucun gain passé n’est attribué à cet objectif.",13))
	else:
		info.add_child(G.wrap("Depuis S%s · semaine %s : niveau %s · minutes %s" % [G.n(baseline.get("season","—")),G.n(baseline.get("week","—")),_signed(deltas.get("rating",0)),_signed(deltas.get("minutes",0))],13))
		var changes: Array[String] = []
		for key in ATTRIBUTES:
			var delta: float = float(deltas.get("attributes",{}).get(key,0))
			if not is_zero_approx(delta): changes.append(str(ATTRIBUTES[key])+" "+_signed(delta))
		info.add_child(G.wrap(" · ".join(changes) if not changes.is_empty() else "Aucun changement de qualité observé depuis cette référence.",12))
	_review(info,person)
	for observation: Dictionary in person.get("observations",[]):
		info.add_child(G.wrap("S%s · semaine %s · %s · niveau %s · minutes %s" % [G.n(observation.get("season","—")),G.n(observation.get("week","—")),REASONS.get(str(observation.get("reason","")),"Observation"),_signed(observation.get("ratingDelta",0)),_signed(observation.get("minutesDelta",0))],12))
	for step: Dictionary in person.get("nextSteps",[]): info.add_child(G.wrap(("✓ " if step.get("done",false) else "À préparer · ")+str(step.get("label",""))+" · "+str(step.get("detail","")),12))
	if not str(person.get("planReason","")).is_empty(): info.add_child(G.wrap(str(person.planReason),13,G.ALERT))
	var draft: Dictionary = state.drafts.get(str(person.id),{})
	var options := HFlowContainer.new(); card.add_child(options)
	var plan := OptionButton.new(); plan.name = "YouthPlan"; plan.set_meta("player_id",str(person.id)); options.add_child(plan)
	var available: Array = person.get("availablePlans",[])
	for entry: Dictionary in _data().get("plans",[]):
		if str(entry.key) not in available: continue
		plan.add_item(str(entry.label)); plan.set_item_metadata(plan.item_count-1,str(entry.key)); plan.set_item_tooltip(plan.item_count-1,"Objectif de suivi uniquement : aucune modification de la progression annuelle ou du temps de jeu." if annual else str(entry.get("description","")))
		if entry.key==draft.get("plan",person.get("plan")): plan.select(plan.item_count-1)
	var focus := OptionButton.new(); focus.name = "YouthFocus"; options.add_child(focus)
	var selected_focus: Variant = draft.get("focus",person.get("focus"))
	if selected_focus == null: selected_focus = person.get("defaultFocus")
	for entry: Dictionary in person.get("focusOptions",[]):
		focus.add_item(str(entry.label)); focus.set_item_metadata(focus.item_count-1,str(entry.key))
		if entry.key==selected_focus: focus.select(focus.item_count-1)
	var description := G.wrap("",12); card.add_child(description)
	var update_focus := func():
		var chosen: String = str(plan.get_item_metadata(plan.selected)) if plan.item_count>0 else ""
		focus.visible = chosen in ["specialist","integration"] and focus.item_count>0
		for entry: Dictionary in _data().get("plans",[]):
			if entry.key==chosen:
				description.text = "Objectif de suivi uniquement : aucune modification de la courbe annuelle ou du temps de jeu." if annual else str(entry.get("description",""))
				if not annual: description.text += " · répartition du budget : %d %% générale / %d %% ciblée" % [roundi(float(entry.get("generalShare",0))*100),roundi(float(entry.get("targetShare",0))*100)]
	var remember := func():
		if plan.item_count==0: return
		var key := str(plan.get_item_metadata(plan.selected))
		var selected: Variant = str(focus.get_item_metadata(focus.selected)) if key in ["specialist","integration"] and focus.item_count>0 else null
		_remember_draft(str(person.id),key,selected)
	plan.item_selected.connect(func(_index: int): update_focus.call(); remember.call())
	focus.item_selected.connect(func(_index: int): remember.call())
	update_focus.call()
	var save := G.button("CONFIRMER CET OBJECTIF",func():
		var key := str(plan.get_item_metadata(plan.selected))
		var target: Variant = str(focus.get_item_metadata(focus.selected)) if key in ["specialist","integration"] and focus.item_count>0 else null
		_confirm_plan(person,key,target))
	save.name = "YouthPlanSave"; save.set_meta("player_id",str(person.id)); save.disabled = app.waiting or not person.get("canPlan",false) or plan.item_count==0; options.add_child(save)
	plan.disabled = save.disabled; focus.disabled = save.disabled
	var suggested: Variant = person.get("review",{}).get("recommendation",{}).get("suggestedPlan")
	if suggested != null and str(suggested) in available and str(suggested) != str(person.get("plan","")):
		var prepare := G.button("PRÉPARER LA RÉORIENTATION CONSEILLÉE",func():
			for i in plan.item_count:
				if str(plan.get_item_metadata(i))==str(suggested): plan.select(i); update_focus.call(); remember.call(); save.grab_focus())
		prepare.name = "YouthReviewPrepare"; prepare.disabled = save.disabled; card.add_child(prepare)
		card.add_child(G.wrap("Préparer ne modifie rien : relisez la répartition, puis confirmez l’objectif choisi.",12))

func _review(parent: Container,person: Dictionary) -> void:
	var review: Dictionary = person.get("review",{})
	if review.is_empty(): return
	var label := G.wrap(str(review.get("label","Bilan intermédiaire")),16,G.INK); label.name = "YouthReviewLabel"; parent.add_child(label)
	var objective: Variant = review.get("objective")
	if objective is Dictionary:
		var line := "Repère historique · "+str(objective.get("label","Objectif"))
		if objective.get("value") != null and objective.get("target") != null: line += " · %s / %s %s depuis la référence" % [_decimal(objective.value),_decimal(objective.target),str(objective.get("unit",""))]
		if objective.get("achieved",false): line += " · repère atteint"
		parent.add_child(G.wrap(line,13))
	parent.add_child(G.wrap(str(review.get("basis","")),12))
	var recent: Dictionary = review.get("recent",{})
	var recent_line := G.wrap("",13)
	recent_line.name = "YouthRecentReview"
	if recent.get("available",false):
		recent_line.text = "Période récente observée · S%s semaine %s → semaine %s · %s semaines · %s minutes · niveau %s. Fenêtre visée : quatre semaines, bornes réelles conservées." % [G.n(recent.from.season),G.n(recent.from.week),G.n(recent.to.week),G.n(recent.weeks),_signed(recent.minutesDelta),_signed(recent.ratingDelta)]
	else:
		var reasons := {"untracked":"Démarrer le suivi.","insufficient":"Attendre deux mesures comparables de cette saison et de ce stade.","club":"Référence provenant d’un autre club.","counter":"Continuité du compteur à vérifier.","context":"Continuité du parcours à vérifier."}
		recent_line.text = "Bilan récent indisponible · "+str(reasons.get(str(recent.get("reason","insufficient")),"Observations comparables insuffisantes."))
	parent.add_child(recent_line)
	if recent.get("available",false):
		var changes: Array[String] = []
		for key in ATTRIBUTES:
			var amount: float = float(recent.get("attributeDeltas",{}).get(key,0))
			if not is_zero_approx(amount): changes.append(str(ATTRIBUTES[key])+" "+_signed(amount))
		parent.add_child(G.wrap("Qualités sur cette période · "+(" · ".join(changes) if not changes.is_empty() else "aucun changement observé"),12))

	var short: Variant = review.get("shortTermObjective")
	if short is Dictionary:
		var line := "Décision S%s semaine %s · %s · " % [G.n(short.from.season),G.n(short.from.week),str(short.label)]
		line += "réexamen au bilan annuel S%s" % G.n(short.due.season) if short.due.week == null else "réexamen S%s semaine %s" % [G.n(short.due.season),G.n(short.due.week)]
		if short.get("value") != null and short.get("target") != null: line += " · %s / %s %s depuis cette décision" % [_decimal(short.value),_decimal(short.target),str(short.unit)]
		elif short.get("coverage")=="unavailable": line += " · mesure depuis cette décision indisponible : son observation n’est plus conservée ou son contexte a changé"
		if short.get("expired",false): line += " · échéance de réexamen atteinte"
		line += ". Repère consultatif, sans gain ajouté ni effet causal attribué au plan."
		var dated := G.wrap(line,13)
		dated.name = "YouthShortTermObjective"
		parent.add_child(dated)

	var advice: Dictionary = review.get("recommendation",{})
	var detail := G.wrap(str(advice.get("label",""))+" · "+str(advice.get("detail","")),13); detail.name = "YouthReviewAdvice"; parent.add_child(detail)
	var destination: Variant = advice.get("destination")
	if destination != null:
		var navigate := G.button("EXAMINER LE PARCOURS →" if str(destination)=="Centre" else "EXAMINER L’EFFECTIF →",func(): app._clear_dialogs(); app.selected_player = str(person.id); app._navigate(str(destination)))
		navigate.name = "YouthReviewNavigate"; parent.add_child(navigate)
	if str(advice.get("key","")) == "promotion":
		var promote := G.button("EXAMINER LE PREMIER CONTRAT DE CE JOUEUR →",func():
			app._clear_dialogs()
			app.selected_player = str(person.id)
			app._navigate("Formation")
			preload("res://ui/development_view.gd").open_player(app,str(person.id)))
		promote.name = "YouthReviewPromotion"
		parent.add_child(promote)
	elif str(advice.get("key","")) == "loan":
		var loan := G.button("EXAMINER LE PRÊT DE CE JOUEUR →",func():
			app._clear_dialogs()
			app.selected_player = str(person.id)
			app._navigate("Centre")
			preload("res://ui/academy_pathways_view.gd").open_professional(app,str(person.id)))
		loan.name = "YouthReviewLoan"
		parent.add_child(loan)


func _enable() -> void:
	var payload := {"confirmed":true,"context":_data().get("context",{}).duplicate(true)}
	app.confirm("Démarrer le suivi des jeunes","Une référence sera conservée à partir d’aujourd’hui. Aucun gain immédiat ni observation passée inventée. Confirmer ?",Callable(app,"_command").bind("youth_development_enable",payload))

func _confirm_plan(person: Dictionary,plan: String,focus: Variant) -> void:
	_remember_draft(str(person.id),plan,focus)
	var payload := {"confirmed":true,"context":_data().get("context",{}).duplicate(true),"playerId":str(person.id),"plan":plan,"focus":focus}
	var detail := "Cet objectif sert uniquement au suivi : il ne change ni la courbe annuelle, ni le temps de jeu." if str(person.get("model",""))=="annual-v11" else "Le plan répartit le futur budget XP existant, sans bonus immédiat."
	if str(person.get("model",""))!="annual-v11":
		detail += " Si la qualité ciblée change, l’XP ciblée partielle non dépensée est remise à zéro ; les qualités déjà gagnées sont conservées."
	app.confirm("Adapter l’objectif de "+str(person.name),detail+" Confirmer date une nouvelle période de suivi à partir d’aujourd’hui, même si le plan reste identique. Les minutes, la fatigue et les blessures restent prises en compte. Confirmer ?",Callable(app,"_command").bind("youth_development_plan",payload))

static func _decimal(value: Variant) -> String: return "%.2f" % float(value)
static func _signed(value: Variant) -> String: return ("+" if float(value)>0 else "")+_decimal(value)
