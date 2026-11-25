extends "res://ui/contextual/live_view_outils.gd"
## Écran 13 « Match en direct » (live_view.gd), morceau : plaques des clubs, écussons, score montré, chiffres du match.

## Couleur de chaque club sur son écusson seulement (puce du sigle, rayon 6, assombrie pour la crème ; jamais
## l'or) ; la plaque reste sur le panneau du bandeau (charte finale §4.3 : couleurs de club sur écusson, maillot, liseré).
func _poser_plaques(teams: Array) -> void:
	var cle := JSON.stringify(teams.map(func(t: Variant): return [S.G.club_name(t), S.G.identity(t).get("color", "")] if t is Dictionary else []))
	if cle == _plaques_cle or plaques.size() < 2: return
	_plaques_cle = cle
	for cote in 2:
		var couleur := Charte.CLUB
		if teams.size() > cote and teams[cote] is Dictionary:
			couleur = Color.from_string(str(S.G.identity(teams[cote]).get("color", "")), Charte.CLUB)
		var ecusson := fond_plaque(couleur)
		plaques[cote].set_meta("ecusson", ecusson)
		var puce: PanelContainer = plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
		var style := StyleBoxFlat.new()
		style.bg_color = ecusson
		# Club trop sombre pour se détacher du panneau : contour crème 12 % (FILET).
		style.border_color = Charte.FILET if Charte.contraste(ecusson, Charte.PANNEAU) < 1.5 else Color(0, 0, 0, 0)
		style.set_border_width_all(1 if style.border_color.a > 0 else 0)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		style.anti_aliasing = true
		style.content_margin_left = roundf(7 * echelle)
		style.content_margin_right = roundf(7 * echelle)
		style.content_margin_top = roundf(2 * echelle)
		style.content_margin_bottom = roundf(2 * echelle)
		puce.add_theme_stylebox_override("panel", style)
		_poser_ecusson(cote, teams)
		# Noms très longs : 300 px au plus (1920 × 1080) par plaque, environ 150 px en 1280 × 720 (les commandes
		# tiennent sur la même rangée) ; au-delà, le nom court (sans ses derniers mots), sinon le sigle. Jamais « … ».
		var nom: Label = home if cote == 0 else away
		var complet := S.G.club_name(teams[cote]) if teams.size() > cote and teams[cote] is Dictionary else ""
		var police: Font = nom.get_theme_font("font")
		var taille := nom.get_theme_font_size("font_size")
		var plafond := clampf((get_viewport_rect().size.x / echelle - 1000.0) * 0.55, 140.0, 300.0) * echelle
		nom.text = nom_court(complet, _sigles[cote].text, police, taille, plafond)
		nom.custom_minimum_size.x = police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 2.0
		plaques[cote].tooltip_text = complet
	_coque_score.queue_redraw()

