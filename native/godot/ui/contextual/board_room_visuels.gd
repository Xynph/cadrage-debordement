extends RefCounted
## Salle du conseil en visuels (option B de la planche du 21/11/2026) : anneaux pour la confiance et l'organisation,
## tuiles chiffre pour les moyens, jalons en cartes et sur la frise de la saison, décisions en cartes.
## Tout ce qui se clique ouvre une petite fenêtre visuelle (Échap, ✕ ou clic à côté la ferment) ou agit.
## Les données viennent toutes de la projection du moteur (clubStrategy) : rien n'est calculé ici hors mise en forme.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const P = preload("res://ui/immersive08/pastilles_club.gd")
const TV = preload("res://ui/contextual/training_visuels.gd")
const JaugeAnneau = preload("res://ui/jauge_anneau.gd")
const BarreEmpilee = preload("res://ui/barre_empilee.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const ICONES_JALON := {"wins": "trophy", "points": "star", "rank": "flag", "cash": "money"}
const COURTS_JALON := {"wins": "Victoires", "points": "Points", "rank": "Classement", "cash": "Trésorerie"}
const ICONES_PRIORITE := {"performance": "trophy", "stabilite": "shield", "finances": "money", "effectif": "people"}
const ICONES_PROJET := {"video": "search", "medical": "heart", "logistique": "bus", "logistics": "bus"}
## Statut d'un jalon : mot, icône (forme) et couleur ; la couleur n'est jamais seule.
const STATUTS := {
	"pending": ["À suivre", "clock", Charte.MORAL],
	"met": ["Atteint", "check", Charte.GAIN],
	"missed": ["Manqué", "warning", Charte.PERTE],
	"unverified": ["Non vérifiable", "info", Charte.GRIS_VERT],
}

static func nombre(valeur: Variant) -> bool:
	return (valeur is int or valeur is float) and is_finite(float(valeur))

static func euros(valeur: Variant) -> String:
	return P.euros_courts(valeur) if nombre(valeur) else "—"

static func entier(valeur: Variant) -> String:
	return str(roundi(float(valeur))) if nombre(valeur) else "—"

static func statut(goal: Dictionary) -> Array:
	return STATUTS.get(str(goal.get("status", "")), ["Non renseigné", "info", Charte.GRIS_VERT])

## Valeur affichée d'une mesure de jalon (euros courts pour la trésorerie, « 3e » pour un rang).
static func mesure(type: String, valeur: Variant) -> String:
	if not nombre(valeur): return "—"
	if type == "cash": return euros(valeur)
	if type == "rank": return "%de" % roundi(float(valeur)) if roundi(float(valeur)) != 1 else "1er"
	return entier(valeur)

## Part atteinte d'un jalon, 0..1 (le rang se lit à l'envers : plus petit = mieux).
static func avancement(type: String, actuel: Variant, cible: Variant) -> float:
	if not nombre(actuel) or not nombre(cible): return 0.0
	var a := float(actuel)
	var c := float(cible)
	if type == "rank": return 1.0 if a > 0.0 and a <= c else (clampf(c / a, 0.0, 1.0) if a > 0.0 else 0.0)
	if c <= 0.0: return 1.0
	return clampf(a / c, 0.0, 1.0)

# --- Petites pièces --------------------------------------------------------------------------------

## Titre de section : icône + capitales, gris-vert (le doré reste à Continuer).
static func titre(texte: String, icone: String = "") -> HBoxContainer:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 8)
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not icone.is_empty(): rangee.add_child(TV.icone(icone, 18, Charte.IVOIRE_2))
	rangee.add_child(TV.texte(texte.to_upper(), 16, Charte.IVOIRE_2, C.BOLD))
	return rangee

