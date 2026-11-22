extends Control
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const Nom = preload("res://ui/person_name.gd")
const Icones = preload("res://ui/immersive08/components.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
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
## Masque des portraits : carré à coins arrondis ou rond, y compris sur une planche (atlas).
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
## Échelle des tuiles : 1 en 1280 × 720, jusqu'à 1,5 en 1920 × 1080 (taille logique de la fenêtre).
var _k := 1.0
var _vp := Vector2.ZERO
## Petite fenêtre d'un joueur (portrait, numéro, tuiles d'état) et page de sa fiche complète, posées sur la salle.
var _fenetre: Control
var _page_fiche: Control
var _fenetre_id := ""

func _ready() -> void:
	name = "ContextualLocker"
	app = director.app
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
	if phase != "pre" and scores.size() == 2: subtitle += "   ·   %s — %s" % [score_text(scores[0]), score_text(scores[1])]
	var head := S.G.h(px(14))
	column.add_child(head)
	head.add_child(S.G.crest(model.get("club", {}), px(42)))
	var head_words := S.G.v(px(1))
	S.G.fill(head_words)
	head.add_child(head_words)
	head_words.add_child(_text(title, px(23), S.TEXT, Charte.TITRE_FICHE))
	head_words.add_child(_text(subtitle, px(13), S.MUTED))
	_layout(column, live, phase)
	# Redessin (fenêtre redimensionnée, nouvelle image du moteur) : la petite fenêtre ouverte le reste.
	if not _fenetre_id.is_empty(): open_player_window(_fenetre_id)
	director._refresh_controls()

# --- Deux colonnes de cartes joueur, la causerie au centre, le banc en bas. ---

func _layout(column: VBoxContainer, live: Dictionary, phase: String) -> void:
	# Planche FM27 n° 7 (CD_VARIANTE_VISUELLE=A|B) : A = liste à la Effectif, B = le vestiaire par lignes.
	var variante := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	if variante == "A":
		_layout_liste(column, live, phase)
		return
	if variante == "B":
		_layout_lignes(column, live, phase)
		return
	var body := S.G.h(px(14))
	S.G.fill(body, true)
	column.add_child(body)
	_roster(body, "AVANTS", "forwards")
	var middle := S.G.v(px(8))
	S.G.fill(middle, true)
	body.add_child(middle)
	middle.add_child(_air())
	if phase in ["pre", "half"] and not live.is_empty(): _meteo(middle, live, phase)
	_talk(middle)
	middle.add_child(_air())
	_roster(body, "ARRIÈRES", "backs")
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

func _roster(parent: Node, title: String, group: String) -> void:
	var list := S.G.v(px(5))
	list.custom_minimum_size.x = px(292)
	parent.add_child(list)
	list.add_child(_text(title, px(14), S.MUTED, Charte.TITRE_GRAS))
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) <= 15 and participant.get("group") == group:
			list.add_child(_player_card(participant))

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
	options_grid.columns = 2
	options_grid.add_theme_constant_override("h_separation", px(10))
	options_grid.add_theme_constant_override("v_separation", px(10))
	declarations.add_child(options_grid)
	var ready_to_speak: bool = not waiting_players and scene.get("options", []).size() == 6
	for option: Dictionary in scene.get("options", []):
		options_grid.add_child(_choice_card(option, ready_to_speak))
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

## Style d'une tuile : carte de rayon 12 avec l'ombre de la charte ; `liseré` : bord gauche coloré.
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

