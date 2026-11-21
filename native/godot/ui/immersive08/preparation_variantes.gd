extends RefCounted
## PROVISOIRE (revue visuelle du 21/11/2026, n° 5) : deux options visuelles de Préparation › Consignes et du
## « plan proposé par le staff », à départager par Léo. `CD_VARIANTE_VISUELLE` = A (tuiles à schéma de terrain)
## ou B (cartes photo voilées) ; sans variable, l'écran actuel reste inchangé. Logique inchangée : `set_tactics`.
## `page` : le canevas de la Préparation (preparation_canvas.gd), dont on réutilise les aides (_titre, _zone, _marque…).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const MatchContext = preload("res://ui/preparation_match_context.gd")

## Effets tirés de la description de chaque intention : [mot, sens (haut/bas/egal), couleur].
const EFFETS := {
	"attack": {
		"equilibre": [["Jeu varié", "egal", R.BLEU], ["Fatigue", "egal", R.ORANGE]],
		"large": [["Gains", "haut", R.VERT], ["Fatigue", "haut", R.ORANGE], ["Fautes de main", "haut", R.ROUGE]],
		"conquete": [["Conservation", "haut", R.VERT], ["Fautes de main", "bas", R.VERT], ["Gains", "bas", R.ROUGE]],
		"occupation": [["Terrain", "haut", R.VERT], ["Ballon rendu", "haut", R.ROUGE], ["Fatigue", "bas", R.TURQUOISE]],
	},
	"defense": {
		"equilibre": [["Pression", "egal", R.BLEU], ["Couverture", "egal", R.BLEU], ["Fatigue", "egal", R.ORANGE]],
		"pression": [["Erreurs adverses", "haut", R.VERT], ["Fatigue", "haut", R.ORANGE], ["Pénalités", "haut", R.ROUGE]],
		"prudente": [["Brèches", "bas", R.VERT], ["Mètres cédés", "haut", R.ROUGE], ["Fatigue", "bas", R.TURQUOISE]],
	},
}
## Photos de la banque du jeu (option B).
const PHOTOS := {
	"attack": {"equilibre": "action-essai", "large": "action-franchissement", "conquete": "action-melee", "occupation": "action-coup-de-pied-but"},
	"defense": {"equilibre": "action-touche", "pression": "action-ballon-perdu", "prudente": "stade-pelouse-sec-jour"},
}
## Secteurs du rapport de force qui fondent chaque conseil du staff (option A).
const SECTEURS_CONSEIL := {
	"attack": {"conquete": ["power", "backs"], "large": ["backs"], "occupation": ["kick"], "equilibre": ["power", "backs"]},
	"defense": {"prudente": ["backs", "power"], "pression": ["discipline"], "equilibre": ["power", "backs"]},
}
const SECTEURS := {"scrum":"comp", "lineout":"comp", "power":"train", "backs":"plan", "kick":"plan", "discipline":"train"}
const DESTINATIONS := {"comp":"Composition", "plan":"Plan de jeu", "train":"Entraînement"}
const AIDE_ZONES := "Les consignes par zone gardent la priorité. Aucun changement automatique des 23."

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Cache l'état du match tant qu'il ne dit que la consigne générale (libérée avec l'étiquette : déconnexion automatique).
class Veille extends Node:
	var statut: Label
	func sur_modele(_modele: Dictionary) -> void:
		statut.visible = statut.text != MatchContext.PRE_MATCH_HINT

## ---- Schéma de terrain dessiné (option A) -------------------------------------------------------------

class Schema extends Control:
	var cote := "attack"
	var id := "equilibre"
	var accent := Color("7fbf7a")

	func _fleche(a: Vector2, b: Vector2, couleur: Color, epaisseur: float) -> void:
		draw_line(a, b, couleur, epaisseur, true)
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var t := epaisseur * 3.2
		draw_colored_polygon(PackedVector2Array([b + dir * t * .6, b - dir * t + n * t * .8, b - dir * t - n * t * .8]), couleur)

	func _courbe(points: PackedVector2Array, couleur: Color, epaisseur: float, pointilles: bool = false) -> void:
		for i in points.size() - 1:
			if pointilles and i % 2 == 1: continue
			draw_line(points[i], points[i + 1], couleur, epaisseur, true)

	func _joueur(p: Vector2, r: float, couleur: Color) -> void:
		draw_circle(p, r, couleur)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var terrain := Charte.VERT_FRANC
		draw_rect(Rect2(Vector2.ZERO, size), terrain)
		var ligne := Color(Charte.IVOIRE, .35)
		var e := maxf(1.0, h * .012)
		draw_rect(Rect2(Vector2(w * .03, h * .06), Vector2(w * .94, h * .88)), ligne, false, e)
		draw_line(Vector2(w * .5, h * .06), Vector2(w * .5, h * .94), ligne, e)
		for x in [.27, .73]: draw_line(Vector2(w * x, h * .06), Vector2(w * x, h * .94), Color(ligne, .18), e)
		var nous := Charte.IVOIRE
		var eux := Color(R.ORANGE, .9)
		var r := h * .045
		var epais := maxf(2.0, h * .028)
		if cote == "attack":
			var porteur := Vector2(w * .38, h * .5)
			match id:
				"large":
					for y in [.2, .35, .65, .8]: _joueur(Vector2(w * (.34 - absf(y - .5) * .12), h * y), r, nous)
					var haut := PackedVector2Array()
					var bas := PackedVector2Array()
					for i in 13:
						var t := i / 12.0
						haut.append(Vector2(lerpf(porteur.x, w * .86, t), lerpf(porteur.y, h * .16, sqrt(t))))
						bas.append(Vector2(lerpf(porteur.x, w * .86, t), lerpf(porteur.y, h * .84, sqrt(t))))
					_courbe(haut, accent, epais)
					_courbe(bas, accent, epais)
					_fleche(haut[11], haut[12], accent, epais)
					_fleche(bas[11], bas[12], accent, epais)
				"conquete":
					for p in [Vector2(.33, .42), Vector2(.33, .58), Vector2(.29, .5), Vector2(.36, .5), Vector2(.3, .36), Vector2(.3, .64)]:
						_joueur(Vector2(w * p.x, h * p.y), r, nous)
					_fleche(Vector2(w * .4, h * .5), Vector2(w * .56, h * .5), accent, epais * 1.8)
					for y in [.38, .5, .62]: _joueur(Vector2(w * .62, h * y), r, eux)
				"occupation":
					_joueur(Vector2(w * .2, h * .55), r, nous)
					var vol := PackedVector2Array()
					for i in 17:
						var t := i / 16.0
						vol.append(Vector2(lerpf(w * .22, w * .84, t), lerpf(h * .55, h * .4, t) - sin(t * PI) * h * .3))
					_courbe(vol, accent, epais, true)
					_fleche(vol[15], vol[16], accent, epais)
					draw_arc(Vector2(w * .84, h * .4), r * 2.2, 0, TAU, 24, accent, epais * .6)
				_:
					for y in [.3, .5, .7]: _joueur(Vector2(w * .3, h * y), r, nous)
					_joueur(porteur, r * 1.15, nous)
					_fleche(porteur, Vector2(w * .62, h * .26), accent, epais)
					_fleche(porteur, Vector2(w * .64, h * .5), accent, epais)
					_fleche(porteur, Vector2(w * .62, h * .74), accent, epais)
			draw_circle(porteur + Vector2(r * 1.6, -r * 1.2), r * .7, Color("d9cfa7"))
		else:
			# Défense : notre ligne (crème) face à l'attaque adverse qui vient de la droite (orange).
			for y in [.24, .5, .76]: _joueur(Vector2(w * .78, h * y), r, eux)
			var ligne_x := w * .52
			match id:
				"pression":
					for y in [.16, .32, .5, .68, .84]:
						_joueur(Vector2(ligne_x, h * y), r, nous)
						_fleche(Vector2(ligne_x + r * 1.6, h * y), Vector2(w * .7, h * y), accent, epais)
				"prudente":
					for y in [.16, .32, .5, .68, .84]:
						_joueur(Vector2(w * .44, h * y), r, nous)
						_fleche(Vector2(w * .44 + r * 1.4, h * y + r * .6), Vector2(w * .54, h * y + h * .1), accent, epais)
					_joueur(Vector2(w * .18, h * .5), r, nous)
					draw_line(Vector2(w * .12, h * .3), Vector2(w * .12, h * .7), Color(accent, .7), epais * .7)
				_:
					for y in [.16, .32, .5, .68, .84]:
						_joueur(Vector2(ligne_x, h * y), r, nous)
						_fleche(Vector2(ligne_x + r * 1.6, h * y), Vector2(w * .61, h * y), accent, epais)
					_joueur(Vector2(w * .24, h * .5), r, nous)

## ---- Pièces communes -----------------------------------------------------------------------------------

## Pastille d'effet : voile de la couleur, flèche ▲/▼ dessinée (ou « = »), mot. Renvoie la largeur posée.
static func pastille_effet(page, parent: Control, x: float, haut: float, effet: Array, taille: int = 18) -> float:
	var mot := str(effet[0])
	var couleur: Color = effet[2]
	var h := float(taille) + 16.0
	var w := 12.0 + 16.0 + 8.0 + R.largeur(mot, taille) + 14.0
	var fond := D.rect(parent, Rect2(x, haut, w, h), Color(couleur, .16), Charte.RAYON_PETIT)
	fond.name = "Effet_" + mot.replace(" ", "")
	page._marque(fond, 12, h / 2.0, 16, str(effet[1]), couleur)
	var libelle := D.text(fond, 36, h / 2.0 + float(taille) * .36, mot, taille, couleur, 700, R.largeur(mot, taille) + 4)
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

## Pastilles en ligne, retour à la ligne si la largeur manque. Renvoie le bas de la dernière ligne.
static func pastilles(page, parent: Control, x: float, haut: float, largeur: float, effets: Array, taille: int = 18) -> float:
	var cx := x
	var cy := haut
	var pas_y := float(taille) + 16.0 + 8.0
	for effet: Array in effets:
		var w := 12.0 + 16.0 + 8.0 + R.largeur(str(effet[0]), taille) + 14.0
		if cx > x and cx + w > x + largeur:
			cx = x
			cy += pas_y
		cx += pastille_effet(page, parent, cx, cy, effet, taille) + 8.0
	return cy + pas_y - 8.0

static func _style_carte(fond: Color, bord: Color, epaisseur: int) -> StyleBoxFlat:
	var style := C.box(fond, bord, Charte.RAYON_CARTE, 0)
	style.set_border_width_all(epaisseur if bord.a > 0.0 else 0)
	return style

## Bouton couvrant une carte : choisit l'intention (même commande qu'avant). Posé AVANT le contenu.
static func bouton_carte(page, parent: Control, rectangle: Rect2, pair: Array, option: Dictionary, choisi: bool, fond: Color) -> Button:
	var bouton := Button.new()
	bouton.name = "Preparation" + str(pair[3]) + "_" + str(option.id)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = str(option.get("label", "")) + "\n" + str(option.get("description", ""))
	bouton.accessibility_name = bouton.tooltip_text
	bouton.add_theme_stylebox_override("normal", _style_carte(fond, Charte.IVOIRE if choisi else Charte.FILET, 3 if choisi else 1))
	bouton.add_theme_stylebox_override("hover", _style_carte(fond.lightened(.06), Charte.IVOIRE if choisi else Charte.IVOIRE_3, 3 if choisi else 1))
	bouton.add_theme_stylebox_override("pressed", _style_carte(fond.lightened(.1), Charte.IVOIRE, 3))
	bouton.add_theme_stylebox_override("hover_pressed", _style_carte(fond.lightened(.1), Charte.IVOIRE, 3))
	bouton.add_theme_stylebox_override("disabled", _style_carte(fond, Charte.IVOIRE if choisi else Charte.FILET, 3 if choisi else 1))
	bouton.add_theme_stylebox_override("focus", _style_carte(Color.TRANSPARENT, Charte.IVOIRE, 2))
	bouton.pressed.connect(func():
		if not page.match_context.can_edit_tactics(): return
		var current: Dictionary = page.app.model.get("tactics", {})
		var payload := {"attack":current.get("attack", "equilibre"), "defense":current.get("defense", "equilibre")}
		payload[pair[0]] = option.id
		page.app._command("set_tactics", payload))
	bouton.set_meta("tactic_id", str(option.id))
	page.match_context.tactics.append(bouton)
	parent.add_child(bouton)
	D.place(bouton, rectangle)
	return bouton

## Coche « Choisie » (pilule crème) en haut à droite d'une carte.
static func coche(parent: Control, droite: float, haut: float) -> void:
	var w := 40.0 + R.largeur("CHOISIE", 16)
	var pilule := D.rect(parent, Rect2(droite - w, haut, w, 34), Charte.IVOIRE, Charte.RAYON_PILULE)
	pilule.name = "IntentionChoisie"
	var icone := C.icon("check", 18, Charte.PANNEAU)
	pilule.add_child(icone)
	D.place(icone, Rect2(10, 8, 18, 18))
	D.text(pilule, 32, 23, "CHOISIE", 16, Charte.PANNEAU, 700, w - 36).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _ignorer(noeud: Node) -> void:
	for enfant in noeud.get_children():
		if enfant is Control and not enfant is Button: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorer(enfant)

## ---- Onglet « Consignes » --------------------------------------------------------------------------------

static func consignes(page) -> void:
	var v := variante()
	var section: Control = page._section("PreparationConsignes")
	page.match_context.consignes = section
	var tactics: Dictionary = page.app.model.get("tactics", {})
	for i in 2:
		var pair: Array = [["attack", "attacks", "Avec le ballon", "Attack", "ball"], ["defense", "defenses", "Sans le ballon", "Defense", "shield"]][i]
		var card := D.panel(section, Rect2(i * 1132, 0, 1116, 853), pair[2], pair[4], "", "Preparation" + str(pair[3]))
		var options: Array = tactics.get(pair[1], [])
		if i == 0:
			var statut := D.text(card, 22, 108, "", 21, C.IVORY, 500, 745)
			statut.name = "PreparationMatchState"
			statut.visible = false
			var veille := Veille.new()
			veille.statut = statut
			statut.add_child(veille)
			page.match_context.status = statut
			page.match_context.pause_button = page._bouton(card, Rect2(771, 76, 323, 45), "Mettre en pause", page.match_context.pause_match, "ivoire", "", "PreparationPauseMatch")
			# Avant le match, la consigne générale reste une infobulle ; l'état ne s'affiche qu'une fois le match lancé.
			page.app.bridge.model_changed.connect(veille.sur_modele)
		var choisie := str(tactics.get(pair[0], ""))
		var nom_choisi := ""
		for option: Dictionary in options:
			if str(option.id) == choisie: nom_choisi = str(option.label)
		R.rond(card, 1116 - 22 - 26, 34, MatchContext.PRE_MATCH_HINT, "i", "PreparationIntentInfo" + str(pair[3]))
		var zone := Control.new()
		zone.name = "Preparation" + str(pair[3]) + "Scroll"
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(zone)
		D.place(zone, Rect2(17, 84, 1081, 751))
		if options.is_empty():
			D.text(zone, 6, 40, "—", 26, C.MUTED, 600)
			continue
		if v == "A": _tuiles_schema(page, zone, pair, options, choisie)
		else: _cartes_photo(page, zone, pair, options, choisie)
		if not nom_choisi.is_empty():
			var largeur_titre := R.largeur(str(pair[2]).to_upper(), 26, 800)
			R.pastille(card, 70 + largeur_titre + 18, 40, nom_choisi, R.VERT, "check", "PreparationChoix" + str(pair[3]), 18)
	var foot := D.panel(section, Rect2(0, 871, 2248, 95), "", "", "", "PreparationPlaybookNote")
	D.text(foot, 23, 58, "Consignes par zone", 30, C.IVORY, 700, 600)
	R.rond(foot, 23 + R.largeur("Consignes par zone", 30) + 18, 47, "Les consignes locales et les phases arrêtées se règlent dans le carnet de jeu.", "i", "PreparationZonesInfo")
	page._bouton(foot, Rect2(1702, 20, 523, 55), "Consignes par zone et phases arrêtées", func(): page.app._navigate("Plan de jeu"), "lien", "arrow", "PreparationOpenZones")

## Option A : grille de tuiles, schéma de terrain dessiné, titre, pastilles d'effet.
static func _tuiles_schema(page, zone: Control, pair: Array, options: Array, choisie: String) -> void:
	var colonnes := 2
	var ecart := 16.0
	var lignes := ceili(options.size() / float(colonnes))
	var w := (1081.0 - ecart) / colonnes
	var h := minf(345.0, (751.0 - ecart * (lignes - 1)) / lignes)
	for n in options.size():
		var option: Dictionary = options[n]
		var choisi := str(option.id) == choisie
		var x := (n % colonnes) * (w + ecart)
		var y := floorf(n / float(colonnes)) * (h + ecart)
		var tuile := Control.new()
		tuile.name = "Tuile_" + str(option.id)
		tuile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(tuile)
		D.place(tuile, Rect2(x, y, w, h))
		bouton_carte(page, tuile, Rect2(0, 0, w, h), pair, option, choisi, Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2)
		var effets: Array = EFFETS.get(pair[0], {}).get(str(option.id), [])
		var schema := Schema.new()
		schema.name = "Schema_" + str(option.id)
		schema.cote = pair[0]
		schema.id = str(option.id)
		schema.accent = R.VERT if pair[0] == "attack" else R.BLEU
		schema.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tuile.add_child(schema)
		D.place(schema, Rect2(14, 14, w - 28, h - 150))
		page._titre(tuile, 18, h - 98, str(option.label).to_upper(), 30, Charte.IVOIRE, w - 36)
		pastilles(page, tuile, 18, h - 78, w - 36, effets, 18)
		if choisi: coche(tuile, w - 24, 26)
		_ignorer(tuile)

## Option B : grandes cartes photo voilées, titre sur la photo, pastilles dessous.
static func _cartes_photo(page, zone: Control, pair: Array, options: Array, choisie: String) -> void:
	var ecart := 14.0
	var h := minf(225.0, (751.0 - ecart * (options.size() - 1)) / options.size())
	var bande := 56.0
	for n in options.size():
		var option: Dictionary = options[n]
		var choisi := str(option.id) == choisie
		var y := n * (h + ecart)
		var carte := Control.new()
		carte.name = "Carte_" + str(option.id)
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(carte)
		D.place(carte, Rect2(0, y, 1081, h))
		bouton_carte(page, carte, Rect2(0, 0, 1081, h), pair, option, choisi, Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2)
		var cadre := Control.new()
		cadre.clip_contents = true
		cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(cadre)
		D.place(cadre, Rect2(3, 3, 1075, h - bande - 3))
		var photo := D.photo(cadre, str(PHOTOS.get(pair[0], {}).get(str(option.id), "stade-pelouse-sec-jour")), Rect2(0, 0, 1075, h - bande - 3), .45)
		photo.tooltip_text = ""
		photo.modulate = Color(1, 1, 1, .9) if choisi else Color(.72, .72, .72, .9)
		var voile := TextureRect.new()
		var degrade := Gradient.new()
		degrade.set_color(0, Color(Charte.PANNEAU, .92))
		degrade.set_color(1, Color(Charte.PANNEAU, .05))
		var texture := GradientTexture2D.new()
		texture.gradient = degrade
		texture.fill_from = Vector2(0, .5)
		texture.fill_to = Vector2(.75, .5)
		voile.texture = texture
		voile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		voile.stretch_mode = TextureRect.STRETCH_SCALE
		voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(voile)
		D.place(voile, Rect2(0, 0, 1075, h - bande - 3))
		var hauteur_photo := h - bande
		page._titre(carte, 26, hauteur_photo / 2.0 + 16, str(option.label).to_upper(), 44, Charte.IVOIRE, 700)
		if choisi: coche(carte, 1081 - 18, 16)
		var effets: Array = EFFETS.get(pair[0], {}).get(str(option.id), [])
		pastilles(page, carte, 22, hauteur_photo + (bande - 34.0) / 2.0, 1040, effets, 18)
		_ignorer(carte)

## ---- Sous-page « Le plan proposé par le staff » --------------------------------------------------------

static func conseils(page, section: Control) -> float:
	page._retour(section)
	var conseil: Dictionary = page.reports.get("advice", {})
	var tactiques: Dictionary = page.app.model.get("tactics", {})
	var gauche: Panel = page._panneau(section, Rect2(0, 66, 1100, 760), "Le plan proposé par le staff", "PreparationAdvice")
	var aide := AIDE_ZONES
	if not str(page.reports.get("notice", "")).is_empty(): aide += "\n" + str(page.reports.get("notice", ""))
	R.rond(gauche, 20 + R.largeur("LE PLAN PROPOSÉ PAR LE STAFF", 26, 800) + 16, 31, aide, "i", "PreparationAdviceInfo")
	var paires := [["attack", "Avec le ballon", page._tactic_label(tactiques.get("attacks", []), conseil.get("attack")), str(conseil.get("attack", "")), str(conseil.get("attackReason", ""))], ["defense", "Sans le ballon", page._tactic_label(tactiques.get("defenses", []), conseil.get("defence")), str(conseil.get("defence", "")), str(conseil.get("defenceReason", ""))]]
	var bas := _conseils_a(page, gauche, paires) if variante() == "A" else _conseils_b(page, gauche, paires)
	var adopte: bool = page._plan_adopte(conseil)
	var adopter: Button = page._bouton(gauche, Rect2(24, bas, 440, 54), "Plan adopté" if adopte else "Adopter ce plan", func():
		page.state.sub = ""
		page.app._command("set_tactics", {"attack":conseil.attack, "defense":conseil.defence}), "lien", "check" if adopte else "arrow", "AdoptDossierPlan")
	adopter.alignment = HORIZONTAL_ALIGNMENT_LEFT
	adopter.disabled = adopte or conseil.is_empty() or not page.app._live().is_empty()
	_observations(page, section)
	return 66.0 + 760.0

## Option A : pour chaque côté, l'intention conseillée, les barres du rapport de force qui la fondent, les effets.
static func _conseils_a(page, gauche: Control, paires: Array) -> float:
	var domaines := {}
	for domaine: Dictionary in page.reports.get("domains", []): domaines[str(domaine.get("key", ""))] = domaine
	var y := 70.0
	for paire: Array in paires:
		page._etiquette(gauche, 24, y + 22, str(paire[1]))
		var titre: Label = page._titre(gauche, 24, y + 62, str(paire[2]), 36)
		titre.tooltip_text = str(paire[4])
		titre.mouse_filter = Control.MOUSE_FILTER_STOP
		R.rond(gauche, 24 + R.largeur(str(paire[2]), 36, 800) + 16, y + 50, str(paire[4]), "i", "PreparationAdviceReason_" + str(paire[0]))
		var cles: Array = SECTEURS_CONSEIL.get(paire[0], {}).get(str(paire[3]), [])
		var ligne := y + 84.0
		var condition := _condition(str(paire[4]))
		for cle: String in cles:
			var domaine: Dictionary = domaines.get(cle, {})
			if domaine.is_empty(): continue
			_barre_rapport(page, gauche, ligne, domaine)
			ligne += 50.0
		if paire[0] == "defense" and condition >= 0:
			_barre_condition(page, gauche, ligne, condition)
			ligne += 50.0
		var effets: Array = EFFETS.get(paire[0], {}).get(str(paire[3]), [])
		ligne = pastilles(page, gauche, 24, ligne + 8, 1050, effets, 18)
		y = ligne + 30.0
	return y

## Une ligne du rapport de force : secteur, nous (barre verte) contre eux (barre orange), écart ▲/▼. Clic : où agir.
static func _barre_rapport(page, parent: Control, y: float, domaine: Dictionary) -> void:
	var code: String = SECTEURS.get(str(domaine.get("key", "")), "")
	var libelle := str(domaine.get("label", "Secteur"))
	if not code.is_empty(): page._zone(parent, Rect2(14, y, 1072, 44), Callable(page, "_agir").bind(code), "PreparationAdviceSector_" + str(domaine.get("key", "")), "%s : agir dans « %s »" % [libelle, DESTINATIONS[code]])
	var propre: Variant = domaine.get("own")
	var adverse: Variant = domaine.get("opponent")
	page._texte(parent, 24, y + 30, libelle, 19, Charte.IVOIRE, 240).add_theme_font_override("font", Charte.TITRE_GRAS)
	var echelle := 250.0
	page._titre(parent, 270, y + 32, G.n(propre) if page._nombre(propre) else "—", 28, Charte.IVOIRE, 52, HORIZONTAL_ALIGNMENT_RIGHT)
	page._barre(parent, Rect2(330, y + 10, echelle, 22), Charte.PANNEAU_3)
	if page._nombre(propre): page._barre(parent, Rect2(330, y + 10, echelle * clampf(float(propre) / 100.0, 0, 1), 22), R.VERT)
	page._barre(parent, Rect2(600, y + 10, echelle, 22), Charte.PANNEAU_3)
	if page._nombre(adverse): page._barre(parent, Rect2(600, y + 10, echelle * clampf(float(adverse) / 100.0, 0, 1), 22), R.ORANGE)
	page._titre(parent, 860, y + 32, G.n(adverse) if page._nombre(adverse) else "—", 28, Charte.IVOIRE, 52)
	if page._nombre(propre) and page._nombre(adverse):
		var delta := int(propre) - int(adverse)
		var couleur: Color = R.VERT if delta > 0 else R.ROUGE if delta < 0 else Charte.N
		pastille_effet(page, parent, 930, y + 5, [("+%d" % delta) if delta > 0 else ("−%d" % -delta) if delta < 0 else "0", "haut" if delta > 0 else "bas" if delta < 0 else "egal", couleur], 18)

static func _condition(raison: String) -> int:
	var motif := RegEx.create_from_string("Condition[^0-9]*(\\d+)\\s*%")
	var trouve := motif.search(raison)
	return int(trouve.get_string(1)) if trouve != null else -1

static func _barre_condition(page, parent: Control, y: float, valeur: int) -> void:
	page._zone(parent, Rect2(14, y, 1072, 44), func(): page.app._navigate("Effectif"), "PreparationAdviceCondition", "Condition du XV : %d %%" % valeur)
	page._texte(parent, 24, y + 30, "Condition du XV", 19, Charte.IVOIRE, 240).add_theme_font_override("font", Charte.TITRE_GRAS)
	page._titre(parent, 270, y + 32, "%d" % valeur, 28, Charte.IVOIRE, 52, HORIZONTAL_ALIGNMENT_RIGHT)
	page._barre(parent, Rect2(330, y + 10, 520, 22), Charte.PANNEAU_3)
	var couleur: Color = R.VERT if valeur >= 84 else R.ORANGE if valeur >= 70 else R.ROUGE
	page._barre(parent, Rect2(330, y + 10, 520 * clampf(valeur / 100.0, 0, 1), 22), couleur)
	pastille_effet(page, parent, 930, y + 5, ["%d %%" % valeur, "haut" if valeur >= 84 else "bas", couleur], 18)

## Option B : carte de l'adjoint (portrait, nom), deux pilules des intentions conseillées, puis deux bandeaux photo.
static func _conseils_b(page, gauche: Control, paires: Array) -> float:
	var adjoint: Dictionary = page._adjoint()
	var carte := D.rect(gauche, Rect2(20, 66, 1060, 170), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = "PreparationAdviceStaffCard"
	var cadre := D.rect(carte, Rect2(16, 15, 140, 140), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	cadre.clip_contents = true
	if not adjoint.is_empty():
		var portrait := G.portrait(int(adjoint.get("portraitIndex", 0)), C.px(140), adjoint)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cadre.add_child(portrait)
		D.place(portrait, Rect2(0, 0, 140, 140))
	else:
		D.photo(cadre, "staff-adjoint", Rect2(0, 0, 140, 140), .2)
	var nom := str(adjoint.get("name", "Le staff"))
	page._titre(carte, 178, 52, nom, 32, Charte.IVOIRE, 520)
	page._etiquette(carte, 178, 80, str(adjoint.get("roleLabel", "Adjoint")) if not adjoint.is_empty() else "Staff", 400)
	var x := 178.0
	for paire: Array in paires:
		var libelle := str(paire[2])
		var w := 60.0 + R.largeur(libelle, 22)
		var pilule := D.rect(carte, Rect2(x, 100, w, 48), Color(R.VERT if paire[0] == "attack" else R.BLEU, .2), Charte.RAYON_PILULE, R.VERT if paire[0] == "attack" else R.BLEU)
		pilule.name = "PreparationAdvicePill_" + str(paire[0])
		var icone := C.icon("ball" if paire[0] == "attack" else "shield", 22, Charte.IVOIRE)
		pilule.add_child(icone)
		D.place(icone, Rect2(16, 13, 22, 22))
		D.text(pilule, 46, 32, libelle, 22, Charte.IVOIRE, 700, w - 52).mouse_filter = Control.MOUSE_FILTER_IGNORE
		R.cliquable(pilule, Callable(page, "_choose").bind(1), "PreparationAdvicePillZone_" + str(paire[0]), str(paire[1]) + " · " + libelle + "\n" + str(paire[4]))
		x += w + 14.0
	var y := 256.0
	var lw := 520.0
	for i in paires.size():
		var paire: Array = paires[i]
		var px := 20.0 + i * (lw + 20.0)
		var bloc := Control.new()
		bloc.name = "PreparationAdvicePhoto_" + str(paire[0])
		bloc.clip_contents = true
		bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauche.add_child(bloc)
		D.place(bloc, Rect2(px, y, lw, 200))
		var photo := D.photo(bloc, str(PHOTOS.get(paire[0], {}).get(str(paire[3]), "stade-pelouse-sec-jour")), Rect2(0, 0, lw, 200), .45)
		photo.tooltip_text = ""
		photo.modulate = Color(.8, .8, .8)
		var voile := D.rect(bloc, Rect2(0, 120, lw, 80), Color(Charte.PANNEAU, .78))
		voile.name = "Voile"
		page._etiquette(bloc, 18, 148, str(paire[1]), lw - 36)
		page._titre(bloc, 18, 186, str(paire[2]).to_upper(), 32, Charte.IVOIRE, lw - 36)
		R.cliquable(bloc, Callable(page, "_choose").bind(1), "PreparationAdvicePhotoZone_" + str(paire[0]), str(paire[4]))
		var effets: Array = EFFETS.get(paire[0], {}).get(str(paire[3]), [])
		pastilles(page, gauche, px, y + 216, lw, effets, 17)
	return y + 216 + 2 * 41.0 + 30.0

## Observations : sans signal, une pastille et un « i » remplacent la phrase.
static func _observations(page, section: Control) -> void:
	var droite: Panel = page._panneau(section, Rect2(1116, 66, 1132, 760), "Observations sur l’adversaire", "PreparationObservations")
	var signaux: Array = page.reports.get("signals", [])
	var ligne := 90.0
	if signaux.is_empty():
		R.pastille(droite, 24, ligne + 22, "Aucun signal net", R.BLEU, "", "PreparationObservationsVide", 18)
		R.rond(droite, 24 + R.largeur("Aucun signal net", 18) + 44, ligne + 16, "Il faut au moins trois matchs et dix phases de conquête observés.", "i", "PreparationObservationsInfo")
		ligne += 56.0
	for signal_row: Dictionary in signaux:
		page._titre(droite, 24, ligne + 24, str(signal_row.get("title", "")), 24)
		page._texte(droite, 24, ligne + 52, str(signal_row.get("evidence", "")), 17, Charte.IVOIRE_2, 1080)
		page._texte(droite, 24, ligne + 78, str(signal_row.get("advice", "")), 17, Charte.IVOIRE, 1080)
		ligne += 104.0
	var club_id := int(page._opponent().get("id", -1))
	page._etiquette(droite, 24, ligne + 30, "Joueurs pressentis à surveiller")
	var menaces: Array = page.reports.get("threats", [])
	for i in menaces.size():
		var menace: Dictionary = menaces[i]
		page._lien_joueur(droite, Rect2(20, ligne + 44 + i * 40, 420, 36), menace, 20, "PreparationAdviceThreat%d" % i, club_id)
		page._texte(droite, 460, ligne + 70 + i * 40, "%s  ·  %s" % [str(menace.get("pos", "")), str(menace.get("role", ""))], 17, Charte.IVOIRE_2, 640)
