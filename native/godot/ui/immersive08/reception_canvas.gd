extends RefCounted
## Le journal du moteur, accompagné de repères et d'actions réellement disponibles.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const Press = preload("res://ui/press_view.gd")

const CATEGORIES = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Compétitions"]
const ICONS = {"Staff":"train", "Médical":"heart", "Direction":"shield", "Recrutement":"search", "Formation":"school", "Compétitions":"trophy", "Club":"mail"}
const COLORS = {"Staff":C.MINT, "Médical":C.ALERT, "Direction":C.GOLD, "Recrutement":C.BLUE, "Formation":C.MINT, "Compétitions":C.GOLD, "Club":C.MUTED}
const ROUTES = {"Staff":"Préparation", "Médical":"Effectif", "Direction":"Club", "Recrutement":"Recrutement", "Formation":"Formation", "Compétitions":"Calendrier", "Club":"Bureau"}
const PORTRAITS = {"Médical":"mail-medical", "Direction":"mail-direction", "Recrutement":"mail-recruitment", "Formation":"academy-player", "Compétitions":"mail-trainer"}
const SEASON_EXPIRY_MAIL := "%d contrat(s) expire(nt) à la fin de cette saison. Consultez l'onglet Contrats pour anticiper les départs."

static func _state(app: Control) -> Dictionary:
	if not app.management_ui.has("reception"):
		app.management_ui.reception = {"folder":0, "category":"Tous", "selected":"", "oldest_first":false, "marks":{}, "scroll":0}
	return app.management_ui.reception

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
	D.text(row,1,19,"LE COURRIER DE VOTRE CARRIÈRE",19,C.GOLD,600,780)
	var title := D.text(row,-1,76,"Réception.",53,C.IVORY,700,777)
	D.line(row,Vector2(746,38),Vector2(746,89),C.LINE)
	D.chip(row,Rect2(773,36,199,52),"%d non lus" % unread(app),C.MINT)
	D.chip(row,Rect2(991,36,204,52),"%d décisions" % _tasks(app).size(),C.AMBER)
	var x := 1230
	var widths := [95,140,145,154,196,196]
	for i in CATEGORIES.size():
		var category: String = CATEGORIES[i]
		var name := "InboxCategory"+str(i)
		var action := D.button(row,Rect2(x,36,widths[i],52),category,func():
			state.category=category
			state.scroll=0
			_redraw(app,name),state.category==category,ICONS.get(category,""),true,app.accent,name)
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
	var folders := D.panel(page,Rect2(0,0,298,379),"", "", "", "InboxFolders")
	var visible := messages.filter(func(message: Dictionary): return _visible(message,state))
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
	var lounge := D.panel(page, Rect2(0, 397, 298, 252), "Sélection nationale" if national else "Accueil du club", "home")
	D.scenario_photo(lounge, "lounge", Rect2(12, 64, 274, 174))
	_list(D.panel(page,Rect2(316,0,749,1124),"","","","InboxMessages"),app,state,visible)
	_detail(D.panel(page,Rect2(1083,0,1165,1124),"","","","InboxDetail"),app,state,current)
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
		var row := D.button(card,Rect2(10,24+index*82,278,71),captions[index],func():
			state.folder=index
			state.category="Tous"
			state.scroll=0
			_redraw(app,id),state.folder==index,["mail","check","star","save"][index],false,app.accent,id)
		if state.folder != index: row.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,16))
		if index < 3: D.line(card,Vector2(20,99+index*82),Vector2(278,99+index*82),Color(C.LINE,.5))
	D.text(card,19,367,"Repères de cette session",18,C.MUTED,500,258)

