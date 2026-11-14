extends SceneTree
## Retouches de cohérence (carrière Monde), dans le vrai jeu et le vrai moteur :
##  1. fiche club, XV type : aucun titulaire du XV type dans « remplaçants les plus utilisés » ;
##  2. fiche club, « Vos confrontations » : prochain match entre les deux clubs (date, lieu, compétition) ;
##  3. Bureau, carnet de Gabi : la ligne « groupe » suit l'alerte fatigue (même source) ;
##  4. délégation : bouton « Déléguer le match » actif sur une feuille à 22, confirmation du match à 22 ;
##  5. finances : « Formation » n'est plus à 0 % dans la répartition des charges ;
##  6. calendrier : une bande de période pour « en sélection », bandeau « prochain match dans N jours ».
## Captures (rendu graphique) : CD_RETOUCHES_CAPTURE=<préfixe de chemin>. Sauvegarde à 22 : CD_RETOUCHES_SAUVEGARDE.
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const Semaine = preload("res://guide/gabi_semaine.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Finance = preload("res://ui/immersive08/finance_canvas.gd")
const Dialogue = preload("res://ui/delegation_dialog.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Rooms = preload("res://qa_runner.gd")
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_prefix := OS.get_environment("CD_RETOUCHES_CAPTURE")

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames: int = 12) -> void:
	# Rendu graphique lent (llvmpipe) : une courte durée réelle en plus des images.
	if DisplayServer.get_name() != "headless": await create_timer(.4).timeout
	for i in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Vraie réponse du moteur : " + str(app.last_error))
	await settle()

func capture(name: String) -> void:
	await settle(16)
	if DisplayServer.get_name() == "headless" or capture_prefix.is_empty(): return
	check(root.get_texture().get_image().save_png(capture_prefix + name + ".png") == OK, "Capture " + name)

func texts(node: Node) -> String:
	var parts: Array[String] = []
	for child: Node in node.find_children("*", "", true, false):
		if not (child is Control) or not child.is_visible_in_tree(): continue
		if child is Label and str(child.text).strip_edges() != "": parts.append(str(child.text))
		elif child is Button and str(child.text).strip_edges() != "": parts.append(str(child.text))
	return "\n".join(parts)

# ---- 1 et 2 : fiche club ------------------------------------------------------------------------------------------

func fiche_club() -> void:
	var own := int(app.model.club.id)
	var opponent := -1
	for fixture: Variant in app.model.get("calendar", []):
		if not fixture is Dictionary: continue
		var home := int(fixture.get("home", {}).get("id", -1))
		var away := int(fixture.get("away", {}).get("id", -1))
		if home == own and away != own: opponent = away; break
		if away == own and home != own: opponent = home; break
	check(opponent >= 0, "Un adversaire du calendrier du club")
	ClubSheet.open(app, opponent)
	await settle(4)
	var limite := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < limite and (app.waiting or app.find_child("FicheClub", true, false) == null or app.find_child("ClubSheetLoading", true, false) != null): await process_frame
	await wait_engine()
	var page := app.find_child("FicheClub", true, false) as Control
	check(page != null and app.route == ClubSheet.ROUTE, "Fiche du club adverse affichée")
	if page == null: return
	var data: Dictionary = page.data
	var head: Dictionary = data.get("headToHead", {})
	check(int(head.get("played", 0)) == 0 and head.get("upcoming") is Dictionary, "Aucune confrontation passée : le moteur publie le prochain match entre les deux clubs")
	var panel := page.find_child("ClubSheetHeadToHead", true, false) as Control
	check(panel != null, "Panneau « Vos confrontations »")
	if panel != null:
		var text := texts(panel)
		check(text.contains("PROCHAINE CONFRONTATION"), "Vos confrontations : annonce la prochaine confrontation : " + text.replace("\n", " | "))
		var upcoming: Dictionary = head.get("upcoming", {})
		check(text.contains("À domicile" if upcoming.get("home", false) else "À l’extérieur"), "Vos confrontations : lieu (domicile ou extérieur)")
		check(text.contains(ClubSheet._date(upcoming.get("date"))), "Vos confrontations : date du match")
		check(not text.contains("date à fixer"), "Vos confrontations : date connue")
		var competition: String = preload("res://ui/club_views.gd").competition_name(str(upcoming.get("competitionId", "")), app.model)
		check(competition != "" and text.contains(competition), "Vos confrontations : compétition « %s »" % competition)
	await capture("fiche-confrontations")
	# Sans prochain match : une phrase utile courte.
	var vide := ClubSheet.new()
	vide.app = app
	var cadre := Panel.new()
	root.add_child(cadre)
	vide._upcoming_meeting(cadre, null)
	var phrase := texts(cadre)
	check(phrase.contains("Aucune confrontation enregistrée") and phrase.contains("Aucun match prévu entre ces deux clubs"), "Sans prochain match : phrase utile : " + phrase.replace("\n", " | "))
	root.remove_child(cadre)
	cadre.queue_free()
	vide.free()
	# XV type : le banc n'a aucun titulaire du XV type (données du moteur, puis texte affiché).
	var onglet := page.find_child("ClubSheetTab2", true, false) as Button
	if onglet != null: onglet.pressed.emit()
	await settle(10)
	page = app.find_child("FicheClub", true, false) as Control
	var xv: Dictionary = page.data.get("xv", {})
	var titulaires := {}
	for slot: Dictionary in xv.get("slots", []):
		if slot.get("id") != null: titulaires[str(slot.id)] = true
	var banc: Array = xv.get("bench", [])
	if banc.is_empty(): banc = xv.get("probableBench", []).map(func(id: Variant): return {"id": id})
	check(not banc.is_empty(), "Banc publié (%d joueurs)" % banc.size())
	for entree: Dictionary in banc: check(not titulaires.has(str(entree.get("id", ""))), "Le remplaçant %s n'est pas dans le XV type" % str(entree.get("id", "")))
	var affiches := 0
	for i in 8:
		var lien := page.find_child("ClubSheetBench%d" % i, true, false) as Button
		if lien == null: continue
		affiches += 1
		for slot_i in 15:
			var titulaire := page.find_child("ClubSheetXVName%d" % (slot_i + 1), true, false) as Button
			if titulaire != null: check(titulaire.text != lien.text, "Le banc n'affiche pas le titulaire %s" % lien.text)
	check(affiches > 0, "Banc affiché dans l'onglet XV type")
	await capture("fiche-xv-type")

# ---- 3 : Gabi ---------------------------------------------------------------------------------------------------

func gabi() -> void:
	var model: Dictionary = app.model.duplicate(true)
	check(not Semaine.prochain_match(model).is_empty(), "Une prochaine rencontre pour la synthèse de Gabi")
	var groupe: Dictionary = Semaine._ligne_groupe(model, Semaine.prochain_match(model))
	# Groupe en forme, aucun titulaire fatigué : « Rien d'inquiétant » reste possible.
	model.selection = (model.get("selection", {}) as Dictionary).duplicate(true)
	model.selection.erase("fatigue")
	var ligne_calme: Dictionary = Semaine._ligne_groupe(model, Semaine.prochain_match(model))
	check(not str(ligne_calme.texte).contains("titulaire"), "Sans alerte fatigue : la ligne groupe ne parle pas de titulaires : " + str(ligne_calme.texte))
	# Alerte fatigue du moteur (titulaires sous 70 %) : la ligne « groupe » le dit aussi, même chiffre que l'alerte.
	model.selection.fatigue = {"threshold": 70, "count": 3, "starters": [{"playerId": "a", "condition": 60}, {"playerId": "b", "condition": 62}, {"playerId": "c", "condition": 66}], "changes": []}
	var fixture := Semaine.prochain_match(model)
	var ligne: Dictionary = Semaine._ligne_groupe(model, fixture)
	var alerte: Dictionary = Semaine._ligne_alerte(model, fixture, Semaine.jours_avant(model, fixture))
	var texte := str(ligne.texte)
	check(not texte.contains("Rien d'inquiétant"), "Titulaires fatigués : plus de « Rien d'inquiétant » : " + texte)
	check(texte.contains("3 titulaires de la feuille sous 70 %"), "La ligne groupe cite les 3 titulaires sous 70 % : " + texte)
	check(str(alerte.texte).contains("3 titulaires de la feuille sous 70 %") or not str(alerte.texte).contains("titulaire"), "Alerte voisine : même chiffre : " + str(alerte.texte))
	check(ligne.couleur == Semaine.AMBRE, "Ligne groupe en ambre")
	var synthese := Semaine.synthese(model)
	check(synthese.lignes.size() == 3 and str(synthese.lignes[1].texte) == texte, "Synthèse : la ligne groupe passe par la même fonction")
	# Affichage réel au Bureau avec l'alerte : le carnet est reconstruit sur le modèle projeté enrichi de l'alerte.
	var reel: Dictionary = app.model
	app._navigate("Bureau")
	await settle(20)
	var zone: Control = app.coach._bureau
	check(is_instance_valid(zone), "Bureau : zone de Gabi installée")
	if is_instance_valid(zone):
		app.model = model
		app.coach._semaine = Semaine.synthese(model)
		app.coach._disposer_bureau(zone)
		await settle(10)
		var ligne_groupe := zone.find_child("GabiLigne_groupe", true, false) as Label
		check(ligne_groupe != null and ligne_groupe.text.contains("3 titulaires de la feuille sous 70 %"), "Bureau : la ligne groupe du carnet affiche l'alerte fatigue : " + (ligne_groupe.text if ligne_groupe != null else "absente"))
		check(ligne_groupe != null and not ligne_groupe.text.contains("Rien d'inquiétant"), "Bureau : pas de « Rien d'inquiétant » à côté d'une alerte")
		var ligne_alerte := zone.find_child("GabiLigne_alerte", true, false) as Label
		check(ligne_alerte != null and ligne_alerte.text.contains("3 titulaires"), "Bureau : l'alerte voisine donne le même chiffre : " + (ligne_alerte.text if ligne_alerte != null else "absente"))
		await capture("gabi-bureau")
	app.model = reel
	groupe = {}

# ---- 5 : finances -----------------------------------------------------------------------------------------------

func finances() -> void:
	var finance: Dictionary = app.model.clubLife.clubStrategy.finance
	check(float(finance.get("academyInvestment", -1)) == 0.0, "Départ : aucune formation payée en plus (l'ancienne ligne était à 0 %)")
	var centre := float(finance.get("budget", {}).get("centreFormationHebdo", 0.0))
	check(centre > 0.0, "Le moteur publie le coût réel du centre de formation : %s par semaine" % str(centre))
	var rows: Array = Finance._weekly(finance)
	var formation: Array = rows[1]
	check(str(formation[0]) == "Formation" and float(formation[2]) == centre, "Répartition : la formation vaut le centre (%s)" % str(formation[2]))
	var fonctionnement := float(rows[2][2])
	var total := float(finance.weeklyCosts)
	check(is_equal_approx(float(rows[0][2]) + float(formation[2]) + fonctionnement, total), "Les trois postes font le total des charges hebdomadaires")
	app.management_ui["immersive08_finance_tab"] = "budget"
	app._navigate("Finances")
	await settle(20)
	var allocation := app.find_child("FinanceAllocation", true, false) as Control
	check(allocation != null, "Panneau « Répartition des charges connues »")
	if allocation != null:
		var text := texts(allocation)
		var lignes := text.split("\n")
		var index := lignes.find("Formation")
		check(index >= 0, "Ligne « Formation » affichée")
		if index >= 0:
			var pourcent := ""
			for suivant in range(index + 1, mini(index + 4, lignes.size())):
				if str(lignes[suivant]).ends_with(" %"): pourcent = lignes[suivant]; break
			var attendu := roundi(centre * 100.0 / total)
			check(pourcent == "%d %%" % attendu and attendu > 0, "Formation affichée à %d %% (et non 0 %%) : « %s »" % [attendu, pourcent])
		check(text.contains(Finance.G.euros(centre)), "Formation : montant hebdomadaire " + Finance.G.euros(centre))
	await capture("finances")

# ---- 6 : calendrier ---------------------------------------------------------------------------------------------

func calendrier() -> void:
	app._navigate("Calendrier")
	await settle(24)
	var cal := app.find_child("CarnetCalendar", true, false)
	check(cal != null, "Calendrier présent")
	var marqueurs := app.find_children("CalendarAbsence_*", "PanelContainer", true, false)
	var legendes := 0
	var debuts := 0
	for marqueur: Node in marqueurs:
		if marqueur.get_meta("period_start", false): debuts += 1
		for child: Node in marqueur.get_children():
			if child is Label and str(child.text).contains("en sélection"): legendes += 1
	if marqueurs.is_empty():
		print("INFO : aucune absence dans le mois courant (pas de marqueur à mesurer)")
	else:
		check(legendes == debuts, "Une seule légende par période (%d légendes, %d débuts)" % [legendes, debuts])
		check(legendes < marqueurs.size() or marqueurs.size() == 1, "Moins de légendes que de jours d'absence : %d pour %d jours" % [legendes, marqueurs.size()])
		check(legendes <= 6, "Pas plus d'une légende par semaine affichée (%d)" % legendes)
		var jour: Control = null
		for node: Node in app.find_children("MonthDay_*", "Button", true, false):
			if (node as Button).tooltip_text.contains("en sélection"): jour = node; break
		check(jour != null, "Détail des convocations au survol de la case du jour")
	# Bandeau d'un mois sans rencontre : « prochain match dans N jours (adversaire) ».
	var banniere: String = cal._next_match_banner() if cal != null else ""
	check(banniere.contains("prochain match") and (banniere.contains("dans ") or banniere.contains("demain") or banniere.contains("aujourd’hui")) and banniere.contains("("), "Bandeau sans rencontre : « %s »" % banniere)
	check(not banniere.begins_with("Aucune rencontre programmée"), "Bandeau : plus de « Aucune rencontre programmée » sec")
	# Mois sans match réel : on avance jusqu'à un mois vide du calendrier de la carrière.
	var vide := ""
	for mois in ["2026-07", "2026-08", "2026-12", "2027-07", "2027-08"]:
		if cal != null and not (cal.fixtures as Array).any(func(f: Dictionary): return str(f.get("date", "")).begins_with(mois)): vide = mois; break
	if not vide.is_empty() and cal != null:
		cal.month = vide
		cal.selected = vide + "-15"
		cal._refresh()
		await settle(10)
		var entete := texts(cal)
		check(entete.contains("prochain match") or entete.contains("Prochain match"), "Mois vide (%s) : le bandeau annonce le prochain match" % vide)
	await capture("calendrier")

# ---- 4 : délégation à 22 ----------------------------------------------------------------------------------------

func delegation_a_22() -> void:
	var fichier := OS.get_environment("CD_RETOUCHES_SAUVEGARDE")
	if fichier.is_empty(): return
	app._command("import", {"text": FileAccess.get_file_as_string(fichier)})
	await wait_engine()
	app.timer.stop()
	check(app.model.get("club") is Dictionary and str(app.model.get("meta", {}).get("mode")) == "world", "Carrière Monde importée (feuille à 22)")
	var vacant := P.reduced_bench_number(app.model)
	print("DIAG import : vacant=", vacant, " next=", app.model.get("next") is Dictionary, " jour=", app.model.get("meta", {}).get("calendarToday"), " reduced=", app.model.get("selection", {}).get("reducedBench"), " valid=", app.model.get("selection", {}).get("valid"))
	check(vacant == 17 and app.model.get("next") is Dictionary, "Feuille à 22 : pilier manquant n° 17, jour de match")
	app._navigate("Match")
	await settle(40)
	var bouton := app.find_child("MatchOpenDelegation", true, false) as Button
	check(bouton != null and bouton.is_visible_in_tree(), "Bouton « Déléguer le match » visible")
	if bouton == null: return
	check(not bouton.disabled, "Feuille à 22 : le bouton « Déléguer le match » est actif")
	check(bouton.tooltip_text.contains("22"), "Info-bulle : explique le match à 22 : " + bouton.tooltip_text)
	await capture("delegation-22-avant")
	bouton.pressed.emit()
	await settle(30)
	var dialogue := app.get_node_or_null("MatchDelegationDialog") as ConfirmationDialog
	check(dialogue != null and dialogue.visible, "La fenêtre de délégation s'ouvre")
	if dialogue == null: return
	var info := dialogue.find_child("MatchDelegationReduced", true, false) as Label
	check(info != null and info.text.contains("22") and info.text.contains("n° 17"), "La fenêtre confirme le match à 22 : " + (info.text if info != null else ""))
	check(dialogue.get_ok_button().text == "DÉLÉGUER À 22", "Bouton de confirmation « DÉLÉGUER À 22 »")
	var case_ := dialogue.find_child("MatchDelegationComposition", true, false) as CheckBox
	check(case_ != null and case_.button_pressed, "Case « Confier aussi la composition au staff » cochée")
	await capture("delegation-22")
	dialogue.get_ok_button().pressed.emit()
	var until := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < until:
		await process_frame
		if not app.waiting and app.model.get("live") is Dictionary and app.model.live.get("finished", false): break
	for i in 30: await process_frame
	var live: Variant = app.model.get("live")
	check(live is Dictionary and live.get("finished", false), "Match délégué joué jusqu'au bout à 22")
	check(live is Dictionary and int(live.get("nominationSize", 23)) == 22, "Le match a bien été joué à 22 joueurs")

func run() -> void:
	create_timer(900.0).timeout.connect(func():
		failures.append("délai dépassé (900 s)")
		fin())
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	app._command("new_career", {"mode": "world-champ", "club": 7})
	await wait_engine()
	app.timer.stop()
	if not await Rooms.settle_club_meetings(app, self, check):
		fin()
		return
	print("PHASE fiche_club")
	await fiche_club()
	print("PHASE gabi")
	await gabi()
	print("PHASE finances")
	await finances()
	print("PHASE calendrier")
	await calendrier()
	print("PHASE delegation_a_22")
	await delegation_a_22()
	fin()

func fin() -> void:
	var out := OS.get_environment("CD_RETOUCHES_OUTPUT")
	if not out.is_empty():
		var report := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
		report.close()
	print("RETOUCHES COHERENCE %d controles, %d echec%s" % [checks, failures.size(), "s" if failures.size() > 1 else ""])
	app.closing = true
	app.bridge.stop()
	quit(1 if failures.size() > 0 else 0)
