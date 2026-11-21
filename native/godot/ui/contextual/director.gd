extends Node
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Locker = preload("res://ui/contextual/locker_view.gd")
const Live = preload("res://ui/contextual/live_view.gd")
const Conversation = preload("res://ui/contextual/conversation_view.gd")
const Training = preload("res://ui/contextual/training_view.gd")
var app: Control
var overlay: Control
var view: Control
var error_label: Label
var kind := ""
var scene_key := ""
var training_open := false
var _waiting := false
var _shell_visible := true
var _coach_visible := true

func setup(owner: Control) -> void:
	app = owner
	name = "ContextualDirector"
	set_process_input(true)
	set_process(true)

func active() -> bool:
	return is_instance_valid(overlay)

func match_immersed() -> bool:
	if app == null: return false
	return not _talk().is_empty() or (not _live().is_empty() and not en_consultation())

## Après-match (ui/contextual/apres_match.gd) : match fini, résultat pas encore validé, le manager consulte un autre
## écran (fiche d'un club, d'un joueur, levier du « Pourquoi », classement, calendrier). La scène du match se ferme ;
## « Continuer » de la coque (ou Espace, ou Précédent) ramène à l'après-match par la route « Match ».
var consultation := false
## Rencontre dont l'après-match a déjà été montré (live_view.cle_apres_match) : au retour d'une consultation, il
## revient aussitôt, sans attendre que la régie rejoue la fin du match.
var apres_match_vu := ""

func en_consultation() -> bool:
	return consultation and bool(_live().get("finished", false))

## Ouvre `cible` (navigation_controller.open_entity) depuis l'après-match ; rien pendant une attente du moteur.
func consulter(cible: Dictionary) -> bool:
	if app == null or app.waiting or not bool(_live().get("finished", false)) or not _talk().is_empty(): return false
	consultation = true
	_close()
	# Fiche d'un club sur un onglet donné (XV type pour un joueur adverse) : open_entity garde l'onglet du même club.
	if str(cible.get("kind", "")) == "club" and cible.has("onglet"):
		app.management_ui.club_sheet = {"id":int(float(str(cible.get("id", -1)))), "tab":int(cible.onglet), "sort":"fam", "descending":false}
	var ouvert := false
	if is_instance_valid(app.navigation_controller): ouvert = app.navigation_controller.open_entity(cible)
	if not ouvert or app.route == "Match":
		consultation = false
		app.route = "Match"
		sync()
	return ouvert

## Retour à l'après-match depuis un écran consulté.
func revenir_apres_match() -> void:
	if not en_consultation(): return
	app._navigate("Match")

## Consultation pendant un rendez-vous (salle du conseil : ballon de la frise → Calendrier), comme l'après-match :
## la salle se ferme, l'écran consulté s'ouvre ; « Continuer » de la coque ramène au rendez-vous, qui reste en attente
## du serveur (rien n'avance tant qu'il n'est pas réglé). Vaut pour ce rendez-vous seulement (identifiant).
var consultation_reunion := ""

func en_consultation_reunion() -> bool:
	return not consultation_reunion.is_empty() and str(_meeting().get("id", "")) == consultation_reunion

## Ouvre `cible` (navigation_controller.open_entity, par ex. {kind: "date", id: "2026-09-26"}) depuis le rendez-vous.
func consulter_depuis_reunion(cible: Dictionary) -> bool:
	var meeting := _meeting()
	if app == null or app.waiting or meeting.is_empty() or not is_instance_valid(app.navigation_controller): return false
	consultation_reunion = str(meeting.get("id", ""))
	_close()
	var ouvert: bool = app.navigation_controller.open_entity(cible)
	if not ouvert:
		consultation_reunion = ""
		sync()
	return ouvert

## Retour au rendez-vous depuis l'écran consulté.
func revenir_reunion() -> void:
	consultation_reunion = ""
	sync()

