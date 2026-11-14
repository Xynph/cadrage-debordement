extends SceneTree
## Fiche d'un club dans le vrai jeu (profil préparé par tests/godot-fiche-club.cjs) : ouverture depuis
## un classement et depuis la recherche Ctrl K, onglets, XV type, club du manager → écran « Club »,
## aucun texte qui en chevauche un autre. Taille : CD_FICHE_SIZE (1920x1080 ou 1280x720).
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
var app: Control
var sortie := OS.get_environment("CD_FICHE_OUTPUT")
var capturer := OS.get_environment("CD_FICHE_CAPTURE") == "1"
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
	await poser(2)
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(12)

func capture(nom: String) -> void:
	await poser(16)
	if DisplayServer.get_name() == "headless" or not capturer: return
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

func fiche() -> Control:
	return app.find_child("FicheClub", true, false) as Control

## Ouvre la fiche (attend la commande moteur en lecture seule) et renvoie la page.
func attendre_fiche() -> Control:
	await poser(4)
	await attendre_moteur()
	var page := fiche()
	verifier(page != null and app.route == ClubSheet.ROUTE, "fiche du club affichée (route %s)" % app.route)
	verifier(page == null or page.find_child("ClubSheetLoading", true, false) == null, "fiche chargée (pas d'écran d'attente)")
	return page

