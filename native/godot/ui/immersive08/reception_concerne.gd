extends RefCounted
## Réception, panneau de droite « Concerné » : joueur lié, échéance, compétition et pièces jointes.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Press = preload("res://ui/press_view.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const Canvas = preload("res://ui/immersive08/reception_canvas.gd")

## Hauteur de la rangée « Concerné » : joueur lié (nom, disponibilité), club, joueurs en fin de contrat. 0 si rien.
static func _concerned_layout(app: Control, message: Dictionary, width: float) -> Dictionary:
	var data := _concerned(app, message)
	if not (data.has("player") or data.has("club") or data.has("expiring")): return {}
	var availability := ""
	if data.has("player"):
		var player: Dictionary = data.player
		var weeks := float(player.get("injury", 0)) if (player.get("injury") is int or player.get("injury") is float) else 0.0
		availability = ("%s · %d sem." % [ClubMail.injury_label(app.model, player), ceili(weeks)]) if weeks > 0 else ("En reprise" if P.player_in_recovery(app.model, str(player.get("id", ""))) else "Apte")
	var lines := Canvas.wrapped_lines(availability, 18, minf(300.0, width - 420.0)) if not availability.is_empty() else 1
	return {"data":data, "availability":availability, "lines":lines, "height":maxf(Canvas._h(40), 24.0 * lines + 10.0)}

## Nom cliquable (joueur, club) : lien souligné d'emblée quand il ouvre un écran ; sans destination, texte gris non
## souligné (jamais un faux lien). Mêmes noms de contrôle qu'avant.
static func _nom_lien(app: Control, parent: Node, rectangle: Rect2, kind: String, id: Variant, caption: String, size: int, _color: Color, control_name: String) -> Control:
	if not Link.available(app, kind, id):
		var inert := C.label(caption, size, C.FAINT, false, 500)
		inert.name = control_name
		parent.add_child(inert)
		D.place(inert, rectangle)
		return inert
	var button := C.button(caption, func(): pass)
	button.name = control_name
	Link.bind(button, app, Link.target(kind, id), caption)
	C.style_bouton_lien(button, size, true)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(button)
	D.place(button, rectangle)
	return button

## Rangée « CONCERNÉ » sous la lettre : noms en liens (mini-fiche au survol d'un joueur, clic = fiche), club, échéances.
static func _concerned_row(card: Panel, app: Control, message: Dictionary, layout: Dictionary, x: float, y: float, width: float) -> void:
	var data: Dictionary = layout.data
	D.text(card, x, y + 26, "CONCERNÉ", 17, C.MUTED, 700, 110)
	var cursor := x + 120.0
	var limit := x + width
	if data.has("player"):
		var player: Dictionary = data.player
		var player_id := str(player.get("id", ""))
		var link := _nom_lien(app, card, Rect2(cursor, y, 260, Canvas._h(40)), "player", player_id, str(player.get("name", "")), 20, C.IVORY, "InboxConcernedName")
		link.accessibility_name = "Ouvrir la fiche de " + str(player.get("name", ""))
		MiniFiche.lier(app, link, player_id, "squad")
		cursor += 270.0
		var state_label := D.text(card, cursor, y + 27, str(layout.availability), 18, C.ALERT if float(player.get("injury", 0) if (player.get("injury") is int or player.get("injury") is float) else 0) > 0 else C.MUTED, 600, minf(300.0, limit - cursor - 10.0), HORIZONTAL_ALIGNMENT_LEFT, true)
		state_label.name = "InboxConcernedAvailability"
		state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		state_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		state_label.size.y = C.px(24.0 * int(layout.lines))
		cursor += minf(300.0, limit - cursor - 10.0) + 14.0
	if data.has("club") and cursor + 300.0 <= limit:
		var club: Dictionary = data.club
		var rank := "1er" if int(club.rank) == 1 else "%de" % int(club.rank)
		var club_link := _nom_lien(app, card, Rect2(cursor, y, 340, Canvas._h(40)), "club", str(club.id), "%s · %s" % [club.name, rank], 20, C.IVORY, "InboxConcernedClub")
		club_link.accessibility_name = "Ouvrir la fiche de " + str(club.name)
		cursor += 350.0
	if data.has("expiring"):
		var players: Array = data.expiring
		var shown := 0
		for index in mini(players.size(), 4):
			if cursor + 240.0 > limit: break
			var person: Dictionary = players[index]
			var chip := _nom_lien(app, card, Rect2(cursor, y, 230, Canvas._h(40)), "player", str(person.id), str(person.name), 19, C.IVORY, "InboxExpiryPlayer_" + str(index))
			chip.set_meta("player_id", str(person.id))
			MiniFiche.lier(app, chip, str(person.id), "squad")
			cursor += 240.0
			shown += 1
		if players.size() > shown: D.text(card, cursor, y + 27, "+ %d dans Effectif" % (players.size() - shown), 17, C.MUTED, 500, 220)

