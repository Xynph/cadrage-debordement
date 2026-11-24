extends RefCounted
## Onglet Développement de la fiche joueur (effectif du club) : « Progression par qualité » (idée FM27 n° 14, option A
## choisie par Léo le 23/11/2026). En haut, la courbe sur 12 mois des qualités cochées (une couleur par qualité) ;
## pastille « Niveau » = courbe de la note de niveau. En dessous, la grille des 36 qualités à cocher, écart sur 12 mois
## en vert (+) ou rouge (−) à côté de chaque note. Un clic coche ou décoche tout de suite.
## Les courbes viennent du relevé mensuel du moteur (native/engine/releve-qualites.cjs, champ « releve » du joueur) :
## un point par mois relevé, plus la valeur d'aujourd'hui. Aucun point inventé : un mois non relevé reste vide (ancienne
## sauvegarde : la courbe commence au chargement).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Academy = preload("res://ui/immersive08/academy_canvas.gd")

const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
## Une couleur franche par qualité cochée (six au plus), jetons de la charte puis rose et citron.
const TEINTES := [Color("5b9bd5"), Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("e07bb0"), Color("d4e35c")]
const FAMILLES := [Color("e0a04a"), Color("a88bd6"), Color("4fb3a9"), Color("5b9bd5")]
const MAX_COCHES := 6
## Ordre des 36 qualités dans le relevé (releve-qualites.cjs, CLES).
const CLES := ["passing", "receiving", "offload", "tackling", "jackal", "ruckClearout", "ballCarry", "evasion",
	"kickDistance", "kickAccuracy", "goalAccuracy", "ballHandling", "decisions", "anticipation", "vision", "positioning",
	"composure", "discipline", "teamwork", "leadership", "workRate", "acceleration", "topSpeed", "agility", "explosiveness",
	"strength", "endurance", "jumping", "scrumTechnique", "hooking", "lineoutThrow", "lineoutJump", "lineoutLift", "maul",
	"kickChase", "aerialAbility"]
const ALPHA := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
## 13 places sur la courbe : 12 mois relevés (le plus récent en 11) puis aujourd'hui (12).
const PLACES := 13

# --- Relevé ----------------------------------------------------------------------------------------------------------

static func _u2(s: String) -> int:
	return ALPHA.find(s[0]) * 64 + ALPHA.find(s[1])

static func _d1(c: String) -> int:
	return ALPHA.find(c) - 32

static func _entree(dix: Array, e: String) -> void:
	var commun := _d1(e[1])
	for i in 36: dix[i] += commun
	var vues := {}
	var k := 2
	while k + 2 <= e.length():
		var i := ALPHA.find(e[k])
		if i >= 0 and i < 36:
			if not vues.has(i):
				vues[i] = true
				dix[i] -= commun
			dix[i] += _d1(e[k + 1])
		k += 2

## Relevé lu (format de releve-qualites.cjs) : {mois: ["AAAA-MM"…], niveau: [int|null…], qualites: {clé: [float|null…]}},
## du plus ancien au plus récent ; {} si absent ou illisible.
static func releve(player: Dictionary) -> Dictionary:
	var rq := str(player.get("releve", ""))
	var sans := rq.begins_with("~")
	if sans: rq = rq.substr(1)
	var parts := rq.split(",")
	var tete: String = parts[0] if parts.size() > 0 else ""
	if tete.length() != 82 or tete[7] != ":": return {}
	var debut := tete.substr(0, 7)
	var an := debut.substr(0, 4).to_int()
	var m := debut.substr(5, 2).to_int()
	if an < 2000 or m < 1 or m > 12: return {}
	for c in tete.substr(8):
		if ALPHA.find(c) < 0: return {}
	var note := _u2(tete.substr(8, 2))
	var dix: Array = []
	for i in 36: dix.append(_u2(tete.substr(10 + 2 * i, 2)))
	var points: Array = [null if sans else {"note": note, "dix": dix.duplicate()}]
	for k in range(1, parts.size()):
		var e: String = parts[k]
		if e == "~":
			points.append(null)
			continue
		if e.length() < 2: return {}
		note += _d1(e[0])
		_entree(dix, e)
		points.append({"note": note, "dix": dix.duplicate()})
	var mois: Array = []
	var niveau: Array = []
	var qualites := {}
	for c: String in CLES: qualites[c] = []
	for k in points.size():
		var mm := m - 1 + k
		mois.append("%04d-%02d" % [an + floori(mm / 12.0), posmod(mm, 12) + 1])
		var p: Variant = points[k]
		niveau.append(null if p == null else p.note)
		for i in 36: (qualites[CLES[i]] as Array).append(null if p == null else float(p.dix[i]) / 10.0)
	return {"mois": mois, "niveau": niveau, "qualites": qualites}

