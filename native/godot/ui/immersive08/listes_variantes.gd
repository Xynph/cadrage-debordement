extends RefCounted
## Planches A/B des listes de joueurs (Effectif, Recrutement), 21/11/2026 : options à montrer à Léo, PAS intégrées.
## Tout est inactif sans `CD_VARIANTE_VISUELLE` ; valeurs propres à ces planches (pas de collision avec d'autres) :
##   FORME_A (barres de hauteur = note) / FORME_B (cases colorées, note écrite dedans) : forme récente, 5 derniers matchs ;
##   TRI_A (en-tête souligné + pastilles de poste en ligne) / TRI_B (en-tête en pilule + mini-terrain cliquable) ;
##   TOTAUX_A (ligne de pied collée sous la liste) / TOTAUX_B (tuiles chiffres au-dessus de la liste).
## Barème des notes : Charte.couleur_note / encre_note (barème commun de Léo du 21/11).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const Notes = preload("res://ui/notes_match.gd")

## Groupes de poste des pastilles et du mini-terrain : id, libellé de pastille, libellé court (terrain), numéros.
const GROUPES := [
	["premiere", "1-3 Piliers · Talon", "1-3", [1, 2, 3]],
	["deuxieme", "2e ligne", "4-5", [4, 5]],
	["troisieme", "3e ligne", "6-8", [6, 7, 8]],
	["charniere", "Charnière", "9-10", [9, 10]],
	["centres", "Centres", "12-13", [12, 13]],
	["triangle", "Ailiers · Arrière", "11-14-15", [11, 14, 15]],
]
const LIBELLES_LONGS := {"premiere": "1re ligne", "deuxieme": "2e ligne", "troisieme": "3e ligne", "charniere": "Charnière", "centres": "Centres", "triangle": "Triangle arrière"}

static func variante() -> String:
	return OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()

static func forme() -> String:
	var v := variante()
	return v if v in ["FORME_A", "FORME_B"] else ""

static func tri() -> String:
	var v := variante()
	return v if v in ["TRI_A", "TRI_B"] else ""

static func totaux() -> String:
	var v := variante()
	return v if v in ["TOTAUX_A", "TOTAUX_B"] else ""

# ---------------------------------------------------------------- forme récente

## Les cinq derniers matchs notés, le plus ancien à gauche : {note, adversaire, competition, semaine, minutes, …}.
## L'historique de la saison porte l'adversaire ; à défaut, les 5 notes de forme seules (sans adversaire).
static func cinq_derniers(notes: Dictionary) -> Array:
	var lignes: Variant = notes.get("historique", [])
	var resultat: Array = []
	if lignes is Array and not (lignes as Array).is_empty():
		for ligne: Variant in (lignes as Array).slice(0, 5):
			if ligne is Dictionary: resultat.append(ligne)
		resultat.reverse()
		return resultat
	for valeur: Variant in Notes.forme(notes):
		resultat.append({"note": float(valeur)})
	return resultat.slice(-5)

