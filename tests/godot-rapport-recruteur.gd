extends SceneTree
## Rapport du recruteur (option A choisie par Léo le 22/11/2026), Godot réel + worker réel, carrière Monde :
## - lien « Rapport du recruteur → » de la piste choisie → sous-page « recruteur » (retour + Échap) ;
## - lettre de l'avis : « ? » tant que le niveau est inconnu ; connu → lettre du staff sur l'échelle unique E- à S+ (notation
##   façon FM, choix B de Léo : pastille ronde, palier écrit en pilule), rang dans notre effectif ;
## - clic sur la lettre → petite fenêtre visuelle du barème (18 pastilles E- à S+), fermée par ✕ ou Échap ;
## - aucun chiffre de marge de progression : le potentiel est une lettre + une phrase du staff ;
## - clic sur une ligne de la liste comparée → fiche (la piste ou notre joueur) ;
## - tuiles : indemnité et salaire → offre au joueur, note et potentiel → fiche de la piste ;
## - pastilles : transfert (offre au joueur), prêt possible / non (lu dans le moteur, clic = fiche).
## - pastille « Parler à l'agent » → fenêtre de discussion (idée 24) : rien de chiffré, ton À tout prix (moteur), question
##   sur le rôle (caractère de l'agent découvert), « Je vous fais une offre » → offre au joueur avec l'humeur de l'agent.
## Imprime une ligne RAPPORT_RECRUTEUR {checks, failures}. Captures : CD_RAPPORT_RECRUTEUR_CAPTURES=<dossier>.
const Flow = preload("helpers/contextual_flow.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const Rapport = preload("res://ui/immersive08/rapport_recruteur.gd")
const Notation = preload("res://ui/notation_staff.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
var capture_dir := OS.get_environment("CD_RAPPORT_RECRUTEUR_CAPTURES")
var piste_id := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func settle(frames := 6) -> void:
	if DisplayServer.get_name() != "headless": await create_timer(.3).timeout
	for frame in frames: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var until := Time.get_ticks_msec() + 120000
	while (app.waiting or not app.queued_action.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await settle()

func command(id: String, payload: Dictionary = {}) -> bool:
	check(app._command(id, payload), "Commande acceptée · " + id)
	await wait_engine()
	return app.bridge.last_response_ok

func node(name: String) -> Control:
	return app.root_content.find_child(name, true, false) as Control if is_instance_valid(app.root_content) else null

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "Capture " + name)

func page_kind() -> String:
	var etat: Variant = app.management_ui.get("recrutement_page")
	return str(etat.get("kind", "")) if etat is Dictionary else ""

func press(name: String) -> bool:
	var bouton := node(name) as Button
	if bouton == null or bouton.disabled: return false
	bouton.pressed.emit()
	await settle(10)
	return true

func ouvrir_rapport() -> void:
	Pages.ouvrir(app, "recruteur", {"player_id": piste_id})
	await settle(10)

## Texte de lettre du staff : « B », « B/A » ou « ? » (jamais un chiffre).
func est_lettre(t: String) -> bool:
	if t == "?": return true
	if t.is_empty(): return false
	for l in t.split("/"):
		if not l in Notation.LETTRES: return false
	return true

func lettre_de(nom: String) -> String:
	var n := trouver(nom)
	return str(n.get_meta("lettre", "")) if n != null else ""

## Textes visibles (libellés, bulles, noms accessibles) des nœuds de note au poste qui contiennent un chiffre.
func chiffres_note() -> Array:
	var sortie: Array = []
	var noeuds: Array = []
	for motif in ["RapportRecruteurNote*", "BaremeNote*", "RapportRecruteurLettrePoste_*", "AgentNotePoste*"]: noeuds += root.find_children(motif, "", true, false)
	for n: Node in noeuds:
		var textes: Array = []
		if n is Control: textes += [(n as Control).tooltip_text, (n as Control).accessibility_name]
		for l: Node in [n] + n.find_children("*", "", true, false):
			if l is Label and (l as Label).is_visible_in_tree(): textes.append((l as Label).text)
			if l is Button: textes.append((l as Button).accessibility_name)
		for t: String in textes:
			for c in t:
				if c >= "0" and c <= "9": sortie.append(t)
	return sortie

func piste() -> Dictionary:
	for p: Variant in app.model.get("market", []):
		if p is Dictionary and str(p.get("id", "")) == piste_id: return p
	return {}

func run() -> void:
	root.size = Vector2i(2560, 1440) if OS.get_environment("CD_RAPPORT_RECRUTEUR_RESOLUTION") == "2560" else Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 120000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	app.timer.stop()
	await command("new_career", {"mode": "world-champ", "club": 102, "start": "veille"})
	await Flow.settle_club_meetings(app, self, check)
	await moteur_pret()
	await lien_depuis_la_liste()
	await lettre_inconnue()
	await lettre_connue()
	await bareme()
	await lignes()
	await tuiles_et_pastilles()
	await agent()
	await reception_et_fiche()
	await ouvrir_rapport()
	shot("rapport-recruteur-1920x1080")
	finish()

func finish() -> void:
	print("RAPPORT_RECRUTEUR ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

## Chaque piste du marché porte son prêt (moteur) : {possible, reason}.
func moteur_pret() -> void:
	var marche: Array = app.model.get("market", [])
	check(not marche.is_empty(), "Marché non vide")
	for p: Variant in marche:
		var pret: Variant = p.get("loan")
		check(pret is Dictionary and pret.get("possible") is bool and str(pret.get("reason", "")) in ["jeune", "hors-23", "cadre"], "Prêt lu dans le moteur · " + str(p.get("id", "")))
		if pret is Dictionary and int(p.get("age", 99)) <= 23: check(bool(pret.possible), "Prêt possible pour un jeune · " + str(p.get("id", "")))

## Le lien de la piste choisie ouvre la sous-page ; Échap / retour ramènent à la liste.
func lien_depuis_la_liste() -> void:
	app._navigate("Recrutement", false)
	await settle(10)
	if node("OpenRecruiterReport") == null and node("MarketShowAll") != null: await press("MarketShowAll")
	var lien := node("OpenRecruiterReport") as Button
	check(lien != null, "Lien « Rapport du recruteur » sur la piste choisie")
	if lien == null: return
	piste_id = str(app.management_ui.market.get("player_id", ""))
	lien.pressed.emit()
	await settle(10)
	check(page_kind() == "recruteur" and node("RecrutementSubpage_recruteur") != null, "Lien → sous-page Rapport du recruteur")
	check(node("RapportRecruteurNom") != null and str((node("RapportRecruteurNom") as Button).text) == str(piste().get("name", "")), "Le rapport suit la piste choisie")
	check(await press("RecrutementRetour") and page_kind().is_empty(), "Retour : la liste du recrutement")

## Recrue pas encore observée (note au poste jamais publiée) : la piste choisie si elle l'est, sinon une autre du marché
## (de préférence avec une première fourchette de niveau : le cas « à observer » relevé par le vérificateur le 24/11).
func lettre_inconnue() -> void:
	if piste_id.is_empty(): return
	var choisie := piste_id
	var candidate := ""
	var rang_candidate := -1
	for x: Variant in app.model.get("market", []):
		if not x is Dictionary: continue
		var publiees_x: Variant = x.get("positionRatings")
		if publiees_x is Dictionary and not (publiees_x as Dictionary).is_empty(): continue
		var rang := (2 if x.get("ratingRange") is Dictionary else 0) + (1 if str(x.get("id", "")) == choisie else 0)
		if rang > rang_candidate:
			candidate = str(x.get("id", ""))
			rang_candidate = rang
	check(not candidate.is_empty(), "Au moins une recrue du marché sans note au poste publiée")
	if candidate.is_empty(): return
	piste_id = candidate
	var p := piste()
	await ouvrir_rapport()
	var meta: Dictionary = node("RecrutementSubpage_recruteur").get_meta("rapport", {})
	if str(p.get("knowledge", {}).get("stage", "")) == "unobserved":
		check(str(meta.get("lettre", "")) == "?", "Piste non observée : lettre « ? » (%s)" % meta.get("lettre", ""))
		check(node("RapportRecruteurConnaissance") != null, "Pastille de connaissance")
	# Note au poste d'une recrue à observer : lettre ESTIMÉE par le staff (double « B/A ») ou « ? », jamais la vraie valeur.
	var note := lettre_de("RapportRecruteurNoteLettre")
	check(est_lettre(note), "Piste non observée : note au poste en lettre (%s)" % note)
	check(note == "?" or note.contains("/"), "Piste non observée : note au poste incertaine, « ? » ou double (%s)" % note)
	if p.get("ratingRange") is Dictionary and float(p.ratingRange.max) - float(p.ratingRange.min) >= 8.0: check(note.contains("/"), "Fourchette de niveau large : lettre estimée double (%s)" % note)
	check(chiffres_note().is_empty(), "Piste non observée : aucun chiffre de note au poste (%s)" % str(chiffres_note().slice(0, 4)))
	shot("rapport-recruteur-a-observer-" + ("2560x1440" if root.size.x >= 2560 else "1920x1080"))
	piste_id = choisie

## Note connue (piste rendue « bien connue » dans la projection de l'écran) : lettre du staff de l'échelle unique, rang 1.
func lettre_connue() -> void:
	var p := piste()
	if p.is_empty(): return
	var numero := Rapport._poste(p)
	p.knowledge = {"stage": "deep", "owned": false, "version": 1}
	p.positionRatings = {str(numero): 99}
	p.ratingRange = {"min": 88, "max": 92}
	await ouvrir_rapport()
	var meta: Dictionary = node("RecrutementSubpage_recruteur").get_meta("rapport", {})
	var attendue := Notation.texte_lettre(int(Notation.resume(app.model, p, false).niveau))
	check(str(meta.get("lettre", "")) == attendue and attendue in Notation.LETTRES and int(meta.get("rang", 0)) == 1, "Niveau connu : lettre du staff %s (échelle E- à S+) et rang 1 (%s)" % [attendue, meta])
	var palier := node("RapportRecruteurPalier")
	check(palier != null and str(palier.get_meta("palier", "")) == str(Notation.resume(app.model, p, false).palier.texte), "Palier écrit en pilule à côté de la lettre")
	var textes := node("RecrutementSubpage_recruteur").find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	check(not textes.has("Marge de progression") and not textes.any(func(t: String): return t.begins_with("+") and t.trim_prefix("+").is_valid_int()), "Plus de « Marge de progression +N » chiffrée")
	check(node("RapportRecruteurPotentiel") != null and node("RapportRecruteurPhrase") != null, "Potentiel : lettre + phrase du staff")
	check(node("RapportRecruteurLignePiste") != null, "La piste est insérée dans la liste comparée")
	check(node("RapportRecruteurFamiliarite_0") != null, "Familiarité au poste dans la liste")
	# Note au poste en lettre du staff (décision de Léo du 24/11) : tuile, ligne de la piste et nos joueurs, aucun chiffre.
	var attendue_poste := Notation.texte_note(Notation.lettre_poste(app.model, p, numero, false))
	check(lettre_de("RapportRecruteurNoteLettre") == attendue_poste and attendue_poste != "?" and not attendue_poste.contains("/"), "Piste bien connue : note au poste en lettre sûre %s (%s)" % [attendue_poste, lettre_de("RapportRecruteurNoteLettre")])
	var lignes_lettres: Array = app.root_content.find_children("RapportRecruteurLettrePoste_*", "", true, false).map(func(n: Node) -> String: return str(n.get_meta("lettre", "")))
	check(not lignes_lettres.is_empty() and lignes_lettres.all(func(t: String) -> bool: return est_lettre(t) and t != "?"), "Liste comparée : note au poste en lettres (%s)" % str(lignes_lettres))
	check(chiffres_note().is_empty(), "Aucun chiffre de note au poste dans le rapport (%s)" % str(chiffres_note().slice(0, 4)))
	check(app.root_content.find_children("RapportRecruteurEtoiles*", "", true, false).is_empty(), "Plus d'étoiles de poste dans la liste")
	var pour: Array = app.root_content.find_children("RapportRecruteurPour_*", "Button", true, false)
	check(not pour.is_empty(), "Au moins un « Pour »")
	# Une seule échelle dans le jeu : plus de barème A+ … D propre au recruteur.
	check(not "lettre" in (Rapport as Script).get_script_method_list().map(func(m: Dictionary): return str(m.name)) and Notation.LETTRES.size() == 18, "Ancienne échelle A+ … D retirée")

func bareme() -> void:
	check(await press("RapportRecruteurLettre"), "Lettre cliquable")
	var pastilles := 0
	for l: String in Notation.LETTRES:
		if node("Bareme_" + l.replace("+", "plus").replace("-", "moins")) != null: pastilles += 1
	check(node("RapportRecruteurBareme") != null and pastilles == 18 and node("BaremeRang") != null, "Lettre → petite fenêtre du barème E- à S+ (%d pastilles)" % pastilles)
	check(est_lettre(lettre_de("BaremeNoteLettre")) and lettre_de("BaremeNoteLettre") == lettre_de("RapportRecruteurNoteLettre"), "Barème : note au poste en lettre, la même que la tuile (%s)" % lettre_de("BaremeNoteLettre"))
	check(chiffres_note().is_empty(), "Barème : aucun chiffre de note au poste (%s)" % str(chiffres_note().slice(0, 4)))
	check(await press("RapportRecruteurBaremeFermer"), "✕ de la petite fenêtre")
	await settle(4)
	check(node("RapportRecruteurBareme") == null, "✕ ferme le barème")
	await press("RapportRecruteurLettre")
	check(PetiteFenetre.fermer_derniere(self), "Échap ferme le barème")
	await settle(4)
	check(node("RapportRecruteurBareme") == null and page_kind() == "recruteur", "Après Échap : toujours sur le rapport")

func lignes() -> void:
	check(await press("RapportRecruteurLignePiste"), "Ligne de la piste cliquable")
	check(app.management_ui.get("fiche_joueur") is Dictionary, "Ligne de la piste → fiche")
	await ouvrir_rapport()
	var ligne := node("RapportRecruteurLigne_1") as Button
	if ligne == null: ligne = node("RapportRecruteurLigne_0") as Button
	check(ligne != null, "Une ligne de notre effectif")
	if ligne == null: return
	ligne.pressed.emit()
	await settle(10)
	check(app.route == "Effectif" and not str(app.selected_player).is_empty(), "Ligne de notre joueur → sa fiche dans l'Effectif (%s)" % app.route)

func tuiles_et_pastilles() -> void:
	for tuile in ["RapportRecruteurIndemniteLien", "RapportRecruteurSalaireLien"]:
		await ouvrir_rapport()
		var ok := await press(tuile)
		check(ok and page_kind() == "negociation", "Tuile %s → offre au joueur (%s)" % [tuile, page_kind()])
	for tuile in ["RapportRecruteurNoteLien", "RapportRecruteurPotentielLien", "RapportRecruteurPretLien", "RapportRecruteurConnaissanceLien"]:
		await ouvrir_rapport()
		var ok := await press(tuile)
		check(ok and app.management_ui.get("fiche_joueur") is Dictionary, "%s → fiche de la piste" % tuile)
	await ouvrir_rapport()
	var pret := node("RapportRecruteurPretTexte") as Label
	var attendu := "Prêt possible" if bool(piste().get("loan", {}).get("possible", false)) else "Prêt non"
	check(pret != null and pret.text == attendu, "Pastille du prêt : « %s »" % attendu)
	check(await press("RapportRecruteurTransfertLien") and page_kind() == "negociation", "Pastille transfert → offre au joueur")

func trouver(nom: String) -> Control:
	var n := node(nom)
	return n if n != null else root.find_child(nom, true, false) as Control

## Visages d'agents (banque art/agents) : numéro `portrait` de la fiche projetée, numéro affiché par une photo (meta
## posée seulement quand la photo de la banque est chargée ; -1 : nœud absent, 0 : repli sur la réserve du staff).
func visage_projete(joueur_id: String) -> int:
	var vue: Dictionary = app.model.get("clubLife", {}).get("agentsJoueurs", {})
	return int(vue.get("agents", {}).get(str(vue.get("joueurs", {}).get(joueur_id, "")), {}).get("portrait", 0))

func visage_affiche(nom: String) -> int:
	var n := trouver(nom)
	if n == null: return -1
	if not n.has_meta("agent_portrait") and n.get_child_count() > 0: n = n.get_child(0) as Control
	return int(n.get_meta("agent_portrait", 0)) if n != null else -1

func presser(nom: String) -> bool:
	var b := trouver(nom) as Button
	if b == null or b.disabled: return false
	b.pressed.emit()
	await settle(10)
	return true

## Discussion avec l'agent : trois tons, le ton choisi passe par le moteur, puis question (caractère découvert) et offre.
## Rien de chiffré à l'écran : ni effet du ton ou de la relation, ni nombre de propositions (patience cachée).
func agent() -> void:
	await ouvrir_rapport()
	var avant := int(piste().get("salary", 0))
	var a0: Dictionary = piste().get("agent", {})
	check(str(a0.get("ton", "x")).is_empty() and not a0.has("essais") and not a0.has("relation") and not a0.has("effet"), "Agent : sans ton, aucun chiffre projeté (%s)" % JSON.stringify(a0))
	check(await presser("RapportAgentOuvrirLien") and trouver("DiscussionAgent") != null, "Pastille « Parler à l'agent » → fenêtre")
	for ton in ["tout_prix", "enthousiaste", "curieux"]: check(trouver("AgentTon_" + ton) != null, "Ton proposé : " + ton)
	check(trouver("AgentRapportLigne") != null and trouver("AgentRapportLettre") != null, "Rapport du recruteur à gauche")
	check(trouver("AgentRelationCran_2") != null and trouver("AgentFamiliarite") != null and trouver("AgentNotePoste") != null, "Relation en crans, familiarité, note au poste")
	check(est_lettre(lettre_de("AgentNotePoste")) and lettre_de("AgentNotePoste") == Notation.texte_note(Rapport.lire(app, piste()).lettre_poste), "Agent : note au poste en lettre du staff (%s)" % lettre_de("AgentNotePoste"))
	check(chiffres_note().is_empty(), "Agent : aucun chiffre de note au poste (%s)" % str(chiffres_note().slice(0, 4)))
	check(trouver("AgentRelationValeur") == null and trouver("AgentEffetRelationNeutre") == null and trouver("AgentPropositions") == null, "Ni valeur de relation, ni effet, ni ronds de propositions")
	var observe := str(piste().get("knowledge", {}).get("stage", "")) in ["observed", "deep"]
	check(observe or texte("AgentCaractere") == "?", "Caractère inconnu : « ? » (%s)" % texte("AgentCaractere"))
	check(trouver("AgentHumeur") != null, "Pastille d'humeur")
	# Agent nommé (retour de Léo du 23/11) : c'est l'agent qu'on voit, il parle de son client ; relation une seule fois.
	var nom_agent := str(a0.get("nom", ""))
	check(not nom_agent.is_empty() and nom_agent != "L’agent" and texte_bouton("AgentNom") == nom_agent, "En-tête : nom de l'agent (%s / %s)" % [nom_agent, texte_bouton("AgentNom")])
	check(trouver("AgentPortraitPhoto") != null and trouver("AgentVisage") != null, "Portrait de l'agent en tête et dans ses bulles")
	var visage := visage_projete(piste_id)
	check(visage >= 1 and visage <= 60 and visage_affiche("AgentPortraitPhoto") == visage and visage_affiche("AgentVisage") == visage,
		"Visage de l'agent (banque) en tête et dans ses bulles : %d / %d / %d" % [visage, visage_affiche("AgentPortraitPhoto"), visage_affiche("AgentVisage")])
	check(trouver("AgentEchelleAttitude") == null and trouver("AgentPalier0") == null and trouver("AgentRelationCran_4") != null, "Relation une seule fois (en-tête), pas d'échelle au-dessus du fil")
	check(trouver("AgentSujet") != null and trouver("AgentJoueurNom") != null, "Carte « Au sujet de » : le joueur")
	check(trouver("AgentClient_0") != null and trouver("AgentClientVise") != null and trouver("AgentClientsTitre") != null, "Ses joueurs : liste, joueur concerné surligné")
	check(texte("AgentBulleAccueilTexte").contains("mon client"), "L'agent parle de son client (%s)" % texte("AgentBulleAccueilTexte"))
	check(await presser("AgentNom") and trouver("FenetreAgentJoueur") != null and texte("FenetreAgentNom") == nom_agent and trouver("FenetreAgentClient_0") != null, "Clic sur le nom : petite fenêtre de l'agent")
	check(visage_affiche("FenetreAgentPortraitPhoto") == visage, "Petite fenêtre : même visage (%d)" % visage_affiche("FenetreAgentPortraitPhoto"))
	await settle(10)
	shot("final-fenetre-agent-%d" % root.size.x)
	PetiteFenetre.fermer_derniere(self)
	await settle(6)
	check(trouver("FenetreAgentJoueur") == null and trouver("DiscussionAgent") != null, "Petite fenêtre de l'agent refermée, discussion toujours là")
	await settle(10)
	shot("final-pastilles-%d" % root.size.x)
	var b := trouver("AgentTon_tout_prix") as Button
	check(b != null and not b.disabled, "Ton cliquable")
	if b == null: return
	b.pressed.emit()
	await wait_engine()
	await settle(10)
	var a: Dictionary = piste().get("agent", {})
	check(str(a.get("ton", "")) == "tout_prix" and int(a.get("cran", 0)) == 3 and not a.has("essais"), "Moteur : ton à tout prix, relation Bonne (%s)" % JSON.stringify(a))
	# Le ton fait pencher la demande sans garantie chiffrée (arrondis, plancher) : jamais plus basse après « À tout prix ».
	check(int(piste().get("salary", 0)) >= avant, "Demande pas baissée (%d → %d)" % [avant, int(piste().get("salary", 0))])
	check(trouver("DiscussionAgent") != null and trouver("AgentBulleDemande") != null and trouver("AgentEffets") == null, "Fenêtre rouverte : réponse de l'agent, sans pastille d'effet")
	check(trouver("AgentRelationFleche") != null, "Le cran de la relation bouge dans l'en-tête (Neutre → Bonne)")
	await settle(10)
	shot("final-discussion-%d" % root.size.x)
	check(await presser("AgentQuestion_role"), "Deuxième tour : rôle attendu")
	await wait_engine()
	await settle(10)
	check(trouver("AgentBulleReponse") != null, "Réponse sur le rôle")
	var mot := texte("AgentCaractere")
	check(not mot.is_empty() and mot != "?" and str(piste().get("agent", {}).get("caractere", "")) == mot, "Caractère découvert au 2e tour : %s" % mot)
	check(await presser("AgentFaireOffre") and page_kind() == "negociation", "Troisième tour : offre au joueur (%s)" % page_kind())
	await settle(10)
	check(trouver("NegoPropo_1") == null and trouver("NegoHumeur") != null, "Offre : humeur de l'agent, plus de ronds numérotés")
	check(texte_bouton("NegoAgentNom") == nom_agent and trouver("NegoAgentAvatarPhoto") != null, "Offre : nom et portrait de l'agent (%s)" % texte_bouton("NegoAgentNom"))
	check(visage_affiche("NegoAgentAvatarPhoto") == visage_projete(piste_id), "Offre : même visage d'agent (%d)" % visage_affiche("NegoAgentAvatarPhoto"))
	check(texte("NegoRelationAgent") == "Bonne" and texte("NegoCaractere") == mot and trouver("NegoEffetRelationDemande") == null, "Offre : relation sans chiffre, caractère (%s · %s)" % [texte("NegoRelationAgent"), texte("NegoCaractere")])
	shot("final-offre-agent-%d" % root.size.x)
	check(texte("OffreEtapeTexte") == "Proposition 1", "Offre : étape sans total (%s)" % texte("OffreEtapeTexte"))

## Agent nommé ailleurs dans le jeu : courrier « Un agent de joueurs » (Réception) et fiche d'un joueur de l'effectif.
func reception_et_fiche() -> void:
	var vue: Dictionary = app.model.get("clubLife", {}).get("agentsJoueurs", {})
	var p := piste()
	var ag_id := str(vue.get("joueurs", {}).get(piste_id, ""))
	var ag: Dictionary = vue.get("agents", {}).get(ag_id, {})
	check(not ag.is_empty() and not str(ag.get("agence", "")).is_empty(), "Agent de la piste projeté, avec son agence")
	if ag.is_empty(): return
	# Courrier de l'agent, sous la forme projetée par club-mail.cjs (expéditeur = son nom, agent, agence).
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	if not app.model.clubLife.has("clubMail") or not app.model.clubLife.clubMail is Dictionary: app.model.clubLife.clubMail = {"mails": [], "reponses": {}}
	var box: Dictionary = app.model.clubLife.clubMail
	var mail := {"id": "mail-990101", "type": "agent", "categorie": "recrutement", "categorieLabel": "Recrutement", "date": today, "expediteur": str(ag.nom), "agent": ag_id,
		"agence": str(ag.agence), "sujet": "Proposition : " + str(p.get("name", "")), "status": "nouveau", "ecran": "fiche", "arret": true, "nature": "action", "joueur": piste_id,
		"corps": "Bonjour coach. Je représente " + str(p.get("name", "")) + ". Il cherche un projet ambitieux et ton club l'intéresse.",
		"reponses": [{"id": "negocier", "libelle": "Ouvrir les discussions", "effets": "", "disponible": true, "raison": "", "ouvrir": true},
			{"id": "decliner", "libelle": "Décliner poliment", "effets": "", "disponible": true, "raison": ""}]}
	box.mails = [mail] + (box.get("mails", []) as Array)
	app._reset_reception("mail-990101")
	app._navigate("Réception", false)
	await settle(12)
	check(node("InboxAgentPortraitPhoto") != null, "Réception : portrait de l'agent")
	check(visage_affiche("InboxAgentPortraitPhoto") == int(ag.get("portrait", 0)) and visage_affiche("InboxRowAgentFacePhoto") == int(ag.get("portrait", 0)),
		"Réception : même visage dans le courrier et sa ligne (%d / %d / %d)" % [int(ag.get("portrait", 0)), visage_affiche("InboxAgentPortraitPhoto"), visage_affiche("InboxRowAgentFacePhoto")])
	var nom := node("InboxSenderName") as Label
	check(nom != null and nom.text == str(ag.nom), "Réception : nom de l'agent (%s)" % (nom.text if nom != null else "?"))
	shot("final-reception-agent-%d" % root.size.x)
	check(await press("InboxAgentNomLien") and node("FenetreAgentJoueur") != null and node("FenetreAgentClientVise") != null, "Réception : clic sur le nom → petite fenêtre de l'agent, client surligné")
	shot("final-reception-fenetre-agent-%d" % root.size.x)
	PetiteFenetre.fermer_derniere(self)
	await settle(6)
	# Fiche d'un joueur de l'effectif : « Agent : <nom> », clic = petite fenêtre de l'agent.
	var joueur: Dictionary = app.model.squad[0]
	app.navigation_controller.open_entity({"kind": "player", "id": str(joueur.id)})
	await settle(12)
	var lien := node("PlayerAgentLink") as Button
	var a2: Dictionary = vue.get("agents", {}).get(str(vue.get("joueurs", {}).get(str(joueur.id), "")), {})
	check(lien != null and lien.text == "Agent : " + str(a2.get("nom", "?")), "Fiche joueur : « Agent : <nom> » (%s)" % (lien.text if lien != null else "?"))
	check(int(a2.get("portrait", 0)) >= 1 and visage_affiche("PlayerAgentFace") == int(a2.get("portrait", 0)), "Fiche joueur : visage de l'agent (%d)" % visage_affiche("PlayerAgentFace"))
	shot("final-fiche-joueur-%d" % root.size.x)
	if lien != null:
		lien.pressed.emit()
		await settle(10)
		check(node("FenetreAgentJoueur") != null and node("FenetreAgentClientVise") != null, "Fiche : petite fenêtre de l'agent, joueur surligné")
		shot("final-fiche-agent-%d" % root.size.x)
		PetiteFenetre.fermer_derniere(self)
		await settle(6)
	app._navigate("Recrutement", false)
	await settle(8)

## Texte d'un bouton (liens de nom).
func texte_bouton(nom: String) -> String:
	var b := trouver(nom) as Button
	return b.text if b != null else ""

## Texte du premier Label sous un nœud (pastilles).
func texte(nom: String) -> String:
	var n := trouver(nom)
	if n == null: return ""
	if n is Label: return (n as Label).text
	for l in n.find_children("*", "Label", true, false): return (l as Label).text
	return ""
