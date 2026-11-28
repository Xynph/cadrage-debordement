extends RefCounted
## Club › Staff « par service » (revue FM27, idée n° 22, choix A de Léo du 23/11/2026). Quatre colonnes : postes occupés
## / postes visés, une silhouette par personne colorée par son niveau (toujours doublée du chiffre), une rangée « En
## plus » réglée d'un clic (− / +, appliqué tout de suite) avec son bonus réel et son salaire, l'avis des dirigeants
## dessous. Bandeau bas : affectations des entraîneurs en anneaux, responsabilités déléguées, contrats. « Tout le staff »
## rend le tableau habituel. Les postes, les membres en plus, les bonus, les salaires et l'avis viennent du moteur
## (native/engine/staff-services.cjs, clubLife.staffServices) ; sans cette projection, le tableau habituel.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const G = preload("res://ui/game_skin.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const EntityLink = preload("res://ui/entity_link.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const StaffTable = preload("res://ui/staff_career_view.gd")
const FenetreVisuelle = preload("res://ui/immersive08/fenetre_visuelle.gd")

const W := 2248.0
const CLE_VUE := "staff_services_vue"

## Présentation des services du moteur (mêmes identifiants et fonctions que staff-services.cjs).
const SERVICES := {
	"coaching": {"titre": "Entraîneurs", "icone": "tactic", "bonus": "progression"},
	"fitness": {"titre": "Préparation physique", "icone": "train", "bonus": "blessures"},
	"medical": {"titre": "Médical", "icone": "heart", "bonus": "soins"},
	"club": {"titre": "Recrutement et club", "icone": "search", "bonus": "observation"},
}
const FONCTIONS := {"assistant": "Adjoint", "forwards": "Avants · mêlée, touche", "backs": "Arrières · attaque, pied", "defence": "Défense",
	"fitnessLead": "Responsable", "conditioning": "Préparateur", "rehab": "Réathlétisation", "doctor": "Médecin", "physio": "Kinésithérapeute",
	"scout": "Recruteur", "analyst": "Analyste vidéo", "formation": "Formation", "teamManager": "Team manager", "equipment": "Intendant"}
## Signe du bonus : la prévention et l'observation baissent un risque ou un coût.
const BAISSE := ["prevention", "observation"]
const AVIS := {"ravis": ["Ravis", Pastilles.VERT, "star"], "satisfaits": ["Satisfaits", Pastilles.TURQUOISE, "check"],
	"mitiges": ["Mitigés", Pastilles.ORANGE, "warning"], "inquiets": ["Inquiets", Pastilles.ROUGE, "warning"]}
const ZONES := [["forwards", "Avants"], ["backs", "Arrières"], ["defence", "Défense"], ["assistant", "Adjoint"]]

static func projection(app: Control) -> Dictionary:
	var p: Variant = app.model.get("clubLife", {}).get("staffServices")
	return p if p is Dictionary and p.get("available", false) == true else {}

## La vue par service remplace l'onglet tant qu'aucune fiche n'est ouverte et que « Tout le staff » n'est pas choisi.
static func actif(app: Control) -> bool:
	if app.route != "Staff" or projection(app).is_empty(): return false
	if not str(app.StaffViews.reading(app).get("navigation_id", "")).is_empty(): return false
	return str(app.management_ui.get(CLE_VUE, "services")) != "tous"

static func membres(app: Control) -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id", -1)) == int(app.model.club.id): return team.get("members", []).filter(func(p: Dictionary): return p.get("historical", false) != true)
	return []

## Personnes des postes : {fonction: [personnes], "enplus:<service>": [...], "surnombre:<service>": [...]} d'après les
## identifiants projetés par le moteur.
static func repartition(app: Control) -> Dictionary:
	var par_id := {}
	for p: Dictionary in membres(app): par_id[str(p.get("id", ""))] = p
	var gens := func(ids: Array) -> Array: return ids.map(func(id: Variant): return par_id.get(str(id), {})).filter(func(p: Dictionary): return not p.is_empty())
	var par := {}
	for service: Dictionary in projection(app).get("services", []):
		for f: Dictionary in service.get("fonctions", []): par[str(f.cle)] = gens.call(f.get("ids", []))
		par["enplus:" + str(service.id)] = gens.call(service.get("enPlus", []))
		par["surnombre:" + str(service.id)] = gens.call(service.get("surnombre", []))
	return par

