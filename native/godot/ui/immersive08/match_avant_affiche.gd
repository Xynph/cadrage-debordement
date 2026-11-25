extends "res://ui/immersive08/match_avant_bandeau.gd"
## Écran « Avant-match » (voir match_avant.gd) — Affiche : fond photo du tunnel, plaques inclinées des deux clubs, centre (heure, lieu, météo), classements, pied de page.

## Illustration plein cadre (tunnel ou pelouse selon l'heure et la météo) recolorée aux couleurs du club, sous un voile
## qui garantit le contraste du texte (C5).
func _fond(parent: Control, model: Dictionary, next: Dictionary) -> void:
	var id := photo_meteo(next) if not next.is_empty() else PHOTO_ORIGINE
	var photo := C.photo(id, Vector2.ZERO, true, .3)
	photo.name = "MatchPosterPhoto"
	photo.set_meta("photo_meteo", id)
	var identite: Dictionary = G.identity(model.get("club", {}))
	BanqueImages.recolorer(photo, id, RI.primary(identite), RI.secondary(identite))
	photo.tooltip_text = ""
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Charte.NUIT, .72))
	gradient.set_color(1, Color(Charte.NUIT, .94))
	gradient.add_point(.22, Color(Charte.NUIT, .34))
	gradient.add_point(.58, Color(Charte.NUIT, .22))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = gradient
	veil_texture.fill_from = Vector2.ZERO
	veil_texture.fill_to = Vector2.DOWN
	var veil := TextureRect.new()
	veil.name = "MatchPosterVeil"
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ---- Bandeau haut -----------------------------------------------------------------------------------------------

## Plaque aux couleurs d'un club (angles arrondis, rayon 12) : écusson, nom en 64 px ; clic : fiche du club.
class Plaque extends Button:
	var couleur := Color.WHITE
	var anneau := false
	var droite := false
	func _ready() -> void:
		resized.connect(queue_redraw)
	## Tuile arrondie (charte : rayon 12 des tuiles et cartes) ; le contour du camp « anneau » et le focus suivent la forme.
	func _forme(fond: Color, contour: Color = Color.TRANSPARENT, epaisseur: int = 0) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = fond
		style.border_color = contour
		style.set_border_width_all(epaisseur)
		style.set_corner_radius_all(Charte.RAYON_CARTE)
		style.anti_aliasing = true
		return Charte.ombrer(style)
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if anneau: draw_style_box(_forme(Color(Charte.NUIT, .55), Charte.IVOIRE, 3), rect)
		else: draw_style_box(_forme(couleur), rect)
		if is_hovered() or has_focus(): draw_style_box(_forme(Color.TRANSPARENT, Charte.IVOIRE, 3 if has_focus() else 2), rect)

func _distance(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))

func _plaque(club: Dictionary, droite: bool, anneau: bool, ma_couleur: Color) -> Button:
	var plaque := Plaque.new()
	plaque.name = "MatchPosterHome" if not droite else "MatchPosterAway"
	plaque.flat = true
	plaque.set_meta("immersive_style_applied", true)
	plaque.couleur = ma_couleur
	plaque.anneau = anneau
	plaque.droite = droite
	for look in ["normal", "hover", "pressed", "disabled"]: plaque.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	plaque.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	plaque.custom_minimum_size = Vector2(M(640), M(100))
	plaque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plaque.tooltip_text = "Fiche du club : %s" % G.club_name(club)
	plaque.accessibility_name = "Fiche du club %s" % G.club_name(club)
	plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plaque.pressed.connect(func(): _ouvrir_club(club))
	var encre := Charte.IVOIRE if anneau or Charte.contraste(Charte.IVOIRE, ma_couleur) >= 3.0 else Charte.NUIT
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(22))
	ligne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ligne.offset_left = M(26)
	ligne.offset_right = -M(26)
	ligne.alignment = BoxContainer.ALIGNMENT_BEGIN if not droite else BoxContainer.ALIGNMENT_END
	plaque.add_child(ligne)
	var crest := G.crest(club, M(70))
	crest.custom_minimum_size = Vector2(M(70), M(78))
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Mini-carte verticale à grand écusson au survol (choix de Léo, 21/11/2026) ; le clic garde la fiche du club.
	CarteClub.lier(crest, club, true)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nom := texte(G.club_name(club).to_upper(), 64, encre, true, 800)
	italique(nom, true)
	nom.name = "MatchPosterName"
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_OFF
	nom.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_ajuster_nom(nom, M(640) - M(26) * 2 - M(70) - M(22) - M(24))
	if not droite:
		ligne.add_child(crest)
		ligne.add_child(nom)
	else:
		ligne.add_child(nom)
		ligne.add_child(crest)
	return plaque

## Réduit la taille du nom (jamais tronqué) jusqu'à ce qu'il tienne dans la plaque ; plancher 30 px.
func _ajuster_nom(nom: Label, largeur: int) -> void:
	var police: Font = nom.get_theme_font("font")
	var taille := nom.get_theme_font_size("font_size")
	var plancher := maxi(12, M(30))
	while taille > plancher and police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur: taille -= 1
	nom.add_theme_font_size_override("font_size", taille)
	nom.custom_minimum_size.x = minf(float(largeur), police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 2.0)

