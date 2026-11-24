extends RefCounted
## Notation façon FM (planche du 24/11/2026, choix de Léo) : le Niveau et le Potentiel restent CACHÉS ; l'écran montre
## l'estimation du STAFF, dont la justesse dépend de son jugement :
##   • une LETTRE E- à S+ relative à NOTRE effectif (référence = moyenne estimée de nos 15 meilleurs : B ; 1 cran = 2 pts) ;
##   • un PALIER absolu, volontairement vague, en 4 familles (Niveau amateur / Niveau pro / Haut niveau / Élite),
##     « Entre pro et haut niveau » quand la fourchette du staff est à cheval ;
##   • le potentiel en PHRASE par cran de marge (beaucoup / de la marge / peu / en déclin / staff incertain), tournure
##     tirée selon le staff et le joueur (empreinte fixe, jamais de hasard à l'affichage).
## Aucun chiffre du moteur n'est affiché. Le calcul du Niveau par poste et rôle (native/engine/niveau-calcule.cjs) n'est
## pas encore branché : l'estimation part de la valeur cachée actuelle. Affichage choisi par Léo (24/11, option B) :
## lettre dans une pastille ronde, palier écrit dans une pilule.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const K = preload("res://ui/player_knowledge_text.gd")

const LETTRES := ["E-", "E", "E+", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+", "S-", "S", "S+"]
## Palette validée par Léo : « - » sourd et sombre, lettre = couleur franche, « + » poussée à fond.
const COULEURS := ["5A2020", "9C2A2A", "E5201F", "8A4A1E", "CC6A1E", "FF7A00", "8E7516", "D4AA1C", "FFD000",
	"245E33", "2F9A47", "14D24A", "1E4780", "2A72CC", "0A8BFF", "45237F", "7440CC", "9B30FF"]
const REFERENCE := 10   ## B = niveau moyen estimé de nos 15 meilleurs
const PAS := 2.0        ## points de Niveau par cran
const INCONNU := Color("3a4446")

## Paliers absolus (Niveau caché, échelle actuelle 15-99) : seuils calés sur les XV du Monde (docs/notation-fm-20261124.md).
const PALIERS := ["Niveau amateur", "Niveau pro", "Haut niveau", "Élite"]
const PALIERS_COURTS := ["amateur", "pro", "haut niveau", "élite"]
const SEUILS := [60.0, 72.0, 82.0]

const PHRASES := {
	"beaucoup": ["Peut aller beaucoup plus haut", "Très loin de son plafond", "Un gros potentiel à faire éclore", "Le staff le voit bien plus haut"],
	"marge": ["Peut encore grandir", "A encore de la marge", "Progression attendue", "Encore du chemin à faire"],
	"peu": ["Proche de son meilleur niveau", "Peu de marge", "Presque à son plafond"],
	"declin": ["Commence à décliner", "Sur la pente descendante", "Ses meilleures années sont derrière lui"],
	"incertain": ["Le staff hésite", "Difficile à cerner", "À revoir avant de juger"],
}
const COULEUR_PHRASE := {"beaucoup": Color("14D24A"), "marge": Color("7fbf7a"), "peu": Color("d4aa1c"), "declin": Color("d9634f"), "incertain": Color("abb7b1")}

static func _empreinte(texte: String) -> float:
	# FNV-1a 32 bits → [-1, 1] : fixe pour un couple (staff, joueur), comme l'erreur du jugement du staff.
	var h := 2166136261
	for i in texte.length():
		h = ((h ^ texte.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return float(h % 20001) / 10000.0 - 1.0

## Jugement du staff (45-85) : moyenne des membres de notre staff qui ont une note ; 60 sans projection.
static func jugement(model: Dictionary) -> float:
	var club_id := int(model.get("club", {}).get("id", -1))
	for team: Variant in model.get("staff", {}).get("teams", []):
		if not team is Dictionary or int(team.get("id", -2)) != club_id: continue
		var total := 0.0
		var n := 0
		for m: Variant in team.get("members", []):
			if not m is Dictionary: continue
			var v: Variant = m.get("rating", m.get("level"))
			if K.number(v):
				total += float(v)
				n += 1
		if n > 0: return clampf(total / n, 45.0, 85.0)
	return 60.0

## Erreur maximale du staff en points : 1,5 (staff de 85) à 6 (staff de 45).
static func erreur(model: Dictionary) -> float:
	return lerpf(6.0, 1.5, (jugement(model) - 45.0) / 40.0)

static func _milieu(b: Dictionary) -> Variant:
	if b.is_empty(): return null
	return (float(b.min) + float(b.max)) / 2.0

## Estimation du staff : {niveau, potentiel, largeur} (null si inconnu). Notre joueur : valeur cachée + erreur fixe ;
## autre joueur : milieu de la fourchette d'observation (player-knowledge) + même erreur.
static func estimation(model: Dictionary, p: Dictionary, notre: bool) -> Dictionary:
	var e := erreur(model)
	var cle := str(model.get("club", {}).get("id", "")) + "|" + str(p.get("id", ""))
	var bn := K.bounds(p, "rating", notre)
	var bp := K.bounds(p, "potential", notre)
	var n: Variant = _milieu(bn)
	var pot: Variant = _milieu(bp)
	var largeur_n := e + (float(bn.max) - float(bn.min)) / 2.0 if not bn.is_empty() else 99.0
	var largeur_p := e + (float(bp.max) - float(bp.min)) / 2.0 if not bp.is_empty() else 99.0
	if n != null: n = float(n) + e * _empreinte(cle + "|n")
	if pot != null: pot = maxf(float(pot) + e * _empreinte(cle + "|p"), float(n) if n != null else 0.0)
	return {"niveau": n, "potentiel": pot, "largeur": largeur_n, "largeur_p": largeur_p}

## Référence de l'effectif : moyenne estimée de nos 15 meilleurs (mémorisée par modèle).
static var _cache_effectif: Variant = null
static var _cache_reference := 65.0

static func reference_effectif(model: Dictionary) -> float:
	var squad: Variant = model.get("squad", [])
	if _cache_effectif != null and is_same(_cache_effectif, squad): return _cache_reference
	var valeurs: Array[float] = []
	for p: Variant in model.get("squad", []):
		if p is Dictionary:
			var v: Variant = estimation(model, p, true).niveau
			if v != null: valeurs.append(float(v))
	valeurs.sort()
	valeurs.reverse()
	var top := valeurs.slice(0, 15)
	var r := 65.0
	if not top.is_empty():
		r = 0.0
		for v in top: r += v
		r /= top.size()
	_cache_effectif = squad
	_cache_reference = r
	return r

static func indice(valeur: Variant, ref: float) -> int:
	if valeur == null: return -1
	return clampi(REFERENCE + roundi((float(valeur) - ref) / PAS), 0, LETTRES.size() - 1)

static func couleur(i: int) -> Color:
	return Color(COULEURS[i]) if i >= 0 else INCONNU

## Texte : clair sur les sombres, foncé sur C, C+, B+ ; blanc sur E+, D+, A+, S+.
static func couleur_texte(i: int) -> Color:
	if i in [7, 8, 11]: return Color("15191a")
	if i in [2, 5, 14, 17]: return Color.WHITE
	return Charte.CREME

static func _famille(v: float) -> int:
	var f := 0
	for s in SEUILS:
		if v >= s: f += 1
	return f

## Palier vague : {texte, bas, haut} (bas/haut : familles 0-3, égales si le staff est sûr).
static func palier(est: Dictionary) -> Dictionary:
	if est.niveau == null: return {"texte": "Palier inconnu", "bas": -1, "haut": -1}
	var bas := _famille(float(est.niveau) - 0.7 * float(est.largeur))
	var haut := _famille(float(est.niveau) + 0.7 * float(est.largeur))
	if haut - bas > 1:
		var milieu := _famille(float(est.niveau))
		bas = clampi(milieu, 0, 2) if float(est.niveau) >= SEUILS[clampi(milieu, 0, 2)] - 1.0 else maxi(milieu - 1, 0)
		haut = bas + 1
	if bas == haut: return {"texte": PALIERS[bas], "bas": bas, "haut": haut}
	return {"texte": "Entre %s et %s" % [PALIERS_COURTS[bas], PALIERS_COURTS[haut]], "bas": bas, "haut": haut}

## Phrase de potentiel : {cran, texte, couleur}.
static func potentiel(model: Dictionary, p: Dictionary, est: Dictionary) -> Dictionary:
	var cran := "incertain"
	if est.niveau != null and est.potentiel != null and float(est.largeur_p) <= 9.0:
		var marge := float(est.potentiel) - float(est.niveau)
		var age := int(p.get("age", 25))
		if age >= 31 and marge < 2.0: cran = "declin"
		elif marge >= 9.0: cran = "beaucoup"
		elif marge >= 3.5: cran = "marge"
		else: cran = "peu"
	var liste: Array = PHRASES[cran]
	var tirage := absf(_empreinte(str(jugement(model)) + "|" + str(p.get("id", "")) + "|phrase"))
	return {"cran": cran, "texte": str(liste[mini(int(tirage * liste.size()), liste.size() - 1)]), "couleur": COULEUR_PHRASE[cran]}

## Tout ce que l'écran montre d'un joueur.
static func resume(model: Dictionary, p: Dictionary, notre: bool) -> Dictionary:
	var est := estimation(model, p, notre)
	var ref := reference_effectif(model)
	return {"niveau": indice(est.niveau, ref), "potentiel": indice(est.potentiel, ref), "palier": palier(est), "phrase": potentiel(model, p, est)}

static func texte_lettre(i: int) -> String:
	return LETTRES[i] if i >= 0 else "?"

## Pastille lettre ronde (choix B de Léo). Renvoie la largeur posée.
static func pastille(parent: Control, x: float, centre_y: float, i: int, taille: float, nom: String = "") -> float:
	var fond := D.rect(parent, Rect2(x, centre_y - taille / 2.0, taille, taille), couleur(i), int(taille / 2.0))
	if not nom.is_empty(): fond.name = nom
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_meta("lettre", texte_lettre(i))
	var t := D.text(fond, taille / 2.0, taille * 0.74, texte_lettre(i), int(taille * 0.6), couleur_texte(i), 800, taille, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_override("font", Charte.TITRE_FICHE)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return taille

## Palier écrit dans une pilule (choix B de Léo). Renvoie la largeur posée.
static func poser_palier(parent: Control, x: float, centre_y: float, pal: Dictionary, taille: int, largeur_max: float, nom: String = "") -> float:
	var texte := str(pal.texte)
	var police: Font = C.font(700)
	var lt := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille + 3))).x / C.density + 32
	lt = minf(lt, largeur_max)
	var h := taille * 1.9
	var fond := D.rect(parent, Rect2(x, centre_y - h / 2.0, lt, h), Charte.PANNEAU_2, int(h / 2.0), Color(Charte.CREME, .35))
	if not nom.is_empty(): fond.name = nom
	fond.set_meta("palier", texte)
	D.text(fond, lt / 2.0, h * 0.70, texte, taille + 3, Charte.CREME, 700, lt, HORIZONTAL_ALIGNMENT_CENTER)
	return lt

## Palier d'un groupe (création de carrière, XV de l'Effectif) : même échelle absolue et vague que celui d'un joueur,
## à partir d'un niveau moyen ; « Entre … et … » à moins de 2 points d'une frontière. Aucun chiffre montré.
static func palier_groupe(moyenne: Variant) -> Dictionary:
	if not K.number(moyenne) or float(moyenne) <= 0.0: return {"texte": "Palier inconnu", "bas": -1, "haut": -1}
	return palier({"niveau": float(moyenne), "largeur": 2.0 / 0.7})
