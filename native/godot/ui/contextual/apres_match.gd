extends Control
## Après-match (design/ux/15-apres-match.md ; choix de Léo du 19/11/2026 : « verdict en tête » avec le classement
## complet de la division). Posé par la vue du direct (live_view.gd) une fois tout le match montré et avant la
## validation du résultat : bandeau vestiaire, pastille V/N/D en pilule et score, les trois raisons du « Pourquoi » avec
## leur levier, fil du score, Gabi ; à droite le classement complet après la journée (zones réelles du championnat),
## ta place, les autres matchs de la journée et le seul aplat doré de l’écran, « Valider le résultat ».
## Tout ce qui ressemble à un lien ouvre un écran du jeu par `director.consulter(cible)` (match_immersed laisse alors
## naviguer ; « Continuer » de la coque ou Espace ramène ici). Aucune donnée inventée : une donnée absente est omise.
## Données : `live.direct` (pourquoi, hommeDuMatch, marques, notes, journee, statsRows, camp) et le modèle.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Zones = preload("res://ui/immersive08/standings_zones.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const PORTRAIT = preload("res://guide/assets/coach-poses.png")
const MATTE = preload("res://guide/coach_matte.gdshader")

## Dessin de la charte finale : forme arrondie droite (`pave` : écusson et sigle de club à 6 px, pastille V/N/D et bouton
## doré en pilule, liseré) ou triangle (▲ ▼ : aucune police du jeu n'a ces glyphes), avec un contour facultatif.
class Trace extends Control:
	var forme := "pave"
	var couleur := Color.WHITE
	var bord := Color(0, 0, 0, 0)
	## Rayon des coins ; négatif : pilule (demi-hauteur).
	var rayon := -1.0
	var epaisseur := 2.0
	func _init(f: String = "pave", c: Color = Color.WHITE, r: float = -1.0) -> void:
		forme = f
		couleur = c
		rayon = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 1 or r.size.y < 1: return
		match forme:
			"haut": draw_colored_polygon(PackedVector2Array([Vector2(r.size.x / 2.0, 0), r.end, Vector2(0, r.end.y)]), couleur)
			"bas": draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(r.end.x, 0), Vector2(r.size.x / 2.0, r.end.y)]), couleur)
			_:
				var s := StyleBoxFlat.new()
				s.bg_color = couleur
				s.draw_center = couleur.a > 0.0
				s.set_corner_radius_all(roundi(minf(r.size.x, r.size.y) / 2.0 if rayon < 0.0 else rayon))
				s.border_color = bord
				s.set_border_width_all(roundi(epaisseur) if bord.a > 0.0 else 0)
				s.anti_aliasing = true
				draw_style_box(s, r)

var app: Control
var director: Node
var model: Dictionary = {}
## Sous-page « Voir plus » (statistiques, notes de ton XV, journal) à la place du verdict, avec retour.
var detail := false
var bouton_valider: Button
var _cle := ""
var _e := 1.0
var _clubs: Dictionary = {}
var _droite: VBoxContainer
var _ta_place: Control
var _autres: Control
static var _gras: FontVariation

## DM Sans graisse 700 : les valeurs des lignes d'information (classement, essais).
static func texte_gras() -> Font:
	if _gras == null:
		_gras = FontVariation.new()
		_gras.base_font = Charte.TEXTE
		_gras.variation_opentype = {"wght": 700}
	return _gras

func _ready() -> void:
	name = "ApresMatch"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(func(): _cle = ""; _reconstruire())

func update_frame(value: Dictionary) -> void:
	model = value
	_reconstruire()

# --- Données ------------------------------------------------------------------------------------

func _live() -> Dictionary:
	return model.get("live", {}) if model.get("live") is Dictionary else {}

func _direct() -> Dictionary:
	var live := _live()
	return live.get("direct", {}) if live.get("direct") is Dictionary else {}

func _camp() -> int:
	var camp := int(_direct().get("camp", -1))
	if camp in [0, 1]: return camp
	var equipes: Array = _live().get("teams", [])
	var nous: Variant = model.get("club", {}).get("id") if model.get("club") is Dictionary else null
	for k in mini(2, equipes.size()):
		if equipes[k] is Dictionary and nous != null and equipes[k].get("id") == nous: return k
	return 0

## « victoire », « defaite » ou « nul » (le moteur le dit dans `pourquoi.issue`, sinon le score).
func issue() -> String:
	var bloc: Variant = _direct().get("pourquoi")
	if bloc is Dictionary and str(bloc.get("issue", "")) in ["victoire", "defaite", "nul"]: return str(bloc.issue)
	var score: Array = _live().get("score", [0, 0])
	var c := _camp()
	if score.size() < 2: return "nul"
	return "victoire" if int(score[c]) > int(score[1 - c]) else ("defaite" if int(score[c]) < int(score[1 - c]) else "nul")

func _journee() -> Dictionary:
	var j: Variant = _direct().get("journee")
	return j if j is Dictionary else {}

func _classement() -> Array:
	var c: Variant = _journee().get("classement")
	return c if c is Array else []

func _fixture() -> Dictionary:
	var next: Variant = model.get("next")
	return next if next is Dictionary else {}

## Compétition de la rencontre (projection `leagues` du modèle), {} si inconnue.
func _ligue() -> Dictionary:
	var id := str(_fixture().get("competitionId", model.get("meta", {}).get("leagueId", "")))
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary and str(ligue.get("id", "")) == id: return ligue
	return {}

func _nom_competition() -> String:
	var ligue := _ligue()
	if not ligue.is_empty(): return str(ligue.get("name", ""))
	return str(_fixture().get("label", "")).get_slice(" · ", 0)

## Étape de la rencontre (« Journée 9 ») lue dans son libellé.
func _etape() -> String:
	var label := str(_fixture().get("label", ""))
	var competition := _nom_competition()
	if label.is_empty(): return ""
	return label.trim_prefix(competition + " · ") if label.begins_with(competition + " · ") else ""

## « J9 » depuis « Journée 9 », sinon l'étape telle quelle.
func _etape_courte() -> String:
	var m := RegEx.create_from_string("(\\d+)").search(_etape())
	return "J" + m.get_string(1) if m != null and _etape().to_lower().begins_with("journ") else _etape()

func _club(id: Variant) -> Dictionary:
	return _clubs.get(_cle_id(id), {})

static func _cle_id(id: Variant) -> String:
	return str(int(id)) if id is float or id is int else str(id)

func _indexer_clubs() -> void:
	_clubs = {}
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary:
			for club: Variant in ligue.get("rows", []):
				if club is Dictionary and club.get("id") != null: _clubs[_cle_id(club.id)] = club
	for club: Variant in (model.get("league", []) if model.get("league") is Array else []):
		if club is Dictionary and club.get("id") != null and not _clubs.has(_cle_id(club.id)): _clubs[_cle_id(club.id)] = club
	for club: Variant in _live().get("teams", []):
		if club is Dictionary and club.get("id") != null: _clubs[_cle_id(club.id)] = club

## Vraie couleur du club (identité), sinon neutre.
func _couleur(club: Dictionary) -> Color:
	var texte := str(G.identity(club).get("color", club.get("color", "")))
	if texte.begins_with("#") and (texte.length() == 7 or texte.length() == 9): return Color(texte)
	return Color(0, 0, 0, 0)

static func ordinal(rang: int) -> String:
	return "1er" if rang == 1 else "%de" % rang

static func signe(n: int) -> String:
	return ("+%d" % n) if n > 0 else ("−%d" % -n if n < 0 else "0")

static func note_texte(note: Variant) -> String:
	return ("%.1f" % float(note)).replace(".", ",") if note is float or note is int else ""

# --- Mise en page ---------------------------------------------------------------------------------

func _d(valeur: float) -> int: return roundi(valeur * _e)
func _f(valeur: float) -> int: return maxi(12, roundi(valeur * _e))

func _texte(texte: String, taille: float, couleur: Color = Charte.IVOIRE, police: Font = Charte.TEXTE, retour: bool = false) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", police)
	l.add_theme_font_size_override("font_size", _f(taille))
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if retour: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _h(ecart: float = 8) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", _d(ecart))
	return b

