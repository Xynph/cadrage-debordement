extends AcceptDialog
## Frozen local facts; browsing never issues a worker command or rewinds play.
const G = preload("res://ui/carnet_skin.gd")
const Journal = preload("res://ui/match_journal.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const KEY_KINDS = ["try", "goal", "miss", "penalty", "advantage", "card", "turnover", "hand-fault", "setpiece-loss", "tactic", "break", "end"]
var events: Array = []
var teams: Array = []
var selection: Array[int] = []
var index := 0
var initial_index := -1
var phases: Array[Dictionary] = []
var phase_choice: OptionButton
var kind_choice: OptionButton
var timeline: OptionButton
var phase_summary: Label
var content_scroll: ScrollContainer
var show_pitch: Button
var show_summary: Button
const FILTERS = [[], ["tactic"], ["scrum","lineout","setpiece-win","setpiece-loss"], ["try","goal","miss"], ["penalty","advantage","card","hand-fault"], ["carry","turnover","kick","reception"]]
var keys_only: CheckButton
var previous: Button
var next: Button
var heading: Label
var facts: Label
var action: Label
var coordinates: Label
var pitch: Control

class ActionPitch extends Control:
	var from: Variant
	var to: Variant
	static func valid(point: Variant) -> bool:
		if not point is Dictionary: return false
		for key in ["x", "y"]:
			if not (point.get(key) is int or point.get(key) is float): return false
			if not is_finite(float(point[key])): return false
		return float(point.x) >= 0 and float(point.x) <= 100 and float(point.y) >= 0 and float(point.y) <= 70
	func _draw() -> void:
		var rect := Rect2(Vector2(10,10),size-Vector2(20,20))
		draw_rect(rect,Color("284e3d"))
		draw_rect(rect,Color("d4e5ce"),false,2)
		for x in [22,50,78]:
			var position := rect.position.x + rect.size.x * float(x)/100.0
			draw_line(Vector2(position,rect.position.y),Vector2(position,rect.end.y),Color("97b99b"),1)
		if valid(from) and valid(to):
			var a := rect.position+rect.size*Vector2(float(from.x)/100.0,float(from.y)/70.0)
			var b := rect.position+rect.size*Vector2(float(to.x)/100.0,float(to.y)/70.0)
			draw_circle(a,5,Color("f7f0d0"))
			draw_line(a,b,Color("edbc61"),3,true)
			draw_circle(b,7,Color("edbc61"))
			if a.distance_to(b)>15:
				var direction := (b-a).normalized()
				draw_line(b,b-direction.rotated(.5)*13,Color("edbc61"),3,true)
				draw_line(b,b-direction.rotated(-.5)*13,Color("edbc61"),3,true)

static func open(journal: Control, source: Array, source_teams: Array, start_index: int = -1) -> AcceptDialog:
	if source.is_empty(): return null
	var dialog: AcceptDialog = load("res://match_action_review.gd").new()
	dialog.initial_index = start_index
	dialog.events = source.duplicate(true)
	dialog.teams = source_teams.duplicate(true)
	dialog._build(journal)
	return dialog

func _build(journal: Control) -> void:
	name = "MatchActionReview"
	title = "Relire les actions"
	# A read-only auxiliary window must not block a real transport-error dialog.
	exclusive = false
	get_ok_button().text = "FERMER LA RELECTURE"
	Dialogs.prepare(self,680,journal.app.accent)
	journal.add_child(self)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var scroll := ScrollContainer.new()
	content_scroll = scroll
	scroll.name = "ActionReviewScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620,420)
	add_child(scroll)
	var body := G.v(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(G.wrap("Instantané des faits filtrés à l’ouverture. Le match reste à son état courant.",15,G.MUTED))
	keys_only = CheckButton.new()
	keys_only.name = "ActionReviewKeys"
	keys_only.text = "MOMENTS CLÉS UNIQUEMENT"
	body.add_child(keys_only)
	keys_only.toggled.connect(func(_on: bool): _select(true))
	_make_phases()
	var filters := G.h(8)
	body.add_child(filters)
	phase_choice = OptionButton.new()
	phase_choice.name = "ActionReviewPhases"
	phase_choice.fit_to_longest_item = false
	phase_choice.add_item("Toutes les séquences retenues")
	for i in phases.size():
		var phase: Dictionary = phases[i]
		phase_choice.add_item("Séquence %d · %s → %s min · %s" % [i+1, _time(phase.startMinute), _time(phase.endMinute), "Période "+str(phase.period) if phase.period!=null else "Période inconnue"])
	phase_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_choice.clip_text = true
	filters.add_child(phase_choice)
	phase_choice.item_selected.connect(func(_i: int): _select(true))
	kind_choice = OptionButton.new()
	kind_choice.name = "ActionReviewKinds"
	for label in ["Tous les faits", "Consignes", "Conquête", "Scores et tentatives", "Discipline", "Progression et ballon"]: kind_choice.add_item(label)
	kind_choice.fit_to_longest_item = false
	kind_choice.clip_text = true
	kind_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(kind_choice)
	kind_choice.item_selected.connect(func(_i: int): _select(true))
	timeline = OptionButton.new()
	timeline.name = "ActionReviewTimeline"
	timeline.fit_to_longest_item = false
	body.add_child(timeline)
	timeline.item_selected.connect(func(i: int): index=i; _show_event())
	var controls := G.h(8)
	body.add_child(controls)
	previous = G.button("← PRÉCÉDENT",func(): index-=1; _show_event())
	previous.name = "ActionReviewPrevious"
	controls.add_child(previous)
	next = G.button("SUIVANT →",func(): index+=1; _show_event())
	next.name = "ActionReviewNext"
	controls.add_child(next)
	show_pitch = G.button("VOIR LE TERRAIN",func(): content_scroll.ensure_control_visible(pitch))
	show_pitch.name = "ActionReviewShowPitch"
	controls.add_child(show_pitch)
	heading = G.wrap("",20,G.INK)
	heading.name = "ActionReviewHeading"
	body.add_child(heading)
	facts = G.wrap("",14,G.MUTED)
	body.add_child(facts)
	action = G.wrap("",17,G.INK)
	action.name = "ActionReviewText"
	body.add_child(action)
	pitch = ActionPitch.new()
	pitch.name = "ActionReviewPitch"
	pitch.custom_minimum_size = Vector2(400,180)
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pitch)
	show_summary = G.button("BILAN DE LA SÉQUENCE",_toggle_summary)
	show_summary.name = "ActionReviewShowSummary"
	body.add_child(show_summary)
	phase_summary = G.wrap("",14,G.MUTED)
	phase_summary.visible = false
	phase_summary.name = "ActionReviewSummary"
	body.add_child(phase_summary)
	coordinates = G.wrap("",14,G.MUTED)
	body.add_child(coordinates)
	body.add_child(G.button("REVENIR À LA CHRONOLOGIE",func(): content_scroll.ensure_control_visible(timeline)))
	_select()
	index = clampi(initial_index,0,maxi(0,selection.size()-1)) if initial_index>=0 else maxi(0,selection.size()-1)
	_show_event()
	Dialogs.show_centered(self,Vector2i(680,560))

func _select(preserve: bool = false) -> void:
	var current: int = selection[index] if preserve and index>=0 and index<selection.size() else -1
	selection.clear()
	for i in events.size():
		var event: Variant = events[i]
		var scene: Dictionary = event.get("scene",{}) if event is Dictionary and event.get("scene") is Dictionary else {}
		var kind := str(scene.get("kind",""))
		if keys_only.button_pressed and kind not in KEY_KINDS: continue
		if kind_choice.selected>0 and kind not in FILTERS[kind_choice.selected]: continue
		if phase_choice.selected>0:
			var phase: Dictionary = phases[phase_choice.selected-1]
			if i<int(phase.start) or i>int(phase.end): continue
		selection.append(i)
	timeline.clear()
	for selected in selection:
		var event: Variant = events[selected]
		var scene: Dictionary = _scene(event)
		var caption: String = Journal.KINDS.get(str(scene.get("kind","")),"Fait non typé")
		timeline.add_item("#%d · %s min · %s" % [selected+1,_time(event.get("min") if event is Dictionary else null),caption])
	index = selection.find(current) if current>=0 else 0
	if index<0: index=0
	_show_event()

func _show_event() -> void:
	index=clampi(index,0,maxi(0,selection.size()-1))
	previous.disabled = selection.is_empty() or index==0
	next.disabled = selection.is_empty() or index>=selection.size()-1
	pitch.from = null
	pitch.to = null
	pitch.queue_redraw()
	if selection.is_empty():
		heading.text = "Aucun moment clé dans cet instantané." if keys_only.button_pressed else "Aucun fait pour ces filtres."
		phase_summary.text = ""
		timeline.disabled = true
		show_pitch.disabled = true
		show_summary.disabled = true
		facts.text = ""
		action.text = "Désactivez le filtre pour retrouver tous les faits du journal."
		coordinates.text = "Position non renseignée."
		return
	timeline.disabled = false
	show_pitch.disabled = false
	show_summary.disabled = false
	timeline.select(index)
	_show_phase(selection[index])
	var value: Variant = events[selection[index]]
	var event: Dictionary = value if value is Dictionary else {}
	var scene: Dictionary = event.get("scene",{}) if event.get("scene") is Dictionary else {}
	var kind := str(scene.get("kind",""))
	var minute := "Minute non renseignée"
	if event.get("min") is int or event.get("min") is float: minute = Journal._number(event.min)+" min"
	heading.text = "%d / %d · %s · %s" % [index+1,selection.size(),minute,Journal.KINDS.get(kind,"Type non renseigné" if kind.is_empty() else "Type inconnu (« %s »)" % kind)]
	var details: Array[String] = []
	var side: Variant = scene.get("team")
	if (side is int or side is float) and float(side) in [0.0,1.0] and int(side)<teams.size(): details.append(G.club_name(teams[int(side)]))
	else: details.append("Équipe non renseignée")
	if scene.has("period"): details.append("Période "+Journal._number(scene.period))
	if scene.get("score") is Array and scene.score.size()==2: details.append("Score %s — %s" % [Journal._number(scene.score[0]),Journal._number(scene.score[1])])
	if scene.get("style") is String: details.append("Consigne enregistrée : "+_plan_label(scene.style,false))
	facts.text = " · ".join(details)
	action.text = str(event.get("text","Texte non renseigné")) if value is Dictionary else str(value)
	if ActionPitch.valid(scene.get("from")) and ActionPitch.valid(scene.get("to")):
		pitch.from=scene.from
		pitch.to=scene.to
		coordinates.text = "Ballon : (%s ; %s) → (%s ; %s) m. Origine claire, arrivée dorée. Schéma enregistré, sans trajectoire animée ni direction d’attaque déduite." % [Journal._number(scene.from.x),Journal._number(scene.from.y),Journal._number(scene.to.x),Journal._number(scene.to.y)]
	else: coordinates.text = "Position non renseignée."
	pitch.queue_redraw()

static func _scene(value: Variant) -> Dictionary:
	return value.scene if value is Dictionary and value.get("scene") is Dictionary else {}

static func _time(value: Variant) -> String:
	return Journal._number(value) if (value is float or value is int) and is_finite(float(value)) else "?"

static func _plans(scene: Dictionary) -> Variant:
	var plans: Variant = scene.get("plans")
	if not plans is Dictionary: return null
	for key in ["attack","defence"]:
		if not plans.get(key) is Array or plans[key].size()!=2: return null
		for value in plans[key]:
			if not value is String or value.is_empty(): return null
	return {"attack":plans.attack.duplicate(),"defence":plans.defence.duplicate()}

static func _score(scene: Dictionary) -> Variant:
	var score: Variant = scene.get("score")
	if not score is Array or score.size()!=2: return null
	for value in score:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0: return null
	return score.duplicate()

func _make_phases() -> void:
	phases.clear()
	for i in events.size():
		var event: Variant = events[i]
		var scene := _scene(event)
		var period: Variant = scene.get("period") if scene.get("period") in [1,2] else null
		var plans: Variant = _plans(scene)
		var key := JSON.stringify([period,plans])
		var minute: Variant = event.get("min") if event is Dictionary else null
		if phases.is_empty() or phases[-1].key!=key:
			phases.append({"key":key,"start":i,"end":i,"period":period,"plans":plans,"startMinute":minute,"endMinute":minute,"firstScore":null,"lastScore":null,"counts":{}})
		var phase: Dictionary = phases[-1]
		phase.end=i
		phase.endMinute=minute
		var score: Variant = _score(scene)
		if score!=null:
			if phase.firstScore==null: phase.firstScore=score
			phase.lastScore=score
		var kind := str(scene.get("kind",""))
		if Journal.KINDS.has(kind): phase.counts[kind]=int(phase.counts.get(kind,0))+1

func _show_phase(selected: int) -> void:
	var phase: Dictionary = {}
	for row in phases:
		if selected>=int(row.start) and selected<=int(row.end): phase=row; break
	if phase.is_empty(): phase_summary.text="Séquence non renseignée."; return
	var lines: Array[String] = []
	if phase.plans==null: lines.append("Plans non renseignés pour cette séquence.")
	else:
		for side in 2:
			var team: String = G.club_name(teams[side]) if side<teams.size() else "Équipe "+str(side+1)
			lines.append("%s · attaque : %s · défense : %s" % [team,_plan_label(phase.plans.attack[side],false),_plan_label(phase.plans.defence[side],true)])
	if phase.firstScore==null: lines.append("Score non renseigné.")
	else: lines.append("Score au premier fait documenté : %s — %s ; au dernier : %s — %s." % [Journal._number(phase.firstScore[0]),Journal._number(phase.firstScore[1]),Journal._number(phase.lastScore[0]),Journal._number(phase.lastScore[1])])
	var counts: Array[String] = []
	for kind in ["try","goal","miss","penalty","turnover","setpiece-win","setpiece-loss"]:
		if phase.counts.has(kind): counts.append(str(Journal.KINDS[kind])+" : "+str(phase.counts[kind]))
	if not counts.is_empty(): lines.append("Faits retenus · "+" · ".join(counts))
	lines.append("Ce bilan des faits retenus ne prouve pas l’effet d’une consigne. Aucune durée d’animation n’est déduite des minutes.")
	phase_summary.text="\n".join(lines)

static func _plan_label(value: String, defence: bool) -> String:
	var labels := {"equilibre":"Équilibrée","pression":"Montée agressive","prudente":"Glissée prudente"} if defence else {"equilibre":"Équilibrée","conquete":"Conquête","large":"Jeu au large","occupation":"Occupation"}
	return str(labels.get(value,value+" (libellé non renseigné)"))

func _toggle_summary() -> void:
	phase_summary.visible=not phase_summary.visible
	if phase_summary.visible: _reveal_summary.call_deferred()

func _reveal_summary() -> void:
	# Its height is unknown while the label is hidden. Wait for the container.
	if not is_inside_tree(): return
	for frame in 2:
		await get_tree().process_frame
		if not is_inside_tree(): return
	if phase_summary.visible: content_scroll.ensure_control_visible(phase_summary)