## Tuile d'un joueur : carte (portrait arrondi, numéro en Anton, nom de famille, poste abrégé, condition ou réaction).
func _player_card(participant: Dictionary, compact: bool = false) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var full_name := str(player.get("name", "Identité indisponible"))
	var position_text := _position_label(participant, player)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	var reaction_label := str(reaction.get("label", ""))
	var number := int(participant.get("number", 0))
	# Toute tuile agit : onglet Joueurs = viser ; sinon (et après la parole) = la petite fenêtre du joueur.
	var card := S.button("", func(): _on_player_pressed(id))
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
	var base := S.PANEL
	# États en couleur, toujours avec un mot ou une coche : visé (vert, coche), réaction après la causerie (sa teinte).
	var teinte := Charte.VERT_CLAIR if targeted else Color.TRANSPARENT
	if not reaction_label.is_empty(): teinte = reaction_color(reaction)
	var fond := base.lerp(teinte, .16) if teinte.a > 0 else base
	_skin_tile(card, fond, fond.lerp(Charte.CREME, .06))
	# Survol (ou touche I) = la mini-fiche du joueur, posée devant la salle.
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

## Tuile d'un ton : pictogramme et mot, la phrase complète dessous en plus petit.
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
	if not order.is_empty() and not OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().is_empty():
		parent.add_child(_barre_reactions(rows))
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

## Score d'un camp sans décimales (le direct peut transmettre 21.0).
static func score_text(value: Variant) -> String:
	return str(roundi(float(value))) if value is int or value is float else str(value)

## Clic sur un joueur : dans l'onglet Joueurs (avant la parole), il est visé ou ne l'est plus ; ailleurs, sa petite fenêtre.
func _on_player_pressed(id: Variant) -> void:
	if app.waiting: return
	if audience == "players" and not scene.get("decision") is Dictionary: _toggle_player(id)
	else: open_player_window(id)

## Petite fenêtre visuelle d'un joueur (règle de Léo : permise si elle reste visuelle) : portrait, numéro, nom, poste,
## tuiles d'état (condition, fatigue, moral, réaction après la parole) et l'accès à la fiche complète.
func open_player_window(id: Variant) -> void:
	close_player_window()
	var participant: Dictionary = {}
	for row: Dictionary in scene.get("participants", []):
		if str(row.get("id", "")) == str(id): participant = row
	var player := S.person(model, id)
	if participant.is_empty() or player.is_empty() or not is_instance_valid(ui): return
	MiniFiche.cacher(app)
	_fenetre_id = str(id)
	var layer := Control.new()
	layer.name = "TalkPlayerWindowLayer"
	S.full(layer)
	ui.add_child(layer)
	_fenetre = layer
	# Petite fenêtre : Échap la ferme (mécanisme commun, ui/petite_fenetre.gd).
	PetiteFenetre.enregistrer(layer, close_player_window)
	var voile := ColorRect.new()
	voile.color = Color(Charte.NUIT, .55)
	S.full(voile)
	voile.gui_input.connect(_on_voile_input)
	layer.add_child(voile)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(center)
	layer.add_child(center)
	var shell := PanelContainer.new()
	shell.name = "TalkPlayerPopup"
	shell.set_meta("player_id", str(id))
	shell.add_theme_stylebox_override("panel", Charte.style_panneau(S.PANEL, px(Charte.RAYON_PANNEAU), px(20)))
	shell.custom_minimum_size.x = px(500)
	center.add_child(shell)
	var column := S.G.v(px(14))
	shell.add_child(column)
	var head := S.G.h(px(14))
	column.add_child(head)
	head.add_child(_portrait(player, px(104), false))
	var number := _text(str(int(participant.get("number", 0))), px(52), S.TEXT, Charte.TITRE_FICHE)
	number.name = "TalkPlayerPopupNumber"
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.custom_minimum_size.x = px(48)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(number)
	var words := S.G.v(px(2))
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	S.G.fill(words)
	head.add_child(words)
	var full_name := str(player.get("name", ""))
	var surname := Nom.surname(full_name)
	var name_label := _text(surname.to_upper(), px(28), S.TEXT, Charte.TITRE_GRAS)
	name_label.name = "TalkPlayerPopupName"
	_fit(name_label, px(28), px(16))
	words.add_child(name_label)
	var first := full_name.substr(0, full_name.length() - surname.length()).strip_edges()
	if not first.is_empty(): words.add_child(_text(first, px(14), S.MUTED))
	words.add_child(_text(_position_label(participant, player), px(14), S.MUTED))
	var close := S.button("✕", close_player_window)
	close.name = "TalkPlayerPopupClose"
	close.tooltip_text = "Fermer"
	close.custom_minimum_size = Vector2(px(38), px(38))
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_focus_lisible(close)
	head.add_child(close)
	var tiles := S.G.h(px(10))
	tiles.name = "TalkPlayerPopupTiles"
	column.add_child(tiles)
	var condition: Variant = player.get("condition")
	if condition is int or condition is float:
		_state_tile(tiles, "CONDITION", "%d %%" % roundi(float(condition)), Charte.couleur_attribut(float(condition)), float(condition))
	var fatigue: Variant = player.get("physicalLoad")
	if fatigue is Dictionary: fatigue = fatigue.get("fatigue")
	if fatigue is int or fatigue is float:
		_state_tile(tiles, "FATIGUE", "%d" % roundi(float(fatigue)), Charte.couleur_attribut(100.0 - float(fatigue)), float(fatigue))
	var morale: Variant = _player_morale(player)
	if morale != null: _state_tile(tiles, "MORAL", "%d" % roundi(float(morale)), Charte.couleur_attribut(float(morale)), float(morale))
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	if not str(reaction.get("label", "")).is_empty():
		_state_tile(tiles, "RÉACTION", str(reaction.label), reaction_color(reaction), -1.0)
	var actions := S.G.h(px(8))
	column.add_child(actions)
	actions.add_child(_hspace())
	var sheet := S.button("FICHE COMPLÈTE   →", func(): open_full_sheet(id))
	sheet.name = "TalkPlayerFullSheet"
	sheet.custom_minimum_size = Vector2(px(220), px(40))
	sheet.add_theme_font_override("font", Charte.TITRE_GRAS)
	sheet.add_theme_font_size_override("font_size", px(15))
	_focus_lisible(sheet)
	actions.add_child(sheet)
	sheet.call_deferred("grab_focus")

