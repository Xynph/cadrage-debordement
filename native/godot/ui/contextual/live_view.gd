extends Control
## Écran 13 « Match en direct » : habillage télé du match 3D (design/ux/13-match-direct.md, revue DA du
## 19/11/2026, variante 1 « Bandeau d'angle » choisie par Léo). Bandeau du score incliné en haut à gauche
## (horloge et période, plaques des deux clubs, score ivoire 40 px), commandes en haut à droite, journal
## de deux lignes en bas à gauche, bannière d'essai dans le tiers inférieur (match_temps_forts.gd) et menu
## du match ouvert par Échap (seule petite fenêtre, exception de Léo). Jetons et polices : ui/charte.gd,
## aucun or. Les plaques ouvrent la fiche du club et le menu ses réglages dans une page du direct : le
## match se met en pause et « Retour au direct » le rend tel quel.
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
## Joueur de la fiche ouverte depuis le journal (page « joueur »).
var _page_joueur := ""
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
		draw_style_box(Charte.style_panneau(FOND, Charte.RAYON_PANNEAU, 0), Rect2(Vector2.ZERO, size))
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
	var taille := roundi(BANDEAU_TAILLES.pause * echelle)
	bouton.add_theme_font_size_override("font_size", taille)
	if puce != null: (puce.get_child(0) as Label).add_theme_font_size_override("font_size", taille)
	var largeur_puce := puce.get_combined_minimum_size().x if puce != null else 0.0
	var a_gauche := bool(bouton.get_meta("puce_a_gauche", false))
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var couleur := Color(Charte.PANNEAU, 0.9)
		if etat in ["hover", "pressed"]: couleur = Charte.PANNEAU_2
		if etat == "focus": couleur = Color(0, 0, 0, 0)
		var cote := roundf(16 * echelle)
		var style := _fond_hud(Vector4(cote + (largeur_puce + 10 * echelle if a_gauche else 0.0), 0, cote + (0.0 if a_gauche else largeur_puce + 10 * echelle), 0), couleur, Charte.RAYON_PILULE)
		if etat == "focus":
			# Anneau de focus de la charte : doré, 2 px, décalé de 2 px.
			style.border_color = Charte.OR
			style.set_border_width_all(2)
			style.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override(etat, style)
	bouton.custom_minimum_size = Vector2(0, roundf(40 * echelle))
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
	var style := Charte.style_panneau(BandeauAngle.FOND, Charte.RAYON_PANNEAU, 0)
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

