extends "res://ui/contextual/match_between_joueurs.gd"
## Multiplex des autres matchs de la journée et cartes de match de l'écran intermédiaire du match.

## Écusson du club (logo d'un pack, sinon l'écusson dessiné à ses couleurs), dans une case de `largeur` px.
func _ecusson(club: Dictionary, largeur: int) -> Control:
	var logo: Texture2D = S.G.Base._pack_texture(str(S.G.identity(club).get("logoPath", club.get("logoPath", ""))))
	if logo != null:
		var image := TextureRect.new()
		image.texture = logo
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2.ONE * largeur
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return image
	var case := Control.new()
	case.custom_minimum_size = Vector2.ONE * largeur
	case.mouse_filter = Control.MOUSE_FILTER_IGNORE
	case.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var taille := roundi(largeur * 1.5)
	var dessin: Control = load("res://ui/tenue_club.gd").ecusson(club, taille) if not club.is_empty() else null
	if dessin == null:
		var pastille := Pastille.new()
		pastille.teinte = FAIBLE
		pastille.custom_minimum_size = Vector2.ONE * largeur
		S.full(pastille)
		case.add_child(pastille)
		return case
	dessin.custom_minimum_size = Vector2.ONE * taille
	dessin.size = Vector2.ONE * taille
	dessin.position = Vector2.ONE * float(largeur - taille) / 2.0
	case.add_child(dessin)
	# Initiales de l'écusson dessiné : masquées (le nom est écrit à côté), jamais sous le plancher de 12 px.
	for initiales in dessin.find_children("*", "Label", true, false):
		(initiales as Label).visible = false
		(initiales as Label).add_theme_font_size_override("font_size", maxi(12, (initiales as Label).get_theme_font_size("font_size")))
	return case

