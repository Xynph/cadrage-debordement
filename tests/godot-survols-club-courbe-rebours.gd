extends SceneTree
## Survols choisis par Léo (21/11/2026) : écusson → mini-carte club (compacte dans les listes, verticale à l'Avant-match,
## avec le vrai prochain match de chaque club), chiffre → mini-courbe (trésorerie, moral, condition), compte à rebours du
## prochain match dans la barre du haut (→ avant-match, absent du Bureau), défaites en rouge dans le classement.
## Carrière world-champ préparée par le .cjs (semaines jouées : relevés de trésorerie et du groupe).
## CD_SURVOLS_CAPTURES : dossier des captures (mode graphique, 2560 puis 1920).
const ContextualFlow = preload("helpers/contextual_flow.gd")
const Charte = preload("res://ui/charte.gd")
const Bulle = preload("res://ui/bulle_survol.gd")
const Rebours = preload("res://ui/rebours_match.gd")
const CarteClub = preload("res://ui/carte_club_survol.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_SURVOLS_ARTIFACTS")
var captures := OS.get_environment("CD_SURVOLS_CAPTURES")

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
func settle() -> void:
	for i in 12: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	await worker()
	check(app.bridge.last_response_ok, "Worker réel " + id + " : " + app.last_error)
func aller(route: String) -> void:
	app._clear_dialogs()
	app._navigate(route)
	await settle()
	var coach: Variant = app.get("coach")
	if is_instance_valid(coach):
		if coach.has_method("fermer_bulle"): coach.fermer_bulle()
		if coach.get("expanded") == true and coach.has_method("close"): coach.close()
	await settle()

func souris(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	root.push_input(m)

## Contrôles portant une bulle dont la clé commence par `debut`, visibles.
func lies(debut: String) -> Array[Control]:
	var sortie: Array[Control] = []
	for n: Node in app.find_children("*", "Control", true, false):
		var c := n as Control
		if c.has_meta("bulle_survol") and c.is_visible_in_tree() and str(c.get_meta("bulle_survol")).begins_with(debut): sortie.append(c)
	return sortie
func lie(cle: String) -> Control:
	for c in lies(cle):
		if str(c.get_meta("bulle_survol")) == cle: return c
	return null

## Survol : la souris se pose sur l'ancre, la bulle apparaît (sans attendre en mode test).
func survoler(ancre: Control) -> Control:
	souris(ancre.get_global_rect().get_center())
	await process_frame
	var bulle := Bulle.montrer(ancre)
	await settle()
	check(bulle != null and bulle.is_visible_in_tree(), "Bulle affichée au survol de " + str(ancre.get_meta("bulle_survol")))
	if bulle != null: check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(bulle.get_global_rect()), "Bulle entière dans l'écran (" + str(ancre.get_meta("bulle_survol")) + ")")
	return bulle

