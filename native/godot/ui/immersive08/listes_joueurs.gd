extends RefCounted
## Listes de joueurs (Effectif, Recrutement), choix de Léo du 21/11/2026 sur planches :
##   forme récente = 5 cases colorées, note écrite dedans (barème Charte.couleur_note / encre_note) ; survol : adversaire
##   + note ; clic : petite fenêtre du match (note, adversaire, score, compétition, semaine, stats) ;
##   tri = en-tête trié souligné avec ▲/▼ + rangée de pastilles de poste au-dessus de la liste (avec le nombre) ;
##   totaux = tuiles chiffres au-dessus de la liste (Effectif), qui suivent les filtres et sont cliquables.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Notes = preload("res://ui/notes_match.gd")

## Groupes de poste des pastilles : id, libellé, numéros de poste.
const GROUPES := [
	["premiere", "1-3 Piliers · Talon", [1, 2, 3]],
	["deuxieme", "2e ligne", [4, 5]],
	["troisieme", "3e ligne", [6, 7, 8]],
	["charniere", "Charnière", [9, 10]],
	["centres", "Centres", [12, 13]],
	["triangle", "Ailiers · Arrière", [11, 14, 15]],
]

# ---------------------------------------------------------------- forme récente

## Les cinq derniers matchs notés, le plus ancien à gauche : {note, adversaire, scorePour, scoreContre, competition,
## semaine, minutes, …}. Sources : `formeMatchs` / `matchs` (moteur : chaque note de forme et son match, tous clubs),
## enrichis par l'`historique` de la saison (club du manager : compétition, minutes, stats) ; ancienne sauvegarde :
## historique seul, ou les notes de forme seules (sans adversaire).
static func cinq_derniers(notes: Dictionary) -> Array:
	var historique: Array = notes.get("historique", []) if notes.get("historique") is Array else []
	var source: Variant = notes.get("formeMatchs", notes.get("matchs", []))
	var resultat: Array = []
	if source is Array and not (source as Array).is_empty():
		for m: Variant in (source as Array).slice(-5):
			if m is Dictionary: resultat.append((m as Dictionary).duplicate())
	elif not historique.is_empty():
		for ligne: Variant in historique.slice(0, 5):
			if ligne is Dictionary: resultat.append(ligne)
		resultat.reverse()
		return resultat
	else:
		for valeur: Variant in Notes.forme(notes).slice(-5):
			resultat.append({"note": float(valeur)})
		return resultat
	# Même match dans l'historique de la saison (semaine, adversaire, note) : on prend sa ligne complète.
	var libres := historique.duplicate()
	for i in resultat.size():
		var m: Dictionary = resultat[i]
		if m.get("semaine") == null: continue
		for h: Variant in libres:
			if not h is Dictionary or h.get("semaine") == null: continue
			if int(h.semaine) != int(m.semaine) or absf(float(h.get("note", -1)) - float(m.get("note", -2))) > .01: continue
			if m.get("adversaireId") != null and h.get("adversaireId") != null and int(h.adversaireId) != int(m.adversaireId): continue
			var complet: Dictionary = (h as Dictionary).duplicate()
			for cle: String in ["scorePour", "scoreContre", "adversaire"]:
				if complet.get(cle) == null and m.get(cle) != null: complet[cle] = m[cle]
			resultat[i] = complet
			libres.erase(h)
			break
	return resultat

## Texte du score vu du joueur (« 24 – 10 »), vide si inconnu.
static func score(m: Dictionary) -> String:
	if m.get("scorePour") == null or m.get("scoreContre") == null: return ""
	return "%d – %d" % [int(m.scorePour), int(m.scoreContre)]

## Résultat du match vu du joueur : [mot, couleur], vide si le score est inconnu.
static func resultat(m: Dictionary) -> Array:
	if m.get("scorePour") == null or m.get("scoreContre") == null: return []
	var pour := int(m.scorePour)
	var contre := int(m.scoreContre)
	if pour > contre: return ["Victoire", Charte.GAIN]
	if pour < contre: return ["Défaite", Charte.PERTE]
	return ["Nul", Charte.IVOIRE_2]

