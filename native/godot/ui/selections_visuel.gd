extends RefCounted
## Sélections › Offres et Disponibilités : deux options visuelles à départager (planche de choix du 21/11/2026).
## CD_VARIANTE_VISUELLE=A : tuiles drapeaux (offres en grille, fenêtres en tuiles).
## CD_VARIANTE_VISUELLE=B : frise des 90 jours (fenêtres en bandes datées, offres rangées par compétition).
## Sans la variable : écran actuel inchangé (aucune de ces fonctions n'est appelée).
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const PALETTE := [Charte.MORAL, Charte.CONFIANCE, Charte.REPOS, Charte.INTENSIF, Charte.CONDITION, Charte.PERTE]
const DUAL := Charte.MORAL
const SEULE := Charte.CONFIANCE

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

# ---------------------------------------------------------------- petites pièces (conteneurs)

static func _iv() -> GDScript: return load("res://ui/international_view.gd")

## Les styles de ces écrans sont posés ici : le style hérité ne doit pas repasser dessus.
static func marquer(noeud: Node) -> Node:
	if noeud is Control: noeud.set_meta("immersive_style_applied", true)
	for enfant in noeud.get_children(): marquer(enfant)
	return noeud

static func _date(iso: Variant) -> String:
	var parts := str(iso).split("-")
	if parts.size() != 3 or not parts[1].is_valid_int(): return "—"
	return "%d %s" % [int(parts[2]), MOIS[clampi(int(parts[1]) - 1, 0, 11)]]

static func _jours(iso: String) -> float:
	return Time.get_unix_time_from_datetime_string(iso + "T00:00:00") / 86400.0

static func _couleur(cle: String) -> Color:
	return PALETTE[posmod(cle.hash(), PALETTE.size())]

static func _boite(fond: Color, bord: Color = Color.TRANSPARENT, rayon: int = Charte.RAYON_CARTE, marge: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	if bord != Color.TRANSPARENT: s.set_border_width_all(maxi(1, C.px(2)))
	s.set_corner_radius_all(C.px(rayon) if rayon < Charte.RAYON_PILULE else 999)
	s.set_content_margin_all(C.px(marge))
	return s

## Rend tout un cadre cliquable (survol crème léger) : bouton plat posé par-dessus.
static func _cliquable(cadre: Control, action: Callable, id: String, libelle: String) -> void:
	var b := Button.new()
	b.name = id
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var survol := _boite(Color(Charte.IVOIRE, .08))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", _boite(Color.TRANSPARENT, Charte.IVOIRE))
	b.accessibility_name = libelle
	b.tooltip_text = libelle
	b.pressed.connect(action)
	cadre.add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Tuile de chiffre (gros chiffre en couleur + légende courte), fond teinté.
static func _tuile(valeur: String, legende: String, couleur: Color, icone: String = "", action: Callable = Callable(), id: String = "") -> PanelContainer:
	var carte := PanelContainer.new()
	carte.name = id if not id.is_empty() else "Tuile_" + legende.validate_node_name()
	carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2.lerp(couleur, .14), Color.TRANSPARENT, Charte.RAYON_CARTE, 14))
	var col := C.v(2)
	carte.add_child(col)
	var haut := C.h(8)
	col.add_child(haut)
	var chiffre := C.label(valeur, 34, couleur, true, 800)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	C.fill(chiffre)
	haut.add_child(chiffre)
	if not icone.is_empty(): haut.add_child(C.icon(icone, 22, couleur))
	col.add_child(C.label(legende.to_upper(), 14, Charte.IVOIRE_2, true, 700))
	if action.is_valid(): _cliquable(carte, action, carte.name + "Lien", "%s %s" % [valeur, legende])
	return carte