## Choix de Léo (21/11/2026) : le logo du club À LA PLACE de la pastille du sigle (même emplacement, 44 px en 1080p),
## jamais les deux : le vrai logo quand un pack d'identité en fournit un (logoPath de la présentation), sinon l'écusson
## dessiné aux couleurs et initiales du club (celui du stade). La pastille reste cachée, stylée (couleur de l'écusson).
## Le logo laisse passer la souris : un clic dessus ouvre la fiche du club comme la plaque.
func _poser_ecusson(cote: int, teams: Array) -> void:
	var puce: Control = plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
	var rangee: Container = puce.get_parent()
	var ancien := rangee.get_node_or_null("MatchClubCrest%d" % cote)
	if ancien != null:
		rangee.remove_child(ancien)
		ancien.queue_free()
	puce.visible = true
	if teams.size() <= cote or not (teams[cote] is Dictionary): return
	var ecusson := ecusson_club(_club_complet(teams[cote]), roundi(44 * echelle * BARRE_HAUT))
	ecusson.name = "MatchClubCrest%d" % cote
	ecusson.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecusson.tooltip_text = ""
	for enfant in ecusson.find_children("*", "Control", true, false): (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(ecusson)
	rangee.move_child(ecusson, puce.get_index())
	puce.visible = false

## Logo du club (`logoPath` d'un pack d'identité), sinon l'écusson dessiné aux couleurs et initiales du club, dans une
## case de `largeur` px : plaques du bandeau et petite fenêtre du club.
func ecusson_club(club: Dictionary, largeur: int) -> Control:
	var ecusson: Control
	var logo: Texture2D = S.G.Base._pack_texture(str(S.G.identity(club).get("logoPath", club.get("logoPath", ""))))
	if logo != null:
		var image := TextureRect.new()
		image.texture = logo
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2.ONE * largeur
		image.set_meta("logo_pack", true)
		ecusson = image
	else:
		# L'image de l'écusson dessiné a une marge transparente (forme ≈ 65 % du cadre) : dessinée à 150 % dans une case
		# de 44 px, la forme fait ≈ 44 px (taille choisie sur la planche) sans grandir le bandeau ni serrer les noms.
		var dessin_taille := roundi(largeur * 1.5)
		var dessin: Control = load("res://ui/tenue_club.gd").ecusson(club, dessin_taille)
		if dessin == null: dessin = S.G.crest(club, dessin_taille)
		dessin.custom_minimum_size = Vector2.ONE * dessin_taille
		dessin.size = Vector2.ONE * dessin_taille
		dessin.position = Vector2.ONE * float(largeur - dessin_taille) / 2.0
		ecusson = Control.new()
		ecusson.custom_minimum_size = Vector2.ONE * largeur
		ecusson.add_child(dessin)
		# Initiales jamais masquées (l'écusson les cache sous 11 px) et toujours lues : ivoire, contour sombre.
		for initiales in dessin.find_children("*", "Label", true, false):
			var etiquette := initiales as Label
			etiquette.add_theme_font_size_override("font_size", maxi(11, roundi(dessin_taille * 0.22)))
			etiquette.add_theme_color_override("font_color", Charte.IVOIRE)
			etiquette.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.07, 0.95))
			etiquette.add_theme_constant_override("outline_size", maxi(3, roundi(dessin_taille * 0.07)))
	return ecusson

## Club du direct complété par sa fiche du classement ou du catalogue (identité, dont le logo du pack).
func _club_complet(equipe: Dictionary) -> Dictionary:
	if S.G.identity(equipe).has("logoPath") or equipe.has("logoPath"): return equipe
	var modele: Dictionary = app.model if app.model is Dictionary else {}
	for liste: Variant in [modele.get("league", []), modele.get("meta", {}).get("catalogue", []) if modele.get("meta") is Dictionary else []]:
		if not liste is Array: continue
		for club: Variant in liste:
			if club is Dictionary and str(club.get("id", "")) == str(equipe.get("id", "?")):
				var complet: Dictionary = club.duplicate()
				complet.merge(equipe, true)
				if club.get("presentation") is Dictionary and not equipe.get("presentation") is Dictionary: complet.presentation = club.presentation
				return complet
	return equipe

static func fond_plaque(couleur: Color) -> Color:
	var fond := Charte.CLUB if Charte._proche_de_l_or(couleur) or couleur.a <= 0.0 else Color(couleur, 1.0)
	var pas := 0
	while Charte.contraste(Charte.IVOIRE, fond) < CONTRASTE_PLAQUE and pas < 60:
		fond = fond.darkened(0.05)
		pas += 1
	return fond

## Nom affiché sur une plaque : le nom complet en capitales s'il tient dans `largeur`, sinon le nom sans ses
## derniers mots (« MEADOWBRIDGE »), sinon le sigle.
static func nom_court(nom: String, sigle: String, police: Font, taille: int, largeur: float) -> String:
	var mots := nom.to_upper().split(" ", false)
	while not mots.is_empty():
		var essai := " ".join(mots)
		if police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return essai
		mots.remove_at(mots.size() - 1)
	return sigle.to_upper()