func active_meeting() -> bool:
	return not _meeting().is_empty() and not en_consultation_reunion()

func _meeting() -> Dictionary:
	var club_life: Dictionary = app.model.get("clubLife", {})
	var value: Variant = club_life.get("clubMeetings", {}).get("scene")
	if not value is Dictionary: return {}
	if value.get("kind") != "press": return value
	# The appointment remains mandatory in the worker. Only its mail opens the room.
	var origin := str(app.get_meta("press_mail_origin", ""))
	if origin.is_empty(): return {}
	var press: Dictionary = club_life.get("press", {})
	if value.get("completed", false):
		var outcome: Variant = press.get("lastOutcome")
		return value if outcome is Dictionary and outcome.get("invitationId") == origin and outcome.get("context") == value.get("context") else {}
	return value if press.get("context") == value.get("context") and press.get("conference", {}).get("invitationId") == origin else {}

## Après-match façon FM (18/11/2026) : la conférence courte d'après-match (créneau « apres ») n'est pas un rendez-vous
## du club, mais elle se tient dans la même salle de presse, ouverte depuis son courrier ou juste après le résultat.
## Vide sinon. `completed` : réponses publiées (par le manager ou Gabi), la salle attend « Continuer ».
func postmatch_press() -> Dictionary:
	var origin := str(app.get_meta("press_mail_origin", ""))
	if origin.is_empty(): return {}
	var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
	var context: Variant = press.get("context")
	var conference: Dictionary = press.get("conference", {})
	if conference.get("available", false) and conference.get("invitationId") == origin and context is Dictionary and context.get("slot") == "apres":
		return {"postmatch":true, "completed":false, "invitationId":origin}
	var outcome: Variant = press.get("lastOutcome")
	if kind == "press" and outcome is Dictionary and outcome.get("invitationId") == origin and outcome.get("context", {}).get("slot") == "apres":
		return {"postmatch":true, "completed":true, "invitationId":origin}
	return {}

## Rendez-vous du club obligatoire qui bloque les autres actions (en cours ou premier de la file), vide sinon.
func blocking_meeting() -> Dictionary:
	var meetings: Dictionary = app.model.get("clubLife", {}).get("clubMeetings", {})
	var scene: Variant = meetings.get("scene")
	if scene is Dictionary: return scene
	var queue: Array = meetings.get("queue", [])
	return queue[0] if not queue.is_empty() and queue[0] is Dictionary else {}

## Nom d'un rendez-vous du club pour le joueur : « la conférence de presse », « le point médical »…
static func meeting_label(meeting: Dictionary) -> String:
	match str(meeting.get("kind", "")):
		"press": return "la conférence de presse"
		"medical": return "le point médical"
		"board": return "le rendez-vous avec la direction"
	return "le rendez-vous du club"

func _talk() -> Dictionary:
	var value: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return value if value is Dictionary else {}

func _live() -> Dictionary:
	var value: Variant = app.model.get("live")
	return value if value is Dictionary else {}