## Plaque d'un club : sigle encadré du liseré du club, nom en capitales ; survol ou focus : le nom se souligne.
## Clic ou Entrée : fiche du club dans une page du direct (le match se met en pause).
func _plaque(cote: int) -> PanelContainer:
	var plaque := _segment("MatchClubPlaque%d" % cote, Charte.CLUB)
	plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	plaque.focus_mode = Control.FOCUS_ALL
	plaque.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plaque.tooltip_text = "Fiche du club (le match se met en pause)."
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
	var t := func(cle: String) -> int: return roundi(float(BANDEAU_TAILLES[cle]) * echelle)
	var marge: MarginContainer = clock.find_parent("MatchHud").get_parent() if clock.find_parent("MatchHud") != null else null
	if marge != null:
		for bord in ["left", "top", "right", "bottom"]: marge.add_theme_constant_override("margin_" + bord, roundi(MARGE * echelle))
	clock.add_theme_font_size_override("font_size", t.call("horloge"))
	phase.add_theme_font_size_override("font_size", t.call("phase"))
	score.add_theme_font_size_override("font_size", t.call("score"))
	for nom: Label in [home, away]: nom.add_theme_font_size_override("font_size", t.call("equipe"))
	for sigle: Label in _sigles: sigle.add_theme_font_size_override("font_size", t.call("sigle"))
	var hauteur := roundf(BANDEAU_HAUTEUR * echelle)
	for segment: Control in _coque_score.get_children():
		segment.custom_minimum_size.y = hauteur
		var marges := StyleBoxEmpty.new()
		marges.content_margin_left = roundf(12 * echelle)
		marges.content_margin_right = roundf(16 * echelle)
		if segment.name == "MatchClubPlaque1": marges.content_margin_right = roundf(18 * echelle)
		if segment.name == "MatchClockBlock": marges.content_margin_left = roundf(14 * echelle)
		if segment.name == "MatchScoreBlock":
			marges.content_margin_left = roundf(16 * echelle)
		segment.add_theme_stylebox_override("panel", marges)
	(_coque_score.get_node("MatchClockBlock") as Control).custom_minimum_size.x = roundf(96 * echelle)
	score.custom_minimum_size.x = roundf(104 * echelle)
	for plaque: PanelContainer in plaques:
		var rangee: HBoxContainer = plaque.get_child(0)
		rangee.add_theme_constant_override("separation", roundi(10 * echelle))
		var souligne: ColorRect = plaque.find_child("Souligne", true, false)
		souligne.custom_minimum_size.y = maxf(1.0, roundf(2 * echelle))
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
	var meteo_vue: bool = not compact and meteo_ligne.visible
	if _meteo_boite.visible != meteo_vue: _meteo_boite.visible = meteo_vue
	# La fenêtre Équipe ouverte depuis la bande ferme le menu (le match reste en pause).
	if is_instance_valid(menu) and menu.visible and is_instance_valid(equipe) and equipe.visible: _cacher_menu()
	# Panneau du menu : ses lignes à retour automatique ne connaissent leur hauteur qu'après une mise en page.
	if is_instance_valid(menu) and menu.visible: _placer_menu()
	# Fiche du club ouverte pendant une réponse du moteur : la demande part dès qu'il est libre.
	if is_instance_valid(page) and page.visible and _page_sorte == "club" and not app.waiting:
		var Fiche = load("res://ui/immersive08/club_sheet_canvas.gd")
		var fiche: Variant = app.management_ui.get("club_sheet")
		if fiche is Dictionary and Fiche.cached(app, int(fiche.get("id", -1))).is_empty(): Fiche.request(app, int(fiche.get("id", -1)))
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
		plaques[cote].tooltip_text = ("%s : fiche du club (le match se met en pause)." % complet) if not complet.is_empty() else "Fiche du club (le match se met en pause)."
	_coque_score.queue_redraw()

## PROVISOIRE (choix de Léo) : variante B du bandeau, l'écusson du club (pack, sinon écusson officiel, sinon écusson
## recoloré) à côté du sigle, ~30 px de haut en 1080p. Actif avec CD_VARIANTE_VISUELLE=B seulement.
func _poser_ecusson(cote: int, teams: Array) -> void:
	if OS.get_environment("CD_VARIANTE_VISUELLE") != "B": return
	var rangee: HBoxContainer = plaques[cote].get_child(0)
	var ancien := rangee.get_node_or_null("MatchClubCrest%d" % cote)
	if ancien != null:
		rangee.remove_child(ancien)
		ancien.queue_free()
	if teams.size() <= cote or not (teams[cote] is Dictionary): return
	var ecusson: Control = S.G.crest(teams[cote], roundi(30 * echelle))
	ecusson.name = "MatchClubCrest%d" % cote
	ecusson.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ecusson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(ecusson)
	rangee.move_child(ecusson, 0 if cote == 0 else rangee.get_child_count() - 1)

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

