extends SceneTree
## Entraînement › Individuel : intensité auto par forme (revue FM27, idée 13, option A retenue le 23/11/2026).
## Cinq cartes de forme avec leur règle (un clic la change tout de suite, sans fenêtre ni Valider), liste de l'effectif,
## risque en 5 niveaux (filtre), avis du kiné à tous, petite fenêtre d'un joueur ; « Auto » remplace « Suivre le collectif ».
const ContextualFlow = preload("helpers/contextual_flow.gd")
const IntensiteAuto = preload("res://ui/immersive08/intensite_auto.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const FicheCharge = preload("res://ui/immersive08/fiche_charge.gd")
const Fatigue = preload("res://ui/immersive08/fatigue_overview.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for frame in 8: await process_frame
func wait_worker() -> void:
	var until := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_worker()
	check(not app.waiting and app.bridge.last_response_ok, "Worker réel · " + id)
func found(id: String) -> Control: return app.find_child(id, true, false) as Control
func page() -> Control: return found("ImmersiveTraining")
func onglet() -> void:
	app._clear_dialogs()
	if page() == null:
		app.Immersive.open_training(app); await settle()
	page()._open_tab(2); await settle()
func press(id: String) -> bool:
	var button := found(id) as BaseButton
	check(button != null and not button.disabled and button.is_visible_in_tree(), "Cliquable · " + id)
	if button == null or button.disabled: return false
	button.pressed.emit(); await settle()
	return true
func cle(p: Dictionary) -> String: return str(p.get("id", "")).replace(":", "_")
func lignes() -> Array: return app.find_children("IntensiteLigne_*", "Control", true, false)
func textes(node: Node) -> Array:
	var out: Array = []
	for label: Node in node.find_children("*", "Label", true, false): out.append(str(label.text))
	return out
func joueur(id: Variant) -> Dictionary:
	for p: Dictionary in app.model.squad:
		if p.id == id: return p
	return {}

func run() -> void:
	root.size = Vector2i(2560, 1440)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode":"world-champ", "club":29})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app.coach.close()
	# « Auto » remplace « Suivre le collectif » partout.
	check(Training.INDIVIDUAL.collective == "Auto" and Fatigue.PLANS.collective == "Auto" and FicheCharge.MODES[0][1] == "Auto", "Libellé Auto partout")
	var moteur: Dictionary = app.model.decisions.training.get("intensiteAuto", {})
	check(moteur.get("regle", []) == ["repos", "repos", "normal", "normal", "normal"] and moteur.get("seuils", []).map(func(v: Variant): return int(v)) == [60, 70, 80, 90], "Règle par défaut et seuils du moteur")
	await onglet()
	check(found("IntensiteRegle") != null and found("IntensiteListe") != null and found("IntensiteRisques") != null, "Onglet Individuel : règle, liste, risques")
	for i in 5:
		check(found("IntensiteForme_%d" % i) != null and found("IntensiteRegle_%d" % i) is Button, "Carte de forme %d avec sa règle cliquable" % i)
		check(found("IntensiteRisque_%d" % i) is Button, "Niveau de risque %d cliquable" % i)
	check(lignes().size() == app.model.squad.size(), "Tout l'effectif listé")
	for texte: String in textes(page()):
		check(not texte.to_lower().contains("suivre le collectif") and not texte.to_lower().contains("valider"), "Pas de « Suivre le collectif » ni de Valider : " + texte)
	# Un clic sur la règle d'une carte la change tout de suite (Intensif → Repos), sans petite fenêtre.
	var avant: String = str(moteur.regle[4])
	if await press("IntensiteRegle_4"):
		check(found("IntensiteRegleFenetre") == null, "Aucune fenêtre de choix de règle")
		await wait_worker()
		check(app.last_command == "set_intensite_auto" and app.bridge.last_response_ok, "Commande de règle envoyée au moteur")
		var regle: Array = app.model.decisions.training.intensiteAuto.regle
		check(regle[4] == IntensiteAuto.mode_suivant(avant) and regle[4] == "intense", "Règle « Très bonne » : %s → %s" % [avant, regle[4]])
		for p: Dictionary in app.model.squad:
			if IntensiteAuto.auto(p): check(p.loadMode == IntensiteAuto.intensite(app, p), "Intensité finale affichée = moteur · " + str(p.name))
			if IntensiteAuto.auto(p) and float(p.condition) >= 90 and float(p.physicalLoad) < 25: check(p.loadMode == "intense", "Très bonne forme, charge basse : Intensif · " + str(p.name))
			if IntensiteAuto.auto(p) and (float(p.condition) < 90 or float(p.physicalLoad) >= 25): check(p.loadMode != "intense", "Intensif refusé hors très bonne forme ou charge haute · " + str(p.name))
		await onglet()
		check(str((found("IntensiteRegle_4") as Button).tooltip_text).contains("Intensif → Repos"), "La carte montre la nouvelle règle")
		check(found("IntensiteSeance") is Button, "Séance de la semaine montrée et cliquable")
		await press("IntensiteRegle_4"); await wait_worker()
		await onglet(); await press("IntensiteRegle_4"); await wait_worker()
		check(app.model.decisions.training.intensiteAuto.regle[4] == "normal", "Trois clics : la règle revient à Normal")
		await onglet()
	# Tri par forme : la forme la plus basse en tête.
	if await press("IntensiteTri_forme"):
		var premiere: Variant = lignes()[0]
		var plus_basse := INF
		for p: Dictionary in app.model.squad: plus_basse = minf(plus_basse, float(p.condition))
		check(float(joueur(premiere.get_meta("player_id")).condition) == plus_basse, "Tri par forme : la plus basse en tête")
	# Filtre par niveau de risque, puis tout l'effectif.
	for i in 5:
		var nombre: int = app.model.squad.filter(func(p: Dictionary): return IntensiteAuto.niveau_risque(app, p) == i).size()
		if nombre == 0: continue
		await press("IntensiteRisque_%d" % i)
		check(lignes().size() == nombre, "Filtre risque %d : %d joueur(s)" % [i, nombre])
		await press("IntensiteRisqueTous")
		check(lignes().size() == app.model.squad.size(), "Tout l'effectif après le filtre")
		break
	# Petite fenêtre d'un joueur : un clic sur une intensité l'applique tout de suite.
	var cible: Dictionary = app.model.squad.filter(func(p: Dictionary): return float(p.get("injury", 0)) <= 0)[0]
	if await press("IntensiteJoueur_" + cle(cible)):
		check(found("IntensiteJoueurFenetre") != null, "Petite fenêtre du joueur")
		check(found("IntensiteJoueurChoix_collective") != null, "Choix Auto dans la fenêtre")
		if await press("IntensiteJoueurChoix_intense"):
			await wait_worker()
			check(joueur(cible.id).loadPlan == "intense" and joueur(cible.id).loadMode == "intense", "Choix Intensif appliqué au joueur")
	await onglet()
	# Avis du kiné à tous : une seule commande, chaque joueur valide suit l'avis.
	var ecarts: int = app.model.squad.filter(func(p: Dictionary): return float(p.get("injury", 0)) <= 0 and IntensiteAuto.kine(p) != IntensiteAuto.intensite(app, p)).size()
	check(ecarts > 0, "Des écarts avec l'avis du kiné")
	if ecarts > 0 and await press("IntensiteKineTous"):
		await wait_worker()
		check(app.last_command == "appliquer_avis_kine", "Une seule commande pour l'avis du kiné")
		for p: Dictionary in app.model.squad:
			if float(p.get("injury", 0)) <= 0: check(p.loadMode == p.avisKine, "Avis du kiné suivi · " + str(p.name))
		await onglet()
		check((found("IntensiteKineTous") as Button).disabled, "Plus d'écart : bouton du kiné éteint")
	# Séance de la semaine : un clic ouvre l'onglet Semaine ; un cran choisi là change l'intensité finale des joueurs en Auto.
	await onglet()
	if await press("IntensiteSeance"):
		check(int(app.management_ui.immersive_training.get("tab", -1)) == 0, "Séance → onglet Semaine")
	app.management_ui.immersive_training.mode = "repos"
	await onglet()
	for p: Dictionary in app.model.squad:
		if IntensiteAuto.auto(p): check(IntensiteAuto.intensite(app, p) == str(p.autoModes.repos), "Séance Repos choisie : intensité finale selon la forme · " + str(p.name))
	app.management_ui.immersive_training.erase("mode")
	# Fiche joueur › charge : Auto avec l'intensité de sa règle.
	var auto_p: Array = app.model.squad.filter(func(p: Dictionary): return IntensiteAuto.auto(p))
	if not auto_p.is_empty():
		FicheCharge.ouvrir(app, auto_p[0]); await settle()
		var ligne := found("IndividualLoad_collective")
		check(ligne != null and textes(ligne).any(func(t: String): return t.begins_with("Auto  →  ")), "Fiche : « Auto → intensité »")
	finish()

func finish() -> void:
	print("INTENSITE AUTO : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	if app != null: app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
