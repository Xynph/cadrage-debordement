extends Node
## Planche A/B « Ajustements et cris du banc » (revue FM27, idée 34), sous CD_VARIANTE_VISUELLE=A|B, dans le tableau de
## bord du direct (match_between.gd). Un clic choisit et applique : aucun bouton Confirmer.
## - Ajustements : raccourcis vers les consignes en direct du moteur (dist/match-pilotage.js, commande `set_consignes`) ;
##   un ajustement allumé se rééteint d'un clic (retour au cran neutre).
## - Cris : les cinq cris de la touche du moteur (commande `cri`), leur usure (3 points) et le cri en cours.
## - Cris à un joueur : PAS dans le moteur (planche seulement : le clic marque la ligne, sans effet de jeu).
## A : deux menus rapides dans la barre (CRIS ▾, AJUSTEMENTS ▾), listes à lignes avec icône et effets.
## B : barre du banc toujours visible au-dessus du tableau de bord : un rond par cri et par ajustement.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const S = preload("res://ui/contextual/skin.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const NOM := "MatchFmBanc"

## Icônes propres à la planche (tracés 24×24, trait).
const TRACES := {
	"pied": "M7 3v9l-3 5a2 2 0 0 0 2 3h9l4-3v-3l-6-2V3z M15 10.5l4 1.5",
	"main": "M8 12V5a1.5 1.5 0 0 1 3 0v6 M11 11V4a1.5 1.5 0 0 1 3 0v7 M14 11V5.5a1.5 1.5 0 0 1 3 0V14c0 4-3 7-7 7-3 0-5-2-6-4l-2-4a1.5 1.5 0 0 1 2.5-1.5L8 14",
	"vite": "M3 6l8 6-8 6z M12 6l8 6-8 6z",
	"souffle": "M3 8h10a3 3 0 1 0-3-3 M3 12h15a3 3 0 1 1-3 3 M3 16h7",
	"relance": "M4 17l6-6 4 4 6-8 M15 7h5v5",
	"ruck": "M5 20l4-8 3 3 3-3 4 8 M12 4a2 2 0 1 1 0 4 2 2 0 0 1 0-4z",
	"sifflet": "M3 13a5 5 0 1 0 10 0 5 5 0 0 0-10 0z M8 8h12v4h-7",
	"melee": "M4 12h6 M14 12h6 M10 8v8 M14 8v8 M2 9l2 3-2 3 M22 9l-2 3 2 3",
	"porte": "M6 20v-6l3-3 3 3 3-3 3 3v6 M9 11V6 M15 11V6 M12 14V4",
	"cible": "M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18z M12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8z M12 12h9",
	"montre": "M12 5a8 8 0 1 1 0 16 8 8 0 0 1 0-16z M12 9v4l3 2 M10 2h4",
	"tout": "M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-3 2-4 2-6 1 1 2 2 3 2 0-2-1-4 0-6z",
	"pouce": "M7 11v9H4v-9z M7 11l4-7c1.5 0 2.5 1 2 3l-1 3h6a2 2 0 0 1 2 2l-2 7a2 2 0 0 1-2 1H7",
	"haut": "M6 14l6-6 6 6 M6 20l6-6 6 6",
	"calme": "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9",
	"bouclier": "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z M9 12l2 2 4-4",
	"reveil": "M12 6a7 7 0 1 1 0 14 7 7 0 0 1 0-14z M12 10v3h3 M4 4l3 3 M20 4l-3 3",
	"cri": "M3 10v4h3l7 4V6L6 10H3z M16 9a4 4 0 0 1 0 6 M18.5 6.5a8 8 0 0 1 0 11",
}

