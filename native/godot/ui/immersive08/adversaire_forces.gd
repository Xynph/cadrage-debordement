extends RefCounted
## Points forts / points faibles de l'adversaire (revue FM27, idée 29 ; choix de Léo du 23/11/2026 : option A).
## En tête de la sous-page « Rapport adverse » de la Préparation (rapport de l'idée 10 dessous, inchangé).
## Trois colonnes : points forts (icônes vertes), points faibles (icônes rouges), hommes clés + entraîneur et son style.
## Fort ou faible = comparé à la moyenne du championnat, sur les matchs joués (club-sheet.cjs `forces`) ; un titulaire
## habituel blessé ou suspendu reste signalé « Absent : X » dans les points faibles.
## Tout est cliquable : un point ouvre une petite fenêtre (eux contre la moyenne), un joueur ouvre sa fiche.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Link = preload("res://ui/entity_link.gd")
const Notes = preload("res://ui/notes_match.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

## Indicateurs du moteur : clé → [libellé fort, libellé faible, icône, unité (format du chiffre)].
const INDICATEURS := {
	"essais": ["Attaque prolifique", "Attaque stérile", "ball", "%s essais/match"],
	"encaisses": ["Défense hermétique", "Défense poreuse", "shield", "%s encaissés/match"],
	"touches": ["Touche solide", "Touche fragile", "target", "%s %% gagnées"],
	"melees": ["Mêlée dominante", "Mêlée fragile", "lock", "%s %% gagnées"],
	"penalites": ["Discipliné", "Indiscipliné", "flag", "%s pén./match"],
	"porte": ["Ballon porté", "", "people", "%s %% des essais"],
	"fin": ["Finit fort", "", "clock", "%s %% après 60′"],
	"loin": ["Contre-attaque", "", "arrow", "%s %% de +50 m"],
	"porteContre": ["", "Subit le ballon porté", "people", "%s %% des encaissés"],
	"finContre": ["", "Craque en fin de match", "clock", "%s %% après 60′"],
}
## Style de jeu de l'entraîneur (identité du club dans le moteur de match) : [libellé, couleur, icône].
const STYLES := {"conquete": ["Jeu au près", R.ORANGE, "people"], "large": ["Jeu au large", R.BLEU, "arrow"],
	"occupation": ["Jeu au pied", R.VIOLET, "ball"], "equilibre": ["Jeu varié", R.TURQUOISE, "renew"]}
const MAX_LIGNES := 5

static func _n(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0

static func _v(x: float) -> String:
	return ("%.1f" % x).replace(".", ",").trim_suffix(",0") if absf(x) >= 10.0 else ("%.1f" % x).replace(".", ",")

## Points relevés : {fort, icone, libelle, chiffre, moyenne, valeur, ligue, joueur}. Moteur d'abord (du plus net au
## moins net), puis les titulaires habituels absents (deux au plus) en fin de colonne des faibles.
static func points(donnees: Dictionary) -> Array:
	var out: Array = []
	var forces: Dictionary = donnees.get("forces") if donnees.get("forces") is Dictionary else {}
	for p: Variant in forces.get("points", []):
		if not p is Dictionary or not INDICATEURS.has(str(p.get("cle", ""))): continue
		var def: Array = INDICATEURS[str(p.cle)]
		var fort := bool(p.get("fort", false))
		var libelle := str(def[0] if fort else def[1])
		if libelle.is_empty(): continue
		var unite := str(def[3])
		out.append({"fort": fort, "icone": def[2], "libelle": libelle, "chiffre": unite % _v(_n(p.get("valeur"))),
			"moyenne": "moy. " + _v(_n(p.get("ligue"))) + (" %" if unite.begins_with("%s %%") else ""),
			"valeur": _n(p.get("valeur")), "ligue": _n(p.get("ligue")), "joueur": "", "cle": str(p.cle)})
	var absents: Array = []
	for j: Variant in donnees.get("squad", []):
		if j is Dictionary and int(_n(j.get("starts"))) >= 3 and (_n(j.get("injury")) > 0 or _n(j.get("suspension")) > 0):
			absents.append(j)
	absents.sort_custom(func(a: Dictionary, b: Dictionary): return int(_n(a.get("starts"))) > int(_n(b.get("starts"))))
	var place := mini(2, absents.size())
	var garde := MAX_LIGNES - place
	var gardes: Array = []
	var faibles := 0
	for p: Dictionary in out:
		if not p.fort:
			faibles += 1
			if faibles > garde: continue
		gardes.append(p)
	out = gardes
	for j: Dictionary in absents.slice(0, place):
		out.append({"fort": false, "icone": "heart" if _n(j.get("injury")) > 0 else "warning", "libelle": "Absent : %s" % str(j.get("name", "")).split(" ")[-1],
			"chiffre": "%s · %d tit." % [str(j.get("pos", "")), int(_n(j.get("starts")))], "moyenne": "", "joueur": str(j.get("id", "")), "nom": str(j.get("name", "")), "cle": "absent"})
	return out

## Hommes clés : [catégorie, icône, couleur, joueur, chiffre].
static func cles(donnees: Dictionary) -> Array:
	var squad: Array = donnees.get("squad", []).filter(func(j): return j is Dictionary)
	var out: Array = []
	var crit := [["Meilleure note", "rating", R.ORANGE, func(j): return _n(j.get("average")) if _n(j.get("matches")) >= 2 else -1.0, func(j): return Notes.texte_note(_n(j.get("average")))],
		["Meilleur marqueur", "ball", R.VERT, func(j): return _n(j.get("tries")), func(j): return "%d essais" % int(_n(j.get("tries")))],
		["Meilleur plaqueur", "shield", R.VIOLET, func(j): return _n(j.get("tackles")), func(j): return "%d plaq." % int(_n(j.get("tackles")))]]
	for c: Array in crit:
		var best: Dictionary = {}
		var bv := 0.0
		for j: Dictionary in squad:
			var v: float = c[3].call(j)
			if v > bv:
				bv = v
				best = j
		if not best.is_empty(): out.append([c[0], c[1], c[2], best, c[4].call(best)])
	return out

# ---- Briques ---------------------------------------------------------------------------------------------------------

static func _portrait(parent: Control, zone: Rect2, joueur: Dictionary, bord: Color) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, bord)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var im: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, zone.size.y * .04, zone.size.x, zone.size.y * 1.12))

