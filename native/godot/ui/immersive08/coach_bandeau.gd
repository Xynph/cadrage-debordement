extends "res://ui/immersive08/coach_bulle.gd"
## Gabi adjoint, le bandeau du haut : pose du visage et de la remarque (appelée par shell.gd), clic, et règles de parole
## (bulle ou indice, une bulle spontanée par jour). Hérite de la bulle (coach_bulle.gd) ; l'écran se lit par coach_canvas.gd.
## Informations déjà dites pendant cette session (clé moteur) : Gabi ne se répète pas d'un écran à l'autre.
var _infos_dites: Dictionary = {}

## Écrans où le coach décide quelque chose : Gabi n'y recouvre jamais le contenu d'un voile.
const ECRANS_DECISION := ["Composition", "Match", "Préparation"]

## Appelé par shell.gd à chaque construction du bandeau : visage, remarque du moment, indice.
func installer_bandeau(zone: Control) -> void:
	_bandeau = zone
	_bandeau_masque = bool(zone.get_meta("masque", false))
	_bandeau_compact = bool(zone.get_meta("compact", false))
	_visage = null
	if not is_instance_valid(app) or not profile.data.enabled or not app._has_career():
		zone.hide()
		return
	_place_portrait()
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE if _bandeau_masque else Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.focus_mode = Control.FOCUS_NONE if _bandeau_masque else Control.FOCUS_ALL
	zone.tooltip_text = "Gabi, ton adjoint · clic : son avis sur cet écran, l'aide, la visite guidée"
	_pastille = Panel.new()
	_pastille.name = "GabiPastille"
	_pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(_pastille)
	_visage = Medaillon.new()
	_visage.ovale = _bandeau_compact
	zone.add_child(_visage)
	_visage.afficher(portrait)
	if _bandeau_compact:
		zone.accessibility_name = "Gabi, ton adjoint · F1"
		zone.tooltip_text = "Gabi, ton adjoint · clic : son avis sur cet écran · F1 : l'aide"
	_bandeau_titre = Label.new()
	_bandeau_titre.name = "GabiBandeauTitre"
	_bandeau_titre.add_theme_font_override("font", C.BOLD)
	_bandeau_titre.add_theme_color_override("font_color", C.GOLD)
	_bandeau_titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bandeau_titre.clip_text = true
	zone.add_child(_bandeau_titre)
	_fil = Control.new()
	_fil.name = "GabiFil"
	_fil.clip_contents = true
	_fil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(_fil)
	_fil_texte = Label.new()
	_fil_texte.name = "GabiRemarque"
	_fil_texte.add_theme_font_override("font", C.BODY)
	_fil_texte.add_theme_color_override("font_color", C.IVORY)
	_fil_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fil.add_child(_fil_texte)
	_fil_fondu = TextureRect.new()
	_fil_fondu.name = "GabiFilFondu"
	_fil_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(FOND, 0.0)); gradient.set_color(1, FOND)
	var fade := GradientTexture2D.new(); fade.gradient = gradient; fade.width = 32; fade.height = 2
	_fil_fondu.texture = fade
	_fil_fondu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fil_fondu.stretch_mode = TextureRect.STRETCH_SCALE
	_fil.add_child(_fil_fondu)
	# Fondu du bord gauche : la remarque s'efface en défilant au lieu d'être coupée net (absent au départ,
	# quand le début du texte est entier, juste après la marge intérieure).
	_fil_fondu_gauche = TextureRect.new()
	_fil_fondu_gauche.name = "GabiFilFonduGauche"
	_fil_fondu_gauche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient_g := Gradient.new()
	gradient_g.set_color(0, FOND); gradient_g.set_color(1, Color(FOND, 0.0))
	var fade_g := GradientTexture2D.new(); fade_g.gradient = gradient_g; fade_g.width = 32; fade_g.height = 2
	_fil_fondu_gauche.texture = fade_g
	_fil_fondu_gauche.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fil_fondu_gauche.stretch_mode = TextureRect.STRETCH_SCALE
	_fil_fondu_gauche.hide()
	_fil.add_child(_fil_fondu_gauche)
	zone.gui_input.connect(_entree_bandeau)
	zone.mouse_entered.connect(func(): _survol = true; _style_pastille())
	zone.mouse_exited.connect(func(): _survol = false; _style_pastille())
	zone.resized.connect(_disposer_bandeau)
	_remarque_cle = ""
	if _bandeau_masque:
		for masque: Control in [_pastille, _visage, _bandeau_titre, _fil]: masque.hide()
	elif _bandeau_compact:
		for masque: Control in [_pastille, _bandeau_titre, _fil]: masque.hide()
	_disposer_bandeau()
	_maj_indice()

