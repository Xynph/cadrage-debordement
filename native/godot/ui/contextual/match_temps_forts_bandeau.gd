extends "res://ui/contextual/match_temps_forts_etat.gd"
## Régie des temps forts : bandeau des grands moments (cadre, animation, placement), consigne bonus.

func _calme() -> bool:
	var preferences: Variant = app.get("user_preferences") if is_instance_valid(app) else null
	return preferences != null and bool(preferences.data.get("reduced_motion", false))

# --- Ralenti de l'essai ------------------------------------------------------

## Cadre de la bannière (charte finale §3, §4.3) : rayon 18, sans bordure, ombre portée de la charte ; pour un essai, aplat plein à la
## couleur du club qui marque (exception de Léo du 20/11/2026) ; mi-temps et fin : panneau `PANNEAU` à 90 %.
## Nom historique gardé (les recettes et le match filmé le lisent) : le cadre est droit.
class CadreIncline extends PanelContainer:
	var fond := Charte.PANNEAU
	func _draw() -> void:
		draw_style_box(Charte.style_panneau(Color(fond, 0.9 if fond == Charte.PANNEAU else 1.0), Charte.RAYON_PANNEAU, 0), Rect2(Vector2.ZERO, size))

## Bannière des grands moments, façon retransmission (charte finale §7) : « ESSAI » en aplat à la couleur du club
## qui marque (exception de Léo du 20/11/2026), filet, le marqueur et « club · minute », puis les points et le score à droite ;
## « MI-TEMPS » et « FIN DU MATCH » sur panneau. Une seule bannière à la fois, texte crème, aucun
## aplat doré. Ne capte jamais la souris.
static func construire_bandeau() -> PanelContainer:
	var cadre := CadreIncline.new()
	cadre.name = "MatchMomentBandeau"
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxEmpty.new()
	fond.content_margin_left = 20
	fond.content_margin_right = 30
	fond.content_margin_top = 6
	fond.content_margin_bottom = 8
	cadre.add_theme_stylebox_override("panel", fond)
	var ligne := HBoxContainer.new()
	ligne.name = "MatchMomentLigne"
	ligne.alignment = BoxContainer.ALIGNMENT_BEGIN
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", 18)
	cadre.add_child(ligne)
	var titre := S.label("", 36, Charte.IVOIRE)
	titre.name = "MatchMomentTitre"
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA)
	titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(titre)
	var filet := ColorRect.new()
	filet.name = "MatchMomentFilet"
	filet.color = Charte.FILET
	filet.custom_minimum_size = Vector2(1, 0)
	filet.size_flags_vertical = Control.SIZE_FILL
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(filet)
	var texte := VBoxContainer.new()
	texte.name = "MatchMomentTexte"
	texte.alignment = BoxContainer.ALIGNMENT_CENTER
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.add_theme_constant_override("separation", 0)
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(texte)
	var nom := S.label("", 22, Charte.IVOIRE)
	nom.name = "MatchMomentNom"
	nom.add_theme_font_override("font", Charte.TITRE)
	var equipe := S.label("", 16, Charte.IVOIRE)
	equipe.name = "MatchMomentEquipe"
	equipe.add_theme_font_override("font", Charte.texte_moyen())
	for l: Label in [nom, equipe]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texte.add_child(l)
	# Points marqués et score (« +5 », « 15 – 7 ») : deux lignes calées à droite.
	var points := S.label("", 22, Charte.IVOIRE)
	points.name = "MatchMomentPoints"
	points.add_theme_font_override("font", Charte.TITRE_EXTRA)
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points.hide()
	ligne.add_child(points)
	cadre.hide()
	return cadre

## Tailles de police du bandeau pour une image de `hauteur` pixels (maquette 1080p : 48, 26, 20 ; lisible
## en 720p, sans excès en 1440p).
static func tailles_bandeau(hauteur: float) -> Dictionary:
	return {"titre": clampi(roundi(hauteur * 0.045), 30, 72), "nom": clampi(roundi(hauteur * 0.024), 18, 40), "equipe": clampi(roundi(hauteur * 0.0185), 14, 30)}

## Fond de la bannière : le panneau, sauf pour un essai (exception de Léo du 20/11/2026, art-bible §4.3).
static func fond_bandeau(couleur: Color = Color.TRANSPARENT) -> Color:
	# Essai : la couleur du club qui marque, assombrie pour la crème (≥ 4,6:1) ; un club jaune ou or ne prend
	# jamais l'or (il passe au bordeaux de la charte).
	if couleur.a <= 0.0: return Charte.PANNEAU
	var base := Charte.CLUB if Charte._proche_de_l_or(couleur) else Color(couleur, 1.0)
	return C08.readable_primary_fill(base)

