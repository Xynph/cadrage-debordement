extends RefCounted
## Mises en page A et B de l'onglet Phases arrêtées en combinaisons (planche de l'idée n° 21, 22/11/2026).
## A : barre (phase, attaque/défense, combinaison, choix pivots), consignes par groupe à gauche (glisser une ligne vers un
## autre groupe), terrain zoomé à droite avec les pastilles lettrées.
## B : liste des combinaisons enregistrées à gauche (lignes style Effectif), grand schéma au centre, étapes en lignes
## à cocher, effets du moteur en barres et « qui fait quoi » à droite.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const K = preload("res://ui/immersive08/tactics_combinaisons.gd")

const HAUT := 196.0
const BAS := 1298.0

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func build(app: Control, page: Control, v: String) -> void:
	if v == "B": _build_b(app, page)
	else: _build_a(app, page)

static func _panneau(page: Control, rect: Rect2, id: String) -> Panel:
	var p := D.rect(page, rect, Color(Charte.PANNEAU, .92), Charte.RAYON_PANNEAU)
	p.name = id
	return p

static func _titre(parent: Control, x: float, y: float, texte: String, taille: int = 26, couleur: Color = Charte.IVOIRE) -> Label:
	var t := D.text(parent, x, y, texte.to_upper(), taille, couleur, 700, 800)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	return t

static func _phases_options() -> Array:
	var o: Array = []
	for p: Array in K.PHASES: o.append([p[0], p[1]])
	return o

