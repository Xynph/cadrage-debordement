extends "res://ui/contextual/match_between_fiche.gd"
## Visages, noms et lignes de joueurs de l'écran intermédiaire du match.

## Note du match en pastille à la couleur de son palier, chiffre écrit (jamais la couleur seule).
func _pastille_note(note: float) -> PanelContainer:
	var teinte := _teinte_note(note)
	var cadre := PanelContainer.new()
	cadre.name = "MatchBetweenPlayerNote"
	var style := _case(teinte, Charte.RAYON_PETIT)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	cadre.add_theme_stylebox_override("panel", style)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := _texte(("%.1f" % note).replace(".", ","), 19, Charte.encre_note(note), false, true)
	texte.add_theme_font_override("font", TITRES_EXTRA)
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texte.custom_minimum_size.x = px(34)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(texte)
	return cadre

## Visage d'un joueur découpé en rond (photo du pack recadrée sur le visage, sinon visage généré), avec son numéro en
## médaillon en bas à gauche ; `energie` >= 0 : cerclé de l'anneau de son énergie (comme Observer la préparation).
func _visage(joueur: Dictionary, cote: int, numero: int, energie: float = -1.0) -> Control:
	var boite := Control.new()
	boite.name = "MatchBetweenFace"
	boite.custom_minimum_size = Vector2(cote, cote)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Même visage que la petite fenêtre du joueur (chargé en différé, photo du pack ou visage généré).
	var anneau_ep := clampf(cote * 0.08, 2.5, float(px(7))) if energie >= 0.0 else 0.0
	var marge := anneau_ep + maxf(1.5, cote * 0.03) if energie >= 0.0 else 0.0
	var diametre := float(cote) - 2.0 * marge
	var disque := Panel.new()
	disque.name = "PortraitDisque"
	var forme := StyleBoxFlat.new()
	forme.bg_color = Charte.PANNEAU_3
	forme.set_corner_radius_all(int(ceilf(diametre / 2.0)))
	forme.anti_aliasing = true
	disque.add_theme_stylebox_override("panel", forme)
	disque.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disque.position = Vector2(marge, marge)
	disque.size = Vector2(diametre, diametre)
	disque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.add_child(disque)
	var agrandi := diametre * 1.18
	var image: TextureRect = S.G.portrait_lazy(int(joueur.get("portraitIndex", 0)), int(agrandi), joueur)
	image.tooltip_text = ""
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	image.position = Vector2((diametre - agrandi) / 2.0, (diametre - agrandi) / 2.0 + diametre * 0.08)
	image.size = Vector2(agrandi, agrandi)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disque.add_child(image)
	if energie >= 0.0:
		var anneau := Visuels.Anneau.new()
		anneau.valeur = energie
		anneau.couleur = Jauge.teinte_vive(energie)
		anneau.epaisseur = anneau_ep
		anneau.size = Vector2(cote, cote)
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(anneau)
	if numero > 0:
		var medaille := PanelContainer.new()
		medaille.name = "MatchBetweenFaceNumber"
		var d := maxi(16, roundi(cote * 0.4))
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.FOND
		style.set_corner_radius_all(Charte.RAYON_PILULE)
		style.anti_aliasing = true
		style.set_content_margin_all(0)
		medaille.add_theme_stylebox_override("panel", style)
		medaille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medaille.position = Vector2(-px(4), cote - d + px(2))
		medaille.size = Vector2(d, d)
		var chiffre := _texte(str(numero), 15, IVOIRE, false, true)
		chiffre.add_theme_font_override("font", TITRES_EXTRA)
		chiffre.add_theme_font_size_override("font_size", maxi(12, roundi(d * 0.6)))
		chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chiffre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medaille.add_child(chiffre)
		boite.add_child(medaille)
	return boite