## Ajustements : [id, libellé, icône, axe, valeur, famille, effets [[texte, sens]]].
const AJUSTEMENTS := [
	["pied", "Jouer au pied", "pied", "piedJeu", "plus", "attaque", [["occupation", 1], ["possession", -1]]],
	["garder", "Garder le ballon", "main", "piedJeu", "moins", "attaque", [["possession", 1], ["camp", -1]]],
	["accelerer", "Accélérer", "vite", "rythme", "rapide", "attaque", [["rythme", 1], ["énergie", -1]]],
	["souffler", "Souffler un peu", "souffle", "rythme", "lent", "attaque", [["énergie", 1], ["rythme", -1]]],
	["relancer", "Relancer de loin", "relance", "relance", "relancer", "attaque", [["mètres", 1], ["pertes", -1]]],
	["contester", "Contester les rucks", "ruck", "rucks", "agressive", "defense", [["ballons volés", 1], ["pénalités", -1]]],
	["zero", "Zéro faute", "sifflet", "discipline", "stricte", "defense", [["discipline", 1], ["plaquages", -1]]],
	["pousser", "Pousser en mêlée", "melee", "melee", "pousser", "conquete", [["pénalités obtenues", 1], ["sifflets", -1]]],
	["porte", "Ballon porté", "porte", "maul", "souvent", "conquete", [["essais de près", 1]]],
	["aile", "Viser l'aile faible", "cible", "cible", "aile", "conquete", [["franchissements", 1]]],
	["montre", "Jouer la montre", "montre", "finDeMatch", "montre", "fin", [["temps", 1], ["points", -1]]],
	["tout_tenter", "Tout tenter", "tout", "finDeMatch", "tout", "fin", [["points", 1], ["contres", -1]]],
]
const FAMILLES := {"attaque": Charte.INTENSIF, "defense": Charte.PERTE, "conquete": Charte.MORAL, "fin": Charte.CONFIANCE}
## Cris du moteur : id → [icône, couleur, effets, durée].
const CRIS := {
	"encourager": ["pouce", Charte.CONDITION, [["tous +1", 1], ["apaise", 1]], 8],
	"exiger": ["haut", Charte.INTENSIF, [["tous +2", 1], ["discipline −3", -1]], 8],
	"calmer": ["calme", Charte.MORAL, [["discipline +6", 1], ["apaise", 1]], 10],
	"defense": ["bouclier", Charte.REPOS, [["plaquage +4", 1], ["passe −2", -1]], 10],
	"toutDonner": ["tout", Charte.PERTE, [["tous +3", 1], ["fatigue ×1,15", -1]], 10],
}
## Cris à un joueur (pas dans le moteur) : [id, libellé, icône, couleur].
const CRIS_JOUEUR := [["bravo", "Bien joué", "pouce", Charte.CONDITION], ["niveau", "Hausse le niveau", "haut", Charte.INTENSIF], ["reveil", "Réveille-toi", "reveil", Charte.PERTE]]

var between: Control
var variante := ""
var barre_b: PanelContainer
var _menu: Control
var _onglet_cris := "equipe"
var _cle := ""

static func variante_active() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

## Pose la planche sur l'écran : boutons dans la barre (A) ou barre du banc en tête de page (B).
static func poser(hote: Control, barre: Control, page: Control) -> Node:
	var v := variante_active()
	if v.is_empty(): return null
	var banc := new()
	banc.name = NOM
	banc.between = hote
	banc.variante = v
	hote.add_child(banc)
	if v == "A": banc._boutons_a(barre)
	else: banc._barre_b(page)
	# L'écran se reconstruit (taille, échelle) : le menu ouvert et l'onglet des cris reviennent.
	banc._onglet_cris = str(hote.get_meta("fm_onglet", "equipe"))
	if not str(hote.get_meta("fm_menu", "")).is_empty(): banc.call_deferred("ouvrir_menu", str(hote.get_meta("fm_menu")))
	return banc

# ------------------------------------------------------------------ état (moteur + envois en attente)

func _pilotage() -> Dictionary:
	var p: Variant = between.get("_pilotage")
	return p if p is Dictionary else {}

