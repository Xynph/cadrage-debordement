extends RefCounted
## Petite fenêtre des consignes pendant le match (planche FM27 n° 33, revue de Léo du 22/11/2026, sous
## CD_VARIANTE_VISUELLE A|B). Le match continue derrière : la fenêtre ne met pas en pause, et un clic sur un cran
## l'applique tout de suite (`set_consignes`, sans bouton Confirmer). Seulement les consignes en direct du moteur
## (`live.pilotage.axes` sans pause) ; les plans de jeu (pause du match) restent dans la fenêtre Équipe.
## A : familles en liste à gauche (façon Effectif), trois cartes illustrées du cran à droite.
## B : les trois crans en lignes au-dessus (effets en colonnes + / −, grand croquis), rangée de cartes illustrées en bas.
## Effets : ordres de grandeur du moteur (dist/match-pilotage.js), rédigés en mots courts ; bilans, avis du staff et
## consignes adverses : projection du moteur, rien n'est calculé ici.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Charte = preload("res://ui/charte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")

const NOM := "MatchFenetreConsignes"
const LARGEUR := 1720.0
const HAUTEUR := 1010.0
## Une couleur franche par famille.
const FAMILLES := {"attaque": Color("e0a04a"), "defense": Color("5b9bd5"), "conquete": Color("a88bd6"), "adversaire": Color("4fb3a9")}
## Effets d'un cran : [signe, mots]. Signe 1 vert, -1 rouge, 0 neutre. Ordres de grandeur du moteur.
const EFFETS := {
	"piedJeu": {"moins": [[1, "Ballon gardé"], [-1, "Jeu au pied ×0,55"], [-1, "Moins de territoire"]], "normal": [[0, "Équilibre"]], "plus": [[1, "Jeu au pied ×1,55"], [1, "Territoire"], [-1, "Ballons rendus"]]},
	"rythme": {"lent": [[1, "Moins d’en-avant"], [1, "Moins d’usure"], [-1, "Avancée −2 %"]], "normal": [[0, "Équilibre"]], "rapide": [[1, "Avancée +2 %"], [-1, "En-avant"], [-1, "Usure des deux XV"]]},
	"relance": {"degager": [[1, "Pied ×1,4 chez nous"], [-1, "Ballon rendu"]], "selon": [[0, "Au choix du 10"]], "relancer": [[1, "Ballon à la main"], [-1, "Pied ×0,6 chez nous"], [-1, "Ballons perdus"]]},
	"finDeMatch": {"montre": [[1, "Ballon gardé"], [-1, "Pied ×0,6"], [0, "Dès 70′"]], "normal": [[0, "Sans effet"]], "tout": [[1, "Prise de risque"], [-1, "Ballons perdus"], [0, "Dès 70′"]]},
	"rucks": {"prudente": [[1, "Fautes ×0,85"], [-1, "Moins d’arrachés"]], "normale": [[0, "Équilibre"]], "agressive": [[1, "Ballons arrachés"], [-1, "Fautes ×1,22"], [-1, "Selon l’arbitre"]]},
	"discipline": {"stricte": [[1, "Fautes ×0,78"], [-1, "Défense moins mordante"]], "normale": [[0, "Équilibre"]], "limite": [[1, "Défense mordante"], [-1, "Fautes ×1,2"], [-1, "Cartons"]]},
	"touche": {"sure": [[1, "Touche +6 pts"], [-1, "Plateforme moyenne"]], "normale": [[0, "Équilibre"]], "risquee": [[1, "Plateforme idéale"], [-1, "Touche −6 pts"]]},
	"maul": {"jamais": [[1, "Ballon vite sorti"], [-1, "Essai porté −8 %"]], "selon": [[0, "Au choix du pack"]], "souvent": [[1, "Essai porté +7 %"], [-1, "Jeu prévisible"]]},
	"melee": {"vite": [[1, "Sifflets ×0,65"], [1, "Plateforme"]], "normale": [[0, "Équilibre"]], "pousser": [[1, "Pénalités si pack fort"], [-1, "Sifflets ×1,5"]]},
	"coupsEnvoi": {"longs": [[1, "Distance ×1,45"], [-1, "Récupération −7 %"]], "normaux": [[0, "Équilibre"]], "courts": [[1, "Récupération +12 %"], [-1, "Distance ×0,6"]]},
	"cible": {"aucune": [[0, "Sans effet"]], "aile": [[1, "Mètres sur leur aile"], [-1, "Adaptation 20-30′"]], "ouvreur": [[1, "Ballons perdus chez eux"], [-1, "Adaptation 20-30′"]]}}

