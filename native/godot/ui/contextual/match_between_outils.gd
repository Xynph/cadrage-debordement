extends "res://ui/contextual/match_between_etat.gd"
## Outils de mise en page et de texte de l'écran intermédiaire du match (échelle, cases, boutons, étiquettes).

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

## Boîte horizontale ou verticale dont l'écart est appliqué tel quel (S.G.h / S.G.v le plafonnent à 8 px).
func _boite(horizontale: bool, ecart: int) -> BoxContainer:
	var boite: BoxContainer = HBoxContainer.new() if horizontale else VBoxContainer.new()
	boite.add_theme_constant_override("separation", px(ecart))
	return boite

func fpx(valeur: float) -> int:
	return maxi(12, px(valeur - (2.0 if valeur >= 20.0 else 1.0)))

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, fpx(taille), couleur) if retour else S.label(texte, fpx(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", fpx(taille))
	if titre: etiquette.add_theme_font_override("font", TITRES)
	return etiquette

## Titre de bloc de la charte : capitales Barlow Condensed ExtraBold, droites, crème.
func _titre_bloc(texte: String, taille: float = 24) -> Label:
	var etiquette := _texte(texte.to_upper(), taille, IVOIRE, false, true)
	etiquette.add_theme_font_override("font", Charte.TITRE_FICHE)
	return etiquette

## Bouton de l'écran : l'action principale en pilule dorée (un seul aplat doré par écran), les autres en lien
## de la charte (texte crème, souligné au survol).
func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	_habiller(bouton, principal)
	return bouton

func _habiller(bouton: Control, principal: bool = false) -> void:
	if principal:
		# Pilule dorée ; éteint : pilule à contour `FILET` (bouton secondaire de la charte), sans aplat doré.
		C.style_bouton_ivoire_plein(bouton as BaseButton)
		bouton.add_theme_font_size_override("font_size", fpx(22))
		bouton.custom_minimum_size.y = maxi(26, px(46))
		return
	# Action secondaire : le lien commun de la charte (texte ivoire, flèche, souligné au survol), jamais un cadre.
	C.style_bouton_lien(bouton as BaseButton)
	bouton.add_theme_font_size_override("font_size", fpx(22))
	bouton.custom_minimum_size.y = maxi(26, px(40))

## Choix d'un groupe (segment : vitesse, temps forts, consigne de fin de match) : case rayon 6 sur `PANNEAU_2`,
## le choix courant sur `SELECTION` avec une coche (la couleur ne porte pas seule le choix) ; focus : anneau doré.
func _style_segment(bouton: Button) -> void:
	for etat_bouton in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var choisi: bool = etat_bouton in ["pressed", "hover_pressed"]
		var style := _case(Charte.SELECTION if choisi else (SURVOL if etat_bouton == "hover" else RELIEF))
		if etat_bouton == "focus": _anneau(style)
		style.content_margin_left = px(16)
		style.content_margin_right = px(16)
		style.content_margin_top = px(6)
		style.content_margin_bottom = px(6)
		bouton.add_theme_stylebox_override(etat_bouton, style)
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(couleur, IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", FAIBLE)
	bouton.add_theme_font_override("font", TITRES)
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.add_theme_constant_override("icon_max_width", fpx(18))
	bouton.custom_minimum_size.y = maxi(26, px(44))

## Case de la charte (rayon 6 par défaut), sans bordure.
func _case(fond: Color, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(rayon)
	style.anti_aliasing = true
	return Charte.ombrer(style, rayon)

## Anneau de focus clavier de la charte : doré, 2 px, décalé de 2 px (seul contour complet permis avec le
## bouton secondaire).
func _anneau(style: StyleBoxFlat) -> void:
	style.border_color = Charte.OR
	style.set_border_width_all(2)
	style.set_expand_margin_all(2)

## Coche du choix courant d'un segment (icône de la charte, la couleur ne porte pas seule le choix).
func _cocher(bouton: Button, choisi: bool) -> void:
	bouton.icon = C.icon_texture("check", IVOIRE) if choisi else null
	bouton.set_meta("coche", choisi)

## Lien de la charte : texte ivoire (+ flèche), souligné au survol et au focus, sans cadre.
func _lien(texte: String, action: Callable, nom: String = "") -> Button:
	var bouton := Button.new()
	bouton.text = texte
	if not nom.is_empty(): bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.pressed.connect(action)
	C.style_bouton_lien(bouton)
	bouton.add_theme_font_size_override("font_size", fpx(20))
	bouton.set_meta("contextual_enabled", true)
	return bouton

## Touche de clavier dessinée (« Espace », « Échap », « T ») : petite pilule `PANNEAU_3`, texte gris-vert.
func _touche(texte: String, agrandi: float = 1.0) -> PanelContainer:
	var cadre := PanelContainer.new()
	var style := _case(SURVOL, Charte.RAYON_PILULE)
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(1)
	style.content_margin_bottom = px(1)
	cadre.add_theme_stylebox_override("panel", style)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etiquette := _texte(texte, 17 * agrandi, DOUX, false, true)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(etiquette)
	return cadre

static func liserer(style: StyleBoxFlat) -> StyleBoxFlat:
	style.border_color = LISERE
	style.set_border_width_all(1)
	return style

## Panneau de la charte : opaque, rayon 18, ombre portée de la charte, liseré fin de l'écran 2D.
func _panneau(parent: Node, marge: int, fond: Color = PANNEAU) -> VBoxContainer:
	var coque := PanelContainer.new()
	var style := liserer(_case(Color(fond, 1.0), Charte.RAYON_PANNEAU))
	coque.add_theme_stylebox_override("panel", style)
	parent.add_child(coque)
	var bord := S.G.margin(marge)
	coque.add_child(bord)
	var colonne := S.G.v(px(10))
	bord.add_child(colonne)
	return colonne

## En-tête de bloc : titre en capitales droites, précision atténuée à droite.
func _titre(texte: String, precision: String = "", principal: bool = false) -> Control:
	var ligne := S.G.h(px(10))
	var etiquette := _titre_bloc(texte, 26 if principal else 22)
	S.G.fill(etiquette)
	ligne.add_child(etiquette)
	if not precision.is_empty():
		var droite := _texte(precision, 18, DOUX)
		droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(droite)
	return ligne

func _animations_reduites() -> bool:
	var noeud: Node = get_parent()
	while noeud != null:
		var preferences: Variant = noeud.get("user_preferences")
		if preferences != null and preferences.get("data") is Dictionary: return bool(preferences.data.get("reduced_motion", false))
		noeud = noeud.get_parent()
	return false

## Choix unique (segment) : filet épais et coche quand il est choisi, filet fin sinon.
func _segment(texte: String, groupe: ButtonGroup, choisi: bool) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.toggle_mode = true
	bouton.button_group = groupe
	bouton.button_pressed = choisi
	bouton.custom_minimum_size.x = px(130)
	bouton.set_meta("contextual_enabled", true)
	_style_segment(bouton)
	_cocher(bouton, choisi)
	bouton.toggled.connect(func(actif: bool): _cocher(bouton, actif))
	return bouton

static func poste_court(poste: String) -> String:
	var cle := poste.strip_edges().to_lower()
	if cle.begins_with("numéro"): return "N8" if cle.ends_with("8") else "3L"
	for nom: String in POSTES_COURTS:
		if cle.begins_with(nom): return POSTES_COURTS[nom]
	return poste.substr(0, 3).to_upper()

func _cellule(texte: String, largeur: int, couleur: Color, taille: float = 19, chiffre: bool = false) -> Label:
	var etiquette := _texte(texte, taille, couleur, false, false)
	if chiffre: etiquette.add_theme_font_override("font", CHIFFRES_GRAS)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if largeur > 0:
		etiquette.custom_minimum_size.x = px(largeur)
		etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if chiffre else HORIZONTAL_ALIGNMENT_LEFT
	else: S.G.fill(etiquette)
	return etiquette

static func _rang_texte(rang: int) -> String:
	return "1er" if rang == 1 else "%de" % rang

## Teintes des deux clubs du match lisibles sur un panneau : [nous, eux] ; deux couleurs trop proches : l'adversaire
## passe au gris-vert (la forme pleine / vide distingue toujours les camps).
func _teintes_duel() -> Array[Color]:
	var nous := terrain.camp if terrain != null and terrain.camp in [0, 1] else 0
	var couleurs: Array = [Charte.V, Charte.D]
	if terrain != null and terrain.couleurs.size() == 2: couleurs = [terrain.couleurs[0], terrain.couleurs[1]]
	var a := Charte.club_trait(couleurs[nous])
	var b := Charte.club_trait(couleurs[1 - nous])
	if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.25: b = Charte.IVOIRE_2
	return [a, b]

func _zone_rang(rang: int) -> Dictionary:
	for z: Variant in _zones_journee:
		if z is Dictionary and rang >= int(z.get("from", 0)) and rang <= int(z.get("to", -1)): return z
	return {}

## Direct de la dernière image (`live`), {} avant la première.
func _live_courant() -> Dictionary:
	return _dernier[1] if _dernier.size() > 1 and _dernier[1] is Dictionary else {}

## Vrai numéro de feuille d'un joueur (1 à 23, `live.numeros`) : un remplaçant entré garde le sien (16 à 23).
func _numero(id: String, repli: int) -> int:
	return MenuJoueur.numero_feuille(_live_courant(), id, repli)

## Zone du classement aux couleurs franches des données (la forme du symbole et le mot de la légende la portent aussi).
static func _teinte_zone(kind: String) -> Color:
	match kind:
		"bye": return Charte.GAIN
		"playoff": return Charte.REPOS
		"promotion-playoff": return Charte.MORAL
		"relegation-playoff", "repechage": return Charte.INTENSIF
		"relegation": return Charte.PERTE
	return Charte.IVOIRE_3

## Vrai quand le panneau d'arrêt attend encore le choix du manager (options actives, rien d'envoyé).
func _choix_en_attente() -> bool:
	if _arret.is_empty() or not _choix_fait.is_empty() or not is_instance_valid(arret_options) or not arret_options.visible: return false
	return arret_options.get_children().any(func(b: Node) -> bool: return b is Button and not (b as Button).disabled)

static func _zone(x: float, possession: int) -> String:
	# Vu de l'équipe en possession : distance jusqu'à la ligne d'essai adverse.
	var reste := 100.0 - x if possession == 0 else x
	if reste <= 22.0: return "dans les 22 mètres adverses"
	if reste <= 50.0: return "dans le camp adverse"
	if reste <= 78.0: return "dans son camp"
	return "dans ses 22 mètres"

## Minute du moteur écrite sans décimale (« 42 » et non « 42.0 »).
static func _minute(valeur: Variant) -> String:
	return str(roundi(float(valeur))) if valeur is float or valeur is int else str(valeur)

## Texte d'une ligne jamais coupé : sa taille de police baisse (jusqu'aux deux tiers, plancher de 12 px) pour tenir
## dans sa largeur ; au-delà, il passe à la ligne (deux lignes au plus).
func _ajuster_taille(etiquette: Label) -> void:
	if not is_instance_valid(etiquette) or etiquette.size.x <= 1.0: return
	var base := int(etiquette.get_meta("taille_base", etiquette.get_theme_font_size("font_size")))
	var police: Font = etiquette.get_theme_font("font")
	var taille := base
	var plancher := maxi(12, roundi(base * 0.66))
	while taille > plancher and police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > etiquette.size.x: taille -= 1
	if etiquette.get_theme_font_size("font_size") != taille: etiquette.add_theme_font_size_override("font_size", taille)
	var trop := police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > etiquette.size.x
	var voulu := TextServer.AUTOWRAP_WORD_SMART if trop else TextServer.AUTOWRAP_OFF
	if etiquette.autowrap_mode != voulu:
		etiquette.autowrap_mode = voulu
		etiquette.max_lines_visible = 2 if trop else -1

## Nom d'un club du match (vide s'il manque).
static func _nom_club(equipes: Array, cote: int) -> String:
	return S.G.club_name(equipes[cote]) if cote >= 0 and cote < equipes.size() and equipes[cote] is Dictionary else ""

## Hauteur d'une étiquette pour montrer `lignes` lignes entières (police, interligne et style compris).
static func hauteur_lignes(etiquette: Label, lignes: int) -> float:
	var police: Font = etiquette.get_theme_font("font")
	var taille := etiquette.get_theme_font_size("font_size")
	var interligne := float(etiquette.get_theme_constant("line_spacing"))
	var style: StyleBox = etiquette.get_theme_stylebox("normal")
	var marges := style.get_minimum_size().y if style != null else 0.0
	return ceilf(police.get_height(taille) * lignes + interligne * maxi(0, lignes - 1) + marges + 1.0)

## Échantillon du moteur (`direct.echantillon`) : court tant que le jeu montré n'atteint pas le
## seuil (dix minutes). Sans l'information (ancienne projection), l'échantillon est jugé suffisant.
static func est_court(direct: Dictionary) -> bool:
	var echantillon: Variant = direct.get("echantillon")
	return echantillon is Dictionary and not bool(echantillon.get("suffisant", true))

static func seuil_echantillon(direct: Dictionary) -> int:
	var echantillon: Variant = direct.get("echantillon")
	return int(echantillon.get("seuil", 10)) if echantillon is Dictionary else 10

## « Darren DOWNES » → « D. DOWNES » : les mots qui ne sont pas tout en capitales (prénoms) deviennent des initiales.
static func abreger_prenom(nom: String) -> String:
	var mots := nom.strip_edges().split(" ", false)
	if mots.size() < 2: return nom
	var famille_debut := mots.size() - 1
	for k in mots.size():
		if mots[k] == mots[k].to_upper() and mots[k].to_lower() != mots[k]:
			famille_debut = k
			break
	if famille_debut == 0: return nom
	var sortie: Array[String] = []
	for k in mots.size(): sortie.append(mots[k].substr(0, 1) + "." if k < famille_debut else mots[k])
	return " ".join(PackedStringArray(sortie))

## Couleur de la note du match : vert au-dessus de 7, ivoire autour de 6,5, jaune sous 6,5,
## alerte sous 6 (6,5 au coup d'envoi).
## Couleur d'une note de match : le barème unique de la charte (`Charte.couleur_note`).
static func _teinte_note(note: float) -> Color:
	return Charte.couleur_note(note)

## Nom de famille lisible : sans le prénom, tronqué proprement au-delà de 9 lettres.
static func _nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.is_empty(): return ""
	var famille := " ".join(morceaux.slice(1)) if morceaux.size() > 1 else morceaux[0]
	return famille if famille.length() <= 9 else famille.substr(0, 8) + "."

## Lignes de Mon XV et du banc, « Remplacer le N » : elles ouvrent Équipe, donc attendent elles aussi le choix du
## staff (une décision à la fois), et ne font plus rien une fois le match fini. Bloquées, elles le montrent :
## atténuées, curseur ordinaire, et la raison est écrite (panneau d'arrêt, barre de commandes).
func _appliquer_blocage() -> void:
	var fini := _dernier.size() > 1 and _dernier[1] is Dictionary and bool(_dernier[1].get("finished", false))
	var bloque := _choix_en_attente() or fini
	var lignes: Array = []
	if is_instance_valid(xv): lignes.append_array(xv.get_children().filter(func(n: Node): return n is Button))
	if is_instance_valid(banc): lignes.append_array(banc.get_children().filter(func(n: Node): return n is Button))
	var remplacer := find_child("MatchBetweenReplace", true, false) as Button
	if remplacer != null: lignes.append(remplacer)
	for bouton: Button in lignes:
		bouton.disabled = bloque
		bouton.set_meta("contextual_enabled", not bloque)
		bouton.modulate.a = 0.55 if bloque else 1.0
		bouton.mouse_default_cursor_shape = Control.CURSOR_ARROW if bloque else Control.CURSOR_POINTING_HAND
		if bouton.get_theme_stylebox("disabled") != bouton.get_theme_stylebox("normal") and bouton.name.begins_with("MatchBetween") and bouton != remplacer:
			bouton.add_theme_stylebox_override("disabled", bouton.get_theme_stylebox("normal"))

static func _nom_initiale(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.size() < 2: return nom.strip_edges()
	return "%s. %s" % [morceaux[0].substr(0, 1), " ".join(morceaux.slice(1))]

func _app() -> Object:
	if app_commandes != null and is_instance_valid(app_commandes): return app_commandes
	var noeud := get_parent()
	while noeud != null:
		var candidat: Variant = noeud.get("app")
		if candidat is Object and is_instance_valid(candidat) and candidat.has_method("_command"): return candidat
		if noeud.has_method("_command"): return noeud
		noeud = noeud.get_parent()
	return null

## Moral en direct d'un de nos joueurs (`live.pilotage.moral[id]` : valeur, départ, cle, label, tendance), {} sinon.
static func moral_joueur(p: Dictionary, id: String) -> Dictionary:
	var tous: Variant = p.get("moral")
	if not tous is Dictionary: return {}
	var m: Variant = (tous as Dictionary).get(id)
	return m if m is Dictionary and not str(m.get("label", "")).is_empty() else {}

## Couleur d'un palier de moral (jetons de la charte : vert gain, bleu moral, orange, rouge perte).
static func teinte_moral(cle: String) -> Color:
	match cle:
		"gonfle": return Charte.NOTE_EXCELLENTE
		"confiant": return Charte.CONDITION
		"inquiet": return Charte.INTENSIF
		"abattu": return Charte.PERTE
	return Charte.MORAL