func _envois() -> Dictionary:
	if not between.has_meta("fm_envois"): between.set_meta("fm_envois", {})
	return between.get_meta("fm_envois")

func _cran(axe: String) -> String:
	var envois := _envois()
	if envois.has(axe): return str(envois[axe])
	var consignes: Variant = _pilotage().get("consignes")
	return str((consignes as Dictionary).get(axe, "")) if consignes is Dictionary else ""

func _neutre(axe: String) -> String:
	for a: Variant in _pilotage().get("axes", []) if _pilotage().get("axes") is Array else []:
		if a is Dictionary and str(a.get("id", "")) == axe:
			var options: Array = a.get("options", []) if a.get("options") is Array else []
			if options.size() >= 3: return str(options[1].get("id", ""))
	return {"piedJeu": "normal", "rythme": "normal", "relance": "selon", "rucks": "normale", "discipline": "normale", "melee": "normale",
		"maul": "selon", "cible": "aucune", "finDeMatch": "normal"}.get(axe, "")

func ajustement_actif(aj: Array) -> bool:
	return _cran(str(aj[3])) == str(aj[4])

func _cris() -> Dictionary:
	var c: Variant = _pilotage().get("cris")
	return c if c is Dictionary else {}

func _cri_option(id: String) -> Dictionary:
	for o: Variant in _cris().get("options", []) if _cris().get("options") is Array else []:
		if o is Dictionary and str(o.get("id", "")) == id: return o
	return {}

func _cri_actif() -> Dictionary:
	var envoye: Variant = between.get_meta("fm_cri", {})
	var a: Variant = _cris().get("actif")
	if a is Dictionary: return a
	return envoye if envoye is Dictionary else {}

func _minute() -> int:
	var d: Variant = between.get("_dernier")
	if d is Array and (d as Array).size() > 1 and d[1] is Dictionary: return int(d[1].get("minute", 0))
	return 0

## Clic sur un ajustement : allume (cran voulu) ou éteint (cran neutre) ; la commande part tout de suite.
func basculer(aj: Array) -> void:
	var axe := str(aj[3])
	var valeur := _neutre(axe) if ajustement_actif(aj) else str(aj[4])
	_envois()[axe] = valeur
	var app: Object = between._app()
	if app != null: app._command("set_consignes", {"axe": axe, "valeur": valeur})
	rafraichir(true)

func reinitialiser() -> void:
	var app: Object = between._app()
	for aj: Array in AJUSTEMENTS:
		if not ajustement_actif(aj): continue
		var axe := str(aj[3])
		_envois()[axe] = _neutre(axe)
		if app != null: app._command("set_consignes", {"axe": axe, "valeur": _neutre(axe)})
	rafraichir(true)

func crier(id: String) -> void:
	var o := _cri_option(id)
	if not o.is_empty() and not bool(o.get("disponible", true)): return
	var app: Object = between._app()
	if app != null: app._command("cri", {"id": id})
	between.set_meta("fm_cri", {"id": id, "jusqua": _minute() + int(CRIS.get(id, ["", null, [], 8])[3])})
	rafraichir(true)

func crier_joueur(id_joueur: String, cri: String) -> void:
	var faits: Dictionary = between.get_meta("fm_cris_joueurs", {})
	faits[id_joueur] = [cri, _minute()]
	between.set_meta("fm_cris_joueurs", faits)
	rafraichir(true)

## Appelé à chaque image du modèle : remet à jour les états allumés (B) ou le menu ouvert (A).
func rafraichir(force: bool = false) -> void:
	var envois := _envois()
	var consignes: Variant = _pilotage().get("consignes")
	if consignes is Dictionary:
		for axe: Variant in envois.keys():
			if str((consignes as Dictionary).get(str(axe), "")) == str(envois[axe]): envois.erase(axe)
	var cle := JSON.stringify([_pilotage().get("consignes"), _cris(), envois, between.get_meta("fm_cri", {}), between.get_meta("fm_cris_joueurs", {}), _onglet_cris])
	if cle == _cle and not force: return
	_cle = cle
	if variante == "B" and is_instance_valid(barre_b): _remplir_b()
	if is_instance_valid(_menu) and _menu.has_meta("sorte"): _remplir_menu(str(_menu.get_meta("sorte")))

