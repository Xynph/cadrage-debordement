extends Control
## Écran 13 « Match en direct » : habillage télé du match 3D (design/ux/13-match-direct.md, revue DA du
## 19/11/2026, variante 1 « Bandeau d'angle » choisie par Léo). Bandeau du score incliné en haut à gauche
## (horloge et période, plaques des deux clubs, score ivoire 40 px), commandes en haut à droite, journal
## de deux lignes en bas à gauche, bannière d'essai dans le tiers inférieur (match_temps_forts.gd) et menu
## du match ouvert par Échap (seule petite fenêtre, exception de Léo). Jetons et polices : ui/charte.gd,
## aucun or. Plein écran obligatoire : on ne quitte jamais le direct avant la fin. Les plaques des clubs et les noms
## de nos joueurs ouvrent une petite fenêtre visuelle par-dessus le match (match en pause, repris à la fermeture) ;
## le menu ouvre ses réglages dans une page du direct.
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const C = preload("res://ui/immersive08/components.gd")
const TempsForts = preload("res://ui/contextual/match_temps_forts.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const FenetreEquipe = preload("res://ui/contextual/match_equipe.gd")
const ApresMatch = preload("res://ui/contextual/apres_match.gd")
## Après-match (verdict, pourquoi, classement complet, « Valider le résultat ») : posé sur toute la vue une fois
## le match fini et entièrement montré (bouton de validation du direct visible).
var apres_match: Control
var _viewport: SubViewport
var director: Node
## Régie du match en temps forts (mode de base ; absente avec CD_MATCH_TEMPS_FORTS=0).
var regie: Node
var _cadence: OptionButton
var _niveau: OptionButton
var _niveaux: Array = []
var _reglages_temps_forts := false
var app: Control
var stage: Node3D
var model: Dictionary = {}
var clock: Label
## Période sous l'horloge (« 1re MT », « 2e MT ») ; vide quand l'horloge dit déjà « MI-TEMPS » ou « TERMINÉ ».
var phase: Label
var score: Label
## Météo et vent sous le score (même bandeau en 3D et pendant l'entracte 2D).
var meteo_ligne: Label
var home: Label
var away: Label
var play: Button
var finish: Button
## Dernier fait écrit : texte tenu par la vue (repli) ou par la régie (légende du temps fort). Il n'est pas
## affiché lui-même : le journal (deux lignes, minute et noms de nos joueurs liés) le reprend.
var events: Label
var drawer: PanelContainer
var drawer_body: VBoxContainer
var journal: VBoxContainer
var _journal_shell: PanelContainer
## Tiroir des statistiques et du journal (menu Plus) ; composition et consignes sont dans la fenêtre Équipe.
var drawer_tab := ""
## Fenêtre « Équipe » (match_equipe.gd) : composition, banc, cris, consignes ; elle met le match en pause.
var equipe: Control
## Consignes en direct envoyées et pas encore confirmées par le moteur (axe → cran).
var _envois_consignes: Dictionary = {}
var _drawer_key := ""
var _camera_controls: Array[Button] = []
var _applied_camera := ""
var _applied_quality := ""
## Plaques des deux clubs dans le bandeau (fond à la couleur du club, sigle, nom) : clic = fiche du club.
var plaques: Array[PanelContainer] = []
var _plaques_cle := ""
## Barre de commandes du bas : repli sans régie et fin de match (« Valider la journée »).
var barre_commandes: Control
## Bande de commandes des temps forts (Équipe, Réglages, Plus), remplie par l'écran intermédiaire
## (match_between.gd) : la même pendant les temps forts 3D et l'entracte 2D, à droite du score.
var bande_temps_forts: HBoxContainer
## Tailles écrites pour 1080p (maquette 13-match-direct-1), agrandies avec la hauteur de l'écran (×1,33
## en 1440p), jamais réduites en dessous : horloge 32, période 16, noms 22, score 40 (charte §7), sigle 15,
## commandes 16, journal 16, météo 13.
const BANDEAU_TAILLES := {"horloge": 32, "phase": 16, "equipe": 22, "score": 40, "sigle": 15, "pause": 16, "legende": 16, "meteo": 13}
## Hauteur du bandeau du score et largeur du journal (maquette 1080p : 56 et 744 px), marge d'écran 24 px.
const BANDEAU_HAUTEUR := 56
## Barre du haut (bandeau du score, ligne du vent, commandes) agrandie d'environ 28 % (retouche de Léo du 21/11/2026).
const BARRE_HAUT := 1.28
## Liseré fin des grandes tuiles du direct (choix de Léo du 21/11/2026) : 1 px, blanc à 22 %.
const LISERE := Color(1, 1, 1, 0.22)
const LEGENDE_LARGEUR := 744
const MARGE := 24
var echelle := 1.0
var _legende: Control
## Bandeau du score (BandeauAngle) : horloge, plaques, score.
var _coque_score: Control
var _meteo_boite: Control
var _sigles: Array[Label] = []
## Pendant l'action 3D : la ligne météo et le rappel « Échap » se retirent (le bandeau reste entier).
var compact := false
## Images à attendre avant de redonner au cadrage la part d'image cachée (mise en page différée).
var _recouvrir := 0
## Rappel « Échap · Pause et menu » sous les commandes (cliquable : ouvre le menu du match).
var indice_menu: Button
## Qui a le ballon, sous le bandeau (maquette 13-1) : en 3D, la phrase de l'état du jeu (écran 14,
## `MatchBetweenState`) sur panneau 85 % avec le liseré du club qui a le ballon ; à l'entracte, la phrase
## reste dans la bande des commandes (maquette 14).
var ligne_possession: PanelContainer
var _possession_trait: Control
var _possession_texte: Label
var _rangee_haut: Control
## Journal affiché : deux faits au plus, le plus récent en premier ({minute, texte}).
var _journal: Array = []
var _journal_texte := ""
var _journal_lignes: Array = []
## Menu du match (Échap) et page du direct (fiche club, réglages).
var menu: Control
var _menu_voile: ColorRect
var _menu_panneau: PanelContainer
var _menu_mode := ""
var _menu_quitter_arme := false
var _menu_cle := ""
var page: Control
var _page_sorte := ""
var _page_cle := ""
## Petite fenêtre du direct (club ou joueur) : calque plein écran (voile + toile au gabarit), ou null.
var fenetre_hote: Control
var _relecture: Array = []  ## [faits filtrés, équipes, fait de départ] de la page « Relire les actions »
## Le match jouait quand le menu ou la page s'est ouvert : « Reprendre » / « Retour au direct » le relance.
var _reprendre_apres := false
## Pause demandée pendant une réponse du moteur : envoyée dès qu'il est libre.
var _pause_voulue := 0

## Bandeau du score (charte finale §7) : un seul panneau `PANNEAU` à 90 %, rayon 18, sans bordure ; un filet
## sépare l'horloge des plaques. La couleur des clubs ne vit que sur l'écusson (puce du sigle) de chaque plaque.
class BandeauAngle extends HBoxContainer:
	const FOND := Color(Charte.PANNEAU, 0.9)
	func _ready() -> void:
		add_theme_constant_override("separation", 0)
		sort_children.connect(queue_redraw)
	func _draw() -> void:
		var fond_bandeau: StyleBoxFlat = Charte.style_panneau(FOND, Charte.RAYON_PANNEAU, 0)
		# Fin trait blanc des grandes tuiles du direct (choix de Léo du 21/11/2026), comme les blocs de l'écran 2D.
		if fond_bandeau != null:
			fond_bandeau = fond_bandeau.duplicate()
			fond_bandeau.border_color = Color(1, 1, 1, 0.22)
			fond_bandeau.set_border_width_all(1)
			fond_bandeau.anti_aliasing = true
		draw_style_box(fond_bandeau, Rect2(Vector2.ZERO, size))
		var horloge: Control = get_node_or_null("MatchClockBlock")
		if horloge != null and horloge.visible:
			draw_rect(Rect2(horloge.position.x + horloge.size.x, size.y * 0.2, 1.0, size.y * 0.6), Charte.FILET)

func _ready() -> void:
	name = "ContextualLiveMatch"
	app = director.app
	var container := SubViewportContainer.new()
	container.name = "LiveMatchViewport"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(container)
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_viewport = viewport
	stage = load("res://match_view.gd").new()
	if stage.has_method("set_club_identity"): stage.set_club_identity(app.model.get("club", {}))
	viewport.add_child(stage)
	var frame := S.frame(self, MARGE)
	frame.name = "MatchHud"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rangée du haut : bandeau du score, bande des commandes (Équipe, Réglages, Plus), Pause.
	var haut := HBoxContainer.new()
	haut.name = "MatchTopRow"
	haut.add_theme_constant_override("separation", 12)
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(haut)
	_construire_bandeau(haut)
	if TempsForts.enabled():
		bande_temps_forts = HBoxContainer.new()
		bande_temps_forts.name = "MatchCommandBand"
		bande_temps_forts.add_theme_constant_override("separation", 12)
		bande_temps_forts.alignment = BoxContainer.ALIGNMENT_END
		bande_temps_forts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		C.fill(bande_temps_forts)
		bande_temps_forts.draw.connect(_fond_bande)
		haut.add_child(bande_temps_forts)
	else:
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		C.fill(vide)
		haut.add_child(vide)
	play = _bouton_hud("Pause", "Espace", _pause, "MatchPauseButton")
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(play)
	_rangee_haut = haut
	# Sous le bandeau : qui a le ballon (en 3D) et météo (aux arrêts) à gauche, rappel « Échap · Pause et
	# menu » à droite.
	var sous := HBoxContainer.new()
	sous.name = "MatchSubRow"
	sous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sous.add_theme_constant_override("separation", 12)
	frame.add_child(sous)
	ligne_possession = PanelContainer.new()
	ligne_possession.name = "MatchPossession"
	ligne_possession.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_possession.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ligne_possession.add_theme_stylebox_override("panel", _fond_hud(Vector4(22, 0, 16, 0)))
	var possession_rangee := HBoxContainer.new()
	possession_rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne_possession.add_child(possession_rangee)
	_possession_trait = Marqueur.new()
	_possession_trait.name = "Trait"
	_possession_trait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_possession_trait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	possession_rangee.add_child(_possession_trait)
	_possession_texte = _texte("", Charte.texte_moyen(), Charte.IVOIRE)
	_possession_texte.name = "Texte"
	possession_rangee.add_child(_possession_texte)
	ligne_possession.hide()
	sous.add_child(ligne_possession)
	meteo_ligne = S.label("", 13, Charte.IVOIRE_2)
	meteo_ligne.name = "MatchWeather"
	meteo_ligne.add_theme_font_override("font", Charte.TEXTE)
	meteo_ligne.hide()
	# Boîte propre à la ligne météo : le mode compact la masque sans lutter avec la régie, qui règle
	# la visibilité de la ligne elle-même.
	_meteo_boite = PanelContainer.new()
	_meteo_boite.name = "MatchWeatherBox"
	_meteo_boite.add_theme_stylebox_override("panel", _fond_hud(Vector4(12, 4, 12, 4)))
	_meteo_boite.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_meteo_boite.add_child(meteo_ligne)
	sous.add_child(_meteo_boite)
	var vide_sous := Control.new()
	vide_sous.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(vide_sous)
	sous.add_child(vide_sous)
	indice_menu = _bouton_hud("Pause et menu", "Échap", ouvrir_menu, "MatchMenuHint", true)
	indice_menu.tooltip_text = "Met le match en pause et ouvre le menu du match."
	sous.add_child(indice_menu)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.G.fill(space, true)
	frame.add_child(space)
	_construire_journal(frame)
	_construire_barre_bas(frame)
	if TempsForts.enabled():
		regie = TempsForts.new()
		add_child(regie)
		regie.setup(self, container, viewport, space)
	_construire_tiroir()
	equipe = FenetreEquipe.new()
	equipe.view = self
	equipe.app = app
	add_child(equipe)
	app.match_view = stage
	app.pause_button = play
	app.match_finish = finish
	app.match_clock = clock
	_mettre_a_l_echelle()
	get_viewport().size_changed.connect(_mettre_a_l_echelle)
	_dessiner_journal()
	apply_preferences()

# --- Construction ---------------------------------------------------------------

## Fond des éléments posés sur l'image : panneau à 90 %, sans cadre ; rayon 18 (panneau) par défaut, 6 pour
## une case, `RAYON_PILULE` pour une commande (charte finale §3, §7).
static func _fond_hud(marges: Vector4, couleur: Color = Color(Charte.PANNEAU, 0.9), rayon: int = Charte.RAYON_PANNEAU) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(rayon)
	style.anti_aliasing = true
	style.content_margin_left = marges.x
	style.content_margin_top = marges.y
	style.content_margin_right = marges.z
	style.content_margin_bottom = marges.w
	return Charte.ombrer(style, rayon)

## Puce de touche (« Espace », « Échap ») : panneau haut, texte ivoire secondaire.
static func _touche(texte: String) -> PanelContainer:
	var puce := PanelContainer.new()
	puce.name = "Touche"
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Charte finale §3 : une puce de touche est une case (rayon 6).
	puce.add_theme_stylebox_override("panel", _fond_hud(Vector4(7, 1, 7, 1), Charte.PANNEAU_3, Charte.RAYON_PETIT))
	var lettre := Label.new()
	lettre.text = texte
	lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lettre.add_theme_font_override("font", Charte.TEXTE)
	lettre.add_theme_color_override("font_color", Charte.IVOIRE_2)
	lettre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	puce.add_child(lettre)
	return puce

## Commande du HUD (Pause, rappel Échap) : pilule, texte crème sur panneau 90 %, puce de la touche à droite (ou à
## gauche), survol en panneau plus clair, anneau doré au focus. Tout le pavé est cliquable.
func _bouton_hud(texte: String, touche: String, action: Callable, nom: String, puce_a_gauche: bool = false) -> Button:
	var bouton := Button.new()
	bouton.name = nom
	bouton.text = texte
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.set_meta("contextual_enabled", true)
	bouton.set_meta("puce_a_gauche", puce_a_gauche)
	bouton.pressed.connect(action)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(cle, Charte.IVOIRE)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var puce := _touche(touche)
	bouton.add_child(puce)
	bouton.resized.connect(_placer_puce.bind(bouton))
	return bouton

func _placer_puce(bouton: Button) -> void:
	var puce: Control = bouton.get_node_or_null("Touche")
	if puce == null: return
	puce.reset_size()
	var marge := roundf(12 * echelle)
	var x := marge if bool(bouton.get_meta("puce_a_gauche", false)) else bouton.size.x - puce.size.x - marge
	puce.position = Vector2(x, roundf((bouton.size.y - puce.size.y) * 0.5))

## Styles et tailles d'une commande du HUD à l'échelle courante.
func _habiller_bouton_hud(bouton: Button) -> void:
	var puce: PanelContainer = bouton.get_node_or_null("Touche")
	var eh := echelle * BARRE_HAUT
	var taille := roundi(BANDEAU_TAILLES.pause * eh)
	bouton.add_theme_font_size_override("font_size", taille)
	if puce != null: (puce.get_child(0) as Label).add_theme_font_size_override("font_size", taille)
	var largeur_puce := puce.get_combined_minimum_size().x if puce != null else 0.0
	var a_gauche := bool(bouton.get_meta("puce_a_gauche", false))
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var couleur := Color(Charte.PANNEAU, 0.9)
		if etat in ["hover", "pressed"]: couleur = Charte.PANNEAU_2
		if etat == "focus": couleur = Color(0, 0, 0, 0)
		var cote := roundf(16 * eh)
		var style := _fond_hud(Vector4(cote + (largeur_puce + 10 * eh if a_gauche else 0.0), 0, cote + (0.0 if a_gauche else largeur_puce + 10 * eh), 0), couleur, Charte.RAYON_PILULE)
		if etat in ["normal", "hover", "pressed", "disabled"]:
			style.border_color = LISERE
			style.set_border_width_all(1)
		if etat == "focus":
			# Anneau de focus de la charte : doré, 2 px, décalé de 2 px.
			style.border_color = Charte.OR
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override(etat, style)
	bouton.custom_minimum_size = Vector2(0, roundf(40 * eh))
	_placer_puce(bouton)

## Fond de la bande des commandes (phrase d'état, Équipe, Réglages, Plus), dans la continuité du bandeau du score :
## le même panneau à 90 %, rayon 18, à la même hauteur, derrière la phrase (à sa largeur de texte) et derrière le
## groupe des commandes. Sur la 3D, rien de la barre du haut ne reste posé à nu sur l'image.
func _fond_bande() -> void:
	var bande := bande_temps_forts
	if bande == null or not is_instance_valid(_coque_score): return
	var hauteur := maxf(_coque_score.size.y, bande.size.y)
	var haut := roundf((bande.size.y - hauteur) * 0.5)
	var marge := roundf(14 * echelle)
	var style := Charte.style_panneau(BandeauAngle.FOND, Charte.RAYON_PANNEAU, 0).duplicate() as StyleBoxFlat
	style.border_color = LISERE
	style.set_border_width_all(1)
	var groupe := Rect2()
	for enfant in bande.get_children():
		var c := enfant as Control
		if c == null or not c.visible: continue
		if c is Label and c.size_flags_horizontal & Control.SIZE_EXPAND:
			var texte := (c as Label).text.strip_edges()
			if texte.is_empty(): continue
			var largeur := c.get_theme_font("font").get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x + 2.0 * marge
			bande.draw_style_box(style, Rect2(c.position.x, haut, minf(c.size.x, largeur), hauteur))
			continue
		var r := Rect2(c.position, c.size)
		groupe = r if groupe.size == Vector2.ZERO else groupe.merge(r)
	if groupe.size != Vector2.ZERO:
		bande.draw_style_box(style, Rect2(groupe.position.x - marge, haut, groupe.size.x + 2.0 * marge, hauteur))

## Redessine le fond de la bande quand ce qu'elle montre change (texte de la phrase, commandes visibles, taille).
var _cle_bande := ""
func _suivre_fond_bande() -> void:
	if bande_temps_forts == null or not bande_temps_forts.visible: return
	var cle := str(bande_temps_forts.size)
	for enfant in bande_temps_forts.get_children():
		var c := enfant as Control
		if c == null: continue
		# La phrase garde une marge intérieure : son texte ne touche pas le bord de son fond.
		if c is Label and c.size_flags_horizontal & Control.SIZE_EXPAND and not c.has_theme_stylebox_override("normal"):
			var retrait := StyleBoxEmpty.new()
			retrait.content_margin_left = roundf(14 * echelle)
			retrait.content_margin_right = roundf(14 * echelle)
			c.add_theme_stylebox_override("normal", retrait)
		cle += "|%s%s%s" % [c.visible, c.position, (c as Label).text if c is Label else ""]
	if cle == _cle_bande: return
	_cle_bande = cle
	bande_temps_forts.queue_redraw()

## Bandeau d'angle : [horloge / période] [plaque du club recevant] [score] [plaque du visiteur ⟋].
func _construire_bandeau(parent: Control) -> void:
	var bandeau := BandeauAngle.new()
	bandeau.name = "MatchScoreboard"
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(bandeau)
	_coque_score = bandeau
	var horloge := _segment("MatchClockBlock", Charte.PANNEAU_3)
	bandeau.add_child(horloge)
	var pile := VBoxContainer.new()
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("separation", -4)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horloge.add_child(pile)
	clock = _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
	clock.name = "MatchClock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(clock)
	phase = _texte("", Charte.texte_moyen(), Charte.IVOIRE_2)
	phase.name = "MatchPhase"
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile.add_child(phase)
	for cote in 2:
		var sigle := _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
		sigle.name = "MatchCompactAbbr%d" % cote
		sigle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sigles.append(sigle)
	home = _texte("", Charte.TITRE_GRAS, Charte.IVOIRE)
	home.name = "MatchHomeName"
	away = _texte("", Charte.TITRE_GRAS, Charte.IVOIRE)
	away.name = "MatchAwayName"
	bandeau.add_child(_plaque(0))
	var bloc_score := _segment("MatchScoreBlock", Charte.PANNEAU)
	bandeau.add_child(bloc_score)
	score = _texte("", Charte.TITRE_EXTRA, Charte.IVOIRE)
	score.name = "MatchScore"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bloc_score.add_child(score)
	bandeau.add_child(_plaque(1))

func _segment(nom: String, fond: Color) -> PanelContainer:
	var segment := PanelContainer.new()
	segment.name = nom
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return segment

static func _texte(texte: String, police: Font, couleur: Color) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.add_theme_font_override("font", police)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return etiquette

## Plaque d'un club : logo du club (_poser_ecusson, à la place de la pastille du sigle), nom en capitales ; survol ou focus : le nom se souligne.
## Clic ou Entrée : petite fenêtre du club par-dessus le match (le match se met en pause).
func _plaque(cote: int) -> PanelContainer:
	var plaque := _segment("MatchClubPlaque%d" % cote, Charte.CLUB)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	plaque.focus_mode = Control.FOCUS_ALL
	plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque.add_child(rangee)
	var puce := PanelContainer.new()
	puce.name = "MatchClubChip%d" % cote
	puce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puce.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	puce.add_child(_sigles[cote])
	var nom := VBoxContainer.new()
	nom.name = "MatchClubName%d" % cote
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nom.alignment = BoxContainer.ALIGNMENT_CENTER
	nom.add_theme_constant_override("separation", 0)
	nom.size_flags_vertical = Control.SIZE_FILL
	var etiquette: Label = home if cote == 0 else away
	etiquette.clip_text = true
	etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom.add_child(etiquette)
	var souligne := ColorRect.new()
	souligne.name = "Souligne"
	souligne.color = Charte.IVOIRE
	souligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	souligne.modulate.a = 0.0
	nom.add_child(souligne)
	if cote == 0:
		rangee.add_child(puce)
		rangee.add_child(nom)
	else:
		rangee.add_child(nom)
		rangee.add_child(puce)
	var survol := func(actif: bool): souligne.modulate.a = 1.0 if actif else 0.0
	plaque.mouse_entered.connect(survol.bind(true))
	plaque.mouse_exited.connect(func(): survol.call(plaque.has_focus()))
	plaque.focus_entered.connect(survol.bind(true))
	plaque.focus_exited.connect(survol.bind(false))
	plaque.gui_input.connect(func(event: InputEvent):
		var souris := event as InputEventMouseButton
		var touche := event as InputEventKey
		if is_instance_valid(menu) and menu.visible: return
		if (souris != null and souris.pressed and souris.button_index == MOUSE_BUTTON_LEFT) or (touche != null and touche.pressed and not touche.echo and touche.is_action("ui_accept")):
			plaque.accept_event()
			ouvrir_fiche_club(cote))
	plaques.append(plaque)
	return plaque

## Journal en bas à gauche (charte §7) : deux faits, minute en Barlow Condensed droite, texte DM Sans 16 px sur
## panneau 90 % rayon 18 ; le plus ancien en ivoire secondaire. Les noms de nos joueurs sont des liens (survol : mini-fiche ;
## clic : la fenêtre Équipe sur lui).
func _construire_journal(frame: Control) -> void:
	var rangee := S.G.h(10)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rangee)
	var cadre := PanelContainer.new()
	cadre.name = "MatchJournalPanel"
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO))
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	rangee.add_child(cadre)
	_legende = cadre
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.name = "MatchJournalLines"
	colonne.mouse_filter = Control.MOUSE_FILTER_PASS
	marge.add_child(colonne)
	events = S.wrap("", 16, Charte.IVOIRE)
	events.name = "MatchLastEvent"
	events.hide()
	colonne.add_child(events)
	for rang in 2:
		var ligne := HBoxContainer.new()
		ligne.name = "MatchJournalLine%d" % rang
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_theme_constant_override("separation", 12)
		colonne.add_child(ligne)
		var minute := _texte("", Charte.TITRE_GRAS, Charte.IVOIRE if rang == 0 else Charte.IVOIRE_2)
		minute.name = "Minute"
		minute.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ligne.add_child(minute)
		var texte := RichTextLabel.new()
		texte.name = "Texte"
		texte.bbcode_enabled = true
		texte.fit_content = true
		texte.scroll_active = false
		texte.autowrap_mode = TextServer.AUTOWRAP_OFF
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		texte.add_theme_font_override("normal_font", Charte.texte_moyen())
		texte.add_theme_color_override("default_color", Charte.IVOIRE if rang == 0 else Charte.IVOIRE_2)
		C.fill(texte)
		texte.meta_hover_started.connect(func(meta: Variant): _survol_joueur(str(meta), texte))
		texte.meta_hover_ended.connect(func(_meta: Variant): _mini_fiche().cacher(app, texte))
		texte.meta_clicked.connect(func(meta: Variant): ouvrir_joueur(str(meta)))
		ligne.add_child(texte)
		ligne.hide()
		_journal_lignes.append([minute, texte, ligne])
	rangee.add_child(S.G.spacer())

