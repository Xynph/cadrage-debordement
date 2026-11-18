extends SceneTree
## Première heure de jeu, sur une vraie carrière Monde (moteur réel) :
## - écran de création : bandeau « Défis de départ » calculé par le moteur, une carte choisit le club et le défi,
##   le président l'annonce, la création fixe l'objectif du club ;
## - deux premières semaines : au premier passage sur un écran clé, Gabi explique en deux phrases avec une
##   action directe (même sur la composition), une seule fois par écran ;
## - après 14 jours, Gabi se met en retrait (un mot, puis plus d'explications) ;
## - « Je connais déjà » : aucune explication d'écran.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Accueil = preload("res://guide/gabi_accueil.gd")
const Defis = preload("res://ui/creation_options/defis.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func wait_model() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func find(name: String) -> Node:
	return app.find_child(name, true, false)

func genre() -> String:
	return str(app.coach._contenu.get("genre", "")) if app.coach._bulle.visible else ""

## Va sur un écran et laisse Gabi parler (réexamen toutes les 0,5 s).
func aller(route: String) -> void:
	app.coach.fermer_bulle()
	app._navigate(route)
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and genre() != "accueil": await process_frame
	await settle()

func creer(club: int, connu: bool) -> void:
	app.coach.fermer_bulle()
	await wait_model(); await settle()
	app.set_meta("creation_connu", connu)
	app._command("new_career", {"club": club, "mode": "world-champ", "start": "premiers-clubs"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	await settle()

func run() -> void:
	# Garde-fou : un blocage rend la main avec les échecs plutôt qu'un dépassement muet de la CI.
	create_timer(270.0).timeout.connect(func() -> void:
		printerr("FAIL: délai dépassé (route ", app.route if app else "", ", attente ", app.waiting if app else "", ")")
		print("PREMIERE_HEURE ", checks, " controles, ", failures.size() + 1, " echecs")
		quit(1))
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	print("PHASE defis")
	# --- Défis de départ ---
	load("res://ui/entry_screens.gd").begin_creation(app)
	await settle(); await wait_model(); await settle(12)
	check(Defis.liste(app).size() == 5, "Cinq défis reçus du moteur (%d)" % Defis.liste(app).size())
	check(find("CreationDefis") != null, "Bandeau « Défis de départ » sur l'écran de création")
	var carte: Button = find("CreationDefi_promu")
	check(carte != null, "Carte « Sauver un promu »")
	var promu: Dictionary = {}
	for d: Dictionary in Defis.liste(app):
		if d.id == "promu": promu = d.clubs[0]
	if carte != null: carte.pressed.emit(); await settle(12)
	check(int(app.management_ui.get("creation_selection", -1)) == int(promu.get("club", -2)), "La carte sélectionne le club du défi")
	check(not Defis.choix(app, int(promu.get("club", -2))).is_empty(), "Le défi est retenu pour ce club")
	app.management_ui["creation_step"] = "carriere"; app._render(); await settle(12)
	var but: Node = find("CreationPresidentGoal")
	check(but != null and "Maintien" in str(but.get_child(0).text if but.get_child_count() > 0 and but.get_child(0) is Label else ""), "Le président annonce le maintien")
	check(find("CreationPresidentChallenge") != null, "Le défi est rappelé dans le mot du président")
	check(find("CreationGabiConnu") is CheckBox, "Case « Je connais déjà » à la création")
	# L'aperçu du club est demandé au moteur juste après l'affichage : on attend sa réponse avant de créer.
	await settle(); await wait_model(); await settle()
	var demarrer: Button = find("CreationStart")
	check(demarrer != null and not demarrer.disabled, "Bouton « Prendre les rênes »")
	if demarrer != null: demarrer.pressed.emit()
	await settle(); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	await settle()
	check(app._has_career() and str(app.model.club.get("goal", "")) == "Maintien", "Carrière créée avec l'objectif du défi")
	if not app._has_career():
		print("PREMIERE_HEURE ", checks, " controles, ", failures.size(), " echecs (création impossible)")
		quit(1); return
	print("PHASE accueil")
	# --- Deux premières semaines ---
	var coach: Control = app.coach
	var etat := Accueil.etat(coach.profile.data)
	check(not etat.is_empty() and not etat.connu and etat.debut == str(app.model.meta.get("calendarToday", "")).substr(0, 10), "Accueil démarré le jour de la création")
	await aller("Effectif")
	check(genre() == "accueil", "Effectif : Gabi explique au premier passage")
	check(coach._bulle_texte.text.length() <= 160, "Texte court (%d caractères)" % coach._bulle_texte.text.length())
	var action: Button = find("GabiAccueilAction0")
	check(action != null and not action.disabled, "Action directe proposée")
	if action != null: action.pressed.emit(); await settle()
	check(str(app.route) == "Composition", "L'action mène à la composition")
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until and genre() != "accueil": await process_frame
	check(genre() == "accueil", "Composition : explication même sur un écran de décision")
	var staff: Button = find("GabiAccueilAction0")
	if staff != null: staff.pressed.emit()
	await settle(); await wait_model(); await settle()
	check(str(app.last_command) == "auto_lineup" and app.bridge.last_response_ok, "« Le staff compose pour moi » envoie la composition")
	await aller("Effectif")
	check(genre() != "accueil", "Pas de répétition au second passage")
	# --- Après le 1er match officiel + 14 jours (modèle simulé : un Continuer peut sauter des semaines) ---
	print("PHASE apres-14-jours")
	check(Accueil.actif(app.model, coach.profile.data), "Toujours actif en préparation")
	var simule: Dictionary = app.model.duplicate(true)
	var propre := str(simule.club.id)
	var premier := ""
	for f: Dictionary in simule.calendar:
		if str(f.home.id) == propre or str(f.away.id) == propre:
			f.played = true; premier = str(f.date).substr(0, 10); break
	var plus_tard := Time.get_unix_time_from_datetime_string(premier + "T12:00:00")
	simule.meta.calendarToday = Time.get_datetime_string_from_unix_time(int(plus_tard + 10 * 86400)).substr(0, 10)
	check(Accueil.actif(simule, coach.profile.data), "10 jours après le 1er match : encore actif")
	simule.meta.calendarToday = Time.get_datetime_string_from_unix_time(int(plus_tard + 15 * 86400)).substr(0, 10)
	check(not Accueil.actif(simule, coach.profile.data), "15 jours après le 1er match : terminé")
	check(Accueil.a_dire("Finances", simule, coach.profile.data).is_empty(), "Terminé : plus d'explication d'écran")
	var fin := Accueil.a_dire("Réception", simule, coach.profile.data)
	check(str(fin.get("texte", "")) == Accueil.TEXTE_FIN, "Gabi annonce qu'il se met en retrait")
	Accueil.marquer(coach.profile, Accueil.FIN)
	check(Accueil.a_dire("Réception", simule, coach.profile.data).is_empty(), "Le mot de retrait n'est dit qu'une fois")
	print("PHASE connu")
	# --- « Je connais déjà » ---
	await creer(1, true)
	check(int(app.model.club.get("id", -1)) == 1, "Nouvelle carrière créée (club %s)" % str(app.model.club.get("id", "")))
	print("ACCUEIL ", JSON.stringify(Accueil.etat(coach.profile.data)), " last=", app.last_command, " ", app.last_error)
	check(bool(Accueil.etat(coach.profile.data).get("connu", false)), "« Je connais déjà » enregistré")
	await aller("Effectif")
	check(genre() != "accueil", "« Je connais déjà » : pas d'explication")
	print("PREMIERE_HEURE ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
