extends Control
## Écran Effectif, socle (découpe de squad_canvas.gd, sans changement) : constantes, état partagé, outils de dessin, lecture des joueurs (statiques).
## Chaîne d'héritage : socle ← puces et filtres ← titre, tuiles et onglets ← lignes ← tableau ← squad_canvas.gd (fichier public).
const Notation = preload("res://ui/notation_staff.gd")
const Fleches = preload("res://ui/fleches_progression.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const P = preload("res://ui/immersive08/projection.gd")
const G = preload("res://ui/game_skin.gd")
const U = preload("res://ui/management_state.gd")
const Charte = preload("res://ui/charte.gd")
const Identity = preload("res://ui/player_identity.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Notes = preload("res://ui/notes_match.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Courbe = preload("res://ui/mini_courbe_survol.gd")
const Etoiles = preload("res://ui/immersive08/liste_etoiles.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")
const ROW_HEIGHT := 34
const GROUP_HEIGHT := 30
const FIRST_ROWS := 26
const ROWS_PER_FRAME := 18
const VISIBLE_MARGIN := 6
const LARGEUR := 2248.0
const HAUT_PAGE := 1244.0
const Y_ONGLETS := 130.0
const Y_FILTRES := 196.0
const Y_ENTETE := 254.0
const Y_LIGNES := 292.0
const Y_PIED := 1206.0
## Postes de l'équilibre du groupe : libellé et numéros de poste principal.
const POSTES := [["Pilier gauche",[1]],["Talonneur",[2]],["Pilier droit",[3]],["Deuxième ligne",[4,5]],["3e ligne aile",[6,7]],["Numéro 8",[8]],["Demi de mêlée",[9]],["Ouvreur",[10]],["Ailier",[11,14]],["Centre",[12,13]],["Arrière",[15]]]
const VUES := ["Vue d’ensemble","Condition","Contrats","Développement","Planificateur"]
const TRIS := ["Numéro","Poste","Autres postes","Nom","Niveau","Potentiel","Condition","Fatigue","Minutes","Moyenne","Forme","Statut","Âge","Salaire","Échéance","Motif"]
var app: Control
var state: Dictionary
var rows: VBoxContainer
var count: Label
var compare: Button
var sort_headers: Dictionary = {}
var _generation := 0
var _group := ""
var _puces: Dictionary = {}
var _marques_tuiles: Dictionary = {}
var _colonnes_actives: Array = []
## Vrai pendant que le focus mémorisé est rendu : il ne doit pas déplacer la sélection choisie ailleurs (palette, retour de fiche).
var _restaurant := false
## Panneaux latéraux à gauche (panneaux_effectif.gd) : décalage et largeur du tableau.
var _x0 := 0.0
var _lt := LARGEUR
## Rangées au-dessus du tableau (choix de Léo du 21/11/2026) : tuiles des totaux de la liste filtrée, puis pastilles de poste.
const Y_TOTAUX := Y_FILTRES + 52.0
const Y_POSTES := Y_FILTRES + 122.0
const DY_RANGEES := 118.0
var _dy := 0.0
var _bandeau_totaux: Control
## Poste (1-15) dont la liste montre la note au poste et la familiarité, choisi d'un clic sur un maillot du terrain XV ; 0 = aucun.
var _poste := 0

func _etroit() -> bool:
	return C.density < .7

## Rafraîchit le tableau : défini dans squad_tableau.gd ; déclaré ici pour que les puces, les menus et la recherche l'appellent.
func _refresh(_reveal: bool) -> void:
	pass

# ---------------------------------------------------------------- outils de dessin

## Fond plat de la charte (rayon en référence 2560) : 6 par défaut (case, ligne), 16 pour une tuile (12 px), pilule pour
## onglet, puce et champ.
## Champ de la charte : pilule, contour fin, jamais d'ombre.
static func _champ(fond: Color, bord: Color) -> StyleBoxFlat:
	var style := _plat(fond, bord, 1, Charte.RAYON_PILULE)
	style.content_margin_left = C.px(18)
	style.content_margin_right = C.px(18)
	return style

static func _plat(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, rayon: int = Charte.RAYON_PETIT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = bord
	style.set_border_width_all(epaisseur)
	style.set_corner_radius_all(rayon if rayon >= Charte.RAYON_PILULE else maxi(3, C.px(rayon)))
	style.anti_aliasing = true
	return Charte.ombrer(style, rayon)

static func _italique(label: Label, gras := true) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE if gras else Charte.TITRE_GRAS_ITALIQUE)
	return label

## Largeur d'un texte en unités du gabarit, mesurée avec la police et la taille réellement affichées.
static func _largeur(texte: String, taille: float, corps := true, graisse := 600) -> float:
	var police: Font = C.BODY if corps else C.font(graisse)
	return police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Parallélogramme incliné de 10° (marqueur de sélection et d'état actif).
static func _marqueur(parent: Control, zone: Rect2, couleur: Color = Charte.IVOIRE) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = couleur
	var h := zone.size.y * C.density
	var d := Charte.decalage(h)
	var l := zone.size.x * C.density
	poly.polygon = PackedVector2Array([Vector2(d, 0), Vector2(d + l, 0), Vector2(l, h), Vector2(0, h)])
	poly.position = zone.position * C.density
	parent.add_child(poly)
	return poly

func _lien(parent: Control, zone: Rect2, texte: String, action: Callable, id: String, couleur: Color = Charte.IVOIRE, taille := 19.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, lien_commun := false) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = texte
	bouton.flat = false
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.alignment = aligne
	bouton.clip_text = true
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(taille)))
	for nom: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(nom, couleur)
	var marge := C.px(10)
	for etat: String in ["normal", "pressed"]:
		var style := _plat(Color.TRANSPARENT); style.content_margin_left = marge; style.content_margin_right = marge
		bouton.add_theme_stylebox_override(etat, style)
	var survol := _plat(Charte.PANNEAU_2); survol.content_margin_left = marge; survol.content_margin_right = marge
	bouton.add_theme_stylebox_override("hover", survol)
	var focus := _plat(Color.TRANSPARENT, Charte.IVOIRE, 1); focus.content_margin_left = marge; focus.content_margin_right = marge
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.pressed.connect(action)
	if lien_commun:
		C.style_bouton_lien(bouton, int(taille))
		bouton.alignment = aligne
	parent.add_child(bouton)
	D.place(bouton, C.reach_rect(zone))
	return bouton

## Le filtre de la tuile est celui qui est actif (marqueur ivoire incliné).
func _tuile_active(action: String) -> bool:
	match action:
		"aptes": return str(state.family) == "Aptes" and str(state.contract) == "Tous"
		"indisponibles": return str(state.family) == "Indisponibles" and str(state.contract) == "Tous"
		"fin": return str(state.contract) == "Fin de saison"
		"niveau": return str(state.sort) == "Niveau" and bool(state.descending) and int(state.get("immersive_tab", 0)) == 0
	return false

static func _known_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func primary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("primaryPositions",[player.get("primaryPosition")])
	if not source is Array: return result
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value)==float(number) and number>=1 and number<=15 and not number in result: result.append(number)
	result.sort()
	return result

