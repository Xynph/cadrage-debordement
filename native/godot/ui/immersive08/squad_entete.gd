extends "res://ui/immersive08/squad_filtres.gd"
## Écran Effectif : titre, tuiles du haut, infobulle de l'équilibre par poste, onglets (découpe de squad_canvas.gd, sans changement).

# ---------------------------------------------------------------- titre et tuiles

func _entete_page() -> void:
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var joueurs: Array = app.model.get("squad", [])
	var titre_effectif := D.text(self, 0, 64, "EFFECTIF", 58, C.IVORY, 800, 600)
	titre_effectif.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre_effectif.name = "RosterTitre"
	# Sous le titre : deux pastilles neutres « 36 joueurs » et « 2026-27 » (plus de phrase, 21/11).
	var nombre := R.pastille(self, 0, 104, "%d joueur%s" % [joueurs.size(), "s" if joueurs.size() > 1 else ""], Charte.IVOIRE_2, "people", "RosterSousTitre")
	R.cliquable(nombre, _tous_les_joueurs, "RosterSousTitreOuvrir", "Tous les joueurs sous contrat")
	var saison_p := R.pastille(self, nombre.size.x / C.density + 10, 104, _saison_courte(G.season_label(saison)), Charte.IVOIRE_2, "calendar", "RosterSaison")
	R.cliquable(saison_p, func(): app._navigate("Calendrier"), "RosterSaisonOuvrir", "Calendrier de la saison " + G.season_label(saison))
	_tuiles(joueurs, saison)

## Moyenne de niveau du XV (numéros 1 à 15) et son évolution depuis le début de saison, si elle est connue pour tout le XV.
func _xv() -> Dictionary:
	var debuts := {}
	for fiche: Variant in app.model.get("decisions", {}).get("development", {}).get("professionals", []):
		if fiche is Dictionary and fiche.get("development") is Dictionary and fiche.development.get("seasonStart") != null:
			debuts[str(fiche.get("id", ""))] = float(fiche.development.seasonStart)
	var total := 0.0
	var debut := 0.0
	var nombre := 0
	var connus := true
	for p: Variant in app.model.get("squad", []):
		if not p is Dictionary: continue
		var numero: Variant = p.get("shirtNumber")
		if not ((numero is int or numero is float) and int(numero) >= 1 and int(numero) <= 15): continue
		if not (p.get("rating") is int or p.get("rating") is float): return {}
		total += float(p.rating)
		nombre += 1
		if debuts.has(str(p.get("id", ""))): debut += float(debuts[str(p.id)])
		else: connus = false
	if nombre == 0: return {}
	var resultat := {"moyenne": total / nombre}
	if connus: resultat.evolution = (total - debut) / nombre
	return resultat

## Pastille « 36 joueurs » : retire filtres et recherche (tous onglets, y compris Contrats).
func _tous_les_joueurs() -> void:
	state.family = "Tous"
	state.contract = "Tous"
	state.search = ""
	state.scroll = 0
	app.roster_filter = "Tous"
	app._render(false)

## « 2026-2027 » devient « 2026-27 » comme dans la maquette.
static func _saison_courte(libelle: String) -> String:
	var m := RegEx.create_from_string("^(\\d{4})-(\\d{2})(\\d{2})$").search(libelle)
	return m.get_string(1) + "-" + m.get_string(3) if m != null else libelle

static func _decimal(valeur: float) -> String:
	return ("%.1f" % valeur).replace(".", ",")

func _tuiles(joueurs: Array, saison: int) -> void:
	var blesses := 0
	var suspendus := 0
	var selection := 0
	var fins := 0
	for p: Variant in joueurs:
		if not p is Dictionary: continue
		match U.indisponibilite(p):
			"blesse": blesses += 1
			"suspendu": suspendus += 1
			"selection": selection += 1
		if p.get("contractEnd") != null and int(p.contractEnd) <= saison: fins += 1
	var indispos := blesses + suspendus + selection
	var detail: Array[String] = []
	if blesses > 0: detail.append("%d blessé%s" % [blesses, "s" if blesses > 1 else ""])
	if suspendus > 0: detail.append("%d suspendu%s" % [suspendus, "s" if suspendus > 1 else ""])
	if selection > 0: detail.append("%d sél." % selection)
	var xv := _xv()
	var tendance := ""
	if xv.has("evolution"):
		var e: float = xv.evolution
		tendance = "—" if absf(e) < .05 else ("▲ +" if e > 0 else "▼ −") + _decimal(absf(e))
	var etroit := _etroit()
	var definitions := [
		{"id": "Aptes", "cap": "APTES ▾", "val": str(joueurs.size() - indispos), "suf": "/ %d" % joueurs.size(), "l": 250.0 if not etroit else 210.0, "act": "aptes", "aide": "Joueurs aptes : survol pour l’équilibre par poste, clic pour ne garder qu’eux."},
		{"id": "Indisponibles", "cap": "INDISPONIBLES", "val": str(indispos), "suf": " · ".join(detail) if not etroit else "", "l": 330.0 if not etroit else 250.0, "act": "indisponibles", "aide": "Indisponibles : " + (" · ".join(detail) if not detail.is_empty() else "aucun")},
		{"id": "Contrats", "cap": "FINS DE CONTRAT", "val": str(fins), "suf": "cette saison", "l": 290.0 if not etroit else 250.0, "act": "fin", "aide": "Contrats qui s’achèvent cette saison."},
		{"id": "Niveau", "cap": "NIVEAU MOYEN DU XV", "val": _decimal(xv.moyenne) if xv.has("moyenne") else "—", "suf": tendance if not etroit else "", "l": 360.0 if not etroit else 270.0, "act": "niveau", "aide": "Niveau moyen des quinze titulaires (clic : trier par niveau)." + ("\n" + ("Stable cette saison" if tendance == "—" else tendance + " cette saison") if not tendance.is_empty() else "")},
	]
	var x := LARGEUR
	for i in range(definitions.size() - 1, -1, -1):
		var d: Dictionary = definitions[i]
		x -= float(d.l)
		_tuile(Rect2(x, 0, float(d.l), 88), d)
		x -= 14.0

