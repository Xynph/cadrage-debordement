extends RefCounted
## Préparation › onglet « Consignes » et sous-page « Le plan proposé par le staff » (option A de la revue visuelle du
## 21/11/2026, n° 5, choisie par Léo) : une tuile par intention, petit schéma de terrain dessiné, titre et pastilles
## d'effet ▲/▼ ; le plan du staff montre les barres du rapport de force qui le fondent. Aucune phrase à l'écran :
## les explications vont dans les ronds « i » et les infobulles. Commande inchangée : `set_tactics`.
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
## Secteurs du rapport de force qui fondent chaque conseil du staff.
const SECTEURS_CONSEIL := {
	"attack": {"conquete": ["power", "backs"], "large": ["backs"], "occupation": ["kick"], "equilibre": ["power", "backs"]},
	"defense": {"prudente": ["backs", "power"], "pression": ["discipline"], "equilibre": ["power", "backs"]},
}
const SECTEURS := {"scrum":"comp", "lineout":"comp", "power":"train", "backs":"plan", "kick":"plan", "discipline":"train"}
const DESTINATIONS := {"comp":"Composition", "plan":"Plan de jeu", "train":"Entraînement"}
const AIDE_ZONES := "Les consignes par zone gardent la priorité. Aucun changement automatique des 23."
## État du match en direct : pastille courte (mot + marque) ; la phrase complète reste dans l'infobulle.
const ETATS := {
	MatchContext.Phase.RUNNING: ["En direct", "cadenas", R.ORANGE],
	MatchContext.Phase.PAUSED: ["En pause", "egal", R.BLEU],
	MatchContext.Phase.HALFTIME: ["Mi-temps", "egal", R.BLEU],
	MatchContext.Phase.FINISHED: ["Match terminé", "cadenas", R.ROUGE],
	MatchContext.Phase.SEASON_ENDED: ["Saison terminée", "cadenas", R.ROUGE],
}

## Pastille d'état du match dans l'en-tête « Avec le ballon ». L'étiquette `status` (texte de match_context) reste
## cachée ; la pastille se refait après chaque changement du modèle (libérée avec la page : déconnexion automatique).
class Veille extends Control:
	var page
	var statut: Label

	func sur_modele(_modele: Dictionary) -> void:
		maj.call_deferred()

	func maj() -> void:
		if not is_inside_tree() or page == null or not is_instance_valid(page.match_context): return
		for enfant in get_children():
			remove_child(enfant)
			enfant.queue_free()
		var etat: Array = ETATS.get(page.match_context.current_phase, [])
		visible = not etat.is_empty()
		if etat.is_empty(): return
		var largeur: float = load("res://ui/immersive08/preparation_consignes.gd").pastille_effet(page, self, 0, 0, etat, 18, Callable(), "PreparationMatchStatePastille")
		var fond := get_child(get_child_count() - 1) as Control
		fond.mouse_filter = Control.MOUSE_FILTER_STOP
		fond.tooltip_text = statut.text
		fond.accessibility_name = statut.text
		size.x = largeur * C.density

## ---- Schéma de terrain dessiné -------------------------------------------------------------

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
## Avec `action`, la pastille devient cliquable (bouton `id`, voile au survol, focus visible).
static func pastille_effet(page, parent: Control, x: float, haut: float, effet: Array, taille: int = 18, action: Callable = Callable(), id: String = "") -> float:
	var mot := str(effet[0])
	var couleur: Color = effet[2]
	var h := float(taille) + 16.0
	var w := 12.0 + 16.0 + 8.0 + R.largeur(mot, taille) + 14.0
	var fond := D.rect(parent, Rect2(x, haut, w, h), Color(couleur, .16), Charte.RAYON_PETIT)
	fond.name = id if not id.is_empty() else "Effet_" + mot.replace(" ", "")
	page._marque(fond, 12, h / 2.0, 16, str(effet[1]), couleur)
	var libelle := D.text(fond, 36, h / 2.0 + float(taille) * .36, mot, taille, couleur, 700, R.largeur(mot, taille) + 4)
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action.is_valid(): R.cliquable(fond, action, id + "Zone", mot)
	return w