static func habiller_bandeau(cadre: PanelContainer, titre: String, nom: String, equipe: String, hauteur: float, couleur: Color = Color.TRANSPARENT, points: String = "") -> void:
	var tailles := tailles_bandeau(hauteur)
	var lignes := {"MatchMomentTitre": [titre, tailles.titre], "MatchMomentNom": [nom, tailles.nom], "MatchMomentEquipe": [equipe, tailles.equipe],
		"MatchMomentPoints": [points, tailles.nom]}
	for nom_ligne: String in lignes:
		var ligne: Label = cadre.find_child(nom_ligne, true, false)
		if ligne == null: continue
		ligne.text = str(lignes[nom_ligne][0])
		ligne.add_theme_font_size_override("font_size", int(lignes[nom_ligne][1]))
		ligne.visible = not ligne.text.is_empty()
	var texte: Control = cadre.find_child("MatchMomentTexte", true, false)
	var filet: Control = cadre.find_child("MatchMomentFilet", true, false)
	var reste := not (nom.is_empty() and equipe.is_empty())
	if texte != null: texte.visible = reste
	if filet != null: filet.visible = reste
	if cadre is CadreIncline:
		(cadre as CadreIncline).fond = fond_bandeau(couleur)
		cadre.queue_redraw()
	var marges: StyleBox = cadre.get_theme_stylebox("panel")
	if marges != null:
		marges.content_margin_left = roundi(hauteur * 0.0185)
		marges.content_margin_right = roundi(hauteur * 0.0222)
	cadre.reset_size()

## Ce que montre le bandeau (tests, capture) : {visible, titre, nom, equipe, points, fond}.
func bandeau_affiche() -> Dictionary:
	if bandeau == null: return {"visible": false}
	var lire := func(n: String) -> String:
		var ligne: Label = bandeau.find_child(n, true, false)
		return ligne.text if ligne != null and ligne.visible else ""
	return {"visible": bandeau.visible, "titre": lire.call("MatchMomentTitre"), "nom": lire.call("MatchMomentNom"), "equipe": lire.call("MatchMomentEquipe"),
		"points": lire.call("MatchMomentPoints"), "fond": (bandeau as CadreIncline).fond if bandeau is CadreIncline else Color.TRANSPARENT}

func montrer_bandeau(titre: String, nom: String, equipe: String, duree: float, couleur: Color = Color.TRANSPARENT, points: String = "") -> void:
	if bandeau == null or view == null: return
	habiller_bandeau(bandeau, titre, nom, equipe, maxf(1.0, view.size.y), couleur, points)
	# Marqueur qui est l'un de nos joueurs : nom souligné, mini-fiche au survol, fiche complète au clic (live_view).
	if view.has_method("lier_nom_bandeau"): view.lier_nom_bandeau(bandeau.find_child("MatchMomentNom", true, false), nom if titre == "ESSAI" else "")
	_bandeau_titre = titre
	_bandeau_duree = maxf(duree, BANDEAU_ENTREE + BANDEAU_FONDU)
	_bandeau_reste = _bandeau_duree
	bandeau.show()
	_placer_bandeau()

## « MI-TEMPS » et « FIN DU MATCH » : sous le bandeau du score et la bande de commandes (zone libre
## de l'image), centré. Sortie des joueurs en plan serré (18/11/2026, nuit) : le tunnel est en haut
## de l'image, sous la tribune ; le bandeau descend dans la pelouse vide du bas (BANDEAU_SORTIE_BAS
## de la hauteur) pour laisser voir les joueurs rentrer.
const BANDEAU_SORTIE_BAS := 0.70

## Place du bandeau (repère de la vue, sans l'animation) pour une image `ecran`, un bandeau `taille`,
## la zone libre qui commence à `haut_libre` (sous le score et les commandes) et la légende `legende`
## (Rect2() si inconnue). « ESSAI » : tiers inférieur, calé à gauche sur la légende, juste au-dessus
## d'elle, comme un bandeau de retransmission (le marqueur et sa célébration restent visibles).
static func place_bandeau(titre: String, ecran: Vector2, taille: Vector2, haut_libre: float, legende: Rect2, sortie_serree: bool) -> Vector2:
	if titre == "ESSAI":
		var marge := roundf(ecran.y * BANDEAU_MARGE)
		var connue := legende.has_area()
		var bas := (legende.position.y if connue else ecran.y * (1.0 - BANDEAU_BAS_REPLI)) - marge
		var gauche := legende.position.x if connue else roundf(ecran.x * 0.015)
		return Vector2(roundf(clampf(gauche, 0.0, maxf(0.0, ecran.x - taille.x))), roundf(maxf(haut_libre + marge, bas - taille.y)))
	var haut := haut_libre + ecran.y * 0.03
	if sortie_serree: haut = maxf(haut, ecran.y * BANDEAU_SORTIE_BAS - taille.y * 0.5)
	return Vector2(roundf((ecran.x - taille.x) * 0.5), roundf(haut))

