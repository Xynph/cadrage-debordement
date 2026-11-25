extends "res://ui/contextual/match_between_adjoint.gd"
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la fenêtre Équipe (composition, banc,
## consignes ; choix de Léo du 18/11/2026 : un seul bouton à la place de Tactique et Banc).
## Une seule mise en page, « Bord de terrain » (choix de Léo du 21/11/2026) en tableau de bord (option A de la revue
## FM27, 22/11/2026) : à gauche Gabi, les 3 derniers événements, le bonus et le banc ; au centre le terrain entre les
## deux compositions notées, la domination sous le terrain, la phrase de jeu, les chiffres en barres miroir et la courbe
## cumulée ; à droite le classement complet et le multiplex ; en bas Mon XV, une carte par joueur (visage cerclé de son
## énergie, note, moral en direct). Plein écran obligatoire : chaque clic ouvre une petite fenêtre
## par-dessus le match (joueur, club, fait, chiffre, match du multiplex). Il n'affiche que la projection `live.direct`
## du moteur et le modèle : aucun calcul sportif, aucune écriture d'état.

func _ready() -> void:
	name = "MatchBetween"
	mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(self)
	_densite = densite_pour(get_viewport_rect().size)
	_construire()
	resized.connect(_a_l_echelle)
	resized.connect(_largeur_multiplex)
	visibility_changed.connect(_apparaitre)

## Apparition en fondu (0,25 s), sauf si le joueur a demandé de réduire les animations.
func _apparaitre() -> void:
	if not visible:
		fermer_fiche()
		return
	if _animations_reduites():
		modulate.a = 1.0
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## La fenêtre a changé de taille : tout l'écran est reconstruit à la nouvelle échelle.
func _a_l_echelle() -> void:
	var densite := densite_pour(get_viewport_rect().size)
	if is_equal_approx(densite, _densite): return
	_densite = densite
	_construire()
	if not _dernier.is_empty(): update_frame.callv(_dernier)

## Une seule mise en page (choix de Léo du 19/11/2026, variante 1 « Terrain au centre ») : la barre de
## commandes, puis Mon XV à gauche (titulaires, banc), le terrain 2D au centre, les chiffres clés à droite
## (la même colonne accueille le panneau d'arrêt, les réglages, les autres matchs) ; dessous la domination
## minute par minute en largeur, Gabi, et le pied des raccourcis.
func _construire() -> void:
	# Le terrain garde sa lecture (places, file des faits) d'une échelle à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	if is_instance_valid(fiche_match): fermer_fiche()
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	_journee_cle = ""
	_temps_forts_cle = ""
	_evenements_cle = ""
	_bonus_cle = ""
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.legende = false
	# Pastilles à l'échelle du terrain (demande de Léo du 21/11/2026 : « ça fait pâté ») : petits ronds nets, numéros
	# écrits quand ils tiennent (masqués en dessous, infobulle au survol), ballon cerclé d'un halo.
	terrain.plancher_pastilles = 0.0
	terrain.pelouse = true
	terrain.taille_pastilles = 1.15
	terrain.remplir = true
	terrain.custom_minimum_size = Vector2(320, 180)
	if not terrain.pastille_survolee.is_connected(_survol_pastille): terrain.pastille_survolee.connect(_survol_pastille)
	if not terrain.pastille_choisie.is_connected(_choix_pastille): terrain.pastille_choisie.connect(_choix_pastille)
	_commandes()
	_composants()
	_page()
	# Conseils de Gabi en bulles dans sa carte et phrase de jeu en aplat coloré (idée FM27 n° 35).
	BullesAdjoint.poser(self)
	_arret_decision()
	montrer_droite(vue_droite)
	if not _arret.is_empty(): montrer_arret(_arret)
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

func _commandes() -> void:
	phase = _texte("", 22 * BARRE_HAUT, DOUX)
	phase.name = "MatchBetweenPhase"
	phase.clip_text = true
	phase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(phase)
	etat = _texte("", 22, IVOIRE)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	etat.custom_minimum_size.x = px(120)
	S.G.fill(etat)
	# Pas de bouton « Passer » ni de compte à rebours (choix de Léo) : le match défile en 2D à la vitesse
	# de l'horloge choisie dans les réglages.
	equipe = _bouton("ÉQUIPE", func(): tiroir_demande.emit("Équipe"), true, true)
	equipe.name = "MatchBetweenTeam"
	_equipe_pleine = true
	equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause) · T"
	equipe.set_meta("contextual_enabled", true)
	equipe.add_theme_font_override("font", TITRES_EXTRA)
	equipe.add_theme_font_size_override("font_size", fpx(24 * BARRE_HAUT))
	equipe.custom_minimum_size.y = maxi(26, px(46 * BARRE_HAUT))
	plus = MenuButton.new()
	plus.name = "MatchBetweenMore"
	plus.text = "Plus ▾"
	plus.flat = true
	plus.tooltip_text = "Statistiques complètes, journal du match, autres matchs et classement en direct, confier la fin à l’adjoint, caméras."
	plus.focus_mode = Control.FOCUS_ALL
	plus.set_meta("contextual_enabled", true)
	C.style_bouton_lien(plus)
	plus.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	var menu := plus.get_popup()
	menu.add_theme_font_size_override("font_size", fpx(22))
	_habiller_menu(menu)
	for libelle: String in ["Statistiques", "Journal du match", "Confier la fin à l’adjoint", "Autres matchs et classement en direct"]: menu.add_item(libelle)
	# Caméras du direct 3D (la barre du bas est masquée en temps forts).
	menu.add_separator("Caméra des temps forts")
	for paire: Array in [["Vue TV", "tv"], ["Vue de dessus", "tactical"], ["Vue contact", "action"]]:
		menu.add_item(str(paire[0]))
		menu.set_item_metadata(menu.item_count - 1, paire[1])
	# Vitesse de l'horloge entre deux temps forts : seulement ici (retouche de Léo du 21/11/2026), la courante cochée.
	menu.add_separator("Vitesse de l’horloge")
	for n in HORLOGES_IDS.size(): menu.add_radio_check_item(HORLOGES_COURTS[n], ID_VITESSE + n)
	# Caméras : la caméra courante cochée ; pendant l'entracte 2D, elles n'ont pas d'effet visible : grisées et
	# dites « en 3D seulement » (la raison est écrite, jamais un choix muet).
	var cameras := {"tv": "Vue TV", "tactical": "Vue de dessus", "action": "Vue contact"}
	menu.about_to_popup.connect(func():
		var en_2d := is_visible_in_tree()
		# Autres matchs : panneau de l'entracte ; pendant un temps fort 3D, grisé et dit (jamais un choix muet).
		menu.set_item_disabled(3, journee_vue == null or not en_2d)
		menu.set_item_text(3, "Autres matchs et classement en direct" + (" · aucun autre match" if journee_vue == null else ("" if en_2d else " · à l’entracte")))
		for n in HORLOGES_IDS.size(): menu.set_item_checked(menu.get_item_index(ID_VITESSE + n), HORLOGES_IDS[n] == horloge)
		var actuelle := camera_actuelle()
		for k in menu.item_count:
			var cle: Variant = menu.get_item_metadata(k)
			if not cle is String or not cameras.has(cle): continue
			menu.set_item_as_radio_checkable(k, true)
			menu.set_item_checked(k, cle == actuelle)
			menu.set_item_disabled(k, en_2d)
			menu.set_item_text(k, str(cameras[cle]) + (" · en 3D seulement" if en_2d else "")))
	menu.id_pressed.connect(func(id: int):
		if id >= ID_VITESSE and id < ID_VITESSE + HORLOGES_IDS.size():
			horloge = HORLOGES_IDS[id - ID_VITESSE]
			horloge_choisie.emit(horloge)
			_poser_phase(_dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {})
			return
		if id == 0: tiroir_demande.emit("Stats")
		elif id == 1: tiroir_demande.emit("Journal")
		elif id == 2:
			if is_visible_in_tree(): montrer_droite("delegation")
			else: confier_fin_demande.emit()
		elif id == 3: montrer_droite("journee")
		else:
			var index := menu.get_item_index(id)
			if index >= 0 and menu.get_item_metadata(index) is String: camera_demandee.emit(str(menu.get_item_metadata(index))))
	# Réglages : vitesse de l'horloge et temps forts montrés, dans la colonne de droite (jamais une fenêtre).
	parametres = _lien("Réglages", func(): _ouvrir_parametres(), "MatchBetweenSettings")
	parametres.tooltip_text = "Temps forts montrés."
	parametres.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	# Pendant un temps fort 3D (entracte caché), les mêmes réglages en menu déroulant sous le lien (exception de Léo).
	menu_reglages = PopupMenu.new()
	menu_reglages.name = "MatchBetweenSettingsMenu"
	menu_reglages.add_theme_font_size_override("font_size", fpx(22))
	_habiller_menu(menu_reglages)
	menu_reglages.id_pressed.connect(_choix_menu_reglages)
	parametres.add_child(menu_reglages)

