extends "res://guide/coach_guide.gd"
## Le guide de carrière utilise le portrait 3D quand son GLB est installé (ou le Gabi Mixamo privé,
## voir coach_portrait_3d.gd).
##
## Gabi adjoint (13 novembre 2026, validé par Léo) : en carrière, Gabi vit dans un médaillon permanent du
## coin bas droit, que les écrans laissent libre (voir shell.gd, GABI_DOCK). « Ton avis, Gabi ? » donne
## un avis contextuel dans une bulle à côté du médaillon ; sur la composition et le recrutement, l'avis
## propose une action (« Suivre le conseil »). Le mode grand (portrait en pied, écran assombri) est réservé
## aux moments clés : début de carrière, veille de finale, fin de saison, grosse crise, et à l'aide ou la
## visite guidée demandées. Avis : guide/gabi_avis.gd ; médaillon : guide/gabi_medaillon.gd.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const GabiPortrait = preload("res://guide/coach_portrait_3d.gd")
const Avis = preload("res://guide/gabi_avis.gd")
const Medaillon = preload("res://guide/gabi_medaillon.gd")
## Hauteur du médaillon : 120 px en 1920×1080, proportionnelle à la fenêtre (la bande du pied de page, shell.gd
## GABI_BAND, la réserve).
const MEDAILLON_RATIO := 120.0 / 1080.0
const ACCENT = Color("176e49")
## Bulle spontanée (première visite d'un écran, conseil de composition) : au plus une par jour de jeu.
## Les autres attendent sous l'indice du médaillon (point or et carnet).
const SPONTANE_PAR_JOUR := 1
## Textes des moments clés (mode grand). Une idée par bulle, phrases prononçables.
const MOMENTS_CLES := {
	"debut": ["bienvenue", "Te voilà dans la maison, coach. Moi, je reste à côté, dans mon coin : quand tu veux mon avis, tu demandes. Je dirai ce que je pense, et c'est toi qui décides."],
	"finale": ["bureau", "Demain, c'est une finale. Ne change rien qui marche, dors bien, et rappelle-leur qu'une mêlée qui tient, ça fait taire un stade."],
	"crise": ["bureau", "Ça ne va pas, et tout le monde le voit. On ne repeint pas une armoire bancale : on revient aux bases, la conquête, la défense, et on se serre les coudes."],
}

var _medaillon: Control
var _bulle: Control
var _bulle_titre: Label
var _bulle_texte: Label
var _bulle_actions: HBoxContainer
var _bulle_suivre: Button
var _avis_bouton: Button
var _voile: ColorRect
## Contenu de la bulle affichée : {genre: avis|menu|contexte|humeur, texte, action, route, cle}.
var _contenu: Dictionary = {}
## Message en attente sous l'indice du médaillon (même forme).
var _attente: Dictionary = {}
## Commandes du conseil suivi, envoyées une à une après chaque réponse du moteur.
var _file: Array = []
var _file_message := ""
var _humeur_cle := ""
var _jour_spontane := ""
var _spontanes := 0
var _ecartes: Dictionary = {}
## Contexte de carrière déjà examiné une fois le coin de Gabi en place (moment clé au premier écran).
var _contexte_examine := ""
## Moment clé affiché (clé du profil) : rendu s'il est interrompu par une fenêtre ou un écran bloquant.
var _moment_courant := ""

func _make_portrait() -> TextureRect:
	var model := GabiPortrait.load_model()
	if model == null: return super._make_portrait()
	var display := GabiPortrait.new()
	display.model = model
	return display

func _portrait_extent(short_layout: bool) -> Vector2:
	if not portrait is GabiPortrait: return super._portrait_extent(short_layout)
	var height := app.get_window().size.y
	var side := 320.0 if height >= 1440 else (256.0 if height >= 1080 else 152.0)
	return Vector2(side, side)

func _allows_automatic_speech() -> bool:
	return false

func _request_portrait_gesture(opening: bool) -> void:
	if portrait is GabiPortrait:
		portrait.request_gesture(opening and app._has_career())

