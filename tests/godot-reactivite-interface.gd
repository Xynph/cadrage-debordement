extends SceneTree
## Réactivité de l'interface (lot 23), Godot réel + worker réel, carrière Monde (world-champ) neuve.
## - Décision optimiste : la consigne choisie est dans le modèle affiché dès le clic, avant la réponse du moteur.
## - Coût côté interface d'une décision, hors moteur : lecture de la réponse (fil d'E/S) + application du patch
##   (fil principal), seuil large 150 ms (médiane) ; le rendu de l'écran est mesuré et imprimé à part.
## - Deux clics rapprochés sur le même réglage : le second attend son tour, aucun refus.
## - Refus du moteur : la valeur affichée d'avance est annulée, fenêtre de refus habituelle.
## - Patchs sans copie : un instantané différentiel est identique à un instantané complet (sections reprises
##   intactes après plusieurs rendus).
## - Fiche club : seconde ouverture du même jour sans commande moteur ; « Suivre » bascule dès le clic sans relire
##   la fiche.
## - Rafraîchissement par écran (ui/screen_refresh.gd) : règles de la table ; sur 10 écrans, une réponse sans section
##   lue par l'écran le garde tel quel (rendu mesuré avant/après), et l'écran gardé est identique au rendu complet
##   (signature de l'arbre : textes, boutons grisés ou enfoncés, éléments visibles) ; une décision lue par l'écran le
##   redessine toujours.
## Imprime une ligne REACTIVITE {checks, failures, mesures}.
const Flow = preload("helpers/contextual_flow.gd")
const ScreenRefresh = preload("res://ui/screen_refresh.gd")
const ECRANS := ["Bureau", "Effectif", "Composition", "Calendrier", "Classements", "Club", "Finances", "Recrutement", "Staff", "Préparation"]
const SEUIL_HORS_MOTEUR_MS := 150.0
var app: Control
var checks := 0
var failures: Array[String] = []
var mesures := {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 4) -> void:
	for frame in frames: await process_frame

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	check(app.bridge.last_response_ok, "Worker réel · " + id + " · " + app.last_error)
	return app.bridge.last_response_ok

## Fenêtres de refus de décision ouvertes par main.gd (_failed), fermées ; les sélecteurs de fichiers restent.
func close_dialogs() -> int:
	var count := 0
	for dialog: Node in app.find_children("*", "AcceptDialog", true, false):
		if dialog is FileDialog or (dialog as AcceptDialog).title != "Ta décision n'a pas été appliquée": continue
		count += 1
		dialog.free()
	return count

func median(values: Array) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 0})
	await Flow.settle_club_meetings(app, self, check)
	check(app.model.get("club") is Dictionary, "Carrière Monde créée")
	plan_rules()
	await decisions()
	await integrity()
	await refresh_screens()
	await club_sheet()
	print("REACTIVITE ", JSON.stringify({"checks": checks, "failures": failures, "mesures": mesures}))
	quit(0 if failures.is_empty() else 1)

