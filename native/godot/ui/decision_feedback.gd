extends RefCounted
## UI de session : ni sauvegarde, ni calcul d'effet métier, ni copie du monde.
const G = preload("res://ui/carnet_skin.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const LIMIT := 10
const TITLES := {
	"train":"Séance effectuée", "training_plan":"Plan de travail appliqué",
	"set_tactics":"Consignes modifiées", "set_collective_focus":"Préparation collective modifiée",
	"set_development_focus":"Objectif de développement modifié", "set_player_load":"Charge modifiée",
	"staff_meeting":"Réunion du staff tenue", "strategic_briefing":"Briefing choisi",
	"press_conference":"Conférence tenue", "club_academy_investment":"Investissement de formation réglé",
	"club_facility_upgrade":"Installations améliorées", "club_sponsor_sign":"Sponsor signé",
	"relationship_activate":"Suivi du vestiaire activé", "relationship_conversation":"Entretien tenu",
	"relationship_promise":"Promesse enregistrée", "relationship_duo":"Travail du duo effectué",
	"locker_room_decision":"Décision du vestiaire appliquée",
	"recruit":"Recrutement", "extend_contract":"Prolongation", "agent_negotiate":"Réponse de l’agent", "agent_confirm":"Contrat signé"
}
var _app: WeakRef
var _pending: Dictionary = {}
var _receipts: Array[Dictionary] = []

func setup(app: Control) -> void: _app = weakref(app)
func reset() -> void:
	_pending.clear()
	_receipts.clear()
func receipts() -> Array: return _receipts.duplicate(true)
func status_text() -> String:
	return str(_receipts.back().summary) if not _receipts.is_empty() else ""

func begin(command: String, payload: Dictionary, model: Dictionary) -> void:
	# À appeler à l'envoi réel, après la file d'attente et les refus locaux.
	if command in ["new_career","import","recover_profile","restore_checkpoint"]:
		_pending = {"command":command}
	elif TITLES.has(command):
		_pending = {"command":command,"payload":payload.duplicate(true),"before":_metrics(model),"evidence":_evidence(command,payload,model),"detail":_detail(command,payload,model),"targets":_targets(command,payload,model)}
		if command == "train": _pending.training = _training_snapshot(model)

func complete(command: String, ok: bool, model: Dictionary) -> void:
	if command in ["new_career","import","recover_profile","restore_checkpoint"] and ok:
		reset()
		return
	if _pending.get("command","") != command: return
	var pending := _pending
	_pending = {}
	if not ok or not TITLES.has(command) or model.get("meta",{}).get("saveError",false): return
	var payload: Dictionary = pending.payload
	var after := _metrics(model)
	var title: String = TITLES[command]
	var detail: String = pending.detail
	if command in ["recruit","extend_contract","agent_negotiate","agent_confirm"]:
		var talk: Dictionary = _talk(command,payload,model)
		if talk.is_empty(): return
		var state := str(talk.get("status",""))
		if state == "signed": title = "Contrat signé"
		elif state == "counter": title = "Contre-offre reçue"
		elif state == "ready": title = "Accord à confirmer"
		elif state == "withdrawn": title = "Négociation retirée"
		else: return
		detail = str(talk.get("message",""))
		if detail.is_empty(): detail = title + "."
		if not str(pending.detail).is_empty(): detail = str(pending.detail) + " · " + detail
	else:
		var evidence: Variant = _evidence(command,payload,model)
		if evidence == null or evidence == pending.evidence: return
	var lines: Array[String] = []
	if not detail.is_empty(): lines.append(detail)
	for metric in ["cash","wage","morale"]:
		if pending.before.get(metric) == null or after.get(metric) == null: continue
		lines.append(_metric_line(metric,pending.before[metric],after[metric]))
	var targets: Array = pending.get("targets",[])
	if command == "train":
		var observed := _training_changes(pending.get("training",{}),model)
		for line: String in observed.lines: lines.append(line)
		for target: Dictionary in observed.targets: targets.append(target)
	var summary := title
	if not detail.is_empty(): summary += " · " + detail
	# Le pied de page reste bref ; le reçu complet est consultable volontairement.
	for metric in ["cash","wage","morale"]:
		if pending.before.get(metric) != null and after.get(metric) != null and pending.before[metric] != after[metric]:
			summary = title + " · " + _metric_line(metric,pending.before[metric],after[metric])
			break
	_receipts.append({"command":command,"title":title,"text":"\n".join(lines),"summary":summary,"before":pending.before,"after":after,"targets":targets})
	if _receipts.size() > LIMIT: _receipts.pop_front()

func _metrics(model: Dictionary) -> Dictionary:
	var finance: Dictionary = model.get("finance",{})
	return {"cash":finance.get("cash"),"wage":finance.get("wage"),"morale":model.get("meta",{}).get("morale")}

func _training_snapshot(model: Dictionary) -> Dictionary:
	var club: Variant = model.get("club")
	var meta: Variant = model.get("meta")
	var squad: Variant = model.get("squad")
	if not club is Dictionary or not meta is Dictionary or not squad is Array: return {}
	if club.get("id") == null or not meta.get("mode") is String or str(meta.mode).is_empty() or meta.get("season") == null or meta.get("week") == null: return {}
	if not (club.id is int or club.id is float or club.id is String): return {}
	if club.id is String and str(club.id).is_empty(): return {}
	if (club.id is int or club.id is float) and not is_finite(float(club.id)): return {}
	for value: Variant in [meta.season,meta.week]:
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	if float(meta.season)<1 or float(meta.week)<0: return {}
	var context := {"club":club.id,"mode":meta.mode,"season":meta.season,"week":meta.week}
	var counts: Dictionary = {}
	for person: Variant in squad:
		if person is Dictionary and person.get("id") is String and not str(person.id).is_empty(): counts[person.id]=int(counts.get(person.id,0))+1
	var people: Dictionary = {}
	for person: Variant in squad:
		if not person is Dictionary or not person.get("id") is String or counts.get(person.id,0)!=1: continue
		var knowledge: Variant = person.get("knowledge")
		if not knowledge is Dictionary or not knowledge.get("owned") is bool or knowledge.owned!=true: continue
		var known := {"name":person.name if person.get("name") is String else "Joueur"}
		# Only current public values of the owned squad. No potential, attributes,
		# market rows, academy rows or forecast is copied into this UI receipt.
		for field in ["condition","physicalLoad","rating"]:
			var value: Variant = person.get(field)
			if (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)<=100: known[field]=float(value)
		people[person.id]=known
	return {"context":context,"people":people}

func _observed_number(value: float) -> String:
	var rounded := roundf(value*10.0)/10.0
	return ("%.1f" % rounded).trim_suffix(".0").replace(".",",")

func _training_changes(before: Dictionary, model: Dictionary) -> Dictionary:
	var result := {"lines":[],"targets":[]}
	var after := _training_snapshot(model)
	if before.is_empty() or after.is_empty() or before.get("context")!=after.get("context"): return result
	var previous: Dictionary = before.get("people",{})
	var current: Dictionary = after.people
	var impact: Dictionary = {}
	for metric in [["condition","Condition moyenne"," %"],["physicalLoad","Charge moyenne"," / 100"],["rating","Niveau moyen"," / 100"]]:
		var field: String = metric[0]
		var count := 0
		var old_total := 0.0
		var new_total := 0.0
		var changes: Dictionary = {}
		for id: String in previous:
			if not current.has(id) or not previous[id].has(field) or not current[id].has(field): continue
			count+=1
			old_total+=float(previous[id][field])
			new_total+=float(current[id][field])
			changes[id]=absf(float(current[id][field])-float(previous[id][field]))
		if count==0: continue
		var old_text := _observed_number(old_total/count)
		var new_text := _observed_number(new_total/count)
		# A numerical difference that rounds to the same visible value must not
		# become a 0→0 observation or create a new link to noise.
		if old_text==new_text: continue
		result.lines.append("%s de %d joueur%s présent%s avant et après : %s → %s%s." % [metric[1],count,"s" if count>1 else "","s" if count>1 else "",old_text,new_text,metric[2]])
		for id: String in changes:
			if float(changes[id])>0: impact[id]=float(impact.get(id,0))+float(changes[id])
	var ids: Array = impact.keys()
	ids.sort_custom(func(a: String,b: String): return float(impact[a])>float(impact[b]) if impact[a]!=impact[b] else a<b)
	for id: String in ids.slice(0,2):
		result.targets.append({"target":{"kind":"player","id":id},"label":str(current[id].get("name","Joueur"))})
	return result

func _person(model: Dictionary, player_id: String) -> Dictionary:
	for group in [model.get("squad",[]),model.get("decisions",{}).get("development",{}).get("academy",[]),model.get("market",[])]:
		for p: Dictionary in group:
			if str(p.get("id","")) == player_id: return p
	return {}

func _targets(command: String, payload: Dictionary, model: Dictionary) -> Array[Dictionary]:
	# Retain exact identifiers at the real send, before a completed decision can
	# remove an event or negotiation. Never recover an ID from a sentence/name.
	var ids: Array = []
	if command in ["set_player_load","set_development_focus","relationship_conversation","relationship_promise","recruit","extend_contract"]:
		ids.append(payload.get("playerId"))
	elif command == "relationship_duo":
		ids.append(payload.get("a")); ids.append(payload.get("b"))
	elif command == "agent_negotiate": ids.append(payload.get("id"))
	elif command == "agent_confirm": ids.append(_talk(command,payload,model).get("id"))
	elif command == "locker_room_decision":
		var event: Variant = model.get("clubLife",{}).get("relationships",{}).get("event")
		if event is Dictionary and event.get("key") == payload.get("eventKey"): ids.append(event.get("playerId"))
	var result: Array[Dictionary] = []
	var seen: Array[String] = []
	for id: Variant in ids:
		if not id is String or id.is_empty() or id in seen: continue
		var person := _person(model,id)
		if person.is_empty(): continue
		seen.append(id)
		var target := {"kind":"player","id":id}
		if command in ["recruit","extend_contract","agent_negotiate","agent_confirm"]: target.section = "contract"
		result.append({"target":target,"label":str(person.get("name","Joueur"))})
	return result

func _navigation(app: Control) -> Node:
	for field: Dictionary in app.get_property_list():
		if field.name == "navigation_controller": return app.get("navigation_controller") as Node
	return null

func _receipt_links(app: Control, receipt: Dictionary, dialog: Window) -> Array[Button]:
	var links: Array[Button] = []
	var navigation := _navigation(app)
	if not is_instance_valid(navigation) or not navigation.has_method("entity_available"): return links
	for item: Dictionary in receipt.get("targets",[]):
		var target: Dictionary = item.get("target",{})
		if not navigation.entity_available(target): continue
		var button := G.button("Voir la fiche · " + str(item.get("label","Joueur")),func(): pass)
		button.name = "DecisionReceiptPlayerLink"
		button.custom_minimum_size.y = 40
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		EntityLink.bind(button,app,target,str(item.get("label","Joueur")),dialog)
		links.append(button)
	return links
func _support(model: Dictionary) -> Dictionary: return model.get("clubLife",{}).get("clubSupport",{})
func _strategy(model: Dictionary) -> Dictionary: return model.get("clubLife",{}).get("clubStrategy",{})
func _evidence(command: String, payload: Dictionary, model: Dictionary) -> Variant:
	var meta: Dictionary = model.get("meta",{})
	match command:
		"train": return meta.get("trained")
		"training_plan":
			var loads: Array = []
			for p: Dictionary in model.get("squad",[]): loads.append([p.get("id"),p.get("loadPlan")])
			return [meta.get("training"),loads]
		"set_tactics":
			var tactics: Dictionary = model.get("live",{}).get("tactics",{}) if model.get("live") is Dictionary else model.get("tactics",{})
			return [tactics.get("attack"),tactics.get("defense")]
		"set_collective_focus": return model.get("decisions",{}).get("training",{}).get("collective",{}).get("selected")
		"set_player_load": return _person(model,str(payload.get("playerId",""))).get("loadPlan")
		"set_development_focus":
			var development: Dictionary = model.get("decisions",{}).get("development",{})
			for group in [development.get("academy",[]),development.get("professionals",[])]:
				for p: Dictionary in group:
					if p.get("id") == payload.get("playerId"): return p.get("development",{}).get("focus")
			return null
		"staff_meeting": return _support(model).get("meeting",{}).get("lastDecision")
		"strategic_briefing": return _support(model).get("briefing",{}).get("selected")
		"club_academy_investment": return _strategy(model).get("finance",{}).get("academyInvestment")
		"club_facility_upgrade":
			var facility: Variant = _strategy(model).get("finance",{}).get("facility")
			return [facility.get("level") if facility is Dictionary else null,model.get("finance",{}).get("cash")]
		"club_sponsor_sign":
			for sponsor: Dictionary in _strategy(model).get("sponsors",[]):
				if sponsor.get("selected",false): return sponsor.get("id")
			return ""
		"press_conference": return model.get("clubLife",{}).get("press",{}).get("lastOutcome")
		"relationship_activate": return model.get("clubLife",{}).get("relationships",{}).get("active")
		"relationship_conversation","relationship_promise":
			for p: Dictionary in model.get("clubLife",{}).get("relationships",{}).get("players",[]):
				if p.get("id") == payload.get("playerId"): return [p.get("score"),p.get("promise"),p.get("conversationAvailable")]
			return null
		"relationship_duo": return model.get("clubLife",{}).get("relationships",{}).get("pairs",[])
		"locker_room_decision":
			var history: Array = model.get("clubLife",{}).get("relationships",{}).get("history",[])
			return history.front() if not history.is_empty() else null
	return null

func _label(options: Array, key: Variant) -> String:
	for option: Dictionary in options:
		if option.get("key",option.get("id")) == key: return str(option.get("label",key))
	return ""
func _detail(command: String, payload: Dictionary, model: Dictionary) -> String:
	var support := _support(model)
	match command:
		"train": return {"repos":"Repos","normal":"Travail normal","intense":"Travail intense"}.get(str(payload.get("mode","")),"")
		"set_tactics": return _label(model.get("tactics",{}).get("attacks",[]),payload.get("attack")) + " / " + _label(model.get("tactics",{}).get("defenses",[]),payload.get("defense"))
		"staff_meeting": return _label(support.get("meeting",{}).get("options",[]),payload.get("plan"))
		"training_plan": return _label(support.get("training",{}).get("plans",[]),payload.get("plan"))
		"strategic_briefing": return _label(support.get("briefing",{}).get("plans",[]),payload.get("plan"))
		"set_player_load": return str(_person(model,str(payload.get("playerId",""))).get("name","")) + " · " + str({"repos":"Repos","normal":"Charge normale","intense":"Charge intense"}.get(str(payload.get("mode","")),""))
		"set_development_focus":
			var development: Dictionary = model.get("decisions",{}).get("development",{})
			for group in [development.get("academy",[]),development.get("professionals",[])]:
				for p: Dictionary in group:
					if p.get("id") == payload.get("playerId"): return str(p.get("name","")) + " · " + _label(p.get("development",{}).get("options",[]),payload.get("focus"))
		"relationship_conversation": return str(_person(model,str(payload.get("playerId",""))).get("name","")) + " · " + _label(model.get("clubLife",{}).get("relationships",{}).get("conversations",[]),payload.get("choice"))
		"relationship_promise","recruit","extend_contract": return str(_person(model,str(payload.get("playerId",""))).get("name",""))
		"agent_negotiate": return str(_person(model,str(payload.get("id",""))).get("name",""))
		"set_collective_focus": return _label(model.get("decisions",{}).get("training",{}).get("collective",{}).get("options",[]),payload.get("focus"))
		"club_academy_investment": return _amount(payload.get("amount",0)) + " par séance ; prélèvement lors de la séance."
		"club_sponsor_sign": return _label(_strategy(model).get("sponsors",[]),payload.get("key"))
	return ""
func _talk(command: String, payload: Dictionary, model: Dictionary) -> Dictionary:
	if command in ["recruit","extend_contract"]:
		var negotiation: Dictionary = model.get("meta",{}).get("negotiation",{})
		return negotiation if negotiation.get("playerId") == payload.get("playerId") else {}
	for talk: Dictionary in _support(model).get("agents",{}).get("talks",[]):
		if (command == "agent_negotiate" and talk.get("id") == payload.get("id")) or (command == "agent_confirm" and talk.get("key") == payload.get("key")): return talk
	return {}
func _amount(value: Variant) -> String:
	var raw := str(int(round(float(value))))
	var result := ""
	for index in raw.length():
		if index > 0 and (raw.length()-index)%3 == 0 and raw[index-1] != "-": result += " "
		result += raw[index]
	return result + " €"
func _metric_line(metric: String, before: Variant, after: Variant) -> String:
	var label: String = {"cash":"Trésorerie","wage":"Salaires "+preload("res://ui/salary_display.gd").period_label(),"morale":"Moral collectif"}[metric]
	if metric == "morale": return "%s : %s → %s / 100%s" % [label,str(before),str(after)," (stable)" if before == after else ""]
	return "%s : %s → %s%s" % [label,preload("res://ui/salary_display.gd").amount(before) if metric == "wage" else _amount(before),preload("res://ui/salary_display.gd").amount(after) if metric == "wage" else _amount(after)," (stable)" if before == after else ""]

func control() -> Button:
	var button := Button.new()
	button.name = "DecisionFeedbackButton"
	button.text = "Dernières décisions"
	button.tooltip_text = "Consulter les dix derniers reçus de cette session"
	button.custom_minimum_size = Vector2(146,30)
	button.add_theme_font_size_override("font_size",12)
	button.disabled = _receipts.is_empty()
	button.pressed.connect(_open)
	return button
func _modal_visible(node: Node) -> bool:
	for child in node.get_children():
		if child is Window and child.visible: return true
		if _modal_visible(child): return true
	return false
func _open() -> void:
	var app: Control = _app.get_ref() if _app else null
	if not is_instance_valid(app) or _modal_visible(app): return
	var dialog := AcceptDialog.new()
	dialog.name = "DecisionFeedbackDialog"
	dialog.set_meta("navigation_read_only",true)
	dialog.title = "Dernières décisions"
	dialog.get_ok_button().text = "FERMER"
	if app.has_method("_prepare_dialog"): app._prepare_dialog(dialog,640)
	var scroll := ScrollContainer.new()
	scroll.name = "DecisionFeedbackScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(600,370)
	dialog.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	var note := Label.new()
	note.text = "Dix dernières décisions de cette session.\nRelisez les engagements et les suites annoncées pour chaque décision."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size",14)
	content.add_child(note)
	var reading_links: Array[Button] = []
	for index in range(_receipts.size()-1,-1,-1):
		var receipt: Dictionary = _receipts[index]
		var entry := Label.new()
		entry.text = receipt.title + "\n" + receipt.text
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_theme_font_size_override("font_size",15)
		content.add_child(entry)
		for link: Button in _receipt_links(app,receipt,dialog):
			content.add_child(link)
			reading_links.append(link)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	# Les labels ne prennent pas le focus : Tab relie lecture et fermeture.
	# La barre native gère les flèches ; les touches de lecture paginée sont explicites.
	var vertical := scroll.get_v_scroll_bar()
	var close := dialog.get_ok_button()
	vertical.focus_mode = Control.FOCUS_ALL
	vertical.gui_input.connect(func(event: InputEvent):
		if not event is InputEventKey or not event.pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
		match event.keycode:
			KEY_PAGEDOWN: vertical.value += vertical.page
			KEY_PAGEUP: vertical.value -= vertical.page
			KEY_HOME: vertical.value = vertical.min_value
			KEY_END: vertical.value = vertical.max_value-vertical.page
			_: return
		vertical.accept_event())
	var focus_chain: Array[Control] = [close]
	for link: Button in reading_links: focus_chain.append(link)
	focus_chain.append(vertical)
	for index in focus_chain.size():
		var current := focus_chain[index]
		current.focus_next=current.get_path_to(focus_chain[(index+1)%focus_chain.size()])
		current.focus_previous=current.get_path_to(focus_chain[posmod(index-1,focus_chain.size())])
	dialog.popup_centered(Vector2i(640,450))
	close.call_deferred("grab_focus")
