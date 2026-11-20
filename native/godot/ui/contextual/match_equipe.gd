extends Control
## Fenêtre « Équipe » du match en direct (maquette retenue par Léo le 18/11/2026, façon FM) : un seul
## bouton « ÉQUIPE » remplace Tactique et Banc. Elle couvre l'écran, met le match en pause à l'ouverture
## et le relance avec « Valider et reprendre ». Trois onglets :
## - Composition : cris de la touche, terrain avec les quinze en médaillons (portrait, anneau d'énergie,
##   niveau, numéro, note du match, état après la causerie), « Dans 10 minutes », le banc en tuiles,
##   le conseil de Gabi, et en pied les consignes en place et l'arbitre ;
## - Consignes : les cinq axes en direct (set_consignes), le plan de jeu (set_tactics, set_penalty_policy),
##   l'arbitre et ses quatre jauges, ce que fait l'adversaire et l'avis du staff (« Appliquer ces consignes ») ;
## - Rôles : buteur, buteur de secours, lanceur en touche et botteur, changés en direct (set_role_direct).
## L'écran n'invente rien : tout vient du modèle (`live`, `live.pilotage`, `live.direct.notes`, `squad`) et
## chaque champ optionnel absent masque son bloc. Les règles du banc (première ligne, cartons) restent au
## moteur : un refus s'affiche en une ligne sous le terrain.
const FocusLater = preload("res://ui/focus_later.gd")
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/contextual/skin.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const W = preload("res://ui/contextual/match_tableau_widgets.gd")
const BanqueImages = preload("res://ui/banque_images.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")

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
## « composition », « consignes » ou « roles ».
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
var _pied_ligne2: HBoxContainer  ## Seconde ligne du pied (arbitre) ; vide sur l'onglet Consignes.
var _gras: FontVariation

func _ready() -> void:
	name = "MatchTeamPage"
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
	onglet = vers if vers in ["consignes", "roles"] else "composition"
	poste_choisi = poste
	entrant_choisi = ""
	_message = ""
	_veut_reprise = false
	_veut_pause = true
	show()
	_cle = ""
	_rafraichir()
	var reprise: Control = find_child("TeamResume", true, false)
	# Focus au tour suivant, seulement si le bouton est encore dans l'arbre (la page peut être reconstruite entre-temps).
	if reprise != null: FocusLater.grab(reprise)

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
	if valeur >= 60.0: return C.IVORY
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

## « Appliquer ces consignes » : l'avis du staff en attente, en une commande, sans pause.
func appliquer_staff() -> void:
	if app._command("appliquer_staff", {}):
		_attente = "staff"
		_succes = "Consignes du staff appliquées."
	_cle = ""
	_rafraichir()

## Rôle en direct : joueur sur le terrain (id) ou retour au choix du staff (id vide).
func choisir_role(role: String, id: String) -> void:
	if app._command("set_role_direct", {"role": role, "id": null if id.is_empty() else id}):
		_attente = "role"
		_succes = "C'est noté : le staff passe le mot."
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

## Taille de police mise à l'échelle, avec le plancher commun de 12 px réels (charte §7).
func fs(valeur: float) -> int:
	return maxi(12, roundi(valeur * k))

## Boîte de la charte (§3) : angles droits (rayon 0) partout, sans ombre ni dégradé, et JAMAIS de cadre complet :
## au plus un filet, sur un seul côté (`cote` : bottom par défaut, left, top), commandes comprises. Le rayon demandé
## n'est gardé que pour les disques du terrain (`rond`), seule forme ronde admise.
func _boite(fond: Color, bord: Color = Color.TRANSPARENT, rayon: float = 0, epaisseur: float = 1, marge: float = 0, rond: bool = false, cote: String = "bottom") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(0)
	if bord.a > 0.0: style.set("border_width_" + cote, maxi(1, px(epaisseur)))
	style.set_corner_radius_all(maxi(2, px(rayon)) if rond else 0)
	style.set_content_margin_all(px(marge))
	style.anti_aliasing = rond
	return Charte.ombrer(style, rayon if rond else 0.0)

## Panneau à plat de la charte : fond opaque, sans bordure ; au plus UN filet (`cote` : left, top, bottom).
func _plat(fond: Color = C.PANEL, filet: Color = Color.TRANSPARENT, marge: float = 0, cote: String = "left", epaisseur: float = 3) -> StyleBoxFlat:
	var style := _boite(fond, Color.TRANSPARENT, 0, 0, marge)
	if filet.a > 0.0:
		style.border_color = filet
		style.set("border_width_" + cote, maxi(1, px(epaisseur)))
	return style

## Titre de section de la charte : Barlow Condensed ExtraBold Italic, capitales, ivoire.
func _titre_section(texte: String, taille: float) -> Label:
	return _texte(texte.to_upper(), taille, C.IVORY, Charte.TITRE_EXTRA_ITALIQUE)

## Coche du choix courant (icône de la charte) : la couleur ne porte jamais seule le choix.
func _coche(taille: float = 16) -> TextureRect:
	var coche := TextureRect.new()
	coche.name = "Coche"
	coche.texture = C.icon_texture("check", C.IVORY)
	coche.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coche.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coche.custom_minimum_size = Vector2(px(taille), px(taille))
	coche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coche

