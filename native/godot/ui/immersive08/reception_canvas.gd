extends RefCounted
## Le journal du moteur, accompagné de repères et d'actions réellement disponibles.
const C = preload("res://ui/immersive08/components.gd")
const Portraits = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const Press = preload("res://ui/press_view.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")

const CATEGORIES = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Compétitions"]
const ICONS = {"Staff":"train", "Médical":"heart", "Direction":"shield", "Recrutement":"search", "Formation":"school", "Compétitions":"trophy", "Club":"mail"}
const COLORS = {"Staff":C.MINT, "Médical":C.ALERT, "Direction":C.GOLD, "Recrutement":C.BLUE, "Formation":C.MINT, "Compétitions":C.GOLD, "Club":C.MUTED}
const ROUTES = {"Staff":"Préparation", "Médical":"Effectif", "Direction":"Club", "Recrutement":"Recrutement", "Formation":"Formation", "Compétitions":"Calendrier", "Club":"Bureau"}
const PORTRAITS = {"Médical":"mail-medical", "Direction":"mail-direction", "Recrutement":"mail-recruitment", "Formation":"academy-player", "Compétitions":"mail-trainer"}
const SEASON_EXPIRY_MAIL := "%d contrat(s) expire(nt) à la fin de cette saison. Consultez l'onglet Contrats pour anticiper les départs."

static func _state(app: Control) -> Dictionary:
	if not app.management_ui.has("reception"):
		app.management_ui.reception = {"folder":0, "category":"Tous", "selected":"", "oldest_first":false, "marks":{}, "scroll":0}
	var state: Dictionary = app.management_ui.reception
	if not state.has("activity_filter"): state.activity_filter = "all"
	if not state.has("expanded_threads"): state.expanded_threads = {}
	return state

