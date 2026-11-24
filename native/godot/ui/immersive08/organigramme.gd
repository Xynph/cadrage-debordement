extends RefCounted
## Club › Organigramme (idée « Organigramme du club », 24/11/2026). Carte du club en cercles : le président et toi au
## centre, puis le staff réel du club (Staff par service, staff-services.cjs) coloré par service. Survol : le membre
## ressort, les autres s'estompent. Clic : petite fenêtre visuelle (portrait, rôle, compétences ESTIMÉES en crans, jamais
## le chiffre du moteur, et ce qu'il a fait récemment en pastilles). À droite, les services en lignes (style Effectif).
## Mise en page choisie par Léo (option B, 24/11/2026) : un anneau par service, tenu par son responsable, autour du centre.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const StaffServices = preload("res://ui/immersive08/staff_services.gd")
const StaffTable = preload("res://ui/staff_career_view.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")
const EntityLink = preload("res://ui/entity_link.gd")

const W := 2248.0
const CARTE_L := 1580.0
const CENTRE := Vector2(790, 728)
## Services : clé, titre, couleur franche, icône (ordre autour du centre).
const SERVICES := [
	["direction", "Direction", Color("a88bd6"), "shield"],
	["coaching", "Entraîneurs", Color("5b9bd5"), "tactic"],
	["fitness", "Préparation physique", Color("7fbf7a"), "train"],
	["medical", "Médical", Color("d9634f"), "heart"],
	["club", "Recrutement et club", Color("e0a04a"), "search"],
]
const RESPONSABLES := ["director", "assistant", "fitnessLead", "doctor", "scout"]
const MOTS := ["Faible", "Moyen", "Correct", "Bon", "Excellent"]
const SOINS := ["doctor", "physio", "rehab"]
const ZONES := {"forwards": "Avants", "backs": "Arrières", "defence": "Défense"}

static func _service(id: String) -> Array:
	for s: Array in SERVICES:
		if s[0] == id: return s
	return SERVICES[4]

static func _rang_service(id: String) -> int:
	for i in SERVICES.size():
		if SERVICES[i][0] == id: return i
	return SERVICES.size()

# --- Données ---------------------------------------------------------------------------------------------------------

## Direction du club (président, directeur sportif) : la même que la fiche du club et les courriers (moteur
## club-directions.cjs), lue dans la projection Staff par service, déjà là au premier affichage. Aucune lecture
## demandée au moteur : sa réponse reconstruirait la page et fermerait une fenêtre ouverte. La forme récente vient de la
## fiche du club si elle est déjà en mémoire.
static func _fiche(app: Control) -> Dictionary:
	var direction: Variant = StaffServices.projection(app).get("direction", {})
	if not direction is Dictionary: direction = {}
	var fiche := ClubSheet.cached(app, int(app.model.club.id))
	var nom := func(cle: String) -> String:
		var v: Variant = direction.get(cle)
		if v == null or str(v).strip_edges().is_empty(): v = fiche.get(cle)
		return str(v).strip_edges() if v != null else ""
	return {"president": nom.call("president"), "director": nom.call("director"), "table": fiche.get("table") if fiche.get("table") is Dictionary else {}}

static func _billetterie_id(app: Control) -> String:
	var fans: Variant = U.strategy(app.model).get("fans", {})
	var t: Variant = fans.get("ticketing", {}) if fans is Dictionary else {}
	var par: Variant = t.get("estimatedBy") if t is Dictionary else null
	if par is Dictionary and par.get("person") is Dictionary: return str(par.person.get("id", ""))
	return ""

static func _service_du_role(role: String) -> String:
	match role:
		"coach", "assistant": return "coaching"
		"fitness": return "fitness"
		"medical": return "medical"
	return "club"