## L'un de nos joueurs (fiche complète disponible dans le direct) ? Les autres n'ont ni lien ni mini-fiche.
func _est_des_notres(id: String) -> bool:
	if id.is_empty() or not app is Control: return false
	return not (load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad") as Dictionary).is_empty()

## Nom d'un de nos joueurs (règle de Léo) : lien ivoire souligné au survol ; survol = mini-fiche, clic = fiche
## complète dans une page du direct (« ← Retour au direct » ramène ici, la page Équipe restée ouverte dessous).
## Sans fiche (id inconnu) : simple texte, jamais un faux lien. `largeur_max` (unités de la maquette) coupe un nom long.
func _nom_joueur(id: String, texte: String, taille: float, nom_noeud: String, largeur_max: float = 0.0, police: Font = null) -> Control:
	var fonte: Font = police if police != null else _gras
	if not _est_des_notres(id):
		var inerte := _texte(texte, taille, C.IVORY, fonte)
		inerte.name = nom_noeud
		return inerte
	var lien := Button.new()
	lien.name = nom_noeud
	lien.text = texte
	lien.flat = true
	lien.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(lien)
	lien.add_theme_font_override("font", fonte)
	lien.add_theme_font_size_override("font_size", fs(taille))
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := lien.get_theme_stylebox(etat) as StyleBoxFlat
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = maxi(1, px(1))
	lien.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lien.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if largeur_max > 0.0:
		lien.clip_text = true
		lien.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lien.custom_minimum_size.x = minf(_largeur_texte(texte, fonte, fs(taille)) + 2.0, px(largeur_max))
	lien.set_meta("lien", true)
	lien.set_meta("fiche_joueur", id)
	lien.pressed.connect(ouvrir_fiche.bind(id))
	MiniFiche.lier(app as Control, lien, id, "squad")
	# Mini-fiche posée sur l'application : au-dessus de la scène du match, comme celles du direct.
	lien.mouse_entered.connect(_mini_fiche_devant)
	return lien

func _mini_fiche_devant() -> void:
	if not app is Control: return
	var fiche: Control = MiniFiche.actuelle(app as Control)
	if fiche != null: fiche.z_index = 200

## Fiche complète d'un de nos joueurs : page « joueur » du direct posée au-dessus de la page Équipe.
func ouvrir_fiche(id: String) -> void:
	if app is Control: MiniFiche.cacher(app as Control)
	if view != null and view.has_method("ouvrir_joueur"): view.ouvrir_joueur(id)

func _clic_fiche(evenement: InputEvent, bloc: Control, id: String) -> void:
	var clic := evenement as InputEventMouseButton
	if clic == null or not clic.pressed or clic.button_index != MOUSE_BUTTON_LEFT: return
	bloc.accept_event()
	ouvrir_fiche(id)

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

## Texte qui passe à la ligne (au plus `lignes`) plutôt que d'être coupé ; le contrôle vérifie « non tronqué ».
func _sur_deux_lignes(etiquette: Label, lignes: int) -> Label:
	etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiquette.max_lines_visible = lignes
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiquette.custom_minimum_size.x = 1.0
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

## Bouton de la charte (§7) :
## - « principal » : pilule dorée, texte `PANNEAU` — le SEUL aplat doré de la fenêtre (« Valider et reprendre » ;
##   la fenêtre couvre la coque, donc pas de Continuer à l'écran) ;
## - « lien » : texte ivoire (+ flèche), souligné au survol et au focus, sans cadre ni fond ;
## - « segment » / « choisi » : choix d'un groupe (onglets, crans, candidats) souligné d'un filet bas fin ; le choix
##   courant sur fond sombre relevé, filet GAUCHE épais ivoire et coche (jamais un second ivoire plein, jamais d'or).
func _bouton(texte: String, action: Callable, genre: String = "lien", taille: float = 18, nom: String = "") -> Button:
	var bouton := Button.new()
	bouton.text = texte
	if not nom.is_empty(): bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	if genre == "principal":
		C.style_bouton_ivoire_plein(bouton)
		for etat: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var boite := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			boite.content_margin_left = px(22)
			boite.content_margin_right = px(22)
			boite.content_margin_top = px(8)
			boite.content_margin_bottom = px(8)
		# Éteint : à plat, un seul filet bas (le style commun pose un cadre complet, exclu par la charte §3).
		var eteint := bouton.get_theme_stylebox("disabled") as StyleBoxFlat
		eteint.set_border_width_all(0)
		eteint.border_width_bottom = maxi(1, px(1))
		bouton.add_theme_font_override("font", C.font(800))
	elif genre == "lien":
		C.style_bouton_lien(bouton)
		bouton.set_meta("lien", true)
	else:
		_style_segment(bouton, genre == "choisi")
	bouton.add_theme_font_size_override("font_size", fs(taille))
	bouton.pressed.connect(action)
	return bouton

## Habillage d'un choix de groupe (charte §3 : jamais de cadre complet) : filet bas fin ; choisi : fond sombre relevé
## (PANNEAU_3, jamais l'ivoire plein du bouton principal), filet gauche épais ivoire et coche (`set_meta("coche")`).
func _style_segment(bouton: Button, choisi: bool) -> void:
	for etat: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = C.SELECTED if choisi or etat in ["hover", "pressed", "hover_pressed"] else Color(0, 0, 0, 0)
		style.border_color = C.FAINT if etat == "disabled" and not choisi else (C.IVORY if choisi or etat in ["focus", "hover"] else C.LINE)
		if choisi: style.border_width_left = maxi(2, px(4))
		else: style.border_width_bottom = maxi(1, px(2 if etat in ["focus", "hover"] else 1))
		# Charte finale : choix et onglets arrondis comme les cases (rayon 6).
		style.set_corner_radius_all(maxi(2, px(Charte.RAYON_PETIT)))
		style.anti_aliasing = true
		style.content_margin_left = px(14)
		style.content_margin_right = px(14)
		style.content_margin_top = px(7)
		style.content_margin_bottom = px(7)
		bouton.add_theme_stylebox_override(etat, style)
	for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(cle, C.IVORY)
	bouton.add_theme_color_override("font_disabled_color", C.FAINT)
	bouton.add_theme_font_override("font", C.font(700))
	bouton.icon = C.icon_texture("check", C.IVORY) if choisi else null
	bouton.add_theme_constant_override("icon_max_width", fs(14))
	bouton.set_meta("coche", choisi)

## Portrait à angles droits ; découpé en disque (`rond`) seulement sur le terrain (médaillons des joueurs).
func _portrait(joueur: Dictionary, largeur: float, hauteur: float = -1.0, rond: bool = false) -> Control:
	var h := hauteur if hauteur > 0.0 else largeur
	var cadre := Panel.new()
	cadre.name = "Portrait"
	cadre.custom_minimum_size = Vector2(largeur, h)
	cadre.size = Vector2(largeur, h)
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", Charte.sans_ombre(_boite(C.RAISED, Color.TRANSPARENT, largeur / 2.0 / k, 0, 0, rond)))
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
	elif onglet == "roles": _roles()
	else: _composition()
	if not focus_nom.is_empty():
		var retrouve: Control = find_child(focus_nom, true, false)
		if retrouve != null and retrouve.focus_mode != Control.FOCUS_NONE: FocusLater.grab(retrouve)

## Fond opaque à plat (charte §3 : pas de dégradé) ; il arrête la souris pour le direct dessous.
func _fond() -> void:
	var fond := ColorRect.new()
	fond.name = "TeamBackdrop"
	fond.color = C.BG
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
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
	var cadre := _panneau(_plat(C.PANEL, C.LINE, 0, "bottom", 1))
	cadre.name = "TeamHeader"
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(14)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(20)
	_poser(cadre, 24, 16, 1552, 64)
	var rangee := _h(18)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	cadre.add_child(rangee)
	# Retour au direct : ferme la page sans valider (le match reste arrêté) ; « Valider et reprendre » reste l'action principale.
	var retour := _bouton("← Retour au direct", func(): fermer(false), "lien", 17, "TeamBackToLive")
	retour.tooltip_text = "Revenir au direct sans relancer le match."
	retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(retour)
	var pastille := _panneau(_plat(C.SELECTED))
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(12)
	(pastille.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(12)
	pastille.custom_minimum_size.y = px(36)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var horloge := _titre(_horloge(), 28, C.IVORY, 700)
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
			var cadre_score := _panneau(_plat(C.BG))
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = px(14)
			(cadre_score.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = px(14)
			cadre_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var score := _titre(_score(), 34, C.IVORY, 800)
			score.name = "TeamScore"
			cadre_score.add_child(score)
			rangee.add_child(cadre_score)
	var vide := Control.new()
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.add_child(vide)
	var en_pause := bool(_live().get("paused", false))
	var etat := _panneau(_plat(Color.TRANSPARENT))
	etat.name = "TeamPauseState"
	var style_etat := etat.get_theme_stylebox("panel") as StyleBoxFlat
	style_etat.content_margin_left = px(4)
	style_etat.content_margin_right = px(4)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etat.add_child(_texte("Match en pause" if en_pause else "Mise en pause…", 13, C.IVORY if en_pause else C.MUTED))
	rangee.add_child(etat)
	for paire: Array in [["composition", "Composition", "TeamTabComposition"], ["consignes", "Consignes", "TeamTabConsignes"], ["roles", "Rôles", "TeamTabRoles"]]:
		var vers: String = paire[0]
		var bouton := _bouton(paire[1], func(): choisir_onglet(vers), "choisi" if onglet == vers else "segment", 18, paire[2])
		bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(bouton)

func _pied(gauche: Callable, secondaire: Array) -> void:
	var cadre := _panneau(_plat(C.PANEL, C.LINE, 0, "top", 1))
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
	var lignes := _v(0)
	lignes.alignment = BoxContainer.ALIGNMENT_CENTER
	S.full(lignes)
	hote.add_child(lignes)
	var infos := _h(10)
	infos.name = "TeamFooterLine1"
	lignes.add_child(infos)
	_pied_ligne2 = _h(10)
	_pied_ligne2.name = "TeamFooterLine2"
	lignes.add_child(_pied_ligne2)
	gauche.call(infos)
	if _pied_ligne2.get_child_count() == 0: _pied_ligne2.hide()
	var bouton_secondaire := _bouton(str(secondaire[0]), secondaire[1], "lien", 18, str(secondaire[2]))
	bouton_secondaire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(bouton_secondaire)
	var reprise := _bouton("Valider et reprendre", func(): fermer(true), "principal", 18, "TeamResume")
	reprise.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(reprise)

## Puce d'information : à plat, angles droits, un seul filet à gauche (sa teinte double le mot, jamais seule).
func _puce(texte: String, couleur: Color = C.IVORY, bord: Color = C.LINE, taille: float = 13) -> PanelContainer:
	var puce := _panneau(_plat(C.RAISED, bord, 0, "left", 2))
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

const CRAN_TAILLE := 14.0
const LIBELLES_COURTS := {"Chercher les points": "Points", "Chercher la pénaltouche": "Pénaltouche", "Jouer vite à la main": "Jeu rapide", "Selon le contexte": "Auto",
	"Montée agressive": "Montée", "Glissée prudente": "Glissée", "Jeu au large": "Large", "Jeu au près": "Près", "Jouer la montre": "La montre",
	"Presser l’ouvreur": "Ouvreur", "Leur aile faible": "Aile faible", "Sortir vite": "Vite"}

## Libellé d'un cran sur une seule ligne (« Pénaltouche ») ; le texte complet reste en infobulle.
static func libelle_court(texte: String) -> String:
	return str(LIBELLES_COURTS.get(texte, texte))

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
	_pied(_pied_composition, ["Ajuster les consignes →", choisir_onglet.bind("consignes"), "TeamToConsignes"])

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
		_pied_ligne2.add_child(ligne)

func _cris(cris: Dictionary) -> void:
	var colonne := _v(8)
	colonne.name = "TeamShouts"
	_poser(colonne, 24, 96, 200, 708)
	colonne.add_child(_titre_section("Cris de la touche", 19))
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
		bouton.custom_minimum_size.y = px(88)
		# Cri actif : fond relevé, filet GAUCHE épais ivoire et coche (comme un choix courant), jamais d'or ; les autres :
		# un seul filet bas (charte §3 : aucun cadre complet).
		# Charte finale : un cri est une carte de rayon 12, sans bordure ; le cri actif est sur fond de ligne choisie (vert franc) avec sa coche ; focus : anneau dore.
		var normal := _boite(Charte.SELECTION if est_actif else C.RAISED, Color.TRANSPARENT, Charte.RAYON_CARTE, 0, 0, true)
		normal.content_margin_left = px(12)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.bg_color = C.SELECTED
		var eteint := normal.duplicate() as StyleBoxFlat
		if not est_actif: eteint.bg_color = Color(C.RAISED, 0.5)
		var focus := _boite(Color.TRANSPARENT, Charte.OR, Charte.RAYON_CARTE, 2, 0, true)
		focus.set_border_width_all(maxi(1, px(2)))
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", eteint], ["focus", focus]]: bouton.add_theme_stylebox_override(paire[0], paire[1])
		bouton.pressed.connect(func(): crier(id))
		var rangee := _h(10)
		rangee.position = Vector2(px(12), 0)
		rangee.size = Vector2(px(200 - 24), px(88))
		rangee.alignment = BoxContainer.ALIGNMENT_CENTER
		bouton.add_child(rangee)
		bouton.resized.connect(func(): rangee.size = Vector2(bouton.size.x - px(24), bouton.size.y))
		var usure := clampf(float(option.get("usure", 0.0)), 0.0, 1.0)
		# Carré de la lettre (angles droits) : sa teinte double la note écrite dessous (« s'use », « Actif jusqu'à »).
		var teinte := C.IVORY if est_actif else (C.FAINT if not disponible else (C.MINT if usure <= 0.0 else (C.IVORY if usure < 1.0 else C.ALERT)))
		var rond := _panneau(_plat(teinte))
		rond.custom_minimum_size = Vector2(px(32), px(32))
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if est_actif:
			var coche := _coche(20)
			coche.texture = C.icon_texture("check", C.BG)
			coche.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			rond.add_child(coche)
		else:
			var marque := _titre(lettre, 17, C.BG, 800)
			marque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marque.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			rond.add_child(marque)
		rangee.add_child(rond)
		var mots := _v(1)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var etiquette := _titre(libelle, 17, C.IVORY if disponible or est_actif else C.MUTED, 700)
		etiquette.name = "TeamShoutLabel"
		_sur_deux_lignes(etiquette, 2)
		mots.add_child(etiquette)
		var note := str(option.get("note", ""))
		var note_complete := note
		if est_actif and actif.get("jusqua") != null: note = "Actif jusqu'à la %de" % int(actif.jusqua)
		if not note.is_empty():
			var texte_note := _texte(note, 12, C.IVORY if est_actif or (usure > 0.0 and usure < 1.0) else (C.ALERT if usure >= 1.0 else C.MUTED))
			texte_note.name = "TeamShoutNote"
			_sur_deux_lignes(texte_note, 3)
			mots.add_child(texte_note)
		bouton.tooltip_text = libelle + ("\n" + note_complete if not note_complete.is_empty() else "") + ("\n" + note if note != note_complete else "")
		rangee.add_child(mots)
		bouton.modulate.a = 1.0 if disponible or est_actif else 0.6
		colonne.add_child(bouton)

## Terrain rayé : quinze médaillons à leur poste, avants à gauche.
class Terrain extends Control:
	const Charte = preload("res://ui/charte.gd")
	var k := 1.0
	var places: Dictionary = {}
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
	## Pelouse à angles droits, bandes à plat (charte §3 : ni arrondi, ni voile en dégradé).
	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0: return
		var forme := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var bande := 60.0 * k
		var x := 0.0
		var n := 0
		while x < size.x:
			draw_rect(Rect2(x, 0, minf(bande, size.x - x), size.y), Charte.PELOUSE if n % 2 == 0 else Charte.PELOUSE_2)
			x += bande
			n += 1
		var epais := maxf(1.0, 2.0 * k)
		for paire: Array in [[0.05, 0.55, false], [0.27, 0.25, true], [0.5, 0.45, false], [0.73, 0.25, true], [0.95, 0.55, false]]:
			var lx := size.x * float(paire[0])
			var couleur := Color(Charte.IVOIRE, float(paire[1]))
			if paire[2]: draw_dashed_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais, 8.0 * k)
			else: draw_line(Vector2(lx, 0), Vector2(lx, size.y), couleur, epais)
		var bord := forme.duplicate()
		bord.append(forme[0])
		draw_polyline(bord, Charte.PELOUSE_BORD, maxf(1.0, k), true)

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
		# Disque de terrain (seule forme ronde admise), sans ombre ; joueur choisi : anneau ivoire épais (et « X choisi »
		# écrit sous le terrain), jamais d'or.
		if choisi: draw_arc(c, (R + 4.5) * k, 0, TAU, 64, C.IVORY, 5.0 * k, true)
		elif cible:
			draw_circle(c, (R + 6.0) * k, Color(C.MINT, 0.18))
			draw_arc(c, (R + 5.0) * k, 0, TAU, 64, C.MINT, 3.0 * k, true)
		elif is_hovered(): draw_circle(c, (R + 6.0) * k, Color(C.IVORY, 0.24))
		if has_focus() and not choisi: draw_arc(c, (R + 6.0) * k, 0, TAU, 64, C.IVORY, 2.0 * k, true)
		draw_circle(c, R * k, C.BG)
		draw_arc(c, (R - 2.5) * k, 0, TAU, 64, C.LINE, 5.0 * k, true)
		if energie > 0.0: draw_arc(c, (R - 2.5) * k, -PI / 2.0, -PI / 2.0 + TAU * clampf(energie / 100.0, 0.0, 1.0), 64, teinte, 5.0 * k, true)
		draw_circle(c, (R - 5.0) * k, C.BG)
	func dessiner_badges() -> void:
		var c := centre()
		var police: Font = C.EXTRA_BOLD
		var corps := maxi(12, roundi(16.0 * k))
		var rond := c + Vector2(-R + 6.0, R - 8.0) * k
		calque.draw_circle(rond, 14.0 * k, C.BG)
		calque.draw_arc(rond, 13.0 * k, 0, TAU, 32, C.IVORY, 2.0 * k, true)
		var largeur := police.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		calque.draw_string(police, rond + Vector2(-largeur / 2.0, (police.get_ascent(corps) - police.get_descent(corps)) / 2.0), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, C.IVORY)
		if niveau.is_empty(): return
		var corps_n := maxi(12, roundi(18.0 * k))
		var l := police.get_string_size(niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n).x
		var large := maxf(34.0 * k, l + 10.0 * k)
		var boite := Rect2(c + Vector2(R + 12.0, 0.0) * k - Vector2(large, (R + 7.0) * k), Vector2(large, 24.0 * k))
		# Badge du niveau : rectangle nuit à angles droits, chiffre ivoire, ni ombre ni or.
		var style := StyleBoxFlat.new()
		style.bg_color = C.BG
		style.set_corner_radius_all(0)
		style.border_color = C.LINE
		style.border_width_bottom = maxi(1, roundi(2.0 * k))
		calque.draw_style_box(style, boite)
		calque.draw_string(police, Vector2(boite.position.x + (boite.size.x - l) / 2.0, boite.position.y + (boite.size.y + police.get_ascent(corps_n) - police.get_descent(corps_n)) / 2.0), niveau, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_n, C.IVORY)

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
			var portrait := _portrait(joueur, diametre, -1.0, true)
			portrait.position = Vector2((px(128) - diametre) / 2.0, px(Medaillon.R + 7.0) - diametre / 2.0)
			medaillon.add_child(portrait)
			var etiquette := _panneau(_plat(Color(C.BG, 0.85)))
			var style_et := etiquette.get_theme_stylebox("panel") as StyleBoxFlat
			style_et.content_margin_left = px(7)
			style_et.content_margin_right = px(7)
			etiquette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ligne := _h(5)
			etiquette.add_child(ligne)
			# Le clic sur le médaillon choisit le poste ; le NOM est un lien vers sa fiche (mini-fiche au survol).
			ligne.add_child(_nom_joueur(id, nom_court(str(d.nom)), 17, "TeamPlayerName", 104, C.font(700)))
			if notes.has(id):
				var note := _titre(("%.1f" % float(d.note)), 17, C.IVORY, 800)
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
				puce_teinte = C.IVORY
			elif not humeur.is_empty() and sens_humeur != 0:
				puce_texte = str(humeur.label)
				puce_teinte = C.MINT if sens_humeur > 0 else C.ALERT
			if not puce_texte.is_empty():
				# Pastille de la charte (§7.1) : voile tiré de la teinte + mot dans la teinte, coins 6 px ; jamais un
				# aplat doré (« Valider et reprendre » reste l'unique aplat doré de la fenêtre).
				var voile := Charte.VOILE_DORE if puce_teinte == C.ALERT else (Charte.VOILE_VERT if puce_teinte == C.MINT else Charte.PANNEAU_2)
				var puce := _panneau(_plat(voile))
				puce.name = "TeamPlayerState"
				var style_p := puce.get_theme_stylebox("panel") as StyleBoxFlat
				style_p.set_corner_radius_all(Charte.RAYON_PETIT)
				style_p.content_margin_left = px(8)
				style_p.content_margin_right = px(8)
				puce.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
				puce.add_child(_texte(puce_texte, 12, puce_teinte, _gras))
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
	var aide := _panneau(_plat(Color(C.BG, 0.85)))
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
	var cadre := _panneau(_plat(C.PANEL))
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
	tete.add_child(_titre_section("Dans 10 minutes", 19))
	var rythme := ""
	for axe_v: Variant in Pilotage.axes(p):
		if axe_v is Dictionary and str(axe_v.get("id", "")) == "rythme":
			for option: Variant in axe_v.get("options", []):
				if option is Dictionary and str(option.get("id", "")) == Pilotage.cran(p, axe_v): rythme = str(option.get("label", ""))
	if not rythme.is_empty(): tete.add_child(_texte("au rythme « %s »" % rythme, 12, C.MUTED))
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
		# Portrait carré souligné d'un seul filet à la teinte de l'énergie (le pourcentage est écrit à côté).
		var anneau := _panneau(_plat(Color.TRANSPARENT, teinte, 0, "bottom", 3))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(joueur, px(40)))
		bloc.add_child(anneau)
		var mots := _v(4)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tete_nom := _h(4)
		tete_nom.add_child(_nom_joueur(id, nom_court(str(joueur.get("name", ""))), 13, "TeamFatigueName", 120))
		tete_nom.add_child(_texte("(%d)" % (slot + 1), 13, C.IVORY, _gras))
		mots.add_child(tete_nom)
		var bas := _h(6)
		var barre := Barre.new()
		barre.mouse_filter = Control.MOUSE_FILTER_PASS
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
		# Bloc d'un de nos joueurs : son clic (portrait, barre, chiffres) ouvre aussi sa fiche complète.
		if _est_des_notres(id):
			bloc.mouse_filter = Control.MOUSE_FILTER_STOP
			bloc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			bloc.set_meta("fiche_joueur", id)
			bloc.gui_input.connect(_clic_fiche.bind(bloc, id))
		rangee.add_child(bloc)
	if montres == 0: cadre.queue_free()

class Barre extends Control:
	const C = preload("res://ui/immersive08/components.gd")
	var avant := 0
	var apres := 0
	var teinte := C.MINT
	func _draw() -> void:
		_piste(size.x, C.LINE)
		_piste(size.x * clampf(avant / 100.0, 0, 1), Color(C.IVORY, 0.25))
		_piste(size.x * clampf(apres / 100.0, 0, 1), teinte)
	## Barre à angles droits (charte §3).
	func _piste(largeur: float, couleur: Color) -> void:
		if largeur <= 0.0: return
		draw_rect(Rect2(0, 0, largeur, size.y), couleur)

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
	# Un seul filet, à gauche (charte §3 : aucun cadre complet). Remplaçant choisi : fond sombre relevé, filet épais
	# ivoire et coche ; autorisé : filet menthe (et « en vert sur le banc » écrit sous le terrain) ; conseillé par
	# Gabi : filet ivoire (sa carte le nomme). Jamais d'or ni d'ivoire plein.
	var bord := C.MINT if eligible and poste_choisi >= 0 else (C.IVORY if choisi or conseille else C.LINE)
	var normal := _boite(C.SELECTED if choisi else C.PANEL, bord, Charte.RAYON_PETIT, 4 if choisi else 2, 8, true, "left")
	var survol := normal.duplicate() as StyleBoxFlat
	survol.bg_color = C.RAISED
	survol.border_color = C.IVORY
	var focus := _boite(Color.TRANSPARENT, C.IVORY, Charte.RAYON_PETIT, 2, 8, true)
	for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: tuile.add_theme_stylebox_override(paire[0], paire[1])
	var rangee := _h(8)
	rangee.alignment = BoxContainer.ALIGNMENT_BEGIN
	S.full(rangee)
	rangee.offset_left = px(8)
	rangee.offset_right = -px(8)
	rangee.offset_top = px(8)
	rangee.offset_bottom = -px(8)
	tuile.add_child(rangee)
	var portrait := _portrait(joueur, px(52), px(58))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(portrait)
	var mots := _v(2)
	mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var haut := _h(4)
	# Le clic sur la tuile choisit l'entrant ; le NOM est un lien vers sa fiche (mini-fiche au survol).
	haut.add_child(_titre("%d ·" % numero, 16, C.IVORY, 700))
	haut.add_child(_nom_joueur(id, nom_court(str(joueur.get("name", ""))), 16, "TeamBenchName", 104, C.font(700)))
	var pousse := Control.new()
	pousse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pousse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(pousse)
	var niveau := _niveau(joueur)
	if not niveau.is_empty():
		var badge := _titre(niveau, 16, C.IVORY, 800)
		badge.name = "TeamBenchLevel"
		haut.add_child(badge)
	if choisi: haut.add_child(_coche(14))
	mots.add_child(haut)
	mots.add_child(_coupe(_texte(str(joueur.get("pos", "")), 12, C.MUTED)))
	var condition := roundi(float(joueur.get("condition", 100)))
	var info := ""
	var teinte := C.MUTED
	for cle: String in ["conseil", "info", "hint", "note"]:
		if joueur.get(cle) is String and not str(joueur.get(cle)).is_empty():
			info = str(joueur.get(cle))
			teinte = C.IVORY
			break
	if int(joueur.get("injury", 0)) > 0:
		info = "Blessé"
		teinte = C.ALERT
	elif info.is_empty():
		info = "Prêt · %d %%" % condition if condition >= 95 else "Énergie %d %%" % condition
		teinte = C.MINT if condition >= 75 else C.IVORY
	mots.add_child(_coupe(_texte(info, 12, teinte)))
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
	var cadre := _panneau(_plat(C.PANEL, C.IVORY, 14, "left", 3))
	cadre.name = "TeamAdvice"
	colonne.add_child(cadre)
	var pile := _v(10)
	cadre.add_child(pile)
	pile.add_child(_titre_section("Gabi conseille", 16))
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
		# Sortant / entrant : portrait carré souligné d'un seul filet (alerte / menthe), la phrase dit qui sort.
		var anneau := _panneau(_plat(Color.TRANSPARENT, paire[1], 0, "bottom", 3))
		anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anneau.add_child(_portrait(paire[0], px(48)))
		rangee.add_child(anneau)
		if paire[1] == C.ALERT:
			var fleche := _titre("⇄", 26, C.IVORY)
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
	# Qui sort, qui entre : leurs noms en liens (mini-fiche au survol, fiche complète au clic), c'est le moment où
	# l'on veut les comparer.
	var noms := _h(6)
	noms.name = "TeamAdviceNames"
	noms.add_child(_nom_joueur(out_id, nom_court(str(sortant.get("name", ""))), 14, "TeamAdviceOut", 130))
	noms.add_child(_texte("sort ·", 13, C.MUTED))
	noms.add_child(_nom_joueur(in_id, nom_court(str(entrant.get("name", ""))), 14, "TeamAdviceIn", 130))
	noms.add_child(_texte("entre", 13, C.MUTED))
	pile.add_child(noms)
	var boutons := _h(8)
	var faire := _bouton("Faire entrer %s →" % nom_court(str(entrant.get("name", ""))), func(): remplacer(slot, in_id), "lien", 17, "TeamAdviceApply")
	faire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faire.disabled = not _autorise(slot, in_id)
	if faire.disabled: faire.tooltip_text = "Changement possible match arrêté, selon les règles du banc."
	boutons.add_child(faire)
	boutons.add_child(_bouton("Plus tard", _plus_tard.bind("%s>%s" % [out_id, in_id]), "lien", 17, "TeamAdviceLater"))
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
	var section := _panneau(_plat(C.PANEL))
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
	# Colonne de droite dans sa propre zone qui défile : en petite fenêtre (720p), le plancher de 12 px des textes
	# la rend plus haute que l'écran ; elle tient sans défiler dès 1080p.
	var defile_aside := ScrollContainer.new()
	defile_aside.name = "TeamConsignesAsideScroll"
	defile_aside.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_poser(defile_aside, 1150, 96, 426, 708)
	var aside := _v(14 if k >= 1.0 else 8)
	aside.name = "TeamConsignesAside"
	aside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aside.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defile_aside.add_child(aside)
	_carte_arbitre(aside, p)
	_carte_adversaire(aside, p, vue)
	_carte_match(aside, p)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.add_child(vide)
	_carte_staff(aside, p)
	_pied(_pied_consignes, ["← Retour à la composition", choisir_onglet.bind("composition"), "TeamToComposition"])

func _espace(hauteur: float) -> Control:
	var vide := Control.new()
	vide.custom_minimum_size.y = px(hauteur)
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vide

func _entete_groupe(texte: String, sous: String) -> Control:
	var colonne := _v(4)
	var rangee := _h(10)
	var t := _titre_section(texte, 22)
	rangee.add_child(t)
	var precision := _texte(sous, 12, C.MUTED)
	precision.size_flags_vertical = Control.SIZE_SHRINK_END
	rangee.add_child(precision)
	colonne.add_child(rangee)
	var filet := ColorRect.new()
	filet.color = C.LINE
	filet.custom_minimum_size = Vector2(0, maxf(1.0, k))
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(filet)
	return colonne

## Point sur le match sous l'adversaire : score et temps, fatigue moyenne du XV, consignes en place.
func _carte_match(parent: Control, p: Dictionary) -> void:
	var cadre := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 14))
	cadre.name = "TeamMatchSummary"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_titre_section("Où en est le match", 15))
	var total := 0.0
	var nombre := 0
	for joueur: Variant in _lineup():
		if joueur is Dictionary and joueur.get("condition") != null:
			total += float(joueur.condition)
			nombre += 1
	var rangee := _h(10)
	colonne.add_child(rangee)
	var score := _titre("%s · %s" % [_score(), _horloge()], 22, C.IVORY, 800)
	score.name = "TeamMatchScore"
	rangee.add_child(_coupe(score))
	if nombre > 0:
		var moyenne := roundi(total / nombre)
		var fatigue := _texte("Fatigue moyenne du XV : %d %%" % moyenne, 14, teinte_energie(float(moyenne)))
		fatigue.name = "TeamMatchFatigue"
		colonne.add_child(_coupe(fatigue))
	var actives := _consignes_actives(p)
	var consignes := _texte("Consignes : " + (", ".join(PackedStringArray(actives)) if not actives.is_empty() else "toutes au cran normal"), 12, C.MUTED)
	consignes.name = "TeamMatchConsignes"
	consignes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consignes.max_lines_visible = 4
	colonne.add_child(consignes)

