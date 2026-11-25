extends "res://ui/immersive08/squad_lignes.gd"
## Écran Effectif : colonnes, en-têtes triables, tri, remplissage des lignes par groupe et tuiles des totaux (découpe de squad_canvas.gd, sans changement).

# ---------------------------------------------------------------- tableau

## Colonnes de la vue : {k : genre de cellule, t : titre, s : clé de tri, x, w : position et largeur (unités), a : alignement}.
func _colonnes(vue: int, etroit: bool, surveillance: bool) -> Array:
	var gauche := HORIZONTAL_ALIGNMENT_LEFT
	var centre := HORIZONTAL_ALIGNMENT_CENTER
	var droite := HORIZONTAL_ALIGNMENT_RIGHT
	var num := {"k": "num", "t": "N°", "s": "Numéro", "x": 14.0, "w": 90.0, "a": gauche}
	var joueur := {"k": "joueur", "t": "JOUEUR", "s": "Nom", "x": 176.0, "w": 360.0 if not etroit else 440.0, "a": gauche}
	var motif := {"k": "motif", "t": "MOTIF DE SURVEILLANCE", "s": "Motif", "x": 1560.0, "w": 330.0, "a": gauche}
	var colonnes: Array = []
	match vue:
		1:
			if etroit:
				colonnes = [num, joueur, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 700.0, "w": 330.0, "a": gauche}, {"k": "fat", "t": "FAT.", "s": "Fatigue", "x": 1080.0, "w": 120.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1260.0, "w": 130.0, "a": centre}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1500.0, "w": 730.0, "a": gauche}]
			else:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 250.0, "a": gauche}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 850.0, "w": 290.0, "a": gauche}, {"k": "fat", "t": "FAT.", "s": "Fatigue", "x": 1170.0, "w": 100.0, "a": droite}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1310.0, "w": 110.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1470.0, "w": 110.0, "a": centre}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1620.0, "w": 260.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1890.0, "w": 280.0, "a": gauche}]
		3:
			if etroit:
				colonnes = [num, joueur, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 700.0, "w": 90.0, "a": droite}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 880.0, "w": 100.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 1060.0, "w": 170.0, "a": centre}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1300.0, "w": 130.0, "a": droite}]
			else:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 250.0, "a": gauche}, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 830.0, "w": 80.0, "a": droite}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 960.0, "w": 80.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 1060.0, "w": 150.0, "a": centre}, {"k": "min", "t": "MIN.", "s": "Minutes", "x": 1260.0, "w": 110.0, "a": droite}, {"k": "moy", "t": "MOY.", "s": "Moyenne", "x": 1420.0, "w": 110.0, "a": centre}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1580.0, "w": 260.0, "a": gauche}]
		_:
			if etroit:
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 640.0, "w": 330.0, "a": gauche}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 1000.0, "w": 100.0, "a": centre}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 1150.0, "w": 300.0, "a": gauche}, {"k": "contrat", "t": "FIN DE CONTRAT", "s": "Échéance", "x": 1500.0, "w": 320.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1840.0, "w": 390.0, "a": gauche}]
			else:
				# Forme récente dans la vue d'ensemble (choix de Léo du 21/11/2026).
				colonnes = [num, joueur, {"k": "poste", "t": "POSTE", "s": "Poste", "x": 560.0, "w": 230.0, "a": gauche}, {"k": "niveau", "t": "NIV.", "s": "Niveau", "x": 810.0, "w": 80.0, "a": centre}, {"k": "pot", "t": "POT.", "s": "Potentiel", "x": 910.0, "w": 120.0, "a": centre}, {"k": "cond", "t": "CONDITION", "s": "Condition", "x": 1060.0, "w": 250.0, "a": gauche}, {"k": "forme", "t": "FORME", "s": "Forme", "x": 1340.0, "w": 250.0, "a": gauche}, {"k": "age", "t": "ÂGE", "s": "Âge", "x": 1590.0, "w": 60.0, "a": droite}, {"k": "contrat", "t": "FIN DE CONTRAT", "s": "Échéance", "x": 1680.0, "w": 200.0, "a": gauche}, {"k": "statut", "t": "STATUT", "s": "Statut", "x": 1890.0, "w": 280.0, "a": gauche}]
	if surveillance:
		var sans: Array = colonnes.filter(func(c: Dictionary): return c.k not in ["age", "contrat", "forme", "min", "moy"])
		var index := 0
		for i in sans.size():
			if sans[i].k == "statut": index = i
		if etroit: motif = motif.merged({"x": 1500.0, "w": 330.0})
		sans.insert(index, motif)
		if etroit:
			for c: Dictionary in sans:
				if c.k == "statut": c.x = 1860.0; c.w = 310.0
		else:
			for c: Dictionary in sans:
				if c.k == "statut": c.x = 1890.0; c.w = 280.0
		colonnes = sans
	# Poste choisi sur le terrain XV : la colonne POSTE devient « CENTRE 12 » (note au poste + familiarité + poste du
	# joueur en petit) ; elle prend 110 unités à la colonne CONDITION quand elle la suit.
	if _poste > 0:
		for i in colonnes.size():
			if colonnes[i].k == "poste":
				var cond := -1
				for j in range(i + 1, colonnes.size()):
					if colonnes[j].k == "cond": cond = j; break
				var extra := 110.0 if cond > 0 else 0.0
				colonnes[i] = (colonnes[i] as Dictionary).merged({"k": "etoiles", "t": "%s %d" % [Etoiles.nom_poste(_poste).to_upper(), _poste], "s": "Note au poste", "w": float(colonnes[i].w) + extra}, true)
				if extra > 0.0:
					for j in range(i + 1, cond + 1):
						colonnes[j] = (colonnes[j] as Dictionary).merged({"x": float(colonnes[j].x) + extra}, true)
					colonnes[cond] = (colonnes[cond] as Dictionary).merged({"w": float(colonnes[cond].w) - extra}, true)
				break
	return colonnes

