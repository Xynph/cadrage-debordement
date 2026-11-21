extends SceneTree
## Carte joueur au survol sur les écrans joueurs et étoiles de capacité au poste (choix de Léo du 21/11/2026) :
## - Effectif, Composition, Recrutement, Entraînement, Vestiaire : la vraie souris passe sur un nom ou un portrait, la
##   carte (même composant que le direct) apparaît après le délai, entière dans l'écran ; la souris part, elle disparaît ;
## - Tactique : étoiles sur les 15 cartes du terrain et dans la liste des candidats (jamais le chiffre de la note) ;
## - Préparation : étoiles sur les joueurs adverses à surveiller.
## Captures 2560 × 1440 et 1920 × 1080 dans CD_ETOILES_FICHE_CAPTURES. godot-etoiles-fiche-partout.cjs prépare la carrière.
const Carte = preload("res://ui/carte_joueur_survol.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var dossier := OS.get_environment("CD_ETOILES_FICHE_CAPTURES")
var taille_txt := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(taille_txt + message)
		printerr("ECHEC : ", taille_txt, message)

func settle(frames: int = 8) -> void:
	for i in frames: await process_frame

func wait_command(limit_ms: int = 60000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle(3)

func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await wait_command()

func until(condition: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	return condition.call()

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dossier.path_join(nom + ".png"))

func souris(position: Vector2) -> void:
	var mouvement := InputEventMouseMotion.new()
	mouvement.position = position
	mouvement.global_position = position
	root.push_input(mouvement)

func named(id: String) -> Control:
	return app.find_child(id, true, false) as Control

## Premier contrôle visible et entier à l'écran qui porte la carte joueur (motif de nom facultatif).
func cible(motif: String = "*") -> Control:
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
	for n: Node in app.root_content.find_children(motif, "Control", true, false):
		var c := n as Control
		if c.has_meta("carte_joueur") and c.is_visible_in_tree() and c.size.x > 4.0 and ecran.encloses(c.get_global_rect()): return c
	return null

## Survol réel (souris du jeu) : rien avant le délai, la carte ensuite, entière ; la souris part, elle disparaît.
func survoler(ecran_nom: String, controle: Control, nom_capture: String) -> void:
	check(controle != null, ecran_nom + " : un nom ou un portrait porte la carte joueur")
	if controle == null:
		print("ETOILES_FICHE %s : %d contrôles liés, route %s" % [ecran_nom, app.find_children("*", "Control", true, false).filter(func(c: Node): return c.has_meta("carte_joueur")).size(), app.route])
		await capture("echec-" + ecran_nom.validate_node_name())
		return
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	souris(Vector2(2, 2))
	await settle(4)
	var debut := Time.get_ticks_msec()
	souris(controle.get_global_rect().get_center())
	var apparue := await until(func(): return Carte.actuelle(app) != null, 3000)
	var delai := Time.get_ticks_msec() - debut
	check(apparue, ecran_nom + " : la carte apparaît au survol")
	check(not apparue or delai >= 300, ecran_nom + " : pas de carte avant le délai (%d ms)" % delai)
	await settle(6)
	var carte := Carte.actuelle(app)
	if carte != null:
		check(Rect2(Vector2.ZERO, Vector2(root.size)).grow(1.0).encloses(carte.get_global_rect()), ecran_nom + " : carte entière dans l'écran")
		check(str(carte.get_meta("player_id", "")) == str(controle.get_meta("carte_joueur")), ecran_nom + " : carte du joueur survolé")
		check(carte.find_child("CarteJoueurEtoilesPoste_*", true, false) != null or carte.find_child("CarteJoueurPolyvalence", true, false) != null, ecran_nom + " : postes de la carte")
		check(carte.find_child("CarteJoueurEtoilesNiveau", true, false) == null, ecran_nom + " : jamais d'étoiles pour le niveau")
		check(app.get_node_or_null("MiniFicheJoueur") == null, ecran_nom + " : plus de mini-fiche par-dessus")
		if not nom_capture.is_empty(): await capture(nom_capture)
	souris(Vector2(2, 2))
	await settle(10)
	check(Carte.actuelle(app) == null, ecran_nom + " : la souris part, la carte disparaît")

func run() -> void:
	root.size = Vector2i(2560, 1440)
	root.content_scale_size = root.size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await command("import", {"text": FileAccess.get_file_as_string(dossier.path_join("monde.json"))})
	for taille: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		root.size = taille
		root.content_scale_size = taille
		taille_txt = "%dx%d · " % [taille.x, taille.y]
		var suffixe := "-%d" % taille.x
		await settle(10)
		await tactique(suffixe)
		await preparation(suffixe)
		# Effectif.
		app._navigate("Effectif")
		await settle(20)
		await survoler("Effectif", cible("SquadOpenPlayer_*"), "effectif" + suffixe)
		# Recrutement.
		app._navigate("Recrutement")
		await settle(30)
		await survoler("Recrutement", cible("MarketEntity_*"), "recrutement" + suffixe)
		# Entraînement (onglet de la Composition).
		app._navigate("Composition")
		await settle(10)
		var onglet := named("TacticsTab4") as Button
		if onglet != null:
			onglet.pressed.emit()
			await settle(20)
		await survoler("Entraînement", cible(), "entrainement" + suffixe)
		# Vestiaire.
		app._navigate("Vestiaire")
		await settle(20)
		await survoler("Vestiaire", cible(), "vestiaire" + suffixe)
	finir()

## Tactique : étoiles sur les cartes du terrain et dans la liste des candidats ; survol d'un nom du terrain.
func tactique(suffixe: String) -> void:
	app._navigate("Composition")
	await settle(20)
	var poses := 0
	for i in 15:
		var person: Dictionary = Selection.occupant(app.model, i)
		if person.is_empty(): continue
		var e := named("TacticsPositionStars%02d" % (i + 1))
		var attendu := Selection.etoiles(app.model, person, i)
		if e != null and e.has_meta("etoiles") and is_equal_approx(float(e.get_meta("etoiles")), attendu): poses += 1
		check(named("TacticsPositionRating%02d" % (i + 1)) == null, "Terrain : plus de chiffre de note au poste (n° %d)" % (i + 1))
		var carte := named("LineupSlot%02d" % (i + 1))
		if e != null and carte != null: check(carte.get_global_rect().grow(1.0).encloses(e.get_global_rect()), "Terrain : étoiles dans la carte n° %d" % (i + 1))
	check(poses >= 14, "Terrain : étoiles de capacité au poste sur les cartes (%d/15)" % poses)
	var candidats: Array = app.root_content.find_children("TacticsCandidateStars", "Control", true, false)
	check(candidats.any(func(c: Node): return c.has_meta("etoiles")), "Candidats : étoiles de capacité au poste")
	check(app.root_content.find_children("TacticsCandidateRating", "Control", true, false).is_empty(), "Candidats : plus de chiffre de note au poste")
	if is_instance_valid(app.coach) and app.coach.has_method("fermer_bulle"): app.coach.fermer_bulle()
	souris(Vector2(2, 2))
	await settle(10)
	await capture("tactique-etoiles" + suffixe)
	await survoler("Composition", named("TacticsName10"), "tactique" + suffixe)

## Préparation : étoiles sur les joueurs adverses à surveiller (jamais le chiffre « au poste »).
func preparation(suffixe: String) -> void:
	app._navigate("Préparation")
	await settle(30)
	var menaces: Array = app.model.get("decisions", {}).get("preparation", {}).get("threats", []) if app.model.get("decisions", {}).get("preparation") is Dictionary else []
	if menaces.is_empty():
		print("ETOILES_FICHE : pas de joueurs adverses à surveiller dans cette carrière")
		return
	var etoiles := named("PreparationThreatStars0")
	check(etoiles != null and etoiles.has_meta("etoiles"), "Préparation : étoiles sur le premier joueur à surveiller")
	if etoiles != null:
		var m: Dictionary = menaces[0]
		check(is_equal_approx(float(etoiles.get_meta("etoiles")), Carte.etoiles_part(float(m.positionNote) / float(m.bestPositionNote))), "Préparation : étoiles = note à sa place / meilleure note")
	var textes: Array = app.root_content.find_children("*", "Label", true, false).map(func(l: Node): return (l as Label).text)
	check(not textes.any(func(t: String): return t.ends_with(" au poste") and t.left(2).is_valid_int()), "Préparation : plus de « NN au poste »")
	await capture("preparation" + suffixe)

func finir() -> void:
	print("ETOILES_FICHE %d controles, %d echec" % [checks, failures.size()])
	for f in failures: print("  - ", f)
	if is_instance_valid(app):
		app.closing = true
		app.bridge.stop()
	for i in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
