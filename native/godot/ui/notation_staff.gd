extends RefCounted
## Notation façon FM (planche du 24/11/2026, choix de Léo) : le Niveau et le Potentiel restent CACHÉS ; l'écran montre
## l'estimation du STAFF, dont la justesse dépend de son jugement :
##   • une LETTRE E- à S+ relative à NOTRE effectif (référence = moyenne estimée de nos 15 meilleurs : B ; 1 cran = 2 pts) ;
##   • un PALIER absolu, volontairement vague, en 4 familles (Niveau amateur / Niveau pro / Haut niveau / Élite),
##     « Entre pro et haut niveau » quand la fourchette du staff est à cheval ;
##   • le potentiel en PHRASE par cran de marge (beaucoup / de la marge / peu / en déclin / staff incertain), tournure
##     tirée selon le staff et le joueur (empreinte fixe, jamais de hasard à l'affichage).
## Aucun chiffre du moteur n'est affiché. Le calcul du Niveau par poste et rôle (native/engine/niveau-calcule.cjs) n'est
## branché à l'écran (projection `niveauCalcule`) : l'estimation part du Niveau au meilleur rôle du poste principal.
## Affichage choisi par Léo (24/11, option B) : lettre dans une pastille ronde, palier écrit dans une pilule.
## Note au poste et note au rôle (décision de Léo du 24/11) : même échelle E- à S+, même référence, même palette ;
## jamais de chiffre. Staff pas sûr (joueur pas encore observé, qualités en fourchette) : pastille double « B/A ».
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const K = preload("res://ui/player_knowledge_text.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")

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
	# Niveau calculé selon le poste et le rôle (niveau-calcule.cjs, projection `niveauCalcule`) : il remplace la valeur
	# posée quand le staff connaît les qualités ; en mode fourchette il part déjà du milieu des fourchettes.
	var calcule: Variant = p.get("niveauCalcule", {}).get("niveau") if p.get("niveauCalcule") is Dictionary else null
	if K.number(calcule): bn = {"min": float(calcule) - qualites_largeur(p) / 2.0, "max": float(calcule) + qualites_largeur(p) / 2.0}
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
	if model.has("squad"): modele = model
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
	var ln := lettre_niveau(model, p, notre)
	var i_niveau := indice(est.niveau, ref)
	# Lettre seule du Niveau = l'une des deux de la pastille double (même estimation que « son rôle »).
	if int(ln.bas) >= 0 and (i_niveau < int(ln.bas) or i_niveau > int(ln.haut)): i_niveau = clampi(i_niveau, int(ln.bas), int(ln.haut))
	return {"niveau": i_niveau, "niveau_note": ln, "potentiel": indice(est.potentiel, ref), "palier": palier(est), "phrase": potentiel(model, p, est)}

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

# --- Note au poste et note au rôle en lettre (décision de Léo, 24/11/2026) -----------------------------------------

## Largeur des fourchettes de qualités (option de carrière « En fourchette ») : 0 si précises.
static func qualites_largeur(p: Dictionary) -> float:
	var k: Variant = p.get("knowledge")
	var l: Variant = k.get("qualitesLargeur") if k is Dictionary else null
	return float(l) if K.number(l) else 0.0

## Lettre d'une note sur l'échelle du Niveau : {bas, haut} (indices de LETTRES, -1 si inconnue ; bas < haut = staff
## pas sûr). `note` : valeur cachée (note au poste, Niveau au rôle) ou -1 si le staff ne la connaît pas ; il l'estime
## alors d'après la fourchette d'observation du joueur, aux postes qu'il connaît seulement (`familiarite` ≥ Confirmé).
## `cle` : nom de la note (sans effet sur l'erreur : une seule erreur fixe du staff par joueur, celle du Niveau).
static func lettre_note(model: Dictionary, p: Dictionary, note: float, notre: bool, cle: String, familiarite: int = Familiarite.NATUREL) -> Dictionary:
	var e := erreur(model)
	var ref := reference_effectif(model)
	# Une seule erreur du staff par joueur (celle du Niveau) : son meilleur rôle au poste principal a la même lettre que
	# son Niveau, et les écarts entre postes et rôles restent ceux du moteur. `cle` reste pour les appels existants.
	var graine := str(model.get("club", {}).get("id", "")) + "|" + str(p.get("id", "")) + "|n"
	var q := qualites_largeur(p) / 2.0
	var v := 0.0
	var demi := q
	if note >= 0.0:
		v = note + e * _empreinte(graine) + (decalage_poste(p) if cle.begins_with("poste:") else 0.0)
	else:
		if familiarite < Familiarite.CONFIRME: return {"bas": -1, "haut": -1}
		var bn := K.bounds(p, "rating", notre)
		if bn.is_empty(): return {"bas": -1, "haut": -1}
		v = (float(bn.min) + float(bn.max)) / 2.0 + e * _empreinte(graine)
		demi = maxf(q, (float(bn.max) - float(bn.min)) / 2.0)
	return paire(v, demi, ref)

