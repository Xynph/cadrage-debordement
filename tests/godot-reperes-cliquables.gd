extends SceneTree
## Règle de Léo (21/11/2026) : tout ce qui ressemble à une tuile ou une pastille ouvre quelque chose. Vrai clic souris
## (événements poussés dans la fenêtre) au centre de chaque tuile / pastille créée par le lot « phrases » (Bureau,
## Effectif, Préparation), puis contrôle de l'écran d'arrivée. Carrière Monde, vrai moteur ; blessure, fin de contrat
## et lettre médicale posées dans le modèle affiché pour que chaque repère existe.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const U = preload("res://ui/management_state.gd")
var app: Control
var failures: Array[String] = []
var checks := 0
var base: Dictionary = {}

func _initialize() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty(): quit(2); return
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func settle(frames: int = 10) -> void:
	for frame in frames: await process_frame

func wait_model(id: String) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Réponse du vrai moteur " + id)
	await settle()

func scenario() -> Dictionary:
	var m := base.duplicate(true)
	var saison := int(m.meta.get("season", 1))
	m.squad[0].injury = 2
	m.squad[1].contractEnd = saison
	var messages: Array = m.get("messages", [])
	messages.insert(0, "%s s’est blessé pendant la rencontre : 2 semaines d’indisponibilité." % str(m.squad[0].name))
	m.messages = messages
	if m.get("clubLife") is Dictionary and m.clubLife.get("press") is Dictionary and m.clubLife.press.get("conference") is Dictionary: m.clubLife.press.conference.required = false
	return m

func ecran(route: String, famille: String = "Tous") -> void:
	app.model = scenario()
	app.management_ui.erase("fiche_joueur")
	app.set_meta("immersive08_full_player", false)
	# Effectif lu depuis zéro (onglet Vue d'ensemble, tous les joueurs, tri par poste) à chaque essai.
	app.management_ui.roster = U.defaults()
	app.management_ui.roster.family = famille
	app.roster_filter = famille
	app.roster_sort = "Poste"
	app._navigate(route)
	await settle(14)
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	await settle()

func trouver(prefixe: String) -> Control:
	for n: Node in app.root_content.find_children(prefixe + "*", "Control", true, false):
		if (n as Control).is_visible_in_tree(): return n as Control
	return null

## Vrai clic gauche au centre du repère.
func cliquer(cible: Control) -> void:
	var point := cible.get_global_rect().get_center()
	var survol := InputEventMouseMotion.new()
	survol.position = point; survol.global_position = point
	root.push_input(survol)
	for appui in [true, false]:
		var bouton := InputEventMouseButton.new()
		bouton.button_index = MOUSE_BUTTON_LEFT
		bouton.pressed = appui
		bouton.position = point; bouton.global_position = point
		root.push_input(bouton)
		await process_frame
	await settle(14)

func fiche_ouverte() -> bool:
	return app.management_ui.get("fiche_joueur") is Dictionary or bool(app.get_meta("immersive08_full_player", false))

## Clique le premier repère `prefixe` de `route` et vérifie l'arrivée avec `arrivee` (Callable -> bool).
func essai(route: String, prefixe: String, libelle: String, arrivee: Callable, facultatif: bool = false, famille: String = "Tous") -> void:
	await ecran(route, famille)
	var cible := trouver(prefixe)
	if cible == null:
		if not facultatif: check(false, "%s : repère « %s » présent" % [route, prefixe])
		return
	await cliquer(cible)
	var ok: bool = arrivee.call()
	check(ok, "%s · %s → %s (route %s)" % [route, prefixe, libelle, app.route])
	print("REPERES : ", route, " · ", prefixe, " → ", libelle, " : ", "ok" if ok else "ÉCHEC")

func tuile_bureau(legende: String) -> String:
	for n: Node in app.root_content.find_children("OfficePriorityTile*", "Panel", true, false):
		var l := n.find_child("TuileLegende", true, false) as Label
		if l != null and l.text.contains(legende): return str(n.name)
	return "OfficePriorityTileAbsente"

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await wait_model("snapshot initial")
	check(app._command("new_career", {"club": 0, "mode": "world-champ"}), "Commande publique new_career")
	await wait_model("new_career")
	var maximize := Callable(app, "_keep_filled_display")
	if root.size_changed.is_connected(maximize): root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize): root.focus_entered.disconnect(maximize)
	root.mode = Window.MODE_WINDOWED
	await ContextualFlow.settle_club_meetings(app, self, check)
	base = app.model.duplicate(true)
	# Bureau
	await ecran("Bureau")
	var blesses := tuile_bureau("BLESS")
	var contrats := tuile_bureau("CONTRAT")
	await essai("Bureau", blesses, "Effectif filtré sur les blessés", func(): return app.route == "Effectif" and str(app.management_ui.roster.family) == "Blessés", blesses == "OfficePriorityTileAbsente")
	await essai("Bureau", contrats, "Effectif › Contrats, fins de saison", func(): return app.route == "Effectif" and int(app.management_ui.roster.get("immersive_tab", 0)) == 2, contrats == "OfficePriorityTileAbsente")
	await essai("Bureau", "OfficePriorityDeadline1Fond", "l'écran de la priorité", func(): return app.route != "Bureau" or fiche_ouverte())
	await essai("Bureau", "OfficeJournalBlessure1Fond", "fiche du joueur blessé", func(): return fiche_ouverte() or app.route != "Bureau")
	await essai("Bureau", "OfficeFatigueActionTexteFond", "composition", func(): return app.route == "Composition", true)
	await essai("Bureau", "OfficeWatchedActionTexteFond", "Effectif filtré surveillés", func(): return app.route == "Effectif", true)
	await essai("Bureau", "GabiLigne_conseil_plus", "composition", func(): return app.route == "Composition", true)
	# Effectif
	await essai("Effectif", "RosterGroupAvants", "filtre Avants", func(): return app.route == "Effectif" and str(app.management_ui.roster.family) == "Avants")
	await essai("Effectif", "RosterSousTitreFond", "tous les joueurs", func(): return app.route == "Effectif" and str(app.management_ui.roster.family) == "Tous", false, "Avants")
	await essai("Effectif", "RosterSaisonFond", "calendrier", func(): return app.route == "Calendrier")
	await essai("Effectif", "RosterStatutFond", "fiche du joueur", func(): return fiche_ouverte() or app.route != "Effectif")
	await essai("Effectif", "RosterContractEndFond", "contrat du joueur", func(): return fiche_ouverte() or app.route != "Effectif")
	# Préparation
	await essai("Préparation", "PreparationBriefingTitle_injuriesFond", "Effectif", func(): return app.route == "Effectif")
	await essai("Préparation", "PreparationHeadToHeadNone", "fiche du club adverse", func(): return app.route != "Préparation" or fiche_ouverte(), true)
	print("REPERES CLIQUABLES : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop(); app.queue_free(); await settle()
	quit(0 if failures.is_empty() else 1)
