extends Control
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
## Six tons de causerie (match-pilotage.js, TONS_LABELS) : libellé de repli quand le moteur n'en donne pas.
const TONS := {"calm": "Calme", "demanding": "Exigeant", "warm": "Encourageant", "furious": "Furieux", "protective": "Rassurant", "assertive": "Affirmé"}
const STARTER_POSITIONS = ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne aile", "Troisième ligne aile", "Troisième ligne centre", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
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

func _ready() -> void:
	name = "ContextualLocker"
	app = director.app
	S.room(self, "locker", app.model.get("club", {}))

func update_frame(value: Dictionary, data: Dictionary) -> void:
	model = value
	scene = data
	var fingerprint := JSON.stringify([data, value.get("squad", []), value.get("club", {}), value.get("live", {}).get("meteo") if value.get("live") is Dictionary else null])
	if fingerprint == _fingerprint: return
	_fingerprint = fingerprint
	_draw()

func _draw() -> void:
	if is_instance_valid(ui): remove_child(ui); ui.queue_free()
	ui = Control.new()
	S.full(ui)
	add_child(ui)
	var column := S.frame(ui, 18)
	var phase := str(scene.get("phase", "pre"))
	var title: String = {"pre":"Avant le match", "half":"Mi-temps", "post":"Après le match"}.get(phase, "Le vestiaire")
	var context: Dictionary = scene.get("context", {})
	var subtitle := S.G.club_name(model.get("club", {}))
	var live: Dictionary = model.get("live", {}) if model.get("live") is Dictionary else {}
	var teams: Array = live.get("teams", [])
	if teams.size() == 2: subtitle = "%s  —  %s" % [S.G.club_name(teams[0]), S.G.club_name(teams[1])]
	var scores: Array = context.get("score", [])
	if phase != "pre" and scores.size() == 2: subtitle += "   ·   %s — %s" % [str(scores[0]), str(scores[1])]
	S.heading(column, model.get("club", {}), title, subtitle)
	var body := S.G.h(14)
	S.G.fill(body, true)
	column.add_child(body)
	_roster(body, "AVANTS", "forwards")
	var middle := S.G.v(8)
	S.G.fill(middle, true)
	body.add_child(middle)
	var air := Control.new()
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(air, true)
	middle.add_child(air)
	if phase in ["pre", "half"] and not live.is_empty(): _meteo(middle, live, phase)
	var declarations := S.panel(middle, 14)
	var decision: Variant = scene.get("decision")
	if decision is Dictionary:
		_bilan_causerie(declarations, decision)
		# Le bouton de sortie, grand et en or : c'est la seule action qui reste.
		var go_on := S.button("CONTINUER   →", _continue, true, true)
		go_on.name = "TalkContinue"
		go_on.custom_minimum_size.y = 74
		go_on.add_theme_font_size_override("font_size", 26)
		go_on.tooltip_text = "Reprendre le match (Entrée ou Espace)"
		for state in ["normal", "hover", "pressed"]:
			var style := Charte.style_pilule(Charte.OR_VIF if state == "hover" else Charte.DORE, Color.TRANSPARENT, 24, 8)
			go_on.add_theme_stylebox_override(state, style)
		declarations.add_child(go_on)
		call_deferred("_focus_continue", go_on)
	else:
		var recipient_row := S.G.h(8)
		declarations.add_child(recipient_row)
		for item in [["group", "GROUPE"], ["forwards", "AVANTS"], ["backs", "ARRIÈRES"], ["players", "JOUEURS"]]:
			var button := S.button(item[1], func(): _set_audience(item[0]))
			button.custom_minimum_size.y = 46
			button.add_theme_font_size_override("font_size", 16)
			S.G.fill(button)
			if audience == item[0]: S.selected(button, S.GOLD)
			recipient_row.add_child(button)
		var waiting_players: bool = audience == "players" and selected_ids.is_empty()
		var prompt := "À qui t’adresses-tu ? Puis clique sur ta phrase."
		if audience == "players": prompt = "Clique d’abord sur les cartes des joueurs visés." if waiting_players else "%d joueur(s) visé(s) · clique sur ta phrase." % selected_ids.size()
		var prompt_label := S.label(prompt, 17, S.GOLD if waiting_players else S.TEXT)
		prompt_label.name = "TalkPrompt"
		declarations.add_child(prompt_label)
		options_grid = GridContainer.new()
		options_grid.name = "TalkDeclarations"
		options_grid.columns = 2
		options_grid.add_theme_constant_override("h_separation", 10)
		options_grid.add_theme_constant_override("v_separation", 10)
		declarations.add_child(options_grid)
		var ready_to_speak: bool = not waiting_players and scene.get("options", []).size() == 6
		for option: Dictionary in scene.get("options", []): options_grid.add_child(_choice_card(option, ready_to_speak))
		var skip_row := S.G.h(8)
		declarations.add_child(skip_row)
		skip_row.add_child(_hspace())
		var skip := S.button("SANS PRENDRE LA PAROLE", func(): _continue(true))
		skip.name = "TalkSkip"
		skip.custom_minimum_size = Vector2(260, 44)
		skip.add_theme_font_size_override("font_size", 15)
		skip_row.add_child(skip)
	_roster(body, "ARRIÈRES", "backs")
	var bench_head := S.G.h(12)
	column.add_child(bench_head)
	bench_head.add_child(S.label("REMPLAÇANTS", 14, S.GOLD))
	bench_head.add_child(_hspace())
	bench_head.add_child(S.label("AVANT-MATCH  /  MATCH  /  MI-TEMPS  /  DÉBRIEF", 13, S.MUTED))
	var bench := S.G.h(8)
	bench.name = "TalkBench"
	column.add_child(bench)
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) > 15: bench.add_child(_player_card(participant, true))
	director._refresh_controls()

