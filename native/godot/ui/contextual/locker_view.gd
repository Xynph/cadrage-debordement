extends Control
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const Nom = preload("res://ui/person_name.gd")
const Icones = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
## Six tons de causerie (match-pilotage.js, TONS_LABELS) : libellé de repli quand le moteur n'en donne pas.
const TONS := {"calm": "Calme", "demanding": "Exigeant", "warm": "Encourageant", "furious": "Furieux", "protective": "Rassurant", "assertive": "Affirmé"}
## Pictogramme de chaque ton (tracés 24 × 24, trait de 1,8 comme les icônes de la coque) : vague, cible, cœur, flamme,
## bouclier, drapeau planté.
const ICONES_TONS := {
	"calm": "M3 9C6 6.5 9 11.5 12 9S18 6.5 21 9M3 15C6 12.5 9 17.5 12 15S18 12.5 21 15",
	"demanding": "M12 3A9 9 0 1 0 12 21A9 9 0 1 0 12 3M12 7.5A4.5 4.5 0 1 0 12 16.5A4.5 4.5 0 1 0 12 7.5M12 11.2V12.8",
	"warm": "M12 20C-4 10 4.5 0 12 7C19.5 0 28 10 12 20",
	"furious": "M12 2.5C13 6.5 18 8.5 18 14.5A6 6 0 0 1 6 14.5C6 11.5 7.5 9.5 9 8.5C9 10.5 10 11.8 11.2 12C11 8 10.5 5.5 12 2.5",
	"protective": "M12 2.5L20 5.5V11C20 16 16.5 19.5 12 21.5C7.5 19.5 4 16 4 11V5.5ZM8.5 12L11 14.5L15.5 9.5",
	"assertive": "M6 21.5V3M6 4H18L15.5 8L18 12H6",
}
## Couleur franche de chaque ton (retour de Léo du 21/11 : « plus en couleurs ») ; jamais seule : le mot reste écrit.
const COULEURS_TONS := {"calm": Color("5b9bd5"), "warm": Color("7fbf7a"), "protective": Color("4fb3a9"),
	"demanding": Color("a88bd6"), "assertive": Color("e0a04a"), "furious": Color("d9634f")}
const STARTER_POSITIONS = ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne aile", "Troisième ligne aile", "Troisième ligne centre", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
## Poste abrégé sur les tuiles (le poste complet reste en infobulle et en métadonnée « position »).
const POSTES_COURTS := {"Pilier gauche": "Pilier G.", "Pilier droit": "Pilier D.", "Deuxième ligne": "2e ligne",
	"Troisième ligne aile": "3e ligne aile", "Troisième ligne centre": "3e ligne centre", "Troisième ligne": "3e ligne",
	"Demi de mêlée": "Demi de mêlée", "Demi d’ouverture": "Ouvreur", "Demi d'ouverture": "Ouvreur"}
## Masque des portraits : carré à coins arrondis (variante A) ou rond (variante B), y compris sur une planche (atlas).
const MASQUE_PORTRAIT := "shader_type canvas_item;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float rayon = 0.18;
void fragment() {
	vec2 p = (UV - region.xy) / region.zw - 0.5;
	vec2 q = abs(p) - (0.5 - rayon);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rayon;
	float aa = max(fwidth(d), 0.001);
	COLOR.a *= 1.0 - smoothstep(-aa, aa, d);
}"
static var _masque: Shader
static var _icones: Dictionary = {}
var director: Node
var app: Control
var model: Dictionary = {}
var scene: Dictionary = {}
var selected_choice := ""
var audience := "group"
var selected_ids: Array = []
var options_grid: GridContainer
var ui: Control
var _fingerprint := ""
## Variante visuelle provisoire (choix de Léo en cours) : A = cartes joueur et tuiles de ton avec la phrase,
## B = feuille de match compacte et six tuiles carrées avec une seule zone d'aperçu de la phrase.
var variante := "A"
## Échelle des tuiles : 1 en 1280 × 720, jusqu'à 1,5 en 1920 × 1080 (taille logique de la fenêtre).
var _k := 1.0
var _vp := Vector2.ZERO
var _apercu_mot: Label
var _apercu_phrase: Label
var _apercu_icone: TextureRect

func _ready() -> void:
	name = "ContextualLocker"
	app = director.app
	variante = "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"
	S.room(self, "locker", app.model.get("club", {}))
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	if get_viewport_rect().size != _vp and not scene.is_empty():
		_fingerprint = ""
		_draw()

func update_frame(value: Dictionary, data: Dictionary) -> void:
	model = value
	scene = data
	var fingerprint := JSON.stringify([data, value.get("squad", []), value.get("club", {}), value.get("live", {}).get("meteo") if value.get("live") is Dictionary else null])
	if fingerprint == _fingerprint: return
	_fingerprint = fingerprint
	_draw()

func px(value: float) -> int:
	return int(round(value * _k))

