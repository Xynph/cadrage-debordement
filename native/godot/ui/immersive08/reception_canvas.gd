extends RefCounted
## Réception, direction A « Bureau du manager » (maquette validée par Léo le 18/11/2026) : liste groupée par jour à
## gauche, mail en grand au centre (réponses en cartes avec leurs conséquences réelles), panneau « Concerné » à droite
## (joueur lié, échéance), gabarits presse (coupure de journal) et médical (tableau de l'infirmerie).
const Copy = preload("res://ui/management_copy.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const RoomIdentityCouleurs = preload("res://ui/contextual/rooms/room_identity.gd")
const C = preload("res://ui/immersive08/components.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const U = preload("res://ui/management_state.gd")
const Press = preload("res://ui/press_view.gd")
const Reading = preload("res://ui/immersive08/reception_reading.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const AgentJoueur = preload("res://ui/agent_joueur.gd")
const Liste = preload("res://ui/immersive08/reception_liste.gd")
const Lettre = preload("res://ui/immersive08/reception_lettre.gd")
const Coupure = preload("res://ui/immersive08/reception_coupure_infirmerie.gd")

const CATEGORIES = ["Tous", "Staff", "Médical", "Conseil", "Transferts", "Compétitions"]
const ICONS = {"Staff":"train", "Médical":"heart", "Conseil":"shield", "Transferts":"search", "Formation":"school", "Compétitions":"trophy", "Club":"mail", "Météo":"cloud"}
const COLORS = {"Staff":C.MINT, "Médical":C.ALERT, "Conseil":C.GOLD, "Transferts":C.BLUE, "Formation":C.MINT, "Compétitions":C.GOLD, "Club":C.MUTED, "Presse":C.GOLD, "Sélections":C.GOLD, "Calendrier":C.GOLD, "Invitation":C.GOLD, "Météo":C.BLUE}
const ROUTES = {"Staff":"Préparation", "Médical":"Effectif", "Conseil":"Club", "Transferts":"Recrutement", "Formation":"Formation", "Compétitions":"Calendrier", "Club":"Bureau", "Météo":"Composition"}
## Expéditeur affiché dans la liste et en tête du mail ouvert (le moteur ne signe que le courrier du club).
const SENDERS = {"Staff":"Staff technique", "Médical":"Service médical", "Conseil":"Direction du club", "Transferts":"Cellule de recrutement", "Formation":"Centre de formation", "Compétitions":"Organisateur des compétitions", "Club":"Secrétariat du club", "Météo":"Intendance du club"}
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
const SUBJECTS = ["Tous", "Staff", "Médical", "Conseil", "Transferts", "Formation", "Compétitions", "Météo", "Club"]
## Icône du service expéditeur (palette existante) ; un portrait n'est montré que pour une personne identifiée.
const SERVICE_ICONS = {"Presse":"globe", "Sélections":"flag", "Calendrier":"calendar", "Invitation":"people", "Staff":"train", "Médical":"heart", "Conseil":"shield", "Transferts":"search", "Formation":"school", "Compétitions":"trophy", "Club":"home", "Météo":"cloud"}
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
	# Rubriques renommées le 23/11/2026 (Direction → Conseil, Recrutement → Transferts) : un ancien filtre est repris.
	state.category = {"Direction":"Conseil", "Recrutement":"Transferts"}.get(str(state.get("category", "Tous")), str(state.get("category", "Tous")))
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
		if category == "Conseil" and "contrat" in folded: destination = "Effectif"
		if category == "Conseil" and ("tresorerie" in folded or "billetterie" in folded): destination = "Finances"
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
	if "recrutement" in message or "mercato" in message or "transfert" in message: return "Transferts"
	if "contrat" in message or "direction" in message or "president" in message or "tresorerie" in message or "billetterie" in message: return "Conseil"
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
	title.add_theme_font_override("font", C.Charte.TITRE_FICHE)
	title.name = "InboxPageTitle"
	var messages := _messages(app)
	var counts := Reading.counts(messages,app.model)
	var x := C.Charte.TITRE_FICHE.get_string_size("RÉCEPTION.", HORIZONTAL_ALIGNMENT_LEFT, -1, C.font_px(50)).x / C.density + 26.0
	var line := "%d non lus · %d à faire" % [unread(app),counts.todo]
	D.text(row,x,56,line,19,C.MUTED,500,560).name = "InboxPageCounts"
	if counts.urgent > 0:
		var after := x + C.font(500).get_string_size(line + " · ", HORIZONTAL_ALIGNMENT_LEFT, -1, C.font_px(19)).x / C.density
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
	Liste._list_filters(list, app, state, messages.filter(func(item: Dictionary): return not state.marks.get(item.id, {}).get("archived", false)), messages.filter(func(item: Dictionary): return _visible(item,category_view)))
	Liste._list(list,app,state,visible,entries)
	# Variante « Liste et lettre » : deux colonnes seulement. Plus de panneau fixe à droite : les joueurs, clubs et
	# rencontres cités sont des liens dans la lettre et sous elle (mini-fiche au survol d'un joueur).
	_w = DETAIL_WIDTH
	Lettre._detail(_surface(page,Rect2(LIST_WIDTH+GAP,0,_w,height),"InboxDetail"),app,state,current,height)
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

## Marque (lu, favori, archivé) tous les courriers représentés par une ligne.
static func _mark_members(state: Dictionary, message: Dictionary, key: String, value: bool) -> void:
	for id: String in members(message):
		var mark: Dictionary = state.marks.get(id, {})
		mark[key] = value
		if key == "archived": mark.read = true
		state.marks[id] = mark

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

## Agent nommé qui signe un courrier « Un agent de joueurs » (moteur : club_mail.agent) ; vide sinon.
static func _mail_agent(app: Control, message: Dictionary) -> Dictionary:
	var mail: Variant = message.get("club_mail")
	if not mail is Dictionary or str(mail.get("agent", "")).is_empty(): return {}
	return AgentJoueur.agent(app, str(mail.agent))

## Toile de la Réception (ImmersiveInbox) qui porte la petite fenêtre de l'agent.
static func _inbox_page(noeud: Node) -> Control:
	var n := noeud
	while n != null and str(n.name) != "ImmersiveInbox": n = n.get_parent()
	return (n if n != null else noeud) as Control

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

## Joueurs et clubs cités dans un texte, prêts à devenir des liens : [{start, end, kind, id}], sans chevauchement,
## triés dans l'ordre du texte. Seules les entités qui ont un écran de destination sont rendues (jamais de lien mort).
static func entities(app: Control, text: String) -> Array:
	return Lettre.entities(app, text)

## Texte du courrier en BBCode : chaque entité citée devient un lien « kind:id » (couleur or-encre, soulignée).
static func linked_text(text: String, found: Array) -> String:
	return Lettre.linked_text(text, found)

## Largeur de la colonne de lecture du mail (≈ 700 px de la maquette, jamais plus large que le mail).
static func _reading_width() -> float:
	return minf(_w - 2 * PAD, READING_MAX)

## Colonnes du tableau de l'infirmerie [titre, part de la largeur] ; « BLESSURE » est la plus large (noms longs).
## Hauteur maximale (px de mise en page) des lignes du tableau avant défilement sous l'en-tête figé.
const INFIRMARY_MAX_ROWS := 460.0

## Tableau de l'infirmerie (données réelles de la partie) : joueurs blessés et en reprise, retour estimé et statut
## pour la prochaine rencontre (forfait rouge, apte vert, risque doré).
static func infirmary_rows(model: Dictionary) -> Array[Dictionary]:
	return Coupure.infirmary_rows(model)

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

## Nombre de lignes d'un texte à retour à la ligne (police et taille du jeu, largeur en unités de mise en page).
static func wrapped_lines(text: String, font_size: int, width: float, font: Font = C.BODY) -> int:
	var pixels := maxi(12, C.px(font_size))
	var flags := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, C.px(width)), pixels, -1, flags)
	return maxi(1, roundi(size.y / maxf(1.0, font.get_height(pixels))))

## Actions du mail, en bas, sur une rangée (au-dessus du rappel Espace).
## Libellé du bouton d'une invitation du club : « Ouvrir l’entretien » pour un entretien (staff, joueur),
## « Ouvrir l’invitation » pour les autres moments au club. Casse normale, style « action » du jeu.
static func scene_invitation_caption(scene: Dictionary) -> String:
	var title := str(scene.get("title", "")).to_lower()
	return "Ouvrir l’entretien" if title.contains("entretien") else "Ouvrir l’invitation"

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