## Menu déroulant à la charte : carte `PANNEAU` opaque rayon 12, sans ombre ni cadre ; survol en case
## `PANNEAU_3` rayon 6 ; texte crème (grisé pour un choix indisponible).
func _habiller_menu(menu: PopupMenu) -> void:
	# Ardoise claire (teinte D) des petites fenêtres du direct (Léo, 23/11) ; survol en case plus claire.
	menu.add_theme_stylebox_override("panel", MenuJoueur.style_ardoise(px(8), false))
	menu.add_theme_stylebox_override("hover", _case(MenuJoueur.PAL.case))
	var filet := StyleBoxLine.new()
	filet.color = MenuJoueur.PAL.filet
	filet.thickness = 1
	for cle in ["separator", "labeled_separator_left", "labeled_separator_right"]: menu.add_theme_stylebox_override(cle, filet)
	for cle in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(cle, IVOIRE)
	menu.add_theme_color_override("font_disabled_color", MenuJoueur.PAL.encre3)
	menu.add_theme_color_override("font_separator_color", MenuJoueur.PAL.encre2)
	menu.add_theme_constant_override("v_separation", px(10))
	menu.transparent_bg = true

## Réglages en menu déroulant (temps fort 3D) : vitesse de l'horloge (0 à 3) et temps forts montrés (100 et plus),
## le choix courant coché.
func _remplir_menu_reglages() -> void:
	menu_reglages.clear()
	# La vitesse de l'horloge se règle seulement dans « Plus » (retouche de Léo du 21/11/2026).
	if _niveaux.is_empty(): return
	menu_reglages.add_separator("Temps forts montrés")
	var choisi := niveau_libelle()
	for n in _niveaux.size():
		var libelle := str(_niveaux[n].get("label", ""))
		menu_reglages.add_radio_check_item(libelle, 100 + n)
		menu_reglages.set_item_checked(menu_reglages.get_item_index(100 + n), libelle == choisi)

func _choix_menu_reglages(id: int) -> void:
	if id >= 0 and id < HORLOGES_IDS.size():
		var bouton := find_child("MatchBetweenSpeed%d" % id, true, false) as Button
		if bouton != null: bouton.button_pressed = true
		horloge = HORLOGES_IDS[id]
		horloge_choisie.emit(horloge)
		_poser_pied()
	elif id >= 100 and id - 100 < _niveaux.size():
		var niveau := str(_niveaux[id - 100].get("id", ""))
		_remplir_niveaux(niveau)
		niveau_choisi.emit(niveau)

## Caméra du direct 3D retenue dans les préférences du joueur (« tv », « tactical », « action »), vide sinon.
func camera_actuelle() -> String:
	var app: Object = _app()
	var preferences: Variant = app.get("user_preferences") if app != null else null
	if preferences is Object and preferences.has_method("effective_camera"): return str(preferences.effective_camera())
	return ""

func _ouvrir_parametres() -> void:
	if not is_visible_in_tree() and is_instance_valid(menu_reglages):
		_remplir_menu_reglages()
		var ancre := parametres.get_global_rect()
		menu_reglages.popup(Rect2i(Vector2i(ancre.position + Vector2(0, ancre.size.y)), Vector2i.ZERO))
		return
	montrer_droite("chiffres" if vue_droite == "reglages" else "reglages")

func _remplir_niveaux(choisi: String = "") -> void:
	if not is_instance_valid(grille_niveaux): return
	S.clear(grille_niveaux)
	groupe_niveaux = ButtonGroup.new()
	for n in _niveaux.size():
		var id := str(_niveaux[n].get("id", ""))
		var choix := _segment(str(_niveaux[n].get("label", "")), groupe_niveaux, id == choisi)
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choix.pressed.connect(func(): niveau_choisi.emit(id))
		grille_niveaux.add_child(choix)

func _libelle_niveau(id: Variant) -> String:
	for item: Dictionary in _niveaux:
		if item.get("id") == id: return str(item.get("label", ""))
	return ""

func montrer_niveau(id: String) -> void:
	niveau_regie = id
	if not _niveaux.is_empty() and niveau_libelle() != _libelle_niveau(id): _remplir_niveaux(id)

## Libellé du niveau de temps forts choisi dans les réglages (vide s'il n'y en a pas).
func niveau_libelle() -> String:
	if groupe_niveaux == null: return ""
	var choisi := groupe_niveaux.get_pressed_button()
	return choisi.text if choisi != null else ""