func _draw() -> void:
	if is_instance_valid(ui): remove_child(ui); ui.queue_free()
	_vp = get_viewport_rect().size
	_k = clampf(minf(_vp.y / 720.0, _vp.x / 1280.0), 1.0, 1.5)
	ui = Control.new()
	S.full(ui)
	add_child(ui)
	var column := S.frame(ui, px(16))
	column.add_theme_constant_override("separation", px(10))
	var phase := str(scene.get("phase", "pre"))
	var title: String = {"pre":"Avant le match", "half":"Mi-temps", "post":"Après le match"}.get(phase, "Le vestiaire")
	var context: Dictionary = scene.get("context", {})
	var subtitle := S.G.club_name(model.get("club", {}))
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	var teams: Array = live.get("teams", [])
	if teams.size() == 2: subtitle = "%s  —  %s" % [S.G.club_name(teams[0]), S.G.club_name(teams[1])]
	var scores: Array = context.get("score", [])
	if phase != "pre" and scores.size() == 2: subtitle += "   ·   %s — %s" % [str(scores[0]), str(scores[1])]
	var head := S.G.h(px(14))
	column.add_child(head)
	head.add_child(S.G.crest(model.get("club", {}), px(42)))
	var head_words := S.G.v(px(1))
	S.G.fill(head_words)
	head.add_child(head_words)
	head_words.add_child(_text(title, px(23), S.TEXT, Charte.TITRE_FICHE))
	head_words.add_child(_text(subtitle, px(13), S.MUTED))
	if variante == "B": _layout_b(column, live, phase)
	else: _layout_a(column, live, phase)
	director._refresh_controls()

# --- Variante A : deux colonnes de cartes joueur, la causerie au centre, le banc en bas. ---

func _layout_a(column: VBoxContainer, live: Dictionary, phase: String) -> void:
	var body := S.G.h(px(14))
	S.G.fill(body, true)
	column.add_child(body)
	_roster_a(body, "AVANTS", "forwards")
	var middle := S.G.v(px(8))
	S.G.fill(middle, true)
	body.add_child(middle)
	middle.add_child(_air())
	if phase in ["pre", "half"] and not live.is_empty(): _meteo(middle, live, phase)
	_talk(middle)
	middle.add_child(_air())
	_roster_a(body, "ARRIÈRES", "backs")
	var bench_head := S.G.h(px(12))
	column.add_child(bench_head)
	bench_head.add_child(_text("REMPLAÇANTS", px(14), S.MUTED, Charte.TITRE_GRAS))
	bench_head.add_child(_hspace())
	bench_head.add_child(_text("AVANT-MATCH  /  MATCH  /  MI-TEMPS  /  DÉBRIEF", px(12), S.MUTED))
	var bench := S.G.h(px(8))
	bench.name = "TalkBench"
	column.add_child(bench)
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) > 15: bench.add_child(_player_card(participant, true))

func _roster_a(parent: Node, title: String, group: String) -> void:
	var list := S.G.v(px(5))
	list.custom_minimum_size.x = px(292)
	parent.add_child(list)
	list.add_child(_text(title, px(14), S.MUTED, Charte.TITRE_GRAS))
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) <= 15 and participant.get("group") == group:
			list.add_child(_player_card(participant))

# --- Variante B : la feuille de match à gauche (titulaires sur deux colonnes, banc dessous), la causerie à droite. ---

func _layout_b(column: VBoxContainer, live: Dictionary, phase: String) -> void:
	var body := S.G.h(px(14))
	S.G.fill(body, true)
	column.add_child(body)
	var sheet_shell := PanelContainer.new()
	sheet_shell.name = "TalkSheet"
	sheet_shell.add_theme_stylebox_override("panel", Charte.style_panneau(S.PANEL, px(Charte.RAYON_PANNEAU), px(12)))
	sheet_shell.custom_minimum_size.x = px(548)
	body.add_child(sheet_shell)
	var sheet := S.G.v(px(5))
	sheet_shell.add_child(sheet)
	var starters := S.G.h(px(8))
	sheet.add_child(starters)
	for side in [["AVANTS", "forwards"], ["ARRIÈRES", "backs"]]:
		var list := S.G.v(px(5))
		S.G.fill(list)
		starters.add_child(list)
		list.add_child(_text(side[0], px(14), S.MUTED, Charte.TITRE_GRAS))
		for participant: Dictionary in scene.get("participants", []):
			if int(participant.get("number", 0)) <= 15 and participant.get("group") == side[1]:
				list.add_child(_player_card(participant))
	var gap := Control.new()
	gap.custom_minimum_size.y = px(4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(gap)
	sheet.add_child(_text("REMPLAÇANTS", px(14), S.MUTED, Charte.TITRE_GRAS))
	var bench := GridContainer.new()
	bench.name = "TalkBench"
	bench.columns = 2
	bench.add_theme_constant_override("h_separation", px(8))
	bench.add_theme_constant_override("v_separation", px(5))
	sheet.add_child(bench)
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) > 15: bench.add_child(_player_card(participant, true))
	var right := S.G.v(px(8))
	S.G.fill(right, true)
	body.add_child(right)
	right.add_child(_air())
	if phase in ["pre", "half"] and not live.is_empty(): _meteo(right, live, phase)
	_talk(right)
	right.add_child(_air())
	var crumbs := S.G.h(0)
	right.add_child(crumbs)
	crumbs.add_child(_hspace())
	crumbs.add_child(_text("AVANT-MATCH  /  MATCH  /  MI-TEMPS  /  DÉBRIEF", px(12), S.MUTED))