func _affiche(model: Dictionary, next: Dictionary, data: Dictionary, nous: int) -> Control:
	var zone := MarginContainer.new()
	zone.name = "MatchAffiche"
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, M(32))
	zone.add_theme_constant_override("margin_top", M(34 if C.density >= .6 else 14))
	var pile := VBoxContainer.new()
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pile.add_theme_constant_override("separation", M(10 if C.density >= .6 else 6))
	zone.add_child(pile)
	var venue := Present.fixture_venue(next, false)
	var haut := texte("  ·  ".join([str(next.get("label", "")), venue].filter(func(x: String): return not x.is_empty())).to_upper(), 14, Charte.IVOIRE, true, 700)
	haut.name = "MatchFixtureVenue"
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	haut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	haut.clip_text = true
	pile.add_child(haut)
	var clubs := [next.get("home", {}), next.get("away", {})]
	var couleurs: Array[Color] = []
	for club: Dictionary in clubs: couleurs.append(RI.primary(G.identity(club)))
	var eux := 1 - nous
	var proches := _distance(couleurs[nous], couleurs[eux]) < CLUBS_PROCHES
	var forme: Array = data.get("forme", [[], []])
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_theme_constant_override("separation", 0)
	pile.add_child(rangee)
	var colonnes: Array[VBoxContainer] = []
	var plaques: Array[Button] = []
	for side in 2:
		var colonne := VBoxContainer.new()
		colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		colonne.add_theme_constant_override("separation", M(6))
		colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		colonne.size_flags_stretch_ratio = 1.0
		colonnes.append(colonne)
		var lieu := "TERRAIN NEUTRE" if next.get("neutral", false) else ("DOMICILE" if side == 0 else "EXTÉRIEUR")
		var etiquette := texte(("TON ÉQUIPE · " + lieu.capitalize()) if side == nous else lieu.capitalize(), 13, Charte.IVOIRE if side == nous else Charte.IVOIRE_2, false, 600)
		etiquette.name = "MatchPosterSide%d" % side
		etiquette.add_theme_font_override("font", C.BODY)
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		colonne.add_child(etiquette)
		var anneau: bool = proches and side == eux
		var plaque := _plaque(clubs[side], side == 1, anneau, couleurs[side])
		plaques.append(plaque)
		colonne.add_child(plaque)
		var detail_forme: Array = data.get("formeMatchs", [[], []])
		colonne.add_child(_classement(clubs[side], side, forme[side] if forme.size() > side and forme[side] is Array else [], detail_forme[side] if detail_forme.size() > side and detail_forme[side] is Array else []))
	rangee.add_child(colonnes[0])
	rangee.add_child(_centre(next, data, nous))
	rangee.add_child(colonnes[1])
	return zone

func _centre(next: Dictionary, data: Dictionary, nous: int) -> Control:
	var colonne := VBoxContainer.new()
	colonne.name = "MatchPosterKickoff"
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.custom_minimum_size.x = M(300)
	colonne.add_theme_constant_override("separation", M(4))
	var heure := texte(str(next.get("kickoffLocal", "")) if next.get("kickoffLocal") is String else "—", 64, Charte.IVOIRE, true, 800)
	italique(heure, true)
	heure.name = "MatchPosterTime"
	heure.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(heure)
	var jour := texte("coup d'envoi · " + date_courte(str(next.get("date", ""))), 14, Charte.IVOIRE, false, 500)
	jour.add_theme_font_override("font", C.BODY)
	jour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(jour)
	# Confrontations : clic = la fiche du club adverse (son historique).
	var bilan: Dictionary = data.get("confrontations", {})
	var joues := int(bilan.get("joues", 0))
	var legende := "Première confrontation" if joues == 0 else "Confrontations : %s" % bilan_court(bilan, true)
	if data.is_empty(): legende = "Avant-match"
	var adverse: Dictionary = next.get("away", {}) if nous == 0 else next.get("home", {})
	var lien := _bouton_lien(legende, func(): _ouvrir_club(adverse), "MatchPosterHeadToHead", 14)
	lien.tooltip_text = "Fiche du club adverse : %s" % G.club_name(adverse)
	lien.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lien.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(lien)
	if next.get("meteo") is Dictionary:
		var meteo := _ligne_meteo(next, nous)
		colonne.add_child(meteo)
	return colonne