func capture(nom: String, zone: Rect2 = Rect2()) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	for k in 3: await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var suffixe := "-%d" % image.get_width()
	check(image.save_png(captures.path_join(nom + suffixe + ".png")) == OK, "Capture " + nom)
	if zone.has_area():
		var z := Rect2i(zone.grow(60.0)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		image.get_region(z).save_png(captures.path_join(nom + suffixe + "-zoom.png"))

func texte(n: Node, nom: String) -> String:
	var l := n.find_child(nom, true, false) as Label
	return l.text if l != null else ""

func classement() -> void:
	app.management_ui.erase("competition_page")
	await aller("Classements")
	var nous := CarteClub.cle(app.model.club.id)
	var prochains: Dictionary = app.model.get("clubNext", {})
	check(prochains.size() > 10, "Moteur : prochain match de chaque club publié")
	# Un club qui ne nous joue pas : son prochain match est contre un autre.
	var ancre: Control = null
	for c in lies("club:"):
		var id := str(c.get_meta("bulle_survol")).trim_prefix("club:")
		var p: Variant = prochains.get(id)
		if id != nous and p is Dictionary and CarteClub.cle(p.opponent.get("id", "")) != nous:
			ancre = c
			break
	check(ancre != null, "Écusson du classement lié à la mini-carte (club qui ne nous joue pas)")
	if ancre == null: return
	var bulle := await survoler(ancre)
	if bulle == null: return
	check(bulle.size.x > bulle.size.y, "Carte compacte horizontale dans le classement")
	check(bulle.find_child("CarteClubBandeau", true, false) == null, "Pas de carte verticale dans le classement")
	check(bulle.find_child("CarteClubForme_0", true, false) != null, "Forme en pastilles")
	check(texte(bulle, "CarteClubRang") != "", "Rang du club")
	check(RegEx.create_from_string("^(J-\\d+|AUJ\\.)$").search(texte(bulle, "CarteClubJours")) != null, "Vrai prochain match d'un autre club : " + texte(bulle, "CarteClubJours"))
	# Défaite en rouge sur la carte (lettre D sur fond perte).
	for i in 5:
		var p := bulle.find_child("CarteClubForme_%d" % i, true, false)
		if p != null and p.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == "D"):
			check(_teinte(p).is_equal_approx(Charte.PERTE), "Défaite rouge sur la mini-carte")
	await capture("classement-carte-club", ancre.get_global_rect().merge(bulle.get_global_rect()))
	# Échap range la bulle.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	await settle()
	# Le guetteur suit le survol réel ; sur le bureau caché des captures, la fenêtre n'a pas la souris : vérifié en headless.
	if captures.is_empty(): check(Bulle.actuelle(ancre) == null, "Échap ferme la mini-carte")
	Bulle.cacher(ancre)
	souris(Vector2(4, 4))
	# Tableau du classement : défaites en rouge, toujours avec la lettre D.
	var defaites := 0
	for n: Node in app.body.find_children("SemanticBadge", "", true, false):
		if str(n.get_meta("semantic_text", "")) != "D": continue
		defaites += 1
		check(_teinte(n).is_equal_approx(Charte.PERTE), "Défaite du classement en rouge")
	check(defaites > 0, "Au moins une défaite dans le classement (%d)" % defaites)
	if not captures.is_empty():
		var tableau := app.body.find_child("RecentForm", true, false) as Control
		await capture("classement-defaites-rouges", Rect2(tableau.get_global_rect().position.x - 900, tableau.get_global_rect().position.y - 60, 1100, 520) if tableau != null else Rect2())

func _teinte(n: Node) -> Color:
	var c := n as Control
	for style_name in ["panel", "normal"]:
		var s := c.get_theme_stylebox(style_name) as StyleBoxFlat
		if s != null: return s.bg_color
	if c is ColorRect: return (c as ColorRect).color
	return Color.TRANSPARENT

func calendrier() -> void:
	await aller("Calendrier")
	check(not lies("club:").is_empty(), "Écussons du calendrier liés à la mini-carte")

func avant_match() -> void:
	await aller("Match")
	check(app.route == "Match", "Avant-match ouvert")
	var adverse := CarteClub.cle(Rebours.prochain(app.model).get("adversaire", {}).get("id", ""))
	var ancre := lie("club:" + adverse)
	check(ancre != null, "Écusson adverse de l'Avant-match lié")
	if ancre == null: return
	var bulle := await survoler(ancre)
	if bulle == null: return
	check(bulle.find_child("CarteClubBandeau", true, false) != null and bulle.size.y > bulle.size.x, "Carte verticale à grand écusson à l'Avant-match")
	await capture("avant-match-carte-club", ancre.get_global_rect().merge(bulle.get_global_rect()))
	Bulle.cacher(ancre)
	check(app.find_child("ImmersiveMatchCountdown", true, false) == null, "Pas de compte à rebours sur l'avant-match lui-même")

func courbe(route: String, cle: String, nom: String) -> void:
	var ancre := lie("courbe:" + cle)
	check(ancre != null, "%s : mini-courbe « %s » liée" % [route, cle])
	if ancre == null: return
	var bulle := await survoler(ancre)
	if bulle == null: return
	check(bulle.find_child("MiniCourbeTrace", true, false) != null and texte(bulle, "MiniCourbeValeur") != "", "%s : courbe remplie et valeur (%s)" % [route, cle])
	if not nom.is_empty(): await capture(nom, ancre.get_global_rect().merge(bulle.get_global_rect()))
	Bulle.cacher(ancre)
	souris(Vector2(4, 4))
	await settle()

