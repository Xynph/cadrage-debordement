extends RefCounted
## Planche A/B « Tests physiques avant le match » (revue FM27, idée 36), sous CD_VARIANTE_VISUELLE=A|B, depuis la tuile
## « Ta feuille » de l'avant-match (match_avant.gd).
## Joueurs testés (données du moteur) : blessés qui reviennent (1-2 semaines restantes), commotion en protocole ou
## récente, joueurs en méforme (condition < 70). Le moteur efface la blessure à la guérison : « revenu de blessure il y a
## moins de 2 semaines » n'existe pas (à ajouter au moteur). Résultat du test et minutes conseillées : règle PROVISOIRE de
## l'écran (condition, fragilité, semaines restantes) ; à porter au moteur si Léo retient l'idée.
## A : sous-page de l'avant-match, liste façon Effectif (silhouette par ligne, barre des minutes sur 80′).
## B : petite fenêtre, un seul corps face / dos avec les zones numérotées, liste à droite, minutes en anneau.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const Blessure = preload("res://ui/immersive08/fenetre_blessure.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const PAGE := "tests"
const FENETRE := "FenetreTestsPhysiques"
const LARGEUR := 2000.0
const LIGNE := 118.0
## Résultats : id → [mot, couleur, icône].
const RESULTATS := {"reussi": ["Réussi", R.VERT, "check"], "partiel": ["Partiel", R.ORANGE, "warning"], "echec": ["Échoué", R.ROUGE, "warning"], "inutile": ["Non requis", Charte.IVOIRE_2, "info"]}
const RAISONS := {"reprise": ["Reprise", R.ROUGE, "heart"], "commotion": ["Commotion", R.VIOLET, "shield"], "meforme": ["Méforme", R.ORANGE, "clock"]}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func _n(v: Variant, d: float = -1.0) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else d

static func _jours_depuis(model: Dictionary, iso: String) -> int:
	var meta: Dictionary = model.get("meta", {})
	var a := str(meta.get("calendarToday", meta.get("date", "")))
	if a.length() < 10 or iso.length() < 10: return 999
	return int((Time.get_unix_time_from_datetime_string(a.substr(0, 10) + "T00:00:00") - Time.get_unix_time_from_datetime_string(iso.substr(0, 10) + "T00:00:00")) / 86400)

## Joueurs testés : [{j, raison, type, libelle, droite, resultat, minutes, score}], 6 au plus.
static func candidats(model: Dictionary) -> Array:
	var r: Array = []
	for p: Variant in model.get("squad", []):
		if not p is Dictionary: continue
		var j: Dictionary = p
		var sem := _n(j.get("injury"), 0.0)
		var cond := _n(j.get("condition"), 100.0)
		var com: Variant = j.get("commotion")
		var raison := ""
		var type := ""
		if sem > 0 and sem <= 2:
			raison = "reprise"
			type = str(j.get("injuryType", ""))
		elif com is Dictionary and (bool(com.get("enCours", false)) or _jours_depuis(model, str(com.get("derniere", ""))) <= 21):
			raison = "commotion"
			type = "commotion"
		elif sem <= 0 and cond < 70:
			raison = "meforme"
		if raison.is_empty(): continue
		r.append(_fiche(model, j, raison, type))
	if r.is_empty():
		# Repli de la planche (carrière sans blessé ni méforme) : les trois plus entamés.
		var tous: Array = model.get("squad", []).filter(func(p: Variant) -> bool: return p is Dictionary and _n(p.get("injury"), 0.0) <= 0)
		tous.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _n(a.get("condition"), 100) < _n(b.get("condition"), 100))
		for j: Dictionary in tous.slice(0, 3): r.append(_fiche(model, j, "meforme", ""))
	var ordre := {"reprise": 0, "commotion": 1, "meforme": 2}
	r.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return ordre[a.raison] < ordre[b.raison] or ordre[a.raison] == ordre[b.raison] and float(a.score) < float(b.score))
	return r.slice(0, 6)