## Carte du multiplex des variantes C et D : un bandeau par club à sa couleur (écusson, sigle, essais, score) ; le
## score qui vient de bouger s'allume en vert, avec ce qu'il a rapporté (« +5 »), et clignote.
func _carte_match_v2(m: Dictionary, avant: Array, teintes: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "MatchBetweenMultiplexMatch"
	carte.set_meta("id", str(m.get("id", "")))
	var style := _case(RELIEF, Charte.RAYON_CARTE)
	style.set_content_margin_all(px(6))
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size.x = px(110)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fini := bool(m.get("fini", false))
	var cotes: Array = [m.get("home", {}), m.get("away", {})]
	var change := false
	carte.tooltip_text = "%s %d – %d %s · %s" % [str(cotes[0].get("nom", "")), int(cotes[0].get("score", 0)), int(cotes[1].get("score", 0)), str(cotes[1].get("nom", "")), "terminé" if fini else "%d′" % int(m.get("minute", 0))]
	var colonne := S.G.v(px(4))
	colonne.add_theme_constant_override("separation", px(4))
	carte.add_child(colonne)
	var gains: Array = []
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var gain := int(club.get("score", 0)) - (int(avant[cote]) if avant.size() == 2 else int(club.get("score", 0)))
		gains.append(gain)
		if gain > 0: change = true
	carte.set_meta("change", change)
	# Toute la carte ouvre la petite fenêtre du match (clubs, score, essais, minute).
	carte.mouse_filter = Control.MOUSE_FILTER_STOP
	carte.focus_mode = Control.FOCUS_ALL
	carte.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rencontre := m.duplicate(true)
	carte.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		var touche := e as InputEventKey
		if (clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT) or (touche != null and touche.pressed and touche.keycode in [KEY_ENTER, KEY_KP_ENTER]):
			carte.accept_event()
			match_demande.emit(rencontre))
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var cle := _cle_club(club.get("id"))
		var fond: Color = teintes.get(cle, RELIEF)
		var encre := encre_sur(fond)
		var bande := PanelContainer.new()
		bande.name = "Domicile" if cote == 0 else "Exterieur"
		var style_bande := _case(fond)
		style_bande.content_margin_left = px(6)
		style_bande.content_margin_right = px(4)
		style_bande.content_margin_top = px(2)
		style_bande.content_margin_bottom = px(2)
		bande.add_theme_stylebox_override("panel", style_bande)
		bande.mouse_filter = Control.MOUSE_FILTER_PASS
		colonne.add_child(bande)
		var rangee := S.G.h(px(6))
		rangee.add_theme_constant_override("separation", px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.add_child(rangee)
		rangee.add_child(_ecusson(_clubs_journee.get(cle, club), px(26)))
		var sigle := _cellule(str(club.get("abbr", club.get("nom", ""))), 0, encre, 24)
		sigle.name = "Club"
		sigle.add_theme_font_override("font", TITRES_EXTRA)
		rangee.add_child(sigle)
		var essais := int(club.get("essais", 0))
		if essais > 0:
			var petit := _texte("%d E" % essais, 16, encre, false, true)
			petit.name = "Essais"
			petit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			petit.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rangee.add_child(petit)
		# Match fini : « FIN » sur le premier bandeau ; score qui vient de bouger : ce qu'il a rapporté (« +5 »), écrit.
		var mot := "FIN" if fini and cote == 0 else ("+%d" % gains[cote] if gains[cote] > 0 else "")
		if not mot.is_empty():
			var pastille := PanelContainer.new()
			pastille.name = "Fin" if mot == "FIN" else "Gain"
			var style_p := _case(PANNEAU if mot == "FIN" else Charte.GAIN, Charte.RAYON_PILULE)
			style_p.content_margin_left = px(8)
			style_p.content_margin_right = px(8)
			style_p.content_margin_top = 0
			style_p.content_margin_bottom = 0
			pastille.add_theme_stylebox_override("panel", style_p)
			pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var texte_p := _texte(mot, 16, DOUX if mot == "FIN" else Charte.ENCRE, false, true)
			texte_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pastille.add_child(texte_p)
			rangee.add_child(pastille)
		var boite := PanelContainer.new()
		boite.name = "ScoreCase"
		var marque_style := _case(Charte.GAIN if gains[cote] > 0 else PANNEAU)
		marque_style.content_margin_left = px(6)
		marque_style.content_margin_right = px(6)
		marque_style.content_margin_top = 0
		marque_style.content_margin_bottom = 0
		boite.add_theme_stylebox_override("panel", marque_style)
		boite.custom_minimum_size.x = px(48)
		boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var score := _texte(str(int(club.get("score", 0))), 24, Charte.ENCRE if gains[cote] > 0 else IVOIRE, false, true)
		score.name = "Score"
		score.add_theme_font_override("font", TITRES_EXTRA)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(score)
		rangee.add_child(boite)
		if gains[cote] > 0:
			if not _animations_reduites():
				var clignote := boite.create_tween().set_loops(4)
				clignote.tween_property(boite, "modulate:a", 0.35, 0.3)
				clignote.tween_property(boite, "modulate:a", 1.0, 0.3)
		bande.mouse_filter = Control.MOUSE_FILTER_PASS
		bande.tooltip_text = "%s · %d" % [str(club.get("nom", club.get("abbr", ""))), int(club.get("score", 0))]
	return carte

static func _cle_club(id: Variant) -> String:
	return str(int(id)) if id is float or id is int else str(id)

## Zone qui ouvre la fiche d'un club (ligne du classement, club d'une carte du multiplex) : main au survol, fond
## de survol, clic gauche ou Entrée = `club_demande`. Sans identifiant, la zone reste du texte (rien ne l'invite).
func _cliquable_club(zone: Control, id: Variant, fond_survol: StyleBox = null) -> void:
	if id == null or not (id is int or id is float or (id is String and (id as String).is_valid_int())): return
	var club := int(id) if not id is String else (id as String).to_int()
	zone.set_meta("club_id", club)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.tooltip_text = (zone.tooltip_text + "\n" if not zone.tooltip_text.is_empty() else "") + "Clic : la fiche du club (le match se met en pause)."
	var survol := func(dedans: bool):
		if fond_survol == null or not zone is PanelContainer: return
		if not zone.has_meta("fond_repos"): zone.set_meta("fond_repos", zone.get_theme_stylebox("panel"))
		zone.add_theme_stylebox_override("panel", fond_survol if dedans else zone.get_meta("fond_repos"))
	zone.mouse_entered.connect(survol.bind(true))
	zone.mouse_exited.connect(survol.bind(false))
	zone.focus_entered.connect(survol.bind(true))
	zone.focus_exited.connect(survol.bind(false))
	zone.gui_input.connect(func(event: InputEvent):
		var clic := event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		var entree := event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER]
		if clic or entree:
			zone.accept_event()
			club_demande.emit(club))