## Membres de l'organigramme : {p, cle, service, role, rang (1 responsable, 2 équipe), tags}.
static func membres(app: Control) -> Array:
	var out: Array = []
	var fiche := _fiche(app)
	var club_id := int(app.model.club.id)
	var directeur: String = fiche.director
	if not directeur.is_empty():
		out.append({"p": {"id": "ds-%d" % club_id, "name": directeur, "age": 52}, "cle": "director", "service": "direction", "role": "Directeur sportif", "rang": 1, "tags": [], "direction": true})
	var billet := _billetterie_id(app)
	var vus := {}
	var ajouter := func(p: Dictionary, cle: String, service: String, role: String, tags: Array) -> void:
		var id := str(p.get("id", ""))
		if id.is_empty() or vus.has(id): return
		# Le directeur sportif est celui de la direction du club (fiche, courriers) : un membre du staff qui en porte le
		# titre n'en fait pas un second.
		if str(role).strip_edges().to_lower() == "directeur sportif": return
		vus[id] = true
		var rang := 1 if cle in RESPONSABLES and not out.any(func(e: Dictionary): return e.cle == cle) else 2
		var t := tags.duplicate()
		if id == billet:
			t.append("billetterie")
			rang = 1
		out.append({"p": p, "cle": cle, "service": service, "role": role, "rang": rang, "tags": t})
	if not StaffServices.projection(app).is_empty():
		var par := StaffServices.repartition(app)
		for s: Dictionary in StaffServices.projection(app).get("services", []):
			for f: Dictionary in s.get("fonctions", []):
				for p: Dictionary in par.get(str(f.cle), []): ajouter.call(p, str(f.cle), str(s.id), str(StaffServices.FONCTIONS.get(str(f.cle), p.get("roleLabel", ""))).get_slice(" · ", 0), [])
			for cle_plus in ["enplus:", "surnombre:"]:
				for p: Dictionary in par.get(cle_plus + str(s.id), []): ajouter.call(p, "", str(s.id), str(p.get("roleLabel", "")), ["enplus"])
	for p: Dictionary in StaffServices.membres(app):
		ajouter.call(p, "", _service_du_role(str(p.get("role", ""))), str(p.get("roleLabel", "")), [])
	out.sort_custom(func(a: Dictionary, b: Dictionary): return _rang_service(a.service) < _rang_service(b.service) if a.service != b.service else int(a.rang) < int(b.rang))
	return out

## Estimation du staff (crans 1-5) : jamais le niveau exact ; marge d'un cran pour un membre arrivé cette saison.
static func estimation(p: Dictionary, saison: int) -> Array:
	if p.get("level") == null: return [0, 0]
	var n := clampi(roundi((float(p.level) - 35.0) / 10.0), 1, 5)
	var marge := 1 if int(p.get("entrySeason", saison - 1)) >= saison else 0
	return [n, mini(5, n + marge)]

static func _experience(p: Dictionary) -> int:
	var age := int(p.get("age", 0))
	if age <= 0: return 0
	return 1 if age <= 32 else 2 if age <= 38 else 3 if age <= 45 else 4 if age <= 54 else 5

# --- Pièces dessinées ------------------------------------------------------------------------------------------------

## Barres de signal : crans estimés pleins, marge d'incertitude estompée.
class Crans extends Control:
	var n := 0
	var haut := 0
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var l := size.x / 5.0
		for i in 5:
			var h := size.y * (0.36 + 0.16 * i)
			var c := Charte.FILET
			if i < n: c = couleur
			elif i < haut: c = Color(couleur, .35)
			draw_rect(Rect2(i * l + l * .14, size.y - h, l * .72, h), c)

## Disque du portrait : fond rond, visage découpé en rond, anneau à la couleur du service.
class Anneau extends Control:
	var couleur := Charte.IVOIRE
	var epais := 3.0
	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		draw_arc(size / 2.0, r - epais / 2.0, 0, TAU, 64, couleur, epais, true)

class Noeud extends Button:
	var couleur := Charte.IVOIRE
	var anneau: Anneau
	var carte: Control
	var service := ""
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rien := StyleBoxEmpty.new()
		for etat in ["normal", "hover", "pressed", "focus", "hover_pressed"]: add_theme_stylebox_override(etat, rien)
		pivot_offset = size / 2.0
		mouse_entered.connect(func(): if carte != null: carte.survoler(self))
		mouse_exited.connect(func(): if carte != null: carte.survoler(null))
		focus_entered.connect(func(): if carte != null: carte.survoler(self))
		focus_exited.connect(func(): if carte != null: carte.survoler(null))

