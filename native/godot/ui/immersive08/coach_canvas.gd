extends "res://ui/immersive08/coach_bureau.gd"
## Le guide de carrière utilise le portrait 3D quand son GLB est installé (ou le Gabi Mixamo privé,
## voir coach_portrait_3d.gd).
##
## Gabi adjoint (choix de Léo, 13/11/2026 à 23h53 : option « A + C ») :
## A. Gabi vit dans le bandeau du haut (shell.gd, zone « GabiBandeau ») : son visage 3D animé dans un disque,
##    sa remarque du moment sur une ligne (défilante si longue, façon fil d'info), un indice discret (point
##    or et carnet) quand il a quelque chose à dire. Un clic ouvre son avis (« Ton avis, Gabi ? » + menu :
##    aide de l'écran, visite guidée) dans une bulle qui descend du bandeau, se ferme d'un clic ailleurs
##    et ne reste pas ouverte. Il ne recouvre rien et ne prend aucune place : le bandeau existait déjà.
## C. Au Bureau, Gabi est chez lui : debout, en entier (3D animé, carnet contre lui), dans une vraie zone de
##    l'écran (office_canvas.gd, « GabiBureau »), sous son carnet de la semaine (gabi_semaine.gd).
## Conservés de #684 : conseils avec « Suivre le conseil » (composition, recrutement, et au Bureau le conseil
## de la semaine), moments clés en grand avec écran assombri (début de carrière, veille de finale, fin de
## saison, grosse crise), limite d'une bulle spontanée par jour de jeu, réglage pour couper Gabi.
## Le médaillon du coin bas droit, la bande basse réservée et la réduction de la mise en page sont retirés.
## Fichier public de l'écran (contexte : moments clés, première visite, humeur, alertes ; rafraîchissement, ouverture, fermeture) ; le reste vit dans la chaîne
## coach_guide.gd ← coach_socle.gd ← coach_bulle.gd ← coach_bandeau.gd ← coach_bureau.gd ← coach_canvas.gd.

func consider_context(route: String, model: Dictionary, command: String, response_ok: bool) -> void:
	# Nouvelle carrière : les deux semaines de Gabi repartent du jour de la création (« je connais déjà » les coupe).
	if is_instance_valid(app) and Accueil.observer(profile, model, command, response_ok, bool(app.get_meta("creation_connu", false))):
		if bool(app.get_meta("creation_connu", false)): _sans_accueil(model)
	if is_instance_valid(_bulle) and is_instance_valid(app) and app._has_career() and profile.data.enabled and route not in ["Accueil", "Création", "Packs"] and not _adjoint_actif():
		# Écran de carrière dont le bandeau n'est pas encore construit : on attend qu'il le soit (_process)
		# plutôt que d'ouvrir l'ancienne bulle flottante.
		var live: Dictionary = app._live()
		if live.is_empty() or live.get("finished", false):
			_contexte_examine = ""
			return
	if not is_instance_valid(_bulle) or not _adjoint_actif():
		super.consider_context(route, model, command, response_ok)
		return
	if not response_ok or app.waiting or app.closing or expanded: return
	if app.connection_error or not str(app.last_error).is_empty(): return
	_humeur(model)
	if _blocked(): return
	if _moment_cle(model): return
	if _accueil(route, model):
		_maj_indice()
		return
	super.consider_context(route, model, command, response_ok)
	_conseil_composition(route, model)
	_alerte_bleus(model)
	_alerte_fatigue(model)
	_maj_indice()

## « Je connais déjà » : pas d'accueil en grand ni de carte des premiers pas pour cette carrière.
func _sans_accueil(model: Dictionary) -> void:
	var context := _career_context(model)
	if context.is_empty(): return
	var parts := context.split(":")
	var cle := "debut:%s:%s:0:" % [parts[0], parts[1]]
	if cle not in profile.data.events:
		profile.data.events.append(cle)
		while profile.data.events.size() > Profile.EVENT_LIMIT: profile.data.events.pop_front()
		profile.save_profile(profile.data)

