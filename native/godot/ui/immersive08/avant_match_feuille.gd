extends RefCounted
## Planche FM27 n° 7 « Avant-match + causerie » (22/11/2026), sous CD_VARIANTE_VISUELLE=A|B ; sans variable, rien ne change.
## Données : fiche du club adverse (native/engine/club-sheet.cjs) : XV habituel (feuilles de la saison), composition
## automatique du prochain match (nextLineup, blessés et suspendus écartés) ; notre feuille (model.selection).
## A « Feuille face à face » : changements de leur XV (entrent / sortent), feuille 1-15 face à face, leur formation probable.
## B « Terrain face à face » : les deux XV sur un même terrain, météo posée dessus, absents adverses en bande à droite.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const RI = preload("res://ui/contextual/rooms/room_identity.gd")
const ClubSheet = preload("res://ui/immersive08/club_sheet_canvas.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Nom = preload("res://ui/person_name.gd")
const MeteoTexte = preload("res://ui/contextual/meteo_texte.gd")

## Place de chaque maillot sur un demi-terrain : x = profondeur (0 = sa ligne d'essai, 1 = ligne médiane), y = largeur.
const PLACES := {1: Vector2(.93, .30), 2: Vector2(.93, .50), 3: Vector2(.93, .70), 4: Vector2(.84, .40), 5: Vector2(.84, .60),
	6: Vector2(.84, .16), 7: Vector2(.84, .84), 8: Vector2(.75, .50), 9: Vector2(.66, .64), 10: Vector2(.56, .40),
	12: Vector2(.48, .26), 13: Vector2(.42, .14), 11: Vector2(.34, .04), 14: Vector2(.34, .96), 15: Vector2(.18, .52)}
## Motif d'absence : mot + couleur franche (jamais la couleur seule).
const MOTIFS := {"blesse": ["Blessé", Color("d9634f")], "suspendu": ["Suspendu", Color("e0a04a")], "selection": ["Sélection", Color("5b9bd5")], "choix": ["Choix", Color("abb7b1")]}

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Données communes : nos 15 (+ banc), leurs 15 probables, entrées et sorties par rapport à leur XV habituel.
static func donnees(app: Control, model: Dictionary, next: Dictionary, nous: int) -> Dictionary:
	var clubs := [next.get("home", {}), next.get("away", {})]
	var adverse: Dictionary = clubs[1 - nous]
	var sortie := {"nous": clubs[nous], "eux": adverse, "nos": [], "leurs": [], "entrent": [], "sortent": [], "pret": false}
	for i in 23: sortie.nos.append({})
	for slot: Dictionary in model.get("selection", {}).get("slots", []):
		var n := int(slot.get("slot", -1))
		if n < 0 or n >= 23: continue
		var joueur := P.player(model, str(slot.get("playerId", "")))
		if not joueur.is_empty(): sortie.nos[n] = joueur
	var id_v: Variant = adverse.get("id")
	if not (id_v is int or id_v is float): return sortie
	var fiche: Dictionary = ClubSheet.cached(app, int(id_v))
	if fiche.is_empty():
		ClubSheet.request(app, int(id_v))
		return sortie
	var effectif := {}
	for j: Dictionary in fiche.get("squad", []): effectif[str(j.get("id", ""))] = j
	var xv: Dictionary = fiche.get("xv", {})
	var habituel := {}
	for s: Dictionary in xv.get("slots", []):
		if s.get("id") != null: habituel[str(s.id)] = int(s.get("jersey", 0))
	var prochain: Array = xv.get("nextLineup", []) if xv.get("nextLineup") is Array else []
	if prochain.is_empty():
		for s: Dictionary in xv.get("slots", []): prochain.append(s.get("id"))
	var dans := {}
	for i in 15:
		var pid: Variant = prochain[i] if i < prochain.size() else null
		var joueur: Dictionary = effectif.get(str(pid), {}) if pid != null else {}
		sortie.leurs.append(joueur)
		if joueur.is_empty(): continue
		dans[str(pid)] = true
		if not habituel.has(str(pid)): sortie.entrent.append({"joueur": joueur, "maillot": i + 1})
	for pid: String in habituel:
		if dans.has(pid) or not effectif.has(pid): continue
		var j: Dictionary = effectif[pid]
		var motif := "blesse" if int(j.get("injury", 0)) > 0 else "suspendu" if int(j.get("suspension", 0)) > 0 else "selection" if j.get("onInternationalDuty", false) else "choix"
		sortie.sortent.append({"joueur": j, "maillot": int(habituel[pid]), "motif": motif})
	sortie.sortent.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.maillot) < int(b.maillot))
	sortie.entrent.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.maillot) < int(b.maillot))
	# Changements maillot par maillot : qui porte le n° au prochain match, qui le portait d'habitude (et pourquoi il sort).
	var par_maillot := {}
	for pid: String in habituel: par_maillot[int(habituel[pid])] = pid
	var maillot_de := {}
	for i in 15:
		if i < prochain.size() and prochain[i] != null: maillot_de[str(prochain[i])] = i + 1
	sortie.changements = []
	for i in 15:
		var entre: Dictionary = sortie.leurs[i]
		var ancien_id := str(par_maillot.get(i + 1, ""))
		if entre.is_empty() or str(entre.get("id", "")) == ancien_id: continue
		var ancien: Dictionary = effectif.get(ancien_id, {})
		var motif := ""
		if maillot_de.has(ancien_id): motif = "n° %d" % int(maillot_de[ancien_id])
		elif not ancien.is_empty():
			motif = "blesse" if int(ancien.get("injury", 0)) > 0 else "suspendu" if int(ancien.get("suspension", 0)) > 0 else "selection" if ancien.get("onInternationalDuty", false) else "choix"
		sortie.changements.append({"maillot": i + 1, "entre": entre, "sort": ancien, "motif": motif})
	sortie.matchs = int(xv.get("matches", 0))
	sortie.pret = true
	return sortie

