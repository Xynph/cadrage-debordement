extends "res://ui/immersive08/coach_bandeau.gd"
## Gabi adjoint, chez lui au Bureau : zone de Gabi en pied, carnet de la semaine, carte des premiers pas, pied du bandeau.
## Hérite du bandeau (coach_bandeau.gd) ; l'écran se lit par coach_canvas.gd.

## Le Bureau réserve une zone à Gabi quand il est activé, en carrière (sinon : mise en page classique).
func bureau_disponible() -> bool:
	return is_instance_valid(app) and is_instance_valid(_bulle) and app._has_career() and profile.data.enabled

## Appelé par office_canvas.gd : « Ta semaine, vue par Gabi » (synthèse et conseil), le bloc supplémentaire du Bureau
## (prochains matchs : `extra(zone, haut, largeur) -> hauteur`), puis le buste de Gabi et sa bulle en bas de la colonne.
func installer_bureau(zone: Control, extra: Callable = Callable()) -> void:
	_bureau = zone
	_bureau_extra = extra
	PremiersPas.observer(profile, str(app.route), app.model, str(app.last_command), bool(app.bridge.last_response_ok))
	_semaine = Semaine.synthese(app.model)
	zone.resized.connect(_disposer_bureau.bind(zone))
	_disposer_bureau(zone)
	var conseil: Dictionary = _semaine.get("conseil", {})
	if is_instance_valid(_pied) and _pied.has_method("set_moment") and not conseil.is_empty():
		_pied.set_moment({"id": "semaine:" + _career_context(app.model) + ":" + str(hash(conseil.get("texte", ""))), "categorie": str(conseil.get("categorie", "consigne")), "ton": str(conseil.get("ton", Avis.NEUTRE))})

func _couleur(nom: String) -> Color:
	return {"or": Charte.IVOIRE, "menthe": Charte.V, "ambre": Charte.IVOIRE, "rouge": Charte.D}.get(nom, Charte.IVOIRE)