## Cinq barres (FORME_A) ou cinq cases (FORME_B) dans `zone` (unités du gabarit). Survol : adversaire + note ;
## clic : petite fenêtre du match. `page` : toile de l'écran (porte la fenêtre).
static func dessiner_forme(page: Control, parent: Control, zone: Rect2, notes: Dictionary, joueur: String, style: String) -> Control:
	var groupe := Control.new()
	groupe.name = "FormeRecente"
	groupe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(groupe)
	D.place(groupe, zone)
	var matchs := cinq_derniers(notes)
	var depart := 5 - matchs.size()
	var barres := style == "FORME_A"
	var cote := Vector2(28.0, zone.size.y - 4.0) if barres else Vector2(44.0, zone.size.y - 4.0)
	var ecart := 10.0 if barres else 6.0
	if barres:
		var base := D.rect(groupe, Rect2(0, zone.size.y - 2.0, 5 * cote.x + 4 * ecart, 2), Color(Charte.IVOIRE, .25), 0)
		base.name = "FormeBase"
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var x := i * (cote.x + ecart)
		if i < depart:
			var vide := D.rect(groupe, Rect2(x + cote.x * .2, zone.size.y / 2.0 - 1.5, cote.x * .6, 3), Color(1, 1, 1, .16), 2)
			vide.name = "FormeVide" + str(i)
			continue
		var m: Dictionary = matchs[i - depart]
		var note := float(m.get("note", 6.5))
		var couleur := Charte.couleur_note(note)
		var rect := Rect2(x, (zone.size.y - cote.y) / 2.0, cote.x, cote.y)
		if barres:
			# Hauteur = note (4 en bas, 9 en haut), posée sur une ligne de base commune.
			var part := clampf((note - 4.5) / 4.0, .18, 1.0)
			var haut := cote.y * part
			rect = Rect2(x, zone.size.y - 2.0 - haut, cote.x, haut)
			var rail := D.rect(groupe, Rect2(x, 2.0, cote.x, zone.size.y - 4.0), Color(1, 1, 1, .06), 3)
			rail.name = "FormeRail" + str(i)
			rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bouton := Button.new()
		bouton.name = "FormeMatch" + str(i)
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rayon := maxi(2, C.px(4 if barres else Charte.RAYON_PETIT))
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var fond := StyleBoxFlat.new()
			fond.bg_color = couleur.lightened(.18) if etat == "hover" else couleur
			fond.set_corner_radius_all(rayon)
			if etat == "focus":
				fond.bg_color = Color.TRANSPARENT
				fond.border_color = Charte.IVOIRE
				fond.set_border_width_all(maxi(1, C.px(2)))
				fond.set_expand_margin_all(2)
			bouton.add_theme_stylebox_override(etat, fond)
		var adversaire := str(m.get("adversaire", ""))
		bouton.tooltip_text = ("%s · %s" % [adversaire, Notes.texte_note(note)]) if not adversaire.is_empty() else Notes.texte_note(note)
		bouton.accessibility_name = "Match %d · %s" % [i + 1, bouton.tooltip_text]
		groupe.add_child(bouton)
		D.place(bouton, rect)
		if not barres:
			var chiffre := D.text(bouton, cote.x / 2.0, cote.y / 2.0 + 7.0, Notes.texte_note(note), 20, Charte.encre_note(note), 800, cote.x, HORIZONTAL_ALIGNMENT_CENTER)
			chiffre.add_theme_font_override("font", Charte.TITRE_GRAS)
			chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bouton.pressed.connect(func(): fenetre_match(page, m, joueur, bouton))
	return groupe

## Petite fenêtre visuelle d'un match : grosse pastille de note, adversaire, compétition, tuiles de stats.
static func fenetre_match(page: Control, m: Dictionary, joueur: String, origine: Control = null) -> void:
	var note := float(m.get("note", 6.5))
	var adversaire := str(m.get("adversaire", ""))
	var titre := ("FACE À " + adversaire.to_upper()) if not adversaire.is_empty() else "MATCH NOTÉ"
	var rendre := func(): if is_instance_valid(origine): origine.grab_focus()
	var panneau := Fenetre.ouvrir(page, "FormeMatchFenetre", titre, "", 820, 360, rendre)
	var pastille := Notes.pastille(panneau, Rect2(30, 92, 150, 104), note, 1.6)
	pastille.name = "FormeMatchNote"
	var x := 206.0
	D.text(panneau, x, 128, joueur, 26, Charte.IVOIRE, 700, 580).name = "FormeMatchJoueur"
	var px := x
	if m.has("competition") and not str(m.competition).is_empty():
		R.pastille(panneau, px, 178, str(m.competition), R.BLEU, "", "FormeMatchCompetition", 19)
		px += R.largeur(str(m.competition), 19) + 26.0 + 12.0
	if m.get("semaine") != null:
		R.pastille(panneau, px, 178, "Semaine %d" % (int(m.semaine) + 1), Charte.IVOIRE_2, "calendar", "FormeMatchSemaine", 19)
	if bool(m.get("hommeDuMatch", false)):
		R.pastille(panneau, 30, 240, "★ Homme du match", R.VERT, "", "FormeMatchHomme", 19)
	var tuiles := [["minutes", "min."], ["essais", "essais"], ["plaquages", "plaquages"], ["metres", "mètres"]]
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
		if numero in g[3]: return str(g[0])
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

## TRI_A : pastilles de poste en ligne (« Tous » puis les six groupes), compte à droite du libellé.
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