static func couleur(club: Dictionary) -> Color:
	return RI.primary(G.identity(club))

## Section posée entre l'affiche et les tuiles de vérification (l'espace vide de l'écran actuel).
static func section(ecran, app: Control, model: Dictionary, next: Dictionary, nous: int) -> Control:
	var d := donnees(app, model, next, nous)
	var zone := MarginContainer.new()
	zone.name = "AvantFeuille" + variante()
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, ecran.M(32))
	zone.add_theme_constant_override("margin_top", ecran.M(14))
	zone.add_theme_constant_override("margin_bottom", ecran.M(14))
	var ligne := HBoxContainer.new()
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_theme_constant_override("separation", ecran.M(16))
	zone.add_child(ligne)
	if variante() == "A":
		ligne.add_child(_changements(ecran, app, d, 1.0))
		ligne.add_child(_feuille_face(ecran, app, d, nous, 1.5))
		ligne.add_child(_formation(ecran, app, next, d, 1.0))
	else:
		ligne.add_child(_terrain_double(ecran, app, next, d, nous, 3.2))
		ligne.add_child(_absents(ecran, app, d, 1.0))
	return zone

static func _panneau(ecran, nom: String, titre: String, legende: String, ratio: float) -> VBoxContainer:
	var tile := PanelContainer.new()
	tile.name = nom
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.size_flags_stretch_ratio = ratio
	tile.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Charte.PANNEAU, .94)
	style.set_corner_radius_all(Charte.RAYON_PANNEAU)
	style.content_margin_left = ecran.M(18)
	style.content_margin_right = ecran.M(18)
	style.content_margin_top = ecran.M(10)
	style.content_margin_bottom = ecran.M(12)
	tile.add_theme_stylebox_override("panel", Charte.ombrer(style))
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", ecran.M(5))
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(colonne)
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(tete)
	var h: Label = ecran.italique(ecran.texte(titre.to_upper(), 18, Charte.IVOIRE, true, 700))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(h)
	if not legende.is_empty():
		var l: Label = ecran.texte(legende.to_upper(), 12, Charte.IVOIRE_2, true, 600)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(l)
	var filet := ColorRect.new()
	filet.color = Charte.FILET
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(filet)
	return colonne