static func _index_mois(texte: String) -> int:
	return texte.substr(0, 4).to_int() * 12 + texte.substr(5, 2).to_int() - 1

## Mois du jeu (AAAA-MM) ; à défaut, celui du dernier relevé.
static func mois_courant(app: Control, rel: Dictionary) -> String:
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	if today.length() >= 7 and today[4] == "-": return today.substr(0, 7)
	var liste: Array = rel.get("mois", [])
	return str(liste[-1]) if not liste.is_empty() else ""

## Série sur les 13 places : relevés du mois courant − 11 au mois courant (null si non relevé), puis `aujourdhui`.
static func places(rel: Dictionary, serie: Array, courant: String, aujourdhui: float) -> Array:
	var sortie: Array = []
	sortie.resize(PLACES)
	sortie.fill(null)
	if not courant.is_empty():
		var fin := _index_mois(courant)
		var liste: Array = rel.get("mois", [])
		for k in liste.size():
			var place := 11 - (fin - _index_mois(str(liste[k])))
			if place >= 0 and place <= 11 and serie[k] != null: sortie[place] = float(serie[k])
	sortie[12] = aujourdhui
	return sortie

## Écart sur 12 mois : aujourd'hui moins le plus ancien relevé de la fenêtre (0 sans relevé).
static func ecart(serie: Array) -> int:
	for v: Variant in serie.slice(0, 12):
		if v != null: return roundi(float(serie[12]) - float(v))
	return 0

static func etiquettes(courant: String) -> Array[String]:
	var sortie: Array[String] = []
	var fin := _index_mois(courant) if not courant.is_empty() else 0
	for k in PLACES: sortie.append(MOIS[posmod(fin - 11 + k, 12)])
	return sortie

static func valeurs(player: Dictionary) -> Dictionary:
	var v: Variant = player.get("attributesV2")
	return v if v is Dictionary and v.size() == 36 else {}

## [{cle, libelle, famille, valeur, ecart, serie (13 places)}] pour les 36 qualités.
static func qualites(app: Control, player: Dictionary) -> Array:
	var v := valeurs(player)
	var rel := releve(player)
	var courant := mois_courant(app, rel)
	var sortie: Array = []
	for f in PlayerAttributes.GROUPS.size():
		for pair: Array in PlayerAttributes.GROUPS[f][1]:
			var valeur: Variant = v.get(pair[0])
			if not (valeur is int or valeur is float): continue
			var brute: Array = rel.get("qualites", {}).get(pair[0], [])
			var s := places(rel, brute, courant, float(valeur))
			sortie.append({"cle": pair[0], "libelle": pair[1], "famille": f, "valeur": float(valeur), "ecart": ecart(s), "serie": s})
	return sortie

## Note de niveau sur les 13 places (relevé + aujourd'hui).
static func niveau(app: Control, player: Dictionary) -> Array:
	var rel := releve(player)
	return places(rel, rel.get("niveau", []), mois_courant(app, rel), float(player.get("rating", 0)))

# --- État ------------------------------------------------------------------------------------------------------------