# --- La causerie (commune) : destinataires, six tons, sans prendre la parole ; après la parole, le bilan. ---

func _talk(parent: Control) -> void:
	var declarations := S.panel(parent, px(14))
	declarations.add_theme_constant_override("separation", px(10))
	var decision: Variant = scene.get("decision")
	if decision is Dictionary:
		_bilan_causerie(declarations, decision)
		# Le bouton de sortie, grand et en or : c'est la seule action qui reste (le seul aplat doré de l'écran).
		var go_on := S.button("CONTINUER   →", _continue, true, true)
		go_on.name = "TalkContinue"
		go_on.custom_minimum_size.y = maxi(74, px(64))
		go_on.add_theme_font_size_override("font_size", maxi(24, px(24)))
		go_on.tooltip_text = "Reprendre le match (Entrée ou Espace)"
		for state in ["normal", "hover", "pressed"]:
			var style := Charte.style_pilule(Charte.OR_VIF if state == "hover" else Charte.DORE, Color.TRANSPARENT, 24, 8)
			go_on.add_theme_stylebox_override(state, style)
		declarations.add_child(go_on)
		call_deferred("_focus_continue", go_on)
		return
	var recipient_row := S.G.h(px(8))
	declarations.add_child(recipient_row)
	# Pas de mode d'emploi à l'écran (règle de Léo) : les onglets se comprennent seuls, le détail est en infobulle.
	for item in [["group", "GROUPE", "Parler à tout le groupe"], ["forwards", "AVANTS", "Parler aux avants"], ["backs", "ARRIÈRES", "Parler aux arrières"], ["players", "JOUEURS", "Viser des joueurs : touche leurs cartes, puis ta phrase"]]:
		var button := S.button(item[1], func(): _set_audience(item[0]))
		button.name = "TalkAudience_" + str(item[0])
		button.tooltip_text = item[2]
		button.custom_minimum_size.y = px(40)
		button.add_theme_font_size_override("font_size", px(15))
		button.add_theme_font_override("font", Charte.TITRE_GRAS)
		S.G.fill(button)
		# Onglet actif : aplat crème, texte encre (charte) ; le doré reste à l'action principale.
		if audience == item[0]:
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, Charte.style_pilule(Charte.CREME, Color.TRANSPARENT, 16, 6))
			for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				button.add_theme_color_override(key, Charte.ENCRE)
		recipient_row.add_child(button)
	var waiting_players: bool = audience == "players" and selected_ids.is_empty()
	# En mode Joueurs, seul l'état compte : combien de joueurs sont visés.
	if audience == "players":
		var prompt := "Aucun joueur visé" if waiting_players else "%d joueur%s visé%s" % [selected_ids.size(), "s" if selected_ids.size() > 1 else "", "s" if selected_ids.size() > 1 else ""]
		var prompt_label := _text(prompt, px(15), S.MUTED if waiting_players else Charte.VERT_CLAIR, Charte.TITRE_GRAS)
		prompt_label.name = "TalkPrompt"
		declarations.add_child(prompt_label)
	options_grid = GridContainer.new()
	options_grid.name = "TalkDeclarations"
	options_grid.columns = 6 if variante == "B" else 2
	options_grid.add_theme_constant_override("h_separation", px(10))
	options_grid.add_theme_constant_override("v_separation", px(10))
	declarations.add_child(options_grid)
	var ready_to_speak: bool = not waiting_players and scene.get("options", []).size() == 6
	for option: Dictionary in scene.get("options", []):
		options_grid.add_child(_tone_tile_b(option, ready_to_speak) if variante == "B" else _choice_card(option, ready_to_speak))
	if variante == "B": _apercu(declarations)
	var skip_row := S.G.h(px(8))
	declarations.add_child(skip_row)
	skip_row.add_child(_hspace())
	var skip := S.button("SANS PRENDRE LA PAROLE", func(): _continue(true))
	skip.name = "TalkSkip"
	skip.custom_minimum_size = Vector2(px(250), px(40))
	skip.add_theme_font_size_override("font_size", px(15))
	skip.add_theme_font_override("font", Charte.TITRE_GRAS)
	skip_row.add_child(skip)

