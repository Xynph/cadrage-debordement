extends "res://ui/contextual/match_equipe_socle.gd"
## Outils de construction de la fenêtre « Équipe » (échelle, cadres, textes, boutons, portraits, noms cliquables),
## en-tête (onglets, score) et pied de page.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

func px(valeur: float) -> int:
	return roundi(valeur * k)

## Taille de police mise à l'échelle, avec le plancher commun de 12 px réels (charte §7).
func fs(valeur: float) -> int:
	return maxi(12, roundi(valeur * k))

## Boîte de la charte (§3) : angles droits (rayon 0) partout, sans ombre ni dégradé, et JAMAIS de cadre complet :
## au plus un filet, sur un seul côté (`cote` : bottom par défaut, left, top), commandes comprises. Le rayon demandé
## n'est gardé que pour les disques du terrain (`rond`), seule forme ronde admise.
func _boite(fond: Color, bord: Color = Color.TRANSPARENT, rayon: float = 0, epaisseur: float = 1, marge: float = 0, rond: bool = false, cote: String = "bottom") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = MenuJoueur.teinte_bloc(fond)
	style.border_color = MenuJoueur.teinte_bloc(bord)
	style.set_border_width_all(0)
	if bord.a > 0.0: style.set("border_width_" + cote, maxi(1, px(epaisseur)))
	style.set_corner_radius_all(maxi(2, px(rayon)) if rond else 0)
	style.set_content_margin_all(px(marge))
	style.anti_aliasing = rond
	return Charte.ombrer(style, rayon if rond else 0.0)

## Panneau à plat de la charte : fond opaque, sans bordure ; au plus UN filet (`cote` : left, top, bottom).
func _plat(fond: Color = C.PANEL, filet: Color = Color.TRANSPARENT, marge: float = 0, cote: String = "left", epaisseur: float = 3, ombre: bool = false) -> StyleBoxFlat:
	var style := _boite(fond, Color.TRANSPARENT, 0, 0, marge)
	if filet.a > 0.0:
		style.border_color = filet
		style.set("border_width_" + cote, maxi(1, px(epaisseur)))
	return Charte.ombrer_droit(style) if ombre else style

## Titre de section de la charte : Barlow Condensed ExtraBold Italic, capitales, ivoire.
func _titre_section(texte: String, taille: float) -> Label:
	return _texte(texte.to_upper(), taille, C.IVORY, Charte.TITRE_EXTRA_ITALIQUE)

## Coche du choix courant (icône de la charte) : la couleur ne porte jamais seule le choix.
func _coche(taille: float = 16) -> TextureRect:
	var coche := TextureRect.new()
	coche.name = "Coche"
	coche.texture = C.icon_texture("check", C.IVORY)
	coche.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coche.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coche.custom_minimum_size = Vector2(px(taille), px(taille))
	coche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coche