static func etat(app: Control, player: Dictionary, liste: Array) -> Dictionary:
	var e: Variant = app.management_ui.get("progression")
	if e is Dictionary and str(e.get("joueur", "")) == str(player.get("id", "")): return e
	var tri := liste.duplicate()
	tri.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.ecart) > int(b.ecart) or (int(a.ecart) == int(b.ecart) and float(a.valeur) > float(b.valeur)))
	var coches: Array = []
	for q: Dictionary in tri.slice(0, 3): coches.append(q.cle)
	var neuf := {"joueur": str(player.get("id", "")), "coches": coches, "vue": "qualites"}
	app.management_ui["progression"] = neuf
	return neuf

static func _basculer(app: Control, e: Dictionary, cle: String) -> void:
	var coches: Array = e.coches
	if cle in coches: coches.erase(cle)
	elif coches.size() < MAX_COCHES: coches.append(cle)
	else:
		coches.pop_front()
		coches.append(cle)
	e.vue = "qualites"
	app._render()

static func _vue(app: Control, e: Dictionary, vue: String) -> void:
	e.vue = vue
	app._render()

static func teinte(e: Dictionary, cle: String) -> Color:
	var i: int = (e.coches as Array).find(cle)
	return TEINTES[i % TEINTES.size()] if i >= 0 else Charte.IVOIRE_3

# --- Courbe ----------------------------------------------------------------------------------------------------------

## Courbe multi-séries : [{valeurs: 13 places (float ou null), couleur, court}], axe Y bas/haut, 12 mois + aujourd'hui.
## Une place vide coupe la ligne ; un point isolé est dessiné en rond.
class Courbe extends Control:
	var series: Array = []
	var etiquettes: Array[String] = []
	var bas := 20.0
	var haut := 100.0
	var pas := 10.0

	func _y(v: float, top: float, bottom: float) -> float:
		return lerpf(bottom, top, inverse_lerp(bas, haut, v))

	func _draw() -> void:
		var font: Font = C.font(600)
		var px := maxi(12, C.px(18))
		var left := float(C.px(56))
		var right := size.x - C.px(150)
		var top := float(C.px(16))
		var bottom := size.y - C.px(40)
		var v := bas
		while v <= haut + .01:
			var y := _y(v, top, bottom)
			draw_line(Vector2(left, y), Vector2(right, y), Color(Charte.FILET, .9), 1.0)
			draw_string(font, Vector2(0, y + px * .35), str(roundi(v)), HORIZONTAL_ALIGNMENT_RIGHT, left - C.px(12), px, Charte.IVOIRE_3)
			v += pas
		for k in etiquettes.size():
			var x := lerpf(left, right, float(k) / 12.0)
			if k % 2 == 0 or k == 12:
				var mot := "auj." if k == 12 else etiquettes[k]
				var large := font.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				draw_string(font, Vector2(x - large / 2.0, size.y - C.px(8)), mot, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Charte.IVOIRE_2)
				draw_line(Vector2(x, bottom), Vector2(x, bottom + C.px(6)), Charte.IVOIRE_3, 1.0)
		var fin_y: Array[float] = []
		for s: Dictionary in series:
			var vals: Array = s.valeurs
			var couleur: Color = s.couleur
			var epais := maxf(2.0, C.px(4))
			var ligne := PackedVector2Array()
			var dernier := Vector2.ZERO
			for k in vals.size():
				if vals[k] == null:
					_trait(ligne, couleur, epais)
					ligne = PackedVector2Array()
					continue
				dernier = Vector2(lerpf(left, right, float(k) / 12.0), _y(float(vals[k]), top, bottom))
				ligne.append(dernier)
			_trait(ligne, couleur, epais)
			draw_circle(dernier, maxf(3.0, C.px(7)), couleur, true, -1, true)
			# Étiquette en bout de courbe, décalée si elle chevauche la précédente.
			var ey := dernier.y
			for autre: float in fin_y:
				if absf(autre - ey) < px * 1.15: ey = autre + px * 1.15
			fin_y.append(ey)
			var libelle := "%s %s" % [str(s.get("court", "")), str(roundi(float(vals[-1])))]
			draw_string(font, Vector2(right + C.px(16), ey + px * .35), libelle, HORIZONTAL_ALIGNMENT_LEFT, C.px(134), px, couleur)

	func _trait(points: PackedVector2Array, couleur: Color, epais: float) -> void:
		if points.size() >= 2: draw_polyline(points, couleur, epais, true)
		elif points.size() == 1: draw_circle(points[0], maxf(2.5, C.px(5)), couleur, true, -1, true)

