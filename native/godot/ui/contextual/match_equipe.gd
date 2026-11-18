extends Control
## Fenêtre « Équipe » du match en direct (maquette retenue par Léo le 18/11/2026, façon FM) : un seul
## bouton « ÉQUIPE » remplace Tactique et Banc. Elle couvre l'écran, met le match en pause à l'ouverture
## et le relance avec « Valider et reprendre ». Deux onglets :
## - Composition : cris de la touche, terrain avec les quinze en médaillons (portrait, anneau d'énergie,
##   niveau, numéro, note du match, état après la causerie), « Dans 10 minutes », le banc en tuiles,
##   le conseil de Gabi, et en pied les consignes en place et l'arbitre ;
## - Consignes : les cinq axes en direct (set_consignes), le plan de jeu (set_tactics, set_penalty_policy),
##   l'arbitre et ses quatre jauges, ce que fait l'adversaire et qui suit la consigne.
## L'écran n'invente rien : tout vient du modèle (`live`, `live.pilotage`, `live.direct.notes`, `squad`) et
## chaque champ optionnel absent masque son bloc. Les règles du banc (première ligne, cartons) restent au
## moteur : un refus s'affiche en une ligne sous le terrain.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/contextual/skin.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")

## Taille de la maquette : tout est écrit pour 1600×900 et mis à l'échelle (k) de la fenêtre.
const REF := Vector2(1600, 900)
## Place de chaque numéro sur le terrain (% de la largeur, % de la hauteur), avants à gauche, attaque ▸.
## Lignes de trois-quarts en colonnes (demis, centres, triangle du fond) : les médaillons agrandis ne se
## chevauchent plus (capture du 18/11/2026, la diagonale de la maquette les empilait).
const PLACES := {1: Vector2(14, 20), 2: Vector2(14, 50), 3: Vector2(14, 80), 4: Vector2(26, 34), 5: Vector2(26, 66),
	6: Vector2(38, 14), 7: Vector2(38, 86), 8: Vector2(38, 50), 9: Vector2(51, 30), 10: Vector2(51, 70),
	11: Vector2(77, 13), 12: Vector2(64, 30), 13: Vector2(64, 70), 14: Vector2(77, 87), 15: Vector2(89, 50)}
const ARBITRE_AXES := [["rucks", "Rucks"], ["melee", "Mêlée"], ["horsJeu", "Hors-jeu"], ["cartons", "Cartons"]]
const ARBITRE_MOTS := ["", "laisse jouer", "souple", "équilibré", "pointilleux", "très pointilleux"]

var view: Control
var app: Node
## « composition » ou « consignes ».
var onglet := "composition"
## Échelle de la maquette dans la fenêtre.
var k := 1.0
## Joueur du XV choisi (poste 0 à 14, -1 : aucun) et remplaçant choisi (id, "" : aucun).
var poste_choisi := -1
var entrant_choisi := ""
## Médaillons du terrain (poste → bouton) et tuiles du banc (id → bouton), pour les tests.
var medaillons: Dictionary = {}
var tuiles: Dictionary = {}
var _model: Dictionary = {}
var _cle := ""
var _veut_pause := false
var _veut_reprise := false
## Commande envoyée depuis la fenêtre, en attente de la réponse du moteur, et message à montrer ensuite.
var _attente := ""
var _succes := ""
var _message := ""
var _message_teinte := C.MUTED
var _conseil_ecarte := ""
var _page: Control
var _gras: FontVariation

func _ready() -> void:
	name = "MatchTeamWindow"
	mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(self)
	_gras = FontVariation.new()
	_gras.base_font = C.BODY
	_gras.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	hide()
	resized.connect(_redimensionne)

func _redimensionne() -> void:
	if not visible: return
	_cle = ""
	_rafraichir()

func _live() -> Dictionary:
	return _model.get("live", {}) if _model.get("live") is Dictionary else {}

## Ouvre la fenêtre sur un onglet (et un joueur du XV choisi) ; le match se met en pause.
func ouvrir(vers: String = "composition", poste: int = -1) -> void:
	if bool(_live().get("finished", false)): return
	onglet = "consignes" if vers == "consignes" else "composition"
	poste_choisi = poste
	entrant_choisi = ""
	_message = ""
	_veut_reprise = false
	_veut_pause = true
	show()
	_cle = ""
	_rafraichir()
	var reprise: Control = find_child("TeamResume", true, false)
	if reprise != null: reprise.grab_focus.call_deferred()

## « Valider et reprendre » : la fenêtre se ferme et le match repart.
func fermer(reprendre: bool = true) -> void:
	hide()
	_veut_pause = false
	_veut_reprise = reprendre
	if view != null and view.has_method("equipe_fermee"): view.equipe_fermee()

func choisir_onglet(vers: String) -> void:
	onglet = vers
	_cle = ""
	_rafraichir()

func update_frame(model: Dictionary) -> void:
	_model = model
	if bool(_live().get("finished", false)) and visible: fermer(false)
	if visible: _rafraichir()

func _process(_delta: float) -> void:
	if app == null: return
	var live := _live()
	var fige := bool(live.get("finished", false)) or bool(live.get("atBreak", false))
	if _veut_pause:
		if fige or bool(live.get("paused", false)): _veut_pause = false
		elif not bool(app.waiting) and app._command("pause", {"paused": true}): _veut_pause = false
	if _veut_reprise:
		var causerie: bool = view != null and view.get("director") != null and not view.director._talk().is_empty()
		if fige or causerie or not bool(live.get("paused", false)): _veut_reprise = false
		elif not bool(app.waiting) and app._command("pause", {"paused": false}): _veut_reprise = false
	if not _attente.is_empty() and not bool(app.waiting):
		var erreur := str(app.get("last_error"))
		_message = erreur if not erreur.is_empty() else _succes
		_message_teinte = C.ALERT if not erreur.is_empty() else C.MINT
		_attente = ""
		_cle = ""
		if visible: _rafraichir()

# --- Données -------------------------------------------------------------------

func _pilotage() -> Dictionary:
	return Pilotage.pilotage(_live())

func _direct() -> Dictionary:
	return _live().get("direct") if _live().get("direct") is Dictionary else {}

func _lineup() -> Array:
	return _live().get("lineup", []) if _live().get("lineup") is Array else []

func _reserves() -> Array:
	return _live().get("reserves", []) if _live().get("reserves") is Array else []

## Fiche de l'effectif (niveau, index de portrait) : complète le joueur du direct.
func _fiche(id: String) -> Dictionary:
	for joueur: Variant in _model.get("squad", []):
		if joueur is Dictionary and str(joueur.get("id", "")) == id: return joueur
	return {}

## Joueur pour le portrait : le joueur du direct, complété par sa fiche de l'effectif.
func _joueur_complet(joueur: Dictionary) -> Dictionary:
	var complet := _fiche(str(joueur.get("id", ""))).duplicate()
	complet.merge(joueur, true)
	return complet

## Niveau du joueur (live.lineup[].rating, sinon la fiche de l'effectif) ; "" s'il manque.
func _niveau(joueur: Dictionary) -> String:
	var valeur: Variant = joueur.get("rating", _fiche(str(joueur.get("id", ""))).get("rating"))
	return str(roundi(float(valeur))) if valeur is float or valeur is int else ""

func _entrants(slot: int) -> Array:
	for option: Variant in _live().get("substitutions", []):
		if option is Dictionary and int(option.get("slot", -1)) == slot: return option.get("inIds", []) if option.get("inIds") is Array else []
	return []

func _autorise(slot: int, id: String) -> bool:
	return _entrants(slot).any(func(x: Variant) -> bool: return str(x) == id)

func _poste_de(id: String) -> int:
	var lineup := _lineup()
	for n in lineup.size():
		if lineup[n] is Dictionary and str(lineup[n].get("id", "")) == id: return n
	return -1

func _reserve(id: String) -> Dictionary:
	for joueur: Variant in _reserves():
		if joueur is Dictionary and str(joueur.get("id", "")) == id: return joueur
	return {}

static func nom_court(nom: String) -> String:
	var morceaux := nom.strip_edges().split(" ", false)
	if morceaux.is_empty(): return ""
	var famille := " ".join(morceaux.slice(1)) if morceaux.size() > 1 else morceaux[0]
	return famille if famille.length() <= 11 else famille.substr(0, 10) + "."

static func teinte_energie(valeur: float) -> Color:
	if valeur >= 75.0: return C.MINT
	if valeur >= 60.0: return C.GOLD
	return C.ALERT

# --- Actions -------------------------------------------------------------------

func choisir_poste(slot: int) -> void:
	if not entrant_choisi.is_empty() and _autorise(slot, entrant_choisi):
		remplacer(slot, entrant_choisi)
		return
	poste_choisi = -1 if poste_choisi == slot else slot
	entrant_choisi = ""
	_message = ""
	_cle = ""
	_rafraichir()

func choisir_entrant(id: String) -> void:
	if poste_choisi >= 0 and _autorise(poste_choisi, id):
		remplacer(poste_choisi, id)
		return
	entrant_choisi = "" if entrant_choisi == id else id
	_message = ""
	_cle = ""
	_rafraichir()

## Remplacement : `substitute {slot, outId, inId}` (le moteur vérifie poste, première ligne et cartons).
func remplacer(slot: int, in_id: String) -> void:
	var lineup := _lineup()
	if slot < 0 or slot >= lineup.size(): return
	var sortant: Variant = lineup[slot]
	var out_id: Variant = sortant.get("id") if sortant is Dictionary else null
	var entrant := _reserve(in_id)
	var payload := {"slot": slot, "outId": out_id, "inId": in_id}
	poste_choisi = -1
	entrant_choisi = ""
	if app._command("substitute", payload):
		_attente = "substitute"
		_succes = "%s entre à la place de %s." % [nom_court(str(entrant.get("name", "Le remplaçant"))), nom_court(str(sortant.get("name", "")) if sortant is Dictionary else "poste vacant")]
		_message = "Changement demandé…"
		_message_teinte = C.MUTED
	_cle = ""
	_rafraichir()

