extends "res://ui/contextual/match_between_xv.gd"
## Fil des faits, chiffres clés, bonus et tableau de bord FM de l'écran intermédiaire du match.

func _remplir_evenements(reperes: Array, equipes: Array) -> void:
	if not is_instance_valid(evenements): return
	var cle := JSON.stringify([reperes, terrain.couleurs])
	if cle == _evenements_cle: return
	_evenements_cle = cle
	S.clear(evenements)
	var haut := domination._haut()
	var teintes := _teintes_duel()
	var tete := S.G.h(px(8))
	evenements.add_child(tete)
	for k in 2:
		var cote := haut if k == 0 else 1 - haut
		var club: Dictionary = equipes[cote] if cote < equipes.size() and equipes[cote] is Dictionary else {}
		var sigle := _texte(S.G.club_abbr(club) if not club.is_empty() else "", 24, IVOIRE, false, true)
		sigle.add_theme_font_override("font", Charte.TITRE_FICHE)
		sigle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k == 0 else HORIZONTAL_ALIGNMENT_LEFT
		S.G.fill(sigle)
		if k == 1:
			var milieu := _texte("", 20, DOUX)
			milieu.custom_minimum_size.x = px(70)
			tete.add_child(milieu)
		tete.add_child(sigle)
	var trait_ligne := ColorRect.new()
	trait_ligne.color = TRAIT
	trait_ligne.custom_minimum_size.y = 1
	evenements.add_child(trait_ligne)
	if reperes.is_empty():
		var vide := _texte("—", 24, FAIBLE, false, true)
		vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		evenements.add_child(vide)
		return
	for repere: Variant in reperes.slice(maxi(0, reperes.size() - 3)):
		if not repere is Dictionary: continue
		var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
		var a_gauche := cote == haut
		var ligne := PanelContainer.new()
		ligne.name = "MatchBetweenEvent%d" % int(repere.get("i", -1))
		ligne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		ligne.custom_minimum_size.y = px(38)
		var rangee := S.G.h(px(8))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(rangee)
		var kind := str(repere.get("kind", ""))
		var mot := "Essai" if kind == "try" else ("Carton" if kind == "card" else "Pénalité")
		var qui := str(repere.get("nom", "")).strip_edges()
		var marque: Variant = repere.get("score") if repere.get("score") is Array else domination.scores.get(int(repere.get("i", -1)))
		var score := ("%d-%d" % [int(marque[haut]), int(marque[1 - haut])]) if kind != "card" and marque is Array and (marque as Array).size() == 2 else ""
		var cote_bloc := S.G.h(px(8))
		cote_bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cote_bloc.alignment = BoxContainer.ALIGNMENT_END if a_gauche else BoxContainer.ALIGNMENT_BEGIN
		S.G.fill(cote_bloc)
		var icone := Icone.new()
		icone.kind = "try" if kind == "try" else ("card" if kind == "card" else "goal")
		icone.rouge = bool(repere.get("rouge", false))
		icone.teinte = teintes[0 if a_gauche else 1]
		icone.custom_minimum_size = Vector2(px(30), px(30))
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nom := _texte(qui if not qui.is_empty() else mot, 21, IVOIRE, false, true)
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var points := _texte(score, 19, DOUX, false, true)
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		points.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for piece: Control in ([points, nom, icone] if a_gauche else [icone, nom, points]): cote_bloc.add_child(piece)
		var minute := _texte(str(repere.get("horloge", "")), 21, IVOIRE, false, true)
		minute.add_theme_font_override("font", TITRES_EXTRA)
		minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		minute.custom_minimum_size.x = px(70)
		minute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minute.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var autre := Control.new()
		autre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.G.fill(autre)
		for piece: Control in ([cote_bloc, minute, autre] if a_gauche else [autre, minute, cote_bloc]): rangee.add_child(piece)
		ligne.tooltip_text = "%s · %s · %s" % [mot, str(repere.get("horloge", "")), _nom_club(equipes, cote)] + ("\n" + qui if not qui.is_empty() else "")
		var i := int(repere.get("i", -1))
		if i >= 0:
			ligne.mouse_filter = Control.MOUSE_FILTER_STOP
			ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ligne.gui_input.connect(func(e: InputEvent):
				var clic := e as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
					ligne.accept_event()
					journal_demande.emit(i))
		evenements.add_child(ligne)

