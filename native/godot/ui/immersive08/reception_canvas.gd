extends RefCounted
## Réception, direction A « Bureau du manager » (maquette validée par Léo le 18/11/2026) : liste groupée par jour à
## gauche, mail en grand au centre (réponses en cartes avec leurs conséquences réelles), panneau « Concerné » à droite
## (joueur lié, échéance), gabarits presse (coupure de journal) et médical (tableau de l'infirmerie).
const Copy = preload("res://ui/management_copy.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const RoomIdentityCouleurs = preload("res://ui/contextual/rooms/room_identity.gd")
const C = preload("res://ui/immersive08/components.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const Portraits = preload("res://ui/game_skin.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const U = preload("res://ui/management_state.gd")
const Press = preload("res://ui/press_view.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const CATEGORIES = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Compétitions"]
const ICONS = {"Staff":"train", "Médical":"heart", "Direction":"shield", "Recrutement":"search", "Formation":"school", "Compétitions":"trophy", "Club":"mail", "Météo":"cloud"}
const COLORS = {"Staff":C.MINT, "Médical":C.ALERT, "Direction":C.GOLD, "Recrutement":C.BLUE, "Formation":C.MINT, "Compétitions":C.GOLD, "Club":C.MUTED, "Presse":C.GOLD, "Sélections":C.GOLD, "Calendrier":C.GOLD, "Invitation":C.GOLD, "Météo":C.BLUE}
const ROUTES = {"Staff":"Préparation", "Médical":"Effectif", "Direction":"Club", "Recrutement":"Recrutement", "Formation":"Formation", "Compétitions":"Calendrier", "Club":"Bureau", "Météo":"Composition"}
## Expéditeur affiché dans la liste et en tête du mail ouvert (le moteur ne signe que le courrier du club).
const SENDERS = {"Staff":"Staff technique", "Médical":"Service médical", "Direction":"Direction du club", "Recrutement":"Cellule de recrutement", "Formation":"Centre de formation", "Compétitions":"Organisateur des compétitions", "Club":"Secrétariat du club", "Météo":"Intendance du club"}
## Gabarit 2248 × 1124 (coordonnées 2560 × 1440 du jeu) : liste ≈ 25 %, mail au centre, panneau « Concerné » ≈ 21 %.
const PAGE := Vector2(2248, 1124)
## Hauteur minimale du gabarit quand la fenêtre est basse.
const MIN_HEIGHT := 680.0
const LIST_WIDTH := 560.0
const GAP := 18.0
const SIDE_WIDTH := 470.0
## Largeur du mail quand le panneau « Concerné » est masqué (le mail s'élargit).
const DETAIL_WIDTH := 2248.0 - 560.0 - 18.0
## Marge intérieure du mail et largeur maximale de la colonne de lecture (≈ 700 px de la maquette).
const PAD := 44.0
const READING_MAX := 1100.0
const SUBJECTS = ["Tous", "Staff", "Médical", "Direction", "Recrutement", "Formation", "Compétitions", "Météo", "Club"]
## Icône du service expéditeur (palette existante) ; un portrait n'est montré que pour une personne identifiée.
const SERVICE_ICONS = {"Presse":"globe", "Sélections":"flag", "Calendrier":"calendar", "Invitation":"people", "Staff":"train", "Médical":"heart", "Direction":"shield", "Recrutement":"search", "Formation":"school", "Compétitions":"trophy", "Club":"home", "Météo":"cloud"}
## Entrées du menu « Sujet » hors catégories : favoris, archives et états rares, pour qu'une seule rangée de filtres suffise.
const SUBJECT_EXTRAS = [["favorites", "Favoris"], ["archives", "Archives"], ["waiting", "En attente"], ["info", "Infos"]]
## Délai avant qu'une demande du club sans réponse soit classée (club-mail.json, cadence.delaiReponse).
const DELAI_REPONSE := 7
## Hauteur ajoutée à la fiche du panneau « Concerné » par ligne supplémentaire de « DISPONIBILITÉ ».
const SIDE_LINE_EXTRA := 26.0
## Condition sous laquelle un joueur apte figure à l'infirmerie comme « incertain » pour le prochain match.
const INCERTAIN := 65.0
## Rubrique du journal selon le type de courrier de presse (club-mail.json).
const RUBRIQUES = {"article":"COMPTE RENDU", "rumeur":"MERCATO", "critique":"TRIBUNE", "une_derby":"DERBY"}
const MONTHS = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const DAYS = ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
# Trois formes : singulier et pluriel accordés (moteur actuel) et la forme historique « contrat(s) expire(nt) » des anciennes carrières.
const SEASON_EXPIRY_MAILS := [
	"%d contrat expire à la fin de cette saison. Consulte l'onglet Contrats pour anticiper les départs.",
	"%d contrats expirent à la fin de cette saison. Consulte l'onglet Contrats pour anticiper les départs.",
	"%d contrat(s) expire(nt) à la fin de cette saison. Consulte l'onglet Contrats pour anticiper les départs.",
]
## Largeur du mail ouvert pour la construction en cours (dépend de la présence du panneau « Concerné »).
static var _w := DETAIL_WIDTH

static func _state(app: Control) -> Dictionary:
	if not app.management_ui.has("reception"):
		app.management_ui.reception = {"folder":0, "category":"Tous", "selected":"", "oldest_first":false, "marks":{}, "scroll":0}
	var state: Dictionary = app.management_ui.reception
	if not state.has("activity_filter"): state.activity_filter = "all"
	if not state.has("expanded_threads"): state.expanded_threads = {}
	if not state.has("reply_pick"): state.reply_pick = {}
	return state

static func international_mail(model: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var international: Variant = model.get("international")
	if not international is Dictionary or not international.get("mail") is Array: return result
	var seen := {}
	for event: Variant in international.mail:
		if not event is Dictionary or not event.get("id") is String or event.id.is_empty() or seen.has(event.id): continue
		seen[event.id] = true
		result.append(event)
	return result

static func _priority_ids(model: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if model.get("international", {}).get("role") != "nation":
		for invitation: Dictionary in model.get("clubLife", {}).get("press", {}).get("invitations", []):
			if invitation.status == "pending": ids.append(invitation.id)
		for notice: Dictionary in model.get("calendarMail", []):
			if notice.status == "pending": ids.append(notice.id)
	for event: Dictionary in international_mail(model): ids.append("international:" + event.id)
	return ids

static func new_priority(previous: Dictionary, current: Dictionary) -> String:
	var before := _priority_ids(previous)
	for id in _priority_ids(current):
		if id not in before: return id
	return ""

static func _messages(app: Control) -> Array[Dictionary]:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var source: Array = [] if national else app.model.get("messages", [])
	var messages: Array[Dictionary] = []
	var occurrences := {}
	# Le moteur ne fournit que des textes dans l'ordre de réception. Distinguer
	# deux exemplaires identiques sans modifier les données d'une carrière.
	for index in range(source.size()-1, -1, -1):
		var message := str(source[index])
		occurrences[message] = int(occurrences.get(message, 0)) + 1
		var id := message.sha256_text() + "-" + str(occurrences[message])
		var clean := Copy.news(message).replace("l’onglet Contrats", "les fiches des joueurs dans Effectif").replace("l'onglet Contrats", "les fiches des joueurs dans Effectif")
		var folded := U.fold(clean)
		var category := _category(folded)
		var destination: String = ROUTES[category]
		if category == "Direction" and "contrat" in folded: destination = "Effectif"
		if category == "Direction" and ("tresorerie" in folded or "billetterie" in folded): destination = "Finances"
		var item := {"id":id, "text":clean, "category":category, "route":destination, "position":source.size()-index}
		if _is_season_expiry_mail(message): item.season_expiry = true
		messages.push_front(item)
	var notices: Array = [] if national else app.model.get("calendarMail", [])
	for index in notices.size():
		var notice: Dictionary = notices[index]
		var previous_date := P.fixture_date({"date":notice.fromDate})
		var new_date := P.fixture_date({"date":notice.toDate})
		var opponent := str(notice.opponent)
		var fixture := "Ta rencontre" if opponent.is_empty() else "Ta rencontre contre " + opponent
		var text := "%s, initialement prévue le %s, aura lieu le %s." % [fixture, previous_date, new_date]
		match notice.status:
			"pending": text += "\n\nTu peux recaler les séances à venir sur la nouvelle date ou conserver la préparation prévue."
			"recalibrated": text += "\n\nLa préparation a été recalée."
			"kept": text += "\n\nLa préparation prévue a été conservée."
			"superseded": text += "\n\nUn courrier plus récent indique la nouvelle date."
			"expired": text += "\n\nCette rencontre ne permet plus de modifier la préparation."
		messages.push_front({
			"id":notice.id, "subject":"Changement de date", "text":text, "category":"Compétitions",
			"route":"Calendrier", "position":source.size()+index+1, "calendar_notice":notice
		})
	# Courrier du club (club-mail.cjs) : les plus récents en tête.
	if not national:
		for item: Dictionary in ClubMail.messages(app.model): messages.push_front(item)
		# Invitations du club (entretiens, moments au club) : des messages à faire, comme le courrier du club.
		var scenes: Array = app.model.get("clubLife", {}).get("sceneInvitations", {}).get("invitations", [])
		for index in range(scenes.size() - 1, -1, -1):
			var scene: Dictionary = scenes[index]
			if scene.get("status") != "pending" or not scene.get("available", false): continue
			var reason := str(scene.get("reason", "")).strip_edges()
			messages.push_front({
				"id":"invitation:" + str(scene.id), "subject":str(scene.get("title", "Invitation du club")),
				"text":reason if not reason.is_empty() else "Le club t'invite à un moment de rencontre.",
				"category":"Club", "route":"Bureau", "position":200000 + index, "scene_invitation":scene
			})
	var press: Dictionary = app.model.get("clubLife", {}).get("press", {})
	var invitations: Array = [] if national else press.get("invitations", [])
	for index in range(invitations.size() - 1, -1, -1):
		var invitation: Dictionary = invitations[index]
		var context: Dictionary = invitation.context
		var subject: String = {
			"arrival":"Présentation à la presse", "knockout":"Conférence de phase finale",
			"season_review":"Conférence de bilan", "weekly":"Conférence de la semaine"
		}.get(invitation.kind, "Invitation de presse")
		var detail := "%s · Saison %s · Semaine %d." % [Press._club(app, context.club), SeasonLabel.label(context.season), int(context.week) + 1]
		match invitation.status:
			"pending": detail += "\n\nLes journalistes t’attendent. Publie tes réponses pour poursuivre."
			"published": detail += "\n\nTes réponses ont été publiées."
			"expired": detail += "\n\nCe rendez-vous est passé."
		messages.push_front({
			"id":invitation.id, "subject":subject, "text":detail, "category":"Compétitions",
			"route":"Presse", "position":messages.size() + 1, "press_invitation":invitation
		})
	var events := international_mail(app.model)
	for index in range(events.size() - 1, -1, -1):
		var event := events[index]
		messages.push_front({
			"id":"international:" + event.id, "subject":str(event.get("title", "Sélections internationales")),
			"text":str(event.get("body", "")), "category":"Compétitions",
			"position":messages.size() + 1, "international_event":event
		})
	_assign_hours(messages)
	return messages

## Ordre d'arrivée dans une journée : courrier du club par numéro, puis les autres courriers datés (stable).
static func _arrival(message: Dictionary) -> float:
	# Courrier du club : le plus important du jour en tête (réponse attendue, puis info, puis routine ; moteur :
	# club-mail.cjs « importance »), puis l'ordre d'arrivée.
	if message.has("club_mail"):
		var mail: Dictionary = message.club_mail
		return float(int(mail.get("importance", 0))) * 1000000.0 + float(str(message.id).trim_prefix("mail-").to_int())
	return -1000.0 + float(absi(hash(str(message.id))) % 1000)

## Heure de réception (heure de jeu plausible et stable) : les courriers d'un même jour s'échelonnent de 7 h 30
## à 21 h 40 dans leur ordre d'arrivée ; quelques minutes dérivées de l'identifiant évitent les heures rondes.
static func _assign_hours(messages: Array) -> void:
	var days := {}
	for message: Dictionary in messages:
		var day := _day(message)
		if day.is_empty(): continue
		if not days.has(day): days[day] = []
		days[day].append(message)
	for day: String in days:
		var list: Array = days[day]
		list.sort_custom(func(a: Dictionary, b: Dictionary): return _arrival(a) < _arrival(b) or (_arrival(a) == _arrival(b) and str(a.id) < str(b.id)))
		var step := minf(95.0, 830.0 / maxf(1.0, list.size()))
		for index in list.size():
			var minutes := mini(450 + roundi(index * step) + absi(hash(str(list[index].id))) % mini(25, maxi(1, roundi(step) - 1)), 21 * 60 + 40)
			list[index].hour = "%02d:%02d" % [minutes / 60, minutes % 60]
			list[index].arrival = index

static func _is_season_expiry_mail(message: String) -> bool:
	# Les courriers historiques du moteur ne contiennent ni type ni identifiants de joueurs.
	var count := message.get_slice(" ", 0).to_int()
	if count <= 0: return false
	var normalized := message.replace("’", "'")
	for template: String in SEASON_EXPIRY_MAILS:
		if normalized == (template % count): return true
	return false

## Photo d'en-tête d'un courrier : résultat du match, finale, titre ou relégation (banque d'images) ;
## sinon la pelouse habituelle.
static func photo_resultat(texte: String) -> String:
	var f := U.fold(texte)
	var id := ""
	if "relegu" in f or "descente en" in f: id = "resultat-relegation"
	elif "champion" in f and ("sacre" in f or "titre" in f): id = "resultat-titre-trophee-leve"
	elif f.begins_with("victoire"): id = "resultat-finale-gagnee" if "finale" in f else ("resultat-bonus-offensif" if "bonus offensif" in f else "resultat-victoire")
	elif f.begins_with("defaite"): id = "resultat-finale-perdue" if "finale" in f else "resultat-defaite"
	elif f.begins_with("match nul"): id = "resultat-nul"
	if id.is_empty(): id = BanqueImages.courrier(texte)
	return id if not id.is_empty() and BanqueImages.texture(id) != null else "mail-pitch"

static func _category(message: String) -> String:
	if "blesse" in message or "indisponibilite" in message or "medical" in message: return "Médical"
	if "espoir" in message or "formation" in message or "promu" in message: return "Formation"
	if "recrutement" in message or "mercato" in message or "transfert" in message: return "Recrutement"
	if "contrat" in message or "direction" in message or "president" in message or "tresorerie" in message or "billetterie" in message: return "Direction"
	if "entrainement" in message or "vestiaire" in message or "preparation" in message: return "Staff"
	if message.begins_with("victoire") or message.begins_with("defaite") or message.begins_with("match nul") or "classement" in message: return "Compétitions"
	return "Club"

static func unread(app: Control) -> int:
	var marks: Dictionary = _state(app).marks
	return _messages(app).filter(func(message: Dictionary): return not marks.get(message.id, {}).get("read", false)).size()

## Jour de réception connu (AAAA-MM-JJ) : courrier du club, sélections, avis du calendrier, invitations ; "" sinon.
static func _day(message: Dictionary) -> String:
	for key in ["club_mail", "international_event", "calendar_notice", "scene_invitation"]:
		var source: Variant = message.get(key)
		if source is Dictionary and source.get("date") is String and str(source.date).length() >= 10: return str(source.date).left(10)
	return ""

static func _unix(day: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(day + "T12:00:00"))

static func _shift(day: String, days: int) -> String:
	return Time.get_date_string_from_unix_time(_unix(day) + days * 86400)

## « mar. 26 août » (année si elle diffère de l'année en cours de la partie).
static func _short_date(day: String, today: String = "", weekday: bool = true) -> String:
	if day.length() < 10: return ""
	var parts := day.split("-")
	var stamp := Time.get_datetime_dict_from_unix_time(_unix(day))
	var caption := "%d %s" % [int(parts[2]), MONTHS[clampi(int(parts[1]) - 1, 0, 11)]]
	if weekday: caption = DAYS[int(stamp.weekday)] + " " + caption
	if today.length() >= 4 and today.left(4) != day.left(4): caption += " " + day.left(4)
	return caption

static func _today(app: Control) -> String:
	return str(app.model.get("meta", {}).get("calendarToday", ""))

## En-tête de section de la liste : priorités épinglées, puis « AUJOURD'HUI », « HIER », date, ou plus ancien.
static func _section(app: Control, message: Dictionary, pinned: bool) -> String:
	if pinned: return "À TRAITER EN PRIORITÉ"
	var day := _day(message)
	if day.is_empty(): return "PLUS TÔT"
	var today := _today(app)
	if day == today: return "AUJOURD'HUI"
	if today.length() >= 10 and day == _shift(today, -1): return "HIER"
	return _short_date(day, today).to_upper()

## Ordre d'affichage de la boîte (et du raccourci Espace) : rendez-vous de presse et urgences épinglés, puis le reste
## groupé par jour (plus récent d'abord, ou plus ancien avec le tri inverse), ordre d'arrivée conservé dans un jour,
## messages sans date à la fin. `pinned` : nombre de messages épinglés en tête.
static func _display_order(app: Control, visible: Array, state: Dictionary) -> Dictionary:
	var marks: Dictionary = state.marks
	var priority := _priority_ids(app.model)
	var mandatory := visible.filter(func(message: Dictionary): return message.has("press_invitation") and message.id in priority)
	var urgent := visible.filter(func(message: Dictionary):
		return (message.id in priority and not message.has("press_invitation")
			and (not message.has("international_event") or not marks.get(message.id, {}).get("read", false))))
	var pinned: Array = mandatory + urgent
	var buckets := {}
	var undated: Array = []
	for message: Dictionary in visible:
		if message in pinned: continue
		var day := _day(message)
		if day.is_empty(): undated.append(message); continue
		if not buckets.has(day): buckets[day] = []
		buckets[day].append(message)
	var days: Array = buckets.keys()
	days.sort()
	if not state.get("oldest_first", false): days.reverse()
	var ordered: Array = pinned.duplicate()
	if state.get("oldest_first", false): ordered.append_array(undated)
	for day in days:
		var bucket: Array = buckets[day]
		bucket.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("arrival", 0)) < int(b.get("arrival", 0)) if state.get("oldest_first", false) else int(a.get("arrival", 0)) > int(b.get("arrival", 0)))
		ordered.append_array(bucket)
	if not state.get("oldest_first", false): ordered.append_array(undated)
	return {"items":ordered, "pinned":pinned.size()}

## Lignes de la liste : fils regroupés, et courriers d'information identiques consécutifs (même expéditeur, même objet,
## même jour) réunis en une ligne « ×N » représentée par le plus récent (`members` : identifiants réunis).
static func _entries(app: Control, items: Array, pinned: int, oldest_first: bool) -> Array:
	var pinned_ids := items.slice(0, pinned).map(func(message: Dictionary): return message.id)
	var result: Array = []
	for group: Dictionary in Reading.groups(items):
		var linked: Array = group.messages
		var section := _section(app, linked[0], linked[0].id in pinned_ids)
		if linked.size() == 1 and not result.is_empty():
			var last: Dictionary = result[-1]
			if last.single and last.section == section and _same(app, last.messages[0], linked[0]):
				last.messages.append(linked[0])
				continue
		result.append({"section":section, "key":group.key, "messages":linked.duplicate(), "single":linked.size() == 1})
	for entry: Dictionary in result:
		entry.collapsed = entry.single and entry.messages.size() > 1
		if entry.collapsed:
			var representative: Dictionary = entry.messages[-1] if oldest_first else entry.messages[0]
			representative.members = entry.messages.map(func(message: Dictionary): return str(message.id))
			entry.messages = [representative]
	return result

static func _same(app: Control, a: Dictionary, b: Dictionary) -> bool:
	if Reading.status(a, app.model).key == "todo" or Reading.status(b, app.model).key == "todo": return false
	return _sender(app, a) == _sender(app, b) and str(a.get("subject", _subject(str(a.text)))) == str(b.get("subject", _subject(str(b.text))))

## Identifiants représentés par une ligne (elle-même, ou tous les courriers réunis sous « ×N »).
static func members(message: Dictionary) -> Array:
	return message.get("members", [str(message.get("id", ""))])

static func _any_unread(marks: Dictionary, message: Dictionary) -> bool:
	return members(message).any(func(id: String): return not marks.get(id, {}).get("read", false))

## Ordre d'affichage du dossier « Tous » (messages non archivés), une entrée par ligne de la liste : celui de la liste
## et de `next_unread` (bouton « Courrier suivant non lu »).
static func display_order(app: Control) -> Array:
	var state := _state(app)
	var view := {"marks":state.marks, "oldest_first":state.oldest_first}
	var visible := _messages(app).filter(func(message: Dictionary): return not state.marks.get(message.id, {}).get("archived", false))
	if state.oldest_first: visible.reverse()
	var order := _display_order(app, visible, view)
	var result: Array = []
	for entry: Dictionary in _entries(app, order.items, int(order.pinned), state.oldest_first): result.append_array(entry.messages)
	return result

## Prochain message non lu, dans l'ordre d'affichage de la boîte (priorités en tête, jours, fils, lignes « ×N »).
## Dictionnaire vide s'il n'en reste aucun. Sert au raccourci Espace (ui/raccourcis_clavier.gd).
static func next_unread(app: Control, skip_id: String = "") -> Dictionary:
	var marks: Dictionary = _state(app).marks
	for message: Dictionary in display_order(app):
		if str(message.get("id", "")) == skip_id: continue
		if _any_unread(marks, message): return message
	return {}

## Ouvre le prochain message non lu : même effet qu'un clic sur sa ligne (sélection, marqué lu), dossier et filtres remis à « Tous ».
static func open_next_unread(app: Control, skip_id: String = "") -> bool:
	var message := next_unread(app, skip_id)
	if message.is_empty(): return false
	var state := _state(app)
	state.folder = 0
	state.category = "Tous"
	state.activity_filter = "all"
	state.selected = message.id
	state.press_opened = message.id if message.has("press_invitation") else ""
	state.expanded_threads[Reading.thread_key(message)] = true
	state.scroll = 0
	_mark_members(state, message, "read", true)
	if app.route == "Réception": app._render()
	else: app._navigate("Réception")
	return true

## Courriers d'information non lus parmi `messages` : jamais une décision (« À faire », « En attente »),
## ni une priorité (invitation de presse ou avis de calendrier en attente, courrier de sélection).
static func markable_read(app: Control, messages: Array) -> Array[Dictionary]:
	var marks: Dictionary = _state(app).marks
	var priority := _priority_ids(app.model)
	var result: Array[Dictionary] = []
	for message: Dictionary in messages:
		if marks.get(message.id, {}).get("read", false) or message.id in priority: continue
		if message.get("press_invitation", {}).get("status") == "pending" or message.get("calendar_notice", {}).get("status") == "pending": continue
		if Reading.status(message, app.model).key == "info": result.append(message)
	return result

## État d'interface de session (mêmes marques que l'ouverture d'un courrier) : aucune commande moteur.
static func mark_all_read(app: Control, messages: Array) -> int:
	var marks: Dictionary = _state(app).marks
	var targets := markable_read(app, messages)
	for message: Dictionary in targets:
		var mark: Dictionary = marks.get(message.id, {})
		mark.read = true
		marks[message.id] = mark
	return targets.size()

static func _tasks(app: Control) -> Array:
	var tasks := []
	if app.Immersive.Selections.nation_only(app.model): return tasks
	if not app.model.get("selection", {}).get("valid", false): tasks.append(["Compléter la feuille de match", "Composition"])
	if not app.model.get("meta", {}).get("trained", false): tasks.append(["Organiser la charge de la semaine", "Entraînement"])
	var contracts := P.contracts_ending(app.model)
	if not contracts.is_empty(): tasks.append(["Examiner %s de contrat en fin de saison" % P.plural(contracts.size(), "échéance", "échéances"), "Effectif"])
	if P.group(app.model).injured > 0: tasks.append(["Consulter les indisponibilités de l’effectif", "Effectif"])
	var reports: Array = app.model.get("decisions", {}).get("recruitment", {}).get("reports", [])
	if not reports.is_empty(): tasks.append(["Consulter %s de recrutement" % P.plural(reports.size(), "rapport", "rapports"), "Recrutement"])
	return tasks

static func heading(row: Control, app: Control) -> Label:
	# Même hiérarchie que les autres pages (Bureau, Effectif) : surtitre, grand titre, puis l'état de la boîte.
	# Maquette : « RÉCEPTION. » en capitales italiques, compteurs sur la même ligne, « ! N urgent » en rouge ; pas de surtitre.
	var title := D.text(row,-1,58,"RÉCEPTION.",50,C.IVORY,800,520)
	title.add_theme_font_override("font", C.Charte.TITRE_EXTRA_ITALIQUE)
	title.name = "InboxPageTitle"
	var messages := _messages(app)
	var counts := Reading.counts(messages,app.model)
	var x := C.Charte.TITRE_EXTRA_ITALIQUE.get_string_size("RÉCEPTION.", HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x + 26.0
	var line := "%d non lus · %d à faire" % [unread(app),counts.todo]
	D.text(row,x,56,line,19,C.MUTED,500,560).name = "InboxPageCounts"
	if counts.urgent > 0:
		var after := x + C.font(500).get_string_size(line + " · ", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		D.text(row,after,56,"! %d urgent%s" % [counts.urgent, "" if counts.urgent == 1 else "s"],19,C.ALERT,700,260).name = "InboxPageUrgent"
	# En haut à droite : volume de la semaine, archives et « Tout lu » (agit sur les courriers d'information).
	var today := _unix(_today(app))
	var week := messages.filter(func(message: Dictionary) -> bool:
		var day := _day(message)
		return not day.is_empty() and today - _unix(day) <= 7 * 86400 and today - _unix(day) >= 0).size()
	var state := _state(app)
	var archived := messages_archived(app)
	var pending := markable_read(app, messages).size()
	# Volume de la semaine et archives en tuiles (gros chiffre + légende) ; les archives ouvrent leur dossier.
	var bandeau := C.h(10)
	bandeau.name = "InboxPageVolume"
	bandeau.add_child(Pastilles.tuile(str(week), "cette semaine", C.Charte.MORAL, C.Charte.PANNEAU_2, 26, "InboxPageWeekTile", true))
	var ouvrir_archives := func():
		state.folder = 3
		state.category = "Tous"
		state.activity_filter = "all"
		state.scroll = 0
		_redraw(app, "InboxFolder3")
	bandeau.add_child(Pastilles.tuile(str(archived), "archivé" if archived < 2 else "archivés", C.Charte.IVOIRE if archived == 0 else C.Charte.REPOS, C.Charte.PANNEAU_2, 26, "InboxPageArchiveTile", true, Callable() if archived == 0 else ouvrir_archives))
	var all_read := C.button("Tout lu ✓" if pending > 0 else "Tout est lu", func():
		mark_all_read(app, _messages(app))
		_redraw(app, "InboxMarkAllRead"), false, app.accent)
	all_read.name = "InboxMarkAllRead"
	C.style_bouton_lien(all_read, 19)
	all_read.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	all_read.disabled = pending == 0
	all_read.tooltip_text = "Tout marquer comme lu : les courriers d'information ; les décisions à prendre restent à faire."
	bandeau.add_child(all_read)
	Pastilles.poser_a_droite(row, bandeau, PAGE.x - 24, 50)
	return title


static func build(app: Control) -> Control:
	var page := Control.new()
	page.name = "ImmersiveInbox"
	var state := _state(app)
	var height := _height(state)
	page.custom_minimum_size = Vector2(PAGE.x, height)*C.density
	C.fill(page,true)
	var messages := _messages(app)
	var marks: Dictionary = state.marks
	var active := messages.map(func(message: Dictionary): return message.id)
	for id in marks.keys():
		if id not in active: marks.erase(id)
	var unfiltered := messages.filter(func(message: Dictionary): return _visible(message,state))
	var selected: Array = unfiltered.filter(func(message: Dictionary): return message.id == state.selected)
	if state.activity_filter != "all" and not selected.is_empty() and Reading.status(selected[0], app.model).key != state.activity_filter:
		state.activity_filter = "all" # A newly selected priority stays visible after a model update.
	var visible := unfiltered.filter(func(message: Dictionary): return state.activity_filter == "all" or Reading.status(message, app.model).key == state.activity_filter)
	if state.oldest_first: visible.reverse()
	var order := _display_order(app, visible, state)
	var entries := _entries(app, order.items, int(order.pinned), state.oldest_first)
	visible = []
	for entry: Dictionary in entries:
		visible.append_array(entry.messages)
		if entry.collapsed and state.selected in entry.messages[0].members: state.selected = entry.messages[0].id
	if not visible.any(func(message: Dictionary): return message.id == state.selected):
		var ordinary := visible.filter(func(message: Dictionary): return not message.has("press_invitation"))
		state.selected = "" if ordinary.is_empty() else ordinary[0].id
	var current: Dictionary = {}
	for message: Dictionary in visible:
		if message.id == state.selected: current=message; break
	var category_view: Dictionary = state.duplicate()
	category_view.category = "Tous"
	var list := _surface(page,Rect2(0,0,LIST_WIDTH,height),"InboxMessages")
	_list_filters(list, app, state, messages.filter(func(item: Dictionary): return not state.marks.get(item.id, {}).get("archived", false)), messages.filter(func(item: Dictionary): return _visible(item,category_view)))
	_list(list,app,state,visible,entries)
	# Variante « Liste et lettre » : deux colonnes seulement. Plus de panneau fixe à droite : les joueurs, clubs et
	# rencontres cités sont des liens dans la lettre et sous elle (mini-fiche au survol d'un joueur).
	_w = DETAIL_WIDTH
	_detail(_surface(page,Rect2(LIST_WIDTH+GAP,0,_w,height),"InboxDetail"),app,state,current,height)
	if state.get("return_focus", false):
		state.return_focus = false
		_restore_reading.call_deferred(page, state)
	_fit.call_deferred(app, page)
	return page

## Fond d'une colonne (palette du jeu) : liste et mail sur le vert sombre, panneau « Concerné » un ton plus bas.
static func _surface(parent: Control, area: Rect2, id: String, darker: bool = false) -> Panel:
	var card := Panel.new()
	card.name = id
	card.add_theme_stylebox_override("panel", C.Charte.ombrer_droit(C.box(C.BG if darker else C.PANEL, Color(C.LINE,.55), 0, 0)))
	parent.add_child(card)
	D.place(card, area)
	card.clip_contents = true
	C.Charte.ombre_derriere(card) # le panneau rogne son contenu : l'ombre passe à un calque frère
	return card

## Hauteur d'une rangée de boutons : gabarit approuvé, sans descendre sous la hauteur minimale réelle d'un bouton
## (police plancher de 12 px) quand la fenêtre est petite.
static func _h(base: float) -> float:
	return maxf(base, 32.0 / C.density)

## Ordonnées de l'en-tête de liste : rangée de filtres, puis filet au-dessus des messages.
static func _header_rows() -> Array[float]:
	var filters := 16.0
	return [filters, filters + _h(44) + 12]

## En tête de la liste : une seule rangée (Tous · Non lus · À faire) et un menu « Sujet » qui regroupe
## les services, les favoris, les archives et les états rares (En attente, Infos).
static func _list_filters(card: Panel, app: Control, state: Dictionary, active: Array, all_subjects: Array) -> void:
	var todo: int = Reading.counts(active, app.model).todo
	# [légende, nom du bouton, dossier, état, infobulle]
	var filters := [
		["Tous", "InboxFolder0", 0, "all", "Tous les messages"],
		["Non lus %d" % unread(app), "InboxFolder1", 1, "all", "Messages non lus"],
		["À faire %d" % todo, "InboxActivity_todo", 0, "todo", Reading.LABELS.todo + ". Les messages sans décision explicite restent des informations."],
	]
	# Pastilles à la taille de leur texte, menu « Sujet » sur le reste de la rangée (aucun recouvrement en petite fenêtre).
	var bar := C.h(8)
	bar.name = "InboxFilterRow"
	card.add_child(bar)
	D.place(bar, Rect2(14,_header_rows()[0],LIST_WIDTH-28,_h(44)))
	for index in filters.size():
		var filter: Array = filters[index]
		var folder: int = filter[2]
		var activity: String = filter[3]
		var id: String = filter[1]
		var chosen: bool = state.folder == folder and state.activity_filter == activity
		var action := C.button(filter[0], func():
			state.folder = folder
			state.activity_filter = activity
			state.category = "Tous"
			if activity != "all": state.selected = ""
			state.scroll = 0
			_redraw(app,id), false, app.accent)
		action.name = id
		action.alignment = HORIZONTAL_ALIGNMENT_CENTER
		action.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
		action.custom_minimum_size = Vector2(C.px(84), 0)
		for look in ["normal", "hover", "pressed", "focus"]:
			# Charte finale : filtre actif = pilule en aplat crème, texte panneau ; inactif = pilule à contour.
			var pill := C.box(C.IVORY if chosen else C.RAISED if look == "hover" else Color(C.PANEL, 0), C.Charte.OR if look == "focus" else Color.TRANSPARENT if chosen else C.LINE, C.Charte.RAYON_PILULE, 16)
			pill.content_margin_top = 0; pill.content_margin_bottom = 0
			action.add_theme_stylebox_override(look, pill)
		action.tooltip_text = filter[4]
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			action.add_theme_color_override(key, C.Charte.PANNEAU if chosen else C.Charte.IVOIRE)
		bar.add_child(action)
	var subject := OptionButton.new()
	subject.name = "InboxSubject"
	subject.fit_to_longest_item = false
	subject.clip_text = true
	subject.add_theme_font_override("font",C.BOLD)
	subject.add_theme_font_size_override("font_size",maxi(12,C.px(18)))
	subject.tooltip_text = "Sujet : services du club, favoris, archives, messages en attente ou d'information"
	var entries: Array = []
	for category: String in SUBJECTS:
		var count := all_subjects.size() if category == "Tous" else all_subjects.filter(func(message: Dictionary): return message.category == category).size()
		entries.append({"kind":"category", "value":category, "label":("Tous les sujets" if category == "Tous" else category) + " (%d)" % count, "short":"Sujet : tous" if category == "Tous" else "Sujet : " + category})
	var chosen_entry := -1
	for index in entries.size():
		if entries[index].kind == "category" and entries[index].value == state.category: chosen_entry = index
	var extra_selected: bool = state.folder != 3 and state.activity_filter in ["waiting", "info"]
	for index in entries.size():
		subject.add_item(entries[index].label, index)
	subject.add_separator()
	var statuses := {"waiting":Reading.counts(active, app.model).waiting, "info":Reading.counts(active, app.model).info}
	for extra: Array in SUBJECT_EXTRAS:
		var count_text := ""
		match extra[0]:
			"archives": count_text = " (%d)" % messages_archived(app)
			"favorites": count_text = " (%d)" % active.filter(func(item: Dictionary): return state.marks.get(item.id, {}).get("favorite", false)).size()
			_: count_text = " (%d)" % statuses[extra[0]]
		entries.append({"kind":extra[0], "value":extra[0], "label":str(extra[1]) + count_text, "short":"Sujet : " + str(extra[1])})
		subject.add_item(entries[-1].label, entries.size() - 1)
		if (extra[0] == "archives" and state.folder == 3) or (extra[0] == "favorites" and state.folder == 2) or (extra[0] in ["waiting", "info"] and extra_selected and state.activity_filter == extra[0]): chosen_entry = entries.size() - 1
	subject.select(subject.get_item_index(maxi(chosen_entry, 0)))
	subject.text = entries[maxi(chosen_entry, 0)].short
	subject.item_selected.connect(func(index: int):
		var entry: Dictionary = entries[subject.get_item_id(index)]
		match entry.kind:
			"category":
				state.category = entry.value
				if state.folder >= 2: state.folder = 0
				if state.activity_filter in ["waiting", "info"]: state.activity_filter = "all"
			"archives", "favorites":
				state.folder = 3 if entry.kind == "archives" else 2
				state.category = "Tous"
				state.activity_filter = "all"
			_:
				state.folder = 0
				state.activity_filter = entry.kind
				state.selected = ""
		state.scroll = 0
		_redraw(app,"InboxSubject"))
	# Menu aux jetons de la charte : fond sombre, bordure fine, rayon 0, texte ivoire ; la fenêtre du menu suit.
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var skin := C.box(C.RAISED if look in ["hover", "pressed"] else C.PANEL, C.IVORY if look == "focus" else C.LINE, 0, 10)
		subject.add_theme_stylebox_override(look, skin)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: subject.add_theme_color_override(key, C.IVORY)
	var menu := subject.get_popup()
	menu.add_theme_stylebox_override("panel", C.box(C.PANEL, C.LINE, 0, 6))
	menu.add_theme_stylebox_override("hover", C.box(C.SELECTED, Color.TRANSPARENT, 0, 6))
	menu.add_theme_font_override("font", C.BODY)
	menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for key in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(key, C.IVORY)
	menu.add_theme_color_override("font_separator_color", C.FAINT)
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject.custom_minimum_size.x = C.px(120)
	bar.add_child(subject)

static func _list(card: Panel, app: Control, state: Dictionary, messages: Array, entries: Array) -> void:
	var top := _header_rows()[1]
	D.line(card,Vector2(0,top),Vector2(LIST_WIDTH,top),Color(C.LINE,.6))
	var scroll := ScrollContainer.new()
	scroll.name = "InboxMessageScroll"
	scroll.tooltip_text = "↑ ↓ choisir · Entrée ouvrir le courrier"
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(0,top+1,LIST_WIDTH,_height(state)-top-2))
	var rows := C.v(0)
	rows.name = "InboxMessageRows"
	C.fill(rows)
	scroll.add_child(rows)
	if messages.is_empty():
		D.text(card,26,top+52,"Aucun message dans cette vue.",24,C.MUTED,600,LIST_WIDTH-52)
		D.text(card,26,top+90,"Choisis un autre filtre.",19,C.MUTED,400,LIST_WIDTH-52,HORIZONTAL_ALIGNMENT_LEFT,true)
	var section := ""
	var sections := 0
	for entry: Dictionary in entries:
		var linked: Array = entry.messages
		if entry.section != section:
			section = entry.section
			_day_heading(rows, section, sections)
			sections += 1
		if linked.size() > 1:
			var default_open: bool = linked.any(func(item: Dictionary): return item.id == state.selected or Reading.status(item, app.model).key == "todo")
			var opened: bool = state.expanded_threads.get(entry.key, default_open)
			var title: String = str(linked[0].get("subject",linked[0].category))
			var notice: Dictionary = linked[0].get("calendar_notice",{})
			if not str(notice.get("opponent","")).is_empty(): title += " · " + str(notice.opponent)
			var context: Dictionary = linked[0].get("press_invitation",{}).get("context",{})
			if context.has_all(["season","week"]): title += " · %s / sem. %d" % [SeasonLabel.label(context.season),int(context.week)+1]
			var group_id := "InboxThread_" + str(entry.key).sha256_text().left(12)
			var key: String = entry.key
			var toggle := C.button(("▾ " if opened else "▸ ") + "%s · %d courriers" % [title,linked.size()], func():
				state.expanded_threads[key] = not opened
				_redraw(app, group_id), false, app.accent)
			toggle.add_theme_font_size_override("font_size", maxi(12, C.px(17)))
			toggle.custom_minimum_size.y = C.px(38)
			toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
			toggle.clip_text = true
			toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			toggle.name = group_id
			toggle.set_meta("thread_key", key)
			toggle.tooltip_text = "Déplier ou réduire les courriers de la même rencontre, édition ou conférence"
			toggle.add_theme_stylebox_override("normal", C.box(Color(C.PANEL, 0), Color(C.LINE, .35), 0, 16))
			rows.add_child(toggle)
			if not opened: continue
		for item: Dictionary in linked: _row(rows, app, state, item)
	_blocking_notice(rows, app)
	scroll.set_deferred("scroll_vertical",int(state.scroll))

## Marque (lu, favori, archivé) tous les courriers représentés par une ligne.
static func _mark_members(state: Dictionary, message: Dictionary, key: String, value: bool) -> void:
	for id: String in members(message):
		var mark: Dictionary = state.marks.get(id, {})
		mark[key] = value
		if key == "archived": mark.read = true
		state.marks[id] = mark

## En-tête de jour dans la liste (« AUJOURD'HUI », « HIER », date).
static func _day_heading(rows: Control, caption: String, index: int) -> void:
	var box := MarginContainer.new()
	box.name = "InboxDay_%d" % index
	box.add_theme_constant_override("margin_left", C.px(22))
	box.add_theme_constant_override("margin_top", C.px(16 if index > 0 else 10))
	box.add_theme_constant_override("margin_bottom", C.px(6))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := C.label(caption, 18, C.FAINT.lightened(.15), true, 700)
	label.name = "InboxDayLabel"
	box.add_child(label)
	rows.add_child(box)

## Échéance d'un courrier qui attend une action ("" sinon) : forme courte pour la liste, longue pour le panneau.
static func _deadline(app: Control, message: Dictionary, long: bool = false) -> String:
	var today := _today(app)
	var mail: Dictionary = message.get("club_mail", {})
	if not mail.is_empty() and ClubMail.awaiting(app.model, mail) and str(mail.get("categorie", "")) != "meteo" and str(mail.get("date", "")).length() >= 10:
		var limit := _shift(str(mail.date).left(10), DELAI_REPONSE)
		return ("Réponds avant le %s : sans réponse, le dossier sera classé." if long else "avant le %s") % _short_date(limit, today, long)
	var notice: Dictionary = message.get("calendar_notice", {})
	if notice.get("status") == "pending" and str(notice.get("toDate", "")).length() >= 10:
		return ("Décide avant la rencontre du %s." if long else "avant le %s") % _short_date(str(notice.toDate), today, long)
	var reading := Reading.status(message, app.model)
	if reading.key == "todo" and message.has("press_invitation") and reading.urgent:
		return "Rendez-vous obligatoire : à tenir avant de continuer." if long else "avant de continuer"
	if reading.key == "todo" and message.has("international_event") and reading.urgent:
		return "Jour de match : la rencontre de ta sélection attend ta décision." if long else "jour de match"
	return ""

## Une ligne de la liste, sur deux lignes : icône du service, « SERVICE · expéditeur », objet (gras si non lu),
## étiquette dorée « À FAIRE · échéance » si une action est attendue, point doré si non lu.
static func _row(rows: Control, app: Control, state: Dictionary, message: Dictionary) -> void:
	var id := _row_id(message)
	var selected: bool = message.id==state.selected
	var mark: Dictionary = state.marks.get(message.id,{})
	var is_unread: bool = _any_unread(state.marks, message)
	var count := members(message).size()
	var reading := Reading.status(message, app.model)
	var tagged: bool = reading.key == "todo" or reading.urgent
	var height := 104.0 if tagged else 80.0
	var row := C.button("",func():
		state.selected=message.id
		state.press_opened=message.id if message.has("press_invitation") else ""
		if state.folder!=1: _mark_members(state, message, "read", true)
		_redraw(app,id),false,app.accent)
	row.name = id
	row.gui_input.connect(_message_key.bind(app, message.id))
	row.custom_minimum_size = Vector2(LIST_WIDTH-16,height)*C.density
	row.tooltip_text = message.text
	row.set_meta("message_text",message.text)
	row.set_meta("message_id", message.id)
	row.set_meta("message_count", count)
	row.accessibility_name = "%s%s · %s · %s" % ["Non lu · " if is_unread else "", reading.label, message.get("subject",message.category), message.text]
	rows.add_child(row)
	var base := C.RAISED.lightened(.06) if selected else Color(C.PANEL,0)
	var style := C.box(base, Color.TRANSPARENT, 0, 0)
	style.border_color = Color(C.LINE,.35)
	style.border_width_bottom = 1
	row.add_theme_stylebox_override("normal", style)
	var hover := C.box(C.RAISED, Color.TRANSPARENT, 0, 0)
	row.add_theme_stylebox_override("hover", hover)
	if selected: D.rect(row,Rect2(0,0,5,height),C.GOLD,0).name = "SelectedEdge"
	var width := LIST_WIDTH - 16
	# Sujet en mot ET en symbole (la couleur ne porte jamais seule le signal) ; pastille ovale des non lus à gauche.
	var text_x := 42.0
	var right := 0.0
	var service := _service(message).to_upper()
	var service_color: Color = COLORS.get(_service(message), C.MUTED)
	var mark_icon := D.rect(row,Rect2(text_x,16,22,22),Color(service_color,.14),0)
	mark_icon.name = "SenderIcon"
	mark_icon.tooltip_text = _sender(app, message)
	_icon(mark_icon,SERVICE_ICONS.get(_service(message), "home"),Rect2(3,3,16,16),service_color)
	var hour := str(message.get("hour", ""))
	var meta_width := (84.0 if not hour.is_empty() else 0.0) + (30.0 if mark.get("favorite", false) else 0.0) + (54.0 if count > 1 else 0.0)
	# Service en petites capitales, expéditeur en casse normale juste après (sans point médian).
	var service_size := C.font(700).get_string_size(service, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 8.0
	D.text(row,text_x+30,32,service,15,C.MUTED,700,service_size)
	D.text(row,text_x+30+service_size,32,_sender(app,message),17,C.MUTED,500,width-text_x-30-service_size-20-right-meta_width)
	var meta_x := width - 20 - right
	if not hour.is_empty():
		D.text(row,meta_x,32,hour,16,C.FAINT.lightened(.2),500,80,HORIZONTAL_ALIGNMENT_RIGHT,true).name = "InboxRowHour"
		meta_x -= 86
	if mark.get("favorite",false):
		_icon(row,"star",Rect2(meta_x-18,15,18,18),C.GOLD)
		meta_x -= 28
	if count > 1:
		var badge := D.rect(row,Rect2(meta_x-48,12,46,24),Color(C.MUTED,.12),12,Color(C.MUTED,.5))
		badge.name = "InboxRowCount"
		D.text(badge,23,18,"×%d" % count,15,C.IVORY,700,44,HORIZONTAL_ALIGNMENT_CENTER)
	if is_unread:
		var dot := D.rect(row,Rect2(16,22,14,9),C.IVORY,5)
		dot.name = "UnreadDot"
	D.text(row,text_x,62,message.get("subject",_subject(message.text)),21,C.IVORY if is_unread else Color(C.IVORY,.62),700 if is_unread else 500,width-text_x-20)
	if tagged:
		var due := _deadline(app, message)
		var caption := ("! URGENT" if reading.urgent else "À FAIRE") + ("" if due.is_empty() else " · " + due.to_upper())
		var tone: Color = C.ALERT if reading.urgent else C.GOLD
		var font := C.font(700)
		var tag_width := minf(width-text_x-20, font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(15))).x / C.density + 22)
		# Maquette : fond plein sombre sans cadre ; « ! URGENT » en rouge souligné (mot + symbole, jamais la couleur seule).
		var tag := D.rect(row,Rect2(text_x,72,tag_width,24),C.RAISED,0)
		tag.name = "InboxTodoTag"
		D.text(tag,11,18,caption,15,tone,700,tag_width-14)
		if reading.urgent: D.line(tag,Vector2(11,21),Vector2(tag_width-11,21),tone)

static func _height(state: Dictionary) -> float:
	return clampf(float(state.get("page_height", PAGE.y)), MIN_HEIGHT, PAGE.y)

## La boîte tient dans la hauteur visible de l'espace de travail : liste et pied du mail sans défilement de page.
## Une seule reconstruction quand la hauteur disponible change (taille de fenêtre, bandeau au-dessus de la boîte).
static func _fit(app: Control, page: Control) -> void:
	if is_instance_valid(page) and page.is_inside_tree():
		# Le nœud peut quitter l'arbre pendant la première attente (écran reconstruit) : l'arbre est gardé, pas relu.
		var tree := page.get_tree()
		await tree.process_frame
		if not is_instance_valid(page) or not page.is_inside_tree(): return
		await tree.process_frame
	if not is_instance_valid(page) or not page.is_inside_tree() or app.route != "Réception": return
	var workspace := app.body_scroll as Control
	if not is_instance_valid(workspace): return
	var available := (workspace.get_global_rect().end.y - page.get_global_rect().position.y - C.px(6)) / C.density
	var state := _state(app)
	var target := clampf(available, MIN_HEIGHT, PAGE.y)
	if absf(target - _height(state)) <= 4.0: return
	state.page_height = target
	app._render()

static func _visible(message: Dictionary, state: Dictionary) -> bool:
	if state.category != "Tous" and state.category != message.category: return false
	var mark: Dictionary = state.marks.get(message.id, {})
	var archived: bool = mark.get("archived", false)
	if state.folder == 3: return archived
	if archived: return false
	if state.folder == 1: return not mark.get("read",false)
	if state.folder == 2: return mark.get("favorite",false)
	return true

## Nombre de messages rangés dans les archives.
static func messages_archived(app: Control) -> int:
	var marks: Dictionary = _state(app).marks
	return _messages(app).filter(func(message: Dictionary): return marks.get(message.id, {}).get("archived", false)).size()

static func _open_related(app: Control, message: Dictionary, action: Callable) -> void:
	if message.is_empty():
		action.call()
		return
	var state := _state(app)
	state.selected = message.id
	state.expanded_threads[Reading.thread_key(message)] = true
	var scroll := app.root_content.find_child("InboxMessageScroll", true, false) as ScrollContainer
	if scroll != null: state.scroll = scroll.scroll_vertical
	state.return_focus = true
	action.call()

static func _restore_reading(page: Control, state: Dictionary) -> void:
	if not is_instance_valid(page) or not page.is_inside_tree(): return
	for row in page.find_children("*", "Button", true, false):
		if row.get_meta("message_id", "") == state.selected:
			row.grab_focus()
			var scroll := page.find_child("InboxMessageScroll", true, false) as ScrollContainer
			if scroll != null: scroll.set_deferred("scroll_vertical", int(state.scroll))
			return

## Rendez-vous obligatoire du club en cours (conférence de presse d'arrivée…), vide sinon.
static func _blocking(app: Control) -> Dictionary:
	return app.contextual_director.blocking_meeting() if is_instance_valid(app.contextual_director) else {}

## Notice en tête de la liste : un rendez-vous obligatoire passe avant tout le reste (#810), avec un accès direct.
static func _blocking_notice(rows: Control, app: Control) -> void:
	var blocking := _blocking(app)
	if blocking.is_empty(): return
	var notice := C.v(6)
	notice.name = "ContextualInvitationsBlocked"
	var why := C.wrap("Rendez-vous obligatoire : termine " + app.contextual_director.meeting_label(blocking) + " avant d'avancer et d'ouvrir les invitations du club.",17,C.GOLD)
	C.fill(why)
	notice.add_child(why)
	if blocking.get("kind") == "press" and not blocking.get("completed", false):
		var go := C.button("OUVRIR LA CONFÉRENCE DE PRESSE", func(): app._open_press_conference(), false, app.accent)
		go.name = "ContextualOpenPress"
		go.add_theme_font_size_override("font_size", C.px(17))
		notice.add_child(go)
	rows.add_child(notice)
	rows.move_child(notice, 0)

## Service expéditeur (clé de SERVICE_ICONS) : presse, sélections, calendrier, invitation ou catégorie du courrier.
static func _service(message: Dictionary) -> String:
	if message.has("press_invitation") or str(message.get("club_mail", {}).get("categorie", "")) == "presse": return "Presse"
	if message.has("international_event"): return "Sélections"
	if message.has("calendar_notice"): return "Calendrier"
	if message.has("scene_invitation"): return "Invitation"
	return str(message.get("category", "Club"))

## Joueur identifié qui signe le courrier (son nom est l'expéditeur) ; vide sinon.
static func _sender_player(app: Control, message: Dictionary) -> Dictionary:
	var mail: Dictionary = message.get("club_mail", {})
	if mail.is_empty() or not mail.get("joueur") is String or str(mail.joueur).is_empty(): return {}
	for player: Dictionary in app.model.get("squad", []):
		if str(player.get("id", "")) == str(mail.joueur):
			return player if not str(player.get("name", "")).is_empty() and str(mail.get("expediteur", "")).contains(str(player.name)) else {}
	return {}

## Pastille de l'expéditeur : icône du service dans la palette du jeu, ou vrai portrait d'une personne identifiée.
static func _sender_badge(parent: Control, app: Control, message: Dictionary, area: Rect2) -> void:
	var player := _sender_player(app, message)
	if not player.is_empty():
		var portrait := Portraits.portrait(int(player.get("portraitIndex",0)),C.px(area.size.x),player)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(portrait); D.place(portrait,area)
		return
	var service := _service(message)
	var color: Color = COLORS.get(service, C.GOLD if service in ["Presse", "Sélections", "Calendrier", "Invitation"] else C.MUTED)
	var tile := D.rect(parent,area,Color(color,.12),8,Color(color,.5))
	tile.name = "SenderIcon"
	tile.tooltip_text = _sender(app, message)
	_icon(tile,SERVICE_ICONS.get(service, "home"),Rect2(area.size.x*.2,area.size.y*.2,area.size.x*.6,area.size.y*.6),color)

## Expéditeur du courrier, pour la liste et l'en-tête du mail ouvert.
static func _sender(app: Control, message: Dictionary) -> String:
	if message.has("club_mail"): return str(message.club_mail.get("expediteur", SENDERS.Club))
	if message.has("scene_invitation"): return SENDERS.Club
	if message.has("press_invitation"): return "Service de presse"
	if message.has("international_event"): return "Sélections" if not app.Immersive.Selections.nation_only(app.model) else "Fédération"
	if message.has("calendar_notice"): return "Calendrier des compétitions"
	return SENDERS.get(message.get("category","Club"), SENDERS.Club)

## Date de réception connue (courrier du club, sélections, presse) ; vide pour les anciens messages du moteur.
static func _date(message: Dictionary) -> String:
	if message.has("club_mail"): return P.fixture_date({"date":message.club_mail.get("date")})
	if message.has("international_event"): return P.fixture_date({"date":message.international_event.get("date")})
	var context: Dictionary = message.get("press_invitation",{}).get("context",{})
	if context.has_all(["season","week"]): return "Sem. %d" % (int(context.week)+1)
	return ""

static func _row_id(message: Dictionary) -> String:
	if message.has("club_mail"): return "InboxClubMail_" + str(message.id).replace("-", "_")
	if message.has("scene_invitation"): return "InboxSceneInvitation_" + str(message.scene_invitation.id).replace("-", "_").replace(":", "_")
	if message.get("press_invitation", {}).get("status") == "pending": return "InboxPressInvitation"
	if message.has("press_invitation"): return "InboxPressMessage_" + str(message.position)
	return "InboxMessage_" + str(message.position)

static func _message_key(event: InputEvent, app: Control, message_id: String) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	if event.keycode not in [KEY_UP, KEY_DOWN, KEY_HOME, KEY_END]: return
	var rows: Node = app.root_content.find_child("InboxMessageRows", true, false)
	if rows == null: return
	var buttons: Array = rows.get_children().filter(func(node): return node is Button and node.has_meta("message_id"))
	var index := -1
	for position in buttons.size():
		if buttons[position].get_meta("message_id") == message_id: index = position; break
	if index < 0: return
	var next := clampi(index + (1 if event.keycode == KEY_DOWN else -1), 0, buttons.size()-1)
	if event.keycode == KEY_HOME: next = 0
	if event.keycode == KEY_END: next = buttons.size()-1
	app.get_viewport().set_input_as_handled()
	buttons[next].pressed.emit()


const LETTER_PAD := 26.0

static func _is_word_char(character: String) -> bool:
	return character.to_lower() != character.to_upper() or character.is_valid_int()

## Joueurs et clubs cités dans un texte, prêts à devenir des liens : [{start, end, kind, id}], sans chevauchement,
## triés dans l'ordre du texte. Seules les entités qui ont un écran de destination sont rendues (jamais de lien mort).
static func entities(app: Control, text: String) -> Array:
	var candidates: Array = []
	var squad: Array = app.model.get("squad", [])
	var surnames := {}
	for player: Dictionary in squad:
		var words := str(player.get("name", "")).split(" ", false)
		if words.size() > 1: surnames[words[-1]] = int(surnames.get(words[-1], 0)) + 1
	for player: Dictionary in squad:
		var full := str(player.get("name", ""))
		if full.length() < 4: continue
		candidates.append([full, "player", str(player.get("id", ""))])
		var words := full.split(" ", false)
		if words.size() > 1 and words[-1].length() >= 5 and int(surnames.get(words[-1], 0)) == 1:
			candidates.append([words[-1], "player", str(player.get("id", ""))])
	var own: Dictionary = app.model.get("club", {})
	if own.has("id") and str(own.get("name", "")).length() >= 4: candidates.append([str(own.name), "club", str(own.id)])
	for division: Dictionary in app.model.get("leagues", []):
		for row: Dictionary in division.get("rows", []):
			var club := str(Press.G.club_name(row))
			if club.length() >= 4: candidates.append([club, "club", str(row.get("id", ""))])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).length() > str(b[0]).length())
	var taken: Array = []
	var found: Array = []
	var checked := {}
	for candidate: Array in candidates:
		var label := str(candidate[0])
		var from := 0
		while true:
			var start := text.find(label, from)
			if start < 0: break
			var end := start + label.length()
			from = end
			if start > 0 and _is_word_char(text[start - 1]): continue
			if end < text.length() and _is_word_char(text[end]): continue
			if taken.any(func(span: Array) -> bool: return start < int(span[1]) and end > int(span[0])): continue
			var key := "%s:%s" % [candidate[1], candidate[2]]
			if not checked.has(key): checked[key] = Link.available(app, str(candidate[1]), candidate[2])
			if not checked[key]: break
			taken.append([start, end])
			found.append({"start":start, "end":end, "kind":candidate[1], "id":candidate[2]})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.start) < int(b.start))
	return found