## Composants : frise de domination, chiffres clés, fil, Mon XV, banc, carte de Gabi.
func _composants() -> void:
	domination = Domination.new()
	domination.name = "MatchBetweenMomentum"
	domination.densite = _densite
	domination.custom_minimum_size = Vector2(0, px(170))
	domination.tooltip_text = "Qui domine, minute par minute (occupation, possession, points, franchissements) : chaque club à sa couleur, nous au-dessus de l’axe ; essais (E), pénalités (P) et cartons (C) à leur minute."
	domination.mouse_filter = Control.MOUSE_FILTER_STOP
	domination.repere_choisi.connect(func(i: int): journal_demande.emit(i))
	S.G.fill(domination, true)
	chiffres = S.G.v(px(6))
	chiffres.name = "MatchBetweenFigures"
	fil = S.G.v(px(4))
	fil.name = "MatchBetweenFeed"
	xv = GridContainer.new()
	xv.name = "MatchBetweenSquad"
	xv.columns = 1
	xv.add_theme_constant_override("v_separation", 0)
	S.G.fill(xv)
	banc = GridContainer.new()
	banc.columns = 2
	banc.add_theme_constant_override("h_separation", px(12))
	banc.add_theme_constant_override("v_separation", 0)
	banc.name = "MatchBetweenBenchList"
	adjoint = S.G.v(px(10))
	adjoint.name = "MatchBetweenAdvice"

## Carte de Gabi (portrait, une phrase, l'action proposée) en largeur, sous la domination.
func _carte_gabi(parent: Control) -> void:
	var cadre := _panneau(parent, px(14))
	adjoint_cadre = cadre.get_parent().get_parent()
	adjoint_cadre.name = "MatchBetweenAdviceCard"
	cadre.add_child(adjoint)

## Mise en page (maquette 14-match-entracte-1, choix de Léo du 19/11/2026).
func _page() -> void:
	var page := _boite(false, GOUTTIERE)
	page.name = "MatchBetweenPage"
	S.full(page)
	# Marge basse : le pied des raccourcis ne touche jamais le bord de l'écran.
	page.offset_bottom = -px(8)
	# Le même vide visible au-dessus de la page que entre ses blocs (sous la ligne du vent).
	page.offset_top = px(GOUTTIERE - 12)
	add_child(page)
	var barre: Control
	if is_instance_valid(hote_barre):
		S.clear(hote_barre)
		barre = hote_barre
	else:
		barre = S.G.h(px(12))
		(barre as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		page.add_child(barre)
	var noeuds_barre: Array[Control] = [phase, equipe, _touche("T", BARRE_HAUT), parametres, plus]
	lien_consignes = _lien("Consignes", func(): consignes_demandees.emit(), "MatchBetweenConsignes")
	lien_consignes.add_theme_font_size_override("font_size", fpx(22 * BARRE_HAUT))
	noeuds_barre.insert(3, lien_consignes)
	for noeud: Control in noeuds_barre: barre.add_child(noeud)
	# Bouton « Banc » (idée FM27 n° 34, menu déroulant comme dans FM) : cris d'équipe, à un joueur, ajustements, ailes.
	load("res://ui/contextual/match_banc_fm.gd").poser(self, barre, page)
	_page_d3(page)

## Pied : les raccourcis de l'écran et où trouver ce qui n'y est pas (vitesse, autres matchs).
func _pied(page: Control) -> void:
	pied = S.G.h(px(10))
	pied.name = "MatchBetweenKeys"
	page.add_child(pied)
	# Raccourcis derrière un « ? » (règle du 21/11/2026 : plus de mode d'emploi à l'écran).
	var aide := PanelContainer.new()
	aide.name = "MatchBetweenKeysHelp"
	aide.tooltip_text = "Espace : reprendre ou mettre en pause · Échap : pause et menu · T : équipe · ↑ ↓ : choisir un joueur · Entrée : remplacer"
	aide.accessibility_name = aide.tooltip_text
	aide.mouse_filter = Control.MOUSE_FILTER_STOP
	aide.mouse_default_cursor_shape = Control.CURSOR_HELP
	aide.custom_minimum_size = Vector2(px(28), px(28))
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.PANNEAU_3
	fond.set_corner_radius_all(Charte.RAYON_PILULE)
	aide.add_theme_stylebox_override("panel", fond)
	var signe := _texte("?", maxi(12, px(15)), DOUX)
	signe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	signe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aide.add_child(signe)
	pied.add_child(aide)
	pied_reglages = _texte("", 18, DOUX)
	pied_reglages.name = "MatchBetweenKeysSettings"
	pied_reglages.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pied_reglages.clip_text = true
	pied_reglages.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pied_reglages.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	S.G.fill(pied_reglages)
	pied.add_child(pied_reglages)

## Colonne gauche : Mon XV (numéro, nom, énergie, plaquages, note), puis le banc ; un lien bascule sur le XV
## adverse. Une ligne choisie (clic, ↑ ↓ puis Entrée) ouvre la fenêtre Équipe sur ce joueur ; le nom ouvre sa
## fiche, son survol la mini-fiche.
func _colonne_xv(grille: Control) -> void:
	var cadre_xv := _panneau(grille, px(18))
	tuile_principale = cadre_xv.get_parent().get_parent()
	tuile_principale.name = "MatchBetweenMain"
	# Assez large pour que le nom le plus long du banc (« Matthew BOOTHROYD ») se lise en entier, banc sur deux colonnes.
	tuile_principale.custom_minimum_size.x = px(780)
	# Séparation serrée (1 px à 1080p) : les quinze lignes et le pied « Équipe » tiennent sans défilement.
	cadre_xv.add_theme_constant_override("separation", px(1))
	var tete := S.G.h(px(10))
	cadre_xv.add_child(tete)
	titre_xv = _titre_bloc("Mon XV", 26)
	titre_xv.name = "MatchBetweenSquadTitle"
	S.G.fill(titre_xv)
	tete.add_child(titre_xv)
	lien_adverse = _lien("XV adverse →", func(): choisir_vue_xv("tableau" if vue_xv == "adverse" else "adverse"), "MatchBetweenTabOpponent")
	lien_adverse.tooltip_text = "Voir le XV adverse (notes, énergie, plaquages) ; revenir à Mon XV."
	tete.add_child(lien_adverse)
	var entete := S.G.h(px(6))
	entete.name = "MatchBetweenSquadHeader"
	# En-têtes triables (comme les tableaux de Football Manager) : un clic trie, un second retourne le sens.
	entetes_tri.clear()
	for k in COLONNES_XV.size():
		var colonne: Array = COLONNES_XV[k]
		var libelle := str(colonne[0]).to_upper()
		var cle: String = TRIS_XV[k]
		var tete_col := Button.new()
		tete_col.name = "MatchBetweenSort_" + cle
		tete_col.flat = false
		tete_col.focus_mode = Control.FOCUS_ALL
		tete_col.set_meta("tri", cle)
		tete_col.set_meta("libelle", libelle)
		tete_col.set_meta("contextual_enabled", true)
		tete_col.text = libelle
		# Jamais rogné (« LAQ. ») : la colonne s'élargit de la flèche s'il le faut.
		tete_col.clip_text = false
		tete_col.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tete_col.tooltip_text = "Trier Mon XV par %s (un second clic retourne le sens)." % str(colonne[0]).to_lower() if cle != "numero" else "Revenir à l’ordre des postes (un second clic retourne le sens)."
		# Tri en pastilles (les tuiles n'ont pas de colonnes) : la pastille du tri courant sur la sélection de la charte.
		for etat_bouton in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			var pilule := StyleBoxFlat.new()
			pilule.bg_color = SURVOL if etat_bouton in ["hover", "hover_pressed"] else RELIEF
			pilule.set_corner_radius_all(Charte.RAYON_PILULE)
			pilule.anti_aliasing = true
			pilule.content_margin_left = px(14)
			pilule.content_margin_right = px(14)
			pilule.content_margin_top = px(3)
			pilule.content_margin_bottom = px(3)
			if etat_bouton == "focus": _anneau(pilule)
			tete_col.add_theme_stylebox_override(etat_bouton, pilule)
		tete_col.add_theme_font_override("font", TITRES)
		for couleur in ["font_color", "font_focus_color"]: tete_col.add_theme_color_override(couleur, DOUX)
		for couleur in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]: tete_col.add_theme_color_override(couleur, IVOIRE)
		tete_col.add_theme_color_override("font_disabled_color", FAIBLE)
		tete_col.add_theme_font_size_override("font_size", fpx(16))
		tete_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tete_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete_col.pressed.connect(trier_xv.bind(cle))
		entetes_tri.append(tete_col)
		entete.add_child(tete_col)
	_poser_entete_tri()
	var defile := ScrollContainer.new()
	defile.name = "MatchBetweenSquadScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# D : les tuiles des joueurs tiennent toutes (jamais d'ascenseur).
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile, true)
	tableau_xv = S.G.v(0)
	tableau_xv.name = "MatchBetweenTable"
	S.G.fill(tableau_xv)
	cadre_xv.add_child(entete)
	cadre_xv.add_child(defile)
	defile_xv = defile
	defile.add_child(tableau_xv)
	tableau_xv.add_child(xv)
	# Total de l'équipe : pied fixe sous la zone de défilement (jamais coupé), aligné sur les colonnes des lignes.
	pied_xv = S.G.v(0)
	pied_xv.name = "MatchBetweenSquadFoot"
	cadre_xv.add_child(pied_xv)
	defile.resized.connect(_aligner_pied_xv)
	defile.get_v_scroll_bar().visibility_changed.connect(_aligner_pied_xv)
	# Banc : zone fixe sous les titulaires, toujours visible (le remplacement est l'action de l'entracte) ; deux
	# colonnes de numéro, nom et poste ; le nombre de changements restants en tête.
	zone_banc = S.G.v(px(2))
	zone_banc.name = "MatchBetweenBenchZone"
	cadre_xv.add_child(zone_banc)
	var filet := ColorRect.new()
	filet.color = TRAIT
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_banc.add_child(filet)
	var tete_banc := S.G.h(px(10))
	tete_banc.name = "MatchBetweenBenchHeader"
	var titre_banc := _titre_bloc("Banc", 22)
	S.G.fill(titre_banc)
	tete_banc.add_child(titre_banc)
	precision_banc = _texte("", 18, DOUX)
	precision_banc.name = "MatchBetweenBenchCount"
	tete_banc.add_child(precision_banc)
	zone_banc.add_child(tete_banc)
	zone_banc.add_child(banc)
	_montrer_vue_xv()

