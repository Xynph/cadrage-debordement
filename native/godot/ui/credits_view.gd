extends RefCounted
## Crédits et mentions légales : texte tenu dans res://legal/credits.json (modifiable sans toucher au code).
## Les champs d'éditeur vides ne s'affichent pas ; ils sont à remplir avant une publication commerciale.
const C = preload("res://ui/immersive08/components.gd")
const SOURCE := "res://legal/credits.json"
const EDITEUR_LIBELLES := [["nom", "Éditeur"], ["forme", "Forme"], ["adresse", "Adresse"], ["contact", "Contact"], ["directeur_publication", "Directeur de la publication"]]

static func load_data() -> Dictionary:
	var file := FileAccess.open(SOURCE, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

## Lignes de l'éditeur réellement renseignées (vide tant que la publication n'est pas préparée).
static func editeur_lines(data: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var editeur: Variant = data.get("editeur", {})
	if not editeur is Dictionary: return lines
	for pair in EDITEUR_LIBELLES:
		var value := str(editeur.get(pair[0], "")).strip_edges()
		if not value.is_empty(): lines.append("%s : %s" % [pair[1], value])
	return lines

static func bbcode(data: Dictionary) -> String:
	var parts := PackedStringArray()
	var sections: Variant = data.get("sections", [])
	if sections is Array:
		for section in sections:
			if not section is Dictionary: continue
			parts.append("[font_size=%d][color=#%s][b]%s[/b][/color][/font_size]" % [maxi(16, C.px(21)), C.GOLD.to_html(false), _escape(str(section.get("titre", "")))])
			for line in section.get("lignes", []): parts.append(_escape(str(line)))
			parts.append("")
	var editeur := editeur_lines(data)
	if not editeur.is_empty():
		parts.append("[font_size=%d][color=#%s][b]Mentions légales[/b][/color][/font_size]" % [maxi(16, C.px(21)), C.GOLD.to_html(false)])
		for line in editeur: parts.append(_escape(line))
	if parts.is_empty(): parts.append("Crédits et licences complets dans le dossier Licences du jeu.")
	return "\n".join(parts).strip_edges()

static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

## Remplit une fenêtre déjà préparée par l'appelant (thème, taille, signaux).
static func fill(dialog: AcceptDialog) -> void:
	dialog.name = "CreditsDialog"
	dialog.title = "Rugby Legacy 27 · Crédits et mentions légales"
	dialog.ok_button_text = "Fermer"
	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 260)
	dialog.add_child(scroll)
	var text := RichTextLabel.new()
	text.name = "CreditsText"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", C.BODY)
	text.add_theme_font_override("bold_font", C.BOLD)
	text.add_theme_font_size_override("normal_font_size", maxi(14, C.px(17)))
	text.add_theme_font_size_override("bold_font_size", maxi(14, C.px(17)))
	text.add_theme_color_override("default_color", C.IVORY)
	text.text = bbcode(load_data())
	scroll.add_child(text)