static func international_mail(model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var international: Variant = model.get("international")
	if not international is Dictionary or not international.get("mail") is Array: return result
	var seen := {}
	for event: Variant in international.mail:
		if not event is Dictionary or not event.get("id") is String or event.id.is_empty() or seen.has(event.id): continue
		seen[event.id] = true
		result.append(event)
	return result

static func _priority_ids(model: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if model.get("international", {}).get("role") != "nation":
		for invitation: Dictionary in model.get("clubLife", {}).get("press", {}).get("invitations", []):
			if invitation.status == "pending": ids.append(invitation.id)
		for notice: Dictionary in model.get("calendarMail", []):
			if notice.status == "pending": ids.append(notice.id)
	for event: Dictionary in international_mail(model): ids.append("international:" + event.id)
	return ids

static func new_priority(previous: Dictionary, current: Dictionary) -> String:
	var before := _priority_ids(previous)
	for id in _priority_ids(current):
		if id not in before: return id
	return ""

static func _messages(app: Control) -> Array[Dictionary]:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var source: Array = [] if national else app.model.get("messages", [])
	var messages: Array[Dictionary] = []
	var occurrences := {}
	# Le moteur ne fournit que des textes dans l'ordre de réception. Distinguer
	# deux exemplaires identiques sans modifier les données d'une carrière.
	for index in range(source.size()-1, -1, -1):
		var message := str(source[index])
		occurrences[message] = int(occurrences.get(message, 0)) + 1
		var id := message.sha256_text() + "-" + str(occurrences[message])
		var clean := message.replace("l’onglet Contrats", "les fiches des joueurs dans Effectif").replace("l'onglet Contrats", "les fiches des joueurs dans Effectif")
		var folded := U.fold(clean)
		var category := _category(folded)
		var destination: String = ROUTES[category]
		if category == "Direction" and "contrat" in folded: destination = "Effectif"
		if category == "Direction" and ("tresorerie" in folded or "billetterie" in folded): destination = "Finances"
		var item := {"id":id, "text":clean, "category":category, "route":destination, "position":source.size()-index}
		if _is_season_expiry_mail(message): item.season_expiry = true
		messages.push_front(item)
	var notices: Array = [] if national else app.model.get("calendarMail", [])
	for index in notices.size():
		var notice: Dictionary = notices[index]
		var previous_date := P.fixture_date({"date":notice.fromDate})
		var new_date := P.fixture_date({"date":notice.toDate})
		var opponent := str(notice.opponent)
		var fixture := "Votre rencontre" if opponent.is_empty() else "Votre rencontre contre " + opponent
		var text := "%s, initialement prévue le %s, aura lieu le %s." % [fixture, previous_date, new_date]
		match notice.status:
			"pending": text += "\n\nVous pouvez recaler les séances à venir sur la nouvelle date ou conserver la préparation prévue."
			"recalibrated": text += "\n\nLa préparation a été recalée."
			"kept": text += "\n\nLa préparation prévue a été conservée."
			"superseded": text += "\n\nUn courrier plus récent indique la nouvelle date."
			"expired": text += "\n\nCette rencontre ne permet plus de modifier la préparation."
		messages.push_front({
			"id":notice.id, "subject":"Changement de date", "text":text, "category":"Compétitions",
			"route":"Calendrier", "position":source.size()+index+1, "calendar_notice":notice
		})
	var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
	var invitations: Array = [] if national else press.get("invitations", [])
	for index in range(invitations.size() - 1, -1, -1):
		var invitation: Dictionary = invitations[index]
		var context: Dictionary = invitation.context
		var subject: String = {
			"arrival":"Présentation à la presse", "knockout":"Conférence de phase finale",
			"season_review":"Conférence de bilan", "weekly":"Conférence de la semaine"
		}.get(invitation.kind, "Invitation de presse")
		var detail := "%s · Saison %d · Semaine %d." % [Press._club(app, context.club), context.season, int(context.week) + 1]
		match invitation.status:
			"pending": detail += "\n\nLes journalistes vous attendent. Publiez vos réponses pour poursuivre."
			"published": detail += "\n\nVos réponses ont été publiées."
			"expired": detail += "\n\nCe rendez-vous est passé."
		messages.push_front({
			"id":invitation.id, "subject":subject, "text":detail, "category":"Compétitions",
			"route":"Presse", "position":messages.size() + 1, "press_invitation":invitation
		})
	var events := international_mail(app.model)
	for index in range(events.size() - 1, -1, -1):
		var event := events[index]
		messages.push_front({
			"id":"international:" + event.id, "subject":str(event.get("title", "Sélections internationales")),
			"text":str(event.get("body", "")), "category":"Compétitions",
			"position":messages.size() + 1, "international_event":event
		})
	return messages

static func _is_season_expiry_mail(message: String) -> bool:
	# Les courriers historiques du moteur ne contiennent ni type ni identifiants de joueurs.
	var count := message.get_slice(" ", 0).to_int()
	return count > 0 and message.replace("’", "'") == (SEASON_EXPIRY_MAIL % count)

static func _category(message: String) -> String:
	if "blesse" in message or "indisponibilite" in message or "medical" in message: return "Médical"
	if "espoir" in message or "formation" in message or "promu" in message: return "Formation"
	if "recrutement" in message or "mercato" in message or "transfert" in message: return "Recrutement"
	if "contrat" in message or "direction" in message or "president" in message or "tresorerie" in message or "billetterie" in message: return "Direction"
	if "entrainement" in message or "vestiaire" in message or "preparation" in message: return "Staff"
	if message.begins_with("victoire") or message.begins_with("defaite") or message.begins_with("match nul") or "classement" in message: return "Compétitions"
	return "Club"

static func unread(app: Control) -> int:
	var marks: Dictionary = _state(app).marks
	return _messages(app).filter(func(message: Dictionary): return not marks.get(message.id, {}).get("read", false)).size()

static func _tasks(app: Control) -> Array:
	var tasks := []
	if app.Immersive.Selections.nation_only(app.model): return tasks
	if not app.model.get("selection", {}).get("valid", false): tasks.append(["Compléter la feuille de match", "Composition"])
	if not app.model.get("meta", {}).get("trained", false): tasks.append(["Organiser la charge de la semaine", "Entraînement"])
	var contracts := P.contracts(app.model)
	if not contracts.is_empty(): tasks.append(["Examiner les échéances de %d contrat(s)" % contracts.size(), "Effectif"])
	if P.group(app.model).injured > 0: tasks.append(["Consulter les indisponibilités de l’effectif", "Effectif"])
	var reports: Array = app.model.get("decisions", {}).get("recruitment", {}).get("reports", [])
	if not reports.is_empty(): tasks.append(["Consulter %d rapport(s) de recrutement" % reports.size(), "Recrutement"])
	return tasks

static func heading(row: Control, app: Control) -> Label:
	var state := _state(app)
	D.text(row,1,19,"LE COURRIER DE VOTRE CARRIÈRE",17,C.GOLD,600,780)
	var title := D.text(row,-1,57,"Réception.",28,C.IVORY,700,777)
	var counts := Reading.counts(_messages(app),app.model)
	D.text(row,1,82,"%d courriers · %d urgences vérifiables" % [counts.all,counts.urgent],17,C.MUTED,500,730)
	D.line(row,Vector2(746,38),Vector2(746,76),C.LINE)
	D.chip(row,Rect2(773,36,199,34),"%d non lus" % unread(app),C.MINT)
	D.chip(row,Rect2(991,36,204,34),"%d à faire" % Reading.counts(_messages(app), app.model).todo,C.AMBER)
	var x := 1230
	var widths := [95,140,145,154,196,196]
	for i in CATEGORIES.size():
		var category: String = CATEGORIES[i]
		var name := "InboxCategory"+str(i)
		var action := D.button(row,Rect2(x,36,widths[i],34),category,func():
			state.category=category
			state.scroll=0
			_redraw(app,name),state.category==category,ICONS.get(category,""),true,app.accent,name)
		action.add_theme_font_size_override("font_size",C.px(18))
		action.tooltip_text = "Filtrer le courrier · " + category
		x += widths[i] + 14
	return title

static func build(app: Control) -> Control:
	var page := Control.new()
	page.name = "ImmersiveInbox"
	page.custom_minimum_size = Vector2(2248,1124)*C.density
	C.fill(page,true)
	var state := _state(app)
	var messages := _messages(app)
	var marks: Dictionary = state.marks
	var active := messages.map(func(message: Dictionary): return message.id)
	for id in marks.keys():
		if id not in active: marks.erase(id)
	var folders := D.panel(page,Rect2(0,0,298,270),"", "", "", "InboxFolders")
	var unfiltered := messages.filter(func(message: Dictionary): return _visible(message,state))
	var selected: Array = unfiltered.filter(func(message: Dictionary): return message.id == state.selected)
	if state.activity_filter != "all" and not selected.is_empty() and Reading.status(selected[0], app.model).key != state.activity_filter:
		state.activity_filter = "all" # A newly selected priority stays visible after a model update.
	var visible := unfiltered.filter(func(message: Dictionary): return state.activity_filter == "all" or Reading.status(message, app.model).key == state.activity_filter)
	if state.oldest_first: visible.reverse()
	var priority := _priority_ids(app.model)
	var mandatory := visible.filter(func(message: Dictionary): return message.has("press_invitation") and message.id in priority)
	var urgent := visible.filter(func(message: Dictionary):
		return (message.id in priority and not message.has("press_invitation")
			and (not message.has("international_event") or not marks.get(message.id, {}).get("read", false))))
	visible = mandatory + urgent + visible.filter(func(message: Dictionary): return message not in mandatory and message not in urgent)
	if not visible.any(func(message: Dictionary): return message.id == state.selected):
		var ordinary := visible.filter(func(message: Dictionary): return not message.has("press_invitation"))
		state.selected = "" if ordinary.is_empty() else ordinary[0].id
	var current: Dictionary = {}
	for message: Dictionary in visible:
		if message.id == state.selected: current=message; break
	_folders(folders,app,state)
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	_activity_filters(D.panel(page, Rect2(0,288,298,255),"","","","InboxActivityFilters"), app, state, unfiltered)
	var lounge := D.panel(page, Rect2(0, 561, 298, 196), "Sélection" if national else "Accueil du club", "home")
	D.scenario_photo(lounge, "lounge", Rect2(12, 50, 274, 132))
	var category_view: Dictionary = state.duplicate()
	category_view.category = "Tous"
	_category_chart(D.panel(page,Rect2(0,775,298,349),"","","","InboxCategoryChart"), app, state, messages.filter(func(item: Dictionary): return _visible(item,category_view)))
	_list(D.panel(page,Rect2(316,0,749,1124),"","","","InboxMessages"),app,state,visible)
	_detail(D.panel(page,Rect2(1083,0,1165,1124),"","","","InboxDetail"),app,state,current)
	if state.get("return_focus", false):
		state.return_focus = false
		_restore_reading.call_deferred(page, state)
	return page

static func _visible(message: Dictionary, state: Dictionary) -> bool:
	if state.category != "Tous" and state.category != message.category: return false
	var mark: Dictionary = state.marks.get(message.id, {})
	var archived: bool = mark.get("archived", false)
	if state.folder == 3: return archived
	if archived: return false
	if state.folder == 1: return not mark.get("read",false)
	if state.folder == 2: return mark.get("favorite",false)
	return true

static func _folders(card: Panel, app: Control, state: Dictionary) -> void:
	var captions := ["Tous les messages", "Non lus  (%d)" % unread(app), "Favoris", "Archives"]
	for index in captions.size():
		var id := "InboxFolder"+str(index)
		var row := D.button(card,Rect2(10,18+index*53,278,43),captions[index],func():
			state.folder=index
			state.category="Tous"
			state.scroll=0
			_redraw(app,id),state.folder==index,["mail","check","star","save"][index],false,app.accent,id)
		row.add_theme_font_size_override("font_size", C.px(18))
		if state.folder != index: row.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,16))
		if index < 3: D.line(card,Vector2(20,67+index*53),Vector2(278,67+index*53),Color(C.LINE,.5))
	D.text(card,19,251,"Repères de session",16,C.MUTED,500,258)

