extends RefCounted
## Club › Direction › Supporters, bloc Billetterie (retour de Léo du 23/11/2026 : « plus visuel ») :
## - en tête, le stade rempli : ≈ affluence en gros, capacité, barre de tribune en trois parts colorées (abonnés, billets
##   vendus estimés, places vides) ;
## - trois lignes larges, style des listes de l'Effectif : Billet, Abonnement saison, Grosse affiche ; icône colorée, prix en
##   gros, − / curseur (piste bon marché → cher, repère « Conseil » du responsable) / +, tendance estimée à droite ;
## - la carte du responsable de la billetterie : photo, nom, niveau, bascule « Billetterie confiée ».
## Tout est cliquable, un clic choisit et valide ; aucun chiffre exact du moteur (estimations ≈, tendances en flèches).
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/carnet_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const Tuile = preload("res://ui/tuile_choix.gd")
const LienZone = preload("res://ui/lien_zone.gd")
const Visuel = preload("res://ui/strategy_visuals.gd")

const ABONNES := Color("a88bd6")   ## violet : abonnés
const BILLETS := Color("7fbf7a")   ## vert : billets vendus
const VIDES := Color("3a4644")     ## gris : places vides
const LIGNES := [
	["base", "Billet", "money", Color("5b9bd5"), "Affluence"],
	["abonnement", "Abonnement saison", "heart", Color("a88bd6"), "Abonnés"],
	["affiche", "Grosse affiche", "star", Color("e0a04a"), "Affluence"],
]
const TENDANCES := {2: ["▲▲", Color("7fbf7a")], 1: ["▲", Color("7fbf7a")], 0: ["=", Color("abb7b1")], -1: ["▼", Color("e0a04a")], -2: ["▼▼", Color("d9634f")]}

## Barre de tribune : trois parts colorées sur toute la largeur.
class BarreStade extends Control:
	var parts: Array = []
	func _init(valeurs: Array) -> void:
		parts = valeurs
		custom_minimum_size = Vector2(0, 46)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var total := 0.0
		for p: Array in parts: total += maxf(0.0, float(p[0]))
		if total <= 0.0: return
		var x := 0.0
		for i in parts.size():
			var largeur := size.x * maxf(0.0, float(parts[i][0])) / total
			if largeur > 0.5: draw_rect(Rect2(x, 0, largeur, size.y), parts[i][1])
			x += largeur
		for k in range(1, 12):
			draw_line(Vector2(size.x * k / 12.0, 0), Vector2(size.x * k / 12.0, size.y), Color(0, 0, 0, 0.18), 2.0)

## Piste d'un prix : dégradé bon marché (vert) → cher (orange, puis rouge), poignée au prix choisi, repère doré du conseil.
## Un clic sur la piste choisit le prix à cet endroit ; un clic sur le repère applique le conseil.
class Piste extends Control:
	var minimum := 1
	var maximum := 100
	var pas := 1
	var prix := 1
	var conseil := -1
	var choisir: Callable
	var actif := true
	func _init(mini: int, maxi: int, p: int, valeur: int, avis: int, action: Callable, peut: bool) -> void:
		minimum = mini; maximum = maxi; pas = maxi(1, p); prix = valeur; conseil = avis; choisir = action; actif = peut
		custom_minimum_size = Vector2(300, 64)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if peut else Control.CURSOR_ARROW
	func _x(valeur: int) -> float:
		return 14.0 + (size.x - 28.0) * clampf(float(valeur - minimum) / maxf(1.0, float(maximum - minimum)), 0.0, 1.0)
	func _draw() -> void:
		var y := size.y * 0.62
		var etapes := 48
		for i in etapes:
			var t := float(i) / etapes
			var couleur := Color("7fbf7a").lerp(Color("e0a04a"), t * 2.0) if t < 0.5 else Color("e0a04a").lerp(Color("d9634f"), (t - 0.5) * 2.0)
			draw_rect(Rect2(14.0 + (size.x - 28.0) * t, y - 5, (size.x - 28.0) / etapes + 1, 10), couleur)
		if conseil > 0:
			var xc := _x(conseil)
			draw_colored_polygon(PackedVector2Array([Vector2(xc, y - 9), Vector2(xc - 9, y - 22), Vector2(xc + 9, y - 22)]), Charte.DORE)
			var police := get_theme_default_font()
			draw_string(police, Vector2(xc - 40, y - 28), "Conseil", HORIZONTAL_ALIGNMENT_CENTER, 80, 17, Charte.DORE)
		var xp := _x(prix)
		draw_circle(Vector2(xp, y), 13.0, Charte.CREME)
		draw_circle(Vector2(xp, y), 7.0, Charte.NOIR_PANNEAU)
	func valeur_en(x: float) -> int:
		var t := clampf((x - 14.0) / maxf(1.0, size.x - 28.0), 0.0, 1.0)
		var v := minimum + roundi(t * (maximum - minimum) / pas) * pas
		return clampi(v, minimum, maximum)
	## Un clic : près du repère (±16 px), le conseil ; ailleurs, le prix sous le pointeur.
	func cliquer(x: float) -> void:
		if not actif: return
		if conseil > 0 and absf(x - _x(conseil)) <= 16.0:
			choisir.call(conseil)
		else:
			var v := valeur_en(x)
			if v != prix: choisir.call(v)
	func cliquer_conseil() -> void:
		if actif and conseil > 0: choisir.call(conseil)
	func _gui_input(evenement: InputEvent) -> void:
		if evenement is InputEventMouseButton and evenement.button_index == MOUSE_BUTTON_LEFT and not evenement.pressed:
			accept_event()
			cliquer(evenement.position.x)