func _build() -> void:
	theme=Legacy.theme(ACCENT)
	super._build()
	_title.add_theme_font_override("font",C.BOLD)
	_title.add_theme_font_size_override("font_size",17)
	_title.add_theme_color_override("font_color",C.GOLD)
	_title.add_theme_stylebox_override("normal",_surface(C.BG,C.GOLD))
	_settings_panel.add_theme_stylebox_override("panel",_surface(C.PANEL,C.LINE))
	_error_panel.add_theme_stylebox_override("panel",_surface(Color("282020"),C.ALERT))
	_build_adjoint()

func _label(parent: Node, text: String, size: int = 13) -> Label:
	var label := super._label(parent,text,size)
	label.add_theme_font_override("font",C.BODY)
	label.add_theme_color_override("font_color",C.IVORY)
	return label

func _button(parent: Node, text: String, id: String, action: Callable) -> Button:
	var button := super._button(parent,text,id,action)
	button.add_theme_font_override("font",C.DISPLAY)
	button.add_theme_font_size_override("font_size",16)
	_skin_button(button,false)
	return button

func _primary(button: Button, active: bool) -> void:
	_skin_button(button,active)

func _skin_button(button: Button, active: bool) -> void:
	var color := ACCENT.darkened(.29) if active else C.PANEL
	var edge := C.MINT if active else C.LINE
	button.add_theme_stylebox_override("normal",_surface(color,edge))
	button.add_theme_stylebox_override("hover",_surface(color.lightened(.12),C.GOLD))
	button.add_theme_stylebox_override("pressed",_surface(color.darkened(.16),edge))
	button.add_theme_stylebox_override("disabled",_surface(C.BG,C.LINE))
	var focus := _surface(Color.TRANSPARENT,C.GOLD)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		button.add_theme_color_override(state,C.IVORY)
	button.add_theme_color_override("font_disabled_color",C.MUTED)

func _surface(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=Color(border,.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left=7
	style.content_margin_right=7
	style.content_margin_top=3
	style.content_margin_bottom=3
	return style

# --- Médaillon, bulle et bouton « Ton avis » ---------------------------------------------------------

func _build_adjoint() -> void:
	_medaillon = Medaillon.new()
	add_child(_medaillon)
	_medaillon.pressed.connect(_clic_medaillon)
	_medaillon.adopt(portrait)
	_avis_bouton = _button(self, "Ton avis, Gabi ?", "GabiAvis", demander_avis)
	_avis_bouton.tooltip_text = "L'avis de Gabi sur cet écran, d'après l'état réel du club"
	_avis_bouton.add_theme_color_override("font_color", C.GOLD)
	_avis_bouton.add_theme_color_override("font_hover_color", C.IVORY)
	var pill := _surface(Color("12261d"), C.GOLD)
	pill.set_corner_radius_all(40); pill.content_margin_left = 14; pill.content_margin_right = 14
	_avis_bouton.add_theme_stylebox_override("normal", pill)
	var pill_hover := pill.duplicate() as StyleBoxFlat; pill_hover.bg_color = Color("1b3a2b")
	_avis_bouton.add_theme_stylebox_override("hover", pill_hover)
	_bulle = Balloon.new()
	_bulle.speaker = _medaillon
	add_child(_bulle)
	_bulle.name = "GabiBulle"
	_bulle.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bulle.add_child(column)
	var head := HBoxContainer.new(); head.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_child(head)
	_bulle_titre = Label.new(); _bulle_titre.name = "GabiBulleTitre"
	_bulle_titre.add_theme_font_override("font", C.BOLD)
	_bulle_titre.add_theme_color_override("font_color", Color("6b5427"))
	_bulle_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_bulle_titre)
	var fermer := Button.new(); fermer.name = "GabiBulleFermer"; fermer.text = "×"; fermer.flat = true
	fermer.tooltip_text = "Fermer la bulle"
	fermer.add_theme_color_override("font_color", Color("5a4a33"))
	fermer.add_theme_color_override("font_hover_color", Color("29272b"))
	fermer.pressed.connect(fermer_bulle)
	head.add_child(fermer)
	_bulle_texte = Label.new(); _bulle_texte.name = "GabiBulleTexte"
	_bulle_texte.add_theme_font_override("font", C.BODY)
	_bulle_texte.add_theme_color_override("font_color", Color("29272b"))
	_bulle_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_bulle_texte)
	_bulle_actions = HBoxContainer.new(); _bulle_actions.add_theme_constant_override("separation", 6)
	_bulle_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bulle_actions)
	_bulle.hide()
	_voile = ColorRect.new()
	_voile.name = "GabiVoile"
	_voile.color = Color(0.02, 0.05, 0.04, 0.55)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	_voile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: close())
	_voile.hide()

