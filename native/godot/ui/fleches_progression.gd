extends RefCounted
## Flèches de progression façon jeu de gestion (planche du 23/11/2026, à côté de chaque qualité de la fiche, du niveau
## dans l'Effectif et des jeunes du Centre). Trois crans selon l'évolution sur environ 4 semaines, lue dans le relevé
## mensuel du moteur (native/engine/releve-qualites.cjs, au dixième) : léger (+0,1 à +0,3), net (+0,4 à +0,9), point
## gagné (le chiffre affiché a monté) ; même chose en baisse (orange, puis rouge). Jamais de dixième à l'écran.
## Survol du chiffre : bulle avec la courbe des 12 derniers mois (bulle_survol.gd, sans clic).
## Deux variantes visuelles à trancher par Léo (CD_VARIANTE_VISUELLE=A|B, A par défaut) :
##   A « triangle » : un triangle à droite du chiffre (pâle, vert, vert vif) ; point gagné = chiffre surligné + « +1 »
##   devant lui.
##   B « chevrons » : 1, 2 ou 3 chevrons empilés à gauche du chiffre ; point gagné = chiffre en pastille pleine + « +1 ».
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Bulle = preload("res://ui/bulle_survol.gd")
const Courbe = preload("res://ui/mini_courbe_survol.gd")

## Hausse : pâle, vert (gain de la charte), vert vif. Baisse : orange pâle, orange (intensif), rouge (perte).
const VIF := Color("4be08a")
const BAISSE := Charte.INTENSIF
const BAISSE_VIVE := Charte.PERTE

static var _cache: Dictionary = {}

## Chargé à l'usage : progression_fiche.gd précharge le Centre, qui précharge ce fichier.
static func _p() -> Script:
	return load("res://ui/immersive08/progression_fiche.gd")

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

static func teinte(cran: int) -> Color:
	match cran:
		3: return VIF
		2: return Charte.GAIN
		1: return Color(Charte.GAIN, 0.5)
		-1: return Color(BAISSE, 0.55)
		-2: return BAISSE
		-3: return BAISSE_VIVE
	return Color.TRANSPARENT

## Place du relevé la plus proche de « il y a 4 semaines » (relevé du mois en cours s'il a au moins 3 semaines, sinon
## celui du mois d'avant) dans la série de 13 places de progression_fiche.gd ; -1 sans relevé.
static func _place_reference(app: Control, serie: Array) -> int:
	var jour := 1
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	if today.length() >= 10: jour = today.substr(8, 2).to_int()
	for k: int in ([11, 10] if jour >= 22 else [10, 11]):
		if serie.size() > k and serie[k] != null: return k
	return -1

## Cran de -3 à 3 entre la valeur de référence et celle d'aujourd'hui (dixièmes du moteur, jamais affichés) :
## ±0,1 à 0,3 léger, ±0,4 à 0,9 net, ±1 ou plus point gagné / perdu.
static func cran(avant: Variant, maintenant: float) -> int:
	if avant == null: return 0
	var dixiemes := roundi((maintenant - float(avant)) * 10.0)
	if absi(dixiemes) >= 10: return 3 * signi(dixiemes)
	if absi(dixiemes) >= 4: return 2 * signi(dixiemes)
	if absi(dixiemes) >= 1: return signi(dixiemes)
	return 0

## {qualites: {clé: {cran, serie, libelle}}, niveau: {cran, serie}} du joueur ; {} sans relevé.
static func donnees(app: Control, player: Dictionary) -> Dictionary:
	if str(player.get("releve", "")).is_empty() or _p().valeurs(player).is_empty(): return {}
	var cle := "%s|%s|%s" % [player.get("id", ""), player.get("releve", ""), app.model.get("meta", {}).get("calendarToday", "")]
	if _cache.has(cle): return _cache[cle]
	if _cache.size() > 400: _cache.clear()
	var qualites := {}
	var place := -1
	var total := 0.0
	var compte := 0
	for q: Dictionary in _p().qualites(app, player):
		var serie: Array = q.serie
		if place < 0: place = _place_reference(app, serie)
		var avant: Variant = serie[place] if place >= 0 else null
		qualites[q.cle] = {"cran": cran(avant, float(q.valeur)), "serie": serie, "libelle": q.libelle}
		if avant != null:
			total += float(q.valeur) - float(avant)
			compte += 1
	# Niveau : note entière du moteur ; point gagné ou perdu si elle a bougé, sinon la dérive moyenne des 36 qualités.
	var niveau: Array = _p().niveau(app, player)
	var cran_niveau := 0
	var ref: Variant = niveau[place] if place >= 0 else null
	if ref != null:
		var points := roundi(float(player.get("rating", 0))) - roundi(float(ref))
		cran_niveau = 3 * signi(points) if points != 0 else cran(0.0, total / maxf(1.0, compte))
	var sortie := {"qualites": qualites, "niveau": {"cran": cran_niveau, "serie": niveau}}
	_cache[cle] = sortie
	return sortie