## Cinq cases colorées dans `zone` (unités du gabarit), note écrite dedans, la plus récente à droite ; match pas encore
## joué : trait discret. Survol : adversaire (+ score) et note ; clic : petite fenêtre du match. `page` porte la fenêtre.
static func dessiner_forme(page: Control, parent: Control, zone: Rect2, notes: Dictionary, joueur: String, largeur_case := 44.0) -> Control:
	var groupe := Control.new()
	groupe.name = "FormeRecente"
	groupe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(groupe)
	D.place(groupe, zone)
	var matchs := cinq_derniers(notes)
	var depart := 5 - matchs.size()
	var cote := Vector2(largeur_case, zone.size.y - 4.0)
	var ecart := 6.0
	for i in 5:
		var x := i * (cote.x + ecart)
		if i < depart:
			var vide := D.rect(groupe, Rect2(x + cote.x * .2, zone.size.y / 2.0 - 1.5, cote.x * .6, 3), Color(1, 1, 1, .16), 2)
			vide.name = "FormeVide" + str(i)
			vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		var m: Dictionary = matchs[i - depart]
		var note := float(m.get("note", 6.5))
		var couleur := Charte.couleur_note(note)
		var bouton := Button.new()
		bouton.name = "FormeMatch" + str(i)
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var fond := StyleBoxFlat.new()
			fond.bg_color = couleur.lightened(.18) if etat == "hover" else couleur
			fond.set_corner_radius_all(maxi(2, C.px(Charte.RAYON_PETIT)))
			if etat == "focus":
				fond.bg_color = Color.TRANSPARENT
				fond.border_color = Charte.IVOIRE
				fond.set_border_width_all(maxi(1, C.px(2)))
				fond.set_expand_margin_all(2)
			bouton.add_theme_stylebox_override(etat, fond)
		var adversaire := str(m.get("adversaire", ""))
		var resume := score(m)
		bouton.tooltip_text = ("%s%s · %s" % [adversaire, (" " + resume) if not resume.is_empty() else "", Notes.texte_note(note)]) if not adversaire.is_empty() else Notes.texte_note(note)
		bouton.accessibility_name = "Match %d · %s" % [i + 1, bouton.tooltip_text]
		groupe.add_child(bouton)
		D.place(bouton, Rect2(x, 2.0, cote.x, cote.y))
		var chiffre := D.text(bouton, cote.x / 2.0, cote.y / 2.0 + 7.0, Notes.texte_note(note), 20 if cote.x >= 40.0 else 18, Charte.encre_note(note), 800, cote.x, HORIZONTAL_ALIGNMENT_CENTER)
		chiffre.add_theme_font_override("font", Charte.TITRE_GRAS)
		chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bouton.pressed.connect(func(): fenetre_match(page, m, joueur, bouton))
	return groupe