func crier(id: String) -> void:
	if app._command("cri", {"id": id}):
		_attente = "cri"
		_succes = "Le message est passé depuis la touche."
	_cle = ""
	_rafraichir()

func _envoyer_consigne(axe: String, valeur: String) -> void:
	if view != null and view.has_method("_envoyer_consigne"): view._envoyer_consigne(axe, valeur)
	else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))
	_cle = ""
	_rafraichir()

func _plan(cle: String, id: Variant) -> void:
	var courant: Dictionary = _model.get("tactics", {}) if _model.get("tactics") is Dictionary else {}
	var payload := {"attack": courant.get("attack", "equilibre"), "defense": courant.get("defense", "equilibre")}
	payload[cle] = id
	app._command("set_tactics", payload)

# --- Construction --------------------------------------------------------------

func px(valeur: float) -> int:
	return roundi(valeur * k)

func fs(valeur: float) -> int:
	return maxi(10, roundi(valeur * k))

func _boite(fond: Color, bord: Color = Color.TRANSPARENT, rayon: float = 10, epaisseur: float = 1, marge: float = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(maxi(1, px(epaisseur)) if bord.a > 0.0 else 0)
	style.set_corner_radius_all(maxi(2, px(rayon)))
	style.set_content_margin_all(px(marge))
	style.anti_aliasing = true
	return style

func _texte(texte: String, taille: float, couleur: Color = C.IVORY, police: Font = null) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_override("font", police if police != null else C.BODY)
	etiquette.add_theme_font_size_override("font_size", fs(taille))
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiquette

func _titre(texte: String, taille: float, couleur: Color = C.IVORY, poids: int = 800) -> Label:
	return _texte(texte, taille, couleur, C.font(poids))

func _coupe(etiquette: Label) -> Label:
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return etiquette

func _h(ecart: float) -> HBoxContainer:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", px(ecart))
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rangee

func _v(ecart: float) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", px(ecart))
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return colonne

func _panneau(style: StyleBox) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", style)
	return cadre

## Bloc posé à sa place de la maquette (unités 1600×900).
func _poser(controle: Control, x: float, y: float, largeur: float, hauteur: float) -> Control:
	controle.position = Vector2(x, y) * k
	controle.size = Vector2(largeur, hauteur) * k
	controle.custom_minimum_size = Vector2.ZERO
	_page.add_child(controle)
	controle.position = Vector2(x, y) * k
	controle.size = Vector2(largeur, hauteur) * k
	return controle

## Bouton de la maquette : principal (or plein), menthe, encadré (RAISED + filet) ou transparent.
func _bouton(texte: String, action: Callable, genre: String = "cadre", taille: float = 18, nom: String = "") -> Button:
	var bouton := Button.new()
	bouton.text = texte
	if not nom.is_empty(): bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.add_theme_font_override("font", C.font(800 if genre in ["or", "menthe"] else 700))
	bouton.add_theme_font_size_override("font_size", fs(taille))
	var fond: Color = {"or": C.GOLD, "menthe": C.MINT, "cadre": C.RAISED, "transparent": Color.TRANSPARENT, "or_cadre": C.RAISED}.get(genre, C.RAISED)
	var bord: Color = {"or": Color.TRANSPARENT, "menthe": Color.TRANSPARENT, "or_cadre": C.GOLD}.get(genre, C.LINE)
	var encre := C.BG if genre in ["or", "menthe"] else C.IVORY
	var normal := _boite(fond, bord, 8, 1, 0)
	normal.content_margin_left = px(18)
	normal.content_margin_right = px(18)
	normal.content_margin_top = px(8)
	normal.content_margin_bottom = px(8)
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = fond.lightened(0.12) if fond.a > 0.0 else Color(C.IVORY, 0.06)
	survol.border_color = C.IVORY if bord.a > 0.0 else Color.TRANSPARENT
	var appui := normal.duplicate() as StyleBoxFlat
	appui.bg_color = fond.darkened(0.12) if fond.a > 0.0 else Color(C.IVORY, 0.1)
	var eteint := normal.duplicate() as StyleBoxFlat
	eteint.bg_color = Color(fond, 0.35) if fond.a > 0.0 else Color.TRANSPARENT
	eteint.border_color = Color(C.LINE, 0.5)
	var focus := _boite(Color.TRANSPARENT, C.GOLD if genre not in ["or", "or_cadre"] else C.IVORY, 8, 2, 0)
	focus.set_expand_margin_all(px(2))
	for paire: Array in [["normal", normal], ["hover", survol], ["pressed", appui], ["disabled", eteint], ["focus", focus]]:
		bouton.add_theme_stylebox_override(paire[0], paire[1])
	for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(cle, encre)
	bouton.add_theme_color_override("font_disabled_color", Color(encre, 0.45))
	bouton.pressed.connect(action)
	return bouton

## Portrait rond (découpé en disque) ou arrondi (tuiles du banc).
func _portrait(joueur: Dictionary, largeur: float, hauteur: float = -1.0, rayon: float = -1.0) -> Control:
	var h := hauteur if hauteur > 0.0 else largeur
	var cadre := Panel.new()
	cadre.name = "Portrait"
	cadre.custom_minimum_size = Vector2(largeur, h)
	cadre.size = Vector2(largeur, h)
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", _boite(C.RAISED, Color.TRANSPARENT, (largeur / 2.0 if rayon < 0.0 else rayon) / k, 0, 0))
	var complet := _joueur_complet(joueur)
	var image: TextureRect = G.portrait_lazy(int(complet.get("portraitIndex", 0)), roundi(largeur), complet)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	var cote := maxf(largeur, h)
	image.position = Vector2((largeur - cote) / 2.0, 0)
	image.size = Vector2(cote, cote * 1.12)
	cadre.add_child(image)
	cadre.set_meta("portrait", true)
	return cadre

func _rafraichir() -> void:
	if not is_node_ready() or not visible: return
	var taille := size if size.x > 0.0 else get_viewport_rect().size
	k = minf(taille.x / REF.x, taille.y / REF.y)
	var live := _live()
	var p := _pilotage()
	var envois: Dictionary = view.get("_envois_consignes") if view != null and view.get("_envois_consignes") is Dictionary else {}
	Pilotage.confirmer(p, envois)
	# Plus rien en attente : un cran non confirmé a été refusé, le modèle reprend la main.
	if not bool(app.waiting): envois.clear()
	var cle := JSON.stringify([onglet, poste_choisi, entrant_choisi, taille, live.get("lineup"), live.get("reserves"), live.get("substitutions"), live.get("paused"),
		live.get("finished"), p, envois, _direct().get("notes"), _direct().get("cartons"), _model.get("tactics"), _message, _conseil_ecarte, _horloge(), _score(), live.get("teams")])
	if cle == _cle: return
	_cle = cle
	var focus := get_viewport().gui_get_focus_owner()
	var focus_nom := str(focus.name) if focus != null and is_ancestor_of(focus) else ""
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	medaillons.clear()
	tuiles.clear()
	_fond()
	_page = Control.new()
	_page.name = "TeamPage"
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.size = REF * k
	_page.position = ((taille - REF * k) / 2.0).floor()
	add_child(_page)
	_entete()
	if onglet == "consignes": _consignes()
	else: _composition()
	if not focus_nom.is_empty():
		var retrouve: Control = find_child(focus_nom, true, false)
		if retrouve != null and retrouve.focus_mode != Control.FOCUS_NONE: retrouve.grab_focus.call_deferred()

func _fond() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, C.RAISED)
	gradient.set_color(1, C.BG)
	gradient.set_offset(1, 0.6)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var fond := TextureRect.new()
	fond.name = "TeamBackdrop"
	fond.texture = texture
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	var plein := ColorRect.new()
	plein.color = C.BG
	plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(plein)
	add_child(plein)
	add_child(fond)

func _horloge() -> String:
	if view != null and view.get("clock") is Label: return str(view.clock.text)
	return "%d′" % int(_live().get("minute", 0))

func _score() -> String:
	if view != null and view.get("score") is Label: return str(view.score.text).replace("—", "–")
	var score: Array = _live().get("score", [0, 0])
	return "%d – %d" % [int(score[0]), int(score[1])] if score.size() >= 2 else ""

func _largeur_texte(texte: String, police: Font, taille: int) -> float:
	return police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

