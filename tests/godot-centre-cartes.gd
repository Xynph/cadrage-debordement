extends SceneTree
## Centre de formation : chaque carte mène quelque part (décision de Léo du 21/11/2026). Godot réel + worker réel,
## carrière Monde. Détection → Recrutement › Relève ; Mentorat → Staff › Mentorat ; Compétition junior → petite
## fenêtre Crabos / Espoirs (Échap, ✕ et clic à côté la ferment) ; tuile Espoirs → Formation ; places → Effectif.
## Survol et curseur main sur chaque carte. Captures 1920 si CD_CENTRE_CARTES_CAPTURES est posé (fenêtre réelle).
## Imprime une ligne CENTRE_CARTES {checks, failures, destinations}.
const Flow = preload("helpers/contextual_flow.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
var captures := OS.get_environment("CD_CENTRE_CARTES_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await settle()

func capture(nom: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await settle(10)
	DirAccess.make_dir_recursive_absolute(captures)
	root.get_texture().get_image().save_png(captures.path_join(nom + ".png"))

func centre() -> void:
	app._navigate("Centre"); await settle(10)
	check(app.route == "Centre", "Centre affiché")

## Bouton de carte : survol visible (style hover non vide), curseur main, couvre la carte.
func lien(nom: String) -> Button:
	var bouton := app.root_content.find_child(nom, true, false) as Button
	check(bouton != null, "%s présent" % nom)
	if bouton == null: return null
	check(bouton.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "%s : curseur main" % nom)
	# Depuis #1152, le survol vient du retour commun des tuiles (ui/retour_tuile.gd, nœud « RetourTuile » sur le bouton).
	var survol := bouton.get_theme_stylebox("hover") as StyleBoxFlat
	check(bouton.has_node("RetourTuile") or survol != null and survol.bg_color.a > 0.0, "%s : effet de survol" % nom)
	check(bouton.is_visible_in_tree(), "%s visible" % nom)
	return bouton

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(app._command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"}), "Carrière créée")
	await wait_engine()
	await Flow.settle_club_meetings(app, self, check)
	# Quelques semaines jouées pour que les Crabos et les Espoirs aient des résultats à montrer.
	var semaines := int(OS.get_environment("CD_CENTRE_CARTES_SEMAINES")) if OS.get_environment("CD_CENTRE_CARTES_SEMAINES") != "" else 0
	for w in semaines:
		var avant := int(app.model.get("meta", {}).get("week", -1))
		if not await Flow.play_to_result(app, self, check): break
		if not await Flow.finish_match_week(app, self, check, avant): break
	await centre()
	await capture("centre")
	# Détection → Recrutement › Relève
	var b := lien("CentreOfferDetectionLien")
	if b != null:
		b.pressed.emit(); await settle(12)
		check(app.route == "Recrutement" and str(app.management_ui.get("recrutement_page", {}).get("kind", "")) == "releve", "Détection ouvre Recrutement › Relève")
		check(app.root_content.find_child("RecrutementRetour", true, false) != null, "Relève : bouton retour présent")
		destinations.append("Carte Détection -> Recrutement › Relève (%s)" % app.route)
		load("res://ui/immersive08/recruitment_pages.gd").fermer(app); await settle(4)
	# Mentorat → Staff › Mentorat
	await centre()
	b = lien("CentreOfferMentoringLien")
	if b != null:
		b.pressed.emit(); await settle(12)
		check(app.route == "Staff" and str(app.management_ui.get("club_page", {}).get("kind", "")) == "mentorat", "Mentorat ouvre Staff › Mentorat")
		check(app.root_content.find_child("ClubRetour", true, false) != null, "Mentorat : bouton retour présent")
		destinations.append("Carte Mentorat -> Staff › Mentorat (%s)" % app.route)
		load("res://ui/immersive08/club_pages.gd").fermer(app); await settle(4)
	# Compétition junior → petite fenêtre ; Échap la ferme sans ouvrir le menu.
	await centre()
	b = lien("CentreOfferJuniorLien")
	if b != null:
		b.pressed.emit(); await settle(8)
		var fenetre := app.root_content.find_child("CentreJuniorsFenetre", true, false) as Control
		check(fenetre != null and fenetre.is_visible_in_tree(), "Compétition junior ouvre la petite fenêtre")
		check(PetiteFenetre.ouverte(self) == fenetre, "Petite fenêtre inscrite pour Échap")
		for nom in ["CentreJuniorsCrabos", "CentreJuniorsEspoirs", "CentreJuniorsCrabosVictoires", "CentreJuniorsEspoirsRang", "CentreJuniorsFenetreSuivi"]:
			check(fenetre != null and fenetre.find_child(nom, true, false) != null, "Fenêtre junior : %s" % nom)
		var juniors: Dictionary = app.model.get("clubLife", {}).get("youthMatches", {})
		var crabos: Array = juniors.get("results", {}).get("crabos", [])
		if fenetre != null and not crabos.is_empty():
			var valeur := fenetre.find_child("CentreJuniorsCrabosVictoiresValeur", true, false) as Label
			var gagnes := crabos.filter(func(r: Dictionary) -> bool: return int(r.get("for", 0)) > int(r.get("against", 0))).size()
			check(valeur != null and valeur.text == "▲ %d" % gagnes, "Fenêtre junior : victoires des Crabos lues du moteur")
		destinations.append("Carte Compétition junior -> petite fenêtre (%d résultats Crabos)" % crabos.size())
		await capture("centre-competition-junior")
		await key(KEY_ESCAPE)
		check(fenetre == null or not is_instance_valid(fenetre) or fenetre.is_queued_for_deletion(), "Échap ferme la petite fenêtre")
		check(app.route == "Centre", "Échap reste sur le Centre")
		var menu := app.find_child("PauseMenu", true, false) as Control
		check(menu == null or not menu.is_visible_in_tree(), "Échap n'ouvre pas le menu")
		# ✕ et clic à côté
		b = lien("CentreOfferJuniorLien")
		if b != null:
			b.pressed.emit(); await settle(6)
			var croix := app.root_content.find_child("CentreJuniorsFenetreFermer", true, false) as Button
			check(croix != null, "Fenêtre junior : ✕ présente")
			if croix != null: croix.pressed.emit(); await settle(4)
			check(PetiteFenetre.ouverte(self) == null, "✕ ferme la petite fenêtre")
			b.pressed.emit(); await settle(6)
			var voile := app.root_content.find_child("CentreJuniorsFenetreVoile", true, false) as Button
			if voile != null: voile.pressed.emit(); await settle(4)
			check(PetiteFenetre.ouverte(self) == null, "Clic à côté ferme la petite fenêtre")
			# Pastille « Suivi des jeunes »
			b.pressed.emit(); await settle(6)
			var bouton_suivi := app.root_content.find_child("CentreJuniorsFenetreSuiviLien", true, false) as Button
			check(bouton_suivi != null, "Fenêtre junior : pastille Suivi des jeunes cliquable")
			if bouton_suivi != null:
				bouton_suivi.pressed.emit(); await settle(10)
				check(app.route == "Suivi des jeunes", "Pastille Suivi des jeunes ouvre Suivi des jeunes")
				destinations.append("Fenêtre junior · Suivi des jeunes -> %s" % app.route)
	# Tuile Espoirs → Formation ; places → Effectif
	await centre()
	b = lien("CentreTuileEspoirs")
	if b != null:
		b.pressed.emit(); await settle(10)
		check(app.route == "Formation", "Tuile Espoirs ouvre Formation")
		destinations.append("Tuile Espoirs suivis -> %s" % app.route)
	await centre()
	b = lien("CentrePlacesLien")
	if b != null:
		b.pressed.emit(); await settle(10)
		check(app.route == "Effectif", "Places professionnelles ouvre Effectif")
		destinations.append("Places professionnelles -> %s" % app.route)
	print("CENTRE_CARTES ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