## TRI_B : mini-terrain cliquable, avants à gauche, arrières à droite ; une bande par groupe (numéros + compte).
static func mini_terrain(parent: Control, zone: Rect2, comptes: Dictionary, actif: String, choisir: Callable) -> Control:
	var terrain := D.rect(parent, zone, Charte.PELOUSE, Charte.RAYON_CARTE)
	terrain.name = "PostesTerrain"
	terrain.mouse_filter = Control.MOUSE_FILTER_PASS
	var largeurs := [1.0, .8, 1.0, .9, .9, 1.2]
	var somme := 0.0
	for l: float in largeurs: somme += l
	var marge := 8.0
	var utile := zone.size.x - marge * 2.0
	var x := marge
	for i in GROUPES.size():
		var g: Array = GROUPES[i]
		var id: String = g[0]
		var w := utile * float(largeurs[i]) / somme
		var est := id == actif
		var b := Button.new()
		b.name = "PosteZone_" + id
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = str(g[1])
		b.accessibility_name = "%s, %d%s" % [g[1], int(comptes.get(id, 0)), " · actif" if est else ""]
		for etat: String in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(maxi(2, C.px(8)))
			s.bg_color = Charte.IVOIRE if est else (Color(Charte.IVOIRE, .14) if etat == "hover" else (Charte.PELOUSE_2 if i % 2 == 0 else Color(0, 0, 0, 0)))
			if etat == "focus":
				s.bg_color = Color.TRANSPARENT
				s.border_color = Charte.IVOIRE
				s.set_border_width_all(maxi(1, C.px(2)))
			b.add_theme_stylebox_override(etat, s)
		terrain.add_child(b)
		D.place(b, Rect2(x + 2, marge, w - 4, zone.size.y - marge * 2.0))
		var encre := Charte.PANNEAU if est else Charte.IVOIRE
		var num := D.text(b, (w - 4) / 2.0, 34, str(g[2]), 20, encre, 800, w - 8, HORIZONTAL_ALIGNMENT_CENTER)
		num.add_theme_font_override("font", Charte.TITRE_GRAS)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nb := D.text(b, (w - 4) / 2.0, zone.size.y - marge * 2.0 - 14, str(int(comptes.get(id, 0))), 30, encre, 800, w - 8, HORIZONTAL_ALIGNMENT_CENTER)
		nb.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): choisir.call("" if est else id))
		x += w
	# Lignes du terrain (ligne médiane entre avants et arrières) : repère discret, non cliquable.
	var mediane := D.rect(terrain, Rect2(marge + utile * (largeurs[0] + largeurs[1] + largeurs[2]) / somme - 1, 4, 2, zone.size.y - 8), Color(Charte.IVOIRE, .5), 0)
	mediane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return terrain

# ---------------------------------------------------------------- en-têtes de tri

## Style commun d'un en-tête de colonne triable : TRI_A souligné, TRI_B pilule crème. Flèche ▲▼ sur l'actif seulement.
static func styler_entete(bouton: Button, legende: Label, actif: bool, descendant: bool, caption: String, style: String) -> void:
	var texte := caption + ((" ▼" if descendant else " ▲") if actif else "")
	bouton.flat = false
	if legende != null:
		legende.text = texte
		legende.add_theme_color_override("font_color", (Charte.PANNEAU if style == "TRI_B" else Charte.IVOIRE) if actif else Charte.IVOIRE_3)
	else:
		bouton.text = texte
		for cle: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			bouton.add_theme_color_override(cle, (Charte.PANNEAU if style == "TRI_B" else Charte.IVOIRE) if actif else Charte.IVOIRE_3)
		if not actif: bouton.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	if actif and style == "TRI_B":
		normal.bg_color = Charte.IVOIRE
		normal.set_corner_radius_all(999)
		normal.content_margin_left = C.px(10)
		normal.content_margin_right = C.px(10)
	elif actif:
		normal.border_color = Charte.IVOIRE
		normal.border_width_bottom = maxi(2, C.px(3))
	bouton.add_theme_stylebox_override("normal", normal)
	var survol := normal.duplicate() as StyleBoxFlat
	if not actif:
		survol.bg_color = Charte.PANNEAU_2
		survol.set_corner_radius_all(999 if style == "TRI_B" else maxi(2, C.px(6)))
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)

# ---------------------------------------------------------------- totaux et moyennes

static func calculer(joueurs: Array, saison: int) -> Dictionary:
	var t := {"n": 0, "age": 0.0, "nage": 0, "niveau": 0.0, "nniveau": 0, "condition": 0.0, "masse": 0.0, "avants": 0, "fins": 0, "minutes": 0.0, "dispo": 0}
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
		if p.get("contractEnd") != null and int(p.contractEnd) <= saison: t.fins += 1
		t.minutes += float(p.get("minutes", 0))
		if float(p.get("injury", 0)) <= 0: t.dispo += 1
	return {
		"n": t.n,
		"age": t.age / t.nage if t.nage > 0 else null,
		"niveau": t.niveau / t.nniveau if t.nniveau > 0 else null,
		"condition": t.condition / t.n if t.n > 0 else null,
		"masse": t.masse,
		"avants": t.avants,
		"arrieres": t.n - t.avants,
		"fins": t.fins,
		"minutes": t.minutes,
	}

static func decimal(v: Variant) -> String:
	return "—" if v == null else ("%.1f" % float(v)).replace(".", ",")