static func _fiche(model: Dictionary, j: Dictionary, raison: String, type: String) -> Dictionary:
	var sem := _n(j.get("injury"), 0.0)
	var cond := _n(j.get("condition"), 100.0)
	var frag := _n(j.get("fragilite"), 50.0)
	var com: Variant = j.get("commotion")
	var score := cond - (frag - 50.0) * 0.3 - sem * 12.0 - (20.0 if com is Dictionary and bool(com.get("enCours", false)) else 0.0)
	var resultat := "reussi"
	var minutes := 80
	if score < 55:
		resultat = "echec"
		minutes = 0
	elif score < 68:
		resultat = "partiel"
		minutes = 45
	elif score < 80:
		resultat = "partiel"
		minutes = 60
	# Méforme sans blessure : test non requis au-dessus de 65 % de condition (temps de jeu limité à 60′).
	if raison == "meforme" and cond >= 65:
		resultat = "inutile"
		minutes = mini(minutes, 60) if minutes > 0 else 60
	var libelle := ""
	if raison == "reprise": libelle = str(ClubMail.injury_label(model, j))
	elif raison == "commotion": libelle = "Commotion · protocole" if bool(com.get("enCours", false)) else "Commotion récente"
	else: libelle = "Condition %d %%" % roundi(cond)
	return {"j": j, "raison": raison, "type": type, "libelle": libelle, "droite": hash(str(j.get("id", "")) + ":cote") % 2 == 0,
		"resultat": resultat, "minutes": minutes, "score": score, "semaines": int(sem)}

static func _mot_minutes(c: Dictionary) -> String:
	if int(c.minutes) <= 0: return "Ne pas aligner"
	if int(c.minutes) >= 80: return "Match entier"
	return "%d′ max" % int(c.minutes)

static func _couleur_minutes(c: Dictionary) -> Color:
	return R.ROUGE if int(c.minutes) <= 0 else R.VERT if int(c.minutes) >= 80 else R.ORANGE

## Entrée depuis la tuile « Ta feuille » : lien avec le nombre de joueurs testés et le nombre de soucis.
static func lien(avant: Control, model: Dictionary) -> Array:
	var cs := candidats(model)
	if cs.is_empty(): return []
	var soucis := cs.filter(func(c: Dictionary) -> bool: return c.resultat in ["partiel", "echec"]).size()
	var texte := "Tests physiques · %d%s →" % [cs.size(), (" · %d à ménager" % soucis) if soucis > 0 else ""]
	return [texte, func(): ouvrir(avant, model), "MatchTestsPhysiques", "Résultats des tests physiques"]

static func ouvrir(avant: Control, model: Dictionary) -> void:
	if variante() == "A": avant.ouvrir_page(PAGE)
	else: _fenetre(avant, model)

# ------------------------------------------------------------------ éléments communs

## Corps face et dos, zone touchée en halo (dessin de la fenêtre blessure).
static func _corps(parent: Control, rect: Rect2, c: Dictionary, nom: String) -> void:
	var largeur := rect.size.x / 2.0 - 4.0
	for i in 2:
		var vue := "F" if i == 0 else "B"
		var s := Blessure.Silhouette.new()
		s.name = nom + vue
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.dessin = Blessure.texture(vue)
		s.point = Blessure.point_zone(str(c.type), bool(c.droite), vue) if not str(c.type).is_empty() else Vector2(-1, -1)
		s.rayon = float(Blessure.ZONES.get(str(c.type), {}).get("r", 0.0))
		s.modulate = Color(1, 1, 1, 1.0 if not str(c.type).is_empty() else 0.45)
		parent.add_child(s)
		D.place(s, Rect2(rect.position.x + i * (largeur + 8.0), rect.position.y, largeur, rect.size.y))

