extends RefCounted
## Page « Dans le monde » (revue FM27, idée 30 ; choix A de Léo du 23/11/2026 : le journal) : onglet de Compétitions.
## Bandeau des affiches du jour, la une (grande image, titre, score), deux cartes, la carte « Dernière minute » (gros
## transfert entre clubs adverses), « Plus d'actus », puis tous les championnats en vignettes de couleur fixe.
## Chaque article est signé d'un journaliste d'un média du jeu (nom et média), au ton de son style ; image de la banque des
## actus selon son thème (dans_le_monde_actus.gd), écussons des clubs, portrait du joueur concerné.
## Clics : affiche → la rencontre ; article → sa petite fenêtre (image, titre, signature, chiffres) dont les tuiles mènent au
## club, à la rencontre ou au classement ; vignette → le classement de la ligue. Aucun bouton de confirmation.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const A = preload("res://ui/immersive08/dans_le_monde_actus.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")

const W := 2248.0
const GAUCHE := 1380.0

static func _n(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0

static func _club(page, id: Variant) -> Dictionary:
	return page._target_club(page.app, str(roundi(_n(id))) if id is float else str(id))

static func _couleur_ligue(ligues: Array, id: String) -> Color:
	for l: Dictionary in ligues:
		if l.id == id: return l.couleur
	return Charte.IVOIRE_2

static func _nom_ligue(ligues: Array, id: String) -> String:
	for l: Dictionary in ligues:
		if l.id == id: return l.nom
	return id

# ---- Briques -------------------------------------------------------------------------------------------------------

## Image d'actu dans un cadre arrondi ; `manquantes` reçoit l'identifiant si l'image ne se charge pas (contrôlé par la suite).
static func _image(parent: Control, id: String, zone: Rect2, rayon: int = 12) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, rayon)
	cadre.name = "Image_" + id.validate_node_name()
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = A.texture(id)
	cadre.set_meta("actu_image", id)
	cadre.set_meta("actu_image_ok", tex != null)
	if tex == null: return
	var im := TextureRect.new()
	im.texture = tex
	im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, 0, zone.size.x, zone.size.y))

static func _crest(parent: Control, club: Dictionary, zone: Rect2) -> void:
	var cr := G.crest(club, C.px(zone.size.x))
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	D.place(cr, zone)

static func _portrait(parent: Control, personne: Dictionary, zone: Rect2, bord: Color) -> void:
	var fond := D.rect(parent, zone, Charte.PANNEAU_3, int(zone.size.x / 2.0), bord)
	fond.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := G.portrait(A.graine(str(personne.get("id", ""))) % 32, C.px(zone.size.x), personne)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(p)
	D.place(p, Rect2(0, 0, zone.size.x, zone.size.y))

static func _survol(ligne: Panel) -> void:
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := (ligne.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var base := style.bg_color
	ligne.add_theme_stylebox_override("panel", style)
	ligne.mouse_entered.connect(func(): style.bg_color = Charte.SELECTION)
	ligne.mouse_exited.connect(func(): style.bg_color = base)

static func _titre(parent: Control, x: float, y: float, texte: String, couleur: Color = Charte.IVOIRE) -> void:
	var t := D.text(parent, x, y, texte, 26, couleur, 800, 900)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)

static func _pastille_ligue(parent: Control, x: float, baseline: float, ligues: Array, lid: String, taille: int = 15) -> Panel:
	return R.pastille(parent, x, baseline, _nom_ligue(ligues, lid), _couleur_ligue(ligues, lid), "trophy", "", taille)

## Signature : nom du journaliste (ivoire) puis le média (couleur de la ligue).
static func _signature(parent: Control, x: float, baseline: float, jn: Dictionary, couleur: Color, taille: int, largeur: float) -> void:
	if jn.is_empty(): return
	var nom := "Par " + str(jn.get("name", ""))
	var w := minf(R.largeur(nom, taille, 800) + 4.0, largeur * .55)
	D.text(parent, x, baseline, nom, taille, Charte.IVOIRE, 800, w).name = "Signature"
	D.text(parent, x + w + 10.0, baseline, "· " + str(jn.get("outlet", "")), taille, couleur, 700, maxf(40.0, largeur - w - 10.0)).name = "Media"

