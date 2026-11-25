extends RefCounted
## Coque du jeu (main.gd) : panneau d’attente des vrais chargements et ligne d’état du pied de page.
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const G = preload("res://ui/game_skin.gd")
const CareerProgression = preload("res://ui/career_progression.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")

## Seuil unique : le panneau d’attente n’apparaît qu’au-delà de 0,5 s (sinon simple flash).
const COMMAND_WAIT_REVEAL_SECONDS := 0.5
const COMMAND_WAIT_MESSAGES := {
	"new_career": "Création de la carrière…",
	"import": "Importation de la carrière…",
	"export": "Préparation de l’export…",
	"save": "Sauvegarde de la carrière…",
	"recover_profile": "Préservation et récupération du profil…",
	"restore_checkpoint": "Reprise de la copie de sécurité…",
	"remove_checkpoint": "Suppression de la copie de sécurité…",
	"pack_inspect": "Analyse du pack d’identités…",
	"pack_install": "Installation du pack d’identités…",
	"pack_select": "Application du pack d’identités…",
	"begin_match": "Préparation du coup d’envoi…",
	"delegate": "Simulation de la rencontre…",
	"finish_round": "Mise à jour de la journée…",
	"advance_day": "Passage au jour suivant…",
	"preseason_advance": "Avance de l’avant-saison…",
	"next_season": "Préparation de la nouvelle saison…",
	"advance_pacific_preparation": "Avance de la préparation…",
	"advance_japan_preparation": "Avance de la préparation…",
	"advance_champ_preparation": "Avance de la préparation…",
	"population_enable": "Mise à jour de la base de joueurs…",
	"academy_groups_enable": "Mise à jour des centres de formation…",
	"national_play_match": "Simulation de la rencontre internationale…",
	"league_benchmark": "Mesure de ta machine…"
}
## Seuls les vrais chargements ont un panneau (décision de Léo, 16/11/2026) : ouverture du jeu, création ou reprise de
## carrière, coup d’envoi, avance du calendrier (Continuer, sauvegarde automatique comprise), fichiers et packs.
## Décisions et menus (fiche d’un club, renforts, championnats suivis…) restent instantanés : jamais de panneau.
## Ouverture du jeu : panneau d’attente tant que le moteur n’a pas rendu le profil (au-delà du même seuil).
const STARTUP_WAIT_MESSAGE := "Ouverture du bureau du manager…"
## Entrée dans le match en direct : la scène 3D se construit d’un bloc ; ce panneau est dessiné avant.
const LIVE_VIEW_WAIT_MESSAGE := "Entrée des joueurs sur la pelouse…"
## Avances du calendrier dont la sauvegarde complète est écrite AVANT la réponse (fréquence des Réglages). Le jour suivant
## et Continuer sont sauvegardés après la réponse (lot 36) : le panneau ne la nomme pas, la disquette la montre.
const AUTOSAVE_ADVANCES := ["finish_round", "next_season"]
## Titre du panneau d’attente par commande (les autres : « En coulisses »).
const COMMAND_WAIT_KICKERS := {
	"advance_day": "Calendrier",
	"finish_round": "Fin de journée",
	"delegate": "Le match se joue",
	"begin_match": "Avant le coup d’envoi",
	"next_season": "Intersaison",
	"new_career": "Nouvelle carrière",
	"import": "Reprise de carrière",
	"restore_checkpoint": "Reprise de carrière",
	"save": "Sauvegarde",
	"snapshot": "Ouverture",
	"national_play_match": "Sélection nationale"
}
## Conseils de Gabi affichés pendant une attente (fonctions réelles du jeu).
const GABI_TIPS := [
	"Avant un match, passe par la Préparation : les consignes d’attaque et de défense se règlent en un clic.",
	"Un joueur lourdement chargé peut souffler : passe sa charge en « repos » depuis le suivi de fatigue.",
	"La composition automatique propose un XV cohérent ; tu gardes la main poste par poste ensuite.",
	"Une observation ciblée affine la fourchette de niveau d’un joueur avant de lui faire une offre.",
	"Le centre de formation récompense la patience : suis la progression des jeunes semaine après semaine.",
	"En conférence de presse, tes réponses pèsent sur le moral du vestiaire et sur la confiance de la direction.",
	"Le calendrier signale les jours de match : avance jour par jour pour ne rien manquer du courrier.",
	"Les contrats qui arrivent à échéance apparaissent au Bureau : anticipe les prolongations."
]

## Commandes légères : jamais de panneau, l’interface reste disponible et une
## décision supplémentaire attend son tour au lieu d’être refusée.
static func shows_wait_panel(command: String) -> bool:
	return COMMAND_WAIT_MESSAGES.has(command) or SeasonPreparation.is_advance(command) or command == CareerProgression.CONTINUE_COMMAND