## Avis du staff en bas de la colonne : ses propositions en attente (avant → après, et pourquoi) et le bouton
## « Appliquer ces consignes » ; sans avis, sa dernière décision du journal.
func _carte_staff(parent: Control, p: Dictionary) -> void:
	var staff: Dictionary = p.get("staff") if p.get("staff") is Dictionary else {}
	var propositions: Array = (staff.get("propositions") if staff.get("propositions") is Array else []).filter(func(x: Variant) -> bool: return x is Dictionary)
	var journal: Array = p.get("journal") if p.get("journal") is Array else []
	var faits: Array = journal.filter(func(e: Variant) -> bool: return e is Dictionary and str(e.get("auteur", "")) == "staff")
	if propositions.is_empty() and faits.is_empty(): return
	# Un seul filet à gauche : menthe quand le staff propose (le titre le dit), sinon aucun.
	var cadre := _panneau(_plat(C.PANEL, C.MINT if not propositions.is_empty() else Color.TRANSPARENT, 14, "left", 3))
	cadre.name = "TeamStaffNote"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	if propositions.is_empty():
		colonne.add_child(_titre_section("Le staff", 15))
		var corps := _texte("%d′ · %s" % [int(faits[-1].get("minute", 0)), str(faits[-1].get("texte", ""))], 14, C.IVORY)
		corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		corps.max_lines_visible = 4
		colonne.add_child(corps)
		return
	var tete := _h(8)
	tete.add_child(_coupe(_titre_section("Le staff conseille · %d′" % int(staff.get("minute", 0)), 15)))
	colonne.add_child(tete)
	var raisons: Array[String] = []
	for x: Dictionary in propositions.slice(0, 3):
		var ligne := _h(6)
		ligne.add_child(_texte(str(x.get("label", "")), 14, C.IVORY, _gras))
		ligne.add_child(_coupe(_texte("%s → %s" % [str(x.get("actuelLabel", "")), str(x.get("valeurLabel", ""))], 14, C.IVORY)))
		colonne.add_child(ligne)
		var raison := str(x.get("raison", ""))
		if not raison.is_empty() and not raison in raisons: raisons.append(raison)
	if not raisons.is_empty():
		var pourquoi := _texte(" ".join(raisons), 12, C.MUTED)
		pourquoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pourquoi.max_lines_visible = 3
		colonne.add_child(pourquoi)
	var bouton := _bouton("Appliquer ces consignes →", appliquer_staff, "lien", 16, "TeamStaffApply")
	bouton.disabled = bool(app.waiting) or _attente == "staff"
	colonne.add_child(bouton)

