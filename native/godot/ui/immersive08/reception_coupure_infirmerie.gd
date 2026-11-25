extends RefCounted
## Réception, gabarits d'un courrier : coupure de journal (presse) et bilan de l'infirmerie (médical).
const BanqueImages = preload("res://ui/banque_images.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const CompteRendu = preload("res://ui/immersive08/compte_rendu_carte.gd")
const Canvas = preload("res://ui/immersive08/reception_canvas.gd")

## Coupure de journal : carte crème, titre du média, rubrique, grand titre, chapeau en italique, texte sur deux
## colonnes, photo seulement si la banque d'images en a une pour ce papier (aucun cadre vide).
static func _clipping(app: Control, message: Dictionary, mail: Dictionary, width: float) -> Control:
	var ink := C.Charte.ENCRE
	var paper := PanelContainer.new()
	paper.name = "InboxPressClipping"
	var style := C.box(C.Charte.PAPIER, Color.TRANSPARENT, 0, 34)
	# Coupure de presse : une carte posée sur la lettre, ombre portée de la charte (choix de Léo du 20/11/2026).
	paper.add_theme_stylebox_override("panel", C.Charte.ombrer(style, C.Charte.RAYON_CARTE))
	paper.custom_minimum_size.x = C.px(width)
	var column := C.v(10)
	paper.add_child(column)
	var masthead := C.h(16)
	var media := C.label(str(mail.get("expediteur", "La presse")), 40, ink, true, 800)
	media.name = "InboxPressMedia"
	C.fill(media)
	masthead.add_child(media)
	var stamp := Canvas._short_date(Canvas._day(message), "", true)
	var dateline := C.label(stamp.left(1).to_upper() + stamp.substr(1) + "\nRugby", 16, Color(ink,.7), false, 500)
	dateline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	masthead.add_child(dateline)
	column.add_child(masthead)
	var rule := ColorRect.new()
	rule.color = Color(ink,.85)
	rule.custom_minimum_size.y = maxi(2, C.px(4))
	column.add_child(rule)
	var rubrique := C.label(Canvas.RUBRIQUES.get(str(mail.get("type", "")), "SPORT"), 17, C.Charte.D_PAPIER, true, 700)
	rubrique.name = "InboxPressRubrique"
	column.add_child(rubrique)
	var headline := C.wrap(str(mail.get("sujet", message.get("subject", ""))), 54, ink, true, 800)
	headline.name = "InboxPressHeadline"
	column.add_child(headline)
	# Compte rendu du match en carte (idée FM n°19, choix de Léo du 23/11) : sur l'article du dernier match seulement.
	var carte_match: Control = CompteRendu.carte(app, mail, width - 68.0)
	if carte_match != null: column.add_child(carte_match)
	var paragraphs: Array[String] = []
	for part in str(mail.get("corps", "")).replace("\r", "").split("\n"):
		if not part.strip_edges().is_empty(): paragraphs.append(part.strip_edges())
	if paragraphs.size() > 1:
		var lead := C.wrap(paragraphs[0], 24, Color(ink,.82), false, 500)
		lead.name = "InboxPressLead"
		var slanted := FontVariation.new()
		slanted.base_font = C.BODY
		slanted.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		lead.add_theme_font_override("font", slanted)
		column.add_child(lead)
		paragraphs.remove_at(0)
	# Deux colonnes équilibrées au nombre de caractères.
	var total := 0
	for part in paragraphs: total += part.length()
	var left: Array[String] = []
	var right: Array[String] = []
	var used := 0
	for part in paragraphs:
		if used < total / 2.0 or left.is_empty(): left.append(part); used += part.length()
		else: right.append(part)
	if right.is_empty() and left.size() == 1 and left[0].length() > 220:
		var words := left[0].split(" ")
		var half := words.size() / 2
		right.append(" ".join(words.slice(half)))
		left[0] = " ".join(words.slice(0, half))
	var columns := C.h(28)
	columns.name = "InboxPressColumns"
	for side: Array in [left, right]:
		if side.is_empty(): continue
		var text := C.wrap("\n\n".join(PackedStringArray(side)), 22, ink, false, 500)
		text.add_theme_constant_override("line_spacing", C.px(5))
		C.fill(text)
		text.name = "InboxPressColumn%d" % columns.get_child_count()
		columns.add_child(text)
	var photo_id := Canvas.photo_resultat(str(mail.get("corps", "")) + " " + str(mail.get("sujet", "")))
	if photo_id != "mail-pitch" and BanqueImages.texture(photo_id) != null:
		var picture := C.photo(photo_id, Vector2(C.px(220), C.px(160)))
		picture.name = "InboxPressPhoto"
		picture.custom_minimum_size = Vector2(C.px(220), C.px(160))
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		columns.add_child(picture)
	column.add_child(columns)
	var answered := ClubMail.answer(app.model, mail)
	if not answered.is_empty() or str(mail.get("status", "")) == "classe":
		var after := str(message.get("text", "")).get_slice("\n\n— ", 1)
		var note := after.substr(after.find("\n\n") + 2) if after.find("\n\n") >= 0 else ""
		if not note.strip_edges().is_empty():
			var receipt := C.wrap(note.strip_edges(), 18, Color(ink,.75), false, 600)
			receipt.name = "InboxPressReceipt"
			column.add_child(receipt)
	return paper

## Marge à droite du texte de chaque colonne du tableau (px de mise en page), pour ne jamais coller la colonne voisine.
const INFIRMARY_GUTTER := 16.0
const INFIRMARY_COLUMNS := [["JOUEUR", .22], ["POSTE", .14], ["BLESSURE", .32], ["RETOUR ESTIMÉ", .16], ["PROCHAIN MATCH", .16]]

## Tableau de l'infirmerie (données réelles de la partie) : joueurs blessés et en reprise, retour estimé et statut
## pour la prochaine rencontre (forfait rouge, apte vert, risque doré).
static func infirmary_rows(model: Dictionary) -> Array[Dictionary]:
	var today := str(model.get("meta", {}).get("calendarToday", ""))
	var medical: Array = model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", [])
	var stages := {}
	for record: Variant in medical:
		if record is Dictionary: stages[str(record.get("id", ""))] = record
	var result: Array[Dictionary] = []
	for player: Dictionary in model.get("squad", []):
		var weeks := float(player.get("injury", 0)) if (player.get("injury") is int or player.get("injury") is float) else 0.0
		var record: Dictionary = stages.get(str(player.get("id", "")), {})
		var condition := float(player.get("condition", 100)) if (player.get("condition") is int or player.get("condition") is float) else 100.0
		var row := {"id":str(player.id), "name":str(player.get("name", "")), "pos":str(player.get("pos", "")), "weeks":weeks}
		if weeks > 0:
			row.injury = "%s · %s" % [ClubMail.injury_label(model, player), P.plural(ceili(weeks), "semaine", "semaines")]
			row.back = ("≈ " + Canvas._short_date(Canvas._shift(today, roundi(weeks * 7)), today, false)) if today.length() >= 10 else "%d sem." % ceili(weeks)
			row.status = "Forfait"; row.tone = "alert"
		elif str(record.get("stage", "")) == "reprise":
			var risky := condition < 80.0
			row.injury = "En reprise · condition %d %%" % roundi(condition)
			row.back = "Rétabli"
			row.status = "Risque" if risky else "Apte"; row.tone = "gold" if risky else "mint"
		elif condition < Canvas.INCERTAIN:
			row.injury = "Gêne · condition %d %%" % roundi(condition)
			row.back = "À évaluer"
			row.status = "Incertain"; row.tone = "gold"; row.weeks = -1.0
		else: continue
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.weeks) > float(b.weeks))
	return result