func courbes() -> void:
	var h: Array = app.model.get("groupHistory", [])
	check(h.size() >= 2, "Moteur : relevé hebdomadaire du moral et de la condition (%d)" % h.size())
	await aller("Club")
	await courbe("Club", "cash", "club-courbe-tresorerie")
	await courbe("Club", "morale", "")
	await aller("Bureau")
	await courbe("Bureau", "morale", "bureau-courbe-moral")
	await courbe("Bureau", "condition", "")
	check(app.find_child("ImmersiveMatchCountdown", true, false) == null, "Bureau : pas de compte à rebours (bloc Prochain match déjà là)")
	# Les jauges du Bureau mènent quelque part : condition → groupe, moral → vestiaire.
	var moral := app.find_child("OfficeGroupMorale", true, false) as Button
	check(moral != null, "Bureau : jauge du moral cliquable")
	if moral != null:
		moral.pressed.emit()
		await settle()
		check(app.route == "Vestiaire", "Moral → Vestiaire (%s)" % app.route)
	app.Immersive.open_training(app)
	await settle()
	await courbe("Entraînement", "condition", "")
	await courbe("Entraînement", "morale", "entrainement-courbe-moral")

func rebours() -> void:
	await aller("Club")
	var b := app.find_child("ImmersiveMatchCountdown", true, false) as Button
	check(b != null, "Compte à rebours dans la barre du haut")
	if b == null: return
	check(RegEx.create_from_string("^(J-\\d+|AUJ\\.)$").search(texte(b, "ReboursJours")) != null, "J-n ou AUJ. : " + texte(b, "ReboursJours"))
	check(b.find_child("ReboursLieu", true, false) != null, "Pastille DOM./EXT.")
	var date := app.find_child("ImmersiveCalendarDate", true, false) as Control
	await capture("barre-compte-a-rebours", b.get_global_rect().merge(date.get_global_rect()) if date != null else b.get_global_rect())
	b.pressed.emit()
	await settle()
	check(app.route == "Match", "Compte à rebours → avant-match (%s)" % app.route)

func ancienne_sauvegarde() -> void:
	# Sauvegarde d'avant le relevé : pas d'historique → pas de bulle, pas d'erreur.
	app.model.erase("groupHistory")
	app.model.erase("clubNext")
	await aller("Bureau")
	check(lie("courbe:morale") == null and lie("courbe:condition") == null, "Sans relevé : pas de mini-courbe du groupe")
	await aller("Classements")
	var ancre: Control = lies("club:")[0] if not lies("club:").is_empty() else null
	if ancre != null:
		var bulle := await survoler(ancre)
		check(bulle != null, "Sans prochain match publié : la mini-carte s'affiche quand même")
		Bulle.cacher(ancre)

func run() -> void:
	var tailles: Array[Vector2i] = [Vector2i(1920, 1080)]
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		tailles = [Vector2i(2560, 1440), Vector2i(1920, 1080)]
		DirAccess.make_dir_recursive_absolute(captures)
	root.size = tailles[0]
	DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	for s: Signal in [root.size_changed, root.focus_entered]:
		if s.is_connected(app._keep_filled_display): s.disconnect(app._keep_filled_display)
	await worker()
	await command("import", {"text": FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	for t in tailles:
		root.mode = Window.MODE_WINDOWED
		root.size = t
		DisplayServer.window_set_size(t)
		for k in 10: await process_frame
		await classement()
		await calendrier()
		await avant_match()
		await courbes()
		await rebours()
	await ancienne_sauvegarde()
	print("SURVOLS checks=%d failures=%d" % [checks, failures.size()])
	for f in failures: print("FAIL ", f)
	app.closing = true
	app.bridge.stop()
	for k in 10: await process_frame
	quit(0 if failures.is_empty() else 1)
