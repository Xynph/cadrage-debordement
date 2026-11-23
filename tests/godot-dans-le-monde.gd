extends SceneTree
## Page « Dans le monde » (Compétitions, idée FM27 n° 30, choix A de Léo du 23/11/2026) dans le vrai écran
## (competition_canvas.gd + dans_le_monde.gd) :
## - banque des actus : chacun des 16 thèmes trouve ses 6 images (art/actus, 1600 × 900) ;
## - page construite à 2560 × 1440 et 1920 × 1080 sans image manquante, jamais deux fois la même image, chaque article signé
##   (journaliste + média du jeu), la carte « Dernière minute » sur le gros transfert entre clubs adverses ;
## - images : autre variante le lendemain, même page pour le même jour (déterministe) ;
## - clics : affiche → rencontre, vignette → classement, article → sa petite fenêtre, dont chaque tuile mène au club, à la
##   rencontre ou au classement (fenêtre refermée), Échap/✕ communs ; aucun bouton de confirmation.
## Monde synthétique (aucun résultat réel). Avec CD_DANS_LE_MONDE_SEMAINE=<dossier de jour-N.json> (modèles du vrai moteur),
## compte en plus les articles par thème sur la semaine et construit la page de chaque jour.
const C = preload("res://ui/immersive08/components.gd")
const Competition = preload("res://ui/immersive08/competition_canvas.gd")
const A = preload("res://ui/immersive08/dans_le_monde_actus.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

class NavStub extends Node:
	var ouverts: Array = []
	func open_entity(target: Dictionary, _source: Window = null) -> bool:
		ouverts.append(target)
		return true

class ReadingApp extends Control:
	var model: Dictionary = {}
	var accent := Color("cc4d57")
	var management_ui: Dictionary = {}
	var table_division := "elite"
	var catalogue: Array = []
	var route := "Classements"
	var navigation_controller: Node
	var navigations: Array = []
	func _navigate(destination: String, _remember: bool = true, _keep: bool = false) -> void:
		route = destination
		navigations.append(destination)
	func _render(_keep: bool = true) -> void: pass
	func _command(_id: String, _payload: Dictionary = {}) -> void: pass

var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		if failures.size() <= 30: printerr("FAIL: ", description)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	banque()
	var model := monde("2026-10-04")
	rotation(model)
	for taille: Vector2 in [Vector2(2560, 1440), Vector2(1920, 1080)]:
		C.configure(taille.y, taille.x)
		await ecran(model, int(taille.x), true)
	C.configure(1440, 2560)
	var dossier := OS.get_environment("CD_DANS_LE_MONDE_SEMAINE")
	if not dossier.is_empty(): await semaine(dossier)
	print("DANS LE MONDE : %d contrôles ; %d échec" % [checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

## Chaque thème : ses 6 images, chargées, au format 1600 × 900.
func banque() -> void:
	for th: String in A.THEMES:
		for n in range(1, 7):
			var id := "actu-%s-%d" % [th, n]
			check(FileAccess.file_exists(A.chemin(id)), "fichier présent dans le dépôt : " + A.chemin(id))
			var tex := A.texture(id)
			check(tex != null, "image chargée : " + id)
			if tex != null: check(tex.get_size() == Vector2(1600, 900), "format 1600 × 900 : %s (%s)" % [id, tex.get_size()])
	check(A.THEMES.size() == 16, "16 thèmes")

## Variante tournante : jamais la même image d'un jour à l'autre pour le premier article d'un thème, ni pour le second.
func rotation(model: Dictionary) -> void:
	for th: String in A.THEMES:
		for d in range(0, 60):
			for r in 2:
				var hier := posmod(3 * (d - 1) + (d - 1) / 2 + A.graine(th) % 6 + r, 6)
				var auj := posmod(3 * d + d / 2 + A.graine(th) % 6 + r, 6)
				if hier == auj:
					check(false, "même image deux jours de suite : %s jour %d rang %d" % [th, d, r])
	var p1 := A.page(model)
	var p2 := A.page(model)
	check(JSON.stringify(p1.tous.map(func(a): return a.image)) == JSON.stringify(p2.tous.map(func(a): return a.image)), "même jour, même page")
	var lendemain := model.duplicate(true)
	lendemain.meta.calendarToday = "2026-10-05"
	var p3 := A.page(lendemain)
	check(str(p1.une.image) != str(p3.une.image), "la une change d'image le lendemain (%s)" % p1.une.image)

func ecran(model: Dictionary, largeur: int, cliquer: bool) -> void:
	var app := ReadingApp.new()
	app.model = model.duplicate(true)
	app.management_ui = {"competition": {"tab": "monde", "club_league": str(model.meta.leagueId)}}
	app.table_division = str(model.meta.leagueId)
	var nav := NavStub.new()
	app.navigation_controller = nav
	app.add_child(nav)
	root.add_child(app)
	var canvas := Control.new()
	app.add_child(canvas)
	Competition.build(app, canvas)
	await process_frame
	var page: Control = canvas.get_child(0)
	var journal: Dictionary = page.get_meta("dans_le_monde", {})
	check(not journal.is_empty(), "%d : page du journal construite" % largeur)
	check(page.find_child("CompetitionMonde", true, false) != null, "%d : onglet « Dans le monde »" % largeur)
	for nom in ["MondeUne", "MondeCarte0", "MondeCarte1", "MondeActu0", "MondeAffiche0", "MondeLigue0"]:
		check(page.find_child(nom, true, false) != null, "%d : %s présent" % [largeur, nom])
	# Images : toutes chargées, aucune deux fois.
	var vues := {}
	for n: Node in page.find_children("Image_*", "", true, false):
		var id := str(n.get_meta("actu_image", ""))
		check(bool(n.get_meta("actu_image_ok", false)), "%d : image chargée %s" % [largeur, id])
		check(not vues.has(id), "%d : image %s une seule fois sur la page" % [largeur, id])
		vues[id] = true
	check(vues.size() >= 6, "%d : au moins 6 images d'actus (%d)" % [largeur, vues.size()])
	# Signature : chaque article a un journaliste et un média des médias du jeu.
	for a: Dictionary in journal.tous:
		check(not (a.journaliste as Dictionary).is_empty() and str(a.journaliste.get("name", "")) != "" and str(a.journaliste.get("outlet", "")) != "", "%d : article signé (%s)" % [largeur, a.titre])
		check(str(a.image).begins_with("actu-" + str(a.theme) + "-"), "%d : image du thème (%s → %s)" % [largeur, a.theme, a.image])
	# Rien ne déborde des cartes (le score de la une sortait sur la colonne de droite).
	for nom in ["MondeUne", "MondeCarte0", "MondeCarte1", "MondeDerniereMinute"]:
		var carte := page.find_child(nom, true, false) as Control
		if carte == null: continue
		var bord := carte.get_global_rect()
		for l: Node in carte.find_children("*", "Label", true, false):
			var r := (l as Control).get_global_rect()
			check(r.position.x >= bord.position.x - 2 and r.end.x <= bord.end.x + 2, "%d : « %s » tient dans %s" % [largeur, (l as Label).text, nom])
	var une := page.find_child("MondeUne", true, false)
	if une != null:
		check(une.find_child("Signature", true, false) != null and une.find_child("Media", true, false) != null, "%d : la une affiche journaliste et média" % largeur)
	if not (model.get("monde", {}).get("transferts", []) as Array).is_empty():
		var dm := page.find_child("MondeDerniereMinute", true, false)
		check(dm != null, "%d : carte « Dernière minute »" % largeur)
		check(str(journal.derniere.get("theme", "")) == "transfert", "%d : dernière minute = transfert" % largeur)
	check(page.find_children("*Confirmer*", "", true, false).is_empty() and page.find_children("*Valider*", "", true, false).is_empty(), "%d : aucun bouton de confirmation" % largeur)
	if cliquer: await clics(app, page, nav, largeur)
	app.queue_free()
	await process_frame

func bouton(page: Node, nom: String) -> BaseButton:
	return page.find_child(nom, true, false) as BaseButton

func clics(app: ReadingApp, page: Control, nav: NavStub, largeur: int) -> void:
	var b := bouton(page, "MondeAfficheLien0")
	check(b != null, "%d : affiche cliquable" % largeur)
	if b != null:
		b.pressed.emit()
		check(str(app.management_ui.get("competition_page", {}).get("kind", "")) == "fixture", "%d : affiche → la rencontre" % largeur)
	app.management_ui.erase("competition_page")
	b = bouton(page, "MondeLigueLien1")
	if b != null:
		b.pressed.emit()
		var deuxieme: String = A.ligues(app.model)[1].id
		check(app.route == "Classements" and app.table_division == deuxieme, "%d : vignette → classement de %s (%s)" % [largeur, deuxieme, app.table_division])
	# Chaque article ouvre sa petite fenêtre ; chaque tuile de la fenêtre mène quelque part et la referme.
	var articles := ["MondeUneLien", "MondeCarteLien0", "MondeCarteLien1", "MondeDerniereMinuteLien", "MondeActuLien0"]
	for nom in articles:
		b = bouton(page, nom)
		if b == null:
			check(nom == "MondeDerniereMinuteLien" and (app.model.get("monde", {}).get("transferts", []) as Array).is_empty(), "%d : %s cliquable" % [largeur, nom])
			continue
		b.pressed.emit()
		await process_frame
		var fen := page.find_child("MondeArticle", true, false)
		check(fen != null, "%d : %s → petite fenêtre de l'article" % [largeur, nom])
		if fen == null: continue
		var img := fen.find_children("Image_*", "", true, false)
		check(not img.is_empty() and bool(img[0].get_meta("actu_image_ok", false)), "%d : image de l'article dans la fenêtre" % largeur)
		check(fen.find_child("Signature", true, false) != null and fen.find_child("Media", true, false) != null, "%d : signature dans la fenêtre" % largeur)
		var tuiles := fen.find_children("MondeArticleLien*", "", true, false)
		check(tuiles.size() >= 2, "%d : %s : au moins deux tuiles (%d)" % [largeur, nom, tuiles.size()])
		# Échap ferme la fenêtre (mécanisme commun).
		check(PetiteFenetre.fermer_derniere(self) , "%d : Échap ferme la fenêtre de %s" % [largeur, nom])
		await process_frame
		# Rouvre et suit chaque tuile.
		for k in tuiles.size():
			b = bouton(page, nom)
			b.pressed.emit()
			await process_frame
			fen = page.find_child("MondeArticle", true, false)
			var t := bouton(fen, "MondeArticleLien%d" % k) if fen != null else null
			if t == null:
				check(false, "%d : tuile %d de %s" % [largeur, k, nom])
				continue
			var avant_nav := nav.ouverts.size()
			var avant_route := app.navigations.size()
			t.pressed.emit()
			await process_frame
			check(nav.ouverts.size() > avant_nav or app.navigations.size() > avant_route, "%d : tuile %d de %s mène à un écran" % [largeur, k, nom])
			var restante := page.find_child("MondeArticle", true, false)
			check(restante == null or restante.is_queued_for_deletion(), "%d : fenêtre refermée après la tuile %d de %s" % [largeur, k, nom])
			app.management_ui.erase("competition_page")
	check(nav.ouverts.any(func(t): return str(t.get("kind", "")) == "club"), "%d : un club ouvert depuis un article" % largeur)

## Semaine simulée du vrai moteur : articles par thème, page construite chaque jour, images différentes d'un jour à l'autre.
func semaine(dossier: String) -> void:
	var fichiers: Array = []
	for f in DirAccess.get_files_at(dossier):
		if f.begins_with("jour-") and f.ends_with(".json"): fichiers.append(f)
	fichiers.sort_custom(func(a, b): return int(a.trim_prefix("jour-").trim_suffix(".json")) < int(b.trim_prefix("jour-").trim_suffix(".json")))
	var themes := {}
	var hier := {}
	var total := 0
	for f: String in fichiers:
		var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(dossier.path_join(f)))
		if not m is Dictionary: continue
		var p := A.page(m)
		var ids := {}
		for a: Dictionary in p.tous:
			themes[a.theme] = int(themes.get(a.theme, 0)) + 1
			total += 1
			ids[a.image] = true
		var communs := ids.keys().filter(func(i): return hier.has(i))
		print("SEMAINE %s %s : %d articles, une « %s » (%s), dernière minute %s, images reprises de la veille %d" % [f, m.meta.get("calendarToday", ""), p.tous.size(), p.une.get("titre", ""), p.une.get("theme", ""), "oui" if not p.derniere.is_empty() else "non", communs.size()])
		for a: Dictionary in p.tous: print("  - [%s] %s · %s · %s" % [a.theme, a.titre, a.journaliste.get("name", ""), a.journaliste.get("outlet", "")])
		hier = ids
		await ecran(m, 2560, false)
	var lignes: Array = []
	for th: String in A.THEMES: lignes.append("%s %d" % [th, int(themes.get(th, 0))])
	print("SEMAINE THEMES (%d articles) : %s" % [total, ", ".join(lignes)])

# ---- Monde synthétique ---------------------------------------------------------------------------------------------

func club(id: int, nom: String, couleur: String, pts: int, forme: Array = ["V", "D", "V"]) -> Dictionary:
	return {"id": id, "name": nom, "abbr": nom.substr(0, 3).to_upper(), "color": couleur, "played": 6, "won": pts / 5, "drawn": 0, "lost": 6 - pts / 5,
		"pf": 100 + pts * 3, "pa": 140 - pts, "bonus": 1, "points": pts, "form": forme, "standingsOpen": true}

func stats(scrums: int, scrums_won: int, lineouts: int, lineouts_won: int, goals: int, melee_pen: int) -> Dictionary:
	return {"scrums": scrums, "scrumsWon": scrums_won, "lineouts": lineouts, "lineoutsWon": lineouts_won, "goals": goals, "goalAttempts": goals + 1,
		"penalties": 9, "penaltyFamilies": {"melee": melee_pen, "touche": 0, "ruck": 4, "maul": 0, "jeu": 1}}

func res(lid: String, fid: String, a: int, b: int, sa: int, sb: int, ta: int, tb: int, date: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"pair": [a, b], "score": [sa, sb], "tries": [ta, tb], "fixtureId": fid, "leagueId": lid, "competitionId": lid, "date": date, "phase": "league",
		"stats": [stats(8, 7, 12, 11, 1, 1), stats(8, 6, 12, 10, 1, 1)], "essais": [], "affluence": 9000 + (a * 731) % 9000}
	r.merge(extra, true)
	return r

func monde(aujourdhui: String) -> Dictionary:
	var elite: Array = []
	var noms := ["Aurore Bastide", "Brumes du Lac", "Cèdres Rouges", "Dunes Blanches", "Étoile du Sud", "Forges d'Ardoise", "Grès Rose", "Hautes Landes", "Iris Bleus", "Jonquilles", "Kermès", "Lavandes", "Mistral", "Noyers"]
	for i in 14: elite.append(club(i, noms[i], ["7a1f2b", "1f4e7a", "2f7a3c", "d7aa5a", "5b2a86", "c2571a", "2a2a2a", "0e6b6b", "8a1538", "3a5f0b", "6b4f1d", "1d3557", "e07a5f", "264653"][i], 28 - i * 2, ["D", "D", "D", "D"] if i == 12 else ["V", "D", "V"]))
	var prem: Array = []
	for i in 10: prem.append(club(20 + i, "Shire %d" % (i + 1), ["223344", "aa3322", "117755", "885511", "553388", "338855", "aa8833", "335577", "772233", "446622"][i], 24 - i * 2))
	var urc: Array = []
	for i in 8: urc.append(club(40 + i, "Coast %d" % (i + 1), ["114477", "771144", "447711", "aa5500", "0055aa", "55aa00", "aa0055", "333333"][i], 22 - i * 2))
	var hier := "2026-10-03"
	var history: Array = [
		res("elite", "e1", 3, 9, 41, 6, 6, 0, hier, {"essais": [[5, 0, "b", 1], [20, 0, "b", 2], [33, 0, "j", 3], [50, 0, "m", 1], [60, 0, "j", 2], [75, 0, "j", 3]]}),
		res("elite", "e2", 0, 1, 18, 17, 1, 2, hier),
		res("elite", "e3", 11, 2, 22, 19, 2, 2, hier),
		res("elite", "e4", 4, 5, 45, 38, 6, 6, hier, {"affluence": 31000}),
		res("elite", "e5", 6, 7, 15, 9, 0, 0, hier, {"stats": [stats(6, 5, 10, 9, 5, 0), stats(6, 5, 10, 8, 3, 0)]}),
		res("elite", "e6", 8, 12, 12, 3, 1, 0, hier),
		res("elite", "e7", 10, 13, 27, 20, 3, 2, hier, {"stats": [stats(10, 10, 16, 15, 1, 0), stats(9, 5, 14, 8, 1, 5)]}),
		res("prem", "p1", 20, 21, 33, 30, 4, 4, hier),
		res("prem", "p2", 22, 23, 50, 10, 8, 1, hier),
		res("prem", "p3", 24, 25, 16, 14, 1, 1, hier, {"stats": [stats(9, 9, 15, 14, 1, 0), stats(9, 4, 15, 9, 1, 4)]}),
		res("prem", "p4", 26, 27, 9, 25, 0, 3, hier),
		res("urc", "u1", 40, 41, 21, 24, 2, 3, hier),
		res("urc", "u2", 42, 43, 38, 7, 5, 1, hier),
		res("urc", "u3", 44, 45, 19, 19, 2, 2, hier),
		res("urc", "u4", 46, 47, 27, 13, 3, 1, hier, {"essais": [[5, 0, "b", 1], [20, 0, "b", 2], [33, 0, "b", 3]]}),
	]
	var presse := {
		"elite": [{"id": "presse-0", "name": "Nathan Delcourt", "outlet": "Mêlée Hebdo", "style": "technique"}, {"id": "presse-1", "name": "Rémi Bourgoin", "outlet": "Le Journal du XV", "style": "analyse"},
			{"id": "presse-3", "name": "Marc Vidalenc", "outlet": "Mêlée Hebdo", "style": "enquete"}, {"id": "presse-6", "name": "Louis Farge", "outlet": "Mêlée Hebdo", "style": "editorial"}, {"id": "presse-2", "name": "Adrien Lestrade", "outlet": "Mêlée Hebdo", "style": "interview"}],
		"prem": [{"id": "presse-10", "name": "Harriet Ashdown", "outlet": "Twin Posts Gazette", "style": "technique"}, {"id": "presse-11", "name": "Graham Whitlock", "outlet": "Twin Posts Gazette", "style": "analyse"}, {"id": "presse-12", "name": "Priya Ranscombe", "outlet": "Chalkline Radio", "style": "enquete"}],
		"urc": [{"id": "presse-20", "name": "Aoife Kilbride", "outlet": "The Breakdown Bulletin", "style": "analyse"}, {"id": "presse-21", "name": "Declan Rathmore", "outlet": "Atlantic Sport Despatch", "style": "interview"}],
	}
	var monde_ := {
		"transferts": [
			{"date": "2026-10-02", "saison": 1, "semaine": 6, "type": "accord", "playerId": "w:1", "nom": "Tomas VELLACOURT", "pos": "Demi d'ouverture", "age": 27, "note": 81, "vendeurId": 22, "acheteurId": 5, "montant": 640000, "appearanceBuild": 0.3, "appearanceBankVersion": 2},
			{"date": "2026-10-01", "saison": 1, "semaine": 6, "type": "precontrat", "playerId": "w:2", "nom": "Owen BRACKLEY", "pos": "Talonneur", "age": 30, "note": 74, "vendeurId": 41, "acheteurId": 24, "montant": 0},
		],
		"blessures": [{"id": "w:3", "name": "Sione FALEMAKA", "pos": "Troisième ligne aile", "age": 26, "rating": 79, "clubId": 2, "weeks": 4, "appearanceBuild": -0.2, "appearanceBankVersion": 2}],
		"presse": presse,
	}
	return {"meta": {"mode": "world", "leagueId": "elite", "season": 1, "week": 6, "calendarToday": aujourdhui, "date": "2026-10-10"},
		"club": elite[3].duplicate(), "league": elite, "leagues": [{"id": "elite", "name": "Top 14", "rows": elite}, {"id": "prem", "name": "Premiership", "rows": prem}, {"id": "urc", "name": "URC", "rows": urc}],
		"history": history, "monde": monde_, "clubNext": {"0": {"opponent": elite[1].duplicate(), "home": true, "neutral": false, "date": "2026-10-10", "week": 7}}}