## Médaillon en service : carrière ouverte, écran de carrière avec son coin réservé, hors match en direct.
func _adjoint_actif() -> bool:
	if not is_instance_valid(app) or not is_instance_valid(_medaillon) or not app._has_career(): return false
	if not profile.data.enabled: return false
	var live: Dictionary = app._live()
	if not live.is_empty() and not live.get("finished", false): return false
	return _dock_ready(_compact_dock())

func _place_portrait() -> void:
	if not is_instance_valid(portrait) or not is_instance_valid(_medaillon): return
	var grand := expanded or not _adjoint_actif()
	if grand and _medaillon.portrait == portrait:
		_medaillon.release()
		_body.add_child(portrait); _body.move_child(portrait, 0)
		_balloon.speaker = portrait
	elif not grand and _medaillon.portrait != portrait:
		portrait.get_parent().remove_child(portrait)
		_medaillon.adopt(portrait)

func _layout() -> void:
	if not is_instance_valid(_compact): return
	if is_instance_valid(_medaillon): _place_portrait()
	super._layout()
	if not is_instance_valid(_medaillon): return
	var actif := _adjoint_actif()
	_compact.visible = not expanded and not actif
	# Mode grand : une scène au-dessus du coin de Gabi ; changer de coin n'a plus de sens.
	var move: Control = find_child("GuideMove", true, false)
	if is_instance_valid(move): move.visible = not actif
	_medaillon.visible = actif and not expanded
	_avis_bouton.visible = actif and not expanded and not Avis.ecran(str(app.route), app.model).is_empty()
	if not actif or expanded: _bulle.hide()
	_layout_voile()
	if not actif: return
	if _medaillon.portrait == portrait: _medaillon._fit_portrait()
	var dock := _compact_dock().get_global_rect()
	# Le médaillon occupe la bande basse réservée (shell.gd, GABI_BAND) : jamais au-dessus de l'espace de
	# travail, quelle que soit la page.
	var top := dock.end.y - clampf(app.size.y * MEDAILLON_RATIO, 48.0, 240.0)
	if is_instance_valid(app.body_scroll) and app.body_scroll.is_visible_in_tree():
		top = maxf(top, app.body_scroll.get_global_rect().end.y + 4.0)
	var side := clampf(dock.end.y - top, 48.0, 240.0)
	_medaillon.size = Vector2(side, side)
	_medaillon.global_position = Vector2(dock.end.x - side, dock.end.y - side)
	_medaillon.reduced_motion = is_instance_valid(app.user_preferences) and bool(app.user_preferences.data.get("reduced_motion", false))
	var font_px := clampi(roundi(dock.size.y * 0.5), 14, 22)
	_avis_bouton.add_theme_font_size_override("font_size", font_px)
	var pill := _avis_bouton.get_combined_minimum_size()
	_avis_bouton.size = Vector2(pill.x, dock.size.y)
	# Centré sur le médaillon : la pastille accompagne Gabi, elle ne reste pas collée au bas du pied de page.
	_avis_bouton.global_position = Vector2(_medaillon.global_position.x - pill.x - side * 0.12, _medaillon.global_position.y + (side - dock.size.y) * 0.5)
	if _bulle.visible: _layout_bulle()

func _layout_voile() -> void:
	if not is_instance_valid(_voile): return
	if not is_instance_valid(app) or get_parent() != app: return
	if _voile.get_parent() != app: app.add_child(_voile)
	# Juste sous Gabi : même plan (z_index), dessiné avant lui.
	_voile.z_index = z_index
	var target := get_index()
	if _voile.get_index() > target: app.move_child(_voile, target)
	elif _voile.get_index() < target - 1: app.move_child(_voile, target - 1)
	_voile.position = Vector2.ZERO
	_voile.size = app.size
	_voile.visible = expanded and visible

