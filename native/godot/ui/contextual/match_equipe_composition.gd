extends "res://ui/contextual/match_equipe_terrain.gd"
## Onglet Composition : cris de la touche, page, prévision « Dans 10 minutes », banc en tuiles et conseil de Gabi.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

func _composition() -> void:
	var p := _pilotage()
	var cris: Variant = p.get("cris")
	var avec_cris: bool = cris is Dictionary and (cris as Dictionary).get("options") is Array and not (cris.options as Array).is_empty()
	if avec_cris: _cris(cris)
	var gauche := 240.0 if avec_cris else 24.0
	var centre := _v(12)
	centre.name = "TeamCentre"
	_poser(centre, gauche, 96, 1140.0 - gauche, 708)
	_terrain(centre)
	_fatigue(centre, p)
	_banc(p)
	_pied(_pied_composition, ["Ajuster les consignes →", choisir_onglet.bind("consignes"), "TeamToConsignes"])

func _pied_composition(infos: HBoxContainer) -> void:
	var p := _pilotage()
	var actives := _consignes_actives(p)
	infos.add_child(_texte("Consignes :", 13, C.MUTED))
	if actives.is_empty(): infos.add_child(_texte("toutes au cran normal", 13, C.MUTED))
	for texte in actives: infos.add_child(_puce(texte))
	for bilan_v: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if bilan_v is Dictionary:
			var texte_bilan := bilan_court(p, str(bilan_v.get("axe", "")))
			# Coupé avec « … » (et infobulle) plutôt que tronqué net quand les puces prennent la place.
			var ligne_bilan := _coupe(_texte(texte_bilan, 13, C.ALERT if str(bilan_v.get("axe", "")) in ["rucks", "discipline"] else C.MUTED))
			ligne_bilan.name = "TeamFooterBilan"
			ligne_bilan.tooltip_text = texte_bilan
			ligne_bilan.mouse_filter = Control.MOUSE_FILTER_PASS
			infos.add_child(ligne_bilan)
			break
	var arbitre := Pilotage.arbitre_texte(p.get("arbitre"))
	if not arbitre.is_empty():
		var ligne := _coupe(_texte(arbitre, 13, C.MUTED))
		ligne.name = "TeamFooterReferee"
		ligne.tooltip_text = arbitre
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		_pied_ligne2.add_child(ligne)