func _tableau() -> void:
	var table := Control.new()
	table.name = "ImmersiveRosterTable"
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table)
	D.place(table, Rect2(_x0, Y_ENTETE + _dy, _lt, HAUT_PAGE - Y_ENTETE - _dy))
	_colonnes_actives = _colonnes(int(state.get("immersive_tab", 0)), _etroit(), state.family == U.WATCH_FILTER)
	if _lt < LARGEUR: _colonnes_actives = _resserrer(_colonnes_actives)
	var entete := Control.new()
	entete.name = "RosterHeader"
	entete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(entete)
	D.place(entete, Rect2(0, 0, _lt, 36))
	D.line(entete, Vector2(0, 35), Vector2(_lt, 35), Charte.FILET)
	var noms := {"Salaire": "RosterColumnSalary", "Potentiel": "RosterColumnPotential", "Poste": "RosterColumn_POSTE", "Autres postes": "RosterColumnSecondaryPositions", "Moyenne": "RosterColumnNote", "Forme": "RosterColumnForm", "Fatigue": "RosterColumnFatigue"}
	for colonne: Dictionary in _colonnes_actives:
		var cle := str(colonne.s)
		var x: float = colonne.x
		var largeur: float = colonne.w
		var legende := D.text(entete, x, 26, colonne.t, 17, C.MUTED, 700, largeur, colonne.a)
		legende.name = noms.get(cle, "RosterColumn_" + str(colonne.t))
		var tri := Button.new()
		tri.name = "Sort_" + cle
		tri.flat = true
		tri.focus_mode = Control.FOCUS_ALL
		tri.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tri.add_theme_stylebox_override("hover", _plat(Color(Charte.PANNEAU_2, .7)))
		tri.add_theme_stylebox_override("focus", _plat(Color.TRANSPARENT, Charte.IVOIRE, 1))
		entete.add_child(tri)
		# En-tête souligné à la largeur de son texte, derrière la légende (choix de Léo du 21/11/2026).
		var lt := _largeur(str(colonne.t) + " ▼", 17, true, 700) + 26.0
		var x0: float = x - 13.0 if colonne.a == HORIZONTAL_ALIGNMENT_LEFT else (x + largeur - lt + 13.0 if colonne.a == HORIZONTAL_ALIGNMENT_RIGHT else x + largeur / 2.0 - lt / 2.0)
		D.place(tri, C.reach_rect(Rect2(x0, 2, lt, 32)))
		entete.move_child(tri, legende.get_index())
		sort_headers[cle] = {"label": legende, "caption": str(colonne.t), "button": tri}
		tri.pressed.connect(_toggle_sort.bind(cle))
	var defile := ScrollContainer.new()
	defile.name = "SquadScroll"
	defile.follow_focus = true
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	table.add_child(defile)
	D.place(defile, Rect2(0, Y_LIGNES - Y_ENTETE + Bandeau.ECART_LIGNES, _lt, Y_PIED - Y_LIGNES - 8 - _dy - Bandeau.ECART_LIGNES))
	rows = C.v(2)
	rows.add_theme_constant_override("separation", C.px(2))
	rows.name = "ImmersiveRosterRows"
	rows.custom_minimum_size.x = C.px(_lt)
	C.fill(rows)
	defile.add_child(rows)
	count = D.text(table, 0, Y_PIED - Y_ENTETE - _dy + 26, "", 18, C.MUTED, 500, 1000, HORIZONTAL_ALIGNMENT_LEFT, true)
	count.name = "RosterCount"
	# Raccourcis clavier derrière un « ? » (21/11) : plus de ligne de mode d'emploi au pied du tableau.
	var aide := "Raccourcis\n↑↓ : choisir un joueur\nEntrée : fiche complète\nMaj Espace : comparer\n/ : chercher dans le tableau\nCtrl Tab : onglet suivant\nÉchap : Menu\nSurvol d'un nom : aperçu · clic : fiche"
	R.rond(table, _lt - 30, Y_PIED - Y_ENTETE - _dy + 18, aide, "?", "RosterScrollHint", 28)