## Pilule colorée cliquable (icône + mot court).
static func _pilule(texte: String, couleur: Color, action: Callable, id: String, icone: String = "", taille: int = 18) -> Button:
	var b := Button.new()
	b.name = id
	b.text = texte
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", C.BOLD)
	b.add_theme_font_size_override("font_size", maxi(13, C.px(taille)))
	var normal := _boite(Charte.PANNEAU_3.lerp(couleur, .22), Color.TRANSPARENT, Charte.RAYON_PILULE, 8)
	normal.content_margin_left = C.px(14); normal.content_margin_right = C.px(14)
	normal.content_margin_top = C.px(5); normal.content_margin_bottom = C.px(5)
	var survol: StyleBoxFlat = normal.duplicate()
	survol.bg_color = Charte.PANNEAU_3.lerp(couleur, .42)
	var focus: StyleBoxFlat = normal.duplicate()
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", focus)
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(etat, couleur.lerp(Charte.IVOIRE, .25))
	if not icone.is_empty():
		b.icon = C.icon_texture(icone, couleur.lerp(Charte.IVOIRE, .25))
		b.add_theme_constant_override("icon_max_width", C.px(18))
	b.pressed.connect(action)
	return b

## Pastille d'état non cliquable (icône + mot).
static func _pastille(texte: String, couleur: Color, icone: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Pastille_" + texte.validate_node_name()
	var s := _boite(Charte.PANNEAU_3.lerp(couleur, .18), Color.TRANSPARENT, Charte.RAYON_PETIT, 6)
	s.content_margin_left = C.px(10); s.content_margin_right = C.px(10)
	p.add_theme_stylebox_override("panel", s)
	var r := C.h(6)
	p.add_child(r)
	if not icone.is_empty(): r.add_child(C.icon(icone, 18, couleur))
	r.add_child(C.label(texte, 22, couleur, true, 700))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p

static func _drapeau(app: Control, nation_id: String, largeur: int) -> Control:
	var d: Control = _iv().nation_badge(_iv().team_by_id(app.model, nation_id), largeur)
	d.custom_minimum_size = Vector2(C.px(largeur), C.px(largeur * .7))
	return d

static func _ouvrir_nation(app: Control, nation_id: String) -> void:
	_fermer_fenetre(app)
	app.navigation_controller.open_entity({"kind": "nation", "id": nation_id})

## Puce nation avec son drapeau (annuaire, frise, fenêtres) : mène à la fiche de la sélection.
static func puce_nation(app: Control, nation_id: String, nom: String, largeur_drapeau: int = 28) -> Button:
	var b := Button.new()
	b.name = "OpenNation_" + nation_id.validate_node_name()
	b.text = nom
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", C.BOLD)
	b.add_theme_font_size_override("font_size", maxi(13, C.px(21)))
	var normal := _boite(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PILULE, 6)
	normal.content_margin_left = C.px(8); normal.content_margin_right = C.px(12)
	var survol: StyleBoxFlat = normal.duplicate()
	survol.bg_color = Charte.SELECTION
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", _boite(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(etat, Charte.IVOIRE)
	var equipe: Dictionary = _iv().team_by_id(app.model, nation_id)
	var code := str(equipe.get("flagCode", "")).to_lower()
	var chemin := "res://art/flags/%s.svg" % code
	if not code.is_empty() and ResourceLoader.exists(chemin):
		b.icon = load(chemin)
		b.add_theme_constant_override("icon_max_width", C.px(largeur_drapeau))
	b.accessibility_name = "Consulter la sélection · " + nom
	b.tooltip_text = b.accessibility_name
	b.set_meta("entity_kind", "nation")
	b.set_meta("entity_id", nation_id)
	b.pressed.connect(_ouvrir_nation.bind(app, nation_id))
	return b

# ---------------------------------------------------------------- petite fenêtre visuelle

static func _fermer_fenetre(app: Control) -> void:
	var ancien := app.get_node_or_null("SelectionsPetiteFenetre")
	if ancien != null:
		ancien.remove_from_group(PetiteFenetre.GROUPE)
		ancien.queue_free()

## Petite fenêtre centrée : titre (drapeau éventuel), ✕, contenu fourni par `remplir(conteneur)`. Échap, ✕, clic à côté la ferment.
static func fenetre(app: Control, titre: String, nation_id: String, couleur: Color, remplir: Callable) -> Control:
	_fermer_fenetre(app)
	var calque := Control.new()
	calque.name = "SelectionsPetiteFenetre"
	calque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.add_child(calque)
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := ColorRect.new()
	voile.name = "SelectionsPetiteFenetreACote"
	voile.color = Color(0, 0, 0, .45)
	calque.add_child(voile)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fermer := func(): _fermer_fenetre(app)
	voile.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed: fermer.call())
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cadre := PanelContainer.new()
	cadre.name = "SelectionsPetiteFenetreCadre"
	cadre.custom_minimum_size.x = C.px(560)
	var style := _boite(Charte.PANNEAU, couleur, Charte.RAYON_PANNEAU, 20)
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(style, Charte.RAYON_PANNEAU))
	centre.add_child(cadre)
	var col := C.v(14)
	cadre.add_child(col)
	var tete := C.h(12)
	col.add_child(tete)
	if not nation_id.is_empty(): tete.add_child(_drapeau(app, nation_id, 64))
	var t := C.label(titre, 30, Charte.IVOIRE, true, 800)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	C.fill(t)
	tete.add_child(t)
	var croix := _pilule("✕", Charte.IVOIRE_2, fermer, "SelectionsPetiteFenetreFermer", "", 20)
	croix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(croix)
	remplir.call(col)
	marquer(calque)
	PetiteFenetre.enregistrer(calque, fermer)
	return calque

