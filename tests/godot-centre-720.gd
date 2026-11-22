extends SceneTree
## Centre de formation en 1440p, 1080p et 1280 × 720 (profil Monde préparé par tests/godot-centre-720.cjs) : les pastilles
## « AU CALENDRIER DES ESPOIRS » tiennent sans points de suspension et le bloc « SAISON JUNIOR » suit
## directement les tuiles du tableau du centre (pas de bande vide). Puis, parcours activés par la vraie commande, les
## pages façon Effectif (choix de Léo du 22/11/2026) à chaque taille : six onglets, tuiles chiffres, textes d'au moins
## 11 px et commandes d'au moins 24 px, page entière dans la fenêtre, panneaux Détection et Rencontres remplis
## jusqu'en bas, parcours individuel en petite fenêtre (Échap la ferme). Captures en affichage graphique.
var app: Control
var sortie := OS.get_environment("CD_CENTRE_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var mesures := {}

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

func tient(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.5

func controler(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(4)
	app._navigate("Centre"); await poser(20)
	var page := app.find_child("ImmersiveCentre", true, false) as Control
	var cle := "%dx%d" % [taille.x, taille.y]
	verifier(page != null and page.is_visible_in_tree(), cle + " : page riche du Centre")
	if page == null: return
	var pastilles := 0
	for noeud: Node in page.find_children("*", "Label", true, false):
		var label := noeud as Label
		if label.text != "AU CALENDRIER DES ESPOIRS": continue
		pastilles += 1
		verifier(tient(label), cle + " : pastille « %s » tronquée (%s px pour %s px)" % [label.text, label.size.x, label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x])
		var carte := label.get_parent().get_parent() as Control
		if carte != null: verifier(carte.get_global_rect().encloses(label.get_parent().get_global_rect()), cle + " : pastille dans sa carte")
	var statut := page.find_child("CentreStatus", true, false) as Control
	verifier(statut != null, cle + " : tableau du centre")
	if statut != null:
		var saison: Label = null
		var bas_tuiles := -1.0
		for noeud: Node in statut.find_children("*", "Label", true, false):
			if (noeud as Label).text == "SAISON JUNIOR": saison = noeud
		for enfant: Node in statut.get_children():
			if enfant is Panel and (enfant as Control).get_global_rect().position.y < statut.get_global_rect().position.y + statut.size.y * .45:
				bas_tuiles = maxf(bas_tuiles, (enfant as Control).get_global_rect().end.y)
		verifier(saison != null, cle + " : titre SAISON JUNIOR")
		if saison != null and bas_tuiles > 0:
			var ecart := saison.get_global_rect().position.y - bas_tuiles
			mesures[cle] = {"pastilles": pastilles, "ecart_saison_px": snappedf(ecart, .1), "hauteur": taille.y}
			# Ligne et titre sous les tuiles : ≈ 75 unités du gabarit ; une bande vide d'une rangée en ajouterait 108.
			verifier(ecart <= 110.0 * C_density(), cle + " : vide de %s px au-dessus de SAISON JUNIOR" % snappedf(ecart, .1))
		# Le bouton suit la note (pas de bande vide au pied du tableau) et le panneau du bas reprend la place.
		var bouton := statut.find_child("CentreOpenAcademy", true, false) as Control
		var bas_texte := -1.0
		for noeud: Node in statut.find_children("*", "Label", true, false):
			var l := noeud as Label
			if bouton != null and not bouton.is_ancestor_of(l): bas_texte = maxf(bas_texte, l.get_global_rect().end.y)
		if bouton != null and saison != null:
			var vide := bouton.get_global_rect().position.y - bas_texte
			if mesures.has(cle): mesures[cle]["vide_bouton_px"] = snappedf(vide, .1)
			verifier(vide <= 90.0 * C_density(), cle + " : vide de %s px au-dessus de « Consulter les Espoirs »" % snappedf(vide, .1))
		var bas := page.find_child("CentreDevelopment", true, false) as Control
		if bas != null: verifier(bas.get_global_rect().position.y - statut.get_global_rect().end.y <= 40.0 * C_density(), cle + " : panneau du bas collé au tableau du centre")
	await poser(10)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join("centre-%s.png" % cle)) == OK, "capture " + cle)

func C_density() -> float:
	return float(load("res://ui/immersive08/components.gd").get("density"))

## Plus petite police et plus petite commande visibles sous `noeud` (pixels de fenêtre).
func plus_petits(noeud: Node) -> Dictionary:
	var texte := [INF, ""]
	var cible := [INF, ""]
	for n: Node in noeud.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty(): continue
		var t := float(l.get_theme_font_size("font_size")) * l.get_global_transform().get_scale().y
		if t < texte[0]: texte = [t, l.text.left(30)]
	for n: Node in noeud.find_children("*", "BaseButton", true, false):
		var b := n as Control
		if not b.is_visible_in_tree(): continue
		var r := b.get_global_rect()
		var cote := minf(r.size.x, r.size.y)
		if cote < cible[0]: cible = [cote, str(b.name)]
	return {"texte": texte, "cible": cible}

## Vide sous le contenu d'un panneau, en part de sa hauteur.
func vide_bas(panneau: Control) -> float:
	var bas := panneau.get_global_rect().position.y
	for n: Node in panneau.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.size.y < panneau.size.y * .9: bas = maxf(bas, c.get_global_rect().end.y)
	return (panneau.get_global_rect().end.y - bas) / maxf(1.0, panneau.size.y)

func onglet(nom: String) -> Control:
	var b := app.find_child("CentreOnglet_" + nom.validate_node_name(), true, false) as Button
	verifier(b != null, "onglet " + nom)
	if b == null: return null
	b.pressed.emit(); await poser(12)
	var v := app.find_child("CentreVisuel", true, false) as Control
	verifier(v != null and str(v.get_meta("onglet", "")) == nom, "onglet %s ouvert" % nom)
	return v

func controler_actif(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(4)
	app._navigate("Centre"); await poser(20)
	var cle := "actif-%dx%d" % [taille.x, taille.y]
	var page := app.find_child("CentreVisuel", true, false) as Control
	verifier(page != null and page.is_visible_in_tree(), cle + " : pages du Centre (parcours actifs)")
	if page == null: return
	verifier(app.find_child("CentreHero", true, false) == null and app.find_child("CentreStatus", true, false) == null, cle + " : ni héros ni colonne de droite")
	for t in ["Cohesion", "Reputation", "Enveloppe", "Places"]: verifier(page.find_child("CentreTuile" + t, true, false) != null, cle + " : tuile " + t)
	var mesure := {}
	for nom: String in ["Centre", "Parcours", "Centres", "Filières", "Passerelle pro", "Générations"]:
		var v := await onglet(nom)
		if v == null: continue
		var fenetre := Rect2(Vector2.ZERO, Vector2(taille))
		verifier(fenetre.grow(1).encloses(v.get_global_rect()), "%s : %s entier dans la fenêtre" % [cle, nom])
		var p := plus_petits(v)
		mesure[nom] = {"texte": snappedf(p.texte[0], .1), "cible": snappedf(p.cible[0], .1)}
		verifier(p.texte[0] >= 11.0, "%s : %s, texte de %s px « %s »" % [cle, nom, snappedf(p.texte[0], .1), p.texte[1]])
		verifier(p.cible[0] >= 24.0, "%s : %s, commande de %s px (%s)" % [cle, nom, snappedf(p.cible[0], .1), p.cible[1]])
		if nom == "Centre":
			for id in ["CentreDetection", "CentreRencontres"]:
				var panneau := v.find_child(id, true, false) as Control
				verifier(panneau != null, cle + " : panneau " + id)
				if panneau != null:
					var vide := vide_bas(panneau)
					mesure[id] = snappedf(vide, .01)
					verifier(vide <= .2, "%s : %s vide sur %d %% de sa hauteur" % [cle, id, roundi(vide * 100)])
		if nom == "Parcours":
			var ligne := v.find_child("CentreVisuelJoueur0", true, false) as Button
			verifier(ligne != null, cle + " : première ligne d'Espoir")
			if ligne != null:
				ligne.pressed.emit(); await poser(12)
				var parcours := app.find_child("CentreVisuelParcours", true, false) as Control
				verifier(parcours != null and parcours.is_visible_in_tree(), cle + " : parcours individuel en petite fenêtre")
				verifier(load("res://ui/petite_fenetre.gd").fermer_derniere(self), cle + " : Échap ferme le parcours individuel")
				await poser(6)
		if DisplayServer.get_name() != "headless" and not sortie.is_empty():
			verifier(root.get_texture().get_image().save_png(sortie.path_join("centre-%s-%s.png" % [cle, nom.validate_node_name()])) == OK, "capture %s %s" % [cle, nom])
	mesures[cle] = mesure

func activer() -> void:
	app._navigate("Centre"); await poser(12)
	await load("res://qa_runner.gd").settle_club_meetings(app, self, verifier)
	var ap: Dictionary = app.model.clubLife.academyPathways
	var contexte: Dictionary = ap.get("context", {}).duplicate()
	contexte.confirmed = true
	app._command("academy_activate", contexte)
	await attendre_moteur()
	verifier(app.model.clubLife.academyPathways.get("active", false), "parcours activés par la vraie commande")

func executer() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	await controler(Vector2i(1280, 720))
	await controler(Vector2i(1920, 1080))
	await controler(Vector2i(2560, 1440))
	await activer()
	for taille in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]: await controler_actif(taille)
	print("CENTRE ", JSON.stringify({"controles": controles, "mesures": mesures, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
