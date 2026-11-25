extends "res://ui/contextual/match_between_multiplex.gd"
## Classement en direct, multiplex et météo de l'écran intermédiaire du match.

## Variantes : panneaux de la journée en direct montrés quand ils ont du contenu (A : avec les chiffres clés).
func _montrer_journee_direct() -> void:
	if panneaux_direct.is_empty(): return
	panneaux_direct[0].visible = classement_tuile.visible
	panneaux_direct[1].visible = multiplex.visible
	if panneaux_direct.size() > 2: panneaux_direct[2].visible = classement_tuile.visible
	if multiplex.visible: _largeur_multiplex.call_deferred()

## Panneaux de la journée en direct : le classement complet dans `parent_classement` (en D1 avec l'enjeu dans son
## en-tête), le multiplex (`colonnes` bandeaux par rangée) dans `parent_multiplex`.
func _poser_journee_v2(parent_classement: Control, parent_multiplex: Control, colonnes: int) -> void:
	panneaux_direct.clear()
	_colonnes_multiplex = colonnes
	var cadre_c := _panneau(parent_classement, px(16))
	var panneau_c: Control = cadre_c.get_parent().get_parent()
	panneau_c.name = "MatchBetweenLiveDay0"
	S.G.fill(panneau_c, true, 1.0)
	panneaux_direct.append(panneau_c)
	classement_tuile.get_parent().remove_child(classement_tuile)
	cadre_c.add_child(classement_tuile)
	S.G.fill(classement_tuile, true)
	var cadre_classement := classement_tuile.get_child(0) as Control
	S.G.fill(cadre_classement, true)
	S.G.fill(classement_lignes, true)
	classement_legende = HFlowContainer.new()
	classement_legende.name = "MatchBetweenLiveTableZones"
	classement_legende.add_theme_constant_override("h_separation", px(8))
	classement_legende.add_theme_constant_override("v_separation", px(6))
	cadre_classement.add_child(classement_legende)
	var cadre_m := _panneau(parent_multiplex, px(16))
	var panneau_m: Control = cadre_m.get_parent().get_parent()
	panneau_m.name = "MatchBetweenLiveDay1"
	panneaux_direct.append(panneau_m)
	multiplex.get_parent().remove_child(multiplex)
	cadre_m.add_child(multiplex)
	S.G.fill(multiplex, true)
	S.G.fill(multiplex_cartes)
	for panneau: Control in panneaux_direct: panneau.visible = false

## D1 : notre rang officiel → notre rang si le score en restait là, pastille aux couleurs du gain ou de la perte.
func _poser_enjeu(classement: Array) -> void:
	if not is_instance_valid(enjeu_pastille): return
	var nous: Dictionary = {}
	for r: Variant in classement:
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	# Planche A/B : « si ça finit ainsi » reste dans l'en-tête du classement (notre ligne y est marquée) ; la tuile laisse la place.
	enjeu_pastille.visible = false
	if nous.is_empty(): return
	var rang := int(nous.get("rang", 0))
	var officiel: int = int(nous.rangOfficiel) if nous.get("rangOfficiel") != null else rang
	var teinte: Color = Charte.GAIN if rang < officiel else (Charte.PERTE if rang > officiel else IVOIRE)
	S.clear(enjeu_pastille)
	var rangee := S.G.h(px(10))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enjeu_pastille.add_child(rangee)
	var titre := _texte("SI ÇA FINIT AINSI", 18, DOUX, false, true)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(titre)
	rangee.add_child(titre)
	var fleche := Fleche.new()
	fleche.delta = officiel - rang
	fleche.custom_minimum_size = Vector2(px(30), px(30))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(fleche)
	fleche.visible = officiel != rang
	var texte := _texte("%s → %s" % [_rang_texte(officiel), _rang_texte(rang)] if officiel != rang else _rang_texte(rang), 34, teinte, false, true)
	texte.add_theme_font_override("font", Charte.TITRE_FICHE)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(texte)
	var points := _texte("%d pts" % int(nous.get("points", 0)), 24, IVOIRE, false, true)
	points.add_theme_font_override("font", TITRES_EXTRA)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(points)
	enjeu_pastille.tooltip_text = "Classement si le score en restait là : %s, %d pts" % [_rang_texte(rang), int(nous.get("points", 0))]
	# Clic : la petite fenêtre de notre club (rang, points, forme).
	if nous.get("clubId") != null and not enjeu_pastille.has_meta("club_id"): _cliquable_club(enjeu_pastille, nous.get("clubId"), _fond_survol())