# ---------------------------------------------------------------- en-tête et annuaire

## Annuaire « Les sélections » : chaque puce porte son drapeau.
static func annuaire(app: Control, parent: Control, international: Dictionary) -> void:
	var flux := HFlowContainer.new()
	flux.name = "InternationalNationLinks"
	flux.add_theme_constant_override("h_separation", C.px(8))
	flux.add_theme_constant_override("v_separation", C.px(8))
	parent.add_child(C.label("LES SÉLECTIONS", 18, C.GOLD, true, 700))
	parent.add_child(flux)
	for team: Dictionary in international.get("teams", []):
		flux.add_child(puce_nation(app, str(team.id), str(team.name), 26))
	marquer(flux)

# ---------------------------------------------------------------- Offres

static func _prendre(app: Control, nation: String, nom: String, role: String) -> void:
	_fermer_fenetre(app)
	_iv()._take(app, nation, nom, role)

static func _boutons_offre(app: Control, parent: Control, job: Dictionary, role: String, taille: int = 17) -> void:
	var nation := str(job.nation)
	var nom := str(job.get("name", nation))
	if role != "nation":
		var dual := _pilule("Club + sélection", DUAL, _prendre.bind(app, nation, nom, "dual"), "NationalJobDual_" + nation, "shield", taille)
		parent.add_child(dual)
	var seule := _pilule("Sélection seule", SEULE, _prendre.bind(app, nation, nom, "nation"), "NationalJobOnly_" + nation, "flag", taille)
	parent.add_child(seule)

static func _jobs(app: Control, international: Dictionary) -> Array:
	var jobs: Array = international.get("jobs", []).duplicate()
	var demande := str(app.management_ui.get("international_nation", ""))
	for i in jobs.size():
		if str(jobs[i].nation) == demande:
			jobs.push_front(jobs.pop_at(i))
			break
	return jobs

static func _pied_offres(app: Control, view: Control, role: String) -> void:
	if role != "dual": return
	var current: Dictionary = _iv().managed_team(app.model)
	var ligne := C.h(10)
	view.add_child(ligne)
	if not current.is_empty():
		var plein := _pilule("Se consacrer à la sélection", SEULE, _iv()._take.bind(app, current.id, current.name, "nation"), "NationalJobCurrentOnly", "flag")
		ligne.add_child(plein)
	ligne.add_child(_pilule("Quitter la sélection", Charte.PERTE, func():
		app.confirm("Quitter la sélection", "Ta carrière en club continue.", func(): app._command("national_leave_job", {"confirmed": true})), "NationalJobLeave", "arrow"))