## Pastille arrondie : fond teinté, mot en couleur franche.
static func pastille(ecran, mot: String, teinte: Color, taille: float = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", Charte.style_pilule(Color(teinte, .18), Color.TRANSPARENT, ecran.M(9), ecran.M(2)))
	var l: Label = ecran.texte(mot.to_upper(), taille, teinte, true, 700)
	p.add_child(l)
	return p

## Ligne cliquable (fiche du joueur) : survol = ligne éclaircie + mini-fiche.
static func _ligne_joueur(ecran, app: Control, joueur: Dictionary, nom: String) -> Button:
	var b := Button.new()
	b.name = nom
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = ecran.M(30)
	var repos := StyleBoxFlat.new()
	repos.bg_color = Color.TRANSPARENT
	repos.set_corner_radius_all(Charte.RAYON_PETIT)
	var survol := repos.duplicate()
	survol.bg_color = Charte.PANNEAU_2.lerp(Charte.CREME, .05)
	for etat in ["normal", "disabled"]: b.add_theme_stylebox_override(etat, repos)
	for etat in ["hover", "pressed", "focus"]: b.add_theme_stylebox_override(etat, survol)
	var pid := str(joueur.get("id", ""))
	b.pressed.connect(func(): ouvrir_joueur(app, pid))
	var source := "squad" if not P.player(app.model, pid).is_empty() else "adverse"
	MiniFiche.lier(app, b, pid, source)
	return b

static func ouvrir_joueur(app: Control, pid: String) -> void:
	for genre in ["player", "market"]:
		if app.navigation_controller.open_entity({"kind": genre, "id": pid}): return

static func _rangee(ecran, parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", ecran.M(8))
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = ecran.M(6)
	r.offset_right = -ecran.M(6)
	parent.add_child(r)
	return r

static func _poste_court(joueur: Dictionary) -> String:
	var p := str(joueur.get("pos", ""))
	return {"Pilier gauche": "Pilier G.", "Pilier droit": "Pilier D.", "Deuxième ligne": "2e ligne", "Troisième ligne aile": "3e l. aile",
		"Troisième ligne centre": "3e l. centre", "Numéro 8": "3e l. centre", "Demi de mêlée": "Mêlée", "Demi d'ouverture": "Ouvreur", "Demi d’ouverture": "Ouvreur"}.get(p, p)

# --- A : changements, feuille face à face, formation probable -------------------------------------------------

static func _changements(ecran, app: Control, d: Dictionary, ratio: float) -> Control:
	var col := _panneau(ecran, "AvantChangements", "Leur XV · changements", ("%d" % d.changements.size()) if d.pret else "", ratio)
	col.add_theme_constant_override("separation", ecran.M(2))
	if not d.pret:
		col.add_child(ecran.texte("…", 16, Charte.IVOIRE_2))
		return col.get_parent()
	if d.changements.is_empty():
		col.add_child(pastille(ecran, "Même XV", Charte.VERT_CLAIR, 14))
		return col.get_parent()
	var tete := HBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_theme_constant_override("separation", ecran.M(8))
	col.add_child(tete)
	for c in [["N°", 26, Charte.IVOIRE_3], ["▲ ENTRE", -1, Charte.GAIN], ["▼ SORT", -1, Charte.PERTE], ["", 86, Charte.IVOIRE_3]]:
		var l: Label = ecran.texte(c[0], 11, c[2], true, 700)
		if int(c[1]) > 0: l.custom_minimum_size.x = ecran.M(c[1])
		else: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tete.add_child(l)
	var max_lignes := 11
	for e: Dictionary in d.changements.slice(0, max_lignes):
		var r := HBoxContainer.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_constant_override("separation", ecran.M(8))
		col.add_child(r)
		var num: Label = ecran.texte(str(e.maillot), 15, Charte.IVOIRE, true, 800)
		num.custom_minimum_size.x = ecran.M(26)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(num)
		for cote in [["entre", Charte.IVOIRE], ["sort", Charte.IVOIRE_2]]:
			var j: Dictionary = e[cote[0]]
			if j.is_empty():
				var vide: Label = ecran.texte("—", 13, Charte.IVOIRE_3)
				vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r.add_child(vide)
				continue
			var b := _ligne_joueur(ecran, app, j, "AvantChangement_%s_%d" % [cote[0], int(e.maillot)])
			b.custom_minimum_size.y = ecran.M(22)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(b)
			var rr := _rangee(ecran, b)
			var nom: Label = ecran.texte(Nom.surname(str(j.get("name", ""))).to_upper(), 14, cote[1], true, 700)
			nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nom.clip_text = true
			nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rr.add_child(nom)
		var motif_box := HBoxContainer.new()
		motif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		motif_box.custom_minimum_size.x = ecran.M(86)
		motif_box.alignment = BoxContainer.ALIGNMENT_END
		r.add_child(motif_box)
		var motif := str(e.motif)
		if MOTIFS.has(motif): motif_box.add_child(pastille(ecran, MOTIFS[motif][0], MOTIFS[motif][1], 11))
		elif not motif.is_empty(): motif_box.add_child(pastille(ecran, "→ " + motif, Charte.IVOIRE_2, 11))
	if d.changements.size() > max_lignes: col.add_child(ecran.texte("+%d" % (d.changements.size() - max_lignes), 12, Charte.IVOIRE_2, true, 700))
	return col.get_parent()

static func _feuille_face(ecran, app: Control, d: Dictionary, nous: int, ratio: float) -> Control:
	var col := _panneau(ecran, "AvantFeuilleFace", "Feuille de match", "1 – 15", ratio)
	col.add_theme_constant_override("separation", 0)
	var cotes := [d.nos, d.leurs] if nous == 0 else [d.leurs, d.nos]
	var clubs := [d.nous, d.eux] if nous == 0 else [d.eux, d.nous]
	var entrants := {}
	for e: Dictionary in d.entrent: entrants[str(e.joueur.get("id", ""))] = true
	# Bandeau aux couleurs des deux clubs au-dessus des colonnes (immersion, comme les plaques de l'affiche).
	var bandes := HBoxContainer.new()
	bandes.add_theme_constant_override("separation", ecran.M(44))
	bandes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bandes)
	for s in 2:
		var bande := PanelContainer.new()
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bande.add_theme_stylebox_override("panel", Charte.style_pilule(couleur(clubs[s]), Color.TRANSPARENT, ecran.M(12), ecran.M(1)))
		var n: Label = ecran.texte(G.club_name(clubs[s]).to_upper(), 13, RI.contrast(couleur(clubs[s])), true, 800)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if s == 0 else HORIZONTAL_ALIGNMENT_LEFT
		n.clip_text = true
		bande.add_child(n)
		bandes.add_child(bande)
	var grille := GridContainer.new()
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", ecran.M(6))
	grille.add_theme_constant_override("v_separation", 0)
	grille.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grille)
	for i in 15:
		for s in 2:
			var j: Dictionary = cotes[s][i] if i < cotes[s].size() else {}
			var cellule: Control
			if j.is_empty():
				cellule = ecran.texte("—", 14, Charte.IVOIRE_3)
			else:
				var b := _ligne_joueur(ecran, app, j, "AvantFeuille_%d_%d" % [s, i + 1])
				b.custom_minimum_size.y = ecran.M(19)
				var r := _rangee(ecran, b)
				r.alignment = BoxContainer.ALIGNMENT_END if s == 0 else BoxContainer.ALIGNMENT_BEGIN
				var nom: Label = ecran.texte(Nom.surname(str(j.get("name", ""))).to_upper(), 13, Charte.IVOIRE, true, 700)
				nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var marque: Label = null
				if entrants.has(str(j.get("id", ""))): marque = ecran.texte("▲", 11, Charte.GAIN, true, 700)
				var cond: Variant = j.get("condition")
				if (cond is int or cond is float) and float(cond) < 80: marque = ecran.texte("!%d" % roundi(float(cond)), 11, Charte.couleur_attribut(float(cond)), true, 700)
				if s == 0:
					if marque != null: r.add_child(marque)
					r.add_child(nom)
				else:
					r.add_child(nom)
					if marque != null: r.add_child(marque)
				cellule = b
			cellule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if s == 1:
				var num := ecran.texte(str(i + 1), 14, Charte.IVOIRE, true, 800) as Label
				num.custom_minimum_size.x = ecran.M(22)
				num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				grille.add_child(num)
				var num2 := ecran.texte(str(i + 1), 14, Charte.IVOIRE, true, 800) as Label
				num2.custom_minimum_size.x = ecran.M(22)
				num2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				grille.add_child(num2)
			grille.add_child(cellule)
	return col.get_parent()