## Deux premières semaines : explication courte au premier passage sur un écran clé, hors limite quotidienne,
## y compris sur la composition et avant le coup d'envoi (jamais pendant le direct ni sur une fenêtre ouverte).
func _accueil(route: String, model: Dictionary) -> bool:
	var dit := Accueil.a_dire(route, model, profile.data)
	if dit.is_empty() or _has_dialog(app): return false
	var live: Dictionary = app._live()
	if not live.is_empty() and not live.get("paused", false) and not live.get("finished", false): return false
	# Une bulle déjà ouverte sur cet écran (accueil du club, conseil) n'est pas écrasée : on repassera.
	if _bulle.visible and _contenu.get("genre") != "fait": return false
	_montrer({"genre": "accueil", "titre": str(dit.titre), "texte": str(dit.texte), "actions": dit.actions, "categorie": "consigne", "ton": Avis.NEUTRE, "route": route})
	Accueil.marquer(profile, str(dit.cle))
	return true

## Moments clés (mode grand, écran assombri) : une seule fois chacun (clé dans le profil du guide).
func _moment_cle(model: Dictionary) -> bool:
	var context := _career_context(model)
	if context.is_empty(): return false
	var parts := context.split(":")
	var keys := {
		"debut": "debut:%s:%s:0:" % [parts[0], parts[1]],
		"finale": "finale:%s:%s:%s:" % [parts[0], parts[1], parts[2]],
		"crise": "crise:%s:%s:0:" % [parts[0], parts[1]],
	}
	var due := ""
	if keys.debut not in profile.data.events: due = "debut"
	elif Avis.finale(model) and keys.finale not in profile.data.events: due = "finale"
	elif Avis.crise(model) and keys.crise not in profile.data.events: due = "crise"
	if due.is_empty(): return false
	var moment: Array = MOMENTS_CLES[due]
	# Le voile assombri est réservé aux vrais moments clés (arrivée au club) et jamais posé sur un écran ou une
	# fenêtre de décision (composition, match, préparation) : ailleurs, Gabi le dit dans le bandeau (indice ou bulle).
	if due == "debut" and _grand_permis():
		super._deliver_context(moment[0], {"id": "moment-" + due, "text": moment[1]}, "", keys[due])
		_moment_courant = keys[due] if expanded else ""
		return true
	if due == "debut" and not _adjoint_actif(): return false
	if str(_attente.get("event", "")) == keys[due]: return true
	_dans_le_bandeau(moment[0], {"id": "moment-" + due, "text": moment[1]}, keys[due], "GABI")
	return true

## Première visite d'un écran, contrat signé, fin de saison, trésorerie : la fin de saison et un compte
## dans le rouge sont des moments clés (mode grand) ; le reste passe par le bandeau (bulle ou indice).
func _deliver_context(id: String, fragment: Dictionary, visit: String, event: String) -> void:
	# Grand mode (voile) : sans bandeau, ou fin de saison hors écran de décision ; la trésorerie passe par le bandeau.
	if not _adjoint_actif() or (event.begins_with("season:") and _grand_permis()):
		super._deliver_context(id, fragment, visit, event)
		return
	var fragments: Array = Content.fragments(id)
	var short: Dictionary = fragment
	# La bulle du bandeau prend la version courte (première bulle numérotée) plutôt que le portrait complet.
	if event.is_empty() and fragments.size() > 1 and str(fragment.get("id", "")).ends_with("-caractere"): short = fragments[1]
	var page: Array = Content.page(id)
	var moment: Dictionary = Moments.moment(id, str(short.get("id", "")), app.model)
	var message := {"genre": "contexte", "titre": "GABI · " + str(page[1]).to_upper(), "texte": str(short.get("text", "")), "categorie": moment.categorie, "ton": moment.ton, "route": str(app.route), "visit": visit, "event": event}
	if event.is_empty():
		# Réplique spontanée : l'information utile d'abord (gabi-repliques.cjs), l'ambiance seulement en complément et plus rarement.
		message = _replique_utile(message, str(short.get("text", "")))
		if message.is_empty(): return
	if _bulle_permise() and _spontane_permis():
		_consommer(message)
		_montrer(message)
	else:
		_attente = message
		_maj_indice()

