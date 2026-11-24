extends RefCounted
## Mise en page de l'onglet Tactique › Phases arrêtées (combinaisons, choix B de Léo du 23/11/2026).
## Gauche : phase, attaque/défense, combinaisons enregistrées en lignes (style Effectif) ; un clic = combinaison appliquée.
## Centre : grand schéma de la phase, pastilles lettrées des joueurs (clic = fiche du joueur).
## Droite : étapes (un choix par ligne, appliqué au clic, ▲/▼ de l'effet), effet sur le match en barres, qui fait quoi.
const C = preload("res://ui/immersive08/components.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Vertical = preload("res://ui/immersive08/tactics_vertical.gd")
const K = preload("res://ui/immersive08/tactics_combinaisons.gd")

const HAUT := 196.0
const BAS := 1298.0

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

## Bouton plat en pilule libellée.
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

## Schéma de la phase avec ses pastilles lettrées (clic = fiche du joueur).
static func _schema(app: Control, page: Control, zone: Rect2, r: float) -> void:
	var e := K.etat(app)
	var combo := K.active(app)
	var schema := K.Schema.new()
	schema.name = "CombiSchema"
	var cadre := K.fenetre(e.phase)
	schema.cadre_m = cadre
	schema.phase = e.phase
	schema.scenario = e.scenario
	schema.choix = combo.get("choix", {})
	schema.accent = K.couleur_phase(e.phase)
	schema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(schema)
	D.place(schema, zone)
	schema.clip_contents = true
	for g: Dictionary in K.groupes(e.phase, e.scenario):
		var couleur: Color = K.GROUPES.get(g.lettre, Charte.IVOIRE)
		for l: Dictionary in g.lignes:
			if not K.visible(app, l): continue
			var centre := zone.position + Vector2((l.x - cadre.position.x) / cadre.size.x * zone.size.x, (l.y - cadre.position.y) / cadre.size.y * zone.size.y)
			var j := K.jeton(page, centre, l.id, couleur, r * (.9 if e.phase == "lineout" else 1.0))
			j.name = "CombiJeton_" + str(l.id)
			var p := K.joueur(app, int(l.numero))
			var nom := "%s · %s · %s" % [l.id, Kit.casse(str(p.get("name", "")), true), K.role(e.phase, e.scenario, combo.get("choix", {}), l)]
			Pieces.rendre_cliquable(j, Vector2(r, r) * 2, func(): K.ouvrir_joueur(app, p), "CombiJetonLien_" + str(l.id), nom, nom, Charte.RAYON_PILULE)

static func build(app: Control, page: Control) -> void:
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
	var actif := K.index_actif(app)
	var y := 200.0
	for i in combos.size():
		_ligne_combo(app, gauche, Rect2(10, y, 750, 104), i, combos[i], i == actif, couleur)
		y += 110
	if combos.size() < int(K.donnees(app).get("max", 8)):
		_bouton(gauche, Rect2(20, y + 6, 220, 46), "+  Nouvelle", Charte.IVOIRE, func(): K.ajouter_combo(app), "CombiAjout")
	# Centre : grand schéma.
	var centre := Rect2(790, HAUT, 860, BAS - HAUT)
	_panneau(page, centre, "CombiTerrainCadre")
	_titre(page, centre.position.x + 24, centre.position.y + 46, "%d · %s" % [actif + 1, str(combo.get("nom", ""))], 30, couleur).name = "CombiNomActif"
	var h := centre.size.y - 90
	var wt := minf(centre.size.x - 40, h * .8)
	_schema(app, page, Rect2(centre.position.x + (centre.size.x - wt) / 2.0, centre.position.y + 72, wt, h), 24)
	# Droite : étapes (une ligne par choix), effets, qui fait quoi.
	var droite := _panneau(page, Rect2(1668, HAUT, 2248 - 1668, BAS - HAUT), "CombiEtapes")
	var dy := 20.0
	var n := 1
	var choix: Dictionary = combo.get("choix", {})
	for pv: Dictionary in K.pivots(app):
		var cle := str(pv.get("id", ""))
		Kit.puce(droite, Rect2(20, dy + 4, 32, 30), str(n), couleur, Charte.ENCRE)
		_titre(droite, 64, dy + 30, str(pv.get("label", "")), 24)
		dy += 44
		var options: Array = pv.get("options", [])
		var colonnes := 2 if options.size() > 4 else 1
		var lignes := ceili(options.size() / float(colonnes))
		var largeur := 556.0 / colonnes
		var choisi := str(choix.get(cle, ""))
		for k in options.size():
			var o: Dictionary = options[k]
			var rect := Rect2(12 + (k / lignes) * largeur, dy + (k % lignes) * 48, largeur - (6 if colonnes > 1 else 0), 44)
			_ligne_choix(app, droite, rect, cle, o, str(o.get("id", "")) == choisi, couleur, colonnes == 1)
		dy += lignes * 48 + 14
		n += 1
	# Effets en barres divergentes (tables du moteur).
	var effets: Array = combo.get("effets", [])
	if not effets.is_empty():
		_titre(droite, 20, dy + 30, "Effet sur le match", 24)
		dy += 50
		for i in effets.size():
			_barre_effet(droite, Rect2(20, dy, 540, 40), effets[i], "CombiBarre%d" % i)
			dy += 46
		dy += 14
	# Qui fait quoi : jeton, visage, nom (fiche), rôle déduit des choix, qualité colorée.
	if dy < BAS - HAUT - 140:
		_titre(droite, 20, dy + 30, "Qui fait quoi", 24)
		dy += 48
		for g: Dictionary in K.groupes(e.phase, e.scenario):
			var cg: Color = K.GROUPES.get(g.lettre, Charte.IVOIRE)
			for l: Dictionary in g.lignes:
				if dy > BAS - HAUT - 60 or not K.visible(app, l): continue
				_ligne_qui(app, droite, Rect2(12, dy, 556, 52), l, cg, choix)
				dy += 54

static func _ligne_combo(app: Control, parent: Control, rect: Rect2, i: int, combo: Dictionary, actif: bool, couleur: Color) -> void:
	var b := Button.new()
	b.name = "CombiLigneB%d" % i
	Kit.styler_ligne(b, Color.TRANSPARENT if i % 2 == 0 else Color(Charte.PANNEAU_2, .6), actif, Color(couleur, .18))
	parent.add_child(b)
	D.place(b, rect)
	var index := i
	b.pressed.connect(func(): K.choisir_combo(app, index))
	if actif: Kit.marqueur(b, Rect2(0, 8, 5, rect.size.y - 16), couleur)
	Kit.puce(b, Rect2(18, 16, 36, 32), str(i + 1), couleur if actif else Charte.PANNEAU_3, Charte.ENCRE if actif else Charte.IVOIRE)
	var t := D.text(b, 70, 42, str(combo.get("nom", "")).to_upper(), 26, couleur if actif else Charte.IVOIRE, 700, 440)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Choix en pastilles colorées.
	var x := 70.0
	var choix: Dictionary = combo.get("choix", {})
	var e := K.etat(app)
	for pv: Dictionary in K.pivots(app):
		var v := str(choix.get(str(pv.get("id", "")), ""))
		var c := couleur
		if e.phase == "penalty" and e.scenario == "attaque": c = K.COULEURS_PENALITE.get(v, couleur)
		x += Pieces.pastille(b, x, 58, K.libelle_choix(pv, v), "", "CombiResume%d_%s" % [i, pv.get("id", "")], "", c) + 8
	# Effets ▲/▼ compacts à droite (vert = bon pour nous).
	var ex := rect.size.x - 16
	var effets: Array = combo.get("effets", [])
	for j in range(effets.size() - 1, -1, -1):
		var f := K.favorable(effets[j])
		var v := float(effets[j][1])
		var s := ("▲" if v > 0 else ("▼" if v < 0 else "=")) + " " + str(effets[j][0]).replace("Leur ", "").replace("Leurs ", "").left(4) + "."
		var w := Kit.largeur(s, 16) + 8
		ex -= w
		D.text(b, ex, 40, s, 16, Charte.GAIN if f > 0 else (Charte.PERTE if f < 0 else Charte.IVOIRE_3), 700, w).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ex -= 8

## Une ligne d'option d'une étape : rond coché, libellé, ▲/▼ de ses effets ; un clic l'applique.
static func _ligne_choix(app: Control, parent: Control, rect: Rect2, cle: String, o: Dictionary, oui: bool, couleur: Color, avec_effets: bool) -> void:
	var b := Button.new()
	var id := str(o.get("id", ""))
	b.name = "CombiPivot_%s_%s" % [cle, id]
	var e := K.etat(app)
	var c := couleur
	if e.phase == "penalty" and e.scenario == "attaque": c = K.COULEURS_PENALITE.get(id, couleur)
	Kit.styler_ligne(b, Color.TRANSPARENT, oui, Color(c, .22))
	parent.add_child(b)
	D.place(b, rect)
	b.pressed.connect(func(): K.choisir_pivot(app, cle, id))
	D.rect(b, Rect2(14, 12, 20, 20), c if oui else Color.TRANSPARENT, Charte.RAYON_PILULE, c if oui else Charte.IVOIRE_3)
	D.text(b, 48, 30, str(o.get("label", "")), 20, c if oui else Charte.IVOIRE, 700, rect.size.x - 60).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not avec_effets: return
	var fx := rect.size.x - 16
	var effets: Array = o.get("effets", [])
	for k in range(effets.size() - 1, -1, -1):
		var f := K.favorable(effets[k])
		var v := float(effets[k][1])
		var signe := "=" if is_zero_approx(v) else ("▲" if v > 0 else "▼")
		D.text(b, fx - 22, 30, signe, 18, Charte.IVOIRE_3 if f == 0 else (Charte.GAIN if f > 0 else Charte.PERTE), 700, 22, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx -= 24

static func _barre_effet(parent: Control, rect: Rect2, ef: Array, id: String) -> void:
	var v := float(ef[1])
	var f := K.favorable(ef)
	D.text(parent, rect.position.x, rect.position.y + 28, str(ef[0]), 19, Charte.IVOIRE_2, 600, 170)
	var axe := Rect2(rect.position.x + 180, rect.position.y + 12, 260, 16)
	var fond := D.rect(parent, axe, Charte.PANNEAU_3, Charte.RAYON_PILULE)
	fond.name = id
	var milieu := axe.position.x + axe.size.x / 2.0
	var lg := clampf(absf(v) / 12.0, 0.0, 1.0) * axe.size.x / 2.0
	var couleur := Charte.GAIN if f > 0 else Charte.PERTE
	if lg > 0: D.rect(parent, Rect2(milieu if v > 0 else milieu - lg, axe.position.y, lg, axe.size.y), couleur, Charte.RAYON_PILULE)
	D.rect(parent, Rect2(milieu - 1, axe.position.y - 4, 2, axe.size.y + 8), Charte.IVOIRE_2)
	var texte := "=" if is_zero_approx(v) else "%s%s %s" % ["+" if v > 0 else "−", str(absf(v)).trim_suffix(".0").replace(".", ","), str(ef[2])]
	D.text(parent, rect.end.x, rect.position.y + 28, texte, 20, couleur if f != 0 else Charte.IVOIRE_3, 700, 100, HORIZONTAL_ALIGNMENT_RIGHT)

static func _ligne_qui(app: Control, parent: Control, rect: Rect2, l: Dictionary, couleur: Color, choix: Dictionary) -> void:
	var e := K.etat(app)
	var b := Panel.new()
	b.name = "CombiQui_" + str(l.id)
	b.add_theme_stylebox_override("panel", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	parent.add_child(b)
	D.place(b, rect)
	K.jeton(b, Vector2(30, 26), l.id, couleur, 19)
	var p := K.joueur(app, int(l.numero))
	var portrait := Vertical._portrait(p, 40)
	b.add_child(portrait)
	portrait.position = Vector2(60, 6) * C.density
	portrait.size = Vector2(40, 40) * C.density
	var nom := Kit.casse(str(p.get("name", "—")), true)
	Kit.nom(app, b, Rect2(108, 10, minf(170, Kit.largeur(nom, 18) + 6), 30), nom, str(p.get("id", "")), "CombiQuiNom_" + str(l.id), Charte.IVOIRE, 18)
	D.text(b, 290, 33, K.role(e.phase, e.scenario, choix, l), 17, couleur, 700, 190).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: Variant = K.valeur(p, l.attr)
	var en_plage := v != null and not PlayerAttributes.plage(p, str(l.attr)).is_empty()
	Kit.puce(b, Rect2(rect.size.x - (76 if en_plage else 56), 12, 64 if en_plage else 44, 28), "—" if v == null else PlayerAttributes.caption_joueur(p, str(l.attr), v), Charte.couleur_attribut(v) if v != null else Charte.PANNEAU_3, Charte.ENCRE).tooltip_text = str(l.attr_nom)