static func _formation(ecran, app: Control, next: Dictionary, d: Dictionary, ratio: float) -> Control:
	var col := _panneau(ecran, "AvantFormation", "Leur formation probable", "", ratio)
	var t := Terrain.new()
	t.name = "AvantTerrainAdverse"
	t.vertical = true
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(ecran.M(200), ecran.M(200))
	col.add_child(t)
	var entrants := {}
	for e: Dictionary in d.entrent: entrants[str(e.joueur.get("id", ""))] = true
	t.ajouter_equipe(app, d.leurs, couleur(d.eux), 1, entrants)
	return col.get_parent()

# --- B : les deux XV sur un même terrain, météo dessus, absents adverses à droite --------------------------------

static func _terrain_double(ecran, app: Control, next: Dictionary, d: Dictionary, nous: int, ratio: float) -> Control:
	var col := _panneau(ecran, "AvantTerrainFace", "Face à face", "", ratio)
	var t := Terrain.new()
	t.name = "AvantTerrainDouble"
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(ecran.M(400), ecran.M(200))
	t.echelle = ecran.M(1)
	col.add_child(t)
	var entrants := {}
	for e: Dictionary in d.entrent: entrants[str(e.joueur.get("id", ""))] = true
	t.ajouter_equipe(app, d.nos.slice(0, 15), couleur(d.nous), 0, {})
	t.ajouter_equipe(app, d.leurs, couleur(d.eux), 1, entrants)
	# Météo posée sur le terrain : ciel + vent, et la flèche du vent pour la 1re période.
	if next.get("meteo") is Dictionary:
		var annonce := MeteoTexte.annonce(next)
		var meteo: Dictionary = next.meteo
		var vent := clampi(int(meteo.get("vent", 0)), 0, 2)
		var mots: Array[String] = [MeteoTexte.libelle(annonce)]
		if vent > 0 and mots[0].to_lower().find("vent") < 0: mots.append(["", "vent", "grand vent"][vent])
		t.meteo = " · ".join(mots).to_upper()
		t.vent = vent
		# Nous à gauche : vent dans notre dos en 1re période = il souffle vers la droite.
		t.sens = 1 if MeteoTexte.camp_vent(annonce, 1) == nous else -1
	return col.get_parent()

