extends "res://ui/immersive08/centre_compact_parcours_centres.gd"
## Centre compact : onglets Filières, Passerelle pro et Générations (découpe de centre_compact.gd, sans changement).

# --- Filières : régions, clubs formateurs et jeunes repérés ------------------------------------------------------------

static func _filieres(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var verrou: bool = data.get("locked", false)
	var prospects: Array = data.get("prospects", [])
	var regions: Array = data.get("regions", [])
	var region_f := str(ctx.state.get("region", ""))
	var discover := V.cout(ctx, "discover", 3000)
	var partner := V.cout(ctx, "partner", 2000)
	var reg := _panneau(parent, "Régions", "globe", "FilieresRegions")
	var flux := _flux(reg, 6)
	for i in regions.size():
		var region := str(regions[i])
		var teinte: Color = V.COULEURS[i % V.COULEURS.size()]
		var n := prospects.filter(func(p: Dictionary): return str(p.region) == region).size()
		var choisi := region == region_f
		var b := _zone(V.aller(ctx, "Filières", "region", "" if choisi else region), "FilieresRegion%d" % i, region, 8, 36.0, Charte.PANNEAU_2.lerp(teinte, .3) if choisi else Color.TRANSPARENT, teinte if choisi else Color.TRANSPARENT)
		b.custom_minimum_size.x = 236.0
		var h := _dans(b, 8, 8)
		var rond := Panel.new()
		rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rond.custom_minimum_size = Vector2(10, 10)
		rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rond.add_theme_stylebox_override("panel", V.plat(teinte, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		h.add_child(rond)
		_txt(h, region, CORPS, Charte.IVOIRE, C.BOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
		_chiffre(h, G.n(n), 20, teinte, HORIZONTAL_ALIGNMENT_RIGHT)
		_pilule(h, V.euros(discover), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_discover", {"region": region}, discover, "Détecter · " + region), "FilieresDetecter%d" % i, "", not verrou)
		flux.add_child(b)
	var feeders: Array = data.get("feeders", [])
	var partenaires: Array = data.get("partners", [])
	var fp := _panneau(parent, "Clubs formateurs", "flag", "FilieresFormateurs", Callable(), G.n(partenaires.size()), V.PROGRES)
	var ff := _flux(fp, 6)
	for f: Dictionary in feeders:
		var fid := str(f.id)
		var ok := partenaires.has(fid)
		var nom_f := str(f.name)
		var b := _zone(func(): T._partenariat(ctx, fid, nom_f, ok or verrou, partner), "FilieresFormateur_" + fid.validate_node_name(), nom_f, 6, 30.0)
		b.custom_minimum_size.x = 276.0
		var h := _dans(b, 8, 8)
		_icone(h, "check" if ok else "flag", 16, V.PROGRES if ok else Charte.IVOIRE_3)
		_txt(h, nom_f, CORPS, Charte.IVOIRE if ok else Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		_txt(h, "Partenaire" if ok else V.euros(partner), PETIT, V.PROGRES if ok else V.DEPENSE, C.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		ff.add_child(b)
	var filtre := str(ctx.state.get("filtre_prospects", ""))
	var garde := func(p: Dictionary, f: String) -> bool:
		match f:
			"zero": return int(p.scouted) == 0
			"suivis": return int(p.scouted) > 0 and not p.trial
			"essai": return bool(p.trial)
		return true
	var dans_region := prospects.filter(func(p: Dictionary): return region_f.is_empty() or str(p.region) == region_f)
	var montres := dans_region.filter(func(p: Dictionary): return garde.call(p, filtre))
	var watch := V.cout(ctx, "watch", 500)
	var trial := V.cout(ctx, "trial", 1000)
	var recruit := V.cout(ctx, "recruit", 8000)
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "obs", "t": "OBS.", "w": 62, "tri": true},
		{"k": "essai", "t": "ESSAI", "w": 56, "tri": true},
		{"k": "suite", "t": "", "w": 128},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p, "", str(p.clubName))
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"pot":
				var vu := int(p.scouted) > 0
				_cel(cel, col, V.potentiel_txt(p) if vu else "?", V.couleur(V.valeur(p, "potential")) if vu else Charte.IVOIRE_3, Charte.TITRE_EXTRA, 17)
			"obs":
				_crans(cel, int(p.scouted), 3, V.MINUTES)
				_txt(cel, "%d/3" % int(p.scouted), PETIT, V.MINUTES if int(p.scouted) > 0 else Charte.IVOIRE_3, C.BOLD)
			"essai":
				if p.trial: _pastille(cel, "Fait", V.PROGRES, "check")
				else: _cel(cel, col, "—", Charte.IVOIRE_3)
			"suite":
				var s := T._suite_prospect(p, watch, trial, recruit)
				if not s.is_empty(): _pastille(cel, str(s[1]), s[2], str(s[3]))
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"pot": return V.valeur(p, "potential") if int(p.scouted) > 0 else -1.0
			"obs": return int(p.scouted)
			"essai": return 1 if p.trial else 0
		return null
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(dans_region.size())], ["zero", "À observer", Charte.IVOIRE_2, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "zero")).size())], ["suivis", "Observés", V.MINUTES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "suivis")).size())], ["essai", "Essai fait", V.PROGRES, G.n(dans_region.filter(func(p: Dictionary): return garde.call(p, "essai")).size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], filtre == valeur, func():
				ctx.state.filtre_prospects = valeur
				(ctx.reconstruire as Callable).call(), "FilieresFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, func(p: Dictionary, _l: Control): (_fenetre(ctx, func(): T._fenetre_prospect(ctx, p))).call(), func(p: Dictionary, _r: int): return "FilieresJeune_" + str(p.id).validate_node_name(), "FilieresListe", filtres, [], ["obs", true])

# --- Passerelle pro : jeunes pros, prêts, retours -------------------------------------------------------------------------

static func _passerelle(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var jeunes: Array = data.get("seniors", []).filter(func(s: Dictionary): return int(s.age) <= 23 or s.get("loanEligible", false))
	var prets: Array = data.get("loans", [])
	var hotes := {}
	for cl: Dictionary in data.get("loanClubs", []): hotes[int(cl.id)] = str(cl.name)
	var elements: Array = jeunes.duplicate()
	for pr: Dictionary in prets:
		var e := pr.duplicate()
		e.pret = true
		e.hote = hotes.get(int(pr.to), "club %d" % int(pr.to))
		elements.append(e)
	var pretables := jeunes.filter(func(s: Dictionary): return s.get("loanEligible", false))
	var etape := str(ctx.state.get("etape_pro", ""))
	var etapes := [
		["jeunes", "Jeunes pros", V.PROGRES, jeunes.size()],
		["pretables", "Prêtables", V.MINUTES, pretables.size()],
		["prets", "En prêt", V.REPUTATION, prets.size()],
	]
	_chemin(ctx, parent, etapes, etape, "etape_pro", "PasserelleChemin", ["Retour", G.n(prets.size()), V.COHESION, "à l’intersaison", Callable()])
	var montres := elements.filter(func(e: Dictionary): return T._garde_pro(e, etape))
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "statut", "t": "STATUT", "w": 176},
	]
	var cellule := func(cel: Control, col: Dictionary, e: Dictionary):
		var pret: bool = e.get("pret", false)
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, e, "" if pret else "squad")
			"poste": _cel(cel, col, e.get("pos", "—"), Charte.IVOIRE)
			"age": _cel(cel, col, G.n(e.get("age", "—")), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(e) if not pret else "—", V.couleur(V.valeur(e, "rating")), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(e) if not pret else "—", V.couleur(V.valeur(e, "potential")), Charte.TITRE_EXTRA, 17)
			"statut":
				if pret: _pastille(cel, "En prêt · " + str(e.hote), V.REPUTATION, "bus")
				elif e.get("loanEligible", false): _pastille(cel, "Prêtable · Prêter", V.MINUTES, "bus")
				else: _pastille(cel, "Effectif", Charte.IVOIRE_3, "lock")
	var cle := func(e: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(e.get("name", ""))
			"poste": return str(e.get("pos", ""))
			"age": return int(e.get("age", 0))
			"niv": return V.valeur(e, "rating")
			"pot": return V.valeur(e, "potential")
		return null
	var au_clic := func(e: Dictionary, _l: Control):
		if e.get("pret", false): return
		var sid := str(e.id)
		if e.get("loanEligible", false) and not ctx.data.get("locked", false): (_fenetre(ctx, func(): T._fenetre_pret(ctx, sid))).call()
		else: V.ouvrir_fiche(ctx, sid)
	var groupes: Array = [["Prêtables", V.MINUTES, func(e: Dictionary): return e.get("loanEligible", false) and not e.get("pret", false)], ["En effectif", Charte.IVOIRE_3, func(e: Dictionary): return not e.get("loanEligible", false) and not e.get("pret", false)], ["En prêt", V.REPUTATION, func(e: Dictionary): return e.get("pret", false)]]
	var filtres := func(fl: Control):
		for d: Array in [["", "Tous", Charte.IVOIRE, G.n(elements.size())], ["pretables", "Prêtables", V.MINUTES, G.n(pretables.size())], ["prets", "En prêt", V.REPUTATION, G.n(prets.size())]]:
			var valeur := str(d[0])
			_pilule(fl, str(d[1]), d[2], etape == valeur, func():
				ctx.state.etape_pro = valeur
				(ctx.reconstruire as Callable).call(), "PasserelleFiltre_" + valeur, str(d[3]))
	_liste(ctx, parent, colonnes, montres, cellule, cle, au_clic, func(e: Dictionary, _r: int): return "PasserelleLigne_" + str(e.get("id", e.get("name", ""))).validate_node_name(), "PasserelleListe", filtres, groupes, ["age", false])

# --- Générations : la frise des saisons ------------------------------------------------------------------------------------

static func _generations(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var gens: Array = data.get("generations", []).duplicate()
	var frise_def: Array = []
	for g: Dictionary in gens:
		frise_def.append({"titre": G.season_label(g.season), "joueurs": g.players, "promus": int(g.get("graduates", 0)), "reputation": int(g.get("reputation", 0))})
	frise_def.append({"titre": "En cours", "joueurs": data.get("players", []), "promus": data.get("promotions", []).size(), "reputation": int(data.get("reputation", 0)), "courante": true})
	var choix := clampi(int(ctx.state.get("generation", frise_def.size() - 1)), 0, frise_def.size() - 1)
	var frise := _panneau(parent, "La frise des générations", "trophy", "GenerationsFrise")
	var defile := ScrollContainer.new()
	defile.name = "GenerationsFriseDefile"
	defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size.y = 128
	frise.add_child(defile)
	var rail := _rangee(defile, ECART)
	var max_j := 1
	for f: Dictionary in frise_def: max_j = maxi(max_j, (f.joueurs as Array).size())
	for i in frise_def.size():
		var f: Dictionary = frise_def[i]
		var choisi := i == choix
		var teinte := V.MINUTES if f.get("courante", false) else V.REPUTATION
		var b := _zone(V.aller(ctx, "Générations", "generation", i), "GenerationsSaison%d" % i, str(f.titre), Charte.RAYON_CARTE, 116.0, Charte.PANNEAU_2.lerp(teinte, .18) if choisi else Charte.PANNEAU_2, teinte if choisi else Color.TRANSPARENT)
		b.custom_minimum_size.x = 210.0
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cote: String in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + cote, 10)
		b.add_child(m)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(v)
		var tete := _rangee(v, 6)
		var pt := Panel.new()
		pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pt.custom_minimum_size = Vector2(10, 10)
		pt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pt.add_theme_stylebox_override("panel", V.plat(teinte, Color.TRANSPARENT, 0, Charte.RAYON_PILULE))
		tete.add_child(pt)
		_txt(tete, str(f.titre).to_upper(), 18, Charte.IVOIRE, Charte.TITRE_FICHE)
		for br: Array in [[(f.joueurs as Array).size(), max_j, "JOUEURS", V.PROGRES], [int(f.promus), maxi(1, max_j / 4), "PROMUS", V.DEPENSE], [int(f.reputation), 100, "RÉPUTATION", V.REPUTATION]]:
			var r := _rangee(v, 6)
			r.custom_minimum_size.y = 20
			var t := _txt(r, br[2], PETIT, Charte.IVOIRE_2, C.BOLD)
			t.custom_minimum_size.x = 76
			_barre(r, float(br[0]) / float(br[1]), br[3], 8.0)
			var c := _chiffre(r, G.n(br[0]), 16, br[3], HORIZONTAL_ALIGNMENT_RIGHT)
			c.custom_minimum_size.x = 26
		rail.add_child(b)
	var f: Dictionary = frise_def[choix]
	var joueurs: Array = f.joueurs
	var colonnes := [
		{"k": "nom", "t": "JOUEUR", "tri": true, "desc": false},
		{"k": "poste", "t": "POSTE", "w": 108, "tri": true, "desc": false},
		{"k": "age", "t": "ÂGE", "w": 34, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "niv", "t": "NIV.", "w": 40, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "pot", "t": "POT.", "w": 48, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "min", "t": "MIN.", "w": 50, "a": HORIZONTAL_ALIGNMENT_RIGHT, "tri": true},
		{"k": "traj", "t": "TRAJECTOIRE", "w": 112, "tri": true, "desc": false},
	]
	var cellule := func(cel: Control, col: Dictionary, p: Dictionary):
		match str(col.k):
			"nom": _cel_joueur(ctx, cel, p, "academy" if not V.joueur(data, str(p.id)).is_empty() else "")
			"poste": _cel(cel, col, p.pos, Charte.IVOIRE)
			"age": _cel(cel, col, G.n(p.age), Charte.IVOIRE_2)
			"niv": _cel(cel, col, V.niveau_txt(p), V.couleur(V.valeur(p, "rating")), Charte.TITRE_EXTRA, 17)
			"pot": _cel(cel, col, V.potentiel_txt(p), V.couleur(V.valeur(p, "potential")), Charte.TITRE_EXTRA, 17)
			"min": _cel(cel, col, V.mille(p.get("minutes", 0)), V.MINUTES, C.BOLD)
			"traj":
				var t := V.trajectoire(str(p.get("path", p.get("strategy", "equilibre"))))
				_pastille(cel, str(t[1]), t[3], str(t[2]))
	var cle := func(p: Dictionary, k: String) -> Variant:
		match k:
			"nom": return str(p.name)
			"poste": return str(p.pos)
			"age": return int(p.age)
			"niv": return V.valeur(p, "rating")
			"pot": return V.valeur(p, "potential")
			"min": return int(p.get("minutes", 0))
			"traj": return str(p.get("path", p.get("strategy", "")))
		return null
	var au_clic := func(p: Dictionary, _l: Control):
		var pid := str(p.id)
		if not V.joueur(data, pid).is_empty(): (_fenetre(ctx, func(): V.fenetre_parcours(ctx, pid))).call()
		else: V.ouvrir_fiche(ctx, pid)
	var table := _liste(ctx, parent, colonnes, joueurs, cellule, cle, au_clic, func(p: Dictionary, _r: int): return "GenerationsJoueur_" + str(p.id).validate_node_name(), "GenerationsListe", Callable(), [], ["pot", true])
	table.set_meta("courante", f.get("courante", false))