static func present_command_wait(m: Control, command: String) -> void:
	var message: String = COMMAND_WAIT_MESSAGES.get(command, "")
	if message.is_empty() and SeasonPreparation.is_advance(command): message = "Avance de la préparation…"
	if not message.is_empty():
		var context: Dictionary = m._command_wait_context(command)
		# Sauvegarde automatique attendue à la fin de cette avance : le panneau la nomme.
		if m.autosave_expected(command):
			message = message.trim_suffix("…") + " et sauvegarde…"
			context.kicker = "Sauvegarde automatique"
		m.command_wait_overlay.set_context(context)
		m.command_wait_overlay.present(message, not m.user_preferences.data.reduced_motion, COMMAND_WAIT_REVEAL_SECONDS)

## Ouverture du jeu (et reconnexion) : même panneau que les autres chargements, au-delà du même seuil.
static func present_startup_wait(m: Control) -> void:
	if not is_instance_valid(m.command_wait_overlay): return
	m.command_wait_overlay.set_context(m._command_wait_context("snapshot"))
	m.command_wait_overlay.present(STARTUP_WAIT_MESSAGE, m.user_preferences == null or not m.user_preferences.data.reduced_motion, COMMAND_WAIT_REVEAL_SECONDS)

## Prévision : l’avance `command` doit-elle se terminer par la sauvegarde complète (même règle que `due` dans
## native/engine/action-journal.cjs) ? Le moteur décide ; ceci ne sert qu’au libellé du panneau.
static func autosave_expected(m: Control, command: String) -> bool:
	if command not in AUTOSAVE_ADVANCES: return false
	var info: Variant = m.model.get("meta", {}).get("autosave")
	if not info is Dictionary: return false
	if command == "next_season": return true
	# Réglage du joueur (interface.json, relu par le moteur à chaque avance), sinon celui du dernier modèle.
	var policy := str(m.user_preferences.data.get("autosave", info.get("policy", "semaine"))) if m.user_preferences != null else str(info.get("policy", "semaine"))
	var today := str(m.model.get("meta", {}).get("calendarToday", ""))
	var last := str(info.get("lastSave", ""))
	if command != "advance_day" or today.length() != 10 or last.length() != 10: return command == "finish_round" and policy != "mois"
	return CareerProgression.autosave_due(policy, last, CareerProgression.shift_day(today, 1))

## Contexte du panneau d’attente : date du jour, club et faits réels du modèle.
static func command_wait_context(m: Control, command: String) -> Dictionary:
	var meta: Dictionary = m.model.get("meta", {}) if m.model.get("meta") is Dictionary else {}
	var club: Dictionary = m.model.get("club", {}) if m.model.get("club") is Dictionary else {}
	var tips: Array = []
	for tip: String in GABI_TIPS: tips.append({"kind":"tip", "title":"Le conseil de Gabi", "text":tip})
	var facts: Array = []
	if not club.is_empty():
		var rank := int(club.get("rank", 0))
		var points := int(club.get("points", 0))
		if rank > 0 and not str(meta.get("roundLabel", "")).is_empty():
			facts.append("%s pointe à la %s place avec %d point%s · %s." % [str(club.get("name", "")), ("1re" if rank == 1 else str(rank) + "e"), points, "" if points <= 1 else "s", str(meta.roundLabel)])
		var next: Variant = m.model.get("next")
		if next is Dictionary and next.get("home") is Dictionary and next.get("away") is Dictionary:
			facts.append("Prochaine rencontre : %s – %s." % [str(next.home.get("name", "")), str(next.away.get("name", ""))])
		if meta.get("morale") is float or meta.get("morale") is int:
			facts.append("Moral du groupe : %d / 100." % int(meta.morale))
		if not str(club.get("goal", "")).is_empty():
			facts.append("Objectif fixé par la direction : %s." % str(club.goal).to_lower())
	# Les faits du club alternent avec les conseils de Gabi.
	var notes: Array = []
	for index in maxi(tips.size(), facts.size()):
		if index < facts.size(): notes.append({"kind":"fact", "title":"Au club", "text":facts[index]})
		if index < tips.size(): notes.append(tips[index])
	return {
		"kicker": COMMAND_WAIT_KICKERS.get(command, "En coulisses"),
		"date": str(meta.get("calendarToday", "")),
		"flip": command == "advance_day",
		"accent": m.accent if m._has_career() else Color("d43e47"),
		"club": str(club.get("abbr", "")),
		# Lus dans le modèle ; vides tant que la carrière n'existe pas (la ligne est alors omise, jamais inventée).
		"club_name": G.club_name(club) if not club.is_empty() else "",
		"division": m._wait_division(),
		"season": "saison " + G.season_label(meta.get("season", 1)) if not club.is_empty() and meta.has("season") else "",
		"stadium": str(G.identity(club).get("stadium", "")) if not club.is_empty() else "",
		"notes": notes,
		"note_seed": Time.get_ticks_msec() / 4600,
		# Vrais chargements longs : photo plein écran de la banque d'images derrière le panneau.
		"photo": command in ["snapshot", "new_career", "import", "restore_checkpoint", "next_season", "begin_match", "national_play_match"]
	}