## Consignes depuis l'écran Préparation : affichage immédiat, coût hors moteur, file, refus.
func decisions() -> void:
	app._navigate("Préparation")
	await settle()
	var tactics: Dictionary = app.model.get("tactics", {})
	var attacks: Array = tactics.get("attacks", [])
	check(attacks.size() >= 3, "Trois intentions d'attaque proposées")
	if attacks.size() < 3: return
	var hors_moteur: Array = []
	var rendus: Array = []
	var affichages: Array = []
	for tour in 6:
		var wanted := str(attacks[(tour + 1) % attacks.size()].id)
		if wanted == str(app.model.tactics.attack): wanted = str(attacks[(tour + 2) % attacks.size()].id)
		var log_size: int = app.timing_log.size()
		var clicked := Time.get_ticks_usec()
		check(app._command("set_tactics", {"attack": wanted, "defense": app.model.tactics.defense}), "Consigne envoyée")
		# Optimiste : la valeur est dans le modèle affiché avant toute réponse (la réponse est lue au plus tôt à la
		# fin de l'image).
		check(app.waiting and str(app.model.tactics.attack) == wanted, "Consigne affichée dès le clic (tour %d)" % tour)
		await process_frame
		affichages.append((Time.get_ticks_usec() - clicked) / 1000.0)
		await wait_engine()
		check(app.bridge.last_response_ok and str(app.model.tactics.attack) == wanted, "Consigne confirmée par le moteur (tour %d)" % tour)
		if app.timing_log.size() > log_size:
			var entry: Dictionary = app.timing_log[-1]
			hors_moteur.append(float(entry.get("analyse_ms", 0.0)) + float(entry.get("composition_ms", 0.0)))
			rendus.append(float(entry.get("rendu_ms", 0.0)))
	check(hors_moteur.size() == 6, "Mesures CD_TIMING disponibles (%d)" % hors_moteur.size())
	var cout := median(hors_moteur)
	check(cout < SEUIL_HORS_MOTEUR_MS, "Décision : lecture + application du patch < %d ms hors moteur (médiane %.1f ms)" % [int(SEUIL_HORS_MOTEUR_MS), cout])
	mesures["decision_hors_moteur_ms"] = {"mediane": cout, "max": hors_moteur.max() if not hors_moteur.is_empty() else 0.0, "valeurs": hors_moteur}
	mesures["decision_rendu_ms"] = {"mediane": median(rendus), "valeurs": rendus}
	mesures["affichage_optimiste_ms"] = {"mediane": median(affichages), "valeurs": affichages}
	# Deux clics rapprochés sur le même réglage : le second attend son tour, sans fenêtre de refus.
	var dialogs := close_dialogs()
	var first := str(attacks[0].id)
	var second := str(attacks[1].id)
	if str(app.model.tactics.attack) == first: first = str(attacks[2].id)
	check(app._command("set_tactics", {"attack": first, "defense": app.model.tactics.defense}), "Premier clic envoyé")
	check(app._command("set_tactics", {"attack": second, "defense": app.model.tactics.defense}), "Second clic mis en file, pas refusé")
	check(str(app.model.tactics.attack) == second, "Second choix affiché tout de suite")
	await wait_engine()
	check(app.bridge.last_response_ok and str(app.model.tactics.attack) == second and str(app.bridge.model.tactics.attack) == second, "Les deux choix appliqués dans l'ordre")
	check(close_dialogs() == 0, "Aucune fenêtre de refus pour deux clics rapprochés (%d avant)" % dialogs)
	# Refus du moteur : suivre son propre club est refusé ; la liste affichée d'avance revient à celle du moteur.
	var own := int(app.model.get("club", {}).get("id", 0))
	var before: Array = app.model.get("clubLife", {}).get("clubSheet", {}).get("followed", [])
	check(app._command("club_follow", {"club": own, "follow": true}), "Décision refusée envoyée")
	var shown: Array = app.model.get("clubLife", {}).get("clubSheet", {}).get("followed", [])
	check(shown.any(func(v: Variant) -> bool: return int(v) == own), "Bascule affichée avant la réponse")
	await wait_engine()
	var after: Array = app.model.get("clubLife", {}).get("clubSheet", {}).get("followed", [])
	check(not app.bridge.last_response_ok, "Le moteur refuse de suivre son propre club")
	check(after == before and is_same(app.model, app.bridge.model), "Refus : la bascule est annulée (modèle confirmé)")
	check(close_dialogs() == 1, "Refus : fenêtre habituelle « Ta décision n'a pas été appliquée »")

## Sections reprises sans copie : un instantané différentiel = un instantané complet.
func integrity() -> void:
	for target: String in ECRANS:
		app._navigate(target)
		await settle(2)
	await command("auto_lineup")
	await command("snapshot")
	var incremental := JSON.stringify(app.model)
	check(not app.bridge.last_full_model, "Instantané différentiel (patch)")
	app.bridge._base_revision = -999
	await command("snapshot")
	check(app.bridge.last_full_model, "Instantané complet (révision perdue)")
	check(JSON.stringify(app.model) == incremental, "Modèle appliqué par sections identique au modèle complet")