## Petite fenêtre visuelle d'un match : grosse pastille de note, joueur, score et résultat, compétition, semaine,
## tuiles de stats (si connues : joueurs du club du manager).
static func fenetre_match(page: Control, m: Dictionary, joueur: String, origine: Control = null) -> void:
	var note := float(m.get("note", 6.5))
	var adversaire := str(m.get("adversaire", ""))
	var titre := ("FACE À " + adversaire.to_upper()) if not adversaire.is_empty() else "MATCH NOTÉ"
	var tuiles := [["minutes", "min."], ["essais", "essais"], ["plaquages", "plaquages"], ["metres", "mètres"]]
	var avec_stats := tuiles.any(func(t: Array): return m.get(t[0]) != null)
	var rendre := func(): if is_instance_valid(origine): origine.grab_focus()
	var panneau := Fenetre.ouvrir(page, "FormeMatchFenetre", titre, "", 820, 360 if avec_stats else 250, rendre)
	var pastille := Notes.pastille(panneau, Rect2(30, 92, 150, 104), note, 1.6)
	pastille.name = "FormeMatchNote"
	var x := 206.0
	D.text(panneau, x, 128, joueur, 26, Charte.IVOIRE, 700, 380).name = "FormeMatchJoueur"
	var resume := score(m)
	if not resume.is_empty():
		var issue := resultat(m)
		var chiffres := D.text(panneau, 790, 132, resume, 44, issue[1], 800, 220, HORIZONTAL_ALIGNMENT_RIGHT)
		chiffres.name = "FormeMatchScore"
		chiffres.add_theme_font_override("font", Charte.TITRE_FICHE)
		var l := R.largeur(str(issue[0]), 19) + 26.0
		R.pastille(panneau, 790 - l, 178, str(issue[0]), issue[1], "", "FormeMatchResultat", 19)
	var px := x
	if m.has("competition") and not str(m.competition).is_empty():
		R.pastille(panneau, px, 178, str(m.competition), R.BLEU, "", "FormeMatchCompetition", 19)
		px += R.largeur(str(m.competition), 19) + 26.0 + 12.0
	if m.get("semaine") != null:
		R.pastille(panneau, px, 178, "Semaine %d" % (int(m.semaine) + 1), Charte.IVOIRE_2, "calendar", "FormeMatchSemaine", 19)
	if bool(m.get("hommeDuMatch", false)):
		R.pastille(panneau, 30, 232, "★ Homme du match", R.VERT, "", "FormeMatchHomme", 19)
	if not avec_stats: return
	var tx := 30.0
	var ty := 262.0 if not bool(m.get("hommeDuMatch", false)) else 268.0
	for t: Array in tuiles:
		var valeur: Variant = m.get(t[0])
		R.tuile(panneau, Rect2(tx, ty, 180, 72), "—" if valeur == null else str(int(valeur)), str(t[1]), Charte.IVOIRE, "FormeMatchTuile_" + str(t[0]), 34)
		tx += 192.0

# ---------------------------------------------------------------- groupes de poste

static func groupe_de(joueur: Dictionary) -> String:
	var source: Variant = joueur.get("primaryPositions", [joueur.get("primaryPosition")])
	var numero := 0
	if source is Array:
		for v: Variant in source:
			if (v is int or v is float) and int(v) >= 1 and int(v) <= 15:
				numero = int(v)
				break
	if numero == 0:
		var pos := str(joueur.get("pos", "")).to_lower()
		for paire: Array in [["pilier", 1], ["talon", 2], ["deuxième", 4], ["troisième", 6], ["numéro 8", 8], ["mêlée", 9], ["ouverture", 10], ["ouvreur", 10], ["centre", 12], ["ailier", 11], ["arrière", 15]]:
			if pos.contains(str(paire[0])):
				numero = int(paire[1])
				break
	for g: Array in GROUPES:
		if numero in g[2]: return str(g[0])
	return ""

static func filtrer_groupe(joueurs: Array, groupe: String) -> Array:
	if groupe.is_empty(): return joueurs
	return joueurs.filter(func(p: Variant): return p is Dictionary and groupe_de(p) == groupe)

static func compter_groupes(joueurs: Array) -> Dictionary:
	var n := {}
	for g: Array in GROUPES: n[str(g[0])] = 0
	for p: Variant in joueurs:
		if not p is Dictionary: continue
		var g := groupe_de(p)
		if n.has(g): n[g] = int(n[g]) + 1
	return n