## Option A : grille de tuiles drapeaux, deux pilules courtes par pays.
static func offres_a(app: Control, international: Dictionary, role: String) -> Control:
	var view := C.v(12)
	view.name = "Offres"
	var jobs := _jobs(app, international)
	var tete := C.h(10)
	view.add_child(tete)
	tete.add_child(_pastille("%d postes ouverts" % jobs.size(), Charte.INTENSIF, "flag"))
	tete.add_child(_pastille("Club + sélection", DUAL, "shield"))
	tete.add_child(_pastille("Sélection seule", SEULE, "flag"))
	var grille := GridContainer.new()
	grille.name = "OffresGrille"
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", C.px(12))
	grille.add_theme_constant_override("v_separation", C.px(12))
	view.add_child(grille)
	for job: Dictionary in jobs:
		var nation := str(job.nation)
		var carte := PanelContainer.new()
		carte.name = "OffreTuile_" + nation.validate_node_name()
		C.fill(carte)
		carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 12))
		grille.add_child(carte)
		var col := C.v(8)
		carte.add_child(col)
		var tete_pays := C.h(10)
		col.add_child(tete_pays)
		var drapeau := _drapeau(app, nation, 56)
		tete_pays.add_child(drapeau)
		var nom := C.label(str(job.get("name", nation)), 24, Charte.IVOIRE, true, 800)
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		C.fill(nom)
		tete_pays.add_child(nom)
		_cliquable(tete_pays, _ouvrir_nation.bind(app, nation), "OffreNation_" + nation.validate_node_name(), "Consulter la sélection · " + str(job.get("name", nation)))
		_boutons_offre(app, col, job, role, 23)
	if jobs.is_empty(): view.add_child(_pastille("Aucun poste ouvert", Charte.IVOIRE_2, "flag"))
	_pied_offres(app, view, role)
	return marquer(view)

## Compétition à venir d'une nation (fenêtre des 90 jours, sinon première rencontre annoncée).
static func _competition_de(international: Dictionary, nation: String, today: String) -> Dictionary:
	var dispo: Dictionary = international.get("availability", {}) if international.get("availability") is Dictionary else {}
	for w: Dictionary in dispo.get("windows", []):
		for n: Dictionary in w.get("nations", []):
			if str(n.get("id", "")) == nation: return {"cle": str(w.competitionId), "nom": str(w.competitionName), "from": str(w.from), "through": str(w.through)}
	var meilleur := {}
	for edition: Dictionary in international.get("editions", []):
		for f: Dictionary in edition.get("fixtures", []):
			if f.get("homeId") != nation and f.get("awayId") != nation: continue
			var d := str(f.get("date", ""))
			if d < today or f.get("result") is Dictionary: continue
			if meilleur.is_empty() or d < str(meilleur.from):
				meilleur = {"cle": str(edition.get("id", "")), "nom": str(edition.get("name", edition.get("id", ""))), "from": d, "through": ""}
	return meilleur

## Option B : offres rangées par compétition, un drapeau par pays ; le choix se fait dans une petite fenêtre.
static func offres_b(app: Control, international: Dictionary, role: String) -> Control:
	var view := C.v(12)
	view.name = "Offres"
	var jobs := _jobs(app, international)
	var today: String = _iv()._today(app.model)
	var groupes := {}
	var ordre: Array = []
	for job: Dictionary in jobs:
		var comp := _competition_de(international, str(job.nation), today)
		var cle := str(comp.get("cle", "")) if not comp.is_empty() else "_"
		if not groupes.has(cle):
			groupes[cle] = {"comp": comp, "jobs": []}
			ordre.append(cle)
		groupes[cle].jobs.append(job)
	ordre.sort_custom(func(a: String, b: String):
		var fa := str(groupes[a].comp.get("from", "9999")) if a != "_" else "9999"
		var fb := str(groupes[b].comp.get("from", "9999")) if b != "_" else "9999"
		return fa < fb)
	for cle: String in ordre:
		var comp: Dictionary = groupes[cle].comp
		var couleur := _couleur(cle) if cle != "_" else Charte.IVOIRE_2
		var carte := PanelContainer.new()
		carte.name = "OffresGroupe_" + cle.validate_node_name()
		carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 12))
		view.add_child(carte)
		var rang := C.h(14)
		carte.add_child(rang)
		var barre := ColorRect.new()
		barre.color = couleur
		barre.custom_minimum_size.x = C.px(6)
		rang.add_child(barre)
		var col := C.v(8)
		C.fill(col)
		rang.add_child(col)
		var tete := C.h(10)
		col.add_child(tete)
		tete.add_child(C.icon("trophy" if cle != "_" else "calendar", 24, couleur))
		tete.add_child(C.label(str(comp.get("nom", "Sans match annoncé")) if cle != "_" else "Sans match annoncé", 24, couleur.lerp(Charte.IVOIRE, .2), true, 800))
		if cle != "_" and not str(comp.get("from", "")).is_empty():
			var dates := _date(comp.from) + ((" → " + _date(comp.through)) if not str(comp.get("through", "")).is_empty() else "")
			tete.add_child(_pastille(dates, couleur, "calendar"))
		tete.add_child(_pastille(str(groupes[cle].jobs.size()), Charte.IVOIRE_2, "flag"))
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", C.px(8))
		flux.add_theme_constant_override("v_separation", C.px(8))
		col.add_child(flux)
		for job: Dictionary in groupes[cle].jobs:
			var nation := str(job.nation)
			var nom := str(job.get("name", nation))
			var b := puce_nation(app, nation, nom, 36)
			b.name = "OffrePays_" + nation.validate_node_name()
			for c in b.pressed.get_connections(): b.pressed.disconnect(c.callable)
			b.add_theme_font_size_override("font_size", maxi(13, C.px(21)))
			b.accessibility_name = "Poste de sélectionneur · " + nom
			b.tooltip_text = b.accessibility_name
			b.pressed.connect(_fenetre_offre.bind(app, job, role, comp, couleur))
			flux.add_child(b)
	if jobs.is_empty(): view.add_child(_pastille("Aucun poste ouvert", Charte.IVOIRE_2, "flag"))
	_pied_offres(app, view, role)
	return marquer(view)