## Momentum sous le terrain : titre, barre animée, durée lue (5′).
func _bande_momentum() -> Control:
	var rangee := S.G.h(px(12))
	rangee.name = "MatchBetweenMomentumBar"
	var titre := _titre_bloc("Momentum", 18)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(titre)
	momentum = Momentum.new()
	momentum.name = "MatchBetweenMomentumGauge"
	momentum.densite = _densite
	momentum.reduit = _animations_reduites()
	momentum.custom_minimum_size = Vector2(px(200), px(30))
	momentum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	momentum.tooltip_text = "Qui pousse sur les cinq dernières minutes (domination du moteur)."
	S.G.fill(momentum)
	rangee.add_child(momentum)
	var duree := _texte("5′", 18, DOUX, false, true)
	duree.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(duree)
	return rangee

func _poser_momentum(minutes: Array, equipes: Array, haut: int) -> void:
	if not is_instance_valid(momentum): return
	momentum.teintes = _teintes_duel()
	momentum.sigles = [S.G.club_abbr(equipes[haut]) if equipes.size() == 2 and equipes[haut] is Dictionary else "", S.G.club_abbr(equipes[1 - haut]) if equipes.size() == 2 and equipes[1 - haut] is Dictionary else ""]
	var recent := minutes.slice(maxi(0, minutes.size() - 5))
	var somme := 0.0
	for v: Variant in recent: somme += float(v)
	var moyenne := somme / maxf(1.0, recent.size())
	if haut == 1: moyenne = -moyenne
	momentum.viser(0.5 + clampf(moyenne, -100.0, 100.0) / 200.0)

func _poser_temps_forts(reperes: Array, equipes: Array) -> void:
	if not is_instance_valid(temps_forts): return
	var cle := JSON.stringify([reperes, terrain.couleurs])
	if cle == _temps_forts_cle: return
	_temps_forts_cle = cle
	S.clear(temps_forts)
	var titre := _titre_bloc("Temps forts", 18)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	temps_forts.add_child(titre)
	if reperes.is_empty():
		var vide := _texte("—", 20, FAIBLE, false, true)
		vide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		temps_forts.add_child(vide)
		return
	for repere: Variant in reperes.slice(maxi(0, reperes.size() - 4)):
		if not repere is Dictionary: continue
		var cote := clampi(int(repere.get("equipe", 0)), 0, 1)
		var fond: Color = terrain.couleurs[cote] if terrain.couleurs.size() == 2 else RELIEF
		var encre := encre_sur(fond)
		var pastille := PanelContainer.new()
		pastille.name = "MatchBetweenHighlight%d" % int(repere.get("i", -1))
		var style := _case(fond, Charte.RAYON_PILULE)
		style.content_margin_left = px(6)
		style.content_margin_right = px(12)
		style.content_margin_top = px(2)
		style.content_margin_bottom = px(2)
		pastille.add_theme_stylebox_override("panel", style)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rangee := S.G.h(px(6))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(rangee)
		var kind := str(repere.get("kind", ""))
		var icone := Icone.new()
		icone.kind = "try" if kind == "try" else ("card" if kind == "card" else "goal")
		icone.rouge = bool(repere.get("rouge", false))
		icone.teinte = encre
		icone.custom_minimum_size = Vector2(px(26), px(26))
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(icone)
		var mot := "Essai" if kind == "try" else ("Carton" if kind == "card" else "Pén.")
		var qui := str(repere.get("nom", "")).strip_edges()
		var texte := _texte("%s %s" % [str(repere.get("horloge", "")), qui if not qui.is_empty() else mot], 18, encre, false, true)
		texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texte.clip_text = true
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var largeur_texte := texte.get_theme_font("font").get_string_size(texte.text, HORIZONTAL_ALIGNMENT_LEFT, -1, texte.get_theme_font_size("font_size")).x
		texte.custom_minimum_size.x = minf(px(170), ceilf(largeur_texte) + 2.0)
		texte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(texte)
		pastille.tooltip_text = "%s · %s · %s" % [mot, str(repere.get("horloge", "")), _nom_club(equipes, cote)] + ("\n" + qui if not qui.is_empty() else "")
		var i := int(repere.get("i", -1))
		if i >= 0:
			pastille.mouse_filter = Control.MOUSE_FILTER_STOP
			pastille.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pastille.gui_input.connect(func(e: InputEvent):
				var clic := e as InputEventMouseButton
				if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
					pastille.accept_event()
					journal_demande.emit(i))
		temps_forts.add_child(pastille)