## Règle de la pastille double (25/11) : jamais plus de DEUX lettres VOISINES. Staff sûr (incertitude < un demi-cran) :
## une lettre, celle de l'estimation ; sinon les deux lettres qui encadrent l'estimation (« B/B+ »). La lettre seule du
## même joueur (Niveau, tri) est toujours l'une des deux.
static func paire(v: float, demi: float, ref: float) -> Dictionary:
	var x := REFERENCE + (v - ref) / PAS
	var seule := indice(v, ref)
	if demi * 0.7 < PAS / 2.0: return {"bas": seule, "haut": seule}
	var bas := clampi(floori(x), 0, LETTRES.size() - 2)
	return {"bas": bas, "haut": bas + 1}

## Niveau du joueur en lettre {bas, haut} : même calcul que « son rôle » (Niveau calculé, même erreur du staff), double
## quand le staff n'est pas sûr (qualités en fourchette, joueur observé de loin).
static func lettre_niveau(model: Dictionary, p: Dictionary, notre: bool) -> Dictionary:
	var nc: Variant = p.get("niveauCalcule")
	var note := -1.0
	if nc is Dictionary and K.number(nc.get("niveau")): note = float(nc.niveau)
	elif K.owned(p, notre) and K.number(p.get("rating")): note = float(p.rating)
	return lettre_note(model, p, note, notre, "niveau")

# --- Modèle courant (posé par main.gd à chaque réponse du moteur) : textes et tris des vues qui n'ont pas le modèle ---
static var modele: Dictionary = {}

static func _modele(model: Dictionary = {}) -> Dictionary:
	return model if not model.is_empty() else modele

## Niveau ou Potentiel d'un joueur en texte de lettre (« B », « B/B+ », « ? »), jamais un chiffre du moteur.
static func texte_champ(p: Dictionary, champ: String, notre: bool, model: Dictionary = {}) -> String:
	var m := _modele(model)
	if champ == "potential": return texte_lettre(int(resume(m, p, notre).potentiel))
	return texte_note(lettre_niveau(m, p, notre))

## Lettre {bas, haut} du Niveau ou du Potentiel (pastille_note).
static func lettre_champ(p: Dictionary, champ: String, notre: bool, model: Dictionary = {}) -> Dictionary:
	var m := _modele(model)
	if champ == "potential":
		var i := int(resume(m, p, notre).potentiel)
		return {"bas": i, "haut": i}
	return lettre_niveau(m, p, notre)

## Valeur MONTRÉE d'un Niveau ou d'un Potentiel sur l'échelle 15-99 : centre de la lettre affichée (milieu d'une double),
## d'après la référence de l'effectif. Pour poser une jauge ou une couleur sans trahir le chiffre du moteur ; null si inconnue.
static func valeur_montree(p: Dictionary, champ: String, notre: bool, model: Dictionary = {}) -> Variant:
	var m := _modele(model)
	var r := rang_lettre(lettre_champ(p, champ, notre, m))
	if r < 0.0: return null
	return reference_effectif(m) + (r - REFERENCE) * PAS

## Valeur de tri d'un Niveau ou d'un Potentiel : la lettre MONTRÉE (milieu d'une double), null si inconnue. À lettre égale,
## les listes départagent par nom ou identifiant : l'ordre ne trahit jamais le chiffre caché.
static func tri_champ(p: Dictionary, champ: String, notre: bool, model: Dictionary = {}) -> Variant:
	var r := rang_lettre(lettre_champ(p, champ, notre, model))
	return r if r >= 0.0 else null

## Notes au poste calées sur le Niveau calculé : au poste principal, la note au poste vaut le Niveau (poste + rôle) ;
## aux autres postes, les écarts du moteur (familiarité, qualités du poste) restent. 0 sans Niveau calculé.
static func decalage_poste(p: Dictionary) -> float:
	var nc: Variant = p.get("niveauCalcule")
	var notes: Variant = p.get("positionRatings")
	var principaux: Variant = p.get("primaryPositions", [p.get("primaryPosition")])
	if not (nc is Dictionary and K.number(nc.get("niveau")) and notes is Dictionary and principaux is Array and not (principaux as Array).is_empty()): return 0.0
	var base: Variant = (notes as Dictionary).get(str(int(principaux[0]))) if K.number(principaux[0]) else null
	return float(nc.niveau) - float(base) if K.number(base) else 0.0

## Écart entre le Niveau calculé et la valeur posée du moteur (`rating`) : recale une valeur passée (niveau de juillet)
## sur l'échelle du Niveau montré. 0 sans Niveau calculé.
static func decalage_niveau(p: Dictionary) -> float:
	var nc: Variant = p.get("niveauCalcule")
	if nc is Dictionary and K.number(nc.get("niveau")) and K.number(p.get("rating")): return float(nc.niveau) - float(p.rating)
	return 0.0

## Empreinte de l'erreur du staff au poste : une par famille de poste (11 et 14, même note → même lettre).
static func cle_poste(numero: int) -> String:
	return "poste:%d" % (Familiarite.FAMILLES[numero - 1] if numero >= 1 and numero <= 15 else 0)

