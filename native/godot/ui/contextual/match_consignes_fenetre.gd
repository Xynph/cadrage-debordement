extends RefCounted
## Petite fenêtre des consignes pendant le match (idée FM27 n° 33, choix de Léo du 23/11/2026 : la planche B).
## Le match continue derrière : la fenêtre ne met jamais en pause. Les 11 consignes en direct ET le plan de jeu
## (attaque, système de défense, pénalités) : un clic sur un cran le choisit et le met dans la file du prochain arrêt de
## jeu du moteur (`set_consignes` → native/engine/match-arrets.cjs), sans bouton Confirmer ; « ⧗ PROCHAIN ARRÊT »
## signale le cran qui attend. Un clic sur le cran en place retire la demande.
## Même taille et même ardoise claire que la fenêtre d'un joueur (idée 32). Haut : les crans de la consigne vue en
## lignes (colonnes Pour / Contre), croquis du cran à droite, bilan du moteur dessous ; bas : cartes illustrées, une par
## consigne, sur deux rangées.
## Pour / Contre : l'avis du staff EN TENDANCE (`pilotage.avisCrans`, dist/match-pilotage.js) : ▲▲ net, ▲ léger, ? il
## ne sait pas ; sa justesse dépend de sa compétence, jamais de chiffre (principe d'incertitude). Bilans, avis du staff
## et consignes adverses : projection du moteur, rien n'est calculé ici.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Charte = preload("res://ui/charte.gd")
const Pilotage = preload("res://ui/contextual/match_consignes.gd")
const MenuJoueur = preload("res://ui/contextual/match_menu_joueur.gd")

const NOM := "MatchFenetreConsignes"
## Même taille et même cadre que la fenêtre d'un joueur en match (idée 32) : ardoise claire, environ deux tiers.
const LARGEUR := MenuJoueur.LARGEUR
const HAUTEUR := MenuJoueur.HAUTEUR
const PAL := MenuJoueur.PAL
## Une couleur franche par famille.
const FAMILLES := {"attaque": Color("e0a04a"), "defense": Color("5b9bd5"), "conquete": Color("a88bd6"), "adversaire": Color("4fb3a9")}
## Fiabilité de la lecture du staff (un mot, jamais son niveau).
const FIABILITE := {"fiable": ["Staff fiable", Color("7fbf7a")], "correct": ["Staff correct", Color("d8dcd3")], "approximatif": ["Staff approximatif", Color("e0a04a")]}
## Libellés courts des cartes de la rangée (14 cartes).
const COURTS := {"planAttaque": "Plan de jeu", "systemeDefense": "Défense", "coupsEnvoi": "Coups d’envoi", "finDeMatch": "Fin de match"}

## Toutes les consignes réglables en direct (plan de jeu compris), dans l'ordre des familles.
static func axes_directs(p: Dictionary) -> Array:
	return Pilotage.axes(p).filter(func(a: Variant) -> bool: return a is Dictionary and a.get("options") is Array and (a.get("options") as Array).size() > 0)

static func neutre(axe: Dictionary) -> String:
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	match str(axe.get("id", "")):
		"cible": return "aucune"
		"planAttaque", "systemeDefense": return "equilibre"
		"penalites": return "auto"
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

## Cran demandé pour cet axe et pas encore appliqué (file du prochain arrêt de jeu), "" sinon.
static func en_attente(p: Dictionary, axe: String) -> String:
	var a: Variant = p.get("arrets")
	var file: Variant = a.get("file") if a is Dictionary else null
	for e: Variant in file if file is Array else []:
		if e is Dictionary and str(e.get("type", "")) == "consigne" and str(e.get("axe", "")) == axe: return str(e.get("valeur", ""))
	return ""

## Avis du staff sur un cran : {pour: [{mot, force}], contre: […], neutre: [mot]} ({} sans avis).
static func avis(p: Dictionary, axe: String, valeur: String) -> Dictionary:
	var a: Variant = p.get("avisCrans")
	var axes: Variant = a.get("axes") if a is Dictionary else null
	var crans: Variant = axes.get(axe) if axes is Dictionary else null
	var r: Variant = crans.get(valeur) if crans is Dictionary else null
	return r if r is Dictionary else {}

