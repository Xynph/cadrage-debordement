extends RefCounted
## Club › Staff « par service » (revue FM27, idée n° 22, PLANCHE A/B sous CD_VARIANTE_VISUELLE, à trancher par Léo).
## Les postes viennent du moteur (staff-completion.cjs : fonctions MINIMUM et capacités lues dans l'intitulé) ; la
## couleur d'une personne = son niveau (barème des attributs), toujours doublée du chiffre. A : quatre colonnes de
## silhouettes + bandeau bas (affectations en anneaux, responsabilités, contrats). B : liste groupée par service, à la
## manière de l'Effectif (visage, fonction, nom, niveau, contrat), avec à droite le terrain des entraîneurs et les
## délégations. « Tout le staff » rend le tableau habituel.
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

## Fonctions du moteur (staff-completion.cjs, MINIMUM) rangées par service ; libellés courts.
const SERVICES := [
	{"id": "coaching", "titre": "Entraîneurs", "icone": "tactic", "role": "coach", "fonctions": [["assistant", "Adjoint", 1], ["forwards", "Avants · mêlée, touche", 1], ["backs", "Arrières · attaque, pied", 1], ["defence", "Défense", 1]]},
	{"id": "fitness", "titre": "Préparation physique", "icone": "train", "role": "fitness", "fonctions": [["fitnessLead", "Responsable", 1], ["conditioning", "Préparateur", 1], ["rehab", "Réathlétisation", 1]]},
	{"id": "medical", "titre": "Médical", "icone": "heart", "role": "medical", "fonctions": [["doctor", "Médecin", 1], ["physio", "Kinésithérapeute", 2]]},
	{"id": "club", "titre": "Recrutement et club", "icone": "search", "role": "support", "fonctions": [["scout", "Recruteur", 1], ["analyst", "Analyste vidéo", 1], ["formation", "Formation", 1], ["teamManager", "Team manager", 1], ["equipment", "Intendant", 1]]},
]
const AUTRES := "autres"
const ZONES := [["forwards", "Avants"], ["backs", "Arrières"], ["defence", "Défense"], ["assistant", "Adjoint"]]

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## La vue par service remplace l'onglet tant qu'aucune fiche n'est ouverte et que « Tout le staff » n'est pas choisi.
static func actif(app: Control) -> bool:
	if variante().is_empty() or app.route != "Staff": return false
	if not str(app.StaffViews.reading(app).get("navigation_id", "")).is_empty(): return false
	return str(app.management_ui.get(CLE_VUE, "services")) != "tous"

# --- Données : capacités et postes (portage de staff-completion.cjs) ------------------------------------------------

static func _norm(x: String) -> String:
	var t := x.to_lower()
	for paire: Array in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"], ["ô", "o"], ["û", "u"], ["ù", "u"], ["ç", "c"], ["’", "'"]]:
		t = t.replace(paire[0], paire[1])
	return t

static func _re(motif: String, texte: String) -> bool:
	var re := RegEx.new()
	re.compile(motif)
	return re.search(texte) != null

static func role_de(label: String) -> String:
	var x := _norm(label)
	if _re("medec|medical|kine|physio|doctor|osteop|infirm|soigneur|paramed", x): return "medical"
	if _re("analys|video|data scientist", x): return "analyst"
	if _re("physiq|fitness|strength|condition|preparateur|athletic|rehab|reathlet|sport scientist", x): return "fitness"
	if _re("recrut|recruit|scout", x): return "scout"
	if _re("academ|format|espoir|jeune|youth|pathway", x): return "formation"
	if _re("team manager|kit manager|operations|intendan|equip|logisti|responsable d.equipe", x): return "support"
	if _re("adjoint|assistant", x): return "assistant"
	if _re("coach|entraine|manager|directeur sportif|director of rugby|jeu au pied|touche|melee|scrum|defen", x): return "coach"
	return "support"

