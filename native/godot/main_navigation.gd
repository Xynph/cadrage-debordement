extends RefCounted
## Coque du jeu (main.gd) : changement d'écran (routes), accès à la presse (conférence, après-match) et bouton
## principal « Continuer » (libellé, info-bulle, action, jour suivant).
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const CareerProgression = preload("res://ui/career_progression.gd")
const Immersive = preload("res://ui/immersive08/shell.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

static func navigate(m: Control, target: String, remember_ui: bool, keep_subview: bool) -> void:
	if is_instance_valid(m.contextual_director) and m.contextual_director.active_meeting():
		m.contextual_director.render_if_needed()
		return
	if is_instance_valid(m.contextual_director) and m.contextual_director.match_immersed() and target != "Match":
		m.contextual_director.render_if_needed()
		return
	# Presse s'ouvre aussi depuis le rail, hors conférence (journal, archives) ; la conférence elle-même
	# reste derrière son courrier (press_view.gd : « Ouvre l'invitation dans Réception »).
	if target == "Sélections" and not m.model.get("international") is Dictionary: return
	if not Immersive.Selections.navigation_allowed(m.model, target): return
	if is_instance_valid(m.navigation_controller): m.navigation_controller.capture_current()
	if target != "Presse" and m.has_meta("press_mail_origin"): m.remove_meta("press_mail_origin")
	if not keep_subview:
		if target == "Effectif": m.set_meta("immersive08_full_player",false)
		# Fiche joueur d'une piste ou d'un Espoir : le menu rouvre l'écran lui-même.
		m.management_ui.erase("fiche_joueur")
		# Sous-page de la Composition (tireurs, espoir, renforts) : le menu rouvre l'écran lui-même.
		m.management_ui.erase("composition_page")
		# Onglet de la Tactique (Consignes, Phases arrêtées, Entraînement) : le menu rouvre la Composition.
		m.management_ui.erase("tactique_onglet")
		# Sous-page de Classements (rencontre, archives) : le menu rouvre l'écran lui-même.
		m.management_ui.erase("competition_page")
		# Sous-page du Recrutement (relève, entre clubs, offres, missions, négociation, rapport) : le menu rouvre l'écran lui-même.
		if m.management_ui.has("recrutement_page"): load("res://ui/immersive08/recruitment_canvas.gd").oublier_page(m)
		# Sous-page de la Formation (suivi des jeunes, revue d'effectif) : le menu rouvre l'écran lui-même.
		if m.management_ui.has("formation_page"): load("res://ui/immersive08/formation_pages.gd").oublier(m)
		# Sous-page du Staff (contrat, mentorat, engagements) : refermée en changeant d'écran.
		m.management_ui.erase("club_page")
		m.management_ui.erase("charge_joueur")
		# Sous-page de l'avant-match (délégation, espoir) : refermée dès qu'on change d'écran.
		m.management_ui.erase("avant_page")
		if m.management_ui.get("preparation") is Dictionary: m.management_ui.preparation.sub = ""
		if target == "Préparation" and m.management_ui.get("preparation", {}).get("tab", 0) == 2:
			m.management_ui.preparation.tab = 0
	m.route = target
	for chapter: Dictionary in m.NAV_CHAPTERS:
		if target in chapter.routes: m.chapter_routes[chapter.label] = target
	m._render(remember_ui)
	if is_instance_valid(m.soundscape): m.soundscape.refresh_visibility(m.route,m._match_visible())

static func reset_reception(m: Control, selected: String) -> void:
	var inbox: Dictionary = Immersive.Reception._state(m)
	inbox.merge({"folder":0, "category":"Tous", "selected":selected, "oldest_first":false, "scroll":0, "press_opened":"", "activity_filter":"all", "expanded_threads":{}, "return_focus":false}, true)

## Bouton « Conf. de presse » (et accès depuis les invitations bloquées) : ouvre directement la conférence attendue,
## son courrier sélectionné et lu en Réception, au lieu de laisser la Réception sur un autre courrier
## (recette native du 16/11/2026). Sans conférence ouverte : la Réception, comme avant.
static func open_press_conference(m: Control) -> void:
	var id: String = m._pending_press_invitation()
	if id.is_empty():
		m._show_press_inbox()
		return
	# Le refus « Rendez-vous du club : … » demandait justement cette conférence : il ne reste pas affiché dans la salle.
	if str(m.last_error).begins_with("Rendez-vous du club"): m.last_error = ""
	m._reset_reception(id)
	var inbox: Dictionary = Immersive.Reception._state(m)
	inbox.press_opened = id
	m._navigate("Réception", false)
	m._open_press_invitation(id)

## Après-match (18/11/2026) : la salle de presse s'ouvre directement sur la conférence d'après-match ; sans elle
## (ancienne carrière, autre créneau), le courrier de la conférence comme avant.
static func open_postmatch_press(m: Control) -> void:
	var id: String = m._pending_press_invitation()
	if id.is_empty(): return
	m.set_meta("press_mail_origin", id)
	if is_instance_valid(m.contextual_director) and m.contextual_director.sync("postmatch_press", true): return
	m._open_press_conference()

static func open_press_invitation(m: Control, id: String) -> void:
	var inbox: Dictionary = m.management_ui.get("reception", {})
	if m.route != "Réception" or m.waiting or inbox.get("press_opened") != id: return
	var press: Dictionary = m.model.get("clubLife", {}).get("press", {})
	var conference: Dictionary = press.get("conference", {})
	var outcome: Variant = press.get("lastOutcome")
	var active: bool = conference.get("available", false) and conference.get("invitationId") == id
	if not active and not (outcome is Dictionary and outcome.get("invitationId") == id): return
	m.set_meta("press_mail_origin", id)
	m.management_ui.press_tab = 1
	m._navigate("Presse", false)

## « Jour suivant » (petit bouton du bandeau, Ctrl+J) : un seul jour, mêmes priorités que « Continuer ».
static func next_day_available(m: Control) -> bool:
	if not m._has_career() or not m._live().is_empty() or m._press_required(): return false
	if not Immersive.Selections.current_fixture(m.model).is_empty() or m.model.get("meta",{}).get("canAdvanceSeason",false): return false
	var daily: Dictionary = m._daily_progression()
	return daily.has("command") and not bool(daily.get("disabled", false))

static func next_day_action(m: Control) -> void:
	if m.waiting: return
	if not m.next_day_available():
		m.primary_action()
		return
	var fixture: Variant = null if Immersive.Selections.nation_only(m.model) else m.model.get("next")
	var step := CareerProgression.next_day(m.model.get("meta", {}), fixture)
	if not step.is_empty(): m._command(step.command, step.payload)

static func daily_progression(m: Control) -> Dictionary:
	var fixture: Variant = null if Immersive.Selections.nation_only(m.model) else m.model.get("next")
	return CareerProgression.daily(m.model.get("meta", {}), fixture, m.route)

## Info-bulle du bouton principal : pour « Continuer », le prochain arrêt prévu (career_progression.gd).
static func primary_tooltip(m: Control) -> String:
	if m.connection_error and m.bridge.child_pid <= 0: return "Le moteur du jeu s’est arrêté. Clique pour le relancer : la carrière reprend à sa dernière sauvegarde."
	if m._live().is_empty() and not m._press_required() and Immersive.Selections.current_fixture(m.model).is_empty() and not m.model.get("meta", {}).get("canAdvanceSeason", false):
		var daily: Dictionary = m._daily_progression()
		if daily.has("tooltip"): return str(daily.tooltip)
	return m.primary_text()

## Ce qui arrête Continuer, en raison courte (22 caractères au plus), ou "" quand il avance (ou passe au direct, au
## résultat, à la préparation du jour de match). Ne dépend pas de l'état désactivé du bouton : un clic ou Espace
## ouvre l'écran qui bloque (primary_action).
static func continue_block(m: Control) -> String:
	if m.connection_error and m.bridge.child_pid <= 0: return ""
	if not m._live().is_empty(): return ""
	if m._press_required(): return "Conférence de presse"
	if not Immersive.Selections.current_fixture(m.model).is_empty(): return "Courrier de match"
	if m.model.get("meta", {}).get("canAdvanceSeason", false): return ""
	var daily: Dictionary = m._daily_progression()
	if daily.has("open"): return "Décision attendue"
	if bool(daily.get("disabled", false)): return "Avance indisponible"
	return ""

static func primary_text(m: Control) -> String:
	if m.connection_error and m.bridge.child_pid <= 0: return "RELANCER LE MOTEUR  →"
	var live: Dictionary = m._live()
	if not live.is_empty():
		if live.get("finished",false) and is_instance_valid(m.contextual_director) and m.contextual_director.en_consultation(): return "RETOUR À L’APRÈS-MATCH  →"
		if live.get("finished",false): return "VALIDER LE RÉSULTAT  →"
		if m.route == "Préparation" and live.get("paused",false): return "RETOUR AU MATCH  →"
		return "RETOUR AU DIRECT  →"
	if m._press_required(): return "OUVRIR LA CONFÉRENCE DE PRESSE  →" if not m._pending_press_invitation().is_empty() else "OUVRIR LA RÉCEPTION  →"
	if not Immersive.Selections.current_fixture(m.model).is_empty(): return "OUVRIR LE COURRIER DE MATCH  →"
	if m.model.get("meta",{}).get("canAdvanceSeason",false): return "SAISON SUIVANTE  →"
	var daily: Dictionary = m._daily_progression()
	if not daily.is_empty(): return daily.label
	if not SeasonPreparation.data(m.model.get("meta",{})).is_empty(): return "AVANCER LA PRÉPARATION  →"
	if m.model.get("next") == null: return "AVANCER LA SEMAINE  →"
	return "ALLER AU JOUR DE MATCH  →" if m.route == "Préparation" else "PRÉPARER LE MATCH  →"

static func primary_action(m: Control) -> void:
	if m.waiting and (m.last_command != "tick" or not m.queued_action.is_empty()): return
	# Moteur arrêté (processus tué, mémoire saturée…) : « Continuer » le relance au lieu de rouvrir en boucle
	# l'écran de l'événement en attente, dont aucune décision ne pourrait être enregistrée.
	if m.connection_error and m.bridge.child_pid <= 0:
		m.reconnect()
		return
	if not m._live().is_empty():
		# Après-match consulté depuis un autre écran : Continuer ramène à l'après-match (le résultat s'y valide).
		if m._live().get("finished",false) and is_instance_valid(m.contextual_director) and m.contextual_director.en_consultation(): m.contextual_director.revenir_apres_match()
		elif m._live().get("finished",false): m._command("finish_round")
		else: m._navigate("Match")
		return
	if m._press_required():
		m._open_press_conference()
		return
	var international_fixture := Immersive.Selections.current_fixture(m.model)
	if not international_fixture.is_empty():
		m._reset_reception("international:match-day/" + str(international_fixture.id))
		m._navigate("Réception", false)
		return
	if m.model.meta.get("canAdvanceSeason",false):
		m.confirm("Une nouvelle saison", "Les contrats arrivés à échéance sont réglés et les mouvements de division sont appliqués. Commencer la saison suivante ?", func(): m._command("next_season",{"confirmed":true}))
		return
	var daily: Dictionary = m._daily_progression()
	if not daily.is_empty():
		if daily.has("open"): m._open_reprise_decision()
		elif daily.has("route"): m._navigate(daily.route)
		elif daily.has("command"): m._command(daily.command, daily.payload)
		# Avance refusée par le calendrier : Continuer n'est jamais inerte, il ouvre le calendrier du jour.
		elif bool(daily.get("disabled", false)) and m.route != "Calendrier": Immersive._open_current_calendar(m)
		return
	if not SeasonPreparation.data(m.model.meta).is_empty(): m._command(SeasonPreparation.command(m.model.meta),{"fromWeek":int(m.model.meta.get("week",0))})
	elif m.model.get("next") == null: m._command("finish_round")
	else: m._navigate("Match" if m.route == "Préparation" else "Préparation")