## Focus clavier sur Continuer (Entrée/Espace), si le bouton est toujours affiché.
func _focus_continue(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

## Espace qui pousse le reste de la ligne à droite (le spacer du carnet est vertical).
static func _hspace() -> Control:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return space

func _roster(parent: Node, title: String, group: String) -> void:
	var list := S.G.v(6)
	list.custom_minimum_size.x = 290
	parent.add_child(list)
	list.add_child(S.label(title, 14, S.GOLD))
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) <= 15 and participant.get("group") == group:
			list.add_child(_player_card(participant))

func _player_card(participant: Dictionary, compact: bool = false) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var text := str(player.get("name", "Identité indisponible"))
	var position_text := _position_label(participant, player)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := reaction_of(decision, id)
	var reaction_label := str(reaction.get("label", ""))
	var card := S.button("", func(): _toggle_player(id), decision.is_empty())
	card.set_meta("participant_id", id)
	card.tooltip_text = text + " · " + position_text + (" · " + reaction_label if not reaction_label.is_empty() else "")
	# Tuiles lisibles : 74 px (titulaires) / 70 px (banc), portrait 58 / 50, textes 17-14 / 15-13.
	card.custom_minimum_size.y = 70 if compact else 74
	if compact: S.G.fill(card)
	var margin := S.G.margin(4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(margin)
	card.add_child(margin)
	var row := S.G.h(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var portrait_size := 50 if compact else 58
	var portrait: TextureRect
	if player.is_empty():
		portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2.ONE * portrait_size
		portrait.tooltip_text = "Identité indisponible · aucun portrait attribué"
	else: portrait = S.G.portrait(int(player.get("portraitIndex", 0)), portrait_size, player)
	portrait.name = "ParticipantPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var words := S.G.v(1)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(words)
	row.add_child(words)
	var name_label := S.label("%s · %s" % [str(int(participant.get("number", 0))), text], 15 if compact else 17)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var position_label := S.label(position_text, 13 if compact else 14, S.MUTED)
	position_label.name = "ParticipantPosition"
	position_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	position_label.tooltip_text = position_label.text
	position_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(position_label)
	if not reaction_label.is_empty():
		var reaction_text := S.label(reaction_label, 13 if compact else 14, reaction_color(reaction))
		reaction_text.name = "ParticipantReaction"
		reaction_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(reaction_text)
	elif audience == "players" and id in selected_ids: words.add_child(S.label("✓ Visé", 13 if compact else 14, S.GOLD))
	var addressed: bool = audience == "group" or (audience in ["forwards", "backs"] and participant.get("group") == audience) or (audience == "players" and id in selected_ids)
	if not decision.is_empty(): addressed = id in decision.get("playerIds", [])
	if addressed: S.selected(card, S.GOLD)
	return card

## Carte d'une déclaration : le ton d'abord (libellé en or), la phrase dessous.
## Un clic prononce la phrase aussitôt (aucune confirmation).
func _choice_card(option: Dictionary, enabled: bool = true) -> Button:
	var card := S.button("", func(): _select_choice(option), enabled)
	card.name = "TalkChoice_" + str(option.get("tone", ""))
	card.set_meta("choice_id", option.get("id", ""))
	card.set_meta("tone", option.get("tone", ""))
	card.tooltip_text = "%s · « %s »" % [tone_label(option), str(option.get("text", ""))]
	card.custom_minimum_size = Vector2(0, 94)
	S.G.fill(card)
	if selected_choice == str(option.get("id", "")): S.selected(card, S.GOLD)
	var margin := S.G.margin(10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(margin)
	card.add_child(margin)
	var words := S.G.v(3)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(words)
	var tone := S.label(tone_label(option).to_upper(), 18, S.GOLD)
	tone.name = "TalkChoiceTone"
	tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(tone)
	var sentence := S.wrap(str(option.get("text", "")), 16, S.TEXT)
	sentence.name = "TalkChoiceText"
	sentence.max_lines_visible = 2
	sentence.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sentence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(sentence)
	words.add_child(sentence)
	return card

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
	var title := S.label(("Le staff a parlé · " if by_staff else "Ton message · ") + tone_label(decision), 22, S.GOLD)
	title.name = "TalkDecisionTone"
	parent.add_child(title)
	parent.add_child(S.wrap("« %s »" % str(decision.get("text", "")), 20, S.TEXT))
	var morale: int = int(decision.get("moraleDelta", 0)) if decision.get("moraleDelta") is int or decision.get("moraleDelta") is float else 0
	if str(decision.get("audience", "")) != "players":
		var morale_text := "Moral du groupe inchangé" if morale == 0 else "Moral du groupe %s%d" % ["+" if morale > 0 else "−", absi(morale)]
		var morale_label := S.label(morale_text, 17, Pilotage.teinte(signi(morale), S.MUTED))
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
			summary.add_child(S.label("%d %s" % [int(counts[label]), label.to_lower()], 16, colors[label]))
	parent.add_child(S.wrap("Chaque réaction visible apparaît sur la carte du joueur.", 14))

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
	var cadre := S.panel(parent, 10)
	cadre.name = "TalkWeather"
	cadre.add_child(S.label("LA MÉTÉO  ·  " + titre.to_upper(), 13, S.GOLD))
	var vent := Meteo.phrase_vent(live, phase)
	if not vent.is_empty(): cadre.add_child(S.wrap(vent, 16, S.TEXT))
	var conseil := Meteo.conseil(live)
	if not conseil.is_empty(): cadre.add_child(S.wrap(conseil, 13))