## Barre du bas : repli sans régie (caméras, cadence, tiroirs) et fin de match (« Valider la journée »,
## action principale : la seule pilule dorée du direct, charte finale §4.3).
func _construire_barre_bas(frame: Control) -> void:
	var cadre := PanelContainer.new()
	cadre.name = "MatchBottomBar"
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO))
	frame.add_child(cadre)
	barre_commandes = cadre
	var marge := S.G.margin(8)
	cadre.add_child(marge)
	var controls := VBoxContainer.new()
	marge.add_child(controls)
	var bar := S.G.h(7)
	controls.add_child(bar)
	var bouton_equipe := _lien("ÉQUIPE", func(): ouvrir_equipe())
	bouton_equipe.name = "MatchTeamButton"
	bouton_equipe.tooltip_text = "Composition, banc, cris de la touche et consignes (le match se met en pause)."
	bar.add_child(bouton_equipe)
	for title in ["Stats", "Journal"]:
		bar.add_child(_lien(title.to_upper(), func(): _toggle_drawer(title)))
	for pair in [["tv", "TV"], ["tactical", "VUE DE DESSUS"], ["action", "CONTACT"]]:
		var button := _lien(pair[1], func(): _choose_camera(pair[0]))
		_camera_controls.append(button)
		bar.add_child(button)
	_cadence = OptionButton.new()
	_cadence.custom_minimum_size.y = 38
	for text in ["Cadence ×1", "Cadence ×4", "Cadence ×12"]: _cadence.add_item(text)
	_cadence.select(maxi(0, [1, 4, 12].find(app.tick_steps)))
	_cadence.item_selected.connect(_choisir_cadence)
	_cadence.set_meta("contextual_enabled", true)
	bar.add_child(_cadence)
	# Ce que le match montre, des temps forts choisis au match complet : visible en temps forts.
	_niveau = OptionButton.new()
	_niveau.name = "MatchLevel"
	_niveau.custom_minimum_size.y = 38
	_niveau.tooltip_text = "Ce que le match montre : des temps forts choisis au match complet. Conservé pour les prochains matchs."
	_niveau.set_meta("contextual_enabled", true)
	_niveau.item_selected.connect(func(index: int): if regie != null and index >= 0 and index < _niveaux.size(): regie.choisir_niveau(str(_niveaux[index].get("id", ""))))
	_niveau.hide()
	bar.add_child(_niveau)
	bar.add_child(S.G.spacer())
	bar.add_child(_lien("CONFIER LA FIN À L’ADJOINT", confier_fin))
	finish = Button.new()
	finish.text = "VALIDER LA JOURNÉE  →"
	finish.name = "MatchFinishButton"
	finish.pressed.connect(func(): director.command("finish_round"))
	finish.set_meta("contextual_enabled", false)
	finish.disabled = true
	C.style_bouton_ivoire_plein(finish, 21)
	bar.add_child(finish)

func _lien(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.pressed.connect(action)
	bouton.set_meta("contextual_enabled", true)
	C.style_bouton_lien(bouton, 19)
	return bouton

func _construire_tiroir() -> void:
	drawer = PanelContainer.new()
	drawer.name = "MatchDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	drawer.offset_left = -450
	drawer.offset_right = -MARGE
	drawer.offset_top = 100
	# En temps forts, le tiroir s'ouvre sous la rangée du haut : Équipe, Réglages et Plus restent
	# cliquables tiroir ouvert.
	if bande_temps_forts != null:
		var caler := func():
			if is_instance_valid(drawer) and bande_temps_forts.is_inside_tree():
				drawer.offset_top = maxf(100.0, bande_temps_forts.get_global_rect().end.y - get_global_rect().position.y + 8.0)
		bande_temps_forts.resized.connect(caler)
		bande_temps_forts.item_rect_changed.connect(caler)
	drawer.anchor_bottom = 1
	drawer.offset_bottom = -90
	# Charte finale §3 : panneau rayon 18, sans bordure ; il se détache de l'image par sa clarté.
	drawer.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO, Charte.PANNEAU))
	add_child(drawer)
	var drawer_margin := S.G.margin(14)
	drawer.add_child(drawer_margin)
	var drawer_column := S.G.v(8)
	drawer_margin.add_child(drawer_column)
	drawer_column.add_child(_lien("FERMER  ×", _fermer_tiroir))
	drawer_body = S.G.scroll(drawer_column)
	S.G.fill(drawer_body.get_parent(), true)
	_journal_shell = PanelContainer.new()
	_journal_shell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	S.G.fill(_journal_shell, true)
	drawer_column.add_child(_journal_shell)
	var journal_margin := S.G.margin(8)
	_journal_shell.add_child(journal_margin)
	journal = preload("res://ui/match_journal.gd").new()
	journal.setup(app)
	# Journal du tiroir aux jetons de la Charte ; « Relire » ouvre une page du direct ; nos joueurs sont liés
	# (survol : mini-fiche, clic : fiche complète), les adversaires restent du texte inerte (pas de fiche).
	journal.habiller_charte()
	journal.relire = ouvrir_relecture
	journal.lier = func(texte: String) -> String: return liens_joueurs(texte, model.get("squad", []) if model.get("squad") is Array else [])
	journal.sur_joueur = ouvrir_joueur
	journal.survol_joueur = _survol_joueur
	journal.fin_survol = func(ancre: Control): _mini_fiche().cacher(app, ancre)
	journal.contexte_change = func(): if _page_sorte == "relecture": fermer_page()
	journal_margin.add_child(journal)
	for defilement: Node in drawer.find_children("*", "ScrollContainer", true, false):
		(defilement as Control).add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_journal_shell.hide()
	drawer.hide()

# --- Échelle et état du bandeau ---------------------------------------------------

## Échelle de l'écran : 1 jusqu'en 1080p, puis proportionnelle à la hauteur (1,33 en 1440p).
static func echelle_pour(hauteur: float) -> float:
	return clampf(hauteur / 1080.0, 1.0, 2.0)

## Bandeau du score (le même en 3D et pendant l'entracte 2D), commandes et journal à l'échelle.
func _mettre_a_l_echelle() -> void:
	if not is_instance_valid(clock): return
	echelle = echelle_pour(get_viewport().get_visible_rect().size.y)
	var eh := echelle * BARRE_HAUT
	var t := func(cle: String) -> int: return roundi(float(BANDEAU_TAILLES[cle]) * (echelle if cle == "legende" else eh))
	# Les tuiles du haut (score, commandes, Reprendre) séparées par le vide des grandes tuiles (24 px en 2560) : la
	# gouttière couvre aussi le débord du fond dessiné derrière les commandes.
	var rangee_haut: HBoxContainer = clock.find_parent("MatchTopRow") as HBoxContainer
	if rangee_haut != null: rangee_haut.add_theme_constant_override("separation", roundi((18 + 14) * echelle))
	var marge: MarginContainer = clock.find_parent("MatchHud").get_parent() if clock.find_parent("MatchHud") != null else null
	if marge != null:
		for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, roundi(MARGE * echelle))
	clock.add_theme_font_size_override("font_size", t.call("horloge"))
	phase.add_theme_font_size_override("font_size", t.call("phase"))
	score.add_theme_font_size_override("font_size", t.call("score"))
	for nom: Label in [home, away]: nom.add_theme_font_size_override("font_size", t.call("equipe"))
	for sigle: Label in _sigles: sigle.add_theme_font_size_override("font_size", t.call("sigle"))
	var hauteur := roundf(BANDEAU_HAUTEUR * eh)
	for segment: Control in _coque_score.get_children():
		segment.custom_minimum_size.y = hauteur
		var marges := StyleBoxEmpty.new()
		marges.content_margin_left = roundf(12 * eh)
		marges.content_margin_right = roundf(16 * eh)
		if segment.name == "MatchClubPlaque1": marges.content_margin_right = roundf(18 * eh)
		if segment.name == "MatchClockBlock": marges.content_margin_left = roundf(14 * eh)
		if segment.name == "MatchScoreBlock":
			marges.content_margin_left = roundf(16 * eh)
		segment.add_theme_stylebox_override("panel", marges)
	(_coque_score.get_node("MatchClockBlock") as Control).custom_minimum_size.x = roundf(96 * eh)
	score.custom_minimum_size.x = roundf(104 * eh)
	for plaque: PanelContainer in plaques:
		var rangee: HBoxContainer = plaque.get_child(0)
		rangee.add_theme_constant_override("separation", roundi(10 * eh))
		var souligne: ColorRect = plaque.find_child("Souligne", true, false)
		souligne.custom_minimum_size.y = maxf(1.0, roundf(2 * eh))
	for etiquette: Label in [meteo_ligne]: etiquette.add_theme_font_size_override("font_size", t.call("meteo"))
	for bouton: Button in [play, indice_menu]: _habiller_bouton_hud(bouton)
	_possession_texte.add_theme_font_size_override("font_size", t.call("legende"))
	_possession_trait.custom_minimum_size = Vector2(roundf(7 * echelle), roundf(20 * echelle))
	ligne_possession.custom_minimum_size.y = roundf(36 * echelle)
	ligne_possession.add_theme_stylebox_override("panel", _fond_hud(Vector4(roundf(9 * echelle), 0, roundf(16 * echelle), 0)))
	(ligne_possession.get_child(0) as HBoxContainer).add_theme_constant_override("separation", roundi(10 * echelle))
	if is_instance_valid(_legende):
		# 744 px en 1080p ; jamais plus de 45 % de la largeur (1280 × 720 : 576 px, la 3D garde sa place).
		_legende.custom_minimum_size.x = mini(roundi(LEGENDE_LARGEUR * echelle), roundi(get_viewport_rect().size.x * 0.45))
		var marge_journal: MarginContainer = _legende.get_child(0)
		for bord in ["left", "right"]: marge_journal.add_theme_constant_override("margin_" + bord, roundi(16 * echelle))
		for bord in ["top", "bottom"]: marge_journal.add_theme_constant_override("margin_" + bord, roundi(9 * echelle))
	for ligne: Array in _journal_lignes:
		(ligne[0] as Label).add_theme_font_size_override("font_size", roundi(17 * echelle))
		(ligne[0] as Label).custom_minimum_size.x = roundf(32 * echelle)
		(ligne[1] as RichTextLabel).add_theme_font_size_override("normal_font_size", t.call("legende"))
	events.add_theme_font_size_override("font_size", t.call("legende"))
	_plaques_cle = ""
	_poser_plaques(_live().get("teams", []))
	if is_instance_valid(_menu_panneau): _placer_menu()

## État du bandeau et du bouton de pause, sans nœud (testable seul).
## `regie_active` : la régie des temps forts cadence le match ; `action_3d` : un temps fort est
## à l'écran ; `action_figee` : ce temps fort est figé par une pause du manager ; `attente` : la 3D
## reste à l'écran entre deux temps forts contigus (le bandeau ne bat pas entre les deux).
## Rend {compact, pause (libellé), pause_possible}.
static func etat_bandeau(live: Dictionary, regie_active: bool, action_3d: bool, action_figee: bool, attente: bool = false) -> Dictionary:
	var fini := bool(live.get("finished", false))
	var arrete := bool(live.get("paused", false))
	var joue: bool
	var reduit: bool
	if regie_active:
		# Le moteur peut déjà être arrêté (mi-temps atteinte, pause d'avant l'action) pendant que le
		# temps fort se joue encore à l'écran : c'est l'image qui dit si le match joue.
		joue = (action_3d and not action_figee) or (not action_3d and not arrete)
		reduit = (action_3d and not action_figee) or (attente and not arrete)
	else:
		joue = not arrete
		reduit = not arrete and not bool(live.get("atBreak", false))
	joue = joue and not fini
	reduit = reduit and not fini and not live.is_empty()
	# Action montrée alors que le moteur est déjà arrêté : rien à mettre en pause, elle se termine.
	return {"compact": reduit, "pause": "PAUSE" if joue or (fini and not arrete) else "REPRENDRE",
		"pause_possible": not fini and not (joue and arrete)}

## Libellé affiché du bouton (« Pause » / « Reprendre ») pour l'état rendu par etat_bandeau.
static func libelle_pause(etat: Dictionary) -> String:
	return "Pause" if str(etat.get("pause", "")) == "PAUSE" else "Reprendre"

## Période sous l'horloge : « 1re MT », « 2e MT », « Prol. ».
static func periode_texte(live: Dictionary) -> String:
	if live.is_empty(): return ""
	var periode := int(live.get("period", 2 if int(live.get("minute", 0)) > 40 else 1))
	return "1re MT" if periode <= 1 else ("2e MT" if periode == 2 else "Prol.")

func _etat_bandeau() -> Dictionary:
	var action: bool = regie != null and regie.etat == regie.JEU
	var attente: bool = regie != null and regie.etat == regie.ATTENTE
	return etat_bandeau(_live(), temps_forts_actifs(), action, action and bool(regie.gel), attente)