static func disque(parent: Control, zone: Rect2, p: Dictionary, couleur: Color, epais: float = 4.0) -> Anneau:
	var fond := Panel.new()
	fond.name = "Disque"
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.PANNEAU_3
	style.set_corner_radius_all(int(zone.size.x * C.density))
	fond.add_theme_stylebox_override("panel", style)
	fond.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fond)
	D.place(fond, zone)
	var visage := p.duplicate(true)
	visage.portraitRole = "staff"
	var portrait := G.portrait_lazy(0, C.px(zone.size.x), visage)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.tooltip_text = ""
	fond.add_child(portrait)
	D.place(portrait, Rect2(Vector2(0, zone.size.y * .04), zone.size))
	var a := Anneau.new()
	a.couleur = couleur
	a.epais = epais * C.density
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(a)
	D.place(a, zone)
	return a

## Toile de la carte : guides (anneaux ou bulles), liens, et survol commun à tous les nœuds.
class Carte extends Control:
	var liens: Array = []      # [de, vers, couleur, ids (Array)]
	var guides: Array = []     # [centre, rayon, couleur, plein]
	var noeuds: Array = []
	var actif: Noeud = null
	var service_actif := ""
	func survoler(n: Noeud) -> void:
		actif = n
		service_actif = ""
		_appliquer()
	func surligner(service: String) -> void:
		actif = null
		service_actif = service
		_appliquer()
	func _appliquer() -> void:
		for n: Noeud in noeuds:
			if not is_instance_valid(n): continue
			var vif: bool = (actif == null and service_actif.is_empty()) or n == actif or (not service_actif.is_empty() and n.service == service_actif)
			n.modulate = Color(1, 1, 1, 1.0 if vif else .32)
			n.scale = Vector2.ONE * (1.14 if n == actif else 1.0)
			n.z_index = 2 if n == actif else 0
			if n.anneau != null:
				n.anneau.epais = (7.0 if n == actif else 4.0) * C.density
				n.anneau.couleur = n.couleur.lightened(.25) if n == actif else n.couleur
				n.anneau.queue_redraw()
		queue_redraw()
	func _draw() -> void:
		var k := C.density
		for g: Array in guides:
			var pts := PackedVector2Array()
			for i in 97: pts.append((g[0] + Vector2(cos(TAU * i / 96.0) * g[1], sin(TAU * i / 96.0) * g[2])) * k)
			if g[4]: draw_colored_polygon(pts, g[3])
			else: draw_polyline(pts, g[3], 2.0 * k, true)
		for l: Array in liens:
			var ids: Array = l[3]
			var vif: bool = (actif == null and service_actif.is_empty()) or (actif != null and actif.name in ids) or (not service_actif.is_empty() and l[4] == service_actif)
			var c: Color = l[2]
			draw_line(l[0] * k, l[1] * k, Color(c, .75 if vif and (actif != null or not service_actif.is_empty()) else .3 if vif else .08), (4.0 if vif and actif != null else 2.0) * k, true)

# --- Entrée ----------------------------------------------------------------------------------------------------------

static func build(app: Control, corps: Control) -> void:
	var gens := membres(app)
	var carte := Carte.new()
	carte.name = "OrgaCarte"
	carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corps.add_child(carte)
	D.place(carte, Rect2(0, 0, CARTE_L, 1244))
	_disposer(app, carte, gens)
	_centre(app, carte)
	_services(app, corps, carte, gens)

static func _centre(app: Control, carte: Carte) -> void:
	var fiche := _fiche(app)
	var nom: String = fiche.president
	var president := {"p": {"id": "pres-%d" % int(app.model.club.id), "name": nom if not nom.is_empty() else "Président", "age": 61}, "cle": "president", "service": "direction", "role": "Président", "rang": 0, "tags": [], "direction": true}
	_noeud(app, carte, president, CENTRE + Vector2(-104, 0), 132, "OrgaPresident")
	var toi := {"p": {"id": "", "name": "Toi"}, "cle": "manager", "service": "", "role": "Manager", "rang": 0, "tags": []}
	_noeud(app, carte, toi, CENTRE + Vector2(104, 0), 132, "OrgaManager")
	carte.liens.append([CENTRE + Vector2(-38, 0), CENTRE + Vector2(38, 0), Charte.IVOIRE, ["OrgaPresident", "OrgaManager"], "direction"])

