extends RefCounted
## Le journal du moteur, accompagné de repères et d'actions réellement disponibles.
const Copy = preload("res://ui/management_copy.gd")
const C = preload("res://ui/immersive08/components.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Portraits = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const U = preload("res://ui/management_state.gd")
const Press = preload("res://ui/press_view.gd")
const Link = preload("res://ui/entity_link.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const CATEGORIES = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Compétitions"]
const ICONS = {"Staff":"train", "Médical":"heart", "Direction":"shield", "Recrutement":"search", "Formation":"school", "Compétitions":"trophy", "Club":"mail"}
const COLORS = {"Staff":C.MINT, "Médical":C.ALERT, "Direction":C.GOLD, "Recrutement":C.BLUE, "Formation":C.MINT, "Compétitions":C.GOLD, "Club":C.MUTED}
const ROUTES = {"Staff":"Préparation", "Médical":"Effectif", "Direction":"Club", "Recrutement":"Recrutement", "Formation":"Formation", "Compétitions":"Calendrier", "Club":"Bureau"}
## Expéditeur affiché dans la liste et en tête du mail ouvert (le moteur ne signe que le courrier du club).
const SENDERS = {"Staff":"Staff technique", "Médical":"Service médical", "Direction":"Direction du club", "Recrutement":"Cellule de recrutement", "Formation":"Centre de formation", "Compétitions":"Organisateur des compétitions", "Club":"Secrétariat du club"}
## Disposition façon Football Manager (gabarit 2248 × 1124) : liste étroite à gauche, mail ouvert en grand à droite.
const PAGE := Vector2(2248, 1124)
## Hauteur minimale du gabarit quand la fenêtre est basse (en-tête du mail, une pièce liée et le pied restent lisibles).
const MIN_HEIGHT := 680.0
const LIST_WIDTH := 700.0
const GAP := 18.0
const DETAIL_WIDTH := 2248.0 - 700.0 - 18.0
const ROW_HEIGHT := 90.0
const HALF := (DETAIL_WIDTH - 52.0 - 18.0) / 2.0
const SUBJECTS = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Formation", "Compétitions", "Club"]
const ACTIVITY_CAPTIONS := {"all":"Tout", "todo":"À faire", "waiting":"En attente", "info":"Infos"}
const PORTRAITS = {"Médical":"mail-medical", "Direction":"mail-direction", "Recrutement":"mail-recruitment", "Formation":"academy-player", "Compétitions":"mail-trainer"}
# Trois formes : singulier et pluriel accordés (moteur actuel) et la forme historique « contrat(s) expire(nt) » des anciennes carrières.
const SEASON_EXPIRY_MAILS := [
	"%d contrat expire à la fin de cette saison. Consultez l'onglet Contrats pour anticiper les départs.",
	"%d contrats expirent à la fin de cette saison. Consultez l'onglet Contrats pour anticiper les départs.",
	"%d contrat(s) expire(nt) à la fin de cette saison. Consultez l'onglet Contrats pour anticiper les départs.",
]

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
		var clean := Copy.news(message).replace("l’onglet Contrats", "les fiches des joueurs dans Effectif").replace("l'onglet Contrats", "les fiches des joueurs dans Effectif")
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
	# Courrier du club (club-mail.cjs) : les plus récents en tête.
	if not national:
		for item: Dictionary in ClubMail.messages(app.model): messages.push_front(item)
	var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
	var invitations: Array = [] if national else press.get("invitations", [])
	for index in range(invitations.size() - 1, -1, -1):
		var invitation: Dictionary = invitations[index]
		var context: Dictionary = invitation.context
		var subject: String = {
			"arrival":"Présentation à la presse", "knockout":"Conférence de phase finale",
			"season_review":"Conférence de bilan", "weekly":"Conférence de la semaine"
		}.get(invitation.kind, "Invitation de presse")
		var detail := "%s · Saison %s · Semaine %d." % [Press._club(app, context.club), SeasonLabel.label(context.season), int(context.week) + 1]
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
	if count <= 0: return false
	var normalized := message.replace("’", "'")
	for template: String in SEASON_EXPIRY_MAILS:
		if normalized == (template % count): return true
	return false

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
	var contracts := P.contracts_ending(app.model)
	if not contracts.is_empty(): tasks.append(["Examiner %s de contrat en fin de saison" % P.plural(contracts.size(), "échéance", "échéances"), "Effectif"])
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
	var state := _state(app)
	var height := _height(state)
	page.custom_minimum_size = Vector2(PAGE.x, height)*C.density
	C.fill(page,true)
	var messages := _messages(app)
	var marks: Dictionary = state.marks
	var active := messages.map(func(message: Dictionary): return message.id)
	for id in marks.keys():
		if id not in active: marks.erase(id)
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
	var category_view: Dictionary = state.duplicate()
	category_view.category = "Tous"
	var list := D.panel(page,Rect2(0,0,LIST_WIDTH,height),"","","","InboxMessages")
	_list_filters(list, app, state, unfiltered, messages.filter(func(item: Dictionary): return _visible(item,category_view)))
	_list(list,app,state,visible)
	_detail(D.panel(page,Rect2(LIST_WIDTH+GAP,0,DETAIL_WIDTH,height),"","","","InboxDetail"),app,state,current)
	if state.get("return_focus", false):
		state.return_focus = false
		_restore_reading.call_deferred(page, state)
	_fit.call_deferred(app, page)
	return page

## Hauteur d'une rangée de boutons : gabarit approuvé, sans descendre sous la hauteur minimale réelle d'un bouton
## (police plancher de 12 px) quand la fenêtre est petite.
static func _h(base: float) -> float:
	return maxf(base, 32.0 / C.density)

## Ordonnées de l'en-tête de liste : dossiers, états, sujet, puis filet au-dessus des messages.
static func _header_rows() -> Array[float]:
	var folders := 16.0 + _h(44)
	var states := folders + _h(44) + 10
	var subject := states + _h(44) + 10
	return [folders, states, subject, subject + _h(44) + 8]

static func _height(state: Dictionary) -> float:
	return clampf(float(state.get("page_height", PAGE.y)), MIN_HEIGHT, PAGE.y)

## La boîte tient dans la hauteur visible de l'espace de travail : liste et pied du mail sans défilement de page.
## Une seule reconstruction quand la hauteur disponible change (taille de fenêtre, bandeau au-dessus de la boîte).
static func _fit(app: Control, page: Control) -> void:
	if is_instance_valid(page) and page.is_inside_tree():
		await page.get_tree().process_frame
		await page.get_tree().process_frame
	if not is_instance_valid(page) or not page.is_inside_tree() or app.route != "Réception": return
	var workspace := app.body_scroll as Control
	if not is_instance_valid(workspace): return
	var available := (workspace.get_global_rect().end.y - page.get_global_rect().position.y - C.px(6)) / C.density
	var state := _state(app)
	var target := clampf(available, MIN_HEIGHT, PAGE.y)
	if absf(target - _height(state)) <= 4.0: return
	state.page_height = target
	app._render()

static func _visible(message: Dictionary, state: Dictionary) -> bool:
	if state.category != "Tous" and state.category != message.category: return false
	var mark: Dictionary = state.marks.get(message.id, {})
	var archived: bool = mark.get("archived", false)
	if state.folder == 3: return archived
	if archived: return false
	if state.folder == 1: return not mark.get("read",false)
	if state.folder == 2: return mark.get("favorite",false)
	return true

## En tête de la liste : dossiers, états et sujet (les filtres de la boîte, regroupés au-dessus des messages).
static func _list_filters(card: Panel, app: Control, state: Dictionary, messages: Array, all_subjects: Array) -> void:
	var captions := ["Tous", "Non lus (%d)" % unread(app), "Favoris", "Archives"]
	for index in captions.size():
		var id := "InboxFolder"+str(index)
		var row := D.button(card,Rect2(12+index*169,_header_rows()[0],163,_h(44)),captions[index],func():
			state.folder=index
			state.category="Tous"
			state.scroll=0
			_redraw(app,id),state.folder==index,"",true,app.accent,id)
		row.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", C.px(18))
		row.tooltip_text = ["Tous les messages", "Messages non lus", "Messages favoris", "Messages traités"][index]
	var counts := Reading.counts(messages, app.model)
	var keys := ["all", "todo", "waiting", "info"]
	var widths := [130, 160, 192, 168]
	var x := 12
	for index in keys.size():
		var key: String = keys[index]
		var id := "InboxActivity_" + key
		var action := D.button(card,Rect2(x,_header_rows()[1],widths[index],_h(44)),"%s (%d)" % [ACTIVITY_CAPTIONS[key], counts[key]],func():
			state.activity_filter = key
			state.selected = ""
			state.scroll = 0
			_redraw(app,id),state.activity_filter==key,"",true,app.accent,id)
		action.alignment = HORIZONTAL_ALIGNMENT_CENTER
		action.add_theme_font_size_override("font_size", C.px(17))
		action.accessibility_name = "%s : %d courrier(s)" % [Reading.LABELS[key], counts[key]]
		action.tooltip_text = Reading.LABELS[key] + ". Les messages sans décision explicite restent des informations."
		x += widths[index] + 6
	var subject := OptionButton.new()
	subject.name = "InboxSubject"
	subject.add_theme_font_override("font",C.BOLD)
	subject.add_theme_font_size_override("font_size",maxi(12,C.px(17)))
	subject.tooltip_text = "Filtrer le courrier par sujet"
	for index in SUBJECTS.size():
		var category: String = SUBJECTS[index]
		var count := all_subjects.size() if category == "Tous" else all_subjects.filter(func(message: Dictionary): return message.category == category).size()
		subject.add_item("Sujet : %s (%d)" % [category, count])
		if category == state.category: subject.select(index)
	subject.item_selected.connect(func(index: int):
		state.category = SUBJECTS[index]
		state.scroll = 0
		_redraw(app,"InboxSubject"))
	card.add_child(subject)
	D.place(subject,Rect2(12,_header_rows()[2],676,_h(44)))

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

## Pièces liées au mail ouvert (rencontre, fiches des joueurs concernés, priorités de la semaine), juste sous le texte.
## Rend la hauteur occupée ; rien n'est dessiné si `draw` est faux (mesure avant placement).
static func _attachments(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: float, focused: bool, draw: bool) -> float:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var width := DETAIL_WIDTH - 52
	var y := top
	if message.is_empty(): return 0.0
	# Rencontre concernée ou dossier de préparation.
	if draw: D.text(card,28,y+20,"PIÈCES LIÉES",17,C.GOLD,700,400)
	var links_top := y + 32
	var x := 26.0
	var notice: Dictionary = message.get("calendar_notice",{})
	var next: Variant = app.model.get("next")
	if not notice.is_empty():
		var target := {"kind":"fixture","id":str(notice.get("fixtureId",""))}
		var caption := "Rencontre · " + str(notice.get("opponent",""))
		if not Competition.target_available(app,"fixture",target.id):
			target = {"kind":"date","id":str(notice.get("toDate",""))}
			caption = "Calendrier · " + P.fixture_date({"date":notice.get("toDate")})
		if Competition.target_available(app,str(target.kind),target.id):
			if draw:
				var link := Link.button(app,caption,target,"InboxContextFixture")
				card.add_child(link); D.place(link,Rect2(x,links_top,520,_h(40)))
			x += 536
	elif next is Dictionary and not next.is_empty() and not national:
		if draw:
			var prep := D.button(card,Rect2(x,links_top,620,_h(40)),"Dossier de préparation · "+str(next.get("label","Prochain match")),_open_related.bind(app,message,Callable(app,"_navigate").bind("Préparation")),false,"tactic",true,app.accent,"InboxPreparation")
			prep.tooltip_text = "Ouvrir l’analyse de la prochaine rencontre · " + P.fixture_date(next)
		x += 636
	else:
		if draw: D.button(card,Rect2(x,links_top,300,_h(40)),"Calendrier",_open_related.bind(app,message,Callable(app,"_navigate").bind("Calendrier")),false,"calendar",true,app.accent,"InboxContextCalendar")
		x += 316
	if message.get("category") == "Médical" and not national:
		var group := P.group(app.model)
		if draw:
			_metric(card,Rect2(x,links_top,250,_h(40)),"people","%d disponibles" % group.available,C.MINT)
			_metric(card,Rect2(x+262,links_top,220,_h(40)),"heart","%d blessés" % group.injured,C.ALERT if group.injured>0 else C.MUTED)
	y = links_top + _h(40) + 12
	# Fiches des joueurs concernés (fin de contrat).
	if message.get("season_expiry", false):
		var expiring: Array = app.model.get("decisions", {}).get("recruitment", {}).get("expiring", [])
		var ids: Array = expiring.map(func(player: Dictionary): return str(player.id))
		var players: Array = app.model.get("squad", []).filter(func(player: Dictionary): return str(player.id) in ids)
		if draw: D.text(card,28,y+18,"Échéances de fin de saison · %s dans l’effectif" % P.plural(players.size(), "joueur", "joueurs"),17,C.MUTED,600,width)
		var shown := mini(players.size(),4)
		for index in shown:
			if not draw: break
			var player: Dictionary = players[index]
			var open := C.button("",_open_related.bind(app,message,_open_current_player.bind(app,str(player.id))),false,app.accent)
			open.name = "InboxExpiryPlayer_"+str(index)
			open.set_meta("player_id",str(player.id))
			open.accessibility_name = "Ouvrir la fiche de " + str(player.name)
			card.add_child(open); D.place(open,Rect2(26+index*(width+12)/4.0,y+30,(width+12)/4.0-12,68))
			var portrait := Portraits.portrait(int(player.get("portraitIndex",0)),C.px(54),player)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			open.tooltip_text = str(player.name) + " · " + portrait.tooltip_text
			open.add_child(portrait); D.place(portrait,Rect2(5,6,54,54))
			D.text(open,68,28,player.name,20,C.IVORY,600,(width+12)/4.0-90)
			D.text(open,68,52,player.get("pos",""),17,C.MUTED,500,(width+12)/4.0-90)
		y += 110 if shown > 0 else 30
	# Priorités de la semaine, pour un courrier d'information du club.
	if not focused and not national:
		var tasks := _tasks(app).slice(0,3)
		if not tasks.is_empty():
			if draw: D.text(card,28,y+18,"PRIORITÉS DE LA SEMAINE",17,C.GOLD,700,400)
			var cell := (width - 32) / 3.0
			for index in tasks.size():
				if not draw: break
				var task: Array = tasks[index]
				var action := D.button(card,Rect2(26+index*(cell+16),y+30,cell,_h(40)),task[0],func():
					if task[1]=="Entraînement": app.Immersive.open_training(app)
					else: app._navigate(task[1]),false,"arrow",true,app.accent,"InboxRecommendation"+str(index))
				action.tooltip_text = task[0]
			y += _h(40) + 42
	return y - top

static func _open_current_player(app: Control, player_id: String) -> void:
	app.navigation_controller.open_entity({"kind":"player","id":player_id,"section":"contract"})

static func _list(card: Panel, app: Control, state: Dictionary, messages: Array) -> void:
	D.text(card,22,40,"Messages (%d)" % messages.size(),26,C.IVORY,700,420)
	D.button(card,Rect2(470,8,218,_h(44)),"Plus anciens" if state.oldest_first else "Plus récents",func():
		state.oldest_first=not state.oldest_first
		state.scroll=0
		_redraw(app,"InboxSort"),false,"clock",true,app.accent,"InboxSort")
	var top := _header_rows()[3]
	D.line(card,Vector2(1,top),Vector2(LIST_WIDTH-1,top))
	var scroll := ScrollContainer.new()
	scroll.name = "InboxMessageScroll"
	scroll.tooltip_text = "↑ ↓ choisir · Entrée ouvrir le courrier"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(3,top+2,LIST_WIDTH-6,_height(state)-top-12))
	var rows := C.v(1)
	rows.name = "InboxMessageRows"
	C.fill(rows)
	scroll.add_child(rows)
	if messages.is_empty():
		D.text(card,26,top+52,"Aucun message dans cette vue.",24,C.MUTED,600,640)
		D.text(card,26,top+90,"Choisissez un autre dossier ou filtre.",19,C.MUTED,400,640,HORIZONTAL_ALIGNMENT_LEFT,true)
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
			if context.has_all(["season","week"]): title += " · %s / sem. %d" % [SeasonLabel.label(context.season),int(context.week)+1]
			list_entries.append({"thread_header":true,"key":group.key,"opened":opened,"count":linked.size(),"title":title})
			if not opened: continue
		for item: Dictionary in linked: list_entries.append(item)
	for message: Dictionary in list_entries:
		if message.get("thread_header", false):
			var group_id := "InboxThread_" + str(message.key).sha256_text().left(12)
			var toggle := C.button(("▾ " if message.opened else "▸ ") + "%s · %d courriers" % [message.title,message.count], func():
				state.expanded_threads[message.key] = not message.opened
				_redraw(app, group_id), false, app.accent)
			toggle.add_theme_font_size_override("font_size", C.px(17))
			toggle.custom_minimum_size.y = C.px(34)
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.clip_text = true
			toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			toggle.name = group_id
			toggle.set_meta("thread_key", message.key)
			toggle.tooltip_text = "Déplier ou réduire les courriers de la même rencontre, édition ou conférence"
			rows.add_child(toggle)
			continue
		_row(rows, app, state, message)
	scroll.set_deferred("scroll_vertical",int(state.scroll))

