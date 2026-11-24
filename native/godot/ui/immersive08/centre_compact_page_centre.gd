extends "res://ui/immersive08/centre_compact_listes.gd"
## Centre compact : onglet Centre, le chemin de la détection à l'équipe première (découpe de centre_compact.gd, sans changement).

# --- Centre : le chemin de la détection à l'équipe première -------------------------------------------------------------

static func _centre(ctx: Dictionary, parent: Node) -> void:
	var data: Dictionary = ctx.data
	var app: Control = ctx.app
	var verrou: bool = data.get("locked", false)
	var colonnes := _rangee(parent, ECART)
	colonnes.name = "CentreCompactChemin"
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", ECART)
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.size_flags_stretch_ratio = 1.0
	colonnes.add_child(gauche)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", ECART)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_stretch_ratio = 1.0
	colonnes.add_child(droite)
	# 1. Détection
	var det := _panneau(gauche, "Détection", "search", "CentreDetection", V.aller(ctx, "Filières"))
	var scout := V.cout(ctx, "scout", 35000)
	var faite: bool = data.get("nextScouted", false)
	_legende(det, "Détection annuelle")
	var rang := _rangee(det, ECART)
	_chiffre(rang, V.euros(scout), 30, Charte.IVOIRE_3 if faite else V.DEPENSE)
	_espace(rang)
	if faite: _pastille(rang, "Faite", V.PROGRES, "check").name = "CentreDetectionFaite"
	else: _pilule(rang, "Lancer", V.DEPENSE, true, func(): V.envoyer(ctx, "academy_scout", {}, scout, "Détection annuelle"), "CentreDetectionLancer", "", not verrou)
	var observes: int = data.get("centers", []).filter(func(c: Dictionary): return c.get("scouted", false) and not c.get("own", false)).size()
	var lignes := [
		["search", "Centres observés", G.n(observes), V.MINUTES, V.aller(ctx, "Centres")],
		["people", "Jeunes repérés", G.n(data.get("prospects", []).size()), V.PROGRES, V.aller(ctx, "Filières")],
		["flag", "Clubs partenaires", G.n(data.get("partners", []).size()), V.COHESION, V.aller(ctx, "Filières")],
		["money", "Enveloppe", V.mille(data.get("recruitBudget", 0)) + " €", V.DEPENSE, V.aller(ctx, "Centres")],
	]
	for i in lignes.size():
		var l: Array = lignes[i]
		_ligne_chiffre(det, l[0], l[1], l[2], l[3], l[4], "CentreDetectionLigne%d" % i)
	var regions: Array = data.get("regions", [])
	if not regions.is_empty():
		var prospects: Array = data.get("prospects", [])
		var max_r := 1
		for zr: Variant in regions: max_r = maxi(max_r, prospects.filter(func(q: Dictionary): return str(q.region) == str(zr)).size())
		var bloc := _zone(V.aller(ctx, "Filières"), "CentreDetectionRegions", "Jeunes repérés par région", 8, 10.0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bloc.add_child(v)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 4
		bloc.custom_minimum_size.y = regions.size() * 22.0 + 8.0
		for i in regions.size():
			var rg := str(regions[i])
			var teinte: Color = V.COULEURS[i % V.COULEURS.size()]
			var n := prospects.filter(func(q: Dictionary): return str(q.region) == rg).size()
			var r := _rangee(v, 6)
			r.custom_minimum_size.y = 20
			var t := _txt(r, rg, PETIT, Charte.IVOIRE_2, C.BOLD)
			t.custom_minimum_size.x = 86
			_barre(r, float(n) / max_r, teinte, 8.0)
			var c := _chiffre(r, G.n(n), 16, teinte, HORIZONTAL_ALIGNMENT_RIGHT)
			c.custom_minimum_size.x = 24
		det.add_child(bloc)
	# 2. Le centre
	var joueurs: Array = data.get("players", [])
	var ctr := _panneau(droite, "Le centre", "school", "CentreLeCentre", V.aller(ctx, "Parcours"), G.n(joueurs.size()), V.PROGRES)
	_jauge(ctr, "heart", "Cohésion", float(data.get("cohesion", 0)), V.COHESION, Callable(), "")
	_jauge(ctr, "star", "Réputation", float(data.get("reputation", 0)), V.REPUTATION, V.aller(ctx, "Générations"), "CentreJaugeReputation")
	var etapes := _rangee(ctr, ECART)
	for e: Array in V.ETAPES:
		var n := joueurs.filter(func(p: Dictionary): return V.etape(p) == str(e[0])).size()
		var c := _zone(V.aller(ctx, "Parcours", "etape", str(e[0])), "CentreEtape_" + str(e[0]), str(e[1]), Charte.RAYON_CARTE, 54.0, Charte.PANNEAU_2)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_top", 2)
		c.add_child(m)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", -4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		m.add_child(cv)
		_chiffre(cv, G.n(n), 26, e[2])
		_legende(cv, str(e[1]), Charte.IVOIRE_2)
		var bande := Panel.new()
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.add_theme_stylebox_override("panel", V.plat(e[2], Color.TRANSPARENT, 0, 3))
		c.add_child(bande)
		bande.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		bande.offset_right = 4
		etapes.add_child(c)
	for k in 2:
		var kind := "facilities" if k == 0 else "coaches"
		var niveau := int(data.get(kind, 0))
		var prix := T._cout_niveau(data, kind, niveau, (niveau + 1) * (85000 if k == 0 else 55000)) if niveau < 3 else 0
		var titre := "Installations" if k == 0 else "Éducateurs"
		var r := _rangee(ctr, 8)
		r.custom_minimum_size.y = 32
		_icone(r, "home" if k == 0 else "people", 16, V.PROGRES)
		_txt(r, titre, CORPS, Charte.IVOIRE, C.BOLD)
		_crans(r, niveau, 3, V.PROGRES)
		_espace(r)
		if niveau < 3: _pilule(r, V.euros(prix), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_upgrade", {"kind": kind}, prix, titre), "CentreAmeliorer_" + kind, "", not verrou)
		else: _pastille(r, "3 / 3", V.PROGRES, "check").name = "CentreMax_" + kind
	var reunion := V.cout(ctx, "meeting", 2000)
	var rr := _rangee(ctr, 8)
	rr.custom_minimum_size.y = 32
	_icone(rr, "people", 16, V.COHESION)
	_txt(rr, "Réunion de cohésion", CORPS, Charte.IVOIRE, C.BOLD)
	_espace(rr)
	_pilule(rr, V.euros(reunion), V.DEPENSE, false, func(): V.envoyer(ctx, "academy_meeting", {}, reunion, "Réunion de cohésion"), "CentreReunion", "", not verrou)
	# 3. Rencontres juniors
	var ouvrir_juniors := _fenetre(ctx, func(): Juniors.ouvrir(app, ctx.page))
	var ren := _panneau(gauche, "Rencontres juniors", "trophy", "CentreRencontres", ouvrir_juniors)
	var ronde := int(data.get("juniorRound", 0))
	var total := maxi(1, int(data.get("totalRounds", 26)))
	var rt := _rangee(ren, 6)
	_chiffre(rt, G.n(ronde), 34, V.MINUTES)
	_legende(rt, "/ %d périodes" % total, Charte.IVOIRE_2, CORPS)
	var segments := _rangee(ren, 2)
	for i in total:
		var s := Panel.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.custom_minimum_size = Vector2(4, 10)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.add_theme_stylebox_override("panel", V.plat(Color(V.MINUTES, .9) if i < ronde else Charte.PANNEAU_3, Color.TRANSPARENT, 0, 3))
		segments.add_child(s)
	var resultats: Array = data.get("results", []).duplicate()
	resultats.reverse()
	var club := int(data.get("clubId", -1))
	if not resultats.is_empty(): _legende(ren, "Derniers matchs")
	for i in mini(resultats.size(), 6):
		var r: Dictionary = resultats[i]
		var dom := int(r.get("home", -1)) == club
		var pour := int(r.score[0] if dom else r.score[1])
		var contre := int(r.score[1] if dom else r.score[0])
		var teinte := V.PROGRES if pour > contre else (V.ALERTE if pour < contre else Charte.IVOIRE_2)
		var ligne := _zone(ouvrir_juniors, "CentreResultat%d" % i, "Période %d" % (int(r.get("round", 0)) + 1), 6, 30.0)
		var h := _dans(ligne, 6, 8)
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(24, 22)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("panel", V.plat(Color(teinte, .2), Color.TRANSPARENT, 0, 6))
		_chiffre(badge, "V" if pour > contre else ("D" if pour < contre else "N"), 17, teinte, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_child(badge)
		_txt(h, "P%d" % (int(r.get("round", 0)) + 1), PETIT, Charte.IVOIRE_3, C.BOLD)
		_chiffre(h, "%d – %d" % [pour, contre], 20, Charte.IVOIRE)
		_txt(h, str(r.get("awayCenter") if dom else r.get("homeCenter")), CORPS, Charte.IVOIRE_2, C.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		ren.add_child(ligne)
	var bilan := [0, 0, 0]
	var points := [0, 0]
	for r: Dictionary in resultats:
		var dom2 := int(r.get("home", -1)) == club
		var a2 := int(r.score[0] if dom2 else r.score[1])
		var b2 := int(r.score[1] if dom2 else r.score[0])
		points[0] += a2
		points[1] += b2
		bilan[0 if a2 > b2 else (1 if a2 == b2 else 2)] += 1
	if not resultats.is_empty():
		var tuiles := _rangee(ren, ECART)
		for t: Array in [[bilan[0], "VICTOIRES", V.PROGRES], [bilan[1], "NULS", Charte.IVOIRE_2], [bilan[2], "DÉFAITES", V.ALERTE]]:
			var c := PanelContainer.new()
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var sc := V.plat(Charte.PANNEAU_2.lerp(t[2], .12), Color.TRANSPARENT, 0, Charte.RAYON_CARTE)
			sc.content_margin_left = 10
			sc.content_margin_top = 4
			sc.content_margin_bottom = 4
			c.add_theme_stylebox_override("panel", sc)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", -4)
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(cv)
			_chiffre(cv, G.n(t[0]), 24, t[2])
			_legende(cv, t[1], Charte.IVOIRE_2)
			tuiles.add_child(c)
		_ligne_chiffre(ren, "ball", "Points marqués · encaissés", "%d · %d" % [points[0], points[1]], V.MINUTES, Callable(), "")
	var mode := "developpement" if str(data.get("mode", "")) == "formation" else str(data.get("mode", ""))
	for m: Array in T.MODES:
		if m[0] == mode:
			var pm := _pastille(null, str(m[1]), m[2], "calendar")
			pm.name = "CentrePlanActif"
			pm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			ren.add_child(pm)
	# 4. Équipe première
	var prem := _panneau(droite, "Équipe 1re", "shield", "CentrePremiere", func(): app._navigate("Effectif"))
	var places := int(data.get("places", 0))
	var rp := _rangee(prem, 8)
	_chiffre(rp, G.n(places), 40, V.REPUTATION)
	_legende(rp, "places pro libres", Charte.IVOIRE_2, CORPS)
	var sieges := _flux(prem, 6)
	for i in places:
		var s := PanelContainer.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.custom_minimum_size = Vector2(30, 30)
		var ss := V.plat(Color.TRANSPARENT, V.REPUTATION, 2, Charte.RAYON_PILULE)
		s.add_theme_stylebox_override("panel", ss)
		var cm := CenterContainer.new()
		cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(cm)
		_icone(cm, "people", 16, Color(V.REPUTATION, .8))
		sieges.add_child(s)
	_ligne_chiffre(prem, "trophy", "Promus", G.n(data.get("promotions", []).size()), V.DEPENSE, V.aller(ctx, "Passerelle pro"), "CentrePromus")
	_ligne_chiffre(prem, "people", "Effectif pro", "%s / %s" % [G.n(data.get("occupied", 0)), G.n(data.get("capacity", 0))], Charte.IVOIRE, func(): app._navigate("Effectif"), "CentreEffectifPro")
	_ligne_chiffre(prem, "bus", "En prêt", G.n(data.get("loans", []).size()), V.COHESION, V.aller(ctx, "Passerelle pro"), "CentrePrets")
	# Réglages du centre : pastilles, la valeur active en aplat de sa couleur.
	var regl := _panneau(parent, "Réglages", "settings", "CentreReglages")
	var choix := func(commande: String, cle: String) -> Callable:
		return func(v: Variant): V.envoyer(ctx, commande, {cle: v})
	var rangs := [["Plan des rencontres", T.MODES, mode, choix.call("academy_mode", "mode"), "CentreMode"], ["Objectif annuel", T.OBJECTIFS, str(data.get("goal", "")), choix.call("academy_goal", "goal"), "CentreObjectif"], ["Identité", T.IDENTITES, str(data.get("identity", "")), choix.call("academy_identity", "identity"), "CentreIdentite"]]
	for rg: Array in rangs:
		var ligne := _rangee(regl, ECART)
		var t := _legende(ligne, str(rg[0]))
		t.custom_minimum_size.x = 120
		var f := _flux(ligne, 6)
		for o: Array in rg[1]:
			var valeur: Variant = o[0]
			_pilule(f, str(o[1]), o[2], str(rg[2]) == str(valeur), (rg[3] as Callable).bind(valeur), "%s_%s" % [rg[4], str(valeur).validate_node_name()], "", not verrou)
