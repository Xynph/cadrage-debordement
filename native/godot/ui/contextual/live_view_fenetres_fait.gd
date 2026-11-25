extends "res://ui/contextual/live_view_fenetres.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : petites fenêtres de l'écran 2D : fait et match du multiplex.

## Petite fenêtre d'un fait du match (essai, pénalité, carton, repère de la frise, dernier fait) : écusson du club,
## type, minute, auteur (sa fenêtre s'il est des nôtres) et score d'après ; « Journal » ouvre le tiroir à ce fait.
func ouvrir_fenetre_fait(i: int) -> void:
	var live := _live()
	var evenements: Array = live.get("events", []) if live.get("events") is Array else []
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var repere: Dictionary = {}
	for r: Variant in direct.get("reperes", []) if direct.get("reperes") is Array else []:
		if r is Dictionary and int(r.get("i", -1)) == i: repere = r
	var evenement: Dictionary = evenements[i] if i >= 0 and i < evenements.size() and evenements[i] is Dictionary else {}
	if repere.is_empty() and evenement.is_empty(): return
	var kind := str(repere.get("kind", evenement.get("kind", "")))
	var rouge := bool(repere.get("rouge", false)) or str(evenement.get("text", "")).to_lower().contains("rouge")
	var type := ("Carton rouge" if rouge else "Carton jaune") if kind == "card" else str(TYPES_FAITS.get(kind, "Fait de jeu"))
	var teams: Array = live.get("teams", [])
	var cote := int(repere.get("equipe", evenement.get("team", evenement.get("equipe", -1))))
	var club: Dictionary = _club_complet(teams[cote]) if cote >= 0 and cote < teams.size() and teams[cote] is Dictionary else {}
	var texte := str(evenement.get("text", ""))
	var fond := _ouvrir_fenetre(FENETRE_FAIT, type.to_upper(), 960, 420 if not texte.is_empty() else 360)
	fond.set_meta("fait", i)
	if not club.is_empty():
		var ecusson := ecusson_club(club, C.px(140))
		ecusson.name = "MatchFenetreFaitEcusson"
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(36, 84, 140, 140))
	var minute := str(repere.get("horloge", evenement.get("clock", "")))
	if minute.is_empty() and evenement.get("minute") != null: minute = "%d′" % int(evenement.minute)
	var largeur := (960.0 - 206.0 - 36.0 - 2 * 12.0) / 3.0
	Pieces.tuile(fond, Rect2(206, 84, largeur, 116), minute if not minute.is_empty() else "—", "minute", Charte.IVOIRE, "MatchFenetreFaitMinute", 50, "", "clock")
	var marque: Variant = repere.get("score") if repere.get("score") is Array else evenement.get("score")
	var score := "%d – %d" % [int(marque[0]), int(marque[1])] if marque is Array and (marque as Array).size() == 2 else "—"
	Pieces.tuile(fond, Rect2(206 + largeur + 12.0, 84, largeur, 116), score, "score après", Charte.IVOIRE, "MatchFenetreFaitScore", 46)
	var couleur_type: Color = Charte.PERTE if rouge else (Charte.INTENSIF if kind == "card" else (Charte.GAIN if kind in ["try", "goal", "transformation", "drop"] else Charte.IVOIRE))
	Pieces.tuile(fond, Rect2(206 + 2 * (largeur + 12.0), 84, largeur, 116), type, "type", couleur_type, "MatchFenetreFaitType", 34)
	# Club et auteur en pastilles ; l'auteur, s'il est des nôtres, ouvre sa petite fenêtre.
	var x := 206.0
	if not club.is_empty(): x += Pieces.pastille(fond, x, 216, S.G.club_name(club), "shield", "MatchFenetreFaitClub", "", Charte.IVOIRE, Charte.PANNEAU_3, func(): ouvrir_fiche_club(cote)) + 10.0
	var qui := str(repere.get("nom", "")).strip_edges()
	var scene: Dictionary = evenement.get("scene", {}) if evenement.get("scene") is Dictionary else {}
	var acteur := str(scene.get("actor", "")) if scene.get("actor") != null else ""
	if qui.is_empty() and not acteur.is_empty():
		for liste: String in ["lineup", "reserves"]:
			for j: Variant in live.get(liste, []) if live.get(liste) is Array else []:
				if j is Dictionary and str(j.get("id", "")) == acteur: qui = str(j.get("name", ""))
	var des_notres: bool = not acteur.is_empty() and not load("res://ui/immersive08/fiche_commune.gd").trouver(app, acteur, "squad").is_empty()
	if not qui.is_empty(): x += Pieces.pastille(fond, x, 216, qui, "people", "MatchFenetreFaitAuteur", "", Charte.IVOIRE, Charte.PANNEAU_3, (func(): ouvrir_fenetre_joueur(acteur)) if des_notres else Callable()) + 10.0
	Pieces.pastille(fond, x, 216, "Journal", "search", "MatchFenetreFaitJournal", "", Charte.IVOIRE, Charte.PANNEAU_3, func():
		fermer_fenetre()
		if regie != null and regie.has_method("ouvrir_journal_a"): regie.ouvrir_journal_a(i))
	if not texte.is_empty():
		var ligne := D.text(fond, 206, 300, texte, 20, Charte.IVOIRE_2, 500, 960 - 206 - 36, HORIZONTAL_ALIGNMENT_LEFT, true)
		ligne.name = "MatchFenetreFaitTexte"
		ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.size.y = 90
		ligne.custom_minimum_size.y = 0