## Clubs connus (pour les écussons) et zones de la poule du classement en direct.
func _clubs_et_zones(model: Dictionary, equipes: Array, classement: Array) -> void:
	_clubs_journee = {}
	var ids := {}
	for r: Variant in classement:
		if r is Dictionary: ids[_cle_club(r.get("clubId"))] = true
	_zones_journee = []
	for division: Variant in model.get("leagues", []):
		if not division is Dictionary: continue
		var dedans := 0
		for club: Variant in division.get("rows", []):
			if club is Dictionary and club.get("id") != null:
				_clubs_journee[_cle_club(club.id)] = club
				if ids.has(_cle_club(club.id)): dedans += 1
		if _zones_journee.is_empty() and dedans > 0 and dedans == ids.size() and division.get("zones") is Array: _zones_journee = division.zones
	for club: Variant in equipes + [model.get("club")]:
		if club is Dictionary and club.get("id") != null and not _clubs_journee.has(_cle_club(club.id)): _clubs_journee[_cle_club(club.id)] = club

## Ligne du classement complet (C et D) : symbole de zone, rang, mouvement ▲▼ chiffré, écusson, sigle et nom, forme
## (C) ou différence (D), bonus de la journée, points. Notre ligne sur un aplat à la couleur du club, liseré épais.
func _ligne_classement_v2(r: Dictionary, teintes: Dictionary) -> Control:
	var nous := bool(r.get("nous", false))
	var rang_n := int(r.get("rang", 0))
	var zone := _zone_rang(rang_n)
	var kind := str(zone.get("kind", ""))
	var club_cle := _cle_club(r.get("clubId"))
	var club: Dictionary = _clubs_journee.get(club_cle, {})
	var teinte: Color = teintes.get(club_cle, FAIBLE)
	var ligne := PanelContainer.new()
	ligne.name = "MatchBetweenLiveRow%d" % rang_n
	ligne.set_meta("rang", rang_n)
	ligne.set_meta("nous", nous)
	ligne.set_meta("zone", kind)
	var fond := StyleBoxFlat.new()
	fond.anti_aliasing = true
	fond.set_corner_radius_all(Charte.RAYON_PETIT)
	fond.content_margin_left = px(8)
	fond.content_margin_right = px(10)
	if nous:
		fond.bg_color = teinte.lerp(PANNEAU, 0.35)
		fond.border_width_left = maxi(3, px(8))
		fond.border_color = Charte.club_trait(teinte)
	else:
		fond.bg_color = Color(0, 0, 0, 0)
		if not kind.is_empty():
			fond.border_width_left = maxi(2, px(5))
			fond.border_color = _teinte_zone(kind)
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.custom_minimum_size.y = px(26)
	ligne.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var encre := encre_sur(fond.bg_color) if nous else IVOIRE
	var delta := int(r.get("delta", 0))
	var nom := str(r.get("nom", ""))
	ligne.tooltip_text = "%d. %s · %d pts · %d joués · %d-%d-%d · différence %+d%s%s" % [rang_n, nom if not nom.is_empty() else str(r.get("abbr", "")), int(r.get("points", 0)), int(r.get("joues", 0)), int(r.get("gagnes", 0)), int(r.get("nuls", 0)), int(r.get("perdus", 0)), int(r.get("diff", 0)),
		("" if r.get("rangOfficiel") == null else " · %s au classement officiel" % _rang_texte(int(r.rangOfficiel))), ("\n" + str(zone.get("label", ""))) if not zone.is_empty() else ""]
	var rangee := S.G.h(px(8))
	rangee.add_theme_constant_override("separation", px(10))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(rangee)
	var marque := MarqueZone.new()
	marque.name = "Zone"
	marque.kind = kind
	marque.teinte = _teinte_zone(kind) if not nous else encre
	marque.custom_minimum_size = Vector2(px(16), px(16))
	marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(marque)
	var numero := _cellule(str(rang_n), 34, encre, 23, true)
	numero.name = "Rang"
	numero.add_theme_font_override("font", TITRES_EXTRA)
	rangee.add_child(numero)
	# Mouvement en direct : flèche (forme) et nombre de places, vert si on monte, rouge si on descend.
	var mouvement := S.G.h(px(2))
	mouvement.name = "Mouvement"
	mouvement.custom_minimum_size.x = px(48)
	mouvement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fleche := Fleche.new()
	fleche.name = "Evolution"
	fleche.delta = delta
	fleche.custom_minimum_size = Vector2(px(22), px(22))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouvement.add_child(fleche)
	if delta != 0:
		var places := _texte(str(absi(delta)), 22, Charte.GAIN if delta > 0 else Charte.PERTE, false, true)
		places.add_theme_font_override("font", TITRES_EXTRA)
		places.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		places.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouvement.add_child(places)
	rangee.add_child(mouvement)
	var ecusson := _ecusson(club, px(26))
	ecusson.name = "Ecusson"
	rangee.add_child(ecusson)
	# Le nom du club en entier (jamais « … ») : l'écusson porte l'identité, le nom prend la place du sigle et sa taille
	# baisse s'il le faut (au-delà : deux lignes).
	var nom_long := _cellule(nom if not nom.is_empty() else str(r.get("abbr", "")), 0, encre, 21)
	nom_long.name = "Nom"
	nom_long.add_theme_font_override("font", TITRES)
	nom_long.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	nom_long.set_meta("taille_base", nom_long.get_theme_font_size("font_size"))
	nom_long.set_meta("sigle", str(r.get("abbr", "")))
	nom_long.resized.connect(_ajuster_taille.bind(nom_long))
	rangee.add_child(nom_long)
	var diff := int(r.get("diff", 0))
	var ecart := _cellule("%+d" % diff, 52, encre if nous else (Charte.GAIN if diff > 0 else (Charte.PERTE if diff < 0 else DOUX)), 19, true)
	ecart.name = "Diff"
	rangee.add_child(ecart)
	for badge: Array in [["bonusOff", "BO", "bonus offensif"], ["bonusDef", "BD", "bonus défensif"]]:
		var nombre := int(r.get(badge[0], 0)) if r.get(badge[0]) != null else 0
		if nombre <= 0: continue
		var pastille_bonus := PanelContainer.new()
		pastille_bonus.name = "Badge" + str(badge[1])
		var style_b := _case(Charte.GAIN if badge[1] == "BO" else Charte.MORAL)
		style_b.content_margin_left = px(6)
		style_b.content_margin_right = px(6)
		style_b.content_margin_top = 0
		style_b.content_margin_bottom = 0
		pastille_bonus.add_theme_stylebox_override("panel", style_b)
		pastille_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille_bonus.tooltip_text = "%d %s%s" % [nombre, badge[2], "s" if nombre > 1 else ""]
		pastille_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		var texte_b := _texte(str(badge[1]), 16, Charte.ENCRE, false, true)
		texte_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille_bonus.add_child(texte_b)
		rangee.add_child(pastille_bonus)
	var points := _cellule(str(int(r.get("points", 0))), 46, encre, 24, true)
	points.name = "Points"
	points.add_theme_font_override("font", TITRES_EXTRA)
	rangee.add_child(points)
	# Rayure une ligne sur deux et survol de ligne communs (ui/survol_ligne.gd, comme l'Effectif) ; la bande de zone à
	# gauche reste visible (le liseré du club commence après elle), notre ligne garde son aplat.
	var fond_ligne = SurvolLigne.poser(ligne, false, Color.TRANSPARENT, float(Charte.RAYON_PETIT), float(fond.border_width_left))
	fond_ligne.rang_fixe = rang_n - 1
	fond_ligne.sans_rayure = nous
	_cliquable_club(ligne, r.get("clubId"))
	return ligne