static func _texte(valeur: String, taille: int, couleur: Color, gras: bool = false) -> Label:
	var l := C.label(valeur, taille, couleur, gras, 700 if gras else 500)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func _ligne_style(couleur: Color = Charte.NOIR_PANNEAU) -> StyleBoxFlat:
	var s := C.box(couleur, Charte.FILET, Charte.RAYON_PETIT, 14)
	s.set_border_width_all(1)
	return s

## Le bloc entier. f : fans du modèle ; envoyer(commande, données) : commande du moteur ; ouvrir_public : petite fenêtre.
static func construire(parent: Container, f: Dictionary, locked: bool, envoyer: Callable, ouvrir_public: Callable) -> void:
	var t: Dictionary = f.get("ticketing", {})
	var capacite := int(t.get("capacity", f.get("capacity", 0)))
	var affluence := int(t.get("expectedAttendance", f.get("expectedAttendance", 0)))
	var abonnes := int(t.get("subscribersPresent", 0))
	var billets := int(t.get("ticketsSold", maxi(0, affluence - abonnes)))
	# 1. Le stade rempli.
	var tete := G.h(24)
	parent.add_child(tete)
	var chiffre := G.v(0)
	chiffre.add_child(_texte("≈ " + G.n(affluence), 46, Charte.CREME, true))
	chiffre.add_child(_texte("SPECTATEURS ESTIMÉS · %s PLACES" % G.n(capacite), 18, Charte.GRIS_VERT))
	tete.add_child(LienZone.relier(chiffre, "DirectionLien_Affluence", "Le public", ouvrir_public))
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(espace)
	var humeur := int(f.get("humeurPublic", 0))
	var teinte := Visuel.VERT if humeur > 0 else Visuel.ORANGE if humeur < 0 else Charte.GRIS_VERT
	var bulle := G.h(10)
	var coeur := Visuel.picto("heart", 34, teinte)
	coeur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bulle.add_child(coeur)
	var mots_humeur := G.v(0)
	mots_humeur.add_child(_texte("+%d %%" % humeur if humeur > 0 else "−%d %%" % absi(humeur) if humeur < 0 else "=", 30, teinte, true))
	mots_humeur.add_child(_texte("PUBLIC · HUMEUR", 18, Charte.GRIS_VERT))
	bulle.add_child(mots_humeur)
	tete.add_child(LienZone.relier(bulle, "DirectionLien_Humeur", "Le public", ouvrir_public))
	var barre := BarreStade.new([[abonnes, ABONNES], [billets, BILLETS], [maxi(0, capacite - abonnes - billets), VIDES]])
	barre.name = "BilletterieStade"
	parent.add_child(barre)
	var legende := G.h(26)
	parent.add_child(legende)
	for item: Array in [["Abonnés", abonnes, ABONNES, "DirectionLien_Abonnes"], ["Billets vendus", billets, BILLETS, ""], ["Places vides", maxi(0, capacite - abonnes - billets), VIDES, ""]]:
		var puce := G.h(8)
		var carre := ColorRect.new()
		carre.color = item[2]
		carre.custom_minimum_size = Vector2(18, 18)
		puce.add_child(carre)
		puce.add_child(_texte("%s ≈ %s" % [item[0], G.n(item[1])], 18, Charte.CREME))
		legende.add_child(LienZone.relier(puce, item[3], "Le public", ouvrir_public) if not str(item[3]).is_empty() else puce)
	# 2. Les trois prix.
	var prix: Dictionary = t.get("prices", {})
	var conseils: Variant = t.get("advice")
	var pistes: Dictionary = t.get("ranges", {})
	var tendances: Dictionary = t.get("trends", {})
	for ligne: Array in LIGNES:
		var kind: String = ligne[0]
		var couleur: Color = ligne[3]
		var valeur := int(prix.get(kind, 0))
		var r: Dictionary = pistes.get(kind, {"min": 1, "max": maxi(2, valeur * 3), "step": 1})
		var pas := int(r.get("step", 1))
		var cadre := PanelContainer.new()
		cadre.name = "Billetterie_" + kind
		cadre.add_theme_stylebox_override("panel", _ligne_style())
		parent.add_child(cadre)
		var rangee := G.h(16)
		cadre.add_child(rangee)
		var pastille := PanelContainer.new()
		var rond := C.box(Color(couleur, 0.22), couleur, 28, 8)
		rond.set_border_width_all(2)
		pastille.add_theme_stylebox_override("panel", rond)
		pastille.add_child(Visuel.picto(str(ligne[2]), 34, couleur))
		rangee.add_child(pastille)
		var nom := _texte(str(ligne[1]), 20, Charte.CREME, true)
		nom.custom_minimum_size.x = 200
		rangee.add_child(nom)
		var montant := _texte(G.euros(valeur), 38, couleur, true)
		montant.name = "BilletPrix_" + kind
		montant.custom_minimum_size.x = 150
		montant.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rangee.add_child(montant)
		var choisir := func(v: int): envoyer.call("club_ticket_price", {"kind": kind, "prix": v})
		rangee.add_child(Tuile.pilule("−", "BilletMoins_" + kind, not locked and valeur > pas, "", func(): choisir.call(maxi(1, valeur - pas))))
		var piste := Piste.new(int(r.get("min", 1)), int(r.get("max", 100)), pas, valeur, int(conseils.get(kind, -1)) if conseils is Dictionary else -1, choisir, not locked)
		piste.name = "BilletPiste_" + kind
		rangee.add_child(piste)
		rangee.add_child(Tuile.pilule("+", "BilletPlus_" + kind, not locked, "", func(): choisir.call(valeur + pas)))
		var tendance: Array = TENDANCES.get(int(tendances.get(kind, 0)), TENDANCES[0])
		var effet := G.v(0)
		effet.custom_minimum_size.x = 130
		var fleche := _texte(str(tendance[0]), 30, tendance[1], true)
		fleche.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fleche.name = "BilletTendance_" + kind
		effet.add_child(fleche)
		var quoi := _texte(str(ligne[4]), 18, Charte.GRIS_VERT)
		quoi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effet.add_child(quoi)
		rangee.add_child(effet)
	# 3. Le responsable de la billetterie : photo, nom, niveau, bascule « Billetterie confiée ».
	var staff: Variant = t.get("estimatedBy")
	if staff is Dictionary:
		var carte := PanelContainer.new()
		carte.name = "BilletterieResponsable"
		carte.add_theme_stylebox_override("panel", _ligne_style(Charte.BANDEAU))
		parent.add_child(carte)
		var rangee := G.h(18)
		carte.add_child(rangee)
		var fiche: Dictionary = (staff.get("person", {}) as Dictionary).duplicate(true)
		fiche.portraitRole = "staff"
		if not fiche.has("name"): fiche.name = str(staff.get("name", ""))
		var photo := G.portrait(0, 72, fiche)
		photo.custom_minimum_size = Vector2(72, 80)
		rangee.add_child(photo)
		var mots := G.v(4)
		mots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mots.alignment = BoxContainer.ALIGNMENT_CENTER
		mots.add_child(_texte(str(staff.get("name", "")), 22, Charte.CREME, true))
		var niveau := int(staff.get("level", 0))
		var badge := Tuile.pastille("Niveau %d" % niveau, Visuel.VERT if niveau >= 70 else Visuel.ORANGE if niveau < 55 else Visuel.BLEU, "star")
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mots.add_child(badge)
		rangee.add_child(mots)
		var delegue := bool(t.get("delegated", false))
		rangee.add_child(_bascule(delegue, locked, func(): envoyer.call("club_ticket_delegate", {"delegue": not delegue})))

