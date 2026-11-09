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
