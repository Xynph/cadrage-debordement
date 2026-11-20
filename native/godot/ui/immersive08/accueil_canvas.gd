extends RefCounted
## Accueil « Affiche et carnet » (maquette 01, choix de Léo du 19/11/2026) : l'affiche (logo, accroche, photo du club
## ou du stade) à gauche, le carnet à droite. Deux états : « carrière en cours » (bouton de reprise en or, seule
## exception hors coque : c'est Continuer) et « première fois » (emprunt de la maquette 2 : Nouvelle carrière en
## ivoire plein). La ligne du lieu (maquette 3) donne le stade du club, lu dans ses données, jamais figé.
## Tout ce qui a l'air cliquable agit : liens soulignés vers un écran, classement et prochain match vers leur page.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const Club = preload("res://ui/club_views.gd")
const Entry = preload("res://ui/entry_screens.gd")
const G = preload("res://ui/game_skin.gd")
const Pages = preload("res://ui/immersive08/accueil_pages.gd")
const Shell = preload("res://ui/immersive08/shell.gd")
const MARQUE = preload("res://branding/rugby-legacy-27-logo.png")
const JOURS := ["dim.", "lun.", "mar.", "mer.", "jeu.", "ven.", "sam."]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

## Marqueur incliné de 10° (charte §3) à gauche du carnet de carrière.
class Marqueur extends Control:
	var teinte := Color.WHITE
	func _draw() -> void:
		var decalage := Charte.decalage(size.y)
		draw_colored_polygon(PackedVector2Array([Vector2(decalage, 0), Vector2(decalage + size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), teinte)

static func home(app: Control, nom_jeu: String = "RUGBY LEGACY 27") -> Control:
	var window := app.get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	C.configure(window.size.y, window.size.x)
	var club: Dictionary = app.model.get("club") if app.model.get("club") is Dictionary else {}
	var meta: Dictionary = app.model.get("meta", {}) if app.model.get("meta") is Dictionary else {}
	var page := Control.new()
	page.name = "CarnetHome"
	var fond := ColorRect.new()
	fond.color = Charte.NUIT
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(fond)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var photo := C.photo("titre-principal" if BanqueImages.existe("titre-principal") else "entry-ground")
	photo.tooltip_text = ""
	page.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_voile(page)
	var sous_page := Pages.courante(app)
	if not sous_page.is_empty():
		Pages.remplir(app, page, sous_page)
		return page
	var content := MarginContainer.new()
	content.name = "ImmersiveWelcome"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Marge gauche et haute ≥ moitié de la hauteur du « 27 » du logo (charte §8.1 : logo 1160 → 329 de haut).
	content.add_theme_constant_override("margin_left", C.px(168))
	content.add_theme_constant_override("margin_right", C.px(128))
	content.add_theme_constant_override("margin_top", C.px(168))
	content.add_theme_constant_override("margin_bottom", C.px(96))
	page.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var colonnes := C.h(48)
	colonnes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(colonnes)
	colonnes.add_child(C.fill(_affiche(app, club, meta, nom_jeu)))
	var droite := C.v(0)
	droite.custom_minimum_size.x = C.px(760)
	droite.alignment = BoxContainer.ALIGNMENT_BEGIN
	colonnes.add_child(droite)
	var carnet := _carnet(app, club, meta)
	droite.add_child(carnet)
	# Crédits en haut à droite, comme sur la maquette.
	var credits := Button.new()
	credits.name = "EntryCredits"
	credits.text = "Crédits"
	credits.focus_mode = Control.FOCUS_ALL
	credits.pressed.connect(func(): Pages.ouvrir(app, "credits"))
	C.style_bouton_lien(credits, 20, true)
	page.add_child(credits)
	credits.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	credits.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credits.offset_right = -C.px(128)
	credits.offset_top = C.px(64)
	# Pied : le lieu (stade du club) et l'aide au clavier.
	var pied := C.h(24)
	pied.name = "EntryFooter"
	pied.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(pied)
	pied.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pied.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pied.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pied.offset_right = -C.px(128)
	pied.offset_bottom = -C.px(48)
	# Gabi (« Gabi · ? » et « Visite ») se pose dans ce pied, jamais au milieu de l'écran sur les liens.
	var emplacement := Control.new()
	emplacement.name = "CoachCompactDock"
	# Taille réelle, non mise à l'échelle : les pastilles de Gabi gardent leur taille propre (comme le pied des autres écrans).
	emplacement.custom_minimum_size = Vector2(210, 36)
	emplacement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emplacement.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pied.add_child(emplacement)
	var lieu := str(club.get("stadium", ""))
	if not lieu.is_empty():
		var ligne := C.label(lieu, 18, Charte.IVOIRE, false, 500)
		ligne.name = "EntryPlace"
		pied.add_child(ligne)
	pied.add_child(C.label("↑↓ choisir · Entrée valider", 18, Charte.IVOIRE_2, false, 500))
	return page

## Voile de lisibilité sur la photo : noir du logo à gauche, photo qui apparaît vers la droite.
static func _voile(page: Control) -> void:
	var rampe := Gradient.new()
	rampe.set_color(0, Color(Charte.NUIT, .97))
	rampe.add_point(.36, Color(Charte.NUIT, .9))
	rampe.add_point(.62, Color(Charte.NUIT, .3))
	rampe.set_color(rampe.get_point_count() - 1, Color(Charte.NUIT, .55))
	var texture := GradientTexture2D.new()
	texture.gradient = rampe
	texture.fill_to = Vector2.RIGHT
	var voile := TextureRect.new()
	voile.texture = texture
	voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _police(texte: String, taille: int, couleur: Color, police: Font) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_override("font", police)
	etiquette.add_theme_font_size_override("font_size", C.font_px(taille))
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.set_meta("immersive_style_applied", true)
	return etiquette

## Affiche : logo du jeu, puis accroche en bas. Le logo est le jeu de couleurs de référence (charte).
static func _affiche(_app: Control, _club: Dictionary, _meta: Dictionary, nom_jeu: String) -> Control:
	var colonne := C.v(0)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := TextureRect.new()
	logo.name = "EntryLogo"
	logo.texture = MARQUE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.tooltip_text = nom_jeu.capitalize()
	logo.accessibility_name = nom_jeu
	# Cadre au ratio réel de la texture (≈ 3,5:1), ni écrasé ni rogné ; logo définitif transparent, sans clé de noir.
	var largeur := C.px(1160)
	var ratio := float(MARQUE.get_width()) / maxf(1.0, float(MARQUE.get_height()))
	logo.custom_minimum_size = Vector2(largeur, roundf(largeur / ratio))
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(logo)
	# Marge sous le logo : moitié de la hauteur du « 27 ».
	var marge_logo := Control.new()
	marge_logo.custom_minimum_size.y = roundf(largeur / ratio * 0.5)
	marge_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(marge_logo)
	colonne.add_child(C.fill(Control.new(), true))
	colonne.add_child(_police("CARRIÈRE DE MANAGER · RUGBY À XV · ÉDITION %s" % OS.get_name().to_upper(), 18, Charte.IVOIRE_2, Charte.TITRE_GRAS))
	var filet := ColorRect.new()
	filet.color = Charte.IVOIRE
	filet.custom_minimum_size = Vector2(C.px(96), maxi(2, C.px(4)))
	filet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var espace := Control.new()
	espace.custom_minimum_size.y = C.px(14)
	colonne.add_child(espace)
	colonne.add_child(filet)
	var accroche := _police("UN CLUB. UN TERRITOIRE.\nUNE SAISON À ÉCRIRE.", 56, Charte.IVOIRE, Charte.TITRE_EXTRA_ITALIQUE)
	accroche.name = "EntryTagline"
	accroche.add_theme_constant_override("line_spacing", -C.px(10))
	colonne.add_child(accroche)
	var suite := C.wrap("Prends les rênes. Prépare le XV, fais grandir le club et vis la saison.", 21, Charte.IVOIRE_2, false, 500)
	colonne.add_child(suite)
	return colonne

## `rayon` en référence 2560 (24 → 18 px à 1920, 16 → 12 px) ; Charte.RAYON_PILULE reste une pilule.
static func _plat(couleur: Color, marge: int, rayon: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.anti_aliasing = true
	style.set_corner_radius_all(rayon if rayon >= Charte.RAYON_PILULE else maxi(0, C.px(rayon)))
	style.set_border_width_all(0)
	for bord in ["left", "right", "top", "bottom"]: style.set("content_margin_" + bord, C.px(marge))
	return style

static func _carnet(app: Control, club: Dictionary, meta: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "EntryCareerCard"
	carte.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU, 34, 24))
	carte.set_meta("immersive_style_applied", true)
	var pile := C.v(14)
	carte.add_child(pile)
	var en_cours := not club.is_empty()
	var verrou: bool = app.model.is_empty() or meta.get("recoveryRequired", false)
	pile.add_child(_police("OUVRIR LE CARNET" if en_cours else "PREMIÈRE CARRIÈRE", 18, Charte.IVOIRE_2, Charte.TITRE_GRAS))
	var titre := _police("TON PROCHAIN CHAPITRE" if en_cours else "UNE SAISON À ÉCRIRE", 40, Charte.IVOIRE, Charte.TITRE_EXTRA_ITALIQUE)
	titre.name = "EntryCardTitle"
	pile.add_child(titre)
	if en_cours:
		pile.add_child(_identite(app, club, meta))
		var lecture := _lecture(app, club, meta)
		if lecture != null: pile.add_child(lecture)
		var sauvegarde := Shell.save_caption(app)
		var trace := C.label("✓ " + str(sauvegarde[0]), 18, sauvegarde[1], false, 500)
		trace.name = "EntrySaveLine"
		pile.add_child(trace)
	else:
		pile.add_child(C.wrap("Choisis un club, prends les rênes et lance la première journée.", 21, Charte.IVOIRE_2, false, 500))
		var monde := _ligne_monde(app)
		if monde != null: pile.add_child(monde)
	var principal: Button
	if en_cours:
		principal = _principal_or("REPRENDRE LA CARRIÈRE", func(): app._navigate("Réception"), "EntryResume")
	else:
		principal = Button.new()
		principal.name = "EntryNewCareer"
		principal.text = "NOUVELLE CARRIÈRE"
		principal.pressed.connect(func(): Entry.begin_creation(app))
		C.style_bouton_ivoire_plein(principal, 34)
		principal.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
		principal.alignment = HORIZONTAL_ALIGNMENT_LEFT
		principal.custom_minimum_size.y = C.px(88)
		principal.disabled = verrou or app.catalogue.is_empty()
		_rappel_entree(principal)
	pile.add_child(principal)
	var raisons: Array[String] = []
	if not en_cours and principal.disabled:
		raisons.append("Nouvelle carrière indisponible : %s" % ("le profil doit d'abord être récupéré." if verrou else "aucun club à choisir, charge un pack dans « Identités et packs »."))
	var liens := C.v(0)
	pile.add_child(liens)
	if en_cours:
		var creer := _lien(liens, "Nouvelle carrière", func(): Pages.nouvelle_carriere(app), "EntryNewCareer")
		creer.disabled = verrou or app.catalogue.is_empty()
		if creer.disabled: raisons.append("Nouvelle carrière indisponible : %s" % ("le profil doit d'abord être récupéré." if verrou else "aucun club à choisir, charge un pack dans « Identités et packs »."))
	var carrieres := _lien(liens, "Mes carrières", func(): Pages.ouvrir(app, "carrieres"), "EntryCareerSlots")
	carrieres.disabled = verrou
	var importer := _lien(liens, "Importer une carrière", func(): app.open_file(true), "EntryImportCareer")
	importer.disabled = verrou
	var rangee := C.h(16)
	liens.add_child(rangee)
	C.fill(_lien(rangee, "Paramètres", func(): Pages.ouvrir(app, "parametres"), "EntrySettings"))
	C.fill(_lien(rangee, "Quitter", app.request_quit, "EntryQuit"))
	# Identités et packs : lien discret, souligné au repos.
	var manquants: Array = app.model.get("packs", {}).get("missing", [])
	var creation_absente := manquants.any(func(avis: String): return avis.begins_with("Pack de création absent"))
	var carriere_absente := manquants.any(func(avis: String): return avis.begins_with("Pack de carrière absent"))
	var portee := "creation" if not en_cours or (creation_absente and not carriere_absente) else "career"
	var packs := Button.new()
	packs.name = "EntryPacks"
	packs.text = "Identités et packs"
	packs.focus_mode = Control.FOCUS_ALL
	packs.pressed.connect(func(): app.pack_manager.open(portee))
	C.style_bouton_lien(packs, 19, true)
	packs.disabled = app.model.is_empty()
	packs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pile.add_child(packs)
	if packs.disabled: raisons.append("Identités et packs indisponible : le profil s'ouvre…")
	for raison: String in raisons:
		var note := C.wrap(raison, 18, Charte.IVOIRE_3, false, 500)
		note.name = "EntryDisabledReason"
		pile.add_child(note)
	for avis: String in manquants:
		pile.add_child(C.wrap(avis + " · Réimporte le pack dans Identités et packs.", 19, Charte.D))
	var legacy := str(meta.get("legacyPurgeNotice", ""))
	if not legacy.is_empty(): pile.add_child(C.wrap(legacy, 18, Charte.IVOIRE_2, false, 500))
	if meta.get("recoveryRequired", false):
		pile.add_child(C.wrap("Le profil ne peut pas être chargé. Sa copie sera conservée avant récupération.", 19, Charte.D))
		_lien(pile, "Récupérer le profil", app.recover_profile, "EntryRecover")
	elif app.connection_error:
		pile.add_child(C.wrap(app.last_error, 19, Charte.D))
		_lien(pile, "Réessayer la connexion", app.reconnect, "EntryReconnect")
	elif not app.last_error.is_empty(): pile.add_child(C.wrap(app.last_error, 19, Charte.D))
	elif app.model.is_empty(): pile.add_child(C.wrap("Ouverture du profil…", 19, Charte.IVOIRE_2, false, 500))
	principal.ready.connect(func(): (func(): if is_instance_valid(principal) and principal.is_inside_tree(): principal.grab_focus()).call_deferred(), CONNECT_ONE_SHOT)
	return carte

## Bloc d'identité : marqueur incliné, écusson du club, nom, saison · division · journée.
static func _identite(app: Control, club: Dictionary, meta: Dictionary) -> Control:
	var national: bool = app.Immersive.Selections.nation_only(app.model)
	var equipe: Dictionary = app.Immersive.Selections.managed_team(app.model)
	var bloc := PanelContainer.new()
	bloc.name = "EntryIdentity"
	bloc.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU_2, 18, 16))
	var rangee := C.h(20)
	bloc.add_child(rangee)
	var marqueur := Marqueur.new()
	marqueur.teinte = Charte.club_trait(app.accent)
	marqueur.custom_minimum_size = Vector2(C.px(10), C.px(120))
	rangee.add_child(marqueur)
	rangee.add_child(app.Immersive.Selections.nation_badge(equipe, C.px(88)) if national else G.crest(club, C.px(88)))
	var texte := C.v(4)
	C.fill(texte)
	rangee.add_child(texte)
	texte.add_child(C.label("CARRIÈRE EN COURS", 17, Charte.IVOIRE_2, true, 700))
	var nom := _police(str(equipe.get("name", "Sélection")) if national else G.club_name(club), 40, Charte.IVOIRE, Charte.TITRE_GRAS)
	nom.name = "EntryClubName"
	texte.add_child(nom)
	var morceaux: Array[String] = ["Saison %s" % G.season_label(meta.get("season", 1))]
	var division: String = app._wait_division() if app.has_method("_wait_division") else ""
	if division.is_empty() and not national and not str(club.get("division", "")).is_empty(): division = Club.competition_name(str(club.division), app.model)
	var tour := str(meta.get("roundLabel", ""))
	# Le libellé de journée porte parfois déjà la division : jamais deux fois.
	if not division.is_empty() and not tour.contains(division): morceaux.append(division)
	if not tour.is_empty(): morceaux.append(tour)
	var ligne := C.wrap(" · ".join(morceaux), 19, Charte.IVOIRE_2, false, 500)
	ligne.name = "EntrySeasonLine"
	texte.add_child(ligne)
	return bloc