## Pastilles de poste en ligne (« Tous postes » puis les six groupes), compte à droite du libellé.
static func pastilles_postes(parent: Control, origine: Vector2, comptes: Dictionary, total: int, actif: String, choisir: Callable) -> Control:
	var rangee := Control.new()
	rangee.name = "PostesPastilles"
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rangee)
	D.place(rangee, Rect2(origine, Vector2(2248, 40)))
	var x := 0.0
	var definitions: Array = [["", "Tous postes", total]]
	for g: Array in GROUPES: definitions.append([g[0], g[1], comptes.get(g[0], 0)])
	for d: Array in definitions:
		var id: String = d[0]
		var est := id == actif
		var texte: String = d[1]
		var nombre := str(d[2])
		var l := R.largeur(texte, 19, 600) + 12.0 + R.largeur(nombre, 19, 700) + 36.0
		var b := Button.new()
		b.name = "PostePastille_" + (id if not id.is_empty() else "tous")
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.accessibility_name = "%s, %s%s" % [texte, nombre, " · actif" if est else ""]
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(999)
			s.bg_color = Charte.IVOIRE if est else (Charte.PANNEAU_2 if etat == "hover" else Color.TRANSPARENT)
			if not est:
				s.border_color = Charte.IVOIRE_3 if etat == "hover" else Charte.FILET
				s.set_border_width_all(maxi(1, C.px(1)))
			if etat == "focus":
				s.bg_color = Color.TRANSPARENT
				s.border_color = Charte.IVOIRE
				s.set_border_width_all(maxi(1, C.px(2)))
				s.set_expand_margin_all(2)
			b.add_theme_stylebox_override(etat, s)
		rangee.add_child(b)
		D.place(b, Rect2(x, 0, l, 40))
		var t := D.text(b, 18, 27, texte, 19, Charte.PANNEAU if est else Charte.IVOIRE, 600, l)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c := D.text(b, 18 + R.largeur(texte, 19, 600) + 12.0, 27, nombre, 19, Charte.PANNEAU if est else Charte.IVOIRE_2, 700, 40)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): choisir.call(id))
		x += l + 8.0
	return rangee

# ---------------------------------------------------------------- en-têtes de tri

## En-tête de colonne triable : actif = souligné, ivoire, flèche ▲ (croissant) ou ▼ (décroissant) ; inactif = discret.
static func styler_entete(bouton: Button, legende: Label, actif: bool, descendant: bool, caption: String) -> void:
	var texte := caption + ((" ▼" if descendant else " ▲") if actif else "")
	bouton.flat = false
	if legende != null:
		legende.text = texte
		legende.add_theme_color_override("font_color", Charte.IVOIRE if actif else Charte.IVOIRE_3)
	else:
		bouton.text = texte
		for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			bouton.add_theme_color_override(cle, Charte.IVOIRE if actif else Charte.IVOIRE_3)
		if not actif: bouton.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	if actif:
		normal.border_color = Charte.IVOIRE
		normal.border_width_bottom = maxi(2, C.px(3))
	bouton.add_theme_stylebox_override("normal", normal)
	var survol := normal.duplicate() as StyleBoxFlat
	if not actif:
		survol.bg_color = Charte.PANNEAU_2
		survol.set_corner_radius_all(maxi(2, C.px(6)))
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)

# ---------------------------------------------------------------- totaux et moyennes

static func calculer(joueurs: Array) -> Dictionary:
	var t := {"n": 0, "age": 0.0, "nage": 0, "niveau": 0.0, "nniveau": 0, "condition": 0.0, "masse": 0.0, "avants": 0}
	for p: Variant in joueurs:
		if not p is Dictionary: continue
		t.n += 1
		var age: Variant = p.get("age")
		if age is int or age is float: t.age += float(age); t.nage += 1
		var niveau: Variant = p.get("rating")
		if niveau is int or niveau is float: t.niveau += float(niveau); t.nniveau += 1
		t.condition += float(p.get("condition", 0))
		var salaire: Variant = p.get("salary")
		if salaire is int or salaire is float: t.masse += float(salaire)
		if float(p.get("fam", 0)) <= 3: t.avants += 1
	return {
		"n": t.n,
		"age": t.age / t.nage if t.nage > 0 else null,
		"niveau": t.niveau / t.nniveau if t.nniveau > 0 else null,
		"condition": t.condition / t.n if t.n > 0 else null,
		"masse": t.masse,
		"avants": t.avants,
		"arrieres": t.n - t.avants,
	}

static func decimal(v: Variant) -> String:
	return "—" if v == null else ("%.1f" % float(v)).replace(".", ",")