## Texte du courrier en BBCode : chaque entité citée devient un lien « kind:id » (couleur or-encre, soulignée).
static func linked_text(text: String, found: Array) -> String:
	var out := ""
	var cursor := 0
	var tone := C.Charte.OR_ENCRE.to_html(false)
	for item: Dictionary in found:
		out += text.substr(cursor, int(item.start) - cursor).replace("[", "[lb]")
		out += "[url=%s:%s][color=#%s]%s[/color][/url]" % [item.kind, item.id, tone, text.substr(int(item.start), int(item.end) - int(item.start)).replace("[", "[lb]")]
		cursor = int(item.end)
	return out + text.substr(cursor).replace("[", "[lb]")

## La lettre : le seul document « papier » de l'écran (charte §4.2). Titre, échéance (mot + symbole, jamais la couleur
## seule), filet, texte à l'encre ; noms de joueurs, de clubs en liens, mini-fiche au survol d'un joueur.
static func _letter(app: Control, message: Dictionary, width: float) -> PanelContainer:
	var paper := PanelContainer.new()
	paper.name = "InboxLetter"
	paper.add_theme_stylebox_override("panel", C.Charte.ombrer_droit(C.box(C.Charte.PAPIER, Color.TRANSPARENT, 0, int(LETTER_PAD))))
	var column := C.v(10)
	paper.add_child(column)
	var inner := C.px(width - 2.0 * LETTER_PAD)
	var total := 2.0 * C.px(LETTER_PAD)
	var children := 0
	# En-tête de lettre (maquette) : club en capitales espacées et date, puis titre en capitales italiques.
	var day := _day(message)
	var letterhead := str(app.model.get("club", {}).get("name", "")).to_upper() + ("" if day.is_empty() else " · " + _short_date(day, _today(app)).to_upper())
	if not C.dense() and not letterhead.strip_edges().is_empty() and letterhead != " · ":
		var head := C.wrap(letterhead, 16, C.Charte.ENCRE_2, true, 700)
		head.name = "InboxLetterhead"
		column.add_child(head)
		total += _label_height(head, inner)
		children += 1
	var title := C.wrap(str(message.get("subject", _subject(str(message.text)))).to_upper(), 42, C.Charte.ENCRE, true, 800)
	title.name = "InboxTitle"
	title.add_theme_font_override("font", C.Charte.TITRE_EXTRA_ITALIQUE)
	column.add_child(title)
	total += _label_height(title, inner)
	children += 1
	var due := _deadline(app, message, true)
	if not due.is_empty():
		var caption := C.wrap("À FAIRE · " + due, 20, C.Charte.OR_ENCRE, true, 700)
		caption.name = "InboxDeadline"
		column.add_child(caption)
		total += _label_height(caption, inner)
		children += 1
	var rule := ColorRect.new()
	rule.color = Color(C.Charte.ENCRE_2, .5)
	rule.custom_minimum_size.y = maxi(1, C.px(1))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	total += rule.custom_minimum_size.y
	children += 1
	var plain := str(message.get("text", ""))
	var pixels := maxi(12, C.px(24))
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var measured := C.BODY.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, float(inner), pixels, -1, flags)
	var line_height := C.BODY.get_height(pixels)
	var lines := maxi(1, roundi(measured.y / maxf(1.0, line_height))) + 1
	var body := RichTextLabel.new()
	body.name = "InboxMessageText"
	body.bbcode_enabled = true
	body.fit_content = false
	body.scroll_active = false
	body.selection_enabled = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", C.BODY)
	body.add_theme_font_size_override("normal_font_size", pixels)
	body.add_theme_color_override("default_color", C.Charte.ENCRE)
	body.add_theme_constant_override("line_separation", C.px(9))
	body.custom_minimum_size.y = lines * (line_height + C.px(9))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = linked_text(plain, entities(app, plain))
	body.meta_hover_started.connect(func(meta: Variant):
		var parts := str(meta).split(":", true, 1)
		if parts.size() < 2 or parts[0] != "player": return
		var fiche := MiniFiche.montrer(app, parts[1], "squad", body)
		if fiche != null:
			var screen := app.get_viewport_rect().size
			var spot := app.get_viewport().get_mouse_position() + Vector2(12, 20)
			fiche.position = Vector2(clampf(spot.x, 8.0, maxf(8.0, screen.x - fiche.size.x - 8.0)), clampf(spot.y, 8.0, maxf(8.0, screen.y - fiche.size.y - 8.0))))
	body.meta_hover_ended.connect(func(_meta: Variant): MiniFiche.cacher(app, body))
	body.meta_clicked.connect(func(meta: Variant):
		var parts := str(meta).split(":", true, 1)
		if parts.size() < 2 or not is_instance_valid(app.navigation_controller): return
		_open_related(app, message, func(): app.navigation_controller.open_entity({"kind":parts[0], "id":parts[1]})))
	column.add_child(body)
	total += body.custom_minimum_size.y
	children += 1
	total += float(maxi(0, children - 1)) * C.px(10)
	paper.set_meta("hauteur_px", total)
	return paper