## Un fait vient d'être joué sur le terrain : le fil le montre, le score le suit.
func _fait_joue(item: Dictionary) -> void:
	_remplir_fil()
	# La ligne d'état suit le fait joué (même instant que le bandeau du fil).
	if not _dernier.is_empty() and is_instance_valid(etat): _etat(_dernier[1], _dernier[2], _equipes)
	var marque: Variant = item.get("score")
	if marque is Array and (marque as Array).size() == 2: score_joue.emit(marque)

## Minute à afficher tant que le terrain rejoue des faits en retard sur le moteur (« 1′ »), sinon vide :
## l'horloge du bandeau suit ce que montre le terrain, comme le score.
func horloge_differee() -> String:
	if terrain == null or not terrain.en_retard(): return ""
	return terrain.horloge_montree()

## Score à montrer tant que le terrain rejoue des faits en retard sur le moteur, sinon vide.
func score_differe() -> Array:
	if terrain == null or not terrain.en_retard() or terrain.joue.is_empty(): return []
	var marque: Variant = terrain.joue.get("score")
	return marque if marque is Array and (marque as Array).size() == 2 else []

## Fil : une ligne n'y entre qu'une fois son fait joué sur le terrain ; le dernier, sous l'en-tête du terrain
## (le journal complet est dans le menu Plus).
func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	var visibles: Array = []
	var prochain := terrain.prochain_i()
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	# Le dernier fait joué ; il apparaît en fondu (sauf animations réduites).
	if not visibles.is_empty():
		var ligne := _ligne_fil(visibles[-1], true, true)
		fil.add_child(ligne)
		var i := int(visibles[-1].get("i", -1))
		if i != _dernier_fait and not _animations_reduites() and is_inside_tree():
			ligne.modulate.a = 0.0
			create_tween().tween_property(ligne, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		_dernier_fait = i
	else: fil.add_child(_texte("Le coup d’envoi approche.", 19, DOUX))

## Occasion de la photo de fin de match : finale, victoire bonifiée selon la règle du championnat (`fin.bonus`,
## calculé par le moteur : 3 essais d'écart en Top 14, 4 essais marqués en Premiership et URC…), sinon championnat.
## Sans bonus en jeu (élimination directe, amical), jamais de victoire bonifiée.
static func occasion_fin(fin: Dictionary, resultat: String) -> String:
	if fin.get("finale", false) and resultat != "nul": return "finale"
	var bonus: Variant = fin.get("bonus")
	if resultat == "victoire" and bonus is Dictionary and bonus.get("offensif") is Dictionary and bool(bonus.offensif.get("acquis", false)): return "bonus"
	return "championnat"

## Image de la banque pour un fait du moteur ("" : fait sans photo).
static func photo_du_fait(kind: String, texte: String) -> String:
	match kind:
		"try": return "action-essai"
		"transformation": return "action-transformation"
		"goal", "penalty", "miss": return "action-coup-de-pied-but"
		"card": return "action-carton-rouge" if texte.to_lower().contains("rouge") else "action-carton-jaune"
		"scrum": return "action-melee"
		"lineout": return "action-touche"
		"turnover", "hand-fault": return "action-ballon-perdu"
		"carry": return "action-franchissement"
	var t := texte.to_lower()
	if t.contains("vidéo") or t.contains("tmo"): return "action-arbitrage-video"
	if t.contains("bless") or t.contains("soign"): return "action-blessure-soins"
	if t.contains("remplac") or t.contains("entre en jeu"): return "action-remplacement"
	return ""

## Ligne du fil : minute, pictogramme du fait cerclé au camp (nous vert clair, eux doré), texte (une ligne, le reste en infobulle).
func _ligne_fil(entree: Dictionary, dernier: bool, en_bandeau: bool) -> Control:
	var kind := str(entree.get("kind", ""))
	var points := kind in ["try", "goal", "transformation"]
	var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
	var notre_camp := int(_dernier[2].get("camp", 0)) if _dernier.size() > 2 and _dernier[2] is Dictionary else 0
	var teinte: Color = (Charte.V if equipe == notre_camp else Charte.D) if equipe in [0, 1] else FAIBLE
	var ligne := PanelContainer.new()
	ligne.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ligne.set_meta("i", int(entree.get("i", -1)))
	ligne.name = "MatchBetweenFeedLine"
	# Le dernier fait mène au journal, à ce fait (clic) ; son acteur, s'il est des nôtres, à sa mini-fiche (survol).
	ligne.mouse_filter = Control.MOUSE_FILTER_STOP
	ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ligne.tooltip_text = str(entree.get("texte", "")) + "\nClic : le journal du match à ce fait."
	var i_fait := int(entree.get("i", -1))
	ligne.gui_input.connect(func(evenement: InputEvent):
		var clic := evenement as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and i_fait >= 0: journal_demande.emit(i_fait))
	var rang := S.G.h(px(10))
	ligne.add_child(rang)
	var heure := _texte(str(entree.get("horloge", "")), 19, IVOIRE if dernier or points else DOUX, false, true)
	heure.custom_minimum_size.x = px(44)
	rang.add_child(heure)
	var icone := Icone.new()
	icone.kind = kind
	icone.teinte = teinte
	icone.rouge = str(entree.get("texte", "")).to_lower().contains("rouge")
	icone.custom_minimum_size = Vector2(px(26), px(26))
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(icone)
	var texte := _texte(str(entree.get("texte", "")), 19, IVOIRE if points else DOUX, true)
	texte.max_lines_visible = 2 if en_bandeau else 1
	texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texte.clip_text = true
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(texte)
	rang.add_child(texte)
	var app_fil: Object = _app()
	if _acteurs.has(i_fait) and app_fil is Control:
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		texte.set_meta("player_id", _acteurs[i_fait])
		MiniFiche.lier(app_fil, texte, str(_acteurs[i_fait]), "squad")
	return ligne

## Valeur affichée d'un chiffre clé pour un côté (0 ou 1 du moteur) ; « — » tant que la donnée est vide.
func _valeur(rang: Dictionary, cote: int) -> String:
	var valeurs: Array = rang.get("valeurs", [0, 0])
	if rang.get("vide", false): return "—"
	var texte := str(int(valeurs[cote])) + (" " + str(rang.unite) if str(rang.get("unite", "")) == "%" else str(rang.get("unite", "")))
	if rang.get("sur") is Array: texte = "%d / %d" % [int(valeurs[cote]), int(rang.sur[cote])]
	return texte

## Chiffre clé face à face (maquette) : libellé centré au-dessus ; notre valeur à gauche, la barre (notre
## part pleine, la leur vide), leur valeur à droite.
func _ligne_chiffre(parent: Control, rang: Dictionary, nous: int) -> void:
	# La ligne entière ouvre les statistiques complètes à ce chiffre (survol : fond plus clair, main).
	var lien := Button.new()
	lien.name = "MatchBetweenFigure_" + str(rang.get("cle", ""))
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	lien.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lien.set_meta("contextual_enabled", true)
	for etat_bouton in ["normal", "hover", "pressed", "focus"]:
		var style := _case(RELIEF if etat_bouton in ["hover", "pressed", "focus"] else Color(0, 0, 0, 0))
		if etat_bouton == "focus": _anneau(style)
		lien.add_theme_stylebox_override(etat_bouton, style)
	var libelle := str(rang.get("stats", rang.get("label", "")))
	var rang_clic := rang.duplicate()
	lien.pressed.connect(func(): stat_demandee.emit(rang_clic))
	lien.set_meta("stat", libelle)
	lien.tooltip_text = "%s : %s %s · %s %s\nClic : les statistiques complètes à cette ligne." % [str(rang.get("label", "")), _nom_club(_equipes, nous), _valeur(rang, nous), _nom_club(_equipes, 1 - nous), _valeur(rang, 1 - nous)]
	var bloc := S.G.v(px(2))
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(bloc)
	lien.add_child(bloc)
	bloc.alignment = BoxContainer.ALIGNMENT_CENTER
	lien.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bloc.minimum_size_changed.connect(func(): lien.custom_minimum_size.y = bloc.get_combined_minimum_size().y)
	var titre := _texte(str(LIBELLES_COURTS.get(str(rang.get("cle", "")), rang.get("label", ""))).to_upper(), 18, DOUX, false, true)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(titre)
	var ligne := S.G.h(px(12))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(ligne)
	var a := _texte(_valeur(rang, nous), 26, IVOIRE)
	a.add_theme_font_override("font", TITRES_EXTRA)
	a.custom_minimum_size.x = px(84)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(a)
	var barre := Barre.new()
	var valeurs: Array = rang.get("valeurs", [0, 0])
	barre.valeurs = [valeurs[nous], valeurs[1 - nous]] if not rang.get("vide", false) else [0, 0]
	# Variantes C et D : les deux clubs à leurs couleurs (la part pleine / vide garde le camp lisible sans la couleur).
	barre.couleurs = _teintes_duel()
	lien.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(80), px(24))
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(barre)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1 - nous), 26, IVOIRE)
	b.add_theme_font_override("font", TITRES_EXTRA)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size.x = px(84)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(b)
	parent.add_child(lien)
	lien.custom_minimum_size.y = bloc.get_combined_minimum_size().y