## Fiche club : cache par club, suivi sans relecture.
func club_sheet() -> void:
	var own := int(app.model.get("club", {}).get("id", 0))
	var others: Array = []
	for division: Dictionary in app.model.get("leagues", []):
		for row: Dictionary in division.get("rows", []):
			if int(row.get("id", -1)) != own and others.size() < 2: others.append(int(row.id))
	check(others.size() == 2, "Deux autres clubs au classement")
	if others.size() < 2: return
	for id: int in others:
		check(app.navigation_controller.open_entity({"kind": "club", "id": str(id)}), "Fiche du club %d ouverte" % id)
		await settle(2)
		await wait_engine()
		var page := app.find_child("FicheClub", true, false)
		check(page != null and page.find_child("ClubSheetLoading", true, false) == null, "Fiche du club %d remplie" % id)
	# Retour sur le premier club : aucune commande moteur, fiche aussitôt remplie.
	var sent: String = app.last_command
	var opened := Time.get_ticks_usec()
	check(app.navigation_controller.open_entity({"kind": "club", "id": str(others[0])}), "Retour sur la première fiche")
	await settle(2)
	mesures["fiche_club_retour_ms"] = (Time.get_ticks_usec() - opened) / 1000.0
	var page := app.find_child("FicheClub", true, false)
	check(not app.waiting and app.last_command == sent, "Seconde ouverture le même jour : aucun aller-retour moteur")
	check(page != null and page.find_child("ClubSheetLoading", true, false) == null, "Seconde ouverture : fiche remplie aussitôt")
	if page == null: return
	var follow := page.find_child("ClubSheetFollow", true, false) as Button
	check(follow != null and follow.text == "Suivre le club", "Club pas encore suivi")
	if follow == null: return
	follow.pressed.emit()
	await process_frame
	page = app.find_child("FicheClub", true, false)
	check(page != null and page.find_child("ClubSheetLoading", true, false) == null, "Suivre : la fiche reste affichée")
	follow = page.find_child("ClubSheetFollow", true, false) as Button if page != null else null
	check(follow != null and follow.text == "Ne plus suivre", "Suivre : bascule affichée dès le clic")
	await wait_engine()
	check(app.bridge.last_response_ok and app.last_command == "club_follow", "Suivi confirmé sans relire la fiche (" + app.last_error + ")")
	var followed: Array = app.bridge.model.get("clubLife", {}).get("clubSheet", {}).get("followed", [])
	check(followed.any(func(v: Variant) -> bool: return int(v) == others[0]), "Club suivi enregistré par le moteur")

## Règles du choix après une réponse (table d'essai, sans moteur).
const RULE_DATA := {"toujours_complet": ["Accueil"], "sections": {"meta.autosave": {"ecrans": []}, "clubLife.clubSheet": {"ecrans": ["Fiche club"]}, "decisions.delegation": {"ecrans": ["Staff"]}}}
const RULE_MODEL := {"meta": {"calendarToday": "2026-07-01"}}

func rule(route: String, rendered: Dictionary, changes: Dictionary, full := false) -> String:
	return ScreenRefresh.plan(route, rendered, ScreenRefresh.stamp(11, route, false, RULE_MODEL, "", false), changes, full, RULE_DATA)