## Nom d'un de nos joueurs cliqué dans le journal : sa fiche complète dans une page du direct (le match se met
## en pause) ; « Retour au direct » le rend tel quel.
func ouvrir_joueur(id: String) -> void:
	_mini_fiche().cacher(app)
	if (load("res://ui/immersive08/fiche_commune.gd").trouver(app, id, "squad") as Dictionary).is_empty(): return
	# Depuis la page Équipe (restée ouverte dessous) : c'est elle qui tient la pause et la reprise ; fermer la fiche
	# ne doit pas relancer le match.
	if not (is_instance_valid(equipe) and equipe.visible): _suspendre()
	_page_joueur = id
	_ouvrir_page("joueur")

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
	var page_ouverte := is_instance_valid(page) and page.visible
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
func _suspendre() -> void:
	var live := _live()
	if live.is_empty() or live.get("finished", false): return
	var etat := _etat_bandeau()
	if str(etat.pause) != "PAUSE" or not bool(etat.pause_possible): return
	_reprendre_apres = true
	if app.waiting: _pause_voulue = 1
	else: director.command("pause", {"paused": true})

## Relance le match s'il est en pause (et pas fini).
func _relancer() -> void:
	_reprendre_apres = false
	var live := _live()
	if live.is_empty() or live.get("finished", false) or not director._talk().is_empty(): return
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
	var chapo := "L’adjoint prend en charge la fin de cette rencontre ; tu retrouves le résultat à la fin du match." if _menu_mode == "deleguer" \
		else "Le match est en pause à la %de. Le menu de carrière reste fermé jusqu’à la fin du match." % maxi(1, minute)
	var texte := _texte(chapo, Charte.TEXTE, Charte.IVOIRE_2)
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.add_theme_font_size_override("font_size", roundi(13 * e))
	pile.add_child(texte)
	colonne.add_child(_filet())
	if _menu_mode == "deleguer":
		colonne.add_child(_option("MatchMenuConfirmer", "Confirmer : l’adjoint finit le match", "le match se joue sans toi jusqu’au coup de sifflet", ["Entrée"], func():
			fermer_menu(false)
			director.command("delegate")))
		colonne.add_child(_option("MatchMenuAnnuler", "Annuler et reprendre le match", "", ["Échap"], func(): fermer_menu(true)))
	else:
		colonne.add_child(_option("MatchMenuReprendre", "Reprendre le match", "", ["Échap", "Espace"], func(): fermer_menu(true)))
		colonne.add_child(_option("MatchMenuReglages", "Réglages", "son, image, commandes", "›", func(): ouvrir_reglages()))
		colonne.add_child(_option("MatchMenuVitesse", "Vitesse du match", "s’applique dès la reprise", {"vitesse": _vitesse_libelle()}, func(): _changer_vitesse(1)))
		var quitter_sous := "Appuie encore : le jeu se ferme, le match sera rejoué depuis le coup d’envoi." if _menu_quitter_arme \
			else "Tu reprendras avant le match : il sera rejoué depuis le coup d’envoi."
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
	for paire: Array in [["↑ ↓", "Choisir"], ["Entrée", "Valider"], ["Échap", "Reprendre" if _menu_mode == "menu" else "Annuler"]]:
		var groupe := HBoxContainer.new()
		groupe.add_theme_constant_override("separation", roundi(6 * e))
		var puce := _touche(str(paire[0]))
		(puce.get_child(0) as Label).add_theme_font_size_override("font_size", roundi(12 * e))
		groupe.add_child(puce)
		var legende := _texte(str(paire[1]), Charte.TEXTE, Charte.IVOIRE_2)
		legende.add_theme_font_size_override("font_size", roundi(12 * e))
		groupe.add_child(legende)
		pied.add_child(groupe)
	_menu_panneau.custom_minimum_size.x = roundf(480 * e)
	_menu_panneau.reset_size()
	_placer_menu()
	if not focus_avant.is_empty():
		var retrouve: Control = colonne.find_child(focus_avant, true, false)
		if retrouve != null: retrouve.call_deferred("grab_focus")

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

# --- Pages du direct : fiche du club, fiche joueur, réglages -----------------------------------