## Ciel et vent en une ligne (icône + mot) ; clic : le plan de jeu, pour l'adapter aux conditions.
func _ligne_meteo(next: Dictionary, nous: int) -> Control:
	var annonce := MeteoTexte.annonce(next)
	var meteo: Dictionary = next.meteo
	var bouton := Button.new()
	bouton.name = "MatchFixtureWeather"
	bouton.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(bouton, roundi(14 / .75))
	bouton.add_theme_font_override("font", C.BODY)
	_icone_dans_lien(bouton, icone_meteo(meteo, Charte.IVOIRE), 18)
	bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ciel := MeteoTexte.libelle(annonce)
	var vent: String = ["", "Vent", "Grand vent"][clampi(int(meteo.get("vent", 0)), 0, 2)]
	var mots: Array[String] = [ciel]
	if not vent.is_empty() and ciel.to_lower().find("vent") < 0: mots.append(vent.to_lower())
	bouton.text = " · ".join(mots)
	bouton.tooltip_text = "Adapter le plan de jeu aux conditions"
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bouton.pressed.connect(func(): _aller("Plan de jeu"))
	bouton.set_meta("vent", phrase_vent(next, nous))
	var enveloppe := CenterContainer.new()
	enveloppe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enveloppe.add_child(bouton)
	return enveloppe
## Rang, points et forme d'un club : rang cliquable (Classements), pastilles V / N / D à lettre et forme.
func _classement(club: Dictionary, side: int, forme: Array, matchs: Array = []) -> Control:
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(8))
	ligne.alignment = BoxContainer.ALIGNMENT_BEGIN if side == 0 else BoxContainer.ALIGNMENT_END
	ligne.name = "MatchPosterRank%d" % side
	var ouvert := Present.standings_open(club)
	var rang := "%s · %s pts" % [Present.rank_ordinal(club), G.n(club.get("points", 0))] if ouvert else "Classement ouvert après la 1re journée"
	var lien := _bouton_lien(rang, func(): _aller("Classements"), "MatchPosterStanding%d" % side, 14)
	lien.tooltip_text = "Ouvrir le classement"
	ligne.add_child(lien)
	var pastilles := HBoxContainer.new()
	pastilles.name = "MatchPosterForm"
	pastilles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastilles.add_theme_constant_override("separation", M(5))
	for index in forme.size():
		var resultat: Variant = forme[index]
		var p := pastille(str(resultat), 24)
		var rencontre: Dictionary = matchs[index] if index < matchs.size() and matchs[index] is Dictionary else {}
		p.pressed.connect(_ouvrir_match.bind(club, rencontre))
		var quand := " du " + date_courte(str(rencontre.get("date"))) if rencontre.get("date") is String else ""
		p.tooltip_text = "%s : le match%s (les 5 derniers, du plus ancien au plus récent)" % [{"V": "Victoire", "N": "Nul", "D": "Défaite"}.get(str(resultat), "Résultat"), quand]
		p.accessibility_name = p.tooltip_text
		pastilles.add_child(p)
	ligne.add_child(pastilles)
	return ligne

## Pastille de forme : le calendrier à la date du match qu'elle représente, sinon la fiche du club.
func _ouvrir_match(club: Dictionary, rencontre: Dictionary) -> void:
	var nav: Node = app.get("navigation_controller")
	# Le résumé d'un match s'ouvre dans une fenêtre de lecture : on préfère le calendrier, à la date du match (un écran).
	var date := str(rencontre.get("date")) if rencontre.get("date") != null else ""
	if is_instance_valid(nav) and not date.is_empty() and nav.open_entity({"kind": "date", "id": date}): return
	_ouvrir_club(club)

## Rappel des touches : Entrée / Espace sur le bouton, Tab, Échap (retour), F1 (aide de Gabi, cliquable).
func _pied(en_page: bool) -> Control:
	var marge := MarginContainer.new()
	marge.name = "MatchFooterHints"
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: marge.add_theme_constant_override("margin_" + edge, M(32))
	marge.add_theme_constant_override("margin_top", M(8))
	marge.add_theme_constant_override("margin_bottom", M(10))
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", M(10))
	marge.add_child(ligne)
	# Raccourcis derrière un « ? » (règle du 21/11) : plus de ligne de mode d'emploi au pied de l'écran.
	var emplacement := Control.new()
	emplacement.custom_minimum_size = Vector2(M(30), M(30))
	emplacement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aide := "Raccourcis\nEntrée ou Espace : le bouton en focus\nTab : élément suivant\nÉchap : " + ("retour à l'avant-match" if en_page else "menu") + "\nF1 : aide de Gabi"
	var rond := Reperes.rond(emplacement, 0, 20.0, aide, "?", "MatchOpenHelp", 38.0)
	rond.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rond.gui_input.connect(func(evenement: InputEvent) -> void:
		if evenement is InputEventMouseButton and evenement.pressed and evenement.button_index == MOUSE_BUTTON_LEFT: app._open_coach())
	ligne.add_child(emplacement)
	# Ligne d'état de la carrière (sauvegarde, action refusée) : le pied de la coque n'existe pas ici, elle vit dans ce pied.
	var etat := texte(app._status_line_text() if app.has_method("_status_line_text") else "", 13, Charte.IVOIRE_2, false, 500)
	etat.name = "ImmersiveSaveStatus"
	etat.add_theme_font_override("font", C.BODY)
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	C.fill(etat)
	ligne.add_child(etat)
	app.status = etat
	return marge

# ---- Les quatre vérifications -----------------------------------------------------------------------------------