func _style_pastille() -> void:
	if not is_instance_valid(_pastille): return
	var style := StyleBoxFlat.new()
	style.bg_color = FOND.lightened(.06) if _survol else FOND
	style.border_color = Color(C.GOLD, .7 if _survol else .38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(maxi(4, roundi(_pastille.size.y * .5)))
	_pastille.add_theme_stylebox_override("panel", style)
	if is_instance_valid(_visage): _visage.set_hover(_survol)

func _disposer_bandeau() -> void:
	if not is_instance_valid(_bandeau) or not is_instance_valid(_visage): return
	var s := _bandeau.size
	var h := s.y
	if _bandeau_compact:
		# Médaillon ovale (72 × 48 en référence) : le visage remplit la zone, l'ovale tracé est dessiné par-dessus.
		_visage.position = Vector2.ZERO
		_visage.size = s
		_visage.ajuster()
		_style_pastille()
		if not _bandeau_masque and portrait is GabiPortrait and portrait.framing == "visage":
			portrait.set_render_size(Vector2i(roundi(s.x * _bandeau.get_global_transform_with_canvas().get_scale().x * 2.0), roundi(h * _bandeau.get_global_transform_with_canvas().get_scale().y * 2.0)))
		return
	var d := roundf(h * 0.97)
	_visage.position = Vector2(0, (h - d) / 2.0)
	_visage.size = Vector2(d, d)
	_pastille.position = Vector2(d * 0.5, h * 0.1)
	_pastille.size = Vector2(maxf(0.0, s.x - d * 0.5), h * 0.8)
	_style_pastille()
	var left := d + h * 0.2
	var title_px := maxi(12, roundi(h * 0.235))
	var line_px := maxi(13, roundi(h * 0.31))
	_bandeau_titre.add_theme_font_size_override("font_size", title_px)
	_fil_texte.add_theme_font_size_override("font_size", line_px)
	var title_h := C.BOLD.get_height(title_px)
	var line_h := C.BODY.get_height(line_px)
	var top := (h - title_h - line_h) / 2.0
	_bandeau_titre.position = Vector2(left, top)
	_bandeau_titre.size = Vector2(maxf(0.0, s.x - left - h * 0.4), title_h)
	_fil.position = Vector2(left, top + title_h)
	_fil.size = Vector2(maxf(0.0, s.x - left - h * 0.4), line_h)
	_fil_texte.position.y = 0
	_fil_texte.size.y = line_h
	_fil_fondu.position = Vector2(_fil.size.x - h * 0.5, 0)
	_fil_fondu.size = Vector2(h * 0.5, line_h)
	_fil_marge = roundf(maxf(4.0, h * 0.12))
	_fil_fondu_gauche.position = Vector2.ZERO
	_fil_fondu_gauche.size = Vector2(h * 0.4, line_h)
	# Rendu net : deux fois les pixels physiques du disque, ni plus ni moins.
	var physical := d * _bandeau.get_global_transform_with_canvas().get_scale().y
	if _bandeau_masque: return
	if portrait is GabiPortrait and portrait.framing == "visage": portrait.set_render_size(Vector2i.ONE * roundi(physical * 2.0))
	_fil_regle(true)

func _entree_bandeau(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_bandeau.accept_event()
		_clic_bandeau()
	elif event.is_action_pressed("ui_accept"):
		_bandeau.accept_event()
		_clic_bandeau()

## Clic sur Gabi (bandeau ou Bureau) : le message en attente, sinon son avis sur l'écran (+ menu).
func _clic_bandeau() -> void:
	if _blocked_adjoint(): return
	if _bulle.visible: fermer_bulle(); return
	if not _attente.is_empty() and _attente.get("route") == str(app.route):
		var message := _attente.duplicate(true)
		_consommer(message)
		_montrer(message)
		return
	demander_avis()

func _consommer(message: Dictionary) -> void:
	if not str(message.get("info", "")).is_empty(): _infos_dites[str(message.info)] = true
	var visit := str(message.get("visit", ""))
	var event := str(message.get("event", ""))
	var changed := false
	if not visit.is_empty() and visit not in profile.data.seen: profile.data.seen.append(visit); changed = true
	if not event.is_empty() and event not in profile.data.events:
		profile.data.events.append(event); changed = true
		while profile.data.events.size() > Profile.EVENT_LIMIT: profile.data.events.pop_front()
	if message == _attente or (not _attente.is_empty() and _attente.get("texte") == message.get("texte")): _attente.clear()
	if changed: profile.save_profile(profile.data); _status()

## Le grand mode (portrait + voile assombri) n'est permis qu'au Bureau (l'accueil du club) et sans fenêtre ouverte :
## jamais sur une fiche, une composition ou une fenêtre de décision.
func _grand_permis() -> bool:
	if not is_instance_valid(app) or _has_dialog(app): return false
	return str(app.route) == "Bureau"

## Bulle ouverte d'office : pas sur un écran ni par-dessus une fenêtre de décision (simple indice dans le bandeau).
func _bulle_permise() -> bool:
	return is_instance_valid(app) and not _has_dialog(app) and str(app.route) not in ECRANS_DECISION

## Message de Gabi sans voile : bulle du bandeau si la limite des interventions spontanées le permet, sinon
## simple indice dans le bandeau (le coach clique sur la tête de Gabi pour lire).
func _dans_le_bandeau(page: String, fragment: Dictionary, event: String, titre: String) -> void:
	var moment: Dictionary = Moments.moment(page, str(fragment.get("id", "")), app.model)
	var message := {"genre": "contexte", "titre": titre, "texte": str(fragment.get("text", "")), "categorie": moment.categorie, "ton": moment.ton, "route": str(app.route), "visit": "", "event": event, "partout": true}
	if _bulle_permise() and _spontane_permis():
		_consommer(message)
		_montrer(message)
	else:
		_attente = message
		_maj_indice()

## Limite de fréquence des interventions spontanées : une bulle ouverte d'office par jour de jeu.
func _spontane_permis() -> bool:
	var meta: Dictionary = app.model.get("meta", {}) if app.model.get("meta") is Dictionary else {}
	var day := str(meta.get("calendarToday", meta.get("date", ""))) + ":" + _career_context(app.model)
	if day != _jour_spontane: _jour_spontane = day; _spontanes = 0
	if _spontanes >= SPONTANE_PAR_JOUR or (_bulle.visible and _contenu.get("genre") != "fait"): return false
	_spontanes += 1
	return true