# ------------------------------------------------------------------ dessin commun

func px(v: float) -> int: return between.px(v)

static func icone_texture(id: String, couleur: Color) -> Texture2D:
	if not TRACES.has(id): return C.icon_texture(id, couleur)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#%s" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [TRACES[id], couleur.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK: return null
	return ImageTexture.create_from_image(image)

func _icone(id: String, couleur: Color, cote: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icone_texture(id, couleur)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px(cote), px(cote))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

## Rond coloré portant une icône (allumé : aplat de la couleur, icône sombre ; éteint : voile de la couleur).
func _rond(id: String, couleur: Color, cote: float, allume: bool) -> PanelContainer:
	var rond := PanelContainer.new()
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = couleur if allume else Color(couleur, 0.16)
	st.set_corner_radius_all(Charte.RAYON_PILULE)
	st.anti_aliasing = true
	var m := px(cote * 0.2)
	st.content_margin_left = m
	st.content_margin_right = m
	st.content_margin_top = m
	st.content_margin_bottom = m
	rond.add_theme_stylebox_override("panel", st)
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rond.add_child(_icone(id, Charte.ENCRE if allume else couleur, cote * 0.6))
	return rond

func _texte(t: String, taille: float, couleur: Color, titre: bool = false) -> Label:
	var l: Label = between._texte(t, taille, couleur, false, titre)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _puce_effet(t: String, sens: int) -> PanelContainer:
	var couleur: Color = Charte.GAIN if sens > 0 else Charte.PERTE if sens < 0 else Charte.IVOIRE_2
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := Charte.style_pilule(Color(couleur, 0.15), Color.TRANSPARENT, px(10), px(2))
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var signe := "▲ " if sens > 0 else "▼ " if sens < 0 else ""
	p.add_child(_texte(signe + t, 15, couleur))
	return p

## Ligne cliquable d'une liste (grammaire de l'Effectif : survol qui se démarque, ligne choisie en vert franc).
func _ligne(nom: String, action: Callable, choisie: bool, actif: bool = true) -> Button:
	var b := Button.new()
	b.name = nom
	b.focus_mode = Control.FOCUS_ALL
	b.flat = false
	b.disabled = not actif
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Charte.SELECTION if choisie else (Charte.PANNEAU_3 if etat in ["hover", "pressed", "hover_pressed"] else Color(0, 0, 0, 0))
		if etat == "focus":
			st.bg_color = Color(0, 0, 0, 0)
			st.border_color = Charte.OR
			st.set_border_width_all(2)
		st.set_corner_radius_all(Charte.RAYON_PETIT)
		b.add_theme_stylebox_override(etat, st)
	b.custom_minimum_size.y = px(58)
	b.pressed.connect(action)
	return b

func _contenu_ligne(b: Button) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(14))
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = px(12)
	h.offset_right = -px(12)
	b.add_child(h)
	return h

func _vide() -> Control:
	var v := Control.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

# ------------------------------------------------------------------ A : menus rapides dans la barre

func _boutons_a(barre: Control) -> void:
	var cris: Button = between._lien("Cris ▾", func(): ouvrir_menu("cris"), "FmBancCris")
	cris.icon = icone_texture("cri", Charte.IVOIRE)
	cris.add_theme_constant_override("icon_max_width", px(30))
	var aj: Button = between._lien("Ajustements ▾", func(): ouvrir_menu("ajustements"), "FmBancAjustements")
	aj.icon = icone_texture("tactic", Charte.IVOIRE)
	aj.add_theme_constant_override("icon_max_width", px(30))
	for b: Button in [cris, aj]: b.add_theme_font_size_override("font_size", between.fpx(22 * 1.28))
	barre.add_child(cris)
	barre.add_child(aj)
	# Juste après ÉQUIPE et sa touche.
	var equipe: Variant = between.get("equipe")
	if equipe is Control and (equipe as Control).get_parent() == barre:
		var i := (equipe as Control).get_index() + 2
		barre.move_child(cris, mini(i, barre.get_child_count() - 1))
		barre.move_child(aj, mini(i + 1, barre.get_child_count() - 1))