## Pastilles en ligne, retour à la ligne si la largeur manque. Renvoie le bas de la dernière ligne.
static func pastilles(page, parent: Control, x: float, haut: float, largeur: float, effets: Array, taille: int = 18, action: Callable = Callable(), prefixe: String = "") -> float:
	var cx := x
	var cy := haut
	var pas_y := float(taille) + 16.0 + 8.0
	for effet: Array in effets:
		var w := 12.0 + 16.0 + 8.0 + R.largeur(str(effet[0]), taille) + 14.0
		if cx > x and cx + w > x + largeur:
			cx = x
			cy += pas_y
		var id := (prefixe + str(effet[0]).replace(" ", "")) if not prefixe.is_empty() else ""
		cx += pastille_effet(page, parent, cx, cy, effet, taille, action, id) + 8.0
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
	var section: Control = page._section("PreparationConsignes")
	page.match_context.consignes = section
	var tactics: Dictionary = page.app.model.get("tactics", {})
	for i in 2:
		var pair: Array = [["attack", "attacks", "Avec le ballon", "Attack", "ball"], ["defense", "defenses", "Sans le ballon", "Defense", "shield"]][i]
		var card := D.panel(section, Rect2(i * 1132, 0, 1116, 853), pair[2], pair[4], "", "Preparation" + str(pair[3]))
		var options: Array = tactics.get(pair[1], [])
		var choisie := str(tactics.get(pair[0], ""))
		var nom_choisi := ""
		for option: Dictionary in options:
			if str(option.id) == choisie: nom_choisi = str(option.label)
		var x_etat := 70.0 + R.largeur(str(pair[2]).to_upper(), 26, 800) + 18.0
		if not nom_choisi.is_empty():
			var pastille := R.pastille(card, x_etat, 40, nom_choisi, R.VERT, "check", "PreparationChoix" + str(pair[3]), 18)
			x_etat += pastille.size.x / C.density + 12.0
		R.rond(card, 1116 - 22 - 26, 34, MatchContext.PRE_MATCH_HINT, "i", "PreparationIntentInfo" + str(pair[3]))
		if i == 0:
			# Match en direct : pastille d'état (mot + marque) et « Mettre en pause » dans l'en-tête, jamais sur les tuiles.
			var statut := D.text(card, 0, 0, "", 12, C.IVORY, 500, 10)
			statut.name = "PreparationMatchState"
			statut.visible = false
			page.match_context.status = statut
			var veille := Veille.new()
			veille.name = "PreparationMatchStateRow"
			veille.page = page
			veille.statut = statut
			veille.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(veille)
			D.place(veille, Rect2(x_etat, 23, 220, 34))
			page.app.bridge.model_changed.connect(veille.sur_modele)
			veille.maj.call_deferred()
			page.match_context.pause_button = page._bouton(card, Rect2(1116 - 22 - 26 - 16 - 280, 18, 280, 44), "Mettre en pause", page.match_context.pause_match, "ivoire", "", "PreparationPauseMatch")
		var defilement := ScrollContainer.new()
		defilement.name = "Preparation" + str(pair[3]) + "Scroll"
		defilement.follow_focus = true
		defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		card.add_child(defilement)
		D.place(defilement, Rect2(17, 84, 1081, 751))
		var cle: String = pair[0]
		defilement.get_v_scroll_bar().value_changed.connect(func(value: float):
			if page.focus_ready: page.state[cle] = int(value))
		var zone := Control.new()
		zone.name = "Preparation" + str(pair[3]) + "Tuiles"
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		defilement.add_child(zone)
		if options.is_empty():
			zone.custom_minimum_size = Vector2(C.px(1063), C.px(60))
			D.text(zone, 6, 40, "—", 26, C.MUTED, 600)
			continue
		_tuiles_schema(page, zone, pair, options, choisie)
	var foot := D.panel(section, Rect2(0, 871, 2248, 95), "", "", "", "PreparationPlaybookNote")
	D.text(foot, 23, 58, "Consignes par zone", 30, C.IVORY, 700, 600)
	R.rond(foot, 23 + R.largeur("Consignes par zone", 30) + 18, 47, "Les consignes locales et les phases arrêtées se règlent dans le carnet de jeu.", "i", "PreparationZonesInfo")
	page._bouton(foot, Rect2(1702, 20, 523, 55), "Consignes par zone et phases arrêtées", func(): page.app._navigate("Plan de jeu"), "lien", "arrow", "PreparationOpenZones")

## Grille de tuiles (deux colonnes) : schéma de terrain dessiné, titre, pastilles d'effet ; la tuile entière choisit.
static func _tuiles_schema(page, zone: Control, pair: Array, options: Array, choisie: String) -> void:
	var colonnes := 2
	var ecart := 16.0
	var lignes := ceili(options.size() / float(colonnes))
	var w := (1063.0 - ecart) / colonnes
	var h := clampf((751.0 - ecart * (lignes - 1)) / lignes, 300.0, 345.0)
	zone.custom_minimum_size = Vector2(C.px(1063), C.px(lignes * h + (lignes - 1) * ecart))
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
	var bas := _conseils_barres(page, gauche, paires)
	var adopte: bool = page._plan_adopte(conseil)
	var adopter: Button = page._bouton(gauche, Rect2(24, bas, 440, 54), "Plan adopté" if adopte else "Adopter ce plan", func():
		# Retour au dossier : le plan adopté s'y lit tout de suite.
		page.state.sub = ""
		page.app._command("set_tactics", {"attack":conseil.attack, "defense":conseil.defence}), "lien", "check" if adopte else "arrow", "AdoptDossierPlan")
	adopter.alignment = HORIZONTAL_ALIGNMENT_LEFT
	adopter.disabled = adopte or conseil.is_empty() or not page.app._live().is_empty()
	_observations(page, section)
	return 66.0 + 760.0

## Pour chaque côté : l'intention conseillée (clic : onglet Consignes), les barres du rapport de force qui la fondent
## (clic : où agir), les effets en pastilles (clic : onglet Consignes). La raison complète est dans le « i ».
static func _conseils_barres(page, gauche: Control, paires: Array) -> float:
	var domaines := {}
	for domaine: Dictionary in page.reports.get("domains", []): domaines[str(domaine.get("key", ""))] = domaine
	var vers_consignes := Callable(page, "_choose").bind(1)
	var y := 70.0
	for paire: Array in paires:
		page._etiquette(gauche, 24, y + 22, str(paire[1]))
		var largeur_titre := R.largeur(str(paire[2]), 36, 800)
		page._zone(gauche, Rect2(14, y + 28, largeur_titre + 20, 44), vers_consignes, "PreparationAdviceIntent_" + str(paire[0]), str(paire[1]) + " · " + str(paire[2]))
		page._titre(gauche, 24, y + 62, str(paire[2]), 36)
		R.rond(gauche, 24 + largeur_titre + 16, y + 50, str(paire[4]), "i", "PreparationAdviceReason_" + str(paire[0]))
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
		ligne = pastilles(page, gauche, 24, ligne + 8, 1050, effets, 18, vers_consignes, "PreparationAdviceEffect_" + str(paire[0]) + "_")
		y = ligne + 30.0
	return y

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