## Fond de survol d'une zone cliquable (ligne, carte) : case `PANNEAU_3` rayon 6 (survol de la charte).
func _fond_survol() -> StyleBoxFlat:
	var style := _case(SURVOL)
	style.content_margin_left = px(8)
	style.content_margin_right = px(10)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

## Multiplex : une carte par autre match (deux lignes club et score, essais en petit, minute ou
## « Terminé ») ; liseré vert sur un score qui a changé depuis la minute montrée précédente.
func _remplir_multiplex(journee: Dictionary, teintes: Dictionary) -> void:
	var matchs: Array = journee.get("matchs", []) if journee.get("matchs") is Array else []
	var minute := int(journee.get("minute", 0))
	var scores := {}
	for m: Variant in matchs:
		if m is Dictionary: scores[str(m.get("id", ""))] = [int(m.get("home", {}).get("score", 0)), int(m.get("away", {}).get("score", 0))]
	if minute != _journee_minute:
		if _journee_minute >= 0: _scores_prec = _scores_cour
		_journee_minute = minute
	_scores_cour = scores
	S.clear(multiplex_cartes)
	multiplex.visible = not matchs.is_empty()
	if matchs.is_empty(): return
	multiplex_precision.text = "%d′" % minute if not matchs.all(func(m: Variant): return m is Dictionary and bool(m.get("fini", false))) else "terminé"
	# Une seule rangée, quel que soit le nombre de matchs : ce qui dépasse la largeur défile.
	# Variantes : trois cartes par rangée, tout le multiplex à l'écran sans défiler.
	multiplex_cartes.columns = colonnes_multiplex(matchs.size(), _colonnes_multiplex)
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var id := str(m.get("id", ""))
		var change: bool = _scores_prec.has(id) and _scores_prec[id] != scores[id]
		var carte := _carte_match_v2(m, _scores_prec.get(id, scores[id]) if change else scores[id], teintes)
		carte.name = "MatchBetweenMultiplexMatch%d" % multiplex_cartes.get_child_count()
		multiplex_cartes.add_child(carte)
	_largeur_multiplex()
	_largeur_multiplex.call_deferred()

## Colonnes du multiplex : `voulues` par rangée, trois rangées au plus (au-delà, la rangée s'allonge et défile en largeur).
static func colonnes_multiplex(matchs: int, voulues: int) -> int:
	return maxi(1, maxi(mini(voulues, matchs), ceili(matchs / 3.0)))

## Largeur du multiplex : la colonne de droite (le défilement prend la largeur du panneau) ; au-delà, les
## cartes défilent et « › » le signale.
func _largeur_multiplex() -> void:
	if not is_instance_valid(multiplex_defile) or not is_instance_valid(multiplex_cartes): return
	if not is_zero_approx(multiplex_defile.custom_minimum_size.x): multiplex_defile.custom_minimum_size.x = 0
	# Les cartes tiennent entièrement dans le bloc : on réduit le nombre de colonnes à ce que la largeur permet.
	if multiplex_cartes.get_child_count() > 0 and multiplex_defile.size.x > 1.0:
		var sep: int = multiplex_cartes.get_theme_constant("h_separation")
		var largeur_carte: float = maxf(1.0, (multiplex_cartes.get_child(0) as Control).get_combined_minimum_size().x)
		var tient: int = maxi(1, int(floor((multiplex_defile.size.x + sep) / (largeur_carte + sep))))
		var voulues: int = colonnes_multiplex(multiplex_cartes.get_child_count(), _colonnes_multiplex)
		if tient < voulues: multiplex_cartes.columns = tient
	multiplex_defile.custom_minimum_size.y = multiplex_cartes.get_combined_minimum_size().y
	_fondu_multiplex()

## Fondu du bord droit du multiplex et « › » : seulement quand la rangée dépasse et qu'il reste des cartes
## à droite (rien quand tout tient, rien une fois au bout de la rangée).
func _fondu_multiplex() -> void:
	if not is_instance_valid(multiplex_fondu) or not is_instance_valid(multiplex_defile) or not is_instance_valid(multiplex_cartes): return
	multiplex_fondu.visible = multiplex_deborde() and float(multiplex_defile.scroll_horizontal) + multiplex_defile.size.x < multiplex_cartes.size.x - 1.0