func plan_rules() -> void:
	var shown := ScreenRefresh.stamp(11, "Classements", false, RULE_MODEL, "", false)
	check(rule("Classements", shown, {}) == ScreenRefresh.NONE, "Règle : rien de changé, écran gardé")
	check(rule("Classements", shown, {"meta": {"autosave": true}, "clubLife": {"clubSheet": true}}) == ScreenRefresh.NONE, "Règle : sections non lues par l'écran, écran gardé")
	check(rule("Staff", ScreenRefresh.stamp(11, "Staff", false, RULE_MODEL, "", false), {"decisions": {"delegation": true}}) == ScreenRefresh.FULL, "Règle : section lue par l'écran, rendu complet")
	check(rule("Classements", shown, {"squad": true}) == ScreenRefresh.FULL, "Règle : section inconnue, rendu complet")
	check(rule("Classements", shown, {"meta": {}}) == ScreenRefresh.FULL, "Règle : sous-section retirée, rendu complet")
	check(rule("Classements", shown, {}, true) == ScreenRefresh.FULL, "Règle : réponse complète, rendu complet")
	check(rule("Classements", ScreenRefresh.stamp(11, "Classements", true, RULE_MODEL, "", false), {}) == ScreenRefresh.FULL, "Règle : écran construit pendant l'attente, rendu complet")
	check(rule("Classements", ScreenRefresh.stamp(11, "Classements", false, {"meta": {"calendarToday": "2026-06-30"}}, "", false), {}) == ScreenRefresh.FULL, "Règle : autre jour, rendu complet")
	check(rule("Classements", ScreenRefresh.stamp(11, "Club", false, RULE_MODEL, "", false), {}) == ScreenRefresh.FULL, "Règle : autre écran, rendu complet")
	check(rule("Classements", ScreenRefresh.stamp(12, "Classements", false, RULE_MODEL, "", false), {}) == ScreenRefresh.FULL, "Règle : écran remplacé, rendu complet")
	check(rule("Classements", ScreenRefresh.stamp(11, "Classements", false, RULE_MODEL, "", false, true), {}) == ScreenRefresh.FULL, "Règle : voyant d'alerte différent, rendu complet")
	check(rule("Accueil", ScreenRefresh.stamp(11, "Accueil", false, RULE_MODEL, "", false), {}) == ScreenRefresh.FULL, "Règle : écran toujours complet")
	check(ScreenRefresh.edit_ids([[["clubLife", "clubSheet", "followed"], []], [["tactics", "attack"], "x"]]) == ["clubLife.clubSheet", "tactics"], "Règle : sections des retouches optimistes")
	check(ScreenRefresh.table().get("sections", {}).has("meta.autosave"), "Table du jeu chargée (res://ui/screen_refresh.json)")

## Signature de l'écran affiché : par position dans l'arbre, type, textes, boutons grisés ou enfoncés (éléments
## visibles seulement).
func signature() -> Array:
	var lines: Array = []
	if is_instance_valid(app.root_content): sign_tree(app.root_content, "", lines)
	return lines

func sign_tree(node: Node, path: String, lines: Array) -> void:
	for index in node.get_child_count():
		var child := node.get_child(index)
		if child is CanvasItem and not (child as CanvasItem).visible: continue
		var here := "%s/%d" % [path, index]
		var line := here + " " + child.get_class()
		if child is Label: line += " «%s»" % (child as Label).text
		elif child is RichTextLabel: line += " «%s»" % (child as RichTextLabel).get_parsed_text()
		elif child is LineEdit: line += " «%s»%s" % [(child as LineEdit).text, "" if (child as LineEdit).editable else " lecture"]
		elif child is Button: line += " «%s»" % (child as Button).text
		if child is BaseButton: line += "%s%s" % [" grisé" if (child as BaseButton).disabled else "", " enfoncé" if (child as BaseButton).button_pressed else ""]
		lines.append(line)
		sign_tree(child, here, lines)

## Signature une fois l'écran stable (lignes progressives, chargements différés).
func stable_signature() -> Array:
	var previous := signature()
	for attempt in 30:
		await settle(3)
		var current := signature()
		if current == previous: return current
		previous = current
	return previous

## Lignes présentes d'un côté seulement (multiensemble).
func differences(a: Array, b: Array) -> Dictionary:
	var counts := {}
	for line: String in a: counts[line] = int(counts.get(line, 0)) + 1
	for line: String in b: counts[line] = int(counts.get(line, 0)) - 1
	var result := {}
	for line: String in counts:
		if int(counts[line]) != 0: result[line] = true
	return result

## L'écran affiché (gardé) est identique à un rendu complet du même modèle ; les lignes qui changent d'un rendu
## complet à l'autre (animations, horloge) sont écartées.
func same_as_full_render(label: String) -> void:
	var shown: Array = await stable_signature()
	app._render(false)
	var full: Array = await stable_signature()
	app._render(false)
	var again: Array = await stable_signature()
	var noise := differences(full, again)
	var real: Array = differences(shown, full).keys().filter(func(line: String) -> bool: return not noise.has(line))
	check(not shown.is_empty() and real.is_empty(), "%s : écran gardé identique au rendu complet (%d ligne(s), écarts : %s)" % [label, shown.size(), " | ".join(real.slice(0, 4))])

func last_render_ms(log_size: int) -> float:
	return float(app.timing_log[-1].get("rendu_ms", 0.0)) if app.timing_log.size() > log_size else -1.0

