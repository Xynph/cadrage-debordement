extends SceneTree
## Club › Organigramme (choix B de Léo du 24/11/2026 : un anneau par service autour du centre), Godot réel + worker réel,
## carrière Monde :
## - la carte montre le président et « Toi » au centre et un anneau par service, sans fenêtre au repos ;
## - survol d'un membre : il grossit, les autres s'estompent ; survol d'un service à droite : ses membres ressortent ;
## - clic sur CHAQUE membre : petite fenêtre visuelle, refermée tour à tour par Échap, ✕ et clic à côté ;
## - aucun chiffre exact du moteur (niveau du staff) dans les fenêtres ; clic sur « Toi » : Carrière.
## Imprime une ligne CLUB_ORGANIGRAMME {checks, failures}. Captures (rendu graphique) : CD_ORGANIGRAMME_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const StaffServices = preload("res://ui/immersive08/staff_services.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_ORGANIGRAMME_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	return app.bridge.last_response_ok

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func windows() -> Array:
	return app.find_children("*", "Window", true, false).filter(func(w: Node) -> bool: return (w as Window).visible)

func fenetre() -> Node:
	var f := app.find_child("OrgaFenetre", true, false)
	return f if f != null and is_instance_valid(f) and not f.is_queued_for_deletion() else null

func taille(l: int, h: int) -> void:
	root.size = Vector2i(l, h)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await settle(10)

func ouvrir_organigramme() -> void:
	app.management_ui[app.Immersive.ClubCanvas.KEY] = "organigramme"
	app._navigate("Club")
	await settle(12)

func noeuds() -> Array:
	var carte := node("OrgaCarte")
	return carte.get("noeuds") if carte != null else []

func run() -> void:
	await taille(1920, 1080)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	await ouvrir_organigramme()
	await carte()
	await survol()
	await clics()
	await toi()
	if not capture_dir.is_empty(): await captures()
	print("CLUB_ORGANIGRAMME ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func carte() -> void:
	check(node("ClubTab_organigramme") != null and node("ClubTab_organigramme").button_pressed, "Onglet Organigramme choisi")
	check(node("OrgaCarte") != null, "Carte de l'organigramme")
	for id in ["OrgaPresident", "OrgaManager", "OrgaMedecin", "OrgaServicesTitre"]: check(node(id) != null, "Organigramme : " + id)
	for id in ["direction", "coaching", "fitness", "medical", "club"]: check(node("OrgaService_" + id) is Button, "Service à droite : " + id)
	check(noeuds().size() >= 8, "Au moins huit membres sur la carte (%d)" % noeuds().size())
	# Option B : un anneau (bulle pleine + contour) par service présent, aucun anneau concentrique de l'option A.
	var guides: Array = node("OrgaCarte").get("guides")
	var pleins := guides.filter(func(g: Array) -> bool: return bool(g[4])).size()
	check(pleins >= 4 and pleins * 2 == guides.size(), "Un anneau par service (%d bulles, %d guides)" % [pleins, guides.size()])
	check(windows().is_empty() and fenetre() == null, "Au repos : aucune fenêtre")
	# Les nœuds tiennent dans la carte et ne se recouvrent pas.
	var rects: Array = []
	for n: Control in noeuds(): rects.append(n.get_global_rect())
	var chevauche := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-2).intersects((rects[j] as Rect2).grow(-2)): chevauche += 1
	check(chevauche == 0, "Aucun membre n'en recouvre un autre (%d)" % chevauche)

