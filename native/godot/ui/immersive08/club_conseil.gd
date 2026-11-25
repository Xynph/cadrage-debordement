extends "res://ui/immersive08/club_socle.gd"
## Écran Club, vue d'ensemble, colonne de gauche : bandeau du club, le conseil (note, domaines, objectif, bilans).

## Bandeau du club : écusson, nom, lieu et chiffres. Un clic ouvre « Le stade ».
static func _hero(app: Control, page: Control, fans: Dictionary) -> void:
	var bandeau := Button.new()
	bandeau.name = "ClubStadium"
	bandeau.flat = false # un bouton « flat » ne dessine ni son fond ni son ombre
	bandeau.focus_mode = Control.FOCUS_ALL
	bandeau.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bandeau.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU, Color.TRANSPARENT, 24, 0))
	bandeau.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 24, 0))
	bandeau.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 24, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 24, 0)
	focus.set_border_width_all(2)
	bandeau.add_theme_stylebox_override("focus", focus)
	bandeau.accessibility_name = "Voir le stade · " + str(G.identity(app.model.club).get("stadium", "le stade du club"))
	bandeau.pressed.connect(func(): _tab(app, "territory", "ClubTab_overview"))
	page.add_child(bandeau)
	bandeau.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	D.place(bandeau, Rect2(0, 0, W, 110))
	var photo := D.photo(bandeau, photo_entete(app.model, "overview"), Rect2(W * .4, 0, W * .6, 110), .5)
	photo.modulate = Color(1, 1, 1, .32)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ecusson := G.crest(app.model.club, C.px(88))
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(ecusson)
	D.place(ecusson, Rect2(24, 11, 88, 88))
	var identite := G.identity(app.model.club)
	var nom := D.text(bandeau, 134, 60, G.club_name(app.model.club).to_upper(), 44, Charte.IVOIRE, 800, 1100)
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	nom.name = "ClubHeroName"
	var x_tuile := 134.0
	if not str(identite.get("stadium", "")).is_empty():
		x_tuile += Kit.largeur(str(identite.stadium), 19) + 16.0
		Kit.texte(bandeau, 134, 92, str(identite.stadium), Charte.IVOIRE_2, 600, 19).name = "ClubStadiumName"
	for chiffre: Array in [["capacity", "places", Pastilles.TURQUOISE], ["expectedAttendance", "affluence", Pastilles.BLEU], ["subscribers", "abonnés", Pastilles.VIOLET]]:
		if not fans.has(chiffre[0]): continue
		var tuile := Pastilles.tuile(G.n(fans[chiffre[0]]), str(chiffre[1]), chiffre[2], Color(Charte.PANNEAU, .78), 24, "ClubStadium_" + str(chiffre[0]), true)
		tuile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		x_tuile += Pastilles.poser(bandeau, tuile, x_tuile, 70) + 8.0
	var voir := Kit.texte(bandeau, W - 28, 60, "Voir le stade →", Charte.IVOIRE, 300, 19, HORIZONTAL_ALIGNMENT_RIGHT)
	voir.add_theme_font_override("font", Kit.texte_gras())
	voir.name = "ClubSeeStadium"

static func _conseil(panneau: Panel, app: Control, finance: Dictionary, board: Dictionary) -> void:
	var confiance: Variant = app.model.meta.get("trust")
	var historique: Array = finance.get("boardHistory", [])
	var dernier: Dictionary = historique[0] if not historique.is_empty() else {}
	var largeur := panneau.size.x / C.density
	if dernier.is_empty():
		Pastilles.poser_a_droite(panneau, Pastilles.pastille("1er bilan à venir", Pastilles.BLEU, "clock", "Le conseil rend son premier bilan après quelques journées.", 18, "ClubLastReview", func(): _open_strategy(app, 1)), largeur - 24, 14)
	else:
		Kit.texte(panneau, largeur - 24, 40, "dernier bilan après J%s" % G.n(dernier.round), Charte.IVOIRE_2, 400, 18, HORIZONTAL_ALIGNMENT_RIGHT).name = "ClubLastReview"
	# Note du conseil en lettre (revue FM27, idée n° 8, option B « carnet de notes » choisie par Léo le 22/11/2026).
	ConseilLettre.conseil(panneau, app, finance, largeur)
	D.line(panneau, Vector2(24, 306), Vector2(largeur - 24, 306), Charte.FILET)
	_objectif(panneau, app, board, 24, 322, 600)
	ConseilLettre.bilans(panneau, app, historique, 664, 322, largeur - 664 - 24, _lier_bilan.bind(app))

