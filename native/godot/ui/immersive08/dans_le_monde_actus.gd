extends RefCounted
## Articles de la page « Dans le monde » (idée FM27 n° 30, choix A de Léo du 23/11/2026), sans interface : testable seul.
## Sources, toutes du moteur : résultats du monde (`history` : score, essais et leur origine, conquête, pénalités, affluence),
## classements (`leagues`), prochaines affiches (`clubNext`), et `monde` (world-model.cjs) : transferts entre clubs adverses,
## cadres blessés, journalistes des médias du jeu par compétition.
## Chaque article : un thème (16, banque `art/actus/actu-<thème>-<1..6>.webp`), un titre au ton du média qui le signe, des
## chiffres en pastilles, les clubs (écussons) et le joueur (portrait) concernés, et sa cible au clic.
## Image : variante tournante selon le jour du calendrier et le rang de l'article dans son thème sur la page : jamais deux
## fois la même image sur la page (jusqu'à 6 articles d'un thème), autre variante le lendemain, même page pour une même
## sauvegarde au même jour.

const G = preload("res://ui/game_skin.gd")

const THEMES := ["victoire-large", "victoire-serree", "defaite-lourde", "defaite-courte", "essai", "melee", "touche", "penalite",
	"plaquage", "ballon-porte", "supporters", "stade", "presse", "transfert", "blessure", "entrainement"]
const DOSSIER := "res://art/actus/"
const VARIANTES := 6
const UNE := 1
const CARTES := 2
const LISTE := 10
const PAR_THEME := 2

## Couleur fixe de chaque compétition (choix de Léo : palette fixe des ligues) ; repli tournant pour une ligue inconnue.
const COULEURS := {
	"elite": Color("5b9bd5"), "accession": Color("8fb3c9"), "nationale": Color("b5c46a"), "prem": Color("d9634f"),
	"champ": Color("c77dba"), "urc": Color("4fb3a9"), "srp": Color("a88bd6"), "jlo-d1": Color("e0a04a"), "jlo-d2": Color("d4a373"),
	"champions": Color("7fbf7a"), "challenge": Color("e98a6b"),
}
const REPLI := [Color("5b9bd5"), Color("7fbf7a"), Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("d9634f")]

## Styles des journalistes (banque de presse) préférés par thème : le résultat aux analystes et techniciens, le mercato et
## l'infirmerie aux enquêteurs et intervieweurs, la chronique aux éditorialistes.
const STYLES := {
	"transfert": ["enquete", "interview"], "blessure": ["enquete", "interview"], "presse": ["editorial", "analyse"],
	"stade": ["interview", "editorial"], "supporters": ["interview", "editorial"], "entrainement": ["technique", "enquete"],
	"melee": ["technique"], "touche": ["technique"], "ballon-porte": ["technique"], "penalite": ["technique", "analyse"],
	"plaquage": ["technique", "analyse"],
}

