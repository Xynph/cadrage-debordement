extends RefCounted
## Coque du jeu (main.gd) : dialogue avec le moteur (commande envoyée, réponse reçue, refus, « Continuer » par
## tranches, affichage anticipé d'une décision, horloge du direct d'origine).
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const G = preload("res://ui/game_skin.gd")
const SeasonLabel = preload("res://ui/season_label.gd")
const CareerProgression = preload("res://ui/career_progression.gd")
const Optimistic = preload("res://ui/optimistic_decisions.gd")
const ClubMail = preload("res://ui/club_mail.gd")
const ScreenRefresh = preload("res://ui/screen_refresh.gd")
const PortraitWarmup = preload("res://ui/portrait_warmup.gd")
const Immersive = preload("res://ui/immersive08/shell.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const SquadViews = preload("res://ui/squad_views.gd")
const Rythme = preload("res://match_rythme.gd")
const Etat = preload("res://main_etat.gd")
## « Continuer » : tranche de calcul du moteur entre deux mises à jour du panneau (date qui défile, « Arrêter »).
const CONTINUE_SLICE_MS := 700
## Commandes de lecture pure (aucun changement d'état de carrière).
const READ_ONLY_COMMANDS := ["club_sheet"]

## Réponse du moteur, après la pose éventuelle du panneau d'entrée dans le direct (main.gd, _receive_model).
static func receive(m: Control, value: Dictionary, live_opening: bool) -> void:
	var receive_us := Time.get_ticks_usec()
	# Une lecture moteur sans changement d'état (fiche club) ne périme pas les lecteurs suspendus.
	if is_instance_valid(m.navigation_controller) and not (m.bridge.last_response_ok and m.last_command in READ_ONLY_COMMANDS): m.navigation_controller.invalidate_readers()
	if m._startup_trace and not m._startup_model_seen:
		m._startup_model_seen = true
		m._trace_startup("model.first")
	# A queued action can replace last_command below; keep this response's identity.
	var received_command: String = m.last_command
	var response_ok: bool = m.bridge.last_response_ok
	var route_before: String = m.route
	var reception_id := ""
	if received_command == CareerProgression.CONTINUE_COMMAND and is_instance_valid(m.continue_progress):
		if response_ok and value.get("meta", {}).get("advanceUntilEvent") is Dictionary: m.continue_progress.finish(value.meta.advanceUntilEvent)
		else: m.continue_progress.dismiss()
	if received_command == CareerProgression.CONTINUE_COMMAND and m._decision_due(value, response_ok): m.call_deferred("_open_reprise_decision")
	if response_ok and (received_command in ["advance_day", CareerProgression.CONTINUE_COMMAND, "preseason_advance", "finish_round", "next_season", "national_play_match"] or SeasonPreparation.is_advance(received_command)):
		reception_id = Immersive.Reception.new_priority(m.model, value)
	# Keep one uninterrupted wait when the player's action follows an automatic tick
	# or a light decision: the queued command keeps the same panel.
	# Entrée dans le direct : le panneau reste affiché jusqu'à la fin de la construction de la scène (retiré plus bas).
	if not live_opening and (not response_ok or m.queued_action.is_empty() or not (received_command == "tick" or Etat.shows_wait_panel(str(m.queued_action.get("command", ""))))):
		m.command_wait_overlay.dismiss()
	SquadViews.U.remember(m)
	m.model = value
	m.optimistic_edits = []
	# Décision suivante déjà en file et déjà affichée : elle reste affichée jusqu'à sa propre réponse.
	if response_ok and m.queued_action.get("optimistic") is Array: m.model = Optimistic.apply(m.model, m.queued_action.optimistic)
	if m.model.get("meta", {}).has("seasonStartYear"): SeasonLabel.start_year = int(m.model.meta.seasonStartYear)
	if m.decision_feedback != null: m.decision_feedback.complete(received_command, response_ok, value)
	if not m.preferences_loaded and not str(m.model.get("meta", {}).get("dataDir", "")).is_empty():
		m.preferences_loaded = true
		m.user_preferences.load_profile(str(m.model.meta.dataDir))
		if m.soundscape_ready: m.sound_profile_loaded = m.soundscape.load_profile(str(m.model.meta.dataDir))
		m._apply_user_preferences()
	SquadViews.U.sync(m, m.bridge.last_response_ok and m.last_command in ["new_career","import","recover_profile","restore_checkpoint"])
	if m.bridge.last_response_ok and m.last_command in ["new_career","import","recover_profile","restore_checkpoint"]:
		if is_instance_valid(m.navigation_controller): m.navigation_controller.reset()
		for key in ["press_draft_context", "press_draft_choices", "press_mail_origin"]:
			if m.has_meta(key): m.remove_meta(key)
	if m.model.get("meta", {}).get("catalogue") is Array:
		m.catalogue = m.model.meta.catalogue.duplicate(true)
	m.waiting = false
	if SeasonPreparation.is_advance(received_command): SeasonPreparation.show_pending(m, false)
	m.connection_error = false
	if m._has_career():
		m.accent = Color("106d43") if Immersive.Selections.nation_only(m.model) else Color(G.identity(m.model.club).get("color", "#d43e47"))
	if not m.export_path.is_empty() and not m._write_export():
		if live_opening: m.command_wait_overlay.dismiss()
		if is_instance_valid(m.soundscape): m.soundscape.observe_model(m.model,m.route,received_command,m._match_visible(),response_ok)
		return
	if m.bridge.last_response_ok and received_command not in ["epcr_preview", "competition_editor_preview"]: m.last_error = ""
	if response_ok:
		if not m.pending_route.is_empty(): m.route = m.pending_route
		m.pending_route = ""
		if m._has_career() and (received_command in ["new_career", "next_season", "finish_round", "restore_checkpoint"] or not reception_id.is_empty()):
			m._reset_reception(reception_id)
			if m.has_meta("press_mail_origin"): m.remove_meta("press_mail_origin")
			m.route = "Réception"
			# Après-match façon FM (18/11/2026) : la conférence courte s'ouvre dès la validation du résultat, sans
			# arrêt de « Continuer » en plus.
			if received_command == "finish_round" and m._press_required(): m.call_deferred("_open_postmatch_press")
		# Arrêt « À noter » de « Continuer » (façon FM) : tous les éléments du jour sont en Réception, le plus récent en tête.
		elif received_command == CareerProgression.CONTINUE_COMMAND and m._stop_kind(m.model) == "a_noter":
			m._reset_reception()
			m.route = "Réception"
		# Arrêt informatif (veille, rapport médical, mi-saison, marché, recruteur, courrier du club) : l'écran utile
		# s'ouvre directement (ui/club_mail.gd), comme dans Football Manager.
		elif received_command == CareerProgression.CONTINUE_COMMAND and m._stop_kind(m.model) == "info":
			var info_route := ClubMail.stop_route(m, m.model.meta.advanceUntilEvent.stop)
			if not info_route.is_empty(): m.route = info_route
	if m.bridge.last_response_ok and m.last_command in ["new_career","next_season","import","restore_checkpoint"] and m._has_career():
		m.table_division = str(m.model.meta.get("leagueId", "elite"))
	if response_ok and received_command == "match_talk_continue" and m._live().is_empty():
		m.route = "Réception"
	var contextual_handled: bool = is_instance_valid(m.contextual_director) and m.contextual_director.sync(received_command, response_ok)
	if contextual_handled:
		pass
	elif m.last_command == "tick" and m.route not in ["Accueil", "Création"]:
		m._update_live_bar()
		if m.route == "Bureau": Immersive.Office.update_live_card(m)
		if is_instance_valid(m.match_screen): m.match_screen.update_frame(m.model)
	else:
		# Le passage de l'avant-match (hors coque) au direct (dans la coque), ou l'inverse, redessine tout l'écran.
		var coque_change: bool = m.route == "Match" and Immersive.avant_match_hors_coque(m) != bool(m.get_meta("hors_coque", false))
		if m.route == "Match" and is_instance_valid(m.match_screen) and not coque_change:
			m._update_live_bar()
			m._update_header_date()
			m.match_screen.update_frame(m.model)
		# Changement d'écran, de boîte de réception, de carrière ou avance du calendrier : toujours le rendu complet.
		else: m._refresh_after_response(response_ok, coque_change or m.route != route_before or not reception_id.is_empty() or received_command in ["new_career", "import", "recover_profile", "restore_checkpoint", "next_season", "finish_round", "advance_day", CareerProgression.CONTINUE_COMMAND] or SeasonPreparation.is_advance(received_command))
	if m.bridge.last_response_ok:
		if is_instance_valid(m.status):
			m.status.text = m._status_line_text()
			m.status.add_theme_color_override("font_color",Color("f1b6a9") if m._status_has_error() else G.MUTED)
			m._refit_status()
		if is_instance_valid(m.root_content) and m.decision_feedback != null:
			var feedback_button: Button = m.root_content.find_child("DecisionFeedbackButton", true, false)
			if feedback_button != null: m.decision_feedback.refresh_control(feedback_button)
		if m.last_command in ["recruit","extend_contract"] and m.model.get("meta",{}).get("negotiation") is Dictionary:
			var offer: Dictionary = m.model.meta.negotiation
			m.notice("La réponse du joueur", str(offer.get("message","La négociation est enregistrée.")))
		if m.last_command=="promote_cover" and m.model.meta.get("coverage") is Dictionary:
			m.notice("Renforts signés",str(m.model.meta.coverage.get("message","La feuille a été complétée.")))
		if m.last_command=="recover_profile" and not str(m.model.meta.get("recoveryBackup","")).is_empty():
			m.notice("Le profil d'origine est conservé","Copie de sécurité :\n"+str(m.model.meta.recoveryBackup)+"\n\nTu peux maintenant créer ou importer une carrière.")
	# Réponse à un mail du club qui mène à un écran (négocier, prolonger, préserver un joueur).
	if response_ok and received_command == "club_mail_reply": ClubMail.after_reply(m)
	# Ligne « ✓ Sauvegardé <date> » du pied du rail (succès comme échec d'écriture).
	if is_instance_valid(m.root_content): Immersive.refresh_save_line(m)
	m.call_deferred("_refresh_coach")
	if is_instance_valid(m.soundscape): m.soundscape.observe_model(m.model,m.route,received_command,m._match_visible(),response_ok)
	# Portraits de l'effectif fabriqués en tâche de fond, interface au repos : la 1re Composition ou le
	# 1er Effectif n'a plus à les décoder d'un bloc (ui/portrait_warmup.gd). Rien pendant le direct.
	if response_ok and received_command != "tick": PortraitWarmup.schedule(m)
	m._record_timing(received_command, receive_us)
	if live_opening: m.command_wait_overlay.dismiss()
	if not m.queued_action.is_empty() and m.bridge.last_response_ok:
		var next: Dictionary = m.queued_action.duplicate(true)
		m.queued_action.clear()
		m._command(next.command, next.payload, next.get("target_route", ""))
	# Fiche cliquée pendant cette requête (navigation_controller.open_entity) : ouverte maintenant que la page est à jour.
	if is_instance_valid(m.navigation_controller): m.navigation_controller.call_deferred("reprendre_differee")

static func record_timing(m: Control, command: String, receive_us: int) -> void:
	if not m._timing_trace: return
	var now := Time.get_ticks_usec()
	var bridge_timing: Dictionary = m.bridge.last_timing
	var entry := {"command": command, "rafraichissement": m.last_refresh, "rendu_ms": (now - receive_us) / 1000.0, "moteur_ms": bridge_timing.get("moteur_ms", 0.0), "analyse_ms": bridge_timing.get("analyse_ms", 0.0), "composition_ms": bridge_timing.get("composition_ms", 0.0), "sections": bridge_timing.get("sections", []).size(), "file_ms": bridge_timing.get("file_ms", 0.0), "octets": bridge_timing.get("octets", 0), "total_ms": (now - m._command_sent_us) / 1000.0 if m._command_sent_us > 0 else 0.0, "route": m.route}
	m._command_sent_us = 0
	m.timing_log.append(entry)
	print("CD_TIMING ", JSON.stringify(entry))

## Décision de la préparation attendue (arrêt ou refus de « Continuer », reprise.cjs) : « La reprise » s'ouvre
## d'elle-même, comme une décision en attente dans Football Manager.
static func decision_due(value: Dictionary, ok: bool) -> bool:
	var advance: Variant = value.get("meta", {}).get("advanceUntilEvent")
	if ok and advance is Dictionary and advance.get("stop") is Dictionary and str(advance.stop.get("kind", "")) == "decision": return true
	return not ok and not (value.get("clubLife", {}).get("reprise", {}).get("due", []) as Array).is_empty()

static func send_command(m: Control, command: String, payload: Dictionary, target_route: String) -> bool:
	if m.closing: return false
	if m.waiting:
		if command == "tick": return false
		# Bascule ou sélection simple : affichée tout de suite, envoyée après la réponse en cours. Une nouvelle
		# valeur pour le même réglage remplace celle en file (sa charge utile est lue sur le modèle déjà retouché).
		var early := Optimistic.edits(command, payload, m.model)
		if not early.is_empty() and m.last_command not in ["snapshot", "tick"] and not Etat.shows_wait_panel(m.last_command) and (m.queued_action.is_empty() or (str(m.queued_action.get("command", "")) == command and m.queued_action.get("optimistic") is Array and Optimistic.same_paths(m.queued_action.optimistic, early))):
			m.queued_action = {"command":command, "payload":payload.duplicate(true), "target_route":target_route, "optimistic":early}
			m.model = Optimistic.apply(m.model, early)
			m.call_deferred("_render_optimistic", early)
			return true
		# Après un tick ou une décision légère, la décision suivante attend son tour.
		# La même décision répétée n’attend pas : sa charge utile a été lue sur le
		# modèle d’avant la réponse en cours et écraserait celle-ci (ex. set_tactics).
		if (m.last_command == "tick" or (not Etat.shows_wait_panel(m.last_command) and command != m.last_command)) and m.last_command != "snapshot" and m.queued_action.is_empty():
			m.queued_action = {"command":command,"payload":payload.duplicate(true),"target_route":target_route}
			m._present_command_wait(command)
			return true
		if m.last_command == "snapshot": return false
		var active_command := str(m.queued_action.get("command", m.last_command))
		if not m.command_wait_overlay.visible or command != active_command:
			m._refuse_action("Une décision est déjà en cours. Cette nouvelle action n'a pas été retenue ; réessaie après sa réponse.")
		return false
	# La fiche d'un club est une lecture moteur sans changement d'état : les lecteurs suspendus
	# (rencontre ouverte avant la fiche, etc.) restent valides et le retour arrière les restitue.
	if is_instance_valid(m.navigation_controller) and command not in READ_ONLY_COMMANDS: m.navigation_controller.invalidate_readers()
	m.waiting = true
	m.last_command = command
	if m._timing_trace: m._command_sent_us = Time.get_ticks_usec()
	m.pending_route = target_route
	if SeasonPreparation.is_advance(command): SeasonPreparation.show_pending(m, true)
	var edits := Optimistic.edits(command, payload, m.model)
	var shown := not edits.is_empty() and Optimistic.applied(m.model, edits)
	# Avant toute retouche : la décision se mesure par rapport au modèle confirmé.
	if m.decision_feedback != null: m.decision_feedback.begin(command, payload, m.bridge.model if shown and not m.bridge.model.is_empty() else m.model)
	m.optimistic_edits = edits
	if not edits.is_empty() and not shown:
		m.model = Optimistic.apply(m.model, edits)
		m.call_deferred("_render_optimistic", edits)
	if command == CareerProgression.CONTINUE_COMMAND:
		payload = m._continue_payload(str(payload.get("fromDate", "")))
		m.continue_progress.begin(m._continue_context(), not m.user_preferences.data.reduced_motion)
	else: m._present_command_wait(command)
	m.bridge.send(command, payload)
	return m.waiting

## Affichage anticipé d'une décision (ou retour au modèle confirmé après un refus) : l'écran en cours est redessiné
## sans attendre le moteur. Les scènes contextuelles et le match gardent leur propre rafraîchissement.
## `edits` : retouches affichées ; l'écran n'est pas redessiné s'il ne lit aucune de leurs sections (ScreenRefresh),
## et reste alors construit hors attente, ce qui permet aussi de le garder à la confirmation.
static func render_optimistic(m: Control, edits: Array) -> void:
	if m.closing or not m._has_career() or m.route in ["Accueil", "Création", "Match"]: return
	if is_instance_valid(m.contextual_director) and m.contextual_director.active(): return
	if m.refresh_by_screen and not edits.is_empty() and m._screen_current() and not ScreenRefresh.concerns(m.route, ScreenRefresh.edit_ids(edits)):
		m.last_refresh = ScreenRefresh.NONE
		return
	m._render(false)

## Vrai si l'écran affiché est celui du dernier rendu complet noté, pour la même route et le même jour.
static func screen_current(m: Control) -> bool:
	if m._screen_stamp.is_empty() or not is_instance_valid(m.root_content): return false
	var now: Dictionary = m._screen_state()
	return m._screen_stamp.content == now.content and m._screen_stamp.route == now.route and m._screen_stamp.day == now.day

static func screen_state(m: Control) -> Dictionary:
	return ScreenRefresh.stamp(m.root_content.get_instance_id() if is_instance_valid(m.root_content) else 0, m.route, m.waiting, m.model, m.last_error, m.connection_error, m._status_has_error(), m._storage_has_error())

## Après une réponse acceptée : rendu complet, sauf si l'écran affiché ne lit aucune section changée
## (table ui/screen_refresh.json) et a été construit dans le même état (hors attente, même jour, même erreur). Les
## éléments vivants hors de l'écran (bandeau du direct, date, état, Gabi) sont mis à jour dans les deux cas.
static func refresh_after_response(m: Control, response_ok: bool, force_full: bool) -> void:
	m.last_refresh = ScreenRefresh.FULL
	if m.refresh_by_screen and response_ok and not force_full and m._has_career():
		m.last_refresh = ScreenRefresh.plan(m.route, m._screen_stamp, m._screen_state(), m.bridge.last_changes, m.bridge.last_full_model)
	if m.last_refresh == ScreenRefresh.FULL:
		m._render(false)
		return
	m._update_live_bar()
	m._update_header_date()

## « Continuer » : tranches partielles (le moteur répond au bout de CONTINUE_SLICE_MS avec la date atteinte),
## arrêts réglés dans les préférences. Les arrêts obligatoires (match, rendez-vous, presse) ne se règlent pas.
static func continue_payload(m: Control, from_date: String) -> Dictionary:
	return {"fromDate": from_date, "budgetMs": CONTINUE_SLICE_MS, "partial": true, "stops": CareerProgression.continue_stops(m.user_preferences.data)}

static func continue_context(m: Control) -> Dictionary:
	var meta: Dictionary = m.model.get("meta", {}) if m.model.get("meta") is Dictionary else {}
	var next: Variant = m.model.get("next")
	var info := {}
	if next is Dictionary and str(next.get("date", "")).length() >= 10:
		var club_id: Variant = m.model.get("club", {}).get("id") if m.model.get("club") is Dictionary else null
		var home: Dictionary = next.get("home", {}) if next.get("home") is Dictionary else {}
		var away: Dictionary = next.get("away", {}) if next.get("away") is Dictionary else {}
		var opponent: Dictionary = away if home.get("id") == club_id else home
		info = {"date": str(next.date).substr(0, 10), "opponent": str(opponent.get("name", ""))}
	return {"date": str(meta.get("calendarToday", "")), "accent": m.accent, "next": info if not info.is_empty() else null, "notes": m._command_wait_context("continue").notes, "note_seed": Time.get_ticks_msec() / 4600}

## Tranche reçue : la date défile ; on demande la suite, ou l'arrêt si le joueur l'a demandé (les jours passés
## sont alors écrits par le moteur avant sa réponse).
static func continue_progressed(m: Control, progress: Dictionary) -> void:
	if not m.waiting or m.last_command != CareerProgression.CONTINUE_COMMAND or m.closing: return
	m.continue_progress.advance_to(progress)
	var parts := str(progress.get("today", "")).split("-")
	if is_instance_valid(m.header_date) and parts.size() == 3 and int(parts[1]) in range(1, 13):
		m.header_date.text = "%s %s %s" % [parts[2], ["JANV.","FÉVR.","MARS","AVR.","MAI","JUIN","JUIL.","AOÛT","SEPT.","OCT.","NOV.","DÉC."][int(parts[1])-1], parts[0]]
	var today := str(progress.get("today", ""))
	if m.continue_progress.stopping: m.bridge.send(CareerProgression.CONTINUE_COMMAND, {"fromDate": today, "stop": true})
	else: m.bridge.send(CareerProgression.CONTINUE_COMMAND, m._continue_payload(today))

## Vrai si ce modèle ouvre l’écran du match en direct (scène 3D) : rencontre en cours, aucune causerie au
## vestiaire, direct pas encore affiché. Après le coup d’envoi ou la causerie d’avant-match.
static func opens_live_view(m: Control, value: Dictionary) -> bool:
	var live: Variant = value.get("live")
	if not live is Dictionary or live.is_empty(): return false
	if is_instance_valid(m.contextual_director) and m.contextual_director.active() and m.contextual_director.kind == "live": return false
	var talks: Variant = value.get("clubLife", {}).get("matchTalks", {}) if value.get("clubLife") is Dictionary else {}
	return not (talks is Dictionary and talks.get("scene") is Dictionary)

static func refuse_action(m: Control, message: String) -> void:
	# A local refusal must not complete or discard the actual in-flight action.
	if is_instance_valid(m.soundscape): m.soundscape.notify_error()
	m.last_error = message
	if is_instance_valid(m.status):
		m.status.text = "ACTION NON EFFECTUÉE · " + message
		m.status.add_theme_color_override("font_color", Color("f1b6a9"))
	if not (is_instance_valid(m.contextual_director) and m.contextual_director.active()):
		m.notice("Ta décision n'a pas été appliquée", message)

static func failed(m: Control, message: String) -> void:
	m.command_wait_overlay.dismiss()
	if is_instance_valid(m.continue_progress): m.continue_progress.dismiss()
	if is_instance_valid(m.soundscape): m.soundscape.notify_error()
	if m.decision_feedback != null: m.decision_feedback.complete(m.last_command, false, m.model)
	m.waiting = false
	# Requête refusée : une fiche cliquée pendant l'attente n'est pas ouverte après coup.
	if is_instance_valid(m.navigation_controller): m.navigation_controller._differee = []
	if SeasonPreparation.is_advance(m.last_command): SeasonPreparation.show_pending(m, false)
	var anticipated: bool = not m.optimistic_edits.is_empty() or m.queued_action.get("optimistic") is Array
	var reverted: Array = m.optimistic_edits.duplicate()
	if m.queued_action.get("optimistic") is Array: reverted.append_array(m.queued_action.optimistic)
	m.queued_action.clear()
	m.pending_route = ""
	m.connection_error = m.bridge.child_pid <= 0 or m.bridge._stopping
	# Décision affichée d'avance puis refusée (ou moteur arrêté avant sa réponse) : retour au modèle confirmé.
	m.optimistic_edits = []
	if anticipated and not m.bridge.model.is_empty() and not is_same(m.model, m.bridge.model):
		m.model = m.bridge.model
		m.call_deferred("_render_optimistic", reverted)
	var epcr_dialog := m.find_child("EpcrPreparationDialog", true, false) if m.last_command == "epcr_preview" else null
	var editor_dialog := m.get_node_or_null("CompetitionEditorDialog") if m.last_command == "competition_editor_preview" else null
	var market_dialog := m.get_node_or_null("InterclubMarket") if m.last_command in ["interclub_negotiate", "interclub_auction", "transfer_budget_extension"] else null
	# A consultation refusal belongs to its report, never to the career decision
	# status. Preserve an existing business error and the unsaved list.
	if m.last_command in ["epcr_preview", "competition_editor_preview"] and not m.connection_error:
		if is_instance_valid(m.status):
			m.status.text = m._status_line_text()
			m.status.add_theme_color_override("font_color",Color("f1b6a9") if m._status_has_error() else G.MUTED)
			m._refit_status()
		return
	m.last_error = message
	if is_instance_valid(m.status):
		m.status.text = "ACTION NON EFFECTUÉE · " + message
		m.status.add_theme_color_override("font_color", Color("f1b6a9"))
	if m.last_command == "tick": m.timer.stop()
	# Moteur arrêté : le bouton principal devient « Relancer » (primary_action), la carrière reprend de sa sauvegarde.
	if m.connection_error:
		if is_instance_valid(m.primary_button): m._update_live_bar()
		message += "\n\nLe moteur du jeu s’est arrêté. Clique sur « Relancer » (bouton principal) : la carrière reprend à sa dernière sauvegarde."
	# The immersive scene owns its visible error panel; a second modal would
	# survive a successful retry and obscure the resumed match.
	if is_instance_valid(m.contextual_director) and m.contextual_director.active() and not m.connection_error: return
	# Transport failures remain globally visible, but keep this local draft too.
	if epcr_dialog != null or editor_dialog != null or market_dialog != null: return
	# A failed annotation must leave its editor and unsaved draft alive. The
	# notebook listens to the same failure signal and presents the local refusal.
	if m.last_command in ["coach_note_save","coach_note_remove"] and m.get_node_or_null("CoachNotebook") != null: return
	m._clear_dialogs()
	var d := AcceptDialog.new()
	m._prepare_dialog(d, 590)
	d.title = "Ta décision n'a pas été appliquée"
	d.dialog_text = message
	m.add_child(d)
	d.popup_centered(Vector2i(590, 180))
	d.confirmed.connect(d.queue_free)
	if m.route == "Accueil" or not m._has_career(): m._render()

static func reconnect(m: Control) -> void:
	if m.waiting or m.bridge.child_pid > 0: return
	m.connection_error = false
	m.waiting = true
	m.last_command = "snapshot"
	m._present_startup_wait()
	m.bridge.start(m._profile_path())

static func live_tick(m: Control) -> void:
	if m.waiting or m.closing: return
	if m._match_visible() and is_instance_valid(m.match_screen.stage) and m.match_screen.stage.is_presenting_extended_pass():
		return
	# Match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0) : la régie de la vue demande elle-même chaque minute.
	if is_instance_valid(m.match_screen) and m.match_screen.has_method("temps_forts_actifs") and m.match_screen.temps_forts_actifs(): return
	var live: Dictionary = m._live()
	if live.is_empty() or live.get("paused",false) or live.get("finished",false):
		m._rythme_ecoule = 0.0
		return
	# Rythme : le fait montré reste à l'écran selon son type (essai, mêlée, course…), divisé par la
	# cadence choisie (×4, ×12) ; rien ne part avant qu'il ait été joué.
	var scene: Dictionary = live.get("scene") if live.get("scene") is Dictionary else {}
	var cle := str(scene.get("key", "")) + "|" + str((live.get("events", []) as Array).size())
	if cle != m._rythme_cle:
		m._rythme_cle = cle
		m._rythme_ecoule = 0.0
		m._rythme_place = 0.0
	m._rythme_ecoule += m.timer.wait_time
	var suite := Rythme.prochain(str(scene.get("kind", "")), m.tick_steps)
	if m._rythme_ecoule < float(suite.secondes): return
	# À ×1, les joueurs proches du ballon finissent d'abord leur déplacement (avec une échéance).
	if m.tick_steps == 1 and m._rythme_place < Rythme.ECHEANCE_PLACE and m._match_visible() and is_instance_valid(m.match_screen.stage) and m.match_screen.stage.has_method("deplacement_restant") and m.match_screen.stage.deplacement_restant() > 0.05:
		m._rythme_place += m.timer.wait_time
		return
	m._rythme_ecoule = 0.0
	m._command("tick",{"steps":int(suite.pas)})
