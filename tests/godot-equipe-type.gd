extends SceneTree
## XV type dans le vrai jeu (profil préparé par tests/godot-equipe-type.cjs) : quinze cartes par équipe,
## vedette, entraîneur, liseré du manager, bascule journée / saison, entrées depuis Compétitions et
## l'actualité, écusson du jeu (sans pack) ou logo du pack (CD_EQUIPE_PACK=1). Captures 1920×1080.
const EquipeType = preload("res://ui/equipe_type_view.gd")
const SCENE_LARGEUR := 1920.0
var app: Control
var sortie := OS.get_environment("CD_EQUIPE_OUTPUT")
var avec_pack := OS.get_environment("CD_EQUIPE_PACK") == "1"
var capturer := OS.get_environment("CD_EQUIPE_CAPTURE") == "1"
var echecs: Array[String] = []
var controles := 0
var mesures: Dictionary = {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 6) -> void:
	for i in images: await process_frame

func attendre_moteur() -> void:
	var limite := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func capture(nom: String) -> void:
	await poser(14)
	if DisplayServer.get_name() == "headless" or not capturer: return
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

func ecussons(vue: Node) -> Dictionary:
	var pack := 0
	var jeu := 0
	for t: Node in vue.find_children("*", "TextureRect", true, false):
		if t.tooltip_text == "Blason fourni par le pack": pack += 1
		elif t.tooltip_text == "Blason de Rugby Legacy 27": jeu += 1
	# Écusson original dessiné par le jeu (sigle et couleur du club) quand aucune image n'est fournie.
	for n: Node in vue.find_children("*", "Control", true, false):
		if "initials" in n: jeu += 1
	return {"pack": pack, "jeu": jeu}

func verifier_equipe(vue: Control, mode: String) -> void:
	var cartes := vue.find_children("EquipeTypeCarte*", "", true, false)
	verifier(cartes.size() == 15, "%s : quinze cartes (%d)" % [mode, cartes.size()])
	var noms := {}
	for c: Node in cartes: noms[c.name] = true
	for n in range(1, 16): verifier(noms.has("EquipeTypeCarte%d" % n), "%s : maillot %d" % [mode, n])
	verifier(vue.find_child("EquipeTypeVedette", true, false) != null, mode + " : joueur mis en avant")
	# Les noms de championnats longs (Japan Rugby League One · Division 1) restent dans la colonne de droite.
	for b: Node in vue.find_children("EquipeTypeLigue_*", "", true, false):
		var bouton := b as Button
		verifier(bouton.size.x <= 404.5 and bouton.position.x + bouton.size.x <= SCENE_LARGEUR + 0.5, "%s : bouton de championnat dans la colonne (%s : %d px)" % [mode, bouton.name, bouton.size.x])
	verifier(vue.find_children("Note", "", true, false).size() >= 15, mode + " : pastilles de note")
	var titre: Label = vue.find_child("EquipeTypeTitre", true, false)
	verifier(titre != null and (titre.text.begins_with("XV DE LA") ), mode + " : en-tête « %s »" % (titre.text if titre else ""))
	verifier(vue.find_child("EquipeTypeFond", true, false) != null, mode + " : fond opaque de la carte à partager")
	var agrandies := 0
	for c: Control in cartes:
		var nom: Label = c.find_child("Nom", true, false)
		verifier(nom != null and not nom.text.is_empty(), "nom du joueur sur la carte " + str(c.name))
		verifier(c.find_child("Portrait", true, false) != null, "portrait sur la carte " + str(c.name))
		verifier(c.get_node_or_null("Ecusson") != null, "écusson sur la carte " + str(c.name))
		verifier(c.get_node_or_null("Note") != null, "pastille de note sur la carte " + str(c.name))
		if c.scale.x > 1.01: agrandies += 1
		# Rectangle visible (la carte de la vedette est agrandie autour de son centre).
		var zone := Rect2(c.position + c.size * 0.5 - c.size * c.scale * 0.5, c.size * c.scale)
		for autre: Control in cartes:
			var z2 := Rect2(autre.position + autre.size * 0.5 - autre.size * autre.scale * 0.5, autre.size * autre.scale)
			if autre != c and zone.intersects(z2): verifier(false, "cartes qui se chevauchent : %s / %s" % [c.name, autre.name])
	verifier(agrandies == 1, "%s : une seule carte agrandie (vedette) : %d" % [mode, agrandies])
	var ec := ecussons(vue)
	if avec_pack:
		verifier(int(ec.pack) >= 15, "%s : logo du pack sur les cartes (%s)" % [mode, str(ec)])
	else:
		verifier(int(ec.pack) == 0, "%s : aucun logo de pack sans pack (%s)" % [mode, str(ec)])
		verifier(int(ec.jeu) >= 15, "écussons originaux du jeu (%s)" % str(ec))
	mesures[mode] = {"cartes": cartes.size(), "ecussons": ec}

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var xv: Dictionary = app.model.get("clubLife", {}).get("matchNotes", {}).get("equipeType", {})
	verifier(xv.get("ligues", []).size() >= 2, "deux championnats : %d" % xv.get("ligues", []).size())
	verifier(EquipeType.disponible(app.model), "équipe-type disponible")
	# Entrée depuis Compétitions.
	app._navigate("Classements"); await poser(30)
	var bouton := app.find_child("CompetitionEquipeType", true, false) as Button
	verifier(bouton != null, "bouton XV type de Compétitions")
	if bouton: bouton.pressed.emit()
	await poser(20)
	var vue := app.get_node_or_null("EquipeTypeVue") as Control
	verifier(vue != null, "vue ouverte depuis Compétitions")
	if vue == null:
		print("EQUIPE_TYPE ", JSON.stringify({"affichage": DisplayServer.get_name(), "controles": controles, "failures": echecs, "mesures": mesures}))
		quit(1)
		return
	await verifier_et_capturer(vue, "journee", "equipe-type-journee")
	# Bascule saison, autre championnat.
	var saison := vue.find_child("EquipeTypeModeSaison", true, false) as Button
	verifier(saison != null, "bouton XV de la saison")
	if saison: saison.pressed.emit()
	await poser(20)
	vue = app.get_node_or_null("EquipeTypeVue") as Control
	await verifier_et_capturer(vue, "saison", "equipe-type-saison")
	var autre: Button = null
	for b: Node in vue.find_children("EquipeTypeLigue_*", "", true, false):
		if not (b as Button).has_theme_color_override("font_color") or (b as Button).get_theme_color("font_color").v > 0.5: pass
	vue.queue_free(); await poser(6)
	# Entrée depuis l'actualité (vignette du fil du club).
	app._navigate("Club"); await poser(30)
	var vignette := app.find_child("EquipeTypeVignette", true, false) as Button
	verifier(vignette != null, "vignette cliquable dans l'actualité du club")
	if vignette:
		vignette.pressed.emit(); await poser(20)
		verifier(app.get_node_or_null("EquipeTypeVue") != null, "vue ouverte depuis l'actualité")
		if app.get_node_or_null("EquipeTypeVue"): app.get_node("EquipeTypeVue").queue_free()
	await poser(6)
	# Fiche d'un joueur du XV de la saison : repère de carrière.
	var rapport := {"affichage": DisplayServer.get_name(), "controles": controles, "failures": echecs, "mesures": mesures}
	print("EQUIPE_TYPE ", JSON.stringify(rapport))
	quit(0 if echecs.is_empty() else 1)

func verifier_et_capturer(vue: Control, mode: String, fichier: String) -> void:
	verifier_equipe(vue, mode)
	await capture(fichier)