## L'un de nos joueurs (fiche complète disponible dans le direct) ? Les autres n'ont ni lien ni mini-fiche.
func _est_des_notres(id: String) -> bool:
	if id.is_empty() or not app is Control: return false
	return not (load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad") as Dictionary).is_empty()

## Nom d'un de nos joueurs (règle de Léo) : lien ivoire souligné au survol ; survol = mini-fiche, clic = fiche
## complète dans une page du direct (« ← Retour au direct » ramène ici, la page Équipe restée ouverte dessous).
## Sans fiche (id inconnu) : simple texte, jamais un faux lien. `largeur_max` (unités de la maquette) coupe un nom long.
func _nom_joueur(id: String, texte: String, taille: float, nom_noeud: String, largeur_max: float = 0.0, police: Font = null) -> Control:
	var fonte: Font = police if police != null else _gras
	if not _est_des_notres(id):
		var inerte := _texte(texte, taille, C.IVORY, fonte)
		inerte.name = nom_noeud
		return inerte
	var lien := Button.new()
	lien.name = nom_noeud
	lien.text = texte
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(lien)
	lien.add_theme_font_override("font", fonte)
	lien.add_theme_font_size_override("font_size", fs(taille))
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := lien.get_theme_stylebox(etat) as StyleBoxFlat
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = maxi(1, px(1))
	lien.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lien.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if largeur_max > 0.0:
		lien.clip_text = true
		lien.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lien.custom_minimum_size.x = minf(_largeur_texte(texte, fonte, fs(taille)) + 2.0, px(largeur_max))
	lien.set_meta("lien", true)
	lien.set_meta("fiche_joueur", id)
	lien.pressed.connect(ouvrir_fiche.bind(id))
	load("res://ui/carte_joueur_survol.gd").lier(app as Control, lien, id, "squad")
	# Mini-fiche posée sur l'application : au-dessus de la scène du match, comme celles du direct.
	lien.mouse_entered.connect(_mini_fiche_devant)
	return lien

func _mini_fiche_devant() -> void:
	if not app is Control: return
	var fiche: Control = MiniFiche.actuelle(app as Control)
	if fiche != null: fiche.z_index = 200

## Fiche complète d'un de nos joueurs : page « joueur » du direct posée au-dessus de la page Équipe.
func ouvrir_fiche(id: String) -> void:
	if app is Control: MiniFiche.cacher(app as Control)
	if view != null and view.has_method("ouvrir_joueur"): view.ouvrir_joueur(id)

func _clic_fiche(evenement: InputEvent, bloc: Control, id: String) -> void:
	var clic := evenement as InputEventMouseButton
	if clic == null or not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT: return
	bloc.accept_event()
	ouvrir_fiche(id)

func _texte(texte: String, taille: float, couleur: Color = C.IVORY, police: Font = null) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_override("font", police if police != null else C.BODY)
	etiquette.add_theme_font_size_override("font_size", fs(taille))
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiquette

func _titre(texte: String, taille: float, couleur: Color = C.IVORY, poids: int = 800) -> Label:
	return _texte(texte, taille, couleur, C.font(poids))

func _coupe(etiquette: Label) -> Label:
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return etiquette

## Texte qui passe à la ligne (au plus `lignes`) plutôt que d'être coupé ; le contrôle vérifie « non tronqué ».
func _sur_deux_lignes(etiquette: Label, lignes: int) -> Label:
	etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiquette.max_lines_visible = lignes
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiquette.custom_minimum_size.x = 1.0
	return etiquette

func _h(ecart: float) -> HBoxContainer:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", px(ecart))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rangee

func _v(ecart: float) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", px(ecart))
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return colonne

func _panneau(style: StyleBox) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", style)
	return cadre

## Bloc posé à sa place de la maquette (unités 1600×900).
func _poser(controle: Control, x: float, y: float, largeur: float, hauteur: float) -> Control:
	controle.position = Vector2(x, y) * k
	controle.size = Vector2(largeur, hauteur) * k
	controle.custom_minimum_size = Vector2.ZERO
	_page.add_child(controle)
	controle.position = Vector2(x, y) * k
	controle.size = Vector2(largeur, hauteur) * k
	return controle

## Bouton de la charte (§7) :
## - « principal » : pilule dorée, texte `PANNEAU` — le SEUL aplat doré de la fenêtre (« Valider et reprendre » ;
##   la fenêtre couvre la coque, donc pas de Continuer à l'écran) ;
## - « lien » : texte ivoire (+ flèche), souligné au survol et au focus, sans cadre ni fond ;
## - « segment » / « choisi » : choix d'un groupe (onglets, crans, candidats) souligné d'un filet bas fin ; le choix
##   courant sur fond sombre relevé, filet GAUCHE épais ivoire et coche (jamais un second ivoire plein, jamais d'or).
func _bouton(texte: String, action: Callable, genre: String = "lien", taille: float = 18, nom: String = "") -> Button:
	var bouton := Button.new()
	bouton.text = texte
	if not nom.is_empty(): bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	if genre == "principal":
		C.style_bouton_ivoire_plein(bouton)
		for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var boite := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			boite.content_margin_left = px(22)
			boite.content_margin_right = px(22)
			boite.content_margin_top = px(8)
			boite.content_margin_bottom = px(8)
		# Éteint : à plat, un seul filet bas (le style commun pose un cadre complet, exclu par la charte §3).
		var eteint := bouton.get_theme_stylebox("disabled") as StyleBoxFlat
		eteint.set_border_width_all(0)
		eteint.border_width_bottom = maxi(1, px(1))
		bouton.add_theme_font_override("font", C.font(800))
	elif genre == "lien":
		C.style_bouton_lien(bouton)
		bouton.set_meta("lien", true)
	else:
		_style_segment(bouton, genre == "choisi")
	bouton.add_theme_font_size_override("font_size", fs(taille))
	bouton.pressed.connect(action)
	return bouton

## Habillage d'un choix de groupe (charte §3 : jamais de cadre complet) : filet bas fin ; choisi : fond sombre relevé
## (PANNEAU_3, jamais l'ivoire plein du bouton principal), filet gauche épais ivoire et coche (`set_meta("coche")`).
func _style_segment(bouton: Button, choisi: bool) -> void:
	for etat: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = C.SELECTED if choisi or etat in ["hover", "pressed", "hover_pressed"] else Color(0, 0, 0, 0)
		style.border_color = C.FAINT if etat == "disabled" and not choisi else (C.IVORY if choisi or etat in ["focus", "hover"] else C.LINE)
		if choisi: style.border_width_left = maxi(2, px(4))
		else: style.border_width_bottom = maxi(1, px(2 if etat in ["focus", "hover"] else 1))
		# Charte finale : choix et onglets arrondis comme les cases (rayon 6).
		style.set_corner_radius_all(maxi(2, px(Charte.RAYON_PETIT)))
		style.anti_aliasing = true
		style.content_margin_left = px(14)
		style.content_margin_right = px(14)
		style.content_margin_top = px(7)
		style.content_margin_bottom = px(7)
		bouton.add_theme_stylebox_override(etat, style)
	for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(cle, C.IVORY)
	bouton.add_theme_color_override("font_disabled_color", C.FAINT)
	bouton.add_theme_font_override("font", C.font(700))
	bouton.icon = C.icon_texture("check", C.IVORY) if choisi else null
	bouton.add_theme_constant_override("icon_max_width", fs(14))
	bouton.set_meta("coche", choisi)

## Portrait à angles droits ; découpé en disque (`rond`) seulement sur le terrain (médaillons des joueurs).
func _portrait(joueur: Dictionary, largeur: float, hauteur: float = -1.0, rond: bool = false) -> Control:
	var h := hauteur if hauteur > 0.0 else largeur
	var cadre := Panel.new()
	cadre.name = "Portrait"
	cadre.custom_minimum_size = Vector2(largeur, h)
	cadre.size = Vector2(largeur, h)
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", Charte.sans_ombre(_boite(C.RAISED, Color.TRANSPARENT, largeur / 2.0 / k, 0, 0, rond)))
	var complet := _joueur_complet(joueur)
	var image: TextureRect = G.portrait_lazy(int(complet.get("portraitIndex", 0)), roundi(largeur), complet)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	var cote := maxf(largeur, h)
	image.position = Vector2((largeur - cote) / 2.0, 0)
	image.size = Vector2(cote, cote * 1.12)
	cadre.add_child(image)
	cadre.set_meta("portrait", true)
	return cadre

## Fond opaque à plat (charte §3 : pas de dégradé) ; il arrête la souris pour le direct dessous.
func _fond() -> void:
	var fond := ColorRect.new()
	fond.name = "TeamBackdrop"
	# Ardoise claire (teinte D), comme toutes les fenêtres du direct (Léo, 23/11).
	fond.color = MenuJoueur.PAL.fond
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	add_child(fond)
	MenuJoueur.fond_plein(fond)

func _horloge() -> String:
	if view != null and view.get("clock") is Label: return str(view.clock.text)
	return "%d′" % int(_live().get("minute", 0))

func _score() -> String:
	if view != null and view.get("score") is Label: return str(view.score.text).replace("—", "–")
	var score: Array = _live().get("score", [0, 0])
	return "%d – %d" % [int(score[0]), int(score[1])] if score.size() >= 2 else ""

func _largeur_texte(texte: String, police: Font, taille: int) -> float:
	return police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

func _entete() -> void:
	var cadre := _panneau(_plat(C.PANEL, C.LINE, 0, "bottom", 1, true))
	cadre.name = "TeamHeader"
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(14)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(20)
	_poser(cadre, 24, 16, 1552, 64)
	var rangee := _h(18)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	cadre.add_child(rangee)
	# Retour au direct : ferme la page sans valider (le match reste arrêté) ; « Valider et reprendre » reste l'action principale.
	var retour := _bouton("← Retour au direct", func(): fermer(false), "lien", 17, "TeamBackToLive")
	retour.tooltip_text = "Revenir au direct sans relancer le match."
	retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(retour)
	var pastille := _panneau(_plat(C.SELECTED))
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(12)
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(12)
	pastille.custom_minimum_size.y = px(36)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var horloge := _titre(_horloge(), 28, C.IVORY, 700)
	horloge.name = "TeamClock"
	horloge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pastille.add_child(horloge)
	rangee.add_child(pastille)
	var equipes: Array = _live().get("teams", [])
	var noms: Array[String] = []
	for n in 2: noms.append(S.G.club_name(equipes[n]).to_upper() if equipes.size() > n and equipes[n] is Dictionary else "")
	var police_nom := C.font(700)
	for n in 2:
		var nom := _coupe(_titre(noms[n], 26, C.IVORY, 700))
		nom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nom.custom_minimum_size.x = minf(_largeur_texte(noms[n], police_nom, fs(26)) + 2.0, px(330))
		nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rangee.add_child(nom)
		if n == 0:
			var cadre_score := _panneau(_plat(C.BG))
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(14)
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(14)
			cadre_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var score := _titre(_score(), 34, C.IVORY, 800)
			score.name = "TeamScore"
			cadre_score.add_child(score)
			rangee.add_child(cadre_score)
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(vide)
	var en_pause := bool(_live().get("paused", false))
	var etat := _panneau(_plat(Color.TRANSPARENT))
	etat.name = "TeamPauseState"
	var style_etat := etat.get_theme_stylebox("panel") as StyleBoxFlat
	style_etat.content_margin_left = px(4)
	style_etat.content_margin_right = px(4)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etat.add_child(_texte("Match en pause" if en_pause else "Mise en pause…", 13, C.IVORY if en_pause else C.MUTED))
	rangee.add_child(etat)
	for paire: Array in [["composition", "Composition", "TeamTabComposition"], ["consignes", "Consignes", "TeamTabConsignes"], ["roles", "Rôles", "TeamTabRoles"]]:
		var vers: String = paire[0]
		var bouton := _bouton(paire[1], func(): choisir_onglet(vers), "choisi" if onglet == vers else "segment", 18, paire[2])
		bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(bouton)

func _pied(gauche: Callable, secondaire: Array) -> void:
	var cadre := _panneau(_plat(C.PANEL, C.LINE, 0, "top", 1, true))
	cadre.name = "TeamFooter"
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(16)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(16)
	_poser(cadre, 24, 820, 1552, 64)
	var rangee := _h(10)
	cadre.add_child(rangee)
	var hote := Control.new()
	hote.name = "TeamFooterInfo"
	hote.clip_contents = true
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(hote)
	var lignes := _v(0)
	lignes.alignment = BoxContainer.ALIGNMENT_CENTER
	S.full(lignes)
	hote.add_child(lignes)
	var infos := _h(10)
	infos.name = "TeamFooterLine1"
	lignes.add_child(infos)
	_pied_ligne2 = _h(10)
	_pied_ligne2.name = "TeamFooterLine2"
	lignes.add_child(_pied_ligne2)
	gauche.call(infos)
	if _pied_ligne2.get_child_count() == 0: _pied_ligne2.hide()
	var bouton_secondaire := _bouton(str(secondaire[0]), secondaire[1], "lien", 18, str(secondaire[2]))
	bouton_secondaire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(bouton_secondaire)
	var reprise := _bouton("Valider et reprendre", func(): fermer(true), "principal", 18, "TeamResume")
	reprise.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(reprise)

## Puce d'information : à plat, angles droits, un seul filet à gauche (sa teinte double le mot, jamais seule).
func _puce(texte: String, couleur: Color = C.IVORY, bord: Color = C.LINE, taille: float = 13) -> PanelContainer:
	var puce := _panneau(_plat(C.RAISED, bord, 0, "left", 2))
	var style := puce.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(3)
	style.content_margin_bottom = px(3)
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(_texte(texte, taille, couleur))
	return puce

## Consignes hors cran neutre, en puces « Rucks · Contester ».
func _consignes_actives(p: Dictionary) -> Array[String]:
	var resultat: Array[String] = []
	for axe_v: Variant in Pilotage.axes(p):
		if not axe_v is Dictionary: continue
		var axe: Dictionary = axe_v
		var options: Array = axe.get("options", []) if axe.get("options") is Array else []
		if options.size() < 3: continue
		var cran := Pilotage.cran(p, axe)
		if cran == str(options[1].get("id", "")): continue
		for option: Variant in options:
			if option is Dictionary and str(option.get("id", "")) == cran: resultat.append("%s · %s" % [str(axe.get("label", "")), str(option.get("label", ""))])
	return resultat
