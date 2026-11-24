extends RefCounted
## Réception, colonne de gauche : filtres (catégorie, sujet, état), liste groupée par jour et ligne d'un courrier.
const C = preload("res://ui/immersive08/components.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Portraits = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Messages = preload("res://ui/immersive08/reception_messages.gd")
const AgentJoueur = preload("res://ui/agent_joueur.gd")
const Canvas = preload("res://ui/immersive08/reception_canvas.gd")

## En tête de la liste : une seule rangée (Tous · Non lus · À faire) et un menu « Sujet » qui regroupe
## les services, les favoris, les archives et les états rares (En attente, Infos).
static func _list_filters(card: Panel, app: Control, state: Dictionary, active: Array, all_subjects: Array) -> void:
	var todo: int = Reading.counts(active, app.model).todo
	# [légende, nom du bouton, dossier, état, infobulle]
	var filters := [
		["Tous", "InboxFolder0", 0, "all", "Tous les messages"],
		["Non lus %d" % Canvas.unread(app), "InboxFolder1", 1, "all", "Messages non lus"],
		["À faire %d" % todo, "InboxActivity_todo", 0, "todo", Reading.LABELS.todo + ". Les messages sans décision explicite restent des informations."],
	]
	# Pastilles à la taille de leur texte, menu « Sujet » sur le reste de la rangée (aucun recouvrement en petite fenêtre).
	var bar := C.h(8)
	bar.name = "InboxFilterRow"
	card.add_child(bar)
	D.place(bar, Rect2(14,Canvas._header_rows()[0],Canvas.LIST_WIDTH-28,Canvas._h(44)))
	# Bandeau des filtres (demande de Léo du 21/11/2026) : la rangée de filtres dans un panneau teinté détouré.
	Bandeau.poser(card, Rect2(6, Canvas._header_rows()[0] - 8, Canvas.LIST_WIDTH - 12, Canvas._h(44) + 16))
	for index in filters.size():
		var filter: Array = filters[index]
		var folder: int = filter[2]
		var activity: String = filter[3]
		var id: String = filter[1]
		var chosen: bool = state.folder == folder and state.activity_filter == activity
		var action := C.button(filter[0], func():
			state.folder = folder
			state.activity_filter = activity
			state.category = "Tous"
			if activity != "all": state.selected = ""
			state.scroll = 0
			Canvas._redraw(app,id), false, app.accent)
		action.name = id
		action.alignment = HORIZONTAL_ALIGNMENT_CENTER
		action.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
		action.custom_minimum_size = Vector2(C.px(84), 0)
		for look in ["normal", "hover", "pressed", "focus"]:
			# Charte finale : filtre actif = pilule en aplat crème, texte panneau ; inactif = pilule à contour.
			var pill := C.box(C.IVORY if chosen else C.RAISED if look == "hover" else Color(C.PANEL, 0), C.Charte.OR if look == "focus" else Color.TRANSPARENT if chosen else C.LINE, C.Charte.RAYON_PILULE, 16)
			pill.content_margin_top = 0; pill.content_margin_bottom = 0
			action.add_theme_stylebox_override(look, pill)
		action.tooltip_text = filter[4]
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			action.add_theme_color_override(key, C.Charte.PANNEAU if chosen else C.Charte.IVOIRE)
		bar.add_child(action)
	var subject := OptionButton.new()
	subject.name = "InboxSubject"
	subject.fit_to_longest_item = false
	subject.clip_text = true
	subject.add_theme_font_override("font",C.BOLD)
	subject.add_theme_font_size_override("font_size",maxi(12,C.px(18)))
	subject.tooltip_text = "Sujet : services du club, favoris, archives, messages en attente ou d'information"
	var entries: Array = []
	for category: String in Canvas.SUBJECTS:
		var count := all_subjects.size() if category == "Tous" else all_subjects.filter(func(message: Dictionary): return message.category == category).size()
		entries.append({"kind":"category", "value":category, "label":("Tous les sujets" if category == "Tous" else category) + " (%d)" % count, "short":"Sujet : tous" if category == "Tous" else "Sujet : " + category})
	var chosen_entry := -1
	for index in entries.size():
		if entries[index].kind == "category" and entries[index].value == state.category: chosen_entry = index
	var extra_selected: bool = state.folder != 3 and state.activity_filter in ["waiting", "info"]
	for index in entries.size():
		subject.add_item(entries[index].label, index)
	subject.add_separator()
	var statuses := {"waiting":Reading.counts(active, app.model).waiting, "info":Reading.counts(active, app.model).info}
	for extra: Array in Canvas.SUBJECT_EXTRAS:
		var count_text := ""
		match extra[0]:
			"archives": count_text = " (%d)" % Canvas.messages_archived(app)
			"favorites": count_text = " (%d)" % active.filter(func(item: Dictionary): return state.marks.get(item.id, {}).get("favorite", false)).size()
			_: count_text = " (%d)" % statuses[extra[0]]
		entries.append({"kind":extra[0], "value":extra[0], "label":str(extra[1]) + count_text, "short":"Sujet : " + str(extra[1])})
		subject.add_item(entries[-1].label, entries.size() - 1)
		if (extra[0] == "archives" and state.folder == 3) or (extra[0] == "favorites" and state.folder == 2) or (extra[0] in ["waiting", "info"] and extra_selected and state.activity_filter == extra[0]): chosen_entry = entries.size() - 1
	subject.select(subject.get_item_index(maxi(chosen_entry, 0)))
	subject.text = entries[maxi(chosen_entry, 0)].short
	subject.item_selected.connect(func(index: int):
		var entry: Dictionary = entries[subject.get_item_id(index)]
		match entry.kind:
			"category":
				state.category = entry.value
				if state.folder >= 2: state.folder = 0
				if state.activity_filter in ["waiting", "info"]: state.activity_filter = "all"
			"archives", "favorites":
				state.folder = 3 if entry.kind == "archives" else 2
				state.category = "Tous"
				state.activity_filter = "all"
			_:
				state.folder = 0
				state.activity_filter = entry.kind
				state.selected = ""
		state.scroll = 0
		Canvas._redraw(app,"InboxSubject"))
	# Menu aux jetons de la charte : fond sombre, bordure fine, rayon 0, texte ivoire ; la fenêtre du menu suit.
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var skin := C.box(C.RAISED if look in ["hover", "pressed"] else C.PANEL, C.IVORY if look == "focus" else C.LINE, 0, 10)
		subject.add_theme_stylebox_override(look, skin)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: subject.add_theme_color_override(key, C.IVORY)
	var menu := subject.get_popup()
	menu.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 0, 6))
	menu.add_theme_stylebox_override("hover", C.box(C.SELECTED, Color.TRANSPARENT, 0, 6))
	menu.add_theme_font_override("font", C.BODY)
	menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for key in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(key, C.IVORY)
	menu.add_theme_color_override("font_separator_color", C.FAINT)
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject.custom_minimum_size.x = C.px(120)
	bar.add_child(subject)

