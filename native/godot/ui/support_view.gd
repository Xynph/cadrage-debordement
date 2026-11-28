extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const Cc = preload("res://ui/immersive08/components.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const JaugeAvantApres = preload("res://ui/jauge_avant_apres.gd")
const BarreEmpilee = preload("res://ui/barre_empilee.gd")
const LienZone = preload("res://ui/lien_zone.gd")
const Etat = preload("res://ui/management_state.gd")

static func build(app: Control) -> Control:
	var page := G.v(12)
	page.name = "CarnetSupport"
	G.fill(page, true)
	var data: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
	if data.is_empty():
		page.add_child(G.wrap("Crée une carrière pour réunir ton staff.", 18))
		return page
	var paper := G.panel(page)
	G.fill(paper.get_parent(), true)
	G.fill(paper, true)
	# Règle des commotions : derrière un « i », plus en phrase sous le titre.
	var entete := G.h(12)
	paper.add_child(entete)
	G.chapter(entete, "21", "Le travail de la semaine", "Staff · préparation · cellule médicale · mandats", app.accent)
	G.fill(entete.get_child(0))
	var notice := Copy.notice("support", data.notice)
	if not notice.is_empty():
		var i := Tuile.info(notice)
		Tuile.proteger(i)
		entete.add_child(i)
	var tabs := TabContainer.new()
	tabs.name = "SupportTabs"
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_color_override("font_selected_color", Charte.ENCRE)
	tabs.add_theme_color_override("font_unselected_color", Charte.CREME)
	var onglet_actif: StyleBoxFlat = Charte.style_pilule(Charte.CREME, Color.TRANSPARENT, 18, 8)
	var onglet_inactif: StyleBoxFlat = Charte.style_pilule(Charte.PANNEAU_3, Charte.FILET, 18, 8)
	# Onglets assez larges et hauts pour être cliqués en 720p (ils tenaient sur 12 px de texte).
	for onglet: StyleBoxFlat in [onglet_actif, onglet_inactif]:
		onglet.content_margin_left = 18
		onglet.content_margin_right = 18
		onglet.content_margin_top = 8
		onglet.content_margin_bottom = 8
	tabs.add_theme_font_size_override("font_size", 16)
	tabs.add_theme_stylebox_override("tab_selected", onglet_actif)
	tabs.add_theme_stylebox_override("tab_unselected", onglet_inactif)
	G.fill(tabs, true)
	paper.add_child(tabs)
	_staff(tabs, app, data)
	_medical(tabs, app, data)
	_agents(tabs, app, data)
	return page

static func _name(app: Control, id: Variant) -> String:
	for p: Dictionary in app.model.get("squad", []):
		if p.id == id: return str(p.name)
	return str(id)

static func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var tab := G.v(12)
	tab.name = title
	tabs.add_child(tab)
	return G.scroll(tab)

static func _action(parent: Node, label: String, name: String, enabled: bool, callback: Callable) -> Button:
	var button := G.button(label, callback)
	button.name = name.replace(":", "_")
	button.disabled = not enabled
	parent.add_child(button)
	return button

static func _meeting_lock(app: Control, completed: bool) -> String:
	if completed: return "Une réunion a déjà eu lieu cette semaine."
	if not app._live().is_empty(): return "Rencontre en cours ou à valider."
	if app.model.meta.get("trained", false): return "Entraînement déjà effectué cette semaine."
	if app.model.meta.get("phase", "league") != "league": return "Les réunions sont réservées aux semaines de championnat."
	return "Réunion indisponible cette semaine."

## Onglet Staff (choix de Léo du 21/11/2026, option A « en couleurs ») : anneaux du diagnostic, tuiles de réunion à
## jauges « maintenant → prévu », plans de charge en tuiles à barre empilée. Aucune phrase d'explication dans les tuiles :
## les textes du jeu passent derrière un repère « i ». Mêmes données, commandes et noms de contrôles qu'avant.
static func _staff(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Staff")
	var d: Dictionary = data.diagnostic
	var tete_diag := Tuile.titre_bloc("Le diagnostic", str(d.get("reason", "")))
	Tuile.proteger(tete_diag)
	list.add_child(tete_diag)
	var diag := Cc.h(28)
	list.add_child(diag)
	# Chaque lecture ouvre l'écran qui la détaille.
	diag.add_child(LienZone.relier(JaugeAnneau.new(float(d.mean), "Condition moyenne", Charte.CONDITION), "SupportLien_Condition", "Effectif › Condition", _vers_condition.bind(app)))
	diag.add_child(LienZone.relier(JaugeAnneau.new(float(d.morale), "Moral du groupe", Charte.MORAL), "SupportLien_Moral", "Vestiaire", _vers_vestiaire.bind(app)))
	diag.add_child(LienZone.relier(JaugeAnneau.new(float(d.trust), "Confiance", Charte.CONFIANCE), "SupportLien_Confiance", "Club › Direction", _vers_direction.bind(app)))
	diag.add_child(LienZone.relier(_chiffre(int(d.fatigue), "sous 65", int(d.fatigue) > 0, "Joueurs disponibles sous 65 de condition"), "SupportLien_Sous65", "Effectif › Condition", _vers_condition.bind(app)))
	if d.has("tired"):
		diag.add_child(LienZone.relier(_chiffre(int(d.tired), "sous 85", int(d.tired) > 0, "Joueurs sous 85 de condition"), "SupportLien_Sous85", "Effectif › Condition", _vers_condition.bind(app)))
	# Les lectures se partagent la largeur du panneau.
	for lecture: Control in diag.get_children(): Cc.fill(lecture)
	Tuile.proteger(diag)
	var meeting_data: Dictionary = data.meeting
	var receipt: Variant = meeting_data.receipt
	var last_decision: Variant = meeting_data.get("lastDecision")
	var current_decision: bool = last_decision is Dictionary and last_decision.get("context") == data.context
	var lock := _meeting_lock(app, receipt is Dictionary or current_decision)
	var tete_reunion := Tuile.titre_bloc("Réunir le staff", "Une réunion par semaine.")
	Tuile.proteger(tete_reunion)
	list.add_child(tete_reunion)
	var rangee := Cc.h(18)
	list.add_child(rangee)
	for option: Dictionary in meeting_data.options:
		# Un reçu importé de l’ancienne version peut précéder le contexte natif.
		var matching_receipt: bool = receipt is Dictionary and receipt.get("title") == "Réunion de staff : " + str(option.label)
		var applied: bool = last_decision.get("plan") == option.key if current_decision else matching_receipt
		var detail := str(receipt.body) if applied and matching_receipt else str(option.detail)
		var pv: Dictionary = option.get("preview", {})
		var etat := "" if meeting_data.available else ("Réunion tenue cette semaine · Moral actuel %d/100 · Confiance actuelle %d/100" % [d.morale, d.trust] if applied else lock)
		var bouton := Tuile.pilule("Réunion effectuée" if applied else "Réunir le staff", "SupportMeeting_" + str(option.key), meeting_data.available, etat, func(): app._command("staff_meeting", {"context":data.context,"plan":option.key}))
		bouton.accessibility_name = "Réunir le staff · " + str(option.label)
		var icone: String = {"recuperation": "heart", "cohesion": "people", "exigence": "target"}.get(str(option.key), "")
		var teinte: Color = {"recuperation": Charte.RECUPERATION, "cohesion": Charte.MORAL, "exigence": Charte.CONFIANCE}.get(str(option.key), Charte.GRIS_VERT)
		var tuile := Tuile.new(str(option.label), icone, applied, teinte, true, detail)
		rangee.add_child(tuile)
		if meeting_data.available:
			var condition := _condition_prevue(pv)
			var cle := str(option.key)
			if not condition.is_empty(): tuile.contenu.add_child(LienZone.relier(JaugeAvantApres.new("Condition", condition.avant, condition.apres, Charte.CONDITION), "SupportLienCondition_" + cle, "Effectif › Condition", _vers_condition.bind(app)))
			tuile.contenu.add_child(LienZone.relier(JaugeAvantApres.new("Moral", float(d.morale), float(pv.get("morale", d.morale)), Charte.MORAL), "SupportLienMoral_" + cle, "Vestiaire", _vers_vestiaire.bind(app)))
			tuile.contenu.add_child(LienZone.relier(JaugeAvantApres.new("Confiance", float(d.trust), float(pv.get("trust", d.trust)), Charte.CONFIANCE), "SupportLienConfiance_" + cle, "Club › Direction", _vers_direction.bind(app)))
			tuile.pied.add_child(LienZone.relier(Tuile.pastille("%d joueur(s)" % int(pv.get("affected", 0)), Charte.IVOIRE, "people", "Joueurs concernés par la réunion"), "SupportLienJoueurs_" + cle, "Effectif › Condition", _vers_condition.bind(app)))
		elif applied:
			tuile.pied.add_child(Tuile.pastille("Réunion tenue", Charte.GAIN, "check", etat))
		else:
			tuile.pied.add_child(Tuile.pastille(_mot_verrou(lock), Charte.GRIS_VERT, "clock", lock))
		if str(d.get("recommended", "")) == str(option.key):
			tuile.pied.add_child(Tuile.pastille("Conseillé", Charte.IVOIRE, "star", str(d.get("reason", ""))))
		var vide := Control.new()
		Cc.fill(vide)
		tuile.pied.add_child(vide)
		tuile.pied.add_child(bouton)
	Tuile.proteger(rangee)
	var tete_charges := Tuile.titre_bloc("Répartir les charges", "Configurer un plan ne lance pas la séance. La prévision physique précède les effets collectifs et médicaux.")
	var session: Dictionary = data.training.get("session", {})
	if session.get("status", "pending") == "applied":
		var reason: Variant = session.get("reason")
		tete_charges.add_child(Tuile.pastille("Séance effectuée", Charte.GAIN, "check", str(reason) if reason != null else "Aucun compte rendu du préparateur pour cette séance."))
	Tuile.proteger(tete_charges)
	list.add_child(tete_charges)
	var verrou_charge := _training_lock(app, session)
	var plans := Cc.h(18)
	list.add_child(plans)
	for plan: Dictionary in data.training.plans:
		var modes: Dictionary = plan.get("effectiveCounts", plan.counts)
		var barre := BarreEmpilee.new([{"valeur": int(modes.repos), "libelle": "repos"}, {"valeur": int(modes.normal) + int(modes.get("collective", 0)), "libelle": "normal"}, {"valeur": int(modes.intense), "libelle": "intensif"}])
		var explication := str(plan.detail)
		if int(plan.counts.collective) > 0 and plan.has("collective"): explication += "\n" + str(plan.collective.reason)
		var configurer := Tuile.pilule("Configurer", "SupportTraining_" + str(plan.key), data.training.available, verrou_charge, func(): app._command("training_plan", {"context":data.context,"plan":plan.key}))
		configurer.accessibility_name = "Configurer · " + str(plan.label)
		var icone: String = {"proteger": "shield", "relever": "school", "equilibrer": "train"}.get(str(plan.key), "")
		var teinte: Color = {"proteger": Charte.REPOS, "relever": Charte.INTENSIF, "equilibrer": Charte.NORMAL}.get(str(plan.key), Charte.GRIS_VERT)
		var tuile := Tuile.new(str(plan.label), icone, false, teinte, false, explication)
		plans.add_child(tuile)
		tuile.contenu.add_child(LienZone.relier(barre, "SupportLienPlan_" + str(plan.key), "Entraînement › Groupes", _vers_groupes.bind(app)))
		var gain := float(plan.conditionGain)
		var signe := "▲" if gain > 0 else "▼" if gain < 0 else "="
		var couleur_gain := Charte.GAIN if gain > 0 else Charte.PERTE if gain < 0 else Charte.GRIS_VERT
		tuile.pied.add_child(LienZone.relier(Tuile.pastille("%s %+.0f condition" % [signe, gain], couleur_gain, "", "Condition totale du groupe après la séance"), "SupportLienGain_" + str(plan.key), "Entraînement › Groupes", _vers_groupes.bind(app)))
		if not data.training.available: tuile.pied.add_child(Tuile.pastille(_mot_verrou(verrou_charge), Charte.GRIS_VERT, "clock", verrou_charge))
		var vide := Control.new()
		Cc.fill(vide)
		tuile.pied.add_child(vide)
		tuile.pied.add_child(configurer)
	Tuile.proteger(plans)
	_briefing(list, app, data)

static func _briefing(list: VBoxContainer, app: Control, data: Dictionary) -> void:
	list.add_child(G.separator())
	var tete := Tuile.titre_bloc("Le briefing ciblé", "Consignes préparées pour le coup d’envoi ; aucun résultat garanti.")
	Tuile.proteger(tete)
	list.add_child(tete)
	var b: Dictionary = data.briefing
	if b.evidence is Dictionary:
		list.add_child(G.wrap("Écart avants %+.0f · passe/vitesse %+.0f · danger adverse %+.0f" % [b.evidence.pack, b.evidence.backs, b.evidence.danger], 16))
	for plan: Dictionary in b.plans:
		list.add_child(G.wrap(plan.desc, 14))
		var button := _action(list, str(plan.label), "SupportBriefing_" + str(plan.key), b.available, func(): app._command("strategic_briefing", {"context":data.context,"fixture":b.fixture,"plan":plan.key}))
		if plan.key == b.selected: G.selected(button, app.accent)

## Destinations des lectures (changement d'écran, jamais une fenêtre).
static func _vers_condition(app: Control) -> void:
	if not app.management_ui.get("roster") is Dictionary: app.management_ui.roster = Etat.defaults()
	app.management_ui.roster.immersive_tab = 1
	app._navigate("Effectif")

static func _vers_vestiaire(app: Control) -> void:
	app._navigate("Vestiaire")

static func _vers_direction(app: Control) -> void:
	app.management_ui.erase("club_page")
	app._navigate("Stratégie")

static func _vers_groupes(app: Control) -> void:
	if not app.management_ui.get("immersive_training") is Dictionary: app.management_ui.immersive_training = {}
	app.management_ui.immersive_training.tab = 1
	app.Immersive.open_training(app)

## Condition moyenne des joueurs concernés avant / après la réunion, quand la prévision détaille les joueurs.
static func _condition_prevue(pv: Dictionary) -> Dictionary:
	var joueurs: Array = pv.get("players", [])
	if joueurs.is_empty(): return {}
	var avant := 0.0
	var apres := 0.0
	for j: Variant in joueurs:
		if not j is Dictionary or not j.has("before") or not j.has("after"): return {}
		avant += float(j.before)
		apres += float(j.after)
	return {"avant": avant / joueurs.size(), "apres": apres / joueurs.size()}

## Tuile chiffre : grand chiffre et un mot (« 15 · sous 85 »), icône d'alerte quand le compte n'est pas nul.
static func _chiffre(valeur: int, legende: String, alerte: bool, detail: String) -> Control:
	var bloc := Cc.v(2)
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bloc.tooltip_text = detail
	bloc.mouse_filter = Control.MOUSE_FILTER_STOP
	var ligne := Cc.h(8)
	if alerte:
		var icone := Cc.icon("warning", 34, Charte.PERTE)
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(icone)
	ligne.add_child(Cc.label(str(valeur), 56, Charte.PERTE if alerte else Charte.IVOIRE, true, 800))
	bloc.add_child(ligne)
	bloc.add_child(Cc.label(legende.to_upper(), 20, Charte.IVOIRE_2, true, 700))
	return bloc

## Verrou en un mot pour la pastille (la phrase complète reste en info-bulle).
static func _mot_verrou(raison: String) -> String:
	if raison.begins_with("Une réunion"): return "Déjà tenue"
	if raison.begins_with("Rencontre"): return "Match en cours"
	if raison.begins_with("Entraînement") or raison.begins_with("Séance"): return "Séance faite"
	if raison.begins_with("Les réunions"): return "Hors championnat"
	return "Indisponible"

## Raison écrite à côté d'un « Configurer » grisé (mêmes verrous que les réunions, côté séance).
static func _training_lock(app: Control, session: Dictionary) -> String:
	if session.get("status", "pending") == "applied": return "Séance déjà effectuée cette semaine."
	if not app._live().is_empty(): return "Rencontre en cours ou à valider."
	if app.model.meta.get("trained", false): return "Entraînement déjà effectué cette semaine."
	return "Configuration indisponible cette semaine."

static func _medical(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Médical")
	_concussions(list, app, data.medical)
	list.add_child(G.section("Disponibilité et retour", "Suivi des autres blessures : les protocoles agissent à la prochaine séance."))
	if data.medical.players.is_empty(): list.add_child(G.wrap("Aucun joueur à suivre actuellement.", 18))
	for p: Dictionary in data.medical.players:
		var identity: Dictionary = p
		for candidate: Dictionary in app.model.squad:
			if candidate.id == p.id: identity = candidate; break
		G.person(list, identity, _name(app, p.id), "Suivi médical du joueur", 48)
		list.add_child(G.section(_name(app, p.id), "%d semaine(s) d’indisponibilité · condition %.0f · charge %.0f" % [p.injury, p.condition, p.fatigue]))
		if p.injury > 0:
			var picker := OptionButton.new()
			picker.name = "MedicalProtocol_" + str(p.id).replace(":", "_")
			picker.custom_minimum_size.y = 44
			picker.disabled = not data.medical.available
			for protocol: Dictionary in data.medical.protocols:
				picker.add_item(protocol.label)
				picker.set_item_metadata(picker.item_count - 1, protocol.key)
				if protocol.key == p.protocol: picker.select(picker.item_count - 1)
			list.add_child(picker)
			var explanation := G.wrap(str(data.medical.protocols[picker.selected].description), 14)
			list.add_child(explanation)
			picker.item_selected.connect(func(index: int): explanation.text = str(data.medical.protocols[index].description))
			_action(list, "CONFIRMER LE SUIVI", "MedicalChoose_" + str(p.id), data.medical.available, func(): app._command("medical_protocol", {"context":data.context,"id":p.id,"protocol":picker.get_item_metadata(picker.selected)}))
		else:
			list.add_child(G.wrap("Reprise progressive : repos, condition +8, charge −12. Retour complet : condition −7, charge +12 et risque de rechute.", 14))
			_action(list, "REPRISE PROGRESSIVE", "MedicalReturnProgressive_" + str(p.id), data.medical.available, func(): app._command("medical_return", {"context":data.context,"id":p.id,"choice":"progressif"}))
			_action(list, "RETOUR COMPLET À RISQUE", "MedicalReturnFull_" + str(p.id), data.medical.available, func(): app._command("medical_return", {"context":data.context,"id":p.id,"choice":"complet"}))
		list.add_child(G.separator())

## Protocole commotion (World Rugby) : décision du médecin, sans choix du staff ; antécédents de l'effectif.
static func _date(iso: Variant) -> String:
	var text := str(iso)
	return text.substr(8, 2) + "/" + text.substr(5, 2) if text.length() == 10 else text

static func _concussions(list: VBoxContainer, app: Control, medical: Dictionary) -> void:
	var cases: Array = medical.get("commotions", [])
	var history: Array = medical.get("antecedents", [])
	if cases.is_empty() and history.is_empty(): return
	list.add_child(G.section("Protocole commotion", "Règle de World Rugby : 12 jours de repos au moins, 7 jours seulement sans antécédent et avec l’avis favorable d’un spécialiste indépendant. Décision médicale."))
	for c: Dictionary in cases:
		var card := G.card(list, G.ALERT)
		card.name = "Concussion_" + str(c.id).replace(":", "_")
		var left: Variant = c.get("joursRestants")
		var remaining := (" · encore %d jour%s" % [int(left), "s" if int(left) > 1 else ""]) if left != null and int(left) > 0 and int(left) < int(c.jours) else ""
		card.add_child(G.section(_name(app, c.id), "Commotion du %s · %s" % [_date(c.date), str(c.motif)]))
		card.add_child(G.wrap("Retour possible le %s (%d jour(s))%s" % [_date(c.retour), int(c.jours), remaining], 16, G.INK))
		var exception := {"possible":"Exception à 7 jours possible : avis du spécialiste à demander depuis le courrier du médecin.", "accordee":"Avis favorable du spécialiste indépendant : retour au 7e jour.", "refusee":"Avis défavorable du spécialiste indépendant : 12 jours.", "non":"Antécédent ou signes évidents : 12 jours, sans exception." if c.get("antecedent", false) or int(c.get("critere", 0)) == 1 else "Pas de retour à la normale au contrôle du lendemain : 12 jours, sans exception."}
		card.add_child(G.wrap(str(exception.get(str(c.exception), "")), 14))
	if not history.is_empty():
		var lines := PackedStringArray()
		for h: Dictionary in history:
			lines.append("%s : %d commotion%s, dernière le %s%s" % [_name(app, h.id), int(h.commotions), "s" if int(h.commotions) > 1 else "", _date(h.derniere), " (en protocole)" if h.get("enCours", false) else ""])
		list.add_child(G.section("Antécédents de commotion", "\n".join(lines)))
	list.add_child(G.separator())

static func _agents(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var list := _tab(tabs, "Agents")
	list.add_child(G.section("Préparer une prolongation", "Trois propositions par semaine ; aucune prime débitée avant confirmation de signature."))
	if not data.agents.players.is_empty():
		var player := OptionButton.new()
		player.name = "AgentPlayer"
		player.custom_minimum_size.y = 44
		for p: Dictionary in data.agents.players: player.add_item(_name(app, p.id))
		list.add_child(player)
		var choices := G.v(12)
		list.add_child(choices)
		var redraw := func(index: int):
			for child in choices.get_children(): choices.remove_child(child); child.queue_free()
			var p: Dictionary = data.agents.players[index]
			for q: Dictionary in p.quotes:
				var policy: Dictionary = data.agents.policies.filter(func(item: Dictionary): return item.key == q.policy)[0]
				var quote := G.card(choices, G.GOLD)
				quote.add_child(G.section(str(policy.label) + " · " + str(int(q.years)) + " saison(s)", policy.detail))
				var amounts := G.h(16)
				quote.add_child(amounts)
				amounts.add_child(G.metric(G.salary_amount(q.wage), G.salary_period()))
				amounts.add_child(G.metric(G.euros(q.fee), "prime à la signature"))
				quote.add_child(G.wrap("Engagement théorique %s sur %d semaines × %d saison(s)" % [G.euros(q.totalCommitment), q.paidWeeks, q.years], 15))
				quote.add_child(G.wrap(str(q.likely) + " · " + str(int(q.attempts)) + "/3 tentative(s)", 13))
				_action(quote, "ENVOYER LA PROPOSITION", "AgentPropose_" + str(int(q.years)) + "_" + str(q.policy), q.affordable and q.attempts < 3 and app._live().is_empty(), func(): app._command("agent_negotiate", {"context":data.context,"id":q.id,"years":q.years,"policy":q.policy}))
		player.item_selected.connect(redraw)
		redraw.call(0)
	else: list.add_child(G.wrap("Aucune prolongation possible actuellement.", 16))
	list.add_child(G.separator())
	list.add_child(G.section("Accords à confirmer"))
	for talk: Dictionary in data.agents.talks:
		list.add_child(G.wrap(_name(app, talk.id) + " — " + str(talk.message), 16))
		if talk.status in ["ready", "counter"]:
			_action(list, "EXAMINER LA SIGNATURE", "AgentConfirm_" + str(talk.id), app._live().is_empty(), func(): _confirm(app, data, talk))
	list.add_child(G.separator())
	list.add_child(G.section("Les derniers mandats", "Historique persistant limité à 24 entrées."))
	for h: Dictionary in data.agents.history:
		var status: String = {"ready":"accord de principe", "counter":"contre-offre", "withdrawn":"retrait", "signed":"signé"}.get(str(h.status), str(h.status))
		list.add_child(G.wrap("%s · semaine %d · %s · %s · %s" % [G.season_label(h.season), int(h.week) + 1, _name(app, h.id), G.salary(h.wage), status], 14))

static func _confirm(app: Control, data: Dictionary, talk: Dictionary) -> void:
	var paid_weeks: int = 34 if int(app.model.meta.get("clubCount", 0)) == 30 else 29
	for p: Dictionary in data.agents.players:
		if p.id == talk.id and not p.quotes.is_empty(): paid_weeks = int(p.quotes[0].paidWeeks)
	var texte := "%s\nPrime immédiate : %s\nSalaire : %s · %d saison(s)\nEngagement théorique : %s (%d semaines payées par saison)." % [_name(app, talk.id), G.euros(talk.fee), G.salary(talk.acceptedSalary), talk.years, G.euros(talk.acceptedSalary * paid_weeks * talk.years + talk.fee), paid_weeks]
	# Confirmation EN PLACE (main.gd : _confirmation_club), jamais une fenêtre.
	app.confirm("Confirmer la prolongation", texte, func(): app._command("agent_confirm", {"context":data.context,"key":talk.key,"confirmed":true,"wage":talk.acceptedSalary,"years":talk.years,"fee":talk.fee}))