## Colonne centrale : le terrain 2D (où est le ballon, qui attaque), le dernier fait joué en une ligne.
func _colonne_centre(grille: Control) -> void:
	var cadre_terrain := _panneau(grille, px(14))
	var tuile: Control = cadre_terrain.get_parent().get_parent()
	tuile.name = "MatchBetweenPitchTile"
	S.G.fill(tuile, true, 1.0)
	cadre_terrain.add_theme_constant_override("separation", px(6))
	var tete := S.G.h(px(14))
	tete.name = "MatchBetweenPitchHeader"
	cadre_terrain.add_child(tete)
	var titre_terrain := _titre_bloc("Terrain", 24)
	titre_terrain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(titre_terrain)
	# L'état du jeu en entier (jamais « … ») : il prend la largeur et sa taille baisse s'il le faut.
	tete.add_child(etat)
	S.G.fill(etat)
	etat.clip_text = true
	etat.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etat.set_meta("taille_base", etat.get_theme_font_size("font_size"))
	etat.resized.connect(_ajuster_taille.bind(etat))
	# Le sens du jeu est dessiné sur le terrain (flèche sous le ballon) : écrit en infobulle de l'état.
	sens_jeu = _texte("", 18, DOUX)
	sens_jeu.name = "MatchBetweenAttack"
	sens_jeu.visible = false
	tete.add_child(sens_jeu)
	# Le dernier fait joué, en une ligne sous l'en-tête (le journal complet est dans Plus).
	bandeau = PanelContainer.new()
	bandeau.name = "MatchBetweenBanner"
	bandeau.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(bandeau)
	cadre_terrain.add_child(bandeau)
	bandeau.add_child(fil)
	S.G.fill(fil)
	var scene := Control.new()
	scene.name = "MatchBetweenScene"
	scene.clip_contents = true
	scene.custom_minimum_size = Vector2(px(560), px(300))
	S.G.fill(scene, true)
	cadre_terrain.add_child(scene)
	S.full(terrain)
	scene.add_child(terrain)
	meteo_pastille = PastilleMeteo.new()
	meteo_pastille.name = "MatchBetweenWeather2D"
	meteo_pastille.visible = false
	scene.add_child(meteo_pastille)
	# Terrain, puis le momentum et les temps forts en pastilles dessous.
	# Hauteur du terrain tenue (vérificateur du 24/11 : 63 % de sa tuile en 2560, pastilles de 3,4 px en 1920) : en 1920 il
	# faut ≈ 208 px pour des pastilles de 4 px et un terrain qui remplit 80 % de sa tuile.
	scene.custom_minimum_size = Vector2(px(420), maxi(150, px(277)))
	cadre_terrain.add_child(_bande_momentum())
	temps_forts = S.G.h(px(8))
	temps_forts.name = "MatchBetweenHighlights"
	temps_forts.custom_minimum_size.y = px(36)
	cadre_terrain.add_child(temps_forts)

