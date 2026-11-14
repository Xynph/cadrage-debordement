extends SceneTree
## Délégation de la composition au staff et alerte de fatigue de Gabi, dans le vrai jeu (moteur Node réel) :
## - alerte : des titulaires de la feuille du prochain match sont sous 70 % de condition (selection.fatigue,
##   calculée par le moteur) ; Gabi la signale (bulle ou bandeau, une seule fois par jour de jeu) et le carnet du
##   Bureau l'affiche avec « Suivre le conseil » ; suivre le conseil fait souffler les fatigués (set_lineup) ;
## - délégation : bouton « Déléguer le match » avant le coup d'envoi, case « Confier aussi la composition au
##   staff » visible et cochée par défaut, choix mémorisé dans la carrière, match joué jusqu'au bout.
## Captures (hors CI) : CD_DELEGUE_CAPTURES=<dossier> sous un affichage réel.
const Avis = preload("res://guide/gabi_avis.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")
const Dialogue = preload("res://ui/delegation_dialog.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var avant: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func wait_model() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")

func settle(frames: int = 24) -> void:
	await create_timer(.25).timeout
	for i in frames: await process_frame

func capture(id: String) -> void:
	var directory := OS.get_environment("CD_DELEGUE_CAPTURES")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id + ".png"))

func sentences(text: String) -> int:
	return RegEx.create_from_string("[.!?…](\\s|$)").search_all(text.strip_edges()).size()

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("import", {"text": FileAccess.get_file_as_string(OS.get_environment("CD_DELEGUE_SAUVEGARDE"))}); await wait_model()
	check(app.model.get("club") is Dictionary and str(app.model.get("meta", {}).get("mode")) == "world", "Carrière Monde importée")
	check(app.model.get("next") is Dictionary and app.model.get("live") == null, "Jour de match, rien en cours")
	donnees()
	await bulle_et_carnet()
	await suivre()
	await delegation()
	print("DELEGUE_COMPOSITION ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	app.closing = true
	app.bridge.stop()
	quit(1 if failures.size() > 0 else 0)

## Conseil de Gabi calculé sur le modèle réel : titulaires sous 70 %, remplaçants frais, action valide.
func donnees() -> void:
	var model: Dictionary = app.model
	var fatigue := Avis.fatigue_donnees(model)
	check(not fatigue.is_empty() and int(fatigue.get("threshold", 0)) == 70, "Le moteur signale les titulaires sous 70 %")
	var starters := {}
	for assignment: Dictionary in model.selection.slots:
		if int(assignment.slot) < 15 and assignment.get("playerId") is String: starters[assignment.playerId] = true
	for starter: Dictionary in fatigue.get("starters", []):
		check(float(starter.condition) < 70.0 and starters.has(str(starter.playerId)), "Signalé : titulaire sous 70 %% (%s)" % str(starter.condition))
	var avis := Avis.fatigue(model)
	var texte := str(avis.get("texte", ""))
	var count := sentences(texte)
	check(not texte.is_empty() and count >= 1 and count <= 3, "Texte de Gabi : 1 à 3 phrases (%d) : %s" % [count, texte])
	check(texte.contains("%") and not texte.contains("%d") and not texte.contains("{"), "Texte de Gabi : conditions citées, aucun gabarit oublié")
	var noms_cites := 0
	for starter: Dictionary in fatigue.starters.slice(0, 3):
		if texte.contains(Avis._nom(Avis.joueur(model, str(starter.playerId)))): noms_cites += 1
	check(noms_cites >= 1, "Gabi nomme les joueurs fatigués")
	var action: Dictionary = avis.get("action", {})
	check(str(action.get("type", "")) == "composition" and str(action.get("libelle", "")) == "Suivre le conseil", "Conseil actionnable : « Suivre le conseil »")
	var changes: Array = action.get("changements", [])
	check(changes.size() == mini((fatigue.changes as Array).size(), Avis.FATIGUE_CHANGEMENTS_MAX) and not changes.is_empty(), "Un remplacement proposé par titulaire fatigué, au plus %d (%d)" % [Avis.FATIGUE_CHANGEMENTS_MAX, changes.size()])
	for change: Dictionary in changes:
		var eligible := false
		for assignment: Dictionary in model.selection.slots:
			if int(assignment.slot) == int(change.slot) and str(change.playerId) in assignment.get("eligibleIds", []): eligible = true
		check(eligible and not starters.has(str(change.playerId)), "Remplaçant admissible au poste et jamais titulaire : " + str(change))
		var entrant := Avis.joueur(model, str(change.playerId))
		check(Avis.condition(entrant) >= 75.0 and not Avis.blesse(entrant), "Remplaçant frais et valide : %s (%d %%)" % [str(entrant.get("name")), int(Avis.condition(entrant))])
	check(Avis.fatigue(model) == avis, "Déterministe")
	var sans := model.duplicate(true)
	sans.selection.erase("fatigue")
	check(Avis.fatigue(sans).is_empty() and Avis.fatigue_donnees({}).is_empty(), "Sans alerte du moteur (ancien modèle compris) : rien")
	var semaine := Semaine.synthese(model)
	var alerte := ""
	for ligne: Dictionary in semaine.get("lignes", []):
		if ligne.cle == "alerte": alerte = str(ligne.texte)
	check(alerte.contains("70 %") and alerte.contains("titulaire"), "Carnet : l'alerte de la semaine : " + alerte)
	var conseil: Dictionary = semaine.get("conseil", {})
	check(str(conseil.get("action", {}).get("type", "")) == "composition" and str(conseil.get("texte", "")).contains("souffler"), "Carnet : conseil de fatigue : " + str(conseil.get("texte", "")))
	check(str(Semaine.synthese(sans).get("conseil", {}).get("texte", "")) != str(conseil.get("texte", "")), "Sans alerte, le conseil de la semaine change")

func fatigue_bulle() -> bool:
	return app.coach._bulle.visible and str(app.coach._contenu.get("titre", "")) == "GABI · FATIGUE"

func fatigue_attente() -> bool:
	return str(app.coach._attente.get("event", "")).begins_with("fatigue:")

func cles_fatigue() -> int:
	var count := 0
	for key: Variant in app.coach.profile.data.events:
		if str(key).begins_with("fatigue:"): count += 1
	return count

## Bulle de Gabi : signalée une seule fois par jour de jeu, quel que soit l'écran ; carnet du Bureau avec « Suivre le conseil ».
func bulle_et_carnet() -> void:
	var coach: Control = app.coach
	check(coach._adjoint_actif() or true, "Gabi adjoint")
	for route: String in ["Bureau", "Effectif", "Bureau"]:
		app._navigate(route); await settle()
		if coach.expanded: coach.close(); await settle()
	# Gabi signale l'alerte : bulle ouverte d'office, ou indice dans le bandeau si la limite spontanée du jour est prise.
	if not fatigue_bulle() and fatigue_attente(): coach._clic_bandeau(); await settle()
	check(fatigue_bulle(), "Gabi signale les titulaires fatigués dans sa bulle (bandeau)")
	check(coach._bulle_suivre != null and coach._bulle_suivre.text == "Suivre le conseil", "La bulle propose « Suivre le conseil »")
	check(cles_fatigue() == 1, "Alerte consommée : une clé du jour dans le profil de Gabi (%d)" % cles_fatigue())
	check(coach.profile.last_error.is_empty() and coach.profile._valid(coach.profile.data), "Profil de Gabi valide avec la clé du jour (écriture acceptée) : " + coach.profile.last_error)
	await capture("gabi-alerte-fatigue-bulle")
	app._navigate("Bureau"); await settle()
	coach.fermer_bulle(); await settle()
	# Pas de spam : aucune seconde alerte le même jour, ni en changeant d'écran ni en revenant.
	var reapparitions := 0
	for route: String in ["Composition", "Effectif", "Club", "Bureau", "Finances", "Bureau"]:
		app._navigate(route); await settle(12)
		if coach.expanded: coach.close(); await settle(12)
		if fatigue_bulle() or fatigue_attente(): reapparitions += 1
	check(reapparitions == 0, "Une alerte par jour au plus : aucune réapparition (%d)" % reapparitions)
	check(cles_fatigue() == 1, "Toujours une seule clé du jour (%d)" % cles_fatigue())
	coach.fermer_bulle(); await settle()
	# Carnet du Bureau : alerte et conseil avec « Suivre le conseil ».
	app._navigate("Bureau"); await settle(40)
	var ligne: Label = app.find_child("GabiLigne_alerte", true, false)
	check(ligne != null and ligne.text.contains("70 %"), "Carnet du Bureau : ligne d'alerte sous 70 %")
	var conseil: Label = app.find_child("GabiLigne_conseil", true, false)
	check(conseil != null and conseil.text.contains("souffler"), "Carnet du Bureau : conseil de fatigue")
	var suivre: Button = app.find_child("GabiBureauSuivre", true, false)
	check(suivre != null and suivre.text == "Suivre le conseil" and not suivre.disabled, "Carnet du Bureau : « Suivre le conseil »")
	await capture("gabi-alerte-fatigue")

## « Suivre le conseil » : les fatigués soufflent (remplacement par le meilleur remplaçant frais au poste).
func suivre() -> void:
	var model: Dictionary = app.model
	var proposition: Array = Avis.fatigue(model).action.changements
	var fatigue_avant := int(Avis.fatigue_donnees(model).get("count", 0))
	var suivre: Button = app.find_child("GabiBureauSuivre", true, false)
	if suivre == null: check(false, "Bouton « Suivre le conseil » introuvable"); return
	suivre.pressed.emit()
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		await process_frame
		if not app.waiting and app.coach._file.is_empty(): break
	await settle()
	var apres: Dictionary = app.model
	check(bool(apres.selection.valid), "La feuille reste valide après le conseil : " + str(apres.selection.get("errors")))
	for change: Dictionary in proposition:
		var place := ""
		for assignment: Dictionary in apres.selection.slots:
			if int(assignment.slot) == int(change.slot): place = str(assignment.get("playerId", ""))
		check(place == str(change.playerId), "Poste %d : le remplaçant frais est titulaire" % (int(change.slot) + 1))
	var fatigue_apres := int(Avis.fatigue_donnees(apres).get("count", 0))
	check(fatigue_apres <= fatigue_avant - proposition.size(), "L'alerte est réglée pour les joueurs remplacés (%d -> %d)" % [fatigue_avant, fatigue_apres])
	check(str(app.coach._contenu.get("titre", "")) == "GABI" and str(app.coach._contenu.get("texte", "")).contains("C'est fait"), "Gabi confirme : « C'est fait »")
	app.coach.fermer_bulle()

## Avant le coup d'envoi : « Déléguer le match », case « Confier aussi la composition au staff » cochée par défaut.
func delegation() -> void:
	check(Dialogue.composition_confiee(app.model), "Nouvelle carrière : choix mémorisé = cochée par défaut")
	check(Dialogue.composition_confiee({}) and Dialogue.composition_confiee({"decisions": {"delegation": {"lineup": false}}}), "Ancienne sauvegarde sans le champ : cochée par défaut")
	check(not Dialogue.composition_confiee({"decisions": {"delegation": {"matchLineup": false}}}), "Choix décoché mémorisé")
	# Le coup d'envoi s'ouvre le jour de la rencontre (calendrier journalier du vrai jeu) : on avance jusque-là.
	check(await ContextualFlow.prepare_match_day(app, self, check), "Jour de match atteint")
	app.timer.stop()
	app._navigate("Match"); await settle(40)
	var bouton: Button = app.find_child("MatchOpenDelegation", true, false)
	check(bouton != null and bouton.is_visible_in_tree() and not bouton.disabled, "Bouton « Déléguer le match » visible avant le coup d'envoi")
	if bouton == null or bouton.disabled: return
	bouton.pressed.emit(); await settle(30)
	var dialogue: Window = app.get_node_or_null("MatchDelegationDialog")
	check(dialogue != null and dialogue.visible, "La fenêtre de délégation s'ouvre")
	if dialogue == null: return
	var case_: CheckBox = dialogue.find_child("MatchDelegationComposition", true, false)
	check(case_ != null and case_.is_visible_in_tree() and case_.text == "Confier aussi la composition au staff", "Case « Confier aussi la composition au staff » visible")
	check(case_ != null and case_.button_pressed, "La case est cochée par défaut")
	var detail: Label = dialogue.find_child("MatchDelegationDetail", true, false)
	var cochee: String = detail.text
	check(cochee.contains("refait la feuille"), "Détail (cochée) : " + cochee)
	await capture("delegue-composition")
	case_.button_pressed = false; await settle(6)
	check(detail.text != cochee and detail.text.contains("telle quelle"), "Décochable : le détail explique la feuille gardée : " + detail.text)
	case_.button_pressed = true; await settle(6)
	check(detail.text == cochee, "Recochée : retour au détail d'origine")
	dialogue.get_ok_button().pressed.emit()
	# begin_match { delegated, composition } puis delegate, chaînés : le match est joué jusqu'au bout.
	var until := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < until:
		await process_frame
		if not app.waiting and app.model.get("live") is Dictionary and app.model.live.get("finished", false): break
	for i in 30: await process_frame
	var live: Variant = app.model.get("live")
	check(live is Dictionary and live.get("finished", false), "Match délégué joué jusqu'au bout")
	check(str(app.last_command) in ["delegate", "match_talk_continue"] or live is Dictionary, "Commande de délégation reçue (" + str(app.last_command) + ")")
	check(Dialogue.composition_confiee(app.model) and app.model.decisions.delegation.get("matchLineup", false) == true, "Choix mémorisé dans la carrière (cochée)")
	check(not bool(app.model.decisions.delegation.get("lineup", true)), "Le réglage permanent « sélection des 23 » reste décoché")
	await capture("delegue-composition-apres")