static func _absents(ecran, app: Control, d: Dictionary, ratio: float) -> Control:
	var col := _panneau(ecran, "AvantAbsents", "Chez eux", "", ratio)
	if not d.pret: return col.get_parent()
	var compte := HBoxContainer.new()
	compte.add_theme_constant_override("separation", ecran.M(8))
	compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(compte)
	compte.add_child(pastille(ecran, "▲ %d entrent" % d.entrent.size(), Charte.GAIN, 12))
	compte.add_child(pastille(ecran, "▼ %d sortent" % d.sortent.size(), Charte.PERTE, 12))
	for e: Dictionary in d.sortent.slice(0, 5):
		var j: Dictionary = e.joueur
		var b := _ligne_joueur(ecran, app, j, "AvantAbsent_" + str(j.get("id", "")).validate_node_name())
		b.custom_minimum_size.y = ecran.M(40)
		col.add_child(b)
		var r := _rangee(ecran, b)
		var portrait := G.portrait(int(j.get("portraitIndex", 0)), ecran.M(32), j)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.modulate = Color(1, 1, 1, .7)
		r.add_child(portrait)
		var mots := VBoxContainer.new()
		mots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mots.add_theme_constant_override("separation", 0)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(mots)
		var nom: Label = ecran.texte(Nom.surname(str(j.get("name", ""))).to_upper(), 14, Charte.IVOIRE, true, 700)
		nom.clip_text = true
		mots.add_child(nom)
		mots.add_child(ecran.texte("n° %d · %s" % [int(e.maillot), _poste_court(j)], 11, Charte.IVOIRE_2, false, 500))
		var m: Array = MOTIFS[e.motif]
		r.add_child(pastille(ecran, m[0], m[1], 11))
	if d.sortent.size() > 5:
		var plus := pastille(ecran, "+%d" % (d.sortent.size() - 5), Charte.IVOIRE_2, 12)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(plus)
	return col.get_parent()