## Largeur de la colonne de lecture du mail (≈ 700 px de la maquette, jamais plus large que le mail).
static func _reading_width() -> float:
	return minf(_w - 2 * PAD, READING_MAX)

## Le mail ouvert : en-tête (service, expéditeur, date ; Favori, Lu, Archiver), grand titre, texte en colonne lisible
## (ou coupure de presse, ou bilan d'infirmerie), pièces liées, puis « TA RÉPONSE » et les actions en bas.
static func _detail(card: Panel, app: Control, state: Dictionary, message: Dictionary, height: float) -> void:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var reading_width := _reading_width()
	if message.is_empty():
		D.text(card,PAD,92,"Le courrier de la sélection" if national else "Le courrier du club",44,C.IVORY,700,_w-2*PAD)
		var empty := C.wrap("Aucun message à afficher dans ce dossier.",24,C.MUTED)
		empty.name = "InboxMessageText"
		card.add_child(empty); D.place(empty,Rect2(PAD,130,reading_width,80))
		return
	var mark: Dictionary = state.marks.get(message.id,{})
	# En-tête : expéditeur, service et date ; actions de rangement à droite (la lettre vient dessous).
	var date := _day(message)
	var when := _short_date(date, _today(app)) if not date.is_empty() else _date(message)
	var tools_width := 3 * 150.0 + 2 * 10.0
	var hour := str(message.get("hour", ""))
	if not hour.is_empty() and not when.is_empty(): when += ", " + hour
	# Presse : le nom du journal n'apparaît qu'une fois, sur la coupure ; l'en-tête dit seulement « Presse » et la date.
	# Service en petites capitales puis expéditeur en casse normale (une seule fois si les deux se confondent), date dessous.
	var service := _service(message)
	var sender := service if not _press_mail(message).is_empty() else _sender(app,message)
	var head_width := _w-2*PAD-tools_width-20
	if sender == service:
		D.text(card,PAD,56,sender,23,C.IVORY,700,head_width).name = "InboxSenderName"
	else:
		var caps := service.to_upper()
		var caps_width := C.font(700).get_string_size(caps, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0
		D.text(card,PAD,56,caps,16,C.MUTED,700,caps_width)
		D.text(card,PAD+caps_width,56,sender,23,C.IVORY,700,head_width-caps_width).name = "InboxSenderName"
	D.text(card,PAD,86,when,19,C.MUTED,500,head_width)
	# Une coupure de presse n'a pas de lettre : l'échéance s'écrit alors dans l'en-tête (mot « À FAIRE », jamais la couleur seule).
	var press_due := _deadline(app, message, true)
	if not _press_mail(message).is_empty() and not press_due.is_empty():
		D.text(card,PAD+420,86,"À FAIRE · " + press_due,19,C.IVORY,700,_w-2*PAD-420-tools_width-20).name = "InboxDeadline"
	var x := _w - PAD - tools_width
	var favorite := D.button(card,Rect2(x,40,150,_h(44)),"Favori" if not mark.get("favorite",false) else "Favori ★",func():
		_mark_members(state, message, "favorite", not mark.get("favorite",false))
		_redraw(app,"InboxToggleFavorite"),false,"star",true,app.accent,"InboxToggleFavorite")
	favorite.tooltip_text = "Retirer des favoris" if mark.get("favorite",false) else "Ajouter aux favoris"
	if not mark.get("archived",false):
		var read_toggle := D.button(card,Rect2(x+160,40,150,_h(44)),"Non lu" if mark.get("read",false) else "Lu",func():
			_mark_members(state, message, "read", not mark.get("read",false))
			_redraw(app,"InboxToggleRead"),false,"mail",true,app.accent,"InboxToggleRead")
		read_toggle.tooltip_text = "Marquer non lu" if mark.get("read",false) else "Marquer lu"
	var archive := D.button(card,Rect2(x+320,40,150,_h(44)),"Désarchiver" if mark.get("archived",false) else "Archiver",func():
		_mark_members(state, message, "archived", not mark.get("archived",false))
		_redraw(app,"InboxFolder"+str(state.folder)),false,"check",true,app.accent,"InboxToggleArchive")
	archive.tooltip_text = "Réouvrir le message" if mark.get("archived",false) else "Marquer comme traité et ranger dans les archives"
	for tool: Button in [favorite, archive] + ([card.get_node_or_null("InboxToggleRead")] if card.get_node_or_null("InboxToggleRead") != null else []):
		C.style_bouton_lien(tool, 18)
	var press := _press_mail(message)
	# Contenu puis, juste dessous, pièces liées, « TA RÉPONSE » et actions ; rappel Espace en bas du mail.
	var hint_base := height - 22 - _context_bar()
	var replies := _reply_layout(app, message, reading_width)
	var focused := message.has("press_invitation") or message.has("calendar_notice") or message.has("club_mail") or message.has("scene_invitation") or message.has("international_event")
	var body_top := 106.0
	var concerned := _concerned_layout(app, message, reading_width)
	var footer := (34.0 + float(replies.height) + 18.0 + _send_row_height() if not replies.is_empty() else 0.0) + _h(46) + (float(concerned.height) + 14.0 if not concerned.is_empty() else 0.0)
	var probe := Panel.new()
	var attachments := _attachments(probe,app,state,message,0,focused,false,reading_width)
	if hint_base - 34 - footer - attachments - body_top < 200 and not focused:
		focused = true
		attachments = _attachments(probe,app,state,message,0,focused,false,reading_width)
	probe.free()
	var room := maxf(80.0, hint_base - 34 - footer - (attachments + 12 if attachments > 0 else 0.0) - 18 - body_top)
	var content_width := _w-2*PAD
	var content: Control
	if not press.is_empty():
		content = _clipping(app, message, press, _w-2*PAD-14)
	else:
		var column := C.v(22)
		column.name = "InboxReadingColumn"
		# La lettre porte l'ombre de la charte : un jeu de 4 px autour d'elle, sinon la zone qui défile la rogne.
		var marge := C.px(6) # plus que l'étendue de l'ombre (4 px), quelle que soit la densité
		var support := MarginContainer.new()
		support.name = "InboxLetterSupport"
		for cote: String in ["left", "right", "top", "bottom"]: support.add_theme_constant_override("margin_" + cote, marge)
		support.add_child(_letter(app, message, content_width - 12.0))
		column.add_child(support)
		if message.get("category") == "Médical" and not national: column.add_child(_infirmary(app, reading_width))
		content = column
	C.fill(content)
	var natural := _clipping_height(content, C.px(_w-2*PAD-14)) if not press.is_empty() else _column_height(content, C.px(content_width))
	var body_height := clampf(natural / C.density + 26, 80.0, room)
	var scroll := ScrollContainer.new()
	scroll.name = "InboxReadingScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	D.place(scroll,Rect2(PAD,body_top,content_width,body_height))
	scroll.add_child(content)
	# Pied (pièces liées, réponses, actions) dans un calque propre : il suit le contenu si celui-ci s'avère plus haut.
	var top := body_top + body_height + 18
	var bottom := Panel.new()
	bottom.name = "InboxFooter"
	bottom.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bottom)
	var y := 0.0
	if attachments > 0:
		_attachments(bottom,app,state,message,y,focused,true,reading_width)
		y += attachments + 12
	if not replies.is_empty():
		D.text(bottom,PAD,y+20,"TA RÉPONSE",19,C.GOLD,700,400).name = "InboxReplyHeading"
		_reply_cards(bottom, app, state, message, replies, y + 34)
		y += 34 + float(replies.height) + 18
		_send_row(bottom, app, state, message, replies, y)
		y += _send_row_height()
	_actions(bottom,app,state,message,int(y))
	y += _h(46)
	if not concerned.is_empty():
		y += 14.0
		_concerned_row(bottom, app, message, concerned, PAD, y, reading_width)
		y += float(concerned.height)
	_mail_context(card, app, message, when, height)
	D.place(bottom, Rect2(0, top, _w, y))
	# Plus de rappel « Espace : message non lu suivant » : dans la coque commune, Espace = Continuer partout.
	_settle_reading.call_deferred(scroll, bottom, (hint_base - 34) * C.density)

