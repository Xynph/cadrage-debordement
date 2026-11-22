extends RefCounted
## Compte rendu du match en carte (idée FM n°19, planche A/B du 22/11/2026, pas encore tranchée par Léo) : en tête de
## l'article « COMPTE RENDU » de la Réception (courrier de presse `article`, le lendemain du match), une carte du
## match, puis le texte du journal. Données : `decisions.report` (score, météo, stats, essais avec minute, marqueur et
## origine) et `clubLife.matchNotes.dernier` (homme du match, notes). Seule la dernière rencontre du club est connue :
## la carte ne se pose que sur l'article de ce match. Variante sous CD_VARIANTE_VISUELLE=A|B :
##   A : carte d'article en trois colonnes (fiche du match + homme du match · stats en barres miroir · marqueurs) ;
##   B : feuille de match en largeur (bandeau du score, frise 0-80' des essais, lignes « Effectif » des meilleures
##       notes et tableau de stats à barre partagée).
## Coordonnées en unités du gabarit (primitives.gd), relatives à la carte.

const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Bilan = preload("res://ui/immersive08/avant_match_bilan.gd")
const Notes = preload("res://ui/notes_match.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const NOUS := R.VERT
const EUX := R.BLEU
const ORIGINES := {"j": ["Jeu courant", "ball"], "b": ["Ballon porté", "people"], "m": ["Mêlée", "shield"]}

static func variante() -> String:
	return "B" if OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper() == "B" else "A"

## La carte du match pour ce courrier de presse, ou null (autre courrier, match inconnu, article d'un ancien match).
static func carte(app: Control, mail: Dictionary, largeur: float) -> Control:
	if str(mail.get("type", "")) != "article": return null
	var model: Dictionary = app.model
	var report := Bilan.rapport(model)
	if report.is_empty(): return null
	if mail.get("club") == null or _n(mail.get("club")) != _n(report.teams[1 - int(report.side)].get("id")): return null
	# Seul le dernier article porte la carte : un ancien papier contre le même club n'a plus ses chiffres.
	for autre: Dictionary in ClubMail.mails(model):
		if str(autre.get("type", "")) == "article":
			if str(autre.get("id", "")) != str(mail.get("id", "")): return null
			break
	var ctx := _contexte(app, report)
	var racine := Control.new()
	racine.name = "CompteRenduCarte"
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	var hauteur := _carte_a(racine, ctx, largeur) if variante() == "A" else _carte_b(racine, ctx, largeur)
	racine.custom_minimum_size = Vector2(C.px(largeur), C.px(hauteur))
	return racine

# ---- Données ---------------------------------------------------------------------------------------------------------

static func _n(v: Variant) -> int:
	return roundi(float(v)) if v is int or v is float else 0

static func _contexte(app: Control, report: Dictionary) -> Dictionary:
	var model: Dictionary = app.model
	var clubs: Array = [Bilan._club(model, report.teams[0]), Bilan._club(model, report.teams[1])]
	var dernier: Variant = model.get("clubLife", {}).get("matchNotes", {}).get("dernier") if model.get("clubLife") is Dictionary else null
	if not dernier is Dictionary or not dernier.get("score") is Array or _n(dernier.score[0]) != _n(report.score[0]) or _n(dernier.score[1]) != _n(report.score[1]): dernier = {}
	var essais: Array = report.get("essais", []) if report.get("essais") is Array else []
	var competition := ""
	var comp := str(dernier.get("comp", ""))
	for ligue: Variant in model.get("leagues", []):
		if ligue is Dictionary and str(ligue.get("id", "")) == comp: competition = str(ligue.get("name", ""))
	var stade := str(G.identity(clubs[0]).get("stadium", "")).strip_edges()
	return {"app": app, "model": model, "report": report, "clubs": clubs, "cote": int(report.side), "dernier": dernier,
		"essais": essais, "competition": competition, "comp": comp, "stade": stade}

## Lignes de stats [libellé, valeur gauche, valeur droite, texte gauche, texte droit] (domicile à gauche).
static func _stats(ctx: Dictionary) -> Array:
	var r: Dictionary = ctx.report
	var lignes: Array = []
	var e := [0, 0]
	for essai: Variant in ctx.essais:
		if essai is Dictionary: e[clampi(_n(essai.get("side")), 0, 1)] += 1
	lignes.append(["Essais", e[0], e[1], str(e[0]), str(e[1])])
	var s: Variant = r.get("stats")
	var t: Variant = r.get("tacticalStats")
	if s is Array and s.size() == 2 and s[0] is Dictionary and s[1] is Dictionary:
		var p := float(_n(s[0].get("possession")) + _n(s[1].get("possession")))
		if p > 0:
			var a := roundi(100.0 * _n(s[0].possession) / p)
			lignes.append(["Possession", a, 100 - a, "%d %%" % a, "%d %%" % (100 - a)])
		var te := float(s[0].get("territory", 0)) + float(s[1].get("territory", 0))
		if te > 0:
			var a := roundi(100.0 * float(s[0].territory) / te)
			lignes.append(["Territoire", a, 100 - a, "%d %%" % a, "%d %%" % (100 - a)])
	if t is Array and t.size() == 2 and t[0] is Dictionary and t[1] is Dictionary:
		lignes.append(["Mètres portés", _n(t[0].get("metres")), _n(t[1].get("metres")), str(_n(t[0].get("metres"))), str(_n(t[1].get("metres")))])
	if s is Array and s.size() == 2 and s[0] is Dictionary and s[1] is Dictionary:
		lignes.append(["Mêlées gagnées", _n(s[0].get("scrumsWon")), _n(s[1].get("scrumsWon")), "%d/%d" % [_n(s[0].get("scrumsWon")), _n(s[0].get("scrums"))], "%d/%d" % [_n(s[1].get("scrumsWon")), _n(s[1].get("scrums"))]])
		lignes.append(["Touches gagnées", _n(s[0].get("lineoutsWon")), _n(s[1].get("lineoutsWon")), "%d/%d" % [_n(s[0].get("lineoutsWon")), _n(s[0].get("lineouts"))], "%d/%d" % [_n(s[1].get("lineoutsWon")), _n(s[1].get("lineouts"))]])
		lignes.append(["Pénalités concédées", _n(s[0].get("penalties")), _n(s[1].get("penalties")), str(_n(s[0].get("penalties"))), str(_n(s[1].get("penalties")))])
	return lignes

static func _couleur_camp(ctx: Dictionary, camp: int) -> Color:
	return NOUS if camp == int(ctx.cote) else EUX

static func _joueur(ctx: Dictionary, id: String, nom: String) -> Dictionary:
	for p: Variant in ctx.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return p
	return {"id": id, "name": nom}

static func _a_nous(ctx: Dictionary, id: String) -> bool:
	for p: Variant in ctx.model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return true
	return false

# ---- Briques -------------------------------------------------------------------------------------------------------

static func _ecusson(parent: Control, ctx: Dictionary, camp: int, zone: Rect2, id: String) -> Control:
	var club: Dictionary = ctx.clubs[camp]
	var e := G.crest(club, C.px(zone.size.x))
	e.name = id
	parent.add_child(e)
	D.place(e, zone)
	var cle := str(_n(ctx.report.teams[camp].get("id")))
	if camp != int(ctx.cote) and Link.available(ctx.app, "club", cle):
		var b := R.cliquable(e, func(): ctx.app.navigation_controller.open_entity({"kind": "club", "id": cle}), id + "Lien", "Fiche · " + G.club_name(club))
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return e

static func _nom_club(parent: Control, ctx: Dictionary, camp: int, x: float, baseline: float, largeur: float, taille: int, align: HorizontalAlignment, id: String) -> void:
	var club: Dictionary = ctx.clubs[camp]
	var nom := D.text(parent, x, baseline, G.club_name(club).to_upper(), taille, Charte.IVOIRE if camp == int(ctx.cote) else Charte.IVOIRE_2, 800, largeur, align)
	nom.name = id
	nom.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)