func _process(_delta: float) -> void:
	if not is_instance_valid(play) or not is_instance_valid(_coque_score): return
	_suivre_fond_bande()
	var etat := _etat_bandeau()
	_poser_pause(etat)
	if bool(etat.compact) != compact: _appliquer_bandeau(bool(etat.compact))
	_suivre_apres_match()
	if _recouvrir > 0:
		_recouvrir -= 1
		if _recouvrir == 0: _recadrer()
	_poser_periode()
	_suivre_journal()
	# Rappel « Échap » : en 3D seulement (l'entracte a ses propres rappels) et hors action en cours.
	var entracte: bool = regie != null and regie.between != null and regie.between.visible
	var rappel: bool = not compact and not entracte and not _live().get("finished", false)
	if indice_menu.visible != rappel: indice_menu.visible = rappel
	_suivre_possession(entracte)
	# Écran 2D : la météo est posée sur le terrain en icônes (retouche de Léo du 21/11/2026), plus de phrase ici.
	var meteo_vue: bool = not compact and meteo_ligne.visible and not entracte
	if _meteo_boite.visible != meteo_vue: _meteo_boite.visible = meteo_vue
	# La fenêtre Équipe ouverte depuis la bande ferme le menu (le match reste en pause).
	if is_instance_valid(menu) and menu.visible and is_instance_valid(equipe) and equipe.visible: _cacher_menu()
	# Panneau du menu : ses lignes à retour automatique ne connaissent leur hauteur qu'après une mise en page.
	if is_instance_valid(menu) and menu.visible: _placer_menu()
	if _pause_voulue != 0 and not app.waiting:
		var voulue := _pause_voulue > 0
		_pause_voulue = 0
		if bool(_live().get("paused", false)) != voulue and not _live().get("finished", false): director.command("pause", {"paused": voulue})

## Qui a le ballon : en 3D, la phrase d'état de l'écran 14 passe sous le bandeau, sur panneau, avec le liseré
## du club nommé en tête ; la phrase de la bande s'efface (elle revient telle quelle à l'entracte).
func _suivre_possession(entracte: bool) -> void:
	var etat_jeu: Label = regie.between.get("etat") if regie != null and regie.between != null and regie.between.get("etat") is Label else null
	var texte := etat_jeu.text.strip_edges() if etat_jeu != null else ""
	# Pendant une bannière (essai, mi-temps, fin), la phrase se tait : la bannière dit déjà le fait.
	var banniere: bool = regie != null and regie.get("bandeau") is Control and (regie.bandeau as Control).visible
	var montre: bool = etat_jeu != null and not entracte and not banniere and not texte.is_empty() and texte != "Le match" and not _live().get("finished", false)
	if etat_jeu != null:
		var alpha := 0.0 if montre else 1.0
		if etat_jeu.modulate.a != alpha: etat_jeu.modulate.a = alpha
	if ligne_possession.visible != montre: ligne_possession.visible = montre
	if not montre or _possession_texte.text == texte: return
	_possession_texte.text = texte
	var couleur := Charte.IVOIRE_2
	var equipes: Array = _live().get("teams", [])
	for cote in equipes.size():
		if equipes[cote] is Dictionary and texte.begins_with(S.G.club_name(equipes[cote])):
			couleur = Charte.club_trait(Color.from_string(str(S.G.identity(equipes[cote]).get("color", "")), Charte.CLUB))
	(_possession_trait as Marqueur).couleur = couleur
	_possession_trait.queue_redraw()

## Période sous l'horloge, et horloge plus petite quand elle écrit un mot (« MI-TEMPS », « TERMINÉ »).
func _poser_periode() -> void:
	var numerique := not clock.text.is_empty() and clock.text.substr(0, 1).is_valid_int()
	var texte := periode_texte(_live()) if numerique else ""
	if phase.text != texte: phase.text = texte
	phase.visible = not texte.is_empty()
	var taille := roundi((BANDEAU_TAILLES.horloge if numerique else 22) * echelle)
	if clock.get_theme_font_size("font_size") != taille: clock.add_theme_font_size_override("font_size", taille)

## Libellé et accès du bouton : « Pause » tant que le match joue à l'écran, « Reprendre » en pause.
func _poser_pause(etat: Dictionary) -> void:
	var libelle := libelle_pause(etat)
	if play.text != libelle: play.text = libelle
	var possible: bool = bool(etat.pause_possible) and director._talk().is_empty()
	var aide := "" if bool(etat.pause_possible) or bool(_live().get("finished", false)) else "Le match est déjà arrêté : l’action en cours se termine."
	if play.tooltip_text != aide: play.tooltip_text = aide
	if bool(play.get_meta("contextual_enabled", true)) != possible:
		play.set_meta("contextual_enabled", possible)
		director._refresh_controls()

## Pendant l'action 3D, la météo et le rappel Échap se retirent ; le bandeau du score reste entier.
func _appliquer_bandeau(valeur: bool) -> void:
	compact = valeur
	if is_instance_valid(_meteo_boite): _meteo_boite.visible = not compact
	_recouvrir = 2

## Le cadrage des temps forts tient compte de la part d'image cachée en haut et en bas.
## Même mesure que la régie au début de chaque plan.
func _recadrer() -> void:
	if regie == null or regie.etat != regie.JEU: return
	var cadrage: Variant = regie.get("cadrage")
	if cadrage == null or not is_instance_valid(clock): return
	var hauteur := maxf(1.0, size.y)
	var legende: Control = events.get_parent().get_parent().get_parent()
	cadrage.couvrir(clock.get_global_rect().end.y / hauteur + 0.03, (hauteur - legende.get_global_rect().position.y) / hauteur + 0.02)

func update_frame(value: Dictionary) -> void:
	model = value
	if not is_node_ready(): return
	var live := _live()
	var teams: Array = live.get("teams", [{}, {}])
	if teams.size() >= 2:
		for cote in 2: _sigles[cote].text = S.G.club_abbr(teams[cote]) if teams[cote] is Dictionary else ""
		_poser_plaques(teams)
	var scores: Array = live.get("score", [0, 0])
	score.text = "%d — %d" % [int(scores[0]), int(scores[1])]
	clock.text = "%d′" % int(live.get("minute", 0))
	if live.get("finished", false): clock.text = "TERMINÉ"
	elif live.get("atBreak", false): clock.text = "MI-TEMPS"
	meteo_ligne.text = Meteo.bandeau(live)
	meteo_ligne.visible = not meteo_ligne.text.is_empty()
	meteo_ligne.add_theme_color_override("font_color", Charte.IVOIRE if live.get("atBreak", false) else Charte.IVOIRE_2)
	meteo_ligne.tooltip_text = Meteo.conseil(live)
	meteo_ligne.mouse_filter = Control.MOUSE_FILTER_PASS if not meteo_ligne.tooltip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
	finish.visible = live.get("finished", false)
	finish.set_meta("contextual_enabled", live.get("finished", false))
	if stage.has_method("set_club_identity"): stage.set_club_identity(model.get("club", {}))
	if regie == null:
		stage.set_live_cadence(app.tick_steps)
		stage.apply_frame(live)
		# Repli : les deux derniers faits du moteur, avec leur minute.
		var rows: Array = live.get("events", [])
		var faits: Array = []
		for event: Variant in rows.slice(maxi(0, rows.size() - 2)):
			if event is Dictionary: faits.push_front({"minute": "%s'" % str(event.get("min", "")), "texte": sigles_affiches(str(event.get("text", "")), live.get("teams", []))})
			else: faits.push_front({"minute": "", "texte": str(event)})
		_journal = faits
		events.text = str(faits[0].texte) if not faits.is_empty() else ""
		_journal_texte = events.text.strip_edges()
		_dessiner_journal()
		events.get_parent().get_parent().visible = not faits.is_empty()
		_legende.visible = not faits.is_empty()
	if regie != null:
		regie.receive(model, live)
		if live.get("direct") is Dictionary: montrer_reglages_temps_forts(live.direct, regie)
	_update_drawer()
	if is_instance_valid(equipe): equipe.update_frame(model)
	if is_instance_valid(apres_match): apres_match.update_frame(model)
	_suivre_apres_match()
	apply_preferences()
	# Après la régie (elle dit si un temps fort se joue) : libellé et accès du bouton de pause ;
	# une causerie retenue par un temps fort bloque aussi la reprise (elle passera par elle).
	var etat := _etat_bandeau()
	_poser_pause(etat)
	if bool(etat.compact) != compact: _appliquer_bandeau(bool(etat.compact))
	if is_instance_valid(page) and page.visible: _actualiser_page()
	if is_instance_valid(menu) and menu.visible: _actualiser_menu()
	director._refresh_controls()

## Couleur de chaque club sur son écusson seulement (puce du sigle, rayon 6, assombrie pour la crème ; jamais
## l'or) ; la plaque reste sur le panneau du bandeau (charte finale §4.3 : couleurs de club sur écusson, maillot, liseré).
func _poser_plaques(teams: Array) -> void:
	var cle := JSON.stringify(teams.map(func(t: Variant): return [S.G.club_name(t), S.G.identity(t).get("color", "")] if t is Dictionary else []))
	if cle == _plaques_cle or plaques.size() < 2: return
	_plaques_cle = cle
	for cote in 2:
		var couleur := Charte.CLUB
		if teams.size() > cote and teams[cote] is Dictionary:
			couleur = Color.from_string(str(S.G.identity(teams[cote]).get("color", "")), Charte.CLUB)
		var ecusson := fond_plaque(couleur)
		plaques[cote].set_meta("ecusson", ecusson)
		var puce: PanelContainer = plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
		var style := StyleBoxFlat.new()
		style.bg_color = ecusson
		# Club trop sombre pour se détacher du panneau : contour crème 12 % (FILET).
		style.border_color = Charte.FILET if Charte.contraste(ecusson, Charte.PANNEAU) < 1.5 else Color(0, 0, 0, 0)
		style.set_border_width_all(1 if style.border_color.a > 0 else 0)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		style.anti_aliasing = true
		style.content_margin_left = roundf(7 * echelle)
		style.content_margin_right = roundf(7 * echelle)
		style.content_margin_top = roundf(2 * echelle)
		style.content_margin_bottom = roundf(2 * echelle)
		puce.add_theme_stylebox_override("panel", style)
		_poser_ecusson(cote, teams)
		# Noms très longs : 300 px au plus (1920 × 1080) par plaque, environ 150 px en 1280 × 720 (les commandes
		# tiennent sur la même rangée) ; au-delà, le nom court (sans ses derniers mots), sinon le sigle. Jamais « … ».
		var nom: Label = home if cote == 0 else away
		var complet := S.G.club_name(teams[cote]) if teams.size() > cote and teams[cote] is Dictionary else ""
		var police: Font = nom.get_theme_font("font")
		var taille := nom.get_theme_font_size("font_size")
		var plafond := clampf((get_viewport_rect().size.x / echelle - 1000.0) * 0.55, 140.0, 300.0) * echelle
		nom.text = nom_court(complet, _sigles[cote].text, police, taille, plafond)
		nom.custom_minimum_size.x = police.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x + 2.0
		plaques[cote].tooltip_text = complet
	_coque_score.queue_redraw()

## Choix de Léo (21/11/2026) : le logo du club À LA PLACE de la pastille du sigle (même emplacement, 44 px en 1080p),
## jamais les deux : le vrai logo quand un pack d'identité en fournit un (logoPath de la présentation), sinon l'écusson
## dessiné aux couleurs et initiales du club (celui du stade). La pastille reste cachée, stylée (couleur de l'écusson).
## Le logo laisse passer la souris : un clic dessus ouvre la fiche du club comme la plaque.
func _poser_ecusson(cote: int, teams: Array) -> void:
	var puce: Control = plaques[cote].find_child("MatchClubChip%d" % cote, true, false)
	var rangee: Container = puce.get_parent()
	var ancien := rangee.get_node_or_null("MatchClubCrest%d" % cote)
	if ancien != null:
		rangee.remove_child(ancien)
		ancien.queue_free()
	puce.visible = true
	if teams.size() <= cote or not (teams[cote] is Dictionary): return
	var ecusson := ecusson_club(_club_complet(teams[cote]), roundi(44 * echelle * BARRE_HAUT))
	ecusson.name = "MatchClubCrest%d" % cote
	ecusson.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecusson.tooltip_text = ""
	for enfant in ecusson.find_children("*", "Control", true, false): (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(ecusson)
	rangee.move_child(ecusson, puce.get_index())
	puce.visible = false

## Logo du club (`logoPath` d'un pack d'identité), sinon l'écusson dessiné aux couleurs et initiales du club, dans une
## case de `largeur` px : plaques du bandeau et petite fenêtre du club.
func ecusson_club(club: Dictionary, largeur: int) -> Control:
	var ecusson: Control
	var logo: Texture2D = S.G.Base._pack_texture(str(S.G.identity(club).get("logoPath", club.get("logoPath", ""))))
	if logo != null:
		var image := TextureRect.new()
		image.texture = logo
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2.ONE * largeur
		image.set_meta("logo_pack", true)
		ecusson = image
	else:
		# L'image de l'écusson dessiné a une marge transparente (forme ≈ 65 % du cadre) : dessinée à 150 % dans une case
		# de 44 px, la forme fait ≈ 44 px (taille choisie sur la planche) sans grandir le bandeau ni serrer les noms.
		var dessin_taille := roundi(largeur * 1.5)
		var dessin: Control = load("res://ui/tenue_club.gd").ecusson(club, dessin_taille)
		if dessin == null: dessin = S.G.crest(club, dessin_taille)
		dessin.custom_minimum_size = Vector2.ONE * dessin_taille
		dessin.size = Vector2.ONE * dessin_taille
		dessin.position = Vector2.ONE * float(largeur - dessin_taille) / 2.0
		ecusson = Control.new()
		ecusson.custom_minimum_size = Vector2.ONE * largeur
		ecusson.add_child(dessin)
		# Initiales jamais masquées (l'écusson les cache sous 11 px) et toujours lues : ivoire, contour sombre.
		for initiales in dessin.find_children("*", "Label", true, false):
			var etiquette := initiales as Label
			etiquette.add_theme_font_size_override("font_size", maxi(11, roundi(dessin_taille * 0.22)))
			etiquette.add_theme_color_override("font_color", Charte.IVOIRE)
			etiquette.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.07, 0.95))
			etiquette.add_theme_constant_override("outline_size", maxi(3, roundi(dessin_taille * 0.07)))
	return ecusson

## Club du direct complété par sa fiche du classement ou du catalogue (identité, dont le logo du pack).
func _club_complet(equipe: Dictionary) -> Dictionary:
	if S.G.identity(equipe).has("logoPath") or equipe.has("logoPath"): return equipe
	var modele: Dictionary = app.model if app.model is Dictionary else {}
	for liste: Variant in [modele.get("league", []), modele.get("meta", {}).get("catalogue", []) if modele.get("meta") is Dictionary else []]:
		if not liste is Array: continue
		for club: Variant in liste:
			if club is Dictionary and str(club.get("id", "")) == str(equipe.get("id", "?")):
				var complet: Dictionary = club.duplicate()
				complet.merge(equipe, true)
				if club.get("presentation") is Dictionary and not equipe.get("presentation") is Dictionary: complet.presentation = club.presentation
				return complet
	return equipe

## Fond de l'écusson d'une plaque : la vraie couleur du club, assombrie (même teinte) jusqu'à ce que l'ivoire y soit lu à
## 5:1 au moins, contraste mesuré comme la charte (Charte.contraste) ; un club jaune ou or passe au bordeaux
## de la charte (l'or reste à Continuer).
const CONTRASTE_PLAQUE := 5.0
static func fond_plaque(couleur: Color) -> Color:
	var fond := Charte.CLUB if Charte._proche_de_l_or(couleur) or couleur.a <= 0.0 else Color(couleur, 1.0)
	var pas := 0
	while Charte.contraste(Charte.IVOIRE, fond) < CONTRASTE_PLAQUE and pas < 60:
		fond = fond.darkened(0.05)
		pas += 1
	return fond

## Nom affiché sur une plaque : le nom complet en capitales s'il tient dans `largeur`, sinon le nom sans ses
## derniers mots (« MEADOWBRIDGE »), sinon le sigle.
static func nom_court(nom: String, sigle: String, police: Font, taille: int, largeur: float) -> String:
	var mots := nom.to_upper().split(" ", false)
	while not mots.is_empty():
		var essai := " ".join(mots)
		if police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return essai
		mots.remove_at(mots.size() - 1)
	return sigle.to_upper()

# --- Journal ------------------------------------------------------------------

## Minute affichée par l'horloge (« 27′ », « 40+2:15 » → « 27' », « 40+2' ») ; vide pour un mot.
static func minute_de(horloge: String) -> String:
	var tete := horloge.strip_edges()
	for coupure in ["′", ":", "'"]:
		var i := tete.find(coupure)
		if i > 0: tete = tete.substr(0, i)
	return tete + "'" if not tete.is_empty() and tete.replace("+", "").is_valid_int() else ""

## Le texte du dernier fait a changé (régie ou repli) : il passe en tête du journal, l'ancien descend.
func _suivre_journal() -> void:
	var texte := events.text.strip_edges()
	if texte == _journal_texte: return
	_journal_texte = texte
	if texte.is_empty(): return
	if not _journal.is_empty() and str(_journal[0].texte) == texte: return
	_journal.push_front({"minute": minute_de(clock.text), "texte": texte})
	if _journal.size() > 2: _journal.resize(2)
	_dessiner_journal()

func _dessiner_journal() -> void:
	var joueurs: Array = model.get("squad", []) if model.get("squad") is Array else []
	# Journal vide : le panneau ne montre pas une bande sans texte.
	if is_instance_valid(_legende): _legende.self_modulate.a = 0.0 if _journal.is_empty() else 1.0
	for rang in _journal_lignes.size():
		var ligne: Array = _journal_lignes[rang]
		var fait: Dictionary = _journal[rang] if rang < _journal.size() and _journal[rang] is Dictionary else {}
		(ligne[2] as Control).visible = not fait.is_empty()
		(ligne[0] as Label).text = str(fait.get("minute", ""))
		var riche: RichTextLabel = ligne[1]
		# Un fait = une ligne (hauteur fixe de deux faits) : un texte trop long s'arrête sur un mot entier « … ».
		var bbcode := liens_joueurs(ligne_tenue(str(fait.get("texte", "")), Charte.texte_moyen(), riche.get_theme_font_size("normal_font_size"), _largeur_journal()), joueurs)
		if riche.text != bbcode: riche.text = bbcode

## Largeur utile d'une ligne du journal (panneau moins marges et colonne des minutes).
func _largeur_journal() -> float:
	if not is_instance_valid(_legende): return 600.0
	return maxf(120.0, _legende.custom_minimum_size.x - roundf(32 * echelle) - roundf(32 * echelle) - roundf(12 * echelle) - 4.0)

## `texte` s'il tient sur une ligne de `largeur`, sinon coupé au dernier mot entier qui tient, suivi de « … ».
static func ligne_tenue(texte: String, police: Font, taille: int, largeur: float) -> String:
	if police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return texte
	var mots := texte.split(" ", false)
	while mots.size() > 1:
		mots.remove_at(mots.size() - 1)
		var essai := " ".join(mots).trim_suffix(",").trim_suffix(":").strip_edges() + " …"
		if police.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x <= largeur: return essai
	return texte.left(12) + " …"

