extends PanelContainer
## Écran Match avant le coup d'envoi (maquette « Retenue » validée par Léo le 17/11/2026) : bandeau (date, « Déléguer
## le match », « Coup d'envoi »), affiche photo (écussons face à face, classement, forme, heure, bilan des
## confrontations, météo et vent) et six tuiles : forces en présence, météo du match, feuille, confrontations
## directes, l'adversaire (plan de jeu probable lu par le staff dès la veille, joueurs à surveiller), mot de Gabi. Toutes les valeurs viennent du modèle natif : `next` (affiche et
## météo annoncée la veille), `selection` et `squad` (feuille), `clubLife.avantMatch` (native/engine/avant-match.cjs :
## forme, forces, confrontations, joueurs, clés de Gabi). Rien n'est inventé : une donnée absente devient une phrase.
## Tailles données en pixels d'un écran 1080p (`M`), à l'échelle de la fenêtre comme le reste de l'interface.

const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const Present = preload("res://ui/immersive08/projection.gd")
const MeteoTexte = preload("res://ui/contextual/meteo_texte.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const ROUGE := Color("df897d")
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const JOURS := ["DIM.", "LUN.", "MAR.", "MER.", "JEU.", "VEN.", "SAM."]
## Photo du tunnel selon la météo annoncée (forte pluie > pluie > vent > chaleur > sec ; sans annonce : neutre).
## Variante absente du jeu : la photo d'origine (pluie fine).
const PHOTO_ORIGINE := "match-tunnel"

var app: Control
var kickoff: Button
var delegate: Button
var status: Label
var match_date: Label
var content: VBoxContainer
var _key := ""

## Pixels d'un écran 1080p, à la densité courante (1080p : 1 pour 1).
static func M(value: float) -> int:
	return roundi(value * C.density / 0.75)

static func texte(value: Variant, size: float, color: Color = C.IVORY, display: bool = true, weight: int = 600) -> Label:
	return C.label(value, roundi(size / 0.75), color, display, weight)

static func lignes(value: Variant, size: float, color: Color, max_lines: int, display: bool = false, weight: int = 500) -> Label:
	var label := texte(value, size, color, display, weight)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

static func virgule(value: Variant, decimals: int = 1) -> String:
	if not (value is float or value is int): return "—"
	return String.num(float(value), decimals).replace(".", ",") if decimals > 0 else str(roundi(float(value)))

## « SAM. 24 OCT. 2026 » (date ISO du match).
static func date_longue(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return iso
	var unix := Time.get_unix_time_from_datetime_string(iso + "T12:00:00")
	var jour: int = Time.get_datetime_dict_from_unix_time(unix).weekday
	return "%s %d %s %s" % [JOURS[jour], int(parts[2]), MOIS[clampi(int(parts[1]) - 1, 0, 11)].to_upper(), parts[0]]

static func mois_annee(iso: Variant) -> String:
	var parts := str(iso).split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return "—"
	return "%s %s" % [MOIS[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]

## Photo d'avant-match selon la météo annoncée (`next.meteo`) et l'heure du coup d'envoi : en journée, la
## pelouse sous le ciel du jour (banque d'images) ; le soir et la nuit, l'entrée des joueurs par le tunnel
## éclairé (photos de la maquette validée).
static func photo_meteo(next: Dictionary) -> String:
	var moment := BanqueImages.moment(next.get("kickoffLocal"), next.get("date", ""))
	# Grande enceinte (20 000 places et plus) : soir sec et nuit pluvieuse aussi (banque lot-13).
	if BanqueImages.niveau_stade(next.get("capacity")) >= 5 and moment in ["soir", "nuit"]:
		var grand := BanqueImages.choisir("avant-match", {"moment": moment, "meteo": BanqueImages.meteo(next.get("meteo")), "taille": "grand"})
		if not grand.is_empty() and BanqueImages.info(grand).get("etiquettes", {}).get("moment") == moment and BanqueImages.texture(grand) != null: return grand
	if moment == "jour":
		# Grande enceinte (20 000 places et plus) par temps sec ; sinon la pelouse d'un stade de club.
		var taille := "grand" if BanqueImages.niveau_stade(next.get("capacity")) >= 5 else "club"
		var pelouse := BanqueImages.choisir("avant-match", {"moment": "jour", "meteo": BanqueImages.meteo(next.get("meteo")), "taille": taille})
		if not pelouse.is_empty() and BanqueImages.texture(pelouse) != null: return pelouse
	var meteo: Variant = next.get("meteo")
	var id := "match-tunnel-neutre"
	if meteo is Dictionary:
		if int(meteo.get("pluie", 0)) >= 2: id = "match-tunnel-forte-pluie"
		elif int(meteo.get("pluie", 0)) == 1: id = PHOTO_ORIGINE
		elif int(meteo.get("vent", 0)) > 0: id = "match-tunnel-vent"
		elif int(meteo.get("chaleur", 0)) > 0: id = "match-tunnel-chaleur"
		else: id = "match-tunnel-sec"
	return id if C.texture(id) != null else PHOTO_ORIGINE

func _init() -> void:
	name = "MatchOpening"
	# Style propre à l'écran : la passe de style héritée (legacy_style.gd) ne doit ni repeindre les pastilles ni
	# agrandir les textes ; elle s'arrête à ce nœud.
	set_meta("immersive_style_applied", true)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func setup(owner: Control, on_kickoff: Callable, on_delegate: Callable) -> void:
	app = owner
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", M(12))
	add_child(column)
	var header := HBoxContainer.new()
	header.name = "MatchPrematchHeader"
	header.add_theme_constant_override("separation", M(14))
	header.custom_minimum_size.y = M(44)
	column.add_child(header)
	status = texte("", 19, C.MINT, true, 700)
	status.name = "MatchPrematchStatus"
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(status)
	var spacer := Control.new()
	C.fill(spacer)
	header.add_child(spacer)
	match_date = texte("", 20, C.IVORY, true, 600)
	match_date.name = "MatchPrematchDate"
	match_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(match_date)
	delegate = _bouton("Déléguer le match", on_delegate, false)
	delegate.name = "MatchOpenDelegation"
	header.add_child(delegate)
	kickoff = _bouton("COUP D'ENVOI", on_kickoff, true)
	kickoff.name = "MatchKickoff"
	kickoff.icon = C.icon_texture("arrow", C.BG)
	kickoff.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kickoff.expand_icon = false
	kickoff.add_theme_constant_override("icon_max_width", M(20))
	kickoff.add_theme_constant_override("h_separation", M(10))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]: kickoff.add_theme_color_override(state, C.BG)
	header.add_child(kickoff)
	content = VBoxContainer.new()
	content.name = "MatchPrematchBoard"
	content.add_theme_constant_override("separation", M(12))
	C.fill(content, true)
	column.add_child(content)

func _bouton(caption: String, callback: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.set_meta("immersive_style_applied", true)
	button.custom_minimum_size = Vector2(M(150) if primary else M(120), M(44))
	button.add_theme_font_override("font", C.BOLD if primary else C.DISPLAY)
	button.add_theme_font_size_override("font_size", M(20 if primary else 18))
	var fill := C.GOLD if primary else Color.TRANSPARENT
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(.08) if state == "hover" and primary else fill.darkened(.12) if state == "pressed" and primary else Color("3a3f37") if state == "disabled" and primary else Color.TRANSPARENT if state == "focus" else fill
		if not primary and state == "hover": style.bg_color = Color(C.IVORY, .08)
		style.set_corner_radius_all(M(6))
		style.content_margin_left = M(22 if primary else 18)
		style.content_margin_right = style.content_margin_left
		style.content_margin_top = M(8)
		style.content_margin_bottom = M(8)
		if not primary or state == "focus":
			style.border_color = C.GOLD if state == "focus" else Color(C.IVORY, .3)
			style.set_border_width_all(2 if state == "focus" else 1)
			if state == "focus": style.set_expand_margin_all(2)
		button.add_theme_stylebox_override(state, style)
	var ink := C.BG if primary else C.IVORY
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", C.FAINT)
	button.pressed.connect(callback)
	return button

## Rafraîchit l'écran (reconstruit seulement quand les données montrées changent).
func refresh(model: Dictionary, play: Button) -> void:
	var next: Dictionary = model.next if model.get("next") is Dictionary else {}
	# Même libellé que le bouton du direct (« COUP D'ENVOI », « Jouer à 22 ») ; la flèche est une icône.
	kickoff.text = play.text
	kickoff.disabled = play.disabled
	kickoff.tooltip_text = play.tooltip_text
	delegate.visible = not next.is_empty()
	delegate.disabled = play.disabled
	match_date.text = date_longue(str(next.get("date", ""))) if not next.is_empty() else ""
	var selection: Dictionary = model.get("selection", {})
	var key := JSON.stringify([next, model.get("clubLife", {}).get("avantMatch"), selection.get("slots", []), selection.get("valid", false),
		model.get("squad", []).map(func(p: Dictionary): return [p.get("id"), p.get("condition"), p.get("injury")]), model.get("meta", {}).get("calendarToday"), app.accent.to_html()])
	if key == _key: return
	_key = key
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if next.is_empty():
		var vide := lignes("Aucune rencontre à préparer pour le moment.", 22, C.MUTED, 2)
		content.add_child(vide)
		return
	var data: Dictionary = model.get("clubLife", {}).get("avantMatch") if model.get("clubLife", {}).get("avantMatch") is Dictionary else {}
	if str(data.get("fixtureId", "")) != str(next.get("id", data.get("fixtureId", ""))): data = {}
	content.add_child(_affiche(model, next, data))
	var grille := VBoxContainer.new()
	grille.name = "MatchPrematchTiles"
	grille.add_theme_constant_override("separation", M(12))
	C.fill(grille, true)
	content.add_child(grille)
	var rangees: Array[HBoxContainer] = []
	for i in 2:
		var rangee := HBoxContainer.new()
		rangee.add_theme_constant_override("separation", M(12))
		C.fill(rangee, true)
		grille.add_child(rangee)
		rangees.append(rangee)
	var nous := _cote(model, next)
	rangees[0].add_child(_forces(next, data, nous))
	rangees[0].add_child(_meteo(model, next, nous, data))
	rangees[0].add_child(_feuille(model))
	rangees[1].add_child(_confrontations(data))
	rangees[1].add_child(_joueurs(data))
	rangees[1].add_child(_gabi(data))

func _cote(model: Dictionary, next: Dictionary) -> int:
	var club_id: Variant = model.get("club", {}).get("id")
	return 1 if next.get("away", {}).get("id") == club_id and club_id != null else 0

# ---- Affiche --------------------------------------------------------------------------------------------------

func _affiche(model: Dictionary, next: Dictionary, data: Dictionary) -> Control:
	var poster := Panel.new()
	poster.name = "MatchPoster"
	poster.custom_minimum_size.y = M(300)
	var frame := StyleBoxFlat.new()
	frame.bg_color = C.BG
	frame.set_corner_radius_all(M(12))
	poster.add_theme_stylebox_override("panel", frame)
	poster.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id := photo_meteo(next)
	var photo := C.photo(id, Vector2.ZERO, true, .3)
	photo.name = "MatchPosterPhoto"
	photo.set_meta("photo_meteo", id)
	# Joueurs du tunnel et des photos aux tenues neutres : à nos couleurs.
	var RI = preload("res://ui/contextual/rooms/room_identity.gd")
	var identite: Dictionary = G.identity(model.get("club", {}))
	BanqueImages.recolorer(photo, id, RI.primary(identite), RI.secondary(identite))
	photo.tooltip_text = ""
	poster.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(C.BG, .62))
	gradient.set_color(1, Color(C.BG, .93))
	gradient.add_point(.38, Color(C.BG, .3))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = gradient
	veil_texture.fill_from = Vector2.ZERO
	veil_texture.fill_to = Vector2.DOWN
	var veil := TextureRect.new()
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: inset.add_theme_constant_override("margin_" + edge, M(44))
	inset.add_theme_constant_override("margin_top", M(16))
	inset.add_theme_constant_override("margin_bottom", M(14))
	poster.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", M(10))
	inset.add_child(stack)
	var venue := Present.fixture_venue(next, false)
	var top := texte("  ·  ".join([str(next.get("label", "")), venue].filter(func(x: String): return not x.is_empty())).to_upper(), 21, C.GOLD, true, 600)
	top.name = "MatchFixtureVenue"
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.clip_text = true
	stack.add_child(top)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", M(24))
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(middle, true)
	stack.add_child(middle)
	var nous := _cote(model, next)
	var forme: Array = data.get("forme", [[], []])
	middle.add_child(_equipe(next.get("home", {}), 0, nous, forme[0] if forme.size() > 0 else [], next))
	middle.add_child(_centre(next, data))
	middle.add_child(_equipe(next.get("away", {}), 1, nous, forme[1] if forme.size() > 1 else [], next))
	stack.add_child(_pastille_meteo(next, nous))
	return poster

func _equipe(club: Dictionary, side: int, nous: int, forme: Array, next: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", M(24))
	row.alignment = BoxContainer.ALIGNMENT_END if side == 0 else BoxContainer.ALIGNMENT_BEGIN
	C.fill(row)
	row.name = "MatchPosterHome" if side == 0 else "MatchPosterAway"
	var crest := G.crest(club, M(88))
	crest.custom_minimum_size = Vector2(M(88), M(100))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var infos := VBoxContainer.new()
	infos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	infos.add_theme_constant_override("separation", M(6))
	infos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var align := HORIZONTAL_ALIGNMENT_RIGHT if side == 0 else HORIZONTAL_ALIGNMENT_LEFT
	var lieu := "TERRAIN NEUTRE" if next.get("neutral", false) else ("DOMICILE" if side == 0 else "EXTÉRIEUR")
	var tag := texte(("TON ÉQUIPE · " + lieu) if side == nous else lieu, 15, C.MINT if side == nous else Color(C.IVORY, .8), false, 600)
	tag.horizontal_alignment = align
	infos.add_child(tag)
	var nom := lignes(G.club_name(club).to_upper(), 42, C.IVORY, 2, true, 700)
	nom.name = "MatchPosterName"
	nom.horizontal_alignment = align
	nom.add_theme_constant_override("line_spacing", -M(8))
	infos.add_child(nom)
	var classement := "%s  ·  %s pts" % [Present.rank_ordinal(club), G.n(club.get("points", 0))] if Present.standings_open(club) else "Classement ouvert après la 1re journée"
	var rang := texte(classement, 17, Color(C.IVORY, .85), false, 500)
	rang.horizontal_alignment = align
	infos.add_child(rang)
	var pills := HBoxContainer.new()
	pills.name = "MatchPosterForm"
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pills.add_theme_constant_override("separation", M(6))
	pills.alignment = BoxContainer.ALIGNMENT_END if side == 0 else BoxContainer.ALIGNMENT_BEGIN
	for result in forme: pills.add_child(pastille(str(result), 28))
	if forme.is_empty():
		var aucun := texte("Pas encore de match cette saison", 14, C.MUTED, false, 500)
		pills.add_child(aucun)
	pills.tooltip_text = "Forme sur les 5 derniers matchs, du plus ancien au plus récent"
	infos.add_child(pills)
	if side == 0:
		row.add_child(infos)
		row.add_child(crest)
	else:
		row.add_child(crest)
		row.add_child(infos)
	return row

## Pastille de résultat : V vert, N doré, D rouge, lettre dedans.
static func pastille(result: String, size: float) -> PanelContainer:
	var color := C.MINT if result == "V" else ROUGE if result == "D" else C.GOLD
	var frame := PanelContainer.new()
	frame.name = "Pastille" + result
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(M(size / 2.0))
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(M(size), M(size))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var letter := texte(result, size * .46, C.BG, false, 700)
	letter.add_theme_font_override("font", C.BODY)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(letter)
	return frame

func _centre(next: Dictionary, data: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.name = "MatchPosterKickoff"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size.x = M(330)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", M(6))
	var heure := texte(str(next.get("kickoffLocal", "")) if next.get("kickoffLocal") is String else "—", 64, C.IVORY, true, 800)
	heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heure)
	var jour := texte("COUP D'ENVOI  ·  " + date_longue(str(next.get("date", ""))), 15, Color(C.IVORY, .85), false, 600)
	jour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(jour)
	var bilan: Dictionary = data.get("confrontations", {})
	var joues := int(bilan.get("joues", 0))
	var caption := "PREMIÈRE CONFRONTATION" if joues == 0 else "%s EN %d CONFRONTATION%s" % [bilan_court(bilan), joues, "S" if joues > 1 else ""]
	if data.is_empty(): caption = "AVANT-MATCH"
	var pill := PanelContainer.new()
	pill.name = "MatchPosterHeadToHead"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(C.BG, .55)
	style.border_color = C.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(M(20))
	style.content_margin_left = M(16)
	style.content_margin_right = M(16)
	style.content_margin_top = M(4)
	style.content_margin_bottom = M(4)
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := texte(caption, 19, C.GOLD, true, 600)
	pill.add_child(label)
	column.add_child(pill)
	return column

static func bilan_court(bilan: Dictionary) -> String:
	var parts: Array[String] = ["%d V" % int(bilan.get("victoires", 0))]
	if int(bilan.get("nuls", 0)) > 0: parts.append("%d N" % int(bilan.get("nuls", 0)))
	parts.append("%d D" % int(bilan.get("defaites", 0)))
	return " – ".join(parts)

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

func _pastille_meteo(next: Dictionary, nous: int) -> Control:
	var annonce := MeteoTexte.annonce(next)
	var holder := HBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := PanelContainer.new()
	pill.name = "MatchPosterWeather"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(C.BG, .82)
	style.border_color = Color(C.GOLD, .55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(M(26))
	style.content_margin_left = M(20)
	style.content_margin_right = M(22)
	style.content_margin_top = M(8)
	style.content_margin_bottom = M(8)
	pill.add_theme_stylebox_override("panel", style)
	holder.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", M(12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var meteo: Dictionary = next.get("meteo", {}) if next.get("meteo") is Dictionary else {}
	var symbol := TextureRect.new()
	symbol.texture = icone_meteo(meteo, C.GOLD)
	symbol.custom_minimum_size = Vector2(M(28), M(28))
	symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(symbol)
	var ciel := texte(MeteoTexte.libelle(annonce).to_upper() if not annonce.is_empty() else "BULLETIN MÉTÉO LA VEILLE DU MATCH", 23, C.GOLD, true, 700)
	ciel.name = "MatchFixtureWeather"
	ciel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ciel)
	var vent := phrase_vent(next, nous)
	if not vent.is_empty():
		var detail := texte(vent, 16, C.IVORY, false, 500)
		detail.name = "MatchFixtureWind"
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(detail)
	return holder

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

# ---- Tuiles -----------------------------------------------------------------------------------------------------

func _tuile(id: String, titre: String, couleur: Color = C.GOLD, bordure: Color = Color.TRANSPARENT) -> VBoxContainer:
	var tile := PanelContainer.new()
	tile.name = id
	tile.clip_contents = true
	tile.set_meta("prematch_tile", true)
	C.fill(tile, true)
	var style := StyleBoxFlat.new()
	style.bg_color = C.RAISED
	style.set_corner_radius_all(M(10))
	style.content_margin_left = M(18)
	style.content_margin_right = M(18)
	style.content_margin_top = M(12)
	style.content_margin_bottom = M(12)
	if bordure.a > 0:
		style.border_color = bordure
		style.set_border_width_all(1)
	tile.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", M(7))
	tile.add_child(column)
	var heading := texte(titre, 20, couleur, true, 600)
	heading.name = "TileTitle"
	column.add_child(heading)
	tile.set_meta("content", column)
	return column

func _tile_of(column: VBoxContainer) -> PanelContainer:
	return column.get_parent() as PanelContainer

func _lien(caption: String, callback: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", C.BODY)
	button.add_theme_font_size_override("font_size", M(15))
	button.add_theme_color_override("font_color", C.GOLD)
	button.add_theme_color_override("font_hover_color", C.IVORY)
	button.add_theme_color_override("font_focus_color", C.IVORY)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, empty)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = C.GOLD
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(M(4))
	button.add_theme_stylebox_override("focus", focus)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(callback)
	return button

func _pousse(column: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

func _forces(next: Dictionary, data: Dictionary, nous: int) -> Control:
	var forces: Variant = data.get("forces")
	var titre := "FORCES EN PRÉSENCE"
	if forces is Dictionary and str(forces.get("saison", "")) == "passée": titre += " · SAISON PASSÉE"
	var column := _tuile("TuileForces", titre)
	if not forces is Dictionary:
		column.add_child(lignes("Les forces en présence s’affichent après la première journée de la saison.", 16, C.MUTED, 3))
		return _tile_of(column)
	var eux := 1 - nous
	var clubs := [next.get("home", {}), next.get("away", {})]
	var noms := HBoxContainer.new()
	var gauche := texte(G.club_name(clubs[eux]).to_upper(), 13, Color(C.IVORY, .8), false, 600)
	gauche.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gauche.clip_text = true
	C.fill(gauche)
	var droite := texte(G.club_name(clubs[nous]).to_upper(), 13, C.MINT, false, 600)
	droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	droite.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	droite.clip_text = true
	C.fill(droite)
	noms.add_child(gauche)
	noms.add_child(droite)
	column.add_child(noms)
	var equipes: Array = forces.get("equipes", [{}, {}])
	var a: Dictionary = equipes[eux]
	var b: Dictionary = equipes[nous]
	for row: Array in [["Essais marqués / match", "essais", 1, ""], ["Points encaissés / match", "encaisses", 1, ""], ["Touches gagnées", "touches", 0, " %"], ["Mêlées gagnées", "melees", 0, " %"]]:
		var va: Variant = a.get(row[1])
		var vb: Variant = b.get(row[1])
		var line := HBoxContainer.new()
		line.name = "Force_" + str(row[1])
		var left := texte(virgule(va, row[2]) + (row[3] if va != null else ""), 15, C.IVORY, false, 700)
		left.custom_minimum_size.x = M(60)
		var label := texte(row[0], 15, Color(C.IVORY, .8), false, 500)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		C.fill(label)
		var right := texte(virgule(vb, row[2]) + (row[3] if vb != null else ""), 15, C.MINT, false, 700)
		right.custom_minimum_size.x = M(60)
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(left)
		line.add_child(label)
		line.add_child(right)
		column.add_child(line)
		column.add_child(_barre_double(va, vb))
	var source := texte("Moyennes sur %s match%s · saison %s" % [G.n(a.get("matchs", 0)), "s" if int(a.get("matchs", 0)) > 1 else "", forces.get("saison", "")], 12, C.FAINT, false, 500)
	_pousse(column)
	column.add_child(source)
	return _tile_of(column)

func _barre_double(left: Variant, right: Variant) -> Control:
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", M(4))
	bars.custom_minimum_size.y = M(7)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var values := [maxf(0.0, float(left)) if left != null else 0.0, maxf(0.0, float(right)) if right != null else 0.0]
	if values[0] + values[1] <= 0: values = [1.0, 1.0]
	for i in 2:
		var bar := Panel.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = (C.IVORY if i == 0 else C.MINT) if (left if i == 0 else right) != null else Color(C.IVORY, .12)
		style.set_corner_radius_all(M(4))
		bar.add_theme_stylebox_override("panel", style)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_stretch_ratio = maxf(.05, values[i])
		bars.add_child(bar)
	return bars

## Conditions du match : la météo annoncée la veille, puis l'arbitre désigné (`clubLife.avantMatch.arbitre`).
func _meteo(model: Dictionary, next: Dictionary, nous: int, data: Dictionary) -> Control:
	var bloc := MeteoTexte.avant_match(next, str(model.get("meta", {}).get("calendarToday", "")))
	var column := _tuile("TuileMeteo", str(bloc.titre))
	var annonce := MeteoTexte.annonce(next)
	var arbitre: Dictionary = data.get("arbitre") if data.get("arbitre") is Dictionary and not str(data.arbitre.get("nom", "")).is_empty() else {}
	if annonce.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", M(14))
		var icon := TextureRect.new()
		icon.texture = icone_meteo({}, C.MUTED)
		icon.custom_minimum_size = Vector2(M(48), M(48))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var message := lignes(str(bloc.conseil), 20, C.IVORY, 2, true, 600)
		message.name = "MeteoAnnonce"
		message.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		C.fill(message)
		row.add_child(message)
		column.add_child(row)
		column.add_child(lignes("Le staff fixe la météo et le sens du vent la veille ; un courrier te les annonce.", 14, C.MUTED, 1 if not arbitre.is_empty() else 2))
		if not arbitre.is_empty():
			_pousse(column)
			_arbitre(column, arbitre)
		return _tile_of(column)
	var meteo: Dictionary = next.meteo
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", M(14))
	var icon := TextureRect.new()
	icon.texture = icone_meteo(meteo, C.GOLD)
	icon.custom_minimum_size = Vector2(M(52), M(52))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var noms := VBoxContainer.new()
	noms.add_theme_constant_override("separation", 0)
	C.fill(noms)
	noms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ciel := texte(str(bloc.ciel), 32, C.IVORY, true, 700)
	ciel.name = "MeteoCiel"
	noms.add_child(ciel)
	var pluie := int(meteo.get("pluie", 0))
	var etat := "Forte pluie" if pluie >= 2 else "Pluie" if pluie == 1 else "Chaleur" if int(meteo.get("chaleur", 0)) > 0 else "Temps sec"
	noms.add_child(texte("%s, pelouse %s" % [etat, "lourde" if str(meteo.get("terrain", "")) == "lourd" else "souple"], 14, Color(C.IVORY, .85), false, 500))
	head.add_child(noms)
	head.add_child(_jauge_vent(int(meteo.get("vent", 0))))
	column.add_child(head)
	var dos1 := MeteoTexte.camp_vent(annonce, 1)
	if dos1 >= 0:
		var sens := texte("sens de notre attaque  ▸", 13, C.MINT, false, 500)
		sens.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sens)
		for periode in [1, 2]:
			var dos := MeteoTexte.camp_vent(annonce, periode)
			column.add_child(_piste(periode, dos == nous))
	else:
		column.add_child(texte("Pas de vent qui avantage un camp.", 14, C.MUTED, false, 500))
	# Avec l'arbitre, le conseil du staff tient sur une ligne (texte entier en infobulle) : la tuile garde sa taille.
	var conseil := lignes(MeteoTexte.conseil(annonce), 14, Color(C.IVORY, .9), 1 if not arbitre.is_empty() else 3)
	conseil.name = "MeteoConseil"
	conseil.tooltip_text = conseil.text
	conseil.mouse_filter = Control.MOUSE_FILTER_PASS
	_pousse(column)
	column.add_child(conseil)
	if not arbitre.is_empty(): _arbitre(column, arbitre)
	return _tile_of(column)

## Arbitre du match : nom, profil en une ligne et quatre jauges de sévérité de 1 (laisse jouer) à 5 (pointilleux).
func _arbitre(column: VBoxContainer, arbitre: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "MatchArbitre"
	bloc.add_theme_constant_override("separation", M(3))
	column.add_child(bloc)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", M(12))
	bloc.add_child(tete)
	var nom := texte("Arbitre : " + str(arbitre.get("nom", "")), 15, C.IVORY, false, 700)
	nom.name = "MatchArbitreNom"
	nom.add_theme_font_override("font", C.BODY)
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	C.fill(nom)
	tete.add_child(nom)
	for axe: Array in [["rucks", "Rucks"], ["melee", "Mêlée"], ["horsJeu", "Hors-jeu"], ["cartons", "Cartons"]]:
		tete.add_child(jauge_arbitre(str(axe[1]), arbitre.get(axe[0])))
	# Profil en infobulle seulement : la ligne de résumé faisait déborder l'écran en 1080p (capture du 18/11) ;
	# les jauges disent l'essentiel et Gabi rappelle une manie marquée (rucks).
	var resume := str(arbitre.get("resume", "")).strip_edges()
	if not resume.is_empty():
		nom.tooltip_text = resume
		nom.mouse_filter = Control.MOUSE_FILTER_PASS

## Jauge compacte d'une sévérité d'arbitre (1 à 5, 3 neutre) : libellé au-dessus de cinq crans.
static func jauge_arbitre(libelle: String, valeur: Variant) -> Control:
	var niveau: int = clampi(int(valeur), 0, 5) if valeur is int or valeur is float else 0
	var colonne := VBoxContainer.new()
	colonne.name = "ArbitreJauge_" + libelle
	colonne.add_theme_constant_override("separation", M(2))
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colonne.tooltip_text = "%s : %s" % [libelle, ("%d sur 5" % niveau) if niveau > 0 else "non renseigné"]
	colonne.mouse_filter = Control.MOUSE_FILTER_PASS
	var titre := texte(libelle, 11, Color(C.IVORY, .75), false, 500)
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(titre)
	var crans := HBoxContainer.new()
	crans.add_theme_constant_override("separation", M(2))
	crans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(crans)
	for i in 5:
		var cran := Panel.new()
		cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cran.custom_minimum_size = Vector2(M(8), M(8))
		var style := StyleBoxFlat.new()
		style.bg_color = C.GOLD if i < niveau else Color(C.IVORY, .2)
		style.set_corner_radius_all(M(2))
		cran.add_theme_stylebox_override("panel", style)
		crans.add_child(cran)
	colonne.set_meta("niveau", niveau)
	return colonne

func _jauge_vent(level: int) -> Control:
	var gauge := HBoxContainer.new()
	gauge.name = "MeteoForceVent"
	gauge.alignment = BoxContainer.ALIGNMENT_END
	gauge.add_theme_constant_override("separation", M(4))
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.tooltip_text = ["Pas de vent notable", "Vent", "Grand vent"][clampi(level, 0, 2)]
	for i in 3:
		var bar := Panel.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(M(8), M(14 + i * 8))
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		var style := StyleBoxFlat.new()
		style.bg_color = C.GOLD if level > 0 and i <= level else Color(C.IVORY, .2)
		style.set_corner_radius_all(M(2))
		bar.add_theme_stylebox_override("panel", style)
		gauge.add_child(bar)
	return gauge

## Une période : piste avec la flèche du vent par rapport au sens de notre attaque (vers la droite).
func _piste(periode: int, dans_le_dos: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "MeteoPeriode%d" % periode
	row.add_theme_constant_override("separation", M(12))
	var label := texte("1re période" if periode == 1 else "2e période", 14, Color(C.IVORY, .85), false, 500)
	label.custom_minimum_size.x = M(84)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var track := Fleche.new()
	track.vers_la_droite = dans_le_dos
	track.custom_minimum_size.y = M(30)
	C.fill(track)
	row.add_child(track)
	var effet := texte("Dans le dos" if dans_le_dos else "De face", 18, C.MINT if dans_le_dos else C.IVORY, true, 700)
	effet.name = "MeteoEffet"
	effet.custom_minimum_size.x = M(100)
	effet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(effet)
	return row

class Fleche extends Control:
	var vers_la_droite := true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0b1012")
		style.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(style, r)
		var y := size.y / 2.0
		var pad := size.y * .45
		var w := maxf(2.0, size.y * .13)
		var gold := Color("d7ad59")
		var a := Vector2(pad, y)
		var b := Vector2(size.x - pad, y)
		draw_line(a, b, gold, w, true)
		var tip := b if vers_la_droite else a
		var back := -1.0 if vers_la_droite else 1.0
		var head := size.y * .32
		draw_polyline([tip + Vector2(back * head, -head), tip, tip + Vector2(back * head, head)], gold, w, true)

func _feuille(model: Dictionary) -> Control:
	var column := _tuile("TuileFeuille", "TA FEUILLE", C.MINT)
	var selection: Dictionary = model.get("selection", {})
	var slots: Array = selection.get("slots", [])
	var filled := slots.filter(func(s: Dictionary): return s.get("playerId") != null).size()
	var valid: bool = selection.get("valid", false)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", M(14))
	var count := texte("%d / %d" % [filled, slots.size()], 42, C.MINT if valid else C.AMBER, true, 700)
	count.name = "FeuilleCompte"
	head.add_child(count)
	var etat := texte("feuille complète" if valid else "feuille à compléter", 16, C.IVORY, false, 500)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(etat)
	column.add_child(head)
	var conditions: Array = []
	var names: Array = []
	for i in 15: conditions.append(-1.0); names.append("")
	for assignment: Dictionary in slots:
		var slot := int(assignment.get("slot", -1))
		if slot < 0 or slot >= 15: continue
		var person := Present.player(model, str(assignment.get("playerId", "")))
		if person.is_empty() or not (person.get("condition") is float or person.get("condition") is int): continue
		conditions[slot] = float(person.condition)
		names[slot] = str(person.get("name", ""))
	var known := conditions.filter(func(x: float): return x >= 0)
	var moyenne := 0.0
	for x in known: moyenne += x
	moyenne = moyenne / known.size() if not known.is_empty() else 0.0
	var line := HBoxContainer.new()
	var caption := texte("Condition moyenne du XV", 15, C.IVORY, false, 500)
	C.fill(caption)
	line.add_child(caption)
	line.add_child(texte("%d %%" % roundi(moyenne) if not known.is_empty() else "—", 15, C.IVORY, false, 700))
	column.add_child(line)
	column.add_child(C.gauge(moyenne, C.MINT if moyenne >= 80 else C.GOLD, 9))
	var bars := Barres.new()
	bars.name = "FeuilleConditions"
	bars.valeurs = conditions
	bars.custom_minimum_size.y = M(50)
	bars.tooltip_text = "Condition des quinze titulaires, du n° 1 au n° 15 (doré sous 80 %)"
	column.add_child(bars)
	var injured := int(Present.group(model).get("injured", 0))
	var bas := -1
	for i in 15:
		if conditions[i] >= 0 and conditions[i] < 80 and (bas < 0 or conditions[i] < conditions[bas]): bas = i
	var parts: Array[String] = ["%d blessé%s écarté%s" % [injured, "s" if injured > 1 else "", "s" if injured > 1 else ""] if injured > 0 else "Aucun blessé"]
	parts.append("le n° %d, %s, est à %d %%" % [bas + 1, names[bas], roundi(conditions[bas])] if bas >= 0 else "tous les titulaires à 80 % ou plus")
	var note := lignes(" · ".join(parts), 14, Color(C.IVORY, .88), 2)
	note.name = "FeuilleAlerte"
	column.add_child(note)
	_pousse(column)
	column.add_child(_lien("Vérifier la feuille →", func(): app._navigate("Composition"), "MatchOpenSheet"))
	return _tile_of(column)

class Barres extends Control:
	var valeurs: Array = []
	var font: Font
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		font = load("res://fonts/DMSans.ttf")
		resized.connect(queue_redraw)
	func _draw() -> void:
		var n := 15
		var font_size := maxi(10, int(size.y * .22))
		var gap := maxf(2.0, size.x * .008)
		var w := (size.x - gap * (n - 1)) / n
		var h := size.y - font_size - 3.0
		for i in n:
			var x := i * (w + gap)
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color("0b1012")
			bg.set_corner_radius_all(3)
			draw_style_box(bg, Rect2(x, 0, w, h))
			var v: float = valeurs[i] if i < valeurs.size() else -1.0
			if v >= 0:
				var fill := StyleBoxFlat.new()
				fill.bg_color = Color("82e3a3") if v >= 80 else Color("d7ad59")
				fill.set_corner_radius_all(3)
				var fh := h * clampf(v / 100.0, .04, 1.0)
				draw_style_box(fill, Rect2(x, h - fh, w, fh))
			draw_string(font, Vector2(x, size.y - 1), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color(0.949, 0.925, 0.863, .8))

func _confrontations(data: Dictionary) -> Control:
	var column := _tuile("TuileConfrontations", "CONFRONTATIONS DIRECTES")
	var bilan: Dictionary = data.get("confrontations", {})
	var joues := int(bilan.get("joues", 0))
	if joues == 0:
		column.add_child(texte("Première confrontation", 26, C.IVORY, true, 700))
		column.add_child(lignes("Aucune rencontre entre les deux clubs depuis le début de ta carrière." if not data.is_empty() else "Le bilan s’affiche avec les données de la rencontre.", 15, C.MUTED, 3))
		return _tile_of(column)
	var total := texte(bilan_court(bilan) + ("  ·  %d match%s" % [joues, "s" if joues > 1 else ""] if joues > 5 else ""), 26, C.IVORY, true, 700)
	total.name = "ConfrontationsBilan"
	column.add_child(total)
	for match: Dictionary in bilan.get("derniers", []):
		var row := HBoxContainer.new()
		row.name = "Confrontation"
		row.add_theme_constant_override("separation", M(10))
		var date := texte(mois_annee(match.get("date")), 15, Color(C.IVORY, .72), false, 500)
		date.custom_minimum_size.x = M(84)
		row.add_child(date)
		var lieu := "terrain neutre" if match.get("neutre", false) else "à domicile" if match.get("domicile", false) else "à " + str(match.get("stade", "l’extérieur")) if match.get("stade") is String else "à l’extérieur"
		var where := texte(lieu, 15, C.IVORY, false, 500)
		where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		where.clip_text = true
		C.fill(where)
		row.add_child(where)
		var score: Array = match.get("score", [0, 0])
		var sc := texte("%s – %s" % [G.n(score[0]), G.n(score[1])], 18, C.IVORY, true, 700)
		sc.custom_minimum_size.x = M(62)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(sc)
		row.add_child(pastille(str(match.get("issue", "N")), 24))
		column.add_child(row)
	return _tile_of(column)

## Plan de jeu probable de l'adversaire lu par notre staff la veille (avant-match.cjs planAdverse) : style, raison
## principale, fiabilité de la lecture et action pour le contrer. Avec un plan, la tuile garde deux joueurs à surveiller.
const CONFIANCE := {"sure": ["LECTURE NETTE", C.MINT], "probable": ["PROBABLE", C.GOLD], "incertaine": ["INCERTAIN", Color("c9b79a")]}

func _plan_adverse(column: VBoxContainer, plan: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "PlanAdverse"
	bloc.add_theme_constant_override("separation", M(2))
	var lecteur: Dictionary = plan.get("lecteur", {}) if plan.get("lecteur") is Dictionary else {}
	var source := "Lecture de %s (%s)" % [str(lecteur.nom), str(lecteur.get("role", "staff"))] if lecteur.get("nom") is String else "Lecture du staff"
	bloc.tooltip_text = "%s, d’après leurs derniers matchs, la météo annoncée et notre feuille actuelle. Une lecture peut se tromper." % source
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", M(8))
	var etiquette := texte("PLAN PROBABLE", 13, Color(C.IVORY, .7), false, 600)
	etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(etiquette)
	var niveau: Array = CONFIANCE.get(str(plan.get("confiance", "probable")), CONFIANCE.probable)
	var puce := PanelContainer.new()
	puce.name = "PlanAdverseConfiance"
	puce.set_meta("confiance", str(plan.get("confiance", "")))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(niveau[1], .16)
	style.border_color = Color(niveau[1], .6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(M(4))
	style.content_margin_left = M(6)
	style.content_margin_right = M(6)
	puce.add_theme_stylebox_override("panel", style)
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(texte(niveau[0], 11, niveau[1], false, 700))
	haut.add_child(puce)
	bloc.add_child(haut)
	var titre := texte(str(plan.get("titre", "")), 21, C.GOLD, true, 700)
	titre.name = "PlanAdverseTitre"
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.clip_text = true
	bloc.add_child(titre)
	var raison := str(plan.get("raison", ""))
	var pourquoi := texte(raison.substr(0, 1).to_upper() + raison.substr(1), 14, C.IVORY, false, 500)
	pourquoi.name = "PlanAdverseRaison"
	pourquoi.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pourquoi.clip_text = true
	pourquoi.tooltip_text = raison
	bloc.add_child(pourquoi)
	column.add_child(bloc)

func _joueurs(data: Dictionary) -> Control:
	var plan: Dictionary = data.get("planAdverse") if data.get("planAdverse") is Dictionary else {}
	var column := _tuile("TuileJoueurs", "L’ADVERSAIRE" if not plan.is_empty() else "JOUEURS À SURVEILLER")
	if not plan.is_empty(): _plan_adverse(column, plan)
	var surveiller: Dictionary = data.get("aSurveiller", {})
	var joueurs: Array = surveiller.get("joueurs", [])
	if not plan.is_empty(): joueurs = joueurs.slice(0, 2)
	if str(surveiller.get("source", "")) == "probable":
		column.add_child(lignes("Pas encore de statistiques cette saison : leur XV probable.", 14, C.MUTED, 2))
	if joueurs.is_empty():
		column.add_child(lignes("Leur effectif n’a pas encore de statistiques ni de XV connu.", 15, C.MUTED, 3))
	for joueur: Dictionary in joueurs:
		var row := HBoxContainer.new()
		row.name = "Surveille_" + str(joueur.get("categorie", ""))
		row.add_theme_constant_override("separation", M(12))
		row.tooltip_text = "%s · %s" % [str(joueur.get("name", "")), str(joueur.get("detail", "")) if joueur.get("detail") != null else "titulaire probable"]
		var numero := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = C.BG
		style.border_color = C.IVORY
		style.set_border_width_all(1)
		style.set_corner_radius_all(M(18))
		numero.add_theme_stylebox_override("panel", style)
		numero.custom_minimum_size = Vector2(M(36), M(36))
		numero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := texte(str(int(joueur.get("numero", 0))) if joueur.get("numero") != null else "—", 18, C.IVORY, true, 700)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		numero.add_child(n)
		row.add_child(numero)
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation", 0)
		C.fill(who)
		var nom := texte(str(joueur.get("name", "")), 16, C.IVORY, false, 700)
		nom.add_theme_font_override("font", C.BODY)
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nom.clip_text = true
		who.add_child(nom)
		var role := texte("%s · %s" % [str(joueur.get("poste", "")), str(joueur.get("role", ""))], 13, Color(C.IVORY, .8), false, 500)
		role.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		role.clip_text = true
		who.add_child(role)
		row.add_child(who)
		if joueur.get("chiffre") is String:
			var chiffre := texte(str(joueur.chiffre), 20, C.GOLD, true, 700)
			chiffre.name = "SurveilleChiffre"
			chiffre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chiffre)
		column.add_child(row)
	_pousse(column)
	var liens := HBoxContainer.new()
	liens.add_theme_constant_override("separation", M(14))
	if not plan.is_empty():
		var route := "Plan de jeu" if str(plan.get("action", "")) == "consignes" else "Composition"
		var contre := _lien(str(plan.get("libelle", "Ouvrir la composition")) + " →", func(): app._navigate(route), "MatchCounterPlan")
		contre.tooltip_text = "Conseil de Gabi : " + str(plan.get("conseil", ""))
		liens.add_child(contre)
	liens.add_child(_lien("Dossier adverse →", func():
		if app.management_ui.get("preparation") is Dictionary: app.management_ui.preparation.tab = 0
		app._navigate("Préparation"), "MatchOpenPreparation"))
	column.add_child(liens)
	return _tile_of(column)

func _gabi(data: Dictionary) -> Control:
	var column := _tuile("TuileGabi", "LE MOT DE GABI", C.MINT, Color(C.MINT, .35))
	var gabi: Dictionary = data.get("gabi", {})
	var phrase := lignes("« %s »" % str(gabi.get("phrase", "On prépare ce match ensemble. Trois clés pour moi :")), 15, C.IVORY, 2, false, 500)
	phrase.name = "GabiPhrase"
	column.add_child(phrase)
	var cles := VBoxContainer.new()
	cles.name = "GabiCles"
	cles.add_theme_constant_override("separation", M(5))
	column.add_child(cles)
	for cle: Dictionary in gabi.get("cles", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", M(10))
		var check := C.icon("check", roundi(20 / .75), C.MINT)
		check.custom_minimum_size = Vector2(M(20), M(20))
		check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(check)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		C.fill(words)
		var titre := texte(str(cle.get("titre", "")), 19, C.IVORY, true, 700)
		titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		titre.clip_text = true
		words.add_child(titre)
		var detail := texte(str(cle.get("detail", "")), 13, Color(C.IVORY, .85), false, 500)
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		detail.clip_text = true
		words.add_child(detail)
		row.add_child(words)
		cles.add_child(row)
	_pousse(column)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", M(8))
	var plan := _bouton_secondaire("Ouvrir le plan de jeu", func(): app._navigate("Plan de jeu"), "MatchOpenPlaybook")
	var talk := _bouton_secondaire("Préparer la causerie", func(): app._navigate("Vestiaire"), "MatchOpenTalk")
	talk.tooltip_text = "La causerie se tient au vestiaire, au coup d’envoi : l’humeur du groupe pour la préparer."
	actions.add_child(plan)
	actions.add_child(talk)
	column.add_child(actions)
	return _tile_of(column)

func _bouton_secondaire(caption: String, callback: Callable, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.set_meta("immersive_style_applied", true)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	C.fill(button)
	button.custom_minimum_size.y = M(34)
	button.add_theme_font_override("font", C.DISPLAY)
	button.add_theme_font_size_override("font_size", M(17))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(C.IVORY, .08) if state == "hover" else Color.TRANSPARENT
		style.border_color = C.GOLD if state == "focus" else Color(C.IVORY, .3)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(M(6))
		style.content_margin_top = M(6)
		style.content_margin_bottom = M(6)
		style.content_margin_left = M(8)
		style.content_margin_right = M(8)
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, C.IVORY)
	button.pressed.connect(callback)
	return button

## Contrôle « rien ne déborde » (tests) : chaque tuile contient son contenu, l'écran tient dans sa zone.
func overflows() -> Array:
	var failures: Array = []
	for tile in find_children("*", "PanelContainer", true, false):
		if not tile.get_meta("prematch_tile", false): continue
		var inner: Control = tile.get_meta("content")
		var needed: Vector2 = tile.get_combined_minimum_size()
		if needed.y > tile.size.y + 0.5 or needed.x > tile.size.x + 0.5: failures.append("%s : %s pour %s" % [tile.name, needed, tile.size])
		if inner.get_combined_minimum_size().y > inner.size.y + 0.5: failures.append("%s : contenu %s pour %s" % [tile.name, inner.get_combined_minimum_size(), inner.size])
	var needed_all := get_combined_minimum_size()
	if needed_all.y > size.y + 0.5: failures.append("écran : %s pour %s" % [needed_all, size])
	return failures
