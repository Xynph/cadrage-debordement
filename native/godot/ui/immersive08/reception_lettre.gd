extends RefCounted
## Réception, colonne centrale : lettre ouverte (en-tête, texte avec liens, fil de lecture, courrier suivant) et mesures de hauteur.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Press = preload("res://ui/press_view.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
const Messages = preload("res://ui/immersive08/reception_messages.gd")
const Analyste = preload("res://ui/immersive08/analyste_match.gd")
const TestsPhysiques = preload("res://ui/immersive08/tests_physiques.gd")
const AgentJoueur = preload("res://ui/agent_joueur.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Canvas = preload("res://ui/immersive08/reception_canvas.gd")
const Concerne = preload("res://ui/immersive08/reception_concerne.gd")
const Coupure = preload("res://ui/immersive08/reception_coupure_infirmerie.gd")
const Reponses = preload("res://ui/immersive08/reception_reponses.gd")

const LETTER_PAD := 26.0

static func _is_word_char(character: String) -> bool:
	return character.to_lower() != character.to_upper() or character.is_valid_int()

## Joueurs et clubs cités dans un texte, prêts à devenir des liens : [{start, end, kind, id}], sans chevauchement,
## triés dans l'ordre du texte. Seules les entités qui ont un écran de destination sont rendues (jamais de lien mort).
static func entities(app: Control, text: String) -> Array:
	var candidates: Array = []
	var squad: Array = app.model.get("squad", [])
	var surnames := {}
	for player: Dictionary in squad:
		var words := str(player.get("name", "")).split(" ", false)
		if words.size() > 1: surnames[words[-1]] = int(surnames.get(words[-1], 0)) + 1
	for player: Dictionary in squad:
		var full := str(player.get("name", ""))
		if full.length() < 4: continue
		candidates.append([full, "player", str(player.get("id", ""))])
		var words := full.split(" ", false)
		if words.size() > 1 and words[-1].length() >= 5 and int(surnames.get(words[-1], 0)) == 1:
			candidates.append([words[-1], "player", str(player.get("id", ""))])
	var own: Dictionary = app.model.get("club", {})
	if own.has("id") and str(own.get("name", "")).length() >= 4: candidates.append([str(own.name), "club", str(own.id)])
	for division: Dictionary in app.model.get("leagues", []):
		for row: Dictionary in division.get("rows", []):
			var club := str(Press.G.club_name(row))
			if club.length() >= 4: candidates.append([club, "club", str(row.get("id", ""))])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).length() > str(b[0]).length())
	var taken: Array = []
	var found: Array = []
	var checked := {}
	for candidate: Array in candidates:
		var label := str(candidate[0])
		var from := 0
		while true:
			var start := text.find(label, from)
			if start < 0: break
			var end := start + label.length()
			from = end
			if start > 0 and _is_word_char(text[start - 1]): continue
			if end < text.length() and _is_word_char(text[end]): continue
			if taken.any(func(span: Array) -> bool: return start < int(span[1]) and end > int(span[0])): continue
			var key := "%s:%s" % [candidate[1], candidate[2]]
			if not checked.has(key): checked[key] = Link.available(app, str(candidate[1]), candidate[2])
			if not checked[key]: break
			taken.append([start, end])
			found.append({"start":start, "end":end, "kind":candidate[1], "id":candidate[2]})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.start) < int(b.start))
	return found

## Texte du courrier en BBCode : chaque entité citée devient un lien « kind:id » (couleur or-encre, soulignée).
static func linked_text(text: String, found: Array) -> String:
	var out := ""
	var cursor := 0
	var tone := C.Charte.OR_ENCRE.to_html(false)
	for item: Dictionary in found:
		out += text.substr(cursor, int(item.start) - cursor).replace("[", "[lb]")
		out += "[url=%s:%s][color=#%s]%s[/color][/url]" % [item.kind, item.id, tone, text.substr(int(item.start), int(item.end) - int(item.start)).replace("[", "[lb]")]
		cursor = int(item.end)
	return out + text.substr(cursor).replace("[", "[lb]")