## Colonne droite : un seul panneau à la fois, à la même place (jamais une fenêtre) — chiffres clés par
## défaut, réglages, autres matchs et classement, confirmation de la délégation, et le panneau d'arrêt.
func _colonne_droite(grille: Control) -> void:
	colonne_droite = _boite(false, GOUTTIERE)
	colonne_droite.name = "MatchBetweenColumn"
	colonne_droite.custom_minimum_size.x = px(540)
	grille.add_child(colonne_droite)
	# Chiffres clés : duel face à face, lien vers les statistiques, météo, bonus.
	var cadre_chiffres := _panneau(colonne_droite, px(18))
	panneau_chiffres = cadre_chiffres.get_parent().get_parent()
	panneau_chiffres.name = "MatchBetweenDuel"
	S.G.fill(panneau_chiffres, true)
	var tete_chiffres := S.G.h(px(10))
	cadre_chiffres.add_child(tete_chiffres)
	var titre_chiffres := _titre_bloc("Chiffres clés", 24)
	S.G.fill(titre_chiffres)
	tete_chiffres.add_child(titre_chiffres)
	# Seul accès aux statistiques détaillées : fixe, à droite du titre, jamais sous le pli.
	var stats := _lien("Voir les statistiques →", func(): tiroir_demande.emit("Stats"), "MatchBetweenStatsLink")
	tete_chiffres.add_child(stats)
	# Le contenu défile s'il dépasse (1280×720 avec la tuile Bonus en fin de match) : la page tient toujours.
	var defile_chiffres := ScrollContainer.new()
	defile_chiffres.name = "MatchBetweenFiguresScroll"
	defile_chiffres.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_chiffres.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(defile_chiffres, true)
	cadre_chiffres.add_child(defile_chiffres)
	var marge_defile := MarginContainer.new()
	# Marge à droite : la barre de défilement ne rogne jamais les valeurs de l'adversaire.
	marge_defile.add_theme_constant_override("margin_right", px(18))
	S.G.fill(marge_defile)
	defile_chiffres.add_child(marge_defile)
	var contenu := S.G.v(px(10))
	contenu.name = "MatchBetweenFiguresContent"
	S.G.fill(contenu, true)
	marge_defile.add_child(contenu)
	cadre_chiffres = contenu
	legende_chiffres = S.G.h(px(8))
	legende_chiffres.name = "MatchBetweenFiguresLegend"
	cadre_chiffres.add_child(legende_chiffres)
	precision_chiffres = _texte("", 17, DOUX)
	precision_chiffres.name = "MatchBetweenFiguresSample"
	precision_chiffres.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cadre_chiffres.add_child(precision_chiffres)
	cadre_chiffres.add_child(chiffres)
	# Les lignes se répartissent la hauteur du panneau (aucun vide sous le bonus).
	S.G.fill(chiffres, true)
	# (lien des statistiques : fixe, dans l'en-tête du panneau)
	# Météo : déjà sous le score (bandeau de la vue du match) ; ici seulement en infobulle du lien des statistiques.
	meteo_ligne = _texte("", 17, DOUX, true)
	meteo_ligne.name = "MatchBetweenWeather"
	meteo_ligne.visible = false
	cadre_chiffres.add_child(meteo_ligne)
	stats_lien = stats
	# Bonus : la règle du championnat et, en fin de match, le dilemme et ses deux consignes.
	bonus_tuile = PanelContainer.new()
	bonus_tuile.name = "MatchBetweenBonus"
	var style_bonus := _case(RELIEF, Charte.RAYON_CARTE)
	style_bonus.set_content_margin_all(px(12))
	bonus_tuile.add_theme_stylebox_override("panel", style_bonus)
	cadre_chiffres.add_child(bonus_tuile)
	var cadre_bonus := S.G.v(px(6))
	bonus_tuile.add_child(cadre_bonus)
	var tete_bonus := _titre("Bonus")
	bonus_regle = _texte("", 17, DOUX, true)
	bonus_regle.name = "MatchBetweenBonusRule"
	cadre_bonus.add_child(tete_bonus)
	cadre_bonus.add_child(bonus_regle)
	bonus_etat = S.G.h(px(16))
	bonus_etat.name = "MatchBetweenBonusState"
	cadre_bonus.add_child(bonus_etat)
	bonus_situation = _texte("", 20, IVOIRE, true)
	bonus_situation.name = "MatchBetweenBonusDilemma"
	bonus_situation.max_lines_visible = 3
	bonus_situation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bonus_situation.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre_bonus.add_child(bonus_situation)
	bonus_choix = S.G.v(px(8))
	bonus_choix.name = "MatchBetweenBonusChoices"
	cadre_bonus.add_child(bonus_choix)
	bonus_tuile.visible = false
	# Réglages : vitesse de l'horloge et temps forts montrés (avant : petite fenêtre de l'engrenage).
	var cadre_reglages := _panneau(colonne_droite, px(18))
	panneau_parametres = cadre_reglages.get_parent().get_parent()
	panneau_parametres.name = "MatchBetweenSettingsPanel"
	S.G.fill(panneau_parametres, true)
	cadre_reglages.add_theme_constant_override("separation", px(12))
	cadre_reglages.add_child(_retour_droite("Réglages du match"))
	groupe_horloge = ButtonGroup.new()
	cadre_reglages.add_child(_texte("Temps forts montrés (gardé pour les prochains matchs)", 18, DOUX, true))
	grille_niveaux = GridContainer.new()
	grille_niveaux.name = "MatchHighlightLevel"
	grille_niveaux.columns = 2
	grille_niveaux.add_theme_constant_override("h_separation", px(8))
	grille_niveaux.add_theme_constant_override("v_separation", px(8))
	cadre_reglages.add_child(grille_niveaux)
	_remplir_niveaux(niveau_regie)
	# Autres matchs de la journée et classement « si ça finit ainsi » (menu Plus).
	var cadre_journee := _panneau(colonne_droite, px(18))
	panneau_journee = cadre_journee.get_parent().get_parent()
	panneau_journee.name = "MatchBetweenDayPanel"
	S.G.fill(panneau_journee, true)
	cadre_journee.add_child(_retour_droite("Autres matchs"))
	classement_tuile = PanelContainer.new()
	classement_tuile.name = "MatchBetweenLiveTable"
	classement_tuile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cadre_journee.add_child(classement_tuile)
	var cadre_classement := S.G.v(px(4))
	classement_tuile.add_child(cadre_classement)
	cadre_classement.add_child(_titre("Classement en direct", "si ça finit ainsi"))
	classement_lignes = S.G.v(px(3))
	classement_lignes.name = "MatchBetweenLiveTableRows"
	cadre_classement.add_child(classement_lignes)
	classement_tuile.visible = false
	multiplex = PanelContainer.new()
	multiplex.name = "MatchBetweenMultiplex"
	multiplex.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	cadre_journee.add_child(multiplex)
	var colonne_multiplex := S.G.v(px(6))
	multiplex.add_child(colonne_multiplex)
	var tete_multiplex := S.G.h(px(10))
	colonne_multiplex.add_child(tete_multiplex)
	var titre_multiplex := _titre_bloc("Multiplex", 22)
	S.G.fill(titre_multiplex)
	tete_multiplex.add_child(titre_multiplex)
	multiplex_precision = _texte("", 18, DOUX)
	multiplex_precision.name = "MatchBetweenMultiplexMinute"
	tete_multiplex.add_child(multiplex_precision)
	multiplex_cartes = GridContainer.new()
	multiplex_cartes.name = "MatchBetweenMultiplexCards"
	multiplex_cartes.add_theme_constant_override("h_separation", px(14))
	multiplex_cartes.add_theme_constant_override("v_separation", px(10))
	multiplex_defile = ScrollContainer.new()
	multiplex_defile.name = "MatchBetweenMultiplexScroll"
	multiplex_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	multiplex_defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	multiplex_defile.mouse_filter = Control.MOUSE_FILTER_PASS
	multiplex_defile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	multiplex_defile.tooltip_text = "Les autres matchs de la journée : molette ou glisser pour voir la suite."
	S.G.fill(multiplex_defile)
	# Le défilement et son indicateur de suite « › » (sans dégradé : charte §3).
	var pile_multiplex := MarginContainer.new()
	pile_multiplex.name = "MatchBetweenMultiplexStack"
	for cote in ["left", "right", "top", "bottom"]: pile_multiplex.add_theme_constant_override("margin_" + cote, 0)
	pile_multiplex.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(pile_multiplex)
	colonne_multiplex.add_child(pile_multiplex)
	pile_multiplex.add_child(multiplex_defile)
	multiplex_defile.add_child(multiplex_cartes)
	multiplex_fondu = PanelContainer.new()
	multiplex_fondu.name = "MatchBetweenMultiplexFade"
	# Fondu de la couleur du panneau (invisible sur lui) : masque le bord droit des cartes qui défilent.
	var style_fondu := StyleBoxFlat.new()
	style_fondu.bg_color = PANNEAU
	multiplex_fondu.add_theme_stylebox_override("panel", style_fondu)
	multiplex_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	multiplex_fondu.custom_minimum_size.x = px(40)
	multiplex_fondu.size_flags_horizontal = Control.SIZE_SHRINK_END
	multiplex_fondu.size_flags_vertical = Control.SIZE_FILL
	var suite := _texte("›", 34, IVOIRE, false, true)
	suite.name = "MatchBetweenMultiplexMore"
	suite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suite.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	multiplex_fondu.add_child(suite)
	multiplex_fondu.visible = false
	pile_multiplex.add_child(multiplex_fondu)
	multiplex_defile.resized.connect(_fondu_multiplex)
	multiplex_cartes.resized.connect(_fondu_multiplex)
	multiplex_defile.get_h_scroll_bar().value_changed.connect(func(_v: float): _fondu_multiplex())
	multiplex.visible = false
	journee_vide = _texte("Aucun autre match de la journée en cours.", 18, DOUX, true)
	journee_vide.name = "MatchBetweenDayEmpty"
	cadre_journee.add_child(journee_vide)
	# Confier la fin à l'adjoint : confirmation en place (avant : petite fenêtre de confirmation).
	var cadre_delegation := _panneau(colonne_droite, px(18))
	panneau_delegation = cadre_delegation.get_parent().get_parent()
	panneau_delegation.name = "MatchBetweenHandOver"
	S.G.fill(panneau_delegation, true)
	cadre_delegation.add_theme_constant_override("separation", px(14))
	cadre_delegation.add_child(_retour_droite("Confier la fin du match"))
	cadre_delegation.add_child(_texte("Gabi prend en charge la fin de cette rencontre : il fait ses choix (changements, consignes) et le match se termine sans toi. Le résultat compte comme si tu l’avais joué.", 19, IVOIRE, true))
	var confirmer := _bouton("Confier la fin à l’adjoint →", func():
		montrer_droite("chiffres")
		delegation_demandee.emit())
	confirmer.name = "MatchBetweenHandOverConfirm"
	confirmer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	confirmer.set_meta("contextual_enabled", true)
	cadre_delegation.add_child(confirmer)

