extends SceneTree
## Avant-match · « Dernière rencontre » (option B choisie par Léo le 21/11/2026). Godot réel + worker réel, carrière Monde.
## - début de saison (aucun match joué) : pas de pastille du dernier match dans le bandeau ;
## - après un match : pastille « résultat · écusson adverse · score » dans le bandeau, sans chevauchement en 2560×1440,
##   1920×1080 et 1280×720 ; un clic (souris) ouvre la petite fenêtre du bilan, entière à l'écran ;
## - la fenêtre montre la carte du compte rendu en version réduite (idée FM n°19, 23/11/2026) : bandeau du score,
##   frise 0-80' avec un repère par essai marqué, stats, marqueurs ; pas la colonne « le match » de l'article ;
## - Échap (sans menu de la carrière), ✕ et clic à côté la ferment ;
## - « tes choix » → Plan de jeu ; zone du club adverse → sa fiche.
## Imprime une ligne AVANT_MATCH_BILAN {checks, failures, destinations}. Captures si CD_BILAN_CAPTURES (hors headless).
const Flow = preload("helpers/contextual_flow.gd")
const Bilan = preload("res://ui/immersive08/avant_match_bilan.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
var captures := OS.get_environment("CD_BILAN_CAPTURES")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 8) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame

func taille(t: Vector2i) -> void:
	root.size = t
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(t)
	await settle(10)