## Bouton plat qui porte une carte (contenu) : survol, focus clavier, curseur main ; sans action, la carte reste neutre.
static func cliquable(contenu: Control, id: String, action: Callable, libelle: String, actif: bool = true) -> Control:
	contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not action.is_valid():
		contenu.name = id
		return contenu
	var bouton := Button.new()
	bouton.name = id
	bouton.flat = true
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.disabled = not actif
	bouton.set_meta("contextual_enabled", actif)
	bouton.set_meta("immersive_style_applied", true)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	bouton.tooltip_text = libelle
	bouton.accessibility_name = libelle
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(Charte.RAYON_CARTE)
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .08)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: bouton.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: bouton.add_theme_stylebox_override(etat, survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.pressed.connect(action)
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bouton.add_child(marge)
	marge.add_child(contenu)
	var suivre := func() -> void: bouton.custom_minimum_size = marge.get_combined_minimum_size()
	marge.minimum_size_changed.connect(suivre)
	suivre.call()
	bouton.size_flags_horizontal = contenu.size_flags_horizontal
	bouton.size_flags_vertical = contenu.size_flags_vertical
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not actif: contenu.modulate = Color(1, 1, 1, .5)
	return bouton

## Anneau chiffré (JaugeAnneau) cliquable ; sans valeur connue, une tuile « — ».
static func anneau(valeur: Variant, legende: String, couleur: Color, id: String, action: Callable, diametre: float = 150.0) -> Control:
	if not nombre(valeur): return P.tuile("—", legende, Charte.IVOIRE, Charte.PANNEAU_2, 34, id, false, action)
	var jauge := JaugeAnneau.new(float(valeur), legende, couleur)
	jauge.diametre = diametre
	jauge.custom_minimum_size = Vector2(C.px(diametre + 60.0), C.px(diametre + 46.0))
	return cliquable(jauge, id, action, "%s %s / 100" % [legende, entier(valeur)])

## Tuile chiffre (pastilles_club) avec pictogramme à gauche du chiffre.
static func tuile(valeur: String, legende: String, couleur: Color, icone: String, id: String, action: Callable, taille: int = 30) -> Control:
	var carte := TV.carte(Charte.PANNEAU_2.lerp(couleur, .12) if couleur != Charte.IVOIRE else Charte.PANNEAU_2, Charte.RAYON_CARTE, 12)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	carte.add_child(colonne)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 8)
	if not icone.is_empty(): haut.add_child(TV.icone(icone, roundi(taille * .7), couleur if couleur != Charte.IVOIRE else Charte.IVOIRE_2))
	var chiffre := TV.texte(valeur, taille, couleur, Charte.TITRE_EXTRA)
	chiffre.name = "Valeur"
	haut.add_child(chiffre)
	colonne.add_child(haut)
	var mot := TV.texte(legende.to_upper(), 14, Charte.IVOIRE_2, C.BOLD)
	mot.name = "Legende"
	colonne.add_child(mot)
	return cliquable(carte, id, action, "%s %s" % [valeur, legende])

## Barre d'avancement d'un jalon : rail, part atteinte en couleur, cran de la cible au bout.
class Barre extends Control:
	var part := 0.0
	var couleur := Charte.MORAL
	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(0, 0, size.x, h), Charte.PANNEAU_3)
		if part > 0.0: draw_rect(Rect2(0, 0, size.x * part, h), couleur)
		draw_rect(Rect2(size.x - 3, -3, 3, h + 6), Charte.IVOIRE)

static func barre(part: float, couleur: Color, hauteur: float = 10.0) -> Barre:
	var b := Barre.new()
	b.part = part
	b.couleur = couleur
	b.custom_minimum_size = Vector2(80, hauteur)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## Carte d'un jalon : pictogramme + type, pastille de statut, « actuel / cible », barre, échéance « S46 ».