## « Bord de terrain » (D3, choix de Léo du 21/11/2026) devenu « tableau de bord » (option A de la revue FM27, choix de
## Léo du 22/11/2026). Plein écran obligatoire : chaque clic ouvre une petite fenêtre par-dessus le match.
## À gauche Gabi, les 3 derniers événements du match, le bonus et le banc ; au centre le terrain entre les deux
## compositions notées (petits terrains), la domination sous le terrain, la phrase de jeu en grand, puis les chiffres
## en barres miroir et la courbe cumulée points / entrées dans les 22 m ; à droite le classement complet et le
## multiplex ; en bas, la barre de Mon XV (visage, énergie, note, plaquages, moral en direct).
func _page_d3(page: Control) -> void:
	compos_fm.clear()
	_compos_cle = ""
	_barres_cle = ""
	var grille := _boite(true, GOUTTIERE)
	grille.name = "MatchBetweenTiles"
	S.G.fill(grille, true, 1.0)
	page.add_child(grille)
	var gauche := _boite(false, GOUTTIERE)
	gauche.name = "MatchBetweenEventsColumn"
	gauche.custom_minimum_size.x = px(540)
	grille.add_child(gauche)
	_carte_gabi(gauche)
	_colonne_droite(gauche)
	# Le panneau des événements se réduit à son contenu (rien de vide en début de match) : le banc prend la place.
	colonne_droite.size_flags_vertical = Control.SIZE_FILL
	colonne_droite.custom_minimum_size.x = 0
	# Le panneau des chiffres clés devient celui des événements (les chiffres passent en miroir autour du terrain).
	for etiquette: Node in panneau_chiffres.find_children("*", "Label", true, false):
		if (etiquette as Label).text == "CHIFFRES CLÉS":
			(etiquette as Label).text = "ÉVÉNEMENTS DU MATCH"
			break
	legende_chiffres.visible = false
	chiffres.visible = false
	evenements = S.G.v(px(6))
	evenements.name = "MatchBetweenEvents"
	S.G.fill(evenements)
	chiffres.get_parent().add_child(evenements)
	chiffres.get_parent().move_child(evenements, chiffres.get_index() + 1)
	# L'enjeu au classement, en carte, sous les événements (rempli par le classement en direct).
	# L'enjeu et le bonus : chacun sa tuile (panneau de la charte) sous celle des événements.
	enjeu_pastille = PanelContainer.new()
	enjeu_pastille.name = "MatchBetweenLiveStake"
	var style_enjeu := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style_enjeu.set_content_margin_all(px(16))
	enjeu_pastille.add_theme_stylebox_override("panel", style_enjeu)
	enjeu_pastille.visible = false
	enjeu_pastille.mouse_filter = Control.MOUSE_FILTER_PASS
	gauche.add_child(enjeu_pastille)
	bonus_tuile.get_parent().remove_child(bonus_tuile)
	var style_bonus_tuile := liserer(_case(PANNEAU, Charte.RAYON_PANNEAU))
	style_bonus_tuile.set_content_margin_all(px(16))
	bonus_tuile.add_theme_stylebox_override("panel", style_bonus_tuile)
	gauche.add_child(bonus_tuile)
	# Le contenu du panneau ne s'étire plus (sinon le vide revient sous le bonus).
	(chiffres.get_parent() as Control).size_flags_vertical = Control.SIZE_FILL
	panneau_chiffres.size_flags_vertical = Control.SIZE_FILL
	var defile_ev := panneau_chiffres.find_child("MatchBetweenFiguresScroll", true, false) as ScrollContainer
	if defile_ev != null:
		defile_ev.size_flags_vertical = Control.SIZE_FILL
		# Les événements cèdent leur hauteur quand Gabi grandit (bulles) : ils défilent, le banc garde ses 8 lignes
		# (vérificateur du 24/11 : la tuile Banc était écrasée). Hauteur tenue par _tenir_gauche.
		defile_ev.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_defile_ev = defile_ev
	_colonne_gauche = gauche
	_page_fm = page
	if not page.resized.is_connected(_tenir_gauche): page.resized.connect(_tenir_gauche)
	var centre := _boite(false, GOUTTIERE)
	centre.name = "MatchBetweenCentre"
	S.G.fill(centre, true, 1.0)
	grille.add_child(centre)
	var rangee := _boite(true, GOUTTIERE)
	rangee.name = "MatchBetweenPitchRow"
	S.G.fill(rangee, true, 1.0)
	centre.add_child(rangee)
	for cote in 2:
		if cote == 1: _colonne_centre(rangee)
		_poser_compo_fm(rangee, cote)
	_poser_phrase_fm(centre)
	# Les temps forts en pastilles sont déjà dans les événements et la phrase de jeu : la ligne laisse la place.
	temps_forts.visible = false
	var rang_bas := _boite(true, GOUTTIERE)
	rang_bas.name = "MatchBetweenDashboardRow"
	# Le terrain d'abord (vérificateur du 24/11) : la rangée du bas garde sa hauteur utile, le reste va au terrain.
	S.G.fill(rang_bas, true, 0.3)
	centre.add_child(rang_bas)
	_poser_bas_fm(rang_bas)
	# La domination prend la place du momentum, sous le terrain (sigles en légende, frise basse).
	var barre_m := find_child("MatchBetweenMomentumBar", true, false) as Control
	var cadre_t: Control = barre_m.get_parent()
	barre_m.visible = false
	titre_domination = _titre("Domination", "1re mi-temps")
	titre_domination.name = "MatchBetweenMomentumTile"
	cadre_t.add_child(titre_domination)
	domination.legende_etroite = true
	domination.custom_minimum_size.y = px(120)
	cadre_t.add_child(domination)
	S.G.fill(domination, true, 0.45)
	var droite := _boite(false, GOUTTIERE)
	droite.name = "MatchBetweenStandingsColumn"
	droite.custom_minimum_size.x = px(560)
	grille.add_child(droite)
	_poser_journee_v2(droite, droite, 2)
	panneaux_direct[1].size_flags_vertical = Control.SIZE_FILL
	# Barre basse : Mon XV, une carte par joueur ; le tri, le total de l'équipe et le XV adverse dans son en-tête.
	var barre_xv := _boite(true, GOUTTIERE)
	barre_xv.name = "MatchBetweenSquadBar"
	page.add_child(barre_xv)
	_colonne_xv(barre_xv)
	S.G.fill(tuile_principale)
	tuile_principale.custom_minimum_size.x = 0
	var tete := titre_xv.get_parent()
	var entete := tuile_principale.find_child("MatchBetweenSquadHeader", true, false) as Control
	entete.get_parent().remove_child(entete)
	tete.add_child(entete)
	tete.move_child(entete, 1)
	titre_xv.size_flags_horizontal = Control.SIZE_FILL
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(vide)
	tete.add_child(vide)
	tete.move_child(vide, 2)
	pied_xv.get_parent().remove_child(pied_xv)
	tete.add_child(pied_xv)
	tete.move_child(pied_xv, 3)
	pied_xv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Le banc quitte Mon XV pour son cadre, sous les événements.
	var cadre_banc := _panneau(gauche, px(16))
	banc_cadre = cadre_banc.get_parent().get_parent()
	banc_cadre.name = "MatchBetweenBenchTile"
	S.G.fill(banc_cadre, true)
	S.G.fill(cadre_banc, true)
	S.G.fill(zone_banc, true)
	S.G.fill(banc, true)
	zone_banc.get_parent().remove_child(zone_banc)
	# Le banc cède sa hauteur quand la colonne de gauche se remplit (2e mi-temps, bonus en fin de match) : il défile
	# au lieu de pousser la barre de Mon XV hors de l'écran.
	var defile_banc := ScrollContainer.new()
	_defile_banc = defile_banc
	defile_banc.name = "MatchBetweenBenchScroll"
	defile_banc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile_banc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	S.G.fill(defile_banc, true)
	cadre_banc.add_child(defile_banc)
	defile_banc.add_child(zone_banc)
	(zone_banc.get_child(0) as Control).visible = false
	banc.columns = 1
	# Le pied (« ? » des raccourcis, vitesse) rejoint l'en-tête de Mon XV : l'écran garde toute sa hauteur.
	_pied(page)
	page.remove_child(pied)
	tete.add_child(pied)
	pied.size_flags_horizontal = Control.SIZE_SHRINK_END
	pied_reglages.size_flags_horizontal = Control.SIZE_SHRINK_END
	pied_reglages.clip_text = false
	pied_reglages.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func update_frame(model: Dictionary, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	if not is_node_ready(): return
	_dernier = [model, live, direct, appliquer]
	_tenir_gauche.call_deferred()
	var densite := densite_pour(get_viewport_rect().size)
	if not is_equal_approx(densite, _densite):
		_densite = densite
		_construire()
	var equipes: Array = live.get("teams", [])
	_equipes = equipes
	terrain.direct = direct
	terrain.camp = int(direct.get("camp", -1))
	terrain.regler_equipes(equipes)
	# Le terrain rejoue les faits que le joueur peut voir : rien au-delà du journal montré.
	terrain.alimenter(direct.get("deroule", []), mini(live.get("events", []).size(), int(direct.get("borne", live.get("events", []).size()))))
	terrain.queue_redraw()
	_etat(live, direct, equipes)
	_pilotage = Pilotage.pilotage(live)
	var bulles := get_node_or_null(BullesAdjoint.NOM)
	if bulles != null: bulles.rafraichir()
	var banc_fm := get_node_or_null("MatchFmBanc")
	if banc_fm != null: banc_fm.rafraichir()
	_remplir_journee(model, direct, equipes)
	_remplir_bonus(model, live, direct)
	_niveaux = direct.get("niveaux", [])
	var voulu := niveau_regie if not niveau_regie.is_empty() else str(direct.get("niveau", ""))
	if niveau_libelle() != _libelle_niveau(voulu) or grille_niveaux.get_child_count() != _niveaux.size(): _remplir_niveaux(voulu)
	var dom: Dictionary = direct.get("domination", {}) if direct.get("domination") is Dictionary else {}
	domination.minutes = dom.get("minutes", [])
	domination.mi_temps = dom.get("miTemps")
	domination.reperes = direct.get("reperes", [])
	domination.couleurs = terrain.couleurs.duplicate()
	domination.sigles = [S.G.club_abbr(equipes[0]) if equipes.size() > 0 and equipes[0] is Dictionary else "", S.G.club_abbr(equipes[1]) if equipes.size() > 1 and equipes[1] is Dictionary else ""]
	domination.camp = int(direct.get("camp", -1))
	var haut := domination._haut()
	domination.noms = [_nom_club(equipes, haut), _nom_club(equipes, 1 - haut)]
	var scores := {}
	for item: Variant in direct.get("deroule", []):
		if item is Dictionary and item.get("score") is Array: scores[int(item.get("i", -1))] = item.score
	domination.scores = scores
	domination.teintes = _teintes_duel()
	_poser_momentum(dom.get("minutes", []) if dom.get("minutes") is Array else [], equipes, haut)
	_poser_temps_forts(direct.get("reperes", []) if direct.get("reperes") is Array else [], equipes)
	_remplir_evenements(direct.get("reperes", []) if direct.get("reperes") is Array else [], equipes)
	domination.queue_redraw()
	_remplir_cumul_fm(direct)
	if is_instance_valid(titre_domination) and titre_domination.get_child_count() > 1:
		(titre_domination.get_child(1) as Label).text = "1re mi-temps" if dom.get("minutes", []).size() <= 40 else "2e mi-temps"
	_poser_phase(live)
	_poser_legende(equipes, int(direct.get("camp", -1)))
	meteo_ligne.text = Meteo.bandeau(live)
	_poser_meteo(live)
	if is_instance_valid(stats_lien): stats_lien.tooltip_text = "Toutes les statistiques du match." + ("\n" + meteo_ligne.text if not meteo_ligne.text.is_empty() else "")
	_remplir_banc(live)
	_appliquer_blocage()
	# Conseil de l'adjoint et composition tels qu'ils étaient avant la borne : rien d'un temps fort à venir.
	var passe := _passe(model, live, direct)
	var conseil: Variant = passe.conseil
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []), direct.get("feuille", {}).get("joueurs", {}) if direct.get("feuille") is Dictionary else {},
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs, direct.get("pourquoi"), direct.get("hommeDuMatch"), direct.get("zone22"), direct.get("echantillon"), _pilotage.get("joueurs"),
		MenuJoueur.arrets(live).get("file"), live.get("numeros")])
	_suivre_choix(live)
	_montrer_changement(live, direct, passe.lineup)
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	# Acteur de chaque fait du fil quand c'est un de nos joueurs (titulaire ou banc) : son nom y mène.
	_acteurs = {}
	var nos_ids := {}
	for j: Variant in (live.get("lineup", []) if live.get("lineup") is Array else []) + (live.get("reserves", []) if live.get("reserves") is Array else []):
		if j is Dictionary: nos_ids[str(j.get("id", ""))] = true
	var evenements: Array = live.get("events", []) if live.get("events") is Array else []
	for entree: Variant in _lignes:
		var i := int(entree.get("i", -1)) if entree is Dictionary else -1
		if i < 0 or i >= evenements.size() or not evenements[i] is Dictionary or not evenements[i].get("scene") is Dictionary: continue
		var acteur: Variant = evenements[i].scene.get("actor")
		if acteur != null and nos_ids.has(str(acteur)): _acteurs[i] = str(acteur)
	_fin = {"fini": live.get("finished", false), "score": live.get("score", []), "camp": int(direct.get("camp", -1)),
		"finale": str(model.get("next", {}).get("phase", "") if model.get("next") is Dictionary else "") == "final", "essais": live.get("tries", []),
		"bonus": direct.get("bonus") if direct.get("bonus") is Dictionary else null}
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_compos_fm(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)
	if bulles != null: bulles.apres_adjoint()
	_appliquer_blocage()

