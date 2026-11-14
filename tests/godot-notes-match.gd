extends SceneTree
## Notes de match dans le vrai jeu (profil préparé par tests/godot-notes-match.cjs : quelques
## journées jouées par le vrai moteur) : moyenne et forme dans l'effectif, moyenne, forme et
## historique dans la fiche joueur. Captures dans CD_NOTES_OUTPUT.
var app: Control
var sortie := OS.get_environment("CD_NOTES_OUTPUT")
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
	var limite := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, "réponse du vrai moteur : " + str(app.last_error))
	await poser(10)

func capture(nom: String) -> void:
	await poser(12)
	if DisplayServer.get_name() == "headless": return
	verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

func executer() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await attendre_moteur()
	if app.timer: app.timer.stop()
	var notes: Dictionary = app.model.get("clubLife", {}).get("matchNotes", {})
	var joueurs: Dictionary = notes.get("joueurs", {})
	verifier(joueurs.size() >= 15, "notes de l'effectif projetées : %d" % joueurs.size())
	# Joueur le plus utilisé : historique le plus long ; un ailier d'abord (retour de Léo du 14/11 : les
	# stats d'un ailier titulaire doivent ressembler à de vraies stats).
	var ailiers := {}
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and str(p.get("pos", "")) == "Ailier": ailiers[str(p.get("id", ""))] = true
	var choisi := ""
	var plus := -1
	var meilleure := -1.0
	for id: String in joueurs:
		var n := int(joueurs[id].get("matchs", 0)) + (1000 if ailiers.has(id) else 0)
		var m: float = float(joueurs[id].get("moyenne")) if joueurs[id].get("moyenne") != null else 0.0
		if n > plus or n == plus and m > meilleure:
			plus = n; meilleure = m; choisi = id
	plus = int(joueurs[choisi].get("matchs", 0)) if choisi != "" else 0
	mesures["joueur"] = choisi
	mesures["ailier"] = ailiers.has(choisi)
	mesures["matchs"] = plus
	app._navigate("Effectif"); await poser(30)
	var colonne := app.find_child("RosterColumnNote", true, false)
	verifier(colonne != null and str(colonne.get("text")) == "MOY.", "colonne « MOY. » de l'effectif")
	verifier(app.find_child("RosterColumnForm", true, false) != null, "colonne FORME de l'effectif")
	var pastilles := app.find_children("RosterNoteAverage", "", true, false)
	verifier(pastilles.size() >= 15, "moyennes dans les lignes : %d" % pastilles.size())
	var formes := app.find_children("FormeNote*", "", true, false)
	verifier(formes.size() >= 15, "pastilles de forme : %d" % formes.size())
	mesures["pastilles_forme"] = formes.size()
	await capture("notes-match-effectif")
	app.selected_player = choisi
	app.management_ui.immersive_player_tab = 2
	app.set_meta("immersive08_full_player", true)
	app._render(); await poser(30)
	verifier(app.find_child("FullPlayerNoteAverage", true, false) != null, "moyenne de la fiche")
	verifier(app.find_child("FullPlayerForm", true, false) != null, "forme de la fiche")
	verifier(app.find_child("PlayerMatchHistory", true, false) != null, "historique des matchs de la fiche")
	var lignes := app.find_children("PlayerMatchRow*", "", true, false)
	verifier(lignes.size() == plus, "une ligne par match noté : %d / %d" % [lignes.size(), plus])
	# Stats de la feuille réaliste (match-stats.cjs) : moyennes par match et colonnes passes / franchissements.
	verifier(app.find_child("PlayerSeasonPerMatch", true, false) != null, "moyennes par match de la saison")
	var j: Dictionary = joueurs[choisi]
	mesures["par_match"] = {"plaquages": float(j.get("plaquages", 0)) / maxi(1, plus), "metres": float(j.get("metres", 0)) / maxi(1, plus), "essais": float(j.get("essais", 0)) / maxi(1, plus), "passes": float(j.get("passes", 0) if j.get("passes") != null else 0) / maxi(1, plus)}
	await capture("notes-match-fiche")
	# Libellés demandés : « MOYENNE SAISON · N matchs » dans la fiche, « MOY. » dans l'effectif.
	var libelle := app.find_child("FullPlayerNoteMatches", true, false)
	verifier(libelle != null and str(libelle.get("text")) == "MOYENNE SAISON · " + ("%d matchs" % plus if plus > 1 else "1 match"), "libellé « MOYENNE SAISON · N matchs » de la fiche")
	# Panneau « Sélection » : vide sans match international, puis rempli (données de présentation
	# posées dans le modèle de l'interface uniquement, jamais dans la carrière).
	verifier(app.find_child("PlayerSelectionNotes", true, false) != null, "panneau « Sélection » de la fiche")
	verifier(app.find_child("PlayerSelectionEmpty", true, false) != null or app.model.clubLife.matchNotes.joueurs[choisi].get("selection") is Dictionary, "état vide du panneau Sélection")
	var fictif := {"matchs": 4, "moyenne": 7.1, "forme": [6.4, 7.0, 7.5, 7.5], "hommeDuMatch": 1, "historique": [
		{"date": "2026-11-21", "adversaire": "Irlande", "competition": "Test-match", "minutes": 80, "note": 7.5, "essais": 1, "hommeDuMatch": true},
		{"date": "2026-11-14", "adversaire": "Écosse", "competition": "Test-match", "minutes": 80, "note": 7.5, "essais": 0, "hommeDuMatch": false},
		{"date": "2026-02-07", "adversaire": "Italie", "competition": "Six Nations", "minutes": 62, "note": 7.0, "essais": 0, "hommeDuMatch": false}]}
	app.model["clubLife"]["matchNotes"]["joueurs"][choisi]["selection"] = fictif
	app._render(); await poser(30)
	verifier(app.find_child("PlayerSelectionAverage", true, false) != null, "moyenne de sélection")
	verifier(app.find_child("PlayerSelectionForm", true, false) != null, "forme de sélection")
	verifier(app.find_children("PlayerSelectionRow*", "", true, false).size() == 3, "trois dernières sélections")
	await capture("notes-match-selection")
	var rapport := {"affichage": DisplayServer.get_name(), "controles": controles, "failures": echecs, "mesures": mesures}
	print("NOTES_MATCH ", JSON.stringify(rapport))
	quit(0 if echecs.is_empty() else 1)
