extends SceneTree
## Fenêtre blessure (option A choisie par Léo le 22/11/2026), Godot réel + worker réel, carrière Monde :
## - la pastille Blessé de l'Effectif ouvre la petite fenêtre (silhouette face / dos, halo sur la zone, retour, jauges) ;
## - fragilité, risque de blessure et risque de rechute viennent du moteur (aucune jauge sans donnée) ;
## - chaque jauge est cliquable et mène à son écran (Semaine ou fiche du joueur) ; Échap et ✕ ferment.
## Imprime une ligne FENETRE_BLESSURE {checks, failures}.
const Rooms = preload("res://qa_runner.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_blessure.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func fenetre() -> Node:
	return app.find_child(Fenetre.NOM, true, false)

## Un blessé dans le modèle projeté (lecture de l'écran seulement : la fenêtre ne change aucun état du jeu).
func blesser(id: String) -> void:
	for p: Dictionary in app.model.squad:
		if str(p.id) == id:
			p.injury = 3; p.injuryType = "ischios"; p.injuryCause = "match"; p.rechute = 14; p.status = "Blessé"

## Effectif reconstruit depuis le modèle (passage par le Bureau), avec le blessé posé.
func ouvrir_effectif(id: String) -> void:
	app._navigate("Bureau")
	await settle(6)
	blesser(id)
	app.selected_player = ""
	app._navigate("Effectif")
	await settle(12)

func pastille(id: String) -> BaseButton:
	for b: Node in get_nodes_in_group(&"ouvre_blessure"):
		if b is BaseButton and b.is_visible_in_tree() and b.name.ends_with(id.validate_node_name()): return b
	return null

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	check(app._command("new_career", {"mode": "world-champ", "club": 102}), "Nouvelle carrière Monde")
	await wait_engine()
	if not await Rooms.settle_club_meetings(app, self, check): return finir()
	for p: Dictionary in app.model.squad:
		check(p.get("fragilite") is float or p.get("fragilite") is int, "Fragilité du moteur : " + str(p.name))
		check(p.get("risqueBlessure") is float or p.get("risqueBlessure") is int, "Risque au prochain match du moteur : " + str(p.name))
	var id := str(app.model.squad[0].id)
	await ouvrir_effectif(id)
	var b := pastille(id)
	check(b != null, "Pastille Blessé cliquable dans l'Effectif")
	if b == null: return finir()
	b.pressed.emit()
	await settle()
	var f := fenetre()
	check(f != null and PetiteFenetre.ouverte(self) == f, "La pastille ouvre la petite fenêtre blessure")
	if f == null: return finir()
	var dos := f.find_child("FenetreBlessureSilhouetteB", true, false)
	var face := f.find_child("FenetreBlessureSilhouetteF", true, false)
	check(face != null and dos != null, "Silhouettes face et dos")
	check(dos != null and dos.point.x >= 0 and face.point.x < 0, "Ischios : halo sur le dos seulement")
	var attendues := ["forme", "energie", "match", "entrainement", "fragilite", "risque", "rechute"]
	for j: String in attendues:
		var ligne := f.find_child("FenetreBlessureJauge_" + j, true, false)
		check(ligne != null, "Jauge " + j)
		check(f.find_child("FenetreBlessureJaugeClic_" + j, true, false) is BaseButton, "Jauge cliquable : " + j)
	check(f.find_child("FenetreBlessureSansDonnee", true, false) == null, "Aucune jauge sans donnée")
	# Échap ferme la fenêtre avant tout autre usage.
	check(PetiteFenetre.fermer_derniere(self) and true, "Échap ferme la fenêtre")
	await settle()
	check(fenetre() == null or fenetre().is_queued_for_deletion(), "Fenêtre fermée")
	# Chaque jauge mène à son écran.
	for j: String in attendues:
		await ouvrir_effectif(id)
		b = pastille(id)
		if b == null: check(false, "Pastille retrouvée pour " + j); continue
		b.pressed.emit()
		await settle()
		var clic := app.find_child("FenetreBlessureJaugeClic_" + j, true, false) as BaseButton
		if clic == null: check(false, "Clic " + j); continue
		clic.pressed.emit()
		await settle(12)
		check(fenetre() == null or fenetre().is_queued_for_deletion(), "Clic " + j + " : fenêtre refermée")
		if j in ["forme", "energie", "entrainement"]: check(app.route != "Effectif", "Clic " + j + " : la Semaine (" + str(app.route) + ")")
		else: check(str(app.selected_player) == id, "Clic " + j + " : fiche du joueur")
	finir()

func finir() -> void:
	print("FENETRE_BLESSURE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