## Remplace la réplique d'ambiance par l'information utile du moteur (`model.gabi`), avec son bouton d'action.
## Retourne {} quand il n'y a rien d'utile à dire et que l'ambiance n'est pas de tour : Gabi se tait.
func _replique_utile(ambiance: Dictionary, texte_ambiance: String) -> Dictionary:
	var gabi: Dictionary = app.model.get("gabi", {}) if app.model.get("gabi") is Dictionary else {}
	var utile: Dictionary = gabi.get("replique", {}) if gabi.get("replique") is Dictionary else {}
	var complement := bool(gabi.get("ambiance", false)) and not texte_ambiance.is_empty()
	if utile.is_empty() or _infos_dites.has(str(utile.get("cle", ""))):
		# Rien de nouveau : l'ambiance seule n'ouvre une bulle que quand elle est de tour.
		return ambiance if complement and utile.is_empty() else {}
	var message: Dictionary = ambiance.duplicate(true)
	message.texte = str(utile.texte) + ("\n" + texte_ambiance if complement else "")
	message.titre = "GABI · " + {"courrier": "COURRIER", "feuille": "LA FEUILLE", "blesses": "INFIRMERIE", "condition": "CONDITION", "contrat": "CONTRATS", "match": "PROCHAIN MATCH"}.get(str(utile.get("genre", "")), "UN MOT")
	message.categorie = "mise_en_garde" if str(utile.get("genre", "")) in ["feuille", "blesses", "condition", "contrat"] else "consigne"
	message.ton = Avis.NEUTRE
	if utile.get("action") is Dictionary: message.action = (utile.action as Dictionary).duplicate(true)
	message.info = str(utile.get("cle", ""))
	return message

## Avant la validation d'une composition (jour de match) : si Gabi changerait quelqu'un, il le signale.
func _conseil_composition(route: String, model: Dictionary) -> void:
	if Avis.ecran(route, model) != "composition" or route == "Match" or not Avis._jour_de_match(model): return
	if _ecartes.has(_cle_conseil(route)) or (_bulle.visible and _contenu.get("genre") == "avis"): return
	var avis := Avis.composition(model)
	if avis.get("action", {}).is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · AVANT DE VALIDER", "route": route})
	if _attente.get("texte", "") == message.texte: return
	if _spontane_permis(): _montrer(message)
	else: _attente = message

## Alerte de fatigue : des titulaires de la feuille du prochain match sont sous 70 % de condition. Gabi le
## signale avec « Suivre le conseil » (ils soufflent, remplacés par le meilleur remplaçant frais au poste).
## Une alerte par jour de jeu au plus (clé dans le profil du guide), sur n'importe quel écran : la bulle s'ouvre
## d'elle-même si la limite des interventions spontanées le permet, sinon Gabi l'indique dans le bandeau.
func _alerte_fatigue(model: Dictionary) -> void:
	var avis := Avis.fatigue(model)
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	var context := _career_context(model)
	if context.is_empty(): return
	# Clé du profil : « fatigue:club:saison:semaine:jour » (jour = numéro de jour en hexadécimal), au format que
	# le profil du guide accepte (guide_profile.gd) ; une clé hors format ferait refuser toute écriture du profil.
	var jour := int(Time.get_unix_time_from_datetime_string(str(meta.get("calendarToday", meta.get("date", ""))) + "T00:00:00") / 86400.0)
	var event := "fatigue:%s:%x" % [context, maxi(jour, 0)]
	var attente_event := str(_attente.get("event", ""))
	# Alerte périmée (autre jour, ou plus personne de fatigué sur la feuille) : elle disparaît du bandeau.
	if attente_event.begins_with("fatigue:") and (avis.is_empty() or attente_event != event): _attente.clear()
	if avis.is_empty() or event in profile.data.events or attente_event == event: return
	if not _attente.is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · FATIGUE", "route": str(app.route), "partout": true, "event": event})
	if _spontane_permis():
		_consommer(message)
		_montrer(message)
	else: _attente = message