static func _list(card: Panel, app: Control, state: Dictionary, messages: Array, entries: Array) -> void:
	var top := Canvas._header_rows()[1]
	D.line(card,Vector2(0,top),Vector2(Canvas.LIST_WIDTH,top),Color(C.LINE,.6))
	var scroll := ScrollContainer.new()
	scroll.name = "InboxMessageScroll"
	scroll.tooltip_text = "↑ ↓ choisir · Entrée ouvrir le courrier"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(0,top+1,Canvas.LIST_WIDTH,Canvas._height(state)-top-2))
	var rows := C.v(0)
	rows.name = "InboxMessageRows"
	C.fill(rows)
	scroll.add_child(rows)
	if messages.is_empty():
		D.text(card,26,top+52,"Aucun message dans cette vue.",24,C.MUTED,600,Canvas.LIST_WIDTH-52)
		D.text(card,26,top+90,"Choisis un autre filtre.",19,C.MUTED,400,Canvas.LIST_WIDTH-52,HORIZONTAL_ALIGNMENT_LEFT,true)
	var section := ""
	var sections := 0
	for entry: Dictionary in entries:
		var linked: Array = entry.messages
		if entry.section != section:
			section = entry.section
			_day_heading(rows, section, sections)
			sections += 1
		if linked.size() > 1:
			var default_open: bool = linked.any(func(item: Dictionary): return item.id == state.selected or Reading.status(item, app.model).key == "todo")
			var opened: bool = state.expanded_threads.get(entry.key, default_open)
			var title: String = str(linked[0].get("subject",linked[0].category))
			var notice: Dictionary = linked[0].get("calendar_notice",{})
			if not str(notice.get("opponent","")).is_empty(): title += " · " + str(notice.opponent)
			var context: Dictionary = linked[0].get("press_invitation",{}).get("context",{})
			if context.has_all(["season","week"]): title += " · %s / sem. %d" % [SeasonLabel.label(context.season),int(context.week)+1]
			var group_id := "InboxThread_" + str(entry.key).sha256_text().left(12)
			var key: String = entry.key
			var toggle := C.button(("▾ " if opened else "▸ ") + "%s · %d courriers" % [title,linked.size()], func():
				state.expanded_threads[key] = not opened
				Canvas._redraw(app, group_id), false, app.accent)
			toggle.add_theme_font_size_override("font_size", maxi(12, C.px(17)))
			toggle.custom_minimum_size.y = C.px(38)
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.clip_text = true
			toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			toggle.name = group_id
			toggle.set_meta("thread_key", key)
			toggle.tooltip_text = "Déplier ou réduire les courriers de la même rencontre, édition ou conférence"
			toggle.add_theme_stylebox_override("normal", C.box(Color(C.PANEL, 0), Color(C.LINE, .35), 0, 16))
			rows.add_child(toggle)
			if not opened: continue
		for item: Dictionary in linked: _row(rows, app, state, item)
	_blocking_notice(rows, app)
	scroll.set_deferred("scroll_vertical",int(state.scroll))