## Texte d'un fait en BBCode : chaque nom d'un de nos joueurs (nom complet, ou nom de famille sans
## ambiguïté) devient un lien [url=id] ; le reste est échappé. Les adversaires restent du texte.
static func liens_joueurs(texte: String, joueurs: Array) -> String:
	var motifs: Array = []
	var familles := {}
	for joueur: Variant in joueurs:
		if not joueur is Dictionary or joueur.get("id") == null: continue
		var nom := str(joueur.get("name", "")).strip_edges()
		if nom.is_empty(): continue
		var id := str(joueur.id)
		motifs.append([nom, id])
		var famille := nom.get_slice(" ", nom.get_slice_count(" ") - 1)
		if famille.length() >= 4 and famille != nom: familles[famille] = "" if familles.has(famille) else id
	for famille: String in familles:
		if not str(familles[famille]).is_empty(): motifs.append([famille, familles[famille]])
	motifs.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]).length() > str(b[0]).length())
	var pris: Array = []
	for motif: Array in motifs:
		var mot := str(motif[0])
		var depuis := 0
		while true:
			var i := texte.find(mot, depuis)
			if i < 0: break
			var f := i + mot.length()
			depuis = f
			if (i > 0 and _lettre(texte[i - 1])) or (f < texte.length() and _lettre(texte[f])): continue
			if pris.any(func(p: Array) -> bool: return i < int(p[1]) and f > int(p[0])): continue
			pris.append([i, f, motif[1]])
	pris.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var sortie := ""
	var curseur := 0
	for p: Array in pris:
		sortie += _echapper(texte.substr(curseur, int(p[0]) - curseur)) + "[url=%s]%s[/url]" % [str(p[2]), _echapper(texte.substr(int(p[0]), int(p[1]) - int(p[0])))]
		curseur = int(p[1])
	return sortie + _echapper(texte.substr(curseur))

static func _lettre(c: String) -> bool:
	return c.to_upper() != c.to_lower() or c.is_valid_int()

static func _echapper(texte: String) -> String:
	return texte.replace("[", "[lb]")

func _mini_fiche():
	return load("res://ui/immersive08/mini_fiche.gd")

func _survol_joueur(id: String, ancre: Control) -> void:
	var fiche: Control = _mini_fiche().montrer(app, id, "squad", ancre)
	# La mini-fiche se pose sur l'application : au-dessus de la scène du match (z 100).
	if fiche != null: fiche.z_index = 200

## Nom d'un de nos joueurs cliqué (journal, bannière d'essai, fenêtre Équipe, entracte) : sa petite fenêtre par-dessus
## le match (`ouvrir_fenetre_joueur`).
func ouvrir_joueur(id: String) -> void:
	ouvrir_fenetre_joueur(id)

## Id de l'un de `joueurs` dont le nom est `nom` (« Eddie WHITWORTH » : casse ignorée), sinon d'après le seul nom de
## famille s'il n'appartient qu'à un joueur ; "" si personne (adversaire : pas de fiche complète).
static func joueur_par_nom(nom: String, joueurs: Array) -> String:
	var cherche := nom.strip_edges().to_lower()
	if cherche.is_empty(): return ""
	var famille := cherche.get_slice(" ", cherche.get_slice_count(" ") - 1)
	var par_famille: Array[String] = []
	for joueur: Variant in joueurs:
		if not joueur is Dictionary or joueur.get("id") == null: continue
		var complet := str(joueur.get("name", "")).strip_edges().to_lower()
		if complet.is_empty(): continue
		if complet == cherche: return str(joueur.id)
		if famille.length() >= 3 and complet.get_slice(" ", complet.get_slice_count(" ") - 1) == famille: par_famille.append(str(joueur.id))
	return par_famille[0] if par_famille.size() == 1 else ""

## Nom du marqueur dans la bannière d'essai (match_temps_forts.gd) : l'un de nos joueurs devient un lien (souligné,
## main, mini-fiche au survol, fiche complète au clic) ; sinon le texte reste inerte, sans soulignement.
func lier_nom_bandeau(etiquette: Label, nom: String) -> void:
	if etiquette == null: return
	var id := joueur_par_nom(nom, model.get("squad", []) if model.get("squad") is Array else [])
	etiquette.set_meta("joueur_id", id)
	if not etiquette.has_meta("lien_pose"):
		etiquette.set_meta("lien_pose", true)
		var trait_nom := ColorRect.new()
		trait_nom.name = "Souligne"
		trait_nom.color = Charte.IVOIRE
		trait_nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trait_nom.anchor_top = 1.0
		trait_nom.anchor_bottom = 1.0
		trait_nom.offset_top = -2.0
		etiquette.add_child(trait_nom)
		# Le trait suit la longueur du nom, pas la largeur de la colonne.
		var caler := func():
			var police: Font = etiquette.get_theme_font("font")
			trait_nom.offset_right = police.get_string_size(etiquette.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiquette.get_theme_font_size("font_size")).x if police != null else etiquette.size.x
		etiquette.resized.connect(caler)
		etiquette.set_meta("caler_souligne", caler)
		etiquette.gui_input.connect(func(evenement: InputEvent):
			var clic := evenement as InputEventMouseButton
			var cible := str(etiquette.get_meta("joueur_id", ""))
			if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and not cible.is_empty():
				etiquette.accept_event()
				ouvrir_joueur(cible))
		etiquette.mouse_entered.connect(func():
			var cible := str(etiquette.get_meta("joueur_id", ""))
			if not cible.is_empty(): _survol_joueur(cible, etiquette))
		etiquette.mouse_exited.connect(func(): _mini_fiche().cacher(app, etiquette))
	var lie := not id.is_empty()
	etiquette.mouse_filter = Control.MOUSE_FILTER_STOP if lie else Control.MOUSE_FILTER_IGNORE
	etiquette.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lie else Control.CURSOR_ARROW
	etiquette.tooltip_text = "Voir sa fiche" if lie else ""
	(etiquette.get_node("Souligne") as Control).visible = lie
	(etiquette.get_meta("caler_souligne") as Callable).call()

## Texte des deux lignes du journal (tests, captures) : [« 27' Bickerstaff gagne la touche », …].
func journal_affiche() -> Array[String]:
	var lignes: Array[String] = []
	for ligne: Array in _journal_lignes:
		if (ligne[2] as Control).visible: lignes.append(("%s %s" % [(ligne[0] as Label).text, (ligne[1] as RichTextLabel).get_parsed_text()]).strip_edges())
	return lignes

# --- Clavier : Échap, Espace, T ---------------------------------------------------

func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree(): return
	if touche.ctrl_pressed or touche.alt_pressed or touche.meta_pressed: return
	var code: int = touche.keycode if touche.keycode != 0 else touche.physical_keycode
	var menu_ouvert := is_instance_valid(menu) and menu.visible
	# Petite fenêtre ouverte : comme une page, elle garde Espace et T.
	var page_ouverte := (is_instance_valid(page) and page.visible) or fenetre_ouverte()
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# Une petite fenêtre ouverte passe avant le menu du match.
		if not PetiteFenetre.fermer_derniere(get_tree()): echap()
	elif code == KEY_SPACE:
		if menu_ouvert:
			get_viewport().set_input_as_handled()
			fermer_menu(true)
		# Une commande qui a le focus (liste du journal, bouton) garde son Espace.
		elif not page_ouverte and not equipe.visible and not play.disabled and not get_viewport().gui_get_focus_owner() is BaseButton:
			get_viewport().set_input_as_handled()
			_pause()
	elif code == KEY_T and not menu_ouvert and not page_ouverte and not equipe.visible and not _live().get("finished", false):
		get_viewport().set_input_as_handled()
		ouvrir_equipe()
	elif menu_ouvert and code in [KEY_LEFT, KEY_RIGHT]:
		var vitesse: Control = menu.find_child("MatchMenuVitesse", true, false)
		if vitesse != null and vitesse.has_focus():
			get_viewport().set_input_as_handled()
			_changer_vitesse(1 if code == KEY_RIGHT else -1)

## Échap : ferme ce qui est ouvert (page, menu, fenêtre Équipe, tiroir) ; sinon met en pause et ouvre le
## menu du match (jamais celui de la carrière).
func echap() -> void:
	_mini_fiche().cacher(app)
	# Après-match (écran 15) : Échap ne ferme rien et n'ouvre pas le menu du match (décision du 16/11).
	if is_instance_valid(apres_match) and apres_match.visible: return
	if is_instance_valid(page) and page.visible:
		fermer_page()
	elif is_instance_valid(menu) and menu.visible:
		fermer_menu(true)
	elif is_instance_valid(equipe) and equipe.visible:
		equipe.fermer()
	elif drawer.visible:
		_fermer_tiroir()
	else:
		ouvrir_menu()

## Met le match en pause s'il joue (une seule fois) ; retient qu'il faudra le relancer.
## Instant de la dernière reprise demandée par la fermeture d'une fenêtre (ms).
var _reprise_ms := -100000

func _suspendre() -> void:
	var live := _live()
	if live.is_empty() or live.get("finished", false): return
	var etat := _etat_bandeau()
	# Une petite fenêtre rouverte juste après en avoir fermé une : la reprise demandée à la fermeture est encore en
	# route (bandeau toujours sur « Reprendre ») ; la pause est redemandée dès la réponse du jeu.
	if str(etat.pause) != "PAUSE" and app.waiting and Time.get_ticks_msec() - _reprise_ms < 5000:
		_reprendre_apres = true
		_pause_voulue = 1
		return
	if str(etat.pause) != "PAUSE" or not bool(etat.pause_possible): return
	_reprendre_apres = true
	if app.waiting: _pause_voulue = 1
	else: director.command("pause", {"paused": true})

## Relance le match s'il est en pause (et pas fini).
func _relancer() -> void:
	_reprendre_apres = false
	var live := _live()
	if live.is_empty() or live.get("finished", false) or not director._talk().is_empty(): return
	_reprise_ms = Time.get_ticks_msec()
	if app.waiting: _pause_voulue = -1
	elif live.get("paused", false): director.command("pause", {"paused": false})

# --- Menu du match (Échap) ----------------------------------------------------------

## Menu du match (maquette 13-match-direct-3, exception de Léo à la règle « jamais de petite fenêtre ») :
## voile noir à 70 % sous le bandeau (score et minute lisibles), panneau de 480 px, « Reprendre » en tête.
## `mode` « deleguer » : la confirmation de « Confier la fin à l'adjoint », dans le même panneau.
func ouvrir_menu(mode: String = "menu") -> void:
	if _live().is_empty(): return
	_suspendre()
	_menu_mode = mode
	_menu_quitter_arme = false
	_menu_cle = ""
	if not is_instance_valid(menu): _construire_menu()
	_actualiser_menu()
	# Voile au-dessus de tout (3D, entracte 2D, bannières) ; la rangée du score passe au-dessus de lui :
	# le score et la minute restent lisibles.
	_menu_voile.show()
	menu.show()
	move_child(_menu_voile, get_child_count() - 1)
	move_child(menu, get_child_count() - 1)
	# Seul le bandeau du score passe au-dessus du voile (lisible) ; commandes et plaques restent dessous : rien
	# d'autre n'est cliquable tant que le menu est ouvert.
	_coque_score.z_index = 1
	menu.z_index = 1
	_placer_menu()
	var premier: Control = menu.find_child("MatchMenuReprendre" if mode == "menu" else "MatchMenuConfirmer", true, false)
	if premier != null: premier.call_deferred("grab_focus")
	director._refresh_controls()

func _cacher_menu() -> void:
	if is_instance_valid(menu): menu.hide()
	if is_instance_valid(_menu_voile): _menu_voile.hide()
	if is_instance_valid(_coque_score): _coque_score.z_index = 0

## Ferme le menu ; `reprendre` : le match repart (Reprendre, Échap, Espace).
func fermer_menu(reprendre: bool = true) -> void:
	_cacher_menu()
	if reprendre: _relancer()

func _construire_menu() -> void:
	_menu_voile = ColorRect.new()
	_menu_voile.name = "MatchMenuVeil"
	_menu_voile.color = Color(Charte.NUIT, 0.7)
	_menu_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Un clic sur le voile, hors du panneau, ferme le menu comme Échap (reprise du match ; délégation annulée).
	_menu_voile.gui_input.connect(func(evenement: InputEvent):
		var clic := evenement as InputEventMouseButton
		if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT and menu.visible:
			accept_event()
			fermer_menu(true))
	S.full(_menu_voile)
	add_child(_menu_voile)
	menu = Control.new()
	menu.name = "MatchMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	S.full(menu)
	add_child(menu)
	_menu_panneau = PanelContainer.new()
	_menu_panneau.name = "MatchMenuPanel"
	# Menu pause : la seule fenêtre permise (charte finale §7.1), panneau rayon 18 sur l'écran voilé.
	_menu_panneau.add_theme_stylebox_override("panel", _fond_hud(Vector4(12, 20, 12, 4), Charte.PANNEAU))
	menu.add_child(_menu_panneau)
	var colonne := VBoxContainer.new()
	colonne.name = "MatchMenuColumn"
	colonne.add_theme_constant_override("separation", 0)
	_menu_panneau.add_child(colonne)
	menu.hide()

## Contenu du panneau selon le mode (menu, délégation) et l'état du match ; reconstruit seulement quand
## ce qu'il dit change (le focus clavier est gardé).
func _actualiser_menu() -> void:
	if not is_instance_valid(_menu_panneau): return
	var cle := JSON.stringify([_menu_mode, _menu_quitter_arme, int(_live().get("minute", 0)), _vitesse_libelle(), echelle])
	if cle == _menu_cle: return
	_menu_cle = cle
	var colonne: VBoxContainer = _menu_panneau.get_child(0)
	var focus_avant := ""
	var focalise := get_viewport().gui_get_focus_owner()
	if focalise != null and colonne.is_ancestor_of(focalise): focus_avant = focalise.name
	S.clear(colonne)
	var e := echelle
	var tete := MarginContainer.new()
	for bord in ["left", "right"]: tete.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	tete.add_theme_constant_override("margin_bottom", roundi(14 * e))
	colonne.add_child(tete)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", roundi(4 * e))
	tete.add_child(pile)
	var minute := int(_live().get("minute", 0))
	var titre := _texte("CONFIER LA FIN À L’ADJOINT" if _menu_mode == "deleguer" else "MENU DU MATCH", Charte.TITRE_GRAS, Charte.IVOIRE)
	titre.name = "MatchMenuTitle"
	titre.add_theme_font_size_override("font_size", roundi(24 * e))
	pile.add_child(titre)
	# Plus de phrase : la minute d'arrêt est une pastille, le titre dit déjà ce que fait le menu.
	var arret := _pastille_hud("Pause · %d’" % maxi(1, minute), "MatchMenuMinute")
	pile.add_child(arret)
	colonne.add_child(_filet())
	if _menu_mode == "deleguer":
		colonne.add_child(_option("MatchMenuConfirmer", "Confirmer : l’adjoint finit le match", "", ["Entrée"], func():
			fermer_menu(false)
			director.command("delegate")))
		colonne.add_child(_option("MatchMenuAnnuler", "Annuler et reprendre le match", "", ["Échap"], func(): fermer_menu(true)))
	else:
		colonne.add_child(_option("MatchMenuReprendre", "Reprendre le match", "", ["Échap", "Espace"], func(): fermer_menu(true)))
		colonne.add_child(_option("MatchMenuReglages", "Réglages", "", "›", func(): ouvrir_reglages()))
		colonne.add_child(_option("MatchMenuVitesse", "Vitesse du match", "", {"vitesse": _vitesse_libelle()}, func(): _changer_vitesse(1)))
		var quitter_sous := "Appuie encore pour fermer" if _menu_quitter_arme else "Rejoué depuis le coup d’envoi"
		# Seule option qui ferme le jeu : dit à droite, en mots, ce qu'elle fait (pas la couleur seule).
		colonne.add_child(_option("MatchMenuQuitter", "Quitter le match", quitter_sous, "Ferme le jeu", _quitter))
	var pied := HBoxContainer.new()
	pied.name = "MatchMenuKeys"
	pied.add_theme_constant_override("separation", roundi(18 * e))
	var marge_pied := MarginContainer.new()
	for bord in ["left", "right"]: marge_pied.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	for bord in ["top", "bottom"]: marge_pied.add_theme_constant_override("margin_" + bord, roundi(12 * e))
	marge_pied.add_child(pied)
	colonne.add_child(marge_pied)
	# Raccourcis clavier : derrière un « ? » (les puces de touche des options restent à droite des lignes).
	pied.add_child(_aide_touches("↑ ↓  choisir   ·   Entrée  valider   ·   Échap  " + ("reprendre" if _menu_mode == "menu" else "annuler"), "MatchMenuAide"))
	_menu_panneau.custom_minimum_size.x = roundf(480 * e)
	_menu_panneau.reset_size()
	_placer_menu()
	if not focus_avant.is_empty():
		var retrouve: Control = colonne.find_child(focus_avant, true, false)
		if retrouve != null: retrouve.call_deferred("grab_focus")

## Pastille d'état du menu (texte court, case ronde, jamais une phrase).
func _pastille_hud(texte: String, nom: String) -> PanelContainer:
	var pastille := PanelContainer.new()
	pastille.name = nom
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastille.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pastille.add_theme_stylebox_override("panel", _fond_hud(Vector4(10, 2, 10, 2), Charte.PANNEAU_3, Charte.RAYON_PILULE))
	var mot := _texte(texte, Charte.texte_moyen(), Charte.IVOIRE)
	mot.name = "Mot"
	mot.add_theme_font_size_override("font_size", roundi(13 * echelle))
	pastille.add_child(mot)
	return pastille

## Petit « ? » : les raccourcis clavier s'affichent au survol ou au focus, jamais en ligne.
func _aide_touches(bulle: String, nom: String) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = nom
	cadre.tooltip_text = bulle
	cadre.accessibility_name = bulle
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.mouse_default_cursor_shape = Control.CURSOR_HELP
	cadre.custom_minimum_size = Vector2(roundf(28 * echelle), roundf(28 * echelle))
	cadre.add_theme_stylebox_override("panel", _fond_hud(Vector4.ZERO, Charte.PANNEAU_3, Charte.RAYON_PILULE))
	var signe := _texte("?", Charte.texte_moyen(), Charte.IVOIRE_2)
	signe.add_theme_font_size_override("font_size", maxi(12, roundi(14 * echelle)))
	signe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(signe)
	return cadre

func _filet() -> ColorRect:
	var filet := ColorRect.new()
	filet.color = Charte.FILET
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filet

