extends SceneTree
## Bureau (profil préparé par tests/godot-objectif-bureau.cjs) : pastille de l'objectif du conseil en tête
## de la carte du classement, sans chevaucher le titre ni sortir de la carte. Capture 1920×1080 en graphique.
var app: Control
var sortie := OS.get_environment("CD_OBJECTIF_OUTPUT")
var echecs: Array[String] = []
var controles := 0

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

const Office = preload("res://ui/immersive08/office.gd")
const C = preload("res://ui/immersive08/components.gd")

func luminance(c: Color) -> float:
	var canaux := [c.r, c.g, c.b].map(func(v: float): return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * canaux[0] + 0.7152 * canaux[1] + 0.0722 * canaux[2]

func contraste(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Bureau en 1280 × 720 (mise en page en conteneurs) et 1920 × 1080 (gabarit) : aucun bloc n'en recouvre un autre,
## un seul défilement pour la page, chaque ligne du classement lisible en entier une fois amenée à l'écran,
## tuiles « Prochains matchs » toutes à la même hauteur fixe.
func geometrie_bureau(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(6)
	app._navigate("Bureau"); await poser(20)
	if is_instance_valid(app.coach) and app.coach.has_method("close"): app.coach.close()
	await poser(4)
	var blocs: Array[Control] = []
	for id: String in Office.PAGE_BLOCKS:
		var bloc := app.find_child(id, true, false) as Control
		if bloc != null and bloc.is_visible_in_tree(): blocs.append(bloc)
	# Large : profil à suivre et résultats sont sortis du Bureau (cinq blocs au moins) ; étroit : sept.
	verifier(blocs.size() >= 5, "Bureau %s : les blocs principaux sont affichés (%d)" % [taille, blocs.size()])
	for i in blocs.size():
		var a := blocs[i]
		var minimum := a.get_combined_minimum_size().y * a.get_global_transform().get_scale().y
		verifier(a.get_global_rect().size.y + 1.0 >= minimum, "Bureau %s : %s garde sa hauteur entière" % [taille, a.name])
		for j in range(i + 1, blocs.size()):
			var b := blocs[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			verifier(not a.get_global_rect().grow(-1.0).intersects(b.get_global_rect().grow(-1.0)), "Bureau %s : %s ne recouvre pas %s (%s / %s)" % [taille, a.name, b.name, a.get_global_rect(), b.get_global_rect()])
	verifier(app.find_child("OfficeReadingScroll", true, false) == null, "Bureau %s : un seul défilement pour la page" % taille)
	for bloc: Control in blocs:
		var parent := bloc.get_parent()
		while parent != null and parent != app.body_scroll:
			verifier(not parent is ScrollContainer, "Bureau %s : %s défile avec la page, pas dans un cadre à part" % [taille, bloc.name])
			parent = parent.get_parent()
	var classement := app.find_child("OfficeStandings", true, false) as Control
	var zone: Rect2 = app.body_scroll.get_global_rect().grow(1.0)
	if classement != null:
		for ligne: Node in classement.find_children("OfficeStandingRow_*", "Button", true, false):
			var bouton := ligne as Control
			app.body_scroll.ensure_control_visible(bouton)
			await poser(2)
			verifier(zone.encloses(bouton.get_global_rect()), "Bureau %s : ligne du classement %s lisible en entier" % [taille, bouton.name])
	app.body_scroll.scroll_vertical = 0
	var hauteurs: Array = []
	for tuile: Node in app.find_children("OfficeTimelineTile*", "PanelContainer", true, false):
		hauteurs.append(snappedf((tuile as Control).size.y, 0.5))
	if not hauteurs.is_empty():
		verifier(hauteurs.min() == hauteurs.max(), "Bureau %s : tuiles « Prochains matchs » à hauteur fixe %s" % [taille, hauteurs])
		verifier(float(hauteurs.min()) <= C.px(Office.TIMELINE_TILE_JAPAN) + 1.0, "Bureau %s : tuiles « Prochains matchs » sans étirement %s" % [taille, hauteurs])
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(sortie.path_join("bureau-%d.png" % taille.x))

## En-tête Effectif (1920 × 1080) : quatre tuiles chiffre (aptes, indisponibles, fins de contrat, niveau du XV),
## cliquables, gros chiffre sous sa légende et détail à droite du chiffre, lisibles (contraste ≥ 4,5:1 sur leur fond).
func chiffres_effectif() -> void:
	app._navigate("Effectif"); await poser(20)
	var trouves := 0
	for id: String in ["Aptes", "Indisponibles", "Contrats", "Niveau"]:
		var tuile := app.find_child("EffectifTuile" + id, true, false) as Button
		if tuile == null: continue
		trouves += 1
		verifier(tuile.is_visible_in_tree() and not tuile.disabled and tuile.focus_mode == Control.FOCUS_ALL, "Effectif : tuile %s visible et cliquable" % id)
		var fond: Color = (tuile.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
		var valeur := tuile.find_child("EffectifTuileValeur", false, false) as Label
		var legende: Label = null
		for enfant in tuile.get_children():
			if enfant is Label and enfant != valeur and str(enfant.name) != "EffectifTuileDetail": legende = enfant; break
		verifier(valeur != null and legende != null and not legende.text.is_empty(), "Effectif : chiffre %s avec sa légende" % id)
		if valeur == null or legende == null: continue
		verifier(valeur.get_theme_font_size("font_size") >= C.px(36), "Effectif : gros chiffre %s (%s)" % [id, valeur.text])
		verifier(valeur.get_theme_font_size("font_size") > legende.get_theme_font_size("font_size"), "Effectif : chiffre plus grand que sa légende %s" % id)
		var detail := tuile.find_child("EffectifTuileDetail", false, false) as Label
		var textes: Array[Label] = [valeur, legende]
		if detail != null: textes.append(detail)
		for l: Label in textes:
			var ratio := contraste(l.get_theme_color("font_color"), fond)
			verifier(ratio >= 4.5, "Effectif : contraste %.1f:1 de « %s »" % [ratio, l.text])
			verifier(tuile.get_global_rect().grow(1.0).encloses(l.get_global_rect()), "Effectif : « %s » dans sa tuile" % l.text)
		verifier(legende.get_global_rect().position.y < valeur.get_global_rect().position.y, "Effectif : légende au-dessus du chiffre %s" % id)
		if detail != null:
			verifier(valeur.get_global_rect().position.x + C.px(20) <= detail.get_global_rect().position.x, "Effectif : détail à droite du chiffre %s" % id)
	verifier(trouves == 4, "Effectif : quatre chiffres clés en 1920 × 1080 (%d)" % trouves)

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	app._navigate("Bureau"); await poser(20)
	var carte := app.find_child("OfficeDecisions", true, false) as Control
	verifier(carte != null, "carte des priorités")
	var texte := ""
	if carte != null:
		# L'objectif du conseil se lit sous le titre « Tes trois priorités » : « Top 6 · 4e · en avance ».
		var objectif := carte.find_child("OfficeBoardObjective", true, false) as Label
		verifier(objectif != null, "objectif du conseil")
		if objectif != null:
			texte = objectif.text
			verifier(carte.get_global_rect().encloses(objectif.get_global_rect()), "objectif dans la carte")
			var titre := carte.find_child("CardTitle", true, false) as Label
			verifier(titre != null and titre.text.begins_with("TES TROIS") and titre.get_global_rect().end.y <= objectif.get_global_rect().position.y + 1.0, "objectif sous le titre, sans le chevaucher")
	await poser(14)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("bureau-objectif.png")) == OK, "capture")
	for taille: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await geometrie_bureau(taille)
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await poser(6)
	await chiffres_effectif()
	print("OBJECTIF ", JSON.stringify({"controles": controles, "failures": echecs, "texte": texte}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