## Objectif de la saison : l'objectif du club, puis le classement, les promesses publiques et les jalons du conseil ;
## chaque ligne ouvre le suivi des objectifs.
static func _objectif(panneau: Panel, app: Control, board: Dictionary, x: float, y: float, largeur: float) -> void:
	var bloc := Control.new()
	bloc.name = "ClubObjectives"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panneau.add_child(bloc)
	D.place(bloc, Rect2(x, y, largeur, 330))
	Kit.etiquette(bloc, 0, 22, "Objectif de la saison", largeur)
	var but := str(app.model.club.get("goal", "Projet sportif"))
	var titre := _texte_lignes(bloc, 0, 36, largeur, but, 28, Charte.TITRE_GRAS_ITALIQUE, Charte.IVOIRE, 2)
	titre.name = "ClubGoal"
	titre.tooltip_text = but
	var lignes: Array = []
	var metriques: Dictionary = board.get("metrics", {})
	var rang: Variant = metriques.get("rank", app.model.club.get("rank"))
	var jouees := int(app.model.club.get("played", 0))
	if P.standings_open(app.model.club) and rang != null:
		var place := "%s%s" % [G.n(rang), "er" if int(rang) == 1 else "e"]
		lignes.append({"genre": "ok", "texte": "En cours : %s après %s" % [place, P.plural(jouees, "journée", "journées")] if jouees > 0 else "En cours : %s" % place, "statut": ""})
	else:
		lignes.append({"genre": "neutre", "texte": "Pas encore de classement", "statut": ""})
	var promesses: Variant = app.model.get("clubLife", {}).get("pressPromises", {})
	var actives: Array = promesses.get("active", []) if promesses is Dictionary else []
	for i in mini(2, actives.size()):
		var promesse: Dictionary = actives[i]
		var avancement: Dictionary = promesse.get("progress", {})
		var suit: Variant = avancement.get("onTrack")
		lignes.append({"genre": "neutre" if suit == null else ("ok" if suit else "alerte"), "texte": str(promesse.get("short", "Promesse publique")), "detail": str(avancement.get("short", "")), "statut": "À suivre" if suit == null else ("En bonne voie" if suit else "En retard"), "promesse": i + 1, "bulle": "Promesse publique : " + str(promesse.get("label", "")) + "\n" + str(avancement.get("label", ""))})
	var objectifs: Array = board.get("objectives", [])
	for objectif: Dictionary in objectifs:
		if lignes.size() >= 5: break
		var genre := str(objectif.get("type", ""))
		var etat := str(objectif.get("status", "pending"))
		var cible: Variant = objectif.get("target")
		var chiffre := G.euros(cible) if genre == "cash" else G.n(cible)
		lignes.append({"genre": "ok" if etat == "met" else ("croix" if etat == "missed" else "neutre"), "texte": "%s : %s · sem. %s" % [GOALS.get(genre, "Jalon du conseil"), chiffre, G.n(objectif.get("deadline", "—"))], "statut": GOAL_STATUS.get(etat, etat)})
	var top := 118.0
	for i in lignes.size():
		var ligne: Dictionary = lignes[i]
		var rangee := Button.new()
		rangee.name = "ClubObjectiveRow%d" % i
		Kit.styler_ligne(rangee, Color.TRANSPARENT)
		rangee.accessibility_name = str(ligne.texte)
		rangee.pressed.connect(func(): _open_strategy(app, 1))
		bloc.add_child(rangee)
		D.place(rangee, Rect2(0, top + i * LIGNE, largeur, LIGNE))
		_coche(rangee, Rect2(4, 6, 20, 20), str(ligne.genre) if str(ligne.genre) != "neutre" else "neutre", Charte.IVOIRE if str(ligne.genre) != "neutre" else Charte.IVOIRE_2)
		var texte := Kit.texte(rangee, 36, 22, str(ligne.texte), Charte.IVOIRE, largeur - 36 - (130 if not str(ligne.statut).is_empty() else 0), 18)
		if ligne.has("promesse"):
			texte.name = "ClubPromise%d" % int(ligne.promesse)
			texte.tooltip_text = str(ligne.get("bulle", ""))
			texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not str(ligne.statut).is_empty(): Kit.texte(rangee, largeur - 6, 22, str(ligne.statut), Charte.IVOIRE_2, 124, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	var suivre := Kit.lien(bloc, Rect2(0, top + 5 * LIGNE + 14, 0, 36), "Suivre les objectifs →", func(): _open_strategy(app, 1), "ClubBoardGoals", 19)
	suivre.tooltip_text = ""

## Ce qui a fait bouger la confiance : un bilan du conseil par ligne (journée, confiance après le bilan, évolution, résultat du match
## de la journée, cause). Une ligne ouvre le match quand il est connu, sinon les objectifs du conseil.
## Ligne d'un bilan du conseil : ovale du résultat de la journée et lien vers la fiche du match (sinon le suivi des objectifs).
static func _lier_bilan(rangee: Button, bilan: Dictionary, app: Control) -> void:
	var rencontre := _rencontre_du_bilan(app, bilan, int(app.model.get("meta", {}).get("season", 1)))
	if rencontre.is_empty():
		Kit.texte(rangee, 248, 25, "—", Charte.IVOIRE_3, 40, 18, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var resume := _resume_rencontre(rencontre, app.model.club.id)
	_ovale_resultat(rangee, Rect2(222, 6, 52, 24), str(resume.lettre))
	var cible: Dictionary = load("res://ui/immersive08/office.gd").score_reading_target(app, rencontre)
	if cible.is_empty(): return
	for connexion: Dictionary in rangee.pressed.get_connections(): rangee.pressed.disconnect(connexion.callable)
	EntityLink.bind(rangee, app, cible, str(resume.texte))

static func _rencontre_du_bilan(app: Control, bilan: Dictionary, saison: int) -> Dictionary:
	if int(bilan.get("season", saison)) != saison: return {}
	var etiquette := "Journée %d" % int(bilan.get("round", -1))
	for rencontre: Variant in app.model.get("calendar", []):
		if not rencontre is Dictionary or not rencontre.get("played", false): continue
		if str(rencontre.get("label", "")) != etiquette: continue
		if rencontre.get("score") is Array and rencontre.score.size() == 2: return rencontre
	return {}

## {lettre : V / N / D, texte : « Victoire 21-18 contre X » (ou « à X » à l'extérieur)} du point de vue du club.
static func _resume_rencontre(rencontre: Dictionary, club_id: Variant) -> Dictionary:
	var cote := 0 if rencontre.get("home", {}).get("id") == club_id else 1
	var adversaire: Dictionary = rencontre.away if cote == 0 else rencontre.home
	var score: Array = rencontre.score
	var lettre := "N"
	var mot := "Nul"
	var vainqueur: Variant = rencontre.get("winner")
	if score[cote] != score[1 - cote] or vainqueur != null:
		var gagne: bool = (vainqueur == club_id) if score[cote] == score[1 - cote] else score[cote] > score[1 - cote]
		lettre = "V" if gagne else "D"
		mot = "Victoire" if gagne else "Défaite"
	var lieu := "à " if P.fixture_location_kind(rencontre, club_id) == "away" else "contre "
	return {"lettre": lettre, "texte": "%s %s-%s %s%s" % [mot, G.n(score[cote]), G.n(score[1 - cote]), lieu, G.club_name(adversaire)]}

## Ovale V / N / D (charte §3) : plein pour une victoire, anneau pour le reste ; la lettre dit toujours le résultat.
static func _ovale_resultat(parent: Control, zone: Rect2, lettre: String) -> void:
	var forme := Kit.Ovale.new()
	forme.numero = lettre
	forme.police = Kit.texte_gras()
	forme.plein = lettre == "V"
	forme.fond = Charte.V
	forme.bordure = Charte.V if lettre == "V" else (Charte.D if lettre == "D" else Charte.IVOIRE_2)
	forme.texte = Charte.NUIT if lettre == "V" else forme.bordure
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(forme)
	D.place(forme, zone)

# --- Installations -------------------------------------------------------------------------------------------------------