func _cris(cris: Dictionary) -> void:
	var colonne := _v(8)
	colonne.name = "TeamShouts"
	_poser(colonne, 24, 96, 200, 708)
	colonne.add_child(_titre_section("Cris de la touche", 19))
	var aide := _texte("Un mot au groupe, tout de suite. Effet court, qui s'use si on répète.", 12, C.MUTED)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(aide)
	var actif: Dictionary = cris.get("actif") if cris.get("actif") is Dictionary else {}
	var lettres := {}
	for option_v: Variant in cris.get("options", []):
		if not option_v is Dictionary: continue
		var option: Dictionary = option_v
		var id := str(option.get("id", ""))
		var libelle := str(option.get("label", id))
		var lettre := ""
		for c in libelle.to_upper():
			if c >= "A" and c <= "Z" and not lettres.has(c):
				lettre = c
				break
		lettres[lettre] = true
		var disponible := bool(option.get("disponible", true))
		var est_actif := str(actif.get("id", "")) == id
		var bouton := Button.new()
		bouton.name = "TeamShout_" + id
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.disabled = not disponible or est_actif
		bouton.tooltip_text = str(option.get("note", ""))
		bouton.custom_minimum_size.y = px(100)
		# Cri actif : fond relevé, filet GAUCHE épais ivoire et coche (comme un choix courant), jamais d'or ; les autres :
		# un seul filet bas (charte §3 : aucun cadre complet).
		# Charte finale : un cri est une carte de rayon 12, sans bordure ; le cri actif est sur fond de ligne choisie (vert franc) avec sa coche ; focus : anneau dore.
		var normal := _boite(Charte.SELECTION if est_actif else C.RAISED, Color.TRANSPARENT, Charte.RAYON_CARTE, 0, 0, true)
		normal.content_margin_left = px(12)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.bg_color = C.SELECTED
		var eteint := normal.duplicate() as StyleBoxFlat
		if not est_actif: eteint.bg_color = Color(C.RAISED, 0.5)
		var focus := _boite(Color.TRANSPARENT, Charte.OR, Charte.RAYON_CARTE, 2, 0, true)
		focus.set_border_width_all(maxi(1, px(2)))
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", eteint], ["focus", focus]]: bouton.add_theme_stylebox_override(paire[0], paire[1])
		bouton.pressed.connect(func(): crier(id))
		var rangee := _h(10)
		rangee.position = Vector2(px(12), 0)
		rangee.size = Vector2(px(200 - 24), px(100))
		rangee.alignment = BoxContainer.ALIGNMENT_CENTER
		bouton.add_child(rangee)
		bouton.resized.connect(func(): rangee.size = Vector2(bouton.size.x - px(24), bouton.size.y))
		var usure := clampf(float(option.get("usure", 0.0)), 0.0, 1.0)
		# Carré de la lettre (angles droits) : sa teinte double la note écrite dessous (« s'use », « Actif jusqu'à »).
		var teinte := C.IVORY if est_actif else (C.FAINT if not disponible else (C.MINT if usure <= 0.0 else (C.IVORY if usure < 1.0 else C.ALERT)))
		var rond := _panneau(_plat(teinte))
		rond.custom_minimum_size = Vector2(px(32), px(32))
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if est_actif:
			var coche := _coche(20)
			coche.texture = C.icon_texture("check", C.BG)
			coche.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rond.add_child(coche)
		else:
			var marque := _titre(lettre, 17, C.BG, 800)
			marque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marque.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rond.add_child(marque)
		rangee.add_child(rond)
		var mots := _v(1)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var etiquette := _titre(libelle, 17, C.IVORY if disponible or est_actif else C.MUTED, 700)
		etiquette.name = "TeamShoutLabel"
		_sur_deux_lignes(etiquette, 2)
		mots.add_child(etiquette)
		var note := str(option.get("note", ""))
		var note_complete := note
		if est_actif and actif.get("jusqua") != null: note = "Actif jusqu'à la %de" % int(actif.jusqua)
		if not note.is_empty():
			var texte_note := _texte(note, 12, C.IVORY if est_actif or (usure > 0.0 and usure < 1.0) else (C.ALERT if usure >= 1.0 else C.MUTED))
			texte_note.name = "TeamShoutNote"
			_sur_deux_lignes(texte_note, 3)
			mots.add_child(texte_note)
		bouton.tooltip_text = libelle + ("\n" + note_complete if not note_complete.is_empty() else "") + ("\n" + note if note != note_complete else "")
		rangee.add_child(mots)
		bouton.modulate.a = 1.0 if disponible or est_actif else 0.6
		colonne.add_child(bouton)

func _fatigue(centre: VBoxContainer, p: Dictionary) -> void:
	var lignes: Variant = p.get("fatigue")
	if not lignes is Array or (lignes as Array).is_empty(): return
	var cadre := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 0, "left", 3, true))
	cadre.name = "TeamFatigue"
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(16)
	style.content_margin_right = px(16)
	cadre.custom_minimum_size.y = px(92)
	centre.add_child(cadre)
	var rangee := _h(18)
	cadre.add_child(rangee)
	var tete := _v(0)
	tete.custom_minimum_size.x = px(140)
	tete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(_titre_section("Dans 10 minutes", 19))
	var rythme := ""
	for axe_v: Variant in Pilotage.axes(p):
		if axe_v is Dictionary and str(axe_v.get("id", "")) == "rythme":
			for option: Variant in axe_v.get("options", []):
				if option is Dictionary and str(option.get("id", "")) == Pilotage.cran(p, axe_v): rythme = str(option.get("label", ""))
	if not rythme.is_empty(): tete.add_child(_texte("au rythme « %s »" % rythme, 12, C.MUTED))
	rangee.add_child(tete)
	var montres := 0
	for ligne_v: Variant in lignes:
		if montres >= 4 or not ligne_v is Dictionary: continue
		var ligne: Dictionary = ligne_v
		var id := str(ligne.get("id", ""))
		var slot := _poste_de(id)
		if slot < 0: continue
		montres += 1
		var joueur: Dictionary = _lineup()[slot]
		var avant := roundi(float(ligne.get("condition", joueur.get("condition", 0))))
		var apres := roundi(float(ligne.get("prevue", avant)))
		var teinte := teinte_energie(apres)
		var bloc := _h(10)
		bloc.name = "TeamFatigue_" + id
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.size_flags_stretch_ratio = 1.0
		bloc.alignment = BoxContainer.ALIGNMENT_CENTER
		# Portrait carré souligné d'un seul filet à la teinte de l'énergie (le pourcentage est écrit à côté).
		var anneau := _panneau(_plat(Color.TRANSPARENT, teinte, 0, "bottom", 3))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(joueur, px(40)))
		bloc.add_child(anneau)
		var mots := _v(4)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tete_nom := _h(4)
		tete_nom.add_child(_nom_joueur(id, nom_court(str(joueur.get("name", ""))), 13, "TeamFatigueName", 120))
		tete_nom.add_child(_texte("(%d)" % (slot + 1), 13, C.IVORY, _gras))
		mots.add_child(tete_nom)
		var bas := _h(6)
		var barre := Barre.new()
		barre.mouse_filter = Control.MOUSE_FILTER_PASS
		barre.avant = avant
		barre.apres = apres
		barre.teinte = teinte
		barre.custom_minimum_size.y = px(6)
		barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bas.add_child(barre)
		bas.add_child(_texte("%d → %d %%" % [avant, apres], 12, teinte))
		mots.add_child(bas)
		bloc.add_child(mots)
		bloc.tooltip_text = "%s : énergie %d %% maintenant, %d %% prévue dans 10 minutes." % [str(joueur.get("name", "")), avant, apres]
		# Bloc d'un de nos joueurs : son clic (portrait, barre, chiffres) ouvre aussi sa fiche complète.
		if _est_des_notres(id):
			bloc.mouse_filter = Control.MOUSE_FILTER_STOP
			bloc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			bloc.set_meta("fiche_joueur", id)
			bloc.gui_input.connect(_clic_fiche.bind(bloc, id))
		rangee.add_child(bloc)
	if montres == 0: cadre.queue_free()

