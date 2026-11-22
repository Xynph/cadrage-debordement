extends RefCounted
## Supporters en camembert et plan des dirigeants sur 5 ans (revue FM27, idée n° 15 ; planche A/B du 22/11/2026).
## Club › Direction › Supporters : types de supporters (part de la foule prévue), leurs attentes avec une barre
## d'importance et leur réaction en pastille. Projet sportif : plan sur 5 saisons (saison en cours = jalons réels).
## Option A (`CD_VARIANTE_VISUELLE=A`) : camembert plein + légende, tableau des attentes ; plan en onglets par saison.
## Option B : anneau avec l'humeur au centre + un tableau par groupe (part, attente, importance, réaction) ; plan en
## tableau objectifs × saisons. Données : `clubStrategy.fans.supporters` et `clubStrategy.board.plan` (moteur,
## club-strategy.cjs), lecture seule. Chaque ligne, tranche ou cellule ouvre l'écran pertinent ou une petite fenêtre.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const LienZone = preload("res://ui/lien_zone.gd")

const COULEURS := {"abonnes": Charte.MORAL, "familles": Charte.CONDITION, "amateurs": Charte.REPOS, "connectes": Charte.CONFIANCE,
	"partenaires": Charte.INTENSIF, "occasionnels": Charte.GRIS_VERT}
const ICONES := {"resultats": "trophy", "classement": "rating", "prix": "money", "proximite": "home", "formation": "school", "image": "globe", "accueil": "star"}
const IMPORTANCE := ["", "Secondaire", "Souhaitée", "Importante", "Indispensable"]
const PLAN_ICONES := {"rank": "trophy", "wins": "trophy", "points": "rating", "cash": "money", "youth": "school"}
const PLAN_STATUTS := {"pending": ["À suivre", "clock", Charte.GRIS_VERT], "met": ["Atteint", "check", Charte.CONDITION], "missed": ["Manqué", "warning", Charte.PERTE],
	"unverified": ["Non vérifiable", "info", Charte.GRIS_VERT], "future": ["À venir", "hourglass", Charte.IVOIRE_3]}

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

static func couleur(id: String) -> Color:
	return COULEURS.get(id, Charte.IVOIRE_2)

## Réaction d'un groupe (sur 100, null = pas encore de quoi juger) : [mot, couleur, icône].
static func reaction(valeur: Variant) -> Array:
	if not (valeur is int or valeur is float): return ["En attente", Charte.GRIS_VERT, "hourglass"]
	var v := float(valeur)
	if v >= 85: return ["Ravis", Charte.NOTE_EXCELLENTE, "heart"]
	if v >= 70: return ["Très contents", Charte.CONDITION, "check"]
	if v >= 55: return ["Contents", Charte.ATTRIBUT_55, "check"]
	if v >= 40: return ["Partagés", Charte.INTENSIF, "warning"]
	return ["Déçus", Charte.PERTE, "warning"]

static func pastille_reaction(valeur: Variant) -> Control:
	var r := reaction(valeur)
	return Tuile.pastille(r[0], r[1], r[2])

# --- Formes ------------------------------------------------------------------------------------------------------------

