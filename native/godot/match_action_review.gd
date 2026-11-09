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

static func open(journal: Control, source: Array, source_teams: Array) -> AcceptDialog:
	if source.is_empty(): return null
	var dialog: AcceptDialog = load("res://match_action_review.gd").new()
	dialog.events = source.duplicate(true)
	dialog.teams = source_teams.duplicate(true)
	dialog._build(journal)
	return dialog

func _build(journal: Control) -> void:
	name = "MatchActionReview"
	title = "Relire les actions"
	get_ok_button().text = "FERMER LA RELECTURE"
	Dialogs.prepare(self,680,journal.app.accent)
	journal.add_child(self)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var scroll := ScrollContainer.new()
	scroll.name = "ActionReviewScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(620,420)
	add_child(scroll)
	var body := G.v(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(G.wrap("Instantané du journal à l’ouverture. Le match reste à son état courant.",15,G.MUTED))
	keys_only = CheckButton.new()
	keys_only.name = "ActionReviewKeys"
	keys_only.text = "MOMENTS CLÉS UNIQUEMENT"
	body.add_child(keys_only)
	keys_only.toggled.connect(func(_on: bool): _select(true))
	var controls := G.h(8)
	body.add_child(controls)
	previous = G.button("← PRÉCÉDENT",func(): index-=1; _show_event())
	previous.name = "ActionReviewPrevious"
	controls.add_child(previous)
	next = G.button("SUIVANT →",func(): index+=1; _show_event())
	next.name = "ActionReviewNext"
	controls.add_child(next)
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
	coordinates = G.wrap("",14,G.MUTED)
	body.add_child(coordinates)
	_select()
	index = maxi(0,selection.size()-1)
	_show_event()
	Dialogs.show_centered(self,Vector2i(680,560))

func _select(preserve: bool = false) -> void:
	var current: int = selection[index] if preserve and index>=0 and index<selection.size() else -1
	selection.clear()
	for i in events.size():
		var event: Variant = events[i]
		var scene: Dictionary = event.get("scene",{}) if event is Dictionary and event.get("scene") is Dictionary else {}
		if not keys_only.button_pressed or str(scene.get("kind","")) in KEY_KINDS: selection.append(i)
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
		heading.text = "Aucun moment clé dans cet instantané."
		facts.text = ""
		action.text = "Désactivez le filtre pour retrouver tous les faits du journal."
		coordinates.text = "Position non renseignée."
		return
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
	if scene.get("style") is String: details.append("Consigne enregistrée : "+scene.style)
	facts.text = " · ".join(details)
	action.text = str(event.get("text","Texte non renseigné")) if value is Dictionary else str(value)
	if ActionPitch.valid(scene.get("from")) and ActionPitch.valid(scene.get("to")):
		pitch.from=scene.from
		pitch.to=scene.to
		coordinates.text = "Ballon : (%s ; %s) → (%s ; %s) m. Origine claire, arrivée dorée. Schéma enregistré, sans trajectoire animée ni direction d’attaque déduite." % [Journal._number(scene.from.x),Journal._number(scene.from.y),Journal._number(scene.to.x),Journal._number(scene.to.y)]
	else: coordinates.text = "Position non renseignée."
	pitch.queue_redraw()