class Barre extends Control:
	const C = preload("res://ui/immersive08/components.gd")
	var avant := 0
	var apres := 0
	var teinte := C.MINT
	func _draw() -> void:
		_piste(size.x, C.LINE)
		_piste(size.x * clampf(avant / 100.0, 0, 1), Color(C.IVORY, 0.25))
		_piste(size.x * clampf(apres / 100.0, 0, 1), teinte)
	## Barre à angles droits (charte §3).
	func _piste(largeur: float, couleur: Color) -> void:
		if largeur <= 0.0: return
		draw_rect(Rect2(0, 0, largeur, size.y), couleur)

func _banc(p: Dictionary) -> void:
	var colonne := _v(10)
	colonne.name = "TeamBench"
	_poser(colonne, 1156, 96, 420, 708)
	var tete := _h(8)
	var titre := _titre("LE BANC", 22, C.IVORY)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var reserves := _reserves()
	var restants: Variant = _live().get("remplacementsRestants", _live().get("substitutionsLeft"))
	var precision := ("%d changement%s restant%s" % [int(restants), "s" if int(restants) > 1 else "", "s" if int(restants) > 1 else ""]) if restants is int or restants is float else "%d remplaçant%s" % [reserves.size(), "s" if reserves.size() > 1 else ""]
	tete.add_child(_texte(precision, 12, C.MUTED))
	colonne.add_child(tete)
	var grille := GridContainer.new()
	grille.name = "TeamBenchGrid"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", px(8))
	grille.add_theme_constant_override("v_separation", px(8))
	colonne.add_child(grille)
	var conseil := _conseil(p)
	var autorises := PackedStringArray()
	if poste_choisi >= 0:
		for x: Variant in _entrants(poste_choisi): autorises.append(str(x))
	var tous: Dictionary = {}
	for option: Variant in _live().get("substitutions", []):
		if option is Dictionary:
			for x: Variant in option.get("inIds", []): tous[str(x)] = true
	for n in reserves.size():
		var joueur: Variant = reserves[n]
		if not joueur is Dictionary: continue
		var id := str(joueur.get("id", ""))
		var eligible: bool = autorises.has(id) if poste_choisi >= 0 else tous.has(id)
		var choisi := entrant_choisi == id
		var conseille := not conseil.is_empty() and str(conseil.get("inId", "")) == id
		grille.add_child(_tuile(joueur, MenuJoueur.numero_feuille(_live(), id, 16 + n), eligible, choisi, conseille))
	if not conseil.is_empty(): _carte_conseil(colonne, conseil)