static func _activity_filters(card: Panel, app: Control, state: Dictionary, messages: Array) -> void:
	D.text(card,20,33,"PAR ÉTAT",22,C.GOLD,700,260)
	var counts := Reading.counts(messages, app.model)
	var keys := ["all", "todo", "waiting", "info"]
	for index in keys.size():
		var key: String = keys[index]
		var id := "InboxActivity_" + key
		var action := D.button(card,Rect2(10,48+index*49,278,39),"%s (%d)" % [Reading.LABELS[key], counts[key]],func():
			state.activity_filter = key
			state.selected = ""
			state.scroll = 0
			_redraw(app,id),state.activity_filter==key,"",false,app.accent,id)
		action.add_theme_font_size_override("font_size", C.px(18))
		action.accessibility_name = "%s : %d courrier(s)" % [Reading.LABELS[key], counts[key]]
		action.tooltip_text = "Filtrer les états réellement indiqués par le moteur. Les messages sans décision explicite restent des informations."

static func _open_related(app: Control, message: Dictionary, action: Callable) -> void:
	if message.is_empty():
		action.call()
		return
	var state := _state(app)
	state.selected = message.id
	state.expanded_threads[Reading.thread_key(message)] = true
	var scroll := app.root_content.find_child("InboxMessageScroll", true, false) as ScrollContainer
	if scroll != null: state.scroll = scroll.scroll_vertical
	state.return_focus = true
	action.call()

