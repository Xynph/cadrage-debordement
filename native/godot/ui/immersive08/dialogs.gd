extends RefCounted
## Habillage des fenêtres natives. La propriété des signaux reste chez l'appelant.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const G = preload("res://ui/game_skin.gd")

static func prepare(dialog: AcceptDialog, width: int, accent: Color) -> void:
	dialog.theme = Legacy.theme(accent)
	dialog.min_size = Vector2i(width,0)
	dialog.set_meta("immersive_dialog_minimum",dialog.min_size)
	dialog.dialog_autowrap = true
	dialog.visibility_changed.connect(_dress.bind(dialog,accent))
	dialog.tree_entered.connect(_watch_host.bind(dialog))

static func watch_file_picker(dialog: FileDialog) -> void:
	dialog.visibility_changed.connect(func():
		if dialog.visible: _fit.call_deferred(dialog))
	_watch_host(dialog)

static func show_centered(dialog: AcceptDialog, requested: Vector2i) -> void:
	# Fenêtre adoptée par une sous-page (recruitment_pages.gd) : son contenu est affiché dans la page, jamais en fenêtre.
	if dialog.get_meta("en_page", false): return
	dialog.set_meta("immersive_dialog_size",requested)
	# Une fenêtre intégrée plus grande que son hôte serait centrée à une position négative (le moteur journalise
	# « Window spawned at invalid position ») avant le recadrage différé de _fit : on la borne d'abord à l'hôte.
	var popup_size := requested
	var host := dialog.get_parent()
	if host != null and host.get_viewport() != null:
		var visible_size := Vector2i(host.get_viewport().get_visible_rect().size)
		# Mêmes marges et même garde que _fit : en dessous de 720 x 520, le recadrage différé ne s'applique pas.
		if visible_size.x >= 720 and visible_size.y >= 520:
			var preferred_minimum: Vector2i = dialog.get_meta("immersive_dialog_minimum",dialog.min_size)
			dialog.min_size = Vector2i(mini(preferred_minimum.x,visible_size.x-28),mini(preferred_minimum.y,visible_size.y-68))
			popup_size = Vector2i(mini(requested.x,visible_size.x-28),mini(requested.y,visible_size.y-68))
	dialog.popup_centered(popup_size)
	_fit.call_deferred(dialog)

static func _dress(dialog: AcceptDialog, accent: Color) -> void:
	if not dialog.visible: return
	for child in dialog.get_children():
		if child is Control and not child.get_meta("immersive_style_applied",false): Legacy.apply(child,accent)
	# Charte : l'action de la fenêtre est sa seule action principale (pilule dorée, texte PANNEAU) ; Annuler et les
	# autres boutons gardent la pilule à contour du thème (legacy_style).
	var action := dialog.get_ok_button()
	C.style_bouton_ivoire_plein(action,20)
	var cancel: Button = (dialog as ConfirmationDialog).get_cancel_button() if dialog is ConfirmationDialog else null
	if cancel != null: C.style_bouton_contour(cancel,20)
	var message := dialog.get_label()
	message.add_theme_color_override("font_color",C.IVORY)
	message.add_theme_font_override("font",C.BODY)
	message.add_theme_font_size_override("font_size",maxi(14,C.px(18)))
	_fit.call_deferred(dialog)

## Barre de titre et cadre d'une fenêtre intégrée aux couleurs des cartes du jeu (au lieu du gris par défaut de Godot).
## Les marges (dont la hauteur de la barre de titre) restent celles du style d'origine : la mise en page ne bouge pas.
static func dress_title(dialog: Window) -> void:
	for state in ["embedded_border","embedded_unfocused_border"]:
		var original := dialog.get_theme_stylebox(state,"Window")
		# Charte : panneau PANNEAU rayon 18 (24 au gabarit 2560), sans bordure, ombre des jetons.
		var style := C.box(C.PANEL,Color.TRANSPARENT,24,0)
		style.set_content_margin(SIDE_LEFT,original.get_margin(SIDE_LEFT))
		style.set_content_margin(SIDE_RIGHT,original.get_margin(SIDE_RIGHT))
		style.set_content_margin(SIDE_TOP,original.get_margin(SIDE_TOP))
		style.set_content_margin(SIDE_BOTTOM,original.get_margin(SIDE_BOTTOM))
		style.expand_margin_top = original.expand_margin_top
		dialog.add_theme_stylebox_override(state,style)
	dialog.add_theme_color_override("title_color",C.GOLD)
	dialog.add_theme_font_override("title_font",C.BOLD)
	dialog.set_meta("immersive_title_dressed",true)