## Focus clavier sur Continuer (Entrée/Espace), si le bouton est toujours affiché.
func _focus_continue(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

## Espace qui pousse le reste de la ligne à droite (le spacer du carnet est vertical).
static func _hspace() -> Control:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return space

## Espace vertical extensible : centre la causerie dans sa colonne.
static func _air() -> Control:
	var air := Control.new()
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return air

## Texte à la taille demandée (sans le barème des anciens écrans), police au choix.
static func _text(value: Variant, size: int, color: Color = S.TEXT, font: Font = null) -> Label:
	var label := Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", font if font != null else Charte.TEXTE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Le nom ne se coupe jamais : la taille descend jusqu'à `minimum` pour tenir dans la largeur donnée par la tuile ;
## au plus petit, le nom passe sur deux lignes plutôt que d'être tronqué.
static func _fit(label: Label, maximum: int, minimum: int) -> void:
	label.clip_text = true
	var refit := func() -> void:
		if not is_instance_valid(label) or label.size.x <= 0.0: return
		var font := label.get_theme_font("font")
		var size := maximum
		while size > minimum and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x: size -= 1
		var too_long := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x
		if label.get_theme_font_size("font_size") != size: label.add_theme_font_size_override("font_size", size)
		var mode := TextServer.AUTOWRAP_WORD_SMART if too_long else TextServer.AUTOWRAP_OFF
		if label.autowrap_mode != mode:
			label.autowrap_mode = mode
			label.clip_text = not too_long
	label.resized.connect(refit)

## Style d'une tuile : carte de rayon 12 avec l'ombre de la charte ; `liseré` : bord gauche à la couleur du club.
func _tile_style(fond: Color, contour: Color = Color.TRANSPARENT, lisere: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(px(Charte.RAYON_CARTE))
	style.anti_aliasing = true
	style.set_content_margin_all(0)
	if contour.a > 0:
		style.border_color = contour
		style.set_border_width_all(maxi(1, px(1.5)))
	if lisere.a > 0:
		style.border_color = lisere
		style.border_width_left = px(4)
	return Charte.ombrer(style, Charte.RAYON_CARTE)

## Pose les fonds d'une tuile cliquable : repos, survol, pression ; désactivée = même fond (la tuile reste lisible) ;
## focus clavier : fin contour crème.
func _skin_tile(button: Button, fond: Color, survol: Color, lisere: Color = Color.TRANSPARENT) -> void:
	button.add_theme_stylebox_override("normal", _tile_style(fond, Color.TRANSPARENT, lisere))
	button.add_theme_stylebox_override("hover", _tile_style(survol, Color.TRANSPARENT, lisere))
	button.add_theme_stylebox_override("pressed", _tile_style(Charte.PANNEAU_3, Color.TRANSPARENT, lisere))
	button.add_theme_stylebox_override("disabled", _tile_style(fond, Color.TRANSPARENT, lisere))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(px(Charte.RAYON_CARTE))
	focus.border_color = Charte.CREME
	focus.set_border_width_all(1)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)

## Portrait masqué (coins arrondis ou rond) ; l'identité inconnue garde un emplacement vide de même taille.
func _portrait(player: Dictionary, size: int, rond: bool) -> TextureRect:
	var portrait: TextureRect
	if player.is_empty():
		portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2.ONE * size
		portrait.tooltip_text = "Identité indisponible · aucun portrait attribué"
	else: portrait = S.G.portrait(int(player.get("portraitIndex", 0)), size, player)
	portrait.name = "ParticipantPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _masque == null:
		_masque = Shader.new()
		_masque.code = MASQUE_PORTRAIT
	var material := ShaderMaterial.new()
	material.shader = _masque
	material.set_shader_parameter("rayon", 0.5 if rond else 0.16)
	var atlas := portrait.texture as AtlasTexture
	if atlas != null and atlas.atlas != null:
		var whole := atlas.atlas.get_size()
		material.set_shader_parameter("region", Vector4(atlas.region.position.x / whole.x, atlas.region.position.y / whole.y, atlas.region.size.x / whole.x, atlas.region.size.y / whole.y))
	portrait.material = material
	return portrait

## Pictogramme d'un ton (tracé de ICONES_TONS), en cache par couleur.
static func tone_icon(tone: String, color: Color) -> Texture2D:
	var key := tone + ":" + color.to_html()
	if _icones.has(key): return _icones[key]
	if not ICONES_TONS.has(tone): return null
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [ICONES_TONS[tone], color.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	var texture := ImageTexture.create_from_image(image)
	_icones[key] = texture
	return texture

func _icon_rect(texture: Texture2D, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2.ONE * size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

## Pastille « visé » : coche crème sur aplat vert (la sélection se lit à la coche, pas à la couleur seule).
func _badge_vise(size: int) -> Control:
	var badge := PanelContainer.new()
	badge.name = "ParticipantTargeted"
	badge.tooltip_text = "Visé"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.custom_minimum_size = Vector2.ONE * size
	var style := Charte.style_pilule(Charte.VERT_FRANC, Color.TRANSPARENT, 0, 0)
	badge.add_theme_stylebox_override("panel", style)
	var check := _icon_rect(Icones.icon_texture("check", Charte.CREME), int(size * 0.7))
	check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_child(check)
	return badge

## Jauge de condition (donnée du joueur dans l'effectif) : rail crème 10 %, remplissage au barème des attributs.
func _condition_gauge(player: Dictionary, width: int) -> Control:
	var value: Variant = player.get("condition")
	if not (value is int or value is float): return null
	var gauge := ProgressBar.new()
	gauge.name = "ParticipantCondition"
	gauge.show_percentage = false
	gauge.min_value = 0
	gauge.max_value = 100
	gauge.value = clampf(float(value), 0.0, 100.0)
	gauge.custom_minimum_size = Vector2(width, maxi(4, px(4)))
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_theme_stylebox_override("background", Charte.style_pilule(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
	gauge.add_theme_stylebox_override("fill", Charte.style_pilule(Charte.couleur_attribut(gauge.value), Color.TRANSPARENT, 0, 0))
	gauge.tooltip_text = "Condition %d %%" % int(gauge.value)
	return gauge

## Tuile d'un joueur. A : carte (portrait arrondi, numéro en Anton, nom de famille, poste abrégé, condition) ;
## B : ligne de feuille de match (numéro en pastille, portrait rond, nom, liseré du club).
func _player_card(participant: Dictionary, compact: bool = false) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var full_name := str(player.get("name", "Identité indisponible"))
	var position_text := _position_label(participant, player)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	var reaction_label := str(reaction.get("label", ""))
	var number := int(participant.get("number", 0))
	var card := S.button("", func(): _toggle_player(id), decision.is_empty())
	card.set_meta("participant_id", id)
	card.set_meta("player_name", full_name)
	card.name = "Participant_%d" % number
	card.tooltip_text = "%d · %s · %s" % [number, full_name, position_text] + (" · " + reaction_label if not reaction_label.is_empty() else "")
	var in_audience: bool = audience in ["group", "players"] or participant.get("group") == audience
	var targeted: bool = audience == "players" and id in selected_ids
	if not decision.is_empty():
		var addressed: bool = id in decision.get("playerIds", [])
		in_audience = addressed
		targeted = addressed and str(decision.get("audience", "")) == "players"
	var lisere := Color.TRANSPARENT
	if variante == "B": lisere = Charte.club_trait(Color(str(S.G.identity(model.get("club", {})).get("color", "#71322f"))))
	var base := Charte.PANNEAU_2 if variante == "B" else S.PANEL
	# États en couleur, toujours avec un mot ou une coche : visé (vert, coche), réaction après la causerie (sa teinte).
	var teinte := Charte.VERT_CLAIR if targeted else Color.TRANSPARENT
	if not reaction_label.is_empty(): teinte = reaction_color(reaction)
	var fond := base.lerp(teinte, .16) if teinte.a > 0 else base
	_skin_tile(card, fond, fond.lerp(Charte.CREME, .06), lisere)
	# Règle de Léo : toute tuile agit. Clic = viser le joueur ; survol (ou touche I) = sa mini-fiche, posée devant la salle.
	if not player.is_empty():
		MiniFiche.lier(app, card, str(id), "squad")
		card.mouse_entered.connect(_mini_fiche_devant)
	# Hors du public visé : la tuile s'efface (la coche, elle, dit qui est visé).
	if not in_audience: card.modulate = Color(1, 1, 1, .42)
	var short_name := Nom.surname(full_name).to_upper() if not player.is_empty() else full_name
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(margin)
	card.add_child(margin)
	var row := S.G.h(px(8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var name_label := _text(short_name, px(19), S.TEXT, Charte.TITRE_GRAS)
	name_label.name = "ParticipantName"
	S.G.fill(name_label)
	var short_position := str(POSTES_COURTS.get(position_text, position_text))
	var position_label := _text(short_position, px(12), S.MUTED)
	position_label.name = "ParticipantPosition"
	position_label.set_meta("position", position_text)
	position_label.tooltip_text = position_text
	var status: Control = null
	if not reaction_label.is_empty():
		var reaction_text := _text(reaction_label, px(12), reaction_color(reaction), Charte.TITRE_GRAS)
		reaction_text.name = "ParticipantReaction"
		status = reaction_text
	if variante == "B":
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, px({"left": 10, "right": 8, "top": 4, "bottom": 4}[side]))
		card.custom_minimum_size.y = px(40)
		S.G.fill(card)
		var pastille := PanelContainer.new()
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.custom_minimum_size = Vector2.ONE * px(27)
		pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.PANNEAU_3 if not targeted else Charte.NOIR_PANNEAU, Color.TRANSPARENT, 0, 0))
		var digits := _text(str(number), px(15), S.TEXT, Charte.TITRE_GRAS)
		digits.name = "ParticipantNumber"
		digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pastille.add_child(digits)
		row.add_child(pastille)
		row.add_child(_portrait(player, px(32), true))
		var words := S.G.v(0)
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.G.fill(words)
		row.add_child(words)
		name_label.add_theme_font_size_override("font_size", px(16))
		_fit(name_label, px(16), px(12))
		words.add_child(name_label)
		position_label.add_theme_font_size_override("font_size", px(11))
		words.add_child(position_label)
		if status != null: row.add_child(status); status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if targeted: row.add_child(_badge_vise(px(20)))
		return card
	# Variante A.
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, px(5) if side != "right" else px(9))
	card.custom_minimum_size.y = px(60) if compact else px(56)
	if compact: S.G.fill(card)
	var portrait_size := px(50) if compact else px(46)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2.ONE * portrait_size
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(holder)
	var portrait := _portrait(player, portrait_size, false)
	holder.add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var digits := _text(str(number), px(26) if not compact else px(19), S.TEXT, Charte.TITRE_FICHE)
	digits.name = "ParticipantNumber"
	if compact:
		# Banc : le numéro se pose sur le coin du portrait, comme sur une carte de joueur.
		digits.add_theme_color_override("font_outline_color", Color(Charte.NOIR_PANNEAU, .85))
		digits.add_theme_constant_override("outline_size", px(5))
		holder.add_child(digits)
		digits.position = Vector2(px(3), portrait_size - px(28))
	else:
		digits.custom_minimum_size.x = px(32)
		digits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digits.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(digits)
	var words := S.G.v(px(1))
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(words)
	row.add_child(words)
	name_label.add_theme_font_size_override("font_size", px(17) if compact else px(20))
	_fit(name_label, px(17) if compact else px(20), px(12))
	words.add_child(name_label)
	# Banc : poste et état sous le nom, dans la même colonne ; titulaires : poste et état sur une ligne.
	var bottom: BoxContainer = words
	if not compact:
		bottom = S.G.h(px(6))
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(bottom)
	position_label.add_theme_font_size_override("font_size", px(11) if compact else px(12))
	position_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_label.clip_text = true
	bottom.add_child(position_label)
	if status != null:
		status.add_theme_font_size_override("font_size", px(13) if not compact else px(11))
		bottom.add_child(status)
	elif not compact:
		var gauge := _condition_gauge(player, px(34))
		if gauge != null: bottom.add_child(gauge)
	if compact and status == null:
		var gauge := _condition_gauge(player, px(30))
		if gauge != null: words.add_child(gauge); gauge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if targeted: row.add_child(_badge_vise(px(20)))
	return card

func _mini_fiche_devant() -> void:
	var fiche: Control = MiniFiche.actuelle(app)
	if fiche != null: fiche.z_index = 200

## Tuile d'un ton (variante A) : pictogramme et mot, la phrase complète dessous en plus petit.
## Un clic prononce la phrase aussitôt (aucune confirmation).
func _choice_card(option: Dictionary, enabled: bool = true) -> Button:
	var card := _tone_button(option, enabled)
	card.custom_minimum_size = Vector2(0, px(88))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, px(12) if side in ["left", "right"] else px(9))
	S.full(margin)
	card.add_child(margin)
	var words := S.G.v(px(3))
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(words)
	var head := S.G.h(px(8))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(head)
	var icon := _icon_rect(tone_icon(str(option.get("tone", "")), tone_color(str(option.get("tone", "")))), px(26))
	icon.name = "TalkChoiceIcon"
	head.add_child(icon)
	var tone := _text(tone_label(option).to_upper(), px(20), S.TEXT, Charte.TITRE_GRAS)
	tone.name = "TalkChoiceTone"
	head.add_child(tone)
	var sentence := _text(str(option.get("text", "")), px(13), S.MUTED)
	sentence.name = "TalkChoiceText"
	sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sentence.max_lines_visible = 3
	S.G.fill(sentence)
	words.add_child(sentence)
	return card

## Bouton commun aux tuiles de ton : nom, métadonnées (id, ton, phrase), fond de carte.
func _tone_button(option: Dictionary, enabled: bool) -> Button:
	var card := S.button("", func(): _select_choice(option), enabled)
	card.name = "TalkChoice_" + str(option.get("tone", ""))
	card.set_meta("choice_id", option.get("id", ""))
	card.set_meta("tone", option.get("tone", ""))
	card.set_meta("text", str(option.get("text", "")))
	card.tooltip_text = "%s · « %s »" % [tone_label(option), str(option.get("text", ""))]
	S.G.fill(card)
	var chosen := selected_choice == str(option.get("id", ""))
	var teinte := tone_color(str(option.get("tone", "")))
	# Léger fond teinté à la couleur du ton ; plus soutenu au survol et une fois choisi (avec un contour).
	_skin_tile(card, Charte.PANNEAU_2.lerp(teinte, .30 if chosen else .12), Charte.PANNEAU_2.lerp(teinte, .22))
	if chosen: card.add_theme_stylebox_override("normal", _tile_style(Charte.PANNEAU_2.lerp(teinte, .30), teinte))
	if not enabled: card.modulate = Color(1, 1, 1, .5)
	return card

## Tuile carrée d'un ton (variante B) : pictogramme et mot ; la phrase s'affiche dans l'aperçu au survol ou au focus.
func _tone_tile_b(option: Dictionary, enabled: bool = true) -> Button:
	var card := _tone_button(option, enabled)
	card.custom_minimum_size = Vector2(px(92), px(92))
	var box := S.G.v(px(6))
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(box)
	card.add_child(box)
	var icon := _icon_rect(tone_icon(str(option.get("tone", "")), tone_color(str(option.get("tone", "")))), px(34))
	icon.name = "TalkChoiceIcon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var tone := _text(tone_label(option).to_upper(), px(16), S.TEXT, Charte.TITRE_GRAS)
	tone.name = "TalkChoiceTone"
	tone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tone)
	card.mouse_entered.connect(func(): _show_apercu(option))
	card.focus_entered.connect(func(): _show_apercu(option))
	return card

## Zone d'aperçu unique (variante B) : le ton survolé et sa phrase entière.
func _apercu(parent: Control) -> void:
	var shell := PanelContainer.new()
	shell.name = "TalkPreview"
	var style := Charte.style_panneau(Charte.PANNEAU_2, px(Charte.RAYON_CARTE), px(12))
	style.content_margin_left = px(16)
	style.content_margin_right = px(16)
	shell.add_theme_stylebox_override("panel", style)
	shell.custom_minimum_size.y = px(84)
	parent.add_child(shell)
	var row := S.G.h(px(12))
	shell.add_child(row)
	_apercu_icone = _icon_rect(null, px(30))
	_apercu_icone.visible = false
	row.add_child(_apercu_icone)
	var words := S.G.v(px(2))
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	S.G.fill(words)
	row.add_child(words)
	_apercu_mot = _text("", px(15), S.MUTED, Charte.TITRE_GRAS)
	_apercu_mot.name = "TalkPreviewTone"
	words.add_child(_apercu_mot)
	_apercu_phrase = _text("« … »", px(17), Charte.IVOIRE_3)
	_apercu_phrase.name = "TalkPreviewText"
	_apercu_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apercu_phrase.max_lines_visible = 2
	words.add_child(_apercu_phrase)
	for option: Dictionary in scene.get("options", []):
		if str(option.get("id", "")) == selected_choice: _show_apercu(option)

func _show_apercu(option: Dictionary) -> void:
	if not is_instance_valid(_apercu_phrase): return
	var teinte := tone_color(str(option.get("tone", "")))
	_apercu_icone.texture = tone_icon(str(option.get("tone", "")), teinte)
	_apercu_icone.visible = true
	_apercu_mot.add_theme_color_override("font_color", teinte)
	_apercu_mot.text = tone_label(option).to_upper()
	_apercu_phrase.text = "« %s »" % str(option.get("text", ""))
	_apercu_phrase.add_theme_color_override("font_color", S.TEXT)

## Couleur franche d'un ton (gris-vert pour un ton inconnu).
static func tone_color(tone: String) -> Color:
	return COULEURS_TONS.get(tone, S.MUTED)

## Libellé français du ton (`toneLabel` du moteur, sinon la table des six tons).
static func tone_label(option: Dictionary) -> String:
	var label := str(option.get("toneLabel", "")).strip_edges()
	if not label.is_empty(): return label
	var tone := str(option.get("tone", ""))
	return str(TONS.get(tone, tone.capitalize()))

## Réaction d'un joueur à la causerie ({id, score, etat, label, delta}), ou {}.
static func reaction_of(decision: Dictionary, id: Variant) -> Dictionary:
	var rows: Variant = decision.get("reactions", [])
	if rows is Array:
		for row: Variant in rows:
			if row is Dictionary and str(row.get("id", "")) == str(id): return row
	return {}

## Couleur d'une réaction : vert si elle porte, rouge de l'alerte si elle braque, neutre sinon.
static func reaction_color(reaction: Dictionary) -> Color:
	var delta: Variant = reaction.get("delta", 0)
	var direction: int = signi(int(delta)) if delta is int or delta is float else 0
	return Pilotage.teinte(direction, S.MUTED)

## Après la parole : ton et phrase, qui a parlé, effet sur le moral et répartition des réactions visibles.
func _bilan_causerie(parent: VBoxContainer, decision: Dictionary) -> void:
	var by_staff := str(decision.get("par", "manager")) == "staff"
	var title := _text(("Le staff a parlé · " if by_staff else "Ton message · ") + tone_label(decision), px(22), tone_color(str(decision.get("tone", ""))), Charte.TITRE_GRAS)
	title.name = "TalkDecisionTone"
	parent.add_child(title)
	parent.add_child(_wrap_text("« %s »" % str(decision.get("text", "")), px(17), S.TEXT))
	var morale: int = int(decision.get("moraleDelta", 0)) if decision.get("moraleDelta") is int or decision.get("moraleDelta") is float else 0
	if str(decision.get("audience", "")) != "players":
		var morale_text := "Moral du groupe inchangé" if morale == 0 else "Moral du groupe %s%d" % ["+" if morale > 0 else "−", absi(morale)]
		var morale_label := _text(morale_text, px(15), Pilotage.teinte(signi(morale), S.MUTED))
		morale_label.name = "TalkDecisionMorale"
		parent.add_child(morale_label)
	var counts := {}
	var order: Array = []
	var colors := {}
	var rows: Array = decision.get("reactions") if decision.get("reactions") is Array else []
	for row: Variant in rows:
		if not row is Dictionary or str(row.get("label", "")).is_empty(): continue
		var label := str(row.label)
		if not counts.has(label):
			order.append(label)
			counts[label] = 0
			colors[label] = reaction_color(row)
		counts[label] = int(counts[label]) + 1
	if not order.is_empty():
		var summary := S.G.h(10)
		summary.name = "TalkDecisionReactions"
		parent.add_child(summary)
		for label: String in order:
			summary.add_child(_text("%d %s" % [int(counts[label]), label.to_lower()], px(14), colors[label]))

func _position_label(participant: Dictionary, player: Dictionary) -> String:
	var number := int(participant.get("number", 0))
	if number >= 1 and number <= 15:
		# A starter's match role follows the jersey, even when his primary
		# individual position differs. Reuse the engine's slot label when given.
		for slot: Dictionary in model.get("selection", {}).get("slots", []):
			if int(slot.get("slot", -1)) != number - 1: continue
			var label := str(slot.get("label", "")).strip_edges()
			if not label.is_empty():
				return "Troisième ligne aile" if number in [6, 7] and label == "Troisième ligne" else _position_display(label)
		return STARTER_POSITIONS[number - 1]
	# Bench numbers are not position assignments. pos is the projected primary
	# position (rosterProfile.position.primary in common careers), not a guess
	# from a bench slot or a newly calculated attribute rating.
	var primary: Variant = player.get("pos")
	if not primary is String or primary.strip_edges().is_empty():
		var profile: Dictionary = player.get("rosterProfile", {}) if player.get("rosterProfile") is Dictionary else {}
		primary = profile.get("position", {}).get("primary", "")
	return _position_display(primary.strip_edges()) if primary is String and not primary.strip_edges().is_empty() else "Poste non renseigné"

func _position_display(value: String) -> String:
	return "Troisième ligne centre" if value in ["Numéro 8", "N° 8", "N°8"] else value

## Choisir une phrase la prononce : le destinataire est déjà fixé (groupe, ligne ou joueurs visés).
func _select_choice(option: Dictionary) -> void:
	if app.waiting or scene.get("decision") is Dictionary: return
	if audience == "players" and selected_ids.is_empty(): return
	selected_choice = str(option.get("id", ""))
	_draw()
	_pronounce()

func _set_audience(value: String) -> void:
	if app.waiting: return
	audience = value
	_draw()

func _toggle_player(id: Variant) -> void:
	if app.waiting or scene.get("decision") is Dictionary: return
	audience = "players"
	if id in selected_ids: selected_ids.erase(id)
	else: selected_ids.append(id)
	_draw()

func _pronounce() -> void:
	if selected_choice.is_empty() or (audience == "players" and selected_ids.is_empty()): return
	director.command("match_talk_decide", {"key":scene.get("key"), "phase":scene.get("phase"), "choiceId":selected_choice, "audience":audience, "playerIds":selected_ids.duplicate() if audience == "players" else []})

func _continue(skip: bool = false) -> void:
	var payload := {"key":scene.get("key"), "phase":scene.get("phase")}
	if skip: payload.skip = true
	director.command("match_talk_continue", payload)

## La météo du match vue du vestiaire : ciel et terrain, camp qui a le vent dans le dos, conseil du staff.
func _meteo(parent: Control, live: Dictionary, phase: String) -> void:
	var titre := Meteo.libelle(live)
	if titre.is_empty(): return
	var cadre := S.panel(parent, px(12))
	cadre.name = "TalkWeather"
	cadre.add_theme_constant_override("separation", px(4))
	cadre.add_child(_text("LA MÉTÉO  ·  " + titre.to_upper(), px(14), Color("8fc1e8"), Charte.TITRE_GRAS))
	var vent := Meteo.phrase_vent(live, phase)
	if not vent.is_empty(): cadre.add_child(_wrap_text(vent, px(14), S.TEXT))
	var conseil := Meteo.conseil(live)
	if not conseil.is_empty(): cadre.add_child(_wrap_text(conseil, px(13), S.MUTED))

static func _wrap_text(value: Variant, size: int, color: Color) -> Label:
	var label := _text(value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