## Ligne de tableau (24 px à 1920) : bouton plat, filet entre les lignes (pas de bandes), survol `PANNEAU_2`,
## focus `PANNEAU_3` rayon 6 avec l'anneau doré ; son contenu est une rangée de cellules.
func _ligne_joueur(nom: String, _rang: int, action: Callable) -> Button:
	var case := Button.new()
	case.name = nom
	case.flat = true
	case.focus_mode = Control.FOCUS_ALL
	case.set_meta("contextual_enabled", true)
	case.pressed.connect(action)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0)
	fond.border_color = TRAIT
	fond.border_width_bottom = 1
	var survol := _case(RELIEF)
	var focus := _case(SURVOL)
	_anneau(focus)
	for style: StyleBox in [fond, survol, focus]: style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", fond)
	case.add_theme_stylebox_override("pressed", survol)
	case.add_theme_stylebox_override("hover", survol)
	case.add_theme_stylebox_override("focus", focus)
	case.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	S.G.fill(case)
	case.custom_minimum_size.y = maxi(18, px(32))
	var ligne := S.G.h(px(8))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(ligne)
	ligne.offset_left = px(6)
	ligne.offset_right = -px(6)
	case.add_child(ligne)
	return case

## Ligne signalée (épuisé, blessé) : attention de la charte, voile doré en case rayon 6 ; le mot (« épuisé »)
## et le chiffre sont écrits dans la ligne (la couleur ne porte jamais seule l'alerte).
func _marquer_ligne(case: Button) -> void:
	case.set_meta("signale", true)
	var style := _case(Charte.VOILE_DORE)
	style.set_content_margin_all(0)
	case.add_theme_stylebox_override("normal", style)

## Nom du joueur : lien vers sa fiche (clic), mini-fiche au survol ; l'alerte écrite à côté (« épuisé »).
func _nom_joueur(nom: String, id: String, alerte: String = "", humeur: Dictionary = {}) -> Control:
	# Cadre sans taille minimale : la colonne Joueur garde sa largeur, quelle que soit la longueur du nom (un nom trop
	# long s'arrête au bord de la colonne, il reste entier dans la mini-fiche et la fiche).
	var cadre := Control.new()
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.clip_contents = true
	S.G.fill(cadre, true)
	var rangee := S.G.h(px(6))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(rangee)
	cadre.add_child(rangee)
	var lien := Button.new()
	lien.name = "MatchBetweenPlayerName_" + id.validate_node_name()
	lien.text = nom
	lien.flat = true
	lien.focus_mode = Control.FOCUS_NONE
	C.style_bouton_lien(lien)
	lien.add_theme_font_override("font", Charte.texte_moyen())
	lien.add_theme_font_size_override("font_size", fpx(19))
	for etat_bouton in ["normal", "hover", "pressed", "focus"]:
		var style := lien.get_theme_stylebox(etat_bouton) as StyleBoxFlat
		if style != null:
			style.content_margin_left = 0
			style.content_margin_top = 0
			style.content_margin_bottom = 0
	lien.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lien.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lien.set_meta("player_id", id)
	lien.pressed.connect(func(): ouvrir_fiche(id))
	var app: Object = _app()
	if app is Control and not id.is_empty(): CarteSurvol.lier(app, lien, id, "squad", func(): return _direct_carte(id))
	rangee.add_child(lien)
	if not alerte.is_empty():
		var mot := _texte(alerte, 18, ALERTE if alerte in ["épuisé", "blessé", "exclu"] or alerte.begins_with("carton") else Charte.ATTRIBUT_40)
		mot.name = "MatchBetweenPlayerAlert"
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(mot)
	if not humeur.is_empty(): rangee.add_child(_etiquette_etat(humeur, fpx(17), false))
	# Nom trop long pour sa colonne : coupé avec « … » (entier dans l'infobulle accessible, la mini-fiche et la fiche).
	cadre.resized.connect(func(): _ajuster_nom(lien, nom, cadre, rangee))
	return cadre