## Morceaux du bilan du moteur depuis le changement (« 2 pénalités », « 1 ballon arraché ») et sa minute.
static func bilan(p: Dictionary, axe: String) -> Dictionary:
	for b: Variant in p.get("bilans", []) if p.get("bilans") is Array else []:
		if b is Dictionary and str(b.get("axe", "")) == axe:
			var texte := str(b.get("texte", ""))
			var morceaux := texte.get_slice(" : ", 1).trim_suffix(".").split(", ", false) if texte.contains(" : ") else PackedStringArray()
			return {"depuis": b.get("depuis"), "morceaux": Array(morceaux)}
	return {}

## Empreinte de ce que montre la fenêtre : la veille la redessine quand le moteur y change quelque chose.
static func signature(p: Dictionary, minute: int) -> String:
	var a: Variant = p.get("arrets")
	var file: Array = []
	for e: Variant in a.get("file", []) if a is Dictionary and a.get("file") is Array else []:
		if e is Dictionary and str(e.get("type", "")) == "consigne": file.append([e.get("axe"), e.get("valeur")])
	var staff: Variant = p.get("staff")
	var adv: Variant = p.get("adversaire")
	return JSON.stringify([minute, p.get("consignes"), axes_directs(p).map(func(x: Dictionary): return x.get("valeur")), file, p.get("bilans"),
		staff.get("propositions") if staff is Dictionary else null, adv.get("consignes") if adv is Dictionary else null])

## Construit le contenu dans `fond` (panneau de la petite fenêtre, unités du gabarit). `choisir(axe)` change l'axe
## montré ; `envoyer(axe, valeur)` demande un cran (file du prochain arrêt).
static func construire(fond: Control, p: Dictionary, axe_vu: String, choisir: Callable, envoyer: Callable, minute: int) -> void:
	var axes := axes_directs(p)
	if axes.is_empty():
		D.text(fond, 40, 100, "—", 34, PAL.encre3)
		return
	var axe: Dictionary = axes[0]
	for a: Variant in axes:
		if str((a as Dictionary).get("id", "")) == axe_vu: axe = a
	# Minute du match (il continue derrière) et fiabilité de la lecture du staff, à gauche de la croix.
	var x := LARGEUR - 92.0
	x -= _puce(fond, x, 30, "%d′ · en jeu" % minute, Charte.GAIN, "MatchFenetreConsignesMinute", true) + 10.0
	var fiab: Variant = (p.get("avisCrans") as Dictionary).get("fiabilite") if p.get("avisCrans") is Dictionary else null
	if fiab != null and FIABILITE.has(str(fiab)):
		var f: Array = FIABILITE[str(fiab)]
		_puce(fond, x, 30, str(f[0]), f[1], "MatchFenetreConsignesFiabilite", true)
	_haut(fond, p, axe, envoyer)
	_rangee(fond, p, axes, axe, choisir)

# --- Haut : les crans de la consigne vue en lignes, croquis, bilan -------------------------------------------------