## Panneaux dépliés : colonnes après « Joueur » resserrées dans la largeur restante.
func _resserrer(colonnes: Array) -> Array:
	var k := (_lt - 560.0) / (LARGEUR - 560.0)
	var sortie: Array = []
	for c: Dictionary in colonnes:
		var d := c.duplicate()
		if float(d.x) >= 540.0:
			d.x = 560.0 + (float(d.x) - 560.0) * k
			d.w = float(d.w) * k
		sortie.append(d)
	return sortie

func _players() -> Array:
	# Les notes de match (clubLife.matchNotes) accompagnent chaque joueur pour le tri.
	var source: Array = []
	for player: Variant in app.model.get("squad",[]):
		if player is Dictionary:
			var copie: Dictionary = player.duplicate()
			copie.matchNotes = Notes.joueur(app.model,str(player.get("id","")))
			copie.notePoste = Notation.rang_lettre(Notation.lettre_poste(app.model, player, _poste, true)) if _poste > 0 else -1.0
			copie.familiarite = Familiarite.niveau(player, _poste)
			source.append(copie)
	source = Listes.filtrer_groupe(source, str(state.get("poste_groupe", "")))
	return ordered_players(source,state,int(app.model.meta.get("season",1)))


func _toggle_sort(key: String) -> void:
	state.descending = not state.descending if state.sort == key else key in ["Niveau","Potentiel","Condition","Fatigue","Minutes","Moyenne","Forme","Note au poste"]
	state.sort = key
	app.roster_sort = key
	state.scroll = 0
	state.focus = "Sort_"+key
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0
	_refresh(false)
	var button := find_child("Sort_"+key,true,false) as Button
	if button != null: button.grab_focus()

func _sort_header_state() -> void:
	for key: String in sort_headers:
		var header: Dictionary = sort_headers[key]
		var active: bool = state.sort == key
		var direction := "décroissant" if state.descending else "croissant"
		header.label.text = header.caption + (" ▼" if state.descending else " ▲") if active else header.caption
		header.label.add_theme_color_override("font_color",C.IVORY if active else C.MUTED)
		var detail := "par famille puis poste" if key == "Poste" else "par "+key
		header.button.tooltip_text = "Tri "+direction+" "+detail+" · cliquer pour inverser" if active else "Trier "+detail+" · valeurs inconnues en dernier"

		if key == "Moyenne": header.button.tooltip_text += "\nMoyenne de la saison en cours (notes de match de 1 à 10)."
		if key == "Forme": header.button.tooltip_text += "\nCinq dernières notes de match, la plus récente à droite."
		header.button.accessibility_name = str(header.caption)+" · "+("tri "+direction if active else "trier")
		Listes.styler_entete(header.button, header.label, active, state.descending, header.caption)

