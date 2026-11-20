extends SceneTree
## Finitions critiques (carrière Monde, club de Champ Rugby), dans le vrai jeu et le vrai moteur :
##  1. fiche joueur, Performances : « MOYENNE SAISON · N matchs » tient sur une ligne ; la compétition est le nom
##     lisible du championnat (pas « Champ Rugby », nom interne du registre) ;
##  3. Gabi : le voile assombri n'est posé que pour un vrai moment clé et jamais sur un écran de décision ;
##  4. panneau « Continuer » : titre annonçant l'arrêt attendu, barre qui suit l'avance vers cet arrêt ;
##  5. alerte fatigue : version courte (« 9 titulaires sous 70 % — je propose 6 changements ») et détail dépliable ;
##  6. carte « État du groupe » du Bureau : même source que l'alerte (selection.fatigue) ;
##  7. calendrier : « Prochains rendez-vous publiés » entièrement atteignable au défilement.
## Captures (rendu graphique) : CD_FINITIONS_CAPTURE=<préfixe de chemin>. Sauvegarde : CD_FINITIONS_SAUVEGARDE.
const Avis = preload("res://guide/gabi_avis.gd")
const Continue = preload("res://ui/continue_progress.gd")
const Rooms = preload("res://qa_runner.gd")
const P = preload("res://ui/immersive08/projection.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_prefix := OS.get_environment("CD_FINITIONS_CAPTURE")

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle(frames: int = 12) -> void:
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

# ---- 1 : fiche joueur, Performances -------------------------------------------------------------------------------

func fiche_joueur() -> void:
	var joueurs: Dictionary = app.model.get("clubLife", {}).get("matchNotes", {}).get("joueurs", {})
	var choisi := ""
	var plus := -1
	for id: String in joueurs:
		var historique: Array = joueurs[id].get("historique", [])
		if historique.size() > plus and not historique.is_empty(): choisi = id; plus = historique.size()
	check(choisi != "", "Un joueur avec au moins un match noté")
	if choisi == "": return
	app._navigate("Effectif")
	await settle(24)
	app.selected_player = choisi
	app.management_ui.immersive_player_tab = 2
	app.set_meta("immersive08_full_player", true)
	app._render()
	await settle(30)
	print("DIAG fiche : route=", app.route, " joueur=", choisi, " historique=", plus, " lignes=", app.find_children("PlayerMatchRow*", "", true, false).size())
	var legende := app.find_child("FullPlayerNoteMatches", true, false) as Label
	check(legende != null, "Légende de la moyenne de saison")
	if legende != null:
		var police := legende.get_theme_font("font")
		var taille := legende.get_theme_font_size("font_size")
		var largeur := police.get_string_size(legende.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		check(legende.get_line_count() == 1, "« %s » tient sur une seule ligne (%d lignes)" % [legende.text, legende.get_line_count()])
		check(largeur <= legende.size.x + 1.0, "Texte entier visible : %.0f px de texte pour %.0f px de largeur" % [largeur, legende.size.x])
		# En 1280×720 la police ne descend pas sous 12 px : la forme courte remplace le libellé entier.
		check(legende.text in ["MOYENNE SAISON", "MOY. SAISON"], "Libellé de la moyenne : " + legende.text)
		if app.get_window().size.x >= 1600: check(legende.text == "MOYENNE SAISON", "Libellé complet à grande taille : " + legende.text)
	var compte := app.find_child("FullPlayerNoteCount", true, false) as Label
	check(compte != null and compte.text.ends_with("match") or compte != null and compte.text.ends_with("matchs"), "Nombre de matchs sur sa ligne : " + (compte.text if compte != null else "absent"))
	if compte != null:
		var largeur_compte := compte.get_theme_font("font").get_string_size(compte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, compte.get_theme_font_size("font_size")).x
		check(largeur_compte <= compte.size.x + 1.0, "Nombre de matchs entier visible")
	var ligues := {}
	for ligue: Dictionary in app.model.get("leagues", []): ligues[str(ligue.id)] = str(ligue.name)
	var vus := 0
	for ligne in app.find_children("PlayerMatchRow*", "", true, false):
		for enfant in ligne.get_children():
			if enfant is Label and not (enfant.text.begins_with("S") and enfant.text.length() < 5):
				if enfant.text == "Champ Rugby": check(false, "Compétition « Champ Rugby » affichée (nom interne)")
		vus += 1
	check(vus > 0, "Lignes d'historique affichées (%d)" % vus)
	var nom := str(ligues.get("champ", ""))
	check(nom != "" and nom != "Champ Rugby", "Le championnat a un nom lisible : « %s »" % nom)
	var trouve := false
	for ligne in app.find_children("PlayerMatchRow*", "", true, false):
		if texts(ligne).contains(nom): trouve = true
	check(trouve, "La colonne compétition affiche « %s »" % nom)
	await capture("fiche-performances")
	# Vue d'ensemble en petite fenêtre : le bouton « Proposer une prolongation » du Contrat est entièrement visible.
	app.management_ui.immersive_player_tab = 0
	app._render()
	await settle(30)
	var offre := app.find_child("OfferRenewal", true, false) as Control
	var fiche := app.find_child("ImmersivePlayerFull", true, false) as Control
	check(offre != null and fiche != null, "Vue d'ensemble de la fiche avec son bouton de contrat")
	if offre != null and fiche != null and app.get_window().size.y <= 800:
		var defilement: Node = fiche.get_parent()
		while defilement != null and not defilement is ScrollContainer: defilement = defilement.get_parent()
		if defilement != null:
			var zone := (defilement as Control).get_global_rect()
			check(zone.grow(1).encloses(offre.get_global_rect()), "Bouton de contrat entièrement visible sans défiler (%s dans %s)" % [offre.get_global_rect(), zone])
	app.set_meta("immersive08_full_player", false)

# ---- 3 : Gabi, voile -----------------------------------------------------------------------------------------------

func gabi_voile() -> void:
	var coach = app.coach
	check(coach != null, "Gabi présent")
	if coach == null: return
	# Écran de composition, moment clé « arrivée au club » encore jamais vu : pas de voile, un simple indice.
	coach.profile.data.events.clear()
	coach.profile.data.seen.clear()
	coach.close()
	coach._attente.clear()
	coach._contexte_examine = ""
	app._navigate("Composition")
	await settle(24)
	coach.consider_context("Composition", app.model, "", true)
	await settle(12)
	var voile := app.find_child("GabiVoile", true, false) as Control
	check(not coach.expanded, "Composition : Gabi ne passe pas en grand")
	check(voile == null or not voile.visible, "Composition : aucun voile assombri")
	var prevu: bool = str(coach._attente.get("event", "")).begins_with("debut:") or (coach._bulle.visible and str(coach._contenu.get("event", "")).begins_with("debut:"))
	check(prevu, "Composition : le moment clé est dit dans le bandeau (indice ou bulle) : " + str(coach._attente.get("event", "")))
	check(not coach._bulle.visible, "Composition : pas de bulle ouverte d'office sur un écran de décision")
	await capture("gabi-composition-sans-voile")
	# Fiche joueur (Effectif) : pas de voile non plus, le moment clé reste en attente dans le bandeau.
	coach._attente.clear()
	coach.profile.data.events.clear()
	coach.close()
	coach._contexte_examine = ""
	app._navigate("Effectif")
	await settle(20)
	coach.consider_context("Effectif", app.model, "", true)
	await settle(10)
	var voile_effectif := app.find_child("GabiVoile", true, false) as Control
	check(not coach.expanded and (voile_effectif == null or not voile_effectif.visible), "Effectif : aucun voile assombri")
	# Bureau, même moment clé : le grand mode (voile) est permis.
	coach._attente.clear()
	coach.profile.data.events.clear()
	coach.close()
	coach._contexte_examine = ""
	app._navigate("Bureau")
	await settle(24)
	coach.consider_context("Bureau", app.model, "", true)
	await settle(14)
	var voile_bureau := app.find_child("GabiVoile", true, false) as Control
	check(coach.expanded and voile_bureau != null and voile_bureau.visible, "Bureau : l'arrivée au club garde son moment clé (voile)")
	await capture("gabi-bureau-moment-cle")
	coach.close()
	await settle(10)
	# Une fenêtre de décision ouverte interdit le grand mode même au Bureau.
	var dialogue := ConfirmationDialog.new()
	app.add_child(dialogue)
	dialogue.popup_centered()
	await settle(4)
	check(not coach._grand_permis(), "Fenêtre ouverte : pas de grand mode")
	dialogue.queue_free()
	await settle(4)
	check(coach._grand_permis(), "Fenêtre fermée au Bureau : grand mode permis")

# ---- 4 : panneau Continuer ------------------------------------------------------------------------------------------

func continuer() -> void:
	var panneau := Continue.new()
	root.add_child(panneau)
	panneau.size = Vector2(1920, 1080)
	panneau.begin({"date": "2026-09-01", "accent": Color("d43e47"), "next": {"date": "2026-09-11", "opponent": "Stade Test"}}, false)
	await settle(6)
	# Maquette « L'ovale du ballon » : le titre est fixe, l'arrêt attendu est écrit dans « Arrêt prévu » et le surtitre.
	check(panneau.title.text == "Passage au jour suivant…", "Titre de la maquette : " + panneau.title.text)
	check(panneau.detail.text.begins_with("Arrêt prévu : ") and panneau.detail.text.contains("match contre Stade Test"), "Arrêt prévu : l'arrêt attendu : " + panneau.detail.text)
	check(panneau.kicker.text == "CONTINUER · jusqu’au match", "Surtitre : " + panneau.kicker.text)
	check(not panneau.title.text.contains("défilent"), "Plus de « Les jours défilent… »")
	check(is_equal_approx(panneau.bar.value, 0.0), "Barre au départ : %.2f" % panneau.bar.value)
	panneau.advance_to({"today": "2026-09-06", "days": 5, "next": {"date": "2026-09-11", "opponent": "Stade Test"}})
	check(absf(panneau.bar.value - 0.5) < 0.01, "Barre à mi-chemin (5 jours sur 10) : %.2f" % panneau.bar.value)
	await capture("continuer-match")
	# Le moteur annonce un arrêt plus proche (rendez-vous) : le titre et la barre le suivent.
	panneau.advance_to({"today": "2026-09-07", "days": 6, "next": {"date": "2026-09-11", "opponent": "Stade Test"}, "plan": {"kind": "rendez_vous", "date": "2026-09-09", "detail": "Point médical"}})
	check(panneau.detail.text.contains("rendez-vous : point médical") and panneau.kicker.text.begins_with("CONTINUER · jusqu’au rendez-vous"), "Arrêt prévu : rendez-vous annoncé : " + panneau.detail.text)
	check(absf(panneau.bar.value - 0.75) < 0.01, "Barre vers le rendez-vous (6 jours sur 8) : %.2f" % panneau.bar.value)
	await capture("continuer-rendez-vous")
	panneau.dismiss()
	panneau.queue_free()

# ---- 5 et 6 : alerte fatigue et carte État du groupe --------------------------------------------------------------

func fatigue() -> void:
	var donnees := Avis.fatigue_donnees(app.model)
	check(not donnees.is_empty(), "Le moteur signale des titulaires sous 70 %")
	if donnees.is_empty(): return
	var nombre: int = (donnees.starters as Array).size()
	var avis := Avis.fatigue(app.model)
	var court := str(avis.get("texte", ""))
	check(court.begins_with("%d titulaire" % nombre) and court.contains("sous 70 %") and court.contains("— je propose"), "Alerte courte : " + court)
	check(court.length() <= 110, "Alerte courte (%d caractères)" % court.length())
	var plus := str(avis.get("plus", ""))
	check(plus.length() > court.length() and plus.contains("%"), "Détail complet séparé : " + plus)
	check(Avis.fatigue_resume(app.model).count == nombre, "Résumé : même nombre que l'alerte (%d)" % nombre)
	var coach = app.coach
	app._navigate("Bureau")
	await settle(20)
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · FATIGUE", "route": "Bureau", "partout": true})
	coach._montrer(message)
	await settle(14)
	check(coach._bulle.visible and coach._bulle_texte.text == court, "Bulle : version courte seule")
	var detail := coach._bulle_detail as Label
	check(detail != null and not detail.visible, "Détail replié par défaut")
	check(coach._bulle_texte.tooltip_text == plus, "Détail au survol")
	var deplier := coach._bulle.find_child("GabiBulleDeplier", true, false) as Button
	check(deplier != null, "Bouton « Détail »")
	await capture("gabi-fatigue-courte")
	if deplier != null:
		deplier.pressed.emit()
		await settle(10)
		check(detail.visible and detail.text == plus, "Détail déplié")
		await capture("gabi-fatigue-detail")
		deplier.pressed.emit()
		await settle(6)
		check(not detail.visible, "Détail replié de nouveau")
	coach.fermer_bulle()
	# Carte « État du groupe » : jamais « Aucune alerte physique » avec des titulaires sous 70 %.
	await settle(10)
	var groupe := app.find_child("OfficeSquadAction", true, false)
	check(groupe != null, "Carte de l'état du groupe au Bureau")
	var page := app.find_child("OfficeSquadAction", true, false)
	var racine: Node = page
	while racine != null and not (racine is Panel or racine is PanelContainer): racine = racine.get_parent()
	var carte := texts(racine) if racine != null else texts(app)
	check(not carte.contains("Aucune alerte physique"), "Carte du groupe : pas d'« Aucune alerte physique » (%d sous 70 %%)" % nombre)
	check(carte.contains("%d titulaire" % nombre) and carte.contains("sous 70 %"), "Carte du groupe : « %d titulaires du prochain match sous 70 %% » : %s" % [nombre, carte.replace("\n", " | ")])
	await capture("bureau-etat-groupe")
	# Sans alerte du moteur : l'ancien message revient seulement quand rien n'est à signaler.
	var sans: Dictionary = app.model.duplicate(true)
	sans.selection.erase("fatigue")
	check(Avis.fatigue_resume(sans).count == 0, "Sans selection.fatigue : zéro titulaire")

# ---- 7 : calendrier ------------------------------------------------------------------------------------------------

func calendrier() -> void:
	app._navigate("Calendrier")
	await settle(30)
	var scroll := app.find_child("CalendarProgramScroll", true, false) as ScrollContainer
	var panneau := app.find_child("CalendarUpcomingContext", true, false) as Control
	check(scroll != null and panneau != null, "Calendrier : défilement et panneau « Prochains rendez-vous publiés »")
	if scroll == null or panneau == null: return
	# Le panneau est fixe sous le planning (hors du défilement) ou, à défaut, entier dans la zone défilante.
	var fenetre := Rect2(Vector2.ZERO, Vector2(root.size))
	var rect := panneau.get_global_rect()
	check(fenetre.encloses(rect), "Panneau entier dans la fenêtre : %s pour %s" % [str(rect), str(fenetre)])
	if scroll.is_ancestor_of(panneau):
		scroll.scroll_vertical = 0
		await settle(6)
		check(panneau.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "Panneau entier dans la zone défilante")
	else:
		check(rect.position.y >= scroll.get_global_rect().end.y - 1.0, "Panneau fixe sous le planning, sans recouvrement (haut %.0f, bas du planning %.0f)" % [rect.position.y, scroll.get_global_rect().end.y])
	var barre := scroll.get_v_scroll_bar()
	check(barre.max_value > barre.page or scroll.get_global_rect().size.y > 200.0, "Le planning garde une zone lisible (%.0f px)" % scroll.get_global_rect().size.y)
	await capture("calendrier-haut")
	scroll.scroll_vertical = int(barre.max_value)
	await capture("calendrier-bas")
	scroll.scroll_vertical = 0
	# Vue semaine : même exigence.
	var semaine := app.find_child("CalendarViewWeek", true, false)
	print("DIAG semaine : bouton=", semaine)

func run() -> void:
	create_timer(1200.0).timeout.connect(func():
		failures.append("délai dépassé (1200 s)")
		fin())
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	var fichier := OS.get_environment("CD_FINITIONS_SAUVEGARDE")
	app._command("import", {"text": FileAccess.get_file_as_string(fichier)})
	await wait_engine()
	app.timer.stop()
	check(app.model.get("club") is Dictionary and str(app.model.get("meta", {}).get("mode")) == "world", "Carrière Monde importée")
	check(str(app.model.get("meta", {}).get("leagueId", "")) == "champ", "Club de Champ Rugby")
	for phase in ["fiche_joueur", "gabi_voile", "continuer", "fatigue", "calendrier"]:
		print("PHASE ", phase)
		await call(phase)
	fin()

func fin() -> void:
	var out := OS.get_environment("CD_FINITIONS_OUTPUT")
	if not out.is_empty():
		var report := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
		report.close()
	print("FINITIONS %d controles, %d echec%s" % [checks, failures.size(), "s" if failures.size() > 1 else ""])
	app.closing = true
	app.bridge.stop()
	quit(1 if failures.size() > 0 else 0)