func _layout_bulle() -> void:
	var side := _medaillon.size.x
	var width := clampf(app.size.x * 0.25, 330.0, 560.0)
	var px := clampi(roundi(side * 0.17), 15, 22)
	_bulle_texte.add_theme_font_size_override("font_size", px)
	_bulle_titre.add_theme_font_size_override("font_size", px - 2)
	_bulle_texte.custom_minimum_size.x = width - 45.0
	for button in _bulle_actions.get_children():
		if button is Button: button.add_theme_font_size_override("font_size", px)
	_bulle.size = Vector2(width, 0)
	_bulle.reset_size()
	var height := _bulle.get_combined_minimum_size().y
	_bulle.size = Vector2(width, height)
	var anchor := _medaillon.global_position
	var y := clampf(anchor.y + side * 0.62 - height, 70.0, app.size.y - height - 4.0)
	_bulle.global_position = Vector2(anchor.x - width + 6.0, y)
	_bulle.queue_redraw()

func _blocked_adjoint() -> bool:
	return _blocked() or not _adjoint_actif()

## Clic sur le médaillon : le message en attente, sinon la petite bulle de Gabi (avis, aide, visite).
func _clic_medaillon() -> void:
	if _blocked_adjoint(): return
	if _bulle.visible and _contenu.get("genre") != "attente": fermer_bulle(); return
	if not _attente.is_empty() and _attente.get("route") == str(app.route):
		var message := _attente.duplicate(true)
		_consommer(message)
		_montrer(message)
		return
	_montrer({"genre": "menu", "titre": "GABI", "texte": "Je suis là, coach. Tu veux mon avis sur cet écran, ou que je te montre comment marche la maison ?", "categorie": "question", "ton": Avis.NEUTRE})

## « Ton avis, Gabi ? » : avis contextuel de l'écran affiché.
func demander_avis() -> void:
	if _blocked_adjoint(): return
	var avis := Avis.avis(str(app.route), app.model, _focus_recrutement())
	if avis.is_empty(): return
	if not _attente.is_empty() and _attente.get("genre") == "avis" and _attente.get("route") == str(app.route): _attente.clear()
	_montrer(avis.merged({"genre": "avis", "titre": "GABI · TON AVIS"}))

## Joueur du marché dont le dossier est ouvert (écran Recrutement).
func _focus_recrutement() -> String:
	if str(app.route) != "Recrutement" or not is_instance_valid(app.root_content): return ""
	var dossier: Control = app.root_content.find_child("RecruitmentProfile", true, false)
	return str(dossier.get_meta("player_id", "")) if is_instance_valid(dossier) else ""

func _montrer(contenu: Dictionary) -> void:
	_contenu = contenu.duplicate(true)
	_contenu.route = str(app.route)
	_bulle_titre.text = str(contenu.get("titre", "GABI"))
	_bulle_texte.text = str(contenu.get("texte", ""))
	for child in _bulle_actions.get_children():
		_bulle_actions.remove_child(child); child.queue_free()
	_bulle_suivre = null
	var action: Dictionary = contenu.get("action", {}) if contenu.get("action") is Dictionary else {}
	if not action.is_empty():
		_bulle_suivre = _button(_bulle_actions, str(action.get("libelle", "Suivre le conseil")), "GabiSuivreConseil", suivre_conseil)
		_primary(_bulle_suivre, true)
		_bulle_suivre.disabled = app.waiting or not app._live().is_empty()
		_bulle_suivre.tooltip_text = "Applique la proposition de Gabi (tu peux toujours la défaire)"
	if contenu.get("genre") == "menu":
		_button(_bulle_actions, "Ton avis", "GabiMenuAvis", demander_avis)
	if contenu.get("genre") in ["menu", "contexte"]:
		_button(_bulle_actions, "Aide de l'écran", "GabiMenuAide", func(): fermer_bulle(); open_help())
		_button(_bulle_actions, "Visite guidée", "GabiMenuVisite", func(): fermer_bulle(); open_tour())
	if not action.is_empty():
		_button(_bulle_actions, "Je garde mon idée", "GabiIgnorer", func(): _ecarter(); fermer_bulle())
	_bulle_actions.visible = _bulle_actions.get_child_count() > 0
	_bulle.show()
	_layout_bulle()
	call_deferred("_layout_bulle")
	if portrait.has_method("set_moment"):
		portrait.set_moment({"id": "adjoint:" + str(hash(_bulle_texte.text)), "categorie": str(contenu.get("categorie", "consigne")), "ton": str(contenu.get("ton", Avis.NEUTRE))})
	if portrait.has_method("mime"): portrait.mime(_bulle_texte.text)
	_maj_indice()