static func _ouvrir_joueur(avant: Control, page: Control, c: Dictionary) -> void:
	var id := str(c.j.get("id", ""))
	if int(c.semaines) > 0:
		Blessure.ouvrir(page, avant.app, id)
	else:
		Fenetre.fermer(page, FENETRE)
		avant._ouvrir_joueur(id)

# ------------------------------------------------------------------ A : sous-page, liste façon Effectif

static func page(avant: Control, app: Control, model: Dictionary) -> Control:
	var zone := MarginContainer.new()
	zone.name = "MatchPage"
	C.fill(zone, true)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, avant.M(32))
	zone.add_theme_constant_override("margin_top", avant.M(20))
	zone.add_theme_constant_override("margin_bottom", avant.M(8))
	var cs := candidats(model)
	var hauteur := 190.0 + LIGNE * cs.size() + 20.0
	var cadre := Panel.new()
	cadre.name = "TestsPhysiquesPage"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Charte.PANNEAU, .96)
	st.set_corner_radius_all(Charte.RAYON_PANNEAU)
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(st))
	cadre.custom_minimum_size = Vector2(LARGEUR, hauteur) * C.density
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zone.add_child(cadre)
	var titre := D.text(cadre, 36, 62, "TESTS PHYSIQUES", 40, Charte.IVOIRE, 700, 600)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var x := 470.0
	for res: String in ["reussi", "partiel", "echec", "inutile"]:
		var n := cs.filter(func(c: Dictionary) -> bool: return c.resultat == res).size()
		if n == 0: continue
		var p := R.pastille(cadre, x, 60, "%d %s" % [n, str(RESULTATS[res][0]).to_lower()], RESULTATS[res][1], RESULTATS[res][2], "TestsPhysiquesCompte_" + res, 22)
		x += p.size.x / C.density + 14.0
	# En-têtes de colonnes (triables plus tard comme l'Effectif).
	var cols := [[36, "JOUEUR"], [520, "MOTIF"], [930, "CORPS"], [1100, "TEST"], [1320, "MINUTES CONSEILLÉES"], [1730, "FORME"], [1860, "RISQUE"]]
	D.rect(cadre, Rect2(20, 102, LARGEUR - 40, 46), Charte.BANDEAU_ENTETE, 6)
	for col: Array in cols: D.text(cadre, float(col[0]), 133, str(col[1]), 17, Charte.IVOIRE_3, 700, 360)
	var y := 160.0
	var i := 0
	for c: Dictionary in cs:
		i += 1
		_ligne_a(cadre, avant, app, c, Rect2(20, y, LARGEUR - 40, LIGNE), i)
		y += LIGNE
	return zone