func _entete() -> void:
	var cadre := _panneau(_boite(C.PANEL, C.LINE, 12, 1, 0))
	cadre.name = "TeamHeader"
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(20)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(20)
	_poser(cadre, 24, 16, 1552, 64)
	var rangee := _h(22)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	cadre.add_child(rangee)
	var pastille := _panneau(_boite(C.GOLD, Color.TRANSPARENT, 16, 0, 0))
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(16)
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(16)
	pastille.custom_minimum_size.y = px(36)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var horloge := _titre(_horloge(), 28, C.BG, 700)
	horloge.name = "TeamClock"
	horloge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pastille.add_child(horloge)
	rangee.add_child(pastille)
	var equipes: Array = _live().get("teams", [])
	var noms: Array[String] = []
	for n in 2: noms.append(S.G.club_name(equipes[n]).to_upper() if equipes.size() > n and equipes[n] is Dictionary else "")
	var police_nom := C.font(700)
	for n in 2:
		var nom := _coupe(_titre(noms[n], 26, C.IVORY, 700))
		nom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		nom.custom_minimum_size.x = minf(_largeur_texte(noms[n], police_nom, fs(26)) + 2.0, px(330))
		nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rangee.add_child(nom)
		if n == 0:
			var cadre_score := _panneau(_boite(C.BG, Color.TRANSPARENT, 8, 0, 0))
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(14)
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(14)
			cadre_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var score := _titre(_score(), 34, C.GOLD, 800)
			score.name = "TeamScore"
			cadre_score.add_child(score)
			rangee.add_child(cadre_score)
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(vide)
	var en_pause := bool(_live().get("paused", false))
	var etat := _panneau(_boite(Color.TRANSPARENT, C.GOLD if en_pause else C.LINE, 14, 1, 0))
	etat.name = "TeamPauseState"
	var style_etat := etat.get_theme_stylebox("panel") as StyleBoxFlat
	style_etat.content_margin_left = px(12)
	style_etat.content_margin_right = px(12)
	style_etat.content_margin_top = px(5)
	style_etat.content_margin_bottom = px(5)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etat.add_child(_texte("Match en pause" if en_pause else "Mise en pause…", 13, C.GOLD if en_pause else C.MUTED))
	rangee.add_child(etat)
	for paire: Array in [["composition", "Composition", "TeamTabComposition"], ["consignes", "Consignes", "TeamTabConsignes"]]:
		var vers: String = paire[0]
		var bouton := _bouton(paire[1], func(): choisir_onglet(vers), "or" if onglet == vers else "cadre", 18, paire[2])
		bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(bouton)

func _pied(gauche: Callable, secondaire: Array) -> void:
	var cadre := _panneau(_boite(C.PANEL, C.LINE, 12, 1, 0))
	cadre.name = "TeamFooter"
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(16)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(16)
	_poser(cadre, 24, 820, 1552, 64)
	var rangee := _h(10)
	cadre.add_child(rangee)
	var hote := Control.new()
	hote.name = "TeamFooterInfo"
	hote.clip_contents = true
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(hote)
	var infos := _h(10)
	S.full(infos)
	hote.add_child(infos)
	gauche.call(infos)
	var bouton_secondaire := _bouton(str(secondaire[0]), secondaire[1], "or_cadre" if onglet == "composition" else "cadre", 18, str(secondaire[2]))
	bouton_secondaire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(bouton_secondaire)
	var reprise := _bouton("Valider et reprendre", func(): fermer(true), "or", 18, "TeamResume")
	reprise.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(reprise.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = px(22)
	(reprise.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = px(22)
	rangee.add_child(reprise)

func _puce(texte: String, couleur: Color = C.IVORY, bord: Color = C.LINE, taille: float = 13) -> PanelContainer:
	var puce := _panneau(_boite(Color.TRANSPARENT, bord, 14, 1, 0))
	var style := puce.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(3)
	style.content_margin_bottom = px(3)
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(_texte(texte, taille, couleur))
	return puce

## Consignes hors cran neutre, en puces « Rucks · Contester ».
func _consignes_actives(p: Dictionary) -> Array[String]:
	var resultat: Array[String] = []
	for axe_v: Variant in Pilotage.axes(p):
		if not axe_v is Dictionary: continue
		var axe: Dictionary = axe_v
		var options: Array = axe.get("options", []) if axe.get("options") is Array else []
		if options.size() < 3: continue
		var cran := Pilotage.cran(p, axe)
		if cran == str(options[1].get("id", "")): continue
		for option: Variant in options:
			if option is Dictionary and str(option.get("id", "")) == cran: resultat.append("%s · %s" % [str(axe.get("label", "")), str(option.get("label", ""))])
	return resultat

## Bilan court d'un axe : ce qui suit « : » dans le bilan du moteur (« 3 pénalités, 2 ballons arrachés »).
static func bilan_court(p: Dictionary, axe: String) -> String:
	for bilan: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if bilan is Dictionary and str(bilan.get("axe", "")) == axe:
			var texte := str(bilan.get("texte", ""))
			var coupe := texte.find(" : ")
			var morceaux := texte.substr(coupe + 3).trim_suffix(".") if coupe >= 0 else texte
			return "Depuis %d′ : %s" % [int(bilan.get("depuis", 0)), morceaux] if bilan.get("depuis") != null else morceaux
	return ""

# --- Onglet Composition ----------------------------------------------------------

func _composition() -> void:
	var p := _pilotage()
	var cris: Variant = p.get("cris")
	var avec_cris: bool = cris is Dictionary and (cris as Dictionary).get("options") is Array and not (cris.options as Array).is_empty()
	if avec_cris: _cris(cris)
	var gauche := 240.0 if avec_cris else 24.0
	var centre := _v(12)
	centre.name = "TeamCentre"
	_poser(centre, gauche, 96, 1140.0 - gauche, 708)
	_terrain(centre)
	_fatigue(centre, p)
	_banc(p)
	_pied(_pied_composition, ["Ajuster les consignes", choisir_onglet.bind("consignes"), "TeamToConsignes"])

func _pied_composition(infos: HBoxContainer) -> void:
	var p := _pilotage()
	var actives := _consignes_actives(p)
	infos.add_child(_texte("Consignes :", 13, C.MUTED))
	if actives.is_empty(): infos.add_child(_texte("toutes au cran normal", 13, C.MUTED))
	for texte in actives: infos.add_child(_puce(texte))
	for bilan_v: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if bilan_v is Dictionary:
			infos.add_child(_texte(bilan_court(p, str(bilan_v.get("axe", ""))), 13, C.ALERT if str(bilan_v.get("axe", "")) in ["rucks", "discipline"] else C.MUTED))
			break
	var arbitre := Pilotage.arbitre_texte(p.get("arbitre"))
	if not arbitre.is_empty():
		var ligne := _coupe(_texte(arbitre, 13, C.MUTED))
		ligne.name = "TeamFooterReferee"
		ligne.tooltip_text = arbitre
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		infos.add_child(ligne)

func _cris(cris: Dictionary) -> void:
	var colonne := _v(8)
	colonne.name = "TeamShouts"
	_poser(colonne, 24, 96, 200, 708)
	colonne.add_child(_titre("CRIS DE LA TOUCHE", 19, C.GOLD))
	var aide := _texte("Un mot au groupe, tout de suite. Effet court, qui s'use si on répète.", 12, C.MUTED)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(aide)
	var actif: Dictionary = cris.get("actif") if cris.get("actif") is Dictionary else {}
	var lettres := {}
	for option_v: Variant in cris.get("options", []):
		if not option_v is Dictionary: continue
		var option: Dictionary = option_v
		var id := str(option.get("id", ""))
		var libelle := str(option.get("label", id))
		var lettre := ""
		for c in libelle.to_upper():
			if c >= "A" and c <= "Z" and not lettres.has(c):
				lettre = c
				break
		lettres[lettre] = true
		var disponible := bool(option.get("disponible", true))
		var est_actif := str(actif.get("id", "")) == id
		var bouton := Button.new()
		bouton.name = "TeamShout_" + id
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.disabled = not disponible or est_actif
		bouton.tooltip_text = str(option.get("note", ""))
		bouton.custom_minimum_size.y = px(54)
		var normal := _boite(C.PANEL, C.GOLD if est_actif else C.LINE, 10, 2 if est_actif else 1, 0)
		normal.content_margin_left = px(12)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.bg_color = C.RAISED
		survol.border_color = C.IVORY
		var eteint := normal.duplicate() as StyleBoxFlat
		if not est_actif: eteint.bg_color = Color(C.PANEL, 0.6)
		var focus := _boite(Color.TRANSPARENT, C.GOLD, 10, 2, 0)
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", eteint], ["focus", focus]]: bouton.add_theme_stylebox_override(paire[0], paire[1])
		bouton.pressed.connect(func(): crier(id))
		var rangee := _h(10)
		rangee.position = Vector2(px(12), 0)
		rangee.size = Vector2(px(200 - 24), px(54))
		rangee.alignment = BoxContainer.ALIGNMENT_CENTER
		bouton.add_child(rangee)
		bouton.resized.connect(func(): rangee.size = Vector2(bouton.size.x - px(24), bouton.size.y))
		var usure := clampf(float(option.get("usure", 0.0)), 0.0, 1.0)
		var teinte := C.GOLD if est_actif else (C.FAINT if not disponible else (C.MINT if usure <= 0.0 else (C.GOLD if usure < 1.0 else C.ALERT)))
		var rond := _panneau(_boite(teinte, Color.TRANSPARENT, 16, 0, 0))
		rond.custom_minimum_size = Vector2(px(32), px(32))
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var marque := _titre(lettre, 17, C.BG, 800)
		marque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marque.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rond.add_child(marque)
		rangee.add_child(rond)
		var mots := _v(1)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mots.add_child(_coupe(_titre(libelle, 18, C.IVORY if disponible or est_actif else C.MUTED, 700)))
		var note := str(option.get("note", ""))
		if est_actif and actif.get("jusqua") != null: note = "Actif jusqu'à la %de" % int(actif.jusqua)
		if not note.is_empty(): mots.add_child(_coupe(_texte(note, 11, C.GOLD if est_actif or (usure > 0.0 and usure < 1.0) else (C.ALERT if usure >= 1.0 else C.MUTED))))
		rangee.add_child(mots)
		bouton.modulate.a = 1.0 if disponible or est_actif else 0.6
		colonne.add_child(bouton)

## Terrain rayé : quinze médaillons à leur poste, avants à gauche.
class Terrain extends Control:
	var k := 1.0
	var places: Dictionary = {}
	var voile: GradientTexture2D
	func _init() -> void:
		var degrade := Gradient.new()
		degrade.set_color(0, Color(0.949, 0.925, 0.863, 0.06))
		degrade.set_color(1, Color(0.043, 0.063, 0.071, 0.45))
		voile = GradientTexture2D.new()
		voile.gradient = degrade
		voile.fill = GradientTexture2D.FILL_RADIAL
		voile.fill_from = Vector2(0.5, 0.4)
		voile.fill_to = Vector2(1.05, 0.95)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: placer()
	func placer() -> void:
		for enfant in get_children():
			if not enfant is Control or not places.has(enfant): continue
			var c: Control = enfant
			var cible: Vector2 = places[enfant]
			var centre := Vector2(cible.x / 100.0 * size.x, cible.y / 100.0 * size.y)
			c.size = c.get_combined_minimum_size()
			c.position = Vector2(clampf(centre.x - c.size.x / 2.0, 2.0, maxf(2.0, size.x - c.size.x - 2.0)), clampf(centre.y - c.size.y / 2.0, 2.0, maxf(2.0, size.y - c.size.y - 2.0)))
	func _arrondi() -> PackedVector2Array:
		var r := minf(14.0 * k, minf(size.x, size.y) / 2.0)
		var points := PackedVector2Array()
		for coin: Array in [[Vector2(size.x - r, r), -PI / 2.0], [Vector2(size.x - r, size.y - r), 0.0], [Vector2(r, size.y - r), PI / 2.0], [Vector2(r, r), PI]]:
			for n in 7: points.append(coin[0] + Vector2.from_angle(float(coin[1]) + PI / 2.0 * n / 6.0) * r)
		return points
	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0: return
		var forme := _arrondi()
		var bande := 60.0 * k
		var x := 0.0
		var n := 0
		while x < size.x:
			var rect := PackedVector2Array([Vector2(x, 0), Vector2(minf(x + bande, size.x), 0), Vector2(minf(x + bande, size.x), size.y), Vector2(x, size.y)])
			for morceau: PackedVector2Array in Geometry2D.intersect_polygons(rect, forme):
				draw_colored_polygon(morceau, Color("1d4631") if n % 2 == 0 else Color("214e37"))
			x += bande
			n += 1
		# Voile de la maquette : plus clair au centre, assombri vers les bords.
		var uvs := PackedVector2Array()
		for point in forme: uvs.append(point / size)
		draw_colored_polygon(forme, Color.WHITE, uvs, voile)
		var epais := maxf(1.0, 2.0 * k)
		for paire: Array in [[0.05, 0.55, false], [0.27, 0.25, true], [0.5, 0.45, false], [0.73, 0.25, true], [0.95, 0.55, false]]:
			var lx := size.x * float(paire[0])
			var couleur := Color(0.949, 0.925, 0.863, float(paire[1]))
			if paire[2]: draw_dashed_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais, 8.0 * k)
			else: draw_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais)
		var bord := forme.duplicate()
		bord.append(forme[0])
		draw_polyline(bord, Color("53625e"), maxf(1.0, k), true)