func fermer_menu() -> void:
	between.set_meta("fm_menu", "")
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null

## Menu déroulant sous son bouton : un calque qui ferme au clic à côté, la liste en panneau de la charte.
func ouvrir_menu(sorte: String) -> void:
	var meme := is_instance_valid(_menu) and str(_menu.get_meta("sorte", "")) == sorte
	fermer_menu()
	if meme: return
	var calque := Control.new()
	calque.name = "FmBancMenu"
	calque.set_meta("sorte", sorte)
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	calque.z_index = 60
	calque.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		if clic != null and clic.pressed: fermer_menu())
	between.add_child(calque)
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu = calque
	between.set_meta("fm_menu", sorte)
	PetiteFenetre.enregistrer(calque, fermer_menu)
	_remplir_menu(sorte)

func _remplir_menu(sorte: String) -> void:
	for e in _menu.get_children():
		_menu.remove_child(e)
		e.queue_free()
	var panneau := PanelContainer.new()
	panneau.name = "FmBancMenuPanneau"
	var st := Charte.style_panneau(Charte.PANNEAU, 12, px(16))
	st.border_color = Color(1, 1, 1, 0.22)
	st.set_border_width_all(1)
	panneau.add_theme_stylebox_override("panel", st)
	panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(panneau)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", px(4))
	panneau.add_child(col)
	var bouton := between.find_child("FmBancCris" if sorte == "cris" else "FmBancAjustements", true, false) as Control
	if sorte == "ajustements": _menu_ajustements(col)
	elif sorte == "joueur": _liste_joueurs(col, true)
	else: _menu_cris(col)
	var largeur := px(760 if sorte == "ajustements" else 720)
	panneau.custom_minimum_size.x = largeur
	panneau.reset_size()
	var pos := Vector2(px(40), px(140))
	if bouton != null and bouton.is_visible_in_tree():
		pos = bouton.get_global_rect().position + Vector2(0, bouton.get_global_rect().size.y + px(8))
	if sorte == "joueur" and is_instance_valid(barre_b):
		var r := barre_b.get_global_rect()
		pos = Vector2(r.end.x - largeur, r.end.y + px(8))
	pos.x = clampf(pos.x, px(16), between.get_viewport_rect().size.x - largeur - px(16))
	panneau.position = pos - between.get_global_rect().position

func _menu_ajustements(col: VBoxContainer) -> void:
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", px(12))
	col.add_child(tete)
	tete.add_child(_texte("AJUSTEMENTS", 26, Charte.IVOIRE, true))
	var allumes := AJUSTEMENTS.filter(func(a: Array): return ajustement_actif(a)).size()
	if allumes > 0: tete.add_child(_puce_effet("%d en place" % allumes, 0))
	tete.add_child(_vide())
	var reset: Button = between._lien("Réinitialiser", reinitialiser, "FmBancReinitialiser")
	reset.icon = C.icon_texture("renew", Charte.IVOIRE)
	reset.add_theme_constant_override("icon_max_width", px(22))
	reset.disabled = allumes == 0
	tete.add_child(reset)
	var famille := ""
	for aj: Array in AJUSTEMENTS:
		if str(aj[5]) != famille:
			famille = str(aj[5])
			var titre := _texte({"attaque": "ATTAQUE", "defense": "DÉFENSE", "conquete": "CONQUÊTE", "fin": "FIN DE MATCH"}[famille], 15, FAMILLES[famille], true)
			titre.custom_minimum_size.y = px(26)
			col.add_child(titre)
		var actif := ajustement_actif(aj)
		var b := _ligne("FmAjust_" + str(aj[0]), func(): basculer(aj), actif)
		b.custom_minimum_size.y = px(50)
		b.tooltip_text = str(aj[1])
		var h := _contenu_ligne(b)
		var couleur: Color = FAMILLES[str(aj[5])]
		h.add_child(_rond(str(aj[2]), couleur, 40, actif))
		var l := _texte(str(aj[1]), 21, Charte.IVOIRE if actif else Charte.IVOIRE_2)
		l.custom_minimum_size.x = px(240)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		for e: Array in aj[6]: h.add_child(_puce_effet(str(e[0]), int(e[1])))
		h.add_child(_vide())
		if actif:
			var coche := _icone("check", Charte.GAIN, 24)
			h.add_child(coche)
		col.add_child(b)