static func _rond_icone(parent: Control, zone: Rect2, icone: String, couleur: Color) -> void:
	var rond := D.rect(parent, zone, Color(couleur, .22), zone.size.x / 2.0, couleur)
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cote := zone.size.x * .55
	var ic := C.icon(icone, C.px(cote), couleur)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rond.add_child(ic)
	D.place(ic, Rect2((zone.size.x - cote) / 2.0, (zone.size.y - cote) / 2.0, cote, cote))

## Clic sur un point : un absent ouvre sa fiche ; sinon petite fenêtre (le point en grand, eux contre la moyenne).
static func _fenetre_point(page, p: Dictionary, ligue: String) -> void:
	var couleur: Color = R.VERT if p.fort else R.ROUGE
	var fond := Fenetre.ouvrir(page, "AdversaireForceFenetre", ("POINT FORT" if p.fort else "POINT FAIBLE"), "", 760, 400)
	_rond_icone(fond, Rect2(40, 100, 140, 140), str(p.icone), couleur)
	var titre := D.text(fond, 210, 152, str(p.libelle).to_upper(), 34, Charte.IVOIRE, 800, 510)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(fond, 210, 200, str(p.chiffre), 28, couleur, 800, 510)
	# Barres : eux (couleur du point) et la moyenne du championnat (gris), à la même échelle.
	var maxi_v := maxf(0.001, maxf(_n(p.get("valeur")), _n(p.get("ligue"))))
	var lignes := [[G.club_name(page._opponent()) if page.has_method("_opponent") and not page._opponent().is_empty() else "Eux",_n(p.get("valeur")), couleur, "AdversaireForceBarreEux"],
		[ligue if not ligue.is_empty() else "Moyenne", _n(p.get("ligue")), Charte.IVOIRE_2, "AdversaireForceBarreLigue"]]
	for i in lignes.size():
		var l: Array = lignes[i]
		var y := 272.0 + i * 54.0
		D.text(fond, 40, y + 22, str(l[0]), 18, Charte.IVOIRE_2, 700, 230)
		var rail := D.rect(fond, Rect2(280, y + 6, 340, 20), Charte.PANNEAU_3, Charte.RAYON_PILULE)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var plein := D.rect(fond, Rect2(280, y + 6, maxf(20.0, 340.0 * float(l[1]) / maxi_v), 20), l[2], Charte.RAYON_PILULE)
		plein.name = str(l[3])
		plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chiffre := D.text(fond, 720, y + 26, _v(float(l[1])), 26, l[2], 800, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		chiffre.add_theme_font_override("font", Charte.TITRE_FICHE)

## Clic sur le style de l'entraîneur : petite fenêtre, les quatre styles, le sien allumé.
static func _fenetre_style(page, coach: String, style: String) -> void:
	var fond := Fenetre.ouvrir(page, "AdversaireForceFenetre", coach.to_upper() if not coach.is_empty() else "ENTRAÎNEUR", "people", 760, 330)
	var x := 40.0
	for cle: String in STYLES.keys():
		var def: Array = STYLES[cle]
		var allume := cle == style
		var couleur: Color = def[1] if allume else Charte.IVOIRE_3
		var carte := D.rect(fond, Rect2(x, 100, 160, 190), Color(couleur, .16 if allume else .06), Charte.RAYON_CARTE, couleur if allume else Color.TRANSPARENT)
		carte.name = "AdversaireStyle_" + cle
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rond_icone(carte, Rect2(40, 24, 80, 80), str(def[2]), couleur)
		D.text(carte, 80, 150, str(def[0]), 19, Charte.IVOIRE if allume else Charte.IVOIRE_3, 800, 150, HORIZONTAL_ALIGNMENT_CENTER)
		x += 172.0

# ---- Bloc ------------------------------------------------------------------------------------------------------------

## Dessine le bloc en haut de `section` (y = 66) ; rend sa hauteur.
static func construire(page, section: Control, donnees: Dictionary) -> float:
	var pts := points(donnees)
	var cl := cles(donnees)
	var forces: Dictionary = donnees.get("forces") if donnees.get("forces") is Dictionary else {}
	var ligue := str(forces.get("ligue")) if forces.get("ligue") is String else ""
	var passee := str(forces.get("saison", "")) == "passée"
	var club_id := int(donnees.get("id", -1))
	var H := 360.0
	var y0 := 66.0
	var lw := 760.0
	for k in 2:
		var fort := k == 0
		var couleur: Color = R.VERT if fort else R.ROUGE
		var liste := pts.filter(func(p: Dictionary): return bool(p.fort) == fort)
		var panneau: Panel = page._panneau(section, Rect2(k * (lw + 16), y0, lw, H), "Points forts" if fort else "Points faibles", "AdversaireForces%s" % ("Forts" if fort else "Faibles"), "saison passée" if passee else "")
		var marque := D.text(panneau, 300, 42, "▲" if fort else "▼", 28, couleur, 800, 40)
		marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var y := 66.0
		var i := 0
		for p: Dictionary in liste.slice(0, MAX_LIGNES):
			var ligne := D.rect(panneau, Rect2(16, y, lw - 32, 52), Charte.PANNEAU_2 if i % 2 == 0 else Color.TRANSPARENT, 8)
			ligne.name = "AdversairePoint%s%d" % ["Fort" if fort else "Faible", i]
			ligne.mouse_filter = Control.MOUSE_FILTER_PASS
			var pc: Dictionary = p
			if not str(p.joueur).is_empty():
				var zone: Button = page._zone_joueur(ligne, Rect2(0, 0, lw - 32, 52), {"id": p.joueur, "name": p.get("nom", "")}, club_id, ligne.name + "Lien")
				page._survol_ligne(zone)
			else:
				page._survol_ligne(page._zone(ligne, Rect2(0, 0, lw - 32, 52), func(): _fenetre_point(page, pc, ligue), ligne.name + "Lien", str(p.libelle)))
			_rond_icone(ligne, Rect2(10, 8, 36, 36), str(p.icone), couleur)
			D.text(ligne, 62, 34, str(p.libelle), 22, Charte.IVOIRE, 800, 330)
			var a_moyenne := not str(p.moyenne).is_empty()
			D.text(ligne, lw - (150.0 if a_moyenne else 48.0), 34, str(p.chiffre), 21, couleur, 800, 300, HORIZONTAL_ALIGNMENT_RIGHT)
			if a_moyenne: D.text(ligne, lw - 48, 33, str(p.moyenne), 16, Charte.IVOIRE_2, 700, 96, HORIZONTAL_ALIGNMENT_RIGHT)
			y += 56.0
			i += 1
		if liste.is_empty(): D.text(panneau, 32, 110, "—", 26, Charte.IVOIRE_2, 800, 60)
	# Hommes clés + entraîneur et son style.
	var x := 2 * (lw + 16)
	var w := 2248.0 - x
	var cles_p: Panel = page._panneau(section, Rect2(x, y0, w, H), "Hommes clés", "AdversaireCles")
	var y := 62.0
	var i := 0
	for c: Array in cl:
		var j: Dictionary = c[3]
		var ligne := D.rect(cles_p, Rect2(14, y, w - 28, 68), Charte.PANNEAU_2, 8)
		ligne.name = "AdversaireCle%d" % i
		ligne.mouse_filter = Control.MOUSE_FILTER_PASS
		page._survol_ligne(page._zone_joueur(ligne, Rect2(0, 0, w - 28, 68), j, club_id, "AdversaireCleLien%d" % i))
		_portrait(ligne, Rect2(8, 6, 56, 56), j, c[2])
		var ic := C.icon(str(c[1]), C.px(16), c[2])
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(ic)
		D.place(ic, Rect2(76, 12, 16, 16))
		D.text(ligne, 98, 27, str(c[0]).to_upper(), 14, c[2], 800, w - 260)
		var nom := D.text(ligne, 76, 56, str(j.get("name", "")), 19, Charte.IVOIRE, 800, w - 330)
		nom.name = "AdversaireCleNom%d" % i
		if _n(j.get("injury")) > 0 or _n(j.get("suspension")) > 0:
			R.pastille(ligne, w - 290, 52, "Absent", R.ROUGE, "heart" if _n(j.get("injury")) > 0 else "warning", "AdversaireCleAbsent%d" % i, 15)
		D.text(ligne, w - 44, 46, str(c[4]), 22, c[2], 800, 150, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 74.0
		i += 1
	var coach := str(donnees.get("coach")) if donnees.get("coach") is String else "—"
	var style := str(donnees.get("coachStyle", "")) if donnees.get("coachStyle") is String else ""
	var cadre := D.rect(cles_p, Rect2(14, H - 66, w - 28, 54), Color(R.BLEU, .14), 8, Color(R.BLEU, .5))
	cadre.name = "AdversaireCoach"
	var ic2 := C.icon("people", C.px(20), R.BLEU)
	ic2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(ic2)
	D.place(ic2, Rect2(12, 17, 20, 20))
	Link.name_link(page.app, cadre, Rect2(38, 8, (w - 28) * .5, 38), "staff", str(donnees.get("coachId", "")) if donnees.get("coachId") != null else "", coach, 19, Charte.IVOIRE, "AdversaireCoachNom")
	if STYLES.has(style):
		var def: Array = STYLES[style]
		var texte := str(def[0])
		var px := (w - 28) - 14.0 - (R.largeur(texte, 18) + 52.0)
		var pa := R.pastille(cadre, px, 35, texte, def[1], str(def[2]), "AdversaireCoachStyle", 18)
		R.cliquable(pa, func(): _fenetre_style(page, coach, style), "AdversaireCoachStyleLien", texte)
	return H + 14.0