func _disposer_bureau(zone: Control) -> void:
	if not is_instance_valid(zone) or zone != _bureau: return
	for child in zone.get_children():
		zone.remove_child(child); child.queue_free()
	_bureau_figure = null
	_bureau_suivre = null
	var w := zone.size.x / C.density
	var h := zone.size.y / C.density
	if w < 120 or h < 200: return
	var pad := 24.0
	var text_w := w - pad * 2
	# Carnet de la semaine : un panneau plat, titre italique, une note par sujet (libellé en capitales, texte ivoire).
	var carnet := Carnet.new()
	carnet.name = "GabiCarnet"
	carnet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(carnet)
	var y := 40.0
	var titre := D.text(carnet, pad, y, "TA SEMAINE, VUE PAR GABI", 26, Charte.IVOIRE, 800, w - pad * 2)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	titre.name = "GabiCarnetTitre"
	y += 16
	D.line(carnet, Vector2(pad - 4, y), Vector2(w - pad + 4, y), Color(Charte.FILET, .9))
	y += 14
	var lignes: Array = _semaine.get("lignes", [])
	for ligne: Dictionary in lignes:
		# Seule la phrase du match reste (21/11) : le groupe et l'alerte répétaient l'État du groupe et ses pastilles.
		if str(ligne.get("cle", "")) != "match": continue
		y = _ligne_carnet(carnet, pad, y, text_w, str(ligne.get("libelle", "")), str(ligne.get("texte", "")), "", _couleur(str(ligne.get("couleur", "or"))), "GabiLigne_" + str(ligne.get("cle", "")), _ouvrir_ligne(str(ligne.get("cle", ""))))
	var conseil: Dictionary = _semaine.get("conseil", {})
	var changements: Array = conseil.get("action", {}).get("changements", []) if conseil.get("action") is Dictionary and conseil.action.get("changements") is Array else []
	if not conseil.is_empty() and not changements.is_empty():
		y = _conseil_changements(carnet, pad, y, text_w, conseil, changements)
	elif not conseil.is_empty():
		y = _ligne_carnet(carnet, pad, y, text_w, "MON CONSEIL", str(conseil.get("texte", "")), "", Charte.IVOIRE, "GabiLigne_conseil", (func(): suivre_conseil(conseil.get("action", {}))) if conseil.get("action") is Dictionary and not conseil.action.is_empty() else Callable())
	var carnet_h := y + 4
	D.place(carnet, Rect2(0, 0, w, carnet_h))
	var bas := carnet_h + 12
	if _bureau_extra.is_valid(): bas += float(_bureau_extra.call(zone, bas, w)) + 12
	# Buste de Gabi (160-200 px, du côté opposé au texte) et sa bulle : panneau-2, filet gauche incliné au trait du club.
	var buste_h := minf(270.0, h - bas - 8)
	if buste_h < 150.0: return
	var buste_w := buste_h * .92
	var bulle_w := w - pad * 2 - buste_w - 20
	var action: Dictionary = conseil.get("action", {}) if conseil.get("action") is Dictionary else {}
	var bulle := Panel.new()
	bulle.name = "GabiBureauBulle"
	bulle.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU_2))
	bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(bulle)
	var bulle_h := minf(buste_h - 30.0, 170.0)
	D.place(bulle, Rect2(pad, h - 8 - buste_h + (buste_h - bulle_h) / 2.0, bulle_w, bulle_h))
	var filet := Polygon2D.new()
	var inc := Charte.decalage(bulle_h)
	filet.polygon = PackedVector2Array([Vector2(inc, 0) * C.density, Vector2(inc + 5, 0) * C.density, Vector2(5, bulle_h) * C.density, Vector2(0, bulle_h) * C.density])
	filet.color = Charte.club_trait(app.accent)
	bulle.add_child(filet)
	var detail := str(action.get("detail", "")) if not action.is_empty() else ""
	if detail.is_empty(): detail = "Je suis là si tu as besoin d’un avis."
	var parole := Label.new()
	parole.name = "GabiBureauParole"
	parole.text = detail
	parole.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parole.add_theme_font_override("font", C.BODY)
	parole.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	parole.add_theme_color_override("font_color", Charte.IVOIRE)
	parole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulle.add_child(parole)
	D.place(parole, Rect2(inc + 20, 12, bulle_w - inc - 36, bulle_h - 56))
	parole.max_lines_visible = 3
	if not action.is_empty():
		_bureau_suivre = Link.styled_button(bulle, Rect2(inc + 14, bulle_h - 44, bulle_w - inc - 28, 36), str(action.get("libelle", "Suivre le conseil")), 20, Charte.IVOIRE, "GabiBureauSuivre")
		_bureau_suivre.add_theme_font_override("font", Charte.texte_moyen())
		_bureau_suivre.icon = C.icon_texture("arrow", Charte.IVOIRE)
		_bureau_suivre.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_bureau_suivre.add_theme_constant_override("icon_max_width", C.px(20))
		_bureau_suivre.pressed.connect(suivre_conseil.bind(action))
		_bureau_suivre.tooltip_text = str(action.get("detail", "Applique la proposition de Gabi (tu peux toujours la défaire)"))
		_bureau_suivre.disabled = app.waiting or not app._live().is_empty()
	_bureau_figure = TextureRect.new()
	_bureau_figure.name = "GabiBureauFigure"
	_bureau_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bureau_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bureau_figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bureau_figure.mouse_filter = Control.MOUSE_FILTER_STOP
	_bureau_figure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bureau_figure.tooltip_text = "Gabi · clic : son avis"
	_bureau_figure.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_bureau_figure.accept_event(); _clic_bandeau())
	zone.add_child(_bureau_figure)
	D.place(_bureau_figure, Rect2(w - pad - buste_w, h - 8 - buste_h, buste_w, buste_h))
	var source := _source_pied()
	if source == null: return
	_bureau_figure.texture = source.texture
	_bureau_figure.material = source.material if not source is GabiPortrait else null
	if source is GabiPortrait:
		var physical := _bureau_figure.size * _bureau_figure.get_global_transform_with_canvas().get_scale().y
		if physical.x < 8: physical = _bureau_figure.size
		source.set_render_size(Vector2i(roundi(physical.x * 1.25), roundi(physical.y * 1.25)))