func sync(_received_command: String = "", _response_ok: bool = true) -> bool:
	if app == null: return false
	var next := ""
	var key := ""
	var data: Dictionary = {}
	var talk := _talk()
	var live := _live()
	var invitation: Variant = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("active")
	# Consultation terminée : retour à l'après-match (route « Match »), résultat validé ou match disparu.
	if consultation and (live.is_empty() or not bool(live.get("finished", false)) or not talk.is_empty() or app.route == "Match"): consultation = false
	if consultation: live = {}
	if _live().is_empty(): apres_match_vu = ""
	# Match en temps forts : le dernier temps fort de la période se regarde avant la
	# causerie ou le débrief. La régie rappelle `sync` quand il est fini.
	if not talk.is_empty() and kind == "live" and active() and not live.is_empty() and view.has_method("retient_la_causerie") and view.retient_la_causerie(live):
		talk = {}
	if not talk.is_empty():
		next = "locker"
		data = talk
		key = str(talk.get("key", "")) + ":" + str(talk.get("phase", ""))
	elif not live.is_empty():
		next = "live"
		key = "live"
	elif invitation is Dictionary:
		next = "conversation"
		data = invitation
		key = str(invitation.get("id", ""))
	elif not _meeting().is_empty() and not en_consultation_reunion():
		var meeting := _meeting()
		next = str(meeting.get("kind", ""))
		data = meeting.duplicate(true)
		data["meetingId"] = meeting.get("id")
		key = next + ":" + str(meeting.get("id", ""))
	elif not postmatch_press().is_empty():
		next = "press"
		data = postmatch_press()
		key = "press:apres:" + str(data.get("invitationId", ""))
	elif training_open and app.model.get("club") is Dictionary:
		next = "training"
		key = "training"
	if next.is_empty():
		_close()
		return false
	if next in ["press", "medical", "board", "conversation"]: training_open = false
	if next in ["locker", "live"]:
		training_open = false
		app.route = "Match"
	if next != kind or key != scene_key or not active(): _open(next, key, data)
	if is_instance_valid(app.root_content): app.root_content.hide()
	if is_instance_valid(app.coach): app.coach.hide()
	if next == "live":
		app.match_screen = view
		view.update_frame(app.model)
		if not live.get("paused", false) and not live.get("finished", false):
			if app.timer.is_stopped(): app.timer.start()
		else: app.timer.stop()
	else:
		app.timer.stop()
		view.update_frame(app.model, data)
	_refresh_controls()
	return true

func render_if_needed() -> bool:
	return sync()

func _open(value: String, key: String, data: Dictionary) -> void:
	if not active():
		_shell_visible = is_instance_valid(app.root_content) and app.root_content.visible
		_coach_visible = is_instance_valid(app.coach) and app.coach.visible
	_close(false)
	kind = value
	scene_key = key
	overlay = Control.new()
	overlay.name = "ContextualImmersion"
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(overlay)
	app.add_child(overlay)
	match kind:
		"locker": view = Locker.new()
		"live": view = Live.new()
		"conversation": view = Conversation.new()
		"training": view = Training.new()
		"press": view = load("res://ui/contextual/press_room_view.gd").new()
		"medical": view = load("res://ui/contextual/medical_room_view.gd").new()
		"board": view = load("res://ui/contextual/board_room_view.gd").new()
	view.director = self
	S.full(view)
	overlay.add_child(view)
	var error_panel := PanelContainer.new()
	error_panel.name = "ContextualActionError"
	error_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	error_panel.offset_left = -420
	error_panel.offset_right = 420
	error_panel.offset_top = 3
	error_panel.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU_3, Charte.RAYON_CARTE, 10), Charte.RAYON_CARTE))
	overlay.add_child(error_panel)
	error_label = S.wrap("", 14, S.TEXT)
	error_panel.add_child(error_label)
	if kind == "live": app.match_screen = view
	elif is_instance_valid(app.match_screen) and app.match_screen != view: app.match_screen = null
	_waiting = not bool(app.waiting)

func _close(restore: bool = true) -> void:
	var was_active := active()
	if is_instance_valid(view) and app.match_screen == view: app.match_screen = null
	if is_instance_valid(overlay):
		app.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	view = null
	error_label = null
	kind = ""
	scene_key = ""
	if restore and was_active:
		if is_instance_valid(app.root_content): app.root_content.visible = _shell_visible
		if is_instance_valid(app.coach): app.coach.visible = _coach_visible

func command(command_name: String, payload: Dictionary = {}) -> void:
	if app.waiting: return
	app._command(command_name, payload)
	_refresh_controls()

func open_invitation(id: String) -> void:
	if not match_immersed(): command("scene_invitation_open", {"id":id})