func _v(ecart: float = 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", _d(ecart))
	return b

## Fond d'un bloc. `rayon` : 0 pour une ligne de liste transparente (seul un filet la sépare), sinon un rayon de la charte
## (RAYON_PANNEAU, RAYON_CARTE, RAYON_PETIT, RAYON_PILULE).
func _fond(couleur: Color, gauche: float = 0, haut: float = 0, droite: float = -1, bas: float = -1, rayon: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	if rayon > 0:
		s.set_corner_radius_all(rayon if rayon >= Charte.RAYON_PILULE else _d(rayon))
		s.anti_aliasing = true
	s.content_margin_left = _d(gauche)
	s.content_margin_top = _d(haut)
	s.content_margin_right = _d(gauche if droite < 0 else droite)
	s.content_margin_bottom = _d(haut if bas < 0 else bas)
	return s

## Panneau de la charte (rayon 18, sans bordure) ; carte dans un panneau : `rayon` = RAYON_CARTE.
func _panneau(couleur: Color = Charte.PANNEAU, gauche: float = 16, haut: float = 10, rayon: int = Charte.RAYON_PANNEAU) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _fond(couleur, gauche, haut, -1, -1, rayon))
	return p

## Lien de la charte (texte ivoire, souligné au survol) qui ouvre `cible` (navigation_controller.open_entity).
func _lien(texte: String, cible: Dictionary, taille: float = 13, souligne := false) -> Button:
	var b := Button.new()
	b.text = texte
	C.style_bouton_lien(b, 17, souligne)
	b.add_theme_font_override("font", Charte.TEXTE)
	b.add_theme_font_size_override("font_size", _f(taille))
	for look in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := b.get_theme_stylebox(look).duplicate() as StyleBoxFlat
		s.content_margin_left = 0
		s.content_margin_right = 0
		s.content_margin_top = _d(2)
		s.content_margin_bottom = _d(2)
		b.add_theme_stylebox_override(look, s)
	b.set_meta("cible", cible)
	b.focus_mode = Control.FOCUS_ALL
	# Jamais de clic silencieux : une destination indisponible donne un lien grisé et sa raison écrite (infobulle).
	var raison := indisponible(cible)
	b.set_meta("contextual_enabled", raison.is_empty())
	if not raison.is_empty():
		b.disabled = true
		b.set_meta("indisponible", raison)
		b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	b.pressed.connect(func(): ouvrir(cible))
	return b

## Raison écrite quand `cible` ne peut pas s'ouvrir (navigation_controller.entity_available), "" sinon.
func indisponible(cible: Dictionary) -> String:
	var kind := str(cible.get("kind", ""))
	if kind in ["", "detail"]: return ""
	var navigation: Variant = app.get("navigation_controller") if app != null else null
	if navigation == null or not is_instance_valid(navigation) or not navigation.has_method("entity_available"): return ""
	if navigation.entity_available(cible): return ""
	return {"club": "Fiche du club indisponible dans cette carrière.", "player": "Fiche du joueur indisponible.",
		"date": "Calendrier indisponible pour ce jour.", "competition": "Classements indisponibles pour cette compétition.",
		"training": "Entraînement indisponible pour le moment.", "menu": "Écran indisponible pour le moment."}.get(kind, "Indisponible pour le moment.")

## Infobulle d'un lien : la raison d'indisponibilité passe toujours en tête.
func _aide(b: Control, texte: String) -> void:
	var raison := str(b.get_meta("indisponible", ""))
	b.tooltip_text = (raison + ("\n" + texte if not texte.is_empty() else "")) if not raison.is_empty() else texte

## Clic sur un lien : l'écran visé s'ouvre (le résultat reste à valider ; Espace ou « Continuer » ramène ici).
func ouvrir(cible: Dictionary) -> void:
	if str(cible.get("kind", "")) == "detail":
		detail = bool(cible.get("ouvert", true))
		_cle = ""
		_reconstruire()
		return
	if director != null and director.has_method("consulter"): director.consulter(cible)

## Nom d'un joueur : notre effectif = fiche complète au clic, mini-fiche au survol. Adversaire : clic = XV type de son
## club (fiche du club), survol = mini-fiche de ce que le jeu en connaît (celle du marché s'il y est suivi).
func _lien_joueur(id: String, nom: String, camp: int, taille: float = 13, police: Font = null) -> Control:
	var nous := camp == _camp()
	var a_nous := nous and _dans_effectif(id)
	var equipes: Array = _live().get("teams", [])
	var club: Dictionary = equipes[camp] if camp >= 0 and camp < equipes.size() and equipes[camp] is Dictionary else {}
	var cible: Dictionary = {}
	if a_nous: cible = {"kind": "player", "id": id}
	elif club.get("id") != null: cible = {"kind": "club", "id": _cle_id(club.get("id")), "onglet": 2}
	if nom.is_empty() or cible.is_empty(): return _texte(nom, taille, Charte.IVOIRE_2)
	var b := _lien(nom, cible, taille)
	if police != null: b.add_theme_font_override("font", police)
	b.name = "ApresMatchJoueur_" + id.validate_node_name()
	# Mini-fiche commune (mini_fiche.gd) : notre effectif, sinon l'adversaire lu dans la fiche de son club déjà chargée
	# (source « adverse », ce que le jeu en connaît), sinon une piste du marché ; à défaut, la fiche de ce match.
	var source_fiche := "squad" if a_nous else ""
	if not a_nous and app != null and app.get("model") is Dictionary:
		var commune: Script = load("res://ui/immersive08/fiche_commune.gd")
		for source: String in ["adverse", "market"]:
			if source_fiche.is_empty() and not (commune.trouver(app, id, source) as Dictionary).is_empty(): source_fiche = source
	if not source_fiche.is_empty():
		MiniFiche.lier(app, b, id, source_fiche)
		# La mini-fiche se pose sur l'application : au-dessus de la scène du match (z 100).
		b.mouse_entered.connect(func():
			var fiche := MiniFiche.actuelle(app)
			if fiche != null: fiche.z_index = 200)
	else: _lier_fiche_adverse(b, id, nom, club, camp)
	return b

# --- Mini-fiche d'un joueur adverse : ce que le jeu en connaît ------------------------------------------

## Survol (ou focus puis touche I) du nom d'un adversaire : poste, club, match du jour ; niveau et attributs « — »
## tant que le joueur n'est pas observé. Un Control posé dans l'écran, jamais une fenêtre.
func _lier_fiche_adverse(b: Button, id: String, nom: String, club: Dictionary, camp: int) -> void:
	b.tooltip_text = ""
	b.set_meta("fiche_adverse", id)
	b.mouse_entered.connect(func(): montrer_fiche_adverse(b, id, nom, club, camp))
	b.mouse_exited.connect(cacher_fiche_adverse)
	b.focus_exited.connect(cacher_fiche_adverse)
	b.tree_exiting.connect(cacher_fiche_adverse)
	b.gui_input.connect(func(event: InputEvent):
		var touche := event as InputEventKey
		if touche == null or not touche.pressed or touche.echo or touche.keycode != KEY_I: return
		if is_instance_valid(get_node_or_null("MiniFicheAdverse")): cacher_fiche_adverse()
		else: montrer_fiche_adverse(b, id, nom, club, camp)
		b.accept_event())

func _adversaire(id: String) -> Dictionary:
	for j: Variant in (_direct().get("adversaire", []) if _direct().get("adversaire") is Array else []):
		if j is Dictionary and str(j.get("joueur", "")) == id: return j
	return {}

func montrer_fiche_adverse(ancre: Control, id: String, nom: String, club: Dictionary, camp: int) -> Control:
	cacher_fiche_adverse()
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return null
	var connu := _adversaire(id)
	var note: Variant = connu.get("note")
	var notes: Variant = _direct().get("notes")
	if note == null and notes is Dictionary and notes.get(id) is Dictionary: note = notes[id].get("note")
	var fiche := _panneau(Charte.PANNEAU_2, 16, 12, Charte.RAYON_CARTE)
	fiche.name = "MiniFicheAdverse"
	fiche.z_index = 200
	fiche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := fiche.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_width_left = maxi(2, _d(3))
	style.border_color = Charte.club_trait(_couleur(club))
	var col := _v(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fiche.add_child(col)
	var tete := _h(8)
	tete.add_child(_sigle(club, 28, 20, 12))
	tete.add_child(_texte(nom, 16, Charte.IVOIRE, Charte.TITRE_GRAS))
	col.add_child(tete)
	var poste := str(connu.get("poste", ""))
	col.add_child(_texte(" · ".join(PackedStringArray(([poste] if not poste.is_empty() else []) + [G.club_name(club)])), 13, Charte.IVOIRE_2))
	col.add_child(_texte("CE QUE LE JEU CONNAÎT", 12, Charte.IVOIRE_3, Charte.TITRE))
	for ligne: Array in [["Niveau", "—"], ["Attributs", "— (joueur non observé)"]]:
		var r := _h(8)
		r.add_child(_texte(str(ligne[0]), 13, Charte.IVOIRE_2))
		r.add_child(_texte(str(ligne[1]), 13, Charte.IVOIRE, texte_gras()))
		col.add_child(r)
	var faits: Array[String] = []
	if note is float or note is int: faits.append("note " + note_texte(note))
	if int(connu.get("essais", 0)) > 0: faits.append("%d essai%s" % [int(connu.essais), "s" if int(connu.essais) > 1 else ""])
	if int(connu.get("plaquages", 0)) > 0: faits.append("%d plaquages" % int(connu.plaquages))
	if int(connu.get("metres", 0)) > 0: faits.append("%d m" % int(connu.metres))
	if not faits.is_empty():
		var r := _h(8)
		r.add_child(_texte("Ce match", 13, Charte.IVOIRE_2))
		r.add_child(_texte(" · ".join(PackedStringArray(faits)), 13, Charte.IVOIRE, texte_gras()))
		col.add_child(r)
	col.add_child(_texte("Clic : XV type de " + G.club_name(club), 12, Charte.IVOIRE_3))
	add_child(fiche)
	fiche.reset_size()
	var taille := fiche.get_combined_minimum_size()
	var vue := get_viewport_rect().size
	var r_ancre := ancre.get_global_rect()
	var pos := Vector2(r_ancre.position.x, r_ancre.end.y + _d(6))
	if pos.y + taille.y > vue.y - 8: pos.y = r_ancre.position.y - taille.y - _d(6)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vue.x - taille.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vue.y - taille.y - 8.0))
	fiche.global_position = pos
	fiche.set_meta("ancre", ancre)
	return fiche