## Option du menu : ligne de 52 px (1080p), libellé, précision en gris-vert, indication à droite ; survol en
## panneau plus clair (rayon 12), focus en panneau choisi avec l'anneau doré de la charte et le marqueur crème à gauche.
func _option(nom: String, libelle: String, precision: String, droite: Variant, action: Callable) -> Button:
	var e := echelle
	var bouton := Button.new()
	bouton.name = nom
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.pressed.connect(action)
	bouton.set_meta("contextual_enabled", true)
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fond := Color(0, 0, 0, 0)
		if etat in ["hover", "pressed"]: fond = Charte.PANNEAU_2
		if etat == "focus": fond = Charte.PANNEAU_3
		var style := _fond_hud(Vector4.ZERO, fond, Charte.RAYON_CARTE)
		if etat == "focus":
			style.border_color = Charte.OR
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override(etat, style)
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_theme_constant_override("separation", roundi(12 * e))
	S.full(rangee)
	rangee.offset_left = roundf(16 * e)
	rangee.offset_right = -roundf(12 * e)
	bouton.add_child(rangee)
	var marqueur := Marqueur.new()
	marqueur.name = "Marqueur"
	marqueur.custom_minimum_size = Vector2(roundf(6 * e), roundf(26 * e))
	marqueur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marqueur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marqueur.modulate.a = 0.0
	rangee.add_child(marqueur)
	bouton.focus_entered.connect(func(): marqueur.modulate.a = 1.0)
	bouton.focus_exited.connect(func(): marqueur.modulate.a = 0.0)
	var pile := VBoxContainer.new()
	pile.alignment = BoxContainer.ALIGNMENT_CENTER
	pile.add_theme_constant_override("separation", 0)
	pile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(pile)
	rangee.add_child(pile)
	var titre := _texte(libelle, Charte.texte_moyen(), Charte.IVOIRE)
	titre.name = "Libelle"
	titre.add_theme_font_size_override("font_size", roundi(17 * e))
	pile.add_child(titre)
	if not precision.is_empty():
		var sous := _texte(precision, Charte.TEXTE, Charte.IVOIRE_2)
		sous.name = "Precision"
		sous.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sous.add_theme_font_size_override("font_size", roundi(13 * e))
		pile.add_child(sous)
	if droite is Dictionary:
		# Vitesse : ◂ ralentit, ▸ accélère (deux zones distinctes) ; la ligne elle-même avance d'un cran.
		var reglage := HBoxContainer.new()
		reglage.name = "Droite"
		reglage.add_theme_constant_override("separation", roundi(6 * e))
		reglage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for sens: int in [-1, 1]:
			var fleche := Button.new()
			fleche.name = "MatchMenuVitesseMoins" if sens < 0 else "MatchMenuVitessePlus"
			fleche.text = "◂" if sens < 0 else "▸"
			fleche.focus_mode = Control.FOCUS_NONE
			fleche.tooltip_text = "Plus lent" if sens < 0 else "Plus rapide"
			fleche.set_meta("contextual_enabled", true)
			fleche.pressed.connect(_changer_vitesse.bind(sens))
			C.style_bouton_lien(fleche, 16)
			fleche.add_theme_font_override("font", Charte.texte_moyen())
			fleche.add_theme_font_size_override("font_size", roundi(16 * e))
			fleche.custom_minimum_size = Vector2(roundf(28 * e), roundf(32 * e))
			fleche.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if sens > 0:
				var valeur := _texte(str(droite.get("vitesse", "")), Charte.texte_moyen(), Charte.IVOIRE)
				valeur.name = "Valeur"
				valeur.add_theme_font_size_override("font_size", roundi(16 * e))
				reglage.add_child(valeur)
			reglage.add_child(fleche)
		rangee.add_child(reglage)
	elif droite is Array:
		# Touches du raccourci (« Échap », « Espace ») en puces, comme la maquette.
		var touches := HBoxContainer.new()
		touches.name = "Droite"
		touches.mouse_filter = Control.MOUSE_FILTER_IGNORE
		touches.add_theme_constant_override("separation", roundi(6 * e))
		touches.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for nom_touche: Variant in droite:
			var puce := _touche(str(nom_touche))
			(puce.get_child(0) as Label).add_theme_font_size_override("font_size", roundi(13 * e))
			touches.add_child(puce)
		rangee.add_child(touches)
	elif not str(droite).is_empty():
		var texte_droite := str(droite)
		var indication := _texte(texte_droite, Charte.texte_moyen(), Charte.IVOIRE if texte_droite.begins_with("◂") else Charte.IVOIRE_2)
		indication.name = "Droite"
		indication.add_theme_font_size_override("font_size", roundi((16 if texte_droite.begins_with("◂") else 15) * e))
		rangee.add_child(indication)
	bouton.custom_minimum_size.y = maxf(roundf(52 * e), (pile.get_combined_minimum_size().y if not precision.is_empty() else 0.0) + roundf(16 * e))
	return bouton

## Marqueur de l'option choisie (ou liseré du club qui a le ballon) : trait droit de 3 px aux bouts arrondis
## (charte finale §3 : droit partout).
class Marqueur extends Control:
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var l := maxf(2.0, size.x * 0.5)
		draw_style_box(Charte.style_pilule(couleur, Color.TRANSPARENT, 0, 0), Rect2(0, 0, l, size.y))

func _placer_menu() -> void:
	if not is_instance_valid(_menu_panneau): return
	_menu_panneau.reset_size()
	var taille := _menu_panneau.size
	_menu_panneau.position = Vector2(roundf((size.x - taille.x) * 0.5), roundf(maxf(size.y * 0.22, (size.y - taille.y) * 0.4)))

## Vitesse du match : l'horloge de l'entracte en temps forts (posée → éclair), la cadence en repli.
const VITESSES := ["lente", "normale", "rapide", "eclair"]
const VITESSES_LIBELLES := {"lente": "Posée", "normale": "Normale", "rapide": "Rapide", "eclair": "Éclair"}

func _vitesse_libelle() -> String:
	if regie != null: return str(VITESSES_LIBELLES.get(str(regie.horloge), "Normale"))
	return "×%d" % int(app.tick_steps)

func _changer_vitesse(sens: int) -> void:
	if regie != null:
		var i := VITESSES.find(str(regie.horloge))
		var suivante: String = VITESSES[wrapi(i + sens, 0, VITESSES.size())]
		regie.choisir_horloge(suivante)
		if regie.between != null: regie.between.horloge = suivante
	else:
		var pas := [1, 4, 12]
		var j := wrapi(pas.find(int(app.tick_steps)) + sens, 0, pas.size())
		_cadence.select(j)
		_choisir_cadence(j)
	_actualiser_menu()

## « Quitter le match » : un premier appui arme (la ligne dit ce qui va se passer), le second ferme le jeu.
## Pas de reprise en plein match (décision de Léo, 16/11/2026) : la carrière repart avant le match.
func _quitter() -> void:
	if not _menu_quitter_arme:
		_menu_quitter_arme = true
		_actualiser_menu()
		return
	app._close()

## « Confier la fin à l'adjoint » (Plus) : confirmation dans le menu du match, pas dans une fenêtre.
func confier_fin() -> void:
	ouvrir_menu("deleguer")

# --- Petites fenêtres du direct : club, joueur ------------------------------------------------------

## Plein écran obligatoire (règle de Léo du 21/11/2026) : on ne quitte jamais le direct avant la fin. La plaque d'un club
## et le nom d'un de nos joueurs ouvrent une petite fenêtre visuelle par-dessus le match (cadre commun
## fenetre_visuelle.gd : voile, panneau rayon 18, titre, ✕) ; Échap, ✕ et clic à côté la ferment. Comme les anciennes
## pages du direct, le match se met en pause à l'ouverture et repart à la fermeture s'il jouait.
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const FENETRE_CLUB := "MatchFenetreClub"
const FENETRE_JOUEUR := "MatchFenetreJoueur"
## Résultats récents : couleur et lettre (la couleur ne porte jamais seule le résultat).
const FORME_TEINTES := {"V": Charte.GAIN, "N": Charte.IVOIRE_2, "D": Charte.PERTE}

## Une petite fenêtre du direct est-elle ouverte ?
func fenetre_ouverte() -> bool:
	return is_instance_valid(fenetre_hote) and not fenetre_hote.is_queued_for_deletion()

## Plaque du club `cote` (0 : recevant, 1 : visiteur) : sa petite fenêtre.
func ouvrir_fiche_club(cote: int) -> void:
	var teams: Array = _live().get("teams", [])
	if cote < 0 or cote >= teams.size() or not teams[cote] is Dictionary or teams[cote].get("id") == null: return
	ouvrir_fiche_club_id(int(float(teams[cote].id)))

## Petite fenêtre d'un club par son identifiant (plaques, autres matchs et classement en direct de l'entracte) :
## écusson ou logo, rang et points, forme récente en pastilles ; s'il joue ce match, score et chiffres du match en tuiles.
func ouvrir_fiche_club_id(id: int) -> void:
	if id < 0: return
	var teams: Array = _live().get("teams", [])
	var cote := -1
	for i in teams.size():
		if teams[i] is Dictionary and teams[i].get("id") != null and int(float(teams[i].id)) == id: cote = i
	var ligne := _ligne_classement(id)
	var club: Dictionary = _club_complet(teams[cote] if cote >= 0 else ligne if not ligne.is_empty() else {"id": id})
	if cote < 0 and ligne.is_empty() and not club.has("name"): return
	var fond := _ouvrir_fenetre(FENETRE_CLUB, S.G.club_name(club).to_upper(), 960, 490 if cote >= 0 else 300)
	fond.set_meta("club_id", id)
	var ecusson := ecusson_club(club, C.px(150))
	ecusson.name = "MatchFenetreClubEcusson"
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(ecusson)
	D.place(ecusson, Rect2(36, 84, 150, 150))
	var rang := int(ligne.get("rank", club.get("rank", 0)))
	var nous: bool = app.model.get("club") is Dictionary and str(app.model.club.get("id", "")) == str(id)
	Pieces.tuile(fond, Rect2(216, 84, 176, 108), ("1er" if rang == 1 else "%de" % rang) if rang > 0 else "—", "classement", Charte.IVOIRE, "MatchFenetreClubRang", 46, "", "trophy")
	Pieces.tuile(fond, Rect2(406, 84, 176, 108), str(int(ligne.get("points", club.get("points", 0)))), "points", Charte.IVOIRE, "MatchFenetreClubPoints", 46)
	# Forme : les cinq derniers résultats de championnat, le plus récent à droite.
	var forme: Array = ligne.get("form", []) if ligne.get("form") is Array else []
	forme = forme.slice(maxi(0, forme.size() - 5))
	var bloc := D.rect(fond, Rect2(596, 84, 328, 108), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	bloc.name = "MatchFenetreClubForme"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(bloc, 14, 98, "FORME", 14, Charte.IVOIRE_2, 600, 200)
	for i in forme.size():
		var code := str(forme[i])
		var teinte: Color = FORME_TEINTES.get(code, Charte.IVOIRE_2)
		var case := D.rect(bloc, Rect2(14 + i * 62, 14, 52, 52), Color(teinte, .2), Charte.RAYON_PETIT, teinte)
		case.name = "MatchFenetreClubForme%d" % i
		case.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(case, 26, 38, code, 26, teinte, 800, 52, HORIZONTAL_ALIGNMENT_CENTER)
	if forme.is_empty(): D.text(bloc, 14, 52, "—", 30, Charte.IVOIRE_3, 700, 100)
	# Où il joue ce match, et notre club.
	var x := 216.0
	if cote >= 0:
		var lieu := "Domicile" if cote == 0 else "Extérieur"
		x += Pieces.pastille(fond, x, 208, lieu, "home" if cote == 0 else "bus", "MatchFenetreClubLieu") + 10.0
	if nous: Pieces.pastille(fond, x, 208, "Nous", "star", "MatchFenetreClubNous", "", Charte.GAIN)
	if cote < 0: return
	# Le match en cours, jamais en avance sur l'image (le moteur a une minute d'avance en temps forts) : le score du
	# bandeau, la minute de l'horloge, les essais et chiffres du direct borné (tiroir Statistiques).
	var live := _live()
	var marque := score_affiche()
	var pour := marque[cote]
	var contre := marque[1 - cote]
	var minute := clock.text.strip_edges()
	D.text(fond, 36, 300, "MATCH · %s" % (minute if not minute.is_empty() else "%d’" % maxi(1, int(live.get("minute", 0)))), 16, Charte.IVOIRE_2, 700, 400)
	var tuiles: Array = [["%d – %d" % [pour, contre], "score", Charte.GAIN if pour > contre else Charte.PERTE if pour < contre else Charte.IVOIRE, "Score"]]
	tuiles.append([str(_essais_montres(cote)), "essais", Charte.IVOIRE, "Essais"])
	for libelle: Array in [["Possession", "possession"], ["Territoire", "territoire"], ["Pénalités concédées", "pénalités"]]:
		tuiles.append([_chiffre_match(str(libelle[0]), cote), str(libelle[1]), Charte.IVOIRE, str(libelle[0]).get_slice(" ", 0)])
	var largeur := (960.0 - 72.0 - 4 * 12.0) / 5.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		Pieces.tuile(fond, Rect2(36 + i * (largeur + 12.0), 318, largeur, 128), str(t[0]), str(t[1]), t[2], "MatchFenetreClub" + str(t[3]), 50 if i > 0 else 46)

## Score montré par le bandeau (pas celui du moteur, en avance pendant les temps forts) : [recevant, visiteur].
func score_affiche() -> Array[int]:
	var morceaux := score.text.replace("–", "—").split("—")
	if morceaux.size() == 2 and morceaux[0].strip_edges().is_valid_int() and morceaux[1].strip_edges().is_valid_int():
		return [int(morceaux[0].strip_edges()), int(morceaux[1].strip_edges())]
	var marque: Variant = _live().get("score", [0, 0])
	return [int(marque[0]), int(marque[1])] if marque is Array and marque.size() >= 2 else [0, 0]

## Essais du club `cote` déjà montrés : repères du direct dont le score d'après ne dépasse pas celui du bandeau (le
## temps fort en cours n'est pas annoncé), sinon le compte du moteur.
func _essais_montres(cote: int) -> int:
	var live := _live()
	var direct: Variant = live.get("direct")
	if direct is Dictionary and direct.get("reperes") is Array:
		var montre := score_affiche()
		return (direct.reperes as Array).filter(func(r: Variant) -> bool:
			if not (r is Dictionary and str(r.get("kind", "")) == "try" and int(r.get("equipe", -1)) == cote): return false
			var apres: Variant = r.get("score")
			return not (apres is Array and apres.size() > cote and int(apres[cote]) > montre[cote])).size()
	var essais: Variant = live.get("tries")
	return int(essais[cote]) if essais is Array and essais.size() > cote else 0

## Chiffre d'une ligne des statistiques du match (« Possession ») pour le club `cote` ; « — » sans donnée.
func _chiffre_match(libelle: String, cote: int) -> String:
	# Mêmes chiffres que le tiroir Statistiques du direct.
	for ligne: Variant in _stats(_live()):
		if ligne is Dictionary and str(ligne.get("label", "")) == libelle:
			var valeur: Variant = ligne.get("home" if cote == 0 else "away", "—")
			# Compte du moteur (JSON : nombre à virgule) écrit en entier.
			return str(roundi(float(valeur))) if valeur is float or valeur is int else str(valeur)
	return "—"

## Ligne du classement d'un club (rang, points, forme) ; vide s'il n'y figure pas.
func _ligne_classement(id: int) -> Dictionary:
	var classement: Variant = app.model.get("league", [])
	if not classement is Array: return {}
	for ligne: Variant in classement:
		if ligne is Dictionary and ligne.get("id") != null and int(float(ligne.id)) == id: return ligne
	return {}

## Petite fenêtre d'un de nos joueurs : portrait, poste et numéro, note du match, énergie (jauge), niveau, puis ses
## essais, plaquages et mètres du match en tuiles. Rien pour un adversaire (pas de fiche).
func ouvrir_fenetre_joueur(id: String) -> void:
	_mini_fiche().cacher(app)
	var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad")
	if trouve.is_empty(): return
	var joueur: Dictionary = (trouve.joueur as Dictionary).duplicate()
	var live := _live()
	var numero := -1
	var titulaire := false
	for liste: String in ["lineup", "reserves"]:
		var rangs: Array = live.get(liste, []) if live.get(liste) is Array else []
		for n in rangs.size():
			if rangs[n] is Dictionary and str(rangs[n].get("id", "")) == id:
				joueur.merge(rangs[n], true)
				titulaire = liste == "lineup"
				numero = n + 1 if titulaire else n + 16
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons := {}
	var liste_cartons: Array = direct.get("cartons", []) if direct.get("cartons") is Array else []
	for carton: Variant in liste_cartons:
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	var feuille: Dictionary = direct.get("feuille", {}) if direct.get("feuille") is Dictionary else {}
	var d := Tableau.donnees_joueur(joueur, notes, cartons, feuille)
	var fond := _ouvrir_fenetre(FENETRE_JOUEUR, str(joueur.get("name", "")).to_upper(), 900, 420)
	fond.set_meta("player_id", id)
	# Portrait (carte rayon 12, image recadrée).
	var cadre := D.rect(fond, Rect2(36, 84, 190, 236), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreJoueurPortrait"
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image: TextureRect = S.G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(236), joueur)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	cadre.add_child(image)
	D.place(image, Rect2(-23, 0, 236, 264))
	# Poste, numéro, état : pastilles.
	var x := 254.0
	var poste := str(joueur.get("pos", ""))
	if not poste.is_empty(): x += Pieces.pastille(fond, x, 84, poste, "people", "MatchFenetreJoueurPoste") + 10.0
	if numero > 0: x += Pieces.pastille(fond, x, 84, "N° %d" % numero, "", "MatchFenetreJoueurNumero") + 10.0
	if bool(d.get("blesse", false)): Pieces.pastille(fond, x, 84, "Blessé", "warning", "MatchFenetreJoueurEtat", "", Charte.PERTE)
	elif bool(d.get("carton", false)): Pieces.pastille(fond, x, 84, "Carton jaune", "warning", "MatchFenetreJoueurEtat", "", Charte.INTENSIF)
	elif numero > 0: Pieces.pastille(fond, x, 84, "Sur le terrain" if titulaire else "Banc", "check" if titulaire else "", "MatchFenetreJoueurEtat", "", Charte.GAIN if titulaire else Charte.IVOIRE_2)
	# Note du match (barème de l'entracte), énergie, niveau.
	var largeur := (900.0 - 254.0 - 36.0 - 2 * 12.0) / 3.0
	var note_connue := notes.has(id)
	var note := float(d.get("note", 6.5))
	var teinte_note: Color = load("res://ui/contextual/match_between.gd")._teinte_note(note) if note_connue else Charte.IVOIRE_3
	Pieces.tuile(fond, Rect2(254, 136, largeur, 116), ("%.1f" % note).replace(".", ",") if note_connue else "—", "note du match", teinte_note, "MatchFenetreJoueurNote", 50, "", "rating")
	var energie := clampf(float(d.get("energie", 100.0)), 0.0, 100.0)
	var teinte_energie := Charte.CONDITION if energie >= 75.0 else Charte.INTENSIF if energie >= 55.0 else Charte.PERTE
	var tuile_energie := Pieces.tuile(fond, Rect2(254 + largeur + 12.0, 136, largeur, 116), "%d %%" % roundi(energie), "énergie", teinte_energie, "MatchFenetreJoueurEnergie", 50, "", "heart")
	D.bar(tuile_energie, Rect2(12, 12, largeur - 52, 8), energie, teinte_energie)
	var niveau: Variant = joueur.get("rating")
	var niveau_connu := niveau is float or niveau is int
	Pieces.tuile(fond, Rect2(254 + 2 * (largeur + 12.0), 136, largeur, 116), str(roundi(float(niveau))) if niveau_connu else "—", "niveau", Charte.couleur_attribut(niveau) if niveau_connu else Charte.IVOIRE, "MatchFenetreJoueurNiveau", 50)
	# Ses chiffres du match.
	for i in 3:
		var cle: String = ["essais", "plaquages", "metres"][i]
		var valeur := str(int(d.get(cle, 0))) if note_connue or not feuille.is_empty() else "—"
		Pieces.tuile(fond, Rect2(254 + i * (largeur + 12.0), 264, largeur, 100), valeur, ["essais", "plaquages", "mètres"][i], Charte.IVOIRE, "MatchFenetreJoueur" + cle.capitalize(), 42)

## Ouvre le calque d'une petite fenêtre du direct et rend son panneau (unités du gabarit 2248 × 1230, centré).
## Une fenêtre déjà ouverte est remplacée. Le match se met en pause (sauf sous la fenêtre Équipe, qui tient la pause),
## sauf `pause` faux : le match continue derrière (fenêtre d'un joueur, idée 32).
func _ouvrir_fenetre(nom: String, titre: String, largeur: float, hauteur: float, pause: bool = true) -> Panel:
	_mini_fiche().cacher(app)
	if drawer.visible: _fermer_tiroir()
	_retirer_fenetre()
	if pause and not (is_instance_valid(equipe) and equipe.visible): _suspendre()
	var hote := Control.new()
	hote.name = "MatchFenetre"
	hote.mouse_filter = Control.MOUSE_FILTER_STOP
	hote.z_index = 5
	S.full(hote)
	add_child(hote)
	fenetre_hote = hote
	# Voile sur tout l'écran (le cadre commun ne couvre que la toile au gabarit) : clic à côté = fermer.
	var voile := Button.new()
	voile.name = "MatchFenetreACote"
	voile.focus_mode = Control.FOCUS_NONE
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var fond_voile := StyleBoxFlat.new()
		fond_voile.bg_color = Color(Charte.NUIT, .45)
		voile.add_theme_stylebox_override(etat, fond_voile)
	voile.pressed.connect(func(): PetiteFenetre.fermer_derniere(get_tree()))
	S.full(voile)
	hote.add_child(voile)
	var toile := Control.new()
	toile.name = "MatchFenetreToile"
	toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var taille := Vector2(2248, 1230) * C.density
	toile.set_anchors_preset(Control.PRESET_CENTER)
	toile.offset_left = -taille.x / 2.0
	toile.offset_right = taille.x / 2.0
	toile.offset_top = -taille.y / 2.0
	toile.offset_bottom = taille.y / 2.0
	hote.add_child(toile)
	var fond := FenetreVisuelle.ouvrir(toile, nom, titre, "", largeur, hauteur, func(): _apres_fenetre(hote))
	# Le voile du cadre commun reste cliquable (fermer) mais transparent : celui de l'écran le remplace.
	var voile_cadre := toile.find_child(nom + "Voile", true, false) as Button
	if voile_cadre != null:
		for etat: String in ["normal", "hover", "pressed", "focus"]: voile_cadre.add_theme_stylebox_override(etat, StyleBoxEmpty.new())
	director._refresh_controls()
	return fond

## Fenêtre refermée (Échap, ✕, clic à côté) : le match repart s'il jouait.
func _apres_fenetre(hote: Control) -> void:
	if is_instance_valid(hote): hote.queue_free()
	if hote != fenetre_hote: return
	fenetre_hote = null
	if _reprendre_apres and not (is_instance_valid(equipe) and equipe.visible): _relancer()
	director._refresh_controls()

## Retire la fenêtre ouverte sans relancer le match (une autre la remplace).
func _retirer_fenetre() -> void:
	if not is_instance_valid(fenetre_hote): return
	for noeud: Node in fenetre_hote.find_children("*", "", true, false):
		if noeud.is_in_group(PetiteFenetre.GROUPE): noeud.remove_from_group(PetiteFenetre.GROUPE)
	remove_child(fenetre_hote)
	fenetre_hote.queue_free()
	fenetre_hote = null

## Ferme la petite fenêtre ouverte comme Échap (tests, fin de match).
func fermer_fenetre() -> void:
	if not fenetre_ouverte(): return
	for noeud: Node in fenetre_hote.find_children("*", "", true, false):
		if noeud.is_in_group(PetiteFenetre.GROUPE):
			noeud.remove_from_group(PetiteFenetre.GROUPE)
			var fermer: Variant = noeud.get_meta(PetiteFenetre.FERMER, Callable())
			if fermer is Callable and (fermer as Callable).is_valid(): (fermer as Callable).call()
			return

# --- Idée FM27 n° 33 : consignes en petite fenêtre, le match continue derrière ------------------------------------

const ConsignesFenetre = preload("res://ui/contextual/match_consignes_fenetre.gd")
const JoueurFenetre = preload("res://ui/contextual/match_menu_joueur.gd")
## Axe montré et l'envoi de la régie (`set_consignes` : file du prochain arrêt de jeu).
var consignes_axe := ""
var _consignes_envoyer: Callable

## Ouvre la petite fenêtre des consignes (sans pause) ; `envoyer(axe, valeur)` demande un cran, qui part au
## prochain arrêt de jeu. Une veille la redessine quand le moteur change ce qu'elle montre (arrêt de jeu, bilan…).
func ouvrir_fenetre_consignes(envoyer: Callable = Callable()) -> void:
	if envoyer.is_valid(): _consignes_envoyer = envoyer
	var p: Dictionary = Pilotage.pilotage(_live())
	var fond := _ouvrir_fenetre(ConsignesFenetre.NOM, "", ConsignesFenetre.LARGEUR, ConsignesFenetre.HAUTEUR, false)
	# Même cadre que la fenêtre d'un joueur (ardoise claire, idée 32).
	JoueurFenetre.habiller(fond, ConsignesFenetre.NOM)
	var choisir := func(axe: String):
		consignes_axe = axe
		ouvrir_fenetre_consignes()
	var demander := func(axe: String, valeur: String):
		consignes_axe = axe
		if _consignes_envoyer.is_valid(): _consignes_envoyer.call(axe, valeur)
		else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))
		_suivre_consignes()
	var minute := int(_live().get("minute", 0))
	ConsignesFenetre.construire(fond, p, consignes_axe, choisir, demander, minute)
	var veille := Timer.new()
	veille.name = "MatchFenetreConsignesVeille"
	veille.wait_time = 0.4
	veille.autostart = true
	veille.ignore_time_scale = true
	fond.add_child(veille)
	var empreinte := ConsignesFenetre.signature(p, minute)
	veille.timeout.connect(func():
		if bool(app.waiting): return
		if ConsignesFenetre.signature(Pilotage.pilotage(_live()), int(_live().get("minute", 0))) != empreinte: ouvrir_fenetre_consignes())