## Raccourcit le nom affiché avec « … » pour qu'il tienne dans son cadre, à côté des mots qui le suivent.
func _ajuster_nom(lien: Button, nom: String, cadre: Control, rangee: HBoxContainer) -> void:
	if not is_instance_valid(lien) or cadre.size.x <= 1.0: return
	var separation := float(rangee.get_theme_constant("separation"))
	var alerte := rangee.find_child("MatchBetweenPlayerAlert", false, false) as Label
	var autres := 0.0
	for enfant: Node in rangee.get_children():
		if enfant != lien and enfant != alerte and enfant is Control and (enfant as Control).visible: autres += (enfant as Control).get_combined_minimum_size().x + separation
	var police: Font = lien.get_theme_font("font")
	if not lien.has_meta("taille_base"): lien.set_meta("taille_base", lien.get_theme_font_size("font_size"))
	var taille := int(lien.get_meta("taille_base"))
	if lien.get_theme_font_size("font_size") != taille: lien.add_theme_font_size_override("font_size", taille)
	var style := lien.get_theme_stylebox("normal")
	var marges := style.get_minimum_size().x if style != null else 0.0
	var largeur_alerte := 0.0
	if alerte != null:
		if not alerte.has_meta("texte_complet"): alerte.set_meta("texte_complet", alerte.text)
		largeur_alerte = alerte.get_theme_font("font").get_string_size(str(alerte.get_meta("texte_complet")), HORIZONTAL_ALIGNMENT_LEFT, -1, alerte.get_theme_font_size("font_size")).x + separation
	var dispo := cadre.size.x - autres - largeur_alerte - marges - 1.0
	var texte := nom
	var place_alerte := -1.0
	if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > dispo:
		if alerte != null:
			# Alerte à côté : le prénom passe en initiale (« D. DOWNES », décision de Léo du 20/11). Le nom de famille n'est
			# jamais coupé : si même abrégé il ne tient pas avec l'alerte, c'est l'alerte qui est raccourcie.
			texte = abreger_prenom(nom)
			var largeur_nom := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			if largeur_nom > dispo: place_alerte = maxf(0.0, cadre.size.x - autres - largeur_nom - marges - separation - 1.0)
		else:
			# Sans alerte : la police baisse jusqu'aux trois quarts pour que le nom tienne en entier.
			var base := taille
			var reduite := base
			while reduite > maxi(12, roundi(base * 0.75)) and police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo: reduite -= 1
			if reduite != taille: lien.add_theme_font_size_override("font_size", reduite)
			if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo:
				texte = abreger_prenom(nom)
				while texte.length() > 1 and police.get_string_size(texte + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, reduite).x > dispo: texte = texte.substr(0, texte.length() - 1)
				if texte != abreger_prenom(nom): texte = texte.strip_edges() + "…"
	if alerte != null:
		alerte.clip_text = place_alerte >= 0.0
		alerte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if place_alerte >= 0.0 else TextServer.OVERRUN_NO_TRIMMING
		alerte.custom_minimum_size.x = maxf(0.0, place_alerte)
	if lien.text != texte: lien.text = texte
	lien.set_meta("nom_entier", str(lien.get_meta("nom_complet", nom)))

## Données de Notre XV, poste par poste : données du joueur (`W.donnees_joueur`), alerte, infobulle.
## Ordre d'affichage de Mon XV (indices de poste) : par numéro (tri vide), ou par la colonne choisie (« joueur »,
## « energie », « plaquages », « note ») ; sens naturel : nom A→Z, énergie la plus basse d'abord (qui remplacer),
## plaquages et note les plus hauts d'abord ; `inverse` retourne le sens. Égalité : le numéro. Postes vacants en fin.
static func ordre_xv(joueurs: Array, infos: Array, tri: String, inverse: bool) -> Array:
	var ordre: Array = range(joueurs.size())
	if tri.is_empty() or tri == "numero":
		if inverse: ordre.reverse()
		return ordre
	var valeur := func(poste: int) -> Variant:
		var info: Dictionary = infos[poste] if poste < infos.size() and infos[poste] is Dictionary else {}
		match tri:
			"joueur": return str(joueurs[poste].get("name", "")).to_lower() if joueurs[poste] is Dictionary else ""
			"energie": return float(info.get("energie", 0.0))
			"plaquages": return -float(info.get("plaquages", 0))
			"note": return -float(info.get("note", 0.0))
		return poste
	ordre.sort_custom(func(a: int, b: int) -> bool:
		var vacant_a := not joueurs[a] is Dictionary
		var vacant_b := not joueurs[b] is Dictionary
		if vacant_a != vacant_b: return vacant_b
		var va: Variant = valeur.call(a)
		var vb: Variant = valeur.call(b)
		if va == vb: return a < b
		return (va > vb) if inverse else (va < vb))
	return ordre