## Protocole des Bleus : un joueur de la liste de 33 doit souffler ce week-end. Une alerte par jour de jeu au plus
## (même mécanique que l'alerte de fatigue), avec « Suivre le conseil » pour changer la composition.
func _alerte_bleus(model: Dictionary) -> void:
	var avis := Avis.repos_bleus(model)
	var meta: Dictionary = model.get("meta", {}) if model.get("meta") is Dictionary else {}
	var context := _career_context(model)
	if context.is_empty(): return
	var jour := int(Time.get_unix_time_from_datetime_string(str(meta.get("calendarToday", meta.get("date", ""))) + "T00:00:00") / 86400.0)
	var event := "bleus:%s:%x" % [context, maxi(jour, 0)]
	var attente_event := str(_attente.get("event", ""))
	if attente_event.begins_with("bleus:") and (avis.is_empty() or attente_event != event): _attente.clear()
	if avis.is_empty() or avis.get("action", {}).is_empty() or event in profile.data.events or attente_event == event: return
	if not _attente.is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · PROTOCOLE DES BLEUS", "route": str(app.route), "partout": true, "event": event})
	if _spontane_permis():
		_consommer(message)
		_montrer(message)
	else: _attente = message

## Humeur après un match : joie après une victoire, mine sombre après une défaite (une fois par match).
func _humeur(model: Dictionary) -> void:
	var humeur := Avis.humeur(model)
	if str(humeur.cle).is_empty() or humeur.cle == _humeur_cle: return
	var first := _humeur_cle.is_empty()
	_humeur_cle = humeur.cle
	_moment_portraits({"id": humeur.cle, "categorie": humeur.categorie if not first else "consigne", "ton": humeur.ton})
	if first: return  # Résultat déjà connu à l'ouverture de la partie : simple ton, sans réaction.
	var dernier := Avis.dernier_resultat(model)
	var texte: String = {
		"victoire": "On a gagné %d-%d contre %s. Savoure ce soir ; demain, on regarde ce qui a coincé, il y a toujours quelque chose.",
		"defaite": "On a perdu %d-%d contre %s. Pas de coupable ce soir : on en reparle demain, à froid, le carnet ouvert.",
		"nul": "Match nul, %d-%d contre %s. Ni fête ni drame : un point, ça se garde au chaud.",
	}.get(str(dernier.get("issue", "")), "")
	if texte.is_empty(): return
	_attente = {"genre": "humeur", "titre": "GABI · APRÈS LE MATCH", "texte": texte % [dernier.pour, dernier.contre, dernier.adversaire], "categorie": humeur.categorie, "ton": humeur.ton, "route": str(app.route), "partout": true}

func refresh() -> void:
	var moment := _moment_courant if expanded and mode == "context" else ""
	super.refresh()
	if not moment.is_empty() and not expanded and moment in profile.data.events:
		# Fermé par une fenêtre ou un blocage, pas par le coach : le moment reviendra.
		profile.data.events.erase(moment)
		profile.save_profile(profile.data)
		_contexte_examine = ""
	if not expanded: _moment_courant = ""
	if is_instance_valid(_bulle):
		if not _safe: fermer_bulle()
		_maj_indice()

func _show_context(id: String, fragment: Dictionary) -> void:
	fermer_bulle()
	super._show_context(id, fragment)

func _open() -> void:
	fermer_bulle()
	var was_disabled: bool = not profile.data.enabled
	super._open()
	# Gabi réactivé (F1, aide) : le bandeau et le Bureau le retrouvent.
	if was_disabled and profile.data.enabled and is_instance_valid(app) and app._has_career(): app.call_deferred("_render")