func fermer_bulle() -> void:
	if is_instance_valid(_bulle): _bulle.hide()
	_contenu.clear()

func _ecarter() -> void:
	var cle := _cle_conseil(str(app.route))
	if not cle.is_empty(): _ecartes[cle] = true
	_attente.clear(); _maj_indice()

func _cle_conseil(route: String) -> String:
	return Avis.ecran(route, app.model) + ":" + _career_context(app.model)

# --- « Suivre le conseil » ---------------------------------------------------------------------------

func suivre_conseil() -> void:
	var action: Dictionary = _contenu.get("action", {}) if _contenu.get("action") is Dictionary else {}
	if action.is_empty() or app.waiting or not app._live().is_empty(): return
	_file.clear()
	match str(action.get("type", "")):
		"composition":
			for change: Dictionary in action.get("changements", []):
				_file.append({"command": "set_lineup", "payload": {"playerId": str(change.playerId), "slot": int(change.slot)}})
			_file_message = "C'est fait. Si tu n'es pas d'accord, remets-le : c'est toi qui signes la feuille."
		"recrutement":
			var id := str(action.get("playerId", ""))
			var context: Variant = app.model.get("clubLife", {}).get("managerCareer", {}).get("context")
			var watched: bool = id in app.management_ui.get("shortlist", [])
			var verdict := str(action.get("verdict", ""))
			if context is Dictionary and ((verdict in ["fonce", "a_suivre"] and not watched) or (verdict == "passe" and watched)):
				_file.append({"command": "manager_recruitment_watch", "payload": {"context": context.duplicate(true), "playerId": id}})
			_file_message = {"fonce": "Je l'ai mis en tête de ta liste. Approche-le maintenant, sans surenchérir.", "a_suivre": "Il est dans ta liste. On le regarde jouer avant de parler argent.", "passe": "Rayé de la liste. Le bon, on le trouvera."}.get(verdict, "C'est noté.")
			if verdict == "fonce": _file.append({"ouvrir_contrat": id})
	_ecarter()
	_suite_file()

func _suite_file() -> void:
	if app.waiting: return
	if _file.is_empty():
		if not _file_message.is_empty():
			var message := _file_message
			_file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": message, "categorie": "approbation", "ton": Avis.POSITIF})
		return
	var next: Dictionary = _file.pop_front()
	if next.has("ouvrir_contrat"):
		var player := Avis.marche(app.model, str(next.ouvrir_contrat))
		if not player.is_empty():
			fermer_bulle()
			app.SquadViews.contract(app, player, true)
		_suite_file()
		return
	if not app._command(str(next.command), next.payload):
		_file.clear(); _file_message = ""

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_medaillon): return
	if (not _file.is_empty() or not _file_message.is_empty()) and not app.waiting:
		if not app.bridge.last_response_ok or not str(app.last_error).is_empty():
			_file.clear(); _file_message = ""
			_montrer({"genre": "fait", "titre": "GABI", "texte": "Le changement n'est pas passé : " + str(app.last_error) + " On regardera autrement.", "categorie": "regret", "ton": Avis.NEGATIF})
		else:
			_suite_file()
	if is_instance_valid(_bulle) and _bulle.visible and _contenu.get("route", "") != str(app.route): fermer_bulle()
	# Le premier écran d'une carrière se construit avant le coin de Gabi : on réexamine le contexte une fois
	# le médaillon en place (début de carrière, première visite).
	if not app.waiting and not expanded and _adjoint_actif():
		var context := _career_context(app.model)
		if not context.is_empty() and context + "|" + str(app.route) != _contexte_examine:
			_contexte_examine = context + "|" + str(app.route)
			consider_context(str(app.route), app.model, "", true)
	if is_instance_valid(_bulle_suivre) and _bulle.visible: _bulle_suivre.disabled = app.waiting or not app._live().is_empty()