## Bouton secondaire qui reçoit le focus à l'ouverture : texte crème et contour crème (lisible, jamais encre sur noir).
func _focus_lisible(button: Button) -> void:
	button.add_theme_color_override("font_focus_color", S.TEXT)
	var focus := Charte.style_pilule(Color.TRANSPARENT, Charte.CREME, 16, 6)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)

func _on_voile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: close_player_window()

## Une tuile d'état de la petite fenêtre : intitulé, valeur en couleur (jamais seule : le chiffre ou le mot est écrit),
## jauge quand la valeur est sur 100.
func _state_tile(parent: Control, title: String, value: String, color: Color, gauge: float) -> void:
	var tile := PanelContainer.new()
	tile.name = "TalkPlayerState_" + title.validate_node_name()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.PANNEAU_2.lerp(color, .10), px(Charte.RAYON_CARTE), px(12)))
	S.G.fill(tile)
	parent.add_child(tile)
	var column := S.G.v(px(4))
	tile.add_child(column)
	column.add_child(_text(title, px(13), S.MUTED, Charte.TITRE_GRAS))
	var short := value.length() <= 6
	var shown := _text(value, px(30) if short else px(22), color, Charte.TITRE_FICHE if short else Charte.TITRE_GRAS)
	shown.name = "TalkPlayerStateValue"
	column.add_child(shown)
	if gauge >= 0.0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100
		bar.value = clampf(gauge, 0.0, 100.0)
		bar.custom_minimum_size = Vector2(0, maxi(4, px(5)))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", Charte.style_pilule(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0))
		bar.add_theme_stylebox_override("fill", Charte.style_pilule(color, Color.TRANSPARENT, 0, 0))
		column.add_child(bar)