static func primary_caption(player: Dictionary) -> String:
	var numbers := primary_numbers(player)
	if numbers==[1,3]: return "Pilier G/D"
	if numbers==[6,7]: return "Troisième ligne aile"
	if numbers==[8]: return "Troisième ligne centre"
	return str(player.get("pos","—"))

## Libellé de poste qui tient dans la largeur réelle du label (police et taille mesurées) ; sinon sa forme courte.
static func fitted_position(caption: String, label: Label) -> String:
	var font: Font = label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	if font == null or font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x: return caption
	var short := str(preload("res://ui/squad_views.gd").position_label(caption, true))
	return short if not short.is_empty() else caption

static func secondary_numbers(player: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var source: Variant = player.get("secondaryPositions")
	if not source is Array: return result
	var primary := primary_numbers(player)
	for value: Variant in source:
		if not _known_number(value): continue
		var number := int(value)
		if float(value) != float(number) or number < 1 or number > 15 or number in result or number in primary: continue
		result.append(number)
	result.sort()
	return result

static func secondary_caption(player: Dictionary) -> String:
	var roles := secondary_roles(player)
	return "·".join(roles) if not roles.is_empty() else "—"

static func secondary_roles(player: Dictionary) -> Array[String]:
	var labels := {1:"PG",2:"T",3:"PD",4:"2E L",5:"2E L",6:"3E L",7:"3E L",8:"8",9:"DM",10:"DO",11:"AL",12:"C",13:"C",14:"AL",15:"AR"}
	var found: Array[String] = []
	for number: int in secondary_numbers(player):
		var role: String = labels[number]
		if not role in found: found.append(role)
	var result: Array[String] = []
	for role: String in ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]:
		if role in found: result.append(role)
	return result