static func _fenetre_offre(app: Control, job: Dictionary, role: String, comp: Dictionary, couleur: Color) -> void:
	var nation := str(job.nation)
	fenetre(app, str(job.get("name", nation)), nation, couleur, func(col: VBoxContainer):
		var tuiles := C.h(10)
		col.add_child(tuiles)
		if not comp.is_empty():
			var t1 := _tuile(_date(comp.get("from", "")), "Prochain rendez-vous", couleur, "calendar")
			C.fill(t1)
			tuiles.add_child(t1)
			var t2 := _tuile(str(comp.get("nom", "")), "Compétition", couleur, "trophy")
			C.fill(t2)
			tuiles.add_child(t2)
		var fiche := _tuile("Fiche", "La sélection", Charte.IVOIRE, "globe", _ouvrir_nation.bind(app, nation), "OffreFenetreFiche")
		C.fill(fiche)
		tuiles.add_child(fiche)
		var choix := C.h(10)
		col.add_child(choix)
		_boutons_offre(app, choix, job, role, 22))

# ---------------------------------------------------------------- Disponibilités

static func _chiffres(app: Control, state: Dictionary) -> Array:
	var count := int(state.get("absentCount", 0))
	var ouvrir_convocations := func():
		app.management_ui.international_section = "callups"
		app._render(false)
	return [
		[str(count), "Joueurs en sélection", Charte.INTENSIF if count > 0 else Charte.CONDITION, "people", ouvrir_convocations, "DispoTuileConvoques"],
		[_date(state.get("nextReturn")) if count > 0 else "Au complet", "Prochain retour", Charte.CONDITION, "calendar", func(): app._navigate("Calendrier"), "DispoTuileRetour"],
		[str(state.get("positions", []).size()), "Postes concernés", Charte.MORAL, "shield", func(): app._navigate("Composition"), "DispoTuilePostes"],
	]