## Écran ouvert par une ligne du carnet de la semaine : le match → Préparation, le groupe → Effectif, l'alerte → Composition.
func _ouvrir_ligne(cle: String) -> Callable:
	var route: String = {"match": "Préparation", "groupe": "Effectif", "alerte": "Composition"}.get(cle, "")
	if route.is_empty(): return Callable()
	return func():
		if not app.waiting and app._live().is_empty(): app._navigate(route)

## Fond plat (sans dégradé, ombre portée de la charte) des blocs de la colonne de Gabi : carte rayon 12 px (16 en référence 2560) par
## défaut, panneau 18 px (24) pour une carte de page.
func _plat(couleur: Color, rayon: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(maxi(3, C.px(rayon)))
	style.anti_aliasing = true
	return Charte.ombrer(style, rayon)

## Appelé par main.gd après chaque rendu : coche les objectifs des premiers pas sur l'événement réel.
func observer_premiers_pas(route: String, model: Dictionary, command: String, response_ok: bool) -> void:
	PremiersPas.observer(profile, route, model, command, response_ok)

## « Premiers pas » : une carte à part sous la frise du Bureau (jamais dans la colonne de Gabi, dont elle
## réduirait la figure). Un objectif à la fois, avec son bouton d'action ; se coche sur l'événement réel
## (gabi_premiers_pas.gd). Masquable ; disparaît une fois fini ou à la 1re journée. Renvoie la hauteur prise (0 : rien).
func carte_premiers_pas(page: Control, rect: Rect2) -> float:
	if not PremiersPas.visible(app.model, profile.data): return 0.0
	if bool(Accueil.etat(profile.data).get("connu", false)) and str(Accueil.etat(profile.data).get("club", "")) == str(app.model.get("club", {}).get("id", "")): return 0.0
	var liste := PremiersPas.objectifs(app.model, profile.data)
	var objectif := PremiersPas.courant(liste)
	if objectif.is_empty(): return 0.0
	var carte := D.panel(page, rect, "", "", "", "GabiPremiersPasCarte")
	carte.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU, 24))
	var pad := 22.0
	var boutons_w := 300.0 + 78.0 + 24.0
	var libelle := "PREMIERS PAS · %d SUR %d" % [PremiersPas.faits(liste), liste.size()]
	_ligne_carnet(carte, pad, 18.0, rect.size.x - pad * 2 - 34 - boutons_w - 16, libelle, str(objectif.texte), "check", C.MINT, "GabiPremiersPas")
	var action: Dictionary = objectif.action
	var bouton := D.button(carte, Rect2(rect.size.x - pad - 78 - 24 - 300, (rect.size.y - 42) / 2, 300, 42), str(objectif.libelle), func(): _suivre_premier_pas(action), false, "arrow", true, ACCENT, "GabiPremiersPasAction")
	bouton.tooltip_text = str(objectif.titre)
	bouton.disabled = app.waiting or not app._live().is_empty()
	var masquer := D.button(carte, Rect2(rect.size.x - pad - 78, (rect.size.y - 42) / 2, 78, 42), "Masquer", func():
		PremiersPas.masquer(profile)
		app.call_deferred("_render"), false, "", true, ACCENT, "GabiPremiersPasMasquer")
	masquer.tooltip_text = "Ne plus afficher les premiers pas"
	return rect.size.y

func _suivre_premier_pas(action: Dictionary) -> void:
	if app.waiting or not app._live().is_empty(): return
	if str(action.get("type", "")) == "reprise": app._open_reprise_decision()
	else: suivre_conseil(action)

## Gabi en pied : un second portrait 3D (même modèle), cadré en entier ; repli : le portrait 2D du guide.
func _source_pied() -> TextureRect:
	if not portrait is GabiPortrait: return portrait
	if not is_instance_valid(_pied):
		_pied = GabiPortrait.new()
		_pied.model = portrait.model
		_pied.framing = "buste"
		_pied.name = "GabiPortraitPied"
		_coulisse.add_child(_pied)
		_pied.size = Vector2(4, 4)
		_pied.visible = false
		var reduced: bool = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
		_pied.set_reduced_motion(reduced)
	return _pied