static func carte_jalon(goal: Dictionary, metrics: Dictionary, id: String, action: Callable, compacte: bool = false) -> Control:
	var type := str(goal.get("type", ""))
	var etat := statut(goal)
	var couleur: Color = etat[2]
	var carte := TV.carte(Charte.PANNEAU_2, Charte.RAYON_CARTE, 12)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	carte.add_child(colonne)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 8)
	haut.add_child(TV.icone(ICONES_JALON.get(type, "target"), 22, Charte.IVOIRE))
	var nom := TV.texte(COURTS_JALON.get(type, type).to_upper(), 17, Charte.IVOIRE, C.BOLD)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(nom)
	haut.add_child(TV.pastille(etat[1], etat[0], couleur, 14))
	colonne.add_child(haut)
	var chiffres := HBoxContainer.new()
	chiffres.add_theme_constant_override("separation", 6)
	var actuel := TV.texte(mesure(type, metrics.get(type)), 30 if not compacte else 26, Charte.IVOIRE, Charte.TITRE_EXTRA)
	actuel.name = "Actuel"
	chiffres.add_child(actuel)
	var cible := TV.texte("/ " + mesure(type, goal.get("target")), 18, Charte.IVOIRE_2, C.BOLD)
	cible.size_flags_vertical = Control.SIZE_SHRINK_END
	cible.name = "Cible"
	chiffres.add_child(cible)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chiffres.add_child(vide)
	var echeance := TV.pastille("calendar", "S" + entier(goal.get("deadline")), Charte.REPOS, 15)
	echeance.name = "Echeance"
	chiffres.add_child(echeance)
	colonne.add_child(chiffres)
	colonne.add_child(barre(avancement(type, metrics.get(type), goal.get("target")), couleur))
	return cliquable(carte, id, action, "%s · %s · %s / %s · S%s" % [COURTS_JALON.get(type, type), etat[0], mesure(type, metrics.get(type)), mesure(type, goal.get("target")), entier(goal.get("deadline"))])