# --- Pièces ----------------------------------------------------------------------------------------------------------

static func _pilule(parent: Control, zone: Rect2, texte: String, choisi: bool, id: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = texte
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Charte.texte_moyen() if choisi else C.BODY)
	b.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for etat_police in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(etat_police, Charte.PANNEAU if choisi else Charte.IVOIRE_2)
	var fond := C.box(Charte.IVOIRE if choisi else Color.TRANSPARENT, Color.TRANSPARENT if choisi else Color(Charte.CREME, .25), Charte.RAYON_PILULE, 10)
	if not choisi: fond.set_border_width_all(1)
	var survol := C.box(Charte.IVOIRE if choisi else Charte.PANNEAU_2, Color(Charte.CREME, .25), Charte.RAYON_PILULE, 10)
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, Charte.sans_ombre(fond))
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, Charte.sans_ombre(survol))
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

static func _ligne_bouton(parent: Control, zone: Rect2, id: String, marque: bool, action: Callable, tip: String) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	var fond := Charte.sans_ombre(C.box(Charte.SELECTION if marque else Color.TRANSPARENT, Color.TRANSPARENT, 6, 0))
	var survol := Charte.sans_ombre(C.box(Charte.PANNEAU_2 if not marque else Color("24473a"), Color(Charte.CREME, .3), 6, 0))
	survol.set_border_width_all(1)
	for s in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(s, fond)
	for s in ["hover", "hover_pressed"]: b.add_theme_stylebox_override(s, survol)
	b.pressed.connect(action)
	parent.add_child(b)
	D.place(b, zone)
	return b

## « +2 » vert, « −1 » rouge ; rien si l'écart est nul.
static func ecart_texte(ecart_: int) -> String:
	return "+%d" % ecart_ if ecart_ > 0 else "−%d" % absi(ecart_) if ecart_ < 0 else ""

static func _ecart(parent: Control, x: float, y: float, ecart_: int, taille: int, largeur: float, id: String) -> void:
	if ecart_ == 0: return
	var l := D.text(parent, x, y, ecart_texte(ecart_), taille, Charte.GAIN if ecart_ > 0 else Charte.PERTE, 800, largeur, HORIZONTAL_ALIGNMENT_RIGHT)
	l.name = id

static func _tuile(parent: Control, zone: Rect2, titre: String, chiffre: String, couleur: Color, sous: String, sous_couleur: Color, id: String, action: Callable) -> void:
	var b := _ligne_bouton(parent, zone, id, false, action, titre)
	b.add_theme_stylebox_override("normal", Charte.sans_ombre(C.box(Color(couleur, .12), Color.TRANSPARENT, Charte.RAYON_CARTE, 0)))
	D.text(parent, zone.position.x + 16, zone.position.y + 26, titre, 15, Charte.IVOIRE_2, 700, zone.size.x - 32)
	var n := D.text(parent, zone.position.x + 16, zone.position.y + zone.size.y - 14, chiffre, 38, couleur, 800, 110)
	n.add_theme_font_override("font", Charte.TITRE_FICHE)
	if not sous.is_empty(): D.text(parent, zone.position.x + zone.size.x - 16, zone.position.y + zone.size.y - 18, sous, 21, sous_couleur, 800, 120, HORIZONTAL_ALIGNMENT_RIGHT)

