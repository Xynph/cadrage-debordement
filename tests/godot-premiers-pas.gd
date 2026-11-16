extends SceneTree
## Premiers pas guidés par Gabi, sur une vraie carrière Monde (moteur réel) :
## - la carte « Premiers pas » est présente au Bureau dès le début de la pré-saison ;
## - un objectif ne se coche que sur l'action réelle (écran ouvert, stage arrêté, composition acceptée), jamais
##   par un simple passage au Bureau ;
## - la carte disparaît une fois les objectifs faits et le profil s'en souvient (guide.json, hors carrière) ;
## - une nouvelle carrière ne la montre plus ; « Masquer » la retire aussi pour de bon.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const PremiersPas = preload("res://guide/gabi_premiers_pas.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func wait_model() -> void:
	var until := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")

func settle() -> void:
	for i in 6: await process_frame

func bureau() -> void:
	app._navigate("Bureau"); await settle()
	if app.coach.expanded: app.coach.close(); await settle()

func carte() -> Control:
	return app.root_content.find_child("GabiPremiersPas", true, false)

func libelle() -> String:
	var label: Control = app.root_content.find_child("GabiPremiersPas_libelle", true, false)
	return label.text if label is Label else ""

func faits() -> int:
	return PremiersPas.faits(PremiersPas.objectifs(app.model, app.coach.profile.data))

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("new_career", {"club": 0, "mode": "world-champ"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(str(app.model.meta.get("mode")) == "world", "Carrière Monde")
	var coach: Control = app.coach
	var liste: Array = PremiersPas.objectifs(app.model, coach.profile.data)
	check(liste.size() >= 3 and liste.size() <= 4, "Trois à quatre objectifs (%d)" % liste.size())
	check(liste.any(func(o: Dictionary) -> bool: return o.cle == "stage"), "Le stage de préparation fait partie des objectifs")
	await bureau()
	check(carte() != null, "Carte « Premiers pas » présente au début de la carrière")
	check(libelle().begins_with("PREMIERS PAS · 0 SUR"), "Progression à zéro au départ : " + libelle())
	check(faits() == 0, "Aucun objectif coché avant d'agir")
	# Passer au Bureau ne coche rien ; le bouton mène au bon écran.
	await bureau()
	check(faits() == 0, "Rester au Bureau ne coche rien")
	var bouton: Button = app.root_content.find_child("GabiPremiersPasAction", true, false)
	check(bouton != null and not bouton.disabled, "Bouton d'action du premier objectif")
	if bouton != null: bouton.pressed.emit(); await settle()
	check(str(app.route) == "Club", "Le bouton mène au Club (objectifs de la saison)")
	check(faits() == 1, "Club ouvert : premier objectif coché")
	await bureau()
	check(libelle().begins_with("PREMIERS PAS · 1 SUR"), "Au retour, un seul objectif de fait : " + libelle())
	# Stage : coché par la décision réelle du moteur.
	check(app._command("reprise_decide", {"decision": "stage", "option": "staff"}), "Commande de stage envoyée")
	await wait_model(); await settle()
	check(faits() == 2, "Stage arrêté : deuxième objectif coché")
	# Composition : coché par la commande acceptée.
	check(app._command("auto_lineup", {}), "Commande de composition envoyée")
	await wait_model(); await settle()
	check(faits() == 3, "Composition acceptée : troisième objectif coché")
	await bureau()
	check(carte() != null, "Un objectif reste : la carte est encore là")
	app._navigate("Recrutement"); await settle()
	await bureau()
	check(carte() == null, "Tout est fait : la carte a disparu")
	var etat := PremiersPas.etat(coach.profile.data)
	check(etat.fin == "termine", "Profil : premiers pas terminés")
	var sur_disque: Variant = JSON.parse_string(FileAccess.get_file_as_string(coach.profile.directory.path_join("guide.json")))
	check(sur_disque is Dictionary and sur_disque.get("premiers_pas", {}).get("fin") == "termine", "guide.json (hors carrière) garde la fin")
	# Nouvelle carrière : la carte ne revient pas.
	app._command("new_career", {"club": 1, "mode": "world-champ"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	await bureau()
	check(carte() == null, "Nouvelle carrière : pas de carte")
	check(not PremiersPas.visible(app.model, coach.profile.data), "Nouvelle carrière : premiers pas non proposés")
	# Masquer : retire la carte pour de bon (profil réinitialisé pour l'essai).
	coach.profile.data.erase(PremiersPas.CLE)
	await bureau(); await settle()
	check(carte() != null, "Profil sans mémoire : la carte revient")
	var masquer: Button = app.root_content.find_child("GabiPremiersPasMasquer", true, false)
	check(masquer != null, "Bouton « Masquer »")
	if masquer != null: masquer.pressed.emit(); await settle(); await settle()
	check(carte() == null and PremiersPas.etat(coach.profile.data).fin == "masque", "Masquée : plus de carte, état enregistré")
	print("PREMIERS_PAS ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)