## Bouton plat rond « + » ou pilule libellée.
static func _bouton(parent: Control, rect: Rect2, texte: String, couleur: Color, action: Callable, id: String) -> Button:
	var b := Button.new()
	b.name = id
	var normal := C.box(Charte.PANNEAU_3, couleur, Charte.RAYON_PILULE, 0)
	Charte.sans_ombre(normal)
	var survol := C.box(Color(couleur, .25), couleur, Charte.RAYON_PILULE, 0)
	Charte.sans_ombre(survol)
	for e in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(e, normal)
	b.add_theme_stylebox_override("hover", survol)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.accessibility_name = texte
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, rect)
	var t := D.text(b, rect.size.x / 2.0, rect.size.y / 2.0 + 7, texte, 20, couleur, 700, rect.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## Schéma de la phase avec ses pastilles lettrées cliquables (petite fenêtre des consignes).
static func _schema(app: Control, page: Control, zone: Rect2, r: float) -> void:
	var e := K.etat(app)
	var combo := K.active(app)
	var schema := K.Schema.new()
	schema.name = "CombiSchema"
	var cadre := K.fenetre(e.phase)
	schema.cadre_m = cadre
	schema.phase = e.phase
	schema.scenario = e.scenario
	schema.choix = combo.choix
	schema.accent = K.couleur_phase(e.phase)
	schema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(schema)
	D.place(schema, zone)
	schema.clip_contents = true
	for g: Dictionary in K.lignes_par_groupe(app):
		var couleur: Color = K.GROUPES.get(g.lettre, Charte.IVOIRE)
		for l: Dictionary in g.lignes:
			if not K.visible(app, l): continue
			var centre := zone.position + Vector2((l.x - cadre.position.x) / cadre.size.x * zone.size.x, (l.y - cadre.position.y) / cadre.size.y * zone.size.y)
			var j := K.jeton(page, centre, l.id, couleur, r * (.9 if e.phase == "lineout" else 1.0))
			j.name = "CombiJeton_" + str(l.id)
			var p := K.joueur(app, int(l.numero))
			var nom := "%s · %s · %s" % [l.id, Kit.casse(str(p.get("name", "")), true), K.libelle_option(l, K.consigne(app, l))]
			var ligne := l
			Pieces.rendre_cliquable(j, Vector2(r, r) * 2, func(): K.fenetre_consigne(app, page, ligne, couleur), "CombiJetonLien_" + str(l.id), nom, nom, Charte.RAYON_PILULE)

# --- Option A ---------------------------------------------------------------------------------------------------------

static func _build_a(app: Control, page: Control) -> void:
	var e := K.etat(app)
	var couleur := K.couleur_phase(e.phase)
	var combo := K.active(app)
	# Barre du haut : phase, scénario, combinaison, effets.
	var barre := _panneau(page, Rect2(0, HAUT, 2248, 168), "CombiBarre")
	Kit.etiquette(barre, 24, 30, "PHASE", 200)
	var x := 24.0 + K.segments(barre, 24, 42, _phases_options(), e.phase, couleur, "CombiPhase", func(v: String): K.choisir_phase(app, v)) + 36
	Kit.etiquette(barre, x, 30, "SCÉNARIO", 200)
	x += K.segments(barre, x, 42, [["attaque", "Attaque"], ["defense", "Défense"]], e.scenario, K.ATTAQUE if e.scenario == "attaque" else K.DEFENSE, "CombiScenario", func(v: String): K.choisir_scenario(app, v)) + 36
	Kit.etiquette(barre, x, 30, "COMBINAISON", 300)
	var index := int(e.actives.get(K._cle(e), 0))
	var texte := "%d · %s  ▾" % [index + 1, str(combo.nom)]
	var w := Kit.largeur(texte, 20) + 40
	_bouton(barre, Rect2(x, 42, w, 44), texte, couleur, func(): K.fenetre_combos(app, page), "CombiChoix")
	_bouton(barre, Rect2(x + w + 8, 42, 44, 44), "+", Charte.IVOIRE, func(): K.ajouter_combo(app), "CombiAjout")
	# Effets réels du moteur, à droite.
	var effets := K.effets(e.phase, e.scenario, combo.choix)
	var ex := 2248.0 - 24
	for i in range(effets.size() - 1, -1, -1):
		var largeur := Pieces.largeur_pastille("%s ▲ 00 %%" % str(effets[i][0]))
		ex -= largeur
		K.puce_effet(barre, ex, 47, effets[i], "CombiEffet%d" % i)
		ex -= 10
	# Ligne 2 : choix pivots.
	var px := 24.0
	for pv: Array in K.pivots(app):
		Kit.etiquette(barre, px, 116, str(pv[1]).to_upper(), 300, false, Charte.IVOIRE_2)
		var agit := K.pivot_agit(e.phase, e.scenario, pv[0])
		if agit: D.text(barre, px + Kit.largeur(str(pv[1]).to_upper(), 16) + 8, 116, "✓", 18, Charte.GAIN, 800, 30)
		var cle := str(pv[0])
		px += K.segments(barre, px, 122, pv[2], str(combo.choix.get(cle, pv[2][0][0])), couleur, "CombiPivot_" + cle, func(v: String): K.choisir_pivot(app, cle, v), 38, 17) + 36
	# Consignes par groupe (deux colonnes), terrain à droite.
	var haut := HAUT + 184
	var groupes := K.lignes_par_groupe(app)
	var colonnes := [[], []]
	var charges := [0, 0]
	for g: Dictionary in groupes:
		var n := 0
		for l: Dictionary in g.lignes: if K.visible(app, l): n += 1
		var c := 0 if charges[0] <= charges[1] else 1
		colonnes[c].append(g)
		charges[c] += n + 2
	var largeur_col := 640.0
	for c in 2:
		var y := haut
		for g: Dictionary in colonnes[c]:
			y += _bloc_groupe(app, page, Rect2(c * (largeur_col + 18), y, largeur_col, 0), g) + 16
	var droite := Rect2(1316, haut, 2248 - 1316, BAS - haut)
	_panneau(page, droite, "CombiTerrainCadre")
	var h := droite.size.y - 28
	var wt := minf(droite.size.x - 28, h * .8)
	_schema(app, page, Rect2(droite.position.x + (droite.size.x - wt) / 2.0, droite.position.y + 14, wt, h), 22)

## Bloc d'un groupe : titre (lettre, nom, nombre), lignes A1, A2… ; on peut y déposer une ligne d'un autre groupe.
static func _bloc_groupe(app: Control, page: Control, zone: Rect2, g: Dictionary) -> float:
	var couleur: Color = K.GROUPES.get(g.lettre, Charte.IVOIRE)
	var lignes: Array = []
	for l: Dictionary in g.lignes: if K.visible(app, l): lignes.append(l)
	var h := 64.0 + maxf(1, lignes.size()) * 60.0 + 8
	var bloc := _panneau(page, Rect2(zone.position, Vector2(zone.size.x, h)), "CombiGroupe_" + str(g.lettre))
	bloc.mouse_filter = Control.MOUSE_FILTER_STOP
	var lettre := str(g.lettre)
	bloc.set_drag_forwarding(Callable(), func(_p: Vector2, data: Variant) -> bool: return data is Dictionary and data.has("combi_ligne"),
		func(_p: Vector2, data: Variant) -> void: K.deplacer(app, str(data.combi_ligne), lettre))
	K.jeton(bloc, Vector2(38, 34), lettre, couleur, 18)
	_titre(bloc, 68, 44, str(g.nom), 26)
	Kit.etiquette(bloc, zone.size.x - 90, 44, "%d" % lignes.size(), 66, true)
	if lignes.is_empty():
		D.rect(bloc, Rect2(16, 66, zone.size.x - 32, 52), Color.TRANSPARENT, Charte.RAYON_PETIT, Charte.FILET)
	for i in lignes.size():
		_ligne_a(app, page, bloc, Rect2(10, 62 + i * 60, zone.size.x - 20, 56), lignes[i], couleur)
	return h

static func _ligne_a(app: Control, page: Control, bloc: Control, rect: Rect2, l: Dictionary, couleur: Color) -> void:
	var b := Button.new()
	b.name = "CombiLigne_" + str(l.id)
	Kit.styler_ligne(b, Color.TRANSPARENT)
	bloc.add_child(b)
	D.place(b, rect)
	var ligne := l
	b.pressed.connect(func(): K.fenetre_consigne(app, page, ligne, couleur))
	var p := K.joueur(app, int(l.numero))
	var lettre := K.groupe_de(app, str(l.id))
	var tirer := func(_p: Vector2) -> Variant:
		var apercu := Control.new()
		K.jeton(apercu, Vector2(24, 24), ligne.id, couleur, 22)
		b.set_drag_preview(apercu)
		return {"combi_ligne": ligne.id}
	var accepter := func(_p: Vector2, data: Variant) -> bool: return data is Dictionary and data.has("combi_ligne")
	var deposer := func(_p: Vector2, data: Variant) -> void: K.deplacer(app, str(data.combi_ligne), lettre)
	b.set_drag_forwarding(tirer, accepter, deposer)
	D.text(b, 12, 36, "⋮⋮", 20, Charte.IVOIRE_3, 700, 24).mouse_filter = Control.MOUSE_FILTER_IGNORE
	K.jeton(b, Vector2(58, 28), l.id, couleur, 19)
	var t := D.text(b, 92, 36, K.libelle_option(l, K.consigne(app, l)), 20, Charte.IVOIRE, 700, 210)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := Vertical._portrait(p, 40)
	b.add_child(portrait)
	portrait.position = Vector2(306, 8) * C.density
	portrait.size = Vector2(40, 40) * C.density
	var nom := Kit.casse(str(p.get("name", "—")), true)
	Kit.nom(app, b, Rect2(354, 12, minf(150, Kit.largeur(nom, 18) + 6), 30), nom, str(p.get("id", "")), "CombiNom_" + str(l.id), Charte.IVOIRE, 18)
	var v: Variant = K.valeur(p, l.attr)
	var vt := "—" if v == null else str(int(v))
	Kit.puce(b, Rect2(rect.size.x - 120, 14, 44, 28), vt, Charte.couleur_attribut(v) if v != null else Charte.PANNEAU_3, Charte.ENCRE, "CombiValeur_" + str(l.id)).tooltip_text = str(l.attr_nom)
	D.text(b, rect.size.x - 66, 34, "▾", 20, Charte.IVOIRE_2, 700, 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Option B ---------------------------------------------------------------------------------------------------------

static func _build_b(app: Control, page: Control) -> void:
	var e := K.etat(app)
	var couleur := K.couleur_phase(e.phase)
	var combo := K.active(app)
	# Colonne gauche : phases (segments), scénario, combinaisons enregistrées en lignes.
	var gauche := _panneau(page, Rect2(0, HAUT, 770, BAS - HAUT), "CombiListeB")
	K.segments(gauche, 20, 20, _phases_options(), e.phase, couleur, "CombiPhase", func(v: String): K.choisir_phase(app, v), 46, 20)
	K.segments(gauche, 20, 80, [["attaque", "Attaque"], ["defense", "Défense"]], e.scenario, K.ATTAQUE if e.scenario == "attaque" else K.DEFENSE, "CombiScenario", func(v: String): K.choisir_scenario(app, v), 40, 18)
	_titre(gauche, 20, 172, "Combinaisons", 28)
	D.line(gauche, Vector2(20, 190), Vector2(750, 190), Charte.FILET)
	var combos := K.liste(app)
	var actif := int(e.actives.get(K._cle(e), 0))
	var y := 200.0
	for i in combos.size():
		_ligne_combo(app, gauche, Rect2(10, y, 750, 112), i, combos[i], i == actif, couleur)
		y += 118
	var plus := _bouton(gauche, Rect2(20, y + 6, 220, 46), "+  Nouvelle", Charte.IVOIRE, func(): K.ajouter_combo(app), "CombiAjout")
	plus.name = "CombiAjout"
	# Centre : grand schéma.
	var centre := Rect2(790, HAUT, 860, BAS - HAUT)
	_panneau(page, centre, "CombiTerrainCadre")
	_titre(page, centre.position.x + 24, centre.position.y + 46, "%d · %s" % [actif + 1, str(combo.nom)], 30, couleur).name = "CombiNomActif"
	var h := centre.size.y - 90
	var wt := minf(centre.size.x - 40, h * .8)
	_schema(app, page, Rect2(centre.position.x + (centre.size.x - wt) / 2.0, centre.position.y + 72, wt, h), 24)
	# Droite : étapes (lignes à cocher), effets, qui fait quoi.
	var droite := _panneau(page, Rect2(1668, HAUT, 2248 - 1668, BAS - HAUT), "CombiEtapes")
	var dy := 20.0
	var n := 1
	for pv: Array in K.pivots(app):
		var cle := str(pv[0])
		Kit.puce(droite, Rect2(20, dy + 4, 32, 30), str(n), couleur, Charte.ENCRE)
		_titre(droite, 64, dy + 30, str(pv[1]), 24)
		if K.pivot_agit(e.phase, e.scenario, cle):
			Pieces.pastille(droite, 580 - 24 - Pieces.largeur_pastille("Moteur", "check"), dy, "Moteur", "check", "CombiMoteur_" + cle, "", Charte.GAIN)
		dy += 44
		var choisi := str(combo.choix.get(cle, pv[2][0][0]))
		for o: Array in pv[2]:
			var oui := str(o[0]) == choisi
			var b := Button.new()
			b.name = "CombiPivot_%s_%s" % [cle, str(o[0])]
			Kit.styler_ligne(b, Color.TRANSPARENT, oui, Color(couleur, .22))
			droite.add_child(b)
			D.place(b, Rect2(12, dy, 556, 44))
			var valeur := str(o[0])
			b.pressed.connect(func(): K.choisir_pivot(app, cle, valeur))
			D.rect(b, Rect2(14, 12, 20, 20), couleur if oui else Color.TRANSPARENT, Charte.RAYON_PILULE, couleur if oui else Charte.IVOIRE_3)
			D.text(b, 48, 30, str(o[1]), 20, couleur if oui else Charte.IVOIRE, 700, 300).mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Effet du moteur pour ce choix (résumé ▲/▼), aligné à droite.
			var choix_test: Dictionary = combo.choix.duplicate()
			choix_test[cle] = valeur
			if K.pivot_agit(e.phase, e.scenario, cle):
				var fx := 540.0
				var liste_ef := K.effets(e.phase, e.scenario, choix_test)
				for k in range(liste_ef.size() - 1, -1, -1):
					var val := float(liste_ef[k][1])
					var signe := "=" if val == 0 else ("▲" if val > 0 else "▼")
					D.text(b, fx - 22, 30, signe, 18, Charte.IVOIRE_3 if val == 0 else (Charte.GAIN if val > 0 else Charte.PERTE), 700, 22, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
					fx -= 24
			dy += 48
		dy += 14
		n += 1
	# Effets en barres divergentes.
	var effets := K.effets(e.phase, e.scenario, combo.choix)
	if not effets.is_empty():
		_titre(droite, 20, dy + 30, "Effet sur le match", 24)
		dy += 50
		for i in effets.size():
			_barre_effet(droite, Rect2(20, dy, 540, 40), effets[i], "CombiBarre%d" % i)
			dy += 46
		dy += 14
	# Qui fait quoi : les premières lignes visibles (jeton, visage, nom, qualité colorée).
	_titre(droite, 20, dy + 30, "Qui fait quoi", 24)
	dy += 48
	var compte := 0
	for g: Dictionary in K.lignes_par_groupe(app):
		var cg: Color = K.GROUPES.get(g.lettre, Charte.IVOIRE)
		for l: Dictionary in g.lignes:
			if compte >= 5 or dy > BAS - HAUT - 60 or not K.visible(app, l): continue
			_ligne_qui(app, page, droite, Rect2(12, dy, 556, 52), l, cg)
			dy += 54
			compte += 1

static func _ligne_combo(app: Control, parent: Control, rect: Rect2, i: int, combo: Dictionary, actif: bool, couleur: Color) -> void:
	var e := K.etat(app)
	var b := Button.new()
	b.name = "CombiLigneB%d" % i
	Kit.styler_ligne(b, Color.TRANSPARENT if i % 2 == 0 else Color(Charte.PANNEAU_2, .6), actif, Color(couleur, .18))
	parent.add_child(b)
	D.place(b, rect)
	var index := i
	b.pressed.connect(func(): K.choisir_combo(app, index))
	if actif: Kit.marqueur(b, Rect2(0, 8, 5, rect.size.y - 16), couleur)
	Kit.puce(b, Rect2(18, 18, 36, 32), str(i + 1), couleur if actif else Charte.PANNEAU_3, Charte.ENCRE if actif else Charte.IVOIRE)
	var t := D.text(b, 70, 44, str(combo.nom).to_upper(), 26, couleur if actif else Charte.IVOIRE, 700, 440)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Choix en pastilles colorées.
	var x := 70.0
	for pv: Array in K.pivots(app):
		var v := str(combo.choix.get(str(pv[0]), pv[2][0][0]))
		var lib := v
		for o: Array in pv[2]: if str(o[0]) == v: lib = str(o[1])
		x += Pieces.pastille(b, x, 62, lib, "", "CombiResume%d_%s" % [i, pv[0]], "", couleur) + 8
	# Effets ▲/▼ compacts à droite.
	var ex := rect.size.x - 16
	var effets := K.effets(e.phase, e.scenario, combo.choix)
	for j in range(effets.size() - 1, -1, -1):
		var v := float(effets[j][1])
		var s := ("▲" if v > 0 else ("▼" if v < 0 else "=")) + " " + str(effets[j][0]).left(4) + "."
		var w := Kit.largeur(s, 16) + 8
		ex -= w
		D.text(b, ex, 40, s, 16, Charte.GAIN if v > 0 else (Charte.PERTE if v < 0 else Charte.IVOIRE_3), 700, w).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ex -= 8

static func _barre_effet(parent: Control, rect: Rect2, ef: Array, id: String) -> void:
	var v := float(ef[1])
	D.text(parent, rect.position.x, rect.position.y + 28, str(ef[0]), 19, Charte.IVOIRE_2, 600, 150)
	var axe := Rect2(rect.position.x + 160, rect.position.y + 12, 280, 16)
	var fond := D.rect(parent, axe, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	fond.name = id
	var milieu := axe.position.x + axe.size.x / 2.0
	var lg := clampf(absf(v) / 12.0, 0.0, 1.0) * axe.size.x / 2.0
	var couleur := Charte.GAIN if v > 0 else Charte.PERTE
	if lg > 0: D.rect(parent, Rect2(milieu if v > 0 else milieu - lg, axe.position.y, lg, axe.size.y), couleur, Charte.RAYON_PILULE)
	D.rect(parent, Rect2(milieu - 1, axe.position.y - 4, 2, axe.size.y + 8), Charte.IVOIRE_2)
	var texte := "=" if v == 0 else "%s%s %s" % ["+" if v > 0 else "−", str(absf(v)).trim_suffix(".0").replace(".", ","), str(ef[2])]
	D.text(parent, rect.end.x, rect.position.y + 28, texte, 20, couleur if v != 0 else Charte.IVOIRE_3, 700, 100, HORIZONTAL_ALIGNMENT_RIGHT)

static func _ligne_qui(app: Control, page: Control, parent: Control, rect: Rect2, l: Dictionary, couleur: Color) -> void:
	var b := Button.new()
	b.name = "CombiQui_" + str(l.id)
	Kit.styler_ligne(b, Color.TRANSPARENT)
	parent.add_child(b)
	D.place(b, rect)
	var ligne := l
	b.pressed.connect(func(): K.fenetre_consigne(app, page, ligne, couleur))
	K.jeton(b, Vector2(30, 26), l.id, couleur, 19)
	var p := K.joueur(app, int(l.numero))
	var portrait := Vertical._portrait(p, 40)
	b.add_child(portrait)
	portrait.position = Vector2(60, 6) * C.density
	portrait.size = Vector2(40, 40) * C.density
	var nom := Kit.casse(str(p.get("name", "—")), true)
	Kit.nom(app, b, Rect2(108, 10, minf(170, Kit.largeur(nom, 18) + 6), 30), nom, str(p.get("id", "")), "CombiQuiNom_" + str(l.id), Charte.IVOIRE, 18)
	D.text(b, 290, 33, K.libelle_option(l, K.consigne(app, l)), 17, couleur, 700, 190).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: Variant = K.valeur(p, l.attr)
	Kit.puce(b, Rect2(rect.size.x - 56, 12, 44, 28), "—" if v == null else str(int(v)), Charte.couleur_attribut(v) if v != null else Charte.PANNEAU_3, Charte.ENCRE).tooltip_text = str(l.attr_nom)