static func _haut(fond: Control, p: Dictionary, axe: Dictionary, envoyer: Callable) -> void:
	var id := str(axe.get("id", ""))
	var teinte: Color = FAMILLES.get(str(axe.get("groupe", "")), PAL.encre)
	var x0 := 28.0
	var titre := D.text(fond, x0, 64, str(axe.get("label", "")).to_upper(), 34, PAL.encre, 800, 330)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "MatchFenetreConsignesTitreAxe"
	var px := x0 + 340.0
	px += _puce(fond, px, 32, libelle_groupe(p, str(axe.get("groupe", ""))), teinte, "MatchFenetreConsignesFamille") + 8.0
	_pastille_adverse(fond, p, axe, px, 32)
	var Lg := 700.0
	# En-têtes de colonnes façon Effectif.
	for entete: Array in [["CRAN", 44.0], ["POUR", 250.0], ["CONTRE", 476.0]]:
		D.text(fond, x0 + float(entete[1]), 98, entete[0], 14, PAL.encre3, 700, 160)
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	var cran := Pilotage.cran(p, axe)
	var attente := en_attente(p, id)
	var propose := staff_propose(p, id)
	var n := maxi(1, options.size())
	var ecart := 8.0
	var h := minf(96.0, (300.0 - (n - 1) * ecart) / float(n))
	var y := 106.0
	for o_v: Variant in options:
		var o: Dictionary = o_v
		var v := str(o.get("id", ""))
		var en_place := v == cran
		var voulu := v == attente
		var ligne := D.rect(fond, Rect2(x0, y, Lg, h), PAL.choisi if en_place else PAL.case, Charte.RAYON_PETIT, Charte.DORE if voulu else Color.TRANSPARENT)
		ligne.name = "MatchFenetreConsignesLigne_" + v
		if en_place: D.rect(ligne, Rect2(0, 0, 5, h), Charte.DORE, 3)
		# Rond du choix : plein = en place, cerclé d'or = demandé pour le prochain arrêt.
		D.rect(ligne, Rect2(14, h / 2.0 - 11.0, 22, 22), Charte.DORE if en_place else Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.DORE if en_place or voulu else PAL.encre3)
		var etat := voulu or en_place or propose == v
		var nom := D.text(ligne, 44, h / 2.0 + (-3.0 if etat else 9.0), str(o.get("label", "")).to_upper(), 24, Charte.DORE if en_place or voulu else PAL.encre, 800, 196)
		nom.add_theme_font_override("font", Charte.TITRE_EXTRA)
		var yp := h / 2.0 + 3.0
		if voulu: _puce(ligne, 44, yp, "⧗ PROCHAIN ARRÊT", Charte.DORE, "MatchFenetreConsignesAttente", false, true)
		elif en_place: _puce(ligne, 44, yp, "✓ En place", Charte.DORE, "MatchFenetreConsignesEnPlace")
		elif propose == v: _puce(ligne, 44, yp, "Le staff", Charte.GAIN, "MatchFenetreConsignesStaff_" + v)
		var r := avis(p, id, v)
		var pour: Array = (r.get("pour", []) as Array).duplicate() if r.get("pour") is Array else []
		for m: Variant in r.get("neutre", []) if r.get("neutre") is Array else []: pour.append({"mot": str(m), "neutre": true})
		var contre: Array = r.get("contre", []) if r.get("contre") is Array else []
		var lignes := maxi(maxi(pour.size(), contre.size()), 1)
		var yl := maxf(4.0, (h - lignes * 22.0) / 2.0)
		_lignes_effets(ligne, pour, 1, 250, yl, 220)
		_lignes_effets(ligne, contre, -1, 476, yl, 220)
		# Un clic demande ce cran ; sur le cran en place, il retire la demande en attente.
		var action := func():
			if v != attente and (v != cran or not attente.is_empty()): envoyer.call(id, v)
		Pieces.rendre_cliquable(ligne, Vector2(Lg, h), action, "MatchFenetreConsignesChoix_" + v, str(o.get("label", "")), "", Charte.RAYON_PETIT)
		y += h + ecart
	# Croquis du cran voulu (en attente, sinon en place), bilan dessous.
	var montre := attente if not attente.is_empty() else cran
	var xd := x0 + Lg + 24.0
	var Wd := LARGEUR - xd - 28.0
	var cadre := D.rect(fond, Rect2(xd, 86, Wd, 236), PAL.case, Charte.RAYON_CARTE)
	cadre.name = "MatchFenetreConsignesTerrain"
	var dessin := Croquis.new()
	dessin.axe = id
	dessin.valeur = montre
	cadre.add_child(dessin)
	D.place(dessin, Rect2(12, 12, Wd - 24, 180))
	D.text(cadre, 14, 222, ("⧗ " if not attente.is_empty() else "") + libelle_cran(axe, montre).to_upper(), 20, Charte.DORE, 800, Wd - 28).add_theme_font_override("font", Charte.TITRE_EXTRA)
	_bandeau_bilan(fond, p, axe, xd, 332, Wd)