## Titres par thème et par ton du média : %1 club mis en avant, %2 l'autre club (ou le joueur), %3 un chiffre.
const TITRES := {
	"victoire-large": {"technique": "{a} déroule face à {b}", "analyse": "{a} écrase {b} ({n})", "interview": "{a} survole {b}", "enquete": "{a} ne laisse rien à {b}", "editorial": "Démonstration de {a} contre {b}"},
	"victoire-serree": {"technique": "{a} arrache la victoire face à {b}", "analyse": "{a} s'impose d'un souffle ({n})", "interview": "{a} au bout du suspense", "enquete": "{a} fait plier {b} au finish", "editorial": "{a} tremble mais gagne"},
	"defaite-lourde": {"technique": "{a} sombre face à {b}", "analyse": "{a} explose ({n})", "interview": "Soirée noire pour {a}", "enquete": "{a} sans réponse face à {b}", "editorial": "{a} touche le fond"},
	"defaite-courte": {"technique": "{a} échoue d'un rien face à {b}", "analyse": "{a} battu d'un souffle ({n})", "interview": "{a} si près face à {b}", "enquete": "{a} rate le coche face à {b}", "editorial": "{a}, la défaite qui fait mal"},
	"essai": {"technique": "Festival d'essais entre {a} et {b}", "analyse": "{n} essais entre {a} et {b}", "interview": "{a} et {b} enflamment la pelouse", "enquete": "Pluie d'essais : {a} – {b}", "editorial": "Le jeu a gagné : {a} – {b}"},
	"melee": {"technique": "{a} étouffe {b} en mêlée", "analyse": "{a} : {n} mêlées gagnées", "interview": "Le pack de {a} fait la loi", "enquete": "{b} plie sous la mêlée de {a}", "editorial": "La mêlée de {a} a tout écrasé"},
	"touche": {"technique": "{a} maître des airs face à {b}", "analyse": "{a} : {n} touches gagnées", "interview": "{a} vole la touche de {b}", "enquete": "{b} privé de ballons par {a}", "editorial": "{a} règne en touche"},
	"penalite": {"technique": "Le pied de {a} fait plier {b}", "analyse": "{a} gagne au pied ({n} pénalités)", "interview": "{a} s'en remet à son buteur", "enquete": "{b} puni au pied par {a}", "editorial": "{a}, la victoire au pied"},
	"plaquage": {"technique": "Muraille {a} : {b} muselé", "analyse": "{a} n'encaisse que {n} points", "interview": "{a} gagne en défendant", "enquete": "{b} bute sur la défense de {a}", "editorial": "La défense de {a} fait la différence"},
	"ballon-porte": {"technique": "Le ballon porté de {a} écrase {b}", "analyse": "{a} : {n} essais sur ballon porté", "interview": "Le maul de {a} fait des dégâts", "enquete": "{b} impuissant face au maul de {a}", "editorial": "{a} avance en bloc"},
	"supporters": {"technique": "{n} spectateurs chez {a}", "analyse": "Record d'affluence : {n} chez {a}", "interview": "{a} porté par {n} supporters", "enquete": "{n} fidèles pour {a} – {b}", "editorial": "Stade plein pour {a}"},
	"stade": {"technique": "Choc à venir : {a} – {b}", "analyse": "Affiche : {a} reçoit {b}", "interview": "{a} attend {b} de pied ferme", "enquete": "{a} – {b}, l'affiche de la semaine", "editorial": "Tous les yeux sur {a} – {b}"},
	"presse": {"technique": "{a} en tête ({n} pts)", "analyse": "{a} leader avec {n} points", "interview": "{a} savoure sa place de leader", "enquete": "{a} tient la tête", "editorial": "{a}, patron du championnat"},
	"transfert": {"technique": "{b} rejoint {a}", "analyse": "{a} recrute {b}", "interview": "{b} signe à {a}", "enquete": "Mercato : {b} file à {a}", "editorial": "Le coup de {a} : {b}"},
	"blessure": {"technique": "{b} ({a}) forfait {n} semaines", "analyse": "{a} perd {b} pour {n} semaines", "interview": "Coup dur pour {a} : {b} blessé", "enquete": "{a} privé de {b}", "editorial": "{a} sans {b}, tuile majeure"},
	"entrainement": {"technique": "{a} au travail après {n} revers", "analyse": "{a} : {n} défaites de suite", "interview": "{a} veut relever la tête", "enquete": "{a} dans le dur", "editorial": "{a} doit réagir"},
}