static func _niveau(p: Dictionary) -> int:
	return int(p.get("level", 0)) if p.get("level") != null else 0

static func _couleur_occupation(occupes: int, vises: int) -> Color:
	if occupes >= vises: return Charte.GAIN
	return Charte.INTENSIF if vises - occupes == 1 else Charte.PERTE

## « +10 % » / « −15 % » : bonus total du service, signe selon son effet.
static func texte_bonus(bonus: Dictionary) -> String:
	var pct := roundi(float(bonus.get("total", 0.0)) * 100.0)
	if pct == 0: return "0 %"
	return ("−%d %%" if str(bonus.get("type", "")) in BAISSE else "+%d %%") % pct

# --- Actions --------------------------------------------------------------------------------------------------------

static func _vue(app: Control, vue: String) -> void:
	app.management_ui[CLE_VUE] = vue
	app._render()

## Ouvre le tableau habituel sur l'onglet voulu (0 : encadrement, 1 : candidats).
static func _tableau(app: Control, onglet: int) -> void:
	var lecture: Dictionary = app.StaffViews.reading(app)
	lecture.navigation_id = ""
	lecture.tab = onglet; lecture.page = 0; lecture.search = ""; lecture.scroll = 0
	app.management_ui.erase("club_page")
	_vue(app, "tous")

## Postes visés en plus du minimum : un clic applique (pas de validation).
static func _viser(app: Control, service: String, cible: int) -> void:
	app._command("staff_services_target", {"service": service, "cible": cible})

static func _lier(app: Control, bouton: BaseButton, p: Dictionary) -> void:
	EntityLink.bind(bouton, app, {"kind": "staff", "id": str(p.get("id", ""))}, str(p.get("name", "")))
	bouton.tooltip_text = ""

# --- Petites pièces dessinées ----------------------------------------------------------------------------------------

## Silhouette d'une personne (tête + épaules) : pleine à la couleur de son niveau, en pointillé si le poste est vide,
## estompée pour un membre en surnombre (au club, hors des postes visés).
class Silhouette extends Button:
	var couleur := Charte.IVOIRE
	var vide := false
	var estompe := false
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rien := StyleBoxEmpty.new()
		for etat in ["normal", "hover", "pressed", "focus", "hover_pressed"]: add_theme_stylebox_override(etat, rien)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var s := size
		var c := couleur.lightened(.18) if is_hovered() else couleur
		if estompe: c = Color(c, .38 if not is_hovered() else .7)
		var tete := Vector2(s.x * .5, s.y * .27)
		var r := s.x * .23
		var corps := PackedVector2Array()
		var n := 16
		for i in n + 1:
			var a := PI + PI * float(i) / n
			corps.append(Vector2(s.x * .5 + cos(a) * s.x * .44, s.y * .98 + sin(a) * s.y * .44))
		if vide:
			draw_arc(tete, r, 0, TAU, 24, Charte.IVOIRE_3, maxf(1.0, s.x * .06), true)
			corps.append(corps[0])
			draw_polyline(corps, Charte.IVOIRE_3, maxf(1.0, s.x * .06), true)
		else:
			draw_circle(tete, r, c)
			draw_colored_polygon(corps, c)
		if has_focus(): draw_rect(Rect2(Vector2.ZERO, s), Charte.IVOIRE, false, 1.5)

static func _silhouette(parent: Control, zone: Rect2, p: Dictionary, app: Control, nom: String, estompe: bool = false) -> Silhouette:
	var s := Silhouette.new()
	s.name = nom
	s.estompe = estompe
	if p.is_empty():
		s.vide = true
		s.accessibility_name = "Poste à pourvoir · candidats"
		s.tooltip_text = "Poste à pourvoir"
		s.pressed.connect(func(): _tableau(app, 1))
	else:
		s.couleur = Charte.couleur_attribut(_niveau(p))
		s.accessibility_name = "%s · %s · niveau %d" % [p.get("name", ""), p.get("roleLabel", ""), _niveau(p)]
		_lier(app, s, p)
	parent.add_child(s)
	D.place(s, zone)
	return s