## Médaillon d'un joueur : anneau d'énergie, portrait, numéro, niveau, nom et note, état.
class Medaillon extends Button:
	const C = preload("res://ui/immersive08/components.gd")
	var k := 1.0
	var energie := 100.0
	var teinte := C.MINT
	var numero := ""
	var niveau := ""
	var choisi := false
	var cible := false
	var calque: Control
	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]: add_theme_stylebox_override(etat, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	## Rayon extérieur de l'anneau (unités de la maquette) : visages bien lisibles (demande de Léo).
	const R := 37.0
	func centre() -> Vector2:
		return Vector2(size.x / 2.0, (R + 7.0) * k)
	func _draw() -> void:
		var c := centre()
		# Ombre portée douce : le médaillon se détache de la pelouse.
		draw_circle(c + Vector2(0, 3.0 * k), (R + 2.0) * k, Color(0, 0, 0, 0.28))
		if choisi: draw_circle(c, (R + 7.0) * k, Color(C.GOLD, 0.95))
		elif cible:
			draw_circle(c, (R + 6.0) * k, Color(C.MINT, 0.18))
			draw_arc(c, (R + 5.0) * k, 0, TAU, 64, C.MINT, 3.0 * k, true)
		elif is_hovered(): draw_circle(c, (R + 6.0) * k, Color(C.IVORY, 0.24))
		if has_focus() and not choisi: draw_arc(c, (R + 6.0) * k, 0, TAU, 64, C.GOLD, 2.0 * k, true)
		draw_circle(c, R * k, C.BG)
		draw_arc(c, (R - 2.5) * k, 0, TAU, 64, C.LINE, 5.0 * k, true)
		if energie > 0.0: draw_arc(c, (R - 2.5) * k, -PI / 2.0, -PI / 2.0 + TAU * clampf(energie / 100.0, 0.0, 1.0), 64, teinte, 5.0 * k, true)
		draw_circle(c, (R - 5.0) * k, C.BG)
	func dessiner_badges() -> void:
		var c := centre()
		var police: Font = C.EXTRA_BOLD
		var corps := maxi(10, roundi(16.0 * k))
		var rond := c + Vector2(-R + 6.0, R - 8.0) * k
		calque.draw_circle(rond, 14.0 * k, C.BG)
		calque.draw_arc(rond, 13.0 * k, 0, TAU, 32, C.GOLD, 2.0 * k, true)
		var largeur := police.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		calque.draw_string(police, rond + Vector2(-largeur / 2.0, (police.get_ascent(corps) - police.get_descent(corps)) / 2.0), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, C.IVORY)
		if niveau.is_empty(): return
		var corps_n := maxi(11, roundi(18.0 * k))
		var l := police.get_string_size(niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n).x
		var large := maxf(34.0 * k, l + 10.0 * k)
		var boite := Rect2(c + Vector2(R + 12.0, 0.0) * k - Vector2(large, (R + 7.0) * k), Vector2(large, 24.0 * k))
		var style := StyleBoxFlat.new()
		style.bg_color = C.GOLD
		style.set_corner_radius_all(maxi(2, roundi(6.0 * k)))
		style.border_color = C.BG
		style.set_border_width_all(maxi(1, roundi(2.0 * k)))
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = maxi(1, roundi(3.0 * k))
		style.anti_aliasing = true
		calque.draw_style_box(style, boite)
		calque.draw_string(police, Vector2(boite.position.x + (boite.size.x - l) / 2.0, boite.position.y + (boite.size.y + police.get_ascent(corps_n) - police.get_descent(corps_n)) / 2.0), niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n, C.BG)

func _terrain(centre: VBoxContainer) -> void:
	var cadre := Control.new()
	cadre.name = "TeamPitch"
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	centre.add_child(cadre)
	var terrain := Terrain.new()
	terrain.name = "TeamPitchField"
	terrain.k = k
	terrain.mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(terrain)
	cadre.add_child(terrain)
	var sens := _titre("SENS DE L'ATTAQUE ▸", 15, Color(C.IVORY, 0.7), 700)
	sens.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sens.offset_left = px(14)
	sens.offset_top = px(10)
	cadre.add_child(sens)
	var lineup := _lineup()
	var notes: Dictionary = _direct().get("notes", {}) if _direct().get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in _direct().get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var p := _pilotage()
	var cibles: Array = []
	if not entrant_choisi.is_empty():
		for slot in lineup.size():
			if _autorise(slot, entrant_choisi): cibles.append(slot)
	for slot in mini(15, lineup.size()):
		var joueur: Variant = lineup[slot]
		var medaillon := Medaillon.new()
		medaillon.name = "TeamPlayer%d" % (slot + 1)
		medaillon.k = k
		medaillon.numero = str(slot + 1)
		medaillon.choisi = poste_choisi == slot
		medaillon.cible = slot in cibles
		medaillon.custom_minimum_size.x = px(128)
		var pile := _v(3)
		pile.alignment = BoxContainer.ALIGNMENT_BEGIN
		pile.position = Vector2(0, px(2.0 * Medaillon.R + 16.0))
		pile.size = Vector2(px(128), 0)
		medaillon.add_child(pile)
		if joueur is Dictionary:
			var d := W.donnees_joueur(joueur, notes, cartons)
			var id := str(d.id)
			medaillon.energie = float(d.energie)
			medaillon.teinte = C.ALERT if bool(d.blesse) else teinte_energie(float(d.energie))
			medaillon.niveau = _niveau(joueur)
			var diametre := px(2.0 * (Medaillon.R - 6.0))
			var portrait := _portrait(joueur, diametre)
			portrait.position = Vector2((px(128) - diametre) / 2.0, px(Medaillon.R + 7.0) - diametre / 2.0)
			medaillon.add_child(portrait)
			var etiquette := _panneau(_boite(Color(C.BG, 0.85), Color.TRANSPARENT, 5, 0, 0))
			var style_et := etiquette.get_theme_stylebox("panel") as StyleBoxFlat
			style_et.content_margin_left = px(7)
			style_et.content_margin_right = px(7)
			etiquette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ligne := _h(5)
			etiquette.add_child(ligne)
			ligne.add_child(_titre(nom_court(str(d.nom)), 17, C.IVORY, 700))
			if notes.has(id):
				var note := _titre(("%.1f" % float(d.note)), 17, C.GOLD, 800)
				note.name = "TeamPlayerNote"
				ligne.add_child(note)
			pile.add_child(etiquette)
			var humeur := Pilotage.etat_joueur(p, id)
			var sens_humeur := Pilotage.sens_etat(str(humeur.get("etat", "")))
			var puce_texte := ""
			var puce_teinte := C.MINT
			if bool(d.blesse):
				puce_texte = "Blessé"
				puce_teinte = C.ALERT
			elif bool(d.carton):
				puce_texte = "Carton"
				puce_teinte = C.GOLD
			elif not humeur.is_empty() and sens_humeur != 0:
				puce_texte = str(humeur.label)
				puce_teinte = C.MINT if sens_humeur > 0 else C.ALERT
			if not puce_texte.is_empty():
				var puce := _panneau(_boite(puce_teinte, Color.TRANSPARENT, 9, 0, 0))
				puce.name = "TeamPlayerState"
				var style_p := puce.get_theme_stylebox("panel") as StyleBoxFlat
				style_p.content_margin_left = px(8)
				style_p.content_margin_right = px(8)
				puce.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
				puce.add_child(_texte(puce_texte, 11, C.BG, _gras))
				pile.add_child(puce)
			medaillon.tooltip_text = "%d · %s · %s\nÉnergie %d %%%s" % [slot + 1, str(d.poste), str(d.nom), roundi(float(d.energie)), ("\nNote du match %.1f" % float(d.note)) if notes.has(id) else ""]
			var eligibles := PackedStringArray()
			for x: Variant in _entrants(slot): eligibles.append(str(x))
			medaillon.set_drag_forwarding(Callable(), _peut_deposer.bind(eligibles), _deposer.bind(slot))
		else:
			medaillon.energie = 0.0
			pile.add_child(_titre("Poste vacant", 16, C.MUTED, 700))
			medaillon.tooltip_text = "%d · poste vacant" % (slot + 1)
		var calque := Control.new()
		calque.name = "Badges"
		calque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(calque)
		medaillon.add_child(calque)
		medaillon.calque = calque
		calque.draw.connect(medaillon.dessiner_badges)
		medaillon.pressed.connect(func(): choisir_poste(slot))
		if not entrant_choisi.is_empty() and not medaillon.cible: medaillon.modulate.a = 0.45
		medaillon.custom_minimum_size.y = px(2.0 * Medaillon.R + 16.0 + 50.0)
		terrain.add_child(medaillon)
		terrain.places[medaillon] = PLACES.get(slot + 1, Vector2(50, 50))
		medaillons[slot] = medaillon
	var aide := _panneau(_boite(Color(C.BG, 0.7), Color.TRANSPARENT, 12, 0, 0))
	aide.name = "TeamPitchHint"
	var style_aide := aide.get_theme_stylebox("panel") as StyleBoxFlat
	style_aide.content_margin_left = px(12)
	style_aide.content_margin_right = px(12)
	style_aide.content_margin_top = px(4)
	style_aide.content_margin_bottom = px(4)
	aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte_aide := "Glisse un remplaçant sur un joueur pour le changer · ou clique un joueur puis un remplaçant"
	var teinte_aide := Color(C.IVORY, 0.75)
	if not _message.is_empty():
		texte_aide = _message
		teinte_aide = _message_teinte
	elif poste_choisi >= 0 and poste_choisi < lineup.size() and lineup[poste_choisi] is Dictionary:
		var n := _entrants(poste_choisi).size()
		texte_aide = "%s choisi : %s" % [nom_court(str(lineup[poste_choisi].get("name", ""))), ("%d remplaçant%s possible%s, en vert sur le banc" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]) if n > 0 else ("aucun remplaçant autorisé à ce poste" if bool(_live().get("paused", false)) else "les changements se font match arrêté")]
	elif not entrant_choisi.is_empty():
		texte_aide = "%s prêt à entrer : clique le joueur à remplacer (cerclé de vert)" % nom_court(str(_reserve(entrant_choisi).get("name", "")))
	var ligne_aide := _texte(texte_aide, 12, teinte_aide)
	ligne_aide.name = "TeamStatus"
	aide.add_child(ligne_aide)
	aide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	aide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	aide.offset_bottom = -px(10)
	cadre.add_child(aide)
	terrain.placer.call_deferred()