## Camembert (plein) ou anneau : une tranche par groupe, dans sa couleur ; survol = tranche décollée ; clic = `choisir`.
## `tranches` : [{id, share, label}]. `centre` (anneau) : chiffre et mot écrits au milieu.
class Camembert extends Control:
	var tranches: Array = []
	var anneau := false
	var choisie := -1
	var survolee := -1
	var centre_haut := ""
	var centre_bas := ""
	var couleur_centre := Charte.IVOIRE
	var choisir: Callable = Callable()
	func _init(liste: Array = [], diametre: float = 260.0, en_anneau: bool = false) -> void:
		tranches = liste
		anneau = en_anneau
		custom_minimum_size = Vector2(C.px(diametre), C.px(diametre))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _rayon() -> float: return minf(size.x, size.y) / 2.0 - C.px(10)
	func _index(point: Vector2) -> int:
		var centre := size / 2.0
		var d := point.distance_to(centre)
		if d > _rayon() + C.px(8) or (anneau and d < _rayon() * .58): return -1
		var angle := fposmod(atan2(point.y - centre.y, point.x - centre.x) + PI / 2.0, TAU)
		var debut := 0.0
		for i in tranches.size():
			var fin := debut + TAU * float(tranches[i].share) / 100.0
			if angle >= debut and angle < fin: return i
			debut = fin
		return -1
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var i := _index(event.position)
			if i != survolee:
				survolee = i
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i >= 0 and choisir.is_valid() else Control.CURSOR_ARROW
				tooltip_text = "" if i < 0 else "%s · %d %%" % [tranches[i].label, int(tranches[i].share)]
				queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var i := _index(event.position)
			if i >= 0 and choisir.is_valid():
				accept_event()
				choisir.call(i)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and survolee != -1:
			survolee = -1
			queue_redraw()
	## Centre de la tranche `index` (tests : clic réel sur une tranche).
	func centre_tranche(index: int) -> Vector2:
		var debut := 0.0
		for i in index: debut += TAU * float(tranches[i].share) / 100.0
		var milieu := debut + TAU * float(tranches[index].share) / 200.0 - PI / 2.0
		var r := _rayon() * (.8 if anneau else .6)
		return size / 2.0 + Vector2(cos(milieu), sin(milieu)) * r
	func _draw() -> void:
		var centre := size / 2.0
		var rayon := _rayon()
		var interieur := rayon * .58 if anneau else 0.0
		var debut := -PI / 2.0
		for i in tranches.size():
			var part := float(tranches[i].share) / 100.0
			if part <= 0: continue
			var fin := debut + TAU * part
			var decale := Vector2.ZERO
			var milieu := (debut + fin) / 2.0
			if i == survolee or i == choisie: decale = Vector2(cos(milieu), sin(milieu)) * C.px(7)
			var points := PackedVector2Array()
			var pas := maxi(3, int(48 * part))
			for k in pas + 1:
				var a := debut + (fin - debut) * k / pas
				points.append(centre + decale + Vector2(cos(a), sin(a)) * rayon)
			if anneau:
				for k in range(pas, -1, -1):
					var a := debut + (fin - debut) * k / pas
					points.append(centre + decale + Vector2(cos(a), sin(a)) * interieur)
			else:
				points.append(centre + decale)
			var teinte: Color = COULEURS.get(str(tranches[i].id), Charte.IVOIRE_2)
			if choisie >= 0 and i != choisie: teinte = teinte.darkened(.45)
			draw_colored_polygon(points, teinte.lightened(.12) if i == survolee else teinte)
			# Filet sombre entre les tranches : lisible sans dépendre de la seule couleur.
			draw_line(centre + decale + Vector2(cos(debut), sin(debut)) * interieur, centre + decale + Vector2(cos(debut), sin(debut)) * rayon, Charte.PANNEAU, C.px(3), true)
			debut = fin
		if anneau and not centre_haut.is_empty():
			var police: Font = Charte.TITRE_FICHE
			draw_string(police, centre + Vector2(-interieur, C.px(14)), centre_haut, HORIZONTAL_ALIGNMENT_CENTER, interieur * 2.0, C.font_px(56), couleur_centre)
			draw_string(C.BOLD, centre + Vector2(-interieur, C.px(48)), centre_bas, HORIZONTAL_ALIGNMENT_CENTER, interieur * 2.0, C.font_px(19), Charte.IVOIRE_2)

## Barre d'importance : 4 crans violets, le mot écrit à côté (jamais la couleur seule).
class Importance extends Control:
	var niveau := 0
	func _init(valeur: int = 0, largeur: float = 120.0) -> void:
		niveau = clampi(valeur, 0, 4)
		custom_minimum_size = Vector2(C.px(largeur), C.px(10))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ecart := C.px(5)
		var largeur := (size.x - ecart * 3) / 4.0
		for i in 4:
			var zone := Rect2(i * (largeur + ecart), 0, largeur, size.y)
			draw_rect(zone, Charte.CONFIANCE if i < niveau else Charte.PANNEAU_3)

static func importance(niveau: int, largeur: float = 120.0) -> VBoxContainer:
	var bloc := C.v(4)
	bloc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(C.label(IMPORTANCE[clampi(niveau, 0, 4)], 17, Charte.IVOIRE_2, true, 600))
	bloc.add_child(Importance.new(niveau, largeur))
	return bloc