## Moral d'un joueur : sa note de relation avec le staff (clubLife.relationships.players, comme sur la fiche).
func _player_morale(player: Dictionary) -> Variant:
	var life: Variant = model.get("clubLife", {})
	if not life is Dictionary: return null
	var relations: Variant = life.get("relationships", {})
	if not relations is Dictionary: return null
	var members: Variant = relations.get("players", [])
	if not members is Array: return null
	for member: Variant in members:
		if member is Dictionary and str(member.get("id", "")) == str(player.get("id", "")):
			var score: Variant = member.get("score")
			return score if score is int or score is float else null
	return null

func close_player_window() -> void:
	_fenetre_id = ""
	if is_instance_valid(_fenetre): _fenetre.queue_free()
	_fenetre = null

## Fiche complète du joueur, en page posée sur le vestiaire ; « Retour au vestiaire » la referme.
func open_full_sheet(id: Variant) -> void:
	close_player_window()
	var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, str(id), "squad")
	if trouve.is_empty() or not is_instance_valid(ui): return
	var page := Control.new()
	page.name = "TalkPlayerSheet"
	S.full(page)
	ui.add_child(page)
	_page_fiche = page
	# Échap revient au vestiaire, comme le bouton Retour.
	PetiteFenetre.enregistrer(page, close_full_sheet)
	var fond := ColorRect.new()
	fond.color = Charte.FOND
	S.full(fond)
	page.add_child(fond)
	var column := S.frame(page, px(16))
	var top := S.G.h(px(8))
	column.add_child(top)
	var back := S.button("←   RETOUR AU VESTIAIRE", close_full_sheet)
	back.name = "TalkPlayerSheetBack"
	back.custom_minimum_size.y = px(40)
	back.add_theme_font_override("font", Charte.TITRE_GRAS)
	back.add_theme_font_size_override("font_size", px(15))
	_focus_lisible(back)
	top.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	S.G.fill(scroll, true)
	column.add_child(scroll)
	var fiche: Control = load("res://ui/immersive08/player_canvas.gd").build(app, trouve.joueur, "squad")
	fiche.name = "TalkPlayerSheetCanvas"
	scroll.add_child(fiche)
	# Comme dans le direct : les actions de gestion de la fiche attendent la fin du match.
	load("res://ui/contextual/live_view.gd").neutraliser(fiche)
	back.call_deferred("grab_focus")

func close_full_sheet() -> void:
	if is_instance_valid(_page_fiche): _page_fiche.queue_free()
	_page_fiche = null

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

# --- Planche FM27 n° 7 : réactions en pastilles colorées, liste à la Effectif (A) ou vestiaire par lignes (B). ---

## État de réaction (moteur, PILOTAGE_ETATS) : couleur franche et symbole ; le mot reste toujours écrit.
const REACTIONS := {"galvanise": [Color("3debb4"), "▲▲"], "motive": [Color("7fbf7a"), "▲"], "serein": [Color("5b9bd5"), "●"],
	"indifferent": [Color("abb7b1"), "–"], "tendu": [Color("e0a04a"), "▼"], "vexe": [Color("d9634f"), "▼"], "relache": [Color("a88bd6"), "▼"]}
const LIGNES := [["1re LIGNE", [1, 2, 3]], ["2e LIGNE", [4, 5]], ["3e LIGNE", [6, 7, 8]], ["CHARNIÈRE", [9, 10]],
	["TROIS-QUARTS", [11, 12, 13, 14, 15]], ["BANC", [16, 17, 18, 19, 20, 21, 22, 23]]]

static func couleur_reaction(reaction: Dictionary) -> Color:
	var defaut: Array = [reaction_color(reaction), ""]
	return REACTIONS.get(str(reaction.get("etat", "")), defaut)[0]