# --- Bas : cartes illustrées, une par consigne, sur deux rangées ----------------------------------------------------

static func _rangee(fond: Control, p: Dictionary, axes: Array, axe: Dictionary, choisir: Callable) -> void:
	var id := str(axe.get("id", ""))
	var n := axes.size()
	var par_rang := ceili(n / 2.0)
	var ecart := 8.0
	var lc := (LARGEUR - 56.0 - (par_rang - 1) * ecart) / float(par_rang)
	var hc := 128.0
	for i in n:
		var a: Dictionary = axes[i]
		var ida := str(a.get("id", ""))
		var vu := ida == id
		var t: Color = FAMILLES.get(str(a.get("groupe", "")), PAL.encre)
		var xc := 28.0 + (i % par_rang) * (lc + ecart)
		var yc := 424.0 + int(i / par_rang) * (hc + ecart)
		var carte := D.rect(fond, Rect2(xc, yc, lc, hc), PAL.choisi if vu else PAL.case, Charte.RAYON_CARTE, t if vu else Color.TRANSPARENT)
		carte.name = "MatchFenetreConsignesCarteAxe_" + ida
		D.rect(carte, Rect2(0, 0, lc, 5), t, 3)
		var titre_c := D.text(carte, lc / 2.0, 24, str(COURTS.get(ida, a.get("label", ""))).to_upper(), 15, t, 800, lc - 12, HORIZONTAL_ALIGNMENT_CENTER)
		titre_c.add_theme_font_override("font", Charte.TITRE_EXTRA)
		var attente := en_attente(p, ida)
		var v := attente if not attente.is_empty() else Pilotage.cran(p, a)
		var c := Croquis.new()
		c.axe = ida
		c.valeur = v
		c.mini = true
		carte.add_child(c)
		D.place(c, Rect2(8, 32, lc - 16, 54))
		# Cran en place (ou demandé) : deux lignes au plus, coupées aux mots (« Chercher la pénaltouche »).
		var actif := v != neutre(a) or not attente.is_empty()
		var mot := D.text(carte, lc / 2.0, 104, libelle_cran(a, v), 15, Charte.DORE if actif else PAL.encre2, 700, lc - 12, HORIZONTAL_ALIGNMENT_CENTER)
		mot.name = "MatchFenetreConsignesCarteCran_" + ida
		mot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mot.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		mot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		D.place(mot, Rect2(6, 88, lc - 12, 38))
		if not attente.is_empty():
			var badge := D.rect(carte, Rect2(12, 36, 32, 18), Charte.DORE, Charte.RAYON_PILULE)
			badge.name = "MatchFenetreConsignesCarteAttente_" + ida
			D.text(badge, 16, 14, "⧗", 13, Charte.ENCRE, 800, 32, HORIZONTAL_ALIGNMENT_CENTER)
		if staff_propose(p, ida) != "" and staff_propose(p, ida) != v:
			D.rect(carte, Rect2(lc - 16, 10, 8, 8), Charte.GAIN, 4).tooltip_text = "Avis du staff"
		Pieces.rendre_cliquable(carte, Vector2(lc, hc), func(): choisir.call(ida), "MatchFenetreConsignesAxeLien_" + ida, str(a.get("label", "")), "", Charte.RAYON_CARTE)

# --- Pièces communes ---------------------------------------------------------------------------------------------

## Pilule d'un mot (ou d'un état) sur l'ardoise ; `plein` : aplat de la couleur, encre sombre. `a_droite` : `x` est
## le bord droit. Renvoie la largeur.
static func _puce(parent: Control, x: float, y: float, texte: String, couleur: Color, nom: String, a_droite := false, plein := false) -> float:
	var taille := 15
	var w := C.BODY.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density + 22.0
	var gauche := x - w if a_droite else x
	var pilule := D.rect(parent, Rect2(gauche, y, w, 24), couleur if plein else Color(couleur, .18), Charte.RAYON_PILULE)
	pilule.name = nom
	D.text(pilule, w / 2.0, 17, texte, taille, Charte.ENCRE if plein else couleur, 700, w, HORIZONTAL_ALIGNMENT_CENTER, true)
	return w

