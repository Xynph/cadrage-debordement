extends "res://ui/immersive08/centre_compact_page_centre.gd"
## Centre compact : onglets Parcours (les Espoirs sur le chemin) et Centres (les centres des autres clubs) (découpe de
## centre_compact.gd, sans changement).

# --- Parcours : les Espoirs sur le chemin -----------------------------------------------------------------------------

static func _parcours(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var app: Control = ctx.app
	var tous: Array = data.get("players", [])
	var etape := str(ctx.state.get("etape", ""))
	var filtre := str(ctx.state.get("filtre_traj", ""))
	var etapes: Array = []
	for e: Array in V.ETAPES:
		var liste: Array = tous.filter(func(p: Dictionary): return V.etape(p) == str(e[0]))
		etapes.append([e[0], e[1], e[2], liste.size()])
	_chemin(ctx, parent, etapes, etape, "etape", "CentreChemin", ["Équipe 1re", G.n(data.get("places", 0)), V.REPUTATION, "%s promus" % G.n(data.get("promotions", []).size()), func(): app._navigate("Effectif")])
	var joueurs: Array = tous.filter(func(p: Dictionary): return (etape.is_empty() or V.etape(p) == etape) and (filtre.is_empty() or str(p.path) == filtre))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "w": 112, "tri": true, "desc": false},
		{"k": "min", "t": "MINUTES", "w": 124, "tri": true},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p)
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(p), V.couleur(V.valeur(p, "rating")), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(p), V.couleur(V.valeur(p, "potential")), Charte.TITRE_EXTRA, 17)
			"traj":
				var t := V.trajectoire(str(p.path))
				_pastille(cel, str(t[1]), t[3], str(t[2]))
			"min":
				var cible := float(p.get("target", 0))
				var m := float(p.get("minutes", 0))
				_barre(cel, m / (cible if cible > 0 else 480.0), V.MINUTES, 6.0)
				var l := _txt(cel, ("%s / %s" % [V.mille(m), V.mille(cible)]) if cible > 0 else V.mille(m), PETIT, V.MINUTES, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
				l.custom_minimum_size.x = 64 if cible > 0 else 30
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"traj": return str(V.trajectoire(str(p.path))[1])
			"min": return float(p.get("minutes", 0))
		return null
	var groupes: Array = []
	if etape.is_empty():
		for e: Array in V.ETAPES:
			var eid := str(e[0])
			groupes.append([str(e[1]), e[2], func(p: Dictionary): return V.etape(p) == eid])
	var filtres := func(flux: Control):
		var defs: Array = [["", "Tous", Charte.IVOIRE, G.n(tous.filter(func(p: Dictionary): return etape.is_empty() or V.etape(p) == etape).size())]]
		for t: Array in V.TRAJECTOIRES:
			var tid := str(t[0])
			defs.append([tid, t[1], t[3], G.n(tous.filter(func(p: Dictionary): return str(p.path) == tid and (etape.is_empty() or V.etape(p) == etape)).size())])
		for d: Array in defs:
			var valeur := str(d[0])
			_pilule(flux, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_traj = valeur
				(ctx.reconstruire as Callable).call(), "CentreFiltreTrajectoire_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, joueurs, cellule, cle, func(p: Dictionary, _l: Control): (_fenetre(ctx, func(): V.fenetre_parcours(ctx, str(p.id)))).call(), func(_p: Dictionary, rang: int): return "CentreVisuelJoueur%d" % rang, "CentreParcoursListe", filtres, groupes, ["pot", true])

# --- Centres : les centres des autres clubs ----------------------------------------------------------------------------

static func _centres(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var world: bool = data.get("world", false)
	var verrou: bool = data.get("locked", false)
	var observe := V.cout(ctx, "centerScout", 1200)
	var centres: Array = data.get("centers", []).filter(func(c: Dictionary): return not c.get("own", false) and (not world or c.scouted or c.count > 15))
	var vus: Array = centres.filter(func(c: Dictionary): return c.scouted)
	var candidats: Array = []
	for c: Dictionary in vus:
		for p: Dictionary in c.get("candidates", []):
			var q := p.duplicate()
			q.centre = str(c.name)
			candidats.append(q)
	candidats.sort_custom(T._par_potentiel)
	var obs := _panneau(parent, "Observation", "search", "CentresObservation")
	var rangee := _rangee(obs, 16)
	for l: Array in [["search", "Centres observés", "%d / %d" % [vus.size(), centres.size()], V.MINUTES], ["money", "Une observation", V.euros(observe), V.DEPENSE], ["money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE]]:
		var r := _ligne_chiffre(null, l[0], l[1], l[2], l[3], Callable(), "")
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rangee.add_child(r)
	var cand := _panneau(parent, "Candidats", "people", "CentresCandidats", Callable(), G.n(candidats.size()), V.PROGRES)
	var flux := _flux(cand, 6)
	for i in mini(candidats.size(), 8):
		var p: Dictionary = candidats[i]
		var fee := int(p.get("fee", 0))
		var pid := str(p.id)
		var pt := V.couleur(V.valeur(p, "potential"))
		var b := _zone(func(): V.envoyer(ctx, "academy_recruit", {"playerId": pid, "offer": fee}, fee, "Recruter " + str(p.name)), "CentresCandidat%d" % i, str(p.name), Charte.RAYON_CARTE, 46.0, Charte.PANNEAU_2)
		b.custom_minimum_size.x = 250.0
		var h := _dans(b, 8, 8)
		_portrait(h, p, 32)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(col)
		_txt(col, p.name, CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_txt(col, p.pos, PETIT, Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		var dr := VBoxContainer.new()
		dr.add_theme_constant_override("separation", -4)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dr.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(dr)
		_chiffre(dr, V.potentiel_txt(p), 22, pt, HORIZONTAL_ALIGNMENT_RIGHT)
		_txt(dr, V.euros(fee), PETIT, V.DEPENSE, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		flux.add_child(b)
	var filtre := str(ctx.state.get("filtre_centres", ""))
	var montres: Array = centres.filter(func(c: Dictionary): return filtre.is_empty() or (filtre == "vus") == bool(c.scouted))
	var max_n := 1
	for c: Dictionary in centres: max_n = maxi(max_n, int(c.count))
	var colonnes := [
		{"k": "nom", "t": "CENTRE", "tri": true, "desc": false},
		{"k": "n", "t": "JEUNES", "w": 120, "tri": true},
		{"k": "cand", "t": "CANDIDATS", "w": 110},
		{"k": "pot", "t": "MEILLEUR POT.", "w": 92, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "act", "t": "", "w": 118},
	]
	var meilleur := func(c: Dictionary) -> float:
		var m := -1.0
		for p: Dictionary in c.get("candidates", []): m = maxf(m, V.valeur(p, "potential"))
		return m
	var cellule := func(cel: Control, col: Dictionary, c: Dictionary):
		match str(col.k):
			"nom":
				_blason(cel, str(c.name), V.MINUTES if c.scouted else Charte.IVOIRE_3)
				_txt(cel, c.name, CORPS, Charte.IVOIRE, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
			"n":
				_barre(cel, float(c.count) / max_n, V.MINUTES if c.scouted else Charte.IVOIRE_2, 6.0)
				var l := _txt(cel, G.n(c.count), PETIT, V.MINUTES if c.scouted else Charte.IVOIRE_2, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
				l.custom_minimum_size.x = 26
			"cand":
				for p: Dictionary in c.get("candidates", []).slice(0, 4):
					_portrait(cel, p, 24)
			"pot":
				var m: float = meilleur.call(c)
				_cel(cel, col, "—" if m < 0 else str(roundi(m)), V.couleur(m), Charte.TITRE_EXTRA, 17)
			"act":
				if c.scouted: _pastille(cel, "Observé", V.PROGRES, "check")
				else: _pastille(cel, "Observer · " + V.euros(observe), V.DEPENSE, "search")
	var cle := func(c: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(c.name)
			"n": return int(c.count)
			"pot": return meilleur.call(c)
		return null
	var au_clic := func(c: Dictionary, _l: Control):
		if verrou: return
		if c.scouted: (_fenetre(ctx, func(): T._fenetre_candidats(ctx, c))).call()
		else: V.envoyer(ctx, "academy_center_scout", {"centerId": str(c.id)}, observe, "Observer " + str(c.name))
	var groupes: Array = [["Observés", V.MINUTES, func(c: Dictionary): return c.scouted], ["À observer", Charte.IVOIRE_3, func(c: Dictionary): return not c.scouted]]
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(centres.size())], ["vus", "Observés", V.MINUTES, G.n(vus.size())], ["avoir", "À observer", Charte.IVOIRE_2, G.n(centres.size() - vus.size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_centres = valeur
				(ctx.reconstruire as Callable).call(), "CentresFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, au_clic, func(c: Dictionary, _r: int): return "CentreLigne_" + str(c.id).validate_node_name(), "CentresListe", filtres, groupes, ["n", true])