## Pastille de réaction : fond teinté, symbole + mot en couleur franche ; « — » avant la parole.
func _pastille_reaction(reaction: Dictionary, taille: int) -> Control:
	var label := str(reaction.get("label", ""))
	if label.is_empty():
		var vide := _text("—", taille, Charte.IVOIRE_3)
		vide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return vide
	var teinte := couleur_reaction(reaction)
	var p := PanelContainer.new()
	p.name = "ParticipantReaction"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_theme_stylebox_override("panel", Charte.style_pilule(Color(teinte, .2), Color.TRANSPARENT, px(8), px(2)))
	var defaut: Array = [teinte, ""]
	var symbole: String = REACTIONS.get(str(reaction.get("etat", "")), defaut)[1]
	p.add_child(_text((symbole + "  " if not symbole.is_empty() else "") + label.to_upper(), taille, teinte, Charte.TITRE_GRAS))
	return p

## Barre empilée des réactions (une couleur par état, proportionnelle au nombre de joueurs).
func _barre_reactions(rows: Array) -> Control:
	var barre := HBoxContainer.new()
	barre.name = "TalkReactionsBar"
	barre.add_theme_constant_override("separation", 2)
	barre.custom_minimum_size.y = px(10)
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var comptes := {}
	for row: Variant in rows:
		if row is Dictionary: comptes[str(row.get("etat", ""))] = int(comptes.get(str(row.get("etat", "")), 0)) + 1
	for etat: String in REACTIONS:
		if not comptes.has(etat): continue
		var bloc := Panel.new()
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.size_flags_stretch_ratio = float(comptes[etat])
		bloc.add_theme_stylebox_override("panel", Charte.style_pilule(REACTIONS[etat][0], Color.TRANSPARENT, 0, 0))
		barre.add_child(bloc)
	return barre

## Note : celle du match en cours (mi-temps), sinon la dernière note de match ; null si aucune.
func _note_de(id: Variant) -> Variant:
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var notes: Variant = direct.get("notes", {})
	if notes is Dictionary and notes.get(str(id)) is Dictionary and notes[str(id)].get("note") != null: return float(notes[str(id)].note)
	var forme: Variant = load("res://ui/notes_match.gd").joueur(model, str(id)).get("forme", [])
	if forme is Array and not forme.is_empty() and (forme[-1] is float or forme[-1] is int): return float(forme[-1])
	return null

func _pastille_note(id: Variant) -> Control:
	var note: Variant = _note_de(id)
	if note == null:
		var vide := _text("—", px(13), Charte.IVOIRE_3)
		vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return vide
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.couleur_note(note), Color.TRANSPARENT, px(6), px(1)))
	var l := _text(("%.1f" % float(note)).replace(".", ","), px(13), Charte.encre_note(note), Charte.TITRE_GRAS)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _participants_par_numero() -> Dictionary:
	var par := {}
	for participant: Dictionary in scene.get("participants", []): par[int(participant.get("number", 0))] = participant
	return par

## Colonne de la parole commune aux deux variantes : météo, causerie (destinataires, six tons) ou bilan.
func _colonne_parole(parent: Control, live: Dictionary, phase: String, largeur: int) -> void:
	var colonne := S.G.v(px(8))
	colonne.custom_minimum_size.x = largeur
	parent.add_child(colonne)
	if phase in ["pre", "half"] and not live.is_empty(): _meteo(colonne, live, phase)
	_talk(colonne)
	colonne.add_child(_air())

# A : liste à la Effectif, une ligne par joueur (n°, visage, nom, poste, condition, moral, réaction, note).
const COLONNES_A := [["", 26], ["N°", 34], ["", 36], ["JOUEUR", -1], ["POSTE", 104], ["COND.", 54], ["MORAL", 54], ["RÉACTION", 150], ["NOTE", 50]]  # largeurs en px de 720p