func _onglets(col: VBoxContainer) -> void:
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", px(18))
	col.add_child(tete)
	for o: Array in [["equipe", "Équipe"], ["joueur", "Individuel"]]:
		var choisi := _onglet_cris == str(o[0])
		var b := Button.new()
		b.name = "FmBancOnglet_" + str(o[0])
		b.text = str(o[1])
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", Charte.TITRE_GRAS)
		b.add_theme_font_size_override("font_size", between.fpx(26))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Charte.IVOIRE if choisi else Charte.IVOIRE_3)
		var cle := str(o[0])
		b.pressed.connect(func():
			_onglet_cris = cle
			between.set_meta("fm_onglet", cle)
			rafraichir(true))
		var pile := VBoxContainer.new()
		pile.add_theme_constant_override("separation", px(2))
		pile.add_child(b)
		var trait_onglet := ColorRect.new()
		trait_onglet.color = Charte.IVOIRE if choisi else Color(0, 0, 0, 0)
		trait_onglet.custom_minimum_size.y = px(3)
		trait_onglet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pile.add_child(trait_onglet)
		tete.add_child(pile)

func _menu_cris(col: VBoxContainer) -> void:
	_onglets(col)
	if _onglet_cris == "joueur":
		_liste_joueurs(col, false)
		return
	var actif := _cri_actif()
	for id: String in CRIS:
		var def: Array = CRIS[id]
		var o := _cri_option(id)
		var dispo := o.is_empty() or bool(o.get("disponible", true))
		var en_cours := str(actif.get("id", "")) == id and int(actif.get("jusqua", 0)) > _minute()
		var b := _ligne("FmCri_" + id, func(): crier(id), en_cours, dispo)
		var h := _contenu_ligne(b)
		h.add_child(_rond(str(def[0]), def[1], 42, en_cours))
		var l := _texte(str(o.get("label", id.capitalize())), 22, Charte.IVOIRE if dispo else Charte.IVOIRE_3)
		l.custom_minimum_size.x = px(190)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		for e: Array in def[2]: h.add_child(_puce_effet(str(e[0]), int(e[1])))
		h.add_child(_vide())
		if en_cours: h.add_child(_puce_effet("→ %d′" % int(actif.get("jusqua", 0)), 0))
		elif not dispo and id == "toutDonner": h.add_child(_puce_effet("dès 65′", 0))
		else: h.add_child(_puce_effet("%d′" % int(def[3]), 0))
		h.add_child(_usure(float(o.get("usure", 0.0))))
		col.add_child(b)

## Usure d'un cri en trois points (plein : intact ; à moitié ; vide : ils n'écoutent plus).
func _usure(usure: float) -> Control:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(4))
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var restants := 3 if usure <= 0.0 else 2 if usure <= 0.5 else 0
	for i in 3:
		var point := ColorRect.new()
		point.custom_minimum_size = Vector2(px(10), px(10))
		point.color = Charte.IVOIRE if i < restants else Charte.FILET
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(point)
	h.tooltip_text = "Usure"
	return h

