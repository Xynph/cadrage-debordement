extends RefCounted
## Habillage des fenêtres natives. La propriété des signaux reste chez l'appelant.
const C = preload("res://ui/immersive08/components.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")

static func prepare(dialog: AcceptDialog, width: int, accent: Color) -> void:
	dialog.theme = Legacy.theme(accent)
	dialog.min_size = Vector2i(width,0)
	dialog.dialog_autowrap = true
	dialog.visibility_changed.connect(_dress.bind(dialog,accent))
	dialog.tree_entered.connect(_watch_host.bind(dialog))

static func watch_file_picker(dialog: FileDialog) -> void:
	dialog.visibility_changed.connect(func():
		if dialog.visible: _fit.call_deferred(dialog))
	_watch_host(dialog)

static func show_centered(dialog: AcceptDialog, requested: Vector2i) -> void:
	dialog.set_meta("immersive_dialog_size",requested)
	dialog.popup_centered(requested)
	_fit.call_deferred(dialog)

static func _dress(dialog: AcceptDialog, accent: Color) -> void:
	if not dialog.visible: return
	for child in dialog.get_children():
		if child is Control and not child.get_meta("immersive_style_applied",false): Legacy.apply(child,accent)
	var action := dialog.get_ok_button()
	action.add_theme_font_override("font",C.BOLD)
	action.add_theme_color_override("font_color",C.IVORY)
	action.add_theme_stylebox_override("normal",C.box(accent.darkened(.37),P.safe_accent(accent),5,12))
	action.add_theme_stylebox_override("hover",C.box(accent.darkened(.14),C.IVORY,5,12))
	action.add_theme_stylebox_override("pressed",C.box(accent.darkened(.54),C.MINT,5,12))
	var message := dialog.get_label()
	message.add_theme_color_override("font_color",C.IVORY)
	message.add_theme_font_override("font",C.BODY)
	message.add_theme_font_size_override("font_size",maxi(14,C.px(18)))
	_fit.call_deferred(dialog)

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
	copy.add_child(C.wrap("Saison %s · %s" % [G.n(meta.get("season","—")),str(meta.get("roundLabel","Carrière locale"))],20,C.GOLD,true,600))
	var storage := C.card("PROFIL ET SAUVEGARDES")
	body.add_child(storage)
	var details := C.content(storage)
	details.add_child(C.wrap("Sauvegarde automatique dans un profil indépendant.",19,C.IVORY))
	var profile := C.wrap(app._profile_path(),16,C.MUTED)
	profile.tooltip_text=app._profile_path()
	details.add_child(profile)
	if app._status_has_error(): details.add_child(C.wrap(app._settled_status_text(),18,C.ALERT))
	dialog.get_ok_button().text="Retour au jeu"