func open_training() -> void:
	if active_meeting(): return
	if match_immersed() or not app.model.get("club") is Dictionary or app.model.get("meta", {}).get("phase") == "ended": return
	training_open = true
	sync()

func open_room(room_kind: String, _data: Dictionary = {}) -> void:
	# Only the current persisted appointment may open a mandatory room.
	if not app.waiting and str(_meeting().get("kind", "")) == room_kind: sync()

func close_room() -> void:
	var postmatch := postmatch_press() if _meeting().is_empty() else {}
	if not postmatch.is_empty():
		if app.waiting or not postmatch.get("completed", false): return
		app.remove_meta("press_mail_origin")
		_close()
		app.route = "Réception"
		app._render(false)
		return
	var meeting := _meeting()
	if app.waiting or not meeting.get("completed", false): return
	command("club_meeting_continue", {"meetingId":meeting.get("id")})

func close_training() -> void:
	if app.waiting: return
	training_open = false
	_close()
	app._render(false)

func _process(_delta: float) -> void:
	if not active(): return
	# Coach refresh is deferred by the shell and must never cover these scenes.
	if is_instance_valid(app.coach): app.coach.hide()
	if is_instance_valid(app.root_content): app.root_content.hide()
	if _waiting != bool(app.waiting): _refresh_controls()
	if is_instance_valid(error_label):
		error_label.text = str(app.last_error)
		error_label.get_parent().visible = not error_label.text.is_empty()

func _refresh_controls() -> void:
	if not active(): return
	_waiting = bool(app.waiting)
	for control in overlay.find_children("*", "BaseButton", true, false):
		if control.has_meta("contextual_enabled"):
			control.disabled = _waiting or not bool(control.get_meta("contextual_enabled"))