## Pied du courrier, collé au bas (maquette), sur UNE ligne : expéditeur, reçu, état, puis « Courrier suivant non lu → »
## en lien texte. Lecture seule ; il garde sa place même sous un mail court.
const CONTEXT_BAR := 50.0
const CONTEXT_GAP := 26.0
## Hauteur du pied : au moins celle d'une commande (en petite fenêtre, la cible minimale grandit).
static func _context_bar() -> float:
	return maxf(CONTEXT_BAR, C.reach(40) + 12.0)
static func _mail_context(card: Panel, app: Control, message: Dictionary, when: String, height: float) -> void:
	var width := _w - 2 * PAD
	var box := Control.new()
	box.name = "InboxMailContext"
	card.add_child(box)
	D.place(box, Rect2(PAD, height - 22 - _context_bar() + 8, width, _context_bar() - 8))
	D.line(box, Vector2(0, 0), Vector2(width, 0), Color(C.LINE, .7))
	var reading := Reading.status(message, app.model)
	var state := str(reading.get("label", "Information"))
	if reading.get("key") != "info" and not str(reading.get("reason", "")).is_empty(): state += " · " + str(reading.reason)
	var rows := [
		["Expéditeur", _sender(app, message), .34],
		["Reçu", when if not when.is_empty() else "Date non précisée", .26],
		["État", state, .40],
	]
	# Jamais grisé à tort : « suivant » = le premier non lu AUTRE que le courrier ouvert ; « Tout est lu » seulement s'il n'en reste aucun.
	var next := next_unread(app, str(message.get("id", "")))
	var follow_width := 320.0
	var room := width - follow_width - 12.0
	var cursor := 0.0
	for index in rows.size():
		var cell := room * float(rows[index][2])
		var caption_width := C.font(600).get_string_size(rows[index][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 10.0
		D.text(box, cursor, 36, rows[index][0], 16, C.MUTED, 600, caption_width)
		D.text(box, cursor + caption_width, 36, rows[index][1], 18, C.IVORY, 700, cell - caption_width - 12).name = "InboxMailContext_%d" % index
		cursor += cell
	if next.is_empty():
		D.text(box, width, 36, "Tout est lu", 18, C.FAINT, 600, follow_width, HORIZONTAL_ALIGNMENT_RIGHT).name = "InboxMailContextNext"
		return
	var follow := D.button(box, Rect2(width - follow_width, 4, follow_width, C.reach(40)), "Courrier suivant non lu", _open_next.bind(app, str(message.get("id", ""))), false, "arrow", true, app.accent, "InboxMailContextNext")
	C.style_bouton_lien(follow, 18)
	follow.alignment = HORIZONTAL_ALIGNMENT_RIGHT

## Ouvre le prochain courrier non lu de la liste affichée (bouton « Courrier suivant non lu »).
static func _open_next(app: Control, current_id: String = "") -> void:
	if open_next_unread(app, current_id): app._render()

## Une fois le contenu mis en page : si sa hauteur réelle dépasse la mesure, la zone de lecture grandit (dans la
## place libre au-dessus du rappel Espace) et le pied descend d'autant ; aucun défilement inutile.
static func _settle_reading(scroll: ScrollContainer, footer: Control, limit: float) -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree(): return
	var tree := scroll.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(footer) or scroll.get_child_count() == 0: return
	var content := scroll.get_child(0) as Control
	var missing := content.get_combined_minimum_size().y + 4.0 - scroll.size.y
	var spare := limit - (footer.position.y + footer.size.y)
	# Le dossier du courrier ne complète qu'un mail court : il cède sa place si le texte en a besoin.
	var extra := footer.get_node_or_null("InboxMailContext") as Control
	if missing > spare and extra != null:
		footer.size.y = maxf(0.0, extra.position.y - C.px(CONTEXT_GAP))
		footer.remove_child(extra)
		extra.queue_free()
		spare = limit - (footer.position.y + footer.size.y)
	var grow := minf(missing, spare)
	if grow <= 0.5: return
	scroll.size.y += grow
	footer.position.y += grow

## Hauteur (px) d'un contenu à largeur donnée, mesurée tout de suite (conteneurs triés hors de l'arbre) :
## les réponses se placent juste sous le contenu, sans attendre une image.
static func _measure(control: Control, width: float) -> float:
	for attempt in 3:
		control.size = Vector2(width, 0)
		_sort_now(control)
	return control.get_combined_minimum_size().y

## Hauteur (px) de la coupure de presse : somme de ses blocs, chaque texte mesuré à sa vraie largeur.
static func _clipping_height(paper: Control, width: float) -> float:
	var pad := C.px(34)
	var inner := width - 2.0 * pad
	var column := paper.get_child(0) as Container
	var gap := float(column.get_theme_constant("separation"))
	var total := 2.0 * pad + gap * maxf(0.0, column.get_child_count() - 1)
	for block: Node in column.get_children():
		if block.name == "InboxPressColumns":
			var texts: Array = block.get_children().filter(func(n: Node): return n is Label)
			var photo := block.find_child("InboxPressPhoto", false, false) as Control
			var spacing := float((block as Container).get_theme_constant("separation"))
			var photo_width := photo.custom_minimum_size.x if photo != null else 0.0
			var share := (inner - photo_width - spacing * maxf(0.0, block.get_child_count() - 1)) / maxf(1.0, texts.size())
			var tallest := photo.custom_minimum_size.y if photo != null else 0.0
			for text: Label in texts: tallest = maxf(tallest, _label_height(text, share))
			total += tallest
		elif block is Label: total += _label_height(block, inner)
		elif block is HBoxContainer:
			var tallest := 0.0
			for part: Node in block.get_children(): if part is Label: tallest = maxf(tallest, _label_height(part, inner / 2.0 if part.autowrap_mode != TextServer.AUTOWRAP_OFF else inner))
			total += tallest
		else: total += (block as Control).get_combined_minimum_size().y
	return total + C.px(8)

## Hauteur (px) de la colonne de lecture : texte mesuré à sa largeur, tableau sans retour à la ligne.
static func _column_height(column: Control, width: float) -> float:
	var total := float((column as Container).get_theme_constant("separation")) * maxf(0.0, column.get_child_count() - 1)
	for block: Node in column.get_children():
		if block is Label: total += _label_height(block, width)
		elif block.has_meta("hauteur_px"): total += float(block.get_meta("hauteur_px"))
		else: total += (block as Control).get_combined_minimum_size().y
	return total + C.px(6)

static func _label_height(label: Label, width: float) -> float:
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF: return label.get_minimum_size().y
	label.size = Vector2(width, 0)
	return label.get_minimum_size().y

static func _sort_now(node: Node) -> void:
	if node is Container: node.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in node.get_children(): _sort_now(child)

## Paragraphes aérés : une ligne vide entre deux paragraphes du moteur.
static func _airy(text: String) -> String:
	var lines := text.replace("\r", "").split("\n")
	var out: Array[String] = []
	for line in lines:
		if line.strip_edges().is_empty():
			if not out.is_empty() and out[-1] != "": out.append("")
		else: out.append(line)
	return "\n".join(PackedStringArray(out))

## Courrier de presse du club (catégorie « presse » du moteur) : vide sinon.
static func _press_mail(message: Dictionary) -> Dictionary:
	var mail: Dictionary = message.get("club_mail", {})
	return mail if str(mail.get("categorie", "")) == "presse" else {}

## Coupure de journal : carte crème, titre du média, rubrique, grand titre, chapeau en italique, texte sur deux
## colonnes, photo seulement si la banque d'images en a une pour ce papier (aucun cadre vide).
static func _clipping(app: Control, message: Dictionary, mail: Dictionary, width: float) -> Control:
	var ink := C.Charte.ENCRE
	var paper := PanelContainer.new()
	paper.name = "InboxPressClipping"
	var style := C.box(C.Charte.PAPIER, Color.TRANSPARENT, 0, 34)
	# Coupure de presse : une carte posée sur la lettre, ombre portée de la charte (choix de Léo du 20/11/2026).
	paper.add_theme_stylebox_override("panel", C.Charte.ombrer(style, C.Charte.RAYON_CARTE))
	paper.custom_minimum_size.x = C.px(width)
	var column := C.v(10)
	paper.add_child(column)
	var masthead := C.h(16)
	var media := C.label(str(mail.get("expediteur", "La presse")), 40, ink, true, 800)
	media.name = "InboxPressMedia"
	C.fill(media)
	masthead.add_child(media)
	var stamp := _short_date(_day(message), "", true)
	var dateline := C.label(stamp.left(1).to_upper() + stamp.substr(1) + "\nRugby", 16, Color(ink,.7), false, 500)
	dateline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	masthead.add_child(dateline)
	column.add_child(masthead)
	var rule := ColorRect.new()
	rule.color = Color(ink,.85)
	rule.custom_minimum_size.y = maxi(2, C.px(4))
	column.add_child(rule)
	var rubrique := C.label(RUBRIQUES.get(str(mail.get("type", "")), "SPORT"), 17, C.Charte.D_PAPIER, true, 700)
	rubrique.name = "InboxPressRubrique"
	column.add_child(rubrique)
	var headline := C.wrap(str(mail.get("sujet", message.get("subject", ""))), 54, ink, true, 800)
	headline.name = "InboxPressHeadline"
	column.add_child(headline)
	var paragraphs: Array[String] = []
	for part in str(mail.get("corps", "")).replace("\r", "").split("\n"):
		if not part.strip_edges().is_empty(): paragraphs.append(part.strip_edges())
	if paragraphs.size() > 1:
		var lead := C.wrap(paragraphs[0], 24, Color(ink,.82), false, 500)
		lead.name = "InboxPressLead"
		var slanted := FontVariation.new()
		slanted.base_font = C.BODY
		slanted.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		lead.add_theme_font_override("font", slanted)
		column.add_child(lead)
		paragraphs.remove_at(0)
	# Deux colonnes équilibrées au nombre de caractères.
	var total := 0
	for part in paragraphs: total += part.length()
	var left: Array[String] = []
	var right: Array[String] = []
	var used := 0
	for part in paragraphs:
		if used < total / 2.0 or left.is_empty(): left.append(part); used += part.length()
		else: right.append(part)
	if right.is_empty() and left.size() == 1 and left[0].length() > 220:
		var words := left[0].split(" ")
		var half := words.size() / 2
		right.append(" ".join(words.slice(half)))
		left[0] = " ".join(words.slice(0, half))
	var columns := C.h(28)
	columns.name = "InboxPressColumns"
	for side: Array in [left, right]:
		if side.is_empty(): continue
		var text := C.wrap("\n\n".join(PackedStringArray(side)), 22, ink, false, 500)
		text.add_theme_constant_override("line_spacing", C.px(5))
		C.fill(text)
		text.name = "InboxPressColumn%d" % columns.get_child_count()
		columns.add_child(text)
	var photo_id := photo_resultat(str(mail.get("corps", "")) + " " + str(mail.get("sujet", "")))
	if photo_id != "mail-pitch" and BanqueImages.texture(photo_id) != null:
		var picture := C.photo(photo_id, Vector2(C.px(220), C.px(160)))
		picture.name = "InboxPressPhoto"
		picture.custom_minimum_size = Vector2(C.px(220), C.px(160))
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		columns.add_child(picture)
	column.add_child(columns)
	var answered := ClubMail.answer(app.model, mail)
	if not answered.is_empty() or str(mail.get("status", "")) == "classe":
		var after := str(message.get("text", "")).get_slice("\n\n— ", 1)
		var note := after.substr(after.find("\n\n") + 2) if after.find("\n\n") >= 0 else ""
		if not note.strip_edges().is_empty():
			var receipt := C.wrap(note.strip_edges(), 18, Color(ink,.75), false, 600)
			receipt.name = "InboxPressReceipt"
			column.add_child(receipt)
	return paper

## Colonnes du tableau de l'infirmerie [titre, part de la largeur] ; « BLESSURE » est la plus large (noms longs).
## Hauteur maximale (px de mise en page) des lignes du tableau avant défilement sous l'en-tête figé.
const INFIRMARY_MAX_ROWS := 460.0
## Marge à droite du texte de chaque colonne du tableau (px de mise en page), pour ne jamais coller la colonne voisine.
const INFIRMARY_GUTTER := 16.0
const INFIRMARY_COLUMNS := [["JOUEUR", .22], ["POSTE", .14], ["BLESSURE", .32], ["RETOUR ESTIMÉ", .16], ["PROCHAIN MATCH", .16]]

## Tableau de l'infirmerie (données réelles de la partie) : joueurs blessés et en reprise, retour estimé et statut
## pour la prochaine rencontre (forfait rouge, apte vert, risque doré).
static func infirmary_rows(model: Dictionary) -> Array[Dictionary]:
	var today := str(model.get("meta", {}).get("calendarToday", ""))
	var medical: Array = model.get("clubLife", {}).get("clubSupport", {}).get("medical", {}).get("players", [])
	var stages := {}
	for record: Variant in medical:
		if record is Dictionary: stages[str(record.get("id", ""))] = record
	var result: Array[Dictionary] = []
	for player: Dictionary in model.get("squad", []):
		var weeks := float(player.get("injury", 0)) if (player.get("injury") is int or player.get("injury") is float) else 0.0
		var record: Dictionary = stages.get(str(player.get("id", "")), {})
		var condition := float(player.get("condition", 100)) if (player.get("condition") is int or player.get("condition") is float) else 100.0
		var row := {"id":str(player.id), "name":str(player.get("name", "")), "pos":str(player.get("pos", "")), "weeks":weeks}
		if weeks > 0:
			row.injury = "%s · %s" % [ClubMail.injury_label(model, player), P.plural(ceili(weeks), "semaine", "semaines")]
			row.back = ("≈ " + _short_date(_shift(today, roundi(weeks * 7)), today, false)) if today.length() >= 10 else "%d sem." % ceili(weeks)
			row.status = "Forfait"; row.tone = "alert"
		elif str(record.get("stage", "")) == "reprise":
			var risky := condition < 80.0
			row.injury = "En reprise · condition %d %%" % roundi(condition)
			row.back = "Rétabli"
			row.status = "Risque" if risky else "Apte"; row.tone = "gold" if risky else "mint"
		elif condition < INCERTAIN:
			row.injury = "Gêne · condition %d %%" % roundi(condition)
			row.back = "À évaluer"
			row.status = "Incertain"; row.tone = "gold"; row.weeks = -1.0
		else: continue
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.weeks) > float(b.weeks))
	return result