func _layout_liste(column: VBoxContainer, live: Dictionary, phase: String) -> void:
	var body := S.G.h(px(14))
	S.G.fill(body, true)
	column.add_child(body)
	_colonne_parole(body, live, phase, px(420))
	var liste := S.panel(body, px(10))
	liste.name = "TalkList"
	liste.add_theme_constant_override("separation", 0)
	S.G.fill(liste.get_parent().get_parent(), true)
	var tete := S.G.h(px(8))
	tete.custom_minimum_size.y = px(22)
	liste.add_child(tete)
	for c: Array in COLONNES_A:
		var l := _text(c[0], px(11), Charte.IVOIRE_3, Charte.TITRE_GRAS)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if int(c[1]) > 0: l.custom_minimum_size.x = px(c[1])
		else: S.G.fill(l)
		tete.add_child(l)
	var par := _participants_par_numero()
	var groupes := [["AVANTS", range(1, 9)], ["ARRIÈRES", range(9, 16)], ["REMPLAÇANTS", range(16, 24)]]
	var rang := 0
	for g: Array in groupes:
		var st := _text(str(g[0]), px(11), Charte.D, Charte.TITRE_GRAS)
		st.custom_minimum_size.y = px(17)
		st.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		liste.add_child(st)
		for n: int in g[1]:
			if not par.has(n): continue
			liste.add_child(_ligne_a(par[n], rang))
			rang += 1