static func capacites(label: String) -> Array:
	var x := _norm(label)
	var r := role_de(label)
	var out: Array = []
	if r == "medical":
		if _re("medecin|doctor", x): out.append("doctor")
		if _re("kine|physio", x): out.append("physio")
		if _re("rehab|reathlet", x): out.append("rehab")
	elif r == "fitness":
		if _re("rehab|reathlet", x): out.append("rehab")
		if _re("responsable|directeur|director|head|lead|chief", x) and _re("physiq|fitness|strength|condition|performance|athletic", x): out.append("fitnessLead")
		if _re("physiq|fitness|strength|condition|athletic|sport scientist", x) and not out.has("rehab"): out.append("conditioning")
		if _re("preparateur|preparation physique|fitness coach|strength|conditioning", x) and not out.has("rehab"): out.append_array(["fitnessLead", "conditioning", "rehab"])
	elif r in ["analyst", "scout", "formation"]: out.append(r)
	elif r == "support":
		if _re("team manager|responsable d.equipe|operations manager", x): out.append("teamManager")
		if _re("intendan|kit |equipment|materiel|logisti", x + " "): out.append("equipment")
	else:
		if _re("avant|melee|scrum|touche|line.?out|forward|conquete", x): out.append("forwards")
		if _re("arriere|attaque|attack|back|jeu au pied|kicking|trois.quarts", x): out.append("backs")
		if _re("defen", x): out.append("defence")
		if _re("adjoint|assistant", x): out.append("assistant")
		if not (out.has("forwards") or out.has("backs") or out.has("defence")) and _re("coach|entraineur|entraine|adjoint", x): out.append_array(["assistant", "forwards", "backs", "defence"])
	var uniques: Array = []
	for c in out: if not uniques.has(c): uniques.append(c)
	return uniques

static func membres(app: Control) -> Array:
	for team: Dictionary in app.model.get("staff", {}).get("teams", []):
		if int(team.get("id", -1)) == int(app.model.club.id): return team.get("members", []).filter(func(p: Dictionary): return p.get("historical", false) != true)
	return []

## Affectation des personnes aux postes du moteur (couplage maximal, même méthode que staff-completion.cjs), puis les
## renforts sur leur première fonction. Rend {fonction: [personnes]} ; « autres » : sans fonction reconnue, par rôle.
static func affectation(people: Array) -> Dictionary:
	var postes: Array = []
	for service: Dictionary in SERVICES:
		for f: Array in service.fonctions:
			for i in int(f[2]): postes.append(str(f[0]))
	var caps: Array = people.map(func(p: Dictionary): return capacites(str(p.get("roleLabel", p.get("role", "")))))
	var tenu := {}  # personne -> poste
	var placer: Callable
	placer = func(poste: int, vus: Dictionary, soi: Callable) -> bool:
		for i in people.size():
			if vus.has(i) or not (caps[i] as Array).has(postes[poste]): continue
			vus[i] = true
			if not tenu.has(i) or soi.call(int(tenu[i]), vus, soi):
				tenu[i] = poste
				return true
		return false
	for poste in postes.size(): placer.call(poste, {}, placer)
	var par := {}
	for service: Dictionary in SERVICES:
		for f: Array in service.fonctions: par[str(f[0])] = []
		par[AUTRES + ":" + str(service.id)] = []
	var ordre := range(people.size())
	ordre.sort_custom(func(a: int, b: int): return int(people[a].get("level", 0)) > int(people[b].get("level", 0)))
	for i: int in ordre:
		if tenu.has(i): (par[postes[int(tenu[i])]] as Array).append(people[i])
	for i: int in ordre:
		if tenu.has(i): continue
		if not (caps[i] as Array).is_empty(): (par[str(caps[i][0])] as Array).append(people[i])
		else: (par[AUTRES + ":" + _service_du_role(role_de(str(people[i].get("roleLabel", people[i].get("role", "")))))] as Array).append(people[i])
	return par

static func _service_du_role(role: String) -> String:
	match role:
		"coach", "assistant": return "coaching"
		"fitness": return "fitness"
		"medical": return "medical"
	return "club"

static func _niveau(p: Dictionary) -> int:
	return int(p.get("level", 0)) if p.get("level") != null else 0

## Postes couverts / postes prévus d'un service, et le détail par fonction.
static func occupation(service: Dictionary, par: Dictionary) -> Vector2i:
	var tenus := 0
	var prevus := 0
	for f: Array in service.fonctions:
		prevus += int(f[2])
		tenus += mini(int(f[2]), (par[str(f[0])] as Array).size())
	return Vector2i(tenus, prevus)