## Hauteur (px) d'un libellé à retour à la ligne, à sa largeur minimale : lignes réelles de la police, sans coupure.
static func wrapped_height(label: Label) -> float:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var lines := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.custom_minimum_size.x - C.px(INFIRMARY_GUTTER), size, -1, flags).y
	return ceilf(lines) + C.px(10)

static func _infirmary(app: Control, width: float) -> Control:
	var table := C.v(0)
	table.name = "InboxInfirmary"
	var heading := C.label("BILAN DE L'INFIRMERIE", 20, C.GOLD, true, 700)
	table.add_child(heading)
	var rows := infirmary_rows(app.model)
	if rows.is_empty():
		var none := C.label("Aucun joueur à l'infirmerie : tout l'effectif est disponible.", 20, C.MINT, false, 500)
		none.name = "InboxInfirmaryEmpty"
		table.add_child(none)
		return table
	var columns := INFIRMARY_COLUMNS
	var header := C.h(0)
	for column: Array in columns:
		var cell := C.label(column[0], 16, C.FAINT.lightened(.15), true, 700)
		cell.custom_minimum_size = Vector2(C.px(width * float(column[1])), C.px(36))
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(cell)
	table.add_child(header)
	var tones := {"alert":C.ALERT, "gold":C.GOLD, "mint":C.MINT}
	# En-tête figé ; les lignes défilent dessous si elles dépassent INFIRMARY_MAX_ROWS (px de mise en page), aucune n'est masquée.
	var body := C.v(0)
	body.name = "InboxInfirmaryRows"
	var body_height := 0.0
	for index in rows.size():
		var data: Dictionary = rows[index]
		var line := ColorRect.new()
		line.color = Color(C.LINE,.5)
		line.custom_minimum_size.y = 1
		body.add_child(line)
		body_height += 1.0
		var row := C.h(0)
		row.name = "InboxInfirmaryRow_%d" % index
		var row_height := 0.0
		row.set_meta("player_id", data.id)
		var values := [[data.name, C.IVORY, 700], [data.pos, C.MUTED, 500], [data.injury, C.MUTED, 500], [data.back, C.IVORY, 500], [data.status, tones[data.tone], 700]]
		for column in values.size():
			var cell: Control
			if column == 0 and Link.available(app, "player", data.id):
				# Nom du joueur : lien vers sa fiche (mini-fiche au survol), souligné d'emblée.
				var name_button := C.button(str(values[column][0]), func(): pass)
				Link.bind(name_button, app, Link.target("player", data.id), str(values[column][0]))
				C.style_bouton_lien(name_button, 21, true)
				MiniFiche.lier(app, name_button, str(data.id), "squad")
				name_button.name = "InboxInfirmaryPlayer_%d" % index
				name_button.set_meta("player_id", str(data.id))
				name_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				cell = name_button
			else:
				cell = C.label(values[column][0], 21, values[column][1] if column != 0 else C.FAINT, column != 2 and column != 1, values[column][2] if column != 0 else 500)
			cell.custom_minimum_size = Vector2(C.px(width * float(columns[column][1])), C.px(48))
			cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if cell is Button:
				row.add_child(cell)
				row_height = maxf(row_height, cell.custom_minimum_size.y)
				continue
			var gutter := StyleBoxEmpty.new()
			gutter.content_margin_right = C.px(INFIRMARY_GUTTER)
			cell.add_theme_stylebox_override("normal", gutter)
			# Retour à la ligne plutôt que coupure : la hauteur de la ligne suit le texte le plus long de la rangée.
			(cell as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(cell as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			cell.custom_minimum_size.y = maxf(cell.custom_minimum_size.y, wrapped_height(cell as Label))
			(cell as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if column == 4: cell.name = "InboxInfirmaryStatus"
			row.add_child(cell)
			row_height = maxf(row_height, cell.custom_minimum_size.y)
		body.add_child(row)
		body_height += row_height
	var scroll := ScrollContainer.new()
	scroll.name = "InboxInfirmaryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = minf(body_height, C.px(INFIRMARY_MAX_ROWS))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	table.add_child(scroll)
	return table

## Conséquences d'une réponse, tirées de ses effets réels (texte du moteur « Moral +2 · Coût 5 000 € ») :
## [symbole, texte, couleur] ; ▲ favorable, ▼ défavorable, = neutre. Pression et charge : une hausse est défavorable.
## Risque de rechute : ▲ hausse (alerte), ▼ baisse ; date de retour : avancée favorable, retardée défavorable.
static func consequences(effets: String) -> Array:
	var result: Array = []
	for part: String in effets.split(" · ", false):
		var text := part.strip_edges()
		if text.is_empty(): continue
		var folded := U.fold(text)
		# Risque de rechute : la flèche suit le sens du risque (▲ hausse, en alerte ; ▼ baisse, favorable).
		if folded.begins_with("risque"):
			var up := text.contains(" +")
			result.append(["▲" if up else "▼", text, C.ALERT if up else C.MINT])
			continue
		var direction := 0
		if folded.begins_with("retour avance"): direction = 1
		elif folded.begins_with("retour retarde"): direction = -1
		elif folded.begins_with("cout") or folded.begins_with("frais"): direction = -1
		elif folded.begins_with("recette"): direction = 1
		elif not folded.begins_with("charge individuelle"):
			var rise := text.contains(" +")
			var fall := text.contains(" −") or text.contains(" -")
			if rise or fall:
				direction = 1 if rise else -1
				if folded.begins_with("pression") or folded.begins_with("charge"): direction = -direction
		match direction:
			1: result.append(["▲", text, C.MINT])
			-1: result.append(["▼", text, C.ALERT])
			_: result.append(["=", text, C.MUTED])
	if result.is_empty(): result.append(["=", "Sans effet chiffré", C.MUTED])
	return result

## Disposition des cartes de réponse d'un mail du club qui en attend une ({} sinon).
static func _reply_layout(app: Control, message: Dictionary, width: float) -> Dictionary:
	if not message.has("club_mail") or not ClubMail.awaiting(app.model, message.club_mail): return {}
	var options: Array = message.club_mail.get("reponses", [])
	if options.is_empty(): return {}
	var columns := options.size() if options.size() <= 3 else 2
	var card_width := (width - 14.0 * (columns - 1)) / columns
	var label_lines := 1
	var effect_height := 24.0
	for option: Dictionary in options:
		label_lines = maxi(label_lines, wrapped_lines(str(option.get("libelle", "")), 21, card_width - 36, C.font(700)))
		effect_height = maxf(effect_height, _effects_height(option, card_width - 36))
	var card_height := 42.0 + 28.0 * label_lines + 8.0 + effect_height + 14.0
	var rows := ceili(options.size() / float(columns))
	return {"options":options, "columns":columns, "card_width":card_width, "card_height":card_height, "label_lines":label_lines, "height":rows * card_height + (rows - 1) * 12.0}

## Nombre de lignes d'un texte à retour à la ligne (police et taille du jeu, largeur en unités de mise en page).
static func wrapped_lines(text: String, font_size: int, width: float, font: Font = C.BODY) -> int:
	var pixels := maxi(12, C.px(font_size))
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, C.px(width)), pixels, -1, flags)
	return maxi(1, roundi(size.y / maxf(1.0, font.get_height(pixels))))

## Lignes de conséquences affichées pour une réponse : [symbole, texte, couleur], indisponibilité en tête.
static func _effect_lines(option: Dictionary) -> Array:
	var lines := consequences(str(option.get("effets", "")))
	if not option.get("disponible", false): lines = [["×", str(option.get("raison", "Indisponible")), C.FAINT]] + lines
	return lines.slice(0, 4)

## Hauteur des conséquences d'une réponse : chaque ligne passe à la ligne au besoin (22 par ligne de texte, 2 d'écart).
static func _effects_height(option: Dictionary, width: float) -> float:
	var total := 0.0
	for effect: Array in _effect_lines(option): total += 22.0 * wrapped_lines("%s %s" % [effect[0], effect[1]], 17, width) + 2.0
	return total

## Chaque réponse est une carte-bouton : libellé, puis ses conséquences (▲ / ▼ / =).
static func _reply_cards(card: Panel, app: Control, state: Dictionary, message: Dictionary, layout: Dictionary, top: float) -> void:
	var mail: Dictionary = message.club_mail
	var options: Array = layout.options
	var picked: String = str(state.reply_pick.get(str(mail.id), ""))
	for index in options.size():
		var option: Dictionary = options[index]
		var column := index % int(layout.columns)
		var line := index / int(layout.columns)
		var area := Rect2(PAD + column * (float(layout.card_width) + 14), top + line * (float(layout.card_height) + 12), layout.card_width, layout.card_height)
		var option_id := str(option.get("id",""))
		var chosen: bool = option_id == picked and bool(option.get("disponible", false))
		# Un clic CHOISIT la réponse ; elle ne part qu'avec « Envoyer la réponse » (rien ne part sans confirmation).
		var reply := C.button("", func():
			state.reply_pick[str(mail.id)] = option_id
			_redraw(app, "InboxClubMailReply_" + option_id), false, app.accent)
		reply.name = "InboxClubMailReply_" + option_id
		reply.set_meta("option_id", option_id)
		reply.custom_minimum_size = Vector2.ZERO
		# Maquette : carte sans cadre sur fond de panneau, filet gauche (ivoire si choisie), en-tête « RÉPONSE A ».
		reply.add_theme_stylebox_override("normal", C.box(C.SELECTED if chosen else C.PANEL, Color.TRANSPARENT, 0, 0))
		reply.add_theme_stylebox_override("hover", C.box(C.RAISED, Color.TRANSPARENT, 0, 0))
		reply.add_theme_stylebox_override("disabled", C.box(C.PANEL, Color.TRANSPARENT, 0, 0))
		card.add_child(reply)
		D.place(reply, area)
		reply.disabled = app.waiting or not option.get("disponible", false)
		var detail := str(option.get("effets",""))
		reply.tooltip_text = str(option.get("libelle","")) + "\n" + (detail if not detail.is_empty() else "Sans effet chiffré.") + ("" if option.get("disponible", false) else "\n" + str(option.get("raison","")))
		reply.accessibility_name = reply.tooltip_text
		var rule := D.rect(reply, Rect2(0, 0, 4, float(layout.card_height)), C.IVORY if chosen else C.LINE, 0)
		rule.name = "InboxReplyRule"
		var letter_id := "RÉPONSE " + char(65 + index) + ("" if option.get("disponible", false) else " · INDISPONIBLE")
		var kicker := D.text(reply, 18, 26, letter_id, 15, C.MUTED, 700, float(layout.card_width) - 36)
		kicker.clip_text = false
		kicker.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var seal := ""
		if chosen: seal = "✓ CHOISIE"
		elif bool(option.get("recommandee", false)): seal = "RECOMMANDÉE PAR GABI"
		if not seal.is_empty():
			var stamp := D.text(reply, float(layout.card_width) - 18, 26, seal, 15, C.IVORY, 700, 220, HORIZONTAL_ALIGNMENT_RIGHT)
			stamp.name = "InboxReplyChosen" if chosen else "InboxReplyRecommended"
			stamp.clip_text = false
			stamp.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var title := C.wrap(str(option.get("libelle","")), 21, C.IVORY if not reply.disabled else C.FAINT, true, 700)
		title.name = "InboxReplyLabel"
		title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		reply.add_child(title)
		D.place(title, Rect2(18, 34, float(layout.card_width) - 36, 28.0 * int(layout.label_lines) + 4))
		var y := 42.0 + 28.0 * int(layout.label_lines) + 8.0
		for effect: Array in _effect_lines(option):
			var effect_label := D.text(reply, 18, y + 16, "%s %s" % [effect[0], effect[1]], 17, effect[2], 600, float(layout.card_width) - 36, HORIZONTAL_ALIGNMENT_LEFT, true)
			effect_label.name = "InboxReplyEffect"
			# Retour à la ligne, jamais d'ellipse : la carte a été dimensionnée pour la réponse la plus longue.
			var count := wrapped_lines(effect_label.text, 17, float(layout.card_width) - 36)
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			effect_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			effect_label.size.y = C.px(22.0 * count + 2.0)
			y += 22.0 * count + 2.0


static func _send_row_height() -> float:
	return _h(46) + 14.0

## « Envoyer la réponse X » : l'action principale de l'écran (ivoire plein, jamais or). Désactivée tant qu'aucune
## réponse n'est choisie ; « Annuler » retire le choix ; rien ne part sans cette confirmation.
static func _send_row(card: Panel, app: Control, state: Dictionary, message: Dictionary, layout: Dictionary, top: float) -> void:
	var mail: Dictionary = message.club_mail
	var picked := str(state.reply_pick.get(str(mail.id), ""))
	var options: Array = layout.options
	var letter := ""
	for index in options.size():
		if str(options[index].get("id", "")) == picked and options[index].get("disponible", false): letter = char(65 + index)
	var send := D.button(card, Rect2(PAD, top, 360, _h(46)), ("Envoyer la réponse " + letter) if not letter.is_empty() else "Choisis une réponse",
		func(): _send_reply(app, state, str(mail.id), picked), true, "", false, app.accent, "InboxClubMailSend")
	send.disabled = letter.is_empty() or app.waiting
	C.style_bouton_contour(send, 21)
	send.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if letter.is_empty(): return
	var cancel := D.button(card, Rect2(PAD + 380, top, 150, _h(46)), "Annuler", func():
		state.reply_pick.erase(str(mail.id))
		_redraw(app, "InboxClubMailReply_" + picked), false, "arrow", true, app.accent, "InboxClubMailCancel")
	C.style_bouton_lien(cancel, 19)
	D.text(card, PAD + 550, top + 30, "Rien ne part sans cette confirmation.", 17, C.MUTED, 500, minf(500.0, _reading_width() - 550), HORIZONTAL_ALIGNMENT_LEFT, true)

static func _send_reply(app: Control, state: Dictionary, mail_id: String, choice: String) -> void:
	state.reply_pick.erase(mail_id)
	_reply_club_mail(app, mail_id, choice)

## Hauteur de la rangée « Concerné » : joueur lié (nom, disponibilité), club, joueurs en fin de contrat. 0 si rien.
static func _concerned_layout(app: Control, message: Dictionary, width: float) -> Dictionary:
	var data := _concerned(app, message)
	if not (data.has("player") or data.has("club") or data.has("expiring")): return {}
	var availability := ""
	if data.has("player"):
		var player: Dictionary = data.player
		var weeks := float(player.get("injury", 0)) if (player.get("injury") is int or player.get("injury") is float) else 0.0
		availability = ("%s · %d sem." % [ClubMail.injury_label(app.model, player), ceili(weeks)]) if weeks > 0 else ("En reprise" if P.player_in_recovery(app.model, str(player.get("id", ""))) else "Apte")
	var lines := wrapped_lines(availability, 18, minf(300.0, width - 420.0)) if not availability.is_empty() else 1
	return {"data":data, "availability":availability, "lines":lines, "height":maxf(_h(40), 24.0 * lines + 10.0)}

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
		var link := _nom_lien(app, card, Rect2(cursor, y, 260, _h(40)), "player", player_id, str(player.get("name", "")), 20, C.IVORY, "InboxConcernedName")
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
		var club_link := _nom_lien(app, card, Rect2(cursor, y, 340, _h(40)), "club", str(club.id), "%s · %s" % [club.name, rank], 20, C.IVORY, "InboxConcernedClub")
		club_link.accessibility_name = "Ouvrir la fiche de " + str(club.name)
		cursor += 350.0
	if data.has("expiring"):
		var players: Array = data.expiring
		var shown := 0
		for index in mini(players.size(), 4):
			if cursor + 240.0 > limit: break
			var person: Dictionary = players[index]
			var chip := _nom_lien(app, card, Rect2(cursor, y, 230, _h(40)), "player", str(person.id), str(person.name), 19, C.IVORY, "InboxExpiryPlayer_" + str(index))
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
	var x := PAD
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
				card.add_child(link); D.place(link,Rect2(x,y,link_width,_h(40)))
			drew = true
	elif not focused and next is Dictionary and not next.is_empty():
		if draw:
			var prep := D.button(card,Rect2(x,y,link_width,_h(40)),"Dossier de préparation · "+str(next.get("label","Prochain match")),_open_related.bind(app,message,Callable(app,"_navigate").bind("Préparation")),false,"tactic",true,app.accent,"InboxPreparation")
			prep.tooltip_text = "Ouvrir l’analyse de la prochaine rencontre · " + P.fixture_date(next)
			C.style_bouton_lien(prep, 18)
		drew = true
	if drew: y += _h(40) + 14
	# Priorités de la semaine, pour un courrier d'information du club.
	if not focused:
		var tasks := _tasks(app).slice(0,3)
		if not tasks.is_empty():
			if draw: D.text(card,x,y+18,"PRIORITÉS DE LA SEMAINE",17,C.GOLD,700,400)
			var cell := (width - 32) / 3.0
			for index in tasks.size():
				if not draw: break
				var task: Array = tasks[index]
				var action := D.button(card,Rect2(x+index*(cell+16),y+30,cell,_h(40)),task[0],func():
					if task[1]=="Entraînement": app.Immersive.open_training(app)
					else: app._navigate(task[1]),false,"arrow",true,app.accent,"InboxRecommendation"+str(index))
				action.tooltip_text = task[0]
				C.style_bouton_lien(action, 17)
			y += _h(40) + 34
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
	var due := _deadline(app, message, true)
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

## Actions du mail, en bas, sur une rangée (au-dessus du rappel Espace).
## Libellé du bouton d'une invitation du club : « Ouvrir l’entretien » pour un entretien (staff, joueur),
## « Ouvrir l’invitation » pour les autres moments au club. Casse normale, style « action » du jeu.
static func scene_invitation_caption(scene: Dictionary) -> String:
	var title := str(scene.get("title", "")).to_lower()
	return "Ouvrir l’entretien" if title.contains("entretien") else "Ouvrir l’invitation"

static func _action_rect(index: int, top: int) -> Rect2:
	var width := minf(520.0, (_reading_width() - 18) / 2.0)
	return Rect2(PAD + index * (width + 18), top, width, _h(46))

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
				var action := D.button(card,_action_rect(0,top),caption,_open_related.bind(app, message, app._open_press_invitation.bind(invitation.id)),true,"arrow",false,app.accent,"InboxOpenPressInvitation")
				action.disabled = app.waiting or (not receipt and (not conference.get("available", false) or conference.get("invitationId") != invitation.id))
				if action.disabled: action.tooltip_text = str(conference.get("reason", ""))
				# Conférence ordinaire seulement (le moteur donne `moment` pour arrivée, phase finale, bilan, derby, crise).
				if not receipt and conference.get("available", false) and conference.get("invitationId") == invitation.id and not conference.get("moment") is Dictionary:
					_press_policy_toggle(card, app, _action_rect(1,top))
	elif message.has("scene_invitation"):
		var scene: Dictionary = message.scene_invitation
		var open := D.button(card,_action_rect(0,top),scene_invitation_caption(scene),func():
			if is_instance_valid(app.contextual_director): app.contextual_director.open_invitation(str(scene.id)),true,"arrow",false,app.accent,"InboxOpenSceneInvitation")
		var blocking := _blocking(app)
		open.disabled = app.waiting or not blocking.is_empty()
		if not blocking.is_empty(): open.tooltip_text = "Disponible après " + app.contextual_director.meeting_label(blocking) + "."
	elif message.has("club_mail"):
		var mail: Dictionary = message.club_mail
		var ecran := str(mail.get("ecran",""))
		var joueur := str(mail.get("joueur","")) if mail.get("joueur") is String else ""
		D.button(card,_action_rect(0,top),ClubMail.caption(ecran),_open_related.bind(app, message, ClubMail.open_screen.bind(app, ecran, joueur)),not ClubMail.awaiting(app.model, mail),"arrow",false,app.accent,"InboxClubMailOpen")
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
				D.button(card,_action_rect(0,top),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenInternational")
		elif destination in ["international", "national_job"]:
			var caption := "Voir les offres de sélection" if destination == "national_job" else "Ouvrir les sélections"
			if _has_match_sheet(app, event): caption = "Préparer la feuille de match"
			elif _is_club_return(app, event): caption = "Voir l’effectif"
			D.button(card,_action_rect(0,top),caption,_open_related.bind(app, message, _open_international.bind(app,event)),true,"arrow",false,app.accent,"InboxOpenInternational")
	else:
		var caption := "Ouvrir · " + str(message.route)
		var open := Callable(app, "_navigate").bind(message.route)
		if message.get("season_expiry", false):
			var current := _current_expiry_roster(app.model)
			if not current.is_empty():
				caption = "Voir les échéances actuelles (%d)" % current.count
				open = _open_expiry_roster.bind(app, current.roster)
		D.button(card,_action_rect(0,top),caption,_open_related.bind(app, message, open),true,"arrow",false,app.accent,"InboxOpenMessageAction")
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

## Hauteur de la rangée de réponses d'un mail du club qui en attend une (0 sinon).
static func _reply_row(app: Control, message: Dictionary) -> float:
	return _h(46) + 10 if message.has("club_mail") and ClubMail.awaiting(app.model, message.club_mail) else 0.0

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

static func _subject(message: String) -> String:
	var colon := message.find(":")
	if colon >= 8 and colon <= 63: return message.left(colon).strip_edges()
	var period := message.find(". ")
	if period > 0 and period <= 72: return message.left(period).strip_edges()
	var words := D.words(message,70,1)
	return words[0]+("…" if words[0]!=message else "") if not words.is_empty() else "Message du club"

static func _icon(parent: Control, id: String, rectangle: Rect2, color: Color) -> void:
	var icon := C.icon(id, int(rectangle.size.x), color)
	parent.add_child(icon)
	D.place(icon,rectangle)

static func _metric(parent: Control, rectangle: Rect2, icon: String, value: String, color: Color) -> void:
	var tile := D.rect(parent,rectangle,Color(color,.10),6,Color(color,.6))
	_icon(tile,icon,Rect2(15,11,22,22),color)
	D.text(tile,47,29,value,20,C.IVORY,700,rectangle.size.x-94)

static func _redraw(app: Control, focus: String) -> void:
	var state := _state(app)
	var scroll: ScrollContainer = app.root_content.find_child("InboxMessageScroll",true,false)
	if is_instance_valid(scroll) and not focus.begins_with("InboxFolder") and not focus.begins_with("InboxActivity") and focus!="InboxSort" and focus!="InboxSubject":
		state.scroll = scroll.scroll_vertical
	app._render()
	var action: Control = app.root_content.find_child(focus,true,false)
	if action == null: action=app.root_content.find_child("InboxFolder"+str(state.folder),true,false)
	if action != null: _focus.call_deferred(action)

static func _focus(action: Control) -> void:
	if is_instance_valid(action) and action.is_inside_tree(): action.grab_focus()


## Portrait de l'expéditeur d'un courrier (banque d'images, par fonction) ; sinon le staff habituel.
static func portrait_expediteur(expediteur: String) -> String:
	var f := U.fold(expediteur)
	var id := ""
	for paire: Array in [[["president"], "staff-president"], [["directeur sportif", "direction sportive"], "staff-directeur-sportif"],
			[["secretariat", "secretaire"], "staff-secretaire-general"], [["medecin", "medical", "infirmerie"], "staff-medecin"],
			[["kine"], "staff-kine"], [["preparat", "physique"], "staff-prepa-physique"], [["analys", "video"], "staff-analyste"],
			[["recrut", "cellule de recrutement"], "staff-recruteur"], [["adjoint", "entraineur", "staff"], "staff-adjoint"],
			[["quotidien", "journal", "presse", "redaction"], "presse-journaliste"], [["television", "tele", "consultant"], "presse-consultant-tv"],
			[["supporter", "abonne", "tribune"], "supporter-ancien"], [["agent"], "agent-joueur"], [["sponsor", "partenaire"], "sponsor-dirigeant"],
			[["arbitr", "ligue", "federation", "commission"], "arbitre"]]:
		for mot: String in paire[0]:
			if id.is_empty() and mot in f: id = paire[1]
	return id if not id.is_empty() and BanqueImages.texture(id) != null else "mail-staff"