func _tuile(zone: Rect2, d: Dictionary) -> void:
	var tuile := Button.new()
	tuile.name = "EffectifTuile" + str(d.id)
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s %s %s" % [str(d.cap).trim_suffix(" ▾"), d.val, d.suf]
	tuile.tooltip_text = "" if d.id == "Aptes" else str(d.aide)
	tuile.add_theme_stylebox_override("normal", _plat(Charte.PANNEAU, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("hover", _plat(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("pressed", _plat(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 16))
	tuile.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, 16))
	add_child(tuile)
	D.place(tuile, zone)
	load("res://ui/retour_tuile.gd").brancher(tuile, tuile, C.px(16))
	D.text(tuile, 16, 28, d.cap, 17, C.MUTED, 700, zone.size.x - 28)
	var valeur := _italique(D.text(tuile, 16, 72, d.val, 48, C.IVORY, 800, 200), false)
	valeur.name = "EffectifTuileValeur"
	var l := _largeur(str(d.val), 48, false, 800)
	if not str(d.suf).is_empty():
		D.text(tuile, 16 + l + 12, 68, d.suf, 18, C.MUTED, 500, zone.size.x - l - 40, HORIZONTAL_ALIGNMENT_LEFT, true).name = "EffectifTuileDetail"
	var marque_active := _marqueur(tuile, Rect2(0, 0, 6, zone.size.y))
	marque_active.name = "EffectifTuileActive"
	marque_active.visible = _tuile_active(str(d.act))
	_marques_tuiles[str(d.act)] = marque_active
	tuile.pressed.connect(_action_tuile.bind(str(d.act)))
	if d.id == "Aptes":
		tuile.mouse_entered.connect(_montrer_bulle.bind(tuile))
		tuile.mouse_exited.connect(_cacher_bulle)
		tuile.focus_entered.connect(_montrer_bulle.bind(tuile))
		tuile.focus_exited.connect(_cacher_bulle)
		tuile.tree_exiting.connect(_cacher_bulle)

func _action_tuile(action: String) -> void:
	_cacher_bulle()
	if action == "niveau":
		state.immersive_tab = 0
		state.sort = "Niveau"; state.descending = true; app.roster_sort = "Niveau"
		state.scroll = 0
		state.focus = "EffectifTuileNiveau"
		app._render(false)
		return
	_appliquer_puce(action)

## Équilibre par poste : effectif, aptes et fins de contrat de la saison pour chaque poste (infobulle autorisée).
func _montrer_bulle(ancre: Control) -> void:
	_cacher_bulle()
	if not is_instance_valid(ancre) or not ancre.is_inside_tree(): return
	var saison := int(app.model.get("meta", {}).get("season", 1))
	var joueurs: Array = app.model.get("squad", [])
	var aptes_total := joueurs.filter(func(p: Dictionary): return U.indisponibilite(p).is_empty()).size()
	var fiche := Panel.new()
	fiche.name = "EquilibrePostes"
	fiche.z_index = 100
	fiche.add_theme_stylebox_override("panel", _plat(Charte.PANNEAU_3, Charte.FILET, 1))
	var hauteur := 118.0 + POSTES.size() * 34.0
	fiche.size = Vector2(720, hauteur) * C.density
	D.text(fiche, 22, 42, "ÉQUILIBRE PAR POSTE", 19, C.IVORY, 700, 400)
	D.text(fiche, 698, 42, "%d aptes sur %d" % [aptes_total, joueurs.size()], 18, C.MUTED, 500, 300, HORIZONTAL_ALIGNMENT_RIGHT, true)
	D.line(fiche, Vector2(22, 60), Vector2(698, 60), Charte.FILET)
	D.text(fiche, 22, 90, "POSTE", 16, C.MUTED, 700, 300)
	for colonne: Array in [["EFF.", 470.0], ["APTES", 590.0], ["FINS", 698.0]]:
		D.text(fiche, float(colonne[1]), 90, colonne[0], 16, C.MUTED, 700, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in POSTES.size():
		var poste: Array = POSTES[i]
		var y := 128.0 + i * 34.0
		var effectif := 0
		var aptes := 0
		var fins := 0
		for p: Variant in joueurs:
			if not p is Dictionary: continue
			var numeros := primary_numbers(p)
			var present := false
			for numero: Variant in poste[1]:
				if int(numero) in numeros: present = true
			if not present: continue
			effectif += 1
			if U.indisponibilite(p).is_empty(): aptes += 1
			if p.get("contractEnd") != null and int(p.contractEnd) <= saison: fins += 1
		if i > 0: D.line(fiche, Vector2(12, y - 24), Vector2(708, y - 24), Charte.FILET)
		D.text(fiche, 22, y, poste[0], 19, C.IVORY, 500, 330, HORIZONTAL_ALIGNMENT_LEFT, true)
		D.text(fiche, 470, y, str(effectif), 19, C.IVORY, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(fiche, 590, y, str(aptes), 19, C.IVORY if aptes == effectif else C.MUTED, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(fiche, 698, y, "⧗ %d" % fins if fins > 0 else "—", 19, C.IVORY if fins > 0 else C.FAINT, 600, 110, HORIZONTAL_ALIGNMENT_RIGHT)
	MiniFiche._ignorer_souris(fiche)
	app.add_child(fiche)
	MiniFiche.placer(fiche, ancre, app.get_viewport_rect().size)

func _cacher_bulle() -> void:
	if not is_instance_valid(app): return
	var fiche := app.get_node_or_null("EquilibrePostes")
	if fiche == null: return
	fiche.hide()
	fiche.name = "EquilibrePostesFermee"
	fiche.queue_free()

# ---------------------------------------------------------------- onglets et liens

func _onglets() -> void:
	var courant := int(state.get("immersive_tab", 0))
	var x := 0.0
	for i in VUES.size():
		var largeur := _largeur(VUES[i], 19) + 44.0
		var onglet := _lien(self, Rect2(x, Y_ONGLETS, largeur, 44), VUES[i], func():
			state.immersive_tab = i
			state.sort = ["Poste","Condition","Échéance","Potentiel","Poste"][i]
			state.descending = i in [1,3]
			app.roster_sort = state.sort
			app._render(), "RosterTab" + str(i), Charte.IVOIRE if i == courant else Charte.IVOIRE_2, 19.0, HORIZONTAL_ALIGNMENT_CENTER)
		onglet.accessibility_name = "Onglet " + VUES[i] + (" · actif" if i == courant else "")
		# Charte §7.1 : onglet en pilule, même rendu que les onglets de la coque (D.tab_state, sans icône).
		D.tab_state(onglet, Vector2(largeur, 44), i == courant, "")
		onglet.icon = null
		var focus_onglet := _plat(Color.TRANSPARENT, Charte.IVOIRE, 2, Charte.RAYON_PILULE)
		focus_onglet.set_expand_margin_all(2)
		onglet.add_theme_stylebox_override("focus", focus_onglet)
		x += largeur + 8.0
	# À droite : changer d'onglet, comparer, Vestiaire.
	var droite := LARGEUR
	var vestiaire := _lien(self, Rect2(droite - 170, Y_ONGLETS, 170, 44), "Vestiaire →", func(): app._navigate("Vestiaire"), "RosterOpenLocker", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	vestiaire.tooltip_text = "Ouvrir le vestiaire"
	droite -= 186.0
	var texte := "Comparer %d/2 →" % app.management_ui.compare.size()
	var largeur_comparer := _largeur("Comparer 2/2 →", 19) + 36.0
	compare = _lien(self, Rect2(droite - largeur_comparer, Y_ONGLETS, largeur_comparer, 44), texte, func(): app.SquadViews.comparison(app), "OpenComparison", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
	droite -= largeur_comparer + 16.0
	# « Ctrl Tab » (onglet suivant) est dans l'aide « ? » du pied du tableau (21/11).
	if app.model.get("epcrPreparation") is Dictionary:
		var europe := _lien(self, Rect2(droite - 300, Y_ONGLETS, 300, 44), "Préparer l’Europe →", func(): load("res://ui/immersive08/europe_canvas.gd").open(app), "OpenEpcrPreparation", Charte.IVOIRE, 19.0, HORIZONTAL_ALIGNMENT_CENTER, true)
		europe.tooltip_text = "Préparer la campagne européenne"

func _onglet_suivant() -> void:
	var i := (int(state.get("immersive_tab", 0)) + 1) % VUES.size()
	state.immersive_tab = i
	state.sort = ["Poste","Condition","Échéance","Potentiel","Poste"][i]
	state.descending = i in [1,3]
	app.roster_sort = state.sort
	app._render()

func _input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo or not is_visible_in_tree(): return
	if touche.keycode == KEY_TAB and touche.ctrl_pressed and not touche.alt_pressed:
		get_viewport().set_input_as_handled()
		_onglet_suivant()
		return
	var recherche := find_child("RosterSearch", true, false) as LineEdit
	if recherche != null and touche.keycode == KEY_SLASH and not touche.ctrl_pressed and not touche.alt_pressed and not (get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		recherche.grab_focus()
