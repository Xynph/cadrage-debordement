extends "res://ui/contextual/match_equipe_cartes.gd"
## Onglet Consignes : page des cinq axes (groupes Attaque, Défense…), un cran par valeur.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

func _choisir_cran(crans: Control, axe: String, valeur: String) -> void:
	if str(crans.get_meta("cran", "")) == valeur: return
	crans.set_meta("cran", valeur)
	_envoyer_consigne(axe, valeur)

# --- Onglet Consignes ------------------------------------------------------------

func _consignes() -> void:
	var p := _pilotage()
	var envois: Dictionary = view.get("_envois_consignes") if view != null and view.get("_envois_consignes") is Dictionary else {}
	var vue := Pilotage.avec_envois(p, envois)
	var section := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 0, "left", 3, true))
	section.name = "TeamConsignes"
	var style := section.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(20)
	style.content_margin_right = px(20)
	style.content_margin_top = px(16)
	style.content_margin_bottom = px(16)
	_poser(section, 24, 96, 1110, 708)
	var axes := Pilotage.axes(vue).filter(func(a: Variant) -> bool: return a is Dictionary)
	# Une seule zone qui défile, et seulement si les groupes ne tiennent pas (petites fenêtres).
	var defile := ScrollContainer.new()
	defile.name = "TeamConsignesScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section.add_child(defile)
	var deux := _h(24)
	deux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(deux)
	var gauche := _v(6)
	var droite := _v(6)
	for c: VBoxContainer in [gauche, droite]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deux.add_child(c)
	gauche.name = "TeamConsignesLeft"
	droite.name = "TeamConsignesRight"
	if axes.is_empty():
		var rien := _texte("Les consignes en direct ne sont pas disponibles pour cette rencontre.", 14, C.MUTED)
		rien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gauche.add_child(rien)
	var libelles := {}
	for g: Variant in p.get("groupes", []) if p.get("groupes") is Array else []:
		if g is Dictionary: libelles[str(g.get("id", ""))] = str(g.get("label", ""))
	if axes.any(func(a: Dictionary) -> bool: return not str(a.get("groupe", "")).is_empty()):
		for n in GROUPES.size():
			var id_groupe: String = GROUPES[n][0]
			var membres := axes.filter(func(a: Dictionary) -> bool: return str(a.get("groupe", "")) == id_groupe)
			if membres.is_empty(): continue
			var cible: VBoxContainer = gauche if n < 2 else droite
			var bloc := _v(6)
			bloc.name = "TeamGroup_" + id_groupe
			cible.add_child(bloc)
			bloc.add_child(_entete_groupe(str(libelles.get(id_groupe, GROUPES[n][1])).to_upper(), str(GROUPES[n][2])))
			for axe: Dictionary in membres: bloc.add_child(_axe(vue, axe))
			if n % 2 == 0: cible.add_child(_espace(8))
		# Axe d'un groupe inconnu : en fin de colonne de droite, jamais perdu.
		var connus: Array = GROUPES.map(func(g: Array) -> String: return g[0])
		for axe: Dictionary in axes:
			if not str(axe.get("groupe", "")) in connus: droite.add_child(_axe(vue, axe))
	else:
		# Moteur sans groupes : les axes sous un seul titre, le plan de jeu d'avant à droite.
		gauche.add_child(_entete_groupe("EN DIRECT", "sans arrêter le match"))
		for axe: Dictionary in axes: gauche.add_child(_axe(vue, axe))
		droite.add_child(_entete_groupe("PLAN DE JEU", "match arrêté"))
		_plan_de_jeu(droite)
	# Colonne de droite dans sa propre zone qui défile : en petite fenêtre (720p), le plancher de 12 px des textes
	# la rend plus haute que l'écran ; elle tient sans défiler dès 1080p.
	var defile_aside := ScrollContainer.new()
	defile_aside.name = "TeamConsignesAsideScroll"
	defile_aside.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Zone élargie de 6 px de chaque côté, contenu rentré d'autant : la zone rogne, l'ombre des cartes reste entière.
	_poser(defile_aside, 1144, 90, 438, 720)
	var aside := _v(14 if k >= 1.0 else 8)
	aside.name = "TeamConsignesAside"
	aside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aside.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var jeu_ombre := MarginContainer.new()
	jeu_ombre.name = "TeamConsignesAsideMargin"
	jeu_ombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cote: String in ["left", "right", "top", "bottom"]: jeu_ombre.add_theme_constant_override("margin_" + cote, px(6))
	defile_aside.add_child(jeu_ombre)
	jeu_ombre.add_child(aside)
	_carte_arbitre(aside, p)
	_carte_adversaire(aside, p, vue)
	_carte_match(aside, p)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.add_child(vide)
	_carte_staff(aside, p)
	_pied(_pied_consignes, ["← Retour à la composition", choisir_onglet.bind("composition"), "TeamToComposition"])