func _refresh(reveal: bool) -> void:
	_sort_header_state()
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	var players := _players()
	if app.selected_player.is_empty() and not players.is_empty():app.selected_player=str(players[0].id)
	state.visible_player=app.selected_player
	count.text="%d / %d joueurs" % [players.size(),app.model.get("squad",[]).size()]
	_totaux(players)
	if compare != null: compare.text="Comparer %d/2 →" % app.management_ui.compare.size()
	# Construction progressive : les lignes visibles sont créées tout de suite, le reste sur les
	# images suivantes (60 lignes d'un coup coûtaient plus de 100 ms avant la première image).
	_generation += 1
	_group = ""
	var built := mini(players.size(),FIRST_ROWS)
	if reveal:
		for i in players.size():
			if str(players[i].id) == app.selected_player:
				built = maxi(built,mini(players.size(),i+VISIBLE_MARGIN))
				break
	_build_rows(players,0,built)
	if built < players.size(): _build_remaining(players,built,_generation)
	if players.is_empty():
		var nobody_watched: bool = state.family==U.WATCH_FILTER and str(state.search).strip_edges().is_empty()
		var empty:=C.wrap("Personne à surveiller cette semaine." if nobody_watched else "Aucun joueur ne correspond. Modifie les filtres ou réinitialise la recherche.",22,C.IVORY if nobody_watched else C.MUTED)
		empty.name = "RosterEmpty"
		rows.add_child(empty)
	if reveal:
		var scroll := find_child("SquadScroll",true,false) as ScrollContainer
		for row: Control in rows.get_children():
			if row.get_meta("player_id","") == app.selected_player and scroll != null:
				scroll.ensure_control_visible.call_deferred(row)
				break

func _build_rows(players: Array,from: int,to: int) -> void:
	for i in range(from,to):
		var player:Dictionary=players[i]
		var group := "AVANTS" if float(player.get("fam",0))<=3 else "ARRIÈRES"
		if state.sort=="Poste" and group!=_group:
			_group=group
			_bandeau_groupe(players, group)
		_row(player,i)

func _bandeau_groupe(players: Array, group: String) -> void:
	var banner:=Control.new()
	banner.name = "RosterGroup" + ("Avants" if group == "AVANTS" else "Arrieres")
	banner.custom_minimum_size=Vector2(C.px(_lt),C.px(C.reach(GROUP_HEIGHT)))
	rows.add_child(banner)
	var source: Array = players if state.family==U.WATCH_FILTER else app.model.get("squad",[])
	var membres: Array = source.filter(func(p:Dictionary):return (float(p.get("fam",0))<=3)==(group=="AVANTS"))
	var titulaires: Array[int] = []
	for p: Dictionary in membres:
		if p.get("shirtNumber") is int or p.get("shirtNumber") is float:
			if int(p.shirtNumber) <= 15: titulaires.append(int(p.shirtNumber))
	# Bandeau de groupe : « AVANTS 19 » (chiffre de tuile) et un « i » pour les numéros de la feuille (21/11).
	var h := C.reach(GROUP_HEIGHT)
	var filtre := "avants" if group == "AVANTS" else "arrieres"
	var ouvrir := Button.new()
	ouvrir.name = "RosterGroupFiltre" + ("Avants" if group == "AVANTS" else "Arrieres")
	ouvrir.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ouvrir.focus_mode = Control.FOCUS_NONE
	ouvrir.tooltip_text = "Ne garder que les " + group.to_lower()
	ouvrir.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	ouvrir.add_theme_stylebox_override("hover", _plat(Color(Charte.IVOIRE, .06)))
	ouvrir.add_theme_stylebox_override("pressed", _plat(Color(Charte.IVOIRE, .10)))
	banner.add_child(ouvrir)
	ouvrir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ouvrir.pressed.connect(func(): _appliquer_puce(filtre))
	var titre := _italique(D.text(banner, 14, h / 2.0 + 8, group, 22, C.IVORY, 700, 200), false)
	var l := _largeur(group, 22, false, 700)
	var chiffre := _italique(D.text(banner, 14 + l + 14, h / 2.0 + 9, str(membres.size()), 26, C.IVORY, 800, 80), false)
	chiffre.name = "RosterGroupNombre"
	chiffre.tooltip_text = "%d joueur%s" % [membres.size(), "s" if membres.size() > 1 else ""]
	if not titulaires.is_empty():
		var lc := _largeur(str(membres.size()), 26, false, 800)
		R.rond(banner, 14 + l + 14 + lc + 14, h / 2.0, "N° %d à %d · ordre de la feuille" % [titulaires.min(), titulaires.max()], "i", "RosterGroupNumeros", 22)
	titre.name = "RosterGroupTitre"