## Chiffres clés du moteur (`direct.tableau`, `direct.zone22`), vus de notre camp. Deux chiffres sont dérivés
## de données réelles : les entrées dans les 22 (`zone22.entrees`) et la part de plaquages réussis (plaquages
## réussis sur plaquages tentés, manqués compris). Une donnée absente : la ligne est omise.
func _remplir_chiffres(direct: Dictionary, _live: Dictionary) -> void:
	S.clear(chiffres)
	chiffres.add_theme_constant_override("separation", px(10))
	# Premières minutes : un « 100 % / 0 % » ne dit rien. Les parts restent masquées (« — ») et les
	# compteurs atténués jusqu'au seuil du moteur ; la précision dit quand la lecture deviendra fiable.
	echantillon_court = est_court(direct)
	chiffres.modulate = Color(1, 1, 1, ATTENUE) if echantillon_court else Color.WHITE
	if is_instance_valid(precision_chiffres):
		precision_chiffres.text = ("Fiable dès la %de min" % seuil_echantillon(direct)) if echantillon_court else ""
		precision_chiffres.visible = echantillon_court
	var camp := int(direct.get("camp", -1))
	var nous := camp if camp in [0, 1] else 0
	var rangs: Array = direct.get("tableau", [])
	var par_cle := {}
	for rang: Variant in rangs:
		if rang is Dictionary: par_cle[str(rang.get("cle", ""))] = rang
	var z: Variant = direct.get("zone22")
	if z is Dictionary and z.get("entrees") is Array and (z.entrees as Array).size() == 2:
		par_cle["zone22"] = {"cle": "zone22", "label": "Entrées dans les 22 mètres adverses", "stats": "22", "valeurs": [int(z.entrees[0]), int(z.entrees[1])]}
	if par_cle.has("plaquages") and par_cle.has("plaquages_manques"):
		var reussis: Array = par_cle.plaquages.get("valeurs", [0, 0])
		var manques: Array = par_cle.plaquages_manques.get("valeurs", [0, 0])
		var parts: Array = []
		for cote in 2:
			var tentes := int(reussis[cote]) + int(manques[cote])
			parts.append(roundi(100.0 * int(reussis[cote]) / tentes) if tentes > 0 else 0)
		var vide := int(reussis[0]) + int(manques[0]) == 0 or int(reussis[1]) + int(manques[1]) == 0
		par_cle["plaquages_reussis"] = {"cle": "plaquages_reussis", "label": "Plaquages réussis (part des plaquages tentés)", "stats": "Plaquages", "valeurs": parts, "unite": "%", "vide": vide}
	# Toujours le même ordre (« — » tant qu'un chiffre est vide).
	for cle: String in STATS + (STATS_PLUS if _densite >= 0.7 else []):
		if par_cle.has(cle): _ligne_chiffre(chiffres, par_cle[cle], nous)
	_rangs = rangs
	_remplir_barres_fm(par_cle, nous)