## Terrain dessiné (pelouse, lignes) avec des maillots cliquables posés dessus ; `vertical` : leur camp en bas,
## attaque vers le haut. Sinon terrain en largeur : camp 0 à gauche, camp 1 à droite.
class Terrain extends Control:
	var vertical := false
	var echelle := 1.0
	var meteo := ""
	var vent := 0
	var sens := 1
	var _maillots: Array = []
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(_placer)
	func ajouter_equipe(app: Control, joueurs: Array, teinte: Color, camp: int, entrants: Dictionary) -> void:
		for i in mini(15, joueurs.size()):
			var j: Dictionary = joueurs[i]
			var m := Maillot.new()
			m.numero = i + 1
			m.teinte = teinte
			m.camp = camp
			m.nouveau = entrants.has(str(j.get("id", "")))
			m.nom = Nom.surname(str(j.get("name", ""))).to_upper() if not j.is_empty() else ""
			m.name = "Maillot_%d_%d" % [camp, i + 1]
			if not j.is_empty():
				var pid := str(j.get("id", ""))
				m.pressed.connect(func(): load("res://ui/immersive08/avant_match_feuille.gd").ouvrir_joueur(app, pid))
				MiniFiche.lier(app, m, pid, "squad" if not P.player(app.model, pid).is_empty() else "adverse")
				m.accessibility_name = "%d · %s" % [i + 1, str(j.get("name", ""))]
			else: m.disabled = true
			add_child(m)
			_maillots.append(m)
		_placer()
	func _zone() -> Rect2:
		return Rect2(Vector2(4, 4), size - Vector2(8, 8))
	func _placer() -> void:
		var z := _zone()
		var cote := clampf(minf(z.size.x, z.size.y) * (0.11 if vertical else 0.105), 22.0, 48.0)
		for m: Maillot in _maillots:
			var p: Vector2 = PLACES.get(m.numero, Vector2(.5, .5))
			var centre: Vector2
			if vertical: centre = z.position + Vector2(z.size.x * p.y, z.size.y * (1.0 - p.x * .92))
			elif m.camp == 0: centre = z.position + Vector2(z.size.x * p.x * .5, z.size.y * p.y)
			else: centre = z.position + Vector2(z.size.x * (1.0 - p.x * .5), z.size.y * (1.0 - p.y))
			# Terrain en largeur : ailiers ramenés dans la pelouse (le nom passe sous le maillot).
			if not vertical: centre.y = clampf(centre.y, z.position.y + cote * .7, z.end.y - cote * 1.6)
			m.cote = cote
			m.size = Vector2(cote * 2.6, cote * 1.55)
			m.position = centre - Vector2(m.size.x / 2.0, cote / 2.0)
			m.queue_redraw()
		queue_redraw()
	func _draw() -> void:
		var z := _zone()
		var fond := StyleBoxFlat.new()
		fond.bg_color = Charte.PELOUSE
		fond.set_corner_radius_all(Charte.RAYON_CARTE)
		draw_style_box(fond, z)
		var trait_ := Color(Charte.CREME, .28)
		var pas := 9 if vertical else 12
		for k in pas:
			if k % 2 == 1:
				var bande := Rect2(z.position + Vector2(0, z.size.y * k / pas), Vector2(z.size.x, z.size.y / pas)) if vertical else Rect2(z.position + Vector2(z.size.x * k / pas, 0), Vector2(z.size.x / pas, z.size.y))
				draw_rect(bande, Charte.PELOUSE_2)
		for f in ([0.04, 0.27, 0.96] if vertical else [0.04, 0.24, 0.5, 0.76, 0.96]):
			if vertical:
				var y: float = z.end.y - z.size.y * f
				draw_line(Vector2(z.position.x, y), Vector2(z.end.x, y), trait_, 2.0 if f in [0.04, 0.96] else 1.0)
			else:
				var x: float = z.position.x + z.size.x * f
				draw_line(Vector2(x, z.position.y), Vector2(x, z.end.y), trait_, 2.0 if f in [0.04, 0.5, 0.96] else 1.0)
		if not meteo.is_empty():
			var police: Font = Charte.TITRE_GRAS
			var t := 15 * echelle
			var largeur := police.get_string_size(meteo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t)).x
			var boite := Rect2(z.position.x + z.size.x / 2.0 - largeur / 2.0 - 14, z.position.y + 8, largeur + 28 + (34.0 * echelle if vent > 0 else 0.0), t + 12)
			var pil := StyleBoxFlat.new()
			pil.bg_color = Color(Charte.NOIR_PANNEAU, .82)
			pil.set_corner_radius_all(int(boite.size.y / 2.0))
			draw_style_box(pil, boite)
			draw_string(police, Vector2(boite.position.x + 14, boite.position.y + t + 3), meteo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(t), Color("8fc1e8"))
			if vent > 0:
				# Flèche du vent (1re période) : vers la droite = dans notre dos quand nous sommes à gauche.
				var y := boite.position.y + boite.size.y / 2.0
				var x0 := boite.end.x - 34.0 * echelle
				var x1 := boite.end.x - 12.0
				if sens < 0:
					var tmp := x0
					x0 = x1
					x1 = tmp
				draw_line(Vector2(x0, y), Vector2(x1, y), Color("8fc1e8"), 2.0 + vent)
				draw_colored_polygon(PackedVector2Array([Vector2(x1 + 4.0 * sens, y), Vector2(x1 - 6.0 * sens, y - 6), Vector2(x1 - 6.0 * sens, y + 6)]), Color("8fc1e8"))