## Gabi en pied ne vit (et ne se rend) que pendant l'affichage du Bureau.
func _maj_pied() -> void:
	if not is_instance_valid(_pied): return
	var montrer := is_instance_valid(_bureau_figure) and _bureau_figure.is_visible_in_tree() and visible
	if _pied.visible != montrer: _pied.visible = montrer
	if montrer and is_instance_valid(_bureau_suivre): _bureau_suivre.disabled = app.waiting or not app._live().is_empty()

func _ligne_carnet(parent: Control, pad: float, y: float, text_w: float, libelle: String, texte: String, icone: String, couleur: Color, id: String, ouvrir: Callable = Callable()) -> float:
	var x0 := pad
	if not icone.is_empty():
		var icon := C.icon(icone, 20, couleur)
		parent.add_child(icon)
		D.place(icon, Rect2(pad, y + 2, 20, 20))
		x0 = pad + 34
		text_w -= 34
	var px := maxi(12, C.px(19))
	var height := C.BODY.get_multiline_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, C.px(text_w), px).y / C.density
	# Toute la ligne ouvre l'écran concerné (sous les noms de joueurs, qui ouvrent leur fiche).
	if ouvrir.is_valid():
		var zone := Link.styled_button(parent, Rect2(x0 - 8, y - 2, text_w + 16, height + 30), "", 19, Charte.IVOIRE, id + "_ouvrir")
		zone.pressed.connect(ouvrir)
		zone.tooltip_text = "Ouvrir · " + libelle.capitalize()
		zone.accessibility_name = zone.tooltip_text
	D.text(parent, x0, y + 17, libelle, 16, Charte.IVOIRE_2 if couleur != Charte.D else couleur, 700, text_w).name = id + "_libelle"
	var label := Label.new()
	label.name = id
	label.text = texte
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", C.BODY)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Charte.IVOIRE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	D.place(label, Rect2(x0, y + 24, text_w, height + 2))
	if ouvrir.is_valid(): load("res://ui/immersive08/office_canvas.gd").noms_cliquables(app, parent, Rect2(x0, y + 24, text_w, height + 2), texte, 19, C.BODY)
	return y + 24 + height + 12

## « MON CONSEIL » d'un changement de feuille : un nom → un nom, puis « +5 » pour les autres changements (la phrase
## complète de Gabi reste dans l'infobulle). Toute la ligne suit le conseil.
func _conseil_changements(parent: Control, pad: float, y: float, text_w: float, conseil: Dictionary, changements: Array) -> float:
	var action: Dictionary = conseil.action
	var zone := Link.styled_button(parent, Rect2(pad - 8, y - 2, text_w + 16, 66), "", 19, Charte.IVOIRE, "GabiLigne_conseil_ouvrir")
	# La ligne ouvre la composition, où les changements proposés se voient (« Suivre le conseil » les applique).
	zone.pressed.connect(func(): if not app.waiting and app._live().is_empty(): app._navigate("Composition"))
	zone.tooltip_text = str(conseil.get("texte", ""))
	zone.accessibility_name = "Mon conseil · " + zone.tooltip_text
	D.text(parent, pad, y + 17, "MON CONSEIL", 16, Charte.IVOIRE_2, 700, text_w).name = "GabiLigne_conseil_libelle"
	var premier: Dictionary = changements[0]
	var entrant := str(Avis._nom(Avis.joueur(app.model, str(premier.get("playerId", "")))))
	var sortant := str(Avis._nom(Avis.joueur(app.model, str(premier.get("sortant", "")))))
	var texte := "%s → %s" % [entrant, sortant]
	var restants := changements.size() - 1
	var largeur_plus := 70.0 if restants > 0 else 0.0
	var ligne := D.text(parent, pad, y + 50, texte, 22, Charte.IVOIRE, 700, minf(text_w - largeur_plus, R.largeur(texte, 22) + 4))
	ligne.name = "GabiLigne_conseil"
	ligne.tooltip_text = zone.tooltip_text
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if restants > 0:
		R.pastille(parent, pad + ligne.size.x / C.density + 12, y + 50, "+%d" % restants, Charte.IVOIRE_2, "", "GabiLigne_conseil_plus").tooltip_text = zone.tooltip_text
	return y + 66 + 8
