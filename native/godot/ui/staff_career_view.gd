extends RefCounted
const G = preload("res://ui/carnet_skin.gd")
const U = preload("res://ui/management_state.gd")
const Dialogs = preload("res://ui/decision_views.gd")
const PAGE_SIZE := 20

static func enable(app: Control, parent: Container, data: Dictionary) -> void:
	if not data.get("canEnable", false): return
	var button := G.button("ACTIVER LES CARRIÈRES DU STAFF", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true)}
		app.confirm("Activer les carrières du staff", "Cette sauvegarde utilisera désormais des âges de carrière, des contrats et des remplacements simulés. Les âges sans source sont estimés. Confirmer ?", func(): app._command("staff_career_enable", payload)))
	button.name = "EnableStaffCareer"
	parent.add_child(button)

static func build(app: Control, parent: Container, data: Dictionary) -> void:
	var overview := G.v(8)
	overview.name = "StaffCareerOverview"
	parent.add_child(overview)
	overview.add_child(G.wrap("Les contrats descriptifs restent gratuits. Les contrats rémunérés volontaires figurent dans le budget staff ; ils n’accordent aucun bonus de match." if app.model.get("clubLife", {}).get("staffEmployment", {}).get("enabled", false) else data.get("notice", ""), 13))
	_mentoring(app, overview)
	_employment(app, overview)
	var teams: Array = app.model.get("staff", {}).get("teams", data.get("teams", []))
	var chooser := OptionButton.new()
	chooser.name = "StaffClub"
	chooser.custom_minimum_size.y = 38
	if not teams.any(func(t: Dictionary): return int(t.id) == app.selected_staff_club): app.selected_staff_club = int(app.model.club.id)
	for team: Dictionary in teams:
		chooser.add_item(str(team.name)); chooser.set_item_metadata(chooser.item_count - 1, int(team.id))
		if int(team.id) == app.selected_staff_club: chooser.select(chooser.item_count - 1)
	chooser.item_selected.connect(func(index: int):
		app.selected_staff_club = int(chooser.get_item_metadata(index)); app._render())
	overview.add_child(chooser)
	var tabs := OptionButton.new()
	tabs.name = "StaffCareerTab"
	for title in ["Équipe du club", "Candidats disponibles", "Retraites et archives"]: tabs.add_item(title)
	overview.add_child(tabs)
	var search := LineEdit.new()
	search.name = "StaffSearch"
	search.placeholder_text = "Rechercher un nom ou un rôle…"
	search.custom_minimum_size.y = 38
	overview.add_child(search)
	var count := G.label("", 12, G.MUTED)
	count.name = "StaffCount"
	overview.add_child(count)
	var list := G.scroll(parent)
	list.get_parent().name = "StaffList"
	var paging := G.h(8)
	parent.add_child(paging)
	var local := {"page":0}
	var previous := G.button("← PRÉCÉDENT", func(): pass)
	var next := G.button("SUIVANT →", func(): pass)
	var page_label := G.label("", 12, G.MUTED)
	paging.add_child(previous); paging.add_child(page_label); paging.add_child(next)
	var redraw := func():
		for child in list.get_children(): list.remove_child(child); child.queue_free()
		var people: Array = []
		if tabs.selected == 0:
			for team: Dictionary in teams:
				if int(team.id) == app.selected_staff_club: people = team.members
		elif tabs.selected == 1: people = data.get("candidates", [])
		else: people = data.get("retired", [])
		var query := U.fold(search.text).strip_edges()
		var filtered := people.filter(func(p: Dictionary): return query.is_empty() or U.fold(str(p.name) + " " + str(p.get("roleLabel", p.role))).contains(query))
		local.page = clampi(int(local.page), 0, maxi(0, ceili(float(filtered.size()) / PAGE_SIZE) - 1))
		var start: int = int(local.page) * PAGE_SIZE
		for person: Dictionary in filtered.slice(start, start + PAGE_SIZE): _person(app, list, person, data, tabs.selected == 0 and app.selected_staff_club == int(app.model.club.id))
		count.text = "%d / %d membres · %s" % [filtered.size(), people.size(), ["staff en poste", "candidats recrutables", "archives conservées"][tabs.selected]]
		if filtered.is_empty(): list.add_child(G.wrap("Aucun profil dans cette sélection.", 15))
		previous.disabled = int(local.page) == 0
		next.disabled = start + PAGE_SIZE >= filtered.size()
		page_label.text = "Page %d / %d" % [int(local.page) + 1, maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))]
	previous.pressed.connect(func(): local.page -= 1; redraw.call())
	next.pressed.connect(func(): local.page += 1; redraw.call())
	tabs.item_selected.connect(func(_i: int): local.page = 0; redraw.call())
	search.text_changed.connect(func(_q: String): local.page = 0; redraw.call())
	redraw.call()
	parent.add_child(G.wrap("Les âges et contrats sont ceux de la carrière simulée. Les identités n’accordent aucun bonus de match. Les engagements rémunérés sont indiqués séparément ; les autres contrats restent descriptifs.", 12))