func survol() -> void:
	var tous := noeuds()
	var cible: Control = node("OrgaMedecin")
	if cible == null: return
	cible.mouse_entered.emit()
	await settle(2)
	check(cible.scale.x > 1.05, "Survol : le membre grossit (%.2f)" % cible.scale.x)
	var estompes := tous.filter(func(n: Control) -> bool: return n != cible and n.modulate.a < .5).size()
	check(estompes == tous.size() - 1, "Survol : les autres s'estompent (%d / %d)" % [estompes, tous.size() - 1])
	cible.mouse_exited.emit()
	await settle(2)
	check(tous.all(func(n: Control) -> bool: return n.modulate.a > .99 and n.scale.x < 1.01), "Fin du survol : tout revient")
	var ligne := node("OrgaService_medical")
	ligne.mouse_entered.emit()
	await settle(2)
	var vifs := tous.filter(func(n: Control) -> bool: return n.modulate.a > .99)
	check(not vifs.is_empty() and vifs.all(func(n: Control) -> bool: return str(n.get("service")) == "medical"), "Survol du service Médical : seuls ses membres ressortent (%d)" % vifs.size())
	check(tous.filter(func(n: Control) -> bool: return str(n.get("service")) == "medical").all(func(n: Control) -> bool: return n.modulate.a > .99), "Survol du service : tous ses membres ressortent")
	ligne.mouse_exited.emit()
	await settle(2)

func echap() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	var relache := ev.duplicate()
	relache.pressed = false
	root.push_input(relache)

## Textes de la fenêtre ouverte : aucun niveau exact du staff (nombre du moteur) ni pourcentage.
func textes_fenetre(f: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for l: Node in f.find_children("*", "Label", true, false): out.append((l as Label).text)
	for b: Node in f.find_children("*", "Button", true, false): out.append((b as Button).text)
	return out

func niveau_du(nom: String) -> Variant:
	for p: Variant in StaffServices.membres(app):
		if p is Dictionary and str(p.get("name", "")).to_upper() == nom: return p.get("level")
	return null

func clics() -> void:
	var manieres := ["Échap", "✕", "clic à côté"]
	var k := 0
	for n: Control in noeuds():
		if n.name == "OrgaManager": continue
		(n as Button).pressed.emit()
		await settle(4)
		var f := fenetre()
		check(f != null, "Clic sur %s : petite fenêtre" % n.name)
		check(windows().is_empty(), "Clic sur %s : aucune fenêtre système" % n.name)
		if f == null: continue
		check(f.find_child("OrgaFenetrePortrait", true, false) != null, "%s : portrait dans la fenêtre" % n.name)
		var titre := f.find_child("OrgaFenetreTitre", true, false) as Label
		var niveau: Variant = niveau_du(titre.text if titre != null else "")
		var textes := textes_fenetre(f)
		var fautifs: PackedStringArray = []
		for t in textes:
			if "%" in t: fautifs.append(t)
			if niveau != null and String.num_int64(roundi(float(niveau))) in t.split(" "): fautifs.append(t)
		check(fautifs.is_empty(), "%s : aucun chiffre exact du moteur (%s)" % [n.name, ", ".join(fautifs)])
		var maniere: String = manieres[k % 3]
		k += 1
		match maniere:
			"Échap": echap()
			"✕": (f.find_child("OrgaFenetreFermer", true, false) as Button).pressed.emit()
			_: (f.find_child("OrgaFenetreVoile", true, false) as Button).pressed.emit()
		await settle(4)
		check(fenetre() == null and PetiteFenetre.ouverte(self) == null, "%s : %s ferme la fenêtre" % [n.name, maniere])
	check(k >= 8, "Chaque membre cliqué (%d)" % k)

func toi() -> void:
	var manager := node("OrgaManager") as Button
	check(manager != null, "Nœud « Toi »")
	if manager == null: return
	manager.pressed.emit()
	await settle(10)
	check(app.route == "Carrière", "Clic sur « Toi » : Carrière (%s)" % app.route)
	check(fenetre() == null, "« Toi » : aucune petite fenêtre")

func captures() -> void:
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await taille(t.x, t.y)
		await ouvrir_organigramme()
		shot("final-%d" % t.x)
		var m := node("OrgaMedecin")
		m.mouse_entered.emit()
		await settle(3)
		shot("final-%d-survol" % t.x)
		m.mouse_exited.emit()
		node("OrgaService_coaching").mouse_entered.emit()
		await settle(3)
		shot("final-%d-survol-service" % t.x)
		node("OrgaService_coaching").mouse_exited.emit()
		(m as Button).pressed.emit()
		await settle(4)
		shot("final-%d-fenetre" % t.x)
		echap()
		await settle(3)