func _pied_consignes(infos: HBoxContainer) -> void:
	if not _message.is_empty():
		infos.add_child(_coupe(_texte(_message, 13, _message_teinte)))
		return
	infos.add_child(_coupe(_texte("Les consignes en direct s'appliquent dès la reprise ; le plan de jeu demande l'arrêt du match.", 13, C.MUTED)))

## Ligne d'un axe : libellé (et « match en pause » pour le plan de jeu), crans ; fond relevé et bilan
## dessous quand le cran en place n'est pas neutre.
func _axe(p: Dictionary, axe: Dictionary) -> Control:
	var id := str(axe.get("id", ""))
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var actuel := Pilotage.cran(p, axe)
	var modifie := not actuel.is_empty() and actuel != cran_neutre(axe)
	var en_pause_seulement := bool(axe.get("pause", false)) or id in ["planAttaque", "systemeDefense", "penalites"]
	var cadre := _panneau(_plat(C.RAISED if modifie else Color.TRANSPARENT))
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
		var note := _texte("match en pause", 12, C.MUTED)
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
		# Même taille et une seule ligne pour tous les crans : libellé court, le complet en infobulle.
		# Cran en place : filet épais ivoire et coche (segment de la charte), jamais d'or ni d'ivoire plein.
		var bouton := _bouton(libelle_court(texte), _choisir_cran.bind(crans, id, valeur), "choisi" if choisi else "segment", CRAN_TAILLE, "Consigne_%s_%s" % [id, valeur])
		bouton.set_meta("axe", id)
		bouton.set_meta("valeur", valeur)
		bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bouton.custom_minimum_size = Vector2(0, px(32))
		bouton.clip_text = true
		bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bouton.add_theme_constant_override("icon_max_width", fs(11))
		bouton.add_theme_constant_override("h_separation", px(2))
		bouton.tooltip_text = texte + ("\n" + aide if not aide.is_empty() else "")
		for etat: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var boite := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			boite.content_margin_left = px(2)
			boite.content_margin_right = px(2)
			boite.content_margin_top = px(6)
			boite.content_margin_bottom = px(6)
		if not choisi: (bouton.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = C.BG
		bouton.disabled = fini or (en_pause_seulement and not en_pause)
		if en_pause_seulement and not en_pause: bouton.tooltip_text += "\nChangement possible match arrêté."
		crans.add_child(bouton)
	rangee.add_child(crans)
	var bilan := bilan_court(p, id)
	if modifie and not bilan.is_empty():
		var ligne := _coupe(_texte(bilan, 12, C.IVORY))
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
	var cadre := _panneau(_plat(C.RAISED))
	cadre.name = "TeamGamePlan"
	var style := cadre.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = px(14)
	style.content_margin_right = px(14)
	style.content_margin_top = px(10)
	style.content_margin_bottom = px(10)
	colonne.add_child(cadre)
	var rangee := _h(10)
	cadre.add_child(rangee)
	var titre := _titre_section("Plan de jeu", 15)
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(titre)
	var autorise: bool = bool(_live().get("paused", false)) and not bool(_live().get("finished", false))
	for trio: Array in [["attack", "attacks", "Avec le ballon", "TeamPlanAttack"], ["defense", "defenses", "Sans le ballon", "TeamPlanDefense"], ["penalty", "penalties", "Sur pénalité", "TeamPlanPenalty"]]:
		var options: Array = tactiques.get(trio[1], []) if tactiques.get(trio[1]) is Array else []
		if options.is_empty(): continue
		var bloc := _v(2)
		bloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloc.add_child(_texte(trio[2], 12, C.MUTED))
		var choix := OptionButton.new()
		choix.name = trio[3]
		choix.fit_to_longest_item = false
		choix.clip_text = true
		choix.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choix.add_theme_font_override("font", C.font(700))
		choix.add_theme_font_size_override("font_size", fs(16))
		# Un seul filet bas (charte §3) ; survol : filet ivoire ; focus : filet bas épais.
		var normal := _boite(C.PANEL, C.LINE, Charte.RAYON_PETIT, 1, 0, true)
		normal.content_margin_left = px(10)
		normal.content_margin_right = px(10)
		normal.content_margin_top = px(5)
		normal.content_margin_bottom = px(5)
		var survol := normal.duplicate() as StyleBoxFlat
		survol.border_color = C.IVORY
		var focus := _boite(Color.TRANSPARENT, C.IVORY, Charte.RAYON_PETIT, 2, 0, true)
		for paire: Array in [["normal", normal], ["hover", survol], ["pressed", survol], ["disabled", normal], ["focus", focus]]: choix.add_theme_stylebox_override(paire[0], paire[1])
		for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: choix.add_theme_color_override(cle, C.IVORY)
		_habiller_menu(choix.get_popup())
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

## Menu déroulant d'un choix (exception permise) habillé à la charte : fond PANNEAU à plat, angles droits, sans ombre
## ni cadre ; ligne survolée sur PANNEAU_3 marquée d'un filet gauche ivoire ; textes ivoire.
func _habiller_menu(menu: PopupMenu) -> void:
	var fond := StyleBoxFlat.new()
	fond.bg_color = Charte.PANNEAU
	fond.set_corner_radius_all(0)
	fond.set_border_width_all(0)
	fond.shadow_size = 0
	fond.set_content_margin_all(px(6))
	menu.add_theme_stylebox_override("panel", fond)
	var survol := StyleBoxFlat.new()
	survol.bg_color = Charte.PANNEAU_3
	survol.set_corner_radius_all(0)
	survol.shadow_size = 0
	survol.border_color = Charte.IVOIRE
	survol.border_width_left = maxi(1, px(3))
	menu.add_theme_stylebox_override("hover", survol)
	for cle: String in ["font_color", "font_hover_color", "font_accelerator_color"]: menu.add_theme_color_override(cle, Charte.IVOIRE)
	menu.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	menu.add_theme_color_override("font_separator_color", Charte.IVOIRE_2)
	menu.add_theme_font_override("font", C.font(700))
	menu.add_theme_font_size_override("font_size", fs(16))
	menu.set_meta("habille", true)

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
	cadre.add_theme_stylebox_override("panel", _plat(C.PANEL))
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
		var initiales := _titre("".join(lettres), 48, C.IVORY)
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
	corps.add_child(_titre_section("L'arbitre", 15))
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
			cran.add_theme_stylebox_override("panel", _plat(C.IVORY if n < niveau else C.LINE))
			crans.add_child(cran)
		jauge.add_child(crans)
		jauge.add_child(_coupe(_texte(ARBITRE_MOTS[niveau], 12, C.ALERT if niveau >= 4 else (C.MINT if niveau <= 2 else C.MUTED))))
		corps.add_child(jauge)
	var resume := _texte(str(arbitre.get("resume", "")), 12, C.IVORY)
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
	var cadre := _panneau(_plat(C.PANEL, Color.TRANSPARENT, 14))
	cadre.name = "TeamOpponent"
	parent.add_child(cadre)
	var colonne := _v(8)
	cadre.add_child(colonne)
	colonne.add_child(_coupe(_titre_section("Ce que fait " + nom, 19)))
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

# --- Onglet Rôles ----------------------------------------------------------------

## Quatre cartes (deux par ligne) : qui s'en charge, le choix du staff, les candidats sur le terrain avec leur
## note dans l'attribut du rôle. Les règles (joueurs sur le terrain seulement, secours ≠ buteur) restent au moteur.
func _roles() -> void:
	var source: Variant = _pilotage().get("roles")
	var roles: Array = (source.get("roles") if source is Dictionary and source.get("roles") is Array else []).filter(func(r: Variant) -> bool: return r is Dictionary)
	var grille := GridContainer.new()
	grille.name = "TeamRoles"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", px(16))
	grille.add_theme_constant_override("v_separation", px(16))
	_poser(grille, 24, 96, 1552, 708)
	if roles.is_empty():
		var rien := _texte("Les rôles se fixent avant le coup d'envoi pour cette rencontre.", 16, C.MUTED)
		grille.add_child(rien)
	for role: Dictionary in roles: grille.add_child(_carte_role(role))
	_pied(_pied_roles, ["← Retour à la composition", choisir_onglet.bind("composition"), "TeamToComposition"])

func _pied_roles(infos: HBoxContainer) -> void:
	var texte := _message if not _message.is_empty() else "Le changement vaut dès la prochaine occasion : prochain but, prochaine touche, prochain dégagement."
	infos.add_child(_coupe(_texte(texte, 13, _message_teinte if not _message.is_empty() else C.MUTED)))

func _carte_role(role: Dictionary) -> Control:
	var id := str(role.get("id", ""))
	var designe: Variant = role.get("designe")
	var staff: Variant = role.get("staff")
	var en_jeu: Variant = role.get("enJeu")
	# Rôle désigné par le manager : un seul filet ivoire à gauche (la ligne « En charge » le dit en toutes lettres).
	var cadre := _panneau(_plat(C.PANEL, C.IVORY if designe is Dictionary else Color.TRANSPARENT, 16, "left", 3))
	cadre.name = "Role_" + id
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var colonne := _v(8)
	cadre.add_child(colonne)
	var tete := _h(10)
	tete.add_child(_titre_section(str(role.get("label", "")), 22))
	var attribut := _texte(str(role.get("attribut", "")), 12, C.MUTED)
	attribut.size_flags_vertical = Control.SIZE_SHRINK_END
	tete.add_child(attribut)
	colonne.add_child(tete)
	var qui := _coupe(_texte("", 14, C.IVORY))
	if en_jeu is Dictionary:
		qui.text = "En charge : %s (%d)%s" % [str(en_jeu.get("name", "")), int(en_jeu.get("value", 0)), "" if designe is Dictionary else " · choix du staff"]
	else:
		qui.text = "Personne sur le terrain"
		qui.add_theme_color_override("font_color", C.ALERT)
	colonne.add_child(qui)
	var candidats: Array = (role.get("candidats") if role.get("candidats") is Array else []).filter(func(c: Variant) -> bool: return c is Dictionary)
	var occupe := bool(app.waiting) or _attente == "role"
	# Candidats sur deux colonnes : six au plus tiennent dans la carte sans défiler.
	var liste := GridContainer.new()
	liste.name = "RoleCandidates_" + id
	liste.columns = 2
	liste.add_theme_constant_override("h_separation", px(8))
	liste.add_theme_constant_override("v_separation", px(8))
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(liste)
	for c: Dictionary in candidats.slice(0, 6):
		liste.add_child(_candidat(id, c, en_jeu is Dictionary and str(en_jeu.get("id", "")) == str(c.get("id", "")), staff is Dictionary and str(staff.get("id", "")) == str(c.get("id", "")), occupe))
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(vide)
	var rendre := _bouton("Laisser le staff choisir" + (" (%s)" % str(staff.get("name", "")) if staff is Dictionary else "") + " →", choisir_role.bind(id, ""), "lien", 14, "RoleStaff_" + id)
	rendre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rendre.disabled = occupe or not designe is Dictionary
	colonne.add_child(rendre)
	return cadre

## Ligne d'un candidat : portrait, numéro et nom, note dans l'attribut ; filet épais et coche s'il est en charge.
func _candidat(role: String, c: Dictionary, choisi: bool, du_staff: bool, occupe: bool) -> Button:
	var bouton := _bouton("", choisir_role.bind(role, str(c.get("id", ""))), "segment", 14, "Role_%s_%d" % [role, int(c.get("num", 0))])
	if choisi:
		_style_segment(bouton, true)
		bouton.icon = null  # La coche va dans la rangée (le bouton n'a pas de texte, son contenu est en enfants).
	bouton.set_meta("joueur", str(c.get("id", "")))
	bouton.custom_minimum_size.y = px(44)
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.disabled = occupe
	bouton.toggle_mode = false
	var rangee := _h(10)
	S.full(rangee)
	rangee.offset_left = px(8)
	rangee.offset_right = -px(12)
	bouton.add_child(rangee)
	var portrait := _portrait(c, px(32))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(portrait)
	var nom := _coupe(_texte("%d · %s" % [int(c.get("num", 0)), str(c.get("name", ""))], 15, C.IVORY, _gras))
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(nom)
	if du_staff:
		var marque := _texte("choix du staff", 12, C.MUTED)
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(marque)
	var note := _titre(str(int(c.get("value", 0))), 18, C.IVORY)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(note)
	if choisi: rangee.add_child(_coche(16))
	return bouton