## Maillot : rond à la couleur du club, numéro au centre, nom dessous ; ▲ vert = entre dans leur XV.
class Maillot extends Button:
	var numero := 0
	var teinte := Color.GRAY
	var camp := 0
	var nouveau := false
	var nom := ""
	var cote := 30.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for look in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(look, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var c := Vector2(size.x / 2.0, cote / 2.0)
		var r := cote / 2.0
		if is_hovered() or has_focus(): draw_circle(c, r + 4, Color(Charte.CREME, .9))
		draw_circle(c, r + 1.5, Color(0, 0, 0, .45))
		draw_circle(c, r, teinte)
		if nouveau: draw_arc(c, r + 2.5, 0, TAU, 32, Charte.GAIN, 3.0, true)
		var police: Font = Charte.TITRE_FICHE
		var t := int(r * 1.05)
		draw_string(police, Vector2(0, c.y + t * .36), str(numero), HORIZONTAL_ALIGNMENT_CENTER, size.x, t, RI.contrast(teinte))
		if not nom.is_empty():
			var tn := int(clampf(cote * .36, 10, 16))
			var largeur := Charte.TITRE_GRAS.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, tn).x
			var fond := Rect2(size.x / 2.0 - largeur / 2.0 - 4, cote + 2, largeur + 8, tn + 4)
			draw_rect(fond, Color(Charte.NOIR_PANNEAU, .72))
			draw_string(Charte.TITRE_GRAS, Vector2(fond.position.x + 4, fond.position.y + tn), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Charte.CREME)
		if nouveau:
			draw_string(Charte.TITRE_GRAS, Vector2(c.x + r - 2, c.y - r + 8), "▲", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cote * .4), Charte.GAIN)