## Légende des zones présentes : pastille symbole, rangs et mot court (« ● 1–6 Phase finale »).
func _poser_legende_zones(classement: Array) -> void:
	if not is_instance_valid(classement_legende): return
	S.clear(classement_legende)
	for z: Variant in _zones_journee:
		if not z is Dictionary or int(z.get("from", 0)) > classement.size(): continue
		var pastille := PanelContainer.new()
		pastille.name = "MatchBetweenZone_" + str(z.get("kind", ""))
		var style := _case(RELIEF, Charte.RAYON_PILULE)
		style.content_margin_left = px(10)
		style.content_margin_right = px(12)
		style.content_margin_top = px(2)
		style.content_margin_bottom = px(2)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.tooltip_text = "%s · %s" % [Zones.span_text(z), str(z.get("label", ""))]
		pastille.mouse_filter = Control.MOUSE_FILTER_PASS
		var rangee := S.G.h(px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(rangee)
		var marque := MarqueZone.new()
		marque.kind = str(z.get("kind", ""))
		marque.teinte = _teinte_zone(marque.kind)
		marque.custom_minimum_size = Vector2(px(14), px(14))
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(marque)
		var texte := _texte("%s  %s" % [Zones.span_text(z), Zones.short_label(z)], 17, IVOIRE, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(texte)
		classement_legende.add_child(pastille)

## En-tête d'un panneau de la colonne de droite : titre et « ← Retour aux chiffres » (Échap).
func _retour_droite(titre: String) -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _titre_bloc(titre, 24)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	var retour := _lien("← Chiffres clés", func(): montrer_droite("chiffres"))
	retour.tooltip_text = "Revenir aux chiffres clés · Échap"
	ligne.add_child(retour)
	return ligne

## Pastille météo du terrain 2D (données du moteur `live.meteo`) : vent, sens et force, pluie, chaleur ; infobulle complète.
func _poser_meteo(live: Dictionary) -> void:
	if not is_instance_valid(meteo_pastille): return
	var m := Meteo.meteo(live)
	var p := meteo_pastille as PastilleMeteo
	p.vent = int(m.get("vent", 0)) if m.get("vent") != null else 0
	p.pluie = int(m.get("pluie", 0)) if m.get("pluie") != null else 0
	p.chaleur = int(m.get("chaleur", 0)) if m.get("chaleur") != null else 0
	var periode := 2 if live.get("atBreak", false) else int(live.get("period", 1))
	var dos := Meteo.camp_vent(live, periode)
	# Le camp 0 attaque vers la droite du terrain : le vent dans son dos souffle vers la droite.
	p.sens = (1 if dos == 0 else -1) if dos in [0, 1] else 0
	p.visible = not live.get("finished", false) and (p.vent > 0 or p.pluie > 0 or p.chaleur > 0)
	var h := float(maxi(22, px(36)))
	p.size = Vector2(p.largeur(h), h)
	p.position = Vector2(px(10), px(8))
	p.tooltip_text = Meteo.bandeau(live) + ("\n" + Meteo.conseil(live) if not Meteo.conseil(live).is_empty() else "")
	p.queue_redraw()

## Panneau de la colonne de droite : « chiffres », « reglages », « journee », « delegation ». Le panneau
## d'arrêt passe devant tant que le match attend la décision du manager.
func montrer_droite(vue: String) -> void:
	vue_droite = vue if vue in ["chiffres", "reglages", "journee", "delegation"] else "chiffres"
	# Variantes : la journée en direct est déjà à l'écran, « Autres matchs » revient aux chiffres clés.
	if not panneaux_direct.is_empty() and vue_droite == "journee": vue_droite = "chiffres"
	if not is_instance_valid(panneau_chiffres): return
	var arret_montre := is_instance_valid(arret) and not _arret.is_empty()
	panneau_chiffres.visible = not arret_montre and vue_droite == "chiffres"
	panneau_parametres.visible = not arret_montre and vue_droite == "reglages"
	panneau_journee.visible = not arret_montre and vue_droite == "journee"
	panneau_delegation.visible = not arret_montre and vue_droite == "delegation"
	if is_instance_valid(arret): arret.visible = arret_montre
	if vue_droite == "journee": _largeur_multiplex.call_deferred()
	_montrer_journee_direct()
	_poser_principal(arret_montre)

func _poser_principal(arret_montre: bool) -> void:
	if not is_instance_valid(equipe) or _equipe_pleine == not arret_montre: return
	_equipe_pleine = not arret_montre
	_habiller(equipe, _equipe_pleine)
	equipe.add_theme_font_override("font", TITRES_EXTRA)
	equipe.add_theme_font_size_override("font_size", fpx(24 * BARRE_HAUT))
	equipe.custom_minimum_size.y = maxi(26, px(46 * BARRE_HAUT))

## Journée en direct (`direct.journee`) : classement en direct et multiplex, masqués sans elle.
func _remplir_journee(model: Dictionary, direct: Dictionary, equipes: Array) -> void:
	if not is_instance_valid(classement_tuile) or not is_instance_valid(multiplex): return
	var journee: Variant = direct.get("journee")
	if not journee is Dictionary: journee = null
	var cle := JSON.stringify(journee)
	if cle == _journee_cle: return
	_journee_cle = cle
	journee_vue = journee
	if journee == null:
		classement_tuile.visible = false
		multiplex.visible = false
		journee_vide.visible = true
		_journee_minute = -1
		_scores_cour = {}
		_scores_prec = {}
		if vue_droite == "journee": montrer_droite("chiffres")
		_montrer_journee_direct()
		return
	var teintes := _teintes_clubs(model, equipes)
	_clubs_et_zones(model, equipes, journee.get("classement", []) if journee.get("classement") is Array else [])
	_remplir_classement(journee.get("classement", []) if journee.get("classement") is Array else [], teintes)
	_poser_enjeu(journee.get("classement", []) if journee.get("classement") is Array else [])
	_remplir_multiplex(journee, teintes)
	journee_vide.visible = not classement_tuile.visible and not multiplex.visible
	_montrer_journee_direct()

func _journee_montree() -> bool:
	return is_instance_valid(classement_tuile) and classement_tuile.visible

## Couleur de chaque club connu du modèle (tableaux des ligues, notre club, les deux équipes du
## match), par identifiant ; un club sans couleur reste neutre.
static func _teintes_clubs(model: Dictionary, equipes: Array) -> Dictionary:
	var clubs: Array = []
	for division: Variant in model.get("leagues", []):
		if division is Dictionary: clubs.append_array(division.get("rows", []))
	clubs.append(model.get("club"))
	clubs.append_array(equipes)
	var teintes := {}
	for club: Variant in clubs:
		if not club is Dictionary or club.get("id") == null: continue
		var c := str(S.G.identity(club).get("color", club.get("color", "")))
		if c.begins_with("#") and (c.length() == 7 or c.length() == 9): teintes[_cle_club(club.get("id"))] = Color(c)
	return teintes

## Lignes montrées du classement (indices ; -1 pour « … ») : tout le tableau s'il tient, sinon le
## haut du tableau et notre voisinage (trois places de part et d'autre), sans défilement.
static func lignes_classement(classement: Array, capacite: int = CLASSEMENT_LIGNES) -> Array:
	var n := classement.size()
	if n <= capacite: return range(n)
	var nous := -1
	for k in n:
		if classement[k] is Dictionary and bool(classement[k].get("nous", false)): nous = k
	if nous < 0: return range(capacite)
	var fenetre := mini(7, capacite)
	# Notre club au milieu de la fenêtre (± 3 places sur sept, ± 2 sur cinq).
	var debut := clampi(nous - floori(fenetre / 2.0), 0, n - fenetre)
	var fin := debut + fenetre
	var restants := capacite - fenetre
	if debut <= restants: return range(maxi(capacite, fin))
	if restants < 2: return range(debut, fin)
	var lignes: Array = range(restants - 1)
	lignes.append(-1)
	lignes.append_array(range(debut, fin))
	return lignes

func _remplir_classement(classement: Array, teintes: Dictionary) -> void:
	S.clear(classement_lignes)
	classement_tuile.visible = not classement.is_empty()
	if classement.is_empty(): return
	if true:
		# Le classement complet de la poule, sans défilement.
		for r: Variant in classement:
			if r is Dictionary: classement_lignes.add_child(_ligne_classement_v2(r, teintes))
		_poser_legende_zones(classement)
		return
	# Notre voisinage (± 3 places) ; en 1280×720, ± 2 places : la colonne de droite tient dans l'écran.
	for k: int in lignes_classement(classement, CLASSEMENT_ECRAN_720 if not panneaux_direct.is_empty() else CLASSEMENT_LIGNES if _densite >= 0.6 else CLASSEMENT_ECRAN):
		if k < 0:
			var ellipse := _texte("…", 22, FAIBLE)
			ellipse.name = "MatchBetweenLiveTableGap"
			ellipse.custom_minimum_size.y = px(22)
			ellipse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			classement_lignes.add_child(ellipse)
			continue
		if classement[k] is Dictionary: classement_lignes.add_child(_ligne_classement(classement[k], teintes))

## Ligne du classement : rang, évolution, pastille du club, sigle et nom, badges de bonus, points.
## Notre club sur la ligne choisie de la charte (`SELECTION`, rayon 6) ; filet entre les lignes, sans bandes.
func _ligne_classement(r: Dictionary, teintes: Dictionary) -> Control:
	var nous := bool(r.get("nous", false))
	var ligne := PanelContainer.new()
	ligne.name = "MatchBetweenLiveRow%d" % int(r.get("rang", 0))
	ligne.set_meta("rang", int(r.get("rang", 0)))
	ligne.set_meta("nous", nous)
	var fond := _case(Charte.SELECTION if nous else Color(0, 0, 0, 0), Charte.RAYON_PETIT if nous else 0)
	fond.content_margin_left = px(8)
	fond.content_margin_right = px(10)
	fond.content_margin_top = 0
	fond.content_margin_bottom = 0
	if not nous:
		fond.border_width_bottom = 1
		fond.border_color = TRAIT
	ligne.add_theme_stylebox_override("panel", fond)
	ligne.custom_minimum_size.y = px(32)
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var delta := int(r.get("delta", 0))
	var nom := str(r.get("nom", ""))
	ligne.tooltip_text = "%d. %s · %d pts · %d joués · différence %+d%s" % [int(r.get("rang", 0)), nom if not nom.is_empty() else str(r.get("abbr", "")), int(r.get("points", 0)), int(r.get("joues", 0)), int(r.get("diff", 0)),
		("" if r.get("rangOfficiel") == null else " · %s au classement officiel" % ("%de" % int(r.rangOfficiel) if int(r.rangOfficiel) > 1 else "1er"))]
	var rang := S.G.h(px(8))
	rang.add_theme_constant_override("separation", px(8))
	ligne.add_child(rang)
	var numero := _cellule(str(int(r.get("rang", 0))), 36, OR if nous else DOUX, 26, true)
	numero.name = "Rang"
	rang.add_child(numero)
	var fleche := Fleche.new()
	fleche.name = "Evolution"
	fleche.delta = delta
	fleche.custom_minimum_size = Vector2(px(22), px(22))
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fleche.tooltip_text = "Gagne %d place%s" % [delta, "s" if delta > 1 else ""] if delta > 0 else ("Perd %d place%s" % [-delta, "s" if delta < -1 else ""] if delta < 0 else "Même place")
	rang.add_child(fleche)
	var pastille := Pastille.new()
	pastille.name = "Couleur"
	pastille.teinte = teintes.get(_cle_club(r.get("clubId")), FAIBLE)
	pastille.custom_minimum_size = Vector2(px(18), px(18))
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(pastille)
	var sigle := str(r.get("abbr", ""))
	var club := _cellule(sigle if not sigle.is_empty() else nom, 0, IVOIRE, 26)
	club.name = "Club"
	rang.add_child(club)
	for badge: Array in [["bonusOff", "BO", "bonus offensif"], ["bonusDef", "BD", "bonus défensif"]]:
		var nombre := int(r.get(badge[0], 0)) if r.get(badge[0]) != null else 0
		if nombre <= 0: continue
		var pastille_bonus := PanelContainer.new()
		pastille_bonus.name = "Badge" + str(badge[1])
		var style := _case(Charte.VOILE_VERT if badge[1] == "BO" else RELIEF)
		style.content_margin_left = px(6)
		style.content_margin_right = px(6)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		pastille_bonus.add_theme_stylebox_override("panel", style)
		pastille_bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille_bonus.tooltip_text = "%d %s%s" % [nombre, badge[2], "s" if nombre > 1 else ""]
		pastille_bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		var texte := _texte(str(badge[1]), 20, VERT_SCORE if badge[1] == "BO" else DOUX, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille_bonus.add_child(texte)
		rang.add_child(pastille_bonus)
	var points := _cellule(str(int(r.get("points", 0))), 44, OR if nous else IVOIRE, 26, true)
	points.name = "Points"
	rang.add_child(points)
	fleche.mouse_filter = Control.MOUSE_FILTER_PASS
	_cliquable_club(ligne, r.get("clubId"), _fond_survol())
	return ligne
