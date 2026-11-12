extends AcceptDialog
## An intentions workbench. Only manager_plan_* commands leave this window.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const POSITIONS = ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne", "Troisième ligne", "Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière", "Talonneur remplaçant", "Pilier remplaçant", "Pilier remplaçant", "Remplaçant", "Remplaçant", "Remplaçant", "Remplaçant", "Remplaçant"]
const METRICS = ["lineouts", "scrums", "penalties"]
const METRIC_LABELS = {"lineouts":"touches conservées (%)", "scrums":"mêlées conservées (%)", "penalties":"pénalités concédées par match"}
var app: Control
var tabs: TabBar
var content: VBoxContainer
var data: Dictionary
var fixture_index := 0
var slot_index := 0
var horizon_index := 0
var kind_index := 0
var candidate_id := ""
var search_text := ""
var show_horizon_players := false
var candidate_rows: Array = []
var player_choice: OptionButton
var salary: SpinBox
var fee: SpinBox
var years: SpinBox

static func open(application: Control) -> AcceptDialog:
	var panel = load("res://ui/manager_planning.gd").new()
	panel.app = application
	application.add_child(panel)
	panel._build()
	panel.popup_centered_clamped(Vector2i(1180, 760), 0.9)
	return panel

func _build() -> void:
	name = "ManagerPlanning"
	title = "Préparer la suite du club"
	min_size = Vector2i(560, 360)
	ok_button_text = "Fermer"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	add_child(page)
	tabs = TabBar.new()
	tabs.name = "PlannerTabs"
	for label in ["Trois rencontres", "Effectif futur", "Objectif tactique"]: tabs.add_tab(label)
	page.add_child(tabs)
	tabs.tab_changed.connect(func(_index: int): _refresh())
	var scroll := ScrollContainer.new()
	scroll.name = "PlannerScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	app.bridge.model_changed.connect(_model_changed)
	_refresh()

func _model_changed(_model: Dictionary) -> void:
	_refresh.call_deferred()