static func _ligne(parent: Control, zone: Rect2, nom: String, action: Callable) -> Button:
	var ligne := Button.new()
	ligne.name = nom
	StaffTable.styler_rangee(ligne)
	ligne.pressed.connect(action)
	parent.add_child(ligne)
	D.place(ligne, zone)
	return ligne

static func _gras(l: Label) -> Label:
	l.add_theme_font_override("font", Kit.texte_gras())
	return l

## Bascule « Par service / Tout le staff », à droite des onglets du Club (corps décalé : y 152 = rangée des onglets).
static func bascule(app: Control, parent: Control, services: bool) -> void:
	if projection(app).is_empty(): return
	var x := W
	for item: Array in [["tous", "Tout le staff"], ["services", "Par service"]]:
		var choisi: bool = (item[0] == "services") == services
		var largeur := C.DISPLAY.get_string_size(str(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(20))).x / C.density + 40
		x -= largeur + 8
		var b := Button.new()
		b.name = "StaffVue_" + str(item[0])
		b.text = str(item[1])
		b.toggle_mode = true
		b.button_pressed = choisi
		b.add_theme_font_override("font", C.DISPLAY)
		b.add_theme_font_size_override("font_size", maxi(12, C.px(20)))
		D.tab_state(b, Vector2(largeur, 42), choisi, "")
		b.icon = null
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vue := str(item[0])
		b.pressed.connect(func(): _vue(app, vue))
		parent.add_child(b)
		D.place(b, Rect2(x, 154, largeur, 42))

# --- Entrée ---------------------------------------------------------------------------------------------------------

static func build(app: Control, corps: Control) -> void:
	var people := membres(app)
	var par := repartition(app)
	bascule(app, corps, true)
	var haut := 214.0
	var hauteur := 600.0
	var ecart := 22.0
	var largeur := (W - ecart * 3) / 4.0
	var services: Array = projection(app).get("services", [])
	for i in services.size():
		_colonne(app, corps, Rect2(i * (largeur + ecart), haut, largeur, hauteur), services[i], par)
	var bas := haut + hauteur + 22.0
	var h_bas := 1244.0 - bas - 12.0
	var l1 := 960.0
	var l2 := 560.0
	_affectations(app, _panneau(corps, Rect2(0, bas, l1, h_bas), "Affectations des entraîneurs", "StaffAffectations"), par)
	_responsabilites(app, _panneau(corps, Rect2(l1 + ecart, bas, l2, h_bas), "Responsabilités", "StaffResponsabilites"), l2)
	_contrats(app, _panneau(corps, Rect2(l1 + l2 + ecart * 2, bas, W - l1 - l2 - ecart * 2, h_bas), "Contrats", "StaffContratsServices"), people, W - l1 - l2 - ecart * 2)

static func _panneau(parent: Control, zone: Rect2, titre: String, id: String) -> Panel:
	var p := D.rect(parent, zone, Charte.PANNEAU, 24)
	p.add_theme_stylebox_override("panel", Charte.style_panneau())
	p.name = id
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if not titre.is_empty(): Kit.titre(p, 24, 44, titre, 26, zone.size.x - 48).name = "CardTitle"
	return p

# --- Colonnes des services -------------------------------------------------------------------------------------------

static func _entete(app: Control, p: Panel, service: Dictionary, largeur: float, par: Dictionary) -> void:
	var meta: Dictionary = SERVICES.get(str(service.id), {})
	var occupes := int(service.get("occupes", 0))
	var vises := int(service.get("vises", 0))
	var couleur := _couleur_occupation(occupes, vises)
	var icone := C.icon(str(meta.get("icone", "people")), 28, couleur)
	p.add_child(icone)
	D.place(icone, Rect2(24, 22, 28, 28))
	Kit.titre(p, 62, 46, str(meta.get("titre", "")), 26, largeur - 200)
	var compte := D.text(p, largeur - 24, 50, "%d/%d" % [occupes, vises], 38, couleur, 800, 140, HORIZONTAL_ALIGNMENT_RIGHT)
	compte.name = "StaffServiceCompte_" + str(service.id)
	var zone := _ligne(p, Rect2(largeur - 150, 12, 136, 50), "StaffServiceOuvrir_" + str(service.id), func(): _fenetre_service(app, service, par))
	zone.accessibility_name = "%s · %d postes sur %d" % [meta.get("titre", ""), occupes, vises]