func _fatigue(centre: VBoxContainer, p: Dictionary) -> void:
	var lignes: Variant = p.get("fatigue")
	if not lignes is Array or (lignes as Array).is_empty(): return
	var cadre := _panneau(_boite(C.PANEL, C.LINE, 12, 1, 0))
	cadre.name = "TeamFatigue"
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(16)
	style.content_margin_right = px(16)
	cadre.custom_minimum_size.y = px(92)
	centre.add_child(cadre)
	var rangee := _h(18)
	cadre.add_child(rangee)
	var tete := _v(0)
	tete.custom_minimum_size.x = px(140)
	tete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(_titre("DANS 10 MINUTES", 19, C.GOLD))
	var rythme := ""
	for axe_v: Variant in Pilotage.axes(p):
		if axe_v is Dictionary and str(axe_v.get("id", "")) == "rythme":
			for option: Variant in axe_v.get("options", []):
				if option is Dictionary and str(option.get("id", "")) == Pilotage.cran(p, axe_v): rythme = str(option.get("label", ""))
	if not rythme.is_empty(): tete.add_child(_texte("au rythme « %s »" % rythme, 11, C.MUTED))
	rangee.add_child(tete)
	var montres := 0
	for ligne_v: Variant in lignes:
		if montres >= 4 or not ligne_v is Dictionary: continue
		var ligne: Dictionary = ligne_v
		var id := str(ligne.get("id", ""))
		var slot := _poste_de(id)
		if slot < 0: continue
		montres += 1
		var joueur: Dictionary = _lineup()[slot]
		var avant := roundi(float(ligne.get("condition", joueur.get("condition", 0))))
		var apres := roundi(float(ligne.get("prevue", avant)))
		var teinte := teinte_energie(apres)
		var bloc := _h(10)
		bloc.name = "TeamFatigue_" + id
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.size_flags_stretch_ratio = 1.0
		bloc.alignment = BoxContainer.ALIGNMENT_CENTER
		var anneau := _panneau(_boite(Color.TRANSPARENT, teinte, 22, 2, 2))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(joueur, px(40)))
		bloc.add_child(anneau)
		var mots := _v(4)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mots.add_child(_coupe(_texte("%s (%d)" % [nom_court(str(joueur.get("name", ""))), slot + 1], 13, C.IVORY, _gras)))
		var bas := _h(6)
		var barre := Barre.new()
		barre.avant = avant
		barre.apres = apres
		barre.teinte = teinte
		barre.custom_minimum_size.y = px(6)
		barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bas.add_child(barre)
		bas.add_child(_texte("%d → %d %%" % [avant, apres], 12, teinte))
		mots.add_child(bas)
		bloc.add_child(mots)
		bloc.tooltip_text = "%s : énergie %d %% maintenant, %d %% prévue dans 10 minutes." % [str(joueur.get("name", "")), avant, apres]
		rangee.add_child(bloc)
	if montres == 0: cadre.queue_free()

class Barre extends Control:
	const C = preload("res://ui/immersive08/components.gd")
	var avant := 0
	var apres := 0
	var teinte := C.MINT
	func _draw() -> void:
		var r := size.y / 2.0
		_piste(size.x, C.LINE, r)
		_piste(size.x * clampf(avant / 100.0, 0, 1), Color(C.IVORY, 0.25), r)
		_piste(size.x * clampf(apres / 100.0, 0, 1), teinte, r)
	func _piste(largeur: float, couleur: Color, r: float) -> void:
		if largeur <= 0.0: return
		var style := StyleBoxFlat.new()
		style.bg_color = couleur
		style.set_corner_radius_all(maxi(1, roundi(r)))
		draw_style_box(style, Rect2(0, 0, largeur, size.y))

func _banc(p: Dictionary) -> void:
	var colonne := _v(10)
	colonne.name = "TeamBench"
	_poser(colonne, 1156, 96, 420, 708)
	var tete := _h(8)
	var titre := _titre("LE BANC", 22, C.IVORY)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var reserves := _reserves()
	var restants: Variant = _live().get("remplacementsRestants", _live().get("substitutionsLeft"))
	var precision := ("%d changement%s restant%s" % [int(restants), "s" if int(restants) > 1 else "", "s" if int(restants) > 1 else ""]) if restants is int or restants is float else "%d remplaçant%s" % [reserves.size(), "s" if reserves.size() > 1 else ""]
	tete.add_child(_texte(precision, 12, C.MUTED))
	colonne.add_child(tete)
	var grille := GridContainer.new()
	grille.name = "TeamBenchGrid"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", px(8))
	grille.add_theme_constant_override("v_separation", px(8))
	colonne.add_child(grille)
	var conseil := _conseil(p)
	var autorises := PackedStringArray()
	if poste_choisi >= 0:
		for x: Variant in _entrants(poste_choisi): autorises.append(str(x))
	var tous: Dictionary = {}
	for option: Variant in _live().get("substitutions", []):
		if option is Dictionary:
			for x: Variant in option.get("inIds", []): tous[str(x)] = true
	for n in reserves.size():
		var joueur: Variant = reserves[n]
		if not joueur is Dictionary: continue
		var id := str(joueur.get("id", ""))
		var eligible: bool = autorises.has(id) if poste_choisi >= 0 else tous.has(id)
		var choisi := entrant_choisi == id
		var conseille := not conseil.is_empty() and str(conseil.get("inId", "")) == id
		grille.add_child(_tuile(joueur, 16 + n, eligible, choisi, conseille))
	if not conseil.is_empty(): _carte_conseil(colonne, conseil)