## Lignes de tendance : flèches colorées (▲▲ net, ▲ léger, ? le staff ne sait pas) puis un mot court, jamais de chiffre.
static func _lignes_effets(parent: Control, effets: Array, sens: int, x: float, y: float, largeur: float) -> void:
	for e_v: Variant in effets:
		if not e_v is Dictionary: continue
		var e: Dictionary = e_v
		var neutre_ := bool(e.get("neutre", false))
		var force := int(e.get("force", 1))
		var teinte: Color = PAL.encre3 if neutre_ or force == 0 else (Charte.GAIN if sens > 0 else Charte.PERTE)
		var signe := "=" if neutre_ else ("?" if force == 0 else ("▲" if sens > 0 else "▼").repeat(clampi(force, 1, 2)))
		var pastille := D.rect(parent, Rect2(x, y + 1, 34, 18), Color(teinte, .22), Charte.RAYON_PILULE)
		pastille.name = "Tendance_%s_%d" % ["neutre" if neutre_ else ("pour" if sens > 0 else "contre"), force]
		D.text(pastille, 17, 14, signe, 12, teinte, 800, 34, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(parent, x + 42, y + 16, str(e.get("mot", "")), 16, PAL.encre if not neutre_ and force > 0 else PAL.encre2, 600, largeur - 42)
		y += 22.0

## Pastille de la consigne adverse sur cet axe (ce que son jeu laisse voir), seulement si elle n'est pas neutre.
static func _pastille_adverse(fond: Control, p: Dictionary, axe: Dictionary, x: float, y: float) -> void:
	var adv: Dictionary = p.get("adversaire", {}) if p.get("adversaire") is Dictionary else {}
	var consignes: Dictionary = adv.get("consignes", {}) if adv.get("consignes") is Dictionary else {}
	var v := str(consignes.get(str(axe.get("id", "")), ""))
	if v.is_empty() or v == neutre(axe): return
	_puce(fond, x, y, "Eux : " + libelle_cran(axe, v), Charte.DORE, "MatchFenetreConsignesAdverse")

## Bilan depuis le changement : « depuis 41′ » puis un chiffre par morceau, en tuiles (ce qui s'est passé, après coup).
static func _bandeau_bilan(fond: Control, p: Dictionary, axe: Dictionary, x: float, y: float, largeur: float) -> void:
	var b := bilan(p, str(axe.get("id", "")))
	if b.is_empty():
		var vide := D.text(fond, x, y + 40, "BILAN · —", 16, PAL.encre3, 700, largeur)
		vide.name = "MatchFenetreConsignesBilanVide"
		return
	var morceaux: Array = b.get("morceaux", [])
	var n := morceaux.size() + 1
	var l := (largeur - (n - 1) * 8.0) / float(n)
	_tuile(fond, Rect2(x, y, l, 72), "%d′" % int(b.get("depuis", 0)), "depuis", Charte.DORE, "MatchFenetreConsignesBilanDepuis")
	for i in morceaux.size():
		var m := str(morceaux[i])
		var chiffre := m.get_slice(" ", 0)
		var reste := m.substr(chiffre.length()).strip_edges()
		var mauvais := (reste.contains("pénalité") and not reste.contains("adverse")) or (reste.contains("perdu") and not reste.contains("chez eux")) or reste.contains("carton") or reste.contains("encaissé")
		_tuile(fond, Rect2(x + (i + 1) * (l + 8.0), y, l, 72), chiffre, reste, Charte.PERTE if mauvais and chiffre != "0" else Charte.GAIN, "MatchFenetreConsignesBilan%d" % i)

## Tuile de chiffre sur l'ardoise : le chiffre coloré, la légende sur deux lignes au plus.
static func _tuile(parent: Control, zone: Rect2, valeur: String, legende: String, couleur: Color, nom: String) -> void:
	var carte := D.rect(parent, zone, PAL.case, Charte.RAYON_CARTE)
	carte.name = nom
	D.text(carte, 10, 28, valeur, 24, couleur, 800, zone.size.x - 20).add_theme_font_override("font", Charte.TITRE_EXTRA)
	var texte := D.text(carte, 10, 52, legende.to_upper(), 13, PAL.encre2, 600, zone.size.x - 16)
	texte.name = nom + "Legende"
	texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texte.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	D.place(texte, Rect2(10, 34, zone.size.x - 16, 36))

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

	# Plan de jeu : passes au large, pick and go, chandelles d'occupation ou jeu varié.
	func _planAttaque() -> void:
		for k in 5: joueur(0.7, 0.12 + k * 0.19, EUX)
		if valeur == "large":
			for k in 5: joueur(0.3 + k * 0.05, 0.3 + k * 0.13, NOUS)
			ballon(0.3, 0.3)
			fleche(Vector2(0.31, 0.32), Vector2(0.48, 0.82), FLECHE, false, 0.06)
			fleche(Vector2(0.52, 0.86), Vector2(0.86, 0.9), Charte.GAIN)
		elif valeur == "conquete":
			for k in 6: joueur(0.42 + (k % 2) * 0.04, 0.4 + int(k / 2.0) * 0.1, NOUS)
			ballon(0.47, 0.5)
			fleche(Vector2(0.5, 0.5), Vector2(0.62, 0.5), Charte.DORE)
		elif valeur == "occupation":
			for k in 3: joueur(0.25 + k * 0.05, 0.4 + k * 0.1, NOUS)
			ballon(0.25, 0.4)
			fleche(Vector2(0.27, 0.4), Vector2(0.9, 0.35), FLECHE, true, -0.3)
		else:
			for k in 4: joueur(0.32 + k * 0.05, 0.35 + k * 0.1, NOUS)
			ballon(0.32, 0.35)
			fleche(Vector2(0.33, 0.37), Vector2(0.45, 0.62))
			fleche(Vector2(0.46, 0.64), Vector2(0.62, 0.66), Color(FLECHE, .6))

	# Système de défense : la ligne monte vite (pression), glisse vers l'aile (prudente) ou avance d'un bloc.
	func _systemeDefense() -> void:
		joueur(0.3, 0.5, EUX)
		ballon(0.31, 0.53)
		for k in 3: joueur(0.24, 0.25 + k * 0.25, EUX)
		for k in 5:
			var y := 0.12 + k * 0.19
			joueur(0.55, y, NOUS)
			if valeur == "pression": fleche(Vector2(0.54, y), Vector2(0.4, y), Charte.PERTE)
			elif valeur == "prudente": fleche(Vector2(0.56, y), Vector2(0.6, minf(0.92, y + 0.14)), Charte.GAIN, false, 0.04)
			else: fleche(Vector2(0.54, y), Vector2(0.47, y))

	# Pénalités : poteaux (pied), touche près de leur ligne, jeu rapide à la main, ou choix du capitaine.
	func _penalites() -> void:
		var e := maxf(1.5, size.y * (0.012 if not mini else 0.03))
		draw_line(P(0.94, 0.4), P(0.94, 0.6), FLECHE, e * 1.5)
		draw_line(P(0.94, 0.5), P(0.99, 0.5), FLECHE, e)
		joueur(0.6, 0.5, NOUS)
		ballon(0.6, 0.5)
		for k in 3: joueur(0.7, 0.3 + k * 0.2, EUX)
		if valeur == "points": fleche(Vector2(0.62, 0.5), Vector2(0.93, 0.5), Charte.GAIN, true, -0.15)
		elif valeur == "touch": fleche(Vector2(0.62, 0.48), Vector2(0.86, 0.04), Charte.DORE, true, -0.1)
		elif valeur == "main": fleche(Vector2(0.62, 0.52), Vector2(0.8, 0.72), Charte.GAIN)
		else:
			fleche(Vector2(0.62, 0.5), Vector2(0.9, 0.5), Color(FLECHE, .5), true, -0.15)
			fleche(Vector2(0.62, 0.48), Vector2(0.84, 0.06), Color(FLECHE, .5), true, -0.1)
