extends "res://ui/contextual/apres_match_bandeau.gd"
## Après-match (apres_match.gd), morceau : colonne de gauche : « Pourquoi », fil du score, Gabi, sous-page « Voir plus ».
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

## Écran et libellé du lien d'un levier : la section où l'on agit (composition, consignes du plan de jeu, entraînement
## de la discipline, condition dans l'effectif, préparation), sinon la route du moteur. {} sans destination.
static func cible_levier(raison: Dictionary) -> Dictionary:
	match str(raison.get("levier", "")):
		"composition": return {"cible": {"kind": "menu", "route": "Composition"}, "libelle": "Revoir la composition"}
		"tactique": return {"cible": {"kind": "menu", "route": "Plan de jeu"}, "libelle": "Ajuster les consignes"}
		"discipline": return {"cible": {"kind": "training", "id": "team"}, "libelle": "Travailler à l’entraînement"}
		"condition": return {"cible": {"kind": "menu", "route": "Effectif"}, "libelle": "Voir la condition"}
		"preparation": return {"cible": {"kind": "menu", "route": "Préparation"}, "libelle": "Préparer la semaine"}
	var route := str(raison.get("route", ""))
	if route.is_empty(): return {}
	return {"cible": {"kind": "menu", "route": route}, "libelle": str(raison.get("action", "Ouvrir " + route))}

## « Pourquoi on a gagné / perdu / ce nul » : trois raisons au plus, du moteur (match-pourquoi.cjs), chacune avec
## son sens (▲ point fort, ▼ à corriger : forme et mot) et le lien vers l'écran de son levier.
func _pourquoi(parent: VBoxContainer) -> void:
	var titre_ligne := _h(16)
	parent.add_child(titre_ligne)
	var titre := _texte({"victoire": "Pourquoi on a gagné", "defaite": "Pourquoi on a perdu", "nul": "Pourquoi ce nul"}.get(issue(), "Pourquoi ce résultat").to_upper(), 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	titre.name = "ApresMatchPourquoiTitre"
	titre_ligne.add_child(titre)
	titre_ligne.add_child(_texte("de la plus décisive à la moins · chaque lien s’ouvre, Espace te ramène ici", 13, Charte.IVOIRE_2))
	var bloc: Variant = _direct().get("pourquoi")
	var raisons: Array = bloc.get("raisons", []) if bloc is Dictionary and bloc.get("raisons") is Array else []
	var cadre := _panneau(Charte.PANNEAU, 0, 0)
	parent.add_child(cadre)
	var liste := _v(0)
	cadre.add_child(liste)
	var serre := _e < 0.8
	var n := 0
	for raison: Variant in raisons:
		if not raison is Dictionary: continue
		n += 1
		var ligne := PanelContainer.new()
		ligne.name = "ApresMatchRaison%d" % int(raison.get("rang", n))
		var style := _fond(Color(0, 0, 0, 0), 20, 8 if serre else 26)
		style.border_width_top = 1
		style.border_color = Charte.FILET
		ligne.add_theme_stylebox_override("panel", style)
		liste.add_child(ligne)
		var r := _h(14)
		ligne.add_child(r)
		var rang := _texte(str(int(raison.get("rang", n))), 34, Charte.IVOIRE_3, Charte.TITRE_EXTRA)
		rang.custom_minimum_size.x = _d(36)
		r.add_child(rang)
		var negatif := str(raison.get("sens", "")) == "negatif"
		var sens := _h(6)
		sens.custom_minimum_size.x = _d(128)
		# « À corriger » : triangle au contour doré, mot en crème (un seul aplat doré par écran : Valider le résultat).
		var fleche := _triangle(not negatif, Charte.PANNEAU if negatif else Charte.IVOIRE) as Trace
		if negatif: fleche.bord = Charte.D
		sens.add_child(fleche)
		var mot_sens := _texte("À CORRIGER" if negatif else "POINT FORT", 13, Charte.IVOIRE, Charte.TITRE)
		mot_sens.name = "Sens"
		sens.add_child(mot_sens)
		r.add_child(sens)
		var levier := _texte(str(raison.get("levierLabel", "")).to_upper(), 15, Charte.IVOIRE, Charte.TITRE_GRAS)
		levier.custom_minimum_size.x = _d(112)
		r.add_child(levier)
		var texte := _texte(str(raison.get("texte", "")), 16, Charte.IVOIRE, Charte.TEXTE, true)
		C.fill(texte)
		r.add_child(texte)
		var levier_cible := cible_levier(raison)
		var action := Control.new()
		if not levier_cible.is_empty():
			action = _lien(str(levier_cible.libelle) + " →", levier_cible.cible, 14, true)
			action.name = "ApresMatchLevier_" + str(raison.get("levier", ""))
			(action as Button).alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action.custom_minimum_size.x = _d(200)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(action)
	if n == 0:
		var vide := _texte("Match trop équilibré pour désigner une cause : les statistiques complètes sont dans « Voir plus ».", 16, Charte.IVOIRE_2, Charte.TEXTE, true)
		vide.name = "ApresMatchSansRaison"
		var m := MarginContainer.new()
		for bord: String in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + bord, _d(20))
		m.add_child(vide)
		liste.add_child(m)
	var plus := _lien("Voir plus : statistiques, notes, journal →", {"kind": "detail", "ouvert": true}, 15, true)
	plus.name = "ApresMatchVoirPlus"
	plus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(plus)