## Un anneau par service, tenu par son responsable, autour du centre.
static func _disposer(app: Control, carte: Carte, gens: Array) -> void:
	var rayon := Vector2(520, 335)
	for i in SERVICES.size():
		var s: Array = SERVICES[i]
		var membres_s := gens.filter(func(e: Dictionary): return e.service == s[0])
		if membres_s.is_empty(): continue
		var a := -PI / 2.0 + TAU * i / SERVICES.size()
		var centre := CENTRE + Vector2(cos(a), sin(a)) * rayon
		var autour := membres_s.size() - 1
		var r := 140.0
		var d := 64.0 if autour <= 6 else 56.0
		var bord := r + d / 2.0 + 16.0
		carte.guides.append([centre, bord, bord, Color(s[2], .10), true])
		carte.guides.append([centre, bord, bord, Color(s[2], .45), false])
		var nom_tete := _nom(gens, membres_s[0])
		_noeud(app, carte, membres_s[0], centre, 96, nom_tete)
		carte.liens.append([CENTRE, centre, s[2], [nom_tete, "OrgaPresident", "OrgaManager"], s[0]])
		for j in autour:
			# Membres en haut et sur les côtés de la bulle : le bas reste aux mots du responsable.
			var b := -PI / 2.0 + (0.0 if autour == 1 else deg_to_rad(-135.0 + 270.0 * j / (autour - 1)))
			var pos := centre + Vector2(cos(b), sin(b)) * r
			var nom := _nom(gens, membres_s[j + 1])
			_noeud(app, carte, membres_s[j + 1], pos, d, nom, true)
			carte.liens.append([centre, pos, s[2], [nom, nom_tete], s[0]])

## Nom du nœud : le premier médecin a un nom fixe (captures), les autres leur rang.
static func _nom(gens: Array, e: Dictionary) -> String:
	if e.cle == "doctor" and gens.filter(func(x: Dictionary): return x.cle == "doctor").front() == e: return "OrgaMedecin"
	return "OrgaMembre_%d" % gens.find(e)

static func _noeud(app: Control, carte: Carte, e: Dictionary, pos: Vector2, d: float, nom: String, compact: bool = false) -> Noeud:
	var s := _service(str(e.service))
	var couleur: Color = Charte.IVOIRE if str(e.cle) == "manager" else s[2]
	var n := Noeud.new()
	n.name = nom
	n.couleur = couleur
	n.service = str(e.service)
	n.carte = carte
	carte.add_child(n)
	D.place(n, Rect2(pos - Vector2(d, d) / 2.0, Vector2(d, d)))
	n.pivot_offset = n.size / 2.0
	if str(e.cle) == "manager":
		var fond := D.rect(n, Rect2(0, 0, d, d), Charte.PANNEAU_3, int(d))
		fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := C.icon("people", int(d * .46), Charte.IVOIRE)
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(icone)
		D.place(icone, Rect2(d * .27, d * .25, d * .46, d * .46))
		var a := Anneau.new()
		a.couleur = couleur
		a.epais = 4.0 * C.density
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_child(a)
		D.place(a, Rect2(0, 0, d, d))
		n.anneau = a
	else:
		n.anneau = disque(n, Rect2(0, 0, d, d), e.p, couleur, 4.0 if d >= 90 else 3.0)
	if "billetterie" in e.tags:
		var pastille := D.rect(n, Rect2(d * .68, d * .68, d * .34, d * .34), Pastilles.ORANGE, int(d))
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := C.icon("money", int(d * .22), Charte.ENCRE)
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.add_child(icone)
		D.place(icone, Rect2(d * .06, d * .06, d * .22, d * .22))
	var taille_role := 17 if d >= 90 else 16
	var largeur := 190.0 if not compact else 156.0
	var nom_court := Kit.casse(str(e.p.get("name", "")), true) if str(e.cle) != "manager" else ""
	# Sous les membres des anneaux : fond sombre sous les mots, lisibles même posés sur le contour de l'anneau.
	if d < 120:
		var lignes := 2 if not nom_court.is_empty() else 1
		var sous := D.rect(n, Rect2(d / 2.0 - largeur / 2.0 + 6, d + 3, largeur - 12, taille_role * lignes + 4 * lignes + 8), Color(Charte.NOIR_PANNEAU, .82), 8)
		sous.name = "OrgaSousTexte"
	# Alignement centré : x est le milieu du texte.
	var role := D.text(n, d / 2.0, d + taille_role + 6, str(e.role).to_upper() if d >= 120 else str(e.role), taille_role, couleur, 800, largeur, HORIZONTAL_ALIGNMENT_CENTER)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not nom_court.is_empty():
		var l := D.text(n, d / 2.0, d + taille_role * 2 + 10, nom_court, taille_role - 1, Charte.IVOIRE_2, 600, largeur, HORIZONTAL_ALIGNMENT_CENTER)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.accessibility_name = "%s · %s" % [e.role, e.p.get("name", "")]
	if str(e.cle) == "manager": n.pressed.connect(func(): app._navigate("Carrière"))
	else: n.pressed.connect(func(): fenetre(app, e))
	carte.noeuds.append(n)
	return n

