extends SceneTree
## Réception · message « Analyse vidéo » (revue FM27, idée 28 ; choix B de Léo du 23/11/2026). Godot réel + worker réel,
## carrière Monde, un match délégué joué puis jour du match suivant.
## - le message de l'analyste vidéo est en Réception ; ouvert, son panneau remplace la lettre (aucune phrase) ;
## - verdicts en colonne (Attaque, Entrées 22 m, Domination, Conquête, Discipline, Défense) : chiffres du vrai match ;
##   un clic sur chacun → petite fenêtre de sa donnée, entière à l'écran ; Échap (sans menu), ✕, clic à côté la ferment ;
## - quatre onglets (Occasions, Domination, Nos joueurs, Conquête et discipline) : un clic change le contenu sur place ;
## - occasions : une marche par entrée dans les 22, un ballon par essai posé sur la courbe, clic = fiche du marqueur ;
## - domination : une barre par minute jouée (données gardées après le match) ;
## - 2560×1440 et 1920×1080 : panneau entier dans la lecture, rien hors écran.
## Imprime une ligne ANALYSTE_VIDEO {checks, failures, destinations}. Captures si CD_ANALYSTE_CAPTURES (hors headless).
const Flow = preload("helpers/contextual_flow.gd")
const Bilan = preload("res://ui/immersive08/avant_match_bilan.gd")
const Analyste = preload("res://ui/immersive08/analyste_match.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var destinations: Array[String] = []
var captures := OS.get_environment("CD_ANALYSTE_CAPTURES")

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
	await cliquer_point(point)

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
	var f := app.find_child(Analyste.FENETRE, true, false)
	return f if f != null and not f.is_queued_for_deletion() else null

func menu_carriere() -> bool:
	for w: Node in app.find_children("*PauseMenu", "", true, false):
		if w is Window and (w as Window).visible: return true
	return false

func trouver(nom: String) -> Control:
	var n := app.find_child(nom, true, false)
	return n as Control if n != null and not n.is_queued_for_deletion() else null

func mail_analyse() -> String:
	var id := ""
	for courrier: Dictionary in load("res://ui/club_mail.gd").mails(app.model):
		if str(courrier.get("type", "")) == Analyste.TYPE and str(courrier.id).trim_prefix("mail-").to_int() > id.trim_prefix("mail-").to_int(): id = str(courrier.id)
	return id

func ouvrir_message(id: String) -> Control:
	app._reset_reception(id)
	app._navigate("Réception", false)
	await settle(12)
	return trouver("AnalysteMatch")

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
	if not await Flow.prepare_match_day(app, self, check): return finish()
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
	check(not report.is_empty(), "Rapport du dernier match disponible")
	var analyse: Variant = report.get("analyse")
	check(analyse is Dictionary and (analyse.get("domination", []) as Array).size() >= 70, "Analyse gardée après le match (domination minute par minute)")
	if report.is_empty() or not analyse is Dictionary: return finish()
	var id := mail_analyse()
	check(not id.is_empty(), "Message « Analyse vidéo » en Réception")
	if id.is_empty(): return finish()
	var nous := int(report.side)
	var entrees := int(analyse.zone22.entrees[nous])
	var entrees_eux := int(analyse.zone22.entrees[1 - nous])
	for t: Vector2i in [Vector2i(2560, 1440), Vector2i(1920, 1080)]:
		var nom := "%dx%d" % [t.x, t.y]
		await taille(t)
		var bloc := await ouvrir_message(id)
		check(bloc != null, "%s : panneau de l'analyste dans le message" % nom)
		if bloc == null: continue
		check(trouver("InboxMessageText") == null, "%s : pas de lettre (aucune phrase)" % nom)
		var score := trouver("AnalysteScore") as Label
		check(score != null and score.text.contains("%d – %d" % [int(report.score[0]), int(report.score[1])]), "%s : score du match analysé dans l'en-tête" % nom)
		var lecture := trouver("InboxReadingScroll") as ScrollContainer
		if lecture != null:
			lecture.scroll_vertical = int(bloc.global_position.y - lecture.global_position.y) + lecture.scroll_vertical - 8
			await settle()
		var fond := trouver("AnalysteFond")
		check(fond != null and ecran().encloses(rect(fond)), "%s : panneau entier à l'écran %s" % [nom, rect(fond) if fond != null else Rect2()])
		# Verdicts : chiffres du vrai match.
		var occ := trouver("AnalysteVerdict_occasions")
		check(occ != null, "%s : verdict des entrées dans les 22" % nom)
		if occ != null:
			var textes := " ".join(occ.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
			check(textes.contains("%d – %d" % [entrees, entrees_eux]), "%s : entrées 22 m du match (%d – %d) : %s" % [nom, entrees, entrees_eux, textes])
		var essais := [0, 0]
		for e: Dictionary in report.get("essais", []): essais[int(e.side)] += 1
		var att := trouver("AnalysteVerdict_attaque")
		if att != null:
			var textes := " ".join(att.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
			check(textes.contains("%d – %d" % [essais[nous], essais[1 - nous]]), "%s : essais du match dans le verdict Attaque : %s" % [nom, textes])
		await capture("analyse-%s" % nom)
		# Onglets : un clic change le contenu sur place.
		for o: Array in [["domination", "AnalysteDomination"], ["joueurs", "AnalysteJoueurs"], ["conquete", "AnalysteConquete"], ["occasions", "AnalysteOccasions"]]:
			var lien := trouver("AnalysteOngletLien_" + str(o[0]))
			check(lien != null, "%s : onglet %s" % [nom, o[0]])
			if lien == null: continue
			await cliquer(lien)
			await settle()
			var vue := trouver(str(o[1]))
			check(vue != null and vue.is_visible_in_tree() and fenetre() == null, "%s : onglet %s → %s sur place" % [nom, o[0], o[1]])
			if vue != null and fond != null: check(rect(fond).grow(1).encloses(rect(vue)), "%s : %s dans le panneau" % [nom, o[1]])
			if o[0] == "joueurs" and t.x == 1920: await capture("analyse-joueurs-%s" % nom)
			if o[0] == "domination" and vue != null: check(vue.find_children("AnalysteDomMinute*", "", true, false).size() >= 40, "%s : une barre par minute de domination" % nom)
		# Occasions : un ballon par essai.
		var ballons := app.find_children("AnalysteEssaiLien*", "Button", true, false).filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())
		check(ballons.size() == essais[0] + essais[1], "%s : un ballon par essai sur la courbe des occasions (%d)" % [nom, ballons.size()])
		# Verdicts → petite fenêtre.
		for v: Array in [["attaque", "AnalysteOccasions"], ["occasions", "AnalysteOccasions"], ["domination", "AnalysteDomination"], ["conquete", "AnalysteConquete"], ["discipline", "AnalysteConquete"], ["defense", "AnalysteJoueurs"]]:
			var lien := trouver("AnalysteVerdictLien_" + str(v[0]))
			check(lien != null, "%s : verdict %s cliquable" % [nom, v[0]])
			if lien == null: continue
			await cliquer(lien)
			check(fenetre() != null, "%s : verdict %s → petite fenêtre" % [nom, v[0]])
			var panneau := trouver(Analyste.FENETRE + "Panneau")
			check(panneau != null and ecran().encloses(rect(panneau)), "%s : fenêtre %s entière à l'écran" % [nom, v[0]])
			if panneau != null: check(panneau.find_child(str(v[1]), true, false) != null, "%s : fenêtre %s montre %s" % [nom, v[0], v[1]])
			if t.x == 1920 and v[0] == "domination": await capture("fenetre-domination-%s" % nom)
			if v[0] == "occasions": await capture("fenetre-occasions-%s" % nom)
			if t.x == 2560 and v[0] == "domination": await capture("fenetre-domination-%s" % nom)
			if destinations.size() < 6: destinations.append("AnalysteVerdictLien_%s -> petite fenêtre %s" % [v[0], v[1]])
			await touche(KEY_ESCAPE)
			check(fenetre() == null, "%s : Échap ferme la fenêtre %s" % [nom, v[0]])
			check(not menu_carriere(), "%s : Échap n'ouvre pas le menu de la carrière" % nom)
			if menu_carriere(): app._clear_dialogs(); await settle()
		var lien_d := trouver("AnalysteVerdictLien_domination")
		if lien_d != null:
			await cliquer(lien_d)
			var croix := trouver(Analyste.FENETRE + "Fermer")
			if croix != null: await cliquer(croix)
			check(fenetre() == null, "%s : ✕ ferme la fenêtre" % nom)
			await cliquer(lien_d)
			var panneau := trouver(Analyste.FENETRE + "Panneau")
			await cliquer_point(Vector2(rect(panneau).position.x * .5, rect(panneau).get_center().y) if panneau != null else Vector2(8, 300))
			check(fenetre() == null, "%s : clic à côté ferme la fenêtre" % nom)
	# Ballon d'un essai → fiche du marqueur (un de nos essais).
	await taille(Vector2i(1920, 1080))
	await ouvrir_message(id)
	var lien_essai: Button = null
	for b: Node in app.find_children("AnalysteEssaiLien%d_*" % nous, "Button", true, false):
		lien_essai = b as Button
		break
	if lien_essai != null:
		lien_essai.pressed.emit()
		await settle(12)
		check(app.route != "Réception", "Ballon d'un essai → fiche du marqueur (%s)" % app.route)
		destinations.append("AnalysteEssaiLien -> %s" % app.route)
	else:
		destinations.append("Aucun essai de notre camp : lien du marqueur non vérifié")
	finish()

func finish() -> void:
	print("ANALYSTE_VIDEO ", JSON.stringify({"checks": checks, "failures": failures, "destinations": destinations}))
	quit(0 if failures.is_empty() else 1)