func _tuile(joueur: Dictionary, numero: int, eligible: bool, choisi: bool, conseille: bool) -> Button:
	var id := str(joueur.get("id", ""))
	var tuile := Button.new()
	tuile.name = "TeamBench%d" % numero
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuile.custom_minimum_size = Vector2(0, px(68))
	tuile.clip_contents = false # le contenu est à 8 px du bord ; rogner couperait l'ombre de la carte
	# Un seul filet, à gauche (charte §3 : aucun cadre complet). Remplaçant choisi : fond sombre relevé, filet épais
	# ivoire et coche ; autorisé : filet menthe (et « en vert sur le banc » écrit sous le terrain) ; conseillé par
	# Gabi : filet ivoire (sa carte le nomme). Jamais d'or ni d'ivoire plein.
	var bord := C.MINT if eligible and poste_choisi >= 0 else (C.IVORY if choisi or conseille else C.LINE)
	var normal := Charte.ombrer_droit(_boite(C.SELECTED if choisi else C.PANEL, bord, Charte.RAYON_PETIT, 4 if choisi else 2, 8, true, "left")) # carte du banc : ombre de la charte
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = C.RAISED
	survol.border_color = C.IVORY
	var focus := _boite(Color.TRANSPARENT, C.IVORY, Charte.RAYON_PETIT, 2, 8, true)
	for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: tuile.add_theme_stylebox_override(paire[0], paire[1])
	var rangee := _h(8)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	S.full(rangee)
	rangee.offset_left = px(8)
	rangee.offset_right = -px(8)
	rangee.offset_top = px(8)
	rangee.offset_bottom = -px(8)
	tuile.add_child(rangee)
	var portrait := _portrait(joueur, px(52), px(58))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(portrait)
	var mots := _v(2)
	mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var haut := _h(4)
	# Le clic sur la tuile choisit l'entrant ; le NOM est un lien vers sa fiche (mini-fiche au survol).
	haut.add_child(_titre("%d ·" % numero, 16, C.IVORY, 700))
	haut.add_child(_nom_joueur(id, nom_court(str(joueur.get("name", ""))), 16, "TeamBenchName", 104, C.font(700)))
	var pousse := Control.new()
	pousse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pousse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(pousse)
	var niveau := _niveau(joueur)
	if not niveau.is_empty():
		# Lettre du staff dans une pastille à sa couleur (comme l'Effectif), jamais le chiffre du moteur.
		var l_niv := _lettre_niveau(joueur)
		var badge := _titre(niveau, 16, Notation.couleur_texte(int(l_niv.haut) if int(l_niv.bas) == int(l_niv.haut) else int(l_niv.bas)), 800)
		badge.name = "TeamBenchLevel"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(px(28), px(28))
		var fond_badge := StyleBoxFlat.new()
		fond_badge.bg_color = Notation.couleur(int(l_niv.bas))
		fond_badge.set_corner_radius_all(roundi(px(14)))
		fond_badge.content_margin_left = px(6)
		fond_badge.content_margin_right = px(6)
		badge.add_theme_stylebox_override("normal", fond_badge)
		badge.set_meta("lettre", niveau)
		haut.add_child(badge)
	if choisi: haut.add_child(_coche(14))
	mots.add_child(haut)
	mots.add_child(_coupe(_texte(str(joueur.get("pos", "")), 12, C.MUTED)))
	var condition := roundi(float(joueur.get("condition", 100)))
	var info := ""
	var teinte := C.MUTED
	for cle: String in ["conseil", "info", "hint", "note"]:
		if joueur.get(cle) is String and not str(joueur.get(cle)).is_empty():
			info = str(joueur.get(cle))
			teinte = C.IVORY
			break
	if int(joueur.get("injury", 0)) > 0:
		info = "Blessé"
		teinte = C.ALERT
	elif info.is_empty():
		info = "Prêt · %d %%" % condition if condition >= 95 else "Énergie %d %%" % condition
		teinte = C.MINT if condition >= 75 else C.IVORY
	mots.add_child(_coupe(_texte(info, 12, teinte)))
	rangee.add_child(mots)
	tuile.custom_minimum_size.y = maxf(px(72), rangee.get_combined_minimum_size().y + px(16))
	tuile.tooltip_text = "%d · %s · %s\n%s" % [numero, str(joueur.get("pos", "")), str(joueur.get("name", "")), info]
	if not eligible and not choisi: tuile.modulate.a = 0.4
	tuile.set_meta("eligible", eligible)
	tuile.pressed.connect(func(): choisir_entrant(id))
	tuile.set_drag_forwarding(_glisser.bind(joueur, tuile), Callable(), Callable())
	tuiles[id] = tuile
	return tuile

