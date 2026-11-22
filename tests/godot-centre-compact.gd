extends SceneTree
## Centre de formation en affichage compact (fenêtre sous 1280 × 720, profil Monde préparé par tests/godot-centre-compact.cjs),
## parcours activés par la vraie commande : mêmes six onglets que la page façon Effectif, tuiles chiffres, textes d'au moins
## 11 px, commandes d'au moins 24 px, rien au-delà du bord droit de la fenêtre, tri par en-tête, filtres, liens entre
## onglets, petites fenêtres (parcours individuel, saison junior, jeune repéré) fermées par Échap.
var app: Control
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

func activer() -> void:
	app._navigate("Centre"); await poser(12)
	await load("res://qa_runner.gd").settle_club_meetings(app, self, verifier)
	var ap: Dictionary = app.model.clubLife.academyPathways
	var contexte: Dictionary = ap.get("context", {}).duplicate()
	contexte.confirmed = true
	app._command("academy_activate", contexte)
	await attendre_moteur()
	verifier(app.model.clubLife.academyPathways.get("active", false), "parcours activés par la vraie commande")

## Plus petite police et plus petite commande visibles sous `noeud` (pixels de la page, avant l'échelle de la coque) ; commandes débordant à droite.
func mesurer(noeud: Node, largeur: float) -> Dictionary:
	var texte := [INF, ""]
	var cible := [INF, ""]
	var debord: Array[String] = []
	for n: Node in noeud.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty(): continue
		# Corps de police dessiné par la page (la coque met toute la page à l'échelle sous 1280 × 720 : même règle pour toutes les vues).
		var t := float(l.get_theme_font_size("font_size"))
		if t < texte[0]: texte = [t, l.text.left(30)]
	for n: Node in noeud.find_children("*", "BaseButton", true, false):
		var b := n as Control
		if not b.is_visible_in_tree(): continue
		var r := b.get_global_rect()
		var cote := minf(r.size.x, r.size.y) / maxf(.01, b.get_global_transform().get_scale().y)
		if cote < cible[0]: cible = [cote, str(b.name)]
		if r.end.x > largeur + 1.0 and not _dans_defilement_horizontal(b): debord.append(str(b.name))
	return {"texte": texte, "cible": cible, "debord": debord}

