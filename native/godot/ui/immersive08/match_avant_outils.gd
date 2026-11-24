extends "res://ui/immersive08/match_avant_socle.gd"
## Écran « Avant-match » (voir match_avant.gd) — Outils partagés par les parties de l'écran : pastilles de résultat, phrases et icônes de météo, jauge de l'arbitre, cadre des tuiles de vérification.

## Pastille de résultat : lettre dedans, forme différente par résultat (V plein, N carré arrondi, D anneau) ; un bouton.
static func pastille(result: String, size: float) -> Button:
	var bouton := Button.new()
	bouton.name = "Pastille" + result
	bouton.text = result
	bouton.set_meta("immersive_style_applied", true)
	bouton.custom_minimum_size = Vector2(M(size), M(size))
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_font_size_override("font_size", maxi(12, M(size * .5)))
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# D : rouge de perte, comme au Classement (choix de Léo du 21/11/2026), toujours avec la lettre D et l'anneau.
	var couleur := Charte.V if result == "V" else Charte.PERTE if result == "D" else Charte.N
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var anneau := result == "D"
		style.bg_color = Color(Charte.NUIT, .6) if anneau else couleur
		style.border_color = Charte.IVOIRE if look in ["hover", "focus"] else couleur
		style.set_border_width_all(M(3) if look in ["hover", "focus"] else (M(2) if anneau else 0))
		if result == "N": style.set_corner_radius_all(M(6))
		else: style.set_corner_radius_all(M(size / 2.0))
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		bouton.add_theme_stylebox_override(look, style)
	# D : anneau rouge, lettre crème.
	var encre := Charte.IVOIRE if result == "D" else Charte.NUIT
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: bouton.add_theme_color_override(key, encre)
	return bouton

## « 1 V · 0 N · 3 D » (ou « 1 V – 3 D » sans nul).
static func bilan_court(bilan: Dictionary, avec_nuls: bool = false) -> String:
	var parts: Array[String] = ["%d V" % int(bilan.get("victoires", 0))]
	if avec_nuls or int(bilan.get("nuls", 0)) > 0: parts.append("%d N" % int(bilan.get("nuls", 0)))
	parts.append("%d D" % int(bilan.get("defaites", 0)))
	return " · ".join(parts) if avec_nuls else " – ".join(parts)

## Phrase du vent : « dans le dos de X en 1re période, dans le nôtre après la pause ».
static func phrase_vent(next: Dictionary, nous: int) -> String:
	var annonce := MeteoTexte.annonce(next)
	var premiere := MeteoTexte.camp_vent(annonce, 1)
	if premiere < 0: return ""
	var seconde := MeteoTexte.camp_vent(annonce, 2)
	var qui := func(camp: int) -> String: return "le nôtre" if camp == nous else "le leur"
	var nom := "nous" if premiere == nous else MeteoTexte.nom_camp(annonce, premiere)
	if premiere == nous: return "dans notre dos en 1re période, dans le leur après la pause"
	return "dans le dos de %s en 1re période, dans %s après la pause" % [nom, qui.call(seconde)]

## Le vent en deux lignes courtes, une par période : « 1re période · notre dos » / « 2e période · dos adverse ».
static func phrase_vent_lignes(next: Dictionary, nous: int) -> Array[String]:
	var annonce := MeteoTexte.annonce(next)
	var premiere := MeteoTexte.camp_vent(annonce, 1)
	var resultat: Array[String] = []
	if premiere < 0: return resultat
	resultat.append("1re période · " + ("notre dos" if premiere == nous else "dos adverse"))
	resultat.append("2e période · " + ("dos adverse" if premiere == nous else "notre dos"))
	return resultat

## Icône du ciel (vent, pluie, soleil, nuage) dessinée en SVG, comme les icônes du jeu.
static func icone_meteo(meteo: Dictionary, color: Color) -> Texture2D:
	var ink := "#" + color.to_html(false)
	var corps := '<path d="M6 17h10a4 4 0 1 0-1.1-7.85A5.5 5.5 0 0 0 4.3 11.2 3 3 0 0 0 6 17z"/>'
	if meteo.is_empty(): corps = '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'
	elif int(meteo.get("pluie", 0)) > 0: corps = '<path d="M6 13h10a4 4 0 1 0-1.1-7.85A5.5 5.5 0 0 0 4.3 7.2 3 3 0 0 0 6 13z"/><path d="M8 16l-1 3M12 16l-1 3M16 16l-1 3"/>' + ('<path d="M10 20l-.6 2M14 20l-.6 2"/>' if int(meteo.get("pluie", 0)) >= 2 else "")
	elif int(meteo.get("vent", 0)) > 0: corps = '<path d="M3 8h11a3 3 0 1 0-3-3"/><path d="M3 12h16a3 3 0 1 1-3 3"/><path d="M3 16h8"/>'
	else: corps = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [ink, corps]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	return ImageTexture.create_from_image(image)