static func _restore_reading(page: Control, state: Dictionary) -> void:
	if not is_instance_valid(page) or not page.is_inside_tree(): return
	for row in page.find_children("*", "Button", true, false):
		if row.get_meta("message_id", "") == state.selected:
			row.grab_focus()
			var scroll := page.find_child("InboxMessageScroll", true, false) as ScrollContainer
			if scroll != null: scroll.set_deferred("scroll_vertical", int(state.scroll))
			return

static func _category_chart(card: Panel, app: Control, state: Dictionary, messages: Array) -> void:
	D.text(card,18,33,"COURRIER PAR SUJET",22,C.GOLD,700,270)
	var categories := ["Staff","Médical","Direction","Recrutement","Formation","Compétitions","Club"]
	var counts := {}
	var maximum := 1
	for category in categories:
		counts[category] = messages.filter(func(message: Dictionary): return message.category == category).size()
		maximum = maxi(maximum, counts[category])
	for index in categories.size():
		var category: String = categories[index]
		var top := 61+index*40
		var id := "InboxCategoryMetric_"+category
		var action := C.button("",func():
			state.category = category
			state.scroll = 0
			_redraw(app,id),state.category==category,app.accent)
		action.name = id
		action.accessibility_name = "%s : %d courrier(s), filtrer" % [category,counts[category]]
		card.add_child(action); D.place(action,Rect2(8,top-22,282,38))
		D.text(action,10,21,category,18,C.IVORY,500,225)
		D.text(action,270,21,counts[category],18,COLORS[category],700,40,HORIZONTAL_ALIGNMENT_RIGHT)
		D.bar(action,Rect2(10,29,260,5),100.0*counts[category]/maximum,COLORS[category])


static func _context(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: int) -> void:
	var height := 1105-top
	var panel := D.panel(card,Rect2(26,top,1112,height),"","","","InboxContext")
	D.text(panel,18,32,"EN CONTEXTE",22,C.GOLD,700,1060)
	var next: Variant = app.model.get("next")
	if next is Dictionary and not next.is_empty():
		D.text(panel,18,68,next.get("label","Prochaine rencontre"),23,C.IVORY,700,850)
		D.text(panel,18,97,P.fixture_date(next),18,C.MUTED,500,850)
		D.button(panel,Rect2(910,53,183,34),"Préparation",_open_related.bind(app,message,Callable(app,"_navigate").bind("Préparation")),false,"tactic",false,app.accent,"InboxContextPreparation")
	else:
		D.text(panel,18,70,"Calendrier et archives de votre carrière",20,C.IVORY,600,850)
		D.button(panel,Rect2(910,53,183,34),"Calendrier",_open_related.bind(app,message,Callable(app,"_navigate").bind("Calendrier")),false,"calendar",false,app.accent,"InboxContextCalendar")
	D.line(panel,Vector2(18,116),Vector2(1094,116))
	var others: Array = _messages(app).filter(func(item: Dictionary): return item.id != message.get("id", ""))
	var related: Array = others.filter(func(item: Dictionary): return Reading.thread_key(item) == Reading.thread_key(message))
	var caption := "Courriers liés"
	if related.is_empty():
		related = others.filter(func(item: Dictionary): return item.category == message.get("category", ""))
		caption = "Dans le même dossier"
	if related.is_empty(): related = others; caption = "Derniers courriers"
	var related_top := 160
	if message.get("season_expiry", false):
		var expiring: Array = app.model.get("decisions", {}).get("recruitment", {}).get("expiring", [])
		var ids: Array = expiring.map(func(player: Dictionary): return str(player.id))
		var players: Array = app.model.get("squad", []).filter(func(player: Dictionary): return str(player.id) in ids)
		D.text(panel,18,145,"Échéances actuelles · %d joueur(s) dans l’effectif" % players.size(),18,C.GOLD,600,1060)
		for index in mini(players.size(),3):
			var player: Dictionary = players[index]
			var open := C.button("",_open_related.bind(app,message,_open_current_player.bind(app,str(player.id))),false,app.accent)
			open.name = "InboxExpiryPlayer_"+str(index)
			open.set_meta("player_id",str(player.id))
			open.accessibility_name = "Ouvrir la fiche de " + str(player.name)
			panel.add_child(open); D.place(open,Rect2(12+index*364,156,354,68))
			var portrait := Portraits.portrait(int(player.get("portraitIndex",0)),C.px(54),player)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			open.tooltip_text = str(player.name) + " · " + portrait.tooltip_text
			open.add_child(portrait); D.place(portrait,Rect2(5,6,54,54))
			D.text(open,68,28,player.name,20,C.IVORY,600,276)
			D.text(open,68,52,player.get("pos",""),17,C.MUTED,500,276)
		related_top = 264
	D.text(panel,18,related_top-12,"%s · %d" % [caption,related.size()],18,C.MUTED,600,1060)
	var row_height := 52 if height>350 else 42
	var capacity := mini(6,maxi(0,floori(float(height-related_top)/row_height)))
	for index in mini(related.size(),capacity):
		var item: Dictionary = related[index]
		var reading := Reading.status(item,app.model)
		var button := C.button("",func():
			state.selected = item.id
			state.activity_filter = "all"
			state.folder = 0
			state.category = "Tous"
			state.expanded_threads[Reading.thread_key(item)] = true
			state.press_opened = item.id if item.has("press_invitation") else ""
			var mark: Dictionary = state.marks.get(item.id,{})
			mark.read = true
			state.marks[item.id] = mark
			_redraw(app,_row_id(item)),false,app.accent)
		button.name = "InboxRelated_"+str(index)
		button.accessibility_name = "%s · %s" % [reading.label,item.get("subject",item.category)]
		panel.add_child(button)
		D.place(button,Rect2(12,related_top+index*row_height,1088,row_height-4))
		D.text(button,12,25,item.get("subject",_subject(item.text)),20,C.IVORY,600,840)
		D.text(button,1062,25,reading.label,17,C.ALERT if reading.urgent else C.MINT,600,190,HORIZONTAL_ALIGNMENT_RIGHT)
		if row_height>50: D.text(button,12,45,item.text,17,C.MUTED,500,1050)