## Redessine la fenêtre des consignes dès que la réponse du moteur est là.
func _suivre_consignes() -> void:
	var attendre := func(rappel: Callable) -> void:
		if not is_instance_valid(self) or not fenetre_ouverte() or fenetre_hote.find_child(ConsignesFenetre.NOM, true, false) == null: return
		if bool(app.waiting):
			get_tree().process_frame.connect(rappel.bind(rappel), CONNECT_ONE_SHOT)
			return
		ouvrir_fenetre_consignes()
	get_tree().process_frame.connect(attendre.bind(attendre), CONNECT_ONE_SHOT)

# --- Petites fenêtres de l'écran 2D : fait, chiffre, match du multiplex -----------------------------------------

const FENETRE_FAIT := "MatchFenetreFait"
const FENETRE_STAT := "MatchFenetreStat"
## Notre camp (0 : recevant) pour l'évolution d'un chiffre : les parts du moteur sont rangées recevant, visiteur.
var nous_stat := 0
const FENETRE_MATCH := "MatchFenetreMatch"
const TYPES_FAITS := {"try": "Essai", "goal": "Tir au but réussi", "miss": "Tir au but manqué", "penalty": "Pénalité", "drop": "Drop",
	"transformation": "Transformation", "card": "Carton", "scrum": "Mêlée", "lineout": "Touche", "turnover": "Ballon récupéré",
	"hand-fault": "En-avant", "kick": "Jeu au pied", "carry": "Temps de jeu"}

## Petite fenêtre d'un fait du match (essai, pénalité, carton, repère de la frise, dernier fait) : écusson du club,
## type, minute, auteur (sa fenêtre s'il est des nôtres) et score d'après ; « Journal » ouvre le tiroir à ce fait.
func ouvrir_fenetre_fait(i: int) -> void:
	var live := _live()
	var evenements: Array = live.get("events", []) if live.get("events") is Array else []
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var repere: Dictionary = {}
	for r: Variant in direct.get("reperes", []) if direct.get("reperes") is Array else []:
		if r is Dictionary and int(r.get("i", -1)) == i: repere = r
	var evenement: Dictionary = evenements[i] if i >= 0 and i < evenements.size() and evenements[i] is Dictionary else {}
	if repere.is_empty() and evenement.is_empty(): return
	var kind := str(repere.get("kind", evenement.get("kind", "")))
	var rouge := bool(repere.get("rouge", false)) or str(evenement.get("text", "")).to_lower().contains("rouge")
	var type := ("Carton rouge" if rouge else "Carton jaune") if kind == "card" else str(TYPES_FAITS.get(kind, "Fait de jeu"))
	var teams: Array = live.get("teams", [])
	var cote := int(repere.get("equipe", evenement.get("team", evenement.get("equipe", -1))))
	var club: Dictionary = _club_complet(teams[cote]) if cote >= 0 and cote < teams.size() and teams[cote] is Dictionary else {}
	var texte := str(evenement.get("text", ""))
	var fond := _ouvrir_fenetre(FENETRE_FAIT, type.to_upper(), 960, 420 if not texte.is_empty() else 360)
	fond.set_meta("fait", i)
	if not club.is_empty():
		var ecusson := ecusson_club(club, C.px(140))
		ecusson.name = "MatchFenetreFaitEcusson"
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(36, 84, 140, 140))
	var minute := str(repere.get("horloge", evenement.get("clock", "")))
	if minute.is_empty() and evenement.get("minute") != null: minute = "%d′" % int(evenement.minute)
	var largeur := (960.0 - 206.0 - 36.0 - 2 * 12.0) / 3.0
	Pieces.tuile(fond, Rect2(206, 84, largeur, 116), minute if not minute.is_empty() else "—", "minute", Charte.IVOIRE, "MatchFenetreFaitMinute", 50, "", "clock")
	var marque: Variant = repere.get("score") if repere.get("score") is Array else evenement.get("score")
	var score := "%d – %d" % [int(marque[0]), int(marque[1])] if marque is Array and (marque as Array).size() == 2 else "—"
	Pieces.tuile(fond, Rect2(206 + largeur + 12.0, 84, largeur, 116), score, "score après", Charte.IVOIRE, "MatchFenetreFaitScore", 46)
	var couleur_type: Color = Charte.PERTE if rouge else (Charte.INTENSIF if kind == "card" else (Charte.GAIN if kind in ["try", "goal", "transformation", "drop"] else Charte.IVOIRE))
	Pieces.tuile(fond, Rect2(206 + 2 * (largeur + 12.0), 84, largeur, 116), type, "type", couleur_type, "MatchFenetreFaitType", 34)
	# Club et auteur en pastilles ; l'auteur, s'il est des nôtres, ouvre sa petite fenêtre.
	var x := 206.0
	if not club.is_empty(): x += Pieces.pastille(fond, x, 216, S.G.club_name(club), "shield", "MatchFenetreFaitClub", "", Charte.IVOIRE, Charte.PANNEAU_3, func(): ouvrir_fiche_club(cote)) + 10.0
	var qui := str(repere.get("nom", "")).strip_edges()
	var scene: Dictionary = evenement.get("scene", {}) if evenement.get("scene") is Dictionary else {}
	var acteur := str(scene.get("actor", "")) if scene.get("actor") != null else ""
	if qui.is_empty() and not acteur.is_empty():
		for liste: String in ["lineup", "reserves"]:
			for j: Variant in live.get(liste, []) if live.get(liste) is Array else []:
				if j is Dictionary and str(j.get("id", "")) == acteur: qui = str(j.get("name", ""))
	var des_notres: bool = not acteur.is_empty() and not load("res://ui/immersive08/fiche_commune.gd").trouver(app, acteur, "squad").is_empty()
	if not qui.is_empty(): x += Pieces.pastille(fond, x, 216, qui, "people", "MatchFenetreFaitAuteur", "", Charte.IVOIRE, Charte.PANNEAU_3, (func(): ouvrir_fenetre_joueur(acteur)) if des_notres else Callable()) + 10.0
	Pieces.pastille(fond, x, 216, "Journal", "search", "MatchFenetreFaitJournal", "", Charte.IVOIRE, Charte.PANNEAU_3, func():
		fermer_fenetre()
		if regie != null and regie.has_method("ouvrir_journal_a"): regie.ouvrir_journal_a(i))
	if not texte.is_empty():
		var ligne := D.text(fond, 206, 300, texte, 20, Charte.IVOIRE_2, 500, 960 - 206 - 36, HORIZONTAL_ALIGNMENT_LEFT, true)
		ligne.name = "MatchFenetreFaitTexte"
		ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.size.y = 90
		ligne.custom_minimum_size.y = 0