# --- Clavier de l'entracte -------------------------------------------------------

## Espace : reprendre ou mettre en pause ; T : Équipe ; Échap : referme la fiche ou le panneau ouvert à droite,
## sinon laisse la vue du match ouvrir son menu de pause (exception de Léo ; jamais de sortie) ; Entrée : l'action de Gabi ou du panneau d'arrêt. ↑ ↓ et
## Entrée parcourent Mon XV (focus des lignes). Muet quand une fenêtre de la vue (Équipe) couvre l'entracte.
func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree() or couvert.call(): return
	if touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	if is_instance_valid(fiche_match):
		if touche.keycode == KEY_ESCAPE:
			fermer_fiche()
			get_viewport().set_input_as_handled()
		return
	var live: Dictionary = _dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {}
	var arrete: bool = bool(live.get("paused", false)) or bool(live.get("atBreak", false))
	match touche.keycode:
		KEY_SPACE:
			if bool(live.get("finished", false)): return
			if arrete: reprise_demandee.emit()
			else: pause_demandee.emit()
		KEY_T:
			if is_instance_valid(equipe) and not equipe.disabled: tiroir_demande.emit("Équipe")
		KEY_I:
			# Ligne de Mon XV ou du banc choisie au clavier : I montre ou cache la mini-fiche du joueur.
			var ligne := get_viewport().gui_get_focus_owner()
			if ligne == null or not is_ancestor_of(ligne) or not ligne.has_meta("player_id"): return
			var noms_ligne := ligne.find_children("MatchBetweenPlayerName_*", "Button", true, false)
			var app_i: Object = _app()
			if noms_ligne.is_empty() or not app_i is Control: return
			var ancre: Control = noms_ligne[0]
			if MiniFiche.visible_pour(app_i, ancre): MiniFiche.cacher(app_i, ancre)
			else: MiniFiche.montrer(app_i, str(ligne.get_meta("player_id")), "squad", ancre)
		KEY_ESCAPE:
			# Sans panneau ouvert, Échap revient à la vue du match : son menu (pause et réglages, exception de Léo).
			if vue_droite == "chiffres": return
			montrer_droite("chiffres")
		KEY_ENTER, KEY_KP_ENTER:
			var focus := get_viewport().gui_get_focus_owner()
			if focus is BaseButton and is_ancestor_of(focus): return
			if not _arret.is_empty() and is_instance_valid(arret_reprendre) and not arret_reprendre.disabled: arret_reprendre.pressed.emit()
			else:
				var action := find_child("MatchBetweenReplace", true, false) as Button
				if action != null and not action.disabled: action.pressed.emit()
				else: return
		_: return
	get_viewport().set_input_as_handled()