## Rafraîchissement par écran sur 10 écrans : « Sauvegarder » (barre latérale, tout écran ; seul l'état du journal
## change) mesuré avec le rendu complet (témoin) puis par écran ; « Suivre un club » (décision optimiste lue par la
## seule fiche club) sans aucun rendu ; une décision lue par l'écran le redessine.
func refresh_screens() -> void:
	var avant: Array = []
	var apres: Array = []
	var suivi_rendus := {"avant": 0, "apres": 0}
	var own := int(app.model.get("club", {}).get("id", 0))
	var other := -1
	for division: Dictionary in app.model.get("leagues", []):
		for row: Dictionary in division.get("rows", []):
			if other < 0 and int(row.get("id", -1)) != own: other = int(row.id)
	for target: String in ECRANS:
		app._navigate(target)
		await settle(4)
		check(app.route == target, "Écran ouvert : " + target)
		if app.route != target: continue
		# Témoin : rendu complet à chaque réponse (comportement d'avant).
		app.refresh_by_screen = false
		var log_size: int = app.timing_log.size()
		await command("save")
		check(app.last_refresh == ScreenRefresh.FULL, "%s : témoin en rendu complet" % target)
		avant.append(last_render_ms(log_size))
		app.refresh_by_screen = true
		await settle(2)
		var renders: int = app.screen_renders
		var content: Node = app.root_content
		log_size = app.timing_log.size()
		await command("save")
		apres.append(last_render_ms(log_size))
		check(app.last_refresh == ScreenRefresh.NONE and app.screen_renders == renders and app.root_content == content, "%s : sauvegarde sans section lue, écran gardé (%s, %d rendu(s), sections %s)" % [target, app.last_refresh, app.screen_renders - renders, str(app.bridge.last_changes.keys())])
		await same_as_full_render(target + " après sauvegarde")
		# Décision optimiste lue par la seule fiche club : témoin (deux rendus), puis aucun.
		if other >= 0 and target in ["Bureau", "Classements", "Staff"]:
			for mode: String in ["avant", "apres"]:
				app.refresh_by_screen = mode == "apres"
				await settle(2)
				renders = app.screen_renders
				var followed: Array = app.model.get("clubLife", {}).get("clubSheet", {}).get("followed", [])
				var follow := not followed.any(func(v: Variant) -> bool: return int(v) == other)
				await command("club_follow", {"club": other, "follow": follow})
				suivi_rendus[mode] += app.screen_renders - renders
			check(app.last_refresh == ScreenRefresh.NONE, "%s : suivi d'un club sans rendu de l'écran (%s)" % [target, app.last_refresh])
			await same_as_full_render(target + " après suivi d'un club")
	app.refresh_by_screen = true
	# Décision lue par l'écran : niveau adverse sur Préparation, toujours redessiné.
	app._navigate("Préparation")
	await settle(4)
	var level: Dictionary = app.model.get("decisions", {}).get("difficulty", {})
	var options: Array = level.get("options", [])
	if level.get("available", false) and options.size() >= 2:
		var wanted := str(options[0].id) if str(options[0].id) != str(level.get("selected", "")) else str(options[1].id)
		var renders: int = app.screen_renders
		await command("set_opponent_level", {"level": wanted})
		check(app.last_refresh == ScreenRefresh.FULL and app.screen_renders > renders, "Préparation : niveau adverse redessiné (%s)" % app.last_refresh)
		await same_as_full_render("Préparation après niveau adverse")
	else: check(false, "Niveau adverse disponible sur une carrière neuve")
	var mesures_avant := avant.filter(func(v: float) -> bool: return v >= 0.0)
	var mesures_apres := apres.filter(func(v: float) -> bool: return v >= 0.0)
	check(mesures_avant.size() == ECRANS.size() and mesures_apres.size() == ECRANS.size(), "Mesures CD_TIMING de la sauvegarde (%d/%d)" % [mesures_avant.size(), mesures_apres.size()])
	mesures["sauvegarde_rendu_ms"] = {"avant_mediane": median(mesures_avant), "apres_mediane": median(mesures_apres), "avant": mesures_avant, "apres": mesures_apres}
	mesures["suivi_club_rendus"] = suivi_rendus