## Pièces liées sous le texte (rencontre concernée, dossier de préparation, priorités de la semaine).
## Rend la hauteur occupée ; rien n'est dessiné si `draw` est faux (mesure avant placement).
static func _attachments(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: float, focused: bool, draw: bool, width: float) -> float:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	if message.is_empty() or national: return 0.0
	var y := top
	var x := Canvas.PAD
	var link_width := minf(520.0, (width - 16) / 2.0)
	var notice: Dictionary = message.get("calendar_notice",{})
	var next: Variant = app.model.get("next")
	var drew := false
	if not notice.is_empty():
		var target := {"kind":"fixture","id":str(notice.get("fixtureId",""))}
		var caption := "Rencontre · " + str(notice.get("opponent",""))
		if not Competition.target_available(app,"fixture",target.id):
			target = {"kind":"date","id":str(notice.get("toDate",""))}
			caption = "Calendrier · " + P.fixture_date({"date":notice.get("toDate")})
		if Competition.target_available(app,str(target.kind),target.id):
			if draw:
				var link := Link.button(app,caption,target,"InboxContextFixture")
				C.style_bouton_lien(link, 18)
				card.add_child(link); D.place(link,Rect2(x,y,link_width,Canvas._h(40)))
			drew = true
	elif not focused and next is Dictionary and not next.is_empty():
		if draw:
			var prep := D.button(card,Rect2(x,y,link_width,Canvas._h(40)),"Dossier de préparation · "+str(next.get("label","Prochain match")),Callable(Canvas, "_open_related").bind(app,message,Callable(app,"_navigate").bind("Préparation")),false,"tactic",true,app.accent,"InboxPreparation")
			prep.tooltip_text = "Ouvrir l’analyse de la prochaine rencontre · " + P.fixture_date(next)
			C.style_bouton_lien(prep, 18)
		drew = true
	if drew: y += Canvas._h(40) + 14
	# Priorités de la semaine, pour un courrier d'information du club.
	if not focused:
		var tasks := Canvas._tasks(app).slice(0,3)
		if not tasks.is_empty():
			if draw: D.text(card,x,y+18,"PRIORITÉS DE LA SEMAINE",17,C.GOLD,700,400)
			var cell := (width - 32) / 3.0
			for index in tasks.size():
				if not draw: break
				var task: Array = tasks[index]
				var action := D.button(card,Rect2(x+index*(cell+16),y+30,cell,Canvas._h(40)),task[0],func():
					if task[1]=="Entraînement": app.Immersive.open_training(app)
					else: app._navigate(task[1]),false,"arrow",true,app.accent,"InboxRecommendation"+str(index))
				action.tooltip_text = task[0]
				C.style_bouton_lien(action, 17)
			y += Canvas._h(40) + 34
	return y - top

## Ce que la rangée « Concerné » montre pour un mail : joueur lié, joueurs en fin de contrat, échéance ({} : rien).
static func _concerned(app: Control, message: Dictionary) -> Dictionary:
	if message.is_empty() or app.Immersive.Selections.nation_only(app.model): return {}
	var result := {}
	var mail: Dictionary = message.get("club_mail", {})
	if mail.get("joueur") is String and not str(mail.joueur).is_empty():
		var player := P.player(app.model, str(mail.joueur))
		if not player.is_empty(): result.player = player
	if message.get("season_expiry", false):
		var expiring: Array = app.model.get("decisions", {}).get("recruitment", {}).get("expiring", [])
		var ids: Array = expiring.map(func(player: Dictionary): return str(player.id))
		var players: Array = app.model.get("squad", []).filter(func(player: Dictionary): return str(player.id) in ids)
		if not players.is_empty(): result.expiring = players
	var club: Variant = mail.get("club")
	if (club is int or club is float or (club is String and not club.is_empty())) and str(club) != str(app.model.get("club", {}).get("id", "")):
		var row := _league_row(app.model, club)
		if not row.is_empty(): result.club = row
	var due := Canvas._deadline(app, message, true)
	if not due.is_empty(): result.deadline = due
	return result

## Ligne du classement d'un club (nom, rang) ; {} s'il n'est dans aucune division projetée.
static func _league_row(model: Dictionary, id: Variant) -> Dictionary:
	for division: Dictionary in model.get("leagues", []):
		var rows: Array = division.get("rows", [])
		for index in rows.size():
			var row: Dictionary = rows[index]
			if str(row.get("id", "")).to_int() == str(id).to_int() and str(id).is_valid_int():
				return {"id":str(id), "name":Press.G.club_name(row), "rank":index + 1, "division":str(division.get("name", division.get("label", "")))}
	return {}

static func _open_club(app: Control, club_id: String) -> void:
	app.navigation_controller.open_entity({"kind":"club","id":club_id})

## Montant compact : « 1,2 M€ », « 850 k€ ».
static func _money(amount: float) -> String:
	if absf(amount) >= 1000000.0: return ("%.1f M€" % (amount / 1000000.0)).replace(".", ",")
	if absf(amount) >= 1000.0: return "%d k€" % roundi(amount / 1000.0)
	return "%d €" % roundi(amount)

static func _open_current_player(app: Control, player_id: String) -> void:
	app.navigation_controller.open_entity({"kind":"player","id":player_id,"section":"contract"})
