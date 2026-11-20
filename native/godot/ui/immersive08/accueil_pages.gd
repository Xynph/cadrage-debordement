extends RefCounted
## Sous-pages de l'Accueil (« jamais de petite fenêtre » : un clic change d'écran) : Paramètres, Crédits et Mes carrières
## remplacent les anciennes fenêtres. Elles se montrent dans l'écran d'accueil (même photo, même voile) avec « ← Accueil »
## et Échap pour revenir. L'état est une méta de l'application (`accueil_sub`), effacée dès qu'on quitte l'Accueil.
## Exemple : `Pages.ouvrir(app, "credits")` ouvre les crédits ; `Pages.fermer(app)` revient au menu principal.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const Credits = preload("res://ui/credits_view.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
const Entry = preload("res://ui/entry_screens.gd")
const Preferences = preload("res://ui/preferences_dialog.gd")
const Slots = preload("res://ui/career_slots_view.gd")
const META := "accueil_sub"
const TITRES := {"parametres": "Paramètres", "credits": "Crédits et licences", "carrieres": "Mes carrières"}

## Retour au menu : Échap, sans autre effet sur l'écran.
class Echap extends Node:
	var retour: Callable
	func _unhandled_key_input(event: InputEvent) -> void:
		var touche := event as InputEventKey
		if touche != null and touche.pressed and not touche.echo and touche.keycode == KEY_ESCAPE and retour.is_valid():
			get_viewport().set_input_as_handled()
			retour.call()

static func courante(app: Control) -> String:
	var quoi := str(app.get_meta(META, ""))
	return quoi if TITRES.has(quoi) else ""

static func ouvrir(app: Control, quoi: String) -> void:
	app.set_meta(META, quoi)
	app._render()

static func fermer(app: Control) -> void:
	if app.has_meta(META): app.remove_meta(META)
	app._render()

## Nouvelle carrière alors qu'une autre est en cours : l'ancienne est rangée dans « Mes carrières », puis le choix du club s'ouvre.
static func nouvelle_carriere(app: Control) -> void:
	if app.waiting: return
	app.bridge.career_slots_changed.connect(func(_slots: Dictionary):
		liberer(app)
		if app.bridge.last_response_ok: Entry.begin_creation(app), CONNECT_ONE_SHOT)
	app._command("career_slots", {"action": "new"})

## Sans carrière, le moteur répond « career_slots » sans modèle : l'attente de l'application ne se lèverait jamais.
static func liberer(app: Control) -> void:
	if app.waiting and str(app.last_command) == "career_slots" and app.bridge.last_response_ok: app.waiting = false

static func remplir(app: Control, page: Control, quoi: String) -> void:
	var marge := MarginContainer.new()
	marge.name = "AccueilSousPage_" + quoi
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_theme_constant_override("margin_left", C.px(128))
	marge.add_theme_constant_override("margin_right", C.px(128))
	marge.add_theme_constant_override("margin_top", C.px(96))
	marge.add_theme_constant_override("margin_bottom", C.px(96))
	page.add_child(marge)
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonne := C.v(16)
	marge.add_child(colonne)
	var retour := Button.new()
	retour.name = "AccueilRetour"
	retour.text = "← Accueil"
	retour.focus_mode = Control.FOCUS_ALL
	retour.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	retour.pressed.connect(func(): fermer(app))
	C.style_bouton_lien(retour, 24, true)
	colonne.add_child(retour)
	var titre := Label.new()
	titre.text = str(TITRES[quoi]).to_upper()
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	titre.add_theme_font_size_override("font_size", C.font_px(72))
	titre.add_theme_color_override("font_color", Charte.IVOIRE)
	colonne.add_child(titre)
	var surface := PanelContainer.new()
	surface.name = "AccueilSurface"
	surface.set_meta("immersive_style_applied", true)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(Charte.PANNEAU, .96)
	fond.set_corner_radius_all(Charte.RAYON_PANNEAU)
	for bord in ["left", "right", "top", "bottom"]: fond.set("content_margin_" + bord, C.px(32))
	surface.add_theme_stylebox_override("panel", Charte.ombrer(fond))
	C.fill(surface, true)
	colonne.add_child(surface)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	surface.add_child(defile)
	var contenu: Control
	match quoi:
		"parametres": contenu = Preferences.page(app, app.user_preferences)
		"credits": contenu = _credits()
		_: contenu = Carrieres.new(app)
	C.fill(contenu)
	defile.add_child(contenu)
	var echap := Echap.new()
	echap.retour = func(): fermer(app)
	page.add_child(echap)
	retour.ready.connect(func(): (func(): if is_instance_valid(retour) and retour.is_inside_tree(): retour.grab_focus()).call_deferred(), CONNECT_ONE_SHOT)

static func _credits() -> Control:
	var texte := RichTextLabel.new()
	texte.name = "CreditsText"
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.scroll_active = false
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.add_theme_font_override("normal_font", C.BODY)
	texte.add_theme_font_override("bold_font", C.BOLD)
	texte.add_theme_font_size_override("normal_font_size", C.font_px(24))
	texte.add_theme_font_size_override("bold_font_size", C.font_px(24))
	texte.add_theme_color_override("default_color", Charte.IVOIRE)
	texte.text = Credits.bbcode(Credits.load_data())
	return texte