## Conseil de changement de Gabi, s'il désigne un joueur du XV et un remplaçant du banc (et pas écarté).
func _conseil(p: Dictionary) -> Dictionary:
	var conseil: Variant = p.get("conseilChangement")
	if not conseil is Dictionary: return {}
	var cle := "%s>%s" % [str(conseil.get("outId", "")), str(conseil.get("inId", ""))]
	if cle == _conseil_ecarte or _poste_de(str(conseil.get("outId", ""))) < 0 or _reserve(str(conseil.get("inId", ""))).is_empty(): return {}
	return conseil

func _carte_conseil(colonne: VBoxContainer, conseil: Dictionary) -> void:
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(vide)
	var cadre := _panneau(_plat(C.PANEL, C.IVORY, 14, "left", 3, true))
	cadre.name = "TeamAdvice"
	colonne.add_child(cadre)
	var pile := _v(10)
	cadre.add_child(pile)
	pile.add_child(_titre_section("Gabi conseille", 16))
	var out_id := str(conseil.get("outId", ""))
	var in_id := str(conseil.get("inId", ""))
	var slot := _poste_de(out_id)
	# Poste donné par le moteur (`conseilChangement.slot`) s'il désigne bien le sortant.
	var poste_moteur: Variant = conseil.get("slot")
	if (poste_moteur is int or poste_moteur is float) and int(poste_moteur) >= 0 and int(poste_moteur) < _lineup().size() and _lineup()[int(poste_moteur)] is Dictionary and str(_lineup()[int(poste_moteur)].get("id", "")) == out_id: slot = int(poste_moteur)
	var sortant: Dictionary = _lineup()[slot]
	var entrant := _reserve(in_id)
	var rangee := _h(12)
	for paire: Array in [[sortant, C.ALERT], [entrant, C.MINT]]:
		# Sortant / entrant : portrait carré souligné d'un seul filet (alerte / menthe), la phrase dit qui sort.
		var anneau := _panneau(_plat(Color.TRANSPARENT, paire[1], 0, "bottom", 3))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(paire[0], px(48)))
		rangee.add_child(anneau)
		if paire[1] == C.ALERT:
			var fleche := _titre("⇄", 26, C.IVORY)
			fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rangee.add_child(fleche)
	var texte := str(conseil.get("texte", ""))
	if texte.is_empty(): texte = "%s (%d) est à bout. %s est frais." % [nom_court(str(sortant.get("name", ""))), slot + 1, nom_court(str(entrant.get("name", "")))]
	var phrase := _texte(texte, 13, C.IVORY)
	phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phrase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phrase.max_lines_visible = 4
	rangee.add_child(phrase)
	pile.add_child(rangee)
	# Qui sort, qui entre : leurs noms en liens (mini-fiche au survol, fiche complète au clic), c'est le moment où
	# l'on veut les comparer.
	var noms := _h(6)
	noms.name = "TeamAdviceNames"
	noms.add_child(_nom_joueur(out_id, nom_court(str(sortant.get("name", ""))), 14, "TeamAdviceOut", 130))
	noms.add_child(_texte("sort ·", 13, C.MUTED))
	noms.add_child(_nom_joueur(in_id, nom_court(str(entrant.get("name", ""))), 14, "TeamAdviceIn", 130))
	noms.add_child(_texte("entre", 13, C.MUTED))
	pile.add_child(noms)
	var boutons := _h(8)
	var faire := _bouton("Faire entrer %s →" % nom_court(str(entrant.get("name", ""))), func(): remplacer(slot, in_id), "lien", 17, "TeamAdviceApply")
	faire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faire.disabled = not _autorise(slot, in_id)
	if faire.disabled: faire.tooltip_text = "Changement possible match arrêté, selon les règles du banc."
	boutons.add_child(faire)
	boutons.add_child(_bouton("Plus tard", _plus_tard.bind("%s>%s" % [out_id, in_id]), "lien", 17, "TeamAdviceLater"))
	pile.add_child(boutons)

func _plus_tard(cle: String) -> void:
	_conseil_ecarte = cle
	_cle = ""
	_rafraichir()
