extends RefCounted
## Fenêtre d'un joueur en match (idée n° 32 de la revue FM27 de Léo, choix final du 23/11/2026).
## Clic sur une carte de Mon XV : petite fenêtre en ardoise claire (teinte D), environ deux tiers de la planche, qui se
## détache nettement du direct ; le match CONTINUE derrière (aucune pause). Contenu :
## - la mini-fiche : portrait, drapeau et nationalité, âge, taille, poids, note du match, énergie, moral, qualités clés et
##   utiles du rôle, responsabilités « En charge » (buteur, lanceur, botteur…) ;
## - le poste : familiarité en barres + note au poste /100, petit terrain des 15 postes coloré en familiarité ;
## - le rôle (trois rôles du poste) et les consignes individuelles (deux au plus).
## Un clic choisit et valide (aucun bouton Confirmer) : le changement part dans la file du prochain arrêt de jeu du
## moteur (`file_arret`, `set_role_direct`, native/engine/match-arrets.cjs) ; « ⧗ » le signale discrètement jusqu'à
## l'arrêt. Aucun remplacement ici : ils restent dans la fenêtre Équipe. Aucun effet chiffré (principe d'incertitude).
## La carte sortant (rouge) / entrant (vert) d'un remplacement s'affiche sur la phrase de jeu, jamais sur le terrain 2D,
## avec le vrai numéro de feuille de l'entrant (16 à 23).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const S = preload("res://ui/contextual/skin.gd")
const Charte = preload("res://ui/charte.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const Roles = preload("res://ui/immersive08/fiche_roles.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const Identity = preload("res://ui/player_identity.gd")

const NOM := "MatchMenuJoueur"
const LARGEUR := 1200.0
const HAUTEUR := 720.0
const POSTES := ["Pilier G", "Talonneur", "Pilier D", "2e ligne", "2e ligne", "3e ligne", "3e ligne", "Numéro 8",
	"Demi mêlée", "Ouvreur", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
## Moral de départ d'un joueur sans fiche de moral (même table que dist/match-pilotage.js).
const MORAL_DEPART := {"galvanise": 72, "motive": 64, "serein": 60, "indifferent": 50, "tendu": 40, "vexe": 36, "relache": 44}
const PALIERS := [[78, "gonfle", "Gonflé à bloc"], [62, "confiant", "Confiant"], [42, "concentre", "Concentré"], [28, "inquiet", "Inquiet"], [0, "abattu", "Abattu"]]
## Places des 15 postes sur le petit terrain, attaque vers le haut.
const PLACES := [Vector2(.22, .90), Vector2(.5, .90), Vector2(.78, .90), Vector2(.39, .78), Vector2(.61, .78),
	Vector2(.16, .68), Vector2(.84, .68), Vector2(.5, .66), Vector2(.36, .53), Vector2(.6, .47), Vector2(.1, .2),
	Vector2(.38, .32), Vector2(.62, .32), Vector2(.9, .2), Vector2(.5, .1)]
## Ardoise claire (teinte D retenue par Léo) : fond, cases, filets, encres.
const PAL := {"fond": Color("3a4947"), "case": Color("445350"), "choisi": Color("2f5a46"), "filet": Color(0.949, 0.925, 0.863, .16),
	"encre": Color("f2ecdc"), "encre2": Color("abb7b1"), "encre3": Color("a7b0aa"), "accent": Color("d7aa5a"),
	"rail": Color(0.949, 0.925, 0.863, .18), "bord": Color(0.949, 0.925, 0.863, .40)}

static func teinte_moral(cle: String) -> Color:
	match cle:
		"gonfle": return Charte.NOTE_EXCELLENTE
		"confiant": return Charte.CONDITION
		"inquiet": return Charte.INTENSIF
		"abattu": return Charte.PERTE
	return Charte.MORAL

static func teinte_energie(e: float) -> Color:
	return Charte.CONDITION if e >= 75.0 else Charte.INTENSIF if e >= 55.0 else Charte.PERTE

# --- Données ---------------------------------------------------------------------------------------------------------

## Moral en direct (`live.pilotage.moral`), sinon départ d'après la réaction à la causerie.
static func moral(pilotage: Dictionary, id: String) -> Dictionary:
	var tous: Variant = pilotage.get("moral")
	if tous is Dictionary and (tous as Dictionary).get(id) is Dictionary:
		var m: Dictionary = tous[id]
		return {"valeur": int(m.get("valeur", 50)), "cle": str(m.get("cle", "")), "label": str(m.get("label", ""))}
	var etats: Variant = pilotage.get("joueurs")
	var etat: Dictionary = (etats as Dictionary).get(id, {}) if etats is Dictionary and (etats as Dictionary).get(id) is Dictionary else {}
	var v := int(MORAL_DEPART.get(str(etat.get("etat", "")), 50))
	for p: Array in PALIERS:
		if v >= int(p[0]): return {"valeur": v, "cle": p[1], "label": p[2]}
	return {"valeur": v, "cle": "concentre", "label": "Concentré"}

static func note_poste(joueur: Dictionary, numero: int) -> float:
	var notes: Variant = joueur.get("positionRatings")
	if not notes is Dictionary: return -1.0
	var n: Variant = (notes as Dictionary).get(str(numero))
	return float(n) if (n is float or n is int) and float(n) >= 0.0 else -1.0

static func _complet(app: Control, joueur: Dictionary) -> Dictionary:
	var trouve: Dictionary = Commune.trouver(app, str(joueur.get("id", "")), "squad")
	var complet: Dictionary = (trouve.joueur as Dictionary).duplicate() if not trouve.is_empty() else {}
	complet.merge(joueur, true)
	return complet

## File du prochain arrêt, rôles et consignes individuelles du moteur (`live.pilotage.arrets`).
static func arrets(live: Dictionary) -> Dictionary:
	var p: Variant = live.get("pilotage")
	var a: Variant = p.get("arrets") if p is Dictionary else null
	return a if a is Dictionary else {}

## Changements en attente qui concernent le joueur `id` : {cle: entrée}.
static func attentes(live: Dictionary, id: String) -> Dictionary:
	var r := {}
	for e: Variant in arrets(live).get("file", []) if arrets(live).get("file") is Array else []:
		if not e is Dictionary: continue
		var t := str(e.get("type", ""))
		if (t in ["role", "consignes"] and str(e.get("id", "")) == id) or (t == "remplacement" and str(e.get("outId", "")) == id) or (t == "responsabilite" and str(e.get("id", "")) == id):
			r[str(e.cle)] = e
	return r

## Vrai numéro de feuille du joueur (1 à 23, `live.numeros`), sinon celui du poste.
static func numero_feuille(live: Dictionary, id: String, repli: int) -> int:
	var n: Variant = live.get("numeros", {}).get(id) if live.get("numeros") is Dictionary else null
	return int(n) if n is int or n is float else repli

## Tout ce que montre la fenêtre pour le joueur `id` (titulaire).
static func donnees(view: Control, id: String) -> Dictionary:
	var live: Dictionary = view._live()
	var lineup: Array = live.get("lineup", []) if live.get("lineup") is Array else []
	var slot := -1
	for i in lineup.size():
		if lineup[i] is Dictionary and str(lineup[i].get("id", "")) == id: slot = i
	if slot < 0: return {}
	var poste := slot + 1
	var joueur := _complet(view.app, lineup[slot])
	var pilotage: Dictionary = live.get("pilotage", {}) if live.get("pilotage") is Dictionary else {}
	var direct: Dictionary = live.get("direct", {}) if live.get("direct") is Dictionary else {}
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var d := Tableau.donnees_joueur(joueur, notes, {}, {})
	var valeurs: Dictionary = Commune.valeurs(joueur, "squad")
	var a := arrets(live)
	var file := attentes(live, id)
	var roles: Array = []
	for r: Array in Roles.roles_famille(Roles.FAMILLE[slot]):
		roles.append({"id": r[0], "nom": r[2], "note": Roles.note_role(valeurs, r)})
	var moteur: Dictionary = a.get("roles", {}).get(id, {}) if a.get("roles") is Dictionary and a.roles.get(id) is Dictionary else {}
	var role := str(moteur.get("role", "")) if moteur.get("role") != null else ""
	if role.is_empty(): role = Roles.meilleur_role(valeurs, poste)
	var role_attente := ""
	if file.has("role:" + id): role_attente = str(file["role:" + id].get("role", "")) if file["role:" + id].get("role") != null else str(moteur.get("naturel", ""))
	var siennes: Array = a.get("consignes", {}).get(id, []) if a.get("consignes") is Dictionary and a.consignes.get(id) is Array else []
	var voulues: Array = (file["consignes:" + id].get("valeurs", []) as Array) if file.has("consignes:" + id) else siennes
	var catalogue: Array = a.get("catalogue", {}).get(famille_consignes(poste), []) if a.get("catalogue") is Dictionary else []
	# Responsabilités en direct (pilotage.roles) : en charge ? demande en attente ?
	var resp: Array = []
	var source: Variant = pilotage.get("roles")
	for r: Variant in (source.get("roles") if source is Dictionary and source.get("roles") is Array else []):
		if not r is Dictionary: continue
		var en_jeu: Variant = r.get("enJeu")
		var charge := en_jeu is Dictionary and str(en_jeu.get("id", "")) == id
		var attente := false
		for e: Variant in a.get("file", []) if a.get("file") is Array else []:
			if e is Dictionary and str(e.get("type", "")) == "responsabilite" and str(e.get("role", "")) == str(r.get("id", "")) and (str(e.get("id", "")) == id or charge): attente = true
		resp.append({"id": str(r.get("id", "")), "nom": str(r.get("label", "")), "charge": charge, "attente": attente})
	var sortie: Dictionary = {}
	for e: Dictionary in file.values():
		if str(e.get("type", "")) == "remplacement": sortie = e
	return {"id": id, "slot": slot, "poste": poste, "numero": numero_feuille(live, id, poste), "joueur": joueur,
		"energie": clampf(float(d.energie), 0.0, 100.0), "moral": moral(pilotage, id), "note": float(d.note), "note_connue": notes.has(id),
		"familiarite": Familiarite.niveau(joueur, poste), "note_poste": note_poste(joueur, poste), "roles": roles, "role": role,
		"role_attente": role_attente, "consignes": siennes, "voulues": voulues, "consignes_attente": file.has("consignes:" + id),
		"catalogue": catalogue, "exclusions": (a.get("exclusions", {}).get(famille_consignes(poste), []) if a.get("exclusions") is Dictionary else []),
		"max": int(a.get("maxConsignes", 2)), "responsabilites": resp, "sortie": sortie, "file": file, "actif": not a.is_empty()}

static func famille_consignes(poste: int) -> String:
	if poste <= 8: return "avant"
	match poste:
		9: return "demi"
		10: return "ouvreur"
		15: return "arriere"
	return "trois"

## Empreinte de ce que montre la fenêtre : elle se redessine quand le match la change (arrêt de jeu, énergie, moral).
static func signature(view: Control, id: String) -> String:
	var d := donnees(view, id)
	if d.is_empty(): return ""
	return JSON.stringify([d.role, d.role_attente, d.consignes, d.voulues, roundi(float(d.energie) / 2.0), d.moral.label, d.note, d.note_connue, d.responsabilites, d.sortie.keys(), d.slot])

# --- Actions (un clic choisit et valide) ----------------------------------------------------------------------------------

static func choisir_role(view: Control, d: Dictionary, role_id: String) -> void:
	if not bool(d.actif): return
	_envoyer(view, str(d.id), "file_arret", {"action": "ajouter", "change": {"type": "role", "id": str(d.id), "role": role_id}})

## Une consigne de plus ou de moins : sa contraire part, deux consignes au plus (la plus ancienne cède).
static func choisir_consigne(view: Control, d: Dictionary, consigne: String) -> void:
	if not bool(d.actif): return
	var voulues: Array = (d.voulues as Array).duplicate()
	if consigne in voulues: voulues.erase(consigne)
	else:
		for paire: Variant in d.exclusions:
			if paire is Array and consigne in paire:
				for autre: Variant in paire:
					if str(autre) != consigne: voulues.erase(str(autre))
		voulues.append(consigne)
		while voulues.size() > int(d.max): voulues.remove_at(0)
	_envoyer(view, str(d.id), "file_arret", {"action": "ajouter", "change": {"type": "consignes", "id": str(d.id), "valeurs": voulues}})

static func choisir_responsabilite(view: Control, d: Dictionary, r: Dictionary) -> void:
	_envoyer(view, str(d.id), "set_role_direct", {"role": str(r.id), "id": null if bool(r.charge) else str(d.id)})

static func _envoyer(view: Control, id: String, commande: String, charge: Dictionary) -> void:
	if view.app._command(commande, charge): _suivre(view, id)

## Redessine la fenêtre dès que la réponse du moteur est là.
static func _suivre(view: Control, id: String) -> void:
	var tree := view.get_tree()
	var attendre := func(rappel: Callable) -> void:
		if not is_instance_valid(view) or not view.fenetre_ouverte(): return
		if bool(view.app.waiting):
			tree.process_frame.connect(rappel.bind(rappel), CONNECT_ONE_SHOT)
			return
		ouvrir(view, id, null)
	tree.process_frame.connect(attendre.bind(attendre), CONNECT_ONE_SHOT)

# --- Ouverture ------------------------------------------------------------------------------------------------------------

## Point d'entrée : clic sur une carte de la bande Mon XV. Le match continue.
static func ouvrir(view: Control, id: String, _ancre: Control) -> void:
	var d := donnees(view, id)
	if d.is_empty():
		if view.fenetre_ouverte() and view.fenetre_hote.find_child(NOM, true, false) != null: view.fermer_fenetre()
		return
	var p := PAL
	var j: Dictionary = d.joueur
	var poste := int(d.poste)
	var fond: Panel = view._ouvrir_fenetre(NOM, "", LARGEUR, HAUTEUR, false)
	fond.set_meta("player_id", id)
	var style := Charte.style_panneau(p.fond, Charte.RAYON_PANNEAU)
	style.border_color = p.bord
	style.set_border_width_all(maxi(1, C.px(2)))
	style.shadow_color = Color(0, 0, 0, .65)
	style.shadow_size = maxi(8, C.px(36))
	fond.add_theme_stylebox_override("panel", style)
	var croix := fond.find_child(NOM + "Fermer", false, false) as Button
	if croix != null:
		croix.add_theme_color_override("font_color", p.encre2)
		croix.add_theme_color_override("font_hover_color", p.encre)
	# Veille : la fenêtre suit le match (arrêt de jeu, énergie, moral) sans le mettre en pause.
	var veille := Timer.new()
	veille.name = "MatchMenuJoueurVeille"
	veille.wait_time = 0.4
	veille.autostart = true
	veille.ignore_time_scale = true
	fond.add_child(veille)
	var empreinte := signature(view, id)
	veille.timeout.connect(func():
		if bool(view.app.waiting): return
		if signature(view, id) != empreinte: ouvrir(view, id, null))
	_colonne_fiche(view, fond, d, p)
	_deco(fond, Rect2(28 + 470 + 14, 28, 2, HAUTEUR - 56), p.filet)
	_colonne_poste(fond, d, p)
	_deco(fond, Rect2(528 + 300 + 14, 28, 2, HAUTEUR - 56), p.filet)
	_colonne_role(view, fond, d, p)
	view.director._refresh_controls()

## Colonne 1 : la mini-fiche du joueur.
static func _colonne_fiche(view: Control, fond: Panel, d: Dictionary, p: Dictionary) -> void:
	var j: Dictionary = d.joueur
	var x1 := 28.0
	var w1 := 470.0
	var cadre := D.rect(fond, Rect2(x1, 28, 150, 150), p.case, Charte.RAYON_CARTE)
	cadre.name = "MatchMenuJoueurPortrait"
	cadre.clip_contents = true
	var image: TextureRect = S.G.portrait_lazy(int(j.get("portraitIndex", 0)), C.px(150), j)
	image.tooltip_text = ""
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2.ZERO
	cadre.add_child(image)
	D.place(image, Rect2(0, 0, 150, 150))
	var maillot := D.rect(fond, Rect2(x1 + 8, 134, 48, 38), Charte.VERT_FRANC, Charte.RAYON_PETIT)
	maillot.name = "MatchMenuJoueurNumero"
	D.text(maillot, 24, 29, str(int(d.numero)), 26, Charte.CREME, 800, 48, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_EXTRA)
	var tx := x1 + 150.0 + 20.0
	var tw := x1 + w1 - tx
	var nom := D.text(fond, tx, 66, str(j.get("name", "—")).to_upper(), 32, p.encre, 800, tw)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.name = "MatchMenuJoueurNom"
	nom.clip_text = true
	D.text(fond, tx, 98, "%s  ·  n° %d" % [POSTES[int(d.poste) - 1], int(d.numero)], 19, p.encre2, 700, tw)
	var facts: Dictionary = j.get("playerFacts", {}) if j.get("playerFacts") is Dictionary else {}
	var ox := tx
	var drapeau: Texture2D = Identity.flag_texture(str(facts.get("flagCode", ""))) if facts.get("flagCode") is String else null
	if drapeau != null:
		var fl := TextureRect.new()
		fl.name = "MatchMenuJoueurDrapeau"
		fl.texture = drapeau
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fond.add_child(fl)
		D.place(fl, Rect2(ox, 116, 30, 20))
		ox += 40.0
	var origine: Array[String] = []
	if facts.get("nationality") is String and not str(facts.nationality).is_empty(): origine.append(str(facts.nationality))
	if j.get("age") is int or j.get("age") is float: origine.append("%d ans" % int(j.age))
	D.text(fond, ox, 134, "  ·  ".join(origine), 19, p.encre, 700, x1 + w1 - ox).name = "MatchMenuJoueurOrigine"
	var corps: Array[String] = []
	if facts.get("heightCm") is int or facts.get("heightCm") is float: corps.append(("%.2f m" % (float(facts.heightCm) / 100.0)).replace(".", ","))
	if facts.get("weightKg") is int or facts.get("weightKg") is float: corps.append("%d kg" % int(facts.weightKg))
	D.text(fond, tx, 166, "  ·  ".join(corps), 19, p.encre2, 700, tw).name = "MatchMenuJoueurGabarit"
	# Sortie déjà demandée dans la fenêtre Équipe : rappel discret.
	if not (d.sortie as Dictionary).is_empty():
		var s: Dictionary = d.sortie
		_pilule(fond, tx, 182, "⧗ sort au prochain arrêt", true, "MatchMenuJoueurSortie", func(): pass, p)
		fond.find_child("MatchMenuJoueurSortieLien", true, false).tooltip_text = str(s.get("texte", ""))
	# État dans le match : note, énergie, moral.
	var lt := (w1 - 24.0) / 3.0
	for k in 3:
		var tuile := D.rect(fond, Rect2(x1 + k * (lt + 12.0), 232, lt, 80), p.case, Charte.RAYON_CARTE)
		tuile.name = ["MatchMenuJoueurNoteMatch", "MatchMenuJoueurEnergie", "MatchMenuJoueurMoral"][k]
		_surtitre(tuile, 14, 26, ["Note du match", "Énergie", "Moral"][k], p, lt - 20)
		match k:
			0:
				var nm := float(d.note)
				if d.note_connue: _plein(tuile, Rect2(14, 36, 72, 34), ("%.1f" % nm).replace(".", ","), Charte.couleur_note(nm), 21, "Note", Charte.encre_note(nm))
				else: _plein(tuile, Rect2(14, 36, 72, 34), "—", p.rail, 21, "Note", p.encre2)
			1:
				var e := float(d.energie)
				D.rect(tuile, Rect2(14, 50, lt - 92, 10), p.rail, 5)
				D.rect(tuile, Rect2(14, 50, maxf(6.0, (lt - 92) * e / 100.0), 10), teinte_energie(e), 5)
				D.text(tuile, lt - 14, 64, "%d %%" % roundi(e), 21, p.encre, 800, 62, HORIZONTAL_ALIGNMENT_RIGHT)
			2: _plein(tuile, Rect2(14, 36, lt - 28, 34), str(d.moral.label), teinte_moral(str(d.moral.cle)), 17, "Etat")
	# Qualités du rôle choisi : les 4 clés puis les 4 utiles, valeur en pastille colorée.
	var r := Roles.role(str(d.role))
	var valeurs: Dictionary = Commune.valeurs(j, "squad")
	_surtitre(fond, x1, 342, "Clés du rôle", p, 220)
	_surtitre(fond, x1 + 241, 342, "Utiles", p, 220)
	if r.size() >= 5:
		for k in 2:
			for i in 4:
				var cle := str(r[3 + k][i])
				var v: Variant = valeurs.get(cle)
				var ligne := D.rect(fond, Rect2(x1 + k * 241.0, 354 + i * 42.0, 229, 38), p.case if i % 2 == 0 else Color.TRANSPARENT, Charte.RAYON_PETIT)
				ligne.name = "MatchMenuJoueurAttribut_" + cle
				D.text(ligne, 12, 26, Roles.libelle(cle), 16, p.encre if k == 0 else p.encre2, 700 if k == 0 else 600, 160)
				if v is int or v is float: _plein(ligne, Rect2(229 - 52, 4, 46, 30), str(roundi(float(v))), Charte.couleur_attribut(float(v)), 18, "Valeur")
	# Responsabilités en direct (buteur, lanceur, botteur…) : au prochain arrêt.
	_surtitre(fond, x1, 554, "En charge", p)
	var resp: Array = []
	for rr: Dictionary in d.responsabilites:
		var rc := rr
		resp.append([("⧗ " if rr.attente else "") + str(rr.nom), bool(rr.charge), "Resp_" + str(rr.id), func(): choisir_responsabilite(view, d, rc)])
	_pilules(fond, x1, 566, w1, resp, p)

## Colonne 2 : le poste (familiarité, note au poste, petit terrain des 15 postes).
static func _colonne_poste(fond: Panel, d: Dictionary, p: Dictionary) -> void:
	var x2 := 528.0
	var w2 := 300.0
	_surtitre(fond, x2, 50, "Au poste · " + POSTES[int(d.poste) - 1], p, 220)
	_familiarite_c(fond, x2, 92, int(d.familiarite), 22, "MatchMenuJoueurFamiliarite", p)
	_note_c(fond, Rect2(x2 + w2 - 72, 56, 72, 42), float(d.note_poste), 28, "MatchMenuJoueurNotePoste", p)
	_petit_terrain(fond, Rect2(x2, 118, w2, 380), d.joueur, int(d.poste))

## Colonne 3 : le rôle (trois rôles du poste) et les consignes individuelles.
static func _colonne_role(view: Control, fond: Panel, d: Dictionary, p: Dictionary) -> void:
	var x3 := 858.0
	var w3 := LARGEUR - x3 - 28.0
	var titre := _surtitre(fond, x3, 50, "Rôle", p, 120)
	titre.name = "MatchMenuJoueurRoleTitre"
	if not str(d.role_attente).is_empty(): _attente(fond, x3 + w3, 32, "MatchMenuJoueurRoleAttente")
	var y := 62.0
	for ro: Dictionary in d.roles:
		var actif: bool = ro.id == d.role
		var voulu: bool = ro.id == d.role_attente and not actif
		var rid := str(ro.id)
		var l := _clic(fond, Rect2(x3, y, w3, 46), "MatchMenuJoueurRole_" + rid, func(): choisir_role(view, d, rid), p.choisi if actif else Color.TRANSPARENT, p, p.accent if voulu else Color.TRANSPARENT)
		if actif: _deco(l, Rect2(0, 8, 5, 30), p.accent, 2)
		D.text(l, 16, 31, ("⧗ " if voulu else "") + str(ro.nom), 19, p.accent if voulu else (p.encre if actif else p.encre2), 800 if actif or voulu else 600, w3 - 84)
		_note_c(l, Rect2(w3 - 58, 7, 52, 32), float(ro.note), 20, "Note", p)
		y += 52.0
	var ty := y + 34.0
	_surtitre(fond, x3, ty, "Consignes", p, 160).name = "MatchMenuJoueurConsignesTitre"
	if bool(d.consignes_attente): _attente(fond, x3 + w3, ty - 18, "MatchMenuJoueurConsignesAttente")
	var cons: Array = []
	for c: Variant in d.catalogue:
		if not c is Dictionary: continue
		var cid := str(c.get("id", ""))
		var applique: bool = cid in d.consignes
		var voulue: bool = cid in d.voulues
		var texte := str(c.get("label", cid))
		if voulue != applique: texte = "⧗ " + texte
		cons.append([texte, voulue, "Consigne_" + cid, func(): choisir_consigne(view, d, cid)])
	var bas := _pilules(fond, x3, ty + 14, w3, cons, p)
	if cons.is_empty(): D.text(fond, x3, ty + 44, "—", 19, p.encre2, 700, w3)
	# Rappel discret de ce qui attend l'arrêt de jeu, en une ligne par changement.
	var yy := maxf(bas + 30.0, HAUTEUR - 40.0 - 30.0 * (d.file as Dictionary).size())
	for e: Dictionary in (d.file as Dictionary).values():
		var ligne := D.text(fond, x3, yy, "⧗ " + str(e.get("texte", "")), 15, p.accent, 700, w3)
		ligne.name = "MatchMenuJoueurFile_" + str(e.get("type", ""))
		ligne.clip_text = true
		yy += 30.0

## Pastille dorée « ⧗ » alignée à droite (bord droit `x`).
static func _attente(parent: Control, x: float, y: float, nom: String) -> void:
	var w := 168.0
	var cadre := D.rect(parent, Rect2(x - w, y, w, 30), Charte.DORE, Charte.RAYON_PILULE)
	cadre.name = nom
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	D.text(cadre, w / 2.0, 21, "⧗ PROCHAIN ARRÊT", 14, Charte.ENCRE, 800, w, HORIZONTAL_ALIGNMENT_CENTER).add_theme_font_override("font", Charte.TITRE_EXTRA)

# --- Pièces ---------------------------------------------------------------------------------------------------------------

static func _surtitre(parent: Control, x: float, base: float, texte: String, p: Dictionary, largeur: float = 300.0) -> Label:
	return D.text(parent, x, base, texte.to_upper(), 15, p.encre3, 800, largeur)

static func _deco(parent: Control, zone: Rect2, couleur: Color, rayon: int = 0) -> Panel:
	var r := D.rect(parent, zone, couleur, rayon)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Pastille pleine : fond de couleur franche, chiffre ou mot à l'encre.
static func _plein(parent: Control, zone: Rect2, texte: String, fond: Color, taille: int, nom: String, encre: Color = Charte.ENCRE) -> Panel:
	var c := D.rect(parent, zone, fond, Charte.RAYON_PETIT)
	c.name = nom
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := D.text(c, zone.size.x / 2.0, zone.size.y / 2.0 + float(taille) * .36, texte, taille, encre, 800, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA)
	return c

static func _note_c(parent: Control, zone: Rect2, note: float, taille: int, nom: String, p: Dictionary) -> Panel:
	if note < 0.0: return _plein(parent, zone, "?", p.rail, taille, nom, p.encre2)
	return _plein(parent, zone, str(roundi(note)), Charte.couleur_attribut(note), taille, nom)

## Familiarité : barres de signal 5 crans + mot en petit. Renvoie la largeur posée.
static func _familiarite_c(parent: Control, x: float, base: float, n: int, taille: int, nom: String, p: Dictionary) -> float:
	var h := float(taille) * 1.05
	var cran := maxf(4.0, roundf(h * .26))
	var ecart := maxf(2.0, roundf(cran * .45))
	var boite := Control.new()
	boite.name = nom
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(boite)
	var l := 5.0 * cran + 4.0 * ecart
	D.place(boite, Rect2(x, base + 2.0 - h, l, h))
	var t := Familiarite.couleur(n)
	for i in 5:
		var hh := h * (.36 + .16 * float(i))
		_deco(boite, Rect2(float(i) * (cran + ecart), h - hh, cran, hh), t if n >= 0 and i <= n else p.rail, 2)
	D.text(parent, x + l + 8.0, base, Familiarite.mot(n), maxi(13, taille - 3), t, 800, 110).name = nom + "Mot"
	return l + 8.0 + 110.0

## Zone cliquable (fond, contour facultatif, survol à l'encre de la carte).
static func _clic(parent: Control, zone: Rect2, nom: String, action: Callable, fond: Color, p: Dictionary, contour: Color = Color.TRANSPARENT, rayon: int = Charte.RAYON_PETIT) -> Panel:
	var cadre := D.rect(parent, zone, fond, rayon, contour)
	cadre.name = nom
	var b := Button.new()
	b.name = nom + "Lien"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var survol := StyleBoxFlat.new()
	survol.bg_color = Color(p.encre, .08)
	survol.set_corner_radius_all(maxi(3, C.px(rayon)) if rayon < Charte.RAYON_PILULE else 999)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = p.accent
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(survol.corner_radius_top_left)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("focus", focus)
	b.accessibility_name = nom
	b.pressed.connect(action)
	cadre.add_child(b)
	D.place(b, Rect2(Vector2.ZERO, zone.size))
	return cadre

## Pilule à bascule (consigne, responsabilité) : pleine dorée quand elle est prise. Renvoie sa largeur.
static func _pilule(parent: Control, x: float, y: float, texte: String, actif: bool, nom: String, action: Callable, p: Dictionary) -> float:
	var w := _largeur_pilule(texte)
	var cadre := _clic(parent, Rect2(x, y, w, 38), nom, action, Charte.DORE if actif else p.case, p, Color.TRANSPARENT if actif else p.filet, Charte.RAYON_PILULE)
	D.text(cadre, w / 2.0, 26, texte, 17, Charte.ENCRE if actif else p.encre, 700, w, HORIZONTAL_ALIGNMENT_CENTER)
	return w

static func _largeur_pilule(texte: String) -> float:
	return C.font(700).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, C.font_px(17)).x / C.density + 36.0

## Pose des pilules en lignes dans `largeur` ; renvoie le bas.
static func _pilules(parent: Control, x: float, y: float, largeur: float, elements: Array, p: Dictionary) -> float:
	var xx := x
	var yy := y
	for e: Array in elements:
		var w := _largeur_pilule(str(e[0]))
		if xx > x and xx + w > x + largeur:
			xx = x
			yy += 46.0
		xx += _pilule(parent, xx, yy, str(e[0]), bool(e[1]), str(e[2]), e[3], p) + 10.0
	return yy + 38.0

## Petit terrain des 15 postes : disques numérotés à la couleur de la familiarité, poste du moment cerclé.
static func _petit_terrain(parent: Control, zone: Rect2, joueur: Dictionary, poste: int) -> void:
	var pelouse := D.rect(parent, zone, Color("2f6b3a"), Charte.RAYON_CARTE)
	pelouse.name = "MatchMenuJoueurTerrain"
	var bandes := 6
	for k in bandes:
		if k % 2 == 1: D.rect(pelouse, Rect2(0, zone.size.y * k / bandes, zone.size.x, zone.size.y / bandes), Color("357541"))
	D.line(pelouse, Vector2(0, zone.size.y * .5), Vector2(zone.size.x, zone.size.y * .5), Color(Charte.CREME, .45), 2)
	for k in [0.22, 0.78]: D.line(pelouse, Vector2(0, zone.size.y * k), Vector2(zone.size.x, zone.size.y * k), Color(Charte.CREME, .25), 2)
	var r := minf(zone.size.x, zone.size.y) * 0.08
	for n in range(1, 16):
		var pos: Vector2 = PLACES[n - 1] * zone.size
		var niveau := Familiarite.niveau(joueur, n)
		if n == poste:
			var anneau := D.rect(pelouse, Rect2(pos.x - r - 6, pos.y - r - 6, 2 * r + 12, 2 * r + 12), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.CREME)
			anneau.get_theme_stylebox("panel").set_border_width_all(maxi(2, C.px(4)))
		var rond := D.rect(pelouse, Rect2(pos.x - r, pos.y - r, 2 * r, 2 * r), Familiarite.couleur(niveau), Charte.RAYON_PILULE, Color(Charte.ENCRE, .35))
		rond.name = "Poste%d" % n
		rond.tooltip_text = "%d · %s · %s" % [n, POSTES[n - 1], Familiarite.mot(niveau)]
		rond.mouse_filter = Control.MOUSE_FILTER_PASS
		D.text(rond, r, r + 7, str(n), 18, Charte.ENCRE, 800, 2 * r, HORIZONTAL_ALIGNMENT_CENTER)

# --- Mon XV : changement en attente ----------------------------------------------------------------------------------------

## Pastille dorée « ⧗ » (ou « ⧗ 21 » pour un remplacement) en haut à droite de la carte de Mon XV d'un joueur concerné
## par un changement en attente du prochain arrêt de jeu.
static func badge_attente(carte: Control, texte: String, detail: String) -> void:
	if carte.find_child("MatchMenuJoueurAttenteBadge", false, false) != null: return
	var badge := PanelContainer.new()
	badge.name = "MatchMenuJoueurAttenteBadge"
	var st := StyleBoxFlat.new()
	st.bg_color = Charte.DORE
	st.set_corner_radius_all(C.px(Charte.RAYON_PETIT))
	st.content_margin_left = C.px(7)
	st.content_margin_right = C.px(7)
	badge.add_theme_stylebox_override("panel", st)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.tooltip_text = "Prochain arrêt · " + detail
	var l := C.label(texte, 17, Charte.ENCRE, true, 800)
	l.add_theme_font_override("font", Charte.TITRE_EXTRA)
	badge.add_child(l)
	carte.add_child(badge)
	var placer := func():
		if not is_instance_valid(badge) or not is_instance_valid(carte): return
		badge.reset_size()
		badge.position = Vector2(carte.size.x - badge.size.x - C.px(5), C.px(5))
	placer.call_deferred()
	carte.resized.connect(placer)

## Texte du badge de Mon XV pour le joueur `id` ("" : rien en attente).
static func texte_badge(live: Dictionary, id: String) -> Array:
	var file := attentes(live, id)
	if file.is_empty(): return ["", ""]
	var detail: Array[String] = []
	var texte := "⧗"
	for e: Dictionary in file.values():
		detail.append(str(e.get("texte", "")))
		if str(e.get("type", "")) == "remplacement": texte = "⧗ %d" % numero_feuille(live, str(e.get("inId", "")), 0)
	return [texte, "\n".join(detail)]

# --- Carte sortant / entrant (remplacement fait), sur la phrase de jeu -----------------------------------------------------

## Deux cartes côte à côte sur la bande de la phrase de jeu (`zone`, jamais le terrain 2D) : sortant en rouge (▼),
## entrant en vert (▲) avec son vrai numéro de feuille ; elles restent quelques secondes.
static func carte_changement(zone: Control, sortant: Dictionary, entrant: Dictionary) -> Control:
	if zone == null or not is_instance_valid(zone): return null
	var ancienne := zone.find_child("MatchChangementCarteCalque", false, false)
	if ancienne != null:
		ancienne.name = "MatchChangementCarteAncienne"
		ancienne.queue_free()
	# Calque sans taille minimale : la carte recouvre la bande sans jamais changer la mise en page de l'écran.
	var calque := Control.new()
	calque.name = "MatchChangementCarteCalque"
	calque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.z_index = 2
	zone.add_child(calque)
	var fond := PanelContainer.new()
	fond.name = "MatchChangementCarte"
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Charte.PANNEAU, 1.0)
	st.set_corner_radius_all(C.px(Charte.RAYON_PANNEAU))
	fond.add_theme_stylebox_override("panel", st)
	calque.add_child(fond)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rang := HBoxContainer.new()
	rang.alignment = BoxContainer.ALIGNMENT_CENTER
	rang.add_theme_constant_override("separation", C.px(18))
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(rang)
	for k in 2:
		var p: Dictionary = sortant if k == 0 else entrant
		var t := Charte.PERTE if k == 0 else Charte.GAIN
		var carte := PanelContainer.new()
		carte.name = "Sortant" if k == 0 else "Entrant"
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU.lerp(t, .25)
		style.border_color = t
		style.set_border_width_all(maxi(2, C.px(3)))
		style.set_corner_radius_all(C.px(Charte.RAYON_CARTE))
		style.content_margin_left = C.px(16)
		style.content_margin_right = C.px(18)
		style.content_margin_top = C.px(2)
		style.content_margin_bottom = C.px(2)
		carte.add_theme_stylebox_override("panel", style)
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.size_flags_vertical = Control.SIZE_FILL
		rang.add_child(carte)
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", C.px(12))
		ligne.alignment = BoxContainer.ALIGNMENT_CENTER
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(ligne)
		var morceaux: Array = [["▼" if k == 0 else "▲", 26, t], [str(int(p.numero)), 32, Charte.IVOIRE], [Tableau_nom(str(p.nom)), 24, Charte.IVOIRE]]
		if k == 0 and float(p.get("note", -1.0)) >= 0.0: morceaux.append([("%.1f" % float(p.note)).replace(".", ","), 24, Charte.couleur_note(float(p.note))])
		if k == 1 and float(p.get("note_poste", -1.0)) >= 0.0: morceaux.append([str(roundi(float(p.note_poste))), 24, Charte.couleur_attribut(float(p.note_poste))])
		morceaux.append(["%d %%" % roundi(float(p.energie)), 20, teinte_energie(float(p.energie))])
		for m: Array in morceaux:
			var l := C.label(str(m[0]), int(m[1]), m[2], true, 800)
			if int(m[1]) >= 24: l.add_theme_font_override("font", Charte.TITRE_EXTRA)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ligne.add_child(l)
		if k == 0:
			var fleche := C.label("⇄", 32, Charte.DORE, true, 800)
			fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			fleche.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rang.add_child(fleche)
	var duree := float(OS.get_environment("CD_CARTE_CHANGEMENT_S")) if OS.get_environment("CD_CARTE_CHANGEMENT_S").is_valid_float() else 6.0
	zone.get_tree().create_timer(duree, true, false, true).timeout.connect(func():
		if is_instance_valid(calque): calque.queue_free())
	return fond

static func Tableau_nom(nom: String) -> String:
	var m := nom.strip_edges().split(" ", false)
	return nom if m.size() < 2 else "%s. %s" % [m[0].left(1), " ".join(m.slice(1)).to_upper()]