## Petite fenêtre d'un autre match de la journée (carte du multiplex) : les deux clubs (écusson et nom, leur fenêtre au
## clic), le score en grandes tuiles, les essais, la minute ou « Terminé ».
func ouvrir_fenetre_match(rencontre: Dictionary) -> void:
	var cotes: Array = [rencontre.get("home", {}), rencontre.get("away", {})]
	if not cotes[0] is Dictionary or not cotes[1] is Dictionary: return
	var fini := bool(rencontre.get("fini", false))
	var fond := _ouvrir_fenetre(FENETRE_MATCH, "%s – %s" % [str(cotes[0].get("abbr", "")), str(cotes[1].get("abbr", ""))], 960, 420)
	fond.set_meta("match_id", str(rencontre.get("id", "")))
	var largeur := (960.0 - 72.0 - 24.0) / 2.0
	for k in 2:
		var c: Dictionary = cotes[k]
		var club: Dictionary = _club_complet({"id": c.get("id"), "name": c.get("nom", ""), "abbr": c.get("abbr", "")}) if c.get("id") != null else c
		var x := 36.0 + k * (largeur + 24.0)
		var ecusson := ecusson_club(club, C.px(80))
		ecusson.name = "MatchFenetreMatchEcusson%d" % k
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(x, 84, 80, 80))
		var nom_club := str(c.get("nom", S.G.club_name(club)))
		var nom := D.text(fond, x + 96, 134, nom_club.to_upper(), 26, Charte.IVOIRE, 800, largeur - 96)
		nom.name = "MatchFenetreMatchNom%d" % k
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		var pour := int(c.get("score", 0))
		var contre := int(cotes[1 - k].get("score", 0))
		var id_club := int(float(c.get("id"))) if c.get("id") != null else -1
		Pieces.tuile(fond, Rect2(x, 180, largeur * 0.6 - 6, 130), str(pour), "points", Charte.GAIN if pour > contre else (Charte.PERTE if pour < contre else Charte.IVOIRE), "MatchFenetreMatchScore%d" % k, 70, "", "", false, (func(): ouvrir_fiche_club_id(id_club)) if id_club >= 0 else Callable())
		Pieces.tuile(fond, Rect2(x + largeur * 0.6 + 6, 180, largeur * 0.4 - 6, 130), str(int(c.get("essais", 0))), "essais", Charte.IVOIRE, "MatchFenetreMatchEssais%d" % k, 54)
	Pieces.pastille(fond, 36, 330, "Terminé" if fini else "%d′" % int(rencontre.get("minute", 0)), "check" if fini else "clock", "MatchFenetreMatchMinute", "", Charte.IVOIRE_2 if fini else Charte.GAIN)

# --- Pages du direct : relecture, réglages -----------------------------------------------------