func _dans_defilement_horizontal(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer and p.name == "GenerationsFriseDefile": return true
		p = p.get_parent()
	return false

func onglet(nom: String) -> Control:
	var b := app.find_child("CentreOnglet_" + nom.validate_node_name(), true, false) as Button
	verifier(b != null, "onglet " + nom)
	if b == null: return null
	b.pressed.emit(); await poser(12)
	var v := app.find_child("CarnetAcademyPathways", true, false) as Control
	verifier(v != null and str(v.get_meta("onglet", "")) == nom, "onglet %s ouvert" % nom)
	return v

func fenetre_ouverte(nom: String) -> bool:
	var f := app.find_child(nom, true, false) as Control
	return f != null and f.is_visible_in_tree()

func fermer_fenetre(cle: String, texte: String) -> void:
	verifier(load("res://ui/petite_fenetre.gd").fermer_derniere(self), "%s : Échap ferme %s" % [cle, texte])
	await poser(6)

func onglet_courant() -> String:
	var p := app.find_child("CarnetAcademyPathways", true, false)
	return str(p.get_meta("onglet", "")) if p != null else ""

func controler(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(4)
	app._navigate("Centre"); await poser(20)
	var cle := "%dx%d" % [taille.x, taille.y]
	var page := app.find_child("CarnetAcademyPathways", true, false) as Control
	verifier(page != null and page.is_visible_in_tree() and page.has_meta("onglet"), cle + " : page compacte du Centre (parcours actifs)")
	if page == null: return
	verifier(app.find_child("CentreVisuel", true, false) == null and app.find_child("AcademyTabs", true, false) == null, cle + " : ni la grande page ni l'ancienne vue à onglets")
	for t in ["Cohesion", "Reputation", "Enveloppe", "Places"]: verifier(page.find_child("CentreTuile" + t, true, false) != null, cle + " : tuile " + t)
	var mesure := {}
	for nom: String in ["Centre", "Parcours", "Centres", "Filières", "Passerelle pro", "Générations"]:
		var v := await onglet(nom)
		if v == null: continue
		var m := mesurer(v, float(taille.x))
		mesure[nom] = {"texte": snappedf(m.texte[0], .1), "cible": snappedf(m.cible[0], .1)}
		verifier(m.texte[0] >= 11.0, "%s : %s, texte de %s px « %s »" % [cle, nom, snappedf(m.texte[0], .1), m.texte[1]])
		verifier(m.cible[0] >= 24.0, "%s : %s, commande de %s px (%s)" % [cle, nom, snappedf(m.cible[0], .1), m.cible[1]])
		verifier(m.debord.is_empty(), "%s : %s, commandes au-delà du bord droit : %s" % [cle, nom, str(m.debord.slice(0, 4))])
		verifier(v.get_global_rect().end.x <= taille.x + 1.0, "%s : %s, page dans la largeur de la fenêtre" % [cle, nom])
	mesures[cle] = mesure

## Parcours des clics : liens entre onglets, filtre, tri, petites fenêtres.
func clics(taille: Vector2i) -> void:
	root.size = taille
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(taille)
	await poser(4)
	var cle := "clics-%dx%d" % [taille.x, taille.y]
	app.management_ui.immersive_centre = {"club": app.model.get("club", {}).get("id"), "tab": "Centre", "scroll": {}}
	app._navigate("Centre"); await poser(20)
	# Tuile Réputation → Générations ; pastille Espoirs → Parcours.
	(app.find_child("CentreTuileReputation", true, false) as Button).pressed.emit(); await poser(12)
	verifier(onglet_courant() == "Générations", cle + " : la tuile Réputation mène aux Générations")
	(app.find_child("CentreSousTitre", true, false) as Button).pressed.emit(); await poser(12)
	verifier(onglet_courant() == "Parcours", cle + " : les Espoirs mènent au Parcours")
	# Filtre de trajectoire et tri par en-tête.
	var filtre := app.find_child("CentreFiltreTrajectoire_equilibre", true, false) as Button
	verifier(filtre != null, cle + " : filtre de trajectoire")
	if filtre != null:
		filtre.pressed.emit(); await poser(12)
		var restantes := 0
		for ligne: Node in app.find_children("CentreVisuelJoueur*", "Button", true, false):
			restantes += 1
			verifier(str((ligne.get_meta("element", {}) as Dictionary).get("path", "")) == "equilibre", cle + " : seules les trajectoires « Équilibre » restent")
		verifier(restantes > 0, cle + " : des Espoirs en trajectoire « Équilibre »")
		var tous := app.find_child("CentreFiltreTrajectoire_", true, false) as Button
		if tous != null:
			tous.pressed.emit(); await poser(12)
	var tri := app.find_child("CentreParcoursListeTri_age", true, false) as Button
	verifier(tri != null, cle + " : en-tête ÂGE triable")
	if tri != null:
		tri.pressed.emit(); await poser(12)
		verifier(app.find_children("CentreVisuelJoueur*", "Button", true, false).size() > 1, cle + " : lignes d'Espoirs après tri")
	# Parcours individuel en petite fenêtre : à l'échelle du gabarit, dans la fenêtre, fermée par Échap.
	var ligne0 := app.find_child("CentreVisuelJoueur0", true, false) as Button
	verifier(ligne0 != null, cle + " : première ligne d'Espoir")
	if ligne0 != null:
		ligne0.pressed.emit(); await poser(12)
		verifier(fenetre_ouverte("CentreVisuelParcours"), cle + " : parcours individuel en petite fenêtre")
		var panneau := app.find_child("CentreVisuelParcoursPanneau", true, false) as Control
		if panneau != null:
			var r := panneau.get_global_rect()
			verifier(Rect2(Vector2.ZERO, Vector2(taille)).grow(1).encloses(r), cle + " : la fenêtre du parcours tient dans l'écran (%s)" % str(r))
		await fermer_fenetre(cle, "le parcours individuel")
		verifier(not fenetre_ouverte("CentreVisuelParcours"), cle + " : parcours individuel fermé")
	# Saison junior (pastille de l'en-tête).
	(app.find_child("CentreSaison", true, false) as Button).pressed.emit(); await poser(12)
	verifier(fenetre_ouverte("CentreJuniorsFenetre"), cle + " : saison junior en petite fenêtre")
	await fermer_fenetre(cle, "la saison junior")
	# Filières : jeune repéré en petite fenêtre.
	(app.find_child("CentreOnglet_Filières", true, false) as Button).pressed.emit(); await poser(12)
	var jeunes := app.find_children("FilieresJeune_*", "Button", true, false)
	verifier(not jeunes.is_empty(), cle + " : un jeune repéré dans les filières")
	if not jeunes.is_empty():
		(jeunes[0] as Button).pressed.emit(); await poser(12)
		verifier(fenetre_ouverte("FilieresProspectFenetre"), cle + " : jeune repéré en petite fenêtre")
		await fermer_fenetre(cle, "le jeune repéré")
	# Onglet Centre : les quatre étapes du chemin et les réglages en pastilles, la valeur active choisie.
	(app.find_child("CentreOnglet_Centre", true, false) as Button).pressed.emit(); await poser(12)
	for id in ["CentreReglages", "CentreDetection", "CentreLeCentre", "CentreRencontres", "CentrePremiere"]:
		verifier(app.find_child(id, true, false) != null, cle + " : panneau " + id)
	var actives := 0
	for b: Node in app.find_children("CentreMode_*", "Button", true, false):
		if str((b as Button).accessibility_name).ends_with("· choisi"): actives += 1
	verifier(actives == 1, cle + " : une seule valeur active pour le plan des rencontres (%d)" % actives)

func executer() -> void:
	root.size = Vector2i(1024, 576)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	await activer()
	for taille in [Vector2i(1024, 576), Vector2i(960, 540), Vector2i(1200, 700)]: await controler(taille)
	await clics(Vector2i(1024, 576))
	print("CENTRE_COMPACT ", JSON.stringify({"controles": controles, "mesures": mesures, "failures": echecs}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)