static func _colonne(app: Control, corps: Control, zone: Rect2, service: Dictionary, par: Dictionary) -> void:
	var id := str(service.id)
	var p := _panneau(corps, zone, "", "StaffService_" + id)
	var largeur := zone.size.x
	_entete(app, p, service, largeur, par)
	var fonctions: Array = service.get("fonctions", [])
	var h := minf(64.0, 384.0 / (fonctions.size() + 1))
	var y := 74.0
	for f: Dictionary in fonctions:
		var cle := str(f.cle)
		var gens: Array = par.get(cle, [])
		var prevus := int(f.get("minimum", 1))
		var ligne := _ligne(p, Rect2(10, y, largeur - 20, h - 4), "StaffFonction_" + cle, func(): _fenetre_service(app, service, par))
		ligne.accessibility_name = "%s · %d / %d" % [FONCTIONS.get(cle, cle), gens.size(), prevus]
		_compteur(p, y, h, "%d/%d" % [mini(gens.size(), prevus), prevus], Charte.GAIN if gens.size() >= prevus else Charte.INTENSIF, "StaffFonctionCompte_" + cle)
		Kit.texte(p, 90, y + h / 2.0 + 4, str(FONCTIONS.get(cle, cle)), Charte.IVOIRE, largeur - 290, 17)
		var slots: Array = gens.duplicate()
		for i in maxi(0, prevus - gens.size()): slots.append({})
		var sx := largeur - 70.0 - 34.0 * (slots.size() - 1)
		for i in slots.size():
			_silhouette(p, Rect2(sx + i * 34.0 - 44, y + (h - 4) / 2.0 - 21, 28, 40), slots[i], app, "StaffSilhouette_%s_%d" % [cle, i])
		if not gens.is_empty():
			var meilleur := _niveau(gens[0])
			_gras(Kit.texte(p, largeur - 22, y + h / 2.0 + 5, str(meilleur), Charte.couleur_attribut(meilleur), 40, 18, HORIZONTAL_ALIGNMENT_RIGHT))
		y += h
	_en_plus(app, p, service, par, y, h, largeur)
	_bonus(p, service, largeur, 600.0 - 160.0)
	D.line(p, Vector2(18, 600.0 - 66), Vector2(largeur - 18, 600.0 - 66), Charte.FILET)
	_avis(app, p, service, par, largeur)

static func _compteur(p: Control, y: float, h: float, texte: String, c: Color, nom: String) -> void:
	var pastille := D.rect(p, Rect2(20, y + (h - 4) / 2.0 - 13, 58, 26), Color(c, .2), 6)
	pastille.name = nom
	D.text(pastille, 29, 19, texte, 18, c, 800, 58, HORIZONTAL_ALIGNMENT_CENTER)

## Rangée « En plus » : membres sur les postes visés (silhouettes pleines), postes visés à pourvoir (pointillés), membres
## en surnombre (estompés) ; − / + règlent le nombre de postes visés d'un clic.
static func _en_plus(app: Control, p: Panel, service: Dictionary, par: Dictionary, y: float, h: float, largeur: float) -> void:
	var id := str(service.id)
	var cible := int(service.get("cible", 0))
	var maxi_ := int(service.get("max", 3))
	var tenus: Array = par.get("enplus:" + id, [])
	var surnombre: Array = par.get("surnombre:" + id, [])
	D.rect(p, Rect2(14, y + 2, largeur - 28, h - 8), Color(Charte.BANDEAU, .55), 8).name = "StaffEnPlus_" + id
	var c := Charte.GAIN if tenus.size() >= cible else Charte.INTENSIF
	if cible == 0: c = Charte.IVOIRE_3
	_compteur(p, y, h, "%d/%d" % [tenus.size(), cible], c, "StaffEnPlusCompte_" + id)
	_gras(Kit.texte(p, 90, y + h / 2.0 + 4, "En plus", Pastilles.VIOLET, 110, 17))
	var slots: Array = []
	for q in tenus: slots.append([q, false])
	for i in maxi(0, cible - tenus.size()): slots.append([{}, false])
	for q in surnombre: slots.append([q, true])
	var x0 := 190.0
	var place := floori((largeur - 120.0 - x0) / 32.0)
	for i in mini(slots.size(), place):
		_silhouette(p, Rect2(x0 + i * 32.0, y + (h - 4) / 2.0 - 20, 26, 38), slots[i][0], app, "StaffEnPlusSilhouette_%s_%d" % [id, i], slots[i][1])
	if slots.size() > place: Kit.texte(p, x0 + place * 32.0, y + h / 2.0 + 4, "+%d" % (slots.size() - place), Charte.IVOIRE_3, 40, 15)
	for sens: Array in [["moins", "−", cible - 1, cible > 0], ["plus", "+", cible + 1, cible < maxi_]]:
		var b := Button.new()
		b.name = "StaffCible_%s_%s" % [id, sens[0]]
		b.text = str(sens[1])
		C.style_bouton_contour(b, 22)
		b.disabled = not bool(sens[3])
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.accessibility_name = "%s · postes en plus : %d" % [SERVICES.get(id, {}).get("titre", id), int(sens[2])]
		var valeur := int(sens[2])
		b.pressed.connect(func(): _viser(app, id, valeur))
		p.add_child(b)
		D.place(b, Rect2(largeur - (108.0 if sens[0] == "moins" else 60.0), y + (h - 4) / 2.0 - 20, 44, 40))

