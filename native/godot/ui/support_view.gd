extends RefCounted
const Copy = preload("res://ui/management_copy.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const Cc = preload("res://ui/immersive08/components.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const JaugeAvantApres = preload("res://ui/jauge_avant_apres.gd")
const BarreEffet = preload("res://ui/barre_effet.gd")
const BarreEmpilee = preload("res://ui/barre_empilee.gd")

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
	var variante := _variante()
	if variante == "A" or variante == "B":
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
	else:
		G.chapter(paper, "21", "Le travail de la semaine", "Staff · préparation · cellule médicale · mandats", app.accent)
		paper.add_child(G.wrap(Copy.notice("support", data.notice), 12))
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

## PROVISOIRE (planche de choix du 21/11/2026, revue visuelle n° 1) : deux habillages de l'onglet Staff, A (tuiles et
## anneaux) et B (barres d'effet et barre empilée), choisis par la variable d'environnement CD_VARIANTE_VISUELLE (A par
## défaut ; toute autre valeur rend l'ancien affichage). À retirer dès que Léo a choisi : on ne garde qu'une variante.
static func _variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return "A" if v.is_empty() else v

static func _staff(tabs: TabContainer, app: Control, data: Dictionary) -> void:
	var variante := _variante()
	if variante == "A" or variante == "B":
		_staff_visuel(tabs, app, data, variante)
		return
	var list := _tab(tabs, "Staff")
	var d: Dictionary = data.diagnostic
	list.add_child(G.section("Le diagnostic", str(d.reason)))
	var health := G.h(18)
	list.add_child(health)
	G.gauge(health, "Condition moyenne", float(d.mean))
	G.gauge(health, "Moral du groupe", float(d.morale))
	G.gauge(health, "Confiance", float(d.trust), 100, G.GOLD)
	list.add_child(G.wrap("Condition moyenne %d / 100 · %d joueurs sous 65 · moral %d · confiance %d" % [d.mean, d.fatigue, d.morale, d.trust], 16))
	var meeting_data: Dictionary = data.meeting
	var receipt: Variant = meeting_data.receipt
	var last_decision: Variant = meeting_data.get("lastDecision")
	var current_decision: bool = last_decision is Dictionary and last_decision.get("context") == data.context
	var lock := _meeting_lock(app, receipt is Dictionary or current_decision)
	for option: Dictionary in meeting_data.options:
		var meeting := G.card(list, G.accent_ink(app.accent))
		# Un reçu importé de l’ancienne version peut précéder le contexte natif.
		var matching_receipt: bool = receipt is Dictionary and receipt.get("title") == "Réunion de staff : " + str(option.label)
		var applied: bool = last_decision.get("plan") == option.key if current_decision else matching_receipt
		var detail := str(receipt.body) if applied and matching_receipt else str(option.detail)
		meeting.add_child(G.section(option.label, detail))
		if meeting_data.available:
			meeting.add_child(G.wrap("Prévision : %d joueurs concernés · moral %d · confiance %d" % [option.preview.affected, option.preview.morale, option.preview.trust], 14))
		elif applied:
			meeting.add_child(G.wrap("Réunion tenue cette semaine · Moral actuel %d/100 · Confiance actuelle %d/100" % [d.morale, d.trust], 16, G.GOOD))
		else:
			meeting.add_child(G.wrap(lock, 14))
		var action := "RÉUNION EFFECTUÉE" if applied else "RÉUNIR LE STAFF · " + str(option.label)
		_action(meeting, action, "SupportMeeting_" + str(option.key), meeting_data.available, func(): app._command("staff_meeting", {"context":data.context,"plan":option.key}))
	list.add_child(G.separator())
	list.add_child(G.section("Répartir les charges", "Configurer un plan ne lance pas la séance. La prévision physique précède les effets collectifs et médicaux."))
	var session: Dictionary = data.training.get("session", {})
	if session.get("status", "pending") == "applied":
		var reason: Variant = session.get("reason")
		list.add_child(G.wrap("Séance effectuée. " + (str(reason) if reason != null else "Aucun compte rendu du préparateur pour cette séance."), 16, G.GOOD))
	for plan: Dictionary in data.training.plans:
		list.add_child(G.wrap(str(plan.label) + " — " + str(plan.detail), 17, G.INK))
		var modes: Dictionary = plan.get("effectiveCounts", plan.counts)
		list.add_child(G.wrap("Prévision · %d repos · %d séance normale · %d intensif · condition totale %+.0f" % [modes.repos, int(modes.normal) + int(modes.get("collective", 0)), modes.intense, plan.conditionGain], 14))
		if int(plan.counts.collective) > 0 and plan.has("collective"):
			list.add_child(G.wrap(str(plan.collective.reason), 14))
		_action(list, "CONFIGURER · " + str(plan.label), "SupportTraining_" + str(plan.key), data.training.available, func(): app._command("training_plan", {"context":data.context,"plan":plan.key}))
	_briefing(list, app, data)

static func _briefing(list: VBoxContainer, app: Control, data: Dictionary, visuel: bool = false) -> void:
	list.add_child(G.separator())
	if visuel:
		var tete := Tuile.titre_bloc("Le briefing ciblé", "Consignes préparées pour le coup d’envoi ; aucun résultat garanti.")
		Tuile.proteger(tete)
		list.add_child(tete)
	else:
		list.add_child(G.section("Le briefing ciblé", "Consignes préparées pour le coup d’envoi ; aucun résultat garanti."))
	var b: Dictionary = data.briefing
	if b.evidence is Dictionary:
		list.add_child(G.wrap("Écart avants %+.0f · passe/vitesse %+.0f · danger adverse %+.0f" % [b.evidence.pack, b.evidence.backs, b.evidence.danger], 16))
	for plan: Dictionary in b.plans:
		list.add_child(G.wrap(plan.desc, 14))
		var button := _action(list, str(plan.label), "SupportBriefing_" + str(plan.key), b.available, func(): app._command("strategic_briefing", {"context":data.context,"fixture":b.fixture,"plan":plan.key}))
		if plan.key == b.selected: G.selected(button, app.accent)

## Onglet Staff habillé (variantes A et B) : mêmes données, mêmes commandes et mêmes noms de contrôles que l'ancien
## affichage ; seules la mise en forme et la lecture changent.
static func _staff_visuel(tabs: TabContainer, app: Control, data: Dictionary, variante: String) -> void:
	var list := _tab(tabs, "Staff")
	var d: Dictionary = data.diagnostic
	var tete_diag := Tuile.titre_bloc("Le diagnostic")
	tete_diag.add_child(Tuile.pastille(str(d.reason), Charte.GRIS_VERT, "info"))
	Tuile.proteger(tete_diag)
	list.add_child(tete_diag)
	var diag := Cc.h(28)
	list.add_child(diag)
	if variante == "A":
		diag.add_child(JaugeAnneau.new(float(d.mean), "Condition moyenne"))
		diag.add_child(JaugeAnneau.new(float(d.morale), "Moral du groupe"))
		diag.add_child(JaugeAnneau.new(float(d.trust), "Confiance", Charte.IVOIRE))
	else:
		for jauge: Array in [["Condition moyenne", d.mean, Charte.VERT_CLAIR], ["Moral du groupe", d.morale, Charte.VERT_CLAIR], ["Confiance", d.trust, Charte.IVOIRE]]:
			var j := JaugeAvantApres.new(str(jauge[0]), float(jauge[1]), float(jauge[1]), jauge[2])
			j.simple = true
			diag.add_child(j)
	diag.add_child(_chiffre(int(d.fatigue), "joueur%s sous 65 de condition" % ("s" if int(d.fatigue) > 1 else "")))
	# Les quatre lectures se partagent la largeur du panneau.
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
	var ecarts := 3.0
	for option: Dictionary in meeting_data.options:
		var pv: Dictionary = option.get("preview", {})
		ecarts = maxf(ecarts, absf(float(pv.get("morale", d.morale)) - float(d.morale)))
		ecarts = maxf(ecarts, absf(float(pv.get("trust", d.trust)) - float(d.trust)))
	var bloc: Control
	var rangee: Container
	if variante == "A":
		rangee = Cc.h(18)
		bloc = rangee
	else:
		var carte := Tuile.new("Effet prévu", "rating")
		bloc = carte
		rangee = carte.contenu
		rangee.add_child(_ligne_effet(Control.new(), BarreEffet.new(0, "", 1, true), Control.new()))
	list.add_child(bloc)
	for option: Dictionary in meeting_data.options:
		var matching_receipt: bool = receipt is Dictionary and receipt.get("title") == "Réunion de staff : " + str(option.label)
		var applied: bool = last_decision.get("plan") == option.key if current_decision else matching_receipt
		var detail := str(receipt.body) if applied and matching_receipt else str(option.detail)
		var pv: Dictionary = option.get("preview", {})
		var etat := "" if meeting_data.available else ("Réunion tenue cette semaine · Moral actuel %d/100 · Confiance actuelle %d/100" % [d.morale, d.trust] if applied else lock)
		var pastille_etat: Control = null
		if not meeting_data.available:
			pastille_etat = Tuile.pastille("Réunion tenue", Charte.VERT_CLAIR, "check", etat) if applied else Tuile.pastille(_mot_verrou(lock), Charte.GRIS_VERT, "clock", lock)
		var bouton := Tuile.pilule("Réunion effectuée" if applied else "Réunir le staff", "SupportMeeting_" + str(option.key), meeting_data.available, etat, func(): app._command("staff_meeting", {"context":data.context,"plan":option.key}))
		bouton.accessibility_name = "Réunir le staff · " + str(option.label)
		var concernes: Control = Tuile.pastille("%d joueurs concernés" % int(pv.get("affected", 0))) if meeting_data.available else null
		var icone: String = {"recuperation": "heart", "cohesion": "people", "exigence": "target"}.get(str(option.key), "")
		if variante == "A":
			var tuile := Tuile.new(str(option.label), icone, applied)
			rangee.add_child(tuile)
			tuile.contenu.add_child(Cc.wrap(detail, 19, Charte.IVOIRE_2))
			if meeting_data.available:
				tuile.contenu.add_child(JaugeAvantApres.new("Moral", float(d.morale), float(pv.get("morale", d.morale))))
				tuile.contenu.add_child(JaugeAvantApres.new("Confiance", float(d.trust), float(pv.get("trust", d.trust)), Charte.IVOIRE))
			if concernes != null: tuile.pied.add_child(concernes)
			if pastille_etat != null: tuile.pied.add_child(pastille_etat)
			var vide := Control.new()
			Cc.fill(vide)
			tuile.pied.add_child(vide)
			tuile.pied.add_child(bouton)
		else:
			rangee.add_child(Cc.rule())
			var gauche := Cc.v(4)
			var tete := Cc.h(10)
			if not icone.is_empty(): tete.add_child(Cc.icon(icone, 26, Charte.IVOIRE))
			tete.add_child(Cc.label(str(option.label).to_upper(), 25, Charte.IVOIRE, true, 700))
			gauche.add_child(tete)
			gauche.add_child(Cc.wrap(detail, 18, Charte.IVOIRE_2))
			var milieu := Cc.v(4)
			if meeting_data.available:
				milieu.add_child(BarreEffet.new(float(pv.get("morale", d.morale)) - float(d.morale), "moral", ecarts))
				milieu.add_child(BarreEffet.new(float(pv.get("trust", d.trust)) - float(d.trust), "confiance", ecarts))
			else:
				pastille_etat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				milieu.add_child(pastille_etat)
			var droite := Cc.v(8)
			droite.alignment = BoxContainer.ALIGNMENT_CENTER
			if concernes != null:
				concernes.size_flags_horizontal = Control.SIZE_SHRINK_END
				droite.add_child(concernes)
			bouton.size_flags_horizontal = Control.SIZE_SHRINK_END
			droite.add_child(bouton)
			rangee.add_child(_ligne_effet(gauche, milieu, droite))
	Tuile.proteger(bloc)
	var tete_charges := Tuile.titre_bloc("Répartir les charges", "Configurer un plan ne lance pas la séance. La prévision physique précède les effets collectifs et médicaux.")
	var session: Dictionary = data.training.get("session", {})
	if session.get("status", "pending") == "applied":
		var reason: Variant = session.get("reason")
		tete_charges.add_child(Tuile.pastille("Séance effectuée", Charte.VERT_CLAIR, "check", str(reason) if reason != null else ""))
	Tuile.proteger(tete_charges)
	list.add_child(tete_charges)
	if session.get("status", "pending") == "applied" and session.get("reason") != null:
		var compte_rendu := Cc.wrap(str(session.reason), 19, Charte.IVOIRE_2)
		Tuile.proteger(compte_rendu)
		list.add_child(compte_rendu)
	var verrou_charge := _training_lock(app, session)
	var plans: BoxContainer = Cc.h(18) if variante == "A" else Cc.v(14)
	list.add_child(plans)
	for plan: Dictionary in data.training.plans:
		var modes: Dictionary = plan.get("effectiveCounts", plan.counts)
		var barre := BarreEmpilee.new([{"valeur": int(modes.repos), "libelle": "repos"}, {"valeur": int(modes.normal) + int(modes.get("collective", 0)), "libelle": "séance normale"}, {"valeur": int(modes.intense), "libelle": "intensif"}])
		var gain := Cc.label("Condition totale %+.0f" % float(plan.conditionGain), 21, Charte.IVOIRE, true, 700)
		var collectif: Control = Cc.wrap(str(plan.collective.reason), 18, Charte.IVOIRE_2) if int(plan.counts.collective) > 0 and plan.has("collective") else null
		var configurer := Tuile.pilule("Configurer", "SupportTraining_" + str(plan.key), data.training.available, verrou_charge, func(): app._command("training_plan", {"context":data.context,"plan":plan.key}))
		configurer.accessibility_name = "Configurer · " + str(plan.label)
		var icone: String = {"proteger": "shield", "relever": "school", "equilibrer": "train"}.get(str(plan.key), "")
		if variante == "A":
			var tuile := Tuile.new(str(plan.label), icone)
			plans.add_child(tuile)
			tuile.contenu.add_child(Cc.wrap(str(plan.detail), 18, Charte.IVOIRE_2))
			tuile.contenu.add_child(barre)
			tuile.contenu.add_child(gain)
			if collectif != null: tuile.contenu.add_child(collectif)
			if not data.training.available: tuile.pied.add_child(Tuile.pastille(_mot_verrou(verrou_charge), Charte.GRIS_VERT, "clock", verrou_charge))
			var vide := Control.new()
			Cc.fill(vide)
			tuile.pied.add_child(vide)
			tuile.pied.add_child(configurer)
		else:
			var ligne := Tuile.new()
			plans.add_child(ligne)
			var gauche := Cc.v(4)
			var tete := Cc.h(10)
			if not icone.is_empty(): tete.add_child(Cc.icon(icone, 26, Charte.IVOIRE))
			tete.add_child(Cc.label(str(plan.label).to_upper(), 25, Charte.IVOIRE, true, 700))
			gauche.add_child(tete)
			gauche.add_child(Cc.wrap(str(plan.detail), 18, Charte.IVOIRE_2))
			if collectif != null: gauche.add_child(collectif)
			var milieu := Cc.v(6)
			milieu.add_child(barre)
			milieu.add_child(gain)
			var droite := Cc.v(6)
			droite.alignment = BoxContainer.ALIGNMENT_CENTER
			configurer.size_flags_horizontal = Control.SIZE_SHRINK_END
			droite.add_child(configurer)
			if not data.training.available:
				var p := Tuile.pastille(_mot_verrou(verrou_charge), Charte.GRIS_VERT, "clock", verrou_charge)
				p.size_flags_horizontal = Control.SIZE_SHRINK_END
				droite.add_child(p)
			ligne.contenu.add_child(_ligne_effet(gauche, milieu, droite))
	Tuile.proteger(plans)
	_briefing(list, app, data, true)

## Rangée à trois colonnes (titre et texte · graphique · chiffres et action), mêmes largeurs d'une rangée à l'autre.
static func _ligne_effet(gauche: Control, milieu: Control, droite: Control) -> HBoxContainer:
	var ligne := Cc.h(24)
	Cc.fill(gauche, false, 1.15)
	Cc.fill(milieu, false, 1.0)
	droite.custom_minimum_size.x = Cc.px(250)
	ligne.add_child(gauche)
	ligne.add_child(milieu)
	ligne.add_child(droite)
	return ligne

## Grand chiffre et sa légende (même lecture que l'anneau, sans part d'un total).
static func _chiffre(valeur: int, legende: String) -> Control:
	var bloc := Cc.v(2)
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nombre := Cc.label(str(valeur), 56, Charte.IVOIRE, true, 800)
	bloc.add_child(nombre)
	var texte := Cc.wrap(legende.to_upper(), 19, Charte.IVOIRE_2, true, 700)
	texte.custom_minimum_size.x = Cc.px(150)
	bloc.add_child(texte)
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
		card.add_child(G.wrap("Retour possible le %s (%d jours)%s" % [_date(c.retour), int(c.jours), remaining], 16, G.INK))
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