static func _watch_host(dialog: AcceptDialog) -> void:
	var owner: Viewport = dialog.get_parent().get_viewport()
	var resize := func(): _fit(dialog)
	owner.size_changed.connect(resize,CONNECT_DEFERRED)
	dialog.tree_exiting.connect(func():
		if is_instance_valid(owner) and owner.size_changed.is_connected(resize): owner.size_changed.disconnect(resize),CONNECT_ONE_SHOT)

static func _fit(dialog: AcceptDialog) -> void:
	if not is_instance_valid(dialog) or not dialog.is_inside_tree() or not dialog.visible or not dialog.is_embedded(): return
	var tree := dialog.get_tree()
	# Autowrapped labels can briefly report a narrow, very tall minimum before
	# the viewport has laid out the real requested width.
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(dialog) or not dialog.is_inside_tree() or not dialog.visible: return
	var screen := Vector2i(dialog.get_parent().get_viewport().get_visible_rect().size)
	if screen.x<720 or screen.y<520: return
	var file_picker := dialog is FileDialog
	var target: Vector2i = dialog.get_meta("immersive_dialog_size",dialog.size)
	# Les sélecteurs peuvent se replier à leur minimum avant le layout de leur liste.
	if file_picker: target = Vector2i((Vector2(screen) * .7).round())
	# A requested width is a preferred minimum, not a reason to escape the host.
	# Restore it when the host grows again; content controls retain their own minima.
	var preferred_minimum: Vector2i = dialog.get_meta("immersive_dialog_minimum",dialog.min_size)
	dialog.min_size = Vector2i(mini(preferred_minimum.x,screen.x-28),mini(preferred_minimum.y,screen.y-68))
	target.x=min(target.x,screen.x-28)
	target.y=min(target.y,screen.y-68)
	if target!=dialog.size: dialog.size=target
	var available := screen-dialog.size
	var title_height := 0 if dialog.borderless else dialog.get_theme_constant("title_height", "Window")
	var minimum_top := maxi(30,title_height)
	if available.x<0 or available.y<minimum_top: return
	if file_picker or dialog.has_meta("immersive_dialog_size") or dialog.position.x<0 or dialog.position.y<minimum_top or dialog.position.x>available.x or dialog.position.y>available.y:
		dialog.position=(available+Vector2i(0,title_height))/2

static func pause_content(dialog: AcceptDialog, app: Control) -> void:
	var body := C.v(13)
	body.set_meta("immersive_style_applied",true)
	body.custom_minimum_size.x = 734
	dialog.add_child(body)
	var context := C.card("LE CARNET DE CARRIÈRE")
	body.add_child(context)
	var row := C.h(18)
	C.content(context).add_child(row)
	var club: Dictionary = app.model.get("club") if app.model.get("club") is Dictionary else {}
	if not club.is_empty(): row.add_child(G.crest(club,maxi(56,C.px(72))))
	var copy := C.v(5)
	C.fill(copy)
	row.add_child(copy)
	var meta: Dictionary = app.model.get("meta",{})
	copy.add_child(C.wrap(G.club_name(club) if not club.is_empty() else "Profil de jeu",32,C.IVORY,true,700))
	copy.add_child(C.wrap("Saison %s · %s" % [G.season_label(meta.get("season","—")),str(meta.get("roundLabel","Carrière locale"))],20,C.GOLD,true,600))
	var storage := C.card("PROFIL ET SAUVEGARDES")
	body.add_child(storage)
	var details := C.content(storage)
	details.add_child(C.wrap("Sauvegarde automatique dans un profil indépendant.",19,C.IVORY))
	var profile := C.wrap(app._profile_path(),16,C.MUTED)
	profile.tooltip_text=app._profile_path()
	details.add_child(profile)
	if app._status_has_error(): details.add_child(C.wrap(app._settled_status_text(),18,C.ALERT))
	dialog.get_ok_button().text="Retour au jeu"
