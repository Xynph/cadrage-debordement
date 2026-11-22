extends RefCounted
## Écran Composition (route « Composition », chapitre Tactique) — choix de Léo du 19/11/2026 : variante 1 « Terrain au
## centre, candidats dessous » (design/ux/10-composition.md, direction-artistique/interface/revue-20261119) et l'encart
## « Première ligne formée » de la variante 3. En-tête visuel (tactics_entete.gd : pastilles de la feuille, actions,
## bandeau du match), onglets, puis terrain vertical, banc et doublures (tactics_vertical.gd, option
## A de Léo du 22/11/2026), impact (tactics_impact.gd) et candidats (tactics_candidats.gd). Jamais de petite fenêtre : les choix annexes sont des
## sous-pages (tactics_sous_pages.gd). L'interface n'écrit jamais l'état du jeu : commandes du moteur seulement.
## Exemple : page dédiée de la coque, `TacticsCanvas.build(app, canvas)`.
const FocusLater := preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Poste = preload("res://ui/immersive08/tactics_poste.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const Impact = preload("res://ui/immersive08/tactics_impact.gd")
const Candidats = preload("res://ui/immersive08/tactics_candidats.gd")
const SousPages = preload("res://ui/immersive08/tactics_sous_pages.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const Roles = preload("res://ui/immersive08/tactics_roles.gd")
const Cover = preload("res://ui/lineup_cover.gd")
const Espoir = preload("res://ui/espoir_appel.gd")
const PersonName = preload("res://ui/person_name.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Entete = preload("res://ui/immersive08/tactics_entete.gd")
const Onglets = preload("res://ui/immersive08/tactics_onglets.gd")
## Hauteur du gabarit (unités) ; largeur 2248 comme toutes les pages de la coque.
const HAUTEUR := 1305.0

## Page : Ctrl+Entrée valide la feuille depuis n'importe quel poste.
class PageComposition extends Control:
	func _input(event: InputEvent) -> void:
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or not touche.ctrl_pressed: return
		if touche.keycode not in [KEY_ENTER, KEY_KP_ENTER] or not is_visible_in_tree(): return
		var bouton := find_child("TacticsValidate", true, false) as Button
		var vue := get_viewport()
		vue.set_input_as_handled()
		# Valider change d'écran (cette page quitte l'arbre) : différé pour finir le traitement de la touche d'abord.
		if bouton != null and not bouton.disabled: bouton.pressed.emit.call_deferred()

static func build(app: Control, canvas: Control = null) -> Control:
	var page := PageComposition.new()
	page.name = "ImmersiveTactics"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.custom_minimum_size = Vector2(2248, HAUTEUR) * C.density
	if canvas != null:
		canvas.add_child(page)
		canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, HAUTEUR * C.density)
		D.place(page, Rect2(0, 0, 2248, HAUTEUR))
	app.selected_slot = clampi(int(app.selected_slot), 0, 22)
	# Première ouverture sous le budget de 250 ms (tests/godot-portraits-prechauffage.gd) : la feuille et l'effectif sont
	# indexés une fois pour toute la construction ; chaque fond naît avec le rayon de la charte (§3), sans passe après coup.
	Selection.lecture_debut(app.model)
	var construite := _construire(app, page)
	Selection.lecture_fin()
	return construite

static func _construire(app: Control, page: Control) -> Control:
	var etat := Selection.state(app)
	var pris: Variant = etat.get("pris")
	if pris is Dictionary and Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1))) == null: etat.erase("pris")
	var sous := SousPages.actuelle(app)
	if not sous.is_empty():
		SousPages.build(app, page, sous)
		return page
	# Onglets Consignes, Phases arrêtées, Entraînement : même page, même en-tête (tactics_onglets.gd).
	var onglet := Onglets.actuel(app)
	if onglet != 0:
		Onglets.build(app, page, onglet)
		_onglets(app, page)
		return page
	var choisir_cb := func(slot: int): choisir(app, slot)
	var clavier_cb := func(event: InputEvent, slot: int, carte: Control): clavier(app, event, slot, carte)
	_entete(app, page)
	_onglets(app, page)
	var avis := Impact.avis(app)
	var bleus := _bleus_marques(app)
	var premiere := Selection.premiere_ligne(app.model)
	# Terrain vertical vert, banc en tuiles, doublures, impact (option A de Léo, 22/11/2026), candidats dessous à droite.
	Vertical.build(app, page, choisir_cb, clavier_cb, avis, bleus, premiere)
	# Bas à droite : candidats du poste choisi, ou tout le reste de l'effectif (« Hors groupe »), au choix en pilules.
	# Alertes des sélections (Bleus, Nationale) : pastilles de la ligne des onglets (Onglets.alertes), plus de bandeau.
	if str(Selection.state(app).get("bas", "candidats")) == "hors_groupe":
		Vertical.hors_groupe(app, page, Vertical.CANDIDATS, 0.0)
	else:
		Candidats.build(app, page, Vertical.CANDIDATS, premiere, choisir_cb, 0.0, 560.0, func(b: Control): Vertical.onglets_bas(app, b))
	_restore_focus.call_deferred(app)
	return page