## « Mes carrières » (native/engine/career-slots.cjs) : la carrière en cours, les carrières rangées, ouvrir ou supprimer
## (confirmation en place), nouvelle carrière. Le moteur enregistre la carrière ouverte avant chaque changement.
class Carrieres extends VBoxContainer:
	var _app: Control
	var _pending := ""
	var _etat: Label
	func _init(app: Control) -> void:
		_app = app
		name = "AccueilCarrieres"
		add_theme_constant_override("separation", C.px(14))
	func _ready() -> void:
		_app.bridge.career_slots_changed.connect(_on_slots)
		_app.bridge.command_failed.connect(_on_failure)
		_render()
		_app._command("career_slots", {"action": "list"})
	func _exit_tree() -> void:
		if is_instance_valid(_app) and _app.bridge != null:
			if _app.bridge.career_slots_changed.is_connected(_on_slots): _app.bridge.career_slots_changed.disconnect(_on_slots)
			if _app.bridge.command_failed.is_connected(_on_failure): _app.bridge.command_failed.disconnect(_on_failure)
	func _lien(parent: Container, texte: String, nom: String, appel: Callable) -> Button:
		var bouton := Button.new()
		bouton.name = nom
		bouton.text = texte + " →"
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bouton.pressed.connect(appel)
		C.style_bouton_lien(bouton, 24)
		bouton.disabled = _app.waiting or not _pending.is_empty()
		parent.add_child(bouton)
		return bouton
	func _carte(entry: Dictionary, en_cours: bool) -> VBoxContainer:
		var cadre := PanelContainer.new()
		cadre.set_meta("immersive_style_applied", true)
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_2
		style.set_corner_radius_all(Charte.RAYON_CARTE)
		if en_cours:
			style.border_color = Charte.IVOIRE
			style.border_width_left = maxi(2, C.px(4))
		for bord in ["left", "right", "top", "bottom"]: style.set("content_margin_" + bord, C.px(22))
		cadre.add_theme_stylebox_override("panel", Charte.ombrer(style))
		add_child(cadre)
		var pile := C.v(8)
		cadre.add_child(pile)
		pile.add_child(C.label(str(entry.get("club", "Carrière")) + ("  ·  en cours" if en_cours else ""), 40, Charte.IVOIRE, true, 700))
		pile.add_child(C.wrap(Slots.describe(entry), 22, Charte.IVOIRE_2, false, 500))
		return pile
	func _render() -> void:
		for enfant in get_children():
			remove_child(enfant)
			enfant.queue_free()
		var slots: Dictionary = _app.bridge.career_slots
		add_child(C.wrap("Chaque carrière garde sa progression. Ta carrière en cours est enregistrée avant d'en ouvrir une autre ou d'en commencer une nouvelle.", 24, Charte.IVOIRE_2, false, 500))
		var actuelle: Variant = slots.get("active")
		if actuelle is Dictionary: _carte(actuelle, true)
		var rangees: Array = slots.get("saved", [])
		for entry: Dictionary in rangees:
			var pile := _carte(entry, false)
			var actions := C.h(28)
			pile.add_child(actions)
			var id := str(entry.id)
			_lien(actions, "Ouvrir cette carrière", "CareerSlotsOpen_" + id, func(): _envoyer("open", {"id": id}, "Enregistrement de ta carrière en cours, puis ouverture…", "Réception"))
			_lien(actions, "Supprimer", "CareerSlotsRemove_" + id, func(): _confirmer(pile, entry))
		if not actuelle is Dictionary and rangees.is_empty() and not slots.is_empty():
			add_child(C.wrap("Aucune carrière enregistrée pour l'instant.", 24, Charte.IVOIRE_2, false, 500))
		_lien(self, "Nouvelle carrière", "CareerSlotsNew", func(): _envoyer("new", {}, "Enregistrement de ta carrière en cours…"))
		_etat = C.wrap("", 22, Charte.IVOIRE_2, false, 500)
		_etat.name = "CareerSlotsStatus"
		add_child(_etat)
	func _envoyer(action: String, charge: Dictionary, message: String, route := "") -> void:
		if _app.waiting or not _pending.is_empty(): return
		_pending = action
		for bouton in find_children("*", "Button", true, false): (bouton as Button).disabled = true
		_etat.text = message
		var demande := charge.duplicate()
		demande["action"] = action
		if not _app._command("career_slots", demande, route): _on_failure("Commande non transmise ; rien n'a changé.")
	func _confirmer(pile: Control, entry: Dictionary) -> void:
		if _app.waiting or not _pending.is_empty(): return
		EnPlace.ouvrir(_app, pile, "CareerSlotsConfirm", "Supprimer cette carrière ?", [
			"%s (%s) sera supprimée définitivement." % [str(entry.get("club", "Cette carrière")), Slots.describe(entry)],
			"Tes autres carrières sont conservées."], "Supprimer", func(): _envoyer("delete", {"id": str(entry.id), "confirmed": true}, "Suppression…"))
	func _on_slots(_slots: Dictionary) -> void:
		if _app.waiting and str(_app.last_command) == "career_slots" and _app.bridge.last_response_ok: _app.waiting = false
		var fait := _pending
		_pending = ""
		if fait in ["open", "new"] and _app.bridge.last_response_ok:
			if fait == "new": Entry.begin_creation(_app)
			return
		_render()
		if fait == "delete": _etat.text = "Carrière supprimée."
	func _on_failure(message: String) -> void:
		if _pending.is_empty(): return
		_pending = ""
		_render()
		_etat.text = message
		_etat.add_theme_color_override("font_color", Charte.D)