## Frise de la saison : semaines 0..fin, semaine en cours, matchs du club (ballons : plein = joué, creux = à venir),
## drapeau de fin de saison, jalons posés à leur échéance (pictogramme dans un disque de la couleur du statut).
## Chaque jalon est un bouton (petite fenêtre) ; chaque ballon et le drapeau ouvrent le Calendrier sur la date du match
## (survol : main + halo). Un jalon proche de la fin monte au-dessus du drapeau, qui reste visible et cliquable.
## Hauteur ajustée aux jalons empilés : pas de vide sans jalon.
class Frise extends Control:
	var semaine := 0
	var fin := 1
	var jalons: Array = []  ## [{goal, action, id}]
	var matchs: Array = []  ## [{semaine, joue, date}]
	var boutons: Array = []
	var ballons: Array = []  ## boutons des matchs, même ordre que matchs
	var drapeau: Button
	const MARGE := 30.0
	const BOUTON := 44.0
	## Le drapeau occupe 30 px au-dessus de la ligne : un jalon à moins de 2 semaines de la fin se pose plus haut.
	const HAUSSE_FIN := 18.0
	func _ready() -> void:
		resized.connect(_placer)
		_placer()
	func pres_du_drapeau(s: int) -> bool:
		return s >= fin - 2
	func etages() -> int:
		var piles := {}
		var haut := 0
		for entree: Dictionary in jalons:
			var s := int(entree.goal.get("deadline", 0))
			piles[s] = int(piles.get(s, 0)) + 1
			haut = maxi(haut, piles[s])
		return haut
	func hausse() -> float:
		for entree: Dictionary in jalons:
			if pres_du_drapeau(int(entree.goal.get("deadline", 0))): return HAUSSE_FIN
		return 0.0
	func x_de(s: float) -> float:
		return MARGE + (size.x - 2.0 * MARGE) * clampf(s / maxf(1.0, float(fin)), 0.0, 1.0)
	func ligne_y() -> float:
		return size.y - 38.0
	func pied_jalon(s: int) -> float:
		return ligne_y() - 20.0 - (HAUSSE_FIN if pres_du_drapeau(s) else 0.0)
	func _placer() -> void:
		var piles := {}
		for i in boutons.size():
			var goal: Dictionary = jalons[i].goal
			var s := int(goal.get("deadline", 0))
			var rang: int = piles.get(s, 0)
			piles[s] = rang + 1
			var b: Button = boutons[i]
			b.size = Vector2(BOUTON, BOUTON)
			b.position = Vector2(x_de(s) - BOUTON * .5, pied_jalon(s) - BOUTON - rang * (BOUTON + 4.0))
		var pas := (size.x - 2.0 * MARGE) / maxf(1.0, float(fin))
		var largeur := clampf(pas, 24.0, 32.0)
		for i in ballons.size():
			var b: Button = ballons[i]
			b.size = Vector2(largeur, 24.0)
			b.position = Vector2(x_de(int(matchs[i].get("semaine", 0))) - largeur * .5, ligne_y() - 12.0)
		if drapeau != null:
			drapeau.size = Vector2(28.0, 24.0)
			drapeau.position = Vector2(x_de(fin) - 20.0, ligne_y() - 36.0)
		queue_redraw()
	func _ballon(centre: Vector2, plein: bool) -> void:
		# Ballon ovale, resserré quand les semaines sont serrées (1280) pour ne jamais se chevaucher.
		var rx := clampf((size.x - 2.0 * MARGE) / maxf(1.0, float(fin)) * .42, 3.0, 8.0)
		var points := PackedVector2Array()
		for k in 21: points.append(centre + Vector2(cos(TAU * k / 20.0) * rx, sin(TAU * k / 20.0) * rx * .62))
		if plein: draw_colored_polygon(points, Charte.IVOIRE_2)
		else:
			draw_colored_polygon(points, Charte.PANNEAU)
			draw_polyline(points, Charte.IVOIRE_2, 2.0, true)
	func _draw() -> void:
		var y := ligne_y()
		draw_line(Vector2(MARGE, y), Vector2(size.x - MARGE, y), Charte.PANNEAU_3, 8.0)
		if semaine > 0: draw_line(Vector2(MARGE, y), Vector2(x_de(semaine), y), Charte.IVOIRE_2, 8.0)
		var police: Font = C.BOLD
		for s in range(0, fin + 1):
			var x := x_de(s)
			var repere := s == 0 or s == fin or (s % 5 == 0 and fin - s >= 3)
			draw_line(Vector2(x, y + 6), Vector2(x, y + (14 if repere else 9)), Charte.IVOIRE_3, 2.0)
			if repere:
				var t := "S%d" % s
				var l := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				draw_string(police, Vector2(clampf(x - l * .5, 0.0, size.x - l), y + 30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Charte.IVOIRE_3)
		for m: Dictionary in matchs:
			_ballon(Vector2(x_de(int(m.get("semaine", 0))), y), bool(m.get("joue", false)))
		# Fin de saison : drapeau au bout de la ligne.
		var xf := x_de(fin)
		draw_line(Vector2(xf, y - 4), Vector2(xf, y - 30), Charte.IVOIRE, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(xf, y - 30), Vector2(xf - 16, y - 25), Vector2(xf, y - 20)]), Charte.IVOIRE)
		if semaine >= 0:
			var xs := x_de(clampi(semaine, 0, fin))
			draw_colored_polygon(PackedVector2Array([Vector2(xs - 9, y - 18), Vector2(xs + 9, y - 18), Vector2(xs, y - 6)]), Charte.IVOIRE)
			var t := "S%d" % semaine
			var l := C.EXTRA_BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string(C.EXTRA_BOLD, Vector2(clampf(xs - l * .5, 0.0, size.x - l), y - 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Charte.IVOIRE)
		# Tige de chaque jalon jusqu'à la ligne (au bout, elle rejoint le mât du drapeau).
		var piles := {}
		for i in jalons.size():
			var goal: Dictionary = jalons[i].goal
			var s := int(goal.get("deadline", 0))
			if piles.has(s): continue
			piles[s] = true
			draw_line(Vector2(x_de(s), pied_jalon(s)), Vector2(x_de(s), y), Charte.IVOIRE_2, 2.0)

## Bouton transparent posé sur un dessin de la frise (ballon, drapeau) : main au survol, léger halo ivoire, focus clavier.
static func zone_frise(id: String, libelle: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = libelle
	b.accessibility_name = libelle
	b.set_meta("immersive_style_applied", true)
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_corner_radius_all(12)
	var halo := vide.duplicate() as StyleBoxFlat
	halo.bg_color = Color(Charte.IVOIRE, .2)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	b.add_theme_stylebox_override("normal", vide)
	b.add_theme_stylebox_override("hover", halo)
	b.add_theme_stylebox_override("pressed", halo)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(action)
	return b

## `ouvrir_match` reçoit l'entrée du match ({semaine, joue, date}) ; le drapeau ouvre le dernier match de la saison.
static func frise(semaine: int, fin: int, jalons: Array, matchs: Array = [], ouvrir_match: Callable = Callable()) -> Frise:
	var f := Frise.new()
	f.name = "BoardSeasonFrise"
	f.semaine = semaine
	f.fin = maxi(1, fin)
	f.jalons = jalons
	for m: Dictionary in matchs:
		if int(m.get("semaine", -1)) >= 0 and int(m.get("semaine", -1)) <= f.fin: f.matchs.append(m)
	f.custom_minimum_size = Vector2(300, 72.0 + f.etages() * (Frise.BOUTON + 4.0) + f.hausse())
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ouvrir_match.is_valid():
		var dernier: Dictionary = {}
		for m: Dictionary in f.matchs:
			var b := zone_frise("BoardFriseMatch_S%d" % int(m.semaine), "S%d · %s" % [int(m.semaine), "Joué" if bool(m.get("joue", false)) else "À venir"], ouvrir_match.bind(m))
			f.add_child(b)
			f.ballons.append(b)
			if dernier.is_empty() or int(m.semaine) > int(dernier.semaine): dernier = m
		f.drapeau = zone_frise("BoardFriseFin", "Fin de saison · S%d" % f.fin, ouvrir_match.bind(dernier))
		f.add_child(f.drapeau)
	for entree: Dictionary in jalons:
		var goal: Dictionary = entree.goal
		var etat := statut(goal)
		var b := Button.new()
		b.name = str(entree.id)
		b.flat = false
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s · %s · S%s" % [COURTS_JALON.get(str(goal.get("type", "")), ""), etat[0], entier(goal.get("deadline"))]
		b.accessibility_name = b.tooltip_text
		b.set_meta("immersive_style_applied", true)
		for e in ["normal", "hover", "pressed", "focus"]:
			var st := Charte.style_pilule(etat[2] if e != "hover" else (etat[2] as Color).lightened(.2), Charte.IVOIRE if e == "focus" else Color.TRANSPARENT, 0, 0)
			if e == "focus": st.set_border_width_all(2)
			b.add_theme_stylebox_override(e, st)
		b.icon = C.icon_texture(ICONES_JALON.get(str(goal.get("type", "")), "target"), Charte.ENCRE)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 24)
		b.pressed.connect(entree.action)
		f.add_child(b)
		f.boutons.append(b)
	return f

# --- Décisions en cartes -------------------------------------------------------------------------

## Carte d'une priorité : grand pictogramme + mot ; la priorité en place porte un contour violet et « ✓ En place ».
static func carte_priorite(cle: String, mot: String, choisie: bool, actif: bool, action: Callable) -> Control:
	var carte := TV.carte(Charte.PANNEAU_2.lerp(Charte.CONFIANCE, .14) if choisie else Charte.PANNEAU_2, Charte.RAYON_CARTE, 12)
	if choisie:
		var style := Charte.style_panneau(Charte.PANNEAU_2.lerp(Charte.CONFIANCE, .14), Charte.RAYON_CARTE, 12)
		style.border_color = Charte.CONFIANCE
		style.set_border_width_all(2)
		carte.add_theme_stylebox_override("panel", style)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 10)
	carte.add_child(rangee)
	rangee.add_child(TV.icone(ICONES_PRIORITE.get(cle, "target"), 28, Charte.CONFIANCE if choisie else Charte.IVOIRE))
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(TV.texte(mot.to_upper(), 19, Charte.IVOIRE, C.EXTRA_BOLD))
	if choisie: colonne.add_child(TV.pastille("check", "En place", Charte.CONFIANCE, 13))
	rangee.add_child(colonne)
	return cliquable(carte, "BoardPriority_" + cle, action, mot + (" · en place" if choisie else ""), actif)

