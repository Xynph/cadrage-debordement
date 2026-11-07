extends VBoxContainer
const G = preload("res://ui/game_skin.gd")
var app: Control
var stage: Node3D
var clock: Label
var score: Label
var home: Label
var away: Label
var play: Button
var finish: Button
var events: Label
var stats: Label
var side: VBoxContainer
var tab := "Direct"
var selected_out := ""
var presence_key := ""
var model: Dictionary = {}

func _ready() -> void:
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",10)
	var banner:=G.h(16)
	add_child(banner)
	clock=G.label("AVANT-MATCH",24,G.GOLD,true)
	clock.custom_minimum_size.x=120
	banner.add_child(clock)
	home=G.label("",23,G.INK,true)
	home.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	G.fill(home)
	banner.add_child(home)
	score=G.label("— / —",42,G.INK,true)
	score.custom_minimum_size.x=130
	score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(score)
	away=G.label("",23,G.INK,true)
	G.fill(away)
	banner.add_child(away)
	play=G.button("COUP D'ENVOI",_act,true)
	banner.add_child(play)
	var center:=G.h(13)
	G.fill(center,true)
	add_child(center)
	var container:=SubViewportContainer.new()
	container.stretch=true
	container.custom_minimum_size=Vector2(560,330)
	G.fill(container,true)
	center.add_child(container)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1000,620)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X
	container.add_child(viewport)
	stage=load("res://match_view.gd").new()
	viewport.add_child(stage)
	var panel:=G.panel(center)
	panel.get_parent().get_parent().custom_minimum_size.x=240
	panel.get_parent().get_parent().size_flags_horizontal=Control.SIZE_FILL
	var tabs:=G.h(3)
	panel.add_child(tabs)
	for name in ["Direct","Banc","Stats"]:
		var b:=G.button(name.to_upper(),func():tab=name;presence_key="";_side())
		b.add_theme_font_size_override("font_size",10)
		G.fill(b)
		tabs.add_child(b)
	side=G.scroll(panel)
	var bottom:=G.h(8)
	add_child(bottom)
	bottom.add_child(G.button("CAMÉRA TV",func():stage.set_camera("tv")))
	bottom.add_child(G.button("VUE TACTIQUE",func():stage.set_camera("tactical")))
	var speed:=OptionButton.new()
	for text in ["Cadence ×1","Cadence ×4","Cadence ×12"]:speed.add_item(text)
	speed.select([1,4,12].find(app.tick_steps))
	speed.item_selected.connect(func(index:int):app.tick_steps=[1,4,12][index])
	bottom.add_child(speed)
	bottom.add_child(G.button("CONSIGNES",func():app._navigate("Préparation")))
	bottom.add_child(G.button("ADJOINT",func():app.confirm("Confier la fin du match", "L'adjoint termine la rencontre avec le moteur actuel. Confirmer la délégation ?",func():app._command("delegate"))))
	var spacer:=Control.new()
	G.fill(spacer)
	bottom.add_child(spacer)
	finish=G.button("VALIDER LA JOURNÉE  →",func():app._command("finish_round"))
	bottom.add_child(finish)
	app.match_view=stage
	app.pause_button=play
	app.match_finish=finish
	app.match_clock=clock
	add_child(G.label("Simulation de carrière · enceinte générique · caméra éloignée",10,G.MUTED))

func update_frame(value:Dictionary) -> void:
	model=value
	if not is_node_ready():return
	var live:Dictionary=value.live if value.get("live") is Dictionary else {}
	if live.is_empty():
		stage.apply_frame({})
		var next:Dictionary=value.next if value.get("next") is Dictionary else {}
		home.text=G.club_name(next.get("home",{}))
		away.text=G.club_name(next.get("away",{}))
		score.text="— / —"
		clock.text="AVANT-MATCH"
		play.text="COUP D'ENVOI"
		play.disabled=next.is_empty()
		var season_done:bool=value.meta.get("canAdvanceSeason",false) or (value.meta.get("mode")!="france30" and value.meta.get("phase")=="ended")
		finish.disabled=not next.is_empty() or season_done
		if next.is_empty():
			clock.text="SAISON TERMINÉE" if season_done else "SANS RENCONTRE"
			finish.text="AVANCER LA SEMAINE  →"
	else:
		var teams:Array=live.get("teams",[{},{}])
		home.text=G.club_abbr(teams[0])
		away.text=G.club_abbr(teams[1])
		var scores:Array=live.get("score",[0,0])
		score.text="%s — %s"%[G.n(scores[0]),G.n(scores[1])]
		clock.text="%s min"%G.n(live.get("minute",0))
		if live.get("finished",false):clock.text="TERMINÉ"
		elif live.get("halftime",false):clock.text="MI-TEMPS"
		play.text="REPRENDRE" if live.get("paused",false) else "PAUSE"
		play.disabled=live.get("finished",false)
		finish.text="VALIDER LA JOURNÉE  →"
		finish.disabled=not live.get("finished",false)
		stage.apply_frame(live)
	_side()