## Une ligne de la liste, façon FM : non lu en évidence, expéditeur et date, objet, état et début du texte.
static func _row(rows: Control, app: Control, state: Dictionary, message: Dictionary) -> void:
	var id := _row_id(message)
	var selected: bool = message.id==state.selected
	var mark: Dictionary = state.marks.get(message.id,{})
	var is_unread: bool = not mark.get("read",false)
	var row := C.button("",func():
		state.selected=message.id
		state.press_opened=message.id if message.has("press_invitation") else ""
		if state.folder!=1:
			mark.read=true
			state.marks[message.id]=mark
		_redraw(app,id),selected,app.accent)
	row.name = id
	row.gui_input.connect(_message_key.bind(app, message.id))
	row.custom_minimum_size = Vector2(LIST_WIDTH-24,ROW_HEIGHT)*C.density
	row.tooltip_text = message.text
	row.set_meta("message_text",message.text)
	row.set_meta("message_id", message.id)
	var reading := Reading.status(message, app.model)
	row.accessibility_name = "%s%s · %s · %s" % ["Non lu · " if is_unread else "", reading.label, message.get("subject",message.category), message.text]
	rows.add_child(row)
	var style := C.box(Color(C.PANEL,.0) if not selected else app.accent.darkened(.54), Color(C.LINE,.45) if not selected else app.accent.lightened(.5), 4, 0)
	row.add_theme_stylebox_override("normal", style)
	var width := LIST_WIDTH - 24
	if is_unread:
		var dot := D.rect(row,Rect2(0,6,5,ROW_HEIGHT-12),C.MINT,2)
		dot.name = "UnreadDot"
	elif mark.get("favorite",false): _icon(row,"star",Rect2(5,10,14,14),C.GOLD)
	var image: String = PORTRAITS.get(message.category,"mail-trainer")
	D.photo(row,image,Rect2(16,14,58,58))
	var text_x := 88.0
	var date := _date(message)
	D.text(row,width-12,28,date,16,C.MUTED,500,150,HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(row,text_x,28,_sender(app,message),16,COLORS[message.category] if is_unread else C.MUTED,600,width-text_x-170)
	D.text(row,text_x,56,message.get("subject",_subject(message.text)),20,C.IVORY if is_unread else Color(C.IVORY,.72),700 if is_unread else 500,width-text_x-14)
	var excerpt := str(message.text).replace("\n"," ").strip_edges()
	var prefix := ""
	var tone: Color = C.MUTED
	if reading.urgent: prefix = "URGENT · " + str(reading.label) + " · "; tone = C.ALERT
	elif reading.key == "todo": prefix = str(reading.label) + " · "; tone = C.AMBER
	elif reading.key == "waiting": prefix = str(reading.label) + " · "
	D.text(row,text_x,80,prefix + excerpt,15,tone,500,width-text_x-14)

## Expéditeur du courrier, pour la liste et l'en-tête du mail ouvert.
static func _sender(app: Control, message: Dictionary) -> String:
	if message.has("club_mail"): return str(message.club_mail.get("expediteur", SENDERS.Club))
	if message.has("press_invitation"): return "Service de presse"
	if message.has("international_event"): return "Sélections" if not app.Immersive.Selections.nation_only(app.model) else "Fédération"
	if message.has("calendar_notice"): return "Calendrier des compétitions"
	return SENDERS.get(message.get("category","Club"), SENDERS.Club)

## Date de réception connue (courrier du club, sélections, presse) ; vide pour les anciens messages du moteur.
static func _date(message: Dictionary) -> String:
	if message.has("club_mail"): return P.fixture_date({"date":message.club_mail.get("date")})
	if message.has("international_event"): return P.fixture_date({"date":message.international_event.get("date")})
	var context: Dictionary = message.get("press_invitation",{}).get("context",{})
	if context.has_all(["season","week"]): return "Sem. %d" % (int(context.week)+1)
	return ""

static func _row_id(message: Dictionary) -> String:
	if message.has("club_mail"): return "InboxClubMail_" + str(message.id).replace("-", "_")
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
	var width := DETAIL_WIDTH
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var category: String = message.get("category","Club")
	if category=="Médical":
		D.photo(card,"medical-recovery",Rect2(width-727,1,726,140))
		_art_fade(card,Rect2(0,0,width-727+359,142))
	else:
		var pitch := width-1-523-588
		D.photo(card,"mail-pitch",Rect2(pitch,1,588,140))
		_art_fade(card,Rect2(pitch,1,135,140))
		_art_fade(card,Rect2(pitch,1,588,45),false)
		D.photo(card,"mail-staff",Rect2(width-524,1,523,140))
		var blend := _art_fade(card,Rect2(width-524,1,154,140))
		blend.fill_from = Vector2(0,.23)
		blend.fill_to = Vector2(.25,.59)
	D.rect(card,Rect2(24,20,4,66),C.GOLD,3)
	D.text(card,46,48,category.to_upper(),28,C.IVORY,800,780)
	_icon(card,ICONS[category],Rect2(47,64,20,20),COLORS[category])
	var event: Dictionary = message.get("international_event", {})
	var source := "Journal de la sélection" if national else "Journal du club"
	if not event.is_empty(): source = "Sélections"
	D.text(card,78,82,source,18,C.IVORY,500,690)
	var title := "Le courrier de la sélection" if national else "Le courrier du club"
	if not message.is_empty(): title = str(message.get("subject",_subject(message.text)))
	D.text(card,32,184,title,30,C.IVORY,700,width-64)
	if not message.is_empty():
		var reading := Reading.status(message, app.model)
		D.chip(card,Rect2(32,101,420,30),("URGENT · " if reading.urgent else "") + str(reading.label),C.ALERT if reading.urgent else C.GOLD)
		var date := _date(message)
		D.text(card,32,220,"De : " + _sender(app,message) + ("" if date.is_empty() else "  ·  " + date),18,C.MUTED,500,width-64)
	D.line(card,Vector2(26,236),Vector2(width-26,236),Color(C.LINE,.7))
	# Pied du mail : réponses et actions, toujours visibles en bas.
	var reply := _reply_row(app, message)
	var height := _height(state)
	var footer_top := height - 26 - (reply + _h(46) + 10 + _h(44))
	var focused := message.has("press_invitation") or message.has("calendar_notice") or message.has("club_mail") or not event.is_empty()
	var attachments := _attachments(card,app,state,message,0,focused,false)
	if footer_top - 30 - attachments - 252 < 80: # Fenêtre basse : les priorités de la semaine restent au Bureau.
		focused = true
		attachments = _attachments(card,app,state,message,0,focused,false)
	var body := C.wrap(message.get("text","Aucun message à afficher dans ce dossier."),22,C.IVORY)
	body.name = "InboxMessageText"
	C.fill(body)
	var scroll := ScrollContainer.new()
	scroll.name = "InboxReadingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var pixels := body.get_theme_font_size("font_size")
	var text_height := body.get_theme_font("font").get_multiline_string_size(body.text,HORIZONTAL_ALIGNMENT_LEFT,C.px(width-80),pixels,-1,TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y / C.density
	var room := footer_top - 30 - attachments - 252
	var body_height := clampf(text_height+18,52,maxf(52,room))
	D.place(scroll,Rect2(34,252,width-68,body_height))
	scroll.add_child(body)
	_attachments(card,app,state,message,252+body_height+18,focused,true)
	if not message.is_empty():
		D.rect(card,Rect2(1,footer_top-16,width-2,height-footer_top+15),Color(C.PANEL,.55),0)
		D.line(card,Vector2(1,footer_top-16),Vector2(width-1,footer_top-16),Color(C.LINE,.8))
		_actions(card,app,state,message,int(footer_top))
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
				var action := D.button(card,Rect2(26,top,HALF,_h(46)),caption,_open_related.bind(app, message, app._open_press_invitation.bind(invitation.id)),true,"arrow",false,app.accent,"InboxOpenPressInvitation")
				action.disabled = app.waiting or (not receipt and (not conference.get("available", false) or conference.get("invitationId") != invitation.id))
				if action.disabled: action.tooltip_text = str(conference.get("reason", ""))
	elif message.has("club_mail"):
		_club_mail_actions(card, app, state, message, top)
	elif message.get("calendar_notice", {}).get("status") == "pending":
		var recalibrate := D.button(card,Rect2(26,top,HALF,_h(46)),"Recaler la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"recalibrate"),true,"calendar",false,app.accent,"InboxRecalibratePreparation")
		var keep := D.button(card,Rect2(26+HALF+18,top,HALF,_h(46)),"Conserver la préparation",
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
					D.button(card,Rect2(26,top,HALF,_h(46)),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenInternational")
			elif destination in ["international", "national_job"]:
				var caption := "Voir les offres de sélection" if destination == "national_job" else "Ouvrir les sélections"
				if _has_match_sheet(app, event): caption = "Préparer la feuille de match"
				elif _is_club_return(app, event): caption = "Voir l’effectif"
				D.button(card,Rect2(26,top,HALF,_h(46)),caption,_open_related.bind(app, message, _open_international.bind(app,event)),true,"arrow",false,app.accent,"InboxOpenInternational")
		else:
			var caption := "Ouvrir · " + str(message.route)
			var open := Callable(app, "_navigate").bind(message.route)
			if message.get("season_expiry", false):
				var current := _current_expiry_roster(app.model)
				if not current.is_empty():
					caption = "Voir les échéances actuelles (%d)" % current.count
					open = _open_expiry_roster.bind(app, current.roster)
			D.button(card,Rect2(26,top,HALF,_h(46)),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenMessageAction")
		D.button(card,Rect2(26+HALF+18,top,HALF,_h(46)),"Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité",func():
			mark.archived=not mark.get("archived",false)
			mark.read=true
			state.marks[message.id]=mark
			_redraw(app,"InboxFolder"+str(state.folder)),false,"check",false,app.accent,"InboxToggleArchive")
	var below := top + _h(46) + 10 + _reply_row(app, message)
	D.button(card,Rect2(26,below,340,_h(44)),"Retirer des favoris" if mark.get("favorite",false) else "Ajouter aux favoris",func():
		mark.favorite=not mark.get("favorite",false)
		state.marks[message.id]=mark
		_redraw(app,"InboxToggleFavorite"),false,"star",true,app.accent,"InboxToggleFavorite")
	if not mark.get("archived",false):
		D.button(card,Rect2(382,below,340,_h(44)),"Marquer non lu" if mark.get("read",false) else "Marquer lu",func():
			mark.read=not mark.get("read",false)
			state.marks[message.id]=mark
			_redraw(app,"InboxToggleRead"),false,"mail",true,app.accent,"InboxToggleRead")

## Courrier du club : une rangée de réponses (si le mail en attend une), puis l'écran concerné et le classement.
static func _club_mail_actions(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: int) -> void:
	var mail: Dictionary = message.club_mail
	var mark: Dictionary = state.marks.get(message.id,{})
	var y := top
	if ClubMail.awaiting(app.model, mail):
		var options: Array = mail.get("reponses", [])
		var count := options.size()
		var width := (DETAIL_WIDTH - 52.0 - 16.0 * (count - 1)) / count
		for index in count:
			var option: Dictionary = options[index]
			var action := D.button(card,Rect2(26+index*(width+16),y,width,_h(46)),str(option.get("libelle","")),
				_reply_club_mail.bind(app,str(mail.id),str(option.get("id",""))),index==0,"check",false,app.accent,"InboxClubMailReply_" + str(option.get("id","")))
			action.disabled = app.waiting or not option.get("disponible", false)
			var detail := str(option.get("effets",""))
			action.tooltip_text = (detail if not detail.is_empty() else "Sans effet chiffré.") + ("" if option.get("disponible", false) else "\n" + str(option.get("raison","")))
		y += _h(46) + 10
	var ecran := str(mail.get("ecran",""))
	var joueur := str(mail.get("joueur","")) if mail.get("joueur") is String else ""
	D.button(card,Rect2(26,y,HALF,_h(46)),ClubMail.caption(ecran),_open_related.bind(app, message, ClubMail.open_screen.bind(app, ecran, joueur)),y==top,"arrow",false,app.accent,"InboxClubMailOpen")
	D.button(card,Rect2(26+HALF+18,y,HALF,_h(46)),"Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité",func():
		mark.archived=not mark.get("archived",false)
		mark.read=true
		state.marks[message.id]=mark
		_redraw(app,"InboxFolder"+str(state.folder)),false,"check",false,app.accent,"InboxToggleArchive")

## Hauteur de la rangée de réponses d'un mail du club qui en attend une (0 sinon).
static func _reply_row(app: Control, message: Dictionary) -> float:
	return _h(46) + 10 if message.has("club_mail") and ClubMail.awaiting(app.model, message.club_mail) else 0.0

static func _reply_club_mail(app: Control, mail_id: String, choice: String) -> void:
	ClubMail.reply(app, mail_id, choice)

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
	if is_instance_valid(scroll) and not focus.begins_with("InboxFolder") and not focus.begins_with("InboxCategory") and focus!="InboxSort" and focus!="InboxSubject":
		state.scroll = scroll.scroll_vertical
	app._render()
	var action: Control = app.root_content.find_child(focus,true,false)
	if action == null: action=app.root_content.find_child("InboxFolder"+str(state.folder),true,false)
	if action != null: _focus.call_deferred(action)

static func _focus(action: Control) -> void:
	if is_instance_valid(action) and action.is_inside_tree(): action.grab_focus()