func _text(value: String, color := Color("e7e4dd")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label

func _button(caption: String, callback: Callable, id: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.name = id
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _select(id: String, labels: Array, selected: int, callback: Callable) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = id
	choice.clip_text = true
	choice.custom_minimum_size.y = 34
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label in labels: choice.add_item(str(label))
	if choice.item_count: choice.select(clampi(selected, 0, choice.item_count - 1))
	choice.item_selected.connect(callback)
	content.add_child(choice)
	return choice

func _number(id: String, caption: String, value: float, maximum: float, step: float = 1, minimum: float = 0) -> SpinBox:
	_text(caption)
	var input := SpinBox.new()
	input.name = id
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = value
	input.custom_minimum_size.y = 34
	content.add_child(input)
	return input

func _send(command: String, payload: Dictionary) -> void:
	payload["context"] = data.get("context", {}).duplicate(true)
	app._command(command, payload)

func _refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	data = app.model.get("managerPlanning", {})
	_text(str(data.get("notice", "Aucune préparation disponible.")), C.GOLD)
	if not data.get("available", false): return
	if not data.get("editable", false): _text("Consultation seule pendant le match ou à la clôture de saison.", C.GOLD)
	match tabs.current_tab:
		0: _fixtures()
		1: _scenario()
		2: _goal()

func _fixtures() -> void:
	var fixtures: Array = data.get("fixtures", [])
	if fixtures.is_empty(): _text("Aucune rencontre future publiée.")
	else:
		fixture_index = clampi(fixture_index, 0, fixtures.size() - 1)
		_select("PlannerFixture", fixtures.map(func(f: Dictionary): return "%s · %s – %s" % [f.get("date", "Date non renseignée"), f.home.name, f.away.name]), fixture_index, func(index: int):
			fixture_index = index
			_refresh())
		var fixture: Dictionary = fixtures[fixture_index]
		_text("%d / 23 intentions renseignées · la condition affichée est celle d’aujourd’hui." % fixture.filled)
		for warning: String in fixture.warnings: _text(warning, C.GOLD)
		for promise: Dictionary in fixture.get("promises", []):
			_text("%s · engagement : %s min, %s min jouées · %s rencontre(s) déjà comptée(s) · %s" % [promise.name, str(promise.get("targetMinutes", "cible non renseignée")), str(promise.promise.get("minutes", "inconnues")), str(promise.promise.get("completed", "inconnues")), "prévu sur cette feuille" if promise.planned else "absent de cette intention"])
		_select("PlannerSlot", POSITIONS, slot_index, func(index: int):
			slot_index = index
			_refresh())
		var eligible: Array = data.get("players", []).filter(func(p: Dictionary): return p.get("eligible", []).any(func(slot: Variant): return int(slot) == slot_index) and (p.id not in fixture.slots or fixture.slots[slot_index] == p.id))
		var labels: Array = ["Aucune intention"]
		var selected := 0
		for player: Dictionary in eligible:
			labels.append("%s · %s · condition actuelle %s" % [player.name, player.pos, str(player.get("condition", "inconnue"))])
			if fixture.slots[slot_index] == player.id: selected = labels.size() - 1
		var choice := _select("PlannerPlayer", labels, selected, func(_index: int): pass)
		var save := _button("Enregistrer l’intention à ce poste", func():
			var id: Variant = null if choice.selected == 0 else eligible[choice.selected - 1].id
			_send("manager_plan_lineup", {"fixtureId":fixture.id,"slot":slot_index,"playerId":id}), "PlannerSaveLineup")
		save.disabled = not data.get("editable", false)
		for index in fixture.slots.size():
			var rows: Array = data.players.filter(func(p: Dictionary): return p.id == fixture.slots[index])
			_text("%d · %s : %s" % [index + 1, POSITIONS[index], "À préparer" if fixture.slots[index] == null else "Joueur absent" if rows.is_empty() else rows[0].name])
		_button("Effacer cette composition provisoire", func(): _send("manager_plan_lineup", {"fixtureId":fixture.id,"slot":null,"playerId":null}), "PlannerClearLineup").disabled = not data.get("editable", false)
	for stale: Dictionary in data.get("staleLineups", []):
		_button("Retirer l’ancienne intention « %s »" % stale.fixtureId, func(): _send("manager_plan_lineup", {"fixtureId":stale.fixtureId,"slot":null,"playerId":null}), "PlannerRemoveStale").disabled = not data.get("editable", false)

func _sources() -> Array:
	if kind_index == 0:
		var incoming: Array = app.model.get("clubLife", {}).get("managerPlanning", {}).get("loans", []).filter(func(loan: Dictionary): return loan.get("to") == app.model.club.id and loan.get("from") != app.model.club.id).map(func(loan: Dictionary): return loan.id)
		return app.model.get("squad", []).filter(func(player: Dictionary): return player.id not in incoming)
	if kind_index == 2: return data.get("academy", [])
	var rows: Array = app.model.get("market", []).duplicate()
	rows.append_array(app.model.get("clubLife", {}).get("interclubMarket", {}).get("candidates", []))
	var seen := {}
	var unique: Array = []
	for player: Dictionary in rows:
		if seen.has(player.id): continue
		seen[player.id] = true
		unique.append(player)
	return unique

func _scenario() -> void:
	var scenario: Dictionary = data.scenario
	_text("Hypothèses : coût initial %s · masse salariale hebdomadaire %s" % [G.euros(scenario.upFront), "inconnue" if scenario.weeklyWages == null else G.euros(scenario.weeklyWages)])
	_text("Engagement des contrats envisagés : %s" % ("périodes de paie non renseignées" if scenario.totalCommitment == null else G.euros(scenario.totalCommitment)))
	_text("Ces montants ne prouvent ni la disponibilité ni l’accord du joueur. Les autres frais et dates contractuelles manquantes restent à confirmer. Seuls les retours de prêts renseignés sont inclus.", C.GOLD)
	_select("PlannerHorizon", data.horizons.map(func(h: Dictionary): return h.label), horizon_index, func(index: int):
		horizon_index = index
		_refresh())
	var horizon: Dictionary = data.horizons[horizon_index]
	_text("%s : %d joueurs dans l’hypothèse ; %d échéances inconnues." % [horizon.label, horizon.players.size(), horizon.unknownContracts])
	_text("%d contrat(s) à échéance cette saison · salaires hebdomadaires projetés : %s" % [horizon.get("expiring", 0), "inconnus" if horizon.get("weeklyWages") == null else G.euros(horizon.weeklyWages)])
	_text(" · ".join(horizon.positions.map(func(position: Dictionary): return "%s : %d" % [position.pos, position.count])))
	_button("Masquer les joueurs projetés" if show_horizon_players else "Voir les joueurs projetés et leurs échéances", func():
		show_horizon_players = not show_horizon_players
		_refresh(), "PlannerHorizonPlayers")
	if show_horizon_players:
		for player: Dictionary in horizon.players:
			_text("%s · %s · %s €/semaine · contrat %s%s" % [player.name, player.pos, str(player.get("salary", "inconnu")), "échéance inconnue" if player.get("contractEnd") == null else "S" + str(player.contractEnd), " · retour de prêt" if player.get("loanReturn", false) else ""])
	for operation: Dictionary in scenario.operations:
		_text("%s · %s · %d €/semaine · %d saison(s)%s" % [{"renew":"Prolongation","recruit":"Recrutement","promote":"Promotion"}.get(operation.kind, operation.kind), operation.player.name if operation.player is Dictionary else operation.playerId, operation.salary, operation.years, " · source absente, exclue des totaux" if not operation.available else ""])
		_button("Retirer cette hypothèse", func():
			var ops: Array = data.settings.get("scenario", []).filter(func(o: Dictionary): return o.playerId != operation.playerId)
			_send("manager_plan_scenario", {"operations":ops}), "PlannerRemoveScenario").disabled = not data.get("editable", false)
	_select("PlannerOperationKind", ["Prolonger", "Recruter", "Promouvoir"], kind_index, func(index: int):
		kind_index = index
		candidate_id = ""
		_refresh())
	var search := LineEdit.new()
	search.name = "PlannerCandidateSearch"
	search.placeholder_text = "Chercher un joueur par nom ou poste"
	search.text = search_text
	content.add_child(search)
	search.text_changed.connect(func(text: String):
		search_text = text
		_update_candidates())
	player_choice = _select("PlannerCandidate", [], 0, func(index: int):
		if index < candidate_rows.size():
			candidate_id = str(candidate_rows[index].id)
			_quote_candidate())
	salary = _number("PlannerSalary", "Hypothèse salariale · € par semaine", 1000, 1000000, 100)
	fee = _number("PlannerFee", "Hypothèse de coût initial · indemnité et primes, en €", 0, 1000000000, 1000)
	years = _number("PlannerYears", "Durée envisagée · saisons", 1, 3, 1, 1)
	_update_candidates()
	var add := _button("Ajouter ou remplacer cette hypothèse", func():
		if candidate_id.is_empty(): return
		var ops: Array = data.settings.get("scenario", []).filter(func(o: Dictionary): return o.playerId != candidate_id)
		ops = ops.duplicate(true)
		ops.append({"kind":["renew","recruit","promote"][kind_index],"playerId":candidate_id,"years":int(years.value),"salary":int(salary.value),"fee":int(fee.value)})
		_send("manager_plan_scenario", {"operations":ops}), "PlannerScenarioAdd")
	add.disabled = not data.get("editable", false)

func _update_candidates() -> void:
	candidate_rows = _sources().filter(func(p: Dictionary): return search_text.is_empty() or (str(p.get("name", "")) + " " + str(p.get("pos", ""))).to_lower().contains(search_text.to_lower())).slice(0, 60)
	player_choice.clear()
	var selected := 0
	for index in candidate_rows.size():
		var player: Dictionary = candidate_rows[index]
		player_choice.add_item("%s · %s" % [player.name, player.pos])
		if player.id == candidate_id: selected = index
	if candidate_rows.is_empty(): candidate_id = ""
	else:
		player_choice.select(selected)
		candidate_id = str(candidate_rows[selected].id)
		_quote_candidate()
	player_choice.tooltip_text = "Au plus 60 résultats ; précisez la recherche pour les autres joueurs."

func _quote_candidate() -> void:
	var rows := candidate_rows.filter(func(p: Dictionary): return p.id == candidate_id)
	if rows.is_empty() or salary == null: return
	var player: Dictionary = rows[0]
	var quote: Dictionary = player.get("renewal", {}) if kind_index == 0 else player
	salary.value = float(quote.get("salary", 1000))
	fee.value = float(quote.get("fee", 0))
	years.min_value = float(quote.get("minYears", 1)) if kind_index == 0 else 1.0
	years.value = maxf(years.value, years.min_value)

func _goal() -> void:
	var goal: Variant = data.get("goal")
	if goal is Dictionary:
		_text("Objectif %s · cible %s · mesure %s sur %d rencontre(s) documentée(s)" % [METRIC_LABELS.get(goal.metric, goal.metric), str(goal.target), "inconnue" if goal.value == null else str(snappedf(float(goal.value), 0.1)), goal.measuredMatches])
		_text(goal.notice, C.GOLD)
		for row: Dictionary in goal.rows:
			_text("%s · %s · %s · mesure %s" % [row.get("opponentName", "Adversaire"), "domicile" if row.get("home", false) else "extérieur", str(row.get("phase", "")), "inconnue" if row.value == null else str(snappedf(float(row.value), 0.1))])
			if row.events.is_empty(): _text("Aucun événement détaillé conservé pour cet indicateur.", C.MUTED)
			else:
				for event: Dictionary in row.events: _text("%s min · %s" % [str(event.get("minute", "?")), str(event.get("text", event.kind))])
	else: _text("Choisissez un objectif ; seules les rencontres jouées ensuite seront suivies.")
	var choice := _select("PlannerGoalMetric", ["Touches conservées · minimum %", "Mêlées conservées · minimum %", "Pénalités concédées · maximum par match"], 0, func(index: int):
		var target := find_child("PlannerGoalTarget", true, false) as SpinBox
		if target != null: target.value = 8 if index == 2 else 80)
	var target := _number("PlannerGoalTarget", "Cible du nouveau suivi", 80, 100)
	_button("Démarrer un nouveau suivi" if goal == null else "Remplacer le suivi à partir d’aujourd’hui", func():
		_send("manager_plan_goal", {"metric":METRICS[choice.selected],"target":target.value}), "PlannerSaveGoal").disabled = not data.get("editable", false)