## Note au poste `numero` (positionRatings du moteur) en lettre.
static func lettre_poste(model: Dictionary, p: Dictionary, numero: int, notre: bool) -> Dictionary:
	var note := -1.0
	var notes: Variant = p.get("positionRatings")
	if notes is Dictionary:
		var x: Variant = (notes as Dictionary).get(str(numero))
		if K.number(x) and float(x) >= 0.0: note = float(x)
	return lettre_note(model, p, note, notre, cle_poste(numero), Familiarite.niveau(p, numero))

## Niveau au rôle (niveau-calcule.cjs : poids du poste + qualités clés et utiles du rôle) en lettre ; `numero` : maillot
## du rôle (familiarité pour l'estimation d'un joueur pas observé).
static func lettre_role(model: Dictionary, p: Dictionary, role_id: String, numero: int, notre: bool) -> Dictionary:
	var nc: Variant = p.get("niveauCalcule")
	var note := -1.0
	if nc is Dictionary and nc.get("roles") is Dictionary and K.number(nc.roles.get(role_id)): note = float(nc.roles[role_id])
	return lettre_note(model, p, note, notre, "role:" + role_id, Familiarite.niveau(p, numero) if numero > 0 else Familiarite.NATUREL)

## Lettre au milieu (tri, comparaisons) ; -1 si inconnue.
static func rang_lettre(l: Dictionary) -> float:
	var b := int(l.get("bas", -1))
	var h := int(l.get("haut", -1))
	return -1.0 if b < 0 else (b + h) / 2.0

static func texte_note(l: Dictionary) -> String:
	var b := int(l.get("bas", -1))
	var h := int(l.get("haut", -1))
	if b < 0: return "?"
	return texte_lettre(b) if b == h else texte_lettre(b) + "/" + texte_lettre(h)

## Largeur que prend `pastille_note` pour une `taille`.
static func largeur_note(l: Dictionary, taille: float) -> float:
	return taille * (1.9 if int(l.get("bas", -1)) >= 0 and int(l.get("bas", -1)) != int(l.get("haut", -1)) else 1.0)

## Pastille de la note : ronde (lettre sûre, même dessin que le Niveau) ou double (« B/A » : deux moitiés aux couleurs
## des deux lettres, staff pas sûr). Méta « lettre » = texte_note. Renvoie le nœud posé.
static func pastille_note(parent: Control, x: float, centre_y: float, l: Dictionary, taille: float, nom: String = "") -> Control:
	var b := int(l.get("bas", -1))
	var h := int(l.get("haut", -1))
	if b == h or b < 0:
		pastille(parent, x, centre_y, b, taille, nom)
		var rond := parent.get_child(parent.get_child_count() - 1) as Control
		rond.set_meta("lettre", texte_note(l))
		return rond
	var w := largeur_note(l, taille)
	var fond := D.rect(parent, Rect2(x, centre_y - taille / 2.0, w, taille), couleur(h), int(taille / 2.0))
	if not nom.is_empty(): fond.name = nom
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.set_meta("lettre", texte_note(l))
	fond.set_meta("incertaine", true)
	var gauche := D.rect(fond, Rect2(0, 0, w / 2.0 + taille * 0.25, taille), couleur(b), int(taille / 2.0))
	gauche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.rect(fond, Rect2(w / 2.0, 0, taille * 0.3, taille), couleur(b)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.rect(fond, Rect2(w / 2.0 - 1.0, taille * 0.18, 2.0, taille * 0.64), Color(Charte.ENCRE, .55)).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 2:
		var i := b if k == 0 else h
		var t := D.text(fond, w * (0.27 + 0.46 * k), taille * 0.72, texte_lettre(i), int(taille * 0.56), couleur_texte(i), 800, w / 2.0, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_font_override("font", Charte.TITRE_FICHE)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fond

## Pastille dans un conteneur (HBox, VBox) : « porte » à la taille de la pastille (ronde ou double), pastille dedans.
static func porte_pastille(l: Dictionary, taille: float, nom: String = "") -> Control:
	var porte := Control.new()
	porte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	porte.custom_minimum_size = Vector2(C.px(largeur_note(l, taille)), C.px(taille))
	porte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rond := pastille_note(porte, 0, taille / 2.0, l, taille, nom)
	porte.set_meta("lettre", rond.get_meta("lettre", ""))
	# Couleurs de la palette des lettres : les re-teintures des vues héritées (recruitment_pages._teindre,
	# legacy_style) ne doivent pas les griser.
	for noeud: Node in [porte] + porte.find_children("*", "", true, false):
		noeud.set_meta("style_charte", true)
		noeud.set_meta("immersive_style_applied", true)
	return porte

## Sens d'une évolution de Niveau sans chiffre : ▲, ▼ ou =.
static func sens(valeur: Variant) -> String:
	if not (valeur is int or valeur is float): return "="
	return "▲" if float(valeur) > 0.0 else "▼" if float(valeur) < 0.0 else "="

## Pastille ronde posée, renvoie le nœud (flèche de progression du Niveau).
static func pastille_noeud(parent: Control, x: float, centre_y: float, i: int, taille: float, nom: String = "") -> Control:
	pastille(parent, x, centre_y, i, taille, nom)
	return parent.get_child(parent.get_child_count() - 1) as Control