## La lettre : le seul document « papier » de l'écran (charte §4.2). Titre, échéance (mot + symbole, jamais la couleur
## seule), filet, texte à l'encre ; noms de joueurs, de clubs en liens, mini-fiche au survol d'un joueur.
static func _letter(app: Control, message: Dictionary, width: float) -> PanelContainer:
	var paper := PanelContainer.new()
	paper.name = "InboxLetter"
	paper.add_theme_stylebox_override("panel", C.Charte.ombrer_droit(C.box(C.Charte.PAPIER, Color.TRANSPARENT, 0, int(LETTER_PAD))))
	var column := C.v(10)
	paper.add_child(column)
	var inner := C.px(width - 2.0 * LETTER_PAD)
	var total := 2.0 * C.px(LETTER_PAD)
	var children := 0
	# En-tête de lettre (maquette) : club en capitales espacées et date, puis titre en capitales italiques.
	var day := Canvas._day(message)
	var letterhead := str(app.model.get("club", {}).get("name", "")).to_upper() + ("" if day.is_empty() else " · " + Canvas._short_date(day, Canvas._today(app)).to_upper())
	if not C.dense() and not letterhead.strip_edges().is_empty() and letterhead != " · ":
		var head := C.wrap(letterhead, 16, C.Charte.ENCRE_2, true, 700)
		head.name = "InboxLetterhead"
		column.add_child(head)
		total += _label_height(head, inner)
		children += 1
	var title := C.wrap(str(message.get("subject", Canvas._subject(str(message.text)))).to_upper(), 42, C.Charte.ENCRE, true, 800)
	title.name = "InboxTitle"
	title.add_theme_font_override("font", C.Charte.TITRE_EXTRA_ITALIQUE)
	column.add_child(title)
	total += _label_height(title, inner)
	children += 1
	var due := Canvas._deadline(app, message, true)
	if not due.is_empty():
		var caption := C.wrap("À FAIRE · " + due, 20, C.Charte.OR_ENCRE, true, 700)
		caption.name = "InboxDeadline"
		column.add_child(caption)
		total += _label_height(caption, inner)
		children += 1
	var rule := ColorRect.new()
	rule.color = Color(C.Charte.ENCRE_2, .5)
	rule.custom_minimum_size.y = maxi(1, C.px(1))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	total += rule.custom_minimum_size.y
	children += 1
	var plain := str(message.get("text", ""))
	var pixels := maxi(12, C.px(24))
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var measured := C.BODY.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, float(inner), pixels, -1, flags)
	var line_height := C.BODY.get_height(pixels)
	var lines := maxi(1, roundi(measured.y / maxf(1.0, line_height))) + 1
	var body := RichTextLabel.new()
	body.name = "InboxMessageText"
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = false
	body.selection_enabled = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", C.BODY)
	body.add_theme_font_size_override("normal_font_size", pixels)
	body.add_theme_color_override("default_color", C.Charte.ENCRE)
	body.add_theme_constant_override("line_separation", C.px(9))
	body.custom_minimum_size.y = lines * (line_height + C.px(9))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = linked_text(plain, entities(app, plain))
	body.meta_hover_started.connect(func(meta: Variant):
		var parts := str(meta).split(":", true, 1)
		if parts.size() < 2 or parts[0] != "player": return
		var fiche := MiniFiche.montrer(app, parts[1], "squad", body)
		if fiche != null:
			var screen := app.get_viewport_rect().size
			var spot := app.get_viewport().get_mouse_position() + Vector2(12, 20)
			fiche.position = Vector2(clampf(spot.x, 8.0, maxf(8.0, screen.x - fiche.size.x - 8.0)), clampf(spot.y, 8.0, maxf(8.0, screen.y - fiche.size.y - 8.0))))
	body.meta_hover_ended.connect(func(_meta: Variant): MiniFiche.cacher(app, body))
	body.meta_clicked.connect(func(meta: Variant):
		var parts := str(meta).split(":", true, 1)
		if parts.size() < 2 or not is_instance_valid(app.navigation_controller): return
		Canvas._open_related(app, message, func(): app.navigation_controller.open_entity({"kind":parts[0], "id":parts[1]})))
	column.add_child(body)
	total += body.custom_minimum_size.y
	children += 1
	total += float(maxi(0, children - 1)) * C.px(10)
	paper.set_meta("hauteur_px", total)
	return paper