## Carte d'un projet : pictogramme, nom, coût en gros, pastille d'état (Engagé, Possible, Trop cher).
static func carte_projet(projet: Dictionary, tresorerie: Variant, actif: bool, action: Callable) -> Control:
	var engage := bool(projet.get("used", false))
	var abordable := nombre(projet.get("cost")) and nombre(tresorerie) and float(tresorerie) >= float(projet.cost)
	var etat: Array = ["Engagé", "check", Charte.GAIN] if engage else (["Possible", "money", Charte.REPOS] if abordable else ["Trop cher", "lock", Charte.PERTE])
	var carte := TV.carte(Charte.PANNEAU_2, Charte.RAYON_CARTE, 12)
	carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	carte.add_child(colonne)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 8)
	haut.add_child(TV.icone(ICONES_PROJET.get(str(projet.get("id", "")), "settings"), 22, Charte.IVOIRE))
	var nom := TV.texte(str(projet.get("label", "Projet")), 17, Charte.IVOIRE, C.BOLD)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(nom)
	colonne.add_child(haut)
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 8)
	var cout := TV.texte(euros(projet.get("cost")), 24, Charte.IVOIRE, Charte.TITRE_EXTRA)
	cout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(cout)
	bas.add_child(TV.pastille(etat[1], etat[0], etat[2], 13))
	colonne.add_child(bas)
	return cliquable(carte, "BoardProject_" + str(projet.get("id", "")), action, "%s · %s · %s" % [str(projet.get("label", "")), euros(projet.get("cost")), etat[0]], actif)