# --- Contexte : moments clés, première visite, humeur, indice ----------------------------------------

func consider_context(route: String, model: Dictionary, command: String, response_ok: bool) -> void:
	if is_instance_valid(_medaillon) and is_instance_valid(app) and app._has_career() and profile.data.enabled and route not in ["Accueil", "Création", "Packs"] and not _adjoint_actif():
		# Écran de carrière dont le coin de Gabi n'est pas encore placé (tri des conteneurs) : on attend
		# qu'il le soit (_process) plutôt que d'ouvrir l'ancienne bulle flottante.
		var live: Dictionary = app._live()
		if live.is_empty() or live.get("finished", false):
			_contexte_examine = ""
			return
	if not is_instance_valid(_medaillon) or not _adjoint_actif():
		super.consider_context(route, model, command, response_ok)
		return
	if not response_ok or app.waiting or app.closing or expanded: return
	if app.connection_error or not str(app.last_error).is_empty(): return
	_humeur(model)
	if _blocked(): return
	if _moment_cle(model): return
	super.consider_context(route, model, command, response_ok)
	_conseil_composition(route, model)
	_maj_indice()

## Moments clés (mode grand, écran assombri) : une seule fois chacun (clé dans le profil du guide).
func _moment_cle(model: Dictionary) -> bool:
	var context := _career_context(model)
	if context.is_empty(): return false
	var parts := context.split(":")
	var keys := {
		"debut": "debut:%s:%s:0:" % [parts[0], parts[1]],
		"finale": "finale:%s:%s:%s:" % [parts[0], parts[1], parts[2]],
		"crise": "crise:%s:%s:0:" % [parts[0], parts[1]],
	}
	var due := ""
	if keys.debut not in profile.data.events: due = "debut"
	elif Avis.finale(model) and keys.finale not in profile.data.events: due = "finale"
	elif Avis.crise(model) and keys.crise not in profile.data.events: due = "crise"
	if due.is_empty(): return false
	var moment: Array = MOMENTS_CLES[due]
	super._deliver_context(moment[0], {"id": "moment-" + due, "text": moment[1]}, "", keys[due])
	_moment_courant = keys[due] if expanded else ""
	return true

## Première visite d'un écran, contrat signé, fin de saison, trésorerie : la fin de saison et un compte
## dans le rouge sont des moments clés (mode grand) ; le reste passe par la bulle du médaillon.
func _deliver_context(id: String, fragment: Dictionary, visit: String, event: String) -> void:
	if not _adjoint_actif() or event.begins_with("season:") or event.begins_with("cash:"):
		super._deliver_context(id, fragment, visit, event)
		return
	var fragments: Array = Content.fragments(id)
	var short: Dictionary = fragment
	# La bulle du médaillon prend la version courte (première bulle numérotée) plutôt que le portrait complet.
	if event.is_empty() and fragments.size() > 1 and str(fragment.get("id", "")).ends_with("-caractere"): short = fragments[1]
	var page: Array = Content.page(id)
	var moment: Dictionary = Moments.moment(id, str(short.get("id", "")), app.model)
	var message := {"genre": "contexte", "titre": "GABI · " + str(page[1]).to_upper(), "texte": str(short.get("text", "")), "categorie": moment.categorie, "ton": moment.ton, "route": str(app.route), "visit": visit, "event": event}
	if _spontane_permis():
		_consommer(message)
		_montrer(message)
	else:
		_attente = message
		_maj_indice()

func _consommer(message: Dictionary) -> void:
	var visit := str(message.get("visit", ""))
	var event := str(message.get("event", ""))
	var changed := false
	if not visit.is_empty() and visit not in profile.data.seen: profile.data.seen.append(visit); changed = true
	if not event.is_empty() and event not in profile.data.events:
		profile.data.events.append(event); changed = true
		while profile.data.events.size() > Profile.EVENT_LIMIT: profile.data.events.pop_front()
	if message == _attente or (not _attente.is_empty() and _attente.get("texte") == message.get("texte")): _attente.clear()
	if changed: profile.save_profile(profile.data); _status()