## Tuile Bonus : la règle du championnat, l'état vu de notre camp et, en fin de match, le dilemme et ses deux
## consignes (la consigne en place est en or). Rien n'est calculé ici : tout vient de `direct.bonus`.
func _remplir_bonus(model: Dictionary, live: Dictionary, direct: Dictionary) -> void:
	if not is_instance_valid(bonus_tuile): return
	var bonus: Variant = direct.get("bonus")
	var tactiques: Dictionary = model.get("tactics", {}) if model.get("tactics") is Dictionary else {}
	var cle := JSON.stringify([bonus, tactiques.get("attack"), tactiques.get("defense"), tactiques.get("penalty"), live.get("finished", false)])
	if cle == _bonus_cle: return
	_bonus_cle = cle
	bonus_tuile.visible = bonus is Dictionary
	_largeur_multiplex.call_deferred()
	if not bonus is Dictionary: return
	bonus_regle.text = str(bonus.get("regle", ""))
	bonus_regle.tooltip_text = "Règle du championnat : " + str(bonus.get("regle", ""))
	S.clear(bonus_etat)
	for cote: String in ["offensif", "defensif"]:
		var item: Variant = bonus.get(cote)
		if not item is Dictionary or str(item.get("texte", "")).is_empty(): continue
		var teinte := DOUX
		if bool(item.get("acquis", false)) or str(item.get("statut", "")) == "tenu": teinte = MONTEE
		elif bool(item.get("horsDePortee", false)): teinte = FAIBLE
		elif str(item.get("statut", "")) == "perdu" or int(item.get("manque", 0) if item.get("manque") != null else 0) > 0: teinte = OR
		var etiquette := _texte(str(item.texte), 19, teinte, true, true)
		S.G.fill(etiquette)
		etiquette.name = "MatchBetweenBonus_" + cote
		bonus_etat.add_child(etiquette)
	S.clear(bonus_choix)
	var situation: Variant = bonus.get("situation")
	bonus_situation.visible = situation is Dictionary
	bonus_choix.visible = situation is Dictionary
	if not situation is Dictionary: return
	bonus_situation.text = str(situation.get("texte", ""))
	bonus_situation.tooltip_text = bonus_situation.text
	for consigne: Variant in situation.get("consignes", []):
		if not consigne is Dictionary: continue
		var c: Dictionary = consigne
		var en_place := str(tactiques.get("attack", "")) == str(c.get("attack", "")) and str(tactiques.get("defense", "")) == str(c.get("defense", "")) and str(tactiques.get("penalty", "auto")) == str(c.get("penalty", ""))
		# Choix entre deux consignes : la consigne en place est marquée par le mot, le filet épais et la coche.
		var bouton := _bouton(str(c.get("label", "")) + ("  · en place" if en_place else ""), func(): consigne_bonus.emit(c), not live.get("finished", false))
		bouton.name = "MatchBetweenBonusChoice_" + str(c.get("id", ""))
		_style_segment(bouton)
		if en_place:
			bouton.add_theme_stylebox_override("normal", bouton.get_theme_stylebox("pressed"))
			_cocher(bouton, true)
		bouton.custom_minimum_size.y = maxi(px(52), 36)
		bouton.add_theme_font_size_override("font_size", fpx(20))
		bouton.clip_text = true
		bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bouton.tooltip_text = str(c.get("aide", "")) + ("\nConsigne en place." if en_place else "\nLe match se met en pause le temps de la donner.")
		bouton.set_meta("contextual_enabled", true)
		S.G.fill(bouton)
		bonus_choix.add_child(bouton)