## Classement et prochain match, lus du modèle ; une donnée absente omet sa colonne. Chaque valeur ouvre sa page.
static func _lecture(app: Control, club: Dictionary, _meta: Dictionary) -> Control:
	if app.Immersive.Selections.nation_only(app.model): return null
	var colonnes := C.h(32)
	colonnes.name = "EntryReading"
	var rang := int(club.get("rank", 0))
	if rang > 0:
		var points := int(club.get("points", 0))
		var bloc := C.v(2)
		bloc.add_child(C.label("CLASSEMENT", 16, Charte.IVOIRE_2, true, 700))
		var valeur := Button.new()
		valeur.name = "EntryRank"
		valeur.text = "%s · %d pt%s" % ["1er" if rang == 1 else "%de" % rang, points, "" if points <= 1 else "s"]
		valeur.pressed.connect(func(): app._navigate("Classements"))
		valeur.tooltip_text = "Ouvrir le classement"
		C.style_bouton_lien(valeur, 20, true)
		bloc.add_child(valeur)
		colonnes.add_child(bloc)
	var suivant: Variant = app.model.get("next")
	if suivant is Dictionary and suivant.get("home") is Dictionary and suivant.get("away") is Dictionary:
		var domicile: Dictionary = suivant.home
		var exterieur: Dictionary = suivant.away
		var adversaire: Dictionary = exterieur if domicile.get("id") == club.get("id") else domicile
		var nom := str(adversaire.get("name", ""))
		if not nom.is_empty():
			var bloc := C.v(2)
			bloc.add_child(C.label("PROCHAIN MATCH", 16, Charte.IVOIRE_2, true, 700))
			var quand := _jour(str(suivant.get("date", "")))
			var valeur := Button.new()
			valeur.name = "EntryNextMatch"
			valeur.text = nom + (" · " + quand if not quand.is_empty() else "")
			valeur.pressed.connect(func(): app._navigate("Calendrier"))
			valeur.tooltip_text = "Ouvrir le calendrier"
			C.style_bouton_lien(valeur, 20, true)
			bloc.add_child(valeur)
			colonnes.add_child(bloc)
	return colonnes if colonnes.get_child_count() > 0 else null