## Ligne d'un axe : libellé (et « match en pause » pour le plan de jeu), crans ; fond relevé et bilan
## dessous quand le cran en place n'est pas neutre.
func _axe(p: Dictionary, axe: Dictionary) -> Control:
	var id := str(axe.get("id", ""))
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var actuel := Pilotage.cran(p, axe)
	var modifie := not actuel.is_empty() and actuel != cran_neutre(axe)
	var en_pause_seulement := bool(axe.get("pause", false)) or id in ["planAttaque", "systemeDefense", "penalites"]
	var cadre := _panneau(_plat(C.RAISED if modifie else Color.TRANSPARENT))
	cadre.name = "Consigne_" + id
	cadre.set_meta("modifie", modifie)
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(6)
	style.content_margin_bottom = px(6)
	var pile := _v(3)
	cadre.add_child(pile)
	var rangee := _h(10)
	pile.add_child(rangee)
	var gauche := _v(0)
	gauche.custom_minimum_size.x = px(112)
	gauche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var aide := str(axe.get("aide", ""))
	var libelle := _coupe(_titre(str(axe.get("label", id)), 17, C.IVORY, 700))
	libelle.tooltip_text = aide
	libelle.mouse_filter = Control.MOUSE_FILTER_PASS
	gauche.add_child(libelle)
	if en_pause_seulement:
		var note := _texte("match en pause", 12, C.MUTED)
		note.name = "ConsignePause"
		gauche.add_child(note)
	cadre.tooltip_text = aide
	rangee.add_child(gauche)
	var crans := _h(4)
	crans.name = "Consigne_%s_Crans" % id
	crans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crans.set_meta("cran", actuel)
	var fini := bool(_live().get("finished", false))
	var en_pause := bool(_live().get("paused", false))
	for option_v: Variant in options:
		if not option_v is Dictionary: continue
		var valeur := str(option_v.get("id", ""))
		var choisi := valeur == actuel
		var texte := str(option_v.get("label", valeur))
		# Même taille et une seule ligne pour tous les crans : libellé court, le complet en infobulle.
		# Cran en place : filet épais ivoire et coche (segment de la charte), jamais d'or ni d'ivoire plein.
		var bouton := _bouton(libelle_court(texte), _choisir_cran.bind(crans, id, valeur), "choisi" if choisi else "segment", CRAN_TAILLE, "Consigne_%s_%s" % [id, valeur])
		bouton.set_meta("axe", id)
		bouton.set_meta("valeur", valeur)
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.custom_minimum_size = Vector2(0, px(32))
		bouton.clip_text = true
		bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bouton.add_theme_constant_override("icon_max_width", fs(11))
		bouton.add_theme_constant_override("h_separation", px(2))
		bouton.tooltip_text = texte + ("\n" + aide if not aide.is_empty() else "")
		for etat: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var boite := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			boite.content_margin_left = px(2)
			boite.content_margin_right = px(2)
			boite.content_margin_top = px(6)
			boite.content_margin_bottom = px(6)
		if not choisi: (bouton.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = C.BG
		bouton.disabled = fini or (en_pause_seulement and not en_pause)
		if en_pause_seulement and not en_pause: bouton.tooltip_text += "\nChangement possible match arrêté."
		crans.add_child(bouton)
	rangee.add_child(crans)
	var bilan := bilan_court(p, id)
	if modifie and not bilan.is_empty():
		var ligne := _coupe(_texte(bilan, 12, C.IVORY))
		ligne.name = "ConsigneBilan"
		ligne.tooltip_text = bilan
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		var decale := MarginContainer.new()
		decale.add_theme_constant_override("margin_left", px(122))
		decale.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decale.add_child(ligne)
		pile.add_child(decale)
	return cadre