## Composition d'un club, côté `k` (0 nous, 1 eux), à la place d'une colonne de chiffres miroir.
func _poser_compo_fm(parent: Control, k: int) -> void:
	var cadre := _panneau(parent, px(14))
	var panneau: Control = cadre.get_parent().get_parent()
	panneau.name = "MatchBetweenLineup%d" % k
	panneau.custom_minimum_size.x = px(320)
	S.G.fill(panneau, true, 0.62)
	S.G.fill(cadre, true)
	var tete := S.G.h(px(10))
	tete.name = "MatchBetweenLineupHead%d" % k
	tete.custom_minimum_size.y = px(40)
	cadre.add_child(tete)
	var trait_club := ColorRect.new()
	trait_club.name = "MatchBetweenLineupStripe%d" % k
	trait_club.custom_minimum_size.y = maxi(2, px(4))
	trait_club.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(trait_club)
	var terrain_compo := Compo.new()
	terrain_compo.name = "MatchBetweenLineupPitch%d" % k
	S.G.fill(terrain_compo, true)
	terrain_compo.choisi.connect(_choix_pastille)
	cadre.add_child(terrain_compo)
	compos_fm.append(terrain_compo)

## Phrase de jeu en grand (l'état du jeu quitte l'en-tête du terrain), liseré à la couleur du club en possession.
func _poser_phrase_fm(parent: Control) -> void:
	phrase_fm = PanelContainer.new()
	phrase_fm.name = "MatchBetweenPlayLine"
	var style := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style.content_margin_left = px(18)
	style.content_margin_right = px(18)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	phrase_fm.add_theme_stylebox_override("panel", style)
	parent.add_child(phrase_fm)
	var ligne := S.G.h(px(16))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phrase_fm.add_child(ligne)
	phrase_trait_fm = ColorRect.new()
	phrase_trait_fm.custom_minimum_size = Vector2(px(8), px(44))
	phrase_trait_fm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(phrase_trait_fm)
	etat.get_parent().remove_child(etat)
	ligne.add_child(etat)
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etat.add_theme_font_override("font", Charte.TITRE_FICHE)
	etat.add_theme_font_size_override("font_size", fpx(36))
	etat.set_meta("taille_base", fpx(36))
	var droite := Control.new()
	droite.custom_minimum_size.x = px(8)
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(droite)