## Pose la marque du `cran` contre le chiffre `label` (déjà placé dans `parent`) et branche la courbe 12 mois au survol.
## `serie` : 13 places (12 mois + aujourd'hui), `titre` : nom de la qualité ou « Niveau ».
static func marquer(app: Control, label: Label, cran_: int, serie: Array, titre: String, id: String) -> void:
	if label == null or not is_instance_valid(label): return
	var parent := label.get_parent() as Control
	var police: Font = label.get_theme_font("font")
	var taille := label.get_theme_font_size("font_size")
	var largeur := police.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var gauche := label.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT: gauche = label.position.x + label.size.x - largeur
		HORIZONTAL_ALIGNMENT_CENTER: gauche = label.position.x + (label.size.x - largeur) / 2.0
	var haut := label.position.y + police.get_ascent(taille) * 0.18
	var hauteur := police.get_ascent(taille) * 0.86
	var droite := gauche + largeur
	var s := float(taille) * 0.6
	var zone := Rect2(gauche, haut, largeur, hauteur)
	if cran_ != 0:
		if variante() == "A": zone = _triangle(parent, label, cran_, gauche, droite, haut, hauteur, s, id)
		else: zone = _chevrons(parent, label, cran_, gauche, droite, haut, hauteur, s, id)
	_survol(app, parent, zone, serie, titre, cran_, id)

## Variante A : triangle à droite ; point gagné = bande surlignée derrière le chiffre + « +1 » devant lui.
static func _triangle(parent: Control, label: Label, n: int, gauche: float, droite: float, haut: float, hauteur: float, s: float, id: String) -> Rect2:
	var cote := s * (0.82 if absi(n) == 1 else 1.0)
	var f := Fleche.new()
	f.name = "Fleche_" + id
	f.forme = "triangle"
	f.cran = n
	parent.add_child(f)
	f.position = Vector2(droite + s * 0.3, haut + (hauteur - cote) / 2.0)
	f.size = Vector2(cote, cote)
	var fin := f.position.x + cote
	if absi(n) == 3:
		var bande := Panel.new()
		bande.name = "FlecheSurligne_" + id
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(teinte(n), 0.26)
		style.border_color = teinte(n)
		style.border_width_bottom = maxi(2, C.px(3))
		style.set_corner_radius_all(maxi(2, C.px(4)))
		bande.add_theme_stylebox_override("panel", style)
		parent.add_child(bande)
		parent.move_child(bande, label.get_index())
		bande.position = Vector2(gauche - s * 0.3, haut - hauteur * 0.1)
		bande.size = Vector2(droite - gauche + s * 0.6, hauteur * 1.25)
		var un := _petit(parent, "+1" if n > 0 else "−1", teinte(n), s * 1.05, "FlecheUn_" + id)
		un.position = Vector2(bande.position.x - un.size.x - s * 0.15, haut + (hauteur - un.size.y) / 2.0)
		gauche = un.position.x
	return Rect2(gauche, haut, fin - gauche, hauteur)

## Variante B : chevrons empilés à gauche (1, 2 ou 3) ; point gagné = chiffre en pastille pleine + « +1 » en exposant.
static func _chevrons(parent: Control, label: Label, n: int, gauche: float, droite: float, haut: float, hauteur: float, s: float, id: String) -> Rect2:
	var f := Fleche.new()
	f.name = "Fleche_" + id
	f.forme = "chevrons"
	f.cran = n
	parent.add_child(f)
	var l := s * 1.15
	f.size = Vector2(l, hauteur * 1.1)
	var marge := s * (0.55 if absi(n) == 3 else 0.3)
	f.position = Vector2(gauche - marge - l, haut - hauteur * 0.05)
	var fin := droite
	if absi(n) == 3:
		var pastille := Panel.new()
		pastille.name = "FlechePastille_" + id
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = teinte(n)
		style.set_corner_radius_all(maxi(3, C.px(7)))
		pastille.add_theme_stylebox_override("panel", style)
		parent.add_child(pastille)
		parent.move_child(pastille, label.get_index())
		pastille.position = Vector2(gauche - s * 0.32, haut - hauteur * 0.14)
		pastille.size = Vector2(droite - gauche + s * 0.64, hauteur * 1.3)
		label.add_theme_color_override("font_color", Charte.ENCRE)
		var un := _petit(parent, "+1" if n > 0 else "−1", teinte(n), s * 1.0, "FlecheUn_" + id)
		un.position = Vector2(pastille.position.x + pastille.size.x + s * 0.05, pastille.position.y - un.size.y * 0.35)
		fin = un.position.x + un.size.x
	return Rect2(f.position.x, haut, fin - f.position.x, hauteur)

static func _petit(parent: Control, texte: String, couleur: Color, taille: float, nom: String) -> Label:
	var l := Label.new()
	l.name = nom
	l.text = texte
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", C.font(800))
	l.add_theme_font_size_override("font_size", maxi(12, roundi(taille)))
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)
	l.size = C.font(800).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, roundi(taille))) + Vector2(2, 0)
	return l