func capture(nom: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await settle(6)
	DirAccess.make_dir_recursive_absolute(captures)
	root.get_texture().get_image().save_png(captures.path_join(nom + ".png"))

func cliquer(cible: Control) -> void:
	var point := cible.get_global_transform_with_canvas() * (cible.size * .5)
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
	await settle()

func cliquer_point(point: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
	await settle()

func touche(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	await settle()

func rect(c: Control) -> Rect2:
	return c.get_global_rect()

func ecran() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(root.size))

func fenetre() -> Node:
	var f := app.find_child(Bilan.FENETRE, true, false)
	return f if f != null and not f.is_queued_for_deletion() else null

func menu_carriere() -> bool:
	for w: Node in app.find_children("*PauseMenu", "", true, false):
		if w is Window and (w as Window).visible: return true
	return false

func avant_match() -> Control:
	app._navigate("Match"); await settle(12)
	return app.match_screen.find_child("MatchOpening", true, false) if app.match_screen != null else null

func ouvrir_bilan(contexte: String) -> bool:
	var ouvre := app.find_child("MatchLastMatchOpen", true, false) as Button
	check(ouvre != null and ouvre.is_visible_in_tree(), "%s : pastille du dernier match cliquable" % contexte)
	if ouvre == null: return false
	await cliquer(ouvre)
	check(fenetre() != null, "%s : clic sur la pastille → petite fenêtre « Dernière rencontre »" % contexte)
	return fenetre() != null

func run() -> void:
	await taille(Vector2i(1920, 1080))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if is_instance_valid(app.coach): app.coach.speech.set_muted(true)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	check(await Flow.command_wait(app, self, check, "new_career", {"mode": "world-champ", "club": 102, "start": "premiers-clubs"}), "Carrière Monde créée")
	if is_instance_valid(app.coach): app.coach.close()
	# Début de saison : premier jour de match, aucun match joué → pas de pastille.
	if not await Flow.prepare_match_day(app, self, check): return finish()
	var avant := await avant_match()
	check(avant != null, "Début de saison : avant-match ouvert")
	check(Bilan.rapport(app.model).is_empty(), "Début de saison : aucun bilan de match")
	check(app.find_child("MatchLastMatchChip", true, false) == null and app.find_child("MatchLastMatchOpen", true, false) == null, "Début de saison : pas de pastille du dernier match")
	await capture("debut-saison-1920")
	# Un match joué (délégué), puis le jour du match suivant.
	if not await Flow.command_wait(app, self, check, "auto_lineup"): return finish()
	if not await Flow.command_wait(app, self, check, "begin_match"): return finish()
	await Flow._skip_scene_talk(app, self, check)
	if not await Flow.command_wait(app, self, check, "delegate"): return finish()
	await Flow._skip_scene_talk(app, self, check)
	if app.model.get("live") is Dictionary:
		if not await Flow.command_wait(app, self, check, "finish_round"): return finish()
		await Flow._skip_scene_talk(app, self, check)
	if not await Flow.prepare_match_day(app, self, check): return finish()
	var report := Bilan.rapport(app.model)
	check(not report.is_empty(), "Bilan du dernier match disponible")
	if report.is_empty(): return finish()
	var mot := Bilan.resultat(report)
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var nom := "%dx%d" % [t.x, t.y]
		await taille(t)
		avant = await avant_match()
		check(avant != null, "%s : avant-match ouvert" % nom)
		if avant == null: continue
		var chip := app.find_child("MatchLastMatchChip", true, false) as Control
		check(chip != null and chip.is_visible_in_tree(), "%s : pastille du dernier match dans le bandeau" % nom)
		if chip == null: continue
		var texte := " ".join(chip.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
		var res := chip.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == mot)
		check(not res.is_empty(), "%s : pastille « %s » (résultat) " % [nom, mot])
		check(texte.contains("%d – %d" % [int(report.score[0]), int(report.score[1])]), "%s : score dans la pastille : %s" % [nom, texte])
		check(ecran().encloses(rect(chip)), "%s : pastille entière à l'écran %s" % [nom, rect(chip)])
		check(chip.size.x + .5 >= chip.get_combined_minimum_size().x, "%s : pastille non tronquée" % nom)
		# Aucun chevauchement avec les autres éléments du bandeau.
		var ligne := chip.get_parent() as Control
		var voisins: Array = ligne.get_children().filter(func(n: Node) -> bool: return n is Control and n != chip and (n as Control).is_visible_in_tree() and (n as Control).size.x > 1)
		for v: Control in voisins:
			check(not rect(v).grow(-1).intersects(rect(chip).grow(-1)), "%s : pastille sans chevauchement avec %s" % [nom, v.name])
			check(ecran().encloses(rect(v).grow(-1)), "%s : %s du bandeau à l'écran %s" % [nom, v.name, rect(v)])
		await capture("avant-match-%s" % nom)
		if not await ouvrir_bilan(nom): continue
		var panneau := app.find_child(Bilan.FENETRE + "Panneau", true, false) as Control
		check(panneau != null and ecran().encloses(rect(panneau)), "%s : fenêtre entière à l'écran %s" % [nom, rect(panneau) if panneau != null else Rect2()])
		if panneau != null:
			for c: Control in panneau.find_children("Bilan*", "Control", true, false):
				if c.is_visible_in_tree() and c.size.x > 0: check(rect(panneau).grow(1).encloses(rect(c)), "%s : %s dans la fenêtre %s" % [nom, c.name, rect(c)])
		for id in ["CompteRenduCarte", "CompteRenduScore", "CompteRenduResultat", "CompteRenduFrise", "CompteRenduMiTemps", "CompteRenduStat0", "BilanTitreChoix", "BilanChoixAttaque", "BilanChoixDefense", "BilanChoixStaff", "BilanClubAdverse"]:
			check(app.find_child(id, true, false) != null, "%s : fenêtre · %s" % [nom, id])
		check(app.find_child("CompteRenduLieu", true, false) == null and app.find_child("CompteRenduHdm", true, false) == null, "%s : carte réduite (sans la colonne du match)" % nom)
		var essais_marques: int = (report.get("essais", []) as Array).size()
		check(essais_marques == app.find_children("CompteRenduFriseEssai*", "", true, false).size(), "%s : un repère par essai sur la frise (%d)" % [nom, essais_marques])
		var carte := app.find_child("CompteRenduCarte", true, false) as Control
		if carte != null and panneau != null: check(rect(panneau).grow(1).encloses(rect(carte)), "%s : carte entière dans la fenêtre %s / %s" % [nom, rect(carte), rect(panneau)])
		await capture("fenetre-%s" % nom)
		# Fermetures : Échap (sans menu de la carrière), ✕, clic à côté.
		await touche(KEY_ESCAPE)
		check(fenetre() == null, "%s : Échap ferme la fenêtre" % nom)
		check(not menu_carriere(), "%s : Échap n'ouvre pas le menu de la carrière" % nom)
		if menu_carriere(): app._clear_dialogs(); await settle()
		if await ouvrir_bilan(nom + " (✕)"):
			var croix := app.find_child(Bilan.FENETRE + "Fermer", true, false) as Button
			check(croix != null, "%s : ✕ présent" % nom)
			if croix != null: await cliquer(croix)
			check(fenetre() == null, "%s : ✕ ferme la fenêtre" % nom)
		if await ouvrir_bilan(nom + " (à côté)"):
			panneau = app.find_child(Bilan.FENETRE + "Panneau", true, false) as Control
			var a_cote := Vector2(rect(panneau).position.x * .5, rect(panneau).get_center().y) if panneau != null else Vector2(8, 300)
			await cliquer_point(a_cote)
			check(fenetre() == null, "%s : clic à côté ferme la fenêtre" % nom)
	destinations.append("MatchLastMatchOpen [bandeau] -> petite fenêtre Dernière rencontre")
	# Tes choix → Plan de jeu.
	await taille(Vector2i(1920, 1080))
	avant = await avant_match()
	for id in ["BilanChoixAttaqueLien", "BilanChoixDefenseLien", "BilanChoixStaffLien"]:
		if not await ouvrir_bilan(id): break
		var lien := app.find_child(id, true, false) as Button
		check(lien != null, "Lien %s" % id)
		if lien == null: continue
		await cliquer(lien)
		await settle(10)
		check(fenetre() == null, "%s : la fenêtre se ferme" % id)
		check(app.route == "Plan de jeu", "%s → Plan de jeu (%s)" % [id, app.route])
		destinations.append("%s [fenêtre] -> %s" % [id, app.route])
		avant = await avant_match()
	# Zone du club adverse → sa fiche.
	if await ouvrir_bilan("club adverse"):
		var zone := app.find_child("BilanClubAdverse", true, false) as Button
		check(zone != null, "Zone du club adverse cliquable")
		if zone != null:
			await cliquer(zone)
			var limite := Time.get_ticks_msec() + 60000
			while app.waiting and Time.get_ticks_msec() < limite: await process_frame
			await settle(10)
			check(fenetre() == null, "Club adverse : la fenêtre se ferme")
			check(app.route == app.Immersive.ClubSheet.ROUTE, "Club adverse → fiche du club (%s)" % app.route)
			var adverse_id := str(int(report.teams[1 - int(report.side)].id))
			var fiche: Variant = app.management_ui.get("club_sheet")
			var fiche_id := str(int(fiche.get("id", -1))) if fiche is Dictionary else ""
			check(fiche_id == adverse_id, "Fiche du bon club : %s / %s" % [fiche_id, adverse_id])
			destinations.append("BilanClubAdverse [fenêtre] -> %s" % app.route)
	await article_compte_rendu(report)
	await essai_apres_mi_temps(report)
	await frise_rangee_chargee()
	await bandeau_feuille_incomplete()
	finish()

## Frise figée (même cas quel que soit le match joué) : sept essais des visiteurs dont trois autour de la 40e et quatre
## noms longs en seconde période ; les étiquettes tiennent dans la carte, sans chevauchement ni « MT » couvert.
func frise_rangee_chargee() -> void:
	var origine: Array = (app.model.decisions.report.get("essais", []) as Array).duplicate(true)
	var essais: Array = []
	for e: Array in [[39, 0, "Mathéo ESSAI-MT", "j"], [40, 1, "Mathéo ESSAI-MT", "j"], [41, 1, "Mathéo ESSAI-MT", "j"], [41, 0, "Mathéo ESSAI-MT", "j"], [42, 1, "Mathéo ESSAI-MT", "j"],
			[45, 1, "Jean-Baptiste FAIRCLOUGH", "b"], [67, 1, "Tom FAIRCLOUGH", "j"], [76, 1, "Kyle OYONO-MBARGA", "m"], [80, 1, "Emmanuel BICKERSTAFF", "j"]]:
		essais.append({"minute": e[0], "side": e[1], "id": null, "name": e[2], "origin": e[3], "zone": 30})
	app.model.decisions.report.essais = essais
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		await taille(t)
		var avant := await avant_match()
		if avant == null or not await ouvrir_bilan("frise chargée"): continue
		var mt := app.find_child("CompteRenduMiTemps", true, false) as Control
		var carte := app.find_child("CompteRenduCarte", true, false) as Control
		check(mt != null and carte != null, "%dx%d · frise chargée : « MT » et carte" % [t.x, t.y])
		if mt == null or carte == null: continue
		var etiquettes: Array = app.find_children("CompteRenduFriseEtiquette*", "", true, false)
		check(etiquettes.size() == essais.size(), "%dx%d · frise chargée : une étiquette par essai (%d)" % [t.x, t.y, etiquettes.size()])
		for i in etiquettes.size():
			check(rect(carte).grow(1).encloses(rect(etiquettes[i])), "%dx%d · frise chargée : %s dans la carte %s" % [t.x, t.y, etiquettes[i].name, rect(etiquettes[i])])
			check(not rect(etiquettes[i]).grow(-1).intersects(rect(mt)), "%dx%d · frise chargée : %s ne couvre pas « MT »" % [t.x, t.y, etiquettes[i].name])
			for j in range(i + 1, etiquettes.size()):
				check(not rect(etiquettes[i]).grow(-1).intersects(rect(etiquettes[j]).grow(-1)), "%dx%d · frise chargée : %s et %s sans chevauchement" % [t.x, t.y, etiquettes[i].name, etiquettes[j].name])
		await capture("fenetre-frise-chargee-%dx%d" % [t.x, t.y])
		await touche(KEY_ESCAPE)
	app.model.decisions.report.essais = origine
	destinations.append("Frise chargée : sept essais d'un camp sans chevauchement")

## 1280×720, feuille incomplète (erreur longue, coup d'envoi verrouillé) : tout le bandeau reste à l'écran, sans
## chevauchement (MatchKickoff sorti de l'écran les 21 et 22/11 selon l'état de la feuille du match joué).
func bandeau_feuille_incomplete() -> void:
	var origine: Variant = app.model.get("selection")
	check(origine is Dictionary, "Feuille du prochain match lisible")
	if not origine is Dictionary: return
	var selection: Dictionary = (origine as Dictionary).duplicate(true)
	selection.valid = false
	selection.errors = ["League One : vérifie les inscriptions et les quotas de la feuille (14 A-1, au plus 3 joueurs sous contrat C)"]
	app.model.selection = selection
	await taille(Vector2i(1280, 720))
	var avant := await avant_match()
	check(avant != null, "1280x720 · feuille incomplète : avant-match ouvert")
	var statut := app.find_child("MatchOpenSheetStatus", true, false) as Button
	check(statut != null and statut.is_visible_in_tree() and statut.text.begins_with("Feuille incomplète"), "1280x720 · feuille incomplète : statut affiché")
	var kickoff := app.find_child("MatchKickoff", true, false) as Control
	check(kickoff != null and kickoff.is_visible_in_tree(), "1280x720 · feuille incomplète : coup d'envoi dans le bandeau")
	if kickoff != null:
		var enfants: Array = kickoff.get_parent().get_children().filter(func(n: Node) -> bool: return n is Control and (n as Control).is_visible_in_tree() and (n as Control).size.x > 1)
		for i in enfants.size():
			check(ecran().encloses(rect(enfants[i]).grow(-1)), "1280x720 · feuille incomplète : %s du bandeau à l'écran %s" % [enfants[i].name, rect(enfants[i])])
			for j in range(i + 1, enfants.size()):
				check(not rect(enfants[i]).grow(-1).intersects(rect(enfants[j]).grow(-1)), "1280x720 · feuille incomplète : %s et %s sans chevauchement" % [enfants[i].name, enfants[j].name])
	await capture("avant-match-feuille-incomplete-1280x720")
	app.model.selection = origine
	destinations.append("Bandeau 1280×720, feuille incomplète : coup d'envoi à l'écran")

## Essais juste avant et juste après la 40e (les deux camps) : aucune étiquette de la frise ne couvre « MT ».
func essai_apres_mi_temps(report: Dictionary) -> void:
	var origine: Array = (report.get("essais", []) as Array).duplicate(true)
	var essais := origine.duplicate(true)
	for e: Array in [[39, 0], [40, 1], [41, 1], [41, 0], [42, 1]]:
		essais.append({"minute": e[0], "side": e[1], "id": null, "name": "Mathéo ESSAI-MT", "origin": "j", "zone": 30})
	essais.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.minute) < int(b.minute))
	app.model.decisions.report.essais = essais
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		await taille(t)
		var avant := await avant_match()
		if avant == null or not await ouvrir_bilan("essai après 40'"): continue
		var mt := app.find_child("CompteRenduMiTemps", true, false) as Control
		check(mt != null, "%dx%d : « MT » sur la frise" % [t.x, t.y])
		if mt == null: continue
		var etiquettes: Array = app.find_children("CompteRenduFriseEtiquette*", "", true, false)
		check(etiquettes.size() == essais.size(), "%dx%d : une étiquette par essai (%d)" % [t.x, t.y, etiquettes.size()])
		for i in etiquettes.size():
			check(not rect(etiquettes[i]).grow(-1).intersects(rect(mt)), "%dx%d : %s ne couvre pas « MT » %s / %s" % [t.x, t.y, etiquettes[i].name, rect(etiquettes[i]), rect(mt)])
			for j in range(i + 1, etiquettes.size()):
				check(not rect(etiquettes[i]).grow(-1).intersects(rect(etiquettes[j]).grow(-1)), "%dx%d : %s et %s sans chevauchement" % [t.x, t.y, etiquettes[i].name, etiquettes[j].name])
		await capture("fenetre-mt-%dx%d" % [t.x, t.y])
		await touche(KEY_ESCAPE)
	app.model.decisions.report.essais = origine
	destinations.append("Frise : essais autour de la 40e sans recouvrir « MT »")