static func _n(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0

static func _cle_id(v: Variant) -> String:
	return str(roundi(v)) if v is float else str(v)

## Graine stable d'un texte (FNV-1a 32 bits) : même résultat d'une session à l'autre.
static func graine(texte: String) -> int:
	var h := 2166136261
	for b in texte.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h

static func couleur(id: String, rang: int = 0) -> Color:
	return COULEURS.get(id, REPLI[posmod(rang, REPLI.size())])

# ---- Lecture du modèle ----------------------------------------------------------------------------------------------

## Ligues avec classement : [{id, nom, rows triés, couleur}].
static func ligues(model: Dictionary) -> Array:
	var out: Array = []
	for l: Variant in model.get("leagues", []):
		if not l is Dictionary or (l.get("rows", []) as Array).is_empty(): continue
		var rows: Array = (l.rows as Array).duplicate()
		rows.sort_custom(func(a, b): return _n(a.get("points")) > _n(b.get("points")) or (_n(a.get("points")) == _n(b.get("points")) and _n(a.get("pf")) - _n(a.get("pa")) > _n(b.get("pf")) - _n(b.get("pa"))))
		out.append({"id": str(l.get("id", "")), "nom": str(l.get("name", "")), "rows": rows, "couleur": couleur(str(l.get("id", "")), out.size())})
	return out

## Clubs connus de la page, par identifiant texte.
static func index_clubs(model: Dictionary) -> Dictionary:
	var out := {}
	for c: Variant in model.get("catalogue", []):
		if c is Dictionary and c.has("id"): out[_cle_id(c.id)] = c
	for l: Variant in model.get("leagues", []):
		if not l is Dictionary: continue
		for c: Variant in l.get("rows", []):
			if c is Dictionary and c.has("id"): out[_cle_id(c.id)] = c
	var own: Variant = model.get("club")
	if own is Dictionary and own.has("id"): out[_cle_id(own.id)] = own
	return out

static func _ligue_du_club(ligs: Array, id: Variant) -> String:
	for l: Dictionary in ligs:
		if l.id in ["champions", "challenge"]: continue
		for c: Dictionary in l.rows:
			if _cle_id(c.get("id")) == _cle_id(id): return l.id
	return ""

static func _rang(ligs: Array, lid: String, id: Variant) -> int:
	for l: Dictionary in ligs:
		if l.id != lid: continue
		for k in (l.rows as Array).size():
			if _cle_id(l.rows[k].get("id")) == _cle_id(id): return k + 1
	return 0

## Jour du calendrier en nombre de jours (tourne les images d'un jour à l'autre) ; repli : semaine × 7.
static func jour(model: Dictionary) -> int:
	var meta: Dictionary = model.get("meta", {})
	var d := str(meta.get("calendarToday", meta.get("date", "")))
	if d.length() >= 10:
		var t := Time.get_unix_time_from_datetime_string(d.substr(0, 10) + "T12:00:00")
		if t > 0: return int(t / 86400)
	return int(_n(meta.get("week"))) * 7

static func _aujourdhui(model: Dictionary) -> String:
	var meta: Dictionary = model.get("meta", {})
	return str(meta.get("calendarToday", meta.get("date", "")))

static func _jours_entre(a: String, b: String) -> int:
	if a.length() < 10 or b.length() < 10: return 0
	return int((Time.get_unix_time_from_datetime_string(b.substr(0, 10) + "T12:00:00") - Time.get_unix_time_from_datetime_string(a.substr(0, 10) + "T12:00:00")) / 86400)

## Résultats des deux dernières dates jouées du monde (bandeau « Affiches du jour »), plus récents d'abord.
static func affiches(model: Dictionary) -> Array:
	var hist: Array = model.get("history", []).filter(func(r): return r is Dictionary and r.get("pair") is Array and r.get("score") is Array and r.get("date") is String)
	var dates := {}
	for r: Dictionary in hist: dates[r.date] = true
	var liste := dates.keys()
	liste.sort()
	var garde := liste.slice(maxi(0, liste.size() - 2))
	var out := hist.filter(func(r): return r.date in garde)
	out.sort_custom(func(a, b): return str(a.date) > str(b.date) or (str(a.date) == str(b.date) and str(a.get("fixtureId", "")) < str(b.get("fixtureId", ""))))
	return out

# ---- Journalistes ---------------------------------------------------------------------------------------------------

## Journaliste qui signe : un des médias du jeu couvrant la compétition, au style adapté au thème, tiré de façon stable.
static func journaliste(model: Dictionary, lid: String, theme: String, cle: String) -> Dictionary:
	var presse: Dictionary = model.get("monde", {}).get("presse", {}) if model.get("monde") is Dictionary else {}
	var liste: Array = presse.get(lid, [])
	if liste.is_empty():
		for k: Variant in presse.keys():
			if not (presse[k] as Array).is_empty():
				liste = presse[k]
				break
	if liste.is_empty(): return {}
	var voulus: Array = STYLES.get(theme, ["analyse", "technique"])
	var choix := liste.filter(func(j): return str(j.get("style", "")) in voulus)
	if choix.is_empty(): choix = liste
	return choix[graine(cle + ":" + theme) % choix.size()]

static func _titre(theme: String, style: String, a: String, b: String, n: Variant) -> String:
	var t: Dictionary = TITRES.get(theme, {})
	var modele := str(t.get(style, t.get("analyse", "{a}")))
	return modele.replace("{a}", a).replace("{b}", b).replace("{n}", str(n))

# ---- Articles -------------------------------------------------------------------------------------------------------

static func _nom(clubs: Dictionary, id: Variant) -> String:
	var c: Dictionary = clubs.get(_cle_id(id), {})
	return G.club_name(c) if not c.is_empty() else "?"

static func _essais_origine(r: Dictionary, cote: int, origine: String) -> int:
	var n := 0
	for e: Variant in r.get("essais", []):
		if e is Array and (e as Array).size() >= 3 and int(_n(e[1])) == cote and str(e[2]) == origine: n += 1
	return n

static func _stat(r: Dictionary, cote: int, cle: String) -> float:
	var s: Variant = r.get("stats")
	if not s is Array or (s as Array).size() < 2 or not s[cote] is Dictionary: return 0.0
	return _n(s[cote].get(cle))

## Articles d'un résultat, un par angle (exploit, raclée, finish, conquête, pied, défense, essais), du point de vue du club
## suivi (le nôtre s'il joue ; sinon le vainqueur, ou le leader battu). La page n'en garde qu'un par rencontre (`sujet`) :
## quand un thème est déjà assez présent, un autre angle de la même rencontre prend la place.
static func _articles_resultat(model: Dictionary, ligs: Array, clubs: Dictionary, r: Dictionary, lid: String) -> Array:
	var s: Array = r.score
	var g := 0 if _n(s[0]) >= _n(s[1]) else 1
	var p := 1 - g
	var e := int(absf(_n(s[0]) - _n(s[1])))
	var nous := _cle_id(model.get("club", {}).get("id", "-"))
	var rg := _rang(ligs, lid, r.pair[g])
	var rp := _rang(ligs, lid, r.pair[p])
	var t: Array = r.get("tries", [0, 0]) if r.get("tries") is Array else [0, 0]
	var essais := int(_n(t[0]) + _n(t[1]))
	var cands: Array = []  # [priorité, thème, club mis en avant (côté), chiffre, pastilles]
	var score_txt := "%d – %d" % [int(_n(s[g])), int(_n(s[p]))]
	# Notre match : victoire ou défaite, large ou serrée, de notre point de vue.
	for k in 2:
		if _cle_id(r.pair[k]) == nous and e > 0:
			var th := ("victoire-large" if e >= 15 else "victoire-serree") if k == g else ("defaite-lourde" if e >= 15 else "defaite-courte")
			cands.append([9, th, k, score_txt, []])
	if e > 0 and rp == 1 and rg > 1:
		cands.append([7, "defaite-courte" if e <= 7 else "defaite-lourde", p, score_txt, []])
	if e > 0 and rg > 0 and rp > 0 and rg >= rp + 5:
		cands.append([6, "victoire-serree" if e <= 7 else "victoire-large", g, score_txt, []])
	if e >= 25: cands.append([4, "victoire-large", g, "+%d" % e, []])
	if e > 0 and e <= 3: cands.append([3, "victoire-serree", g, score_txt, []])
	if e >= 20 and rp > 0 and rp <= 3: cands.append([5, "defaite-lourde", p, "−%d" % e, []])
	if e > 0 and e <= 3 and rp > 0 and rp <= 3: cands.append([4, "defaite-courte", p, score_txt, []])
	var maul := _essais_origine(r, g, "b")
	if maul >= 2: cands.append([4, "ballon-porte", g, maul, [["%d essais sur ballon porté" % maul, "tactic"]]])
	var penal_melee := 0.0
	var fam: Variant = r.stats[p].get("penaltyFamilies") if r.get("stats") is Array and (r.stats as Array).size() == 2 and r.stats[p] is Dictionary else null
	if fam is Dictionary: penal_melee = _n(fam.get("melee"))
	var melees_g := _stat(r, g, "scrumsWon")
	if penal_melee >= 3 or _essais_origine(r, g, "m") >= 1:
		cands.append([4, "melee", g, int(melees_g), [["Mêlées %d/%d" % [int(melees_g), int(_stat(r, g, "scrums"))], "shield"], ["%d pénalités en mêlée" % int(penal_melee), "warning"]]])
	var touches_g := _stat(r, g, "lineoutsWon")
	var touches_p := _stat(r, p, "lineouts")
	if touches_g >= 10 and touches_p > 0 and _stat(r, p, "lineoutsWon") / touches_p < 0.8:
		cands.append([4, "touche", g, int(touches_g), [["Touches %d/%d" % [int(touches_g), int(_stat(r, g, "lineouts"))], "flag"]]])
	var buts := _stat(r, g, "goals")
	if buts >= 3 and _n(t[g]) <= 2:
		cands.append([4, "penalite", g, int(buts), [["Pénalités %d/%d" % [int(buts), int(_stat(r, g, "goalAttempts"))], "target"]]])
	if e > 0 and (_n(s[p]) <= 10 or _n(t[p]) == 0):
		cands.append([4, "plaquage", g, int(_n(s[p])), [["%d essai encaissé" % int(_n(t[p])) if int(_n(t[p])) <= 1 else "%d essais encaissés" % int(_n(t[p])), "shield"]]])
	if essais >= 9: cands.append([4, "essai", g, essais, []])
	if cands.is_empty():
		cands.append([1, "victoire-large" if e >= 15 else "victoire-serree" if e > 0 else "plaquage", g, score_txt, []])
	var notre_ligue := lid == str(model.get("meta", {}).get("leagueId", ""))
	var out: Array = []
	for c: Array in cands:
		var cote: int = c[2]
		var theme: String = c[1]
		var cle := "res:" + str(r.get("fixtureId", "")) + ":" + theme
		var jn := journaliste(model, lid, theme, cle)
		var titre := _titre(theme, str(jn.get("style", "analyse")), _nom(clubs, r.pair[cote]), _nom(clubs, r.pair[1 - cote]), c[3])
		var pastilles: Array = [["%d essais" % essais, "ball"]]
		pastilles.append_array(c[4])
		if r.get("affluence") != null: pastilles.append(["%s spectateurs" % _milliers(int(_n(r.affluence))), "people"])
		out.append({"cle": cle, "sujet": "res:" + str(r.get("fixtureId", "")), "prio": int(c[0]) + (2 if notre_ligue else 0), "theme": theme, "titre": titre, "ligue": lid,
			"resultat": r, "clubs": [r.pair[cote], r.pair[1 - cote]], "personne": {}, "journaliste": jn, "pastilles": pastilles,
			"cible": {"kind": "fixture", "id": str(r.get("fixtureId", ""))}})
	return out
static func _derniers_resultats(model: Dictionary, lid: String) -> Array:
	var res: Array = model.get("history", []).filter(func(r): return r is Dictionary and r.get("pair") is Array and r.get("score") is Array and str(r.get("leagueId", r.get("competitionId", ""))) == lid)
	var dates := {}
	for r: Dictionary in res: dates[str(r.get("date", ""))] = true
	var tri := dates.keys()
	tri.sort()
	var garde := tri.slice(maxi(0, tri.size() - 2))
	var aujourdhui := _aujourdhui(model)
	# Une journée de plus de 10 jours ne fait plus l'actu.
	garde = garde.filter(func(d): return aujourdhui.length() < 10 or _jours_entre(str(d), aujourdhui) <= 10)
	return res.filter(func(r): return str(r.get("date", "")) in garde)

## Tous les articles candidats, triés du plus fort au plus faible (avant le choix de la page).
static func candidats(model: Dictionary) -> Array:
	var ligs := ligues(model)
	var clubs := index_clubs(model)
	var out: Array = []
	var aujourdhui := _aujourdhui(model)
	var affluence_max: Dictionary = {}
	for l: Dictionary in ligs:
		var jour_l := _derniers_resultats(model, l.id)
		for r: Dictionary in jour_l:
			out.append_array(_articles_resultat(model, ligs, clubs, r, l.id))
			if r.get("affluence") != null and _n(r.affluence) > _n(affluence_max.get("affluence", 0)): affluence_max = r
		var chef: Dictionary = l.rows[0]
		if _n(chef.get("played")) > 0:
			var cle: String = "chef:" + str(l.id) + ":" + _cle_id(chef.get("id"))
			var jn := journaliste(model, l.id, "presse", cle)
			out.append({"cle": cle, "prio": 3, "theme": "presse", "titre": _titre("presse", str(jn.get("style", "")), _nom(clubs, chef.id), "", int(_n(chef.get("points")))),
				"ligue": l.id, "resultat": {}, "clubs": [chef.id], "personne": {}, "journaliste": jn,
				"pastilles": [["%d pts" % int(_n(chef.get("points"))), "trophy"], ["%d victoires" % int(_n(chef.get("won"))), "check"]], "cible": {"kind": "competition", "id": l.id}})
			var suite: Variant = model.get("clubNext", {}).get(_cle_id(chef.get("id")))
			if suite is Dictionary and suite.get("opponent") is Dictionary and str(suite.get("date", "")) != "" and (aujourdhui.length() < 10 or _jours_entre(aujourdhui, str(suite.date)) in range(0, 8)):
				var adv: Dictionary = suite.opponent
				var dom: bool = suite.get("home", false)
				var a_id: Variant = chef.id if dom else adv.get("id")
				var b_id: Variant = adv.get("id") if dom else chef.id
				var cle2 := "affiche:" + _cle_id(a_id) + ":" + _cle_id(b_id) + ":" + str(suite.date)
				var jn2 := journaliste(model, l.id, "stade", cle2)
				out.append({"cle": cle2, "prio": 3, "theme": "stade", "titre": _titre("stade", str(jn2.get("style", "")), _nom(clubs, a_id), _nom(clubs, b_id), ""),
					"ligue": l.id, "resultat": {}, "clubs": [a_id, b_id], "personne": {}, "journaliste": jn2, "date": str(suite.date),
					"pastilles": [[str(suite.date).substr(8, 2) + "/" + str(suite.date).substr(5, 2), "calendar"]], "cible": {"kind": "club", "id": _cle_id(a_id)}})
		# Série noire : trois défaites de suite au moins (une seule par ligue, la plus longue).
		var pire: Dictionary = {}
		var pire_n := 0
		for c: Dictionary in l.rows:
			var f: Array = c.get("form", []) if c.get("form") is Array else []
			var n := 0
			for k in range(f.size() - 1, -1, -1):
				if str(f[k]) in ["D", "L"]: n += 1
				else: break
			if n > pire_n:
				pire_n = n
				pire = c
		if pire_n >= 3:
			var cle3: String = "serie:" + str(l.id) + ":" + _cle_id(pire.get("id")) + ":" + str(pire_n)
			var jn3 := journaliste(model, l.id, "entrainement", cle3)
			out.append({"cle": cle3, "prio": 3, "theme": "entrainement", "titre": _titre("entrainement", str(jn3.get("style", "")), _nom(clubs, pire.id), "", pire_n),
				"ligue": l.id, "resultat": {}, "clubs": [pire.id], "personne": {}, "journaliste": jn3,
				"pastilles": [["%d défaites" % pire_n, "warning"], ["%de" % _rang(ligs, l.id, pire.id), "trophy"]], "cible": {"kind": "club", "id": _cle_id(pire.id)}})
	if not affluence_max.is_empty() and _n(affluence_max.affluence) >= 10000:
		var r: Dictionary = affluence_max
		var lid := str(r.get("leagueId", r.get("competitionId", "")))
		var cle4 := "foule:" + str(r.get("fixtureId", ""))
		var jn4 := journaliste(model, lid, "supporters", cle4)
		out.append({"cle": cle4, "sujet": "res:" + str(r.get("fixtureId", "")), "prio": 3, "theme": "supporters", "titre": _titre("supporters", str(jn4.get("style", "")), _nom(clubs, r.pair[0]), _nom(clubs, r.pair[1]), _milliers(int(_n(r.affluence)))),
			"ligue": lid, "resultat": r, "clubs": [r.pair[0], r.pair[1]], "personne": {}, "journaliste": jn4,
			"pastilles": [["%s spectateurs" % _milliers(int(_n(r.affluence))), "people"]], "cible": {"kind": "fixture", "id": str(r.get("fixtureId", ""))}})
	var monde: Dictionary = model.get("monde", {}) if model.get("monde") is Dictionary else {}
	for tr: Variant in transferts_recents(model):
		var x: Dictionary = tr
		var lid := _ligue_du_club(ligs, x.get("acheteurId"))
		var cle5 := "transfert:" + str(x.get("playerId", "")) + ":" + str(x.get("date", ""))
		var jn5 := journaliste(model, lid, "transfert", cle5)
		var montant := int(_n(x.get("montant")))
		out.append({"cle": cle5, "prio": 4 if montant > 0 else 2, "theme": "transfert", "titre": _titre("transfert", str(jn5.get("style", "")), _nom(clubs, x.acheteurId), str(x.get("nom", "")), ""),
			"ligue": lid, "resultat": {}, "clubs": [x.get("acheteurId"), x.get("vendeurId")], "personne": _personne(x, "playerId", "nom"), "journaliste": jn5, "transfert": x,
			"pastilles": [[_montant(montant) if montant > 0 else "Libre", "money"], [str(x.get("pos", "")), ""]], "cible": {"kind": "club", "id": _cle_id(x.get("acheteurId"))}})
	var nb := 0
	for b: Variant in monde.get("blessures", []):
		if nb >= 4 or not b is Dictionary: break
		var lid := _ligue_du_club(ligs, b.get("clubId"))
		var cle6 := "blessure:" + str(b.get("id", "")) + ":" + str(int(_n(b.get("weeks"))))
		var jn6 := journaliste(model, lid, "blessure", cle6)
		out.append({"cle": cle6, "prio": 3, "theme": "blessure", "titre": _titre("blessure", str(jn6.get("style", "")), _nom(clubs, b.get("clubId")), str(b.get("name", "")), int(_n(b.get("weeks")))),
			"ligue": lid, "resultat": {}, "clubs": [b.get("clubId")], "personne": _personne(b, "id", "name"), "journaliste": jn6,
			"pastilles": [["%d semaines" % int(_n(b.get("weeks"))), "heart"], [str(b.get("pos", "")), ""]], "cible": {"kind": "club", "id": _cle_id(b.get("clubId"))}})
		nb += 1
	out.sort_custom(func(a, b): return int(a.prio) > int(b.prio) or (int(a.prio) == int(b.prio) and graine(str(a.cle)) < graine(str(b.cle))))
	return out

static func _personne(x: Dictionary, cle_id: String, cle_nom: String) -> Dictionary:
	var p := {"id": str(x.get(cle_id, "")), "name": str(x.get(cle_nom, "")), "pos": str(x.get("pos", ""))}
	for k in ["age", "sourcePlayerId", "appearanceId", "appearanceAge", "appearanceBankVersion", "appearanceBuild"]:
		if x.has(k) and x[k] != null: p[k] = x[k]
	return p

static func _milliers(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

static func _montant(n: int) -> String:
	if n >= 1000000: return ("%.1f M€" % (n / 1000000.0)).replace(".", ",")
	if n >= 1000: return "%d k€" % int(round(n / 1000.0))
	return "%d €" % n

## Transferts entre clubs adverses des 30 derniers jours, plus gros d'abord (montant, puis date). Hors période des
## mutations (mai-juin) et des pré-contrats (janvier-juin), le moteur en conclut peu : la fenêtre reste large.
static func transferts_recents(model: Dictionary) -> Array:
	var monde: Dictionary = model.get("monde", {}) if model.get("monde") is Dictionary else {}
	var aujourdhui := _aujourdhui(model)
	var liste: Array = (monde.get("transferts", []) as Array).filter(func(x): return x is Dictionary and (aujourdhui.length() < 10 or str(x.get("date", "")).length() < 10 or _jours_entre(str(x.date), aujourdhui) <= 30))
	liste.sort_custom(func(a, b): return _n(a.get("montant")) > _n(b.get("montant")) or (_n(a.get("montant")) == _n(b.get("montant")) and str(a.get("date", "")) > str(b.get("date", ""))))
	return liste

## Carte « Dernière minute » : le plus gros transfert payant entre clubs adverses des 30 derniers jours, {} sinon.
static func derniere_minute(model: Dictionary, articles: Array) -> Dictionary:
	var aujourdhui := _aujourdhui(model)
	for a: Dictionary in articles:
		if a.theme != "transfert" or not a.has("transfert"): continue
		var x: Dictionary = a.transfert
		if _n(x.get("montant")) <= 0: continue
		if aujourdhui.length() >= 10 and str(x.get("date", "")).length() >= 10 and _jours_entre(str(x.date), aujourdhui) > 30: continue
		return a
	return {}

## Page du jour : {une, derniere, cartes, liste} ; choix glouton : un article par sujet (rencontre, joueur, club), au plus
## PAR_THEME articles d'un même thème (au-delà, seulement s'il ne reste rien d'autre), un thème neuf favorisé, puis images.
static func page(model: Dictionary) -> Dictionary:
	var tous := candidats(model)
	var dm := derniere_minute(model, tous)
	var sujets := {}
	if not dm.is_empty(): sujets[_sujet(dm)] = true
	var reste := tous.filter(func(a): return not sujets.has(_sujet(a)))
	var pris: Array = []
	var compte := {}
	if not dm.is_empty(): compte[dm.theme] = 1
	var max_n := UNE + CARTES + LISTE
	for passe in 2:
		while pris.size() < max_n:
			var meilleur := -1
			var score := -1.0e9
			for k in reste.size():
				var a: Dictionary = reste[k]
				if sujets.has(_sujet(a)): continue
				var n := int(compte.get(a.theme, 0))
				if passe == 0 and n >= PAR_THEME: continue
				var sc := float(a.prio) * 10.0 - 7.0 * float(n) + (8.0 if n == 0 else 0.0)
				if sc > score:
					score = sc
					meilleur = k
			if meilleur < 0: break
			var a2: Dictionary = reste.pop_at(meilleur)
			compte[a2.theme] = int(compte.get(a2.theme, 0)) + 1
			sujets[_sujet(a2)] = true
			pris.append(a2)
	# La une parle de notre championnat quand un article fort (priorité 5 et plus) y est.
	var nous := str(model.get("meta", {}).get("leagueId", ""))
	for k in pris.size():
		if str(pris[k].ligue) == nous and int(pris[k].prio) >= 5:
			if k > 0: pris.push_front(pris.pop_at(k))
			break
	var ordre: Array = []
	if not pris.is_empty(): ordre.append(pris[0])
	if not dm.is_empty(): ordre.append(dm)
	ordre.append_array(pris.slice(1))
	images(model, ordre)
	return {"une": pris[0] if not pris.is_empty() else {}, "derniere": dm, "cartes": pris.slice(1, 1 + CARTES), "liste": pris.slice(1 + CARTES), "tous": ordre}

static func _sujet(a: Dictionary) -> String:
	return str(a.get("sujet", a.get("cle", "")))

## Variante d'image de chaque article (champ `image`), dans l'ordre d'affichage : rang dans le thème + rotation du jour.
static func images(model: Dictionary, ordre: Array) -> void:
	var d := jour(model)
	var rang := {}
	for a: Dictionary in ordre:
		var th: String = a.theme
		var r := int(rang.get(th, 0))
		rang[th] = r + 1
		var v := posmod(3 * d + d / 2 + graine(th) % VARIANTES + r, VARIANTES) + 1
		a.image = "actu-%s-%d" % [th, v]

# ---- Images ---------------------------------------------------------------------------------------------------------

static var _cache: Dictionary = {}
static var _ordre_cache: Array = []

static func chemin(id: String) -> String:
	return DOSSIER + id + ".webp"

## Texture d'une image de la banque des actus (cache des 24 dernières) ; null si absente.
static func texture(id: String) -> Texture2D:
	if _cache.has(id): return _cache[id]
	var path := chemin(id)
	var tex: Texture2D = null
	if ResourceLoader.exists(path): tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		# Dossier pas encore importé (jeu exporté sans import, ou ajouté après l'import) : lecture directe.
		var image := Image.new()
		if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK: tex = ImageTexture.create_from_image(image)
	if tex == null: return null
	_cache[id] = tex
	_ordre_cache.append(id)
	while _ordre_cache.size() > 24: _cache.erase(_ordre_cache.pop_front())
	return tex