static func _open_current_player(app: Control, player_id: String) -> void:
	if not app.model.get("squad", []).any(func(player: Dictionary): return str(player.id)==player_id): return
	U.remember(app)
	app.management_ui.roster = U.defaults()
	app.roster_filter = "Tous"
	app.roster_sort = "Poste"
	app.selected_player = player_id
	app.management_ui.profile_scroll = 0
	app.set_meta("immersive08_full_player",true)
	app._navigate("Effectif",false,true)

static func _list(card: Panel, app: Control, state: Dictionary, messages: Array) -> void:
	D.text(card,25,43,"Messages (%d)" % messages.size(),28,C.IVORY,700,390)
	D.button(card,Rect2(503,12,223,38),"Plus anciens" if state.oldest_first else "Plus récents",func():
		state.oldest_first=not state.oldest_first
		state.scroll=0
		_redraw(app,"InboxSort"),false,"clock",true,app.accent,"InboxSort")
	D.text(card,25,78,"↑ ↓ choisir · Entrée ouvrir le courrier",17,C.MUTED,500,700)
	D.line(card,Vector2(1,94),Vector2(748,94))
	var scroll := ScrollContainer.new()
	scroll.name = "InboxMessageScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(3,103,743,988))
	var rows := C.v(1)
	rows.name = "InboxMessageRows"
	C.fill(rows)
	scroll.add_child(rows)
	if messages.is_empty():
		D.text(card,28,150,"Aucun message dans cette vue.",27,C.MUTED,600,690)
		D.text(card,28,190,"Choisissez un autre dossier ou filtre.",21,C.MUTED,400,690,HORIZONTAL_ALIGNMENT_LEFT,true)
	var list_entries: Array[Dictionary] = []
	for group: Dictionary in Reading.groups(messages):
		var linked: Array = group.messages
		if linked.size() > 1:
			var default_open: bool = linked.any(func(item: Dictionary): return item.id == state.selected or Reading.status(item, app.model).key == "todo")
			var opened: bool = state.expanded_threads.get(group.key, default_open)
			var title: String = str(linked[0].get("subject",linked[0].category))
			var notice: Dictionary = linked[0].get("calendar_notice",{})
			if not str(notice.get("opponent","")).is_empty(): title += " · " + str(notice.opponent)
			var context: Dictionary = linked[0].get("press_invitation",{}).get("context",{})
			if context.has_all(["season","week"]): title += " · S%d / sem. %d" % [context.season,int(context.week)+1]
			list_entries.append({"thread_header":true,"key":group.key,"opened":opened,"count":linked.size(),"title":title})
			if not opened: continue
		for item: Dictionary in linked: list_entries.append(item)
	for message: Dictionary in list_entries:
		if message.get("thread_header", false):
			var group_id := "InboxThread_" + str(message.key).sha256_text().left(12)
			var toggle := C.button(("▾ " if message.opened else "▸ ") + "%s · %d courriers" % [message.title,message.count], func():
				state.expanded_threads[message.key] = not message.opened
				_redraw(app, group_id), false, app.accent)
			toggle.add_theme_font_size_override("font_size", C.px(18))
			toggle.custom_minimum_size.y = C.px(34)
			toggle.name = group_id
			toggle.set_meta("thread_key", message.key)
			toggle.tooltip_text = "Déplier ou réduire les courriers de la même rencontre, édition ou conférence"
			rows.add_child(toggle)
			continue
		var id := _row_id(message)
		var selected: bool = message.id==state.selected
		var mark: Dictionary = state.marks.get(message.id,{})
		var row := C.button("",func():
			state.selected=message.id
			state.press_opened=message.id if message.has("press_invitation") else ""
			if state.folder!=1:
				mark.read=true
				state.marks[message.id]=mark
			_redraw(app,id),selected,app.accent)
		row.name = id
		row.gui_input.connect(_message_key.bind(app, message.id))
		row.custom_minimum_size = Vector2(700,62)*C.density
		row.tooltip_text = message.text
		row.set_meta("message_text",message.text)
		row.set_meta("message_id", message.id)
		var reading := Reading.status(message, app.model)
		row.accessibility_name = "%s · %s · %s" % [reading.label, message.get("subject",message.category), message.text]
		rows.add_child(row)
		if selected: row.add_theme_stylebox_override("normal",C.box(app.accent.darkened(.54),app.accent.lightened(.5),6,0))
		if not mark.get("read",false): D.rect(row,Rect2(7,27,8,8),C.MINT,7)
		elif mark.get("favorite",false): _icon(row,"star",Rect2(5,23,15,15),C.GOLD)
		var image: String = PORTRAITS.get(message.category,"mail-trainer")
		D.photo(row,image,Rect2(24,6,53,50))
		D.text(row,90,25,message.get("subject",message.category),20,C.IVORY,700,450)
		D.text(row,90,48,("URGENT · " if reading.urgent else "") + str(reading.label) + " · " + message.text,17,C.ALERT if reading.urgent else C.MUTED,500,598)
		var badge := "Message %02d" % message.position
		if message.get("press_invitation", {}).get("status") == "pending": badge = "À traiter"
		elif message.get("calendar_notice", {}).get("status") == "pending": badge = "À décider"
		elif message.has("international_event"): badge = "Sélections"
		D.chip(row,Rect2(544,7,150,24),badge,COLORS[message.category])
	scroll.set_deferred("scroll_vertical",int(state.scroll))