static func secondary_tooltip(player: Dictionary, _model: Dictionary) -> String:
	var result: Array[String] = []
	var names := {"PG":"Pilier gauche", "PD":"Pilier droit", "T":"Talonneur", "2E L":"Deuxième ligne (4–5)", "3E L":"Troisième ligne aile (6–7)", "8":"Troisième ligne centre", "DM":"Demi de mêlée", "DO":"Demi d’ouverture", "C":"Centre (12–13)", "AL":"Ailier (11 et 14)", "AR":"Arrière"}
	for role: String in secondary_roles(player): result.append(role+" · "+str(names[role]))
	return "\n".join(result) if not result.is_empty() else "—"

static func _compare_secondary(left: Array, right: Array) -> int:
	for index in mini(left.size(),right.size()):
		if int(left[index]) != int(right[index]): return -1 if int(left[index]) < int(right[index]) else 1
	if left.size() == right.size(): return 0
	return -1 if left.size() < right.size() else 1

static func sort_value(player: Dictionary, key: String) -> Variant:
	if key == "Note au poste":
		# Lettre MONTRÉE au poste choisi, puis familiarité (à égalité : identifiant, jamais le chiffre caché) ; inconnues en dernier.
		var e := float(player.get("notePoste", -1.0))
		if e < 0.0: return null
		return e * 100.0 + float(player.get("familiarite", 0))
	if key in ["Niveau","Potentiel"]: return Notation.tri_champ(player,"rating" if key == "Niveau" else "potential",true)
	if key == "Autres postes":
		var order: Array[int] = []
		var roles: Array = ["PG","PD","T","2E L","3E L","8","DM","DO","C","AL","AR"]
		for role: String in secondary_roles(player): order.append(roles.find(role))
		return order if not order.is_empty() else null
	if key == "Statut":
		if _known_number(player.get("injury")) and float(player.injury) > 0: return U.fold("Blessé")
		var status: Variant = player.get("status")
		return U.fold(status.strip_edges()) if status is String and not status.strip_edges().is_empty() and status != "—" else null
	if key in ["Moyenne","Forme"]:
		var notes: Variant = player.get("matchNotes")
		if notes is Dictionary:
			if key == "Moyenne": return notes.get("moyenne")
			var forme: Array = notes.get("forme", [])
			if forme.is_empty(): return null
			var somme := 0.0
			for v: Variant in forme: somme += float(v)
			return somme / forme.size()
		return null
	if key == "Motif":
		var source := player.duplicate()
		if not _known_number(source.get("condition")): source.condition = 100
		if not _known_number(source.get("physicalLoad")): source.physicalLoad = 0
		var reason := U.watch_reason(source)
		return U.fold(reason) if not reason.is_empty() else null
	var field: String = {"Numéro":"shirtNumber","Poste":"pos","Nom":"name","Niveau":"rating","Potentiel":"potential","Condition":"condition","Âge":"age","Salaire":"salary","Échéance":"contractEnd","Fatigue":"physicalLoad","Minutes":"minutes"}.get(key,"pos")
	var value: Variant = primary_caption(player) if key == "Poste" else player.get(field)
	if key in ["Nom","Poste"]:
		if not value is String or value.strip_edges().is_empty() or value.strip_edges() in ["—","-"]: return null
		var text := U.fold(value.strip_edges())
		# Le tri de poste conserve les familles rugby du tableau, puis le poste.
		if key == "Poste" and _known_number(player.get("fam")): return "%03d/" % int(player.fam) + text
		return text
	return value if _known_number(value) else null

static func ordered_players(source: Array, reading: Dictionary, season: int) -> Array:
	# Réutiliser les filtres sans subir un premier tri numérique sur un inconnu.
	var filtering := reading.duplicate()
	filtering.sort = "Nom"
	filtering.descending = false
	var result := U.players(source,filtering,season)
	var key := str(reading.get("sort","Poste"))
	var descending: bool = reading.get("descending",false)
	result.sort_custom(func(a: Dictionary,b: Dictionary):
		var left: Variant = sort_value(a,key)
		var right: Variant = sort_value(b,key)
		if left == null and right == null: return str(a.get("id","")) < str(b.get("id",""))
		if left == null: return false
		if right == null: return true
		if key == "Autres postes":
			var comparison := _compare_secondary(left,right)
			if comparison == 0: return str(a.get("id","")) < str(b.get("id",""))
			return comparison > 0 if descending else comparison < 0
		if left == right: return str(a.get("id","")) < str(b.get("id",""))
		return left > right if descending else left < right)
	return result