static func _ligne_a(cadre: Control, avant: Control, app: Control, c: Dictionary, rect: Rect2, i: int) -> void:
	var j: Dictionary = c.j
	var ligne := Control.new()
	ligne.name = "TestsPhysiquesLigne%d" % i
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(ligne)
	D.place(ligne, rect)
	if i % 2 == 0: D.rect(ligne, Rect2(0, 0, rect.size.x, rect.size.y), Charte.PANNEAU_2, 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Panneaux._bouton(ligne, Rect2(0, 0, rect.size.x, rect.size.y), func(): _ouvrir_joueur(avant, avant, c), "TestsPhysiquesOuvrir%d" % i, str(j.get("name", "")))
	var res: Array = RESULTATS[c.resultat]
	Panneaux._portrait(ligne, j, Rect2(16, 16, 84, 84), res[1], 3)
	var nom := D.text(ligne, 118, 52, str(j.get("name", "")), 26, Charte.IVOIRE, 700, 380)
	nom.name = "TestsPhysiquesNom%d" % i
	D.text(ligne, 118, 86, str(j.get("pos", "")), 20, Charte.IVOIRE_2, 600, 380)
	var raison: Array = RAISONS[c.raison]
	R.pastille(ligne, 500, 50, str(raison[0]), raison[1], raison[2], "TestsPhysiquesMotif%d" % i, 20)
	D.text(ligne, 500, 92, str(c.libelle), 20, Charte.IVOIRE, 600, 400)
	_corps(ligne, Rect2(910, 8, 120, rect.size.y - 16), c, "TestsPhysiquesCorps%d" % i)
	R.pastille(ligne, 1080, 70, str(res[0]), res[1], res[2], "TestsPhysiquesTest%d" % i, 22)
	# Minutes : barre sur 80′, repères 40 et 60, part conseillée en couleur, mot à droite.
	var bx := 1300.0
	var bl := 220.0
	D.rect(ligne, Rect2(bx, 50, bl, 18), Charte.PANNEAU_3, 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if int(c.minutes) > 0: D.rect(ligne, Rect2(bx, 50, bl * float(c.minutes) / 80.0, 18), _couleur_minutes(c), 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in [40, 60]: D.line(ligne, Vector2(bx + bl * m / 80.0, 44), Vector2(bx + bl * m / 80.0, 74), Charte.IVOIRE_3, 2)
	D.text(ligne, bx, 100, "0′", 16, Charte.IVOIRE_3, 600, 40)
	D.text(ligne, bx + bl - 40, 100, "80′", 16, Charte.IVOIRE_3, 600, 40, HORIZONTAL_ALIGNMENT_RIGHT)
	D.text(ligne, bx + bl + 20, 68, _mot_minutes(c), 22, _couleur_minutes(c), 700, 180)
	var cond := _n(j.get("condition"))
	D.text(ligne, 1710, 70, "%d %%" % roundi(cond) if cond >= 0 else "?", 26, Charte.couleur_attribut(cond), 700, 110)
	var risque := _n(j.get("risqueBlessure"))
	D.text(ligne, 1840, 70, ("%s %%" % str(risque).replace(".", ",")) if risque >= 0 else "?", 26, R.ROUGE if risque >= 6 else R.ORANGE if risque > 3 else R.VERT, 700, 110)
	D.line(ligne, Vector2(0, rect.size.y - 1), Vector2(rect.size.x, rect.size.y - 1), Charte.FILET, 1)

# ------------------------------------------------------------------ B : petite fenêtre, un corps pour le groupe

static func _fenetre(avant: Control, model: Dictionary) -> void:
	var cs := candidats(model)
	var largeur := 1700.0
	var hauteur := maxf(860.0, 150.0 + 112.0 * cs.size() + 40.0)
	var scene: Control = avant.find_child("MatchStage", true, false)
	if scene == null: scene = avant
	var declencheur := avant.find_child("MatchTestsPhysiques", true, false) as Control
	var fond := Fenetre.ouvrir(scene, FENETRE, "TESTS PHYSIQUES", "heart", largeur, hauteur, func(): if is_instance_valid(declencheur): declencheur.grab_focus())
	var calque := fond.get_parent() as Control
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var voile := calque.find_child(FENETRE + "Voile", false, false) as Control
	if voile != null: voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.position = ((scene.size - fond.size) / 2.0).floor()
	# Gauche : un corps face / dos pour tout le groupe, une pastille numérotée par zone touchée.
	var corps := D.rect(fond, Rect2(28, 92, 560, hauteur - 120), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	corps.name = FENETRE + "Corps"
	corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zones := {"F": Rect2(26, 40, 245, 600), "B": Rect2(289, 40, 245, 600)}
	for vue: String in zones:
		var s := Blessure.Silhouette.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.dessin = Blessure.texture(vue)
		corps.add_child(s)
		D.place(s, zones[vue])
	D.text(corps, 98, 676, "FACE", 18, Charte.IVOIRE_3, 700, 100, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(corps, 361, 676, "DOS", 18, Charte.IVOIRE_3, 700, 100, HORIZONTAL_ALIGNMENT_CENTER)
	var i := 0
	for c: Dictionary in cs:
		i += 1
		if str(c.type).is_empty(): continue
		for vue: String in zones:
			var pt := Blessure.point_zone(str(c.type), bool(c.droite), vue)
			if pt.x < 0: continue
			var z: Rect2 = zones[vue]
			# Le dessin est ajusté dans son cadre (même calcul que la silhouette).
			var t := Vector2(Blessure.texture(vue).get_size())
			var k := minf(z.size.x / t.x, z.size.y / t.y)
			var o := z.position + (z.size - t * k) / 2.0
			var centre := o + pt * t * k
			var rond := D.rect(corps, Rect2(centre.x - 19, centre.y - 19, 38, 38), RESULTATS[c.resultat][1], 99)
			rond.name = FENETRE + "Zone%d%s" % [i, vue]
			_numero(rond, i, Charte.ENCRE)
			var cc := c
			R.cliquable(rond, func(): _ouvrir_joueur(avant, scene, cc), FENETRE + "ZoneClic%d%s" % [i, vue], str(c.j.get("name", "")))
	# Droite : liste numérotée (numéro, visage, nom, motif, test, anneau des minutes).
	var x := 620.0
	var l := largeur - x - 36.0
	var y := 100.0
	i = 0
	for c: Dictionary in cs:
		i += 1
		var res: Array = RESULTATS[c.resultat]
		var ligne := Control.new()
		ligne.name = FENETRE + "Ligne%d" % i
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(ligne)
		D.place(ligne, Rect2(x, y, l, 104))
		var cc := c
		Panneaux._bouton(ligne, Rect2(0, 0, l, 104), func(): _ouvrir_joueur(avant, scene, cc), FENETRE + "Ouvrir%d" % i, str(c.j.get("name", "")))
		var num := D.rect(ligne, Rect2(4, 33, 38, 38), res[1] if not str(c.type).is_empty() else Charte.PANNEAU_3, 99)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_numero(num, i, Charte.ENCRE if not str(c.type).is_empty() else Charte.IVOIRE_2)
		Panneaux._portrait(ligne, c.j, Rect2(58, 12, 80, 80), Color.TRANSPARENT)
		D.text(ligne, 156, 46, str(c.j.get("name", "")), 25, Charte.IVOIRE, 700, 330)
		var raison: Array = RAISONS[c.raison]
		D.text(ligne, 156, 82, str(c.libelle), 19, raison[1], 600, 330)
		R.pastille(ligne, 520, 64, str(res[0]), res[1], res[2], FENETRE + "Test%d" % i, 21)
		var anneau := Anneau.new()
		anneau.name = FENETRE + "Minutes%d" % i
		anneau.part = float(c.minutes) / 80.0
		anneau.couleur = _couleur_minutes(c)
		anneau.texte = ("%d′" % int(c.minutes)) if int(c.minutes) > 0 else "0′"
		anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(anneau)
		D.place(anneau, Rect2(l - 250, 8, 88, 88))
		D.text(ligne, l - 150, 62, _mot_minutes(c), 22, _couleur_minutes(c), 700, 150)
		D.line(ligne, Vector2(0, 103), Vector2(l, 103), Charte.FILET, 1)
		y += 112.0

static func _numero(rond: Control, i: int, couleur: Color) -> void:
	var l := Label.new()
	l.text = str(i)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Charte.TITRE_GRAS)
	l.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
	l.add_theme_color_override("font_color", couleur)
	rond.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Anneau des minutes conseillées sur 80′ (part colorée, chiffre au centre).
class Anneau extends Control:
	var part := 0.0
	var couleur := Color.WHITE
	var texte := ""

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 6.0
		var e := maxf(4.0, r * 0.22)
		draw_arc(c, r, 0, TAU, 64, Charte.PANNEAU_3, e, true)
		if part > 0.0: draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(part, 0.0, 1.0), 64, couleur, e, true)
		var police: Font = Charte.TITRE_GRAS
		var taille := int(r * 0.75)
		draw_string(police, Vector2(0, c.y + taille * 0.36), texte, HORIZONTAL_ALIGNMENT_CENTER, size.x, taille, Charte.IVOIRE)