static func _score(parent: Control, ctx: Dictionary, centre: float, baseline: float, taille: int) -> void:
	var s: Array = ctx.report.score
	var t := D.text(parent, centre, baseline, "%d – %d" % [_n(s[0]), _n(s[1])], taille, Charte.IVOIRE, 800, 420, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "CompteRenduScore"
	t.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)

static func _resultat(ctx: Dictionary) -> Array:
	var res := Bilan.resultat(ctx.report)
	return [{"V": "Victoire", "N": "Nul", "D": "Défaite"}[res], R.VERT if res == "V" else R.ROUGE if res == "D" else R.BLEU, "trophy" if res == "V" else "flag"]

## Nom de joueur : lien vers sa fiche si elle existe, mini-fiche au survol pour nos joueurs.
static func _nom_joueur(parent: Control, ctx: Dictionary, id: String, nom: String, zone: Rect2, taille: int, couleur: Color, cle: String) -> Control:
	var n := Link.name_link(ctx.app, parent, zone, "player", id, nom, taille, couleur, cle)
	if _a_nous(ctx, id) and n is Button: MiniFiche.lier(ctx.app, n, id, "squad")
	return n

static func _portrait(parent: Control, ctx: Dictionary, zone: Rect2, joueur: Dictionary, bord: Color) -> void:
	var cadre := D.rect(parent, zone, Charte.PANNEAU_3, 999, bord)
	(cadre.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(2, C.px(3)))
	cadre.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	cadre.name = "CompteRenduPortrait"
	var im: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(zone.size.x), joueur)
	im.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(im)
	D.place(im, Rect2(0, zone.size.y * .04, zone.size.x, zone.size.y * 1.12))