## Cris à un joueur : nos quinze, numéro, nom, moral en direct, trois cris en ronds (planche : sans effet moteur).
func _liste_joueurs(col: VBoxContainer, titre: bool) -> void:
	if titre:
		col.add_child(_texte("CRIS À UN JOUEUR", 26, Charte.IVOIRE, true))
	var d: Variant = between.get("_dernier")
	var live: Dictionary = d[1] if d is Array and (d as Array).size() > 1 and d[1] is Dictionary else {}
	var faits: Dictionary = between.get_meta("fm_cris_joueurs", {})
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size.y = px(600)
	col.add_child(defile)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", px(2))
	defile.add_child(liste)
	var n := 0
	for j: Variant in live.get("lineup", []) if live.get("lineup") is Array else []:
		n += 1
		if not j is Dictionary: continue
		var id := str(j.get("id", ""))
		var ligne := HBoxContainer.new()
		ligne.name = "FmCriJoueur_%d" % n
		ligne.add_theme_constant_override("separation", px(10))
		ligne.custom_minimum_size.y = px(44)
		liste.add_child(ligne)
		var num := _texte(str(n), 20, Charte.IVOIRE_2, true)
		num.custom_minimum_size.x = px(30)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(num)
		var nom := _texte(str(j.get("name", "")), 20, Charte.IVOIRE)
		nom.custom_minimum_size.x = px(230)
		nom.clip_text = true
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(nom)
		var moral: Dictionary = between.moral_joueur(_pilotage(), id)
		if not moral.is_empty():
			var pastille := PanelContainer.new()
			pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var teinte: Color = between.teinte_moral(str(moral.get("cle", "")))
			pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Color(teinte, 0.16), Color.TRANSPARENT, px(10), px(2)))
			pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pastille.add_child(_texte(str(moral.get("label", "")), 15, teinte))
			pastille.custom_minimum_size.x = px(110)
			ligne.add_child(pastille)
		ligne.add_child(_vide())
		var fait: Array = faits.get(id, [])
		for c: Array in CRIS_JOUEUR:
			var fait_ici := not fait.is_empty() and str(fait[0]) == str(c[0])
			var b := Button.new()
			b.name = "FmCriJoueur_%d_%s" % [n, str(c[0])]
			b.flat = true
			b.tooltip_text = str(c[1])
			b.focus_mode = Control.FOCUS_ALL
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.custom_minimum_size = Vector2(px(40), px(40))
			var rond := _rond(str(c[2]), c[3], 38, fait_ici)
			rond.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(rond)
			var id_j := id
			var id_c := str(c[0])
			b.pressed.connect(func(): crier_joueur(id_j, id_c))
			ligne.add_child(b)
		var marque := _texte(("%d′" % int(fait[1])) if not fait.is_empty() else "", 15, Charte.GAIN)
		marque.custom_minimum_size.x = px(40)
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(marque)

# ------------------------------------------------------------------ B : barre du banc, toujours visible

func _barre_b(page: Control) -> void:
	barre_b = PanelContainer.new()
	barre_b.name = "FmBancBarre"
	var st: StyleBoxFlat = between.liserer(between._case(Charte.PANNEAU, Charte.RAYON_PANNEAU))
	st.content_margin_left = px(22)
	st.content_margin_right = px(22)
	st.content_margin_top = px(8)
	st.content_margin_bottom = px(8)
	barre_b.add_theme_stylebox_override("panel", st)
	page.add_child(barre_b)
	_remplir_b()