## Pastille carrée de la couleur d'un groupe.
static func carre(id: String, cote: float = 18.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", C.box(couleur(id), Color.TRANSPARENT, 4, 0))
	return p

# --- Lignes (grammaire de l'Effectif : colonnes, survol, clic) -----------------------------------------------------------

## Ligne cliquable : survol éclairé, focus clavier ; `cellules` : [[Control, largeur px (0 = s'étire)]].
static func ligne(nom: String, cellules: Array, action: Callable, hauteur: float = 58.0) -> Button:
	var rangee := Button.new()
	rangee.name = nom
	Kit.styler_ligne(rangee, Color.TRANSPARENT)
	rangee.custom_minimum_size.y = C.px(hauteur)
	rangee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rangee.pressed.connect(action)
	var contenu := C.h(16)
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenu.offset_left = C.px(12)
	contenu.offset_right = -C.px(12)
	rangee.add_child(contenu)
	for cellule: Array in cellules:
		var boite := HBoxContainer.new()
		boite.add_theme_constant_override("separation", C.px(10))
		boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.alignment = BoxContainer.ALIGNMENT_BEGIN
		if float(cellule[1]) <= 0: boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: boite.custom_minimum_size.x = C.px(float(cellule[1]))
		var controle: Control = cellule[0]
		controle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if controle is BoxContainer or controle is Label: controle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ignorer(controle)
		boite.add_child(controle)
		contenu.add_child(boite)
	Tuile.proteger(rangee)
	return rangee

static func _ignorer(controle: Control) -> void:
	controle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for enfant in controle.find_children("*", "Control", true, false): (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

## En-tête de colonnes (texte faible, capitales).
static func entete(colonnes: Array) -> HBoxContainer:
	var tete := C.h(16)
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for colonne: Array in colonnes:
		var etiquette := C.label(str(colonne[0]).to_upper(), 16, Charte.IVOIRE_3, true, 700)
		if float(colonne[1]) <= 0: etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: etiquette.custom_minimum_size.x = C.px(float(colonne[1]))
		tete.add_child(etiquette)
	var cadre := MarginContainer.new()
	cadre.add_theme_constant_override("margin_left", C.px(12))
	cadre.add_theme_constant_override("margin_right", C.px(12))
	cadre.add_child(tete)
	var h := C.h(0)
	h.add_child(cadre)
	C.fill(cadre)
	return h

static func _texte(valeur: String, taille: int = 22, couleur_texte: Color = Charte.IVOIRE, poids: int = 600) -> Label:
	var l := C.label(valeur, taille, couleur_texte, true, poids)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# --- Supporters --------------------------------------------------------------------------------------------------------

static func _segment(data: Dictionary, id: String) -> Dictionary:
	for s: Dictionary in data.get("segments", []):
		if str(s.id) == id: return s
	return {}

static func _attente(data: Dictionary, id: String) -> Dictionary:
	for e: Dictionary in data.get("expectations", []):
		if str(e.segment) == id: return e
	return {}

## Destination d'une attente : l'écran qui la juge, sinon la petite fenêtre de son groupe.
static func _ouvrir_attente(app: Control, data: Dictionary, attente: Dictionary, public: Callable) -> void:
	match str(attente.get("kind", "")):
		"resultats": app._navigate("Calendrier")
		"classement": app._navigate("Classements")
		"formation": app._navigate("Centre")
		"prix": public.call()
		_: fenetre_groupe(app, data, str(attente.get("segment", "")))

## Petite fenêtre d'un groupe : camembert avec sa tranche, part, nombre, attente (importance) et réaction.
static func fenetre_groupe(app: Control, data: Dictionary, id: String) -> void:
	var segments: Array = data.get("segments", [])
	var index := -1
	for i in segments.size():
		if str(segments[i].id) == id: index = i
	if index < 0: return
	var seg: Dictionary = segments[index]
	var att := _attente(data, id)
	var pie := Camembert.new(segments, 220, variante() == "B")
	pie.choisie = index
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var part := Visuel.tuile_chiffre("people", "%d %%" % int(seg.share), "Part du public")
	var nombre := Visuel.tuile_chiffre("home", G.n(seg.count), "Spectateurs par match")
	var haut := Visuel.rangee([pie, part, nombre])
	var attente_ligne := C.h(18)
	attente_ligne.add_child(C.icon(ICONES.get(str(att.get("kind", "")), "target"), 34, couleur(id)))
	var titre := _texte(str(att.get("label", "—")), 26, Charte.IVOIRE, 700)
	C.fill(titre)
	attente_ligne.add_child(titre)
	attente_ligne.add_child(importance(int(att.get("importance", 0)), 150))
	attente_ligne.add_child(pastille_reaction(att.get("reaction")))
	Visuel.petite_fenetre(app, "SupportersFenetreGroupe", str(seg.label), [haut, attente_ligne])

## Onglet Supporters, option A : camembert plein + légende chiffrée, puis tableau des attentes.
static func supporters_a(app: Control, page: Container, data: Dictionary, public: Callable) -> void:
	var segments: Array = data.get("segments", [])
	if segments.is_empty(): return
	var carte := G.panel(page)
	carte.name = "SupportersProfil"
	var tete := C.h(14)
	carte.add_child(tete)
	var titre := Tuile.titre_bloc("Profil des supporters")
	C.fill(titre)
	tete.add_child(titre)
	tete.add_child(_petit_chiffre("people", G.n(data.get("crowd", 0)), "SPECTATEURS PAR MATCH"))
	var corps := C.h(36)
	carte.add_child(corps)
	var pie := Camembert.new(segments, 300, false)
	pie.name = "SupportersCamembert"
	pie.choisir = func(i: int): fenetre_groupe(app, data, str(segments[i].id))
	corps.add_child(pie)
	var legende := C.v(2)
	legende.custom_minimum_size.x = C.px(820)
	legende.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corps.add_child(legende)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(vide)
	var mood: Variant = data.get("mood")
	var anneau := JaugeAnneau.new(float(mood) if mood != null else 0.0, "Humeur", reaction(mood)[1], 100.0, "heart")
	anneau.name = "SupportersHumeurAnneau"
	anneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var colonne := C.v(10)
	colonne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_child(anneau)
	var mot := pastille_reaction(mood)
	mot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	colonne.add_child(mot)
	corps.add_child(colonne)
	LienZone.relier(anneau, "SupportersLien_Humeur", "Le public", public)
	for s: Dictionary in segments:
		var id := str(s.id)
		legende.add_child(ligne("SupportersType_" + id, [[carre(id), 22], [_texte("%d %%" % int(s.share), 26, couleur(id), 700), 70], [_texte(str(s.label), 22), 0], [_texte(G.n(s.count), 22, Charte.IVOIRE_2), 110]], func(): fenetre_groupe(app, data, id), 46))
	# Attentes : une ligne par groupe, colonnes Attente / Importance / Groupe / Réaction.
	var attentes := G.panel(page)
	attentes.name = "SupportersAttentes"
	var tete2 := C.h(14)
	attentes.add_child(tete2)
	var titre2 := Tuile.titre_bloc("Culture et attentes")
	C.fill(titre2)
	tete2.add_child(titre2)
	var humeur := pastille_reaction(data.get("mood"))
	humeur.name = "SupportersHumeur"
	tete2.add_child(humeur)
	attentes.add_child(entete([["Attente", 0], ["Importance", 190], ["Groupe", 330], ["Réaction", 190]]))
	for e: Dictionary in data.get("expectations", []):
		var id := str(e.segment)
		var seg := _segment(data, id)
		var nom := C.h(12)
		nom.add_child(C.icon(ICONES.get(str(e.kind), "target"), 26, couleur(id)))
		nom.add_child(_texte(str(e.label), 22))
		var groupe := C.h(10)
		groupe.add_child(carre(id, 14))
		groupe.add_child(_texte(str(seg.get("label", "")), 19, Charte.IVOIRE_2))
		attentes.add_child(ligne("SupportersAttente_" + id, [[nom, 0], [importance(int(e.importance), 150), 190], [groupe, 330], [pastille_reaction(e.get("reaction")), 190]], func(): _ouvrir_attente(app, data, e, public)))

## Onglet Supporters, option B : anneau (humeur au centre) et un tableau par groupe qui réunit part, attente,
## importance et réaction.
static func supporters_b(app: Control, page: Container, data: Dictionary, public: Callable) -> void:
	var segments: Array = data.get("segments", [])
	if segments.is_empty(): return
	var carte := G.panel(page)
	carte.name = "SupportersTribunes"
	var tete := C.h(14)
	carte.add_child(tete)
	var titre := Tuile.titre_bloc("Les tribunes")
	C.fill(titre)
	tete.add_child(titre)
	tete.add_child(_petit_chiffre("people", G.n(data.get("crowd", 0)), "SPECTATEURS PAR MATCH"))
	var corps := C.h(36)
	carte.add_child(corps)
	var pie := Camembert.new(segments, 330, true)
	pie.name = "SupportersAnneau"
	var r := reaction(data.get("mood"))
	pie.centre_haut = "—" if data.get("mood") == null else str(int(data.mood))
	pie.centre_bas = str(r[0]).to_upper()
	pie.couleur_centre = r[1]
	pie.choisir = func(i: int): fenetre_groupe(app, data, str(segments[i].id))
	corps.add_child(pie)
	var tableau := C.v(2)
	tableau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tableau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corps.add_child(tableau)
	tableau.add_child(entete([["Groupe", 0], ["Part", 200], ["Attente", 380], ["Importance", 170], ["Réaction", 180]]))
	for s: Dictionary in segments:
		var id := str(s.id)
		var e := _attente(data, id)
		var nom := C.h(10)
		nom.add_child(carre(id))
		nom.add_child(_texte(str(s.label), 22))
		var part := C.h(10)
		var barre := _BarrePart.new(float(s.share), couleur(id))
		part.add_child(barre)
		part.add_child(_texte("%d %%" % int(s.share), 22, couleur(id), 700))
		var attente := C.h(10)
		attente.add_child(C.icon(ICONES.get(str(e.get("kind", "")), "target"), 24, Charte.IVOIRE_2))
		attente.add_child(_texte(str(e.get("label", "—")), 19, Charte.IVOIRE))
		tableau.add_child(ligne("SupportersGroupe_" + id, [[nom, 0], [part, 200], [attente, 380], [importance(int(e.get("importance", 0)), 130), 170], [pastille_reaction(e.get("reaction")), 180]], func(): fenetre_groupe(app, data, id), 60))

## Barre horizontale de la part d'un groupe (rail sombre, remplissage de la couleur du groupe).
class _BarrePart extends Control:
	var part := 0.0
	var teinte := Charte.IVOIRE
	func _init(valeur: float = 0.0, couleur_barre: Color = Charte.IVOIRE) -> void:
		part = clampf(valeur / 100.0, 0.0, 1.0)
		teinte = couleur_barre
		custom_minimum_size = Vector2(C.px(110), C.px(12))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Charte.PANNEAU_3)
		draw_rect(Rect2(0, 0, size.x * part, size.y), teinte)

static func _petit_chiffre(icone: String, valeur: String, legende: String) -> HBoxContainer:
	var l := C.h(10)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_child(Visuel.picto(icone, 30, Visuel.teinte(icone)))
	l.add_child(C.label(valeur, 30, Charte.IVOIRE, true, 700))
	l.add_child(C.label(legende, 16, Charte.IVOIRE_2, true, 600))
	return l

# --- Plan des dirigeants sur 5 ans ------------------------------------------------------------------------------------

static func _objectif_texte(o: Dictionary) -> String:
	match str(o.get("label", "")):
		"rank": return "Classement ≤ %s" % G.n(o.target)
		"wins": return "Victoires ≥ %s" % G.n(o.target)
		"points": return "Points ≥ %s" % G.n(o.target)
		"cash": return "Trésorerie positive" if float(o.get("target", 0)) <= 0 else "Trésorerie ≥ " + G.euros(o.target)
		"youth": return "Lancer un jeune du centre"
	return str(o.get("label", ""))

static func _objectif_court(o: Dictionary) -> String:
	match str(o.get("label", "")):
		"rank": return "≤ %s" % G.n(o.target)
		"wins", "points": return "≥ %s" % G.n(o.target)
		"cash": return "≥ 0 €" if float(o.get("target", 0)) <= 0 else "≥ " + G.euros(o.target)
		"youth": return "%s jeune" % G.n(o.target)
	return "—"

static func _ouvrir_objectif(app: Control, o: Dictionary) -> void:
	match str(o.get("label", "")):
		"cash": app._navigate("Finances")
		"youth": app._navigate("Centre")
		_: app._navigate("Classements")

static func _statut(o: Dictionary) -> Control:
	var s: Array = PLAN_STATUTS.get(str(o.get("status", "")), ["—", "info", Charte.GRIS_VERT])
	return Tuile.pastille(s[0], s[2], s[1])

static func _saison(saison: Dictionary) -> String:
	return "Saison actuelle" if saison.get("current", false) else G.season_label(saison.season)

## Option A : onglets par saison (pilules), une liste Objectif / Importance / Évaluation par saison.
static func plan_a(app: Control, parent: Container, plan: Array) -> void:
	var bloc := C.v(10)
	bloc.name = "PlanCinqAns"
	parent.add_child(bloc)
	var onglets := C.h(10)
	bloc.add_child(onglets)
	var pages: Array = []
	var boutons: Array = []
	for i in plan.size():
		var saison: Dictionary = plan[i]
		var liste := C.v(2)
		liste.name = "PlanSaison%d" % i
		liste.visible = i == 0
		liste.add_child(entete([["Objectif", 0], ["Importance", 200], ["Évaluation", 200]]))
		for j in (saison.get("objectives", []) as Array).size():
			var o: Dictionary = saison.objectives[j]
			var nom := C.h(12)
			nom.add_child(C.icon(PLAN_ICONES.get(str(o.label), "target"), 26, Charte.CONFIANCE))
			nom.add_child(_texte(_objectif_texte(o), 22))
			liste.add_child(ligne("PlanObjectif_%d_%d" % [i, j], [[nom, 0], [importance(int(o.get("importance", 0)), 150), 200], [_statut(o), 200]], func(): _ouvrir_objectif(app, o)))
		pages.append(liste)
		bloc.add_child(liste)
	for i in plan.size():
		var bouton := Tuile.pilule(_saison(plan[i]), "PlanOnglet%d" % i, true, "", func():
			for k in pages.size(): (pages[k] as Control).visible = k == i
			for k in boutons.size(): _onglet_style(boutons[k], k == i))
		boutons.append(bouton)
		onglets.add_child(bouton)
	for k in boutons.size(): _onglet_style(boutons[k], k == 0)

static func _onglet_style(bouton: Button, actif: bool) -> void:
	var fond := Charte.IVOIRE if actif else Color.TRANSPARENT
	var style := C.box(fond, Color.TRANSPARENT if actif else Charte.FILET, Charte.RAYON_PILULE, 18)
	for etat in ["normal", "hover", "pressed", "focus"]: bouton.add_theme_stylebox_override(etat, style)
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(cle, Charte.PANNEAU if actif else Charte.IVOIRE)

## Option B : tableau objectifs × saisons, toutes les saisons visibles d'un coup ; chaque cellule ouvre l'écran qui juge
## l'objectif.
static func plan_b(app: Control, parent: Container, plan: Array) -> void:
	var bloc := C.v(2)
	bloc.name = "PlanCinqAns"
	parent.add_child(bloc)
	var genres: Array = []
	for saison: Dictionary in plan:
		for o: Dictionary in saison.get("objectives", []):
			if not genres.has(str(o.label)): genres.append(str(o.label))
	var colonnes: Array = [["Objectif", 0], ["Importance", 170]]
	for saison: Dictionary in plan: colonnes.append([_saison(saison), 190])
	bloc.add_child(entete(colonnes))
	for genre: String in genres:
		var exemple: Dictionary = {}
		var cellules: Array = []
		for saison: Dictionary in plan:
			var trouve: Dictionary = {}
			for o: Dictionary in saison.get("objectives", []):
				if str(o.label) == genre: trouve = o
			if exemple.is_empty() and not trouve.is_empty(): exemple = trouve
			var cellule := C.h(8)
			if trouve.is_empty():
				cellule.add_child(_texte("—", 22, Charte.IVOIRE_3))
			else:
				var s: Array = PLAN_STATUTS.get(str(trouve.get("status", "")), ["—", "info", Charte.GRIS_VERT])
				cellule.add_child(C.icon(s[1], 20, s[2]))
				cellule.add_child(_texte(_objectif_court(trouve), 24, Charte.IVOIRE if saison.get("current", false) else Charte.IVOIRE_2, 700))
			cellules.append([cellule, 190])
		var nom := C.h(12)
		nom.add_child(C.icon(PLAN_ICONES.get(genre, "target"), 26, Charte.CONFIANCE))
		nom.add_child(_texte(_objectif_texte(exemple).replace(" ≤ " + G.n(exemple.get("target", "")), "").replace(" ≥ " + G.n(exemple.get("target", "")), ""), 22))
		var rangee: Array = [[nom, 0], [importance(int(exemple.get("importance", 0)), 130), 170]]
		rangee.append_array(cellules)
		bloc.add_child(ligne("PlanObjectif_" + genre, rangee, func(): _ouvrir_objectif(app, exemple), 62))