# ---- Pied -------------------------------------------------------------------------------------------------------

func _touche(libelle: String) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(Charte.RAYON_CARTE)
	style.content_margin_left = M(8)
	style.content_margin_right = M(8)
	style.content_margin_top = M(2)
	style.content_margin_bottom = M(2)
	cadre.add_theme_stylebox_override("panel", style)
	var l := texte(libelle, 13, Charte.IVOIRE, false, 700)
	l.add_theme_font_override("font", C.BODY)
	cadre.add_child(l)
	return cadre

func _tuile(id: String, titre: String, legende: String = "") -> VBoxContainer:
	var tile := PanelContainer.new()
	tile.name = id
	tile.clip_contents = true
	tile.set_meta("prematch_tile", true)
	C.fill(tile)
	tile.size_flags_stretch_ratio = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU, .94)
	style.set_corner_radius_all(Charte.RAYON_PANNEAU)
	style.content_margin_left = M(18)
	style.content_margin_right = M(18)
	style.content_margin_top = M(12)
	style.content_margin_bottom = M(12)
	tile.add_theme_stylebox_override("panel", Charte.ombrer(style))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", M(5))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tete)
	var heading := italique(texte(titre.to_upper(), 18, Charte.IVOIRE, true, 700))
	heading.name = "TileTitle"
	C.fill(heading)
	tete.add_child(heading)
	if not legende.is_empty():
		var droite := texte(legende.to_upper(), 12, Charte.IVOIRE_2, true, 600)
		droite.name = "TileLegend"
		droite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(droite)
	var filet := ColorRect.new()
	filet.color = Charte.FILET
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filet)
	tile.set_meta("content", column)
	return column

func _tile_of(column: VBoxContainer) -> PanelContainer:
	return column.get_parent() as PanelContainer

func _pousse(column: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

## Ligne « ÉTIQUETTE  valeur » (étiquette en petites capitales de 12 px, valeur à droite).
func _rang(column: VBoxContainer, etiquette: String, valeur: Control, node_name: String = "") -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(12))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.custom_minimum_size.y = M(26)
	if not node_name.is_empty(): ligne.name = node_name
	var cle := texte(etiquette.to_upper(), 12, Charte.IVOIRE_2, true, 600)
	cle.custom_minimum_size.x = M(84)
	cle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(cle)
	valeur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not valeur.size_flags_horizontal & Control.SIZE_EXPAND: C.fill(valeur)
	ligne.add_child(valeur)
	column.add_child(ligne)
	var filet := ColorRect.new()
	filet.color = Color(Charte.FILET, .55)
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filet)
	return ligne

func _valeur(texte_: String, size: float = 13, couleur: Color = Charte.IVOIRE, max_lignes: int = 2, gras: bool = false) -> Label:
	var l := lignes(texte_, size, couleur, max_lignes, false, 700 if gras else 500)
	l.clip_text = true
	return l

## Ligne de liens en bas d'une tuile.
func _liens(column: VBoxContainer, liens: Array) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", M(14))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entree: Array in liens:
		var lien := _bouton_lien(str(entree[0]), entree[1], str(entree[2]), 14)
		if entree.size() > 3: lien.tooltip_text = str(entree[3])
		ligne.add_child(lien)
	column.add_child(ligne)
	return ligne

## Tendance d'un arbitre en mot, avec trois repères (1 laisse jouer ... 5 pointilleux).
static func mot_arbitre(niveau: int) -> String:
	return "non renseigné" if niveau <= 0 else "Souple" if niveau <= 2 else "Équilibré" if niveau == 3 else "Pointilleux"

static func jauge_arbitre(libelle: String, valeur: Variant) -> Control:
	var niveau: int = clampi(int(valeur), 0, 5) if valeur is int or valeur is float else 0
	var ligne := HBoxContainer.new()
	ligne.name = "ArbitreJauge_" + libelle
	ligne.add_theme_constant_override("separation", M(8))
	ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.tooltip_text = "%s : %s" % [libelle, ("%d sur 5" % niveau) if niveau > 0 else "non renseigné"]
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var mot := texte(mot_arbitre(niveau), 13, Charte.IVOIRE, false, 500)
	mot.add_theme_font_override("font", C.BODY)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(mot)
	ligne.add_child(mot)
	var crans := HBoxContainer.new()
	crans.add_theme_constant_override("separation", M(2))
	crans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crans.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var allumes := 0 if niveau <= 0 else 1 if niveau <= 2 else 2 if niveau == 3 else 3
	for i in 3:
		var cran := Panel.new()
		cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cran.custom_minimum_size = Vector2(M(14 if i == allumes - 1 else 10), M(5))
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.IVOIRE if i == allumes - 1 and allumes > 0 else Color(Charte.IVOIRE, .22)
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		cran.add_theme_stylebox_override("panel", style)
		crans.add_child(cran)
	ligne.add_child(crans)
	ligne.set_meta("niveau", niveau)
	return ligne