func _tuile(joueur: Dictionary, numero: int, eligible: bool, choisi: bool, conseille: bool) -> Button:
	var id := str(joueur.get("id", ""))
	var tuile := Button.new()
	tuile.name = "TeamBench%d" % numero
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuile.custom_minimum_size = Vector2(0, px(68))
	tuile.clip_contents = true
	var bord := C.MINT if eligible and poste_choisi >= 0 else (C.GOLD if choisi or conseille else C.LINE)
	var normal := _boite(C.RAISED if choisi else C.PANEL, bord, 10, 2 if choisi else 1, 8)
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = C.RAISED
	survol.border_color = C.IVORY
	var focus := _boite(Color.TRANSPARENT, C.GOLD, 10, 2, 8)
	for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: tuile.add_theme_stylebox_override(paire[0], paire[1])
	var rangee := _h(8)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	S.full(rangee)
	rangee.offset_left = px(8)
	rangee.offset_right = -px(8)
	rangee.offset_top = px(8)
	rangee.offset_bottom = -px(8)
	tuile.add_child(rangee)
	var portrait := _portrait(joueur, px(52), px(58), 8)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(portrait)
	var mots := _v(2)
	mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var haut := _h(4)
	haut.add_child(_coupe(_titre("%d · %s" % [numero, nom_court(str(joueur.get("name", "")))], 16, C.IVORY, 700)))
	var niveau := _niveau(joueur)
	if not niveau.is_empty():
		var badge := _titre(niveau, 16, C.GOLD, 800)
		badge.name = "TeamBenchLevel"
		haut.add_child(badge)
	mots.add_child(haut)
	mots.add_child(_coupe(_texte(str(joueur.get("pos", "")), 11, C.MUTED)))
	var condition := roundi(float(joueur.get("condition", 100)))
	var info := ""
	var teinte := C.MUTED
	for cle: String in ["conseil", "info", "hint", "note"]:
		if joueur.get(cle) is String and not str(joueur.get(cle)).is_empty():
			info = str(joueur.get(cle))
			teinte = C.GOLD
			break
	if int(joueur.get("injury", 0)) > 0:
		info = "Blessé"
		teinte = C.ALERT
	elif info.is_empty():
		info = "Prêt · %d %%" % condition if condition >= 95 else "Énergie %d %%" % condition
		teinte = C.MINT if condition >= 75 else C.GOLD
	mots.add_child(_coupe(_texte(info, 11, teinte)))
	rangee.add_child(mots)
	tuile.custom_minimum_size.y = maxf(px(72), rangee.get_combined_minimum_size().y + px(16))
	tuile.tooltip_text = "%d · %s · %s\n%s" % [numero, str(joueur.get("pos", "")), str(joueur.get("name", "")), info]
	if not eligible and not choisi: tuile.modulate.a = 0.4
	tuile.set_meta("eligible", eligible)
	tuile.pressed.connect(func(): choisir_entrant(id))
	tuile.set_drag_forwarding(_glisser.bind(joueur, tuile), Callable(), Callable())
	tuiles[id] = tuile
	return tuile

## Conseil de changement de Gabi, s'il désigne un joueur du XV et un remplaçant du banc (et pas écarté).
func _conseil(p: Dictionary) -> Dictionary:
	var conseil: Variant = p.get("conseilChangement")
	if not conseil is Dictionary: return {}
	var cle := "%s>%s" % [str(conseil.get("outId", "")), str(conseil.get("inId", ""))]
	if cle == _conseil_ecarte or _poste_de(str(conseil.get("outId", ""))) < 0 or _reserve(str(conseil.get("inId", ""))).is_empty(): return {}
	return conseil

func _carte_conseil(colonne: VBoxContainer, conseil: Dictionary) -> void:
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(vide)
	var cadre := _panneau(_boite(C.PANEL, C.GOLD, 12, 1, 14))
	cadre.name = "TeamAdvice"
	colonne.add_child(cadre)
	var pile := _v(10)
	cadre.add_child(pile)
	pile.add_child(_texte("GABI CONSEILLE", 12, C.GOLD, _gras))
	var out_id := str(conseil.get("outId", ""))
	var in_id := str(conseil.get("inId", ""))
	var slot := _poste_de(out_id)
	# Poste donné par le moteur (`conseilChangement.slot`) s'il désigne bien le sortant.
	var poste_moteur: Variant = conseil.get("slot")
	if (poste_moteur is int or poste_moteur is float) and int(poste_moteur) >= 0 and int(poste_moteur) < _lineup().size() and _lineup()[int(poste_moteur)] is Dictionary and str(_lineup()[int(poste_moteur)].get("id", "")) == out_id: slot = int(poste_moteur)
	var sortant: Dictionary = _lineup()[slot]
	var entrant := _reserve(in_id)
	var rangee := _h(12)
	for paire: Array in [[sortant, C.ALERT], [entrant, C.MINT]]:
		var anneau := _panneau(_boite(Color.TRANSPARENT, paire[1], 27, 3, 3))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(paire[0], px(48)))
		rangee.add_child(anneau)
		if paire[1] == C.ALERT:
			var fleche := _titre("⇄", 26, C.GOLD)
			fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rangee.add_child(fleche)
	var texte := str(conseil.get("texte", ""))
	if texte.is_empty(): texte = "%s (%d) est à bout. %s est frais." % [nom_court(str(sortant.get("name", ""))), slot + 1, nom_court(str(entrant.get("name", "")))]
	var phrase := _texte(texte, 13, C.IVORY)
	phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phrase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phrase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phrase.max_lines_visible = 4
	rangee.add_child(phrase)
	pile.add_child(rangee)
	var boutons := _h(8)
	var faire := _bouton("Faire entrer %s" % nom_court(str(entrant.get("name", ""))), func(): remplacer(slot, in_id), "menthe", 17, "TeamAdviceApply")
	faire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faire.disabled = not _autorise(slot, in_id)
	if faire.disabled: faire.tooltip_text = "Changement possible match arrêté, selon les règles du banc."
	boutons.add_child(faire)
	boutons.add_child(_bouton("Plus tard", _plus_tard.bind("%s>%s" % [out_id, in_id]), "transparent", 17, "TeamAdviceLater"))
	pile.add_child(boutons)

func _peut_deposer(_a: Vector2, data: Variant, eligibles: PackedStringArray) -> bool:
	return data is Dictionary and eligibles.has(str(data.get("equipe_entrant", "")))

func _deposer(_a: Vector2, data: Variant, slot: int) -> void:
	if data is Dictionary: remplacer(slot, str(data.get("equipe_entrant", "")))

## Glisser un remplaçant : son portrait suit la souris, les joueurs qu'il peut remplacer sont cerclés.
func _glisser(_a: Vector2, joueur: Dictionary, tuile: Control) -> Variant:
	var apercu := _portrait(joueur, px(56))
	apercu.modulate.a = 0.9
	tuile.set_drag_preview(apercu)
	return {"equipe_entrant": str(joueur.get("id", ""))}

func _plus_tard(cle: String) -> void:
	_conseil_ecarte = cle
	_cle = ""
	_rafraichir()

func _choisir_cran(crans: Control, axe: String, valeur: String) -> void:
	if str(crans.get_meta("cran", "")) == valeur: return
	crans.set_meta("cran", valeur)
	_envoyer_consigne(axe, valeur)

# --- Onglet Consignes ------------------------------------------------------------

## Groupes de l'onglet Consignes (décision de Léo, 18/11/2026), dans cet ordre ; deux colonnes :
## Attaque et Défense à gauche, Conquête et Adversaire à droite. Libellés : `live.pilotage.groupes`.
const GROUPES := [["attaque", "Attaque", "avec le ballon"], ["defense", "Défense", "sans le ballon"], ["conquete", "Conquête", "phases arrêtées"], ["adversaire", "Adversaire", "leurs points faibles"]]

## Cran sans effet d'un axe : `neutre` du moteur, sinon le premier cran « équilibré / contexte / aucun »
## pour le plan de jeu et le point faible, sinon le cran du milieu.
static func cran_neutre(axe: Dictionary) -> String:
	if not str(axe.get("neutre", "")).is_empty(): return str(axe.neutre)
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	if options.is_empty(): return ""
	if bool(axe.get("pause", false)) or str(axe.get("id", "")) == "cible":
		for option: Variant in options:
			var id := str(option.get("id", "")) if option is Dictionary else ""
			if id.begins_with("equilibr") or id in ["contexte", "context", "aucune", "aucun", "normal"]: return id
		return str(options[0].get("id", ""))
	return str(options[1 if options.size() >= 3 else 0].get("id", ""))