## Le mail ouvert : en-tête (service, expéditeur, date ; Favori, Lu, Archiver), grand titre, texte en colonne lisible
## (ou coupure de presse, ou bilan d'infirmerie), pièces liées, puis « TA RÉPONSE » et les actions en bas.
static func _detail(card: Panel, app: Control, state: Dictionary, message: Dictionary, height: float) -> void:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var reading_width := Canvas._reading_width()
	if message.is_empty():
		D.text(card,Canvas.PAD,92,"Le courrier de la sélection" if national else "Le courrier du club",44,C.IVORY,700,Canvas._w-2*Canvas.PAD)
		var empty := C.wrap("Aucun message à afficher dans ce dossier.",24,C.MUTED)
		empty.name = "InboxMessageText"
		card.add_child(empty); D.place(empty,Rect2(Canvas.PAD,130,reading_width,80))
		return
	var mark: Dictionary = state.marks.get(message.id,{})
	# En-tête : expéditeur, service et date ; actions de rangement à droite (la lettre vient dessous).
	var date := Canvas._day(message)
	var when := Canvas._short_date(date, Canvas._today(app)) if not date.is_empty() else Canvas._date(message)
	var tools_width := 3 * 150.0 + 2 * 10.0
	var hour := str(message.get("hour", ""))
	if not hour.is_empty() and not when.is_empty(): when += ", " + hour
	# Presse : le nom du journal n'apparaît qu'une fois, sur la coupure ; l'en-tête dit seulement « Presse » et la date.
	# Service en petites capitales puis expéditeur en casse normale (une seule fois si les deux se confondent), date dessous.
	var service := Canvas._service(message)
	var sender := service if not _press_mail(message).is_empty() else Canvas._sender(app,message)
	var head_width := Canvas._w-2*Canvas.PAD-tools_width-20
	# Agent de joueurs nommé (ui/agent_joueur.gd) : son portrait d'adulte, son nom cliquable (sa petite fenêtre), son agence.
	var agent := Canvas._mail_agent(app, message)
	var hx := Canvas.PAD
	if not agent.is_empty():
		var joueur := str(message.get("club_mail", {}).get("joueur", ""))
		var ouvrir_agent := func(): AgentJoueur.ouvrir(app, Canvas._inbox_page(card), str(agent.id), joueur)
		var portrait := AgentJoueur.poser_portrait(card, Rect2(Canvas.PAD, 20, 84, 84), agent, "InboxAgentPortrait", AgentJoueur.RANGS.get(str(agent.get("rang", "petite")), C.GOLD))
		Pieces.rendre_cliquable(portrait, Vector2(84, 84), ouvrir_agent, "InboxAgentPortraitLien", str(agent.get("nom", "")), str(agent.get("agence", "")), 8)
		hx = Canvas.PAD + 100
		head_width -= 100
	if sender == service:
		D.text(card,hx,56,sender,23,C.IVORY,700,head_width).name = "InboxSenderName"
	else:
		var caps := service.to_upper()
		var caps_width := C.font(700).get_string_size(caps, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
		D.text(card,hx,56,caps,16,C.MUTED,700,caps_width)
		var nom := D.text(card,hx+caps_width,56,sender,23,C.IVORY,700,head_width-caps_width)
		nom.name = "InboxSenderName"
		if not agent.is_empty():
			var largeur_nom := C.font(700).get_string_size(sender, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x + 8.0
			Pieces.rendre_cliquable(nom, Vector2(minf(largeur_nom, head_width - caps_width), 32), func(): AgentJoueur.ouvrir(app, Canvas._inbox_page(card), str(agent.id), str(message.get("club_mail", {}).get("joueur", ""))), "InboxAgentNomLien", sender, str(agent.get("agence", "")), 6)
	D.text(card,hx,86,when + ("" if agent.is_empty() else "  ·  " + str(agent.get("agence", ""))),19,C.MUTED,500,head_width)
	# Une coupure de presse n'a pas de lettre : l'échéance s'écrit alors dans l'en-tête (mot « À FAIRE », jamais la couleur seule).
	var press_due := Canvas._deadline(app, message, true)
	if not _press_mail(message).is_empty() and not press_due.is_empty():
		D.text(card,Canvas.PAD+420,86,"À FAIRE · " + press_due,19,C.IVORY,700,Canvas._w-2*Canvas.PAD-420-tools_width-20).name = "InboxDeadline"
	var x := Canvas._w - Canvas.PAD - tools_width
	var favorite := D.button(card,Rect2(x,40,150,Canvas._h(44)),"Favori" if not mark.get("favorite",false) else "Favori ★",func():
		Canvas._mark_members(state, message, "favorite", not mark.get("favorite",false))
		Canvas._redraw(app,"InboxToggleFavorite"),false,"star",true,app.accent,"InboxToggleFavorite")
	favorite.tooltip_text = "Retirer des favoris" if mark.get("favorite",false) else "Ajouter aux favoris"
	if not mark.get("archived",false):
		var read_toggle := D.button(card,Rect2(x+160,40,150,Canvas._h(44)),"Non lu" if mark.get("read",false) else "Lu",func():
			Canvas._mark_members(state, message, "read", not mark.get("read",false))
			Canvas._redraw(app,"InboxToggleRead"),false,"mail",true,app.accent,"InboxToggleRead")
		read_toggle.tooltip_text = "Marquer non lu" if mark.get("read",false) else "Marquer lu"
	var archive := D.button(card,Rect2(x+320,40,150,Canvas._h(44)),"Désarchiver" if mark.get("archived",false) else "Archiver",func():
		Canvas._mark_members(state, message, "archived", not mark.get("archived",false))
		Canvas._redraw(app,"InboxFolder"+str(state.folder)),false,"check",true,app.accent,"InboxToggleArchive")
	archive.tooltip_text = "Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité et ranger dans les archives"
	for tool: Button in [favorite, archive] + ([card.get_node_or_null("InboxToggleRead")] if card.get_node_or_null("InboxToggleRead") != null else []):
		C.style_bouton_lien(tool, 18)
	var press := _press_mail(message)
	# Contenu puis, juste dessous, pièces liées, « TA RÉPONSE » et actions ; rappel Espace en bas du mail.
	var hint_base := height - 22 - _context_bar()
	# Courrier du club : bande rouge « RÉPONSE REQUISE » en pied (un clic sur une réponse l'envoie), puis, une fois
	# répondu, bande de la réponse donnée (par toi ou par Gabi).
	var bande := Messages.hauteur_bande(app, message)
	if bande > 0.0: hint_base = height - bande + 8.0
	var focused := message.has("press_invitation") or message.has("calendar_notice") or message.has("club_mail") or message.has("scene_invitation") or message.has("international_event")
	var body_top := 106.0
	var concerned := Concerne._concerned_layout(app, message, reading_width)
	var footer := Canvas._h(46) + (float(concerned.height) + 14.0 if not concerned.is_empty() else 0.0)
	var probe := Panel.new()
	var attachments := Concerne._attachments(probe,app,state,message,0,focused,false,reading_width)
	if hint_base - 34 - footer - attachments - body_top < 200 and not focused:
		focused = true
		attachments = Concerne._attachments(probe,app,state,message,0,focused,false,reading_width)
	probe.free()
	var room := maxf(80.0, hint_base - 34 - footer - (attachments + 12 if attachments > 0 else 0.0) - 18 - body_top)
	var content_width := Canvas._w-2*Canvas.PAD
	var content: Control
	if not press.is_empty():
		content = Coupure._clipping(app, message, press, Canvas._w-2*Canvas.PAD-14)
	else:
		var column := C.v(22)
		column.name = "InboxReadingColumn"
		# La lettre porte l'ombre de la charte : un jeu de 4 px autour d'elle, sinon la zone qui défile la rogne.
		var marge := C.px(6) # plus que l'étendue de l'ombre (4 px), quelle que soit la densité
		var support := MarginContainer.new()
		support.name = "InboxLetterSupport"
		for cote: String in ["left", "right", "top", "bottom"]: support.add_theme_constant_override("margin_" + cote, marge)
		# Analyse vidéo du dernier match (revue FM27, idée 28) : le panneau de l'analyste remplace la lettre.
		var analyse: Control = Analyste.bloc_mail(app, message.get("club_mail", {}), content_width - 12.0) if message.get("club_mail") is Dictionary else null
		support.add_child(analyse if analyse != null else _letter(app, message, content_width - 12.0))
		column.add_child(support)
		# Tests de reprise du médecin (idée FM27 n° 36) : la liste des joueurs testés sous sa lettre.
		var tests: Control = TestsPhysiques.bloc_mail(app, message.get("club_mail", {}), content_width - 12.0) if message.get("club_mail") is Dictionary else null
		if tests != null: column.add_child(tests)
		if message.get("category") == "Médical" and not national and tests == null: column.add_child(Coupure._infirmary(app, reading_width))
		content = column
	C.fill(content)
	var natural := _clipping_height(content, C.px(Canvas._w-2*Canvas.PAD-14)) if not press.is_empty() else _column_height(content, C.px(content_width))
	var body_height := clampf(natural / C.density + 26, 80.0, room)
	var scroll := ScrollContainer.new()
	scroll.name = "InboxReadingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(Canvas.PAD,body_top,content_width,body_height))
	scroll.add_child(content)
	# Pied (pièces liées, réponses, actions) dans un calque propre : il suit le contenu si celui-ci s'avère plus haut.
	var top := body_top + body_height + 18
	var bottom := Panel.new()
	bottom.name = "InboxFooter"
	bottom.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bottom)
	var y := 0.0
	if attachments > 0:
		Concerne._attachments(bottom,app,state,message,y,focused,true,reading_width)
		y += attachments + 12
	Reponses._actions(bottom,app,state,message,int(y))
	y += Canvas._h(46)
	if not concerned.is_empty():
		y += 14.0
		Concerne._concerned_row(bottom, app, message, concerned, Canvas.PAD, y, reading_width)
		y += float(concerned.height)
	if bande > 0.0:
		var mail_id := str(message.club_mail.id)
		Messages.bande(card, app, message, Canvas._w, height, Canvas._deadline(app, message).to_upper(), Reading.status(message, app.model).key == "todo",
			func(choix: String): Reponses._reply_club_mail(app, mail_id, choix),
			_open_next.bind(app, str(message.get("id", ""))))
	else: _mail_context(card, app, message, when, height)
	D.place(bottom, Rect2(0, top, Canvas._w, y))
	# Plus de rappel « Espace : message non lu suivant » : dans la coque commune, Espace = Continuer partout.
	_settle_reading.call_deferred(scroll, bottom, (hint_base - 34) * C.density)

## Pied du courrier, collé au bas (maquette), sur UNE ligne : expéditeur, reçu, état, puis « Courrier suivant non lu → »
## en lien texte. Lecture seule ; il garde sa place même sous un mail court.
const CONTEXT_BAR := 50.0
const CONTEXT_GAP := 26.0

## Hauteur du pied : au moins celle d'une commande (en petite fenêtre, la cible minimale grandit).
static func _context_bar() -> float:
	return maxf(CONTEXT_BAR, C.reach(40) + 12.0)

static func _mail_context(card: Panel, app: Control, message: Dictionary, when: String, height: float) -> void:
	var width := Canvas._w - 2 * Canvas.PAD
	var box := Control.new()
	box.name = "InboxMailContext"
	card.add_child(box)
	D.place(box, Rect2(Canvas.PAD, height - 22 - _context_bar() + 8, width, _context_bar() - 8))
	D.line(box, Vector2(0, 0), Vector2(width, 0), Color(C.LINE, .7))
	var reading := Reading.status(message, app.model)
	var state := str(reading.get("label", "Information"))
	if reading.get("key") != "info" and not str(reading.get("reason", "")).is_empty(): state += " · " + str(reading.reason)
	var rows := [
		["Expéditeur", Canvas._sender(app, message), .34],
		["Reçu", when if not when.is_empty() else "Date non précisée", .26],
		["État", state, .40],
	]
	# Jamais grisé à tort : « suivant » = le premier non lu AUTRE que le courrier ouvert ; « Tout est lu » seulement s'il n'en reste aucun.
	var next := Canvas.next_unread(app, str(message.get("id", "")))
	var follow_width := 320.0
	var room := width - follow_width - 12.0
	var cursor := 0.0
	for index in rows.size():
		var cell := room * float(rows[index][2])
		var caption_width := C.font(600).get_string_size(rows[index][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10.0
		D.text(box, cursor, 36, rows[index][0], 16, C.MUTED, 600, caption_width)
		D.text(box, cursor + caption_width, 36, rows[index][1], 18, C.IVORY, 700, cell - caption_width - 12).name = "InboxMailContext_%d" % index
		cursor += cell
	if next.is_empty():
		D.text(box, width, 36, "Tout est lu", 18, C.FAINT, 600, follow_width, HORIZONTAL_ALIGNMENT_RIGHT).name = "InboxMailContextNext"
		return
	var follow := D.button(box, Rect2(width - follow_width, 4, follow_width, C.reach(40)), "Courrier suivant non lu", _open_next.bind(app, str(message.get("id", ""))), false, "arrow", true, app.accent, "InboxMailContextNext")
	C.style_bouton_lien(follow, 18)
	follow.alignment = HORIZONTAL_ALIGNMENT_RIGHT

## Ouvre le prochain courrier non lu de la liste affichée (bouton « Courrier suivant non lu »).
static func _open_next(app: Control, current_id: String = "") -> void:
	if Canvas.open_next_unread(app, current_id): app._render()

## Une fois le contenu mis en page : si sa hauteur réelle dépasse la mesure, la zone de lecture grandit (dans la
## place libre au-dessus du rappel Espace) et le pied descend d'autant ; aucun défilement inutile.
static func _settle_reading(scroll: ScrollContainer, footer: Control, limit: float) -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree(): return
	var tree := scroll.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(footer) or scroll.get_child_count() == 0: return
	var content := scroll.get_child(0) as Control
	var missing := content.get_combined_minimum_size().y + 4.0 - scroll.size.y
	var spare := limit - (footer.position.y + footer.size.y)
	# Le dossier du courrier ne complète qu'un mail court : il cède sa place si le texte en a besoin.
	var extra := footer.get_node_or_null("InboxMailContext") as Control
	if missing > spare and extra != null:
		footer.size.y = maxf(0.0, extra.position.y - C.px(CONTEXT_GAP))
		footer.remove_child(extra)
		extra.queue_free()
		spare = limit - (footer.position.y + footer.size.y)
	var grow := minf(missing, spare)
	if grow <= 0.5: return
	scroll.size.y += grow
	footer.position.y += grow

## Hauteur (px) d'un contenu à largeur donnée, mesurée tout de suite (conteneurs triés hors de l'arbre) :
## les réponses se placent juste sous le contenu, sans attendre une image.
static func _measure(control: Control, width: float) -> float:
	for attempt in 3:
		control.size = Vector2(width, 0)
		_sort_now(control)
	return control.get_combined_minimum_size().y

## Hauteur (px) de la coupure de presse : somme de ses blocs, chaque texte mesuré à sa vraie largeur.
static func _clipping_height(paper: Control, width: float) -> float:
	var pad := C.px(34)
	var inner := width - 2.0 * pad
	var column := paper.get_child(0) as Container
	var gap := float(column.get_theme_constant("separation"))
	var total := 2.0 * pad + gap * maxf(0.0, column.get_child_count() - 1)
	for block: Node in column.get_children():
		if block.name == "InboxPressColumns":
			var texts: Array = block.get_children().filter(func(n: Node): return n is Label)
			var photo := block.find_child("InboxPressPhoto", false, false) as Control
			var spacing := float((block as Container).get_theme_constant("separation"))
			var photo_width := photo.custom_minimum_size.x if photo != null else 0.0
			var share := (inner - photo_width - spacing * maxf(0.0, block.get_child_count() - 1)) / maxf(1.0, texts.size())
			var tallest := photo.custom_minimum_size.y if photo != null else 0.0
			for text: Label in texts: tallest = maxf(tallest, _label_height(text, share))
			total += tallest
		elif block is Label: total += _label_height(block, inner)
		elif block is HBoxContainer:
			var tallest := 0.0
			for part: Node in block.get_children(): if part is Label: tallest = maxf(tallest, _label_height(part, inner / 2.0 if part.autowrap_mode != TextServer.AUTOWRAP_OFF else inner))
			total += tallest
		else: total += (block as Control).get_combined_minimum_size().y
	return total + C.px(8)

## Hauteur (px) de la colonne de lecture : texte mesuré à sa largeur, tableau sans retour à la ligne.
static func _column_height(column: Control, width: float) -> float:
	var total := float((column as Container).get_theme_constant("separation")) * maxf(0.0, column.get_child_count() - 1)
	for block: Node in column.get_children():
		if block is Label: total += _label_height(block, width)
		elif block.has_meta("hauteur_px"): total += float(block.get_meta("hauteur_px"))
		elif block is MarginContainer and block.get_child_count() == 1 and block.get_child(0).has_meta("hauteur_px"):
			# Lettre posée dans son support à marges (ombre de la charte) : sa hauteur connue plus les marges haute et basse.
			total += float(block.get_child(0).get_meta("hauteur_px")) + float(block.get_theme_constant("margin_top") + block.get_theme_constant("margin_bottom"))
		else: total += (block as Control).get_combined_minimum_size().y
	return total + C.px(6)

static func _label_height(label: Label, width: float) -> float:
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF: return label.get_minimum_size().y
	label.size = Vector2(width, 0)
	return label.get_minimum_size().y

static func _sort_now(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort_now(child)

## Paragraphes aérés : une ligne vide entre deux paragraphes du moteur.
static func _airy(text: String) -> String:
	var lines := text.replace("\r", "").split("\n")
	var out: Array[String] = []
	for line in lines:
		if line.strip_edges().is_empty():
			if not out.is_empty() and out[-1] != "": out.append("")
		else: out.append(line)
	return "\n".join(PackedStringArray(out))

## Courrier de presse du club (catégorie « presse » du moteur) : vide sinon.
static func _press_mail(message: Dictionary) -> Dictionary:
	var mail: Dictionary = message.get("club_mail", {})
	return mail if str(mail.get("categorie", "")) == "presse" else {}