## Carte d'un joueur (absent ou revenu) : portrait, drapeau, pastilles ; toute la carte mène à sa fiche.
static func _carte_joueur(app: Control, player: Dictionary, revenu: bool) -> Control:
	var carte := PanelContainer.new()
	carte.name = "InternationalAbsence_" + str(player.id).replace(":", "_")
	carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 12))
	var rang := C.h(14)
	carte.add_child(rang)
	var connu: Dictionary = player
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == str(player.get("id", "")): connu = p
	var visage := G.portrait(posmod(str(player.get("id", player.name)).hash(), 32), C.px(72), connu)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(visage)
	var col := C.v(6)
	C.fill(col)
	rang.add_child(col)
	var ligne := C.h(10)
	col.add_child(ligne)
	ligne.add_child(C.label(str(player.name), 26, Charte.IVOIRE, true, 800))
	ligne.add_child(_pastille(str(player.pos), Charte.IVOIRE_2))
	var etats := C.h(8)
	col.add_child(etats)
	var drap := _drapeau(app, str(player.get("nation", "")), 34)
	drap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	etats.add_child(drap)
	etats.add_child(_pastille(str(player.get("nationName", "")), Charte.IVOIRE))
	etats.add_child(_pastille(str(player.get("competitionName", "")), _couleur(str(player.get("competitionId", ""))), "trophy"))
	if revenu: etats.add_child(_pastille("De retour · " + _date(player.get("returnDate")), Charte.CONDITION, "check"))
	else: etats.add_child(_pastille("Retour · " + _date(player.get("returnDate")), Charte.INTENSIF, "clock"))
	_cliquable(carte, func():
		app.selected_player = str(player.id)
		app._navigate("Effectif"), "InternationalAbsencePlayer_" + str(player.id).replace(":", "_"), "Voir la fiche · " + str(player.name))
	return carte

static func _joueurs(app: Control, view: Control, state: Dictionary) -> void:
	if not state.get("clubManaged", false): return
	if int(state.get("absentCount", 0)) > 0:
		for player: Dictionary in state.get("players", []): view.add_child(_carte_joueur(app, player, false))
		var postes := C.h(10)
		view.add_child(postes)
		for position: Dictionary in state.get("positions", []):
			var couleur := Charte.PERTE if int(position.available) == 0 else Charte.CONDITION
			var t := _tuile("%d / %d" % [position.available, position.total], str(position.position), couleur, "people", func(): app._navigate("Composition"), "DispoPoste_" + str(position.position).validate_node_name())
			postes.add_child(t)
	if not state.get("returned", []).is_empty():
		view.add_child(C.label("RETOURS · 7 JOURS", 20, Charte.IVOIRE_2, true, 700))
		for player: Dictionary in state.returned: view.add_child(_carte_joueur(app, player, true))

static func _fenetre_window(app: Control, w: Dictionary, couleur: Color) -> void:
	fenetre(app, str(w.competitionName), "", couleur, func(col: VBoxContainer):
		var tuiles := C.h(10)
		col.add_child(tuiles)
		for t: Control in [_tuile(_date(w.from), "Début", couleur, "calendar"), _tuile(_date(w.through), "Fin", couleur, "calendar"), _tuile(str(w.nations.size()), "Sélections", couleur, "flag")]:
			C.fill(t)
			tuiles.add_child(t)
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", C.px(8))
		flux.add_theme_constant_override("v_separation", C.px(8))
		col.add_child(flux)
		for n: Dictionary in w.nations: flux.add_child(puce_nation(app, str(n.id), str(n.name), 34))
		col.add_child(_pastille("Convocations à venir", Charte.INTENSIF, "clock")))