## Bascule « Billetterie confiée » : interrupteur dessiné (allumé vert, éteint gris) et son mot ; un clic l'inverse.
class Interrupteur extends Control:
	var allume := false
	func _init(etat: bool) -> void:
		allume = etat
		custom_minimum_size = Vector2(64, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color("32644b") if allume else Color("3a4644")
		fond.border_color = Color("b6d6b6") if allume else Color("abb7b1")
		fond.set_border_width_all(2)
		fond.set_corner_radius_all(17)
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(size.x - 17.0 if allume else 17.0, size.y / 2.0), 12.0, Color("f2ecdc"))

static func _bascule(delegue: bool, locked: bool, action: Callable) -> Button:
	var b := Button.new()
	b.name = "BilletterieConfier"
	b.toggle_mode = true
	b.button_pressed = delegue
	b.disabled = locked
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(330, 60)
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var s := C.box(Charte.VERT_FRANC if delegue else Charte.NOIR_PANNEAU, Charte.VERT_CLAIR if delegue else Charte.FILET, Charte.RAYON_PILULE, 12)
		s.set_border_width_all(2)
		if etat == "focus": s.draw_center = false
		b.add_theme_stylebox_override(etat, s)
	var rangee := G.h(14)
	rangee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rangee.offset_left = 16; rangee.offset_right = -16
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_child(Interrupteur.new(delegue))
	var mot := _texte("Billetterie confiée" if delegue else "Confier la billetterie", 22, Charte.CREME, true)
	rangee.add_child(mot)
	b.add_child(rangee)
	b.pressed.connect(action)
	return b