func _build_remaining(players: Array,from: int,generation: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var next := from
	while next < players.size():
		await tree.process_frame
		if not is_instance_valid(self) or generation != _generation or not is_inside_tree(): return
		var upto := mini(players.size(),next+ROWS_PER_FRAME)
		_build_rows(players,next,upto)
		next = upto
	# Le défilement mémorisé n'existait pas tant que la liste était incomplète.
	var scroll := find_child("SquadScroll",true,false) as ScrollContainer
	if scroll != null and int(state.get("scroll",0)) > 0:
		await tree.process_frame
		if is_instance_valid(self) and generation == _generation and is_instance_valid(scroll): scroll.scroll_vertical = int(state.scroll)

## Chiffres de la liste filtrée : {id, v, cap, c (couleur), act}. Pas de tuile « fins de contrat » : la tuile du haut
## de l'écran la donne déjà.
func _definitions_totaux(players: Array) -> Array:
	var t := Listes.calculer(players)
	var masse := G.salary_amount(t.masse) + " " + G.salary_period(true)
	return [
		{"id": "Joueurs", "v": str(t.n), "cap": "joueurs", "c": Charte.IVOIRE, "act": func(): _tous_les_joueurs()},
		{"id": "Lignes", "v": "%d · %d" % [t.avants, t.arrieres], "cap": "av. · arr.", "c": Charte.IVOIRE, "act": func(): _toggle_sort("Poste")},
		# Notation façon FM : lettre moyenne de la liste, relative à notre effectif (jamais la moyenne chiffrée).
		{"id": "Niveau", "v": "—" if t.niveau == null else Notation.texte_lettre(Notation.indice(t.niveau, Notation.reference_effectif(app.model))), "cap": "niveau moyen", "c": Notation.couleur(Notation.indice(t.niveau, Notation.reference_effectif(app.model))).lightened(.15) if t.niveau != null else Charte.IVOIRE, "act": func(): _toggle_sort("Niveau")},
		{"id": "Condition", "v": "—" if t.condition == null else "%d %%" % roundi(float(t.condition)), "cap": "condition moy.", "c": Charte.CONDITION, "act": func(): _toggle_sort("Condition")},
		{"id": "Moral", "v": str(roundi(float(app.model.get("meta", {}).get("morale", 0)))) if app.model.get("meta", {}).get("morale") != null else "—", "cap": "moral", "c": Charte.MORAL, "act": func(): app._navigate("Vestiaire")},
		{"id": "Age", "v": Listes.decimal(t.age), "cap": "âge moyen", "c": Charte.IVOIRE, "act": func(): _toggle_sort("Âge")},
		{"id": "Masse", "v": masse, "cap": "masse salariale", "c": R.BLEU, "act": func(): app._navigate("Finances")},
	]

func _totaux(players: Array) -> void:
	if _bandeau_totaux == null: return
	for enfant in _bandeau_totaux.get_children():
		_bandeau_totaux.remove_child(enfant)
		enfant.queue_free()
	var x := 0.0
	for d: Dictionary in _definitions_totaux(players):
		var l := maxf(R.largeur(str(d.v), 34, 800) + R.largeur(str(d.cap).to_upper(), 17) + 52.0, 180.0)
		var tuile := R.tuile(_bandeau_totaux, Rect2(x, 0, l, 60), str(d.v), str(d.cap), d.c, "TotalTuile_" + str(d.id), 34)
		var bouton := R.cliquable(tuile, d.act, "TotalTuileOuvrir_" + str(d.id), str(d.cap))
		# Mini-courbe au survol (relevé hebdomadaire du moteur, mêmes bulles que le Bureau et l'Entraînement).
		if str(d.id) == "Condition": Courbe.lier(app, bouton, "condition", "Condition du groupe")
		elif str(d.id) == "Moral": Courbe.lier(app, bouton, "morale", "Moral du vestiaire")
		x += l + 12.0