## Rangée du bas du centre : barres miroir des chiffres et courbe cumulée.
func _poser_bas_fm(rang_bas: Control) -> void:
	var cadre := _panneau(rang_bas, px(14))
	var tuile: Control = cadre.get_parent().get_parent()
	tuile.name = "MatchBetweenMirrorBars"
	S.G.fill(tuile, true)
	S.G.fill(cadre, true)
	cadre.add_child(_titre("Chiffres du match"))
	barres_fm = S.G.v(px(2))
	barres_fm.name = "MatchBetweenMirrorBarsRows"
	S.G.fill(barres_fm, true)
	cadre.add_child(barres_fm)
	var cadre_c := _panneau(rang_bas, px(14))
	var tuile_c: Control = cadre_c.get_parent().get_parent()
	tuile_c.name = "MatchBetweenCumulTile"
	S.G.fill(tuile_c, true)
	S.G.fill(cadre_c, true)
	cadre_c.add_child(_titre("Points et occasions", "cumulés"))
	cumul_fm = Cumul.new()
	cumul_fm.name = "MatchBetweenCumul"
	S.G.fill(cumul_fm, true)
	cumul_fm.choisi.connect(func(): if _par_cle_fm.has("zone22"): stat_demandee.emit((_par_cle_fm["zone22"] as Dictionary).duplicate()))
	cadre_c.add_child(cumul_fm)

## Barres miroir (comme le bilan de mi-temps de la référence) : notre valeur et notre barre à gauche, le libellé au
## milieu, la leur à droite ; la barre du club qui mène ce chiffre est pleine. Une ligne ouvre ce chiffre.
func _remplir_barres_fm(par_cle: Dictionary, nous: int) -> void:
	_par_cle_fm = par_cle
	if not is_instance_valid(barres_fm): return
	var cle_barres := JSON.stringify([par_cle, nous, _teintes_duel(), _densite])
	if cle_barres == _barres_cle: return
	_barres_cle = cle_barres
	S.clear(barres_fm)
	for cle: String in STATS_FM:
		if not par_cle.has(cle): continue
		var rang: Dictionary = par_cle[cle]
		var ligne := Button.new()
		ligne.name = "MatchBetweenMirrorBar_%s" % cle
		ligne.flat = true
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for etat_bouton in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = RELIEF if etat_bouton != "normal" else Color(0, 0, 0, 0)
			style.set_corner_radius_all(Charte.RAYON_PETIT)
			if etat_bouton == "focus": _anneau(style)
			ligne.add_theme_stylebox_override(etat_bouton, style)
		var rang_clic := rang.duplicate()
		ligne.pressed.connect(func(): stat_demandee.emit(rang_clic))
		ligne.tooltip_text = str(rang.get("label", ""))
		ligne.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ligne.custom_minimum_size.y = px(22)
		var barre := BarreMiroir.new()
		S.full(barre)
		barre.densite = _densite
		var valeurs: Array = rang.get("valeurs", [0, 0])
		barre.valeurs = [float(valeurs[nous]), float(valeurs[1 - nous])]
		barre.textes = [_valeur(rang, nous), _valeur(rang, 1 - nous)]
		barre.libelle = str(LIBELLES_FM.get(cle, rang.get("label", "")))
		barre.inverse = cle == "penalites"
		barre.vide = bool(rang.get("vide", false))
		barre.teintes = _teintes_duel()
		ligne.add_child(barre)
		barres_fm.add_child(ligne)