## Option A : chiffres en tuiles, fenêtres en tuiles drapeaux.
static func disponibilites_a(app: Control) -> Control:
	var view := C.v(14)
	view.name = "Disponibilités"
	var state: Dictionary = load("res://ui/international_availability.gd").data(app.model)
	if state.is_empty(): return view
	var chiffres := C.h(12)
	view.add_child(chiffres)
	for c: Array in _chiffres(app, state):
		var t := _tuile(c[0], c[1], c[2], c[3], c[4], c[5])
		C.fill(t)
		chiffres.add_child(t)
	_joueurs(app, view, state)
	view.add_child(C.label("FENÊTRES · 90 JOURS", 20, Charte.IVOIRE_2, true, 700))
	var grille := GridContainer.new()
	grille.name = "DispoFenetres"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", C.px(12))
	grille.add_theme_constant_override("v_separation", C.px(12))
	view.add_child(grille)
	for w: Dictionary in state.get("windows", []):
		var couleur := _couleur(str(w.competitionId))
		var carte := PanelContainer.new()
		carte.name = "DispoFenetre_" + (str(w.competitionId) + str(w.from)).validate_node_name()
		C.fill(carte)
		carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2.lerp(couleur, .10), Color.TRANSPARENT, Charte.RAYON_CARTE, 12))
		grille.add_child(carte)
		var col := C.v(8)
		carte.add_child(col)
		var tete := C.h(8)
		col.add_child(tete)
		tete.add_child(C.icon("trophy", 22, couleur))
		var nom := C.label(str(w.competitionName), 22, couleur.lerp(Charte.IVOIRE, .2), true, 800)
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		C.fill(nom)
		tete.add_child(nom)
		_cliquable(tete, _fenetre_window.bind(app, w, couleur), "DispoFenetreOuvrir_" + (str(w.competitionId) + str(w.from)).validate_node_name(), str(w.competitionName))
		var dates := C.label("%s → %s" % [_date(w.from), _date(w.through)], 30, Charte.IVOIRE, true, 800)
		dates.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		col.add_child(dates)
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", C.px(6))
		flux.add_theme_constant_override("v_separation", C.px(6))
		col.add_child(flux)
		for n: Dictionary in w.nations: flux.add_child(puce_nation(app, str(n.id), str(n.name), 26))
		col.add_child(_pastille("Convocations à venir", Charte.INTENSIF, "clock"))
	if state.get("windows", []).is_empty(): view.add_child(_pastille("Aucune fenêtre", Charte.CONDITION, "check"))
	return marquer(view)

## Option B : frise des 90 jours, une bande par fenêtre, drapeaux des nations engagées au bout.
static func disponibilites_b(app: Control) -> Control:
	var view := C.v(14)
	view.name = "Disponibilités"
	var state: Dictionary = load("res://ui/international_availability.gd").data(app.model)
	if state.is_empty(): return view
	var chiffres := C.h(10)
	view.add_child(chiffres)
	for c: Array in _chiffres(app, state):
		chiffres.add_child(_pilule("%s · %s" % [c[0], c[1]], c[2], c[4], c[5], c[3], 23))
	view.add_child(_frise(app, state))
	_joueurs(app, view, state)
	return marquer(view)

