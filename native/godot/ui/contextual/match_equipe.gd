extends "res://ui/contextual/match_equipe_roles.gd"
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
		# Match du manager : le changement attend le prochain arrêt de jeu (file du moteur, match-arrets.cjs).
		var meta: Variant = app.model.get("meta", {}) if app.get("model") is Dictionary else {}
		var file: Variant = meta.get("fileArret") if meta is Dictionary else null
		if erreur.is_empty() and file is Dictionary and bool(file.get("enAttente", false)): _message = "⧗ Au prochain arrêt de jeu : " + _succes.left(1).to_lower() + _succes.substr(1)
		_message_teinte = C.ALERT if not erreur.is_empty() else C.MINT
		_attente = ""
		_cle = ""
		if visible: _rafraichir()

# --- Données -------------------------------------------------------------------

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