func disable() -> void:
	fermer_bulle()
	super.disable()
	# Gabi coupé : le bandeau se vide et le Bureau reprend sa mise en page classique.
	if is_instance_valid(app) and app._has_career(): app.call_deferred("_render")

func _avoid_primary_controls() -> void:
	# Mode grand : une courte scène, écran assombri ; Gabi garde sa place de base (coin bas)…
	# … sauf s'il y recouvre une commande principale (« Approcher le joueur » du Recrutement, validation) :
	# il prend alors la place libre que calcule l'évitement commun. Sans ce recours, la liste des commandes
	# protégées (OfferRecruitment…) restait sans effet tant que le bandeau de Gabi était en service.
	if is_instance_valid(_bulle) and _adjoint_actif():
		if not expanded or not visible: return
		var rects := _priority_rects()
		if not _covers_priority(rects): return
	if _place_in_creation_slot(): return
	super._avoid_primary_controls()

## Création (bandeau du haut) et Packs (pied de page) : les boutons compacts occupent l'emplacement réservé.
func _place_in_creation_slot() -> bool:
	if expanded or _error_panel.visible or not is_instance_valid(app) or str(app.route) not in ["Création", "Packs"]: return false
	if not is_instance_valid(app.root_content): return false
	var packs := str(app.route) == "Packs"
	# Packs : la place est dans le pied de page, sous son filet (marge garantie avec le filet).
	var slot := app.root_content.find_child("PacksGabiSlot" if packs else "CreationGabiSlot", true, false) as Control
	if slot == null or not slot.is_visible_in_tree(): return false
	var rect := slot.get_global_rect()
	if rect.size.x < size.x: return false
	if packs:
		if not Rect2(Vector2.ZERO, app.size).encloses(rect): return false
	elif rect.position.y >= app.size.y * .5: return false
	global_position = rect.position + (rect.size - size) / 2.0
	return true

func destroy() -> void:
	if is_instance_valid(_voile): _voile.queue_free()
	super.destroy()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_bulle): return
	if (not _file.is_empty() or not _file_message.is_empty()) and not app.waiting:
		if not app.bridge.last_response_ok or not str(app.last_error).is_empty():
			_file.clear(); _file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": "Le changement n'est pas passé : " + str(app.last_error) + " On regardera autrement.", "categorie": "regret", "ton": Avis.NEGATIF})
		else:
			_suite_file()
	if _bulle.visible:
		if _contenu.get("route", "") != str(app.route) or not _adjoint_actif(): fermer_bulle()
		elif _file.is_empty() and not _bulle.get_global_rect().has_point(get_viewport().get_mouse_position()):
			_bulle_reste -= delta
			if _bulle_reste <= 0.0: fermer_bulle()
	# Le premier écran d'une carrière se construit avant le bandeau : on réexamine le contexte une fois
	# Gabi en place (début de carrière, première visite).
	if not app.waiting and not expanded and _adjoint_actif():
		var context := _career_context(app.model)
		if not context.is_empty() and context + "|" + str(app.route) != _contexte_examine:
			_contexte_examine = context + "|" + str(app.route)
			consider_context(str(app.route), app.model, "", true)
	# Deux premières semaines : l'explication de l'écran attend que la bulle soit libre.
	_accueil_attente -= delta
	if _accueil_attente <= 0.0:
		_accueil_attente = 0.5
		if app._has_career() and not app.waiting and Accueil.observer(profile, app.model, "", true, bool(app.get_meta("creation_connu", false))):
			if bool(app.get_meta("creation_connu", false)): _sans_accueil(app.model)
		if not app.waiting and not expanded and _adjoint_actif() and not _bulle.visible and app._has_career():
			_accueil(str(app.route), app.model)
	if is_instance_valid(_bulle_suivre) and _bulle.visible: _bulle_suivre.disabled = app.waiting or not app._live().is_empty()
	if _adjoint_actif():
		_maj_remarque()
		if not _bandeau_masque and not _bandeau_compact: _defiler(delta)
	_maj_pied()