static func _couleur_occupation(o: Vector2i) -> Color:
	if o.x >= o.y: return Charte.GAIN
	return Charte.INTENSIF if o.y - o.x == 1 else Charte.PERTE

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

static func _fiche(app: Control, p: Dictionary) -> void:
	app.navigation_controller.open_entity({"kind": "staff", "id": str(p.get("id", ""))})

static func _lier(app: Control, bouton: BaseButton, p: Dictionary) -> void:
	EntityLink.bind(bouton, app, {"kind": "staff", "id": str(p.get("id", ""))}, str(p.get("name", "")))
	bouton.tooltip_text = ""

# --- Petites pièces dessinées ----------------------------------------------------------------------------------------

## Silhouette d'une personne (tête + épaules) : pleine à la couleur de son niveau, en pointillé si le poste est vide.
class Silhouette extends Button:
	var couleur := Charte.IVOIRE
	var vide := false
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

static func _silhouette(parent: Control, zone: Rect2, p: Dictionary, app: Control, nom: String) -> Silhouette:
	var s := Silhouette.new()
	s.name = nom
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
	if variante().is_empty(): return
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
	var par := affectation(people)
	bascule(app, corps, true)
	if variante() == "B": _option_b(app, corps, people, par)
	else: _option_a(app, corps, people, par)

static func _panneau(parent: Control, zone: Rect2, titre: String, id: String) -> Panel:
	var p := D.rect(parent, zone, Charte.PANNEAU, 24)
	p.add_theme_stylebox_override("panel", Charte.style_panneau())
	p.name = id
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	if not titre.is_empty(): Kit.titre(p, 24, 44, titre, 26, zone.size.x - 48).name = "CardTitle"
	return p

# --- Option A : colonnes de silhouettes ------------------------------------------------------------------------------

static func _option_a(app: Control, corps: Control, people: Array, par: Dictionary) -> void:
	var haut := 214.0
	var hauteur := 600.0
	var ecart := 22.0
	var largeur := (W - ecart * 3) / 4.0
	for i in SERVICES.size():
		var service: Dictionary = SERVICES[i]
		_colonne_a(app, corps, Rect2(i * (largeur + ecart), haut, largeur, hauteur), service, par)
	var bas := haut + hauteur + 22.0
	var h_bas := 1244.0 - bas - 12.0
	var l1 := 960.0
	var l2 := 560.0
	_affectations_a(app, _panneau(corps, Rect2(0, bas, l1, h_bas), "Affectations des entraîneurs", "StaffAffectations"), par)
	_responsabilites(app, _panneau(corps, Rect2(l1 + ecart, bas, l2, h_bas), "Responsabilités", "StaffResponsabilites"), l2)
	_contrats(app, _panneau(corps, Rect2(l1 + l2 + ecart * 2, bas, W - l1 - l2 - ecart * 2, h_bas), "Contrats", "StaffContratsServices"), people, W - l1 - l2 - ecart * 2)

static func _entete_service(app: Control, p: Panel, service: Dictionary, o: Vector2i, largeur: float, par: Dictionary) -> void:
	var couleur := _couleur_occupation(o)
	var icone := C.icon(str(service.icone), 28, couleur)
	p.add_child(icone)
	D.place(icone, Rect2(24, 22, 28, 28))
	Kit.titre(p, 62, 46, str(service.titre), 26, largeur - 200)
	var compte := D.text(p, largeur - 24, 50, "%d/%d" % [o.x, o.y], 38, couleur, 800, 140, HORIZONTAL_ALIGNMENT_RIGHT)
	compte.name = "StaffServiceCompte_" + str(service.id)
	var zone := _ligne(p, Rect2(largeur - 150, 12, 136, 50), "StaffServiceOuvrir_" + str(service.id), func(): _fenetre_service(app, service, par))
	zone.accessibility_name = "%s · %d postes sur %d" % [service.titre, o.x, o.y]