## En-tête de jour dans la liste (« AUJOURD'HUI », « HIER », date).
static func _day_heading(rows: Control, caption: String, index: int) -> void:
	var box := MarginContainer.new()
	box.name = "InboxDay_%d" % index
	box.add_theme_constant_override("margin_left", C.px(22))
	box.add_theme_constant_override("margin_top", C.px(16 if index > 0 else 10))
	box.add_theme_constant_override("margin_bottom", C.px(6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := C.label(caption, 18, C.FAINT.lightened(.15), true, 700)
	label.name = "InboxDayLabel"
	box.add_child(label)
	rows.add_child(box)

## Une ligne de la liste, sur deux lignes (choix A de Léo, 23/11/2026) : pastille de catégorie colorée (icône + mot ;
## clic = filtre de la liste sur ce sujet), expéditeur et heure ; objet en gras si non lu, avec un point de la couleur
## de la catégorie ; étiquette « RÉPONSE REQUISE · échéance » (rouge, ⚠) et liseré rouge sur un courrier du club qui
## attend une décision, « À FAIRE » (doré) ou « ! URGENT » sinon.
static func _row(rows: Control, app: Control, state: Dictionary, message: Dictionary) -> void:
	var id := Canvas._row_id(message)
	var selected: bool = message.id == state.selected
	var mark: Dictionary = state.marks.get(message.id, {})
	var is_unread: bool = Canvas._any_unread(state.marks, message)
	var count := Canvas.members(message).size()
	var reading := Reading.status(message, app.model)
	var tagged: bool = reading.key == "todo" or reading.urgent
	var requise := tagged and Messages.attend(app, message)
	# Répondu (par toi ou par Gabi) : ligne normale, sans rouge, avec une marque sobre « ✓ RÉPONDU ».
	var repondu := not tagged and Messages.repondu(app, message)
	var width := Canvas.LIST_WIDTH - 16
	var height := 110.0 if tagged or repondu else 86.0
	var row := C.button("", func():
		state.selected = message.id
		state.press_opened = message.id if message.has("press_invitation") else ""
		if state.folder != 1: Canvas._mark_members(state, message, "read", true)
		Canvas._redraw(app, id), false, app.accent)
	row.name = id
	row.gui_input.connect(_message_key.bind(app, message.id))
	row.custom_minimum_size = Vector2(width, height) * C.density
	row.tooltip_text = message.text
	row.set_meta("message_text", message.text)
	row.set_meta("message_id", message.id)
	row.set_meta("message_count", count)
	row.accessibility_name = "%s%s · %s · %s" % ["Non lu · " if is_unread else "", "Réponse requise" if requise else reading.label, message.get("subject", message.category), message.text]
	rows.add_child(row)
	load("res://ui/survol_ligne.gd").appliquer(row, selected, Color(C.PANEL, 0), app.accent)
	if requise:
		D.rect(row, Rect2(0, 0, width, height), Color(Messages.ROUGE_BANDE, .10), 0).name = "InboxRowRequired"
		D.rect(row, Rect2(0, 0, 4, height), Messages.ROUGE_BANDE, 0).name = "InboxRowRequiredRule"
	D.rect(row, Rect2(0, height - 1, width, 1), Color(C.LINE, .35), 1).name = "RowRule"
	var service := Canvas._service(message)
	var teinte := Messages.couleur(service)
	var filtre := func():
		state.category = str(message.get("category", "Tous"))
		if state.folder >= 2: state.folder = 0
		state.activity_filter = "all"
		state.scroll = 0
		Canvas._redraw(app, "InboxSubject")
	var hour := str(message.get("hour", ""))
	var meta_width := (84.0 if not hour.is_empty() else 0.0) + (30.0 if mark.get("favorite", false) else 0.0) + (54.0 if count > 1 else 0.0)
	if is_unread: D.rect(row, Rect2(14, 22, 12, 12), teinte, 6).name = "UnreadDot"
	var service_w := minf(Messages.largeur_pastille(service, 17), 220.0)
	var pill := Messages.pastille(row, Rect2(36, 12, service_w, 30), service, Canvas.SERVICE_ICONS.get(service, "home"), 17, filtre)
	pill.tooltip_text = service + " · " + Canvas._sender(app, message)
	# Courrier signé par un agent nommé : son visage devant son nom (même visage que dans sa fenêtre et la discussion).
	var sender_x := 36 + service_w + 12
	var agent := Canvas._mail_agent(app, message)
	if not agent.is_empty():
		AgentJoueur.poser_portrait(row, Rect2(sender_x, 12, 30, 30), agent, "InboxRowAgentFace").mouse_filter = Control.MOUSE_FILTER_IGNORE
		sender_x += 40
	D.text(row, sender_x, 33, Canvas._sender(app, message), 17, C.MUTED, 500, width - (sender_x - 36) - 48 - 20 - meta_width)
	var meta_x := width - 18
	if not hour.is_empty():
		D.text(row, meta_x, 33, hour, 16, C.FAINT.lightened(.2), 500, 80, HORIZONTAL_ALIGNMENT_RIGHT, true).name = "InboxRowHour"
		meta_x -= 86
	if mark.get("favorite", false):
		Canvas._icon(row, "star", Rect2(meta_x - 18, 16, 18, 18), C.GOLD)
		meta_x -= 28
	if count > 1:
		var badge := D.rect(row, Rect2(meta_x - 48, 14, 46, 24), Color(C.MUTED, .12), 12, Color(C.MUTED, .5))
		badge.name = "InboxRowCount"
		D.text(badge, 23, 18, "×%d" % count, 15, C.IVORY, 700, 44, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(row, 36, 72, message.get("subject", Canvas._subject(message.text)), 21, C.IVORY if is_unread else Color(C.IVORY, .62), 700 if is_unread else 500, width - 56)
	if tagged:
		var due := Canvas._deadline(app, message)
		var caption := ("RÉPONSE REQUISE" if requise else "! URGENT" if reading.urgent else "À FAIRE") + ("" if due.is_empty() else " · " + due.to_upper())
		var tone: Color = Messages.ROUGE_BANDE if requise or reading.urgent else C.GOLD
		var tag_width := minf(width - 56, C.font(700).get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(15))).x / C.density + 22 + (22 if requise else 0))
		# Doré : voile de la charte (jamais un aplat doré hors Continuer) ; rouge : voile de la bande « réponse requise ».
		var tag := D.rect(row, Rect2(36, 80, tag_width, 24), C.Charte.VOILE_DORE if tone == C.GOLD else Color(tone, .16), 6)
		tag.name = "InboxTodoTag"
		var tx := 10.0
		if requise:
			var alerte := C.icon("warning", C.px(16), tone)
			tag.add_child(alerte)
			D.place(alerte, Rect2(8, 4, 16, 16))
			tx = 30.0
		D.text(tag, tx, 18, caption, 15, tone, 700, tag_width - tx - 6)
	elif repondu:
		var marque := "✓ GABI A RÉPONDU" if ClubMail.delegated(app.model, message.club_mail) else "✓ RÉPONDU"
		var marque_w := C.font(700).get_string_size(marque, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(15))).x / C.density + 22
		var fait := D.rect(row, Rect2(36, 80, marque_w, 24), Color(C.Charte.GRIS_VERT, .12), 6)
		fait.name = "InboxRowAnswered"
		D.text(fait, 10, 18, marque, 15, C.Charte.GRIS_VERT, 700, marque_w - 14)