## Fil du score : chaque essai et coup de pied réussi (`direct.marques`), sigle du club, minute, auteur, score.
func _fil_du_score(parent: VBoxContainer) -> void:
	var marques: Variant = _direct().get("marques")
	if not marques is Array or marques.is_empty(): return
	var cadre := _panneau(Charte.PANNEAU, 16, 10)
	cadre.name = "ApresMatchFil"
	parent.add_child(cadre)
	var col := _v(4)
	cadre.add_child(col)
	col.add_child(_texte("FIL DU SCORE", 12, Charte.IVOIRE_2, Charte.TITRE))
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", _d(18))
	flux.add_theme_constant_override("v_separation", _d(4))
	col.add_child(flux)
	var equipes: Array = _live().get("teams", [])
	for m: Variant in marques:
		if not m is Dictionary: continue
		var cote := int(m.get("equipe", -1))
		var club: Dictionary = equipes[cote] if cote >= 0 and cote < equipes.size() and equipes[cote] is Dictionary else {}
		var item := _h(6)
		item.name = "ApresMatchMarque"
		item.tooltip_text = str(m.get("texte", ""))
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_child(_sigle(club, 28, 20, 12))
		item.add_child(_texte(str(m.get("horloge", m.get("minute", ""))).trim_suffix("′").trim_suffix("'") + "′", 15, Charte.IVOIRE, Charte.TITRE_GRAS))
		var nature := nature_marque(m, _e < 0.8)
		var mot := _texte(nature, 12, Charte.IVOIRE_2, Charte.TITRE)
		mot.name = "Nature"
		item.add_child(mot)
		var nom := str(m.get("nom", ""))
		if not nom.is_empty(): item.add_child(_lien_joueur(str(m.get("joueur", "")), nom, cote, 13))
		var buteur: Variant = m.get("buteur")
		if buteur is Dictionary and not str(buteur.get("nom", "")).is_empty():
			item.add_child(_texte("transf.", 12, Charte.IVOIRE_2))
			item.add_child(_lien_joueur(str(buteur.get("joueur", "")), str(buteur.nom), cote, 13))
		var s: Variant = m.get("score")
		if s is Array and s.size() == 2: item.add_child(_texte("%d–%d" % [int(s[0]), int(s[1])], 13, Charte.IVOIRE_2))
		flux.add_child(item)

## Mot écrit d'une marque : « ESSAI », « ESSAI TRANSFORMÉ », « PÉNALITÉ », « DROP » (moteur : `nature`).
## `court` (petites hauteurs) : « ESSAI TR. », « PÉN. ».
static func nature_marque(m: Dictionary, court: bool = false) -> String:
	match str(m.get("nature", "")):
		"essai": return "ESSAI"
		"essai-transforme": return "ESSAI TR." if court else "ESSAI TRANSFORMÉ"
		"penalite": return "PÉN." if court else "PÉNALITÉ"
		"drop": return "DROP"
	return "ESSAI" if str(m.get("kind", "")) == "try" else "PÉNALITÉ OU DROP"