func _remplir_b() -> void:
	for e in barre_b.get_children():
		barre_b.remove_child(e)
		e.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", px(8))
	barre_b.add_child(h)
	var titre_cris := _texte("CRIS", 22, Charte.IVOIRE, true)
	titre_cris.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(titre_cris)
	var actif := _cri_actif()
	for id: String in CRIS:
		var def: Array = CRIS[id]
		var o := _cri_option(id)
		var dispo := o.is_empty() or bool(o.get("disponible", true))
		var en_cours := str(actif.get("id", "")) == id and int(actif.get("jusqua", 0)) > _minute()
		var mot := str(o.get("label", id))
		if mot == "Serrer la défense": mot = "Défense"
		h.add_child(_bouton_rond("FmCri_" + id, str(def[0]), def[1], mot, en_cours, dispo, func(): crier(id),
			("→ %d′" % int(actif.get("jusqua", 0))) if en_cours else "", float(o.get("usure", 0.0))))
	var joueur := _bouton_rond("FmBancJoueur", "people", Charte.IVOIRE_2, "À un joueur", false, true, func(): ouvrir_menu("joueur"), "", 0.0)
	h.add_child(joueur)
	var sep := ColorRect.new()
	sep.color = Charte.FILET
	sep.custom_minimum_size = Vector2(px(2), px(64))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sep)
	var titre_aj := _texte("AJUSTEMENTS", 22, Charte.IVOIRE, true)
	titre_aj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(titre_aj)
	for aj: Array in AJUSTEMENTS:
		var court: String = {"pied": "Au pied", "garder": "Garder", "accelerer": "Accélérer", "souffler": "Souffler", "relancer": "Relancer", "contester": "Contester",
			"zero": "Zéro faute", "pousser": "Pousser", "porte": "Porté", "aile": "Aile faible", "montre": "La montre", "tout_tenter": "Tout tenter"}.get(str(aj[0]), str(aj[1]))
		var b := _bouton_rond("FmAjust_" + str(aj[0]), str(aj[2]), FAMILLES[str(aj[5])], court, ajustement_actif(aj), true, func(): basculer(aj), "", -1.0)
		b.tooltip_text = str(aj[1]) + "\n" + "\n".join((aj[6] as Array).map(func(e: Array): return ("▲ " if int(e[1]) > 0 else "▼ ") + str(e[0])))
		h.add_child(b)

## Rond + mot dessous ; allumé : aplat de couleur. `marque` (minute de fin) et usure du cri en petit à droite.
func _bouton_rond(nom: String, icone: String, couleur: Color, mot: String, allume: bool, actif: bool, action: Callable, marque: String, usure: float) -> Button:
	var b := Button.new()
	b.name = nom
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not actif
	b.tooltip_text = mot
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actif else Control.CURSOR_ARROW
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Charte.PANNEAU_3 if etat in ["hover", "hover_pressed"] else Color(0, 0, 0, 0)
		if etat == "focus":
			st.border_color = Charte.OR
			st.set_border_width_all(2)
		st.set_corner_radius_all(Charte.RAYON_PETIT)
		b.add_theme_stylebox_override(etat, st)
	b.custom_minimum_size = Vector2(px(92), px(84))
	b.pressed.connect(action)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", px(2))
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	var haut := HBoxContainer.new()
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.alignment = BoxContainer.ALIGNMENT_CENTER
	haut.add_theme_constant_override("separation", px(4))
	v.add_child(haut)
	var rond := _rond(icone, couleur if actif else Charte.IVOIRE_3, 48, allume)
	haut.add_child(rond)
	if usure >= 0.0 and not allume: haut.add_child(_usure_vertical(usure))
	var l := _texte(marque if not marque.is_empty() else mot, 16, (couleur if allume else Charte.IVOIRE) if actif else Charte.IVOIRE_3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return b

func _usure_vertical(usure: float) -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", px(3))
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var restants := 3 if usure <= 0.0 else 2 if usure <= 0.5 else 0
	for i in 3:
		var point := ColorRect.new()
		point.custom_minimum_size = Vector2(px(7), px(7))
		point.color = Charte.IVOIRE_2 if (2 - i) < restants else Charte.FILET
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(point)
	return v