static func _adversaire(app: Control) -> String:
	var match_ := P.next_fixture(app.model)
	if match_.is_empty(): return ""
	var club_id: Variant = app.model.get("club", {}).get("id")
	var autre: Dictionary = match_.get("away", {}) if match_.get("home", {}).get("id") == club_id else match_.get("home", {})
	return G.club_name(autre)

## En-tête visuel (tactics_entete.gd) : titre, pastilles de la feuille, actions, bandeau du match.
static func _entete(app: Control, page: Control) -> void:
	Entete.build(app, page, {"choisir": func(slot: int): choisir(app, slot), "valider": func(): validate(app), "corriger": _place_a_corriger(app)})

## Première place à corriger : vide, sinon tenue par un joueur que le moteur n'y accepte plus ; -1 sinon.
static func _place_a_corriger(app: Control) -> int:
	for index in 23:
		if Selection.slot(app.model, index).get("playerId") == null: return index
	for index in 23:
		var id: Variant = Selection.slot(app.model, index).get("playerId")
		if id != null and str(id) not in Selection.slot(app.model, index).get("eligibleIds", []): return index
	return -1

## Onglets du chapitre Tactique et pastilles Plan / Défense (→ Consignes).
static func _onglets(app: Control, page: Control) -> void:
	var onglets := [[0, "Composition"], [1, "Consignes"], [2, "Phases arrêtées"], [4, "Entraînement"]]
	var x := 0.0
	for onglet: Array in onglets:
		var index: int = onglet[0]
		var largeur := C.DISPLAY.get_string_size(str(onglet[1]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density + 40
		_onglet(app, page, Rect2(x, 132, largeur, 44), str(onglet[1]), index)
		x += largeur + 6
	Onglets.alertes(app, page, x + 24, 137)
	D.line(page, Vector2(0, 176), Vector2(2248, 176), Charte.FILET)
	var tactique: Dictionary = app.model.get("tactics", {})
	Entete.plan(app, page, _libelle(tactique.get("attacks", []), tactique.get("attack")), _libelle(tactique.get("defenses", []), tactique.get("defense")))

static func _libelle(options: Variant, id: Variant) -> String:
	if options is Array:
		for option: Variant in options:
			if option is Dictionary and option.get("id") == id: return str(option.get("label", id))
	return str(id) if id != null else "—"

static func _onglet(app: Control, page: Control, zone: Rect2, texte: String, index: int) -> void:
	var choisi := index == Onglets.actuel(app)
	var bouton := Button.new()
	bouton.name = "TacticsTab" + str(index)
	bouton.text = texte.to_upper()
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.add_theme_font_override("font", C.DISPLAY)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, Charte.PANNEAU if choisi else Charte.IVOIRE_2)
	# Onglet de la charte §7.1 : pilule ; actif = aplat crème, texte `PANNEAU` ; survol `PANNEAU_2`.
	var fond := C.box(Charte.IVOIRE if choisi else Color.TRANSPARENT, Color.TRANSPARENT, Charte.RAYON_PILULE, 0)
	for etat in ["normal", "pressed", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, fond)
	bouton.add_theme_stylebox_override("hover", fond if choisi else C.box(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_PILULE, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 0)
	focus.set_border_width_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.pressed.connect(func(): _ouvrir_onglet(app, index))
	page.add_child(bouton)
	D.place(bouton, zone)

## Onglets de la même page (tactics_onglets.gd) ; Composition déjà ouverte : focus sur les candidats du poste choisi.
static func _ouvrir_onglet(app: Control, index: int) -> void:
	if index == 0 and Onglets.actuel(app) == 0:
		choisir(app, app.selected_slot)
		return
	Onglets.choisir_onglet(app, index)

static func _bleus_marques(app: Control) -> Dictionary:
	var marques := {}
	var bleus: Dictionary = app.SquadViews.bleus_resume(app)
	for e: Dictionary in bleus.get("echanges", []): marques[int(e.slot)] = true
	return marques

## Choisir une place (carte, ligne du banc, doublure, encart) : sa liste de candidats s'affiche dessous. Un second appui
## sur la place déjà choisie met le focus sur le premier candidat (clavier : Entrée puis ↑ ↓).
static func choisir(app: Control, index: int) -> void:
	var etat := Selection.state(app)
	if app.selected_slot == index and app.root_content.find_child("TacticsCandidateRows", true, false) != null:
		_focus_candidat(app)
		return
	app.selected_slot = index
	etat.bas = "candidats"
	etat.message = ""
	etat.scroll = 0
	etat.focus = "LineupSlot%02d" % (index + 1)
	app._render()
	_restore_focus(app)

static func _focus_candidat(app: Control) -> void:
	var lignes: Node = app.root_content.find_child("TacticsCandidateRows", true, false)
	if lignes == null: return
	for ligne in lignes.get_children():
		if ligne is Button:
			FocusLater.grab(ligne)
			return

## Clavier sur une place (terrain ou banc) : Espace prend puis pose (échange), Échap annule, Suppr libère (confirmation),
## Maj+Entrée ouvre la fiche, I montre la mini-fiche. Alternative complète au glisser-déposer (K6).
static func clavier(app: Control, event: InputEvent, slot: int, carte: Control) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or touche.alt_pressed or touche.meta_pressed or touche.ctrl_pressed: return
	var etat := Selection.state(app)
	var pris: Dictionary = etat.get("pris", {}) if etat.get("pris") is Dictionary else {}
	var person := Selection.occupant(app.model, slot)
	var id := str(person.get("id", ""))
	match touche.keycode:
		KEY_SPACE:
			if touche.shift_pressed: return
			carte.accept_event()
			if pris.is_empty():
				if person.is_empty():
					_annoncer(app, "Poste n° %d vide : rien à prendre." % (slot + 1), carte)
					return
				if Selection.payload(app, id, slot) == null:
					_annoncer(app, "La feuille ne se modifie pas maintenant.", carte)
					return
				etat.pris = {"player_id":id, "source":slot}
				_annoncer(app, "%s (n° %d) pris : flèches vers sa nouvelle place, puis Espace pour poser. Échap annule." % [str(person.get("name", "")), slot + 1], carte, true)
				return
			etat.erase("pris")
			if int(pris.get("source", -1)) == slot:
				_annoncer(app, "Déplacement annulé.", carte, true)
				return
			var payload: Variant = Selection.payload(app, str(pris.get("player_id", "")), int(pris.get("source", -1)))
			if Selection.can_drop(app, payload, slot):
				var nom := str(Selection.player(app.model, str(pris.get("player_id", ""))).get("name", ""))
				etat.message = "%s posé au n° %d." % [nom, slot + 1]
				Selection.apply(app, payload, slot)
			else:
				_annoncer(app, "Ce joueur ne peut pas tenir le n° %d : déplacement annulé." % (slot + 1), carte, true)
		KEY_ESCAPE:
			if pris.is_empty(): return
			carte.accept_event()
			etat.erase("pris")
			_annoncer(app, "Déplacement annulé.", carte, true)
		KEY_ENTER, KEY_KP_ENTER:
			if not touche.shift_pressed or person.is_empty(): return
			carte.accept_event()
			app.navigation_controller.open_entity({"kind":"player", "id":id})
		KEY_DELETE:
			if person.is_empty() or not Selection.editable(app): return
			carte.accept_event()
			Candidats.liberer(app, id, slot)
		KEY_I:
			if person.is_empty() or touche.shift_pressed: return
			carte.accept_event()
			var ouverte: Control = CarteSurvol.actuelle(app)
			if ouverte != null and ouverte.get_meta("player_id", "") == id: CarteSurvol.cacher(app)
			else: CarteSurvol.montrer(app, id, "squad", carte)

## Message lisible sous les candidats ; `rendre` redessine l'écran (marques « pris » / destinations) et garde le focus.
static func _annoncer(app: Control, texte: String, carte: Control, rendre: bool = false) -> void:
	var etat := Selection.state(app)
	etat.message = texte
	etat.focus = str(carte.name)
	if rendre:
		app._render()
		_restore_focus(app)
	else:
		Candidats._message(app)

static func _restore_focus(app: Control) -> void:
	var focus_id := str(Selection.state(app).get("focus", ""))
	if focus_id.is_empty(): return
	var focus: Control = app.root_content.find_child(focus_id, true, false)
	if focus != null: FocusLater.grab(focus)

## « Valider la feuille » : feuille valide → préparation du match. Sinon rien n'est envoyé : la ligne de validité dit
## pourquoi (pastille « Incomplète ») et son lien prend le focus (aucune fenêtre).
static func validate(app: Control) -> void:
	if app.model.get("selection", {}).get("valid", false):
		app._navigate("Préparation")
		return
	var corriger := app.root_content.find_child("TacticsCorriger", true, false) as Control
	if corriger != null: FocusLater.grab(corriger)

## Charge individuelle d'un joueur, ouverte depuis la fiche joueur : sous-page de la fiche (fiche_charge.gd), plus une
## fenêtre (décision de Léo du 19/11/2026).
static func _individual(app:Control,player:Dictionary) -> void:
	load("res://ui/immersive08/fiche_charge.gd").ouvrir(app,player)