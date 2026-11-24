extends RefCounted
## Réception, cartes d'action du courrier : réponses du club, ouvertures d'écrans liés, choix de calendrier et politique de presse.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const U = preload("res://ui/management_state.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const Canvas = preload("res://ui/immersive08/reception_canvas.gd")

static func _action_rect(index: int, top: int) -> Rect2:
	var width := minf(520.0, (Canvas._reading_width() - 18) / 2.0)
	return Rect2(Canvas.PAD + index * (width + 18), top, width, Canvas._h(46))

static func _actions(card: Panel, app: Control, state: Dictionary, message: Dictionary, top: int) -> void:
	if message.has("press_invitation"):
		var invitation: Dictionary = message.press_invitation
		if state.get("press_opened") == invitation.id:
			var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
			var conference: Dictionary = press.get("conference", {})
			var outcome: Variant = press.get("lastOutcome")
			var receipt: bool = invitation.status == "published" and outcome is Dictionary and outcome.get("invitationId") == invitation.id
			if invitation.status == "pending" or receipt:
				var caption := "Consulter le compte rendu" if receipt else "Ouvrir la conférence"
				var action := D.button(card,_action_rect(0,top),caption,Callable(Canvas, "_open_related").bind(app, message, app._open_press_invitation.bind(invitation.id)),true,"arrow",false,app.accent,"InboxOpenPressInvitation")
				action.disabled = app.waiting or (not receipt and (not conference.get("available", false) or conference.get("invitationId") != invitation.id))
				if action.disabled: action.tooltip_text = str(conference.get("reason", ""))
				# Conférence ordinaire seulement (le moteur donne `moment` pour arrivée, phase finale, bilan, derby, crise).
				if not receipt and conference.get("available", false) and conference.get("invitationId") == invitation.id and not conference.get("moment") is Dictionary:
					_press_policy_toggle(card, app, _action_rect(1,top))
	elif message.has("scene_invitation"):
		var scene: Dictionary = message.scene_invitation
		var open := D.button(card,_action_rect(0,top),Canvas.scene_invitation_caption(scene),func():
			if is_instance_valid(app.contextual_director): app.contextual_director.open_invitation(str(scene.id)),true,"arrow",false,app.accent,"InboxOpenSceneInvitation")
		var blocking := Canvas._blocking(app)
		open.disabled = app.waiting or not blocking.is_empty()
		if not blocking.is_empty(): open.tooltip_text = "Disponible après " + app.contextual_director.meeting_label(blocking) + "."
	elif message.has("club_mail"):
		var mail: Dictionary = message.club_mail
		var ecran := str(mail.get("ecran",""))
		var joueur := str(mail.get("joueur","")) if mail.get("joueur") is String else ""
		D.button(card,_action_rect(0,top),ClubMail.caption(ecran),Callable(Canvas, "_open_related").bind(app, message, ClubMail.open_screen.bind(app, ecran, joueur)),not ClubMail.awaiting(app.model, mail),"arrow",false,app.accent,"InboxClubMailOpen")
	elif message.get("calendar_notice", {}).get("status") == "pending":
		var recalibrate := D.button(card,_action_rect(0,top),"Recaler la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"recalibrate"),true,"calendar",false,app.accent,"InboxRecalibratePreparation")
		var keep := D.button(card,_action_rect(1,top),"Conserver la préparation",
			_choose_calendar_preparation.bind(app,card,message.id,"keep"),false,"check",false,app.accent,"InboxKeepPreparation")
		recalibrate.disabled = app.waiting
		keep.disabled = app.waiting
	elif message.has("international_event"):
		var event: Dictionary = message.international_event
		var destination: String = event.get("action", "")
		if event.get("kind") == "international_host":
			var edition: Dictionary = app.Immersive.Selections.host_mail_edition(app.model, event)
			if not edition.is_empty():
				var caption: String = app.Immersive.Selections.host_mail_caption(edition)
				var open: Callable = app.Immersive.Selections.open_host.bind(app, edition)
				D.button(card,_action_rect(0,top),caption,Callable(Canvas, "_open_related").bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenInternational")
		elif destination in ["international", "national_job"]:
			var caption := "Voir les offres de sélection" if destination == "national_job" else "Ouvrir les sélections"
			if _has_match_sheet(app, event): caption = "Préparer la feuille de match"
			elif _is_club_return(app, event): caption = "Voir l’effectif"
			D.button(card,_action_rect(0,top),caption,Callable(Canvas, "_open_related").bind(app, message, _open_international.bind(app,event)),true,"arrow",false,app.accent,"InboxOpenInternational")
	else:
		var caption := "Ouvrir · " + str(message.route)
		var open := Callable(app, "_navigate").bind(message.route)
		if message.get("season_expiry", false):
			var current := _current_expiry_roster(app.model)
			if not current.is_empty():
				caption = "Voir les échéances actuelles (%d)" % current.count
				open = _open_expiry_roster.bind(app, current.roster)
		D.button(card,_action_rect(0,top),caption,Callable(Canvas, "_open_related").bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenMessageAction")
	# Une seule action principale (ivoire plein) par écran : celle qui ouvre l'écran du courrier ; si le courrier attend une
	# réponse, c'est « Envoyer la réponse » et les autres actions deviennent des liens texte.
	var awaiting_reply: bool = message.has("club_mail") and ClubMail.awaiting(app.model, message.club_mail) and not (message.club_mail.get("reponses", []) as Array).is_empty()
	for action in card.find_children("*", "Button", true, false):
		var id := str(action.name)
		if id.begins_with("InboxOpen") or id in ["InboxClubMailOpen", "InboxRecalibratePreparation"]:
			if awaiting_reply: C.style_bouton_lien(action, 19)
			else: C.style_bouton_contour(action, 19)
		elif id in ["InboxKeepPreparation", "InboxPressPolicy"]:
			C.style_bouton_lien(action, 19)

static func _art_fade(parent: Node, area: Rect2, horizontal: bool = true) -> GradientTexture2D:
	var fade := Control.new()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fade)
	D.place(fade,area)
	var overlay := C.veil(fade,horizontal)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return overlay.texture as GradientTexture2D

## Bascule discrète du réglage « conférences ordinaires » (commande press_policy, comme dans les Paramètres) ; la conférence en cours reste à traiter.
static func _press_policy_toggle(card: Panel, app: Control, rectangle: Rect2) -> void:
	var toggle := D.button(card,rectangle,_press_policy_caption(app),_press_policy_choose.bind(app, card),false,"",true,app.accent,"InboxPressPolicy")
	toggle.tooltip_text = "Gabi tient les conférences ordinaires à ta place, sur un ton prudent : médias −2 et relation −1 avec chaque journaliste présent. Tu restes convoqué aux grands rendez-vous (arrivée, phase finale, bilan de saison, derby, crise). La conférence ouverte reste à traiter."
	toggle.disabled = app.waiting

static func _press_policy_current(app: Control) -> String:
	return "adjoint" if str(app.model.get("clubLife", {}).get("press", {}).get("policy", {}).get("ordinary", "moi")) == "adjoint" else "moi"

static func _press_policy_caption(app: Control) -> String:
	return "Les prochaines fois, y aller moi-même" if _press_policy_current(app) == "adjoint" else "Les prochaines fois, envoyer Gabi aux conférences ordinaires"

static func _press_policy_choose(app: Control, card: Panel) -> void:
	var next := "moi" if _press_policy_current(app) == "adjoint" else "adjoint"
	app._command("press_policy", {"ordinary":next})
	_press_policy_refresh(app, card)
	# Un refus du moteur ramène le modèle à l'ancien réglage : relire un instant plus tard (le minuteur meurt avec la carte).
	var later := Timer.new()
	later.one_shot = true
	later.wait_time = 0.8
	card.add_child(later)
	later.timeout.connect(_press_policy_refresh.bind(app, card))
	later.start()

static func _press_policy_refresh(app: Control, card: Panel) -> void:
	var toggle := card.get_node_or_null("InboxPressPolicy") as Button
	if toggle != null: toggle.text = _press_policy_caption(app)

## Réponse à un mail du club (identifiant de réponse, ou « deleguer » : Gabi répond à ta place), envoyée dès le clic.
static func _reply_club_mail(app: Control, mail_id: String, choice: String) -> void:
	ClubMail.reply(app, mail_id, choice)

static func _open_international(app: Control, event: Dictionary) -> void:
	if _is_club_return(app, event):
		app._navigate("Effectif")
		return
	app.management_ui.international_section = "offers" if event.action == "national_job" else "callups"
	if _has_match_sheet(app, event): app.management_ui.international_section = "sheet"
	app.management_ui.international_nation = str(event.get("nation", ""))
	app._navigate("Sélections")

static func _is_club_return(app: Control, event: Dictionary) -> bool:
	return event.get("kind") == "international_return" and not app.Immersive.Selections.nation_only(app.model)

static func _has_match_sheet(app: Control, event: Dictionary) -> bool:
	var fixture: Dictionary = app.Immersive.Selections.current_fixture(app.model)
	return not fixture.is_empty() and event.id == "match-day/" + str(fixture.id) and not app.Immersive.Selections.Sheet.slots(app.model.international).is_empty()

static func _current_expiry_roster(model: Dictionary) -> Dictionary:
	var expiring: Variant = model.get("decisions", {}).get("recruitment", {}).get("expiring")
	if not expiring is Array: return {}
	var roster := U.defaults()
	roster.contract = "Fin de saison"
	roster.sort = "Échéance"
	roster.immersive_tab = 2
	var season := int(model.get("meta", {}).get("season", 1))
	var displayed := U.players(model.get("squad", []), roster, season)
	var displayed_ids := displayed.map(func(player: Dictionary): return str(player.id))
	var expiring_ids: Array = expiring.map(func(player: Dictionary): return str(player.id))
	displayed_ids.sort()
	expiring_ids.sort()
	# Le filtre inclut aussi les contrats antérieurs que certaines sauvegardes conservent.
	if displayed_ids != expiring_ids: return {}
	return {"roster":roster, "count":displayed_ids.size()}

static func _open_expiry_roster(app: Control, roster: Dictionary) -> void:
	app.management_ui.roster = roster
	app.management_ui.profile_scroll = 0
	app.roster_filter = roster.family
	app.roster_sort = roster.sort
	app.selected_player = ""
	app._navigate("Effectif", false)

static func _choose_calendar_preparation(app: Control, card: Panel, id: String, choice: String) -> void:
	if app._command("calendar_mail_decide",{"id":id, "choice":choice}):
		for name in ["InboxRecalibratePreparation", "InboxKeepPreparation"]:
			var action := card.get_node_or_null(name) as Button
			if action != null: action.disabled = true