static func _list(card: Panel, app: Control, state: Dictionary, messages: Array) -> void:
	D.text(card,25,54,"Messages (%d)" % messages.size(),32,C.IVORY,700,390)
	D.button(card,Rect2(503,17,223,48),"Plus anciens" if state.oldest_first else "Plus récents",func():
		state.oldest_first=not state.oldest_first
		state.scroll=0
		_redraw(app,"InboxSort"),false,"clock",true,app.accent,"InboxSort")
	D.line(card,Vector2(1,73),Vector2(748,73))
	var scroll := ScrollContainer.new()
	scroll.name = "InboxMessageScroll"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(3,82,743,1009))
	var rows := C.v(1)
	rows.name = "InboxMessageRows"
	C.fill(rows)
	scroll.add_child(rows)
	if messages.is_empty():
		D.text(card,28,150,"Aucun message dans cette vue.",27,C.MUTED,600,690)
		D.text(card,28,190,"Choisissez un autre dossier ou filtre.",21,C.MUTED,400,690,HORIZONTAL_ALIGNMENT_LEFT,true)
	for message: Dictionary in messages:
		var id := "InboxMessage_"+str(message.position)
		if message.get("press_invitation", {}).get("status") == "pending": id = "InboxPressInvitation"
		elif message.has("press_invitation"): id = "InboxPressMessage_" + str(message.position)
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
		row.custom_minimum_size = Vector2(700,104)*C.density
		row.tooltip_text = message.text
		row.set_meta("message_text",message.text)
		rows.add_child(row)
		if selected: row.add_theme_stylebox_override("normal",C.box(app.accent.darkened(.54),app.accent.lightened(.5),6,0))
		if not mark.get("read",false): D.rect(row,Rect2(18,44,13,13),C.MINT,7)
		elif mark.get("favorite",false): _icon(row,"star",Rect2(14,38,23,23),C.GOLD)
		var image: String = PORTRAITS.get(message.category,"mail-trainer")
		D.photo(row,image,Rect2(57,12,83,79))
		D.text(row,160,40,message.get("subject",message.category),29,C.IVORY,700,380)
		D.text(row,160,76,message.text,22,C.IVORY,500,525)
		var badge := "Message %02d" % message.position
		if message.get("press_invitation", {}).get("status") == "pending": badge = "À traiter"
		elif message.get("calendar_notice", {}).get("status") == "pending": badge = "À décider"
		elif message.has("international_event"): badge = "Sélections"
		D.chip(row,Rect2(544,13,150,31),badge,COLORS[message.category])
	scroll.set_deferred("scroll_vertical",int(state.scroll))