## Bonus réel du service (chiffre coloré + mot) et salaire des postes en plus.
static func _bonus(p: Panel, service: Dictionary, largeur: float, y: float) -> void:
	var bonus: Dictionary = service.get("bonus", {})
	var actif := float(bonus.get("total", 0.0)) > 0.0
	var mot := str(SERVICES.get(str(service.id), {}).get("bonus", ""))
	var valeur := D.text(p, 24, y + 52, texte_bonus(bonus), 44, Pastilles.VIOLET if actif else Charte.IVOIRE_3, 800, 160)
	valeur.name = "StaffBonus_" + str(service.id)
	Kit.texte(p, 24 + Kit.largeur(texte_bonus(bonus), 44) * 1.05 + 14, y + 50, mot, Charte.IVOIRE if actif else Charte.IVOIRE_3, 200, 17)
	var salaire := int(service.get("salaire", {}).get("semaine", 0))
	var par_poste := int(service.get("salaire", {}).get("parPoste", 0))
	var montant := D.text(p, largeur - 24, y + 40, ("−" + G.euros(salaire)) if salaire > 0 else "0 €", 24, Pastilles.ORANGE if salaire > 0 else Charte.IVOIRE_3, 800, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	montant.name = "StaffSalaire_" + str(service.id)
	Kit.texte(p, largeur - 24, y + 64, "%s / POSTE / SEM." % G.euros(par_poste), Charte.IVOIRE_3, 280, 13, HORIZONTAL_ALIGNMENT_RIGHT)

## Avis des dirigeants (moteur) : pastille colorée, niveau moyen du service face au niveau attendu.
static func _avis(app: Control, p: Panel, service: Dictionary, par: Dictionary, largeur: float) -> void:
	var avis: Dictionary = service.get("avis", {})
	var a: Array = AVIS.get(str(avis.get("verdict", "satisfaits")), AVIS.satisfaits)
	Kit.texte(p, 24, 600.0 - 38, "DIRIGEANTS", Charte.IVOIRE_3, 140, 14)
	var moyenne := int(avis.get("moyenne", 0))
	var attendu := int(avis.get("attendu", 0))
	var niv := _gras(Kit.texte(p, 24, 600.0 - 14, str(moyenne), Charte.couleur_attribut(moyenne), 40, 18))
	niv.name = "StaffAvisNiveau_" + str(service.id)
	Kit.texte(p, 24 + Kit.largeur(str(moyenne), 18) + 6, 600.0 - 14, "/ %d" % attendu, Charte.IVOIRE_3, 60, 15)
	var action := func(): _fenetre_service(app, service, par)
	if int(avis.get("manque", 0)) > 0: action = func(): _tableau(app, 1)
	var pastille := Pastilles.pastille(str(a[0]), a[1], str(a[2]), "", 17, "StaffAvis_" + str(service.id), action)
	Pastilles.poser_a_droite(p, pastille, largeur - 22, 600.0 - 50)

# --- Bandeau bas ---------------------------------------------------------------------------------------------------

static func _coach(par: Dictionary, cle: String) -> Dictionary:
	var gens: Array = par.get(cle, [])
	return gens[0] if not gens.is_empty() else {}

static func _affectations(app: Control, p: Panel, par: Dictionary) -> void:
	var largeur := p.size.x / C.density
	var pas := (largeur - 48) / ZONES.size()
	for i in ZONES.size():
		var z: Array = ZONES[i]
		var coach := _coach(par, str(z[0]))
		var niveau := _niveau(coach)
		var anneau := JaugeAnneau.new(float(niveau), str(z[1]), Charte.couleur_attribut(niveau) if not coach.is_empty() else Charte.IVOIRE_3)
		anneau.diametre = 116.0
		anneau.name = "StaffAnneau_" + str(z[0])
		anneau.custom_minimum_size = Vector2.ZERO
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(anneau)
		D.place(anneau, Rect2(24 + i * pas, 66, pas, 176))
		Kit.texte(p, 24 + i * pas + pas / 2.0, 272, Kit.casse(str(coach.get("name", "Poste vide")), true), Charte.IVOIRE if not coach.is_empty() else Charte.IVOIRE_3, pas - 12, 17, HORIZONTAL_ALIGNMENT_CENTER)
		var zone := Button.new()
		zone.name = "StaffAnneauLien_" + str(z[0])
		StaffTable.styler_rangee(zone)
		p.add_child(zone)
		D.place(zone, Rect2(24 + i * pas + 6, 60, pas - 12, 228))
		p.move_child(zone, anneau.get_index())
		if coach.is_empty(): zone.pressed.connect(func(): _tableau(app, 1))
		else: _lier(app, zone, coach)

static func _delegations(app: Control) -> Array:
	var decisions: Dictionary = app.model.get("decisions", {})
	var delegation: Dictionary = decisions.get("delegation", {})
	return [["lineup", "Composition des 23", "Adjoint", bool(delegation.get("lineup", false))], ["training", "Charge d’entraînement", "Préparateur", bool(delegation.get("training", false))]]

static func _basculer(app: Control, cle: String, valeur: bool) -> void:
	app._command("set_delegation", {"key": cle, "enabled": valeur})

static func _responsabilites(app: Control, p: Panel, largeur: float) -> void:
	var items := _delegations(app)
	var deleguees := items.filter(func(e: Array): return e[3]).size()
	var t1 := Pastilles.tuile(str(items.size() - deleguees), "Sous ton contrôle", Pastilles.BLEU, Charte.PANNEAU_2, 40, "StaffSousControle")
	var t2 := Pastilles.tuile(str(deleguees), "Déléguées", Pastilles.VIOLET, Charte.PANNEAU_2, 40, "StaffDeleguees")
	Pastilles.poser(p, t1, 24, 70)
	Pastilles.poser(p, t2, 24 + (largeur - 60) / 2.0 + 12, 70)
	t1.custom_minimum_size.x = (largeur - 60) / 2.0 * C.density
	t2.custom_minimum_size.x = (largeur - 60) / 2.0 * C.density
	var y := 186.0
	for e: Array in items:
		var actif: bool = e[3]
		var cle := str(e[0])
		var ligne := _ligne(p, Rect2(12, y, largeur - 24, 48), "StaffDelegation_" + cle, func(): _basculer(app, cle, not actif))
		ligne.accessibility_name = "%s · %s" % [e[1], "déléguée" if actif else "sous ton contrôle"]
		Kit.texte(p, 24, y + 31, str(e[1]), Charte.IVOIRE, largeur - 250, 18)
		var c := Pastilles.VIOLET if actif else Pastilles.BLEU
		var etat := Pastilles.pastille(str(e[2]) if actif else "Toi", c, "people" if actif else "lock", "", 16)
		Pastilles.poser_a_droite(p, etat, largeur - 24, y + 9)
		y += 52

static func _contrats(app: Control, p: Panel, people: Array, largeur: float) -> void:
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var fin := people.filter(func(x: Dictionary): return x.get("contractEnd") != null and int(x.contractEnd) <= saison).size()
	var carriere: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	var tuiles := [
		[str(people.size()), "Membres", Charte.IVOIRE, "StaffTuileMembres", func(): _tableau(app, 0)],
		[str(fin), "Fin de saison", Pastilles.ORANGE if fin > 0 else Charte.IVOIRE, "StaffTuileFin", func(): _tableau(app, 0)],
		[str(carriere.get("candidates", []).size()), "Candidats", Pastilles.TURQUOISE, "StaffTuileCandidats", func(): _tableau(app, 1)],
	]
	var l := (largeur - 48 - 24) / 3.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		var tuile := Pastilles.tuile(str(t[0]), str(t[1]), t[2], Charte.PANNEAU_2, 40, str(t[3]), false, t[4])
		Pastilles.poser(p, tuile, 24 + i * (l + 12), 70)
		tuile.custom_minimum_size.x = l * C.density; tuile.size.x = l * C.density
	# Salaires des postes en plus (moteur) : total de la semaine, en orange s'il y en a.
	var total := int(projection(app).get("salaireSemaine", 0))
	Kit.texte(p, 24, 230, "POSTES EN PLUS · SEMAINE", Charte.IVOIRE_3, largeur - 48, 14)
	var montant := D.text(p, 24, 286, ("−" + G.euros(total)) if total > 0 else "0 €", 44, Pastilles.ORANGE if total > 0 else Charte.IVOIRE_3, 800, largeur - 48)
	montant.name = "StaffSalaireTotal"

## Petite fenêtre visuelle d'un service : un visage par personne (niveau coloré), postes vides en silhouette.
static func _fenetre_service(app: Control, service: Dictionary, par: Dictionary) -> void:
	var page := app.find_child("ImmersiveClub", true, false) as Control
	if page == null: return
	var id := str(service.id)
	var gens: Array = []
	for f: Dictionary in service.get("fonctions", []):
		var liste: Array = par.get(str(f.cle), [])
		for p in liste: gens.append([p, str(FONCTIONS.get(str(f.cle), ""))])
		for i in maxi(0, int(f.get("minimum", 1)) - liste.size()): gens.append([{}, str(FONCTIONS.get(str(f.cle), ""))])
	for p in par.get("enplus:" + id, []): gens.append([p, "En plus"])
	for i in maxi(0, int(service.get("cible", 0)) - par.get("enplus:" + id, []).size()): gens.append([{}, "En plus"])
	for p in par.get("surnombre:" + id, []): gens.append([p, str(p.get("roleLabel", ""))])
	var colonnes := 5
	var rangees := ceili(gens.size() / float(colonnes))
	var meta: Dictionary = SERVICES.get(id, {})
	var fond := FenetreVisuelle.ouvrir(page, "StaffFenetreService", str(meta.get("titre", "")).to_upper(), str(meta.get("icone", "people")), 1000, 120 + rangees * 190 + 20)
	for i in gens.size():
		var p: Dictionary = gens[i][0]
		var x := 28 + (i % colonnes) * 190.0
		var y := 90 + (i / colonnes) * 190.0
		var carte := D.rect(fond, Rect2(x, y, 178, 178), Charte.PANNEAU_2, 12)
		if p.is_empty():
			_silhouette(carte, Rect2(59, 18, 60, 84), {}, app, "StaffFenetreVide_%d" % i)
			D.text(carte, 89, 128, "À pourvoir", 18, Pastilles.ORANGE, 700, 170, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var visage := p.duplicate(true)
			visage.portraitRole = "staff"
			var portrait := G.portrait_lazy(0, C.px(80), visage)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			carte.add_child(portrait)
			D.place(portrait, Rect2(49, 10, 80, 90))
			var n := _niveau(p)
			var pastille := D.rect(carte, Rect2(128, 8, 42, 28), Charte.couleur_attribut(n), 6)
			D.text(pastille, 21, 21, str(n), 19, Charte.ENCRE, 800, 42, HORIZONTAL_ALIGNMENT_CENTER)
			D.text(carte, 89, 128, Kit.casse(str(p.get("name", "")), true), 18, Charte.IVOIRE, 700, 170, HORIZONTAL_ALIGNMENT_CENTER)
			var zone := Button.new()
			zone.name = "StaffFenetreFiche_%d" % i
			StaffTable.styler_rangee(zone)
			carte.add_child(zone)
			D.place(zone, Rect2(0, 0, 178, 178))
			_lier(app, zone, p)
		D.text(carte, 89, 158, str(gens[i][1]), 15, Charte.IVOIRE_2 if str(gens[i][1]) != "En plus" else Pastilles.VIOLET, 600, 170, HORIZONTAL_ALIGNMENT_CENTER)