## Bouton pilule à pictogramme (contour, jamais doré).
static func pilule(texte: String, icone: String, action: Callable, actif: bool, id: String) -> Button:
	var b := preload("res://ui/contextual/skin.gd").button(texte, action, actif, false)
	b.name = id
	b.icon = C.icon_texture(icone, Charte.IVOIRE)
	b.add_theme_constant_override("icon_max_width", 18)
	return b

# --- Petite fenêtre ------------------------------------------------------------------------------

static func fermer(vue: Control) -> void:
	var ancienne := vue.find_child("BoardRoomWindow", true, false)
	if ancienne != null:
		ancienne.get_parent().remove_child(ancienne)
		ancienne.queue_free()

## Petite fenêtre visuelle au centre : voile (clic à côté ferme), panneau, pictogramme + titre, ✕ ; Échap la ferme.
static func fenetre(vue: Control, titre_texte: String, icone: String, couleur: Color, contenu: Control, largeur: float = 620.0) -> void:
	fermer(vue)
	var calque := Control.new()
	calque.name = "BoardRoomWindow"
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	vue.add_child(calque)
	var voile := Button.new()
	voile.name = "BoardRoomWindowVeil"
	voile.flat = false
	voile.focus_mode = Control.FOCUS_NONE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, .5)
	for etat in ["normal", "hover", "pressed", "focus"]: voile.add_theme_stylebox_override(etat, fond)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.pressed.connect(func(): fermer(vue))
	calque.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_PANNEAU, 24), Charte.RAYON_PANNEAU))
	panneau.custom_minimum_size = Vector2(largeur, 0)
	panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 16)
	panneau.add_child(colonne)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 10)
	haut.add_child(TV.icone(icone, 28, couleur))
	var t := TV.texte(titre_texte.to_upper(), 24, Charte.IVOIRE, C.EXTRA_BOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(t)
	var croix := Button.new()
	croix.name = "BoardRoomWindowClose"
	croix.text = "✕"
	croix.flat = true
	croix.tooltip_text = "Fermer"
	croix.add_theme_font_size_override("font_size", 22)
	croix.add_theme_color_override("font_color", Charte.IVOIRE_2)
	croix.pressed.connect(func(): fermer(vue))
	haut.add_child(croix)
	colonne.add_child(haut)
	colonne.add_child(contenu)
	PetiteFenetre.enregistrer(calque, func(): fermer(vue))

static func rangee(espace: int = 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", espace)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func colonne(espace: int = 12) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", espace)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Contenu : confiance de la direction (anneau) + bilan des jalons en tuiles + priorité en place.
static func contenu_confiance(confiance: Variant, board: Dictionary, priorites: Dictionary) -> Control:
	var c := colonne(14)
	var r := rangee(18)
	r.add_child(anneau(confiance, "Confiance", Charte.CONFIANCE, "BoardWindowTrust", Callable(), 190.0))
	var tuiles := GridContainer.new()
	tuiles.columns = 2
	tuiles.add_theme_constant_override("h_separation", 10)
	tuiles.add_theme_constant_override("v_separation", 10)
	tuiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var compte := {"met": 0, "pending": 0, "missed": 0, "unverified": 0}
	for goal: Dictionary in board.get("objectives", []): compte[str(goal.get("status", "pending"))] = int(compte.get(str(goal.get("status", "pending")), 0)) + 1
	for cle in ["met", "pending", "missed", "unverified"]:
		var e: Array = STATUTS[cle]
		tuiles.add_child(tuile(str(compte[cle]), e[0], e[2], e[1], "BoardWindowGoals_" + cle, Callable(), 28))
	r.add_child(tuiles)
	c.add_child(r)
	var p := str(board.get("priority", ""))
	if priorites.has(p):
		var ligne := rangee(8)
		ligne.add_child(TV.icone(ICONES_PRIORITE.get(p, "target"), 22, Charte.CONFIANCE))
		ligne.add_child(TV.texte("PRIORITÉ · " + str(priorites[p]).to_upper(), 18, Charte.IVOIRE, C.BOLD))
		c.add_child(ligne)
	return c

## Contenu : organisation (anneau), projets engagés, bilans archivés en barres par saison ; la règle derrière « i ».
static func contenu_organisation(board: Dictionary, saison: Callable) -> Control:
	var c := colonne(14)
	var r := rangee(18)
	r.add_child(anneau(board.get("organizationScore"), "Organisation", Charte.REPOS, "BoardWindowOrganization", Callable(), 190.0))
	var droite := colonne(10)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var engages := 0
	for projet: Dictionary in board.get("projectOptions", []): if projet.get("used", false): engages += 1
	droite.add_child(tuile("%d / %d" % [engages, (board.get("projectOptions", []) as Array).size()], "Projets engagés", Charte.GAIN if engages > 0 else Charte.IVOIRE, "check", "BoardWindowProjects", Callable(), 28))
	var history: Array = board.get("history", [])
	var barres := rangee(10)
	if history.is_empty(): barres.add_child(TV.pastille("hourglass", "Premier bilan en fin de saison", Charte.IVOIRE_2, 14))
	for report: Dictionary in history.slice(maxi(0, history.size() - 5)):
		var col := colonne(4)
		var score := float(report.get("score", 0)) if nombre(report.get("score")) else 0.0
		var b := barre(score / 100.0, Charte.REPOS, 10)
		b.custom_minimum_size = Vector2(70, 10)
		col.add_child(TV.texte(entier(report.get("score")), 22, Charte.IVOIRE, Charte.TITRE_EXTRA))
		col.add_child(b)
		col.add_child(TV.texte(str(saison.call(report.get("season"))), 13, Charte.IVOIRE_2, C.BOLD))
		barres.add_child(col)
	droite.add_child(barres)
	r.add_child(droite)
	c.add_child(r)
	if not str(board.get("notice", "")).is_empty():
		var ligne := rangee(8)
		ligne.add_child(P.info(str(board.notice), "i", "BoardWindowOrganizationInfo"))
		c.add_child(ligne)
	return c

## Contenu : semaine type (revenus contre salaires + autres coûts), marge, semaines restantes, projection ; règle derrière « i ».
static func contenu_moyens(finance: Dictionary) -> Control:
	var c := colonne(14)
	var grille := GridContainer.new()
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 10)
	var marge: Variant = null
	if nombre(finance.get("weeklyIncome")) and nombre(finance.get("weeklyCosts")): marge = float(finance.weeklyIncome) - float(finance.weeklyCosts)
	var signe := ("▲ " if float(marge) >= 0.0 else "▼ ") if nombre(marge) else ""
	grille.add_child(tuile(euros(finance.get("cash")), "Trésorerie", Charte.IVOIRE, "money", "BoardWindowCash", Callable(), 28))
	grille.add_child(tuile(signe + euros(marge), "Marge / sem.", (Charte.GAIN if float(marge) >= 0.0 else Charte.PERTE) if nombre(marge) else Charte.IVOIRE, "", "BoardWindowMargin", Callable(), 28))
	grille.add_child(tuile(entier(finance.get("remainingWeeks")), "Semaines restantes", Charte.IVOIRE, "calendar", "BoardWindowWeeks", Callable(), 28))
	c.add_child(grille)
	if nombre(finance.get("weeklyIncome")) and nombre(finance.get("weeklyCosts")):
		var salaires := float(finance.get("weeklyWages", 0)) if nombre(finance.get("weeklyWages")) else 0.0
		var k := func(x: float) -> int: return roundi(x / 1000.0)
		c.add_child(titre("Semaine type · k€", "money"))
		c.add_child(BarreEmpilee.new([{"valeur": k.call(float(finance.weeklyIncome)), "libelle": "revenus", "couleur": Charte.GAIN}]))
		c.add_child(BarreEmpilee.new([{"valeur": k.call(salaires), "libelle": "salaires", "couleur": Charte.INTENSIF}, {"valeur": k.call(maxf(0.0, float(finance.weeklyCosts) - salaires)), "libelle": "autres coûts", "couleur": Charte.PERTE}]))
	var bas := rangee(8)
	bas.add_child(tuile(euros(finance.get("baseForecast")), "Fin de saison", Charte.MORAL, "flag", "BoardWindowForecast", Callable(), 28))
	var notice := str(finance.get("notice", "")).replace("Montants de jeu fictifs.", "").strip_edges()
	if not notice.is_empty():
		var i := P.info(notice, "i", "BoardWindowFinanceInfo")
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bas.add_child(i)
	c.add_child(bas)
	return c