static func _specialisation(card: Control, app: Control, player: Dictionary, zone: Rect2) -> void:
	var record := Academy.professional_progress(app, str(player.get("id", "")))
	var development: Dictionary = record.get("development", {}) if record.get("development") is Dictionary else {}
	var choix := {}
	for option: Variant in development.get("options", []):
		if option is Dictionary: choix[option.get("id")] = option.get("label")
	if choix.is_empty(): return
	var control := Academy._option("ProgressionFocus", "Spécialisation", choix, development.get("focus"), func(value):
		app._command("set_development_focus", {"playerId": record.get("id", player.get("id")), "focus": value}))
	control.disabled = not development.get("available", false)
	card.add_child(control)
	D.place(control, zone)

## Entraînement individuel du moteur (entrainement-cible.cjs) : {poste: {nom, qualites}, role: {nom, cles, utiles},
## designations: [{nom, qualites}]} ; {} sans données.
static func _individuel_donnees(app: Control, player: Dictionary) -> Dictionary:
	var record := Academy.professional_progress(app, str(player.get("id", "")))
	var development: Variant = record.get("development", {})
	var i: Variant = development.get("individuel", {}) if development is Dictionary else {}
	return i if i is Dictionary and i.get("poste") is Dictionary else {}

## Bloc « Entraînement individuel » (24/11/2026) : qualités travaillées au poste, au rôle de jeu (clés puis utiles) et
## aux rôles désignés, en puces à chevron, sans chiffre.
static func _individuel(parent: Control, i: Dictionary, zone: Rect2) -> void:
	var bloc := Control.new()
	bloc.name = "ProgressionIndividuel"
	bloc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bloc)
	D.place(bloc, zone)
	D.text(bloc, 0, 22, "ENTRAÎNEMENT INDIVIDUEL", 17, Charte.IVOIRE_3, 700, zone.size.x)
	var y := 36.0
	var lignes: Array = []
	var poste: Dictionary = i.get("poste", {})
	lignes.append(["POSTE · " + str(poste.get("nom", "")).to_upper(), poste.get("qualites", []), Charte.GAIN, "Poste"])
	var role: Variant = i.get("role")
	if role is Dictionary:
		lignes.append(["RÔLE · " + str(role.get("nom", "")).to_upper(), role.get("cles", []), Charte.GAIN, "RoleCle"])
		lignes.append(["", role.get("utiles", []), Color(Charte.GAIN, .55), "RoleUtile"])
	for d: Variant in i.get("designations", []):
		if d is Dictionary: lignes.append([str(d.get("nom", "")).to_upper(), d.get("qualites", []), Charte.GAIN, "Designe"])
	for ligne: Array in lignes:
		if y > zone.size.y - 34: break
		if not str(ligne[0]).is_empty():
			D.text(bloc, 0, y + 20, str(ligne[0]), 16, Charte.IVOIRE_2, 700, zone.size.x).name = "ProgressionIndividuelTitre" + str(ligne[3])
			y += 28
		var x := 0.0
		for cle: Variant in ligne[1]:
			var w := _largeur_puce(str(cle))
			if x + w > zone.size.x and x > 0:
				x = 0
				y += 40
			if y > zone.size.y - 34: break
			_puce(bloc, x, y, str(cle), ligne[2], "ProgressionIndividuel%s_%s" % [ligne[3], cle])
			x += w + 8
		y += 44