# --- Journal ------------------------------------------------------------------

## Score montré par le bandeau (pas celui du moteur, en avance pendant les temps forts) : [recevant, visiteur].
func score_affiche() -> Array[int]:
	var morceaux := score.text.replace("–", "—").split("—")
	if morceaux.size() == 2 and morceaux[0].strip_edges().is_valid_int() and morceaux[1].strip_edges().is_valid_int():
		return [int(morceaux[0].strip_edges()), int(morceaux[1].strip_edges())]
	var marque: Variant = _live().get("score", [0, 0])
	return [int(marque[0]), int(marque[1])] if marque is Array and marque.size() >= 2 else [0, 0]

## Essais du club `cote` déjà montrés : repères du direct dont le score d'après ne dépasse pas celui du bandeau (le
## temps fort en cours n'est pas annoncé), sinon le compte du moteur.
func _essais_montres(cote: int) -> int:
	var live := _live()
	var direct: Variant = live.get("direct")
	if direct is Dictionary and direct.get("reperes") is Array:
		var montre := score_affiche()
		return (direct.reperes as Array).filter(func(r: Variant) -> bool:
			if not (r is Dictionary and str(r.get("kind", "")) == "try" and int(r.get("equipe", -1)) == cote): return false
			var apres: Variant = r.get("score")
			return not (apres is Array and apres.size() > cote and int(apres[cote]) > montre[cote])).size()
	var essais: Variant = live.get("tries")
	return int(essais[cote]) if essais is Array and essais.size() > cote else 0

## Chiffre d'une ligne des statistiques du match (« Possession ») pour le club `cote` ; « — » sans donnée.
func _chiffre_match(libelle: String, cote: int) -> String:
	# Mêmes chiffres que le tiroir Statistiques du direct.
	for ligne: Variant in _stats(_live()):
		if ligne is Dictionary and str(ligne.get("label", "")) == libelle:
			var valeur: Variant = ligne.get("home" if cote == 0 else "away", "—")
			# Compte du moteur (JSON : nombre à virgule) écrit en entier.
			return str(roundi(float(valeur))) if valeur is float or valeur is int else str(valeur)
	return "—"

## Ligne du classement d'un club (rang, points, forme) ; vide s'il n'y figure pas.
func _ligne_classement(id: int) -> Dictionary:
	var classement: Variant = app.model.get("league", [])
	if not classement is Array: return {}
	for ligne: Variant in classement:
		if ligne is Dictionary and ligne.get("id") != null and int(float(ligne.id)) == id: return ligne
	return {}

## Couleur d'un club (identité), sinon vert pour nous / ivoire pour l'adversaire.
func _couleur_club(club: Dictionary, k: int) -> Color:
	var c := str(S.G.identity(club).get("color", club.get("color", "")))
	return Color(c) if c.begins_with("#") else (Charte.GAIN if k == 0 else Charte.IVOIRE_2)

## Le journal du moteur nomme les clubs par leur sigle interne (« FDG ») ; l'écran affiche le
## sigle de leur identité (presentation.abbr). Même règle que match-direct.cjs (renommeur).
static func sigles_affiches(texte: String, equipes: Array) -> String:
	for equipe_: Variant in equipes:
		if not equipe_ is Dictionary: continue
		var interne := str(equipe_.get("abbr", ""))
		var identite: Variant = equipe_.get("presentation")
		var affiche := str(identite.get("abbr", "")) if identite is Dictionary else ""
		if not RegEx.create_from_string("^[A-Z0-9]{2,5}$").search(interne) or affiche.is_empty() or affiche == interne: continue
		var motif := RegEx.create_from_string("\\b" + interne + "\\b")
		if motif != null: texte = motif.sub(texte, affiche, true)
	return texte