func _side() -> void:
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	if tab=="Banc":
		# Fatigue/clock changes do not affect these controls. Keep focus across ticks,
		# but rebuild when player identity or a replacement permission changes.
		var identities:Array=[]
		for group in [live.get("lineup",[]),live.get("reserves",[])]:
			var players:Array=[]
			for player in group:
				if player is Dictionary:players.append([player.get("id"),player.get("name")])
			identities.append(players)
		var key:=JSON.stringify([identities,selected_out,live.get("paused",false),live.get("finished",false),live.get("substitutions",[])])
		if key==presence_key:return
		presence_key=key
	for child in side.get_children():
		side.remove_child(child)
		child.queue_free()
	if live.is_empty():
		side.add_child(G.section("L'AVANT-MATCH"))
		side.add_child(G.wrap("Vérifiez votre composition à23 et vos consignes. Le coup d'envoi utilise les décisions du moteur.",14))
		side.add_child(G.button("VÉRIFIER LA FEUILLE",func():app._navigate("Composition")))
		return
	match tab:
		"Stats":
			side.add_child(G.section("LE MATCH EN CHIFFRES"))
			for stat in live.get("statsRows",[]):
				side.add_child(G.label(stat.label,12,G.MUTED))
				var row:=G.h()
				row.add_child(G.label(G.n(stat.home),25,G.GOLD,true))
				row.add_child(G.label("/",20,G.MUTED,true))
				row.add_child(G.label(G.n(stat.away),25,G.INK,true))
				side.add_child(row)
				side.add_child(G.separator())
		"Banc":_bench(live)
		_:
			side.add_child(G.section("AU BORD DU TERRAIN"))
			if live.get("finished",false) and live.get("decision") is Dictionary:
				side.add_child(G.wrap(str(live.decision.get("label","Rencontre terminée")),15,G.GOLD))
			var tries:Array=live.get("tries",[0,0])
			side.add_child(G.label("ESSAIS   %s — %s"%[G.n(tries[0]),G.n(tries[1])],14,G.GOLD))
			if live.get("paused",false):side.add_child(G.wrap("Le jeu est en pause. Vos changements et vos consignes restent accessibles.",12,G.GOOD))
			var events:Array=live.get("events",[])
			for event in events.slice(maxi(0,events.size()-5)):
				var text:=str(event.get("text","")) if event is Dictionary else str(event)
				if event is Dictionary:side.add_child(G.label(G.n(event.get("min",0))+"'",20,G.GOLD,true))
				side.add_child(G.wrap(text,13,G.INK))
				side.add_child(G.separator())

func _bench(live:Dictionary) -> void:
	side.add_child(G.section("LES CHANGEMENTS"))
	if not live.get("paused",false):side.add_child(G.wrap("Mettez la rencontre en pause pour préparer le changement.",12,G.GOLD))
	var players:Array=live.get("lineup",[])
	var reserves:Array=live.get("reserves",[])
	for p in players:
		if not p is Dictionary:continue
		var b:=G.button(str(p.get("name","Joueur")),func():selected_out=str(p.id);presence_key="";_side())
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if str(p.get("id",""))==selected_out:b.add_theme_stylebox_override("normal",G.T.box(Color("493b2d"),4,G.GOLD))
		side.add_child(b)
	if selected_out.is_empty():return
	var allowed:Array=[]
	for option in live.get("substitutions",[]):
		if str(option.get("outId",""))==selected_out:allowed=option.get("inIds",[])
	side.add_child(G.separator())
	side.add_child(G.label("FAIRE ENTRER",12,G.GOLD))
	for p in reserves:
		if not p is Dictionary:continue
		var b:=G.button(str(p.get("name","Joueur")),func():app._command("substitute",{"outId":selected_out,"inId":p.id}))
		b.disabled=p.get("id") not in allowed or not live.get("paused",false) or live.get("finished",false)
		side.add_child(b)

func _act() -> void:
	var live:Dictionary=model.live if model.get("live") is Dictionary else {}
	if live.is_empty():app._command("begin_match")
	else:
		app._command("pause",{"paused":not live.get("paused",false)})
		app.timer.start()