static func _frise(app: Control, state: Dictionary) -> Control:
	var carte := PanelContainer.new()
	carte.name = "DispoFrise"
	carte.add_theme_stylebox_override("panel", _boite(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 14))
	var windows: Array = state.get("windows", [])
	var debut := str(state.get("date", ""))
	var fin := str(state.get("horizonDate", ""))
	var j0 := _jours(debut)
	var j1 := maxf(j0 + 1.0, _jours(fin))
	var toile := Control.new()
	toile.name = "DispoFriseToile"
	var rangee := C.px(80)
	var haut_axe := C.px(40)
	var gauche := C.px(340)
	toile.custom_minimum_size.y = haut_axe + rangee * maxi(1, windows.size())
	carte.add_child(toile)
	var lignes: Array = []
	for i in windows.size():
		var w: Dictionary = windows[i]
		var couleur := _couleur(str(w.competitionId))
		var id := (str(w.competitionId) + str(w.from)).validate_node_name()
		# Colonne de gauche : compétition et dates, cliquable (petite fenêtre).
		var titre := C.v(0)
		titre.name = "DispoFriseTitre_" + id
		toile.add_child(titre)
		var l1 := C.h(6)
		titre.add_child(l1)
		l1.add_child(C.icon("trophy", 20, couleur))
		l1.add_child(C.label(str(w.competitionName), 20, couleur.lerp(Charte.IVOIRE, .2), true, 800))
		titre.add_child(C.label("%s → %s" % [_date(w.from), _date(w.through)], 18, Charte.IVOIRE_2, true, 700))
		_cliquable(titre, _fenetre_window.bind(app, w, couleur), titre.name + "Lien", str(w.competitionName))
		# Bande datée sur la frise.
		var bande := PanelContainer.new()
		bande.name = "DispoBande_" + id
		bande.add_theme_stylebox_override("panel", _boite(couleur, Color.TRANSPARENT, Charte.RAYON_PETIT, 0))
		bande.tooltip_text = "%s · %s → %s" % [w.competitionName, _date(w.from), _date(w.through)]
		toile.add_child(bande)
		_cliquable(bande, _fenetre_window.bind(app, w, couleur), bande.name + "Lien", str(w.competitionName))
		# Drapeaux des nations engagées sous la bande.
		var drapeaux := C.h(4)
		drapeaux.name = "DispoBande_" + id + "Drapeaux"
		toile.add_child(drapeaux)
		for k in mini(7, w.nations.size()):
			var n: Dictionary = w.nations[k]
			var d := Button.new()
			d.name = "DispoDrapeau_" + str(n.id).validate_node_name()
			d.flat = true
			d.custom_minimum_size = Vector2(C.px(42), C.px(30))
			d.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			d.tooltip_text = str(n.name)
			d.accessibility_name = "Consulter la sélection · " + str(n.name)
			var image := _drapeau(app, str(n.id), 40)
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d.add_child(image)
			image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			d.pressed.connect(_ouvrir_nation.bind(app, str(n.id)))
			drapeaux.add_child(d)
		if w.nations.size() > 7:
			drapeaux.add_child(_pilule("+%d" % (w.nations.size() - 7), couleur, _fenetre_window.bind(app, w, couleur), "DispoBande_" + id + "Plus", "", 16))
		lignes.append({"w": w, "titre": titre, "bande": bande, "drapeaux": drapeaux})
	var placer := func():
		var zone := toile.size.x - gauche
		for i in lignes.size():
			var e: Dictionary = lignes[i]
			var y := haut_axe + i * rangee
			e.titre.position = Vector2(0, y + C.px(10))
			e.titre.size = Vector2(gauche - C.px(16), rangee - C.px(20))
			var a := clampf((_jours(str(e.w.from)) - j0) / (j1 - j0), 0, 1) * zone
			var b := clampf((_jours(str(e.w.through)) - j0 + 1) / (j1 - j0), 0, 1) * zone
			e.bande.position = Vector2(gauche + a, y + C.px(12))
			e.bande.size = Vector2(maxf(b - a, C.px(12)), C.px(20))
			var largeur_d: float = e.drapeaux.get_combined_minimum_size().x
			e.drapeaux.position = Vector2(gauche + clampf(a, 0, maxf(0, zone - largeur_d)), y + C.px(40))
			e.drapeaux.size = Vector2(largeur_d, C.px(30))
		toile.queue_redraw()
	toile.resized.connect(placer)
	toile.draw.connect(func():
		var zone := toile.size.x - gauche
		var police: Font = C.BOLD
		var taille := maxi(12, C.px(19))
		var y_axe := haut_axe - C.px(8)
		toile.draw_line(Vector2(gauche, y_axe), Vector2(toile.size.x, y_axe), Charte.IVOIRE_3, maxf(1, C.px(2)))
		for i in lignes.size() - 1:
			var y := haut_axe + (i + 1) * rangee - C.px(2)
			toile.draw_line(Vector2(0, y), Vector2(toile.size.x, y), Charte.FILET, 1.0)
		var d := Time.get_datetime_dict_from_unix_time(int(j0 * 86400))
		var annee := int(d.year)
		var mois := int(d.month) + 1
		if mois > 12:
			mois = 1
			annee += 1
		while true:
			var jj := _jours("%04d-%02d-01" % [annee, mois])
			if jj > j1: break
			var x := gauche + (jj - j0) / (j1 - j0) * zone
			toile.draw_line(Vector2(x, y_axe - C.px(10)), Vector2(x, toile.size.y), Color(Charte.IVOIRE_3, .3), 1.0)
			toile.draw_string(police, Vector2(x + C.px(6), y_axe - C.px(8)), MOIS[mois - 1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE_2)
			mois += 1
			if mois > 12:
				mois = 1
				annee += 1
		toile.draw_circle(Vector2(gauche, y_axe), C.px(7), Charte.CONDITION)
		toile.draw_string(police, Vector2(0, y_axe + C.px(6)), "AUJOURD’HUI · " + _date(debut).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.CONDITION)
		var fin_txt := _date(fin).to_upper()
		var lf := police.get_string_size(fin_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		toile.draw_string(police, Vector2(toile.size.x - lf, y_axe - C.px(8)), fin_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Charte.IVOIRE_2))
	if windows.is_empty():
		toile.add_child(_pastille("Aucune fenêtre", Charte.CONDITION, "check"))
	return carte