static func _note(parent: Control, zone: Rect2, note: Variant) -> void:
	if note == null: return
	Notes.pastille(parent, zone, float(note), 0.62 * C.density).name = "CompteRenduNote"

static func _titre(parent: Control, x: float, baseline: float, texte: String, icone: String, couleur: Color) -> void:
	var i := C.icon(icone, C.px(22), couleur)
	parent.add_child(i)
	D.place(i, Rect2(x, baseline - 19, 22, 22))
	D.text(parent, x + 32, baseline, texte, 20, Charte.IVOIRE, 800, 400)

# ---- Option A : carte d'article en trois colonnes ------------------------------------------------------------------

static func _carte_a(racine: Control, ctx: Dictionary, W: float) -> float:
	var stats := _stats(ctx)
	var corps_h := maxf(300.0, maxf(64.0 + stats.size() * 38.0, 44.0 + 2 * 54.0 + maxf(1, ctx.essais.size()) * 38.0 + 38.0))
	var H := 112.0 + corps_h + 16.0
	var fond := D.rect(racine, Rect2(0, 0, W, H), Charte.PANNEAU, Charte.RAYON_CARTE)
	fond.name = "CompteRenduFond"
	fond.add_theme_stylebox_override("panel", Charte.ombrer(fond.get_theme_stylebox("panel") as StyleBoxFlat, Charte.RAYON_CARTE))
	# Bandeau : noms, écussons et score, résultat dessous.
	var bandeau := D.rect(fond, Rect2(0, 0, W, 112), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	bandeau.name = "CompteRenduBandeau"
	var m := W / 2.0
	_ecusson(bandeau, ctx, 0, Rect2(m - 290, 16, 74, 74), "CompteRenduEcusson0")
	_ecusson(bandeau, ctx, 1, Rect2(m + 216, 16, 74, 74), "CompteRenduEcusson1")
	_nom_club(bandeau, ctx, 0, m - 310, 64, m - 340, 30, HORIZONTAL_ALIGNMENT_RIGHT, "CompteRenduNom0")
	_nom_club(bandeau, ctx, 1, m + 310, 64, m - 340, 30, HORIZONTAL_ALIGNMENT_LEFT, "CompteRenduNom1")
	_score(bandeau, ctx, m, 72, 60)
	var res := _resultat(ctx)
	var w_res := R.largeur(res[0], 17) + 52
	R.pastille(bandeau, m - w_res / 2.0, 100, res[0], res[1], res[2], "CompteRenduResultat", 17)
	if not str(ctx.competition).is_empty():
		var lien := D.text(bandeau, 28, 100, str(ctx.competition).to_upper(), 17, Charte.IVOIRE_2, 700, m - 360)
		lien.name = "CompteRenduCompetition"
	# Trois colonnes.
	var y := 112.0 + 16.0
	var c1 := 32.0
	var w1 := W * .27
	var c2 := c1 + w1 + 32.0
	var w2 := W * .40
	var c3 := c2 + w2 + 32.0
	var w3 := W - c3 - 32.0
	for x: float in [c2 - 16.0, c3 - 16.0]: D.line(fond, Vector2(x, y), Vector2(x, H - 16), Charte.FILET)
	# 1. Le match (lieu, météo) puis l'homme du match.
	_titre(fond, c1, y + 22, "LE MATCH", "calendar", Charte.IVOIRE_2)
	var infos: Array = []
	infos.append(["home", "Lieu", str(ctx.stade) if not str(ctx.stade).is_empty() else ("Domicile" if int(ctx.cote) == 0 else "Extérieur")])
	if ctx.report.get("weather") is String and not str(ctx.report.weather).is_empty(): infos.append(["cloud", "Météo", str(ctx.report.weather)])
	var yy := y + 60.0
	for info: Array in infos:
		D.rect(fond, Rect2(c1, yy - 26, w1, 40), Charte.PANNEAU_2, 6)
		var ic := C.icon(str(info[0]), C.px(20), R.BLEU)
		fond.add_child(ic)
		D.place(ic, Rect2(c1 + 12, yy - 16, 20, 20))
		D.text(fond, c1 + 42, yy, str(info[1]), 17, Charte.IVOIRE_2, 600, 110)
		D.text(fond, c1 + 150, yy, str(info[2]), 18, Charte.IVOIRE, 700, w1 - 160)
		yy += 44.0
	var hdm: Variant = ctx.dernier.get("hommeDuMatch")
	yy += 12.0
	_titre(fond, c1, yy, "HOMME DU MATCH", "star", R.ORANGE)
	if hdm is Dictionary:
		var id := str(hdm.get("id", ""))
		var camp := 0 if _n(hdm.get("club")) == _n(ctx.report.teams[0].get("id")) else 1
		var joueur := _joueur(ctx, id, str(hdm.get("nom", "")))
		_portrait(fond, ctx, Rect2(c1, yy + 20, 92, 92), joueur, _couleur_camp(ctx, camp))
		_nom_joueur(fond, ctx, id, str(hdm.get("nom", "")), Rect2(c1 + 106, yy + 24, w1 - 160, 34), 22, Charte.IVOIRE, "CompteRenduHdm")
		var mini := G.crest(ctx.clubs[camp], C.px(26))
		fond.add_child(mini)
		D.place(mini, Rect2(c1 + w1 - 40, yy + 28, 26, 26))
		_note(fond, Rect2(c1 + 106, yy + 66, 58, 30), hdm.get("note"))
		var x := c1 + 106 + (68.0 if hdm.get("note") != null else 0.0)
		for fait: Array in [[_n(hdm.get("essais")), "ess.", NOUS], [_n(hdm.get("plaquages")), "plaq.", R.VIOLET], [_n(hdm.get("metres")), "m", R.BLEU]]:
			var t := "%d %s" % [fait[0], fait[1]]
			D.text(fond, x, yy + 89, t, 18, fait[2], 800, R.largeur(t, 18, 800) + 4)
			x += R.largeur(t, 18, 800) + 16
	# 2. Stats en barres miroir : domicile à gauche, extérieur à droite, part de chacun depuis le centre.
	_titre(fond, c2, y + 22, "STATS DU MATCH", "target", Charte.IVOIRE_2)
	for camp in 2:
		var p := R.pastille(fond, c2 + (230.0 if camp == 0 else w2 - 120.0), y + 22, G.club_abbr(ctx.clubs[camp]), _couleur_camp(ctx, camp), "", "CompteRenduLegende%d" % camp, 16)
		if camp == 1: p.position.x = C.px(c2 + w2) - p.size.x
	var ys := y + 66.0
	var mi := c2 + w2 / 2.0
	var trou := 92.0
	var demi := w2 / 2.0 - trou - 70.0
	for i in stats.size():
		var l: Array = stats[i]
		var total := float(l[1] + l[2])
		D.text(fond, mi, ys + 6, str(l[0]), 15, Charte.IVOIRE_2, 600, trou * 2 - 8, HORIZONTAL_ALIGNMENT_CENTER).name = "CompteRenduStat%d" % i
		for camp in 2:
			var bx := mi - trou - demi if camp == 0 else mi + trou
			D.rect(fond, Rect2(bx, ys - 6, demi, 14), Charte.PANNEAU_3, 7)
			var part := (float(l[1 + camp]) / total) if total > 0 else 0.0
			var w := demi * part
			if w > 2: D.rect(fond, Rect2(mi - trou - w if camp == 0 else mi + trou, ys - 6, w, 14), _couleur_camp(ctx, camp), 7)
			var gagne: bool = l[1 + camp] > l[2 - camp] if l[0] != "Pénalités concédées" else l[1 + camp] < l[2 - camp]
			D.text(fond, c2 if camp == 0 else c2 + w2, ys + 8, str(l[3 + camp]), 20, _couleur_camp(ctx, camp) if gagne else Charte.IVOIRE, 800, 64, HORIZONTAL_ALIGNMENT_LEFT if camp == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		ys += 38.0
	# 3. Marqueurs : par équipe, minute, nom, origine de l'essai.
	_titre(fond, c3, y + 22, "ESSAIS", "ball", Charte.IVOIRE_2)
	var ye := y + 44.0
	for camp in 2:
		var e := G.crest(ctx.clubs[camp], C.px(28))
		fond.add_child(e)
		D.place(e, Rect2(c3, ye, 28, 28))
		D.text(fond, c3 + 38, ye + 21, G.club_name(ctx.clubs[camp]), 19, _couleur_camp(ctx, camp), 800, w3 - 40)
		ye += 40.0
		var n := 0
		for essai: Variant in ctx.essais:
			if not essai is Dictionary or _n(essai.get("side")) != camp: continue
			var ligne := D.rect(fond, Rect2(c3, ye, w3, 36), Charte.PANNEAU_2 if n % 2 == 0 else Color.TRANSPARENT, 6)
			ligne.name = "CompteRenduEssai%d_%d" % [camp, n]
			D.text(ligne, 10, 25, "%d'" % _n(essai.get("minute")), 19, _couleur_camp(ctx, camp), 800, 46)
			var nom := str(essai.get("name")) if essai.get("name") != null else "—"
			_nom_joueur(ligne, ctx, str(essai.get("id", "")), nom, Rect2(56, 2, w3 - 56 - 150, 32), 18, Charte.IVOIRE, "CompteRenduMarqueur%d_%d" % [camp, n])
			var o: Array = ORIGINES.get(str(essai.get("origin", "j")), ORIGINES.j)
			var po := R.pastille(ligne, 0, 24, str(o[0]), R.TURQUOISE if o[1] != "ball" else Charte.IVOIRE_2, str(o[1]), "", 15)
			po.position.x = C.px(w3 - 8) - po.size.x
			ye += 38.0
			n += 1
		if n == 0:
			D.text(fond, c3 + 10, ye + 22, "—", 19, Charte.IVOIRE_2, 700, 40)
			ye += 38.0
		ye += 14.0
	return H

# ---- Option B : feuille de match en largeur ------------------------------------------------------------------------

static func _carte_b(racine: Control, ctx: Dictionary, W: float) -> float:
	var stats := _stats(ctx)
	var H_bandeau := 126.0
	var H_frise := 148.0
	var H_bas := 52.0 + maxf(4.0, stats.size()) * 34.0
	var H := H_bandeau + H_frise + H_bas + 26.0
	var fond := D.rect(racine, Rect2(0, 0, W, H), Charte.PANNEAU, Charte.RAYON_CARTE)
	fond.name = "CompteRenduFond"
	fond.add_theme_stylebox_override("panel", Charte.ombrer(fond.get_theme_stylebox("panel") as StyleBoxFlat, Charte.RAYON_CARTE))
	# Bandeau : couleur du camp sur chaque bord, écussons, noms, score géant, pastilles résultat / lieu / météo.
	var m := W / 2.0
	for camp in 2:
		var bord := D.rect(fond, Rect2(0 if camp == 0 else W - 10, 0, 10, H_bandeau), _couleur_camp(ctx, camp), 0)
		bord.name = "CompteRenduBord%d" % camp
	_ecusson(fond, ctx, 0, Rect2(36, 18, 86, 86), "CompteRenduEcusson0")
	_ecusson(fond, ctx, 1, Rect2(W - 122, 18, 86, 86), "CompteRenduEcusson1")
	_nom_club(fond, ctx, 0, 146, 58, m - 380, 34, HORIZONTAL_ALIGNMENT_LEFT, "CompteRenduNom0")
	_nom_club(fond, ctx, 1, W - 146, 58, m - 380, 34, HORIZONTAL_ALIGNMENT_RIGHT, "CompteRenduNom1")
	for camp in 2:
		var leg := G.club_abbr(ctx.clubs[camp])
		var p := R.pastille(fond, 146, 94, leg, _couleur_camp(ctx, camp), "", "CompteRenduLegende%d" % camp, 17)
		if camp == 1: p.position.x = C.px(W - 146) - p.size.x
	_score(fond, ctx, m, 72, 68)
	var res := _resultat(ctx)
	var pastilles: Array = [[res[0], res[1], res[2]]]
	pastilles.append([str(ctx.stade) if not str(ctx.stade).is_empty() else ("Domicile" if int(ctx.cote) == 0 else "Extérieur"), R.TURQUOISE, "home"])
	if ctx.report.get("weather") is String and not str(ctx.report.weather).is_empty(): pastilles.append([str(ctx.report.weather), R.BLEU, "cloud"])
	if not str(ctx.competition).is_empty(): pastilles.append([str(ctx.competition), Charte.IVOIRE_2, "trophy"])
	var total_w := 0.0
	for p: Array in pastilles: total_w += R.largeur(str(p[0]), 17) + 52 + 10
	var x := m - (total_w - 10) / 2.0
	for i in pastilles.size():
		var p: Array = pastilles[i]
		var pa := R.pastille(fond, x, 108, str(p[0]), p[1], str(p[2]), "CompteRenduInfo%d" % i, 17)
		x += pa.size.x / C.density + 10
	D.line(fond, Vector2(0, H_bandeau), Vector2(W, H_bandeau), Charte.FILET)
	# Frise des essais : 0' à 80', mi-temps marquée ; domicile au-dessus, extérieur dessous, nom et minute.
	var y0 := H_bandeau + H_frise / 2.0 + 4
	var gx := 90.0
	var gw := W - 180.0
	var fin := 80.0
	for essai: Variant in ctx.essais:
		if essai is Dictionary: fin = maxf(fin, float(_n(essai.get("minute"))))
	D.rect(fond, Rect2(gx, y0 - 3, gw, 6), Charte.PANNEAU_3, 3)
	for repere: Array in [[0, "0'"], [40, "MT"], [80, "80'"]]:
		var rx := gx + gw * float(repere[0]) / fin
		D.rect(fond, Rect2(rx - 1, y0 - 12, 2, 24), Charte.IVOIRE_2, 0)
		if repere[0] == 0: D.text(fond, gx - 14, y0 + 6, str(repere[1]), 16, Charte.IVOIRE_2, 700, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		elif repere[0] == 80: D.text(fond, gx + gw + 14, y0 + 6, str(repere[1]), 16, Charte.IVOIRE_2, 700, 60)
		else: D.text(fond, rx + 8, y0 + 30, str(repere[1]), 15, Charte.IVOIRE_2, 700, 40)
	# Une rangée d'étiquettes par camp : une étiquette trop proche de la précédente glisse à droite, reliée par un coude.
	var bout := [-9999.0, -9999.0]
	var compte := [0, 0]
	for essai: Variant in ctx.essais:
		if not essai is Dictionary: continue
		var camp := clampi(_n(essai.get("side")), 0, 1)
		var ex := gx + gw * float(_n(essai.get("minute"))) / fin
		var nom := str(essai.get("name")) if essai.get("name") != null else "—"
		var o: Array = ORIGINES.get(str(essai.get("origin", "j")), ORIGINES.j)
		var lw := R.largeur(nom, 17) + 64 + (22.0 if o[1] != "ball" else 0.0)
		var lx := clampf(maxf(ex - lw / 2.0, float(bout[camp]) + 10.0), 4.0, W - lw - 4.0)
		bout[camp] = lx + lw
		var sens := -1.0 if camp == 0 else 1.0
		var tige := 34.0
		var couleur := _couleur_camp(ctx, camp)
		D.rect(fond, Rect2(ex - 1, y0 + (sens * tige if sens < 0 else 0), 2, tige), Color(couleur, .7), 0)
		var centre := lx + lw / 2.0
		if absf(centre - ex) > 2: D.rect(fond, Rect2(minf(ex, centre) - 1, y0 + sens * tige - 1, absf(centre - ex) + 2, 2), Color(couleur, .7), 0)
		var pastille := D.rect(fond, Rect2(ex - 13, y0 - 13, 26, 26), couleur, 13)
		var ball := C.icon("ball", C.px(16), Charte.ENCRE)
		pastille.add_child(ball)
		D.place(ball, Rect2(5, 5, 16, 16))
		var haut := y0 + sens * tige + (-30.0 if sens < 0 else 0.0)
		var cadre := D.rect(fond, Rect2(lx, haut, lw, 30), Charte.PANNEAU_2, 6, Color(couleur, .5))
		cadre.name = "CompteRenduEssai%d_%d" % [camp, compte[camp]]
		D.text(cadre, 8, 22, "%d'" % _n(essai.get("minute")), 17, couleur, 800, 44)
		_nom_joueur(cadre, ctx, str(essai.get("id", "")), nom, Rect2(48, 0, R.largeur(nom, 17) + 12, 30), 17, Charte.IVOIRE, "CompteRenduMarqueur%d_%d" % [camp, compte[camp]])
		if o[1] != "ball":
			var io := C.icon(str(o[1]), C.px(16), R.TURQUOISE)
			io.tooltip_text = str(o[0])
			io.mouse_filter = Control.MOUSE_FILTER_STOP
			cadre.add_child(io)
			D.place(io, Rect2(lw - 26, 7, 16, 16))
		compte[camp] += 1
	D.line(fond, Vector2(0, H_bandeau + H_frise), Vector2(W, H_bandeau + H_frise), Charte.FILET)
	# Bas gauche : lignes « Effectif » des meilleures notes du match (homme du match en tête, étoile).
	var yb := H_bandeau + H_frise + 30.0
	var gl := W * .46
	_titre(fond, 32, yb, "LES NOTES", "star", R.ORANGE)
	var colonnes := [["NOTE", 120.0], ["ESS.", 70.0], ["PLAQ.", 80.0], ["M", 70.0]]
	var cx := 32.0 + gl - 340.0
	for c: Array in colonnes:
		D.text(fond, cx, yb + 32, str(c[0]), 14, Charte.IVOIRE_2, 700, float(c[1]), HORIZONTAL_ALIGNMENT_CENTER if c[0] != "NOTE" else HORIZONTAL_ALIGNMENT_LEFT)
		cx += float(c[1])
	var lignes: Array = []
	var hdm: Variant = ctx.dernier.get("hommeDuMatch")
	var hdm_id := str(hdm.get("id", "")) if hdm is Dictionary else ""
	if hdm is Dictionary: lignes.append({"id": hdm_id, "nom": str(hdm.get("nom", "")), "note": hdm.get("note"), "essais": hdm.get("essais"), "plaquages": hdm.get("plaquages"), "metres": hdm.get("metres"), "camp": 0 if _n(hdm.get("club")) == _n(ctx.report.teams[0].get("id")) else 1})
	var nos: Array = []
	for n: Variant in ctx.dernier.get("notes", []):
		if n is Dictionary and n.get("note") != null and _n(n.get("cote")) == int(ctx.cote) and str(n.get("id", "")) != hdm_id: nos.append(n)
	nos.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.note) > float(b.note))
	for n: Dictionary in nos.slice(0, 4 - lignes.size()):
		var p := _joueur(ctx, str(n.id), "")
		lignes.append({"id": str(n.id), "nom": str(p.get("name", "")), "note": n.note, "essais": n.get("essais"), "plaquages": n.get("plaquages"), "metres": n.get("metres"), "camp": int(ctx.cote)})
	var yl := yb + 38.0
	for i in lignes.size():
		var l: Dictionary = lignes[i]
		var ligne := D.rect(fond, Rect2(32, yl, gl, 38), Charte.PANNEAU_2 if i % 2 == 0 else Color.TRANSPARENT, 6)
		ligne.name = "CompteRenduLigne%d" % i
		_survol(ligne)
		D.rect(ligne, Rect2(0, 5, 4, 28), _couleur_camp(ctx, int(l.camp)), 2)
		var joueur := _joueur(ctx, str(l.id), str(l.nom))
		var visage: Control = G.portrait_lazy(int(joueur.get("portraitIndex", 0)), C.px(34), joueur)
		visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(visage)
		D.place(visage, Rect2(12, 3, 32, 32))
		var lw := gl - 340.0 - 60.0 - (34.0 if str(l.id) == hdm_id else 0.0)
		_nom_joueur(ligne, ctx, str(l.id), str(l.nom), Rect2(54, 3, lw, 32), 19, Charte.IVOIRE, "CompteRenduNoteNom%d" % i)
		if str(l.id) == hdm_id:
			var etoile := C.icon("star", C.px(22), R.ORANGE)
			etoile.tooltip_text = "Homme du match"
			etoile.mouse_filter = Control.MOUSE_FILTER_STOP
			ligne.add_child(etoile)
			D.place(etoile, Rect2(54 + lw + 6, 8, 22, 22))
		var x0 := gl - 340.0
		if l.note != null: _note(ligne, Rect2(x0, 5, 56, 28), l.note)
		else: D.text(ligne, x0 + 10, 26, "—", 19, Charte.IVOIRE_2, 700, 40)
		x0 += 120.0
		for val: Array in [[l.essais, NOUS, 70.0], [l.plaquages, R.VIOLET, 80.0], [l.metres, R.BLEU, 70.0]]:
			D.text(ligne, x0 + float(val[2]) / 2.0, 26, str(_n(val[0])), 20, val[1] if _n(val[0]) > 0 else Charte.IVOIRE_2, 800, float(val[2]), HORIZONTAL_ALIGNMENT_CENTER)
			x0 += float(val[2])
		yl += 40.0
	# Bas droit : tableau de stats, une barre partagée par ligne (part de chaque camp), chiffre du meilleur coloré.
	var tx := 32.0 + gl + 48.0
	var tw := W - tx - 32.0
	_titre(fond, tx, yb, "STATS", "target", Charte.IVOIRE_2)
	var yt := yb + 18.0
	for i in stats.size():
		var s: Array = stats[i]
		var ligne := D.rect(fond, Rect2(tx, yt, tw, 32), Charte.PANNEAU_2 if i % 2 == 0 else Color.TRANSPARENT, 6)
		ligne.name = "CompteRenduStat%d" % i
		_survol(ligne)
		D.text(ligne, 12, 23, str(s[0]), 18, Charte.IVOIRE_2, 600, 210)
		var bx := 232.0
		var bw := tw - bx - 170.0
		var total := float(s[1] + s[2])
		var part := float(s[1]) / total if total > 0 else 0.5
		D.rect(ligne, Rect2(bx, 10, bw, 12), Charte.PANNEAU_3, 6)
		if total > 0:
			if part > 0: D.rect(ligne, Rect2(bx, 10, bw * part - 1, 12), _couleur_camp(ctx, 0), 6)
			if part < 1: D.rect(ligne, Rect2(bx + bw * part + 1, 10, bw * (1.0 - part) - 1, 12), _couleur_camp(ctx, 1), 6)
		for camp in 2:
			var gagne: bool = s[1 + camp] > s[2 - camp] if s[0] != "Pénalités concédées" else s[1 + camp] < s[2 - camp]
			var vx := tw - 170.0 + 78.0 if camp == 0 else tw - 170.0 + 92.0
			D.text(ligne, vx, 23, str(s[3 + camp]), 19, _couleur_camp(ctx, camp) if gagne else Charte.IVOIRE, 800, 72, HORIZONTAL_ALIGNMENT_RIGHT if camp == 0 else HORIZONTAL_ALIGNMENT_LEFT)
		yt += 34.0
	return H

## Survol d'une ligne (grammaire de l'Effectif) : la ligne se démarque sous la souris, sans changer d'écran.
static func _survol(ligne: Panel) -> void:
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := (ligne.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var base := style.bg_color
	ligne.add_theme_stylebox_override("panel", style)
	ligne.mouse_entered.connect(func(): style.bg_color = Charte.SELECTION)
	ligne.mouse_exited.connect(func(): style.bg_color = base)