## Animation du bandeau `ecoule` s après son apparition, `reste` s avant sa fin, dans une image de
## `hauteur` px : {alpha, decalage}. Entrée courte (glissé + fondu), sortie en fondu qui descend un peu.
static func animation_bandeau(titre: String, ecoule: float, reste: float, hauteur: float, calme: bool) -> Dictionary:
	if calme: return {"alpha": 1.0, "decalage": Vector2.ZERO}
	var entree := clampf(ecoule / BANDEAU_ENTREE, 0.0, 1.0)
	var sortie := clampf(reste / BANDEAU_FONDU, 0.0, 1.0)
	var arrivee := 1.0 - pow(1.0 - entree, 3.0)
	var glisse := hauteur * BANDEAU_GLISSE
	var decalage := Vector2(-(1.0 - arrivee) * glisse * 3.0, 0.0) if titre == "ESSAI" else Vector2(0.0, (1.0 - arrivee) * glisse)
	decalage.y += (1.0 - sortie) * glisse * 0.5
	return {"alpha": minf(entree, sortie), "decalage": decalage}

func _placer_bandeau() -> void:
	var hauteur := maxf(1.0, view.size.y)
	var haut: float = (_espace.get_global_rect().position.y if is_instance_valid(_espace) else view.clock.get_global_rect().end.y) - view.get_global_rect().position.y
	var legende: Control = view.events.get_parent().get_parent().get_parent() if is_instance_valid(view.events) else null
	if legende != null and legende.is_visible_in_tree() and legende.size.y > 0.0:
		_legende_rect = Rect2(legende.get_global_rect().position - view.get_global_rect().position, legende.size)
	# « ESSAI » : même largeur que le journal qu'il surmonte (maquette : 744 px en 1080p).
	bandeau.custom_minimum_size.x = _legende_rect.size.x if _bandeau_titre == "ESSAI" and _legende_rect.has_area() else 0.0
	bandeau.reset_size()
	var place := place_bandeau(_bandeau_titre, Vector2(view.size.x, hauteur), bandeau.size, haut, _legende_rect, etat == SORTIE and _sortie_t >= SORTIE_LARGE)
	var anime := animation_bandeau(_bandeau_titre, _bandeau_duree - _bandeau_reste, _bandeau_reste, hauteur, _calme())
	bandeau.modulate.a = float(anime.alpha)
	bandeau.position = (place + (anime.decalage as Vector2)).round()

func _animer_bandeau(delta: float) -> void:
	if bandeau == null or not bandeau.visible: return
	if not gel: _bandeau_reste -= delta
	if _bandeau_reste <= 0.0:
		_cacher_bandeau()
		return
	_placer_bandeau()

func _cacher_bandeau() -> void:
	_bandeau_reste = 0.0
	_bandeau_titre = ""
	if bandeau != null: bandeau.hide()

## Consigne de la tuile Bonus : mêmes commandes que le tiroir Tactique (set_tactics, set_penalty_policy), posées
## pendant une courte pause si le match roule ; la reprise suit d'elle-même.
func appliquer_consigne_bonus(consigne: Dictionary) -> void:
	if _live.is_empty() or _live.get("finished", false) or not _consigne_bonus.is_empty(): return
	if str(consigne.get("attack", "")).is_empty() or str(consigne.get("defense", "")).is_empty() or str(consigne.get("penalty", "")).is_empty(): return
	_consigne_bonus = {"attack": consigne.attack, "defense": consigne.defense, "penalty": consigne.penalty,
		"etape": "pause", "reprendre": not _live.get("paused", false), "essais": 0}

func _suivre_consigne_bonus() -> void:
	if _consigne_bonus.is_empty() or app.waiting: return
	var c := _consigne_bonus
	c.essais = int(c.essais) + 1
	# Garde-fou : une étape qui ne passe pas (refus du moteur, fin du match) abandonne la consigne.
	if int(c.essais) > 600 or _live.get("finished", false):
		_consigne_bonus = {}
		return
	match str(c.etape):
		"pause":
			if _live.get("paused", false): c.etape = "tactique"
			elif app._command("pause", {"paused": true}): c.etape = "attente"
		"attente":
			if _live.get("paused", false): c.etape = "tactique"
		"tactique":
			if app._command("set_tactics", {"attack": c.attack, "defense": c.defense}): c.etape = "penalite"
		"penalite":
			if app._command("set_penalty_policy", {"policy": c.penalty}): c.etape = "reprise"
		"reprise":
			_consigne_bonus = {}
			if c.reprendre and _live.get("paused", false) and arret.is_empty() and not _tiroir: app._command("pause", {"paused": false})