## Zone de survol posée sur le chiffre et sa marque : bulle « courbe 12 mois » (au moins 2 relevés).
static func _survol(app: Control, parent: Control, zone: Rect2, serie: Array, titre: String, n: int, id: String) -> void:
	var points := 0
	for v: Variant in serie: if v != null: points += 1
	if points < 2: return
	var cible := Control.new()
	cible.name = "FlecheSurvol_" + id
	cible.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(cible)
	cible.position = zone.position - Vector2(4, 4)
	cible.size = zone.size + Vector2(8, 8)
	Bulle.lier(cible, "progression:" + id, func(): return courbe(app, serie, titre, n))

## Bulle : titre, chiffre d'aujourd'hui (entier), marque du cran, écart entier sur 12 mois, courbe, mois extrêmes.
static func courbe(app: Control, serie: Array, titre: String, n: int) -> Control:
	var largeur := 440.0
	var hauteur := 250.0
	var bulle := Panel.new()
	bulle.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_CARTE, 0)))
	bulle.custom_minimum_size = Vector2(largeur, hauteur) * C.density
	bulle.size = bulle.custom_minimum_size
	var valeurs: Array[float] = []
	var premiere := -1
	for k in serie.size():
		if serie[k] == null: continue
		if premiere < 0: premiere = k
		valeurs.append(float(serie[k]))
	var aujourdhui := roundi(valeurs[-1])
	var ecart := aujourdhui - roundi(valeurs[0])
	D.text(bulle, 22, 34, titre.to_upper(), 15, Charte.IVOIRE_3, 700, 260)
	D.text(bulle, largeur - 22, 34, "12 MOIS", 14, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	var chiffre := D.text(bulle, 22, 80, str(aujourdhui), 40, Charte.couleur_attribut(aujourdhui), 800, 90)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA)
	chiffre.name = "FlecheCourbeValeur"
	if n != 0:
		var marque := Fleche.new()
		marque.forme = "triangle" if variante() == "A" else "chevrons"
		marque.cran = n
		bulle.add_child(marque)
		D.place(marque, Rect2(98, 48, 24, 30))
	var hausse := ecart >= 0
	var pastille := D.rect(bulle, Rect2(largeur - 150, 50, 128, 34), Color(Charte.GAIN if hausse else Charte.PERTE, 0.16), Charte.RAYON_PILULE)
	pastille.name = "FlecheCourbeEcart"
	D.text(pastille, 64, 24, ("+%d" % ecart) if ecart > 0 else ("−%d" % -ecart) if ecart < 0 else "=", 19, Charte.GAIN if hausse else Charte.PERTE, 800, 120, HORIZONTAL_ALIGNMENT_CENTER)
	var trace := Courbe.Trace.new()
	trace.name = "FlecheCourbeTrace"
	trace.teinte = Charte.GAIN if hausse else Charte.PERTE
	trace.valeurs = valeurs
	bulle.add_child(trace)
	D.place(trace, Rect2(22, 98, largeur - 44, 112))
	var etiquettes: Array = _p().etiquettes(_p().mois_courant(app, {}))
	D.text(bulle, 22, 238, etiquettes[maxi(0, premiere)], 14, Charte.IVOIRE_3, 600, 120)
	D.text(bulle, largeur - 22, 238, "auj.", 14, Charte.IVOIRE_3, 600, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	return bulle

## Marque dessinée (aucune police du jeu n'a ▲ ▼) : triangle plein ou chevrons empilés, pointe en haut pour la hausse.
class Fleche extends Control:
	const F = preload("res://ui/fleches_progression.gd")
	var forme := "triangle"
	var cran := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if cran == 0 or size.x < 1: return
		var couleur := F.teinte(cran)
		var w := size.x
		var h := size.y
		var monte := cran > 0
		if forme == "triangle":
			var t := minf(w, h)
			var y0 := (h - t * 0.86) / 2.0
			var y1 := y0 + t * 0.86
			var pts := PackedVector2Array([Vector2(w / 2.0, y0), Vector2(w, y1), Vector2(0, y1)]) if monte else PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w / 2.0, y1)])
			draw_colored_polygon(pts, couleur)
			return
		var nombre := absi(cran)
		var pas := h / 3.0
		var epaisseur := maxf(2.5, w * 0.24)
		var haut_c := minf(w * 0.5, pas * 0.95)
		for i in nombre:
			# Pile depuis le bas (hausse) ou le haut (baisse) : un chevron par cran.
			var centre := h - pas * (i + 0.5) if monte else pas * (i + 0.5)
			var a := centre + haut_c / 2.0 if monte else centre - haut_c / 2.0
			var b := centre - haut_c / 2.0 if monte else centre + haut_c / 2.0
			draw_polyline(PackedVector2Array([Vector2(epaisseur / 2.0, a), Vector2(w / 2.0, b), Vector2(w - epaisseur / 2.0, a)]), couleur, epaisseur, true)