## Consignes en direct du moteur (sans les plans de jeu qui demandent la pause), dans l'ordre des familles.
static func axes_directs(p: Dictionary) -> Array:
	return Pilotage.axes(p).filter(func(a: Variant) -> bool: return a is Dictionary and not bool(a.get("pause", false)) and EFFETS.has(str(a.get("id", ""))))

static func neutre(axe: Dictionary) -> String:
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	if str(axe.get("id", "")) == "cible": return "aucune"
	return str((options[1] as Dictionary).get("id", "")) if options.size() > 1 and options[1] is Dictionary else ""

static func libelle_cran(axe: Dictionary, valeur: String) -> String:
	for o: Variant in axe.get("options", []) if axe.get("options") is Array else []:
		if o is Dictionary and str(o.get("id", "")) == valeur: return str(o.get("label", valeur))
	return valeur

static func libelle_groupe(p: Dictionary, id: String) -> String:
	for g: Variant in p.get("groupes", []) if p.get("groupes") is Array else []:
		if g is Dictionary and str(g.get("id", "")) == id: return str(g.get("label", id))
	return id.capitalize()

## Cran proposé par le staff pour cet axe ("" sans avis).
static func staff_propose(p: Dictionary, axe: String) -> String:
	var staff: Dictionary = p.get("staff", {}) if p.get("staff") is Dictionary else {}
	for x: Variant in staff.get("propositions", []) if staff.get("propositions") is Array else []:
		if x is Dictionary and str(x.get("axe", "")) == axe: return str(x.get("valeur", ""))
	return ""

## Morceaux du bilan du moteur depuis le changement (« 2 pénalités », « 1 ballon arraché ») et sa minute.
static func bilan(p: Dictionary, axe: String) -> Dictionary:
	for b: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if b is Dictionary and str(b.get("axe", "")) == axe:
			var texte := str(b.get("texte", ""))
			var morceaux := texte.get_slice(" : ", 1).trim_suffix(".").split(", ", false) if texte.contains(" : ") else PackedStringArray()
			return {"depuis": b.get("depuis"), "morceaux": Array(morceaux)}
	return {}

## Construit le contenu dans `fond` (panneau de la petite fenêtre, unités du gabarit). `choisir(axe)` change l'axe
## montré ; `envoyer(axe, valeur)` applique un cran.
static func construire(fond: Control, p: Dictionary, variante: String, axe_vu: String, choisir: Callable, envoyer: Callable, minute: int) -> void:
	var axes := axes_directs(p)
	if axes.is_empty():
		D.text(fond, 40, 140, "—", 40, Charte.IVOIRE_3)
		return
	var axe: Dictionary = axes[0]
	for a: Variant in axes:
		if str((a as Dictionary).get("id", "")) == axe_vu: axe = a
	# Minute du match : le match continue derrière.
	var x_min := LARGEUR - 230.0
	Pieces.pastille(fond, x_min, 26, "%d′ · en jeu" % minute, "clock", "MatchFenetreConsignesMinute", "", Charte.GAIN, Charte.PANNEAU_3)
	if variante == "B": _variante_b(fond, p, axes, axe, choisir, envoyer)
	else: _variante_a(fond, p, axes, axe, choisir, envoyer)

# --- Option A : familles en liste à gauche, trois cartes illustrées à droite ------------------------------------