static func _person(app: Control, parent: Container, person: Dictionary, data: Dictionary, own: bool) -> void:
	var card := G.card(parent)
	var row := G.h(12)
	row.set_meta("staff_id", person.id)
	card.add_child(row)
	var appearance := person.duplicate(true)
	appearance.portraitRole = "staff"
	row.add_child(G.portrait(0, 68, appearance))
	var text := G.v(4)
	G.fill(text); row.add_child(text)
	text.add_child(G.wrap(person.name, 21, G.INK))
	text.add_child(G.wrap(person.get("roleLabel", data.get("roles", {}).get(person.get("role", ""), person.get("role", "Staff"))), 14, G.GOLD))
	var estimated := str(person.get("ageBasis", "")).contains("estimated") or str(person.get("ageBasis", "")).contains("simulated")
	text.add_child(G.wrap("%s ans · %s" % [G.n(person.get("age", 0)), "âge de carrière estimé" if estimated else "âge de carrière"], 12))
	if person.get("contractEnd") != null: text.add_child(G.wrap("Contrat jusqu’à la saison %s" % G.n(person.contractEnd), 12))
	if person.get("sourcePlayerId") != null: text.add_child(G.wrap("Ancien joueur · reconversion dans l’encadrement", 12, G.GOOD))
	var employment := _employment_person(app, str(person.id))
	if employment.get("employed", false): text.add_child(G.wrap("Contrat rémunéré · %s €/semaine · %s paies restantes · rupture %s €" % [G.n(employment.paidSalary), G.n(employment.remainingPayments), G.n(employment.severance)], 12, G.GOLD))
	var actions := G.h(6)
	card.add_child(actions)
	if own and not employment.is_empty() and not employment.get("employed", false) and app.model.get("clubLife", {}).get("staffEmployment", {}).get("enabled", false):
		var adopt := G.button("ADOPTER LE CONTRAT RÉMUNÉRÉ", func():
			var data_finance: Dictionary = app.model.clubLife.staffEmployment
			app.confirm("Rémunérer " + str(person.name), "%s €/semaine, engagement restant %s €. Les autres dépenses du club continuent. Confirmer l’adoption volontaire ?" % [G.n(employment.salary),G.n(employment.adoptionCommitment)], func(): app._command("staff_employment_adopt", {"confirmed":true,"context":data_finance.context.duplicate(true),"staffId":str(person.id),"salary":int(employment.salary)})))
		adopt.name = "StaffEmploymentAdopt"
		adopt.disabled = app.model.clubLife.staffEmployment.get("locked", true)
		actions.add_child(adopt)
	if person.get("canHire", false):
		var hire := G.button("RECRUTER →", func(): _contract(app, person, data, false))
		hire.name = "StaffHire"
		hire.set_meta("staff_id", person.id)
		actions.add_child(hire)
	if own and person.get("canRenew", false):
		var renew := G.button("PROLONGER", func(): _contract(app, person, data, true))
		renew.name = "StaffRenew"
		renew.set_meta("staff_id", person.id)
		actions.add_child(renew)
	if own and person.get("canRelease", false): _departure(app, actions, person, data, "staff_release", "LIBÉRER", "Le membre du staff redeviendra disponible au recrutement.")
	if own and person.get("canRetire", false): _departure(app, actions, person, data, "staff_retire", "RETRAITE", "Cette personne quittera définitivement le marché du staff.")