## Notice en tête de la liste : un rendez-vous obligatoire passe avant tout le reste (#810), avec un accès direct.
static func _blocking_notice(rows: Control, app: Control) -> void:
	var blocking := Canvas._blocking(app)
	if blocking.is_empty(): return
	var notice := C.v(6)
	notice.name = "ContextualInvitationsBlocked"
	var why := C.wrap("Rendez-vous obligatoire : termine " + app.contextual_director.meeting_label(blocking) + " avant d'avancer et d'ouvrir les invitations du club.",17,C.GOLD)
	C.fill(why)
	notice.add_child(why)
	if blocking.get("kind") == "press" and not blocking.get("completed", false):
		var go := C.button("OUVRIR LA CONFÉRENCE DE PRESSE", func(): app._open_press_conference(), false, app.accent)
		go.name = "ContextualOpenPress"
		go.add_theme_font_size_override("font_size", C.px(17))
		notice.add_child(go)
	rows.add_child(notice)
	rows.move_child(notice, 0)

## Pastille de l'expéditeur : icône du service dans la palette du jeu, ou vrai portrait d'une personne identifiée.
static func _sender_badge(parent: Control, app: Control, message: Dictionary, area: Rect2) -> void:
	var player := Canvas._sender_player(app, message)
	if not player.is_empty():
		var portrait := Portraits.portrait(int(player.get("portraitIndex",0)),C.px(area.size.x),player)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(portrait); D.place(portrait,area)
		return
	var service := Canvas._service(message)
	var color: Color = Canvas.COLORS.get(service, C.GOLD if service in ["Presse", "Sélections", "Calendrier", "Invitation"] else C.MUTED)
	var tile := D.rect(parent,area,Color(color,.12),8,Color(color,.5))
	tile.name = "SenderIcon"
	tile.tooltip_text = Canvas._sender(app, message)
	Canvas._icon(tile,Canvas.SERVICE_ICONS.get(service, "home"),Rect2(area.size.x*.2,area.size.y*.2,area.size.x*.6,area.size.y*.6),color)

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