## Nom du championnat du club (lu dans le modèle) ; vide si inconnu.
static func wait_division(m: Control) -> String:
	var league_id: Variant = m.model.get("meta", {}).get("leagueId") if m.model.get("meta") is Dictionary else null
	for league: Variant in m.model.get("leagues", []):
		if league is Dictionary and league_id != null and league.get("id") == league_id: return str(league.get("name", ""))
	return ""

static func sound_error(m: Control, message: String) -> void:
	# Local audio availability never marks a career decision as failed.
	if is_instance_valid(m.status):
		m.status.text = m._status_line_text()
		m.status.add_theme_color_override("font_color",Color("f1b6a9") if m._status_has_error() else G.MUTED)
		m._refit_status()
	if not message.is_empty(): m.call_deferred("_show_sound_error",message)

static func show_sound_error(m: Control, message: String) -> void:
	if not is_instance_valid(m.soundscape) or m.soundscape.last_error != message: return
	var options := m.get_node_or_null("PreferencesDialog")
	if options != null and not options.is_queued_for_deletion(): return # The options show their own reason.
	m.notice("Réglages sonores indisponibles",message)

static func settled_status_text(m: Control) -> String:
	if not m.last_error.is_empty(): return "ACTION NON EFFECTUÉE · " + m.last_error
	if m.model.get("meta",{}).get("saveError",false): return "DERNIÈRE SAUVEGARDE IMPOSSIBLE · Vérifie le stockage avant de poursuivre."
	if m.user_preferences != null and not m.user_preferences.last_error.is_empty(): return "RÉGLAGES LOCAUX · " + m.user_preferences.last_error
	if is_instance_valid(m.soundscape) and not m.soundscape.last_error.is_empty(): return "RÉGLAGES SONORES · " + m.soundscape.last_error
	if m.decision_feedback != null and not m.decision_feedback.status_text().is_empty(): return m.decision_feedback.status_text()
	# Reprise après une fermeture pendant un match (native/engine/worker.cjs, matchResumeNotice).
	var resume: Variant = m.model.get("meta",{}).get("matchResumeNotice")
	if resume is Dictionary and not str(resume.get("text","")).is_empty(): return "REPRISE DE CARRIÈRE · " + str(resume.text)
	return m._autosave_status()

## Ligne d'état affichée en pied de page. Dans la coque commune, la sauvegarde ordinaire n'y est plus répétée : la
## ligne « ✓ Sauvegardé <date> » du rail est la seule (relectures du 19/11/2026). Erreurs, retours de décision,
## reprise et alertes du journal de sauvegarde restent affichés ici.
static func status_line_text(m: Control) -> String:
	var text: String = m._settled_status_text()
	var coque: bool = is_instance_valid(m.root_content) and m.root_content.name == "ImmersiveShell"
	if coque and text == m._autosave_status() and not m._autosave_alert(): return ""
	return text

## Ligne d'état de la sauvegarde (meta.autosave, native/engine/action-journal.cjs) : fréquence choisie, date de la
## dernière sauvegarde complète, reprise du journal d'actions après un arrêt imprévu.
static func autosave_status(m: Control) -> String:
	var info: Variant = m.model.get("meta",{}).get("autosave")
	if not info is Dictionary: return "Sauvegarde automatique · Profil de carrière indépendant"
	var notice: Variant = info.get("notice")
	if notice is Dictionary and not str(notice.get("text","")).is_empty():
		return ("JOURNAL DE SAUVEGARDE · " if bool(notice.get("alert",false)) else "Sauvegarde automatique · ") + str(notice.text)
	var text := "Sauvegarde automatique · " + str({"jour":"chaque jour","semaine":"chaque semaine","mois":"chaque mois"}.get(str(info.get("policy","")),"profil indépendant"))
	var last := str(info.get("lastSave",""))
	if last.length() == 10: text += " · dernière le %s/%s" % [last.substr(8,2), last.substr(5,2)]
	return text
