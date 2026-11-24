extends "res://ui/contextual/apres_match_socle.gd"
## Après-match (apres_match.gd), morceau : mise à l'échelle, textes, boîtes, fonds, panneaux, liens vers les écrans du jeu, écussons, pastilles V/N/D, triangles.
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

func _d(valeur: float) -> int: return roundi(valeur * _e)

func _f(valeur: float) -> int: return maxi(12, roundi(valeur * _e))

func _texte(texte: String, taille: float, couleur: Color = Charte.IVOIRE, police: Font = Charte.TEXTE, retour: bool = false) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", police)
	l.add_theme_font_size_override("font_size", _f(taille))
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if retour: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _h(ecart: float = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", _d(ecart))
	return b

func _v(ecart: float = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", _d(ecart))
	return b

## Fond d'un bloc. `rayon` : 0 pour une ligne de liste transparente (seul un filet la sépare), sinon un rayon de la charte
## (RAYON_PANNEAU, RAYON_CARTE, RAYON_PETIT, RAYON_PILULE).
func _fond(couleur: Color, gauche: float = 0, haut: float = 0, droite: float = -1, bas: float = -1, rayon: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	if rayon > 0:
		s.set_corner_radius_all(rayon if rayon >= Charte.RAYON_PILULE else _d(rayon))
		s.anti_aliasing = true
	s.content_margin_left = _d(gauche)
	s.content_margin_top = _d(haut)
	s.content_margin_right = _d(gauche if droite < 0 else droite)
	s.content_margin_bottom = _d(haut if bas < 0 else bas)
	return Charte.ombrer(s, rayon)

## Panneau de la charte (rayon 18, sans bordure) ; carte dans un panneau : `rayon` = RAYON_CARTE.
func _panneau(couleur: Color = Charte.PANNEAU, gauche: float = 16, haut: float = 10, rayon: int = Charte.RAYON_PANNEAU) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _fond(couleur, gauche, haut, -1, -1, rayon))
	return p

## Lien de la charte (texte ivoire, souligné au survol) qui ouvre `cible` (navigation_controller.open_entity).
func _lien(texte: String, cible: Dictionary, taille: float = 13, souligne := false) -> Button:
	var b := Button.new()
	b.text = texte
	C.style_bouton_lien(b, 17, souligne)
	b.add_theme_font_override("font", Charte.TEXTE)
	b.add_theme_font_size_override("font_size", _f(taille))
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := b.get_theme_stylebox(look).duplicate() as StyleBoxFlat
		s.content_margin_left = 0
		s.content_margin_right = 0
		s.content_margin_top = _d(2)
		s.content_margin_bottom = _d(2)
		b.add_theme_stylebox_override(look, s)
	b.set_meta("cible", cible)
	b.focus_mode = Control.FOCUS_ALL
	# Jamais de clic silencieux : une destination indisponible donne un lien grisé et sa raison écrite (infobulle).
	var raison := indisponible(cible)
	b.set_meta("contextual_enabled", raison.is_empty())
	if not raison.is_empty():
		b.disabled = true
		b.set_meta("indisponible", raison)
		b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	b.pressed.connect(func(): ouvrir(cible))
	return b

## Raison écrite quand `cible` ne peut pas s'ouvrir (navigation_controller.entity_available), "" sinon.
func indisponible(cible: Dictionary) -> String:
	var kind := str(cible.get("kind", ""))
	if kind in ["", "detail"]: return ""
	var navigation: Variant = app.get("navigation_controller") if app != null else null
	if navigation == null or not is_instance_valid(navigation) or not navigation.has_method("entity_available"): return ""
	if navigation.entity_available(cible): return ""
	return {"club": "Fiche du club indisponible dans cette carrière.", "player": "Fiche du joueur indisponible.",
		"date": "Calendrier indisponible pour ce jour.", "competition": "Classements indisponibles pour cette compétition.",
		"training": "Entraînement indisponible pour le moment.", "menu": "Écran indisponible pour le moment."}.get(kind, "Indisponible pour le moment.")

## Infobulle d'un lien : la raison d'indisponibilité passe toujours en tête.
func _aide(b: Control, texte: String) -> void:
	var raison := str(b.get_meta("indisponible", ""))
	b.tooltip_text = (raison + ("\n" + texte if not texte.is_empty() else "")) if not raison.is_empty() else texte

## Clic sur un lien : l'écran visé s'ouvre (le résultat reste à valider ; Espace ou « Continuer » ramène ici).
func ouvrir(cible: Dictionary) -> void:
	if str(cible.get("kind", "")) == "detail":
		detail = bool(cible.get("ouvert", true))
		_cle = ""
		_reconstruire()
		return
	if director != null and director.has_method("consulter"): director.consulter(cible)

## Écusson du club : vignette droite à coins de 6 px, à sa couleur sombre, liseré à sa couleur lisible (la couleur d'un
## club ne vit que sur son écusson, son maillot et son liseré).
func _sigle(club: Dictionary, largeur: float, hauteur: float, taille: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.custom_minimum_size = Vector2(_d(largeur), _d(hauteur))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var couleur := _couleur(club)
	var t := Trace.new("pave", C.readable_primary_fill(couleur) if couleur.a > 0 else Charte.PANNEAU_3, _d(Charte.RAYON_PETIT))
	t.name = "Ecusson"
	t.bord = Charte.club_trait(couleur) if couleur.a > 0 else Charte.IVOIRE_3
	t.epaisseur = maxf(1.0, _d(2))
	p.add_child(t)
	var l := _texte(G.club_abbr(club) if not club.is_empty() else "", taille, Charte.IVOIRE, Charte.TITRE_EXTRA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## Pastille V / N / D en pilule (charte §4.5) : la lettre toujours écrite, et la forme dit le résultat sans la couleur :
## V pleine vert clair (lettre PANNEAU), N demi-pleine gris-vert (lettre crème), D contour doré (lettre crème : un seul aplat doré par écran, comme #1068).
static func style_pastille(lettre: String) -> Dictionary:
	match lettre:
		"V": return {"fond": Charte.V, "bord": Color(0, 0, 0, 0), "lettre": Charte.PANNEAU}
		"D": return {"fond": Color(0, 0, 0, 0), "bord": Charte.D, "lettre": Charte.IVOIRE}
	return {"fond": Color(Charte.N, 0.35), "bord": Charte.N, "lettre": Charte.IVOIRE}

func _pastille(lettre: String, largeur: float, hauteur: float, taille: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "ApresMatchPastille" + lettre
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Jamais plus petit que 20 × 14 px réels : la lettre (12 px au moins) reste entière.
	p.custom_minimum_size = Vector2(maxi(_d(largeur), 20), maxi(_d(hauteur), 14))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sens := style_pastille(lettre)
	var forme := Trace.new("pave", sens.fond)
	forme.name = "FondPastille"
	forme.bord = sens.bord
	forme.epaisseur = maxf(1.0, _d(2) if hauteur >= 30 else 1.0)
	p.add_child(forme)
	var l := _texte(lettre, taille, sens.lettre, Charte.TITRE_EXTRA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _triangle(haut: bool, couleur: Color, cote: float = 10) -> Control:
	var t := Trace.new("haut" if haut else "bas", couleur)
	t.custom_minimum_size = Vector2(_d(cote), _d(cote * 0.8))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t