## Réception : l'article du dernier match porte la carte complète (frise, le match avec le public, stats, marqueurs).
func article_compte_rendu(report: Dictionary) -> void:
	var article := ""
	for courrier: Dictionary in load("res://ui/club_mail.gd").mails(app.model):
		if str(courrier.get("type", "")) == "article": article = str(courrier.id); break
	if article.is_empty():
		destinations.append("Réception : aucun article de match (carte non vérifiée)")
		return
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		await taille(t)
		app._reset_reception(article)
		app._navigate("Réception", false)
		await settle(12)
		var carte := app.find_child("CompteRenduCarte", true, false) as Control
		check(carte != null, "%dx%d : article du match · carte du compte rendu" % [t.x, t.y])
		if carte == null: continue
		for id in ["CompteRenduFrise", "CompteRenduMiTemps", "CompteRenduLieu", "CompteRenduStat0", "CompteRenduResultat"]:
			check(carte.find_child(id, true, false) != null, "%dx%d : article · %s" % [t.x, t.y, id])
		if report.get("affluence") is float or report.get("affluence") is int:
			var public := carte.find_child("CompteRenduAffluenceValeur", true, false) as Label
			check(public != null and public.text.replace(" ", "") == str(int(report.affluence)), "%dx%d : public %s" % [t.x, t.y, public.text if public != null else "absent"])
		else: check(false, "Affluence du dernier match absente du compte rendu")
		check(carte.find_children("CompteRenduFriseEssai*", "", true, false).size() == (report.get("essais", []) as Array).size(), "%dx%d : un repère par essai sur la frise" % [t.x, t.y])
		for camp in 2:
			var etiquettes: Array = carte.find_children("CompteRenduFriseEtiquette%d_*" % camp, "", true, false)
			for i in etiquettes.size():
				check(rect(carte).grow(1).encloses(rect(etiquettes[i])), "%dx%d : étiquette %s dans la carte" % [t.x, t.y, etiquettes[i].name])
				for j in range(i + 1, etiquettes.size()):
					check(not rect(etiquettes[i]).grow(-1).intersects(rect(etiquettes[j]).grow(-1)), "%dx%d : étiquettes %s et %s sans chevauchement" % [t.x, t.y, etiquettes[i].name, etiquettes[j].name])
		var lecture := app.find_child("InboxReadingScroll", true, false) as ScrollContainer
		if lecture != null:
			lecture.scroll_vertical = int(carte.global_position.y - lecture.global_position.y) + lecture.scroll_vertical - 12
			await settle(6)
		await capture("article-%dx%d" % [t.x, t.y])
	destinations.append("Réception : article du dernier match -> carte du compte rendu")

func finish() -> void:
	print("AVANT_MATCH_BILAN " + JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	app.closing = true
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)