static func _contract(app: Control, person: Dictionary, data: Dictionary, renew: bool) -> void:
	var view := Dialogs.dialog(app, "Prolonger le staff" if renew else "Recruter le staff", "StaffContract", 700)
	var dialog: AcceptDialog = view[0]
	var list: VBoxContainer = view[1]
	list.add_child(G.section(person.name, person.get("roleLabel", person.get("role", "Staff"))))
	var employment: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	var context_key := JSON.stringify(data.get("context",{}))
	if app.management_ui.get("staff_contract_context","") != context_key:
		app.management_ui.staff_contract_context = context_key
		app.management_ui.staff_contract_drafts = {}
	var drafts: Dictionary = app.management_ui.get("staff_contract_drafts",{})
	var draft_key := str(person.id) + (":renew" if renew else ":hire")
	var draft: Dictionary = drafts.get(draft_key,{})
	if draft.get("status","") == "submitted" and not app.get("waiting"): draft.status = "refused"
	var paid: bool = employment.get("enabled", false)
	var person_finance := _employment_person(app, str(person.id))
	list.add_child(G.wrap("Salaire de jeu : %s €/semaine, sans prime de signature. Les autres charges du club continuent." % G.n(person_finance.get("salary",0)) if paid else "Contrat descriptif : salaires et prime 0 €. Le contrat fixe la durée de présence dans le club.", 14))
	var years := OptionButton.new()
	years.name = "StaffContractYears"
	for n in range(int(person.get("minYears", 1)), int(person.get("maxYears", data.get("maxYears", 3))) + 1):
		years.add_item("%d saison%s" % [n, "s" if n > 1 else ""]); years.set_item_metadata(years.item_count - 1, n)
	for index in years.item_count:
		if int(years.get_item_metadata(index)) == int(draft.get("years",-1)): years.select(index)
	list.add_child(years)
	if draft.get("status","") == "refused":
		var retry := G.wrap("Le contrat n’a pas été appliqué. Votre durée est conservée ; vérifiez le devis puis réessayez.",14,G.ALERT)
		retry.name = "StaffContractRetryNotice"
		list.add_child(retry)
	var remember := func():
		if years.selected < 0: return
		if not drafts.has(draft_key) and drafts.size() >= 32: drafts.erase(drafts.keys()[0])
		draft.years = int(years.get_item_metadata(years.selected))
		drafts[draft_key] = draft
		app.management_ui.staff_contract_drafts = drafts
	var commitment := G.wrap("", 14)
	commitment.name = "StaffEmploymentCommitment"
	list.add_child(commitment)
	var refresh_cost := func():
		if not paid or years.selected < 0: return
		var duration := int(years.get_item_metadata(years.selected))
		var payments := int(employment.get("remainingCurrentSeason",0)) + (duration - 1) * int(employment.get("weeksPerSeason",29))
		commitment.text = "Engagement projeté : %s € sur %d paies. Réserve 50 000 € et provision de huit paies du staff requises." % [G.n(payments * int(person_finance.get("salary",0))),payments]
	years.item_selected.connect(func(_i: int): remember.call(); refresh_cost.call())
	refresh_cost.call()
	var sign := G.button("CONFIRMER LE CONTRAT", func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"years":int(years.get_item_metadata(years.selected))}
		payload["staffId" if renew else "candidateId"] = str(person.id)
		if paid: payload.salary = int(person_finance.get("salary",0)); payload.context = employment.context.duplicate(true)
		remember.call()
		draft.status = "submitted"
		var command := ("staff_employment_renew" if renew else "staff_employment_hire") if paid else ("staff_renew" if renew else "staff_hire")
		var bridge: Variant = app.get("bridge")
		var expected_end := int(payload.context.season) + int(payload.years) - 1
		if not paid and app.model.get("meta",{}).get("phase","") == "ended": expected_end += 1
		dialog.queue_free()
		var sent: Variant = app._command(command,payload)
		if sent == true and bridge != null:
			_observe_contract(app,bridge,drafts,draft_key,draft,command,str(person.id),payload.context.duplicate(true),expected_end,paid,int(payload.get("salary",0)))
		else: draft.status = "refused", true)
	sign.name = "StaffContractConfirm"
	if draft.get("status","") == "refused": sign.text = "RÉESSAYER LE CONTRAT"
	sign.disabled = years.item_count == 0
	list.add_child(sign)
	dialog.popup_centered()