## Fiche du club `cote` (0 : recevant, 1 : visiteur) dans une page du direct : match en pause, « Retour au
## direct » le rend tel quel (et le relance s'il jouait). Fiche commune (club_sheet_canvas.gd), y compris
## pour notre club.
func ouvrir_fiche_club(cote: int) -> void:
	var teams: Array = _live().get("teams", [])
	if cote < 0 or cote >= teams.size() or not teams[cote] is Dictionary or teams[cote].get("id") == null: return
	ouvrir_fiche_club_id(int(float(teams[cote].id)))

## Fiche d'un club par son identifiant (autres matchs et classement en direct de l'entracte), même page du direct.
func ouvrir_fiche_club_id(id: int) -> void:
	if id < 0: return
	_suspendre()
	var avant: Variant = app.management_ui.get("club_sheet")
	var meme: bool = avant is Dictionary and int(avant.get("id", -1)) == id
	app.management_ui.club_sheet = {"id": id, "tab": int(avant.get("tab", 0)) if meme else 0, "sort": str(avant.get("sort", "fam")) if meme else "fam", "descending": bool(avant.get("descending", false)) if meme else false}
	_ouvrir_page("club")

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

## Ce que la fiche du club sait du match en cours (club_sheet_canvas.gd, « MATCH EN COURS ») : les deux clubs,
## le score et la minute du direct.
func _poser_match_pour_fiches() -> void:
	var equipes: Array = _live().get("teams", [])
	if equipes.size() < 2 or not equipes[0] is Dictionary or not equipes[1] is Dictionary or equipes[0].get("id") == null or equipes[1].get("id") == null:
		app.remove_meta("fiche_club_en_match")
		return
	var marque: Array = _live().get("score", [0, 0])
	app.set_meta("fiche_club_en_match", {"ids": [int(float(equipes[0].id)), int(float(equipes[1].id))], "score": [int(marque[0]), int(marque[1])], "minute": int(_live().get("minute", 0))})

func _ouvrir_page(sorte: String) -> void:
	_mini_fiche().cacher(app)
	if drawer.visible: _fermer_tiroir()
	_page_sorte = sorte
	_page_cle = ""
	if sorte == "joueur":
		# Fiche ouverte depuis le direct : l'onglet Vue d'ensemble, sans charge individuelle en cours d'édition.
		app.management_ui.erase("charge_joueur")
		app.management_ui.immersive_player_tab = 0
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

## Actions qui restent sur place dans une page du direct (onglets, tri, suivi du club) ; tout le reste mène à un
## autre écran ou ouvre une fenêtre : grisé, « Disponible après le match ».
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

## Fiche du club ouverte dans le direct : les noms de NOS joueurs (Effectif, XV type, joueurs clés…) gardent leur
## clic, qui ouvre leur fiche complète dans le direct (`ouvrir_joueur`), et leur mini-fiche au survol. Les autres
## noms (adversaires : pas de fiche complète) restent grisés par `neutraliser`. Rend les ids liés.
func _lier_nos_joueurs(racine: Node) -> Array[String]:
	var lies: Array[String] = []
	var Commune = load("res://ui/immersive08/fiche_commune.gd")
	for noeud: Node in racine.find_children("*", "BaseButton", true, false):
		var bouton := noeud as BaseButton
		if str(bouton.get_meta("entity_kind", "")) != "player": continue
		var id := str(bouton.get_meta("entity_id", ""))
		if id.is_empty() or (Commune.trouver(app, id, "squad") as Dictionary).is_empty(): continue
		for liaison: Dictionary in bouton.pressed.get_connections(): bouton.pressed.disconnect(liaison.callable)
		bouton.pressed.connect(ouvrir_joueur.bind(id))
		bouton.mouse_entered.connect(_survol_joueur.bind(id, bouton))
		bouton.mouse_exited.connect(func(): _mini_fiche().cacher(app, bouton))
		bouton.set_meta("fiche_en_match", true)
		bouton.tooltip_text = "Voir sa fiche (le match reste en pause)"
		if bouton is Button:
			var taille: int = bouton.get_theme_font_size("font_size")
			C.style_bouton_lien(bouton, 12)
			bouton.add_theme_font_size_override("font_size", taille)
		lies.append(id)
	return lies