## Petite fenêtre d'un chiffre du match (ligne des chiffres en miroir) : les deux clubs, écusson, nom et valeur en
## grandes tuiles à leurs couleurs, la barre des parts, puis l'évolution par tranche de 10 minutes (`direct.periodes`
## du moteur) ; « Statistiques » ouvre le tiroir à cette ligne.
func ouvrir_fenetre_stat(rang: Dictionary) -> void:
	var live := _live()
	var teams: Array = live.get("teams", [])
	if teams.size() < 2: return
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var camp := int(direct.get("camp", 0))
	var nous := camp if camp in [0, 1] else 0
	var cle := str(rang.get("cle", ""))
	var titre := str(rang.get("label", "")).get_slice(" (", 0)
	var tranches := tranches_stat(direct, cle)
	var L := 1480.0 if not tranches.is_empty() else 960.0
	var h_zone := 370.0 if cle in STATS_PARTS else 340.0
	var fond := _ouvrir_fenetre(FENETRE_STAT, titre.to_upper(), L, 352.0 + h_zone + 78.0 if not tranches.is_empty() else 400.0)
	fond.set_meta("stat", cle)
	var valeurs: Array = rang.get("valeurs", [0, 0]) if rang.get("valeurs") is Array else [0, 0]
	var vide := bool(rang.get("vide", false))
	var inverse := bool(rang.get("inverse", false)) or cle == "penalites"
	var pourcent := str(rang.get("unite", "")) == "%"
	var largeur := (L - 72.0 - 24.0) / 2.0
	var teintes := teintes_stat(teams, nous)
	for k in 2:
		var cote := nous if k == 0 else 1 - nous
		var club: Dictionary = _club_complet(teams[cote]) if teams[cote] is Dictionary else {}
		var x := 36.0 + k * (largeur + 24.0)
		var ecusson := ecusson_club(club, C.px(70))
		ecusson.name = "MatchFenetreStatEcusson%d" % k
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(x, 84, 70, 70))
		var nom := D.text(fond, x + 86, 128, S.G.club_name(club).to_upper(), 24, Charte.IVOIRE, 800, largeur - 86)
		nom.name = "MatchFenetreStatNom%d" % k
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		var a := float(valeurs[cote])
		var b := float(valeurs[1 - cote])
		var mieux: bool = not vide and (a < b if inverse else a > b)
		var valeur := "—" if vide else (("%d / %d" % [int(a), int((rang.sur as Array)[cote])]) if rang.get("sur") is Array else ("%d %%" % int(a) if pourcent else str(int(a))))
		Pieces.tuile(fond, Rect2(x, 170, largeur, 130), valeur, "en tête" if mieux else ("à égalité" if a == b and not vide else "derrière"), teintes[k] if mieux else Charte.IVOIRE, "MatchFenetreStatValeur%d" % k, 64, "", "star" if mieux else "", mieux)
	if not vide and float(valeurs[0]) + float(valeurs[1]) > 0.0:
		var part := float(valeurs[nous]) / (float(valeurs[0]) + float(valeurs[1]))
		var rail := D.rect(fond, Rect2(36, 318, L - 72, 14), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		rail.name = "MatchFenetreStatBarre"
		var plein := D.rect(rail, Rect2(0, 0, maxf(14.0, (L - 72) * part), 14), teintes[0], Charte.RAYON_PILULE)
		plein.name = "MatchFenetreStatPart"
	var y_bas := 346.0
	if not tranches.is_empty():
		var zone := Rect2(36, 352, L - 72, h_zone)
		# Choix de Léo (22/11/2026) : taux de réussite en barres par tranche, comptes en courbes cumulées, parts entre
		# les deux clubs : possession en courbe du match, occupation en frise.
		var taux := (pourcent or rang.get("sur") is Array) and not cle in STATS_PARTS
		var nos_valeurs: Array = []
		for t: Dictionary in tranches:
			var v: Variant = (t.valeurs as Dictionary).get(cle)
			var part: Variant = (t.get("parts", {}) as Dictionary).get(cle) if t.get("parts") is Dictionary else null
			if taux and part is Array and (part as Array).size() == 2:
				var ratio := func(c: int) -> Variant: return roundi(100.0 * float(part[c][0]) / float(part[c][1])) if float(part[c][1]) > 0.0 else null
				var r0: Variant = ratio.call(nous)
				var r1: Variant = ratio.call(1 - nous)
				nos_valeurs.append([r0, r1] if r0 != null or r1 != null else null)
			else:
				nos_valeurs.append([v[nous], v[1 - nous]] if v is Array and (v as Array).size() == 2 and v[0] != null and v[1] != null else null)
		nous_stat = nous
		if cle in STATS_PARTS:
			var sigles: Array = []
			for k in 2:
				var c: Dictionary = _club_complet(teams[nous if k == 0 else 1 - nous]) if teams[nous if k == 0 else 1 - nous] is Dictionary else {}
				sigles.append(str(c.get("abbr", "")))
			var globale: Array = [null, null] if vide else [float(valeurs[nous]), float(valeurs[1 - nous])]
			var minutes: Variant = ((direct.get("periodes", {}) as Dictionary).get("minutes", {}) as Dictionary).get(cle) if direct.get("periodes") is Dictionary and direct.periodes.get("minutes") is Dictionary else null
			# Choix de Léo (22/11/2026) : possession en courbe minute par minute, occupation en frise des tranches.
			if cle == "possession" and minutes is Array: _courbe_parts(fond, zone, minutes, teintes, sigles, globale, nous)
			else: _frise_parts(fond, zone, tranches, nos_valeurs, teintes, sigles, globale)
		elif taux: _barres_periodes(fond, zone, tranches, nos_valeurs, teintes, true)
		else: _courbe_periodes(fond, zone, tranches, nos_valeurs, teintes, false)
		y_bas = 352.0 + h_zone + 16.0
	Pieces.pastille(fond, 36, y_bas, "Statistiques", "rating", "MatchFenetreStatTiroir", "", Charte.IVOIRE, Charte.PANNEAU_3, func():
		fermer_fenetre()
		if regie != null and regie.has_method("ouvrir_stats_a"): regie.ouvrir_stats_a(str(rang.get("stats", rang.get("label", "")))))

## Tranches de 10 minutes du direct (`direct.periodes`, moteur) qui portent le chiffre `cle` ; vide sans donnée
## (début de match, chiffre sans évolution) : la fenêtre reste sans évolution.
static func tranches_stat(direct: Dictionary, cle: String) -> Array:
	var periodes: Variant = direct.get("periodes")
	if not periodes is Dictionary or not (periodes as Dictionary).get("tranches") is Array: return []
	return (periodes.tranches as Array).filter(func(t: Variant) -> bool: return t is Dictionary and t.get("valeurs") is Dictionary and (t.valeurs as Dictionary).has(cle))

## Couleurs des deux clubs dans la fenêtre d'un chiffre (nous, eux) ; si elles se confondent, l'adversaire passe en ivoire.
func teintes_stat(teams: Array, nous: int) -> Array[Color]:
	var a := Charte.club_trait(_couleur_club(_club_complet(teams[nous]) if teams[nous] is Dictionary else {}, 0))
	var b := Charte.club_trait(_couleur_club(_club_complet(teams[1 - nous]) if teams[1 - nous] is Dictionary else {}, 1))
	var ecart := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
	return [a, b if ecart > 0.25 else Charte.IVOIRE_2]

## Taux de réussite : barres en miroir par tranche de 10 minutes (nous au-dessus de l'axe, eux en dessous), séparation de la
## mi-temps ; tranche en cours atténuée, tranches à venir en cases vides.
func _barres_periodes(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], pourcent: bool) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var n := 8
	var gauche := 20.0
	var pas := (zone.size.x - 2.0 * gauche) / n
	var axe := zone.size.y / 2.0 + 8.0
	var haut := axe - 84.0
	var maxi := 1.0
	for v: Variant in valeurs:
		if v is Array:
			for c: Variant in v:
				if c != null: maxi = maxf(maxi, float(c))
	if pourcent: maxi = 100.0
	D.rect(cadre, Rect2(gauche, axe - 1, zone.size.x - 2.0 * gauche, 2), Charte.PANNEAU_3)
	D.rect(cadre, Rect2(gauche + 4 * pas - 1, 40, 2, zone.size.y - 52), Color(Charte.IVOIRE_3, .5)).name = "MatchFenetreStatMiTemps"
	D.text(cadre, gauche + 2 * pas, 30, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 2 * pas, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT1"
	D.text(cadre, gauche + 6 * pas, 30, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 2 * pas, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT2"
	for k in n:
		var x := gauche + k * pas + pas * 0.2
		var l := pas * 0.6
		# Minute de fin de la tranche, sur l'axe entre les deux barres.
		var etiquette := D.text(cadre, gauche + k * pas + pas / 2.0, axe + 6, "%d′" % ((k + 1) * 10), 15, Charte.IVOIRE_3, 700, pas, HORIZONTAL_ALIGNMENT_CENTER)
		etiquette.name = "MatchFenetreStatMinute%d" % k
		if k >= valeurs.size():
			D.rect(cadre, Rect2(x, axe - 40, l, 28), Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.PANNEAU_3).name = "MatchFenetreStatAVenir%d" % k
			D.rect(cadre, Rect2(x, axe + 12, l, 28), Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.PANNEAU_3)
			continue
		var v: Variant = valeurs[k]
		var en_cours := bool((tranches[k] as Dictionary).get("enCours", false))
		for s in 2:
			# Taux sans tentative dans la tranche (un seul club a lancé) : « — » de ce côté seulement.
			var connu: bool = v is Array and v[s] != null
			var nombre := float(v[s]) if connu else 0.0
			var h := maxf(4.0, haut * nombre / maxi) if connu else 0.0
			if connu:
				var barre := D.rect(cadre, Rect2(x, axe - 12 - h if s == 0 else axe + 12, l, h), Color(teintes[s], .5 if en_cours else 1.0), Charte.RAYON_PETIT)
				barre.name = "MatchFenetreStatBarre%d_%d" % [k, s]
			var texte := ("%d%%" % int(nombre) if pourcent else str(int(nombre))) if connu else "—"
			var y := (axe - 12 - h - 8) if s == 0 else (axe + 12 + h + 24)
			D.text(cadre, x + l / 2.0, y, texte, 20, Charte.IVOIRE if connu else Charte.IVOIRE_3, 700, l + 30, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatChiffre%d_%d" % [k, s]

## Comptes : courbes cumulées des deux clubs sur 80 minutes (compte, ou part refaite depuis le coup d'envoi), un point
## à chaque fin de tranche (la tranche en cours à la minute montrée), le chiffre au bout de chaque courbe.
func _courbe_periodes(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], pourcent: bool) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var gauche := 70.0
	var droite := 100.0
	var haut := 56.0
	var bas := zone.size.y - 46.0
	var w := zone.size.x - gauche - droite
	var series: Array = [[], []]
	var cumul := [0.0, 0.0]
	var num := [0.0, 0.0]
	var den := [0.0, 0.0]
	var cle := str(fond.get_meta("stat", ""))
	for k in valeurs.size():
		var v: Variant = valeurs[k]
		var t: Dictionary = tranches[k]
		var fin := float(t.get("fin", t.get("a", (k + 1) * 10)))
		var part: Variant = (t.get("parts", {}) as Dictionary).get(cle) if t.get("parts") is Dictionary else null
		for s in 2:
			var cote := s if nous_stat == 0 else 1 - s
			if pourcent and part is Array and (part as Array).size() == 2:
				num[s] += float(part[cote][0])
				den[s] += float(part[cote][1])
				if den[s] <= 0.0: continue
				cumul[s] = 100.0 * num[s] / den[s]
			elif pourcent:
				if not v is Array: continue
				cumul[s] = float(v[s])
			else:
				if not v is Array: continue
				cumul[s] += float(v[s])
			series[s].append(Vector2(fin, cumul[s]))
	# Échelle : de 0 au plus haut pour un compte ; pour une part, la plage utile arrondie à la dizaine.
	var bas_valeur := 0.0
	var maxi := maxf(1.0, maxf(cumul[0], cumul[1]))
	if pourcent:
		var mini := 100.0
		maxi = 0.0
		for serie: Array in series:
			for m: Vector2 in serie:
				mini = minf(mini, m.y)
				maxi = maxf(maxi, m.y)
		bas_valeur = clampf(floorf((mini - 5.0) / 10.0) * 10.0, 0.0, 90.0)
		maxi = clampf(ceilf((maxi + 5.0) / 10.0) * 10.0, bas_valeur + 10.0, 100.0)
	var point := func(m: Vector2) -> Vector2: return Vector2(gauche + w * clampf(m.x, 0.0, 80.0) / 80.0, bas - (bas - haut) * (m.y - bas_valeur) / maxf(1.0, maxi - bas_valeur))
	if pourcent:
		D.text(cadre, gauche - 8, haut + 6, "%d%%" % int(maxi), 14, Charte.IVOIRE_3, 600, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(cadre, gauche - 8, bas + 6, "%d%%" % int(bas_valeur), 14, Charte.IVOIRE_3, 600, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	D.rect(cadre, Rect2(gauche, bas, w, 2), Charte.PANNEAU_3)
	if pourcent and bas_valeur < 50.0 and maxi > 50.0: D.rect(cadre, Rect2(gauche, (point.call(Vector2(0, 50)) as Vector2).y, w, 1), Color(Charte.IVOIRE_3, .35))
	for k in 9:
		var x := gauche + w * k / 8.0
		if k == 4: D.rect(cadre, Rect2(x - 1, 40, 2, bas - 40), Color(Charte.IVOIRE_3, .5)).name = "MatchFenetreStatMiTemps"
		elif k > 0: D.rect(cadre, Rect2(x, haut, 1, bas - haut), Color(Charte.PANNEAU_3, .8))
		if k > 0: D.text(cadre, x, bas + 30, "%d′" % (k * 10), 15, Charte.IVOIRE_3, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 0.25, 30, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 220, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT1"
	D.text(cadre, gauche + w * 0.75, 30, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 220, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMT2"
	var fins: Array = []
	for s in 2:
		var pts: Array = series[s]
		if pts.is_empty(): continue
		var ligne := Line2D.new()
		ligne.name = "MatchFenetreStatCourbe%d" % s
		ligne.width = 5.0 * C.density
		ligne.default_color = teintes[s]
		ligne.antialiased = true
		ligne.joint_mode = Line2D.LINE_JOINT_ROUND
		ligne.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ligne.end_cap_mode = Line2D.LINE_CAP_ROUND
		var depart := Vector2(0.0, (pts[0] as Vector2).y if pourcent else 0.0)
		for m: Vector2 in ([] if pourcent else [depart]) + pts: ligne.add_point((point.call(m) as Vector2) * C.density)
		cadre.add_child(ligne)
		for m: Vector2 in pts:
			var p: Vector2 = point.call(m)
			D.rect(cadre, Rect2(p.x - 7, p.y - 7, 14, 14), teintes[s], 7)
		fins.append([s, point.call(pts[-1]), (pts[-1] as Vector2).y])
	# Chiffre au bout de chaque courbe, écartés s'ils se chevauchent.
	if fins.size() == 2 and absf((fins[0][1] as Vector2).y - (fins[1][1] as Vector2).y) < 28.0:
		var dessus := 0 if (fins[0][1] as Vector2).y <= (fins[1][1] as Vector2).y else 1
		fins[dessus][1] = (fins[dessus][1] as Vector2) + Vector2(0, -14)
		fins[1 - dessus][1] = (fins[1 - dessus][1] as Vector2) + Vector2(0, 14)
	for f: Array in fins:
		var p: Vector2 = f[1]
		var valeur := float(f[2])
		D.text(cadre, p.x + 14, p.y + 9, ("%d%%" % roundi(valeur)) if pourcent else str(roundi(valeur)), 24, teintes[int(f[0])], 800, 84).name = "MatchFenetreStatFin%d" % int(f[0])

## Parts entre les deux clubs (somme 100 %) : possession en courbe du match, occupation en frise (choix de Léo, 22/11/2026).
const STATS_PARTS := ["possession", "occupation"]

## Parts : pastilles de légende (couleur et sigle des deux clubs), notre club toujours en premier.
func _legende_parts(cadre: Control, x: float, y: float, teintes: Array[Color], sigles: Array) -> void:
	for s in 2:
		var case := D.rect(cadre, Rect2(x, y - 16, 22, 22), teintes[s], Charte.RAYON_PETIT)
		case.name = "MatchFenetreStatLegende%d" % s
		D.text(cadre, x + 32, y + 2, str(sigles[s]), 20, Charte.IVOIRE, 800, 120)
		x += 150.0

## Frise du temps (occupation) : une frise 0'→80' de 8 cases jointives libellées « 0–10' »… ; chaque case partagée
## entre les deux clubs (nous en haut, eux en bas, à leur couleur), notre part seule en chiffre ; mi-temps marquée.
func _frise_parts(fond: Control, zone: Rect2, tranches: Array, valeurs: Array, teintes: Array[Color], sigles: Array, globale: Array) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	var gauche := 30.0
	var largeur := zone.size.x - 2.0 * gauche
	var coupure := 18.0
	var case := (largeur - coupure) / 8.0
	var haut := 116.0
	var hauteur := 190.0
	_legende_parts(cadre, gauche, 48, teintes, sigles)
	var total := ("%s  %d %%" % [str(sigles[0]), roundi(float(globale[0]))]) if globale.size() == 2 and globale[0] != null else ""
	D.text(cadre, zone.size.x - gauche, 54, total, 30, teintes[0], 800, 400, HORIZONTAL_ALIGNMENT_RIGHT).name = "MatchFenetreStatCentre"
	D.text(cadre, gauche + 2 * case, haut - 16, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 4 * case, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + coupure + 6 * case, haut - 16, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 4 * case, HORIZONTAL_ALIGNMENT_CENTER)
	for k in 8:
		var x := gauche + k * case + (coupure if k >= 4 else 0.0)
		D.text(cadre, x + case / 2.0, haut + hauteur + 30, "%d–%d′" % [k * 10, (k + 1) * 10], 18, Charte.IVOIRE_2, 700, case, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatTranche%d" % k
		var v: Variant = valeurs[k] if k < valeurs.size() else null
		if not v is Array:
			var vide := D.rect(cadre, Rect2(x, haut, case, hauteur), Color(Charte.PANNEAU_3, 0.35), 0)
			vide.name = "MatchFenetreStatAVenir%d" % k
			if k < valeurs.size(): D.text(cadre, x + case / 2.0, haut + hauteur / 2.0 + 10, "—", 26, Charte.IVOIRE_3, 700, case, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var en_cours := bool((tranches[k] as Dictionary).get("enCours", false))
		var h := hauteur * clampf(float(v[0]) / 100.0, 0.0, 1.0)
		var nous := D.rect(cadre, Rect2(x, haut, case, h), Color(teintes[0], .55 if en_cours else 1.0), 0)
		nous.name = "MatchFenetreStatPart%d_0" % k
		var eux := D.rect(cadre, Rect2(x, haut + h, case, hauteur - h), Color(teintes[1], .35 if en_cours else .55), 0)
		eux.name = "MatchFenetreStatPart%d_1" % k
		var encre: Color = Charte.ENCRE if teintes[0].get_luminance() > 0.55 and not en_cours else Charte.IVOIRE
		var y_chiffre := haut + h / 2.0 + 14.0 if h >= 50.0 else haut + h + 34.0
		D.text(cadre, x + case / 2.0, y_chiffre, "%d %%" % roundi(float(v[0])), 30, encre if h >= 50.0 else Charte.IVOIRE, 800, case, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatChiffre%d" % k
	# Séparations fines entre les cases (frise jointive) et ligne des 50 %.
	for k in range(1, 8):
		if k == 4: continue
		var x := gauche + k * case + (coupure if k > 4 else 0.0)
		D.rect(cadre, Rect2(x - 1, haut, 2, hauteur), Color(Charte.PANNEAU_2, 0.9))
	D.rect(cadre, Rect2(gauche, haut + hauteur / 2.0, largeur, 1), Color(Charte.NOIR_PANNEAU, 0.45)).name = "MatchFenetreStat50"

## Courbe du match (possession, idée de Léo, 22/11/2026) : part minute par minute, lissée sur 5 minutes, de part et
## d'autre de la ligne des 50 % : au-dessus quand nous avons le ballon (zone à notre couleur), en dessous pour l'adversaire.
## Axe 0′→80′, mi-temps marquée, minute actuelle repérée, futur vide ; survol : « 34′ · 62 % / 38 % ».
func _courbe_parts(fond: Control, zone: Rect2, minutes: Array, teintes: Array[Color], sigles: Array, globale: Array, nous: int) -> void:
	var cadre := D.rect(fond, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreStatPeriodes"
	_legende_parts(cadre, 30, 48, teintes, sigles)
	var total := ("%s  %d %%" % [str(sigles[0]), roundi(float(globale[0]))]) if globale.size() == 2 and globale[0] != null else ""
	D.text(cadre, zone.size.x - 30, 54, total, 30, teintes[0], 800, 400, HORIZONTAL_ALIGNMENT_RIGHT).name = "MatchFenetreStatCentre"
	var gauche := 90.0
	var droite := 30.0
	var haut := 84.0
	var bas := zone.size.y - 50.0
	var courbe := CourbeParts.new()
	courbe.name = "MatchFenetreStatCourbe"
	courbe.mouse_filter = Control.MOUSE_FILTER_PASS
	courbe.tooltip_text = " "
	courbe.teintes = teintes
	for m: Variant in minutes:
		courbe.comptes.append([float(m[nous]), float(m[1 - nous])] if m is Array and (m as Array).size() == 2 else [0.0, 0.0])
	courbe.duree = maxf(80.0, float(minutes.size() - 1))
	cadre.add_child(courbe)
	D.place(courbe, Rect2(gauche, haut, zone.size.x - gauche - droite, bas - haut))
	var w := zone.size.x - gauche - droite
	for k in 9:
		var x := gauche + w * k * 10.0 / courbe.duree
		D.text(cadre, x, bas + 30, "%d′" % (k * 10), 16 if k != 4 else 18, Charte.IVOIRE_3 if k != 4 else Charte.IVOIRE, 700, 70, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 20.0 / courbe.duree, haut - 10, "1re MI-TEMPS", 15, Charte.IVOIRE_3, 700, 300, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(cadre, gauche + w * 60.0 / courbe.duree, haut - 10, "2e MI-TEMPS", 15, Charte.IVOIRE_3, 700, 300, HORIZONTAL_ALIGNMENT_CENTER)
	# Minute actuelle repérée au-dessus de la courbe.
	if minutes.size() > 0:
		D.text(cadre, gauche + w * float(minutes.size() - 1) / courbe.duree, haut - 34, "%d′" % (minutes.size() - 1), 18, Charte.IVOIRE, 800, 70, HORIZONTAL_ALIGNMENT_CENTER).name = "MatchFenetreStatMaintenant"
	# Qui est où : notre sigle au-dessus de la ligne des 50 %, l'adversaire en dessous.
	var milieu := haut + (bas - haut) / 2.0
	D.text(cadre, 24, milieu - 24, "▲ " + str(sigles[0]), 18, teintes[0], 800, 80).name = "MatchFenetreStatNous"
	D.text(cadre, 24, milieu + 40, "▼ " + str(sigles[1]), 18, teintes[1], 800, 80).name = "MatchFenetreStatEux"

## Courbe de part minute par minute : `comptes[m]` = faits [nous, eux] de la minute m ; part lissée sur ±2 minutes.
class CourbeParts extends Control:
	const LISSAGE := 2
	var comptes: Array = []
	var teintes: Array[Color] = [Charte.IVOIRE, Charte.IVOIRE_2]
	var duree := 80.0
	func part(m: int) -> float:
		var a := 0.0
		var b := 0.0
		for j in range(maxi(0, m - LISSAGE), mini(comptes.size() - 1, m + LISSAGE) + 1):
			a += float(comptes[j][0])
			b += float(comptes[j][1])
		return a / (a + b) if a + b > 0.0 else 0.5
	func _x(m: float) -> float: return size.x * m / duree
	func _y(p: float) -> float: return size.y * (1.0 - p)
	func _get_tooltip(at_position: Vector2) -> String:
		var m := roundi(at_position.x / size.x * duree)
		if m < 0 or m >= comptes.size(): return ""
		var p := part(m)
		return "%d′ · %d %% / %d %%" % [m, roundi(p * 100.0), 100 - roundi(p * 100.0)]
	func _draw() -> void:
		var milieu := size.y / 2.0
		# Repères : minutes de 10 en 10, mi-temps, ligne des 50 %.
		for k in range(1, int(duree / 10.0) + 1):
			draw_line(Vector2(_x(k * 10.0), 0), Vector2(_x(k * 10.0), size.y), Color(Charte.PANNEAU_3, 0.8 if k != 4 else 0.0), 1.0)
		draw_line(Vector2(_x(40.0), -14), Vector2(_x(40.0), size.y), Color(Charte.IVOIRE_3, 0.6), 2.0)
		if comptes.size() >= 2:
			var points: Array[Vector2] = []
			for m in comptes.size(): points.append(Vector2(_x(m), _y(part(m))))
			# Zones : au-dessus de la médiane à notre couleur, en dessous à la sienne (coupées au croisement).
			for i in points.size() - 1:
				var p0 := points[i]
				var p1 := points[i + 1]
				var d0 := p0.y - milieu
				var d1 := p1.y - milieu
				if d0 * d1 < 0.0:
					var t := d0 / (d0 - d1)
					var c := Vector2(lerpf(p0.x, p1.x, t), milieu)
					_zone(p0, c, d0)
					_zone(c, p1, d1)
				else: _zone(p0, p1, d0 if absf(d0) > 0.0 else d1)
			draw_polyline(PackedVector2Array(points), Charte.IVOIRE, maxf(2.0, size.y * 0.008), true)
			# Minute actuelle.
			var maintenant := points[-1].x
			draw_line(Vector2(maintenant, -6), Vector2(maintenant, size.y + 6), Charte.IVOIRE, 2.0)
			draw_circle(points[-1], maxf(4.0, size.y * 0.02), Charte.IVOIRE)
		draw_line(Vector2(0, milieu), Vector2(size.x, milieu), Color(Charte.IVOIRE_2, 0.7), 2.0)
	func _zone(a: Vector2, b: Vector2, signe: float) -> void:
		var milieu := size.y / 2.0
		if absf(b.x - a.x) < 0.5 or (absf(a.y - milieu) < 0.5 and absf(b.y - milieu) < 0.5): return
		var couleur: Color = Color(teintes[0], 0.85) if signe < 0.0 else Color(teintes[1], 0.6)
		draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, milieu), Vector2(a.x, milieu)]), couleur)

## Couleur d'un club (identité), sinon vert pour nous / ivoire pour l'adversaire.
func _couleur_club(club: Dictionary, k: int) -> Color:
	var c := str(S.G.identity(club).get("color", club.get("color", "")))
	return Color(c) if c.begins_with("#") else (Charte.GAIN if k == 0 else Charte.IVOIRE_2)

## Petite fenêtre d'un autre match de la journée (carte du multiplex) : les deux clubs (écusson et nom, leur fenêtre au
## clic), le score en grandes tuiles, les essais, la minute ou « Terminé ».
func ouvrir_fenetre_match(rencontre: Dictionary) -> void:
	var cotes: Array = [rencontre.get("home", {}), rencontre.get("away", {})]
	if not cotes[0] is Dictionary or not cotes[1] is Dictionary: return
	var fini := bool(rencontre.get("fini", false))
	var fond := _ouvrir_fenetre(FENETRE_MATCH, "%s – %s" % [str(cotes[0].get("abbr", "")), str(cotes[1].get("abbr", ""))], 960, 420)
	fond.set_meta("match_id", str(rencontre.get("id", "")))
	var largeur := (960.0 - 72.0 - 24.0) / 2.0
	for k in 2:
		var c: Dictionary = cotes[k]
		var club: Dictionary = _club_complet({"id": c.get("id"), "name": c.get("nom", ""), "abbr": c.get("abbr", "")}) if c.get("id") != null else c
		var x := 36.0 + k * (largeur + 24.0)
		var ecusson := ecusson_club(club, C.px(80))
		ecusson.name = "MatchFenetreMatchEcusson%d" % k
		ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ecusson)
		D.place(ecusson, Rect2(x, 84, 80, 80))
		var nom_club := str(c.get("nom", S.G.club_name(club)))
		var nom := D.text(fond, x + 96, 134, nom_club.to_upper(), 26, Charte.IVOIRE, 800, largeur - 96)
		nom.name = "MatchFenetreMatchNom%d" % k
		nom.add_theme_font_override("font", Charte.TITRE_FICHE)
		var pour := int(c.get("score", 0))
		var contre := int(cotes[1 - k].get("score", 0))
		var id_club := int(float(c.get("id"))) if c.get("id") != null else -1
		Pieces.tuile(fond, Rect2(x, 180, largeur * 0.6 - 6, 130), str(pour), "points", Charte.GAIN if pour > contre else (Charte.PERTE if pour < contre else Charte.IVOIRE), "MatchFenetreMatchScore%d" % k, 70, "", "", false, (func(): ouvrir_fiche_club_id(id_club)) if id_club >= 0 else Callable())
		Pieces.tuile(fond, Rect2(x + largeur * 0.6 + 6, 180, largeur * 0.4 - 6, 130), str(int(c.get("essais", 0))), "essais", Charte.IVOIRE, "MatchFenetreMatchEssais%d" % k, 54)
	Pieces.pastille(fond, 36, 330, "Terminé" if fini else "%d′" % int(rencontre.get("minute", 0)), "check" if fini else "clock", "MatchFenetreMatchMinute", "", Charte.IVOIRE_2 if fini else Charte.GAIN)

# --- Pages du direct : relecture, réglages -----------------------------------------------------

## « Relire » (et « → » d'un fait) dans le tiroir Journal : la relecture des faits filtrés dans une page du direct,
## match en pause, « ← Retour au direct » (jamais une fenêtre pendant le match).
func ouvrir_relecture(evenements: Array, equipes: Array, depart: int = -1) -> void:
	if evenements.is_empty(): return
	_suspendre()
	_relecture = [evenements, equipes, depart]
	_ouvrir_page("relecture")

## Réglages (son, image, commandes) depuis le menu du match : l'écran Réglages de la coque, monté dans une
## page du direct ; « Retour au menu du match ».
func ouvrir_reglages() -> void:
	_cacher_menu()
	_ouvrir_page("reglages")

func _ouvrir_page(sorte: String) -> void:
	_mini_fiche().cacher(app)
	if drawer.visible: _fermer_tiroir()
	_page_sorte = sorte
	_page_cle = ""
	if not is_instance_valid(page):
		page = Control.new()
		page.name = "MatchPage"
		page.mouse_filter = Control.MOUSE_FILTER_STOP
		S.full(page)
		add_child(page)
	page.show()
	move_child(page, get_child_count() - 1)
	_actualiser_page()
	director._refresh_controls()

## Actions qui restent sur place dans une fiche ouverte pendant un match (onglets, tri, suivi du club) ; tout le reste
## mène à un autre écran ou ouvre une fenêtre : grisé, « Disponible après le match » (vestiaire, locker_view.gd).
const ACTIONS_SUR_PLACE := ["ClubSheetTab", "ClubSheetFollow", "ClubSheetSort_", "ClubSheetRetry", "FullPlayerTab"]

static func neutraliser(racine: Node) -> Array[String]:
	var grises: Array[String] = []
	for noeud: Node in racine.find_children("*", "BaseButton", true, false):
		var bouton := noeud as BaseButton
		var nom := str(bouton.name)
		if ACTIONS_SUR_PLACE.any(func(prefixe: String) -> bool: return nom.begins_with(prefixe)): continue
		if bouton.has_meta("fiche_en_match"): continue
		# Le retour de la fiche (vers l'Effectif) est remplacé par « Retour au direct ».
		if nom == "PlayerBackToSquad":
			bouton.hide()
			continue
		bouton.disabled = true
		bouton.focus_mode = Control.FOCUS_NONE
		bouton.mouse_default_cursor_shape = Control.CURSOR_ARROW
		bouton.tooltip_text = "Disponible après le match."
		bouton.set_meta("indisponible_en_match", true)
		bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
		var repos: StyleBox = bouton.get_theme_stylebox("normal")
		if repos != null: bouton.add_theme_stylebox_override("disabled", repos)
		grises.append(nom)
	return grises

## Page reconstruite quand son contenu change (onglet de la fiche, réponse du moteur, échelle).
func _actualiser_page() -> void:
	if not is_instance_valid(page) or not page.visible: return
	var etat_page: Variant = null
	if _page_sorte == "relecture": etat_page = [_relecture[2], _relecture[0].size()] if _relecture.size() == 3 else null
	var cle := JSON.stringify([_page_sorte, etat_page, size, C.density])
	if cle == _page_cle: return
	_page_cle = cle
	S.clear(page)
	var fond := ColorRect.new()
	fond.color = Charte.FOND
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	S.full(fond)
	page.add_child(fond)
	var marge := MarginContainer.new()
	S.full(marge)
	for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, roundi(MARGE * echelle))
	page.add_child(marge)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", roundi(12 * echelle))
	marge.add_child(colonne)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", roundi(18 * echelle))
	colonne.add_child(tete)
	var retour := Button.new()
	retour.name = "MatchPageBack"
	retour.text = "←  Retour au menu du match" if _page_sorte == "reglages" else "←  Retour au direct"
	retour.pressed.connect(fermer_page)
	retour.set_meta("contextual_enabled", true)
	C.style_bouton_lien(retour, 19, true)
	retour.add_theme_font_size_override("font_size", roundi(16 * echelle))
	tete.add_child(retour)
	if _page_sorte in ["reglages", "relecture"]:
		var titre := _texte("RÉGLAGES" if _page_sorte == "reglages" else "RELIRE LES ACTIONS", Charte.TITRE_GRAS, Charte.IVOIRE)
		titre.add_theme_font_size_override("font_size", roundi(22 * echelle))
		tete.add_child(titre)
	var espace := Control.new()
	espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	C.fill(espace)
	tete.add_child(espace)
	var rappel := _pastille_hud("Pause · %d’" % maxi(1, int(_live().get("minute", 0))), "MatchPageNote")
	tete.add_child(rappel)
	colonne.add_child(_filet())
	var defile := ScrollContainer.new()
	defile.name = "MatchPageScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	defile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	C.fill(defile, true)
	colonne.add_child(defile)
	if _page_sorte == "relecture":
		# Relecture des faits du tiroir Journal : son propre défilement, colonne de lecture de 960 px (1080p).
		defile.hide()
		var contenu: Control = load("res://match_action_review.gd").page(colonne, _relecture[0], _relecture[1], int(_relecture[2]))
		if contenu != null:
			contenu.size_flags_vertical = Control.SIZE_EXPAND_FILL
			contenu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			contenu.custom_minimum_size = Vector2(minf(size.x - 2.0 * MARGE * echelle, 960.0 * echelle), 0)
	elif _page_sorte == "reglages":
		var contenu: Control = load("res://ui/preferences_dialog.gd").page(app, app.get("user_preferences"))
		C.fill(contenu, true)
		defile.add_child(contenu)
	retour.call_deferred("grab_focus")

## Retour : au menu du match depuis les réglages, au direct depuis une fiche (le match repart s'il jouait).
func fermer_page() -> void:
	_mini_fiche().cacher(app)
	if not is_instance_valid(page): return
	var sorte := _page_sorte
	page.hide()
	S.clear(page)
	_page_sorte = ""
	_page_cle = ""
	if sorte == "reglages":
		apply_preferences()
		var reprendre := _reprendre_apres
		ouvrir_menu()
		_reprendre_apres = reprendre
	elif _reprendre_apres:
		_relancer()
	director._refresh_controls()

## Fenêtre « Équipe » (choix de Léo, 18/11/2026 : un seul bouton à la place de Tactique et Banc) :
## plein écran, le match se met en pause à l'ouverture et repart avec « Valider et reprendre ».
## `onglet` : « composition » ou « consignes » ; `poste` : joueur du XV déjà choisi (0 à 14).
func ouvrir_equipe(onglet: String = "composition", poste: int = -1) -> void:
	if not is_instance_valid(equipe) or _live().get("finished", false): return
	if drawer.visible: _fermer_tiroir()
	_cacher_menu()
	equipe.update_frame(model)
	equipe.ouvrir(onglet, poste)
	director._refresh_controls()

func equipe_fermee() -> void:
	director._refresh_controls()

## Le journal du moteur nomme les clubs par leur sigle interne (« FDG ») ; l'écran affiche le
## sigle de leur identité (presentation.abbr). Même règle que match-direct.cjs (renommeur).
static func sigles_affiches(texte: String, equipes: Array) -> String:
	for equipe_: Variant in equipes:
		if not equipe_ is Dictionary: continue
		var interne := str(equipe_.get("abbr", ""))
		var identite: Variant = equipe_.get("presentation")
		var affiche := str(identite.get("abbr", "")) if identite is Dictionary else ""
		if not RegEx.create_from_string("^[A-Z0-9]{2,5}$").search(interne) or affiche.is_empty() or affiche == interne: continue
		var motif := RegEx.create_from_string("\\b" + interne + "\\b")
		if motif != null: texte = motif.sub(texte, affiche, true)
	return texte

func _choisir_cadence(index: int) -> void:
	if _reglages_temps_forts:
		regie.choisir_horloge(["lente", "normale", "rapide", "eclair"][index])
		return
	app.tick_steps = [1, 4, 12][index]
	stage.set_live_cadence(app.tick_steps)

## Appelée par la régie quand le moteur projette les temps forts : l'horloge de l'écran
## intermédiaire remplace la cadence du direct, et le niveau se choisit dans la barre.
func montrer_reglages_temps_forts(direct: Dictionary, source: Node) -> void:
	if not _reglages_temps_forts:
		_reglages_temps_forts = true
		_cadence.clear()
		for text in ["Horloge posée", "Horloge normale", "Horloge rapide", "Horloge éclair"]: _cadence.add_item(text)
		_cadence.select(maxi(0, ["lente", "normale", "rapide", "eclair"].find(source.horloge)))
		_cadence.tooltip_text = "Vitesse de l’horloge entre deux temps forts. Un temps fort se joue toujours à vitesse réelle."
	var niveaux: Array = direct.get("niveaux", [])
	if JSON.stringify(niveaux) != JSON.stringify(_niveaux):
		_niveaux = niveaux.duplicate(true)
		_niveau.clear()
		for item: Dictionary in _niveaux: _niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == source.niveau and _niveau.selected != index: _niveau.select(index)
	_niveau.visible = not _niveaux.is_empty()
	if source.get("between") != null: source.between.montrer_niveau(str(source.niveau))

## Vrai tant qu'un temps fort reste à montrer : la causerie attend la fin de l'action.
func retient_la_causerie(live: Dictionary) -> bool:
	return regie != null and regie.retient(live)

## Vrai quand la régie des temps forts cadence elle-même le match.
func temps_forts_actifs() -> bool:
	return regie != null and _live().get("direct") is Dictionary

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func _pause() -> void:
	var live := _live()
	director.command("pause", {"paused":not live.get("paused", false)})

func choisir_camera(mode: String) -> void:
	_choose_camera(mode)

func _choose_camera(mode: String) -> void:
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: stage.set_camera(mode); return
	if not preferences.set_value("camera", mode): app.notice("Réglage non enregistré", preferences.last_error)
	apply_preferences()

func apply_preferences() -> void:
	if not is_instance_valid(stage): return
	var preferences: Variant = app.get("user_preferences")
	if preferences == null: return
	var camera: String = preferences.effective_camera()
	var quality: String = str(preferences.data.quality)
	stage.set_stadium_evening(preferences.data.stadium == "evening")
	stage.set_action_motion(not bool(preferences.data.reduced_motion))
	if camera != _applied_camera:
		_applied_camera = camera
		stage.set_camera(camera)
	if quality != _applied_quality:
		_applied_quality = quality
		stage.set_quality(quality)
	for button: Button in _camera_controls:
		button.set_meta("contextual_enabled", not bool(preferences.data.reduced_motion))
		# Preferences can change without a worker/waiting transition.
		button.disabled = bool(app.waiting) or bool(preferences.data.reduced_motion)
		button.tooltip_text = "Mode calme : caméra tactique fixe." if preferences.data.reduced_motion else "Caméra conservée pour les prochains matchs."

func _toggle_drawer(title: String) -> void:
	# Composition, banc et consignes : la fenêtre Équipe (anciens onglets Tactique et Banc compris).
	if title in ["Équipe", "Banc", "Tactique"]:
		ouvrir_equipe("consignes" if title == "Tactique" else "composition")
		return
	if title == drawer_tab and drawer.visible:
		_fermer_tiroir()
		return
	drawer_tab = title
	drawer.show()
	_drawer_key = ""
	_update_drawer()
	if regie != null: regie.tiroir_ferme()

func _fermer_tiroir() -> void:
	drawer_tab = ""
	drawer.hide()
	if regie != null: regie.tiroir_ferme()

func _update_drawer() -> void:
	_journal_shell.visible = drawer_tab == "Journal"
	drawer_body.get_parent().visible = drawer_tab != "Journal"
	if drawer_tab.is_empty(): return
	var live := _live()
	if drawer_tab == "Journal":
		journal.update_frame(regie.montre(live) if regie != null else live)
		return
	var key := JSON.stringify([drawer_tab, _stats(live), live.get("finished")])
	if key == _drawer_key: return
	_drawer_key = key
	S.clear(drawer_body)
	drawer_body.add_child(S.label(drawer_tab, 23, Charte.IVOIRE))
	for stat: Dictionary in _stats(live):
		drawer_body.add_child(S.label(str(stat.get("label", "")), 13, Charte.IVOIRE_2))
		drawer_body.add_child(S.label("%s    —    %s" % [str(stat.get("home", "")), str(stat.get("away", ""))], 23, Charte.IVOIRE))
		# Détail par équipe sous le compte (pénalités par phase, lancers pas droits) : une ligne courte chacune.
		if stat.get("detail") is Array:
			for ligne: Variant in stat.detail: drawer_body.add_child(S.wrap(str(ligne), 12, Charte.IVOIRE_2))
	if _stats(live).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique", 14, Charte.IVOIRE_2))
	director._refresh_controls()

## Chiffres du tiroir : entre deux temps forts, ceux d'avant la borne du moteur (rien d'un temps fort à venir).
func _stats(live: Dictionary) -> Array:
	if regie != null and regie.etat != regie.JEU and live.get("direct") is Dictionary and live.direct.has("statsRows"): return live.direct.statsRows
	return live.get("statsRows", [])

## Consigne en direct (fenêtre Équipe, onglet Consignes) : sans pause, gardée à l'écran jusqu'à la réponse.
func _envoyer_consigne(axe: String, valeur: String) -> void:
	_envois_consignes[axe] = valeur
	if regie != null: regie.envoyer_consigne(axe, valeur)
	else: app._command(Pilotage.COMMANDE, Pilotage.charge(axe, valeur))

## Identité de la rencontre affichée (projection du moteur, sinon les deux clubs) : l'après-match déjà montré.
static func cle_apres_match(live: Dictionary) -> String:
	var direct: Variant = live.get("direct")
	if direct is Dictionary and not str(direct.get("rencontre", "")).is_empty(): return str(direct.rencontre)
	var equipes: Array = live.get("teams", [])
	if equipes.size() < 2 or not equipes[0] is Dictionary or not equipes[1] is Dictionary: return ""
	return "%s|%s" % [str(equipes[0].get("id", "")), str(equipes[1].get("id", ""))]

## L'après-match prend toute la vue dès que le match est fini et entièrement montré (bouton de validation du direct
## visible) ; la scène 3D, cachée dessous, cesse alors d'être rendue.
func _suivre_apres_match() -> void:
	# Retour d'une consultation (fiche d'un club, levier…) : la vue est neuve et la régie rejouerait sa fin (sortie des
	# joueurs, dernier temps fort) avant de rendre la validation ; l'après-match déjà montré pour cette rencontre
	# revient tout de suite, sans dépendre de ce délai.
	var cle := cle_apres_match(_live())
	var deja_vu: bool = not cle.is_empty() and is_instance_valid(director) and str(director.get("apres_match_vu")) == cle
	var fini: bool = bool(_live().get("finished", false)) and ((is_instance_valid(finish) and finish.visible) or deja_vu)
	if fini and is_instance_valid(director) and director.get("apres_match_vu") != null: director.apres_match_vu = cle
	if fini and not is_instance_valid(apres_match):
		apres_match = ApresMatch.new()
		apres_match.app = app
		apres_match.director = director
		add_child(apres_match)
		apres_match.update_frame(model)
		if is_instance_valid(drawer) and drawer.visible: _fermer_tiroir()
	if is_instance_valid(apres_match) and apres_match.visible != fini:
		apres_match.visible = fini
		if fini: apres_match.update_frame(model)
	if is_instance_valid(_viewport):
		var mode := SubViewport.UPDATE_DISABLED if fini else SubViewport.UPDATE_ALWAYS
		if _viewport.render_target_update_mode != mode: _viewport.render_target_update_mode = mode