## Flèche du tri courant dans l'en-tête (▲ sens naturel, ▼ inversé) ; la colonne triée en ivoire.
func _poser_entete_tri() -> void:
	var courant := "numero" if tri_xv.is_empty() else tri_xv
	for bouton: Button in entetes_tri:
		var cle := str(bouton.get_meta("tri"))
		# Flèche sur la colonne triée ; l'ordre des postes par défaut n'en porte pas (« N° » tient dans sa colonne).
		var actif := cle == courant and not (cle == "numero" and not tri_inverse)
		bouton.text = str(bouton.get_meta("libelle")) + ((" ▼" if tri_inverse else " ▲") if actif else "")
		for couleur in ["font_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE if actif else DOUX)
		var courant_style := bouton.get_theme_stylebox("normal") as StyleBoxFlat
		if courant_style != null:
			courant_style = courant_style.duplicate()
			courant_style.bg_color = Charte.SELECTION if cle == courant else RELIEF
			bouton.add_theme_stylebox_override("normal", courant_style)

func _infos_xv(joueurs: Array, direct: Dictionary) -> Array:
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var infos: Array = []
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		if not joueur is Dictionary:
			infos.append({"vacant": true, "alerte": "", "detail": "%d · poste vacant" % (poste + 1)})
			continue
		var d := W.donnees_joueur(joueur, notes, cartons, feuille)
		var id: String = d.id
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var condition: float = d.energie
		var alerte := ""
		if d.blesse: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % _minute(cartons[id].get("retour")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		var plaq := int(d.get("plaquages", 0))
		var detail := "%d · %s · %s\nÉnergie %d %%, note %.1f (%d action%s du match), %d plaquage%s" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), roundi(condition), float(d.note), int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else "", plaq, "s" if plaq > 1 else ""]
		if not feuille.is_empty(): detail += " (%d manqué%s), %d course%s, %d passe%s" % [int(d.plaquages_manques), "s" if int(d.plaquages_manques) > 1 else "", int(d.courses), "s" if int(d.courses) > 1 else "", int(d.passes), "s" if int(d.passes) > 1 else ""]
		if not alerte.is_empty(): detail += "\n" + alerte.capitalize()
		var humeur := Pilotage.etat_joueur(_pilotage, id)
		if not humeur.is_empty(): detail += "\nAprès la causerie : " + str(humeur.label).to_lower()
		var info := d.duplicate()
		info.merge({"alerte": alerte, "carton": cartons.has(id), "etat": humeur, "detail": detail + "\nClic : l'écran Équipe sur ce joueur ; son nom : sa fiche."}, true)
		infos.append(info)
	return infos

## Carte joueur au survol : l'état du joueur dans ce match (note, énergie, plaquages…), lu à son apparition.
func _direct_carte(id: String) -> Dictionary:
	if _xv_donnees.size() < 2: return {}
	for info: Variant in _infos_xv(_xv_donnees[0], _xv_donnees[1]):
		if info is Dictionary and str(info.get("id", "")) == id: return info
	return {}

## État d'un joueur après la causerie (« Motivé », « Vexé »…) : vert s'il porte, rouge de l'alerte s'il
## pèse, neutre sinon.
func _etiquette_etat(humeur: Dictionary, taille: int, centre: bool) -> Label:
	var etiquette := S.label(str(humeur.get("label", "")), taille, Pilotage.teinte(Pilotage.sens_etat(str(humeur.get("etat", ""))), DOUX))
	etiquette.name = "MatchBetweenPlayerState"
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if centre: etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else: etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return etiquette