static func _detail(card: Panel, app: Control, state: Dictionary, message: Dictionary) -> void:
	card.clip_contents = true
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var category: String = message.get("category","Club")
	if category=="Médical":
		D.photo(card,"medical-recovery",Rect2(438,1,726,274))
		_art_fade(card,Rect2(0,0,797,276))
	else:
		D.photo(card,"mail-pitch",Rect2(53,120,588,155))
		_art_fade(card,Rect2(53,120,135,155))
		_art_fade(card,Rect2(53,120,588,57),false)
		D.photo(card,"mail-staff",Rect2(641,1,523,274))
		var blend := _art_fade(card,Rect2(641,1,154,274))
		blend.fill_from = Vector2(0,.23)
		blend.fill_to = Vector2(.25,.59)
	D.rect(card,Rect2(24,30,6,71),C.GOLD,3)
	D.text(card,52,68,category.to_upper(),39,C.IVORY,800,780)
	_icon(card,ICONS[category],Rect2(53,87,27,27),COLORS[category])
	var event: Dictionary = message.get("international_event", {})
	var source := "Journal de la sélection" if national else ("Journal du club" if message.is_empty() else "Journal du club · Message %02d" % message.position)
	if not event.is_empty():
		var date := P.fixture_date({"date":event.get("date")})
		source = "Sélections" if date.is_empty() else "Sélections · " + date
	D.text(card,92,110,source,24,C.IVORY,500,690)
	var title := "Le courrier de la sélection" if national else "Le courrier du club"
	if not message.is_empty(): title = str(message.get("subject",_subject(message.text)))
	D.text(card,32,303,title,44,C.IVORY,700,1097)
	var body := C.wrap(message.get("text","Aucun message à afficher dans ce dossier."),23,C.IVORY)
	body.name = "InboxMessageText"
	C.fill(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(33,330,1097,180))
	scroll.add_child(body)
	if not national:
		var group := P.group(app.model)
		_metric(card,Rect2(33,533,357,59),"people","%d disponibles" % group.available,C.MINT)
		_metric(card,Rect2(404,533,296,59),"heart","%d blessés" % group.injured,C.ALERT if group.injured>0 else C.MUTED)
		_metric(card,Rect2(714,533,416,59),"heart","Condition · %d %%" % group.condition,C.MINT)
	var focused := message.has("press_invitation") or message.has("calendar_notice") or not event.is_empty()
	if not focused and not national:
		var tasks := _tasks(app).slice(0,3)
		var recommendations := D.panel(card,Rect2(26,610,1112,175),"Mes recommandations","warning")
		if tasks.is_empty(): D.text(recommendations,25,104,"Aucune priorité immédiate.",23,C.MUTED,600,1020)
		for index in tasks.size():
			var task: Array = tasks[index]
			D.chip(recommendations,Rect2(22,64+index*35,38,28),str(index+1),C.MINT)
			var action := D.button(recommendations,Rect2(74,63+index*35,1016,33),task[0],func():
				if task[1]=="Entraînement": app.Immersive.open_training(app)
				else: app._navigate(task[1]),false,"arrow",true,app.accent,"InboxRecommendation"+str(index))
			action.add_theme_stylebox_override("normal",C.box(Color.TRANSPARENT,Color.TRANSPARENT,0,0))
		var next: Variant = app.model.get("next")
		if next is Dictionary and not next.is_empty():
			var fixture := D.button(card,Rect2(26,801,1112,69),"Dossier de préparation · "+str(next.get("label","Prochain match")),func():app._navigate("Préparation"),false,"tactic",false,app.accent,"InboxPreparation")
			fixture.tooltip_text = "Ouvrir l’analyse de la prochaine rencontre"
	if not message.is_empty(): _actions(card,app,state,message,628 if focused else 890)
	D.line(card,Vector2(26,1026),Vector2(1138,1026),C.LINE)
	D.text(card,35,1064,"HISTORIQUE DU COURRIER",26,C.IVORY,700,1040)
	D.text(card,35,1100,"Consultez les messages du journal dans leur ordre de réception.",21,C.MUTED,500,1080)

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
				var action := D.button(card,Rect2(26,top,545,62),caption,app._open_press_invitation.bind(invitation.id),true,"arrow",false,app.accent,"InboxOpenPressInvitation")
				action.disabled = app.waiting or (not receipt and (not conference.get("available", false) or conference.get("invitationId") != invitation.id))
				if action.disabled: action.tooltip_text = str(conference.get("reason", ""))
	elif message.get("calendar_notice", {}).get("status") == "pending":
		var recalibrate := D.button(card,Rect2(26,top,545,62),"Recaler la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"recalibrate"),true,"calendar",false,app.accent,"InboxRecalibratePreparation")
		var keep := D.button(card,Rect2(589,top,549,62),"Conserver la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"keep"),false,"check",false,app.accent,"InboxKeepPreparation")
		recalibrate.disabled = app.waiting
		keep.disabled = app.waiting
	else:
		if message.has("international_event"):
			var event: Dictionary = message.international_event
			var destination: String = event.get("action", "")
			if destination in ["international", "national_job"]:
				var caption := "Voir les offres de sélection" if destination == "national_job" else "Ouvrir les sélections"
				D.button(card,Rect2(26,top,545,62),caption,_open_international.bind(app,event),true,"arrow",false,app.accent,"InboxOpenInternational")
		else:
			var caption := "Ouvrir · " + str(message.route)
			var open := Callable(app, "_navigate").bind(message.route)
			if message.get("season_expiry", false):
				var current := _current_expiry_roster(app.model)
				if not current.is_empty():
					caption = "Voir les échéances actuelles (%d)" % current.count
					open = _open_expiry_roster.bind(app, current.roster)
			D.button(card,Rect2(26,top,545,62),caption,open,true,"arrow",false,app.accent,"InboxOpenMessageAction")
		D.button(card,Rect2(589,top,549,62),"Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité",func():
			mark.archived=not mark.get("archived",false)
			mark.read=true
			state.marks[message.id]=mark
			_redraw(app,"InboxFolder"+str(state.folder)),false,"check",false,app.accent,"InboxToggleArchive")
	D.button(card,Rect2(26,top+76,300,44),"Retirer des favoris" if mark.get("favorite",false) else "Ajouter aux favoris",func():
		mark.favorite=not mark.get("favorite",false)
		state.marks[message.id]=mark
		_redraw(app,"InboxToggleFavorite"),false,"star",true,app.accent,"InboxToggleFavorite")
	if not mark.get("archived",false):
		D.button(card,Rect2(342,top+76,300,44),"Marquer non lu" if mark.get("read",false) else "Marquer lu",func():
			mark.read=not mark.get("read",false)
			state.marks[message.id]=mark
			_redraw(app,"InboxToggleRead"),false,"mail",true,app.accent,"InboxToggleRead")

static func _open_international(app: Control, event: Dictionary) -> void:
	app.management_ui.international_section = "offers" if event.action == "national_job" else "callups"
	app.management_ui.international_nation = str(event.get("nation", ""))
	app._navigate("Sélections")

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
	_icon(tile,icon,Rect2(21,14,32,32),color)
	D.text(tile,75,41,value,32,C.IVORY,700,rectangle.size.x-94)

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