func cacher_fiche_adverse() -> void:
	var fiche := get_node_or_null("MiniFicheAdverse")
	if fiche != null:
		remove_child(fiche)
		fiche.queue_free()

func _dans_effectif(id: String) -> bool:
	for p: Variant in model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return true
	return false

## Écusson du club : vignette droite à coins de 6 px, à sa couleur sombre, liseré à sa couleur lisible (la couleur d'un
## club ne vit que sur son écusson, son maillot et son liseré).
func _sigle(club: Dictionary, largeur: float, hauteur: float, taille: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.custom_minimum_size = Vector2(_d(largeur), _d(hauteur))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var couleur := _couleur(club)
	var t := Trace.new("pave", C.readable_primary_fill(couleur) if couleur.a > 0 else Charte.PANNEAU_3, _d(Charte.RAYON_PETIT))
	t.name = "Ecusson"
	t.bord = Charte.club_trait(couleur) if couleur.a > 0 else Charte.IVOIRE_3
	t.epaisseur = maxf(1.0, _d(2))
	p.add_child(t)
	var l := _texte(G.club_abbr(club) if not club.is_empty() else "", taille, Charte.IVOIRE, Charte.TITRE_EXTRA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## Pastille V / N / D en pilule (charte §4.5) : la lettre toujours écrite, et la forme dit le résultat sans la couleur :
## V pleine vert clair (lettre PANNEAU), N demi-pleine gris-vert (lettre crème), D contour doré (lettre dorée).
static func style_pastille(lettre: String) -> Dictionary:
	match lettre:
		"V": return {"fond": Charte.V, "bord": Color(0, 0, 0, 0), "lettre": Charte.PANNEAU}
		"D": return {"fond": Color(0, 0, 0, 0), "bord": Charte.D, "lettre": Charte.D}
	return {"fond": Color(Charte.N, 0.35), "bord": Charte.N, "lettre": Charte.IVOIRE}

func _pastille(lettre: String, largeur: float, hauteur: float, taille: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "ApresMatchPastille" + lettre
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Jamais plus petit que 20 × 14 px réels : la lettre (12 px au moins) reste entière.
	p.custom_minimum_size = Vector2(maxi(_d(largeur), 20), maxi(_d(hauteur), 14))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sens := style_pastille(lettre)
	var forme := Trace.new("pave", sens.fond)
	forme.name = "FondPastille"
	forme.bord = sens.bord
	forme.epaisseur = maxf(1.0, _d(2) if hauteur >= 30 else 1.0)
	p.add_child(forme)
	var l := _texte(lettre, taille, sens.lettre, Charte.TITRE_EXTRA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _triangle(haut: bool, couleur: Color, cote: float = 10) -> Control:
	var t := Trace.new("haut" if haut else "bas", couleur)
	t.custom_minimum_size = Vector2(_d(cote), _d(cote * 0.8))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

# --- Construction ----------------------------------------------------------------------------------

func _reconstruire() -> void:
	if not is_inside_tree(): return
	var vue := get_viewport_rect().size
	_e = clampf(minf(vue.x / 1920.0, vue.y / 1080.0), 0.5, 2.0)
	var cle := JSON.stringify([vue, detail, _live().get("score"), _live().get("finished"), _direct().get("pourquoi"), _direct().get("hommeDuMatch"), _direct().get("marques"),
		_journee(), _direct().get("notes"), _direct().get("statsRows"), _live().get("events", []).size(), _fixture().get("label")])
	if cle == _cle: return
	_cle = cle
	_indexer_clubs()
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	bouton_valider = null
	_ta_place = null
	_autres = null
	var fond := ColorRect.new()
	fond.color = Charte.FOND
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var colonne := _v(16)
	colonne.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(colonne)
	colonne.add_child(_bandeau())
	var marge := MarginContainer.new()
	for bord: String in ["left", "right"]: marge.add_theme_constant_override("margin_" + bord, _d(24))
	marge.add_theme_constant_override("margin_bottom", _d(40))
	marge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(marge)
	var corps := _h(24)
	marge.add_child(corps)
	var gauche := _v(12)
	gauche.name = "ApresMatchGauche"
	C.fill(gauche, true, 1116)
	corps.add_child(gauche)
	_droite = _v(10)
	_droite.name = "ApresMatchDroite"
	C.fill(_droite, true, 732)
	corps.add_child(_droite)
	if detail: _sous_page(gauche)
	else:
		_pourquoi(gauche)
		var vide := Control.new()
		vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauche.add_child(vide)
		_fil_du_score(gauche)
		var vide_bas := Control.new()
		vide_bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vide_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauche.add_child(vide_bas)
		_gabi(gauche)
	_colonne_classement(_droite)
	for b: Node in find_children("*", "BaseButton", true, false):
		if b.has_meta("indisponible") and not (b as Control).tooltip_text.begins_with(str(b.get_meta("indisponible"))): _aide(b, (b as Control).tooltip_text)
	if is_instance_valid(director) and director.has_method("_refresh_controls"): director._refresh_controls()
	_ajuster.call_deferred()
	_focus_valider.call_deferred()

func _focus_valider() -> void:
	if is_instance_valid(bouton_valider) and bouton_valider.is_inside_tree() and bouton_valider.is_visible_in_tree(): bouton_valider.grab_focus()

## La colonne de droite tient dans l'écran : « Ta place » passe sur une ligne, puis les autres matchs en sigles.
## Rien n'est retiré.
func _ajuster() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(_droite) or not _droite.is_inside_tree(): return
	var dispo := get_viewport_rect().size.y - _droite.get_global_rect().position.y - float(_d(40))
	if dispo <= 0: return
	if is_instance_valid(_ta_place) and not bool(_ta_place.get_meta("condense", false)) and _droite.get_combined_minimum_size().y > dispo + 1.0:
		_remplacer(_ta_place, _place(_classement(), true))
		await get_tree().process_frame
		if not is_instance_valid(_droite): return
	if is_instance_valid(_autres) and not bool(_autres.get_meta("sigles", false)) and _droite.get_combined_minimum_size().y > dispo + 1.0:
		_remplacer(_autres, _autres_matchs(true))

func _remplacer(ancien: Control, nouveau: Control) -> void:
	if not is_instance_valid(ancien) or nouveau == null: return
	var parent := ancien.get_parent()
	var index := ancien.get_index()
	parent.remove_child(ancien)
	ancien.queue_free()
	parent.add_child(nouveau)
	parent.move_child(nouveau, index)
	if ancien == _ta_place: _ta_place = nouveau
	elif ancien == _autres: _autres = nouveau
	if is_instance_valid(director) and director.has_method("_refresh_controls"): director._refresh_controls()
func _bandeau() -> Control:
	var bandeau := Control.new()
	bandeau.name = "ApresMatchBandeau"
	bandeau.custom_minimum_size.y = _d(256)
	bandeau.clip_contents = true
	var photo := C.photo("lockerroom", Vector2.ZERO, true, 0.35)
	photo.tooltip_text = ""
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bandeau.add_child(photo)
	C.veil(bandeau)
	var marge := MarginContainer.new()
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", _d(48))
	marge.add_theme_constant_override("margin_top", _d(20))
	marge.add_theme_constant_override("margin_right", _d(24))
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(marge)
	var col := _v(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(col)
	# Ligne du haut : FIN, compétition · étape · stade · date, et le menu Plus à droite.
	var haut := _h(12)
	col.add_child(haut)
	var fin := PanelContainer.new()
	fin.add_theme_stylebox_override("panel", _fond(Charte.PANNEAU_3, 6, 1, -1, -1, Charte.RAYON_PETIT))
	fin.add_child(_texte("FIN", 12, Charte.IVOIRE, Charte.TITRE_GRAS))
	fin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(fin)
	var lieu: Array[String] = []
	for morceau: String in [_nom_competition(), _etape_courte(), P.fixture_venue(_fixture(), false) if not _fixture().is_empty() else "", P.fixture_date(_fixture()) if not _fixture().is_empty() else ""]:
		if not morceau.is_empty(): lieu.append(morceau)
	var contexte := _texte(" · ".join(PackedStringArray(lieu)), 13, Charte.IVOIRE_2)
	contexte.name = "ApresMatchContexte"
	C.fill(contexte)
	haut.add_child(contexte)
	haut.add_child(_menu_plus())
	# Verdict : pastille V/N/D en pilule et mot.
	var verdict := _h(16)
	col.add_child(verdict)
	var lettre: String = {"victoire": "V", "defaite": "D", "nul": "N"}.get(issue(), "N")
	verdict.add_child(_pastille(lettre, 72, 48, 32))
	var mot := _texte({"victoire": "Victoire", "defaite": "Défaite", "nul": "Match nul"}.get(issue(), "Match nul").to_upper(), 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	mot.name = "ApresMatchVerdict"
	verdict.add_child(mot)
	col.add_child(_ligne_score())
	for ligne: HBoxContainer in _meta(): col.add_child(ligne)
	return bandeau

func _menu_plus() -> MenuButton:
	var plus := MenuButton.new()
	plus.name = "ApresMatchPlus"
	plus.text = "Plus  ▾"
	plus.flat = false
	# Bouton secondaire de la charte : pilule à contour FILET sur un panneau (lisible sur la photo voilée), focus doré.
	C.style_bouton_contour(plus, 15)
	for look in ["normal", "disabled"]:
		var s := (plus.get_theme_stylebox(look) as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.bg_color = Color(Charte.PANNEAU, 0.85)
		plus.add_theme_stylebox_override(look, s)
	plus.add_theme_font_override("font", Charte.TEXTE)
	plus.add_theme_font_size_override("font_size", _f(15))
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.set_meta("contextual_enabled", true)
	var menu := plus.get_popup()
	var cibles: Array = [{"kind": "detail", "ouvert": true}]
	menu.add_item("Statistiques, notes et journal", 0)
	var competition := str(_fixture().get("competitionId", ""))
	if not _classement().is_empty() and not competition.is_empty():
		menu.add_item("Classements de la compétition", cibles.size())
		cibles.append({"kind": "competition", "id": competition})
	var date := str(_fixture().get("date", ""))
	if not date.is_empty():
		menu.add_item("Calendrier du jour", cibles.size())
		cibles.append({"kind": "date", "id": date})
	plus.set_meta("cibles", cibles)
	menu.id_pressed.connect(func(id: int): if id >= 0 and id < cibles.size(): ouvrir(cibles[id]))
	return plus

## Score : un seul panneau (PANNEAU 90 %, rayon 18) qui porte les deux clubs (écusson et nom, lien vers sa fiche) et le
## score crème 48 px. Pas de fond à la couleur des clubs : elle reste sur leur écusson.
func _ligne_score() -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = "ApresMatchScoreCadre"
	cadre.add_theme_stylebox_override("panel", _fond(Color(Charte.PANNEAU, 0.9), 16, 0, -1, -1, Charte.RAYON_PANNEAU))
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ligne := _h(0)
	ligne.name = "ApresMatchScore"
	cadre.add_child(ligne)
	var equipes: Array = _live().get("teams", [])
	var score: Array = _live().get("score", [0, 0])
	for cote in 2:
		var club: Dictionary = equipes[cote] if cote < equipes.size() and equipes[cote] is Dictionary else {}
		if cote == 1:
			var chiffre := PanelContainer.new()
			chiffre.add_theme_stylebox_override("panel", _fond(Color(0, 0, 0, 0), 20, 0))
			var texte := _texte("%d – %d" % [int(score[0]) if score.size() > 0 else 0, int(score[1]) if score.size() > 1 else 0], 48, Charte.IVOIRE, Charte.TITRE_EXTRA)
			texte.name = "ApresMatchScoreChiffres"
			chiffre.add_child(texte)
			ligne.add_child(chiffre)
		ligne.add_child(_plaque(club, cote))
	return cadre

## Plaque d'un club dans le panneau du score : son écusson et son nom (lien vers sa fiche), sans fond.
func _plaque(club: Dictionary, cote: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "ApresMatchPlaque%d" % cote
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.custom_minimum_size.y = _d(52)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", _d(0 if cote == 0 else 4))
	marge.add_theme_constant_override("margin_right", _d(4 if cote == 0 else 0))
	p.add_child(marge)
	var rang := _h(10)
	marge.add_child(rang)
	var sigle := _sigle(club, 48, 34, 19)
	var nom: Control
	if club.get("id") != null: nom = _lien(G.club_name(club).to_upper(), {"kind": "club", "id": _cle_id(club.get("id"))}, 26)
	else: nom = _texte(G.club_name(club).to_upper(), 26)
	nom.add_theme_font_override("font", Charte.TITRE_GRAS)
	nom.name = "ApresMatchClub%d" % cote
	if cote == 0:
		rang.add_child(sigle)
		rang.add_child(nom)
	else:
		rang.add_child(nom)
		rang.add_child(sigle)
	return p

## Lignes d'information sous le score : classement avant → après, homme du match, essais, bonus de la journée.
func _meta() -> Array[HBoxContainer]:
	var lignes: Array[HBoxContainer] = []
	var une := _h(22)
	var deux := _h(22)
	var nous := {}
	for r: Variant in _classement():
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	if not nous.is_empty():
		var bloc := _h(5)
		bloc.name = "ApresMatchRang"
		bloc.add_child(_texte("Classement", 15, Charte.IVOIRE_2))
		var avant: Variant = nous.get("rangOfficiel")
		var rang := int(nous.get("rang", 0))
		var valeur := (ordinal(int(avant)) + " → " if avant is float or avant is int else "") + ordinal(rang)
		var competition := str(_fixture().get("competitionId", ""))
		if competition.is_empty(): bloc.add_child(_texte(valeur, 15, Charte.IVOIRE, texte_gras()))
		else:
			var lien_rang := _lien(valeur, {"kind": "competition", "id": competition}, 15)
			lien_rang.name = "ApresMatchRangLien"
			lien_rang.add_theme_font_override("font", texte_gras())
			_aide(lien_rang, "Classements de la compétition")
			bloc.add_child(lien_rang)
		var delta := int(nous.get("delta", 0))
		if avant is float or avant is int:
			if delta != 0: bloc.add_child(_triangle(delta > 0, Charte.V if delta > 0 else Charte.D))
			bloc.add_child(_texte(("%s place%s" % [signe(delta), "s" if absi(delta) > 1 else ""]) if delta != 0 else "même place", 15, Charte.IVOIRE_2))
		une.add_child(bloc)
	var homme: Variant = _direct().get("hommeDuMatch")
	if homme is Dictionary and not str(homme.get("nom", "")).is_empty():
		var bloc := _h(5)
		bloc.name = "ApresMatchHomme"
		bloc.add_child(_texte("Homme du match", 15, Charte.IVOIRE_2))
		bloc.add_child(_lien_joueur(str(homme.get("joueur", "")), str(homme.get("nom", "")), int(homme.get("camp", -1)), 15, texte_gras()))
		var note := note_texte(homme.get("note"))
		if not note.is_empty(): bloc.add_child(_texte("(%s)" % note, 15, Charte.IVOIRE_2))
		(une if nous.is_empty() else deux).add_child(bloc)
	var essais: Variant = _live().get("tries")
	if essais is Array and essais.size() == 2:
		var bloc := _h(5)
		bloc.add_child(_texte("Essais", 15, Charte.IVOIRE_2))
		bloc.add_child(_texte("%d – %d" % [int(essais[0]), int(essais[1])], 15, Charte.IVOIRE, texte_gras()))
		deux.add_child(bloc)
	var equipes: Array = _live().get("teams", [])
	for r: Variant in _classement():
		if not r is Dictionary: continue
		var dans := false
		for e: Variant in equipes:
			if e is Dictionary and _cle_id(e.get("id")) == _cle_id(r.get("clubId")): dans = true
		if not dans: continue
		var nom := G.club_name(_club(r.get("clubId"))) if not _club(r.get("clubId")).is_empty() else str(r.get("nom", ""))
		for bonus: Array in [["bonusOff", "Point de bonus offensif"], ["bonusDef", "Point de bonus défensif"]]:
			if int(r.get(bonus[0], 0)) > 0: deux.add_child(_texte("%s pour %s" % [bonus[1], nom], 15, Charte.IVOIRE_2))
	for ligne in [une, deux]:
		if ligne.get_child_count() > 0: lignes.append(ligne)
	return lignes

## Écran et libellé du lien d'un levier : la section où l'on agit (composition, consignes du plan de jeu, entraînement
## de la discipline, condition dans l'effectif, préparation), sinon la route du moteur. {} sans destination.
static func cible_levier(raison: Dictionary) -> Dictionary:
	match str(raison.get("levier", "")):
		"composition": return {"cible": {"kind": "menu", "route": "Composition"}, "libelle": "Revoir la composition"}
		"tactique": return {"cible": {"kind": "menu", "route": "Plan de jeu"}, "libelle": "Ajuster les consignes"}
		"discipline": return {"cible": {"kind": "training", "id": "team"}, "libelle": "Travailler à l’entraînement"}
		"condition": return {"cible": {"kind": "menu", "route": "Effectif"}, "libelle": "Voir la condition"}
		"preparation": return {"cible": {"kind": "menu", "route": "Préparation"}, "libelle": "Préparer la semaine"}
	var route := str(raison.get("route", ""))
	if route.is_empty(): return {}
	return {"cible": {"kind": "menu", "route": route}, "libelle": str(raison.get("action", "Ouvrir " + route))}

## « Pourquoi on a gagné / perdu / ce nul » : trois raisons au plus, du moteur (match-pourquoi.cjs), chacune avec
## son sens (▲ point fort, ▼ à corriger : forme et mot) et le lien vers l'écran de son levier.
func _pourquoi(parent: VBoxContainer) -> void:
	var titre_ligne := _h(16)
	parent.add_child(titre_ligne)
	var titre := _texte({"victoire": "Pourquoi on a gagné", "defaite": "Pourquoi on a perdu", "nul": "Pourquoi ce nul"}.get(issue(), "Pourquoi ce résultat").to_upper(), 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	titre.name = "ApresMatchPourquoiTitre"
	titre_ligne.add_child(titre)
	titre_ligne.add_child(_texte("de la plus décisive à la moins · chaque lien s’ouvre, Espace te ramène ici", 13, Charte.IVOIRE_2))
	var bloc: Variant = _direct().get("pourquoi")
	var raisons: Array = bloc.get("raisons", []) if bloc is Dictionary and bloc.get("raisons") is Array else []
	var cadre := _panneau(Charte.PANNEAU, 0, 0)
	parent.add_child(cadre)
	var liste := _v(0)
	cadre.add_child(liste)
	var serre := _e < 0.8
	var n := 0
	for raison: Variant in raisons:
		if not raison is Dictionary: continue
		n += 1
		var ligne := PanelContainer.new()
		ligne.name = "ApresMatchRaison%d" % int(raison.get("rang", n))
		var style := _fond(Color(0, 0, 0, 0), 20, 8 if serre else 26)
		style.border_width_top = 1
		style.border_color = Charte.FILET
		ligne.add_theme_stylebox_override("panel", style)
		liste.add_child(ligne)
		var r := _h(14)
		ligne.add_child(r)
		var rang := _texte(str(int(raison.get("rang", n))), 34, Charte.IVOIRE_3, Charte.TITRE_EXTRA)
		rang.custom_minimum_size.x = _d(36)
		r.add_child(rang)
		var negatif := str(raison.get("sens", "")) == "negatif"
		var sens := _h(6)
		sens.custom_minimum_size.x = _d(128)
		# « À corriger » : triangle au contour doré, mot en crème (un seul aplat doré par écran : Valider le résultat).
		var fleche := _triangle(not negatif, Charte.PANNEAU if negatif else Charte.IVOIRE) as Trace
		if negatif: fleche.bord = Charte.D
		sens.add_child(fleche)
		var mot_sens := _texte("À CORRIGER" if negatif else "POINT FORT", 13, Charte.IVOIRE, Charte.TITRE)
		mot_sens.name = "Sens"
		sens.add_child(mot_sens)
		r.add_child(sens)
		var levier := _texte(str(raison.get("levierLabel", "")).to_upper(), 15, Charte.IVOIRE, Charte.TITRE_GRAS)
		levier.custom_minimum_size.x = _d(112)
		r.add_child(levier)
		var texte := _texte(str(raison.get("texte", "")), 16, Charte.IVOIRE, Charte.TEXTE, true)
		C.fill(texte)
		r.add_child(texte)
		var levier_cible := cible_levier(raison)
		var action := Control.new()
		if not levier_cible.is_empty():
			action = _lien(str(levier_cible.libelle) + " →", levier_cible.cible, 14, true)
			action.name = "ApresMatchLevier_" + str(raison.get("levier", ""))
			(action as Button).alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action.custom_minimum_size.x = _d(200)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(action)
	if n == 0:
		var vide := _texte("Match trop équilibré pour désigner une cause : les statistiques complètes sont dans « Voir plus ».", 16, Charte.IVOIRE_2, Charte.TEXTE, true)
		vide.name = "ApresMatchSansRaison"
		var m := MarginContainer.new()
		for bord: String in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + bord, _d(20))
		m.add_child(vide)
		liste.add_child(m)
	var plus := _lien("Voir plus : statistiques, notes, journal →", {"kind": "detail", "ouvert": true}, 15, true)
	plus.name = "ApresMatchVoirPlus"
	plus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(plus)

## Fil du score : chaque essai et coup de pied réussi (`direct.marques`), sigle du club, minute, auteur, score.
func _fil_du_score(parent: VBoxContainer) -> void:
	var marques: Variant = _direct().get("marques")
	if not marques is Array or marques.is_empty(): return
	var cadre := _panneau(Charte.PANNEAU, 16, 10)
	cadre.name = "ApresMatchFil"
	parent.add_child(cadre)
	var col := _v(4)
	cadre.add_child(col)
	col.add_child(_texte("FIL DU SCORE", 12, Charte.IVOIRE_2, Charte.TITRE))
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", _d(18))
	flux.add_theme_constant_override("v_separation", _d(4))
	col.add_child(flux)
	var equipes: Array = _live().get("teams", [])
	for m: Variant in marques:
		if not m is Dictionary: continue
		var cote := int(m.get("equipe", -1))
		var club: Dictionary = equipes[cote] if cote >= 0 and cote < equipes.size() and equipes[cote] is Dictionary else {}
		var item := _h(6)
		item.name = "ApresMatchMarque"
		item.tooltip_text = str(m.get("texte", ""))
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		item.add_child(_sigle(club, 28, 20, 12))
		item.add_child(_texte(str(m.get("horloge", m.get("minute", ""))).trim_suffix("′").trim_suffix("'") + "′", 15, Charte.IVOIRE, Charte.TITRE_GRAS))
		var nature := nature_marque(m, _e < 0.8)
		var mot := _texte(nature, 12, Charte.IVOIRE_2, Charte.TITRE)
		mot.name = "Nature"
		item.add_child(mot)
		var nom := str(m.get("nom", ""))
		if not nom.is_empty(): item.add_child(_lien_joueur(str(m.get("joueur", "")), nom, cote, 13))
		var buteur: Variant = m.get("buteur")
		if buteur is Dictionary and not str(buteur.get("nom", "")).is_empty():
			item.add_child(_texte("transf.", 12, Charte.IVOIRE_2))
			item.add_child(_lien_joueur(str(buteur.get("joueur", "")), str(buteur.nom), cote, 13))
		var s: Variant = m.get("score")
		if s is Array and s.size() == 2: item.add_child(_texte("%d–%d" % [int(s[0]), int(s[1])], 13, Charte.IVOIRE_2))
		flux.add_child(item)

## Mot écrit d'une marque : « ESSAI », « ESSAI TRANSFORMÉ », « PÉNALITÉ », « DROP » (moteur : `nature`).
## `court` (petites hauteurs) : « ESSAI TR. », « PÉN. ».
static func nature_marque(m: Dictionary, court: bool = false) -> String:
	match str(m.get("nature", "")):
		"essai": return "ESSAI"
		"essai-transforme": return "ESSAI TR." if court else "ESSAI TRANSFORMÉ"
		"penalite": return "PÉN." if court else "PÉNALITÉ"
		"drop": return "DROP"
	return "ESSAI" if str(m.get("kind", "")) == "try" else "PÉNALITÉ OU DROP"

## Gabi : le levier de la semaine tiré des raisons du moteur, et l'homme du match s'il est des nôtres.
func phrase_gabi() -> String:
	var bloc: Variant = _direct().get("pourquoi")
	var raisons: Array = bloc.get("raisons", []) if bloc is Dictionary and bloc.get("raisons") is Array else []
	var negatif := {}
	var positif := {}
	for r: Variant in raisons:
		if not r is Dictionary: continue
		if str(r.get("sens", "")) == "negatif" and negatif.is_empty(): negatif = r
		if str(r.get("sens", "")) != "negatif" and positif.is_empty(): positif = r
	var morceaux: Array[String] = []
	var homme: Variant = _direct().get("hommeDuMatch")
	if homme is Dictionary and int(homme.get("camp", -1)) == _camp() and not str(homme.get("nom", "")).is_empty():
		var chiffres: Array[String] = []
		if int(homme.get("essais", 0)) > 0: chiffres.append("%d essai%s" % [int(homme.essais), "s" if int(homme.essais) > 1 else ""])
		if int(homme.get("plaquages", 0)) > 0: chiffres.append("%d plaquages" % int(homme.plaquages))
		if int(homme.get("metres", 0)) > 0: chiffres.append("%d m gagnés" % int(homme.metres))
		morceaux.append("%s a fait le match%s." % [str(homme.nom), (" : " + ", ".join(PackedStringArray(chiffres))) if not chiffres.is_empty() else ""])
	var levier_neg := str(negatif.get("levierLabel", "")).to_lower()
	var levier_pos := str(positif.get("levierLabel", "")).to_lower()
	match issue():
		"victoire":
			if not levier_neg.is_empty(): morceaux.append("On a gagné malgré la %s : c’est le chantier de la semaine." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("Garde ce qui a marché : la %s." % levier_pos)
		"defaite":
			if not levier_neg.is_empty(): morceaux.append("Pas de panique : le chantier de la semaine, c’est la %s." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("On a perdu, mais la %s a tenu : on repart de là." % levier_pos)
		_:
			if not levier_neg.is_empty(): morceaux.append("Un nul qui se joue à la %s : on la travaille cette semaine." % levier_neg)
			elif not levier_pos.is_empty(): morceaux.append("Un nul, mais la %s a tenu : on garde cette base." % levier_pos)
	if morceaux.is_empty(): morceaux.append("Rien d’alarmant dans les chiffres : on garde cette base pour la semaine.")
	return " ".join(PackedStringArray(morceaux))

func _gabi(parent: VBoxContainer) -> void:
	# Panneau à 18 qui porte deux cartes à 12 (portrait, bulle), séparées par 12 px de panneau.
	var carte := _panneau(Charte.PANNEAU, 10, 10)
	carte.name = "ApresMatchGabi"
	parent.add_child(carte)
	var rang := _h(12)
	carte.add_child(rang)
	var cadre_portrait := _panneau(Charte.PANNEAU_2, 17, 5, Charte.RAYON_CARTE)
	cadre_portrait.custom_minimum_size = Vector2(_d(116), _d(116))
	rang.add_child(cadre_portrait)
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ShaderMaterial.new()
	matte.shader = MATTE
	portrait.material = matte
	cadre_portrait.add_child(portrait)
	var bulle := _panneau(Charte.PANNEAU_2, 24, 12, Charte.RAYON_CARTE)
	C.fill(bulle)
	rang.add_child(bulle)
	var interieur := _h(14)
	bulle.add_child(interieur)
	var filet_club := Trace.new("pave", Charte.club_trait(_couleur(model.get("club", {}) if model.get("club") is Dictionary else {})))
	filet_club.custom_minimum_size = Vector2(_d(8), _d(90))
	filet_club.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interieur.add_child(filet_club)
	var col := _v(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	C.fill(col)
	interieur.add_child(col)
	col.add_child(_texte("GABI, TON ADJOINT", 12, Charte.IVOIRE_2, Charte.TITRE))
	var phrase := _texte("« " + phrase_gabi() + " »", 16, Charte.IVOIRE, Charte.TEXTE, true)
	phrase.name = "ApresMatchGabiPhrase"
	col.add_child(phrase)

# --- Colonne de droite ---------------------------------------------------------------------------------

func _zones() -> Array:
	var z: Variant = _ligue().get("zones")
	return z if z is Array else []

func _zone(rang: int) -> Dictionary:
	for z: Variant in _zones():
		if z is Dictionary and rang >= int(z.get("from", 0)) and rang <= int(z.get("to", -1)): return z
	return {}

func _colonne_classement(parent: VBoxContainer) -> void:
	var classement := _classement()
	if not classement.is_empty():
		var cadre := _panneau(Charte.PANNEAU, 16, 10)
		cadre.name = "ApresMatchClassement"
		parent.add_child(cadre)
		var col := _v(0)
		cadre.add_child(col)
		var titre := _h(8)
		titre.custom_minimum_size.y = _d(28)
		col.add_child(titre)
		var etape := _etape_courte()
		titre.add_child(_texte(("Classement après la " + etape if not etape.is_empty() else "Classement après la journée").to_upper(), 18, Charte.IVOIRE, Charte.TITRE_GRAS))
		var droite := _texte(" · ".join(PackedStringArray([_nom_competition(), "%d clubs" % classement.size()]).slice(0 if not _nom_competition().is_empty() else 1)), 12, Charte.IVOIRE_2)
		droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		C.fill(droite)
		titre.add_child(droite)
		col.add_child(_ligne_table(["", "#", "CLUB", "J", "V", "N", "D", "DIFF.", "PTS", "FORME"], true))
		for r: Variant in classement:
			if r is Dictionary: col.add_child(_ligne_club(r, classement.size()))
		var legende := _legende()
		if legende != null: col.add_child(legende)
		_ta_place = _place(classement, _e < 0.8)
		if _ta_place != null: parent.add_child(_ta_place)
	_autres = _autres_matchs(_e < 0.8)
	if _autres != null: parent.add_child(_autres)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vide)
	parent.add_child(_bloc_valider())

const LARGEURS := [30, 30, 0, 30, 30, 30, 30, 50, 40, 140]

func _cellule(texte: String, k: int, couleur: Color = Charte.IVOIRE, police: Font = Charte.TEXTE, taille: float = 13) -> Label:
	var l := _texte(texte, taille, couleur, police)
	if LARGEURS[k] > 0: l.custom_minimum_size.x = _d(LARGEURS[k])
	else: C.fill(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k in [1, 3, 4, 5, 6, 7, 8] else HORIZONTAL_ALIGNMENT_LEFT
	l.clip_text = true
	return l

func _ligne_table(entetes: Array, entete: bool) -> PanelContainer:
	var ligne := PanelContainer.new()
	var style := _fond(Color(0, 0, 0, 0), 0, 0)
	style.border_width_bottom = 1
	style.border_color = Charte.FILET
	ligne.add_theme_stylebox_override("panel", style)
	ligne.custom_minimum_size.y = _d(24)
	var r := _h(6)
	ligne.add_child(r)
	for k in entetes.size(): r.add_child(_cellule(str(entetes[k]), k, Charte.IVOIRE_2, Charte.TITRE, 12))
	return ligne

## Ligne d'un club : zone (liseré, symbole dessiné), rang, sigle et nom (lien vers sa fiche), J V N D, différence,
## points, forme (cinq pastilles V/N/D). Notre club : fond choisi et liseré à sa couleur.
func _ligne_club(r: Dictionary, total: int) -> PanelContainer:
	var rang := int(r.get("rang", 0))
	var nous := bool(r.get("nous", false))
	var zone := _zone(rang)
	var ligne := PanelContainer.new()
	ligne.name = "ApresMatchLigne%d" % rang
	ligne.set_meta("rang", rang)
	ligne.set_meta("zone", str(zone.get("kind", "")))
	# Pas de bandes alternées : un filet entre les lignes ; notre club en ligne sélectionnée (SELECTION, coins de 6 px).
	var style := _fond(Charte.SELECTION if nous else Color(0, 0, 0, 0), 0, 0, -1, -1, Charte.RAYON_PETIT if nous else 0)
	if not nous and rang < total:
		style.border_width_bottom = 1
		style.border_color = Charte.FILET
	# Fin de zone : filet plus marqué sous la dernière ligne de la zone.
	if not zone.is_empty() and rang < total and _zone(rang + 1).get("kind") != zone.get("kind"):
		style.border_width_bottom = 1
		style.border_color = Charte.IVOIRE_3
	ligne.add_theme_stylebox_override("panel", style)
	ligne.custom_minimum_size.y = _d(24)
	var rangee := _h(6)
	ligne.add_child(rangee)
	var case_zone := _h(0)
	case_zone.custom_minimum_size.x = _d(LARGEURS[0])
	var lisere := ColorRect.new()
	lisere.custom_minimum_size.x = maxi(2, _d(3))
	lisere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var club := _club(r.get("clubId"))
	lisere.color = Charte.club_trait(_couleur(club)) if nous else (Zones.tint(str(zone.kind)) if not zone.is_empty() else Color(0, 0, 0, 0))
	case_zone.add_child(lisere)
	var centre := CenterContainer.new()
	C.fill(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not zone.is_empty():
		var marque := Zones.mark_slot(str(zone.kind), 10.0 * _e)
		centre.add_child(marque)
		centre.tooltip_text = str(zone.get("label", ""))
		centre.mouse_filter = Control.MOUSE_FILTER_PASS
	case_zone.add_child(centre)
	rangee.add_child(case_zone)
	rangee.add_child(_cellule(str(rang), 1))
	var case_club := _h(8)
	C.fill(case_club)
	# Petites hauteurs : sans le sigle, le nom du club garde sa place (la forme a sa largeur minimale).
	if _e >= 0.8: case_club.add_child(_sigle(club if not club.is_empty() else {"abbr": r.get("abbr", "")}, 28, 20, 12))
	var nom := str(r.get("nom", "")) if club.is_empty() else G.club_name(club)
	var lien := _lien(nom, {"kind": "club", "id": _cle_id(r.get("clubId"))}, 13)
	lien.name = "ApresMatchClubLigne%d" % rang
	if nous: lien.add_theme_font_override("font", C.BOLD)
	lien.clip_text = true
	lien.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lien.tooltip_text = nom
	C.fill(lien)
	case_club.add_child(lien)
	rangee.add_child(case_club)
	rangee.add_child(_cellule(str(int(r.get("joues", 0))), 3))
	for k in [["gagnes", 4], ["nuls", 5], ["perdus", 6]]:
		rangee.add_child(_cellule(str(int(r.get(k[0], 0))) if r.has(k[0]) else "", k[1]))
	rangee.add_child(_cellule(signe(int(r.get("diff", 0))), 7, Charte.IVOIRE_2, Charte.TEXTE, 12))
	rangee.add_child(_cellule(str(int(r.get("points", 0))), 8, Charte.IVOIRE, C.BOLD))
	var forme := _h(3)
	forme.custom_minimum_size.x = maxi(_d(LARGEURS[9]), 5 * 20 + 4 * 3)
	forme.name = "Forme"
	for lettre: String in forme_vnd(r.get("forme", []) if r.get("forme") is Array else []):
		forme.add_child(_pastille(lettre, 24, 16, 11))
	rangee.add_child(forme)
	return ligne

## Forme en lettres V / N / D. Le moteur (CDWorldCareer.rows, via match-multiplex.cjs) l'écrit déjà en V / N / D, où
## D veut dire défaite ; une forme brute W / D / L (D = nul) est reconnue à ses W ou L et convertie (W→V, D→N, L→D).
static func forme_vnd(forme: Array) -> Array[String]:
	var brute := forme.any(func(x: Variant): return str(x) in ["W", "L"])
	var table: Dictionary = {"W": "V", "D": "N", "L": "D"} if brute else {"V": "V", "N": "N", "D": "D"}
	var sortie: Array[String] = []
	for x: Variant in forme:
		if table.has(str(x)): sortie.append(str(table[str(x)]))
	return sortie

## Légende des zones présentes : symbole dessiné et libellé (« 1er à 4e · Phases finales »), puis la note courte.
func _legende() -> Control:
	var zones := _zones()
	var note := str(_ligue().get("zoneShortNote", "")) if _ligue().get("zoneShortNote") is String else ""
	if zones.is_empty() and note.is_empty(): return null
	var rang := _h(24)
	rang.name = "ApresMatchLegende"
	rang.custom_minimum_size.y = _d(26)
	for z: Variant in zones:
		if not z is Dictionary: continue
		var item := _h(5)
		item.add_child(Zones.mark_slot(str(z.get("kind", "")), 10.0 * _e))
		var de := int(z.get("from", 0))
		var a := int(z.get("to", 0))
		item.add_child(_texte(("%s à %s" % [ordinal(de), ordinal(a)] if a > de else ordinal(de)) + " · " + str(z.get("label", "")), 12, Charte.IVOIRE))
		rang.add_child(item)
	if not note.is_empty(): rang.add_child(_texte(note, 12, Charte.IVOIRE_2))
	return rang

## Écart de points écrit en toutes lettres : « 3 pts d'avance sur le 13e », « à 20 pts du 1er », « à égalité avec le 11e ».
static func ecart_texte(ecart: int, rang: int) -> String:
	if ecart > 0: return "%d pt%s d’avance sur le %s" % [ecart, "s" if ecart > 1 else "", ordinal(rang)]
	if ecart < 0: return "à %d pt%s du %s" % [-ecart, "s" if ecart < -1 else "", ordinal(rang)]
	return "à égalité avec le %s" % ordinal(rang)

## Ta place : écart de points avec le premier et nos voisins directs (chacun mène à la fiche du club). `condense` :
## une seule ligne (petites hauteurs d'écran), toujours présente.
func _place(classement: Array, condense: bool = false) -> Control:
	var nous := {}
	for r: Variant in classement:
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	if nous.is_empty(): return null
	var rang := int(nous.get("rang", 0))
	var voisins: Array = []
	for cible in [1, rang - 1, rang + 1, rang + 2]:
		if cible < 1 or cible > classement.size() or cible == rang or voisins.size() >= 3: continue
		if voisins.any(func(v: Dictionary): return int(v.get("rang", 0)) == cible): continue
		var r: Variant = classement[cible - 1]
		if r is Dictionary: voisins.append(r)
	var cadre := _panneau(Charte.PANNEAU, 16, 6 if condense else 10)
	cadre.name = "ApresMatchTaPlace"
	cadre.set_meta("condense", condense)
	var col := _v(6)
	cadre.add_child(col)
	var titre := _h(8)
	col.add_child(titre)
	titre.add_child(_texte("TA PLACE", 15, Charte.IVOIRE, Charte.TITRE_GRAS))
	var zone := _zone(rang)
	var resume := "%s · %d pts" % [ordinal(rang), int(nous.get("points", 0))] + ((" · " + str(zone.get("label", "")).to_lower()) if not zone.is_empty() else "")
	if condense:
		titre.add_child(_texte(resume, 12, Charte.IVOIRE_2))
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", _d(14))
		col.add_child(flux)
		for v: Dictionary in voisins:
			var club_v := _club(v.get("clubId"))
			var nom_v := G.club_name(club_v) if not club_v.is_empty() else str(v.get("nom", ""))
			var lien := _lien(ecart_texte(int(nous.get("points", 0)) - int(v.get("points", 0)), int(v.get("rang", 0))) + ", " + nom_v, {"kind": "club", "id": _cle_id(v.get("clubId"))}, 12)
			lien.name = "ApresMatchEcart%d" % int(v.get("rang", 0))
			_aide(lien, "%s · %d pts" % [nom_v, int(v.get("points", 0))])
			flux.add_child(lien)
		return cadre
	var droite := _texte(resume, 12, Charte.IVOIRE_2)
	droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	C.fill(droite)
	titre.add_child(droite)
	var cases := _h(8)
	col.add_child(cases)
	for v: Dictionary in voisins:
		var ecart := int(nous.get("points", 0)) - int(v.get("points", 0))
		var club := _club(v.get("clubId"))
		var nom := G.club_name(club) if not club.is_empty() else str(v.get("nom", ""))
		var b := _lien("", {"kind": "club", "id": _cle_id(v.get("clubId"))}, 12)
		b.name = "ApresMatchEcart%d" % int(v.get("rang", 0))
		_aide(b, "%s · %d pts" % [nom, int(v.get("points", 0))])
		b.add_theme_stylebox_override("normal", _fond(Charte.PANNEAU_2, 10, 6, -1, -1, Charte.RAYON_CARTE))
		b.add_theme_stylebox_override("hover", _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE))
		var focus_case := _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE)
		focus_case.border_color = Charte.OR
		focus_case.set_border_width_all(2)
		b.add_theme_stylebox_override("focus", focus_case)
		b.add_theme_stylebox_override("pressed", _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE))
		C.fill(b)
		var contenu := _v(0)
		contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contenu.offset_left = _d(10)
		contenu.offset_top = _d(4)
		contenu.add_child(_texte(signe(ecart) if ecart != 0 else "=", 20, Charte.IVOIRE, Charte.TITRE_GRAS))
		contenu.add_child(_texte(ecart_texte(ecart, int(v.get("rang", 0))) + ", " + nom, 12, Charte.IVOIRE_2, Charte.TEXTE, true))
		b.add_child(contenu)
		b.custom_minimum_size.y = _d(60)
		b.clip_contents = true
		cases.add_child(b)
	return cadre

## Les autres matchs de la journée (`journee.matchs`, résultats réels du moteur) ; un clic ouvre le calendrier du jour
## (le jeu n'a pas d'écran de résumé d'une rencontre : sa fiche est une petite fenêtre). Une colonne avec les noms
## entiers ; `sigles` (place comptée) : trois colonnes « sigle score sigle », noms entiers en infobulle. Jamais de « … ».
func _autres_matchs(sigles: bool = false) -> Control:
	var matchs: Variant = _journee().get("matchs")
	if not matchs is Array or matchs.is_empty(): return null
	var cadre := _panneau(Charte.PANNEAU, 16, 10)
	cadre.name = "ApresMatchAutresMatchs"
	cadre.set_meta("sigles", sigles)
	var col := _v(4)
	cadre.add_child(col)
	var etape := _etape_courte()
	col.add_child(_texte(("Les autres matchs de la " + etape if not etape.is_empty() else "Les autres matchs de la journée").to_upper(), 15, Charte.IVOIRE, Charte.TITRE_GRAS))
	var grille := GridContainer.new()
	grille.columns = 3 if sigles else 1
	grille.name = "ApresMatchAutresGrille"
	grille.add_theme_constant_override("h_separation", _d(16))
	grille.add_theme_constant_override("v_separation", _d(2))
	col.add_child(grille)
	var date := str(_fixture().get("date", ""))
	var cible: Dictionary = {"kind": "date", "id": date} if not date.is_empty() else {"kind": "competition", "id": str(_fixture().get("competitionId", ""))}
	var n := 0
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var dom: Dictionary = m.get("home", {}) if m.get("home") is Dictionary else {}
		var ext: Dictionary = m.get("away", {}) if m.get("away") is Dictionary else {}
		var c1 := _club(dom.get("id"))
		var c2 := _club(ext.get("id"))
		var n1 := G.club_name(c1) if not c1.is_empty() else str(dom.get("nom", ""))
		var n2 := G.club_name(c2) if not c2.is_empty() else str(ext.get("nom", ""))
		var b := _lien("", cible, 13)
		b.name = "ApresMatchAutreMatch%d" % n
		_aide(b, "%s %d – %d %s · le calendrier du jour" % [n1, int(dom.get("score", 0)), int(ext.get("score", 0)), n2])
		C.fill(b)
		var rang := _h(6)
		rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rang.add_child(_sigle(c1 if not c1.is_empty() else {"abbr": dom.get("abbr", "")}, 28, 20, 12))
		if not sigles:
			var nom1 := _texte(n1, 13)
			C.fill(nom1)
			rang.add_child(nom1)
		var score := _texte("%d – %d" % [int(dom.get("score", 0)), int(ext.get("score", 0))], 14, Charte.IVOIRE, Charte.TITRE_GRAS)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.custom_minimum_size.x = _d(56)
		rang.add_child(score)
		if not sigles:
			var nom2 := _texte(n2, 13)
			nom2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			C.fill(nom2)
			rang.add_child(nom2)
		rang.add_child(_sigle(c2 if not c2.is_empty() else {"abbr": ext.get("abbr", "")}, 28, 20, 12))
		# Le bouton ne mesure pas ses enfants : la rangée est posée dessus et lui donne sa taille minimale.
		b.add_child(rang)
		rang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.custom_minimum_size = Vector2(rang.get_combined_minimum_size().x, maxf(_d(24), rang.get_combined_minimum_size().y))
		rang.minimum_size_changed.connect(func(): b.custom_minimum_size = Vector2(rang.get_combined_minimum_size().x, maxf(_d(24), rang.get_combined_minimum_size().y)))
		grille.add_child(b)
		n += 1
	return cadre
## Seul aplat doré de l'écran (charte : le bouton principal d'une page sans Continuer), en pilule : valide le résultat.
func _bloc_valider() -> Control:
	var col := _v(10)
	col.name = "ApresMatchSuite"
	col.alignment = BoxContainer.ALIGNMENT_END
	var aide := _texte("Valide le résultat · la suite de ta semaine s’ouvre ensuite", 13, Charte.IVOIRE_2)
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Petites hauteurs : le libellé du bouton suffit, la colonne de droite garde le classement entier.
	aide.visible = _e >= 0.8
	col.add_child(aide)
	var b := Button.new()
	b.name = "ApresMatchValider"
	b.text = ""
	b.accessibility_name = "Valider le résultat · touche Espace"
	b.custom_minimum_size = Vector2(_d(440), _d(56))
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	for look in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	# Focus (charte §7) : le seul cadre complet permis, et seulement en navigation au clavier ; au repos et à la souris,
	# rien (le bouton a pourtant le focus à l'ouverture : Espace ou Entrée valident).
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cadre_focus := Panel.new()
	cadre_focus.name = "ApresMatchValiderFocus"
	var trait_focus := StyleBoxFlat.new()
	trait_focus.draw_center = false
	# Anneau de focus de la charte : doré, 2 px, décalé de 2 px, en pilule comme le bouton.
	trait_focus.border_color = Charte.OR
	trait_focus.set_border_width_all(2)
	trait_focus.set_corner_radius_all(Charte.RAYON_PILULE)
	trait_focus.anti_aliasing = true
	cadre_focus.add_theme_stylebox_override("panel", trait_focus)
	cadre_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for cote: String in ["offset_left", "offset_top"]: cadre_focus.set(cote, -_d(4))
	for cote: String in ["offset_right", "offset_bottom"]: cadre_focus.set(cote, _d(4))
	cadre_focus.hide()
	b.add_child(cadre_focus)
	b.focus_entered.connect(_maj_focus_clavier)
	b.focus_exited.connect(_maj_focus_clavier)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("contextual_enabled", true)
	var plaque := Trace.new("pave", Charte.OR)
	plaque.name = "ApresMatchValiderFond"
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(plaque)
	b.mouse_entered.connect(func(): plaque.couleur = Charte.OR_VIF; plaque.queue_redraw())
	b.mouse_exited.connect(func(): plaque.couleur = Charte.OR; plaque.queue_redraw())
	var rang := _h(14)
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rang.offset_left = _d(28)
	rang.offset_right = -_d(28)
	b.add_child(rang)
	var libelle := _texte("VALIDER LE RÉSULTAT", 22, Charte.PANNEAU, Charte.TITRE_EXTRA)
	libelle.name = "ApresMatchValiderTexte"
	C.fill(libelle)
	rang.add_child(libelle)
	var filet := ColorRect.new()
	filet.color = Color(Charte.PANNEAU, 0.35)
	filet.custom_minimum_size = Vector2(1, _d(24))
	filet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(filet)
	rang.add_child(_texte("Espace", 13, Charte.PANNEAU))
	b.pressed.connect(valider)
	bouton_valider = b
	col.add_child(b)
	return col

## Navigation au clavier en cours (dernière entrée : une touche), pour le cadre de focus du bouton or.
var clavier := false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var avant := clavier
	if event is InputEventKey and event.pressed: clavier = true
	elif event is InputEventMouseButton and event.pressed: clavier = false
	if avant != clavier: _maj_focus_clavier()

func _maj_focus_clavier() -> void:
	if not is_instance_valid(bouton_valider): return
	var cadre_focus := bouton_valider.get_node_or_null("ApresMatchValiderFocus") as Control
	if cadre_focus != null: cadre_focus.visible = clavier and bouton_valider.has_focus()

func valider() -> void:
	if director != null and director.has_method("command"): director.command("finish_round")

# --- Sous-page « Voir plus » ---------------------------------------------------------------------------

func _sous_page(parent: VBoxContainer) -> void:
	var titre := _h(16)
	parent.add_child(titre)
	var t := _texte("LE MATCH EN DÉTAIL", 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	t.name = "ApresMatchDetailTitre"
	titre.add_child(t)
	var retour := _lien("← Retour au pourquoi", {"kind": "detail", "ouvert": false}, 15, true)
	retour.name = "ApresMatchRetour"
	retour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.add_child(retour)
	var rang := _h(12)
	rang.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(rang)
	# Statistiques comparées du moteur.
	var stats := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(stats, true)
	rang.add_child(stats)
	var col_stats := _v(2)
	stats.add_child(col_stats)
	col_stats.add_child(_texte("STATISTIQUES", 12, Charte.IVOIRE_2, Charte.TITRE))
	var equipes: Array = _live().get("teams", [])
	var entete := _h(6)
	entete.add_child(C.fill(_texte("", 12)))
	for cote in 2: entete.add_child(_cellule_stat(G.club_abbr(equipes[cote]) if cote < equipes.size() and equipes[cote] is Dictionary else "", Charte.IVOIRE_2))
	col_stats.add_child(entete)
	for s: Variant in _live().get("statsRows", []):
		if not s is Dictionary: continue
		var ligne := _h(6)
		var libelle := _texte(str(s.get("label", "")), 13, Charte.IVOIRE_2)
		C.fill(libelle)
		ligne.add_child(libelle)
		ligne.add_child(_cellule_stat(str(s.get("home", ""))))
		ligne.add_child(_cellule_stat(str(s.get("away", ""))))
		col_stats.add_child(ligne)
	# Notes de ton XV.
	var notes := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(notes, true)
	rang.add_child(notes)
	var col_notes := _v(2)
	notes.add_child(col_notes)
	col_notes.add_child(_texte("NOTES DE TON XV", 12, Charte.IVOIRE_2, Charte.TITRE))
	var lignes: Array = []
	var donnees: Variant = _direct().get("notes")
	if donnees is Dictionary:
		for id: Variant in donnees:
			var n: Variant = donnees[id]
			if n is Dictionary and int(n.get("cote", _camp())) == _camp() and _dans_effectif(str(id)): lignes.append([str(id), float(n.get("note", 0.0))])
	lignes.sort_custom(func(a: Array, b: Array): return a[1] > b[1])
	for l: Array in lignes:
		var ligne := _h(6)
		var nom := ""
		for p: Variant in model.get("squad", []):
			if p is Dictionary and str(p.get("id", "")) == l[0]: nom = str(p.get("name", ""))
		var lien := _lien_joueur(l[0], nom, _camp(), 13)
		C.fill(lien)
		ligne.add_child(lien)
		ligne.add_child(_cellule_stat(note_texte(l[1])))
		col_notes.add_child(ligne)
	if lignes.is_empty(): col_notes.add_child(_texte("Notes indisponibles pour ce match.", 13, Charte.IVOIRE_2))
	# Journal complet.
	var journal := _panneau(Charte.PANNEAU, 16, 10)
	C.fill(journal, true, 1.4)
	rang.add_child(journal)
	var col_journal := _v(4)
	journal.add_child(col_journal)
	col_journal.add_child(_texte("JOURNAL DU MATCH", 12, Charte.IVOIRE_2, Charte.TITRE))
	var defile := ScrollContainer.new()
	defile.name = "ApresMatchJournal"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_journal.add_child(defile)
	var lignes_journal := _v(2)
	C.fill(lignes_journal)
	defile.add_child(lignes_journal)
	for ev: Variant in _live().get("events", []):
		var texte := ("%s′  %s" % [str(ev.get("min", "")), str(ev.get("text", ""))]) if ev is Dictionary else str(ev)
		lignes_journal.add_child(_texte(texte, 13, Charte.IVOIRE, Charte.TEXTE, true))

func _cellule_stat(texte: String, couleur: Color = Charte.IVOIRE) -> Label:
	var l := _texte(texte, 13, couleur, Charte.TITRE_GRAS)
	l.custom_minimum_size.x = _d(56)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l