# --- Colonne des services (lignes façon Effectif) ----------------------------------------------------------------------

static func _services(app: Control, corps: Control, carte: Carte, gens: Array) -> void:
	var x0 := CARTE_L + 20.0
	var largeur := W - x0
	var titre := Kit.titre(corps, x0 + 8, 250, "Services", 26, 300)
	titre.name = "OrgaServicesTitre"
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var h := 186.0
	var services_moteur := {}
	for s: Dictionary in StaffServices.projection(app).get("services", []): services_moteur[str(s.id)] = s
	var par := StaffServices.repartition(app) if not services_moteur.is_empty() else {}
	for i in SERVICES.size():
		var s: Array = SERVICES[i]
		var id: String = s[0]
		var membres_s := gens.filter(func(e: Dictionary): return e.service == id)
		if id == "direction":
			var fiche := _fiche(app)
			membres_s.push_front({"p": {"id": "pres-%d" % int(app.model.club.id), "name": fiche.president if not str(fiche.president).is_empty() else "Président"}})
		var y := 276.0 + i * (h + 6)
		var ligne := Button.new()
		ligne.name = "OrgaService_" + id
		StaffTable.styler_rangee(ligne)
		ligne.accessibility_name = "%s · %d" % [s[1], membres_s.size()]
		ligne.mouse_entered.connect(func(): carte.surligner(id))
		ligne.mouse_exited.connect(func(): carte.surligner(""))
		if services_moteur.has(id): ligne.pressed.connect(func(): StaffServices._fenetre_service(app, services_moteur[id], par))
		else: ligne.pressed.connect(func(): _fenetre_president(app))
		corps.add_child(ligne)
		D.place(ligne, Rect2(x0, y, largeur, h))
		D.rect(ligne, Rect2(0, 10, 8, h - 20), s[2], 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icone := C.icon(str(s[3]), 26, s[2])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(icone)
		D.place(icone, Rect2(26, 18, 26, 26))
		var t := D.text(ligne, 62, 42, str(s[1]).to_upper(), 24, Charte.IVOIRE, 800, largeur - 160)
		t.add_theme_font_override("font", Charte.TITRE_EXTRA)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(ligne, largeur - 24, 46, str(membres_s.size()), 38, s[2], 800, 80, HORIZONTAL_ALIGNMENT_RIGHT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Visages du service.
		var montres := mini(membres_s.size(), 8)
		for j in montres:
			var p: Dictionary = membres_s[j].p
			disque(ligne, Rect2(26 + j * 60, 62, 54, 54), p, s[2], 2.0)
		if membres_s.size() > montres: D.text(ligne, 26 + montres * 60 + 6, 98, "+%d" % (membres_s.size() - montres), 18, Charte.IVOIRE_2, 700, 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Niveau estimé du service (crans, jamais de chiffre).
		var estimes := membres_s.map(func(e: Dictionary): return estimation(e.p, saison)).filter(func(v: Array): return v[0] > 0)
		if not estimes.is_empty():
			var bas: int = roundi(estimes.reduce(func(a: float, v: Array): return a + v[0], 0.0) / estimes.size())
			var haut: int = roundi(estimes.reduce(func(a: float, v: Array): return a + v[1], 0.0) / estimes.size())
			var sig := Crans.new()
			sig.n = bas; sig.haut = maxi(bas, haut); sig.couleur = s[2]
			sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(sig)
			D.place(sig, Rect2(26, 132, 70, 32))
			D.text(ligne, 108, 158, MOTS[clampi(bas - 1, 0, 4)], 19, s[2], 700, 200).mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Petites fenêtres ------------------------------------------------------------------------------------------------

static func _page(app: Control) -> Control:
	return app.find_child("ImmersiveClub", true, false) as Control

## Pastilles en ligne, mesurées une fois posées (thème et police appliqués), centrées sur une même hauteur de ligne ;
## retour à la ligne quand la largeur est atteinte.
static func _pastilles(parent: Control, x: float, y: float, items: Array, largeur: float) -> float:
	const LIGNE := 36.0
	var cx := x
	for it: Array in items:
		var action: Callable = it[3] if it.size() > 3 else Callable()
		var p := Pastilles.pastille(str(it[0]), it[1], str(it[2]), "", 18, "", action)
		p.name = "OrgaPastille_%d" % parent.get_child_count()
		var l := Pastilles.poser(parent, p, cx, y)
		if cx + l > x + largeur and cx > x:
			cx = x
			y += 44
		p.position = Vector2(cx * C.density, y * C.density + maxf(0.0, LIGNE * C.density - p.size.y) / 2.0)
		cx += l + 10
	return y + 44

static func _crans(parent: Control, x: float, y: float, libelle: String, est: Array, couleur: Color) -> void:
	Kit.texte(parent, x, y + 24, libelle, Charte.IVOIRE, 250, 18)
	var sig := Crans.new()
	sig.n = int(est[0]); sig.haut = int(est[1]); sig.couleur = couleur
	parent.add_child(sig)
	D.place(sig, Rect2(x + 260, y, 80, 32))
	var mot: String = MOTS[clampi(int(est[0]) - 1, 0, 4)] if int(est[0]) > 0 else "—"
	if int(est[1]) > int(est[0]): mot = "%s ?" % mot
	D.text(parent, x + 356, y + 26, mot, 20, couleur, 700, 160)

static func _recents(app: Control, e: Dictionary) -> Array:
	var out: Array = []
	var p: Dictionary = e.p
	var cle := str(e.cle)
	var saison := int(app.model.get("meta", {}).get("season", 0))
	if p.get("entrySeason") != null and int(p.entrySeason) >= saison: out.append(["Recrue", Pastilles.TURQUOISE, "star"])
	if cle in SOINS:
		var blesses: int = app.model.get("squad", []).filter(func(j: Variant): return j is Dictionary and float(j.get("injury", 0)) > 0).size()
		out.append(["%d en soins" % blesses, Pastilles.ROUGE if blesses > 0 else Pastilles.VERT, "heart", func(): app._navigate("Effectif")])
	if ZONES.has(cle): out.append([ZONES[cle], Pastilles.BLEU, "tactic", func(): app._navigate("Tactique")])
	var delegation: Dictionary = app.model.get("decisions", {}).get("delegation", {})
	if cle == "assistant": out.append(["Compo des 23" if bool(delegation.get("lineup", false)) else "Compo : toi", Pastilles.VIOLET if bool(delegation.get("lineup", false)) else Pastilles.BLEU, "people", func(): app._navigate("Staff")])
	if cle in ["fitnessLead", "conditioning"]: out.append(["Charge confiée" if bool(delegation.get("training", false)) else "Charge : toi", Pastilles.VIOLET if bool(delegation.get("training", false)) else Pastilles.BLEU, "train", func(): app._navigate("Entraînement")])
	if cle == "scout":
		var rapports: int = app.model.get("decisions", {}).get("recruitment", {}).get("reports", []).size()
		out.append(["%d rapports" % rapports, Pastilles.ORANGE, "search", func(): app._navigate("Recrutement")])
	if "billetterie" in e.tags:
		out.append(["Billetterie", Pastilles.ORANGE, "money", func(): app._navigate("Stratégie")])
	if "enplus" in e.tags: out.append(["En plus", Pastilles.VIOLET, "check", func(): app._navigate("Staff")])
	if p.get("contractEnd") != null and int(p.contractEnd) <= saison: out.append(["Fin de contrat", Pastilles.ORANGE, "warning", func(): app._navigate("Staff")])
	return out

static func fenetre(app: Control, e: Dictionary) -> void:
	if str(e.cle) == "president":
		_fenetre_president(app)
		return
	var page := _page(app)
	if page == null: return
	var s := _service(str(e.service))
	var p: Dictionary = e.p
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var fond := FenetreVisuelle.ouvrir(page, "OrgaFenetre", str(p.get("name", "")).to_upper(), str(s[3]), 960, 430)
	var portrait := disque(fond, Rect2(40, 96, 210, 210), p, s[2], 6.0)
	portrait.name = "OrgaFenetrePortrait"
	if not bool(e.get("direction", false)):
		var lien := Button.new()
		lien.name = "OrgaFenetreFiche"
		StaffTable.styler_rangee(lien)
		fond.add_child(lien)
		D.place(lien, Rect2(36, 92, 218, 218))
		EntityLink.bind(lien, app, {"kind": "staff", "id": str(p.get("id", ""))}, str(p.get("name", "")))
		lien.tooltip_text = ""
	D.text(fond, 145, 352, str(s[1]), 17, s[2], 700, 260, HORIZONTAL_ALIGNMENT_CENTER)
	var infos: Array = [[str(e.role), s[2], str(s[3])]]
	if int(p.get("age", 0)) > 0 and not bool(e.get("direction", false)): infos.append(["%d ans" % int(p.age), Charte.IVOIRE_2, ""])
	if p.get("entrySeason") != null: infos.append(["Depuis " + G.season_label(p.entrySeason), Pastilles.TURQUOISE, "check"])
	if p.get("contractEnd") != null: infos.append(["Fin " + G.season_label(p.contractEnd), Pastilles.ORANGE if int(p.contractEnd) <= saison else Charte.IVOIRE_2, "lock"])
	_pastilles(fond, 290, 92, infos, 640)
	Kit.texte(fond, 290, 196, "COMPÉTENCES ESTIMÉES", Charte.IVOIRE_3, 400, 14)
	var metier := str(StaffServices.FONCTIONS.get(str(e.cle), e.role)).get_slice(" · ", 1) if " · " in str(StaffServices.FONCTIONS.get(str(e.cle), "")) else str(e.role)
	if metier == str(e.role): metier = "Au poste"
	_crans(fond, 290, 212, metier.capitalize() if metier == metier.to_lower() else metier, estimation(p, saison), s[2])
	var xp := _experience(p)
	if xp > 0: _crans(fond, 290, 256, "Expérience", [xp, xp], s[2])
	Kit.texte(fond, 290, 336, "RÉCEMMENT", Charte.IVOIRE_3, 400, 14)
	var recents := _recents(app, e)
	if recents.is_empty(): recents = [["Au club", Charte.IVOIRE_2, "check", func(): app._navigate("Staff")]]
	_pastilles(fond, 290, 352, recents, 640)

static func _fenetre_president(app: Control) -> void:
	var page := _page(app)
	if page == null: return
	var fiche := _fiche(app)
	var nom: String = fiche.president
	var p := {"id": "pres-%d" % int(app.model.club.id), "name": nom if not nom.is_empty() else "Président"}
	var fond := FenetreVisuelle.ouvrir(page, "OrgaFenetre", str(p.name).to_upper(), "shield", 960, 430)
	disque(fond, Rect2(40, 96, 210, 210), p, Pastilles.VIOLET, 6.0).name = "OrgaFenetrePortrait"
	D.text(fond, 145, 352, "Direction", 17, Pastilles.VIOLET, 700, 260, HORIZONTAL_ALIGNMENT_CENTER)
	var infos: Array = [["Président", Pastilles.VIOLET, "shield", func(): app._navigate("Stratégie")]]
	var directeur: String = fiche.director
	if not directeur.is_empty(): infos.append(["DS · " + Kit.casse(directeur, true), Pastilles.VIOLET, "people", func(): app._navigate("Stratégie")])
	_pastilles(fond, 290, 92, infos, 640)
	Kit.texte(fond, 290, 196, "CONSEIL", Charte.IVOIRE_3, 400, 14)
	var confiance: Variant = app.model.get("meta", {}).get("trust")
	if confiance is int or confiance is float:
		var n := clampi(roundi(float(confiance) / 20.0), 1, 5)
		_crans(fond, 290, 212, "Confiance en toi", [n, n], Pastilles.VIOLET)
	Kit.texte(fond, 290, 336, "RÉCEMMENT", Charte.IVOIRE_3, 400, 14)
	var forme: Variant = fiche.table.get("form", [])
	if not forme is Array: forme = []
	var recents: Array = []
	for r: Variant in forme:
		var lettre := str(r)
		recents.append([lettre, Pastilles.VERT if lettre in ["V", "W"] else Pastilles.ROUGE if lettre in ["D", "L"] else Pastilles.ORANGE, "", func(): app._navigate("Calendrier")])
	if recents.is_empty(): recents = [["Saison en cours", Charte.IVOIRE_2, "check", func(): app._navigate("Stratégie")]]
	_pastilles(fond, 290, 352, recents, 640)