static func _departure(app: Control, parent: Container, person: Dictionary, data: Dictionary, command: String, title: String, detail: String) -> void:
	var button := G.button(title, func():
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(person.id)}
		var employment := _employment_person(app, str(person.id))
		var destination := command
		var message := detail
		if employment.get("employed",false):
			payload.severance = int(employment.severance)
			payload.context = app.model.clubLife.staffEmployment.context.duplicate(true)
			destination = "staff_employment_retire" if command == "staff_retire" else "staff_employment_release"
			message += " Indemnité de rupture : %s €, au plus deux paies." % G.n(employment.severance)
		app.confirm(title + " · " + str(person.name), message, func(): app._command(destination, payload)))
	button.name = "StaffRelease" if command == "staff_release" else "StaffRetire"
	button.set_meta("staff_id", person.id)
	parent.add_child(button)

# Shared by the classic Staff page and its immersive styling.
static func _mentoring(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffMentoring", {})
	if not data.get("available", false): return
	var open := G.button("MENTORAT DES JEUNES · %d LIEN(S) →" % data.get("assignments", []).size(), func(): _mentor_overview(app, data))
	open.name = "StaffMentoringOpen"
	parent.add_child(open)

static func _mentor_overview(app: Control, data: Dictionary) -> void:
	var view := Dialogs.dialog(app, "Transmettre aux jeunes", "StaffMentoringOverview", 700)
	var dialog: AcceptDialog = view[0]
	var parent: VBoxContainer = view[1]
	parent.add_child(G.wrap(data.get("notice", ""), 14))
	if not data.get("enabled", false):
		var activate := G.button("ACTIVER LE MENTORAT", func():
			dialog.queue_free()
			app.confirm("Activer le mentorat", "Cette carrière conservera les affectations et les séances réellement encadrées. Aucun point de croissance ni salaire supplémentaire.", func(): app._command("staff_mentoring_enable", {"confirmed":true,"context":data.context.duplicate(true)})))
		activate.name = "StaffMentoringEnable"
		activate.disabled = not data.get("canEnable", false)
		parent.add_child(activate)
	else:
		if int(data.get("dormantAssignments", 0)) > 0: parent.add_child(G.wrap("%d lien(s) devenus indisponibles seront libérés lors de votre prochaine affectation." % int(data.dormantAssignments), 12))
		for assignment: Dictionary in data.get("assignments", []):
			parent.add_child(G.wrap("%s → %s · %s · %d/8 séances · %d %% ciblés%s" % [assignment.staffName, assignment.playerName, assignment.focus, int(assignment.sessions), roundi(float(assignment.targetShare) * 100), " · " + str(assignment.reason) if not assignment.get("active", false) else ""], 13))
			var remove := G.button("LIBÉRER LE MENTOR", func():
				dialog.queue_free(); app._command("staff_mentor_remove", {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(assignment.staffId)}))
			remove.name = "StaffMentorRemove"
			remove.disabled = data.get("locked", true)
			parent.add_child(remove)
		var assign := G.button("CHOISIR UN MENTOR ET UN JEUNE →", func(): _mentor_dialog(app, data))
		assign.name = "StaffMentorAssign"
		assign.disabled = data.get("locked", true) or data.get("mentors", []).is_empty() or data.get("players", []).is_empty()
		parent.add_child(assign)
		if data.get("players", []).is_empty(): parent.add_child(G.wrap("Aucun jeune de 15 à 24 ans avec progression spécialisée disponible. Les courbes annuelles restent inchangées.", 12))
	dialog.popup_centered()

static func _mentor_dialog(app: Control, data: Dictionary) -> void:
	var view := Dialogs.dialog(app, "Un mentor, un jeune", "StaffMentoring", 700)
	var dialog: AcceptDialog = view[0]
	var list: VBoxContainer = view[1]
	list.add_child(G.wrap("Le mentor consacre son suivi à un seul jeune. La qualité ciblée prend une part de son expérience générale. Un plan individuel explicite garde priorité. Changer de qualité remet à zéro ses XP ciblés partiels, selon la règle existante.", 14))
	var mentors := OptionButton.new()
	mentors.name = "StaffMentorChoice"
	for member: Dictionary in data.get("mentors", []):
		mentors.add_item("%s · %d/8 séances observées%s" % [member.name, int(member.observedSessions), " · ancien joueur" if member.get("converted", false) else ""])
		mentors.set_item_metadata(mentors.item_count - 1, member.id)
	list.add_child(mentors)
	var pupils := OptionButton.new()
	pupils.name = "StaffMentorPupil"
	for player: Dictionary in data.get("players", []):
		pupils.add_item(str(player.name) + " · " + str(player.pos))
		pupils.set_item_metadata(pupils.item_count - 1, player.id)
	list.add_child(pupils)
	var focus := OptionButton.new()
	focus.name = "StaffMentorFocus"
	list.add_child(focus)
	var refresh := func():
		focus.clear()
		if pupils.selected < 0: return
		var selected: Dictionary = data.players[pupils.selected]
		for quality: Dictionary in selected.get("focusOptions", []):
			focus.add_item(str(quality.label)); focus.set_item_metadata(focus.item_count - 1, quality.key)
	pupils.item_selected.connect(func(_index: int): refresh.call())
	refresh.call()
	var confirm := G.button("CONFIRMER L’AFFECTATION", func():
		if mentors.selected < 0 or pupils.selected < 0 or focus.selected < 0: return
		var payload := {"confirmed":true,"context":data.context.duplicate(true),"staffId":str(mentors.get_item_metadata(mentors.selected)),"playerId":str(pupils.get_item_metadata(pupils.selected)),"focus":str(focus.get_item_metadata(focus.selected))}
		dialog.queue_free(); app._command("staff_mentor_assign", payload), true)
	confirm.name = "StaffMentorConfirm"
	list.add_child(confirm)
	dialog.popup_centered()

static func _employment_person(app: Control, staff_id: String) -> Dictionary:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	for person: Dictionary in data.get("own", []) + data.get("candidates", []):
		if str(person.id) == staff_id: return person
	return {}

static func _employment(app: Control, parent: Container) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("staffEmployment", {})
	if not data.get("available", false): return
	if not data.get("enabled", false):
		var activate := G.button("ACTIVER LES CONTRATS RÉMUNÉRÉS",func(): app.confirm("Rémunération nominative du staff", "Activation gratuite, sans adoption des contrats en poste. Les futurs recrutements de ce club seront rémunérés selon le barème visible avant signature.",func():app._command("staff_employment_enable",{"confirmed":true,"context":data.context.duplicate(true)})))
		activate.name = "StaffEmploymentEnable"; activate.disabled = not data.get("canEnable", false)
		parent.add_child(activate)
	else:
		var budget := G.button("BUDGET STAFF · %s €/SEMAINE →" % G.n(data.get("weeklyWages",0)),func():
			var view := Dialogs.dialog(app,"Engagements du staff","StaffEmploymentBudget",700)
			var dialog: AcceptDialog = view[0]
			var list: VBoxContainer = view[1]
			list.add_child(G.wrap(str(data.get("notice","")),14))
			list.add_child(G.wrap("Trésorerie : %s € · engagements staff : %s € · solde après ces seuls engagements : %s €. Autres recettes et dépenses exclues." % [G.n(data.cash),G.n(data.knownCommitment),G.n(data.forecastAfterKnownStaff)],15))
			dialog.popup_centered())
		budget.name = "StaffEmploymentBudgetOpen"
		parent.add_child(budget)

# One in-flight observer per app, with paired cleanup on model OR transport error.
static func _forget_contract_observer(app: Control) -> void:
	if not app.has_meta("staff_contract_observer"): return
	var observer: Dictionary = app.get_meta("staff_contract_observer")
	app.remove_meta("staff_contract_observer")
	var bridge: Variant = observer.bridge.get_ref()
	if bridge == null: return
	if bridge.is_connected("model_changed",observer.model): bridge.disconnect("model_changed",observer.model)
	if bridge.is_connected("command_failed",observer.error): bridge.disconnect("command_failed",observer.error)

static func _contract_ack(model: Dictionary,command: String,staff_id: String,context: Dictionary,end_season: int,paid: bool,salary: int) -> bool:
	var action: Dictionary = model.get("meta",{}).get("staffEmploymentAction" if paid else "staffCareerAction",{})
	if str(action.get("command","")) != command: return false
	if not paid and str(action.get("staffId","")) != staff_id: return false
	var career: Dictionary = model.get("clubLife",{}).get("staffCareer",{})
	var data: Dictionary = model.get("clubLife",{}).get("staffEmployment",{}) if paid else career
	if data.get("context",{}) != context: return false
	var witnessed := false
	for team: Dictionary in career.get("teams",[]):
		if int(team.id) != int(context.club): continue
		for person: Dictionary in team.get("members",[]):
			if str(person.id) == staff_id and int(person.get("clubId",-1)) == int(context.club) and int(person.get("contractEnd",-1)) == end_season: witnessed = true
	if not witnessed: return false
	if paid:
		for person: Dictionary in data.get("own",[]):
			if str(person.id) == staff_id and person.get("employed",false) and int(person.get("paidSalary",-1)) == salary and int(person.get("contractEnd",-1)) == end_season: return true
		return false
	return true

static func _observe_contract(app: Control,bridge: Object,drafts: Dictionary,key: String,draft: Dictionary,command: String,staff_id: String,context: Dictionary,end_season: int,paid: bool,salary: int) -> void:
	_forget_contract_observer(app)
	var app_ref: WeakRef = weakref(app)
	var bridge_ref: WeakRef = weakref(bridge)
	var token := RefCounted.new()
	var on_model := func(model: Dictionary):
		var host: Control = app_ref.get_ref()
		var source: Object = bridge_ref.get_ref()
		if host == null or source == null or host.get_meta("staff_contract_observer",{}).get("token") != token: return
		var accepted: bool = source.get("last_response_ok") == true and _contract_ack(model,command,staff_id,context,end_season,paid,salary)
		_forget_contract_observer(host)
		if accepted: drafts.erase(key)
		else: draft.status = "refused"
	var on_error := func(_message: String):
		var host: Control = app_ref.get_ref()
		if host == null or host.get_meta("staff_contract_observer",{}).get("token") != token: return
		_forget_contract_observer(host)
		draft.status = "refused"
	app.set_meta("staff_contract_observer",{"bridge":bridge_ref,"model":on_model,"error":on_error,"token":token})
	bridge.connect("model_changed",on_model)
	bridge.connect("command_failed",on_error)