static func _variante_a(fond: Control, p: Dictionary, axes: Array, axe: Dictionary, choisir: Callable, envoyer: Callable) -> void:
	var y := 84.0
	var groupe := ""
	var L := 520.0
	for a_v: Variant in axes:
		var a: Dictionary = a_v
		var g := str(a.get("groupe", ""))
		var teinte: Color = FAMILLES.get(g, Charte.IVOIRE)
		if g != groupe:
			groupe = g
			D.rect(fond, Rect2(28, y + 10, 6, 22), teinte, 3)
			var titre := D.text(fond, 44, y + 30, libelle_groupe(p, g).to_upper(), 18, teinte, 800, 300)
			titre.add_theme_font_override("font", Charte.TITRE_EXTRA)
			y += 40.0
		var id := str(a.get("id", ""))
		var vu := id == str(axe.get("id", ""))
		var ligne := D.rect(fond, Rect2(28, y, L, 60), Charte.SELECTION if vu else Color.TRANSPARENT, Charte.RAYON_PETIT)
		ligne.name = "MatchFenetreConsignesAxe_" + id
		if vu: D.rect(ligne, Rect2(0, 0, 5, 60), teinte, 2)
		var croquis := Croquis.new()
		croquis.axe = id
		croquis.valeur = Pilotage.cran(p, a)
		croquis.mini = true
		ligne.add_child(croquis)
		D.place(croquis, Rect2(14, 8, 66, 44))
		D.text(ligne, 96, 39, str(a.get("label", "")), 22, Charte.IVOIRE, 700, 220)
		var cran := Pilotage.cran(p, a)
		var actif := cran != neutre(a)
		var mot := libelle_cran(a, cran)
		var largeur := Pieces.largeur_pastille(mot)
		Pieces.pastille(ligne, L - 14 - largeur, 13, mot, "", "MatchFenetreConsignesCran_" + id, "", Charte.DORE if actif else Charte.IVOIRE_2, Charte.PANNEAU_3)
		if staff_propose(p, id) != "" and staff_propose(p, id) != cran:
			D.rect(ligne, Rect2(L - 26 - largeur, 22, 10, 10), Charte.GAIN, 5).tooltip_text = "Avis du staff"
		Pieces.rendre_cliquable(ligne, Vector2(L, 60), func(): choisir.call(id), "MatchFenetreConsignesAxeLien_" + id, str(a.get("label", "")), "", Charte.RAYON_PETIT)
		y += 62.0
	# Droite : l'axe choisi.
	var x0 := 580.0
	var W := LARGEUR - x0 - 28.0
	var id := str(axe.get("id", ""))
	var teinte: Color = FAMILLES.get(str(axe.get("groupe", "")), Charte.IVOIRE)
	var titre := D.text(fond, x0, 128, str(axe.get("label", "")).to_upper(), 44, Charte.IVOIRE, 800, 560)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "MatchFenetreConsignesTitreAxe"
	var px := x0 + 560.0
	px += Pieces.pastille(fond, px, 94, libelle_groupe(p, str(axe.get("groupe", ""))), "", "MatchFenetreConsignesFamille", "", teinte, Charte.PANNEAU_3) + 10.0
	_pastille_adverse(fond, p, axe, px, 94)
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var cran := Pilotage.cran(p, axe)
	var propose := staff_propose(p, id)
	var lc := (W - 2 * 20.0) / 3.0
	for k in options.size():
		var o: Dictionary = options[k]
		var v := str(o.get("id", ""))
		var en_place := v == cran
		var xc := x0 + k * (lc + 20.0)
		var carte := D.rect(fond, Rect2(xc, 160, lc, 560), Charte.PANNEAU_2.lerp(teinte, .10) if en_place else Charte.PANNEAU_2, Charte.RAYON_CARTE, Charte.DORE if en_place else Color.TRANSPARENT)
		carte.name = "MatchFenetreConsignesCarte_%s" % v
		var dessin := Croquis.new()
		dessin.axe = id
		dessin.valeur = v
		carte.add_child(dessin)
		D.place(dessin, Rect2(14, 14, lc - 28, 230))
		var nom := D.text(carte, 22, 300, str(o.get("label", "")).to_upper(), 34, Charte.DORE if en_place else Charte.IVOIRE, 800, lc - 44)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA)
		var py := 324.0
		if en_place: py += Pieces.pastille(carte, 22, py, "En place", "check", "MatchFenetreConsignesEnPlace", "", Charte.DORE, Charte.PANNEAU_3) * 0.0 + 46.0
		if propose == v and not en_place: py += Pieces.pastille(carte, 22, py, "Le staff", "people", "MatchFenetreConsignesStaff_" + v, "", Charte.GAIN, Charte.PANNEAU_3) * 0.0 + 46.0
		_lignes_effets(carte, EFFETS.get(id, {}).get(v, []), 22, py + 8, lc - 44)
		Pieces.rendre_cliquable(carte, Vector2(lc, 560), func(): envoyer.call(id, v), "MatchFenetreConsignesChoix_" + v, str(o.get("label", "")), "", Charte.RAYON_CARTE)
	# Bas : bilan du moteur depuis le changement, puis les avis du staff (un clic les applique).
	_bandeau_bilan(fond, p, axe, x0, 748, W)
	_avis_staff(fond, p, x0, 850, W, envoyer, choisir)

# --- Option B : crans en lignes + grand croquis au-dessus, rangée de cartes illustrées en bas --------------------