static func _largeur_puce(cle: String) -> float:
	return C.font(700).get_string_size(_libelle(cle), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density + 50

static func _libelle(cle: String) -> String:
	for groupe: Array in PlayerAttributes.GROUPS:
		for pair: Array in groupe[1]:
			if str(pair[0]) == cle: return str(pair[1])
	return cle

## Puce : chevron (tendance, sans chiffre) + nom de la qualité.
static func _puce(parent: Control, x: float, y: float, cle: String, couleur: Color, id: String) -> void:
	var largeur := _largeur_puce(cle)
	var pilule := D.rect(parent, Rect2(x, y, largeur, 34), Color(couleur, .18), Charte.RAYON_PILULE)
	pilule.name = id
	pilule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chevron = load("res://ui/fleches_progression.gd").Fleche.new()
	chevron.cran = 1
	chevron.modulate = Color(1, 1, 1, couleur.a)
	pilule.add_child(chevron)
	D.place(chevron, Rect2(11, 4, 18, 27))
	D.text(pilule, 36, 24, _libelle(cle), 18, Charte.IVOIRE if couleur.a > .9 else Charte.IVOIRE_2, 700, largeur - 40).mouse_filter = Control.MOUSE_FILTER_IGNORE

## Saisons passées (historique du moteur : niveau en début et en fin de saison).
static func _saisons(card: Control, app: Control, player: Dictionary, x: float, y: float, largeur: float) -> void:
	var record := Academy.professional_progress(app, str(player.get("id", "")))
	var development: Dictionary = record.get("development", {}) if record.get("development") is Dictionary else {}
	var history: Array = development.get("history", []) if development.get("history") is Array else []
	D.text(card, x, y, "SAISONS", 15, Charte.IVOIRE_3, 700, 200)
	if history.is_empty():
		D.text(card, x, y + 34, "—", 22, Charte.IVOIRE_3, 700, 60)
		return
	for i in mini(3, history.size()):
		var an: Dictionary = history[history.size() - 1 - i]
		var debut := int(an.get("start", 0))
		var fin := int(an.get("end", 0))
		D.text(card, x, y + 34 + i * 32, G.season_label(an.get("season", "—")), 19, Charte.IVOIRE_2, 600, 140)
		D.text(card, x + 150, y + 34 + i * 32, "%d → %d" % [debut, fin], 19, Charte.IVOIRE, 700, 120)
		_ecart(card, x + largeur, y + 34 + i * 32, fin - debut, 19, 70, "ProgressionSaison%d" % i)

static func _court(libelle: String) -> String:
	return libelle if libelle.length() <= 11 else libelle.substr(0, 10).strip_edges() + "."

static func _cadre_y(courbe: Courbe, vals: Array) -> void:
	var nombres: Array = vals.filter(func(x): return x != null)
	if nombres.is_empty(): return
	var lo: float = nombres.min()
	var hi: float = nombres.max()
	courbe.pas = 5.0 if hi - lo <= 25 else 10.0
	courbe.bas = maxf(0.0, floorf((lo - 3) / courbe.pas) * courbe.pas)
	courbe.haut = minf(100.0, ceilf((hi + 3) / courbe.pas) * courbe.pas)

# --- Onglet ----------------------------------------------------------------------------------------------------------

## Courbe 12 mois en haut (qualités cochées ou niveau), grille des 36 qualités à cocher en dessous.
static func construire(page: Control, app: Control, player: Dictionary, top: float) -> void:
	var liste := qualites(app, player)
	var e := etat(app, player, liste)
	var courant := mois_courant(app, releve(player))
	var haut := D.panel(page, Rect2(0, top, 2248, 480), "", "", "", "ProgressionCourbeCarte")
	var titre := D.text(haut, 24, 46, "PROGRESSION · 12 MOIS", 26, Charte.IVOIRE, 700, 520)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	_pilule(haut, Rect2(560, 16, 150, 40), "Qualités", e.vue == "qualites", "ProgressionVue_qualites", func(): _vue(app, e, "qualites"))
	_pilule(haut, Rect2(720, 16, 150, 40), "Niveau", e.vue == "niveau", "ProgressionVue_niveau", func(): _vue(app, e, "niveau"))
	var niv := niveau(app, player)
	var gain := ecart(niv)
	_tuile(haut, Rect2(1290, 10, 220, 74), "NIVEAU", G.n(roundi(float(niv[12]))), Charte.IVOIRE, ecart_texte(gain), Charte.GAIN if gain >= 0 else Charte.PERTE, "ProgressionTuileNiveau", func(): _vue(app, e, "niveau"))
	_tuile(haut, Rect2(1522, 10, 220, 74), "POTENTIEL", G.potential_text(player), Charte.CONFIANCE, "", Charte.IVOIRE, "ProgressionTuilePotentiel", func(): _vue(app, e, "niveau"))
	_specialisation(haut, app, player, Rect2(1760, 24, 466, 46))
	var courbe := Courbe.new()
	courbe.name = "ProgressionCourbe"
	courbe.etiquettes = etiquettes(courant)
	courbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.vue == "niveau":
		courbe.series.append({"valeurs": niv, "couleur": Charte.IVOIRE, "court": "Niveau"})
		_cadre_y(courbe, niv)
		haut.add_child(courbe)
		D.place(courbe, Rect2(24, 96, 1700, 370))
		_saisons(haut, app, player, 1780, 140, 440)
	else:
		var vals: Array = []
		for q: Dictionary in liste:
			if q.cle in e.coches:
				courbe.series.append({"valeurs": q.serie, "couleur": teinte(e, q.cle), "court": _court(str(q.libelle))})
				vals.append_array(q.serie)
		_cadre_y(courbe, vals)
		haut.add_child(courbe)
		var individuel := _individuel_donnees(app, player)
		D.place(courbe, Rect2(24, 96, 1590 if not individuel.is_empty() else 2200, 370))
		if not individuel.is_empty(): _individuel(haut, individuel, Rect2(1650, 96, 574, 372))
	# Grille des 36 qualités à cocher.
	var bas_y := top + 496
	var grille := D.panel(page, Rect2(0, bas_y, 2248, 1246 - bas_y), "", "", "", "ProgressionGrille")
	var colonne := (2248.0 - 48 - 3 * 28) / 4.0
	for f in PlayerAttributes.GROUPS.size():
		var x := 24 + f * (colonne + 28)
		D.rect(grille, Rect2(x, 18, 6, 26), FAMILLES[f], 3)
		D.text(grille, x + 16, 40, str(PlayerAttributes.GROUPS[f][0]).to_upper(), 18, Charte.IVOIRE, 700, colonne - 100)
		D.text(grille, x + colonne - 70, 40, "12 MOIS", 14, Charte.IVOIRE_3, 700, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		var j := 0
		for q: Dictionary in liste:
			if int(q.famille) != f: continue
			var y := 50 + j * 38.0
			var coche: bool = q.cle in e.coches
			var c := teinte(e, q.cle)
			var cle := str(q.cle)
			_ligne_bouton(grille, Rect2(x - 6, y, colonne + 12, 36), "ProgressionCoche_" + cle, coche, func(): _basculer(app, e, cle), "%s · %s" % [q.libelle, "retirer de la courbe" if coche else "voir sur la courbe"])
			# Case : rond plein à la couleur de la courbe quand coché, anneau vide sinon.
			if coche: D.rect(grille, Rect2(x + 4, y + 8, 20, 20), c, 10)
			else: D.rect(grille, Rect2(x + 4, y + 8, 20, 20), Color.TRANSPARENT, 10, Color(Charte.CREME, .45))
			D.text(grille, x + 36, y + 25, q.libelle, 20, Charte.IVOIRE if coche else Charte.IVOIRE_2, 600 if coche else 500, colonne - 160, HORIZONTAL_ALIGNMENT_LEFT, true)
			_ecart(grille, x + colonne - 56, y + 25, int(q.ecart), 18, 70, "ProgressionEcart_" + cle)
			D.text(grille, x + colonne, y + 26, G.n(roundi(float(q.valeur))), 23, Charte.couleur_attribut(q.valeur), 700, 46, HORIZONTAL_ALIGNMENT_RIGHT).name = "ProgressionNote_" + cle
			j += 1