static func _colonne_a(app: Control, corps: Control, zone: Rect2, service: Dictionary, par: Dictionary) -> void:
	var p := _panneau(corps, zone, "", "StaffService_" + str(service.id))
	var largeur := zone.size.x
	var o := occupation(service, par)
	_entete_service(app, p, service, o, largeur, par)
	var y := 74.0
	var rangs: Array = service.fonctions.duplicate()
	if not (par[AUTRES + ":" + str(service.id)] as Array).is_empty(): rangs.append([AUTRES + ":" + str(service.id), "Autres fonctions", 0])
	var h := minf(72.0, 420.0 / rangs.size())
	for f: Array in rangs:
		var gens: Array = par[str(f[0])]
		var prevus := int(f[2])
		var ligne := _ligne(p, Rect2(10, y, largeur - 20, h - 4), "StaffFonction_" + str(f[0]).validate_node_name(), func(): _fenetre_service(app, service, par))
		ligne.accessibility_name = "%s · %d / %d" % [f[1], gens.size(), prevus]
		var tenus := mini(gens.size(), prevus) if prevus > 0 else gens.size()
		var c := Charte.GAIN if prevus == 0 or gens.size() >= prevus else Charte.INTENSIF
		var pastille := D.rect(p, Rect2(20, y + (h - 4) / 2.0 - 13, 58, 26), Color(c, .2), 6)
		pastille.name = "StaffFonctionCompte_" + str(f[0]).validate_node_name()
		D.text(pastille, 29, 19, ("%d/%d" % [tenus, prevus]) if prevus > 0 else str(gens.size()), 18, c, 800, 58, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.texte(p, 90, y + h / 2.0 + 4, str(f[1]), Charte.IVOIRE, largeur - 290, 17)
		var slots: Array = gens.duplicate()
		for i in maxi(0, prevus - gens.size()): slots.append({})
		var sx := largeur - 70.0 - 34.0 * (slots.size() - 1)
		for i in slots.size():
			_silhouette(p, Rect2(sx + i * 34.0 - 44, y + (h - 4) / 2.0 - 21, 28, 40), slots[i], app, "StaffSilhouette_%s_%d" % [str(f[0]).validate_node_name(), i])
		if not gens.is_empty():
			var meilleur := _niveau(gens[0])
			_gras(Kit.texte(p, largeur - 22, y + h / 2.0 + 5, str(meilleur), Charte.couleur_attribut(meilleur), 40, 18, HORIZONTAL_ALIGNMENT_RIGHT))
		y += h
	D.line(p, Vector2(18, zone.size.y - 66), Vector2(largeur - 18, zone.size.y - 66), Charte.FILET)
	Kit.texte(p, 24, zone.size.y - 28, "DIRIGEANTS", Charte.IVOIRE_3, 140, 14)
	var manque := o.y - o.x
	var avis: Control
	if manque <= 0: avis = Pastilles.pastille("Satisfaits", Pastilles.VERT, "check", "", 17, "StaffAvis_" + str(service.id), func(): _fenetre_service(app, service, par))
	else: avis = Pastilles.pastille("%d poste%s à pourvoir" % [manque, "s" if manque > 1 else ""], Pastilles.ORANGE, "warning", "", 17, "StaffAvis_" + str(service.id), func(): _tableau(app, 1))
	Pastilles.poser_a_droite(p, avis, largeur - 22, zone.size.y - 48)

static func _coach(par: Dictionary, cle: String) -> Dictionary:
	var gens: Array = par.get(cle, [])
	return gens[0] if not gens.is_empty() else {}

static func _affectations_a(app: Control, p: Panel, par: Dictionary) -> void:
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
		var nom := Kit.texte(p, 24 + i * pas + pas / 2.0, 272, Kit.casse(str(coach.get("name", "Poste vide")), true), Charte.IVOIRE if not coach.is_empty() else Charte.IVOIRE_3, pas - 12, 17, HORIZONTAL_ALIGNMENT_CENTER)
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
	var moyenne := 0.0
	for x: Dictionary in people: moyenne += _niveau(x)
	if not people.is_empty():
		moyenne /= people.size()
		Kit.texte(p, 24, 230, "NIVEAU MOYEN", Charte.IVOIRE_3, 200, 14)
		D.text(p, 24, 286, str(roundi(moyenne)), 48, Charte.couleur_attribut(moyenne), 800)
		var barre_l := largeur - 48 - 110
		D.rect(p, Rect2(130, 262, barre_l, 14), Charte.PANNEAU_3, 7)
		D.rect(p, Rect2(130, 262, barre_l * clampf(moyenne / 100.0, 0, 1), 14), Charte.couleur_attribut(moyenne), 7)

## Petite fenêtre visuelle d'un service : un visage par personne (niveau coloré), postes vides en silhouette.
static func _fenetre_service(app: Control, service: Dictionary, par: Dictionary) -> void:
	var page := app.find_child("ImmersiveClub", true, false) as Control
	if page == null: return
	var gens: Array = []
	for f: Array in service.fonctions:
		var liste: Array = par[str(f[0])]
		for p in liste: gens.append([p, str(f[1])])
		for i in maxi(0, int(f[2]) - liste.size()): gens.append([{}, str(f[1])])
	for p in par[AUTRES + ":" + str(service.id)]: gens.append([p, str(p.get("roleLabel", ""))])
	var colonnes := 5
	var rangees := ceili(gens.size() / float(colonnes))
	var fond := FenetreVisuelle.ouvrir(page, "StaffFenetreService", str(service.titre).to_upper(), str(service.icone), 1000, 120 + rangees * 190 + 20)
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
		D.text(carte, 89, 158, str(gens[i][1]), 15, Charte.IVOIRE_2, 600, 170, HORIZONTAL_ALIGNMENT_CENTER)

# --- Option B : liste groupée par service, à la manière de l'Effectif ------------------------------------------------

const B_GAUCHE := 1640.0
const B_LIGNE := 50.0
const B_ENTETE := 62.0

static func _option_b(app: Control, corps: Control, people: Array, par: Dictionary) -> void:
	var p := _panneau(corps, Rect2(0, 214, B_GAUCHE, 1018), "", "StaffParService")
	# Bandeau des en-têtes de colonnes (grammaire de l'Effectif).
	var bandeau := D.rect(p, Rect2(12, 14, B_GAUCHE - 24, 40), Charte.BANDEAU_ENTETE, 6)
	bandeau.name = "StaffColonnes"
	for col: Array in [[86, "FONCTION"], [460, "NOM"], [900, "ÂGE"], [1010, "NIVEAU"], [1330, "CONTRAT"]]:
		Kit.texte(bandeau, float(col[0]), 27, str(col[1]), Charte.IVOIRE_3, 200, 14)
	var defil := ScrollContainer.new()
	defil.name = "StaffServicesDefil"
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(defil)
	D.place(defil, Rect2(12, 60, B_GAUCHE - 24, 1018 - 72))
	var contenu := Control.new()
	contenu.mouse_filter = Control.MOUSE_FILTER_PASS
	defil.add_child(contenu)
	var y := 0.0
	var l := B_GAUCHE - 24
	var saison := int(app.model.get("meta", {}).get("season", 0))
	for service: Dictionary in SERVICES:
		var o := occupation(service, par)
		var c := _couleur_occupation(o)
		var tete := D.rect(contenu, Rect2(0, y + 6, l, B_ENTETE - 10), Color(Charte.BANDEAU, 1), 8)
		tete.name = "StaffGroupe_" + str(service.id)
		var icone := C.icon(str(service.icone), 26, c)
		tete.add_child(icone)
		D.place(icone, Rect2(16, 12, 26, 26))
		Kit.titre(tete, 54, 35, str(service.titre), 24, 420)
		var compte := D.rect(tete, Rect2(470, 10, 74, 32), Color(c, .22), 6)
		compte.name = "StaffGroupeCompte_" + str(service.id)
		D.text(compte, 37, 24, "%d/%d" % [o.x, o.y], 21, c, 800, 74, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.texte(tete, 556, 32, "POSTES", Charte.IVOIRE_3, 100, 14)
		var manque := o.y - o.x
		var avis: Control
		if manque <= 0: avis = Pastilles.pastille("Dirigeants satisfaits", Pastilles.VERT, "check", "", 16, "StaffAvisB_" + str(service.id), func(): _fenetre_service(app, service, par))
		else: avis = Pastilles.pastille("%d poste%s à pourvoir" % [manque, "s" if manque > 1 else ""], Pastilles.ORANGE, "warning", "", 16, "StaffAvisB_" + str(service.id), func(): _tableau(app, 1))
		Pastilles.poser_a_droite(tete, avis, l - 14, 10)
		y += B_ENTETE
		var rangs: Array = service.fonctions.duplicate()
		rangs.append([AUTRES + ":" + str(service.id), "", 0])
		for f: Array in rangs:
			var gens: Array = par[str(f[0])]
			var lignes: Array = gens.duplicate()
			for i in maxi(0, int(f[2]) - gens.size()): lignes.append({})
			for q: Dictionary in lignes:
				_ligne_b(app, contenu, y, l, q, str(f[1]) if not str(f[1]).is_empty() else str(q.get("roleLabel", "")), saison, str(f[0]))
				y += B_LIGNE
		y += 8
	contenu.custom_minimum_size = Vector2(l, y) * C.density
	var droite := B_GAUCHE + 22.0
	var lr := W - droite
	_terrain_b(app, _panneau(corps, Rect2(droite, 214, lr, 470), "Sur le terrain", "StaffTerrain"), par, lr)
	_delegations_b(app, _panneau(corps, Rect2(droite, 706, lr, 250), "Délégations", "StaffDelegationsB"), lr)
	_contrats_b(app, _panneau(corps, Rect2(droite, 978, lr, 254), "Contrats", "StaffContratsB"), people, lr)

static func _ligne_b(app: Control, parent: Control, y: float, l: float, q: Dictionary, fonction: String, saison: int, cle: String) -> void:
	var vide := q.is_empty()
	var ligne := _ligne(parent, Rect2(0, y, l, B_LIGNE - 2), "StaffLigneB_%s_%s" % [cle.validate_node_name(), str(q.get("id", "vide")).validate_node_name()], func(): _tableau(app, 1))
	if vide:
		ligne.accessibility_name = fonction + " · poste à pourvoir"
		var s := _silhouette(parent, Rect2(22, y + 7, 26, 36), {}, app, "StaffLigneBVide_%s_%d" % [cle.validate_node_name(), int(y)])
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.texte(parent, 86, y + 32, fonction, Charte.IVOIRE_2, 360, 17)
		Pastilles.poser(parent, Pastilles.pastille("Poste à pourvoir", Pastilles.ORANGE, "search", "", 16), 460, y + 10)
		return
	ligne.pressed.disconnect(ligne.pressed.get_connections()[0].callable)
	_lier(app, ligne, q)
	ligne.accessibility_name = "%s · %s" % [fonction, q.get("name", "")]
	var visage := q.duplicate(true)
	visage.portraitRole = "staff"
	var portrait := G.portrait_lazy(0, C.px(40), visage)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(portrait)
	D.place(portrait, Rect2(16, y + 3, 40, 44))
	Kit.texte(parent, 86, y + 32, fonction, Charte.IVOIRE_2, 360, 17)
	_gras(Kit.texte(parent, 460, y + 32, Kit.casse(str(q.get("name", ""))), Charte.IVOIRE, 420, 18))
	if q.get("age") != null: Kit.texte(parent, 900, y + 32, str(int(q.age)), Charte.IVOIRE, 80, 18)
	var n := _niveau(q)
	var pastille := D.rect(parent, Rect2(1010, y + 10, 48, 28), Charte.couleur_attribut(n), 6)
	D.text(pastille, 24, 21, str(n), 19, Charte.ENCRE, 800, 48, HORIZONTAL_ALIGNMENT_CENTER)
	D.rect(parent, Rect2(1072, y + 20, 220, 8), Charte.PANNEAU_3, 4)
	D.rect(parent, Rect2(1072, y + 20, 220 * clampf(n / 100.0, 0, 1), 8), Charte.couleur_attribut(n), 4)
	if q.get("contractEnd") != null:
		var finit: bool = int(q.contractEnd) <= saison
		Kit.texte(parent, 1330, y + 32, ("! fin " if finit else "fin ") + G.season_label(q.contractEnd), Pastilles.ORANGE if finit else Charte.IVOIRE, 260, 17)

## Terrain des entraîneurs : une rangée par zone (visage, nom, barre colorée du niveau) ; clic = fiche.
static func _terrain_b(app: Control, p: Panel, par: Dictionary, l: float) -> void:
	var y := 70.0
	for z: Array in ZONES:
		var coach := _coach(par, str(z[0]))
		var n := _niveau(coach)
		var ligne := _ligne(p, Rect2(12, y, l - 24, 92), "StaffZoneB_" + str(z[0]), func(): _tableau(app, 1))
		Kit.texte(p, 24, y + 26, str(z[1]).to_upper(), Charte.IVOIRE_3, 200, 14)
		if coach.is_empty():
			_silhouette(p, Rect2(24, y + 36, 34, 48), {}, app, "StaffZoneBVide_" + str(z[0])).mouse_filter = Control.MOUSE_FILTER_IGNORE
			Pastilles.poser(p, Pastilles.pastille("Poste vide", Pastilles.ORANGE, "warning", "", 16), 80, y + 46)
		else:
			ligne.pressed.disconnect(ligne.pressed.get_connections()[0].callable)
			_lier(app, ligne, coach)
			var visage := coach.duplicate(true)
			visage.portraitRole = "staff"
			var portrait := G.portrait_lazy(0, C.px(44), visage)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(portrait)
			D.place(portrait, Rect2(22, y + 34, 44, 50))
			_gras(Kit.texte(p, 80, y + 58, Kit.casse(str(coach.get("name", "")), true), Charte.IVOIRE, l - 220, 18))
			var bl := l - 24 - 80 - 80
			D.rect(p, Rect2(80, y + 70, bl, 10), Charte.PANNEAU_3, 5)
			D.rect(p, Rect2(80, y + 70, bl * clampf(n / 100.0, 0, 1), 10), Charte.couleur_attribut(n), 5)
			D.text(p, l - 24, y + 66, str(n), 30, Charte.couleur_attribut(n), 800, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 98

static func _delegations_b(app: Control, p: Panel, l: float) -> void:
	var y := 70.0
	for e: Array in _delegations(app):
		var actif: bool = e[3]
		var cle := str(e[0])
		var ligne := _ligne(p, Rect2(12, y, l - 24, 76), "StaffDelegationB_" + cle, func(): _basculer(app, cle, not actif))
		ligne.accessibility_name = "%s · %s" % [e[1], "déléguée" if actif else "sous ton contrôle"]
		_gras(Kit.texte(p, 24, y + 32, str(e[1]), Charte.IVOIRE, l - 200, 18))
		Kit.texte(p, 24, y + 60, (str(e[2]) if actif else "Toi").to_upper(), Pastilles.VIOLET if actif else Pastilles.BLEU, 200, 15)
		# Interrupteur dessiné : pilule + pastille ronde (couleur + position + mot).
		var x := l - 24 - 84
		D.rect(p, Rect2(x, y + 22, 84, 34), Color(Pastilles.VIOLET, .35) if actif else Charte.PANNEAU_3, 17)
		D.rect(p, Rect2(x + (52 if actif else 4), y + 25, 28, 28), Pastilles.VIOLET if actif else Charte.IVOIRE_3, 14)
		y += 82

static func _contrats_b(app: Control, p: Panel, people: Array, l: float) -> void:
	var saison := int(app.model.get("meta", {}).get("season", 0))
	var fin := people.filter(func(x: Dictionary): return x.get("contractEnd") != null and int(x.contractEnd) <= saison).size()
	var carriere: Dictionary = app.model.get("clubLife", {}).get("staffCareer", {})
	var tuiles := [
		[str(people.size()), "Membres", Charte.IVOIRE, "StaffTuileBMembres", func(): _tableau(app, 0)],
		[str(fin), "Fin de saison", Pastilles.ORANGE if fin > 0 else Charte.IVOIRE, "StaffTuileBFin", func(): _tableau(app, 0)],
		[str(carriere.get("candidates", []).size()), "Candidats", Pastilles.TURQUOISE, "StaffTuileBCandidats", func(): _tableau(app, 1)],
	]
	var lt := (l - 48 - 24) / 3.0
	for i in tuiles.size():
		var t: Array = tuiles[i]
		var tuile := Pastilles.tuile(str(t[0]), str(t[1]), t[2], Charte.PANNEAU_2, 36, str(t[3]), false, t[4])
		Pastilles.poser(p, tuile, 24 + i * (lt + 12), 76)
		tuile.custom_minimum_size.x = lt * C.density; tuile.size.x = lt * C.density