## Contenu : un jalon en grand (actuel, cible, échéance, semaines restantes, statut, barre).
static func contenu_jalon(goal: Dictionary, metrics: Dictionary, semaine: int) -> Control:
	var type := str(goal.get("type", ""))
	var etat := statut(goal)
	var c := colonne(14)
	var r := rangee(10)
	r.add_child(tuile(mesure(type, metrics.get(type)), "Actuel", Charte.IVOIRE, ICONES_JALON.get(type, "target"), "BoardWindowGoalNow", Callable(), 34))
	r.add_child(tuile(mesure(type, goal.get("target")), "Cible", etat[2], "target", "BoardWindowGoalTarget", Callable(), 34))
	r.add_child(tuile("S" + entier(goal.get("deadline")), "Échéance", Charte.REPOS, "calendar", "BoardWindowGoalDeadline", Callable(), 34))
	if nombre(goal.get("deadline")) and semaine > 0:
		r.add_child(tuile(str(maxi(0, int(goal.deadline) - semaine)), "Semaines", Charte.IVOIRE, "hourglass", "BoardWindowGoalLeft", Callable(), 34))
	c.add_child(r)
	c.add_child(barre(avancement(type, metrics.get(type), goal.get("target")), etat[2], 14))
	var ligne := rangee(8)
	ligne.add_child(TV.pastille(etat[1], etat[0], etat[2], 16))
	c.add_child(ligne)
	return c
