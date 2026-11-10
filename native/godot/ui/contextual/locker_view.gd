extends Control
const S = preload("res://ui/contextual/skin.gd")
const STARTER_POSITIONS = ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "Troisième ligne aile", "Troisième ligne aile", "Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
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
	var fingerprint := JSON.stringify([data, value.get("squad", []), value.get("club", {})])
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
	var declarations := S.panel(middle, 12)
	var decision: Variant = scene.get("decision")
	if decision is Dictionary:
		declarations.add_child(S.label("Votre message a été prononcé", 19, S.GOLD))
		declarations.add_child(S.wrap(str(decision.get("text", "")), 19, S.TEXT))
		declarations.add_child(S.wrap("Les réactions de vos destinataires apparaissent sur leurs cartes.", 13))
	else:
		var recipient_row := S.G.h(6)
		declarations.add_child(recipient_row)
		for item in [["group", "GROUPE"], ["forwards", "AVANTS"], ["backs", "ARRIÈRES"], ["players", "JOUEURS"]]:
			var button := S.button(item[1], func(): _set_audience(item[0]))
			S.G.fill(button)
			if audience == item[0]: S.selected(button, S.GOLD)
			recipient_row.add_child(button)
		declarations.add_child(S.label("À qui vous adressez-vous ?" if audience != "players" else "%d joueur(s) sélectionné(s) · cliquez sur leurs cartes" % selected_ids.size(), 12))
		options_grid = GridContainer.new()
		options_grid.name = "TalkDeclarations"
		options_grid.columns = 3
		options_grid.add_theme_constant_override("h_separation", 7)
		options_grid.add_theme_constant_override("v_separation", 7)
		declarations.add_child(options_grid)
		for option: Dictionary in scene.get("options", []):
			var button := S.button(str(option.get("text", "")), func(): _select_choice(option))
			button.set_meta("choice_id", option.get("id", ""))
			button.custom_minimum_size = Vector2(0, 62)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size", 14)
			S.G.fill(button)
			if selected_choice == str(option.get("id", "")): S.selected(button, S.GOLD)
			options_grid.add_child(button)
		var selected: Dictionary = {}
		for option: Dictionary in scene.get("options", []):
			if str(option.get("id", "")) == selected_choice: selected = option
		if not selected.is_empty(): declarations.add_child(S.wrap("Aperçu · « %s »" % str(selected.get("text", "")), 13, S.GOLD))
	_roster(body, "ARRIÈRES", "backs")
	var bench := S.G.h(8)
	bench.name = "TalkBench"
	column.add_child(S.label("REMPLAÇANTS", 11, S.GOLD))
	column.add_child(bench)
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) > 15: bench.add_child(_player_card(participant, true))
	var footer := S.G.h(12)
	column.add_child(footer)
	footer.add_child(S.label("AVANT-MATCH  /  MATCH  /  MI-TEMPS  /  DÉBRIEF", 12, S.GOLD))
	footer.add_child(S.G.spacer())
	if decision is Dictionary:
		footer.add_child(S.button("CONTINUER  →", _continue, true, true))
	else:
		footer.add_child(S.button("SANS PRENDRE LA PAROLE", func(): _continue(true)))
		var enabled: bool = not selected_choice.is_empty() and (audience != "players" or not selected_ids.is_empty()) and scene.get("options", []).size() == 6
		var pronounce := S.button("PRONONCER", _pronounce, enabled, true)
		pronounce.name = "TalkPronounce"
		footer.add_child(pronounce)
	director._refresh_controls()

func _roster(parent: Node, title: String, group: String) -> void:
	var list := S.G.v(5)
	list.custom_minimum_size.x = 205
	parent.add_child(list)
	list.add_child(S.label(title, 11, S.GOLD))
	for participant: Dictionary in scene.get("participants", []):
		if int(participant.get("number", 0)) <= 15 and participant.get("group") == group:
			list.add_child(_player_card(participant))

func _player_card(participant: Dictionary, compact: bool = false) -> Button:
	var id: Variant = participant.get("id")
	var player := S.person(model, id)
	var text := str(player.get("name", "Identité indisponible"))
	var position_text := _position_label(participant, player)
	var decision: Dictionary = scene.get("decision", {}) if scene.get("decision") is Dictionary else {}
	var reaction := S.reactions(decision, id)
	var reaction_label: String = {"encouraged":"Encouragé", "unconvinced":"Peu convaincu", "unchanged":"Sans réaction visible"}.get(reaction, reaction)
	var card := S.button("", func(): _toggle_player(id), decision.is_empty())
	card.set_meta("participant_id", id)
	card.tooltip_text = text + " · " + position_text + (" · " + reaction_label if not reaction_label.is_empty() else "")
	card.custom_minimum_size.y = 54
	if compact: S.G.fill(card)
	var margin := S.G.margin(3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(margin)
	card.add_child(margin)
	var row := S.G.h(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var portrait: TextureRect
	if player.is_empty():
		portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2.ONE * 40
		portrait.tooltip_text = "Identité indisponible · aucun portrait attribué"
	else: portrait = S.G.portrait(int(player.get("portraitIndex", 0)), 40, player)
	portrait.name = "ParticipantPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var words := S.G.v(1)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(words)
	row.add_child(words)
	var name_label := S.label("%s · %s" % [str(int(participant.get("number", 0))), text], 11 if compact else 12)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_label)
	var position_label := S.label(position_text, 10, S.MUTED)
	position_label.name = "ParticipantPosition"
	position_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	position_label.tooltip_text = position_label.text
	position_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(position_label)
	if not reaction_label.is_empty(): words.add_child(S.label(reaction_label, 10, S.GOLD))
	elif audience == "players" and id in selected_ids: words.add_child(S.label("✓ Destinataire", 10, S.GOLD))
	var addressed: bool = audience == "group" or (audience in ["forwards", "backs"] and participant.get("group") == audience) or (audience == "players" and id in selected_ids)
	if not decision.is_empty(): addressed = id in decision.get("playerIds", [])
	if addressed: S.selected(card, S.GOLD)
	return card

func _position_label(participant: Dictionary, player: Dictionary) -> String:
	var number := int(participant.get("number", 0))
	if number >= 1 and number <= 15:
		# A starter's match role follows the jersey, even when his primary
		# individual position differs. Reuse the engine's slot label when given.
		for slot: Dictionary in model.get("selection", {}).get("slots", []):
			if int(slot.get("slot", -1)) != number - 1: continue
			var label := str(slot.get("label", "")).strip_edges()
			if not label.is_empty():
				return "Troisième ligne aile" if number in [6, 7] and label == "Troisième ligne" else label
		return STARTER_POSITIONS[number - 1]
	# Bench numbers are not position assignments. pos is the projected primary
	# position (rosterProfile.position.primary in common careers), not a guess
	# from a bench slot or a newly calculated attribute rating.
	var primary: Variant = player.get("pos")
	if not primary is String or primary.strip_edges().is_empty():
		var profile: Dictionary = player.get("rosterProfile", {}) if player.get("rosterProfile") is Dictionary else {}
		primary = profile.get("position", {}).get("primary", "")
	return primary.strip_edges() if primary is String and not primary.strip_edges().is_empty() else "Poste non renseigné"

func _select_choice(option: Dictionary) -> void:
	if app.waiting: return
	selected_choice = str(option.get("id", ""))
	_draw()

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