static func _score_txt(r: Dictionary) -> String:
	return "%d – %d" % [int(_n(r.score[0])), int(_n(r.score[1]))] if not r.is_empty() and r.get("score") is Array else ""

static func _pastilles(parent: Control, x: float, baseline: float, a: Dictionary, couleur: Color, taille: int, largeur_max: float) -> void:
	var xx := x
	for p: Variant in a.get("pastilles", []):
		var w := 24.0 + R.largeur(str(p[0]), taille) + (taille + 9.0 if str(p[1]) != "" else 0.0)
		if xx + w > x + largeur_max: break
		R.pastille(parent, xx, baseline, str(p[0]), couleur, str(p[1]), "", taille)
		xx += w + 10.0

static func _cliquable(cible: Control, action: Callable, nom: String, aide: String) -> void:
	R.cliquable(cible, action, nom, aide).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _ouvrir_cible(page, cible: Dictionary) -> void:
	var kind := str(cible.get("kind", ""))
	var id := str(cible.get("id", ""))
	if kind.is_empty() or id.is_empty(): return
	page.open_target(page.app, kind, id)

# ---- Bandeau des affiches ------------------------------------------------------------------------------------------

static func _bandeau(page, y: float, ligues: Array) -> float:
	var res := A.affiches(page.app.model)
	_titre(page, 0, y + 30, "AFFICHES DU JOUR")
	var n := mini(res.size(), 10)
	var tw := (W - 9 * 10.0) / 10.0
	for i in n:
		var r: Dictionary = res[i]
		var lid := str(r.get("leagueId", r.get("competitionId", "")))
		var col := _couleur_ligue(ligues, lid)
		var tuile := D.rect(page, Rect2(i * (tw + 10), y + 48, tw, 104), Charte.PANNEAU, 10)
		tuile.name = "MondeAffiche%d" % i
		_survol(tuile)
		D.rect(tuile, Rect2(0, 0, tw, 6), col, 3)
		for k in 2:
			var club := _club(page, r.pair[k])
			_crest(tuile, club, Rect2(12, 18 + k * 40, 28, 28))
			var gagne := _n(r.score[k]) > _n(r.score[1 - k])
			D.text(tuile, 48, 40 + k * 40, G.club_abbr(club), 19, Charte.IVOIRE if gagne else Charte.IVOIRE_2, 800, tw - 110)
			D.text(tuile, tw - 14, 40 + k * 40, str(int(_n(r.score[k]))), 22, col if gagne else Charte.IVOIRE_2, 800, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		var fid := str(r.get("fixtureId", ""))
		_cliquable(tuile, func(): page.open_target(page.app, "fixture", fid), "MondeAfficheLien%d" % i, "%s · %s" % [_nom_ligue(ligues, lid), _score_txt(r)])
	if n == 0: D.text(page, 0, y + 100, "—", 24, Charte.IVOIRE_2, 800, 40)
	return y + 170.0

# ---- Page ----------------------------------------------------------------------------------------------------------

static func construire(page) -> float:
	var ligues := A.ligues(page.app.model)
	var y := _bandeau(page, 150.0, ligues)
	var journal := A.page(page.app.model)
	page.set_meta("dans_le_monde", journal)
	_une(page, y, ligues, journal.une)
	_cartes(page, y + 494, ligues, journal.cartes)
	var yy := y + 48.0
	_titre(page, GAUCHE + 24, y + 30, "DERNIÈRE MINUTE" if not journal.derniere.is_empty() else "PLUS D'ACTUS", R.ROUGE if not journal.derniere.is_empty() else Charte.IVOIRE)
	if not journal.derniere.is_empty():
		yy = _derniere_minute(page, yy, ligues, journal.derniere)
		_titre(page, GAUCHE + 24, yy + 34, "PLUS D'ACTUS")
		yy += 52.0
	_liste(page, yy, y + 794.0, ligues, journal.liste)
	return _championnats(page, y + 830.0, ligues)

# ---- La une et les cartes ------------------------------------------------------------------------------------------

static func _une(page, y: float, ligues: Array, u: Dictionary) -> void:
	_titre(page, 0, y + 30, "À LA UNE")
	if u.is_empty(): return
	var col := _couleur_ligue(ligues, str(u.ligue))
	var une := D.rect(page, Rect2(0, y + 48, GAUCHE, 430), Charte.PANNEAU, Charte.RAYON_CARTE)
	une.name = "MondeUne"
	_survol(une)
	_image(une, str(u.image), Rect2(0, 0, 640, 430), Charte.RAYON_CARTE)
	D.rect(une, Rect2(0, 0, 10, 430), col, 4)
	_pastille_ligue(une, 676, 44, ligues, str(u.ligue), 17)
	var titre := D.text(une, 676, 150, str(u.titre).to_upper(), 46, Charte.IVOIRE, 800, GAUCHE - 710)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.fit_title(titre, GAUCHE - 710, 130, 2, 26)
	_signature(une, 676, 196, u.journaliste, col, 18, GAUCHE - 710)
	_acteurs(page, une, Rect2(676, 222, GAUCHE - 710, 120), u, col, 64)
	_pastilles(une, 676, 392, u, col, 17, GAUCHE - 710)
	_cliquable(une, func(): article(page, u, ligues), "MondeUneLien", str(u.titre))

## Écussons, noms et score d'un résultat ; portrait et écussons d'un transfert ou d'une blessure ; écusson sinon.
static func _acteurs(page, parent: Control, zone: Rect2, a: Dictionary, col: Color, cote: float) -> void:
	var r: Dictionary = a.get("resultat", {})
	var clubs: Array = a.get("clubs", [])
	var personne: Dictionary = a.get("personne", {})
	if not personne.is_empty():
		_portrait(parent, personne, Rect2(zone.position.x, zone.position.y, cote + 30, cote + 30), col)
		var x := zone.position.x + cote + 50
		D.text(parent, x, zone.position.y + 34, str(personne.get("name", "")), 24, Charte.IVOIRE, 800, zone.size.x - cote - 60)
		D.text(parent, x, zone.position.y + 62, str(personne.get("pos", "")), 17, Charte.IVOIRE_2, 700, 300)
		var tr: Dictionary = a.get("transfert", {})
		var y0 := zone.position.y + 74
		if not tr.is_empty():
			var acheteur := _club(page, tr.get("acheteurId"))
			_crest(parent, _club(page, tr.get("vendeurId")), Rect2(x, y0, 40, 40))
			D.text(parent, x + 50, y0 + 30, "→", 26, col, 800, 34)
			_crest(parent, acheteur, Rect2(x + 86, y0, 40, 40))
			D.text(parent, x + 136, y0 + 28, G.club_name(acheteur), 19, Charte.IVOIRE_2, 800, zone.size.x - cote - 190)
		elif not clubs.is_empty():
			var club := _club(page, clubs[0])
			_crest(parent, club, Rect2(x, y0, 40, 40))
			D.text(parent, x + 50, y0 + 28, G.club_name(club), 19, Charte.IVOIRE_2, 800, zone.size.x - cote - 110)
		return
	if not r.is_empty():
		var pair: Array = r.pair
		# Les deux clubs côte à côte, le score en grand dessous (jamais hors de la carte).
		var demi := zone.size.x / 2.0
		for k in 2:
			var club := _club(page, pair[k])
			_crest(parent, club, Rect2(zone.position.x + k * demi, zone.position.y, cote * .75, cote * .75))
			D.text(parent, zone.position.x + k * demi + cote * .75 + 12, zone.position.y + cote * .375 + 8, G.club_name(club), 20, Charte.IVOIRE_2, 800, demi - cote * .75 - 24)
		var sc := D.text(parent, zone.position.x, zone.position.y + cote * .75 + 62, _score_txt(r), int(cote * .85), col, 800, zone.size.x)
		sc.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		return
	for k in mini(2, clubs.size()):
		var club := _club(page, clubs[k])
		_crest(parent, club, Rect2(zone.position.x + k * 330, zone.position.y + 6, cote, cote))
		D.text(parent, zone.position.x + k * 330 + cote + 12, zone.position.y + cote / 2.0 + 12, G.club_name(club), 20, Charte.IVOIRE_2, 800, 220)

static func _cartes(page, y: float, ligues: Array, cartes: Array) -> void:
	var cw := (GAUCHE - 16) / 2.0
	for k in mini(2, cartes.size()):
		var a: Dictionary = cartes[k]
		var col := _couleur_ligue(ligues, str(a.ligue))
		var carte := D.rect(page, Rect2(k * (cw + 16), y, cw, 300), Charte.PANNEAU, Charte.RAYON_CARTE)
		carte.name = "MondeCarte%d" % k
		_survol(carte)
		_image(carte, str(a.image), Rect2(0, 0, 260, 300), Charte.RAYON_CARTE)
		D.rect(carte, Rect2(0, 0, 8, 300), col, 4)
		_pastille_ligue(carte, 284, 44, ligues, str(a.ligue))
		var t := D.text(carte, 284, 104, str(a.titre), 27, Charte.IVOIRE, 800, cw - 310)
		D.fit_title(t, cw - 310, 92, 2, 18)
		_signature(carte, 284, 152, a.journaliste, col, 15, cw - 310)
		var r: Dictionary = a.get("resultat", {})
		if not r.is_empty() and a.theme != "supporters":
			for j in 2:
				_crest(carte, _club(page, r.pair[j]), Rect2(284 + j * 54, 180, 44, 44))
			D.text(carte, 400, 216, _score_txt(r), 38, col, 800, cw - 420).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		elif not (a.get("personne", {}) as Dictionary).is_empty():
			_portrait(carte, a.personne, Rect2(284, 172, 60, 60), col)
			_crest(carte, _club(page, a.clubs[0]), Rect2(356, 182, 40, 40))
			D.text(carte, 408, 212, str(a.personne.get("name", "")), 20, Charte.IVOIRE, 800, cw - 430)
		else:
			for j in mini(2, (a.clubs as Array).size()):
				_crest(carte, _club(page, a.clubs[j]), Rect2(284 + j * 54, 180, 44, 44))
		_pastilles(carte, 284, 272, a, col, 15, cw - 300)
		_cliquable(carte, func(): article(page, a, ligues), "MondeCarteLien%d" % k, str(a.titre))

# ---- Dernière minute et plus d'actus -------------------------------------------------------------------------------

static func _derniere_minute(page, y: float, ligues: Array, a: Dictionary) -> float:
	var x := GAUCHE + 24
	var lw := W - x
	var col := _couleur_ligue(ligues, str(a.ligue))
	var carte := D.rect(page, Rect2(x, y, lw, 250), Charte.PANNEAU, Charte.RAYON_CARTE, R.ROUGE)
	carte.name = "MondeDerniereMinute"
	_survol(carte)
	_image(carte, str(a.image), Rect2(0, 0, 250, 250), Charte.RAYON_CARTE)
	D.rect(carte, Rect2(0, 0, 8, 250), R.ROUGE, 4)
	R.pastille(carte, 272, 40, "DERNIÈRE MINUTE", R.ROUGE, "clock", "MondeDerniereMinuteMarque", 15)
	var x0 := 272.0
	_portrait(carte, a.personne, Rect2(x0, 64, 84, 84), col)
	D.text(carte, x0 + 100, 96, str(a.personne.get("name", "")), 24, Charte.IVOIRE, 800, lw - x0 - 120)
	D.text(carte, x0 + 100, 124, str(a.personne.get("pos", "")), 16, Charte.IVOIRE_2, 700, 300)
	var tr: Dictionary = a.get("transfert", {})
	var vendeur := _club(page, tr.get("vendeurId"))
	var acheteur := _club(page, tr.get("acheteurId"))
	_crest(carte, vendeur, Rect2(x0 + 100, 136, 34, 34))
	D.text(carte, x0 + 142, 162, "→", 24, R.ROUGE, 800, 30)
	_crest(carte, acheteur, Rect2(x0 + 174, 136, 34, 34))
	D.text(carte, x0 + 218, 162, G.club_name(acheteur), 18, Charte.IVOIRE, 800, lw - x0 - 360)
	var montant := D.text(carte, lw - 20, 120, A._montant(int(_n(tr.get("montant")))), 40, R.ROUGE, 800, 220, HORIZONTAL_ALIGNMENT_RIGHT)
	montant.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	_signature(carte, x0, 222, a.journaliste, col, 15, lw - x0 - 20)
	_cliquable(carte, func(): article(page, a, ligues), "MondeDerniereMinuteLien", str(a.titre))
	return y + 250.0

static func _liste(page, y: float, bas: float, ligues: Array, liste: Array) -> void:
	var x := GAUCHE + 24
	var lw := W - x
	var yy := y
	var i := 0
	for a: Dictionary in liste:
		if yy + 72 > bas: break
		var col := _couleur_ligue(ligues, str(a.ligue))
		var ligne := D.rect(page, Rect2(x, yy, lw, 72), Charte.PANNEAU if i % 2 == 0 else Charte.PANNEAU_2, 10)
		ligne.name = "MondeActu%d" % i
		_survol(ligne)
		_image(ligne, str(a.image), Rect2(8, 8, 96, 56), 8)
		D.rect(ligne, Rect2(112, 10, 5, 52), col, 2)
		D.text(ligne, 128, 32, str(a.titre), 19, Charte.IVOIRE, 800, lw - 270)
		var jn: Dictionary = a.journaliste
		D.text(ligne, 128, 58, (str(jn.get("outlet", "")) + " · " + str(jn.get("name", ""))) if not jn.is_empty() else _nom_ligue(ligues, str(a.ligue)), 15, col, 700, lw - 270)
		var r: Dictionary = a.get("resultat", {})
		var droite := _score_txt(r) if not r.is_empty() and a.theme != "supporters" else (str(a.pastilles[0][0]) if not (a.pastilles as Array).is_empty() else "")
		D.text(ligne, lw - 16, 46, droite, 22, Charte.IVOIRE, 800, 130, HORIZONTAL_ALIGNMENT_RIGHT)
		_cliquable(ligne, func(): article(page, a, ligues), "MondeActuLien%d" % i, str(a.titre))
		yy += 80
		i += 1

# ---- Tous les championnats -----------------------------------------------------------------------------------------

static func _championnats(page, yv: float, ligues: Array) -> float:
	_titre(page, 0, yv, "TOUS LES CHAMPIONNATS")
	var par_ligne := 6
	var vw := (W - (par_ligne - 1) * 14.0) / par_ligne
	var h := 226.0
	for k in ligues.size():
		var l: Dictionary = ligues[k]
		var vx := (k % par_ligne) * (vw + 14)
		var vy := yv + 18 + (k / par_ligne) * (h + 14)
		var v := D.rect(page, Rect2(vx, vy, vw, h), Charte.PANNEAU, Charte.RAYON_CARTE)
		v.name = "MondeLigue%d" % k
		_survol(v)
		var tete := D.rect(v, Rect2(0, 0, vw, 50), l.couleur, Charte.RAYON_CARTE)
		D.text(tete, 16, 34, str(l.nom).to_upper(), 18, Charte.ENCRE, 800, vw - 32)
		for j in mini(4, (l.rows as Array).size()):
			var club: Dictionary = l.rows[j]
			var ly := 60.0 + j * 40.0
			D.text(v, 16, ly + 26, str(j + 1), 17, l.couleur if j == 0 else Charte.IVOIRE_2, 800, 30)
			_crest(v, club, Rect2(44, ly + 6, 28, 28))
			D.text(v, 82, ly + 26, G.club_name(club), 17, Charte.IVOIRE, 700, vw - 150)
			D.text(v, vw - 16, ly + 26, str(int(_n(club.get("points")))), 18, l.couleur if j == 0 else Charte.IVOIRE, 800, 50, HORIZONTAL_ALIGNMENT_RIGHT)
		var lid := str(l.id)
		_cliquable(v, func(): page.open_target(page.app, "competition", lid), "MondeLigueLien%d" % k, str(l.nom))
	var rangs := ceili(ligues.size() / float(par_ligne))
	return yv + 18 + rangs * (h + 14) + 20.0

# ---- Petite fenêtre de l'article -----------------------------------------------------------------------------------

## L'article en grand : image, ligue, titre, signature, chiffres ; tuiles cliquables vers les clubs, la rencontre, le
## classement. Échap, ✕ et clic à côté ferment.
static func article(page, a: Dictionary, ligues: Array) -> void:
	var col := _couleur_ligue(ligues, str(a.ligue))
	var jn: Dictionary = a.get("journaliste", {})
	var lw := 1180.0
	var fond := Fenetre.ouvrir(page, "MondeArticle", str(jn.get("outlet", "Dans le monde")).to_upper(), "globe", lw, 900)
	_image(fond, str(a.image), Rect2(28, 80, lw - 56, 430), 14)
	D.rect(fond, Rect2(28, 80, 10, 430), col, 4)
	_pastille_ligue(fond, 28, 556, ligues, str(a.ligue), 17)
	var t := D.text(fond, 28, 618, str(a.titre).to_upper(), 40, Charte.IVOIRE, 800, lw - 56)
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.fit_title(t, lw - 56, 100, 2, 24)
	_signature(fond, 28, 668, jn, col, 18, lw - 56)
	_pastilles(fond, 28, 712, a, col, 17, lw - 56)
	# Tuiles : clubs (fiche du club), rencontre (feuille de match) ou classement.
	var tuiles: Array = []
	var personne: Dictionary = a.get("personne", {})
	for id: Variant in a.get("clubs", []):
		var club := _club(page, id)
		if not club.is_empty(): tuiles.append({"club": club, "cible": {"kind": "club", "id": str(club.get("id"))}})
	var r: Dictionary = a.get("resultat", {})
	if not r.is_empty(): tuiles.append({"score": _score_txt(r), "cible": {"kind": "fixture", "id": str(r.get("fixtureId", ""))}})
	tuiles.append({"ligue": str(a.ligue), "cible": {"kind": "competition", "id": str(a.ligue)}})
	var tw := (lw - 56 - (tuiles.size() - 1) * 14.0) / tuiles.size()
	for k in tuiles.size():
		var d: Dictionary = tuiles[k]
		var tuile := D.rect(fond, Rect2(28 + k * (tw + 14), 748, tw, 120), Charte.PANNEAU_3, 12)
		tuile.name = "MondeArticleTuile%d" % k
		_survol(tuile)
		if d.has("club"):
			if k == 0 and not personne.is_empty():
				_portrait(tuile, personne, Rect2(14, 14, 92, 92), col)
				_crest(tuile, d.club, Rect2(84, 74, 34, 34))
				D.text(tuile, 124, 54, str(personne.get("name", "")), 19, Charte.IVOIRE, 800, tw - 136)
				D.text(tuile, 124, 84, G.club_name(d.club), 16, Charte.IVOIRE_2, 700, tw - 136)
			else:
				_crest(tuile, d.club, Rect2(16, 22, 76, 76))
				D.text(tuile, 106, 68, G.club_name(d.club), 19, Charte.IVOIRE, 800, tw - 118)
		elif d.has("score"):
			D.text(tuile, tw / 2.0, 80, d.score, 44, col, 800, tw - 20, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		else:
			var tete := D.rect(tuile, Rect2(0, 0, tw, 12), col, 6)
			tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ic := C.icon("trophy", 34, col)
			tuile.add_child(ic)
			D.place(ic, Rect2(18, 44, 34, 34))
			D.text(tuile, 64, 72, _nom_ligue(ligues, d.ligue), 19, Charte.IVOIRE, 800, tw - 76)
		var cible: Dictionary = d.cible
		var aller := func():
			Fenetre.fermer(page, "MondeArticle")
			_ouvrir_cible(page, cible)
		_cliquable(tuile, aller, "MondeArticleLien%d" % k, str(cible.kind))