## Onglets et suivi de la fiche du club au style lien commun (charte §7 : pas de boîte encadrée) ; l'onglet
## ouvert reste souligné.
static func liens_fiche_club(racine: Node) -> void:
	for noeud: Node in racine.find_children("*", "Button", true, false):
		var bouton := noeud as Button
		var nom := str(bouton.name)
		if not (nom.begins_with("ClubSheetTab") or nom == "ClubSheetFollow"): continue
		var actif := bouton.toggle_mode and bouton.button_pressed
		bouton.icon = null
		C.style_bouton_lien(bouton, 22, actif)
		if not actif and nom.begins_with("ClubSheetTab"):
			for cle in ["font_color", "font_focus_color"]: bouton.add_theme_color_override(cle, Charte.IVOIRE_2)

## Page reconstruite quand son contenu change (onglet de la fiche, réponse du moteur, échelle).
func _actualiser_page() -> void:
	if not is_instance_valid(page) or not page.visible: return
	var fiche: Variant = app.management_ui.get("club_sheet")
	var donnees := false
	if _page_sorte == "club" and fiche is Dictionary:
		donnees = not load("res://ui/immersive08/club_sheet_canvas.gd").cached(app, int(fiche.get("id", -1))).is_empty()
	var etat_page: Variant = null
	if _page_sorte == "club": etat_page = fiche
	elif _page_sorte == "joueur": etat_page = [_page_joueur, app.management_ui.get("immersive_player_tab", 0)]
	elif _page_sorte == "relecture": etat_page = [_relecture[2], _relecture[0].size()] if _relecture.size() == 3 else null
	var cle := JSON.stringify([_page_sorte, etat_page, donnees, size, C.density])
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
	# Un seul titre : celui de la fiche (club, joueur) ; « RÉGLAGES » pour l'écran des réglages qui n'en a pas.
	if _page_sorte in ["reglages", "relecture"]:
		var titre := _texte("RÉGLAGES" if _page_sorte == "reglages" else "RELIRE LES ACTIONS", Charte.TITRE_GRAS, Charte.IVOIRE)
		titre.add_theme_font_size_override("font_size", roundi(22 * echelle))
		tete.add_child(titre)
	var rappel := _texte("Le match est en pause à la %de. Grisé : disponible après le match." % maxi(1, int(_live().get("minute", 0))), Charte.TEXTE, Charte.IVOIRE_2)
	rappel.name = "MatchPageNote"
	rappel.add_theme_font_size_override("font_size", roundi(13 * echelle))
	C.fill(rappel)
	rappel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	elif _page_sorte == "joueur":
		var trouve: Dictionary = load("res://ui/immersive08/fiche_commune.gd").trouver(app, _page_joueur, "squad")
		if not trouve.is_empty():
			var fiche_joueur: Control = load("res://ui/immersive08/player_canvas.gd").build(app, trouve.joueur, "squad")
			fiche_joueur.name = "MatchPlayerSheet"
			defile.add_child(fiche_joueur)
			neutraliser(fiche_joueur)
	else:
		_poser_match_pour_fiches()
		var Fiche = load("res://ui/immersive08/club_sheet_canvas.gd")
		var toile := Control.new()
		toile.name = "MatchClubSheetCanvas"
		toile.custom_minimum_size = Vector2(Fiche.WIDTH, Fiche.HEIGHT) * C.density
		defile.add_child(toile)
		Fiche.build(app, toile)
		liens_fiche_club(toile)
		_lier_nos_joueurs(toile)
		neutraliser(toile)
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
	app.remove_meta("fiche_club_en_match")
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
	if _stats(live).is_empty(): drawer_body.add_child(S.wrap("Aucune statistique disponible pour cette rencontre.", 14, Charte.IVOIRE_2))
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