## Textes visibles (Label, Button) de la page : aucun ne doit en chevaucher un autre ni déborder de l'écran.
func chevauchements(page: Control, onglet: String) -> void:
	var zones: Array = []
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
	for n: Node in page.find_children("*", "", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree(): continue
		var texte := ""
		if c is Label: texte = (c as Label).text
		elif c is Button: texte = (c as Button).text
		if texte.strip_edges().is_empty(): continue
		# Zone réellement occupée par le texte (police et taille du contrôle).
		var police: Font = c.get_theme_font("font")
		var corps: int = c.get_theme_font_size("font_size")
		var largeur := minf(police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x, c.size.x)
		var hauteur := minf(police.get_height(corps), c.size.y) if not (c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF) else c.size.y
		var gauche := 0.0
		var align: int = (c as Label).horizontal_alignment if c is Label else (c as Button).alignment
		if align == HORIZONTAL_ALIGNMENT_RIGHT: gauche = c.size.x - largeur
		elif align == HORIZONTAL_ALIGNMENT_CENTER: gauche = (c.size.x - largeur) / 2.0
		var haut := (c.size.y - hauteur) / 2.0
		var t := c.get_global_transform_with_canvas()
		var zone := Rect2(t * Vector2(gauche, haut), (t.basis_xform(Vector2(largeur, hauteur))))
		# Lignes d'un tableau dans un défilement : seules les lignes visibles comptent.
		var defilement := c.get_parent()
		var masque := Rect2()
		while defilement != null and defilement != page:
			if defilement is ScrollContainer: masque = (defilement as Control).get_global_rect(); break
			defilement = defilement.get_parent()
		if masque.size != Vector2.ZERO and not masque.encloses(zone.grow(-1)): continue
		verifier(ecran.grow(1).encloses(zone), "%s : texte hors écran « %s »" % [onglet, texte.left(40)])
		zones.append([zone.grow(-1.5), texte, c])
	for i in zones.size():
		for k in range(i + 1, zones.size()):
			if zones[i][2].is_ancestor_of(zones[k][2]) or zones[k][2].is_ancestor_of(zones[i][2]): continue
			if (zones[i][0] as Rect2).intersects(zones[k][0]):
				verifier(false, "%s : chevauchement « %s » / « %s »" % [onglet, str(zones[i][1]).left(40), str(zones[k][1]).left(40)])
	mesures[onglet + "_textes"] = zones.size()

func onglet(index: int) -> Control:
	var page := fiche()
	var bouton := page.find_child("ClubSheetTab%d" % index, true, false) as Button if page else null
	verifier(bouton != null, "onglet %d" % index)
	if bouton: bouton.pressed.emit()
	await poser(10)
	return fiche()

func executer() -> void:
	# Garde : une erreur d'exécution dans ce scénario ne doit jamais laisser Godot tourner sans fin.
	create_timer(540.0).timeout.connect(func():
		echecs.append("délai dépassé (540 s)")
		fin())
	var taille := OS.get_environment("CD_FICHE_SIZE").split("x")
	root.size = Vector2i(int(taille[0]), int(taille[1])) if taille.size() == 2 else Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var own := int(app.model.club.id)
	# 1. Depuis le classement : le premier autre club de la liste.
	app._navigate("Classements"); await poser(30)
	var lien: BaseButton = null
	var lien_mien: BaseButton = null
	for n: Node in app.root_content.find_children("*", "BaseButton", true, false):
		if n.get_meta("entity_kind", "") != "club" or not (n as Control).is_visible_in_tree(): continue
		if int(n.get_meta("entity_id", "-1")) == own: lien_mien = n
		elif lien == null: lien = n
	verifier(lien != null, "un nom de club cliquable dans le classement")
	if lien_mien == null:
		lien_mien = await trouver_mien(own)
		# Le changement de page a reconstruit les lignes : reprendre un lien de la page courante.
		lien = null
		for n: Node in app.root_content.find_children("*", "BaseButton", true, false):
			if n.get_meta("entity_kind", "") == "club" and (n as Control).is_visible_in_tree() and int(n.get_meta("entity_id", "-1")) != own: lien = n; break
	verifier(lien_mien != null, "votre club cliquable dans le classement")
	var cible := int(lien.get_meta("entity_id", "-1")) if lien else -1
	if lien: lien.pressed.emit()
	var page := await attendre_fiche()
	if page == null:
		fin()
		return
	verifier(int(app.management_ui.club_sheet.id) == cible, "fiche du club cliqué")
	verifier(page.find_child("ClubSheetCrest", true, false) != null, "écusson")
	var nom := page.find_child("ClubSheetName", true, false) as Label
	verifier(nom != null and not nom.text.is_empty(), "nom du club")
	for i in 4: verifier(page.find_child("ClubSheetTab%d" % i, true, false) != null, "onglet %d présent" % i)
	for action in ["ClubSheetFollow", "ClubSheetCalendar", "ClubSheetCompare", "ClubSheetRecruit"]: verifier(page.find_child(action, true, false) != null, "action " + action)
	verifier(page.find_child("ClubSheetSeason", true, false) != null and page.find_child("ClubSheetHeadToHead", true, false) != null, "vue d'ensemble : saison et confrontations")
	chevauchements(page, "vue")
	await capture("fiche-club-vue-ensemble")
	# Actions : calendrier du club, comparaison, suivi (commande moteur).
	(page.find_child("ClubSheetCalendar", true, false) as Button).pressed.emit(); await poser(6)
	var calendrier := app.get_node_or_null("ClubCalendarDialog") as Window
	verifier(calendrier != null and calendrier.find_children("ClubCalendarRow*", "", true, false).size() >= 20, "calendrier du club : matchs de la saison")
	if calendrier: calendrier.free()
	await poser(4)
	(page.find_child("ClubSheetCompare", true, false) as Button).pressed.emit(); await poser(6)
	var comparaison := app.get_node_or_null("ClubSheetComparison") as Window
	verifier(comparaison != null, "comparaison avec votre club")
	if comparaison: comparaison.free()
	await poser(4)
	(page.find_child("ClubSheetFollow", true, false) as Button).pressed.emit()
	await attendre_moteur()
	page = await attendre_fiche()
	verifier(page != null and (page.find_child("ClubSheetFollow", true, false) as Button).text == "Ne plus suivre", "club suivi (" + str(app.last_error) + ")")
	verifier(app.model.get("clubLife", {}).get("clubSheet", {}).get("followed", []).any(func(v): return int(v) == int(app.management_ui.club_sheet.id)), "club suivi enregistré par le moteur")
	# Effectif : lignes et tri.
	page = await onglet(1)
	var lignes := page.find_children("ClubSheetRow*", "", true, false).size()
	verifier(lignes >= 30, "effectif : %d lignes" % lignes)
	mesures.effectif = lignes
	chevauchements(page, "effectif")
	await capture("fiche-club-effectif")
	var tri := page.find_child("ClubSheetSort_age", true, false) as Button
	verifier(tri != null, "tri par âge")
	if tri: tri.pressed.emit()
	await poser(8)
	verifier(str(app.management_ui.club_sheet.sort) == "age", "tri retenu")
	# XV type : quinze cartes sur le terrain, source annoncée.
	page = await onglet(2)
	var cartes := page.find_children("ClubSheetXV*", "", true, false).filter(func(n: Node): return not str(n.name).begins_with("ClubSheetXVLink") and not str(n.name).begins_with("ClubSheetXVName") and str(n.name) != "ClubSheetXVSource" and str(n.name) != "ClubSheetXVList")
	verifier(cartes.size() == 15, "XV type : quinze cartes (%d)" % cartes.size())
	var source := page.find_child("ClubSheetXVSource", true, false) as Label
	verifier(source != null and (source.text.contains("revient le plus") or source.text.contains("XV le plus fréquent")), "XV type tiré des feuilles de match : « %s »" % (source.text if source else ""))
	mesures.xv = cartes.size()
	chevauchements(page, "xv")
	await capture("fiche-club-xv-type")
	page = await onglet(3)
	verifier(page.find_child("ClubSheetBoard0", true, false) != null, "statistiques : meilleurs marqueurs")
	chevauchements(page, "stats")
	await capture("fiche-club-stats")
	# 2. Votre club dans le classement : écran « Club » (décision de Léo).
	app._navigate("Classements"); await poser(30)
	lien_mien = await trouver_mien(own)
	if lien_mien: lien_mien.pressed.emit()
	await poser(20)
	verifier(app.route == "Club", "votre club ouvre l'écran Club (route %s)" % app.route)
	# 3. Recherche Ctrl K : un autre club, puis le vôtre.
	var autre := ""
	for division: Dictionary in app.model.get("leagues", []):
		for club: Dictionary in division.get("rows", []):
			if int(club.id) != own and int(club.id) != cible and autre.is_empty(): autre = str(club.get("presentation", club).get("name", club.name))
	app.navigation_controller.open_palette(); await poser(6)
	app.navigation_controller._search.text = autre
	app.navigation_controller._refresh_results(autre); await poser(4)
	verifier(app.navigation_controller._results.item_count >= 1 and app.navigation_controller._matches[0].kind == "club", "recherche : club proposé pour « %s »" % autre)
	app.navigation_controller._activate_selected()
	page = await attendre_fiche()
	verifier(page != null and ClubSheet.caption(app) == autre, "recherche : fiche de « %s »" % autre)
	app.navigation_controller.open_palette(); await poser(6)
	var mien := str(app.model.club.get("presentation", app.model.club).get("name", app.model.club.name))
	app.navigation_controller._refresh_results(mien); await poser(4)
	var trouve := -1
	for i in app.navigation_controller._matches.size():
		if app.navigation_controller._matches[i].kind == "club" and str(app.navigation_controller._matches[i].id) == str(own): trouve = i
	verifier(trouve >= 0, "recherche : votre club proposé (« %s » : %s)" % [mien, str(app.navigation_controller._matches.map(func(m): return m.label)).left(300)])
	if trouve >= 0:
		app.navigation_controller._results.select(trouve)
		app.navigation_controller._activate_selected()
	await poser(20)
	verifier(app.route == "Club", "recherche : votre club ouvre l'écran Club (route %s)" % app.route)
	# 4. Retour arrière : la fiche précédente revient.
	app.navigation_controller._travel(-1)
	await poser(4)
	await attendre_moteur()
	verifier(app.route == ClubSheet.ROUTE, "retour arrière vers la fiche (route %s)" % app.route)
	fin()

# Petite fenêtre : le classement est l'ancienne page paginée ; la ligne de votre club peut être sur une autre page.
func trouver_mien(own: int) -> BaseButton:
	for _page in 8:
		for n: Node in app.root_content.find_children("*", "BaseButton", true, false):
			if n.get_meta("entity_kind", "") == "club" and int(n.get_meta("entity_id", "-1")) == own and (n as Control).is_visible_in_tree(): return n
		var pager: Node = app.root_content.find_child("StandingsPagination", true, false)
		if pager == null or pager.get_child_count() < 3: return null
		var suivant := pager.get_child(2) as BaseButton
		if suivant == null or suivant.disabled: return null
		suivant.pressed.emit(); await poser(6)
	return null

func fin() -> void:
	var rapport := {"affichage": DisplayServer.get_name(), "taille": str(root.size), "controles": controles, "failures": echecs, "mesures": mesures}
	print("FICHE_CLUB ", JSON.stringify(rapport))
	quit(0 if echecs.is_empty() else 1)