static func _row_id(message: Dictionary) -> String:
	if message.get("press_invitation", {}).get("status") == "pending": return "InboxPressInvitation"
	if message.has("press_invitation"): return "InboxPressMessage_" + str(message.position)
	return "InboxMessage_" + str(message.position)

static func _message_key(event: InputEvent, app: Control, message_id: String) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	if event.keycode not in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_END]: return
	var rows: Node = app.root_content.find_child("InboxMessageRows", true, false)
	if rows == null: return
	var buttons: Array = rows.get_children().filter(func(node): return node is Button and node.has_meta("message_id"))
	var index := -1
	for position in buttons.size():
		if buttons[position].get_meta("message_id") == message_id: index = position; break
	if index < 0: return
	var next := clampi(index + (1 if event.keycode == KEY_DOWN else -1), 0, buttons.size()-1)
	if event.keycode == KEY_HOME: next = 0
	if event.keycode == KEY_END: next = buttons.size()-1
	app.get_viewport().set_input_as_handled()
	buttons[next].pressed.emit()

static func _detail(card: Panel, app: Control, state: Dictionary, message: Dictionary) -> void:
	card.clip_contents = true
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var category: String = message.get("category","Club")
	if category=="Médical":
		D.photo(card,"medical-recovery",Rect2(438,1,726,140))
		_art_fade(card,Rect2(0,0,797,142))
	else:
		D.photo(card,"mail-pitch",Rect2(53,1,588,140))
		_art_fade(card,Rect2(53,1,135,140))
		_art_fade(card,Rect2(53,1,588,45),false)
		D.photo(card,"mail-staff",Rect2(641,1,523,140))
		var blend := _art_fade(card,Rect2(641,1,154,140))
		blend.fill_from = Vector2(0,.23)
		blend.fill_to = Vector2(.25,.59)
	D.rect(card,Rect2(24,20,4,66),C.GOLD,3)
	D.text(card,46,48,category.to_upper(),28,C.IVORY,800,780)
	_icon(card,ICONS[category],Rect2(47,64,20,20),COLORS[category])
	var event: Dictionary = message.get("international_event", {})
	var source := "Journal de la sélection" if national else ("Journal du club" if message.is_empty() else "Journal du club · Message %02d" % message.position)
	if not event.is_empty():
		var date := P.fixture_date({"date":event.get("date")})
		source = "Sélections" if date.is_empty() else "Sélections · " + date
	D.text(card,78,82,source,18,C.IVORY,500,690)
	var title := "Le courrier de la sélection" if national else "Le courrier du club"
	if not message.is_empty(): title = str(message.get("subject",_subject(message.text)))
	D.text(card,32,181,title,28,C.IVORY,700,1097)
	var body := C.wrap(message.get("text","Aucun message à afficher dans ce dossier."),18,C.IVORY)
	body.name = "InboxMessageText"
	C.fill(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var text_height := body.get_theme_font("font").get_multiline_string_size(body.text,HORIZONTAL_ALIGNMENT_LEFT,C.px(1080),C.px(18),-1,TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y / C.density
	var body_height := clampf(text_height+14,52,207)
	var offset := body_height-207
	D.place(scroll,Rect2(33,204,1097,body_height))
	scroll.add_child(body)
	if not message.is_empty():
		var reading := Reading.status(message, app.model)
		D.chip(card,Rect2(32,101,600,30),("URGENT · " if reading.urgent else "") + str(reading.label),C.ALERT if reading.urgent else C.GOLD)
	if not national:
		var group := P.group(app.model)
		_metric(card,Rect2(33,430+offset,357,43),"people","%d disponibles" % group.available,C.MINT)
		_metric(card,Rect2(404,430+offset,296,43),"heart","%d blessés" % group.injured,C.ALERT if group.injured>0 else C.MUTED)
		_metric(card,Rect2(714,430+offset,416,43),"heart","Condition · %d %%" % group.condition,C.MINT)
	var focused := message.has("press_invitation") or message.has("calendar_notice") or not event.is_empty()
	if not focused and not national:
		var tasks := _tasks(app).slice(0,3)
		var recommendations := D.panel(card,Rect2(26,489+offset,1112,145),"Mes recommandations","warning")
		if tasks.is_empty(): D.text(recommendations,25,91,"Aucune priorité immédiate.",23,C.MUTED,600,1020)
		for index in tasks.size():
			var task: Array = tasks[index]
			D.chip(recommendations,Rect2(22,50+index*28,28,23),str(index+1),C.MINT)
			var action := D.button(recommendations,Rect2(62,48+index*28,1028,26),task[0],func():
				if task[1]=="Entraînement": app.Immersive.open_training(app)
				else: app._navigate(task[1]),false,"arrow",true,app.accent,"InboxRecommendation"+str(index))
			action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
		var next: Variant = app.model.get("next")
		if next is Dictionary and not next.is_empty():
			var fixture := D.button(card,Rect2(26,648+offset,1112,45),"Dossier de préparation · "+str(next.get("label","Prochain match")),func():app._navigate("Préparation"),false,"tactic",false,app.accent,"InboxPreparation")
			fixture.tooltip_text = "Ouvrir l’analyse de la prochaine rencontre"
	if not message.is_empty(): _actions(card,app,state,message,int((489 if focused else 712)+offset))
	_context(card,app,state,message,int((610 if focused else 830)+offset))
	for action in card.find_children("*", "Button", true, false):
		action.add_theme_font_size_override("font_size", C.px(18))

static func _art_fade(parent: Node, area: Rect2, horizontal: bool = true) -> GradientTexture2D:
	var fade := Control.new()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fade)
	D.place(fade,area)
	var overlay := C.veil(fade,horizontal)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return overlay.texture as GradientTexture2D

static func _actions(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: int) -> void:
	var mark: Dictionary = state.marks.get(message.id,{})
	if message.has("press_invitation"):
		var invitation: Dictionary = message.press_invitation
		if state.get("press_opened") == invitation.id:
			var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
			var conference: Dictionary = press.get("conference", {})
			var outcome: Variant = press.get("lastOutcome")
			var receipt: bool = invitation.status == "published" and outcome is Dictionary and outcome.get("invitationId") == invitation.id
			if invitation.status == "pending" or receipt:
				var caption := "Consulter le compte rendu" if receipt else "Ouvrir la conférence"
				var action := D.button(card,Rect2(26,top,545,38),caption,_open_related.bind(app, message, app._open_press_invitation.bind(invitation.id)),true,"arrow",false,app.accent,"InboxOpenPressInvitation")
				action.disabled = app.waiting or (not receipt and (not conference.get("available", false) or conference.get("invitationId") != invitation.id))
				if action.disabled: action.tooltip_text = str(conference.get("reason", ""))
	elif message.get("calendar_notice", {}).get("status") == "pending":
		var recalibrate := D.button(card,Rect2(26,top,545,38),"Recaler la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"recalibrate"),true,"calendar",false,app.accent,"InboxRecalibratePreparation")
		var keep := D.button(card,Rect2(589,top,549,38),"Conserver la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"keep"),false,"check",false,app.accent,"InboxKeepPreparation")
		recalibrate.disabled = app.waiting
		keep.disabled = app.waiting
	else:
		if message.has("international_event"):
			var event: Dictionary = message.international_event
			var destination: String = event.get("action", "")
			if event.get("kind") == "international_host":
				var edition: Dictionary = app.Immersive.Selections.host_mail_edition(app.model, event)
				if not edition.is_empty():
					var caption: String = app.Immersive.Selections.host_mail_caption(edition)
					var open: Callable = app.Immersive.Selections.open_host.bind(app, edition)
					D.button(card,Rect2(26,top,545,38),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenInternational")
			elif destination in ["international", "national_job"]:
				var caption := "Voir les offres de sélection" if destination == "national_job" else "Ouvrir les sélections"
				if _has_match_sheet(app, event): caption = "Préparer la feuille de match"
				elif _is_club_return(app, event): caption = "Voir l’effectif"
				D.button(card,Rect2(26,top,545,38),caption,_open_related.bind(app, message, _open_international.bind(app,event)),true,"arrow",false,app.accent,"InboxOpenInternational")
		else:
			var caption := "Ouvrir · " + str(message.route)
			var open := Callable(app, "_navigate").bind(message.route)
			if message.get("season_expiry", false):
				var current := _current_expiry_roster(app.model)
				if not current.is_empty():
					caption = "Voir les échéances actuelles (%d)" % current.count
					open = _open_expiry_roster.bind(app, current.roster)
			D.button(card,Rect2(26,top,545,38),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenMessageAction")
		D.button(card,Rect2(589,top,549,38),"Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité",func():
			mark.archived=not mark.get("archived",false)
			mark.read=true
			state.marks[message.id]=mark
			_redraw(app,"InboxFolder"+str(state.folder)),false,"check",false,app.accent,"InboxToggleArchive")
	D.button(card,Rect2(26,top+48,300,34),"Retirer des favoris" if mark.get("favorite",false) else "Ajouter aux favoris",func():
		mark.favorite=not mark.get("favorite",false)
		state.marks[message.id]=mark
		_redraw(app,"InboxToggleFavorite"),false,"star",true,app.accent,"InboxToggleFavorite")
	if not mark.get("archived",false):
		D.button(card,Rect2(342,top+48,300,34),"Marquer non lu" if mark.get("read",false) else "Marquer lu",func():
			mark.read=not mark.get("read",false)
			state.marks[message.id]=mark
			_redraw(app,"InboxToggleRead"),false,"mail",true,app.accent,"InboxToggleRead")

static func _open_international(app: Control, event: Dictionary) -> void:
	if _is_club_return(app, event):
		app._navigate("Effectif")
		return
	app.management_ui.international_section = "offers" if event.action == "national_job" else "callups"
	if _has_match_sheet(app, event): app.management_ui.international_section = "sheet"
	app.management_ui.international_nation = str(event.get("nation", ""))
	app._navigate("Sélections")

static func _is_club_return(app: Control, event: Dictionary) -> bool:
	return event.get("kind") == "international_return" and not app.Immersive.Selections.nation_only(app.model)

static func _has_match_sheet(app: Control, event: Dictionary) -> bool:
	var fixture: Dictionary = app.Immersive.Selections.current_fixture(app.model)
	return not fixture.is_empty() and event.id == "match-day/" + str(fixture.id) and not app.Immersive.Selections.Sheet.slots(app.model.international).is_empty()

static func _current_expiry_roster(model: Dictionary) -> Dictionary:
	var expiring: Variant = model.get("decisions", {}).get("recruitment", {}).get("expiring")
	if not expiring is Array: return {}
	var roster := U.defaults()
	roster.contract = "Fin de saison"
	roster.sort = "Échéance"
	roster.immersive_tab = 2
	var season := int(model.get("meta", {}).get("season", 1))
	var displayed := U.players(model.get("squad", []), roster, season)
	var displayed_ids := displayed.map(func(player: Dictionary): return str(player.id))
	var expiring_ids: Array = expiring.map(func(player: Dictionary): return str(player.id))
	displayed_ids.sort()
	expiring_ids.sort()
	# Le filtre inclut aussi les contrats antérieurs que certaines sauvegardes conservent.
	if displayed_ids != expiring_ids: return {}
	return {"roster":roster, "count":displayed_ids.size()}

static func _open_expiry_roster(app: Control, roster: Dictionary) -> void:
	app.management_ui.roster = roster
	app.management_ui.profile_scroll = 0
	app.roster_filter = roster.family
	app.roster_sort = roster.sort
	app.selected_player = ""
	app._navigate("Effectif", false)

static func _choose_calendar_preparation(app: Control, card: Panel, id: String, choice: String) -> void:
	if app._command("calendar_mail_decide",{"id":id, "choice":choice}):
		for name in ["InboxRecalibratePreparation", "InboxKeepPreparation"]:
			var action := card.get_node_or_null(name) as Button
			if action != null: action.disabled = true

static func _subject(message: String) -> String:
	var colon := message.find(":")
	if colon >= 8 and colon <= 63: return message.left(colon).strip_edges()
	var period := message.find(". ")
	if period > 0 and period <= 72: return message.left(period).strip_edges()
	var words := D.words(message,70,1)
	return words[0]+("…" if words[0]!=message else "") if not words.is_empty() else "Message du club"

static func _icon(parent: Control, id: String, rectangle: Rect2, color: Color) -> void:
	var icon := C.icon(id, int(rectangle.size.x), color)
	parent.add_child(icon)
	D.place(icon,rectangle)

static func _metric(parent: Control, rectangle: Rect2, icon: String, value: String, color: Color) -> void:
	var tile := D.rect(parent,rectangle,Color(color,.10),6,Color(color,.6))
	_icon(tile,icon,Rect2(15,11,22,22),color)
	D.text(tile,47,29,value,20,C.IVORY,700,rectangle.size.x-94)

static func _redraw(app: Control, focus: String) -> void:
	var state := _state(app)
	var scroll: ScrollContainer = app.root_content.find_child("InboxMessageScroll",true,false)
	if is_instance_valid(scroll) and not focus.begins_with("InboxFolder") and not focus.begins_with("InboxCategory") and focus!="InboxSort":
		state.scroll = scroll.scroll_vertical
	app._render()
	var action: Control = app.root_content.find_child(focus,true,false)
	if action == null: action=app.root_content.find_child("InboxFolder"+str(state.folder),true,false)
	if action != null: _focus.call_deferred(action)

static func _focus(action: Control) -> void:
	if is_instance_valid(action) and action.is_inside_tree(): action.grab_focus()