static func _variante_b(fond: Control, p: Dictionary, axes: Array, axe: Dictionary, choisir: Callable, envoyer: Callable) -> void:
	var id := str(axe.get("id", ""))
	var teinte: Color = FAMILLES.get(str(axe.get("groupe", "")), Charte.IVOIRE)
	var x0 := 28.0
	var titre := D.text(fond, x0, 128, str(axe.get("label", "")).to_upper(), 44, Charte.IVOIRE, 800, 520)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "MatchFenetreConsignesTitreAxe"
	var px := x0 + 520.0
	px += Pieces.pastille(fond, px, 94, libelle_groupe(p, str(axe.get("groupe", ""))), "", "MatchFenetreConsignesFamille", "", teinte, Charte.PANNEAU_3) + 10.0
	_pastille_adverse(fond, p, axe, px, 94)
	var Lg := 1000.0
	# En-têtes de colonnes façon Effectif.
	for entete: Array in [["CRAN", 70.0], ["POUR", 380.0], ["CONTRE", 690.0]]:
		D.text(fond, x0 + float(entete[1]), 170, entete[0], 15, Charte.IVOIRE_3, 700, 200)
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var cran := Pilotage.cran(p, axe)
	var propose := staff_propose(p, id)
	var y := 184.0
	for o_v: Variant in options:
		var o: Dictionary = o_v
		var v := str(o.get("id", ""))
		var en_place := v == cran
		var ligne := D.rect(fond, Rect2(x0, y, Lg, 132), Charte.SELECTION if en_place else Charte.PANNEAU_2, Charte.RAYON_PETIT)
		ligne.name = "MatchFenetreConsignesLigne_" + v
		if en_place: D.rect(ligne, Rect2(0, 0, 6, 132), Charte.DORE, 3)
		# Rond du choix (plein = en place).
		D.rect(ligne, Rect2(24, 48, 30, 30), Charte.DORE if en_place else Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.DORE if en_place else Charte.IVOIRE_3)
		var nom := D.text(ligne, 70, 62, str(o.get("label", "")).to_upper(), 34, Charte.DORE if en_place else Charte.IVOIRE, 800, 290)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA)
		if en_place: Pieces.pastille(ligne, 70, 80, "En place", "check", "MatchFenetreConsignesEnPlace", "", Charte.DORE, Charte.PANNEAU_3)
		elif propose == v: Pieces.pastille(ligne, 70, 80, "Le staff", "people", "MatchFenetreConsignesStaff_" + v, "", Charte.GAIN, Charte.PANNEAU_3)
		var effets: Array = EFFETS.get(id, {}).get(v, [])
		_lignes_effets(ligne, effets.filter(func(e: Array) -> bool: return int(e[0]) >= 0), 380, 22, 290)
		_lignes_effets(ligne, effets.filter(func(e: Array) -> bool: return int(e[0]) < 0), 690, 22, 290)
		Pieces.rendre_cliquable(ligne, Vector2(Lg, 132), func(): envoyer.call(id, v), "MatchFenetreConsignesChoix_" + v, str(o.get("label", "")), "", Charte.RAYON_PETIT)
		y += 142.0
	# Grand croquis du cran en place, bilan dessous.
	var xd := x0 + Lg + 24.0
	var Wd := LARGEUR - xd - 28.0
	var cadre := D.rect(fond, Rect2(xd, 150, Wd, 410), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreConsignesTerrain"
	var dessin := Croquis.new()
	dessin.axe = id
	dessin.valeur = cran
	cadre.add_child(dessin)
	D.place(dessin, Rect2(18, 18, Wd - 44, 328))
	D.text(cadre, 22, 388, libelle_cran(axe, cran).to_upper(), 26, Charte.DORE, 800, Wd - 44).add_theme_font_override("font", Charte.TITRE_EXTRA)
	_bandeau_bilan(fond, p, axe, xd, 576, Wd)
	# Rangée de cartes illustrées : une par consigne, la famille en liseré, le cran en place dessous.
	var n := axes.size()
	var ecart := 8.0
	var lc := (LARGEUR - 56.0 - (n - 1) * ecart) / float(n)
	var yb := 700.0
	for i in n:
		var a: Dictionary = axes[i]
		var ida := str(a.get("id", ""))
		var vu := ida == id
		var t: Color = FAMILLES.get(str(a.get("groupe", "")), Charte.IVOIRE)
		var xc := 28.0 + i * (lc + ecart)
		var carte := D.rect(fond, Rect2(xc, yb, lc, 270), Charte.PANNEAU_3 if vu else Charte.PANNEAU_2, Charte.RAYON_CARTE, t if vu else Color.TRANSPARENT)
		carte.name = "MatchFenetreConsignesCarteAxe_" + ida
		D.rect(carte, Rect2(0, 0, lc, 8), t, 4)
		var titre_c := D.text(carte, lc / 2.0, 44, str(a.get("label", "")).to_upper(), 18, t, 800, lc - 16, HORIZONTAL_ALIGNMENT_CENTER)
		titre_c.add_theme_font_override("font", Charte.TITRE_EXTRA)
		var c := Croquis.new()
		c.axe = ida
		c.valeur = Pilotage.cran(p, a)
		c.mini = true
		carte.add_child(c)
		D.place(c, Rect2(10, 60, lc - 20, 130))
		var v := Pilotage.cran(p, a)
		var actif := v != neutre(a)
		D.text(carte, lc / 2.0, 236, libelle_cran(a, v), 21, Charte.DORE if actif else Charte.IVOIRE_2, 700, lc - 16, HORIZONTAL_ALIGNMENT_CENTER)
		if staff_propose(p, ida) != "" and staff_propose(p, ida) != v:
			D.rect(carte, Rect2(lc - 22, 18, 12, 12), Charte.GAIN, 6).tooltip_text = "Avis du staff"
		Pieces.rendre_cliquable(carte, Vector2(lc, 270), func(): choisir.call(ida), "MatchFenetreConsignesAxeLien_" + ida, str(a.get("label", "")), "", Charte.RAYON_CARTE)

# --- Pièces communes ---------------------------------------------------------------------------------------------

## Lignes + / − : signe en rond coloré, mots courts.
static func _lignes_effets(parent: Control, effets: Array, x: float, y: float, largeur: float) -> void:
	for e_v: Variant in effets:
		var e: Array = e_v
		var s := int(e[0])
		var teinte: Color = Charte.GAIN if s > 0 else (Charte.PERTE if s < 0 else Charte.IVOIRE_3)
		var rond := D.rect(parent, Rect2(x, y, 28, 28), Color(teinte, .22), Charte.RAYON_PILULE)
		D.text(rond, 14, 22, "+" if s > 0 else ("−" if s < 0 else "="), 22, teinte, 800, 28, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(parent, x + 38, y + 22, str(e[1]), 21, Charte.IVOIRE if s != 0 else Charte.IVOIRE_2, 600, largeur - 38)
		y += 36.0

## Pastille de la consigne adverse sur cet axe (ce que son jeu laisse voir), seulement si elle n'est pas neutre.
static func _pastille_adverse(fond: Control, p: Dictionary, axe: Dictionary, x: float, y: float) -> void:
	var adv: Dictionary = p.get("adversaire", {}) if p.get("adversaire") is Dictionary else {}
	var consignes: Dictionary = adv.get("consignes", {}) if adv.get("consignes") is Dictionary else {}
	var v := str(consignes.get(str(axe.get("id", "")), ""))
	if v.is_empty() or v == neutre(axe): return
	Pieces.pastille(fond, x, y, "Eux : " + libelle_cran(axe, v), "shield", "MatchFenetreConsignesAdverse", "", Charte.DORE, Charte.PANNEAU_3)

## Bilan depuis le changement : « depuis 41′ » puis un chiffre par morceau, en tuiles.
static func _bandeau_bilan(fond: Control, p: Dictionary, axe: Dictionary, x: float, y: float, largeur: float) -> void:
	var b := bilan(p, str(axe.get("id", "")))
	if b.is_empty():
		var vide := D.text(fond, x, y + 50, "BILAN · —", 18, Charte.IVOIRE_3, 700, largeur)
		vide.name = "MatchFenetreConsignesBilanVide"
		return
	var morceaux: Array = b.get("morceaux", [])
	var n := morceaux.size() + 1
	var l := (largeur - (n - 1) * 12.0) / float(n)
	Pieces.tuile(fond, Rect2(x, y, l, 90), "%d′" % int(b.get("depuis", 0)), "depuis", Charte.DORE, "MatchFenetreConsignesBilanDepuis", 34, "", "clock")
	for i in morceaux.size():
		var m := str(morceaux[i])
		var chiffre := m.get_slice(" ", 0)
		var reste := m.substr(chiffre.length()).strip_edges()
		var mauvais := (reste.contains("pénalité") and not reste.contains("adverse")) or (reste.contains("perdu") and not reste.contains("chez eux")) or reste.contains("carton") or reste.contains("encaissé")
		Pieces.tuile(fond, Rect2(x + (i + 1) * (l + 12.0), y, l, 90), chiffre, reste, Charte.PERTE if mauvais and chiffre != "0" else Charte.GAIN, "MatchFenetreConsignesBilan%d" % i, 34)

## Avis du staff en attente (projection `staff.propositions`) : une pastille par proposition, un clic l'applique.
static func _avis_staff(fond: Control, p: Dictionary, x: float, y: float, largeur: float, envoyer: Callable, choisir: Callable) -> void:
	var staff: Dictionary = p.get("staff", {}) if p.get("staff") is Dictionary else {}
	var props: Array = staff.get("propositions", []) if staff.get("propositions") is Array else []
	var titre := D.text(fond, x, y + 26, "LE STAFF", 18, Charte.GAIN, 800, 160)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA)
	var px := x + 120.0
	if props.is_empty():
		D.text(fond, px, y + 26, "—", 20, Charte.IVOIRE_3, 600, 100)
		return
	for x_v: Variant in props:
		if not x_v is Dictionary: continue
		var prop: Dictionary = x_v
		var axe := str(prop.get("axe", ""))
		var valeur := str(prop.get("valeur", ""))
		var mot := "%s → %s" % [str(prop.get("label", "")), str(prop.get("valeurLabel", ""))]
		if px + Pieces.largeur_pastille(mot, "people") > x + largeur: break
		px += Pieces.pastille(fond, px, y, mot, "people", "MatchFenetreConsignesAvis_" + axe, "", Charte.GAIN, Charte.PANNEAU_3, func():
			choisir.call(axe)
			envoyer.call(axe, valeur)) + 10.0

## Croquis rugby d'une consigne : petit terrain vu de dessus (nous attaquons vers la droite), nos joueurs en vert
## clair, les leurs en doré, le ballon en crème, flèches du geste. `mini` : vignette (moins de traits).
class Croquis extends Control:
	var axe := ""
	var valeur := ""
	var mini := false
	const NOUS := Color("b6d6b6")
	const EUX := Color("d7aa5a")
	const BALLON := Color("f2ecdc")
	const FLECHE := Color("f2ecdc")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		resized.connect(queue_redraw)

	func P(x: float, y: float) -> Vector2:
		return Vector2(x * size.x, y * size.y)

	func joueur(x: float, y: float, c: Color) -> void:
		var r := maxf(3.0, size.y * (0.035 if not mini else 0.07))
		draw_circle(P(x, y), r, c)
		draw_circle(P(x, y), r, Color(0, 0, 0, .35), false, 1.0)

	func ballon(x: float, y: float) -> void:
		var r := maxf(2.5, size.y * (0.025 if not mini else 0.05))
		draw_set_transform(P(x, y), -0.5, Vector2(1.5, 1.0))
		draw_circle(Vector2.ZERO, r, BALLON)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func fleche(a: Vector2, b: Vector2, c: Color = FLECHE, pointille := false, courbe := 0.0) -> void:
		var e := maxf(1.5, size.y * (0.012 if not mini else 0.03))
		var pa := P(a.x, a.y)
		var pb := P(b.x, b.y)
		var pts := PackedVector2Array()
		var milieu := (pa + pb) / 2.0 + (pb - pa).orthogonal().normalized() * courbe * size.y
		for i in 17:
			var t := i / 16.0
			pts.append(pa.lerp(milieu, t).lerp(milieu.lerp(pb, t), t))
		if pointille:
			for i in range(0, 16, 2): draw_line(pts[i], pts[i + 1], c, e, true)
		else: draw_polyline(pts, c, e, true)
		var dir := (pts[16] - pts[14]).normalized()
		var t2 := maxf(6.0, size.y * (0.05 if not mini else 0.1))
		draw_colored_polygon(PackedVector2Array([pb, pb - dir * t2 + dir.orthogonal() * t2 * .55, pb - dir * t2 - dir.orthogonal() * t2 * .55]), c)

	func _draw() -> void:
		if size.x < 4: return
		var rayon := 6.0 if mini else 10.0
		var herbe := StyleBoxFlat.new()
		herbe.bg_color = Color("1d4631")
		herbe.set_corner_radius_all(int(rayon))
		draw_style_box(herbe, Rect2(Vector2.ZERO, size))
		var craie := Color(1, 1, 1, .28 if mini else .35)
		var e := 1.0 if mini else 2.0
		if not mini:
			for k in 6: draw_rect(Rect2(P(0.06 + k * 0.176, 0), Vector2(size.x * 0.088, size.y)), Color("214e37"))
		for x: float in [0.06, 0.94]: draw_line(P(x, 0.04), P(x, 0.96), craie, e)
		draw_line(P(0.5, 0.04), P(0.5, 0.96), craie, e)
		if not mini:
			for x: float in [0.236, 0.764]: draw_line(P(x, 0.04), P(x, 0.96), Color(craie, .2), e)
			for x: float in [0.412, 0.588]:
				for k in 8: draw_line(P(x, 0.08 + k * 0.115), P(x, 0.13 + k * 0.115), Color(craie, .2), e)
		draw_rect(Rect2(P(0.02, 0.04), P(0.96, 0.92)), craie, false, e)
		var dessin := "_" + axe
		if has_method(dessin): call(dessin)

	# Jeu au pied : passes courtes (garder) ou grandes chandelles / coups de pied d'occupation.
	func _piedJeu() -> void:
		for k in 4: joueur(0.28 + k * 0.08, 0.35 + k * 0.1, NOUS)
		for k in 4: joueur(0.62 + k * 0.06, 0.2 + k * 0.2, EUX)
		ballon(0.28, 0.35)
		if valeur == "moins":
			for k in 3: fleche(Vector2(0.29 + k * 0.08, 0.37 + k * 0.1), Vector2(0.35 + k * 0.08, 0.44 + k * 0.1))
		elif valeur == "plus": fleche(Vector2(0.3, 0.35), Vector2(0.86, 0.3), FLECHE, true, -0.35)
		else:
			fleche(Vector2(0.29, 0.37), Vector2(0.35, 0.44))
			fleche(Vector2(0.36, 0.45), Vector2(0.66, 0.6), FLECHE, true, -0.2)

	# Rythme : une, deux ou trois vagues de temps de jeu.
	func _rythme() -> void:
		var n := 1 if valeur == "lent" else (3 if valeur == "rapide" else 2)
		for k in 5: joueur(0.68, 0.12 + k * 0.19, EUX)
		for k in n:
			var x := 0.22 + k * 0.13
			joueur(x, 0.5, NOUS)
			fleche(Vector2(x + 0.02, 0.5), Vector2(x + 0.11, 0.5 - 0.06 * (k % 2 * 2 - 1)), Charte.GAIN if valeur == "rapide" else FLECHE)
		ballon(0.22, 0.5)

	# Relance depuis notre camp : dégagement au pied ou course ballon en main.
	func _relance() -> void:
		joueur(0.14, 0.55, NOUS)
		joueur(0.2, 0.35, NOUS)
		ballon(0.14, 0.55)
		for k in 4: joueur(0.5 + k * 0.03, 0.2 + k * 0.2, EUX)
		if valeur == "degager": fleche(Vector2(0.15, 0.53), Vector2(0.58, 0.04), FLECHE, true, -0.15)
		elif valeur == "relancer":
			fleche(Vector2(0.16, 0.55), Vector2(0.42, 0.6))
			fleche(Vector2(0.21, 0.36), Vector2(0.4, 0.4), Color(FLECHE, .6))
		else:
			fleche(Vector2(0.15, 0.53), Vector2(0.45, 0.08), FLECHE, true, -0.12)
			fleche(Vector2(0.16, 0.57), Vector2(0.32, 0.62), Color(FLECHE, .6))

	# Fin de match : garder le ballon en grappes (montre) ou tout envoyer au large.
	func _finDeMatch() -> void:
		for k in 5: joueur(0.7, 0.12 + k * 0.19, EUX)
		if valeur == "montre":
			for k in 4: joueur(0.42 + (k % 2) * 0.04, 0.45 + int(k / 2.0) * 0.1, NOUS)
			ballon(0.44, 0.5)
			draw_arc(P(0.44, 0.5), size.y * 0.22, 0.3, TAU - 0.3, 24, FLECHE, maxf(1.5, size.y * 0.012))
		else:
			for k in 5: joueur(0.4 + k * 0.03, 0.15 + k * 0.17, NOUS)
			ballon(0.4, 0.15)
			fleche(Vector2(0.42, 0.18), Vector2(0.62, 0.7), Charte.GAIN if valeur == "tout" else FLECHE)
			if valeur == "tout": fleche(Vector2(0.55, 0.85), Vector2(0.9, 0.85), Charte.GAIN)

	# Rucks : la pile au centre, nos défenseurs restent en ligne (prudence) ou plongent dedans (contester).
	func _rucks() -> void:
		joueur(0.48, 0.5, EUX)
		joueur(0.46, 0.44, EUX)
		ballon(0.45, 0.52)
		var plonge := 3 if valeur == "agressive" else (1 if valeur == "normale" else 0)
		for k in 5:
			var y := 0.12 + k * 0.19
			if k >= 1 and k <= plonge:
				joueur(0.58, y, NOUS)
				fleche(Vector2(0.57, y), Vector2(0.5, 0.48 + (y - 0.48) * 0.3), Charte.PERTE if valeur == "agressive" else FLECHE)
			else: joueur(0.6, y, NOUS)

	# Discipline : ligne de défense à distance de la ligne de hors-jeu, ou tout contre.
	func _discipline() -> void:
		joueur(0.4, 0.5, EUX)
		ballon(0.41, 0.53)
		var hors_jeu := 0.46
		for k in 9: draw_line(P(hors_jeu, 0.08 + k * 0.1), P(hors_jeu, 0.12 + k * 0.1), Charte.PERTE, maxf(1.5, size.y * 0.012))
		var x := 0.58 if valeur == "stricte" else (0.47 if valeur == "limite" else 0.52)
		for k in 5:
			joueur(x, 0.12 + k * 0.19, NOUS)
			if valeur == "limite": fleche(Vector2(x - 0.01, 0.12 + k * 0.19), Vector2(x - 0.06, 0.12 + k * 0.19), Charte.PERTE)

	# Touche : l'alignement le long de la ligne, lancer court (sûr) ou en fond d'alignement (risqué).
	func _touche() -> void:
		joueur(0.6, 0.06, NOUS)
		ballon(0.6, 0.06)
		for k in 6:
			joueur(0.58, 0.2 + k * 0.11, NOUS)
			joueur(0.63, 0.2 + k * 0.11, EUX)
		var cible := 0.22 if valeur == "sure" else (0.75 if valeur == "risquee" else 0.46)
		fleche(Vector2(0.61, 0.08), Vector2(0.585, cible), Charte.GAIN if valeur == "sure" else (Charte.DORE if valeur == "risquee" else FLECHE), false, 0.05)

	# Ballon porté : le paquet pousse vers leur ligne, ou le ballon sort vite vers les trois-quarts.
	func _maul() -> void:
		for k in 6: joueur(0.78 + (k % 3) * 0.025, 0.42 + int(k / 3.0) * 0.1, NOUS)
		for k in 4: joueur(0.86, 0.36 + k * 0.08, EUX)
		ballon(0.77, 0.5)
		if valeur == "souvent": fleche(Vector2(0.84, 0.47), Vector2(0.95, 0.47), Charte.GAIN)
		elif valeur == "jamais": fleche(Vector2(0.76, 0.52), Vector2(0.56, 0.85), FLECHE, true)
		else:
			fleche(Vector2(0.84, 0.47), Vector2(0.92, 0.47))
			fleche(Vector2(0.76, 0.52), Vector2(0.62, 0.8), Color(FLECHE, .5), true)

	# Mêlée : deux paquets face à face ; pousser (grosse flèche) ou sortir vite vers le 9.
	func _melee() -> void:
		for k in 8: joueur(0.4 + int(k / 3.0) * 0.035, 0.4 + (k % 3) * 0.1, NOUS)
		for k in 8: joueur(0.52 + int(k / 3.0) * 0.035, 0.4 + (k % 3) * 0.1, EUX)
		ballon(0.5, 0.5)
		if valeur == "pousser": fleche(Vector2(0.34, 0.5), Vector2(0.6, 0.5), Charte.DORE)
		elif valeur == "vite":
			joueur(0.42, 0.78, NOUS)
			fleche(Vector2(0.49, 0.56), Vector2(0.43, 0.75), Charte.GAIN)
		else: fleche(Vector2(0.34, 0.5), Vector2(0.46, 0.5))

	# Coups d'envoi : court vers les 10 m pour reprendre le ballon, ou long pour occuper.
	func _coupsEnvoi() -> void:
		joueur(0.5, 0.5, NOUS)
		ballon(0.5, 0.5)
		for k in 4: joueur(0.47 + k * 0.01, 0.15 + k * 0.23, NOUS)
		for k in 5: joueur(0.7 + (k % 2) * 0.12, 0.12 + k * 0.19, EUX)
		var arrivee := Vector2(0.62, 0.25) if valeur == "courts" else (Vector2(0.88, 0.5) if valeur == "longs" else Vector2(0.75, 0.35))
		fleche(Vector2(0.51, 0.48), arrivee, Charte.GAIN if valeur == "courts" else FLECHE, true, -0.2)

	# Point faible : leur aile la plus faible (en rouge) ou leur ouvreur pressé ; sans cible, défense à plat.
	func _cible() -> void:
		for k in 5: joueur(0.4, 0.12 + k * 0.19, NOUS)
		joueur(0.62, 0.5, EUX)
		joueur(0.66, 0.3, EUX)
		joueur(0.66, 0.7, EUX)
		joueur(0.75, 0.1, EUX)
		joueur(0.75, 0.9, Charte.PERTE if valeur == "aile" else EUX)
		if valeur == "aile": fleche(Vector2(0.42, 0.88), Vector2(0.72, 0.9), Charte.GAIN)
		elif valeur == "ouvreur":
			draw_arc(P(0.62, 0.5), size.y * 0.1, 0, TAU, 24, Charte.PERTE, maxf(1.5, size.y * 0.012))
			for y: float in [0.31, 0.5, 0.69]: fleche(Vector2(0.42, y), Vector2(0.58, 0.5 + (y - 0.5) * 0.3), Charte.GAIN)