## Gabi : le levier de la semaine tiré des raisons du moteur, et l'homme du match s'il est des nôtres.
func phrase_gabi() -> String:
	var bloc: Variant = _direct().get("pourquoi")
	var raisons: Array = bloc.get("raisons", []) if bloc is Dictionary and bloc.get("raisons") is Array else []
	var negatif := {}
	var positif := {}
	for r: Variant in raisons:
		if not r is Dictionary: continue
		if str(r.get("sens", "")) == "negatif" and negatif.is_empty(): negatif = r
		if str(r.get("sens", "")) != "negatif" and positif.is_empty(): positif = r
	var morceaux: Array[String] = []
	var homme: Variant = _direct().get("hommeDuMatch")
	if homme is Dictionary and int(homme.get("camp", -1)) == _camp() and not str(homme.get("nom", "")).is_empty():
		var chiffres: Array[String] = []
		if int(homme.get("essais", 0)) > 0: chiffres.append("%d essai%s" % [int(homme.essais), "s" if int(homme.essais) > 1 else ""])
		if int(homme.get("plaquages", 0)) > 0: chiffres.append("%d plaquages" % int(homme.plaquages))
		if int(homme.get("metres", 0)) > 0: chiffres.append("%d m gagnés" % int(homme.metres))
		morceaux.append("%s a fait le match%s." % [str(homme.nom), (" : " + ", ".join(PackedStringArray(chiffres))) if not chiffres.is_empty() else ""])
	var levier_neg := str(negatif.get("levierLabel", "")).to_lower()
	var levier_pos := str(positif.get("levierLabel", "")).to_lower()
	match issue():
		"victoire":
			if not levier_neg.is_empty(): morceaux.append("On a gagné malgré la %s : c’est le chantier de la semaine." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("Garde ce qui a marché : la %s." % levier_pos)
		"defaite":
			if not levier_neg.is_empty(): morceaux.append("Pas de panique : le chantier de la semaine, c’est la %s." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("On a perdu, mais la %s a tenu : on repart de là." % levier_pos)
		_:
			if not levier_neg.is_empty(): morceaux.append("Un nul qui se joue à la %s : on la travaille cette semaine." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("Un nul, mais la %s a tenu : on garde cette base." % levier_pos)
	if morceaux.is_empty(): morceaux.append("Rien d’alarmant dans les chiffres : on garde cette base pour la semaine.")
	return " ".join(PackedStringArray(morceaux))

func _gabi(parent: VBoxContainer) -> void:
	# Panneau à 18 qui porte deux cartes à 12 (portrait, bulle), séparées par 12 px de panneau.
	var carte := _panneau(Charte.PANNEAU, 10, 10)
	carte.name = "ApresMatchGabi"
	parent.add_child(carte)
	var rang := _h(12)
	carte.add_child(rang)
	var cadre_portrait := _panneau(Charte.PANNEAU_2, 17, 5, Charte.RAYON_CARTE)
	cadre_portrait.custom_minimum_size = Vector2(_d(116), _d(116))
	rang.add_child(cadre_portrait)
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	cadre_portrait.add_child(portrait)
	var bulle := _panneau(Charte.PANNEAU_2, 24, 12, Charte.RAYON_CARTE)
	C.fill(bulle)
	rang.add_child(bulle)
	var interieur := _h(14)
	bulle.add_child(interieur)
	var filet_club := Trace.new("pave", Charte.club_trait(_couleur(model.get("club", {}) if model.get("club") is Dictionary else {})))
	filet_club.custom_minimum_size = Vector2(_d(8), _d(90))
	filet_club.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interieur.add_child(filet_club)
	var col := _v(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	C.fill(col)
	interieur.add_child(col)
	col.add_child(_texte("GABI, TON ADJOINT", 12, Charte.IVOIRE_2, Charte.TITRE))
	var phrase := _texte("« " + phrase_gabi() + " »", 16, Charte.IVOIRE, Charte.TEXTE, true)
	phrase.name = "ApresMatchGabiPhrase"
	col.add_child(phrase)

func _sous_page(parent: VBoxContainer) -> void:
	var titre := _h(16)
	parent.add_child(titre)
	var t := _texte("LE MATCH EN DÉTAIL", 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	t.name = "ApresMatchDetailTitre"
	titre.add_child(t)
	var retour := _lien("← Retour au pourquoi", {"kind": "detail", "ouvert": false}, 15, true)
	retour.name = "ApresMatchRetour"
	retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.add_child(retour)
	var rang := _h(12)
	rang.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rang)
	# Statistiques comparées du moteur.
	var stats := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(stats, true)
	rang.add_child(stats)
	var col_stats := _v(2)
	stats.add_child(col_stats)
	col_stats.add_child(_texte("STATISTIQUES", 12, Charte.IVOIRE_2, Charte.TITRE))
	var equipes: Array = _live().get("teams", [])
	var entete := _h(6)
	entete.add_child(C.fill(_texte("", 12)))
	for cote in 2: entete.add_child(_cellule_stat(G.club_abbr(equipes[cote]) if cote < equipes.size() and equipes[cote] is Dictionary else "", Charte.IVOIRE_2))
	col_stats.add_child(entete)
	for s: Variant in _live().get("statsRows", []):
		if not s is Dictionary: continue
		var ligne := _h(6)
		var libelle := _texte(str(s.get("label", "")), 13, Charte.IVOIRE_2)
		C.fill(libelle)
		ligne.add_child(libelle)
		ligne.add_child(_cellule_stat(str(s.get("home", ""))))
		ligne.add_child(_cellule_stat(str(s.get("away", ""))))
		col_stats.add_child(ligne)
	# Notes de ton XV.
	var notes := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(notes, true)
	rang.add_child(notes)
	var col_notes := _v(2)
	notes.add_child(col_notes)
	col_notes.add_child(_texte("NOTES DE TON XV", 12, Charte.IVOIRE_2, Charte.TITRE))
	var lignes: Array = []
	var donnees: Variant = _direct().get("notes")
	if donnees is Dictionary:
		for id: Variant in donnees:
			var n: Variant = donnees[id]
			if n is Dictionary and int(n.get("cote", _camp())) == _camp() and _dans_effectif(str(id)): lignes.append([str(id), float(n.get("note", 0.0))])
	lignes.sort_custom(func(a: Array, b: Array): return a[1] > b[1])
	for l: Array in lignes:
		var ligne := _h(6)
		var nom := ""
		for p: Variant in model.get("squad", []):
			if p is Dictionary and str(p.get("id", "")) == l[0]: nom = str(p.get("name", ""))
		var lien := _lien_joueur(l[0], nom, _camp(), 13)
		C.fill(lien)
		ligne.add_child(lien)
		ligne.add_child(_cellule_stat(note_texte(l[1])))
		col_notes.add_child(ligne)
	if lignes.is_empty(): col_notes.add_child(_texte("Notes indisponibles pour ce match.", 13, Charte.IVOIRE_2))
	# Journal complet.
	var journal := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(journal, true, 1.4)
	rang.add_child(journal)
	var col_journal := _v(4)
	journal.add_child(col_journal)
	col_journal.add_child(_texte("JOURNAL DU MATCH", 12, Charte.IVOIRE_2, Charte.TITRE))
	var defile := ScrollContainer.new()
	defile.name = "ApresMatchJournal"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_journal.add_child(defile)
	var lignes_journal := _v(2)
	C.fill(lignes_journal)
	defile.add_child(lignes_journal)
	for ev: Variant in _live().get("events", []):
		var texte := ("%s′  %s" % [str(ev.get("min", "")), str(ev.get("text", ""))]) if ev is Dictionary else str(ev)
		lignes_journal.add_child(_texte(texte, 13, Charte.IVOIRE, Charte.TEXTE, true))

func _cellule_stat(texte: String, couleur: Color = Charte.IVOIRE) -> Label:
	var l := _texte(texte, 13, couleur, Charte.TITRE_GRAS)
	l.custom_minimum_size.x = _d(56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