## Hauteur (px) d'un libellé à retour à la ligne, à sa largeur minimale : lignes réelles de la police, sans coupure.
static func wrapped_height(label: Label) -> float:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var lines := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.custom_minimum_size.x - C.px(INFIRMARY_GUTTER), size, -1, flags).y
	return ceilf(lines) + C.px(10)

static func _infirmary(app: Control, width: float) -> Control:
	var table := C.v(0)
	table.name = "InboxInfirmary"
	var heading := C.label("BILAN DE L'INFIRMERIE", 20, C.GOLD, true, 700)
	table.add_child(heading)
	var rows := infirmary_rows(app.model)
	if rows.is_empty():
		var none := C.label("Aucun joueur à l'infirmerie : tout l'effectif est disponible.", 20, C.MINT, false, 500)
		none.name = "InboxInfirmaryEmpty"
		table.add_child(none)
		return table
	var columns := INFIRMARY_COLUMNS
	var header := C.h(0)
	for column: Array in columns:
		var cell := C.label(column[0], 16, C.FAINT.lightened(.15), true, 700)
		cell.custom_minimum_size = Vector2(C.px(width * float(column[1])), C.px(36))
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(cell)
	table.add_child(header)
	var tones := {"alert":C.ALERT, "gold":C.GOLD, "mint":C.MINT}
	# En-tête figé ; les lignes défilent dessous si elles dépassent INFIRMARY_MAX_ROWS (px de mise en page), aucune n'est masquée.
	var body := C.v(0)
	body.name = "InboxInfirmaryRows"
	var body_height := 0.0
	for index in rows.size():
		var data: Dictionary = rows[index]
		var line := ColorRect.new()
		line.color = Color(C.LINE,.5)
		line.custom_minimum_size.y = 1
		body.add_child(line)
		body_height += 1.0
		var row := C.h(0)
		row.name = "InboxInfirmaryRow_%d" % index
		var row_height := 0.0
		row.set_meta("player_id", data.id)
		var values := [[data.name, C.IVORY, 700], [data.pos, C.MUTED, 500], [data.injury, C.MUTED, 500], [data.back, C.IVORY, 500], [data.status, tones[data.tone], 700]]
		for column in values.size():
			var cell: Control
			if column == 0 and Link.available(app, "player", data.id):
				# Nom du joueur : lien vers sa fiche (mini-fiche au survol), souligné d'emblée.
				var name_button := C.button(str(values[column][0]), func(): pass)
				Link.bind(name_button, app, Link.target("player", data.id), str(values[column][0]))
				C.style_bouton_lien(name_button, 21, true)
				MiniFiche.lier(app, name_button, str(data.id), "squad")
				name_button.name = "InboxInfirmaryPlayer_%d" % index
				name_button.set_meta("player_id", str(data.id))
				name_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cell = name_button
			else:
				cell = C.label(values[column][0], 21, values[column][1] if column != 0 else C.FAINT, column != 2 and column != 1, values[column][2] if column != 0 else 500)
			cell.custom_minimum_size = Vector2(C.px(width * float(columns[column][1])), C.px(48))
			cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if cell is Button:
				row.add_child(cell)
				row_height = maxf(row_height, cell.custom_minimum_size.y)
				continue
			var gutter := StyleBoxEmpty.new()
			gutter.content_margin_right = C.px(INFIRMARY_GUTTER)
			cell.add_theme_stylebox_override("normal", gutter)
			# Retour à la ligne plutôt que coupure : la hauteur de la ligne suit le texte le plus long de la rangée.
			(cell as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(cell as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			cell.custom_minimum_size.y = maxf(cell.custom_minimum_size.y, wrapped_height(cell as Label))
			(cell as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if column == 4: cell.name = "InboxInfirmaryStatus"
			row.add_child(cell)
			row_height = maxf(row_height, cell.custom_minimum_size.y)
		body.add_child(row)
		body_height += row_height
	var scroll := ScrollContainer.new()
	scroll.name = "InboxInfirmaryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(body_height, C.px(Canvas.INFIRMARY_MAX_ROWS))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	table.add_child(scroll)
	return table