## Limite de fréquence des interventions spontanées : une bulle ouverte d'office par jour de jeu.
func _spontane_permis() -> bool:
	var meta: Dictionary = app.model.get("meta", {}) if app.model.get("meta") is Dictionary else {}
	var day := str(meta.get("calendarToday", meta.get("date", ""))) + ":" + _career_context(app.model)
	if day != _jour_spontane: _jour_spontane = day; _spontanes = 0
	if _spontanes >= SPONTANE_PAR_JOUR or (_bulle.visible and _contenu.get("genre") != "fait"): return false
	_spontanes += 1
	return true

## Avant la validation d'une composition (jour de match) : si Gabi changerait quelqu'un, il le signale.
func _conseil_composition(route: String, model: Dictionary) -> void:
	if Avis.ecran(route, model) != "composition" or route == "Match" or not Avis._jour_de_match(model): return
	if _ecartes.has(_cle_conseil(route)) or (_bulle.visible and _contenu.get("genre") == "avis"): return
	var avis := Avis.composition(model)
	if avis.get("action", {}).is_empty(): return
	var message: Dictionary = avis.merged({"genre": "avis", "titre": "GABI · AVANT DE VALIDER", "route": route})
	if _attente.get("texte", "") == message.texte: return
	if _spontane_permis(): _montrer(message)
	else: _attente = message

## Humeur après un match : joie après une victoire, mine sombre après une défaite (une fois par match).
func _humeur(model: Dictionary) -> void:
	var humeur := Avis.humeur(model)
	if str(humeur.cle).is_empty() or humeur.cle == _humeur_cle: return
	var first := _humeur_cle.is_empty()
	_humeur_cle = humeur.cle
	if portrait.has_method("set_moment"):
		portrait.set_moment({"id": humeur.cle, "categorie": humeur.categorie if not first else "consigne", "ton": humeur.ton})
	if first: return  # Résultat déjà connu à l'ouverture de la partie : simple ton, sans réaction.
	var dernier := Avis.dernier_resultat(model)
	var texte: String = {
		"victoire": "On a gagné %d-%d contre %s. Savoure ce soir ; demain, on regarde ce qui a coincé, il y a toujours quelque chose.",
		"defaite": "On a perdu %d-%d contre %s. Pas de coupable ce soir : on en reparle demain, à froid, le carnet ouvert.",
		"nul": "Match nul, %d-%d contre %s. Ni fête ni drame : un point, ça se garde au chaud.",
	}.get(str(dernier.get("issue", "")), "")
	if texte.is_empty(): return
	_attente = {"genre": "humeur", "titre": "GABI · APRÈS LE MATCH", "texte": texte % [dernier.pour, dernier.contre, dernier.adversaire], "categorie": humeur.categorie, "ton": humeur.ton, "route": str(app.route), "partout": true}

func _maj_indice() -> void:
	if not is_instance_valid(_medaillon): return
	if not _attente.is_empty() and _attente.get("partout", false): _attente.route = str(app.route)
	if not _attente.is_empty() and _attente.get("route") != str(app.route) and not _attente.get("partout", false):
		# Le message d'un écran ne suit pas le coach ailleurs : il revient à la prochaine visite.
		_attente.clear()
	_medaillon.indice = not _attente.is_empty() and not _bulle.visible

func refresh() -> void:
	var moment := _moment_courant if expanded and mode == "context" else ""
	super.refresh()
	if not moment.is_empty() and not expanded and moment in profile.data.events:
		# Fermé par une fenêtre ou un blocage, pas par le coach : le moment reviendra.
		profile.data.events.erase(moment)
		profile.save_profile(profile.data)
		_contexte_examine = ""
	if not expanded: _moment_courant = ""
	if is_instance_valid(_medaillon):
		_avis_bouton.disabled = not _safe
		_maj_indice()

func _show_context(id: String, fragment: Dictionary) -> void:
	fermer_bulle()
	super._show_context(id, fragment)

func _open() -> void:
	fermer_bulle()
	super._open()

func _avoid_primary_controls() -> void:
	# Mode grand : une courte scène, écran assombri ; Gabi reste au-dessus de son coin.
	if is_instance_valid(_medaillon) and _adjoint_actif(): return
	super._avoid_primary_controls()

func destroy() -> void:
	if is_instance_valid(_voile): _voile.queue_free()
	super.destroy()