## Compositions notées (petits terrains), à chaque image utile.
func _remplir_compos_fm(lineup: Array, direct: Dictionary) -> void:
	if compos_fm.size() != 2: return
	var camp := int(direct.get("camp", -1))
	var nous := camp if camp in [0, 1] else 0
	var infos := _infos_xv(lineup, direct)
	var adverse: Array = direct.get("adversaire", []) if direct.get("adversaire") is Array else []
	var teintes := _teintes_duel()
	var donnees: Array = [[], []]
	for poste in 15:
		var a: Dictionary = infos[poste] if poste < infos.size() and infos[poste] is Dictionary else {"vacant": true}
		donnees[0].append({} if a.get("vacant", false) else {"nom": str(a.get("nom", "")), "note": float(a.get("note", NOTE_DEPART)), "energie": float(a.get("energie", 100)), "id": str(a.get("id", "")), "alerte": str(a.get("alerte", "")), "num": _numero(str(a.get("id", "")), poste + 1)})
		var o: Variant = adverse[poste] if poste < adverse.size() else null
		donnees[1].append({} if not o is Dictionary else {"nom": str(o.get("nom", "")), "note": float(o.get("note", NOTE_DEPART)), "energie": float(o.get("energie")) if o.get("energie") != null else -1.0, "id": "", "alerte": ""})
	for k in 2:
		var cote_club := nous if k == 0 else 1 - nous
		var club: Dictionary = _equipes[cote_club] if cote_club < _equipes.size() and _equipes[cote_club] is Dictionary else {}
		var tete := find_child("MatchBetweenLineupHead%d" % k, true, false) as HBoxContainer
		var trait_club := find_child("MatchBetweenLineupStripe%d" % k, true, false) as ColorRect
		if trait_club != null: trait_club.color = teintes[k]
		if tete == null: continue
		if tete.get_child_count() == 0 and not club.is_empty():
			tete.add_child(_ecusson(club, px(34)))
			var nom := _texte(S.G.club_name(club).to_upper(), 22, IVOIRE, false, true)
			nom.add_theme_font_override("font", Charte.TITRE_FICHE)
			nom.clip_text = true
			nom.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			nom.set_meta("taille_base", nom.get_theme_font_size("font_size"))
			nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			S.G.fill(nom)
			nom.resized.connect(_ajuster_taille.bind(nom))
			tete.add_child(nom)
			var moyenne := PanelContainer.new()
			moyenne.name = "MatchBetweenLineupAverage%d" % k
			moyenne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			moyenne.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tete.add_child(moyenne)
		var somme := 0.0
		var n := 0
		for d: Dictionary in donnees[k]:
			if d.is_empty(): continue
			somme += float(d.note)
			n += 1
		var moy := tete.find_child("MatchBetweenLineupAverage%d" % k, false, false) as PanelContainer
		if moy != null and n > 0:
			S.clear(moy)
			var p := _pastille_note(somme / n)
			moy.add_child(p)
			moy.tooltip_text = "Note moyenne du XV"
	var cle := JSON.stringify([donnees.map(func(c: Array): return c.map(func(d: Dictionary): return [d.get("nom"), d.get("note"), roundi(float(d.get("energie", 0))), d.get("alerte"), d.get("num")])), teintes, _densite, nous])
	if cle == _compos_cle: return
	_compos_cle = cle
	for k in 2:
		var cote := nous if k == 0 else 1 - nous
		var c: Compo = compos_fm[k]
		c.joueurs = donnees[k]
		c.cote = cote
		c.plein = k == 0
		c.teinte = teintes[k]
		c.densite = _densite
		c.queue_redraw()

## Courbe cumulée : points de chaque club en escalier, entrées dans les 22 m en tirets (tranches de 10 min).
func _remplir_cumul_fm(direct: Dictionary) -> void:
	if not is_instance_valid(cumul_fm): return
	cumul_fm.reperes = domination.reperes
	cumul_fm.scores = domination.scores
	cumul_fm.camp = domination.camp
	cumul_fm.teintes = _teintes_duel()
	cumul_fm.densite = _densite
	cumul_fm.minute = domination.minutes.size()
	var periodes: Variant = direct.get("periodes")
	cumul_fm.tranches = (periodes.get("tranches", []) as Array) if periodes is Dictionary and periodes.get("tranches") is Array else []
	cumul_fm.queue_redraw()