func _consignes() -> void:
	var p := _pilotage()
	var envois: Dictionary = view.get("_envois_consignes") if view != null and view.get("_envois_consignes") is Dictionary else {}
	var vue := Pilotage.avec_envois(p, envois)
	var section := _panneau(_boite(C.PANEL, C.GOLD, 14, 1, 0))
	section.name = "TeamConsignes"
	var style := section.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(20)
	style.content_margin_right = px(20)
	style.content_margin_top = px(16)
	style.content_margin_bottom = px(16)
	_poser(section, 24, 96, 1110, 708)
	var axes := Pilotage.axes(vue).filter(func(a: Variant) -> bool: return a is Dictionary)
	# Une seule zone qui défile, et seulement si les groupes ne tiennent pas (petites fenêtres).
	var defile := ScrollContainer.new()
	defile.name = "TeamConsignesScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	section.add_child(defile)
	var deux := _h(24)
	deux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(deux)
	var gauche := _v(6)
	var droite := _v(6)
	for c: VBoxContainer in [gauche, droite]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deux.add_child(c)
	gauche.name = "TeamConsignesLeft"
	droite.name = "TeamConsignesRight"
	if axes.is_empty():
		var rien := _texte("Les consignes en direct ne sont pas disponibles pour cette rencontre.", 14, C.MUTED)
		rien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gauche.add_child(rien)
	var libelles := {}
	for g: Variant in p.get("groupes", []) if p.get("groupes") is Array else []:
		if g is Dictionary: libelles[str(g.get("id", ""))] = str(g.get("label", ""))
	if axes.any(func(a: Dictionary) -> bool: return not str(a.get("groupe", "")).is_empty()):
		for n in GROUPES.size():
			var id_groupe: String = GROUPES[n][0]
			var membres := axes.filter(func(a: Dictionary) -> bool: return str(a.get("groupe", "")) == id_groupe)
			if membres.is_empty(): continue
			var cible: VBoxContainer = gauche if n < 2 else droite
			var bloc := _v(6)
			bloc.name = "TeamGroup_" + id_groupe
			cible.add_child(bloc)
			bloc.add_child(_entete_groupe(str(libelles.get(id_groupe, GROUPES[n][1])).to_upper(), str(GROUPES[n][2])))
			for axe: Dictionary in membres: bloc.add_child(_axe(vue, axe))
			if n % 2 == 0: cible.add_child(_espace(8))
		# Axe d'un groupe inconnu : en fin de colonne de droite, jamais perdu.
		var connus: Array = GROUPES.map(func(g: Array) -> String: return g[0])
		for axe: Dictionary in axes:
			if not str(axe.get("groupe", "")) in connus: droite.add_child(_axe(vue, axe))
	else:
		# Moteur sans groupes : les axes sous un seul titre, le plan de jeu d'avant à droite.
		gauche.add_child(_entete_groupe("EN DIRECT", "sans arrêter le match"))
		for axe: Dictionary in axes: gauche.add_child(_axe(vue, axe))
		droite.add_child(_entete_groupe("PLAN DE JEU", "match arrêté"))
		_plan_de_jeu(droite)
	var aside := _v(14)
	aside.name = "TeamConsignesAside"
	_poser(aside, 1150, 96, 426, 708)
	_carte_arbitre(aside, p)
	_carte_adversaire(aside, p, vue)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.add_child(vide)
	_carte_staff(aside, p)
	_pied(_pied_consignes, ["Retour à la composition", choisir_onglet.bind("composition"), "TeamToComposition"])

func _espace(hauteur: float) -> Control:
	var vide := Control.new()
	vide.custom_minimum_size.y = px(hauteur)
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vide

func _entete_groupe(texte: String, sous: String) -> Control:
	var colonne := _v(4)
	var rangee := _h(10)
	var t := _titre(texte, 22, C.GOLD, 800)
	rangee.add_child(t)
	var precision := _texte(sous, 11, C.MUTED)
	precision.size_flags_vertical = Control.SIZE_SHRINK_END
	rangee.add_child(precision)
	colonne.add_child(rangee)
	var filet := ColorRect.new()
	filet.color = C.LINE
	filet.custom_minimum_size = Vector2(0, maxf(1.0, k))
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(filet)
	return colonne

## Conseil du staff (dernière entrée du staff dans le journal du pilotage), en bas de la colonne.
func _carte_staff(parent: Control, p: Dictionary) -> void:
	var journal: Array = p.get("journal") if p.get("journal") is Array else []
	var staff: Array = journal.filter(func(e: Variant) -> bool: return e is Dictionary and str(e.get("auteur", "")) == "staff")
	var conseil: Variant = p.get("conseilStaff")
	var texte := ""
	if conseil is Dictionary: texte = str(conseil.get("texte", ""))
	elif conseil is String: texte = conseil
	elif not staff.is_empty(): texte = "%d′ · %s" % [int(staff[-1].get("minute", 0)), str(staff[-1].get("texte", ""))]
	if texte.is_empty(): return
	var cadre := _panneau(_boite(C.PANEL, C.GOLD, 14, 1, 14))
	cadre.name = "TeamStaffNote"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_texte("LE STAFF CONSEILLE" if conseil != null else "LE STAFF", 11, C.GOLD, _gras))
	var corps := _texte(texte, 14, C.IVORY)
	corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corps.max_lines_visible = 4
	colonne.add_child(corps)

func _pied_consignes(infos: HBoxContainer) -> void:
	infos.add_child(_coupe(_texte("Les consignes en direct s'appliquent dès la reprise ; le plan de jeu demande l'arrêt du match.", 13, C.MUTED)))

## Ligne d'un axe : libellé (et « match en pause » pour le plan de jeu), crans ; fond relevé et bilan
## dessous quand le cran en place n'est pas neutre.
func _axe(p: Dictionary, axe: Dictionary) -> Control:
	var id := str(axe.get("id", ""))
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var actuel := Pilotage.cran(p, axe)
	var modifie := not actuel.is_empty() and actuel != cran_neutre(axe)
	var en_pause_seulement := bool(axe.get("pause", false)) or id in ["planAttaque", "systemeDefense", "penalites"]
	var cadre := _panneau(_boite(C.RAISED if modifie else Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 0))
	cadre.name = "Consigne_" + id
	cadre.set_meta("modifie", modifie)
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(8)
	style.content_margin_right = px(8)
	style.content_margin_top = px(6)
	style.content_margin_bottom = px(6)
	var pile := _v(3)
	cadre.add_child(pile)
	var rangee := _h(10)
	pile.add_child(rangee)
	var gauche := _v(0)
	gauche.custom_minimum_size.x = px(112)
	gauche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var aide := str(axe.get("aide", ""))
	var libelle := _coupe(_titre(str(axe.get("label", id)), 17, C.IVORY, 700))
	libelle.tooltip_text = aide
	libelle.mouse_filter = Control.MOUSE_FILTER_PASS
	gauche.add_child(libelle)
	if en_pause_seulement:
		var note := _texte("match en pause", 10, C.MUTED)
		note.name = "ConsignePause"
		gauche.add_child(note)
	cadre.tooltip_text = aide
	rangee.add_child(gauche)
	var crans := _h(4)
	crans.name = "Consigne_%s_Crans" % id
	crans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crans.set_meta("cran", actuel)
	var fini := bool(_live().get("finished", false))
	var en_pause := bool(_live().get("paused", false))
	for option_v: Variant in options:
		if not option_v is Dictionary: continue
		var valeur := str(option_v.get("id", ""))
		var choisi := valeur == actuel
		var texte := str(option_v.get("label", valeur))
		var long := options.size() > 3
		var bouton := _bouton(texte, _choisir_cran.bind(crans, id, valeur), "or" if choisi else "cadre", 13 if long else 15, "Consigne_%s_%s" % [id, valeur])
		bouton.set_meta("axe", id)
		bouton.set_meta("valeur", valeur)
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.custom_minimum_size = Vector2(0, px(32))
		# Quatre crans aux libellés longs (pénalités, plan de jeu) : sur deux lignes plutôt que tronqués.
		if long: bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			bouton.clip_text = true
			bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bouton.tooltip_text = texte + ("\n" + aide if not aide.is_empty() else "")
		for etat: String in ["normal", "hover", "pressed", "disabled"]:
			var boite := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			boite.set_corner_radius_all(maxi(2, px(6)))
			boite.content_margin_left = px(2)
			boite.content_margin_right = px(2)
			boite.content_margin_top = px(6)
			boite.content_margin_bottom = px(6)
		if not choisi:
			var normal := bouton.get_theme_stylebox("normal") as StyleBoxFlat
			normal.bg_color = C.BG
			normal.border_color = C.LINE
			normal.set_border_width_all(maxi(1, px(1)))
		bouton.disabled = fini or (en_pause_seulement and not en_pause)
		if en_pause_seulement and not en_pause: bouton.tooltip_text += "\nChangement possible match arrêté."
		crans.add_child(bouton)
	rangee.add_child(crans)
	var bilan := bilan_court(p, id)
	if modifie and not bilan.is_empty():
		var ligne := _coupe(_texte(bilan, 12, C.GOLD))
		ligne.name = "ConsigneBilan"
		ligne.tooltip_text = bilan
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		var decale := MarginContainer.new()
		decale.add_theme_constant_override("margin_left", px(122))
		decale.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decale.add_child(ligne)
		pile.add_child(decale)
	return cadre

## Plan de jeu (tiroir Tactique d'avant) : avec le ballon, sans le ballon, sur pénalité, en une rangée.
func _plan_de_jeu(colonne: VBoxContainer) -> void:
	var tactiques: Dictionary = _model.get("tactics", {}) if _model.get("tactics") is Dictionary else {}
	if tactiques.is_empty(): return
	var cadre := _panneau(_boite(C.RAISED, Color.TRANSPARENT, 10, 0, 0))
	cadre.name = "TeamGamePlan"
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(14)
	style.content_margin_right = px(14)
	style.content_margin_top = px(10)
	style.content_margin_bottom = px(10)
	colonne.add_child(cadre)
	var rangee := _h(10)
	cadre.add_child(rangee)
	var titre := _texte("PLAN DE JEU", 12, C.GOLD, _gras)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(titre)
	var autorise: bool = bool(_live().get("paused", false)) and not bool(_live().get("finished", false))
	for trio: Array in [["attack", "attacks", "Avec le ballon", "TeamPlanAttack"], ["defense", "defenses", "Sans le ballon", "TeamPlanDefense"], ["penalty", "penalties", "Sur pénalité", "TeamPlanPenalty"]]:
		var options: Array = tactiques.get(trio[1], []) if tactiques.get(trio[1]) is Array else []
		if options.is_empty(): continue
		var bloc := _v(2)
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.add_child(_texte(trio[2], 11, C.MUTED))
		var choix := OptionButton.new()
		choix.name = trio[3]
		choix.fit_to_longest_item = false
		choix.clip_text = true
		choix.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choix.add_theme_font_override("font", C.font(700))
		choix.add_theme_font_size_override("font_size", fs(16))
		var normal := _boite(C.PANEL, C.LINE, 8, 1, 0)
		normal.content_margin_left = px(10)
		normal.content_margin_right = px(10)
		normal.content_margin_top = px(5)
		normal.content_margin_bottom = px(5)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.border_color = C.IVORY
		var focus := _boite(Color.TRANSPARENT, C.GOLD, 8, 2, 0)
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: choix.add_theme_stylebox_override(paire[0], paire[1])
		for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: choix.add_theme_color_override(cle, C.IVORY)
		choix.get_popup().add_theme_font_size_override("font_size", fs(16))
		var ids: Array = []
		for option: Variant in options:
			if not option is Dictionary: continue
			choix.add_item(str(option.get("label", "")))
			choix.set_item_tooltip(choix.item_count - 1, str(option.get("description", "")))
			ids.append(option.get("id"))
		var cle_plan: String = trio[0]
		var courant: Variant = tactiques.get(cle_plan)
		choix.select(maxi(0, ids.find(courant)))
		choix.disabled = not autorise
		choix.tooltip_text = "Mets le match en pause pour changer le plan de jeu." if not autorise else str(trio[2])
		choix.item_selected.connect(_choisir_plan.bind(cle_plan, ids))
		bloc.add_child(choix)
		rangee.add_child(bloc)