## Vrai quand la rangée de cartes du multiplex est plus large que sa zone de défilement.
func multiplex_deborde() -> bool:
	return is_instance_valid(multiplex_defile) and is_instance_valid(multiplex_cartes) and multiplex_cartes.size.x > multiplex_defile.size.x + 1.0

func _carte_match(m: Dictionary, change: bool, teintes: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "MatchBetweenMultiplexMatch"
	carte.set_meta("id", str(m.get("id", "")))
	carte.set_meta("change", change)
	var style := _case(RELIEF, Charte.RAYON_CARTE)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(4)
	style.content_margin_bottom = px(4)
	if change:
		# Score qui vient de changer : filet gauche épais (jamais un cadre complet), le mot est dans l'infobulle.
		style.border_width_left = maxi(2, px(5))
		style.border_color = VERT_SCORE
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size.x = px(160)
	var fini := bool(m.get("fini", false))
	var cotes: Array = [m.get("home", {}), m.get("away", {})]
	carte.tooltip_text = "%s %d – %d %s · %s" % [str(cotes[0].get("nom", "")), int(cotes[0].get("score", 0)), int(cotes[1].get("score", 0)), str(cotes[1].get("nom", "")), "terminé" if fini else "%d′" % int(m.get("minute", 0))]
	var rang := S.G.h(px(8))
	rang.add_theme_constant_override("separation", px(8))
	carte.add_child(rang)
	var lignes := S.G.v(0)
	lignes.add_theme_constant_override("separation", 0)
	S.G.fill(lignes)
	rang.add_child(lignes)
	var meneur := -1
	if int(cotes[0].get("score", 0)) != int(cotes[1].get("score", 0)): meneur = 0 if int(cotes[0].get("score", 0)) > int(cotes[1].get("score", 0)) else 1
	for cote in 2:
		var club: Dictionary = cotes[cote] if cotes[cote] is Dictionary else {}
		var ligne := S.G.h(px(6))
		ligne.add_theme_constant_override("separation", px(6))
		ligne.name = "Domicile" if cote == 0 else "Exterieur"
		lignes.add_child(ligne)
		var pastille := Pastille.new()
		pastille.teinte = teintes.get(_cle_club(club.get("id")), FAIBLE)
		pastille.custom_minimum_size = Vector2(px(14), px(14))
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(pastille)
		var sigle := str(club.get("abbr", ""))
		var nom_club := _cellule(sigle if not sigle.is_empty() else str(club.get("nom", "")), 0, IVOIRE if meneur == cote or meneur < 0 else DOUX, 26)
		nom_club.name = "Club"
		nom_club.custom_minimum_size.x = px(60)
		ligne.add_child(nom_club)
		var essais := int(club.get("essais", 0))
		var petit := _cellule("(%d)" % essais if essais > 0 else "", 32, FAIBLE, 20, true)
		petit.name = "Essais"
		petit.tooltip_text = "%d essai%s" % [essais, "s" if essais > 1 else ""]
		ligne.add_child(petit)
		var score := _cellule(str(int(club.get("score", 0))), 32, IVOIRE if meneur == cote or meneur < 0 else DOUX, 26, true)
		score.name = "Score"
		ligne.add_child(score)
		petit.mouse_filter = Control.MOUSE_FILTER_PASS
		# Chaque club de la carte mène à sa fiche ; son sigle s'éclaire et se fléche au survol.
		_cliquable_club(ligne, club.get("id"))
		if ligne.has_meta("club_id"):
			ligne.tooltip_text = "%s · clic : sa fiche (le match se met en pause)." % str(club.get("nom", sigle))
			var repos := nom_club.get_theme_color("font_color")
			var texte_club := nom_club.text
			var eclairer := func(dedans: bool):
				nom_club.add_theme_color_override("font_color", IVOIRE if dedans else repos)
				nom_club.text = texte_club + (" →" if dedans else "")
			ligne.mouse_entered.connect(eclairer.bind(true))
			ligne.mouse_exited.connect(eclairer.bind(false))
			ligne.focus_entered.connect(eclairer.bind(true))
			ligne.focus_exited.connect(eclairer.bind(false))
	var heure := _texte("Terminé" if fini else "%d′" % int(m.get("minute", 0)), 22, FAIBLE if fini else OR, false, true)
	heure.name = "Minute"
	heure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heure.custom_minimum_size.x = px(40)
	rang.add_child(heure)
	return carte