func _fond_ligne(fond: Color, contour: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fond
	st.draw_center = fond.a > 0
	st.set_corner_radius_all(Charte.RAYON_PETIT)
	if contour.a > 0:
		st.border_color = contour
		st.set_border_width_all(1)
	return st

func _ligne_a(participant: Dictionary, rang: int) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	var number := int(participant.get("number", 0))
	var ligne := S.button("", func(): _on_player_pressed(id))
	ligne.name = "Participant_%d" % number
	ligne.set_meta("participant_id", id)
	ligne.custom_minimum_size.y = px(21)
	var in_audience: bool = audience in ["group", "players"] or participant.get("group") == audience
	var targeted: bool = audience == "players" and id in selected_ids
	if not decision.is_empty():
		in_audience = id in decision.get("playerIds", [])
		targeted = in_audience and str(decision.get("audience", "")) == "players"
	var fond := Charte.SELECTION if targeted else (Charte.PANNEAU if rang % 2 == 0 else Charte.PANNEAU_2)
	for etat in ["normal", "disabled"]: ligne.add_theme_stylebox_override(etat, _fond_ligne(fond))
	for etat in ["hover", "pressed"]: ligne.add_theme_stylebox_override(etat, _fond_ligne(fond.lerp(Charte.CREME, .10)))
	ligne.add_theme_stylebox_override("focus", _fond_ligne(Color.TRANSPARENT, Charte.CREME))
	if not player.is_empty():
		MiniFiche.lier(app, ligne, str(id), "squad")
		ligne.mouse_entered.connect(_mini_fiche_devant)
	if not in_audience: ligne.modulate = Color(1, 1, 1, .45)
	var row := S.G.h(px(8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(row)
	row.offset_left = px(4)
	row.offset_right = -px(4)
	ligne.add_child(row)
	# Case à cocher (onglet Joueurs) : coche verte = visé.
	var caseb := CenterContainer.new()
	caseb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caseb.custom_minimum_size = Vector2(px(26), px(14))
	row.add_child(caseb)
	if targeted:
		caseb.add_child(_badge_vise(px(16)))
	elif audience == "players" and decision.is_empty():
		var vide := Panel.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.custom_minimum_size = Vector2(px(14), px(14))
		var st := StyleBoxFlat.new()
		st.draw_center = false
		st.border_color = Charte.IVOIRE_2
		st.set_border_width_all(1)
		st.set_corner_radius_all(3)
		vide.add_theme_stylebox_override("panel", st)
		caseb.add_child(vide)
	var num := _text(str(number), px(17), S.TEXT, Charte.TITRE_FICHE)
	num.custom_minimum_size.x = px(34)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(num)
	var cadre := CenterContainer.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.custom_minimum_size.x = px(36)
	cadre.add_child(_portrait(player, px(19), true))
	row.add_child(cadre)
	var full_name := str(player.get("name", "Identité indisponible"))
	var nom := _text(Nom.surname(full_name).to_upper() if not player.is_empty() else full_name, px(15), S.TEXT, Charte.TITRE_GRAS)
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nom.clip_text = true
	S.G.fill(nom)
	row.add_child(nom)
	var poste_long := _position_label(participant, player)
	var poste := _text(str(POSTES_COURTS.get(poste_long, poste_long)), px(12), S.MUTED)
	poste.custom_minimum_size.x = px(104)
	poste.clip_text = true
	poste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(poste)
	var cond: Variant = player.get("condition")
	var a_cond: bool = cond is int or cond is float
	var c := _text("%d" % roundi(float(cond)) if a_cond else "—", px(15), Charte.couleur_attribut(float(cond)) if a_cond else Charte.IVOIRE_3, Charte.TITRE_GRAS)
	c.custom_minimum_size.x = px(54)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var moral: Variant = _player_morale(player)
	var m := _text("%d" % roundi(float(moral)) if moral != null else "—", px(15), Charte.MORAL if moral != null else Charte.IVOIRE_3, Charte.TITRE_GRAS)
	m.custom_minimum_size.x = px(54)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(m)
	var cellule := HBoxContainer.new()
	cellule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cellule.custom_minimum_size.x = px(150)
	cellule.add_child(_pastille_reaction(reaction, px(11)))
	row.add_child(cellule)
	var note := CenterContainer.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.custom_minimum_size.x = px(50)
	note.add_child(_pastille_note(id))
	row.add_child(note)
	ligne.tooltip_text = "%d · %s · %s" % [number, full_name, poste_long] + (" · " + str(reaction.label) if reaction.has("label") else "")
	return ligne

# B : le vestiaire par lignes ; clic sur le nom d'une ligne = parler à cette ligne (joueurs visés).
func _layout_lignes(column: VBoxContainer, live: Dictionary, phase: String) -> void:
	var body := S.G.h(px(14))
	S.G.fill(body, true)
	column.add_child(body)
	var gauche := S.G.v(px(8))
	S.G.fill(gauche, true)
	body.add_child(gauche)
	var par := _participants_par_numero()
	var grille := GridContainer.new()
	grille.name = "TalkLines"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", px(10))
	grille.add_theme_constant_override("v_separation", px(8))
	gauche.add_child(grille)
	for i in 4: grille.add_child(_bande_ligne(LIGNES[i], par, false))
	gauche.add_child(_bande_ligne(LIGNES[4], par, false))
	gauche.add_child(_bande_ligne(LIGNES[5], par, true))
	gauche.add_child(_air())
	_colonne_parole(body, live, phase, px(400))

func _bande_ligne(ligne_def: Array, par: Dictionary, compact: bool) -> Control:
	var ids: Array = []
	for n: int in ligne_def[1]:
		if par.has(n): ids.append(par[n].get("id"))
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var visee: bool = not ids.is_empty() and audience == "players" and ids.all(func(x): return x in selected_ids)
	var cadre := PanelContainer.new()
	cadre.name = "TalkLine_" + str(ligne_def[0]).validate_node_name()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.add_theme_stylebox_override("panel", Charte.style_panneau(Charte.SELECTION if visee else Color(Charte.PANNEAU, .92), px(Charte.RAYON_CARTE), px(8)))
	var pile := S.G.v(px(5))
	cadre.add_child(pile)
	var tete := S.G.h(px(8))
	pile.add_child(tete)
	var bouton := S.button(str(ligne_def[0]) + "  ·  %d" % ids.size(), func(): _viser_ligne(ids), decision.is_empty())
	bouton.name = "TalkLineTarget_" + str(ligne_def[0]).validate_node_name()
	bouton.tooltip_text = "Parler à cette ligne"
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
	bouton.add_theme_font_size_override("font_size", px(13))
	bouton.custom_minimum_size.y = px(24)
	tete.add_child(bouton)
	tete.add_child(_hspace())
	# Réactions de la ligne en petite barre empilée (après la parole).
	var lignes_reac: Array = []
	for id: Variant in ids:
		var r := reaction_of(decision, id)
		if not r.is_empty(): lignes_reac.append(r)
	if not lignes_reac.is_empty():
		var barre := _barre_reactions(lignes_reac)
		barre.custom_minimum_size = Vector2(px(90), px(8))
		barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(barre)
	var rangee := S.G.h(px(6))
	pile.add_child(rangee)
	for n: int in ligne_def[1]:
		if par.has(n): rangee.add_child(_jeton(par[n], compact))
	return cadre

func _viser_ligne(ids: Array) -> void:
	if app.waiting or scene.get("decision") is Dictionary: return
	audience = "players"
	var deja: bool = ids.all(func(x): return x in selected_ids)
	for id: Variant in ids:
		if deja: selected_ids.erase(id)
		elif not id in selected_ids: selected_ids.append(id)
	_draw()

## Jeton d'un joueur : visage rond cerclé de la couleur de sa réaction (ou de sa condition avant la parole),
## numéro et nom, pastille de réaction (après la parole) ou dernière note dessous.
func _jeton(participant: Dictionary, compact: bool) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	var number := int(participant.get("number", 0))
	var jeton := S.button("", func(): _on_player_pressed(id))
	jeton.name = "Participant_%d" % number
	jeton.set_meta("participant_id", id)
	var targeted: bool = audience == "players" and id in selected_ids
	var in_audience: bool = audience in ["group", "players"] or participant.get("group") == audience
	if not decision.is_empty():
		in_audience = id in decision.get("playerIds", [])
		targeted = in_audience and str(decision.get("audience", "")) == "players"
	var cond: Variant = player.get("condition")
	var teinte := couleur_reaction(reaction) if not reaction.is_empty() else (Charte.couleur_attribut(float(cond)) if cond is int or cond is float else S.MUTED)
	var fond := Charte.PANNEAU_2.lerp(teinte, .16 if not reaction.is_empty() else 0.0)
	_skin_tile(jeton, fond, fond.lerp(Charte.CREME, .07))
	if not player.is_empty():
		MiniFiche.lier(app, jeton, str(id), "squad")
		jeton.mouse_entered.connect(_mini_fiche_devant)
	if not in_audience: jeton.modulate = Color(1, 1, 1, .45)
	var largeur := px(92) if compact else px(104)
	jeton.custom_minimum_size = Vector2(largeur, px(96) if compact else px(104))
	S.G.fill(jeton)
	var pile := S.G.v(px(2))
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	S.full(pile)
	jeton.add_child(pile)
	var visage := px(38) if compact else px(44)
	var anneau := Panel.new()
	anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anneau.custom_minimum_size = Vector2.ONE * (visage + px(6))
	anneau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	anneau.add_theme_stylebox_override("panel", Charte.style_pilule(teinte, Color.TRANSPARENT, 0, 0))
	pile.add_child(anneau)
	var portrait := _portrait(player, visage, true)
	anneau.add_child(portrait)
	portrait.position = Vector2.ONE * px(3)
	portrait.size = Vector2.ONE * visage
	var tete := S.G.h(px(4))
	tete.alignment = BoxContainer.ALIGNMENT_CENTER
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(tete)
	tete.add_child(_text(str(number), px(14), S.TEXT, Charte.TITRE_FICHE))
	var full_name := str(player.get("name", ""))
	var nom := _text(Nom.surname(full_name).to_upper(), px(12), S.TEXT, Charte.TITRE_GRAS)
	nom.clip_text = true
	nom.custom_minimum_size.x = largeur - px(30)
	tete.add_child(nom)
	var bas := S.G.h(px(4))
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_child(bas)
	if not reaction.is_empty(): bas.add_child(_pastille_reaction(reaction, px(9)))
	else: bas.add_child(_pastille_note(id))
	if targeted:
		var b := _badge_vise(px(16))
		jeton.add_child(b)
		b.position = Vector2(px(4), px(4))
	jeton.tooltip_text = "%d · %s" % [number, full_name] + (" · " + str(reaction.label) if reaction.has("label") else "")
	return jeton