static func _jour(iso: String) -> String:
	if iso.length() < 10: return ""
	var jour := iso.substr(0, 10)
	var parties := jour.split("-")
	if parties.size() != 3 or not parties[1].is_valid_int() or not parties[2].is_valid_int(): return ""
	var mois := int(parties[1])
	if mois < 1 or mois > 12: return ""
	var semaine := int(Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_string(jour + "T12:00:00"))).get("weekday", 0))
	return "%s %d %s" % [JOURS[semaine], int(parties[2]), MOIS[mois - 1]]

## « Monde · N clubs jouables » et « N joueurs au départ » (première fois) : chiffres lus du pack chargé.
static func _ligne_monde(app: Control) -> Control:
	var ligne := C.v(2)
	if not app.pack_manager.creation_catalogue().is_empty():
		var clubs := C.label("Monde · %d clubs jouables" % app.pack_manager.playable_club_count("creation"), 19, Charte.IVOIRE_2, false, 500)
		clubs.name = "EntryWorldCount"
		ligne.add_child(clubs)
	var base: Dictionary = app.pack_manager.database("creation")
	var joueurs := int(base.get("startingPlayerCount", base.get("playerCount", 0)))
	if joueurs > 0:
		var depart := C.label("%s joueurs au départ" % G.n(joueurs), 19, Charte.IVOIRE_2, false, 500)
		depart.name = "EntryStartingPlayers"
		ligne.add_child(depart)
	return ligne if ligne.get_child_count() > 0 else null