func _choisir_plan(index: int, cle_plan: String, ids: Array) -> void:
	if index < 0 or index >= ids.size(): return
	if cle_plan == "penalty": app._command("set_penalty_policy", {"policy": ids[index]})
	else: _plan(cle_plan, ids[index])

## Carte de l'arbitre : photo à gauche, nom, quatre jauges de sévérité (1 à 5) et son profil.
func _carte_arbitre(parent: Control, p: Dictionary) -> void:
	var arbitre: Dictionary = p.get("arbitre") if p.get("arbitre") is Dictionary else {}
	var cadre := PanelContainer.new()
	cadre.name = "TeamReferee"
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cadre.add_theme_stylebox_override("panel", _boite(C.PANEL, C.LINE, 14, 1, 0))
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(cadre)
	var rangee := _h(0)
	cadre.add_child(rangee)
	var nom := str(arbitre.get("nom", ""))
	var cadre_photo := Control.new()
	cadre_photo.custom_minimum_size = Vector2(px(130), px(190))
	cadre_photo.clip_contents = true
	cadre_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(cadre_photo)
	if BanqueImages.texture("arbitre") != null:
		var photo := C.photo("arbitre", Vector2.ZERO, true, 0.2)
		photo.name = "TeamRefereePhoto"
		photo.tooltip_text = ""
		S.full(photo)
		cadre_photo.add_child(photo)
	else:
		var lettres := PackedStringArray()
		for mot in nom.split(" ", false): lettres.append(mot.substr(0, 1))
		var initiales := _titre("".join(lettres), 48, C.GOLD)
		initiales.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cadre_photo.add_child(initiales)
	var marge := MarginContainer.new()
	for cote: String in ["left", "right"]: marge.add_theme_constant_override("margin_" + cote, px(14))
	for cote: String in ["top", "bottom"]: marge.add_theme_constant_override("margin_" + cote, px(12))
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(marge)
	var corps := _v(6)
	marge.add_child(corps)
	corps.add_child(_texte("L'ARBITRE", 11, C.GOLD, _gras))
	var ligne_nom := _coupe(_titre(nom if not nom.is_empty() else "Non désigné", 24, C.IVORY))
	ligne_nom.name = "TeamRefereeName"
	ligne_nom.tooltip_text = (str(arbitre.get("civilite", "")) + " " + nom).strip_edges() + ("\n" + str(arbitre.get("resume", "")) if arbitre.has("resume") else "")
	ligne_nom.mouse_filter = Control.MOUSE_FILTER_PASS
	corps.add_child(ligne_nom)
	for paire: Array in ARBITRE_AXES:
		var niveau := clampi(int(arbitre.get(paire[0], 3)), 1, 5)
		var jauge := _h(8)
		jauge.name = "TeamRefereeGauge_" + str(paire[0])
		jauge.set_meta("niveau", niveau)
		var axe := _texte(paire[1], 12, C.MUTED)
		axe.custom_minimum_size.x = px(58)
		jauge.add_child(axe)
		var crans := _h(2)
		crans.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for n in 5:
			var cran := Panel.new()
			cran.custom_minimum_size = Vector2(px(12), px(8))
			cran.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cran.add_theme_stylebox_override("panel", _boite(C.GOLD if n < niveau else C.LINE, Color.TRANSPARENT, 2, 0, 0))
			crans.add_child(cran)
		jauge.add_child(crans)
		jauge.add_child(_coupe(_texte(ARBITRE_MOTS[niveau], 12, C.ALERT if niveau >= 4 else (C.MINT if niveau <= 2 else C.MUTED))))
		corps.add_child(jauge)
	var resume := _texte(str(arbitre.get("resume", "")), 12, C.GOLD)
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume.max_lines_visible = 2
	corps.add_child(resume)

func _carte_adversaire(parent: Control, p: Dictionary, vue: Dictionary) -> void:
	var equipes: Array = _live().get("teams", [])
	var club_id := str(_model.get("club", {}).get("id", "")) if _model.get("club") is Dictionary else ""
	var adverse := {}
	for equipe: Variant in equipes:
		if equipe is Dictionary and str(equipe.get("id", "")) != club_id: adverse = equipe
	var nom := S.G.club_name(adverse).to_upper() if not adverse.is_empty() else "L'ADVERSAIRE"
	var cadre := _panneau(_boite(C.PANEL, C.LINE, 14, 1, 14))
	cadre.name = "TeamOpponent"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_coupe(_titre("CE QUE FAIT " + nom, 19, C.IVORY)))
	var source: Dictionary = p.get("adversaire") if p.get("adversaire") is Dictionary else {}
	var puces := HFlowContainer.new()
	puces.name = "TeamOpponentChips"
	puces.add_theme_constant_override("h_separation", px(6))
	puces.add_theme_constant_override("v_separation", px(6))
	puces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var consignes: Variant = source.get("consignes")
	if consignes is Dictionary:
		for axe_v: Variant in Pilotage.axes(vue):
			if not axe_v is Dictionary or not (consignes as Dictionary).has(str(axe_v.get("id", ""))): continue
			var valeur := str(consignes[str(axe_v.id)])
			if valeur == cran_neutre(axe_v): continue
			for option: Variant in axe_v.get("options", []):
				if option is Dictionary and str(option.get("id", "")) == valeur:
					var dur := str(axe_v.id) in ["rucks", "discipline", "melee"]
					puces.add_child(_puce("%s · %s" % [str(axe_v.label), str(option.label)], C.ALERT if dur else C.IVORY, C.ALERT if dur else C.LINE, 12))
	elif consignes is Array:
		for c: Variant in consignes:
			var texte := str(c.get("label", c.get("texte", ""))) if c is Dictionary else str(c)
			if not texte.is_empty(): puces.add_child(_puce(texte, C.IVORY, C.LINE, 12))
	var causeries: Variant = source.get("causeries")
	if causeries is Dictionary:
		for paire: Array in [["pre", "Avant-match"], ["half", "Pause"]]:
			var c: Variant = (causeries as Dictionary).get(paire[0])
			if c is Dictionary and not str(c.get("label", "")).is_empty(): puces.add_child(_puce("%s : discours %s" % [paire[1], str(c.label).to_lower()], C.IVORY, C.LINE, 12))
	if puces.get_child_count() > 0: colonne.add_child(puces)
	var lignes: Array = []
	for cle: String in ["derniers", "journal", "lignes"]:
		if source.get(cle) is Array:
			var liste: Array = source[cle]
			for k_ in range(liste.size() - 1, -1, -1):
				var ligne: Variant = liste[k_]
				if ligne is Dictionary and not str(ligne.get("texte", "")).is_empty(): lignes.append(("%d′ " % int(ligne.minute) if ligne.get("minute") != null else "") + str(ligne.texte).trim_suffix("."))
				elif ligne is String and not ligne.is_empty(): lignes.append(ligne)
			break
	if not lignes.is_empty():
		var l := _texte(" · ".join(PackedStringArray(lignes.slice(0, 3))), 12, C.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 3
		colonne.add_child(l)
	if puces.get_child_count() == 0 and lignes.is_empty():
		var rien := _texte("Le staff n'a rien repéré de marquant chez eux pour l'instant.", 12, C.MUTED)
		rien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		colonne.add_child(rien)
	var lecture := str(source.get("lecture", ""))
	if not lecture.is_empty():
		var l := _texte(lecture, 12, C.MINT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 3
		colonne.add_child(l)

## Débordements : tout bloc visible reste dans la fenêtre et chaque texte non coupé dans son parent.
func debordements() -> Array[String]:
	var echecs: Array[String] = []
	var cadre := get_global_rect().grow(1)
	for c: Control in find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.size.x <= 0.0: continue
		if c.name == "Portrait" or c.get_parent().name == "Portrait": continue
		var r := c.get_global_rect()
		# Contenu d'une zone qui défile : jugé par la zone elle-même (il peut dépasser, il défile).
		var defile := false
		var parent := c.get_parent()
		while parent != null and parent != self:
			if parent is ScrollContainer: defile = true
			parent = parent.get_parent()
		if not defile and not cadre.encloses(r): echecs.append("%s hors fenêtre %s" % [c.name, r])
		if c is Label and not (c as Label).clip_text and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var l := c as Label
			var police: Font = l.get_theme_font("font")
			var besoin := police.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			if besoin > l.size.x + 2.0: echecs.append("texte coupé « %s » (%d > %d)" % [l.text, roundi(besoin), roundi(l.size.x)])
	return echecs