func _input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed: return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if (event.ctrl_pressed and code == KEY_K) or (event.alt_pressed and code in [KEY_LEFT, KEY_RIGHT]) or code in [KEY_F1, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		# Une petite fenêtre ouverte (joueur du vestiaire…) : Échap la ferme et ne fait rien d'autre.
		if code == KEY_ESCAPE and not event.echo and PetiteFenetre.fermer_derniere(get_tree()): return
		# Direct : Échap met en pause et ouvre le menu du match (live_view.gd le traite d'ordinaire avant).
		if code == KEY_ESCAPE and kind == "live" and is_instance_valid(view) and view.has_method("echap") and not event.echo: view.echap()

const Components = preload("res://ui/immersive08/components.gd")
const INVITATION_PANEL := Charte.PANNEAU
const INVITATION_TITLE := Charte.CREME
const INVITATION_REASON := Charte.GRIS_VERT
const INVITATION_GOLD := S.GOLD
const INVITATION_GAP := 12

# Mêmes corps que les lignes du courrier (reception_canvas.gd : 20 pour le titre, 17 pour le détail), mis à l'échelle
# de la fenêtre : la carte reste lisible à toutes les résolutions, au lieu des 12 px plafonnés de reading_size().
func _invitation_title_size() -> int: return maxi(13, Components.px(20))
func _invitation_reason_size() -> int: return maxi(12, Components.px(17))
func _invitation_card_width() -> int: return maxi(300, Components.px(620))

# Carte sombre de la charte (panneau noir, rayon 18, ombre portée) : le texte à gauche, l'action à droite.
func _invitation_card(card_name: String, _edge: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.name = card_name
	var style := StyleBoxFlat.new()
	style.bg_color = INVITATION_PANEL
	style.set_corner_radius_all(Charte.RAYON_PANNEAU)
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", Charte.ombrer(style, Charte.RAYON_PANNEAU))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	return {"card": card, "row": row}
func _invitation_text(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold: label.add_theme_font_override("font", Components.BOLD)
	return label

func _invitation_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(Components.px(150), maxi(32, Components.px(46)))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", _invitation_reason_size())
	button.add_theme_font_override("font", Components.BOLD)
	var states := {"normal": Charte.DORE, "hover": Charte.OR_VIF, "pressed": Charte.OR_VIF, "disabled": Charte.PANNEAU_3}
	for key: String in states:
		button.add_theme_stylebox_override(key, Charte.style_pilule(states[key], Color.TRANSPARENT, 18, 6))
	var focus := Charte.style_pilule(Color.TRANSPARENT, INVITATION_TITLE, 18, 6)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Charte.ENCRE)
	button.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	button.pressed.connect(callback)
	return button

func install_entrypoints() -> void:
	if active() or not is_instance_valid(app.root_content): return
	if app.route == "Préparation":
		var parent: Node = app.root_content.find_child("PreparationEntrainement", true, false)
		if parent == null and app.management_ui.get("preparation", {}).get("tab", 0) == 2:
			parent = app.body
		if parent != null and parent.find_child("ContextualObserveTraining", true, false) == null:
			_add_training_entry(parent)
	elif app.route == "Travail du club":
		if is_instance_valid(app.body) and app.body.find_child("ContextualObserveTraining", true, false) == null: _add_training_entry(app.body)

func _add_training_entry(parent: Node) -> void:
	# Style de bouton du jeu (contour or, comme « Préparer le match »), plus le bouton blanc pleine largeur du thème Godot.
	# Fond sombre quel que soit l'accent du club (une couleur claire donnait un bouton presque blanc), contour or.
	var button := Components.button("VOIR L’ENTRAÎNEMENT", open_training, false, app.accent)
	var normal := (button.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	normal.border_color = Components.GOLD
	button.add_theme_stylebox_override("normal", normal)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size.x = Components.px(300)
	button.name = "ContextualObserveTraining"
	button.disabled = not _live().is_empty() or app.model.get("meta", {}).get("phase") == "ended"
	# Page riche (gabarit fixe, Travail du club) : le bouton se pose dans le coin haut droit du gabarit, sur la
	# photo d'en-tête, au lieu de pousser toute la page vers le bas (le panneau de droite se mettait à défiler).
	var canvas := _fixed_canvas(parent)
	if canvas != null:
		button.custom_minimum_size.y = maxi(32, Components.px(46))
		canvas.add_child(button)
		var width := maxf(button.custom_minimum_size.x, button.get_combined_minimum_size().x)
		var height := maxf(button.custom_minimum_size.y, button.get_combined_minimum_size().y)
		var margin := float(Components.px(24))
		button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		button.offset_left = -width - margin
		button.offset_right = -margin
		button.offset_top = Components.px(18)
		button.offset_bottom = button.offset_top + height
		return
	parent.add_child(button)
	parent.move_child(button, 0)
	_contain_entry_content(parent, button)

## Gabarit fixe de la page riche (Control simple, hors conteneur) posé seul dans le corps du Travail du club.
func _fixed_canvas(parent: Node) -> Control:
	if parent != app.body or app.route != "Travail du club": return null
	var pages := parent.get_children().filter(func(node: Node): return node is Control and not node.is_queued_for_deletion())
	if pages.size() != 1: return null
	var page: Control = pages[0]
	if page is Container: return null
	return page

func _contain_entry_content(parent: Node, entry: Control) -> void:
	if parent != app.body: return
	for inner: ScrollContainer in parent.find_children("*", "ScrollContainer", true, false):
		inner.mouse_force_pass_scroll_events = false
		inner.mouse_filter = Control.MOUSE_FILTER_STOP
	# Full-height career pages were sized before these entrypoints were added.
	# Give the page the remaining space while keeping the new actions visible.
	var scroll := ScrollContainer.new()
	scroll.name = "ContextualPageWorkspace"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	S.G.fill(scroll, true)
	var content := S.G.v(0)
	S.G.fill(content, true)
	for child in parent.get_children():
		if child == entry: continue
		parent.remove_child(child)
		content.add_child(child)
	parent.add_child(scroll)
	scroll.add_child(content)