## Reprise : bouton or (Continuer, seule exception hors coque), « Entrée » en rappel à droite.
static func _principal_or(texte: String, appel: Callable, nom: String) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = texte
	bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.custom_minimum_size.y = C.px(88)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "focus"]:
		var style := _plat(Charte.OR_VIF if etat == "hover" else Charte.OR, 24, Charte.RAYON_PILULE)
		if etat == "focus":
			style.border_color = Charte.IVOIRE
			style.set_border_width_all(maxi(2, C.px(4)))
		bouton.add_theme_stylebox_override(etat, style)
	bouton.add_theme_stylebox_override("disabled", _plat(Charte.PANNEAU_3, 24, Charte.RAYON_PILULE))
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(cle, Charte.NUIT)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	bouton.add_theme_font_size_override("font_size", C.font_px(36))
	bouton.pressed.connect(appel)
	_rappel_entree(bouton)
	return bouton

## « Entrée » en rappel à droite du bouton principal (Entrée valide le bouton qui a le focus).
static func _rappel_entree(bouton: Button) -> void:
	var rappel := _police("Entrée", 17, Charte.ENCRE, Charte.TEXTE)
	rappel.name = "EntryEnterHint"
	bouton.add_child(rappel)
	rappel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	rappel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rappel.offset_right = -C.px(24)

## Lien du carnet : texte ivoire, flèche à droite, filet dessous, souligné au survol.
static func _lien(parent: Container, texte: String, appel: Callable, nom: String) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = texte
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.pressed.connect(appel)
	C.style_bouton_lien(bouton, 25)
	bouton.custom_minimum_size.y = maxi(C.px(61), int(C.TARGET_MIN))
	bouton.icon = C.icon_texture("arrow", Charte.IVOIRE)
	bouton.expand_icon = true
	bouton.add_theme_constant_override("icon_max_width", C.px(24))
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_stylebox_override("normal", _filet_bas())
	parent.add_child(bouton)
	return bouton

static func _filet_bas() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(0)
	style.border_color = Charte.FILET
	style.border_width_bottom = 1
	style.content_margin_left = C.px(6)
	style.content_margin_right = C.px(6)
	return style
